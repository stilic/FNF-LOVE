local MenuList = SpriteGroup:extend("MenuList")
MenuList.selectionCache = {}

local defaultScrolls = {
	default = function(self, obj, dt, time)
		obj.y = self:lerp(dt, obj, "y", time)
		obj.x = self:lerp(dt, obj, "x", time, obj.target * 26)
	end,
	centered = function(self, obj, dt, time)
		obj:screenCenter("x")
		obj.y = self:lerp(dt, obj, "y", time)
	end,
	vertical = function(self, obj, dt, time)
		obj.y = self:lerp(dt, obj, "y", time)
	end,
	horizontal = function(self, obj, dt, time)
		obj.x = self:lerp(dt, obj, "x", time)
	end,
	mobile = function(self, obj, dt, time)
		local spacing = (#self.members + 0) * obj.yMult
		obj.y = spacing * obj.ID - 1

		local baseX = 80 - (obj.ID * 3)
		local slideOffset = obj.target == 0 and 20 or 0
		local targetX = baseX + slideOffset

		obj.x = self:lerp(dt, obj, "x", time or self.speed, 0, targetX)
	end
}

local defaultHovers = {
	default = function(self, obj)
		obj.alpha = obj.target == 0 and 1 or 0.6
		if obj.child then obj.child.alpha = obj.alpha end
	end,
	anim = function(self, obj)
		for _, item in ipairs(self.members) do
			if item and item.animation:has("idle") and item.animation.name ~= "idle" then
				item.animation:play("idle")
			end
		end
		if obj and obj.animation:has("selected") and obj.animation.name ~= "selected" then
			obj.animation:play("selected")
		end
	end,
	mobile = function(self, obj)
		local alpha = obj.target == 0 and 1 or nil
		if alpha then
			obj.alpha = alpha
			if obj.child then obj.child.alpha = alpha end
		end
	end
}

function MenuList:new(sound, cache, scroll, hover)
	MenuList.super.new(self, 0, 0)
	self.width = game.width
	self.height = game.height

	self.sound = sound
	self.cache = cache
	self.scroll = scroll
	self.hover = hover

	self.childPos = "left"
	self.speed = 10

	self.lock = false
	self.curSelected = 1
	self.changeCallback = nil
	self.selectCallback = nil

	self.isMobile = (scroll == "mobile")

	if cache then
		self.__key = tostring(game.getState())
		if MenuList.selectionCache[self.__key] then
			self.curSelected = MenuList.selectionCache[self.__key]
		else
			MenuList.selectionCache[self.__key] = 1
		end
	end

	self.throttles = {}
	if self.scroll ~= "horizontal" and not self.isMobile then
		self.throttles[-1] = Throttle:make({controls.down, controls, "ui_up"})
		self.throttles[1] = Throttle:make({controls.down, controls, "ui_down"})
	elseif self.scroll == "horizontal" and not self.isMobile then
		self.throttles[-1] = Throttle:make({controls.down, controls, "ui_left"})
		self.throttles[1] = Throttle:make({controls.down, controls, "ui_right"})
	end
end

function MenuList:add(obj, child, unselectable)
	MenuList.super.add(self, obj)
	obj.unselectable = unselectable
	obj.ID = #self.members
	obj.target = 0

	obj.yAdd = obj.yAdd or self.height * .44
	obj.yMult = obj.yMult or (self.isMobile and 20 or 120)
	obj.xAdd = obj.xAdd or 60
	obj.xMult = obj.xMult or 1
	obj.spaceFactor = obj.spaceFactor or 1.25

	if child then
		child.xAdd = child.xAdd or 10
		child.yAdd = child.yAdd or -30
		obj.child = child
	end

	self:updatePositions(game.dt, 0)
end

function MenuList:lerp(dt, obj, d, time, targ, direct)
	targ = targ or obj.target
	time = time or self.speed

	if direct ~= nil then
		if time <= 0 then return direct end
		return util.coolLerp(obj[d], direct, time, dt)
	end

	local mult = d == "y" and obj.yMult or obj.xMult
	local add = d == "y" and obj.yAdd or obj.xAdd
	local factor = obj.spaceFactor

	local formula = (math.remapToRange(targ, 0, 1, 0, factor) * mult) + add
	if time <= 0 then return formula end
	return util.coolLerp(obj[d], formula, time, dt)
end

function MenuList:updatePositions(dt, time)
	local scrollFunc = type(self.scroll) == "function" and self.scroll or
		defaultScrolls[self.scroll or "default"]
	for i = 1, #self.members do
		local obj = self.members[i]
		if scrollFunc then scrollFunc(self, obj, dt, time) end
		if obj.child then
			obj.child:setPosition(self.childPos == "left" and obj.x + obj:getWidth() +
				obj.child.xAdd or obj.x - obj.child.width - obj.child.xAdd,
				obj.y + obj.child.yAdd)
			obj.child:update(dt)
		end
	end
end

function MenuList:handleTouch(dt)
	if not self.isMobile or self.lock then return end

	if game.touch.anyTouchJustReleased then
		local touch = game.touch.getTouch(0)
		if not touch then return end
		local tx, ty = touch.x, touch.y
		for i, obj in ipairs(self.members) do
			if not obj.unselectable and self:touchOverObj(tx, ty, obj) then
				if i == self.curSelected then
					if self.selectCallback then
						self.selectCallback(obj)
						self.lock = true
					end
				else
					self:setSelection(i)
				end
				return
			end
		end
	end
end

function MenuList:touchOverObj(tx, ty, obj)
	local objLeft = obj.x - (obj.origin and obj.origin.x * obj.width or 0)
	local objTop = obj.y - (obj.origin and obj.origin.y * obj.height or 0)
	local objRight = objLeft + obj.width
	local objBottom = objTop + obj.height

	return tx >= objLeft and tx <= objRight and ty >= objTop and ty <= objBottom
end

function MenuList:setSelection(index, blockSound)
	if index < 1 or index > #self.members then return end
	if self.members[index].unselectable then return end

	self.curSelected = index

	for i, member in ipairs(self.members) do
		member.target = i - self.curSelected
	end

	if self.cache then
		MenuList.selectionCache[self.__key] = self.curSelected
	end
	if self.changeCallback then
		self.changeCallback(self.curSelected, self.members[self.curSelected])
	end
	if #self.members > 1 and not blockSound and self.sound then
		util.playSfx(self.sound)
	end
end

function MenuList:update(dt)
	MenuList.super.update(self, dt)

	self:handleTouch(dt)

	if not self.isMobile then
		for i, throttle in pairs(self.throttles) do
			if throttle:check() and not self.lock and #self.members > 1 then
				self:changeSelection(i)
			end
		end
	end

	for i = 1, #self.members do
		local obj = self.members[i]
		local hoverFunc = type(self.hover) == "function" and self.hover or
			defaultHovers[self.hover or "default"]
		if obj.active and hoverFunc then hoverFunc(self, obj, dt) end
	end

	if not self.isMobile and not self.lock and controls:pressed("accept") and self.selectCallback
		and #self.members > 0 then
		self.lock = true
		self.selectCallback(self.members[self.curSelected])
	end

	self:updatePositions(dt)
end

function MenuList:changeSelection(c, blockSound)
	c = c or 0
	if #self.members == 0 then return end

	-- locking all objects (who would?) may result in a infinite loop here
	self.curSelected = (self.curSelected - 1 + c) % #self.members + 1
	while self.members[self.curSelected].unselectable do
		self.curSelected = self.curSelected + (c ~= 0 and c or 1)
		self.curSelected = (self.curSelected - 1) % #self.members + 1
	end

	for i, member in ipairs(self.members) do
		member.target = i - self.curSelected
	end
	if self.cache then
		MenuList.selectionCache[self.__key] = self.curSelected
	end
	if self.changeCallback then
		self.changeCallback(self.curSelected, self.members[self.curSelected])
	end
	if #self.members > 1 and not blockSound and self.sound then
		util.playSfx(self.sound)
	end
end

function MenuList:getSelected()
	return self.members[self.curSelected]
end

function MenuList:__render(c)
	love.graphics.stencil(function()
		local x, y, w, h = self.x, self.y, self.width, self.height
		x, y = x - self.offset.x - (c.scroll.x * self.scrollFactor.x),
			y - self.offset.y - (c.scroll.y * self.scrollFactor.y)

		love.graphics.rectangle("fill", x, y, w, h)
	end, "replace", 1)
	love.graphics.setStencilTest("greater", 0)

	MenuList.super.__render(self, c)

	for i = 1, #self.members do
		local obj = self.members[i]
		if obj.child and obj.child:isOnScreen(c) then
			obj.child:__render(c)
		end
	end

	love.graphics.setStencilTest()
end

function MenuList:getWidth() return self.width end
function MenuList:getHeight() return self.height end

return MenuList
