local lightColors = {
	{49,  162, 253}, {49, 253, 140}, {251, 51, 245}, {253, 69, 49},
	{251, 166, 51}
}
local curLight = 1
local Train, trainobj = require "philly.train"

function postCreate()
	trainobj = Train(train, state)
end

function postUpdate(dt)
	window.alpha = window.alpha -
		(PlayState.conductor.crotchet / 1000) * dt * 1.5
	trainobj:update(dt)
end

function measure()
	local prevCurLight = curLight
	repeat curLight = love.math.random(1, #lightColors) until prevCurLight ~= curLight

	window.color = {
		lightColors[curLight][1] / 255, lightColors[curLight][2] / 255,
		lightColors[curLight][3] / 255
	}
	window.alpha = 1
end

function postBeat(b) trainobj:beat(b) end
