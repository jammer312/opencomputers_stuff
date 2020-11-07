local modem = require"component".modem
local event = require"event"

local nano = {}

nano.ops = {
	setResponsePort = "setResponsePort",
	getPowerState = "getPowerState",
	getHealth = "getHealth",
	getHunger = "getHunger",
	getAge = "getAge",
	getName = "getName",
	getExperience = "getExperience",
	getTotalInputCount = "getTotalInputCount",
	getSafeActiveInputs = "getSafeActiveInputs",
	getMaxActiveInputs = "getMaxActiveInputs",
	getInput = "getInput",
	setInput = "setInput",
	getActiveEffects = "getActiveEffects",
	saveConfiguration = "saveConfiguration"
}
setmetatable(nano.ops, {__index = function(tbl, key) error("No such nanomachines op:", key) end})

nano.port = 312
nano.timeout = 2

local function shift(ename, la, ra, p, d, nmsg, ...)
	if not ename then
		error("Nanomachines response timed out")
	end
	return ...
end

nano.op = function(op, ...)
	op = nano.ops[op]
	modem.send(nano.address, nano.port, "nanomachines", op, ...)
	return shift(event.pull(nano.timeout, "modem_message", modem.address, nano.address, nano.port, nil, "nanomachines"))
end



modem.open(nano.port)
modem.broadcast(nano.port, "nanomachines", nano.ops.setResponsePort, nano.port)
_, _, nano.address = event.pull(nano.timeout, "modem_message", modem.address, _, nano.port, nil, "nanomachines", "port", nano.port)
if not nano.address then error"Nanomachines response timed out" end

return nano