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

	local box = Graphic(x, y, self.box.width - 20, 60)
	box.y = self.lastHeight > 0 and self.lastHeight + 10 or box.y
	box.alpha = 0.4
	box.config.round = {18, 18}
	box.scrollFactor:set(0, 1)
	self:add(box)

	local title = Text(x + 10, y + 8, name or "Unknown", font)
	title.y = box.y + (box.height - title:getHeight()) / 2
	title.limit = box.width - 20
	title.scrollFactor:set(0, 1)
	title.alignment = "center"
	title.antialiasing = false
	self:add(title)

	local function makeCard(name, icon, i)
		local img, txt = Sprite(x + 10, box.y + (64 * i + 10))
		if icon:startsWith("https://") then
			img:loadTexture(paths.getImage("menus/credits/icons/loading"))
			img.loading = true

			icon = icon .. "?size=100"
			paths.async.getImage(icon, function(image, url)
				if url == icon then
					img.loading = nil
					img.angle = 0
					img:loadTexture(image)
					img:setGraphicSize(54, 54)
					img:updateHitbox()
					if txt and font then
						txt:setPosition(x + img.x + img.width + 10,
							img.y + (img.height - txt:getHeight()) / 2)
					end
				end
			end)
		else
			img:loadTexture(paths.getImage("menus/credits/icons/" .. icon))
		end

		img:setGraphicSize(54, 54)
		img:updateHitbox()
		img.scrollFactor:set(0, 1)
		self:add(img)

		txt = Marquee(x + img.x + img.width + 10, y,
			box.width - img.width - 50, 40, name, font)
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
	self.bar.x, self.bar.width = txt.x - 10, txt.limit + 20
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

	local currentList = self.curSelected
	for i = 1, self.curTab - 1 do
		currentList = currentList + #self.data[i].credits
	end

	self.bar.y = (94 - self.y) + 84 * (self.curTab - 1) + 64 * (currentList - 1)
end

function UserList:update(dt)
	UserList.super.update(self, dt)
	if self.parent then
		--;self.box.color = self.parent.bg.color
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
