local json = loxreq "lib.json"
local ffi = require "ffi"

-- NOTE: LOVE 12 enables JIT compilation for ARM, but
-- LOVE 11 does not. ffi is insanely slow if the code
-- is executed in interpreter mode instead of JIT compilation,
-- so i added a lua table workaround. its not optimized in
-- memory in the slightest, but its way faster without jit. - kaoy

if Project.flags.jitFFI then
	ffi.cdef[[
		typedef struct { float a, b, c, d, tx, ty; } AtlasMat2D;
		typedef struct { float m[16]; } AtlasMat3D;
		typedef struct { float rm, gm, bm, am, ro, go, bo, ao; } AtlasColor;

		typedef struct {
			uint32_t transform_id;
			uint32_t color_id;
			uint16_t name_id;
			uint16_t first_frame;
			uint16_t filter_id;
			uint8_t  type;
			uint8_t  symbol_type : 2;
			uint8_t  loop_mode : 2;
			uint8_t  is_3d : 1;
			uint8_t  has_color : 1;
		} AtlasElement;

		typedef struct {
			uint32_t elements_start;
			uint32_t color_id;
			uint16_t elements_count;
			uint16_t index;
			uint16_t duration;
			uint16_t name_id;
		} AtlasFrame;

		typedef struct {
			uint32_t frames_start;
			uint16_t frames_count;
			uint16_t name_id;
			uint16_t clipped_by_id;
			uint8_t  layer_type;
		} AtlasLayer;

		typedef struct {
			uint32_t layers_start;
			uint32_t length;
			uint16_t layers_count;
			uint16_t name_id;
		} AtlasTimeline;
	]]
else
	ffi = {}
	ffi.cdef = function() end
	ffi.sizeof = function() return 1 end

	local struct_factories = {
		["AtlasMat2D"] = function() return {a=0, b=0, c=0, d=0, tx=0, ty=0} end,
		["AtlasMat3D"] = function()
			local t = {m = {}}
			for i = 0, 15 do t.m[i] = 0 end
			return t
		end,
		["AtlasColor"] = function() return {rm=0, gm=0, bm=0, am=0, ro=0, go=0, bo=0, ao=0} end,
		["AtlasElement"] = function() return {transform_id=0, color_id=0, name_id=0, first_frame=0, filter_id=0, type=0, symbol_type=0, loop_mode=0, is_3d=0, has_color=0} end,
		["AtlasFrame"] = function() return {elements_start=0, color_id=0, elements_count=0, index=0, duration=0, name_id=0} end,
		["AtlasLayer"] = function() return {frames_start=0, frames_count=0, name_id=0, clipped_by_id=0, layer_type=0} end,
		["AtlasTimeline"] = function() return {layers_start=0, length=0, layers_count=0, name_id=0} end,
	}

	ffi.new = function(typeStr, count)
		local baseType = typeStr:gsub("%[%?%]", "")
		local factory = struct_factories[baseType]
		local arr = {}
		if factory and count then
			for i = 0, count - 1 do
				arr[i] = factory()
			end
		elseif factory then
			return factory()
		end
		return arr
	end

	ffi.copy = function(dst, src, count)
		for i = 0, count - 1 do
			dst[i] = src[i]
		end
	end
end

local AnimateLibrary = Basic:extend("AnimateLibrary")

function AnimateLibrary:new(folder)
	AnimateLibrary.super.new(self)

	self.folder = folder
	self.strings = {}
	self.string_to_id = {}
	self.id_to_string = {}
	self.filters = {}
	self.sprite_quads = {}
	self.sprite_textures = {}
	self.sprite_rotated = {}
	self.sprite_w = {}
	self.symbol_timelines = {}

	self.elements_cap = 1024
	self.frames_cap = 1024
	self.layers_cap = 128
	self.timelines_cap = 32
	self.mat2d_cap = 1024
	self.mat3d_cap = 16
	self.colors_cap = 128

	self.elements = ffi.new("AtlasElement[?]", self.elements_cap)
	self.frames = ffi.new("AtlasFrame[?]", self.frames_cap)
	self.layers = ffi.new("AtlasLayer[?]", self.layers_cap)
	self.timelines = ffi.new("AtlasTimeline[?]", self.timelines_cap)
	self.mat2ds = ffi.new("AtlasMat2D[?]", self.mat2d_cap)
	self.mat3ds = ffi.new("AtlasMat3D[?]", self.mat3d_cap)
	self.colors = ffi.new("AtlasColor[?]", self.colors_cap)

	self.elements_count = 0
	self.frames_count = 0
	self.layers_count = 0
	self.timelines_count = 0
	self.mat2d_count = 0
	self.mat3d_count = 0
	self.colors_count = 1

	local mainData = json.decode(love.filesystem.read("string", folder .. "/Animation.json"))
	local optimized = mainData.AN ~= nil

	local framerate = 24
	if love.filesystem.getInfo(folder .. "/metadata.json", "file") then
		local meta = json.decode(love.filesystem.read("string", folder .. "/metadata.json"))
		framerate = meta[optimized and "FRT" or "framerate"] or 24
	else
		framerate = mainData.FRT or mainData.framerate or 24
	end
	self.framerate = framerate

	self.imageLoads = {}
	for _, item in ipairs(love.filesystem.getDirectoryItems(folder)) do
		if string.startsWith(item, "spritemap") and string.endsWith(item, ".json") then
			table.insert(self.imageLoads, {
				json_path = folder .. "/" .. item,
				image_path = folder .. "/" .. string.sub(item, 1, #item - 5) .. ".png"
			})
		end
	end

	self.main_timeline_id = self:parseTimeline(
		"",
		mainData[optimized and "AN" or "ANIMATION"][optimized and "TL" or "TIMELINE"],
		optimized
	)

	if mainData.SD or mainData.SYMBOL_DICTIONARY then
		local dict = mainData[optimized and "SD" or "SYMBOL_DICTIONARY"]
		local symbols = dict[optimized and "S" or "Symbols"]
		for i = 1, #symbols do
			local sym = symbols[i]
			local symName = sym[optimized and "SN" or "SYMBOL_name"]
			local symTL = sym[optimized and "TL" or "TIMELINE"]
			self:parseTimeline(symName, symTL, optimized)
		end
	else
		if love.filesystem.getInfo(folder .. "/LIBRARY", "directory") then
			for _, item in ipairs(love.filesystem.getDirectoryItems(folder .. "/LIBRARY")) do
				if string.endsWith(item, ".json") then
					local symName = string.sub(item, 1, #item - 5)
					local symData = json.decode(love.filesystem.read("string", folder .. "/LIBRARY/" .. item))
					self:parseTimeline(symName, symData, symData.L ~= nil)
				end
			end
		end
	end

	self:loadImages()
	self:shrink()
end

function AnimateLibrary:getStringId(str)
	if not str then return 0 end
	if self.string_to_id[str] then return self.string_to_id[str] end
	local id = #self.strings + 1
	self.strings[id] = str
	self.string_to_id[str] = id
	self.id_to_string[id] = str
	return id
end

function AnimateLibrary:getString(id)
	if id == 0 then return nil end
	return self.id_to_string[id]
end

function AnimateLibrary:getFilterId(filterData)
	if not filterData then return 0 end
	local id = #self.filters + 1
	self.filters[id] = filterData
	return id
end

function AnimateLibrary:ensureCapacity(typeStr, currentCap, currentCount, needed, ptrName)
	if currentCount + needed >= currentCap then
		local newCap = currentCap * 2 + needed
		local newArr = ffi.new(typeStr, newCap)
		ffi.copy(newArr, self[ptrName], ffi.sizeof(typeStr:sub(1, -4)) * currentCount)
		self[ptrName] = newArr
		return newCap
	end
	return currentCap
end

function AnimateLibrary:parseMatrix(mat, opt, is3D, outElem)
	outElem.is_3d = is3D and 1 or 0
	if is3D then
	self.mat3d_cap = self:ensureCapacity("AtlasMat3D[?]", self.mat3d_cap, self.mat3d_count, 1, "mat3ds")
	local mIdx = self.mat3d_count
	self.mat3d_count = self.mat3d_count + 1
	local m3Struct = self.mat3ds[mIdx]

	for i = 0, 15 do m3Struct.m[i] = (i % 5 == 0) and 1 or 0 end
		local m3 = mat[opt and "M3D" or "Matrix3D"]
		if type(m3) == "table" then
			local isArray = false
			for i = 1, 16 do
				if m3[i] ~= nil then
					isArray = true
					break
				end
			end

			if isArray then
				for i = 1, 16 do m3Struct.m[i - 1] = m3[i] or 0 end
			else
				for r = 0, 3 do
					for c = 0, 3 do
						local key = "m" .. r .. c
						m3Struct.m[r * 4 + c] = m3[key] or 0
					end
				end
			end
		end
		outElem.transform_id = mIdx
	else
		self.mat2d_cap = self:ensureCapacity("AtlasMat2D[?]", self.mat2d_cap, self.mat2d_count, 1, "mat2ds")
		local mIdx = self.mat2d_count
		self.mat2d_count = self.mat2d_count + 1
		local m2Struct = self.mat2ds[mIdx]

		local m2 = mat[opt and "MX" or "Matrix"]
		if type(m2) == "table" then
			if #m2 > 0 then
				m2Struct.a = m2[1] or 1
				m2Struct.b = m2[2] or 0
				m2Struct.c = m2[3] or 0
				m2Struct.d = m2[4] or 1
				m2Struct.tx = m2[5] or 0
				m2Struct.ty = m2[6] or 0
			else
				m2Struct.a = m2.a or 1
				m2Struct.b = m2.b or 0
				m2Struct.c = m2.c or 0
				m2Struct.d = m2.d or 1
				m2Struct.tx = m2.tx or 0
				m2Struct.ty = m2.ty or 0
			end
		else
			m2Struct.a = 1; m2Struct.b = 0; m2Struct.c = 0; m2Struct.d = 1
			m2Struct.tx = 0; m2Struct.ty = 0
		end
		outElem.transform_id = mIdx
	end
end

function AnimateLibrary:parseColor(colorData, opt, outElem)
	if not colorData then
		outElem.has_color = 0
		outElem.color_id = 0
		return
	end

	self.colors_cap = self:ensureCapacity("AtlasColor[?]", self.colors_cap, self.colors_count, 1, "colors")
	local cIdx = self.colors_count
	self.colors_count = self.colors_count + 1
	local cStruct = self.colors[cIdx]

	outElem.has_color = 1
	outElem.color_id = cIdx

	cStruct.rm = colorData[opt and "RM" or "RedMultiplier"]   or 1
	cStruct.gm = colorData[opt and "GM" or "GreenMultiplier"] or 1
	cStruct.bm = colorData[opt and "BM" or "BlueMultiplier"]  or 1
	cStruct.am = colorData[opt and "AM" or "alphaMultiplier"] or 1
	cStruct.ro = (colorData[opt and "RO" or "RedOffset"]   or 0) / 255
	cStruct.go = (colorData[opt and "GO" or "GreenOffset"] or 0) / 255
	cStruct.bo = (colorData[opt and "BO" or "BlueOffset"]  or 0) / 255
	cStruct.ao = (colorData[opt and "AO" or "alphaOffset"] or 0) / 255
end

function AnimateLibrary:parseTimeline(name, data, opt)
	self.timelines_cap = self:ensureCapacity("AtlasTimeline[?]", self.timelines_cap, self.timelines_count, 1, "timelines")
	local tl_idx = self.timelines_count
	self.timelines_count = self.timelines_count + 1

	local t_struct = self.timelines[tl_idx]
	t_struct.name_id = self:getStringId(name)

	local layersData = data[opt and "L" or "LAYERS"]
	local l_count = layersData and #layersData or 0

	t_struct.layers_start = self.layers_count
	t_struct.layers_count = l_count

	self.layers_cap = self:ensureCapacity("AtlasLayer[?]", self.layers_cap, self.layers_count, l_count, "layers")
	local l_start = self.layers_count
	self.layers_count = self.layers_count + l_count

	local max_length = 0

	for i = 1, l_count do
		local l_data = layersData[i]
		local l_struct = self.layers[l_start + i - 1]

		l_struct.name_id = self:getStringId(l_data[opt and "LN" or "Layer_name"])
		l_struct.clipped_by_id = self:getStringId(l_data[opt and "Clpb" or "Clipped_by"])
		l_struct.layer_type = (l_data[opt and "LT" or "Layer_type"] == nil) and 0 or 1

		local framesData = l_data[opt and "FR" or "Frames"]
		local f_count = framesData and #framesData or 0

		l_struct.frames_start = self.frames_count
		l_struct.frames_count = f_count

		self.frames_cap = self:ensureCapacity("AtlasFrame[?]", self.frames_cap, self.frames_count, f_count, "frames")
		local f_start = self.frames_count
		self.frames_count = self.frames_count + f_count

		for j = 1, f_count do
			local f_data = framesData[j]
			local f_struct = self.frames[f_start + j - 1]

			local f_idx = f_data[opt and "I" or "index"] or 0
			local f_dur = f_data[opt and "DU" or "duration"] or 1
			local f_name = f_data[opt and "N" or "name"]

			f_struct.index = f_idx
			f_struct.duration = f_dur
			f_struct.name_id = self:getStringId(f_name)
			f_struct.color_id = self:getColorId(f_data[opt and "C" or "Color"], opt)

			if f_idx + f_dur > max_length then max_length = f_idx + f_dur end

			local elementsData = f_data[opt and "E" or "elements"]
			local e_count = elementsData and #elementsData or 0

			f_struct.elements_start = self.elements_count
			f_struct.elements_count = e_count

			self.elements_cap = self:ensureCapacity("AtlasElement[?]", self.elements_cap, self.elements_count, e_count, "elements")
			local e_start = self.elements_count
			self.elements_count = self.elements_count + e_count

			for k = 1, e_count do
				local e_data = elementsData[k]
				local e_struct = self.elements[e_start + k - 1]

				local symInst = e_data[opt and "SI" or "SYMBOL_Instance"]
				local atlasInst = e_data[opt and "ASI" or "ATLAS_SPRITE_instance"]
				local elemColor = e_data[opt and "C" or "Color"]

				if symInst then
					e_struct.type = 0
					e_struct.name_id = self:getStringId(symInst[opt and "SN" or "SYMBOL_name"])
					e_struct.first_frame = symInst[opt and "FF" or "firstFrame"] or 0

					local st = symInst[opt and "ST" or "symbolType"]
					e_struct.symbol_type = (st == "movieclip" or st == "MC") and 0 or 1

					local lm = symInst[opt and "LP" or "loop"]
					if lm == "playonce" or lm == "PO" then e_struct.loop_mode = 1
					elseif lm == "singleframe" or lm == "SF" then e_struct.loop_mode = 2
					else e_struct.loop_mode = 0 end

					self:parseMatrix(symInst, opt, symInst[opt and "M3D" or "Matrix3D"] ~= nil, e_struct)
					e_struct.filter_id = self:getFilterId(symInst[opt and "F" or "Filters"])
					self:parseColor(elemColor, opt, e_struct)

				elseif atlasInst then
					e_struct.type = 1
					e_struct.name_id = self:getStringId(atlasInst[opt and "N" or "name"])

					self:parseMatrix(atlasInst, opt, atlasInst[opt and "M3D" or "Matrix3D"] ~= nil, e_struct)
					e_struct.filter_id = self:getFilterId(atlasInst[opt and "F" or "Filters"])
					self:parseColor(elemColor, opt, e_struct)
				end
			end
		end
	end

	t_struct.length = max_length
	self.symbol_timelines[name] = tl_idx

	return tl_idx
end

function AnimateLibrary:getColorId(colorData, opt)
	if not colorData then return 0 end
	self.colors_cap = self:ensureCapacity("AtlasColor[?]", self.colors_cap, self.colors_count, 1, "colors")
	local cIdx = self.colors_count
	self.colors_count = self.colors_count + 1
	local cStruct = self.colors[cIdx]

	cStruct.rm = colorData[opt and "RM" or "RedMultiplier"]   or 1
	cStruct.gm = colorData[opt and "GM" or "GreenMultiplier"] or 1
	cStruct.bm = colorData[opt and "BM" or "BlueMultiplier"]  or 1
	cStruct.am = colorData[opt and "AM" or "alphaMultiplier"] or 1

	cStruct.ro = (colorData[opt and "RO" or "RedOffset"]   or 0) / 255
	cStruct.go = (colorData[opt and "GO" or "GreenOffset"] or 0) / 255
	cStruct.bo = (colorData[opt and "BO" or "BlueOffset"]  or 0) / 255
	cStruct.ao = (colorData[opt and "AO" or "alphaOffset"] or 0) / 255

	return cIdx
end

function AnimateLibrary:loadImages()
	if not self.imageLoads then return end
	for _, loadData in ipairs(self.imageLoads) do
		local tex = love.graphics.newImage(loadData.image_path)
		local data = json.decode(love.filesystem.read("string", loadData.json_path))
		local texW, texH = tex:getWidth(), tex:getHeight()
		local sprites = data.ATLAS.SPRITES

		for z = 1, #sprites do
			local sprite = sprites[z].SPRITE
			local n_id = self:getStringId(sprite.name)
			self.sprite_quads[n_id] = love.graphics.newQuad(sprite.x, sprite.y, sprite.w, sprite.h, texW, texH)
			self.sprite_textures[n_id] = tex

			if sprite.rotated then
				self.sprite_rotated[n_id] = true
				self.sprite_w[n_id] = sprite.w
			end
		end
	end
	self.imageLoads = nil
end

function AnimateLibrary:getTimelineLength(tl_idx)
	if tl_idx < 0 or tl_idx >= self.timelines_count then return 0 end
	return self.timelines[tl_idx].length
end

function AnimateLibrary:getLength()
	return self:getTimelineLength(self.main_timeline_id)
end

function AnimateLibrary:getSymbolTimeline(symbol)
	local sym = symbol
	if type(sym) == "string" then
		sym = sym:match("^%s*(.-)%s*$") or ""
	end
	local idx = self.symbol_timelines[sym]
	if idx then return idx end
	if sym == "" then return self.main_timeline_id end

	for k, v in pairs(self.symbol_timelines) do
		if type(k) == "string" and k:match("^%s*(.-)%s*$") == sym then
			return v
		end
	end
	return self.main_timeline_id
end

function AnimateLibrary:getLabelRange(symbol, label)
	local tl_idx = self:getSymbolTimeline(symbol)
	if not tl_idx then return nil end

	local label_id = self.string_to_id[label]
	if not label_id then return nil end

	local tl = self.timelines[tl_idx]
	local layers_start = tl.layers_start
	local layers_count = tl.layers_count

	for i = 0, layers_count - 1 do
		local layer = self.layers[layers_start + i]
		local frames_start = layer.frames_start
		local frames_count = layer.frames_count
		for j = 0, frames_count - 1 do
			local frame = self.frames[frames_start + j]
			if frame.name_id == label_id then
				local startFrame = frame.index
				local endFrame = startFrame + frame.duration - 1
				return startFrame, endFrame
			end
		end
	end
	return nil
end

function AnimateLibrary:shrink()
	local function shrinkArray(arrName, count, elementSize, elementType)
		if count == 0 then
			self[arrName] = nil
			return
		end
		local oldArr = self[arrName]
		local newArr = ffi.new(elementType .. "[?]", count)
		ffi.copy(newArr, oldArr, elementSize * count)
		self[arrName] = newArr
		local capName = arrName .. "_cap"
		if self[capName] then
			self[capName] = count
		end
	end

	shrinkArray("elements", self.elements_count, ffi.sizeof("AtlasElement"), "AtlasElement")
	shrinkArray("frames", self.frames_count, ffi.sizeof("AtlasFrame"), "AtlasFrame")
	shrinkArray("layers", self.layers_count, ffi.sizeof("AtlasLayer"), "AtlasLayer")
	shrinkArray("timelines", self.timelines_count, ffi.sizeof("AtlasTimeline"), "AtlasTimeline")
	shrinkArray("mat2ds", self.mat2d_count, ffi.sizeof("AtlasMat2D"), "AtlasMat2D")
	shrinkArray("mat3ds", self.mat3d_count, ffi.sizeof("AtlasMat3D"), "AtlasMat3D")
	shrinkArray("colors", self.colors_count, ffi.sizeof("AtlasColor"), "AtlasColor")
end

function AnimateLibrary:destroy()
	for _, tex in pairs(self.sprite_textures) do
		if tex and tex.release then tex:release() end
	end
	self.sprite_textures = {}
	self.sprite_quads = {}
	self.sprite_rotated = nil
	self.sprite_w = nil
	self.strings = nil
	self.string_to_id = nil
	self.id_to_string = nil
	self.symbol_timelines = nil
	self.filters = nil

	self.elements = nil
	self.frames = nil
	self.layers = nil
	self.timelines = nil
	self.mat2ds = nil
	self.mat3ds = nil
	self.colors = nil

	AnimateLibrary.super.destroy(self)
end

return AnimateLibrary
