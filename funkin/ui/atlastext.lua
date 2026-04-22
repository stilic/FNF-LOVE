local ffi = require "ffi"
local utf8 = require "utf8"

if Project.flags.jitFFI then
	ffi.cdef[[
		typedef struct {
			double x, y;
			int32_t batchIdx;
			int16_t ox, oy;
			uint16_t width, height;
			uint16_t animFrame;
			uint16_t animLength;
			bool visible;
			double animTimer;
		} AtlasGlyph;
	]]
else
	ffi = {}
	function ffi.new(typeStr, count)
		if typeStr:find("AtlasGlyph") then
			local arr = {}
			for i = 0, (count or 1) - 1 do
				arr[i] = {
					x = 0, y = 0, batchIdx = -1, ox = 0, oy = 0,
					width = 0, height = 0, animFrame = 0, animLength = 0,
					visible = false, animTimer = 0
				}
			end
			return arr
		end
	end
end

local function newcasemap(ranges)
	local upper, lower = {}, {}
	for _, range in pairs(ranges) do
		local u1, u2, l1, l2 = unpack(range)
		local lower_cp = l1
		for codepoint = u1, u2 do
			local char1 = utf8.char(codepoint)
			local char2 = utf8.char(lower_cp)
			lower[char1] = char2
			upper[char2] = char1
			lower_cp = lower_cp + 1
		end
	end
	return upper, lower
end

local upcase, lowcase = newcasemap({
	{0x00C0, 0x00DF, 0x00E0, 0x00FF},
	{0x0400, 0x040F, 0x0450, 0x045F},
	{0x0410, 0x042F, 0x0430, 0x044F},
})

local function lower(input)
	local result = {}
	for _, c in utf8.codes(input) do
		c = utf8.char(c)
		table.insert(result, lowcase[c] or c:lower())
	end
	return table.concat(result)
end

local function upper(input)
	local result = {}
	for _, c in utf8.codes(input) do
		c = utf8.char(c)
		table.insert(result, upcase[c] or c:upper())
	end
	return table.concat(result)
end

local AtlasText = Object:extend("AtlasText", true)

function AtlasText.getFont(name, size)
	local font = paths.getJSON("data/fonts/" .. name)
	if font == nil and AtlasText.defaultFont ~= nil then
		return AtlasText.defaultFont
	elseif not font then
		return
	end

	font.scale = font.scale or 1
	if size ~= nil then font.scale = font.scale * size end
	font.lineSize = font.lineSize or 70
	font.spaceWidth = font.spaceWidth or 40

	return font
end

function AtlasText:new(x, y, text, font, limit, align)
	AtlasText.super.new(self, x, y)

	self._text = text or ""
	self._limit = limit or 0
	self._align = align or "left"
	self.italic = false

	self.batchPool = {}
	self._glyphCapacity = 0
	self._glyphCount = 0
	self._luaFrames = {}
	self._animCache = {}

	self:setTyping(nil, 0)
	self:setFont(font)
end

function AtlasText:set_text(v) self._text = v; self:setText() end
function AtlasText:set_limit(v) self._limit = v; self:setText() end
function AtlasText:set_align(v) self._align = v; self:setText() end

function AtlasText:get_text() return self._text end
function AtlasText:get_limit() return self._limit end
function AtlasText:get_align() return self._align end

function AtlasText:setTyping(text, speed, sound)
	self.typed = speed > 0
	if self.typed then
		self.text = ""
		self.finished = false
	end
	self.__target, self.timer, self.index = text or self._text, 0, 0
	self.sound, self.speed, self.completeCallback = sound, speed, nil
end

function AtlasText:setFont(font, size)
	if (font and self.font == font) and (size and self.size == size) then return end

	font = font or self.font or AtlasText.defaultFont
	self.font = type(font) == "string" and AtlasText.getFont(font, size) or font

	self.frames = paths.getSparrowAtlas('fonts/' .. self.font.name)
	self._animCache = {}

	if self.batch then
		self.batch:setTexture(self.frames.texture)
	else
		self.batch = love.graphics.newSpriteBatch(self.frames.texture, 1, "stream")
	end

	self:setText()
end

function AtlasText:_getFramesForChar(char)
	if self._animCache[char] then return self._animCache[char] end
	local frames = {}
	if self.frames and self.frames.frames then
		for _, f in ipairs(self.frames.frames) do
			if string.sub(f.name, 1, #char) == char then
				table.insert(frames, f)
			end
		end
	end
	self._animCache[char] = frames
	return frames
end

function AtlasText:setText(text)
	self:cleanup()

	if text ~= nil then self._text = text end
	local font = self.font
	if font == nil then return end

	local charDataList = {}
	local words = {}
	local word = {width = 0, start = 1, stop = 0}
	local idx = 1

	for _, charCode in utf8.codes(self._text) do
		local rawChar = utf8.char(charCode)
		local isSpace = (rawChar == " ")
		local isNewline = (rawChar == "\n")

		if isSpace or isNewline then
			if word.start <= idx - 1 then
				word.stop = idx - 1
				table.insert(words, word)
			end
			word = {width = 0, start = idx + 1, stop = 0}

			local sp = {start = idx, stop = idx, space = isSpace, nl = isNewline}
			sp.width = isSpace and font.spaceWidth or 0
			table.insert(words, sp)

			charDataList[idx] = { char = rawChar, w = sp.width, h = 0, ox = 0, oy = 0, visible = false }
		else
			local c = font.noUpper and lower(rawChar) or (font.noLower and upper(rawChar) or rawChar)
			local gd = font.glyphs and font.glyphs[c]
			local w, h, ox, oy = 0, 0, 0, 0
			local visible = true
			local cFrames = nil

			if c == "\t" then
				visible = false
				w = (gd and type(gd[1]) == "number") and gd[1] or (font.spaceWidth * 4)
				h = w
			else
				if gd then
					c = gd[1]
					if gd[2] then ox, oy = gd[2][1], gd[2][2] end
				end
				cFrames = self:_getFramesForChar(c)
				if cFrames and #cFrames > 0 then
					local f = cFrames[1]
					if f and f.quad then
						local _, _, qw, qh = f.quad:getViewport()
						w, h = qw, qh
					end
				end
			end
			charDataList[idx] = { char = c, w = w, h = h, ox = ox, oy = oy, visible = visible, frames = cFrames }
			word.width = word.width + w
		end
		idx = idx + 1
	end

	if word.start <= idx - 1 then
		word.stop = idx - 1
		table.insert(words, word)
	end

	local lines = {}
	local line, last = {width = 0, words = {}}, 0
	local limit = self._limit
	if limit > 0 and font.scale ~= 1 then limit = limit / font.scale end

	for i, w in ipairs(words) do
		if w.nl then
			if last > 0 and words[last].space then
				line.width = line.width - words[last].width
				table.remove(line.words)
				last = last - 1
			end
			table.insert(lines, line)
			line = {width = 0, words = {}}
			last = 0
		elseif limit > 0 and not w.space and line.width + w.width > limit and line.width > 0 then
			if last > 0 and words[last].space then
				line.width = line.width - words[last].width
				table.remove(line.words)
			end
			table.insert(lines, line)
			line = {width = w.width, words = {w}}
			last = i
		else
			line.width = line.width + w.width
			table.insert(line.words, w)
			last = i
		end
	end

	if #line.words > 0 or line.width > 0 then table.insert(lines, line) end

	local requiredCapacity = #charDataList
	if self._glyphCapacity < requiredCapacity then
		self._glyphCapacity = math.max(requiredCapacity, self._glyphCapacity * 2, 32)
		self._glyphData = ffi.new("AtlasGlyph[?]", self._glyphCapacity)
	end

	self._glyphCount = 0
	self._luaFrames = {}

	for i, ln in ipairs(lines) do
		local y = (i - 1) * font.lineSize
		local xOff = 0
		if self._align ~= "left" then
			if limit > 0 then
				xOff = (limit - ln.width * font.scale) / (self._align == "center" and 2 or 1)
			else
				xOff = (ln.width * font.scale) / (self._align == "center" and 2 or 1)
			end
		end

		local x = 0
		for _, w in ipairs(ln.words) do
			if w.space then
				x = x + w.width
			else
				local wx = x
				for ci = w.start, w.stop do
					local d = charDataList[ci]
					if d then
						local g = self._glyphData[self._glyphCount]
						g.x = wx + xOff
						g.y = y
						g.width = d.w
						g.height = d.h
						g.batchIdx = -1
						g.visible = d.visible
						g.animTimer = 0
						g.animFrame = 1

						local fx = font.offsets and font.offsets[1] or 0
						local fy = font.offsets and font.offsets[2] or 0

						g.ox = d.ox - fx
						g.oy = d.oy - fy

						if d.frames and #d.frames > 0 then
							g.animLength = #d.frames
							self._luaFrames[self._glyphCount + 1] = d.frames
						else
							g.animLength = 0
						end

						self._glyphCount = self._glyphCount + 1
						wx = wx + d.w
					end
				end
				x = wx
			end
		end
	end
	self:updateHitbox()
	self:forceUpdateBatch()
end

function AtlasText:forceUpdateBatch()
	if not self.batch or self._glyphCount == 0 then return end
	local s = self.italic and -0.2 or 0

	for i = 0, self._glyphCount - 1 do
		local g = self._glyphData[i]
		if g.visible and g.animLength > 0 then
			local frames = self._luaFrames[i + 1]
			local f = frames[g.animFrame]
			if f and f.quad then

				local bx = g.x + g.ox - f.offset.x
				local by = g.y + g.oy + (self.font.lineSize - g.height) - f.offset.y

				if g.batchIdx == -1 then
					if #self.batchPool > 0 then
						g.batchIdx = table.remove(self.batchPool)
						self.batch:set(g.batchIdx, f.quad, bx, by, 0, 1, 1, 0, 0, s)
					else
						g.batchIdx = self.batch:add(f.quad, bx, by, 0, 1, 1, 0, 0, s)
					end
				else
					self.batch:set(g.batchIdx, f.quad, bx, by, 0, 1, 1, 0, 0, s)
				end
			end
		end
	end
end

function AtlasText:update(dt)
	if self.typed and not self.finished then
		self.timer = self.timer + dt
		if self.timer >= self.speed then self:addLetter() end
		if self.index == #self.__target then
			self.finished = true
			if self.completeCallback then self.completeCallback() end
		end
	end

	local needsUpdate = false
	local framerate = self.font.framerate or 24
	local delay = framerate > 0 and (1.0 / framerate) or 0

	if delay > 0 then
		for i = 0, self._glyphCount - 1 do
			local g = self._glyphData[i]
			if g.visible and g.animLength > 1 then
				g.animTimer = g.animTimer + dt
				if g.animTimer >= delay then
					g.animTimer = g.animTimer - delay
					g.animFrame = g.animFrame + 1
					if g.animFrame > g.animLength then g.animFrame = 1 end
					needsUpdate = true
				end
			end
		end
	end

	if needsUpdate then self:forceUpdateBatch() end
	AtlasText.super.update(self, dt)
end

function AtlasText:forceEnd()
	if not self.typed then return end
	self.text = self.__target
	self.finished = true
	if self.completeCallback then self.completeCallback() end
end

function AtlasText:addLetter()
	if not self.typed then return end
	self.timer = 0
	self.index = self.index + 1
	self.text = self.__target:sub(1, self.index)
	if self.sound then game.sound.play(self.sound) end
end

function AtlasText:__render(camera)
	if not self.batch or self._glyphCount == 0 then return end

	local x, y, rad, sx, sy, ox, oy = self:setupDrawLogic(camera)
	if self.font and self.font.scale then
		sx, sy = sx * self.font.scale, sy * self.font.scale
	end

	love.graphics.push("all")

	local texture = self.batch:getTexture()
	local min, mag, anisotropy = texture:getFilter()
	local antialiasing = true
	if self.font.antialiasing ~= nil then antialiasing = self.font.antialiasing end
	local mode = antialiasing and "linear" or "nearest"
	texture:setFilter(mode, mode, anisotropy)

	local r, g, b, a = self:getDrawColor()
	love.graphics.setColor(r, g, b, a)

	love.graphics.draw(self.batch, x, y, rad, sx, sy, ox, oy)

	texture:setFilter(min, mag, anisotropy)
	love.graphics.pop()
end

function AtlasText:cleanup()
	if not self._glyphData then return end
	for i = 0, self._glyphCount - 1 do
		local g = self._glyphData[i]
		if g.batchIdx ~= -1 and self.batch then
			table.insert(self.batchPool, g.batchIdx)
			self.batch:set(g.batchIdx, 0, 0, 0, 0, 0, 0, 0)
			g.batchIdx = -1
		end
	end
	self._glyphCount = 0
	self._luaFrames = {}
end

function AtlasText:destroy()
	self:cleanup()
	if self.batch then self.batch:release() end
	self.batch = nil
	self._glyphData = nil
	AtlasText.super.destroy(self)
end

function AtlasText:canDraw()
	return self._glyphCount > 0 and AtlasText.super.canDraw(self)
end

function AtlasText:__tostring() return self._text end

function AtlasText:updateHitbox()
	if self._glyphCount == 0 then
		self.width, self.height, self.minX, self.minY = 0, 0, 0, 0
		return
	end

	local fs = self.font.scale or 1

	local xmin = self._glyphData[0].x * fs
	local xmax = xmin
	for i = 0, self._glyphCount - 1 do
		local g = self._glyphData[i]
		local vw = (g.x + g.width) * fs
		if g.x * fs < xmin then xmin = g.x * fs end
		if vw > xmax then xmax = vw end
	end

	local totalLines = 1
	for i = 0, self._glyphCount - 1 do
		local lineNum = math.floor(self._glyphData[i].y / self.font.lineSize) + 1
		if lineNum > totalLines then totalLines = lineNum end
	end

	self._minX = xmin
	self.width = xmax - xmin
	self.height = totalLines * self.font.lineSize * fs
end

function AtlasText:getLocalBounds()
	return self._minX or 0, 0, self.width, self.height
end

function AtlasText:getWidth() return self.width end
function AtlasText:getHeight() return self.height end

AtlasText.__getters.text  = AtlasText.get_text
AtlasText.__getters.limit = AtlasText.get_limit
AtlasText.__getters.align = AtlasText.get_align

AtlasText.__setters.text  = AtlasText.set_text
AtlasText.__setters.limit = AtlasText.set_limit
AtlasText.__setters.align = AtlasText.set_align

return AtlasText
