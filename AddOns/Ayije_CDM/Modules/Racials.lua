local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}

local RACE_RACIALS = {
    Scourge           = { 7744 },
    Tauren            = { 20549 },
    Orc               = { 20572, 33697, 33702 },
    BloodElf          = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
    Dwarf             = { 20594 },
    Troll             = { 26297 },
    Draenei           = { 28880 },
    NightElf          = { 58984 },
    Human             = { 59752 },
    DarkIronDwarf     = { 265221 },
    Gnome             = { 20589 },
    HighmountainTauren = { 69041 },
    Worgen            = { 68992 },
    Goblin            = { 69070 },
    Pandaren          = { 107079 },
    MagharOrc         = { 274738 },
    LightforgedDraenei = { 255647 },
    VoidElf           = { 256948 },
    KulTiran          = { 287712 },
    ZandalariTroll    = { 291944 },
    Vulpera           = { 312411 },
    Mechagnome        = { 312924 },
    Dracthyr          = { 357214, { 368970, class = "EVOKER" } },
    EarthenDwarf      = { 436344 },
    Haranir           = { 1287685 },
}

-- combatLockout: cooldown starts after leaving combat
local ITEMS = {
    { itemID = 241304, spellID = 1234768, alternateItemID = 241305 }, -- Silvermoon Health Potion
    { itemID = 241308, spellID = 1236616, alternateItemID = 241309 }, -- Light's Potential
    { itemID = 5512,   spellID = 6262, combatLockout = true, requiresWarlockAccess = true },   -- Healthstone
    { itemID = 224464, spellID = 452930, class = "WARLOCK", requiresWarlockAccess = true }, -- Demonic Healthstone
}

local combatLockoutSpells = {}
for _, itemData in ipairs(ITEMS) do
    if itemData.combatLockout and itemData.spellID then
        combatLockoutSpells[itemData.spellID] = itemData.itemID
    end
end

local BUILTIN_SPELL_SET = {}
for _, spells in pairs(RACE_RACIALS) do
    for _, entry in ipairs(spells) do
        local id = type(entry) == "table" and entry[1] or entry
        BUILTIN_SPELL_SET[id] = true
    end
end

local BUILTIN_ITEM_SET = {}
for _, item in ipairs(ITEMS) do
    BUILTIN_ITEM_SET[item.itemID] = true
    if item.alternateItemID then
        BUILTIN_ITEM_SET[item.alternateItemID] = true
    end
end

local EMPTY = {}

local _, playerClass = UnitClass("player")

local isInitialized = false
local isEnabled = false
local needsStyleUpdate = true
local racialsCombatCallbackRegistered = false
local lastRacialsSpecID = nil
local racialsStartupCooldownGate
local racialsContainer
local iconEntries = {}
local iconFrames = {}
local iconFramePool = {}
local iconEntryPool = {}
local playerRace
local lastRacialsWidth, lastRacialsHeight = nil, nil
local lastRacialsSpacing = nil
local lastVisibilityHash = 0

local DesaturationCurve = CDM_C.DesaturationCurve
local GCDFilterCurve = CDM_C.GCDFilterCurve
local gcdActive = false
local GCD_SPELL_ID = CDM_C.GCD_SPELL_ID
local ITEM_COOLDOWN_MIN_SECONDS = 1.6 -- Match GCDFilterCurve threshold.
local PACT_OF_GLUTTONY_TALENT_ID = 386689
local RACIALS_UPDATE_SPELL_COOLDOWNS = "spellCooldowns"
local RACIALS_UPDATE_SPELL_CHARGES = "spellCharges"
local RACIALS_UPDATE_ITEMS = "items"
local RACIALS_UPDATE_ITEM_COOLDOWNS = "itemCooldowns"
local RACIALS_UPDATE_LAYOUT = "layout"
local RACIALS_UPDATE_FULL = "full"
local RACIALS_ITEM_COOLDOWN_WATCH_OWNER = "CDM_Racials"
local RACIALS_SPELL_WATCH_OWNER = "CDM_Racials_Spells"
local QueueRacialsUpdate
local PlayerHasAbility

local function HasVisibleItemCooldown(startTime, duration)
    return startTime and duration and duration >= ITEM_COOLDOWN_MIN_SECONDS
end

local function AnchorRacialsToPartyFrame(partyFrame, side, offsetX, offsetY)
    if not (racialsContainer and partyFrame) then
        return false
    end

    racialsContainer:ClearAllPoints()
    if side == "LEFT" then
        CDM.Pixel.SetPoint(racialsContainer, "RIGHT", partyFrame, "LEFT", offsetX, offsetY)
    else
        CDM.Pixel.SetPoint(racialsContainer, "LEFT", partyFrame, "RIGHT", offsetX, offsetY)
    end
    if not racialsContainer:IsShown() then
        racialsContainer:Show()
    end
    return true
end

local iconSizeCache = { w = 40, h = 36 }
local racialsTrackerAcquireOpts = {
    size = iconSizeCache,
    showCharges = true,
    named = false,
}
local function GetIconSize()
    iconSizeCache.w = CDM.db and CDM.db.racialsIconWidth or 40
    iconSizeCache.h = CDM.db and CDM.db.racialsIconHeight or 36
    return iconSizeCache
end

local function AcquireIconEntryRecord(id, isItem, itemSpellID, isCustom, combatLockout, alternateItemID)
    local entry = table.remove(iconEntryPool)
    if entry then
        table.wipe(entry)
    else
        entry = {}
    end

    entry.id = id
    entry.isItem = isItem
    entry.itemSpellID = itemSpellID
    entry.isCustom = isCustom
    entry.combatLockout = combatLockout and true or false
    entry.alternateItemID = alternateItemID
    entry.requiresWarlockAccess = nil
    entry.inCombatLockout = nil
    entry._spellbookCached = nil
    entry._itemDisplayCount = nil
    entry._itemCountCacheToken = nil
    entry._activeItemID = nil
    entry.frame = nil
    return entry
end

local function ReleaseIconEntryRecord(entry)
    if not entry then return end
    table.wipe(entry)
    iconEntryPool[#iconEntryPool + 1] = entry
end

-- =========================================================================
-- CACHED STYLING
-- =========================================================================
local cachedRacialsStyles = {
    fontPath = nil,
    fontOutline = nil,
    chargeFontSize = 10,
    chargeColor = { r = 1, g = 1, b = 1, a = 1 },
    chargePosition = "BOTTOMRIGHT",
    chargeOffsetX = 0,
    chargeOffsetY = 0,
}
local racialsChargeStyleVersion = 0
local racialsItemCountCacheToken = 0

local function BeginRacialsItemCountPass()
    racialsItemCountCacheToken = racialsItemCountCacheToken + 1
    if racialsItemCountCacheToken > 1000000 then
        racialsItemCountCacheToken = 1
    end
end

local function GetCachedRacialItemDisplayCount(entry)
    if not entry then return nil end
    if entry._itemCountCacheToken ~= racialsItemCountCacheToken then
        local count = C_Item.GetItemCount(entry.id, false, true)
        if count <= 0 and entry.alternateItemID then
            local altCount = C_Item.GetItemCount(entry.alternateItemID, false, true)
            if altCount > 0 then
                entry._itemDisplayCount = altCount
                entry._activeItemID = entry.alternateItemID
            else
                entry._itemDisplayCount = count
                entry._activeItemID = entry.id
            end
        else
            entry._itemDisplayCount = count
            entry._activeItemID = entry.id
        end
        entry._itemCountCacheToken = racialsItemCountCacheToken
    end
    return entry._itemDisplayCount
end

local function RefreshCachedRacialsStyles()
    CDM.RefreshChargeStyleCache(cachedRacialsStyles, "racials")
    racialsChargeStyleVersion = racialsChargeStyleVersion + 1
end

CDM.RefreshCachedRacialsStyles = RefreshCachedRacialsStyles

local GetSpacing = CDM.GetTrackerSpacing

local function GetCustomRacialEntries(specID)
    if not specID then return EMPTY end
    local custom = CDM.db and CDM.db.racialsCustomEntries
    if not custom then return EMPTY end
    return custom[specID] or EMPTY
end

function CDM.GetOrderedRacialEntries(specID)
    local entries = {}
    local entryByID = {}

    local raceSpells = RACE_RACIALS[playerRace] or {}
    for _, spellEntry in ipairs(raceSpells) do
        local spellID = type(spellEntry) == "table" and spellEntry[1] or spellEntry
        local spellClass = type(spellEntry) == "table" and spellEntry.class
        if (not spellClass or spellClass == playerClass) and C_SpellBook.IsSpellInSpellBook(spellID) then
            local entry = { id = spellID, isItem = false }
            entries[#entries + 1] = entry
            entryByID[spellID] = entry
        end
    end

    for _, itemData in ipairs(ITEMS) do
        if not itemData.class or itemData.class == playerClass then
            local entry = {
                id = itemData.itemID,
                isItem = true,
                itemSpellID = itemData.spellID,
                combatLockout = itemData.combatLockout,
                requiresWarlockAccess = itemData.requiresWarlockAccess and true or false,
                alternateItemID = itemData.alternateItemID,
            }
            entries[#entries + 1] = entry
            entryByID[itemData.itemID] = entry
        end
    end

    for _, customEntry in ipairs(GetCustomRacialEntries(specID)) do
        if not entryByID[customEntry.id] then
            local resolvedSpellID = customEntry.spellID
            if customEntry.isItem and not resolvedSpellID then
                local _, s = C_Item.GetItemSpell(customEntry.id)
                resolvedSpellID = s
            end
            local entry = { id = customEntry.id, isItem = customEntry.isItem, itemSpellID = resolvedSpellID, isCustom = true }
            entries[#entries + 1] = entry
            entryByID[customEntry.id] = entry
        end
    end

    local savedOrder = specID and CDM.db and CDM.db.racialsOrderPerSpec and CDM.db.racialsOrderPerSpec[specID]
    if not savedOrder then return entries end

    local result = {}
    local added = {}

    for _, id in ipairs(savedOrder) do
        if entryByID[id] then
            result[#result + 1] = entryByID[id]
            added[id] = true
        elseif BUILTIN_SPELL_SET[id] then
            -- Racial from another race; substitute current race's racials here
            for _, entry in ipairs(entries) do
                if not entry.isItem and not entry.isCustom and not added[entry.id] then
                    result[#result + 1] = entry
                    added[entry.id] = true
                end
            end
        end
    end

    for _, entry in ipairs(entries) do
        if not added[entry.id] then
            result[#result + 1] = entry
        end
    end

    return result
end

local function CreateIconFrame(id, isItem, itemSpellID, isCustom)
    GetIconSize()
    local frame = CDM.AcquireFromTrackerPool(iconFramePool, racialsContainer, "CDM_Racial_", id, racialsTrackerAcquireOpts)

    frame.spellID = isItem and nil or id
    frame.itemID = isItem and id or nil
    frame.itemSpellID = itemSpellID
    frame.isItem = isItem
    frame.isCustomSpell = (isCustom and not isItem) or false
    frame._spellbookCached = nil

    local texture
    if isItem then
        texture = C_Item.GetItemIconByID(id)
    else
        texture = C_Spell.GetSpellTexture(CDM.GetEffectiveSpellID(id))
    end

    if texture and frame.Icon then
        frame.Icon:SetTexture(texture)
        frame.Icon:SetDesaturation(0)
    end

    return frame
end

local function SyncEntryToFrame(entry, frame)
    frame.spellID = entry.isItem and nil or entry.id
    frame.itemID = entry.isItem and entry.id or nil
    frame.itemSpellID = entry.itemSpellID
    frame.isItem = entry.isItem
    frame.isCustomSpell = (entry.isCustom and not entry.isItem) or false
    frame.combatLockout = entry.combatLockout or false
    frame.requiresWarlockAccess = entry.requiresWarlockAccess or false
    frame.inCombatLockout = entry.inCombatLockout
    frame._spellbookCached = entry._spellbookCached
    frame.cdmRacialEntry = entry
end

local function BindEntryFrame(entry)
    local frame = entry.frame
    local boundNow = false
    if not frame then
        frame = CreateIconFrame(entry.id, entry.isItem, entry.itemSpellID, entry.isCustom)
        entry.frame = frame
        boundNow = true
    end
    SyncEntryToFrame(entry, frame)
    return frame, boundNow
end

local function ResetRacialTrackerFrame(f)
    f.spellID = nil
    f.itemID = nil
    f.itemSpellID = nil
    f.isItem = nil
    f.combatLockout = nil
    f.requiresWarlockAccess = nil
    f.inCombatLockout = nil
    f.isCustomSpell = nil
    f._spellbookCached = nil
    f.cdmRacialEntry = nil
    f._cdmRacialChargeValue = nil
    f._cdmRacialsChargeStyleVersion = nil
end

local function ReleaseEntryFrame(entry)
    local frame = entry and entry.frame
    if not frame then return end

    entry.frame = nil
    CDM.ReleaseToTrackerPool(iconFramePool, frame, ResetRacialTrackerFrame)
end

local function ReleaseRacialFramesForLowMemory()
    for _, entry in ipairs(iconEntries) do
        ReleaseEntryFrame(entry)
    end
    table.wipe(iconFrames)
    if CDM.ClearTrackerPool then
        CDM.ClearTrackerPool(iconFramePool)
    end
    lastVisibilityHash = -1
    lastRacialsWidth = nil
    lastRacialsHeight = nil
    lastRacialsSpacing = nil
end

local function UpdateIcon(frame, updateCooldowns, updateCharges)
    if not frame or not frame:IsShown() then return end
    if updateCooldowns == nil then updateCooldowns = true end
    if updateCharges == nil then updateCharges = true end

    local hasCharges = false
    local desatDurationObject = nil
    local isOnGCD = false
    local itemCooldownActive = false
    local itemCount = nil
    local showEmptyItem = false

    if frame.isItem then
        local itemID = frame.itemID
        if not itemID then return end

        local itemSpellID = frame.itemSpellID
        local entry = frame.cdmRacialEntry

        if updateCooldowns or updateCharges then
            itemCount = GetCachedRacialItemDisplayCount(entry)
            if itemCount == nil then
                itemCount = C_Item.GetItemCount(itemID, false, true)
            end
            showEmptyItem = itemCount ~= nil
                and itemCount <= 0
                and CDM.db
                and CDM.db.racialsShowItemsAtZeroStacks == true
        end

        if updateCooldowns and itemSpellID then
            local SCD = C_Spell.GetSpellCooldownDuration(itemSpellID)
            local itemCdStart, itemCdDuration = C_Container.GetItemCooldown(entry and entry._activeItemID or itemID)
            local hasItemCooldown = HasVisibleItemCooldown(itemCdStart, itemCdDuration)

            if gcdActive and SCD then
                local cdInfo = C_Spell.GetSpellCooldown(itemSpellID)
                isOnGCD = cdInfo and cdInfo.isOnGCD or false
            end

            if hasItemCooldown then
                frame.Cooldown:SetCooldown(itemCdStart, itemCdDuration)
                itemCooldownActive = true
            elseif not isOnGCD and SCD then
                frame.Cooldown:SetCooldownFromDurationObject(SCD)
            else
                frame.Cooldown:Clear()
            end

            desatDurationObject = SCD
        elseif updateCooldowns then
            local startTime, durationSeconds, enableCooldownTimer = C_Container.GetItemCooldown(entry and entry._activeItemID or itemID)

            if HasVisibleItemCooldown(startTime, durationSeconds) then
                frame.Cooldown:SetCooldown(startTime, durationSeconds)
                itemCooldownActive = true
            else
                frame.Cooldown:Clear()
            end
        end

        if updateCharges then
            if itemCount ~= nil and not showEmptyItem then
                local chargeText = CDM.EnsureTrackerChargeWidgets(frame)
                if chargeText then
                    if frame._cdmRacialChargeValue ~= itemCount then
                        chargeText:SetText(itemCount)
                        frame._cdmRacialChargeValue = itemCount
                    end
                end
                hasCharges = true
            end
        end
    else
        local spellID = frame.spellID
        if not spellID then return end

        local effectiveID = CDM.GetEffectiveSpellID(spellID)

        if updateCooldowns then
            local CCD = C_Spell.GetSpellChargeDuration(effectiveID)
            local SCD = C_Spell.GetSpellCooldownDuration(effectiveID)

            if gcdActive and SCD then
                local cdInfo = C_Spell.GetSpellCooldown(effectiveID)
                isOnGCD = cdInfo and cdInfo.isOnGCD or false
            end

            if not isOnGCD then
                local durObj = CCD or SCD
                if durObj then
                    frame.Cooldown:SetCooldownFromDurationObject(durObj)
                else
                    frame.Cooldown:Clear()
                end
            else
                frame.Cooldown:Clear()
            end

            if SCD then
                desatDurationObject = SCD
            end
        end

        if updateCharges then
            local entry = frame.cdmRacialEntry
            if entry and entry.hasMultipleCharges then
                local chargeInfo = C_Spell.GetSpellCharges(effectiveID)
                if chargeInfo and chargeInfo.currentCharges then
                    local chargeText = CDM.EnsureTrackerChargeWidgets(frame)
                    if chargeText then
                        chargeText:SetText(C_StringUtil.TruncateWhenZero(chargeInfo.currentCharges))
                    end
                    hasCharges = true
                end
            end
        end
    end

    if updateCooldowns and frame.Icon then
        if frame.inCombatLockout then
            frame.Icon:SetDesaturation(1)
            frame.Cooldown:Clear()
        elseif itemCooldownActive then
            frame.Icon:SetDesaturation(1)
        elseif showEmptyItem then
            frame.Icon:SetDesaturation(1)
        elseif desatDurationObject then
            local curve = isOnGCD and GCDFilterCurve or DesaturationCurve
            if curve and desatDurationObject.EvaluateRemainingDuration then
                frame.Icon:SetDesaturation(desatDurationObject:EvaluateRemainingDuration(curve, 0) or 0)
            else
                frame.Icon:SetDesaturation(0)
            end
        else
            frame.Icon:SetDesaturation(0)
        end
    end

    if updateCharges and frame.ChargeCount and frame.ChargeCount.Current then
        local chargeText = frame.ChargeCount.Current

        if hasCharges then
            local styles = cachedRacialsStyles
            if not styles.fontPath then
                RefreshCachedRacialsStyles()
            end
            if frame._cdmRacialsChargeStyleVersion ~= racialsChargeStyleVersion or not chargeText:IsShown() then
                CDM.StyleChargeText(chargeText, frame, styles)
                frame._cdmRacialsChargeStyleVersion = racialsChargeStyleVersion
            end
        else
            frame._cdmRacialChargeValue = nil
            chargeText:Hide()
        end
    end
end

local function PositionIcons()
    local size = GetIconSize()
    local spacing = GetSpacing()
    local anchorPoint = CDM.db and CDM.db.racialsAnchorPoint or "TOPLEFT"
    CDM.PositionTrackerIcons(racialsContainer, iconFrames, size, spacing, anchorPoint)
end

local function InvalidateSpellbookCache()
    for _, entry in ipairs(iconEntries) do
        entry._spellbookCached = nil
        entry.hasMultipleCharges = nil
        if entry.frame then
            entry.frame._spellbookCached = nil
        end
    end
end

local function PlayerHasWarlockAccess()
    if playerClass == "WARLOCK" then
        return true
    end

    if not IsInGroup() then
        return false
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local _, classTag = UnitClass("raid" .. i)
            if classTag == "WARLOCK" then
                return true
            end
        end
        return false
    end

    for i = 1, GetNumSubgroupMembers() do
        local _, classTag = UnitClass("party" .. i)
        if classTag == "WARLOCK" then
            return true
        end
    end

    return false
end

local function PlayerHasPactOfGluttony()
    if playerClass ~= "WARLOCK" then
        return false
    end

    return IsPlayerSpell(PACT_OF_GLUTTONY_TALENT_ID) == true
end

PlayerHasAbility = function(entry)
    local id = entry.id
    if id and CDM.db and CDM.db.racialsDisabled and CDM.db.racialsDisabled[id] then
        return false
    end

    if entry.isItem then
        if entry.requiresWarlockAccess and not PlayerHasWarlockAccess() then
            return false
        end
        if entry.id == 5512 and PlayerHasPactOfGluttony() then
            return false
        end
        if entry.id == 224464 and not PlayerHasPactOfGluttony() then
            return false
        end

        local itemCount = GetCachedRacialItemDisplayCount(entry)
        if itemCount and itemCount > 0 then
            return true
        end
        if entry.combatLockout and entry.inCombatLockout then
            return true
        end
        if CDM.db and CDM.db.racialsShowItemsAtZeroStacks == true then
            return true
        end
        return false
    end

    if entry._spellbookCached ~= nil then
        return entry._spellbookCached
    end

    local known
    if entry.isCustom and not entry.isItem then
        known = C_SpellBook.IsSpellInSpellBook(entry.id)
            or C_SpellBook.IsSpellInSpellBook(entry.id, Enum.SpellBookSpellBank.Pet)
    else
        known = C_SpellBook.IsSpellInSpellBook(entry.id)
    end

    entry._spellbookCached = known
    if entry.frame then
        entry.frame._spellbookCached = known
    end
    return known
end

local racialsLastUsedPartyAnchor = false

local function UpdateContainerPosition()
    if not racialsContainer then return end

    local usePartyFrame = CDM.db and CDM.db.racialsUsePartyFrame or false

    if usePartyFrame then
        local partyFrame = CDM.GetRacialsPartyAnchorFrame and CDM.GetRacialsPartyAnchorFrame()

        if partyFrame then
            local side = CDM.db and CDM.db.racialsPartyFrameSide or "LEFT"
            local offsetX = CDM.db and CDM.db.racialsPartyFrameOffsetX or -6
            local offsetY = CDM.db and CDM.db.racialsPartyFrameOffsetY or 19

            if AnchorRacialsToPartyFrame(partyFrame, side, offsetX, offsetY) then
                racialsLastUsedPartyAnchor = true
                return
            end
        end
    end

    if racialsLastUsedPartyAnchor then
        racialsLastUsedPartyAnchor = false
        CDM.InvalidateTrackerAnchorCache(racialsContainer)
        CDM.ScheduleTrackerPositionRefresh()
    end

    local anchorPoint = CDM.db and CDM.db.racialsAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.racialsOffsetX or 0
    local offsetY = CDM.db and CDM.db.racialsOffsetY or 0
    CDM.AnchorToPlayerFrame(racialsContainer, anchorPoint, offsetX, offsetY, "Racials")
end

local racialsUpdatePending = false
local racialsDispatchFrame = CreateFrame("Frame")
racialsDispatchFrame:Hide()
local racialsQueuedFullUpdate = false
local racialsQueuedSpellCooldownUpdate = false
local racialsQueuedSpellChargeUpdate = false
local racialsQueuedItemUpdate = false
local racialsQueuedItemCooldownUpdate = false
local racialsQueuedLayoutUpdate = false
local racialsSpellWatcherGcdActive = false
local racialsSpellWatcherGcdActiveValid = false

local function RacialsNeedFullUpdate()
    if needsStyleUpdate then
        return true
    end
    local currentSpec = CDM:GetCurrentSpecID()
    return currentSpec and currentSpec ~= lastRacialsSpecID
end

local function UpdateRacialSpellCooldownsOnly()
    if not racialsContainer or not isEnabled then return end
    if RacialsNeedFullUpdate() then
        CDM:UpdateRacials()
        return
    end

    if racialsSpellWatcherGcdActiveValid then
        gcdActive = racialsSpellWatcherGcdActive
        racialsSpellWatcherGcdActiveValid = false
    else
        gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil
    end
    for _, frame in ipairs(iconFrames) do
        if frame:IsShown() and (not frame.isItem or frame.itemSpellID) then
            UpdateIcon(frame, true, false)
        end
    end
end

local function UpdateRacialSpellChargesOnly()
    if not racialsContainer or not isEnabled then return end
    if RacialsNeedFullUpdate() then
        CDM:UpdateRacials()
        return
    end

    BeginRacialsItemCountPass()
    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil

    for _, frame in ipairs(iconFrames) do
        if frame:IsShown() then
            if frame.isItem then
                if frame.itemSpellID then
                    UpdateIcon(frame, true, true)
                end
            else
                UpdateIcon(frame, false, true)
            end
        end
    end
end

local function UpdateRacialItemCooldownsOnly()
    if not racialsContainer or not isEnabled then return end
    if RacialsNeedFullUpdate() then
        CDM:UpdateRacials()
        return
    end

    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil
    for _, frame in ipairs(iconFrames) do
        if frame:IsShown() and frame.isItem and not frame.itemSpellID then
            UpdateIcon(frame, true, false)
        end
    end
end

racialsStartupCooldownGate = CDM.CreateStartupSettleGate(function()
    if isEnabled then
        UpdateRacialSpellCooldownsOnly()
        UpdateRacialSpellChargesOnly()
        UpdateRacialItemCooldownsOnly()
    end
end)

local function UpdateRacialItemsOnly()
    if not racialsContainer or not isEnabled then return end
    if RacialsNeedFullUpdate() then
        CDM:UpdateRacials()
        return
    end

    BeginRacialsItemCountPass()
    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil

    local visibilityChanged = false
    for _, entry in ipairs(iconEntries) do
        if entry.isItem then
            local shouldShow = PlayerHasAbility(entry)
            local frame = entry.frame
            local wasShown = frame and frame:IsShown() or false

            if shouldShow then
                frame = BindEntryFrame(entry)
                frame:Show()
                if not wasShown and CDM.ApplyTrackerStyle then
                    CDM:ApplyTrackerStyle(frame, "CDM_Racials", true)
                end
                UpdateIcon(frame)
            else
                ReleaseEntryFrame(entry)
            end

            local isShown = entry.frame and entry.frame:IsShown() or false
            if wasShown ~= isShown then
                visibilityChanged = true
            end
        end
    end

    if visibilityChanged then
        local visibleCount = 0
        local visibilityHash = 0
        local bit = 1
        for _, entry in ipairs(iconEntries) do
            local frame = entry.frame
            if frame and frame:IsShown() then
                visibleCount = visibleCount + 1
                iconFrames[visibleCount] = frame
                visibilityHash = visibilityHash + bit
            end
            bit = bit + bit
        end
        for i = visibleCount + 1, #iconFrames do
            iconFrames[i] = nil
        end
        lastVisibilityHash = visibilityHash
        PositionIcons()
    end
end

local function DoRacialsUpdate()
    racialsUpdatePending = false
    if not isEnabled then
        return
    end
    local doFull = racialsQueuedFullUpdate
    local doSpellCooldowns = racialsQueuedSpellCooldownUpdate
    local doSpellCharges = racialsQueuedSpellChargeUpdate
    local doItems = racialsQueuedItemUpdate
    local doItemCooldowns = racialsQueuedItemCooldownUpdate
    local doLayout = racialsQueuedLayoutUpdate

    racialsQueuedFullUpdate = false
    racialsQueuedSpellCooldownUpdate = false
    racialsQueuedSpellChargeUpdate = false
    racialsQueuedItemUpdate = false
    racialsQueuedItemCooldownUpdate = false
    racialsQueuedLayoutUpdate = false

    if doFull then
        if doLayout then
            UpdateContainerPosition()
        end
        CDM:UpdateRacials()
        return
    end

    if (doItems or doItemCooldowns or doSpellCooldowns or doSpellCharges) and RacialsNeedFullUpdate() then
        if doLayout then
            UpdateContainerPosition()
        end
        CDM:UpdateRacials()
        return
    end

    if doLayout then
        UpdateContainerPosition()
    end

    if doItems then
        UpdateRacialItemsOnly()
    end
    if doItemCooldowns and not doItems then
        UpdateRacialItemCooldownsOnly()
    end
    if doSpellCooldowns then
        UpdateRacialSpellCooldownsOnly()
    end
    if doSpellCharges then
        UpdateRacialSpellChargesOnly()
    end
end

racialsDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoRacialsUpdate()
end)

QueueRacialsUpdate = function(reason)
    if reason == RACIALS_UPDATE_FULL then
        racialsQueuedFullUpdate = true
    elseif reason == RACIALS_UPDATE_SPELL_COOLDOWNS then
        racialsQueuedSpellCooldownUpdate = true
    elseif reason == RACIALS_UPDATE_SPELL_CHARGES then
        racialsQueuedSpellChargeUpdate = true
    elseif reason == RACIALS_UPDATE_ITEMS then
        racialsQueuedItemUpdate = true
    elseif reason == RACIALS_UPDATE_ITEM_COOLDOWNS then
        racialsQueuedItemCooldownUpdate = true
    elseif reason == RACIALS_UPDATE_LAYOUT then
        racialsQueuedLayoutUpdate = true
    else
        racialsQueuedSpellCooldownUpdate = true
    end
    if racialsUpdatePending then return end
    racialsUpdatePending = true
    racialsDispatchFrame:Show()
end

local function OnRacialItemCooldownWatchChanged()
    if not isEnabled then return end
    if not racialsStartupCooldownGate:IsSettled() then return end
    QueueRacialsUpdate(RACIALS_UPDATE_ITEM_COOLDOWNS)
end

local function OnRacialSpellWatchChanged(cooldownsChanged, chargesChanged, watcherGcdActive)
    if not isEnabled then return end
    if not racialsStartupCooldownGate:IsSettled() then return end
    if cooldownsChanged then
        racialsSpellWatcherGcdActive = watcherGcdActive and true or false
        racialsSpellWatcherGcdActiveValid = true
        QueueRacialsUpdate(RACIALS_UPDATE_SPELL_COOLDOWNS)
    end
    if chargesChanged then
        QueueRacialsUpdate(RACIALS_UPDATE_SPELL_CHARGES)
    end
end

local function RegisterRacialItemCooldownWatches()
    if not (CDM.WatchItemCooldown and CDM.UnwatchAllCooldowns) then
        return
    end

    CDM.UnwatchAllCooldowns(RACIALS_ITEM_COOLDOWN_WATCH_OWNER)
    for _, entry in ipairs(iconEntries) do
        if entry.isItem and not entry.itemSpellID then
            CDM.WatchItemCooldown(RACIALS_ITEM_COOLDOWN_WATCH_OWNER, entry.id, OnRacialItemCooldownWatchChanged)
        end
    end
end

local function UnregisterRacialItemCooldownWatches()
    if CDM.UnwatchAllCooldowns then
        CDM.UnwatchAllCooldowns(RACIALS_ITEM_COOLDOWN_WATCH_OWNER)
    end
end

local function RegisterRacialSpellWatches()
    if not (CDM.WatchSpellState and CDM.UnwatchAllSpellStates) then
        return
    end

    CDM.UnwatchAllSpellStates(RACIALS_SPELL_WATCH_OWNER)
    for _, entry in ipairs(iconEntries) do
        if entry.isItem then
            if entry.itemSpellID then
                CDM.WatchSpellState(RACIALS_SPELL_WATCH_OWNER, entry.itemSpellID, OnRacialSpellWatchChanged)
            end
        else
            CDM.WatchSpellState(RACIALS_SPELL_WATCH_OWNER, entry.id, OnRacialSpellWatchChanged)
        end
    end
end

local function UnregisterRacialSpellWatches()
    if CDM.UnwatchAllSpellStates then
        CDM.UnwatchAllSpellStates(RACIALS_SPELL_WATCH_OWNER)
    end
end

local function ClearRacialItemCombatLockouts()
    for _, entry in ipairs(iconEntries) do
        if entry.isItem then
            entry.inCombatLockout = nil
            if entry.frame then
                entry.frame.inCombatLockout = nil
            end
        end
    end
end

local function OnRacialsCombatStateChanged(isInCombat)
    if isInCombat then
        return
    end
    ClearRacialItemCombatLockouts()
    QueueRacialsUpdate(RACIALS_UPDATE_ITEMS)
end

local function RegisterRacialsCombatStateListener()
    if racialsCombatCallbackRegistered then
        return
    end
    if CDM:RegisterInternalCallback("OnCombatStateChanged", OnRacialsCombatStateChanged) then
        racialsCombatCallbackRegistered = true
    end
end

local function UnregisterRacialsCombatStateListener()
    if racialsCombatCallbackRegistered then
        CDM:UnregisterInternalCallback("OnCombatStateChanged", OnRacialsCombatStateChanged)
        racialsCombatCallbackRegistered = false
    end
end

function CDM:InitializeRacials()
    if isInitialized then return end

    RefreshCachedRacialsStyles()

    racialsContainer = CDM.CreateTrackerContainer("CDM_RacialsContainer")

    UpdateContainerPosition()

    local _, race = UnitRace("player")
    playerRace = race

    lastRacialsSpecID = CDM:GetCurrentSpecID()
    local ordered = CDM.GetOrderedRacialEntries(lastRacialsSpecID)
    for _, entry in ipairs(ordered) do
        local iconEntry = AcquireIconEntryRecord(
            entry.id,
            entry.isItem,
            entry.itemSpellID,
            entry.isCustom,
            entry.combatLockout,
            entry.alternateItemID
        )
        iconEntry.requiresWarlockAccess = entry.requiresWarlockAccess and true or false
        iconEntries[#iconEntries + 1] = iconEntry
    end

    EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_ENTERING_WORLD", function()
        UpdateContainerPosition()
    end)

    CDM.RegisterTrackerPositionCallback("CDM_Racials", UpdateContainerPosition)

    local updater = CDM.CreateTrackerUpdater({
        "BAG_UPDATE_COOLDOWN",
        "BAG_UPDATE_DELAYED",
        "GROUP_ROSTER_UPDATE",
        "PLAYER_ROLES_ASSIGNED",
        "SPELLS_CHANGED",
    }, function(_, event, arg1, arg2, arg3)
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            QueueRacialsUpdate(RACIALS_UPDATE_ITEMS)
            QueueRacialsUpdate(RACIALS_UPDATE_LAYOUT)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local castSpellID = arg3
            local matchedItemBackedSpell = false

            if castSpellID then
                for _, entry in ipairs(iconEntries) do
                    if entry.isItem and entry.itemSpellID and entry.itemSpellID == castSpellID then
                        matchedItemBackedSpell = true
                        if entry.combatLockout and InCombatLockdown() then
                            entry.inCombatLockout = true
                            if entry.frame then
                                entry.frame.inCombatLockout = true
                            end
                        end
                        QueueRacialsUpdate(RACIALS_UPDATE_ITEMS)
                        break
                    end
                end

                if (not matchedItemBackedSpell) and combatLockoutSpells[castSpellID] and InCombatLockdown() then
                    local targetItemID = combatLockoutSpells[castSpellID]
                    for _, entry in ipairs(iconEntries) do
                        if entry.isItem and entry.id == targetItemID then
                            entry.inCombatLockout = true
                            if entry.frame then
                                entry.frame.inCombatLockout = true
                            end
                            break
                        end
                    end
                    QueueRacialsUpdate(RACIALS_UPDATE_ITEMS)
                end
            end
        elseif event == "SPELLS_CHANGED" then
            InvalidateSpellbookCache()
            QueueRacialsUpdate(RACIALS_UPDATE_FULL)
        elseif event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE_DELAYED" then
            QueueRacialsUpdate(RACIALS_UPDATE_ITEMS)
        else
            QueueRacialsUpdate(RACIALS_UPDATE_FULL)
        end
    end)

    updater:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    RegisterRacialsCombatStateListener()

    CDM.racialsUpdater = updater
    isInitialized = true
    isEnabled = true
    racialsStartupCooldownGate:Begin()
    RegisterRacialItemCooldownWatches()
    RegisterRacialSpellWatches()
    CDM:UpdateRacials()
    racialsStartupCooldownGate:ScheduleSettle()
end

local function EnableRacials()
    if not isInitialized or isEnabled then return end
    local updater = CDM.racialsUpdater
    if updater then
        updater:RegisterEvent("BAG_UPDATE_COOLDOWN")
        updater:RegisterEvent("BAG_UPDATE_DELAYED")
        updater:RegisterEvent("GROUP_ROSTER_UPDATE")
        updater:RegisterEvent("PLAYER_ROLES_ASSIGNED")
        updater:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        updater:RegisterEvent("SPELLS_CHANGED")
        RegisterRacialsCombatStateListener()
    end
    racialsStartupCooldownGate:Begin()
    RegisterRacialItemCooldownWatches()
    RegisterRacialSpellWatches()
    CDM.RegisterTrackerPositionCallback("CDM_Racials", UpdateContainerPosition)
    if racialsContainer then
        racialsContainer:Show()
    end
    needsStyleUpdate = true
    isEnabled = true
    CDM:UpdateRacials()
    racialsStartupCooldownGate:ScheduleSettle()
end

local function DisableRacials()
    if not isEnabled then return end
    local updater = CDM.racialsUpdater
    if updater then
        updater:UnregisterAllEvents()
    end
    UnregisterRacialsCombatStateListener()
    UnregisterRacialItemCooldownWatches()
    UnregisterRacialSpellWatches()
    CDM.UnregisterTrackerPositionCallback("CDM_Racials")
    if racialsContainer then
        racialsContainer:Hide()
    end
    racialsStartupCooldownGate:Cancel()
    racialsUpdatePending = false
    racialsQueuedFullUpdate = false
    racialsQueuedSpellCooldownUpdate = false
    racialsQueuedSpellChargeUpdate = false
    racialsQueuedItemUpdate = false
    racialsQueuedItemCooldownUpdate = false
    racialsQueuedLayoutUpdate = false
    ReleaseRacialFramesForLowMemory()
    racialsSpellWatcherGcdActiveValid = false
    isEnabled = false
end

function CDM:UpdateRacials()
    if not racialsContainer then return end

    local currentSpec = CDM:GetCurrentSpecID()
    if currentSpec and currentSpec ~= lastRacialsSpecID then
        lastRacialsSpecID = currentSpec
        self:ReinitRacialIcons()
        return
    end

    local size = GetIconSize()
    local spacing = GetSpacing()

    local sizeChanged = (lastRacialsWidth ~= size.w or lastRacialsHeight ~= size.h)
    if sizeChanged then
        lastRacialsWidth = size.w
        lastRacialsHeight = size.h
    end

    local spacingChanged = (lastRacialsSpacing ~= spacing)
    if spacingChanged then
        lastRacialsSpacing = spacing
    end

    local applyStyle = needsStyleUpdate or sizeChanged

    BeginRacialsItemCountPass()
    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil

    local visibilityHash = 0
    local bit = 1
    local visibleCount = 0
    for _, entry in ipairs(iconEntries) do
        if PlayerHasAbility(entry) then
            visibilityHash = visibilityHash + bit

            local frame, boundNow = BindEntryFrame(entry)

            if not boundNow and not entry.isItem and frame.Icon then
                local texture = C_Spell.GetSpellTexture(CDM.GetEffectiveSpellID(entry.id))
                if texture then
                    frame.Icon:SetTexture(texture)
                end
            end

            CDM.CacheMultipleCharges(entry, entry.id)

            if sizeChanged then
                frame:SetSize(size.w, size.h)

                if frame.Icon then
                    frame.Icon:SetAllPoints(frame)
                end
                if frame.Cooldown then
                    frame.Cooldown:SetAllPoints(frame)
                end
                if frame.cdmBorderFrame then
                    frame.cdmBorderFrame:SetAllPoints(frame)
                end
                if frame.ChargeCount then
                    frame.ChargeCount:SetAllPoints(frame)
                end
            end

            local wasHidden = not frame:IsShown()
            frame:Show()
            if (applyStyle or wasHidden or boundNow) and CDM.ApplyTrackerStyle then
                CDM:ApplyTrackerStyle(frame, "CDM_Racials", true)
            end
            UpdateIcon(frame)

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

function CDM:ReinitRacialIcons()
    if not isInitialized then return end
    racialsStartupCooldownGate:Cancel()
    CDM.WipeEffectiveIDCache()
    for _, entry in ipairs(iconEntries) do
        ReleaseEntryFrame(entry)
        ReleaseIconEntryRecord(entry)
    end
    table.wipe(iconEntries)
    table.wipe(iconFrames)
    lastVisibilityHash = 0
    racialsSpellWatcherGcdActiveValid = false

    local ordered = CDM.GetOrderedRacialEntries(CDM:GetCurrentSpecID())
    for _, entry in ipairs(ordered) do
        local iconEntry = AcquireIconEntryRecord(
            entry.id,
            entry.isItem,
            entry.itemSpellID,
            entry.isCustom,
            entry.combatLockout,
            entry.alternateItemID
        )
        iconEntry.requiresWarlockAccess = entry.requiresWarlockAccess and true or false
        iconEntries[#iconEntries + 1] = iconEntry
    end
    needsStyleUpdate = true
    if isEnabled then
        racialsStartupCooldownGate:Begin()
        RegisterRacialItemCooldownWatches()
        RegisterRacialSpellWatches()
    end
    self:UpdateRacials()
    CDM.TrimTrackerPool(iconFramePool, #iconEntries)
    if isEnabled then
        racialsStartupCooldownGate:ScheduleSettle()
    end
end

function CDM:AddRacialEntry(id, isItem)
    local specID = CDM:GetCurrentSpecID()
    if not specID then return false end

    if not CDM.db.racialsCustomEntries then
        CDM.db.racialsCustomEntries = {}
    end
    if not CDM.db.racialsCustomEntries[specID] then
        CDM.db.racialsCustomEntries[specID] = {}
    end

    for _, entry in ipairs(CDM.db.racialsCustomEntries[specID]) do
        if entry.id == id and entry.isItem == isItem then return false end
    end

    if isItem then
        if BUILTIN_ITEM_SET[id] then return false end
    else
        if BUILTIN_SPELL_SET[id] then return false end
    end

    local newEntry = { id = id, isItem = isItem }
    if isItem then
        local _, spellID = C_Item.GetItemSpell(id)
        if spellID then
            newEntry.spellID = spellID
        else
            C_Item.RequestLoadItemDataByID(id)
            local resolveFrame = CreateFrame("Frame")
            resolveFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
            resolveFrame:SetScript("OnEvent", function(self, _, loadedID, success)
                if loadedID ~= id then return end
                self:UnregisterAllEvents()
                self:SetScript("OnEvent", nil)
                if not success then return end
                local _, resolved = C_Item.GetItemSpell(id)
                if resolved then
                    newEntry.spellID = resolved
                    CDM:ReinitRacialIcons()
                end
            end)
        end
    end

    table.insert(CDM.db.racialsCustomEntries[specID], newEntry)

    if CDM.db.racialsOrderPerSpec and CDM.db.racialsOrderPerSpec[specID] then
        table.insert(CDM.db.racialsOrderPerSpec[specID], id)
    end

    self:ReinitRacialIcons()
    CDM:RefreshConfig()
    return true
end

function CDM:RemoveRacialEntry(id)
    local specID = CDM:GetCurrentSpecID()
    if not specID then return end

    local list = CDM.db.racialsCustomEntries and CDM.db.racialsCustomEntries[specID]
    if not list then return end

    for i = #list, 1, -1 do
        if list[i].id == id then
            table.remove(list, i)
            break
        end
    end

    if CDM.db.racialsOrderPerSpec and CDM.db.racialsOrderPerSpec[specID] then
        local order = CDM.db.racialsOrderPerSpec[specID]
        for i = #order, 1, -1 do
            if order[i] == id then
                table.remove(order, i)
                break
            end
        end
    end

    self:ReinitRacialIcons()
    CDM:RefreshConfig()
end

-- =========================================================================
--  REFRESH CALLBACK REGISTRATIONS
-- =========================================================================

local function OnRacialsProfileApplied()
    needsStyleUpdate = true
    lastRacialsSpecID = nil
    lastRacialsWidth = nil
    lastRacialsHeight = nil
    lastRacialsSpacing = nil
    lastVisibilityHash = -1
    InvalidateSpellbookCache()
end

local function RefreshRacialsLifecycle()
    if not isEnabled then return end
    UpdateContainerPosition()
    CDM:UpdateRacials()
end

if CDM.ModuleManager and CDM.ModuleManager.RegisterModule then
    CDM.ModuleManager:RegisterModule({
        id = "racials",
        Initialize = function()
            CDM:InitializeRacials()
        end,
        Enable = EnableRacials,
        Disable = DisableRacials,
        Refresh = RefreshRacialsLifecycle,
        OnProfileApplied = OnRacialsProfileApplied,
        ShouldBeEnabled = function(db)
            return db and db.racialsEnabled ~= false
        end,
    })
end

CDM:RegisterRefreshCallback("racialsStyles", function()
    RefreshCachedRacialsStyles()
    needsStyleUpdate = true
end, 15, { "text_visuals", "trackers_layout", "viewers" })

CDM:RegisterRefreshCallback("racials", function()
    local moduleManager = CDM.ModuleManager
    if moduleManager and moduleManager.ReconcileModule then
        moduleManager:ReconcileModule("racials")
    end
end, 50, { "trackers_layout", "viewers" })
