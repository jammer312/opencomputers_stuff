local component = require"component"
local wdc = require"warpdrive_control"
local event = require"event"

local controllers_list = component.list"warpdriveShipController"

local c1 = controllers_list()
local c2 = controllers_list()

if not c1 or not c2 then error"Not enough cores (need exactly 2)" end
if controllers_list() then error"Too many cores (need exactly 2)" end

local wc1 = component.proxy(c1)
local wc2 = component.proxy(c2)

local drone_name = "Bumblebee drone"
wc1.shipName(drone_name)
wc2.shipName(drone_name)

local x1, y1, z1 = wc1.position()
local x2, y2, z2 = wc2.position()
local ox1, oy1, oz1 = wc1.getOrientation()
local ox2, oy2, oz2 = wc2.getOrientation()

if not (ox1 == ox2 and oy1 == oy2 and oz1 == oz2) then error"Cores not cooriented" end
local pdx, pdy, pdz = x2 - x1, y2 - y1, z2 - z1
if pdy ~= 0 or not (pdx == 0 and math.abs(pdz) == 2 or pdz == 0 and math.abs(pdx) == 2) then error"Bad cores positioning" end

local cx, cy, cz = x1 + pdx / 2 + ox1, y1 + pdy / 2 + oy1, z1 + pdz / 2 + oz1

local wdc1 = wdc.wrap(c1, {x = x1 - cx, y = y1 - cy, z = z1 - cz})
local wdc2 = wdc.wrap(c2, {x = x2 - cx, y = y2 - cy, z = z2 - cz})
wdc1.coorient_ship()
wdc1.disable()
wdc2.disable()

local size_without_payload = {0, 1, 0, 0, 1, 1}
local size_with_payload =    {2, 1, 0, 0, 1, 1}

local function vecneg(x, y, z) return -x, -y, -z end

local function work_cycle(x, y, z, s1, s2)
	local tx, ty, tz = x - 2 * ox1, y - 2 * oy1, z - 2 * oz1
	wdc1.disable()
	wdc2.disable()
	wdc1.set_size_ship(table.unpack(s1))
	wdc2.set_size_ship(table.unpack(s2))
	wdc1.movement_global(tx, ty, tz)
	wc2.movement(vecneg(wc1.movement()))
	wdc1.jump_blocking()
	wdc2.jump_blocking()
end

local function retrieve(x, y, z) work_cycle(x, y, z, size_without_payload, size_with_payload) end
local function deliver(x, y, z) work_cycle(x, y, z, size_with_payload, size_without_payload) end

return {deliver = deliver, retrieve = retrieve, drone_name = drone_name, debug_wdc1 = wdc1, debug_wdc2 = wdc2, debug_c = {x=cx, y=cy, z=cz}}
