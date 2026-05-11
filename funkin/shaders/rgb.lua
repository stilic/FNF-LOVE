local RGBShader = {}

RGBShader.code = [[
	uniform vec3 r; uniform vec3 g; uniform vec3 b;
	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 pixel = Texel(texture, texture_coords);
		pixel.rgb = min(pixel.r * r + pixel.g * g + pixel.b * b, vec3(1.));
		return pixel * color;
	}
]]

RGBShader.actorCode = [[
	uniform vec3 r; uniform vec3 g; uniform vec3 b;
	uniform Image MainTex;
	void effect() {
		vec4 pixel = Texel(MainTex, VaryingTexCoord.xy / VaryingTexCoord.z);
		pixel.rgb = min(pixel.r * r + pixel.g * g + pixel.b * b, vec3(1.));
		love_PixelColor = pixel * VaryingColor;
	}
]]

RGBShader.shader = nil
RGBShader.actorShader = nil

function RGBShader.init()
	RGBShader.shader	  = love.graphics.newShader(RGBShader.code)
	RGBShader.actorShader = love.graphics.newShader(RGBShader.actorCode)
end

function RGBShader.apply(r, g, b)
	local s = RGBShader.shader
	s:send("r", {r[1], r[2], r[3]})
	s:send("g", {g[1], g[2], g[3]})
	s:send("b", {b[1], b[2], b[3]})
	love.graphics.setShader(s)
end

function RGBShader.applyActor(r, g, b)
	local s = RGBShader.actorShader
	s:send("r", {r[1], r[2], r[3]})
	s:send("g", {g[1], g[2], g[3]})
	s:send("b", {b[1], b[2], b[3]})
	love.graphics.setShader(s)
end

function RGBShader.reset()
	love.graphics.setShader()
end

return RGBShader
