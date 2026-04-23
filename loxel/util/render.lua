local RenderUtil = {}

function RenderUtil.init()
	if love._version_major < 12 then
		love.graphics.setBlendState = function() end
	end

	local newImage = love.graphics.newImage
	love.graphics.newImage = function(source, settings, skipAll)
		settings = table.clone(settings)
		local isFullQuality = false
		if type(settings) == "table" then
			isFullQuality = settings.fullQuality
			settings.fullQuality = nil
		end

		return newImage(source, settings)
	end
end

return RenderUtil
