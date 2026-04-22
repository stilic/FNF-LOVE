local string_match = string.match
local string_sub = string.sub
local string_gsub = string.gsub
local string_find = string.find
local string_char = string.char
local tonumber = tonumber
local table_insert = table.insert
local table_remove = table.remove
local type = type
local setmetatable = setmetatable

-- XML parser made by Stilic for FNF LÖVE
-- Based off https://github.com/Cluain/Lua-Simple-XML-Parser

local function trim(str)
	return string_match(str, "^%s*(.-)%s*$")
end

local function endsWith(str, ending)
	return ending == "" or string_sub(str, -#ending) == ending
end

local function count(str, pattern)
	local c = 0
	local i = 1
	while true do
		local _, j = string_find(str, pattern, i, true)
		if not j then break end
		c = c + 1
		i = j + 1
	end
	return c
end

local entity_map = {
	quot = "\"",
	apos = "'",
	gt = ">",
	lt = "<",
	amp = "&"
}

local function fromXmlString(value)
	if not string_find(value, "&", 1, true) then return value end

	value = string_gsub(value, "&#x([%x]+);?", function(h)
		return string_char(tonumber(h, 16))
	end)
	value = string_gsub(value, "&#([0-9]+);?", function(h)
		return string_char(tonumber(h, 10))
	end)
	value = string_gsub(value, "&(%a+);?", entity_map)

	return value
end

local node_methods = {}
node_methods.__index = node_methods

function node_methods:addChild(child)
	if self[child.name] then
		if self[child.name].name and type(self[child.name].name) == "string" then
			local tempTable = {self[child.name]}
			self[child.name] = tempTable
		end
		table_insert(self[child.name], child)
	else
		self[child.name] = child
	end
	table_insert(self.children, child)
end

function node_methods:setAttr(name, value)
	if self.attrs[name] then
		if type(self.attrs[name]) == "string" then
			local tempTable = {self.attrs[name]}
			self.attrs[name] = tempTable
		end
		table_insert(self.attrs[name], value)
	else
		self.attrs[name] = value
	end
end

local function parseArgs(node, s)
	string_gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
		node:setAttr(w, fromXmlString(a))
	end)
end

local function newNode(name)
	local node = {
		name = name,
		children = {},
		attrs = {}
	}
	return setmetatable(node, node_methods)
end

local function parse(xmlText)
	local stack = {}
	local top = newNode()
	table_insert(stack, top)

	local i = 1
	while true do
		local ni, j, c, label, xarg, empty = string_find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
		if not ni then break end

		local text = trim(string_sub(xmlText, i, ni - 1))
		local addNode = true

		if text ~= "" then
			if endsWith(text, "/>") and count(text, '"') % 2 ~= 0 then
				local xargEnd = string_sub(text, 1, #text - 2)
				local first = string_find(xmlText, xargEnd, i, true) - 1
				xargEnd = string_sub(xmlText, first, first) .. xargEnd
				xarg = string_sub(xarg, 1, string_find(xarg, '"', 1, true)) .. xargEnd
				empty = "/"
			else
				stack[#stack].value = (top.value or "") .. fromXmlString(text)
			end
		else
			addNode = count(xarg, '"') % 2 == 0
		end

		if addNode then
			if empty == "/" then
				local lNode = newNode(label)
				parseArgs(lNode, xarg)
				top:addChild(lNode)
			elseif c == "" then
				local lNode = newNode(label)
				parseArgs(lNode, xarg)
				table_insert(stack, lNode)
				top = lNode
			else
				local toclose = table_remove(stack)
				top = stack[#stack]

				if #stack < 1 then
					error("parser: nothing to close with " .. label)
				end
				if toclose.name ~= label then
					error("parser: trying to close " .. toclose.name .. " with " .. label)
				end

				top:addChild(toclose)
			end
		end
		i = j + 1
	end

	if #stack > 1 then
		error("parser: unclosed " .. stack[#stack].name)
	end

	return top
end

return parse
