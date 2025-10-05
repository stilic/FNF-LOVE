local chart = require "funkin.backend.parser.chart"
local character = require "funkin.backend.parser.character"
local stage = require "funkin.backend.parser.stage"

local Parser = {chart = chart, character = character}

local weak = {__mode = "k"}
local weakValue = {__mode = "kv"}

local chartCache = setmetatable({}, weakValue)
local characterCache = setmetatable({}, weakValue)
local stageCache = setmetatable({}, weakValue)
local metaCache = setmetatable({}, weakValue)

function Parser.sortByTime(a, b)
	if a and b then
		return a.t < b.t
	end
	return false
end

function Parser.pset(tbl, key, v) if v ~= nil then tbl[key] = v end end

local function getCacheKey(...) return table.concat({...}, "@") end

function Parser.getChart(name, diff)
	name = paths.formatToSongPath(name)
	diff = diff and diff:lower() or "normal"

	local cacheKey = getCacheKey(name, diff)

	if chartCache[cacheKey] then return chartCache[cacheKey] end

	local data, path = chart.get(name, diff)

	if data then
		local parser = chart.getParser(data)
		local meta = paths.getJSON(path .. "meta")
		local events = paths.getJSON(path .. "events")

		data = parser.parse(data, events, meta, diff)
		data.metadata = Parser.getMeta(name)

		table.sort(data.notes.enemy, Parser.sortByTime)
		table.sort(data.notes.player, Parser.sortByTime)
		table.sort(data.events, Parser.sortByTime)

		if data.song == nil then data.song = name end

		chartCache[cacheKey] = parsed

		Logger.log("debug", "[ PARSER ] Chart \"" .. (data.song or "unknown") ..
			"\" parsed as " .. (parser.name or "unknown"))
		return data
	else
		Logger.log("warn", "[ PARSER ] Chart not found for " .. name .. ", generated a dummy one")
		local dummy = Parser.getDummyChart(name, true)
		dummy.metadata = Parser.getMeta(name)
		chartCache[cacheKey] = dummy
		return dummy
	end
end

function Parser.getDummyChart(name, dummyData)
	return {
		song = name and paths.formatToSongPath(name) or nil,
		bpm = 100,
		speed = 1,

		difficulties = {"Easy", "Normal", "Hard"},

		player1 = dummyData and "bf" or nil,
		player2 = dummyData and "dad" or nil,
		gfVersion = dummyData and "gf" or nil,

		stage = dummyData and "stage" or nil,
		skin = dummyData and "default" or nil,

		events = {},
		notes = {player = {}, enemy = {}}
	}
end

function Parser.newTimeChange(time, bpm, beats, n, d)
	return {
		t = time,
		b = beats,
		bpm = bpm,
		n = n or 4,
		d = d or 4
	}
end

function Parser.getMeta(name)
	local cacheKey = paths.formatToSongPath(name)

	if metaCache[cacheKey] then return metaCache[cacheKey] end

	local format = paths.formatToSongPath
	local meta = {
		song = format(name),
		displayName = name,
		charter = "unknown",
		composer = "unknown",

		icon = HealthIcon.defaultIcon,
		color = Color.WHITE,
		difficulties = {"easy", "normal", "hard"}
	}

	local data = paths.getJSON("songs/" .. format(name) .. "/meta")
	if not data then
		metaCache[cacheKey] = meta
		return meta
	end
	setmetatable(data, weakValue)

	local function get(key, def)
		local playData, info = data.playData or {}
		if type(key) == "table" then
			for i = 1, #key do
				local k = key[i]
				info = playData[k] ~= nil and playData[k] or
					data[k] ~= nil and data[k]
				if info then
					break
				end
			end
		else
			info = playData[key] ~= nil and playData[key] or
				data[key] ~= nil and data[key]
		end
		return info or def
	end

	meta.displayName = get({"displayName", "songName", "song", "name"}, meta.displayName)
	meta.icon = get("icon", meta.icon)
	meta.difficulties = get("difficulties", meta.difficulties)
	for i, difficulty in ipairs(meta.difficulties) do
		meta.difficulties[i] = difficulty:gsub("^%l", string.upper)
	end

	meta.charter = get("charter", meta.charter)
	meta.composer = get({"composer", "artist"}, meta.composer)

	local rawColor = get("color", nil)
	if rawColor then
		switch(type(rawColor), {
			["string"] = function()
				if not rawColor:startsWith("#") then
					rawColor = "0x" .. rawColor
				else
					rawColor = rawColor:gsub("#", "0x")
				end
				meta.color = Color.fromHEX(tonumber(rawColor))
			end,
			["number"] = function() meta.color = Color.fromHEX(rawColor) end,
			["table"]  = function() meta.color = Color.convert(rawColor) end
		})
	end
	if data.version ~= nil and data.songName then
		switch(data.songName:lower(), {
			[{"bopeebo", "fresh", "dadbattle"}] = function() meta.icon = "dad" end,
			[{"south", "spookeez"}] = function() meta.icon = "spooky" end,
			[{"pico", "philly nice", "blammed"}] = function() meta.icon = "pico" end,
			[{"satin panties", "high", "m.i.l.f"}] = function() meta.icon = "mom" end,
			[{"cocoa", "eggnog"}] = function() meta.icon = "parents" end,
			[{"ugh", "guns", "stress"}] = function() meta.icon = "tankman" end,
			[{"darnell", "lit up", "2hot", "blazin"}] = function() meta.icon = "darnell" end,
			[{"monster", "winter horrorland"}] = function() meta.icon = "monster" end,
			["senpai"] = function() meta.icon = "senpai-pixel" end,
			["roses"] = function() meta.icon = "senpai-angry-pixel" end,
			["thorns"] = function() meta.icon = "spirit-pixel" end,
			["tutorial"] = function() meta.icon = "gf" end,
		})
	end

	metaCache[cacheKey] = meta
	return meta
end

function Parser.getCharacter(name)
	if characterCache[name] then
		return characterCache[name].data, characterCache[name].parser
	end

	local data = character.get(name)
	if not data then data = character.get("bf") end
	local parser = character.getParser(data)

	local parsed = parser.parse(data, name)

	characterCache[name] = {data = parsed, parser = parser.name}

	return parsed, parser.name
end

function Parser.getDummyChar(name)
	return {
		animations = {},
		voice_suffix = name or "",

		position = {0, 0},
		camera_points = {0, 0},
		sing_duration = 4,
		dance_beats = nil,

		flip_x = false,
		icon = HealthIcon.defaultIcon,
		sprite = nil,
		antialiasing = true,
		scale = 1
	}
end

function Parser.getStage(name)
	if stageCache[name] then return stageCache[name] end

	local data = stage.get(name)
	if not data then return false end

	local parsed = stage.getParser(data)
	if parsed then
		parsed = parsed.parse(data)
		stageCache[name] = parsed
	end
	return parsed
end

function Parser.getDummyStage()
	return {
		name = "Stage",
		cameraZoom = 1.0,
		props = {},
		characters = {}
	}
end

function Parser.clearCache()
	chartCache = setmetatable({}, weakValue)
	characterCache = setmetatable({}, weakValue)
	stageCache = setmetatable({}, weakValue)
	metaCache = setmetatable({}, weakValue)
	collectgarbage("collect")
end

return Parser
