local decodeJson = (loxreq "lib.json").decode
local parseXml = loxreq "lib.xml"

local FrameCollection = loxreq "animation.frame.collection"
local AnimateLibrary = loxreq "animateatlas.library"

local paths = {
	async = require "funkin.backend.paths.async",

	images = {},
	audio = {},
	atlases = {},
	fonts = {},
	skins = {},
	animate_atlases = {},
	persistantAssets = {"music/freakyMenu.ogg"}
}

local function readFile(key)
	if paths.exists(key, "file") then return love.filesystem.read(key) end
	return nil
end

local function excludeAssets(path)
	local i, n = path:find("assets/")
	if i == 1 then
		return path:sub(n + 1)
	elseif path:find(Mods.root .. "/") == 1 then
		i = path:find("/", 6)
		if i then return path:sub(i + 1) end
	elseif path:find(Addons.root .. "/") == 1 then
		i = path:find("/", 8)
		if i then return path:sub(i + 1) end
	end
	return path
end

local function insertFile(path, file, type, tbl)
	local info = love.filesystem.getInfo(path)
	if info and (type == "any" or info.type == type:lower()) then
		table.insert(tbl, file)
	end
end

function paths.addPersistant(path)
	path = excludeAssets(path)
	if not table.find(paths.persistantAssets, path) then
		table.insert(paths.persistantAssets, path)
	end
end

function paths.isPersistant(path)
	path = excludeAssets(path)
	for _, k in pairs(paths.persistantAssets) do
		if path:startsWith(k) then return true end
	end
	return false
end

local function clear(tbl)
	for k, o in pairs(tbl) do
		if not paths.isPersistant(k) then
			if o.release then o:release() end
			if o.destroy then o:destroy() end
			tbl[k] = nil
		end
	end
end

function paths.clearCache()
	clear(paths.atlases)
	clear(paths.animate_atlases)
	clear(paths.images)
	clear(paths.audio)
	clear(paths.fonts)
	clear(paths.skins)
	collectgarbage()
end

function paths.getMods(key)
	local root = Mods.root .. "/"
	if Mods.currentMod then
		return root .. Mods.currentMod .. "/" .. key
	end
	return "_"
end

function paths.getPath(key, allowMods, allowAddons)
	if allowMods == nil then allowMods = true end
	if allowAddons == nil then allowAddons = true end

	if allowAddons then
		for _, addon in ipairs(Addons.all) do
			if addon.active then
				local addonPath = Addons.root .. "/" .. addon.path .. "/" .. key
				if paths.exists(addonPath) then return addonPath end
			end
		end
	end
	if allowMods then
		local modPath = paths.getMods(key)
		if paths.exists(modPath) then return modPath end
	end
	return "assets/" .. key
end

function paths.getItems(key, type, extension, excludeMods, excludeAddons, excludeAssets)
	type = type or "any"
	local files, getItems = {}, love.filesystem.getDirectoryItems

	if not excludeAddons then
		for _, addon in ipairs(Addons.all) do
			local addonPath = Addons.root .. "/" .. addon.path .. "/" .. key .. "/"
			if addon.active and paths.exists(addonPath, "directory") then
				for _, v in ipairs(getItems(addonPath)) do
					if not table.find(files, v) and (not extension or v:ext() == extension) then
						insertFile(addonPath .. v, v, type, files)
					end
				end
			end
		end
	end

	local mods, base = paths.getMods(key) .. "/", paths.getPath(key, false, false) .. "/"
	if paths.exists(mods, "directory") or paths.exists(base, "directory") then
		if not excludeMods and paths.exists(mods, "directory") then
			for _, v in ipairs(getItems(mods)) do
				if not table.find(files, v) and (not extension or v:ext() == extension) then
					insertFile(mods .. v, v, type, files)
				end
			end
		end
		if not excludeAssets then
			for _, v in ipairs(getItems(base)) do
				if not table.find(files, v) and (not extension or v:ext() == extension) then
					insertFile(base .. v, v, type, files)
				end
			end
		end
	end

	return files
end

function paths.exists(path, type)
	local info = love.filesystem.getInfo(path)
	return info ~= nil and (not type or info.type == type:lower())
end

function paths.getText(key)
	local path = paths.getPath("data/" .. key .. ".txt")
	return readFile(path), path
end

function paths.getJSON(key)
	local path = paths.getPath(key .. ".json")
	local data = readFile(path)
	if data then
		local s, r = pcall(decodeJson, data)
		if not s then
			local err = r:gsub("^.-:%d+: ERROR: ", "")
			error(path .. ": " .. err)
			return
		end
		return r, path
	end
	return nil, path
end

function paths.getXML(key)
	local path = paths.getPath(key .. ".xml")
	local data = readFile(path)
	if data then
		return parseXml(data)
	end
	return nil
end

function paths.getSkin(key)
	local obj = paths.skins[key]
	if obj then return obj else
		obj = Skin(key)
		return obj
	end

	print('oh no its returning "skin" null NOOOO: ' .. key)
	return nil
end

function paths.getFont(key, size)
	if size == nil then size = 12 end

	local path = paths.getPath("fonts/" .. key)
	local obj = paths.fonts[path .. "_" .. size]
	if obj then return obj end
	if paths.exists(path, "file") then
		obj = love.graphics.newFont(path, size, "light")
		paths.fonts[path .. "_" .. size] = obj
		return obj
	end

	print('oh no its returning "font" null NOOOO: ' .. path)
	return nil
end

function paths.getImage(key)
	local path = paths.getPath("images/" .. key .. ".png")
	local obj = paths.images[path]
	if obj then return obj end
	if paths.exists(path, "file") then
		obj = love.graphics.newImage(path)
		paths.images[path] = obj
		return obj
	end

	print('oh no its returning "image" null NOOOO: ' .. key)
	return nil
end

function paths.getAnimateAtlas(key)
	local path = paths.getPath("images/" .. key)
	local obj = paths.animate_atlases[path]
	if obj then return obj end
	if paths.exists(path, "directory") then
		obj = AnimateLibrary(path)
		paths.animate_atlases[path] = obj
		return obj
	end

	print('oh no its returning "animate atlas" null NOOOO: ' .. key)
	return nil
end

function paths.update(dt)
	paths.async.update(dt)
end

function paths.getAudio(key, stream, logError)
	local path = paths.getPath(key .. ".ogg")
	local obj = paths.audio[path]
	if obj then return obj end
	if paths.exists(path, "file") then
		obj = stream and love.audio.newSource(path, "stream") or
			love.sound.newSoundData(path)
		paths.audio[path] = obj
		return obj
	end

	if not logError then print('oh no its returning "audio" null NOOOO: ' .. key) end
	return nil
end

function paths.getMusic(key) return paths.getAudio("music/" .. key, true) end

function paths.getSound(key) return paths.getAudio("sounds/" .. key, false) end

function paths.getInst(song, suffix, logError)
	return paths.getAudio("songs/"
		.. paths.formatToSongPath(song)
		.. "/Inst" .. (suffix and "-" .. suffix or ""), true, logError)
end

function paths.getVoices(song, suffix, logError)
	return paths.getAudio("songs/"
		.. paths.formatToSongPath(song)
		.. "/Voices" .. (suffix and "-" .. suffix or ""), true, logError)
end

function paths.getSparrowAtlas(key)
	local imgPath, xmlPath = key, paths.getPath("images/" .. key .. ".xml")
	local obj = paths.atlases[paths.getPath("images/" .. key)]
	if obj then return obj end
	img = paths.getImage(imgPath)
	if img and paths.exists(xmlPath, "file") then
		obj = FrameCollection.fromSparrow(img, readFile(xmlPath))
		paths.atlases[paths.getPath("images/" .. key)] = obj
		return obj
	end
	return nil
end

function paths.getPackerAtlas(key)
	local imgPath, txtPath = key, paths.getPath("images/" .. key .. ".txt")
	local obj = paths.atlases[paths.getPath("images/" .. key)]
	if obj then return obj end
	local img = paths.getImage(imgPath)
	if img and paths.exists(txtPath, "file") then
		obj = FrameCollection.fromPacker(img, readFile(txtPath))
		paths.atlases[paths.getPath("images/" .. key)] = obj
		return obj
	end
	return nil
end

function paths.getAtlas(key)
	if paths.exists(paths.getPath("images/" .. key .. ".xml"), "file") then return paths.getSparrowAtlas(key) end
	return paths.getPackerAtlas(key)
end

function paths.getLua(key)
	local path = paths.getPath(key .. ".lua")
	if paths.exists(path, "file") then
		return love.filesystem.load(path)
	end
	return nil
end

local invalidChars = '[~&\\;:<>#]'
local hideChars = '[.,\'"%?!]'
function paths.formatToSongPath(path)
	return string.lower(string.gsub(string.gsub(path:gsub(" ", "-"),
			invalidChars, "-"), hideChars,
		""))
end

return paths
