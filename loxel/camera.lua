---@diagnostic disable: duplicate-set-field
---@class Camera:Object
local Camera = Object:extend("Camera")

local stencilSupport = false
local canvasTable = {nil, stencil = true, depth = false}
local canvasConfig = {format = "normal", dpiscale = 1}

Camera.__defaultCameras = {}
Camera.defaultResolution = 1

local axes_enum = {
	x = 1,
	y = 2,
	xy = 3,
	yx = 3
}

function Camera.__init()
	if love.graphics.getTextureFormats then
		stencilSupport = love.graphics.getTextureFormats({canvas = true})["stencil8"]
	else
		local cv = love.graphics.getCanvas()
		stencilSupport = pcall(love.graphics.setCanvas, canvasTable)
		pcall(love.graphics.setCanvas, cv)
	end

	if not stencilSupport then Camera.draw = Camera.drawSimple end
end

function Camera:new(x, y, width, height)
	Camera.super.new(self, x, y)

	self.simple = true
	self.isSimple = true
	self.clipCam = not Project.flags.loxelDefaultClipCamera == false
	self.antialiasing = true
	self.pixelPerfect = false

	self:resize(
		width and (width > 0 and width) or game.width,
		height and (height > 0 and height) or game.height,
		nil, nil, true
	)

	self.scroll = Point()

	self.rotation = 0
	self.angle = 0
	self._zoom = Point(1, 1)

	self.target = nil
	self.followType = nil
	self.followLerp = 0

	self.bgColor = {0, 0, 0, 0}
	self.__zoom = Point(1, 1)
	self.__renderQueue = {}

	self.__flashColor = Color.WHITE
	self.__flashAlpha = 0
	self.__flashDuration = 0
	self.__flashComplete = nil

	self.__fadeColor = Color.WHITE
	self.__fadeAlpha = 0
	self.__fadeDuration = 0
	self.__fadeComplete = nil
	self.__fadeIn = false

	self.__shakeX = 0; self.__shakeY = 0
	self.__shakeAxes = 3
	self.__shakeIntensity = 0; self.__shakeDuration = 0
	self.__shakeComplete = nil

	self.freezed = false; self.__freeze = false
end

function Camera:shake(intensity, duration, onComplete, force, axes)
	if not force and (self.__shakeDuration > 0) then return end
	self.__shakeAxes = axes and axes_enum[axes:lower()] or 3
	self.__shakeIntensity = intensity
	self.__shakeDuration = duration or 1
	self.__shakeComplete = onComplete or nil
end

function Camera:flash(color, duration, onComplete, force)
	if not force and (self.__flashAlpha > 0) then return end
	self.__flashColor = color or Color.WHITE
	self.__flashDuration = duration or 1
	self.__flashComplete = onComplete or nil
	self.__flashAlpha = 1
end

function Camera:fade(color, duration, fadeIn, onComplete, force)
	if not force and (self.__fadeDuration > 0) then return end
	self.__fadeColor = color or Color.BLACK
	self.__fadeDuration = duration or 1
	self.__fadeComplete = onComplete or nil
	self.__fadeAlpha = fadeIn and 0.999999 or 0.000001
	self.__fadeIn = fadeIn
end

function Camera:follow(target, type, lerp)
	if target == nil then return end
	self.target = target; self.followType = type; self.followLerp = lerp
end

function Camera:unfollow(resetType)
	if self.target == nil then return end
	self.target = nil
	if resetType then self.followType = nil; self.followLerp = nil end
end

function Camera:snapToTarget()
	if self.target == nil then return end
	self.scroll.x = self.target.x - self.width / 2
	self.scroll.y = self.target.y - self.height / 2
end

function Camera:freeze() self.__freeze = true; self.freezed = not self.isSimple end

function Camera:unfreeze() self.__freeze = false; self.freezed = false end

function Camera:resize(width, height, resX, resY, force)
	resX = resX or Camera.defaultResolution
	resY = resY or resX

	if self.pixelPerfect then resX, resY = 1, 1 end
	if self.width == width and self.height == height and self.__resolutionX == resX and self.__resolutionY == resY then return end

	self.width, self.height, self.resolutionX, self.resolutionY = width, height, resX, resY
	self.__requestCanvas = not force and self.freezed

	if not self.__requestCanvas and Camera.draw ~= Camera.drawSimple then
		if self.canvas then self.canvas:release() end
		canvasConfig.dpiscale = resX
		self.__resolutionX, self.__resolutionY, self.canvas = resX, resY, love.graphics.newCanvas(width, height, canvasConfig)
	end
end

function Camera:update(dt)
	local zoom, target, scroll, w, h = self.zoom, self.target, self.scroll, self.width, self.height
	local isnum = type(zoom) == "number"
	local zx, zy = isnum and zoom or zoom.x, isnum and zoom or zoom.y
	self.__zoom.x, self.__zoom.y = zx, zy

	if target then
		local tx, ty = target.x - w * 0.5, target.y - h * 0.5
		if self.followLerp then
			local lerp = 1 - math.exp(-dt * self.followLerp)
			tx, ty = math.lerp(self.scroll.x, tx, lerp), math.lerp(self.scroll.y, ty, lerp)
		end
		scroll.x, scroll.y = tx, ty
	end

	if self.__flashAlpha > 0 then
		self.__flashAlpha = self.__flashAlpha - dt / self.__flashDuration
		if self.__flashAlpha <= 0 and self.__flashComplete then self.__flashComplete() end
	end

	if self.__fadeDuration > 0 then
		local dir = self.__fadeIn and -1 or 1
		self.__fadeAlpha = self.__fadeAlpha + (dt / self.__fadeDuration) * dir
		if (self.__fadeIn and self.__fadeAlpha <= 0) or (not self.__fadeIn and self.__fadeAlpha >= 1) then
			self.__fadeAlpha = self.__fadeIn and 0 or 1
			if self.__fadeComplete then self.__fadeComplete() end
			self.__fadeDuration = 0
		end
	end

	self.__shakeX, self.__shakeY = 0, 0
	if self.__shakeDuration > 0 then
		self.__shakeDuration = self.__shakeDuration - dt
		if self.__shakeDuration <= 0 then
			if self.__shakeComplete then self.__shakeComplete() end
		else
			local s, axes = self.__shakeIntensity, self.__shakeAxes
			if axes == 1 or axes == 3 then self.__shakeX = (love.math.random() * 2 - 1) * s * w * zx end
			if axes == 2 or axes == 3 then self.__shakeY = (love.math.random() * 2 - 1) * s * h * zy end
		end
	end
end

function Camera:_getCameraBoundary()
	local w, h = self.width, self.height
	return 0, 0, w, h, 1 / math.abs(self.__zoom.x), 1 / math.abs(self.__zoom.y), w / 2, h / 2
end

local abs, rad, sin, cos = math.abs, math.rad, math.fastsin, math.fastcos
function Camera:_check(ox, oy, ow, oh, sfx, sfy)
	local x = ox - self.scroll.x * sfx
	local y = oy - self.scroll.y * sfy
	local cx, cy, cw, ch, csx, csy, cox, coy = self:_getCameraBoundary()

	local hw1, hw2, hh1, hh2 = ow / 2, cw / 2, oh / 2, ch / 2

	if (self.angle or 0) == 0 then
		return abs(cx + hw2 - x - hw1) - hw1 - hw2 * csx < 0 and
			abs(cy + hh2 - y - hh1) - hh1 - hh2 * csy < 0
	end

	local rad2 = rad(self.angle)
	local sin2, cos2 = abs(sin(rad2)), abs(cos(rad2))

	return abs(cx + hw2 - x - hw1) - hw1 - hw2 * cos2 * csx - hh2 * sin2 * csy < 0 and
		abs(cy + hh2 - y - hh1) - hh1 - hh2 * cos2 * csy - hw2 * sin2 * csx < 0
end

function Camera:getZoomXY()
	local isnum = type(self.zoom) == "number"
	self.__zoom.x = isnum and self.zoom or self.zoom.x
	self.__zoom.y = isnum and self.zoom or self.zoom.y
	return self.__zoom.x, self.__zoom.y
end

function Camera:canDraw()
	if not self.visible or not self.exists then return false end
	self:getZoomXY()
	return self.visible and self.exists and (self.bgColor[4] and self.bgColor[4] > 0) or ((
			self.freezed or next(self.__renderQueue) or self.__flashAlpha > 0 or self.__fadeDuration > 0
		) and self.alpha > 0 and (self.scale.x * self.__zoom.x) ~= 0 and (self.scale.y * self.__zoom.y) ~= 0)
end

function Camera:draw()
	if not self.visible or not self.exists then
		table.clear(self.__renderQueue)
		return
	end
	if self.__freeze then return self:drawComplex(true) end
	if not self:canDraw() then
		table.clear(self.__renderQueue)
		return
	end

	local winWidth, winHeight = love.graphics.getDimensions()
	local scale = math.min(winWidth / game.width, winHeight / game.height)

	if self.pixelPerfect or not self.simple or self.shader or (self.antialiasing and
			(self.x ~= math.floor(self.x) or self.y ~= math.floor(self.y) or
				self.scale.x ~= 1 or self.scale.y ~= 1 or
				self.__resolutionX ~= scale or self.__resolutionY ~= scale) or
			scale > 1) or
		self.alpha < 1 or self.rotation ~= 0 then
		self:drawComplex(true)
	else
		self:drawSimple(true)
	end
end

function Camera:destroy()
	Camera.super.destroy(self)
	if self.canvas then self.canvas:release() end
	self.canvas = nil
end

local _simpleCamera, _ogSetColor
local function setSimpleColor(r, g, b, a)
	if type(r) == "table" then
		_ogSetColor(_simpleCamera:getMultColor(r[1], r[2], r[3], r[4]))
	else
		_ogSetColor(_simpleCamera:getMultColor(r, g, b, a))
	end
end

function Camera:drawOverlays(x, y, w, h, scf)
	local grap = love.graphics
	local setC = scf or grap.setColor

	if self.__flashAlpha > 0 then
		local c = self.__flashColor
		setC(c[1], c[2], c[3], self.__flashAlpha)
		grap.rectangle("fill", x, y, w, h)
	end

	if self.__fadeDuration > 0 then
		local c = self.__fadeColor
		setC(c[1], c[2], c[3], self.__fadeAlpha)
		grap.rectangle("fill", x, y, w, h)
	end
end

function Camera:renderObjects(complex)
	local grap, cc = love.graphics, self.clipCam
	local w, h = self.width, self.height
	local w2, h2 = w / 2, h / 2
	grap.push("all")

	if Camera.zoomDebug then
		grap.translate(w2 / 2, h2 / 2)
		grap.scale(0.5, 0.5)
	end

	grap.setBlendMode("alpha", "alphamultiply")
	grap.translate((not cc or not complex) and w2 + self.x + self.__shakeX or w2 + self.__shakeX,
		(not cc or not complex) and h2 + self.y + self.__shakeY or h2 + self.__shakeY)

	local rot = self.angle
	if not complex then rot = rot + self.rotation end
	grap.rotate(math.rad(rot))

	local zx, zy = self.__zoom.x, self.__zoom.y
	if not complex then
		zx = zx * self.scale.x
		zy = zy * self.scale.y
	end
	grap.scale(zx, zy)
	grap.translate(-w2, -h2)

	local queue = self.__renderQueue
	for i = 1, #queue do
		local o = queue[i]
		if type(o) == "function" then
			o(self)
		else
			o:__render(self)
			table.clear(o.__cameraQueue)
		end
	end
	table.clear(queue)
	grap.pop()

	if Camera.zoomDebug then
		-- DEBUG PURPOSES
		grap.push("all")
		grap.setColor(1, 1, 0, 1)
		grap.setLineWidth(2)
		love.graphics.rectangle("line", w2 / 2, h2 / 2, w2, h2)
		grap.pop()
	end
end

function Camera:drawSimple(_skipCheck)
	if not _skipCheck and not self:canDraw() then return end
	self.isSimple = true

	local grap = love.graphics
	grap.push("all")

	_simpleCamera, _ogSetColor, grap.setColor = self, grap.setColor, setSimpleColor
	local x, y, w, h = self.x, self.y, self.width, self.height
	local sx, sy = self.scale.x, self.scale.y
	local w2, h2 = w / 2, h / 2
	local r, g, b, a = grap.getColor()

	if not Project.flags.loxelDisableScissorOnRenderCameraSimple then
		if self.clipCam then
			local gs = game.renderScale or 1
			local csx, csy, csw, csh = grap.getScissor()
			local gox, goy = csx or (game.renderOffset.x or 0), csy or (game.renderOffset.y or 0)
			local csx, csy, csw, csh = gox + (x * gs), goy + (y * gs), w * gs, h * gs
			grap.intersectScissor(csx, csy, csw, csh)
		end
	end

	local r2, g2, b2, a2 = Color.get(self.bgColor)
	if self.bgColor and (not a2 or a2 > 0) then
		_ogSetColor(r2, g2, b2, a2)
		grap.rectangle("fill", x, y, w, h)
		_ogSetColor(r, g, b, a)
	end
	self:renderObjects()
	if self.__flashAlpha > 0 or self.__fadeDuration > 0 then
		grap.push()
		grap.translate(x + self.__shakeX, y + self.__shakeY)
		self:drawOverlays(0, 0, w, h, grap.setColor)
		grap.pop()
	end
	grap.setColor = _ogSetColor
	grap.pop()
end

function Camera:drawComplex(_skipCheck)
	if not _skipCheck and not self:canDraw() then return end
	if self.__requestCanvas and not self.freezed then
		self:resize(self.width, self.height, self.resolutionX, self.resolutionY, true)
	end
	self.isSimple = false

	local canvas, grap = self.canvas, love.graphics
	local cv, cc = grap.getCanvas(), self.clipCam
	local sx, sy, sw, sh = grap.getScissor()

	local x, y, w, h = self.x, self.y, self.width, self.height
	local hw, hh = w / 2, h / 2

	if not self.freezed then
		if self.__freeze then
			self.freezed = next(self.__renderQueue) ~= nil
			self.__freeze = self.freezed
		end

		local _, _, anisotropy = canvas:getFilter()
		local mode = self.antialiasing and "linear" or "nearest"
		canvasTable[1] = canvas
		canvas:setFilter(mode, mode, anisotropy)

		grap.setCanvas(canvasTable); grap.setScissor()

		local color = self.bgColor
		grap.clear(color[1], color[2], color[3], color[4] or 1)

		grap.push("all"); grap.origin()
		local shx, shy = self.__shakeX, self.__shakeY
		local px, py = cc and hw + shx or hw + x + shx, cc and hh + shy or hh + y + shy

		self:renderObjects(true)
		if self.__flashAlpha > 0 or self.__fadeDuration > 0 then
			grap.translate(cc and shx or x + shx, cc and shy or y + shy)
			self:drawOverlays(0, 0, w, h)
		end
		grap.pop()

		grap.setCanvas(cv)
	end

	grap.push("all")
	grap.setScissor(sx, sy, sw, sh)

	local alpha, color, shader, blend = self.alpha, self.color, self.shader, self.blend
	local sx, sy = self.scale.x, self.scale.y

	if self.shader then grap.setShader(self.shader) end
	grap.setBlendMode(blend or "alpha", "premultiplied")
	grap.setColor(color[1] * alpha, color[2] * alpha, color[3] * alpha, alpha)

	local filter = self.antialiasing and "linear" or "nearest"
	canvas:setFilter(filter, filter)

	local scx, scy, min = 1, 1, 1
	if self.pixelPerfect then
		scx, scy = game.width / self.width, game.height / self.height
		min = math.min(scx, scy)
		sx, sy = sx * min, sy * min
	end

	local dx, dy = cc and hw or hw + x, cc and hh or hh + y
	grap.draw(canvas, dx * min, dy * min, math.rad(self.rotation), sx, sy, hw, hh)
	grap.setScissor()

	grap.pop()
end

if Project.flags.loxelForceRenderCameraComplex then
	Camera.draw = Camera.drawComplex
elseif Project.flags.loxelDisableRenderCameraComplex then
	Camera.draw = Camera.drawSimple
end

return Camera
