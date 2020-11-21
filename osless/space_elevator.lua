local c = computer
local cmp = component
local prx = function(name) local c = cmp.list(name)(); return c and cmp.proxy(c) or error("Component not found: " .. name) end

local core = prx"warpdriveShipController"

core.dim_positive(2, 2, 2)
core.dim_negative(2, 2, 2)
core.command"MANUAL"
core.movement(0, 200, 0)
core.enable(true)