local MediaCard = Graphic:extend("MediaCard")

function MediaCard:new(x, y, icon, text, color)
	MediaCard.super.new(self, x, y)

	self.icon = icon
	self.text = text

	self.color = color or {0.5, 0.5, 0.5}
	self.config.round = {16, 16}
	self.lined = false
	self.line.color = {0.8, 0.7, 0.8}
	self.time = 0
end

function MediaCard:setSize(width, height)
	self.width, self.height = width, height

	self.icon.x, self.icon.y = self.x + 10,
		self.y + (self.height - self.icon.height) / 2

	self.text.x, self.text.y = self.icon.x + self.icon.width + 10,
		self.y + (self.height - self.text.height) / 2
	self.text.limit = (self.width - self.icon.width) - 30
end

function MediaCard:update(dt)
	MediaCard.super.update(self, dt)
	self.icon:update(dt)
	self.text:update(dt)

	self.time = self.time + dt * 3
	self.line.width = 2 * math.sin(self.time) / 2
end

function MediaCard:__render(camera)
	MediaCard.super.__render(self, camera)

	self.icon.scrollFactor = self.scrollFactor
	self.text.scrollFactor = self.scrollFactor
	self.icon:__render(camera)
	self.text:__render(camera)
end

function MediaCard:setFocus(focus)
	self.lined = focus
	self.alpha = focus and 0.7 or 0.4
end

return MediaCard
