local character = require "funkin.backend.parser.character"
local stage = require "funkin.backend.parser.stage"

local Parser = {character = character}

Song = require "funkin.backend.parser.song"

function Parser.sortByTime(a, b)
	if a and b then
		return a.t < b.t
	end
	return false
end

function Parser.pset(tbl, key, v) if v ~= nil then tbl[key] = v end end

function Parser.getCharacter(name)
	local data = character.get(name)
	if not data then data = character.get("bf") end
	local parser = character.getParser(data)

	local parsed = parser.parse(data, name)

	return parsed, parser.name
end

function Parser.getDummyChar(name)
	return {
		animations = {},
		voice_suffix = name or "",

		position = {0, 0},
		camera_points = {0, 0},
		sing_duration = 8,
		dance_beats = nil,

		flip_x = false,
		icon = HealthIcon.defaultIcon,
		sprite = nil,
		antialiasing = true,
		scale = 1
	}
end

function Parser.getStage(name)
	local data = stage.get(name)
	if not data then return false end

	local parsed = stage.getParser(data)
	if parsed then
		return parsed.parse(data)
	end
end

function Parser.getDummyStage()
	return {
		zoom = 1,
		objects = {},
		characters = {
			boyfriend = {
				x = 770, y = 0, z = 200,
				scale = Point(1, 1),
				scroll = Point(1, 1),
				cameraOffset = Point(-100, -100)
			},
			gf = {
				x = 400, y = -100, z = 100,
				scale = Point(1, 1),
				scroll = Point(1, 1),
				cameraOffset = Point()
			},
			dad = {
				x = 100, y = 0, z = 300,
				scale = Point(1, 1),
				scroll = Point(1, 1),
				cameraOffset = Point(150, -100)
			}
		}
	}
end

return Parser
