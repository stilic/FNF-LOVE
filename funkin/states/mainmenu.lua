local MainMenuState = State:extend("MainMenuState")

MainMenuState.curSelected = 1

function MainMenuState:enter()
	self.notCreated = false

	self.versionText = Text(0, game.height - 18, "v" .. Project.version, paths.getFont("vcr.ttf", 16))
	self.versionText.antialiasing = false
	self.versionText.outline.width = 1
	self.versionText.scrollFactor:set()

	self.script = Script("data/states/mainmenu", false)
	local event = self.script:call("create")
	if event == Script.Event_Cancel then
		self.notCreated = true
		MainMenuState.super.enter(self)
		self:add(self.versionText)
		self.script:call("postCreate")
		return
	end

	self.menuItems = {'storymode', 'freeplay', 'credits', 'options', 'donate'}

	game.camera.target = {x = 0, y = 0}
	self.camFollow = {x = 0, y = 0}
	game.camera:follow(self.camFollow, nil, 10)

	local yScroll = math.max(0.25 - (0.05 * (#self.menuItems - 4)), 0.1)
	self.menuBg = Sprite()
	self.menuBg:loadTexture(paths.getImage('menus/menuBG'))
	self.menuBg.scrollFactor:set(0, yScroll)
	self.menuBg:setGraphicSize(math.floor(self.menuBg.width * 1.175))
	self.menuBg:updateHitbox()
	self.menuBg:screenCenter()
	self:add(self.menuBg)

	self.menuYellow = paths.getImage('menus/menuBG')
	self.menuMagenta = paths.getImage('menus/menuBGMagenta')

	self.menuList = MenuList(paths.getSound("scrollMenu"), true, "centered", function(self, obj)
		for _, spr in ipairs(self.members) do
			spr.yAdd = 50 + (self.curSelected) * (80 - game.height * 0.005)
		end
	end)
	self.menuList.selectCallback = function(menuItem)
		self:enterSelection(self.menuItems[menuItem.ID])
	end
	self.menuList.speed = 8
	self.menuList.scrollFactor:set()

	for i = 0, #self.menuItems - 1 do
		local item = Sprite(0, 0)
		item:setFrames(paths.getSparrowAtlas('menus/mainmenu/' .. self.menuItems[i + 1]))
		item.animation:addByPrefix('idle', self.menuItems[i + 1] .. ' idle', 24)
		item.animation:addByPrefix('selected', self.menuItems[i + 1] .. ' selected', 24)
		item.animation:play('idle')
		item.yAdd = 50 + (self.menuList.curSelected) * (80 - game.height * 0.005)

		self.menuList:add(item)
	end

	self:add(self.menuList)
	self:add(self.versionText)

	self.throttles = {}
	self.throttles.up = Throttle:make({controls.down, controls, "ui_up"})
	self.throttles.down = Throttle:make({controls.down, controls, "ui_down"})

	if love.system.getDevice() == "Mobile" then
		self.buttons = util.createButtons("udab")
		self.buttons:add(VirtualPad("tab", game.width - 126, (game.height - 126) / 2, 126, 126))
		self:add(self.buttons)
	end

	self.menuList.changeCallback = function(curSelected, item)
		for _, spr in ipairs(self.menuList.members) do
			spr.animation:play('idle')
			spr:updateHitbox()
		end

		item.animation:play('selected')
		local y = 120 * curSelected
		self.camFollow.x, self.camFollow.y = 0, y
		item:fixOffsets()
	end
	self.menuList:changeSelection()
	self.menuList:updatePositions(0, 0)

	if Discord then
		Discord.changePresence({details = "In the Menus", state = "Main Menu"})
	end

	MainMenuState.super.enter(self)

	self.script:call("postCreate")
end

function MainMenuState:update(dt)
	self.script:call("update", dt)

	if self.notCreated then
		MainMenuState.super.update(self, dt)
		self.script:call("postUpdate", dt)
		return
	end

	if not self.menuList.lock then
		if controls:pressed("back") then
			self.menuList.lock = true
			game.sound.play(paths.getSound('cancelMenu'))
			game.switchState(TitleState())
		end

		if controls:pressed("pick_mods") then
			self.menuList.lock = true
			game.switchState(ModsState())
		end
	end

	MainMenuState.super.update(self, dt)
	self.script:call("postUpdate", dt)
end

local triggerChoices = {
	storymode = {true, function(self)
		game.switchState(StoryMenuState())
	end},
	freeplay = {true, function(self)
		game.switchState(FreeplayState())
	end},
	credits = {true, function(self)
		game.switchState(CreditsState())
	end},
	options = {false, function(self)
		if self.buttons then self:remove(self.buttons) end
		if self.optionsUI then self.optionsUI:destroy() end
		self.optionsUI = OptionsSubstate(true, function()
			self.menuList.lock = false

			if Discord then
				Discord.changePresence({details = "In the Menus", state = "Main Menu"})
			end
			if self.buttons then self:add(self.buttons) end
		end)
		self.optionsUI.applySettings = bind(self, self.onSettingChange)
		self:openSubstate(self.optionsUI)
		return false
	end},
	donate = {false, function(self)
		love.system.openURL('https://ninja-muffin24.itch.io/funkin')
		self.menuList.lock = false
		return true
	end}
}

function MainMenuState:onSettingChange(setting, option)
	if setting == "gameplay" and option == "menuMusicVolume" then
		game.sound.music:fade(1, game.sound.music.volume, ClientPrefs.data.menuMusicVolume / 100)
	end
end

function MainMenuState:enterSelection(choice)
	local switch = triggerChoices[choice]
	local flash = ClientPrefs.data.flashingLights

	util.playSfx(paths.getSound('confirmMenu'))
	local flicker = Flicker(self.menuBg, switch[1] and 1.1 or 1, 0.15, true)
	if not flash then self.menuBg:loadTexture(self.menuMagenta) end
	local magenta = false
	flicker.onFlicker = function()
		if not self.menuBg.exists or not flash then return end
		magenta = not magenta
		self.menuBg:loadTexture(magenta and self.menuMagenta or self.menuYellow)
	end
	flicker.completionCallback = function()
		if not self.menuBg.exists then return end
		self.menuBg:loadTexture(self.menuYellow)
	end

	local selectedItem = self.menuList.members[self.menuList.curSelected]
	local time = flash and 0.05 or 0.2
	Flicker(selectedItem, 1, time, not switch[1], false, function()
		self.selectedSomethin = not switch[2](self)
	end)
	for _, spr in ipairs(self.menuList.members) do
		if switch[1] and self.menuList.curSelected ~= spr.ID then
			Tween.tween(spr, {alpha = 0}, 0.4, {
				ease = "quadOut",
				onComplete = function()
					spr:destroy()
				end
			})
		end
	end
end

function MainMenuState:leave()
	self.script:call("leave")
	if self.notCreated then
		self.script:call("postLeave")
		self.script:close()
		return
	end

	for _, v in ipairs(self.throttles) do v:destroy() end

	self.script:call("postLeave")
	self.script:close()
end

return MainMenuState
