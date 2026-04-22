local Judgements = SpriteGroup:extend("Judgements")
Judgements.area = {width = 328, height = 134}

local numCache = {}
for i = 0, 9 do numCache[tostring(i)] = "num" .. i end
numCache["-"] = "numnegative"

function Judgements:new(x, y, skin)
	Judgements.super.new(self, x, y)

	self.ratingVisible = true
	self.comboNumVisible = true

	self.skin = skin
	self.antialiasing = not skin.isPixel

	self.noStack = false
	self.state = game.getState()
end

function Judgements:createSprite(name, scale, duration)
	local sprite = self:recycle()
	sprite:loadTexture(PlayState.SONG.skin:get(name, "image"))
	sprite:setGraphicSize(math.floor(sprite.width * scale))
	sprite.x, sprite.y = 0, 0
	sprite:updateHitbox()
	sprite.alpha = 1
	sprite.antialiasing = antialias

	sprite.moves = true
	sprite.velocity:zero()
	sprite.acceleration.y = 0
	sprite.antialiasing = self.antialiasing

	self.state.tween:cancelTweensOf(sprite)
	if sprite.tween then sprite.tween:cancel() end
	sprite.tween = self.state.tween:tween(sprite, {alpha = 0}, 0.2, {
		onComplete = function() sprite:kill() end,
		startDelay = duration
	})
	return sprite
end

function Judgements:spawn(rating, combo)
	if not self.visible or not self.exists then return end

	local accel = PlayState.conductor.crotchet * 0.001
	if self.noStack or ClientPrefs.data.lowQuality then
		for i = 1, #self.members do
			self.members[i]:kill()
		end
	end

	local pixelPerfect = self.cameras[1].pixelPerfect
	if rating and self.ratingVisible then
		local scale = pixelPerfect and 1 or (self.antialiasing and 0.65 or 4.2)
		local areaHeight = self.area.height / 2
		local ratingSpr = self:createSprite(rating, scale, accel)
		ratingSpr.x = (self.area.width - ratingSpr.width) / 2
		ratingSpr.y = (self.area.height - ratingSpr.height) / 2 - self.area.height / 3
		ratingSpr.acceleration.y = 550
		ratingSpr.velocity.y = ratingSpr.velocity.y - love.math.random(140, 175)
		ratingSpr.velocity.x = ratingSpr.velocity.x - love.math.random(0, 10)
		if pixelPerfect then
			ratingSpr.acceleration.y = ratingSpr.acceleration.y / 4
			ratingSpr.velocity:set(ratingSpr.velocity.x / 4, ratingSpr.velocity.y / 4)
		end
		ratingSpr.visible = self.ratingVisible
	end

	if combo and self.comboNumVisible and (combo > 9 or combo < 0) then
		combo = string.format(combo < 0 and "-%03d" or "%03d", math.abs(combo))
		local l, x, char, comboNum = #combo, 38
		local scale = pixelPerfect and 1 or (self.antialiasing and 0.45 or 4.2)
		for i = 1, l do
			char = combo:sub(i, i)
			comboNum = self:createSprite(numCache[char], scale, accel * 2)
			x, comboNum.x, comboNum.y = x + comboNum.width - (pixelPerfect and 1 or 8),
				x, self.area.height - comboNum.height
			comboNum.acceleration.y, comboNum.velocity.x, comboNum.velocity.y = love.math.random(200, 300),
				love.math.random(-5.0, 5.0), comboNum.velocity.y - love.math.random(140, 160)
			if pixelPerfect then
				comboNum.acceleration.y = comboNum.acceleration.y / 4
				comboNum.velocity:set(comboNum.velocity.x / 4, comboNum.velocity.y / 4)
			end
		end
	end
end

function Judgements:screenCenter()
	self.x, self.y = (game.width - self.area.width) / 2,
		(game.height - self.area.height) / 2
	return self
end

return Judgements
