local SIGNAL_ARGS = {
    Touched              = { "BasePart" },
    TouchEnded           = { "BasePart" },
    Changed              = { "string" },
    ChildAdded           = { "Instance" },
    ChildRemoved         = { "Instance" },
    DescendantAdded      = { "Instance" },
    DescendantRemoving   = { "Instance" },
    AncestryChanged      = { "Instance", "Instance" },
    AttributeChanged     = { "string" },
    Event                = { "Variant" },
    OnClientEvent        = { "Variant" },
    OnServerEvent        = { "Player", "Variant" },
    InputBegan           = { "InputObject", "bool" },
    InputEnded           = { "InputObject", "bool" },
    InputChanged         = { "InputObject", "bool" },
    MouseButton1Click    = {},
    MouseButton2Click    = {},
    Activated            = { "InputObject", "int" },
}

local function get_signal_name(signal)
    local str = tostring(signal)

    return str:match("^Signal (.+)$") or str
end

local function getsignalarguments(signal)
    local name = get_signal_name(signal)
    local args = SIGNAL_ARGS[name] or { "Variant" }
    local result = {}
    for i, v in ipairs(args) do
        result[i] = v
    end
    return result
end


local SIGNAL_ARGS_INFO = {
    Touched            = { { Name = "otherPart",          Type = "BasePart"     } },
    TouchEnded         = { { Name = "otherPart",          Type = "BasePart"     } },
    Changed            = { { Name = "property",           Type = "string"       } },
    ChildAdded         = { { Name = "child",              Type = "Instance"     } },
    ChildRemoved       = { { Name = "child",              Type = "Instance"     } },
    DescendantAdded    = { { Name = "descendant",         Type = "Instance"     } },
    DescendantRemoving = { { Name = "descendant",         Type = "Instance"     } },
    AncestryChanged    = { { Name = "child",              Type = "Instance"     },
                           { Name = "parent",             Type = "Instance"     } },
    AttributeChanged   = { { Name = "attribute",          Type = "string"       } },
    Event              = { { Name = "arg0",               Type = "Variant"      } },
    OnClientEvent      = { { Name = "arg0",               Type = "Variant"      } },
    OnServerEvent      = { { Name = "player",             Type = "Player"       },
                           { Name = "arg0",               Type = "Variant"      } },
    InputBegan         = { { Name = "input",              Type = "InputObject"  },
                           { Name = "gameProcessedEvent", Type = "bool"         } },
    InputEnded         = { { Name = "input",              Type = "InputObject"  },
                           { Name = "gameProcessedEvent", Type = "bool"         } },
    InputChanged       = { { Name = "input",              Type = "InputObject"  },
                           { Name = "gameProcessedEvent", Type = "bool"         } },
    Activated          = { { Name = "inputObject",        Type = "InputObject"  },
                           { Name = "clickCount",         Type = "int"          } },
}

local function getsignalargumentsinfo(signal)
    local name    = get_signal_name(signal)
    local entries = SIGNAL_ARGS_INFO[name] or { { Name = "arg0", Type = "Variant" } }
    local result  = {}
    for i, entry in ipairs(entries) do
        result[i] = { Name = entry.Name, Type = entry.Type }
    end
    return result
end


local SIGNAL_WHITELIST = {
    { Event = "Touched",            Parent = "BasePart"        },
    { Event = "TouchEnded",         Parent = "BasePart"        },
    { Event = "Changed",            Parent = "Instance"        },
    { Event = "ChildAdded",         Parent = "Instance"        },
    { Event = "ChildRemoved",       Parent = "Instance"        },
    { Event = "DescendantAdded",    Parent = "Instance"        },
    { Event = "DescendantRemoving", Parent = "Instance"        },
    { Event = "AncestryChanged",    Parent = "Instance"        },
    { Event = "AttributeChanged",   Parent = "Instance"        },
    { Event = "Event",              Parent = "BindableEvent"   },
    { Event = "OnClientEvent",      Parent = "RemoteEvent"     },
    { Event = "OnServerEvent",      Parent = "RemoteEvent"     },
    { Event = "InputBegan",         Parent = "UserInputService"},
    { Event = "InputEnded",         Parent = "UserInputService"},
    { Event = "InputChanged",       Parent = "UserInputService"},
    { Event = "MouseButton1Click",  Parent = "GuiButton"       },
    { Event = "MouseButton2Click",  Parent = "GuiButton"       },
    { Event = "Activated",          Parent = "GuiButton"       },
}

local function getsignalwhitelist()
    local result = {}
    for i, entry in ipairs(SIGNAL_WHITELIST) do
        result[i] = { Event = entry.Event, Parent = entry.Parent }
    end
    return result
end


local REPLICATING_SIGNALS = {
    Changed            = true,
    ChildAdded         = true,
    ChildRemoved       = true,
    DescendantAdded    = true,
    DescendantRemoving = true,
    AttributeChanged   = true,
    AncestryChanged    = true,
}

local function cansignalreplicate(signal)
    local name = get_signal_name(signal)
    return REPLICATING_SIGNALS[name] == true
end


local env = getfenv(function() end)

env.getsignalarguments     = getsignalarguments
env.getsignalargumentsinfo = getsignalargumentsinfo
env.getsignalwhitelist     = getsignalwhitelist
env.cansignalreplicate     = cansignalreplicate
print("[CattStar] Signals Library loaded successfully.")
