local sky, cars, cars2, traffic

local rainStartIntensity = .01
local rainEndIntensity = .23

local lightsStop = false
local lastChange = 0
local changeInterval = 8

local carWaiting = false
local stopCar = true
local stopCar2 = true

switch(PlayState.SONG.song:lower(), {
	["darnell"] = function()
		rainStartIntensity = 0
		rainEndIntensity = 0.1
	end,
	["lit up"] = function()
		rainStartIntensity = 0.1
		rainEndIntensity = 0.2
	end,
	["2hot"] = function()
		rainStartIntensity = 0.2
		rainEndIntensity = 0.4
	end
})

local rain = Shader("rain")
rain.scale = game.height / 200
rain.intensity = rainStartIntensity
rain.distortionStrength = 0.5

local function make(x, y, filename, sx, sy, front)
	local sprite = Sprite(x, y)
	sprite:loadTexture(paths.getImage(SCRIPT_PATH .. filename))
	sprite:setScrollFactor(sx, sy)
	add(sprite, front)
	return sprite
end

function preload()
	return {
		{"image", SCRIPT_PATH .. "phillySkybox"},
		{"image", SCRIPT_PATH .. "phillySkyline"},
		{"image", SCRIPT_PATH .. "phillyForegroundCity"},
		{"image", SCRIPT_PATH .. "phillyConstruction"},
		{"image", SCRIPT_PATH .. "phillyHighwayLights"},
		{"image", SCRIPT_PATH .. "phillyHighwayLights_lightmap"},
		{"image", SCRIPT_PATH .. "phillyHighway"},
		{"image", SCRIPT_PATH .. "phillySmog"},
		{"image", SCRIPT_PATH .. "phillyTraffic_lightmap"},
		{"image", SCRIPT_PATH .. "phillyForeground"},
		{"image", SCRIPT_PATH .. "SpraycanPile"},
		{"image", SCRIPT_PATH .. "phillyCars"},
		{"image", SCRIPT_PATH .. "phillyTraffic"}
	}
end

function create()
	camZoom = 0.77
	boyfriendPos = {x = 2151, y = 500}
	gfPos = {x = 1100, y = 470}
	dadPos = {x = 920, y = 1330}

	boyfriendCam.x = boyfriendCam.x - 150
	boyfriendCam.y = boyfriendCam.y - 10
	dadCam:set(500, -100)

	if ClientPrefs.data.shader then
		game.camera.shader = rain:get()
	end

	sky = Sprite(-180, -180, paths.getImage(SCRIPT_PATH .. 'phillySkybox'))
	sky.scrollFactor:set(0.1, 0.1)
	sky.scale:set(0.65, 0.65)

	--workaround till i make a proper class - kaoy
	sky.texture:setWrap("repeat", "repeat")
	local sw, sh = sky.texture:getDimensions()
	sky:loadTexture(sky.texture, true, sw - 1, 718)
	sky.animation:add("a", {0}, 1); sky.animation:play("a")
	sky:updateHitbox()

	add(sky)

	make(-545, -273, 'phillySkyline', 0.2, 0.2)
	make(625, 94, 'phillyForegroundCity', 0.3, 0.3)
	make(1800, 364, 'phillyConstruction', 0.7, 1)

	make(284, 305, 'phillyHighwayLights', 1, 1)

	local lightsLightmap = make(284, 305, 'phillyHighwayLights_lightmap', 1, 1)
	lightsLightmap.alpha = 0.6
	lightsLightmap.blend = "add"

	make(139, 209, 'phillyHighway', 1, 1)
	make(-6, 245, 'phillySmog', 0.8, 1)

	cars = Sprite(1200, 818)
	cars:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'phillyCars'))
	cars:setScrollFactor(0.9, 1)
	add(cars)

	cars2 = Sprite(1200, 818)
	cars2:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'phillyCars'))
	cars2:setScrollFactor(0.9, 1)
	cars2.flipX = true
	add(cars2)

	for i = 1, 4 do
		local n = 'car' .. i
		cars:addAnimByPrefix(n, n, 24, true)
		cars2:addAnimByPrefix(n, n, 24, true)
	end

	traffic = Sprite(1840, 608)
	traffic:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'phillyTraffic'))
	traffic:setScrollFactor(0.9, 1)
	traffic:addAnimByPrefix('togreen', 'redtogreen', 24, false)
	traffic:addAnimByPrefix('tored', 'greentored', 24, false)
	add(traffic)

	local trafficLightmap = make(1840, 608, 'phillyTraffic_lightmap', 0.9, 1)
	trafficLightmap.alpha = 0.6
	trafficLightmap.blend = "add"

	make(88, 317, 'phillyForeground', 1, 1)
	make(920, 1045, 'SpraycanPile', 1, 1, true)
end

local paths = {
	{
		Point(1950 - 306.6 - 80, 980 - 168.3 + 15),
		Point(2400 - 306.6, 980 - 168.3 - 50),
		Point(3102 - 306.6, 1127 - 168.3 + 40)
	},
	{
		Point(1500 - 306.6 - 20, 1049 - 168.3 - 20),
		Point(1770 - 306.6 - 80, 994 - 168.3 + 10),
		Point(1950 - 306.6 - 80, 980 - 168.3 + 15)
	},
	{
		Point(1570 - 306.6, 1049 - 168.3 - 30),
		Point(2400 - 306.6, 980 - 168.3 - 50),
		Point(3102 - 306.6, 1127 - 168.3 + 40)
	},
	{
		Point(3102 - 306.6, 1127 - 168.3 + 60),
		Point(2400 - 306.6, 980 - 168.3 - 30),
		Point(1570 - 306.6, 1049 - 168.3 - 10)
	}
}

function finishCarLights(sprite)
	carWaiting = false

	local duration = math.random() + math.random(1.8, 3)
	local startdelay = math.random() + math.random(0.2, 1.2)

	sprite.angle = -5
	tween:tween(sprite, {angle = 18}, duration, {ease = Ease.sineIn, startDelay = startdelay})
	tween:quadPath(sprite, paths[1], duration, true, {
		ease = Ease.sineIn,
		startDelay = startdelay,
		onComplete = function() stopCar = true end
	})
end

function driveCarLights(sprite)
	stopCar = false
	tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)
	local extraOffset = {0, 0}
	local duration = 2

	if variant == 1 then
		duration = math.random() + math.random(1, 1.7)
	elseif variant == 2 then
		extraOffset = {20, -15}
		duration = math.random() + math.random(0.9, 1.5)
	elseif variant == 3 then
		extraOffset = {30, 50}
		duration = math.random() + math.random(1.5, 2.5)
	elseif variant == 4 then
		extraOffset = {10, 60}
		duration = math.random() + math.random(1.5, 2.5)
	end

	sprite.offset:set(extraOffset[1], extraOffset[2])
	sprite.angle = -7
	tween:tween(sprite, {angle = -5}, duration, {ease = Ease.cubeOut})
	tween:quadPath(sprite, paths[2], duration, true, {
		ease = Ease.cubeOut,
		onComplete = function()
			carWaiting = true
			if not lightsStop then finishCarLights(cars) end
		end
	})
end

function driveCar(sprite)
	stopCar = false
	tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)

	local extraOffset = {0, 0}
	local duration = 2

	if variant == 1 then
		duration = math.random() + math.random(1, 1.7)
	elseif variant == 2 then
		extraOffset = {20, -15}
		duration = math.random() + math.random(0.6, 1.2)
	elseif variant == 3 then
		extraOffset = {30, 50}
		duration = math.random() + math.random(1.5, 2.5)
	elseif variant == 4 then
		extraOffset = {10, 60}
		duration = math.random() + math.random(1.5, 2.5)
	end
	sprite.offset:set(extraOffset[1], extraOffset[2])

	sprite.angle = -8
	tween:tween(sprite, {angle = 18}, duration)
	tween:quadPath(sprite, paths[3], duration, true, {
		onComplete = function() stopCar = true end
	})
end

function driveCarBack(sprite)
	stopCar2 = false
	tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)

	local extraOffset = {0, 0}
	local duration = 2

	if variant == 1 then
		duration = math.random() + math.random(1, 1.7)
	elseif variant == 2 then
		extraOffset = {20, -15}
		duration = math.random() + math.random(0.6, 1.2)
	elseif variant == 3 then
		extraOffset = {30, 50}
		duration = math.random() + math.random(1.5, 2.5)
	elseif variant == 4 then
		extraOffset = {10, 60}
		duration = math.random() + math.random(1.5, 2.5)
	end

	sprite.offset:set(extraOffset[1], extraOffset[2])

	sprite.angle = 18
	tween:tween(sprite, {angle = -8}, duration)
	tween:quadPath(sprite, paths[4], duration, true, {
		onComplete = function() stopCar2 = true end
	})
end

local x
function update(dt)
	if x == nil then x = sky.x end
	x = x - dt * 22
	local skyQuad = sky:getCurrentFrame()
	if skyQuad then skyQuad.quad:setViewport(x, 0, 2922, 900) end

	local remap = math.remapToRange(conductor.time / 1000, 0, game.sound.music.duration,
		rainStartIntensity, rainEndIntensity)
	rain.intensity = remap
end

function beat(b)
	if love.math.randomBool(10) and b ~= (lastChange + changeInterval) and stopCar then
		(lightsStop and driveCarLights or driveCar)(cars)
	end
	if love.math.randomBool(10) and b ~= (lastChange + changeInterval) and stopCar2 and not lightsStop then
		driveCarBack(cars2)
	end

	if b == (lastChange + changeInterval) then
		lastChange, lightsStop = b, not lightsStop
		traffic.animation:play(lightsStop and 'tored' or 'togreen')
		changeInterval = lightsStop and 20 or 30
		if not lightsStop and carWaiting then
			finishCarLights(cars)
		end
	end
end

function onSettingChange(category, setting)
	if not setting == "shader" then return end
	if ClientPrefs.data.shader then
		game.camera.shader = rain:get()
	else
		game.camera.shader = nil
	end
end
