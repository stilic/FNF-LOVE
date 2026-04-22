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

local shader, dancers = Shader("wave"), {}
shader.intensity = 2.6
shader.speed = 6

shader.position = {0.495, 0.34}
shader.radius = 0.13532459616
local timeThreshold = math.rad(360 / 6.22)

function postCreate()
	limoSunset.shader = shader:get()
	skyOverlay.blend = "add"

	for _, m in ipairs(jsonInstances) do
		if m.name:startsWith("limoDancer") then
			table.insert(dancers, m)
		end
	end
end

local bgLimoTime = 0
local cameraOffset = {0, 0}
local offsetTime = 0
function update(dt)
	bgLimoTime = bgLimoTime + dt / 2
	bgLimo.x = -200 + 120 * math.sin(bgLimoTime)

	offsetTime = offsetTime + dt
	cameraOffset[1] = 14 * math.sin(offsetTime * 1.5)
	cameraOffset[2] = 14 * math.cos(offsetTime * 2.5)

	shader.__time = shader.__time % timeThreshold

	for i = 1, 5 do
		dancers[i].offset.x = -120 * math.sin(bgLimoTime)
	end
end

function onCameraMove(event)
	event.offset.x, event.offset.y =
		event.offset.x + cameraOffset[1], event.offset.y + cameraOffset[2]
end

function beat(b)
	if love.math.randomBool(10) and fastCarCanDrive then
		fastCarDrive()
	end
end
