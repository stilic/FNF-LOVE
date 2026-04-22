local UserCard = SpriteGroup:extend("UserCard")
local MediaCard = require "funkin.ui.credits.mediacard"

function UserCard:new(x, y, width, height)
	UserCard.super.new(self, x, y)

	self.icon = Sprite(0, 0)
	self.icon:setGraphicSize(100)
	self.icon:updateHitbox()
	self.icon.scrollFactor:set()
	self:add(self.icon)

	self.name = Text(self.icon.x + self.icon.width + 10, 0, "Name",
		paths.getFont("phantommuff.ttf", 75))
	self.name:setOutline("normal", 4)
	self.name.y = 10 + (self.icon.height - self.name:getHeight()) / 2
	self.name.antialiasing = false
	self.name.scrollFactor:set()
	self:add(self.name)

	self.box = Graphic(
		self.icon.x, self.icon.y + self.icon.height + 10, width, height, Color.fromRGB(10, 12, 26))
	self.box.alpha = 0.4
	self.box.config.round = {24, 24}
	self.box.scrollFactor:set()
	self:add(self.box)

	self.desc = Text(
		self.box.x + 10, self.box.y + 10, "Description",
		paths.getFont("vcr.ttf", 32), nil, nil, self.box.width - 20)
	self.desc.antialiasing = false
	self.desc.scrollFactor:set()
	self:add(self.desc)

	self.media = SpriteGroup(0, self.box.y)
	self.media.scrollFactor:set()
	self:add(self.media)

	self.curSocial = 1
	self.onSocials = false
end

function UserCard:update(dt)
	UserCard.super.update(self, dt)
	if self.icon.loading then
		self.icon.angle = self.icon.angle + 380 * dt
	end
end

function UserCard:__reloadIcon(image, url, error)
	if self.icon.loading ~= url then return end
	self.icon.loading = nil
	self.icon.angle = 0
	self.icon:loadTexture(image)
	self.icon:setGraphicSize(100, 100)
	self.icon:updateHitbox()
end

function UserCard:reload(d)
	self.data = d

	self.name.content = d.name
	self.desc.content = d.description
	self.name:centerOrigin()
	self.name.scale.x = 1

	if self.name:getWidth() > game.width - self.x - 250 then
		local factor = game.width / (self.name:getWidth() + self.x + 250)
		self.name.origin.x = 0
		self.name.scale.x = factor
	end

	self.icon.loading = nil

	if d.icon and d.icon ~= "" then
		self.icon.visible = true

		if d.icon:startsWith("https://") or d.icon:startsWith("@") then
			self.icon:loadTexture(paths.getImage("menus/credits/icons/loading"))

			local icon
			if d.icon:startsWith("@") then
				local clean = d.icon:sub(2)
				local platform, handle
				platform, handle = clean:match("([^:]+):(.+)")
				if platform and handle then
					local apiURL = string.format("https://unavatar.io/%s/%s?fallback=false", platform, handle)
					icon = string.format("https://wsrv.nl/?output=png&maxage=1d&w=128&q=100&url=%s", apiURL)
				end
			else
				icon = d.icon .. "?size=128"
			end

			self.icon.loading = icon
			paths.async.getImage(icon, bind(self, self.__reloadIcon))
		else
			self.icon:loadTexture(paths.getImage("menus/credits/icons/" .. d.icon))
		end
		self.icon.angle = 0
		self.icon:setGraphicSize(100, 100)
		self.icon:updateHitbox()
		self.name.x = self.icon.x + self.icon.width + 10
	else
		self.icon.visible = false
		self.name.x = self.icon.x
	end

	self:reloadSocials(d)
	self.box.height = (game.height - 130) - (self.media:getHeight())
	if #self.media.members > 0 then self.box.height = self.box.height - 10 end

	self.curSocial = 1
	self.onSocials = false
end

function UserCard:reloadSocials(person)
	self.media:clear()

	local font = paths.getFont("vcr.ttf", 34)

	local function makeThing(name, icon, i)
		local img = Sprite(0, 0, paths.getImage("menus/credits/social/" .. icon))
		img:setGraphicSize(img.width, 42)
		img:updateHitbox()

		local txt = Marquee(500, 500,
			self.box.width - 130, 40, name, font)
		txt.y = img.y + (img.height - txt:getHeight()) / 2
		txt.antialiasing = false

		local card = MediaCard(0, 72 * i, img, txt, Color.fromRGB(10, 12, 26))
		card.alpha = 0.4
		card:setSize(self.box.width, 62)
		card.scrollFactor:set()
		self.media:add(card)
	end

	if person.social then
		for i = #person.social, 1, -1 do
			local social = person.social[i]
			makeThing(social.text, social.name:lower(), #person.social - i)
		end
	end
	self.media.y = game.height - self.media:getHeight() - 20
end

function UserCard:enterSocials()
	if #self.media.members == 0 then return false end
	self.onSocials = true
	self.curSocial = 1
	self:updateSocialFocus()
	return true
end

function UserCard:exitSocials()
	self.onSocials = false
	self:updateSocialFocus()
end

function UserCard:changeSocialSelection(change)
	if not self.onSocials then return end
	self.curSocial = self.curSocial + change
	if self.curSocial > #self.media.members then self.curSocial = 1 end
	if self.curSocial < 1 then self.curSocial = #self.media.members end
	self:updateSocialFocus()
end

function UserCard:updateSocialFocus()
	for i, card in ipairs(self.media.members) do
		card:setFocus(self.onSocials and i == self.curSocial)
	end
end

function UserCard:getSelectedSocialUrl()
	if not self.data or not self.data.social then return nil end

	local socialList = self.data.social
	local index = #socialList - (self.curSocial - 1)
	local item = socialList[index]

	if item then
		return self:getURL(item.name, item.text)
	end
	return nil
end

function UserCard:getURL(platform, handle)
	platform = platform:lower()
	if platform == "x" or platform == "twitter" then
		return "https://twitter.com/" .. handle:gsub("@", "")
	elseif platform == "github" then
		return "https://github.com" .. handle
	elseif platform == "youtube" then
		return "https://youtube.com/" .. handle
	end
	return nil
end

return UserCard
