local vslice = {name = "VSlice"}

function vslice.parse(data, name)
	local char = Parser.getDummyChar()

	Parser.pset(char, "sing_duration", data.singTime)
	Parser.pset(char, "flip_x", data.flipX)
	Parser.pset(char, "sprite", data.assetPath:gsub("shared:", ""))
	Parser.pset(char, "antialiasing", not data.isPixel)
	Parser.pset(char, "scale", data.scale)
	if data.offsets then
		Parser.pset(char, "position", data.offsets)
	end
	if data.cameraOffsets then
		Parser.pset(char, "camera_points", data.cameraOffsets)
	end

	char.voice_suffix = name:gsub("-[^-]*$", "")

	local healthIconId = data.healthIcon and data.healthIcon.id or name
	local isPixel = data.healthIcon and data.healthIcon.isPixel or false
	local should = isPixel and not healthIconId:endsWith("-pixel")
	Parser.pset(char, "icon", healthIconId .. (should and "-pixel" or ""))

	for _, anim in pairs(data.animations) do
		local name = '' .. anim.name
		if name:endsWith("-hold") then
			name = name:gsub("-hold", "-loop")
		end

		local actualAnim = {
			name,
			(anim.prefix or ''),
			anim.frameIndices or {},
			anim.fps or 24,
			anim.looped == true,
			anim.offsets or {0, 0},
			anim.assetPath
		}
		actualAnim[6][1] = actualAnim[6][1] * char.scale
		actualAnim[6][2] = actualAnim[6][2] * char.scale

		if not actualAnim[2]:endsWith("0") and data.renderType ~= "animateatlas" then
			actualAnim[2] = actualAnim[2] .. "0"
		end

		table.insert(char.animations, actualAnim)
	end

	return char
end

return vslice
