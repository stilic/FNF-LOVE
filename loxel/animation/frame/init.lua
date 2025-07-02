local Frame = Basic:extend("Frame")

function Frame:new(name, x, y, w, h, sw, sh, ox, oy, ow, oh, r, t)
	local aw, ah = x + w, y + h

	self.name = name
	self.quad = love.graphics.newQuad(x, y, aw > sw and w - (aw - sw) or w,
		ah > sh and h - (ah - sh) or h, sw, sh)
	self.width = ow or w
	self.height = oh or h
	self.offset = {x = ox or 0, y = oy or 0}
	self.rotated = r
	self.texture = t
end

function Frame:destroy()
	self.quad:release()
	Frame.super.destroy(self)
end

return Frame
