local ffi = require("ffi")

local PointCData
local PointMethods = {}

function PointMethods:new(x, y, z)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
	return self
end

function PointMethods:clone()
	return PointCData(self.x, self.y, self.z)
end

function PointMethods:add(other)
	if type(other) == "number" then
		self.x = self.x + other
		self.y = self.y + other
		self.z = self.z + other
	else
		self.x = self.x + other.x
		self.y = self.y + other.y
		self.z = self.z + (other.z or 0)
	end
	return self
end

function PointMethods:sub(other)
	if type(other) == "number" then
		self.x = self.x - other
		self.y = self.y - other
		self.z = self.z - other
	else
		self.x = self.x - other.x
		self.y = self.y - other.y
		self.z = self.z - (other.z or 0)
	end
	return self
end

function PointMethods:mul(value)
	if type(value) == "number" then
		self.x = self.x * value
		self.y = self.y * value
		self.z = self.z * value
	else
		self.x = self.x * value.x
		self.y = self.y * value.y
		self.z = self.z * (value.z or 1)
	end
	return self
end

function PointMethods:div(value)
	if type(value) == "number" then
		local invVal = 1.0 / value
		self.x = self.x * invVal
		self.y = self.y * invVal
		self.z = self.z * invVal
	else
		self.x = self.x / value.x
		self.y = self.y / value.y
		self.z = self.z / (value.z or 1)
	end
	return self
end

function PointMethods:dot(other)
	return self.x * other.x + self.y * other.y + self.z * (other.z or 0)
end

function PointMethods:cross(other)
	return PointCData(
		self.y * (other.z or 0) - self.z * other.y,
		self.z * other.x - self.x * (other.z or 0),
		self.x * other.y - self.y * other.x
	)
end

function PointMethods:lengthSq()
	return self.x * self.x + self.y * self.y + self.z * self.z
end

function PointMethods:length()
	return math.sqrt(self:lengthSq())
end

function PointMethods:normalize()
	local len = self:length()
	if len > 0 then
		local invLen = 1.0 / len
		self.x = self.x * invLen
		self.y = self.y * invLen
		self.z = self.z * invLen
	end
	return self
end

function PointMethods:normalized()
	local result = self:clone()
	return result:normalize()
end

function PointMethods:distanceSq(other)
	local dx = self.x - other.x
	local dy = self.y - other.y
	local dz = self.z - (other.z or 0)
	return dx * dx + dy * dy + dz * dz
end

function PointMethods:distance(other)
	return math.sqrt(self:distanceSq(other))
end

function PointMethods:lerp(other, t)
	self.x = self.x + (other.x - self.x) * t
	self.y = self.y + (other.y - self.y) * t
	self.z = self.z + ((other.z or self.z) - self.z) * t
	return self
end

function PointMethods:rotate(angle)
	local c = math.cos(angle)
	local s = math.sin(angle)
	local nx = self.x * c - self.y * s
	local ny = self.x * s + self.y * c
	self.x, self.y = nx, ny
	return self
end

function PointMethods:set(x, y, z)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
	return self
end

function PointMethods:zero()
	self.x, self.y, self.z = 0, 0, 0
	return self
end

function PointMethods:equals(other, epsilon)
	epsilon = epsilon or 1e-10
	return math.abs(self.x - other.x) < epsilon and
		   math.abs(self.y - other.y) < epsilon and
		   math.abs(self.z - (other.z or 0)) < epsilon
end

local PointMeta = {
	__index = function(self, key)
		if PointMethods[key] then return PointMethods[key] end

		if key == 1 then return self.x
		elseif key == 2 then return self.y
		elseif key == 3 then return self.z end
	end,

	__newindex = function(self, key, value)
		if key == 1 then self.x = value
		elseif key == 2 then self.y = value
		elseif key == 3 then self.z = value
		else
			error("FFI Struct constraint: Cannot add arbitrary key '" .. tostring(key) .. "' to Point.")
		end
	end,

	__add = function(a, b)
		if type(a) == "number" then
			return PointCData(a + b.x, a + b.y, a + (b.z or 0))
		elseif type(b) == "number" then
			return PointCData(a.x + b, a.y + b, (a.z or 0) + b)
		else
			return PointCData(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0))
		end
	end,

	__sub = function(a, b)
		if type(a) == "number" then
			return PointCData(a - b.x, a - b.y, a - (b.z or 0))
		elseif type(b) == "number" then
			return PointCData(a.x - b, a.y - b, (a.z or 0) - b)
		else
			return PointCData(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0))
		end
	end,

	__mul = function(a, b)
		if type(a) == "number" then
			return PointCData(a * b.x, a * b.y, a * (b.z or 0))
		elseif type(b) == "number" then
			return PointCData(a.x * b, a.y * b, (a.z or 0) * b)
		else
			return PointCData(a.x * b.x, a.y * b.y, (a.z or 0) * (b.z or 1))
		end
	end,

	__div = function(a, b)
		if type(a) == "number" then
			return PointCData(a / b.x, a / b.y, a / (b.z or 0))
		elseif type(b) == "number" then
			local invB = 1.0 / b
			return PointCData(a.x * invB, a.y * invB, (a.z or 0) * invB)
		else
			return PointCData(a.x / b.x, a.y / b.y, (a.z or 0) / (b.z or 1))
		end
	end,

	__eq = function(a, b)
		if not a or not b then return false end
		if type(a) == "number" or type(b) == "number" then return false end

		return a.x == b.x and a.y == b.y and (a.z or 0) == (b.z or 0)
	end,

	__unm = function(a)
		return PointCData(-a.x, -a.y, -(a.z or 0))
	end,

	__tostring = function(self)
		return string.format("Point(%f, %f, %f)", self.x, self.y, self.z)
	end
}

if Project.flags.jitFFI then
	ffi.cdef[[ typedef struct { float x, y, z; } FFI_Point3; ]]
	PointCData = ffi.typeof("FFI_Point3")
	ffi.metatype(PointCData, PointMeta)
else
	PointCData = function(x, y, z)
		return setmetatable({
			x = x or 0,
			y = y or 0,
			z = z or 0
		}, PointMeta)
	end
end

local PointModule = {}
setmetatable(PointModule, {
	__call = function(_, x, y, z)
		return PointCData(x or 0, y or 0, z or 0)
	end
})

function PointModule.static_add(a, b)
	return PointMeta.__add(a, b)
end

function PointModule.static_sub(a, b)
	return PointMeta.__sub(a, b)
end

function PointModule.static_lerp(a, b, t)
	return PointCData(
		a.x + (b.x - a.x) * t,
		a.y + (b.y - a.y) * t,
		(a.z or 0) + ((b.z or 0) - (a.z or 0)) * t
	)
end

function PointModule.get(x, y, z)
	return PointCData(x or 0, y or 0, z or 0)
end

return PointModule
