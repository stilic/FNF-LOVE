local cantUppercut = false
local alternate = false
local holdTimer = 0
local p = "weekend-1-"

local function doAlternate()
	alternate = not alternate
	return alternate and "1" or "2"
end

local function willMissBeLethal(health, healthChange)
	return (health + (healthChange or 0)) <= 0.0
end

local function shouldDoUppercutPrep(judgement, health)
	return (judgement == "bad" or judgement == "shit") and
		   health <= 0.6 and
		   math.random() < 0.3
end

local function play(name, force, z)
	self:playAnim(name, force or false)
	if z then
		self.zIndex = z
		state.stage:refresh()
	end

	if shakeCallback and (string.find(name, "hit") or name == "block") then
		local intensity = name == "block" and 0.0025 or 0.003
		local duration = name == "block" and 0.1 or 0.15
		game.camera.shake(intensity, duration)
	end
end

local function getCurrentAnim()
	return (_animAtlas and _animAtlas.animation or animation).curAnim.name
end

local function handleTaunt()
	play(getCurrentAnim() == "cringe" and "pissed" or "idle", true, 2000)
end

local hitmap = {
	[p .. "punchlow"] = function() play('hitLow', true, 2000) end,
	[p .. "punchlowblocked"] = function() play('block', true, 2000) end,
	[p .. "punchlowdodged"] = function() play('dodge', true, 2000) end,
	[p .. "punchlowspin"] = function() play('hitSpin', true, 2000) end,
	[p .. "punchhigh"] = function() play('hitHigh', true, 2000) end,
	[p .. "punchhighblocked"] = function() play('block', true, 2000) end,
	[p .. "punchhighdodged"] = function() play('dodge', true, 2000) end,
	[p .. "punchhighspin"] = function() play('hitSpin', true, 2000) end,
	[p .. "blockhigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "dodgehigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "hithigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "blockspin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "dodgespin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "hitspin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "blocklow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "dodgelow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "hitlow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "picouppercutprep"] = function() end,
	[p .. "picouppercut"] = function() play('uppercutHit', true, 2000) end,
	[p .. "darnelluppercutprep"] = function() play('uppercutPrep', true, 3000) end,
	[p .. "darnelluppercut"] = function() play('uppercut', true, 3000) end,
	[p .. "idle"] = function() play('idle', false, 2000) end,
	[p .. "fakeout"] = function() play('cringe', true, 2000) end,
	[p .. "taunt"] = handleTaunt,
	[p .. "tauntforce"] = function() play('pissed', true, 2000) end,
	[p .. "reversefakeout"] = function() play('fakeout', true, 2000) end,
}

local missmap = {
	[p .. "punchlow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "punchlowblocked"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "punchlowdodged"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "punchlowspin"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "punchhigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "punchhighblocked"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "punchhighdodged"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "punchhighspin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "blockhigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "blocklow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "blockspin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "dodgehigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "dodgelow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "dodgespin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "hithigh"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "hitlow"] = function() play('punchLow' .. doAlternate(), true, 3000) end,
	[p .. "hitspin"] = function() play('punchHigh' .. doAlternate(), true, 3000) end,
	[p .. "picouppercutprep"] = function()
		play('hitHigh', true, 2000)
		cantUppercut = true
	end,
	[p .. "picouppercut"] = function() play('dodge', true, 2000) end,
	[p .. "idle"] = function() play('idle', false, 2000) end,
	[p .. "fakeout"] = function() play('cringe', true, 2000) end,
	[p .. "taunt"] = handleTaunt,
	[p .. "tauntforce"] = function() play('pissed', true, 2000) end,
	[p .. "reversefakeout"] = function() play('fakeout', true, 2000) end,
}

function postCreate()
	play('idle', true, 2000)
end

function onNoteHit(event)
	lastHit = math.huge
	local type = event.note.type

	if not type:sub(1, 10) == "weekend-1-" then return end

	if shouldDoUppercutPrep(event.rating.name, state.health) then
		play('uppercutPrep', true)
		return
	end

	if cantUppercut then
		play('punchHigh' .. doAlternate(), true)
		cantUppercut = false
		return
	end

	switch(type, hitmap)
	cantUppercut = false
end

function onNoteMiss(event)
	lastHit = math.huge
	local type = event.note.type

	if not type:sub(1, 10) == "weekend-1-" then return end

	local anim = getCurrentAnim()
	if anim == 'uppercutPrep' then
		play('uppercut', true, 3000)
		return
	end

	if willMissBeLethal(state.health, 0.045) then
		play('punchLow' .. doAlternate(), true, 3000)
		return
	end

	if cantUppercut then
		play('punchHigh' .. doAlternate(), true, 3000)
		cantUppercut = false
		return
	end

	switch(type, missmap)
	cantUppercut = false
end

function onMiss(event)
	if willMissBeLethal(state.health, 0) then
		play('punchLow' .. doAlternate(), true, 3000)
	else
		if math.random() < 0.5 then
			play('dodge', true, 2000)
		else
			play('block', true, 2000)
		end
	end
end
