local Logger = {}

Logger.levels = {
	DEBUG = {color = "blue",   prefix = "[  DEBUG  ]"},
	INFO  = {color = "green",  prefix = "[  INFO   ]"},
	WARN  = {color = "yellow", prefix = "[  WARN   ]"},
	ERROR = {color = "red",    prefix = "[  ERROR  ]"}
}

local function getPath(l)
	local info = debug.getinfo(l or 3, "Sl")
	if info and info.source then
		local source = info.source
		if source:sub(1, 1) == "@" then source = source:sub(2) end

		local parts = {}
		for part in source:gmatch("[^/\\]+") do table.insert(parts, part) end

		local path
		if #parts >= 2 then
			path = parts[#parts - 1] .. "/" .. parts[#parts]
		elseif #parts == 1 then
			path = parts[1]
		else
			path = "unknown"
		end

		local line = info.currentline or "?"
		return path .. ":" .. line
	end
	return "unknown"
end

function Logger.log(level, str, l)
	local info = Logger.levels[level:upper()]
	if info then
		local path = getPath(l)
		local code = info.color == "red" and "31" or
					 info.color == "green" and "32" or
					 info.color == "yellow" and "33" or "94"

		print(string.format("\27[%sm%s [  %s  ]\27[0m %s",
			code, info.prefix, path, str))

		if level == "error" and Toast.showErrors then
			Toast.error(path .. ": " .. str)
		elseif level == "warn" and Toast.showDeprecations then
			Toast.deprecated(path .. ": " .. str)
		end
	end
end

return Logger
