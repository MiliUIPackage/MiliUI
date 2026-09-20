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
    UPDATE_SHAPESHIFT_FORMS = "mounted",
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
        "UPDATE_SHAPESHIFT_FORMS",
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

local BRANCHES = { "inCombat", "outOfCombat" }
local MODES = { always = true, hidden = true, hover = true, target = true }

-- Configuration normalization is a cold path. Runtime evaluation reads canonical rules.
function Visibility:NormalizeBranches(rule, target)
    rule = type(rule) == "table" and rule or {}
    target = type(target) == "table" and target or {}
    target.version = 2
    for _, key in ipairs(BRANCHES) do
        local source = type(rule[key]) == "table" and rule[key] or {}
        local hide = type(source.hide) == "table" and source.hide or {}
        local branch = type(target[key]) == "table" and target[key] or {}
        branch.mode = MODES[source.mode] and source.mode or "always"
        branch.hide = branch.hide or {}
        branch.hide.mounted = NormalizeMode(hide.mounted, "mounted", "unmounted")
        branch.hide.skyriding = hide.skyriding == true
        branch.hide.housing = hide.housing == true
        target[key] = branch
    end
    return target
end

function Visibility:ValidateBranches(rule, capabilities)
    if type(rule) ~= "table" or rule.version ~= 2 then return false, "invalid-visibility-version" end
    for key in pairs(rule) do
        if key ~= "version" and key ~= "inCombat" and key ~= "outOfCombat" then return false, "unknown-visibility-field" end
    end
    for _, key in ipairs(BRANCHES) do
        local branch = rule[key]
        if type(branch) ~= "table" or not MODES[branch.mode] then return false, "invalid-visibility-mode" end
        if branch.mode == "hover" and capabilities and capabilities.hover == false then
            return false, "hover-unavailable"
        end
        local hide = branch.hide
        if type(hide) ~= "table" or (hide.mounted ~= "any" and hide.mounted ~= "mounted" and hide.mounted ~= "unmounted")
            or type(hide.skyriding) ~= "boolean" or type(hide.housing) ~= "boolean" then
            return false, "invalid-visibility-hide"
        end
        for field in pairs(branch) do
            if field ~= "mode" and field ~= "hide" then return false, "unknown-visibility-field" end
        end
        for field in pairs(hide) do
            if field ~= "mounted" and field ~= "housing" and field ~= "skyriding" then return false, "unknown-visibility-field" end
        end
    end
    return true
end

function Visibility:MigrateActionBar(mode, hideSkyriding)
    local rule = self:NormalizeBranches()
    for _, key in ipairs(BRANCHES) do
        local branch = rule[key]
        if mode == "mouseover" then branch.mode = "hover"
        elseif mode == "hidden" or (mode == "combat" and key == "outOfCombat")
            or (mode == "outOfCombat" and key == "inCombat") then branch.mode = "hidden" end
        if mode == "mounted" then branch.hide.mounted = "unmounted"
        elseif mode == "unmounted" then branch.hide.mounted = "mounted" end
        -- The accepted migration deliberately drops this obsolete combination.
        branch.hide.skyriding = mode ~= "mouseover" and hideSkyriding == true
    end
    return rule
end

function Visibility:MigrateGroup(rule)
    if type(rule) == "table" and rule.version == 2 then return self:NormalizeBranches(rule) end
    local result = self:NormalizeBranches()
    rule = type(rule) == "table" and rule or {}
    local hide = type(rule.hide) == "table" and rule.hide or {}
    for _, key in ipairs(BRANCHES) do
        local branch = result[key]
        if (rule.combat == "in" and key == "outOfCombat") or (rule.combat == "out" and key == "inCombat") then
            branch.mode = "hidden"
        elseif hide.noTarget then branch.mode = "target" end
        branch.hide.mounted = rule.mounted == "mounted" and "unmounted"
            or rule.mounted == "unmounted" and "mounted" or "any"
        branch.hide.housing = hide.housing == true
        branch.hide.skyriding = hide.skyriding == true
    end
    return result
end

function Visibility:SameBranches(left, right, effective)
    if not (left and right) then return left == right end
    for _, key in ipairs(BRANCHES) do
        local a, b = left[key], right[key]
        if not (a and b) or a.mode ~= b.mode then return false end
        if not effective or (a.mode ~= "hidden" and a.mode ~= "hover") then
            if a.hide.mounted ~= b.hide.mounted or a.hide.skyriding ~= b.hide.skyriding
                or a.hide.housing ~= b.hide.housing then return false end
        end
    end
    return true
end

function Visibility:GetBranch(rule, combat)
    return rule and rule[combat == true and "inCombat" or "outOfCombat"]
end

function Visibility:HasActiveHides(branch)
    return branch and branch.mode ~= "hidden" and branch.mode ~= "hover"
        and (branch.hide.mounted ~= "any" or branch.hide.skyriding or branch.hide.housing) or false
end

function Visibility:NormalizeRule(rule, target)
    if type(rule) == "table" and rule.version == 2 then
        return self:NormalizeBranches(rule, target)
    end
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
    target.skyriding = NormalizeMode(
        rule and rule.skyriding,
        "in",
        "out"
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
    if bypass == true or (bypass == "outOfCombat" and state.combat ~= true) then return true, "bypass" end

    if rule.version == 2 then
        local branch = Visibility:GetBranch(rule, state.combat)
        if branch.mode == "hidden" then return false, "hidden" end
        if branch.mode == "hover" then return true, "hover" end
        if branch.mode == "target" and state.target == false then return false, "noTarget" end
        local hide = branch.hide
        if (hide.mounted == "mounted" and state.mounted == true)
            or (hide.mounted == "unmounted" and state.mounted == false) then return false, "mounted" end
        if hide.housing and state.housing == true then return false, "housing" end
        if hide.skyriding and state.skyriding == true then return false, "skyriding" end
        return true, "visible"
    end

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
    if rule.skyriding == "in" and state.skyriding ~= true then
        return false, "skyriding"
    end
    if rule.skyriding == "out" and state.skyriding == true then
        return false, "skyriding"
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
    if handle.backend == "secure" then
        if handle.pendingRelease then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then self:Release(handle) end
            return false
        end
        local applied, err = self:_ApplySecure(handle)
        if applied == false and err then return false, err end
    end
    self.stats.evaluations = self.stats.evaluations + 1
    local visible, reason = EvaluateCanonical(
        handle.rule,
        self.state,
        handle.bypass
    )
    local changed = handle.lastVisible ~= visible
        or (handle.rule.version == 2 and (handle.lastReason == "hover") ~= (reason == "hover"))
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
    if event == "UPDATE_SHAPESHIFT_FORMS" or event == "PLAYER_ENTERING_WORLD" then self.formsDirty = true end
    if (event == "HOUSE_PLOT_ENTERED" or event == "HOUSE_PLOT_EXITED") and _G.C_Timer and _G.C_Timer.NewTimer then
        if not self.housingTimer then
            self.housingTimer = _G.C_Timer.NewTimer(0, function()
                self.housingTimer = nil
                if self.handleCount > 0 and self:_RefreshState("housing") then self:_Notify() end
            end)
        end
        return
    end
    local changed
    if event == "PLAYER_ENTERING_WORLD" then
        changed = self:_RefreshAll()
    elseif event == "PLAYER_REGEN_DISABLED" then
        changed = self:_SetState("combat", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        changed = self:_SetState("combat", false)
        self:_RefreshState("housing")
        changed = true
    elseif event == "PLAYER_DEAD" then
        changed = self:_RefreshState("combat")
    else
        local stateKey = EVENT_STATE[event]
        changed = stateKey and self:_RefreshState(stateKey) or false
    end
    if changed or event == "UPDATE_SHAPESHIFT_FORMS" or event == "PLAYER_ENTERING_WORLD" then self:_Notify() end
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
    self.formsDirty = true
    self:_RefreshAll()
    self.listening = true
    self.stats.activations = self.stats.activations + 1
    return true
end

function Visibility:_Deactivate()
    if self.housingTimer then self.housingTimer:Cancel(); self.housingTimer = nil end
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
        bypass = options.bypass == "outOfCombat" and "outOfCombat" or options.bypass == true,
        active = true,
        sequence = self.sequence,
        rule = self:NormalizeRule(rule),
        backend = options.backend,
        target = options.target,
        guard = options.guard,
        capabilities = options.capabilities,
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
    if handle.backend then
        local valid, err = self:ValidateBranches(rule, handle.capabilities)
        if not valid then return false, err end
        if not self:SameBranches(handle.rule, rule) then handle.driverDirty = true end
    end
    self:NormalizeRule(rule, handle.rule)
    local _, err = self:_EvaluateHandle(handle, false)
    if err then return false, err end
    return true
end

function Visibility:SetBypass(handle, enabled)
    if type(handle) ~= "table" or self.handles[handle] ~= true then
        return false, "invalid-handle"
    end
    enabled = enabled == "outOfCombat" and "outOfCombat" or enabled == true
    if handle.bypass == enabled then return true end
    handle.bypass = enabled
    handle.driverDirty = true
    self:_EvaluateHandle(handle, false)
    return true
end

function Visibility:Refresh()
    if self.handleCount <= 0 or self.listening ~= true then return false end
    local changed = self:_RefreshAll()
    if changed then self:_Notify() end
    return changed
end

function Visibility:Release(handle)
    if type(handle) ~= "table" or self.handles[handle] ~= true then
        return false
    end
    local ownerHandles = self.ownerHandles[handle.owner]
    if ownerHandles then
        ownerHandles[handle] = nil
        if not next(ownerHandles) then self.ownerHandles[handle.owner] = nil end
    end
    local moduleHandles = self.moduleHandles[handle.moduleId]
    if moduleHandles then
        moduleHandles[handle] = nil
        if not next(moduleHandles) then self.moduleHandles[handle.moduleId] = nil end
    end

    if handle.backend == "secure" then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            handle.pendingRelease = true
            return true
        end
        if handle.driver then _G.UnregisterStateDriver(handle.target, "visibility") end
        self.secureTargets[handle.target] = nil
        handle.target, handle.driver, handle.guard = nil, nil, nil
    end
    self.handles[handle] = nil
    handle.active = false
    handle.owner = nil
    handle.callback = nil
    handle.context = nil
    handle.moduleId = nil
    handle.rule = nil
    handle.capabilities = nil
    handle.lastVisible = nil
    handle.lastReason = nil
    self.handleCount = max(0, self.handleCount - 1)
    if self.handleCount == 0 then self:_Deactivate() end
    return true
end

-- Explicit backends share registration, state subscriptions and ownership. Only this
-- backend owns the visibility state attribute; paging and other attributes are untouched.
Visibility.secureTargets = Visibility.secureTargets or setmetatable({}, { __mode = "k" })

function Visibility:CompileSecure(rule, housing, guard, bypass)
    local parts = {}
    local function add(condition, result)
        parts[#parts + 1] = (condition ~= "" and "[" .. condition .. "] " or "") .. result
    end
    local api = YUI.API and YUI.API.Visibility
    if api and api.IsSupported and api.IsSupported("petBattle") then add("petbattle", "hide") end
    for _, key in ipairs(BRANCHES) do
        local branch = rule[key]
        local combat = key == "inCombat" and "combat" or "nocombat"
        if bypass == true or (bypass == "outOfCombat" and key == "outOfCombat") then
            add(combat, "show")
        elseif branch.mode == "hidden" then
            add(combat, "hide")
        else
            if branch.mode ~= "hover" then
                local hide = branch.hide
                if hide.housing and housing == true then add(combat, "hide") end
                if hide.mounted == "mounted" then
                    add(combat .. ",mounted", "hide")
                    if self.travelForms then add(combat .. ",form:" .. self.travelForms, "hide") end
                elseif hide.mounted == "unmounted" then
                    add(combat .. ",nomounted" .. (self.travelForms and ",noform:" .. self.travelForms or ""), "hide")
                end
                if hide.skyriding and YUI.IsRetail then add(combat .. ",advflyable,flying", "hide") end
                if branch.mode == "target" then add(combat .. ",@target,noexists", "hide") end
            end
            add(combat, "show")
        end
    end
    parts[#parts + 1] = "show"
    local user = table.concat(parts, "; ")
    if not guard or guard == "show" then return user end
    -- Compose ordered decision lists, including alternative bracket conditions.
    local combined = {}
    for clause in guard:gmatch("[^;]+") do
        local conditions, result = clause:match("^%s*(.-)%s*(%a+)%s*$")
        if result == "hide" then
            combined[#combined + 1] = clause
        elseif result == "show" then
            for item in user:gmatch("[^;]+") do
                local userConditions, userResult = item:match("^%s*(.-)%s*(%a+)%s*$")
                if conditions == "" then
                    combined[#combined + 1] = item
                else
                    for condition in conditions:gmatch("%[([^%]]*)%]") do
                        local extra = userConditions:match("%[([^%]]*)%]")
                        combined[#combined + 1] = "[" .. condition .. (extra and "," .. extra or "") .. "] " .. userResult
                    end
                end
            end
        end
    end
    return table.concat(combined, "; ")
end

function Visibility:_ApplySecure(handle)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    if self.formsDirty or not self.formsInitialized then
        local api = YUI.API and YUI.API.Visibility
        self.travelForms = api and api.GetTravelFormCondition and api.GetTravelFormCondition() or nil
        self.formsDirty, self.formsInitialized = nil, true
        self.formsRevision = (self.formsRevision or 0) + 1
    end
    if handle.driver and not handle.driverDirty and handle.housing == self.state.housing
        and handle.formsRevision == self.formsRevision then return true end
    local driver = self:CompileSecure(handle.rule, self.state.housing, handle.guard, handle.bypass)
    if driver ~= handle.driver then
        local ok, err = pcall(_G.RegisterStateDriver, handle.target, "visibility", driver)
        if not ok then
            handle.secureError = err
            self.stats.secureErrors = (self.stats.secureErrors or 0) + 1
            return false, err
        end
        handle.driver = driver
        handle.secureError = nil
        self.stats.secureWrites = (self.stats.secureWrites or 0) + 1
    end
    handle.housing = self.state.housing
    handle.formsRevision = self.formsRevision
    handle.driverDirty = nil
    return true
end

function Visibility:Register(options)
    if type(options) ~= "table" or (options.backend ~= "event" and options.backend ~= "secure") then
        return nil, "explicit-backend-required"
    end
    local valid, err = self:ValidateBranches(options.rule, options.capabilities)
    if not valid then return nil, err end
    if options.backend == "event" and options.target and options.target.IsProtected and options.target:IsProtected() then
        return nil, "protected-target-requires-secure"
    end
    if options.backend == "secure" then
        if _G.InCombatLockdown and _G.InCombatLockdown() then return nil, "combat-lockdown" end
        if not (options.target and options.target.IsProtected and options.target:IsProtected()) then
            return nil, "protected-target-required"
        end
        if not (_G.RegisterStateDriver and _G.UnregisterStateDriver) then return nil, "secure-driver-unavailable" end
        if self.secureTargets[options.target] then return nil, "visibility-target-owned" end
    end
    local handle, code = self:Watch(options.owner, options.rule, options.callback, options)
    if handle and handle.secureError then
        local err = handle.secureError
        self:Release(handle)
        return nil, err
    end
    if handle and options.backend == "secure" then self.secureTargets[options.target] = handle end
    return handle, code
end

function Visibility:SetGuard(handle, guard)
    if not (self.handles[handle] and handle.backend == "secure") then return false end
    if handle.guard ~= guard then handle.guard = guard; handle.driverDirty = true end
    return self:_ApplySecure(handle)
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
