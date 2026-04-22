local stencilSprite, stencilX, stencilY = nil, 0, 0
local function stencil()
	if stencilSprite then
		love.graphics.push()
		love.graphics.translate(stencilX + stencilSprite.clipRect.x +
			stencilSprite.clipRect.width / 2,
			stencilY + stencilSprite.clipRect.y +
			stencilSprite.clipRect.height / 2)
		love.graphics.rotate(stencilSprite.angle)
		love.graphics.translate(-stencilSprite.clipRect.width / 2,
			-stencilSprite.clipRect.height / 2)
		love.graphics.rectangle("fill", -stencilSprite.width / 2,
			-stencilSprite.height / 2,
			stencilSprite.clipRect.width,
			stencilSprite.clipRect.height)
		love.graphics.pop()
	end
end

local FrameCollection = loxreq "animation.frame.collection"
local Animation = loxreq "animation"
local Frame = loxreq "animation.frame"

---@class Sprite:Object
local Sprite = Object:extend("Sprite")

function Sprite:new(x, y, texture)
	Sprite.super.new(self, x, y)

	self.texture = Sprite.defaultTexture
	self.clipRect = nil
	self.frames = nil
	self.animation = Animation(self)

	-- DEPRECATED!!
	self.__frames = self.frames
	self.__animations = self.animation.animations

	self.__width, self.__height = self.width, self.height
	if texture then self:loadTexture(texture) end
end

function Sprite:destroy()
	Sprite.super.destroy(self)

	self.texture = nil
	self.frames = nil
	if self.animation then self.animation:destroy() end
	self.animation = nil
end

function Sprite:loadTexture(texture, animated, frameWidth, frameHeight)
	if type(texture) == "string" then
		texture = love.graphics.newImage(texture)
	end
	self.texture = texture or Sprite.defaultTexture

	if frameWidth == nil then frameWidth = 0 end
	if frameWidth == 0 then
		frameWidth = animated and self.texture:getHeight() or
			self.texture:getWidth()
		frameWidth = (frameWidth > self.texture:getWidth()) or
			self.texture:getWidth() or frameWidth
	elseif frameWidth > self.texture:getWidth() then
		print('frameWidth: ' .. frameWidth ..
			' is larger than the graphic\'s width: ' ..
			self.texture:getWidth())
	end
	self.width = frameWidth

	if frameHeight == nil then frameHeight = 0 end
	if frameHeight == 0 then
		frameHeight = animated and frameWidth or self.texture:getHeight()
		frameHeight = (frameHeight > self.texture:getHeight()) or
			self.texture:getHeight() or frameHeight
	elseif frameHeight > self.texture:getHeight() then
		print('frameHeight: ' .. frameHeight ..
			' is larger than the graphic\'s height: ' ..
			self.texture:getHeight())
	end
	self.height = frameHeight

	self.__width, self.__height = self.width, self.height

	if animated then
		self.frames = FrameCollection.fromTiles(texture, {x = frameWidth, y = frameHeight})
		self.__frames = self.frames.frames
	end

	return self
end

function Sprite:loadTextureFromSprite(sprite)
	self.texture = sprite.texture
	self.antialiasing = sprite.antialiasing

	self.width, self.height = sprite.width, sprite.height
	self.__width, self.__height = self.width, self.height

	if sprite.frames then
		self.frames = sprite.frames
	end

	return self
end

function Sprite:getFrameWidth()
	local f = self.animation and self.animation:getCurrentFrame()
	return f and f.width or (self.texture and self.texture:getWidth()) or 0
end

function Sprite:getFrameHeight()
	local f = self.animation and self.animation:getCurrentFrame()
	return f and f.height or (self.texture and self.texture:getHeight()) or 0
end

function Sprite:getFrameDimensions() return self:getFrameWidth(), self:getFrameHeight() end

function Sprite:getGraphicMidpoint()
	return self.x + self:getFrameWidth() / 2,
		self.y + self:getFrameHeight() / 2
end

function Sprite:setGraphicSize(width, height)
	if width == nil then width = 0 end
	if height == nil then height = 0 end

	self.scale.x = width / self:getFrameWidth()
	self.scale.y = height / self:getFrameHeight()

	if width <= 0 then
		self.scale.x = self.scale.y
	elseif height <= 0 then
		self.scale.y = self.scale.x
	end
end

function Sprite:updateHitbox()
	local width, height = self:getFrameDimensions()

	self.width = math.abs(self.scale.x * self.zoom.x) * width
	self.height = math.abs(self.scale.y * self.zoom.y) * height
	self.__width, self.__height = self.width, self.height

	self:fixOffsets(width, height)
	self:centerOrigin(width, height)
end

function Sprite:centerOffsets(width, height)
	self.offset.x = (width or self:getFrameWidth()) / 2
	self.offset.y = (height or self:getFrameHeight()) / 2
end

function Sprite:fixOffsets(width, height)
	self.offset.x = (self.width - (width or self:getFrameWidth())) / -2
	self.offset.y = (self.height - (height or self:getFrameHeight())) / -2
end

function Sprite:centerOrigin(width, height)
	self.origin.x = (width or self:getFrameWidth()) / 2
	self.origin.y = (height or self:getFrameHeight()) / 2
end

function Sprite:update(dt)
	if self.__width ~= self.width or self.__height ~= self.height then
		self:setGraphicSize(self.width, self.height)
		self.__width, self.__height = self.width, self.height
	end
	if self.animation then self.animation:update(dt) end
	Sprite.super.update(self, dt)
end

function Sprite:canDraw()
	return self.texture ~= nil and (self.width ~= 0 or self.height ~= 0) and
		Sprite.super.canDraw(self)
end

function Sprite:__render(camera)
	love.graphics.push("all")
	local f, texture = self:getCurrentFrame(), self.texture
	if f and f.texture then texture = f.texture end

	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)

	if self.animation.curAnim then
		local ax, ay = self.animation.curAnim:rotateOffset(self.angle, sx, sy)
		x, y = x - ax, y - ay
	end

	if f then
		if f.rotated then
			rad = rad - math.pi/2
			ox, oy = select(3, f.quad:getViewport()) - (oy + f.offset.y), ox + f.offset.x
			sx, sy, kx, ky = sy, sx, ky, kx
		else
			ox, oy = ox + f.offset.x, oy + f.offset.y
		end
	end

	if self.clipRect then
		stencilSprite, stencilX, stencilY = self, x, y
		love.graphics.stencil(stencil, "replace", 1, false)
		love.graphics.setStencilTest("greater", 0)
	end

	local min, mag, anisotropy = texture:getFilter()
	local mode = self.antialiasing and "linear" or "nearest"
	texture:setFilter(mode, mode, anisotropy)

	if f then
		love.graphics.draw(texture, f.quad, x, y, rad, sx, sy, ox, oy, kx, ky)
	else
		love.graphics.draw(texture, x, y, rad, sx, sy, ox, oy, kx, ky)
	end
	texture:setFilter(min, mag, anisotropy)

	love.graphics.pop()
end

function Sprite:_markDeprecated(func, new)
	local str = "%s is deprecated, use %s."
	Logger.log("warn", str:format(func, new), 5)
end

function Sprite.newFrame(name, x, y, w, h, sw, sh, ox, oy, ow, oh, r)
	Sprite._markDeprecated("Sprite", "Sprite.newFrame", "Frame")
	return Frame(name, x, y, w, h, sw, sh, ox, oy, ow, oh, r)
end

function Sprite.getFramesFromSparrow(texture, description)
	Sprite._markDeprecated("Sprite", "Sprite.getFramesFromSparrow", "FrameCollection.fromSparrow")
	return FrameCollection.fromSparrow(texture, description)
end

function Sprite.getFramesFromPacker(texture, description)
	Sprite._markDeprecated("Sprite", "Sprite.getFramesFromPacker", "FrameCollection.fromPacker")
	return FrameCollection.fromPacker(texture, description)
end

function Sprite.getTiles(texture, tileSize, region, tileSpacing)
	Sprite._markDeprecated("Sprite", "Sprite.getTiles", "FrameCollection.fromTiles")
	return FrameCollection.fromTiles(texture, tileSize, region, tileSpacing)
end

function Sprite:addAnim(name, frameIndices, framerate, looped)
	self:_markDeprecated("addAnim", "animation:add")
	self.animation:add(name, frameIndices, framerate, looped)
end

function Sprite:addAnimByPrefix(name, prefix, framerate, looped)
	self:_markDeprecated("addAnimByPrefix", "animation:addByPrefix")
	self.animation:addByPrefix(name, prefix, framerate, looped)
end

function Sprite:addAnimByIndices(name, prefix, indices, postfix, framerate, looped)
	self:_markDeprecated("addAnimByIndices", "animation:addByIndices")
	self.animation:addByIndices(name, prefix, indices, postfix, framerate, looped)
end

function Sprite:play(...)
	self:_markDeprecated("play", "animation:play"); self.animation:play(...)
end

function Sprite:pause()
	self:_markDeprecated("pause", "animation:pause"); self.animation:pause()
end

-- function Sprite:resume() -- this is getting called by Group lmao
	-- self:_markDeprecated("resume", "animation:resume"); self.animation:resume()
-- end

function Sprite:stop()
	self:_markDeprecated("stop", "animation:stop"); self.animation:stop()
end

function Sprite:finish()
	self:_markDeprecated("finish", "animation:finish"); self.animation:finish()
end

function Sprite:setFrames(collection)
	if not collection then return end
	-- self:_markDeprecated("setFrames")
	self.frames = collection
	self.texture = collection.texture

	self.__frames = self.frames.frames

	self.width, self.height = self:getFrameDimensions()
	self.__width, self.__height = self.width, self.height
	self:centerOrigin()
end

function Sprite:getCurrentFrame()
	-- self:_markDeprecated("getCurrentFrame", "animation:getCurrentFrame")
	return self.animation:getCurrentFrame()
end

return Sprite
