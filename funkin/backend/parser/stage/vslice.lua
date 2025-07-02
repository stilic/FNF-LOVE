local vslice = {name = "VSlice"}

function vslice.parse(data)
	local stage = Parser.getDummyStage()

	Parser.pset(stage, "name", data.name)
	Parser.pset(stage, "cameraZoom", data.cameraZoom)
	Parser.pset(stage, "props", data.props)
	Parser.pset(stage, "characters", data.characters)
	Parser.pset(stage, "version", data.version)

	return stage
end

return vslice
