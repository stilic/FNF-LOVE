local Settings = require "funkin.ui.options.settings"

local function parse()
    local data = {}

    local json = loxreq "lib.json".decode(love.filesystem.read(paths.getMods("data/options.json")))
    for category, options in pairs(json) do
        table.insert(data, {category:upper()})
        for _, option in pairs(options) do
            local op = {option.data, option.name}
			if option.type == "function" then
				table.insert(op, function(optionsUI)
					local script = Script("data/options/" .. option.data)
					script:call("execute", optionsUI)
				end)
			else
				table.insert(op, option.type)
			end

            if option.type == "number" then
				table.insert(op, function(add)
					local value = math.clamp(ClientPrefs.mods[Mods.currentMod][option.data] + (add * (option.step or 1)), option.min or 0, option.max or 100)
					ClientPrefs.mods[Mods.currentMod][option.data] = value
				end)
				if option.format then
					table.insert(op, function(value) return option.format:gsub("(%%v)", value) end)
				end
            elseif option.type == "string" then
                table.insert(op, option.choices)
            end
            table.insert(data, op)
        end
    end

    return data
end

local Mod = Settings:base("Mod", parse())

-- replace functions just to go over the clientprefs mods table
function Mod:getOption(id)
    local option = self.settings[id]
	local bind = self.curBind
	if type(option[3]) == "table" then return option[bind][3] and option[bind][3]() or nil end
	return ClientPrefs.mods[Mods.currentMod][option[1]]
end

function Mod:cancel(id, oldValue)
	local bind = self.curBind
	local func = self.settings[id][4]
	local functype, ret = type(func)

	if ClientPrefs.mods[Mods.currentMod][self.settings[id][1]] ~= oldValue then
		if func and functype == "function" then func(0) end
		ClientPrefs.mods[Mods.currentMod][self.settings[id][1]] = oldValue
	end

	if self.tab then
		self.tab.items[id].texts[bind].content = self:getOptionString(id, bind)
	end
end

function Mod:changeOption(id, add, optionsUI)
	local option, value = self.settings[id], self:getOption(id)
	local bind = self.curBind
	local prev = value

	local optiontype, func = option[3], option[4]
	local functype, ret, dont = type(func)
	if optiontype == "boolean" then
		if functype == "function" then
			ret, dont = func(add, optionsUI)
			value = self:getOption(id)
		else
			value = not value
		end
	elseif optiontype == "string" then
		if functype == "function" then
			ret, dont = func(add, optionsUI)
			value = self:getOption(id)
		elseif functype == "table" then
			value = func[math.wrap(table.find(func, value) + add, 1, #func + 1)]
		else
			-- TODO: input
		end
	elseif optiontype == "number" then
		if functype == "function" then
			ret, dont = func(add, optionsUI)
			value = self:getOption(id)
		elseif functype == "table" then
			value = func[math.wrap(value + add, 1, #func + 1)]
		else
			value = value + add
		end
	elseif type(optiontype) == "table" or bind then
		if not bind then return false end
		ret, dont = option[3][bind][1](add, value, optionsUI)
		value = self:getOption(id, bind)
	end

	if functype ~= "function" then ClientPrefs.mods[Mods.currentMod][option[1]] = value end
	if self.tab then
		local selectedStr = self:getOptionString(id, bind)
		if self.selected then selectedStr = "< " .. selectedStr .. " >" end
		self.tab.items[id].texts[bind].content = selectedStr
	end
	if dont then optionsUI.dontPlaySound = true end
	if ret ~= nil then return ret end
	return value ~= prev
end

return Mod