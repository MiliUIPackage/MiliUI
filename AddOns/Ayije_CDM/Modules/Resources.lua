local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = CDM.IsSafeNumber
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local GetTime = GetTime
local issecretvalue = issecretvalue
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local POWER_TYPES = Enum.PowerType
local LSM = LibStub("LibSharedMedia-3.0")

local resEventFrame = CreateFrame("Frame")
local resEventHandlers = {}

resEventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = resEventHandlers[event]
    if handler then handler(event, ...) end
end)

local function RegisterResEvent(event, handler)
    resEventHandlers[event] = handler
    resEventFrame:RegisterEvent(event)
end

local function UnregisterResEvent(event)
    resEventHandlers[event] = nil
    resEventFrame:UnregisterEvent(event)
end

local function RegisterResUnitEvent(event, unit, handler)
    resEventHandlers[event] = handler
    resEventFrame:RegisterUnitEvent(event, unit)
end

local function UnregisterResUnitEvent(event)
    resEventHandlers[event] = nil
    resEventFrame:UnregisterEvent(event)
end

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
    Ironfur = "Ironfur",
    IgnorePain = "IgnorePain",
    TipOfTheSpear = "TipOfTheSpear",
}
CDM.CUSTOM_POWER_TYPES = CUSTOM_POWER_TYPES


local isInitialized = false
local isEnabled = false

local currentSpecID
local resourcesSpecInitRetries = 0
local _, resourcesPlayerClass = UnitClass("player")


local cachedPrimaryPowerType
local cachedSoulShardReadyColor
local cachedSoulShardRechargingColor
local GetResourceConfigSlot

local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local IsOneBorderMode = Pixel.IsOneBorderMode

local function SnapWidthToPixelGrid(frame, width)
    if not width or width <= 0 then
        return width, 0, 1
    end

    local onePixel = Pixel.GetSize()
    local pixelWidth = math_max(1, math_floor(width / onePixel + 0.5))
    return pixelWidth * onePixel, pixelWidth, onePixel
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
        -- edge-anchored (BOTTOMLEFT + HalfFloor offset), bars are snapped individually.
        borderFrame:SetPoint("BOTTOMLEFT", bottomBar, "BOTTOMLEFT", 0, 0)
        borderFrame:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", 0, 0)
        return
    end

    borderFrame:SetAllPoints(container)
end

local function ConfigurePixelTexture(tex)
    if not tex then return end
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    Pixel.DisableTextureSnap(tex)
end


local function ApplyResourcePixelBorder(host, color)
    if not host.pixelBorderLines then
        host.pixelBorderLines = {}
        for i = 1, 4 do
            host.pixelBorderLines[i] = Pixel.CreateSolidTexture(host, "OVERLAY", 6)
        end
    end

    local onePx = Pixel.GetSize()
    local px = math_max(1, math_floor((CDM_C.GetConfigValue("borderSize", 1) or 1) / onePx)) * onePx
    Pixel.ApplyBorderLines(host.pixelBorderLines, host, px,
        (color and color.r) or 1, (color and color.g) or 1,
        (color and color.b) or 1, (color and color.a) or 1)
end

local function HideResourcePixelBorder(host)
    if host and host.pixelBorderLines then
        for _, line in ipairs(host.pixelBorderLines) do
            line:Hide()
        end
    end
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
            xOffset = Snap(pipRight - barLeft)
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
    [CUSTOM_POWER_TYPES.Ironfur] = "resourcesIronfurColor",
    [CUSTOM_POWER_TYPES.IgnorePain] = "resourcesIgnorePainColor",
    [CUSTOM_POWER_TYPES.TipOfTheSpear] = "resourcesTipOfTheSpearColor",
}

local DEFAULT_WHITE_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local chargedComboPointLookup = {}

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

local function IsFeralOverflowingComboPoints(powerType)
    return resourcesPlayerClass == "DRUID" and currentSpecID == 103 and powerType == POWER_TYPES.ComboPoints
end

local function GetFeralOverflowingColors()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    local baseColor = (db and db.resourcesComboPointsColor) or defaults.resourcesComboPointsColor or DEFAULT_WHITE_COLOR
    local filledColor = (db and db.resourcesFeralOverflowingColor) or defaults.resourcesFeralOverflowingColor or baseColor
    local emptyColor = (db and db.resourcesFeralOverflowingEmptyColor) or defaults.resourcesFeralOverflowingEmptyColor or baseColor
    return filledColor, emptyColor
end

local function GetComboPointChargeColors()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    local baseColor = (db and db.resourcesComboPointsColor) or defaults.resourcesComboPointsColor or DEFAULT_WHITE_COLOR
    local chargedColor = (db and db.resourcesComboPointsChargedColor) or defaults.resourcesComboPointsChargedColor or baseColor
    local chargedEmptyColor = (db and db.resourcesComboPointsChargedEmptyColor) or defaults.resourcesComboPointsChargedEmptyColor or baseColor
    return chargedColor, chargedEmptyColor
end

local chargedComboPointsDirty = true

local function RefreshChargedComboPointLookup()
    chargedComboPointsDirty = false

    if resourcesPlayerClass ~= "ROGUE" or type(GetUnitChargedPowerPoints) ~= "function" then
        return nil
    end

    local chargedPoints = GetUnitChargedPowerPoints("player")
    if type(chargedPoints) ~= "table" or #chargedPoints == 0 then
        table.wipe(chargedComboPointLookup)
        return nil
    end

    table.wipe(chargedComboPointLookup)

    local hasEntries = false
    for i = 1, #chargedPoints do
        local pointIndex = chargedPoints[i]
        if type(pointIndex) == "number" and pointIndex > 0 then
            chargedComboPointLookup[pointIndex] = true
            hasEntries = true
        end
    end

    return hasEntries and chargedComboPointLookup or nil
end

local function GetChargedComboPointLookup()
    if chargedComboPointsDirty then
        RefreshChargedComboPointLookup()
    end
    return next(chargedComboPointLookup) and chargedComboPointLookup or nil
end

local function RefreshCachedFontStyles()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    cachedSoulShardReadyColor = GetPowerColor(POWER_TYPES.SoulShards)
    cachedSoulShardRechargingColor = (db and db.resourcesSoulShardsRechargingColor)
        or defaults.resourcesSoulShardsRechargingColor or cachedSoulShardReadyColor
    if CDM._Res and CDM._Res.RefreshTrackerFontCache then
        CDM._Res.RefreshTrackerFontCache()
    end
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
    [73] = {POWER_TYPES.Rage, CUSTOM_POWER_TYPES.IgnorePain},    -- Protection Warrior
    [65] = POWER_TYPES.HolyPower,                               -- Holy Paladin
    [66] = POWER_TYPES.HolyPower,                               -- Protection Paladin
    [70] = POWER_TYPES.HolyPower,                               -- Retribution Paladin
    [253] = POWER_TYPES.Focus,                                  -- Beast Mastery Hunter
    [254] = POWER_TYPES.Focus,                                  -- Marksmanship Hunter
    [255] = {POWER_TYPES.Focus, CUSTOM_POWER_TYPES.TipOfTheSpear}, -- Survival Hunter
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
CDM.currentPowerSlots = {}
CDM.currentPowerTypeSlots = {}


local scratchPowerTypes = {}
local scratchVisiblePowerTypes = {}
local scratchVisiblePowerSlots = {}

GetResourceConfigSlot = function(powerType)
    local powerTypeSlots = CDM.currentPowerTypeSlots
    if powerType and powerTypeSlots and powerTypeSlots[powerType] then
        return powerTypeSlots[powerType]
    end

    local powerTypes = CDM.currentPowerTypes
    local slotIndices = CDM.currentPowerSlots
    if powerTypes then
        for i, currentPowerType in ipairs(powerTypes) do
            if currentPowerType == powerType then
                return (slotIndices and slotIndices[i]) or i
            end
        end
    end

    local bar = CDM.resourceBars and CDM.resourceBars[powerType]
    if bar and bar.slotIndex then
        return bar.slotIndex
    end

    return nil
end

function CDM:GetResourceBarSlotIndex(powerType)
    return GetResourceConfigSlot(powerType)
end

local function ApplyResourceVisibilityFilter(powerTypes)
    if not powerTypes or #powerTypes == 0 then return powerTypes end

    local primaryEnabled = CDM.GetPrimaryResourceEnabled and CDM:GetPrimaryResourceEnabled()
    local secondaryEnabled = CDM.GetSecondaryResourceEnabled and CDM:GetSecondaryResourceEnabled()
    if primaryEnabled == nil then primaryEnabled = true end
    if secondaryEnabled == nil then secondaryEnabled = true end

    local firstNonMana, secondNonMana
    table.wipe(scratchVisiblePowerTypes)
    table.wipe(scratchVisiblePowerSlots)

    for i = 1, #powerTypes do
        local powerType = powerTypes[i]
        if powerType ~= POWER_TYPES.Mana then
            if not firstNonMana then
                firstNonMana = i
            elseif not secondNonMana then
                secondNonMana = i
            end
        end

        local isHiddenPrimary = (not primaryEnabled and i == firstNonMana)
        local isHiddenSecondary = (not secondaryEnabled and i == secondNonMana)
        if not isHiddenPrimary and not isHiddenSecondary then
            local visibleIndex = #scratchVisiblePowerTypes + 1
            scratchVisiblePowerTypes[visibleIndex] = powerType
            scratchVisiblePowerSlots[visibleIndex] = i
        end
    end

    return scratchVisiblePowerTypes, scratchVisiblePowerSlots
end

local function GetPlayerPowerTypes()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID or specID == 0 then
        return nil
    end

    local manaEnabled = CDM.GetManaEnabled and CDM:GetManaEnabled() or false

    local _, class = UnitClass("player")
    if class == "DRUID" then
        local currentPowerType = UnitPowerType("player")

        table.wipe(scratchPowerTypes)
        if currentPowerType == POWER_TYPES.Rage then
            scratchPowerTypes[1] = POWER_TYPES.Rage
            if specID == 104 then
                scratchPowerTypes[2] = CUSTOM_POWER_TYPES.Ironfur
            end
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
        powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments or
        powerType == CUSTOM_POWER_TYPES.TipOfTheSpear
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
    local isFeralOverflowing = IsFeralOverflowingComboPoints(bar.powerType)
    local needsChargeOverlays = isRogueComboPoints or isFeralOverflowing

    if not bar.bgTexture then
        bar.bgTexture = bar:CreateTexture(nil, "BACKGROUND")
    end
    bar.bgTexture:SetTexture(bgTexturePath)
    bar.bgTexture:SetHorizTile(false)
    bar.bgTexture:SetVertTile(false)
    bar.bgTexture:SetAllPoints(bar)
    Pixel.DisableTextureSnap(bar.bgTexture)
    bar.bgTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    bar.bgTexture:Show()

    if not bar.separatorFill then
        bar.separatorFill = Pixel.CreateSolidTexture(bar, "ARTWORK", -1)
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
                timerText:SetFont(CDM_C.FONT_PATH, Pixel.FontSize(10), CDM_C.FONT_OUTLINE)
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
                pip.timerText:SetPoint("CENTER", pip.timerFrame, "CENTER", 0, 0)
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
        end
    else
        if needsChargeOverlays then
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

            if needsChargeOverlays then
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
        if not needsChargeOverlays then
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
            separator = Pixel.CreateSolidTexture(bar.separatorOverlay, "OVERLAY", 7)
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

    if powerType == CUSTOM_POWER_TYPES.IgnorePain then
        bar:SetMinMaxValues(0, 100)
    else
        bar:SetMinMaxValues(0, 1)
    end
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
    Pixel.DisableTextureSnap(bg)
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

    local twoPixels = Pixel.GetSize() * 2

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
        local xOffset = Snap(math_floor((boundary - 2) / twoPixels + 0.5) * twoPixels)

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
                end
                bar.borderFrame:Show()

                if IsOneBorderMode() then
                    if bar.borderFrame.border then bar.borderFrame.border:Hide() end
                    ApplyResourcePixelBorder(bar.borderFrame, borderColor)
                else
                    HideResourcePixelBorder(bar.borderFrame)
                    if CDM.BORDER and CDM.BORDER.CreateBorder then
                        CDM.BORDER:CreateBorder(bar.borderFrame)
                    end
                end
            end
        end
    end

    if useUnified then
        if not CDM.resourceContainer.unifiedBorderFrame then
            CDM.resourceContainer.unifiedBorderFrame = CreateFrame("Frame", nil, CDM.resourceContainer, "BackdropTemplate")
            CDM.resourceContainer.unifiedBorderFrame:SetAllPoints()
        end
        CDM.resourceContainer.unifiedBorderFrame:Show()

        UpdateUnifiedBorderFrameGeometry(powerTypes)

        if IsOneBorderMode() then
            local ubf = CDM.resourceContainer.unifiedBorderFrame
            if ubf.border then ubf.border:Hide() end
            ApplyResourcePixelBorder(ubf, borderColor)
        else
            HideResourcePixelBorder(CDM.resourceContainer.unifiedBorderFrame)
            if CDM.BORDER and CDM.BORDER.CreateBorder then
                CDM.BORDER:CreateBorder(CDM.resourceContainer.unifiedBorderFrame)
            end
        end

        if #powerTypes > 1 then
            if not CDM.resourceContainer.separator then
                local separator = CreateFrame("Frame", nil, CDM.resourceContainer)
                separator:SetIgnoreParentAlpha(true)

                local tex = separator:CreateTexture(nil, "ARTWORK")
                tex:SetTexture("Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Separator")
                Pixel.DisableTextureSnap(tex)
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

                local activeSeps = math_max(0, (bar.activePipCount or 0) - 1)
                local barLeft = bar.GetLeft and bar:GetLeft() or nil
                local onePixel = Pixel.GetSize()
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
    if not CDM.resourceContainer or not CDM.db then
        return
    end

    local offsetX = CDM.db.resourcesOffsetX or 0
    local offsetY = CDM.db.resourcesOffsetY or -200
    local halfW = Pixel.HalfFloor(CDM.resourceContainer:GetWidth() or 0)

    CDM.resourceContainer:ClearAllPoints()
    Pixel.SetPoint(CDM.resourceContainer, "BOTTOMLEFT", UIParent, "CENTER", offsetX - halfW, offsetY)
end

local MAX_SOUL_FRAGMENTS = 6
local MAX_MAELSTROM_WEAPON = 10
local MAX_TIP_OF_THE_SPEAR = 3
local DEVOURER_STACKS_PER_PIP = 5

local UpdateBarValue

local function ApplySoulShardStates(bar)
    local rawPower = UnitPower("player", POWER_TYPES.SoulShards, true) or 0
    local isRawSecret = type(rawPower) == "number" and issecretvalue(rawPower)
    local specID = currentSpecID
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


UpdateBarValue = function(powerType)
    local bar = CDM.resourceBars[powerType]
    if not bar or not bar:IsShown() then
        return
    end

    local current, max

    if powerType == CUSTOM_POWER_TYPES.SoulFragments then
        current = C_Spell.GetSpellCastCount(CDM_C.SOUL_CLEAVE_SPELL_ID) or 0
        max = MAX_SOUL_FRAGMENTS
    elseif powerType == CUSTOM_POWER_TYPES.MaelstromWeapon then
        current, max = CDM._Res.UpdateMaelstromBar(bar)
    elseif powerType == CUSTOM_POWER_TYPES.TipOfTheSpear then
        current, max = CDM._Res.UpdateTipOfTheSpearBar(bar)
    elseif powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments then
        current, max = CDM._Res.GetDevourerSoulValueMax()
        current = current / DEVOURER_STACKS_PER_PIP
        max = max / DEVOURER_STACKS_PER_PIP
    elseif powerType == CUSTOM_POWER_TYPES.Ironfur then
        CDM._Res.UpdateIronfurBar()
        return
    elseif powerType == CUSTOM_POWER_TYPES.IgnorePain then
        return
    elseif powerType == CUSTOM_POWER_TYPES.Stagger then
        CDM._Res.UpdateStaggerBar()
        return
    else
        current = UnitPower("player", powerType)
        max = UnitPowerMax("player", powerType)
    end

    if bar.isPipBar then
        if powerType == POWER_TYPES.Runes then
            CDM._Res.UpdateRuneCooldowns(bar)
            return
        elseif powerType == POWER_TYPES.Essence then
            CDM._Res.UpdateEssenceCooldowns(bar)
            CDM._Res.UpdateTagTextForPowerType(powerType)
            return
        elseif powerType == POWER_TYPES.SoulShards then
            ApplySoulShardStates(bar)
            CDM._Res.UpdateTagTextForPowerType(powerType)
            return
        end
        local isRogueComboPoints = IsRogueComboPoints(powerType)
        local isFeralOverflowing = IsFeralOverflowingComboPoints(powerType)
        local hasChargedPoints = false
        local chargedFilledColor, chargedEmptyColor
        local chargedLookup, feralStacks

        if isRogueComboPoints then
            chargedLookup = GetChargedComboPointLookup()
            if chargedLookup then
                hasChargedPoints = true
                chargedFilledColor, chargedEmptyColor = GetComboPointChargeColors()
            end
        elseif isFeralOverflowing then
            feralStacks = CDM._Res.GetFeralOverflowingStacks()
            if feralStacks > 0 then
                hasChargedPoints = true
                chargedFilledColor, chargedEmptyColor = GetFeralOverflowingColors()
            end
        end

        for i, pip in ipairs(bar.pips) do
            pip:SetValue(current, Enum.StatusBarInterpolation.Immediate)

            if hasChargedPoints then
                local isCharged = chargedLookup and chargedLookup[i] or (feralStacks and i <= feralStacks)

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
            elseif bar.comboChargeEmptyOverlays then
                SetStatusBarColorIfChanged(pip, bar.color)
                local overlay = bar.comboChargeEmptyOverlays[i]
                if overlay then overlay:Hide() end
            end
        end

        if bar.comboChargeEmptyOverlays then
            for i = (#bar.pips + 1), #bar.comboChargeEmptyOverlays do
                bar.comboChargeEmptyOverlays[i]:Hide()
            end
        end
    else
        bar:SetMinMaxValues(0, max)
        if bar.isPrimaryResource and CDM.db.resourcesSmoothBars ~= false then
            bar:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
        else
            bar:SetValue(current, Enum.StatusBarInterpolation.Immediate)
        end

    end

    CDM._Res.UpdateTagTextForPowerType(powerType)
end

local function GetPipBarMax(powerType)
    if powerType == CUSTOM_POWER_TYPES.SoulFragments then
        return MAX_SOUL_FRAGMENTS
    end
    if powerType == CUSTOM_POWER_TYPES.MaelstromWeapon then
        return MAX_MAELSTROM_WEAPON
    end
    if powerType == CUSTOM_POWER_TYPES.DevourerSoulFragments then
        local _, max = CDM._Res.GetDevourerSoulValueMax()
        return max / DEVOURER_STACKS_PER_PIP
    end
    if powerType == CUSTOM_POWER_TYPES.TipOfTheSpear then
        return MAX_TIP_OF_THE_SPEAR
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
        CDM._Res.UpdateRuneCooldowns(bar)
        return
    end

    if powerType == POWER_TYPES.Essence then
        ApplyPipTexturesIfChanged(bar, barTexturePath)
        ApplyBarBackground(bar, bgTexturePath, bgColor)
        CDM._Res.UpdateEssenceCooldowns(bar)
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

local function GetBarHeightForSlot(slotIndex)
    if slotIndex == 2 then
        return Snap(CDM.db.resourcesBar2Height or 16)
    end
    return Snap(CDM.db.resourcesBarHeight or 16)
end

local function UpdateBarPositions()
    if not CDM.resourceContainer then
        return
    end

    local basePowerTypes = GetPlayerPowerTypes()
    local powerTypes, powerSlots = ApplyResourceVisibilityFilter(basePowerTypes)

    if not powerTypes or #powerTypes == 0 then
        table.wipe(CDM.currentPowerTypes)
        table.wipe(CDM.currentPowerSlots)
        table.wipe(CDM.currentPowerTypeSlots)
        HideAllResourceBars()

        if CDM.resourceContainer.unifiedBorderFrame then
            CDM.resourceContainer.unifiedBorderFrame:Hide()
        end
        if CDM.resourceContainer.separator then
            CDM.resourceContainer.separator:Hide()
        end

        UpdateContainerPosition()
        return
    end

    table.wipe(CDM.currentPowerTypes)
    table.wipe(CDM.currentPowerSlots)
    table.wipe(CDM.currentPowerTypeSlots)
    for i = 1, #powerTypes do
        CDM.currentPowerTypes[i] = powerTypes[i]
        CDM.currentPowerSlots[i] = (powerSlots and powerSlots[i]) or i
        CDM.currentPowerTypeSlots[powerTypes[i]] = CDM.currentPowerSlots[i]
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

    local barSpacing = Snap(CDM.db.resourcesBarSpacing or 2)
    local barTexturePath, bgTexturePath = GetBarTextures()
    local bgColor = CDM.db.resourcesBackgroundColor or CDM.defaults.resourcesBackgroundColor
    local borderColor = CDM.db.borderColor or CDM.defaults.borderColor or DEFAULT_WHITE_COLOR
    local totalHeight = 0

    for visualIndex, powerType in ipairs(powerTypes) do
        local bar = CreateBar(powerType)
        local slotIndex = (powerSlots and powerSlots[visualIndex]) or visualIndex

        bar.slotIndex = slotIndex

        local barHeight = GetBarHeightForSlot(slotIndex)
        totalHeight = totalHeight + barHeight
        if visualIndex > 1 then
            totalHeight = totalHeight + barSpacing
        end

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

        if visualIndex == 1 then
            bar:SetPoint("BOTTOMLEFT", CDM.resourceContainer, "BOTTOMLEFT", 0, 0)
        else
            local prevBar = CDM.resourceBars[powerTypes[visualIndex - 1]]
            if prevBar then
                bar:SetPoint("BOTTOMLEFT", prevBar, "TOPLEFT", 0, barSpacing)
            end
        end

        bar:Show()

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

    CDM.resourceContainer:SetSize(barWidth, totalHeight)
    UpdateContainerPosition()

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

    if currentSpecID == 104 then
        CDM._Res.RefreshIronfurTalents()
    end

    if currentSpecID == 73 and CDM._Res.RefreshIgnorePainVisibility then
        CDM._Res.RefreshIgnorePainVisibility()
    end

    cachedPrimaryPowerType = UnitPowerType("player")
    RefreshCachedFontStyles()
    UpdateBarPositions()
    CDM._Res.RefreshCachedRuneTimerSlot()
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


local function UpdateAncillaryLayouts()
    if CDM.UpdateBuffContainerPosition then
        CDM:UpdateBuffContainerPosition()
    end
    if CDM.UpdatePlayerCastBar then
        CDM:UpdatePlayerCastBar()
    end
end

local function OnSpecChanged()
    if CDM.InvalidateSpecIDCache then
        CDM:InvalidateSpecIDCache()
    end

    local specIndex = GetSpecialization()
    local newSpecID = specIndex and GetSpecializationInfo(specIndex) or nil

    if not newSpecID or newSpecID == 0 then
        if resourcesSpecInitRetries < 20 then
            resourcesSpecInitRetries = resourcesSpecInitRetries + 1
            C_Timer.After(0.1, function()
                if isEnabled and (not currentSpecID or currentSpecID == 0) then
                    OnSpecChanged()
                end
            end)
        end
        CDM.resourcesSpecReady = false
        return
    else
        resourcesSpecInitRetries = 0
    end

    if newSpecID == 581 then
        if currentSpecID ~= 581 then
            CDM._Res.EnableVengeanceSoulTracking()
        end
    elseif currentSpecID == 581 then
        CDM._Res.DisableVengeanceSoulTracking()
    end

    if newSpecID == 268 then
        if currentSpecID ~= 268 then
            CDM._Res.EnableBrewmasterTracking()
        end
    elseif currentSpecID == 268 then
        CDM._Res.DisableBrewmasterTracking()
    end

    if newSpecID == 263 then
        if currentSpecID ~= 263 then
            CDM._Res.EnableMaelstromTracking()
        end
    elseif currentSpecID == 263 then
        CDM._Res.DisableMaelstromTracking()
    end

    if newSpecID == 103 then
        if currentSpecID ~= 103 then
            CDM._Res.EnableFeralOverflowingTracking()
        end
    elseif currentSpecID == 103 then
        CDM._Res.DisableFeralOverflowingTracking()
    end

    if newSpecID == 255 then
        if currentSpecID ~= 255 then
            CDM._Res.EnableTipOfTheSpearTracking()
        end
    elseif currentSpecID == 255 then
        CDM._Res.DisableTipOfTheSpearTracking()
    end

    if newSpecID == 1480 then
        if currentSpecID ~= 1480 then
            CDM._Res.EnableDevourerTracking()
        end
    elseif currentSpecID == 1480 then
        CDM._Res.DisableDevourerTracking()
    end

    if newSpecID == 104 then
        if currentSpecID ~= 104 then
            CDM._Res.EnableGuardianTracking()
        else
            CDM._Res.RefreshGuardianTracking()
        end
    elseif currentSpecID == 104 then
        CDM._Res.DisableGuardianTracking()
    end

    if newSpecID == 73 then
        -- StartIgnorePainTracking runs after UpdateResources below
    elseif currentSpecID == 73 then
        CDM._Res.StopIgnorePainTracking()
    end

    currentSpecID = newSpecID
    CDM.resourcesSpecReady = (newSpecID ~= nil)

    CDM:UpdateResources()

    if newSpecID == 73 then
        CDM._Res.StartIgnorePainTracking()
    end

    UpdateAncillaryLayouts()
end

local function OnUnitPowerFrequent(event, unitTarget, powerToken)
    local primaryPowerType = cachedPrimaryPowerType
    if primaryPowerType ~= nil then
        UpdateBarValue(primaryPowerType)
    end

    if powerToken then
        local powerTypeFromToken = POWER_TOKEN_MAP[powerToken]
        if powerTypeFromToken and powerTypeFromToken ~= primaryPowerType then
            UpdateBarValue(powerTypeFromToken)
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
    chargedComboPointsDirty = true
    UpdateBarValue(POWER_TYPES.ComboPoints)
end

local function OnUpdateShapeshiftForm()
    cachedPrimaryPowerType = UnitPowerType("player")

    if currentSpecID == 104 and CDM._Res.OnShapeshiftGuardianCheck then
        CDM._Res.OnShapeshiftGuardianCheck(cachedPrimaryPowerType)
    end

    CDM:UpdateResources()
    UpdateAncillaryLayouts()
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
            RegisterResUnitEvent(entry[1], entry[3], entry[2])
        else
            RegisterResEvent(entry[1], entry[2])
        end
    end
    CDM:RegisterSpecStateHandler(OnResourcesSpecStateChanged)
    if resourcesPlayerClass == "DEATHKNIGHT" then
        RegisterResEvent("RUNE_POWER_UPDATE", CDM._Res.OnRunePowerUpdate)
    end
    if resourcesPlayerClass == "ROGUE" then
        RegisterResUnitEvent("UNIT_POWER_POINT_CHARGE", "player", OnUnitPowerPointCharge)
    end
end

local function UnregisterCoreEvents()
    for _, entry in ipairs(CORE_EVENTS) do
        UnregisterResEvent(entry[1])
    end
    CDM:UnregisterSpecStateHandler(OnResourcesSpecStateChanged)
    if resourcesPlayerClass == "DEATHKNIGHT" then
        UnregisterResEvent("RUNE_POWER_UPDATE")
    end
    if resourcesPlayerClass == "ROGUE" then
        UnregisterResUnitEvent("UNIT_POWER_POINT_CHARGE")
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
    CDM._Res.DisableVengeanceSoulTracking()
    CDM._Res.DisableBrewmasterTracking()
    CDM._Res.DisableMaelstromTracking()
    CDM._Res.DisableFeralOverflowingTracking()
    CDM._Res.DisableTipOfTheSpearTracking()
    CDM._Res.DisableDevourerTracking()
    CDM._Res.DisableGuardianTracking()
    CDM._Res.StopIgnorePainTracking()
    CDM._Res.DisableAllTrackerTickers()
    if CDM.resourceContainer then
        CDM.resourceContainer:Hide()
    end
    currentSpecID = nil
    cachedPrimaryPowerType = nil
    isEnabled = false
end

local function RefreshResourcesLifecycle()
    if not isEnabled then return end
    CDM:UpdateResources()
end

local function OnResourcesProfileApplied()
    cachedSoulShardReadyColor = nil
    cachedSoulShardRechargingColor = nil
    if CDM._Res.OnTrackerProfileApplied then
        CDM._Res.OnTrackerProfileApplied()
    end

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

local function ReconcileResources()
    if CDM.db and CDM.db.resourcesEnabled ~= false then
        if not isInitialized then CDM:InitializeResources() end
        if not isEnabled then EnableResources() end
        RefreshResourcesLifecycle()
    elseif isEnabled then
        DisableResources()
    end
end

CDM._Res = {
    SetStatusBarColorIfChanged = SetStatusBarColorIfChanged,
    SetVertexColorIfChanged    = SetVertexColorIfChanged,
    UpdateBarValue             = UpdateBarValue,
    UpdateBarPositions         = UpdateBarPositions,
    GetPowerColor              = GetPowerColor,
    CUSTOM_POWER_TYPES         = CUSTOM_POWER_TYPES,
    POWER_TYPES                = POWER_TYPES,
    DEVOURER_STACKS_PER_PIP    = DEVOURER_STACKS_PER_PIP,
    GetCurrentSpecID           = function() return currentSpecID end,
    GetIsEnabled               = function() return isEnabled end,
    GetResourceConfigSlot      = GetResourceConfigSlot,
    RegisterResEvent           = RegisterResEvent,
    UnregisterResEvent         = UnregisterResEvent,
    RegisterResUnitEvent       = RegisterResUnitEvent,
    UnregisterResUnitEvent     = UnregisterResUnitEvent,
}

CDM.ReconcileResources = ReconcileResources
CDM.OnResourcesProfileApplied = OnResourcesProfileApplied

