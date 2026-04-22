local vslice = {name = "VSlice"}

function vslice.parse(data)
	local stage = Parser.getDummyStage()

	for _, o in ipairs(data.props) do
		local obj = {
			name           = o.name,
			x              = o.position and o.position[1] or 0,
			y              = o.position and o.position[2] or 0,
			zIndex         = o.zIndex or 0,
			scaleX         = o.scale and o.scale[1] or 1,
			scaleY         = o.scale and o.scale[2] or 1,
			scrollX        = o.scroll and o.scroll[1] or 1,
			scrollY        = o.scroll and o.scroll[2] or 1,
			flipX          = o.flipX or false,
			flipY          = o.flipY or false,
			type           = (o.assetPath and o.assetPath:startsWith("#")) and "graphic" or "image",
			assetPath      = o.assetPath,
			startAnimation = o.startingAnimation,
			isPixel        = o.isPixel == true,
			alpha          = o.alpha or 1,
			danceSpeed     = o.danceEvery or 0,
			animations     = {}
		}

		if obj.type == "image" and o.animations and #o.animations > 0 then
			for _, a in pairs(o.animations) do
				local animData = {
					name      = a.name,
					frameRate = a.frameRate or 24,
					looped    = a.looped or false,
					offsets   = a.offsets
				}

				if a.frameIndices and not a.prefix then
					animData.func = "add"
					animData.indices = a.frameIndices
				elseif a.frameIndices then
					animData.func = "addByIndices"
					animData.prefix = a.prefix or ""
					animData.indices = a.frameIndices
				else
					animData.func = "addByPrefix"
					animData.prefix = a.prefix or ""
				end

				table.insert(obj.animations, animData)
			end
		end

		table.insert(stage.objects, obj)
	end

	for c, cd in pairs(data.characters) do
		char = stage.characters[c == "bf" and "boyfriend" or c]
		if cd.position then char.x, char.y = cd.position[1] or 0, cd.position[2] or 0 end
		if cd.scroll then char.scroll.x, char.scroll.y = cd.scroll[1] or 0, cd.scroll[2] or 0 end
		if cd.scale then char.scale.x, char.scale.y = cd.scale, cd.scale end
		if cd.cameraOffsets then
			char.cameraOffset.x, char.cameraOffset.y = cd.cameraOffsets[1] or 0, cd.cameraOffsets[2] or 0
		end
		char.z = cd.zIndex or char.z
	end
	stage.zoom = data.cameraZoom or 1

	return stage
end

return vslice
