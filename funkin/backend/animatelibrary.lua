local json = loxreq "lib.json"
local AnimateLibrary = loxreq "animateatlas.library"

local AnimateLib = AnimateLibrary:extend("AnimateLib")

function AnimateLib:new(folder)
	self._defer = true
	AnimateLib.super.new(self, folder)
	self._defer = false
	self.loaded = false
end

function AnimateLib:loadImages()
	if self._defer then return end
	AnimateLib.super.loadImages(self)
end

function AnimateLib:loadAsync(callback)
	local textures = self.textures

	if not textures or #textures == 0 then
		self.loaded = true
		if callback then callback(self) end
		return
	end

	local remaining = #textures

	for _, loadData in ipairs(textures) do
		local image_path = loadData.image_path
		local json_path  = loadData.json_path

		paths.async.queueTask("image", image_path, function(tex)
			if tex then
				local atlasData = json.decode(love.filesystem.read("string", json_path))
				local texW, texH = tex:getWidth(), tex:getHeight()
				local sprites = atlasData.ATLAS.SPRITES

				for z = 1, #sprites do
					local sprite = sprites[z].SPRITE
					local n_id = self:getStringId(sprite.name)
					self.sprite_quads[n_id]    = love.graphics.newQuad(sprite.x, sprite.y, sprite.w, sprite.h, texW, texH)
					self.sprite_textures[n_id] = tex
					if sprite.rotated then
						self.sprite_rotated[n_id] = true
						self.sprite_w[n_id]       = sprite.w
					end
				end
			end

			remaining = remaining - 1
			if remaining == 0 then
				self.textures = nil
				self.loaded = true
				if callback then callback(self) end
			end
		end)
	end
end

return AnimateLib
