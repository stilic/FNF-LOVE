local shader = Shader("wiggle")

local floor = math.floor

function create()
	camZoom = 1

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

	game.camera:resize(floor(1280 / 6), floor(720 / 6), 1, 1, true)
	game.camera.pixelPerfect = true
	game.camera.antialiasing = false

	local bg = Sprite(-24, 0, paths.getImage(SCRIPT_PATH .. 'evilSchoolBG'))
	bg:setScrollFactor(0.6, 1)
	bg:updateHitbox()
	bg.antialiasing = false
	bg.shader = shader:get()
	add(bg)

	local floor = Sprite(0, 0)
	floor:loadTexture(paths.getImage(SCRIPT_PATH .. 'evilSchoolFG'))
	floor:updateHitbox()
	floor.antialiasing = false
	floor.shader = shader:get()
	add(floor)
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
	if dad then
		stage:insert(stage:indexOf(dad), Trail(dad, 4, 24, 0.3, 0.069))
	end


	dad:dance()
	dad:finish()
	cameraMovement(getCameraPosition(camTarget))
	game.camera:follow(camFollow, nil)

	judgeSprites.cameras = {cam}
	judgeSprites:setPosition(cam.width / 4, 264 / 4)
	judgeSprites.area = {width = 135, height = 30}
end

function postUpdate(dt)
	shader.__time = shader.__time % (2 * math.pi)
	game.camera.zoom = math.truncate(game.camera.zoom, 3)
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
