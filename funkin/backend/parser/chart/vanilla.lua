local vanilla = {name = "Vanilla/Psych"}
local NoteBuffer = require "funkin.backend.notebuffer"

local STAGE_BY_SONG = {
	["test"]              = "test",
	["spookeez"]          = "spooky",  ["south"]        = "spooky",  ["monster"]  = "spooky",
	["pico"]              = "philly",  ["philly-nice"]  = "philly",  ["blammed"]  = "philly",
	["satin-panties"]     = "limo",    ["high"]         = "limo",    ["milf"]     = "limo",
	["cocoa"]             = "mall",    ["eggnog"]       = "mall",
	["winter-horrorland"] = "mall-evil",
	["senpai"]            = "school",  ["roses"]        = "school",
	["thorns"]            = "school-evil",
	["ugh"]               = "tank",    ["guns"]         = "tank",    ["stress"]   = "tank",
}

local SKIN_BY_STAGE = {
	["school"]       = "default-pixel",
	["school-evil"]  = "default-pixel",
}

local GF_BY_STAGE = {
	["limo"]        = "gf-car",
	["mall"]        = "gf-christmas",
	["mall-evil"]   = "gf-christmas",
	["school"]      = "gf-pixel",
	["school-evil"] = "gf-pixel",
	["tank"]        = "gf-tankmen",
}

local function applyFallbacks(chart, songPath)
	if not chart.stage then
		chart.stage = STAGE_BY_SONG[songPath] or "stage"
	end
	if not chart.skin then
		chart.skin = SKIN_BY_STAGE[chart.stage]
	end
	if not chart.gfVersion then
		if chart.stage == "tank" and songPath == "stress" then
			chart.gfVersion = "pico-speaker"
		else
			chart.gfVersion = GF_BY_STAGE[chart.stage] or "gf"
		end
	end
end

local function resolveKind(raw, forceAlt)
	if raw == true or raw == 1 or forceAlt then return "alt" end
	if raw == "gf" or raw == "GF Sing"     then return nil  end
	if type(raw) == "string"               then return raw  end
	return nil
end

local function parseSections(sections, startBpm, isPsych, externalEvents)
	local enemy       = NoteBuffer()
	local player      = NoteBuffer()
	local events      = {}
	local timeChanges = { Song.newTimeChange(0, startBpm) }

	timeChanges[1].stepCrotchet = (60 / startBpm * 1000) / 4
	timeChanges[1].id           = 0

	if externalEvents then
		for _, entry in ipairs(externalEvents) do
			local eTime = entry[1]
			for _, item in ipairs(entry[2]) do
				events[#events + 1] = { t = eTime, e = item[1], v = { item[2], item[3] }, psych = true }
			end
		end
	end

	local currentBpm    = startBpm
	local bpmChangeCount = 0
	local currentTime   = 0
	local currentStep   = 0
	local lastFocus     = nil

	for _, section in ipairs(sections) do
		if not section.sectionNotes then goto nextSection end

		for _, noteArr in ipairs(section.sectionNotes) do
			local time_ms = noteArr[1]
			local col     = noteArr[2]
			local length  = noteArr[3]
			local rawKind = noteArr[4]

			local isGf    = rawKind == "gf" or rawKind == "GF Sing"
			local hitsPlayer = isPsych or section.mustHitSection
			if col > 3 then hitsPlayer = not hitsPlayer end

			local forceAlt = not hitsPlayer and section.altAnim
			local kind     = isGf and nil or resolveKind(rawKind, forceAlt)
			local gfFlag   = isGf or (not hitsPlayer and section.gfSection) or false
			local buf      = hitsPlayer and player or enemy

			buf:push(time_ms, col % 4, length, kind, gfFlag)
		end

		local focus = section.gfSection and 2 or (section.mustHitSection and 0 or 1)
		if focus ~= lastFocus then
			events[#events + 1] = { t = currentTime, e = "FocusCamera", v = focus }
			lastFocus = focus
		end

		if section.changeBPM and section.bpm and section.bpm ~= currentBpm then
			currentBpm    = section.bpm
			bpmChangeCount = bpmChangeCount + 1

			local tc            = Song.newTimeChange(currentTime, currentBpm)
			tc.step             = currentStep
			tc.stepCrotchet     = (60 / currentBpm * 1000) / 4
			tc.id               = bpmChangeCount
			timeChanges[#timeChanges + 1] = tc
		end

		local rowCount     = section.sectionBeats and section.sectionBeats * 4 or 16
		local stepCrotchet = timeChanges[#timeChanges].stepCrotchet
		currentStep = currentStep + rowCount
		currentTime = currentTime + stepCrotchet * rowCount

		::nextSection::
	end

	return { enemy = enemy, player = player }, events, timeChanges
end

function vanilla.parse(song, data, events)
	local raw = data.song
	data = type(raw) == "table" and raw or data

	local chart = Song.newChart()

	chart.song      = data.song
	chart.bpm       = data.bpm
	chart.speed     = data.speed
	chart.stage     = data.stage
	chart.player1   = data.player1
	chart.player2   = data.player2
	chart.gfVersion = data.gfVersion

	local meta      = song.meta
	chart.song      = chart.song      or meta.songName or meta.song
	chart.stage     = chart.stage     or meta.stage
	chart.skin      = chart.skin      or meta.skin
	chart.player1   = chart.player1   or meta.player
	chart.player2   = chart.player2   or meta.opponent
	chart.gfVersion = chart.gfVersion or meta.girlfriend

	local isPsych = data.format and data.format:startsWith("psych")
	applyFallbacks(chart, paths.formatToSongPath(chart.song))

	if data.notes then
		chart.notes, chart.events, chart.timeChanges =
			parseSections(data.notes, chart.bpm, isPsych, events or data.events)
	end

	return chart
end

return vanilla
