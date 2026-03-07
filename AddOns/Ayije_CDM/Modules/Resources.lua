local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = CDM.IsSafeNumber
local math_floor = math.floor

local POWER_TYPES = Enum.PowerType
local LSM = LibStub("LibSharedMedia-3.0")

local POWER_TOKEN_MAP = {}
local function ToEventToken(name)
    return (name:gsub("(%l)(%u)", "%1_%2")):upper()
end
for name, value in pairs(Enum.PowerType) do
    POWER_TOKEN_MAP[name] = value
    POWER_TOKEN_MAP[ToEventToken(name)] = value
end

local CUSTOM_POWER_TYPES = {
    SoulFragments = "SoulFragments",
    Stagger = "Stagger",
    MaelstromWeapon = "MaelstromWeapon",
    DevourerSoulFragments = "DevourerSoulFragments",
}
CDM.CUSTOM_POWER_TYPES = CUSTOM_POWER_TYPES

local MAX_SOUL_FRAGMENTS = 6
local MAX_MAELSTROM_WEAPON = 10
local DEVOURER_BASE_SOULS_MAX = 50
local DEVOURER_SOUL_GLUTTON_REDUCED_MAX = 35
local DEVOURER_STACKS_PER_PIP = 5

local isInitialized = false
local isEnabled = false

local currentSpecID
local brewmasterCombatCallbackRegistered = false
local resourcesSpecInitRetries = 0
local _, resourcesPlayerClass = UnitClass("player")
local lastMaelstromAuraUpdateTime = 0
local lastDevourerAuraUpdateTime = 0

local cachedFontPath
local cachedFontSize
local cachedFontOutline
local cachedFontColor
local cachedRuneReadyColor
local cachedRuneRechargingColor
local cachedEssenceReadyColor
local cachedEssenceRechargingColor
local cachedSoulShardReadyColor
local cachedSoulShardRechargingColor
local cachedBar2TagEnabled = false
local cachedBar2OffsetX = 0
local cachedBar2OffsetY = 0

local GetOnePixelSize = CDM_C.GetPixelSizeForRegion
local SetPixelPerfectPoint = CDM_C.SetPixelPerfectPoint
local ToPixelCountForRegion = CDM_C.ToPixelCountForRegion

local function SnapWidthToPixelGrid(frame, width)
    if not width or width <= 0 then
        return width, 0, 1
    end

    local onePixel = GetOnePixelSize(frame)
    local pixelWidth = math.max(1, CDM_C.PixelPerfect(width / onePixel))
    return pixelWidth * onePixel, pixelWidth, onePixel
end

local SnapToPixel = CDM_C.SnapOffsetToPixel

local function SnapFrameVerticallyToPixelGrid(frame)
    if not frame or not frame.GetPoint then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then
        return
    end

    local onePixel = GetOnePixelSize(frame)
    if not onePixel or onePixel <= 0 then
        return
    end

    local top = frame:GetTop()
    if not top then
        return
    end

    local snappedTop = SnapToPixel(top, frame)
    local dy = snappedTop - top
    if math.abs(dy) < (onePixel * 0.05) then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, (xOfs or 0), (yOfs or 0) + dy)
end

local function UpdateUnifiedBorderFrameGeometry(powerTypes)
    local container = CDM.resourceContainer
    local borderFrame = container and container.unifiedBorderFrame
    if not (container and borderFrame) then
        return
    end

    borderFrame:ClearAllPoints()

    local bottomBar
    local topBar
    if powerTypes then
        for _, powerType in ipairs(powerTypes) do
            local bar = CDM.resourceBars and CDM.resourceBars[powerType]
            if bar and bar:IsShown() then
                if not bottomBar then
                    bottomBar = bar
                end
                topBar = bar
            end
        end
    end

    if bottomBar and topBar then
        -- Follow the actual snapped bar bounds. The resource container itself can be
        -- center-anchored with odd pixel widths, but the bars are snapped individually.
        borderFrame:SetPoint("BOTTOMLEFT", bottomBar, "BOTTOMLEFT", 0, 0)
        borderFrame:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", 0, 0)
        return
    end

    borderFrame:SetAllPoints(container)
end

local function AlignResourceContainerXToEssentialCenter()
    local container = CDM.resourceContainer
    if not (container and container.GetCenter) then
        return
    end

    local essentialCenterX = CDM:GetEssentialContentCenterX()
    local resourceCenterX = select(1, container:GetCenter())
    if not (essentialCenterX and resourceCenterX) then
        return
    end

    local onePixel = GetOnePixelSize(container) or 1
    local targetCenterX = essentialCenterX + (CDM.db and CDM.db.resourcesOffsetX or 0)
    local dx = targetCenterX - resourceCenterX
    if math.abs(dx) < (onePixel * 0.05) then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = container:GetPoint(1)
    if not point then
        return
    end

    container:ClearAllPoints()
    container:SetPoint(point, relativeTo, relativePoint, (xOfs or 0) + dx, yOfs or 0)
end

local function ConfigurePixelTexture(tex)
    if not tex then return end
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end


local function HideBarSeparatorFill(bar)
    if bar and bar.separatorFill then
        bar.separatorFill:Hide()
    end
end

local function HideBarPipSeparators(bar, firstIndex)
    if not (bar and bar.isPipBar and bar.separators) then
        return
    end

    for i = (firstIndex or 1), #bar.separators do
        local sep = bar.separators[i]
        if sep then
            sep:Hide()
        end
    end
end

local function IsPipSeparatorBar(bar)
    return bar and bar.isPipBar and bar.separators
end

local function HidePipBarDecorations(bar)
    HideBarSeparatorFill(bar)
    HideBarPipSeparators(bar)
end

local function ResolvePipSeparatorXOffset(bar, index, barLeft, onePixel)
    local xOffset
    local pip = bar.pips and bar.pips[index]
    if barLeft and pip and pip.GetRight then
        local pipRight = pip:GetRight()
        if pipRight then
            xOffset = SnapToPixel(pipRight - barLeft, bar)
        end
    end

    if xOffset == nil then
        local sepPixel = bar.pipBoundaryPixels and bar.pipBoundaryPixels[index]
        if sepPixel and onePixel and onePixel > 0 then
            xOffset = sepPixel * onePixel
        elseif bar.pipPositions and bar.pipWidths then
            xOffset = (bar.pipPositions[index] or 0) + (bar.pipWidths[index] or 0)
        end
    end

    return xOffset
end

local function SetPipSeparatorVerticalLine(sep, bar, xOffset)
    if not (sep and bar) or xOffset == nil then
        return
    end
    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, 0)
    sep:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", xOffset, 0)
end

local POWER_COLOR_KEYS = {
    [POWER_TYPES.Mana] = "resourcesManaColor",
    [POWER_TYPES.Rage] = "resourcesRageColor",
    [POWER_TYPES.Energy] = "resourcesEnergyColor",
    [POWER_TYPES.RunicPower] = "resourcesRunicPowerColor",
    [POWER_TYPES.Fury] = "resourcesFuryColor",
    [POWER_TYPES.Focus] = "resourcesFocusColor",
    [POWER_TYPES.LunarPower] = "resourcesLunarPowerColor",
    [POWER_TYPES.Maelstrom] = "resourcesMaelstromColor",
    [POWER_TYPES.Insanity] = "resourcesInsanityColor",
    [POWER_TYPES.ComboPoints] = "resourcesComboPointsColor",
    [POWER_TYPES.Runes] = "resourcesRunesReadyColor",
    [POWER_TYPES.SoulShards] = "resourcesSoulShardsColor",
    [POWER_TYPES.HolyPower] = "resourcesHolyPowerColor",
    [POWER_TYPES.Chi] = "resourcesChiColor",
    [POWER_TYPES.ArcaneCharges] = "resourcesArcaneChargesColor",
    [POWER_TYPES.Essence] = "resourcesEssenceColor",
    [CUSTOM_POWER_TYPES.SoulFragments] = "resourcesSoulFragmentsColor",
    [CUSTOM_POWER_TYPES.MaelstromWeapon] = "resourcesMaelstromColor",
    [CUSTOM_POWER_TYPES.DevourerSoulFragments] = "resourcesDevourerSoulFragmentsColor",
}

local DEFAULT_WHITE_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local chargedComboPointLookup = {}
local GetDevourerSoulMax

local function GetPowerColor(powerType)
    if powerType == CUSTOM_POWER_TYPES.Stagger then
        return nil
    end

    local key = POWER_COLOR_KEYS[powerType]
    if key then
        local db = CDM.db
        local defaults = CDM.defaults or {}
        return (db and db[key]) or defaults[key] or DEFAULT_WHITE_COLOR
    end

    return DEFAULT_WHITE_COLOR
end

local function IsRogueComboPoints(powerType)
    return resourcesPlayerClass == "ROGUE" and powerType == POWER_TYPES.ComboPoints
end

local function GetComboPointChargeColors()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    local baseColor = (db and db.resourcesComboPointsColor) or defaults.resourcesComboPointsColor or DEFAULT_WHITE_COLOR
    local chargedColor = (db and db.resourcesComboPointsChargedColor) or defaults.resourcesComboPointsChargedColor or baseColor
    local chargedEmptyColor = (db and db.resourcesComboPointsChargedEmptyColor) or defaults.resourcesComboPointsChargedEmptyColor or baseColor
    return chargedColor, chargedEmptyColor
end

local function GetChargedComboPointLookup()
    if resourcesPlayerClass ~= "ROGUE" or type(GetUnitChargedPowerPoints) ~= "function" then
        return nil
    end

    local chargedPoints = GetUnitChargedPowerPoints("player")
    if type(chargedPoints) ~= "table" or #chargedPoints == 0 then
        return nil
    end

    table.wipe(chargedComboPointLookup)

    local hasEntries = false
    for _, pointIndex in ipairs(chargedPoints) do
        if type(pointIndex) == "number" and pointIndex > 0 then
            chargedComboPointLookup[pointIndex] = true
            hasEntries = true
        end
    end

    return hasEntries and chargedComboPointLookup or nil
end

local function IsDevourerSoulGluttonKnown()
    if not (C_SpellBook and C_SpellBook.IsSpellKnown and CDM_C.DEVOURER_SOUL_GLUTTON_TALENT_SPELL_ID) then
        return false
    end
    return C_SpellBook.IsSpellKnown(CDM_C.DEVOURER_SOUL_GLUTTON_TALENT_SPELL_ID)
end

GetDevourerSoulMax = function()
    if IsDevourerSoulGluttonKnown() then
        return DEVOURER_SOUL_GLUTTON_REDUCED_MAX
    end
    return DEVOURER_BASE_SOULS_MAX
end

local function GetDevourerSoulValueMax()
    local max = GetDevourerSoulMax()
    if not CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID then
        return 0, max, false
    end

    local inVoidMetamorphosis = C_UnitAuras.GetPlayerAuraBySpellID(CDM_C.DEVOURER_VOID_METAMORPHOSIS_SPELL_ID) ~= nil
    local trackedAuraSpellID = inVoidMetamorphosis and CDM_C.DEVOURER_COLLAPSING_STAR_SPELL_ID or CDM_C.DEVOURER_RESOURCE_AURA_SPELL_ID

    local auraData = trackedAuraSpellID and C_UnitAuras.GetPlayerAuraBySpellID(trackedAuraSpellID) or nil
    local current = auraData and auraData.applications or 0
    if current < 0 then
        current = 0
    elseif current > max then
        current = max
    end

    return current, max, inVoidMetamorphosis
end

CDM.GetDevourerSoulValueMax = GetDevourerSoulValueMax

local function RefreshCachedFontStyles()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    CDM_C.RefreshBaseFontCache()
    cachedFontPath = CDM_C.GetBaseFontPath()
    cachedFontOutline = CDM_C.GetBaseFontOutline()
    cachedFontSize = db and db.resourcesBar2TagFontSize or 14
    cachedFontColor = db and db.resourcesBar2TagColor or DEFAULT_WHITE_COLOR
    cachedRuneReadyColor = db and db.resourcesRunesReadyColor or defaults.resourcesRunesReadyColor
    cachedRuneRechargingColor = db and db.resourcesRunesRechargingColor or defaults.resourcesRunesRechargingColor
    cachedEssenceReadyColor = GetPowerColor(POWER_TYPES.Essence)
    cachedEssenceRechargingColor = (db and db.resourcesEssenceRechargingColor)
        or defaults.resourcesEssenceRechargingColor or cachedEssenceReadyColor
    cachedSoulShardReadyColor = GetPowerColor(POWER_TYPES.SoulShards)
    cachedSoulShardRechargingColor = (db and db.resourcesSoulShardsRechargingColor)
        or defaults.resourcesSoulShardsRechargingColor or cachedSoulShardReadyColor
    cachedBar2TagEnabled = CDM.GetTagEnabled and CDM:GetTagEnabled(true) or false
    cachedBar2OffsetX = db and db.resourcesBar2TagOffsetX or 0
    cachedBar2OffsetY = db and db.resourcesBar2TagOffsetY or 0
end

local function GetBarTextures()
    local barName = CDM.db.resourcesBarTexture or CDM.defaults.resourcesBarTexture
    local bgName = CDM.db.resourcesBarBackgroundTexture or CDM.defaults.resourcesBarBackgroundTexture
    return LSM:Fetch("statusbar", barName) or CDM_C.TEX_WHITE8X8,
           LSM:Fetch("statusbar", bgName) or CDM_C.TEX_WHITE8X8
end

local function SetStatusBarTextureIfChanged(statusBar, texturePath)
    if not statusBar or statusBar._cdmStatusBarTexturePath == texturePath then
        return
    end

    statusBar:SetStatusBarTexture(texturePath)
    local statusTexture = statusBar:GetStatusBarTexture()
    if statusTexture then
        statusTexture:SetHorizTile(false)
        statusTexture:SetVertTile(false)
    end
    statusBar._cdmStatusBarTexturePath = texturePath
end

local function SetTextureIfChanged(region, texturePath)
    if not region or region._cdmTexturePath == texturePath then
        return
    end

    region:SetTexture(texturePath)
    region._cdmTexturePath = texturePath
end

local function SetVertexColorIfChanged(region, color)
    if not region or not color then
        return
    end

    local cached = region._cdmVertexColor
    if cached and
        cached.r == color.r and
        cached.g == color.g and
        cached.b == color.b and
        cached.a == color.a then
        return
    end

    if not cached then
        cached = {}
        region._cdmVertexColor = cached
    end
    cached.r = color.r
    cached.g = color.g
    cached.b = color.b
    cached.a = color.a
    region:SetVertexColor(color.r, color.g, color.b, color.a)
end

local function SetStatusBarColorIfChanged(statusBar, color)
    if not statusBar or not color then
        return
    end

    local cached = statusBar._cdmStatusBarColor
    if cached and
        cached.r == color.r and
        cached.g == color.g and
        cached.b == color.b and
        cached.a == color.a then
        return
    end

    if not cached then
        cached = {}
        statusBar._cdmStatusBarColor = cached
    end
    cached.r = color.r
    cached.g = color.g
    cached.b = color.b
    cached.a = color.a
    statusBar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

local function HideFrameList(frameList)
    if not frameList then
        return
    end

    for _, frame in ipairs(frameList) do
        frame:Hide()
    end
end

local SPEC_POWER_MAP = {
    [71] = POWER_TYPES.Rage,                                    -- Arms Warrior
    [72] = POWER_TYPES.Rage,                                    -- Fury Warrior
    [73] = POWER_TYPES.Rage,                                    -- Protection Warrior
    [65] = POWER_TYPES.HolyPower,                               -- Holy Paladin
    [66] = POWER_TYPES.HolyPower,                               -- Protection Paladin
    [70] = POWER_TYPES.HolyPower,                               -- Retribution Paladin
    [253] = POWER_TYPES.Focus,                                  -- Beast Mastery Hunter
    [254] = POWER_TYPES.Focus,                                  -- Marksmanship Hunter
    [255] = POWER_TYPES.Focus,                                  -- Survival Hunter
    [259] = {POWER_TYPES.Energy, POWER_TYPES.ComboPoints},      -- Assassination Rogue
    [260] = {POWER_TYPES.Energy, POWER_TYPES.ComboPoints},      -- Outlaw Rogue
    [261] = {POWER_TYPES.Energy, POWER_TYPES.ComboPoints},      -- Subtlety Rogue
    [258] = POWER_TYPES.Insanity,                               -- Shadow Priest
    [250] = {POWER_TYPES.RunicPower, POWER_TYPES.Runes},        -- Blood Death Knight
    [251] = {POWER_TYPES.RunicPower, POWER_TYPES.Runes},        -- Frost Death Knight
    [252] = {POWER_TYPES.RunicPower, POWER_TYPES.Runes},        -- Unholy Death Knight
    [262] = POWER_TYPES.Maelstrom,                              -- Elemental Shaman
    [263] = {CUSTOM_POWER_TYPES.MaelstromWeapon},               -- Enhancement Shaman
    [62] = POWER_TYPES.ArcaneCharges,                           -- Arcane Mage
    [265] = POWER_TYPES.SoulShards,                             -- Affliction Warlock
    [266] = POWER_TYPES.SoulShards,                             -- Demonology Warlock
    [267] = POWER_TYPES.SoulShards,                             -- Destruction Warlock
    [268] = {POWER_TYPES.Energy, CUSTOM_POWER_TYPES.Stagger},   -- Brewmaster Monk
    [269] = {POWER_TYPES.Energy, POWER_TYPES.Chi},               -- Windwalker Monk
    [102] = POWER_TYPES.LunarPower,                             -- Balance Druid
    [103] = {POWER_TYPES.Energy, POWER_TYPES.ComboPoints},      -- Feral Druid
    [104] = POWER_TYPES.Rage,                                   -- Guardian Druid
    [577] = POWER_TYPES.Fury,                                   -- Havoc Demon Hunter
    [581] = {POWER_TYPES.Fury, CUSTOM_POWER_TYPES.SoulFragments}, -- Vengeance Demon Hunter
    [1480] = {POWER_TYPES.Fury, CUSTOM_POWER_TYPES.DevourerSoulFragments}, -- Devourer Demon Hunter
    [1467] = POWER_TYPES.Essence,                               -- Devastation Evoker
    [1468] = POWER_TYPES.Essence,                               -- Preservation Evoker
    [1473] = POWER_TYPES.Essence,                               -- Augmentation Evoker
}

-- Per-spec mana defaults: true = enabled by default, false = disabled by default
CDM.MANA_SPECS = {
    -- Paladin
    [65] = true,    -- Holy Paladin
    [66] = false,   -- Protection Paladin
    [70] = false,   -- Retribution Paladin
    -- Priest
    [256] = true,   -- Discipline Priest
    [257] = true,   -- Holy Priest
    [258] = true,   -- Shadow Priest
    -- Shaman
    [262] = false,   -- Elemental Shaman
    [263] = false,  -- Enhancement Shaman
    [264] = true,   -- Restoration Shaman
    -- Mage
    [62] = true,    -- Arcane Mage
    [63] = true,    -- Fire Mage
    [64] = true,    -- Frost Mage
    -- Warlock
    [265] = false,   -- Affliction Warlock
    [266] = false,   -- Demonology Warlock
    [267] = false,   -- Destruction Warlock
    -- Druid
    [102] = false,   -- Balance Druid
    [103] = false,  -- Feral Druid
    [104] = false,  -- Guardian Druid
    [105] = true,   -- Restoration Druid
    -- Monk
    [270] = true,   -- Mistweaver Monk
    -- Evoker
    [1467] = false,  -- Devastation Evoker
    [1468] = true,  -- Preservation Evoker
    [1473] = false,  -- Augmentation Evoker
}

CDM.resourceBars = {}
CDM.resourceContainer = nil
CDM.currentPowerTypes = {}
CDM.lastPowerTypeUpdateTimes = {}

local runeDataCache = {}
for i = 1, 6 do
    runeDataCache[i] = {
        runeIndex = i,
        startTime = 0,
        duration = 0,
        isReady = false,
        remaining = 0
    }
end

local runeSortOrder = {1, 2, 3, 4, 5, 6}

local MAX_VISIBLE_RECHARGING = 3

local essenceUpdateTicker
local essenceRechargeStart
local essenceRechargeRate

local function CompareRuneOrder(a, b)
    local runeA = runeDataCache[a]
    local runeB = runeDataCache[b]
    if runeA.isReady and not runeB.isReady then
        return true
    elseif not runeA.isReady and runeB.isReady then
        return false
    end
    return runeA.remaining < runeB.remaining
end

local function CollectRuneData()
    local now = GetTime()
    local hasRecharging = false

    for i = 1, 6 do
        local startTime, duration, runeIsReady = GetRuneCooldown(i)
        local remaining = 0

        if not runeIsReady and startTime and duration and duration > 0 then
            remaining = (startTime + duration) - now
            if remaining < 0 then remaining = 0 end
            hasRecharging = true
        end

        local entry = runeDataCache[i]
        entry.runeIndex = i
        entry.startTime = startTime
        entry.duration = duration
        entry.isReady = runeIsReady
        entry.remaining = remaining
    end

    for i = 1, 6 do
        runeSortOrder[i] = i
    end

    table.sort(runeSortOrder, CompareRuneOrder)

    return hasRecharging
end

local scratchPowerTypes = {}

local function GetPlayerPowerTypes()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        return nil
    end

    local manaEnabled = CDM.GetManaEnabled and CDM:GetManaEnabled() or false

    local _, class = UnitClass("player")
    if class == "DRUID" then
        local currentPowerType = UnitPowerType("player")

        table.wipe(scratchPowerTypes)
        if currentPowerType == POWER_TYPES.Rage then
            scratchPowerTypes[1] = POWER_TYPES.Rage
            return scratchPowerTypes
        elseif currentPowerType == POWER_TYPES.Energy then
            scratchPowerTypes[1] = POWER_TYPES.Energy
            scratchPowerTypes[2] = POWER_TYPES.ComboPoints
            return scratchPowerTypes
        elseif currentPowerType == POWER_TYPES.LunarPower and specID == 102 then
            if manaEnabled then
                scratchPowerTypes[1] = POWER_TYPES.Mana
                scratchPowerTypes[2] = POWER_TYPES.LunarPower
            else
                scratchPowerTypes[1] = POWER_TYPES.LunarPower
            end
            return scratchPowerTypes
        else
            if specID == 102 then
                if manaEnabled then
                    scratchPowerTypes[1] = POWER_TYPES.Mana
                    scratchPowerTypes[2] = POWER_TYPES.LunarPower
                else
                    scratchPowerTypes[1] = POWER_TYPES.LunarPower
                end
                return scratchPowerTypes
            end
            if manaEnabled then
                scratchPowerTypes[1] = POWER_TYPES.Mana
                return scratchPowerTypes
            end
            return nil
        end
    end

    local specPowers = SPEC_POWER_MAP[specID]

    if manaEnabled then
        table.wipe(scratchPowerTypes)
        scratchPowerTypes[1] = POWER_TYPES.Mana
        if specPowers then
            if type(specPowers) == "table" then
                for _, pt in ipairs(specPowers) do
                    scratchPowerTypes[#scratchPowerTypes + 1] = pt
                end
            else
                scratchPowerTypes[#scratchPowerTypes + 1] = specPowers
            end
        end
        return scratchPowerTypes
    end

    if not specPowers then
        return nil
    end

    if type(specPowers) ~= "table" then
        table.wipe(scratchPowerTypes)
        scratchPowerTypes[1] = specPowers
        return scratchPowerTypes
    end
    table.wipe(scratchPowerTypes)
    for i, pt in ipairs(specPowers) do
        scratchPowerTypes[i] = pt
    end
    return scratchPowerTypes
end

local function UsesPips(powerType)
    return (
        powerType == POWER_TYPES.ComboPoints or
        powerType == POWER_TYPES.Runes or
        powerType == POWER_TYPES.SoulShards or
        powerType == POWER_TYPES.HolyPower or
        powerType == POWER_TYPES.Chi or
        powerType == POWER_TYPES.ArcaneCharges or
        powerType == POWER_TYPES.Essence or
        powerType == CUSTOM_POWER_TYPES.SoulFragments or
        powerType == CUSTOM_POWER_TYPES.MaelstromWeapon or
        powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments
    )
end

local function CreatePipBar(powerType)
    if CDM.resourceBars[powerType] then
        return CDM.resourceBars[powerType]
    end

    local bar = CreateFrame("StatusBar", nil, CDM.resourceContainer)
    bar:SetFrameStrata(CDM_C.STRATA_MAIN)
    bar.powerType = powerType
    bar.isPipBar = true
    bar.pips = {}

    bar.color = GetPowerColor(powerType) or DEFAULT_WHITE_COLOR

    bar:Hide()

    CDM.resourceBars[powerType] = bar

    if CDM.TAGS and powerType ~= POWER_TYPES.Runes then
        CDM.TAGS:CreateTag(bar, powerType)
    end

    return bar
end

local function CreatePips(bar, maxPips, barWidth, barHeight)
    bar.pips = bar.pips or {}
    bar.separators = bar.separators or {}
    bar.pipPositions = bar.pipPositions or {}
    bar.pipBoundaryPixels = bar.pipBoundaryPixels or {}

    local color = bar.color

    local borderColor = (CDM.db and CDM.db.borderColor) or (CDM.defaults and CDM.defaults.borderColor) or DEFAULT_WHITE_COLOR

    local bgColor = CDM.db.resourcesBackgroundColor or CDM.defaults.resourcesBackgroundColor

    if maxPips <= 0 then return end
    local _, barPixels, onePixel = SnapWidthToPixelGrid(bar, barWidth)

    local separatorWidth = onePixel
    local availablePixels = barPixels - (maxPips - 1)

    bar.pipWidths = bar.pipWidths or {}
    local pipWidths = bar.pipWidths
    local pipBoundaryPixels = bar.pipBoundaryPixels
    local prevBoundary = 0
    for i = 1, maxPips do
        local boundary = math_floor(i * availablePixels / maxPips)
        pipWidths[i] = (boundary - prevBoundary) * onePixel
        bar.pipPositions[i] = (prevBoundary + (i - 1)) * onePixel
        pipBoundaryPixels[i] = boundary + (i - 1)
        prevBoundary = boundary
    end

    local barTexturePath, bgTexturePath = GetBarTextures()

    local isRuneBar = (bar.powerType == POWER_TYPES.Runes)
    local isEssenceBar = (bar.powerType == POWER_TYPES.Essence)
    local isSoulShardBar = (bar.powerType == POWER_TYPES.SoulShards)
    local isRogueComboPoints = IsRogueComboPoints(bar.powerType)

    if not bar.bgTexture then
        bar.bgTexture = bar:CreateTexture(nil, "BACKGROUND")
    end
    bar.bgTexture:SetTexture(bgTexturePath)
    bar.bgTexture:SetHorizTile(false)
    bar.bgTexture:SetVertTile(false)
    bar.bgTexture:SetAllPoints(bar)
    bar.bgTexture:SetSnapToPixelGrid(false)
    bar.bgTexture:SetTexelSnappingBias(0)
    bar.bgTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    bar.bgTexture:Show()

    if not bar.separatorFill then
        bar.separatorFill = bar:CreateTexture(nil, "ARTWORK", nil, -1)
        bar.separatorFill:SetTexture(CDM_C.TEX_WHITE8X8)
        ConfigurePixelTexture(bar.separatorFill)
        bar.separatorFill:SetAllPoints(bar)
    end
    bar.separatorFill:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    bar.separatorFill:Show()

    if isRuneBar then
        for i = 1, maxPips do
            local pip = bar.pips[i]

            if not pip then
                pip = CreateFrame("StatusBar", nil, bar)
                pip:SetMinMaxValues(0, 1)
                pip:SetValue(0)
                bar.pips[i] = pip

                local timerFrame = CreateFrame("Frame", nil, pip)
                timerFrame:SetAllPoints(pip)
                timerFrame:SetFrameLevel(pip:GetFrameLevel() + 10)
                local timerText = timerFrame:CreateFontString(nil, "OVERLAY")
                timerText:SetDrawLayer("OVERLAY", 7)
                timerText:SetJustifyH("CENTER")
                timerText:SetJustifyV("MIDDLE")
                timerText:SetIgnoreParentScale(true)
                timerText:SetFont(CDM_C.FONT_PATH, CDM_C.GetPixelFontSize(10), CDM_C.FONT_OUTLINE)
                pip.timerText = timerText
                pip.timerFrame = timerFrame
            end

            pip:SetParent(bar)

            pip:SetStatusBarTexture(barTexturePath)
            pip:GetStatusBarTexture():SetHorizTile(false)
            pip:GetStatusBarTexture():SetVertTile(false)
            pip:SetStatusBarColor(color.r, color.g, color.b, color.a)

            if pip.timerText then
                pip.timerText:ClearAllPoints()
                pip.timerText:SetPoint("CENTER", pip.timerFrame, "CENTER", cachedBar2OffsetX, cachedBar2OffsetY)
            end

            local xStart = bar.pipPositions[i]
            local xEnd = xStart + pipWidths[i]
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", bar, "TOPLEFT", xStart, 0)
            pip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", xEnd, 0)
            pip:Show()
        end

        bar.hasRunesRecharging = false
    elseif isEssenceBar or isSoulShardBar then
        for i = 1, maxPips do
            local pip = bar.pips[i]

            if not pip then
                pip = CreateFrame("StatusBar", nil, bar)
                pip:SetMinMaxValues(0, 1)
                pip:SetValue(0)
                bar.pips[i] = pip
            end

            pip:SetParent(bar)

            pip:SetStatusBarTexture(barTexturePath)
            pip:GetStatusBarTexture():SetHorizTile(false)
            pip:GetStatusBarTexture():SetVertTile(false)
            pip:SetStatusBarColor(color.r, color.g, color.b, color.a)

            local xStart = bar.pipPositions[i]
            local xEnd = xStart + pipWidths[i]
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", bar, "TOPLEFT", xStart, 0)
            pip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", xEnd, 0)
            pip:Show()
        end

        if isEssenceBar then
            bar.hasEssenceRecharging = false
            bar._essencePrevCurrent = nil
            essenceRechargeStart = nil
            essenceRechargeRate = nil
        end
    else
        if isRogueComboPoints then
            bar.comboChargeEmptyOverlays = bar.comboChargeEmptyOverlays or {}
        end

        for i = 1, maxPips do
            local pip = bar.pips[i]

            if not pip or not pip.SetMinMaxValues then
                if pip then pip:Hide() end
                pip = CreateFrame("StatusBar", nil, bar)
                bar.pips[i] = pip
            end

            pip:SetParent(bar)
            pip:SetMinMaxValues(i - 1, i)
            pip:SetValue(0)

            pip:SetStatusBarTexture(barTexturePath)
            pip:GetStatusBarTexture():SetHorizTile(false)
            pip:GetStatusBarTexture():SetVertTile(false)
            pip:SetStatusBarColor(color.r, color.g, color.b, color.a)

            local xStart = bar.pipPositions[i]
            local xEnd = xStart + pipWidths[i]
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", bar, "TOPLEFT", xStart, 0)
            pip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", xEnd, 0)
            pip:Show()

            if isRogueComboPoints then
                local overlay = bar.comboChargeEmptyOverlays[i]
                if not overlay then
                    overlay = pip:CreateTexture(nil, "ARTWORK", nil, 1)
                    bar.comboChargeEmptyOverlays[i] = overlay
                    ConfigurePixelTexture(overlay)
                end
                overlay:SetParent(pip)
                overlay:SetAllPoints(pip)
                overlay:SetTexture(barTexturePath)
                overlay:Hide()
            end
        end
    end

    bar.pipWidth = pipWidths[1]
    bar.activePipCount = maxPips
    bar._barWidth = barWidth

    for i = maxPips + 1, #bar.pips do
        bar.pips[i]:Hide()
    end
    if bar.comboChargeEmptyOverlays then
        for i = maxPips + 1, #bar.comboChargeEmptyOverlays do
            bar.comboChargeEmptyOverlays[i]:Hide()
        end
        if not isRogueComboPoints then
            for _, overlay in ipairs(bar.comboChargeEmptyOverlays) do
                overlay:Hide()
            end
        end
    end

    if not bar.separatorOverlay then
        bar.separatorOverlay = CreateFrame("Frame", nil, bar)
        bar.separatorOverlay:SetAllPoints()
    end
    bar.separatorOverlay:SetFrameLevel(bar:GetFrameLevel() + 5)

    for i = 1, maxPips - 1 do
        local separator = bar.separators[i]

        if not separator then
            separator = bar.separatorOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
            separator:SetTexture(CDM_C.TEX_WHITE8X8)
            separator:SetDrawLayer("OVERLAY", 7)
            separator:SetSnapToPixelGrid(false)
            separator:SetTexelSnappingBias(0)
            bar.separators[i] = separator
        end

        separator:SetSize(separatorWidth, barHeight)
        separator:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)

        local sepPixel = pipBoundaryPixels[i]
        local sepXOffset = (sepPixel and (sepPixel * onePixel)) or (bar.pipPositions[i] + pipWidths[i])
        separator:ClearAllPoints()
        separator:SetPoint("LEFT", bar, "LEFT", sepXOffset, 0)
        separator:Show()
    end

    for i = maxPips, #bar.separators do
        bar.separators[i]:Hide()
    end
end

local function CreateBar(powerType)
    if UsesPips(powerType) then
        return CreatePipBar(powerType)
    end

    if CDM.resourceBars[powerType] then
        return CDM.resourceBars[powerType]
    end

    local bar = CreateFrame("StatusBar", nil, CDM.resourceContainer)
    bar:SetFrameStrata(CDM_C.STRATA_MAIN)

    local barTexturePath, bgTexturePath = GetBarTextures()
    bar:SetStatusBarTexture(barTexturePath)

    local statusBarTexture = bar:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:SetHorizTile(false)
        statusBarTexture:SetVertTile(false)
    end

    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar.powerType = powerType

    local color = GetPowerColor(powerType)
    if not color and powerType == CUSTOM_POWER_TYPES.Stagger then
        color = CDM.db.resourcesStaggerLightColor or CDM.defaults.resourcesStaggerLightColor
    end
    if color then
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
    end

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(bgTexturePath)
    bg:SetHorizTile(false)
    bg:SetVertTile(false)
    bg:SetAllPoints()
    bg:SetSnapToPixelGrid(false)
    bg:SetTexelSnappingBias(0)
    local bgColor = CDM.db.resourcesBackgroundColor or CDM.defaults.resourcesBackgroundColor
    bg:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    bar.bg = bg

    local isPrimaryResource = (
        powerType == POWER_TYPES.Rage or
        powerType == POWER_TYPES.Energy or
        powerType == POWER_TYPES.Focus or
        powerType == POWER_TYPES.RunicPower or
        powerType == POWER_TYPES.LunarPower or
        powerType == POWER_TYPES.Maelstrom or
        powerType == POWER_TYPES.Insanity or
        powerType == POWER_TYPES.Fury or
        powerType == POWER_TYPES.Mana or
        powerType == CUSTOM_POWER_TYPES.Stagger
    )

    if isPrimaryResource then
        bar.isPrimaryResource = true
    end

    if not CDM.db.resourcesUnifiedBorder then
        if not bar.borderFrame then
            bar.borderFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
            bar.borderFrame:SetAllPoints()
        end

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(bar.borderFrame)
        end
    else
        if bar.borderFrame then
            bar.borderFrame:Hide()
        end
    end

    bar:Hide()

    CDM.resourceBars[powerType] = bar

    if CDM.TAGS and not bar.isPipBar then
        CDM.TAGS:CreateTag(bar, powerType)
    end

    return bar
end

local function CreateVerticalSeparators(bar2)
    CDM.resourceContainer.verticalSeparators = CDM.resourceContainer.verticalSeparators or {}

    if not bar2 or not bar2.isPipBar or not bar2.pipPositions then
        HideFrameList(CDM.resourceContainer.verticalSeparators)
        return
    end

    HideFrameList(bar2.separators)

    local borderColor = CDM.db.borderColor or CDM.defaults.borderColor or DEFAULT_WHITE_COLOR
    local maxPips = #bar2.pips
    local pipWidths = bar2.pipWidths
    local fallbackPipWidth = bar2.pipWidth or (bar2.pips[1] and bar2.pips[1]:GetWidth() or 0)

    local twoPixels = GetOnePixelSize(bar2) * 2

    local separatorWidth = 16
    local separatorHeight = 10

    local visiblePips = 0
    for i = 1, maxPips do
        if bar2.pips[i] and bar2.pips[i]:IsShown() then
            visiblePips = visiblePips + 1
        end
    end

    for i = 1, visiblePips - 1 do
        local separator = CDM.resourceContainer.verticalSeparators[i]

        if not separator then
            separator = CreateFrame("Frame", nil, bar2)
            separator:SetFrameStrata(CDM_C.STRATA_MAIN)

            local tex = separator:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetTexture("Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\vSeparator")
            tex:SetAllPoints()
            ConfigurePixelTexture(tex)
            separator.texture = tex

            CDM.resourceContainer.verticalSeparators[i] = separator
        end

        separator:SetParent(bar2)
        separator:SetFrameLevel(bar2:GetFrameLevel() + 1)
        separator:SetSize(separatorWidth, separatorHeight)
        separator.texture:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)

        local pw = (pipWidths and pipWidths[i]) or fallbackPipWidth
        local boundary = bar2.pipPositions[i] + pw
        local xOffset = SnapToPixel(math_floor((boundary - 2) / twoPixels + 0.5) * twoPixels, bar2)

        separator:ClearAllPoints()
        separator:SetPoint("BOTTOMLEFT", bar2, "BOTTOMLEFT", xOffset, -1)
        separator:SetPoint("TOPLEFT", bar2, "TOPLEFT", xOffset, 0)
        separator:Show()
    end

    if visiblePips < 1 then
        HideFrameList(CDM.resourceContainer.verticalSeparators)
        return
    end

    for i = visiblePips, #CDM.resourceContainer.verticalSeparators do
        CDM.resourceContainer.verticalSeparators[i]:Hide()
    end
end

local function UpdateBorders(powerTypes)
    if not powerTypes or #powerTypes == 0 then
        return
    end

    local useUnified = CDM.db.resourcesUnifiedBorder
    local borderColor = CDM.db.borderColor or CDM.defaults.borderColor or DEFAULT_WHITE_COLOR

    for _, powerType in ipairs(powerTypes) do
        local bar = CDM.resourceBars[powerType]
        if bar then
            if useUnified then
                if bar.borderFrame then
                    bar.borderFrame:Hide()
                end
            else
                if not bar.borderFrame then
                    bar.borderFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
                    bar.borderFrame:SetAllPoints()

                    if CDM.BORDER and CDM.BORDER.CreateBorder then
                        CDM.BORDER:CreateBorder(bar.borderFrame)
                    end
                else
                    bar.borderFrame:Show()
                end
            end
        end
    end

    if useUnified then
        if not CDM.resourceContainer.unifiedBorderFrame then
            CDM.resourceContainer.unifiedBorderFrame = CreateFrame("Frame", nil, CDM.resourceContainer, "BackdropTemplate")
            CDM.resourceContainer.unifiedBorderFrame:SetAllPoints()

            if CDM.BORDER and CDM.BORDER.CreateBorder then
                CDM.BORDER:CreateBorder(CDM.resourceContainer.unifiedBorderFrame)
            end
        else
            CDM.resourceContainer.unifiedBorderFrame:Show()
        end

        UpdateUnifiedBorderFrameGeometry(powerTypes)

        if #powerTypes > 1 then
            if not CDM.resourceContainer.separator then
                local separator = CreateFrame("Frame", nil, CDM.resourceContainer)
                separator:SetIgnoreParentAlpha(true)

                local tex = separator:CreateTexture(nil, "ARTWORK")
                tex:SetTexture("Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Separator")
                tex:SetSnapToPixelGrid(false)
                tex:SetTexelSnappingBias(0)
                tex:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
                separator.texture = tex

                CDM.resourceContainer.separator = separator
            end

            local bar1 = CDM.resourceBars[powerTypes[1]]
            local bar2 = CDM.resourceBars[powerTypes[2]]
            if bar1 and bar2 then
                local separator = CDM.resourceContainer.separator

                separator:ClearAllPoints()
                separator:SetHeight(16)
                local tex = separator.texture
                tex:ClearAllPoints()
                tex:SetTexCoord(0, 1, 0, 1)
                tex:SetAllPoints()

                separator:SetPoint("TOPRIGHT", bar1, "TOPRIGHT", 0, 4)
                separator:SetPoint("LEFT", bar1, "LEFT", 0, 0)
                separator:Show()

                if bar2.isPipBar then
                    CreateVerticalSeparators(bar2)
                end
            end
        else
            if CDM.resourceContainer.separator then
                CDM.resourceContainer.separator:Hide()
            end

            local singleBar = CDM.resourceBars[powerTypes[1]]
            if singleBar and singleBar.isPipBar then
                CreateVerticalSeparators(singleBar)
            else
                HideFrameList(CDM.resourceContainer.verticalSeparators)
            end
        end

        if CDM.resourceContainer.separator and CDM.resourceContainer.separator.texture then
            CDM.resourceContainer.separator.texture:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        end

        if CDM.resourceContainer.verticalSeparators then
            for _, sep in ipairs(CDM.resourceContainer.verticalSeparators) do
                if sep:IsShown() and sep.texture then
                    sep.texture:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
                end
            end
        end

        for _, powerType in ipairs(powerTypes) do
            local bar = CDM.resourceBars[powerType]
            HidePipBarDecorations(bar)
        end
    else
        if CDM.resourceContainer.unifiedBorderFrame then
            CDM.resourceContainer.unifiedBorderFrame:Hide()
        end
        if CDM.resourceContainer.separator then
            CDM.resourceContainer.separator:Hide()
        end
        HideFrameList(CDM.resourceContainer.verticalSeparators)

        for _, powerType in ipairs(powerTypes) do
            local bar = CDM.resourceBars[powerType]
            if IsPipSeparatorBar(bar) then
                HideBarSeparatorFill(bar)

                local activeSeps = math.max(0, (bar.activePipCount or 0) - 1)
                local barLeft = bar.GetLeft and bar:GetLeft() or nil
                local onePixel = GetOnePixelSize(bar)
                local barHeight = bar.GetHeight and bar:GetHeight() or nil
                for i = 1, activeSeps do
                    local sep = bar.separators[i]
                    if sep then
                        sep:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)

                        if onePixel and onePixel > 0 and barHeight and barHeight > 0 then
                            sep:SetSize(onePixel, barHeight)
                        end

                        local xOffset = ResolvePipSeparatorXOffset(bar, i, barLeft, onePixel)
                        SetPipSeparatorVerticalLine(sep, bar, xOffset)

                        sep:Show()
                    end
                end
                HideBarPipSeparators(bar, activeSeps + 1)
            end
        end
    end
end

local function UpdateContainerPosition()
    if not CDM.resourceContainer then
        return
    end

    local offsetX = CDM.db.resourcesOffsetX or 0
    local offsetY = CDM.db.resourcesOffsetY or -200

    CDM.resourceContainer:ClearAllPoints()
    SetPixelPerfectPoint(CDM.resourceContainer, "BOTTOM", UIParent, "CENTER", offsetX, offsetY)
end

local runeUpdateTicker = nil

local runePowerUpdatePending = false

local staggerUpdateTicker = nil

local function ApplyRuneStates(bar, readyColor, rechargingColor, textEnabled)
    local hasRecharging = CollectRuneData()

    local rechargingShown = 0
    for i, pip in ipairs(bar.pips) do
        local runeIndex = runeSortOrder[i]
        local rune = runeDataCache[runeIndex]
        if not rune then
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            if pip.timerText then
                pip.timerText:Hide()
            end
        elseif rune.isReady then
            pip:SetValue(1, Enum.StatusBarInterpolation.Immediate)
            pip.runeInitialRemaining = nil
            pip.lastRuneIndex = nil
            pip:SetStatusBarColor(readyColor.r, readyColor.g, readyColor.b, readyColor.a)
            if pip.timerText then
                pip.timerText:Hide()
            end
        elseif rune.startTime and rune.duration and rune.duration > 0 then
            rechargingShown = rechargingShown + 1
            if rechargingShown <= MAX_VISIBLE_RECHARGING then
                if pip.lastRuneIndex ~= runeIndex then
                    pip.lastRuneIndex = runeIndex
                    pip.runeInitialRemaining = rune.remaining
                elseif not pip.runeInitialRemaining or rune.remaining > pip.runeInitialRemaining then
                    pip.runeInitialRemaining = rune.remaining
                end

                local progress = 0
                if pip.runeInitialRemaining and pip.runeInitialRemaining > 0 then
                    progress = 1 - (rune.remaining / pip.runeInitialRemaining)
                end

                if progress < 0 then progress = 0 end
                if progress > 1 then progress = 1 end

                pip:SetValue(progress, Enum.StatusBarInterpolation.Immediate)
                pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)

                if pip.timerText and textEnabled then
                    if rune.remaining > 0 then
                        local displayValue = math_floor(rune.remaining)
                        if pip._lastDisplayValue ~= displayValue then
                            pip._lastDisplayValue = displayValue
                            pip.timerText:SetFormattedText("%d", displayValue)
                        end
                        pip.timerText:Show()
                    else
                        if pip._lastDisplayValue ~= 0 then
                            pip._lastDisplayValue = 0
                        end
                        pip.timerText:Hide()
                    end
                end
            else
                pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
                pip.runeInitialRemaining = nil
                pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)
                if pip.timerText then
                    pip.timerText:Hide()
                end
            end
        else
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            if pip.timerText then
                pip.timerText:Hide()
            end
        end
    end

    return hasRecharging
end

local function UpdateRuneProgress(bar)
    if not bar or not bar:IsShown() or not bar.hasRunesRecharging then
        if runeUpdateTicker then
            runeUpdateTicker:Cancel()
            runeUpdateTicker = nil
            if bar then bar.hasRunesRecharging = false end
        end
        return
    end

    if not cachedRuneReadyColor then
        RefreshCachedFontStyles()
    end

    ApplyRuneStates(bar, cachedRuneReadyColor, cachedRuneRechargingColor, cachedBar2TagEnabled)
end

local function UpdateRuneCooldowns(bar)
    if not bar or not bar.pips or bar.powerType ~= POWER_TYPES.Runes or not bar:IsShown() then
        return
    end

    if not cachedFontPath or not cachedRuneReadyColor then
        RefreshCachedFontStyles()
    end

    local textEnabled = cachedBar2TagEnabled

    if textEnabled then
        local pixelSize = CDM_C.GetPixelFontSize(cachedFontSize)
        local cachedColor = bar._lastRuneFontColor
        local colorChanged = (not cachedColor) or
            cachedColor.r ~= cachedFontColor.r or
            cachedColor.g ~= cachedFontColor.g or
            cachedColor.b ~= cachedFontColor.b or
            cachedColor.a ~= cachedFontColor.a

        local styleChanged = colorChanged or
            bar._lastRuneFontPath ~= cachedFontPath or
            bar._lastRuneFontSize ~= pixelSize or
            bar._lastRuneFontOutline ~= cachedFontOutline or
            bar._lastRuneOffsetX ~= cachedBar2OffsetX or
            bar._lastRuneOffsetY ~= cachedBar2OffsetY

        if styleChanged then
            for _, pip in ipairs(bar.pips) do
                if pip.timerText then
                    pip.timerText:SetIgnoreParentScale(true)
                    pip.timerText:SetFont(cachedFontPath, pixelSize, cachedFontOutline)
                    pip.timerText:SetTextColor(cachedFontColor.r, cachedFontColor.g, cachedFontColor.b, cachedFontColor.a)
                    pip.timerText:ClearAllPoints()
                    pip.timerText:SetPoint("CENTER", pip.timerFrame, "CENTER", cachedBar2OffsetX, cachedBar2OffsetY)
                end
            end

            bar._lastRuneFontPath = cachedFontPath
            bar._lastRuneFontSize = pixelSize
            bar._lastRuneFontOutline = cachedFontOutline
            bar._lastRuneOffsetX = cachedBar2OffsetX
            bar._lastRuneOffsetY = cachedBar2OffsetY
            cachedColor = cachedColor or {}
            cachedColor.r = cachedFontColor.r
            cachedColor.g = cachedFontColor.g
            cachedColor.b = cachedFontColor.b
            cachedColor.a = cachedFontColor.a
            bar._lastRuneFontColor = cachedColor
        end
    end

    local hasRecharging = ApplyRuneStates(bar, cachedRuneReadyColor, cachedRuneRechargingColor, textEnabled)

    if hasRecharging and not runeUpdateTicker then
        runeUpdateTicker = C_Timer.NewTicker(0.05, function()
            UpdateRuneProgress(bar)
        end)
        bar.hasRunesRecharging = true
    elseif not hasRecharging and runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
        bar.hasRunesRecharging = false
    end
end

local function ApplyEssenceStates(bar, current, max, readyColor, rechargingColor)
    for i, pip in ipairs(bar.pips) do
        if not pip:IsShown() then break end
        if i <= current then
            pip:SetValue(1, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(readyColor.r, readyColor.g, readyColor.b, readyColor.a)
        elseif i == current + 1 and essenceRechargeStart and essenceRechargeRate and essenceRechargeRate > 0 then
            local elapsed = GetTime() - essenceRechargeStart
            local rechargeTime = 1 / essenceRechargeRate
            local progress = elapsed / rechargeTime
            if progress < 0 then progress = 0 end
            if progress > 1 then progress = 1 end
            pip:SetValue(progress, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)
        else
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)
        end
    end
end

local function UpdateEssenceCooldowns(bar)
    if not bar or not bar.pips or bar.powerType ~= POWER_TYPES.Essence or not bar:IsShown() then
        if essenceUpdateTicker then
            essenceUpdateTicker:Cancel()
            essenceUpdateTicker = nil
        end
        if bar then bar.hasEssenceRecharging = false end
        return
    end

    local readyColor = cachedEssenceReadyColor or GetPowerColor(POWER_TYPES.Essence)
    local rechargingColor = cachedEssenceRechargingColor or readyColor

    local current = UnitPower("player", POWER_TYPES.Essence)
    local max = UnitPowerMax("player", POWER_TYPES.Essence)

    local rate = GetPowerRegenForPowerType(POWER_TYPES.Essence)
    essenceRechargeRate = rate

    if bar._essencePrevCurrent ~= current then
        bar._essencePrevCurrent = current
        if current < max then
            essenceRechargeStart = GetTime()
        else
            essenceRechargeStart = nil
        end
        if CDM.TAGS and CDM.TAGS.textFrames[POWER_TYPES.Essence] then
            CDM.TAGS:UpdateTagText(CDM.TAGS.textFrames[POWER_TYPES.Essence])
        end
    end

    local hasRecharging = (current < max)
    ApplyEssenceStates(bar, current, max, readyColor, rechargingColor)

    if hasRecharging and not essenceUpdateTicker then
        essenceUpdateTicker = C_Timer.NewTicker(0.05, function()
            UpdateEssenceCooldowns(bar)
        end)
        bar.hasEssenceRecharging = true
    elseif not hasRecharging and essenceUpdateTicker then
        essenceUpdateTicker:Cancel()
        essenceUpdateTicker = nil
        bar.hasEssenceRecharging = false
    end
end

local function ApplySoulShardStates(bar)
    local rawPower = UnitPower("player", POWER_TYPES.SoulShards, true) or 0
    local isRawSecret = type(rawPower) == "number" and issecretvalue(rawPower)
    local specID = (CDM.GetCurrentSpecID and CDM:GetCurrentSpecID()) or currentSpecID
    local wholePart, fractionalPart

    if isRawSecret then
        wholePart = UnitPower("player", POWER_TYPES.SoulShards) or 0
        fractionalPart = 0
    elseif specID == 267 then
        wholePart = math_floor(rawPower / 10)
        fractionalPart = (rawPower % 10) / 10
    else
        wholePart = UnitPower("player", POWER_TYPES.SoulShards) or 0
        fractionalPart = 0
    end

    local readyColor = cachedSoulShardReadyColor or GetPowerColor(POWER_TYPES.SoulShards)
    local rechargingColor = cachedSoulShardRechargingColor or readyColor

    for i, pip in ipairs(bar.pips) do
        if not pip:IsShown() then break end
        if i <= wholePart then
            pip:SetValue(1, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(readyColor.r, readyColor.g, readyColor.b, readyColor.a)
        elseif i == wholePart + 1 and fractionalPart > 0 then
            pip:SetValue(fractionalPart, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)
        else
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            pip:SetStatusBarColor(rechargingColor.r, rechargingColor.g, rechargingColor.b, rechargingColor.a)
        end
    end

    bar.soulShardRawPower = rawPower
end

local StartStaggerTicker, StopStaggerTicker

local function UpdateStaggerBar()
    local bar = CDM.resourceBars[CUSTOM_POWER_TYPES.Stagger]
    if not bar or not bar:IsShown() then
        return
    end

    local stagger = UnitStagger("player")
    local maxHealth = UnitHealthMax("player")

    if not stagger or not maxHealth or maxHealth == 0 then
        return
    end

    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)

    local pct = 0
    local isStaggerSecret = (type(stagger) == "number" and issecretvalue(stagger)) or
                            (type(maxHealth) == "number" and issecretvalue(maxHealth))
    if not isStaggerSecret and type(stagger) == "number" and type(maxHealth) == "number" then
        pct = stagger / maxHealth
    end

    local colorTier = 0
    if pct >= 0.6 then
        colorTier = 2
    elseif pct >= 0.3 then
        colorTier = 1
    end

    if bar._lastColorTier ~= colorTier then
        bar._lastColorTier = colorTier
        local color
        if colorTier == 2 then
            color = CDM.db.resourcesStaggerHeavyColor or CDM.defaults.resourcesStaggerHeavyColor
        elseif colorTier == 1 then
            color = CDM.db.resourcesStaggerModerateColor or CDM.defaults.resourcesStaggerModerateColor
        else
            color = CDM.db.resourcesStaggerLightColor or CDM.defaults.resourcesStaggerLightColor
        end
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
    end

    bar.staggerPercent = pct * 100

    if CDM.TAGS and CDM.TAGS.textFrames[CUSTOM_POWER_TYPES.Stagger] then
        CDM.TAGS:UpdateTagText(CDM.TAGS.textFrames[CUSTOM_POWER_TYPES.Stagger])
    end

    if not isStaggerSecret and type(stagger) == "number" and stagger == 0 and not InCombatLockdown() and staggerUpdateTicker then
        StopStaggerTicker()
    end
end

StartStaggerTicker = function()
    if staggerUpdateTicker then
        return
    end

    staggerUpdateTicker = C_Timer.NewTicker(0.05, function()
        UpdateStaggerBar()
    end)
end

StopStaggerTicker = function()
    if staggerUpdateTicker then
        staggerUpdateTicker:Cancel()
        staggerUpdateTicker = nil
    end
end

local function UpdateTagTextForPowerType(powerType)
    if CDM.TAGS and CDM.TAGS.textFrames[powerType] then
        CDM.TAGS:UpdateTagText(CDM.TAGS.textFrames[powerType])
    end
end

local maelstromWatchTicker

local function StopMaelstromWatch()
    if maelstromWatchTicker then
        maelstromWatchTicker:Cancel()
        maelstromWatchTicker = nil
    end
end

local function UpdateBarValue(powerType)
    local bar = CDM.resourceBars[powerType]
    if not bar or not bar:IsShown() then
        return
    end

    local current, max

    if powerType == CUSTOM_POWER_TYPES.SoulFragments then
        current = C_Spell.GetSpellCastCount(CDM_C.SOUL_CLEAVE_SPELL_ID) or 0
        max = MAX_SOUL_FRAGMENTS
    elseif powerType == CUSTOM_POWER_TYPES.MaelstromWeapon then
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(CDM_C.MAELSTROM_WEAPON_SPELL_ID)
        current = auraData and auraData.applications or 0
        max = MAX_MAELSTROM_WEAPON
        if current > 0 and not maelstromWatchTicker then
            maelstromWatchTicker = C_Timer.NewTicker(0.25, function()
                local ad = C_UnitAuras.GetPlayerAuraBySpellID(CDM_C.MAELSTROM_WEAPON_SPELL_ID)
                if not ad or (ad.applications or 0) == 0 then
                    StopMaelstromWatch()
                    UpdateBarValue(CUSTOM_POWER_TYPES.MaelstromWeapon)
                end
            end)
        elseif current <= 0 then
            StopMaelstromWatch()
        end
    elseif powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments then
        current, max = GetDevourerSoulValueMax()
        current = current / DEVOURER_STACKS_PER_PIP
        max = max / DEVOURER_STACKS_PER_PIP
    elseif powerType == CUSTOM_POWER_TYPES.Stagger then
        UpdateStaggerBar()
        return
    else
        current = UnitPower("player", powerType)
        max = UnitPowerMax("player", powerType)
    end

    if bar.isPipBar then
        if powerType == POWER_TYPES.Runes then
            UpdateRuneCooldowns(bar)
            return
        elseif powerType == POWER_TYPES.Essence then
            UpdateEssenceCooldowns(bar)
            UpdateTagTextForPowerType(powerType)
            return
        elseif powerType == POWER_TYPES.SoulShards then
            ApplySoulShardStates(bar)
            UpdateTagTextForPowerType(powerType)
            return
        end
        local isRogueComboPoints = IsRogueComboPoints(powerType)
        local chargedLookup
        local chargedFilledColor
        local chargedEmptyColor
        if isRogueComboPoints then
            chargedLookup = GetChargedComboPointLookup()
            chargedFilledColor, chargedEmptyColor = GetComboPointChargeColors()
        end

        for i, pip in ipairs(bar.pips) do
            pip:SetValue(current, Enum.StatusBarInterpolation.Immediate)

            if isRogueComboPoints then
                local isCharged = chargedLookup and chargedLookup[i]
                if isCharged and i <= current then
                    SetStatusBarColorIfChanged(pip, chargedFilledColor)
                else
                    SetStatusBarColorIfChanged(pip, bar.color)
                end

                local overlay = bar.comboChargeEmptyOverlays and bar.comboChargeEmptyOverlays[i]
                if overlay then
                    if isCharged and i > current then
                        SetVertexColorIfChanged(overlay, chargedEmptyColor)
                        overlay:Show()
                    else
                        overlay:Hide()
                    end
                end
            end
        end

        if isRogueComboPoints and bar.comboChargeEmptyOverlays then
            for i = (#bar.pips + 1), #bar.comboChargeEmptyOverlays do
                bar.comboChargeEmptyOverlays[i]:Hide()
            end
        end
    else
        bar:SetMinMaxValues(0, max)
        if bar.isPrimaryResource then
            bar:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
        else
            bar:SetValue(current, Enum.StatusBarInterpolation.Immediate)
        end

    end

    UpdateTagTextForPowerType(powerType)
end

local function GetPipBarMax(powerType)
    if powerType == CUSTOM_POWER_TYPES.SoulFragments then
        return MAX_SOUL_FRAGMENTS
    end
    if powerType == CUSTOM_POWER_TYPES.MaelstromWeapon then
        return MAX_MAELSTROM_WEAPON
    end
    if powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments then
        return GetDevourerSoulMax() / DEVOURER_STACKS_PER_PIP
    end
    return UnitPowerMax("player", powerType)
end

local function ApplyBarBackground(bar, bgTexturePath, bgColor)
    if not bar or not bar.bgTexture then
        return
    end
    SetTextureIfChanged(bar.bgTexture, bgTexturePath)
    SetVertexColorIfChanged(bar.bgTexture, bgColor)
end

local function ApplyPipTexturesIfChanged(bar, barTexturePath)
    if bar._lastPipTexturePath == barTexturePath then
        return
    end

    for _, pip in ipairs(bar.pips) do
        SetStatusBarTextureIfChanged(pip, barTexturePath)
    end
    if bar.comboChargeEmptyOverlays then
        for _, overlay in ipairs(bar.comboChargeEmptyOverlays) do
            SetTextureIfChanged(overlay, barTexturePath)
        end
    end
    bar._lastPipTexturePath = barTexturePath
end

local function UpdatePipBarVisuals(bar, powerType, barTexturePath, bgTexturePath, bgColor)
    if powerType == POWER_TYPES.Runes then
        ApplyPipTexturesIfChanged(bar, barTexturePath)
        ApplyBarBackground(bar, bgTexturePath, bgColor)
        UpdateRuneCooldowns(bar)
        return
    end

    if powerType == POWER_TYPES.Essence then
        ApplyPipTexturesIfChanged(bar, barTexturePath)
        ApplyBarBackground(bar, bgTexturePath, bgColor)
        UpdateEssenceCooldowns(bar)
        return
    end

    if powerType == POWER_TYPES.SoulShards then
        ApplyPipTexturesIfChanged(bar, barTexturePath)
        ApplyBarBackground(bar, bgTexturePath, bgColor)
        ApplySoulShardStates(bar)
        return
    end

    ApplyPipTexturesIfChanged(bar, barTexturePath)
    local color = bar.color
    if color then
        for _, pip in ipairs(bar.pips) do
            SetStatusBarColorIfChanged(pip, color)
        end
    end
    ApplyBarBackground(bar, bgTexturePath, bgColor)
end

local visiblePowerTypes = {}
local function HideInactiveResourceBars(powerTypes)
    table.wipe(visiblePowerTypes)
    for i = 1, #powerTypes do
        visiblePowerTypes[powerTypes[i]] = true
    end

    for powerType, bar in pairs(CDM.resourceBars) do
        if not visiblePowerTypes[powerType] then
            bar:Hide()
            if bar.borderFrame then
                bar.borderFrame:Hide()
            end
        end
    end

    table.wipe(visiblePowerTypes)
end

local function HideAllResourceBars()
    for _, bar in pairs(CDM.resourceBars) do
        bar:Hide()
        if bar.borderFrame then
            bar.borderFrame:Hide()
        end
    end
end

local function UpdateBarPositions()
    if not CDM.resourceContainer then
        return
    end

    UpdateContainerPosition()

    local powerTypes = GetPlayerPowerTypes()

    if not powerTypes or #powerTypes == 0 then
        table.wipe(CDM.currentPowerTypes)
        HideAllResourceBars()

        if CDM.resourceContainer.unifiedBorderFrame then
            CDM.resourceContainer.unifiedBorderFrame:Hide()
        end
        if CDM.resourceContainer.separator then
            CDM.resourceContainer.separator:Hide()
        end

        return
    end

    table.wipe(CDM.currentPowerTypes)
    for i = 1, #powerTypes do
        CDM.currentPowerTypes[i] = powerTypes[i]
    end

    local configuredBarWidth = CDM.db.resourcesBarWidth or 0
    local useAutoWidth = (configuredBarWidth == 0)
    local barWidth = configuredBarWidth

    if barWidth == 0 and CDM.CalculateEssentialRow1Width then
        barWidth = CDM.CalculateEssentialRow1Width()
    end

    if barWidth == 0 then
        barWidth = 200
    end

    barWidth = SnapWidthToPixelGrid(CDM.resourceContainer, barWidth)

    local bar1Height = SnapToPixel(CDM.db.resourcesBarHeight or 16, CDM.resourceContainer)
    local bar2Height = SnapToPixel(CDM.db.resourcesBar2Height or 16, CDM.resourceContainer)
    local barSpacing = SnapToPixel(CDM.db.resourcesBarSpacing or 2, CDM.resourceContainer)
    local barTexturePath, bgTexturePath = GetBarTextures()
    local bgColor = CDM.db.resourcesBackgroundColor or CDM.defaults.resourcesBackgroundColor
    local borderColor = CDM.db.borderColor or CDM.defaults.borderColor or DEFAULT_WHITE_COLOR

    for i, powerType in ipairs(powerTypes) do
        local bar = CreateBar(powerType)

        local barHeight = (i == 1) and bar1Height or bar2Height

        if bar.isPipBar then
            local max = GetPipBarMax(powerType)

            if max and max > 0 then
                bar:SetSize(barWidth, barHeight)

                local needsRecreate = ((bar.activePipCount or 0) ~= max) or
                                     (bar.lastBarWidth ~= barWidth) or
                                     (bar.lastBarHeight ~= barHeight)

                if needsRecreate then
                    CreatePips(bar, max, barWidth, barHeight)
                    bar.lastBarWidth = barWidth
                    bar.lastBarHeight = barHeight
                end
            else
                bar:SetSize(barWidth, barHeight)
            end
        else
            bar:SetSize(barWidth, barHeight)

            SetStatusBarTextureIfChanged(bar, barTexturePath)

            local color = GetPowerColor(powerType)
            if color then
                SetStatusBarColorIfChanged(bar, color)
            end

            if bar.bg then
                SetTextureIfChanged(bar.bg, bgTexturePath)
                SetVertexColorIfChanged(bar.bg, bgColor)
            end
        end

        bar:ClearAllPoints()

        if i == 1 then
            bar:SetPoint("BOTTOMLEFT", CDM.resourceContainer, "BOTTOMLEFT", 0, 0)
        else
            local prevBar = CDM.resourceBars[powerTypes[i - 1]]
            if prevBar then
                bar:SetPoint("BOTTOMLEFT", prevBar, "TOPLEFT", 0, barSpacing)
            end
        end

        bar:Show()
        -- Bars are positioned at x=0 inside a center-aligned container. Snapping bar X here
        -- can introduce a 1px horizontal drift relative to icons; keep only vertical snapping.
        SnapFrameVerticallyToPixelGrid(bar)

        if bar.isPipBar then
            bar.color = GetPowerColor(powerType) or bar.color

            if bar.separators then
                local activeSeps = bar.activePipCount and (bar.activePipCount - 1) or 0
                for i = 1, activeSeps do
                    SetVertexColorIfChanged(bar.separators[i], borderColor)
                end
            end

            UpdatePipBarVisuals(bar, powerType, barTexturePath, bgTexturePath, bgColor)
        end
    end

    local totalHeight = bar1Height + (#powerTypes - 1) * (bar2Height + barSpacing)
    CDM.resourceContainer:SetSize(barWidth, totalHeight)
    -- In auto-width mode, match the essential container's rendered center exactly.
    -- This avoids 1px parity drift across different row sizes and border modes.
    if useAutoWidth then
        AlignResourceContainerXToEssentialCenter()
    end

    UpdateBorders(powerTypes)

    HideInactiveResourceBars(powerTypes)
end

function CDM:HasSecondaryResourceBar()
    if CDM.db.resourcesEnabled == false then return false end
    return CDM.currentPowerTypes and #CDM.currentPowerTypes >= 2
end

function CDM:UpdateResources()
    if not self.resourceContainer then
        return
    end

    RefreshCachedFontStyles()
    UpdateBarPositions()
    self:UpdateResourceValues()

    if CDM.TAGS and CDM.TAGS.styleDirty and CDM.TAGS.UpdateAllTags then
        CDM.TAGS:UpdateAllTags()
    end
end

function CDM:UpdateResourceValues()
    if not self.resourceContainer then return end
    for _, powerType in ipairs(self.currentPowerTypes) do
        UpdateBarValue(powerType)
    end
end

local function OnSpellUpdateUses(event, spellID, baseSpellID)
    UpdateBarValue(CUSTOM_POWER_TYPES.SoulFragments)
end

local function OnPlayerRegenDisabled()
    StartStaggerTicker()
end

local function OnPlayerRegenEnabled()
    local currentStagger = UnitStagger("player") or 0
    if IsSafeNumber(currentStagger) and currentStagger > 0 then
        StartStaggerTicker()
        return
    end
    StopStaggerTicker()
end

local function OnBrewmasterCombatStateChanged(isInCombat)
    if currentSpecID ~= 268 then
        return
    end
    if isInCombat then
        OnPlayerRegenDisabled()
        return
    end
    OnPlayerRegenEnabled()
end

local function RegisterBrewmasterCombatStateListener()
    if brewmasterCombatCallbackRegistered then
        return
    end
    if CDM:RegisterInternalCallback("OnCombatStateChanged", OnBrewmasterCombatStateChanged) then
        brewmasterCombatCallbackRegistered = true
    end
end

local function UnregisterBrewmasterCombatStateListener()
    if brewmasterCombatCallbackRegistered then
        CDM:UnregisterInternalCallback("OnCombatStateChanged", OnBrewmasterCombatStateChanged)
        brewmasterCombatCallbackRegistered = false
    end
end

local function OnUnitMaxHealth()
    UpdateStaggerBar()
end

local function OnMaelstromUnitAura()
    local now = GetTime()
    if now - lastMaelstromAuraUpdateTime < 0.05 then
        return
    end
    lastMaelstromAuraUpdateTime = now

    UpdateBarValue(CUSTOM_POWER_TYPES.MaelstromWeapon)
end

local function OnDevourerUnitAura()
    local now = GetTime()
    if now - lastDevourerAuraUpdateTime < 0.05 then
        return
    end
    lastDevourerAuraUpdateTime = now

    UpdateBarValue(CUSTOM_POWER_TYPES.DevourerSoulFragments)
end

local function OnDevourerSpellsChanged()
    if currentSpecID ~= 1480 then
        return
    end
    CDM:UpdateResources()
end


local function OnSpecChanged()
    if CDM.InvalidateSpecIDCache then
        CDM:InvalidateSpecIDCache()
    end

    local specIndex = GetSpecialization()
    local newSpecID = specIndex and GetSpecializationInfo(specIndex) or nil

    if not newSpecID then
        if resourcesSpecInitRetries < 20 then
            resourcesSpecInitRetries = resourcesSpecInitRetries + 1
            C_Timer.After(0.1, function()
                if isEnabled and not currentSpecID then
                    OnSpecChanged()
                end
            end)
        end
        CDM.resourcesSpecReady = false
    else
        resourcesSpecInitRetries = 0
    end

    if newSpecID == 581 then  -- Vengeance Demon Hunter
        if currentSpecID ~= 581 then
            CDM:RegisterEvent("SPELL_UPDATE_USES", OnSpellUpdateUses)
            C_Timer.After(0.1, function()
                UpdateBarValue(CUSTOM_POWER_TYPES.SoulFragments)
            end)
        end
    else
        if currentSpecID == 581 then
            CDM:UnregisterEventHandler("SPELL_UPDATE_USES", OnSpellUpdateUses)
        end
    end

    if newSpecID == 268 then  -- Brewmaster Monk
        if currentSpecID ~= 268 then
            RegisterBrewmasterCombatStateListener()
            CDM:RegisterUnitEvent("UNIT_MAXHEALTH", "player", OnUnitMaxHealth)

            local currentStagger = UnitStagger("player") or 0
            if InCombatLockdown() or (IsSafeNumber(currentStagger) and currentStagger > 0) then
                StartStaggerTicker()
            end
        end
    else
        if currentSpecID == 268 then
            UnregisterBrewmasterCombatStateListener()
            CDM:UnregisterUnitEventHandler("UNIT_MAXHEALTH", OnUnitMaxHealth)
            StopStaggerTicker()
        end
    end

    if newSpecID == 263 then
        if currentSpecID ~= 263 then
            CDM:RegisterUnitEvent("UNIT_AURA", "player", OnMaelstromUnitAura)
            C_Timer.After(0.1, function()
                UpdateBarValue(CUSTOM_POWER_TYPES.MaelstromWeapon)
            end)
        end
    else
        if currentSpecID == 263 then
            CDM:UnregisterUnitEventHandler("UNIT_AURA", OnMaelstromUnitAura)
            StopMaelstromWatch()
        end
    end

    if newSpecID == 1480 then
        if currentSpecID ~= 1480 then
            CDM:RegisterUnitEvent("UNIT_AURA", "player", OnDevourerUnitAura)
            CDM:RegisterEvent("SPELLS_CHANGED", OnDevourerSpellsChanged)
            C_Timer.After(0.1, function()
                UpdateBarValue(CUSTOM_POWER_TYPES.DevourerSoulFragments)
            end)
        end
    else
        if currentSpecID == 1480 then
            CDM:UnregisterUnitEventHandler("UNIT_AURA", OnDevourerUnitAura)
            CDM:UnregisterEventHandler("SPELLS_CHANGED", OnDevourerSpellsChanged)
        end
    end

    currentSpecID = newSpecID
    CDM.resourcesSpecReady = (newSpecID ~= nil)

    CDM:UpdateResources()

    if CDM.UpdateBuffContainerPosition then
        CDM:UpdateBuffContainerPosition()
    end
    if CDM.UpdatePlayerCastBar then
        CDM:UpdatePlayerCastBar()
    end
end

local function OnUnitPowerFrequent(event, unitTarget, powerToken)
    local now = GetTime()

    local primaryPowerType = UnitPowerType("player")
    if primaryPowerType ~= nil then
        local lastPrimary = CDM.lastPowerTypeUpdateTimes[primaryPowerType]
        if not lastPrimary or (now - lastPrimary) >= 0.05 then
            CDM.lastPowerTypeUpdateTimes[primaryPowerType] = now
            UpdateBarValue(primaryPowerType)
        end
    end

    if powerToken then
        local powerTypeFromToken = POWER_TOKEN_MAP[powerToken]
        if powerTypeFromToken and powerTypeFromToken ~= primaryPowerType then
            local lastToken = CDM.lastPowerTypeUpdateTimes[powerTypeFromToken]
            if not lastToken or (now - lastToken) >= 0.05 then
                CDM.lastPowerTypeUpdateTimes[powerTypeFromToken] = now
                UpdateBarValue(powerTypeFromToken)
            end
        end
    end
end

local function OnUnitPowerPointCharge(event, unitTarget)
    if resourcesPlayerClass ~= "ROGUE" then
        return
    end
    if unitTarget and unitTarget ~= "player" then
        return
    end
    UpdateBarValue(POWER_TYPES.ComboPoints)
end

local function OnUpdateShapeshiftForm()
    CDM:UpdateResources()

    if CDM.UpdateBuffContainerPosition then
        CDM:UpdateBuffContainerPosition()
    end
    if CDM.UpdatePlayerCastBar then
        CDM:UpdatePlayerCastBar()
    end
end

local function RunePowerBatchCallback()
    runePowerUpdatePending = false
    local bar = CDM.resourceBars[POWER_TYPES.Runes]
    if bar and bar:IsShown() then
        UpdateRuneCooldowns(bar)
    end
end

local function OnRunePowerUpdate(event, runeIndex, isEnergize)
    if runePowerUpdatePending then return end
    runePowerUpdatePending = true
    C_Timer.After(0, RunePowerBatchCallback)
end

local function OnUnitMaxPower()
    UpdateBarPositions()
    CDM:UpdateResourceValues()
end

local CORE_EVENTS = {
    { "UNIT_POWER_FREQUENT", OnUnitPowerFrequent, "player" },
    { "UNIT_MAXPOWER", OnUnitMaxPower, "player" },
    { "UPDATE_SHAPESHIFT_FORM", OnUpdateShapeshiftForm },
}

local function OnResourcesSpecStateChanged(unit, event)
    if unit and unit ~= "player" then
        return
    end
    if event and event ~= "PLAYER_SPECIALIZATION_CHANGED" then
        return
    end
    OnSpecChanged()
end

local function RegisterCoreEvents()
    for _, entry in ipairs(CORE_EVENTS) do
        if entry[3] then
            CDM:RegisterUnitEvent(entry[1], entry[3], entry[2])
        else
            CDM:RegisterEvent(entry[1], entry[2])
        end
    end
    CDM:RegisterInternalCallback("OnSpecStateChanged", OnResourcesSpecStateChanged)
    if resourcesPlayerClass == "DEATHKNIGHT" then
        CDM:RegisterEvent("RUNE_POWER_UPDATE", OnRunePowerUpdate)
    end
    if resourcesPlayerClass == "ROGUE" then
        CDM:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player", OnUnitPowerPointCharge)
    end
end

local function UnregisterCoreEvents()
    for _, entry in ipairs(CORE_EVENTS) do
        if entry[3] then
            CDM:UnregisterUnitEventHandler(entry[1], entry[2])
        else
            CDM:UnregisterEventHandler(entry[1], entry[2])
        end
    end
    CDM:UnregisterInternalCallback("OnSpecStateChanged", OnResourcesSpecStateChanged)
    if resourcesPlayerClass == "DEATHKNIGHT" then
        CDM:UnregisterEventHandler("RUNE_POWER_UPDATE", OnRunePowerUpdate)
    end
    if resourcesPlayerClass == "ROGUE" then
        CDM:UnregisterUnitEventHandler("UNIT_POWER_POINT_CHARGE", OnUnitPowerPointCharge)
    end
end

function CDM:InitializeResources()
    if isInitialized then return end

    if not self.resourceContainer then
        self.resourceContainer = CreateFrame("Frame", "Ayije_CDM_ResourcesContainer", UIParent)
        self.resourceContainer:SetFrameStrata(CDM_C.STRATA_MAIN)
        self.resourceContainer:SetSize(200, 100)
    end

    RegisterCoreEvents()
    local specIndex = GetSpecialization()
    local specReady = false
    if specIndex then
        specReady = GetSpecializationInfo(specIndex) ~= nil
    end

    if specReady then
        OnSpecChanged()
    elseif EventUtil and EventUtil.RegisterOnceFrameEventAndCallback then
        EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_ENTERING_WORLD", function()
            OnSpecChanged()
        end)
    else
        OnSpecChanged()
    end

    isInitialized = true
    isEnabled = true
end

local function EnableResources()
    if not isInitialized or isEnabled then return end
    RegisterCoreEvents()
    OnSpecChanged()
    if CDM.resourceContainer then
        CDM.resourceContainer:Show()
    end
    isEnabled = true
end

local function DisableResources()
    if not isEnabled then return end
    UnregisterCoreEvents()
    CDM:UnregisterEventHandler("SPELL_UPDATE_USES", OnSpellUpdateUses)
    CDM:UnregisterEventHandler("SPELLS_CHANGED", OnDevourerSpellsChanged)
    UnregisterBrewmasterCombatStateListener()
    CDM:UnregisterUnitEventHandler("UNIT_MAXHEALTH", OnUnitMaxHealth)
    CDM:UnregisterUnitEventHandler("UNIT_AURA", OnMaelstromUnitAura)
    CDM:UnregisterUnitEventHandler("UNIT_AURA", OnDevourerUnitAura)
    StopMaelstromWatch()
    if runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
    end
    if essenceUpdateTicker then
        essenceUpdateTicker:Cancel()
        essenceUpdateTicker = nil
    end
    essenceRechargeStart = nil
    essenceRechargeRate = nil
    StopStaggerTicker()
    if CDM.resourceContainer then
        CDM.resourceContainer:Hide()
    end
    CDM.lastPowerTypeUpdateTimes = {}
    lastMaelstromAuraUpdateTime = 0
    lastDevourerAuraUpdateTime = 0
    currentSpecID = nil
    isEnabled = false
end

local function RefreshResourcesLifecycle()
    if not isEnabled then return end
    CDM:UpdateResources()
end

local function OnResourcesProfileApplied()
    cachedFontPath = nil
    cachedFontSize = nil
    cachedFontOutline = nil
    cachedFontColor = nil
    cachedRuneReadyColor = nil
    cachedRuneRechargingColor = nil
    cachedEssenceReadyColor = nil
    cachedEssenceRechargingColor = nil
    cachedSoulShardReadyColor = nil
    cachedSoulShardRechargingColor = nil
    cachedBar2TagEnabled = false
    cachedBar2OffsetX = 0
    cachedBar2OffsetY = 0

    if CDM.resourceBars then
        for _, bar in pairs(CDM.resourceBars) do
            if bar then
                bar.lastBarWidth = nil
                bar.lastBarHeight = nil
                bar._lastPipTexturePath = nil
            end
        end
    end
end

if CDM.ModuleManager and CDM.ModuleManager.RegisterModule then
    CDM.ModuleManager:RegisterModule({
        id = "resources",
        Initialize = function()
            CDM:InitializeResources()
        end,
        Enable = EnableResources,
        Disable = DisableResources,
        Refresh = RefreshResourcesLifecycle,
        OnProfileApplied = OnResourcesProfileApplied,
        ShouldBeEnabled = function(db)
            return db and db.resourcesEnabled ~= false
        end,
    })
end

CDM:RegisterRefreshCallback("resources", function()
    local moduleManager = CDM.ModuleManager
    if moduleManager and moduleManager.ReconcileModule then
        moduleManager:ReconcileModule("resources")
    end
end, 50, { "resources_visuals", "trackers_layout", "viewers" })
