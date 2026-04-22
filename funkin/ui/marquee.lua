local Marquee = Text:extend("Marquee", true)

function Marquee:new(x, y, limit, velocity, content, font, color, align)
	Marquee.super.new(self, x, y, content, font, color, align)

	self._speed = velocity or 100
	self._pauseTime = 1.5
	self._pauseTimer = self._pauseTime
	self._scrollOffset = 0
	self._isScrolling = false
	self._spacing = 50

	self._fadeSize = 10
	self._leftFadeWidth = 0
	self._growthSpeed = 2.5

	self._limit = limit or 200
	self._canvas = nil
	self._textObj = nil
	self._fadeMesh = nil
	self._outlineOffsets = nil
	self.__force = true

	self:__updateDimension()
end

function Marquee:set_content(v)
	Marquee.super.set_content(self, v)
	self.__force = true
end

function Marquee:set_font(v)
	Marquee.super.set_font(self, v)
	self.__force = true
end

function Marquee:set_limit(v)
	Marquee.super.set_limit(self, v)
	self.__force = true
end

function Marquee:set_outline(v)
	Marquee.super.set_outline(self, v)
	self.__force = true
end

function Marquee:update(dt)
	Marquee.super.update(self, dt)

	if not self._limit or not self.width or self.width <= self._limit then
		self._leftFadeWidth = 0
		return
	end

	if not self._isScrolling then
		self._pauseTimer = self._pauseTimer - dt
		if self._leftFadeWidth > 0 then
			self._leftFadeWidth = math.max(0, self._leftFadeWidth - dt * self._speed * self._growthSpeed)
			self.__force = true
		end
		if self._pauseTimer <= 0 then self._isScrolling = true end
	else
		if self._leftFadeWidth < self._fadeSize then
			self._leftFadeWidth = math.min(self._fadeSize, self._leftFadeWidth + dt * self._speed * self._growthSpeed)
			self.__force = true
		end

		self._scrollOffset = self._scrollOffset + self._speed * dt
		if self._scrollOffset >= self.width + self._spacing then
			self._scrollOffset = 0
			self._pauseTimer = self._pauseTime
			self._isScrolling = false
			self._leftFadeWidth = 0
		end
	end
end

function Marquee:__updateDimension()
	if not self._limit then return end

	if self.__content == self._content and self.__font == self._font and
	   self.__limit == self._limit then return end

	self.__content = self._content
	self.__limit = self._limit
	self.__font = self._font
	if not self._font then return end

	local str = tostring(self._content)
	self.width = self._font:getWidth(str)
	self.height = self._font:getHeight()

	if self._textObj then self._textObj:release() end
	self._textObj = love.graphics.newText(self._font, str)

	if self._outline and self._outline.width > 0 and self._outline.style == "normal" then
		self._outlineOffsets = {}
		local step = (2 * math.pi) / self._outline.precision
		for i = 1, self._outline.precision do
			self._outlineOffsets[i] = {
				x = math.cos(i * step) * self._outline.width,
				y = math.sin(i * step) * self._outline.width
			}
		end
	end

	if self._canvas then self._canvas:release(); self._canvas = nil end
	if self.width > self._limit then
		self._canvas = love.graphics.newCanvas(self._limit, self.height, { msaa = 0, dpiscale = 1 })

		local vertices = {
			{0, 0, 0, 0, 1, 1, 1, 1},
			{1, 0, 0, 0, 1, 1, 1, 1},
			{1, 1, 0, 0, 1, 1, 1, 1},
			{0, 1, 0, 0, 1, 1, 1, 1},
		}
		self._fadeMesh = love.graphics.newMesh(vertices, "fan", "dynamic")
	end
end

function Marquee:__preRender(willRender)
	if not willRender then return end
	if not self._canvas or not self._limit then return end

	if self._isScrolling or self.__force then
		self.__force = false
		self:__updateDimension()

		local w, h = self._limit, self.height
		local f = self._fadeSize
		local l = self._leftFadeWidth

		local r, g, b, a = love.graphics.getColor()
		local bMode, bAlpha = love.graphics.getBlendMode()

		love.graphics.setCanvas(self._canvas)
		love.graphics.clear(0, 0, 0, 0)

		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.setColor(1, 1, 1, 1)

		self:__renderTextInternal(-self._scrollOffset)
		self:__renderTextInternal(-self._scrollOffset + self.width + self._spacing)

		love.graphics.setBlendMode("multiply", "premultiplied")

		self._fadeMesh:setVertex(1, 0, 0, 0, 0, 1, 1, 1, 1)
		self._fadeMesh:setVertex(2, f, 0, 0, 0, 0, 0, 0, 0)
		self._fadeMesh:setVertex(3, f, h, 0, 0, 0, 0, 0, 0)
		self._fadeMesh:setVertex(4, 0, h, 0, 0, 1, 1, 1, 1)
		love.graphics.draw(self._fadeMesh, w - f, 0)

		if l > 0 then
			local copyPos = -self._scrollOffset + self.width + self._spacing
			if copyPos > l then
				self._fadeMesh:setVertex(1, 0, 0, 0, 0, 0, 0, 0, 0)
				self._fadeMesh:setVertex(2, l, 0, 0, 0, 1, 1, 1, 1)
				self._fadeMesh:setVertex(3, l, h, 0, 0, 1, 1, 1, 1)
				self._fadeMesh:setVertex(4, 0, h, 0, 0, 0, 0, 0, 0)
				love.graphics.draw(self._fadeMesh, 0, 0)
			end
		end

		love.graphics.setCanvas()
		love.graphics.setColor(r, g, b, a)
		love.graphics.setBlendMode(bMode, bAlpha)
	end
end

function Marquee:__renderTextInternal(x)
	if not self._textObj then return end

	local outline = self._outline
	if not self.antialiasing then x = math.floor(x) end

	if outline and outline.width > 0 then
		if outline.style == "simple" then
			love.graphics.draw(self._textObj, x + outline.offset.x, outline.offset.y)
		elseif outline.style == "normal" and self._outlineOffsets then
			for i = 1, #self._outlineOffsets do
				local off = self._outlineOffsets[i]
				love.graphics.draw(self._textObj, x + off.x, off.y)
			end
		end
	end

	love.graphics.draw(self._textObj, x, 0)
end

function Marquee:__render(camera)
	if not self.width or not self._limit or self.width <= self._limit then
		return Marquee.super.__render(self, camera)
	end

	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	if self._canvas then
		local filter = self.antialiasing and "linear" or "nearest"
		self._canvas:setFilter(filter, filter)

		love.graphics.draw(self._canvas, x, y, rad, sx, sy, ox, oy, kx, ky)
	end
end

function Marquee:destroy()
	if self._canvas then self._canvas:release() end
	if self._textObj then self._textObj:release() end
	if self._fadeMesh then self._fadeMesh:release() end
	Marquee.super.destroy(self)
end

Marquee.__setters.content = Marquee.set_content
Marquee.__setters.font    = Marquee.set_font
Marquee.__setters.limit   = Marquee.set_limit
Marquee.__setters.outline = Marquee.set_outline

return Marquee
