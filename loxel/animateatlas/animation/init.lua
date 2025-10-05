local Animation = loxreq "animateatlas.animation.instance"
local AnimationController = loxreq "animation"

---@class AnimateAtlasController:AnimationController
local AnimateAtlasController = AnimationController:extend("AnimateAtlasController")
AnimateAtlasController:exclude("add", "addByPrefix", "addByIndices")

function AnimateAtlasController:add(name, symbol, framerate, looped)
	if not self.sprite.library then
		Toast.error("[ANIMATE ATLAS] No library loaded")
		return false
	end

	local timeline = self.sprite.library:getSymbolTimeline(symbol)
	if not timeline then
		Toast.error("[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if framerate == nil then framerate = self.sprite.library.framerate or 30 end
	if looped == nil then looped = false end

	local length = self.sprite.library:getTimelineLength(timeline)
	local indices = {}
	for i = 0, length - 1 do
		table.insert(indices, i)
	end

	self.animations[name] = Animation(self, name, symbol, indices, framerate, looped)
	return true
end

function AnimateAtlasController:addFromLibrary(name, anim, symbol, framerate, looped)
	if not self.sprite.library or not anim then return false end

	symbol = symbol or ""
	local timeline = self.sprite.library:getSymbolTimeline(symbol)
	if not timeline then return false end

	local timelineData = timeline
	if timeline.data then
		local optimized = timeline.optimized == true or timeline.data.L ~= nil
		timelineData = timeline.data[optimized and "AN" or "ANIMATION"][optimized and "TL" or "TIMELINE"]
	end

	local optimized = timelineData.L ~= nil
	local timelineLayers = timelineData[optimized and "L" or "LAYERS"]

	local startf, endf, loop
	for i = 1, #timelineLayers do
		local layer = timelineLayers[i]
		local keyframes = layer[optimized and "FR" or "Frames"]

		for j = 1, #keyframes do
			local keyframe = keyframes[j]
			local kfName = keyframe[optimized and "N" or "name"] or keyframe.N

			if kfName == anim then
				startf = keyframe[optimized and "I" or "index"]
				local dur = keyframe[optimized and "DU" or "duration"]
				endf = startf + dur - 1
				break
			end
		end
	end

	if startf then
		return self:addByRange(name, symbol, startf, endf, framerate, looped)
	end
	return false
end

function AnimateAtlasController:addByIndices(name, symbol, indices, framerate, looped)
	if not self.sprite.library then
		Toast.error("[ANIMATE ATLAS] No library loaded")
		return false
	end

	local timeline = self.sprite.library:getSymbolTimeline(symbol)
	if not timeline then
		Toast.error("[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if not indices or #indices == 0 then
		Toast.error("[ANIMATE ATLAS] Indices table cannot be empty")
		return false
	end

	local timelineLength = self.sprite.library:getTimelineLength(timeline)
	local validIndices = {}

	for i, frameIndex in ipairs(indices) do
		if frameIndex >= 0 and frameIndex < timelineLength then
			table.insert(validIndices, frameIndex)
		end
	end

	if #validIndices == 0 then
		Toast.error("[ANIMATE ATLAS]  no valid frame indices provided for symbol '" .. symbol .. "'")
		return false
	end

	if framerate == nil then framerate = self.sprite.library.framerate or 30 end
	if looped == nil then looped = false end

	self.animations[name] = Animation(self, name, symbol, validIndices, framerate, looped)
	return true
end

function AnimateAtlasController:addByRange(name, symbol, startFrame, endFrame, framerate, looped)
	if not self.sprite.library then
		Toast.error("[ANIMATE ATLAS] No library loaded")
		return false
	end

	local timeline = self.sprite.library:getSymbolTimeline(symbol)
	if not timeline then
		Toast.error("[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if startFrame == nil then startFrame = 0 end
	if endFrame == nil then
		local length = self.sprite.library:getTimelineLength(timeline)
		endFrame = length - 1
	end

	if framerate == nil then framerate = self.sprite.library.framerate or 30 end
	if looped == nil then looped = true end

	local indices = {}
	for i = startFrame, endFrame do
		table.insert(indices, i)
	end

	self.animations[name] = Animation(self, name, symbol, indices, framerate, looped)
	return true
end

function AnimateAtlasController:play(name, force, frame, reversed)
	if not self:has(name) then
		return
	end

	local curAnim = self.curAnim
	if curAnim and not force and curAnim.name == name and not curAnim.finished then
		self.finished = false
		return
	end

	curAnim = self.animations[name]
	if curAnim then
		self.curAnim = curAnim
		self.name = curAnim.name
		curAnim.finished = false
		curAnim:play(frame, reversed or false)

		self.sprite.symbol = curAnim.symbol
		self.sprite.frame = curAnim:getCurrentFrameIndex()
	end
end

function AnimateAtlasController:playSymbol(name)
	self.sprite.symbol = name or ""
	self.sprite.frame = 0
	self.sprite._currentAnim = name

	self.curAnim = nil
	self.name = name
end

function AnimateAtlasController:getCurrentFrame()
	if self.curAnim then
		return self.curAnim:getCurrentFrameIndex()
	end
	return self.sprite.frame
end

function AnimateAtlasController:update(dt)
	if self.curAnim then
		self.curAnim:update(dt)
		self.finished = self.curAnim.finished

		self.sprite.frame = self.curAnim:getCurrentFrameIndex()
	else
		local sprite = self.sprite
		sprite.frame = sprite.frame or 1
		local framerate = sprite.library.framerate
		if framerate <= 0 then return end

		sprite._frameTimer = sprite._frameTimer + dt
		local frameStep = 1 / framerate

		while sprite._frameTimer >= frameStep do
			sprite.frame = sprite.frame + 1
			sprite._frameTimer = sprite._frameTimer - frameStep

			local length = sprite.library:getTimelineLength(sprite.library:getSymbolTimeline(self.symbol))

			if sprite.frame > length - 1 then
				if sprite._curSymbol then
					local data = sprite._curSymbol.data
					local optimized = data.ST ~= nil

					local symbolName = data[optimized and "SN" or "SYMBOL_name"]
					local firstFrame = data[optimized and "FF" or "firstFrame"] or 0
					local loopMode = data[optimized and "LP" or "loop"]
					local symbolType = data[optimized and "ST" or "symbolType"]

					local frameIndex = firstFrame + (sprite.frame - sprite._curSymbol.index)

					if symbolType == "movieclip" or symbolType == "MC" then
						frameIndex = 0
					end

					local symbolTimeline = sprite.library.libraries[symbolName].data
					local symbolLength = sprite.library:getTimelineLength(symbolTimeline)

					if loopMode == "loop" or loopMode == "LP" then
						frameIndex = frameIndex % symbolLength
						if frameIndex < 0 then frameIndex = frameIndex + symbolLength end
					elseif loopMode == "playonce" or loopMode == "PO" then
						frameIndex = math.max(0, math.min(frameIndex, symbolLength - 1))
					elseif loopMode == "singleframe" or loopMode == "SF" then
						frameIndex = firstFrame
					end
					sprite.frame = frameIndex
				else
					sprite.frame = length - 1
				end
			end
		end
	end
end

return AnimateAtlasController
