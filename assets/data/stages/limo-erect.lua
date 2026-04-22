local DustGroup = require "dust"

local haptic, sound = false
local fastCarCanDrive = true
local function resetFastCar()
	fastCar:setPosition(-12600, math.random(140, 250))
	fastCar.velocity.x = 0
	fastCarCanDrive = true
end

local carData = {
	{t = 1, c = function() haptic = true end},
	{t = 1.4, c = function() haptic = false end},
	{t = 2, c = function() resetFastCar() end}
}

local function fastCarDrive()
	sound = util.playSfx(paths.getSound('gameplay/carPass' .. love.math.random(0, 1)))
	fastCar.velocity.x = (love.math.random(170, 220) / game.dt)
	fastCar.moves = true
	fastCarCanDrive = false
	for _, data in pairs(carData) do
		Timer(state.timer):start(data.t, data.c)
	end
end

local function shootStar()
	shootingStar:setPosition(math.random(50, 900), math.random(-10, 20))
	shootingStar.flipX = love.math.randomBool(50)
	shootingStar.animation:play("shooting star")
end

local dancers = table.new(0, 5)

function postCreate()
	limoSunset.texture:setWrap("clamp", "clamp")
	local sw, sh = limoSunset.texture:getDimensions()
	limoSunset:loadTexture(limoSunset.texture, true, sw - 1, sh)
	limoSunset.animation:add("a", {0}, 1)
	limoSunset.animation:play("a")
	limoSunset.frames.frames[1].quad:setViewport(0, 0, sw * 1.5, sh)
	limoSunset:updateHitbox()

	local colorShader = Shader('adjustColor')
	colorShader.hue = -30;
	colorShader.saturation = -20;
	colorShader.contrast = 0;
	colorShader.brightness = -30;

	boyfriend.shader = colorShader:get()
	dad.shader = colorShader:get()
	gf.shader = colorShader:get()

	fastCar.shader = colorShader:get()

	for _, m in ipairs(jsonInstances) do
		if m.name:startsWith("limoDancer") then
			table.insert(dancers, m)
			m.shader = colorShader:get()
		end
	end

	local mists = DustGroup(self)
	add(mists)
	mists:add('mistMid', -650, -100, 1.1, 1.1, 400, 1700, 0xc6bfde, 0.4, 1.0, 100, 1.0, 200)
	mists:add('mistBack', -650, -100, 1.2, 1.2, 401, 2100, 0x6a4da1, 1.0, 1.3, 0, 0.8, 100)
	mists:add('mistMid', -650, -100, 0.8, 0.8, 99, 900, 0xa7d9be, 0.5, 1.5, -20, 0.5, 200)
	mists:add('mistBack', -650, -380, 0.6, 0.6, 98, 700, 0x9c77c7, 1.0, 1.5, -180, 0.4, 300)
	mists:add('mistMid', -650, -400, 0.2, 0.2, 15, 100, 0xE7A480, 1.0, 1.5, -450, 0.2, 150)

	refresh()
end

local timer = 0
function postUpdate(dt)
	timer = timer + dt
	bgLimo.offset.x = -120 * math.sin(timer / 2)
	for i = 1, 5 do
		dancers[i].offset.x = -120 * math.sin(timer / 2)
	end
	cameraOffset:set(14 * math.sin(timer * 1.5), 14 * math.cos(timer * 2.5))
end

local starBeat, starOffset = 0, 0
function beat(b)
	if love.math.randomBool(10) and fastCarCanDrive then
		fastCarDrive()
	end
	if love.math.randomBool(10) and b > (starBeat + starOffset) then
		shootStar()
		starBeat, starOffset = b, math.random(4, 8)
	end
end
