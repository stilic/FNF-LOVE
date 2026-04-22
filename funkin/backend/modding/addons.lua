-- mods the sequel
local ModdingUtil = require "funkin.backend.modding.util"
local lfs = love.filesystem

local Addons = {all = {}, root = "addons"}

if love.system.getDevice() == "Desktop" and lfs.isFused() and
	lfs.mount(lfs.getSourceBaseDirectory(), "root") then
	Addons.root = "root/" .. Addons.root
end

function Addons.getBanner(addon) return ModdingUtil.getBanner(Addons.root, addon.path) end
function Addons.getIcon(addon) return ModdingUtil.getIcon(Addons.root, addon.path) end
function Addons.getMetadata(addon) return ModdingUtil.getMeta(Addons.root, addon.path) end

function Addons.sortAddons()
	local order = ClientPrefs.save.data.addons.order
	table.sort(Addons.all, function(a, b)
		return (table.find(order, a.path) or math.huge) < (table.find(order, b.path) or math.huge)
	end)
end

function Addons.move(addon, n)
	local name = addon.path

	local order = ClientPrefs.save.data.addons.order
	local idx, new = table.find(order, name), nil

	if idx then
		new = ((idx - 1 + n) % #order) + 1
		table.shift(order, idx, new)
		Addons.sortAddons()
	end
end

function Addons.setState(addon, enabled)
	addon.active = enabled
	ClientPrefs.save.data.addons.active[addon.path] = addon.active
end

function Addons.reload()
	table.clear(Addons.all)
	if not paths.exists(Addons.root, "directory") then return end

	if not ClientPrefs.save.data.addons then
		ClientPrefs.save.data.addons = {
			order = {},
			active = {}
		}
	end

	local existent = {}

	for _, dir in ipairs(lfs.getDirectoryItems(Addons.root)) do
		if lfs.getInfo(Addons.root .. "/" .. dir, "directory") then
			local addon = {
				path = dir,
				active = ClientPrefs.save.data.addons.active[dir] or false
			}
			if not table.find(ClientPrefs.save.data.addons.order, dir) then
				table.insert(ClientPrefs.save.data.addons.order, dir)
			end
			table.insert(Addons.all, addon)
			existent[dir] = true
		end
	end

	if ClientPrefs.save.data.addons.order then
		for i = #ClientPrefs.save.data.addons.order, 1, -1 do
			if not existent[ClientPrefs.save.data.addons.order[i]] then
				table.remove(ClientPrefs.save.data.addons.order, i)
			end
		end
	end

	if ClientPrefs.save.data.addons.active then
		for name in pairs(ClientPrefs.save.data.addons.active) do
			if not existent[name] then
				ClientPrefs.save.data.addons.active[name] = nil
			end
		end
	end

	Addons.sortAddons()
end

return Addons
