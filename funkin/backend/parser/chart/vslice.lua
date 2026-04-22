local vslice = {name = "V-Slice"}
local NoteBuffer = require "funkin.backend.notebuffer"

local STAGE_MAP = {
	["mainStage"]          = "stage",
	["spookyMansion"]      = "spooky",
	["phillyTrain"]        = "philly",
	["limoRide"]           = "limo",
	["mallXmas"]           = "mall",
	["mallEvil"]           = "mall-evil",
	["schoolEvil"]         = "school-evil",
	["tankmanBattlefield"] = "tank",
	["phillyStreets"]      = "streets",
}

for k, v in pairs(STAGE_MAP) do STAGE_MAP[k .. "Erect"] = v .. "-erect" end

local NOTE_STYLE_MAP = {
	["funkin"] = "default",
	["pixel"]  = "default-pixel",
}

local KIND_MAP = {
	["mom"] = "alt",
}

local function readMeta(song)
	local info  = song.meta
	local chars = info.characters
	return {
		stage       = STAGE_MAP[info.stage] or info.stage,
		skin        = NOTE_STYLE_MAP[info.noteStyle] or info.noteStyle,
		timeChanges = info.timeChanges,
		player1     = chars.player,
		player2     = chars.opponent,
		gfVersion   = chars.girlfriend,
	}
end

local function processNotes(notes)
	local enemy  = NoteBuffer()
	local player = NoteBuffer()

	for _, n in ipairs(notes) do
		local col      = tonumber(n.d) or 0
		local isPlayer = col <= 3
		local kind     = KIND_MAP[n.k] or n.k
		local buf      = isPlayer and player or enemy

		buf:push(n.t, col % 4, n.l, kind, n.gf)
	end

	enemy:shrink()
	player:shrink()
	return { enemy = enemy, player = player }
end

function vslice.parse(song, data, rawEvents, diff)
	local chart = Song.newChart()

	local meta      = readMeta(song)
	chart.stage     = meta.stage
	chart.skin      = meta.skin
	chart.player1   = meta.player1
	chart.player2   = meta.player2
	chart.gfVersion = meta.gfVersion
	chart.timeChanges = meta.timeChanges

	if data.scrollSpeed and diff then
		chart.speed = data.scrollSpeed[diff:lower()] or data.scrollSpeed.default or 1
	end

	local diffNotes = data.notes and data.notes[diff:lower()]
	chart.notes  = diffNotes and processNotes(diffNotes) or { enemy = {}, player = {} }
	chart.events = data.events or rawEvents or {}

	return chart
end

return vslice
