local Traffic = require "streets.traffic"
local Rain    = require "shaders.rain"
local Ambient = require "streets.ambient"

local ambient

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
			startVolume = Rain.startIntensity * 0.6,
			targetVolume = Rain.endIntensity * 0.6,
			endVolume = Rain.endIntensity * 0.6,
			intensityMultiplier = 1.3,
			randomStart = true
		}, {
			path = paths.getSound('streets/carAmbience'),
			startVolume = Rain.startIntensity,
			targetVolume = Rain.endIntensity,
			endVolume = Rain.endIntensity,
			intensityMultiplier = 2.2,
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

	refresh()
end

local skyScrollX
function postUpdate(dt)
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

function onSettingChange(category, setting)
	if not setting == "shader" or not setting == "lowQuality" then return end
	game.camera.shader = ClientPrefs.data.shader and
		(ClientPrefs.data.lowQuality and rainLow:get() or rain:get()) or nil
end

function beat(b)
	traffic:beat(b)
end
