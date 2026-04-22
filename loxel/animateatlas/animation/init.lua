local Animation = loxreq "animateatlas.animation.instance"
local AnimationController = loxreq "animation"

local AnimateAtlasController = AnimationController:extend("AnimateAtlasController")
AnimateAtlasController:exclude("add", "addByPrefix", "addByIndices")

function AnimateAtlasController:add(name, symbol, framerate, looped)
	if not self.sprite.library then
		Logger.log("error", "[ANIMATE ATLAS] No library loaded")
		return false
	end

	local lib = self.sprite.library
	local tl_idx = lib:getSymbolTimeline(symbol)
	if not tl_idx then
		Logger.log("error", "[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if framerate == nil then framerate = lib.framerate or 30 end
	if looped == nil then looped = false end

	local length = lib.timelines[tl_idx].length
	local indices = {}
	for i = 0, length - 1 do
		table.insert(indices, i)
	end

	self.animations[name] = Animation(self, name, symbol, indices, framerate, looped)
	return true
end

function AnimateAtlasController:addFromLibrary(name, anim, symbol, framerate, looped)
	if not self.sprite.library then
		Logger.log("error", "[ANIMATE ATLAS] No library loaded")
		return false
	end

	local lib = self.sprite.library
	symbol = symbol or ""

	local startFrame, endFrame = lib:getLabelRange(symbol, anim)
	if not startFrame then
		Logger.log("error", "[ANIMATE ATLAS] Label '" .. anim .. "' not found in symbol '" .. symbol .. "'")
		return false
	end

	return self:addByRange(name, symbol, startFrame, endFrame, framerate, looped)
end

function AnimateAtlasController:addFromLibraryIndices(name, anim, symbol, indices, framerate, looped)
	if not self.sprite.library then
		Logger.log("error", "[ANIMATE ATLAS] No library loaded")
		return false
	end

	local lib = self.sprite.library
	symbol = symbol or ""

	local startFrame, endFrame = lib:getLabelRange(symbol, anim)
	if not startFrame then
		Logger.log("error", "[ANIMATE ATLAS] Label '" .. anim .. "' not found in symbol '" .. symbol .. "'")
		return false
	end

	if not indices or #indices == 0 then
		Logger.log("error", "[ANIMATE ATLAS] Indices table cannot be empty")
		return false
	end

	local validIndices = {}
	for _, idx in ipairs(indices) do
		local absFrame = startFrame + idx
		if absFrame >= startFrame and absFrame <= endFrame then
			table.insert(validIndices, absFrame)
		end
	end

	if #validIndices == 0 then
		Logger.log("error", "[ANIMATE ATLAS] No valid frame indices provided for label '" .. anim .. "'")
		return false
	end

	if framerate == nil then framerate = lib.framerate or 30 end
	if looped == nil then looped = false end

	self.animations[name] = Animation(self, name, symbol, validIndices, framerate, looped)
	return true
end

function AnimateAtlasController:addByRange(name, symbol, startFrame, endFrame, framerate, looped)
	if not self.sprite.library then
		Logger.log("error", "[ANIMATE ATLAS] No library loaded")
		return false
	end

	local lib = self.sprite.library
	local tl_idx = lib:getSymbolTimeline(symbol)
	if not tl_idx then
		Logger.log("error", "[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if startFrame == nil then startFrame = 0 end
	if endFrame == nil then
		endFrame = lib.timelines[tl_idx].length - 1
	end

	if framerate == nil then framerate = lib.framerate or 30 end
	if looped == nil then looped = true end

	local indices = {}
	for i = startFrame, endFrame do
		table.insert(indices, i)
	end

	self.animations[name] = Animation(self, name, symbol, indices, framerate, looped)
	return true
end

function AnimateAtlasController:addByIndices(name, symbol, indices, framerate, looped)
	if not self.sprite.library then
		Logger.log("error", "[ANIMATE ATLAS] No library loaded")
		return false
	end

	local lib = self.sprite.library
	local tl_idx = lib:getSymbolTimeline(symbol)
	if not tl_idx then
		Logger.log("error", "[ANIMATE ATLAS] Symbol '" .. symbol .. "' not found in library")
		return false
	end

	if not indices or #indices == 0 then
		Logger.log("error", "[ANIMATE ATLAS] Indices table cannot be empty")
		return false
	end

	local timelineLength = lib.timelines[tl_idx].length
	local validIndices = {}
	for _, frameIndex in ipairs(indices) do
		if frameIndex >= 0 and frameIndex < timelineLength then
			table.insert(validIndices, frameIndex)
		end
	end

	if #validIndices == 0 then
		Logger.log("error", "[ANIMATE ATLAS] No valid frame indices provided for symbol '" .. symbol .. "'")
		return false
	end

	if framerate == nil then framerate = lib.framerate or 30 end
	if looped == nil then looped = false end

	self.animations[name] = Animation(self, name, symbol, validIndices, framerate, looped)
	return true
end

function AnimateAtlasController:play(name, force, frame, reversed)
	if not self:has(name) then return end

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
		self:update(-(1 / self.curAnim.framerate) / 3)
	end
end

function AnimateAtlasController:playSymbol(name)
	self.sprite.symbol = name or ""
	self.sprite.frame = 0
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
		self.frame = self:getCurrentFrame()
		self.sprite.frame = self.curAnim:getCurrentFrameIndex()
	else
		local sprite = self.sprite
		local lib = sprite.library
		if not lib then return end

		sprite.frame = sprite.frame or 0
		local framerate = lib.framerate
		if framerate <= 0 then return end

		sprite._frameTimer = (sprite._frameTimer or 0) + dt
		local frameStep = 1 / framerate

		while sprite._frameTimer >= frameStep do
			sprite.frame = sprite.frame + 1
			sprite._frameTimer = sprite._frameTimer - frameStep

			local tl_idx = lib:getSymbolTimeline(self.symbol)
			if tl_idx then
				local length = lib.timelines[tl_idx].length
				if sprite.frame >= length then
					sprite.frame = length - 1
				end
			end
		end
	end
end

return AnimateAtlasController
