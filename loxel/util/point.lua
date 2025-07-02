-- point class. (kinda) supports a third z value as well

local Point = Classic:extend("Point")

-- local pool = {}

-- function Point.get(x, y, z)
	-- if #pool > 0 then
		-- local instance = table.remove(pool)
		-- if type(instance) == "table" then
			-- setmetatable(instance, Point)
			-- instance:zero():set(x or instance.x, y or instance.y, z or instance.z)
			-- return instance
		-- end
	-- end

	-- return Point(x, y, z)
-- end

-- function Point.repool(obj)
	-- table.insert(pool, obj)
-- end

function Point:new(x, y, z)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
end

function Point:clone() return Point(self.x, self.y, self.z) end

function Point:add(other)
	self.x = self.x + other.x
	self.y = self.y + other.y
	self.z = self.z + (other.z or 0)
	return self
end

function Point.static_add(a, b)
	return Point(
		a.x + b.x,
		a.y + b.y,
		(a.z or 0) + (b.z or 0)
	)
end

function Point:sub(other)
	self.x = self.x - other.x
	self.y = self.y - other.y
	self.z = self.z - (other.z or 0)
	return self
end

function Point.static_sub(a, b)
	return Point(
		a.x - b.x,
		a.y - b.y,
		(a.z or 0) - (b.z or 0)
	)
end

function Point:mul(value)
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

function Point:div(value)
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

function Point:dot(other)
	return self.x * other.x + self.y * other.y + self.z * (other.z or 0)
end

function Point:cross(other)
	return Point(
		self.y * (other.z or 0) - self.z * other.y,
		self.z * other.x - self.x * (other.z or 0),
		self.x * other.y - self.y * other.x
	)
end

function Point:lengthSq()
	return self.x * self.x + self.y * self.y + self.z * self.z
end

function Point:length()
	return math.sqrt(self:lengthSq())
end

function Point:normalize()
	local len = self:length()
	if len > 0 then
		local invLen = 1.0 / len
		self.x = self.x * invLen
		self.y = self.y * invLen
		self.z = self.z * invLen
	end
	return self
end

function Point:normalized()
	local result = self:clone()
	return result:normalize()
end

function Point:distanceSq(other)
	local dx = self.x - other.x
	local dy = self.y - other.y
	local dz = self.z - (other.z or 0)
	return dx * dx + dy * dy + dz * dz
end

function Point:distance(other)
	return math.sqrt(self:distanceSq(other))
end

function Point:lerp(other, t)
	self.x = self.x + (other.x - self.x) * t
	self.y = self.y + (other.y - self.y) * t
	self.z = self.z + ((other.z or self.z) - self.z) * t
	return self
end

function Point.static_lerp(a, b, t)
	return Point(
		a.x + (b.x - a.x) * t,
		a.y + (b.y - a.y) * t,
		(a.z or 0) + ((b.z or 0) - (a.z or 0)) * t
	)
end

function Point:rotate(angle)
	local c = math.cos(angle)
	local s = math.sin(angle)
	local nx = self.x * c - self.y * s
	local ny = self.x * s + self.y * c
	self.x, self.y = nx, ny
	return self
end

function Point:set(x, y, z)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
	return self
end

function Point:zero()
	self.x, self.y, self.z = 0, 0, 0
	return self
end

function Point:equals(other, epsilon)
	epsilon = epsilon or 1e-10
	return math.abs(self.x - other.x) < epsilon and
				 math.abs(self.y - other.y) < epsilon and
				 math.abs(self.z - (other.z or 0)) < epsilon
end

function Point:__tostring()
	return string.format("Point(%f, %f, %f)", self.x, self.y, self.z)
end

Point.__add = Point.static_add
Point.__sub = Point.static_sub

function Point.__mul(a, b)
	if type(a) == "number" then
		return Point(a * b.x, a * b.y, a * (b.z or 0))
	elseif type(b) == "number" then
		return Point(a.x * b, a.y * b, a.z * b)
	else
		return Point(a.x * b.x, a.y * b.y, (a.z or 0) * (b.z or 1))
	end
end

function Point.__div(a, b)
	if type(b) == "number" then
		local invB = 1.0 / b
		return Point(a.x * invB, a.y * invB, a.z * invB)
	else
		return Point(a.x / b.x, a.y / b.y, a.z / (b.z or 1))
	end
end

function Point.__eq(a, b)
	return a.x == b.x and a.y == b.y and (a.z or 0) == (b.z or 0)
end

function Point.__unm(a)
	return Point(-a.x, -a.y, -a.z)
end

function Point:__index(key)
	if key == 1 then return self.x
	elseif key == 2 then return self.y
	elseif key == 3 then return self.z end
	return rawget(self, key) or Point[key]
end

function Point:__newindex(key, value)
	if key == 1 then self.x = value
	elseif key == 2 then self.y = value
	elseif key == 3 then self.z = value
	else rawset(self, key, value) end
end

return Point
