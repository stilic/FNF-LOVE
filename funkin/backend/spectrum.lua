local thread = [[
require("love.sound")
local ffi = require("ffi")
local bit = require("bit")

local inputChannel = love.thread.getChannel("spectrum_input")
local outputChannel = love.thread.getChannel("spectrum_output")

local MAX_SIZE = 4096
local real = ffi.new("float[?]", MAX_SIZE)
local imag = ffi.new("float[?]", MAX_SIZE)

local function doFFT(size)
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

local decoder = nil
local params = {}
local ready = false

while true do
	local msg = inputChannel:pop()
	if msg then
		if msg.type == "quit" then
			break
		elseif msg.type == "init" then
			params = msg
			local probe = love.sound.newDecoder(msg.path, 4)
			params.sampleRate = probe:getSampleRate()
			params.channels = probe:getChannelCount()
			params.bitDepth = probe:getBitDepth()
			probe = nil
			decoder = love.sound.newDecoder(msg.path, msg.fftSize * params.channels * (params.bitDepth / 8))
			ready = true
			outputChannel:push({type = "ready"})

		elseif msg.type == "process" and ready then
			local size = msg.size
			decoder:seek(msg.pos)
			local chunk = decoder:decode()

			local frames = chunk and chunk:getSampleCount() or 0
			local channels = params.channels
			local ptr = chunk and ffi.cast("int16_t*", chunk:getFFIPointer())

			for i = 0, size - 1 do
				if i < frames then
					local s = ptr[i * channels] / 32768
					if channels > 1 then
						s = (s + ptr[i * channels + 1] / 32768) * 0.5
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

				local centerFreq = math.sqrt(math.exp(logStart) * math.exp(logEnd))
				local boostDb = params.slopeDbPerOctave * (math.log(centerFreq / params.minFreq) / math.log(2))

				local amplitude = count > 0 and (sum / count) or 0
				local db = amplitude > 0 and (20 * math.log10(amplitude) + boostDb) or params.minDb
				db = math.max(params.minDb, math.min(params.maxDb, db))

				bars[i] = (db - params.minDb) / (params.maxDb - params.minDb)
			end

			outputChannel:push({type = "result", bars = bars})
		end
	end
	require("love.timer").sleep(0.001)
end
]]

local spectrumThread = love.thread.newThread(thread)
local inputChannel = love.thread.getChannel("spectrum_input")
local outputChannel = love.thread.getChannel("spectrum_output")

local Spectrum = Classic:extend()

function Spectrum:new(numBars, audioFile, externalSource)
	self.numBars = numBars or 7
	self.bars = {}
	for i = 1, self.numBars do self.bars[i] = 0 end

	self.fftSize = 2048
	self.externalSource = externalSource
	self.isReady = false
	self.processing = false

	if not spectrumThread:isRunning() then spectrumThread:start() end

	inputChannel:push({
		type = "init",
		path = paths.getPath(audioFile),
		numBars = self.numBars,
		fftSize = self.fftSize,
		minDb = -75,
		maxDb = -10,
		slopeDbPerOctave = 4,
		minFreq = 60,
		maxFreq = 20000
	})
end

function Spectrum:update(dt)
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

function Spectrum:getBars() return self.bars end
function Spectrum:getBar(index) return self.bars[index] or 0 end

function Spectrum.close()
	inputChannel:push({type = "quit"})
	spectrumThread:wait()
end

return Spectrum
