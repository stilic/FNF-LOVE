---@class Script:Classic
local Script = Classic:extend("Script")

local closedEnv = setmetatable({}, {
	__index = function() error("closed") end,
	__newindex = function() error("closed") end,
})

local function errformat(s, thread)
	local i = debug.getinfo(thread or 3, "Sln")
	Logger.log("warn", ("%i: %s not allowed"):format(i.short_src, i.currentline, s), 4)
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

	if name == "Script" then
		mt.__call = function(_, ...) return Script(...) end
	end
	return setmetatable({}, mt)
end

-- script sandboxing
-- avoids executing malicious code
-- http://lua-users.org/wiki/SandBoxes
-- this looks unclean i know -kaoy

local blocklist, modules = {
	"loxreq", "dofile", "loadfile", "loadstring", "load", "module",
	"rawset", "rawget", "rawequal", "setfenv", "getfenv", "newproxy",
	"_G", "_VERSION", "collectgarbage", "gcinfo", "coroutine"
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
		local scr = Script("data/classes/" .. path .. "/init", nil, nil, nil, true)
		return scr.chunk()
	end

	local scr = Script("data/classes/" .. path, nil, nil, nil, true)
	return scr.chunk()
end

modules.getmetatable = function(t)
	if type(t) == "string" then return nil end

	local mt = getmetatable(t)
	if mt and type(mt) == "table" and mt.__metatable then
		return mt.__metatable
	end
	return mt
end

modules.setmetatable = function(t, mt)
	if type(t) ~= "table" then
		error("Cannot set metatable of non-table types")
	end
	return setmetatable(t, mt)
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

function Script:new(path, notFoundMsg, noLink, fullPath, isLibrary)
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

			if not isLibrary then
				self.receiveFunc = function(...)
					self:call("receive", ...)
					self.__failedfunc["receive"] = nil
				end
				Script.messages:add(self.receiveFunc)
			end

			setfenv(chunk, setmetatable(vars, mtenv))
			if not noLink then
				self:linkObject(game.getState())
			end
			chunk()
		else
			if not self.notFoundMsg then return end
			Logger.log("error", "Script not found for " .. paths.getPath(p))
			self:close()
			return
		end

		self.chunk = chunk
	end)

	if not s then
		Logger.log("error", string.format('Failed to load %s: %s', path, err))
		self.errorCallback:dispatch("chunk")
		self:close()
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
			Logger.log("error", string.format('%s failed at %s: %s', self.path, func, err))
			self.__failedfunc[func] = true
			self.errorCallback:dispatch(func)
		end
	end
	return
end

function Script:close()
	if self.closed then return end
	self:call("onClose")

	if self.chunk then setfenv(self.chunk, closedEnv) end

	self.closed = true

	if self.closeCallback then
		self.closeCallback:dispatch()
		self.closeCallback:destroy()
	end
	if self.errorCallback then
		self.errorCallback:destroy()
	end

	if self.receiveFunc then
		Script.messages:remove(self.receiveFunc)
		self.receiveFunc = nil
	end

	if self.variables then
		setmetatable(self.variables, nil)
		table.clear(self.variables)
	end

	self.variables = nil
	self.chunk = nil
	self.errorCallback = nil
	self.closeCallback = nil
	self.__failedfunc = nil
	self.path = nil
	self.notFoundMsg = nil
end

if jit and jit.off then
	jit.off(Script.new)
	jit.off(Script.call)
	jit.off(Script.linkObject)
	jit.off(Script.close)
end

return Script
