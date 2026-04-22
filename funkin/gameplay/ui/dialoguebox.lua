-- TODO rewrite this. again - kaoy

local DialogueBox = SpriteGroup:extend("DialogueBox")

local function dispatchAnims(spr, data)
	for _, anim in ipairs(data) do
		local name, prefix, indices, offset, fps, loop =
			unpack(anim)

		if #indices > 0 then
			spr.animation:addByIndices(name, prefix, indices, nil, fps, loop)
		else
			spr.animation:addByPrefix(name, prefix, fps, loop)
		end
		if offsets then
			local anim = spr.animation:get(name)
			if anim then anim.offset:set(unpack(offset)) end
		end
	end
end

function DialogueBox:onFinishAnim(name)
	if self.animation:has(name .. "-loop") then
		self.animation:play(name .. "-loop")
	end
end

function DialogueBox:onCharFinishAnim(name)
	if self.finished and self.animation:has(name .. "-loop") then
		self.animation:play(name .. "-loop")
	elseif not self.finished then
		self.animation:play(name, true)
	end
end

function DialogueBox:new(box, anim, song, ...)
	DialogueBox.super.new(self)

	local path = "data/dialogue/boxes/" .. box
	self.jsonData = paths.getJSON(path)

	song = paths.formatToSongPath(song)

	self.script = Script(path, false)
	self.script:linkObject(self)
	self.script:set("self", self)
	self.script:call("create", box, anim, song, ...)

	self.characters, self.box = SpriteGroup(), SpriteGroup()
	self.characters.visible, self.box.visible = false, false
	self:add(self.characters); self:add(self.box)

	self:loadBox(anim)

	self.dialogues = {}
	self.jsonCache = {}

	if love.system.getDevice() == "Mobile" then
		self.button = VirtualPad("return", 0, 0, game.width, game.height, false)
		self:add(self.button)
	end

	self.started, self.finished, self.allFinished = false, false, false

	local read = love.filesystem.read
	local file = read(paths.getPath("songs/" .. song .."/dialogue.txt"))
	if not file then return self:closeDialogue() end
	self.curDialogue = 1
	self.dialogueDelay = 0.3
	self:splitDialogues(file)

	local event = self.script:call("postCreate")
	if event ~= Script.Event_Cancel then
		self:startDialogue()
	end
end

function DialogueBox:loadBox(anim)
	local event = self.script:call("onLoadBox", anim)
	if event == Script.Event_Cancel then return end

	local data = self.jsonData[anim] or self.jsonData.default

	self.boxSpr = self.boxSpr or Sprite()
	self.boxSpr.animation:reset()
	if data.animations then
		self.boxSpr:setFrames(paths.getAtlas("dialogue/boxes/" .. data.sprite))
		dispatchAnims(self.boxSpr, data.animations)
		self.boxSpr.animation:play("enter")
		self.boxSpr.animation.onFinish = bind(self.boxSpr, self.onFinishAnim)
	else
		self.boxSpr:loadTexture(paths.getImage("dialogue/boxes/" .. data.sprite))
		self.boxSpr.frames = nil
	end

	if data.scale and data.scale ~= 1 then
		self.boxSpr:setGraphicSize(self.boxSpr.width * data.scale)
	end
	self.boxSpr.antialiasing = data.antialiasing == nil and true or data.antialiasing
	self.boxSpr:updateHitbox()

	self.boxSpr:screenCenter('x')
	self.boxSpr.x, self.boxSpr.y = self.boxSpr.x + data.position[1], self.boxSpr.y + data.position[2]
	self.box:add(self.boxSpr)

	if data.finishedDialogueSprite then
		local ndata = data.finishedDialogueSprite
		local spr = self.finishSpr or Sprite()
		spr.animation:reset()
		spr:setPosition(ndata.position[1], ndata.position[2])
		if ndata.animations then
			spr:setFrames(paths.getAtlas("dialogue/boxes/" .. ndata.sprite))
			dispatchAnims(spr, ndata.animations)
			spr:play("enter")
			spr.animation.onFinish = bind(spr, self.onFinishAnim)
		else
			spr:loadTexture(paths.getImage("dialogue/boxes/" .. ndata.sprite))
			spr.frames = nil
		end
		if ndata.scale and ndata.scale ~= 1 then
			spr:setGraphicSize(spr.width * ndata.scale)
		end
		spr:updateHitbox()
		spr.visible = false
		spr.antialiasing = ndata.antialiasing == nil and true or ndata.antialiasing
		self.box:add(spr)
		self.finishSpr = spr
	end

	self.skipSound = paths.getSound(data.skipSound)
	self.nextSound = paths.getSound(data.nextSound)
	self.textSound = paths.getSound(data.textSound)

	local function getTextObject(data)
		local kind = data.type or "font"

		local pos = data.position or {100, 100}
		local color = data.color and Color.fromString(data.color) or Color.WHITE
		local align = data.align or "left"
		local limit = data.limit or game.width * 0.6
		local font = data.font or (kind == "font" and {"vcr.ttf", 16} or {"default", 0.9})
		local fnt, text

		if kind == "font" then
			fnt = paths.getFont(font[1], font[2])
			text = TypeText(pos[1], pos[2], "", fnt, color, align, limit)
			if data.outline then
				local kind, size, color, offset = data.outline[1], data.outline[2], data.outline[3]
				if type(size) == "table" then size, offset = 0, {x = size[1], y = size[2]} end
				text:setOutline(kind, size, offset, Color.fromString(color))
			end
			text.sound = self.textSound
		else
			fnt = AtlasText.getFont(font[1], font[2])
			text = AtlasText(pos[1], pos[2], "", fnt, limit, align)
			text.color = color
		end
		text.antialiasing = data.antialiasing == nil and true or data.antialiasing
		return text
	end

	if self.text then self.text:destroy(); self.text = nil end
	self.text = getTextObject(data.text)
	self.box:add(self.text)
end

function DialogueBox:startDialogue()
	self.curDialogue = self.curDialogue or 0
	local prev = self.dialogues[self.curDialogue - 1]
	local dialogue = self.dialogues[self.curDialogue]
	if not dialogue then return end

	local event = self.script:call("onStartDialogue")
	if event == Script.Event_Cancel then return end

	self.finished = false

	self.characters.visible = true
	if not self.box.visible then
		self.box.visible = true
		if self.boxSpr.animations then self.boxSpr:play("enter") end
	end

	if self.finishSpr then self.finishSpr.visible = false end

	if not prev or prev[3] ~= dialogue[3] then
		self:resetCharacters(dialogue[1])
	end

	local function func()
		if self.text:is(TypeText) then
			self.text:resetText(dialogue[2])
		else
			self.text:setTyping(dialogue[2], 0.04, self.textSound)
		end
		self.text.completeCallback = function()
			if self.finishSpr then
				self.finishSpr.visible = true
				if self.finishSpr.__animations then
					self.finishSpr:play("enter")
				end
			end
			self.finished = true
		end
		self.started = true
		self.dialogueDelay = 0
	end

	if self.dialogueDelay > 0 then
		Timer.wait(self.dialogueDelay, func)
	else
		func()
	end
end

function DialogueBox:resetCharacters(chars)
	local event = self.script:call("onResetCharacters", chars)
	if event == Script.Event_Cancel then return end

	for _, member in pairs(self.characters.members) do
		member:kill()
	end

	for _, char in ipairs(chars) do
		local spr = self.characters:recycle()

		spr.x, spr.y = char.position[1], char.position[2]
		spr:setGraphicSize(spr.width)
		spr.animation:reset()
		if char.animations then
			spr:setFrames(paths.getAtlas("dialogue/characters/" .. char.sprite))
			dispatchAnims(spr, char.animations)
			spr:play("enter")
			spr.animation.finished = bind(spr, self.onCharFinishAnim)
		else
			spr:loadTexture(paths.getImage("dialogue/characters/" .. char.sprite))
			spr.frames = nil
		end
		if char.scale and char.scale ~= 1 then
			spr:setGraphicSize(spr.width * char.scale)
		end
		spr:updateHitbox()
		spr.antialiasing = not char.antialiasing == false
	end
end

function DialogueBox:update(dt)
	self.script:call("update", dt)

	if controls:pressed("accept") and self.started then
		if self.finished and self.curDialogue == #self.dialogues then
			if not self.allFinished then
				local event = self.script:call("finishDialogue")
				if event ~= Script.Event_Cancel then
					self:closeDialogue()
				end
			end
			self.allFinished = true
		elseif self.finished then
			self.curDialogue = self.curDialogue + 1
			self:startDialogue()
			if self.nextSound then util.playSfx(self.nextSound) end
		else
			self.text:forceEnd()
			if self.skipSound then util.playSfx(self.skipSound) end
		end
	end

	DialogueBox.super.update(self, dt)
	self.script:call("postUpdate", dt)
end

function DialogueBox:getCachedChar(char, expression)
	if not self.jsonCache[char] then
		self.jsonCache[char] = paths.getJSON("data/dialogue/characters/" .. char)
		self.jsonCache[char].name = char .. expression
	end
	return self.jsonCache[char][expression]
end

function DialogueBox:splitDialogues(data)
	local lines = data:split('\n')
	for i, line in ipairs(lines) do
		local stuff = line:split(':')

		local dialogue = stuff[#stuff]
		stuff[#stuff] = nil

		local chars = {}
		for i = 1, #stuff do
			local line = stuff[i]
			local name, expr = line:match("([^.]+)%.?(.*)")
			if not expr or expr == "" then expr = "default" end
			table.insert(chars, self:getCachedChar(name, expr))
		end

		table.insert(self.dialogues, {chars, dialogue, table.concat(stuff)})
		local prev = self.dialogues[#self.dialogues - 1]
	end
end

function DialogueBox:closeDialogue()
	if self.button then self:remove(self.button); self.button:destroy() end
	if self.onFinish then self.onFinish() end
	self.script:close()
	self:destroy()
end

return DialogueBox
