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

local function mod(val, step, tar, max)
	return val - math[max and "ceil" or "floor"]((val - tar) / step) * step
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
end

function Backdrop:_getBoundary() return 0, 0, 0, 0, 1, 1, 0, 0 end

function Backdrop:_isOnScreen() return true end
function Backdrop:isOnScreen() return true end

local round = math.round
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
	if camera.pixelPerfect then ox, oy = round(ox), round(oy) end

	local fw, fh = self:getFrameDimensions()
	fw, fh = fw * math.abs(sx), fh * math.abs(sy)

	local tsx, tsy = spx + fw, spy + fh
	local tx, ty, hasX, hasY = 1, 1, self.axes:find("x"), self.axes:find("y")

	local zoom = camera.zoom or 1
	
	if hasX then
		local l, r = mod(x + fw, tsx, 0) - fw, mod(x, tsx, camera.width / zoom, true) + tsx
		tx, x = math.ceil((r - l) / tsx), mod(x + fw, fw + spx, 0) - fw
	end
	
	if hasY then
		local t, b = mod(y + fh, tsy, 0) - fh, mod(y, tsy, camera.height / zoom, true) + tsy
		ty, y = math.ceil((b - t) / tsy), mod(y + fh, fh + spy, 0) - fh
	end

	love.graphics.shear(kx, ky)

	for tlx = 0, tx do
		for tly = 0, ty do
			local xx, yy = x + tsx * tlx, y + tsy * tly
			if camera.pixelPerfect then xx, yy = round(xx), round(yy) end

			if self.clipRect then
				stencilSprite, stencilX, stencilY = self, xx, yy
				love.graphics.stencil(stencil, "replace", 1, false)
				love.graphics.setStencilTest("greater", 0)
			end

			if f then
				love.graphics.draw(self.texture, f.quad, xx, yy, rad, sx, sy, ox, oy)
			else
				love.graphics.draw(self.texture, xx, yy, rad, sx, sy, ox, oy)
			end
		end
	end

	love.graphics.setStencilTest()
	self.texture:setFilter(min, mag, anisotropy)

	love.graphics.pop()
end

function Backdrop:destroy()
	Backdrop.super.destroy(self)
	if self.__releaseTexture then
		self.texture:release()
	end
end

return Backdrop
