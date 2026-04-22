local Character = Sprite:extend("Character")

Character.directions = {"left", "down", "up", "right"}
Character.editorMode = false

function Character:new(x, y, char, isPlayer)
	Character.super.new(self, x, y)

	if not Character.editorMode then
		self.script = Script("data/characters/" .. char, false)
		self.script:linkObject(self)
		self.script:set("self", self)
		self.script:call("create")
	end

	self.char = char or "bf"
	self.isPlayer = isPlayer == true
	self.__reverseDraw = false

	local data, type = Parser.getCharacter(self.char)
	self.data = data

	local fullpath = paths.getPath('images/' .. data.sprite)
	if paths.exists(fullpath, "directory") and paths.exists(fullpath .. "/Animation.json", "file") then
		self._animAtlas = AnimateAtlas(0, 0, paths.getAnimateAtlas(data.sprite))
	elseif paths.exists(paths.getPath('images/' .. data.sprite .. ".xml", "file"))
			or paths.exists(paths.getPath('images/' .. data.sprite .. ".txt", "file")) then
		self:setFrames(paths.getAtlas(data.sprite, not data.antialiasing))
	else
		Logger.log("error", "Character \"" .. char .. "\" has invalid image path: \"" .. fullpath .. "\"")
		self.exists = false
	end

	self.anim = self._animAtlas and self._animAtlas.animation or self.animation

	if data.scale and data.scale ~= 1 then
		self:setGraphicSize(math.floor(self.width * data.scale))
		self.scale:set(data.scale, data.scale)
	end

	self.icon = data.icon or char
	self.iconColor = data.color

	self.flipX = data.flip_x == true
	self.antialiasing = ClientPrefs.data.antialiasing and data.antialiasing ~= false
	self.voiceSuffix = data.voice_suffix or char

	local atlasAdded = {}
	if data.animations and #data.animations > 0 then
		for _, an in pairs(data.animations) do
			local anim, name, indices, fps, loop, offset, atlas = unpack(an)

			if not self._animAtlas and atlas and atlas ~= "" and not atlasAdded[atlas] and
					(paths.exists(atlas .. ".xml", "file") or paths.exists(atlas .. ".txt", "file")) then
				self.frames:addCollection(paths.getAtlas(atlas))
				atlasAdded[atlas] = true
			end

			if indices ~= nil and #indices > 0 then
				if not self._animAtlas then
					self.anim:addByIndices(anim, name, indices, nil, fps, loop)
				else
					local success = self.anim:addFromLibraryIndices(anim, name, "", indices, fps, loop)
					if not success then self.anim:addByIndices(anim, name, indices, fps, loop) end
				end
			else
				if not self._animAtlas then
					self.anim:addByPrefix(anim, name, fps, loop)
				else
					local success = self.anim:addFromLibrary(anim, name, "", fps, loop)
					if not success then self.anim:add(anim, name, fps, loop) end
				end
			end
			if offset ~= nil then
				local anim = self.anim:get(anim)
				if anim then anim.offset:set(unpack(offset)) end
			end
		end
	end

	if self.isPlayer ~= self.flipX then
		self.__reverseDraw = true
		self.anim:rename("singLEFT", "singRIGHT")
		self.anim:rename("singLEFTmiss", "singRIGHTmiss")
		self.anim:rename("singLEFT-loop", "singRIGHT-loop")
		self.anim:rename("singLEFT-end", "singRIGHT-end")
		self.anim:rename("danceLeft", "danceRight")
	end

	local position, x, y = Point()
	if data.position then
		x, y = unpack(data.position)
		if self.__reverseDraw then
			x = x + self:getWidth() / (self.isPlayer and -4 or 4)
		end
		position:set(x, y)
	end

	self.cameraPosition = Point()
	if data.camera_points then
		x, y = data.camera_points[1], data.camera_points[2]
		self.cameraPosition:set(x, y)
	end

	self.dirAnim, self.danced, self.isDanced, self.waitingFinish = nil, false, false, false
	self.lastHit = math.negative_infinity

	self.danceSpeed = data.dance_beats or 1
	self.holdTime = data.sing_duration or 8

	self.anim.onFinish:add(bind(self, self.__animFinished))

	if self.isPlayer then self.flipX = not self.flipX end

	if self.anim:has('danceLeft') and self.anim:has('danceRight') then
		self.idleAnims = {'danceLeft', 'danceRight'}
	else
		self.idleAnims = {'idle'}
	end
	self.idleIndex = 1

	self:setPosition(self.x + position.x, self.y + position.y)
	self.type = type

	self:dance()
	self.anim:finish()

	self:updateHitbox()
	if self._animAtlas then self._animAtlas:centerOrigin() end
end

function Character:__animFinished(name)
	if self.script then
		self.script:call("onAnimFinish", name)
	end

	if self.anim:has(name .. '-loop') then self.anim:play(name .. '-loop') end
	self.waitingFinish = false
	if self.script then
		self.script:call("postAnimFinish", name)
	end
end

function Character:update(dt)
	local animName = self.anim.curAnim and self.anim.curAnim.name or ""

	local cond, last, hold = PlayState.conductor, self.lastHit, self.holdTime
	local canDance = self.waitingFinish or (last > 0 and last + cond.stepCrotchet * hold < cond.time)
	if canDance and (self.dirAnim ~= nil and self.waitReleaseAfterSing) then
		canDance = controls:down(PlayState.keysControls[self.dirAnim]) ~= true
	end
	if canDance and self.anim:has(animName .. "-end") and not animName:endsWith("-end") then
		self:playAnim(animName .. '-end', true, nil, true)
	end

	if canDance and not self.waitingFinish then
		self:dance()
		self.lastHit = math.negative_infinity
	end

	if self._animAtlas then
		self._animAtlas:update(dt)
	end
	Character.super.update(self, dt)
end

function Character:beat(b)
	if not self.waitingFinish and self.lastHit <= 0 and b % self.danceSpeed == 0 then
		self:dance()
	end
end

function Character:playAnim(anim, force, frame, waitFinish)
	local result = Script.Event_Continue
	if self.script then
		result = self.script:call("onPlayAnim", anim, force, frame, waitFinish) or result
	end
	if result == Script.Event_Cancel then return end

	self.anim:play(anim, force, frame)
	self.dirAnim = nil
	self.waitingFinish = waitFinish == true

	if self.script then
		self.script:call("postPlayAnim", anim, force, frame, waitFinish)
	end
end

function Character:getDropAnim(number)
	local drop, value = nil, -1
	for name, anim in pairs(self.anim:getList()) do
		local dnum = name:match("^drop(%d+)$")
		if dnum then
			local num = tonumber(dnum)
			if num and num <= number and num > value then
				drop, value = anim.name, num
			end
		end
	end
	return drop
end

function Character:sing(dir, type, force)
	local anim = "sing" .. Character.directions[dir + 1]:upper()
	if type then
		local altAnim = anim .. (type == "miss" and type or "-" .. type)
		if self.anim:has(altAnim) then anim = altAnim end
	end
	self:playAnim(anim, force ~= false)

	self.dirAnim = type == "miss" and nil or dir
	self.lastHit = PlayState.conductor.time
	if #self.idleAnims == 2 then
		self.idleIndex = (anim:startsWith("singLEFT") or anim == "singUP") and 2 or 1
	end
end

function Character:dance(force)
	local result = self.script and self.script:call("dance") or true
	if result == nil then result = true end
	if not result then return end

	local animToPlay = self.idleAnims[self.idleIndex]
	if animToPlay and self.anim:has(animToPlay) then
		self:playAnim(animToPlay, force)
		self.idleIndex = (self.idleIndex % #self.idleAnims) + 1
	end
end

function Character:hasAnim(name)
	return self.anim:has(name)
end

function Character:getWidth()
	if self._animAtlas then
		return self._animAtlas.width
	end
	return self.width
end

function Character:getHeight()
	if self._animAtlas then
		return self._animAtlas.height
	end
	return self.height
end

function Character:getMidpoint()
	return self.x + self:getWidth() / 2, self.y + self:getHeight() / 2
end

function Character:updateHitbox()
	if self._animAtlas then
		local at = self._animAtlas
		at:updateHitbox()
		self.offset:set(at.offset.x, at.offset.y)
		self.origin:set(at.origin.x, at.origin.y)

		local ox, oy = self._animAtlas:getBoundTopLeft()
		self.offset:set(self.offset.x + ox * (self.flipX and -1 or 1),
			self.offset.y + oy * (self.flipY and -1 or 1))
	else
		Character.super.updateHitbox(self)
	end
end

function Character:__preRender(willRender)
	if self._animAtlas and self:canDraw() then
		self._animAtlas:__preRender(willRender)
	end
end

function Character:getLocalBounds()
	if self._animAtlas then return self._animAtlas:getLocalBounds() end
	return Character.super.getLocalBounds(self)
end

function Character:canDraw()
	if self._animAtlas then return self.alpha > 0 and self.visible and self.exists end
	return Character.super.canDraw(self)
end

function Character:getBoundaryTransform()
	if self._animAtlas then
		local d = self._data
		local x, y = self.x, self.y
		local ox, oy, offx, offy = self.origin.x, self.origin.y, self.offset.x, self.offset.y
		local ang = math.rad(self.angle)
		local sx, sy = self.scale.x * self.zoom.x, self.scale.y * self.zoom.y
		local kx, ky = self.skew.x, self.skew.y

		if self.flipX then sx = -sx end
		if self.flipY then sy = -sy end

		if self.anim and self.anim.curAnim then
			local ax, ay = self.anim.curAnim:rotateOffset(self.angle, sx, sy)
			x, y = x - ax, y - ay
		end

		local dx, dy = x + ox - offx, y + oy - offy
		local s, c = math.fastsin(ang), math.fastcos(ang)

		d.m11 = c * sx - ky * s * sy
		d.m12 = s * sx + ky * c * sy
		d.m21 = kx * c * sx - s * sy
		d.m22 = kx * s * sx + c * sy

		d.dx = dx - (ox * d.m11 + oy * d.m21)
		d.dy = dy - (ox * d.m12 + oy * d.m22)

		return d
	end

	return Character.super.getBoundaryTransform(self)
end

function Character:__render(camera)
	if self._animAtlas then
		love.graphics.push("all")
		local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
		self._animAtlas:__draw(x, y, rad, sx, sy, ox, oy, kx, ky)
		love.graphics.pop()
	else
		Character.super.__render(self, camera)
	end
end

function Character:destroy()
	if self._animAtlas then
		self._animAtlas:destroy()
	end
	Character.super.destroy(self)
end

return Character
