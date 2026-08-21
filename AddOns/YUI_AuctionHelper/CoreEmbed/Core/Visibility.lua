do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

local Visibility = YUI.Visibility or {}
YUI.Visibility = Visibility

local max = math.max

local STATE_KEYS = {
    "combat",
    "instance",
    "group",
    "mounted",
    "target",
    "petBattle",
    "skyriding",
    "housing",
}

local EVENT_STATE = {
    PLAYER_REGEN_DISABLED = "combat",
    PLAYER_REGEN_ENABLED = "combat",
    PLAYER_DEAD = "combat",
    ZONE_CHANGED_NEW_AREA = "instance",
    GROUP_ROSTER_UPDATE = "group",
    PLAYER_MOUNT_DISPLAY_CHANGED = "mounted",
    UPDATE_SHAPESHIFT_FORM = "mounted",
    PLAYER_TARGET_CHANGED = "target",
    PET_BATTLE_OPENING_DONE = "petBattle",
    PET_BATTLE_CLOSE = "petBattle",
    PLAYER_IS_GLIDING_CHANGED = "skyriding",
    HOUSE_PLOT_ENTERED = "housing",
    HOUSE_PLOT_EXITED = "housing",
}

local STATE_EVENTS = {
    combat = {
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_DEAD",
    },
    instance = { "ZONE_CHANGED_NEW_AREA" },
    group = { "GROUP_ROSTER_UPDATE" },
    mounted = {
        "PLAYER_MOUNT_DISPLAY_CHANGED",
        "UPDATE_SHAPESHIFT_FORM",
    },
    target = { "PLAYER_TARGET_CHANGED" },
    petBattle = { "PET_BATTLE_OPENING_DONE", "PET_BATTLE_CLOSE" },
    skyriding = { "PLAYER_IS_GLIDING_CHANGED" },
    housing = { "HOUSE_PLOT_ENTERED", "HOUSE_PLOT_EXITED" },
}

Visibility.handles = Visibility.handles or {}
Visibility.ownerHandles = Visibility.ownerHandles or {}
Visibility.moduleHandles = Visibility.moduleHandles or {}
Visibility.state = Visibility.state or {}
Visibility.handleCount = Visibility.handleCount or 0
Visibility.sequence = Visibility.sequence or 0
Visibility.listening = Visibility.listening == true
Visibility.listenerCount = Visibility.listenerCount or 0
Visibility.stats = Visibility.stats or {
    activations = 0,
    deactivations = 0,
    events = 0,
    evaluations = 0,
    callbacks = 0,
    callbackErrors = 0,
    noOpSkips = 0,
}

local function NormalizeMode(value, allowedA, allowedB)
    if value == allowedA or value == allowedB then return value end
    return "any"
end

function Visibility:NormalizeRule(rule, target)
    rule = type(rule) == "table" and rule or nil
    target = type(target) == "table" and target or {}
    local sourceHide = rule and type(rule.hide) == "table" and rule.hide or nil
    local targetHide = type(target.hide) == "table" and target.hide or {}

    target.combat = NormalizeMode(rule and rule.combat, "in", "out")
    target.instance = NormalizeMode(rule and rule.instance, "inside", "outside")
    target.group = NormalizeMode(rule and rule.group, "grouped", "solo")
    target.mounted = NormalizeMode(
        rule and rule.mounted,
        "mounted",
        "unmounted"
    )
    targetHide.noTarget = sourceHide and sourceHide.noTarget == true or false
    targetHide.housing = sourceHide and sourceHide.housing == true or false
    targetHide.skyriding = sourceHide and sourceHide.skyriding == true or false
    target.hide = targetHide
    return target
end

local function EvaluateCanonical(rule, state, bypass)
    state = type(state) == "table" and state or {}
    if state.petBattle == true then return false, "petBattle" end
    if bypass == true then return true, "bypass" end

    if rule.combat == "in" and state.combat == false then
        return false, "combat"
    end
    if rule.combat == "out" and state.combat == true then
        return false, "combat"
    end
    if rule.instance == "inside" and state.instance == false then
        return false, "instance"
    end
    if rule.instance == "outside" and state.instance == true then
        return false, "instance"
    end
    if rule.group == "grouped" and state.group == false then
        return false, "group"
    end
    if rule.group == "solo" and state.group == true then
        return false, "group"
    end
    if rule.mounted == "mounted" and state.mounted == false then
        return false, "mounted"
    end
    if rule.mounted == "unmounted" and state.mounted == true then
        return false, "mounted"
    end

    local hide = rule.hide
    if hide.noTarget == true and state.target == false then
        return false, "noTarget"
    end
    if hide.housing == true and state.housing == true then
        return false, "housing"
    end
    if hide.skyriding == true and state.skyriding == true then
        return false, "skyriding"
    end
    return true, "visible"
end

function Visibility:Evaluate(rule, state, bypass)
    return EvaluateCanonical(self:NormalizeRule(rule), state, bypass)
end

local function Invoke(handle, visible, reason)
    local callback = handle.callback
    if type(callback) == "string" then
        callback = handle.owner and handle.owner[callback]
    end
    if type(callback) ~= "function" then return false end

    local ok = pcall(
        callback,
        handle.owner,
        visible,
        reason,
        handle.context
    )
    Visibility.stats.callbacks = Visibility.stats.callbacks + 1
    if not ok then
        Visibility.stats.callbackErrors = Visibility.stats.callbackErrors + 1
    end
    return ok
end

function Visibility:_EvaluateHandle(handle, force)
    if not (handle and handle.active == true) then return false end
    self.stats.evaluations = self.stats.evaluations + 1
    local visible, reason = EvaluateCanonical(
        handle.rule,
        self.state,
        handle.bypass
    )
    local changed = handle.lastVisible ~= visible
    handle.lastReason = reason
    if force == true or changed then
        handle.lastVisible = visible
        Invoke(handle, visible, reason)
        return true
    end
    self.stats.noOpSkips = self.stats.noOpSkips + 1
    return false
end

function Visibility:_Notify()
    local cutoff = self.sequence
    for handle in pairs(self.handles) do
        if handle.active == true and handle.sequence <= cutoff then
            self:_EvaluateHandle(handle, false)
        end
    end
end

function Visibility:_ReadState(stateKey)
    local api = YUI.API and YUI.API.Visibility
    if not (api and api.Read) then return nil end
    return api.Read(stateKey)
end

function Visibility:_RefreshState(stateKey)
    local previous = self.state[stateKey]
    local current = self:_ReadState(stateKey)
    self.state[stateKey] = current
    return previous ~= current
end

function Visibility:_SetState(stateKey, current)
    local previous = self.state[stateKey]
    self.state[stateKey] = current
    return previous ~= current
end

function Visibility:_RefreshAll()
    local changed = false
    for index = 1, #STATE_KEYS do
        if self:_RefreshState(STATE_KEYS[index]) then changed = true end
    end
    return changed
end

function Visibility:OnStateEvent(event)
    if self.handleCount <= 0 then return end
    self.stats.events = self.stats.events + 1
    local changed
    if event == "PLAYER_ENTERING_WORLD" then
        changed = self:_RefreshAll()
    elseif event == "PLAYER_REGEN_DISABLED" then
        changed = self:_SetState("combat", true)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
        changed = self:_SetState("combat", false)
    else
        local stateKey = EVENT_STATE[event]
        changed = stateKey and self:_RefreshState(stateKey) or false
    end
    if changed then self:_Notify() end
end

function Visibility:_ReleaseModule(moduleId)
    local handles = self.moduleHandles[moduleId]
    if not handles then return 0 end
    local released = 0
    while next(handles) do
        local handle = next(handles)
        if self:Release(handle) then released = released + 1 end
    end
    return released
end

function Visibility:OnModuleDisabled(_, moduleId)
    if type(moduleId) == "string" and moduleId ~= "" then
        self:_ReleaseModule(moduleId)
    end
end

local function AddListener(service, eventName, handler)
    local event = YUI.Event
    local listener = event and event.On
        and event:On(eventName, handler, service, {
            moduleId = "core.visibility",
            traceName = "Visibility:" .. eventName,
        })
    if listener then
        service.listenerCount = service.listenerCount + 1
        return true
    end
    return false
end

function Visibility:_Activate()
    if self.listening then return true end
    local event = YUI.Event
    if not (event and event.On and event.OffOwner) then
        return false
    end

    self.listenerCount = 0
    AddListener(self, "PLAYER_ENTERING_WORLD", "OnStateEvent")
    AddListener(self, "YUI_MODULE_DISABLED", "OnModuleDisabled")

    local api = YUI.API and YUI.API.Visibility
    for index = 1, #STATE_KEYS do
        local stateKey = STATE_KEYS[index]
        if api and api.IsSupported and api.IsSupported(stateKey) then
            local events = STATE_EVENTS[stateKey]
            for eventIndex = 1, #events do
                AddListener(self, events[eventIndex], "OnStateEvent")
            end
        end
    end

    if self.listenerCount < 2 then
        event:OffOwner(self)
        self.listenerCount = 0
        return false
    end
    self:_RefreshAll()
    self.listening = true
    self.stats.activations = self.stats.activations + 1
    return true
end

function Visibility:_Deactivate()
    if YUI.Event and YUI.Event.OffOwner then
        YUI.Event:OffOwner(self)
    end
    self.listenerCount = 0
    self.listening = false
    for index = 1, #STATE_KEYS do
        self.state[STATE_KEYS[index]] = nil
    end
    self.stats.deactivations = self.stats.deactivations + 1
end

function Visibility:Watch(owner, rule, callback, options)
    if type(callback) ~= "function" and type(callback) ~= "string" then
        return nil, "invalid-callback"
    end
    if type(callback) == "string" and owner == nil then
        return nil, "invalid-owner"
    end
    options = type(options) == "table" and options or {}

    if self.handleCount == 0 and not self:_Activate() then
        return nil, "event-unavailable"
    end

    self.sequence = self.sequence + 1
    local handle = {
        owner = owner,
        callback = callback,
        context = options.context,
        moduleId = type(options.moduleId) == "string"
            and options.moduleId or nil,
        bypass = options.bypass == true,
        active = true,
        sequence = self.sequence,
        rule = self:NormalizeRule(rule),
    }
    self.handles[handle] = true
    self.handleCount = self.handleCount + 1

    if owner ~= nil then
        local handles = self.ownerHandles[owner]
        if not handles then
            handles = {}
            self.ownerHandles[owner] = handles
        end
        handles[handle] = true
    end
    if handle.moduleId then
        local handles = self.moduleHandles[handle.moduleId]
        if not handles then
            handles = {}
            self.moduleHandles[handle.moduleId] = handles
        end
        handles[handle] = true
    end

    self:_EvaluateHandle(handle, true)
    return handle
end

function Visibility:Update(handle, rule)
    if type(handle) ~= "table" or self.handles[handle] ~= true then
        return false, "invalid-handle"
    end
    self:NormalizeRule(rule, handle.rule)
    self:_EvaluateHandle(handle, false)
    return true
end

function Visibility:SetBypass(handle, enabled)
    if type(handle) ~= "table" or self.handles[handle] ~= true then
        return false, "invalid-handle"
    end
    enabled = enabled == true
    if handle.bypass == enabled then return true end
    handle.bypass = enabled
    self:_EvaluateHandle(handle, false)
    return true
end

function Visibility:Release(handle)
    if type(handle) ~= "table" or self.handles[handle] ~= true then
        return false
    end
    self.handles[handle] = nil

    local ownerHandles = self.ownerHandles[handle.owner]
    if ownerHandles then
        ownerHandles[handle] = nil
        if not next(ownerHandles) then self.ownerHandles[handle.owner] = nil end
    end
    local moduleHandles = self.moduleHandles[handle.moduleId]
    if moduleHandles then
        moduleHandles[handle] = nil
        if not next(moduleHandles) then
            self.moduleHandles[handle.moduleId] = nil
        end
    end

    handle.active = false
    handle.owner = nil
    handle.callback = nil
    handle.context = nil
    handle.moduleId = nil
    handle.rule = nil
    handle.lastVisible = nil
    handle.lastReason = nil
    self.handleCount = max(0, self.handleCount - 1)
    if self.handleCount == 0 then self:_Deactivate() end
    return true
end

function Visibility:ReleaseOwner(owner)
    local handles = self.ownerHandles[owner]
    if not handles then return 0 end
    local released = 0
    while next(handles) do
        local handle = next(handles)
        if self:Release(handle) then released = released + 1 end
    end
    return released
end

function Visibility:GetStats(target)
    target = type(target) == "table" and target or {}
    for key, value in pairs(self.stats) do target[key] = value end
    target.activeWatchers = self.handleCount
    target.activeListeners = self.listenerCount
    target.listening = self.listening == true
    return target
end

function Visibility:GetState(stateKey)
    if type(stateKey) ~= "string" then return nil end
    return self.state[stateKey]
end
