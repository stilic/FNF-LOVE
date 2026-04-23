local funkin = {}

if love.system.getOS() == "Windows" then
	WindowDialogue = require "lib.windows.dialogue"
	WindowUtil = require "lib.windows.util"

	local _ogSetMode = love.window.setMode
	function love.window.setMode(...)
		_ogSetMode(...)
		WindowUtil.setDarkMode(true)
	end
end

Https = require "lib.https"

paths = require "funkin.backend.paths"
util = require "funkin.util"

ClientPrefs = require "funkin.backend.clientprefs"
Throttle = require "funkin.backend.throttle"
Parser = require "funkin.backend.parser"

Conductor = require "funkin.backend.gameplay.conductor"
Highscore = require "funkin.backend.gameplay.highscore"

Script = require "funkin.backend.scripts"
ScriptsHandler = require "funkin.backend.scripts.handler"
-- GlobalScripts = require "funkin.backend.modding.scripts.global"
require "funkin.backend.scripts.events"

Mods = require "funkin.backend.modding.mods"
Addons = require "funkin.backend.modding.addons"

Discord = require "funkin.backend.discord"

Skin = require "funkin.backend.gameplay.skin"
Receptor = require "funkin.gameplay.receptor"
Note = require "funkin.gameplay.note"
Notefield = require "funkin.gameplay.notefield"

FFT = require "funkin.backend.fft"
Countdown = require "funkin.gameplay.ui.countdown"
HealthIcon = require "funkin.gameplay.ui.healthicon"
HealthBar = require "funkin.gameplay.ui.healthbar"
ProgressArc = require "funkin.gameplay.ui.progressarc"
Judgements = require "funkin.gameplay.ui.judgements"

NoteMods = require "funkin.gameplay.notemods"
Character = require "funkin.gameplay.character"
Stage = require "funkin.gameplay.stage"
DialogueBox = require "funkin.gameplay.ui.dialoguebox"

AtlasText = require "funkin.ui.atlastext"
SpriteButton = require "funkin.ui.spritebutton"
Marquee = require "funkin.ui.marquee"
MenuList = require "funkin.ui.menulist"
LoadScreen = require "funkin.ui.loadscreen"

StatsCounter = require "funkin.ui.statscounter"

LoadState = require 'funkin.states.load'
CreditsState = require "funkin.states.credits"
TitleState = require "funkin.states.title"
MainMenuState = require "funkin.states.mainmenu"
ModsState = require "funkin.states.mods"
StoryMenuState = require "funkin.states.storymenu"
FreeplayState = require "funkin.states.freeplay"
PlayState = require "funkin.states.play"

PauseSubstate = require "funkin.substates.pause"
GameOverSubstate = require "funkin.substates.gameover"
StickerSubstate = require "funkin.substates.stickers"
OptionsSubstate = require "funkin.substates.options"

EditorMenu = require "funkin.ui.editor.editormenu"
CutsceneState = require "funkin.states.editors.cutscene"
CharacterEditor = require "funkin.states.editors.character"
ChartingState = require "funkin.states.editors.charting"
ChartingNote = require "funkin.ui.editor.charting.chartingnote"

Shader = require "funkin.shaders"
RGBShader = require "funkin.shaders.rgb"
Video = require "funkin.backend.video"
local res, isMobile
local TransitionFade = loxreq "transition.transitionfade"

function funkin.load()
	local prefs = ClientPrefs.data

	res, isMobile = math.abs(prefs.resolution), love.system.getDevice() == "Mobile"
	Camera.defaultResolution = res

	funkin.setEnvironment()

	if ClientPrefs.save.data.prefs then
		love.FPScap = ClientPrefs.data.fps or 60
		love.vsync = ClientPrefs.data.vsync
		love.autoPause = ClientPrefs.data.autoPause
	else
		love.FPScap = math.max(select(3, love.window.getMode()).refreshrate, love.FPScap)
		ClientPrefs.data.fps = love.FPScap
		ClientPrefs.data.vsync = love.vsync
		ClientPrefs.data.resolution = 1
	end

	Object.defaultAntialiasing = ClientPrefs.data.antialiasing

	Toast.showErrors = ClientPrefs.data.showToastErrors
	Toast.showDeprecations = ClientPrefs.data.showToastDeprecations

	local config = {controls = table.clone(ClientPrefs.controls)}
	if controls == nil then
		controls = (require "lib.baton").new(config)
	else
		controls:reset(config)
	end

	if Project.bgColor then
		love.graphics.setBackgroundColor(Project.bgColor)
	end

	paths.initCompressedSupport()

	Mods.reload()
	Addons.reload()
	Highscore.load()

	local color = Color.BLACK
	State.defaultTransIn = TransitionFade(0.6, color, "vertical")
	State.defaultTransOut = TransitionFade(0.7, color, "vertical")

	game.onPreStateEnter = function(state)
		-- GlobalScripts.call("preStateEnter", state)
		if paths and game.getState() and not game.getState().persistCache and
			getmetatable(state) ~= getmetatable(game.getState()) then
			paths.clearCache()
			Shader.clear()
		end
	end

	local dimen = love.graphics.getDimensions()
	local SoundTray = require "funkin.ui.soundtray".init(dimen).new()
	game:add(SoundTray)

	game.init(Project, TitleState)

	if ClientPrefs.data.resolution == -1 then
		Camera.defaultResolution = love.graphics.getFixedScale()
		ClientPrefs.data.resolution = Camera.defaultResolution
		for _, camera in pairs(game.cameras.list) do
			if camera then camera:resize(camera.width, camera.height) end
		end
	end
	love.window.setVSync(love.vsync and 1 or 0)

	game.statsCounter = StatsCounter(18, 18,
		love.graphics.newFont('assets/fonts/consolas.ttf', 14),
		love.graphics.newFont('assets/fonts/consolas.ttf', 18))
	game.statsCounter.showFps = ClientPrefs.data.showFps
	game.statsCounter.showRender = ClientPrefs.data.showRender
	game.statsCounter.showMemory = ClientPrefs.data.showMemory
	game.statsCounter.showDraws = ClientPrefs.data.showDraws
	game:add(game.statsCounter)

	AtlasText.defaultFont = AtlasText.getFont("default-white", 1)

	if Discord then Discord.init() end

	Script.addToEnv("controls", controls)
	Script.addToEnv("print", print)
	-- GlobalScripts.reload()
end

function funkin.update(dt)
	paths.update(dt)

	controls:update()
	Throttle:update(dt)
	Shader.updateTime(dt)

	if Discord then Discord.update() end
	if controls:pressed("fullscreen") then
		love.window.setFullscreen(not love.window.getFullscreen())
	end

	-- GlobalScripts.call("update", dt)
end

function funkin.fullscreen(f)
	ClientPrefs.data.fullscreen = f
end

function funkin.quit()
	ClientPrefs.saveData()
	paths.async.crashstop()
	if Discord then Discord.shutdown() end
	FFT.close()
end

local function error_printer(msg, layer)
	ogprint((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1)):gsub("\n[^\n]+$", "")))
end

function funkin.heartbeat()
	if Discord then Discord.heartbeat() end
end

local function rmerge(a, b)
	if a and b then
		for i, v in pairs(b) do
			if type(v) == "table" and type(a[i]) == "table" then rmerge(a[i], v) else a[i] = v end
		end
	end
end

local appdata = {
	appName = Project.title,
	appIcon = Project.icon,
	window = {
		width = Project.width,
		height = Project.height,
		dynamicWidth = Project.adaptableWidth,
		color = {0, 0, 0, 1}
	},
	discord = {
		id = "1098761843956273304",
		assets = {
			large_image = "icon",
			large_text = "FNF LÖVE"
		}
	}
}

function funkin.setEnvironment(settings)
	local res = math.abs(ClientPrefs.data.resolution)
	local data = table.clone(appdata)
	if settings then rmerge(data, settings) end

	love.window.setTitle(data.appName)
	love.window.setIcon(love.image.newImageData(data.appIcon))

	game.width, game.height = data.window.width, data.window.height
	love.window.updateMode(data.window.width * res, data.window.height * res, {
		fullscreen = isMobile or ClientPrefs.data.fullscreen,
		resizable = not isMobile,
		usedpiscale = false
	})
	if Project.adaptableWidth then
		local w, h = love.graphics.getDimensions()
		local screenRatio = w / h
		local gameRatio = game.width / game.height

		if screenRatio > gameRatio then
			game.width = math.floor(game.height * screenRatio)
			for _, camera in pairs(game.cameras.list) do
				camera:resize(game.width, game.height)
			end
		end
	end
	Transition.width = game.width

	love.graphics.setBackgroundColor(data.window.color[1], data.window.color[2], data.window.color[3])

	if Discord then
		Discord.clientID = data.discord.id
		Discord.options.assets = data.discord.assets
		Discord.restart()
	end
end
util.setEnvironment = funkin.setEnvironment

function funkin.throwError(msg)
	paths.async.crashstop()
	if Discord then Discord.shutdown() end
	FFT.close()
	pcall(love.errorhandler_quit)

	msg = tostring(msg)
	error_printer(msg, 2)

	if not love.window or not love.graphics or not love.event then return end

	if not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600, {fullscreen = false})
		if not success or not status then return end
	end

	local trace = debug.traceback()

	if utf8 == nil then utf8 = require("utf8") end

	local sanitizedmsg, err = {}, {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)

	table.insert(err, sanitizedmsg)
	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

	for l in trace:gmatch("(.-)\n") do
		l = l:gsub("stack traceback:", "Traceback\n")
		table.insert(err, l)
	end

	local p = table.concat(err, "\n"):gsub("\t", ""):gsub("%[string \"(.-)\"%]", "%1")
	local fullErrorText = p

	love.graphics.reset()
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1)
	love.graphics.origin()

	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
		if love.mouse.isCursorSupported() then love.mouse.setCursor() end
	end
	if love.joystick then
		for i, v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.window then
		love.window.setFullscreen(false)
		love.window.setDisplaySleepEnabled(true)
	end
	if love.audio then love.audio.stop() end
	if love.handlers then love.handlers = nil end

	collectgarbage("collect")
	collectgarbage()
	collectgarbage()

	local interactTxt = ""
	if love.system then
		interactTxt = interactTxt .. "\n\nPress Ctrl+C or tap to copy this error"
	end
	interactTxt = interactTxt .. "\nPress ESC to quit"
	interactTxt = interactTxt .. "\nPress Ctrl+R to restart"

	local menuDesat, funkinLogo, fnfFont18, fnfFont20
	local bgMusic, missSfx

	function firstPass()
		menuDesat = paths.getImage("menus/menuDesat")
		funkinLogo = paths.getImage("menus/splashscreen/FNFLOVE_logo")
		fnfFont18 = paths.getFont("phantommuff.ttf", 18) or love.graphics.setNewFont(18)
		fnfFont20 = paths.getFont("phantommuff.ttf", 35) or love.graphics.setNewFont(35)

		bgMusic = paths.getMusic("pause/railways", "static")
		missSfx = love.audio.newSource(paths.getSound("gameplay/missnote" .. love.math.random(1, 3)), "static")

		bgMusic:setLooping(true)
		bgMusic:setVolume(0.7)
		bgMusic:play()

		missSfx:setVolume(0.4)
		missSfx:play()
	end

	local dontDraw = false
	local __error__, __align__, focused = "[ ERROR ]", "left"
	local scale1, scale2, gameW, gameH, hgameW, hgameH, retval
	local menuDesatW, menuDesatH, funkinLogoW, funkinLogoH
	local function draw(force)
		if not force and dontDraw then return end

		love.graphics.clear(0, 0, 0)

		hgameW, hgameH = gameW / 2, gameH / 2
		menuDesatW, menuDesatH = menuDesat:getWidth(), menuDesat:getHeight()
		funkinLogoW, funkinLogoH = funkinLogo:getWidth(), funkinLogo:getHeight()

		scale1 = math.max(gameW / menuDesatW, gameH / menuDesatH)
		scale2 = math.max(math.min(gameW, 1600) / funkinLogoW, math.min(gameH, 900) / funkinLogoH) * 0.525

		love.graphics.setColor(0.2, 0.2, 0.2)
		love.graphics.draw(menuDesat, hgameW, hgameH, 0, scale1, scale1, menuDesatW / 2, menuDesatH / 2)
		love.graphics.draw(funkinLogo, (hgameW * 2) - (scale2 * funkinLogoW / 1.8) - 64, hgameH, 0, scale2, scale2, funkinLogoW / 2, funkinLogoH / 2)

		love.graphics.setColor(1, 1, 1)

		love.graphics.setFont(fnfFont20)
		love.graphics.printf(__error__, 40, 40, love.graphics.getWidth() - 80, __align__)

		love.graphics.setFont(fnfFont18)
		love.graphics.printf(p, 40, 110, love.graphics.getWidth() - 80, __align__)

		love.graphics.setFont(fnfFont18)
		love.graphics.printf(interactTxt, 40, love.graphics.getHeight() - 130, love.graphics.getWidth() - 80, __align__)

		love.graphics.present()
	end

	local function copyToClipboard()
		love.system.setClipboardText(fullErrorText)
		p = p .. "\nCopied to clipboard!"
		draw()
	end

	eventhandlers = {
		quit = function()
			return 1
		end,
		keypressed = function(key)
			if key == "escape" then return 1 end
			if not love.keyboard.isDown("lctrl", "rctrl") then return end
			if love.system and key == "c" then
				copyToClipboard()
			elseif key == "r" then
				return "restart"
			end
		end,
		touchpressed = function()
			local name = love.window.getTitle()
			if #name == 0 or name == "Untitled" then name = "Game" end

			local buttons = {"OK", "Cancel", "Restart"}
			if love.system then buttons[4] = "Copy to clipboard" end

			local pressed = love.window.showMessageBox("Quit " .. name .. "?", "", buttons)
			if pressed == 1 then
				return 1
			elseif pressed == 3 then
				return "restart"
			elseif pressed == 4 then
				copyToClipboard()
			end
		end,
		focus = function(f)
			bgMusic:setVolume(f and 0.7 or 0.3)
		end,
		resize = function(w, h)
			gameW, gameH = w, h
			draw()
		end,
		displayrotated = function(force)
			gameW, gameH = love.graphics.getDimensions()
			draw(force)
		end
	}

	local __step__, name, a, b = "step"
	--[[ if love.system.getDevice() == "Mobile" then
		dontDraw = true

		local first, done = true, false
		return function()
			if first then
				first = false
				return
			end

			love.event.pump()
			for name, a in love.event.poll() do
				if eventhandlers[name] ~= nil then
					retval = eventhandlers[name](a)
					if retval then return retval end
				end
			end

			if not done then
				firstPass()
			end
			eventhandlers.displayrotated(true)

			done = true
			collectgarbage(__step__)
			sleep(0.1)
		end
	end]]

	firstPass()
	eventhandlers.displayrotated(true)

	return function()
		name, a, b = love.event.wait()
		if eventhandlers[name] ~= nil then
			collectgarbage(__step__)
			retval = (eventhandlers[name])(a, b)
			if retval then return retval end
		end
	end
end

return funkin
