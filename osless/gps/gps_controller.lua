local c = computer
local ut = c.uptime
local cmp = component
local prx = function(name) local c = cmp.list(name)(); return c and cmp.proxy(c) or error("Component not found: " .. name) end

local e = prx"eeprom"
local edata = e.getData()
local _, _, port, key, x, y, z = string.find(edata, "port: (%d+), key: (%w+), anchor: %{(%-?%d+), (%-?%d+), (%-?%d+)%}")
port = tonumber(port) or 312
key = key or "admin"
x = tonumber(x) or 0
y = tonumber(y) or 0
z = tonumber(z) or 0

local m = prx"modem"
local wm = "gps_wake"
local pwm = "gps_periphery_wake"
local owm = m.getWakeMessage()
m.setWakeMessage(wm)
if owm ~= wm then
	c.beep()
	c.shutdown()
	return
end
m.open(port)

m.setStrength(1)
m.broadcast(port, pwm)

local periphery = {}
local p_count = 0
local deadline = ut() + 2
while true do
	local sname, la, ra, p, d, msg, side = computer.pullSignal(deadline - ut())
	if sname == "modem_message" and d == 0 and msg == "gps_periphery_init" then
		side = tonumber(side)
		periphery[ra] = side
		p_count = p_count + 1
		if p_count >= 3 then
			break
		end
	end
	if ut() >= deadline then
		error"Init failed: periphery init timed out"
	end
end

m.setStrength(0)
for a, s in pairs(periphery) do
	m.send(a, port, "gps_periphery_bind", a, s)
end

m.setStrength(400)
m.broadcast(port, "gps_ready")

--init done
local request_timeout = 1
local requests = {}

local function handle_request(from, role, dist)
	local ct = ut()
	if not requests[from] or requests[from].deadline <= ct then
		requests[from] = {deadline = ct + request_timeout, counter = 0}
	end
	requests[from][role] = dist
	requests[from].counter = requests[from].counter + 1
	if requests[from].counter < 4 then
		return
	end
	local r = requests[from]
	requests[from] = nil
	local main_ds = r.main ^ 2
	local coords = {}
	for i = 0, 5 do
		if r[i] then
			local rolemod = 1 - 2 * (i % 2)
			coords[math.floor(i / 2)] = rolemod * (main_ds - r[i] ^ 2 + 1) / 2
		end
	end
	for i = 0, 2 do
		coords[i] = coords[i] and math.floor(coords[i] + 0.5)
	end

	m.send(from, port, "gps_response", coords[2] and coords[2] + x, coords[0] and coords[0] + y, coords[1] and coords[1] + z)
end

while true do
	local sname, la, ra, p, d, msg, from, rd, _y, _z = computer.pullSignal()
	if sname == "modem_message" then
		if msg == "gps_request" then
			handle_request(ra, "main", d)
		elseif msg == "gps_periphery_request" then
			handle_request(from, periphery[ra], rd)
		elseif msg == "gps_anchor" and from == key then
			x = rd
			y = _y
			z = _z
			e.setData(table.concat({"port: " .. tostring(port), "key: " .. key, "anchor: {" .. table.concat({x, y, z}, ", ") .. "}"}, ", "))
		elseif msg == wm then
			m.send(ra, port, "gps_ready")
		end
	end
end
