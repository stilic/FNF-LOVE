---@class Graphic:Object
local Graphic = Object:extend("Graphic")

function Graphic:new(x, y, width, height, color, type, fill, lined)
	Graphic.super.new(self, x, y)

	self.width = width or 120
	self.height = height or 50

	self.color = color or Color.BLACK
	self.type = type or "rectangle"
	self.fill = fill or "fill"
	self.lined = lined or false

	self.config = {
		type = "open",
		angle = Point(0, 360),
		round = Point(),
		segments = 36,
		vertices = {}
	}

	self.line = {
		width = 6,
		color = {1, 1, 1, 1},
		join = "miter"
	}
end

function Graphic:updateHitbox()
	Graphic.super.updateHitbox(self)
	if self.type ~= "polygon" or #self.config.vertices == 0 then return end

	local min, max, v = math.huge, -math.huge
	for i = 1, #self.config.vertices, 2 do
		v = self.config.vertices[i]
		min = math.min(min, v)
		max = math.max(max, v)
	end
	self.width = max - min

	min, max = math.huge, -math.huge
	for i = 2, #self.config.vertices, 2 do
		v = self.config.vertices[i]
		min = math.min(min, v)
		max = math.max(max, v)
	end
	self.height = max - min
end

function Graphic:getLocalBounds()
	if self.type ~= "polygon" or #self.config.vertices == 0 then
		return Graphic.super.getLocalBounds(self)
	end

	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge

	for i = 1, #self.config.vertices, 2 do
		local vx, vy = self.config.vertices[i], self.config.vertices[i+1]
		if vx < minX then minX = vx end
		if vx > maxX then maxX = vx end
		if vy < minY then minY = vy end
		if vy > maxY then maxY = vy end
	end

	local ox, oy = 0, 0
	return minX - ox, minY - oy, maxX - minX, maxY - minY
end

function Object:getWorldBounds()
	local d = self:getBoundaryTransform()
	local lx, ly, lw, lh = self:getLocalBounds()

	local x0 = lx * d.m11 + ly * d.m21 + d.dx
	local y0 = lx * d.m12 + ly * d.m22 + d.dy
	local x1 = (lx + lw) * d.m11 + ly * d.m21 + d.dx
	local y1 = (lx + lw) * d.m12 + ly * d.m22 + d.dy
	local x2 = lx * d.m11 + (ly + lh) * d.m21 + d.dx
	local y2 = lx * d.m12 + (ly + lh) * d.m22 + d.dy
	local x3 = (lx + lw) * d.m11 + (ly + lh) * d.m21 + d.dx
	local y3 = (lx + lw) * d.m12 + (ly + lh) * d.m22 + d.dy

	local minX = math.min(x0, x1, x2, x3)
	local minY = math.min(y0, y1, y2, y3)
	local maxX = math.max(x0, x1, x2, x3)
	local maxY = math.max(y0, y1, y2, y3)
	d.minX, d.minY, d.maxX, d.maxY = minX, minY, maxX, maxY
	return d
end

function Graphic:canDraw()
	return (self.width > 0 or self.height > 0 or
		#self.config.vertices ~= 0) and Graphic.super.canDraw(self)
end

local grap = love.graphics
local function drawShape(gtype, fill, ox, oy, w, h, rad, config, ang1, ang2)
	if gtype == "rectangle" then
		grap.rectangle(fill, -ox, -oy, w, h, config.round[1], config.round[2], config.segments)
	elseif gtype == "polygon" and config.vertices then
		grap.translate(-ox, -oy)
		grap.polygon(fill, config.vertices)
		grap.translate(ox, oy)
	elseif gtype == "circle" then
		if w == h then
			grap.circle(fill, rad - ox, rad - oy, rad, config.segments)
		else
			local hx, hy = w / 2, h / 2
			grap.ellipse(fill, hx - ox, hy - oy, hx, hy, config.segments)
		end
	elseif gtype == "arc" then
		grap.arc(fill, config.type, rad - ox, rad - oy, rad, ang1, ang2,
			math.ceil(config.segments * math.min((ang2 - ang1) / (math.pi * 2), 1)))
	end
end

function Graphic:__render(camera)
	grap.push("all")

	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	local w, h = self.width, self.height
	local line = self.line
	local linesize = line.width

	grap.setLineStyle(self.antialiasing and "smooth" or "rough")
	grap.setLineWidth(linesize)
	grap.setLineJoin(line.join)

	local config = self.config
	local ang1, ang2 = 0, 0
	if config.angle then
		local pi180 = math.pi / 180
		ang1, ang2 = config.angle[1] * pi180, config.angle[2] * pi180
	end

	local drawW, drawH = w, h
	local drawX, drawY = x, y
	if self.fill == "line" then
		drawX, drawY = x + linesize / 2, y + linesize / 2
		drawW, drawH = w - linesize, h - linesize
	end
	local circleRad = math.min(drawW, drawH) / 2

	grap.translate(drawX, drawY)
	grap.rotate(rad)
	grap.scale(sx, sy)
	grap.shear(kx, ky)

	drawShape(self.type, self.fill, ox, oy, drawW, drawH, circleRad, config, ang1, ang2)

	if self.lined then
		grap.setColor(self:getDrawColor(line.color))
		drawShape(self.type, "line", ox, oy, drawW, drawH, circleRad, config, ang1, ang2)
	end

	grap.pop()
end

return Graphic
