require "love.system"

local https = {
	-- boundary must include a %s (for os.time) and %04i (for the random number)
	boundary = "FNF_LOVE_REQ_%s%04i",
	mimes = {
		png = "image/png",
		jpg = "image/jpeg",
		jpeg = "image/jpeg",
		txt = "text/plain",
		json = "application/json",
		default = "application/octet-stream"
	}
}

local OS = love.system.getOS()
local s, lib = pcall(require, "https")

if not s then
	if OS == "Android" or OS == "iOS" then
		local __NULL__ = function() end
		lib = setmetatable({}, {__index = function() return __NULL__ end})
	else
		if OS == "OS X" then OS = "osx" end
		local loader, err_msg = package.loadlib("lib/" .. OS:lower() .. "/https", "luaopen_https")
		if type(loader) == "function" then
			lib = loader()
		end
	end
end

if not lib then
	if Logger then Logger.log("error", "HTTPS Module failed: " .. tostring(err_msg)) end
	-- makes a curl request, in case the modules fails
	lib = {
		request = function(url, options)
			print("curl req")
			options = options or {}
			local pointer = tostring({}):match("0x[%x]+") or tostring(math.random(100000, 999999))
			local time_str = tostring(os.clock()):gsub("%.", "")
			local dir = love.filesystem.getSaveDirectory()
			local temp_out = dir .. "/tmp_curlout_" .. pointer .. ".bin"
			local temp_body = dir .. "/tmp_curlbody_" .. pointer .. ".bin"
			local temp_head = dir .. "/tmp_curlhead_" .. pointer .. ".txt"

			local safe_url = url:gsub('"', '\\"')
			local cmd = 'curl -s -L -w "%{http_code}" -D "' .. temp_head .. '" -o "' .. temp_out .. '"'

			if options.method then
				cmd = cmd .. ' -X ' .. options.method
			end

			if options.headers then
				for k, v in pairs(options.headers) do
					local safe_k = tostring(k):gsub('"', '\\"')
					local safe_v = tostring(v):gsub('"', '\\"')
					cmd = cmd .. ' -H "' .. safe_k .. ': ' .. safe_v .. '"'
				end
			end

			if options.data then
				local f = io.open(temp_body, "wb")
				if f then
					f:write(options.data)
					f:close()
					cmd = cmd .. ' --data-binary "@' .. temp_body .. '"'
				end
			end

			cmd = cmd .. ' "' .. safe_url .. '"'

			local handle = io.popen(cmd)
			if not handle then
				os.remove(temp_body)
				os.remove(temp_head)
				return 0, nil, {}
			end

			local status_str = handle:read("*a")
			handle:close()

			local status_code = tonumber(status_str) or 0
			local body = ""
			local f = io.open(temp_out, "rb")
			if f then
				body = f:read("*a")
				f:close()
				os.remove(temp_out)
			end

			local headers = {}
			local hf = io.open(temp_head, "r")
			if hf then
				for line in hf:lines() do
					local key, value = line:match("^(.-):%s*(.*)$")
					if key and value then
						headers[key:lower()] = value:gsub("\r", "")
					end
				end
				hf:close()
				os.remove(temp_head)
			end

			if options.data then os.remove(temp_body) end

			return status_code, body, headers
		end
	}
end

function https.request(url, options)
	options = options or {}
	if options.data and not (options.headers and options.headers["Content-Length"]) then
		options.headers = options.headers or {}
		options.headers["Content-Length"] = tostring(#options.data)
	end
	return lib.request(url, options)
end

function https.buildFormData(fields, files)
	local boundary, body = https.boundary:format(os.time(), math.random(1, 9999)), {}

	if fields then
		for key, value in pairs(fields) do
			table.insert(body, "--" .. boundary .. "\r\n")
			table.insert(body, 'Content-Disposition: form-data; name="' .. tostring(key) .. '"\r\n\r\n')
			table.insert(body, tostring(value) .. "\r\n")
		end
	end
	if files then
		for key, fileInfo in pairs(files) do
			table.insert(body, "--" .. boundary .. "\r\n")
			table.insert(body, 'Content-Disposition: form-data; name="' .. tostring(key) .. '"; filename="' .. tostring(fileInfo.filename) .. '"\r\n')
			table.insert(body, 'Content-Type: ' .. (fileInfo.contentType or "application/octet-stream") .. '\r\n\r\n')
			table.insert(body, fileInfo.data .. "\r\n")
		end
	end
	table.insert(body, "--" .. boundary .. "--\r\n")
	return table.concat(body), "multipart/form-data; boundary=" .. boundary
end

function https.buildQuery(params)
	local query = {}
	for k, v in pairs(params) do
		local serial = tostring(v):gsub("([^%w%-%.%_%~])", function(c)
			return string.format("%%%02X", string.byte(c))
		end)
		table.insert(query, k .. "=" .. serial)
	end
	return "?" .. table.concat(query, "&")
end

function https.mimeType(filename)
	local ext = filename:match("%.([^%.]+)$")
	return https.mimes[ext:lower()] or https.mimes.default
end

function https.get(url, headers)
	return https.request(url, {method = "GET", headers = headers})
end

function https.post(url, data, headers)
	return https.request(url, {method = "POST", data = data, headers = headers})
end

return https
