local term = require"term"

local term_utils = {}

term_utils.ensure = function(reason)
	if not term.isAvailable() then error("Term utils: no terminal found", reason) end
end

local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function nonempty(s)
	return #s > 0
end

local function not_nil(v)
	return v ~= nil
end

term_utils.read_something = function(prompt, process, check)
	if prompt then
		term.write(prompt)
	end
	local resp = ""
	repeat
		resp = term.read()
		resp = process(resp)
		if not check(resp) then
			term.write("Invalid input!\n")
			if prompt then term.write(prompt) end
		end
	until check(resp)
	return resp
end

term_utils.read_line = function(prompt)
	return term_utils.read_something(prompt, trim, nonempty)
end

term_utils.read_number = function(prompt)
	return term_utils.read_something(prompt, tonumber, not_nil)
end

return term_utils