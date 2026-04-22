local SoundTray = {
	images = {
		bars = love.graphics.newImage(paths.getPath("images/soundtray/bars.png")),
		box = love.graphics.newImage(paths.getPath("images/soundtray/volumebox.png"))
	},

	sounds = {
		voldown = love.sound.newSoundData(paths.getPath("sounds/soundtray/voldown.ogg")),
		volup = love.sound.newSoundData(paths.getPath("sounds/soundtray/volup.ogg")),
		volmax = love.sound.newSoundData(paths.getPath("sounds/soundtray/volmax.ogg"))
	},

	game = {width = 0, height = 0}
}

local DEFAULT_VOLUME = 10
local prev = DEFAULT_VOLUME
local n = DEFAULT_VOLUME
local SCALE = 0.5

function SoundTray.init(width, height)
	SoundTray.game.width = width
	SoundTray.game.height = height

	if ClientPrefs.save.data.gameVolume ~= nil then
		game.sound.setVolume(ClientPrefs.save.data.gameVolume / 10)
		prev = ClientPrefs.save.data.gameVolume
		n = ClientPrefs.save.data.gameVolume
	end

	return SoundTray
end

function SoundTray.new()
	local this = SoundTray

	this.visible = false
	this.silent = false
	this.canSpawn = false
	this.timer = 0
	this.alpha = 1

	this.box = {
		image = this.images.box,
		x = 0,
		y = 0,
		width = this.images.box:getWidth() * SCALE,
		height = this.images.box:getHeight() * SCALE
	}

	this.bars = {
		image = this.images.bars,
		x = 0,
		y = 0,
		width = this.images.bars:getWidth() * SCALE,
		height = this.images.bars:getHeight() * SCALE
	}

	this.throttles = {}
	this.throttles.up = Throttle:make({controls.down, controls, "volume_up"})
	this.throttles.down = Throttle:make({controls.down, controls, "volume_down"})

	this.adjust()

	return this
end

function SoundTray.adjust()
	local this = SoundTray

	this.box.x = (this.game.width - this.box.width) / 2
	this.bars.x = (this.game.width - this.bars.width) / 2
	this.bars.y = (this.box.y + (this.box.width - this.bars.width) / 2) - 11 * SCALE
end

function SoundTray.adjustVolume(amount)
	local this = SoundTray

	this.canSpawn = true
	this.timer = 0

	local newVolume = n + amount
	newVolume = math.max(0, math.min(10, newVolume))

	prev, n = n, newVolume
	local sound = amount > 0 and (prev == 10 and "volmax" or "volup") or "voldown"

	game.sound.setVolume(newVolume / 10)
	game.sound.setMute(newVolume == 0)

	if not this.silent then
		game.sound.play(SoundTray.sounds[sound], 1, false, false)
	end

	ClientPrefs.save.data.gameVolume = newVolume
end

function SoundTray.toggleMute()
	local this = SoundTray

	game.sound.setMute(not game.sound.__mute)
	if not game.sound.__mute then
		this.adjustVolume(prev > 0 and prev or 1)
	else
		this.adjustVolume(-n)
	end
end

function SoundTray:update(dt)
	local this = SoundTray

	if this.throttles.up:check() then this.adjustVolume(1) end
	if this.throttles.down:check() then this.adjustVolume(-1) end
	if controls:pressed("volume_mute") then this.toggleMute() end

	this.timer = this.timer + dt
	if this.timer >= 2 then this.canSpawn = false end

	if this.canSpawn then
		this.visible = true
		this.alpha = 1
		this.box.y = math.lerp(25 * SCALE, this.box.y, math.exp(-dt * 14))
	else
		this.box.y = math.lerp(-180 * SCALE, this.box.y, math.exp(-dt * 2.6))
		this.alpha = this.alpha - 6.22 * dt
		if this.alpha <= 0 then self.visible = false end
	end

	this.adjust()
end

function SoundTray:fullscreen()
	SoundTray.resize(love.graphics.getDimensions())
end

function SoundTray:resize(width, height)
	local this = SoundTray

	this.game.width = width
	this.game.height = height
	this.adjust()
end

function SoundTray:__render()
	local this = SoundTray

	if this.visible then
		local lg = love.graphics
		lg.push("all")
		lg.setColor(1, 1, 1, this.alpha)
		lg.draw(this.box.image, this.box.x, this.box.y, 0, SCALE, SCALE)

		lg.setColor(1, 1, 1, math.clamp(this.alpha - 0.4, 0, 1))
		lg.draw(this.bars.image, this.bars.x, this.bars.y, 0, SCALE, SCALE)

		lg.setColor(1, 1, 1, this.alpha)
		lg.stencil(function()
			local width = n * 20 * SCALE
			lg.rectangle("fill", this.bars.x, this.bars.y, width, this.bars.height)
		end, "replace", 1)
		lg.setStencilTest("greater", 0)
		lg.draw(this.bars.image, this.bars.x, this.bars.y, 0, SCALE, SCALE)

		lg.setStencilTest()
		lg.pop()
	end
end

return SoundTray
