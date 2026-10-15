do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, namespace = ...
local YUI = _G.YUI or namespace
if not YUI or YUI.NotificationSound then return end

-- Business configuration stays with its owner; providers only resolve/play it.
local Service = { API_VERSION = 1 }
YUI.NotificationSound = Service
local API = YUI.API and YUI.API.Sound
local owners = setmetatable({}, { __mode = "k" })
local MAX_HANDLES = 8
local kinds = { native = true, voice = true, system = true, tts = true, lsm = true, custom = true }
local channels = { Master = true, SFX = true, Music = true, Ambience = true, Dialog = true }

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function ReadSelection(selection)
    if Secret(selection) then return nil, "invalid-selection" end
    if selection == nil then return "native" end
    if type(selection) ~= "table" or getmetatable(selection) then
        return nil, "invalid-selection"
    end
    local kind, value = selection.kind, selection.value
    if Secret(kind) or type(kind) ~= "string" or not kinds[kind] then return nil, "invalid-selection" end
    local count = 0
    for key in pairs(selection) do
        count = count + 1
        if Secret(key) or count > 2 or (key ~= "kind" and key ~= "value") then return nil, "invalid-selection" end
    end
    if Secret(value) then return nil, "invalid-selection" end
    if kind == "native" then
        if value ~= nil then return nil, "invalid-selection" end
        return kind
    end
    if Secret(value) or type(value) ~= "string" or value == "" or value:find("[%z\1-\31]") then
        return nil, "invalid-selection"
    end
    local maximum = kind == "tts" and 2048 or kind == "custom" and 153 or 256
    if #value > maximum then return nil, "invalid-selection" end
    if kind == "voice" and not value:match("^VC%-%x%x%x%x%x%x%x%x$") then return nil, "invalid-selection" end
    if kind == "custom" then
        value = value:match("^%s*(.-)%s*$")
        if value == "" or value:match("^[A-Za-z]:[\\/]") or value:sub(1, 2) == "\\\\"
            or value:sub(1, 1) == "/" or value:sub(1, 1) == "\\" then
            return nil, "invalid-selection"
        end
    end
    return kind, value
end

function Service:NormalizeSelection(selection)
    local kind, value = ReadSelection(selection)
    if not kind then return nil, value end
    return { kind = kind, value = value }
end

local function Provider()
    local provider = YUI.Sound and YUI.Sound.NotificationProvider
    if not provider then return nil, false, "provider-unavailable" end
    if provider.apiVersion ~= 1 or type(provider.GetStatus) ~= "function"
        or type(provider.Resolve) ~= "function" or type(provider.Submit) ~= "function"
        or type(provider.CancelOwner) ~= "function" or type(provider.GetChoices) ~= "function" then
        return nil, false, "provider-incompatible"
    end
    local ready, reason = provider:GetStatus()
    return provider, ready == true, reason
end

function Service:GetCapabilities()
    local provider, ready, reason = Provider()
    return { provider = provider, ready = ready, reason = reason,
        sources = { native = true, lsm = true, custom = true, voice = ready, system = ready, tts = ready } }
end

local function Media()
    local stub = _G.LibStub
    if type(stub) == "table" and type(stub.GetLibrary) == "function" then
        return stub:GetLibrary("LibSharedMedia-3.0", true)
    elseif type(stub) == "function" then
        return stub("LibSharedMedia-3.0", true)
    end
end

function Service:ResolveNative(options)
    local name = options and options.nativeSound
    if Secret(name) or type(name) ~= "string" then return nil, "missing-native-sound" end
    local value = SOUNDKIT and SOUNDKIT[name]
    if Secret(value) or type(value) ~= "number" or value <= 0 then return nil, "missing-native-sound" end
    return { kind = "kit", value = value }
end

local function ResolveLocal(kind, value, options)
    if kind == "native" then return Service:ResolveNative(options) end
    if kind == "custom" then return { kind = "file", value = value } end
    if kind == "lsm" then
        local media = Media()
        local file = media and media.Fetch and media:Fetch("sound", value, true)
        if not Secret(file) and ((type(file) == "string" and file ~= "") or (type(file) == "number" and file > 1)) then
            return { kind = "file", value = file }
        end
        return nil, "missing-sound"
    end
    return nil, "provider-unavailable"
end

function Service:GetSelectionState(selection, options)
    local normalized, reason = self:NormalizeSelection(selection)
    local provider, ready, capabilityReason = Provider()
    local resource
    if normalized then
        if ready then resource, reason = provider:Resolve(normalized, options)
        else resource, reason = ResolveLocal(normalized.kind, normalized.value, options) end
    end
    return { selection = normalized, effective = resource and normalized or { kind = "native" },
        backend = ready and "system" or "local", reason = reason or capabilityReason,
        available = resource ~= nil, muted = capabilityReason == "sound-disabled" or capabilityReason == "module-disabled" }
end

function Service:GetChoices(source, query, current, options)
    source = source or "all"
    query = type(query) == "string" and query:lower() or ""
    local result = {}
    local function Add(kind, value, label, available)
        label = label or value or kind
        if query == "" or label:lower():find(query, 1, true) or (value and value:lower():find(query, 1, true)) then
            result[#result + 1] = { kind = kind, value = value, label = label, available = available ~= false }
        end
    end
    if source == "all" or source == "native" then
        local locale = YUI.Locale and YUI.Locale:Get("Core")
        Add("native", nil, locale and locale["notification.sound.native"] or "Native sound", self:ResolveNative(options) ~= nil)
    end
    if source == "all" or source == "lsm" then
        local media = Media()
        local hash = media and media.HashTable and media:HashTable("sound")
        for name, file in pairs(type(hash) == "table" and hash or {}) do
            if name ~= "None" and file ~= 1 and type(name) == "string" then Add("lsm", name, name) end
        end
    end
    local provider, ready = Provider()
    if ready and (source == "all" or source == "voice" or source == "system") then
        for _, choice in ipairs(provider:GetChoices(source, options) or {}) do
            Add(choice.kind, choice.value, choice.label, choice.available)
        end
    end
    table.sort(result, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.label < b.label
    end)
    return result
end

local function State(owner)
    local state = owners[owner]
    if not state then state = { handles = {}, providers = {} }; owners[owner] = state end
    return state
end

local function Prune(state)
    for index = #state.handles, 1, -1 do
        if API and API.IsPlaying and API.IsPlaying(state.handles[index]) == false then
            table.remove(state.handles, index)
        end
    end
end

local function LocalPlay(owner, kind, value, options, preview)
    local state = State(owner)
    Prune(state)
    if #state.handles >= MAX_HANDLES then
        -- Some clients cannot query completion. Retire an owned old handle
        -- only after a successful stop, without a polling timer or lost handle.
        local oldest = state.handles[1]
        if API and API.IsPlaying and API.IsPlaying(oldest) == nil and API.Stop and API.Stop(oldest) then
            table.remove(state.handles, 1)
        else return false, "handle-budget" end
    end
    local resource, reason = ResolveLocal(kind, value, options)
    local fallback = resource == nil
    if not resource then
        local nativeReason
        resource, nativeReason = Service:ResolveNative(options)
        if not resource then return false, nativeReason or reason end
    end
    local issue = API and API.GetOutputIssue and API.GetOutputIssue()
    if issue then return false, issue end
    local channel = options and options.defaultChannel
    channel = channels[channel] and channel or "Master"
    local function Play(part)
        local play = API and (part.kind == "kit" and API.PlayKit or API.PlayFile)
        if not play then return false end
        return play(part.value, channel)
    end
    local played, handle = Play(resource)
    if not played and resource.kind ~= "kit" then
        issue = API and API.GetOutputIssue and API.GetOutputIssue()
        if issue then return false, issue end
        local native = Service:ResolveNative(options)
        if native then played, handle = Play(native); fallback = true end
    end
    if played and type(handle) == "number" and not Secret(handle) then
        state.handles[#state.handles + 1] = handle
    end
    state.lastReason = played and (fallback and (reason or "native-fallback") or "played") or "play-failed"
    return played == true, state.lastReason
end

local function Request(owner, key, selection, options, preview)
    if Secret(owner) or type(owner) ~= "table" or Secret(key) or type(key) ~= "string" or key == "" then
        return false, "invalid-request"
    end
    local kind, value = ReadSelection(selection)
    if not kind then kind, value = "native", nil end
    local provider, ready, reason = Provider()
    if reason == "module-disabled" or (not preview and reason == "sound-disabled") then return false, reason end
    if ready then
        -- Keep every provider used by this owner so late capability changes
        -- cannot strand requests in an earlier provider's queue.
        local state = State(owner)
        state.providers[provider] = true
        return provider:Submit(owner, key, { kind = kind, value = value }, options, preview)
    end
    return LocalPlay(owner, kind, value, options, preview)
end

function Service:Play(owner, key, selection, options)
    return Request(owner, key, selection, options, false)
end

function Service:Preview(owner, selection, options)
    if not self:CancelOwner(owner) then return false, "stop-failed" end
    return Request(owner, "preview", selection, options, true)
end

function Service:CancelOwner(owner)
    if Secret(owner) or type(owner) ~= "table" then return false, "invalid-request" end
    local state = owners[owner]
    if not state then return true end
    local cleared = true
    for provider in pairs(state.providers) do
        if provider:CancelOwner(owner) == false then cleared = false else state.providers[provider] = nil end
    end
    Prune(state)
    for index = #state.handles, 1, -1 do
        if API and API.Stop and API.Stop(state.handles[index]) then
            table.remove(state.handles, index)
        else cleared = false end
    end
    if cleared then owners[owner] = nil end
    return cleared
end

function Service:GetDiagnostics(owner)
    local state = not Secret(owner) and type(owner) == "table" and owners[owner] or nil
    if state then Prune(state) end
    return { handles = state and #state.handles or 0, lastReason = state and state.lastReason,
        capabilities = self:GetCapabilities() }
end
