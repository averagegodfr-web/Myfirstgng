-- Minimal signal that passes tables by reference (BindableEvents deep-copy them).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { Fn = fn, Connected = true }
	table.insert(self._handlers, handler)
	return {
		Disconnect = function()
			handler.Connected = false
			local i = table.find(self._handlers, handler)
			if i then
				table.remove(self._handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		if handler.Connected then
			task.spawn(handler.Fn, ...)
		end
	end
end

return Signal
