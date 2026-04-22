io.stdout:setvbuf("no")

local cupid
require "loxel"
local funkin = require "funkin"

function love.load(args)
	funkin.load()
	if args then
		for i = 1, #args do
			if args[i] == "--terminal" then
				cupid = require "lib.cupid"
				cupid.setup()
				break
			end
		end
	end
end

function love.resize(w, h) game.resize(w, h) end

function love.keypressed(key, ...)
	if key == "f5" then
		game.resetState(true)
	elseif Project.DEBUG_MODE and love.keyboard.isDown("lctrl", "rctrl") then
		if key == "f4" then error("force crash") end
		if key == "`" then return "restart" end
	elseif key == "f12" then
		Object.showBoundary = not Object.showBoundary
	end
	controls:onKeyPress(key, ...)
	game.keypressed(key, ...)
end

function love.keyreleased(...)
	controls:onKeyRelease(...)
	game.keyreleased(...)
end

function love.textinput(t) game.textinput(t) end

function love.wheelmoved(...) game.wheelmoved(...) end

function love.mousemoved(...) game.mousemoved(...) end

function love.mousepressed(...) game.mousepressed(...) end

function love.mousereleased(...) game.mousereleased(...) end

function love.touchpressed(...) game.touchpressed(...) end

function love.touchmoved(...) game.touchmoved(...) end

function love.touchreleased(...) game.touchreleased(...) end

function love.update(dt)
	funkin.update(dt)
	game.update(dt)
	if cupid then cupid.update() end
end

function love.heartbeat()
	funkin.heartbeat()
	game.heartbeat()
end

function love.draw() game.draw() end

function love.focus(f) game.focus(f) end

function love.fullscreen(f, t)
	funkin.fullscreen(f)
	game.fullscreen(f)
end

function love.quit()
	funkin.quit()
	game.quit()
	if cupid then cupid.quit() end
end

function love.errorhandler(msg)
	if cupid then cupid.quit() end
	return funkin.throwError(msg)
end
