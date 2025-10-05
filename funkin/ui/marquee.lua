local Marquee = Text:extend("Marquee")

function Marquee:new(x, y, limit, velocity, content, font, color)
	self.speed = velocity
	self.pauseTime = 1.5
	self.pauseTimer = self.pauseTime
	self.scrollOffset = 0
	self.isScrolling = false
	self.spacing = 50
	Marquee.super.new(self, x, y, content, font, color)
	self.limit = limit or 200
end

function Marquee:update(dt)
	Marquee.super.update(self, dt)
	if self.width <= self.limit then return end

	if not self.isScrolling then
		self.pauseTimer = self.pauseTimer - dt
		if self.pauseTimer <= 0 then
			self.isScrolling = true
		end
	else
		self.scrollOffset = self.scrollOffset + self.speed * dt
		if self.scrollOffset >= self.width + self.spacing then
			self.scrollOffset = 0
			self.pauseTimer = self.pauseTime
			self.isScrolling = false
		end
	end
	if self.canRender then -- insane shit but its fucked up on render due to transformations
	-- no love.graphics.origin() won't do it
		self.canvas:renderTo(function()
			love.graphics.clear(0, 0, 0, 0)
			self:__renderText(-self.scrollOffset)
			self:__renderText(-self.scrollOffset + self.width + self.spacing)
		end)
		self.canRender = nil
	end
end

function Marquee:__updateDimension()
	if self.__content == self.content and self.__font == self.font and
		self.__limit == self.limit then return end
	self.__content = self.content
	self.__limit = self.limit
	self.__font = self.font

	if not self.font then return end

	self.width = self.font:getWidth(self.content)
	self.height = self.font:getHeight()

	if self.width > (self.limit or -1) then
		self:updateCanvas()
	end
end

function Marquee:updateCanvas()
	if self.canvas then self.canvas:release() end

	self.canvas = love.graphics.newCanvas(self.limit, self.height)
	self.canvas:renderTo(function()
		love.graphics.clear(0, 0, 0, 0)
		self:__renderText(-self.scrollOffset)
		self:__renderText(-self.scrollOffset + self.width + self.spacing)
	end)
end

function Marquee:__renderText(x)
	love.graphics.push("all")

	---@diagnostic disable-next-line: unbalanced-assignments
	local rad, sx, sy, ox, oy = 0, 1, 1
	if not self.antialiasing then x = math.floor(x) end

	local content, align, outline = self.content, self.alignment, self.outline
	local width, font = self.width, self.font

	love.graphics.setFont(self.font)

	local min, mag, anisotropy = self.font:getFilter()
	local mode = self.antialiasing and "linear" or "nearest"

	if outline then
		love.graphics.setColor(self:getDrawColor(outline.color))
		if outline.style == "simple" then
			love.graphics.printf(content,
				x + outline.offset.x, outline.offset.y,
				width, align, rad, sx, sy, ox, oy)
		elseif outline.width > 0 and outline.style == "normal" then
			local step = (2 * math.pi) / outline.precision
			for i = 1, outline.precision do
				local dx = math.cos(i * step) * outline.width
				local dy = math.sin(i * step) * outline.width
				if outline.antialiasing ~= nil then
					local omode = outline.antialiasing and "linear" or "nearest"
					self.font:setFilter(omode, omode, anisotropy)
				end
				love.graphics.printf(content, x + dx, dy,
					width, align, rad, sx, sy, ox, oy)
			end
		end
	end
	self.font:setFilter(mode, mode, anisotropy)

	love.graphics.setColor(self:getDrawColor())
	love.graphics.printf(content, x, 0, width, align, rad, sx, sy, ox, oy)

	self.font:setFilter(min, mag, anisotropy)
	love.graphics.pop()
end

function Marquee:__render(camera)
	if self.width <= self.limit then
		return Marquee.super.__render(self, camera)
	end

	self.canRender = true

	love.graphics.push("all")
	local r, g, b = love.graphics.getColor()
	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera, false)
	if not self.antialiasing then x, y = math.floor(x), math.floor(y) end
	love.graphics.setShader(self.shader)
	local mode = self.antialiasing and "linear" or "nearest"
	self.canvas:setFilter(mode, mode)
	love.graphics.setBlendMode(self.blend)
	love.graphics.setColor(r, g, b, self.alpha)
	love.graphics.draw(self.canvas, x, y, rad, sx, sy, ox, oy, kx, ky)
	love.graphics.pop()
end

function Marquee:getLocalBounds()
	local x, y = 0, 0
	if self.offset ~= nil then x, y = x - self.offset.x, y - self.offset.y end
	local w, h = self.limit ~= nil and self.limit or self:getWidth(), self:getHeight()

	if self.outline then
		x, y, w, h = x - self.outline.width, y - self.outline.width,
			w + self.outline.width, h + self.outline.width
	end

	return x, y, w, h
end

function Marquee:destroy()
	if self.canvas then self.canvas:release() end
	Marquee.super.destroy(self)
end

return Marquee
