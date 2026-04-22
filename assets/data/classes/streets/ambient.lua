local Ambient = Object:extend("Ambient")

function Ambient:new(sounds)
	self.sounds = {}
	
	for i, soundData in ipairs(sounds) do
		local sound = game.sound.load(soundData.path, false)
		sound.volume = soundData.startVolume or 0
		sound.looped = true

		if soundData.randomStart then
			sound.time = math.random() * sound.duration
		end

		sound:play()

		table.insert(self.sounds, {
			sound = sound,
			targetVolume = soundData.targetVolume or 0,
			startVolume = soundData.startVolume or 0,
			endVolume = soundData.endVolume or 0,
			intensityMultiplier = soundData.intensityMultiplier or 1
		})
	end
	
	self.paused = false
end

function Ambient:updateIntensity(songPosition, songLength)
	for _, data in ipairs(self.sounds) do
		if songLength and songLength > 0 then
			local intensity = songPosition / songLength
			local remappedVolume = data.startVolume + (data.endVolume - data.startVolume) * intensity
			data.sound.volume = math.min(data.targetVolume, remappedVolume * data.intensityMultiplier)
		else
			data.sound.volume = data.startVolume
		end
	end
end

function Ambient:setVolume(volume)
	for _, data in ipairs(self.sounds) do
		data.sound.volume = volume
	end
end

function Ambient:pause()
	if not self.paused then
		for _, data in ipairs(self.sounds) do
			data.sound:pause()
		end
		self.paused = true
	end
end

function Ambient:resume()
	if self.paused then
		for _, data in ipairs(self.sounds) do
			data.sound:play()
		end
		self.paused = false
	end
end

function Ambient:stop()
	for _, data in ipairs(self.sounds) do
		data.sound:stop()
	end
end

return Ambient
