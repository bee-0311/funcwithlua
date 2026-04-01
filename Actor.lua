local _sv = Instance.new("BoolValue")
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
local function makeSignal()
    local connections = {}
    local onceList    = {}
    local waitList    = {}
    local connId      = 0

    local function fireAll(...)
        local args = table.pack(...)

    
        local onceCopy = onceList
        onceList = {}
        for _, fn in pairs(onceCopy) do
            task.spawn(fn, table.unpack(args, 1, args.n))
        end

        
        for _, fn in pairs(connections) do
            task.spawn(fn, table.unpack(args, 1, args.n))
        end

 
        local waitCopy = waitList
        waitList = {}
        for _, thread in ipairs(waitCopy) do
            task.spawn(thread, table.unpack(args, 1, args.n))
        end
    end

    local signal = {}

    signal.Connect = function(self, fn)
        connId += 1
        local id = connId
        connections[id] = fn
        return {
            Disconnect = function(self) connections[id] = nil end,
        }
    end

    signal.Once = function(self, fn)
        connId += 1
        local id = connId
        onceList[id] = fn
        return {
            Disconnect = function(self) onceList[id] = nil end,
        }
    end

    signal.Wait = function(self)
        local thread = coroutine.running()
        table.insert(waitList, thread)
        return coroutine.yield()
    end

    return signal, fireAll
end

local function makeEventObject(bindable)
    local signal, fireAll = makeSignal()
    bindable.Event:Connect(function(...)
        fireAll(...)
    end)

    local obj = {}
    obj.Event = signal
    obj.Fire = function(self, ...)
        fireAll(...)
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
        _sv.Value = _sv.Value
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

local env = getgenv()

env.getactors           = getactors
env.run_on_actor        = run_on_actor
env.runonactor          = run_on_actor
env.isparallel          = isparallel
env.checkparallel       = isparallel
env.inparallel          = isparallel
env.create_comm_channel = create_comm_channel
env.get_comm_channel    = get_comm_channel
