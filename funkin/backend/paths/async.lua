local async = {debug = true}

local MAX_THREADS = 6
local THREAD_TIMEOUT = 10
local threads = {}
local thread_times = {}
local tasks = love.thread.getChannel("async_tasks")
local results = love.thread.getChannel("async_results")

local queue = {tasks = {}, callbacks = {}}
local active = {}
local stats = {queued = 0, completed = 0, running = false}

local targetLib = nil
local AnimateLibrary = require "funkin.backend.animatelibrary"

local loaders = {
	image = function(path, fullQuality) async.getImage(path, nil, fullQuality) end,
	sound = function(path) async.getSound(path) end,
	audio = function(path) async.getAudio(path, true) end,
	inst = function(path, suffix) async.getInst(path, suffix) end,
	voices = function(path, suffix) async.getVoices(path, suffix) end,
	animate = function(path) async.getAnimateAtlas(path) end
}

local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function isUrl(path)
	return path:startsWith("http://") or path:startsWith("https://")
end

local function getCachePath(path)
	return isUrl(path) and ("online:" .. path) or path
end

local function log(msg, stack)
	if async.debug then Logger.log("debug", msg,  stack or 5) end
end

local code = love.filesystem.read("funkin/backend/paths/thread.lua")
local function createThread()
	if #threads >= MAX_THREADS then return false end
	local thread = love.thread.newThread(code)
	table.insert(threads, thread)
	table.insert(thread_times, love.timer.getTime())
	thread:start()
	return true
end

local function cleanupIdleThreads()
	local current_time = love.timer.getTime()
	local active_count = count(active)

	for i = #threads, 1, -1 do
		local thread = threads[i]
		local last_used = thread_times[i]

		if current_time - last_used > THREAD_TIMEOUT and active_count == 0 and #queue.tasks == 0 then
			tasks:push("exit")
			table.remove(threads, i)
			table.remove(thread_times, i)
		elseif not thread:isRunning() then
			table.remove(threads, i)
			table.remove(thread_times, i)
		end
	end
end

local function ensureThreads()
	local needed = math.min(MAX_THREADS, #queue.tasks + count(active))
	while #threads < needed do
		if not createThread() then break end
	end
	for i = 1, #thread_times do
		thread_times[i] = love.timer.getTime()
	end
end

local fullQualityTbl = {fullQuality = true}
local function processImage(data, path, fullQuality)
	local image = love.graphics.newImage(data, fullQuality and fullQualityTbl or nil)
	local cache = getCachePath(path)
	targetLib.images[cache] = image
	data:release()
	return image, isUrl(path) and path or nil
end

local function processSound(data, path)
	local cache = getCachePath(path)
	targetLib.audio[cache] = data
	return data, isUrl(path) and path or nil
end

local function processAudio(data, path)
	local cache = getCachePath(path)
	if isUrl(path) then
		local source, fileData = data[1], data[2]
		targetLib.audio[cache] = source
		fileData:release()
		return source, path
	else
		targetLib.audio[cache] = data
		return data, nil
	end
end

local function processText(data, path)
	return data, path
end

local processors = {
	image = processImage,
	sound = processSound,
	audio = processAudio,
	text = processText
}

function async.processQueue()
	while #queue.tasks > 0 do
		local task = table.remove(queue.tasks, 1)
		local id = task[3]
		active[id] = { fullQuality = task[4] }
		tasks:push(task)
	end
end

function async.update(dt)
	cleanupIdleThreads()

	while true do
		local result = results:pop()
		if not result then break end

		stats.completed = stats.completed + 1
		local success, data, id, type, path = unpack(result)

		local activeTask = active[id]
		local isFullQuality = activeTask and activeTask.fullQuality
		active[id] = nil

		local dispatch, err
		if success and processors[type] then
			if type == "image" then
				dispatch, err = processors[type](data, path, isFullQuality)
			else
				dispatch, err = processors[type](data, path)
			end
		else
			log("async loading failed for " .. path .. ": " .. tostring(data), 4)
			dispatch, err = nil, data
		end

		local callbacks = queue.callbacks[id]
		if callbacks then
			for _, callback in pairs(callbacks) do
				callback(dispatch, err)
			end
			queue.callbacks[id] = nil
		end
	end
end

function async.queueTask(type, path, callback, imgFullQ)
	local id = type .. ":" .. path

	if active[id] or queue.callbacks[id] then
		if callback then
			queue.callbacks[id] = queue.callbacks[id] or table.new(1, 0)
			table.insert(queue.callbacks[id], callback)
		end
		return id
	end

	if #queue.tasks == 0 and count(active) == 0 then
		stats.queued = 0
		stats.completed = 0
	end

	if callback then
		queue.callbacks[id] = {callback}
	end

	table.insert(queue.tasks, {type, path, id, imgFullQ})
	stats.queued = stats.queued + 1

	ensureThreads()
	async.processQueue()
	return id
end

local formats = {"astc", "ktx", "dds", "png"}

local function findImagePath(key)
	local base = "images/" .. key .. "."
	local support = paths.compressedSupport

	for _, fmt in ipairs(formats) do
		if fmt == "png" or (support and support[fmt]) then
			local path = paths.getPath(base .. fmt)
			if paths.exists(path, "file") then
				return path
			end
		end
	end
	return nil
end

function async.getImage(key, callback, fullQuality)
	if isUrl(key) then
		local cache = getCachePath(key)
		if targetLib.images[cache] then
			if callback then callback(targetLib.images[cache], key) end
			return targetLib.images[cache]
		end
		async.queueTask("image", key, callback, fullQuality)
		return true
	else
		local path = findImagePath(key)

		if path and targetLib.images[path] then
			if callback then callback(targetLib.images[path]) end
			return targetLib.images[path]
		end

		if path and paths.exists(path, "file") then
			async.queueTask("image", path, callback, fullQuality)
			return true
		else
			log('image not found: ' .. key)
			if callback then callback(nil) end
		end
	end
	return nil
end

function async.getAudio(key, stream, callback)
	if isUrl(key) then
		local cache = "online:" .. key
		local obj = targetLib.audio[cache]
		if obj then
			if callback then callback(obj, key) end
			return obj
		end
		async.queueTask(stream and "audio" or "sound", key, callback)
		return true
	else
		local path = paths.getPath(key .. ".ogg")
		local obj = targetLib.audio[path]
		if obj then
			if callback then callback(obj) end
			return obj
		end
		if paths.exists(path, "file") then
			async.queueTask(stream and "audio" or "sound", path, callback)
			return true
		else
			log('audio not found: ' .. key)
			if callback then callback(nil) end
		end
	end
	return nil
end

function async.getTextFromURL(url, callback)
	if not isUrl(url) then
		log("Invalid URL: " .. url)
		if callback then callback(nil, "Invalid URL") end
		return nil
	end
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
	local ext = kind == "sparrow" and ".xml" or ".txt"
	local dataPath = paths.getPath("images/" .. key .. ext)
	local cacheKey = paths.getPath("images/" .. key)
	local obj = targetLib.atlases[cacheKey]

	if obj then
		if callback then callback(obj) end
		return obj
	end

	if not paths.exists(dataPath, "file") then
		log((kind == "sparrow" and "XML" or "TXT") .. ' file not found for atlas: ' .. key)
		if callback then callback(nil) end
		return nil
	end

	local function processAtlas(img)
		if not img then
			if callback then callback(nil) end
			return nil
		end

		local data = love.filesystem.read(dataPath)
		if not data then
			log('failed to read ' .. (kind == "sparrow" and "XML" or "TXT") .. ' file: ' .. dataPath)
			if callback then callback(nil) end
			return nil
		end

		local FrameCollection = loxreq "animation.frame.collection"
		obj = FrameCollection["from" .. kind:capitalize()](img, data)
		targetLib.atlases[cacheKey] = obj
		if callback then callback(obj) end
		return obj
	end

	local img = targetLib.images[imgPath]
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

function async.getAnimateAtlas(key, callback)
	local path = paths.getPath("images/" .. key)
	local obj = targetLib.animate_atlases[path]

	if obj then
		if callback then callback(obj) end
		return obj
	end

	if paths.exists(path, "directory") then
		local atlas = AnimateLibrary(path)
		atlas:loadAsync(function(loadedAtlas)
			targetLib.animate_atlases[path] = loadedAtlas
			if callback then callback(loadedAtlas) end
		end)
		return true
	else
		log('animate atlas not found: ' .. key)
		if callback then callback(nil) end
		return nil
	end
end

function async.loadBatch(files)
	for _, file in ipairs(files) do
		local type, path, suffix = unpack(file)
		local loader = loaders[type]
		if loader then
			loader(path, suffix)
		else
			Logger.log("warn", "Asynchronous batch loading doesn't handles \"" .. type .. "\"")
		end
	end
end

function async.getProgress()
	return stats.queued == 0 and 1 or math.min(1, stats.completed / stats.queued)
end

function async.crashstop()
	for i = 1, #threads do
		tasks:push("exit")
	end

	for i = 1, #threads do
		if threads[i]:isRunning() then
			threads[i]:wait()
		end
	end

	threads = nil
	thread_times = nil
end

function async._setTarget(lib)
	targetLib = lib
end

return async
