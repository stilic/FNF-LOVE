local Frame = loxreq "animation.frame"
local parseXml = loxreq "lib.xml"

---@class FrameCollection:Basic
local FrameCollection = Basic:extend("FrameCollection")

function FrameCollection:new(texture)
	self.texture = texture
	self.frames = {}
end

function FrameCollection:destroy()
	for _, frame in pairs(self.frames) do
		frame:destroy()
	end
	FrameCollection.super.destroy(self)
end

function FrameCollection:add(frame)
	table.insert(self.frames, frame)
end

function FrameCollection:getFrame(index)
	return self.frames[index]
end

function FrameCollection:getFrameCount()
	return #self.frames
end

function FrameCollection:addCollection(collection, force)
	if not collection or not collection.frames then
		return false
	end

	if force then
		for _, frame in ipairs(collection.frames) do
			self:add(frame)
		end
		return true
	end

	local frameNames = {}
	for i = 1, #self.frames do
		frameNames[self.frames[i].name] = true
	end
	for i = 1, #collection.frames do
		local frame = collection.frames[i]
		if not frameNames[frame.name] then
			self:add(frame)
			frameNames[frame.name] = true
		end
	end
	return nil
end

function FrameCollection.fromSparrow(texture, description)
	if type(texture) == "string" then
		texture = love.graphics.newImage(texture)
	end

	local collection = FrameCollection(texture)
	local sw, sh = texture:getDimensions()

	for _, c in ipairs(parseXml(description).TextureAtlas.children) do
		if c.name == "SubTexture" then
			local frame = Frame(c.attrs.name, tonumber(c.attrs.x),
				tonumber(c.attrs.y),
				tonumber(c.attrs.width),
				tonumber(c.attrs.height), sw, sh,
				tonumber(c.attrs.frameX),
				tonumber(c.attrs.frameY),
				tonumber(c.attrs.frameWidth),
				tonumber(c.attrs.frameHeight),
				c.attrs.rotated == "true",
				texture)
			collection:add(frame)
		end
	end

	return collection
end

function FrameCollection.fromPacker(texture, description)
	if type(texture) == "string" then
		texture = love.graphics.newImage(texture)
	end

	local collection = FrameCollection(texture)
	local sw, sh = texture:getDimensions()

	local pack = description:trim()
	local lines = pack:split("\n")
	for i = 1, #lines do
		local currImageData = lines[i]:split("=")
		local name = currImageData[1]:trim()
		local currImageRegion = currImageData[2]:split(" ")

		local frame = Frame(name, tonumber(currImageRegion[1]),
			tonumber(currImageRegion[2]),
			tonumber(currImageRegion[3]),
			tonumber(currImageRegion[4]), sw, sh)
		frame.texture = texture
		collection:add(frame)
	end

	return collection
end

function FrameCollection.fromTiles(texture, tileSize, region, tileSpacing)
	if type(texture) == "string" then
		texture = love.graphics.newImage(texture)
	end

	local collection = FrameCollection(texture)
	local sw, sh = texture:getDimensions()

	if region == nil then
		region = {
			x = 0,
			y = 0,
			width = texture:getWidth(),
			height = texture:getHeight()
		}
	else
		if region.width == 0 then
			region.width = texture:getWidth() - region.x
		end
		if region.height == 0 then
			region.height = texture:getHeight() - region.y
		end
	end

	tileSpacing = (tileSpacing ~= nil) and tileSpacing or {x = 0, y = 0}

	region.x = math.floor(region.x)
	region.y = math.floor(region.y)
	region.width = math.floor(region.width)
	region.height = math.floor(region.height)
	tileSpacing = {x = math.floor(tileSpacing.x), y = math.floor(tileSpacing.y)}
	tileSize = {x = math.floor(tileSize.x), y = math.floor(tileSize.y)}

	local spacedWidth = tileSize.x + tileSpacing.x
	local spacedHeight = tileSize.y + tileSpacing.y

	local numRows = (tileSize.y == 0) and 1 or
		math.floor(
			(region.height + tileSpacing.y) / spacedHeight)
	local numCols = (tileSize.x == 0) and 1 or
		math.floor((region.width + tileSpacing.x) / spacedWidth)

	local totalFrame = 0
	for j = 0, numRows - 1 do
		for i = 0, numCols - 1 do
			local frame = Frame(tostring(totalFrame),
				region.x + i * spacedWidth,
				region.y + j * spacedHeight,
				tileSize.x, tileSize.y, sw, sh)
			frame.texture = texture
			collection:add(frame)
			totalFrame = totalFrame + 1
		end
	end

	return collection
end

return FrameCollection
