Ease = loxreq "util.tween.ease"
local Instance = loxreq "util.tween.instance"
local Motion = loxreq "util.tween.motion"

local Tween = {}
Tween.__index = Tween

function Tween:tween(object, props, duration, options)
	local tween = Instance()
	tween.manager = self
	tween.persist = options and (options.persist == true) or false
	tween:tween(object, props, duration, options)

	table.insert(self.instances, tween)
	return tween
end

function Tween:color(object, property, targetColor, duration, options)
	local tween = Instance()
	tween.manager = self
	tween.persist = options and (options.persist == true) or false

	tween.object = object
	tween.property = property

	local sr, sg, sb, sa = Color.get(object[property])
	local tr, tg, tb, ta = Color.get(targetColor)

	local proxy = {r = sr, g = sg, b = sb, a = sa}
	local target = {r = tr, g = tg, b = tb, a = ta}

	local userUpdate = options and options.onUpdate
	options = options or {}
	options.onUpdate = function(t)
		object[property] = Color.fromRGB(proxy.r * 255, proxy.g * 255, proxy.b * 255, proxy.a)
		if userUpdate then userUpdate(t) end
	end

	tween:tween(proxy, target, duration, options)
	table.insert(self.instances, tween)
	tween.object = object
	return tween
end

function Tween:quadPath(object, points, speed, isDuration, options)
	local tween = Motion.QuadPath(object, options, points, speed)
	tween.object = object
	tween:setMotion(speed, isDuration)
	table.insert(self.instances, tween)
	return tween
end

function Tween:remove(instance)
	table.delete(self.instances, instance)
end

function Tween:update(dt)
	if dt == 0 then return end

	for i = #self.instances, 1, -1 do
		local tween = self.instances[i]
		tween:update(dt * self.timeScale)
	end
end

function Tween:cancelTweensOf(object)
	for i = #self.instances, 1, -1 do
		local tween = self.instances[i]

		if tween.object == object then
			tween:destroy()
		end
	end
end

function Tween:clear()
	for i = #self.instances, 1, -1 do
		local tween = self.instances[i]
		if tween and tween.destroy and not tween.persist then tween:destroy() end
	end
end

-- wrapper
function Tween.new() return setmetatable({instances = {}, timeScale = 1}, Tween) end
local def, module = Tween.new(), {}
for k in pairs(Tween) do
	if k ~= "__index" then
		module[k] = function(...) return def[k](def, ...) end
	end
end

return setmetatable(module, {__call = Tween.new})
