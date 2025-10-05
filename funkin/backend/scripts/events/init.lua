local path = "funkin.backend.scripts.events."
Events = {}

Events.Cancellable = require(path .. "cancellable")
Events.NoteHit = require(path .. "notehit")
Events.Miss = require(path .. "miss")
Events.PopUpScore = require(path .. "popupscore")
Events.CameraMove = require(path .. "cameramove")
Events.GameOver = require(path .. "gameover")
Events.CountdownCreation = require(path .. "countdowncreation")
