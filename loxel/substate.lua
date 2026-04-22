---@class Substate:State
local Substate = State:extend("Substate")

function Substate:new()
	Substate.super.new(self)
	self.parent = nil
end

function Substate:belongsToParent()
	return self.parent and self.parent.substate == self
end

function Substate:openSubstate(substate)
	self.substate = substate
	substate.parent = self
	game.openSubstate(substate)
end

function Substate:closeSubstate()
	if self.substate then
		game.closeSubstate(self.substate)
		self.substate = nil
	end
end

function Substate:update(dt)
    if self:belongsToParent() and self.parent.persistentUpdate then
        self.parent:update(dt)
    end
    Substate.super.update(self, dt)
end

function Substate:draw()
    Substate.super.draw(self)
end

function Substate:close()
	if self:belongsToParent() then self.parent:closeSubstate() end
end

return Substate
