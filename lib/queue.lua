local queue = {}

queue.new = function()
	local ret = {}
	local head = 0
	local tail = 0
	
	ret.size = function()
		return head - tail
	end

	ret.push = function(val)
		ret[head] = val
		head = head + 1
		return val
	end

	ret.pop = function()
		if ret.size() <= 0 then error"Empty queue pop()" end
		local _ret = ret[tail]
		ret[tail] = nil --GC
		tail = tail + 1
		return _ret
	end

	ret.peek = function()
		return ret[tail]
	end

	return ret
end

return queue