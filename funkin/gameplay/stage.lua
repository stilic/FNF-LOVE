local Stage = Group:extend("Stage")

function Stage:new(name)
	Stage.super.new(self)
	self.name = name
	if name == "" then return end

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
		for _, prop in pairs(self.data.props) do
			if prop.assetPath:sub(1, 1) ~= '#' then
				table.insert(list, {"image", path .. "/" .. prop.assetPath})
			end
		end
		paths.async.loadBatch(list)
	end

	if noData and noScript then
		Logger.log("error", "No stage found for " .. name)
	end
end

function Stage:load()
	local data = self.data or Parser.getDummyStage()
	self.camZoom, self.camSpeed, self.camZoomSpeed = data.cameraZoom or 0.4, 1, 1

	self.boyfriendPos = Point(770, 100)
	self.gfPos = Point(400, 130)
	self.dadPos = Point(100, 100)

	self.boyfriendCam = Point(-100, -100)
	self.gfCam = Point()
	self.dadCam = Point(150, -100)

	for char, data in pairs(data.characters) do
		local c = char == "bf" and "boyfriend" or char
		if data.position then self[c .. "Pos"]:set(unpack(data.position)) end
		if data.cameraOffsets then self[c .. "Cam"]:set(unpack(data.cameraOffsets)) end
	end

	self.foreground = Group()

	if self.script then
		self.script:linkObject(game.getState())
		self.script:set("state", game.getState())
		self.script:linkObject(self) -- link this back so playstate doesnt overrides
		self.script:call("create")
	end

	local characters = {
		gf = {"gfVersion", "gf", false, 100},
		dad = {"player2", "dad", false, 300},
		bf = {"player1", "boyfriend", true, 200}
	}
	for n, props in pairs(characters) do
		local key, name, player, z, scroll = unpack(props)
		local char, pos = PlayState.SONG[key], self[name .. "Pos"]
		if char and char ~= "" then
			self[name] = Character(pos.x, pos.y, char, player)
			local character = self[name]
			character.scrollFactor:set(scroll or 1, scroll or 1)
			character.zIndex = data.characters[n] and data.characters[n].zIndex or z
			local scale = data.characters[n] and data.characters[n].scale or 1
			character.scale:mul(scale)
			self:add(character)

			character:dance()
			if character.type == "VSlice" then
				character:updateHitbox()
				character.x = character.x - character.width / 2
				character.y = character.y - character.height
			end
		end
	end
	if self.gf and self.dad and self.dad.char:startsWith("gf") then
		self.gf.visible = false
		self.dad:setPosition(self.gf.x, self.gf.y)
	end

	if self.data then
		self:generateStage()
	end

	self:refresh()
end

function Stage:generateStage()
	local path = "stages/" .. self.name .. '/'

	for _, prop in pairs(self.data.props) do
		local instance
		local isAnimated = prop.animations and next(prop.animations)

		if isAnimated then
			instance = Sprite(prop.position[1], prop.position[2])
			instance:setFrames(paths.getSparrowAtlas(path .. prop.assetPath))
			for _, anim in pairs(prop.animations) do
				local name = anim.name
				if anim.frameIndices then
					instance.animation:addByIndices(name, anim.prefix or '', anim.frameIndices, anim.frameRate or 24, anim.looped or false)
				else
					instance.animation:addByPrefix(name, anim.prefix or '', anim.frameRate or 24, anim.looped or false)
				end
				if anim.offsets then
					local anima = instance.animation:get(name)
					if anima then anima.offset:set(anim.offsets[1], anim.offsets[2]) end
				end
			end
			instance:play(prop.startingAnimation or "danceLeft", true)
		elseif prop.assetPath:sub(1, 1) == '#' then
			instance = Graphic(prop.position[1], prop.position[2], prop.scale[1] or 1.0, prop.scale[2] or 1.0)
			instance.color = Color.fromString(prop.assetPath or Color.BLACK)
		else
			instance = Sprite(prop.position[1], prop.position[2], paths.getImage(path .. prop.assetPath))
		end

		instance.scale:set(prop.scale[1] or 1, prop.scale[2] or 1)
		instance.flipX, instance.flipY = prop.flipX or false, prop.flipY or false
		instance.scrollFactor:set(prop.scroll[1] or 1, prop.scroll[2] or 1)
		instance.name, instance.zIndex = prop.name, prop.zIndex or 0
		instance.blend = prop.blend or instance.blend
		instance.alpha = prop.alpha or 1

		self:add(instance)
		if self.script then
			self.script:set(prop.name, instance)
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

return Stage
