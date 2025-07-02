local function intToRGB(int)
	return
		bit.band(bit.rshift(int, 16), 0xFF) / 255,
		bit.band(bit.rshift(int, 8), 0xFF) / 255,
		bit.band(int, 0xFF) / 255,
		bit.band(bit.rshift(int, 24), 0xFF) / 255
end

local ColorTransform = Basic:extend("ColorTransform")

function ColorTransform:new()
	ColorTransform.super.new(self)

	self._colorTransformShader = love.graphics.newShader[[
		extern vec4 colorOffset;
		extern vec4 colorMultiplier;

		vec4 effect(vec4 color, Image tex, vec2 texCoords, vec2 screenCoords) {
			vec4 finalColor = Texel(tex, texCoords) * color;
			finalColor += colorOffset;
			return finalColor * colorMultiplier;
		}
	]]

	self:setColorMultiplier(1, 1, 1, 1)

	self._transformHandlers = {
		brightness = self._hbrightness,
		tint = self._htint,
		alpha = self._halpha,
		advanced = self._hadvanced
	}
end

function ColorTransform:setColorOffset(r, g, b, a)
	self._colorTransformShader:send("colorOffset", {r, g, b, a})
end

function ColorTransform:setColorMultiplier(r, g, b, a)
	self._colorTransformShader:send("colorMultiplier", {r, g, b, a})
end

function ColorTransform:getShader()
	return self._colorTransformShader
end

function ColorTransform:_hbrightness(self, colorTransform, optimized)
	local brightness = colorTransform["brightness"]
	self:setColorOffset(brightness, brightness, brightness, 0)

	local brn = 1 - math.abs(brightness)
	self:setColorMultiplier(brn, brn, brn, 1)
end

function ColorTransform:_htint(self, colorTransform)
	local tintColor = tonumber("0xFF" + colorTransform["tintColor"]:sub(2))
	local tintR, tintG, tintB = intToRGB(tintColor)

	local multiplier = colorTransform["tintMultiplier"]
	local mult = 1 - multiplier
	self:setColorOffset(
		tintR * multiplier,
		tintG * multiplier,
		tintB * multiplier,
		0
	)
	self:setColorMultiplier(mult, mult, mult, 1)
end

function ColorTransform:_halpha(self, colorTransform)
	local alphaMultiplier = colorTransform["alphaMultiplier"]
	self:setColorMultiplier(1, 1, 1, alphaMultiplier)
end

function ColorTransform:_hadvanced(self, colorTransform)
	self:setColorOffset(
		colorTransform["redOffset"],
		colorTransform["greenOffset"],
		colorTransform["blueOffset"],
		colorTransform["alphaOffset"]
	)
	self:setColorMultiplier(
		colorTransform["redMultiplier"],
		colorTransform["greenMultiplier"],
		colorTransform["blueMultiplier"],
		colorTransform["alphaMultiplier"]
	)
end

function ColorTransform:applyTransform(colorTransform, transformType, optimized)
	if not colorTransform then return end
	
	local handler = self._transformHandlers[transformType]
	if handler then
		handler(self, colorTransform, optimized)
	end
end

function ColorTransform:mergeTransforms(baseColor, symbolColor, optimized)
	if not baseColor and not symbolColor then return nil end
	if not baseColor then return symbolColor end
	if not symbolColor then return baseColor end

	local merged = {}

	for key, value in pairs(baseColor) do merged[key] = value end

	for key, value in pairs(symbolColor) do
		if type(value) == "number" then
			local offsetKey = optimized and "O" or "Offset"
			if key:sub(-1) == "O" or key:sub(-6) == "Offset" then
				merged[key] = (merged[key] or 0) + value
			else
				merged[key] = (merged[key] or 1) * value
			end
		else
			merged[key] = value
		end
	end
	return merged
end

function ColorTransform:hasEffects(colorTransform, optimized)
	if not colorTransform then return false end

	local rm = colorTransform[optimized and "RM" or "redMultiplier"] or 1
	local gm = colorTransform[optimized and "GM" or "greenMultiplier"] or 1
	local bm = colorTransform[optimized and "BM" or "blueMultiplier"] or 1
	local am = colorTransform[optimized and "AM" or "alphaMultiplier"] or 1

	if rm ~= 1 or gm ~= 1 or bm ~= 1 or am ~= 1 then return true end

	local ro = colorTransform[optimized and "RO" or "redOffset"] or 0
	local go = colorTransform[optimized and "GO" or "greenOffset"] or 0
	local bo = colorTransform[optimized and "BO" or "blueOffset"] or 0
	local ao = colorTransform[optimized and "AO" or "alphaOffset"] or 0

	if ro ~= 0 or go ~= 0 or bo ~= 0 or ao ~= 0 then return true end

	return false
end

function ColorTransform:applyRawTransform(colorTransform, optimized)
	if not colorTransform then return end

	local rm = colorTransform[optimized and "RM" or "redMultiplier"] or 1
	local gm = colorTransform[optimized and "GM" or "greenMultiplier"] or 1
	local bm = colorTransform[optimized and "BM" or "blueMultiplier"] or 1
	local am = colorTransform[optimized and "AM" or "alphaMultiplier"] or 1

	local ro = colorTransform[optimized and "RO" or "redOffset"] or 0
	local go = colorTransform[optimized and "GO" or "greenOffset"] or 0
	local bo = colorTransform[optimized and "BO" or "blueOffset"] or 0
	local ao = colorTransform[optimized and "AO" or "alphaOffset"] or 0

	self:setColorOffset(ro, go, bo, ao)
	self:setColorMultiplier(rm, gm, bm, am)
end

function ColorTransform:getBlendMode(colorTransform, optimized)
	if not colorTransform then return "alpha" end

	local blendMode = colorTransform[optimized and "M" or "blendMode"]
	if not blendMode then return "alpha" end

	if blendMode == "AD" then return "add" end
	-- TODO add non-optimized namings and other blend  modes
	-- also fix this because its a mess but i got tired getting it to work
	-- this isnt blend mode aswell but works for now and its enough
	-- delayed this too much already
	-- kaoy

	return blendMode == "AD" and "add" or "alpha"
end

function ColorTransform:destroy()
	if self._colorTransformShader then
		self._colorTransformShader:release()
		self._colorTransformShader = nil
	end
	
	ColorTransform.super.destroy(self)
end

return ColorTransform
