local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local BORDER = CDM.BORDER
local LSM = LibStub("LibSharedMedia-3.0", true)
local CDM_C = CDM.CONST

local GetFrameData = CDM.GetFrameData
local IsSafeNumber = CDM.IsSafeNumber
local GetColorForSpellID = CDM.GetColorForSpellID
local GetBaseSpellID = CDM.GetBaseSpellID
local GetSpellIDCandidates = CDM.GetSpellIDCandidates

local math_floor = math.floor
local math_max = math.max
local math_abs = math.abs
local GetTime = GetTime
local issecretvalue = issecretvalue
local select = select
local ipairs = ipairs
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration
local GetSpellChargeDuration = C_Spell.GetSpellChargeDuration

local VIEWERS = CDM_C.VIEWERS
local VIEWERS_WITH_OVERRIDE = CDM_C.VIEWERS_WITH_OVERRIDE
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local styleBorderCtx = { active = false, color = nil, version = 0, force = false }
local iconBorderCtx = { active = false, color = nil, version = 0 }
local barBorderCtx = { active = false, color = nil, version = 0 }

local VIEWER_DESC = {
    [VIEWERS.ESSENTIAL] = {
        sizeKey      = "SIZE_ESS_ROW1",
        sizeKey2     = "SIZE_ESS_ROW2",
        cdFontKey    = "cooldownFontSize",
        cdFontKey2   = "essRow2CooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "chargeFontSize",
        isCooldown   = true,
        hasOverride  = true,
        hasKeybind   = true,
        hookType     = "cooldown",
    },
    [VIEWERS.UTILITY] = {
        sizeKey      = "SIZE_UTILITY",
        cdFontKey    = "utilityCooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "utilityChargeFontSize",
        isCooldown   = true,
        hasOverride  = true,
        hasKeybind   = true,
        hookType     = "cooldown",
        hasUtilVisibility = true,
    },
    [VIEWERS.BUFF] = {
        sizeKey      = "SIZE_BUFF",
        cdFontKey    = "buffCooldownFontSize",
        cdColorKey   = "buffCooldownColor",
        isBuff       = true,
        hasCount     = true,
        hookType     = "buff",
    },
    [VIEWERS.BUFF_BAR] = {
        hookType     = "bar",
    },
    ["CDM_Racials"] = {
        sizeKey      = "SIZE_RACIALS",
        cdFontKey    = "racialsCooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "racialsChargeFontSize",
        isCooldown   = true,
        hookType     = "cooldown",
    },
    ["CDM_Defensives"] = {
        sizeKey      = "SIZE_DEFENSIVES",
        cdFontKey    = "defensivesCooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "defensivesChargeFontSize",
        isCooldown   = true,
        hookType     = "cooldown",
    },
    ["CDM_Trinkets"] = {
        sizeKey      = "SIZE_TRINKETS",
        cdFontKey    = "trinketsCooldownFontSize",
        cdColorKey   = "cooldownColor",
        chargeKey    = "chargeFontSize",
        isCooldown   = true,
        hookType     = "cooldown",
    },
}

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
local DEFAULT_WHITE_COLOR = { r = 1, g = 1, b = 1, a = 1 }

function CDM_C.GetEffectiveZoomAmount()
    if lastStyleCacheVersion < 0 then
        if not CDM_C.GetConfigValue("zoomIcons", true) then return 0 end
        local v = CDM_C.GetConfigValue("zoomAmount", 0.08)
        return (type(v) == "number") and v or 0.08
    end
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
    styleCache.textFont = CfgValue(db, defaults, "textFont", "Friz Quadrata TT")
    local rawOutline = CfgValue(db, defaults, "textFontOutline", "OUTLINE")
    styleCache.textFontOutline = CDM_C.ResolveOutlineFlags(rawOutline)

    styleCache.cooldownFontSize = CfgValue(db, defaults, "cooldownFontSize", 12)
    styleCache.cooldownColor = CfgValue(db, defaults, "cooldownColor", DEFAULT_WHITE_COLOR)
    styleCache.racialsCooldownFontSize = CfgValue(db, defaults, "racialsCooldownFontSize", 12)
    styleCache.defensivesCooldownFontSize = CfgValue(db, defaults, "defensivesCooldownFontSize", 12)
    styleCache.trinketsCooldownFontSize = CfgValue(db, defaults, "trinketsCooldownFontSize", 12)
    styleCache.externalsCooldownFontSize = CfgValue(db, defaults, "externalsCooldownFontSize", 15)
    styleCache.essRow2CooldownFontSize = CfgValue(db, defaults, "essRow2CooldownFontSize", 15)
    styleCache.utilityCooldownFontSize = CfgValue(db, defaults, "utilityCooldownFontSize", 15)

    styleCache.chargeFontSize = CfgValue(db, defaults, "chargeFontSize", 12)
    styleCache.utilityChargeFontSize = CfgValue(db, defaults, "utilityChargeFontSize", 12)
    styleCache.racialsChargeFontSize = CfgValue(db, defaults, "racialsChargeFontSize", 15)
    styleCache.defensivesChargeFontSize = CfgValue(db, defaults, "defensivesChargeFontSize", 15)
    styleCache.chargeColor = CfgValue(db, defaults, "chargeColor", DEFAULT_WHITE_COLOR)
    styleCache.chargePosition = CfgValue(db, defaults, "chargePosition", "BOTTOMRIGHT")
    styleCache.chargeOffsetX = CfgValue(db, defaults, "chargeOffsetX", 0)
    styleCache.chargeOffsetY = CfgValue(db, defaults, "chargeOffsetY", 0)

    styleCache.countFontSize = CfgValue(db, defaults, "countFontSize", 12)
    styleCache.countColor = CfgValue(db, defaults, "countColor", DEFAULT_WHITE_COLOR)

    styleCache.buffCooldownFontSize = CfgValue(db, defaults, "buffCooldownFontSize", 12)
    styleCache.buffCooldownColor = CfgValue(db, defaults, "buffCooldownColor", DEFAULT_WHITE_COLOR)

    styleCache.countPositionMain = CfgValue(db, defaults, "countPositionMain", "TOP")
    styleCache.countOffsetXMain = CfgValue(db, defaults, "countOffsetXMain", 0)
    styleCache.countOffsetYMain = CfgValue(db, defaults, "countOffsetYMain", 0)
    styleCache.borderColor = CfgValue(db, defaults, "borderColor", DEFAULT_WHITE_COLOR)

    styleCache.hideDebuffBorder = CfgValue(db, defaults, "hideDebuffBorder", false)
    styleCache.hidePandemicIndicator = CfgValue(db, defaults, "hidePandemicIndicator", false)
    styleCache.hideCooldownBling = CfgValue(db, defaults, "hideCooldownBling", false)

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
    styleCache.buffBarDualMode = CfgValue(db, defaults, "buffBarDualMode", false)
    styleCache.buffBarNameFontSize = CfgValue(db, defaults, "buffBarNameFontSize", 12)
    styleCache.buffBarNameColor = CfgValue(db, defaults, "buffBarNameColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarNameOffsetX = CfgValue(db, defaults, "buffBarNameOffsetX", 4)
    styleCache.buffBarNameOffsetY = CfgValue(db, defaults, "buffBarNameOffsetY", 0)
    styleCache.buffBarDurationFontSize = CfgValue(db, defaults, "buffBarDurationFontSize", 12)
    styleCache.buffBarDurationColor = CfgValue(db, defaults, "buffBarDurationColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarDurationOffsetX = CfgValue(db, defaults, "buffBarDurationOffsetX", -4)
    styleCache.buffBarDurationOffsetY = CfgValue(db, defaults, "buffBarDurationOffsetY", 0)
    styleCache.buffBarShowApplications = CfgValue(db, defaults, "buffBarShowApplications", true)
    styleCache.buffBarApplicationsFontSize = CfgValue(db, defaults, "buffBarApplicationsFontSize", 15)
    styleCache.buffBarApplicationsColor = CfgValue(db, defaults, "buffBarApplicationsColor", { r = 1, g = 1, b = 1, a = 1 })
    styleCache.buffBarApplicationsPosition = CfgValue(db, defaults, "buffBarApplicationsPosition", "CENTER")
    styleCache.buffBarApplicationsOffsetX = CfgValue(db, defaults, "buffBarApplicationsOffsetX", 0)
    styleCache.buffBarApplicationsOffsetY = CfgValue(db, defaults, "buffBarApplicationsOffsetY", 0)

    styleCache.assistFontSize = CfgValue(db, defaults, "assistFontSize", 15)
    styleCache.assistColor = CfgValue(db, defaults, "assistColor", DEFAULT_WHITE_COLOR)
    styleCache.assistPosition = CfgValue(db, defaults, "assistPosition", "TOPRIGHT")
    styleCache.assistOffsetX = CfgValue(db, defaults, "assistOffsetX", 0)
    styleCache.assistOffsetY = CfgValue(db, defaults, "assistOffsetY", 0)

    styleCache.isOneBorderMode = Pixel.IsOneBorderMode()
    styleCache.isBorderActive = CfgValue(db, defaults, "borderFile", "1 Pixel") ~= "None"
    styleCache.borderSize = CfgValue(db, defaults, "borderSize", 1)

    CDM_C.RefreshBaseFontCache()
    styleCache.fontPath = CDM_C.GetBaseFontPath()

    cdFont:SetFont(styleCache.fontPath, Pixel.FontSize(styleCache.cooldownFontSize), styleCache.textFontOutline)
    cdFontBuff:SetFont(styleCache.fontPath, Pixel.FontSize(styleCache.buffCooldownFontSize), styleCache.textFontOutline)
end

CDM.RefreshStyleCache = RefreshStyleCache

local DesaturationCurve = CDM_C.DesaturationCurve


local function StyleCooldownTextElement(text, fontPath, fontSize, fontOutline, color, init)
    if not text or not text.SetFont then return end
    color = color or DEFAULT_WHITE_COLOR
    if init then
        text:SetIgnoreParentScale(true)
        text:ClearAllPoints()
        text:SetPoint("CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetShadowOffset(0, 0)
        text:SetDrawLayer("OVERLAY", 7)
    end
    text:SetFont(fontPath, Pixel.FontSize(fontSize), fontOutline)
    text:SetTextColor(color.r, color.g, color.b)
end

local function SafeEquals(v, expected)
    return (type(v) ~= "number" or not issecretvalue(v)) and v == expected
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

local function GetSpellIDForCooldown(frame)
    if not frame then return nil end
    if frame.isCustomBuff then
        return IsSafeNumber(frame.spellID) and frame.spellID or nil
    end
    local info = frame.cooldownInfo
    if not info then return nil end
    local id = info.overrideSpellID or info.spellID
    return IsSafeNumber(id) and id or nil
end

local function ApplyAuraStateBody(frame, spellID, frameData)
    local tex = frame.Icon

    local hasChargeSource = false
    if type(frame.HasVisualDataSource_Charges) == "function" then
        hasChargeSource = not not frame:HasVisualDataSource_Charges()
    end
    local chargeDurObj = hasChargeSource and spellID and GetSpellChargeDuration(spellID)
    local useChargePath = hasChargeSource and chargeDurObj

    local realDur, desatValue
    if not useChargePath then
        realDur = spellID and GetSpellCooldownDuration(spellID, true)
        desatValue = (realDur and realDur:EvaluateRemainingDuration(DesaturationCurve, 0)) or 0
    end

    local swipeDur
    if useChargePath then
        swipeDur = chargeDurObj
    elseif styleCache.hideGCDSwipe then
        swipeDur = realDur
    else
        swipeDur = spellID and GetSpellCooldownDuration(spellID, false)
    end

    if tex and tex.SetDesaturation then
        if hasChargeSource then
            tex:SetDesaturation(0)
        else
            tex:SetDesaturation(desatValue)
        end
    end

    if frame.Cooldown.SetUseAuraDisplayTime then
        frame.Cooldown:SetUseAuraDisplayTime(false)
    end

    if swipeDur then
        frame.Cooldown:SetCooldownFromDurationObject(swipeDur)
        frame.Cooldown:SetDrawSwipe(true)
    else
        frame.Cooldown:Clear()
    end

    local sc = styleCache.swipeColor or CDM_C.SWIPE_COLOR
    frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    frame.Cooldown:SetDrawEdge(false)
end

local function FindAuraOverlayEntry(frame)
    local map = CDM._auraOverlayEnabled
    if not map then return nil end
    local cdID = frame and frame.cooldownID
    if cdID and map[cdID] then return map[cdID] end
    return nil
end

local function DetectAuraActive(frame)
    local swipeColor = frame.cooldownSwipeColor
    if swipeColor and type(swipeColor) ~= "number" and swipeColor.GetRGBA then
        local r = swipeColor:GetRGBA()
        if r and type(r) == "number" and not issecretvalue(r) then
            return r ~= 0
        end
    end
    return false
end

local function ApplyAuraOverlayActive(frame, frameData, entry)
    frame.Cooldown:SetReverse(true)
    frame.Cooldown:SetAlpha(1)
    local sc = styleCache.swipeColor or CDM_C.SWIPE_COLOR
    frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    frame.Cooldown:SetDrawEdge(false)
    if frame.Cooldown.SetUseAuraDisplayTime then
        frame.Cooldown:SetUseAuraDisplayTime(true)
    end
    if frame.Icon then
        frame.Icon:SetDesaturation(0)
    end

    if entry.auraGlowEnabled then
        CDM.Glow:RequestBuffGlow(frame, true, entry.auraGlowColor, nil)
        frameData.cdmAuraGlowActive = true
    elseif frameData.cdmAuraGlowActive then
        CDM.Glow:RequestBuffGlow(frame, false)
        frameData.cdmAuraGlowActive = false
    end

    if entry.auraBorderEnabled then
        BORDER:ApplyBorderColorOverride(frame, entry.auraBorderColor or DEFAULT_WHITE_COLOR)
        frameData.cdmAuraBorderActive = true
    elseif frameData.cdmAuraBorderActive then
        BORDER:RestoreToCurrentBorderColor(frame)
        frameData.cdmAuraBorderActive = false
    end

    frameData.cdmAuraOverrideActive = true
end

local function ApplyAuraOverlayInactive(frame, frameData)
    if frame.Cooldown.SetDrawSwipe then
        frame.Cooldown:SetDrawSwipe(false)
    end
    if frame.Icon then
        frame.Icon:SetDesaturation(1)
    end

    if frameData.cdmAuraGlowActive then
        CDM.Glow:RequestBuffGlow(frame, false)
        frameData.cdmAuraGlowActive = false
    end
    if frameData.cdmAuraBorderActive then
        BORDER:RestoreToCurrentBorderColor(frame)
        frameData.cdmAuraBorderActive = false
    end

    frameData.cdmAuraOverrideActive = true
end

local function ClearAuraOverlay(frame, frameData)
    if frameData.cdmAuraOverrideActive then
        frame.Cooldown:SetAlpha(1)
        frame.Cooldown:SetReverse(false)
        if frame.Icon then
            frame.Icon:SetDesaturation(0)
        end
        frameData.cdmAuraOverrideActive = false
    end
    if frameData.cdmAuraGlowActive then
        CDM.Glow:RequestBuffGlow(frame, false)
        frameData.cdmAuraGlowActive = false
    end
    if frameData.cdmAuraBorderActive then
        BORDER:RestoreToCurrentBorderColor(frame)
        frameData.cdmAuraBorderActive = false
    end
end

local function ClearReadyGlow(frame, frameData)
    if frameData.cdmReadyGlowActive then
        if not frameData.cdmAuraGlowActive then
            CDM.Glow:RequestBuffGlow(frame, false)
        end
        frameData.cdmReadyGlowActive = false
    end
end

local function ApplyReadyGlow(frame, frameData, entry)
    if frameData.cdmReadyGlowActive and frameData.cdmBuffGlowOverrideColor == entry.readyGlowColor then
        local host = frameData.cdmBuffGlowHost
        if host and host:IsShown() and host:GetWidth() >= 1 and GetFrameData(host).cdmGlowActive then
            return
        end
    end
    CDM.Glow:RequestBuffGlow(frame, true, entry.readyGlowColor, nil)
    frameData.cdmReadyGlowActive = true
end

local function GetReadyGlowDecision(frame, frameData, entry, spellID)
    if not entry or not entry.readyGlowEnabled then
        return true, false
    end
    if frameData.cdmAuraOverrideActive then
        return true, false
    end
    if not spellID then
        return false, false
    end

    local cdInfo = GetSpellCooldown(spellID)
    if not cdInfo then return false, false end
    return true, not cdInfo.isActive or cdInfo.isOnGCD
end

local function SyncReadyGlow(frame, frameData, entry, spellID)
    local decisionKnown, shouldShowReadyGlow = GetReadyGlowDecision(frame, frameData, entry, spellID)
    if not decisionKnown then
        return
    end

    if shouldShowReadyGlow then
        ApplyReadyGlow(frame, frameData, entry)
    else
        ClearReadyGlow(frame, frameData)
    end
end

function CDM:ApplyAuraOverride(frame, cachedEntry)
    if not frame then return end
    local frameData = GetFrameData(frame)
    local vName = frameData.cdmViewerName
    if not vName or not VIEWERS_WITH_OVERRIDE[vName] then return end
    if frameData.isProcessingOverride then return end

    frameData.isProcessingOverride = true

    local spellID = GetSpellIDForCooldown(frame)
    if not spellID then
        ClearAuraOverlay(frame, frameData)
        ClearReadyGlow(frame, frameData)
        frameData.isProcessingOverride = false
        return
    end

    local entry = cachedEntry or FindAuraOverlayEntry(frame)
    local auraActive = DetectAuraActive(frame)
    frameData.cdmLastAuraActive = auraActive

    if entry and entry.auraOverlay then
        if auraActive then
            ApplyAuraOverlayActive(frame, frameData, entry)
        elseif entry.auraDesaturateInactive then
            ApplyAuraOverlayInactive(frame, frameData)
        else
            ClearAuraOverlay(frame, frameData)
            ApplyAuraStateBody(frame, spellID, frameData)
        end
    else
        ClearAuraOverlay(frame, frameData)
        ApplyAuraStateBody(frame, spellID, frameData)
    end

    SyncReadyGlow(frame, frameData, entry, spellID)

    frameData.isProcessingOverride = false
end

function CDM:ApplyBuffVisualState(frame)
    if not frame then return end

    if styleCache.hideDebuffBorder and frame.DebuffBorder then
        frame.DebuffBorder:Hide()
    end
end

function CDM:ProcessBuffViewerOverrides(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    if frameData.isProcessingBuffOverride then return end

    frameData.isProcessingBuffOverride = true
    self:ApplyBuffVisualState(frame)
    frameData.isProcessingBuffOverride = false
end

local function EnsureCooldownStateInit(frame, frameData)
    if not frame or not frame.Cooldown then return end

    if not frameData.cdmCooldownInitDone then
        if frame.Cooldown.SetDrawEdge then
            frame.Cooldown:SetDrawEdge(false)
        end
        frameData.cdmCooldownInitDone = true
    end

    local styleVersion = CDM.styleCacheVersion or 0
    if frameData.cdmLastCooldownStyleVer == styleVersion then return end
    frameData.cdmLastCooldownStyleVer = styleVersion

    if frame.Cooldown.SetSwipeColor then
        local sc = styleCache.swipeColor or CDM_C.SWIPE_COLOR
        frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end

    if frame.Cooldown.SetSwipeTexture then
        if styleCache.zoomIcons then
            frame.Cooldown:SetSwipeTexture(CDM_C.TEX_WHITE8X8)
        else
            frame.Cooldown:SetSwipeTexture(DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE)
        end
    end
end

local function EnsureFrameHooks(frame, frameData, hookType)
    if not frame then return end

    if hookType ~= "bar" then
        EnsureCooldownStateInit(frame, frameData)
    end

    if (hookType == "buff" or hookType == "bar") and frame.DebuffBorder and not frameData.debuffBorderHooked then
        frameData.debuffBorderHooked = true
        hooksecurefunc(frame.DebuffBorder, "Show", function(self)
            if styleCache.hideDebuffBorder and not frameData.isProcessingBuffOverride then
                self:Hide()
            end
        end)
    end

    if (hookType == "cooldown" or hookType == "bar") and frame.CooldownFlash and not frameData.cooldownFlashHooked then
        frameData.cooldownFlashHooked = true
        hooksecurefunc(frame.CooldownFlash, "Show", function(self)
            if styleCache.hideCooldownBling then
                self:Hide()
                if self.FlashAnim then
                    self.FlashAnim:Stop()
                end
            end
        end)
    end

    if frame.ShowPandemicStateFrame and not frameData.pandemicHooked then
        frameData.pandemicHooked = true
        hooksecurefunc(frame, "ShowPandemicStateFrame", function(self)
            local selfData = GetFrameData(self)
            if styleCache.hidePandemicIndicator and self.PandemicIcon and not selfData.isProcessingBuffOverride then
                self.PandemicIcon:Hide()
            end
        end)
    end
end

local function InvalidateUtilCache()
    if CDM.InvalidateUtilityVisibleCountCache then
        CDM:InvalidateUtilityVisibleCountCache()
    end
end

local function SetupUtilityVisibilityHooks(frame, frameData)
    if not frame or frameData.cdmUtilityVisibilityHooked or not frame.HookScript then
        return
    end

    frameData.cdmUtilityVisibilityHooked = true
    frame:HookScript("OnShow", InvalidateUtilCache)
    frame:HookScript("OnHide", InvalidateUtilCache)
end

local function ApplyIconTextureLayout(texture, frame, iconWidth, iconHeight, zoomAmount)
    CDM_C.ApplyIconTexCoord(texture, zoomAmount, iconWidth, iconHeight)
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
    Pixel.DisableTextureSnap(texture)
end

local function RemoveBlizzardIconMask(iconFrame, iconTexture, frameData, flagName)
    if not (iconFrame and iconTexture and iconTexture.RemoveMaskTexture and frameData) then
        return
    end

    if frameData[flagName] then
        return
    end

    local regions = { iconFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.IsObjectType and region:IsObjectType("MaskTexture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_MASK_ATLAS) then
                pcall(iconTexture.RemoveMaskTexture, iconTexture, region)
                frameData[flagName] = true
                frameData[flagName .. "Source"] = region
                break
            end
        end
    end
end

local function RestoreBlizzardIconMask(iconTexture, frameData, flagName)
    if not (iconTexture and iconTexture.AddMaskTexture and frameData) then
        return
    end
    if not frameData[flagName] then
        return
    end
    local source = frameData[flagName .. "Source"]
    if source then
        pcall(iconTexture.AddMaskTexture, iconTexture, source)
    end
    frameData[flagName] = false
    frameData[flagName .. "Source"] = nil
end

local function EnsureIconBorder(store, host, borderKey, ctx)
    local bf = store[borderKey]

    if not ctx.active then
        if bf and bf.border then
            bf.border:Hide()
        end
        return
    end

    if not bf then
        bf = CreateFrame("Frame", nil, host)
        bf:SetAllPoints()
        store[borderKey] = bf
    end

    local versionKey = borderKey .. "Version"
    local needRefresh = ctx.force or store[versionKey] ~= ctx.version or not bf.border

    if needRefresh then
        BORDER:CreateBorder(bf, { forceUpdate = true })
        store[versionKey] = ctx.version
        local inner = bf.border
        if inner and inner.SetBackdropBorderColor then
            local color = ctx.color or styleCache.borderColor
            inner:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        end
    elseif bf.border and not bf.border:IsShown() then
        bf.border:Show()
    end
end

local RefreshKeybindForFrame

function CDM:ApplyStyle(frame, vName, forceUpdate)
    if not frame then return end

    local frameData = GetFrameData(frame)
    frameData.cdmViewerName = vName
    local fullUpdate = forceUpdate or not frameData.hooksInitialized or frameData.cdmLastStyledVName ~= vName
    local styleVersion = CDM.styleCacheVersion or 0

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local sizes = CDM.Sizes
    if not sizes then return end

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
    elseif desc and desc.sizeKey then
        local sizeKey = (desc.sizeKey2 and frameData.cdmRow == 2) and desc.sizeKey2 or desc.sizeKey
        local s = sizes[sizeKey]
        iconWidth = Snap(s.w)
        iconHeight = Snap(s.h)
    else
        iconWidth = Snap(30)
        iconHeight = Snap(30)
    end

    local fontSpellID = isCooldown and GetSpellIDForCooldown(frame) or nil

    local actualW = frame:GetWidth() or 0
    local actualH = frame:GetHeight() or 0

    local currentCatID = frameData.buffCategorySpellID
    local currentBorderOverride = frameData.cdmBorderColorOverride
    local currentBorderStyleVer = CDM.borderStyleVersion or 0

    local needsVisualUpdate = fullUpdate
        or frameData.cdmLastStyleVersion ~= styleVersion
        or frameData.cdmLastStyledW ~= iconWidth
        or frameData.cdmLastStyledH ~= iconHeight
        or frameData.cdmLastFontSpellID ~= fontSpellID
        or (isBuff and frameData.cdmLastBuffCatID ~= currentCatID)
        or (isBuff and frameData.cdmLastBorderOverride ~= currentBorderOverride)
        or (isBuff and frameData.cdmLastBorderStyleVer ~= currentBorderStyleVer)
        or (actualW > 1 and math_abs(actualW - iconWidth) > 0.01)
        or (actualH > 1 and math_abs(actualH - iconHeight) > 0.01)

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
        local tex = frame.Icon
        local hasTexture = tex ~= nil and (type(tex) ~= "number" or not issecretvalue(tex))

        if hasTexture then
            ApplyIconTextureLayout(tex, frame, iconWidth, iconHeight, zoomAmount)
        end

        if frame.Cooldown then
            frame.Cooldown:ClearAllPoints()
            frame.Cooldown:SetAllPoints(frame)

            if frame.Cooldown.SetCountdownFont then
                frame.Cooldown:SetCountdownFont(isBuff and "AyijeCDM_CDFont_Buff" or "AyijeCDM_CDFont")
            end
        end

        local hideAtlas = styleCache.hideIconOverlay
        local hideTexture = styleCache.hideIconOverlayTexture
        if fullUpdate
            or frameData.cdmOverlayAtlasHidden ~= hideAtlas
            or frameData.cdmOverlayTextureHidden ~= hideTexture then
            ApplyOverlayVisibility(hideAtlas, hideTexture, frame:GetRegions())
            frameData.cdmOverlayAtlasHidden = hideAtlas
            frameData.cdmOverlayTextureHidden = hideTexture
        end

        if hideTexture then
            local iconTex = frame.Icon
            if iconTex then
                RemoveBlizzardIconMask(frame, iconTex, frameData, "cdmIconMaskRemoved")
            end
        elseif frameData.cdmIconMaskRemoved then
            RestoreBlizzardIconMask(frame.Icon, frameData, "cdmIconMaskRemoved")
        end

        styleBorderCtx.active = borderActive
        styleBorderCtx.color = frameData.cdmBorderColorOverride or styleCache.borderColor
        styleBorderCtx.version = CDM.borderStyleVersion or 0
        styleBorderCtx.force = forceUpdate
        EnsureIconBorder(frameData, frame, "borderFrame", styleBorderCtx)

        if isCooldown then
            if frame.ChargeCount then
                frame.ChargeCount:SetFrameLevel(frame:GetFrameLevel() + 7)
            end

            local chargeText = frame.ChargeCount and frame.ChargeCount.Current
            if chargeText then
                if not frameData.cdmChargeTextHooked then
                    frameData.cdmChargeTextHooked = true
                    hooksecurefunc(chargeText, "SetText", function(self, value)
                        if type(value) == "number" and C_StringUtil and C_StringUtil.TruncateWhenZero then
                            self:SetText(C_StringUtil.TruncateWhenZero(value))
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
                countText:SetFont(fontPath, Pixel.FontSize(styleCache.countFontSize), textFontOutline)
                countText:SetTextColor(styleCache.countColor.r, styleCache.countColor.g, styleCache.countColor.b)
                countText:SetDrawLayer("OVERLAY", 7)
                countText:SetShadowOffset(0, 0)

                if desc and desc.hasCount then
                    countText:ClearAllPoints()
                    countText:SetPoint(styleCache.countPositionMain, frame, styleCache.countPositionMain,
                        styleCache.countOffsetXMain, styleCache.countOffsetYMain)
                end

                frameData.countStyle = nil
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
                    effectiveChargeColor = effectiveChargeColor or styleCache.chargeColor
                else
                    local ov = spellID and CDM:GetUngroupedCooldownOverride(spellID)
                    if ov and ov.textOverride then
                        local db = CDM.db
                        effectiveCdFontSize = ov.cooldownFontSize or (db and db.cooldownFontSize or 15)
                        effectiveCdColor = ov.cooldownColor or (db and db.cooldownColor) or styleCache.cooldownColor
                        effectiveChargeFS = ov.chargeFontSize or (db and db.chargeFontSize or 15)
                        effectiveChargeColor = ov.chargeColor or (db and db.chargeColor) or styleCache.chargeColor
                        effectiveChargePos = ov.chargePosition or (db and db.chargePosition or "BOTTOMRIGHT")
                        effectiveChargeOX = ov.chargeOffsetX or (db and db.chargeOffsetX or 0)
                        effectiveChargeOY = ov.chargeOffsetY or (db and db.chargeOffsetY or 0)
                    else
                        local cdFontKey = (desc.cdFontKey2 and frameData.cdmRow == 2) and desc.cdFontKey2 or desc.cdFontKey
                        effectiveCdFontSize = styleCache[cdFontKey]
                        effectiveCdColor = styleCache[desc.cdColorKey]
                        effectiveChargeFS = desc.chargeKey and styleCache[desc.chargeKey] or styleCache.chargeFontSize
                        effectiveChargeColor = styleCache.chargeColor
                        effectiveChargePos = styleCache.chargePosition
                        effectiveChargeOX = styleCache.chargeOffsetX
                        effectiveChargeOY = styleCache.chargeOffsetY
                    end
                end
            else
                local cdFontKey = desc and ((desc.cdFontKey2 and frameData.cdmRow == 2) and desc.cdFontKey2 or desc.cdFontKey) or "cooldownFontSize"
                effectiveCdFontSize = styleCache[cdFontKey]
                effectiveCdColor = styleCache[desc and desc.cdColorKey or "cooldownColor"]
            end

            local cooldownText = frame.Cooldown and (frame.Cooldown.Text or frame.Cooldown.text)
            StyleCooldownTextElement(cooldownText, fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor, fullUpdate)

            if frame.Cooldown then
                StyleCooldownFontStringsInRegions(
                    fontPath, effectiveCdFontSize, textFontOutline, effectiveCdColor,
                    fullUpdate, frame.Cooldown:GetRegions()
                )
            end

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
                    Pixel.SetPoint(chargeText, effectiveChargePos, frame, effectiveChargePos, effectiveChargeOX, effectiveChargeOY)
                    chargeText:SetFont(fontPath, Pixel.FontSize(effectiveChargeFS), textFontOutline)
                    chargeText:SetTextColor(effectiveChargeColor.r, effectiveChargeColor.g, effectiveChargeColor.b, effectiveChargeColor.a or 1)
                    if fullUpdate then
                        chargeText:SetDrawLayer("OVERLAY", 7)
                        chargeText:SetShadowOffset(0, 0)
                    end
                end
            end
        end

        if isBuff then
            local borderInner = frameData.borderFrame and frameData.borderFrame.border
            if borderInner and borderInner.SetBackdropBorderColor then
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

                local resolvedBorderColor = frameData.cdmResolvedBorderColor
                if not resolvedBorderColor then
                    resolvedBorderColor = {}
                    frameData.cdmResolvedBorderColor = resolvedBorderColor
                end
                resolvedBorderColor.r = r
                resolvedBorderColor.g = g
                resolvedBorderColor.b = b
                resolvedBorderColor.a = 1
                GetFrameData(frameData.borderFrame).cdmResolvedBorderColor = resolvedBorderColor

                borderInner:SetBackdropBorderColor(r, g, b, 1)
                borderInner.backdropBorderColor = resolvedBorderColor
                borderInner.backdropBorderColorAlpha = 1
            end
        end

        frameData.cdmLastStyleVersion = styleVersion
        frameData.cdmLastStyledW = iconWidth
        frameData.cdmLastStyledH = iconHeight
        frameData.cdmLastStyledVName = vName
        frameData.cdmLastFontSpellID = fontSpellID
        frameData.cdmLastBuffCatID = currentCatID
        frameData.cdmLastBorderOverride = currentBorderOverride
        frameData.cdmLastBorderStyleVer = currentBorderStyleVer
    end

    if isBuff and frame.Cooldown then
        frame.Cooldown:SetReverse(true)
    end

    if desc and desc.hasKeybind then
        local KB = CDM.Keybinds
        if KB and KB.IsEnabled and KB:IsEnabled() then
            RefreshKeybindForFrame(frame, frameData, KB, KB:GetCacheVersion(), styleVersion)
        elseif frameData.cdmKeybindContainer then
            frameData.cdmKeybindContainer:Hide()
        end
    end

    if isBuff then
        if fullUpdate and desc then
            EnsureFrameHooks(frame, frameData, desc.hookType)
        end

        self:ProcessBuffViewerOverrides(frame)
    else
        if fullUpdate and desc then
            EnsureFrameHooks(frame, frameData, desc.hookType)
        end
        if desc and desc.hasUtilVisibility then
            SetupUtilityVisibilityHooks(frame, frameData)
        end
    end

    if desc and desc.hasOverride then
        if fullUpdate then
            local iconTex = frame.Icon
            if iconTex and not frameData.cdmDesatHooked then
                frameData.cdmDesatHooked = true
                hooksecurefunc(iconTex, "SetDesaturated", function()
                    local fd = GetFrameData(frame)
                    if fd.isProcessingOverride then return end

                    local entry = FindAuraOverlayEntry(frame)
                    local sid = GetSpellIDForCooldown(frame)

                    if entry then
                        local auraActive = DetectAuraActive(frame)
                        if auraActive ~= fd.cdmLastAuraActive then
                            fd.cdmLastAuraActive = auraActive
                            CDM:ApplyAuraOverride(frame)
                        elseif fd.cdmAuraOverrideActive then
                            if fd.cdmLastAuraActive then
                                ApplyAuraOverlayActive(frame, fd, entry)
                            else
                                ApplyAuraOverlayInactive(frame, fd)
                            end
                        elseif sid then
                            fd.isProcessingOverride = true
                            ApplyAuraStateBody(frame, sid, fd)
                            fd.isProcessingOverride = false
                        end
                    elseif sid then
                        fd.isProcessingOverride = true
                        ApplyAuraStateBody(frame, sid, fd)
                        fd.isProcessingOverride = false
                    end

                    if frame.cooldownID then
                        if entry and entry.readyGlowEnabled then
                            SyncReadyGlow(frame, fd, entry, sid)
                        elseif fd.cdmReadyGlowActive then
                            ClearReadyGlow(frame, fd)
                        end
                    end
                end)
            end
        end

        local overlayEntry = FindAuraOverlayEntry(frame)
        if fullUpdate or overlayEntry then
            self:ApplyAuraOverride(frame, overlayEntry)
        end
    end

    if fullUpdate then
        frameData.hooksInitialized = true
    end
end

RefreshKeybindForFrame = function(frame, frameData, KB, kbCacheVer, styleVersion)
    if not frameData.cdmKeybindContainer then
        local container = CreateFrame("Frame", nil, frame)
        container:SetAllPoints()
        frameData.cdmKeybindContainer = container
        frameData.cdmKeybindFS = container:CreateFontString(nil, "OVERLAY")
        frameData.cdmKeybindFS:SetDrawLayer("OVERLAY", 7)
        frameData.cdmKeybindFS:SetShadowOffset(0, 0)
    end
    frameData.cdmKeybindContainer:SetFrameLevel(frame:GetFrameLevel() + 7)
    frameData.cdmKeybindContainer:Show()

    local baseSpellID = GetBaseSpellID(frame)
    local kbFS = frameData.cdmKeybindFS
    kbFS:SetIgnoreParentScale(true)
    kbFS:ClearAllPoints()
    kbFS:SetPoint(styleCache.assistPosition, frame, styleCache.assistPosition,
                  styleCache.assistOffsetX, styleCache.assistOffsetY)
    local kbFontPath = styleCache.fontPath or CDM_C.GetBaseFontPath()
    local kbOutline = styleCache.textFontOutline
    kbFS:SetFont(kbFontPath, Pixel.FontSize(styleCache.assistFontSize), kbOutline)
    kbFS:SetTextColor(styleCache.assistColor.r, styleCache.assistColor.g, styleCache.assistColor.b)

    local kbText = baseSpellID and KB:GetKeybindText(baseSpellID) or nil
    if not kbText and frame.itemID then
        kbText = KB:GetKeybindTextForItem(frame.itemID)
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
    local viewers = { VIEWERS.ESSENTIAL, VIEWERS.UTILITY }

    for _, vName in ipairs(viewers) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local frameData = GetFrameData(frame)
                if frameData and frameData.cdmKeybindContainer then
                    RefreshKeybindForFrame(frame, frameData, KB, kbCacheVer, styleVersion)
                end
            end
        end
    end

    local trinketFrames = self.GetTrinketIconFrames and self.GetTrinketIconFrames()
    if trinketFrames then
        for _, frame in ipairs(trinketFrames) do
            local frameData = GetFrameData(frame)
            if frameData and frameData.cdmKeybindContainer then
                RefreshKeybindForFrame(frame, frameData, KB, kbCacheVer, styleVersion)
            end
        end
    end
end

local function ShouldShowBuffBarElement(dbKey)
    return styleCache[dbKey] ~= false
end

local function InstallBuffBarVisibilityShowHook(frameData, hookKey, textElement, dbKey)
    if not textElement or frameData[hookKey] then
        return
    end

    frameData[hookKey] = true
    hooksecurefunc(textElement, "Show", function(self)
        if ShouldShowBuffBarElement(dbKey) then
            return
        end
        self:Hide()
        self:SetAlpha(0)
    end)
end

function CDM:ApplyBarStyle(frame, vName, iconPositionOverride, frameWidthOverride, frameHeightOverride)
    if not frame then return end

    local frameData = GetFrameData(frame)
    frameData.cdmViewerName = vName

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local styleVersion = CDM.styleCacheVersion or 0
    local iconPosition = iconPositionOverride or styleCache.buffBarIconPosition
    local targetFrameWidth = frameWidthOverride or (frame.GetWidth and frame:GetWidth()) or 0
    local targetFrameHeight = frameHeightOverride or (frame.GetHeight and frame:GetHeight()) or 0
    local barStyleNeedsUpdate = not frameData.cdmBarStyled
        or frameData.cdmLastBarStyleVersion ~= styleVersion
        or frameData.cdmLastBarW ~= targetFrameWidth
        or frameData.cdmLastBarH ~= targetFrameHeight
        or frameData.cdmLastBarIconPosition ~= iconPosition

    local borderVersion = CDM.borderStyleVersion or 0

    local bar = frame.Bar

    if not frameData.cdmBarHidesDone then
        if frame.DebuffBorder then
            frame.DebuffBorder:Hide()
        end
        EnsureFrameHooks(frame, frameData, "bar")
        if frameData.borderFrame then
            frameData.borderFrame:Hide()
        end

        if bar then
            if bar.BarBG then
                bar.BarBG:Hide()
                bar.BarBG:SetAlpha(0)
            end

            if bar.Pip then
                bar.Pip:Hide()
                bar.Pip:SetAlpha(0)
                if not frameData.cdmPipHooked then
                    frameData.cdmPipHooked = true
                    hooksecurefunc(bar.Pip, "Show", function(self)
                        self:Hide()
                        self:SetAlpha(0)
                    end)
                end
            end
        end
        frameData.cdmBarHidesDone = true
    end

    if not frameData.cdmBarContentHooked and frame.SetBarContent then
        frameData.cdmBarContentHooked = true
        hooksecurefunc(frame, "SetBarContent", function()
            local fd = GetFrameData(frame)
            if not fd then return end
            fd.cdmBarStyled = false
            if fd.cdmLastBarIconPosition == "HIDDEN" then
                if frame.Icon then frame.Icon:Hide() end
                local bar = frame.Bar
                if bar then
                    bar:ClearAllPoints()
                    Pixel.SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
                    Pixel.SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
                end
            end
        end)
    end

    if not barStyleNeedsUpdate then
        return
    end

    local barHeight = (targetFrameHeight and targetFrameHeight > 0) and targetFrameHeight or styleCache.buffBarHeight
    local iconGap = Snap(styleCache.buffBarIconGap or 0)
    local showName = styleCache.buffBarShowName
    local showDuration = styleCache.buffBarShowDuration
    local barTextureName = styleCache.buffBarTexture
    local barColor = styleCache.buffBarColor
    local bgColor = styleCache.buffBarBackgroundColor
    local fontPath = styleCache.fontPath
    local textFontOutline = styleCache.textFontOutline
    local zoomIcons = styleCache.zoomIcons
    local zoomAmount = zoomIcons and styleCache.zoomAmount or 0
    local nameFontSize = styleCache.buffBarNameFontSize
    local nameMaxChars = styleCache.buffBarNameMaxChars
    local nameColor = styleCache.buffBarNameColor
    local nameOffsetX = styleCache.buffBarNameOffsetX
    local nameOffsetY = styleCache.buffBarNameOffsetY
    local durationFontSize = styleCache.buffBarDurationFontSize
    local durationColor = styleCache.buffBarDurationColor
    local durationOffsetX = styleCache.buffBarDurationOffsetX
    local durationOffsetY = styleCache.buffBarDurationOffsetY
    local showApplications = styleCache.buffBarShowApplications
    local appFontSize = styleCache.buffBarApplicationsFontSize
    local appColor = styleCache.buffBarApplicationsColor
    local appPosition = styleCache.buffBarApplicationsPosition
    local appOffsetX = styleCache.buffBarApplicationsOffsetX
    local appOffsetY = styleCache.buffBarApplicationsOffsetY

    local barTexture = (LSM and LSM:Fetch("statusbar", barTextureName)) or "Interface\\TargetingFrame\\UI-StatusBar"

    local iconFrame = frame.Icon
    local iconSize = barHeight

    frameData.cdmLastBarIconPosition = iconPosition

    if iconFrame then
        if iconPosition == "HIDDEN" then
            if frameData.iconBorderFrame and frameData.iconBorderFrame.border then
                frameData.iconBorderFrame.border:Hide()
            end
            iconFrame:Hide()
        else
            iconFrame:Show()
            iconFrame:SetSize(iconSize, iconSize)

            iconFrame:ClearAllPoints()
            if iconPosition == "RIGHT" then
                Pixel.SetPoint(iconFrame, "RIGHT", frame, "RIGHT", 0, 0)
            else
                Pixel.SetPoint(iconFrame, "LEFT", frame, "LEFT", 0, 0)
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
                RemoveBlizzardIconMask(iconFrame, iconTex, frameData, "cdmBarIconMaskRemoved")
                CDM_C.ApplyIconTexCoord(iconTex, zoomAmount, iconSize, iconSize)
                Pixel.DisableTextureSnap(iconTex)
            end

            ApplyOverlayVisibility(styleCache.hideIconOverlay, styleCache.hideIconOverlayTexture, iconFrame:GetRegions())

            iconBorderCtx.active = styleCache.isBorderActive
            iconBorderCtx.color = styleCache.borderColor
            iconBorderCtx.version = borderVersion
            EnsureIconBorder(frameData, iconFrame, "iconBorderFrame", iconBorderCtx)
            if frameData.iconBorderFrame and not frameData.iconBorderFrameLevelSet then
                frameData.iconBorderFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)
                frameData.iconBorderFrameLevelSet = true
            end
        end
    end
    if bar then
        bar:ClearAllPoints()
        bar:SetHeight(barHeight)

        if iconPosition == "HIDDEN" then
            Pixel.SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            Pixel.SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        elseif iconPosition == "RIGHT" then
            Pixel.SetPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            Pixel.SetPoint(bar, "RIGHT", iconFrame or frame, iconFrame and "LEFT" or "RIGHT", iconFrame and -iconGap or 0, 0)
        else
            Pixel.SetPoint(bar, "LEFT", iconFrame or frame, iconFrame and "RIGHT" or "LEFT", iconFrame and iconGap or 0, 0)
            Pixel.SetPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        end

        bar:SetStatusBarTexture(barTexture)
        bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)

        if not frameData.barBackground then
            frameData.barBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        end
        frameData.barBackground:ClearAllPoints()
        frameData.barBackground:SetAllPoints(bar)
        Pixel.DisableTextureSnap(frameData.barBackground)
        frameData.barBackground:SetTexture(barTexture)
        frameData.barBackground:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.8)

        local nameText = bar.Name
        local durationText = bar.Duration
        local wantsNameText = showName and nameText
        local wantsDurationText = showDuration and durationText

        if wantsNameText or wantsDurationText then
            if not frameData.barTextContainer then
                frameData.barTextContainer = CreateFrame("Frame", nil, bar)
                frameData.barTextContainer:SetAllPoints(bar)
                frameData.barTextContainer:SetFrameLevel(bar:GetFrameLevel() + 6)
            end
            frameData.barTextContainer:Show()

            if nameText then
                InstallBuffBarVisibilityShowHook(frameData, "cdmNameHooked", nameText, "buffBarShowName")
                nameText:SetParent(frameData.barTextContainer)
                if showName then
                    nameText:SetAlpha(1)
                    nameText:Show()
                    nameText:SetIgnoreParentScale(true)
                    nameText:SetFont(fontPath, Pixel.FontSize(nameFontSize), textFontOutline)
                    nameText:SetTextColor(nameColor.r, nameColor.g, nameColor.b, nameColor.a or 1)
                    nameText:SetShadowOffset(0, 0)
                    nameText:SetDrawLayer("OVERLAY", 7)
                    nameText:SetWordWrap(false)
                    nameText:SetNonSpaceWrap(false)
                    nameText:ClearAllPoints()
                    Pixel.SetPoint(nameText, "LEFT", bar, "LEFT", nameOffsetX, nameOffsetY)
                    if nameMaxChars and nameMaxChars > 0 then
                        nameText:SetWidth(nameMaxChars * Pixel.FontSize(nameFontSize) * 0.55)
                    else
                        Pixel.SetPoint(nameText, "RIGHT", bar, "RIGHT", -30, nameOffsetY)
                        nameText:SetWidth(0)
                    end
                else
                    nameText:Hide()
                    nameText:SetAlpha(0)
                end
            end

            if durationText then
                InstallBuffBarVisibilityShowHook(frameData, "cdmDurationHooked", durationText, "buffBarShowDuration")
                durationText:SetParent(frameData.barTextContainer)
                if showDuration then
                    durationText:SetAlpha(1)
                    durationText:Show()
                    durationText:SetIgnoreParentScale(true)
                    durationText:SetFont(fontPath, Pixel.FontSize(durationFontSize), textFontOutline)
                    durationText:SetTextColor(durationColor.r, durationColor.g, durationColor.b, durationColor.a or 1)
                    durationText:SetShadowOffset(0, 0)
                    durationText:SetDrawLayer("OVERLAY", 7)
                    durationText:ClearAllPoints()
                    Pixel.SetPoint(durationText, "RIGHT", bar, "RIGHT", durationOffsetX, durationOffsetY)
                else
                    durationText:Hide()
                    durationText:SetAlpha(0)
                end
            end
        else
            if frameData.barTextContainer then frameData.barTextContainer:Hide() end
            if bar.Name then bar.Name:Hide(); bar.Name:SetAlpha(0) end
            if bar.Duration then bar.Duration:Hide(); bar.Duration:SetAlpha(0) end
        end

        local appText = iconFrame and iconFrame.Applications
        if appText then
            local canShowApplications = showApplications
            if canShowApplications then
                if not frameData.barAppTextContainer then
                    frameData.barAppTextContainer = CreateFrame("Frame", nil, bar)
                    frameData.barAppTextContainer:SetAllPoints(bar)
                    frameData.barAppTextContainer:SetFrameLevel(bar:GetFrameLevel() + 6)
                end

                frameData.barAppTextContainer:Show()
                InstallBuffBarVisibilityShowHook(frameData, "cdmAppHooked", appText, "buffBarShowApplications")
                appText:SetParent(frameData.barAppTextContainer)
                appText:SetAlpha(1)
                appText:Show()
                appText:SetIgnoreParentScale(true)
                appText:SetFont(fontPath, Pixel.FontSize(appFontSize), textFontOutline)
                appText:SetTextColor(appColor.r, appColor.g, appColor.b, appColor.a or 1)
                appText:SetShadowOffset(0, 0)
                appText:SetDrawLayer("OVERLAY", 7)
                appText:SetJustifyH("CENTER")
                appText:SetSize(0, 0)
                appText:ClearAllPoints()
                Pixel.SetPoint(appText, "CENTER", bar, appPosition, appOffsetX, appOffsetY)
            else
                if frameData.barAppTextContainer then frameData.barAppTextContainer:Hide() end
                appText:Hide()
                appText:SetAlpha(0)
            end
        end

        barBorderCtx.active = styleCache.isBorderActive
        barBorderCtx.color = styleCache.borderColor
        barBorderCtx.version = borderVersion
        EnsureIconBorder(frameData, frame, "barBorderFrame", barBorderCtx)
        if frameData.barBorderFrame then
            frameData.barBorderFrame:ClearAllPoints()
            frameData.barBorderFrame:SetAllPoints(bar)
            if frame.GetFrameStrata then
                frameData.barBorderFrame:SetFrameStrata(frame:GetFrameStrata())
            end
            frameData.barBorderFrame:SetFrameLevel((bar:GetFrameLevel() or 0) + 1)
        end
    end

    frameData.cdmLastBarStyleVersion = styleVersion
    frameData.cdmLastBarW = targetFrameWidth
    frameData.cdmLastBarH = targetFrameHeight

    frameData.cdmBarStyled = true
end
