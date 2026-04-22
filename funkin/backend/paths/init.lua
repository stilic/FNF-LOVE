local decodeJson = (loxreq "lib.json").decode
local parseXml = loxreq "lib.xml"

local FrameCollection = loxreq "animation.frame.collection"
local AnimateLibrary = require "funkin.backend.animatelibrary"

local asyncModule = require "funkin.backend.paths.async"

local Library = Classic:extend("Library")

function Library:new()
	self.images = {}
	self.audio = {}
	self.atlases = {}
	self.fonts = {}
	self.skins = {}
	self.animate_atlases = {}
	self.songs = {}

	self.persistantAssets = {}

	self.async = setmetatable({}, {
		__index = function(t, k)
			if asyncModule[k] and type(asyncModule[k]) == "function" then
				return function(...)
					asyncModule._setTarget(self)
					return asyncModule[k](...)
				end
			end
			return asyncModule[k]
		end,
		__newindex = function(t, k, v)
			asyncModule[k] = v
		end
	})

	return self
end

function Library:addPersistant(path)
	path = paths.excludeAssets(path)
	if not table.find(self.persistantAssets, path) then
		table.insert(self.persistantAssets, path)
	end
end

function Library:isPersistant(path)
	path = paths.excludeAssets(path)
	for _, k in pairs(self.persistantAssets) do
		if path:startsWith(k) then return true end
	end
	return false
end

local function clearCache(lib, tbl, skipPers)
	for k, o in pairs(tbl) do
		if skipPers or not lib:isPersistant(k) then
			if o.release then o:release() end
			if o.destroy then o:destroy() end
			tbl[k] = nil
		end
	end
end

function Library:clearCache(skipPers)
	clearCache(self, self.atlases)
	clearCache(self, self.animate_atlases)
	clearCache(self, self.images)
	clearCache(self, self.audio)
	clearCache(self, self.fonts)
	clearCache(self, self.skins)
	collectgarbage()
end

function Library:destroy()
	self:clearCache(true)
end

local function getFromCache(cache, key)
	local obj = cache[key]
	if obj then return obj end
end

local function generate(lib, cache, key, createFunc, error, path)
	local obj = getFromCache(cache, key)
	local exists = paths.exists(key, path and "directory" or "file")
	if obj then return obj end

	obj = createFunc(exists)
	if obj then cache[key] = obj; return obj end
	if error then Logger.log("debug", error .. ' returned a null value: ' .. key, 4) end
	return nil
end

function Library:getSkin(key)
	return generate(self, self.skins, key, function() return Skin(key) end, "skin")
end

function Library:getFont(key, size, logError)
	local path = paths.getPath("fonts/" .. key)
	local pkey = path .. "_" .. size
	return generate(self, self.fonts, pkey, function()
		if paths.exists(path, "file") then
			return love.graphics.newFont(path, size or 12, "light")
		end
	end, "font")
end

local fullQualityTbl = {fullQuality = true}
function Library:getImage(key, fullQuality)
	if not paths.compressedSupport then paths.initCompressedSupport() end
	if not key then
		Logger.log("warn", "A key must be provided!")
		return
	end

	local basePath, path = "images/" .. key .. "."
	for key in ipairs(paths.compressedSupport) do
		if paths.compressedSupport[key] then
			path = paths.getPath(basePath .. key)
			if paths.exists(path, "file") then
				return generate(self, self.images, path, function()
					return love.graphics.newImage(path, nil, true)
				end, "image")
			end
		end
	end

	path = paths.getPath(basePath .. "png")
	return generate(self, self.images, path, function()
		if paths.exists(path, "file") then
			return love.graphics.newImage(path, fullQuality and fullQualityTbl or nil)
		end
	end, "image")
end

function Library:getAnimateAtlas(key)
	local path = paths.getPath("images/" .. key)
	return generate(self, self.animate_atlases, path, function(y)
		if y then
			local lib = AnimateLibrary(path)
			--lib:load()
			return lib
		end
	end, "animate atlas", true)
end

function Library:getAudio(key, stream, logError)
	local path = paths.getPath(key .. ".ogg")
	return generate(self, self.audio, path, function(y)
		if y then return stream and love.audio.newSource(path, "stream") or
			love.sound.newSoundData(path) end
	end, not logError and "audio" or nil)
end

function Library:getMusic(key) return self:getAudio("music/" .. key, true) end

function Library:getSound(key) return self:getAudio("sounds/" .. key, false) end

function Library:getInst(song, suffix, logError)
	return self:getAudio("songs/"
		.. paths.formatToSongPath(song)
		.. "/Inst" .. (suffix and "-" .. suffix or ""), true, logError)
end

function Library:getVoices(song, suffix, logError)
	return self:getAudio("songs/"
		.. paths.formatToSongPath(song)
		.. "/Voices" .. (suffix and "-" .. suffix or ""), true, logError)
end

function Library:getSparrowAtlas(key, fullQuality)
	local imgPath, xmlPath = key, paths.getPath("images/" .. key .. ".xml")
	local atlasPath = paths.getPath("images/" .. key)

	return generate(self, self.atlases, atlasPath, function()
		local img = self:getImage(imgPath, fullQuality)
		if img and paths.exists(xmlPath, "file") then
			return FrameCollection.fromSparrow(img, paths.readFile(xmlPath))
		end
		return nil
	end)
end

function Library:getPackerAtlas(key, fullQuality)
	local imgPath, txtPath = key, paths.getPath("images/" .. key .. ".txt")
	local atlasPath = paths.getPath("images/" .. key)

	return generate(self, self.atlases, atlasPath, function()
		local img = self:getImage(imgPath, fullQuality)
		if img and paths.exists(txtPath, "file") then
			return FrameCollection.fromPacker(img, paths.readFile(txtPath))
		end
		return nil
	end)
end

function Library:getAtlas(key, fullQuality)
	if paths.exists(paths.getPath("images/" .. key .. ".xml"), "file") then
		return self:getSparrowAtlas(key, fullQuality)
	end
	return self:getPackerAtlas(key, fullQuality)
end

local paths = {
	_internal = nil,
	_libs = {},
}

paths._internal = Library()
paths._internal.persistantAssets = {"music/freakyMenu.ogg"}

paths.images = paths._internal.images
paths.audio = paths._internal.audio
paths.atlases = paths._internal.atlases
paths.fonts = paths._internal.fonts
paths.skins = paths._internal.skins
paths.animate_atlases = paths._internal.animate_atlases
paths.persistantAssets = paths._internal.persistantAssets
paths.async = paths._internal.async

function paths.getLib(name)
	if paths._libs[name] then return paths._libs[name] end
	paths._libs[name] = Library()
	return paths._libs[name]
end

function paths.destroyLib(name)
	local lib = paths._libs[name]
	if lib then
		lib:destroy()
		paths._libs[name] = nil
		return true
	end
	return false
end

local ktx = {"ETC1", "ETC2rgb", "ETC2rgba", "ETC2rgba1", "EACr", "EACrs", "EACrg", "EACrgs"}
local dds = {"DXT1", "DXT3", "DXT5", "BC4", "BC4s", "BC5", "BC5s", "BC6h", "BC6hs", "BC7"}
local astc = {"ASTC4x4", "ASTC5x4", "ASTC5x5", "ASTC6x5", "ASTC6x6", "ASTC8x5", "ASTC8x6", "ASTC8x8",
			  "ASTC10x5", "ASTC10x6", "ASTC10x8", "ASTC10x10", "ASTC12x10", "ASTC12x12"}

function paths.initCompressedSupport()
	local supported = love.graphics.getImageFormats()
	local hasKTX, hasDDS, hasASTC

	for _, format in pairs(ktx) do
		if supported[format] then hasKTX = true; break end
	end
	for _, format in pairs(dds) do
		if supported[format] then hasDDS = true; break end
	end
	for _, format in pairs(astc) do
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
paths.readFile = readFile

local function insertFile(path, file, type, tbl)
	local info = love.filesystem.getInfo(path)
	if info and (type == "any" or info.type == type:lower()) then
		table.insert(tbl, file)
	end
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

function paths.getLua(key)
	local path = paths.getPath(key .. ".lua")
	if paths.exists(path, "file") then return love.filesystem.load(path) end
end

local invalidChars = '[~&\\;:<>#]'
local hideChars = '[.,\'"%?!]'
function paths.formatToPath(path)
	return string.lower(string.gsub(string.gsub(path:gsub(" ", "-"),
			invalidChars, "-"), hideChars,
		""))
end

paths.formatToSongPath = paths.formatToPath

function paths.update(dt)
	asyncModule.update(dt)
end

function paths.crashstop()
	asyncModule.crashstop()
end

return setmetatable(paths, {
	__index = function(t, k)
		local internal = rawget(t, "_internal")
		if internal and Library[k] then
			return function(...)
				return internal[k](internal, ...)
			end
		end
	end
})
