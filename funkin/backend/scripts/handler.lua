local ScriptsHandler = Classic:extend("ScriptsHandler")

function ScriptsHandler:new(link)
	self.scripts = {}
	self.variables = {}
end

function ScriptsHandler:loadScript(file) self:add(Script(file)) end

function ScriptsHandler:add(script)
	for k, v in pairs(self.variables) do
		script:set(k, v)
	end
	table.insert(self.scripts, script)
end

function ScriptsHandler:remove(script) table.delete(self.scripts, script) end

function ScriptsHandler:loadDirectory(...)
	for _, dir in ipairs({...}) do
		for _, file in ipairs(paths.getItems(dir, "file", "lua")) do
			self:loadScript(dir .. "/" .. file:withoutExt())
		end
	end
end

function ScriptsHandler:call(func, ...)
	local retValue = Script.Event_Continue
	for _, script in ipairs(self.scripts) do
		local retScript = script:call(func, ...)
		if retScript == Script.Event_Cancel then
			retValue = Script.Event_Cancel
		end
	end
	return retValue
end

function ScriptsHandler:event(func, event)
	for _, script in ipairs(self.scripts) do
		script:call(func, event)
		if event.cancelled and not event.__continueCalls then break end
	end
	return event
end

function ScriptsHandler:set(variable, value)
	self.variables[variable] = value
	for _, script in ipairs(self.scripts) do
		script:set(variable, value)
	end
end

function ScriptsHandler:close()
	for _, script in ipairs(self.scripts) do
		script:close()
	end
	self.scripts = nil
	self.variables = nil
end

return ScriptsHandler
