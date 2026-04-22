local RimEffect = require "shaders.rim"
local ABot = require "abot"

local lowHealth, raisedKnife, loweredKnife = false, false, true
local minBlink, maxBlink = 3, 7
local blinkTimer = minBlink
local abotEffects = {}

function create()
	abot = ABot(0, 0, "pixel")
	self.abot = abot
end

function postCreate()
	setPosition(x - 50, y - 150)
	abot:setPosition(x + 296, y + 430)
	state.stage:insert(state.stage:indexOf(self), abot)

	if not state.stage.name:endsWith("erect") then return end
	local maskPath = "stages/school-erect/masks/aBotPixelSpeaker_mask"

	if abot.speaker then
		local fxSpeaker = RimEffect(abot.speaker)
		fxSpeaker:setMask(maskPath, 0, true, true)
		fxSpeaker:setRimProperty(1, 5, 1)
		table.insert(abotEffects, fxSpeaker)
	end
	local fxBody = RimEffect()
	fxBody:setMask(nil, 10, true, true)
	fxBody:setRimProperty(0, 0, 10)
	table.insert(abotEffects, fxBody)

	for _, part in pairs({abot.abot, abot.head, abot.back}) do
		part.shader = fxBody.shader:get()
	end
end

function onEvent(e)
	if not abot then return end
	if e.e == "FocusCamera" then
		local n = _G.type(e.v) == "table" and e.v.char or tonumber(e.v)
		abot:setEyeDirection(n)
	end
end

function postUpdate(dt)
	if not abot then return end

	abot.visible = self.visible
	abot.alpha = self.alpha

	local threshold = 0.5
	if state.health <= threshold and not raisedKnife then
		playAnim("raiseKnife", true)
		if abot.abot then abot.abot.animation:play("danceLeft", true) end
		lowHealth, raisedKnife, loweredKnife = true, true, false

	elseif state.health > threshold and not loweredKnife then
		playAnim("lowerKnife", true)
		if abot.abot then abot.abot.animation:play("lowerKnife", true) end
		lowHealth, raisedKnife, loweredKnife = false, false, true
		self.danced = true
	end
end

function beat()
	if not abot then return end
	if abot.speaker then abot.speaker.animation:play("danceLeft", true) end
	if abot.abot then abot.abot.animation:play("danceLeft", true) end

	if raisedKnife then
		blinkTimer = blinkTimer - 1
		if blinkTimer <= 0 then
			playAnim("idleKnifeBlink", false)
			blinkTimer = math.random(minBlink, maxBlink)
		end
	end
end

function onAnimFinish(name)
	if name == "raiseKnife" then playAnim("idleKnife", true)
	elseif name == "lowerKnife" then loweredKnife = true; dance()
	elseif name == "idleKnifeBlink" then playAnim("idleKnife", true) end
end

function onPlayAnim(anim)
	if lowHealth and anim ~= "idleKnifeBlink" and anim ~= "idleKnife" then return Event_Cancel end
end

function draw()
	if not abot then return end
	abot.color = self.color
	for _, fx in pairs(abotEffects) do fx:update() end
end
