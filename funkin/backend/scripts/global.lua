local GlobalScripts = {scripts = {}}

-- wip

local function setIdentity(title, icon)
	if title then love.window.setTitle(title) end
	if icon then love.window.setIcon(love.image.newImageData(paths.getPath(icon))) end
end

local function setBackgroundColor(color)
	love.graphics.setBackgroundColor(color or Color.BLACK)
end
local function setTransitions(in, out)
end

local function setDiscordClientID(id)
end

function GlobalScripts.reload()
	local oldScripts = {}
	for _, scr in pairs(GlobalScripts.scripts) do
		oldScripts[scr.path] = scr
	end
	table.clear(GlobalScripts.scripts)

	local sameMod = Mods.currentMod == GlobalScripts.currentMod
	local addonsUnchanged = true
	local newScripts = {}

	for _, addon in ipairs(Addons.all) do
		local path = Addons.root .. "/" .. addon.path .. "/global.lua"
		local scriptLoaded = oldScripts[path] ~= nil

		if addon.active then
			if paths.exists(path, "file") then
				if not scriptLoaded then
					local script = Script(path, false, true, true)
					table.insert(GlobalScripts.scripts, script)
					table.insert(newScripts, script)
					addonsUnchanged = false
				else
					table.insert(GlobalScripts.scripts, oldScripts[path])
					oldScripts[path] = nil
				end
			end
		else
			if scriptLoaded then
				oldScripts[path]:close()
				addonsUnchanged = false
			end
		end
	end

	if Mods.currentMod then
		local path = Mods.root .. "/" .. Mods.currentMod .. "/global.lua"
		if paths.exists(path, "file") then
			if not sameMod or not oldScripts[path] then
				local script = Script(path, false, true, true)
				table.insert(GlobalScripts.scripts, script)
				table.insert(newScripts, script)
				addonsUnchanged = false
			else
				table.insert(GlobalScripts.scripts, oldScripts[path])
				oldScripts[path] = nil
			end
		end
	end

	for _, scr in pairs(oldScripts) do
		scr:close()
		addonsUnchanged = false
	end
	if sameMod and addonsUnchanged then return end

	GlobalScripts.set("setIdentity", setIdentity)

	GlobalScripts.currentMod = Mods.currentMod

	for _, script in ipairs(newScripts) do
		script:call("init")
	end
end

function GlobalScripts.call(func, ...)
	for _, s in pairs(GlobalScripts.scripts) do
		s:call(func, ...)
	end
end

function GlobalScripts.set(var, value)
	for _, s in pairs(GlobalScripts.scripts) do
		s:set(var, value)
	end
end

return GlobalScripts
