local _sv = Instance.new("StringValue")
local commCache = {}

local function getCommFolder()
    local cg = game:GetService("CoreGui")
    local folder = cg:FindFirstChild("__comm_channels__")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "__comm_channels__"
        folder.Parent = cg
    end
    return folder
end


local function getNextId(folder)
    local current = folder:GetAttribute("__next_id") or 0
    local next_id = current + 1
    folder:SetAttribute("__next_id", next_id)
    return next_id
end


local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
end


local function makeEventObject(bindable)
    local pendingArgs = {}
    local argCounter  = 0

    local signal = {}

    signal.Connect = function(self, fn)
        return bindable.Event:Connect(function(id)
            local args = pendingArgs[id]
            if args then
              
                task.defer(function()
                    pendingArgs[id] = nil
                end)
                fn(table.unpack(args, 1, args.n))
            end
        end)
    end

    signal.Once = function(self, fn)
        local conn
        conn = bindable.Event:Connect(function(id)
            conn:Disconnect()
            local args = pendingArgs[id]
            if args then
          
                task.defer(function()
                    pendingArgs[id] = nil
                end)
                fn(table.unpack(args, 1, args.n))
            end
        end)
        return conn
    end


    signal.Wait = function(self)
        local thread = coroutine.running()
        local conn
        conn = bindable.Event:Connect(function(id)
            conn:Disconnect()
            local args = pendingArgs[id]
            if args then
                task.defer(function()
                    pendingArgs[id] = nil
                end)
               
                task.spawn(thread, table.unpack(args, 1, args.n))
            else
                task.spawn(thread)
            end
        end)
        return coroutine.yield()
    end

    local obj = {}

    obj.Event = signal

    obj.Fire = function(self, ...)
        argCounter += 1
        local id = argCounter
        pendingArgs[id] = table.pack(...)
        bindable:Fire(id)
    end

    obj.Connect = function(self, fn) return signal:Connect(fn) end
    obj.Once    = function(self, fn) return signal:Once(fn) end
    obj.Wait    = function(self)     return signal:Wait() end

    return obj
end

local function getactors()
    local actors = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Actor") then
            table.insert(actors, v)
        end
    end
    return actors
end

local function isparallel()
    local ok = pcall(function()
        local v = _sv.Value
        _sv.Value = v
    end)
    return not ok
end

local function run_on_actor(actor, code, ...)
    assert(
        typeof(actor) == "Instance",
        "bad argument #1 to 'run_on_actor' (Instance expected, got " .. typeof(actor) .. ")"
    )
    assert(
        type(code) == "string",
        "bad argument #2 to 'run_on_actor' (string expected, got " .. type(code) .. ")"
    )
    assert(
        actor:IsA("Actor"),
        "bad argument #1 to 'run_on_actor' (Actor expected)"
    )

    local fn, compileErr = loadstring(code)
    if not fn then
        error("run_on_actor compile error: " .. tostring(compileErr), 2)
    end

    local safeArgs = {}
    for i = 1, select("#", ...) do
        safeArgs[i] = deepCopy(select(i, ...))
    end

    task.defer(function()
        local ok, err = pcall(fn, table.unpack(safeArgs))
        if not ok then
            warn("run_on_actor runtime error: " .. tostring(err))
        end
    end)
end

local function create_comm_channel()
    local folder   = getCommFolder()
    local id       = getNextId(folder)

    local bindable = Instance.new("BindableEvent")
    bindable.Name  = tostring(id)
    bindable.Parent = folder

    local eventObj = makeEventObject(bindable)
    commCache[id]  = eventObj

    return id, eventObj
end


local function get_comm_channel(id)
    if type(id) ~= "number" then
        return nil
    end

    if commCache[id] then
        return commCache[id]
    end

    local cg     = game:GetService("CoreGui")
    local folder = cg:FindFirstChild("__comm_channels__")
    if not folder then return nil end

    local bindable = folder:FindFirstChild(tostring(id))
    if not bindable then return nil end

    local eventObj = makeEventObject(bindable)
    commCache[id]  = eventObj
    return eventObj
end

local env = getfenv(function() end)

env.getactors           = getactors
env.run_on_actor        = run_on_actor
env.isparallel          = isparallel
env.checkparallel       = isparallel
env.inparallel          = isparallel
env.create_comm_channel = create_comm_channel
env.get_comm_channel    = get_comm_channel

print("[CattStar] Actor Library loaded successfully.")
