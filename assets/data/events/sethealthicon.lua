function postCreate()
	for _, e in pairs(events) do
		if e.e == "SetHealthIcon" then
			paths.getImage("icons/" .. e.v.id)
		end
	end
end

function event(params)
	local icon = params.v.char == 1 and healthBar.iconP2 or healthBar.iconP1
	icon:changeIcon(params.v.id)
end
