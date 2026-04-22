local LoadScreen = SpriteGroup:extend("LoadScreen")

function LoadScreen:new(nextState)
	LoadScreen.super.new(self)

	local px, py = game.width - 80, game.height - 80
	self.icon = Sprite(0, 0, paths.getImage("menus/loadicon"))
	self.icon:setGraphicSize(self.icon.width * 0.65)
	self.icon:updateHitbox()
	self.icon:setPosition(px - self.icon.width / 2, py - self.icon.height / 2)
	self:add(self.icon)

	local size = math.max(self.icon.width, self.icon.height) + 40
	self.arc = Graphic(0, 0, size, size, Color.WHITE, "arc", "line")
	self.arc:center(self.icon)
	self.arc.line.width = 12
	self.arc.config.segments = 64
	self:add(self.arc)

	self.percent = Text(20, 680, "0%", paths.getFont("vcr.ttf", 16), Color.BLACK)
	self.percent:center(self.icon)
	self.percent.antialiasing = false
	self:add(self.percent)

	self.progress = 0
	self.time = 0

	if nextState.preload then nextState:preload() end
	self.nextState = nextState
end

function LoadScreen:update(dt)
	local progress = paths.async.getProgress()
	self.progress = util.coolLerp(self.progress, progress, 34, dt)
	self.time = self.time + dt

	self.arc.config.angle[2] = self.progress * 360
	self.percent.content = math.ceil(self.progress * 100) .. "%"
	self.percent:center(self.icon)

	local amount = math.sin(self.time * 2)
	local min = 0.01
	local scale = min + (1 - min) * math.abs(amount)
	self.icon.scale.x = scale * (amount >= 0 and 1 or -1) * 0.65

	LoadScreen.super.update(self, dt)
end

return LoadScreen
