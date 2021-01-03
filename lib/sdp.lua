--sequenced delivery protocol

local component = require"component"
local event = require"event"

local modem = component.modem
local port = 312

modem.open(312)
modem.setStrength(400)


local function sdp_serve(remote, handler)
	local handled = {}
	local en, la, ra, p, d, op = event.pull("modem_message", modem.address, remote, port, nil, "sdp", "start")
	local function answer(...)
		modem.send(remote, p, "sdp", ...)
	end
	answer("ok")
	local function process(en, la, ra, p, d, proto, op, id, ...)
		id = math.floor(id)
		answer("ok", id)
		if not handled[id] then
			handler(...)
			handled[id] = true
		end
	end
	while true do
		local packet = {event.pull("modem_message", modem.address, remote, port, nil, "sdp")}
		if packet[7] == "end" then
			answer("ok")
			break
		end
		process(table.unpack(packet))
	end
end

return {serve = sdp_serve}