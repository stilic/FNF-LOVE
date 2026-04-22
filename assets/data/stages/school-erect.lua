local RimEffect = require "shaders.rim"
local effects = {}

function create()
	if PlayState.SONG.song:lower() == "roses" then
		if freaks then freaks.idleSuffix = '-scared' end
	else
		if freaks then freaks.idleSuffix = '' end
	end
end

function postCreate()
	setupCharacter(boyfriend, "bf")
	setupCharacter(dad, "dad")
	setupCharacter(gf, "gf"):setHSB(-42, -10, 5, -25):setRimProperty(1.0, 3, 0.3)

	cam = Camera()
	cam:resize(math.floor(1280 / 4), math.floor(720 / 4), 1, 1, true)
	cam.pixelPerfect = true
	cam.antialiasing = false
	table.insert(game.cameras.list, 2, cam)

	judgeSprites.cameras = {cam}
	judgeSprites:setPosition(cam.width / 4, 264 / 4)
	judgeSprites.area = {width = 135, height = 30}
end

function setupCharacter(char, type)
	local fx = RimEffect(char)
	local maskPath = SCRIPT_PATH .. 'masks/' .. char.data.sprite:gsub('.*/', '') .. '_mask'
	fx:setMask(maskPath, 1, true, not char.antialiasing)
	table.insert(effects, fx)
	return fx
end

function draw()
	for _, fx in pairs(effects) do fx:update() end
end
