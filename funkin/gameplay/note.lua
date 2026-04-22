local ffi = require("ffi")

local math = math
local max, min, round = math.max, math.min, math.round
local atan, fastsin, fastcos = math.atan, math.fastsin, math.fastcos

local Note = ActorSprite:extend("Note")

Note.safeZoneOffset = 1 / 6

function Note.toPos(time, speed)
	return time * 450 * speed
end

Note.defaultSustainSegments = 3

local susMesh, susData, susVerts
function Note.init()
	if susMesh then return end
	susMesh = love.graphics.newMesh(ActorSprite.vertexFormat, 16, "strip")
	susData = love.data.newByteData(ffi.sizeof("ActorVertex") * 16)
	susVerts = ffi.cast("ActorVertex*", susData:getFFIPointer())

	for i = 0, 15 do
		susVerts[i].r = 255
		susVerts[i].g = 255
		susVerts[i].b = 255
		susVerts[i].a = 255
	end
end

function Note:new(time, direction, sustainTime, type, skin)
	Note.init()
	Note.super.new(self)
	self.ignoreAffectByGroup = true

	self.scale.x, self.scale.y = 0.7, 0.7
	self.speed = 1
	self.time = time
	self._targetTime = 0

	self.wasGoodHit, self.wasGoodSustainHit, self.wasFullSustainHit,
	self.tooLate, self.ignoreNote, self.lastPress = false, false, false, false, false, nil
	self.priority, self.earlyHitMult, self.lateHitMult = 0, 1, 1
	self.showNote, self.showNoteOnHit = true, false
	self.type = type
	self.group = nil

	self.sustainSegments = Note.defaultSustainSegments

	self.__lastScoreTime = nil

	self.direction, self.data = direction, direction -- data is for backward compatibilty
	self:setSkin(skin)
	self:setSustainTime(sustainTime)
end

function Note:reset(time, direction, sustainTime, type, skin)
	self.ignoreAffectByGroup = true

	self.x, self.y, self.z = 0, 0, 0
	self.scale.x, self.scale.y, self.scale.z = 0.7, 0.7, 1
	self.zoom.x, self.zoom.y, self.zoom.z = 1, 1, 1
	self.rotation.x, self.rotation.y, self.rotation.z = 0, 0, 0
	self.offset.x, self.offset.y, self.offset.z = 0, 0, 0
	self.origin.x, self.origin.y, self.origin.z = 0, 0, 0
	self.alpha, self.angle, self.blend = 1, 0, "alpha"

	self.speed, self.time, self._targetTime = 1, time, 0

	self.wasGoodHit, self.wasGoodSustainHit,
	self.tooLate, self.ignoreNote, self.lastPress = false, false, false, false, nil
	self.priority, self.earlyHitMult, self.lateHitMult = 0, 1, 1
	self.showNote, self.showNoteOnHit = true, false
	self.type, self.group, self.character = type, nil, nil

	self.sustainSegments = Note.defaultSustainSegments
	self.__lastScoreTime = nil

	self.isGhost, self.sustainTime, self.skin, self.shader = false, nil, nil, nil
	if self.__shaderAnimations then
		table.clear(self.__shaderAnimations)
	end
	self:destroySustain()

	self.direction, self.data = direction, direction
	self:setSkin(skin)
	self:setSustainTime(sustainTime)
end

function Note:clone()
	local clone = Note(self.time, self.direction, self.sustainTime, self.type, self.skin)
	clone.scale.x, clone.scale.y, clone.scale.z = self.scale.x, self.scale.y, self.scale.z
	clone.zoom.x, clone.zoom.y, clone.zoom.z = self.zoom.x, self.zoom.y, self.zoom.z
	clone.rotation.x, clone.rotation.y, clone.rotation.z = self.rotation.x, self.rotation.y, self.rotation.z
	clone.ignoreNote, clone.priority, clone.type = self.ignoreNote, self.priority, self.type
	clone.earlyHitMult, clone.lateHitMult, clone.hit = self.earlyHitMult, self.lateHitMult, self.hit
	clone.speed, clone.sustainSegments = self.speed, self.sustainSegments

	return clone
end

function Note:_addAnim(...)
	(type(select(2, ...)) == 'table' and self.animation.add or self.animation.addByPrefix)(self.animation, ...)
end

local function makeRGB(color)
	return RGBShader.actorCreate(
		Color.fromString(color[1]),
		Color.fromString(color[2]),
		Color.fromString(color[3])
	)
end

function Note:loadSkinData(skinData, name, direction, noRgb)
	direction = direction + 1
	if not self.__shaderAnimations then
		self.__shaderAnimations = table.new(0, 4)
	else
		table.clear(self.__shaderAnimations)
	end

	local data = skinData[name]
	local anims, tex = data.animations, "skins/" .. skinData.skin .. "/" .. data.sprite
	if anims then
		if data.isPixel then
			self:loadTexture(paths.getImage(tex, true), true, data.frameWidth, data.frameHeight)
		else
			self:setFrames(paths.getSparrowAtlas(tex))
		end

		local noteDatas = not noRgb and skinData.notes or nil
		local noteColor = noteDatas and noteDatas.colors and noteDatas.colors[direction]
		for _, anim in ipairs(anims) do
			Note._addAnim(self, unpack(anim))
			if anim[5] and noteColor then
				self.__shaderAnimations[anim[1]] = makeRGB(noteColor)
			end
		end
	else
		self:loadTexture(paths.getImage(tex))
	end
	self:updateHitbox()

	self.blend = data.blend or self.blend

	if data.scale ~= nil then
		self.scale.x, self.scale.y, self.scale.z = data.scale, data.scale, data.scale
	end
	if data.alpha ~= nil then self.alpha = data.alpha end
	if data.antialiasing ~= nil then self.antialiasing = data.antialiasing end

	local props = data.properties
	props = props and props[math.min(direction, #props)] or props
	if props then for i, v in pairs(props) do self[i] = v end end

	local isArray, color = data.colors and data.colors[1]
	if data.colors and not noRgb and not data.disableRgb then
		if isArray then
			color = data.colors
			color = color and color[math.min(direction, #color)] or color
			self.__shaderAnimations.default = color and #color >= 3 and makeRGB(color) or nil
		else
			for a, c in pairs(data.colors) do
				color = c[math.min(direction, #c)]
				self.__shaderAnimations[a] = makeRGB(color)
			end
		end
	end
end

function Note:setSkin(skin)
	if skin == self.skin then return end
	local name, col = skin.skin, self.direction
	self.skin, self.direction = skin, nil

	self:loadSkinData(skin, "notes", col, true)

	if self.sustain then
		Note.loadSkinData(self.sustain, skin, "sustains", col)
		Note.loadSkinData(self.sustainEnd, skin, "sustainends", col)
	end
	if col then self:setDirection(col) end

	self:play("note")
end

function Note:setDirection(direction)
	if direction == self.direction then return end
	self.direction, self.data = direction, direction

	local data = self.skin.notes
	if not data.disableRgb then
		local color = data.colors[direction + 1]
		self.__shaderAnimations.default = color and makeRGB(color) or nil
	end
end

function Note:setSustainTime(sustainTime)
	if sustainTime == self.sustainTime then return end
	self.sustainTime = sustainTime

	if sustainTime > 0.01 then return self:createSustain() end
	return self:destroySustain()
end

function Note:createSustain()
	if self.sustain then return end
	local sustain, sustainEnd = Sprite(), Sprite()
	self.sustain, self.sustainEnd = sustain, sustainEnd

	local skin, col = self.skin, self.direction
	Note.loadSkinData(sustain, skin, "sustains", col)
	Note.loadSkinData(sustainEnd, skin, "sustainends", col)

	local toPlay = "hold-note" .. self.direction
	Note.play(sustain, sustain.__animations[toPlay] and toPlay or "hold", nil, nil, nil, true)
	toPlay = "end-note" .. self.direction
	Note.play(sustainEnd, sustainEnd.__animations[toPlay] and toPlay or "end", nil, nil, nil, true)

	sustain.z, sustain.offset.z, sustain.origin.z, sustain.__render = 0, 0, 0, __NIL__
	sustainEnd.z, sustainEnd.offset.z, sustainEnd.origin.z, sustainEnd.__render = 0, 0, 0, __NIL__
end

function Note:destroySustain()
	if self.sustainEnd and self.sustainEnd.destroy then self.sustainEnd:destroy() end
	if self.sustain and self.sustain.destroy then self.sustain:destroy() end

	self.sustainEnd, self.sustain = nil, nil
end

function Note:ghost()
	self:loadSkinData(self.skin, "receptors", self.direction)
	self:play("pressed")
	self.isGhost = true
end

function Note:update(dt)
	Note.super.update(self, dt)
	if self.sustain and self.sustain.update then self.sustain:update(dt) end
	if self.sustainEnd and self.sustainEnd.update then self.sustainEnd:update(dt) end
end

function Note:destroy()
	Note.super.destroy(self)
	self:destroySustain()
end

function Note:play(anim, force, frame, dontShader, skipName)
	local toPlay = skipName and anim or anim .. '-note' .. self.direction
	toPlay = self.animation:has(toPlay) and toPlay or anim

	self.animation:play(toPlay, force, frame)
	self:centerOrigin()
	self:centerOffsets()

	if not dontShader then
		self.shader = self.__shaderAnimations[anim] or self.__shaderAnimations.default
	end
end

function Note:canDraw()
	if self.sustain then
		self.sustain.cameras = self.cameras
		self.sustainEnd.cameras = self.cameras
	end
	return (self.texture ~= nil and (self.width ~= 0 or self.height ~= 0)) and
		(Note.super.canDraw(self) or (
			self.sustain and (self.sustain:canDraw() or self.sustainEnd:canDraw())
		))
end

local values, worldSpin, toScreen = {}, Actor.worldSpin, Actor.toScreen

local function getValues(r, pos, values)
	if r then r:getValues(pos, values) end
end

local function applyMod(mods, beat, pos, notefield, direction)
	if mods then for _, mod in pairs(mods) do if mod.applyPath then mod:applyPath(values, beat, pos, notefield, direction) end end end
end

function Note:__render(camera)
	local grp, px, py, pz, pa, pal, rot, sc = self.group, self.x, self.y, self.z, self.angle, self.alpha, self.rotation, self.scale
	local dir, time, target, speed, psx, psy, psz, prx, pry, prz = self.direction, self.time, self._targetTime, self.speed,
		sc.x, sc.y, sc.z, rot.x, rot.y, rot.z

	local par, nx, ny, nz, pos, rec, beat, mods = self.parent, px, py, pz, Note.toPos(time - target, speed)
	Receptor.getDefaultValues(values)

	if par then
		beat, mods = par.beat or 0, par.modifiers
	end

	local gx, gy, gz, gsx, gsy, gsz, grx, gry, grz, gox, goy, goz = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	if grp then
		gx, gy, gz, gsx, gsy, gsz, grx, gry, grz, gox, goy, goz, rec = grp.x, grp.y, grp.z, grp.scale.x, grp.scale.y, grp.scale.z,
			grp.rotation.x, grp.rotation.y, grp.rotation.z, grp.origin.x, grp.origin.y, grp.origin.z, grp.receptor

		self.angle, rot.x, rot.y, rot.z, sc.x, sc.y, sc.z = pa + grp.memberAngles,
			prx + grp.memberRotations.x, pry + grp.memberRotations.y, prz + grp.memberRotations.z,
			psx * grp.memberScales.x, psy * grp.memberScales.y, psz * grp.memberScales.z

		if grp.affectAngle then self.angle, rot.y, rot.y, rot.z = self.angle + grp.angle, rot.y + grx, rot.y + gry, rot.z + grz end
		if grp.affectScale then sc.x, sc.y, sc.z = sc.x * gsx, sc.y * gsy, sc.z * gsz end
		if rec then
			nx, ny, nz = nx + rec.x + rec.noteOffsets.x, ny + rec.y + rec.noteOffsets.y, nz + rec.z + rec.noteOffsets.z
			rot.x, rot.y, rot.z = rot.x + rec.noteRotations.x, rot.y + rec.noteRotations.y, rot.z + rec.noteRotations.z
			grx, gry, grz = grx + rec.directions.x, gry + rec.directions.y, grz + rec.directions.z
			self.angle = self.angle + rec.noteAngles
		end

		getValues(rec, pos, values); applyMod(mods, beat, pos, par, dir)
		local vx, vy, vz = worldSpin(
			(nx + values.x) * gsx,
			(ny + values.y) * gsy,
			(nz + values.z) * gsz,
			grx, gry, grz, gox, goy, goz)

		self.x, self.y, self.z = vx + gx, vy + gy, vz + gz
	else
		applyMod(mods, beat, pos, par, dir)
		self.x, self.y, self.z = nx, ny + pos, nz
	end

	local v, almult = values.size, self.tooLate and .5 or (self.isGhost and .6 or 1)
	rot.x, rot.y, rot.z = rot.x + values.rotX, rot.y + values.rotY, rot.z + values.rotZ
	sc.x, sc.y, sc.z = sc.x * values.sizeX * v, sc.y * values.sizeY * v, sc.z * values.sizeZ * v
	self.alpha = pal * values.alpha * almult

	--[[
		I'm aware that if the texture size height or scale are too small, it'll be huge draw calls
		i can't wrap it around it either since it requires a shader which would not be a big deal but
		ActorSprite and rgb uses a shader, and i have to make it around before those renders,
		I could make a canvas but who knows...

		get fucked™

		Also probably need a rework like the actorsprite
	--]]

	local sus = self.sustain
	if sus then
		local dshader, shader, r, g, b, a = ActorSprite.defaultShader, love.graphics.getShader(), love.graphics.getColor()
		local blendMode, alphaMode = love.graphics.getBlendMode()

		local fov, drawSize, drawSizeOffset = self.fov, grp and grp.drawSize or 800, grp and grp.drawSizeOffset or 0
		local suspos, minbound, maxbound = Note.toPos(time + self.sustainTime - target, speed),
			self.pressed and 0 or self.lastPress and Note.toPos(self.lastPress - target, speed) or max(pos, -drawSize / 2 + drawSizeOffset - ny),
			drawSize / 2 + drawSizeOffset - ny

		local segments = self.sustainSegments
		local vertLens = min(2 + segments * 2, 16)

		if vertLens > 2 then
			local susend, gotVerts = self.sustainEnd
			if susend and suspos >= minbound and suspos < maxbound then
				local snx, sny, snz, ssc, tex = susend.x + nx, susend.y + ny, (susend.z or 0) + nz, susend.scale, susend.texture
				local f, tw, th = susend:getCurrentFrame(), tex:getWidth(), tex:getHeight()
				local hfw, fh, uvx, uvy, uvxw, uvh = tw, th, 0, 0, 1, 1
				if f then
					uvx, uvy, hfw, fh = f.quad:getViewport()
					if susend.antialiasing then uvy, fh = uvy + 1, fh - 1 end
					uvx, uvy, uvxw, uvh = uvx / tw, uvy / th, (hfw + uvx) / tw, fh / th
				end
				local fhs = uvh / segments
				hfw, fh, gotVerts = hfw * ssc.x / 2, fh / segments * ssc.y, vertLens

				tex:setFilter(susend.antialiasing and "linear" or "nearest")
				love.graphics.setShader(susend.shader or defaultShader); love.graphics.setBlendMode(susend.blend)
				love.graphics.setColor(susend.color[1], susend.color[2], susend.color[3], susend.alpha * almult)
				susMesh:setTexture(tex)

				getValues(rec, suspos + 1, Receptor.getDefaultValues(values)); applyMod(mods, beat, suspos + 1, par, dir)
				vx, vy, vz = worldSpin(
					(snx + values.x) * gsx,
					(sny + values.y) * gsy,
					(snz + values.z) * gsz,
					grx, gry, grz, gox, goy, goz
				)
				local pvx, pvy = toScreen(vx + gx, vy + gy, vz + gz, fov)
				local enduv, aa, as, ac

				for vi = 1, vertLens, 2 do
					getValues(rec, suspos, Receptor.getDefaultValues(values)); applyMod(mods, beat, suspos, par, dir)
					vx, vy, vz = worldSpin(
						(snx + values.x) * gsx,
						(sny + values.y) * gsy,
						(snz + values.z) * gsz,
						grx, gry, grz, gox, goy, goz
					)

					vx, vy, vz = toScreen(vx + gx, vy + gy, vz + gz, fov)

					aa = -atan((pvx - vx) / (pvy - vy))
					as, ac, pvx, pvy = fastsin(aa) * vz, fastcos(aa) * vz, vx, vy

					local ptr1 = susVerts[vi - 1]
					ptr1.x, ptr1.y = vx - hfw * ac, vy - hfw * as
					ptr1.u, ptr1.v, ptr1.w = uvx * vz, (uvy + uvh) * vz, vz
					ptr1.a = values.alpha * 255

					local ptr2 = susVerts[vi]
					ptr2.x, ptr2.y = vx + hfw * ac, vy + hfw * as
					ptr2.u, ptr2.v, ptr2.w = uvxw * vz, (uvy + uvh) * vz, vz
					ptr2.a = values.alpha * 255

					if vi + 1 < vertLens then suspos, uvh = suspos - fh, uvh - fhs end
					if enduv then
						gotVerts = vi + 1
						break
					elseif suspos < minbound then
						suspos, uvh, enduv = minbound, uvh - ((suspos - minbound) / ssc.y / th / segments), true
					end
				end

				susMesh:setDrawRange(1, gotVerts); susMesh:setVertices(susData); love.graphics.draw(susMesh)
			end

			if suspos >= minbound then
				local snx, sny, snz, ssc, tex = sus.x + nx, sus.y + ny, (sus.z or 0) + nz, sus.scale, sus.texture
				local f, tw, th = sus:getCurrentFrame(), tex:getWidth(), tex:getHeight()
				local hfw, fh, uvx, uvy, uvxw, uvh = tw, th, 0, 0, 1, 1
				if f then
					uvx, uvy, hfw, fh = f.quad:getViewport()
					if sus.antialiasing then uvy, fh = uvy + 1, fh - 2 end
					uvx, uvy, uvxw, uvh = uvx / tw, uvy / th, (hfw + uvx) / tw, fh / th
				end
				local ssy = max(fh * ssc.y, 64) / fh
				hfw, fh = hfw * ssc.x / 2, max(fh * ssc.y, 64)
				segments = segments * max(round(fh / 128), 1)
				fh = fh / segments

				tex:setFilter(sus.antialiasing and "linear" or "nearest")
				love.graphics.setShader(sus.shader or defaultShader); love.graphics.setBlendMode(sus.blend)
				love.graphics.setColor(sus.color[1], sus.color[2], sus.color[3], sus.alpha * almult)
				susMesh:setTexture(tex)

				getValues(rec, suspos + 1, Receptor.getDefaultValues(values)); applyMod(mods, beat, suspos + 1, par, dir)
				suspos, vertLens, vx, vy, vz = min(suspos, maxbound), min(2 + segments * 2, 16), worldSpin(
					(snx + values.x) * gsx,
					(sny + values.y) * gsy,
					(snz + values.z) * gsz,
					grx, gry, grz, gox, goy, goz
				)
				local pvx, pvy = toScreen(vx + gx, vy + gy, vz + gz, fov)
				local uvfh, fhs, uvyh, vi, enduv, aa, as, ac = uvh, uvh / segments, uvy + uvh, 1

				if gotVerts then
					local vert2 = susVerts[gotVerts - 1]
					local vert1 = susVerts[gotVerts - 2]

					suspos, uvfh = suspos - fh, uvfh - fhs
					vi = 3

					local dst2 = susVerts[1]
					dst2.x, dst2.y = vert2.x, vert2.y
					dst2.u, dst2.v, dst2.w = uvxw * vert2.w, uvyh * vert2.w, vert2.w
					dst2.a = vert2.a

					local dst1 = susVerts[0]
					dst1.x, dst1.y = vert1.x, vert1.y
					dst1.u, dst1.v, dst1.w = uvx * vert1.w, uvyh * vert1.w, vert1.w
					dst1.a = vert1.a

					if suspos < minbound then
						suspos, uvfh, enduv = minbound, uvfh - ((suspos - minbound) / ssy / th / segments), true
					end
				end

				while true do
					getValues(rec, suspos, Receptor.getDefaultValues(values)); applyMod(mods, beat, suspos, par, dir)
					vx, vy, vz = worldSpin(
						(snx + values.x) * gsx,
						(sny + values.y) * gsy,
						(snz + values.z) * gsz,
						grx, gry, grz, gox, goy, goz
					)

					vx, vy, vz = toScreen(vx + gx, vy + gy, vz + gz, fov)

					aa = -atan((pvx - vx) / (pvy - vy))
					as, ac, pvx, pvy = fastsin(aa) * vz, fastcos(aa) * vz, vx, vy

					local ptr1 = susVerts[vi - 1]
					ptr1.x, ptr1.y = vx - hfw * ac, vy - hfw * as
					ptr1.u, ptr1.v, ptr1.w = uvx * vz, (uvy + uvfh) * vz, vz
					ptr1.a = values.alpha * 255
					vi = vi + 1

					local ptr2 = susVerts[vi - 1]
					ptr2.x, ptr2.y = vx + hfw * ac, vy + hfw * as
					ptr2.u, ptr2.v, ptr2.w = uvxw * vz, (uvy + uvfh) * vz, vz
					ptr2.a = values.alpha * 255
					vi = vi + 1

					suspos, uvfh = suspos - fh, uvfh - fhs
					if enduv or vi > vertLens then
						susMesh:setDrawRange(1, vi - 1); susMesh:setVertices(susData); love.graphics.draw(susMesh)

						if enduv then
							break
						else
							local srcRight                     = susVerts[vi - 2]
							local srcLeft                      = susVerts[vi - 3]

							local dstRight                     = susVerts[1]
							dstRight.x, dstRight.y             = srcRight.x, srcRight.y
							dstRight.u, dstRight.v, dstRight.w = srcRight.u, uvyh * srcRight.w, srcRight.w
							dstRight.a                         = srcRight.a

							uvfh                               = uvh - fhs
							vi                                 = 3

							local dstLeft                      = susVerts[0]
							dstLeft.x, dstLeft.y               = srcLeft.x, srcLeft.y
							dstLeft.u, dstLeft.v, dstLeft.w    = srcLeft.u, uvyh * srcLeft.w, srcLeft.w
							dstLeft.a                          = srcLeft.a
						end
					end

					if suspos < minbound then
						suspos, uvfh, enduv = minbound, uvfh - ((suspos - minbound) / ssy / th / segments), true
					end
				end
			end
		end

		love.graphics.setShader(shader); love.graphics.setColor(r, g, b, a)
		love.graphics.setBlendMode(blendMode, alphaMode)
	end

	if self.showNote and (self.isGhost or not self.wasGoodHit or self.showNoteOnHit) then
		ActorSprite.__render(self, camera)
	end

	self.x, self.y, self.z, self.angle, self.alpha, sc.x, sc.y, sc.z, rot.x, rot.y, rot.z = px, py, pz, pa, pal, psx, psy, psz, prx, pry, prz
end

return Note
