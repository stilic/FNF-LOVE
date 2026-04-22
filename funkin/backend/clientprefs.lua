local ClientPrefs = {}

local desktop = game.system.device == "Desktop"
ClientPrefs.data = {
	-- controls
	asyncInput = false,

	-- gameplay
	autoPause = true,
	downScroll = false,
	middleScroll = false,
	ghostTap = true,
	noteSplash = true,
	backgroundDim = 0,
	flashingLights = true,
	botplayMode = false,
	playback = 1,
	gameOverInfos = true,

	-- gameplay - notes
	splitReceptors = not desktop,
	splitWidth = desktop and 448 or 900,
	noteWidth = desktop and 112 or 190,

	-- audio
	pauseMusic = "railways",
	hitSound = 0,
	songOffset = 0,
	menuMusicVolume = 80,
	musicVolume = 100,
	vocalVolume = 100,
	sfxVolume = 80,

	-- display
	fps = 60,
	antialiasing = true,
	lowQuality = false,
	shader = true,
	fullscreen = false,
	resolution = 1,
	vsync = true,
	margin = desktop and 0 or 76,

	-- stats
	showFps = false,
	showRender = false,
	showMemory = false,
	showDraws = false,

	-- toast messages
	showToastErrors = true,
	showToastDeprecations = true,
	showToastPrints = false,
}

ClientPrefs.controls = {
	note_left = {"key:a", "key:left"},
	note_down = {"key:s", "key:down"},
	note_up = {"key:w", "key:up"},
	note_right = {"key:d", "key:right"},

	ui_left = {"key:a", "key:left"},
	ui_down = {"key:s", "key:down"},
	ui_up = {"key:w", "key:up"},
	ui_right = {"key:d", "key:right"},

	volume_down = {"key:-", "key:f7"},
	volume_up = {"key:+", "key:f8"},
	volume_mute = {"key:0", "key:f6"},

	reset = {"key:r"},
	accept = {"key:space", "key:return"},
	back = {"key:backspace", "key:escape"},
	pause = {"key:return", "key:escape"},

	fullscreen = {"key:f11"},
	pick_mods = {"key:tab"},

	debug_1 = {"key:7"},
	debug_2 = {"key:6"},
}

function ClientPrefs.saveData()
	ClientPrefs.data.fullscreen = love.window.getFullscreen()

	ClientPrefs.save.data.prefs = ClientPrefs.data
	ClientPrefs.save.data.controls = ClientPrefs.controls

	ClientPrefs.save:save()
end

-- load save on start
ClientPrefs.save = game.save("preferences")
ClientPrefs.save:load()
pcall(table.merge, ClientPrefs.data, ClientPrefs.save.data.prefs)
pcall(table.merge, ClientPrefs.controls, ClientPrefs.save.data.controls)

return ClientPrefs
