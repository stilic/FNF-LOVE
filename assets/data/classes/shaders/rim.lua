local RimEffect = Classic:extend("RimEffect")

function RimEffect:new(sprite)
	self.sprite = sprite
	self.shader = Shader('rimLight')
	if self.sprite then self.sprite.shader = self.shader:get() end

	self:setHSB(-66, -10, 24, -23)
	self:setRimColor(Color.fromHEX(0x52351d))
	self:setRimProperty(1, 5, 0.1, 0)

	self.shader.uRim_antialiasAmt = 0
	self.shader.uRim_angle = 90 * (math.pi / 180)
end

function RimEffect:setHSB(brightness, hue, contrast, saturation)
	self.shader.uRim_brightness = brightness or -66
	self.shader.uRim_hue = hue or -10
	self.shader.uRim_contrast = contrast or 24
	self.shader.uRim_saturation = saturation or -23
	return self
end

function RimEffect:setRimProperty(strength, distance, threshold, angleOffset)
	if strength then self.shader.uRim_strength = strength end
	if distance then self.shader.uRim_distance = distance end
	if threshold then self.shader.uRim_threshold = threshold end
	if angleOffset then self.shader.uRim_angOffset = angleOffset end
	return self
end

function RimEffect:setAngle(degrees)
	self.shader.uRim_angle = degrees * (math.pi / 180)
	return self
end

function RimEffect:setRimColor(colorTable)
	self.shader.uRim_dropColor = colorTable
	return self
end

function RimEffect:setMask(path, maskThreshold, useAlt, isPixel)
	local mask = paths.getImage(path)
	if mask then
		if isPixel then
			mask:setFilter('nearest', 'nearest')
		end
		self.shader.altMask = mask
		self.shader.uRim_maskThreshold = maskThreshold or 1
		self.shader.uRim_useAltMask = (useAlt == nil and true or useAlt)
	end
	return self
end

function RimEffect:update()
	if not self.sprite or not self.sprite.texture then return end

	local frame = self.sprite:getCurrentFrame()
	if frame then
		local quad = frame.quad
		local x, y, w, h = quad:getViewport()
		local sw, sh = self.sprite.texture:getDimensions()

		self.shader.uTextureSize = {sw, sh}
		self.shader.uFrameBounds = {x/sw, y/sh, (x+w)/sw, (y+h)/sh}
		self.shader.uRim_angOffset = 0
	end
end

return RimEffect
