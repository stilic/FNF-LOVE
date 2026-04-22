-- classic

-- Copyright (c) 2014, rxi

-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.

---@class Classic
---@operator call:fun(...:any)
local type = type
local rawget = rawget
local rawset = rawset
local getmetatable = getmetatable
local setmetatable = setmetatable
local pairs = pairs
local select = select
local tostring = tostring
local byte = string.byte

local Classic = {
	__class = "Classic"
}
Classic.__index = Classic

function Classic:new() end

function Classic:clone()
	local meta = getmetatable(self)
	local super = rawget(self, "super")
	local index = rawget(self, "__index")

	setmetatable(self, nil)
	self.__index = nil
	self.super = nil

	local clone = table.clone(self)

	setmetatable(self, meta)
	setmetatable(clone, meta)

	clone.__index = index
	self.__index = index
	clone.super = super
	self.super = super

	return clone
end

function Classic:extend(type_name, use_getset)
	local cls = {}

	for k, v in pairs(self) do
		if type(k) == "string" and byte(k, 1) == 95 and byte(k, 2) == 95 then
			if k ~= "__getters" and k ~= "__setters" and k ~= "__newindex" then
				cls[k] = v
			end
		end
	end

	cls.__class = type_name or "Unknown"
	cls.super = self

	if use_getset then
		cls.__getters = setmetatable({}, {__index = self.__getters})
		cls.__setters = setmetatable({}, {__index = self.__setters})

		cls.__index = function(instance, key)
			local getter = cls.__getters[key]
			if getter then return getter(instance) end
			return cls[key]
		end

		cls.__newindex = function(self_inst, k, v)
			local is_inst = rawget(self_inst, "__class") == nil
			local src = is_inst and getmetatable(self_inst) or self_inst

			-- Fast lookup in the registry
			local setter = src.__setters and src.__setters[k]

			if setter then
				-- Direct call: No string concatenation, no while-loop
				if is_inst then setter(self_inst, v) else setter(v, nil) end
			else
				rawset(self_inst, k, v)
			end
		end
	else
		cls.__index = cls
		cls.__newindex = rawset
	end

	return setmetatable(cls, self)
end

function Classic:implement(...)
	for i = 1, select("#", ...) do
		local cls = select(i, ...)
		for k, v in pairs(cls) do
			if self[k] == nil and type(v) == "function" and k ~= "new" then
				if not (type(k) == "string" and byte(k, 1) == 95 and byte(k, 2) == 95) then
					self[k] = v
				end
			end
		end
	end
end

function Classic:exclude(...)
	for i = 1, select("#", ...) do
		self[select(i, ...)] = nil
	end
end

function Classic:is(T)
	local mt = self
	while mt do
		mt = getmetatable(mt)
		if mt == T then return true end
	end
	return false
end

function Classic:__tostring()
	return self.__class
end

function Classic:__call(...)
	local obj = setmetatable({}, self)
	obj:new(...)
	return obj
end

return Classic
