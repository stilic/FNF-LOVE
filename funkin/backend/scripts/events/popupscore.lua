local PopUpScoreEvent = Events.Cancellable:extend("PopUpScoreEvent")

function PopUpScoreEvent:new()
	PopUpScoreEvent.super.new(self)

	self.hideRating = false
	self.hideScore = false
end

function PopUpScoreEvent:recycle()
	PopUpScoreEvent.super.recycle(self)

	self.hideRating = false
	self.hideScore = false

	return self
end

function PopUpScoreEvent:cancelRating()
	self.hideRating = true
end

function PopUpScoreEvent:cancelScore()
	self.hideScore = true
end

return PopUpScoreEvent
