local StateManager = {}

local stack = {}
StateManager.stack = stack

local initialized = setmetatable({}, {__mode = "k"})
local function call(state, method, ...)
	local fn = state[method]
	if fn then return fn(state, ...) end
end

local function ensureInit(state)
	if not initialized[state] then
		initialized[state] = true
		call(state, "init")
	end
end

function StateManager.current() return stack[#stack] end

function StateManager.switch(to, ...)
	assert(to, "StateManager.switch: state argument required")

	for i = #stack, 1, -1 do
		call(stack[i], "leave")
		stack[i] = nil
	end

	ensureInit(to)
	stack[1] = to
	return call(to, "enter", nil, ...)
end

function StateManager.push(to, ...)
	assert(to, "StateManager.push: state argument required")
	local prev = stack[#stack]
	ensureInit(to)
	stack[#stack + 1] = to
	to.parent = prev
	return call(to, "enter", prev, ...)
end

function StateManager.pop(index, ...)
	local n = #stack
	assert(n > 0, "StateManager.pop: stack is empty")
	index = index or n

	local popped = stack[index]
	table.remove(stack, index)
	local top = stack[#stack]

	call(popped, "leave")
	if top then
		top.parent = stack[#stack - 1]
		return call(top, "resume", popped, ...)
	end
end

function StateManager.update(dt)
	local n = #stack
	for i = n, 1, -1 do
		local s = stack[i]
		call(s, "update", dt)
		if not s.persistentUpdate then break end
	end
end

function StateManager.draw()
	local n = #stack
	if n == 0 then return end

	local start = n
	for i = n - 1, 1, -1 do
		if stack[i + 1].persistentDraw then
			start = i
		else
			break
		end
	end

	for i = start, n do
		call(stack[i], "draw")
	end
end

function StateManager.resize(w, h)
	local s = stack[#stack]
	if s then call(s, "resize", w, h) end
end

function StateManager.focus(f)
	local s = stack[#stack]
	if s then call(s, "focus", f) end
end

function StateManager.fullscreen(f)
	local s = stack[#stack]
	if s then call(s, "fullscreen", f) end
end

function StateManager.quit()
	local s = stack[#stack]
	if s then call(s, "quit") end
end

return StateManager
