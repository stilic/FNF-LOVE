local TankmanSprite = Sprite:extend("TankmanSprite")

function TankmanSprite:new()
	TankmanSprite.super.new(self)

	self.endingOffset = 0
	self.runSpeed = 0
	self.time = 0
	self.right = false

	self:setFrames(paths.getSparrowAtlas("stages/tank/tankmanKilled1"))
	self.animation:addByPrefix("run", "tankman running", 24, true)
	self.animation:addByPrefix("shot", "John Shot " .. math.random(1, 2), 24, false)
	self.animation:get("shot").offset:set(300, 200)

	self:initAnim()

	self:setGraphicSize(math.floor(self.width * 0.4))
	self:updateHitbox()

	self.tankmanFlicker = nil
end

function TankmanSprite:initAnim()
	self.animation:play("run")
	self.animation.curAnim.frame = math.random(1, #self.animation.curAnim.frames)
	self.tankmanFlicker = nil
end

function TankmanSprite:revive()
	TankmanSprite.super.revive(self)
	self:initAnim()
end

function TankmanSprite:update(dt)
	TankmanSprite.super.update(self, dt)

	local anim = self.animation
	if anim.curAnim.name == "shot" and anim.curAnim.frame >= 10 and not self.tankmanFlicker then
		self.tankmanFlicker = true
		Timer():start(1, function() self:kill() end)
	end

	if PlayState.conductor.time >= self.time and anim.curAnim.name == "run" then
		self:play("shot")
	end

	if anim.curAnim.name == "run" then
		local base = self.right and game.width * 0.74 + self.endingOffset or
			game.width * 0.02 - self.endingOffset
		local cond = (PlayState.conductor.time - self.time) * self.runSpeed
		self.x = base + cond * (self.right and -1 or 1)
	end
end

local TankmenGroup = Group:extend("TankmenGroup")

function TankmenGroup:new()
	TankmenGroup.super.new(self)
	paths.getSparrowAtlas("stages/tank/tankmanKilled1") -- cache shit

	self.times = {}
	self.dirs = {}

	local animChart = Parser.getChart("stress", "picospeaker")
	if not animChart then
		return
	end

	for k, v in ipairs(animChart.notes.player) do table.insert(animChart.notes.enemy, v) end
	table.sort(animChart.notes.enemy, function(a, b) return a.t < b.t end)

	for _, note in ipairs(animChart.notes.enemy) do
		if love.math.randomBool(7) then
			table.insert(self.times, note.t)
			local isRight = note.d ~= 3
			table.insert(self.dirs, isRight)
		end
	end
end

function TankmenGroup:recycle(x, y, time, right)
	local tankman = TankmenGroup.super.recycle(self, TankmanSprite)

	tankman.x, tankman.y = x, y
	tankman.flipX = not right

	tankman.time = time
	tankman.endingOffset = math.random() + math.random(50, 200)
	tankman.runSpeed = math.random() + math.random(0.6, 1)
	tankman.right = right
end

function TankmenGroup:update(dt)
	TankmenGroup.super.update(self, dt)

	while true do
		local cutoff = PlayState.conductor.time + 3000
		if #self.times > 0 and self.times[1] <= cutoff then
			local time = table.remove(self.times, 1)
			local right = table.remove(self.dirs, 1)
			local x, y = 500, 200 + math.random(50, 100)
			self:recycle(x, y, time, right)
		else
			break
		end
	end
end

return TankmenGroup
