local Discord = {}

Discord.isInitialized = false
Discord.clientID = "1098761843956273304"

Discord.options = {
	details = "Starting",
	state = nil,
	assets = {
		large_image = "icon",
		large_text = "FNF LÖVE"
	},
	buttons = {
		{
			label = "Join Discord Server",
			url = "https://discord.com/invite/eFFgHz7X8N"
		},
		{
			label = "View Repository",
			url = "https://github.com/Stilic/FNF-LOVE"
		}
	}
}

local tc, ec = love.thread.getChannel("discord_req"), love.thread.getChannel("discord_ev")
local ready, thread, pendingActivity = false

local uploadThreadCode = [[
	local thread, https = require("love.thread"), require("lib.https")
	local req, res = thread.getChannel("discord_upload_req"), thread.getChannel("discord_upload_res")
	-- intended to use 0x0.st, but its failing the handshake i think?? it didnt work at all
	local api = "https://litterbox.catbox.moe/resources/internals/api.php"

	while true do
		local msg = req:demand()
		if msg[1] == "quit" then break end
		local reqId, path = msg[1], msg[2]
		local file = love.filesystem.newFile(path)

		if not file:open("r") then
			res:push({reqId, nil, "failed to open file: " .. tostring(path)})
		else
			local fileData = file:read("string")
			file:close()
			local body, type = https.buildFormData(
				{ reqtype = "fileupload", time = "1h" },
				{ fileToUpload = { filename = "rpcimage.png", contentType = "image/png", data = fileData } }
			)
			local code, response = https.post(api, body, { ["Content-Type"] = type })
			if code == 200 then
				local query = https.buildQuery({ url = response, w = 256, h = 256 })
				res:push({reqId, "https://wsrv.nl/" .. query, nil, path})
			else
				res:push({reqId, nil, "HTTP Error: " .. tostring(code), path})
			end
		end
	end
]]

local threadCode = [[
	local timer, system, thread = require "love.timer", require "love.system", love.thread
	local ipc = require "lib.discordipc"

	local cin, cout = thread.getChannel("discord_req"), thread.getChannel("discord_ev")
	local connected, next, dirty = false, nil, false

	while true do
		local msg = cin:pop()
		while msg do
			local op = msg[1]
			if op == "start" then
				if connected then ipc:close() end
				ipc:initID(msg[2])
				connected = ipc:connect()
				cout:push(connected and {"ready"} or {"error"})
			elseif op == "activity" then
				next, dirty = msg[2], true
			elseif op == "quit" then
				if connected then ipc:close() end
				return
			end
			msg = cin:pop()
		end

		if connected and dirty then
			ipc.activity = next
			ipc:sendActivity()
			dirty = false

			if not ipc.connected then
				connected = false; cout:push({"disconnected"})
			end
		end

		love.timer.sleep(0.5)
	end
]]

local uploadThread
local uploadReqChannel = love.thread.getChannel("discord_upload_req")
local uploadResChannel = love.thread.getChannel("discord_upload_res")

Discord.uploadCallbacks = {}
Discord.uploadCounter = 0
Discord.uploadCache = {}

function Discord.init()
	if thread then return end

	thread = love.thread.newThread(threadCode)
	thread:start()
	uploadThread = love.thread.newThread(uploadThreadCode)
	uploadThread:start()

	tc:push({"start", Discord.clientID})

	Discord.isInitialized = true
	Discord.changePresence(Discord.options)
end

function Discord.restart()
	if not thread then
		Discord.init()
		return
	end
	ready = false
	tc:push({"start", Discord.clientID})
end

function Discord.changePresence(options)
	if not Discord.isInitialized then return end

	local newOptions = table.clone(Discord.options)
	table.merge(newOptions, options)
	newOptions.assets.large_image = newOptions.assets.large_image or "icon"
	newOptions.assets.large_text = newOptions.assets.large_text or "FNF LÖVE"

	pendingActivity = newOptions
end

function Discord.heartbeat()
	if not ready then return end

	if pendingActivity then
		tc:push({"activity", pendingActivity})
		pendingActivity = nil
	end
end

function Discord.update()
	local msg = ec:pop()
	while msg do
		local type = msg[1]
		if type == "ready" then
			ready = true
			pendingActivity = Discord.options
			Discord.heartbeat()
		elseif type == "disconnected" or type == "error" then
			ready = false
		end
		msg = ec:pop()
	end
	local upMsg = uploadResChannel:pop()
	while upMsg do
		local reqId, url, err = upMsg[1], upMsg[2], upMsg[3]
		local callback = Discord.uploadCallbacks[reqId]

		if callback then
			callback(url, err)
			Discord.uploadCallbacks[reqId] = nil
			Discord.uploadCache[upMsg[4]] = {url, err}
		end

		upMsg = uploadResChannel:pop()
	end
end

function Discord.shutdown()
	if thread then
		tc:push({"quit"})
		thread:wait()
		thread = nil
	end
	if uploadThread then
		uploadReqChannel:push({"quit"})
		uploadThread:wait()
		uploadThread = nil
	end
	ready = false
	Discord.isInitialized = false
end

function Discord.uploadImage(imagePath, callback)
	if Discord.uploadCache[imagePath] then
		return callback(unpack(Discord.uploadCache[imagePath]))
	end

	if not uploadThread then
		if callback then callback(nil, "Upload thread not initialized") end
		return
	end

	Discord.uploadCounter = Discord.uploadCounter + 1
	local reqId = Discord.uploadCounter
	Discord.uploadCallbacks[reqId] = callback

	uploadReqChannel:push({reqId, imagePath})
end

return Discord
