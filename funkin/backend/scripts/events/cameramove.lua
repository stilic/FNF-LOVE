local CameraMoveEvent = Events.Cancellable:extend("CameraMoveEvent")

function CameraMoveEvent:new(target)
	CameraMoveEvent.super.new(self)

	self.offset = Point()
	self.target = target
end

function CameraMoveEvent:recycle(target)
	CameraMoveEvent.super.recycle(self)

	self.offset:zero()
	self.target = target

	return self
end

return CameraMoveEvent
