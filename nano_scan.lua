local db_name_prefix = "nanomachines"

local nano = require"nano"
require"component".modem.setStrength(2)

local db = require"db".load(db_name_prefix.."_"..nano.address)

local _, inputs = nano.op(nano.ops.getTotalInputCount)
inputs = math.floor(inputs) --cast it to int

print"Resetting state"

for i = 1, inputs do
	nano.op(nano.ops.setInput, i, false)
end

print"Done, proceeding to scan"

local function ewrap(what, recover_on_fail)
	status, err = pcall(what)
	if not status and not recover_on_fail(err) then error"failed to recover" end
end

if not db[""..inputs] then
	print"Scanning singular inputs"
	for i = 1, inputs do
		if db[""..i] then
		else
			ewrap(function()
				nano.op(nano.ops.setInput, i, true)
				local _, effects = nano.op(nano.ops.getActiveEffects)
				db[""..i] = effects
				if effects ~= "{}" then
					print(i, effects)
				end
				nano.op(nano.ops.setInput, i, false)
			end, function(err) db[""..i] = "?harm?"; return false end)
		end
	end
	print"Done"
else
	print"Singular inputs already scanned, skipping"
end

local function is_bad(i)
	return db[""..i] and (db[""..i]:find"harm" or db[""..i]:find"poison" or db[""..i]:find"wither")
end

if not db[inputs.." "..(inputs - 1)] then
	print"Scanning dual inputs"
	for i1 = 1, inputs do
		if db[i1.." "..inputs] then
		elseif is_bad(i1) then
			print(i1, "harmful input, skipping")
		else
			nano.op(nano.ops.setInput, i1, true)
			for i2 = i1 + 1, inputs do
				if db[i1.." "..i2] then
				elseif is_bad(i2) then
					print(i1, i2, "harmful input, skipping")
				else
					ewrap(function()
						nano.op(nano.ops.setInput, i2, true)
						local _, effects = nano.op(nano.ops.getActiveEffects)
						db[i1.." "..i2] = effects
						if effects ~= "{}" then
							print(i1, i2, effects)
						end
						nano.op(nano.ops.setInput, i2, false)
					end, function(err) db[i1..""..i2] = "?harm?"; return false end)
				end
			end
			nano.op(nano.ops.setInput, i1, false)
		end
	end
	print"Done"
else
	print"Dual inputs already scanned, skipping"
end
print"Nothing else to do"