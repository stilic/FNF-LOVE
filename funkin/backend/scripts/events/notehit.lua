local NoteHitEvent = Events.Cancellable:extend("NoteHitEvent")

function NoteHitEvent:new(notefield, note, character, rating)
	NoteHitEvent.super.new(self)

	self.cancelledAnim = false
	self.strumGlowCancelled = false
	self.coverSpawnCancelled = false
	self.unmuteVocals = true

	self.notefield = notefield
	self.note = note
	self.character = character
	self.rating = rating
end

function NoteHitEvent:recycle(notefield, note, character, rating)
	NoteHitEvent.super.recycle(self)

	self.cancelledAnim = false
	self.strumGlowCancelled = false
	self.coverSpawnCancelled = false
	self.unmuteVocals = true

	self.notefield = notefield
	self.note = note
	self.character = character
	self.rating = rating

	return self
end

function NoteHitEvent:cancelAnim()
	self.cancelledAnim = true
end

function NoteHitEvent:cancelStrumGlow()
	self.strumGlowCancelled = true
end

function NoteHitEvent:cancelCoverSpawn()
	self.coverSpawnCancelled = true
end

function NoteHitEvent:cancelUnmuteVocals()
	self.unmuteVocals = false
end

return NoteHitEvent
