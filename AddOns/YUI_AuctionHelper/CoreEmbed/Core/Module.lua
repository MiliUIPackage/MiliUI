do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI then return end

local Runtime = YUI.Module or {}
YUI.Module = Runtime

Runtime.registry = Runtime.registry or {}
Runtime.order = Runtime.order or {}
Runtime.states = Runtime.states or {}
Runtime.capabilities = Runtime.capabilities or {}

local registry = Runtime.registry
local order = Runtime.order
local states = Runtime.states

local function Emit(event, ...)
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit(event, ...)
    end
end

local function ReportError(id, phase, err)
    local state = states[id]
    if state then
        state.status = "error"
        state.errorCount = (state.errorCount or 0) + 1
        state.lastError = tostring(err)
        state.lastPhase = phase
    end

    local message = "YUI.Module error [" .. tostring(id) .. ":" .. tostring(phase) .. "]: " .. tostring(err)
    if type(geterrorhandler) == "function" then
        local errorHandler = geterrorhandler()
        if type(errorHandler) == "function" then
            pcall(errorHandler, message)
        elseif print then
            print(message)
        end
    elseif print then
        print(message)
    end

    Emit("YUI_MODULE_ERROR", id, phase, tostring(err))
end

local function SafeCall(def, phase, ...)
    local handler = def and def[phase]
    if type(handler) == "string" then
        handler = def.owner and def.owner[handler]
    end
    if type(handler) ~= "function" then
        return true
    end

    local target = def.owner or def
    local traceRecord
    if YUI.Trace and YUI.Trace.Begin then
        local detail = tostring(def.product or "suite")
        if def.scope then
            detail = detail .. " / " .. tostring(def.scope)
        end
        traceRecord = YUI.Trace:Begin("Modules", tostring(def.id or "unknown") .. ":" .. tostring(phase), detail, {
            moduleId = tostring(def.id or "unknown"),
            phase = tostring(phase),
            durationKind = "sync",
            blocking = true,
        })
    end

    local ok, err = xpcall(function(...)
        return handler(target, ...)
    end, function(e)
        return e
    end, ...)

    if traceRecord and YUI.Trace and YUI.Trace.Finish then
        YUI.Trace:Finish(traceRecord, ok and "ok" or "error", ok and nil or err)
    end

    if not ok then
        ReportError(def.id, phase, err)
        return false
    end

    return true
end

local function EnsureState(id)
    local state = states[id]
    if not state then
        state = {
            id = id,
            status = "registered",
            initialized = false,
            enabled = false,
            errorCount = 0,
        }
        states[id] = state
    end
    return state
end

local function GetProductProfile(productId)
    productId = productId or YUI.ProductId or "suite"
    if YUI.DB and YUI.DB.GetProfile then
        local profile = YUI.DB:GetProfile(productId)
        if profile then
            return profile
        end
    end
    return nil
end

local function EnsureStore(productId)
    local profile = GetProductProfile(productId)
    if type(profile) ~= "table" then
        return nil
    end
    if type(profile.ModuleStates) ~= "table" then
        profile.ModuleStates = {}
    end
    return profile.ModuleStates
end

local function EnsureModuleStore(id)
    local def = registry[id]
    local store = EnsureStore(def and def.product)
    if not store then
        return nil
    end
    if type(store[id]) ~= "table" then
        store[id] = {}
    end
    return store[id]
end

local function DefaultCapability(name)
    if name == "core.db" then
        return YUI.DB and YUI.DB.IsReady and YUI.DB:IsReady()
    elseif name == "core.event" then
        return YUI.Event ~= nil
    elseif name == "core.locale" then
        return YUI.Locale ~= nil and type(YUI.Locale.Get) == "function"
    elseif name == "core.api" then
        return YUI.API ~= nil
    elseif name == "gui" then
        return YUI.GUI ~= nil
    elseif name == "settings" then
        return YUI.Settings ~= nil
    end
    return nil
end

local function DependencyAvailable(dep)
    if registry[dep] then
        return Runtime:Initialize(dep)
    end

    local custom = Runtime.capabilities[dep]
    if type(custom) == "function" then
        return custom()
    elseif custom ~= nil then
        return custom and true or false
    end

    local default = DefaultCapability(dep)
    if default ~= nil then
        return default and true or false
    end

    return false
end

local function NormalizeDef(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return nil
    end

    def.name = def.name or def.id
    def.dependencies = type(def.dependencies) == "table" and def.dependencies or {}
    def.product = def.product or YUI.ProductId or "suite"
    return def
end

function Runtime:RegisterCapability(name, value)
    if type(name) ~= "string" or name == "" then
        return false
    end
    self.capabilities[name] = value == nil and true or value
    return true
end

function Runtime:Register(def)
    def = NormalizeDef(def)
    if not def then
        return nil
    end

    local existing = registry[def.id]
    registry[def.id] = def
    local state = EnsureState(def.id)
    state.name = def.name
    state.product = def.product
    state.scope = def.scope
    state.parent = def.parent

    if not existing then
        table.insert(order, def.id)
    end

    SafeCall(def, "OnRegister")
    Emit("YUI_MODULE_REGISTERED", def.id, def)
    return def
end

function Runtime:Get(id)
    return registry[id]
end

function Runtime:GetState(id)
    return states[id]
end

function Runtime:IsEnabled(id)
    local def = registry[id]
    if not def then
        return false
    end

    if type(def.getEnabled) == "function" then
        local ok, enabled = pcall(def.getEnabled, def.owner or def, def)
        if ok then
            return enabled ~= false
        end
        ReportError(id, "getEnabled", enabled)
        return false
    end

    local moduleStore = EnsureModuleStore(id)
    if moduleStore and moduleStore.enabled ~= nil then
        return moduleStore.enabled == true
    end

    return def.defaultEnabled ~= false
end

function Runtime:SetEnabled(id, enabled)
    local def = registry[id]
    if not def then
        return false
    end

    enabled = enabled and true or false
    if type(def.setEnabled) == "function" then
        local ok, err = pcall(def.setEnabled, def.owner or def, enabled, def)
        if not ok then
            ReportError(id, "setEnabled", err)
            return false
        end
    else
        local moduleStore = EnsureModuleStore(id)
        if moduleStore then
            moduleStore.enabled = enabled
        end
    end

    if enabled then
        return self:Enable(id)
    end
    return self:Disable(id)
end

function Runtime:Initialize(id)
    local def = registry[id]
    if not def then
        return false
    end

    local state = EnsureState(id)
    if state.initialized then
        return true
    end
    if state.initializing then
        state.status = "blocked"
        state.blockedReason = "dependency cycle"
        return false
    end

    state.initializing = true
    state.status = "initializing"

    for _, dep in ipairs(def.dependencies) do
        if not DependencyAvailable(dep) then
            state.initializing = false
            state.status = "blocked"
            state.blockedReason = "missing dependency: " .. tostring(dep)
            return false
        end
    end

    if not SafeCall(def, "OnInitialize") then
        state.initializing = false
        return false
    end

    state.initializing = false
    state.initialized = true
    state.status = "initialized"
    Emit("YUI_MODULE_INITIALIZED", id, def)
    return true
end

function Runtime:Enable(id)
    local def = registry[id]
    if not def or not self:Initialize(id) then
        return false
    end

    local state = EnsureState(id)
    if state.enabled then
        return true
    end

    state.status = "enabling"
    if not SafeCall(def, "OnEnable") then
        return false
    end

    state.enabled = true
    state.status = "enabled"
    Emit("YUI_MODULE_ENABLED", id, def)
    return true
end

function Runtime:Disable(id)
    local def = registry[id]
    if not def then
        return false
    end

    local state = EnsureState(id)
    if not state.initialized then
        state.enabled = false
        state.status = "disabled"
        return true
    end
    if not state.enabled and state.status == "disabled" then
        return true
    end

    state.status = "disabling"
    if not SafeCall(def, "OnDisable") then
        return false
    end

    state.enabled = false
    state.status = "disabled"
    Emit("YUI_MODULE_DISABLED", id, def)
    return true
end

function Runtime:InitializeAll()
    local traceRecord
    if YUI.Trace and YUI.Trace.Begin then
        traceRecord = YUI.Trace:Begin("Login", "Runtime:InitializeAll", nil, {
            moduleId = "YUI.Module",
            phase = "InitializeAll",
            durationKind = "sync",
            blocking = true,
        })
    end

    if YUI.DB and YUI.DB.RestoreAllPersistedProfiles then
        YUI.DB:RestoreAllPersistedProfiles()
    end

    for _, id in ipairs(order) do
        if self:Initialize(id) then
            if self:IsEnabled(id) then
                self:Enable(id)
            else
                self:Disable(id)
            end
        end
    end

    if traceRecord and YUI.Trace and YUI.Trace.Finish then
        YUI.Trace:Finish(traceRecord, "ok")
    end
end

function Runtime:NotifyProfileChanged(event, database, newProfileKey)
    local changedProducts = YUI.DB and YUI.DB.databaseProducts and YUI.DB.databaseProducts[database]
    for _, id in ipairs(order) do
        local def = registry[id]
        local state = EnsureState(id)
        if def and state.initialized and (not changedProducts or not def.product or changedProducts[def.product]) then
            SafeCall(def, "OnProfileChanged", event, database, newProfileKey)
            if self:IsEnabled(id) then
                self:Enable(id)
            else
                self:Disable(id)
            end
        end
    end
end

function Runtime:Refresh(id, reason)
    local def = registry[id]
    if not def then
        return false
    end
    return SafeCall(def, "OnConfigChanged", reason or "refresh")
end

function Runtime:NotifyLayoutChanged(scope, ...)
    for _, id in ipairs(order) do
        local def = registry[id]
        local state = EnsureState(id)
        if def and state.initialized and (scope == nil or def.scope == scope or def.id == scope or def.parent == scope) then
            SafeCall(def, "OnLayoutChanged", scope, ...)
        end
    end
end

if YUI.Event and not Runtime._loginHandle then
    Runtime._loginHandle = YUI.Event:Once("YUI_LOGIN_READY", "InitializeAll", Runtime, {
        priority = 8000,
        traceName = "Runtime:InitializeAll",
        moduleId = "YUI.Module",
        phase = "YUI_LOGIN_READY",
    })
end
