-- Discord IPC lua -- A discord rich presence library for IPC
-- This library is based off of https://github.com/vionya/discord-rich-presence

-- assert jit and ffi. This library requires them both
local ffi, jit, e
e, ffi = pcall(require, "ffi")
if not e then
	error("Failed to load FFI library")
end
e, jit = pcall(require, "jit")
if not e then
	error("Failed to load JIT library")
end

local AF_UNIX = 1
local SOCK_STREAM = 1

ffi.cdef [[
typedef unsigned int size_t;
typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;
typedef int ssize_t;

struct sockaddr {
	sa_family_t sa_family;
	char sa_data[14];
};

struct sockaddr_un {
	sa_family_t sun_family;
	char sun_path[104];
};

int socket(int domain, int type, int protocol);
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
int close(int fd);
]]

-- HELPER FUNCTIONS
local curRanSeed = os.time()
local function random(min, max)
	max = max or (2^32)
	min = min or 0
	curRanSeed = (1103515245 * curRanSeed + 12345) % (2^32)
	return min + curRanSeed % (max - min)
end

local function getUUID()
	curRanSeed = os.time()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	local result = string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 15) or random(8, 11)
		return string.format("%x", v)
	end)

	return result
end

local function stringify(data)
	local result = {}

	for k, v in pairs(data) do
		local formatted = type(v) == "table" and stringify(v) or tostring(v)

		if type(v) == "string" then
			formatted = '"'..formatted..'"'
		end

		if type(k) == "number" then
			table.insert(result, formatted)
		else
			table.insert(result, string.format("\"%s\":%s", k, formatted))
		end
	end

	if #data > 0 then
		return "["..table.concat(result, ",").."]"
	else
		return "{"..table.concat(result, ",").."}"
	end
end

local function getPID()
	if jit.os == "Windows" then
		ffi.cdef[[
			unsigned long GetCurrentProcessId(void);
		]]

		return ffi.C.GetCurrentProcessId()
	else
		ffi.cdef[[
			int getpid(void);
		]]

		return ffi.C.getpid()
	end
end

local function intToBytes(n)
	local result = {}
	local hex = string.format("%08x", n)
	table.insert(result, tonumber(hex:sub(7, 8), 16))
	table.insert(result, tonumber(hex:sub(5, 6), 16))
	table.insert(result, tonumber(hex:sub(3, 4), 16))
	table.insert(result, tonumber(hex:sub(1, 2), 16))

	return result
end

local function strToBytes(str)
	local result = {}

	for i = 1, #str do
		table.insert(result, str:byte(i))
	end

	return result
end

local function bytesToInt(bytes)
	local result = 0

	for i, v in ipairs(bytes) do
		result = result + v * (0x100 ^ (i - 1))
	end

	return math.floor(result)
end

local function bytesToStr(bytes)
	local result = ""

	for _, v in ipairs(bytes) do
		local byte = v < 0 and (0xFF + v + 1) or v
		result = result..string.char(byte)
	end

	return result
end

local function pack(opcode, length)
	return bytesToStr(intToBytes(opcode)) .. bytesToStr(intToBytes(length))
end

local function _unpack(str)
	return bytesToInt(strToBytes(str:sub(1, 4))), bytesToInt(strToBytes(str:sub(5, 8)))
end

---@class discordIPC
---@field id string The ID of the Discord IPC
---@field OPCODES table<string, number> The opcodes for the Discord IPC -- Meant for internal use
---@field PIPE_ENVS table<string> The environment variables for the Discord IPC -- Meant for internal use
---@field PIPE_PATHS table<string> The paths for the Discord IPC -- Meant for internal use
---@field activity table<string, any> The current activity for the Discord IPC
---@field connected boolean Whether the Discord IPC is connected or not
local discordIPC = {
	id = "",
	OPCODES = {
		HANDSHAKE = 0,
		FRAME = 1,
		CLOSE = 2,
		PING = 3,
		PONG = 4
	},
	PIPE_ENVS = {
		"XDG_RUNTIME_DIR",
		"TMPDIR",
		"TMP",
		"TEMP"
	},
	PIPE_PATHS = {
		"",
		"app/com.discordapp.Discord/",
		"snap.discord-canary/",
		"snap.discord/"
	},
	activity = {},
	connected = false
}

---@param id string
---@return nil
--- Initializes the Discord IPC with the given ID
function discordIPC:initID(id)
	self.id = id
end

---@return boolean connected Whether the IPC is connected or not
--- Connects to the Discord IPC,
function discordIPC:connect()
	if not self.id then error("Attempted to connect to Discord IPC without an ID") end

	-- windows machines and unix machines have different ways of connecting to the IPC
	if jit.os == "Windows" then
		for i = 0, 9 do
			local file = io.open("\\\\.\\pipe\\discord-ipc-"..i, "r+")

			if file then
				print("Connected to DiscordIPC Pipe #"..i)
				self.socket = file
				self.connected = true
				break
			end
		end
	else
		local socket = ffi.C.socket(AF_UNIX, SOCK_STREAM, 0)

		if socket < 0 then
			print("Failed to create Discord IPC socket")
			return false
		end

		local env = nil
		for _, v in ipairs(self.PIPE_ENVS) do
			env = os.getenv(v)
			if env then
				if env:sub(-1) == "/" then
					env = env:sub(1, -2)
				end

				break
			end
		end

		if not env then
			env = "/tmp"
		end

		for i = 0, 9 do
			for _, v in ipairs(self.PIPE_PATHS) do
				local path = env.."/"..v.."discord-ipc-"..i
				local address = ffi.new("struct sockaddr_un")
				address.sun_family = AF_UNIX
				ffi.copy(address.sun_path, path)
				local addrlen = ffi.offsetof("struct sockaddr_un", "sun_path") + #path + 1
				local connected = ffi.C.connect(socket, ffi.cast("struct sockaddr*", address), addrlen)

				if connected == 0 then
					print("Connected to DiscordIPC Pipe #"..i)
					self.socket = socket
					self.connected = true
					break
				end
			end
			if self.connected then break end
		end

		if not self.connected then
			ffi.C.close(socket)
		end
	end

	if self.socket then
		self.connected = true
		local result = self:__sendHandshake()
		print("Successfully connected to Discord IPC")

		return result == self.OPCODES.FRAME
	end

	return false
end

---@return nil
--- Reconnects to the Discord IPC
function discordIPC:reconnect()
	self:close()
	self:connect()
end

---@return nil
--- Closes the connection to the Discord IPC
function discordIPC:close()
	if not self.socket then return end

	if self.connected then
		pcall(function()
			self:clearActivity()
		end)
	end
	local sock = self.socket
	self.socket = nil
	self.connected = false

	pcall(function()
		local close_msg = pack(self.OPCODES.CLOSE, 2) .. "{}"
		if jit.os == "Windows" then
			sock:seek("end")
			sock:write(close_msg)
			sock:flush()
		else
			ffi.C.send(sock, ffi.cast("const char*", close_msg), #close_msg, 0)
		end
	end)

	if jit.os == "Windows" then
		pcall(function() sock:close() end)
	else
		pcall(ffi.C.close, sock)
	end

	print("Successfully disconnected Discord IPC")
end

---@param msg string
---@internal
--- Writes a message to the Discord IPC
---
--- this is an internal function and should not be used outside of this library
function discordIPC:__write(msg)
	if not self.socket then return end

	if jit.os == "Windows" then
		self.socket:seek("end")
		local success, err = self.socket:write(msg)
		self.socket:flush()

		if not success then
			-- print("Failed to write to Discord IPC with error "..tostring(err))
			self:close()
		end
	else
		local sent = ffi.C.send(self.socket, ffi.cast("const char*", msg), #msg, 0)

		if sent < 0 then
			print("Failed to write to Discord IPC")
			self:close()
		end
	end
end

---@param data string
---@param opcode number
---@return number opcode, string data
---@internal
--- Sends a message to the Discord IPC
---
--- this is an internal function and should not be used outside of this library
function discordIPC:__send(data, opcode)
	if not self.connected then return end
	self:__write(pack(opcode, #data) .. data)
	if not self.connected then return end

	local opcode, data = self:__receive()
	---@diagnostic disable-next-line: return-type-mismatch
	return opcode, data
end

---@return number opcode, string data
---@internal
--- Sends a handshake message to the Discord IPC allowing us to connect
---
--- this is an internal function and should not be used outside of this library
function discordIPC:__sendHandshake()
	return self:__send('{"v": 1, "client_id": "'..self.id..'"}', self.OPCODES.HANDSHAKE)
end

---@return number opcode
--- Sends a message to the Discord IPC with the current activity
function discordIPC:sendActivity()
	if not self.connected then return end
	local data = {
		cmd = "SET_ACTIVITY",
		args = {
			pid = getPID() or 9999,
			activity = self.activity
		},
		nonce = getUUID()
	}

	local o = self:__send(stringify(data), self.OPCODES.FRAME)
	-- print("Sent activity to Discord IPC", stringify(data), o)

	return o
end

---@return nil
--- Clears the current activity on the Discord IPC
---@return nil
--- Clears the current activity on the Discord IPC
function discordIPC:clearActivity()
	if not self.connected then return end
	local pid = getPID() or 9999
	local nonce = getUUID()
	local payload = '{"cmd":"SET_ACTIVITY","args":{"pid":'..pid..'},"nonce":"'..nonce..'"}'

	self:__send(payload, self.OPCODES.FRAME)
end

---@return number opcode, string data
---@internal
--- Receives a message from the Discord IPC
---
--- this is an internal function and should not be used outside of this library
function discordIPC:__receive()
	if not self.connected then return nil, nil end
	local opcode, length, data = nil, nil, nil

	if jit.os == "Windows" then
		local header = self:__read(8)
		if not header or #header < 8 then
			self:close()
			return nil, nil
		end
		opcode, length = _unpack(header)
		data = self:__read(length)
	else
		local hbuffer = ffi.new("char[8]")
		local hbytes = ffi.C.recv(self.socket, hbuffer, 8, 0)

		if hbytes <= 0 then
			self:close()
			return nil, nil
		end

		opcode, length = _unpack(ffi.string(hbuffer, hbytes))

		local dbuffer = ffi.new("char[" .. length .. "]")
		local dbytes = ffi.C.recv(self.socket, dbuffer, length, 0)

		if dbytes <= 0 then
			self:close()
			return nil, nil
		end

		data = ffi.string(dbuffer, dbytes)
	end

	---@diagnostic disable-next-line: return-type-mismatch
	return opcode, data
end

---@param buf number
---@internal
--- Reads a message from the Discord IPC
---
--- this is an internal function and should not be used outside of this library
function discordIPC:__read(buf)
	if not self.socket then return end

	local data, err = self.socket:read(buf)
	if not data then
		self:close()
		return nil
	end
	return data
end

return discordIPC
