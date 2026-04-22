local LightSprite = ActorSprite:extend("LightSprite")

function LightSprite:new(x, y, sx, sy, radius, color)
	LightSprite.super.new(self, x, y, 0)

	self.width = (radius * 2) * (sx or 1)
	self.height = (radius * 2) * (sy or 1)
	self.origin:set(0.5, 0.5)

	local segments = 50
	self.vertices = {}
	table.insert(self.vertices, {0.5, 0.5, 0, 0.5, 0.5, 255, 255, 255, 255})
	for i = 0, segments do
		local angle = (i / segments) * math.pi * 2
		local lx = 0.5 + math.cos(angle) * 0.5
		local ly = 0.5 + math.sin(angle) * 0.5
		table.insert(self.vertices, {lx, ly, 0, lx, ly, 255, 255, 255, 0})
	end

	self.mesh = love.graphics.newMesh(ActorSprite.vertexFormat, #self.vertices, "fan")
	local img = love.image.newImageData(1, 1)
	img:setPixel(0, 0, 1, 1, 1, 1)
	self.texture = love.graphics.newImage(img, nil, true)
	img:release()
	self.color = color
end

function LightSprite:destroy()
	self.texture:release()
	LightSprite.super.destroy(self)
end

function LightSprite:getDrawMode() return "fan" end

return LightSprite
