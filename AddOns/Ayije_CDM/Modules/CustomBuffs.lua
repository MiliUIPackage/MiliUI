local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}

-- =========================================================================
--  MODULE STATE
-- =========================================================================

CDM.CustomBuffs = {
    trackedSpells = {},     -- [spellID] = config
    activeBuffs = {},       -- [spellID] = { expires, frame, startTime, duration }
    activeBuffVersion = 0,
    iconFrames = {},        -- [spellID] = frame
    framePool = {},         -- reusable, inactive custom buff frames
}

local CB = CDM.CustomBuffs
local VIEWERS = { BUFF = "BuffIconCooldownViewer" }

-- =========================================================================
--  CACHED STYLING
-- =========================================================================
local cachedCustomBuffStyles = {
    fontPath = nil,
    fontOutline = nil,
    fontSize = 12,
    fontColor = nil,
}

local function RefreshCachedCustomBuffStyles()
    local db = CDM.db
    local defaults = CDM.defaults or {}

    CDM_C.RefreshBaseFontCache()
    cachedCustomBuffStyles.fontPath = CDM_C.GetBaseFontPath()
    cachedCustomBuffStyles.fontOutline = CDM_C.GetBaseFontOutline()
    cachedCustomBuffStyles.fontSize = db and db.buffCooldownFontSize or defaults.buffCooldownFontSize or 12
    cachedCustomBuffStyles.fontColor = (db and db.buffCooldownColor) or defaults.buffCooldownColor or CDM_C.WHITE
end

CDM.RefreshCachedCustomBuffStyles = RefreshCachedCustomBuffStyles

local function StyleCustomBuffTextElement(text)
    if not text or not text.SetFont then return end
    local fontColor = cachedCustomBuffStyles.fontColor or CDM_C.WHITE
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetFont(
        cachedCustomBuffStyles.fontPath,
        CDM.Pixel.FontSize(cachedCustomBuffStyles.fontSize),
        cachedCustomBuffStyles.fontOutline
    )
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(fontColor.r, fontColor.g, fontColor.b)
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function StyleCustomBuffCooldownRegions(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            StyleCustomBuffTextElement(region)
        end
    end
end

local function ApplyCustomBuffCooldownTextStyle(frame)
    if not frame or not frame.Cooldown then return end
    if not cachedCustomBuffStyles.fontPath then
        RefreshCachedCustomBuffStyles()
    end
    local cooldownText = frame.Cooldown.Text or frame.Cooldown.text
    StyleCustomBuffTextElement(cooldownText)
    StyleCustomBuffCooldownRegions(frame.Cooldown:GetRegions())
end

-- =========================================================================
--  ORDERING / LAYOUT HELPERS
-- =========================================================================

local function CompareCustomBuffEntries(a, b)
    local aStart = a.startTime or 0
    local bStart = b.startTime or 0
    if aStart ~= bStart then return aStart < bStart end
    local aID = a.frame and a.frame.spellID or 0
    local bID = b.frame and b.frame.spellID or 0
    return aID < bID
end

local sortBuffer = {}

local function GetSortedCustomBuffEntries()
    table.wipe(sortBuffer)
    for _, buffData in pairs(CB.activeBuffs) do
        if buffData and buffData.frame then
            sortBuffer[#sortBuffer + 1] = buffData
        end
    end

    if #sortBuffer > 1 then
        table.sort(sortBuffer, CompareCustomBuffEntries)
    end

    return sortBuffer
end

local sortedFramesCache = {}
local sortedFramesCacheVersion = -1
local sortedFramesCacheVisibleCount = -1

function CDM:GetSortedCustomBuffFrames()
    local currentVersion = CB.activeBuffVersion or 0

    local visibleCount = 0
    for _, buffData in pairs(CB.activeBuffs) do
        if buffData and buffData.frame and buffData.frame:IsShown() then
            visibleCount = visibleCount + 1
        end
    end

    if sortedFramesCacheVersion == currentVersion
        and sortedFramesCacheVisibleCount == visibleCount
        and visibleCount > 0
    then
        return sortedFramesCache
    end

    table.wipe(sortedFramesCache)
    local entries = GetSortedCustomBuffEntries()
    for _, buffData in ipairs(entries) do
        if buffData.frame and buffData.frame:IsShown() then
            sortedFramesCache[#sortedFramesCache + 1] = buffData.frame
        end
    end

    sortedFramesCacheVersion = currentVersion
    sortedFramesCacheVisibleCount = visibleCount
    return sortedFramesCache
end

local function QueueBuffViewerImmediate()
    if not CDM.QueueViewer then return end
    CDM:QueueViewer(VIEWERS.BUFF, true)
end

local function ProvisionalPlaceCustomBuff(spellID)
    local buffData = CB.activeBuffs[spellID]
    if not buffData or not buffData.frame then return end

    local viewer = _G[VIEWERS.BUFF]
    if not viewer then return end

    local buffContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
    if not buffContainer then return end

    local entries = GetSortedCustomBuffEntries()
    if #entries == 0 then return end

    local index
    for i, entry in ipairs(entries) do
        if entry == buffData then
            index = i
            break
        end
    end
    if not index then return end

    local nativeCount = 0
    if viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                local matchType = CDM.GetBuffRegistryMatch and CDM:GetBuffRegistryMatch(frame)
                if not matchType then
                    nativeCount = nativeCount + 1
                end
            end
        end
    end

    local totalCount = #entries + nativeCount
    if totalCount <= 0 then return end

    local constants = CDM.GetConstants and CDM:GetConstants()
    local size = constants and constants.SIZE_BUFF or { w = 32, h = 32 }
    local spacing = constants and constants.SPACING or 6

    local totalWidth = (totalCount * size.w) + ((totalCount - 1) * spacing)
    local startX = -(totalWidth / 2) + (size.w / 2)
    local x = startX + ((index - 1) * (size.w + spacing))

    local frame = buffData.frame
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame:SetPoint("BOTTOM", buffContainer, "BOTTOM", x, 0)
end

-- =========================================================================
--  ICON FRAME CREATION
-- =========================================================================

local function CreateCustomBuffIcon(spellID, config)
    if CB.iconFrames[spellID] then
        return CB.iconFrames[spellID]
    end

    local defaults = CDM.defaults or {}
    local defaultSize = defaults.sizeBuff or { w = 32, h = 32 }
    local size = {
        w = (CDM.db and CDM.db.sizeBuff and CDM.db.sizeBuff.w) or defaultSize.w,
        h = (CDM.db and CDM.db.sizeBuff and CDM.db.sizeBuff.h) or defaultSize.h,
    }

    local frame = table.remove(CB.framePool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("MEDIUM")

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        CDM.Pixel.DisableTextureSnap(icon)
        frame.Icon = icon

        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
        cooldown:SetReverse(true)  -- Fill up as time passes (like a buff)
        frame.Cooldown = cooldown

        local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        borderFrame:SetAllPoints()
        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(borderFrame)
        end
        CDM.GetFrameData(frame).borderFrame = borderFrame
    end

    frame:SetParent(UIParent)
    frame:SetSize(size.w, size.h)
    frame.spellID = spellID
    frame.isCustomBuff = true
    frame.customBuffStartTime = nil

    if frame.Icon then
        frame.Icon:SetAllPoints()
        CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), size.w, size.h)
        frame.Icon:SetTexture(config.icon)
        frame.Icon:SetDesaturation(0)
    end

    if frame.Cooldown then
        frame.Cooldown:SetAllPoints()
        frame.Cooldown:SetDrawBling(not (CDM.db and CDM.db.hideCooldownBling))
        frame.Cooldown:SetReverse(true)
        frame.Cooldown:SetScript("OnCooldownDone", nil)
    end

    local fd = CDM.GetFrameData(frame)
    if fd.borderFrame then
        fd.borderFrame:SetAllPoints()
    end
    frame:Hide()

    CB.iconFrames[spellID] = frame

    return frame
end

-- =========================================================================
--  BUFF ACTIVATION / DEACTIVATION
-- =========================================================================

local DeactivateCustomBuff

local function ActivateCustomBuff(spellID, config)
    local frame = CreateCustomBuffIcon(spellID, config)

    local startTime = GetTime()
    local duration = config.duration

    frame.Cooldown:SetCooldown(startTime, duration)
    frame.Cooldown:SetScript("OnCooldownDone", function()
        DeactivateCustomBuff(spellID)
    end)
    ApplyCustomBuffCooldownTextStyle(frame)

    CB.activeBuffs[spellID] = {
        expires = startTime + duration,
        frame = frame,
        startTime = startTime,
        duration = duration,
    }
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1

    frame.customBuffStartTime = startTime

    ProvisionalPlaceCustomBuff(spellID)
    frame:Show()
    QueueBuffViewerImmediate()
end

DeactivateCustomBuff = function(spellID)
    local buffData = CB.activeBuffs[spellID]
    if not buffData then return end

    if buffData.frame then
        if buffData.frame.Cooldown then
            buffData.frame.Cooldown:SetScript("OnCooldownDone", nil)
        end
        buffData.frame:Hide()
    end

    CB.activeBuffs[spellID] = nil
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1
    QueueBuffViewerImmediate()
end

-- =========================================================================
--  EVENT HANDLING
-- =========================================================================

local function OnSpellCastSucceeded(event, unit, castGUID, spellID)
    local config = CB.trackedSpells[spellID]
    if not config then return end

    ActivateCustomBuff(spellID, config)
end

-- =========================================================================
--  REGISTRY MANAGEMENT
-- =========================================================================

local function BuildTrackedSpellsTable()
    CB.trackedSpells = {}

    local registry = CDM.db.customBuffRegistry
    if not registry then return end

    for spellID, config in pairs(registry) do
        CB.trackedSpells[spellID] = config
    end
end

local CUSTOM_BUFF_MAX = 9

function CDM:GetCustomBuffCount()
    local registry = CDM.db and CDM.db.customBuffRegistry
    if not registry then return 0 end
    local count = 0
    for _ in pairs(registry) do count = count + 1 end
    return count
end

function CDM:AddCustomBuffSpell(spellID, duration)
    if not spellID or not duration then return false end
    if self:GetCustomBuffCount() >= CUSTOM_BUFF_MAX then return false end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return false end

    if not CDM.db.customBuffRegistry then
        CDM.db.customBuffRegistry = {}
    end

    CDM.db.customBuffRegistry[spellID] = {
        duration = duration,
        name = spellInfo.name,
        icon = spellInfo.iconID,
    }

    CB.trackedSpells[spellID] = CDM.db.customBuffRegistry[spellID]

    return true
end

function CDM:RemoveCustomBuffSpell(spellID)
    if not CDM.db.customBuffRegistry then return end

    if CB.activeBuffs[spellID] then
        DeactivateCustomBuff(spellID)
    end

    local frame = CB.iconFrames[spellID]
    if frame then
        if frame.Cooldown then
            frame.Cooldown:SetScript("OnCooldownDone", nil)
            if frame.Cooldown.Clear then
                frame.Cooldown:Clear()
            else
                frame.Cooldown:SetCooldown(0, 0)
            end
        end
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(UIParent)
        frame.spellID = nil
        frame.customBuffStartTime = nil
        CB.framePool[#CB.framePool + 1] = frame
        CB.iconFrames[spellID] = nil
    end

    CDM.db.customBuffRegistry[spellID] = nil
    CB.trackedSpells[spellID] = nil
end

function CDM:UpdateCustomBuffs()
    RefreshCachedCustomBuffStyles()

    local defaults = CDM.defaults or {}
    local defaultSize = defaults.sizeBuff or { w = 32, h = 32 }
    local size = {
        w = (CDM.db and CDM.db.sizeBuff and CDM.db.sizeBuff.w) or defaultSize.w,
        h = (CDM.db and CDM.db.sizeBuff and CDM.db.sizeBuff.h) or defaultSize.h,
    }

    for spellID, frame in pairs(CB.iconFrames) do
        frame:SetSize(size.w, size.h)

        if frame.Icon then
            CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), size.w, size.h)
        end

        ApplyCustomBuffCooldownTextStyle(frame)
    end
end

-- =========================================================================
--  DEFAULT ENTRIES (seeded on first load)
-- =========================================================================

local DEFAULT_CUSTOM_BUFFS = {
    { spellID = 1236616, duration = 30 },  -- Light's Potential
}

local function SeedDefaultCustomBuffs()
    if CDM.db.customBuffsSeeded then return end

    if not CDM.db.customBuffRegistry then
        CDM.db.customBuffRegistry = {}
    end

    for _, entry in ipairs(DEFAULT_CUSTOM_BUFFS) do
        if not CDM.db.customBuffRegistry[entry.spellID] then
            CDM:AddCustomBuffSpell(entry.spellID, entry.duration)
        end
    end

    CDM.db.customBuffsSeeded = true
end

-- =========================================================================
--  INITIALIZATION
-- =========================================================================

function CDM:InitializeCustomBuffs()
    SeedDefaultCustomBuffs()
    BuildTrackedSpellsTable()
    self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OnSpellCastSucceeded)
end

-- =========================================================================
--  REFRESH CALLBACK REGISTRATION
-- =========================================================================

CDM:RegisterRefreshCallback("customBuffs", function()
    CDM:UpdateCustomBuffs()
end, 50, { "viewers" })
