require "love.image"
require "love.sound"
require "love.audio"
require "love.timer"

local results = {}

local c_task = love.thread.getChannel("async_tasks")
local c_results = love.thread.getChannel("async_results")

local s, Https = pcall(require, "https")
if not s then Https = require "lib.https" end

local function startsWith(string, prefix)
	return string.find(string, prefix, 1, true) == 1
end

local regex_ext = "%.([^%.]+)$"
local function ext(string) return string:match(regex_ext) or string end

local function getFromURL(url, ext)
	local success, code, response = pcall(Https.request, url)
	if not success or code ~= 200 then
		-- error("failed to fetch image: " .. tostring(code))
		return
	end

	local random = "temp" .. string.format("%04d", math.random(1, 9999)) .. "." .. ext
	local filedata = love.filesystem.newFileData(response, random)
	return filedata
end

local function load(type, path, id)
	local success, data
	if type == "image" then
		if startsWith(path, "http://") or startsWith(path, "https://") then
			success, data = pcall(love.image.newImageData, getFromURL(path, "png"))
		else
			local fun = ext(path) ~= "png"
						and love.image.newCompressedData
						or love.image.newImageData
			success, data = pcall(fun, path)
		end
	elseif type == "sound" then
		if startsWith(path, "http://") or startsWith(path, "https://") then
			success, data = pcall(love.sound.newSoundData, getFromURL(path, "ogg"))
		else
			success, data = pcall(love.sound.newSoundData, path)
		end
	elseif type == "audio" then
		if startsWith(path, "http://") or startsWith(path, "https://") then
			success, data = pcall(love.audio.newSource, getFromURL(path, "ogg"), "stream")
		else
			success, data = pcall(love.audio.newSource, path, "stream")
		end
	elseif type == "text" then
		if startsWith(path, "http://") or startsWith(path, "https://") then
			success, data = pcall(function()
				local code, response = Https.request(path)
				if code ~= 200 then
					error("Failed to fetch text: HTTP " .. tostring(code))
				end
				return response
			end)
		else
			success, data = false, "Text loading requires URL"
		end
	end
	if not success then
		return {false, tostring(data or ("missing type: " .. type)), id, type, path}
	end
	return {true, data, id, type, path}
end

while true do
	local task = c_task:demand()
	if task == "exit" then
		collectgarbage()
		collectgarbage()
		break
	end

	local type, task, id = unpack(task)
	if task then
		c_results:push(load(type, task, id))
	else
		collectgarbage()
		love.timer.sleep(0.12)
	end
end
