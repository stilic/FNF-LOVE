local ModdingUtil = {}

local decodeJSON = (loxreq "lib.json").decode

local function createMeta(name)
	return {
		name = name or "Unknown",
		color = "#1F1F1F",
		description = "No description provided.",
		version = 1
	}
end

local function getImage(path)
	obj = paths.images[path]
	if obj then return obj end

	if paths.exists(path, "file") then
		obj = love.graphics.newImage(path, {fullQuality = true})
		paths.images[path] = obj
		return obj
	end
end

function ModdingUtil.getBanner(root, name)
	local obj = getImage(root .. "/" .. name .. "/banner.png")
	if obj then return obj end
	return paths.getImage("menus/modding/banner")
end

function ModdingUtil.getIcon(root, name)
	local obj = getImage(root .. "/" .. name .. "/icon.png", true)
	if obj then return obj end
	return paths.getImage("menus/modding/icon", true)
end

function ModdingUtil.getMeta(root, name)
	local path = root .. "/" .. name .. "/meta.json"
	local onErr = function(r)
		r = r:gsub("^.-:%d+: ERROR: ", "")
		Logger.log("error", name .. "'s JSON metadata returned an error: " .. r)
	end

	if paths.exists(root, "directory") and paths.exists(path, "file") then
		local s, r = xpcall(decodeJSON, onErr, love.filesystem.read(path))
		if not s then
			return createMeta(name)
		end
		return r
	end
	return createMeta(name)
end

return ModdingUtil
