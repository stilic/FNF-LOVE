function event(data)
	data = data.v

	local rate = tonumber(data.rate) or 4
	local intensity = tonumber(data.intensity) or 1.0

	cameraZoomIntensity = (1.015 - 1.0) * intensity + 1.0
	hudZoomIntensity = (1.015 - 1.0) * intensity * 2.0
	zoomRate = rate
end
