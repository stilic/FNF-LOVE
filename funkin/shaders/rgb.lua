local RGBShader = {cache = {}}
RGBShader.code = [[
	uniform vec3 r; uniform vec3 g; uniform vec3 b;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 pixel = Texel(texture, texture_coords);

		vec4 newColor = pixel;
		newColor.rgb = min(pixel.r * r + pixel.g * g + pixel.b * b, vec3(1.));

		pixel.rgb = mix(pixel.rgb, newColor.rgb, 1.0);
		return pixel * color;
	}
]]
RGBShader.actorCode = [[
	uniform vec3 r; uniform vec3 g; uniform vec3 b;
	uniform Image MainTex;

	void effect() {
		vec4 pixel = Texel(MainTex, VaryingTexCoord.xy / VaryingTexCoord.z);

		vec4 newColor = pixel;
		newColor.rgb = min(pixel.r * r + pixel.g * g + pixel.b * b, vec3(1.));

		pixel.rgb = mix(pixel.rgb, newColor.rgb, 1.0);
		love_PixelColor = pixel * VaryingColor;
	}
]]

function RGBShader.set(shader, r, g, b)
	shader:send("r", {r[1], r[2], r[3]})
	shader:send("g", {g[1], g[2], g[3]})
	shader:send("b", {b[1], b[2], b[3]})
	return shader
end

function RGBShader.getKey(r, g, b)
	return string.format("%.3f%.3f%.3f_%.3f%.3f%.3f_%.3f%.3f%.3f",
		r[1], r[2], r[3],
		g[1], g[2], g[3],
		b[1], b[2], b[3])
end

function RGBShader.create(r, g, b, unique)
	r, g, b = r or Color.RED, g or Color.LIME, b or Color.BLUE

	local key = RGBShader.getKey(r, g, b)
	local shader = RGBShader.cache[key]
	if shader == nil or unique then
		shader = RGBShader.set(love.graphics.newShader(RGBShader.code), r, g, b)
		if not unique then RGBShader.cache[key] = shader end
	end

	return shader
end

function RGBShader.actorCreate(r, g, b, unique)
	r, g, b = r or Color.RED, g or Color.LIME, b or Color.BLUE

	local key = "actor_" .. RGBShader.getKey(r, g, b)
	local shader = RGBShader.cache[key]
	if shader == nil or unique then
		shader = RGBShader.set(love.graphics.newShader(RGBShader.actorCode), r, g, b)
		if not unique then RGBShader.cache[key] = shader end
	end

	return shader
end

function RGBShader.reset()
	for key, shader in pairs(RGBShader.cache) do
		shader:release()
		RGBShader.cache[key] = nil
	end
end

return RGBShader
