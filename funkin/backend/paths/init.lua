local decodeJson = (loxreq "lib.json").decode
local parseXml = loxreq "lib.xml"

local FrameCollection = loxreq "animation.frame.collection"
local AnimateLibrary = require "funkin.backend.animatelibrary"

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

local ktx = {"ETC1", "ETC2rgb", "ETC2rgba", "ETC2rgba1", "EACr", "EACrs", "EACrg", "EACrgs"}
local dds = {"DXT1", "DXT3", "DXT5", "BC4", "BC4s", "BC5", "BC5s", "BC6h", "BC6hs", "BC7"}
local astc = {"ASTC4x4", "ASTC5x4", "ASTC5x5", "ASTC6x5", "ASTC6x6", "ASTC8x5", "ASTC8x6", "ASTC8x8",
			  "ASTC10x5", "ASTC10x6", "ASTC10x8", "ASTC10x10", "ASTC12x10", "ASTC12x12"}

local function initCompressedSupport()
	local supported = love.graphics.getImageFormats()
	local hasKTX, hasDDS, hasASTC

	for _, format in ipairs(ktx) do
		if supported[format] then hasKTX = true; break end
	end
	for _, format in ipairs(dds) do
		if supported[format] then hasDDS = true; break end
	end
	for _, format in ipairs(astc) do
		if supported[format] then hasASTC = true; break end
	end

	paths.compressedSupport = {ktx = hasKTX, dds = hasDDS, astc = hasASTC}
end

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

paths.excludeAssets = excludeAssets

local function insertFile(path, file, type, tbl)
	local info = love.filesystem.getInfo(path)
	if info and (type == "any" or info.type == type:lower()) then
		table.insert(tbl, file)
	end
end

local function getFromCache(cache, key)
	local obj = cache[key]
	if obj then return obj end
end

local function generate(cache, key, createFunc, error, path)
	local obj = getFromCache(cache, key)
	local exists = paths.exists(key, path and "directory" or "file")
	if obj then return obj end

	obj = createFunc(exists)
	if obj then cache[key] = obj; return obj end
	if error then Logger.log("debug", "[ PATHS ] " .. error .. ' returned a null value: ' .. key, 4) end
	return nil
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

	if allowMods then
		local modPath = paths.getMods(key)
		if paths.exists(modPath) then return modPath end
	end
	if allowAddons then
		for _, addon in ipairs(Addons.all) do
			if addon.active then
				local addonPath = Addons.root .. "/" .. addon.path .. "/" .. key
				if paths.exists(addonPath) then return addonPath end
			end
		end
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
	return generate(paths.skins, key, function() return Skin(key) end, "skin")
end

function paths.getFont(key, size, logError)
	local path = paths.getPath("fonts/" .. key)
	local pkey = path .. "_" .. size
	return generate(paths.fonts, pkey, function()
		if paths.exists(path, "file") then
			return love.graphics.newFont(path, size or 12, "light")
		end
	end, "font")
end

function paths.getImage(key)
	if not paths.compressedSupport then initCompressedSupport() end
	local basePath = "images/" .. key .. "."
	local path

	if paths.compressedSupport.astc then
		path = paths.getPath(basePath .. "astc")
		if paths.exists(path, "file") then
			return generate(paths.images, path, function()
				return love.graphics.newImage(path)
			end, "image")
		end
	end

	if paths.compressedSupport.ktx then
		path = paths.getPath(basePath .. "ktx")
		if paths.exists(path, "file") then
			return generate(paths.images, path, function()
				return love.graphics.newImage(path)
			end, "image")
		end
	end

	if paths.compressedSupport.dds then
		path = paths.getPath(path .. "dds")
		if paths.exists(path, "file") then
			return generate(paths.images, path, function()
				return love.graphics.newImage(path)
			end, "image")
		end
	end

	path = paths.getPath(basePath .. "png")
	return generate(paths.images, path, function()
		if paths.exists(path, "file") then
			return love.graphics.newImage(path)
		end
	end, "image")
end

function paths.getAnimateAtlas(key)
	local path = paths.getPath("images/" .. key)
	return generate(paths.animate_atlases, path, function(y)
		if y then
			local lib = AnimateLibrary(path)
			lib:load()
			return lib
		end
	end, "animate atlas", true)
end

function paths.getAudio(key, stream, logError)
	local path = paths.getPath(key .. ".ogg")
	return generate(paths.audio, path, function(y)
		if y then return stream and love.audio.newSource(path, "stream") or
			love.sound.newSoundData(path) end
	end, not logError and "audio" or nil)
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
	local atlasPath = paths.getPath("images/" .. key)

	return generate(paths.atlases, atlasPath, function()
		local img = paths.getImage(imgPath)
		if img and paths.exists(xmlPath, "file") then
			return FrameCollection.fromSparrow(img, readFile(xmlPath))
		end
		return nil
	end)
end

function paths.getPackerAtlas(key)
	local imgPath, txtPath = key, paths.getPath("images/" .. key .. ".txt")
	local atlasPath = paths.getPath("images/" .. key)

	return generate(paths.atlases, atlasPath, function()
		local img = paths.getImage(imgPath)
		if img and paths.exists(txtPath, "file") then
			return FrameCollection.fromPacker(img, readFile(txtPath))
		end
		return nil
	end)
end

function paths.getAtlas(key)
	if paths.exists(paths.getPath("images/" .. key .. ".xml"), "file") then
		return paths.getSparrowAtlas(key)
	end
	return paths.getPackerAtlas(key)
end

function paths.getLua(key)
	local path = paths.getPath(key .. ".lua")
	if paths.exists(path, "file") then return love.filesystem.load(path) end
end

local invalidChars = '[~&\\;:<>#]'
local hideChars = '[.,\'"%?!]'
function paths.formatToSongPath(path)
	return string.lower(string.gsub(string.gsub(path:gsub(" ", "-"),
			invalidChars, "-"), hideChars,
		""))
end

function paths.update(dt) paths.async.update(dt) end

return paths
