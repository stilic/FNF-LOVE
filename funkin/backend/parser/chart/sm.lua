local sm = {name = "StepMania"}
local NoteBuffer = require "funkin.backend.notebuffer"

local function stripLineComments(content)
	local out, valid = {}, true
	for i = 1, #content do
		local ch = content:sub(i, i)
		if ch == "/" and content:sub(i + 1, i + 1) == "/" then
			valid = false
		elseif ch == "\n" then
			out[#out + 1] = ch
			valid = true
		elseif valid then
			out[#out + 1] = ch
		end
	end
	return table.concat(out)
end

local function trim(s) return s:gsub("^%s+", ""):gsub("%s+$", "") end

function sm.load(content)
	local data = { NOTES = {} }
	for tag, val in stripLineComments(content):gmatch("#([^:]+):([^;]*);") do
		local key = tag:upper():gsub("%s+", "")
		if key == "NOTES" then
			data.NOTES[#data.NOTES + 1] = val
		else
			data[key] = trim(val)
		end
	end
	return data
end

local function buildBpmMap(bpmString)
	local map = {}
	for beat, bpm in (bpmString or "0=120"):gsub("[,\n\r]", " "):gmatch("([%d%.]+)%s*=%s*([%d%.]+)") do
		map[#map + 1] = { beat = tonumber(beat), bpm = tonumber(bpm) }
	end
	table.sort(map, function(a, b) return a.beat < b.beat end)

	map[1].startMs = 0
	for i = 2, #map do
		local prev     = map[i - 1]
		local beatDiff = map[i].beat - prev.beat
		map[i].startMs = prev.startMs + (beatDiff / (prev.bpm / 60)) * 1000
	end

	return map
end

local function beatToMs(bpmMap, beat)
	for i = #bpmMap, 1, -1 do
		if beat >= bpmMap[i].beat - 0.001 then
			local diff = beat - bpmMap[i].beat
			return bpmMap[i].startMs + (diff / (bpmMap[i].bpm / 60)) * 1000
		end
	end
	return 0
end

local function findNoteData(smData, targetDiff)
	for _, block in ipairs(smData.NOTES) do
		local sections = {}
		for s in block:gmatch("([^:]+)") do sections[#sections + 1] = trim(s) end
		if sections[3] and sections[3]:lower() == targetDiff:lower() then
			return sections[6] or sections[#sections]
		end
	end
	return ""
end

local ROW_NOTE_TYPES = {
	["1"] = "tap",
	["2"] = "holdHead",
	["4"] = "rollHead",
	["3"] = "holdTail",
}

local function parseNoteRows(rawNoteData)
	local noteData    = {}
	local holdTracker = {}
	local measureIdx  = 0

	for measureStr in rawNoteData:gmatch("([^,]+)") do
		local rows = {}
		for line in measureStr:gmatch("[^\r\n]+") do
			local t = trim(line)
			if #t > 0 then rows[#rows + 1] = t end
		end

		local numRows = #rows
		if numRows > 0 then
			local rowsPerBeat = 192.0 / numRows

			for rowIdx = 0, numRows - 1 do
				local row  = rows[rowIdx + 1]
				local beat = (measureIdx * 192 + rowsPerBeat * rowIdx) / 48.0

				for col = 1, #row do
					local ch   = row:sub(col, col)
					local lane = col - 1

					if ch == "1" then
						noteData[#noteData + 1] = { beat = beat, lane = lane, kind = "tap" }
					elseif ch == "2" or ch == "4" then
						noteData[#noteData + 1] = { beat = beat, lane = lane, kind = "holdHead" }
						holdTracker[lane] = #noteData
					elseif ch == "3" and holdTracker[lane] then
						noteData[holdTracker[lane]].holdEndBeat = beat
						holdTracker[lane] = nil
					end
				end
			end
		end

		measureIdx = measureIdx + 1
	end

	return noteData
end

function sm.parse(song, data, events, targetDiff)
	local smData  = type(data) == "string" and sm.load(data) or data
	local chart   = Song.newChart(nil, false)
	local offset  = (tonumber(smData.OFFSET) or 0) * 1000

	local bpmMap  = buildBpmMap(smData.BPMS)
	local rows    = parseNoteRows(findNoteData(smData, targetDiff or "Normal"))

	local player = NoteBuffer()
	for _, note in ipairs(rows) do
		local timeMs = beatToMs(bpmMap, note.beat) - offset
		local length = 0
		if note.holdEndBeat then
			length = beatToMs(bpmMap, note.holdEndBeat) - beatToMs(bpmMap, note.beat)
		end
		player:push(timeMs, note.lane, length, 0, false)
	end
	player:shrink()

	local timeChanges = {}
	for _, entry in ipairs(bpmMap) do
		timeChanges[#timeChanges + 1] =
			Song.newTimeChange(entry.startMs - offset, entry.bpm, entry.beat)
	end

	chart.notes       = { player = player, enemy = NoteBuffer() }
	chart.timeChanges = timeChanges
	chart.events      = { { t = 0, e = "FocusCamera", v = 0 } }
	chart.bpm         = bpmMap[1].bpm
	chart.speed       = 2.5
	chart.stage       = "test"
	chart.player1     = "bf"
	chart.gfVersion   = "gf"

	return chart
end

return sm
