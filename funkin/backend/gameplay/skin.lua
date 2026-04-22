local function loadAsset(type, p)
	local obj
	switch(type, {
		["image"] = function() obj = paths.getImage(p) end,
		["atlas"] = function() obj = paths.getAtlas(p) end,
		["sound"] = function() obj = paths.getSound(p) end
	})
	return obj
end

local Skin = Basic:extend("Skin")

function Skin:new(name)
	local s, d = pcall(paths.getJSON, "data/skins/" .. name)

	if s and d ~= nil then
		self.data = d
		self.data.skin = self.data.skin or name
	else
		self.data = paths.getJSON("data/skins/default" ..
			(name:endsWith("-pixel") and "-pixel" or ""))
		self.data.skin = name:endsWith("-pixel") and "default-pixel" or "default"
	end
	self.skin = self.data.skin
	self.isPixel = self.skin:endsWith("-pixel")

	self.assetCache = {}
	self.pathCache = {}
end

function Skin:get(asset, type)
	type = type or "image"
	local cacheKey = type .. ":" .. asset

	if self.assetCache[cacheKey] ~= nil then
		local cached = self.assetCache[cacheKey]
		return cached ~= false and cached or nil
	end

	local function try(skin)
		return loadAsset(type, "skins/" .. skin .. "/" .. asset)
	end

	local obj = try(self.skin)
	if not obj and self.isPixel and self.skin ~= "default-pixel" then
		obj = try("default-pixel")
	end
	if not obj then obj = try("default") end

	self.assetCache[cacheKey] = obj or false
	return obj
end

function Skin:getPath(asset, type)
	type = type or "image"
	local cacheKey = type .. ":" .. asset

	if self.pathCache[cacheKey] ~= nil then
		return self.pathCache[cacheKey]
	end

	local function buildFullPath(skin)
		local path, full = "skins/" .. skin .. "/" .. asset
		switch(type, {
			[{"image", "atlas"}] = function() full = "images/" .. path .. ".png" end,
			["sound"] = function() full = "sounds/" .. path .. ".ogg" end
		})
		if full and paths.exists(paths.getPath(full), "file") then
			return path
		end
	end

	local path = buildFullPath(self.skin)
	if not path and self.isPixel and self.skin ~= "default-pixel" then
		path = buildFullPath("default-pixel")
	end
	if not path then path = buildFullPath("default") end

	local finalPath = path or ("skins/default/" .. asset)

	self.pathCache[cacheKey] = finalPath
	return finalPath
end

return Skin
