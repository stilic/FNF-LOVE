local Rain = Basic:extend("Rain")

Rain.startIntensity = .01
Rain.endIntensity = .23

local setSpeed = {
	["darnell"] = function()
		Rain.startIntensity = 0
		Rain.endIntensity = 0.1
	end,
	["lit up"] = function()
		Rain.startIntensity = 0.1
		Rain.endIntensity = 0.2
	end,
	["2hot"] = function()
		Rain.startIntensity = 0.2
		Rain.endIntensity = 0.4
	end
}

function Rain.create(song, low)
	for key, func in pairs(setSpeed) do
		if song:lower():find(key) then func(); break end
	end
	local rain = Shader("rain" .. (low and "low" or ""))
	rain.scale = game.height / 200
	rain.intensity = Rain.startIntensity
	rain.distortionStrength = 0.65

	return rain
end

return Rain
