local SpriteButton = Sprite:extend("SpriteButton")

function SpriteButton:new(x, y, key, texture)
	SpriteButton.super.new(self, x, y)
	if type(texture) == "table" then
		self:setFrames(texture)
	else
		self:setTexture(texture)
	end

	self.button = VirtualPad(key, x, y, 150, 150)
	self.button.visible = false
	self.button:enter()
end

function SpriteButton:onPress() end

function SpriteButton:onRelease() end

function SpriteButton:destroy()
	SpriteButton.super.destroy(self)
	self.button:leave()
	self.button:destroy()
end

return SpriteButton
