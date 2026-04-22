local stencilSprite, stencilX, stencilY = nil, 0, 0

local function stencil()
	if stencilSprite then
		love.graphics.push()
		love.graphics.translate(
			stencilX + stencilSprite.clipRect.x + stencilSprite.clipRect.width / 2,
			stencilY + stencilSprite.clipRect.y + stencilSprite.clipRect.height / 2
		)
		love.graphics.rotate(stencilSprite.angle)
		love.graphics.translate(-stencilSprite.clipRect.width / 2, -stencilSprite.clipRect.height / 2)
		love.graphics.rectangle(
			"fill",
			-stencilSprite.width / 2,
			-stencilSprite.height / 2,
			stencilSprite.clipRect.width,
			stencilSprite.clipRect.height
		)
		love.graphics.pop()
	end
end

local Backdrop = Sprite:extend("Backdrop")

local function makeSprite(size, colors)
	colors = colors or {{0, 0, 0, 0}, {1, 1, 1, 1}}
	local data = love.image.newImageData(size, size)

	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local fill = (x < size / 2) ~= (y < size / 2)
			local c = fill and colors[1] or colors[2]
			data:setPixel(x, y, c[1], c[2], c[3], c[4] or 1)
		end
	end
	return love.graphics.newImage(data)
end

function Backdrop:new(texture, axes, sx, sy)
	if not Backdrop.defaultSprite then
		Backdrop.defaultSprite = makeSprite(32)
	end

	if texture and type(texture) == "number" or type(texture) == "table" then
		local tbl = type(texture) == "table"
		texture = makeSprite(tbl and texture[1] or texture, tbl and texture[2])
		self.__releaseTexture = true
	end

	Backdrop.super.new(self, 0, 0, texture or Backdrop.defaultSprite)
	self.antialiasing = not self.__releaseTexture

	self._batch = love.graphics.newSpriteBatch(self.texture, 100)
	self._ids = {}

	self.axes = axes or "xy"
	self.spacing = {
		x = sx or 0,
		y = sy or 0,
		set = function(this, x, y)
			this.x = x or this.x
			this.y = y or this.y
		end
	}
end

function Backdrop:loadTexture(...)
	Backdrop.super.loadTexture(self, ...)
	self.__releaseTexture = false

	if self._batch then
		self._batch:setTexture(self.texture)
		self._batch:clear()
		self._ids = {}
	else
		self._batch = love.graphics.newSpriteBatch(self.texture, 100)
		self._ids = {}
	end
end

function Backdrop:getLocalBounds() return 0, 0, 0, 0 end
function Backdrop:isOnScreen() return true end

local ceil, floor = math.ceil, math.floor

function Backdrop:__render(camera)
	love.graphics.push("all")

	local mode = self.antialiasing and "linear" or "nearest"
	local min, mag, anisotropy = self.texture:getFilter()
	self.texture:setFilter(mode, mode, anisotropy)

	local f = self:getCurrentFrame()

	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	local spx, spy = self.spacing.x * self.scale.x, self.spacing.y * self.scale.y

	if self.flipX then sx = -sx end
	if self.flipY then sy = -sy end

	if f then ox, oy = ox + f.offset.x, oy + f.offset.y end

	local fw, fh = self:getFrameDimensions()
	local tileW = (fw + spx) * math.abs(sx)
	local tileH = (fh + spy) * math.abs(sy)

	local zoomX = (type(camera.zoom) == "number" and camera.zoom or camera.zoom.x) or 1
	local zoomY = (type(camera.zoom) == "number" and camera.zoom or camera.zoom.y) or 1

	local viewW = camera.width / zoomX
	local viewH = camera.height / zoomY

	local viewLeft = (camera.width / 2) - (viewW / 2)
	local viewTop  = (camera.height / 2) - (viewH / 2)

	local viewRight = viewLeft + viewW
	local viewBottom = viewTop + viewH

	local i_min, i_max = 0, 0
	local j_min, j_max = 0, 0

	local ox_scaled = ox * math.abs(sx)
	local oy_scaled = oy * math.abs(sy)
	local left_margin = (fw - ox) * math.abs(sx)
	local top_margin = (fh - oy) * math.abs(sy)

	if self.axes:find("x") then
		i_min = floor((viewLeft - x - left_margin) / tileW) + 1
		i_max = ceil((viewRight - x + ox_scaled) / tileW) - 1
	end

	if self.axes:find("y") then
		j_min = floor((viewTop - y - top_margin) / tileH) + 1
		j_max = ceil((viewBottom - y + oy_scaled) / tileH) - 1
	end

	love.graphics.shear(kx, ky)

	if self.clipRect then
		for i = i_min, i_max do
			for j = j_min, j_max do
				local xx = x + (i * tileW)
				local yy = y + (j * tileH)

				if camera.pixelPerfect then xx, yy = floor(xx), floor(yy) end

				stencilSprite, stencilX, stencilY = self, xx, yy
				love.graphics.stencil(stencil, "replace", 1, false)
				love.graphics.setStencilTest("greater", 0)

				if f then
					love.graphics.draw(self.texture, f.quad, xx, yy, rad, sx, sy, ox, oy)
				else
					love.graphics.draw(self.texture, xx, yy, rad, sx, sy, ox, oy)
				end
			end
		end
		love.graphics.setStencilTest()
	else
		local q = f and f.quad or nil
		local idIndex = 1

		for i = i_min, i_max do
			for j = j_min, j_max do
				local xx = x + (i * tileW)
				local yy = y + (j * tileH)

				if camera.pixelPerfect then xx, yy = floor(xx), floor(yy) end

				local cid = self._ids[idIndex]
				if cid then
					if q then
						self._batch:set(cid, q, xx, yy, rad, sx, sy, ox, oy, kx, ky)
					else
						self._batch:set(cid, xx, yy, rad, sx, sy, ox, oy, kx, ky)
					end
				else
					if q then
						self._ids[idIndex] = self._batch:add(q, xx, yy, rad, sx, sy, ox, oy, kx, ky)
					else
						self._ids[idIndex] = self._batch:add(xx, yy, rad, sx, sy, ox, oy, kx, ky)
					end
				end
				idIndex = idIndex + 1
			end
		end
		for k = idIndex, #self._ids do self._batch:set(self._ids[k], 0, 0, 0, 0, 0) end
		love.graphics.draw(self._batch)
	end

	self.texture:setFilter(min, mag, anisotropy)
	love.graphics.pop()
end

function Backdrop:destroy()
	Backdrop.super.destroy(self)
	if self._batch then self._batch:release() end
	if self.__releaseTexture then
		self.texture:release()
	end
end

return Backdrop
