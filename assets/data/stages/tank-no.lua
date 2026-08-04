local TankmenGroup = require "tankmengroup"

local tankWatchtower
local tankGround
local tankAngle = love.math.random(-90, 45)
local tankSpeed = love.math.random(5, 7)

local tankmanRun
local fgSprites

function preload()
	local assets = {
		{"image", SCRIPT_PATH .. "tankSky"},
		{"image", SCRIPT_PATH .. "tankClouds"},
		{"image", SCRIPT_PATH .. "tankMountains"},
		{"image", SCRIPT_PATH .. "tankBuildings"},
		{"image", SCRIPT_PATH .. "tankRuins"},
		{"image", SCRIPT_PATH .. "tankGround"},
		{"image", SCRIPT_PATH .. "smokeLeft"},
		{"image", SCRIPT_PATH .. "smokeRight"},
		{"image", SCRIPT_PATH .. "tankWatchtower"},
		{"image", SCRIPT_PATH .. "tankRolling"},
		{"image", SCRIPT_PATH .. "tanks"}
	}
	return assets
end

function create()
	self.camZoom = 0.9

	self.boyfriendPos = {x = 810, y = 100}
	self.gfPos = {x = 200, y = 65}
	self.dadPos = {x = 20, y = 100}

	local bg = Sprite(-380, -400 + 196)
	bg:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankSky'))
	bg:setScrollFactor()
	self:add(bg)

	local clouds = Sprite()
	clouds:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankClouds'))
	clouds:setScrollFactor(0.4, 0.4)
	clouds.x = math.random(-700, -100)
	clouds.y = math.random(-20, 20)
	clouds.moves = true
	clouds.velocity.x = math.random() + math.random(5, 15)
	self:add(clouds)

	local tankMountains = Sprite(-300, -20)
	tankMountains:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankMountains'))
	tankMountains:setScrollFactor(0.2, 0.2)
	tankMountains:setGraphicSize(math.floor(tankMountains.width * 1.2))
	tankMountains:updateHitbox()
	self:add(tankMountains)

	local tankBuildings = Sprite(-200 + 136 * 1.1, 226 * 1.1)
	tankBuildings:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankBuildings'))
	tankBuildings:setScrollFactor(0.3, 0.3)
	tankBuildings:setGraphicSize(math.floor(tankBuildings.width * 1.1))
	tankBuildings:updateHitbox()
	self:add(tankBuildings)

	local tankRuins = Sprite(-200, 0)
	tankRuins:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankRuins'))
	tankRuins:setScrollFactor(0.35, 0.35)
	tankRuins:setGraphicSize(math.floor(tankRuins.width * 1.1))
	tankRuins:updateHitbox()
	self:add(tankRuins)

	local smokeLeft = Sprite(-200, -100)
	smokeLeft:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'smokeLeft'))
	smokeLeft:setScrollFactor(0.4, 0.4)
	smokeLeft:addAnimByPrefix('SmokeBlurLeft', 'SmokeBlurLeft', 24, true)
	smokeLeft:play('SmokeBlurLeft')
	self:add(smokeLeft)

	local smokeRight = Sprite(1100, -100)
	smokeRight:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'smokeRight'))
	smokeRight:setScrollFactor(0.4, 0.4)
	smokeRight:addAnimByPrefix('SmokeRight', 'SmokeRight', 24, true)
	smokeRight:play('SmokeRight')
	self:add(smokeRight)

	tankWatchtower = Sprite(100, 50)
	tankWatchtower:setFrames(paths.getSparrowAtlas(SCRIPT_PATH ..
		'tankWatchtower'))
	tankWatchtower:setScrollFactor(0.5, 0.5)
	tankWatchtower:addAnimByPrefix('watchtower gradient color',
		'watchtower gradient color', 24, false)
	tankWatchtower:play('watchtower gradient color', true)
	self:add(tankWatchtower)

	tankGround = Sprite(300, 300)
	tankGround:setFrames(paths.getSparrowAtlas(SCRIPT_PATH .. 'tankRolling'))
	tankGround:setScrollFactor(0.5, 0.5)
	tankGround:addAnimByPrefix('BG tank w lighting', 'BG tank w lighting', 24,
		true)
	tankGround:play('BG tank w lighting', true)
	self:add(tankGround)

	fgSprites = Group()
	self:add(fgSprites, true)

	local tankGround = Sprite(-420, -150 + 595 * 1.15)
	tankGround:loadTexture(paths.getImage(SCRIPT_PATH .. 'tankGround'))
	tankGround:setGraphicSize(math.floor(tankGround.width * 1.15))
	tankGround:updateHitbox()
	self:add(tankGround)

	local data = {
		{-500, 650, 1.7}, {-300, 750, 2, 0.2}, {450, 940},
		{1300, 1200, 3.5, 2.5}, {1300, 900}, {1620, 700}
	}
	local anims = {
		"fg tankhead far right instance 1",
		"fg tankhead 5 instance 1",
		"fg man 3 instance 1",
		"fg tankhead 4 instance 1",
		"fg tankman bobbin 3 instance 1",
		"fg tankhead far right instance 1"
	}

	local sparrow = paths.getSparrowAtlas(SCRIPT_PATH .. 'tanks')
	for i = 0, 5 do
		local info = data[i + 1]
		local fgTank = Sprite(info[1], info[2])
		fgTank:setFrames(sparrow)
		fgTank:setScrollFactor(info[3] or 1.5, info[4] or 1.5)
		fgTank:addAnimByPrefix('fg', anims[i + 1], 24, false)
		fgTank:play('fg', true)
		fgSprites:add(fgTank)
	end
	local member = fgSprites.members[4]
	fgSprites:remove(member); fgSprites:add(member)

	if PlayState.SONG.song:lower() == "stress" then
		tankmanRun = TankmenGroup()
		self:add(tankmanRun)
	end
end

function update(dt)
	tankAngle = tankAngle + dt * tankSpeed
	tankGround.angle = tankAngle - 90 + 15

	tankGround.x = 400 + math.cos(math.rad(tankAngle + 180)) * 1500
	tankGround.y = 1300 + math.sin(math.rad(tankAngle + 180)) * 1100
end

function beat(b)
	tankWatchtower:play('watchtower gradient color', true)

	for _, fgTank in ipairs(fgSprites.members) do fgTank:play('fg', true) end
end
