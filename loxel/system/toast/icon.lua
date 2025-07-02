local Icon = {}

function Icon.make(size, color, type)
	local canvas = love.graphics.newCanvas(size, size, {msaa = 8})
	canvas:renderTo(function()
		love.graphics.push("all")
		local x, y = size / 2, size / 2

		local vertices, sides = {}, 8
		local angleOffset = (format == "tri") and -math.pi / 2 or math.pi / sides

		for i = 1, sides do
			local angle = (i - 1) * (2 * math.pi / sides) + angleOffset
			local radius = (size * 0.5)

			vertices[2 * i - 1] = x + radius * math.fastcos(angle)
			vertices[2 * i] = y + radius * math.fastsin(angle)
		end

		local r, g, b = 0.9, 0.2, 0.2
		if color == "yellow" then
			r, g, b = 1, 0.7, 0.1
		end

		love.graphics.setColor(r, g, b)
		love.graphics.polygon("line", vertices)

		love.graphics.setColor(1, 1, 1)
		if type == "error" then
			love.graphics.setColor(1, 1, 1)
			local exLine = {
				x - size * 0.06, y - size * 0.25,
				x + size * 0.06, y - size * 0.25,
				x + size * 0.03, y + size * 0.1,
				x - size * 0.03, y + size * 0.1
			}
			love.graphics.polygon("fill", exLine)
			love.graphics.circle("fill", x, y + size * 0.25, size * 0.06)
		elseif type == "script" then
			local symbolHeight = size * 0.31
			local symbolWidth = size * 0.34
			local symbolX = x - symbolWidth / 2
			local symbolY = y
			love.graphics.setLineWidth(2)

			love.graphics.line(
				symbolX, symbolY - symbolHeight/2,
				symbolX - symbolWidth/5, symbolY,
				symbolX, symbolY + symbolHeight/2
			)

			love.graphics.line(
				symbolX + symbolWidth, symbolY - symbolHeight/2,
				symbolX + symbolWidth + symbolWidth/5, symbolY,
				symbolX + symbolWidth, symbolY + symbolHeight/2
			)

			love.graphics.line(
				symbolX + symbolWidth * 0.6, symbolY - symbolHeight/2,
				symbolX + symbolWidth * 0.4, symbolY + symbolHeight/2
			)
		end
		love.graphics.pop()
	end)

	local data = canvas:newImageData()
	local image = love.graphics.newImage(data)
	canvas:release(); data:release()
	return image
end

return Icon