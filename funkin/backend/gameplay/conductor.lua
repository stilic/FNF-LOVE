local Conductor = Classic:extend("Conductor", true)

function Conductor:new(timeChanges)
	self.onMeasure, self.onBeat, self.onStep, self.onTimeChange = Signal(), Signal(), Signal(), Signal()
	self.measureF, self.measureI = 0, 0
	self.beatF,    self.beatI    = 0, 0
	self.stepF,    self.stepI    = 0, 0
	self.time, self.prevTime, self.bpmOverride = 0, 0
	self:mapTimeChanges(timeChanges or {})
end

function Conductor:getBPM(initial)
	if self.bpmOverride then return self.bpmOverride end
	if initial then return self.timeChanges[1] and self.timeChanges[1].bpm or 100 end
	return self.curTimeChange and self.curTimeChange.bpm or self.startBPM
end

function Conductor:getSemiquaver() return (self.crotchet or 1000) / 4 end
function Conductor:getCrotchet()   return (60 / self.bpm) * 1000 end

function Conductor:getSemibreve()
	local num = self.timeSignNum or 4
	local den = self.timeSignDen or 4
	return self.crotchet * (num / den) * 4
end

function Conductor:getTimeSign(num)
	return num and (self.curTimeChange and self.curTimeChange.n or 4)
	           or  (self.curTimeChange and self.curTimeChange.d or 4)
end

function Conductor:getBeatsPerMeasure() return self.stepsPerMeasure / 4 end

function Conductor:getStepsPerMeasure()
	return math.floor((self.timeSignNum or 4) / (self.timeSignDen or 4) * 16)
end

function Conductor:forceBPM(bpm) self.bpmOverride = bpm end

function Conductor:update(songPos)
	self.prevTime = self.time
	self.time = songPos or self.time

	if self.time >= 0 then
		songPos = game.sound.music and game.sound.music.time * 1000 or 0
	end

	local oldm, oldb, olds = self.measureI, self.beatI, self.stepI
	local timeChanges      = self.timeChanges

	self.curTimeChange = timeChanges[1]
	if songPos > 0 then
		for i = 1, #timeChanges do
			local tc = timeChanges[i]
			if songPos >= tc.t then
				self.curTimeChange = tc
				self.onTimeChange:dispatch()
			else
				break
			end
		end
	end

	local stepCrotchet = self.stepCrotchet
	local cur          = self.curTimeChange
	local sf = cur and songPos > 0
		and ((cur.b or 0) * 4) + (songPos - (cur.t or 4)) / stepCrotchet
		or  songPos / stepCrotchet
	local bf = sf / 4
	local mf = sf / self.stepsPerMeasure
	self.stepF,    self.stepI    = sf, math.floor(sf)
	self.beatF,    self.beatI    = bf, math.floor(bf)
	self.measureF, self.measureI = mf, math.floor(mf)

	if self.stepI    ~= olds then self.onStep:dispatch(self.stepI)       end
	if self.beatI    ~= oldb then self.onBeat:dispatch(self.beatI)       end
	if self.measureI ~= oldm then self.onMeasure:dispatch(self.measureI) end
end

function Conductor:mapTimeChanges(timeChanges)
	local result = {}
	for _, time in ipairs(timeChanges) do
		if time.t < 0 then time.t = 0 end
		time.b = 0
		if time.t > 0 and #result > 0 then
			local prev = result[#result]
			time.b = math.truncate(prev.b + (time.t - prev.t) * prev.bpm / 60000, 4)
		end
		result[#result + 1] = time
	end
	self.timeChanges = result
end

function Conductor:getTimeInSteps(ms)
	if #self.timeChanges == 0 then return math.floor(ms / self.stepCrotchet) end

	local lastTC = self.timeChanges[1]
	for _, tc in ipairs(self.timeChanges) do
		if ms >= tc.t then lastTC = tc else break end
	end
	return lastTC.b * 4 + (ms - lastTC.t) / ((60 / lastTC.bpm) * 250)
end

function Conductor:getStepTimeInMs(stepTime)
	if #self.timeChanges == 0 then return stepTime * self.stepCrotchet end

	local lastTC = self.timeChanges[1]
	for _, tc in ipairs(self.timeChanges) do
		if stepTime >= tc.b * 4 then lastTC = tc else break end
	end
	return lastTC.t + (stepTime - lastTC.b * 4) * ((60 / lastTC.bpm) * 250)
end

function Conductor:getBeatTimeInMs(beatTime)
	if #self.timeChanges == 0 then return beatTime * self.crotchet end

	local lastTC = self.timeChanges[1]
	for _, tc in ipairs(self.timeChanges) do
		if beatTime >= tc.b then lastTC = tc else break end
	end
	return lastTC.t + (beatTime - lastTC.b) * (60 / lastTC.bpm) * 1000
end

function Conductor:destroy()
	self.onMeasure:destroy()
	self.onBeat:destroy()
	self.onStep:destroy()
	self.onTimeChange:destroy()
end

Conductor.__getters.bpm             = Conductor.getBPM
Conductor.__getters.startBPM        = function(s) return s:getBPM(true) end
Conductor.__getters.crotchet        = Conductor.getCrotchet
Conductor.__getters.stepCrotchet    = Conductor.getSemiquaver
Conductor.__getters.measureCrotchet = Conductor.getSemibreve
Conductor.__getters.timeSignNum     = function(s) return s:getTimeSign(true) end
Conductor.__getters.timeSignDen     = Conductor.getTimeSign
Conductor.__getters.beatsPerMeasure = Conductor.getBeatsPerMeasure
Conductor.__getters.stepsPerMeasure = Conductor.getStepsPerMeasure

for _, n in pairs({"measure", "beat", "step"}) do
	local name = n
	Conductor.__getters["current" .. name:capitalize()]            = function(s) return s[name .. "I"] end
	Conductor.__getters["current" .. name:capitalize() .. "Float"] = function(s) return s[name .. "F"] end
end

return Conductor
