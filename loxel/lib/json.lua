-- json.lua from https://github.com/actboy168/json.lua
-- Modified by Stilic and Victor Kaoy for FNF LÖVE

local ffi = require("ffi")
local utf8 = utf8 or require "utf8"

local type = type
local next = next
local error = error
local tonumber = tonumber
local tostring = tostring
local table_concat = table.concat
local table_sort = table.sort
local string_char = string.char
local string_byte = string.byte
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local string_sub = string.sub
local string_format = string.format
local setmetatable = setmetatable
local getmetatable = getmetatable
local huge = math.huge
local tiny = -huge
local utf8_char = utf8.char
local math_type = math.type or function(v)
	if v >= -2147483648 and v <= 2147483647 and math.floor(v) == v then return "integer" end
	return "float"
end

ffi.cdef[[
	double strtod(const char* nptr, char** endptr);
]]
local end_ptr_ptr = ffi.new("char*[1]")

local json = {}
json.supportSparseArray = true

local objectMt = {}

function json.createEmptyObject()
	return setmetatable({}, objectMt)
end

function json.isObject(t)
	if t[1] ~= nil then return false end
	return next(t) ~= nil or getmetatable(t) == objectMt
end

-- table recycle
local statusVisited = {}
local statusBuilder = {}
local function clear_hash(t) for k in next, t do t[k] = nil end end
local function clear_array(t) for i = 1, #t do t[i] = nil end end

-- json.encode --
local encode_map = {}
local encode_escape_map = {
	["\""] = "\\\"", ["\\"] = "\\\\", ["/"]  = "\\/", ["\b"] = "\\b",
	["\f"] = "\\f",  ["\n"] = "\\n",  ["\r"] = "\\r", ["\t"] = "\\t",
}

local decode_escape_set = {}
local decode_escape_map = {}
for k, v in next, encode_escape_map do
	decode_escape_map[v] = k
	decode_escape_set[string_byte(v, 2)] = true
end

for i = 0, 31 do
	local c = string_char(i)
	if not encode_escape_map[c] then
		encode_escape_map[c] = string_format("\\u%04x", i)
	end
end

local function encode(v)
	local res = encode_map[type(v)](v)
	statusBuilder[#statusBuilder+1] = res
end

encode_map["nil"] = function () return "null" end

local function encode_string(v)
	return string_gsub(v, '[%z\1-\31\\"]', encode_escape_map)
end

function encode_map.string(v)
	statusBuilder[#statusBuilder+1] = '"'
	statusBuilder[#statusBuilder+1] = encode_string(v)
	return '"'
end

local function convertreal(v)
	local g = string_format("%.16g", v)
	if tonumber(g) == v then return g end
	return string_format("%.17g", v)
end

function encode_map.number(v)
	if v ~= v or v <= tiny or v >= huge then error("unexpected number value '"..tostring(v).."'") end
	if math_type(v) == "integer" then return string_format("%d", v) end
	return convertreal(v)
end

function encode_map.boolean(v) return v and "true" or "false" end

function encode_map.table(t)
	local first_val = next(t)
	if first_val == nil then return getmetatable(t) == objectMt and "{}" or "[]" end
	if statusVisited[t] then error("circular reference") end

	statusVisited[t] = true
	if type(first_val) == "string" then
		local keys = {}
		for k in next, t do
			if type(k) ~= "string" then error("invalid table: mixed or invalid key types: "..k) end
			keys[#keys+1] = k
		end
		table_sort(keys)

		local k = keys[1]
		statusBuilder[#statusBuilder+1] = '{"'
		statusBuilder[#statusBuilder+1] = encode_string(k)
		statusBuilder[#statusBuilder+1] = '":'
		encode(t[k])

		for i = 2, #keys do
			k = keys[i]
			statusBuilder[#statusBuilder+1] = ',"'
			statusBuilder[#statusBuilder+1] = encode_string(k)
			statusBuilder[#statusBuilder+1] = '":'
			encode(t[k])
		end
		statusVisited[t] = nil
		return "}"
	elseif json.supportSparseArray then
		local max = 0
		for k in next, t do
			if math_type(k) ~= "integer" or k <= 0 then error("invalid table: mixed or invalid key types: "..k) end
			if max < k then max = k end
		end
		statusBuilder[#statusBuilder+1] = "["
		encode(t[1])
		for i = 2, max do
			statusBuilder[#statusBuilder+1] = ","
			encode(t[i])
		end
		statusVisited[t] = nil
		return "]"
	else
		if t[1] == nil then error("invalid table: sparse array is not supported") end
		if jit and t[0] ~= nil then error("invalid table: mixed or invalid key types: "..0) end

		statusBuilder[#statusBuilder+1] = "["
		encode(t[1])
		local count = 2
		while t[count] ~= nil do
			statusBuilder[#statusBuilder+1] = ","
			encode(t[count])
			count = count + 1
		end

		local k = next(t, count - 1)
		if k ~= nil then
			if type(k) == "number" then error("invalid table: sparse array is not supported")
			else error("invalid table: mixed or invalid key types: "..k) end
		end
		statusVisited[t] = nil
		return "]"
	end
end

local function encode_unexpected(v)
	if v == nil then return "null" else error("unexpected type '"..type(v).."'") end
end
encode_map["function"] = encode_unexpected
encode_map["userdata"] = encode_unexpected
encode_map["thread"] = encode_unexpected

function json.encode(v)
	-- recycled tbls
	clear_hash(statusVisited)
	clear_array(statusBuilder)
	encode(v)
	return table_concat(statusBuilder)
end

-- json.decode --
local statusBuf
local statusBufLen = 0
local buf_ptr --  ffi pointer
local statusPos
local statusTop
local statusAry = {}
local statusRef = {}

local function find_line()
	local line = 1
	local pos = 1
	while true do
		local f, _, nl1, nl2 = string_find(statusBuf, "([\n\r])([\n\r]?)", pos)
		if not f then return line, statusPos - pos + 1 end
		local newpos = f + ((nl1 == nl2 or nl2 == "") and 1 or 2)
		if newpos > statusPos then return line, statusPos - pos + 1 end
		pos = newpos
		line = line + 1
	end
end

local function decode_error(msg)
	error(string_format("ERROR: %s at line %d col %d", msg, find_line()), 2)
end

local function next_byte()
	while statusPos <= statusBufLen do
		local c = buf_ptr[statusPos - 1]
		-- skip spaces tabs CR LF
		if c ~= 32 and c ~= 9 and c ~= 13 and c ~= 10 then return c end
		statusPos = statusPos + 1
	end
	return -1
end

local function decode_unicode_surrogate(s1, s2)
	return utf8_char(0x10000 + (tonumber(s1, 16) - 0xd800) * 0x400 + (tonumber(s2, 16) - 0xdc00))
end

local function decode_unicode_escape(s)
	return utf8_char(tonumber(s, 16))
end

local function decode_string()
	local has_unicode_escape = false
	local has_escape = false
	local i = statusPos + 1

	while true do
		i = string_find(statusBuf, '[%z\1-\31\\"]', i)
		if not i then decode_error "expected closing quote for string" end

		local x = buf_ptr[i - 1]
		if x < 32 then
			statusPos = i
			decode_error "control character in string"
		end
		if x == 34 --[[ '"' ]] then
			local s = string_sub(statusBuf, statusPos + 1, i - 1)
			if has_unicode_escape then
				s = string_gsub(string_gsub(s, "\\u([dD][89aAbB]%x%x)\\u([dD][c-fC-F]%x%x)", decode_unicode_surrogate), "\\u(%x%x%x%x)", decode_unicode_escape)
			end
			if has_escape then s = string_gsub(s, "\\.", decode_escape_map) end
			statusPos = i + 1
			return s
		end

		local nx = buf_ptr[i]
		if nx == 117 --[[ "u" ]] then
			if not string_match(statusBuf, "^%x%x%x%x", i + 2) then
				statusPos = i
				decode_error "invalid unicode escape in string"
			end
			has_unicode_escape = true
			i = i + 6
		else
			if not decode_escape_set[nx] then
				statusPos = i
				decode_error("invalid escape char in string")
			end
			has_escape = true
			i = i + 2
		end
	end
end

local function decode_number_fast()
	local current_ptr = ffi.cast("const char*", buf_ptr + (statusPos - 1))

	local num = ffi.C.strtod(current_ptr, end_ptr_ptr)
	local consumed = ffi.cast("const char*", end_ptr_ptr[0]) - current_ptr
	if consumed == 0 then decode_error("invalid number at position " .. statusPos) end

	statusPos = statusPos + tonumber(consumed)
	return num
end

local function decode_true()
	if buf_ptr[statusPos] ~= 114 or buf_ptr[statusPos+1] ~= 117 or buf_ptr[statusPos+2] ~= 101 then
		decode_error("invalid literal")
	end
	statusPos = statusPos + 4
	return true
end

local function decode_false()
	if buf_ptr[statusPos] ~= 97 or buf_ptr[statusPos+1] ~= 108 or buf_ptr[statusPos+2] ~= 115 or buf_ptr[statusPos+3] ~= 101 then
		decode_error("invalid literal")
	end
	statusPos = statusPos + 5
	return false
end

local function decode_null()
	if buf_ptr[statusPos] ~= 117 or buf_ptr[statusPos+1] ~= 108 or buf_ptr[statusPos+2] ~= 108 then
		decode_error("invalid literal")
	end
	statusPos = statusPos + 4
	return nil
end

local function decode_array()
	statusPos = statusPos + 1
	if next_byte() == 93 --[[ "]" ]] then
		statusPos = statusPos + 1
		return {}
	end
	local res = {}
	statusTop = statusTop + 1
	statusAry[statusTop] = true
	statusRef[statusTop] = res
	return res
end

local function decode_object()
	statusPos = statusPos + 1
	if next_byte() == 125 --[[ "}" ]] then
		statusPos = statusPos + 1
		return json.createEmptyObject()
	end
	local res = {}
	statusTop = statusTop + 1
	statusAry[statusTop] = false
	statusRef[statusTop] = res
	return res
end

local decode_uncompleted_map = {
	[string_byte '"'] = decode_string,
	[string_byte "t"] = decode_true,
	[string_byte "f"] = decode_false,
	[string_byte "n"] = decode_null,
	[string_byte "["] = decode_array,
	[string_byte "{"] = decode_object,
}

for b = 48, 57 do decode_uncompleted_map[b] = decode_number_fast end
decode_uncompleted_map[string_byte "-"] = decode_number_fast

local function unexpected_character()
	decode_error("unexpected character '"..string_char(buf_ptr[statusPos-1]).."'")
end
local function unexpected_eol()
	decode_error("unexpected character '<eol>'")
end

local decode_map = {}
for i = 0, 255 do decode_map[i] = decode_uncompleted_map[i] or unexpected_character end
decode_map[-1] = unexpected_eol

local function decode() return decode_map[next_byte()]() end

local function decode_item()
	local top = statusTop
	local ref = statusRef[top]

	if statusAry[top] then
		ref[#ref+1] = decode()
	else
		if next_byte() ~= 34 then decode_error("expected '\"'") end
		local key = decode_string()
		if next_byte() ~= 58 then decode_error("expected ':'") end
		statusPos = statusPos + 1
		ref[key] = decode()
	end

	if top == statusTop then
		repeat
			local chr = next_byte()
			statusPos = statusPos + 1
			if chr == 44 --[[ "," ]] then return end

			if statusAry[statusTop] then
				if chr ~= 93 --[[ "]" ]] then decode_error "expected ']' or ','" end
			else
				if chr ~= 125 --[[ "}" ]] then decode_error "expected '}' or ','" end
			end
			statusTop = statusTop - 1
		until statusTop == 0
	end
end

function json.decode(str)
	if type(str) ~= "string" then error("expected argument of type string, got "..type(str)) end

	if #str >= 3 and string_byte(str, 1) == 0xEF and string_byte(str, 2) == 0xBB and string_byte(str, 3) == 0xBF then
		str = string_sub(str, 4)
	end

	statusBuf = str
	statusBufLen = #str
	-- ffi  cast for rapid o1 byte reading
	buf_ptr = ffi.cast("const uint8_t*", str)
	statusPos = 1
	statusTop = 0

	local res = decode()
	while statusTop > 0 do
		decode_item()
	end

	if next_byte() ~= -1 then decode_error "trailing garbage" end
	return res
end

return json
