local function modify(obj, c, s, b)
	obj.shaderObj.isGraphic = obj:is(Graphic)
	obj.shaderObj.modifier = {c, s, b}
end

local function lightingAnimation()
	if ClientPrefs.data.flashingLights then
		modify(base, 1, 0.8, 1.6)
		modify(back, 1.25, 1.5, 0.8)
		modify(window, 1, 1, 10)

		reflect.alpha = 1
		local color = Color.BLACK
		boyfriend.color, dad.color, gf.color =
			color, color, color
	end

	Timer(timer):start(1 / 12, function()
		local eh = {c = 3, s = 2, b = 0.9}
		local eh2 = {b = 10}

		if ClientPrefs.data.flashingLights then
			modify(base, 1.5, 1, 0.5)
			modify(back, 1.5, 1, 0.5)
			modify(window, 1.3, 1, 0.5)

			reflect.alpha = 0
			local color = Color.WHITE
			boyfriend.color, dad.color, gf.color =
				color, color, color
		else
			-- lower the intensity for next animation
			eh2.b = 1.5
			eh.c, eh.s = 1.5, 1
		end

		Timer(timer):start(1 / 24, function()
			game.camera:shake(0.001, 1.4)
			camHUD:shake(0.001, 1.4)

			util.playSfx(paths.getSound('gameplay/thunder_' ..
				love.math.random(1, 2)))

			reflect.alpha = 0.5

			local ease = {ease = Ease.cubeOut}
			tween:tween(eh, {c = 1, s = 1, b = 1}, 1, ease)
			tween:tween(eh2, {b = 1}, 1, ease)

			tween:tween(reflect, {alpha = 0.6}, 0.7, ease)

			local tmp = {a = 0} -- whoops
			tween:tween(tmp, {a = 0}, 4, {onUpdate = function(this)
				modify(base, eh.c, eh.s, eh.b)
				modify(back, eh.c, eh.s, eh.b)
				modify(window, 1, 1, eh2.b)
			end,
				ease = Ease.quintOut
			})

			if boyfriend then
				boyfriend:playAnim('scared', true)
				boyfriend.lastHit = PlayState.conductor.time + 300
			end
			if gf then
				gf:playAnim('scared', true)
				gf.lastHit = PlayState.conductor.time + 300
			end
		end)
	end)
end

function preload()
	return {
		{"image", SCRIPT_PATH .. "window"},
		{"image", SCRIPT_PATH .. "bg_shadows"},
		{"image", SCRIPT_PATH .. "windowReflect"},
	}
end

function postCreate()
	base.shaderObj = Shader("csb")
	base.shader = base.shaderObj:get()
	window.shaderObj = Shader("csb")
	window.shader = window.shaderObj:get()
	windowBlend.blend = "add"
	windowBlend.alpha = 0.22
	back.shaderObj = Shader("csb")
	back.shader = back.shaderObj:get()
	reflect.alpha = 0.5
	reflect.blend = "add"
	reflect.shader = window.shader

	modify(base, 1, 1, 1)
	modify(back, 1, 1, 1)
	modify(window, 1, 1, 1)
end


local lightningStrikeBeat = 0
local lightningOffset = love.math.random(8, 24)
function beat()
	if love.math.randomBool(10) and curBeat > lightningStrikeBeat +
		lightningOffset then
		lightingAnimation()

		lightningStrikeBeat = curBeat
		lightningOffset = love.math.random(8, 24)
	end
end

function close()
	base.shaderObj:destroy()
	back.shaderObj:destroy()
	window.shaderObj:destroy()
end
