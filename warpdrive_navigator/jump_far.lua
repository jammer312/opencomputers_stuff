local wdmc = require"warpdrive_multicore"

local args = {...}

local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])

if not (x and y and z) then error("Invalid args: "..(x or "nil").." "..(y or "nil").." "..(z or "nil")) end

local max_dist = wdmc.max_jump_distance - 5 -- -5 because big spooky cooldowns

local function step(from, to, max)
	max = max or max_dist
	if max < 1 then error"nonpositive max in step()" end
	local delta = to - from
	if delta >= max then delta = max end
	if delta <= -max then delta = -max end
	return delta
end

local curx, cury, curz = wdmc.get_position()

while curx ~= x or cury ~= y or curz ~= z do
	local sx, sy, sz = step(curx, x), step(cury, y), step(curz, z)
	curx = curx + sx
	cury = cury + sy
	curz = curz + sz
	wdmc.queue_jump(curx, cury, curz)
end
print"Course plotted, preparing to jump"