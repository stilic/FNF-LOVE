local PauseSubstate = Substate:extend("PauseSubstate")

function PauseSubstate:new()
	PauseSubstate.super.new(self)

	self.menuItems = {"Resume", "Restart song", "Practice mode", "Options", "Exit to menu"}
	if #PlayState.SONG.difficulties > 1 then
		table.insert(self.menuItems, 3, "Change difficulty")
	end

	self.blockInput = false
	self.lock = false
	self.timer = 0

	self:loadMusic()

	self.bg = Graphic(0, 0, game.width, game.height, Color.BLACK)
	self.bg.alpha = 0
	self.bg.scrollFactor:set()
	self:add(self.bg)

	local reset = function()
		util.device.wakelock(true)
		love.FPScap = ClientPrefs.data.fps
		self.timer = 0
	end

	self.menuList = MenuList(paths.getSound('scrollMenu'), false,
		love.system.getDevice() == "Mobile" and "mobile" or nil)
	self.menuList.selectCallback = bind(self, self.selectOption)
	self.menuList.changeCallback = reset
	self:add(self.menuList)

	self.diffList = MenuList(paths.getSound('scrollMenu'), false,
		love.system.getDevice() == "Mobile" and "mobile" or nil)
	self.diffList.selectCallback = bind(self, self.selectDifficulty)
	self.diffList.changeCallback = reset
	self.diffList.lock, self.diffList.open = true, false

	for i = 1, #self.menuItems do
		local item = AtlasText(0, 0, self.menuItems[i], "bold")
		self.menuList:add(item)
	end
	for i = 1, #PlayState.SONG.difficulties do
		if PlayState.SONG.difficulties[i]:lower() ~= PlayState.songDifficulty:lower() then
			local item = AtlasText(0, 0, PlayState.SONG.difficulties[i], "bold")
			self.diffList:add(item)
		end
	end

	self.diffItem = nil
	self.diffItemIdx = nil
	for i, member in ipairs(self.menuList.members) do
		if tostring(member):lower() == "change difficulty" then
			self.diffItem = member
			self.diffItemIdx = i
			break
		end
	end

	self.menuList:changeSelection()

	local txt, font = PlayState.SONG.metadata.displayName or "?", paths.getFont("vcr.ttf", 32)
	self.songText = Marquee(0, 15, 400, 36, txt, font, nil, "right")
	self.songText.alignmen = "right"
	self.songText.pauseTime = 2.4
	self.songText.x = game.width - self.songText.limit - 28
	self.songText.alpha = 0
	self:add(self.songText)

	txt = "Difficulty: " .. (PlayState.songDifficulty or "?")
	self.diffText = Text(0, 47, txt, font)
	self.diffText.x = game.width - self.diffText:getWidth() - 28
	self.diffText.alpha = 0
	self:add(self.diffText)

	txt = GameOverSubstate.deaths .. " Blue Balls"
	self.deathsText = Text(0, 79, txt, font)
	self.deathsText.x = game.width - self.deathsText:getWidth() - 28
	self.deathsText.alpha = 0
	self:add(self.deathsText)

	txt = "Practice Mode"
	self.practiceText = Text(0, 111, txt, font)
	self.practiceText.x = game.width - self.practiceText:getWidth() - 28
	self.practiceText.alpha = 0
	self:add(self.practiceText)
	self.practiceText.visible = PlayState.practiceMode
end

function PauseSubstate:loadMusic()
	self.curPauseMusic = self:loadPauseMusic()
	self.music = game.sound.load(paths.getMusic('pause/' .. self.curPauseMusic))
end

function PauseSubstate:enter()
	self.music:play(0, true)
	self.music:fade(6, 0, ClientPrefs.data.menuMusicVolume / 100)

	Tween.tween(self.bg, {alpha = 0.6}, 0.4, {ease = 'quartInOut'})
	Tween.tween(self.songText, {y = self.songText.y + 5, alpha = 1},
		0.4, {ease = 'quartInOut'})
	Tween.tween(self.diffText, {y = self.diffText.y + 5, alpha = 1},
		0.4, {ease = 'quartInOut', startDelay = 0.2})
	Tween.tween(self.deathsText, {y = self.deathsText.y + 5, alpha = 1},
		0.4, {ease = 'quartInOut', startDelay = 0.4})
	Tween.tween(self.practiceText, {y = self.practiceText.y + 5, alpha = 1},
		0.4, {ease = 'quartInOut', startDelay = 0.6})

	if love.system.getDevice() == "Mobile" then
		self.buttons = util.createButtons("b")
		self:add(self.buttons)

		self.parent:remove(self.parent.pauseButton)
		self:add(self.parent.pauseButton)
		Tween.cancelTweensOf(self.parent.pauseButton)
		Tween.tween(self.parent.pauseButton, {alpha = 0}, 0.6, {ease = Ease.quartOut, startDelay = 0.5});
	end

	util.device.wakelock(false)
end

function PauseSubstate:resetState()
	util.device.wakelock(true)
	self.lock = true
	love.FPScap = ClientPrefs.data.fps

	self.load = LoadScreen(getmetatable(game.getState())())
	self:add(self.load)
end

function PauseSubstate:selectDifficulty(daChoice)
	util.device.wakelock(true)
	love.FPScap = ClientPrefs.data.fps
	PlayState.loadSong(PlayState.songObject, PlayState.SONG.difficulties[
		table.find(PlayState.SONG.difficulties, tostring(daChoice))])
	self:resetState()
end

function PauseSubstate:selectOption(daChoice)
	love.FPScap = ClientPrefs.data.fps
	self.timer = 0

	if self.lock or self.blockInput then return end

	switch(tostring(daChoice):lower(), {
		["resume"] = function() self:close() end,
		["restart song"] = function()
			util.device.wakelock(true)
			self:resetState()
		end,
		["practice mode"] = function()
			self.menuList.lock = false
			self.blockInput = false
			daChoice.offset.x = -30

			Tween.cancelTweensOf(daChoice.offset)
			Tween.tween(daChoice.offset, {x = 0}, 0.6, {ease = Ease.circOut})

			PlayState.practiceMode = not PlayState.practiceMode
			self.practiceText.visible = true

			local p = PlayState.practiceMode
			Tween.cancelTweensOf(self.practiceText)
			self.practiceText.alpha = p and 0 or 1
			self.practiceText.y = p and 111 or self.practiceText.y
			Tween.tween(self.practiceText, {y = self.practiceText.y + (p and 5 or -5), alpha = (p and 1 or 0)},
				0.4, {ease = 'quartInOut'})
			util.playSfx(paths.getSound("scrollMenu"))
		end,
		["change difficulty"] = function()
			self:openDifficultyMenu()
		end,
		["options"] = function()
			if self.buttons then self:remove(self.buttons) end
			self.timer = -1
			if self.optionsUI then self.optionsUI:destroy() end
			self.optionsUI = OptionsSubstate(false, function()
				if self.buttons then self:add(self.buttons) end

				self.menuList.alpha = 1
				self.menuList.lock = false
				self.blockInput = false
				self.timer = 0
			end)
			self.optionsUI.cameras = self.cameras
			self.optionsUI.applySettings = bind(self, self.onSettingChange)
			self:openSubstate(self.optionsUI)

			self.menuList.alpha = 0.25
			self.menuList.lock = true
			self.blockInput = true
		end,
		["exit to menu"] = function()
			game.sound.music.pitch = 1

			self.timer = -1
			util.device.wakelock(true)
			love.FPScap = ClientPrefs.data.fps

			self.music:stop()
			util.playMenuMusic()
			local state = FreeplayState
			if PlayState.storyMode then
				PlayState.seenCutscene = false
				state = StoryMenuState
			end
			local stickers = StickerSubstate()
			self:openSubstate(stickers)
			stickers:start(state())

			GameOverSubstate.deaths = 0
			PlayState.fadeReceptors = true
			PlayState.chartingMode = false
			PlayState.startPos = 0
		end,
		default = function() Logger.log("error", "Missing option: " .. tostring(daChoice)) end
	})
end

function PauseSubstate:update(dt)
	if self.load then
		if paths.async.getProgress() == 1 then
			local state = self.load.nextState
			state.skipTransIn = true
			self.parent.skipTransOut = true
			game.switchState(state)
		end
	end
	PauseSubstate.super.update(self, dt)

	if self.diffList.open and controls:pressed("back") then
		self:closeDifficultyMenu()
	end

	if self.timer > -1 then self.timer = self.timer + dt end
	if self.timer >= 2 then
		love.FPScap = 12
		self.timer = -1
	end
end

function PauseSubstate:openDifficultyMenu()
	if self.diffList.open or self.lock then return end
	util.playSfx(paths.getSound("scrollMenu"))

	self:add(self.diffList)

	if self.diffItem then
		self.diffItem._savedX = self.diffItem.x
		self.diffItem._savedY = self.diffItem.y
		table.remove(self.menuList.members, self.diffItemIdx)
		for i, m in ipairs(self.menuList.members) do m.ID = i end
		self.diffItem.alpha = 1
		self:add(self.diffItem)
	end

	Tween.cancelTweensOf(self.diffList)
	Tween.cancelTweensOf(self.menuList)

	for i = 1, #self.diffList.members do
		self.diffList.members[i].target = 0
	end
	self.diffList:updatePositions(game.dt, 0)
	self.diffList:changeSelection(nil, true)

	self.menuList.lock = true
	self.blockInput = true
	Timer():start(0.1, function() self.diffList.lock = false end)

	self.diffList.x = -300
	Tween.tween(self.diffList, {x = 120}, 0.4, {ease = "circOut", onComplete = function()
		self.diffList.open = true
	end})
	Tween.tween(self.menuList, {alpha = 0}, 0.4, {ease = "circOut"})

	if self.diffItem then
		Tween.cancelTweensOf(self.diffItem)
		Tween.tween(self.diffItem, {x = 18, y = 18}, 0.6, {ease = "expoOut"})
	end
end

function PauseSubstate:closeDifficultyMenu()
	if self.diffList.closing or self.lock then return end
	util.playSfx(paths.getSound("cancelMenu"))

	self.diffList.closing = true
	Tween.tween(self.diffList, {x = -300}, 0.21, {ease = "circIn", onComplete = function()
		self:remove(self.diffList)
		self.diffList.closing = false
		self.diffList.open = false
	end})
	Tween.tween(self.menuList, {alpha = 1}, 0.21, {ease = "circIn", onComplete = function()
		Tween.cancelTweensOf(self.menuList)
	end})

	if self.diffItem then
		Tween.cancelTweensOf(self.diffItem)
		Tween.tween(self.diffItem, {x = self.diffItem._savedX + 6, y = self.diffItem._savedY + 6}, 0.2,
			{ease = "smoothStepOut", onComplete = function()
				self:remove(self.diffItem)
				table.insert(self.menuList.members, self.diffItemIdx, self.diffItem)
				for i, m in ipairs(self.menuList.members) do m.ID = i end
				self.menuList:changeSelection(nil, true)
			end})
	end

	self.menuList.lock = false
	self.diffList.lock = true
	self.blockInput = false
end

function PauseSubstate:onSettingChange(setting, option)
	if self.parent and self.parent.onSettingChange then
		self.parent:onSettingChange(setting, option)
	end

	if setting == "gameplay" then
		if option == "pauseMusic" then
			if self.activeTimer then
				Timer.cancel(self.activeTimer)
				self.activeTimer = nil
			end

			self.activeTimer = Timer.start(1, function()
				if not self.parent or ClientPrefs.data.pauseMusic == self.curPauseMusic then return end
				self.music:fade(0.7, self.music:getVolume(), 0)
				Timer.start(0.8, function()
					if ClientPrefs.data.pauseMusic == self.curPauseMusic then return end
					self.music:stop()
					self.music:cancelFade()
					if not self.parent then return end
					self:loadMusic()
					self.music:play(ClientPrefs.data.menuMusicVolume / 100, true)
				end)
			end)
		elseif option == "menuMusicVolume" then
			self.music:fade(1, self.music:getVolume(), ClientPrefs.data.menuMusicVolume / 100)
		end
	end
end

function PauseSubstate:loadPauseMusic()
	local pauseMusic = ClientPrefs.data.pauseMusic
	if pauseMusic == "breakfast" then
		local songName = PlayState.SONG.song:lower()
		if songName == "pico" or songName == "philly nice" or songName == "blammed" then
			pauseMusic = pauseMusic .. "-pico"
		elseif songName == "senpai" or songName == "roses" or songName == "thorns" then
			pauseMusic = pauseMusic .. "-pixel"
		end
	end
	return pauseMusic
end

function PauseSubstate:close()
	if self.parent.pauseButton then
		self:remove(self.parent.pauseButton)
		self.parent:add(self.parent.pauseButton)
		Tween.cancelTweensOf(self.parent.pauseButton)
		Tween.tween(self.parent.pauseButton, {alpha = 1}, 0.25, {ease = Ease.quartOut});
		Tween.tween(self.parent.pauseCircle, {alpha = 0.1}, 0.25, {ease = Ease.quartOut});
	end

	util.device.wakelock(true)
	love.FPScap = ClientPrefs.data.fps

	self.music:stop()
	self.music:destroy()

	if self.buttons then self.buttons:destroy() end

	PauseSubstate.super.close(self)
end

return PauseSubstate
