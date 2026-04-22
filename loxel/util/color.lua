local ffi = require("ffi")
local bit = bit or require("bit")
local color_c, ctype

local color_mt = {
	__index = function(self, k)
		if k == 1 then return self.r
		elseif k == 2 then return self.g
		elseif k == 3 then return self.b
		elseif k == 4 then return self.a
		end
	end,
	__newindex = function(self, k, v)
		if k == 1 then self.r = v
		elseif k == 2 then self.g = v
		elseif k == 3 then self.b = v
		elseif k == 4 then self.a = v
		end
	end
}

if Project.flags.jitFFI then
	-- this used to be a float type but it has random overflow problems in the 32bit binaries
	ffi.cdef[[
		typedef struct { double r, g, b, a; } color_c;
	]]
	color_c = ffi.typeof("color_c")
	ffi.metatype(color_c, color_mt)
else
	color_c = function(r, g, b, a)
		return setmetatable({r = r or 0, g = g or 0, b = b or 0, a = a or 1}, color_mt)
	end
end

local function fromRGB(r, g, b, a)
	return color_c(r / 255, g / 255, b / 255, a or 1)
end

local function fromHEX(hex)
	hex = tonumber(hex)
	return color_c(
		bit.band(bit.rshift(hex, 16), 0xFF) / 255,
		bit.band(bit.rshift(hex, 8), 0xFF) / 255,
		bit.band(hex, 0xFF) / 255,
		1
	)
end

local colorTable = {
	BLACK   = fromHEX(0x000000),
	BLUE	= fromHEX(0x0000FF),
	BROWN   = fromHEX(0x8B4513),
	CYAN	= fromHEX(0x00FFFF),
	GRAY	= fromHEX(0x808080),
	GREEN   = fromHEX(0x008000),
	LIME	= fromHEX(0x00FF00),
	MAGENTA = fromHEX(0xFF00FF),
	ORANGE  = fromHEX(0xFFA500),
	PINK	= fromHEX(0xFFC0CB),
	PURPLE  = fromHEX(0x800080),
	RED	 = fromHEX(0xFF0000),
	WHITE   = fromHEX(0xFFFFFF),
	YELLOW  = fromHEX(0xFFFF00),
	TRANSPARENT = fromHEX(0x00000000)
}

local Color = {}

function Color.get(c)
	local r, g, b, a

	if type(c) == "cdata" or type(c) == "table" then
		r, g, b, a = c[1] or c.r, c[2] or c.g, c[3] or c.b, c[4] or c.a or 1
		if r > 1 then
			r, g, b, a = r / 255, g / 255, b / 255, a / 255
		end
	elseif type(c) == "string" then
		local col = Color.fromString(c)
		r, g, b, a = col.r, col.g, col.b, col.a
	else
		local col = fromHEX(c)
		r, g, b, a = col.r, col.g, col.b, col.a
	end

	return r, g, b, a
end

function Color.fromHEX(hex) return fromHEX(hex) end

function Color.fromRGB(...) return fromRGB(...) end

function Color.HSLtoRGB(h, s, l)
	local c = (1 - math.abs(l + l - 1)) * s
	local m = l - 0.5 * c
	local r, g, b = m, m, m
	if h == h then
		local h2 = (h % 1.0) * 6.0
		local x = c * (1 - math.abs(h2 % 2 - 1))
		c, x = c + m, x + m
		if h2 < 1 then
			r, g, b = c, x, m
		elseif h2 < 2 then
			r, g, b = x, c, m
		elseif h2 < 3 then
			r, g, b = m, c, x
		elseif h2 < 4 then
			r, g, b = m, x, c
		elseif h2 < 5 then
			r, g, b = x, m, c
		else
			r, g, b = c, m, x
		end
	end
	return r, g, b
end

function Color.RGBtoHSL(r, g, b)
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h, s, l = 0, 0, (max + min) / 2

	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, l
end

function Color.fromHSL(...)
	local r, g, b = Color.HSLtoRGB(...)
	return color_c(r, g, b, 1)
end

function Color.fromString(str)
	local hex = tonumber(str:gsub("[#x]", ""), 16)
	return fromHEX(hex or 0)
end

function Color.convert(rgb)
	return color_c((rgb.r or rgb[1]) / 255,
		(rgb.g or rgb[2]) / 255,
		(rgb.b or rgb[3]) / 255,
		1)
end

function Color.saturate(col, amount)
	local h, s, l = Color.RGBtoHSL(col.r or col[1], col.g or col[2], col.b or col[3])
	s = math.min(1, math.max(0, s + amount))
	local r, g, b = Color.HSLtoRGB(h, s, l)
	return color_c(r, g, b, 1)
end

function Color.lerp(x, y, i)
	return color_c(math.lerp(x.r or x[1], y.r or y[1], i),
		math.lerp(x.g or x[2], y.g or y[2], i),
		math.lerp(x.b or x[3], y.b or y[3], i),
		1)
end

function Color.lerpDelta(x, y, i, delta)
	local factor = math.exp(-(delta or game.dt) * i)
	return color_c(math.lerp(y.r or y[1], x.r or x[1], factor),
		math.lerp(y.g or y[2], x.g or x[2], factor),
		math.lerp(y.b or y[3], x.b or x[3], factor),
		1)
end

function Color.vec4(tbl, ...)
	local args = {...}
	local fill = {tbl.r or tbl[1], tbl.g or tbl[2], tbl.b or tbl[3], tbl.a or tbl[4] or 1}

	local idx = 1
	for i = (tbl.r and 5 or #tbl + 1), 4 do
		if idx <= #args then
			fill[i] = args[idx]
			idx = idx + 1
		else
			fill[i] = 0
		end
	end

	return fill[1], fill[2], fill[3], fill[4]
end

setmetatable(Color, {
	__index = function(tbl, key)
		if colorTable[key] then return color_c(colorTable[key].r, colorTable[key].g, colorTable[key].b, colorTable[key].a) end
	end
})

return Color
