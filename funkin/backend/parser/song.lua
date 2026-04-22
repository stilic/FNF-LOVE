local Song = Classic:extend("Song")

local metadefs = {
	composer     = "Unknown Composer",
	album        = "Unknown Album",
	charter      = "Unknown Charter",
	difficulties = {"Easy", "Normal", "Hard"}
}

local SongMetaMT = {
	__index = function(data, key)
		local aliases = {
			displayName = {"displayName", "songName", "name", "song"},
			composer    = {"composer", "artist"}
		}

		local pdata = rawget(data, "playData")
		local keys = aliases[key]

		if keys then
			for _, k in ipairs(keys) do
				if pdata and pdata[k] ~= nil then return pdata[k] end
				if rawget(data, k) ~= nil then return rawget(data, k) end
			end
		else
			if pdata and pdata[key] ~= nil then return pdata[key] end
			if rawget(data, key) ~= nil then print("debug") return rawget(data, key) end
		end
		return metadefs[key]
	end
}

local parserPath = "funkin.backend.parser.chart."

local Parsers = {
	vanilla = require(parserPath .. "vanilla"),
	codename = require(parserPath .. "codename"),
	vslice = require(parserPath .. "vslice"),
	sm = require(parserPath .. "sm")
}

function Song.newChart(name, dummyData)
	return {
		song = name and paths.formatToSongPath(name) or nil,
		bpm = 100,
		speed = 1,

		player1 = dummyData and "bf" or nil,
		player2 = dummyData and "dad" or nil,
		gfVersion = dummyData and "gf" or nil,

		stage = dummyData and "stage" or nil,
		skin = dummyData and "default" or nil,

		events = {},
		notes = {player = {}, enemy = {}}
	}
end

function Song.newTimeChange(time, bpm, beats, n, d)
	return {t = time, b = beats, bpm = bpm, n = n or 4, d = d or 4}
end

function Song:new(name, diff)
	self.chart = {}

	self.path = paths.formatToSongPath(name or "test")

	local metapath = "/meta" .. (diff and ("-" .. diff) or "")
	local s, content = pcall(paths.getJSON, "songs/" .. self.path .. metapath)
	local smData = nil
	if not s or not content then
		local smPath = paths.getPath("songs/" .. self.path .. "/" .. self.path .. ".sm")
		if paths.exists(smPath, "file") then
			local rawSM = love.filesystem.read(smPath)
			smData = Parsers.sm.load(rawSM)
		end
	end

	if not s and content and not smData then
		Logger.log("error", "Meta for " .. name .. " returned a error: " .. content)
	end
	local meta = setmetatable((content or {}), SongMetaMT)
	if smData then
		meta.displayName = smData.TITLE
		meta.composer = smData.ARTIST
	end

	self.meta = meta

	self.name = meta.displayName or self.path or (smData and smData.TITLE)
	meta.song = meta.song or name or "test"
	self.difficulties = meta.difficulties

	self.composer = meta.composer
	self.album = meta.album
	self.charter = meta.charter

	self.icon = meta.icon or HealthIcon.defaultIcon

	local color = meta.color
	if color then
		switch(type(color), {
			["string"] = function() color = Color.fromHEX(tonumber("0x" .. color:gsub("#", ""))) end,
			["number"] = function() color = Color.fromHEX(color) end,
			["table"]  = function() color = Color.convert(color) end
		})
	end
	self.color = color or Color.WHITE

	if meta.version ~= nil and meta.songName then
		switch(meta.songName:lower(), {
			[{"bopeebo", "fresh", "dadbattle"}] = function() self.icon = "dad" end,
			[{"south", "spookeez"}] = function() self.icon = "spooky" end,
			[{"pico", "philly nice", "blammed"}] = function() self.icon = "pico" end,
			[{"satin panties", "high", "m.i.l.f"}] = function() self.icon = "mom" end,
			[{"cocoa", "eggnog"}] = function() self.icon = "parents" end,
			[{"ugh", "guns", "stress"}] = function() self.icon = "tankman" end,
			[{"darnell", "lit up", "2hot", "blazin"}] = function() self.icon = "darnell" end,
			[{"monster", "winter horrorland"}] = function() self.icon = "monster" end,
			["senpai"] = function() self.icon = "senpai-pixel" end,
			["roses"] = function() self.icon = "senpai-angry-pixel" end,
			["thorns"] = function() self.icon = "spirit-pixel" end,
			["tutorial"] = function() self.icon = "gf" end,
		})
	end

	self.charts = {}
end

function Song:getChart(diff, variant)
	diff = diff and diff:lower() or "normal"
	variant = variant and variant:lower() or nil

	local key = diff .. (variant and ("_" .. variant) or "")
	if self.charts[key] then return self.charts[key] end

	local path, data = "songs/" .. self.path .. "/"
	local function getFolder(dir, ext)
		return {paths.getPath(path .. dir .. (ext or ".json")), path .. dir}
	end

	for _, p in ipairs({
		getFolder("charts/" .. diff),
		getFolder("chart-" .. diff),
		getFolder(diff),
		getFolder("chart")
	}) do
		if paths.exists(p[1], "file") then data = paths.getJSON(p[2]) end
	end

	local kind
	if not data then
		local smPath = paths.getPath(path .. self.path .. ".sm")
		if paths.exists(smPath, "file") then
			data = love.filesystem.read(smPath)
			kind = "sm"
		end
	end

	if not data then
		Logger.log("warn", "Chart not found for " .. self.name .. ", dummy chart generated")
		local dummy = Song.newChart(self.path, true)
		self.charts[key] = dummy
		dummy.metadata = self.meta
		dummy.difficulties = self.difficulties
		return dummy
	end

	if not kind then
		kind = data.codenameChart and "codename" or
			(not data.version and "vanilla" or "vslice")
	end

	local events
	if kind ~= "vslice" then
		events = paths.getJSON(path .. "events")
	end

	local parser = Parsers[kind]
	data = parser.parse(self, data, events, diff)

	data.notes.enemy:sortByTime()
	data.notes.player:sortByTime()
	table.sort(data.events, Parser.sortByTime)

	data.song = data.song or self.path
	data.metadata = self.meta
	data.difficulties = self.difficulties
	data.skin = data.skin or self.meta.skin

	self.charts[key] = data

	Logger.log("debug", "Chart \"" .. (data.song or "unknown") ..
		"\" parsed as " .. (parser.name or "unknown"))

	return self.charts[key]
end

function Song:destroy()
	self.charts = nil
	self.meta = nil
end

return Song
