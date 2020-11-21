local structs = {}

structs.queue = function()
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

structs.set = function()
	local proxy = {}
	local data = {}
	local size = 0
	proxy.del = function(key) 
		if data[key] then size = size - 1 end
		data[key] = nil
	end
	proxy.set = function(key)
		if not data[key] then size = size + 1 end
		data[key] = true
	end
	proxy.push = proxy.set -- alias
	proxy.size = function() return size end
	proxy.is_empty = function() return size < 1 end
	proxy.get = function()
		for k, v in pairs(data) do return k end
	end
	proxy.pop = function()
		local ret = proxy.get()
		proxy.del(ret)
		return ret
	end
	return proxy
end

return structs