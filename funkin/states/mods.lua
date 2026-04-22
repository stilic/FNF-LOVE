local SelectionList = require "funkin.ui.mods.selectionlist"
local ModsState = State:extend("ModsState")

local info = "Hold Accept to move addons - Press Left/Right to change tabs"

function ModsState:enter()
	ModsState.super.enter(self)

	Addons.reload()
	Mods.reload()

	self.initialMod = Mods.currentMod
	if Discord then
		Discord.changePresence({details = "In the Menus", state = "Mods Menu"})
	end

	self.bg = Sprite(0, 0, paths.getImage("menus/menuDesat"))
	self:add(util.responsiveBG(self.bg))

	self.bd = BackDrop(128)
	self.bd.moves = true
	self.bd.velocity:set(26, 26)
	self.bd.scrollFactor:set()
	self.bd.alpha = 0.5
	self:add(self.bd)

	self.curColor = Color.WHITE

	self.info = Text(24, game.height - 18, info, paths.getFont("vcr.ttf", 16))
	self.info.antialiasing = false
	self.info.outline.width = 1
	self:add(self.info)

	self.tabBG = Graphic(20, 10, 384, 70)
	self.tabBG.config.round = {16, 16}
	self.tabBG.alpha = 0.6
	self:add(self.tabBG)

	self.tabText = Text(20, 30, "< Mods >",
		paths.getFont('vcr.ttf', 30), Color.WHITE, 'center', 384)
	self.tabText:setOutline("default", 4, nil, Color.BLACK)
	self.tabText.antialiasing = false
	self:add(self.tabText)

	self.modsTab = SelectionList(20, 90, 384, game.height - 110)
	self.modsTab.name = "Mods"
	self.modsTab:insertContent(Mods.all)
	self:add(self.modsTab)

	if Mods.currentMod then
		for i, m in ipairs(self.modsTab.list.members) do
			if m.mod == Mods.currentMod then
				self.modsTab.curSelected = i
				break
			end
		end
	end

	self.addonsTab = SelectionList(20, 90, 384, game.height - 110)
	self.addonsTab.name = "Add-ons"
	self.addonsTab:insertContent(Addons.all, "addon")
	self.addonsTab.visible = false
	self:add(self.addonsTab)

	self.tabs = {self.modsTab, self.addonsTab}

	self.cardGroup = SpriteGroup(424, 10)
	self:add(self.cardGroup)

	self.banner = Sprite(0, 0)
	self.cardGroup:add(self.banner)

	self.bannerEffect = SpriteGroup(0, 0)
	self.cardGroup:add(self.bannerEffect)

	self.descBG = Graphic(0, 0, 836, 0)
	self.descBG.alpha = 0.65
	self.descBG.config.round = {18, 18}
	self.cardGroup:add(self.descBG)

	local font = AtlasText.getFont("default-white", 0.4)
	self.desc = AtlasText(20, 0, "", font, 806, "left")
	self.cardGroup:add(self.desc)

	self.versionBox = Graphic(0, 0, 836, 50)
	self.versionBox.alpha = 0.71
	self.versionBox.config.round = {15, 15}
	self.cardGroup:add(self.versionBox)

	self.versionText = Text(20, 0, "Version: 1", paths.getFont("vcr.ttf", 18),
		Color.WHITE, "left", 806)
	self.versionText.antialiasing = false
	self.cardGroup:add(self.versionText)

	self.noContent = AtlasText(0, game.height / 2.2, "No content!",
		AtlasText.getFont("bold", 0.6))
	self.noContent:center(self.cardGroup, "x")
	self:add(self.noContent)

	self.curTab = self.modsTab
	self.onAddons = false

	self.timer = 0

	self.throttles = {
		up = Throttle:make({controls.down, controls, "ui_up"}),
		down = Throttle:make({controls.down, controls, "ui_down"})
	}

	if love.system.getDevice() == "Mobile" then
		self.buttons = util.createButtons("lrudab")
		self:add(self.buttons)
	end

	self:reloadInfo()

	self.descBG.y = self.banner.y + self.banner.height + 10
	self.descBG.height = game.height - self.banner.height - 100
	self.desc.y = self.descBG.y + 20
	self.bg.color = self.curColor
	self.bd.color = Color.saturate(self.bg.color, 0.4)
end

local colorBlack, colorRed = Color.BLACK, Color.RED
function ModsState:update(dt)
	ModsState.super.update(self, dt)

	self.bg.color = Color.lerpDelta(self.bg.color, self.curColor, 3, dt)
	self.bd.color = Color.saturate(self.bg.color, 0.4)

	if controls:pressed("back") and not self.leaving then
		if Mods.currentMod ~= self.initialMod then
			ClientPrefs.save.data.currentMod = Mods.currentMod
			local volume = ClientPrefs.data.menuMusicVolume
			if game.sound.music then game.sound.music:fade(1.5, volume / 100, 0) end
			TitleState.initialized = false
			Tween.tween(game.camera, {zoom = 1.15, alpha = 0}, 1.5, {ease = "sineIn", onComplete = function()
				if game.sound.music then game.sound.music:stop() end
				Timer.wait(1, function()
					util.setEnvironment()
					-- GlobalScripts.reload()
					ClientPrefs.saveData()
					game.switchState(TitleState(), true)
				end)
			end})
		else
			game.switchState(MainMenuState())
		end
		self.leaving = true
	end

	self.descBG.y = util.coolLerp(self.descBG.y,
		self.banner.y + self.banner.height + 10, 10, dt)
	self.descBG.height = util.coolLerp(self.descBG.height,
		game.height - self.banner.height - 100, 10, dt)
	self.desc.y = self.descBG.y + 20

	if self.leaving or self.inEffect then return end

	local color = colorBlack
	local curSelect = self.curTab:getSelected()
	if controls:released("accept") then
		self:enterSelection()
	elseif self.onAddons and controls:down("accept") then
		self.timer = self.timer + dt
		if self.timer >= 0.34 then
			self.moveIndex = true
			color = colorRed
		end
	else
		self.moveIndex = false
		self.timer = 0
	end
	self.curTab.bar.color = Color.lerpDelta(
		self.curTab.bar.color, color, 10, dt)

	for _, m in pairs(self.curTab.list.members) do
		if m == curSelect and self.moveIndex then
			m.scale.x = util.coolLerp(
				m.scale.x, 0.86, 8, dt)
		else
			m.scale.x = util.coolLerp(
				m.scale.x, 1, 8, dt)
		end
		m.scale.y = m.scale.x
	end

	if controls:pressed("ui_left") or controls:pressed("ui_right") then
		self.onAddons = not self.onAddons
		self.moveIndex = false
		self.inEffect = true
		util.playSfx(paths.getSound('scrollMenu'))
		self:swapTabs()
	elseif self.throttles.up:check() then
		self:changeSelection(-1)
	elseif self.throttles.down:check() then
		self:changeSelection(1)
	end
end

function ModsState:enterSelection()
	if #self.curTab.list.members < 1 then return end
	local cur = self.curTab:getSelected(true)
	if self.onAddons and not self.moveIndex then
		Addons.setState(cur, not cur.active)
		util.playSfx(paths.getSound(
			cur.active and 'confirmMenu' or 'cancelMenu'))
	elseif self.onAddons and self.moveIndex then
		util.playSfx(paths.getSound('scrollMenu'))
	elseif not self.onAddons then
		local equal = Mods.currentMod == cur
		Mods.currentMod = cur
		if equal then Mods.currentMod = nil end
		util.playSfx(paths.getSound(equal and 'cancelMenu' or 'confirmMenu'))
	end
end

function ModsState:changeSelection(n)
	if self.onAddons and self.moveIndex then
		if #self.curTab.list.members > 1 then
			util.playSfx(paths.getSound('beep'))
		end
		Addons.move(self.curTab:getSelected(true), n)
		self.curTab:moveMember(n)
	else
		if #self.curTab.list.members > 1 then
			util.playSfx(paths.getSound('scrollMenu'))
		end
		self.timer = 0
		self.curTab:changeSelection(n)
	end
	self:reloadInfo()
end

function ModsState:reloadInfo(addons, tab)
	local md = (addons or self.onAddons) and Addons or Mods
	tab = tab or self.curTab

	if #tab.list.members < 1 then
		self.noContent.visible = true
		self.curColor = Color.WHITE

		Tween.cancelTweensOf(self.cardGroup)
		Tween.cancelTweensOf(self.noContent)
		self.cardGroup.alpha = 1
		self.noContent.alpha = 0
		Tween.tween(self.cardGroup, {alpha = 0}, 0.1, {onComplete = function()
			self.cardGroup.visible = false
		end})
		Tween.tween(self.noContent, {alpha = 1}, 0.1)
		return
	else
		if self.noContent.visible then
			Tween.cancelTweensOf(self.cardGroup)
			Tween.cancelTweensOf(self.noContent)
			self.cardGroup.visible = true
			self.cardGroup.alpha = 0
			self.noContent.alpha = 1
			Tween.tween(self.cardGroup, {alpha = 1}, 0.1)
			Tween.tween(self.noContent, {alpha = 0}, 0.1, {onComplete = function()
				self.noContent.visible = false
			end})
		end
	end

	local meta = tab:getSelected().meta

	if self.banner.texture ~= Sprite.defaultTexture then
		local spr = self.bannerEffect:recycle()
		spr:loadTexture(self.banner.texture)
		spr:setGraphicSize(836)
		spr:updateHitbox()
		spr.alpha = 1
		Tween.tween(spr, {alpha = 0}, 0.16, {onComplete = function() spr:kill() end})
	end

	local texture = md.getBanner(tab:getSelected(true))
	self.banner:loadTexture(texture)
	self.banner:setGraphicSize(836)
	self.banner:updateHitbox()

	self.desc.text = meta.description

	local y = self.banner.y + self.banner.height + 10
	local h = game.height - self.banner.height - 100
	self.versionBox.y = y + h + 10
	self.versionText.content = "Version: " .. (meta.version or "unknown")
	self.versionText:center(self.versionBox)

	self.curColor = Color.fromString(meta.color)
end

function ModsState:swapTabs()
	local nextTab = self.onAddons and self.addonsTab or self.modsTab
	local curTab = self.onAddons and self.modsTab or self.addonsTab
	local toLeft = controls:down("ui_left")
	nextTab.x = toLeft and -200 or 200
	nextTab.alpha = 0
	nextTab.visible = true

	local textX = 20
	local textTargX = toLeft and -50 or 50
	Tween.tween(self.tabText, {x = textX - textTargX, alpha = 0}, 0.18, {
		ease = Ease.smoothStepIn,
		onComplete = function()
			self.tabText.x = textX + textTargX
			Tween.tween(self.tabText, {x = textX, alpha = 1}, 0.18, {
				ease = Ease.smoothStepOut
			})
		end
	})

	Tween.tween(curTab, {x = -(nextTab.x), alpha = 0}, 0.18, {
		ease = Ease.smoothStepIn,
		onComplete = function()
			curTab.visible = false
			self.tabText.content = "< " .. nextTab.name .. " >"
			self:reloadInfo(self.onAddons, nextTab)

			Tween.tween(nextTab, {x = 20, alpha = 1}, 0.2, {
				ease = Ease.smoothStepOut,
				onComplete = function()
					self.curTab = nextTab
					self.inEffect = false
				end
			})
		end
	})
end

return ModsState
