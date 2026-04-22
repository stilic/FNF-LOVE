local maskShader

local Library = loxreq "animateatlas.library"
local AnimationController = loxreq "animateatlas.animation"
local Boundary = loxreq "animateatlas.boundary"
local Matrix = loxreq "animateatlas.matrix"
local ColorTransform = loxreq "animateatlas.color"
local Filters = loxreq "animateatlas.filters"

local m_min = math.min
local m_max = math.max
local m_ceil = math.ceil
local m_floor = math.floor
local m_pi_2 = math.pi / 2

local canvasConfig = {nil, stencil = true, depth = false}
local canvasTable = {dpiscale = 1}

local ffi = require "ffi"

local newColorArray, copyColorArray

if Project.flags.jitFFI then
	newColorArray = function(cap)
		if not cap then return ffi.new("AtlasColor") end
		return ffi.new("AtlasColor[?]", cap)
	end
	copyColorArray = function(dst, src, count)
		ffi.copy(dst, src, ffi.sizeof("AtlasColor") * count)
	end
else
	newColorArray = function(cap)
		local arr, cap = {}, cap
		if not cap then return {rm=0, gm=0, bm=0, am=0, ro=0, go=0, bo=0, ao=0} end
		for i = 0, cap do
			arr[i] = {rm=0, gm=0, bm=0, am=0, ro=0, go=0, bo=0, ao=0}
		end
		return arr
	end
	copyColorArray = function(dst, src, count)
		for i = 0, count - 1 do
			dst[i] = src[i]
		end
	end
end

local function pushTransform(self)
	self.tfIndex = self.tfIndex + 1
	if not self.tfStack[self.tfIndex] then
		self.tfStack[self.tfIndex] = love.math.newTransform()
	end
	return self.tfStack[self.tfIndex]
end

local function popTransform(self)
	self.tfIndex = self.tfIndex - 1
end

local function pushColor(self)
	self.colorIndex = self.colorIndex + 1
	if self.colorIndex >= self.colorStackCap then
		local oldCap = self.colorStackCap
		self.colorStackCap = self.colorStackCap * 2
		local newStack = newColorArray(self.colorStackCap + 1)
		copyColorArray(newStack, self.colorStack, oldCap + 1)
		self.colorStack = newStack
	end
	return self.colorStack[self.colorIndex]
end

local function popColor(self)
	self.colorIndex = math.max(1, self.colorIndex - 1)
end

local AnimateAtlas = Object:extend("AnimateAtlas")
AnimateAtlas:implement(Boundary)

AnimateAtlas.renderOnCanvas = Project.flags.animateAtlasRenderCanvas
AnimateAtlas.canvasQuality = Project.flags.animateAtlasQuality

function AnimateAtlas:new(x, y, library)
	AnimateAtlas.super.new(self, x, y)
	self.frame = 0
	self.symbol = ""

	self.tfStack = {}
	self.tfIndex = 0

	self.colorStackCap = 8
	self.colorStack = newColorArray(self.colorStackCap)
	self.colorIndex = 1

	self.colorStack[1].rm, self.colorStack[1].gm, self.colorStack[1].bm, self.colorStack[1].am = 1, 1, 1, 1
	self.colorStack[1].ro, self.colorStack[1].go, self.colorStack[1].bo, self.colorStack[1].ao = 0, 0, 0, 0

	if library then self:load(library) end

	self._curSymbol = nil
	self._frameTimer = 0

	self._batchCache = {}
	self._currentBatch = nil
	self._lastTexture = nil
	self._lastBlendMode = "alpha"
	self._lastColorData = nil
	self.__transform = love.math.newTransform()

	self._layersMapCache = table.new(0, 16)

	self.animation = AnimationController(self)
	self.colorTransform = ColorTransform()
	self.filters = Filters()

	self._canvas = nil
	self._canvasOffsetX = 0
	self._canvasOffsetY = 0
	self._lastCanvasSymbol = nil

	if not maskShader then
		maskShader = love.graphics.newShader[[
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
				float alpha = Texel(texture, texture_coords).a;
				if (alpha == 0.0) { discard; }
				return vec4(alpha);
			}
		]]
	end

	self._lastColorValues = newColorArray()
	self._lastColorValues.rm, self._lastColorValues.gm, self._lastColorValues.bm, self._lastColorValues.am = 1, 1, 1, 1
end

function AnimateAtlas:load(library)
	if self._mustRelease then
		self.library:destroy()
	end
	self._mustRelease = false

	if type(library) == 'string' then
		self.library = Library(library)
		self._mustRelease = true
	elseif type(library) == 'table' and library.is and library:is(AnimateLibrary) then
		self.library = library
	else
		error("incorrect type loaded, it must be an AnimateLibrary object or a string")
	end
	self:precalculateBounds()
end

function AnimateAtlas:_flushCurrentBatch()
	if self._currentBatch then
		if self._lastColorData then
			love.graphics.setShader(self.colorTransform:getShader())
			self.colorTransform:applyRawTransform(self._lastColorValues, true)
		end

		love.graphics.setBlendMode(self._lastBlendMode)
		love.graphics.draw(self._currentBatch)
		self._currentBatch:clear()

		if self._lastColorData then love.graphics.setShader() end
	end
end

function AnimateAtlas:flush()
	self:_flushCurrentBatch()
	self._currentBatch = nil
	self._lastTexture = nil
	self._lastColorData = nil
	local v = self._lastColorValues
	v.rm, v.gm, v.bm, v.am = 1, 1, 1, 1
	v.ro, v.go, v.bo, v.ao = 0, 0, 0, 0
end

local function queueSprite(self, name_id, matrix, colorStruct)
	local tex = self.library.sprite_textures[name_id]
	local quad = self.library.sprite_quads[name_id]
	if not tex or not quad then return end

	local activeColorData = colorStruct
	local blendMode = "alpha"
	local stateChanged = false

	if tex ~= self._lastTexture then stateChanged = true end
	if blendMode ~= self._lastBlendMode then stateChanged = true end

	if not stateChanged then
		stateChanged = not self.colorTransform:areEqual(self._lastColorValues, activeColorData)
	end

	if stateChanged then
		self:_flushCurrentBatch()
		self._lastTexture = tex
		self._lastBlendMode = blendMode

		copyColorArray(self._lastColorValues, colorStruct, 1)
		if colorStruct ~= self.colorStack[1] then
			self._lastColorData = true
		else
			self._lastColorData = nil
		end

		if not self._batchCache[tex] then
			self._batchCache[tex] = love.graphics.newSpriteBatch(tex, 1, "dynamic")
		end
		self._currentBatch = self._batchCache[tex]
	end

	local drawMatrix = pushTransform(self)
	drawMatrix:setTransformation(0,0,0,1,1,0,0,0,0)
	drawMatrix:apply(matrix)

	if self.library.sprite_rotated[name_id] then
		drawMatrix:translate(0, self.library.sprite_w[name_id])
		drawMatrix:rotate(-m_pi_2)
	end

	self._currentBatch:add(quad, drawMatrix)
	popTransform(self)
end

local function drawElement(elem, frame, matrix, colorTransform, lib, self)
	local typ = elem.type
	local name_id = elem.name_id
	local transform_id = elem.transform_id
	local color_id = elem.color_id
	local is_3d = elem.is_3d
	local has_color = elem.has_color

	local elemMatrix = pushTransform(self)
	if is_3d == 1 then
		elemMatrix:setMatrix(Matrix._3Dstruct(lib.mat3ds[transform_id]))
	else
		elemMatrix:setMatrix(Matrix._2Dstruct(lib.mat2ds[transform_id]))
	end

	local combined = pushTransform(self)
	combined:setMatrix(matrix:getMatrix())
	combined:apply(elemMatrix)

	local finalColor = colorTransform
	local pushedColor = false

	if has_color == 1 then
		local elemColor = lib.colors[color_id]
		if colorTransform then
			finalColor = pushColor(self)
			pushedColor = true
			finalColor.rm = colorTransform.rm * elemColor.rm
			finalColor.gm = colorTransform.gm * elemColor.gm
			finalColor.bm = colorTransform.bm * elemColor.bm
			finalColor.am = colorTransform.am * elemColor.am
			finalColor.ro = colorTransform.ro + colorTransform.rm * elemColor.ro
			finalColor.go = colorTransform.go + colorTransform.gm * elemColor.go
			finalColor.bo = colorTransform.bo + colorTransform.bm * elemColor.bo
			finalColor.ao = colorTransform.ao + colorTransform.am * elemColor.ao
		else
			finalColor = elemColor
		end
	end

	if typ == 0 then
		local symbolName = lib.id_to_string[name_id]
		local symbolTL = lib.symbol_timelines and lib.symbol_timelines[symbolName]
		if symbolTL then
			local firstFrame = elem.first_frame
			local frameIndex = firstFrame + frame

			local symLength = lib.timelines[symbolTL].length
			local loopMode = elem.loop_mode
			if loopMode == 0 then
				if frameIndex < 0 then frameIndex = symLength - 1
				else frameIndex = frameIndex % symLength end
			elseif loopMode == 1 then
				frameIndex = math.max(0, math.min(frameIndex, symLength - 1))
			elseif loopMode == 2 then
				frameIndex = firstFrame
			end

			drawTimeline(self, symbolTL, frameIndex, combined, finalColor)
		end
	else
		queueSprite(self, name_id, combined, finalColor)
	end

	if pushedColor then popColor(self) end
	popTransform(self)
	popTransform(self)
end

local function drawKeyframe(frameStruct, frame, matrix, colorTransform, lib, self)
	local index = frameStruct.index
	local duration = frameStruct.duration
	if frame < index or frame >= index + duration then return false end

	local frameColor = nil
	if frameStruct.color_id ~= 0 then
		frameColor = lib.colors[frameStruct.color_id]
	end

	local combinedColor = colorTransform
	local pushed = false
	if frameColor then
		if colorTransform then
			combinedColor = pushColor(self)
			pushed = true
			combinedColor.rm = colorTransform.rm * frameColor.rm
			combinedColor.gm = colorTransform.gm * frameColor.gm
			combinedColor.bm = colorTransform.bm * frameColor.bm
			combinedColor.am = colorTransform.am * frameColor.am
			combinedColor.ro = colorTransform.ro + colorTransform.rm * frameColor.ro
			combinedColor.go = colorTransform.go + colorTransform.gm * frameColor.go
			combinedColor.bo = colorTransform.bo + colorTransform.bm * frameColor.bo
			combinedColor.ao = colorTransform.ao + colorTransform.am * frameColor.ao
		else
			combinedColor = frameColor
		end
	end

	local elements_start = frameStruct.elements_start
	local elements_count = frameStruct.elements_count
	for k = 0, elements_count - 1 do
		local elem = lib.elements[elements_start + k]
		drawElement(elem, frame - index, matrix, combinedColor, lib, self)
	end

	if pushed then popColor(self) end
	return true
end

local function drawLayer(layer, frame, matrix, colorTransform, lib, self, layersMap)
	local clipped_by_id = layer.clipped_by_id
	if clipped_by_id ~= 0 then
		self:flush()

		love.graphics.clear(false, true, false)
		love.graphics.setStencilState("replace", "always", 1)
		love.graphics.setColorMask(false, false, false, false)

		local maskLayer = layersMap[clipped_by_id]
		if maskLayer then
			love.graphics.setShader(maskShader)
			local maskFrames_start = maskLayer.frames_start
			local maskFrames_count = maskLayer.frames_count
			for j = 0, maskFrames_count - 1 do
				local f = lib.frames[maskFrames_start + j]
				if drawKeyframe(f, frame, matrix, self.colorStack[1], lib, self) then
					break
				end
			end
			self:flush()
			love.graphics.setShader()
		end

		love.graphics.setColorMask(true, true, true, true)
		love.graphics.setStencilState("keep", "greater", 0)
	end

	local frames_start = layer.frames_start
	local frames_count = layer.frames_count
	for j = 0, frames_count - 1 do
		local f = lib.frames[frames_start + j]
		if drawKeyframe(f, frame, matrix, colorTransform, lib, self) then
			break
		end
	end

	if clipped_by_id ~= 0 then
		self:flush()
		love.graphics.clear(false, true, false)
		love.graphics.setStencilState()
	end
end

function drawTimeline(self, tl_idx, frame, matrix, colorTransform)
	local lib = self.library
	local tl = lib.timelines[tl_idx]
	local layers_start = tl.layers_start
	local layers_count = tl.layers_count

	if not self._layersMapCache[tl_idx] then
		local layersMap = {}
		for i = 0, layers_count - 1 do
			local layer = lib.layers[layers_start + i]
			layersMap[layer.name_id] = layer
		end
		self._layersMapCache[tl_idx] = layersMap
	end

	local layersMap = self._layersMapCache[tl_idx]
	for i = layers_count - 1, 0, -1 do
		local layer = lib.layers[layers_start + i]
		if layer.layer_type == 0 then
			drawLayer(layer, frame, matrix, colorTransform, lib, self, layersMap)
		end
	end
end

function AnimateAtlas:update(dt)
	AnimateAtlas.super.update(self, dt)
	if not self.library then return end
	self.animation:update(dt)
end

function AnimateAtlas:updateHitbox()
	if not self.library then
		self.width, self.height = 0, 0
		return
	end
	self.width, self.height = self:getBoundDimensions()
	self:fixOffsets()
	self:centerOrigin()
end

function AnimateAtlas:__preRender()
	if not self.renderOnCanvas or not self.library then return end

	if self._canvas and self._lastCanvasSymbol == self.symbol and self._lastCanvasFrame == self.frame then
		return
	end

	if self._lastCanvasSymbol ~= self.symbol or not self._canvas then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

		self:precalculateBounds()
		local cache = self._boundsCache and self._boundsCache[self.symbol]
		if cache then
			local tl_idx = self.library.symbol_timelines[self.symbol] or self.library.main_timeline_id
			local length = self.library.timelines[tl_idx].length
			for i = 0, length - 1 do
				if cache.valid[i] then
					minX = m_min(minX, cache.minX[i])
					minY = m_min(minY, cache.minY[i])
					maxX = m_max(maxX, cache.maxX[i])
					maxY = m_max(maxY, cache.maxY[i])
				end
			end
		end

		if minX == math.huge then minX, minY, maxX, maxY = 0, 0, 1, 1 end

		local w = m_max(1, m_ceil(maxX - minX)) + 4
		local h = m_max(1, m_ceil(maxY - minY)) + 4

		self._canvasOffsetX = m_floor(minX)
		self._canvasOffsetY = m_floor(minY)

		if not self._canvas or self._canvas:getWidth() < w or self._canvas:getHeight() < h then
			if self._canvas then self._canvas:release() end
			canvasTable.dpiscale = self.canvasQuality
			self._canvas = love.graphics.newCanvas(w, h, canvasTable)
		end

		self._lastCanvasSymbol = self.symbol
	end

	love.graphics.push("all")
	canvasConfig[1] = self._canvas
	love.graphics.setCanvas(canvasConfig)
	love.graphics.clear(0,0,0,0)

	local identity = self.__transform:reset()
	identity:translate(-self._canvasOffsetX, -self._canvasOffsetY)

	local tl_idx = self.library.symbol_timelines[self.symbol] or self.library.main_timeline_id

	self._lastTexture = nil
	self._lastColorData = nil
	self._lastBlendMode = "alpha"

	drawTimeline(self, tl_idx, self.frame, identity, self.colorStack[1])
	self:flush()

	love.graphics.setCanvas()
	love.graphics.discard()
	love.graphics.pop()
	self._lastCanvasFrame = self.frame
end

function AnimateAtlas:__draw(x, y, r, sx, sy, ox, oy, kx, ky)
	if not self.library then return end
	love.graphics.push("all")

	local identity = self.__transform:reset()
	x, y = x or 0, y or 0
	sx, sy = sx or 1, sy or 1
	ox, oy = ox or 0, oy or 0
	r = r or 0
	kx, ky = kx or 0, ky or 0

	if self.animation and self.animation.curAnim then
		local ax, ay = self.animation.curAnim:rotateOffset(r, sx, sy)
		x, y = x - ax, y - ay
	end

	identity:translate(x, y):rotate(r):scale(sx, sy):shear(kx, ky):translate(-ox, -oy)

	if self.renderOnCanvas and self._canvas then
		love.graphics.applyTransform(identity)
		love.graphics.draw(self._canvas, self._canvasOffsetX, self._canvasOffsetY)
	else
		local tl_idx = self.library.symbol_timelines[self.symbol] or self.library.main_timeline_id
		self._lastTexture = nil
		self._lastColorData = nil
		self._lastBlendMode = "alpha"

		drawTimeline(self, tl_idx, self.frame, identity, self.colorStack[1])
		self:flush()
	end

	love.graphics.pop()
end

function AnimateAtlas:__render(camera)
	love.graphics.push("all")
	local x, y, rad, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	self:__draw(x, y, rad, sx, sy, ox, oy, kx, ky)
	love.graphics.pop()
end

function AnimateAtlas:getLocalBounds()
	if not self.library then return 0,0,0,0 end
	return self:calculateFrameBounds(self.frame)
end

function AnimateAtlas:destroy()
	if self._mustRelease then self.library:destroy() end
	if self.colorTransform then self.colorTransform:destroy() end
	if self.filters then self.filters:destroy() end

	if self._batchCache then
		for _, batch in pairs(self._batchCache) do
			batch:release()
		end
	end
	self._batchCache = nil

	if self._canvas then
		self._canvas:release()
		self._canvas = nil
	end

	if self.tfStack then
		for i = 1, #self.tfStack do
			if self.tfStack[i].release then self.tfStack[i]:release() end
		end
		self.tfStack = nil
	end
	self.colorStack = nil
	self._layersMapCache = nil

	AnimateAtlas.super.destroy(self)
end

return AnimateAtlas
