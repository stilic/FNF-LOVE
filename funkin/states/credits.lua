local CreditsState = State:extend("CreditsState")

local UserList = require "funkin.ui.credits.userlist"
local UserCard = require "funkin.ui.credits.usercard"

local function category(header, people)
	return { header = header, credits = people }
end

local function user(name, icon, color, description, ...)
	local socials = {}
	for i = 1, select("#", ...), 2 do
		local platform = select(i, ...)
		local handle   = select(i + 1, ...)
		socials[#socials + 1] = {name = platform, text = handle}
	end
	return {name = name, icon = icon, color = color, description = description, social = socials}
end

CreditsState.defaultData = {
	category("Contributors", {
		user("Stilic", "https://github.com/stilic.png", "#FFCA45", "Main director and programmer",
			"X", "@stilic_dev",
			"Github", "/Stilic"
		),
		user("Raltyro", "https://github.com/raltyro.png", "#FF4545", "Artist and programmer",
			"X", "@raltyro",
			"Youtube", "@Raltyro",
			"Github", "/Raltyro"
		),
		user("Fellyn", "https://github.com/yuk1r4luvyu.png", "#E49CFA", "Composer of \"Railways\", programmer and logo creator",
			"X", "@FellynnLol_",
			"Youtube", "@FellynnMusic_",
			"Github", "/FellynYukira"
		),
		user("MrMeep64", "https://github.com/Arm4GeDon.png", "#D1794D", "V-Slice content porting and programmer"),
		user("TehPuertoRicanSpartan", "https://github.com/TehPuertoRicanSpartan.png", "#D1794D", "V-Slice content porting and programmer"),
		user("Victor Kaoy", "@x:vk15_", "#D1794D", "Artist and programmer",
			"X", "@vk15_",
			"Github", "/ViKaoy"
		),
		user("Blue Colorsin",           "https://github.com/bluecolorsin.png",           "#2B56FF", "Programmer",
			"X", "@BlueColorsin",
			"Youtube", "@BlueColorsin",
			"Github", "/BlueColorsin"
		),
		user("FowluhhDev", "https://github.com/fowluhhdevbcfunny.png", "#383838", "Programmer"),
	}),

	category("The Funkin' Crew Inc.", {
		user("Ninjamuffin99", "@x:ninja_muffin99", "#FF392B", "Shareholder / Programmer",
			"X", "@ninja_muffin99", "Github", "/ninjamuffin99"),
		user("Phantom Arcade", "@x:PhantomArcade3k", "#EBC73B", "Shareholder / Animator",
			"X", "@PhantomArcade3K", "Youtube", "@PhantomArcade"),
		user("Kawai Sprite", "@x:kawaisprite", "#4185FA", "Shareholder / Musician",
			"X", "@kawaisprite", "Youtube", "@KawaiSprite"),
		user("EvilSk8r", "@x:evilsk8r", "#5EED3E", "Shareholder / Artist",
			"X", "@evilsk8r"),
	}),

	category("Direction and Art Lead", {
		user("PhantomArcade", "", "#EBC73B", "Direction and Art Lead"),
	}),

	category("Music Lead", {
		user("Isaac “Kawai Sprite” Garcia", "", "#4185FA", "Music Lead"),
	}),

	category("Co-Direction and Programming Lead", {
		user("ninjamuffin99", "", "#FF392B", "Co-Direction and Programming Lead"),
	}),

	category("Mobile Lead", {
		user("MoonDroid (Zack)", "", "#FFFFFF", "Mobile Lead"),
	}),

	category("Production Manager", {
		user("Hundrec", "", "#FFFFFF", "Production Manager"),
	}),

	category("Team Organizers", {
		user("Hundrec", "", "#FFFFFF", "Team Organizer"),
		user("AbnormalPoof", "", "#FFFFFF", "Team Organizer"),
	}),

	category("Producer", {
		user("Kawa Teaño", "", "#FFFFFF", "Producer"),
	}),

	category("Artists", {
		user("PhantomArcade", "", "#EBC73B", "Artist"),
		user("evilsk8r", "", "#5EED3E", "Artist"),
		user("beck", "", "#FFFFFF", "Artist"),
	}),

	category("Pixel Art", {
		user("moawling", "", "#FFFFFF", "Pixel Art"),
		user("IGJHSpritin", "", "#FFFFFF", "Pixel Art"),
	}),

	category("Cutscene Storyboards & SFX", {
		user("PhantomArcade", "", "#EBC73B", "Storyboards & SFX"),
	}),

	category("Additional Background Design", {
		user("Red Minus", "", "#FFFFFF", "Background Design"),
	}),

	category("Cutscene Animation", {
		user("Figburn", "", "#FFFFFF", "Animation"),
		user("Sade", "", "#FFFFFF", "Animation"),
		user("Topium", "", "#FFFFFF", "Animation"),
		user("BlairTheUnseriousGuy", "", "#FFFFFF", "Animation"),
	}),

	category("Cutscene Cleanup", {
		user("PennilessRagamuffin", "", "#FFFFFF", "Cleanup"),
		user("beck", "", "#FFFFFF", "Cleanup"),
	}),

	category("Cutscene Background Art", {
		user("beck", "", "#FFFFFF", "Background Art"),
	}),

	category("Additional Art", {
		user("Jeff Bandelin", "", "#FFFFFF", "Additional Art"),
		user("Mogy64", "", "#FFFFFF", "Additional Art"),
		user("ChipsGoWoah", "", "#FFFFFF", "Additional Art"),
		user("Min Ho Kim (Deegeemin)", "", "#FFFFFF", "Additional Art"),
		user("PKettles", "", "#FFFFFF", "Additional Art"),
		user("peepo173", "", "#FFFFFF", "Additional Art"),
	}),

	category("Additional Character Design", {
		user("Tom Fulp", "", "#FFFFFF", "Pico School Characters"),
		user("JohnnyUtah", "", "#FFFFFF", "Tankman"),
		user("SrPelo", "", "#FFFFFF", "Skid and Pump"),
		user("Magna", "", "#FFFFFF", "Otis"),
		user("gacktenzo", "", "#FFFFFF", "Preppy Otis"),
	}),

	category("Music Production", {
		user("Saruky", "", "#FFFFFF", "Music Production"),
		user("crisp", "", "#FFFFFF", "Music Production"),
	}),

	category("Featured Guest Musicians", {
		user("Bassetfilms", "", "#FFFFFF", "Guest Musician"),
		user("Kohta Takahashi", "", "#FFFFFF", "Guest Musician"),
		user("Lotus Juice", "", "#FFFFFF", "Guest Musician"),
		user("METAROOM", "", "#FFFFFF", "Guest Musician"),
		user("nuphory", "", "#FFFFFF", "Guest Musician"),
		user("Saster", "", "#FFFFFF", "Guest Musician"),
		user("six impala", "", "#FFFFFF", "Guest Musician"),
		user("TeraVex", "", "#FFFFFF", "Guest Musician"),
		user("That Andy Guy", "", "#FFFFFF", "Guest Musician"),
		user("tsuyunoshi", "", "#FFFFFF", "Guest Musician"),
		user("Xploshi", "", "#FFFFFF", "Guest Musician"),
		user("Tee Lopes", "", "#FFFFFF", "Guest Musician"),
		user("RRThiel", "", "#FFFFFF", "Guest Musician"),
	}),

	category("Programming", {
		user("Eric \"EliteMasterEric\" Myllyoja", "", "#FFFFFF", "Programming"),
		user("fabs", "", "#FFFFFF", "Programming"),
		user("KadeDev", "", "#FFFFFF", "Programming"),
	}),

	category("Additional Programming", {
		user("Jenny Crowe", "", "#FFFFFF", "Additional Programming"),
		user("ember ana", "", "#FFFFFF", "Additional Programming"),
		user("Mike Welsh", "", "#FFFFFF", "Additional Programming"),
		user("Saharan", "", "#FFFFFF", "Additional Programming"),
		user("Ian Harrigan", "", "#FFFFFF", "Additional Programming"),
		user("Thomas J Webb", "", "#FFFFFF", "Osaka Red LLC"),
		user("Emma (MtH)", "", "#FFFFFF", "Additional Programming"),
		user("George Kurelic", "", "#FFFFFF", "Additional Programming"),
		user("Will Blanton", "", "#FFFFFF", "Additional Programming"),
		user("Victor - Cheemsandfriends", "", "#FFFFFF", "Additional Programming"),
		user("Hundrec", "", "#FFFFFF", "Additional Programming"),
		user("AbnormalPoof", "", "#FFFFFF", "Additional Programming"),
		user("MaybeMaru", "", "#FFFFFF", "Additional Programming"),
	}),

	category("Mobile Porting", {
		user("MAJigsaw77", "", "#FFFFFF", "Mobile Porting"),
		user("Luckydog7", "", "#FFFFFF", "Mobile Porting"),
		user("Karim Akra", "", "#FFFFFF", "Mobile Porting"),
		user("sector_5", "", "#FFFFFF", "Mobile Porting"),
	}),

	category("Devops and Tooling", {
		user("ember ana", "", "#FFFFFF", "Devops and Tooling"),
	}),

	category("Gameplay Design", {
		user("PhantomArcade", "", "#EBC73B", "Gameplay Design"),
		user("Cameron Taylor", "", "#FF392B", "Gameplay Design"),
		user("Jenny Crowe", "", "#FFFFFF", "Gameplay Design"),
		user("Spazkid", "", "#FFFFFF", "Gameplay Design"),
		user("fabs", "", "#FFFFFF", "Gameplay Design"),
		user("Emma (MtH)", "", "#FFFFFF", "Gameplay Design"),
	}),

	category("Kickstarter Backer Portal", {
		user("Shingai Shamu", "", "#FFFFFF", "Portal Programming"),
	}),

	category("Merchandise Partners", {
		user("Jace McLain", "", "#FFFFFF", "Needlejuice Records"),
		user("Brandon Brown", "", "#FFFFFF", "Needlejuice Records"),
		user("Coby Win", "", "#FFFFFF", "Type-4"),
		user("IvanAlmighty", "", "#FFFFFF", "Merchandise"),
		user("Mogy64", "", "#FFFFFF", "Merchandise"),
		user("ChipsGoWoah", "", "#FFFFFF", "Merchandise"),
		user("Min Ho Kim", "", "#FFFFFF", "Merchandise"),
		user("PKettles", "", "#FFFFFF", "Merchandise"),
		user("Jeff Bandelin", "", "#FFFFFF", "Merchandise"),
		user("PhantomArcade", "", "#EBC73B", "Merchandise"),
		user("evilsk8r", "", "#5EED3E", "Merchandise"),
		user("beck", "", "#FFFFFF", "Merchandise"),
		user("Seebs", "", "#FFFFFF", "Makeship"),
		user("Anna N", "", "#FFFFFF", "Makeship"),
	}),

	category("Production and BizDev", {
		user("Sunni Pavlovic", "", "#FFFFFF", "Windflower Games"),
		user("Kristen Lynch", "", "#FFFFFF", "Windflower Games"),
	}),

	category("Admin Assistance", {
		user("moawling", "", "#FFFFFF", "Administrative Assistance"),
	}),

	category("Quality Assurance", {
		user("Mihajlo Vuković", "", "#FFFFFF", "Lead Tester: Indium Play"),
		user("Andrej Naumovski", "", "#FFFFFF", "Tester: Indium Play"),
		user("Dajana Dimovska", "", "#FFFFFF", "Indium Play"),
	}),

	category("Accounting", {
		user("Francis Molinari", "", "#FFFFFF", "Molinari Oswald"),
		user("Aaron Hofmann", "", "#FFFFFF", "Molinari Oswald"),
		user("Katherine Stauffer", "", "#FFFFFF", "Molinari Oswald"),
		user("Jane Haring", "", "#FFFFFF", "Molinari Oswald"),
	}),

	category("US Legal: Odin Law", {
		user("Brandon Huffman", "", "#FFFFFF", "Odin Law"),
		user("Michele Robichaux", "", "#FFFFFF", "Odin Law"),
		user("Connor Richards", "", "#FFFFFF", "Odin Law"),
		user("Pam Driver", "", "#FFFFFF", "Odin Law"),
		user("Jacob Barefoot", "", "#FFFFFF", "Odin Law"),
	}),

	category("CA Legal: DLA Piper", {
		user("Ryan Black", "", "#FFFFFF", "DLA Piper"),
		user("Brian Wong", "", "#FFFFFF", "DLA Piper"),
	}),
}

function CreditsState:enter()
	CreditsState.super.enter(self)

	if Discord then
		Discord.changePresence({details = "In the Menus", state = "Credits"})
	end

	self.data = {}

	self.lastHeight = 0
	self.curSelected = 1
	self.curTab = 1

	self.camFollow = {x = game.width / 2, y = game.height / 2}
	game.camera:follow(self.camFollow, nil, 8)
	game.camera:snapToTarget()

	self.bg = Sprite(0, 0, paths.getImage("menus/menuDesat"))
	self:add(util.responsiveBG(self.bg))

	self.bd = BackDrop(128)
	self.bd.moves = true
	self.bd.velocity:set(26, 26)
	self.bd.scrollFactor:set()
	self.bd.alpha = 0.5
	self:add(self.bd)

	local creditsMod = paths.getJSON('data/credits')
	if creditsMod then
		for i = 1, #creditsMod do table.insert(self.data, creditsMod[i]) end
	end
	for i = 1, #self.defaultData do
		table.insert(self.data, self.defaultData[i])
	end

	self.userList = UserList(self.data, game.width * 0.3)
	self.userList.parent = self
	self:add(self.userList)

	self.userCard = UserCard(10 + self.userList:getWidth() + 10, 10,
		game.width - self.userList:getWidth() - 30, game.height - 130)
	self.userCard.scrollFactor:set()
	self:add(self.userCard)

	self:changeSelection()

	local colorBG = Color.fromString(self.userList:getSelected().color or "#DF7B29")
	self.bg.color = colorBG
	self.bd.color = Color.saturate(self.bg.color, 0.4)

	self.throttles = {}
	self.throttles.up = Throttle:make({controls.down, controls, "ui_up"})
	self.throttles.down = Throttle:make({controls.down, controls, "ui_down"})

	if love.system.getDevice() == "Mobile" then
		self.buttons = VirtualPadGroup()
		local w = 134

		local down = VirtualPad("down", 0, game.height - w)
		local up = VirtualPad("up", 0, down.y - w)

		self.buttons:add(down)
		self.buttons:add(up)

		self:add(self.buttons)
	end
end

function CreditsState:update(dt)
	CreditsState.super.update(self, dt)

	if self.userCard.onSocials then
		if self.throttles.up:check() then
			util.playSfx(paths.getSound('scrollMenu'))
			self.userCard:changeSocialSelection(-1)
		end
		if self.throttles.down:check() then
			util.playSfx(paths.getSound('scrollMenu'))
			self.userCard:changeSocialSelection(1)
		end

		if controls:pressed("back") then
			util.playSfx(paths.getSound('cancelMenu'))
			self.userCard:exitSocials()
		end

		if controls:pressed("accept") then
			local url = self.userCard:getSelectedSocialUrl()
			if url then
				love.system.openURL(url)
			end
		end
	else
		if self.throttles then
			if self.throttles.up:check() then self:changeSelection(-1) end
			if self.throttles.down:check() then self:changeSelection(1) end
		end

		if controls:pressed("back") then
			util.playSfx(paths.getSound('cancelMenu'))
			game.switchState(MainMenuState())
		end

		if controls:pressed("accept") then
			if self.userCard:enterSocials() then
				util.playSfx(paths.getSound('scrollMenu'))
			end
		end
	end

	local u = self.userList
	if u.bar.y > game.camera.scroll.y + game.height - u.bar.height then
		self.camFollow.y = u.bar.y - game.height / 2 + 84
	elseif u.bar.y < self.camFollow.y - game.height / 2 + 74 then
		self.camFollow.y = u.bar.y + game.height / 2 - 84
	end

	local colorBG = Color.fromString(self.userList:getSelected().color or "#DF7B29")
	self.bg.color = Color.lerpDelta(self.bg.color, colorBG, 3, dt)
	self.bd.color = Color.saturate(self.bg.color, 0.4)
end

function CreditsState:changeSelection(n)
	if n == nil then n = 0 end
	util.playSfx(paths.getSound('scrollMenu'))

	self.userList:changeSelection(n)
	self.userCard:reload(self.userList:getSelected())
end

return CreditsState
