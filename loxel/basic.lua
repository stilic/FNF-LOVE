---@class Basic:Classic
local Basic = Classic:extend("Basic")

function Basic:new()
	self.active = true
	self.visible = true

	self.alive = true
	self.exists = true

	self.cameras = nil
	self.__cameraQueue = {}
end

function Basic:kill()
	self.alive = false
	self.exists = false
end

function Basic:revive()
	self.alive = true
	self.exists = true
end

function Basic:destroy()
	self.exists = false
	self.cameras = nil
end

function Basic:isOnScreen(cameras)
	return true
end

function Basic:canDraw()
	return self.exists and self.visible and self.__render
end

function Basic:draw()
	if not self:canDraw() then return end

	local willRender = false
	for _, c in ipairs(self.cameras or Camera.__defaultCameras) do
		if c.visible and c.exists and not c.freezed and self:isOnScreen(c) then
			table.insert(c.__renderQueue, self)
			table.insert(self.__cameraQueue, c)
			willRender = true
		end
	end
	if self.__preRender then self:__preRender(willRender) end
end

function Basic:cancelDraw()
	for i, c in ipairs(self.__cameraQueue) do
		for i = #c.__renderQueue, 1, -1 do
			if c.__renderQueue[i] == self then
				table.remove(c.__renderQueue, i)
				break
			end
		end
		self.__cameraQueue[i] = nil
	end
end

--function Basic:enter(group) end
--function Basic:leave(group) end
--function Basic:resume(group) end

return Basic
