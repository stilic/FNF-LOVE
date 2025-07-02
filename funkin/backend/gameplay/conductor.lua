local Conductor = Classic:extend("Conductor")

local setter = {
	__index = function(s, k)
		return k == "i" and math.floor(s[1]) or s[1]
	end,
	__newindex = function(s, _, v) s[1] = v; return end
}
local function make() return setmetatable({0}, setter) end

function Conductor:new(timeChanges)
	self.onMeasure, self.onBeat, self.onStep, self.onTimeChange = Signal(), Signal(), Signal(), Signal()
	self.measure, self.beat, self.step = make(), make(), make()
	self.time, self.prevTime, self.bpmOverride = 0, 0
	self:mapTimeChanges(timeChanges or {})
end

function Conductor:getBPM(initial)
	if self.bpmOverride then return self.bpmOverride end
	if initial then return self.timeChanges[1] and self.timeChanges[1].bpm or 100 end
	return self.curTimeChange and self.curTimeChange.bpm or self.startBPM
end

function Conductor:getSemiquaver() return (self.crotchet or 1000) / (self.timeSignNum or 4) end

function Conductor:getCrotchet() return (60 / self.bpm) * 1000 end

function Conductor:getSemibreve() return self.crotchet * self.timeSignNum end

function Conductor:getTimeSign(num)
	return num and (self.curTimeChange and self.curTimeChange.n or 4) or
		self.curTimeChange and self.curTimeChange.d or 4
end

function Conductor:getBeatsPerMeasure() return self.stepsPerMeasure / 4 end

function Conductor:getStepsPerMeasure()
	return math.floor((self.timeSignNum or 4) / (self.timeSignDen or 4) * 4 * 4)
end

function Conductor:forceBPM(bpm) self.bpmOverride = bpm end

function Conductor:update(songPos)
	self.prevTime = self.time

	self.time = songPos or self.time
	if self.time >= 0 then
		songPos = game.sound.music and game.sound.music.time * 1000 or 0
	end

	local oldm, oldb, olds = self.measure.i, self.beat.i, self.step.i

	self.curTimeChange = self.timeChanges[1]
	if songPos > 0 then
		for i = 1, #self.timeChanges do
			if songPos >= self.timeChanges[i].t then
				self.curTimeChange = self.timeChanges[i]
				self.onTimeChange:dispatch()
			end
			if songPos < self.timeChanges[i].t then
				break
			end
		end
	end

	if self.curTimeChange and songPos > 0 then
		self.step.f = ((self.curTimeChange.b or 0) * 4) +
			(songPos - (self.curTimeChange.t or 4)) / self.stepCrotchet
	else
		self.step.f = songPos / self.stepCrotchet
	end
	self.beat.f = self.step.f / 4
	self.measure.f = self.step.f / self.stepsPerMeasure

	if self.step.i ~= olds then self.onStep:dispatch(self.step.i) end
	if self.beat.i ~= oldb then self.onBeat:dispatch(self.beat.i) end
	if self.measure.i ~= oldm then self.onMeasure:dispatch(self.measure.i) end
end

function Conductor:mapTimeChanges(timeChanges)
	self.timeChanges = {}

	for _, time in ipairs(timeChanges) do
		if time.t < 0 then time.t = 0 end

		if time.t <= 0 then
			time.b = 0
		else
			time.b = 0
			if time.t > 0 and #self.timeChanges > 0 then
				local prevTime = self.timeChanges[#self.timeChanges]
				time.b = math.truncate(prevTime.b
					+ ((time.t - prevTime.t) * prevTime.bpm
					/ 60 / 1000), 4)
			end
		end
		table.insert(self.timeChanges, time)
	end
end

function Conductor:getTimeInSteps(ms)
	if #self.timeChanges == 0 then
		return math.floor(ms / self.stepCrotchet)
	else
		local resultStep = 0

		local lastTimeChange = self.timeChanges[1]
		for _, timeChange in ipairs(self.timeChanges) do
			if ms >= timeChange.t then
				lastTimeChange = timeChange
				resultStep = lastTimeChange.b * 4
			else
				break
			end
		end
		local lastStepCrotchet = ((60 / lastTimeChange.bpm) * 1000) / self.timeSignNum
		local resultFracStep = (ms - lastTimeChange.t) / lastStepCrotchet
		resultStep = resultStep + resultFracStep

		return resultStep
	end
end

function Conductor:getStepTimeInMs(stepTime)
	if #self.timeChanges == 0 then
		return stepTime * self.stepCrotchet
	else
		local resultMs = 0

		local lastTimeChange = self.timeChanges[1]
		for _, timeChange in ipairs(self.timeChanges) do
			if stepTime >= timeChange.b * 4 then
				lastTimeChange = timeChange
				resultMs = lastTimeChange.t
			else
				break
			end
		end
		local lastStepCrotchet = ((60 / lastTimeChange.bpm) * 1000) / self.timeSignNum
		resultMs = resultMs + (stepTime - lastTimeChange.b * 4) * lastStepCrotchet

		return resultMs
	end
end

function Conductor:getBeatTimeInMs(beatTime)
	if #self.timeChanges == 0 then
		return beatTime * self.stepCrotchet * 4
	else
		local resultMs = 0

		local lastTimeChange = self.timeChanges[1]
		for _, timeChange in ipairs(self.timeChanges) do
			if beatTime >= timeChange.b then
				lastTimeChange = timeChange
				resultMs = lastTimeChange.t
			else
				break
			end
		end

		local lastStepCrotchet = ((60 / lastTimeChange.bpm) * 1000) / self.timeSignNum
		resultMs = resultMs + (beatTime - lastTimeChange.b) * lastStepCrotchet * 4

		return resultMs
	end
end

function Conductor:destroy()
	self.onMeasure:destroy()
	self.onBeat:destroy()
	self.onStep:destroy()
	self.onTimeChange:destroy()
end

local redirect = {
	bpm = "getBPM",
	startBPM = function(s) return s:getBPM(true) end,
	crotchet = "getCrotchet",
	stepCrotchet = "getSemiquaver",
	measureCrotchet = "getSemibreve",
	timeSignNum = function(s) return s:getTimeSign(true) end,
	timeSignDen = "getTimeSign",
	beatsPerMeasure = "getBeatsPerMeasure",
	stepsPerMeasure = "getStepsPerMeasure"
}
for _, n in pairs({"measure", "beat", "step"}) do
	redirect["current" .. n:capitalize()] = function(s) return s[n].i end
	redirect["current" .. n:capitalize() .. "Float"] = function(s) return s[n].f end
end

function Conductor:__index(k)
	local g = redirect[k]
	return g and (type(g) == "function" and g(self) or self[g](self)) or
		rawget(self, k) or Conductor[k]
end

return Conductor
