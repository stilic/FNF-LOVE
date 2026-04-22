function event(params)
	local data, target = params.v
	switch(data.target, {
		[{"boyfriend", "bf", "player"}] = function() target = state.boyfriend end,
		[{"dad", "opponent", "enemy"}] = function() target = state.dad end,
		[{"girlfriend", "gf"}] = function() target = state.gf end
	})
	if target then
		target:playAnim(data.anim, data.force, nil, true)
	end
end
