local c = computer
local ut = c.uptime
local cmp = component
local prx = function(name) local c = cmp.list(name)(); return c and cmp.proxy(c) or error("Component not found: " .. name) end

local e = prx"eeprom"
local edata = e.getData()
local port = tonumber(edata) or 312

local m = prx"modem"
local wm = "gps_periphery_wake"
local owm = m.getWakeMessage()
m.setWakeMessage(wm)
if owm ~= wm then
	c.beep()
	c.shutdown()
	return
end 
m.open(port)
m.setStrength(0)


local mc = prx"microcontroller"
local open = function(side) mc.setSideOpen(side, true) end
local close = function(side) mc.setSideOpen(side, false) end
local side
for side = 0, 5 do
	pcall(close, side)
end
for side = 0, 5 do
	local ok = pcall(open, side)
	if ok then
		m.broadcast(port, "gps_periphery_init", side)
		close(side)
	end
end

local ctl
local deadline = ut() + 2
while true do
	local sname, la, ra, p, d, msg, key, side = computer.pullSignal(deadline - ut())
	if sname == "modem_message" and d == 0 and msg == "gps_periphery_bind" and key == la then
		open(tonumber(side))
		ctl = ra
		break
	end
	if ut() >= deadline then
		error"Init failed: bind timed out"
	end
end

--init done

while true do
	local sname, la, ra, p, d, msg = computer.pullSignal()
	if sname == "modem_message" and msg == "gps_request" then
		m.send(ctl, port, "gps_periphery_request", ra, d)
	end
end
