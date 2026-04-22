function create()
	state.camHUD.visible, state.camNotes.visible = false, false

	state.camFollow:set(400, -2050)
	game.camera:snapToTarget()

	util.playSfx(paths.getSound('gameplay/Lights_Turn_On'))
	pushEvent("zoomcamera", {zoom = 1.2, ease = "INSTANT"})

	local blackScreen = Graphic(0, 0,
		math.floor(game.width * 2), math.floor(game.height * 2), Color.BLACK)
	blackScreen:setScrollFactor()
	state:add(blackScreen)

	state.tween:tween(blackScreen, {alpha = 0}, 0.7, {
		onComplete = function()
			state:remove(blackScreen)
		end
	})

	Timer.wait(1, function()
		pushEvent("zoomcamera", {zoom = 1, ease = "quadInOut", duration = 16})
		state.camHUD.visible, state.camNotes.visible = true, true
		Timer.wait(1.2, close)
	end)
end
