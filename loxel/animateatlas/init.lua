local maskShader

local Library = loxreq "animateatlas.library"
local AnimationController = loxreq "animateatlas.animation"
local Boundary = loxreq "animateatlas.boundary"
local Matrix = loxreq "animateatlas.matrix"
local ColorTransform = loxreq "animateatlas.color"

local AnimateAtlas = Object:extend("AnimateAtlas")
AnimateAtlas:implement(Boundary)

function AnimateAtlas:new(x, y, library)
	AnimateAtlas.super.new(self, x, y)
	self.frame = 0
	self.symbol = ""

	if library then self:load(library) end

	self._curSymbol = nil
	self._frameTimer = 0
	self._drawBatches = {}
	self._hasColorEffects = false

	self.animation = AnimationController(self)
	self.colorTransform = ColorTransform()

	if not maskShader then
		maskShader = love.graphics.newShader[[
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			float alpha = Texel(texture, texture_coords).a;
			if (alpha == 0.0) { discard; }
			return vec4(alpha);
		}]]
	end
end

function AnimateAtlas:load(library)
	if self._mustRelease then
		self.library:destroy()
	end
	self._mustRelease = false

	if type(library) == 'string' then
		self.library = Library(library)
		self._mustRelease = true
	elseif type(library) == 'table' and library.is and library:is(AnimateLibrary) then
		self.library = library
	else
		error("incorrect type loaded, it must be a AnimateLibrary object or a string")
	end
	self:updateHitbox()
end

local function renderSymbol(self, symbol, frame, index, matrix, colorTransform, optimized)
	local symbolName = symbol[optimized and "SN" or "SYMBOL_name"]
	local firstFrame = symbol[optimized and "FF" or "firstFrame"] or 0
	local frameIndex = firstFrame + (frame - index)
	local symbolType = symbol[optimized and "ST" or "symbolType"]
	if symbolType == "movieclip" or symbolType == "MC" then frameIndex = 0 end
	local loopMode = symbol[optimized and "LP" or "loop"]
	local library = self.library.libraries[symbolName]
	local symbolTimeline = library.data
	local length = self.library:getTimelineLength(symbolTimeline)

	if loopMode == "loop" or loopMode == "LP" then
		if frameIndex < 0 then frameIndex = length - 1
		else while frameIndex > length - 1 do frameIndex = frameIndex - length end end
	elseif loopMode == "playonce" or loopMode == "PO" then
		frameIndex = math.max(0, math.min(frameIndex, length - 1))
	elseif loopMode == "singleframe" or loopMode == "SF" then
		frameIndex = firstFrame
	end

	local is3DMatrix = symbol[optimized and "M3D" or "Matrix3D"] ~= nil
	local symbolMatrix = love.math.newTransform()
	symbolMatrix:setMatrix((is3DMatrix and Matrix._3D or Matrix._2D)(is3DMatrix and
		symbol[optimized and "M3D" or "Matrix3D"] or symbol[optimized and "MX" or "Matrix"], optimized))
	self:drawTimeline(symbolTimeline, frameIndex, matrix:clone():apply(symbolMatrix),
		self.colorTransform:mergeTransforms(colorTransform, symbol[optimized and "C" or "color"], optimized))
end

local function addSpriteToBatch(self, sprite, spritemap, spriteMatrix, matrix, colorTransform, optimized)
	local texture = spritemap.texture
	local drawMatrix = matrix * spriteMatrix

	if sprite.rotated then
		drawMatrix:translate(0,sprite.w)
		drawMatrix:rotate(-math.pi/2)
	end

	if self.colorTransform:hasEffects(colorTransform, optimized) then
		self._hasColorEffects = true
	end

	if not self._drawBatches[texture] then
		self._drawBatches[texture] = {
			texture = texture,
			sprites = {}
		}
	end

	table.insert(self._drawBatches[texture].sprites, {
		quad = love.graphics.newQuad(sprite.x, sprite.y, sprite.w, sprite.h, texture:getWidth(), texture:getHeight()),
		transform = drawMatrix:clone(),
		colorTransform = colorTransform,
		optimized = optimized
	})
end

local function renderAtlasSprite(self, atlasSprite, matrix, colorTransform, optimized)
	local name = atlasSprite[optimized and "N" or "name"]
	local is3DMatrix = atlasSprite[optimized and "M3D" or "Matrix3D"] ~= nil

	local spriteMatrixRaw = nil
	if is3DMatrix then
		spriteMatrixRaw = atlasSprite[optimized and "M3D" or "Matrix3D"]
	else
		spriteMatrixRaw = atlasSprite[optimized and "MX" or "Matrix"]
	end
	local spriteMatrix = love.math.newTransform()
	spriteMatrix:setMatrix((is3DMatrix and Matrix._3D or Matrix._2D)(spriteMatrixRaw, optimized))

	local spritemaps = self.library.spritemaps
	for l = 1, #spritemaps do
		local spritemap = spritemaps[l]
		local sprites = spritemap.data.ATLAS.SPRITES
		for z = 1, #sprites do
			local sprite = sprites[z].SPRITE

			if sprite.name == name then
				addSpriteToBatch(self, sprite, spritemap, spriteMatrix, matrix, colorTransform, optimized)
				break
			end
		end
	end
end

local function renderKeyFrame(self, keyframe, frame, matrix, colorTransform, optimized)
	local index = keyframe[optimized and "I" or "index"]
	local duration = keyframe[optimized and "DU" or "duration"]

	if not (frame >= index and frame < index + duration) then
		return false
	end
	local elements = keyframe[optimized and "E" or "elements"]

	for k = 1, #elements do
		local element = elements[k]

		local symbol = element[optimized and "SI" or "SYMBOL_Instance"]
		local atlasSprite = element[optimized and "ASI" or "ATLAS_SPRITE_instance"]

		if symbol then
			self._curSymbol = { data = symbol, index = index }
			renderSymbol(self, symbol, frame, index, matrix, colorTransform, optimized)
		elseif atlasSprite then
			renderAtlasSprite(self, atlasSprite, matrix, colorTransform, optimized)
		end
	end

	return true
end

function AnimateAtlas:drawTimeline(timeline, frame, matrix, colorTransform)
	local optimized = timeline.L ~= nil
	local timelineLayers = timeline[optimized and "L" or "LAYERS"]
	local namesToLayers = {}

	for i = #timelineLayers, 1, -1 do
		local layer = timelineLayers[i]
		namesToLayers[layer[optimized and "LN" or "Layer_name"]] = layer
	end

	for i = #timelineLayers, 1, -1 do
		local layer = timelineLayers[i]
		local keyframes = layer[optimized and "FR" or "Frames"]
		local layerType = layer[optimized and "LT" or "Layer_type"]
		local clippedBy = layer[optimized and "CB" or "Clipped_by"]

		if layerType ~= nil then
			goto continue
		end

		if clippedBy ~= nil then
			love.graphics.clear(false, true, false)
			love.graphics.setStencilState("replace", "always", 1)

			local maskLayer = namesToLayers[clippedBy]
			local maskKeyframes = maskLayer[optimized and "FR" or "Frames"]
			love.graphics.setShader(maskShader)
			for j = 1, #maskKeyframes do
				if renderKeyFrame(self, maskKeyframes[j], frame, matrix, nil, optimized) then
					break
				end
			end
			love.graphics.setShader()

			love.graphics.setStencilState("keep", "greater", 0)
		end

		for j = 1, #keyframes do
			if renderKeyFrame(self, keyframes[j], frame, matrix, colorTransform, optimized) then
				break
			end
		end

		if clippedBy ~= nil then
			love.graphics.clear(false, true, false)
			love.graphics.setStencilState()
		end
		::continue::
	end
end

function AnimateAtlas:update(dt)
	AnimateAtlas.super.update(self, dt)

	if not self.library then return end
	self.animation:update(dt)
end

function AnimateAtlas:flush()
	if self._hasColorEffects then
		for texture, batch in pairs(self._drawBatches) do
			for i = 1, #batch.sprites do
				local spriteData = batch.sprites[i]
				local lastShader = love.graphics.getShader()
				local lastBlendMode = love.graphics.getBlendMode()

				if spriteData.colorTransform then
					love.graphics.setShader(self.colorTransform:getShader())
					self.colorTransform:applyRawTransform(spriteData.colorTransform, spriteData.optimized)

					local blendMode = self.colorTransform:getBlendMode(spriteData.colorTransform, spriteData.optimized)
					love.graphics.setBlendMode(blendMode)
				end

				love.graphics.draw(texture, spriteData.quad, spriteData.transform)

				if spriteData.colorTransform then
					love.graphics.setShader(lastShader)
					love.graphics.setBlendMode(lastBlendMode)
				end
			end
		end
	else
		for texture, batch in pairs(self._drawBatches) do
			for i = 1, #batch.sprites do
				local spriteData = batch.sprites[i]
				love.graphics.draw(texture, spriteData.quad, spriteData.transform)
			end
		end
	end

	for k in pairs(self._drawBatches) do self._drawBatches[k] = nil end
	self._hasColorEffects = false
end

function AnimateAtlas:updateHitbox()
	if not self.library then
		self.width, self.height = 0, 0
		return
	end

	self.width, self.height = self:getBoundDimensions()
	self:fixOffsets()
	self:centerOrigin()
end

function AnimateAtlas:__draw(x, y, r, sx, sy, ox, oy, kx, ky)
	if not self.library then return end

	local identity = love.math.newTransform()
	x, y = x or 0, y or 0
	sx, sy = sx or 1, sy or 1
	ox, oy = ox or 0, oy or 0
	r = r or 0
	kx, ky = kx or 0, ky or 0

	if self.animation and self.animation.curAnim then
		local ax, ay = self.animation.curAnim:rotateOffset(r, sx, sy)
		x, y = x - ax, y - ay
	end

	identity:translate(x, y)
	identity:translate(ox, oy)
	identity:rotate(r)
	identity:scale(sx, sy)
	identity:shear(kx, ky)
	identity:translate(-ox, -oy)

	local timeline = self.library:getSymbolTimeline(self.symbol)
	if timeline.data then
		timeline = timeline.data[timeline.optimized and "AN" or "ANIMATION"][timeline.optimized and "TL" or "TIMELINE"]
	end
	self._curSymbol = nil
	self:drawTimeline(timeline, self.frame, identity, nil)
	self:flush()
end

function AnimateAtlas:isOnScreen() return true end
function AnimateAtlas:_isOnScreen() return true end

AnimateAtlas._canDraw = Object._canDraw

function AnimateAtlas:__render(camera)
	love.graphics.push("all")
	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	self:__draw(x, y, rad, sx, sy, ox, oy, kx, ky)
	love.graphics.pop()
end

function AnimateAtlas:destroy()
	AnimateAtlas.super.destroy(self)
	if self._mustRelease then self.library:destroy() end
	if self.colorTransform then self.colorTransform:destroy() end
end

return AnimateAtlas
