local Video = Object:extend("Video")

function Video:new(x, y, source, screenAdjust, autoDestroy, looped)
	Video.super.new(self, x, y)
	if type(source) == "string" then
		source = paths.getPath("videos/" .. source .. ".ogv")
	end
	self.video = source.typeOf and source or
		love.graphics.newVideo(source)
	self.width, self.height = self.video:getDimensions()

	if screenAdjust then
		self:adjust(game.width, game.height)
	end

	self.looped = looped
	self.paused = false
	self.__volume = 1
	self.__source = self.video:getSource()
	self.__lastVolume = self:getActualVolume()
	self.autoDestroy = autoDestroy

	self:setVolume()
	self.video:rewind()
end

function Video:adjust(width, height)
	self.scale.x = width / self.width
	self.scale.y = height / self.height

	if width <= 0 then
		self.scale.x = self.scale.y
	elseif height <= 0 then
		self.scale.y = self.scale.x
	end
end

function Video:update(dt)
	Video.super.update(self, dt)
	if not self.paused and self.video then
		if self.looped and not self.video:isPlaying() then
			self.video:rewind()
			self.video:play()
		elseif not self.looped and not self.video:isPlaying() then
			if self.onComplete then self.onComplete(self) end
			if self.autoDestroy then self:destroy() end
		end
	end
	self:setVolume()
end

function Video:seek(time)
	if not self.video then return end
	return self.video:seek(time)
end

function Video:tell()
	if not self.video then return end
	return self.video:tell()
end

function Video:getDuration()
	if not self.video then return end
	if not self.__source then
		return -1
	end
	return self.__source:tell()
end

function Video:pause(skip)
	if not self.video then return end
	self.video:pause()
	if not skip then self.paused = true end
end

function Video:play()
	if not self.video then return end
	self.video:play()
	self.paused = false
end

function Video:focus(f)
	if not self.video then return end
	if f then self:play() else self:pause() end
end

function Video:destroy()
	Video.super.destroy(self)
	self.video = nil
end

function Video:__render(camera)
	local min, mag, anisotropy, mode
	mode = self.antialiasing and "linear" or "nearest"
	min, mag, anisotropy = self.video:getFilter()

	love.graphics.push("all")
	self.video:setFilter(mode, mode, anisotropy)

	local x, y, rad, sx, sy, ox, oy = self.x, self.y, math.rad(self.angle),
		self.scale.x * self.zoom.x, self.scale.y * self.zoom.y,
		self.origin.x, self.origin.y

	if self.flipX then sx = -sx end
	if self.flipY then sy = -sy end

	x, y = x + ox - self.offset.x - (camera.scroll.x * self.scrollFactor.x),
		y + oy - self.offset.y - (camera.scroll.y * self.scrollFactor.y)

	love.graphics.setShader(self.shader); love.graphics.setBlendMode(self.blend)
	love.graphics.setColor(Color.vec4(self.color, self.alpha))

	love.graphics.draw(self.video, x, y, rad, sx, sy, ox, oy)

	self.video:setFilter(min, mag, anisotropy)
	love.graphics.pop()
end

function Video:setVolume(volume)
	if not self.video then return end
	self.__volume = volume or self.__volume
	if not self.__source then return false end
	return self.__source:setVolume(self:getActualVolume())
end

function Video:getActualVolume()
	return self.__volume * (game.sound.__mute and 0 or 1) * (game.sound.__volume or 1)
end

function Video:getVolume() return self.__volume end

return Video
