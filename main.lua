io.stdout:setvbuf("no")

require "loxel"
local funkin = require "funkin"

function love.load() funkin.load() end

function love.resize(w, h) game.resize(w, h) end

function love.keypressed(key, ...)
	if key == "f5" and not game.getState():is(PlayState) then
		game.resetState(true)
	elseif Project.DEBUG_MODE and love.keyboard.isDown("lctrl", "rctrl") then
		if key == "f4" then error("force crash") end
		if key == "`" then return "restart" end
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
end

function love.errorhandler(msg) return funkin.throwError(msg) end
