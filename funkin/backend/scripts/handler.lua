local ScriptsHandler = Classic:extend("ScriptsHandler")

function ScriptsHandler:new(link)
	self.scripts = {}
	self.variables = {}

	self._entries = {}
	self._counter = 0
end

function ScriptsHandler:rebuild()
	table.sort(self._entries, function(a, b)
		if a.priority == b.priority then
			return a.id < b.id
		end
		return a.priority < b.priority
	end)

	self.scripts = {}
	for i, entry in ipairs(self._entries) do
		self.scripts[i] = entry.script
	end
end

function ScriptsHandler:loadScript(file, priority)
	self:add(Script(file), priority)
end

function ScriptsHandler:add(script, priority)
	priority = type(priority) == "number" and priority or math.huge

	for k, v in pairs(self.variables) do
		script:set(k, v)
	end

	self._counter = self._counter + 1
	table.insert(self._entries, {
		script = script,
		priority = priority,
		id = self._counter
	})

	self:rebuild()
end

function ScriptsHandler:remove(script)
	for i, entry in ipairs(self._entries) do
		if entry.script == script then
			table.remove(self._entries, i)
			break
		end
	end
	self:rebuild()
end

function ScriptsHandler:loadDirectory(...)
	local args = {...}
	local priority = math.huge

	if type(args[#args]) == "number" then
		priority = table.remove(args, #args)
	end

	for _, dir in ipairs(args) do
		for _, file in ipairs(paths.getItems(dir, "file", "lua")) do
			self:loadScript(dir .. "/" .. file:withoutExt(), priority)
		end
	end
end

function ScriptsHandler:call(func, ...)
	local retValue = Script.Event_Continue
	if not self.scripts then return end
	for _, script in ipairs(self.scripts) do
		local retScript = script:call(func, ...)
		if retScript == Script.Event_Cancel then
			retValue = Script.Event_Cancel
		end
	end
	return retValue
end

function ScriptsHandler:event(func, event)
	if not self.scripts then return end
	for _, script in ipairs(self.scripts) do
		script:call(func, event)
		if event.cancelled and not event.__continueCalls then break end
	end
	return event
end

function ScriptsHandler:set(variable, value)
	if not self.scripts then return end
	self.variables[variable] = value
	for _, script in ipairs(self.scripts) do
		script:set(variable, value)
	end
end

function ScriptsHandler:close()
	if not self.scripts then return end
	for _, script in ipairs(self.scripts) do
		script:close()
	end
	self.scripts = nil
	self.variables = nil
	self._entries = nil
end

return ScriptsHandler
