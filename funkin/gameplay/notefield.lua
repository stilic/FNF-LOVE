local Notefield = ActorGroup:extend("Notefield")
 
function Notefield:new(x, y, keys, skin, character, vocals, speed)
	if keys == nil then keys = 4 end
	if skin == nil then skin = "default" end
	if speed == nil then speed = 1 end
 
	Notefield.super.new(self, x, y)
 
 	self.__offsetX = 0
 	self.noteWidth = 160 * 0.7
	self.height = 514
	self.keys = keys
	self.skin = skin.data
 
	self.time, self.beat = 0, 0
	self.offsetTime = 0
	self.speed = speed
	self.drawSize = game.height * 2 + self.noteWidth
	self.drawSizeOffset = 0
	self.downscroll = false
	self.canSpawnSplash = true
 
	self.character, self.vocals = character, vocals
	self.bot = false
	self.lastSustain = nil
	self.recentPresses = {}
 
	self.modifiers = {}
 
	self.lanes = {}
	self.receptors = {}
 
	self.chartNotes = {}
	self.activeNotes = {}
	self.chartIndex = 1
	self.spawnBuffer = 2.0
	self.lastSpawnTime = -math.huge
 
	self.noNoteRender = false

	self.state = game.getState()
 
	self.__topSprites = Group()
	for i = 1, keys do self:makeLane(i) end
	self:add(self.__topSprites)
 
	self.groupScale = Point(1, 1)
	self.groupOrigin = Point(0, 0)
 
	self:setWidth()
	self.groupOrigin:set(0, self.noteWidth / 2)
end

function Notefield:hideNotes(bool)
	self.noNoteRender = bool
	if not bool and not table.find(self.members, self.__topSprites) then
		self:add(self.__topSprites)
	elseif bool and table.find(self.members, self.__topSprites) then
		self:remove(self.__topSprites)
	end

	local pos = bool and -self.noteWidth / 2 or -self.height / 2
	for _, lane in pairs(self.lanes) do lane.receptor.y = pos end
end

function Notefield:setWidth(width, nwidth)
	nwidth = nwidth or 160 * 0.7
	width = width or nwidth * self.keys
	self.width = width

	local half = math.floor(self.keys / 2)
	local lw, rw = nwidth * half, nwidth * (self.keys - half)
	local rx = width - rw

	for i = 1, self.keys do
		local sx, idx = i > half and rx or 0, i > half and i - half or i
		self.lanes[i].x = sx + nwidth * (idx - 1) + nwidth / 2
	end
end

function Notefield:makeLane(direction, y)
	local lane = ActorGroup(0, 0, 0, false)
	lane.receptor = Receptor(0, y or -self.height / 2, direction - 1, self.skin)
	lane.renderedNotes, lane.renderedNotesI = {}, {}
	lane.currentNoteI = 1
	lane.drawSize, lane.drawSizeOffset = 1, 0
	lane.speed = 1
 
	lane:add(lane.receptor)
	lane.receptor.lane = lane
	lane.receptor.parent = self
 
	self.receptors[direction] = lane.receptor
	self.lanes[direction] = lane
	self:add(lane)
	self.__topSprites:add(lane.receptor.covers)
	self.__topSprites:add(lane.receptor.splashes)
	return lane
end
 
function Notefield:makeNotesFromChart(notes)
	local gf = self.state.gf
	if gf and not gf:is(Character) then
		gf = nil
	end
 
	local chartNotes = {}
	for _, n in ipairs(notes) do
		if n.t >= PlayState.startPos then
			local sustainTime = n.l or 0
			if sustainTime ~= 0 then
				sustainTime = math.max(sustainTime / 1000, 0.125)
			end
 
			table.insert(chartNotes, {
				t = n.t,
				d = n.d,
				l = sustainTime * 1000,
				k = n.k,
				gf = n.gf,
				character = (gf and n.gf) and gf or nil
			})
		end
	end
 
	self.chartNotes = notes
	self.chartIndex = 1
	table.sort(self.chartNotes, function(a, b) return a.t < b.t end)
 
	for _, note in ipairs(self.activeNotes) do
		if note.group then
			local lane = note.group
			table.delete(lane.renderedNotes, note)
			lane.renderedNotesI[note] = nil
		end
		note:destroy()
	end
	self.activeNotes = {}
 
	for _, lane in ipairs(self.lanes) do
		table.clear(lane.renderedNotes)
		table.clear(lane.renderedNotesI)
	end
end
 
function Notefield:getNotes(time, direction, sustainLoop)
	local notes = self.activeNotes
	if #notes == 0 then return {} end
 
	local safeZoneOffset, hitNotes, i, started, hasSustain,
	forceHit, noteTime, hitTime, prev, prevIdx = Note.safeZoneOffset, {}, 1
	for _, note in ipairs(notes) do
		noteTime = note.time
		if not note.tooLate
			and not note.ignoreNote
			and (direction == nil or note.direction == direction)
			and (note.lastPress
				or (noteTime > time - safeZoneOffset * note.lateHitMult
					and noteTime < time + safeZoneOffset * note.earlyHitMult)) then
			forceHit = sustainLoop and not note.wasGoodSustainHit and note.sustain
			if forceHit then hasSustain = true end
			if not note.wasGoodHit or forceHit then
				prevIdx = i - 1
				prev = hitNotes[prevIdx]
				if prev and noteTime - prev.time <= 0.001 and note.sustainTime > prev.sustainTime then
					hitNotes[i] = prev
					hitNotes[prevIdx] = note
				else
					hitNotes[i] = note
				end
				i = i + 1
				started = true
			elseif started then
				break
			end
		end
	end
 
	return hitNotes, hasSustain
end
 
function Notefield:addNote(note)
	note.parent = self
	table.insert(self.activeNotes, note)
	return note
end
 
function Notefield:makeNote(time, column, sustain, type, skin)
	local note = Note(time, column, sustain, type, skin or self.skin)
	note.parent = self
	table.insert(self.activeNotes, note)
	return note
end
 
function Notefield:removeNoteFromIndex(idx)
	local note = self.activeNotes[idx]
	if not note then return end
	if self.lastSustain == note then
		self.lastSustain = nil
	end
	note.lastPress = nil
 
	local lane = note.group
	if lane then
		note.group, lane.renderedNotesI[note] = nil
		lane:remove(note)
		table.delete(lane.renderedNotes, note)
	end
 
	return table.remove(self.activeNotes, idx)
end
 
function Notefield:removeNote(note)
	local idx = table.find(self.activeNotes, note)
	if idx then
		return self:removeNoteFromIndex(idx)
	end
end
 
function Notefield:copyNotesFromNotefield(notefield)
	if notefield.chartNotes and #notefield.chartNotes > 0 then
		self.chartNotes = {}
		for i, chartNote in ipairs(notefield.chartNotes) do
			self.chartNotes[i] = {
				t = chartNote.t,
				d = chartNote.d,
				l = chartNote.l,
				k = chartNote.k,
				gf = chartNote.gf,
				character = chartNote.character
			}
		end
		self.chartIndex = 1
	else
		for i, note in ipairs(notefield.activeNotes) do
			local noteClone = note:clone()
			noteClone.parent = self
			table.insert(self.activeNotes, noteClone)
		end
	end
 
	table.sort(self.activeNotes, Conductor.sortByTime)
end
 
function Notefield:setSkin(skin)
	if self.skin == skin then return end
 
	self.skin = skin.data
 
	for _, receptor in ipairs(self.receptors) do
		receptor:setSkin(skin.data)
	end
	for _, note in ipairs(self.activeNotes) do
		note:setSkin(skin.data)
	end
end
 
function Notefield:fadeInReceptors(tween)
	for i = 1, #self.lanes do
		local receptor = self.lanes[i].receptor
		receptor.y = receptor.y - 10
		receptor.alpha = 0
 
 		local func = function(...) return tween and tween:tween(...) or Tween.tween(...) end
		func(receptor, {y = receptor.y + 10, alpha = 1}, 1, {
			ease = "circOut",
			startDelay = 0.16 + (0.2 * i)
		})
	end
end
 
function Notefield:update(dt)
	Notefield.super.update(self, dt)
 
	local maxSpeed = self.speed
	for _, lane in ipairs(self.lanes) do
		maxSpeed = math.max(maxSpeed, self.speed * lane.speed)
	end
	self.spawnBuffer = math.max(2.0, 1.0 + maxSpeed * 0.5)
 
	if #self.chartNotes == 0 then return end
 
	local currentTime = (self.time - self.offsetTime) * 1000
	local spawnTime = currentTime + self.spawnBuffer * 1000
 
	if spawnTime - self.lastSpawnTime < 100 then return end
	self.lastSpawnTime = spawnTime
 
	while self.chartIndex <= #self.chartNotes do
		local chartNote = self.chartNotes[self.chartIndex]
		if chartNote.t > spawnTime then break end
 
		local sustainTime = chartNote.l or 0
		if sustainTime ~= 0 then
			sustainTime = math.max(sustainTime / 1000, 0.125)
		end
 
		local note = Note(chartNote.t / 1000, chartNote.d % 4, sustainTime, chartNote.k, self.skin)
		note.parent = self
		if chartNote.character then
			note.character = chartNote.character
		end
 
		table.insert(self.activeNotes, note)
		self.chartIndex = self.chartIndex + 1

		if self.state.scripts then
			self.state.scripts:call("noteSpawn", note)
		end
	end
 
	if #self.activeNotes > 1 then
		table.sort(self.activeNotes, function(a, b) return a.time < b.time end)
	end
 
	for _, lane in ipairs(self.lanes) do
		for _, note in ipairs(lane.renderedNotes) do
			note:update(dt)
		end
	end
	for _, mod in pairs(self.modifiers) do mod:update(self.beat) end
end
 
function Notefield:screenCenter(axes)
	if axes == nil then axes = "xy" end
	if axes:find("x") then self.x = (game.width - self.width) / 2 end
	if axes:find("y") then self.y = game.height / 2 end
	if axes:find("z") then self.z = 0 end
	return self
end
 
function Notefield:getWidth()
	return self.width
end
 
function Notefield:getHeight()
	return self.noNoteRender and self.noteWidth or self.height
end
 
function Notefield:destroy()
	ActorSprite.destroy(self)
 
	self.modifiers = nil
	if self.receptors then
		for _, r in ipairs(self.receptors) do r:destroy() end
		self.receptors = nil
	end
 
	if self.activeNotes then
		for _, n in ipairs(self.activeNotes) do n:destroy() end
		self.activeNotes = nil
	end
 
	if self.lanes then
		for _, l in ipairs(self.lanes) do
			l:destroy(); if l.receptor then l.receptor:destroy() end
			l.renderedNotes, l.renderedNotesI, l.currentNoteI, l.receptor = nil
		end
	end
 
	self.chartNotes = nil
end
 
function Notefield:__prepareLane(direction, lane, time)
	if self.noNoteRender then
		for _, note in ipairs(lane.renderedNotes) do
			note.group = nil
			lane:remove(note)
			table.delete(lane.renderedNotes, note)
		end
		return
	end

	local notes, receptor, speed, drawSize, drawSizeOffset =
		self.activeNotes, lane.receptor,
		self.speed * lane.speed,
		self.drawSize * (lane.drawSize or 1),
		self.drawSizeOffset + (lane.drawSizeOffset or 0)
 
	local size, renderedNotes, renderedNotesI = #notes, lane.renderedNotes, lane.renderedNotesI
	table.clear(renderedNotesI)
 
	if size == 0 then
		for _, note in ipairs(renderedNotes) do
			note.group = nil
			lane:remove(note)
			table.delete(renderedNotes, note)
		end
		return
	end
 
	local repx, repy, repz = receptor.x, receptor.y, receptor.z
	local offset, noteI = (-drawSize / 2) - repy + drawSizeOffset, math.clamp(lane.currentNoteI, 1, size)
	while noteI < size and not notes[noteI].sustain and
		(notes[noteI + 1].direction ~= direction or Note.toPos(notes[noteI + 1].time - time, speed) <= offset)
	do
		noteI = noteI + 1
	end
	while noteI > 1 and (Note.toPos(notes[noteI - 1].time - time, speed) > offset) do noteI = noteI - 1 end
 
	lane._drawSize, lane._drawSizeOffset = lane.drawSize, lane.drawSizeOffset
	lane.drawSize, lane.drawSizeOffset, lane.currentNoteI = drawSize, drawSizeOffset, noteI
	local reprx, repry, reprz = receptor.noteRotations.x, receptor.noteRotations.y, receptor.noteRotations.z
	local repox, repoy, repoz = repx + receptor.noteOffsets.x, repy + receptor.noteOffsets.y, repz + receptor.noteOffsets.z
	while noteI <= size do
		local note = notes[noteI]
		local y = Note.toPos(note.time - time, speed)
		if note.direction == direction and (y > offset or note.sustain) then
			if y > drawSize / 2 + drawSizeOffset - repy then break end
 
			renderedNotesI[note] = true
			local prevlane = note.group
			if prevlane ~= lane then
				if prevlane then prevlane:remove(note) end
				table.insert(renderedNotes, note)
				lane:add(note)
				note.group = lane
			end
 
			note._rx, note._ry, note._rz, note._speed = note.rotation.x, note.rotation.y, note.rotation.z, note.speed
			note._targetTime, note.speed, note.rotation.x, note.rotation.y, note.rotation.z =
				time, note._speed * speed, note._rx + reprx, note._ry + repry, note._rz + reprz
		end
 
		noteI = noteI + 1
	end
 
	for _, note in ipairs(renderedNotes) do
		if not renderedNotesI[note] then
			note.group = nil
			lane:remove(note)
			table.delete(renderedNotes, note)
		end
	end
end
 
function Notefield:__render(camera)
	local time = self.time - self.offsetTime
	for i, lane in ipairs(self.lanes) do
		self:__prepareLane(i - 1, lane, time)
	end
	love.graphics.push()
	love.graphics.translate(self.groupOrigin.x, self.groupOrigin.y)
	love.graphics.scale(self.groupScale.x, self.groupScale.y)
	love.graphics.translate(-self.groupOrigin.x, -self.groupOrigin.y)
 
	for _, mod in pairs(self.modifiers) do if mod.apply then mod:apply(self) end end
	if self.downscroll then self.scale.y = -self.scale.y end
	self.x = self.x - self.__offsetX
	Notefield.super.__render(self, camera)
	self.x = self.x + self.__offsetX
	if self.downscroll then self.scale.y = -self.scale.y end
	NoteModifier.discard()
 
	for _, lane in ipairs(self.lanes) do
		lane.drawSize, lane.drawSizeOffset = lane._drawSize, lane._drawSizeOffset
		for _, note in ipairs(lane.renderedNotes) do
			note.speed, note.rotation.x, note.rotation.y, note.rotation.z = note._speed, note._rx, note._ry, note._rz
		end
	end
	love.graphics.pop()
end
 
return Notefield
