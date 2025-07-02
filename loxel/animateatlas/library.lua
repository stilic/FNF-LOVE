local json = loxreq "lib.json"

local AnimateLibrary = Basic:extend("AnimateLibrary")

function AnimateLibrary:new(folder)
	AnimateLibrary.super.new(self)

	self.timeline = {}
	self.spritemaps = {}
	self.libraries = {}
	self.framerate = 24

	self.folder = folder
	self.timeline = {}

	self.timeline.data = json.decode(love.filesystem.read("string", folder .. "/" .. "Animation.json"))
	self.timeline.optimized = self.timeline.data.AN ~= nil

	self.spritemaps = {}
	for _, item in ipairs(love.filesystem.getDirectoryItems(folder)) do
		if string.startsWith(item, "spritemap") and string.endsWith(item, ".json") then
			local data = json.decode(love.filesystem.read("string", folder .. "/" .. item))
			local texture = love.graphics.newImage(folder .. "/" .. string.sub(item, 1, #item - 5) .. ".png")
			table.insert(self.spritemaps, { data = data, texture = texture })
		end
	end

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
		for _, item in ipairs(love.filesystem.getDirectoryItems(folder .. "/LIBRARY")) do
			if string.endsWith(item, ".json") then
				local data = json.decode(love.filesystem.read("string", folder .. "/LIBRARY/" .. item))
				self.libraries[string.sub(item, 1, #item - 5)] = { data = data, optimized = data.L ~= nil }
			end
		end
	end
	if #self.spritemaps < 1 then
		error("Couldn't find any spritemaps for folder path '" .. folder .. "'")
		return
	end

	if love.filesystem.getInfo(folder .. "/metadata.json", "file") ~= nil then
		self.framerate = json.decode(love.filesystem.read("string", folder .. "/metadata.json"))[self.timeline.optimized and "FRT" or "framerate"]
	else
		local optimized = self.timeline.data.FRT ~= nil
		local hasFramerate = self.timeline.data.FRT ~= nil or self.timeline.data.framerate ~= nil
		self.framerate = hasFramerate and (optimized and self.timeline.data.FRT or self.timeline.data.framerate) or 24
	end
end

function AnimateLibrary:getTimelineLength(timeline)
	local optimized = timeline.optimized == true or timeline.L ~= nil
	if timeline.data then
		timeline = timeline.data[optimized and "AN" or "ANIMATION"][optimized and "TL" or "TIMELINE"]
	end
	local longest = 0
	local timelineLayers = timeline[optimized and "L" or "LAYERS"]
	for i = #timelineLayers, 1, -1 do
		local layer = timelineLayers[i]
		local layerFrames = layer[optimized and "FR" or "Frames"]
		if layerFrames == nil then
			goto continue
		end

		local keyframe = layerFrames[#layerFrames]
		if keyframe ~= nil then
			local length = keyframe[optimized and "I" or "index"] + keyframe[optimized and "DU" or "duration"]
			if length > longest then
				longest = length
			end
		end
		::continue::
	end

	return longest
end

function AnimateLibrary:getLength()
	local optimized = self.timeline.optimized == true or self.timeline.L ~= nil
	return self:getTimelineLength(self.timeline.data[optimized and "AN" or "ANIMATION"][optimized and "TL" or "TIMELINE"])
end

function AnimateLibrary:getSymbolTimeline(symbol)
	if not symbol then
		symbol = ""
	else
		symbol = symbol:match("^%s*(.-)%s*$") or ""
	end

	local timeline = self.libraries[symbol]
	if not timeline and symbol ~= "" then
		for key, value in pairs(self.libraries) do
			local trimmed = key:match("^%s*(.-)%s*$") or ""
			if trimmed == symbol then
				timeline = value
				break
			end
		end
	end
	if not timeline then
		timeline = self.timeline
	else
		timeline = timeline.data
	end

	return timeline
end

function AnimateLibrary:destroy()
	for _, spritemap in ipairs(self.spritemaps or {}) do
		if spritemap.texture then
			spritemap.texture:release()
		end
	end

	self.spritemaps = {}
	self.libraries = {}
	self.timeline = {}
	self.loaded = false

	AnimateLibrary.super.destroy(self)
end

return AnimateLibrary
