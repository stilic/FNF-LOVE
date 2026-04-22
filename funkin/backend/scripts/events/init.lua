local path = "funkin.backend.scripts.events."
Events = {}

Events.Cancellable = require(path .. "cancellable")
Events.NoteHit = require(path .. "notehit")
Events.Miss = require(path .. "miss")
Events.PopUpScore = require(path .. "popupscore")
Events.CameraMove = require(path .. "cameramove")
Events.GameOver = require(path .. "gameover")
Events.CountdownCreation = require(path .. "countdowncreation")

Events.pool = {}

function Events.get(eventType, ...)
	Events.pool[eventType] = Events.pool[eventType] or {}
	local pool = Events.pool[eventType]
	local ev = table.remove(pool)

	if ev then
		return ev:recycle(...)
	end
	return eventType(...)
end

function Events.recycle(eventType, ev)
	Events.pool[eventType] = Events.pool[eventType] or {}
	table.insert(Events.pool[eventType], ev)
end
