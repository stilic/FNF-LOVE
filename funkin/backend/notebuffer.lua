local okffi = Project.flags.jitFFI

local function make_quicksort(get_t, swap)
	local function qs(data, lo, hi)
		local i, j  = lo, hi
		local pivot = get_t(data, bit.rshift(lo + hi, 1))
		while i <= j do
			while get_t(data, i) < pivot do i = i + 1 end
			while get_t(data, j) > pivot do j = j - 1 end
			if i <= j then
				swap(data, i, j)
				i, j = i + 1, j - 1
			end
		end
		if lo < j then qs(data, lo, j) end
		if i < hi then qs(data, i,  hi) end
	end
	return qs
end

local ffiBackend
if okffi then
	local ffi = require("ffi")
	ffi.cdef[[
		typedef struct { double t; float l; uint16_t k; uint8_t d; bool gf; } Note;
	]]
	local note_t    = ffi.typeof("Note[?]")
	local note_size = ffi.sizeof("Note")
	local swap_buf  = ffi.new("Note")

	local sort = make_quicksort(
		function(d, i)    return d[i].t end,
		function(d, i, j)
			ffi.copy(swap_buf, d + i,    note_size)
			ffi.copy(d + i,    d + j,    note_size)
			ffi.copy(d + j,    swap_buf, note_size)
		end
	)

	ffiBackend = {
		alloc = function(cap) return note_t(cap) end,
		grow = function(self)
			local grown = note_t(self.capacity)
			ffi.copy(grown, self.data, note_size * self.count)
			self.data = grown
		end,
		shrink = function(self)
			local slim = note_t(self.count)
			if self.count > 0 then ffi.copy(slim, self.data, note_size * self.count) end
			self.data, self.capacity = slim, self.count
		end,
		push = function(self, t, d, l, k, gf)
			local n = self.data[self.count]
			n.t, n.d, n.l, n.k, n.gf = t, d, l, k, gf
		end,
		remove = function(self, idx)
			local tail = self.count - idx - 1
			if tail > 0 then
				ffi.copy(self.data + idx, self.data + idx + 1, note_size * tail)
			end
		end,
		sort = function(self) sort(self.data, 0, self.count - 1) end,
	}
end

local sortLua = make_quicksort(
	function(d, i)    return d[i].t end,
	function(d, i, j) d[i], d[j] = d[j], d[i] end
)

local luaBackend = {
	alloc = function(_cap) return {} end,
	grow = function(_self) end,
	shrink = function(self)
		for i = self.count, self.capacity - 1 do self.data[i] = nil end
		self.capacity = self.count
	end,
	push = function(self, t, d, l, k, gf)
		self.data[self.count] = { t = t, d = d, l = l, k = k, gf = gf }
	end,
	remove = function(self, idx)
		local tail = self.count - idx - 1
		for i = 0, tail - 1 do self.data[idx + i] = self.data[idx + i + 1] end
		self.data[self.count - 1] = nil
	end,
	sort = function(self) sortLua(self.data, 0, self.count - 1) end,
}

local backend = okffi and ffiBackend or luaBackend

local NoteBuffer = Classic:extend("NoteBuffer")
local DEFAULT_CAPACITY = 1024

function NoteBuffer:new(capacity)
	self.count    = 0
	self.capacity = capacity or DEFAULT_CAPACITY
	self.data     = backend.alloc(self.capacity)
	self.kindMap  = { [""] = 0 }
	self.kindList = { [0] = "" }
end

function NoteBuffer:_internKind(k)
	local str = k or ""
	local id  = self.kindMap[str]
	if not id then
		id = #self.kindList + 1
		self.kindMap[str] = id
		self.kindList[id] = str
	end
	return id
end

function NoteBuffer:_grow()
	self.capacity = self.capacity * 2
	backend.grow(self)
end

function NoteBuffer:push(t, d, l, k, gf)
	if self.count >= self.capacity then self:_grow() end
	local raw = l or 0
	backend.push(self,
		t,
		d,
		raw ~= 0 and math.max(raw / 1000, 0.125) * 1000 or 0,
		self:_internKind(k),
		gf or false
	)
	self.count = self.count + 1
end

function NoteBuffer:shrink()
	if self.count ~= self.capacity then backend.shrink(self) end
end

function NoteBuffer:remove(idx)
	if idx < 0 or idx >= self.count then return end
	backend.remove(self, idx)
	self.count = self.count - 1
end

function NoteBuffer:sortByTime()
	if self.count > 1 then backend.sort(self) end
end

function NoteBuffer:insert(t, d, l, k, gf)
	self:push(t, d, l, k, gf)
	self:sortByTime()
end

return NoteBuffer
