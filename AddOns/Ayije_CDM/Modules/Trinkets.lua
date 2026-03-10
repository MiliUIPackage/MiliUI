local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

-- Ayije_CDM Trinkets Tracker
local CDM_C = CDM and CDM.CONST or {}
local SetPixelPerfectPoint = CDM_C.SetPixelPerfectPoint

local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14

local isInitialized = false
local isEnabled = false
local needsStyleUpdate = true

local trinketsContainer
local iconFrames = {}
local iconFramePool = {}
local injectionScratch = {}

local currentMode = "independent"
local lastTrinketsVisibilityHash = -1
local lastTrinketsSpacing = nil
local lastTrinketsPositionAnchor = nil
local lastTrinketsWidth, lastTrinketsHeight = nil, nil
local trinketsCooldownUpdatePending = false
local trinketsDispatchFrame = CreateFrame("Frame")
trinketsDispatchFrame:Hide()
local TRINKETS_COOLDOWN_WATCH_OWNER = "CDM_Trinkets"
local TRINKETS_SPELL_WATCH_OWNER = "CDM_Trinkets_Spells"

local getItemSpell = C_Item and C_Item.GetItemSpell

local DEFENSIVES_EDGE_ANCHORS = {
    TOPLEFT = { point = "BOTTOMLEFT", relativePoint = "BOTTOMRIGHT", xSign = 1 },
    TOPRIGHT = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMLEFT", xSign = -1 },
    BOTTOMLEFT = { point = "TOPLEFT", relativePoint = "TOPRIGHT", xSign = 1 },
    BOTTOMRIGHT = { point = "TOPRIGHT", relativePoint = "TOPLEFT", xSign = -1 },
}


local function GetTrinketMode()
    local db = CDM.db
    if not db then return "independent" end
    return db.trinketsMode or "independent"
end

function CDM.GetTrinketMode()
    return currentMode
end

function CDM.GetTrinketIconFrames()
    if not isEnabled then return nil end
    return iconFrames
end

local iconSizeCache = { w = 40, h = 36 }
local trinketsTrackerAcquireOpts = {
    size = iconSizeCache,
    named = false,
}
local function GetIconSize()
    iconSizeCache.w = CDM.db and CDM.db.trinketsIconWidth or 40
    iconSizeCache.h = CDM.db and CDM.db.trinketsIconHeight or 36
    return iconSizeCache
end

-- =========================================================================
-- CACHED STYLING
-- =========================================================================
local function RefreshCachedTrinketsStyles()
    CDM_C.RefreshBaseFontCache()
end

CDM.RefreshCachedTrinketsStyles = RefreshCachedTrinketsStyles

local GetSpacing = CDM.GetTrackerSpacing

local function InvalidateTrinketsLayoutCache()
    lastTrinketsVisibilityHash = -1
    lastTrinketsSpacing = nil
    lastTrinketsPositionAnchor = nil
    lastTrinketsWidth = nil
    lastTrinketsHeight = nil
end

local function CreateIconFrame(slotID)
    GetIconSize()
    local frame = CDM.AcquireFromTrackerPool(iconFramePool, trinketsContainer, "CDM_Trinket_", slotID, trinketsTrackerAcquireOpts)

    frame.slotID = slotID
    frame.itemID = nil
    frame.spellID = nil
    frame.isOnUse = false

    return frame
end

local function ResetTrinketTrackerFrame(frame)
    frame.slotID = nil
    frame.itemID = nil
    frame.spellID = nil
    frame.isOnUse = nil
    if frame.Icon then
        frame.Icon:SetTexture(nil)
        frame.Icon:SetDesaturation(0)
    end
    local fd = CDM.GetFrameData(frame)
    fd.cdmCooldownStyled = nil
end

local function AcquireTrinketFrames()
    if not iconFrames[1] then
        iconFrames[1] = CreateIconFrame(TRINKET_SLOT_1)
    end
    if not iconFrames[2] then
        iconFrames[2] = CreateIconFrame(TRINKET_SLOT_2)
    end
end

local function ReleaseTrinketFramesForLowMemory()
    for i = 1, #iconFrames do
        local frame = iconFrames[i]
        if frame then
            frame:SetParent(trinketsContainer)
            CDM.ReleaseToTrackerPool(iconFramePool, frame, ResetTrinketTrackerFrame)
        end
        iconFrames[i] = nil
    end
    table.wipe(injectionScratch)
    if CDM.ClearTrackerPool then
        CDM.ClearTrackerPool(iconFramePool)
    end
    InvalidateTrinketsLayoutCache()
end

-- Refresh trinket data for a frame (called on equipment change)
local function RefreshTrinketData(frame)
    if not frame or not frame.slotID then return end

    local prevItemID = frame.itemID
    local prevSpellID = frame.spellID
    local prevIsOnUse = frame.isOnUse

    local itemID = GetInventoryItemID("player", frame.slotID)
    frame.itemID = itemID

    if itemID then
        local texture = C_Item.GetItemIconByID(itemID)
        if texture and frame.Icon then
            frame.Icon:SetTexture(texture)
        end

        local spellName, spellID
        if getItemSpell then
            spellName, spellID = getItemSpell(itemID)
        end
        if spellID then
            frame.spellID = spellID
            frame.isOnUse = true
        else
            frame.spellID = nil
            frame.isOnUse = false
        end
    else
        frame.itemID = nil
        frame.spellID = nil
        frame.isOnUse = false
        if frame.Icon then
            frame.Icon:SetTexture(nil)
        end
    end

    local dataChanged = (prevItemID ~= frame.itemID) or (prevSpellID ~= frame.spellID) or (prevIsOnUse ~= frame.isOnUse)
    if dataChanged then
        CDM.GetFrameData(frame).cdmCooldownStyled = false
    end

    return dataChanged
end

local UpdateTrinketCooldowns  -- forward declaration (used in InitializeTrinkets before definition)
local trinketsStartupCooldownGate = CDM.CreateStartupSettleGate(function()
    -- Run one cooldown refresh after suppression lifts so startup watcher events
    -- dropped during warmup do not leave stale trinket cooldown state.
    UpdateTrinketCooldowns()
end)

local function DoQueuedTrinketCooldowns()
    trinketsCooldownUpdatePending = false
    UpdateTrinketCooldowns()
end

trinketsDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoQueuedTrinketCooldowns()
end)

local function QueueTrinketCooldownsUpdate()
    if not isEnabled or not trinketsStartupCooldownGate:IsSettled() then
        return
    end
    if trinketsCooldownUpdatePending then
        return
    end
    trinketsCooldownUpdatePending = true
    trinketsDispatchFrame:Show()
end

local function OnTrinketCooldownWatchChanged()
    QueueTrinketCooldownsUpdate()
end

local function OnTrinketSpellWatchChanged(cooldownsChanged, chargesChanged)
    if cooldownsChanged or chargesChanged then
        QueueTrinketCooldownsUpdate()
    end
end

local function RegisterTrinketCooldownWatches()
    if not (CDM.WatchInventorySlotCooldown and CDM.UnwatchAllCooldowns) then
        return
    end

    CDM.UnwatchAllCooldowns(TRINKETS_COOLDOWN_WATCH_OWNER)
    CDM.WatchInventorySlotCooldown(TRINKETS_COOLDOWN_WATCH_OWNER, TRINKET_SLOT_1, OnTrinketCooldownWatchChanged)
    CDM.WatchInventorySlotCooldown(TRINKETS_COOLDOWN_WATCH_OWNER, TRINKET_SLOT_2, OnTrinketCooldownWatchChanged)
end

local function UnregisterTrinketCooldownWatches()
    if CDM.UnwatchAllCooldowns then
        CDM.UnwatchAllCooldowns(TRINKETS_COOLDOWN_WATCH_OWNER)
    end
end

local function RegisterTrinketSpellWatches()
    if not (CDM.WatchSpellState and CDM.UnwatchAllSpellStates) then
        return
    end

    CDM.UnwatchAllSpellStates(TRINKETS_SPELL_WATCH_OWNER)
    for _, frame in ipairs(iconFrames) do
        if frame.spellID then
            CDM.WatchSpellState(TRINKETS_SPELL_WATCH_OWNER, frame.spellID, OnTrinketSpellWatchChanged)
        end
    end
end

local function UnregisterTrinketSpellWatches()
    if CDM.UnwatchAllSpellStates then
        CDM.UnwatchAllSpellStates(TRINKETS_SPELL_WATCH_OWNER)
    end
end

local function UpdateIcon(frame)
    if not frame or not frame:IsShown() then return end

    local isOnCooldown = false

    -- Use per-slot item cooldown (correctly tracks each trinket independently,
    -- including shared cooldowns between on-use trinkets)
    if frame.slotID then
        local start, duration, enable = GetInventoryItemCooldown("player", frame.slotID)
        if start and duration and duration > 1.5 and enable == 1 then
            frame.Cooldown:SetCooldown(start, duration)
            isOnCooldown = true
        else
            frame.Cooldown:Clear()
        end
    else
        frame.Cooldown:Clear()
    end

    if frame.Icon then
        frame.Icon:SetDesaturation(isOnCooldown and 1 or 0)
    end

    if isOnCooldown then
        local fd = CDM.GetFrameData(frame)
        if not fd.cdmCooldownStyled then
            if currentMode == "essential" and CDM_C.VIEWERS and CDM_C.VIEWERS.ESSENTIAL then
                if CDM.ApplyStyle then
                    CDM:ApplyStyle(frame, CDM_C.VIEWERS.ESSENTIAL)
                end
            elseif CDM.ApplyTrackerStyle then
                CDM:ApplyTrackerStyle(frame, "CDM_Trinkets")
            end
            fd.cdmCooldownStyled = true
        end
    end
end

local function PositionIcons()
    local size = GetIconSize()
    local spacing = GetSpacing()
    local anchorPoint = CDM.db and CDM.db.trinketsAnchorPoint or "TOPLEFT"
    CDM.PositionTrackerIcons(trinketsContainer, iconFrames, size, spacing, anchorPoint)
end

function CDM.GetTrinketInjectionFrames()
    if not isEnabled then return nil end
    if currentMode ~= "essential" then return nil end

    local showPassive = true
    local db = CDM.db
    if db and db.trinketsShowPassive ~= nil then
        showPassive = db.trinketsShowPassive
    end

    local count = 0
    for _, frame in ipairs(iconFrames) do
        if frame.itemID and (showPassive or frame.isOnUse) then
            count = count + 1
            injectionScratch[count] = frame
        end
    end
    for i = count + 1, #injectionScratch do
        injectionScratch[i] = nil
    end
    return count > 0 and injectionScratch or nil
end

local function UpdateContainerPosition()
    if not trinketsContainer then return end

    local anchorPoint = CDM.db and CDM.db.trinketsAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.trinketsOffsetX or 0
    local offsetY = CDM.db and CDM.db.trinketsOffsetY or 0
    CDM.AnchorToPlayerFrame(trinketsContainer, anchorPoint, offsetX, offsetY, "Trinkets")
end

-- Anchor trinkets to player frame using defensives position settings
local function UpdateContainerPositionAsDefensives()
    if not trinketsContainer then return end
    local anchorPoint = CDM.db and CDM.db.defensivesAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.defensivesOffsetX or 0
    local offsetY = CDM.db and CDM.db.defensivesOffsetY or 0
    CDM.AnchorToPlayerFrame(trinketsContainer, anchorPoint, offsetX, offsetY, "Trinkets")
end

-- Anchor trinkets container flush to defensives container
local function UpdateContainerPositionDefensives()
    if not trinketsContainer then return end

    local defContainer = _G["CDM_DefensivesContainer"]
    if not defContainer or not defContainer:IsShown() or defContainer:GetWidth() < 1 then
        UpdateContainerPositionAsDefensives()
        return
    end

    CDM.InvalidateTrackerAnchorCache(trinketsContainer)

    local anchorPoint = CDM.db and CDM.db.defensivesAnchorPoint or "TOPLEFT"
    local spacing = GetSpacing()
    local anchor = DEFENSIVES_EDGE_ANCHORS[anchorPoint]
    if not anchor then
        UpdateContainerPositionAsDefensives()
        return
    end

    trinketsContainer:ClearAllPoints()
    -- Align to the fixed vertical edge of defensives container
    SetPixelPerfectPoint(
        trinketsContainer,
        anchor.point,
        defContainer,
        anchor.relativePoint,
        spacing * anchor.xSign,
        0
    )
end

local function OnTrackerPositionUpdate()
    if currentMode == "defensives" then
        UpdateContainerPositionDefensives()
    elseif currentMode == "independent" then
        UpdateContainerPosition()
    end
end

function CDM:InitializeTrinkets()
    if isInitialized then return end

    RefreshCachedTrinketsStyles()

    trinketsContainer = CDM.CreateTrackerContainer("CDM_TrinketsContainer")

    UpdateContainerPosition()

    AcquireTrinketFrames()

    trinketsStartupCooldownGate:Begin()
    -- Initial update can queue essential-viewer injection; mark enabled first so
    -- GetTrinketInjectionFrames() doesn't return nil during fresh-login startup.
    isEnabled = true
    self:UpdateTrinkets()

    CDM.RegisterTrackerPositionCallback("CDM_Trinkets", OnTrackerPositionUpdate)

    local updater = CDM.CreateTrackerUpdater({
        "BAG_UPDATE_DELAYED",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_ENTERING_WORLD",
    }, function(_, event, arg1)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            if arg1 == TRINKET_SLOT_1 or arg1 == TRINKET_SLOT_2 then
                needsStyleUpdate = true
                CDM:UpdateTrinkets()
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
            CDM:UpdateTrinkets()
        end
    end)

    CDM.trinketsUpdater = updater
    RegisterTrinketCooldownWatches()
    RegisterTrinketSpellWatches()
    isInitialized = true
    trinketsStartupCooldownGate:ScheduleSettle()
end

local function EnableTrinkets()
    if not isInitialized or isEnabled then return end
    trinketsStartupCooldownGate:Begin()
    AcquireTrinketFrames()
    local updater = CDM.trinketsUpdater
    if updater then
        updater:RegisterEvent("BAG_UPDATE_DELAYED")
        updater:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        updater:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    RegisterTrinketCooldownWatches()
    RegisterTrinketSpellWatches()
    CDM.RegisterTrackerPositionCallback("CDM_Trinkets", OnTrackerPositionUpdate)
    if trinketsContainer then
        trinketsContainer:Show()
    end
    needsStyleUpdate = true
    isEnabled = true
    CDM:UpdateTrinkets()
    trinketsStartupCooldownGate:ScheduleSettle()
end

local function DisableTrinkets()
    if not isEnabled then return end
    trinketsStartupCooldownGate:Cancel()
    trinketsCooldownUpdatePending = false
    local updater = CDM.trinketsUpdater
    if updater then
        updater:UnregisterAllEvents()
    end
    UnregisterTrinketCooldownWatches()
    UnregisterTrinketSpellWatches()
    CDM.UnregisterTrackerPositionCallback("CDM_Trinkets")
    ReleaseTrinketFramesForLowMemory()
    if trinketsContainer then
        trinketsContainer:Hide()
    end
    isEnabled = false
    -- Queue viewer AFTER clearing isEnabled so GetTrinketInjectionFrames returns nil
    if currentMode == "essential" then
        CDM:QueueViewer(CDM_C.VIEWERS.ESSENTIAL, true)
    end
end

-- Cooldown-only update: skip data refresh, position, and size checks
UpdateTrinketCooldowns = function()
    if not trinketsContainer or not isEnabled then return end

    for _, frame in ipairs(iconFrames) do
        if frame:IsShown() then
            UpdateIcon(frame)
        end
    end
end

-- Update all trinket icons (full refresh: data + position + cooldowns)
function CDM:UpdateTrinkets()
    if not trinketsContainer then return end

    local anyTrinketDataChanged = false
    for _, frame in ipairs(iconFrames) do
        if RefreshTrinketData(frame) then
            anyTrinketDataChanged = true
        end
    end
    if anyTrinketDataChanged then
        RegisterTrinketSpellWatches()
    end

    local showPassive = true
    local db = CDM.db
    if db and db.trinketsShowPassive ~= nil then
        showPassive = db.trinketsShowPassive
    end

    local mode = GetTrinketMode()
    local modeChanged = (mode ~= currentMode)

    if modeChanged then
        -- Switching away from essential: reparent frames back to container
        if currentMode == "essential" then
            for _, frame in ipairs(iconFrames) do
                frame:SetParent(trinketsContainer)
            end
            trinketsContainer:Show()
            -- Queue essential viewer to remove injected trinkets
            CDM:QueueViewer(CDM_C.VIEWERS.ESSENTIAL, true)
        end
        currentMode = mode

        -- Hide keybind containers left over from essential mode
        if mode ~= "essential" then
            local GetFrameData = CDM.GetFrameData
            for _, frame in ipairs(iconFrames) do
                local frameData = GetFrameData(frame)
                if frameData and frameData.cdmKeybindContainer then
                    frameData.cdmKeybindContainer:Hide()
                end
            end
        end
        lastTrinketsWidth = nil
        lastTrinketsHeight = nil
        InvalidateTrinketsLayoutCache()
        CDM.InvalidateTrackerAnchorCache(trinketsContainer)

        if mode == "independent" then
            UpdateContainerPosition()
            CDM.ScheduleTrackerPositionRefresh()
        elseif mode == "defensives" then
            UpdateContainerPositionDefensives()
        end
    end

    local size = GetIconSize()
    local sizeChanged = (lastTrinketsWidth ~= size.w or lastTrinketsHeight ~= size.h)
    if sizeChanged then
        lastTrinketsWidth = size.w
        lastTrinketsHeight = size.h
    end

    if mode == "essential" then
        -- In essential mode, trinket frames are positioned by the essential layout engine.
        -- We still refresh data and show/hide, but skip our own positioning.
        local queueEssentialViewer = modeChanged or anyTrinketDataChanged or needsStyleUpdate or sizeChanged
        for _, frame in ipairs(iconFrames) do
            local hasItem = frame.itemID ~= nil
            local shouldShow = hasItem and (showPassive or frame.isOnUse)
            local wasShown = frame:IsShown()
            if shouldShow then
                frame:Show()
                UpdateIcon(frame)
            else
                frame:Hide()
            end
            if wasShown ~= shouldShow then
                queueEssentialViewer = true
            end
        end
        trinketsContainer:Hide()
        if queueEssentialViewer then
            CDM:QueueViewer(CDM_C.VIEWERS.ESSENTIAL, true)
        end
        -- Consume style invalidation in essential mode after queueing the viewer refresh.
        needsStyleUpdate = false
        return
    end

    local applyStyle = needsStyleUpdate or sizeChanged

    local visibilityHash = 0
    local vBit = 1
    for _, frame in ipairs(iconFrames) do
        if sizeChanged then
            local fd = CDM.GetFrameData(frame)
            fd.cdmCooldownStyled = false
            frame:SetSize(size.w, size.h)

            if frame.Icon then
                frame.Icon:SetAllPoints(frame)
            end
            if frame.Cooldown then
                frame.Cooldown:SetAllPoints(frame)
            end
            if fd.borderFrame then
                fd.borderFrame:SetAllPoints(frame)
            end
        end

        local hasItem = frame.itemID ~= nil
        local shouldShow = hasItem and (showPassive or frame.isOnUse)
        local wasShown = frame:IsShown()

        if shouldShow then
            visibilityHash = visibilityHash + vBit
            frame:Show()
            UpdateIcon(frame)
            -- Fresh login can produce a hidden first pass before inventory/item data settles.
            -- Ensure frames receive full style the first time they become visible.
            if (applyStyle or not wasShown) and CDM.ApplyTrackerStyle then
                CDM:ApplyTrackerStyle(frame, "CDM_Trinkets")
            end
        else
            frame:Hide()
        end
        vBit = vBit + vBit
    end

    needsStyleUpdate = false

    local currentSpacing = GetSpacing()
    local currentAnchor
    if mode == "independent" then
        currentAnchor = db and db.trinketsAnchorPoint or "TOPLEFT"
    elseif mode == "defensives" then
        currentAnchor = db and db.defensivesAnchorPoint or "TOPLEFT"
    end

    local needsReposition = modeChanged or sizeChanged
        or visibilityHash ~= lastTrinketsVisibilityHash
        or currentSpacing ~= lastTrinketsSpacing
        or currentAnchor ~= lastTrinketsPositionAnchor

    if needsReposition then
        lastTrinketsVisibilityHash = visibilityHash
        lastTrinketsSpacing = currentSpacing
        lastTrinketsPositionAnchor = currentAnchor

        if mode == "independent" then
            PositionIcons()
        elseif mode == "defensives" then
            CDM.PositionTrackerIcons(trinketsContainer, iconFrames, size, currentSpacing, currentAnchor)
        end
    end
end

-- =========================================================================
--  REFRESH CALLBACK REGISTRATIONS
-- =========================================================================

local function RefreshTrinketsLifecycle()
    if not isEnabled then return end
    local pendingMode = GetTrinketMode()
    if pendingMode == currentMode then
        if currentMode == "independent" then
            UpdateContainerPosition()
        elseif currentMode == "defensives" then
            UpdateContainerPositionDefensives()
        end
    end
    CDM:UpdateTrinkets()
end

local function OnTrinketsProfileApplied()
    needsStyleUpdate = true
    InvalidateTrinketsLayoutCache()
    if trinketsContainer then
        CDM.InvalidateTrackerAnchorCache(trinketsContainer)
    end
end

if CDM.ModuleManager and CDM.ModuleManager.RegisterModule then
    CDM.ModuleManager:RegisterModule({
        id = "trinkets",
        Initialize = function()
            CDM:InitializeTrinkets()
        end,
        Enable = EnableTrinkets,
        Disable = DisableTrinkets,
        Refresh = RefreshTrinketsLifecycle,
        OnProfileApplied = OnTrinketsProfileApplied,
        ShouldBeEnabled = function(db)
            return db and db.trinketsEnabled ~= false
        end,
    })
end

CDM:RegisterRefreshCallback("trinketsStyles", function()
    RefreshCachedTrinketsStyles()
    needsStyleUpdate = true
    InvalidateTrinketsLayoutCache()
end, 17, { "text_visuals", "trackers_layout", "viewers" })

CDM:RegisterRefreshCallback("trinkets", function()
    local moduleManager = CDM.ModuleManager
    if moduleManager and moduleManager.ReconcileModule then
        moduleManager:ReconcileModule("trinkets")
    end
end, 52, { "trackers_layout", "viewers" })
