--[[
	Probably need a rework because the vertices are still locked to 4,
	because its in fixed length,
]]
local rad, fastsin, fastcos = math.rad, math.fastsin, math.fastcos
local max, min = math.max, math.min

local ffi = require("ffi")

ffi.cdef[[
	typedef struct {
		float x, y;
		float u, v, w;
		uint8_t r, g, b, a;
	} ActorVertex;
]]

local VERTEX_SIZE = ffi.sizeof("ActorVertex")

local Animation = loxreq "animation"

local ActorSprite = Actor:extend("ActorSprite")
ActorSprite:implement(Sprite)

-- Actors have their own shader format, to avoid uv affine.
ActorSprite.vertexFormat = {
	{"VertexPosition", "float", 2},
	{"VertexTexCoord", "float", 3},
	{"VertexColor",    "byte",  4}
}

local defaultShader
function ActorSprite.init()
	if defaultShader then return end
	defaultShader = love.graphics.newShader [[
		uniform Image MainTex;
		void effect() {
			love_PixelColor = Texel(MainTex, VaryingTexCoord.xy / VaryingTexCoord.z) * VaryingColor;
		}
	]]
	ActorSprite.defaultShader = defaultShader
	ActorSprite.allMesh = love.graphics.newMesh(ActorSprite.vertexFormat, 4, "fan")
end

function ActorSprite:new(x, y, z, texture)
	ActorSprite.super.new(self, x, y, z)
	ActorSprite.init()

	self.texture = Sprite.defaultTexture

	self.vertices = {
		{0, 0, 0, 0, 0},
		{1, 0, 0, 1, 0},
		{1, 1, 0, 1, 1},
		{0, 1, 0, 0, 1},
	}

	self.vertexData = love.data.newByteData(VERTEX_SIZE * 4)
	self.vertexArray = ffi.cast("ActorVertex*", self.vertexData:getFFIPointer())

	for i = 0, 3 do
		local ptr = self.vertexArray[i]
		ptr.r, ptr.g, ptr.b, ptr.a = 255, 255, 255, 255
	end

	self.mesh = ActorSprite.allMesh
	self.clipRect = nil

	self.frames = nil
	self.animation = Animation(self)

	self.__frames = nil
	self.__animations = {}

	self.__width, self.__height = self.width, self.height
	self.__rectangleMode = false

	if texture then self:loadTexture(texture) end
end

function ActorSprite:destroy()
	ActorSprite.super.destroy(self)

	self.texture = nil
	if self.mesh ~= ActorSprite.allMesh then
		self.mesh:setTexture()
	end

	self.__frames = nil
	self.__animations = nil
end

function ActorSprite:makeUniqueMesh()
	if self.mesh and self.mesh ~= ActorSprite.allMesh then return end
	self.mesh = love.graphics.newMesh(ActorSprite.vertexFormat, self.vertices, "fan")
end

function ActorSprite:setDrawMode(mode)
	if mode == self:getDrawMode() then return end
	self:makeUniqueMesh()
	self.mesh:setDrawMode(mode)
end

function ActorSprite:getDrawMode()
	return self.mesh:getDrawMode()
end

function ActorSprite:update(dt)
	if self.__width ~= self.width or self.__height ~= self.height then
		self:setGraphicSize(self.width, self.height)
		self.__width, self.__height = self.width, self.height
	end

	self.animation:update(dt)

	if self.moves then
		self.velocity.x = self.velocity.x + self.acceleration.x * dt
		self.velocity.y = self.velocity.y + self.acceleration.y * dt
		self.velocity.z = self.velocity.z + self.acceleration.z * dt

		self.x = self.x + self.velocity.x * dt
		self.y = self.y + self.velocity.y * dt
		self.z = self.z + self.velocity.z * dt
	end
end

function ActorSprite:canDraw()
	return self.texture ~= nil and (self.width ~= 0 or self.height ~= 0) and
		ActorSprite.super.canDraw(self)
end

function ActorSprite:__render(camera)
	local r, g, b, a = love.graphics.getColor()
	local shader = love.graphics.getShader()
	local blendMode, alphaMode = love.graphics.getBlendMode()

	local mode = self.antialiasing and "linear" or "nearest"
	local min, mag, anisotropy = self.texture:getFilter()
	self.texture:setFilter(mode, mode, anisotropy)

	local f = self:getCurrentFrame()

	local x, y, z, rx, ry, rz, sx, sy, sz, ox, oy, oz =
		self.x - self.offset.x - (camera.scroll.x * self.scrollFactor.x),
		self.y - self.offset.y - (camera.scroll.y * self.scrollFactor.y),
		self.z - self.offset.z,
		self.rotation.x, self.rotation.y, self.rotation.z - self.angle,
		self.scale.x * self.zoom.x, self.scale.y * self.zoom.y, self.scale.z * self.zoom.z,
		self.origin.x, self.origin.y, self.origin.z

	x, y = x + ox, y + oy

	if self.animation.curAnim then
		local ax, ay = self.animation.curAnim:rotateOffset(self.angle, sx, sy)
		x, y = x - ax, y - ay
	end

	if f and f.rotated then
		ox, oy = ox - 0, oy - f.width + oy
		rz = rz - 90
	end

	local tw, th = self.texture:getWidth(), self.texture:getHeight()
	local fw, fh, uvx, uvy, uvw, uvh = tw, th, 0, 0, 1, 1
	if f then
		ox, oy = ox + f.offset.x, oy + f.offset.y
		uvx, uvy, fw, fh = f.quad:getViewport()
		uvx, uvy, uvw, uvh = uvx / tw, uvy / th, fw / tw, fh / th
	end
	fw, fh, ox, oy, oz = fw * sx, fh * sy, ox * sx, oy * sy, oz * sz

	if self.flipX then uvx, uvw = uvx + uvw, -uvw end
	if self.flipY then uvy, uvh = uvy + uvh, -uvh end

	local hw, hh = game.width / 2, game.height / 2
	local fovMult = self.fov / 180 / 200

	local radx, rady, radz = rad(rx), rad(ry), rad(rz)
	local angx0, angx1 = fastcos(radx), fastsin(radx)
	local angy0, angy1 = fastcos(rady), fastsin(rady)
	local angz0, angz1 = fastcos(radz), fastsin(radz)

	local m11 = angy0 * angz0
	local m12 = -angz1 * angx0 + angx1 * angy1 * angz0
	local m13 =  angx1 * angz1 + angx0 * angy1 * angz0
	local m21 = -angy0 * angz1
	local m22 = -(angx0 * angz0 + angx1 * angy1 * angz1)
	local m23 = -(-angx1 * angz0 + angx0 * angy1 * angz1)
	local m31 =  angy1
	local m32 = -angx1 * angy0
	local m33 = -angx0 * angy0

	local vCount = #self.vertices
	if not self.vertexArray or self.vertexData:getSize() < VERTEX_SIZE * vCount then
		self.vertexData = love.data.newByteData(VERTEX_SIZE * vCount)
		self.vertexArray = ffi.cast("ActorVertex*", self.vertexData:getFFIPointer())
		for i = 0, vCount - 1 do
			local ptr = self.vertexArray[i]
			ptr.r, ptr.g, ptr.b, ptr.a = 255, 255, 255, 255
		end
	end

	for i = 1, vCount do
		local v = self.vertices[i]

		local gapx = (v[1] * fw) - ox
		local gapy = oy - (v[2] * fh)
		local gapz = oz - (v[3] * sz)

		local vx = ox + m11 * gapx + m12 * gapy + m13 * gapz
		local vy = oy + m21 * gapx + m22 * gapy + m23 * gapz
		local vz = oz + m31 * gapx + m32 * gapy + m33 * gapz

		local z_calc = vz + z - oz
		local z_proj = max((z_calc * fovMult) + 1, 0.00001)
		local invZ = 1 / z_proj

		local ptr = self.vertexArray[i - 1]
		ptr.x = hw + (vx + x - ox - hw) * invZ
		ptr.y = hh + (vy + y - oy - hh) * invZ
		ptr.u = (v[4] * uvw + uvx) * invZ
		ptr.v = (v[5] * uvh + uvy) * invZ
		ptr.w = invZ

		if v[6] then
			ptr.r, ptr.g, ptr.b, ptr.a = v[6], v[7], v[8], v[9]
		else
			ptr.r, ptr.g, ptr.b, ptr.a = 255, 255, 255, 255
		end
	end

	local mesh = self.mesh
	mesh:setVertices(self.vertexData)
	mesh:setDrawRange(1, vCount)

	if mesh:getTexture() ~= self.texture then mesh:setTexture(self.texture) end
	love.graphics.setShader(self.shader or defaultShader)
	love.graphics.setBlendMode(self.blend)
	love.graphics.setColor(self:getDrawColor())
	love.graphics.draw(mesh)

	love.graphics.setColor(r, g, b, a)
	love.graphics.setBlendMode(blendMode, alphaMode)
	love.graphics.setShader(shader)
end

ActorSprite.updateHitbox  = Sprite.updateHitbox
ActorSprite.centerOffsets = Sprite.centerOffsets
ActorSprite.fixOffsets    = Sprite.fixOffsets
ActorSprite.centerOrigin  = Sprite.centerOrigin

return ActorSprite
