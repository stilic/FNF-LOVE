local Modcard = SpriteGroup:extend("Modcard")

function Modcard:new(x)
	Modcard.super.new(self, 0, 0)

	self.bg = Sprite(0, 0, paths.getImage("menus/modding/modcardBG", true))
	self.bg:updateHitbox()
	self:add(self.bg)

	self.overlay = Sprite(0, 0, paths.getImage("menus/modding/modcardCHECK", true))
	self.overlay:updateHitbox()
	self:add(self.overlay)

	self.image = Sprite(18, 6, Mods.getIcon(""))
	self.image:setGraphicSize(44, 44)
	self.image.antialiasing = false
	self.image:updateHitbox()
	self:add(self.image)

	self.text = Marquee(82, 2, 190, 48, "?", paths.getFont("vcr.ttf", 30), Color.WHITE)
	self.text.antialiasing = false
	self:add(self.text)

	self.image:center(self.bg, "y")
	self.text:center(self.bg, "y")

	self:updateHitbox()
end

function Modcard:reload(x, mod, type)
	self.mod = mod
	self.type = type

	local md = type == "addon" and Addons or Mods
	local data = md.getMetadata(mod)

	self.meta = data

	self.image:loadTexture(md.getIcon(mod))
	self.image:setGraphicSize(44, 44)
	self.image:updateHitbox()

	self.text.content = data.name
	self.text:__updateDimension()

	self.image:center(self.bg, "y")
	self.text:center(self.bg, "y")

	self:updateHitbox()
end

local black, white = Color.BLACK, Color.WHITE
local lime, red = Color.LIME, Color.RED
function Modcard:update(dt)
	Modcard.super.update(self, dt)

	local check, color
	if self.type == "addon" then
		check = self.mod.active
	else
		check = self.mod == Mods.currentMod
	end

	color = check and lime or red
	self.text.color = Color.lerpDelta(self.text.color, self.selected and black or white, 16, dt)
	self.overlay.color = Color.lerpDelta(self.overlay.color, color, 16, dt)
	self.bg.color = Color.lerpDelta(self.bg.color, self.selected and white or black, 16, dt)
	self.alpha = util.coolLerp(self.alpha, self.selected and 1 or 0.5, 16, dt)
end

function Modcard:__render(camera)
	for _, member in ipairs(self.members) do
		member.skew = self.skew
	end
	Modcard.super.__render(self, camera)
end

return Modcard
