local LightSprite = require "light"

function postCreate()
	local colorShaderBf = Shader('adjustColor')
	local colorShaderDad = Shader('adjustColor')
	local colorShaderGf = Shader('adjustColor')

	colorShaderBf.brightness = -23
	colorShaderBf.hue = 12
	colorShaderBf.contrast = 7
	colorShaderBf.saturation = 0

	colorShaderGf.brightness = -30
	colorShaderGf.hue = -9
	colorShaderGf.contrast = -4
	colorShaderGf.saturation = 0

	colorShaderDad.brightness = -33
	colorShaderDad.hue = -32
	colorShaderDad.contrast = -23
	colorShaderDad.saturation = 0

	boyfriend.shader = colorShaderBf:get()
	dad.shader = colorShaderDad:get()
	gf.shader = colorShaderGf:get()

	local s = 343
	local funny = LightSprite(967 + s, -103 + s, 1, 0.9287, s, Color.fromHEX(0xffffb2))
	funny.scrollFactor:mul(1.2)
	funny.scale.y = 0.9287
	funny.alpha = 190 / 255
	funny.zIndex = 10
	add(funny)

	s = 188 / 2
	local glight = LightSprite(-171 + s, 242 + s, 1, 1.0562, s, Color.fromHEX(0x64fbb0))
	glight.alpha = 60 / 255
	glight.zIndex = 40
	add(glight)

	local rlight = LightSprite(-101 + s, 560 + s, 1, 1.0562, s, Color.fromHEX(0xf63b3b))
	rlight.alpha = 60 / 255
	rlight.zIndex = 41
	add(rlight)

	s = 420
	local above = LightSprite(816 + s, -138 + s, 1, 0.888, s, Color.fromHEX(0xffee98))
	above.alpha = 170 / 255
	above.zIndex = 4500
	above.blend = "add"
	above.scrollFactor:set(1.2, 1.2)
	add(above)

	refresh()
	close()
end
