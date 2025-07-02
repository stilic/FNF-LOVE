---@class AnimateAtlasAnimation:Animation
local Animation = loxreq "animation.instance"
local AnimateAtlasAnimation = Animation:extend("AnimateAtlasAnimation")

function AnimateAtlasAnimation:new(parent, name, symbol, indices, framerate, looped)
	AnimateAtlasAnimation.super.new(self, parent, name, indices, framerate, looped)
	self.symbol = symbol
end

function AnimateAtlasAnimation:getCurrentFrameIndex()
	local frameIndex = math.floor(self.frame)
	if frameIndex < 1 then frameIndex = 1 end
	if frameIndex > #self.frames then frameIndex = #self.frames end
	return self.frames[frameIndex] or 0
end

function AnimateAtlasAnimation:update(dt)
	if self.finished then return end
	AnimateAtlasAnimation.super.update(self, dt)
end

return AnimateAtlasAnimation
