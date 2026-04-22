local LoadScreen = require "funkin.ui.loadscreen"
local LoadState = State:extend("LoadState")

function LoadState:new(state)
	LoadState.super.new(self)
	self.nextState = state
	self.persistCache = true
end

function LoadState:enter()
	self.notCreated = false

	self.script = Script("data/states/load", false)
	local event = self.script:call("create")
	if event == Script.Event_Cancel then
		LoadState.super.enter(self)
		self.notCreated = true
		self.script:call("postCreate")
		return
	end

	self.skipTransIn, self.skipTransOut = true, true
	self.load = LoadScreen(self.nextState)
	self:add(self.load)

	LoadState.super.enter(self)

	if game.sound.music then
		game.sound.music:fade(0.66, ClientPrefs.data.menuMusicVolume / 100, 0)
	end
	self.script:call("postCreate")
end

function LoadState:update(dt)
	self.script:call("update", dt)
	if self.notCreated then
		LoadState.super.update(self, dt)
		self.script:call("postUpdate", dt)
		return
	end

	if paths.async.getProgress() == 1 and not self._loaded then
		self._loaded = true
		if game.sound.music then
			game.sound.music:cancelFade()
		end
		Timer.wait(0.056, function()
			game.switchState(self.nextState)
		end)
	end
	LoadState.super.update(self, dt)
	self.script:call("postUpdate", dt)
end

function LoadState:leave()
	self.script:call("leave")
	if self.notCreated then
		self.script:call("postLeave")
		self.script:close()
		return
	end

	self.script:call("postLeave")
	self.script:close()
end

return LoadState
