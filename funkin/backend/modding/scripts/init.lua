---@class Script:Classic
local Script = Classic:extend("Script")

local closedEnv = setmetatable({}, {
	__index = function() error("closed") end,
	__newindex = function() error("closed") end,
})

-- script sandboxing
-- avoid game crashing / executing malicious code
-- http://lua-users.org/wiki/SandBoxes
-- this looks unclean i know -kaoy
local function errformat(s, thread)
	local i = debug.getinfo(thread or 3, "Sln")
	Toast.error(("%s: %i: %s not allowed"):format(i.short_src, i.currentline, s))
end

local n = function() end
local nindex = setmetatable({}, {__call = n, __index = n, __newindex = n})

local function deny(name, toReturn)
	return function()
		errformat(name); return toReturn or nindex
	end
end
local function noindex(module)
	return setmetatable({}, {
		__index = function(_, k) return deny(module .. "." .. k) end,
	})
end
local function limitindex(name, blocklist)
	local mt = {
		__index = function(_, k)
			if _G[name][k] then
				if blocklist and blocklist[k] then
					return blocklist[k]
				end
			end
			return _G[name][k]
		end,
		__newindex = deny(name .. " new indexing")
	}

	-- uhh workaround
	if name == "Script" then
		mt.__call = function(_, ...) return Script(...) end
	end
	return setmetatable({}, mt)
end

local blocklist, modules = {
	"loxreq", "dofile", "loadfile", "loadstring", "load", "module",
	"rawset", "rawget", "rawequal", "setfenv", "getfenv", "newproxy"
}, {
	debug = noindex("debug"),
	package = noindex("package"),
	io = noindex("io"),
	jit = noindex("jit"),
	ffi = noindex("ffi"),

	math = limitindex("math"),
	table = limitindex("table"),
	coroutine = limitindex("coroutine"),
	love = limitindex("love"),

	os = limitindex("os", {
		execute = deny("os.execute", false),
		remove = deny("os.remove", false),
		rename = deny("os.rename", false),
		tmpname = deny("os.tmpname", false),
		setenv = deny("os.setenv", false),
		getenv = deny("os.getenv", false),
		setlocale = deny("os.setlocale", false)
	}),
	string = limitindex("string", {
		dump = deny("string.dump", "")
	}),

	Script = limitindex("Script", {
		addToEnv = deny("Script addToEnv")
	})
}

modules.require = function(path)
	path = path:gsub("%.", "/")
	if paths.exists(paths.getPath(path), "directory") and
		paths.exists(paths.getPath(path .. "/init.lua"), "file") then
		return Script("data/classes/" .. path .. "/init").chunk()
	end
	return Script("data/classes/" .. path).chunk()
end

local mtenv = {
	__index = function(_, k)
		if table.find(blocklist, k) then
			return deny(k)
		end
		return modules[k] or _G[k]
	end
}

function Script.addToEnv(k, v) modules[k] = modules[k] or v end

Script.messages = Signal()
Script.Event_Continue = 1
Script.Event_Cancel = 2

function Script:new(path, notFoundMsg, noLink, fullPath)
	self.path = path
	self.variables = {}
	self.notFoundMsg = (notFoundMsg == nil and true or false)
	self.closed = false
	self.chunk = nil
	self.__failedfunc = {}

	self.errorCallback = Signal()
	self.closeCallback = Signal()

	local s, err = pcall(function()
		local p, vars = path, self.variables

		local chunk = fullPath and love.filesystem.load(p) or paths.getLua(p)
		if chunk then
			if not p:endsWith("/") then p = p .. "/" end
			self:set("close", function() self:close() end)
			self:set("Event_Continue", Script.Event_Continue)
			self:set("Event_Cancel", Script.Event_Cancel)
			self:set("SCRIPT_PATH", p)
			self:set("state", game.getState())

			self:set("send", function(...)
				if self.closed then return end
				Script.messages:dispatch(self.path, ...)
			end)

			self.receiveFunc = function(...)
				self:call("receive", ...)
				self.__failedfunc["receive"] = nil
			end
			Script.messages:add(self.receiveFunc)

			setfenv(chunk, setmetatable(vars, mtenv))
			if not noLink then
				self:linkObject(game.getState())
			end
			chunk()
		else
			if not self.notFoundMsg then return end
			Toast.error("Script not found for " .. paths.getPath(p))
			self:close()
			return
		end

		self.chunk = chunk
	end)

	if not s then
		Toast.error(string.format('Failed to load %s: %s', path, err))
		self:close()
		self.errorCallback:dispatch("chunk")
	end
end

function Script:set(var, value)
	if self.closed then return end
	rawset(self.variables, var, value)
end

function Script:linkObject(link)
	local cur = getmetatable(self.variables)
	local s = self.variables
	if not s then return end
	local new = {
		__index = function(_, k)
			if link[k] ~= nil then
				if type(link[k]) == "function" then
					return function(...)
						return link[k](link, ...)
					end
				end
				return link[k]
			end
			return type(cur.__index) == "table" and
				cur.__index[k] or cur.__index(s, k)
		end,
		__newindex = function(_, k, v)
			-- avoid overriding functions
			-- was other method but it kinda fucked up callbacks
			if k ~= nil and link[k] ~= nil and type(link[k]) ~= "function" then
				link[k] = v; return
			end
			return cur.__newindex and
				cur.__newindex(s, k, v) or rawset(s, k, v)
		end
	}
	setmetatable(self.variables, new)
end

function Script:call(func, ...)
	if self.closed then return true end

	if self.__failedfunc[func] then return end

	local f = rawget(self.variables, func)
	if f and type(f) == "function" then
		local s, err = pcall(f, ...)
		if s then
			if err ~= nil and pcall(type, err) then
				return err
			end
			return true
		else
			Toast.error(string.format('%s failed at %s: %s', self.path, func, err))
			self.__failedfunc[func] = true
			self.errorCallback:dispatch(func)
		end
	end
	return
end

function Script:close()
	if self.variables then table.clear(self.variables) end
	if self.chunk then setfenv(self.chunk, closedEnv) end
	self.variables = nil
	self.chunk = nil
	self.__failedfunc = {}

	if not self.closed then
		self.closed = true
		self.closeCallback:dispatch()
		Script.messages:remove(self.receiveFunc)
	end
end

return Script
