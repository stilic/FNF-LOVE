function event(params)
	local table = type(params.v) == "table"
	local charID = ((table and params.v.char or tonumber(params.v)) or 0) + 1
	local ease = table and params.v.ease or "CLASSIC"
	local x, y = 0, 0

	state.camTarget = nil

	cameraOffset:set(table and -(params.v.x or 0), table and -(params.v.y or 0))

	if notefields[charID] and notefields[charID].character then
		local character = notefields[charID].character
		x, y = getCameraPosition(character)
		state.camTarget = character
	end

	if ease == "CLASSIC" then
		cameraMovement(x, y)
	elseif ease == "INSTANT" then
		cameraMovement(x, y, "linear", 0)
	else
		if table and ease ~= "linear" and params.v.easeDir then
			ease = ease .. params.v.easeDir
		end
		if Ease[ease] == nil then
			Logger.log("warn", "Invalid ease function: " .. ease)
		end
		cameraMovement(x, y, ease, stepCrotchet * params.v.duration / 1000)
	end
end
