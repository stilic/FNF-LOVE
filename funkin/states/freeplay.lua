local FreeplayState = State:extend("FreeplayState")
FreeplayState.curDifficulty = 2

function FreeplayState:enter()
	Parser.clearCache()
	self.notCreated = false

	self.script = Script("data/states/freeplay", false)
	local event = self.script:call("create")
	if event == Script.Event_Cancel then
		FreeplayState.super.enter(self)
		self.notCreated = true
		self.script:call("postCreate")
		return
	end

	-- Update Presence
	if Discord then
		Discord.changePresence({details = "In the Menus", state = "Freeplay Menu"})
	end

	self.lerpScore = 0
	self.intendedScore = 0

	self.persistentUpdate = true
	self.persistentDraw = true

	self.bg = Sprite(0, 0, paths.getImage('menus/menuDesat'))
	self:add(util.responsiveBG(self.bg))

	self.songs = MenuList(paths.getSound('scrollMenu'), true)
	self.songs.changeCallback = function() self:changeDiff(0) end
	self.songs.selectCallback = bind(self, self.openSong)
	self:loadSongs()
	self:add(self.songs)

	if #self.songs.members == 0 then
		self.noSongTxt = AtlasText(0, 0, 'No songs here', "bold")
		self.noSongTxt:screenCenter()
		self:add(self.noSongTxt)
	end

	self.scoreText = Text(game.width * 0.7, 5, "", paths.getFont("vcr.ttf", 32),
		Color.WHITE, "right")
	self.scoreText.antialiasing = false

	self.scoreBG = Graphic(self.scoreText.x - 6, 0, 1, 66, Color.BLACK)
	self.scoreBG.alpha = 0.6
	self:add(self.scoreBG)

	self.diffText = Text(self.scoreText.x, self.scoreText.y + 36, "DIFFICULTY",
		paths.getFont("vcr.ttf", 24))
	self.diffText.antialiasing = false
	self:add(self.diffText)
	self:add(self.scoreText)

	if love.system.getDevice() == "Mobile" then
		self.buttons = util.createButtons(self.noSongTxt and "b" or "lrudab")
		self:add(self.buttons)
	end

	self.throttles = {}
	self.throttles.left = Throttle:make({controls.down, controls, "ui_left"})
	self.throttles.right = Throttle:make({controls.down, controls, "ui_right"})

	if #self.songs.members > 0 then
		self.songs.curSelected = math.min(#self.songs.members, self.songs.curSelected)
		self:changeDiff(0)
		self.songs:changeSelection()
		self.bg.color = self.songs:getSelected().bgColor
	end

	FreeplayState.super.enter(self)

	self.script:call("postCreate")
end

function FreeplayState:openSong(song)
	PlayState.storyMode = false
	PlayState.META = song.meta
	local diff = song.diffs[FreeplayState.curDifficulty]

	if game.keys.pressed.SHIFT then
		PlayState.loadSong(song.songName, diff)
		PlayState.storyDifficulty = diff
		game.switchState(ChartingState())
	else
		game.switchState(LoadState(PlayState(nil, song.songName, diff)))
	end
end

function FreeplayState:update(dt)
	self.script:call("update", dt)
	if self.notCreated then
		FreeplayState.super.update(self, dt)
		self.script:call("postUpdate", dt)
		return
	end

	self.lerpScore = util.coolLerp(self.lerpScore, self.intendedScore, 24, dt)
	if math.abs(self.lerpScore - self.intendedScore) <= 10 then
		self.lerpScore = self.intendedScore
	end
	self.scoreText.content = "PERSONAL BEST: " .. util.formatNumber(math.floor(self.lerpScore))

	self:positionHighscore()

	if not self.songs.lock then
		if #self.songs.members > 0 and self.throttles then
			if self.throttles.left:check() then self:changeDiff(-1) end
			if self.throttles.right:check() then self:changeDiff(1) end
		end
		if controls:pressed("back") then
			self.songs.lock = true
			util.playSfx(paths.getSound('cancelMenu'))
			game.switchState(MainMenuState())
		end
	end

	if #self.songs.members > 0 then
		local colorBG = self.songs:getSelected().bgColor
		self.bg.color = Color.lerpDelta(self.bg.color, colorBG, 3, dt)
	end
	FreeplayState.super.update(self, dt)

	self.script:call("postUpdate", dt)
end

function FreeplayState:closeSubstate()
	FreeplayState.super.closeSubstate(self)
end

function FreeplayState:changeDiff(change)
	local songDiffs = self.songs:getSelected().diffs
	if change == nil then change = 0 end

	FreeplayState.curDifficulty = FreeplayState.curDifficulty + change
	FreeplayState.curDifficulty = (FreeplayState.curDifficulty - 1) % #songDiffs + 1

	self.intendedScore = Highscore.getScore(self.songs:getSelected().songName,
		songDiffs[FreeplayState.curDifficulty])

	self.diffText.content = songDiffs[FreeplayState.curDifficulty]:upper()
	if #songDiffs > 1 then
		self.diffText.content = "< " .. self.diffText.content .. " >"
	end

	self:positionHighscore()
end

function FreeplayState:positionHighscore()
	self.scoreText.x = game.width - self.scoreText:getWidth() - 6
	self.scoreBG.width = self.scoreText:getWidth() + 12
	self.scoreBG.x = self.scoreText.x - 6
	self.diffText.x = math.floor(self.scoreBG.x + (self.scoreBG.width - self.diffText:getWidth()) / 2)
end

function FreeplayState:loadSongs()
	local listData, func = nil, Mods.currentMod and paths.getMods or function(...)
		return paths.getPath(..., false)
	end
	local data, dont = {}

	if paths.exists(func('data/freeplayList.txt'), 'file') then
		listData = paths.getText('freeplayList')
	elseif paths.exists(func('data/freeplaySonglist.txt'), 'file') then
		listData = paths.getText('freeplaySonglist')
	else
		if paths.exists(func('data/weekList.txt'), 'file') then
			listData = paths.getText('weekList'):gsub('\r', ''):split('\n')
			for _, week in pairs(listData) do
				local weekData = paths.getJSON('data/weeks/weeks/' .. week)
				if not weekData.hide_fm then
					for _, song in ipairs(weekData.songs) do
						table.insert(data, Parser.getMeta(song))
					end
				end
			end
		else
			for _, name in pairs(paths.getItems('data/weeks/weeks', 'file', 'json',
				not Mods.currentMod, true, Mods.currentMod)) do
				local weekData = paths.getJSON('data/weeks/weeks/' .. name:withoutExt())
				if weekData and not weekData.hide_fm then
					for _, song in ipairs(weekData.songs) do
						table.insert(data, Parser.getMeta(song))
					end
				end
			end
		end
		dont = true
	end

	if not dont and listData then
		listData = listData:gsub('\r', ''):split('\n')
		for _, song in ipairs(listData) do
			table.insert(data, Parser.getMeta(song))
		end
	end

	if #data > 0 then
		for i = 1, #data do
			local songText = AtlasText(0, 0,
				data[i].displayName, "bold")

			songText.diffs = data[i].difficulties
			songText.songName = data[i].song
			songText.bgColor = data[i].color

			local icon = HealthIcon(data[i].icon)
			icon:updateHitbox()

			if songText:getWidth() > 980 then
				local textScale = 980 / songText:getWidth()
				songText.origin.x = 0
				songText.scale.x = textScale
			end
			songText.meta = data[i]

			self.songs:add(songText, icon)
		end
	end
end

function FreeplayState:leave()
	self.script:call("leave")
	if self.notCreated then
		self.script:call("postLeave")
		return
	end

	for _, v in ipairs(self.throttles) do v:destroy() end
	self.throttles = nil

	self.script:call("postLeave")
	self.script:close()
end

return FreeplayState
