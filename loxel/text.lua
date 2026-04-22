---@class Text:Object
local Text = Object:extend("Text", true)

function Text:new(x, y, content, font, color, align, limit)
	Text.super.new(self, x, y)

	self._content = content
	self._font = font or love.graphics.getFont()
	self._color = color or {1, 1, 1, 1}
	self._alignment = align or "left"
	self._limit = limit
	self._outline = {
		style = "normal",
		color = Color.BLACK,
		width = 0,
		offset = Point(),
		precision = 8,
		antialiasing = nil
	}

	self.bgColor = nil
	self.antialiasing = true
	self._loveText = love.graphics.newText(self._font)
	self.__textNeedsUpdate = true

	self:__updateDimension()
end

function Text:set_content(v)
	if self._content == v then return end
	self._content = v
	self.__textNeedsUpdate = true
end

function Text:set_font(v)
	if self._font == v then return end
	self._font = v
	self.__textNeedsUpdate = true
end

function Text:set_color(v)
	self._color = v
	self.__textNeedsUpdate = true
end

function Text:set_alignment(v)
	if self._alignment == v then return end
	self._alignment = v
	self.__textNeedsUpdate = true
end

function Text:set_limit(v)
	if self._limit == v then return end
	self._limit = v
	self.__textNeedsUpdate = true
end

function Text:set_outline(v)
	self._outline = v
	self.__textNeedsUpdate = true
end

function Text:get_content() return self._content end
function Text:get_font() return self._font end
function Text:get_color() return self._color end
function Text:get_alignment() return self._alignment end
function Text:get_limit() return self._limit end
function Text:get_outline() return self._outline end

function Text:setOutline(style, width, offset, color)
	local o = self._outline

	o.style = style or o.style
	o.width = width or o.width
	o.offset:set(offset and offset.x or o.offset.x, offset and offset.y or o.offset.y)
	o.color = color or o.color
	self.__textNeedsUpdate = true
end

function Text:__updateTextBatch()
	if not self.__textNeedsUpdate then return end

	self._loveText:setFont(self._font)
	self._loveText:clear()

	local str = tostring(self._content)
	local limit = self._limit or self._font:getWidth(str)
	local align = self._alignment

	if self._outline then
		local oc = self._outline.color
		local outlineData = {{oc[1], oc[2], oc[3], oc[4] or 1}, str}

		if self._outline.style == "simple" then
			self._loveText:addf(outlineData, limit, align, self._outline.offset.x, self._outline.offset.y)
		elseif self._outline.style == "normal" and self._outline.width > 0 then
			local step = (2 * math.pi) / self._outline.precision
			for i = 1, self._outline.precision do
				local dx = math.fastcos(i * step) * self._outline.width
				local dy = math.fastsin(i * step) * self._outline.width
				self._loveText:addf(outlineData, limit, align, math.round(dx), math.round(dy))
			end
		end
	end

	local c = self._color
	self._loveText:addf({{c[1], c[2], c[3], 1}, str}, limit, align, 0, 0)

	self:__updateDimension()

	self.__textNeedsUpdate = false
end

function Text:__render(camera)
	if self.__textNeedsUpdate then self:__updateTextBatch() end

	love.graphics.push("all")

	local mode = self.antialiasing and "linear" or "nearest"
	local min, mag, anisotropy = self._font:getFilter()

	if min ~= mode or mag ~= mode then
		self._font:setFilter(mode, mode, anisotropy)
	end

	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	if not self.antialiasing then x, y = math.round(x), math.round(y) end

	if self.bgColor and self.bgColor[4] > 0 then
		love.graphics.setColor(self:getDrawColor(self.bgColor))
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end

	local r, g, b, a = self:getDrawColor()
	love.graphics.setColor(1, 1, 1, a)

	love.graphics.draw(self._loveText, x, y, rad, sx, sy, ox, oy, kx, ky)

	love.graphics.pop()
end

function Text:__updateDimension()
	local f = self._font
	local c = tostring(self._content)
	local w = f:getWidth(c)
	local h = f:getHeight()

	if self._limit ~= nil or w ~= 0 then
		local _, lines = f:getWrap(c, self._limit or w)
		w = self._limit or w
		h = h * #lines
	end

	self.width = w
	self.height = h
end

function Text:getWidth()
	if self.__textNeedsUpdate then self:__updateTextBatch() end
	return self.width
end

function Text:getHeight()
	if self.__textNeedsUpdate then self:__updateTextBatch() end
	return self.height
end

function Text:canDraw()
	return self._content and self._content ~= "" and Text.super.canDraw(self)
end

function Text:destroy()
	Text.super.destroy(self)
	if self._loveText then
		self._loveText:release()
	end
end

Text.__getters.content   = Text.get_content
Text.__getters.font      = Text.get_font
Text.__getters.color     = Text.get_color
Text.__getters.alignment = Text.get_alignment
Text.__getters.limit     = Text.get_limit
Text.__getters.outline   = Text.get_outline

Text.__setters.content   = Text.set_content
Text.__setters.font      = Text.set_font
Text.__setters.color     = Text.set_color
Text.__setters.alignment = Text.set_alignment
Text.__setters.limit     = Text.set_limit
Text.__setters.outline   = Text.set_outline

return Text
