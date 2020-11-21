local wdmc = require"warpdrive_multicore"

local args = {...}

local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])

if not (x and y and z) then error("Invalid args: "..(x or "nil").." "..(y or "nil").." "..(z or "nil")) end

local cx, cy, cz = table.unpack(wdmc.get_expected_position())
wdmc.queue_jump(cx + x, cy + y, cz + z)