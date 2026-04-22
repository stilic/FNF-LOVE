local ModdingUtil = require "funkin.backend.modding.util"
local lfs = love.filesystem

local Mods = {
	all = {},
	root = "mods",
	currentMod = nil
}

if love.system.getDevice() == "Desktop" and lfs.isFused() and
	lfs.mount(lfs.getSourceBaseDirectory(), "root") then
	Mods.root = "root/" .. Mods.root
end

function Mods.getBanner(name) return ModdingUtil.getBanner(Mods.root, name) end
function Mods.getIcon(name) return ModdingUtil.getIcon(Mods.root, name) end
function Mods.getMetadata(name) return ModdingUtil.getMeta(Mods.root, name) end

function Mods.reload()
	table.clear(Mods.all)
	if not paths.exists(Mods.root, "directory") then return end

	for _, dir in ipairs(lfs.getDirectoryItems(Mods.root)) do
		if lfs.getInfo(Mods.root .. "/" .. dir, "directory") then
			table.insert(Mods.all, dir)
		end
	end

	if ClientPrefs.save.data.currentMod then
		if table.find(Mods.all, ClientPrefs.save.data.currentMod) then
			Mods.currentMod = ClientPrefs.save.data.currentMod
		else
			Mods.currentMod = nil
			ClientPrefs.save.data.currentMod = Mods.currentMod
		end
	end
end

return Mods
