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

	if d.icon:startsWith("https://") then
		self.icon:loadTexture(paths.getImage("menus/credits/icons/loading"))

		local icon = d.icon .. "?size=100"
		self.icon.loading = icon
		paths.async.getImage(icon, bind(self, self.__reloadIcon))
	else
		self.icon:loadTexture(paths.getImage("menus/credits/icons/" .. d.icon))
	end
	self.icon.angle = 0
	self.icon:setGraphicSize(100, 100)
	self.icon:updateHitbox()

	self:reloadSocials(d)
	self.box.height = (game.height - 130) - (self.media:getHeight())
	if #self.media.members > 0 then self.box.height = self.box.height - 10 end
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

return UserCard
