local Stage = SpriteGroup:extend("Stage")

function Stage:new(name)
	Stage.super.new(self)

	self.name = name
	if name == "" then return end

	self.suppressedEvents = {}

	local path, noScript, noData = "stages/" .. name
	if paths.exists(paths.getPath("data/" .. path .. ".lua"), "file") then
		self.script = Script("data/" .. path, nil, true)
		self.script:linkObject(self)
		self.script:set("SCRIPT_PATH", path .. "/")
		self.script:set("self", self)

		local list = self.script:call("preload")
		if list and type(list) == "table" then
			paths.async.loadBatch(list)
		end
	else
		noScript = true
	end

	self.data = Parser.getStage(self.name)
	noData = self.data == false

	if self.data then
		local list = {}
		for _, prop in pairs(self.data.objects) do
			if prop[11] == "image" then
				table.insert(list, {"image", path .. "/" .. prop[12]})
			end
		end
		paths.async.loadBatch(list)
	end

	if noData and noScript then
		Logger.log("warn", "No stage found for " .. name)
	end
end

function Stage:load()
	local data = self.data or Parser.getDummyStage()

	self.camZoom, self.camSpeed, self.camZoomSpeed = data.zoom, 1, 1

	self.boyfriendPos = Point(770, 100)
	self.gfPos = Point(400, 130)
	self.dadPos = Point(100, 100)

	self.boyfriendCam = Point(-100, -100)
	self.gfCam = Point()
	self.dadCam = Point(150, -100)

	self.jsonInstances = {}
	self.characters = {}

	for c, data in pairs(data.characters) do
		self[c .. "Pos"]:set(data.x, data.y)
		self[c .. "Cam"]:set(data.cameraOffset.x, data.cameraOffset.y)
	end

	self.foreground = Group()

	if self.script then
		self.script:linkObject(game.getState())
		self.script:set("state", game.getState())
		self.script:linkObject(self) -- link this back so playstate doesnt overrides
		self.script:call("create")
	end

	local char = PlayState.SONG
	local c = data.characters.gf
	if char.gfVersion and char.gfVersion ~= "" then
		self.gf = self:addCharacter(char.gfVersion, self.gfPos, c.scale, c.scroll, c.z, false)
	end

	if char.player1 and char.player1 ~= "" then
		c = data.characters.boyfriend
		self.boyfriend = self:addCharacter(char.player1, self.boyfriendPos, c.scale, c.scroll, c.z, true)
	end

	if char.player2 and char.player2 ~= "" then
		local c = data.characters.dad
		self.dad = self:addCharacter(char.player2, self.dadPos, c.scale, c.scroll, c.z, false)
	end

	if self.gf and self.dad and self.dad.char:startsWith("gf") then
		self.gf.visible = false
		self.dad:setPosition(self.gf.x, self.gf.y)
	end

	if self.data then self:generateStage() end
	self:refresh()
end

function Stage:addCharacter(name, position, scale, scrollFactor, zIndex, isPlayer)
	-- TODO: MAKE THIS CALL A PROPER CANCELLABLE EVENT
	if self.script then
		self.script:call("onAddCharacter", name, position, scale, scrollFactor, zIndex, isPlayer)
	end

	local character = Character(position.x, position.y, name, isPlayer)

	if scrollFactor then character.scrollFactor:set(scrollFactor.x, scrollFactor.y) end
	if scale then character.zoom:set(scale.x, scale.y) end

	character.zIndex = zIndex or self.characters[#self.characters].zIndex + 1

	if character.type == "VSlice" then
		character.x = character.x - character:getWidth() / 2
		character.y = character.y - character:getHeight()
	end

	self:add(character)
	table.insert(self.characters, character)

	if self.script then
		self.script:call("postAddCharacter", character, name, position, scale, scrollFactor, zIndex, isPlayer)
	end

	return character
end

function Stage:generateStage()
	local path = "stages/" .. self.name .. '/'

	for _, prop in ipairs(self.data.objects) do
		local instance

		if prop.type == "graphic" then
			instance = Graphic(prop.x, prop.y, prop.scaleX, prop.scaleY)
			instance.color = prop.assetPath and Color.fromString(prop.assetPath) or Color.BLACK
		else
			instance = Sprite(prop.x, prop.y)
			local isAnimated = #prop.animations > 0

			if isAnimated then
				instance:setFrames(paths.getAtlas(path .. prop.assetPath, prop.isPixel))
				for _, anim in ipairs(prop.animations) do
					if anim.func == "add" then
						instance.animation:add(anim.name, anim.indices, anim.frameRate, anim.looped)
					elseif anim.func == "addByIndices" then
						instance.animation:addByIndices(anim.name, anim.prefix, anim.indices, "", anim.frameRate, anim.looped)
					elseif anim.func == "addByPrefix" then
						instance.animation:addByPrefix(anim.name, anim.prefix, anim.frameRate, anim.looped)
					end
					if anim.offsets then
						local a = instance.animation:get(anim.name)
						if a then a.offset:set(anim.offsets[1], anim.offsets[2]) end
					end
				end
				if prop.startAnimation then
					instance.animation:play(prop.startAnimation, true)
				end
			else
				instance:loadTexture(paths.getImage(path .. prop.assetPath, prop.isPixel))
			end
		end

		if not instance:is(Graphic) then
			instance.scale:set(prop.scaleX, prop.scaleY)
		end

		instance.flipX = prop.flipX
		instance.flipY = prop.flipY
		instance.scrollFactor:set(prop.scrollX, prop.scrollY)
		instance.name = prop.name
		instance.zIndex = prop.zIndex
		instance.alpha = prop.alpha
		instance.antialiasing = not prop.isPixel
		instance.danceSpeed = prop.danceSpeed

		instance:updateHitbox()
		self:add(instance)
		table.insert(self.jsonInstances, instance)

		if self.script then
			self.script:set(prop.name, instance)
			self.script:call("addProp", instance)
		end
	end
end

function Stage:refresh()
	self:sort(function(a, b) return (a.zIndex or 0) < (b.zIndex or 0) end)
end

function Stage:add(obj, foreground)
	if foreground then
		return self.foreground:add(obj)
	end
	Stage.super.add(self, obj)
	if not obj.zIndex then obj.zIndex = #self.members end
end

function Stage:beat(b)
	for _, obj in ipairs(self.jsonInstances) do
		if  obj.danceSpeed > 0 and obj.animation and b % obj.danceSpeed == 0 then
			if obj.animation:has("idle") then
				obj.animation:play("idle", true)
			elseif obj.animation:has("danceLeft") and obj.animation:has("danceRight") then
				obj.animation:play(obj.animation.curAnim and obj.animation.curAnim.name == "danceRight" and "danceLeft" or "danceRight")
			end
		end
	end
	for _, char in ipairs(self.characters) do
		char:beat(b)
	end
end

function Stage:suppressEvents(...)
	for _, n in ipairs({...}) do self.suppressedEvents[n] = true end
end

return Stage
