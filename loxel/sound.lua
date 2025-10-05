---@class Sound:Basic
local Sound = Basic:extend("Sound")

function Sound:new(x, y)
	Sound.super.new(self)
	self:revive()
	self.visible, self.cameras = nil, nil
end

function Sound:revive()
	self:reset(true)
	self._volume = 1
	self._pitch = 1
	self._duration = 0
	self._wasPlaying = false
	Sound.super.revive(self)
end

function Sound:reset(cleanup, x, y)
	if cleanup then
		self:cleanup()
	elseif self._source ~= nil then
		self:stop()
	end
	self:setPosition(x or self.x, y or self.y)

	self._wasPlaying = false
	self.looped = false
	self.autoDestroy = false
	self.radius = 0

	self:cancelFade()
	self.volume = 1
	self.pitch = 1
end

function Sound:fade(duration, startVolume, endVolume)
	self._fadeElapsed = 0
	self._fadeDuration = duration
	self._startVolume = startVolume
	self._endVolume = endVolume
end

function Sound:cancelFade()
	self._fadeDuration = nil
end

function Sound:cleanup()
	self.active = false
	self.target = nil
	self.onComplete = nil

	if self._source ~= nil then
		self:stop()
		if self._isSource and self._source.release then
			self._source:release()
		end
	end
	self._paused = true
	self._isFinished = false
	self._isSource = false
	self._source = nil
end

function Sound:destroy()
	Sound.super.destroy(self)
	self:cleanup()
end

function Sound:kill()
	Sound.super.kill(self)
	self:reset(self.autoDestroy)
end

function Sound:setPosition(x, y)
	self.x, self.y = x or 0, y or 0
end

function Sound:load(asset, autoDestroy, onComplete)
	if not self.exists or asset == nil then return end
	self:cleanup()

	self._isSource = asset:typeOf("SoundData")
	self._source = self._isSource and love.audio.newSource(asset) or asset
	return self:init(autoDestroy, onComplete)
end

function Sound:init(autoDestroy, onComplete)
	if autoDestroy ~= nil then self.autoDestroy = autoDestroy end
	if onComplete ~= nil then self.onComplete = onComplete end
	self.active = true
	return self
end

function Sound:play(volume, looped, pitch, restart)
	if not self.active or not self._source then return self end

	if restart then
		pcall(self._source.stop, self._source)
	elseif self:isPlaying() then
		return self
	end

	self._paused = false
	self._isFinished = false
	self.volume = volume
	self.looped = looped
	self.pitch = pitch

	pcall(self._source.play, self._source)
	return self
end

function Sound:pause()
	self._paused = true
	if self._source then pcall(self._source.pause, self._source) end
	return self
end

function Sound:stop()
	self._paused = true
	if self._source then pcall(self._source.stop, self._source) end
	return self
end

function Sound:proximity(x, y, target, radius)
	self:setPosition(x, y)
	self.target = target
	self.radius = radius
	return self
end

function Sound:update(dt)
	local isFinished = self:isFinished()
	if isFinished and not self._isFinished then
		local onComplete = self.onComplete
		if self.autoDestroy then self:kill() else self:stop() end

		if onComplete then onComplete() end
	end

	self._isFinished = isFinished

	if self._fadeDuration then
		self._fadeElapsed = self._fadeElapsed + dt
		if self._fadeElapsed < self._fadeDuration then
			self.volume = math.lerp(self._startVolume, self._endVolume, self._fadeElapsed / self._fadeDuration)
		else
			self.volume = self._endVolume
			self._fadeStartTime, self._fadeDuration, self._startVolume, self._endVolume = nil
		end
	end
end

function Sound:onFocus(focus)
	if not self:isFinished() then
		if focus then
			if self._wasPlaying then self:play() end
		elseif self:isPlaying() then
			self._wasPlaying = true
			self:pause()
		else
			self._wasPlaying = false
		end
	end
end

function Sound:isPlaying()
	if not self._source then return false end
	local success, playing = pcall(self._source.isPlaying, self._source)
	return success and playing or false
end

function Sound:isFinished()
	return self.active and not self._paused and not self:isPlaying() and
		not self:get_looped()
end

function Sound:getActualVolume()
	return self._volume * (game.sound.__mute and 0 or 1) * (game.sound.__volume or 1)
end

function Sound:getActualPitch()
	return self._pitch * (game.sound.__pitch or 1)
end

function Sound:get_duration()
	if not self._source then return -1 end
	return self._source:getDuration() or -1
end

function Sound:get_time()
	if not self._source then return 0 end
	return self._source:tell() or 0
end

function Sound:get_volume() return self._volume end
function Sound:get_pitch() return self._pitch end

function Sound:get_looped()
	if not self._source then return false end
	return self._source:isLooping()
end

function Sound:set_time(time)
	if not self._source or not time then return false end
	self._source:seek(time)
end

function Sound:set_volume(volume)
	self._volume = volume or self._volume
	if not self._source then return end
	self._source:setVolume(self:getActualVolume())
end

function Sound:set_pitch(pitch)
	self._pitch = pitch or self._pitch
	if not self._source then return false end
	self._source:setPitch(self:getActualPitch())
end

function Sound:set_looped(loop)
	if not self._source then return false end
	self._source:setLooping(loop or self.looped or false)
end

function Sound:__index(k)
	local g = rawget(self, "get_" .. k) or rawget(getmetatable(self), "get_" .. k)
	return g and g(self) or rawget(self, k) or getmetatable(self)[k]
end

return Sound
