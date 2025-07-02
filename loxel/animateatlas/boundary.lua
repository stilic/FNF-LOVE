local Matrix = loxreq "animateatlas.matrix"
local AnimateAtlasBoundary = Classic:extend("AnimateAtlasBoundary")
-- meant to be used with Class:implement!

local calcTL, calcKF, calcAS, calcS

calcTL = function(self, timeline, frame, matrix, bounds)
	local optimized = timeline.L ~= nil
	local timelineLayers = timeline[optimized and "L" or "LAYERS"]
	local foundSprites = false

	for i = #timelineLayers, 1, -1 do
		local layer = timelineLayers[i]
		if layer[optimized and "LT" or "Layer_type"] then
			goto continue
		end

		local keyframes = layer[optimized and "FR" or "Frames"]

		local activeKeyframe = nil
		for j = 1, #keyframes do
			local kf = keyframes[j]
			local index = kf[optimized and "I" or "index"]
			local duration = kf[optimized and "DU" or "duration"]

			if frame >= index and frame < index + duration then
				activeKeyframe = kf
				break
			end
		end

		if activeKeyframe then
			if calcKF(self, activeKeyframe, frame, matrix, optimized, bounds) then
				foundSprites = true
			end
		end

		::continue::
	end

	return foundSprites
end

calcKF = function(self, keyframe, frame, matrix, optimized, bounds)
	local elements = keyframe[optimized and "E" or "elements"]
	local foundSprites = false
	local index = keyframe[optimized and "I" or "index"]

	for k = 1, #elements do
		local element = elements[k]
		local symbol = element[optimized and "SI" or "SYMBOL_Instance"]
		local atlas = element[optimized and "ASI" or "ATLAS_SPRITE_Instance"]

		if symbol then
			if calcS(self, symbol, frame, index, matrix, optimized, bounds) then
				foundSprites = true
			end
		elseif atlas then
			if calcAS(self, atlas, matrix, optimized, bounds) then
				foundSprites = true
			end
		end
	end

	return foundSprites
end

calcS = function(self, symbol, frame, index, matrix, optimized, bounds)
	local symbolName = symbol[optimized and "SN" or "SYMBOL_name"]
	local firstFrame = symbol[optimized and "FF" or "firstFrame"] or 0

	local frameIndex = firstFrame + (frame - index)
	local symbolType = symbol[optimized and "ST" or "symbolType"]
	if symbolType == "movieclip" or symbolType == "MC" then
		frameIndex = 0
	end

	local loopMode = symbol[optimized and "LP" or "loop"]

	local libraries = self.library.libraries
	local library = libraries[symbolName]
	if not library then return false end

	local symbolTimeline = library.data
	local length = self.library:getTimelineLength(symbolTimeline)

	if loopMode == "loop" or loopMode == "LP" then
		if frameIndex < 0 then
			frameIndex = length - 1
		elseif frameIndex >= length then
			frameIndex = frameIndex % length
		end
	elseif loopMode == "playonce" or loopMode == "PO" then
		frameIndex = math.max(0, math.min(frameIndex, length - 1))
	elseif loopMode == "singleframe" or loopMode == "SF" then
		frameIndex = firstFrame
	end

	local is3DMatrix = symbol[optimized and "M3D" or "Matrix3D"] ~= nil
	local symbolMatrix = love.math.newTransform()
	local symbolMatrixRaw = is3DMatrix and symbol[optimized and "M3D" or "Matrix3D"] or symbol[optimized and "MX" or "Matrix"]
	symbolMatrix:setMatrix((is3DMatrix and Matrix._3D or Matrix._2D)(symbolMatrixRaw, optimized))

	local combinedMatrix = matrix:clone():apply(symbolMatrix)
	return calcTL(self, symbolTimeline, frameIndex, combinedMatrix, bounds)
end

calcAS = function(self, atlasSprite, matrix, optimized, bounds)
	local name = atlasSprite[optimized and "N" or "name"]

	local sprite = nil
	local spritemaps = self.library.spritemaps
	for l = 1, #spritemaps do
		local spritemap = spritemaps[l]
		local sprites = spritemap.data.ATLAS.SPRITES
		for z = 1, #sprites do
			local s = sprites[z].SPRITE
			if s.name == name then
				sprite = s
				goto found_sprite
			end
		end
	end

	::found_sprite::
	if not sprite then return false end

	local is3DMatrix = atlasSprite[optimized and "M3D" or "Matrix3D"] ~= nil
	local spriteMatrixRaw = is3DMatrix and atlasSprite[optimized and "M3D" or "Matrix3D"] or atlasSprite[optimized and "MX" or "Matrix"]
	local spriteMatrix = love.math.newTransform()
	spriteMatrix:setMatrix((is3DMatrix and Matrix._3D or Matrix._2D)(spriteMatrixRaw, optimized))

	local drawMatrix = matrix:clone():apply(spriteMatrix)
	local w, h = sprite.w, sprite.h

	if sprite.rotated then
		drawMatrix:translate(0, w)
		drawMatrix:rotate(-math.pi/2)
		w, h = h, w
	end
	local x1, y1 = drawMatrix:transformPoint(0, 0)
	local x2, y2 = drawMatrix:transformPoint(w, 0)
	local x3, y3 = drawMatrix:transformPoint(w, h)
	local x4, y4 = drawMatrix:transformPoint(0, h)

	local minX = math.min(x1, x2, x3, x4)
	local minY = math.min(y1, y2, y3, y4)
	local maxX = math.max(x1, x2, x3, x4)
	local maxY = math.max(y1, y2, y3, y4)

	bounds.minX = math.min(bounds.minX, minX)
	bounds.minY = math.min(bounds.minY, minY)
	bounds.maxX = math.max(bounds.maxX, maxX)
	bounds.maxY = math.max(bounds.maxY, maxY)

	return true
end

function AnimateAtlasBoundary:getBoundTopLeft()
	if not self.library then return 0, 0 end

	local timeline = self.library:getSymbolTimeline(self.symbol)
	if timeline.data then
		timeline = timeline.data[timeline.optimized and "AN" or "ANIMATION"][timeline.optimized and "TL" or "TIMELINE"]
	end

	local bounds = {minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge}
	local identity = love.math.newTransform()

	local foundSprites = calcTL(self, timeline, self.frame, identity, bounds)

	if foundSprites and bounds.minX ~= math.huge and bounds.minY ~= math.huge then
		return bounds.minX, bounds.minY
	end
	return 0, 0
end

function AnimateAtlasBoundary:getBoundDimensions()
	local width, height = 0, 0

	local timeline = self.library:getSymbolTimeline(self.symbol)
	if timeline.data then
		timeline = timeline.data[timeline.optimized and "AN" or "ANIMATION"][timeline.optimized and "TL" or "TIMELINE"]
	end

	local bounds = {minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge}
	local identity = love.math.newTransform()

	local foundSprites = calcTL(self, timeline, self.frame, identity, bounds)

	if foundSprites and bounds.minX ~= math.huge and bounds.maxX ~= -math.huge then
		width = math.max(0, bounds.maxX - bounds.minX)
		height = math.max(0, bounds.maxY - bounds.minY)
	end

	return width, height
end

return AnimateAtlasBoundary
