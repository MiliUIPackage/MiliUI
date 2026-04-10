local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local GetTrackerIconSize = CDM.GetTrackerIconSize
local GetTrackerSpacing = CDM.GetTrackerSpacing
local AcquireFromTrackerPool = CDM.AcquireFromTrackerPool
local ReleaseToTrackerPool = CDM.ReleaseToTrackerPool
local GetEffectiveSpellID = CDM.GetEffectiveSpellID
local GetFrameData = CDM.GetFrameData

function CDM.CreateTracker(config)
    local containerName = config.containerName
    local viewerName = config.viewerName
    local positionCallbackKey = config.positionCallbackKey
    local iconWidthKey = config.iconWidthKey
    local iconHeightKey = config.iconHeightKey
    local anchorPointKey = config.anchorPointKey
    local offsetXKey = config.offsetXKey
    local offsetYKey = config.offsetYKey
    local moduleKey = config.moduleKey
    local watchOwnerKey = config.watchOwnerKey
    local showCharges = config.showCharges
    local styleRefreshPriority = config.styleRefreshPriority
    local useEntryPool = config.useEntryPool ~= false
    local useDispatch = config.useDispatch ~= false

    local cfgGetEntries = config.GetEntries
    local cfgPlayerHasAbility = config.PlayerHasAbility
    local cfgUpdateIcon = config.UpdateIcon
    local cfgResetFrame = config.resetFrame
    local cfgOnEntriesChanged = config.onEntriesChanged
    local cfgUpdateContainerPosition = config.UpdateContainerPosition
    local cfgOnStyleRefresh = config.onStyleRefresh

    local isInitialized = false
    local isEnabled = false
    local needsStyleUpdate = true
    local lastSpecID = nil

    local container
    local iconEntries = {}
    local iconFrames = {}
    local iconFramePool = {}
    local iconEntryPool = {}

    local lastVisibilityHash = 0
    local lastWidth, lastHeight = nil, nil
    local lastSpacing = nil

    local cachedStyles = {
        fontPath = nil,
        fontOutline = nil,
        chargeFontSize = 10,
        chargeColor = { r = 1, g = 1, b = 1, a = 1 },
        chargePosition = "BOTTOMRIGHT",
        chargeOffsetX = 0,
        chargeOffsetY = 0,
    }
    local chargeStyleVersion = 0

    local acquireOpts = {
        size = nil,
        showCharges = showCharges,
        named = false,
    }

    local settleGate
    local dispatchFrame, updatePending, queuedFullUpdate, queuedCooldownUpdate

    local tracker = {}

    local function GetCurrentSpecID()
        return CDM:GetCurrentSpecID()
    end

    local function RefreshCachedStyles()
        CDM.RefreshChargeStyleCache(cachedStyles, moduleKey)
        chargeStyleVersion = chargeStyleVersion + 1
    end

    local function UpdateContainerPosition()
        if not container then return end
        if cfgUpdateContainerPosition then
            cfgUpdateContainerPosition()
            return
        end
        local db = CDM.db
        local anchorPoint = db and db[anchorPointKey] or "TOPLEFT"
        local offsetX = db and db[offsetXKey] or 0
        local offsetY = db and db[offsetYKey] or 0
        CDM.AnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, containerName)
    end

    -- Entry pool

    local function AcquireEntry(proto)
        local entry = table.remove(iconEntryPool)
        if entry then
            table.wipe(entry)
        else
            entry = {}
        end
        for k, v in pairs(proto) do
            entry[k] = v
        end
        entry._spellbookCached = nil
        entry.frame = nil
        return entry
    end

    local function ReleaseEntry(entry)
        if not entry then return end
        table.wipe(entry)
        iconEntryPool[#iconEntryPool + 1] = entry
    end

    -- Frame pool

    local function CreateIconFrame(id)
        acquireOpts.size = GetTrackerIconSize(iconWidthKey, iconHeightKey)
        local frame = AcquireFromTrackerPool(iconFramePool, container, containerName:gsub("Container", "_"), id, acquireOpts)

        frame.spellID = id
        frame._spellbookCached = nil

        local effectiveID = GetEffectiveSpellID(id)
        local texture = C_Spell.GetSpellTexture(effectiveID)
        if texture and frame.Icon then
            frame.Icon:SetTexture(texture)
            frame.Icon:SetDesaturation(0)
        end

        return frame
    end

    local function BindEntryFrame(entry)
        local frame = entry.frame
        if frame then
            return frame, false
        end

        local id = entry.spellID or entry.id
        frame = CreateIconFrame(id)
        frame._spellbookCached = entry._spellbookCached
        frame.cdmTrackerEntry = entry
        entry.frame = frame
        return frame, true
    end

    local function ReleaseEntryFrame(entry)
        local frame = entry and entry.frame
        if not frame then return end

        entry.frame = nil
        frame.cdmTrackerEntry = nil
        ReleaseToTrackerPool(iconFramePool, frame, cfgResetFrame)
    end

    local function ReleaseAllFrames()
        for _, entry in ipairs(iconEntries) do
            ReleaseEntryFrame(entry)
        end
        table.wipe(iconFrames)
        if CDM.ClearTrackerPool then
            CDM.ClearTrackerPool(iconFramePool)
        end
        lastVisibilityHash = -1
        lastWidth = nil
        lastHeight = nil
        lastSpacing = nil
    end

    local function InvalidateSpellbookCache()
        for _, entry in ipairs(iconEntries) do
            entry._spellbookCached = nil
            if entry.frame then
                entry.frame._spellbookCached = nil
            end
        end
    end

    local function PositionIcons()
        CDM.PositionTrackerIconsFromDB(container, iconFrames, iconWidthKey, iconHeightKey, "spacing", anchorPointKey)
    end

    -- Dispatch frame (optional)

    if useDispatch then
        dispatchFrame = CreateFrame("Frame")
        dispatchFrame:Hide()
        updatePending = false
        queuedFullUpdate = false
        queuedCooldownUpdate = false
    end

    -- Update passes

    function tracker.Update()
        if not container then return end

        if useEntryPool then
            local currentSpec = GetCurrentSpecID()
            if currentSpec and currentSpec ~= lastSpecID then
                lastSpecID = currentSpec
                tracker.Reinit()
                return
            end
            InvalidateSpellbookCache()
        end

        local size = GetTrackerIconSize(iconWidthKey, iconHeightKey)
        local spacing = GetTrackerSpacing()

        local sizeChanged = (lastWidth ~= size.w or lastHeight ~= size.h)
        if sizeChanged then
            lastWidth = size.w
            lastHeight = size.h
        end

        local spacingChanged = (lastSpacing ~= spacing)
        if spacingChanged then
            lastSpacing = spacing
        end

        local applyStyle = needsStyleUpdate or sizeChanged

        if useEntryPool then
            local visibilityHash = 0
            local bit = 1
            local visibleCount = 0
            for _, entry in ipairs(iconEntries) do
                if cfgPlayerHasAbility(entry, currentSpec) then
                    visibilityHash = visibilityHash + bit

                    local frame, boundNow = BindEntryFrame(entry)

                    if not boundNow and frame.Icon then
                        local id = entry.spellID or entry.id
                        local texture = C_Spell.GetSpellTexture(GetEffectiveSpellID(id))
                        if texture then
                            frame.Icon:SetTexture(texture)
                        end
                    end

                    if sizeChanged then
                        frame:SetSize(size.w, size.h)
                        if frame.Icon then frame.Icon:SetAllPoints(frame) end
                        if frame.Cooldown then frame.Cooldown:SetAllPoints(frame) end
                        local fd = GetFrameData(frame)
                        if fd.borderFrame then fd.borderFrame:SetAllPoints(frame) end
                        if frame.ChargeCount then frame.ChargeCount:SetAllPoints(frame) end
                    end

                    frame:Show()
                    if (applyStyle or boundNow) and CDM.ApplyStyle then
                        CDM:ApplyStyle(frame, viewerName, boundNow)
                    end
                    cfgUpdateIcon(frame)

                    visibleCount = visibleCount + 1
                    iconFrames[visibleCount] = frame
                else
                    ReleaseEntryFrame(entry)
                end
                bit = bit + bit
            end
            for i = visibleCount + 1, #iconFrames do
                iconFrames[i] = nil
            end

            needsStyleUpdate = false

            if visibilityHash ~= lastVisibilityHash or sizeChanged or spacingChanged then
                lastVisibilityHash = visibilityHash
                PositionIcons()
            end
        end
    end

    function tracker.UpdateCooldownsOnly()
        if not container or not isEnabled then return end

        if needsStyleUpdate then
            tracker.Update()
            return
        end

        if useEntryPool then
            local currentSpec = GetCurrentSpecID()
            if currentSpec and currentSpec ~= lastSpecID then
                lastSpecID = currentSpec
                tracker.Reinit()
                return
            end
        end

        for _, frame in ipairs(iconFrames) do
            if frame:IsShown() then
                cfgUpdateIcon(frame)
            end
        end
    end

    -- Dispatch

    function tracker.Queue(fullUpdate)
        if not useDispatch then return end
        if not fullUpdate and settleGate and not settleGate:IsSettled() then
            return
        end
        if fullUpdate then
            queuedFullUpdate = true
        else
            queuedCooldownUpdate = true
        end
        if updatePending then return end
        updatePending = true
        dispatchFrame:Show()
    end

    if useDispatch then
        dispatchFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            updatePending = false
            if not isEnabled then return end
            local doFull = queuedFullUpdate
            local doCooldowns = queuedCooldownUpdate
            queuedFullUpdate = false
            queuedCooldownUpdate = false
            if doFull then
                tracker.Update()
            elseif doCooldowns then
                tracker.UpdateCooldownsOnly()
            end
        end)
    end

    -- Lifecycle

    function tracker.Reinit()
        if not isInitialized then return end

        if useEntryPool then
            for _, entry in ipairs(iconEntries) do
                ReleaseEntryFrame(entry)
                ReleaseEntry(entry)
            end
            table.wipe(iconEntries)
            table.wipe(iconFrames)
        end
        lastVisibilityHash = -1

        local specID = GetCurrentSpecID()
        lastSpecID = specID

        if useEntryPool and cfgGetEntries then
            local protos = cfgGetEntries(specID)
            for _, proto in ipairs(protos) do
                iconEntries[#iconEntries + 1] = AcquireEntry(proto)
            end
        end

        needsStyleUpdate = true

        if cfgOnEntriesChanged then
            cfgOnEntriesChanged(iconEntries)
        end

        if isEnabled then
            tracker.Update()
        end
        if useEntryPool then
            CDM.TrimTrackerPool(iconFramePool, #iconEntries)
        end
    end

    function tracker.Initialize()
        if isInitialized then return end

        RefreshCachedStyles()

        container = CDM.CreateTrackerContainer(containerName)
        UpdateContainerPosition()

        lastSpecID = GetCurrentSpecID()

        if useEntryPool and cfgGetEntries then
            local protos = cfgGetEntries(lastSpecID)
            for _, proto in ipairs(protos) do
                iconEntries[#iconEntries + 1] = AcquireEntry(proto)
            end
        end

        if cfgOnEntriesChanged then
            cfgOnEntriesChanged(iconEntries)
        end

        settleGate = CDM.CreateStartupSettleGate(function()
            if isEnabled then
                tracker.UpdateCooldownsOnly()
            end
        end)

        settleGate:Begin()
        tracker.Update()

        CDM.RegisterTrackerPositionCallback(positionCallbackKey, UpdateContainerPosition)

        CDM:RegisterRefreshCallback(moduleKey .. "Styles", function()
            RefreshCachedStyles()
            if cfgOnStyleRefresh then
                cfgOnStyleRefresh()
            end
            needsStyleUpdate = true
        end, styleRefreshPriority, { "TRACKERS", "STYLE" })

        isInitialized = true
        isEnabled = true
        settleGate:ScheduleSettle()
    end

    function tracker.Enable()
        if not isInitialized or isEnabled then return end
        settleGate:Begin()
        CDM.RegisterTrackerPositionCallback(positionCallbackKey, UpdateContainerPosition)
        if container then
            container:Show()
        end
        needsStyleUpdate = true
        isEnabled = true

        if useEntryPool then
            InvalidateSpellbookCache()
        end

        tracker.Update()

        if cfgOnEntriesChanged then
            cfgOnEntriesChanged(iconEntries)
        end

        settleGate:ScheduleSettle()
    end

    function tracker.Disable()
        if not isEnabled then return end
        if settleGate then settleGate:Cancel() end
        if useDispatch then
            updatePending = false
            queuedFullUpdate = false
            queuedCooldownUpdate = false
        end
        if watchOwnerKey and CDM.UnwatchAllSpellStates then
            CDM.UnwatchAllSpellStates(watchOwnerKey)
        end
        CDM.UnregisterTrackerPositionCallback(positionCallbackKey)
        if container then
            container:Hide()
        end
        if useEntryPool then
            ReleaseAllFrames()
        end
        isEnabled = false
    end

    function tracker.Reconcile(dbEnabledKey)
        if CDM.db and CDM.db[dbEnabledKey] ~= false then
            if not isInitialized then tracker.Initialize() end
            if not isEnabled then tracker.Enable() end
            UpdateContainerPosition()
        elseif isEnabled then
            tracker.Disable()
        end
    end

    function tracker.OnProfileApplied()
        needsStyleUpdate = true
        lastSpecID = nil
        lastVisibilityHash = -1
        lastWidth = nil
        lastHeight = nil
        lastSpacing = nil
        if useEntryPool then
            InvalidateSpellbookCache()
        end
    end

    function tracker.InvalidateStyle()
        needsStyleUpdate = true
    end

    function tracker.ConsumeStyleDirty()
        if needsStyleUpdate then
            needsStyleUpdate = false
            return true
        end
        return false
    end

    function tracker.GetContainer()
        return container
    end

    function tracker.GetIconFrames()
        return iconFrames
    end

    function tracker.GetCachedStyles()
        return cachedStyles
    end

    function tracker.GetChargeStyleVersion()
        return chargeStyleVersion
    end

    function tracker.IsEnabled()
        return isEnabled
    end

    function tracker.IsInitialized()
        return isInitialized
    end

    return tracker
end
