local CameraMoveEvent = Events.Cancellable:extend("CameraMoveEvent")

function CameraMoveEvent:new(target)
	CameraMoveEvent.super.new(self)

	self.offset = {x = 0, y = 0}
	self.target = target
end

return CameraMoveEvent
