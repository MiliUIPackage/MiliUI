local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local GetTime = GetTime
local issecretvalue = issecretvalue
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local table_wipe = table.wipe
local GetSpellCastCount = C_Spell.GetSpellCastCount

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

local UnregisterResUnitEvent = UnregisterResEvent

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

local POWER_TYPE_TO_BAR_KEY = {
    [POWER_TYPES.Mana] = "Mana",
    [POWER_TYPES.Rage] = "Rage",
    [POWER_TYPES.Energy] = "Energy",
    [POWER_TYPES.Focus] = "Focus",
    [POWER_TYPES.ComboPoints] = "ComboPoints",
    [POWER_TYPES.Runes] = "Runes",
    [POWER_TYPES.RunicPower] = "RunicPower",
    [POWER_TYPES.SoulShards] = "SoulShards",
    [POWER_TYPES.LunarPower] = "LunarPower",
    [POWER_TYPES.HolyPower] = "HolyPower",
    [POWER_TYPES.Maelstrom] = "Maelstrom",
    [POWER_TYPES.Chi] = "Chi",
    [POWER_TYPES.Insanity] = "Insanity",
    [POWER_TYPES.ArcaneCharges] = "ArcaneCharges",
    [POWER_TYPES.Fury] = "Fury",
    [POWER_TYPES.Essence] = "Essence",
}

local BAR_KEY_TO_POWER_TYPE = {}
for pt, key in pairs(POWER_TYPE_TO_BAR_KEY) do
    BAR_KEY_TO_POWER_TYPE[key] = pt
end
for _, customKey in pairs(CUSTOM_POWER_TYPES) do
    BAR_KEY_TO_POWER_TYPE[customKey] = customKey
end

local function GetBarKey(powerType)
    return POWER_TYPE_TO_BAR_KEY[powerType] or powerType
end

local CLASS_BARS = {
    General     = { "Mana" },
    WARRIOR     = { "Rage", "IgnorePain" },
    PALADIN     = { "HolyPower" },
    HUNTER      = { "Focus", "TipOfTheSpear" },
    ROGUE       = { "Energy", "ComboPoints" },
    PRIEST      = { "Insanity" },
    DEATHKNIGHT = { "RunicPower", "Runes" },
    SHAMAN      = { "Maelstrom", "MaelstromWeapon" },
    MAGE        = { "ArcaneCharges" },
    WARLOCK     = { "SoulShards" },
    MONK        = { "Energy", "Chi", "Stagger" },
    DRUID       = { "Rage", "Energy", "ComboPoints", "LunarPower", "Ironfur" },
    DEMONHUNTER = { "Fury", "SoulFragments", "DevourerSoulFragments" },
    EVOKER      = { "Essence" },
}

CDM.POWER_TYPE_TO_BAR_KEY = POWER_TYPE_TO_BAR_KEY
CDM.BAR_KEY_TO_POWER_TYPE = BAR_KEY_TO_POWER_TYPE
CDM.CLASS_BARS = CLASS_BARS

local SMOOTH_ELIGIBLE_BARS = {
    Mana=true, Rage=true, Energy=true, Focus=true, RunicPower=true,
    LunarPower=true, Maelstrom=true, Insanity=true, Fury=true,
}

local isInitialized = false
local isEnabled = false

local currentSpecID
local resourcesSpecInitRetries = 0
local _, resourcesPlayerClass = UnitClass("player")


local cachedPrimaryPowerType
local cachedSoulShardReadyColor
local cachedSoulShardRechargingColor
local cachedComboBaseColor
local cachedComboOverflowingFilled
local cachedComboOverflowingEmpty
local cachedComboCharged
local cachedComboChargedEmpty

local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local function SnapWidthToPixelGrid(frame, width)
    if not width or width <= 0 then
        return width, 0, 1
    end

    local onePixel = Pixel.GetSize()
    local pixelWidth = math_max(1, math_floor(width / onePixel + 0.5))
    return pixelWidth * onePixel, pixelWidth, onePixel
end


local function ConfigurePixelTexture(tex)
    if not tex then return end
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    Pixel.DisableTextureSnap(tex)
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

local function PositionSeparatorAt(bar, i, borderColor)
    local sep = bar.separators and bar.separators[i]
    if not sep then return end
    local onePixel = Pixel.GetSize()
    local barHeight = bar.GetHeight and bar:GetHeight() or 0
    if onePixel > 0 and barHeight > 0 then
        sep:SetSize(onePixel, barHeight)
    end
    sep:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    local barLeft = bar.GetLeft and bar:GetLeft() or nil
    local xOffset = ResolvePipSeparatorXOffset(bar, i, barLeft, onePixel)
    SetPipSeparatorVerticalLine(sep, bar, xOffset)
    sep:Show()
end

local DEFAULT_BG_COLOR = { r = 0.2, g = 0.2, b = 0.2, a = 0.5 }
local chargedComboPointLookup = {}

local function GetPowerColor(powerType)
    if powerType == CUSTOM_POWER_TYPES.Stagger then
        return nil
    end
    local barKey = GetBarKey(powerType)
    return CDM:GetBarSetting(barKey, "color") or CDM_C.WHITE
end

local function IsRogueComboPoints(powerType)
    return resourcesPlayerClass == "ROGUE" and powerType == POWER_TYPES.ComboPoints
end

local function IsFeralOverflowingComboPoints(powerType)
    return resourcesPlayerClass == "DRUID" and currentSpecID == 103 and powerType == POWER_TYPES.ComboPoints
end

local function GetFeralOverflowingColors()
    return cachedComboOverflowingFilled or CDM_C.WHITE,
           cachedComboOverflowingEmpty or CDM_C.WHITE
end

local function GetComboPointChargeColors()
    return cachedComboCharged or CDM_C.WHITE,
           cachedComboChargedEmpty or CDM_C.WHITE
end

local chargedComboPointsDirty = true

local function RefreshChargedComboPointLookup()
    chargedComboPointsDirty = false

    if resourcesPlayerClass ~= "ROGUE" or type(GetUnitChargedPowerPoints) ~= "function" then
        return nil
    end

    local chargedPoints = GetUnitChargedPowerPoints("player")
    if type(chargedPoints) ~= "table" or #chargedPoints == 0 then
        table_wipe(chargedComboPointLookup)
        return nil
    end

    table_wipe(chargedComboPointLookup)

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
    cachedSoulShardReadyColor = GetPowerColor(POWER_TYPES.SoulShards)
    cachedSoulShardRechargingColor = CDM:GetBarSetting("SoulShards", "rechargingColor")
        or cachedSoulShardReadyColor
    cachedComboBaseColor = CDM:GetBarSetting("ComboPoints", "color") or CDM_C.WHITE
    cachedComboOverflowingFilled = CDM:GetBarSetting("ComboPoints", "overflowingColor") or cachedComboBaseColor
    cachedComboOverflowingEmpty = CDM:GetBarSetting("ComboPoints", "overflowingEmptyColor") or cachedComboBaseColor
    cachedComboCharged = CDM:GetBarSetting("ComboPoints", "chargedColor") or cachedComboBaseColor
    cachedComboChargedEmpty = CDM:GetBarSetting("ComboPoints", "chargedEmptyColor") or cachedComboBaseColor
    if CDM._Res and CDM._Res.RefreshTrackerFontCache then
        CDM._Res.RefreshTrackerFontCache()
    end
end

local function GetBarTextures(barKey)
    local barName = CDM:GetBarSetting(barKey, "barTexture") or "Solid"
    local bgName = CDM:GetBarSetting(barKey, "bgTexture") or "Solid"
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

local function RememberPipBaseColor(bar, pipIndex, color)
    if not color then return end
    local t = bar._pipBaseColors
    if not t then t = {}; bar._pipBaseColors = t end
    t[pipIndex] = color
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
    [104] = {POWER_TYPES.Rage, CUSTOM_POWER_TYPES.Ironfur},     -- Guardian Druid
    [577] = POWER_TYPES.Fury,                                   -- Havoc Demon Hunter
    [581] = {POWER_TYPES.Fury, CUSTOM_POWER_TYPES.SoulFragments}, -- Vengeance Demon Hunter
    [1480] = {POWER_TYPES.Fury, CUSTOM_POWER_TYPES.DevourerSoulFragments}, -- Devourer Demon Hunter
    [1467] = POWER_TYPES.Essence,                               -- Devastation Evoker
    [1468] = POWER_TYPES.Essence,                               -- Preservation Evoker
    [1473] = POWER_TYPES.Essence,                               -- Augmentation Evoker
}
CDM.SPEC_POWER_MAP = SPEC_POWER_MAP

-- Per-spec mana defaults: true = enabled by default, false = disabled by default
CDM.MANA_SPECS = {
    -- Paladin
    [65] = true,    -- Holy Paladin
    [66] = false,   -- Protection Paladin
    [70] = false,   -- Retribution Paladin
    -- Priest
    [256] = true,   -- Discipline Priest
    [257] = true,   -- Holy Priest
    [258] = false,  -- Shadow Priest
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

local SPEC_TO_CLASS = {
    [71]="WARRIOR", [72]="WARRIOR", [73]="WARRIOR",
    [65]="PALADIN", [66]="PALADIN", [70]="PALADIN",
    [253]="HUNTER", [254]="HUNTER", [255]="HUNTER",
    [259]="ROGUE", [260]="ROGUE", [261]="ROGUE",
    [256]="PRIEST", [257]="PRIEST", [258]="PRIEST",
    [250]="DEATHKNIGHT", [251]="DEATHKNIGHT", [252]="DEATHKNIGHT",
    [262]="SHAMAN", [263]="SHAMAN", [264]="SHAMAN",
    [62]="MAGE", [63]="MAGE", [64]="MAGE",
    [265]="WARLOCK", [266]="WARLOCK", [267]="WARLOCK",
    [268]="MONK", [269]="MONK", [270]="MONK",
    [102]="DRUID", [103]="DRUID", [104]="DRUID", [105]="DRUID",
    [577]="DEMONHUNTER", [581]="DEMONHUNTER", [1480]="DEMONHUNTER",
    [1467]="EVOKER", [1468]="EVOKER", [1473]="EVOKER",
}

local BAR_SPEC_PEERS_BY_CLASS = {}
local BAR_CAN_USE_MANA_BY_CLASS = {}

local function EnsureSubMap(parent, key)
    local m = parent[key]
    if not m then
        m = {}
        parent[key] = m
    end
    return m
end

for specID, powers in pairs(SPEC_POWER_MAP) do
    local classKey = SPEC_TO_CLASS[specID]
    if classKey then
        local list = type(powers) == "table" and powers or { powers }
        local keys = {}
        for i = 1, #list do
            keys[i] = GetBarKey(list[i])
        end

        local classPeers = EnsureSubMap(BAR_SPEC_PEERS_BY_CLASS, classKey)
        for i = 1, #keys do
            local peers = EnsureSubMap(classPeers, keys[i])
            for j = 1, #keys do
                if i ~= j then peers[keys[j]] = true end
            end
        end

        if CDM.MANA_SPECS[specID] ~= nil then
            local manaMap = EnsureSubMap(BAR_CAN_USE_MANA_BY_CLASS, classKey)
            for i = 1, #keys do
                manaMap[keys[i]] = true
            end
        end
    end
end

CDM.BAR_SPEC_PEERS_BY_CLASS = BAR_SPEC_PEERS_BY_CLASS

function CDM.AreBarKeysSpecCompatible(classKey, a, b)
    if a == b then return false end
    if a == "Mana" then
        local map = BAR_CAN_USE_MANA_BY_CLASS[classKey]
        return map ~= nil and map[b] == true
    end
    if b == "Mana" then
        local map = BAR_CAN_USE_MANA_BY_CLASS[classKey]
        return map ~= nil and map[a] == true
    end
    local classPeers = BAR_SPEC_PEERS_BY_CLASS[classKey]
    if not classPeers then return false end
    local peers = classPeers[a]
    return peers ~= nil and peers[b] == true
end

CDM.resourceBars = {}
CDM.currentPowerTypes = {}
CDM.activeBarKeys = {}
CDM.resourceUnifiedHosts = {}

local DRUID_TRAVEL_FORM_IDS = {[3] = true, [4] = true, [27] = true, [29] = true}
local DRUID_CAT_FORM_ID = 1
local DRUID_BEAR_FORM_ID = 5
local DRUID_FERAL_FORM_IDS = {[DRUID_CAT_FORM_ID] = true, [DRUID_BEAR_FORM_ID] = true}
local function IsEffectivelyMounted()
    return IsMounted()
        or UnitInVehicle("player")
        or DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()]
        or false
end
local function IsInFeralForm()
    return DRUID_FERAL_FORM_IDS[GetShapeshiftFormID()] or false
end
local function GetDruidPrimaryPowerType(specID)
    local formID = GetShapeshiftFormID()
    if formID == DRUID_BEAR_FORM_ID then
        return POWER_TYPES.Rage
    elseif formID == DRUID_CAT_FORM_ID then
        return POWER_TYPES.Energy
    elseif specID == 102 then
        return POWER_TYPES.LunarPower
    end
    return POWER_TYPES.Mana
end
CDM.GetDruidPrimaryPowerType = GetDruidPrimaryPowerType
local loadInCombat = InCombatLockdown() and true or false
local loadIsMounted = IsEffectivelyMounted()
local loadIsFeralForm = IsInFeralForm()

local function EvalLoadConditions(barKey, specID)
    local loadMode = CDM:GetBarSetting(barKey, "loadMode") or "always"
    if loadMode == "always" then return true end
    if loadMode == "never" then return false end

    local ld = CDM:GetBarSetting(barKey, "load")
    if not ld then return true end

    if ld.combat ~= nil and ld.combat ~= loadInCombat then return false end

    if ld.hideMounted and loadIsMounted then return false end

    if ld.hideInFeralForm and loadIsFeralForm then return false end

    if ld.spec and not ld.spec[specID] then return false end

    return true
end

local scratchActiveKeys = {}

local function GetActiveBarKeys()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)
    if not specID or specID == 0 then return nil end

    table_wipe(scratchActiveKeys)

    local manaSpecs = CDM.MANA_SPECS
    if manaSpecs and manaSpecs[specID] ~= nil then
        if EvalLoadConditions("Mana", specID) then
            scratchActiveKeys[#scratchActiveKeys + 1] = "Mana"
        end
    end

    local specPowers = SPEC_POWER_MAP[specID]

    if resourcesPlayerClass == "DRUID" then
        local currentPowerType = GetDruidPrimaryPowerType(specID)
        if currentPowerType == POWER_TYPES.Rage then
            specPowers = specID == 104 and {POWER_TYPES.Rage, CUSTOM_POWER_TYPES.Ironfur} or {POWER_TYPES.Rage}
        elseif currentPowerType == POWER_TYPES.Energy then
            specPowers = {POWER_TYPES.Energy, POWER_TYPES.ComboPoints}
        elseif specID == 102 then
            specPowers = {POWER_TYPES.LunarPower}
        else
            specPowers = nil
        end
    end

    if specPowers then
        local powers = type(specPowers) == "table" and specPowers or {specPowers}
        for _, pt in ipairs(powers) do
            local barKey = GetBarKey(pt)
            if EvalLoadConditions(barKey, specID) then
                scratchActiveKeys[#scratchActiveKeys + 1] = barKey
            end
        end
    end

    return #scratchActiveKeys > 0 and scratchActiveKeys or nil
end

local ANCHOR_TARGET_SCREEN = "screen"
local ANCHOR_TARGET_PLAYER_FRAME = "playerFrame"
local ANCHOR_TARGET_ESSENTIAL = "essential"

local function IsExternalAnchorTarget(anchorTo)
    return anchorTo == ANCHOR_TARGET_PLAYER_FRAME or anchorTo == ANCHOR_TARGET_ESSENTIAL
end

local function ResolveExternalAnchorFrame(anchorTo)
    if anchorTo == ANCHOR_TARGET_ESSENTIAL then
        local containers = CDM.anchorContainers
        local vName = CDM_C.VIEWERS and CDM_C.VIEWERS.ESSENTIAL
        local target = containers and vName and containers[vName]
        if target and target:IsShown() then return target end
    end
    return nil
end

local function BarToBarOffsets(barKey, anchorPoint, targetPoint)
    local spacing = CDM:GetBarSetting(barKey, "barSpacing") or 1
    if anchorPoint == "BOTTOM" and targetPoint == "TOP" then
        return 0, spacing
    elseif anchorPoint == "TOP" and targetPoint == "BOTTOM" then
        return 0, -spacing
    elseif anchorPoint == "LEFT" and targetPoint == "RIGHT" then
        return spacing, 0
    elseif anchorPoint == "RIGHT" and targetPoint == "LEFT" then
        return -spacing, 0
    end
    return 0, spacing
end

local function ResolveAnchorTarget(barKey)
    local anchorTo = CDM:GetBarSetting(barKey, "anchorTo")
    local anchorPoint = CDM:GetBarSetting(barKey, "anchorPoint") or "BOTTOM"
    local targetPoint = CDM:GetBarSetting(barKey, "anchorTargetPoint") or "TOP"
    local offX = CDM:GetBarSetting(barKey, "offsetX") or 0
    local offY = CDM:GetBarSetting(barKey, "offsetY") or -200

    if not anchorTo or anchorTo == ANCHOR_TARGET_SCREEN then
        return UIParent, anchorPoint, targetPoint, offX, offY
    end

    if anchorTo == ANCHOR_TARGET_PLAYER_FRAME then
        return ANCHOR_TARGET_PLAYER_FRAME, anchorPoint, targetPoint, offX, offY
    end

    if anchorTo == ANCHOR_TARGET_ESSENTIAL then
        local target = ResolveExternalAnchorFrame(anchorTo)
        if target then
            return target, anchorPoint, targetPoint, offX, offY
        end
        return UIParent, anchorPoint, targetPoint, offX, offY
    end

    local targetPT = BAR_KEY_TO_POWER_TYPE[anchorTo]
    local targetBar = targetPT and CDM.resourceBars[targetPT]
    if targetBar and targetBar:IsShown() then
        local bx, by = BarToBarOffsets(barKey, anchorPoint, targetPoint)
        return targetBar, anchorPoint, targetPoint, bx, by
    end

    return UIParent, anchorPoint, targetPoint, offX, offY
end

local function IsActiveBarKey(targetKey)
    local keys = CDM.activeBarKeys
    if not keys then return false end
    for i = 1, #keys do
        if keys[i] == targetKey then return true end
    end
    return false
end

local function ResolveEffectiveAnchorKey(barKey)
    while true do
        local anchorTo = CDM:GetBarSetting(barKey, "anchorTo")
        if not anchorTo or anchorTo == ANCHOR_TARGET_SCREEN
           or anchorTo == ANCHOR_TARGET_PLAYER_FRAME
           or anchorTo == ANCHOR_TARGET_ESSENTIAL then
            return barKey
        end
        if IsActiveBarKey(anchorTo) then
            return barKey
        end
        barKey = anchorTo
    end
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

    local bar = CreateFrame("StatusBar", nil, UIParent)
    bar:SetFrameStrata(CDM_C.STRATA_MAIN)
    bar.powerType = powerType
    bar.isPipBar = true
    bar.pips = {}
    bar.barKey = GetBarKey(powerType)

    bar.color = GetPowerColor(powerType) or CDM_C.WHITE

    bar:Hide()

    CDM.resourceBars[powerType] = bar

    if CDM.TAGS and powerType ~= POWER_TYPES.Runes then
        CDM.TAGS:CreateTag(bar, powerType)
    end

    return bar
end

local function SetupPip(pip, bar, texturePath, color, i, pipPositions, pipWidths)
    pip:SetStatusBarTexture(texturePath)
    pip:GetStatusBarTexture():SetHorizTile(false)
    pip:GetStatusBarTexture():SetVertTile(false)
    pip:SetStatusBarColor(color.r, color.g, color.b, color.a)
    local xStart = pipPositions[i]
    pip:ClearAllPoints()
    pip:SetPoint("TOPLEFT", bar, "TOPLEFT", xStart, 0)
    pip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", xStart + pipWidths[i], 0)
    pip:Show()
end

local function CreatePips(bar, maxPips, barWidth, barHeight)
    bar.pips = bar.pips or {}
    bar.separators = bar.separators or {}
    bar.pipPositions = bar.pipPositions or {}
    bar.pipBoundaryPixels = bar.pipBoundaryPixels or {}

    local color = bar.color

    local borderColor = (CDM.db and CDM.db.borderColor) or (CDM.defaults and CDM.defaults.borderColor) or CDM_C.WHITE

    local bgColor = (bar.barKey and CDM:GetBarSetting(bar.barKey, "bgColor")) or DEFAULT_BG_COLOR

    if maxPips <= 0 then return end
    local _, barPixels, onePixel = SnapWidthToPixelGrid(bar, barWidth)

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

    local barTexturePath, bgTexturePath = GetBarTextures(bar.barKey)

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
            SetupPip(pip, bar, barTexturePath, color, i, bar.pipPositions, pipWidths)

            if pip.timerText then
                pip.timerText:ClearAllPoints()
                pip.timerText:SetPoint("CENTER", pip.timerFrame, "CENTER", 0, 0)
            end
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
            SetupPip(pip, bar, barTexturePath, color, i, bar.pipPositions, pipWidths)
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

            SetupPip(pip, bar, barTexturePath, color, i, bar.pipPositions, pipWidths)

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

    bar.activePipCount = maxPips

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
        if not bar.separators[i] then
            bar.separators[i] = Pixel.CreateSolidTexture(bar.separatorOverlay, "OVERLAY", 7)
        end
        PositionSeparatorAt(bar, i, borderColor)
    end

    HideBarPipSeparators(bar, maxPips)
end

local function CreateBar(powerType)
    if UsesPips(powerType) then
        return CreatePipBar(powerType)
    end

    if CDM.resourceBars[powerType] then
        return CDM.resourceBars[powerType]
    end

    local bar = CreateFrame("StatusBar", nil, UIParent)
    bar:SetFrameStrata(CDM_C.STRATA_MAIN)

    local barTexturePath, bgTexturePath = GetBarTextures(GetBarKey(powerType))
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
        color = CDM:GetBarSetting("Stagger", "lightColor") or { r = 0.52, g = 0.90, b = 0.52, a = 1 }
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
    local barKey = GetBarKey(powerType)
    local bgColor = CDM:GetBarSetting(barKey, "bgColor") or DEFAULT_BG_COLOR
    bg:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    bar.bg = bg
    bar.barKey = barKey

    if not bar.borderFrame then
        bar.borderFrame = CreateFrame("Frame", nil, bar)
        bar.borderFrame:SetAllPoints()
    end

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(bar.borderFrame)
    end

    bar:Hide()

    CDM.resourceBars[powerType] = bar

    if CDM.TAGS and not bar.isPipBar then
        CDM.TAGS:CreateTag(bar, powerType)
    end

    return bar
end

local function EnsurePerBarBorder(bar, borderColor)
    if not bar.borderFrame then
        bar.borderFrame = CreateFrame("Frame", nil, bar)
        bar.borderFrame:SetAllPoints()
    end
    bar.borderFrame:Show()

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(bar.borderFrame)
        if bar.borderFrame.border then
            bar.borderFrame.border:SetBackdropBorderColor(
                borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        end
    end
end

local function RefreshPipSeparators(bar, borderColor)
    if not IsPipSeparatorBar(bar) then return end
    HideBarSeparatorFill(bar)
    local activeSeps = math_max(0, (bar.activePipCount or 0) - 1)
    for i = 1, activeSeps do
        PositionSeparatorAt(bar, i, borderColor)
    end
    HideBarPipSeparators(bar, activeSeps + 1)
end

local UNIFIED_HSEPARATOR_TEXTURE = "Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Separator"
local UNIFIED_VSEPARATOR_TEXTURE = "Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\vSeparator"
local UNIFIED_HSEPARATOR_HEIGHT = 16
local UNIFIED_VSEPARATOR_WIDTH = 16
local UNIFIED_VSEPARATOR_HEIGHT = 10

local function EnsureChainHost(hostIndex)
    local entry = CDM.resourceUnifiedHosts[hostIndex]
    if entry then return entry end
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetFrameStrata(CDM_C.STRATA_MAIN)
    entry = { host = host, hSeparators = {} }
    CDM.resourceUnifiedHosts[hostIndex] = entry
    return entry
end

local function HideChainHost(entry)
    if not entry then return end
    entry.host:Hide()
    if entry.hSeparators then
        for _, sep in ipairs(entry.hSeparators) do
            sep:Hide()
        end
    end
end

local function HideAllChainHosts()
    for i = 1, #CDM.resourceUnifiedHosts do
        HideChainHost(CDM.resourceUnifiedHosts[i])
    end
end

local function HideBarUnifiedVerticalSeparators(bar)
    if bar and bar.unifiedVerticalSeparators then
        for _, sep in ipairs(bar.unifiedVerticalSeparators) do
            sep:Hide()
        end
    end
end

local function ApplyUnifiedVerticalSeparators(bar, borderColor)
    if not (bar and bar.isPipBar and bar.pipPositions) then
        HideBarUnifiedVerticalSeparators(bar)
        return
    end

    bar.unifiedVerticalSeparators = bar.unifiedVerticalSeparators or {}

    local visiblePips = bar.activePipCount or 0
    if visiblePips < 2 then
        HideBarUnifiedVerticalSeparators(bar)
        return
    end

    local pipWidths = bar.pipWidths
    local fallbackPipWidth = bar.pipWidth or (bar.pips[1] and bar.pips[1]:GetWidth() or 0)
    local twoPixels = Pixel.GetSize() * 2

    for i = 1, visiblePips - 1 do
        local sep = bar.unifiedVerticalSeparators[i]
        if not sep then
            sep = CreateFrame("Frame", nil, bar)
            sep:SetFrameStrata(CDM_C.STRATA_MAIN)
            local tex = sep:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetTexture(UNIFIED_VSEPARATOR_TEXTURE)
            tex:SetAllPoints()
            ConfigurePixelTexture(tex)
            sep.texture = tex
            bar.unifiedVerticalSeparators[i] = sep
        end
        sep:SetParent(bar)
        sep:SetFrameLevel(bar:GetFrameLevel() + 1)
        sep:SetSize(UNIFIED_VSEPARATOR_WIDTH, UNIFIED_VSEPARATOR_HEIGHT)
        sep.texture:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)

        local pw = (pipWidths and pipWidths[i]) or fallbackPipWidth
        local boundary = bar.pipPositions[i] + pw
        local xOffset = Snap(math_floor((boundary - 2) / twoPixels + 0.5) * twoPixels)

        sep:ClearAllPoints()
        sep:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", xOffset, -1)
        sep:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, 0)
        sep:Show()
    end

    for i = visiblePips, #bar.unifiedVerticalSeparators do
        bar.unifiedVerticalSeparators[i]:Hide()
    end
end

local function ApplyChainHorizontalSeparator(entry, index, lowerBar, borderColor)
    local sep = entry.hSeparators[index]
    if not sep then
        sep = CreateFrame("Frame", nil, entry.host)
        sep:SetIgnoreParentAlpha(true)
        local tex = sep:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(UNIFIED_HSEPARATOR_TEXTURE)
        Pixel.DisableTextureSnap(tex)
        tex:SetAllPoints()
        sep.texture = tex
        entry.hSeparators[index] = sep
    end
    sep:SetHeight(UNIFIED_HSEPARATOR_HEIGHT)
    sep:ClearAllPoints()
    sep:SetPoint("TOPRIGHT", lowerBar, "TOPRIGHT", 0, 4)
    sep:SetPoint("LEFT", lowerBar, "LEFT", 0, 0)
    sep.texture:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    sep:Show()
end

local function ApplyUnifiedChain(hostIndex, chain, borderColor)
    local entry = EnsureChainHost(hostIndex)
    local host = entry.host

    host:ClearAllPoints()
    host:SetPoint("BOTTOMLEFT", chain[1], "BOTTOMLEFT", 0, 0)
    host:SetPoint("TOPRIGHT", chain[#chain], "TOPRIGHT", 0, 0)
    host:SetFrameLevel((chain[1]:GetFrameLevel() or 0) + 1)
    host:Show()

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(host)
        if host.border then
            host.border:SetBackdropBorderColor(
                borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        end
    end

    for i = 1, #chain - 1 do
        ApplyChainHorizontalSeparator(entry, i, chain[i], borderColor)
    end
    for i = #chain, #entry.hSeparators do
        entry.hSeparators[i]:Hide()
    end

    for _, bar in ipairs(chain) do
        if bar.borderFrame then bar.borderFrame:Hide() end
        HidePipBarDecorations(bar)
        ApplyUnifiedVerticalSeparators(bar, borderColor)
    end
end

local function IsVerticalAnchor(anchorPoint, targetPoint)
    return (anchorPoint == "BOTTOM" and targetPoint == "TOP")
end

local scratchParentOf = {}
local scratchChildrenOf = {}
local scratchActiveSet = {}
local scratchChains = {}

local function BuildChains(activeKeys)
    for k in pairs(scratchParentOf) do scratchParentOf[k] = nil end
    for k, v in pairs(scratchChildrenOf) do
        table_wipe(v)
        scratchChildrenOf[k] = nil
    end
    for k in pairs(scratchActiveSet) do scratchActiveSet[k] = nil end
    for i = 1, #scratchChains do
        table_wipe(scratchChains[i])
        scratchChains[i] = nil
    end

    for _, barKey in ipairs(activeKeys) do
        local pt = BAR_KEY_TO_POWER_TYPE[barKey]
        local bar = pt and CDM.resourceBars[pt]
        if bar and bar:IsShown() then
            scratchActiveSet[barKey] = bar
        end
    end

    for barKey in pairs(scratchActiveSet) do
        local anchorTo = CDM:GetBarSetting(barKey, "anchorTo")
        if anchorTo and scratchActiveSet[anchorTo] then
            local aP = CDM:GetBarSetting(barKey, "anchorPoint") or "BOTTOM"
            local tP = CDM:GetBarSetting(barKey, "anchorTargetPoint") or "TOP"
            if IsVerticalAnchor(aP, tP) then
                scratchParentOf[barKey] = anchorTo
                local children = scratchChildrenOf[anchorTo]
                if not children then
                    children = {}
                    scratchChildrenOf[anchorTo] = children
                end
                children[#children + 1] = barKey
            end
        end
    end

    local chainCount = 0
    local visited = {}
    for barKey, bar in pairs(scratchActiveSet) do
        if not scratchParentOf[barKey] then
            chainCount = chainCount + 1
            local chain = {}
            chain[1] = bar
            visited[barKey] = true
            local current = barKey
            while true do
                local kids = scratchChildrenOf[current]
                if not kids or #kids == 0 then break end
                local nextKey = kids[1]
                if visited[nextKey] then break end
                chain[#chain + 1] = scratchActiveSet[nextKey]
                visited[nextKey] = true
                current = nextKey
            end
            scratchChains[chainCount] = chain
        end
    end

    for barKey, bar in pairs(scratchActiveSet) do
        if not visited[barKey] then
            chainCount = chainCount + 1
            scratchChains[chainCount] = { bar }
            visited[barKey] = true
        end
    end

    return scratchChains, chainCount
end

local function UpdateBorders(activeKeys)
    local borderColor = (CDM.db and CDM.db.borderColor) or (CDM.defaults and CDM.defaults.borderColor) or CDM_C.WHITE
    local unified = CDM.db and CDM.db.unifiedBorder == true

    local chains, chainCount = BuildChains(activeKeys)

    local hostIdx = 0
    for c = 1, chainCount do
        local chain = chains[c]
        if unified then
            hostIdx = hostIdx + 1
            ApplyUnifiedChain(hostIdx, chain, borderColor)
        else
            for _, bar in ipairs(chain) do
                EnsurePerBarBorder(bar, borderColor)
                RefreshPipSeparators(bar, borderColor)
                HideBarUnifiedVerticalSeparators(bar)
            end
        end
    end

    for i = hostIdx + 1, #CDM.resourceUnifiedHosts do
        HideChainHost(CDM.resourceUnifiedHosts[i])
    end
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
            SetStatusBarColorIfChanged(pip, readyColor)
            RememberPipBaseColor(bar, i, readyColor)
        elseif i == wholePart + 1 and fractionalPart > 0 then
            pip:SetValue(fractionalPart, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, rechargingColor)
            RememberPipBaseColor(bar, i, rechargingColor)
        else
            pip:SetValue(0, Enum.StatusBarInterpolation.Immediate)
            SetStatusBarColorIfChanged(pip, rechargingColor)
            RememberPipBaseColor(bar, i, rechargingColor)
        end
    end
end


UpdateBarValue = function(powerType)
    local bar = CDM.resourceBars[powerType]
    if not bar or not bar:IsShown() then
        return
    end

    local current, max

    if powerType == CUSTOM_POWER_TYPES.SoulFragments then
        current = GetSpellCastCount(CDM_C.SOUL_CLEAVE_SPELL_ID) or 0
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
            if CDM._Res.ApplyPipConditions then CDM._Res.ApplyPipConditions(bar, powerType, current, max) end
            CDM._Res.UpdateTagTextForPowerType(powerType)
            return
        elseif powerType == POWER_TYPES.SoulShards then
            ApplySoulShardStates(bar)
            if CDM._Res.ApplyPipConditions then CDM._Res.ApplyPipConditions(bar, powerType, current, max) end
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
                    RememberPipBaseColor(bar, i, chargedFilledColor)
                else
                    SetStatusBarColorIfChanged(pip, bar.color)
                    RememberPipBaseColor(bar, i, bar.color)
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
                RememberPipBaseColor(bar, i, bar.color)
                local overlay = bar.comboChargeEmptyOverlays[i]
                if overlay then overlay:Hide() end
            end
        end

        if bar.comboChargeEmptyOverlays then
            for i = (#bar.pips + 1), #bar.comboChargeEmptyOverlays do
                bar.comboChargeEmptyOverlays[i]:Hide()
            end
        end
        if CDM._Res.ApplyPipConditions then CDM._Res.ApplyPipConditions(bar, powerType, current, max) end
    else
        bar:SetMinMaxValues(0, max)
        bar:SetValue(current, bar._smoothBars and Enum.StatusBarInterpolation.ExponentialEaseOut
                                               or Enum.StatusBarInterpolation.Immediate)
        if CDM._Res.ApplyBarConditions then CDM._Res.ApplyBarConditions(bar, powerType, current, max) end
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
    ApplyPipTexturesIfChanged(bar, barTexturePath)
    ApplyBarBackground(bar, bgTexturePath, bgColor)

    if powerType == POWER_TYPES.Runes then
        CDM._Res.UpdateRuneCooldowns(bar)
    elseif powerType == POWER_TYPES.Essence then
        CDM._Res.UpdateEssenceCooldowns(bar)
    elseif powerType == POWER_TYPES.SoulShards then
        ApplySoulShardStates(bar)
    else
        local color = bar.color
        if color then
            for i, pip in ipairs(bar.pips) do
                SetStatusBarColorIfChanged(pip, color)
                RememberPipBaseColor(bar, i, color)
            end
        end
    end
end

local visiblePowerTypes = {}
local function HideInactiveResourceBars(powerTypes)
    table_wipe(visiblePowerTypes)
    for i = 1, #powerTypes do
        visiblePowerTypes[powerTypes[i]] = true
    end

    for powerType, bar in pairs(CDM.resourceBars) do
        if not visiblePowerTypes[powerType] then
            bar:Hide()
            if bar.borderFrame then
                bar.borderFrame:Hide()
            end
            HideBarUnifiedVerticalSeparators(bar)
        end
    end

    table_wipe(visiblePowerTypes)
end

local function HideAllResourceBars()
    for _, bar in pairs(CDM.resourceBars) do
        bar:Hide()
        if bar.borderFrame then
            bar.borderFrame:Hide()
        end
        HideBarUnifiedVerticalSeparators(bar)
    end
    HideAllChainHosts()
end

local function EnsurePrimaryBarPositioned(activeKeys)
    local primaryPT = cachedPrimaryPowerType or UnitPowerType("player")
    if not primaryPT then return end
    local primaryBarKey = POWER_TYPE_TO_BAR_KEY[primaryPT]
    if not primaryBarKey then return end
    for i = 1, #activeKeys do
        if activeKeys[i] == primaryBarKey then return end
    end

    local bar = CreateBar(primaryPT)
    if not bar then return end

    local barHeight = Snap(CDM:GetBarSetting(primaryBarKey, "height") or 16)
    local barWidth = CDM:GetBarSetting(primaryBarKey, "width") or 0
    if barWidth == 0 and CDM.CalculateEssentialRow1Width then
        barWidth = CDM.CalculateEssentialRow1Width()
    end
    if barWidth == 0 then barWidth = 200 end
    barWidth = SnapWidthToPixelGrid(bar, barWidth)
    bar:SetSize(barWidth, barHeight)

    local effectiveKey = ResolveEffectiveAnchorKey(primaryBarKey)
    local anchorTo = CDM:GetBarSetting(effectiveKey, "anchorTo")
    bar:ClearAllPoints()
    if not anchorTo or anchorTo == ANCHOR_TARGET_SCREEN then
        local offX = CDM:GetBarSetting(effectiveKey, "offsetX") or 0
        local offY = CDM:GetBarSetting(effectiveKey, "offsetY") or -200
        local halfW = Pixel.HalfFloor(bar:GetWidth() or 0)
        Pixel.SetPoint(bar, "BOTTOMLEFT", UIParent, "CENTER", offX - halfW, offY)
    else
        local target, aP, tP, oX, oY = ResolveAnchorTarget(effectiveKey)
        if target == ANCHOR_TARGET_PLAYER_FRAME then
            CDM.AnchorToPlayerFrame(bar, tP, oX, oY, "Resources_" .. primaryBarKey, true, aP)
        elseif target and not (target == UIParent and IsExternalAnchorTarget(anchorTo)) then
            bar:SetPoint(aP, target, tP, oX, oY)
        else
            local offX = CDM:GetBarSetting(effectiveKey, "offsetX") or 0
            local offY = CDM:GetBarSetting(effectiveKey, "offsetY") or -200
            local halfW = Pixel.HalfFloor(bar:GetWidth() or 0)
            Pixel.SetPoint(bar, "BOTTOMLEFT", UIParent, "CENTER", offX - halfW, offY)
        end
    end
end

local function UpdateBarPositions()
    local activeKeys = GetActiveBarKeys()

    if not activeKeys or #activeKeys == 0 then
        table_wipe(CDM.currentPowerTypes)
        table_wipe(CDM.activeBarKeys)
        HideAllResourceBars()
        EnsurePrimaryBarPositioned(CDM.activeBarKeys)
        return
    end

    table_wipe(CDM.currentPowerTypes)
    table_wipe(CDM.activeBarKeys)
    for i, barKey in ipairs(activeKeys) do
        CDM.activeBarKeys[i] = barKey
        CDM.currentPowerTypes[i] = BAR_KEY_TO_POWER_TYPE[barKey]
    end

    local borderColor = (CDM.db and CDM.db.borderColor) or (CDM.defaults and CDM.defaults.borderColor) or CDM_C.WHITE

    for _, barKey in ipairs(activeKeys) do
        local powerType = BAR_KEY_TO_POWER_TYPE[barKey]
        local bar = CreateBar(powerType)
        bar.barKey = barKey
        bar._smoothBars = SMOOTH_ELIGIBLE_BARS[barKey]
            and CDM:GetBarSetting(barKey, "smoothBars") ~= false

        local barHeight = Snap(CDM:GetBarSetting(barKey, "height") or 16)
        local barWidth = CDM:GetBarSetting(barKey, "width") or 0
        if barWidth == 0 and CDM.CalculateEssentialRow1Width then
            barWidth = CDM.CalculateEssentialRow1Width()
        end
        if barWidth == 0 then barWidth = 200 end
        barWidth = SnapWidthToPixelGrid(bar, barWidth)

        local barTexturePath, bgTexturePath = GetBarTextures(barKey)
        local bgColor = CDM:GetBarSetting(barKey, "bgColor") or DEFAULT_BG_COLOR

        if bar.isPipBar then
            local max = GetPipBarMax(powerType)
            if max and max > 0 then
                bar:SetSize(barWidth, barHeight)
                local needsRecreate = ((bar.activePipCount or 0) ~= max) or
                    (bar.lastBarWidth ~= barWidth) or (bar.lastBarHeight ~= barHeight)
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
            if color then SetStatusBarColorIfChanged(bar, color) end
            if bar.bg then
                SetTextureIfChanged(bar.bg, bgTexturePath)
                SetVertexColorIfChanged(bar.bg, bgColor)
            end
        end

        local effectiveKey = ResolveEffectiveAnchorKey(barKey)
        local anchorTo = CDM:GetBarSetting(effectiveKey, "anchorTo")

        bar:ClearAllPoints()
        if not anchorTo or anchorTo == ANCHOR_TARGET_SCREEN then
            local offX = CDM:GetBarSetting(effectiveKey, "offsetX") or 0
            local offY = CDM:GetBarSetting(effectiveKey, "offsetY") or -200
            local halfW = Pixel.HalfFloor(bar:GetWidth() or 0)
            Pixel.SetPoint(bar, "BOTTOMLEFT", UIParent, "CENTER", offX - halfW, offY)
            bar:Show()
        else
            local target, aP, tP, oX, oY = ResolveAnchorTarget(effectiveKey)
            if target == UIParent and IsExternalAnchorTarget(anchorTo) then
                bar:Hide()
            else
                if target == ANCHOR_TARGET_PLAYER_FRAME then
                    CDM.AnchorToPlayerFrame(bar, tP, oX, oY, "Resources_" .. barKey, true, aP)
                else
                    bar:SetPoint(aP, target, tP, oX, oY)
                end
                bar:Show()
            end
        end

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

    UpdateBorders(activeKeys)
    HideInactiveResourceBars(CDM.currentPowerTypes)
    EnsurePrimaryBarPositioned(activeKeys)
end

function CDM:UpdateResources()
    if not isEnabled then
        return
    end

    if currentSpecID == 104 then
        CDM._Res.RefreshIronfurTalents()
    end

    if currentSpecID == 73 and CDM._Res.RefreshIgnorePainVisibility then
        CDM._Res.RefreshIgnorePainVisibility()
    end

    if resourcesPlayerClass == "DRUID" then
        cachedPrimaryPowerType = GetDruidPrimaryPowerType(currentSpecID)
    else
        cachedPrimaryPowerType = UnitPowerType("player")
    end
    RefreshCachedFontStyles()
    UpdateBarPositions()
    CDM._Res.RefreshCachedRuneTimerSlot()
    self:UpdateResourceValues()

    if CDM.TAGS and CDM.TAGS.styleDirty and CDM.TAGS.UpdateAllTags then
        CDM.TAGS:UpdateAllTags()
    end
end

function CDM:UpdateResourceValues()
    if not isEnabled then return end
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

local SPEC_TRACKER_TOGGLES = {
    [581]  = { "EnableVengeanceSoulTracking",    "DisableVengeanceSoulTracking" },
    [268]  = { "EnableBrewmasterTracking",       "DisableBrewmasterTracking" },
    [263]  = { "EnableMaelstromTracking",        "DisableMaelstromTracking" },
    [103]  = { "EnableFeralOverflowingTracking", "DisableFeralOverflowingTracking" },
    [255]  = { "EnableTipOfTheSpearTracking",    "DisableTipOfTheSpearTracking" },
    [1480] = { "EnableDevourerTracking",         "DisableDevourerTracking" },
}

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

    for specID, fns in pairs(SPEC_TRACKER_TOGGLES) do
        if newSpecID == specID then
            if currentSpecID ~= specID then CDM._Res[fns[1]]() end
        elseif currentSpecID == specID then
            CDM._Res[fns[2]]()
        end
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

local function ActiveKeysEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function ReevaluateLoadOnEvent()
    local newKeys = GetActiveBarKeys()
    local cur = CDM.activeBarKeys
    if newKeys == nil and (not cur or #cur == 0) then return end
    if newKeys and cur and ActiveKeysEqual(newKeys, cur) then return end
    UpdateBarPositions()
    UpdateAncillaryLayouts()
end

local function OnUpdateShapeshiftForm()
    if resourcesPlayerClass == "DRUID" then
        cachedPrimaryPowerType = GetDruidPrimaryPowerType(currentSpecID)
    else
        cachedPrimaryPowerType = UnitPowerType("player")
    end
    loadIsMounted = IsEffectivelyMounted()
    loadIsFeralForm = IsInFeralForm()

    if currentSpecID == 104 and CDM._Res.OnShapeshiftGuardianCheck then
        CDM._Res.OnShapeshiftGuardianCheck(cachedPrimaryPowerType)
    end

    CDM:UpdateResources()
    UpdateAncillaryLayouts()
end

local function OnMountDisplayChanged()
    local wasMounted = loadIsMounted
    loadIsMounted = IsEffectivelyMounted()
    if loadIsMounted ~= wasMounted then
        ReevaluateLoadOnEvent()
    end
end

local function OnLoadCombatStateChanged(isInCombat)
    loadInCombat = isInCombat and true or false
    ReevaluateLoadOnEvent()
end

local function OnVehicleStateChanged()
    loadIsMounted = IsEffectivelyMounted()
    ReevaluateLoadOnEvent()
end

local function OnUnitMaxPower()
    UpdateBarPositions()
    UpdateAncillaryLayouts()
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

local loadCombatRegistered = false
local loadMountRegistered = false

local function ScanLoadConditions()
    local needsCombat, needsMount = false, false
    local rbs = CDM.db and CDM.db.resourceBarSettings
    if not rbs then return needsCombat, needsMount end

    local function ScanGroup(group)
        if type(group) ~= "table" then return end
        for _, entry in pairs(group) do
            if type(entry) == "table" and entry.loadMode == "conditional" and entry.load then
                if entry.load.combat ~= nil then needsCombat = true end
                if entry.load.hideMounted then needsMount = true end
            end
        end
    end

    ScanGroup(rbs[resourcesPlayerClass])
    ScanGroup(rbs["General"])
    return needsCombat, needsMount
end

local function RegisterLoadEvents()
    local needsCombat, needsMount = ScanLoadConditions()

    if needsCombat and not loadCombatRegistered then
        loadInCombat = InCombatLockdown() and true or false
        CDM:RegisterCombatStateHandler(OnLoadCombatStateChanged)
        loadCombatRegistered = true
    elseif not needsCombat and loadCombatRegistered then
        CDM:UnregisterCombatStateHandler(OnLoadCombatStateChanged)
        loadCombatRegistered = false
    end

    if needsMount and not loadMountRegistered then
        RegisterResEvent("PLAYER_MOUNT_DISPLAY_CHANGED", OnMountDisplayChanged)
        RegisterResUnitEvent("UNIT_ENTERED_VEHICLE", "player", OnVehicleStateChanged)
        RegisterResUnitEvent("UNIT_EXITED_VEHICLE", "player", OnVehicleStateChanged)
        loadMountRegistered = true
    elseif not needsMount and loadMountRegistered then
        UnregisterResEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
        UnregisterResEvent("UNIT_ENTERED_VEHICLE")
        UnregisterResEvent("UNIT_EXITED_VEHICLE")
        loadMountRegistered = false
    end
end

local function UnregisterLoadEvents()
    if loadCombatRegistered then
        CDM:UnregisterCombatStateHandler(OnLoadCombatStateChanged)
        loadCombatRegistered = false
    end
    if loadMountRegistered then
        UnregisterResEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
        UnregisterResEvent("UNIT_ENTERED_VEHICLE")
        UnregisterResEvent("UNIT_EXITED_VEHICLE")
        loadMountRegistered = false
    end
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
    RegisterLoadEvents()
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
    UnregisterLoadEvents()
end

function CDM:InitializeResources()
    if isInitialized then return end

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
    HideAllResourceBars()
    currentSpecID = nil
    cachedPrimaryPowerType = nil
    isEnabled = false
end

local function RefreshResourcesLifecycle()
    if not isEnabled then return end
    RegisterLoadEvents()
    CDM:UpdateResources()
end

local function OnResourcesProfileApplied()
    cachedSoulShardReadyColor = nil
    cachedSoulShardRechargingColor = nil
    cachedComboBaseColor = nil
    cachedComboOverflowingFilled = nil
    cachedComboOverflowingEmpty = nil
    cachedComboCharged = nil
    cachedComboChargedEmpty = nil
    CDM._conditionsVersion = (CDM._conditionsVersion or 0) + 1
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

local COPY_BAR_WHITELIST_ALWAYS = {
    "height", "width",
    "barTexture", "bgTexture",
    "tagEnabled", "tagFontSize", "tagAnchor", "tagOffsetX", "tagOffsetY",
}

local COPY_BAR_WHITELIST_POSITIONING = {
    "anchorPoint", "anchorTargetPoint", "offsetX", "offsetY",
}

local COPY_BAR_FREE_ANCHORS = {
    screen       = true,
    playerFrame  = true,
    essential    = true,
}

local function CopyBarSettingsSharesFreeAnchor(srcAnchorTo, dstAnchorTo)
    local src = srcAnchorTo or "screen"
    local dst = dstAnchorTo or "screen"
    if src ~= dst then return false end
    return COPY_BAR_FREE_ANCHORS[src] == true
end

local function CopyBarSettings(sourceClassKey, sourceBarKey, destClassKey, destBarKey)
    if not sourceClassKey or not sourceBarKey or not destClassKey or not destBarKey then
        return
    end
    if sourceClassKey == destClassKey and sourceBarKey == destBarKey then
        return
    end

    for _, key in ipairs(COPY_BAR_WHITELIST_ALWAYS) do
        local value = CDM:GetBarSettingForClass(sourceClassKey, sourceBarKey, key)
        CDM:SetBarSettingForClass(destClassKey, destBarKey, key, value)
    end

    local srcAnchorTo = CDM:GetBarSettingForClass(sourceClassKey, sourceBarKey, "anchorTo")
    local dstAnchorTo = CDM:GetBarSettingForClass(destClassKey, destBarKey, "anchorTo")
    if CopyBarSettingsSharesFreeAnchor(srcAnchorTo, dstAnchorTo) then
        for _, key in ipairs(COPY_BAR_WHITELIST_POSITIONING) do
            local value = CDM:GetBarSettingForClass(sourceClassKey, sourceBarKey, key)
            CDM:SetBarSettingForClass(destClassKey, destBarKey, key, value)
        end
    end

    if CDM.OnResourcesProfileApplied then
        CDM.OnResourcesProfileApplied()
    end
    if CDM.API and CDM.API.Refresh then
        CDM.API:Refresh("RESOURCES", "LAYOUT")
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
    DEFAULT_BG_COLOR           = DEFAULT_BG_COLOR,
    MAX_MAELSTROM_WEAPON       = MAX_MAELSTROM_WEAPON,
    MAX_TIP_OF_THE_SPEAR       = MAX_TIP_OF_THE_SPEAR,
    GetCurrentSpecID           = function() return currentSpecID end,
    GetIsEnabled               = function() return isEnabled end,
    RegisterResEvent           = RegisterResEvent,
    UnregisterResEvent         = UnregisterResEvent,
    RegisterResUnitEvent       = RegisterResUnitEvent,
    UnregisterResUnitEvent     = UnregisterResUnitEvent,
}

CDM.ReconcileResources = ReconcileResources
CDM.OnResourcesProfileApplied = OnResourcesProfileApplied
CDM.CopyBarSettings = CopyBarSettings

