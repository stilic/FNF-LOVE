local codename = {name = "Codename"}

local function getFromMeta(data, tbl)
	Parser.pset(tbl, "song", data.displayName or data.name)
	Parser.pset(tbl, "skin", data.skin)

	Parser.pset(tbl, "difficulties", data.difficulties)
	Parser.pset(tbl, "bpm", data.bpm)
end

local function getStuff(data, eventData, chart)
	local dad, bf, events =
		{}, {}, {}

	if eventData then
		for i, e in ipairs(eventData.events) do
			local eevent, eparams
			if e.name == "Camera Movement" then
				e.name = "FocusCamera"
				local val = e.params[1]
				e.params = val ~= 2 and 1 - val or val
			end

			table.insert(events, {
				t = e.time,
				e = e.name,
				v = e.params,
				codename = true
			})
		end
	end

	for _, s in ipairs(data.strumLines) do
		local toAdd, gfNotes = bf
		if s.position == "dad" then
			toAdd = dad
			gfNotes = false
			Parser.pset(chart, "player2", s.characters[1])
		elseif s.position == "girlfriend" then
			toAdd = dad
			gfNotes = true
			Parser.pset(chart, "gfVersion", s.characters[1])
		elseif s.position == "boyfriend" then
			toAdd = bf
			gfNotes = false
			Parser.pset(chart, "player1", s.characters[1])
		end

		for _, n in ipairs(s.notes) do
			local newNote = {
				t = n.time,
				d = n.id % 4,
				l = n.sLen,
				k = n.type,
				gf = gfNotes
			}
			table.insert(toAdd, newNote)
		end
	end

	return {enemy = dad, player = bf}, events
end

function codename.parse(data, events, meta)
	local chart = Parser.getDummyChart(nil, true)

	if meta then getFromMeta(meta, chart) end

	Parser.pset(chart, "stage", data.stage)
	Parser.pset(chart, "speed", data.scrollSpeed)

	local timeChanges = {}
	if events then
		for _, e in ipairs(events) do
			if e.name == "BPM Change" then
				table.insert(timeChanges, Parser.newTimeChange(e.time, e.params[1]))
			end
		end
	end
	chart.timeChanges = timeChanges

	chart.notes, chart.events = getStuff(data, events, chart)

	return chart
end

return codename
