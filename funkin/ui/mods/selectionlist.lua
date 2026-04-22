local Modcard = require "funkin.ui.mods.modcard"
local SelectionList = SpriteGroup:extend("SelectionList")

function SelectionList:new(x, y, w, h)
	SelectionList.super.new(self, x, y)

	self.twidth = w
	self.theight = h

	self.curSelected = 1

	self.modsListBG = Graphic(0, 0, w, h)
	self.modsListBG.alpha = 0.5
	self.modsListBG.config.round = {16, 16}

	self.bar = Graphic(10, 0, 0, 0, Color.BLACK)
	self.bar.alpha = 0.4
	self.bar.config.round = {18, 18}
	self:add(self.bar)

	self.list = SpriteGroup(0, 0)
	self:add(self.list)
end

function SelectionList:isOnScreen() return true end

function SelectionList:insertContent(content, type)
	if #content == 0 then return end
	for _, m in ipairs(self.list.members) do
		m:kill()
	end
	for i, c in ipairs(content) do
		local spr = self.list:recycle(Modcard)
		spr:reload(10, c, type)
		spr.y = (spr.height + 10) * (i - 1) + 10
	end
	self.bar.height = self.list.members[1].height
	self.bar.width = self.twidth - 20
	self:changeSelection()
end

function SelectionList:query(name)
	local results = {}
	for _, member in ipairs(self.list.members) do
		if member.name and member.name:lower():find(name:lower(), 1, true) then
			table.insert(results, member)
		end
	end

	return results
end

function SelectionList:update(dt)
	SelectionList.super.update(self, dt)

	if #self.list.members < 1 then return end

	local factor, size = 4.06, self.list.members[1].height + 10
	local maxidx = math.max(1, #self.list.members - (factor - 1))
	local targ = math.min(self.curSelected - factor, maxidx - factor)
	local off = math.max(0, targ * size)

	for i, m in ipairs(self.list.members) do
		m.selected = i == self.curSelected
		local x = m.selected and 15 or (-m.width / 1.7) / (self.curSelected - i)
		m.x = util.coolLerp(m.x, x, 9.6, dt)

		local k = m.selected and 0 or 0.44
		m.skew.x = util.coolLerp(m.skew.x, k, 12, dt)

		local y = (size * (i - 1) + 10) - off
		m.y = util.coolLerp(m.y, y, 16, dt)
	end

	self.bar.y = util.coolLerp(self.bar.y, self:getSelected().y, 16, dt)
end

function SelectionList:changeSelection(n)
	if #self.list.members < 1 then return end
	if n == nil then n = 0 end
	self.curSelected = (self.curSelected - 1 + n) % #self.list.members + 1
end

function SelectionList:moveMember(i, idx)
	if #self.list.members < 1 then return end
	if not i or i == 0 or #self.list.members < 2 then return end

	idx = idx or self.curSelected
	local targ = ((idx - 1 + i) % #self.list.members) + 1

	if idx ~= targ then
		table.shift(self.list.members, idx, targ)
		self.curSelected = (self.curSelected == idx) and targ or idx
		self:changeSelection(0)
	end
end

function SelectionList:getSelected(getMod)
	if #self.list.members < 1 then return end
	if getMod then
		return self.list.members[self.curSelected].mod
	end
	return self.list.members[self.curSelected]
end

function SelectionList:__render(c)
	love.graphics.push("all")
	love.graphics.translate(self.x, self.y)
	self.modsListBG.alpha = 0.5 * self.alpha
	self.modsListBG:__render(c)
	love.graphics.pop()

	local x, y, w, h = self.x + 10, self.y + 10, self.twidth - 20, self.theight - 20
	x, y = x - self.offset.x, y - self.offset.y
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", x, y, w, h, 8, 8)
	end, "replace", 20)

	love.graphics.setStencilTest("equal", 20)
	SelectionList.super.__render(self, c)
	love.graphics.setStencilTest()
end

return SelectionList
