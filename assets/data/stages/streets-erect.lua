local Traffic = require "streets.traffic"
local Ambient = require "streets.ambient"
local Rain    = require "shaders.rain"
local DustGroup = require "dust"

local timer, traffic, ambient, rain, rainLow, scrollingSky = 0
local colorShader = Shader('adjustColor')

function postCreate()
	rain = Rain.create(PlayState.SONG.song)
	rainLow = Rain.create(PlayState.SONG.song, true)

	traffic = Traffic(phillyCars, phillyCars2, phillyTraffic)
	phillyCars2.flipX = true
	phillyTraffic_lightmap.blend = "add"
	phillyHighwayLights_lightmap.blend = "add"

	game.camera.shader = ClientPrefs.data.shader and
		(ClientPrefs.data.lowQuality and rainLow:get() or rain:get()) or nil

	local soundConfigs = {
		{
			path = paths.getSound('streets/rainAmbience'),
			startVolume = Rain.startIntensity,
			targetVolume = Rain.endIntensity,
			endVolume = Rain.endIntensity,
			intensityMultiplier = 2,
			randomStart = true
		}, {
			path = paths.getSound('streets/carAmbience'),
			startVolume = Rain.startIntensity * 0.3,
			targetVolume = Rain.endIntensity * 0.3,
			endVolume = Rain.endIntensity * 0.3,
			intensityMultiplier = 1,
			randomStart = true
		}
	}

	ambient = Ambient(soundConfigs)

	scrollingSky = Sprite(-650, -275)
	scrollingSky:loadTexture(paths.getImage(SCRIPT_PATH .. 'phillySkybox'))
	scrollingSky.scrollFactor:set(0.1, 0.1)
	scrollingSky.zIndex = 10
	scrollingSky.scale:set(0.65, 0.65)
	scrollingSky.texture:setWrap("repeat", "mirroredrepeat")
	local sw, sh = scrollingSky.texture:getDimensions()
	scrollingSky:loadTexture(scrollingSky.texture, true, sw - 1, 717)
	scrollingSky.animation:add("a", {0}, 1)
	scrollingSky.animation:play("a")
	scrollingSky:updateHitbox()
	self:add(scrollingSky)

	local mists = DustGroup(self)
	add(mists)
	mists:add('mistMid', 0, 660, 1.2, 1.2, 1000, 172, 0x5C5C5C, 0.6, 1, 660, 0.35, 70)
	mists:add('mistMid', 0, 500, 1.1, 1.1, 1000, 150, 0x5C5C5C, 0.6, 1, 500, 0.3, 80)
	mists:add('mistBack', 0, 540, 1.2, 1.2, 1001, -80, 0x5C5C5C, 0.8, 1, 540, 0.4, 60)
	mists:add('mistMid', 0, 230, 0.95, 0.95, 99, -50, 0x5C5C5C, 0.5, 0.8, 230, 0.3, 70)
	mists:add('mistBack', 0, 170, 0.8, 0.8, 88, 40, 0x5C5C5C, 1, 0.7, 170, 0.35, 50)
	mists:add('mistMid', 0, -80, 0.5, 0.5, 39, 20, 0x5C5C5C, 1, 1.1, -80, 0.08, 100)

	colorShader.hue = -5
	colorShader.saturation = -40
	colorShader.contrast = -25
	colorShader.brightness = -20

	boyfriend.shader = colorShader:get()
	dad.shader = colorShader:get()
	gf.shader = colorShader:get()

	refresh()
end

local skyScrollX
function postUpdate(dt)
	timer = timer + dt

	local remap = math.remapToRange(conductor.time / 1000, 0,
									game.sound.music.duration,
									Rain.startIntensity, Rain.endIntensity)
	rain.intensity = remap
	rainLow.intensity = remap

	if scrollingSky then
		if skyScrollX == nil then skyScrollX = scrollingSky.x end
		skyScrollX = skyScrollX - dt * 22
		local skyQuad = scrollingSky:getCurrentFrame()
		if skyQuad then
			skyQuad.quad:setViewport(skyScrollX, 0, 6000, 2000)
		end
	end

	if game.sound.music and ambient then
		ambient:updateIntensity(game.sound.music.time, game.sound.music.duration)
	end
end

local paperBeat = 0
local isPaperVisible = false
function beat(b)
	traffic:beat(b)
	if not isPaperVisible and paperBeat > math.random(36, 50) then
		paperBeat = 0
		isPaperVisible = true
		paper.animation:get("paperBlow").framerate = math.random(20, 35)
		paper.animation:play("paperBlow", true)
		paper.offset.y = math.random(-150, 200)
		paper.alpha = 1
		paper.flipY = love.math.randomBool(50)
		paper.animation.onFinish:addOnce(function()
			isPaperVisible = false
			paper.alpha = 0
		end)
	elseif not isPaperVisible then
		paperBeat = paperBeat + 1
	end
end

function pause() if ambient then ambient:pause() end end

function substateClosed() if ambient then ambient:resume() end end

function destroy() if ambient then ambient:stop() end end

function onSettingChange(category, setting)
	if not setting == "shader" or not setting == "lowQuality" then return end
	game.camera.shader = ClientPrefs.data.shader and
		(ClientPrefs.data.lowQuality and rainLow:get() or rain:get()) or nil
end
