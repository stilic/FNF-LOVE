local util = {}

util.math = {}
util.device = {}

function util.math.coolLerp(x, y, i, delta)
	return math.lerp(y, x, math.exp(-(delta or game.dt) * i))
end

local time, clock, ms = "%d:%02d", "%d:%02d:%02d", "%.3f"
function util.math.formatTime(seconds, includeMS)
	local minutes = seconds / 60
	local str = minutes < 60 and time:format(minutes, seconds % 60) or
		clock:format(minutes / 60, minutes % 60, seconds % 60)
	if not includeMS then return str end
	return str .. ms:format(seconds - math.floor(seconds)):sub(2)
end

function util.math.formatNumber(number)
	if number < 1000 and number > -1000 then return tostring(number) end
	local _, _, minus, int, frac = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	return minus .. int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. frac
end

util.coolLerp = util.math.coolLerp
util.formatTime = util.math.formatTime
util.formatNumber = util.math.formatNumber

function util.device.wakelock(state)
	love.window.setDisplaySleepEnabled(not state)
end

function util.newGradient(dir, ...)
	local colorSize, meshData = select("#", ...) - 1, {}
	local off = dir:sub(1, 1):lower() == "v" and 1 or 2

	for i = 0, colorSize do
		local idx, color, x = i * 2 + 1, select(i + 1, ...), i / colorSize
		local r, g, b, a = color[1], color[2], color[3], color[4]
		a = a or 1

		meshData[idx] = {x, x, x, x, r, g, b, a}
		meshData[idx + 1] = {x, x, x, x, r, g, b, a}

		for o = off, off + 2, 2 do
			meshData[idx][o], meshData[idx + 1][o] = 1, 0
		end
	end

	return love.graphics.newMesh(meshData, "strip", "static")
end

function util.playMenuMusic(fade)
	local menu = paths.getMusic("freakyMenu")
	if not game.sound.music or not game.sound.music:isPlaying() or game.sound.music._source ~= menu then
		if game.sound.music then game.sound.music:reset(true) end
		game.sound.playMusic(menu, fade and 0 or ClientPrefs.data.menuMusicVolume / 100, true)
		if fade then game.sound.music:fade(4, 0, ClientPrefs.data.menuMusicVolume / 100) end
	end
end

function util.playSfx(asset, volume, ...)
	return game.sound.play(asset, (volume or 1) * ClientPrefs.data.sfxVolume / 100, ...)
end

-- menu thing
function util.responsiveBG(bg)
	local scale = math.max(game.width / bg.width, game.height / bg.height)
	bg:setGraphicSize(math.floor(bg.width * scale))
	bg:updateHitbox()
	bg:screenCenter()
	bg.scrollFactor:set()

	return bg
end

function util.createButtons(scheme, width)
	local buttons = VirtualPadGroup()
	local pad = ClientPrefs.data.margin

	local w = width or 126
	local y = game.height - w

	local l, r, u, d, a, b =
		scheme:find("l"), scheme:find("r"),
		scheme:find("u"), scheme:find("d"),
		scheme:find("a"), scheme:find("b")

	local lx = pad
	local mx = l and lx + w or pad
	local rx = l and ((u or d) and mx + w or w) or pad

	-- {char, name, x, y, color}
	local conf = {
		{"l", "left", lx, y},
		{"r", "right", rx, y},
		{"u", "up", mx, d and y - w or y},
		{"d", "down", mx, y},
		{"a", "return", game.width - w - pad, y, Color.LIME},
		{"b", "escape", a and (game.width - pad - w * 2) or (game.width - w - pad), y, Color.RED}
	}

	for _, config in ipairs(conf) do
		local key, name, x, y, color = unpack(config)
		if scheme:find(key) then
			buttons:add(VirtualPad(name, x, y, w, w, color))
		end
	end

	return buttons
end

return util
