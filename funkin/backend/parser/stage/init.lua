local f = "funkin.backend.parser.stage."

local vslice = require(f..'vslice')

local StageParse = {}

function StageParse.get(stage)
	return paths.getJSON('data/stages/' .. stage)
end

function StageParse.getParser(data)
	if data.version ~= nil then
		return vslice
	end
	return false
end

return StageParse
