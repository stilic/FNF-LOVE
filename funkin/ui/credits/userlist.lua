local UserList = SpriteGroup:extend("UserList")

function UserList:new(data, width)
	UserList.super.new(self, 10, 10)

	self.lastHeight = 0
	self.curSelected = 1
	self.curTab = 1
	self.data = data or {}

	local color = Color.fromRGB(10, 12, 26)
	self.box = Graphic(self.x, self.y, width, game.height - 20, color)
	self.box.config.round = {24, 24}
	self.box.alpha = 0.4
	self.box.scrollFactor:set()

	self.bar = Graphic(self.x, self.y, width - 20, 54, Color.WHITE)
	self.bar.alpha = 0.2
	self.bar.config.round = {16, 16}
	self.bar.scrollFactor:set(0, 1)
	self:add(self.bar)

	self._sectionHeights = {}

	for i = 1, #self.data do
		local header = self.data[i]
		self:addUsers(header.header, header.credits, i - 1)
	end

	self.selected = false
end

function UserList:getWidth() return self.box.width end

function UserList:addUsers(name, people, i)
	local x, y = self.x, self.y
	local font = paths.getFont("vcr.ttf", 36)

	local title = Text(x, y + 8, name or "Unknown", font)
	title.limit = self.box.width - 20
	title.scrollFactor:set(0, 1)
	title.alignment = "center"
	title.antialiasing = false

	local boxHeight = title:getHeight() + 20
	local box = Graphic(x, y, self.box.width - 20, boxHeight)
	box.y = self.lastHeight > 0 and self.lastHeight + 10 or box.y
	box.alpha = 0.4
	box.config.round = {18, 18}
	box.scrollFactor:set(0, 1)
	self:add(box)

	title.y = box.y + (box.height - title:getHeight()) / 2
	self:add(title)

	table.insert(self._sectionHeights, boxHeight)

	local function makeCard(name, icon, i)
		local hasIcon = icon and icon ~= ""
		local img, txt = Sprite(x + 10, box.y + (box.height + (64 * (i - 1)) + 10))

		if hasIcon then
			if icon:startsWith("https://") or icon:startsWith("@") then
				img:loadTexture(paths.getImage("menus/credits/icons/loading"))
				img.loading = true

				local finalURL = icon

				if icon:startsWith("@") then
					local clean = icon:sub(2)
					local platform, handle = clean:match("([^:]+):(.+)")

					if platform and handle then
						local apiURL = string.format("https://unavatar.io/%s/%s?fallback=false", platform, handle)
						finalURL = string.format("https://wsrv.nl/?output=png&maxage=1d&w=128&q=100&url=%s", apiURL)
					else
						finalURL = nil
					end
				else
					finalURL = icon .. "?size=128"
				end

				if finalURL then
					paths.async.getImage(finalURL, function(image, url)
						if url == finalURL then
							img.loading = nil
							img.angle = 0
							if image then
								img:loadTexture(image)
								img:setGraphicSize(54, 54)
								img:updateHitbox()
								if txt and font then
									txt:setPosition(x + img.x + img.width + 10,
										img.y + (img.height - txt:getHeight()) / 2)
								end
							end
						end
					end)
				else
					img.loading = nil
				end
			else
				img:loadTexture(paths.getImage("menus/credits/icons/" .. icon))
			end
			img:setGraphicSize(54, 54)
		else
			img.visible = false
			img:setGraphicSize(0, 54)
		end

		img:updateHitbox()
		img.scrollFactor:set(0, 1)
		self:add(img)

		local textX = (img.visible and x + img.x + img.width or x + img.x) + (hasIcon and 10 or 0)
		local textWidth = box.width - (img.visible and img.width or 0) - (hasIcon and 50 or 40)

		txt = Marquee(textX, y, textWidth, 40, name, font)
		txt.y = img.y + (img.height - txt:getHeight()) / 2
		txt.scrollFactor:set(0, 1)
		txt.antialiasing = false
		self:add(txt)

		return img, txt
	end

	local img, txt
	for i = 1, #people do
		img, txt = makeCard(people[i].name, people[i].icon, i)
		self.lastHeight = img.y + img.height + 10
	end
end

function UserList:_prepareCameraDraw(c, force)
	local list = UserList.super._prepareCameraDraw(self, c, force)

	local scrollY = c.scroll and c.scroll.y or 0
	local clipTop = self.y + 10 - self.offset.y
	local clipBot = clipTop + self.box.height - 20

	local i = 1
	while i <= #list do
		local m = list[i]
		if m.y then
			local sf = m.scrollFactor and m.scrollFactor.y or 1
			local ey = m.y - scrollY * sf
			if ey + (m.height or 0) < clipTop or ey > clipBot then
				table.remove(list, i)
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end

	return list
end

function UserList:changeSelection(n)
	if self.selected then return end
	n = n or 0

	self.curSelected = self.curSelected + n

	if self.curSelected < 1 then
		self.curTab = (self.curTab - 2) % #self.data + 1
		self.curSelected = #self.data[self.curTab].credits
	elseif self.curSelected > #self.data[self.curTab].credits then
		self.curTab = self.curTab % #self.data + 1
		self.curSelected = 1
	end

	local user = self.data[self.curTab].credits[self.curSelected]
	local hasIcon = user.icon and user.icon ~= ""

	if hasIcon then
		self.bar.x = self.x + 74
		self.bar.width = self.box.width - 74 - 30
	else
		self.bar.x = self.x + 10
		self.bar.width = self.box.width - 40
	end

	local yPos = 0
	for t = 1, #self.data do
		local headHeight = self._sectionHeights[t] + 10

		if t == self.curTab then
			yPos = yPos + headHeight
			yPos = yPos + ((self.curSelected - 1) * 64)
			break
		else
			yPos = yPos + headHeight
			yPos = yPos + (#self.data[t].credits * 64) + 10
		end
	end
	self.bar.y = self.y + yPos
end

function UserList:update(dt)
	UserList.super.update(self, dt)
	if self.parent then
	end
	for _, member in pairs(self.members) do
		if member.loading then
			member.angle = member.angle + 380 * dt
		end
	end
end

function UserList:getSelected()
	return self.data[self.curTab].credits[self.curSelected]
end

function UserList:__render(c)
	local x, y, w, h = self.x + 10, self.y + 10, self.box.width - 20, self.box.height - 20
	x, y = x - self.offset.x, y - self.offset.y
	self.box:__render(c)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", x, y, w, h)
	end, "replace", 20)
	love.graphics.setStencilTest("equal", 20)
	UserList.super.__render(self, c)
	love.graphics.setStencilTest()
end

return UserList
