local tweenTable = {}

function event(data)
	data = data.v

	local duration = data.duration or 4
	local ease = data.ease or "linear"
	local notefield = data.strumline or "both"
	local abs = data.absolute == true
	local scroll = (tonumber(data.scroll) or 1) * (abs and 1 or PlayState.SONG.speed)
	local notefields

	switch(notefield, {
		["both"] = function() notefields = state.notefields end,
		["player"] = function() notefields = {playerNotefield} end,
		["opponent"] = function() notefields = {enemyNotefield} end,
		default = function()
			print("[SCROLLSPEED EVENT] " .. notefield .. " strumline not supported in FNF-LÖVE")
		end
	})

	for _, nf in pairs(notefields) do
		local idx = table.find(tweenTable, nf)
		if idx then
			local tween = tweenTable[idx]
			tween:destroy()
			table.remove(tweenTable, idx)
		end
	end

	if ease == "INSTANT" then
		for _, nf in pairs(notefields) do
			if nf.is then nf.speed = scroll end
		end
	else
		local dur = (conductor.stepCrotchet * duration) / 1000
		local daEase = Ease[ease]

		if daEase == nil then
			print("[SCROLLSPEED EVENT] Invalid ease function: " .. ease)
			return
		end

		for _, nf in pairs(notefields) do
			if nf.is then
				local tw
				tw = tween:tween(nf, {speed = scroll}, dur, {
					ease = daEase,
					onComplete = function()
						table.delete(tweenTable, tw)
					end
				})

				table.insert(tweenTable, tw)
			end
		end
	end
end
