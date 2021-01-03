local sdp = require"sdp"

local modem = require"component".modem
local event = require"event"

local args = {...}

for i = 1, 7 do
	args[i] = tonumber(args[i])
	if not args[i] then
		print"Usage: netgeo_client <x> <y> <z> <lower> <exact> <higher> <attempts>"
		return
	end
end

local x, y, z, l, e, r, a = table.unpack(args)

local port = 312
modem.open(port)
modem.broadcast(port, "netgeo_wake")
local en, la, remote, p, d, msg = event.pull("modem_message", modem.address, nil, port, nil, "netgeo_ready")
modem.send(remote, port, "netgeo_scan", x, y, z, l, e, r, a)
print"Starting scanning..."
sdp.serve(remote, print)
print"Scanning done, exiting"
return