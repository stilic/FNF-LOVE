---@class PlayState:State
local PlayState = State:extend("PlayState")
local PauseButton = require "funkin.gameplay.ui.pausebutton"
local inputState = {}

PlayState.defaultDifficulty = "normal"
PlayState.transIn = TransitionData(0.5)

PlayState.inputDirections = {
	note_left = 0,
	note_down = 1,
	note_up = 2,
	note_right = 3
}
PlayState.keysControls = {}
for control, key in pairs(PlayState.inputDirections) do
	PlayState.keysControls[key] = control
end

PlayState.songObject = nil
PlayState.SONG = nil
PlayState.songDifficulty = ""

PlayState.storyPlaylist = {}
PlayState.storyMode = false
PlayState.storyWeek = ""
PlayState.storyScore = 0
PlayState.storyWeekFile = ""

PlayState.seenCutscene = false
PlayState.practiceMode = false
PlayState.fadeReceptors = true
PlayState.prevCamFollow = nil

-- Charting Stuff
PlayState.chartingMode = false
PlayState.startPos = 0

PlayState.isPBOTScore = true

local max, min, slope, offset = 500, 9, 0.080, 54.99
local function getPBOTScore(ms)
	local abs = math.abs(ms) * 1000

	if abs > 160 then return -100 end
	if abs < 5 then return max end
	local exponent = -slope * (abs - offset)
	local factor = 1 - (1 / (1 + math.exp(exponent)))
	return math.floor(max * factor + min)
end

function PlayState.getCutscene(isEnd)
	local name = paths.formatToSongPath(PlayState.SONG.song)
	if isEnd then name = name .. "-end" end
	if paths.exists(paths.getPath("data/cutscenes/" .. name .. ".lua"), "file") then
		return name
	end
end

function PlayState.loadSong(song, diff)
	diff = diff or PlayState.defaultDifficulty
	PlayState.songDifficulty = diff

	if type(song) == "string" then
		song = Song(song)
	end
	PlayState.songObject = song
	PlayState.SONG = song:getChart(diff)
end

function PlayState:new(storyMode, song, diff)
	PlayState.super.new(self)

	if storyMode ~= nil then
		PlayState.storyMode = storyMode
		PlayState.storyWeek = ""
	end

	if song ~= nil then
		if storyMode and type(song) == "table" and #song > 0 then
			PlayState.storyPlaylist = song
			song = song[1]
		end
		PlayState.loadSong(song, diff)
	end
end

function PlayState:preload()
	local skin = PlayState.SONG.skin or "default"
	if type(skin) == "string" then
		PlayState.SONG.skin = paths.getSkin(PlayState.SONG.skin or "default")
		skin = PlayState.SONG.skin
	end

	local function skinPath(type, name) return {type, skin:getPath(name, type)} end
	local song = paths.formatToSongPath(PlayState.SONG.song)
	local diff, async = PlayState.songDifficulty:lower(), paths.async

	local function getInst()
		return async.getInst(song, diff) or async.getInst(song, nil)
	end
	local function getVocals(suffix, fallback, skip)
		local vocal = async.getVoices(song, suffix .. "-" .. diff) or
			async.getVoices(song, diff) or async.getVoices(song, suffix) or
			(fallback and async.getVoices(song, fallback) or nil) or
			(not skip and async.getVoices(song, nil) or nil)
		return vocal
	end

	local p1, p2 = PlayState.SONG.player1, PlayState.SONG.player2
	local playerVocals, enemyVocals =
		getVocals(p1 or "Player", "Player"),
		getVocals(p2 or "Opponent", "Opponent", true)
	getInst()

	local list = {
		skinPath("image", "ready"), skinPath("image", "set"), skinPath("image", "go"),
		skinPath("sound", "intro3"), skinPath("sound", "intro2"), skinPath("sound", "intro1"),
		skinPath("sound", "introGo"), {"sound", "hitsound"}
	}

	local path, sprite
	for i, part in ipairs(PlayState.SONG.skin.data) do
		path, sprite = "skins/" .. PlayState.SONG.skin.skin .. "/", part.sprite
		if part.skin then path = "skins/" .. part.skin .. "/" end
		if sprite then
			table.insert(list, {"image", path .. sprite})
		end
	end

	self.ratings = {
		{name = "sick", time = 0.045,  score = 350, splash = true,  mod = 1},
		{name = "good", time = 0.090,  score = 200, splash = false, mod = 0.7},
		{name = "bad",  time = 0.135,  score = 100, splash = false, mod = 0.4, resetCombo = true},
		{name = "shit", time = -1,     score = 50,  splash = false, mod = 0, resetCombo = true}
	}
	for _, r in ipairs(self.ratings) do
		self[r.name .. "s"] = 0
	end

	for i, rating in ipairs(self.ratings) do
		table.insert(list, skinPath("image", rating.name))
	end
	for i = 0, 9 do
		table.insert(list, skinPath("image", "num" .. i))
	end
	table.insert(list, skinPath("image", "numnegative"))
	table.insert(list, skinPath("image", "healthBar"))

	for i = 1, 3 do table.insert(list, {"sound", "gameplay/missnote" .. i}) end

	self.stage = Stage(PlayState.SONG.stage)
	for _, char in ipairs({PlayState.SONG.gfVersion, PlayState.SONG.player1, PlayState.SONG.player2}) do
		if char and char ~= "" then
			local data = Parser.getCharacter(char)
			if data then
				local kind = paths.exists(paths.getPath(data.sprite .. "/Animation.json")) and "animate" or "image"
				if kind == "animate" then return end -- TODO remove this check and fix the async animatelib
				table.insert(list, {kind, data.sprite})

				if data.animations and kind ~= "animate" then
					for _, anim in ipairs(data.animations) do
						if anim[7] then
							table.insert(list, {"image", anim[7]})
						end
					end
				end
				table.insert(list, {"image", "icons/" .. (data.icon or "face")})
			end
		end
	end
	paths.async.loadBatch(list)
end

function PlayState:enter()
	if PlayState.SONG == nil then PlayState.loadSong("test") end

	local songName = paths.formatToSongPath(PlayState.SONG.song)

	if type(PlayState.SONG.skin) == "string" then
		PlayState.SONG.skin = paths.getSkin(PlayState.SONG.skin or "default")
	end
	local skin = PlayState.SONG.skin

	local difficulty = PlayState.songDifficulty:lower()
	if game.sound.music then game.sound.music:reset(true) end
	game.sound.loadMusic(paths.getInst(songName, difficulty, true)
		or paths.getInst(songName, nil, true))
	game.sound.music.looped = false
	game.sound.music.volume = ClientPrefs.data.musicVolume / 100
	game.sound.music.onComplete = bind(self, self.endSong)

	local conductor = Conductor(PlayState.SONG.timeChanges)
	conductor.time = self.startPos - conductor.crotchet * 5
	conductor.onStep:add(bind(self, self.step))
	conductor.onBeat:add(bind(self, self.beat))
	conductor.onMeasure:add(bind(self, self.measure))
	PlayState.conductor = conductor

	self.skipConductor = false

	Note.defaultSustainSegments = 3
	NoteModifier.reset()

	self.timer = TimerManager()
	self.tween = Tween()
	self.camPosTween = nil

	if Discord then self:updateDiscordRPC() end

	self.startingSong = true
	self.startedCountdown = false
	self.doCountdownAtBeats = nil
	self.lastCountdownBeats = nil

	self.isDead = false

	self.usedBotPlay = ClientPrefs.data.botplayMode
	self.downScroll = ClientPrefs.data.downScroll
	self.middleScroll = ClientPrefs.data.middleScroll
	self.playback = 1
	self.timer.timeScale = 1
	self.tween.timeScale = 1

	self.camNotes = Camera()
	self.camHUD = Camera()
	self.camOther = Camera()
	game.cameras.add(self.camHUD, false)
	game.cameras.add(self.camNotes, false)
	game.cameras.add(self.camOther, false)

	self.camHUD.bgColor[4] = ClientPrefs.data.backgroundDim / 100

	self.cameraOffset = Point()
	self.ghostTime = 0

	self.scripts = ScriptsHandler()
	self.scripts:loadDirectory("data/scripts", "data/scripts/" .. songName, "songs/" .. songName)
	conductor.onTimeChange:add(function()
		self.scripts:set("bpm", conductor.bpm)
		self.scripts:set("crotchet", conductor.crotchet)
		self.scripts:set("stepCrotchet", conductor.stepCrotchet)
	end)
	conductor.onTimeChange:dispatch()
	self.scripts:call("create")

	self.stage:load()
	self:add(self.stage)
	if self.stage.script then self.scripts:add(self.stage.script, 1) end
	self:add(self.stage.foreground)

	self.boyfriend, self.dad, self.gf =
		self.stage.boyfriend, self.stage.dad, self.stage.gf

	if self.boyfriend then self.scripts:add(self.boyfriend.script, 2) end
	if self.gf then self.scripts:add(self.gf.script, 2) end
	if self.dad then self.scripts:add(self.dad.script, 2) end

	self.events = table.clone(PlayState.SONG.events)
	self.eventScripts = {}
	self.curEventIndex = 1

	local error, missing = "Events not found: %s", {}
	for _, e in ipairs(self.events) do
		local scriptPath = "data/events/" .. e.e:gsub(" ", "-"):lower()
		if paths.exists(paths.getPath(scriptPath .. ".lua"), "file") then
			if not self.eventScripts[e.e] then
				self.eventScripts[e.e] = Script(scriptPath)
				self.eventScripts[e.e]:call("create")
				self.scripts:add(self.eventScripts[e.e], 3)
			end
		else
			if not table.find(missing, e.e) and not self.stage.suppressedEvents[e.e] then
				table.insert(missing, e.e)
			end
		end
	end
	if error and next(missing) then Logger.log("warn", error:format(table.concat(missing, ", "))) end

	if not self.stage then
		self.stage = Stage(PlayState.SONG.stage)
	end

	self.judgeSprites = Judgements(game.width / 3, 264, PlayState.SONG.skin)
	self:add(self.judgeSprites)

	game.camera.zoom, self.camZoom,
	self.camZoomSpeed, self.camSpeed, self.camTarget =
		self.stage.camZoom, self.stage.camZoom,
		self.stage.camZoomSpeed, self.stage.camSpeed

	self.zoomRate = conductor.timeSignNum
	self.hudZoomIntensity = 0.015 * 2
	self.camZoomIntensity = 1.015
	self.camZoomMult = 1

	if PlayState.prevCamFollow then
		self.camFollow = PlayState.prevCamFollow
		PlayState.prevCamFollow = nil
	else
		self.camFollow = Point()
	end

	local volume = ClientPrefs.data.vocalVolume / 100
	local function getVocals(char, fallback, n)
		local file = (paths.getVoices(songName, char .. "-" .. difficulty, true) or
			paths.getVoices(songName, difficulty, true) or paths.getVoices(songName, char, true)) or
			(fallback and paths.getVoices(songName, fallback, true) or nil) or
			(n and paths.getVoices(songName, nil, false))
		if file then
			local vocal = game.sound.load(file)
			vocal.volume, vocal.looped = volume, false
			return vocal
		end
	end

	local p1, p2 = self.boyfriend and self.boyfriend.voiceSuffix or self.SONG.player1,
		self.dad and self.dad.voiceSuffix or PlayState.SONG.player2
	local playerVocals = getVocals(p1 or "Player", "Player", true)
	local enemyVocals = getVocals(p2 or "Opponent", "Opponent") or playerVocals

	-- {field name, char, vocals, botplay, splash}
	self.notefields = {}
	local y, keys, speed = game.height / 2, 4, PlayState.SONG.speed
	local config = {
		{"player", self.boyfriend, playerVocals, ClientPrefs.data.botplayMode, true},
		{"enemy", self.dad, enemyVocals, true},
	}
	for _, nf in ipairs(config) do
		local name, char, vocal, bot, splash = unpack(nf)
		local notes, notefield = PlayState.SONG.notes[nf[1]], Notefield(0, y, keys, skin, char, vocal, speed)
		notefield.bot, notefield.canSpawnSplash, notefield.cameras = bot, splash, {self.camNotes}
		if notes then notefield:setNoteBuffer(notes) end
		self:add(notefield)
		table.insert(self.notefields, notefield)
		self[name .. "Notefield"] = notefield
	end
	self:positionNotefields()
	table.insert(self.notefields, 3, {character = self.gf})

	local notefield
	for i, event in ipairs(self.events) do
		if event.t > 10 then
			break
		elseif event.e == "FocusCamera" then
			self:executeEvent(event)
			table.remove(self.events, i)
			break
		end
	end

	self.countdown = Countdown()
	self.countdown:screenCenter()
	self:add(self.countdown)

	local isPixel = skin.isPixel
	local event = self.scripts:event("onCountdownCreation",
		Events.CountdownCreation({}, isPixel and {x = 7, y = 7} or {x = 1, y = 1}, not isPixel))
	if not event.cancelled then
		self.countdown.data = #event.data == 0 and {
			{
				sound = skin:getPath("intro3", "sound"),
			},
			{
				sound = skin:getPath("intro2", "sound"),
				image = skin:getPath("ready", "image")
			},
			{
				sound = skin:getPath("intro1", "sound"),
				image = skin:getPath("set", "image")
			},
			{
				sound = skin:getPath("introGo", "sound"),
				image = skin:getPath("go", "image")
			}
		} or event.data
		self.countdown.scale = event.scale
		self.countdown.antialiasing = event.antialiasing
	end

	self.scoreText = Text(0, 0, "", paths.getFont("vcr.ttf", 16), Color.WHITE, "right")
	self.scoreText.outline.width = 1
	self.scoreText.antialiasing = true
	self:add(self.scoreText)

	self.healthBar = HealthBar(self.boyfriend and self.boyfriend.icon or nil,
		self.dad and self.dad.icon or nil, skin)
	self.healthBar:screenCenter("x").y = game.height * (self.downScroll and 0.1 or 0.9)
	self:add(self.healthBar)

	for _, o in ipairs({
		self.judgeSprites, self.countdown, self.healthBar, self.scoreText
	}) do o.cameras = {self.camHUD} end

	self.score = 0
	self.combo = 0
	self.misses = 0
	self.health = 1

	if love.system.getDevice() == "Mobile" then
		local pad = ClientPrefs.data.margin
		local w, h = (game.width - pad * 2) / 4, game.height

		self.buttons = VirtualPadGroup()
		self.pauseButton = PauseButton(game.width - 130 - ClientPrefs.data.margin, 20, skin)
		self:add(self.pauseButton)
		self.buttons.cameras = {self.camOther}
		self.pauseButton.cameras = self.buttons.cameras

		local left = VirtualPad("left", pad, 0, w, h, Color.PURPLE)
		local down = VirtualPad("down", pad + w, 0, w, h, Color.BLUE)
		local up = VirtualPad("up", pad + w * 2, 0, w, h, Color.LIME)
		local right = VirtualPad("right", pad + w * 3, 0, w, h, Color.RED)

		self.buttons:add(left)
		self.buttons:add(down)
		self.buttons:add(up)
		self.buttons:add(right)
		self.buttons:set({
			fill = "line",
			lined = false,
			blend = "add",
			releasedAlpha = 0,
			config = {round = {0, 0}}
		})
	end
	if self.buttons then self.buttons:disable() end

	self.lastTick = love.timer.getTime()

	self.bindedKeyPress = bind(self, self.onKeyPress)
	controls:bindPress(self.bindedKeyPress)

	self.bindedKeyRelease = bind(self, self.onKeyRelease)
	controls:bindRelease(self.bindedKeyRelease)

	for _, nf in ipairs(self.notefields) do
		if nf.is then
			nf.downscroll = self.downScroll
			for _, r in ipairs(nf.receptors) do
				r.alpha = PlayState.fadeReceptors and 0 or r.alpha
			end
		end
	end
	self:positionText()

	if self.buttons then self:add(self.buttons) end

	if PlayState.storyMode and not PlayState.seenCutscene then
		local name = PlayState.getCutscene()
		if name then
			self:executeCutscene(name, function() self:startCountdown() end)
		else
			self:startCountdown()
		end
	else
		self:startCountdown()
	end
	self:recalculateRating()

	PlayState.super.enter(self)
	collectgarbage()

	self.scripts:call("postCreate")

	game.camera:follow(self.camFollow, nil, 2.4 * self.camSpeed)
	game.camera:snapToTarget()

	self.lastSongTime = 0

	self:update(0)
end

function PlayState:executeCutscene(name, onComplete, isEnd)
	PlayState.seenCutscene = true

	local cutsceneScript = Script("data/cutscenes/" .. name)
	cutsceneScript.errorCallback:addOnce(function()
		Logger.log("warn", "Cutscene returned a error, skipping")
		cutsceneScript:close()
	end)
	cutsceneScript.closeCallback:addOnce(function()
		if onComplete then onComplete() end
		onComplete = nil
	end)

	cutsceneScript:call("create")
	if isEnd then cutsceneScript:call("postCreate") end

	self.scripts:add(cutsceneScript)
end

function PlayState:positionNotefields()
	local playerNF, enemyNF = self.playerNotefield, self.enemyNotefield
	if self.middleScroll then
		local splitWidth = ClientPrefs.data.splitReceptors and ClientPrefs.data.splitWidth or nil
		playerNF:setWidth(splitWidth, ClientPrefs.data.noteWidth)
		playerNF:screenCenter("x")

		enemyNF.groupScale:set(0.4, 0.4)
		enemyNF:screenCenter("x").x = enemyNF.x * 3.3
		enemyNF:setPosition(enemyNF.x - 380 * 3.3, game.height * (self.downScroll and 0.088 or 2.246))
		enemyNF:hideNotes(true)
	else
		local x = 44
		enemyNF.groupScale:set(1, 1)
		enemyNF:hideNotes(false)
		enemyNF:setPosition(x, game.height / 2)

		playerNF:setWidth()
		playerNF.x = x + game.width / 2
	end
end

function PlayState:positionText()
	self.scoreText.x, self.scoreText.y = self.healthBar.x + self.healthBar.bg.width - 190, self.healthBar.y + 30
end

function PlayState:getRating(a, b)
	local diff = math.abs(a - b)
	for _, r in ipairs(self.ratings) do
		if diff <= (r.time < 0 and Note.safeZoneOffset or r.time) then return r end
	end
end

function PlayState:startCountdown()
	if self.buttons then self:add(self.buttons) end

	local event = self.scripts:call("startCountdown")
	if event == Script.Event_Cancel then return end

	self:setPlayback(ClientPrefs.data.playback)

	if not PlayState.conductor then return end
	self.doCountdownAtBeats = PlayState.startPos / PlayState.conductor.crotchet - 4
	self.startedCountdown = true
	self.countdown.duration = PlayState.conductor.crotchet / 1000
	self.countdown.playback = 1

	self:fadeInReceptors()
end

function PlayState:fadeInReceptors()
	for _, notefield in ipairs(self.notefields) do
		if notefield.is and PlayState.fadeReceptors then
			notefield:fadeInReceptors(self.tween)
		end
	end
	PlayState.fadeReceptors = false
end

function PlayState:setPlayback(playback)
	playback = playback or self.playback
	game.sound.music.pitch = playback

	local lastVocals
	for _, notefield in ipairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals.pitch = playback
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil

	self.playback = playback
	self.timer.timeScale = playback
	self.tween.timeScale = playback
end

function PlayState:playSong(daTime)
	self:updateDiscordRPC()
	self:setPlayback(self.playback)

	if daTime then game.sound.music.time = math.max(daTime, 0) end
	game.sound.music:play()

	local time, lastVocals = game.sound.music.time
	for _, notefield in ipairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals.time = time
			notefield.vocals:play()
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil
	PlayState.conductor:update(time * 1000)

	self.paused = false
end

function PlayState:pauseSong()
	game.sound.music:pause()
	local lastVocals
	for _, notefield in ipairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals:pause()
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil

	self.paused = true
end

function PlayState:resyncSong()
	local time, rate = game.sound.music.time, math.max(self.playback, 1)
	if math.abs(time - self.conductor.time / 1000) > 0.015 * rate then
		PlayState.conductor:update(time * 1000)
	end
	local maxDelay, vocals, lastVocals = 0.009262 * rate
	for _, notefield in ipairs(self.notefields) do
		vocals = notefield.vocals
		if vocals and lastVocals ~= vocals and vocals:isPlaying()
			and vocals.time > 0.8 and math.abs(time - vocals.time) > maxDelay then
			vocals:pause()
			vocals.time = time
			vocals:play()
			lastVocals = vocals
		end
	end
	lastVocals = nil
end

function PlayState:getCameraPosition(char)
	if not char then return 0, 0 end
	local camX, camY = char:getMidpoint()

	local offsetX = 0
	if game.camera.width < 1280 then
		offsetX = (1280 - game.camera.width) / 4
	end

	if char == self.gf then
		camX, camY = camX - char.cameraPosition.x + self.stage.gfCam.x,
			camY - char.cameraPosition.y + self.stage.gfCam.y
	elseif char.isPlayer then
		camX, camY = camX - char.cameraPosition.x + self.stage.boyfriendCam.x + offsetX,
			camY + char.cameraPosition.y + self.stage.boyfriendCam.y
	else
		camX, camY = camX + char.cameraPosition.x + self.stage.dadCam.x - offsetX,
			camY + char.cameraPosition.y + self.stage.dadCam.y
	end

	return camX, camY
end

function PlayState:cameraMovement(ox, oy, easing, time)
	local ev = Events.get(Events.CameraMove, self.camTarget)
	local event = self.scripts:event("onCameraMove", ev)

	local ex, ey = event and event.offset and event.offset.x or 0,
		event and event.offset and event.offset.y or 0

	local camX, camY = (ox or 0) + ex, (oy or 0) + ey
	if self.camPosTween then
		self.camPosTween:cancel()
	end
	camX, camY = camX - self.cameraOffset.x, camY - self.cameraOffset.y

	if easing then
		if game.camera.followLerp then
			game.camera:follow(self.camFollow, nil)
		end
		self.camPosTween = self.tween:tween(self.camFollow, {x = camX, y = camY}, time, {
			ease = Ease[easing],
			onComplete = function() self.camPosTween = nil end
		})
	else
		if not game.camera.followLerp then
			game.camera:follow(self.camFollow, nil, 2.4 * self.camSpeed)
		end
		self.camPosTween = nil
		self.camFollow:set(camX, camY)
	end
	Events.recycle(Events.CameraMove, ev)
end

function PlayState:step(s)
	if self.skipConductor then return end

	if not self.startingSong then
		self:resyncSong()
	end

	self.scripts:set("curStep", s)
	self.scripts:call("step", s)
	self.scripts:call("postStep", s)
end

function PlayState:beat(b)
	if self.skipConductor then return end

	self.scripts:set("curBeat", b)
	self.scripts:call("beat", b)
	self.stage:beat(b)

	local val, healthBar = 1.2, self.healthBar
	healthBar.iconScale = val
	if healthBar.iconP1 then
		healthBar.iconP1:setScale(val)
	end
	if healthBar.iconP2 then
		healthBar.iconP2:setScale(val)
	end

	if --[[ClientPrefs.data.zoomCamera and]] game.camera.zoom < 1.35 and
		self.zoomRate > 0 and self.conductor.currentBeat % self.zoomRate == 0 then
		self.camZoomMult = self.camZoomIntensity
		self.camHUD.zoom = 1 + self.hudZoomIntensity
	end

	self.scripts:call("postBeat", b)
end

function PlayState:measure(m)
	if self.skipConductor then return end

	self.scripts:set("curMeasure", m)
	self.scripts:call("measure", m)

	self.scripts:call("postMeasure", m)
end

function PlayState:focus(f)
	self.scripts:call("focus", f)
	if Discord and love.autoPause then self:updateDiscordRPC(not f) end
	self.scripts:call("postFocus", f)
end

function PlayState:executeEvent(event)
	if self.eventScripts[event.e] then
		self.eventScripts[event.e]:call("event", event)
	end
	self.scripts:call("onEvent", event)
end

function PlayState:pushEvent(name, params)
	if params == nil then
		Logger.log("error", "pushEvent: argument 2 must be the event parameter(s).")
		return
	end

	local path = "data/events/" .. name:gsub(" ", "-"):lower()
	if not self.eventScripts[name] then
		self.eventScripts[name] = Script(path)
		self.scripts:add(self.eventScripts[name])
	end

	self:executeEvent({e = name, v = params})
end

function PlayState:doCountdown(beat)
	if self.lastCountdownBeats == beat then return end
	self.lastCountdownBeats = beat

	if beat > #self.countdown.data then
		self.doCountdownAtBeats = nil
	else
		self.countdown:doCountdown(beat)
	end
end

function PlayState:resetStroke(notefield, dir, doPress)
	local receptor = notefield.receptors[dir + 1]
	if receptor then
		receptor:play((doPress and not notefield.bot)
			and "pressed" or "static")
	end
end

function PlayState:update(dt)
	if self.load then
		self.load:update(dt)
		if paths.async.getProgress() == 1 then
			local state = self.load.nextState
			state.skipTransIn = true
			self.skipTransOut = true
			game.switchState(state)
		end
		return
	end

	if not self.paused and game.sound.music:isPlaying() and not self.skipResync then
		if dt > 1 / 12 then
			self:playSong(math.max(0, self.lastSongTime - dt))
			self.lastSongTime = game.sound.music.time
			return
		end
		self.lastSongTime = game.sound.music.time
	end

	if self.ghostTime > 0 then self.ghostTime = self.ghostTime - dt end

	self.timer:update(dt)
	self.tween:update(dt)

	dt = dt * self.playback
	self.lastTick = love.timer.getTime()

	if self.startedCountdown then
		local time = PlayState.conductor.time + 1000 * dt
		PlayState.conductor:update(time)
		if self.skipConductor then self.skipConductor = false end

		if self.startingSong and PlayState.conductor.time >= self.startPos then
			self.startingSong = false

			self:playSong(self.startPos)
			PlayState.conductor.time = self.startPos
			self.scripts:call("songStart")
		else
			local noFocus, events, e = true, self.events
			while events[self.curEventIndex] do
				local e = events[self.curEventIndex]
				if e.t <= game.sound.music.time * 1000 then
					self:executeEvent(e)
					self.curEventIndex = self.curEventIndex + 1
					if e.e == "FocusCamera" then noFocus = false end
				else
					break
				end
			end
			while events[1] do
				e = events[1]
				if e.t <= game.sound.music.time * 1000 then
					self:executeEvent(e)
					table.remove(events, 1)
					if e.e == "FocusCamera" then noFocus = false end
				else
					break
				end
			end
			if noFocus and self.camTarget and game.camera.followLerp then
				self:cameraMovement(self:getCameraPosition(self.camTarget))
			end
		end

		if self.startingSong and self.doCountdownAtBeats then
			self:doCountdown(math.floor(
				PlayState.conductor.currentBeatFloat - self.doCountdownAtBeats + 1
			))
		end
	end

	local time = PlayState.conductor.time / 1000
	local missOffset = time - Note.safeZoneOffset / 1.25

	for _, nf in ipairs(self.notefields) do
	if not nf.is then goto continue end

	nf.time, nf.beat = time, PlayState.conductor.currentBeatFloat
	local isPlayer = not nf.bot
	local sustainOffset = 0.25 / nf.speed

	local skipThreshold = 1.5

	if isPlayer then
		for dir = 0, nf.keys - 1 do
			local key = PlayState.keysControls[dir]
			inputState[dir] = controls:down(key) or controls:pressed(key)
		end
	end
	if isPlayer then
		for i = 1, #nf.activeNotes do
			local note = nf.activeNotes[i]
			if note.time >= missOffset then break end

			if not note.wasGoodHit and not note.tooLate and not note.ignoreNote then
				if time - note.time > skipThreshold then
					note.tooLate = true
				else
					self:miss(note)
				end
			end
		end
	end

	for _, note in ipairs(nf:getNotes(time, nil, true)) do
		local hasInput = not isPlayer or inputState[note.direction]
		local char = note.character or nf.character

		if note.wasGoodHit then
			if not note.lastPress then note.lastPress = time end

			if hasInput then
				note.lastPress = time
			end

			if isPlayer and hasInput and not note.wasGoodSustainHit then
				if not note.__lastScoreTime then note.__lastScoreTime = note.time end

				local noteEnd = note.time + note.sustainTime
				local currentCap = math.min(time, noteEnd)

				if currentCap > note.__lastScoreTime then
					local diff = currentCap - note.__lastScoreTime
					if diff > 0 and not PlayState.practiceMode then
						self.score = self.score + math.floor(diff * 300)

						self.ratingNeedsRecalc = true
						note.__lastScoreTime = currentCap
					end
				end
			end

			if not note.wasGoodSustainHit then
				local noteEnd = note.time + note.sustainTime

				if noteEnd - sustainOffset <= note.lastPress then
					local fullHeld = noteEnd <= note.lastPress
					if fullHeld then
						note.wasFullSustainHit = true
					end
					if fullHeld or not hasInput then
						self:goodSustainHit(note, time, fullHeld)
						if hasInput and not isPlayer and char then
							char.lastHit = PlayState.conductor.time
						end
					end
				elseif not hasInput and isPlayer and note.time <= time then
					self:goodSustainHit(note, time)
					note.tooLate = true
				elseif not isPlayer and hasInput and char then
					char.lastHit = PlayState.conductor.time
				end
			end

		elseif isPlayer then
			if not note.wasGoodSustainHit and (note.lastPress or note.time) <= missOffset then
				if time - note.time <= skipThreshold then
					self:miss(note)
				else
					note.tooLate = true
				end
			end
		elseif note.time <= time then
			self:goodNoteHit(note, time)
		end
	end
	::continue::
end

if self.ratingNeedsRecalc then
	self:recalculateRating()
	self.ratingNeedsRecalc = false
end

	self.scripts:call("update", dt)
	PlayState.super.update(self, dt)

	self.camZoomMult = util.coolLerp(self.camZoomMult, 1, 3, dt * self.camZoomSpeed)
	local zoomPlusBop = self.camZoom * self.camZoomMult
	game.camera.zoom = zoomPlusBop

	self.camHUD.zoom = util.coolLerp(self.camHUD.zoom, 1, 3, dt * self.camZoomSpeed)
	self.camNotes.zoom = self.camHUD.zoom

	if self.startedCountdown and controls:pressed("pause") then
		self:tryPause()
	end

	self.healthBar.value = util.coolLerp(self.healthBar.value, self.health, 15, dt)
	if not self.isDead and self.health <= 0 and not PlayState.practiceMode then self:tryGameOver() end

	if self.startedCountdown then
		-- if controls:pressed("debug_1") then
		-- 	game.camera:unfollow()
		-- 	self:pauseSong()
		-- 	game.switchState(ChartingState())
		-- end

		-- if controls:pressed("debug_2") then
		-- 	game.camera:unfollow()
		-- 	game.sound.music:pause()
		-- 	self:pauseSong()
		-- 	CharacterEditor.onPlayState = true
		-- 	game.switchState(CharacterEditor())
		-- end

		if not self.isDead and controls:pressed("reset") then self:tryGameOver() end
	end

	if Project.DEBUG_MODE then
		if game.keys.justPressed.ONE then self.playerNotefield.bot = not self.playerNotefield.bot end
		if game.keys.justPressed.TWO then self:endSong() end
		if game.keys.justPressed.THREE then
			local time = (PlayState.conductor.time +
				PlayState.conductor.crotchet * (game.keys.pressed.SHIFT and 8 or 4)) / 1000
			self.skipConductor, PlayState.conductor.time = true, time * 1000
			self:playSong(time)
		end
	end

	self.scripts:call("postUpdate", dt)
end

function PlayState:draw()
	self.scripts:call("draw")
	PlayState.super.draw(self)
	self.scripts:call("postDraw")
end

function PlayState:onSettingChange(category, setting)
	game.camera.freezed = false
	self.camNotes.freezed = false
	self.camHUD.freezed = false

	if category == "gameplay" then
		switch(setting, {
			["downScroll"] = function()
				local downscroll = ClientPrefs.data.downScroll
				for _, notefield in ipairs(self.notefields) do
					if notefield.is then notefield.downscroll = downscroll end
				end

				self.healthBar.y = game.height * (downscroll and 0.1 or 0.9)
				self:positionText()
				self.downScroll = downscroll
				self:positionNotefields()
			end,
			[{"middleScroll", "splitReceptors", "noteWidth", "splitWidth"}] = function()
				self.middleScroll = ClientPrefs.data.middleScroll
				self:positionNotefields()
			end,
			["botplayMode"] = function()
				self.playerNotefield.bot = ClientPrefs.data.botplayMode
				self:recalculateRating()
				self.usedBotplay = true
			end,
			["backgroundDim"] = function()
				self.camHUD.bgColor[4] = ClientPrefs.data.backgroundDim / 100
			end,
			["playback"] = function()
				self:setPlayback(ClientPrefs.data.playback)
			end
		})

		game.sound.music.volume = ClientPrefs.data.musicVolume / 100
		local volume, vocals = ClientPrefs.data.vocalVolume / 100
		for _, notefield in ipairs(self.notefields) do
			vocals = notefield.vocals
			if vocals then vocals.volume = volume end
		end
	elseif category == "controls" then
		controls:unbindPress(self.bindedKeyPress)
		controls:unbindRelease(self.bindedKeyRelease)

		self.bindedKeyPress = bind(self, self.onKeyPress)
		controls:bindPress(self.bindedKeyPress)

		self.bindedKeyRelease = bind(self, self.onKeyRelease)
		controls:bindRelease(self.bindedKeyRelease)
	end

	self.scripts:call("onSettingChange", category, setting)
end

function PlayState:goodNoteHit(note, time)
	local rating = self:getRating(note.time, time)
	self.scripts:call("goodNoteHit", note, rating)

	local notefield, dir, isSustain =
		note.parent, note.direction, note.sustain
	local ev = Events.get(Events.NoteHit, notefield, note,
			note.character or notefield.character, rating)
	local event = self.scripts:event("onNoteHit", ev)

	if not event.cancelled and not note.wasGoodHit then
		note.wasGoodHit = true

		if event.unmuteVocals then
			local vocals = notefield.vocals
			if vocals then vocals.volume = ClientPrefs.data.vocalVolume / 100 end
		end

		local char = event.character
		if char and not event.cancelledAnim then
			char.waitReleaseAfterSing = not notefield.bot
			local type, lastsus = note.type ~= "alt" and nil or note.type, notefield.lastSustain
			local sustime = lastsus and lastsus.sustainTime or 0
			if (not lastsus or sustime <= 0 or note.sustainTime > sustime or
					(time - lastsus.time) / sustime >= 0.7) then
				if char.anim:has(type) then
					char:playAnim(type, nil, nil, true)
				else
					char:sing(dir, type)
				end
				notefield.lastSustain = note
			end
		end

		if not isSustain then
			notefield:removeNote(note)
		elseif rating.mod < 0.5 then
			note:ghost()
		end

		local receptor = notefield.receptors[dir + 1]
		if receptor then
			if not event.strumGlowCancelled then
				local time = (notefield.bot or note.sustain) and 0.16 or 0.25
				receptor:play("confirm", true)
				receptor.hitSustain = note.sustain
				receptor.holdTime = time
				if ClientPrefs.data.noteSplash and notefield.canSpawnSplash and rating.splash then
					receptor:spawnSplash()
				end
			end
			if isSustain and not event.coverSpawnCancelled then
				receptor:spawnCover(note)
			end
		end

		if self.playerNotefield == notefield then
			self.health = math.clamp(self.health + 0.023, 0, 2)
			if not notefield.bot and not PlayState.practiceMode then
				self.score = self.score + (self.isPBOTScore and getPBOTScore(note.time - time) or rating.score)
			end
			if rating.resetCombo and self.gf then
				local drop = self.gf:getDropAnim(self.combo)
				if drop then self.gf:playAnim(drop, true, nil, true) end
			end

			self.combo = (rating.resetCombo and math.min(self.combo, 0) - 1 or
				math.max(self.combo, 0) + 1)

			if self.gf and self.gf:hasAnim("combo" .. self.combo) then
				self.gf:playAnim("combo" .. self.combo, false, nil, true)
				self.gf.lastHit = notefield.time * 1000
			end

			self:recalculateRating(rating.name)

			local hitSoundVolume = ClientPrefs.data.hitSound
			if hitSoundVolume > 0 then
				game.sound.play(paths.getSound("hitsound"), hitSoundVolume / 100)
			end
		end
	end

	self.scripts:call("postGoodNoteHit", note, rating)
	Events.recycle(Events.NoteHit, ev)
end

function PlayState:goodSustainHit(note, time, fullyHeldSustain)
	self.scripts:call("goodSustainHit", note)

	local notefield, dir, fullScore =
		note.parent, note.direction, fullyHeldSustain ~= nil
	local ev = Events.get(Events.NoteHit, notefield, note,
		note.character or notefield.character)
	local event = self.scripts:event("onSustainHit", ev)

	if not event.cancelled and not note.wasGoodSustainHit then
		note.wasGoodSustainHit = true
		if notefield.lastSustain == note then notefield.lastSustain = nil end

		if not event.cancelledAnim then
			self:resetStroke(notefield, dir, fullyHeldSustain)
		end
		if fullScore then notefield:removeNote(note) end
	end

	self.scripts:call("postGoodSustainHit", note)
	Events.recycle(Events.NoteHit, ev)
end

-- dir can be nil for non-ghost-tap
function PlayState:miss(note, dir)
	local ghostMiss = dir ~= nil
	if not ghostMiss then dir = note.direction end

	local funcParam = ghostMiss and dir or note
	self.scripts:call(ghostMiss and "miss" or "noteMiss", funcParam)

	local notefield = ghostMiss and note or note.parent
	local ev = Events.get(Events.Miss, notefield, dir, ghostMiss and nil or note,
		note.character or notefield.character)
	local event = self.scripts:event(ghostMiss and "onMiss" or "onNoteMiss", ev)
	if not event.cancelled and (ghostMiss or not note.tooLate) then
		if not ghostMiss then
			note.tooLate = true
		end

		if event.muteVocals and notefield.vocals then notefield.vocals.volume = 0 end

		if event.triggerSound then
			util.playSfx(paths.getSound("gameplay/missnote" .. love.math.random(1, 3)),
				love.math.random(1, 2) / 10)
		end

		local char = event.character
		if char and not event.cancelledAnim then
			char:sing(dir, "miss")
		end

		if notefield == self.playerNotefield then
			self.health = math.clamp(self.health - (ghostMiss and 0.04 or 0.0475), 0, 2)
			if not PlayState.practiceMode then
				self.score = self.score - 300
			end
			self.misses = self.misses + 1
			if not ghostMiss then
				if self.gf and not event.cancelledSadGF then
					local drop = self.gf:getDropAnim(self.combo)
					if drop then self.gf:playAnim(drop, true, nil, true) end
				end
				self.combo = math.min(self.combo, 0) - 1
				self:popUpScore()
			end
			self:recalculateRating()
		end
	end
	notefield.lastSustain = nil

	self.scripts:call(ghostMiss and "postMiss" or "postNoteMiss", funcParam)
	Events.recycle(Events.Miss, ev)
end

function PlayState:recalculateRating(rating)
	self.scoreText.content = ClientPrefs.data.botplayMode and "Botplay Enabled" or
		"Score: " .. util.formatNumber(math.floor(self.score))
	if rating then
		local field = rating .. "s"
		self[field] = (self[field] or 0) + 1
		self:popUpScore(rating)
	end
end

function PlayState:popUpScore(rating)
	local ev = Events.get(Events.PopUpScore)
	local event = self.scripts:event('onPopUpScore', ev)
	if not event.cancelled then
		self.judgeSprites.ratingVisible = not event.hideRating
		self.judgeSprites.comboNumVisible = not event.hideScore
		self.judgeSprites:spawn(rating, self.combo)
	end
	Events.recycle(Events.PopUpScore, ev)
end

function PlayState:tryPause()
	local event = self.scripts:call("pause")
	if event ~= Script.Event_Cancel then
		game.camera:unfollow(false)
		game.camera:freeze()
		self.camNotes:freeze()
		self.camHUD:freeze()

		self:pauseSong()
		self:updateDiscordRPC(true)

		if self.buttons then self:remove(self.buttons) end

		local pause = PauseSubstate()
		pause.cameras = {self.camOther}
		self:openSubstate(pause)
	end
end

function PlayState:tryGameOver()
	local event = self.scripts:event("onGameOver", Events.GameOver())
	if not event.cancelled then
		if self.buttons then self:remove(self.buttons) end

		GameOverSubstate.characterName = event.characterName
		GameOverSubstate.deathSoundName = event.deathSoundName
		GameOverSubstate.loopSoundName = event.loopSoundName
		GameOverSubstate.endSoundName = event.endSoundName
		GameOverSubstate.deaths = GameOverSubstate.deaths + 1

		local tween = Tween.tween(self, {playback = 0.001}, 1, {
			ease = Ease.quadOut,
			onUpdate = function() self:setPlayback() end
		})

		self.scripts:call("gameOverCreate")

		if GameOverSubstate.characterName ~= "" then
			local data = Parser.getCharacter(GameOverSubstate.characterName)
			if data and data.sprite then
				paths.async.getImage(data.sprite, function()
					if event.pauseSong then
						self:pauseSong()
					end
					self.paused = event.pauseGame
					tween:cancel()
					self:setPlayback(1)

					self.camHUD.visible, self.camNotes.visible = false, false
					if self.boyfriend then
						self.boyfriend.visible = false
					end
					self:openSubstate(GameOverSubstate(self.stage.boyfriendPos.x,
						self.stage.boyfriendPos.y))
					self.scripts:call("postGameOverCreate")
				end)
			end
		end

		self.isDead = true
	end
end

function PlayState:getKeyFromEvent(controls)
	for _, control in ipairs(controls) do
		local dir = PlayState.inputDirections[control]
		if dir ~= nil then return dir end
	end
	return -1
end

function PlayState:onKeyPress(key, type, scancode, isrepeat, time)
	if self.substate and not self.persistentUpdate then return end
	local controls = controls:getControlsFromSource(type .. ":" .. key)
	local ghostTap = ClientPrefs.data.ghostTap and self.ghostTime <= 0

	if not controls then return end
	key = self:getKeyFromEvent(controls)
	if key < 0 then return end

	local fixedKey, offset = key + 1,
		(time - self.lastTick) * game.sound.music:getActualPitch()
	for _, notefield in ipairs(self.notefields) do
		if notefield.is and not notefield.bot then
			time = notefield.time + offset
			local hitNotes, hasSustain = notefield:getNotes(time, key)
			local l = #hitNotes

			if l == 0 then
				local receptor = notefield.receptors[fixedKey]
				if receptor then
					receptor:play(hasSustain and "confirm" or "pressed")
				end
				if not hasSustain and not ghostTap then
					self:miss(notefield, key)
				end
			else
				-- remove stacked notes (this is dedicated to spam songs)
				local i, firstNote, note = 2, hitNotes[1]
				while i <= l do
					note = hitNotes[i]
					if note and math.abs(note.time - firstNote.time) < 0.01 then
						notefield:removeNote(note)
					else
						break
					end
					i = i + 1
				end
				self:goodNoteHit(firstNote, time)
				self.ghostTime = 0.17
			end
		end
	end
end

function PlayState:onKeyRelease(key, type, scancode, time)
	if self.substate and not self.persistentUpdate then return end
	local controls = controls:getControlsFromSource(type .. ":" .. key)

	if not controls then return end
	key = self:getKeyFromEvent(controls)

	if key < 0 then return end

	local fixedKey = key + 1
	for _, notefield in ipairs(self.notefields) do
		if notefield.is and not notefield.bot then
			self:resetStroke(notefield, key)
		end
	end
end

function PlayState:closeSubstate()
	self.scripts:call("substateClosed")
	PlayState.super.closeSubstate(self)

	game.camera:unfreeze()
	self.camNotes:unfreeze()
	self.camHUD:unfreeze()

	game.camera.target = self.camFollow

	if not self.startingSong then
		self:playSong()
		if Discord then self:updateDiscordRPC() end
	end

	if self.buttons then self:add(self.buttons) end

	self.scripts:call("postSubstateClosed")
end

function PlayState:endSong(skip)
	if PlayState.storyMode and not skip then
		local name = PlayState.getCutscene(true)
		if name then
			self:executeCutscene(name, function() self:endSong(true) end, true)
			return
		end
	end
	PlayState.seenCutscene = false

	local event = self.scripts:call("endSong")
	if event == Script.Event_Cancel then return end

	game.sound.music:reset(true)
	for _, notefield in ipairs(self.notefields) do
		if notefield.vocals then notefield.vocals:stop() end
	end

	game.sound.music.onComplete = nil
	self.skipResync = true

	if not self.usedBotPlay then
		Highscore.saveScore(PlayState.SONG.song, self.score, self.songDifficulty)
	end
	if self.chartingMode then
		game.switchState(ChartingState())
		return
	end

	if PlayState.storyMode then
		PlayState.fadeReceptors = false
		if not self.usedBotPlay then
			PlayState.storyScore = PlayState.storyScore + self.score
		end

		table.remove(PlayState.storyPlaylist, 1)
		if #PlayState.storyPlaylist > 0 then
			game.sound.music:stop()

			if Discord then
				local detailsText = "Freeplay"
				if PlayState.storyMode then detailsText = "Story Mode: " .. PlayState.storyWeek end

				Discord.changePresence({
					details = detailsText,
					state = 'Loading next song..'
				})
			end

			PlayState.loadSong(Song(PlayState.storyPlaylist[1]), PlayState.songDifficulty)
			self.load = LoadScreen(getmetatable(game.getState())())
			self.load.cameras = {self.camOther}
			self:add(self.load)
		else
			GameOverSubstate.deaths = 0
			PlayState.canFadeInReceptors = true
			if not self.usedBotPlay then
				Highscore.saveWeekScore(self.storyWeekFile, self.storyScore, self.songDifficulty)
			end

			local stickers = Stickers(nil, StoryMenuState())
			self:openSubstate(stickers)

			util.playMenuMusic()
		end
	else
		GameOverSubstate.deaths = 0
		PlayState.fadeReceptors = true
		game.camera:unfollow()

		local stickers = StickerSubstate(nil, FreeplayState())
		self:openSubstate(stickers)

		util.playMenuMusic()
	end
	controls:unbindPress(self.bindedKeyPress)
	controls:unbindRelease(self.bindedKeyRelease)

	self.scripts:call("postEndSong")
end

function PlayState:updateDiscordRPC(paused)
	if not Discord or not PlayState.conductor then return end

	local songName = PlayState.SONG.metadata.displayName
	local composer = PlayState.SONG.metadata.composer
	local album = PlayState.SONG.metadata.album

	local detailsText = "Freeplay"
	if PlayState.storyMode then detailsText = "Story Mode: " .. PlayState.storyWeek end

	local diff = PlayState.defaultDifficulty
	if PlayState.songDifficulty ~= "" then
		diff = PlayState.songDifficulty:capitalize()
	end

	if not self._rpcBannerReq then
		self._rpcBannerReq = true
		local path = paths.getPath("images/covers/" .. album .. ".png")
		if paths.exists(path, "file") then
			Discord.uploadImage(path, function(url, err)
				Logger.log('debug', "uploaded " .. path .. ": " .. (err or "all fine"))
				self._rpcBanner = url
				self:updateDiscordRPC(paused)
			end)
		end
	end

	if paused then
		Discord.changePresence({
			details = "Paused: " .. detailsText .. " - " .. diff,
			assets = {large_text = album, large_image = self._rpcBanner},
			state = songName .. " by " .. composer
		})
		return
	end

	if PlayState.conductor.time < 0 then
		Discord.changePresence({
			details = detailsText,
			state = songName .. ' - [' .. diff .. ']',
			assets = {large_text = album, large_image = self._rpcBanner}
		})
	else
		local startTime = (os.time(os.date("*t"))) - game.sound.music.time
		local endTime = (startTime + game.sound.music.duration)

		Discord.changePresence({
			name = songName,

			state = detailsText .. " - " .. diff,
			details = composer,
			assets = {large_text = album, large_image = self._rpcBanner},
			type = 2,
			timestamps = {
				start = math.floor(startTime),
				["end"] = math.floor(endTime)
			}
		})
	end
end

function PlayState:leave()
	self.scripts:call("leave")

	PlayState.prevCamFollow = self.camFollow
	PlayState.conductor:destroy()
	PlayState.conductor = nil

	controls:unbindPress(self.bindedKeyPress)
	controls:unbindRelease(self.bindedKeyRelease)

	self.scripts:call("postLeave")
	self.scripts:close()
end

return PlayState
