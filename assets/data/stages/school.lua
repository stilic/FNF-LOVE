local BackgroundGirls = require "backgroundgirls"

local bgGirls, cam
local floor = math.floor

function preload()
	return {
		{"image", SCRIPT_PATH .. "weebSky"},
		{"image", SCRIPT_PATH .. "bgFreaks"},
		{"image", SCRIPT_PATH .. "weebSchool"},
		{"image", SCRIPT_PATH .. "weebStreet"},
		{"image", SCRIPT_PATH .. "weebTreesBack"},
		{"image", SCRIPT_PATH .. "weebTrees"},
		{"image", SCRIPT_PATH .. "petals"}
	}
end

function create()
	camZoom = 1

	game.camera:resize(floor(1280 / 6), floor(720 / 6), 1, 1, true)
	game.camera.pixelPerfect = true
	game.camera.antialiasing = false

	cam = Camera()
	cam:resize(floor(1280 / 4), floor(720 / 4), 1, 1, true)
	cam.pixelPerfect = true
	cam.antialiasing = false
	table.insert(game.cameras.list, 2, cam)

	boyfriendPos:set(1080, 60)
	gfPos:set(580, 90)
	dadPos:set(0, -400)

	boyfriendCam:set(-20, 0)
	dadCam:set(80, 50)
	gfCam:set(gfCam.x + 40, gfCam.y)
	-- gfCam.x = gfCam.x + 40
	-- gfCam.y = gfCam.y - 4

	local bgSky = Sprite()
	bgSky:loadTexture(paths.getImage(SCRIPT_PATH .. 'weebSky'))
	bgSky:setScrollFactor(0.1, 0.1)
	add(bgSky)
	bgSky.antialiasing = false

	local bgSchool = Sprite(-12, 0)
	bgSchool:loadTexture(paths.getImage(SCRIPT_PATH .. 'weebSchool'))
	bgSchool:setScrollFactor(0.6, 0.90)
	add(bgSchool)
	bgSchool.antialiasing = false

	local bgStreet = Sprite(0, -1)
	bgStreet:loadTexture(paths.getImage(SCRIPT_PATH .. 'weebStreet'))
	add(bgStreet)
	bgStreet.antialiasing = false

	local fgTrees = Sprite(5, 0)
	fgTrees:loadTexture(paths.getImage(SCRIPT_PATH .. 'weebTreesBack'))
	fgTrees:updateHitbox()
	add(fgTrees)
	fgTrees.antialiasing = false

	local bgTrees = Sprite(-100, -168)
	bgTrees:setFrames(paths.getPackerAtlas(SCRIPT_PATH .. 'weebTrees'))
	bgTrees:addAnim('treeLoop', {
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
	}, 12)
	bgTrees:play('treeLoop')
	bgTrees:setScrollFactor(0.85, 0.85)
	bgTrees:updateHitbox()
	add(bgTrees)
	bgTrees.antialiasing = false

	local treeLeaves = Sprite(-20, 10)
	treeLeaves:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'petals'))
	treeLeaves:setScrollFactor(0.85, 0.85)
	treeLeaves:addAnimByPrefix('PETALS ALL', 'PETALS ALL', 24, true)
	treeLeaves:play('PETALS ALL')
	treeLeaves:updateHitbox()
	add(treeLeaves)
	treeLeaves.antialiasing = false

	bgGirls = BackgroundGirls(0, 26, paths.formatToSongPath(PlayState.SONG.song) == "roses")
	bgGirls:updateHitbox()
	bgGirls.antialiasing = false
	add(bgGirls)

	refresh()
end

function postCreate()
	for _, nf in ipairs(notefields) do
		if nf.character then
			local m = nf.character
			m.scale.x, m.scale.y = 1, 1
			m:updateHitbox()
			m.x, m.y = floor(m.x / 6), floor(m.y / 6)
			if m.cameraPosition then
				m.cameraPosition.x, m.cameraPosition.y =
					floor(m.cameraPosition.x / 6), floor(m.cameraPosition.y / 6)
			end
			for _, anim in pairs(m.animation:getList()) do
				anim.offset:set(floor(anim.offset.x / 6), floor(anim.offset.y / 6))
			end
		end
	end

	dad:dance()
	dad:finish()
	cameraMovement(getCameraPosition(camTarget))
	game.camera:follow(camFollow, nil)

	judgeSprites.cameras = {cam}
	judgeSprites:setPosition(cam.width / 4, 264 / 4)
	judgeSprites.area = {width = 135, height = 30}
end

function postGameOverCreate()
	game.cameras.remove(cam)
	local m = game.getState(true).boyfriend
	m.scale:set(1, 1)
	m:updateHitbox()
	m.x, m.y = floor(m.x / 6), floor(m.y / 6)
	if m.cameraPosition then
		m.cameraPosition.x, m.cameraPosition.y =
			floor(m.cameraPosition.x / 6), floor(m.cameraPosition.y / 6)
	end
	local x, y = m:getGraphicMidpoint()
	game.getState(true).camFollow = Point(x - 30, y - 9)
	for _, anim in pairs(m.animation:getList()) do
		anim.offset:set(floor(anim.offset.x / 6), floor(anim.offset.y / 6))
	end
end

function postGameOverUpdate()
	game.camera.zoom = 1
end

function postUpdate()
	game.camera.zoom = math.truncate(game.camera.zoom, 3)
	cam.zoom = math.truncate(camHUD.zoom, 3)
end

function beat(b) bgGirls:dance() end
