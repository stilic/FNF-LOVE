local folder = "funkin.gameplay.notemods."

NoteModifier = require(folder .. "notemodifier")

local NoteMods = {
	beat   = require(folder .. "beat"),
	column = require(folder .. "column"),
	scale  = require(folder .. "scale"),
	scroll = require(folder .. "scroll"),
	tipsy  = require(folder .. "tipsy")
}

return NoteMods
