local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local Pixel = CDM.Pixel

local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14

local injectionScratch = {}

local currentMode = "independent"
local TRINKETS_COOLDOWN_WATCH_OWNER = "CDM_Trinkets"
local TRINKETS_SPELL_WATCH_OWNER = "CDM_Trinkets_Spells"

local getItemSpell = C_Item and C_Item.GetItemSpell
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemCooldown = GetInventoryItemCooldown

local DEFENSIVES_EDGE_ANCHORS = {
    TOPLEFT = { point = "BOTTOMLEFT", relativePoint = "BOTTOMRIGHT", xSign = 1 },
    TOPRIGHT = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMLEFT", xSign = -1 },
    BOTTOMLEFT = { point = "TOPLEFT", relativePoint = "TOPRIGHT", xSign = 1 },
    BOTTOMRIGHT = { point = "TOPRIGHT", relativePoint = "TOPLEFT", xSign = -1 },
}

local GetSpacing = CDM.GetTrackerSpacing

local function GetTrinketMode()
    local db = CDM.db
    if not db then return "independent" end
    return db.trinketsMode or "independent"
end

function CDM.GetTrinketMode()
    return currentMode
end

local trinketsTracker

function CDM.GetTrinketIconFrames()
    if not trinketsTracker.IsEnabled() then return nil end
    return trinketsTracker.GetIconFrames()
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

local function CreateIconFrame(slotID)
    local iconFramePool = trinketsTracker._iconFramePool
    local container = trinketsTracker.GetContainer()
    local size = CDM.GetTrackerIconSize("trinketsIconWidth", "trinketsIconHeight")
    local opts = { size = size, named = false }
    local frame = CDM.AcquireFromTrackerPool(iconFramePool, container, "CDM_Trinket_", slotID, opts)
    frame.slotID = slotID
    frame.itemID = nil
    frame.spellID = nil
    frame.isOnUse = false
    return frame
end

local function AcquireTrinketFrames()
    local iconFrames = trinketsTracker.GetIconFrames()
    if not iconFrames[1] then
        iconFrames[1] = CreateIconFrame(TRINKET_SLOT_1)
    end
    if not iconFrames[2] then
        iconFrames[2] = CreateIconFrame(TRINKET_SLOT_2)
    end
end

local function ReleaseTrinketFrames()
    local iconFrames = trinketsTracker.GetIconFrames()
    local container = trinketsTracker.GetContainer()
    local iconFramePool = trinketsTracker._iconFramePool
    for i = 1, #iconFrames do
        local frame = iconFrames[i]
        if frame then
            frame:SetParent(container)
            CDM.ReleaseToTrackerPool(iconFramePool, frame, ResetTrinketTrackerFrame)
        end
        iconFrames[i] = nil
    end
    table.wipe(injectionScratch)
    if CDM.ClearTrackerPool then
        CDM.ClearTrackerPool(iconFramePool)
    end
end

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

local function OnTrinketCooldownWatchChanged()
    trinketsTracker.Queue(false)
end

local function OnTrinketSpellWatchChanged(cooldownsChanged, chargesChanged)
    if cooldownsChanged or chargesChanged then
        trinketsTracker.Queue(false)
    end
end

local function RegisterTrinketCooldownWatches()
    if not (CDM.WatchInventorySlotCooldown and CDM.UnwatchAllCooldowns) then return end
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
    if not (CDM.WatchSpellState and CDM.UnwatchAllSpellStates) then return end
    CDM.UnwatchAllSpellStates(TRINKETS_SPELL_WATCH_OWNER)
    local iconFrames = trinketsTracker.GetIconFrames()
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

    if frame.slotID then
        local start, duration, enable = GetInventoryItemCooldown("player", frame.slotID)
        if start and duration and duration > 1.5 and enable == 1 then
            local fd = CDM.GetFrameData(frame)
            if not fd.cdmDurationObj then
                fd.cdmDurationObj = C_DurationUtil.CreateDuration()
            end
            fd.cdmDurationObj:SetTimeFromStart(start, duration)
            frame.Cooldown:SetCooldownFromDurationObject(fd.cdmDurationObj)
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
            elseif CDM.ApplyStyle then
                CDM:ApplyStyle(frame, "CDM_Trinkets")
            end
            fd.cdmCooldownStyled = true
        end
    end
end

local function UpdateContainerPosition()
    local container = trinketsTracker.GetContainer()
    if not container then return end
    local anchorPoint = CDM.db and CDM.db.trinketsAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.trinketsOffsetX or 0
    local offsetY = CDM.db and CDM.db.trinketsOffsetY or 0
    CDM.AnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, "Trinkets")
end

local function UpdateContainerPositionAsDefensives()
    local container = trinketsTracker.GetContainer()
    if not container then return end
    local anchorPoint = CDM.db and CDM.db.defensivesAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.defensivesOffsetX or 0
    local offsetY = CDM.db and CDM.db.defensivesOffsetY or 0
    CDM.AnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, "Trinkets")
end

local function UpdateContainerPositionDefensives()
    local container = trinketsTracker.GetContainer()
    if not container then return end

    local defContainer = _G["CDM_DefensivesContainer"]
    if not defContainer or not defContainer:IsShown() or defContainer:GetWidth() < 1 then
        UpdateContainerPositionAsDefensives()
        return
    end

    CDM.InvalidateTrackerAnchorCache(container)

    local anchorPoint = CDM.db and CDM.db.defensivesAnchorPoint or "TOPLEFT"
    local spacing = GetSpacing()
    local anchor = DEFENSIVES_EDGE_ANCHORS[anchorPoint]
    if not anchor then
        UpdateContainerPositionAsDefensives()
        return
    end

    container:ClearAllPoints()
    Pixel.SetPoint(
        container,
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

local lastTrinketsVisibilityHash = -1
local lastTrinketsSpacing = nil
local lastTrinketsPositionAnchor = nil
local lastTrinketsWidth, lastTrinketsHeight = nil, nil

local function InvalidateTrinketsLayoutCache()
    lastTrinketsVisibilityHash = -1
    lastTrinketsSpacing = nil
    lastTrinketsPositionAnchor = nil
    lastTrinketsWidth = nil
    lastTrinketsHeight = nil
end

trinketsTracker = CDM.CreateTracker({
    containerName       = "CDM_TrinketsContainer",
    viewerName          = "CDM_Trinkets",
    positionCallbackKey = "CDM_Trinkets",
    iconWidthKey        = "trinketsIconWidth",
    iconHeightKey       = "trinketsIconHeight",
    anchorPointKey      = "trinketsAnchorPoint",
    offsetXKey          = "trinketsOffsetX",
    offsetYKey          = "trinketsOffsetY",
    moduleKey           = "trinkets",
    watchOwnerKey       = nil,
    showCharges         = false,
    styleRefreshPriority = 17,
    useEntryPool        = false,
    useDispatch         = true,
    UpdateIcon          = UpdateIcon,
    resetFrame          = ResetTrinketTrackerFrame,
    UpdateContainerPosition = OnTrackerPositionUpdate,
    onStyleRefresh      = InvalidateTrinketsLayoutCache,
})

-- Expose internal pool for frame management
trinketsTracker._iconFramePool = {}

function CDM.GetTrinketInjectionFrames()
    if not trinketsTracker.IsEnabled() then return nil end
    if currentMode ~= "essential" then return nil end

    local showPassive = true
    local db = CDM.db
    if db and db.trinketsShowPassive ~= nil then
        showPassive = db.trinketsShowPassive
    end

    local iconFrames = trinketsTracker.GetIconFrames()
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

function CDM:InitializeTrinkets()
    trinketsTracker.Initialize()

    AcquireTrinketFrames()

    local updater = CDM.CreateTrackerUpdater({
        "BAG_UPDATE_DELAYED",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_ENTERING_WORLD",
    }, function(_, event, arg1)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            if arg1 == TRINKET_SLOT_1 or arg1 == TRINKET_SLOT_2 then
                trinketsTracker.InvalidateStyle()
                CDM:UpdateTrinkets()
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
            CDM:UpdateTrinkets()
        end
    end)

    CDM.trinketsUpdater = updater
    RegisterTrinketCooldownWatches()
    RegisterTrinketSpellWatches()
end

local function EnableTrinkets()
    trinketsTracker.Enable()

    AcquireTrinketFrames()

    local updater = CDM.trinketsUpdater
    if updater then
        updater:RegisterEvent("BAG_UPDATE_DELAYED")
        updater:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        updater:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    RegisterTrinketCooldownWatches()
    RegisterTrinketSpellWatches()
    CDM:UpdateTrinkets()
end

local function DisableTrinkets()
    if not trinketsTracker.IsEnabled() then return end

    local updater = CDM.trinketsUpdater
    if updater then
        updater:UnregisterAllEvents()
    end
    UnregisterTrinketCooldownWatches()
    UnregisterTrinketSpellWatches()

    ReleaseTrinketFrames()

    trinketsTracker.Disable()

    if currentMode == "essential" then
        local essViewer = _G[CDM_C.VIEWERS.ESSENTIAL]
        if essViewer then CDM:ForceReanchor(essViewer) end
    end
end

function CDM:UpdateTrinkets()
    local container = trinketsTracker.GetContainer()
    if not container then return end

    local iconFrames = trinketsTracker.GetIconFrames()
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
        if currentMode == "essential" then
            for _, frame in ipairs(iconFrames) do
                frame:SetParent(container)
            end
            container:Show()
            local essViewer = _G[CDM_C.VIEWERS.ESSENTIAL]
            if essViewer then CDM:ForceReanchor(essViewer) end
        end
        currentMode = mode
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
        CDM.InvalidateTrackerAnchorCache(container)

        if mode == "independent" then
            UpdateContainerPosition()
            CDM.ScheduleTrackerPositionRefresh()
        elseif mode == "defensives" then
            UpdateContainerPositionDefensives()
        end
    end

    local size = CDM.GetTrackerIconSize("trinketsIconWidth", "trinketsIconHeight")
    local sizeChanged = (lastTrinketsWidth ~= size.w or lastTrinketsHeight ~= size.h)
    if sizeChanged then
        lastTrinketsWidth = size.w
        lastTrinketsHeight = size.h
    end

    if mode == "essential" then
        local styleDirty = trinketsTracker.ConsumeStyleDirty()
        local queueEssentialViewer = modeChanged or anyTrinketDataChanged or sizeChanged or styleDirty
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
        container:Hide()
        if queueEssentialViewer then
            local essViewer = _G[CDM_C.VIEWERS.ESSENTIAL]
            if essViewer then CDM:ForceReanchor(essViewer) end
        end
        return
    end

    local styleDirty = trinketsTracker.ConsumeStyleDirty()
    local applyStyle = sizeChanged or styleDirty

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

            if (applyStyle or not wasShown) and CDM.ApplyStyle then
                CDM:ApplyStyle(frame, "CDM_Trinkets")
            end
        else
            frame:Hide()
        end
        vBit = vBit + vBit
    end

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
            CDM.PositionTrackerIconsFromDB(container, iconFrames, "trinketsIconWidth", "trinketsIconHeight", "spacing", "trinketsAnchorPoint")
        elseif mode == "defensives" then
            CDM.PositionTrackerIcons(container, iconFrames, size, currentSpacing, currentAnchor)
        end
    end
end

local function OnTrinketsProfileApplied()
    trinketsTracker.OnProfileApplied()
    InvalidateTrinketsLayoutCache()
    local container = trinketsTracker.GetContainer()
    if container then
        CDM.InvalidateTrackerAnchorCache(container)
    end
end

local function RefreshTrinketsLifecycle()
    if not trinketsTracker.IsEnabled() then return end
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

local function ReconcileTrinkets()
    if CDM.db and CDM.db.trinketsEnabled ~= false then
        if not trinketsTracker.IsInitialized() then CDM:InitializeTrinkets() end
        if not trinketsTracker.IsEnabled() then EnableTrinkets() end
        RefreshTrinketsLifecycle()
    elseif trinketsTracker.IsEnabled() then
        DisableTrinkets()
    end
end

CDM.ReconcileTrinkets = ReconcileTrinkets
CDM.OnTrinketsProfileApplied = OnTrinketsProfileApplied
