---@class Object:Basic
local Object = Basic:extend("Object")

Object.showBoundary = false
Object.defaultAntialiasing = false

local floor, min, max = math.floor, math.min, math.max

local ffi = require("ffi")
ffi.cdef[[
	typedef struct {
		float x, y, rad, sx, sy, ox, oy, kx, ky;
		float minX, minY, maxX, maxY;
		float m11, m12, m21, m22, dx, dy; //  matrix compons
	} TransformData;
]]

function Object:setupDrawLogic(camera, initDraw)
	if initDraw == nil then initDraw = true end
	local x, y, rad, sx, sy, ox, oy = self.x, self.y, math.rad(self.angle),
		self.scale.x * self.zoom.x, self.scale.y * self.zoom.y,
		self.origin.x, self.origin.y

	if self.flipX then sx = -sx end
	if self.flipY then sy = -sy end

	if camera.pixelPerfect then
		x, y, ox, oy = floor(x), floor(y), floor(ox), floor(oy)
	end
	x, y = x + ox - self.offset.x - (camera.scroll.x * self.scrollFactor.x),
		y + oy - self.offset.y - (camera.scroll.y * self.scrollFactor.y)
	if camera.pixelPerfect then
		x, y, ox, oy = floor(x), floor(y), floor(ox), floor(oy)
	end
	if initDraw then
		love.graphics.setShader(self.shader)
		if self.blend == "multiply" then
			-- rgb op, alpha op, srcfacRGB, srcfacA, dtsfacRGB, dstFactorA
			love.graphics.setBlendState("add", "add", "dstcolor", "one", "oneminussrcalpha", "oneminussrcalpha")
		else
			love.graphics.setBlendMode(self.blend, self.blendMethod)
		end
		love.graphics.setColor(self:getDrawColor())
	end

	if Object.showBoundary then
		local d = self:getWorldBounds()
		local x1, y1, w1, h1 = d.minX, d.minY, d.maxX - d.minX, d.maxY - d.minY
		love.graphics.push("all")
		love.graphics.scale(1, 1)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("line", x1 - (camera.scroll.x * self.scrollFactor.x),
			y1 - (camera.scroll.y * self.scrollFactor.y), math.abs(w1), math.abs(h1))
		love.graphics.pop()
	end

	return x, y, rad, sx, sy, ox, oy, self.skew.x, self.skew.y
end

function Object:new(x, y)
	Object.super.new(self)

	self:setPosition(x, y)
	self.width, self.height = 0, 0

	self.offset = Point()
	self.origin = Point()
	self.scale = Point(1, 1)
	self.zoom = Point(1, 1)
	self.scrollFactor = Point(1, 1)
	self.skew = Point()
	self.flipX = false
	self.flipY = false

	self.shader = nil
	self.antialiasing = Object.defaultAntialiasing or false
	self.color = Color.WHITE
	self.blend = "alpha"
	self.blendMethod = nil

	self.alpha = 1
	self.angle = 0

	self.moves = false
	self.velocity = Point()
	self.acceleration = Point()

	-- self._transform = love.math.newTransform()
	self._data = ffi.new("TransformData") -- internal, never use
end

function Object:destroy()
	self.offset:zero()
	self.origin:zero()
	self.scale.x, self.scale.y = 1, 1
	if type(zoom) == "table" then self.zoom:set(1, 1) end

	self.skew:zero()
	self.velocity:zero()
	self.acceleration:zero()

	self.shader = nil
	self._data = nil
	Object.super.destroy(self)
end

function Object:setPosition(x, y)
	self.x, self.y = x or 0, y or 0
end

function Object:setScrollFactor(x, y)
	Logger.log("warn", "[ " .. tostring(self):upper() ..
		" ] setScrollFactor method is deprecated! Use scrollFactor:set", 4)
	self.scrollFactor:set(x or 0, y or 0)
end

function Object:getMidpoint()
	return self.x + self.width / 2, self.y + self.height / 2
end

function Object:screenCenter(axes)
	local centerAll = axes == nil or axes == "xy"
	if centerAll or axes == "x" then self.x = (game.width - self.width) / 2 end
	if centerAll or axes == "y" then self.y = (game.height - self.height) / 2 end
	return self
end

function Object:center(obj, axes)
	local centerAll = axes == nil or axes == "xy"
	local sw, sh = self.getWidth and self:getWidth() or self.width,
		self.getHeight and self:getHeight() or self.height

	if centerAll or axes == "x" then
		local w = obj.getWidth and obj:getWidth() or obj.width
		self.x = obj.x + (w - sw) / 2
	end
	if centerAll or axes == "y" then
		local h = obj.getHeight and obj:getHeight() or obj.height
		self.y = obj.y + (h - sh) / 2
	end
	return self
end

function Object:updateHitbox()
	local width, height
	if self.getWidth then width, height = self:getWidth(), self:getHeight() end
	self:fixOffsets(width, height)
	self:centerOrigin(width, height)
end

function Object:centerOffsets(__width, __height)
	self.offset.x = (__width or self.width) / 2
	self.offset.y = (__height or self.height) / 2
end

function Object:fixOffsets(__width, __height)
	self.offset.x = ((__width or self.width) - self.width) / 2
	self.offset.y = ((__height or self.height) - self.height) / 2
end

function Object:centerOrigin(__width, __height)
	self.origin.x = (__width or self.width) / 2
	self.origin.y = (__height or self.height) / 2
end

function Object:update(dt)
	if self.moves then
		self.velocity.x = self.velocity.x + self.acceleration.x * dt
		self.velocity.y = self.velocity.y + self.acceleration.y * dt

		self.x = self.x + self.velocity.x * dt
		self.y = self.y + self.velocity.y * dt
	end
end

local abs, rad, sin, cos = math.abs, math.rad, math.fastsin, math.fastcos

function Object:isOnScreen(cameras, x, y, w, h, sfx, sfy)
	local ox, oy, ow, oh
	if x then
		ox, oy, ow, oh = x, y, w, h
	else
		local d = self:getWorldBounds()
		ox, oy, ow, oh = d.minX, d.minY, d.maxX - d.minX, d.maxY - d.minY
	end

	if sfx == nil then sfx = self.scrollFactor and self.scrollFactor.x or 1 end
	if sfy == nil then sfy = self.scrollFactor and self.scrollFactor.y or 1 end

	if cameras.x then return cameras:_check(ox, oy, ow, oh, sfx, sfy) end
	for _, camera in pairs(cameras) do
		if camera:_check(ox, oy, ow, oh, sfx, sfy) then return true end
	end
	return false
end

function Object:canDraw()
	return self.alpha > 0 and (self.scale.x * self.zoom.x ~= 0 or
		self.scale.y * self.zoom.y ~= 0) and Object.super.canDraw(self)
end

function Object:getBoundaryTransform()
	local d = self._data
	local x, y = self.x, self.y
	local ox, oy, offx, offy = self.origin.x, self.origin.y, self.offset.x, self.offset.y
	local ang = math.rad(self.angle)
	local sx, sy = self.scale.x * self.zoom.x, self.scale.y * self.zoom.y
	local kx, ky = self.skew.x, self.skew.y

	if self.flipX then sx = -sx end
	if self.flipY then sy = -sy end

	if self.animation and self.animation.curAnim then
		local ax, ay = self.animation.curAnim:rotateOffset(self.angle, sx, sy)
		x, y = x - ax, y - ay
	end

	local dx, dy = x + ox - offx, y + oy - offy
	local frame = self.animation and self.animation:getCurrentFrame()
	local dox, doy = ox, oy

	if frame and type(frame) == "table" then
		local fox, foy = frame.offset and frame.offset.x or 0, frame.offset and frame.offset.y or 0
		if frame.rotated then
			ang, sx, sy, kx, ky = ang - math.pi / 2, sy, sx, ky, kx
			local _, _, qw, qh = frame.quad:getViewport()
			dox, doy = qw - (oy + foy), ox + fox
		else
			dox, doy = ox + fox, oy + foy
		end
	end

	local s, c = math.fastsin(ang), math.fastcos(ang)

	d.m11 = c * sx - ky * s * sy
	d.m12 = s * sx + ky * c * sy
	d.m21 = kx * c * sx - s * sy
	d.m22 = kx * s * sx + c * sy

	d.dx = dx - (dox * d.m11 + doy * d.m21)
	d.dy = dy - (dox * d.m12 + doy * d.m22)

	return d
end

function Object:getLocalBounds()
	local x, y, w, h = 0, 0

	if self.getFrameWidth then
		w, h = self:getFrameWidth(), self:getFrameHeight()
	elseif self.getWidth then
		w, h = self:getWidth(), self:getHeight()
	end
	if self.animation and self.animation.getCurrentFrame then
		local frame = self.animation:getCurrentFrame()
		if frame and type(frame) ~= "number" and frame.quad then
			local _, _, qw, qh = frame.quad:getViewport()
			w, h = qw, qh
		end
	end

	w, h = w or self.width or 0, h or self.height or 0

	return x, y, w, h
end

function Object:getWorldBounds()
	self:getBoundaryTransform()
	local d = self._data
	local lx, ly, lw, lh = self:getLocalBounds()
	local rx, ry = lx + lw, ly + lh

	local x0 = lx * d.m11 + ly * d.m21 + d.dx
	local y0 = lx * d.m12 + ly * d.m22 + d.dy
	local x1 = rx * d.m11 + ly * d.m21 + d.dx
	local y1 = rx * d.m12 + ly * d.m22 + d.dy
	local x2 = lx * d.m11 + ry * d.m21 + d.dx
	local y2 = lx * d.m12 + ry * d.m22 + d.dy
	local x3 = rx * d.m11 + ry * d.m21 + d.dx
	local y3 = rx * d.m12 + ry * d.m22 + d.dy

	d.minX = math.min(x0, x1, x2, x3)
	d.minY = math.min(y0, y1, y2, y3)
	d.maxX = math.max(x0, x1, x2, x3)
	d.maxY = math.max(y0, y1, y2, y3)

	return d
end

function Object:getMultColor(r, g, b, a)
	local r2, g2, b2, a2 = Color.get(self.color)
	return r2 * math.min(r, 1), g2 * math.min(g, 1), b2 * math.min(b, 1),
		self.alpha * (math.min(a or 1, 1))
end

function Object:getDrawColor(input)
	local color = input or self.color
	local r, g, b, a = Color.get(color)
	return r, g, b, a * self.alpha
end

return Object
