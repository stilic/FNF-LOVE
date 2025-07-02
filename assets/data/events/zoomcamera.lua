local camZoomTween
local function cameraZoom(zoom, dur, direct, ease)
	if camZoomTween then camZoomTween:destroy() end

	local target = zoom * (direct and 1 or stage.camZoom)

	if dur == 0 then
		camZoom = target
		camZoomTween = nil
	else
		camZoomTween = tween:tween(state, {camZoom = target}, dur, {
			ease = ease,
			onComplete = function() camZoomTween = nil end
		})
	end
end

function event(data)
	if game.camera.pixelPerfect then
		return
	end

	data = data.v
	local zoom = data.zoom or 1
	local duration = data.duration or 4
	local mode = data.mode or "direct"
	local direct = (mode == "direct")
	local ease = data.ease or "linear"

	if ease == "INSTANT" then
		cameraZoom(zoom, 0, direct)
	else
		local dur = conductor.stepCrotchet * duration / 1000
		local daEase = Ease[ease]

		if daEase == nil then
			print("[CAMERAZOOM EVENT] Invalid ease function: " .. ease)
			return
		end

		cameraZoom(zoom, dur, direct, daEase)
	end
end
