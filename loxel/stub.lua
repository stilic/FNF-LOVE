local Stub = Classic:extend("Stub")

function Stub:new() end

function Stub:__index(k)
	local val = rawget(getmetatable(self), k)
	if val then return val end
	return function() end
end

return Stub
