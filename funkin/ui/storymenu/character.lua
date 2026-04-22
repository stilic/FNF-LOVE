---@class StoryCharacter:Sprite
local StoryCharacter = Sprite:extend("StoryCharacter")

function StoryCharacter:new(x, char)
	StoryCharacter.super.new(self, x)
	self:changeCharacter(char)
end

function StoryCharacter:changeCharacter(char)
	if char == nil then char = '' end
	if char == self.character then return end

	self.character = char
	self.visible = true

	self.scale:set(1, 1)
	self:updateHitbox()

	self.hasConfirmAnimation = false
	switch(self.character, {
		[''] = function() self.visible = false end,
		default = function()
			local path = 'data/weeks/characters/' .. self.character
			if not paths.exists(paths.getPath(path .. '.json'), "file") then
				path = 'data/weeks/characters/bf'
			end

			local charFile = paths.getJSON(path)
			self:setFrames(paths.getSparrowAtlas(
				'menus/storymenu/characters/' .. charFile.sprite))
			self.animation:reset()
			self.animation:addByPrefix('idle', charFile.idle_anim, 24)

			local confirmAnim = charFile.confirm_anim
			if confirmAnim ~= nil and confirmAnim:len() > 0 and confirmAnim ~=
				charFile.idle_anim then
				self.animation:addByPrefix('confirm', confirmAnim, 24, false)
				if self.animation:has('confirm') then
					self.hasConfirmAnimation = true
				end
			end

			self.flipX = (charFile.flipX == true)

			if charFile.scale ~= 1 then
				self.scale:set(charFile.scale, charFile.scale)
				self:updateHitbox()
			end
			self.offset.x, self.offset.y = charFile.position[1],
				charFile.position[2]
			self.animation:play('idle')
		end
	})
end

return StoryCharacter
