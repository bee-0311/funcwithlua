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

local RUNNER_NAME = "__ee_actor_runner__"
local EXEC_MSG    = "__ee_exec__"
local runnerReady = {}

local function ensureRunner(actor)
    if runnerReady[actor] then return end

    if actor:FindFirstChild(RUNNER_NAME) then
        runnerReady[actor] = true
        return
    end

    local debugId   = tostring(actor:GetDebugId())
    local readyName = "__ee_ready_" .. debugId .. "__"
    local readyBE   = Instance.new("BindableEvent")
    readyBE.Name    = readyName
    readyBE.Parent  = game:GetService("CoreGui")

    readyBE.Event:Once(function()
        runnerReady[actor] = true
        readyBE:Destroy()
    end)

    local s        = Instance.new("Script")
    s.Name         = RUNNER_NAME
    s.Enabled      = false
    s.Source       = string.format([[
        local hs    = game:GetService("HttpService")
        local actor = script.Parent

        local readyBE = game:GetService("CoreGui"):FindFirstChild(%q)
        if readyBE then readyBE:Fire() end

        actor:BindToMessage(%q, function(code, argsJson)
            local fn, err = loadstring(code)
            if not fn then
                warn("run_on_actor compile error: " .. tostring(err))
                return
            end
            local callArgs = {}
            if argsJson and argsJson ~= "" then
                local ok, decoded = pcall(function()
                    return hs:JSONDecode(argsJson)
                end)
                if ok and type(decoded) == "table" then
                    callArgs = decoded
                end
            end
            local ok2, e = pcall(fn, table.unpack(callArgs))
            if not ok2 then
                warn("run_on_actor runtime error: " .. tostring(e))
            end
        end)
    ]], readyName, EXEC_MSG)

    s.Parent  = actor
    s.Enabled = true
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

    local hs       = game:GetService("HttpService")
    local safeArgs = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local t = type(v)
        if t == "string" or t == "number" or t == "boolean" then
            safeArgs[i] = v
        end
    end

    local argsJson = ""
    local ok, encoded = pcall(hs.JSONEncode, hs, safeArgs)
    if ok then argsJson = encoded end

    ensureRunner(actor)

    task.spawn(function()
        local elapsed = 0
        while not runnerReady[actor] and elapsed < 2 do
            task.wait(0.01)
            elapsed += 0.01
        end
        if not runnerReady[actor] then
            warn("run_on_actor: runner not ready for Actor: " .. actor.Name)
            return
        end
        actor:SendMessage(EXEC_MSG, code, argsJson)
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
env.runonactor          = run_on_actor      -- alias
env.isparallel          = isparallel
env.checkparallel       = isparallel        -- alias
env.inparallel          = isparallel        -- alias
env.create_comm_channel = create_comm_channel
env.get_comm_channel    = get_comm_channel
