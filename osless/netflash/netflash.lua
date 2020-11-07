local c = computer
local ut = c.uptime
local cmp = component
local err = error
local prx = function(name) local c = cmp.list(name)(); return c and cmp.proxy(c) or err("Component not found: " .. name) end

local e = prx"eeprom"
local edata = e.getData()
local _, _, port, tag, _, key, _, bios, ver = string.find(edata, "^(%d+) ([%w_]+)( ([%w_]+)( ([%w_]+) v(%d+))?)?$")
local eerr = function(issue) err("corrupt eeprom data: " .. issue) end
tag or eerr"port, tag"
port = tonumber(port) or eerr"port"
ver = ver and (tonumber(ver) or eerr"ver")

local m = prx"modem"
local wm = tag
local owm = m.getWakeMessage()
m.setWakeMessage(wm)
if wm ~= owm then
	c.beep()
	c.shutdown()
end
m.open(port)
m.setStrength(400)
local prefix = "netflash"
local function bcast(...) m.broadcast(port, prefix, ...) end
local function send(to, ...) m.send(to, port, prefix, ...) end
local function info(...) bcast(tag, "info", ...)
local serr = function(...) bcast(tag, "soft error", ...) end
err = function(...) bcast(tag, "error", ...); error(...) end
bcast(tag, "ready")

--init done
--or is it not? who knows