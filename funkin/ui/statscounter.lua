-- this code fucking sucks
local StatsCounter = Object:extend("StatsCounter")

local collectgarbage = collectgarbage
local countbytes = math.countbytes
local getRendererInfo = love.graphics.getRendererInfo
local getStats = love.graphics.getStats
local newText = love.graphics.newText
local grap = love.graphics
local getFPS = love.timer.getFPS
local getTPS = love.timer.getTPS

local rname, rversion, rvendor, rdevice
function StatsCounter:new(x, y, font, bigfont, color, align)
	StatsCounter.super.new(self, x, y)

	self.font = font or grap.newFont(14)
	self.bigfont = bigfont or grap.newFont(18)
	self.color = Color.WHITE
	self.alignment = align or "left"
	self.width = 512

	self.showFps = true
	self.showRender = true
	self.showMemory = true
	self.showDraws = true

	self.compact = true

	self.bigTextObj = grap.newText(self.bigfont)
	self.regTextObj = grap.newText(self.font)

	self.shadowColor = {Color.get(Color.BLACK)}
	self.color = {Color.get(Color.WHITE)}
	self.regMainColor = {Color.get(Color.WHITE)}

	rname, rversion, rvendor, rdevice = grap.getRendererInfo()
end

local combine = " / "
local fpsFormat, tpsFormat = "%d FPS", "%d TPS"
local ramFormat, renderFormat, drawsFormat = "%s RAM / %s VRAM", "%s / %s", "%d DRAWS"
local count = "count"

function StatsCounter:__render(camera)
	grap.push("all")

	local x, y, rad, sx, sy, ox, oy = self:setupDrawLogic(camera)

	local align, color, width, bigheight = self.alignment, self.color, self.width, self.bigfont:getHeight()

	self.shadowColor[4] = self.alpha * 0.8
	self.regMainColor[4] = self.alpha * 0.75

	local bigcontent = fpsFormat:format(getFPS())
	if not love.vsync then
		bigcontent = bigcontent .. combine .. tpsFormat:format(getTPS())
	end

	local stats = grap.getStats()
	local ram = countbytes(collectgarbage(count), 2)
	local vram = countbytes(stats.texturememory)

	if self.showFps then
		self.bigTextObj:clear()
		self.bigTextObj:addf({self.shadowColor, bigcontent}, width, align, 1, 1)
		self.bigTextObj:addf({self.color, bigcontent}, width, align, 0, 0)
	end

	self.regTextObj:clear()
	local yOffset = self.showFps and bigheight or 0

	if self.compact then
		local rightWidth = grap.getWidth() - (x * 2)
		local line1 = ""

		if self.showMemory and self.showDraws then
			line1 = ramFormat:format(ram, vram) .. combine .. drawsFormat:format(stats.drawcalls)
		elseif self.showMemory then
			line1 = ramFormat:format(ram, vram)
		elseif self.showDraws then
			line1 = drawsFormat:format(stats.drawcalls)
		end

		local line2 = ""
		if self.showRender then
			line2 = renderFormat:format(rname, rdevice)
		end

		local s = ""
		if line1 ~= "" then s = line1 end
		if line2 ~= "" then s = s .. (s == "" and "" or "\n") .. line2 end

		if s ~= "" then
			self.regTextObj:addf({self.shadowColor, s}, rightWidth, "right", 1, 1)
			self.regTextObj:addf({self.regMainColor, s}, rightWidth, "right", 0, 0)
		end
	else
		local s = ""
		if self.showMemory then s = ramFormat:format(ram, vram) end
		if self.showRender then s = s .. (s == "" and "" or "\n") .. renderFormat:format(rname, rdevice) end
		if self.showDraws then s = s .. (s == "" and "" or "\n") .. drawsFormat:format(stats.drawcalls) end

		if self.showRender or self.showMemory or self.showDraws then
			self.regTextObj:addf({self.shadowColor, s}, width, align, 1, 1 + yOffset)
			self.regTextObj:addf({self.regMainColor, s}, width, align, 0, yOffset)
		end
	end

	grap.draw(self.bigTextObj, x, y, rad, sx, sy, ox, oy)
	grap.draw(self.regTextObj, x, y, rad, sx, sy, ox, oy)

	grap.pop()
end

return StatsCounter
