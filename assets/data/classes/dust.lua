local DustGroup = Group:extend("DustGroup")

function DustGroup.close() close() end

function DustGroup:new(parent)
	DustGroup.super.new(self)
	self.parent = parent
	self.timer = 0
	self._objects = {}
end

function DustGroup:add(path, x, y, sx, sy, z, v, c, a, scale, oy, waveSpeed, waveAmp)
	path = "stages/" .. self.parent.name .. '/' .. path
	local obj = BackDrop(paths.getImage(path), "x")

	obj:setPosition(x or 0, y or 0)
	obj.scrollFactor:set(sx or 1, sy or 1)
	obj.zIndex = z or 0

	obj.blend = self.blend or "add"
	obj.color = Color.fromHEX(c or 0xFFFFFF)
	obj.alpha = a or 1
	obj.scale:set(scale or 1, scale or 1)

	obj.moves = true
	obj.velocity.x = v or 0

	obj._baseY = oy or y or 0
	obj._waveSpeed = waveSpeed or 0
	obj._waveAmp = waveAmp or 0

	if self.parent then
		self.parent:add(obj)
	end
	table.insert(self._objects, obj)

	return obj
end

function DustGroup:update(dt)
	if not (self.exists and self.active) then return end

	self.timer = self.timer + dt

	for _, obj in ipairs(self._objects) do
		if obj.exists and obj._waveSpeed > 0 then
			obj.y = obj._baseY + math.sin(self.timer * obj._waveSpeed) * obj._waveAmp
		end
	end
end

function DustGroup:destroy()
	DustGroup.super.destroy(self)
	table.clear(self._objects)
end

return DustGroup
