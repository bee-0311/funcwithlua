--!nocheck
--!nolint


local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = {
        _bindable = Instance.new("BindableEvent"),
        _connections = {},
        _onceFlags = {}
    }
    return setmetatable(self, Signal)
end

function Signal:Connect(callback)
    local connection = {
        Connected = true,
        _callback = callback,
        _signal = self,
        Disconnect = function()
            connection.Connected = false
        end
    }
    table.insert(self._connections, connection)
    

    return setmetatable({}, {
        __index = function(_, key)
            if key == "Disconnect" then
                return function()
                    connection.Connected = false
                end
            elseif key == "Connected" then
                return connection.Connected
            end
        end
    })
end

function Signal:Once(callback)
    local fired = false
    local connection
    connection = self:Connect(function(...)
        if not fired then
            fired = true
            callback(...)
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end
    end)
    return connection
end

function Signal:Wait()
    return self._bindable.Event:Wait()
end

function Signal:Fire(...)
    self._bindable:Fire(...)

    for _, conn in ipairs(self._connections) do
        if conn.Connected then
            task.spawn(conn._callback, ...)
        end
    end
end


getgenv().Signal = Signal


return {
    status = 200,
    message = "Signal is ready"
}
