local HealthBar = SpriteGroup:extend("HealthBar")

function HealthBar:new(p1, p2, skin)
	HealthBar.super.new(self, 0, 0)

	self.maxHealth = 2

	self.bg = Sprite():loadTexture(skin:get("healthBar"))
	self.bg:updateHitbox()

	self.bar = Bar(self.bg.x + 4, self.bg.y + 4,
		math.floor(self.bg.width - 8),
		math.floor(self.bg.height - 8), 0, self.maxHealth, true)

	self:add(self.bg)
	self:add(self.bar)

	local healthPercent = self.bar.percent
	self.iconP1, self.iconP2, self.iconScale =
		HealthIcon(p1, true, healthPercent),
		HealthIcon(p2, false, healthPercent),
		1

	local y = self.bar.y
	self.iconP1.y = y - self.iconP1.height / 2
	self.iconP2.y = y - self.iconP2.height / 2

	self.bar.color = Color.fromHEX(0xFF66FF33)
	self.bar.color.bg = Color.fromHEX(0xFFFF0000)

	self:add(self.iconP1)
	self:add(self.iconP2)

	self.value = 1
	self.bar:setValue(1)
end

local iconOffset = 26
function HealthBar:update(dt)
	HealthBar.super.update(self, dt)
	self.bar:setValue(self.value)
	local swap, percent = self.bar.flipX, self.bar.percent
	local lerpValue, healthPercent, y =
		util.coolLerp(self.iconScale, 1, 15, dt),
		swap and 50 - percent + 50 or percent,
		self.bar.y - 75
	local p1, p2 = swap and self.iconP2 or self.iconP1,
		swap and self.iconP1 or self.iconP2
	self.iconScale, p1.health, p2.health = lerpValue, percent, percent
	p1:setScale(lerpValue)
	p2:setScale(lerpValue)
	p1.x = self.bar.x + self.bar.width *
		(math.remapToRange(healthPercent, 0, 100, 100,
			0) * 0.01) + (150 * p1.scale.x - 150) / 2 - iconOffset
	p2.x = self.bar.x + (self.bar.width *
		(math.remapToRange(healthPercent, 0, 100, 100,
			0) * 0.01)) - (150 * p2.scale.x) / 2 - iconOffset * 2
	p1.y, p2.y = y, y
end

function HealthBar:__render(camera)
	local swap, p1, p2 = self.bar.flipX, self.iconP1, self.iconP2
	if swap then
		p1.flipX = not p1.flipX
		p2.flipX = not p2.flipX
	end
	HealthBar.super.__render(self, camera)
	if swap then
		p1.flipX = not p1.flipX
		p2.flipX = not p2.flipX
	end
end

function HealthBar:screenCenter(axes)
	if axes == nil then axes = "xy" end
	if axes:find("x") then self.x = (game.width - self.bg.width) / 2 end
	if axes:find("y") then self.y = (game.height - self.bg.height) / 2 end
	return self
end

function HealthBar:getWidth()
	return self.bg.width
end

function HealthBar:getHeight()
	return self.bg.height
end

return HealthBar
