local Train = Object:extend("Train")

function Train:new(trainSprite, state)
	self.state = state
	self.train = trainSprite
	self.trainSound = game.sound.load(paths.getSound('gameplay/train_passes'), false)

	self.trainMoving = false
	self.trainFrameTiming = 0
	self.trainCars = 8
	self.trainFinishing = false
	self.trainCooldown = 0
	self.startedMoving = false
end

function Train:update(dt)
	local gf = self.state.gf
	if self.trainMoving then
		self.trainFrameTiming = self.trainFrameTiming + dt
		if self.trainFrameTiming >= 1 / 24 then
			if self.trainSound.time >= 4.5 then
				self.startedMoving = true
				if gf then
					if not gf.anim.curAnim.name:endsWith("-blow") then
						gf:playAnim(gf.anim.curAnim.name .. "-blow", true, math.floor(gf.anim.curAnim.frame))
						gf.idleAnims = {"danceLeft-blow", "danceRight-blow"}
					end
				end
				game.camera:shake(0.001, 1)
				self.state.camHUD:shake(0.001, 1)
			end
			if self.startedMoving then
				self.train.x = self.train.x - 400
				if self.train.x < -2000 and not self.trainFinishing then
					self.train.x = -1150
					self.trainCars = self.trainCars - 1
					if self.trainCars <= 0 then
						self.trainFinishing = true
					end
				end
				if self.train.x < -4000 and self.trainFinishing then
					self.train.x = game.width + 200
					self.trainMoving = false
					self.trainCars = 8
					self.trainFinishing = false
					self.startedMoving = false
				end
			end
			self.trainFrameTiming = 0
		end
	end
end

function Train:beat(b)
	if not self.trainMoving then
		self.trainCooldown = self.trainCooldown + 1
	end
	if b % 8 == 4 and love.math.randomBool(30) and not self.trainMoving and self.trainCooldown > 8 then
		self.trainCooldown = love.math.random(-4, 0)
		self.trainMoving = true
		self.trainSound:stop()
		self.trainSound:play()
	end

	local gf = self.state.gf
	if gf and not self.trainMoving and gf.anim.curAnim.name == "danceLeft-blow" then
		gf:playAnim("hairFall", true)
		gf.idleAnims = {"danceLeft", "danceRight"}
	end
end

return Train
