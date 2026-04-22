local codename = {name = "Codename"}
local NoteBuffer = require "funkin.backend.notebuffer"

local function remapEvent(e)
	if e.name ~= "Camera Movement" then return e end
	local val = e.params[1]
	return {
		name   = "FocusCamera",
		time   = e.time,
		params = val ~= 2 and 1 - val or val
	}
end

local function parseEvents(eventData)
	if not eventData then return {} end
	local events = {}
	for _, e in ipairs(eventData.events) do
		local mapped = remapEvent(e)
		events[#events + 1] = {
			t        = mapped.time,
			e        = mapped.name,
			v        = mapped.params,
			codename = true
		}
	end
	return events
end

local STRUM_POSITIONS = {
	dad        = { buf = "enemy",  gf = false },
	girlfriend = { buf = "enemy",  gf = true  },
	boyfriend  = { buf = "player", gf = false },
}

local function parseStrumLines(strumLines, chart)
	local enemy  = NoteBuffer()
	local player = NoteBuffer()
	local bufs   = { enemy = enemy, player = player }

	for _, strum in ipairs(strumLines) do
		local info = STRUM_POSITIONS[strum.position]
		if not info then goto nextStrum end

		if strum.position == "dad"        then Parser.pset(chart, "player2",    strum.characters[1]) end
		if strum.position == "girlfriend" then Parser.pset(chart, "gfVersion",  strum.characters[1]) end
		if strum.position == "boyfriend"  then Parser.pset(chart, "player1",    strum.characters[1]) end

		local buf   = bufs[info.buf]
		local isGf  = info.gf

		for _, n in ipairs(strum.notes) do
			buf:push(n.time, n.id % 4, n.sLen, n.type, isGf)
		end

		::nextStrum::
	end

	enemy:shrink()
	player:shrink()

	return { enemy = enemy, player = player }
end

local function parseTimeChanges(meta, eventData)
	local timeChanges = { Song.newTimeChange(0, meta.bpm or 100) }
	if not eventData then return timeChanges end

	for _, e in ipairs(eventData.events) do
		if e.name == "BPM Change" then
			timeChanges[#timeChanges + 1] = Song.newTimeChange(e.time, e.params[1])
		end
	end
	return timeChanges
end

function codename.parse(song, data, events)
	local chart = Song.newChart(nil, true)

	Parser.pset(chart, "song",  song.meta.displayName or song.meta.name)
	Parser.pset(chart, "skin",  song.meta.skin)
	Parser.pset(chart, "stage", data.stage)
	Parser.pset(chart, "speed", data.scrollSpeed)

	chart.timeChanges = parseTimeChanges(song.meta, events)
	chart.events      = parseEvents(events)
	chart.notes       = parseStrumLines(data.strumLines, chart)

	return chart
end

return codename
