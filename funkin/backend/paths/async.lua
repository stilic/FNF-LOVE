local async = {debug = true}

local max = math.min(1, love.system.getProcessorCount() - 2)
local threads = {}
local c_task = love.thread.getChannel("async_tasks")
local c_results = love.thread.getChannel("async_results")

local pending = {tasks = {}, callbacks = {}}
local active_tasks = {}
local stats = {queued = 0, completed = 0, active = false}
local timer = {time = 0, timeout = 5}

local function size(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

local thread_code = love.filesystem.read("funkin/backend/paths/thread.lua")

local FrameCollection = loxreq "animation.frame.collection"

stats.active, timer.time = true, 0
local thread
for i = 1, math.min(1, love.system.getProcessorCount() - 1) do
	thread = love.thread.newThread(thread_code)
	table.insert(threads, thread)
	thread:start()
end

function async.processQueue()
	while #pending.tasks > 0 do
		local task = table.remove(pending.tasks, 1)
		local id = task[3]
		active_tasks[id] = true
		c_task:push(task)
	end
end

function async.update(dt)
	while true do
		local result = c_results:pop()
		if not result then break end
		stats.completed = stats.completed + 1

		local success, data, id, type, path = unpack(result)
		active_tasks[id] = nil

		local dispatch, err
		if success then
			if type == "image" then
				local image = love.graphics.newImage(data)
				local cachePath = path
				if path:startsWith("http://") or path:startsWith("https://") then
					cachePath = "online:" .. path
					err = path
				end
				paths.images[cachePath] = image
				data:release()
				dispatch = image
			elseif type == "sound" then
				local cachePath = path
				if path:startsWith("http://") or path:startsWith("https://") then
					cachePath = "online:" .. path
					err = path
				end
				paths.audio[cachePath] = data
				dispatch = data
			elseif type == "audio" then
				local cachePath = path
				if path:startsWith("http://") or path:startsWith("https://") then
					cachePath = "online:" .. path
					err = path
					local source, fileData = data[1], data[2]
					paths.audio[cachePath] = source
					dispatch = source
					fileData:release()
				else
					paths.audio[cachePath] = data
					dispatch = data
				end
			elseif type == "text" then
				dispatch = data
				err = path
			end
		else
			if async.debug then print("async loading failed for " .. path .. ": " .. data) end
			dispatch, err = nil, data
		end

		local callbacks = pending.callbacks[id]
		if callbacks then
			for _, callback in pairs(callbacks) do
				callback(dispatch, err)
			end
		end
		pending.callbacks[id] = nil
	end
end

function async.queueTask(type, path, callback)
	local id = type .. ":" .. path

	if active_tasks[id] or pending.callbacks[id] then
		if callback then
			if not pending.callbacks[id] then
				pending.callbacks[id] = {}
			end
			table.insert(pending.callbacks[id], callback)
		end
		return id
	end

	if #pending.tasks == 0 and size(active_tasks) == 0 then
		stats.queued = 0
		stats.completed = 0
	end

	local task = {type, path, id}

	if callback then
		if not pending.callbacks[id] then
			pending.callbacks[id] = {}
		end
		table.insert(pending.callbacks[id], callback)
	end

	table.insert(pending.tasks, task)
	stats.queued = stats.queued + 1

	async.processQueue()
	return id
end

function async.getImage(key, callback)
	if key:startsWith("http://") or key:startsWith("https://") then
		local path = key
		local obj = paths.images["online:" .. path]
		if obj then
			if callback then callback(obj, key) end
			return obj
		end
		async.queueTask("image", path, callback)
		return true
	else
		local path = paths.getPath("images/" .. key .. ".png")
		local obj = paths.images[path]
		if obj then
			if callback then callback(obj) end
			return obj
		end

		if paths.exists(path, "file") then
			async.queueTask("image", path, callback)
			return true
		else
			if async.debug then print('image not found: ' .. key) end
			if callback then callback(nil) end
		end
	end

	return nil
end

function async.getAudio(key, stream, callback)
	if key:startsWith("http://") or key:startsWith("https://") then
		local path = key
		local obj = paths.audio["online:" .. path]
		if obj then
			if callback then callback(obj, path) end
			return obj
		end
		async.queueTask(stream and "audio" or "sound", path, callback)
		return true
	else
		local path = paths.getPath(key .. ".ogg")
		local obj = paths.audio[path]
		if obj then
			if callback then callback(obj) end
			return obj
		end

		if paths.exists(path, "file") then
			async.queueTask(stream and "audio" or "sound", path, callback)
			return true
		else
			if async.debug then print('audio not found: ' .. key) end
			if callback then callback(nil) end
		end
	end
	return nil
end

function async.getTextFromURL(url, callback)
	if not url:startsWith("http://") and not url:startsWith("https://") then
		if async.debug then print("Invalid URL: " .. url) end
		if callback then callback(nil, "Invalid URL") end
		return nil
	end

	local id = "text:" .. url
	async.queueTask("text", url, callback)
	return true
end

function async.getMusic(key, callback)
	return async.getAudio("music/" .. key, true, callback)
end

function async.getSound(key, callback)
	return async.getAudio("sounds/" .. key, false, callback)
end

function async.getInst(song, suffix, callback)
	return async.getAudio("songs/" .. paths.formatToSongPath(song) .. "/Inst" ..
		(suffix and "-" .. suffix or ""), true, callback)
end

function async.getVoices(song, suffix, callback)
	return async.getAudio("songs/" .. paths.formatToSongPath(song) .. "/Voices" ..
		(suffix and "-" .. suffix or ""), true, callback)
end

local function loadAtlas(key, kind, callback)
	local imgPath = paths.getPath("images/" .. key .. ".png")
	local dataPath = paths.getPath("images/" .. key .. (
		kind == "sparrow" and ".xml" or ".txt"))

	local cachekey = paths.getPath("images/" .. key)
	local obj = paths.atlases[cachekey]

	if obj then if callback then callback(obj) end; return obj end

	if not paths.exists(dataPath, "file") then
		local type = kind == "sparrow" and "XML" or "TXT"
		if async.debug then print(type .. ' file not found for atlas: ' .. key) end
		if callback then callback(nil) end
		return nil
	end

	local function processAtlas(img)
		if not img then if callback then callback(nil) end; return nil end
		local data = love.filesystem.read(dataPath)
		if not data then
			local type = kind == "sparrow" and "XML" or "TXT"
			if async.debug then print('failed to read ' .. type .. ' file: ' .. dataPath) end
			if callback then callback(nil) end
			return nil
		end
		local name = "from" .. kind:capitalize()
		obj = FrameCollection[name](img, data)
		paths.atlases[cachekey] = obj
		if callback then callback(obj) end; return obj
	end

	local img = paths.images[imgPath]
	if img then
		return processAtlas(img)
	else
		async.getImage(key, processAtlas)
		return true
	end
end

function async.getSparrowAtlas(key, callback)
	return loadAtlas(key, "sparrow", callback)
end

function async.getPackerAtlas(key, callback)
	return loadAtlas(key, "packer", callback)
end

function async.getAtlas(key, callback)
	if paths.exists(paths.getPath("images/" .. key .. ".xml"), "file") then
		return async.getSparrowAtlas(key, callback)
	end
	return async.getPackerAtlas(key, callback)
end

function async.loadBatch(files)
	for _, file in ipairs(files) do
		local type, path, suffix = unpack(file)
		switch(type, {
			["image"]  = function() async.getImage(path) end,
			["sound"]  = function() async.getSound(path) end,
			["audio"]  = function() async.getAudio(path, true) end,
			["inst"]   = function() async.getInst(path, suffix) end,
			["voices"] = function() async.getVoices(path, suffix) end
		})
	end
end

function async.getProgress()
	if stats.queued == 0 then return 1 end
	return math.min(1, stats.completed / stats.queued)
end

function async.crashstop()
	for i = 1, #threads do
		c_task:push("exit")
	end

	for i = 1, #threads do
		if threads[i]:isRunning() then
			threads[i]:wait()
		end
	end
end

return async
