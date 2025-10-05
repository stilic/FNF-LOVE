local json = loxreq "lib.json"

local AnimateLibrary = loxreq "animateatlas.library"
local AnimateLib = AnimateLibrary:extend("AnimateLibrary")

function AnimateLib:new(folder)
	Basic.new(self)

	self.timeline = {}
	self.spritemaps = {}
	self.libraries = {}
	self.framerate = 24
	self.folder = folder
	self.loaded = false

	self.timeline = {}

	local assfolder = paths.excludeAssets(folder)

	self.timeline.data = paths.getJSON(assfolder .. "/Animation")
	self.timeline.optimized = self.timeline.data.AN ~= nil

	self.libraries = {}
	if self.timeline.data.SD ~= nil or self.timeline.data.SYMBOL_DICTIONARY ~= nil then
		local optimized = self.timeline.data.SD ~= nil
		local symbolDictionary = self.timeline.data[optimized and "SD" or "SYMBOL_DICTIONARY"]
		local symbols = symbolDictionary[optimized and "S" or "Symbols"]

		for i = 1, #symbols do
			local symbol = symbols[i]
			local symbolName = symbol[optimized and "SN" or "SYMBOL_name"]
			local data = symbol[optimized and "TL" or "TIMELINE"]
			self.libraries[symbolName] = { data = data, optimized = data.L ~= nil }
		end
	else
		for _, item in pairs(paths.getItems(assfolder .. "/LIBRARY")) do
			if item:ext() == "json" then
				local data = paths.getJSON(assfolder .. "/LIBRARY/" .. item:withoutExt())
				self.libraries[item:withoutExt()] = { data = data, optimized = data.L ~= nil }
			end
		end
	end

	local configs = {}
	for _, item in pairs(paths.getItems(assfolder)) do
		if item:startsWith("spritemap") and item:ext() == "json" then
			local data = paths.getJSON(assfolder .. "/" .. item:withoutExt())
			table.insert(configs, {
				name = item:withoutExt(),
				data = data,
				imagePath = assfolder .. "/" .. item:withoutExt()
			})
		end
	end

	if paths.exists(paths.getPath(assfolder .. "/metadata.json"), "file") then
		self.framerate = paths.getJSON(assfolder .. "/metadata")[self.timeline.optimized and "FRT" or "framerate"]
	else
		local optimized = self.timeline.data.FRT ~= nil
		local hasFramerate = self.timeline.data.FRT ~= nil or self.timeline.data.framerate ~= nil
		self.framerate = hasFramerate and (optimized and self.timeline.data.FRT or self.timeline.data.framerate) or 24
	end

	if #configs < 1 then
		error("Couldn't find any spritemaps for folder path '" .. folder .. "'")
		return nil
	end

	self.configs = configs
end

function AnimateLib:load()
	self.spritemaps = {}
	for _, config in pairs(self.configs) do
		local texture = paths.getImage(config.imagePath:gsub("images/", ""))
		table.insert(self.spritemaps, {data = config.data, texture = texture})
	end

	self.loaded = true
end

function AnimateLib:loadAsync(callback)
	self.spritemaps = {}
	local loaded, total = 0, #self.configs

	for _, config in ipairs(self.configs) do
		async.getImage(config.imagePath:gsub("images/", ""), function(texture, err)
			if texture then
				table.insert(self.spritemaps, {data = config.data, texture = texture})
			end
			loaded = loaded + 1
			if loaded >= total then
				self.loaded = true
				if callback then callback(self) end
			end
		end)
	end
end

return AnimateLib
