local function sortFramesByIndices(prefix, postfix)
	local s, e = #prefix + 1, - #postfix - 1

	return function(a, b)
		local numA = tonumber(string.sub(a.name, s, e))
		local numB = tonumber(string.sub(b.name, s, e))

		if numA == nil or numB == nil then
			return a.name < b.name
		end

		return numA < numB
	end
end

local Animation = loxreq "animation.instance"
---@class AnimationController:Basic
local AnimationController = Basic:extend("AnimationController")

function AnimationController:new(sprite)
	self.sprite = sprite
	self.animations = {}

	self.name = nil
	self.finished = false
	self.curAnim = nil

	self.onFinish = Signal()
	self.onFrameChange = Signal()
end

function AnimationController:add(name, frames, framerate, looped)
	if not self.sprite.frames or not frames or #frames == 0 then return end

	if framerate == nil then framerate = 30 end
	if looped == nil then looped = true end

	local animFrames = {}
	for _, i in ipairs(frames) do
		table.insert(animFrames, self.sprite.frames.frames[i + 1])
	end

	self.animations[name] = Animation(self, name, animFrames, framerate, looped)
end

function AnimationController:addByPrefix(name, prefix, framerate, looped)
	if not self.sprite.frames then return end

	if framerate == nil then framerate = 30 end
	if looped == nil then looped = true end

	local animFrames, foundFrame = {}, false
	for _, f in ipairs(self.sprite.frames.frames) do
		if f.name:startsWith(prefix) then
			foundFrame = true
			table.insert(animFrames, f)
		end
	end
	if not foundFrame then return end

	table.sort(animFrames, sortFramesByIndices(prefix, ""))

	self.animations[name] = Animation(self, name, animFrames, framerate, looped)
end

function AnimationController:addByIndices(name, prefix, indices, postfix, framerate, looped)
	if not self.sprite.frames then return end

	if postfix == nil then postfix = "" end
	if framerate == nil then framerate = 30 end
	if looped == nil then looped = true end

	local allFrames, foundFrame = {}, false
	local notPostfix = #postfix <= 0
	for _, f in ipairs(self.sprite.frames.frames) do
		if f.name:startsWith(prefix) and
			(notPostfix or f.name:endsWith(postfix)) then
			foundFrame = true
			table.insert(allFrames, f)
		end
	end
	if not foundFrame then return end

	table.sort(allFrames, sortFramesByIndices(prefix, postfix))

	local animFrames = {}
	for _, i in ipairs(indices) do
		local f = allFrames[i + 1]
		if f then table.insert(animFrames, f) end
	end

	self.animations[name] = Animation(self, name, animFrames, framerate, looped)
end

function AnimationController:has(name)
	return self:get(name) ~= nil
end

function AnimationController:get(name)
	return self.animations[name]
end

function AnimationController:getList(asString)
	if asString then
		local list = {}
		for _, anim in pairs(self.animations) do
			table.insert(list, anim.name)
		end
		return list
	end
	return self.animations
end

function AnimationController:rename(oldName, newName)
	if oldName == newName then return end

	local animation = self.animations[oldName]
	local animation2 = self.animations[newName]
	if not animation and not animation2 then return end

	if animation then animation.name = newName end
	if animation2 then animation2.name = oldName end

	self.animations[newName] = animation
	self.animations[oldName] = animation2
end

function AnimationController:remove(name)
	if self.curAnim and self.curAnim.name == name then
		self:stop()
		self.curAnim = nil
	end
	self.animations[name] = nil
end

function AnimationController:play(name, force, frame, reversed)
	if not self:has(name) then
		Logger.log("error", "No animation data found for " .. name, 4)
		return
	end
	local curAnim = self.curAnim

	if curAnim and not force and curAnim.name == name and
		not curAnim.finished then
		self.finished = false
		self.paused = false
		return
	end

	curAnim = self.animations[name]
	if curAnim then
		self.curAnim = curAnim
		self.name = curAnim.name
		self.finished = false
		curAnim:play(frame, reversed or false)
		self:update(-(1 / self.curAnim.framerate) / 3)
	end
end

function AnimationController:pause()
	if self.curAnim then
		self.curAnim:pause()
	end
end

function AnimationController:resume()
	if self.curAnim then
		self.curAnim:resume()
	end
end

function AnimationController:stop()
	if self.curAnim then
		self.curAnim:stop()
	end
end

function AnimationController:finish()
	if self.curAnim then
		self.curAnim:finish()
	end
end

function AnimationController:getCurrentFrame()
	if self.curAnim then
		return self.curAnim:getCurrentFrame()
	elseif self.sprite.frames then
		return self.sprite.frames.frames[1]
	end
	return nil
end

function AnimationController:update(dt)
	if self.curAnim then
		self.curAnim:update(dt)
		self.finished = self.curAnim.finished
		self.frame = self:getCurrentFrame()
	end
end

function AnimationController:reset()
	self.curAnim = nil
	table.clear(self.animations)
end

return AnimationController
