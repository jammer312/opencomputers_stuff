local component = require"component"
local event = require"event"
local queue = require"queue"

local wc = {}
wc.fly_height = 225
wc.min_jump_interval = 1 --won't jump more often than that

wc.commands = {
	offline = "offline",
	idle = "idle",
	manual = "manual",
	hyperdrive = "hyperdrive",
	gate = "gate",
	maintenance = "maintenance"
}
setmetatable(wc.commands, {__index = function(tbl, key) error("No such command:", key) end})


local jump_queue = queue.new()
local jump_catch_delay = nil
local function jump_catcher(ename, addr, ...)
	local args = {...}
	if ename == "component_added" and args[1] == "warpdriveShipController" and addr == jump_queue.peek() and (not jump_catch_delay or os.time() > jump_catch_delay) then
		jump_queue.pop()
		jump_catch_delay = os.time() + wc.min_jump_interval
		component.proxy(addr).command(wc.commands.offline) --turn off the core so it won't interfere with others
		event.push("core_jumped", addr)
		return
	end
	if ename == "core_jumping" then
		jump_queue.push(addr)
	end
end

event.listen("component_added", jump_catcher)
event.listen("core_jumping", jump_catcher)

wc.wrap = function(addr, offset)
	local prx = component.proxy(addr)
	prx.movement(0, 0, 0)
	prx.rotationSteps(0) --reset rotation, don't want to deal with them bugs
	prx.command(wc.commands.offline)

	local ret = {}
	ret.offset = offset or {0, 0, 0}

	local movement = function(x, y, z)
		local px, py, pz = prx.dim_positive()
		local nx, ny, nz = prx.dim_negative()
		local sx, sy, sz = 1 + px + nx, 1 + py + ny, 1 + pz + nz
		if math.abs(x) < sx and math.abs(y) < sz and math.abs(z) < sy then return false, "too small" end
		prx.movement(x, y, z)
		return true
	end

	ret.global_to_relative = function(x, y, z, ignore_offset)
		local ox, oy, oz = prx.getOrientation()
		local cx, cy, cz = prx.position()
		local rx = x - cx
		local ry = y - cy
		local rz = z - cz
		if not ignore_offset then
			rx = rx + ret.offset.x
			ry = ry + ret.offset.y
			rz = rz + ret.offset.z
		end
		return rx * ox + rz * oz, ry, -(rx * oz) + (rz * ox) 
	end
	ret.relative_to_global = function(rx, ry, rz, ignore_offset)
		local ox, oy, oz = prx.getOrientation()
		local cx, cy, cz = prx.position()
		rx, ry, rz = rx * ox - rz * oz, ry, (rx * oz) + (rz * ox)
		if not ignore_offset then
			rx = rx - ret.offset.x
			ry = ry - ret.offset.y
			rz = rz - ret.offset.z
		end
		return rx + cx, ry + cy, rz + cz
	end
	ret.get_position = function()
		return ret.relative_to_global(0, 0, 0)
	end

	ret.jump = function()
		prx.command(wc.commands.manual)
		prx.enable(true)
		event.push("core_jumping", addr)
	end

	ret.jump_blocking = function()
		ret.jump()
		event.pull("core_jumped", addr)
	end

	ret.movement_local = function(x, y, z)
		if x and y and z then
			return movement(x, y, z)
		end
		return false, "invalid args"
	end

	ret.movement_global = function(x, y, z)
		if x and y and z then
			return movement(ret.global_to_relative(x, y, z))
		end
		return false, "invalid args"
	end

	return ret
end

return wc