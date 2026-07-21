local ColorTransform = Classic:extend("ColorTransform")

local GLSL_BLOCK = [[
uniform vec4  colorMultiply;
uniform vec4  colorOffset;
uniform float grayscaleAmount;

vec4 applyColorTransform(vec4 c) {
	c = clamp(c * colorMultiply + colorOffset, 0.0, 1.0);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum), grayscaleAmount);
	return c;
}
]]

local DEFAULTS = {
	colorMultiply = { 1, 1, 1, 1 },
	colorOffset = { 0, 0, 0, 0 },
	grayscaleAmount = 0
}

function ColorTransform.preprocess(source)
	local injected = false
	local result = source:gsub("#pragma use ColorTransform[^\n]*", function()
		injected = true
		return GLSL_BLOCK
	end)
	return result, injected
end

function ColorTransform.newShader(source, vertSource)
	local processed, hadPragma = ColorTransform.preprocess(source)
	local s = love.graphics.newShader(processed, vertSource)
	if hadPragma then
		s:send("colorMultiply", DEFAULTS.colorMultiply)
		s:send("colorOffset", DEFAULTS.colorOffset)
		s:send("grayscaleAmount", DEFAULTS.grayscaleAmount)
	end
	return s
end

local standaloneShader = nil

local function ensureStandalone()
	if standaloneShader then return standaloneShader end
	standaloneShader = love.graphics.newShader(GLSL_BLOCK .. [[
		vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
			return applyColorTransform(Texel(tex, tc) * vcolor);
		}
	]])
	standaloneShader:send("colorMultiply", DEFAULTS.colorMultiply)
	standaloneShader:send("colorOffset", DEFAULTS.colorOffset)
	standaloneShader:send("grayscaleAmount", DEFAULTS.grayscaleAmount)
	return standaloneShader
end

function ColorTransform:new(rMul, gMul, bMul, aMul, rOff, gOff, bOff, aOff, gray)
	self.mul = { rMul or 1, gMul or 1, bMul or 1, aMul or 1 }
	self.off = { rOff or 0, gOff or 0, bOff or 0, aOff or 0 }
	self.gray = gray or 0
end

function ColorTransform:apply(shader)
	local s = shader
	if not s then
		s = ensureStandalone()
		love.graphics.setShader(s)
	end
	if s:hasUniform("colorMultiply") then s:send("colorMultiply", self.mul) end
	if s:hasUniform("colorOffset") then s:send("colorOffset", self.off) end
	if s:hasUniform("grayscaleAmount") then s:send("grayscaleAmount", self.gray) end
end

function ColorTransform.reset(shader)
	local s = shader or love.graphics.getShader()
	if not s then return end
	if s:hasUniform("colorMultiply") then s:send("colorMultiply", DEFAULTS.colorMultiply) end
	if s:hasUniform("colorOffset") then s:send("colorOffset", DEFAULTS.colorOffset) end
	if s:hasUniform("grayscaleAmount") then s:send("grayscaleAmount", DEFAULTS.grayscaleAmount) end
end

function ColorTransform:setMultiply(r, g, b, a)
	self.mul[1] = r or self.mul[1]
	self.mul[2] = g or self.mul[2]
	self.mul[3] = b or self.mul[3]
	self.mul[4] = a or self.mul[4]
end

function ColorTransform:setOffset(r, g, b, a)
	self.off[1] = (r or 0) / 255
	self.off[2] = (g or 0) / 255
	self.off[3] = (b or 0) / 255
	self.off[4] = (a or 0) / 255
end

function ColorTransform:getOffset()
	return self.off[1] * 255, self.off[2] * 255, self.off[3] * 255, self.off[4] * 255
end

function ColorTransform.identity()
	return ColorTransform()
end

function ColorTransform.tint(r, g, b, a)
	return ColorTransform(r or 1, g or 1, b or 1, a or 1)
end

function ColorTransform.brightness(offset)
	local v = math.max(-1, math.min(1, (offset or 0) / 255))
	return ColorTransform(1, 1, 1, 1, v, v, v, 0)
end

function ColorTransform.grayscale(amount)
	local t = ColorTransform()
	t.gray = math.max(0, math.min(1, amount or 1))
	return t
end

return ColorTransform
