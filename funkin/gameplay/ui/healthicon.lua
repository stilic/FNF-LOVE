local HealthIcon = Sprite:extend("HealthIcon")
HealthIcon.defaultIcon = "face"

function HealthIcon:new(icon, isPlayer, health)
	HealthIcon.super.new(self)
	self.isPlayer, self.isLegacyStyle = isPlayer or false, true
	self.health = health or 50
	self.flipX = self.isPlayer
	self.sprTracker = nil
	self:changeIcon(icon)
end

function HealthIcon:updateAnimation()
	if not self.animation.curAnim then return end

	local percent = self.health
	if not self.isPlayer then percent = 100 - percent end
	local isLosing = percent < 10
	if self.isLegacyStyle then
		self.animation.curAnim.frame = isLosing and 2 or 1
	else
		local isWinning = percent > 80
		local function backToIdleIfFinished()
			if self.animFinished then self.animation:play("idle") end
		end
		switch(self.curAnim and self.curAnim.name or "idle", {
			["idle"] = function()
				if isLosing then
					self:fallbackPlay("toLosing", "losing")
				elseif isWinning then
					self:fallbackPlay("toWinning", "winning")
				else
					self.animation:play("idle")
				end
			end,
			["winning"] = function()
				if not isWinning then
					self:fallbackPlay("fromWinning", "idle")
				else
					self:fallbackPlay("winning", "idle")
				end
			end,
			["losing"] = function()
				if not isLosing then
					self:fallbackPlay("fromLosing", "idle")
				else
					self:fallbackPlay("losing", "idle")
				end
			end,
			["toLosing"] = function()
				if self.animFinished then self:fallbackPlay("losing", "idle") end
			end,
			["toWinning"] = function()
				if self.animFinished then self:fallbackPlay("winning", "idle") end
			end,
			["fromLosing"] = backToIdleIfFinished,
			["fromWinning"] = backToIdleIfFinished,
			["default"] = function() self.animation:play("idle") end
		})
	end
end

function HealthIcon:changeIcon(icon)
	if icon and icon ~= "" then
		self.active, self.visible = true, true
	else
		self.active, self.visible = false, false
		return false
	end

	local path = "icons/" .. icon
	if paths.getImage(path) then
		self.char = icon
	else
		path = "icons/" .. HealthIcon.defaultIcon
		self.char = HealthIcon.defaultIcon
	end

	local hasOldSuffix = icon:endsWith("-old")
	self.isPixelIcon = icon:endsWith("-pixel") or
		(hasOldSuffix and icon:sub(1, -5):endsWith("-pixel"))
	self.isOldIcon = hasOldSuffix or
		(self.isPixelIcon and icon:sub(1, -7):endsWith("-old"))

	local isSparrow = paths.exists(paths.getPath("images/" .. path .. ".xml"), "file")
	self.isLegacyStyle = not isSparrow and not paths.exists(paths.getPath("images/" .. path .. ".txt"), "file")
	self.animation:reset()
	if self.isLegacyStyle then
		self:loadTexture(paths.getImage(path))
		if math.round(self.width / self.height) > 1 then
			self:loadTexture(self.texture, true,
				math.floor(self.width / 2),
				math.floor(self.height))
			self.animation:add("i", {0, 1}, 0)
			self.animation:play("i")
		end

		self.iconOffset = {x = (self.width - 150) / 2, y = (self.height - 150) / 2}

		local zoom = self.isPixelIcon and 150 / self.height or 1
		self.zoom.x, self.zoom.y = zoom, zoom
		self.antialiasing = zoom < 2.5 and self.antialiasing
		self:updateHitbox()
	else
		self:setFrames(isSparrow and paths.getSparrowAtlas(path) or paths.getPackerAtlas(path))

		self.animation:addByPrefix("idle", "idle", 24, true)
		self.animation:addByPrefix("winning", "winning", 24, true)
		self.animation:addByPrefix("losing", "losing", 24, true)
		self.animation:addByPrefix("toWinning", "toWinning", 24, false)
		self.animation:addByPrefix("toLosing", "toLosing", 24, false)
		self.animation:addByPrefix("fromWinning", "fromWinning", 24, false)
		self.animation:addByPrefix("fromLosing", "fromLosing", 24, false)
	end

	self:updateAnimation()
	if not self.isLegacyStyle
		and self.curAnim
		and not self.curAnim.looped then
		self:finish()
	end

	return true
end

function HealthIcon:fallbackPlay(anim, fallback)
	self.animation:play(self.animation:has(anim) and anim or fallback)
	end

function HealthIcon:setScale(scale)
	if self.isLegacyStyle then
		self.scale:set(scale, scale)
	else
		self.scale:set(1, 1)
	end
	-- self:updateHitbox()
end

function HealthIcon:fixOffsets(width, height)
	if self.isLegacyStyle and self.iconOffset then
		self.offset.x, self.offset.y = self.iconOffset.x, self.iconOffset.y
	else
		HealthIcon.super.fixOffsets(self, width, height)
	end
end

function HealthIcon:update(dt)
	HealthIcon.super.update(self, dt)
	self:updateAnimation()
	if self.sprTracker then
		self:setPosition(self.sprTracker.x + self.sprTracker:getWidth() + 10,
			self.sprTracker.y - 30)
	end
end

return HealthIcon
