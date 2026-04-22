local Matrix = loxreq "animateatlas.matrix"
local Boundary = Classic:extend("Boundary")

local m_pi_2 = math.pi / 2

local tfStack = {}
local tfIndex = 0

local function pushTransform()
	tfIndex = tfIndex + 1
	if not tfStack[tfIndex] then
		tfStack[tfIndex] = love.math.newTransform()
	end
	return tfStack[tfIndex]
end

local function popTransform()
	tfIndex = tfIndex - 1
end

local processTimeline, processLayer, processKeyframe, processElement

local lib_timelines, lib_layers, lib_frames, lib_elements
local lib_mat2ds, lib_mat3ds, lib_id_to_string, lib_sprite_quads
local lib_symbol_timelines, lib_sprite_rotated, lib_sprite_w

processElement = function(elem, frame, matrix, bounds, lib)
	local typ = elem.type
	local name_id = elem.name_id
	local transform_id = elem.transform_id
	local is_3d = elem.is_3d

	local elemMatrix = pushTransform()
	if is_3d == 1 then
		elemMatrix:setMatrix(Matrix._3Dstruct(lib_mat3ds[transform_id]))
	else
		elemMatrix:setMatrix(Matrix._2Dstruct(lib_mat2ds[transform_id]))
	end

	local combined = pushTransform()
	combined:setMatrix(matrix:getMatrix())
	combined:apply(elemMatrix)

	if typ == 0 then   -- symbol
		local symbolName = lib_id_to_string[name_id]
		local symbolTL = lib_symbol_timelines and lib_symbol_timelines[symbolName]
		if symbolTL then
			local firstFrame = elem.first_frame
			local frameIndex = firstFrame + frame

			local symLength = lib_timelines[symbolTL].length
			local loopMode = elem.loop_mode
			if loopMode == 0 then   -- loop
				if frameIndex < 0 then
					frameIndex = symLength - 1
				else
					frameIndex = frameIndex % symLength
				end
			elseif loopMode == 1 then   -- play once
				frameIndex = math.max(0, math.min(frameIndex, symLength - 1))
			elseif loopMode == 2 then   -- single frame
				frameIndex = firstFrame
			end

			processTimeline(symbolTL, frameIndex, combined, bounds, lib)
		end
	else   -- atlas sprite
		local quad = lib_sprite_quads[name_id]
		if quad then
			if lib_sprite_rotated[name_id] then
				combined:translate(0, lib_sprite_w[name_id])
				combined:rotate(-m_pi_2)
			end

			local _, _, w, h = quad:getViewport()
			local x1, y1 = combined:transformPoint(0, 0)
			local x2, y2 = combined:transformPoint(w, 0)
			local x3, y3 = combined:transformPoint(w, h)
			local x4, y4 = combined:transformPoint(0, h)

			bounds.minX = math.min(bounds.minX, x1, x2, x3, x4)
			bounds.minY = math.min(bounds.minY, y1, y2, y3, y4)
			bounds.maxX = math.max(bounds.maxX, x1, x2, x3, x4)
			bounds.maxY = math.max(bounds.maxY, y1, y2, y3, y4)
		end
	end

	popTransform()   -- combined
	popTransform()   -- elem matrix
end

processKeyframe = function(frameStruct, frame, matrix, bounds, lib)
	local index = frameStruct.index
	local duration = frameStruct.duration
	if frame < index or frame >= index + duration then return false end

	local elements_start = frameStruct.elements_start
	local elements_count = frameStruct.elements_count
	for k = 0, elements_count - 1 do
		local elem = lib_elements[elements_start + k]
		processElement(elem, frame - index, matrix, bounds, lib)
	end
	return true
end

processLayer = function(layer, frame, matrix, bounds, lib)
	local frames_start = layer.frames_start
	local frames_count = layer.frames_count
	for j = 0, frames_count - 1 do
		local f = lib_frames[frames_start + j]
		if processKeyframe(f, frame, matrix, bounds, lib) then
			break
		end
	end
end

processTimeline = function(tl_idx, frame, matrix, bounds, lib)
	local tl = lib_timelines[tl_idx]
	local layers_start = tl.layers_start
	local layers_count = tl.layers_count

	for i = layers_count - 1, 0, -1 do
		local layer = lib_layers[layers_start + i]
		if layer.layer_type == 0 then
			processLayer(layer, frame, matrix, bounds, lib)
		end
	end
end

function Boundary:calculateFrameBounds(frame)
	local iFrame = math.floor(frame)
	local symbol = self.symbol

	if not self._boundsCache then self._boundsCache = {} end
	if not self._boundsCache[symbol] then
		self._boundsCache[symbol] = {
			valid = {}, minX = {}, minY = {}, maxX = {}, maxY = {}
		}
	end

	local cache = self._boundsCache[symbol]
	if cache.valid[iFrame] ~= nil then
		if cache.valid[iFrame] then
			return cache.minX[iFrame], cache.minY[iFrame],
			       cache.maxX[iFrame] - cache.minX[iFrame],
			       cache.maxY[iFrame] - cache.minY[iFrame]
		else
			return 0,0,0,0
		end
	end

	local lib = self.library
	if not lib then return 0,0,0,0 end

	lib_timelines = lib.timelines
	lib_layers = lib.layers
	lib_frames = lib.frames
	lib_elements = lib.elements
	lib_mat2ds = lib.mat2ds
	lib_mat3ds = lib.mat3ds
	lib_id_to_string = lib.id_to_string
	lib_sprite_quads = lib.sprite_quads
	lib_symbol_timelines = lib.symbol_timelines
	lib_sprite_rotated = lib.sprite_rotated
	lib_sprite_w = lib.sprite_w

	local tl_idx = lib_symbol_timelines and lib_symbol_timelines[symbol] or lib.main_timeline_id
	if not tl_idx then return 0,0,0,0 end

	local b = { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }

	local identity = pushTransform()
	identity:setTransformation(0,0, 0, 1,1, 0,0)

	processTimeline(tl_idx, iFrame, identity, b, lib)

	popTransform()

	if b.minX ~= math.huge and b.maxX ~= -math.huge then
		cache.minX[iFrame] = b.minX
		cache.minY[iFrame] = b.minY
		cache.maxX[iFrame] = b.maxX
		cache.maxY[iFrame] = b.maxY
		cache.valid[iFrame] = true
		return b.minX, b.minY, b.maxX - b.minX, b.maxY - b.minY
	end

	cache.valid[iFrame] = false
	return 0,0,0,0
end

function Boundary:precalculateBounds()
	local lib = self.library
	if not lib then return end
	local tl_idx = lib.symbol_timelines and lib.symbol_timelines[self.symbol] or lib.main_timeline_id
	if not tl_idx then return end
	local length = lib.timelines[tl_idx].length
	for i = 0, length - 1 do
		self:calculateFrameBounds(i)
	end
end

function Boundary:getBoundTopLeft()
	local x, y = self:calculateFrameBounds(self.frame)
	return x, y
end

function Boundary:getBoundDimensions()
	local _, _, w, h = self:calculateFrameBounds(self.frame)
	return w, h
end

return Boundary
