local thread = [[
require("love.sound")
local ffi = require("ffi")
local bit = require("bit")

local inputChannel = love.thread.getChannel("fft_input")
local outputChannel = love.thread.getChannel("fft_output")

local MAX_SIZE = 4096
local real = ffi.new("float[?]", MAX_SIZE)
local imag = ffi.new("float[?]", MAX_SIZE)

local function doFFT(size)
	-- bitreversal permutation
	local j = 0
	for i = 0, size - 1 do
		if i < j then
			local tr, ti = real[i], imag[i]
			real[i], imag[i] = real[j], imag[j]
			real[j], imag[j] = tr, ti
		end
		local m = bit.rshift(size, 1)
		while m >= 1 and j >= m do
			j = j - m
			m = bit.rshift(m, 1)
		end
		j = j + m
	end

	local mmax = 1
	while size > mmax do
		local istep = bit.lshift(mmax, 1)
		local theta = -math.pi / mmax
		local wtemp = math.sin(0.5 * theta)
		local wpr = -2.0 * wtemp * wtemp
		local wpi = math.sin(theta)
		local wr, wi = 1.0, 0.0

		for m = 0, mmax - 1 do
			for i = m, size - 1, istep do
				local j = i + mmax
				local tempr = wr * real[j] - wi * imag[j]
				local tempi = wr * imag[j] + wi * real[j]
				real[j] = real[i] - tempr
				imag[j] = imag[i] - tempi
				real[i] = real[i] + tempr
				imag[i] = imag[i] + tempi
			end
			local wtemp2 = wr
			wr = wr * wpr - wi * wpi + wr
			wi = wi * wpr + wtemp2 * wpi + wi
		end
		mmax = istep
	end
end

local audioData = nil
local params = {}
local ready = false

while true do
	local msg = inputChannel:pop()
	if msg then
		if msg.type == "quit" then
			break
		elseif msg.type == "init" then
			params = msg
			audioData = love.sound.newSoundData(msg.path)
			params.sampleRate = audioData:getSampleRate()
			params.channels = audioData:getChannelCount()
			ready = true
			outputChannel:push({type = "ready"})

		elseif msg.type == "process" and ready then
			local size = msg.size
			local startSample = math.floor(msg.pos * params.sampleRate)
			local totalSamples = audioData:getSampleCount()

			for i = 0, size - 1 do
				local idx = startSample + i
				if idx >= 0 and idx < totalSamples then
					local s = audioData:getSample(idx * params.channels)
					if params.channels > 1 then
						s = (s + audioData:getSample(idx * params.channels + 1)) * 0.5
					end

					local window = 0.5 * (1 - math.cos((2 * math.pi * i) / (size - 1)))
					real[i] = s * window
				else
					real[i] = 0
				end
				imag[i] = 0
			end

			doFFT(size)

			local nyquist = params.sampleRate / 2
			local binSize = nyquist / (size / 2)
			local logMin = math.log(params.minFreq)
			local logMax = math.log(math.min(params.maxFreq, nyquist))

			local bars = {}
			for i = 1, params.numBars do
				local logStart = logMin + ((i - 1) / params.numBars) * (logMax - logMin)
				local logEnd = logMin + (i / params.numBars) * (logMax - logMin)

				local startBin = math.max(1, math.floor(math.exp(logStart) / binSize))
				local endBin = math.min(size / 2, math.floor(math.exp(logEnd) / binSize))
				if startBin > endBin then endBin = startBin end

				local sum, count = 0, 0
				for j = startBin, endBin do
					local mag = math.sqrt(real[j]*real[j] + imag[j]*imag[j]) / size
					sum = sum + mag
					count = count + 1
				end

				local amplitude = count > 0 and (sum / count) * (1.0 + (i / params.numBars) * 8.0) or 0
				if amplitude > 0 then
					local db = math.max(params.minDb, math.min(params.maxDb, 20 * math.log10(amplitude)))
					bars[i] = (db - params.minDb) / (params.maxDb - params.minDb)
				else
					bars[i] = 0
				end
			end

			outputChannel:push({type = "result", bars = bars})
		end
	end
	require("love.timer").sleep(0.001)
end
]]

local fftThread = love.thread.newThread(thread)
local inputChannel = love.thread.getChannel("fft_input")
local outputChannel = love.thread.getChannel("fft_output")

local FFT = Classic:extend()

function FFT:new(numBars, audioFile, externalSource)
	self.numBars = numBars or 7
	self.bars = {}
	for i = 1, self.numBars do self.bars[i] = 0 end

	self.fftSize = 2048
	self.externalSource = externalSource
	self.isReady = false
	self.processing = false

	if not fftThread:isRunning() then fftThread:start() end

	inputChannel:push({
		type = "init",
		path = paths.getPath(audioFile),
		numBars = self.numBars,
		minDb = -75,
		maxDb = -10,
		minFreq = 60,
		maxFreq = 20000
	})
end

function FFT:update(dt)
	while true do
		local msg = outputChannel:pop()
		if not msg then break end

		if msg.type == "ready" then
			self.isReady = true
		elseif msg.type == "result" then
			self.bars = msg.bars
			self.processing = false
		end
	end

	local isPlaying = self.externalSource and self.externalSource:isPlaying()

	if isPlaying and self.isReady and not self.processing then
		inputChannel:push({
			type = "process",
			pos = self.externalSource:tell(),
			size = self.fftSize
		})
		self.processing = true
	elseif not isPlaying then
		for i = 1, self.numBars do self.bars[i] = 0 end
		self.processing = false
	end
end

function FFT:getBars() return self.bars end
function FFT:getBar(index) return self.bars[index] or 0 end

function FFT.close()
	inputChannel:push({type = "quit"})
	fftThread:wait()
end

return FFT
