function event(data)
	data = data.v

	local rate = tonumber(data.rate) or 4
	local intensity = tonumber(data.intensity) or 1

	camZoomIntensity = (1.015 - 1) * intensity + 1
	hudZoomIntensity = (1.015 - 1) * intensity * 2
	zoomRate = rate
end
