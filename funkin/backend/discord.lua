local DiscordActivity = require "lib.discord"

---@class Discord
local Discord = {}

Discord.isInitialized = false
Discord.clientID = "1098761843956273304"

local _options = {
	details = "Starting",
	state = nil,

	assets = {
		large_image = "icon",
		large_text = "FNF LÖVE"
	}
}

function Discord.init()
	DiscordActivity.start(Discord.clientID, true, function()
		DiscordActivity.setActivity(_options)
	end)

	Logger.log("debug", "Discord Activity started")
	Discord.isInitialized = true
end

function Discord.shutdown() DiscordActivity.shutdown() end

function Discord.changePresence(options)
	if not Discord.isInitialized then return end
	_options = options or {}
	_options.assets = options.assets or {}
	_options.assets.large_image = options.assets.large_image or "icon"
	_options.assets.large_text = options.assets.large_text or "FNF LÖVE"

	DiscordActivity.setActivity(_options)
end

function Discord.update() DiscordActivity.update() end

return Discord
