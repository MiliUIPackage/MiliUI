do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
if not (YUI and YUI.Monitor) then return end

local Monitor = YUI.Monitor
local Data = Monitor.Data or {}
Monitor.Data = Data

local pairs = pairs
local select = select
local sort = table.sort
local type = type

Data.Policy = Data.Policy or {
    maxFlushPerFrame = 0,
}
Data.types = Data.types or {}
Data.sources = Data.sources or {}
Data.eventRoutes = Data.eventRoutes or {}
Data.routesByEvent = Data.routesByEvent or {}
Data.ownerHandles = Data.ownerHandles or {}
Data.tickSources = Data.tickSources or {}
Data.queue = Data.queue or {}
Data.queueHead = Data.queueHead or 1
Data.queueTail = Data.queueTail or 0
Data.broadcastQueue = Data.broadcastQueue or {}
Data.broadcastHead = Data.broadcastHead or 1
Data.broadcastTail = Data.broadcastTail or 0
Data.stats = Data.stats or {
    activeSources = 0,
    activeSubscriptions = 0,
    activeIndexes = 0,
    activeTicks = 0,
    events = 0,
    candidateKeys = 0,
    changedKeys = 0,
    apiReads = 0,
    sourceStateBuilds = 0,
    fanOutMonitors = 0,
    queueRequests = 0,
    coalescedRequests = 0,
    broadcastRequests = 0,
    coalescedBroadcasts = 0,
    broadcastFlushes = 0,
    broadcastSources = 0,
    flushPasses = 0,
    uiWrites = 0,
    noOpSkips = 0,
    forcedDispatches = 0,
    poolActive = 0,
    poolFree = 0,
    fallbacks = 0,
    shadowComparisons = 0,
    shadowMismatches = 0,
}
Data.stats.forcedDispatches = tonumber(Data.stats.forcedDispatches) or 0
Data.stats.broadcastRequests = tonumber(Data.stats.broadcastRequests) or 0
Data.stats.coalescedBroadcasts = tonumber(Data.stats.coalescedBroadcasts) or 0
Data.stats.broadcastFlushes = tonumber(Data.stats.broadcastFlushes) or 0
Data.stats.broadcastSources = tonumber(Data.stats.broadcastSources) or 0

local function EventBus()
    return YUI.Event
end

local function NormalizeEventRule(rule)
    if type(rule) == "string" and rule ~= "" then
        return {
            event = rule,
            all = true,
        }
    end
    if type(rule) ~= "table" or type(rule.event) ~= "string" or rule.event == "" then
        return nil
    end
    local normalized = {}
    for key, value in pairs(rule) do
        normalized[key] = value
    end

    local units
    if type(rule.unit) == "string" and rule.unit ~= "" then
        units = { rule.unit }
    elseif type(rule.units) == "table" then
        local seen = {}
        for index = 1, #rule.units do
            local unit = rule.units[index]
            if type(unit) == "string" and unit ~= "" and not seen[unit] then
                units = units or {}
                units[#units + 1] = unit
                seen[unit] = true
            end
        end
    end
    if units and #units > 0 then
        sort(units)
        normalized.unit = #units == 1 and units[1] or nil
        normalized.units = units
        normalized.unitKey = table.concat(units, "\001")
    else
        normalized.unit = nil
        normalized.units = nil
        normalized.unitKey = nil
    end
    return normalized
end

local function RouteOnEvent(route, event, ...)
    route.data:_OnRouteEvent(route, event, ...)
end

local function InvokeConsumer(handle, state, sourceKey, reason, forced)
    local handler = handle.handler
    local owner = handle.owner
    if type(handler) == "string" then
        local method = owner and owner[handler]
        if type(method) == "function" then
            method(owner, state, sourceKey, reason, forced == true)
        end
    elseif type(handler) == "function" then
        if owner ~= nil then
            handler(owner, state, sourceKey, reason, forced == true)
        else
            handler(state, sourceKey, reason, forced == true)
        end
    end
end

function Data:RegisterSourceType(typeId, definition)
    if type(typeId) ~= "string" or typeId == "" or type(definition) ~= "table" then
        return nil, "invalid-source-type"
    end
    if type(definition.read) ~= "function" then
        return nil, "missing-source-reader"
    end
    if self.types[typeId] then
        return nil, "source-type-exists"
    end

    local sourceType = {
        id = typeId,
        definition = definition,
        sources = {},
        sourceCount = 0,
        identityIndex = {},
        routes = {},
        queuedBroadcast = false,
        pendingBroadcastReason = nil,
    }
    self.types[typeId] = sourceType

    local events = definition.events
    if type(events) == "table" then
        for index = 1, #events do
            local rule = NormalizeEventRule(events[index])
            if rule then
                local routeKey = rule.unitKey
                    and (rule.event .. "\002" .. rule.unitKey)
                    or rule.event
                local route = self.eventRoutes[routeKey]
                if not route then
                    route = {
                        key = routeKey,
                        event = rule.event,
                        unit = rule.unit,
                        units = rule.units,
                        data = self,
                        OnEvent = RouteOnEvent,
                        sourceTypes = {},
                        activeTypes = {},
                        activeCount = 0,
                    }
                    self.eventRoutes[routeKey] = route
                    local eventRoutes = self.routesByEvent[rule.event]
                    if not eventRoutes then
                        eventRoutes = {}
                        self.routesByEvent[rule.event] = eventRoutes
                    end
                    eventRoutes[#eventRoutes + 1] = route
                end
                route.sourceTypes[sourceType] = rule
                sourceType.routes[#sourceType.routes + 1] = route
            end
        end
    end
    return sourceType
end

function Data:_ActivateRoute(route, sourceType)
    if route.activeTypes[sourceType] then return true end
    route.activeTypes[sourceType] = route.sourceTypes[sourceType]
    route.activeCount = route.activeCount + 1
    if route.listener then return true end

    local Event = EventBus()
    if not (Event and Event.On) then
        route.activeTypes[sourceType] = nil
        route.activeCount = route.activeCount - 1
        return false
    end
    local options = {
        moduleId = "core.monitor",
        traceName = "YUI.Monitor.Data",
    }
    if route.unit then
        options.unit = route.unit
    elseif route.units then
        options.units = route.units
    end
    local listener = Event:On(route.event, "OnEvent", route, options)
    if not listener then
        route.activeTypes[sourceType] = nil
        route.activeCount = route.activeCount - 1
        return false
    end
    route.listener = listener
    return true
end

function Data:_DeactivateRoute(route, sourceType)
    if not route.activeTypes[sourceType] then return false end
    route.activeTypes[sourceType] = nil
    route.activeCount = route.activeCount - 1
    if route.activeCount > 0 or not route.listener then return true end

    local Event = EventBus()
    if Event and Event.Off then
        Event:Off(route.listener)
    end
    route.listener = nil
    return true
end

function Data:_ActivateSourceType(sourceType)
    for index = 1, #sourceType.routes do
        self:_ActivateRoute(sourceType.routes[index], sourceType)
    end
end

function Data:_DeactivateSourceType(sourceType)
    for index = 1, #sourceType.routes do
        self:_DeactivateRoute(sourceType.routes[index], sourceType)
    end
    sourceType.queuedBroadcast = false
    sourceType.pendingBroadcastReason = nil
    local writeIndex = self.broadcastHead
    for readIndex = self.broadcastHead, self.broadcastTail do
        local pendingType = self.broadcastQueue[readIndex]
        self.broadcastQueue[readIndex] = nil
        if pendingType and pendingType.queuedBroadcast == true then
            self.broadcastQueue[writeIndex] = pendingType
            writeIndex = writeIndex + 1
        end
    end
    self.broadcastTail = writeIndex - 1
    if self.broadcastHead > self.broadcastTail then
        self.broadcastHead = 1
        self.broadcastTail = 0
    end
end

function Data:_CreateSource(sourceKey, sourceType, params)
    local definition = sourceType.definition
    local identities
    if type(definition.getIdentity) == "function" then
        identities = definition.getIdentity(params)
    elseif type(params) == "table" then
        identities = params.identity
    end
    if type(identities) ~= "table" then
        identities = identities ~= nil and { identities } or nil
    end
    local normalizedIdentities
    local seenIdentity = {}
    if identities then
        normalizedIdentities = {}
        for index = 1, #identities do
            local identity = identities[index]
            if identity ~= nil and not seenIdentity[identity] then
                seenIdentity[identity] = true
                normalizedIdentities[#normalizedIdentities + 1] = identity
                if sourceType.identityIndex[identity] then
                    return nil, "source-identity-exists"
                end
            end
        end
    end

    local state
    if type(definition.createState) == "function" then
        state = definition.createState(params)
    end
    if type(state) ~= "table" then state = {} end

    local source = {
        key = sourceKey,
        sourceType = sourceType,
        definition = definition,
        params = params,
        identities = normalizedIdentities,
        identity = normalizedIdentities and normalizedIdentities[1] or nil,
        state = state,
        consumers = {},
        consumerCount = 0,
        initialized = definition.initializeOnCreate == true,
        queuedRefresh = false,
        pendingReason = nil,
        tickElapsed = 0,
    }
    source.tickInterval = tonumber(definition.tickInterval)
        or (type(params) == "table" and tonumber(params.tickInterval))

    self.sources[sourceKey] = source
    sourceType.sources[sourceKey] = source
    sourceType.sourceCount = sourceType.sourceCount + 1
    self.stats.activeSources = self.stats.activeSources + 1

    if normalizedIdentities then
        for index = 1, #normalizedIdentities do
            sourceType.identityIndex[normalizedIdentities[index]] = source
            self.stats.activeIndexes = self.stats.activeIndexes + 1
        end
    end
    if source.tickInterval and source.tickInterval > 0 then
        self.tickSources[source] = true
        self.stats.activeTicks = self.stats.activeTicks + 1
    end
    if sourceType.sourceCount == 1 then
        self:_ActivateSourceType(sourceType)
    end
    return source
end

function Data:_CancelQueuedSource(source)
    if not source or source.queuedRefresh ~= true then return false end

    source.queuedRefresh = false
    source.pendingReason = nil
    local writeIndex = self.queueHead
    for readIndex = self.queueHead, self.queueTail do
        local queuedSource = self.queue[readIndex]
        self.queue[readIndex] = nil
        if queuedSource and queuedSource.queuedRefresh == true then
            self.queue[writeIndex] = queuedSource
            writeIndex = writeIndex + 1
        end
    end
    self.queueTail = writeIndex - 1
    if self.queueHead > self.queueTail then
        self.queueHead = 1
        self.queueTail = 0
    end
    return true
end

function Data:_DestroySource(source)
    if not source or source.consumerCount > 0 then return false end
    self:_CancelQueuedSource(source)
    local sourceType = source.sourceType
    self.sources[source.key] = nil
    sourceType.sources[source.key] = nil
    sourceType.sourceCount = sourceType.sourceCount - 1
    self.stats.activeSources = self.stats.activeSources - 1

    local sourceIdentities = source.identities
    if sourceIdentities then
        for index = 1, #sourceIdentities do
            local identity = sourceIdentities[index]
            if sourceType.identityIndex[identity] == source then
                sourceType.identityIndex[identity] = nil
                self.stats.activeIndexes = self.stats.activeIndexes - 1
            end
        end
    end
    if self.tickSources[source] then
        self.tickSources[source] = nil
        self.stats.activeTicks = self.stats.activeTicks - 1
    end
    if sourceType.sourceCount <= 0 then
        self:_DeactivateSourceType(sourceType)
    end
    Monitor:_StopDriver()
    return true
end

function Data:AcquireSource(owner, sourceKey, typeId, params, handler)
    if type(sourceKey) ~= "string" or sourceKey == "" then
        return nil, "invalid-source-key"
    end
    if type(handler) ~= "function" and type(handler) ~= "string" then
        return nil, "invalid-source-handler"
    end
    if type(handler) == "string" and owner == nil then
        return nil, "missing-source-owner"
    end

    local sourceType = self.types[typeId]
    if not sourceType then return nil, "unknown-source-type" end
    local source = self.sources[sourceKey]
    if source and source.sourceType ~= sourceType then
        return nil, "source-key-type-conflict"
    end
    if not source then
        local reason
        source, reason = self:_CreateSource(sourceKey, sourceType, params)
        if not source then return nil, reason end
    end

    local handle = {
        source = source,
        owner = owner,
        handler = handler,
        active = true,
    }
    source.consumerCount = source.consumerCount + 1
    handle.index = source.consumerCount
    source.consumers[handle.index] = handle
    self.stats.activeSubscriptions = self.stats.activeSubscriptions + 1

    if owner ~= nil then
        local handles = self.ownerHandles[owner]
        if not handles then
            handles = {}
            self.ownerHandles[owner] = handles
        end
        handles[handle] = true
    end
    self:QueueSource(source, "acquire")
    return handle
end

function Data:ReleaseSource(handle)
    if type(handle) ~= "table" or handle.active ~= true then return false end
    local source = handle.source
    if not source then return false end

    local index = handle.index
    local lastIndex = source.consumerCount
    local lastHandle = source.consumers[lastIndex]
    source.consumers[lastIndex] = nil
    source.consumerCount = lastIndex - 1
    if index < lastIndex then
        source.consumers[index] = lastHandle
        lastHandle.index = index
    end

    handle.active = false
    handle.source = nil
    handle.index = nil
    self.stats.activeSubscriptions = self.stats.activeSubscriptions - 1

    local ownerHandles = self.ownerHandles[handle.owner]
    if ownerHandles then
        ownerHandles[handle] = nil
        if not next(ownerHandles) then self.ownerHandles[handle.owner] = nil end
    end
    if source.consumerCount <= 0 then
        self:_DestroySource(source)
    end
    return true
end

function Data:ReleaseOwner(owner)
    local handles = self.ownerHandles[owner]
    if not handles then return 0 end
    local count = 0
    while next(handles) do
        local handle = next(handles)
        if self:ReleaseSource(handle) then count = count + 1 end
    end
    return count
end

function Data:QueueSource(sourceOrKey, reason, forceDispatch)
    local source = sourceOrKey
    if type(sourceOrKey) == "string" then
        source = self.sources[sourceOrKey]
    end
    if not source or source.consumerCount <= 0 then return false end

    if not source.queuedRefresh
        and source.sourceType.queuedBroadcast == true then
        reason = source.sourceType.pendingBroadcastReason or reason
    end
    self.stats.queueRequests = self.stats.queueRequests + 1
    source.pendingReason = source.pendingReason or reason or "refresh"
    if forceDispatch == true then source.pendingForceDispatch = true end
    if source.queuedRefresh then
        self.stats.coalescedRequests = self.stats.coalescedRequests + 1
        return true
    end

    source.queuedRefresh = true
    self.queueTail = self.queueTail + 1
    self.queue[self.queueTail] = source
    Monitor:_StartDriver()
    return true
end

function Data:QueueSourceType(sourceType, reason)
    if not sourceType or sourceType.sourceCount <= 0 then return false end
    self.stats.broadcastRequests = self.stats.broadcastRequests + 1
    sourceType.pendingBroadcastReason = sourceType.pendingBroadcastReason
        or reason or "refresh"
    if sourceType.queuedBroadcast == true then
        self.stats.coalescedBroadcasts = self.stats.coalescedBroadcasts + 1
        return true
    end
    sourceType.queuedBroadcast = true
    self.broadcastTail = self.broadcastTail + 1
    self.broadcastQueue[self.broadcastTail] = sourceType
    Monitor:_StartDriver()
    return true
end

function Data:_FlushBroadcasts()
    if self.broadcastHead > self.broadcastTail then return 0 end
    local flushTail = self.broadcastTail
    local flushed = 0
    while self.broadcastHead <= flushTail do
        local sourceType = self.broadcastQueue[self.broadcastHead]
        self.broadcastQueue[self.broadcastHead] = nil
        self.broadcastHead = self.broadcastHead + 1
        if sourceType and sourceType.queuedBroadcast == true then
            local reason = sourceType.pendingBroadcastReason or "refresh"
            sourceType.queuedBroadcast = false
            sourceType.pendingBroadcastReason = nil
            flushed = flushed + 1
            self.stats.broadcastFlushes = self.stats.broadcastFlushes + 1
            for _, source in pairs(sourceType.sources) do
                self.stats.candidateKeys = self.stats.candidateKeys + 1
                self.stats.broadcastSources = self.stats.broadcastSources + 1
                self:QueueSource(source, reason)
            end
        end
    end
    if self.broadcastHead > self.broadcastTail then
        self.broadcastHead = 1
        self.broadcastTail = 0
    end
    return flushed
end

function Data:_OnRouteEvent(route, event, ...)
    if not route then return end
    self.stats.events = self.stats.events + 1

    for sourceType, rule in pairs(route.activeTypes) do
        if rule.all == true then
            self:QueueSourceType(sourceType, rule.reason or event)
        else
            local identityArgs = rule.identityArgs
            local identityArg = rule.identityArg
            local hadIdentity = false
            local lastSource

            if type(identityArgs) == "table" then
                for index = 1, #identityArgs do
                    local identity = select(identityArgs[index], ...)
                    if identity ~= nil then
                        hadIdentity = true
                        if type(rule.mapIdentity) == "function" then
                            identity = rule.mapIdentity(identity, ...)
                        end
                        local source = sourceType.identityIndex[identity]
                        if source and source ~= lastSource then
                            lastSource = source
                            self.stats.candidateKeys = self.stats.candidateKeys + 1
                            self:QueueSource(source, rule.identityReason or rule.reason or event)
                        end
                    end
                end
            elseif identityArg then
                local identity = select(identityArg, ...)
                if identity ~= nil then
                    hadIdentity = true
                    if type(rule.mapIdentity) == "function" then
                        identity = rule.mapIdentity(identity, ...)
                    end
                    local source = sourceType.identityIndex[identity]
                    if source then
                        self.stats.candidateKeys = self.stats.candidateKeys + 1
                        self:QueueSource(source, rule.identityReason or rule.reason or event)
                    end
                end
            end

            local queueAll = rule.allWhenIdentityMissing == true and not hadIdentity
            local allReason = rule.missingAllReason or rule.allReason or rule.reason or event
            local allWhenArgEquals = rule.allWhenArgEquals
            if type(allWhenArgEquals) == "table"
                and select(allWhenArgEquals.arg or 1, ...) == allWhenArgEquals.value then
                queueAll = true
                allReason = rule.matchAllReason or rule.allReason or rule.reason or event
            end

            if queueAll then
                self:QueueSourceType(sourceType, allReason)
            end
        end
    end
end

function Data:OnEvent(event, ...)
    local routes = self.routesByEvent[event]
    if not routes then
        local route = self.eventRoutes[event]
        if route then
            self:_OnRouteEvent(route, event, ...)
        end
        return
    end
    for index = 1, #routes do
        self:_OnRouteEvent(routes[index], event, ...)
    end
end

function Data:Flush()
    self:_FlushBroadcasts()
    if self.queueHead > self.queueTail then return 0 end
    self.stats.flushPasses = self.stats.flushPasses + 1
    local processed = 0
    local flushTail = self.queueTail
    local limit = tonumber(self.Policy.maxFlushPerFrame) or 0
    if limit <= 0 then
        limit = flushTail - self.queueHead + 1
    end

    while self.queueHead <= flushTail and processed < limit do
        local source = self.queue[self.queueHead]
        self.queue[self.queueHead] = nil
        self.queueHead = self.queueHead + 1
        if source and source.consumerCount > 0 and source.queuedRefresh then
            source.queuedRefresh = false
            local reason = source.pendingReason
            source.pendingReason = nil
            local forceDispatch = source.pendingForceDispatch == true
            source.pendingForceDispatch = nil
            self.stats.apiReads = self.stats.apiReads + 1
            self.stats.sourceStateBuilds = self.stats.sourceStateBuilds + 1
            local changed = source.definition.read(source, source.state, reason) == true
            if not source.initialized then
                source.initialized = true
                changed = true
            end
            if changed or forceDispatch then
                if forceDispatch and not changed then
                    self.stats.forcedDispatches =
                        (self.stats.forcedDispatches or 0) + 1
                end
                self.stats.changedKeys = self.stats.changedKeys + 1
                for index = 1, source.consumerCount do
                    InvokeConsumer(
                        source.consumers[index],
                        source.state,
                        source.key,
                        reason,
                        forceDispatch
                    )
                    self.stats.fanOutMonitors = self.stats.fanOutMonitors + 1
                end
            else
                self.stats.noOpSkips = self.stats.noOpSkips + 1
            end
            if type(source.definition.afterDispatch) == "function" then
                source.definition.afterDispatch(source, source.state, reason, changed)
            end
            processed = processed + 1
        end
    end

    if self.queueHead > self.queueTail then
        self.queueHead = 1
        self.queueTail = 0
    end
    return processed
end

function Data:_NeedsDriver()
    return self.queueHead <= self.queueTail
        or self.broadcastHead <= self.broadcastTail
        or self.stats.activeTicks > 0
end

function Data:_OnUpdate(elapsed)
    if self.stats.activeTicks > 0 then
        for source in pairs(self.tickSources) do
            source.tickElapsed = source.tickElapsed + elapsed
            if source.tickElapsed >= source.tickInterval then
                source.tickElapsed = source.tickElapsed - source.tickInterval
                self:QueueSource(source, "tick")
            end
        end
    end
    self:Flush()
end

function Data:AddStat(field, amount)
    if self.stats[field] == nil then return false end
    self.stats[field] = self.stats[field] + (tonumber(amount) or 1)
    return true
end

function Data:SetStat(field, value)
    if self.stats[field] == nil then return false end
    self.stats[field] = tonumber(value) or 0
    return true
end

function Data:GetStats(target)
    target = target or {}
    for key, value in pairs(self.stats) do
        target[key] = value
    end
    target.queuedRefresh = self.queueHead <= self.queueTail
    return target
end

function Monitor:RegisterSourceType(typeId, definition)
    return Data:RegisterSourceType(typeId, definition)
end

function Monitor:AcquireSource(owner, sourceKey, typeId, params, handler)
    return Data:AcquireSource(owner, sourceKey, typeId, params, handler)
end

function Monitor:ReleaseSource(handle)
    return Data:ReleaseSource(handle)
end

function Monitor:ReleaseSourceOwner(owner)
    return Data:ReleaseOwner(owner)
end

function Monitor:QueueSource(sourceOrKey, reason, forceDispatch)
    return Data:QueueSource(sourceOrKey, reason, forceDispatch)
end

function Monitor:GetDataStats(target)
    return Data:GetStats(target)
end

function Monitor:AddDataStat(field, amount)
    return Data:AddStat(field, amount)
end

function Monitor:SetDataStat(field, value)
    return Data:SetStat(field, value)
end
