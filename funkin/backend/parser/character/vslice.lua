local vslice = {name = "VSlice"}

function vslice.parse(data, name)
	local char = Parser.getDummyChar()

	Parser.pset(char, "sing_duration", data.singTime)
	Parser.pset(char, "flip_x", data.flipX)
	Parser.pset(char, "sprite", data.assetPath:gsub("shared:", ""))

	char.voice_suffix = name:gsub("-[^-]*$", "")

	local healthIconId = data.healthIcon and data.healthIcon.id or name
	local isPixel = data.healthIcon and data.healthIcon.isPixel or false
	Parser.pset(char, "icon", healthIconId .. (isPixel and "-pixel" or ""))

	for _, anim in pairs(data.animations) do
		local name = '' .. anim.name
		if name:endsWith("-hold") then
			name = name:gsub("-hold", "-loop")
		end

		actualAnim = {
			name,
			(anim.prefix or '') .. ((data.renderType == "animateatlas" or
				(anim.prefix or ""):endsWith("0")) and "" or "0"),
			anim.frameIndices or {},
			anim.fps or 24,
			anim.looped == true,
			anim.offsets or {0, 0},
			anim.assetPath
		}

		table.insert(char.animations, actualAnim)
	end

	return char
end

return vslice
