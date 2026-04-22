---@class Animation:Basic
local Animation = Basic:extend("Animation")

function Animation:new(parent, name, frames, framerate, looped)
	self.parent = parent
	self.name = name
	self.frames = frames or {}
	self.framerate = framerate or 30
	self.looped = looped == nil and true or looped
	self.offset = Point()

	self.frame = 1
	self.timer = 0
	self.finished = false
	self.paused = false
	self.reversed = false

	self._justPlayed = false
	self.__lastFrame = 1
end

function Animation:play(frame, reversed)
	self.frame = frame and (frame < 1 and math.random(1, #self.frames) or frame) or 1
	self.timer = 0
	self.finished = false
	self.paused = false
	self.reversed = reversed or false
	self.__lastFrame = math.floor(self.frame)
end

function Animation:pause()
	if not self.finished then
		self.paused = true
	end
end

function Animation:resume()
	if not self.finished then
		self.paused = false
	end
end

function Animation:stop()
	self.finished = true
	self.paused = true
end

function Animation:finish()
	self:stop()
	self.frame = self.reversed and 1 or #self.frames
	if self.parent then
		self.parent.onFinish:dispatch(self.name)
	end
end

function Animation:getCurrentFrame()
	return self.frames[math.floor(self.frame)]
end

function Animation:rotateOffset(angle, sx, sy)
	local x, y = self.offset.x, self.offset.y
	if sx and sx < 0 then x = -x end
	if sy and sy < 0 then y = -y end
	local rot = math.pi * angle / 180
	local offx = x * math.cos(rot) - y * math.sin(rot)
	local offy = x * math.sin(rot) + y * math.cos(rot)

	return offx, offy
end

function Animation:update(dt)
	if not self.finished and not self.paused then
		self.timer = self.timer + dt

		local delay = 1 / self.framerate

		while self.timer >= delay do
			self.timer = self.timer - delay

			if self.reversed then
				self.frame = self.frame - 1
				if self.frame < 1 then
					if self.looped then
						self.frame = #self.frames
					else
						self.frame = 1
						self:finish()
						break
					end
				end
			else
				self.frame = self.frame + 1
				if self.frame > #self.frames then
					if self.looped then
						self.frame = 1
					else
						self.frame = #self.frames
						self:finish()
						break
					end
				end
			end
		end

		local newFrame = math.floor(self.frame)
		if newFrame ~= self.__lastFrame then
			self.__lastFrame = newFrame
			if self.parent then
				self.parent.onFrameChange:dispatch(newFrame)
			end
		end
	end
end

return Animation
