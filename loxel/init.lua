loxreq = setmetatable({path = (...) .. "."}, {
	__call = function(_, f) return require(loxreq.path .. f) end
})

require "love.window"
loxreq "lib.override"

Project = require "project"
Logger = loxreq "system.logger"

local isMobile = love.system.getDevice() == "Mobile"

if Project.flags.loxelInitWindow then
	love.window.setTitle(Project.title)
	love.window.setIcon(love.image.newImageData(Project.icon))
	love.window.setMode(Project.width, Project.height, {
		fullscreen = isMobile, resizable = not isMobile, usedpiscale = false
	})

	if Project.bgColor then
		love.graphics.setBackgroundColor(Project.bgColor)
	end
	love.window.setVSync(Project.VSync and 1 or 0)
end

local __step__, __quit__ = "step", "quit"
local dt, fps = 0, 0
local sleep = love.timer.sleep

local eventhandlers = {
	keypressed = function(t, b, s, r) return love.keypressed(b, s, r, t) end,
	keyreleased = function(t, b, s) return love.keyreleased(b, s, t) end,
	joystickpressed = function(t, j, b) if love.joystickpressed then return love.joystickpressed(j, b, t) end end,
	joystickreleased = function(t, j, b) if love.joystickreleased then return love.joystickreleased(j, b, t) end end,
	gamepadpressed = function(t, j, b) if love.gamepadpressed then return love.gamepadpressed(j, b, t) end end,
	gamepadreleased = function(t, j, b) if love.gamepadreleased then return love.gamepadreleased(j, b, t) end end,
	touchpressed = function(t, id, x, y, dx, dy, p) return love.touchpressed(id, x, y, dx, dy, p, t) end,
	touchmoved = function(t, id, x, y, dx, dy, p) return love.touchmoved(id, x, y, dx, dy, p, t) end,
	touchreleased = function(t, id, x, y, dx, dy, p) return love.touchreleased(id, x, y, dx, dy, p, t) end,
}

function love.run()
	love.FPScap, love.unfocusedFPScap = Project.FPS, 16
	love.autoPause = Project.flags.loxelInitialAutoPause
	love.vsync = Project.vSync

	if love.math then love.math.setRandomSeed(os.time()) end
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	love.timer.step(); collectgarbage()

	local origin, clear, present = love.graphics.origin, love.graphics.clear, love.graphics.present
	local getBgColor, draw = love.graphics.getBackgroundColor, love.draw
	local pump, poll = love.event.pump, love.event.poll()
	local focused, clock, nextdraw, cap = true, 0, 0, 0
	local prevFpsUpdate, sinceLastFps, frames = love.timer.getTime(), 0, 0

	local function event(name, a, ...)
		if name == __quit__ and not love.quit() then
			return a or 0, ...
		end
		if eventhandlers[name] then return eventhandlers[name](clock, a, ...) end
		return love.handlers[name](a, ...)
	end

	return function()
		pump()
		for name, a, b, c, d, e, f in poll do
			a, b = event(name, a, b, c, d, e, f)
			if a then return a, b end
		end

		cap = 1 / (focused and love.FPScap or love.unfocusedFPScap)
		dt, clock = love.timer.step(), love.timer.getTime()
		if focused or not love.autoPause then
			love.update(dt);
			if love.graphics.isActive() and clock > nextdraw - dt then
				if love.vsync ~= nil and love.window.setVSync then
					love.window.setVSync(love.vsync and 1 or 0)
				end
				origin(); clear(getBgColor()); love.draw(); present()
				nextdraw, sinceLastFps, frames = cap + clock, clock - prevFpsUpdate, frames + 1
				if sinceLastFps > 0.5 then
					fps, prevFpsUpdate, frames = math.round(frames / sinceLastFps), clock, 0
				end
			end
		end

		if love.window.hasFocus() then
			sleep(dt < 0.001 and 0.001 or 0)
			collectgarbage(__step__)
			focused = true
		else
			if focused then
				collectgarbage(); collectgarbage()
			else
				collectgarbage(__step__)
			end
			focused = sleep(cap)
		end
	end
end

function love.handlers.fullscreen(f, t)
	love.fullscreen(f, t)
end

local _ogGetFPS = love.timer.getFPS

---@return number -- Returns the current ticks per second.
love.timer.getTPS = _ogGetFPS

---@return number -- Returns the current frames per second.
function love.timer.getFPS() return fps end

-- fix a bug where love.window.hasFocus doesnt return the actual focus in Mobiles
local _ogSetFullscreen = love.window.setFullscreen
if isMobile then
	local _f = true
	function love.window.hasFocus()
		return _f
	end

	function love.handlers.focus(f)
		_f = f
		if love.focus then return love.focus(f) end
	end

	function love.window.setFullscreen()
		return false
	end
else
	function love.window.setFullscreen(f, t)
		if _ogSetFullscreen(f, t) then
			love.handlers.fullscreen(f, t)
			return true
		end
		return false
	end
end

function love.errorhandler_quit()
	if channel_event_active then channel_event_active:push(0) end
	pcall(love.quit, true)
end

local Gamestate = loxreq "lib.gamestate"
Classic = loxreq "lib.classic"

Point = loxreq "util.point"

Basic = loxreq "basic"
Object = loxreq "object"
Sound = loxreq "sound"
Graphic = loxreq "graphic"
Sprite = loxreq "sprite"
Camera = loxreq "camera"
Text = loxreq "text"
TypeText = loxreq "typetext"

Bar = loxreq "ui.bar"
Group = loxreq "group.group"
SpriteGroup = loxreq "group.spritegroup"
TransitionData = loxreq "transition.transitiondata"
Transition = loxreq "transition.transition"
State = loxreq "state"
Substate = loxreq "substate"
Flicker = loxreq "effects.flicker"
BackDrop = loxreq "effects.backdrop"
Trail = loxreq "effects.trail"
Actor = loxreq "3d.actor"
ActorSprite = loxreq "3d.actorsprite"
ActorGroup = loxreq "group.actorgroup"

AnimateAtlas = loxreq "animateatlas"

VirtualPad = loxreq "virtualpad"
VirtualPadGroup = loxreq "group.virtualpadgroup"

Color = loxreq "util.color"
Timer = loxreq "util.timer"
Tween = loxreq "util.tween"
Signal = loxreq "util.signal"

Toast = loxreq "system.toast"
ui = loxreq "ui"

local function getram()
	local os, handle, result = jit.os

	if os == "Windows" then
		handle = io.popen('wmic computersystem get TotalPhysicalMemory /value | findstr "="')
		if handle then
			result = handle:read("*all")
			handle:close()
			local bytes = result:match("TotalPhysicalMemory=(%d+)")
			return tonumber(bytes)
		end
	elseif os == "Linux" then
		handle = io.popen("free -b | awk '/^Mem:/ {print $2}'")
		if handle then
			result = handle:read("*all")
			handle:close()
			return tonumber(result:match("%d+"))
		end
	elseif os == "OSX" or jit.os == "BSD" then
		handle = io.popen("sysctl -n hw.memsize 2>/dev/null || sysctl -n hw.physmem")
		if handle then
			result = handle:read("*all")
			handle:close()
			return tonumber(result:match("%d+"))
		end
	end
	return 0
end

local function temp() return true end
local metatemp = setmetatable(table, {__index = function() return temp end})
game = {
	bound = {members = {}, scroll = {x = 0, y = 0}, super = metatemp},
	members = {},
	scroll = {x = 0, y = 0},
	super = metatemp,

	width = -1,
	height = -1,
	isSwitchingState = false,
	dt = 0,

	keys = loxreq "input.keyboard",
	mouse = loxreq "input.mouse",
	touch = loxreq "input.touch",
	cameras = loxreq "managers.cameramanager",
	sound = loxreq "managers.soundmanager",
	save = loxreq "util.save",

	system = {
		arch = jit.arch,
		os = love.system.getOS(),
		device = love.system.getDevice(),
		ram = getram()
	}
}

Classic.implement(game, Group)
Classic.implement(game.bound, Group)

TextInput = Signal()

local function triggerCallback(callback, ...) if callback then callback(...) end end

function game.getState(front) return front and Gamestate.current() or Gamestate.stack[1] end

function game.resetState(force, ...) game.switchState(getmetatable(game.getState())(...), force) end

function game.discardTransition() (game.getState() or metatemp):discardTransition() end

local requestedState = nil
function game.switchState(state, force)
	local stateOnCall = game.getState()
	if force or not stateOnCall then
		requestedState = state
		state.skipTransIn = true
		return
	end

	stateOnCall:startOutro(function()
		if game.getState() == stateOnCall then
			requestedState = state
		else
			print("startOutro callback was called after the state was switched. This will be ignored.")
		end
	end)
end

function game.openSubstate(substate) return Gamestate.push(substate) end

function game.closeSubstate(substate)
	Gamestate.pop(table.find(Gamestate.stack, substate))
	for _, o in pairs(substate.members) do
		if type(o) == "table" and o.destroy then o:destroy() end
	end
end

function game.init(app, state, ...)
	local width, height = app.width, app.height
	game.width, game.height = width, height

	Toast.init(love.graphics.getDimensions())
	game:add(Toast)

	local path = loxreq.path:gsub("%.", "/")
	Sprite.defaultTexture = love.graphics.newImage(path .. "/assets/default.png")

	Camera.__init()
	game.cameras.reset()
	game.bound:add(game.cameras)

	Transition.__init(width, height, game.bound)

	love.mouse.setVisible(false)

	triggerCallback(game.onPreStateEnter, state)
	Gamestate.switch(state(...))
end

function game.keypressed(...) game.keys.onPressed(...) end

function game.keyreleased(...) game.keys.onReleased(...) end

function game.touchpressed(id, x, y, dx, dy, p, time)
	VirtualPad.press(id, x, y, p, time)
	game.touch.onPressed(id, x, y, dx, dy, p)
end

function game.touchreleased(id, x, y, dx, dy, p, time)
	VirtualPad.release(id, x, y, p, time)
	game.touch.onReleased(id, x, y, dx, dy, p)
end

function game.touchmoved(id, x, y, dx, dy, p, time)
	game.touch.onMoved(id, x, y, dx, dy, p)
end

function game.wheelmoved(x, y) game.mouse.wheel = y end

function game.mousemoved(x, y) game.mouse.onMoved(x, y) end

function game.mousepressed(x, y, button) game.mouse.onPressed(button) end

function game.mousereleased(x, y, button) game.mouse.onReleased(button) end

function game.textinput(t) TextInput:dispatch(t) end

local function switch(state)
	game.cameras.reset()
	game.sound.destroy()

	game.keys.onPress:destroy()
	game.keys.onRelease:destroy()

	VirtualPad.reset()

	Timer.globalManager:clear()
	Tween.clear()

	triggerCallback(game.onPreStateSwitch, state)

	for _, s in ipairs(Gamestate.stack) do
		for _, o in pairs(s.members) do
			if type(o) == "table" and o.destroy then o:destroy() end
		end
		if s.substate then
			Gamestate.pop(table.find(Gamestate.stack, s.substate))
			for _, o in pairs(s.substate.members) do
				if type(o) == "table" and o.destroy then o:destroy() end
			end
			s.substate = nil
		end
		collectgarbage()
	end

	triggerCallback(game.onPreStateEnter, state)

	Gamestate.switch(state)
	game.isSwitchingState = false

	triggerCallback(game.onPostStateSwitch, state)

	collectgarbage()
end

function game.update(real_dt)
	local dt = game.dt
	local low = math.min(math.log(1.101 + dt), 0.1)
	dt = real_dt - dt > low and dt + low or real_dt

	game.dt = dt

	for _, o in ipairs(Flicker.instances) do o:update(dt) end
	game.sound.update(dt)

	if requestedState ~= nil then
		dt, game.isSwitchingState = 0, true
		requestedState = switch(requestedState)
	end

	if dt ~= 0 then
		if Timer.globalManager then
			Timer.globalManager:update(dt)
		end
		Tween.update(dt)
	end

	if not game.isSwitchingState then Gamestate.update(dt) end
	for _, o in ipairs(game.bound.members) do triggerCallback(o.update, o, dt) end
	for _, o in ipairs(game.members) do triggerCallback(o.update, o, dt) end

	if dt ~= 0 then VirtualPad.updatePress() end

	game.keys.reset()
	game.mouse.reset()
	game.touch.reset()
end

function game.resize(w, h)
	if Project.adaptableWidth then
		local ratio = w / h
		Project.width = math.floor(Project.height * ratio)
		game.width = Project.width
		love.window.updateMode(Project.width, Project.height)
	end
	Gamestate.resize(w, h)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.resize, o, w, h) end
	for _, o in ipairs(game.members) do triggerCallback(o.resize, o, w, h) end
end

function game.focus(f)
	game.sound.onFocus(f)
	Gamestate.focus(f)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.focus, o, f) end
	for _, o in ipairs(game.members) do triggerCallback(o.focus, o, f) end
end

function game.fullscreen(f)
	Gamestate.fullscreen(f)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.fullscreen, o, f) end
	for _, o in ipairs(game.members) do triggerCallback(o.fullscreen, o, f) end
end

function game.quit()
	Gamestate.quit()
	for _, o in ipairs(game.bound.members) do triggerCallback(o.quit, o) end
	for _, o in ipairs(game.members) do triggerCallback(o.quit, o) end
end

local _ogGetScissor, _ogSetScissor, _ogIntersectScissor
local _scX, _scY, _scW, _scH, _scSX, _scSY, _scvX, _scvY, _scvW, _scvH
local function getScissor() return _scvX, _scvY, _scvW, _scvH end
local function getRealScissor()
	return _scvX * _scSX + _scX, _scvY * _scSY + _scY, _scvW * _scSX, _scvH * _scSY
end

local function setScissor(x, y, w, h)
	_scvX, _scvY, _scvW, _scvH = x, y, w, h
	if not x then return _ogSetScissor() end
	_ogSetScissor(getRealScissor())
end

local function intersectScissor(x, y, w, h)
	if not _scvX then
		_scvX, _scvY, _scvW, _scvH = x, y, w, h
		return _ogSetScissor(getRealScissor())
	end
	_scvX, _scvY = math.max(_scvX, x), math.max(_scvY, y)
	_scvW, _scvH = math.max(math.min(_scvX + _scvW, x + w) - _scvX, 0), math.max(math.min(_scvY + _scvH, y + h) - _scvY, 0)
	_ogSetScissor(getRealScissor())
end

-- need a rework
local _scissors, _scissorn = {}, 0
function game.__pushBoundScissor(w, h, sx, sy)
	local idx = _scissorn * 6; _scissorn = _scissorn + 1
	_scissors[idx + 6], _scissors[idx + 5] = _scH, _scW
	_scissors[idx + 4], _scissors[idx + 3] = _scSY, _scSX
	_scissors[idx + 2], _scissors[idx + 1] = _scY, _scX
	_scSX, _scSY = math.abs(_scSX * sx), math.abs(_scSY * sy)
	_scX, _scW = (_scW - _scSX * math.abs(w)) / 2, math.abs(w)
	_scY, _scH = (_scH - _scSY * math.abs(h)) / 2, math.abs(h)
end

function game.__literalBoundScissor(w, h, sx, sy)
	local idx = _scissorn * 6; _scissorn = _scissorn + 1
	_scissors[idx + 6], _scissors[idx + 5] = _scH, _scW
	_scissors[idx + 4], _scissors[idx + 3] = _scSY, _scSX
	_scissors[idx + 2], _scissors[idx + 1] = _scY, _scX
	_scSX, _scSY = math.abs(sx), math.abs(sy)
	_scX, _scW = 0, math.abs(w)
	_scY, _scH = 0, math.abs(h)
end

function game.__popBoundScissor()
	_scissorn = _scissorn - 1; local idx = _scissorn * 4
	_scX, _scY = _scissors[idx + 1], _scissors[idx + 2]
	_scSX, _scSY = _scissors[idx + 3], _scissors[idx + 4]
	_scW, _scH = _scissors[idx + 5], _scissors[idx + 6]
end

function game.draw()
	local grap, w, h = love.graphics, game.width, game.height
	Gamestate.draw()

	local winW, winH = grap.getDimensions()
	local scale, xc, yc, wc, hc = math.min(winW / w, winH / h), grap.getScissor()

	_scW, _scH, _scSX, _scSY = winW, winH, scale, scale
	_scX, _scY = math.floor((winW - _scSX * w) / 2), math.floor((winH - _scSY * h) / 2)
	_scvX, _scvY, _scvW, _scvH = nil, nil, nil, nil

	_ogIntersectScissor, grap.intersectScissor = grap.intersectScissor, intersectScissor
	_ogGetScissor, grap.getScissor = grap.getScissor, getScissor
	_ogSetScissor, grap.setScissor = grap.setScissor, setScissor

	grap.push("all")
	grap.translate(_scX, _scY)
	grap.scale(scale)

	for _, o in ipairs(game.bound.members) do
		if o.__render and (not o._canDraw or o:_canDraw()) then
			o:__render(game)
		end
	end

	grap.pop()

	_ogSetScissor(xc, yc, wc, hc)
	grap.getScissor, grap.setScissor = _ogGetScissor, _ogSetScissor
	grap.intersectScissor = _ogIntersectScissor

	for _, o in ipairs(game.members) do
		if o.__render and (not o._canDraw or o:_canDraw()) then
			o:__render(game)
		end
	end
end
