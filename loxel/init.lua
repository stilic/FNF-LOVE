local ffi = require "ffi"

loxreq = setmetatable({path = (...) .. "."}, {
	__call = function(_, f) return require(loxreq.path .. f) end
})

require "love.window"
loxreq "lib.override"
ogprint = print

Project = require "project"
Logger = loxreq "system.logger"

RenderUtil = loxreq "util.render"

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

local STEP, QUIT = "step", "quit"
local dt, fps = 0, 0

function love.run()
	local cg, l, floor, Project = collectgarbage, love, math.floor, Project
	local timer, graphics, event, window = l.timer, l.graphics, l.event, l.window

	l.FPScap, l.unfocusedFPScap, l.autoPause = Project.FPS, 16, Project.flags.loxelInitialAutoPause
	l.vsync = Project.vSync; if window.setVSync then window.setVSync(l.vsync and 1 or 0) end
	if l.math then l.math.setRandomSeed(os.time()) end
	if l.load then l.load(l.arg.parseGameArguments(arg), arg) end

	timer.step(); cg()

	local step, getTime, sleep, gcint, gctimer = timer.step, timer.getTime, timer.sleep, 2, 0
	local origin, clear, present = graphics.origin, graphics.clear, graphics.present
	local getBgColor, isActive = graphics.getBackgroundColor, graphics.isActive
	local pump, poll, handlers = event.pump, event.poll, l.handlers
	local update, draw, heartbeat, quit = l.update, l.draw, l.heartbeat, l.quit
	local clock, acc, prevfpsu, frames, cap, focused, lastfps, lt = 0, 0, 0, getTime(), 0, 0, true, 0, 0

	local registry = {}; for k, v in pairs(l.handlers) do registry[k] = v end
	registry['keypressed']	   = function(b, s, r, _,_,_, t) return l.keypressed(b, s, r, t) end
	registry['keyreleased']	  = function(b, s, _,_,_,_, t) return l.keyreleased(b, s, t) end
	registry['touchpressed']	 = function(id, x, y, dx, dy, p, t) return l.touchpressed(id, x, y, dx, dy, p, t) end
	registry['touchmoved']	   = function(id, x, y, dx, dy, p, t) return l.touchmoved(id, x, y, dx, dy, p, t) end
	registry['touchreleased']	= function(id, x, y, dx, dy, p, t) return l.touchreleased(id, x, y, dx, dy, p, t) end
	registry['joystickpressed']  = function(j, b, _,_,_,_, t) if l.joystickpressed then return l.joystickpressed(j, b, t) end end
	registry['joystickreleased'] = function(j, b, _,_,_,_, t) if l.joystickreleased then return l.joystickreleased(j, b, t) end end
	registry['gamepadpressed']   = function(j, b, _,_,_,_, t) if l.gamepadpressed then return l.gamepadpressed(j, b, t) end end
	registry['gamepadreleased']  = function(j, b, _,_,_,_, t) if l.gamepadreleased then return l.gamepadreleased(j, b, t) end end

	return function()
		pump()
		clock = getTime()
		for name, a, b, c, d, e, f in poll() do
			if name == QUIT and not quit() then return a or 0; else
			local h = registry[name]; if h then h(a, b, c, d, e, f, clock) end end
		end

		dt = step()
		acc, cap = acc + dt, 1 / (focused and l.FPScap or l.unfocusedFPScap)
		if focused or not l.autoPause then
			update(dt)
			lt = lt + dt
			if lt >= 1 then lt = lt - 1; if heartbeat then heartbeat() end end
			if isActive() and acc >= cap then
				origin(); clear(getBgColor()); draw(); present()
				frames, lastfps, acc = frames + 1, clock - prevfpsu, acc - cap
				if acc > cap then acc = 0 end
				if lastfps >= 1 then fps, frames, prevfpsu = floor(frames / lastfps + 0.5), 0, clock end
			end
		end
		if window.hasFocus() then
			focused = true; sleep(0.001); cg(STEP)
		else
			if focused then cg(); cg() else cg(STEP) end
			focused = sleep(cap - acc > 0.001 and cap - acc or 0.001)
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
	pcall(love.quit, true)
end

Classic = loxreq "lib.classic"
Stub = loxreq "stub"

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
	elseif os == "OSX" or os == "BSD" then
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

	renderScale = 1,
	renderOffset = Point(),

	width = -1,
	height = -1,
	isSwitchingState = false,
	dt = 0,

	keys = loxreq "input.keyboard",
	mouse = loxreq "input.mouse",
	touch = loxreq "input.touch",
	state = loxreq "managers.statemanager",
	cameras = loxreq "managers.cameramanager",
	sound = loxreq "managers.soundmanager",
	save = loxreq "util.save",

	system = {
		arch = jit.arch,
		os = love.system.getOS(),
		device = love.system.getDevice(),
		ram = getram(),

		power = {state = "unknown", percent = 0}
	}
}

Classic.implement(game, Group)
Classic.implement(game.bound, Group)

TextInput = Signal()

local function triggerCallback(callback, ...) if callback then callback(...) end end

function game.getState(front) return front and game.state.current() or game.state.stack[1] end

function game.resetState(force, ...)
	game.switchState(getmetatable(game.getState())(...), force)
	collectgarbage()
end

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
			Logger.log("warn", "startOutro callback was called after the state was switched. This will be ignored.")
		end
	end)
end

function game.openSubstate(substate)
	return game.state.push(substate)
end

function game.closeSubstate(substate)
	game.state.pop(table.find(game.state.stack, substate))
	for _, o in pairs(substate.members) do
		if type(o) == "table" and o.destroy then o:destroy() end
	end
end

function game.init(app, state, ...)
	local width, height = app.width, app.height
	game.width, game.height = width, height

	RenderUtil.init()

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
	game.state.switch(state(...))
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

	for _, s in ipairs(game.state.stack) do
		for _, o in pairs(s.members) do
			if type(o) == "table" and o.destroy then o:destroy() end
		end
		if s.substate then
			game.state.pop(table.find(game.state.stack, s.substate))
			for _, o in pairs(s.substate.members) do
				if type(o) == "table" and o.destroy then o:destroy() end
			end
			s.substate = nil
		end
	end

	triggerCallback(game.onPreStateEnter, state)

	game.state.switch(state)
	game.isSwitchingState = false

	triggerCallback(game.onPostStateSwitch, state)
	jit.flush()
	collectgarbage("collect")
	if game.system.os == "Linux" then
		pcall(function()
			ffi.cdef[[void malloc_trim(size_t);]]
			ffi.C.malloc_trim(0)
		end)
	elseif game.system.os == "Windows" then
		pcall(function()
			ffi.cdef[[
				void* GetProcessHeap();
				size_t HeapCompact(void* hHeap, uint32_t dwFlags);
			]]
			ffi.C.HeapCompact(ffi.C.GetProcessHeap(), 0)
		end)
	end
	collectgarbage()
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

	if not game.isSwitchingState then game.state.update(dt) end
	for _, o in ipairs(game.bound.members) do triggerCallback(o.update, o, dt) end
	for _, o in ipairs(game.members) do triggerCallback(o.update, o, dt) end

	if dt ~= 0 then VirtualPad.updatePress() end

	game.keys.reset()
	game.mouse.reset()
	game.touch.reset()
end

function game.heartbeat()
	local state, percent = love.system.getPowerInfo()
	game.system.power.state, game.system.power.percent = state, percent or -1
end

function game.resize(w, h)
	if Project.adaptableWidth then
		local ratio, ratio2 = w / h, game.width / game.height
		local should = math.max(ratio, ratio2) ~= ratio2
		if should then
			game.width = math.floor(game.height * ratio)
			Transition.width = game.width
			for _, c in pairs(game.cameras.list) do
				c:resize(game.width, game.height)
			end
		end
	end
	game.state.resize(w, h)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.resize, o, w, h) end
	for _, o in ipairs(game.members) do triggerCallback(o.resize, o, w, h) end
end

function game.focus(f)
	game.sound.onFocus(f)
	game.state.focus(f)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.focus, o, f) end
	for _, o in ipairs(game.members) do triggerCallback(o.focus, o, f) end
end

function game.fullscreen(f)
	game.state.fullscreen(f)
	for _, o in ipairs(game.bound.members) do triggerCallback(o.fullscreen, o, f) end
	for _, o in ipairs(game.members) do triggerCallback(o.fullscreen, o, f) end
end

function game.quit()
	game.state.quit()
	for _, o in ipairs(game.bound.members) do triggerCallback(o.quit, o) end
	for _, o in ipairs(game.members) do triggerCallback(o.quit, o) end
end

game.preRenders = {}

function game.draw()
	local grap = love.graphics
	local w, h, ww, wh = game.width, game.height, grap.getDimensions()
	local scale = math.min(ww / w, wh / h)
	local tx, ty = math.floor((ww - w * scale) / 2), math.floor((wh - h * scale) / 2)
	game.renderScale = scale
	game.renderOffset:set(tx, ty)

	game.state.draw()
	grap.push("all")
		grap.translate(tx, ty)
		grap.scale(scale)
		grap.intersectScissor(tx, ty, math.ceil(w * scale), math.ceil(h * scale))

		for _, o in ipairs(game.bound.members) do
			if o.__render and (not o.canDraw or o:canDraw()) then
				o:__render(game)
			end
		end
		grap.setScissor()
	grap.pop()

	grap.push("all")
		for _, o in ipairs(game.members) do
			if o.__render and (not o.canDraw or o:canDraw()) then
				o:__render(game)
			end
		end
	grap.pop()
end
