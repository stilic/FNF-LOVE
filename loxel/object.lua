---@class Object:Basic
local Object = Basic:extend("Object")

Object.showBoundary = false
Object.defaultAntialiasing = false

local floor, min, max = math.floor, math.min, math.max

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
		love.graphics.setBlendMode(self.blend, self.blendMethod)
		love.graphics.setColor(self:getDrawColor())
	end

	if Object.showBoundary then
		local x1, y1, w1, h1 = self:getWorldBounds()
		love.graphics.push("all")
		love.graphics.scale(1, 1)
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

	self._transform = love.math.newTransform() -- internal, never use
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
	self._transform = nil
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
	if self._boundsCache then self._boundsCache.dirty = true end
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
local function checkCamera(camera, ox, oy, ow, oh, sfx, sfy)
	local x = ox - camera.scroll.x * sfx
	local y = oy - camera.scroll.y * sfy
	local cx, cy, cw, ch, csx, csy, cox, coy = camera:_getCameraBoundary()

	local hw1, hw2, hh1, hh2 = ow / 2, cw / 2, oh / 2, ch / 2
	local rad2 = rad(camera.angle or 0)
	local sin2, cos2 = abs(sin(rad2)), abs(cos(rad2))

	return abs(cx + hw2 - x - hw1) - hw1 - hw2 * cos2 * csx - hh2 * sin2 * csy < 0 and
		abs(cy + hh2 - y - hh1) - hh1 - hh2 * cos2 * csy - hw2 * sin2 * csx < 0
end

function Object:isOnScreen(cameras, x, y, w, h, sfx, sfy)
	local ox, oy, ow, oh
	if x then
		ox, oy, ow, oh = x, y, w, h
	else
		ox, oy, ow, oh = self:getWorldBounds()
	end

	if sfx == nil then sfx = self.scrollFactor and self.scrollFactor.x or 1 end
	if sfy == nil then sfy = self.scrollFactor and self.scrollFactor.y or 1 end

	if cameras.x then return checkCamera(cameras, ox, oy, ow, oh, sfx, sfy) end
	for _, camera in pairs(cameras) do
		if checkCamera(camera, ox, oy, ow, oh, sfx, sfy) then return true end
	end
	return false
end

function Object:_canDraw()
	return self.alpha > 0 and (self.scale.x * self.zoom.x ~= 0 or
		self.scale.y * self.zoom.y ~= 0) and Object.super._canDraw(self)
end

function Object:getBoundaryTransform()
	self._transform:reset()
	local x, y = self.x, self.y
	local ox, oy, offx, offy = self.origin.x, self.origin.y, self.offset.x, self.offset.y
	local ang, sx, sy = math.rad(self.angle), self.scale.x * self.zoom.x, self.scale.y * self.zoom.y
	local kx, ky = self.skew.x, self.skew.y
	if self.flipX then sx = -sx end; if self.flipY then sy = -sy end

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
			dox, doy = select(3, frame.quad:getViewport()) - (oy + foy), ox + fox
		else
			dox, doy = ox + fox, oy + foy
		end
	end
	self._transform:translate(dx, dy):rotate(ang):scale(sx, sy):shear(kx, ky):translate(-dox, -doy)
	return self._transform
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
	local t, lx, ly, lw, lh = self:getBoundaryTransform(), self:getLocalBounds()
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for i = 0, 3 do
		local x, y = t:transformPoint(lx + (i % 2) * lw, ly + floor(i / 2) * lh)
		minX, maxX, minY, maxY = min(minX, x), max(maxX, x), min(minY, y), max(maxY, y)
	end
	return minX, minY, maxX - minX, maxY - minY
end

function Object:getMultColor(r, g, b, a)
	local r2, g2, b2, a2 = Color.get(self.color)
	return r2 * math.min(r, 1), g2 * math.min(g, 1), b2 * math.min(b, 1),
		self.alpha * (math.min(a or 1, 1))
end

function Object:getDrawColor(input)
	local r, g, b, a = 1, 1, 1, self.alpha
	local color = input or self.color
	if type(color) == "table" then
		r, g, b, a = color[1], color[2], color[3], (color[4] or 1) * self.alpha
	end
	return r, g, b, a
end

return Object
