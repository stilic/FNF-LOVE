local Traffic = Basic:extend("Traffic")

function Traffic:new(car1, car2, traffic)
	Traffic.super.new(self)
	self.car1 = car1
	self.car2 = car2
	self.traffic = traffic
	self.tween = game.getState().tween

	self.lightsStop = false
	self.carWaiting = false
	self.lastChange = 0
	self.changeInterval = 8
	self.stopCar = true
	self.stopCar2 = true

	self.paths = {
		{
			Point(1950 - 306.6 - 80, 980 - 168.3 + 15),
			Point(2400 - 306.6, 980 - 168.3 - 50),
			Point(3102 - 306.6, 1127 - 168.3 + 40)
		},
		{
			Point(1500 - 306.6 - 20, 1049 - 168.3 - 20),
			Point(1770 - 306.6 - 80, 994 - 168.3 + 10),
			Point(1950 - 306.6 - 80, 980 - 168.3 + 15)
		},
		{
			Point(1570 - 306.6, 1049 - 168.3 - 30),
			Point(2400 - 306.6, 980 - 168.3 - 50),
			Point(3102 - 306.6, 1127 - 168.3 + 40)
		},
		{
			Point(3102 - 306.6, 1127 - 168.3 + 60),
			Point(2400 - 306.6, 980 - 168.3 - 30),
			Point(1570 - 306.6, 1049 - 168.3 - 10)
		}
	}
end

function Traffic:finishCarLights(sprite)
	self.carWaiting = false

	local duration = math.random(18, 30) / 10
	local startdelay = math.random(2, 12) / 10

	sprite.angle = -5
	self.tween:tween(sprite, {angle = 18}, duration, {ease = Ease.sineIn, startDelay = startdelay})
	self.tween:quadPath(sprite, self.paths[1], duration, true, {
		ease = Ease.sineIn,
		startDelay = startdelay,
		onComplete = function() self.stopCar = true end
	})
end

function Traffic:driveCarLights(sprite)
	self.stopCar = false
	self.tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)
	local extraOffset = {0, 0}
	local durations = {
		math.random(10, 17) / 10,
		math.random(9, 15) / 10,
		math.random(15, 25) / 10,
		math.random(15, 25) / 10
	}
	local offsets = {{0, 0}, {20, -15}, {30, 50}, {10, 60}}

	extraOffset = offsets[variant]
	local duration = durations[variant]

	sprite.offset:set(extraOffset[1], extraOffset[2])
	sprite.angle = -7
	self.tween:tween(sprite, {angle = -5}, duration, {ease = Ease.cubeOut})
	self.tween:quadPath(sprite, self.paths[2], duration, true, {
		ease = Ease.cubeOut,
		onComplete = function()
			self.carWaiting = true
			if not self.lightsStop then self:finishCarLights(self.car1) end
		end
	})
end

function Traffic:driveCar(sprite)
	self.stopCar = false
	self.tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)

	local durations = {
		math.random(10, 17) / 10,
		math.random(6, 12) / 10,
		math.random(15, 25) / 10,
		math.random(15, 25) / 10
	}
	local offsets = {{0, 0}, {20, -15}, {30, 50}, {10, 60}}

	local extraOffset = offsets[variant]
	local duration = durations[variant]

	sprite.offset:set(extraOffset[1], extraOffset[2])
	sprite.angle = -8
	self.tween:tween(sprite, {angle = 18}, duration)
	self.tween:quadPath(sprite, self.paths[3], duration, true, {
		onComplete = function() self.stopCar = true end
	})
end

function Traffic:driveCarBack(sprite)
	self.stopCar2 = false
	self.tween:cancelTweensOf(sprite)
	local variant = math.random(1, 4)
	sprite.animation:play('car' .. variant)

	local durations = {
		math.random(10, 17) / 10,
		math.random(6, 12) / 10,
		math.random(15, 25) / 10,
		math.random(15, 25) / 10
	}
	local offsets = {{0, 0}, {20, -15}, {30, 50}, {10, 60}}

	local extraOffset = offsets[variant]
	local duration = durations[variant]

	sprite.offset:set(extraOffset[1], extraOffset[2])
	sprite.angle = 18
	self.tween:tween(sprite, {angle = -8}, duration)
	self.tween:quadPath(sprite, self.paths[4], duration, true, {
		onComplete = function() self.stopCar2 = true end
	})
end

function Traffic:beat(b)
	if love.math.randomBool(10) and b ~= (self.lastChange + self.changeInterval) and self.stopCar then
		(self.lightsStop and self.driveCarLights or self.driveCar)(self, self.car1)
	end
	if love.math.randomBool(10) and b ~= (self.lastChange + self.changeInterval) and self.stopCar2 and not self.lightsStop then
		self:driveCarBack(self.car2)
	end

	if b == (self.lastChange + self.changeInterval) then
		self.lastChange = b
		self.lightsStop = not self.lightsStop
		self.traffic.animation:play(self.lightsStop and 'tored' or 'togreen')
		self.changeInterval = self.lightsStop and 20 or 30

		if not self.lightsStop and self.carWaiting then
			self:finishCarLights(self.car1)
		end
	end
end

return Traffic
