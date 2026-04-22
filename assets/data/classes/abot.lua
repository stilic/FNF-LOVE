local ABot = SpriteGroup:extend("ABot")
local Visualizer = SpriteGroup:extend("Visualizer")

function Visualizer:new(x, y, fftInstance, variant)
	Visualizer.super.new(self, x, y)

	self.fft = fftInstance
	self.barCount = 7
	self.variant = variant or "normal"

	local isPixel = self.variant == "pixel"
	local path = isPixel and "characters/nene/abotPixel/aBotVizPixel" or "characters/nene/abot/aBotViz"
	local frames = paths.getSparrowAtlas(path)

	local s, aa, px, py = 1, true

	if isPixel then
		px, py = {0, 42, 48, 54, 60, 36, 42}, {0, -12, -6, 0, 0, 6, 12}
		s, aa = 6, false
	else
		px, py = {0, 59, 56, 66, 54, 52, 51}, {0, -8, -3.5, -0.4, 0.5, 4.7, 7}
	end

	local cx, cy = 0, 0

	for i = 1, self.barCount do
		cx, cy = cx + px[i], cy + py[i]

		local sprite = Sprite(cx, cy)
		sprite:setFrames(frames)
		sprite.animation:addByPrefix("VIZ", "viz" .. i .. "0", 0, false)
		sprite.animation:play("VIZ", true)
		sprite.antialiasing = aa
		sprite.scale:set(s, s)
		sprite:updateHitbox()
		self:add(sprite)
	end
end

function Visualizer:__render(c)
	self.fft:update(0)
	local bars = self.fft:getBars(true)
	for i = 1, 7 do
		local member = self.members[i]

		local bar = bars[i]
		member.alpha = bar > 0 and 1 or 0.000001
		local animFrame = 0

		if game.sound.__volume > 0 and not game.sound.__muted then
			animFrame = math.floor(bar * 6) + 1
		end

		animFrame = animFrame - 1
		animFrame = math.max(1, math.min(7, animFrame))
		animFrame = math.abs(animFrame - 7)

		if member.animation and member.animation.curAnim then
			member.animation.curAnim.frame = animFrame
		end
	end
	Visualizer.super.__render(self, c)
end

function ABot:new(x, y, variant)
	ABot.super.new(self, x, y)
	self.variant = variant or "normal"

	local path = "songs/" .. paths.formatToSongPath(PlayState.SONG.song) .. "/Inst.ogg"
	local fft = FFT(7, path, game.sound.music._source)
	fft.fftSize = 1024
	self.fft = fft

	if self.variant == "pixel" then
		self.speaker = Sprite(-78, 9)
		self.speaker:setFrames(paths.getSparrowAtlas('characters/nene/abotPixel/aBotPixelSpeaker'))
		self.speaker.scale:set(6, 6)
		self.speaker.antialiasing = false
		self.speaker.animation:addByPrefix('danceLeft', 'danceLeft', 24, false)
		self.speaker.animation:addByPrefix('danceRight', 'danceLeft', 24, false)
		self:add(self.speaker)

		self.back = Sprite(-240, -100, paths.getImage('characters/nene/abotPixel/aBotPixelBack'))
		self.back.scale:set(6.1, 6)
		self.back:updateHitbox()
		self.back.antialiasing = false
		self:add(self.back)

		self.visualizer = Visualizer(0, -40, fft, "pixel")
		self.visualizer:updateHitbox()
		self.visualizer:center(self.back, "x")
		self:add(self.visualizer)

		self.head = Sprite(-325, 72)
		self.head:setFrames(paths.getSparrowAtlas('characters/nene/abotPixel/abotHead'))
		self.head.scale:set(6, 6)
		self.head.antialiasing = false
		self.head.animation:addByPrefix('toleft', 'toleft0', 24, false)
		self.head.animation:addByPrefix('toright', 'toright0', 24, false)
		self.head.animation:play('toright', true)
		self:add(self.head)

		self.abot = Sprite(0, 0)
		self.abot:setFrames(paths.getSparrowAtlas('characters/nene/abotPixel/aBotPixelBody'))
		self.abot.scale:set(6, 6)
		self.abot.antialiasing = false
		self.abot.animation:addByPrefix('danceLeft', 'danceLeft', 24, false)
		self.abot.animation:addByPrefix('danceRight', 'danceRight', 24, false)
		self.abot.animation:addByPrefix('lowerKnife', 'return', 24, false)
		self:add(self.abot)
	else
		self.eyeWhites = Graphic(50, 240, 160, 60)
		self.eyeWhites.color = Color.WHITE
		self:add(self.eyeWhites)

		self.stereoBG = Sprite(160, 30, paths.getImage('characters/nene/abot/stereoBG'))
		self:add(self.stereoBG)

		self.visualizer = Visualizer(200, 80, fft, "normal")
		self:add(self.visualizer)

		self.pupil = AnimateAtlas(55, 238, paths.getAnimateAtlas("characters/nene/abot/systemEyes"))
		local lf = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
		local rg = {17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36}
		self.pupil.animation:addByIndices("pupilLeft", '', lf, 24)
		self.pupil.animation:addByIndices("pupilRight", '', rg, 24)
		self.pupil.animation:play("pupilLeft")
		self.pupil.animation:finish()
		self:add(self.pupil)

		self.abot = AnimateAtlas(0, 0, paths.getAnimateAtlas("characters/nene/abot/abotSystem"))
		self.abot.animation:add("beat", "", 24, false)
		self.abot.animation:play("beat")
		self:add(self.abot)
	end
end

function ABot:setEyeDirection(n)
	if self.variant == "pixel" then
		if n == 1 and self.head.animation.curAnim.name ~= "toleft" then
			self.head.animation:play("toleft")
		elseif n == 0 and self.head.animation.curAnim.name ~= "toright" then
			self.head.animation:play("toright")
		end
	else
		if n == 1 and self.abot.animation.curAnim.name ~= "pupilRight" then
			return self.pupil.animation:play("pupilRight")
		elseif self.pupil.animation.curAnim.name ~= "pupilLeft" then
			return self.pupil.animation:play("pupilLeft")
		end
	end
end

function ABot:beat()
	if self.variant == "normal" then
		self.abot.animation:play("beat", true)
	end
end

function ABot:destroy()
	ABot.super.destroy(self)
end

return ABot
