local Icon = loxreq "system.toast.icon"
local Toast = {instances = {}, pool = {}, width = 0, height = 0}
Toast.iconSize = 24
Toast.iconSpace = 30
Toast.scale = 1

Toast.showErrors = true
Toast.showDeprecations = true
Toast.showPrints = true

function Toast.init(width, height)
	Toast.width = width
	Toast.height = height
	Toast.scale = love.graphics.getFixedScale() * 1.15
	Toast.font = love.graphics.newFont(16 * Toast.scale)
	Toast.bigfont = love.graphics.newFont(20 * Toast.scale)
	Toast.visibleToasts = 0
	Toast.icons = {
		error = Icon.make(Toast.iconSize, "red", "error"),
		deprecated = Icon.make(Toast.iconSize, "yellow", "script")
	}
end

local clock = 0

local function getToast(text, icon, font, color)
	if not Toast.font then return end
	local n = #text
	font = font or (n < 14 and Toast.bigfont or Toast.font)

	local width = math.min(Toast.width - 24 * Toast.scale, font:getWidth(text))
	if icon then
		width = width + Toast.iconSpace * Toast.scale
	end

	local _, lines = font:getWrap(text, width - (icon and Toast.iconSpace * Toast.scale or 0))

	local t = table.remove(Toast.pool, 1)
	if t then
		t.text = text
		t.font = font
		t.timer = math.min(n * 0.11, 4)
		t.width = width
		t.height = font:getHeight() * #lines
		t.y = -font:getHeight() * #lines - 8
		t.lastclock = clock
		t.icon = icon
		t.color = color or 0xF5DCC4
	else
		t = {
			text = text,
			font = font,
			timer = math.min(n * 0.11, 4),
			width = width,
			height = font:getHeight() * #lines,
			y = -font:getHeight() * #lines - 8,
			lastclock = clock,
			icon = icon,
			color = color or 0xF5DCC4
		}
	end

	return t
end

local function handler(text, font, icon, color)
	for _, t in ipairs(Toast.instances) do
		local original = t.originalText or t.text
		if original == text and t.icon == icon then
			t.count = (t.count or 1) + 1
			t.originalText = original
			t.text = "(x" .. t.count .. ") " .. original
			t.timer = math.min(#original * 0.11, 4)
			t.lastclock = clock

			local newtext = t.text
			local font = t.font
			local width = math.min(Toast.width - 24 * Toast.scale, font:getWidth(newtext))
			if icon then
				width = width + Toast.iconSpace * Toast.scale
			end
			local _, lines = font:getWrap(newtext, width - (icon and Toast.iconSpace * Toast.scale or 0))
			t.width = width
			t.height = font:getHeight() * #lines

			return t
		end
	end
	local t = getToast(text, icon, font, color)
	if not t then return end
	t.originalText = text
	t.count = 1
	Toast.visibleToasts = Toast.visibleToasts + 1
	table.insert(Toast.instances, t)
	return t
end

function Toast.print(text, font)
	if not Toast.showPrints then return end
	return handler(text, font, nil, 0x2B1B1B)
end

function Toast.error(text, font)
	print(text)
	if not Toast.showErrors then return end
	return handler(text, font, Toast.icons.error, 0x9C2C3D)
end

function Toast.deprecated(text, font)
	print(text)
	if not Toast.showDeprecations then return end
	return handler(text, font, Toast.icons.deprecated, 0xC8671E)
end

function Toast:resize(width, height)
	self.width = width
	self.height = height

	for _, t in ipairs(self.instances) do
		local twidth = math.min(width - 24 * self.scale, t.font:getWidth(t.text))
		if t.icon then
			twidth = twidth + Toast.iconSpace * self.scale
		end
		local _, lines = t.font:getWrap(t.text, twidth - (t.icon and Toast.iconSpace * self.scale or 0))
		t.width, t.height = twidth, t.font:getHeight() * #lines
	end
end

local dt = 0
function Toast:update(_dt) dt = dt + _dt end

local fill, line = "fill", "line"
local lastVisibleToasts = 0
function Toast:__render()
	love.graphics.push("all")

	local instances, width, scale = self.instances, self.width, self.scale
	local bs1, bs2, offset = 8 * scale, 16 * scale, 24 * scale
	local y = bs1 + 6
	love.graphics.setLineWidth(2)

	local visibleToasts, n = Toast.visibleToasts, #instances
	for i = n, n - visibleToasts + 1, -1 do
		local t = instances[i]

		local timer = t.timer + t.lastclock - clock
		t.lastclock = clock
		if timer < -.3 then
			visibleToasts = visibleToasts - 1
			table.insert(Toast.pool, table.remove(instances, i))
		else
			local ty = math.lerp(t.y, y, 1 - math.exp(-dt * 6))
			local th = t.height
			if ty > self.height then
				visibleToasts = n - i
				break
			end

			local tw, ta = t.width, math.min((t.timer + .3) / .3, 1)
			local tx = (width - tw) / 2

			local bx, by, bw, bh = tx - bs1, ty - bs1, tw + bs2, th + bs2
			local c1, c2 = 6, 6

			local r, g, b =
				bit.band(bit.rshift(t.color, 16), 0xFF) / 255,
				bit.band(bit.rshift(t.color, 8), 0xFF) / 255,
				bit.band(t.color, 0xFF) / 255

			love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, ta * 0.5)
			love.graphics.rectangle(fill, bx, by, bw, bh, c1, c1, c2)

			love.graphics.setColor(r, g, b, ta * 0.7)
			love.graphics.rectangle(line, bx, by, bw, bh, c1, c1, c2)

			if t.icon then
				love.graphics.setColor(1, 1, 1, ta)
				love.graphics.draw(t.icon, tx, ty + (th - Toast.iconSize * scale) / 2, 0, scale, scale)
				tx = tx + Toast.iconSpace * scale
			end

			love.graphics.setColor(1, 1, 1, ta)
			love.graphics.setFont(t.font)
			love.graphics.printf(t.text, tx, ty, tw - (t.icon and Toast.iconSpace * scale or 0))

			t.timer, t.y = timer, ty
			y = y + th + offset
		end
	end

	clock = n == 0 and 0 or clock + dt

	self.visibleToasts, lastVisibleToasts, dt = visibleToasts, visibleToasts, 0
	love.graphics.pop()
end

return Toast
