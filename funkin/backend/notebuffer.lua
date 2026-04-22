local ffi = require("ffi")

ffi.cdef[[
	typedef struct { double t; float l; uint16_t k; uint8_t d; bool gf; } Note;
]]

local note_t    = ffi.typeof("Note[?]")
local note_size = ffi.sizeof("Note")
local swap_buf  = ffi.new("Note")

local function quicksort(data, lo, hi)
	local i, j  = lo, hi
	local pivot = data[bit.rshift(lo + hi, 1)].t
	while i <= j do
		while data[i].t < pivot do i = i + 1 end
		while data[j].t > pivot do j = j - 1 end
		if i <= j then
			ffi.copy(swap_buf,    data + i, note_size)
			ffi.copy(data + i,    data + j, note_size)
			ffi.copy(data + j,    swap_buf, note_size)
			i, j = i + 1, j - 1
		end
	end
	if lo < j then quicksort(data, lo, j) end
	if i < hi then quicksort(data, i,  hi) end
end

local NoteBuffer = Classic:extend("NoteBuffer")

local DEFAULT_CAPACITY = 1024

function NoteBuffer:new(capacity)
	self.count    = 0
	self.capacity = capacity or DEFAULT_CAPACITY
	self.data     = note_t(self.capacity)
	self.kindMap  = { [""] = 0 }
	self.kindList = { [0] = "" }
end

function NoteBuffer:_grow()
	self.capacity = self.capacity * 2
	local grown   = note_t(self.capacity)
	ffi.copy(grown, self.data, note_size * self.count)
	self.data = grown
end

function NoteBuffer:_internKind(k)
	local str = k or ""
	local id  = self.kindMap[str]
	if not id then
		id = #self.kindList + 1
		self.kindMap[str]  = id
		self.kindList[id]  = str
	end
	return id
end

function NoteBuffer:push(t, d, l, k, gf)
	if self.count >= self.capacity then self:_grow() end

	local n   = self.data[self.count]
	local raw = l or 0

	n.t  = t
	n.d  = d
	n.l  = raw ~= 0 and math.max(raw / 1000, 0.125) * 1000 or 0
	n.k  = self:_internKind(k)
	n.gf = gf or false

	self.count = self.count + 1
end

function NoteBuffer:shrink()
	if self.count == self.capacity then return end
	local slim = note_t(self.count)
	if self.count > 0 then
		ffi.copy(slim, self.data, note_size * self.count)
	end
	self.data     = slim
	self.capacity = self.count
end

function NoteBuffer:remove(idx)
	if idx < 0 or idx >= self.count then return end
	local tail = self.count - idx - 1
	if tail > 0 then
		ffi.copy(self.data + idx, self.data + idx + 1, note_size * tail)
	end
	self.count = self.count - 1
end

function NoteBuffer:sortByTime()
	if self.count > 1 then quicksort(self.data, 0, self.count - 1) end
end

function NoteBuffer:insert(t, d, l, k, gf)
	self:push(t, d, l, k, gf)
	self:sortByTime()
end

return NoteBuffer
