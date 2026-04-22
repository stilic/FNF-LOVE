local ColorTransform = Basic:extend("ColorTransform")

function ColorTransform:new()
	ColorTransform.super.new(self)
	self._buffer = {1, 1, 1, 1}

	self._colorTransformShader = love.graphics.newShader[[
		extern vec4 colorOffset;
		extern vec4 colorMultiplier;

		vec4 effect(vec4 color, Image tex, vec2 texCoords, vec2 screenCoords) {
			vec4 texColor = Texel(tex, texCoords) * color;
			vec4 result = texColor * colorMultiplier;
			result.rgb += colorOffset.rgb * texColor.a;
			result.a += colorOffset.a;
			return result;
		}
	]]

	self:setColorMultiplier(1, 1, 1, 1)
	self:setColorOffset(0, 0, 0, 0)
end

function ColorTransform:setColorOffset(r, g, b, a)
	local buf = self._buffer
	buf[1], buf[2], buf[3], buf[4] = r or 0, g or 0, b or 0, a or 0
	self._colorTransformShader:send("colorOffset", buf)
end

function ColorTransform:setColorMultiplier(r, g, b, a)
	local buf = self._buffer
	buf[1], buf[2], buf[3], buf[4] = r or 1, g or 1, b or 1, a or 1
	self._colorTransformShader:send("colorMultiplier", buf)
end

function ColorTransform:getShader()
	return self._colorTransformShader
end

function ColorTransform:areEqual(ct1, ct2)
	if ct1 == ct2 then return true end
	if not ct1 or not ct2 then return false end

	return ct1.rm == ct2.rm and ct1.gm == ct2.gm and
		   ct1.bm == ct2.bm and ct1.am == ct2.am and
		   ct1.ro == ct2.ro and ct1.go == ct2.go and
		   ct1.bo == ct2.bo and ct1.ao == ct2.ao
end

function ColorTransform:applyRawTransform(ct)
	if not ct then
		self:setColorMultiplier(1, 1, 1, 1)
		self:setColorOffset(0, 0, 0, 0)
	else
		self:setColorMultiplier(ct.rm, ct.gm, ct.bm, ct.am)
		self:setColorOffset(ct.ro, ct.go, ct.bo, ct.ao)
	end
end

function ColorTransform:destroy()
	if self._colorTransformShader then
		self._colorTransformShader:release()
		self._colorTransformShader = nil
	end
	ColorTransform.super.destroy(self)
end

return ColorTransform
