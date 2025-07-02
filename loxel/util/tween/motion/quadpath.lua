local Tween = loxreq "util.tween.instance"

local QuadPath = Tween:extend("QuadPath")

function QuadPath:new(object, options, points, duration)
	QuadPath.super.new(self)

	self._points = points or {}
	self._distance = 0
	self._speed = 0
	self._index = 0
	self._numSegs = 0

	self._updateCurve = true
	self._curveT = {}
	self._curveD = {}

	self._a = Point()
	self._b = Point()
	self._c = Point()

	self.x = 0
	self.y = 0

	if object then
		self:tween(object, {}, duration, options)
	end

	return self
end

function QuadPath:destroy()
	self._points = {}
	self._a = nil
	self._b = nil
	self._c = nil

	QuadPath.super.destroy(self)
end

function QuadPath:tween(object, properties, duration, options)
	QuadPath.super.tween(self, object, properties, duration, options)
	self._index = self.forward and 0 or (self._numSegs - 1)
	return self
end

function QuadPath:setMotion(durationOrSpeed, useDuration)
	useDuration = useDuration ~= false
	self:updatePath()

	if useDuration then
		self.duration = durationOrSpeed
		self._speed = self._distance / durationOrSpeed
	else
		self.duration = self._distance / durationOrSpeed
		self._speed = durationOrSpeed
	end

	self:start()
	return self
end

function QuadPath:addPoint(x, y)
	x = x or 0
	y = y or 0
	self._updateCurve = true
	table.insert(self._points, Point(x, y))
	return self
end

function QuadPath:getPoint(index)
	index = index or 0
	if #self._points == 0 then
		error("No points have been added to the path yet.")
	end
	return self._points[index % #self._points + 1]
end

function QuadPath:start()
	self._index = self.forward and 0 or (self._numSegs - 1)
	self.time = 0
	self.progress = 0
	self.finished = false
	self.active = true

	if self.onStart then
		self.onStart(self)
	end

	return self
end

function QuadPath:update(dt)
	if self.finished or not self.active then return end

	if self.startDelay > 0 then
		self.startDelay = self.startDelay - dt
		return
	end

	QuadPath.super.update(self, dt)

	if self.finished then return end

	local easedProgress = self.progress
	if type(self.ease) == "function" then
		easedProgress = self.ease(self.progress)
	elseif Ease and Ease[self.ease] then
		easedProgress = Ease[self.ease](self.progress)
	end

	self:calculatePosition(easedProgress)

	if self.object then
		if type(self.object.setPosition) == "function" then
			self.object:setPosition(self.x, self.y)
		else
			self.object.x = self.x
			self.object.y = self.y
		end
	end
end

function QuadPath:calculatePosition(scale)
	if #self._points == 0 then return end

	local td, tt

	if self.forward then
		if self._index < self._numSegs - 1 then
			while scale > self._curveT[self._index + 2] do
				self._index = self._index + 1
				if self._index == self._numSegs - 1 then
					break
				end
			end
		end

		td = self._curveT[self._index + 1]
		tt = self._curveT[self._index + 2] - td
		td = (scale - td) / tt

		self._a = self._points[self._index * 2 + 1]
		self._b = self._points[self._index * 2 + 2]
		self._c = self._points[self._index * 2 + 3]
	else
		if self._index > 0 then
			while scale < self._curveT[self._index + 1] do
				self._index = self._index - 1
				if self._index == 0 then
					break
				end
			end
		end

		td = self._curveT[self._index + 2]
		tt = self._curveT[self._index + 1] - td
		td = (scale - td) / tt

		self._a = self._points[self._index * 2 + 3]
		self._b = self._points[self._index * 2 + 2]
		self._c = self._points[self._index * 2 + 1]
	end

	local t = td
	local invT = 1 - t
	self.x = self._a.x * invT * invT + self._b.x * 2 * invT * t + self._c.x * t * t
	self.y = self._a.y * invT * invT + self._b.y * 2 * invT * t + self._c.y * t * t
end

function QuadPath:complete()
	if self.type == "looping" or self.type == "pingpong" then
		self._index = self.forward and 0 or (self._numSegs - 1)
	end
	QuadPath.super.complete(self)
end

function QuadPath:updatePath()
	if (#self._points - 1) % 2 ~= 0 or #self._points < 3 then
		error("A QuadPath must have at least 3 or a odd mumber of points to operate")
	end

	if not self._updateCurve then return end

	self._updateCurve = false

	local i = 0
	local j = 0
	self._distance = 0
	self._numSegs = math.floor((#self._points - 1) / 2)

	self._curveD = {}
	while i < self._numSegs do
		j = i * 2
		self._curveD[i + 1] = self:getCurveLength(
			self._points[j + 1], self._points[j + 2], self._points[j + 3])
		self._distance = self._distance + self._curveD[i + 1]
		i = i + 1
	end

	i = 0
	local d = 0

	self._curveT = {0}
	while i < self._numSegs do
		d = d + self._curveD[i + 1]
		table.insert(self._curveT, d / self._distance)
		i = i + 1
	end
end

function QuadPath:getCurveLength(start, control, finish)
	local safeControl = control:clone()
	local p1 = Point()
	local p2 = Point()

	local EPSILON = 0.0001

	if safeControl == start then
		safeControl.x = safeControl.x + EPSILON
		safeControl.y = safeControl.y + EPSILON
	end

	if safeControl == finish then
		safeControl.x = safeControl.x + EPSILON
		safeControl.y = safeControl.y + EPSILON
	end

	p1.x = start.x - 2 * safeControl.x + finish.x
	p1.y = start.y - 2 * safeControl.y + finish.y
	p2.x = 2 * safeControl.x - 2 * start.x
	p2.y = 2 * safeControl.y - 2 * start.y

	local a = 4 * (p1.x * p1.x + p1.y * p1.y)
	local b = 4 * (p1.x * p2.x + p1.y * p2.y)
	local c = p2.x * p2.x + p2.y * p2.y
	local abc = 2 * math.sqrt(a + b + c)
	local a2 = math.sqrt(a)
	local a32 = 2 * a * a2
	local c2 = 2 * math.sqrt(c)
	local ba = b / a2

	return (a32 * abc + a2 * b * (abc - c2) + (4 * c * a - b * b) *
		math.log((2 * a2 + ba + abc) / (ba + c2))) / (4 * a32)
end

return QuadPath
