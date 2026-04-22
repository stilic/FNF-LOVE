local AnimateLibrary = loxreq "animateatlas.library"

local AnimateLib = AnimateLibrary:extend("AnimateLib")

function AnimateLib:new(folder)
	AnimateLib.super.new(self, folder)
	self.loaded = true
end

function AnimateLib:loadAsync(callback)
	if callback then callback(self) end
end

return AnimateLib
