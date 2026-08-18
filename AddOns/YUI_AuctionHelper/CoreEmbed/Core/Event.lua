local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

-- 事件系统 (Event System)
YUI.f = YUI.f or CreateFrame("Frame")
YUI.f.registeredEvents = YUI.f.registeredEvents or {}

local Event = YUI.Event or {}
YUI.Event = Event

Event.listeners = Event.listeners or {}
Event.ownerListeners = Event.ownerListeners or {}
Event.stats = Event.stats or {}
Event.normalCounts = Event.normalCounts or {}
Event.unitRegistrations = Event.unitRegistrations or {}
Event.explicitEvents = Event.explicitEvents or {}
Event.sequence = Event.sequence or 0
Event.debug = Event.debug or false

local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local concat = table.concat
local unpack = unpack
local next = next
local API = YUI.WOW_API
local CombatAPI = YUI.API and YUI.API.Combat or API

local function Now()
    if CombatAPI and CombatAPI.GetTime then
        return CombatAPI.GetTime()
    end
    return 0
end

local function CopyOptions(options)
    local result = {}
    if type(options) == "table" then
        for key, value in pairs(options) do
            result[key] = value
        end
    end
    return result
end

local function CopyArgs(...)
    local count = select("#", ...)
    local args = {}
    for i = 1, count do
        args[i] = select(i, ...)
    end
    return args, count
end

local function GetDelay(value)
    value = tonumber(value)
    if value and value > 0 then
        return value
    end
    return nil
end

local function GetUnits(options)
    if type(options) ~= "table" then
        return nil, nil
    end

    local set = nil
    local units = nil

    local function AddUnit(unit)
        if type(unit) ~= "string" or unit == "" then
            return
        end

        if not set then
            set = {}
            units = {}
        end

        if not set[unit] then
            set[unit] = true
            tinsert(units, unit)
        end
    end

    AddUnit(options.unit)

    if type(options.units) == "table" then
        for _, unit in ipairs(options.units) do
            AddUnit(unit)
        end
    else
        AddUnit(options.units)
    end

    if units then
        tsort(units)
    end

    return units, set
end

local function GetStatsTable(self, event)
    local stats = self.stats[event]
    if not stats then
        stats = {
            fireCount = 0,
            listenerCalls = 0,
            errorCount = 0,
            throttleCount = 0,
            debounceCount = 0,
        }
        self.stats[event] = stats
    end
    return stats
end

local function CountListeners(list)
    local count = 0
    if not list then
        return count
    end

    for _, listener in ipairs(list) do
        if listener.active then
            count = count + 1
        end
    end

    return count
end

local function CountOwners(list)
    local owners = {}
    local count = 0
    if not list then
        return count
    end

    for _, listener in ipairs(list) do
        if listener.active and listener.owner ~= nil and not owners[listener.owner] then
            owners[listener.owner] = true
            count = count + 1
        end
    end

    return count
end

local function UnitKey(units)
    if not units or #units == 0 then
        return nil
    end
    return concat(units, "\001")
end

local function CallListener(listener, event, ...)
    local handler = listener.handler
    local owner = listener.owner

    if listener.legacy then
        if type(handler) == "string" then
            local method = owner and owner[handler]
            if type(method) == "function" then
                return method(owner, ...)
            end
            return
        end

        if owner ~= nil then
            return handler(owner, ...)
        end

        return handler(...)
    end

    if type(handler) == "string" then
        local method = owner and owner[handler]
        if type(method) == "function" then
            return method(owner, event, ...)
        end
        return
    end

    return handler(event, ...)
end

local function GetOwnerTraceName(owner)
    if type(owner) == "table" then
        return owner.traceName or owner.name or owner.id or owner.moduleId or owner.Name
    end
    if owner ~= nil then
        return tostring(owner)
    end
    return nil
end

local function GetListenerTraceName(listener)
    if listener.traceName and listener.traceName ~= "" then
        return listener.traceName
    end

    local ownerName = GetOwnerTraceName(listener.owner)
    if ownerName and type(listener.handler) == "string" then
        return tostring(ownerName) .. "." .. tostring(listener.handler)
    end
    if ownerName then
        return tostring(ownerName)
    end
    if type(listener.handler) == "string" then
        return tostring(listener.handler)
    end
    return "anonymous"
end

function Event:_Debug(...)
    if self.debug and YUI.Debug then
        YUI:Debug("EventBus", ...)
    end
end

function Event:_RecordError(event, err)
    local stats = GetStatsTable(self, event)
    stats.errorCount = stats.errorCount + 1
    stats.lastError = tostring(err)
    stats.lastErrorTime = Now()

    local message = "YUI.Event listener error [" .. tostring(event) .. "]: " .. tostring(err)
    if type(geterrorhandler) == "function" then
        local errorHandler = geterrorhandler()
        if type(errorHandler) == "function" then
            pcall(errorHandler, message)
            return
        end
    end

    if YUI.Print then
        YUI:Print(message)
    else
        print(message)
    end
end

function Event:_RegisterFrameEvent(event)
    if YUI.f.registeredEvents[event] then
        return
    end

    local success = pcall(YUI.f.RegisterEvent, YUI.f, event)
    YUI.f.registeredEvents[event] = success or "custom"
    self:_Debug("RegisterEvent", event, success and "ok" or "custom")
end

function Event:_AcquireNormalEvent(event)
    self.normalCounts[event] = (self.normalCounts[event] or 0) + 1
    self:_RegisterFrameEvent(event)
end

function Event:_ReleaseNormalEvent(event)
    local count = (self.normalCounts[event] or 0) - 1
    if count > 0 then
        self.normalCounts[event] = count
        return
    end

    self.normalCounts[event] = nil

    if self.explicitEvents[event] then
        return
    end

    if YUI.f.registeredEvents[event] == true then
        pcall(YUI.f.UnregisterEvent, YUI.f, event)
    end

    YUI.f.registeredEvents[event] = nil
    self:_Debug("UnregisterEvent", event)
end

function Event:_RegisterUnitEvent(listener)
    local event = listener.event
    local key = listener.unitKey
    if not key then
        return
    end

    local eventRegs = self.unitRegistrations[event]
    if not eventRegs then
        eventRegs = {}
        self.unitRegistrations[event] = eventRegs
    end

    local registration = eventRegs[key]
    if not registration then
        local frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, unitEvent, ...)
            Event:_Dispatch(unitEvent, "unit", key, ...)
        end)

        local success = pcall(frame.RegisterUnitEvent, frame, event, unpack(listener.units))
        registration = {
            count = 0,
            frame = frame,
            registered = success,
            units = listener.units,
        }
        eventRegs[key] = registration

        if not success then
            local stats = GetStatsTable(self, event)
            stats.lastError = "RegisterUnitEvent failed"
            stats.lastErrorTime = Now()
        end

        self:_Debug("RegisterUnitEvent", event, key, success and "ok" or "failed")
    end

    registration.count = registration.count + 1
end

function Event:_ReleaseUnitEvent(listener)
    local event = listener.event
    local key = listener.unitKey
    if not key then
        return
    end

    local eventRegs = self.unitRegistrations[event]
    local registration = eventRegs and eventRegs[key]
    if not registration then
        return
    end

    registration.count = registration.count - 1
    if registration.count > 0 then
        return
    end

    if registration.registered and registration.frame then
        pcall(registration.frame.UnregisterEvent, registration.frame, event)
    end

    eventRegs[key] = nil
    if not next(eventRegs) then
        self.unitRegistrations[event] = nil
    end

    self:_Debug("UnregisterUnitEvent", event, key)
end

function Event:_Sort(event)
    local list = self.listeners[event]
    if not list then
        return
    end

    tsort(list, function(a, b)
        if a.priority == b.priority then
            return a.sequence < b.sequence
        end
        return a.priority > b.priority
    end)
end

function Event:_CancelTimer(listener)
    if listener.timer and listener.timer.Cancel then
        listener.timer:Cancel()
    end
    listener.timer = nil
    listener.pendingArgs = nil
    listener.pendingN = nil
end

function Event:_RemoveListener(listener)
    if not listener or not listener.active then
        return false
    end

    listener.active = false
    self:_CancelTimer(listener)

    local list = self.listeners[listener.event]
    if list then
        for i = #list, 1, -1 do
            if list[i] == listener then
                tremove(list, i)
                break
            end
        end

        if #list == 0 then
            self.listeners[listener.event] = nil
        end
    end

    if listener.owner ~= nil then
        local ownerSet = self.ownerListeners[listener.owner]
        if ownerSet then
            ownerSet[listener] = nil
            if not next(ownerSet) then
                self.ownerListeners[listener.owner] = nil
            end
        end
    end

    if listener.unitKey then
        self:_ReleaseUnitEvent(listener)
    else
        self:_ReleaseNormalEvent(listener.event)
    end

    return true
end

function Event:_Invoke(listener, event, ...)
    if not listener.active then
        return
    end

    if listener.once then
        self:_RemoveListener(listener)
    end

    local traceRecord
    local trace = YUI.Trace
    if trace and trace.ShouldMeasureListener and trace:ShouldMeasureListener(event) and trace.Begin then
        traceRecord = trace:Begin("EventBus", tostring(event) .. " listener", GetListenerTraceName(listener), {
            moduleId = listener.moduleId,
            phase = listener.phase or event,
            traceName = listener.traceName,
        })
    end

    local success, err = pcall(CallListener, listener, event, ...)
    local stats = GetStatsTable(self, event)
    if success then
        stats.listenerCalls = stats.listenerCalls + 1
        if trace and traceRecord and trace.Finish then
            trace:Finish(traceRecord, "ok")
        end
    else
        if trace and traceRecord and trace.Finish then
            trace:Finish(traceRecord, "error", err)
        end
        self:_RecordError(event, err)
    end
end

function Event:_RunPending(listener)
    listener.timer = nil

    if not listener.active then
        listener.pendingArgs = nil
        listener.pendingN = nil
        return
    end

    local args = listener.pendingArgs
    local count = listener.pendingN or 0
    local event = listener.pendingEvent or listener.event
    listener.pendingArgs = nil
    listener.pendingN = nil
    listener.pendingEvent = nil

    if not args then
        return
    end

    self:_Invoke(listener, event, unpack(args, 1, count))
end

function Event:_QueueOrInvoke(listener, event, ...)
    if (listener.throttle or listener.debounce) and (not C_Timer or not C_Timer.NewTimer) then
        self:_Invoke(listener, event, ...)
        return
    end

    if listener.throttle then
        listener.pendingArgs, listener.pendingN = CopyArgs(...)
        listener.pendingEvent = event

        if listener.timer then
            local stats = GetStatsTable(self, event)
            stats.throttleCount = stats.throttleCount + 1
            return
        end

        listener.timer = C_Timer.NewTimer(listener.throttle, function()
            Event:_RunPending(listener)
        end)
        return
    end

    if listener.debounce then
        listener.pendingArgs, listener.pendingN = CopyArgs(...)
        listener.pendingEvent = event

        if listener.timer and listener.timer.Cancel then
            listener.timer:Cancel()
            local stats = GetStatsTable(self, event)
            stats.debounceCount = stats.debounceCount + 1
        end

        listener.timer = C_Timer.NewTimer(listener.debounce, function()
            Event:_RunPending(listener)
        end)
        return
    end

    self:_Invoke(listener, event, ...)
end

function Event:_ShouldDispatch(listener, source, sourceKey, ...)
    if source == "normal" and listener.unitKey then
        return false
    end

    if source == "unit" then
        if not listener.unitKey or listener.unitKey ~= sourceKey then
            return false
        end
    end

    if listener.unitSet then
        local unit = ...
        return unit ~= nil and listener.unitSet[unit] == true
    end

    return true
end

function Event:_Dispatch(event, source, sourceKey, ...)
    if type(event) ~= "string" then
        return
    end

    local stats = GetStatsTable(self, event)
    stats.fireCount = stats.fireCount + 1
    stats.lastFire = Now()

    local list = self.listeners[event]
    if not list or #list == 0 then
        return
    end

    local snapshot = {}
    for _, listener in ipairs(list) do
        if listener.active and self:_ShouldDispatch(listener, source, sourceKey, ...) then
            tinsert(snapshot, listener)
        end
    end

    for _, listener in ipairs(snapshot) do
        if listener.active then
            self:_QueueOrInvoke(listener, event, ...)
        end
    end
end

function Event:On(event, handler, owner, options)
    if type(event) ~= "string" or event == "" then
        return nil
    end

    local handlerType = type(handler)
    if handlerType ~= "function" and handlerType ~= "string" then
        return nil
    end

    if handlerType == "string" and owner == nil then
        return nil
    end

    options = options or {}
    local units, unitSet = GetUnits(options)

    self.sequence = self.sequence + 1

    local listener = {
        event = event,
        handler = handler,
        owner = owner,
        active = true,
        once = options.once and true or false,
        legacy = options.legacy and true or false,
        priority = tonumber(options.priority) or 0,
        throttle = GetDelay(options.throttle),
        debounce = GetDelay(options.debounce),
        sequence = self.sequence,
        units = units,
        unitSet = unitSet,
        unitKey = UnitKey(units),
        traceName = options.traceName,
        moduleId = options.moduleId,
        phase = options.phase,
    }

    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    tinsert(self.listeners[event], listener)
    self:_Sort(event)

    if owner ~= nil then
        if not self.ownerListeners[owner] then
            self.ownerListeners[owner] = {}
        end
        self.ownerListeners[owner][listener] = true
    end

    if listener.unitKey then
        self:_RegisterUnitEvent(listener)
    else
        self:_AcquireNormalEvent(event)
    end

    self:_Debug("On", event, handler, owner)
    return listener
end

function Event:Once(event, handler, owner, options)
    options = CopyOptions(options)
    options.once = true
    return self:On(event, handler, owner, options)
end

function Event:Off(target, handler, owner)
    if type(target) == "table" and target.event and target.handler then
        return self:_RemoveListener(target)
    end

    local event = target
    if type(event) ~= "string" then
        return 0
    end

    local list = self.listeners[event]
    if not list then
        return 0
    end

    local removed = 0
    for i = #list, 1, -1 do
        local listener = list[i]
        if listener.handler == handler and listener.owner == owner and self:_RemoveListener(listener) then
            removed = removed + 1
        end
    end

    return removed
end

function Event:OffOwner(owner)
    if owner == nil then
        return 0
    end

    local ownerSet = self.ownerListeners[owner]
    if not ownerSet then
        return 0
    end

    local snapshot = {}
    for listener in pairs(ownerSet) do
        tinsert(snapshot, listener)
    end

    local removed = 0
    for _, listener in ipairs(snapshot) do
        if self:_RemoveListener(listener) then
            removed = removed + 1
        end
    end

    return removed
end

function Event:Emit(event, ...)
    self:_Dispatch(event, "all", nil, ...)
end

function Event:SetDebug(enabled)
    self.debug = enabled and true or false
end

function Event:_UnitRegistrationCount(event)
    local eventRegs = self.unitRegistrations[event]
    local count = 0
    if not eventRegs then
        return count
    end

    for _ in pairs(eventRegs) do
        count = count + 1
    end

    return count
end

function Event:GetStats(event)
    if event == nil then
        local allStats = {}
        for eventName in pairs(self.stats) do
            allStats[eventName] = self:GetStats(eventName)
        end
        for eventName in pairs(self.listeners) do
            if not allStats[eventName] then
                allStats[eventName] = self:GetStats(eventName)
            end
        end
        return allStats
    end

    local stats = GetStatsTable(self, event)
    local list = self.listeners[event]

    return {
        event = event,
        listenerCount = CountListeners(list),
        ownerCount = CountOwners(list),
        fireCount = stats.fireCount or 0,
        listenerCalls = stats.listenerCalls or 0,
        lastFire = stats.lastFire,
        errorCount = stats.errorCount or 0,
        lastError = stats.lastError,
        lastErrorTime = stats.lastErrorTime,
        throttleCount = stats.throttleCount or 0,
        debounceCount = stats.debounceCount or 0,
        registered = YUI.f.registeredEvents[event],
        explicitRegistered = self.explicitEvents[event] and true or false,
        unitRegistrationCount = self:_UnitRegistrationCount(event),
    }
end

function Event:Dump(event)
    if event == nil then
        local names = {}
        local seen = {}

        for eventName in pairs(self.stats) do
            if not seen[eventName] then
                seen[eventName] = true
                tinsert(names, eventName)
            end
        end

        for eventName in pairs(self.listeners) do
            if not seen[eventName] then
                seen[eventName] = true
                tinsert(names, eventName)
            end
        end

        tsort(names)
        for _, eventName in ipairs(names) do
            self:Dump(eventName)
        end
        return
    end

    local stats = self:GetStats(event)
    local line = string.format(
        "EventBus[%s] listeners=%d owners=%d fires=%d calls=%d errors=%d throttle=%d debounce=%d unitRegs=%d",
        tostring(event),
        stats.listenerCount,
        stats.ownerCount,
        stats.fireCount,
        stats.listenerCalls,
        stats.errorCount,
        stats.throttleCount,
        stats.debounceCount,
        stats.unitRegistrationCount
    )

    if stats.lastError then
        line = line .. " lastError=" .. tostring(stats.lastError)
    end

    if YUI.Print then
        YUI:Print(line)
    else
        print(line)
    end
end

-- 核心修复：当 Frame 接收到游戏事件时，通过 EventBus 分发给非 unit 监听。
YUI.f:SetScript("OnEvent", function(_, event, ...)
    Event:_Dispatch(event, "normal", nil, ...)
end)

-- 自定义事件系统 (Custom Event System)
YUI.callbacks = YUI.callbacks or {}

function YUI:RegisterEvent(event)
    if type(event) ~= "string" or event == "" then
        return
    end

    Event.explicitEvents[event] = true
    Event:_RegisterFrameEvent(event)
end

-- 注册事件监听
-- @param event string 事件名称
-- @param func function|string 回调函数或方法名
-- @param owner table|nil (可选) 如果func是方法名，则为调用该方法的对象；如果func是函数，则作为旧接口第一个参数传入
function YUI:RegisterCallback(event, func, owner)
    self:Debug("RegisterCallback:", event, func, owner)

    local handle = Event:On(event, func, owner, { legacy = true })
    if not handle then
        return nil
    end

    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end

    tinsert(self.callbacks[event], { func = func, owner = owner, handle = handle })
    return handle
end

-- 注销事件监听
function YUI:UnregisterCallback(event, func, owner)
    local removed = Event:Off(event, func, owner)

    local list = self.callbacks[event]
    if list then
        for i = #list, 1, -1 do
            local cb = list[i]
            if cb.func == func and cb.owner == owner then
                tremove(list, i)
            end
        end

        if #list == 0 then
            self.callbacks[event] = nil
        end
    end

    return removed
end

-- 触发事件
function YUI:Fire(event, ...)
    return Event:Emit(event, ...)
end
