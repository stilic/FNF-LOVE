local vslice = {name = "V-Slice"}

local stage
local switchStage = {
	["mainStage"] = function() stage = "stage" end,
	["spookyMansion"] = function() stage = "spooky" end,
	["phillyTrain"] = function() stage = "philly" end,
	["limoRide"] = function() stage = "limo" end,
	["mallXmas"] = function() stage = "mall" end,
	["mallEvil"] = function() stage = "mall-evil" end,
	["schoolEvil"] = function() stage = "school-evil" end,
	["tankmanBattlefield"] = function() stage = "tank" end
}

local function updateFromMeta(data, meta)
	if not meta then return end

	assert(meta.playData ~= nil, "Not a valid V-Slice metadata")
	local info = meta.playData

	-- Parser.pset(data, "song", meta.songName or meta.song)

	stage = nil
	switch(info.stage, switchStage)
	Parser.pset(data, "stage", stage or info.stage)

	local notestyle = info.noteStyle == "funkin" and
		"default" or info.noteStyle == "pixel" and "default-pixel"
		or info.noteStyle
	Parser.pset(data, "skin", notestyle)
	Parser.pset(data, "difficulties", info.difficulties)
	Parser.pset(data, "timeChanges", meta.timeChanges)

	info = info.characters
	Parser.pset(data, "player1", info.player)
	Parser.pset(data, "player2", info.opponent)
	Parser.pset(data, "gfVersion", info.girlfriend)
end

local function processNotes(notes)
	local dad, bf, isPlayer = {}, {}
	for _, n in ipairs(notes) do
		isPlayer = not (tonumber(n.d or 0) > 3)
		n.d = tonumber(n.d or 0) % 4
		n.k = n.k == "mom" and "alt" or n.k
		table.insert(isPlayer and bf or dad, n)
	end

	return {enemy = dad, player = bf}
end

function vslice.parse(data, events, meta, diff)
	local scrollspeed, notes, events = data.scrollSpeed, data.notes, data.events
	for k, _ in pairs(data) do data[k] = nil end
	updateFromMeta(data, meta)

	if scrollspeed and diff then
		data.speed = scrollspeed[diff:lower()] or scrollspeed.default or 1
	end

	local diffnotes = notes and notes[diff:lower()] or nil
	data.notes = diffnotes and processNotes(diffnotes) or {enemy = {}, player = {}}
	data.events = events or {}

	return data
end

return vslice
