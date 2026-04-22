local json = loxreq("lib.json")

local Save = Classic:extend("Save")

function Save:new(filename)
	self.filename = filename
	self.data = {}
	self.path = ''
	self.initialized = false
end

function Save:load()
	if self.initialized then return end
	self.initialized = true

	if love.system.getDevice() == "Mobile" then
		self.path = love.filesystem.getSaveDirectory()
		if love.filesystem.getInfo(self.filename .. '.lox') then
			local dataFile = love.filesystem.read(self.filename .. '.lox')
			if dataFile then
				self:__decode(dataFile)
			end
		end
	else
		self.path = love.filesystem.getAppdataDirectory() .. '/' .. Project.company .. '/' .. Project.file
		local filePath = self.path .. '/' .. self.filename .. '.lox'
		local dataFile = io.open(filePath, "rb")
		if dataFile then
			local content = dataFile:read("a")
			self:__decode(content)
			dataFile:close()
		end
	end
end

function Save:save()
	local success, jsonString = pcall(json.encode, self.data)
	if not success then
		Logger.log("error", "Failed to encode save data for " .. self.filename)
		return
	end

	local compressedData = love.data.compress("string", "zlib", jsonString)
	if love.system.getDevice() == "Mobile" then
		love.filesystem.write(self.filename .. '.lox', compressedData)
	else
		local company = Project.company or "company"
		local folder = Project.file or "game"

		self.path = love.filesystem.getAppdataDirectory() .. '/' .. company .. '/' .. folder
		local filePath = self.path .. '/' .. self.filename .. '.lox'
		local saveFile = io.open(filePath, "wb")

		if not saveFile then
			self:__ensureDir(filePath)
			saveFile = io.open(filePath, "wb")
		end

		if saveFile then
			saveFile:write(compressedData)
			saveFile:close()
		else
			Logger.log("error", "Could not write to " .. filePath)
		end
	end
end

function Save:__ensureDir(filePath)
	local dirToMake = filePath:gsub('/' .. self.filename .. '.lox', '')
	if love.system.getOS() == "Windows" then
		os.execute('mkdir "' .. dirToMake .. '"')
	else
		os.execute('mkdir -p "' .. dirToMake .. '"')
	end
end

function Save:__decode(raw)
	local successDecompress, decompressedJson = pcall(love.data.decompress, "string", "zlib", raw)
	if not successDecompress then
		Timer.wait(0.1, function()
			Logger.log("error", "Save file \"" ..self.filename.. "\" cannot be decompressed")
		end)
		return
	end
	local successJson, content = pcall(json.decode, decompressedJson)
	if not successJson then
		Timer.wait(0.1, function()
			Logger.log("error", "Save file \"" ..self.filename.. "\" is corrupt")
		end)
		return
	end
	self.data = content
end

return Save
