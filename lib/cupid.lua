--[[
Copyright (c) 2026 Victor Kaoy

 This module is free software; you can redistribute it and/or modify
 it under the terms of the MIT license.
]]

local Terminal = {
	type_prompt  = "\27[38;5;214m[   CMD   ] > \27[0m",
	output       = "\27[38;5;214m[   CMD   ] [  %s  ] \27[0m%s",
	error_output = "\27[38;5;214m[   CMD   ]\27[0m [  ERROR  ] %s"
}

local thread_code = [=[
require("love.timer")
require("love.thread")

local ffi = require("ffi")
ffi.cdef[[
	int _kbhit(void);
	int _getch(void);
]]
local msvcrt = ffi.load("msvcrt")

local prompt = "]=] .. Terminal.type_prompt .. [=["
local input_buffer = ""
local cursor_pos = 1
local command_history = {}
local history_index = 1
local history_limit = 20

local cmds_chan = love.thread.getChannel("terminal_cmds")
local prints_chan = love.thread.getChannel("terminal_prints")
local quit_chan = love.thread.getChannel("terminal_quit")

local function redraw()
	local max_len = 68
	local disp_start = 1
	local disp_end = #input_buffer

	if #input_buffer > max_len then
		if cursor_pos > max_len then
			disp_start = cursor_pos - max_len
			disp_end = cursor_pos - 1
		else
			disp_start = 1
			disp_end = max_len
		end
	end

	local display_str = input_buffer:sub(disp_start, disp_end)
	local vis_cursor = cursor_pos - disp_start + 1

	io.write("\r\27[K" .. prompt .. display_str)
	local move_back = #display_str - (vis_cursor - 1)
	if move_back > 0 then io.write("\27[" .. move_back .. "D") end
	io.flush()
end

io.stdout:setvbuf("no")
io.write("\27[2J\27[H")
redraw()

while true do
	local needs_redraw = false

	local p = prints_chan:pop()
	while p do
		io.write("\r\27[K" .. p .. "\n")
		needs_redraw = true
		p = prints_chan:pop()
	end

	if quit_chan:peek() then break end

	while msvcrt._kbhit() ~= 0 do
		local char = msvcrt._getch()

		if char == 0 or char == 224 then
			local ext = msvcrt._getch()
			if ext == 72 then
				if history_index > 1 then
					history_index = history_index - 1
					input_buffer = command_history[history_index]
					cursor_pos = #input_buffer + 1
					needs_redraw = true
				end
			elseif ext == 80 then
				if history_index < #command_history then
					history_index = history_index + 1
					input_buffer = command_history[history_index]
					cursor_pos = #input_buffer + 1
					needs_redraw = true
				elseif history_index == #command_history then
					history_index = #command_history + 1
					input_buffer = ""
					cursor_pos = 1
					needs_redraw = true
				end
			elseif ext == 75 then
				if cursor_pos > 1 then
					cursor_pos = cursor_pos - 1
					needs_redraw = true
				end
			elseif ext == 77 then
				if cursor_pos <= #input_buffer then
					cursor_pos = cursor_pos + 1
					needs_redraw = true
				end
			end
		elseif char == 13 or char == 10 then
			if input_buffer ~= "" then
				redraw()
				io.write("\n")
				io.flush()
				local cmd = input_buffer
				input_buffer = ""
				cursor_pos = 1
				table.insert(command_history, cmd)
				if #command_history > history_limit then
					table.remove(command_history, 1)
				end
				history_index = #command_history + 1
				cmds_chan:push(cmd)
				needs_redraw = true
			end
		elseif char == 8 or char == 127 then
			if cursor_pos > 1 then
				local left = input_buffer:sub(1, cursor_pos - 2)
				local right = input_buffer:sub(cursor_pos)
				input_buffer = left .. right
				cursor_pos = cursor_pos - 1
				needs_redraw = true
			end
		elseif char == 3 then
			cmds_chan:push("QUIT_EVENT")
		elseif char >= 32 and char <= 126 then
			local left = input_buffer:sub(1, cursor_pos - 1)
			local right = input_buffer:sub(cursor_pos)
			input_buffer = left .. string.char(char) .. right
			cursor_pos = cursor_pos + 1
			needs_redraw = true
		end
	end
	if needs_redraw then redraw() end
	love.timer.sleep(0.01)
end
]=]

function Terminal.setup()
	local original_print = _G.print
	_G.print = function(...)
		local n = select("#", ...)
		local args = {}
		for i = 1, n do
			args[i] = tostring(select(i, ...))
		end
		local str = table.concat(args, "\t")
		love.thread.getChannel("terminal_prints"):push(str)
	end

	Terminal.thread = love.thread.newThread(thread_code)
	Terminal.thread:start()
end

local shortcuts = {
	switchState = function() return game.switchState end,
	resetState = function() return game.resetState end,
	state = function() return game.getState() end,
	substate = function() return game.getState(true) end,
}

local terminal_env = setmetatable({}, {
	__index = function(_, key)
		if shortcuts[key] then
			return shortcuts[key]()
		end
		return _G[key]
	end,
	__newindex = _G
})

function Terminal.execute(cmd)
	if cmd == "" then return end

	local display_cmd = #cmd > 8 and (cmd:sub(1, 8) .. "...") or cmd
	local func, err = load("return " .. cmd)
	if not func then func, err = load(cmd) end

	if func then
		setfenv(func, terminal_env)
		local status, res = pcall(func)
		if status then
			if res ~= nil then
				print(Terminal.output:format(display_cmd, tostring(res)))
			end
		else
			local clean_err = tostring(res):gsub("^%[string \".-\"%]:%d+: ", "")
			print(Terminal.error_output:format(clean_err))
		end
	else
		local clean_err = tostring(err):gsub("^%[string \".-\"%]:%d+: ", "")
		print(Terminal.error_output:format(clean_err))
	end
end

function Terminal.update()
	local cmds_chan = love.thread.getChannel("terminal_cmds")
	local cmd = cmds_chan:pop()

	while cmd do
		if cmd == "quit" then
			require("love").event.quit()
		elseif cmd == "restart" then
			require("love").event.quit("restart")
		else
			Terminal.execute(cmd)
		end
		cmd = cmds_chan:pop()
	end
end

function Terminal.quit()
	love.thread.getChannel("terminal_quit"):push(true)
end

return Terminal
