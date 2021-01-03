--It's too fat for eeprom, use netgeo_minified.lua instead

local cmp = component or require"component"
local prx = function(name) local c = cmp.list(name)(); return c and cmp.proxy(c) or error("Component not found: " .. name) end


local geo = prx"geolyzer"
if not geo then error"Need geolyzer to function" end


local function get_noise(dist)
	return dist * 2.0 / 33.0
end

local function oor(value, noise, anchor)
	return math.abs(value - anchor) > noise
end

local function index_to_coords(i, w, d, h)
	i = i - 1
	local ix, iy, iz
	ix = i % w
	iz = math.floor(i / w) % h
	iy = math.floor((i / w) / h)
	return ix, iy, iz
end


local function discern(x, y, z, w, d, h, lower, exact, higher, attempts)
	local area = w * d * h
	local function get_noise_for_index(i)
		local ix, iy, iz = index_to_coords(i, w, d, h)
		ix = ix + x
		iy = iy + y
		iz = iz + z
		return get_noise(math.sqrt(ix*ix + iy*iy + iz*iz))
	end

	local buf = {}
	local result = {}
	local cant_lower = {}
	local cant_higher = {}
	local nothing_to_do = false
	attempts = attempts or -1

	while not nothing_to_do and attempts ~= 0 do
		buf, err = geo.scan(x, z, y, w, d, h)
		if err ~= nil then error("Scan error: "..err) end
		attempts = attempts - 1

		nothing_to_do = true

		for i = 1, area do
			local noise = get_noise_for_index(i)
			local value = buf[i] --cached
			if result[i] then
				if oor(value, noise, exact) then
					result[i] = false
				end
			elseif result[i] == nil then
				if oor(value, noise, exact) then
					result[i] = false
				else
					cant_lower[i] = cant_lower[i] or oor(value, noise, lower)
					cant_higher[i] = cant_higher[i] or oor(value, noise, higher)
					if cant_higher[i] and cant_lower[i] then
						result[i] = true
					else
						nothing_to_do = false
					end
				end
			end
		end
	end

	return result
end

local modem = prx"modem"

modem.setWakeMessage"netgeo_wake"
modem.setStrength(400)

local port = 312
modem.open(port)

local function bcast(...)
	modem.broadcast(312, ...)
end

local remote = nil
local function relay(...)
	modem.send(remote, port, ...)
end

local messages_queue = {}
local queue_tip = 0
local next_msg = 1
local next_msg_id = 1
local function enqueue_message(str)
	if #messages_queue == 0 then
		queue_tip = 1
		next_msg = 1
	else
		queue_tip = queue_tip + 1
	end
	table.insert(messages_queue, str)
end
local function process_message_queue(timeout)
	timeout = timeout or 600
	while queue_tip >= next_msg do
		--attempt to join messages together to reduce amt of packets
		local max_packet_size = modem.maxPacketSize()
		local max_payload_size = max_packet_size - 2*4 - 3 - 6 - 8
		--can be further optimized but w/e, not here
		while queue_tip >= next_msg + 1 and string.len(messages_queue[next_msg]) + string.len(messages_queue[next_msg + 1]) + 1 <= max_payload_size do
			messages_queue[next_msg + 1] = messages_queue[next_msg].."\n"..messages_queue[next_msg + 1]
			messages_queue[next_msg] = nil --free memory
			next_msg = next_msg + 1
		end
		--
		relay("sdp", "packet", next_msg_id, messages_queue[next_msg])
		local deadline = computer.uptime() + timeout
		while true do
			if computer.uptime() > deadline then
				break
			end
			local en, la, ra, p, d, proto, ok, id = computer.pullSignal(deadline - computer.uptime())
			if en == "modem_message" and ra == remote and proto == "sdp" and ok == "ok" and id == next_msg_id then
				messages_queue[next_msg] = nil --free memory?
				next_msg = next_msg + 1
				next_msg_id = next_msg_id + 1
				computer.beep()
				break
			end
		end
		if computer.uptime() > deadline then
			break
		end
	end
end

local function sdp_endpoint(...)
	local done = false
	while not done do
		relay("sdp", ...)
		local deadline = computer.uptime() + 1
		while computer.uptime() < deadline do
			local en, la, ra, p, d, proto, ok = computer.pullSignal(deadline - computer.uptime())
			if en == "modem_message" and ra == remote and proto == "sdp" and ok == "ok" then
				done = true
				break
			end
		end
	end
end

local function scan(x, y, z, l, e, h, a)
	local function itc(i)
		return index_to_coords(i, 4, 4, 4)
	end
	local counter = 1
	for ix = -32, 28, 4 do
		for iy = -32, 28, 4 do
			for iz = -32, 28, 4 do
				local result = discern(ix, iy, iz, 4, 4, 4, l, e, h, a)
				--enqueue_message("Block #"..counter.." finished")
				counter = counter + 1
				for i = 1, 64 do
					local lx, ly, lz = itc(i)
					lx = lx + ix + x
					ly = ly + iy + y
					lz = lz + iz + z
					local coord_string = "("..lx..", "..ly..", "..lz..") -> "
					if result[i] == nil then
						enqueue_message(coord_string.."undecided")
					elseif result[i] then
						enqueue_message(coord_string.."found")
					end
				end
				if (counter - 1) % 512 == 0 then
					enqueue_message("Progress: "..(((counter - 1) / 4096.0) * 100).."% scanned.")
					process_message_queue(5)
				end
			end
		end
	end
end

bcast"netgeo_ready"

while true do
	local en, la, ra, p, d, op, a1, a2, a3, a4, a5, a6, a7 = computer.pullSignal()
	if en ~= "modem_message" then
	else
		remote = ra
		if op == "netgeo_wake" then
			relay"netgeo_ready"
		elseif op == "netgeo_scan" then
			sdp_endpoint("start")
			enqueue_message"netgeo_scanning"
			scan(a1, a2, a3, a4, a5, a6, a7)
			enqueue_message"netgeo_scan_done"
			process_message_queue()
			sdp_endpoint("end")
			computer.shutdown()
		end
	end
end