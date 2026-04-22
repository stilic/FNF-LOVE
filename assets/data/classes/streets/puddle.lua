local Puddle = Sprite:extend("Puddle")

-- TODO rewrite this too. extremely inefficient - kaoy

local mask_shader = love.graphics.newShader[[
	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		if ( Texel(texture, texture_coords).a <= 0.3 ) { discard; }
		return vec4(1.0);
	}
]]

function Puddle:new(x, y, texture, copy)
	Puddle.super.new(self, x, y, texture)

	self.copyFrom = copy or game.camera
	self.copyFrom.isSimple = false

	if self.texture then
		local texW, texH = self.texture:getDimensions()
		self.canvas = love.graphics.newCanvas(texW, texH)
	end

	self.framerate = 1 / 35
	self.elapsed = 0
end

function Puddle:update(dt)
	self.elapsed = self.elapsed + dt
	if self.elapsed >= self.framerate then
		self.elapsed = 0

		if self.canvas and self.copyFrom then
			self.canvas:renderTo(function()
				love.graphics.push("all")
				love.graphics.clear()

				local copyW, copyH = self.copyFrom.canvas:getDimensions()
				local canvasW, canvasH = self.canvas:getDimensions()

				local scaleX = canvasW / copyW
				local scaleY = (canvasH / copyH) * 2.3

				local scrollOffset = (game.camera.scroll.x * 1.8) - 1322
				local skewFactor = scrollOffset * 0.002

				love.graphics.shear(skewFactor, 0)

				love.graphics.draw(self.copyFrom.canvas, 0, canvasH * 1.4, 0, scaleX, -scaleY)
				love.graphics.pop()
			end)
		end
	end
	Puddle.super.update(self, dt)
end

function Puddle:__render(camera)
	if not self.canvas or not self.texture then return end
	love.graphics.push("all")

	local x, y, rad, sx, sy, ox, oy = self:setupDrawLogic(camera)

	love.graphics.stencil(function()
		love.graphics.push("all")
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setShader(mask_shader)
		love.graphics.setBlendMode("alpha")
		love.graphics.draw(self.texture, x, y, rad, sx, sy, ox, oy)
		love.graphics.pop()
	end, "replace", 1, false)

	love.graphics.setStencilTest("greater", 0)
	love.graphics.draw(self.canvas, x, y, rad, sx, sy, ox, oy)
	love.graphics.setStencilTest()

	love.graphics.pop()
end

function Puddle:destroy()
	Puddle.super.destroy(self)
	if self.canvas then
		self.canvas:release()
	end
end

return Puddle
