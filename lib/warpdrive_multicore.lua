local component = require"component"
local wdc = require"warpdrive_control"
local queue = require"queue"
local event = require"event"
local term_utils = require"term_utils"

local config_db_name = "warpdrive_multicore_config"

local db = require"db".load(config_db_name)

local ship_center
local ship_size
if not db.initialized then
	term_utils.ensure("Needed for initial configuration")
	db.ship_name = term_utils.read_line("Enter ship name: ")
	ship_center = {
		term_utils.read_number("Enter ship center X: "),
		term_utils.read_number("Enter ship center Y: "),
		term_utils.read_number("Enter ship center Z: ")}
	ship_size = {
		ship_center[1] + term_utils.read_number("Enter ship size +X: "), ship_center[1] - term_utils.read_number("Enter ship size -X: "),
		ship_center[2] + term_utils.read_number("Enter ship size +Y: "), ship_center[2] - term_utils.read_number("Enter ship size -Y: "),
		ship_center[3] + term_utils.read_number("Enter ship size +Z: "), ship_center[3] - term_utils.read_number("Enter ship size -Z: ")}
end

local new_controllers = queue.new()

local function swap_yz(x, y, z) return x, z, y end --needed because ship size uses different order
local function vec_neg(x, y, z) return -x, -y, -z end

local controller_list = component.list"warpdriveShipController"
for addr in controller_list do
	if db[addr] then
		local ctl = component.proxy(addr)
		local cached = db[addr]
		local ctlw = wdc.wrap(addr, cached.offset)
		local cx, cy, cz = ctl.position()
		local ox, oy, oz = cached.offset.x, cached.offset.y, cached.offset.z
		local cur_ship_center = {cx - ox, cy - oy, cz - oz}
		local rdpx, rdpy, rdpz = swap_yz(ctl.dim_positive())
		local rdnx, rdny, rdnz = swap_yz(ctl.dim_negative())
		local dpx, dpy, dpz = ctlw.relative_to_global(rdpx, rdpy, rdpz, true)
		local dnx, dny, dnz = ctlw.relative_to_global(-rdnx, -rdny, -rdnz, true)
		if dpx < dnx then dpx, dnx = dnx, dpx end
		if dpy < dny then dpy, dny = dny, dpy end
		if dpz < dnz then dpz, dnz = dnz, dpz end
		local cur_ship_size = {dpx, dnx, dpy, dny, dpz, dnz}
		if not ship_center then
			ship_center = cur_ship_center
			ship_size = cur_ship_size
		else
			for i, v in ipairs(ship_center) do
				if v ~= cur_ship_center[i] then error"Inconsistent ship center offset" end
			end
			for i,v in ipairs(ship_size) do
				if v ~= cur_ship_size[i] then error"Inconsistent ship size" end
			end
		end
	else
		new_controllers.push(addr)
	end
end

if not ship_center then error("No old cores found") end --TODO: insert proper db reset right before crash
while new_controllers.size() > 0 do
	local addr = new_controllers.pop()
	local ctl = component.proxy(addr)
	local cx, cy, cz = ctl.position()
	local offset = {x = cx - ship_center[1], y = cy - ship_center[2], z = cz - ship_center[3]}
	db[addr] = {offset = offset}
	local ctlw = wdc.wrap(addr, offset)
	local dpx, dnx, dpy, dny, dpz, dnz = ship_size[1], ship_size[2], ship_size[3], ship_size[4], ship_size[5], ship_size[6]
	local dpx, dpy, dpz = swap_yz(ctlw.global_to_relative(dpx, dpy, dpz, true))
	local dnx, dny, dnz = vec_neg(swap_yz(ctlw.global_to_relative(dnx, dny, dnz, true)))
	if dpx < 0 then dpx, dnx = -dnx, -dpx end
	if dpy < 0 then dpy, dny = -dny, -dpy end
	if dpz < 0 then dpz, dnz = -dnz, -dpz end
	ctl.dim_positive(dpx, dpy, dpz)
	ctl.dim_negative(dnx, dny, dnz)
	ctl.shipName(db.ship_name)
	if not db.initialized then db.initialized = true end
end

local wdmc = {}
wdmc.ctls = {}
wdmc.ctls_ready = queue.new()
wdmc.pending_jumps = queue.new()
wdmc.active = false
wdmc.print = print
local primary
local at_least_one
for addr in component.list"warpdriveShipController" do
	if not db[addr] then error"unexpected new controller" end
	wdmc.ctls[addr] = wdc.wrap(addr, db[addr].offset)
	if not wdmc.max_jump_distance then
		local wc = component.proxy(addr)
		wc.command(wdc.commands.manual)
		_, wdmc.max_jump_distance = wc.getMaxJumpDistance()
		wc.command(wdc.commands.offline)
		primary = wdmc.ctls[addr]
	end
	wdmc.ctls_ready.push(wdmc.ctls[addr])
	at_least_one = true
end

if not at_least_one then error"no controllers" end

wdmc.get_position = function()
	return primary.get_position()
end

local function manage_pending_jumps()
	if wdmc.pending_jumps.size() < 1 then
		wdmc.active = false
		return
	end
	if wdmc.ctls_ready.size() < 1 or not wdmc.active then return end
	local jump = wdmc.pending_jumps.pop()
	local ctl = wdmc.ctls_ready.pop()
	local cx, cy, cz = wdmc.get_position()
	local rx, ry, rz = jump.x - cx, jump.y - cy, jump.z - cz
	if math.abs(rx) > wdmc.max_jump_distance or math.abs(ry) > wdmc.max_jump_distance or math.abs(rz) > wdmc.max_jump_distance then
		error"Max jump distance exceeded"
	end
	local res, reason = ctl.movement_global(jump.x, jump.y, jump.z)
	if not res then
		if reason == "too small" then
			wdmc.print("Skipping jump because it's too small", jump.x, jump.y, jump.z)
			wdmc.ctls_ready.push(ctl)
			return
		end
		error(reason)
	end
	ctl.jump()
end

local function cooled_down(ename, addr)
	if not wdmc.ctls[addr] then error"Caught event from unmanaged controller" end
	wdmc.ctls_ready.push(wdmc.ctls[addr])
	manage_pending_jumps()
end

event.listen("shipCoreCooldownDone", cooled_down)
event.listen("core_jumped", manage_pending_jumps)

wdmc.queue_jump = function(x, y, z)
	wdmc.pending_jumps.push({x = x, y = y, z = z})
	if not wdmc.active then
		wdmc.active = true
		manage_pending_jumps()
	end
end

return wdmc