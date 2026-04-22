local RenderUtil = {}

RenderUtil.alphaBleeding = Project.flags.imageAlphaBleed
RenderUtil.imageQuality = Project.flags.imageQuality
RenderUtil.boxBlur = Project.flags.imageBlurSamples

local ffi = require("ffi")
local lib = ffi.C

local function procsafe(x, y, i, w, h, ptr, stride)
	local r, g, b, c = 0, 0, 0, 0
	for dy = (y > 0 and -1 or 0), (y < h - 1 and 1 or 0) do
		for dx = (x > 0 and -1 or 0), (x < w - 1 and 1 or 0) do
			if dx ~= 0 or dy ~= 0 then
				local ni = i + (dy * stride) + (dx * 4)
				if ptr[ni + 3] > 0 then
					r, g, b, c = r + ptr[ni], g + ptr[ni + 1], b + ptr[ni + 2], c + 1
				end
			end
		end
	end
	if c > 0 then ptr[i], ptr[i + 1], ptr[i + 2] = r / c, g / c, b / c end
end

function RenderUtil.applyAlphaBleed(imageData)
	local w, h = imageData:getDimensions()
	local ptr, stride = ffi.cast("uint8_t*", imageData:getFFIPointer()), w * 4

	if w < 3 or h < 3 then
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local i = y * stride + x * 4; if ptr[i + 3] == 0 then procsafe(x, y, i, w, h, ptr, stride) end
			end
		end
		return imageData
	end

	for x = 0, w - 1 do
		if ptr[x * 4 + 3] == 0 then procsafe(x, 0, x * 4, w, h, ptr, stride) end
		local bottom_i = (h - 1) * stride + x * 4
		if ptr[bottom_i + 3] == 0 then procsafe(x, h - 1, bottom_i, w, h, ptr, stride) end
	end
	for y = 1, h - 2 do
		local left_i = y * stride
		if ptr[left_i + 3] == 0 then procsafe(0, y, left_i, w, h, ptr, stride) end
		local right_i = y * stride + (w - 1) * 4
		if ptr[right_i + 3] == 0 then procsafe(w - 1, y, right_i, w, h, ptr, stride) end
	end

	local o1, o2, o3, o4, o5, o6, o7, o8 = -stride - 4, -stride, -stride + 4, -4, 4, stride - 4, stride, stride + 4
	for y = 1, h - 2 do
		local row_start = y * stride
		for x = 1, w - 2 do
			local i = row_start + x * 4
			if ptr[i + 3] == 0 then
				local r, g, b, c = 0, 0, 0, 0
				-- unrolled 3p3 for better jit compilation aughhh
				if ptr[i + o1 + 3] > 0 then r = r + ptr[i + o1]; g = g + ptr[i + o1 + 1]; b = b + ptr[i + o1 + 2]; c = c + 1 end
				if ptr[i + o2 + 3] > 0 then r = r + ptr[i + o2]; g = g + ptr[i + o2 + 1]; b = b + ptr[i + o2 + 2]; c = c + 1 end
				if ptr[i + o3 + 3] > 0 then r = r + ptr[i + o3]; g = g + ptr[i + o3 + 1]; b = b + ptr[i + o3 + 2]; c = c + 1 end
				if ptr[i + o4 + 3] > 0 then r = r + ptr[i + o4]; g = g + ptr[i + o4 + 1]; b = b + ptr[i + o4 + 2]; c = c + 1 end
				if ptr[i + o5 + 3] > 0 then r = r + ptr[i + o5]; g = g + ptr[i + o5 + 1]; b = b + ptr[i + o5 + 2]; c = c + 1 end
				if ptr[i + o6 + 3] > 0 then r = r + ptr[i + o6]; g = g + ptr[i + o6 + 1]; b = b + ptr[i + o6 + 2]; c = c + 1 end
				if ptr[i + o7 + 3] > 0 then r = r + ptr[i + o7]; g = g + ptr[i + o7 + 1]; b = b + ptr[i + o7 + 2]; c = c + 1 end
				if ptr[i + o8 + 3] > 0 then r = r + ptr[i + o8]; g = g + ptr[i + o8 + 1]; b = b + ptr[i + o8 + 2]; c = c + 1 end

				if c > 0 then
					ptr[i], ptr[i + 1], ptr[i + 2] = r / c, g / c, b / c
				end
			end
		end
	end

	return imageData
end

function RenderUtil.shrink(imageData)
	local w, h = imageData:getDimensions()
	local newW = math.max(1, math.ceil(w * RenderUtil.imageQuality))
	local newH = math.max(1, math.ceil(h * RenderUtil.imageQuality))

	if newW == w and newH == h then return imageData end

	local newImageData = love.image.newImageData(newW, newH)
	local srcPtr = ffi.cast("uint8_t*", imageData:getFFIPointer())
	local dstPtr = ffi.cast("uint8_t*", newImageData:getFFIPointer())

	local srcStride, dstStride = w * 4, newW * 4
	local invQuality = 1 / RenderUtil.imageQuality
	local sampleSize = math.floor(RenderUtil.boxBlur or 0)

	for y = 0, newH - 1 do
		local dstRow = y * dstStride
		local startY = math.floor(y * invQuality)

		for x = 0, newW - 1 do
			local startX = math.floor(x * invQuality)
			local dstIdx = dstRow + x * 4

			if sampleSize <= 1 then
				local srcIdx = (startY < h and startY or h-1) * srcStride + (startX < w and startX or w-1) * 4
				dstPtr[dstIdx] = srcPtr[srcIdx]
				dstPtr[dstIdx+1] = srcPtr[srcIdx+1]
				dstPtr[dstIdx+2] = srcPtr[srcIdx+2]
				dstPtr[dstIdx+3] = srcPtr[srcIdx+3]

			elseif sampleSize == 2 then
				local sy2 = math.min(startY + 1, h - 1)
				local sx2 = math.min(startX + 1, w - 1)
				local i1 = startY * srcStride + startX * 4
				local i2 = startY * srcStride + sx2 * 4
				local i3 = sy2 * srcStride + startX * 4
				local i4 = sy2 * srcStride + sx2 * 4

				dstPtr[dstIdx]   = (srcPtr[i1] + srcPtr[i2] + srcPtr[i3] + srcPtr[i4]) / 4
				dstPtr[dstIdx+1] = (srcPtr[i1+1] + srcPtr[i2+1] + srcPtr[i3+1] + srcPtr[i4+1]) / 4
				dstPtr[dstIdx+2] = (srcPtr[i1+2] + srcPtr[i2+2] + srcPtr[i3+2] + srcPtr[i4+2]) / 4
				dstPtr[dstIdx+3] = (srcPtr[i1+3] + srcPtr[i2+3] + srcPtr[i3+3] + srcPtr[i4+3]) / 4

			else
				local r, g, b, a, c = 0, 0, 0, 0, 0
				for dy = 0, sampleSize - 1 do
					local sy = startY + dy
					if sy < h then
						local sRow = sy * srcStride
						for dx = 0, sampleSize - 1 do
							local sx = startX + dx
							if sx < w then
								local i = sRow + sx * 4
								r, g, b, a, c = r+srcPtr[i], g+srcPtr[i+1], b+srcPtr[i+2], a+srcPtr[i+3], c+1
							end
						end
					end
				end
				dstPtr[dstIdx], dstPtr[dstIdx+1] = r/c, g/c
				dstPtr[dstIdx+2], dstPtr[dstIdx+3] = b/c, a/c
			end
		end
	end
	imageData:release()
	return newImageData
end

function RenderUtil.init()
	if love._version_major < 12 then

		-- setBlendState
		local gl_lib = ffi.C
		if ffi.os ~= "Windows" then pcall(function() gl_lib = ffi.load("GL") end) end -- aaughhhhe

		if game.os == "Android" or game.os == "iOS" then
			love.graphics.setBlendState = __NULL__
			Logger.log("debug", "Cannot reimplement setBlendState on Mobile devices. Please update to LÖVE 12")
			return
		end

		ffi.cdef[[
			typedef unsigned int GLenum;
			void glBlendEquationSeparate(GLenum modeRGB, GLenum modeAlpha);
			void glBlendFuncSeparate(GLenum sfactorRGB, GLenum dfactorRGB, GLenum sfactorAlpha, GLenum dfactorAlpha);

			typedef void (*PFNGLBLENDEQUATIONSEPARATEPROC) (GLenum modeRGB, GLenum modeAlpha);
			typedef void (*PFNGLBLENDFUNCSEPARATEPROC)	 (GLenum sfactorRGB,
															GLenum dfactorRGB,
															GLenum sfactorAlpha,
															GLenum dfactorAlpha);

			void* SDL_GL_GetProcAddress(const char* proc);
		]]

		local glBlendEquationSeparate, glBlendFuncSeparate

		if ffi.os == "Windows" then
			local sdl = ffi.load("SDL2")
			if not sdl then sdl = ffi.C end

			local function getProc(name)
				local proc = sdl.SDL_GL_GetProcAddress(name)
				if proc == nil then error("Could not load OpenGL function: " .. name) end
				return proc
			end

			glBlendEquationSeparate = ffi.cast("PFNGLBLENDEQUATIONSEPARATEPROC",
											getProc("glBlendEquationSeparate"))
			glBlendFuncSeparate	 = ffi.cast("PFNGLBLENDFUNCSEPARATEPROC",
											getProc("glBlendFuncSeparate"))
		else
			-- ??? ig?
			-- glBlendEquationSeparate = gl_lib.glBlendEquationSeparate
			-- glBlendFuncSeparate	 = gl_lib.glBlendFuncSeparate
			love.graphics.setBlendState = __NULL__
			Logger.log("debug", "not supported yet :)")
			return
		end

		local MODES = {
			add		 = 0x8006, min = 0x8007,
			subtract	= 0x800A, max = 0x8008,
			revsubtract = 0x800B,
		}

		local FACTORS = {
			zero	 = 0,	  oneminussrccolor = 0x0301,
			one	  = 1,	  oneminussrcalpha = 0x0303,
			srccolor = 0x0300, oneminusdstalpha = 0x0305,

			srcalpha = 0x0302, oneminusdstcolor  = 0x0307,
			dstalpha = 0x0304, srcalphasaturated = 0x0308,
			dstcolor = 0x0306,
		}

		local buildError = function(str, factor)
			local str, exp = "Invalid blend %s \"%s\", expected one of those: %s", ""
			if factor == "mode" then
				for k in pairs(MODES) do exp = exp .. (exp ~= "" and ", " or "") .. k end
			elseif factor == "factor" then
				for k in pairs(FACTORS) do exp = exp .. (exp ~= "" and ", " or "") .. k end
			end
			return str:format(factor, str, exp)
		end

		love.graphics.setBlendState = function(modeRGB, modeAlpha, srcRGB, srcAlpha, dstRGB, dstAlpha)
			local glmc, glma = MODES[modeRGB], MODES[modeAlpha]

			local glsc, glsa = FACTORS[srcRGB], FACTORS[srcAlpha]
			local gldc, glda = FACTORS[dstRGB], FACTORS[dstAlpha]

			glBlendEquationSeparate(glmc, glma)
			glBlendFuncSeparate(glsc, gldc, glsa, glda)
		end
	end

	local newImage = love.graphics.newImage
	love.graphics.newImage = function(source, settings, skipAll)
		settings = table.clone(settings)
		local isFullQuality = false
		if type(settings) == "table" then
			isFullQuality = settings.fullQuality
			settings.fullQuality = nil
		end

		if skipAll then return newImage(source, settings) end

		local imageData
		if type(source) == "string" or (type(source) == "userdata" and source:typeOf("FileData")) then
			imageData = love.image.newImageData(source)
		elseif type(source) == "userdata" and source:typeOf("ImageData") then
			imageData = source
		else
			return newImage(source, settings)
		end

		if RenderUtil.alphaBleeding then
			imageData = RenderUtil.applyAlphaBleed(imageData)
		end

		if RenderUtil.imageQuality ~= 1 and not isFullQuality then
			imageData = RenderUtil.shrink(imageData)

			if RenderUtil.alphaBleeding then
				imageData = RenderUtil.applyAlphaBleed(imageData)
			end
			settings = settings or {}
			settings.dpiscale = (settings.dpiscale or 1) * RenderUtil.imageQuality
		end

		local img = newImage(imageData, settings)
		imageData:release()
		return img
	end
end

return RenderUtil
