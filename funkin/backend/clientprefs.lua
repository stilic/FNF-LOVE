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

ClientPrefs.mods = {}
function ClientPrefs.__setMod()
	ClientPrefs.mods[Mods.currentMod] = ClientPrefs.mods[Mods.currentMod] or {}
	ClientPrefs.mod = setmetatable({}, {
		__index = function(_, k)
			return ClientPrefs.save.data.mods[Mods.currentMod][k]
		end,
		__newindex = function(_, k, v)
			ClientPrefs.save.data.mods[Mods.currentMod][k] = v
		end
	})

	local json = loxreq "lib.json".decode(love.filesystem.read(paths.getMods("data/options.json")))
	for _, options in pairs(json) do
		for _, option in pairs(options) do
			if ClientPrefs.mods[Mods.currentMod][option.data] == nil then
				ClientPrefs.mods[Mods.currentMod][option.data] = option.defaultValue
			end
		end
	end
end

function ClientPrefs.saveData()
	ClientPrefs.data.fullscreen = love.window.getFullscreen()

	ClientPrefs.save.data.prefs = ClientPrefs.data
	ClientPrefs.save.data.controls = ClientPrefs.controls

	if Mods.currentMod and paths.exists(paths.getMods("data/options.json")) then
		ClientPrefs.__setMod()
	end
	ClientPrefs.save.data.mods = ClientPrefs.mods

	ClientPrefs.save:save()
end

-- load save on start
ClientPrefs.save = game.save("preferences")
ClientPrefs.save:load()
pcall(table.merge, ClientPrefs.data, ClientPrefs.save.data.prefs)
pcall(table.merge, ClientPrefs.controls, ClientPrefs.save.data.controls)
pcall(table.merge, ClientPrefs.mods, ClientPrefs.save.data.mods)

return ClientPrefs
