local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local BORDER = CDM.BORDER
local LSM = LibStub("LibSharedMedia-3.0", true)
local CDM_C = CDM.CONST

local IsSafeNumber = CDM.IsSafeNumber
local GetColorForSpellID = CDM.GetColorForSpellID
local GetBaseSpellID = CDM.GetBaseSpellID
local GetSpellIDCandidates = CDM.GetSpellIDCandidates

local math_floor = math.floor
local math_max = math.max
local math_abs = math.abs
local GetTime = GetTime
local canaccessvalue = canaccessvalue
local select = select
local ipairs = ipairs
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell.GetSpellChargeDuration
local TruncateWhenZero = C_StringUtil.TruncateWhenZero
local GetConfigValue = CDM_C.GetConfigValue
local DesaturationCurve = CDM_C.DesaturationCurve
local RealTime = Enum.DurationTimeModifier.RealTime
local EvaluateColorValueFromBoolean = C_CurveUtil.EvaluateColorValueFromBoolean

local VIEWERS = CDM_C.VIEWERS
local VIEWERS_WITH_OVERRIDE = CDM_C.VIEWERS_WITH_OVERRIDE
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local FontSize = Pixel.FontSize
local SetPoint = Pixel.SetPoint
local DisableTextureSnap = Pixel.DisableTextureSnap

local VIEWER_DESC = {
    [VIEWERS.ESSENTIAL] = {
        sizeKey      = "sizeEssRow1",
        sizeKey2     = "sizeEssRow2",
        cdFontKey    = "cooldownFontSize",
        cdFontKey2   = "essRow2CooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "chargeFontSize",
        chargeKey2   = "essRow2ChargeFontSize",
        chargeColorKey = "chargeColor",
        chargePosKey  = "chargePosition",
        chargeOXKey   = "chargeOffsetX",
        chargeOYKey   = "chargeOffsetY",
        chargeColorKey2 = "essRow2ChargeColor",
        chargePosKey2 = "essRow2ChargePosition",
        chargeOXKey2  = "essRow2ChargeOffsetX",
        chargeOYKey2  = "essRow2ChargeOffsetY",
        isCooldown   = true,
        hasOverride  = true,
        hasKeybind   = true,
        hookType     = "cooldown",
    },
    [VIEWERS.UTILITY] = {
        sizeKey      = "sizeUtility",
        cdFontKey    = "utilityCooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "utilityChargeFontSize",
        chargeColorKey = "utilityChargeColor",
        chargePosKey  = "utilityChargePosition",
        chargeOXKey   = "utilityChargeOffsetX",
        chargeOYKey   = "utilityChargeOffsetY",
        isCooldown   = true,
        hasOverride  = true,
        hasKeybind   = true,
        hookType     = "cooldown",
        hasUtilVisibility = true,
    },
    [VIEWERS.BUFF] = {
        sizeKey      = "sizeBuff",
        cdFontKey    = "buffCooldownFontSize",
        cdColorKey   = "buffCooldownColor",
        isBuff       = true,
        hasCount     = true,
        hookType     = "buff",
    },
    [VIEWERS.BUFF_BAR] = {
        hookType     = "bar",
    },
}

function CDM.RegisterViewerDesc(name, desc)
    VIEWER_DESC[name] = desc
end

local function ResolveIconSize(desc, row)
    local d = CDM.defaults
    if desc.widthKey then
        return GetConfigValue(desc.widthKey, d[desc.widthKey]),
               GetConfigValue(desc.heightKey, d[desc.heightKey])
    end
    local key = (desc.sizeKey2 and row == 2) and desc.sizeKey2 or desc.sizeKey
    local size = GetConfigValue(key, d[key])
    return size.w, size.h
end

local function GetAspectPreservingTexCoord(frameW, frameH, zoomPadding)
    if not frameH or frameH <= 0 then return 0, 1, 0, 1 end
    local padding = zoomPadding or 0
    local texWidth = 1 - (padding * 2)

    local aspectRatio = frameW / frameH
    local xRatio = aspectRatio < 1 and aspectRatio or 1
    local yRatio = aspectRatio > 1 and 1 / aspectRatio or 1

    local left   = -0.5 * texWidth * xRatio + 0.5
    local right  =  0.5 * texWidth * xRatio + 0.5
    local top    = -0.5 * texWidth * yRatio + 0.5
    local bottom =  0.5 * texWidth * yRatio + 0.5

    return left, right, top, bottom
end

function CDM_C.ApplyIconTexCoord(texture, zoomAmount, frameW, frameH)
    if not texture or not texture.SetTexCoord then return end
    local padding = (type(zoomAmount) == "number") and zoomAmount or 0
    if frameW and frameH and frameW > 0 and frameH > 0 then
        local left, right, top, bottom = GetAspectPreservingTexCoord(frameW, frameH, padding)
        texture:SetTexCoord(left, right, top, bottom)
    elseif padding > 0 then
        texture:SetTexCoord(padding, 1 - padding, padding, 1 - padding)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local styleCache = {}
local lastStyleCacheVersion = -1

function CDM_C.GetEffectiveZoomAmount()
    if not styleCache.zoomIcons then return 0 end
    local v = styleCache.zoomAmount
    return (type(v) == "number") and v or 0.08
end

local cdFont = _G["AyijeCDM_CDFont"] or CreateFont("AyijeCDM_CDFont")
local cdFontBuff = _G["AyijeCDM_CDFont_Buff"] or CreateFont("AyijeCDM_CDFont_Buff")
local BLIZZARD_ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local BLIZZARD_ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local BLIZZARD_ICON_OVERLAY_TEXTURE_FILE_ID = 6707800
local DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

local function CfgValue(db, defaults, key, fallback)
    if db and db[key] ~= nil then return db[key] end
    if defaults[key] ~= nil then return defaults[key] end
    return fallback
end

local function RefreshStyleCache()
    local targetVersion = CDM.styleCacheVersion or 0
    if lastStyleCacheVersion == targetVersion then return end
    lastStyleCacheVersion = targetVersion

    local db = CDM.db
    local defaults = CDM.defaults or {}

    styleCache.zoomIcons = CfgValue(db, defaults, "zoomIcons", false)
    styleCache.zoomAmount = CfgValue(db, defaults, "zoomAmount", 0.08)
    styleCache.hideIconOverlay = CfgValue(db, defaults, "hideIconOverlay", true)
    styleCache.hideIconOverlayTexture = CfgValue(db, defaults, "hideIconOverlayTexture", true)
    styleCache.swipeColor = CfgValue(db, defaults, "swipeColor", CDM_C.SWIPE_COLOR)
    styleCache.hideGCDSwipe = CfgValue(db, defaults, "hideGCDSwipe", false)
    styleCache.hideBuffSwipe = CfgValue(db, defaults, "hideBuffSwipe", false)
    styleCache.disableCooldownDesat = CfgValue(db, defaults, "disableCooldownDesat", false)
    styleCache.textFont = CfgValue(db, defaults, "textFont", "Friz Quadrata TT")
    local rawOutline = CfgValue(db, defaults, "textFontOutline", "OUTLINE")
    styleCache.textFontOutline = CDM_C.ResolveOutlineFlags(rawOutline)

    styleCache.cooldownFontSize = CfgValue(db, defaults, "cooldownFontSize", 12)
    styleCache.cooldownColor = CfgValue(db, defaults, "cooldownColor", CDM_C.WHITE)
    styleCache.racialsCooldownFontSize = CfgValue(db, defaults, "racialsCooldownFontSize", 12)
    styleCache.defensivesCooldownFontSize = CfgValue(db, defaults, "defensivesCooldownFontSize", 12)
    styleCache.trinketsCooldownFontSize = CfgValue(db, defaults, "trinketsCooldownFontSize", 12)
    styleCache.externalsCooldownFontSize = CfgValue(db, defaults, "externalsCooldownFontSize", 15)
    styleCache.essRow2CooldownFontSize = CfgValue(db, defaults, "essRow2CooldownFontSize", 15)
    styleCache.utilityCooldownFontSize = CfgValue(db, defaults, "utilityCooldownFontSize", 15)

    styleCache.chargeFontSize = CfgValue(db, defaults, "chargeFontSize", 12)
    styleCache.utilityChargeFontSize = CfgValue(db, defaults, "utilityChargeFontSize", 12)
    styleCache.essRow2ChargeFontSize = CfgValue(db, defaults, "essRow2ChargeFontSize", 15)
    styleCache.racialsChargeFontSize = CfgValue(db, defaults, "racialsChargeFontSize", 15)
    styleCache.defensivesChargeFontSize = CfgValue(db, defaults, "defensivesChargeFontSize", 15)
    styleCache.chargeColor = CfgValue(db, defaults, "chargeColor", CDM_C.WHITE)
    styleCache.chargePosition = CfgValue(db, defaults, "chargePosition", "BOTTOMRIGHT")
    styleCache.chargeOffsetX = CfgValue(db, defaults, "chargeOffsetX", 0)
    styleCache.chargeOffsetY = CfgValue(db, defaults, "chargeOffsetY", 0)
    styleCache.utilityChargeColor = CfgValue(db, defaults, "utilityChargeColor", CDM_C.WHITE)
    styleCache.utilityChargePosition = CfgValue(db, defaults, "utilityChargePosition", "BOTTOMRIGHT")
    styleCache.utilityChargeOffsetX = CfgValue(db, defaults, "utilityChargeOffsetX", 0)
    styleCache.utilityChargeOffsetY = CfgValue(db, defaults, "utilityChargeOffsetY", 0)
    styleCache.essRow2ChargeColor = CfgValue(db, defaults, "essRow2ChargeColor", CDM_C.WHITE)
    styleCache.essRow2ChargePosition = CfgValue(db, defaults, "essRow2ChargePosition", "BOTTOMRIGHT")
    styleCache.essRow2ChargeOffsetX = CfgValue(db, defaults, "essRow2ChargeOffsetX", 0)
    styleCache.essRow2ChargeOffsetY = CfgValue(db, defaults, "essRow2ChargeOffsetY", 0)

    styleCache.countFontSize = CfgValue(db, defaults, "countFontSize", 12)
    styleCache.countColor = CfgValue(db, defaults, "countColor", CDM_C.WHITE)

    styleCache.buffCooldownFontSize = CfgValue(db, defaults, "buffCooldownFontSize", 12)
    styleCache.buffCooldownColor = CfgValue(db, defaults, "buffCooldownColor", CDM_C.WHITE)

    styleCache.countPositionMain = CfgValue(db, defaults, "countPositionMain", "TOP")
    styleCache.countOffsetXMain = CfgValue(db, defaults, "countOffsetXMain", 0)
    styleCache.countOffsetYMain = CfgValue(db, defaults, "countOffsetYMain", 0)
    styleCache.borderColor = CfgValue(db, defaults, "borderColor", CDM_C.WHITE)

    styleCache.hideDebuffBorder = CfgValue(db, defaults, "hideDebuffBorder", false)
    styleCache.hidePandemicIndicator = CfgValue(db, defaults, "hidePandemicIndicator", false)
    styleCache.hideCooldownBling = CfgValue(db, defaults, "hideCooldownBling", false)

    local pandemicCustomizationEnabled = CfgValue(db, defaults, "pandemicCustomizationEnabled", false) == true
    local pandemicStylingActive = styleCache.hidePandemicIndicator == true
        and pandemicCustomizationEnabled
    styleCache.pandemicBorderEnabled = pandemicStylingActive and (CfgValue(db, defaults, "pandemicBorderEnabled", false) == true) or false
    styleCache.pandemicBorderColorBuffBars = styleCache.pandemicBorderEnabled and (CfgValue(db, defaults, "pandemicBorderColorBuffBars", false) == true) or false
    styleCache.pandemicBorderColor   = CfgValue(db, defaults, "pandemicBorderColor", CDM_C.WHITE)

    styleCache.chargeShowEdge  = CfgValue(db, defaults, "chargeShowEdge", false) == true
    styleCache.chargeHideSwipe = CfgValue(db, defaults, "chargeHideSwipe", false) == true
    styleCache.chargeHideRechargeTimer = CfgValue(db, defaults, "chargeHideRechargeTimer", false) == true

    styleCache.buffBarWidth = CfgValue(db, defaults, "buffBarWidth", 0)
    styleCache.buffBarHeight = CfgValue(db, defaults, "buffBarHeight", 20)
    styleCache.buffBarSpacing = CfgValue(db, defaults, "buffBarSpacing", 2)
    styleCache.buffBarGrowDirection = CfgValue(db, defaults, "buffBarGrowDirection", "DOWN")
    styleCache.buffBarIconPosition = CfgValue(db, defaults, "buffBarIconPosition", "LEFT")
    styleCache.buffBarIconGap = CfgValue(db, defaults, "buffBarIconGap", 2)
    styleCache.buffBarShowName = CfgValue(db, defaults, "buffBarShowName", true)
    styleCache.buffBarNameMaxChars = CfgValue(db, defaults, "buffBarNameMaxChars", 0)
    styleCache.buffBarShowDuration = CfgValue(db, defaults, "buffBarShowDuration", true)
    styleCache.buffBarTexture = CfgValue(db, defaults, "buffBarTexture", "Blizzard")
    styleCache.buffBarColor = CfgValue(db, defaults, "buffBarColor", { r = 0.4, g = 0.6, b = 0.9, a = 1 })
    styleCache.buffBarBackgroundColor = CfgValue(db, defaults, "buffBarBackgroundColor", { r = 0.1, g = 0.1, b = 0.1, a = 0.8 })
    styleCache.buffBarFillDirection = CfgValue(db, defaults, "buffBarFillDirection", "LEFT_TO_RIGHT")
    styleCache.buffBarNameFontSize = CfgValue(db, defaults, "buffBarNameFontSize", 12)
    styleCache.buffBarNameColor = CfgValue(db, defaults, "buffBarNameColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarNameOffsetX = CfgValue(db, defaults, "buffBarNameOffsetX", 4)
    styleCache.buffBarNameOffsetY = CfgValue(db, defaults, "buffBarNameOffsetY", 0)
    styleCache.buffBarDurationFontSize = CfgValue(db, defaults, "buffBarDurationFontSize", 12)
    styleCache.buffBarDurationColor = CfgValue(db, defaults, "buffBarDurationColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarDurationPosition = CfgValue(db, defaults, "buffBarDurationPosition", "RIGHT")
    styleCache.buffBarDurationOffsetX = CfgValue(db, defaults, "buffBarDurationOffsetX", -4)
    styleCache.buffBarDurationOffsetY = CfgValue(db, defaults, "buffBarDurationOffsetY", 0)
    styleCache.buffBarShowApplications = CfgValue(db, defaults, "buffBarShowApplications", true)
    styleCache.buffBarApplicationsFontSize = CfgValue(db, defaults, "buffBarApplicationsFontSize", 15)
    styleCache.buffBarApplicationsColor = CfgValue(db, defaults, "buffBarApplicationsColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarApplicationsPosition = CfgValue(db, defaults, "buffBarApplicationsPosition", "CENTER")
    styleCache.buffBarApplicationsOffsetX = CfgValue(db, defaults, "buffBarApplicationsOffsetX", 0)
    styleCache.buffBarApplicationsOffsetY = CfgValue(db, defaults, "buffBarApplicationsOffsetY", 0)

    styleCache.assistFontSize = CfgValue(db, defaults, "assistFontSize", 15)
    styleCache.assistColor = CfgValue(db, defaults, "assistColor", CDM_C.WHITE)
    styleCache.assistPosition = CfgValue(db, defaults, "assistPosition", "TOPRIGHT")
    styleCache.assistOffsetX = CfgValue(db, defaults, "assistOffsetX", 0)
    styleCache.assistOffsetY = CfgValue(db, defaults, "assistOffsetY", 0)

    styleCache.isOneBorderMode = Pixel.IsOneBorderMode()
    styleCache.isBorderActive = CfgValue(db, defaults, "borderFile", "1 Pixel") ~= "None"
    styleCache.borderSize = CfgValue(db, defaults, "borderSize", 1)

    CDM_C.RefreshBaseFontCache()
    styleCache.fontPath = CDM_C.GetBaseFontPath()

    cdFont:SetFont(styleCache.fontPath, FontSize(styleCache.cooldownFontSize), styleCache.textFontOutline)
    cdFontBuff:SetFont(styleCache.fontPath, FontSize(styleCache.buffCooldownFontSize), styleCache.textFontOutline)

    styleCache.cooldownDecimalThreshold = CfgValue(db, defaults, "cooldownDecimalThreshold")
    styleCache.cooldownColorThresholdEnabled = CfgValue(db, defaults, "cooldownColorThresholdEnabled")
    styleCache.cooldownColorThreshold = CfgValue(db, defaults, "cooldownColorThreshold")
    styleCache.cooldownColorThresholdColor = CfgValue(db, defaults, "cooldownColorThresholdColor")

    CDM.CooldownFormatter.Rebuild(styleCache)
end

CDM.RefreshStyleCache = RefreshStyleCache
CDM.styleCache = styleCache



local function StyleCooldownTextElement(text, fontPath, fontSize, fontOutline, color, init)
    if not text then return end
    color = color or CDM_C.WHITE
    if init then
        text:SetIgnoreParentScale(true)
        text:ClearAllPoints()
        text:SetPoint("CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetShadowOffset(0, 0)
        text:SetDrawLayer("OVERLAY", 7)
    end
    text:SetFont(fontPath, FontSize(fontSize), fontOutline)
    text:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

local function SafeEquals(v, expected)
    return (type(v) ~= "number" or canaccessvalue(v)) and v == expected
end

local function ApplyOverlayVisibility(hideAtlas, hideTexture, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_OVERLAY_ATLAS) then
                if hideAtlas then
                    region:SetAlpha(0)
                    region:Hide()
                else
                    region:SetAlpha(1)
                    region:Show()
                end
            elseif SafeEquals(region:GetTexture(), BLIZZARD_ICON_OVERLAY_TEXTURE_FILE_ID) then
                if hideTexture then
                    region:SetAlpha(0)
                    region:Hide()
                else
                    region:SetAlpha(1)
                    region:Show()
                end
            end
        end
    end
end

local function StyleCooldownFontStringsInRegions(fontPath, fontSize, fontOutline, color, init, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            StyleCooldownTextElement(region, fontPath, fontSize, fontOutline, color, init)
        end
    end
end

local function GetEffectiveCooldownSpellID(frame)
    if not frame then return nil end
    local info = frame.cooldownInfo
    if not info then return nil end
    local id = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
    return IsSafeNumber(id) and id or nil
end

local function GetCastSpellID(frame)
    if not frame then return nil end
    local info = frame.cooldownInfo
    if not info then return nil end
    local id = info.overrideSpellID or info.spellID
    return IsSafeNumber(id) and id or nil
end
CDM.GetCastSpellID = GetCastSpellID

local function HasChargeSource(frame)
    return frame.HasVisualDataSource_Charges and frame:HasVisualDataSource_Charges() or false
end

local function FindAuraOverlayEntry(frame)
    local map = CDM._auraOverlayEnabled
    if not map then return nil end
    local cdID = frame and frame.cooldownID
    if cdID and map[cdID] then return map[cdID] end
    return nil
end

local function ApplyPandemicCDMStyle(frame)
    if frame.cdmPandemicActive then return end
    if not styleCache.pandemicBorderEnabled then return end
    frame.cdmPandemicActive = true

    BORDER:ApplyPandemicBorderColor(frame, styleCache.pandemicBorderColor, styleCache.pandemicBorderColorBuffBars)
end

local function ClearPandemicCDMStyle(frame)
    if not frame.cdmPandemicActive then return end
    frame.cdmPandemicActive = false

    BORDER:ClearPandemicBorderColor(frame)
end

local function ClearReadyGlow(frame)
    CDM.Glow:RequestBuffGlow(frame, "ready", false)
end

local function ApplyReadyGlow(frame, entry)
    if frame.cdmGlowProducer == "ready"
       and frame.cdmBuffGlowOverrideColor == entry.readyGlowColor then
        local host = frame.cdmBuffGlowHost
        if host and host:IsShown() and host:GetWidth() >= 1 and host.cdmGlowActive then
            return
        end
    end
    CDM.Glow:RequestBuffGlow(frame, "ready", true, entry.readyGlowColor, nil)
end

local function GetReadyGlowDecision(frame, entry, spellID, isReady)
    if not entry or not entry.readyGlowEnabled then
        return true, false
    end
    if frame.cdmLastAuraActive then
        return true, false
    end
    if entry.auraOverlay and entry.auraDesaturateInactive then
        return true, false
    end
    if not spellID then
        return false, false
    end
    return true, isReady
end

local function SyncReadyGlow(frame, entry, spellID, isReady)
    local decisionKnown, shouldShowReadyGlow = GetReadyGlowDecision(frame, entry, spellID, isReady)
    if not decisionKnown then
        return
    end
    if shouldShowReadyGlow then
        ApplyReadyGlow(frame, entry)
    else
        ClearReadyGlow(frame)
    end
end

CDM.SyncReadyGlowForFrame = SyncReadyGlow

local function ApplyIconDesat(frame, entry, auraActive, sid, blizzDesat)
    local desat = 0
    if entry and entry.auraOverlay and auraActive then
        desat = 0
    elseif entry and entry.auraOverlay and entry.auraDesaturateInactive then
        desat = 1
    elseif sid and not HasChargeSource(frame) then
        if not styleCache.disableCooldownDesat then
            local realDur = GetSpellCooldownDuration(sid, true)
            desat = (realDur and realDur:EvaluateRemainingDuration(DesaturationCurve, RealTime)) or 0
        end
    else
        local boolDesat = blizzDesat
        if boolDesat == nil then boolDesat = frame.cooldownDesaturated end
        if boolDesat ~= nil and not styleCache.disableCooldownDesat then
            desat = EvaluateColorValueFromBoolean(boolDesat, 1, 0)
        end
    end
    frame.cdmInternalWrite = true
    frame.Icon:SetDesaturation(desat)
    frame.cdmInternalWrite = false
end

local function ApplyBaseSwipeStyle(cd, frame)
    local sc = styleCache.swipeColor or CDM_C.SWIPE_COLOR
    cd:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)

    local ver = CDM.styleCacheVersion or 0
    if frame.cdmLastCooldownStyleVer ~= ver then
        if styleCache.zoomIcons then
            cd:SetSwipeTexture(CDM_C.TEX_WHITE8X8)
        else
            cd:SetSwipeTexture(DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE)
        end
        frame.cdmLastCooldownStyleVer = ver
    end
end

local function ApplyCooldownWidget(frame, entry, auraActive, sid)
    local cd = frame.Cooldown
    frame.cdmInternalWrite = true

    local hideCountdown = false

    if entry and entry.auraOverlay and auraActive then
        cd:SetReverse(true)
        cd:SetAlpha(1)
        cd:SetDrawEdge(false)
        cd:SetUseAuraDisplayTime(true)
        cd:SetDrawSwipe(true)
        frame.cdmCooldownOverlayStyleApplied = true
    elseif entry and entry.auraOverlay and not auraActive and entry.auraDesaturateInactive then
        cd:SetReverse(false)
        cd:SetAlpha(1)
        cd:SetDrawEdge(false)
        cd:SetDrawSwipe(false)
        frame.cdmCooldownOverlayStyleApplied = true
    else
        local transitioningOut = frame.cdmCooldownOverlayStyleApplied
        if transitioningOut then
            cd:SetReverse(false)
            cd:SetAlpha(1)
            frame.cdmCooldownOverlayStyleApplied = nil
        end
        if HasChargeSource(frame) then
            local chargeDur = sid and GetSpellChargeDuration(sid)
            if chargeDur then
                cd:SetUseAuraDisplayTime(false)
                cd:SetCooldownFromDurationObject(chargeDur)
            else
                cd:Clear()
            end
            cd:SetDrawSwipe(not styleCache.chargeHideSwipe)
            cd:SetDrawEdge(styleCache.chargeShowEdge and true or false)
            hideCountdown = styleCache.chargeHideRechargeTimer
        else
            cd:SetDrawEdge(false)
            cd:SetUseAuraDisplayTime(false)
            local cdDur = sid and GetSpellCooldownDuration(sid, styleCache.hideGCDSwipe)
            if cdDur then
                cd:SetCooldownFromDurationObject(cdDur)
            else
                cd:Clear()
            end
            if transitioningOut then
                cd:SetDrawSwipe(true)
            end
        end
    end

    cd:SetHideCountdownNumbers(hideCountdown)

    frame.cdmInternalWrite = false
end

local function ApplyGlows(frame, entry, auraActive)
    if entry and entry.auraOverlay and auraActive and entry.auraGlowEnabled then
        CDM.Glow:RequestBuffGlow(frame, "aura", true, entry.auraGlowColor, nil)
    else
        CDM.Glow:RequestBuffGlow(frame, "aura", false)
    end

    if entry and entry.auraOverlay and auraActive and entry.auraBorderEnabled then
        BORDER:ApplyBorderColorOverride(frame, entry.auraBorderColor or CDM_C.WHITE)
        frame.cdmAuraBorderActive = true
    elseif frame.cdmAuraBorderActive then
        BORDER:RestoreToCurrentBorderColor(frame)
        frame.cdmAuraBorderActive = false
    end

    local director = CDM.GlowDirector
    if director and director.RefreshFrame then
        director:RefreshFrame(frame)
    end
end

function CDM:RefreshFrameVisuals(frame, skipDesat)
    if not frame then return end
    if not VIEWERS_WITH_OVERRIDE[frame.cdmViewerName] then return end
    local entry = FindAuraOverlayEntry(frame)
    local auraActive = (frame.cooldownUseAuraDisplayTime == true)
    local sid = GetCastSpellID(frame)
    frame.cdmLastAuraActive = auraActive
    if not skipDesat then
        ApplyIconDesat(frame, entry, auraActive, sid)
    end
    ApplyCooldownWidget(frame, entry, auraActive, sid)
    ApplyGlows(frame, entry, auraActive)
end

function CDM:ApplyBuffVisualState(frame)
    if not frame then return end

    if styleCache.hideDebuffBorder and frame.DebuffBorder then
        frame.DebuffBorder:Hide()
    end
end

function CDM:ProcessBuffViewerOverrides(frame)
    if not frame then return end
    if frame.cdmIsProcessingBuffOverride then return end

    frame.cdmIsProcessingBuffOverride = true
    self:ApplyBuffVisualState(frame)
    frame.cdmIsProcessingBuffOverride = false
end

local function ApplyBuffCooldownStyle(frame)
    local cd = frame.Cooldown
    ApplyBaseSwipeStyle(cd, frame)
    cd:SetDrawEdge(false)
    cd:SetDrawSwipe(not styleCache.hideBuffSwipe)
end

local function EnsureFrameHooks(frame, hookType)
    if not frame then return end

    if hookType == "buff" then
        ApplyBuffCooldownStyle(frame)

        local cd = frame.Cooldown
        if not frame.cdmBuffSwipeHooked then
            frame.cdmBuffSwipeHooked = true
            hooksecurefunc(cd, "SetCooldown", function()
                ApplyBaseSwipeStyle(cd, frame)
            end)
        end
    end

    if (hookType == "buff" or hookType == "bar") and frame.DebuffBorder and not frame.cdmDebuffBorderHooked then
        frame.cdmDebuffBorderHooked = true
        hooksecurefunc(frame.DebuffBorder, "Show", function(self)
            if styleCache.hideDebuffBorder and not frame.cdmIsProcessingBuffOverride then
                self:Hide()
            end
        end)
    end

    if (hookType == "cooldown" or hookType == "bar") and frame.CooldownFlash and not frame.cdmCooldownFlashHooked then
        frame.cdmCooldownFlashHooked = true
        hooksecurefunc(frame.CooldownFlash, "Show", function(self)
            if styleCache.hideCooldownBling then
                self:Hide()
                if self.FlashAnim then
                    self.FlashAnim:Stop()
                end
            end
        end)
    end

    if frame.ShowPandemicStateFrame and not frame.cdmPandemicHooked then
        frame.cdmPandemicHooked = true
        hooksecurefunc(frame, "ShowPandemicStateFrame", function(self)
            if styleCache.hidePandemicIndicator and self.PandemicIcon and not self.cdmIsProcessingBuffOverride then
                self.PandemicIcon:Hide()
            end
            ApplyPandemicCDMStyle(self)
        end)
        hooksecurefunc(frame, "HidePandemicStateFrame", function(self)
            if not self.cdmPandemicActive then return end
            ClearPandemicCDMStyle(self)
        end)
    end
end

local function InvalidateUtilCache()
    if CDM.InvalidateUtilityVisibleCountCache then
        CDM:InvalidateUtilityVisibleCountCache()
    end
end

local function SetupUtilityVisibilityHooks(frame)
    if not frame or frame.cdmUtilityVisibilityHooked or not frame.HookScript then
        return
    end

    frame.cdmUtilityVisibilityHooked = true
    frame:HookScript("OnShow", InvalidateUtilCache)
    frame:HookScript("OnHide", InvalidateUtilCache)
end

local function ApplyIconTextureLayout(texture, frame, iconWidth, iconHeight, zoomAmount)
    CDM_C.ApplyIconTexCoord(texture, zoomAmount, iconWidth, iconHeight)
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
    DisableTextureSnap(texture)
end

local function RemoveBlizzardIconMask(iconTexture, flagName)
    if not iconTexture then
        return
    end

    if iconTexture[flagName] then
        return
    end

    for i = 1, iconTexture:GetNumMaskTextures() do
        local mask = iconTexture:GetMaskTexture(i)
        if mask and SafeEquals(mask:GetAtlas(), BLIZZARD_ICON_MASK_ATLAS) then
            iconTexture:RemoveMaskTexture(mask)
            iconTexture[flagName] = true
            iconTexture[flagName .. "Source"] = mask
            break
        end
    end
end

local function RestoreBlizzardIconMask(iconTexture, flagName)
    if not iconTexture then
        return
    end
    if not iconTexture[flagName] then
        return
    end
    local source = iconTexture[flagName .. "Source"]
    if source then
        iconTexture:AddMaskTexture(source)
    end
    iconTexture[flagName] = false
    iconTexture[flagName .. "Source"] = nil
end

local function EnsureIconBorder(frame, host, borderKey, active, version)
    local existing = frame[borderKey]

    if not active then
        if existing then existing:Hide() end
        return
    end

    local versionKey = borderKey .. "Version"
    if frame[versionKey] ~= version or not existing then
        local border = BORDER:CreateBorder(host, true)
        if BORDER.activeBorders[host] then
            BORDER.activeBorders[host].colorFrame = frame
        end
        frame[borderKey] = border
        frame[versionKey] = version
        if border and border.SetBackdropBorderColor then
            local color = BORDER:ResolveCurrentBorderColor(frame)
            border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        end
    elseif existing and not existing:IsShown() then
        existing:Show()
    end
end

local RefreshKeybindForFrame

function CDM:ApplyStyle(frame, vName, forceUpdate)
    if not frame then return end

    frame.cdmViewerName = vName
    local fullUpdate = forceUpdate or not frame.cdmHooksInitialized or frame.cdmLastStyledVName ~= vName
    local styleVersion = CDM.styleCacheVersion or 0
    local borderStyleVersion = CDM.borderStyleVersion or 0

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local desc = VIEWER_DESC[vName]
    local isBuff = desc and desc.isBuff
    local isCooldown = desc and desc.isCooldown

    local groupData
    if isCooldown then
        local groupIdx = CDM.CheckCdGroupMatch and CDM.CheckCdGroupMatch(frame)
        if groupIdx then
            local sets = CDM.CooldownGroupSets
            groupData = sets and sets.groups and sets.groups[groupIdx]
        end
    end

    local borderActive = styleCache.isBorderActive

    local iconWidth, iconHeight
    if groupData then
        iconWidth = Snap(groupData.iconWidth or 30)
        iconHeight = Snap(groupData.iconHeight or 30)
    elseif desc and (desc.sizeKey or desc.widthKey) then
        local w, h = ResolveIconSize(desc, frame.cdmRow)
        iconWidth = Snap(w)
        iconHeight = Snap(h)
    else
        iconWidth = Snap(30)
        iconHeight = Snap(30)
    end

    local fontSpellID = isCooldown and GetEffectiveCooldownSpellID(frame) or nil

    local needsVisualUpdate = fullUpdate
        or frame.cdmLastStyleVersion ~= styleVersion
        or frame.cdmLastStyledW ~= iconWidth
        or frame.cdmLastStyledH ~= iconHeight
        or frame.cdmLastFontSpellID ~= fontSpellID

    if not needsVisualUpdate then
        local actualW = frame:GetWidth() or 0
        local actualH = frame:GetHeight() or 0
        needsVisualUpdate = (actualW > 1 and math_abs(actualW - iconWidth) > 0.01)
                         or (actualH > 1 and math_abs(actualH - iconHeight) > 0.01)
    end

    if needsVisualUpdate then
        frame:SetSize(iconWidth, iconHeight)

        local glow = frame.SpellActivationAlert
        if glow then
            glow:SetFrameLevel(frame:GetFrameLevel() + 5)
            if CDM.Glow and CDM.Glow.HideBlizzardGlow then
                CDM.Glow:HideBlizzardGlow(frame)
            else
                glow:SetAlpha(0)
                glow:Hide()
            end
        end

        local zoomIcons = styleCache.zoomIcons
        local zoomAmount = zoomIcons and styleCache.zoomAmount or 0
        ApplyIconTextureLayout(frame.Icon, frame, iconWidth, iconHeight, zoomAmount)

        frame.Cooldown:ClearAllPoints()
        frame.Cooldown:SetAllPoints(frame)

        frame.Cooldown:SetCountdownFont(isBuff and "AyijeCDM_CDFont_Buff" or "AyijeCDM_CDFont")
        frame.Cooldown:SetCountdownFormatter(CDM.CooldownFormatter.Get())

        local hideAtlas = styleCache.hideIconOverlay
        local hideTexture = styleCache.hideIconOverlayTexture
        if fullUpdate
            or frame.cdmOverlayAtlasHidden ~= hideAtlas
            or frame.cdmOverlayTextureHidden ~= hideTexture then
            ApplyOverlayVisibility(hideAtlas, hideTexture, frame:GetRegions())
            frame.cdmOverlayAtlasHidden = hideAtlas
            frame.cdmOverlayTextureHidden = hideTexture
        end

        if hideTexture then
            RemoveBlizzardIconMask(frame.Icon, "cdmIconMaskRemoved")
        elseif frame.Icon.cdmIconMaskRemoved then
            RestoreBlizzardIconMask(frame.Icon, "cdmIconMaskRemoved")
        end

        EnsureIconBorder(frame, frame, "cdmBorder", borderActive, borderStyleVersion)

        if isCooldown then
            if frame.ChargeCount then
                frame.ChargeCount:SetFrameLevel(frame:GetFrameLevel() + 15)
            end

            local chargeText = frame.ChargeCount and frame.ChargeCount.Current
            if chargeText then
                if not frame.cdmChargeTextHooked then
                    frame.cdmChargeTextHooked = true
                    hooksecurefunc(chargeText, "SetText", function(self, value)
                        if type(value) == "number" then
                            self:SetText(TruncateWhenZero(value))
                        end
                    end)
                end
                chargeText:SetIgnoreParentScale(true)
            end
        end

        if isBuff then
            if frame.Applications then
                frame.Applications:SetFrameLevel(frame:GetFrameLevel() + 7)
            end

            local countText = frame.Applications and frame.Applications.Applications
            if countText then
                local fontPath = styleCache.fontPath
                local textFontOutline = styleCache.textFontOutline
                countText:SetIgnoreParentScale(true)
                countText:SetFont(fontPath, FontSize(styleCache.countFontSize), textFontOutline)
                countText:SetTextColor(styleCache.countColor.r, styleCache.countColor.g, styleCache.countColor.b, styleCache.countColor.a or 1)
                countText:SetDrawLayer("OVERLAY", 7)
                countText:SetShadowOffset(0, 0)

                if desc and desc.hasCount then
                    countText:ClearAllPoints()
                    countText:SetPoint(styleCache.countPositionMain, frame, styleCache.countPositionMain,
                        styleCache.countOffsetXMain, styleCache.countOffsetYMain)
                end

                frame.cdmCountStyle = nil
            end

        end

        do
            local fontPath = styleCache.fontPath
            local textFontOutline = styleCache.textFontOutline
            local effectiveCdFontSize, effectiveCdColor
            local effectiveChargeFS, effectiveChargeColor
            local effectiveChargePos, effectiveChargeOX, effectiveChargeOY

            if isCooldown then
                local spellID = fontSpellID

                local isRow2 = frame.cdmRow == 2
                local colorKey = (isRow2 and desc.chargeColorKey2) or desc.chargeColorKey
                local posKey = (isRow2 and desc.chargePosKey2) or desc.chargePosKey
                local oxKey = (isRow2 and desc.chargeOXKey2) or desc.chargeOXKey
                local oyKey = (isRow2 and desc.chargeOYKey2) or desc.chargeOYKey
                local viewerChargeColor = colorKey and styleCache[colorKey] or styleCache.chargeColor
                local viewerChargePos = posKey and styleCache[posKey] or styleCache.chargePosition
                local viewerChargeOX = oxKey and styleCache[oxKey] or styleCache.chargeOffsetX
                local viewerChargeOY = oyKey and styleCache[oyKey] or styleCache.chargeOffsetY

                if groupData then
                    effectiveCdFontSize = groupData.cooldownFontSize or 12
                    effectiveCdColor = groupData.cooldownColor
                    effectiveChargeFS = groupData.chargeFontSize or 15
                    effectiveChargeColor = groupData.chargeColor
                    effectiveChargePos = groupData.chargePosition or "BOTTOMRIGHT"
                    effectiveChargeOX = groupData.chargeOffsetX or 0
                    effectiveChargeOY = groupData.chargeOffsetY or 0

                    local spellOv = CDM.GetCooldownGroupSpellOverride(groupData, spellID)
                    if spellOv and spellOv.textOverride then
                        effectiveCdFontSize = spellOv.cooldownFontSize or effectiveCdFontSize
                        effectiveCdColor = spellOv.cooldownColor or effectiveCdColor
                        effectiveChargeFS = spellOv.chargeFontSize or effectiveChargeFS
                        effectiveChargeColor = spellOv.chargeColor or effectiveChargeColor
                        effectiveChargePos = spellOv.chargePosition or effectiveChargePos
                        effectiveChargeOX = spellOv.chargeOffsetX or effectiveChargeOX
                        effectiveChargeOY = spellOv.chargeOffsetY or effectiveChargeOY
                    end

                    effectiveCdColor = effectiveCdColor or styleCache.cooldownColor
                    effectiveChargeColor = effectiveChargeColor or viewerChargeColor
                else
                    local ov = spellID and CDM:GetUngroupedCooldownOverride(spellID)
                    if ov and ov.textOverride then
                        local db = CDM.db
                        effectiveCdFontSize = ov.cooldownFontSize or (db and db.cooldownFontSize or 15)
                        effectiveCdColor = ov.cooldownColor or (db and db.cooldownColor) or styleCache.cooldownColor
                        effectiveChargeFS = ov.chargeFontSize or (db and db.chargeFontSize or 15)
                        effectiveChargeColor = ov.chargeColor or viewerChargeColor
                        effectiveChargePos = ov.chargePosition or viewerChargePos
                        effectiveChargeOX = ov.chargeOffsetX or viewerChargeOX
                        effectiveChargeOY = ov.chargeOffsetY or viewerChargeOY
                    else
                        local cdFontKey = (desc.cdFontKey2 and isRow2) and desc.cdFontKey2 or desc.cdFontKey
                        effectiveCdFontSize = styleCache[cdFontKey]
                        effectiveCdColor = styleCache[desc.cdColorKey]
                        local chargeFontKey = (desc.chargeKey2 and isRow2) and desc.chargeKey2 or desc.chargeKey
                        effectiveChargeFS = chargeFontKey and styleCache[chargeFontKey] or styleCache.chargeFontSize
                        effectiveChargeColor = viewerChargeColor
                        effectiveChargePos = viewerChargePos
                        effectiveChargeOX = viewerChargeOX
                        effectiveChargeOY = viewerChargeOY
                    end
                end
            else
                local cdFontKey = desc and ((desc.cdFontKey2 and frame.cdmRow == 2) and desc.cdFontKey2 or desc.cdFontKey) or "cooldownFontSize"
                effectiveCdFontSize = styleCache[cdFontKey]
                effectiveCdColor = styleCache[desc and desc.cdColorKey or "cooldownColor"]
            end

            local cooldownText = frame.Cooldown.Text or frame.Cooldown.text
            StyleCooldownTextElement(cooldownText, fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor, fullUpdate)

            StyleCooldownFontStringsInRegions(
                fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor,
                fullUpdate, frame.Cooldown:GetRegions()
            )

            if frame.Time then
                StyleCooldownTextElement(frame.Time, fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor, fullUpdate)
            end
            if frame.Duration then
                StyleCooldownTextElement(frame.Duration, fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor, fullUpdate)
            end

            if isCooldown then
                local chargeText = frame.ChargeCount and frame.ChargeCount.Current
                if chargeText then
                    chargeText:ClearAllPoints()
                    SetPoint(chargeText, effectiveChargePos, frame, effectiveChargePos, effectiveChargeOX, effectiveChargeOY)
                    chargeText:SetFont(fontPath, FontSize(effectiveChargeFS), textFontOutline)
                    chargeText:SetTextColor(effectiveChargeColor.r, effectiveChargeColor.g, effectiveChargeColor.b, effectiveChargeColor.a or 1)
                    if fullUpdate then
                        chargeText:SetDrawLayer("OVERLAY", 7)
                        chargeText:SetShadowOffset(0, 0)
                    end
                end
            end
        end

        if isBuff then
            frame.Cooldown:SetReverse(true)
        end

        frame.cdmLastStyleVersion = styleVersion
        frame.cdmLastStyledW = iconWidth
        frame.cdmLastStyledH = iconHeight
        frame.cdmLastStyledVName = vName
        frame.cdmLastFontSpellID = fontSpellID
    end

    if desc and desc.hasKeybind then
        local KB = CDM.Keybinds
        if KB and KB.IsEnabled and KB:IsEnabled() then
            RefreshKeybindForFrame(frame, KB, KB:GetCacheVersion(), styleVersion)
        elseif frame.cdmKeybindContainer then
            frame.cdmKeybindContainer:Hide()
        end
    end

    if isBuff then
        if fullUpdate and desc then
            EnsureFrameHooks(frame, desc.hookType)
        end

        self:ProcessBuffViewerOverrides(frame)

        local borderInner = frame.cdmBorder
        if borderInner and borderInner.SetBackdropBorderColor then
            local sid = GetCastSpellID(frame) or (frame.isCustomBuff and IsSafeNumber(frame.spellID) and frame.spellID) or nil
            local catID = frame.cdmBuffCategorySpellID
            if fullUpdate
               or frame.cdmLastBuffBorderSpellID ~= sid
               or frame.cdmLastBuffBorderCatID ~= catID
               or frame.cdmLastBuffBorderColorVer ~= borderStyleVersion
               or frame.cdmLastBuffBorderStyleVer ~= styleVersion then
                frame.cdmLastBuffBorderSpellID = sid
                frame.cdmLastBuffBorderCatID = catID
                frame.cdmLastBuffBorderColorVer = borderStyleVersion
                frame.cdmLastBuffBorderStyleVer = styleVersion

                local configColor = styleCache.borderColor
                local r, g, b = configColor.r, configColor.g, configColor.b

                local customColor
                local candidates = GetSpellIDCandidates(self, frame)
                for _, id in ipairs(candidates) do
                    customColor = GetColorForSpellID(id)
                    if customColor then break end
                end

                if customColor then
                    r, g, b = customColor.r or r, customColor.g or g, customColor.b or b
                end

                BORDER:CommitResolvedBorderColor(frame, r, g, b)
            end
        end
    else
        if fullUpdate and desc then
            EnsureFrameHooks(frame, desc.hookType)
        end
        if desc and desc.hasUtilVisibility then
            SetupUtilityVisibilityHooks(frame)
        end
    end

    if desc and desc.hasOverride then
        if fullUpdate then
            local iconTex = frame.Icon
            if not frame.cdmDesatHooked then
                frame.cdmDesatHooked = true
                hooksecurefunc(iconTex, "SetDesaturated", function(_, desaturated)
                    if frame.cdmInternalWrite then return end
                    local entry = FindAuraOverlayEntry(frame)
                    local auraActive = (frame.cooldownUseAuraDisplayTime == true)
                    ApplyIconDesat(frame, entry, auraActive, GetCastSpellID(frame), desaturated)
                end)
            end

            local cd = frame.Cooldown
            if not frame.cdmCooldownHooked then
                frame.cdmCooldownHooked = true

                hooksecurefunc(cd, "SetCooldown", function()
                    local entry = FindAuraOverlayEntry(frame)
                    if entry
                       or frame.cdmLastAuraActive
                       or frame.cooldownUseAuraDisplayTime == true
                       or frame.cdmCooldownOverlayStyleApplied
                       or HasChargeSource(frame) then
                        ApplyBaseSwipeStyle(cd, frame)
                        CDM:RefreshFrameVisuals(frame, true)
                        return
                    end
                    ApplyBaseSwipeStyle(cd, frame)
                    cd:SetDrawEdge(false)
                    cd:SetHideCountdownNumbers(false)
                    if styleCache.hideGCDSwipe then
                        local sid = GetCastSpellID(frame)
                        local realDur = sid and GetSpellCooldownDuration(sid, true)
                        if realDur then
                            cd:SetCooldownFromDurationObject(realDur)
                        end
                    end
                end)

                hooksecurefunc(cd, "Clear", function()
                    if frame.cdmInternalWrite then return end
                    local entry = FindAuraOverlayEntry(frame)
                    if entry or frame.cdmLastAuraActive then
                        CDM:RefreshFrameVisuals(frame, true)
                    end
                end)
            end
        end

        local overlayEntry = FindAuraOverlayEntry(frame)
        if fullUpdate or overlayEntry then
            if fullUpdate then
                ApplyBaseSwipeStyle(frame.Cooldown, frame)
            end
            self:RefreshFrameVisuals(frame)
        end
    end

    if fullUpdate then
        frame.cdmHooksInitialized = true
    end
end

RefreshKeybindForFrame = function(frame, KB, kbCacheVer, styleVersion)
    if not frame.cdmKeybindContainer then
        local container = CreateFrame("Frame", nil, frame)
        container:SetAllPoints()
        frame.cdmKeybindContainer = container
        frame.cdmKeybindFS = container:CreateFontString(nil, "OVERLAY")
        frame.cdmKeybindFS:SetDrawLayer("OVERLAY", 7)
        frame.cdmKeybindFS:SetShadowOffset(0, 0)
    end
    frame.cdmKeybindContainer:SetFrameLevel(frame:GetFrameLevel() + 7)
    frame.cdmKeybindContainer:Show()

    local baseSpellID = GetBaseSpellID(frame)
    local kbFS = frame.cdmKeybindFS
    kbFS:SetIgnoreParentScale(true)
    kbFS:ClearAllPoints()
    kbFS:SetPoint(styleCache.assistPosition, frame, styleCache.assistPosition,
                  styleCache.assistOffsetX, styleCache.assistOffsetY)
    local kbFontPath = styleCache.fontPath or CDM_C.GetBaseFontPath()
    local kbOutline = styleCache.textFontOutline
    kbFS:SetFont(kbFontPath, FontSize(styleCache.assistFontSize), kbOutline)
    kbFS:SetTextColor(styleCache.assistColor.r, styleCache.assistColor.g, styleCache.assistColor.b, styleCache.assistColor.a or 1)

    local kbText = baseSpellID and KB:GetKeybindText(baseSpellID) or nil
    if not kbText and frame.itemID then
        kbText = KB:GetKeybindTextForItem(frame.itemID)
    end
    if not kbText and frame.spellID then
        kbText = KB:GetKeybindText(frame.spellID)
    end
    if kbText then
        kbFS:SetText(kbText)
        kbFS:Show()
    else
        kbFS:SetText("")
        kbFS:Hide()
    end
end

function CDM:RefreshViewerKeybindText()
    local KB = self.Keybinds
    if not KB or not KB.IsEnabled or not KB:IsEnabled() then return end

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local kbCacheVer = KB:GetCacheVersion()
    local styleVersion = self.styleCacheVersion or 0

    self:ForEachActiveFrame({ VIEWERS.ESSENTIAL, VIEWERS.UTILITY }, function(frame)
        if frame.cdmKeybindContainer then
            RefreshKeybindForFrame(frame, KB, kbCacheVer, styleVersion)
        end
    end)

    for _, name in ipairs(CDM_C.TRACKER_FRAME_ACCESSORS) do
        local accessor = self[name]
        local frames = accessor and accessor()
        if frames then
            for _, frame in ipairs(frames) do
                if frame.cdmKeybindContainer then
                    RefreshKeybindForFrame(frame, KB, kbCacheVer, styleVersion)
                end
            end
        end
    end
end

local function InstallBuffBarVisibilityShowHook(frame, hookKey, textElement, resolvedFlagKey)
    if not textElement or frame[hookKey] then
        return
    end

    frame[hookKey] = true
    hooksecurefunc(textElement, "Show", function(self)
        if frame[resolvedFlagKey] ~= false then
            return
        end
        self:Hide()
        self:SetAlpha(0)
    end)
end

local function InstallBarNameTextHook(frame, nameText)
    if not nameText or frame.cdmNameTextHooked then return end
    frame.cdmNameTextHooked = true
    hooksecurefunc(nameText, "SetText", function(self, text)
        if frame.cdmNameTextApplyGuard then return end
        local custom = frame.cdmResolvedCustomName
        if not custom or custom == "" then return end
        if text == custom then return end
        frame.cdmNameTextApplyGuard = true
        self:SetText(custom)
        frame.cdmNameTextApplyGuard = false
    end)
end

local function ResolveBarSpellOverride(frame, groupData)
    local spellID = frame.cdmBarGroupSpellID
    if groupData then
        if groupData.spellOverrides and spellID then
            return CDM:ResolveBarOverrideEntry(groupData.spellOverrides, spellID)
        end
        return nil
    end
    local db = CDM.db
    if not db or not db.ungroupedBarOverrides then return nil end
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil
    local specOv = specID and db.ungroupedBarOverrides[specID]
    if not specOv then return nil end
    if spellID then
        local ov = CDM:ResolveBarOverrideEntry(specOv, spellID)
        if ov then return ov end
    end
    if CDM.GetSpellIDCandidates then
        local candidates = CDM:GetSpellIDCandidates(frame)
        if candidates then
            for _, id in ipairs(candidates) do
                local ov = CDM:ResolveBarOverrideEntry(specOv, id)
                if ov then return ov end
            end
        end
    end
    return nil
end

CDM.ResolveBarSpellOverride = ResolveBarSpellOverride

local function ResolveBarField(groupData, groupKey, dbKey)
    if groupData and groupData[groupKey] ~= nil then
        return groupData[groupKey]
    end
    return styleCache[dbKey]
end

function CDM:ApplyBarStyle(frame, vName, iconPositionOverride, frameWidthOverride, frameHeightOverride, groupData, spellOvOverride)
    if not frame then return end

    frame.cdmViewerName = vName

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local spellOv = spellOvOverride or ResolveBarSpellOverride(frame, groupData)

    local iconPosition
    if iconPositionOverride ~= nil then
        iconPosition = iconPositionOverride
    elseif spellOv and spellOv.iconPosition ~= nil then
        iconPosition = spellOv.iconPosition
    else
        iconPosition = ResolveBarField(groupData, "iconPosition", "buffBarIconPosition")
    end

    local styleVersion = CDM.styleCacheVersion or 0
    local targetFrameWidth = frameWidthOverride or (frame.GetWidth and frame:GetWidth()) or 0
    local targetFrameHeight = frameHeightOverride or (frame.GetHeight and frame:GetHeight()) or 0
    local barStyleNeedsUpdate = not frame.cdmBarStyled
        or frame.cdmLastBarStyleVersion ~= styleVersion
        or frame.cdmLastBarW ~= targetFrameWidth
        or frame.cdmLastBarH ~= targetFrameHeight
        or frame.cdmLastBarIconPosition ~= iconPosition
        or frame.cdmLastBarOv ~= spellOv

    local borderVersion = CDM.borderStyleVersion or 0

    local bar = frame.Bar

    if not frame.cdmBarHidesDone then
        if frame.DebuffBorder then
            frame.DebuffBorder:Hide()
        end
        EnsureFrameHooks(frame, "bar")
        if frame.cdmBorder then
            frame.cdmBorder:Hide()
        end

        if bar then
            if bar.BarBG then
                bar.BarBG:Hide()
                bar.BarBG:SetAlpha(0)
            end

            if bar.Pip then
                bar.Pip:Hide()
                bar.Pip:SetAlpha(0)
                if not frame.cdmPipHooked then
                    frame.cdmPipHooked = true
                    hooksecurefunc(bar.Pip, "Show", function(self)
                        self:Hide()
                        self:SetAlpha(0)
                    end)
                end
            end
        end
        frame.cdmBarHidesDone = true
    end

    if not frame.cdmBarContentHooked and frame.SetBarContent then
        frame.cdmBarContentHooked = true
        hooksecurefunc(frame, "SetBarContent", function()
            frame.cdmBarStyled = false
            if frame.cdmLastBarIconPosition == "HIDDEN" then
                if frame.Icon then frame.Icon:Hide() end
                local bar = frame.Bar
                if bar then
                    bar:ClearAllPoints()
                    SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
                    SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
                end
            end
        end)
    end

    if not barStyleNeedsUpdate then
        return
    end

    local barHeight = (targetFrameHeight and targetFrameHeight > 0) and targetFrameHeight or ResolveBarField(groupData, "barHeight", "buffBarHeight")
    if spellOv and type(spellOv.barHeight) == "number" and spellOv.barHeight > 0 then
        barHeight = spellOv.barHeight
    end
    barHeight = Snap(barHeight)
    local iconGap = Snap(ResolveBarField(groupData, "iconGap", "buffBarIconGap") or 0)
    local showName = ResolveBarField(groupData, "showName", "buffBarShowName")
    if spellOv and spellOv.nameHidden == true then showName = false end
    local showDuration = ResolveBarField(groupData, "showDuration", "buffBarShowDuration")
    if spellOv and spellOv.durationHidden == true then showDuration = false end
    local barTextureName = ResolveBarField(groupData, "texture", "buffBarTexture")
    local barColor = (spellOv and spellOv.barColor) or ResolveBarField(groupData, "barColor", "buffBarColor")
    local bgColor = (spellOv and spellOv.backgroundColor) or ResolveBarField(groupData, "backgroundColor", "buffBarBackgroundColor")
    local fillDirection = (spellOv and spellOv.barFillDirection) or ResolveBarField(groupData, "barFillDirection", "buffBarFillDirection") or "LEFT_TO_RIGHT"
    local customName = spellOv and type(spellOv.customName) == "string" and spellOv.customName ~= "" and spellOv.customName or nil
    local fontPath = styleCache.fontPath
    local textFontOutline = styleCache.textFontOutline
    local zoomIcons = styleCache.zoomIcons
    local zoomAmount = zoomIcons and styleCache.zoomAmount or 0
    local nameFontSize = ResolveBarField(groupData, "nameFontSize", "buffBarNameFontSize")
    local nameMaxChars = ResolveBarField(groupData, "nameMaxChars", "buffBarNameMaxChars")
    local nameColor = ResolveBarField(groupData, "nameColor", "buffBarNameColor")
    local nameOffsetX = ResolveBarField(groupData, "nameOffsetX", "buffBarNameOffsetX")
    local nameOffsetY = ResolveBarField(groupData, "nameOffsetY", "buffBarNameOffsetY")
    local durationFontSize = ResolveBarField(groupData, "durationFontSize", "buffBarDurationFontSize")
    local durationColor = ResolveBarField(groupData, "durationColor", "buffBarDurationColor")
    local durationPosition = ResolveBarField(groupData, "durationPosition", "buffBarDurationPosition")
    if durationPosition ~= "LEFT" and durationPosition ~= "RIGHT" then durationPosition = "CENTER" end
    local durationOffsetX = ResolveBarField(groupData, "durationOffsetX", "buffBarDurationOffsetX")
    local durationOffsetY = ResolveBarField(groupData, "durationOffsetY", "buffBarDurationOffsetY")
    local showApplications = ResolveBarField(groupData, "showApplications", "buffBarShowApplications")
    local appFontSize = ResolveBarField(groupData, "applicationsFontSize", "buffBarApplicationsFontSize")
    local appColor = ResolveBarField(groupData, "applicationsColor", "buffBarApplicationsColor")
    local appPosition = ResolveBarField(groupData, "applicationsPosition", "buffBarApplicationsPosition")
    local appOffsetX = ResolveBarField(groupData, "applicationsOffsetX", "buffBarApplicationsOffsetX")
    local appOffsetY = ResolveBarField(groupData, "applicationsOffsetY", "buffBarApplicationsOffsetY")

    frame.cdmResolvedShowName = showName and true or false
    frame.cdmResolvedShowDuration = showDuration and true or false
    frame.cdmResolvedShowApplications = showApplications and true or false

    local customNameChanged = frame.cdmResolvedCustomName ~= customName
    frame.cdmResolvedCustomName = customName

    local barTexture = (LSM and LSM:Fetch("statusbar", barTextureName)) or "Interface\\TargetingFrame\\UI-StatusBar"

    local iconFrame = frame.Icon
    local iconSize = barHeight

    frame.cdmLastBarIconPosition = iconPosition

    if iconFrame then
        if iconPosition == "HIDDEN" then
            if frame.cdmIconBorder then
                frame.cdmIconBorder:Hide()
            end
            iconFrame:Hide()
        else
            iconFrame:Show()
            Pixel.SetSize(iconFrame, iconSize, iconSize)

            iconFrame:ClearAllPoints()
            if iconPosition == "RIGHT" then
                SetPoint(iconFrame, "RIGHT", frame, "RIGHT", 0, 0)
            else
                SetPoint(iconFrame, "LEFT", frame, "LEFT", 0, 0)
            end

            local iconTex = iconFrame.Icon
            if iconTex then
                if iconTex.ClearAllPoints then
                    iconTex:ClearAllPoints()
                    if styleCache.isOneBorderMode then
                        local onePx = Pixel.GetSize()
                        local configuredSize = styleCache.borderSize or 1
                        local borderPixels = math_max(1, math_floor(configuredSize / onePx))
                        local inset = math_max(0, (borderPixels * onePx) - onePx)
                        iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", inset, -inset)
                        iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset, inset)
                    else
                        iconTex:SetAllPoints(iconFrame)
                    end
                end
                if styleCache.hideIconOverlayTexture then
                    RemoveBlizzardIconMask(iconTex, "cdmBarIconMaskRemoved")
                elseif iconTex.cdmBarIconMaskRemoved then
                    RestoreBlizzardIconMask(iconTex, "cdmBarIconMaskRemoved")
                end
                CDM_C.ApplyIconTexCoord(iconTex, zoomAmount, iconSize, iconSize)
                DisableTextureSnap(iconTex)
            end

            ApplyOverlayVisibility(styleCache.hideIconOverlay, styleCache.hideIconOverlayTexture, iconFrame:GetRegions())

            EnsureIconBorder(frame, iconFrame, "cdmIconBorder", styleCache.isBorderActive, borderVersion)
        end
    end
    if bar then
        bar:ClearAllPoints()
        bar:SetHeight(barHeight)

        if iconPosition == "HIDDEN" then
            SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        elseif iconPosition == "RIGHT" then
            SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            SetPoint(bar, "RIGHT", iconFrame or frame, iconFrame and "LEFT" or "RIGHT", iconFrame and -iconGap or 0, 0)
        else
            SetPoint(bar, "LEFT", iconFrame or frame, iconFrame and "RIGHT" or "LEFT", iconFrame and iconGap or 0, 0)
            SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        end

        bar:SetStatusBarTexture(barTexture)
        DisableTextureSnap(bar:GetStatusBarTexture())
        bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
        if bar.SetReverseFill then
            bar:SetReverseFill(fillDirection == "LEFT_TO_RIGHT")
        end

        if not frame.cdmBarBackground then
            frame.cdmBarBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        end
        frame.cdmBarBackground:ClearAllPoints()
        frame.cdmBarBackground:SetAllPoints(bar)
        DisableTextureSnap(frame.cdmBarBackground)
        frame.cdmBarBackground:SetTexture(barTexture)
        frame.cdmBarBackground:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.8)

        local nameText = bar.Name
        local durationText = bar.Duration
        local wantsNameText = showName and nameText
        local wantsDurationText = showDuration and durationText

        if wantsNameText or wantsDurationText then
            if not frame.cdmBarTextContainer then
                frame.cdmBarTextContainer = CreateFrame("Frame", nil, bar)
                frame.cdmBarTextContainer:SetAllPoints(bar)
            end
            frame.cdmBarTextContainer:SetFrameLevel(bar:GetFrameLevel() + 6)
            frame.cdmBarTextContainer:Show()

            if nameText then
                InstallBuffBarVisibilityShowHook(frame, "cdmNameHooked", nameText, "cdmResolvedShowName")
                InstallBarNameTextHook(frame, nameText)
                nameText:SetParent(frame.cdmBarTextContainer)
                if showName then
                    nameText:SetAlpha(1)
                    nameText:Show()
                    nameText:SetIgnoreParentScale(true)
                    nameText:SetFont(fontPath, FontSize(nameFontSize), textFontOutline)
                    nameText:SetTextColor(nameColor.r, nameColor.g, nameColor.b, nameColor.a or 1)
                    nameText:SetShadowOffset(0, 0)
                    nameText:SetDrawLayer("OVERLAY", 7)
                    nameText:SetWordWrap(false)
                    nameText:SetNonSpaceWrap(false)
                    nameText:ClearAllPoints()
                    SetPoint(nameText, "LEFT", bar, "LEFT", nameOffsetX, nameOffsetY)
                    if nameMaxChars and nameMaxChars > 0 then
                        nameText:SetWidth(Snap(nameMaxChars * FontSize(nameFontSize) * 0.55))
                    else
                        SetPoint(nameText, "RIGHT", bar, "RIGHT", -30, nameOffsetY)
                        nameText:SetWidth(0)
                    end
                else
                    nameText:Hide()
                    nameText:SetAlpha(0)
                end
            end

            if durationText then
                InstallBuffBarVisibilityShowHook(frame, "cdmDurationHooked", durationText, "cdmResolvedShowDuration")
                durationText:SetParent(frame.cdmBarTextContainer)
                if showDuration then
                    durationText:SetAlpha(1)
                    durationText:Show()
                    durationText:SetIgnoreParentScale(true)
                    durationText:SetFont(fontPath, FontSize(durationFontSize), textFontOutline)
                    durationText:SetTextColor(durationColor.r, durationColor.g, durationColor.b, durationColor.a or 1)
                    durationText:SetShadowOffset(0, 0)
                    durationText:SetDrawLayer("OVERLAY", 7)
                    durationText:SetJustifyH(durationPosition)
                    durationText:ClearAllPoints()
                    if durationPosition == "CENTER" then
                        SetPoint(durationText, "CENTER", frame, "CENTER", durationOffsetX, durationOffsetY)
                    else
                        SetPoint(durationText, durationPosition, bar, durationPosition, durationOffsetX, durationOffsetY)
                    end
                else
                    durationText:Hide()
                    durationText:SetAlpha(0)
                end
            end
        else
            if frame.cdmBarTextContainer then frame.cdmBarTextContainer:Hide() end
            if bar.Name then bar.Name:Hide(); bar.Name:SetAlpha(0) end
            if bar.Duration then bar.Duration:Hide(); bar.Duration:SetAlpha(0) end
        end

        local appText = iconFrame and iconFrame.Applications
        if appText then
            local canShowApplications = showApplications
            if canShowApplications then
                if not frame.cdmBarAppTextContainer then
                    frame.cdmBarAppTextContainer = CreateFrame("Frame", nil, bar)
                    frame.cdmBarAppTextContainer:SetAllPoints(bar)
                end
                frame.cdmBarAppTextContainer:SetFrameLevel(bar:GetFrameLevel() + 6)

                frame.cdmBarAppTextContainer:Show()
                InstallBuffBarVisibilityShowHook(frame, "cdmAppHooked", appText, "cdmResolvedShowApplications")
                appText:SetParent(frame.cdmBarAppTextContainer)
                appText:SetAlpha(1)
                appText:Show()
                appText:SetIgnoreParentScale(true)
                appText:SetFont(fontPath, FontSize(appFontSize), textFontOutline)
                appText:SetTextColor(appColor.r, appColor.g, appColor.b, appColor.a or 1)
                appText:SetShadowOffset(0, 0)
                appText:SetDrawLayer("OVERLAY", 7)
                appText:SetJustifyH("CENTER")
                appText:SetSize(0, 0)
                appText:ClearAllPoints()
                if appPosition == "CENTER" then
                    SetPoint(appText, "CENTER", frame, "CENTER", appOffsetX, appOffsetY)
                else
                    SetPoint(appText, "CENTER", bar, appPosition, appOffsetX, appOffsetY)
                end
            else
                if frame.cdmBarAppTextContainer then frame.cdmBarAppTextContainer:Hide() end
                appText:Hide()
                appText:SetAlpha(0)
            end
        end

        EnsureIconBorder(frame, bar, "cdmBarBorder", styleCache.isBorderActive, borderVersion)
    end

    frame.cdmLastBarStyleVersion = styleVersion
    frame.cdmLastBarW = targetFrameWidth
    frame.cdmLastBarH = targetFrameHeight
    frame.cdmLastBarOv = spellOv

    frame.cdmBarStyled = true

    if customNameChanged and frame.RefreshName then
        frame:RefreshName()
    end
end

CDM:RegisterRefreshCallback("pandemicCDMStyle", function()
    CDM:ForEachActiveFrame(CDM_C.ALL_VIEWER_NAMES, function(itemFrame)
        if itemFrame.cdmPandemicActive then
            ClearPandemicCDMStyle(itemFrame)
            ApplyPandemicCDMStyle(itemFrame)
        end
    end)
end, 30, { "STYLE" })

function CDM:InstallStyleAcquireResetHook(v)
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        itemFrame.cdmInternalWrite = nil
        itemFrame.cdmLastCooldownStyleVer = nil
        itemFrame.cdmIsProcessingBuffOverride = nil
        itemFrame.cdmLastAuraActive = nil
        itemFrame.cdmLastBuffBorderSpellID = nil
        itemFrame.cdmLastBuffBorderCatID = nil
        itemFrame.cdmLastBuffBorderColorVer = nil
        itemFrame.cdmLastBuffBorderStyleVer = nil
        itemFrame.cdmLastBarOv = nil
        itemFrame.cdmResolvedShowName = nil
        itemFrame.cdmResolvedShowDuration = nil
        itemFrame.cdmResolvedShowApplications = nil
        itemFrame.cdmResolvedCustomName = nil
    end)
end
