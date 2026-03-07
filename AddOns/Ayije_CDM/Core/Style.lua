local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local BORDER = CDM.BORDER
local LSM = LibStub("LibSharedMedia-3.0", true)
local CDM_C = CDM.CONST

local GetFrameData = CDM.GetFrameData
local IsSafeNumber = CDM.IsSafeNumber
local GetColorForSpellID = CDM.GetColorForSpellID
local GetBaseSpellID = CDM.GetBaseSpellID
local GetCachedBaseSpellID = CDM.GetCachedBaseSpellID
local GetSpellIDCandidates = CDM.GetSpellIDCandidates

local VIEWERS = CDM_C.VIEWERS
local VIEWERS_WITH_OVERRIDE = CDM_C.VIEWERS_WITH_OVERRIDE

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

function CDM_C.ApplyIconTexCoord(texture, useZoom, frameW, frameH)
    if not texture or not texture.SetTexCoord then return end
    if frameW and frameH and frameW > 0 and frameH > 0 then
        local zoomPadding = useZoom and CDM_C.ICON_TEXCOORD_MIN or 0
        local left, right, top, bottom = GetAspectPreservingTexCoord(frameW, frameH, zoomPadding)
        texture:SetTexCoord(left, right, top, bottom)
    elseif useZoom then
        texture:SetTexCoord(CDM_C.ICON_TEXCOORD_MIN, CDM_C.ICON_TEXCOORD_MAX, CDM_C.ICON_TEXCOORD_MIN, CDM_C.ICON_TEXCOORD_MAX)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function IsBorderStyleActive()
    return CDM.db and CDM.db.borderFile ~= "None"
end

local styleCache = {}
local DEFAULT_WHITE_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local cdFont = _G["AyijeCDM_CDFont"] or CreateFont("AyijeCDM_CDFont")
local cdFontBuff = _G["AyijeCDM_CDFont_Buff"] or CreateFont("AyijeCDM_CDFont_Buff")
local BLIZZARD_ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local BLIZZARD_ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local BLIZZARD_ICON_OVERLAY_TEXTURE_FILE_ID = 6707800
local DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local lastStyleCacheVersion = -1

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
    styleCache.textFont = CfgValue(db, defaults, "textFont", "Friz Quadrata TT")
    local rawOutline = CfgValue(db, defaults, "textFontOutline", "OUTLINE")
    styleCache.textFontOutline = (rawOutline == "NONE") and "" or rawOutline

    styleCache.cooldownFontSize = CfgValue(db, defaults, "cooldownFontSize", 12)
    styleCache.cooldownColor = CfgValue(db, defaults, "cooldownColor", DEFAULT_WHITE_COLOR)
    styleCache.racialsCooldownFontSize = CfgValue(db, defaults, "racialsCooldownFontSize", 12)
    styleCache.defensivesCooldownFontSize = CfgValue(db, defaults, "defensivesCooldownFontSize", 12)
    styleCache.trinketsCooldownFontSize = CfgValue(db, defaults, "trinketsCooldownFontSize", 12)

    styleCache.chargeFontSize = CfgValue(db, defaults, "chargeFontSize", 12)
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

    CDM_C.RefreshBaseFontCache()
    styleCache.fontPath = CDM_C.GetBaseFontPath()

    cdFont:SetFont(styleCache.fontPath, CDM_C.GetPixelFontSize(styleCache.cooldownFontSize), styleCache.textFontOutline)
    cdFontBuff:SetFont(styleCache.fontPath, CDM_C.GetPixelFontSize(styleCache.buffCooldownFontSize), styleCache.textFontOutline)
end

CDM.RefreshStyleCache = RefreshStyleCache

local DesaturationCurve = CDM_C.DesaturationCurve
local GCDFilterCurve = CDM_C.GCDFilterCurve


local function StyleCooldownTextElement(text, fontPath, fontSize, fontOutline, color)
    if not text or not text.SetFont then return end
    color = color or DEFAULT_WHITE_COLOR
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetFont(fontPath, CDM_C.GetPixelFontSize(fontSize), fontOutline)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(color.r, color.g, color.b)
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function SafeEquals(v, expected)
    return (type(v) ~= "number" or not issecretvalue(v)) and v == expected
end

local function HideBlizzardIconOverlayFromRegions(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_OVERLAY_ATLAS)
                or SafeEquals(region:GetTexture(), BLIZZARD_ICON_OVERLAY_TEXTURE_FILE_ID) then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
end

local function RestoreBlizzardIconOverlayInRegions(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_OVERLAY_ATLAS)
                or SafeEquals(region:GetTexture(), BLIZZARD_ICON_OVERLAY_TEXTURE_FILE_ID) then
                region:SetAlpha(1)
                region:Show()
            end
        end
    end
end

local function HideBarIconOverlay(zoomIcons, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_OVERLAY_ATLAS) then
                region:SetAlpha(zoomIcons and 0 or 1)
            end
        end
    end
end

local function StyleCooldownFontStringsInRegions(fontPath, fontSize, fontOutline, color, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            StyleCooldownTextElement(region, fontPath, fontSize, fontOutline, color)
        end
    end
end


local function ReportError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function GetSpellIDForCooldown(frame)
    local info = frame and frame.cooldownInfo
    if not info then return nil end
    local id = info.overrideSpellID or info.spellID
    return IsSafeNumber(id) and id or nil
end

local function ApplyAuraStateBody(frame, spellID)
    local cdInfo = spellID and C_Spell.GetSpellCooldown(spellID)
    local tex = frame.Icon

    local durObj = spellID and C_Spell.GetSpellCooldownDuration(spellID)

    local hasChargeSource = false
    if type(frame.HasVisualDataSource_Charges) == "function" then
        hasChargeSource = not not frame:HasVisualDataSource_Charges()
    end

    local chargeDurObj = hasChargeSource and spellID and C_Spell.GetSpellChargeDuration(spellID)

    if tex and (type(tex) ~= "number" or not issecretvalue(tex)) then
        if durObj and not hasChargeSource and durObj.EvaluateRemainingDuration then
            local curve = (cdInfo and cdInfo.isOnGCD) and GCDFilterCurve or DesaturationCurve
            tex:SetDesaturation(durObj:EvaluateRemainingDuration(curve, 0) or 0)
        else
            tex:SetDesaturation(0)
        end
    end

    if frame.Cooldown.SetUseAuraDisplayTime then
        frame.Cooldown:SetUseAuraDisplayTime(false)
    end

    if hasChargeSource and chargeDurObj then
        frame.Cooldown:SetCooldownFromDurationObject(chargeDurObj)
        if frame.Cooldown.SetDrawSwipe then
            frame.Cooldown:SetDrawSwipe(true)
        end
    elseif durObj then
        frame.Cooldown:SetCooldownFromDurationObject(durObj)
        if frame.Cooldown.SetDrawSwipe then
            frame.Cooldown:SetDrawSwipe(true)
        end
    elseif cdInfo and cdInfo.isOnGCD then
        if frame.Cooldown.Clear then
            frame.Cooldown:Clear()
        end
    end

    if frame.Cooldown.SetSwipeColor then
        frame.Cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
    end
    if frame.Cooldown.SetDrawEdge then
        frame.Cooldown:SetDrawEdge(false)
    end
end

function CDM:ApplyAuraState(frame, spellID)
    if not frame or not frame.Cooldown then return end

    local frameData = GetFrameData(frame)
    if frameData.isUpdatingCD then return end

    frameData.isUpdatingCD = true

    local ok, err = pcall(ApplyAuraStateBody, frame, spellID)
    frameData.isUpdatingCD = false
    if not ok then ReportError(err) end
end

local DOT_OVERRIDE_SPELLS = CDM_C.DOT_OVERRIDE_SPELLS

local function ApplyDotOverride(frame)
    if not frame or not frame.Cooldown then return end

    local swipeColor = frame.cooldownSwipeColor
    local isActive = false
    if swipeColor and type(swipeColor) ~= "number" and swipeColor.GetRGBA then
        local r = swipeColor:GetRGBA()
        if r and type(r) == "number" and not issecretvalue(r) then
            isActive = r ~= 0
        end
    end

    if not isActive then
        frame.Cooldown:SetAlpha(0)
        if frame.Icon then
            frame.Icon:SetDesaturation(1)
        end
    else
        frame.Cooldown:SetReverse(true)
        frame.Cooldown:SetAlpha(1)
        frame.Cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
        frame.Cooldown:SetDrawEdge(false)
        if frame.Cooldown.SetUseAuraDisplayTime then
            frame.Cooldown:SetUseAuraDisplayTime(false)
        end
        if frame.Icon then
            frame.Icon:SetDesaturation(0)
        end
    end
end

local function ClearDotOverride(frame, frameData)
    if frameData.cdmDotOverride and frame.Cooldown then
        frameData.cdmDotOverride = false
        frame.Cooldown:SetAlpha(1)
        frame.Cooldown:SetReverse(false)
    end
end

local function ProcessAuraOverrideBody(self, frame, frameData, spellID)
    if spellID then
        if DOT_OVERRIDE_SPELLS[spellID] then
            frameData.cdmDotOverride = true
            ApplyDotOverride(frame)
        else
            ClearDotOverride(frame, frameData)
            self:ApplyAuraState(frame, spellID)
        end
        frameData.cdmAuraLastSpellID = spellID
    else
        ClearDotOverride(frame, frameData)
        frameData.cdmAuraLastSpellID = nil
    end

    frameData.cdmAuraStateDirty = false
end

function CDM:ProcessAuraOverride(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    if frameData.isUpdatingCD then return end
    if frameData.isProcessingOverride then return end

    frameData.isProcessingOverride = true

    local spellID = GetSpellIDForCooldown(frame)
    if spellID
        and not frameData.cdmAuraStateDirty
        and frameData.cdmAuraLastSpellID == spellID
    then
        frameData.isProcessingOverride = false
        return
    end

    local ok, err = pcall(ProcessAuraOverrideBody, self, frame, frameData, spellID)
    frameData.isProcessingOverride = false
    if not ok then ReportError(err) end
end

function CDM:ApplyBuffVisualState(frame)
    if not frame then return end

    if styleCache.hideDebuffBorder and frame.DebuffBorder then
        frame.DebuffBorder:Hide()
    end

    if styleCache.hidePandemicIndicator and frame.PandemicIcon then
        frame.PandemicIcon:Hide()
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

local function SetupPandemicStateHook(frame, frameData)
    if not frame or not frame.ShowPandemicStateFrame or frameData.pandemicHooked then
        return
    end

    frameData.pandemicHooked = true
    hooksecurefunc(frame, "ShowPandemicStateFrame", function(self)
        local selfData = GetFrameData(self)
        if styleCache.hidePandemicIndicator and self.PandemicIcon and not selfData.isProcessingBuffOverride then
            self.PandemicIcon:Hide()
        end
    end)
end

function CDM:SetupBuffViewerHooks(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)

    if frame.DebuffBorder and not frameData.debuffBorderHooked then
        frameData.debuffBorderHooked = true

        hooksecurefunc(frame.DebuffBorder, "Show", function(self)
            if styleCache.hideDebuffBorder and not frameData.isProcessingBuffOverride then
                self:Hide()
            end
        end)

        if frame.DebuffBorder.UpdateFromAuraData then
            hooksecurefunc(frame.DebuffBorder, "UpdateFromAuraData", function(self)
                if styleCache.hideDebuffBorder and not frameData.isProcessingBuffOverride then
                    self:Hide()
                end
            end)
        end
    end

    SetupPandemicStateHook(frame, frameData)
end

function CDM:SetupCooldownViewerHooks(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)

    if frame.CooldownFlash and not frameData.cooldownFlashHooked then
        frameData.cooldownFlashHooked = true

        hooksecurefunc(frame.CooldownFlash, "Show", function(self)
            if styleCache.hideCooldownBling then
                self:Hide()
                if self.FlashAnim then
                    self.FlashAnim:Stop()
                end
            end
        end)

        if frame.CooldownFlash.FlashAnim and frame.CooldownFlash.FlashAnim.Play then
            hooksecurefunc(frame.CooldownFlash.FlashAnim, "Play", function(self)
                if styleCache.hideCooldownBling then
                    self:Stop()
                    frame.CooldownFlash:Hide()
                end
            end)
        end
    end

    SetupPandemicStateHook(frame, frameData)
end

local function SetupUtilityVisibilityHooks(frame, frameData)
    if not frame or frameData.cdmUtilityVisibilityHooked or not frame.HookScript then
        return
    end

    frameData.cdmUtilityVisibilityHooked = true
    local function invalidateUtil()
        if CDM.InvalidateUtilityVisibleCountCache then
            CDM:InvalidateUtilityVisibleCountCache()
        end
    end
    frame:HookScript("OnShow", invalidateUtil)
    frame:HookScript("OnHide", invalidateUtil)
end

local function GetViewerIconSize(vName, frameData, sizes, isBuff)
    if isBuff then
        local s = sizes.SIZE_BUFF
        return s.w, s.h
    end
    if vName == VIEWERS.ESSENTIAL then
        local s = (frameData.cdmRow == 2) and sizes.SIZE_ESS_ROW2 or sizes.SIZE_ESS_ROW1
        return s.w, s.h
    end
    if vName == VIEWERS.UTILITY then
        local s = sizes.SIZE_UTILITY
        return s.w, s.h
    end
    if vName == "CDM_Racials" then
        local s = sizes.SIZE_RACIALS
        return s.w, s.h
    end
    if vName == "CDM_Defensives" then
        local s = sizes.SIZE_DEFENSIVES
        return s.w, s.h
    end
    if vName == "CDM_Trinkets" then
        local s = sizes.SIZE_TRINKETS
        return s.w, s.h
    end
    local s = sizes.SIZE_ESS_ROW1
    return s.w, s.h
end

local function GetEffectiveCooldownFontSize(vName, isBuff)
    if vName == "CDM_Racials" then
        return styleCache.racialsCooldownFontSize
    end
    if vName == "CDM_Defensives" then
        return styleCache.defensivesCooldownFontSize
    end
    if vName == "CDM_Trinkets" then
        return styleCache.trinketsCooldownFontSize
    end
    if isBuff then
        return styleCache.buffCooldownFontSize
    end
    return styleCache.cooldownFontSize
end

local function GetEffectiveCooldownColor(vName, isBuff)
    if isBuff then return styleCache.buffCooldownColor end
    return styleCache.cooldownColor
end

local function ApplyIconTextureLayout(texture, frame, iconWidth, iconHeight, zoomIcons)
    CDM_C.ApplyIconTexCoord(texture, zoomIcons, iconWidth, iconHeight)
    texture:ClearAllPoints()
    texture:SetAllPoints(frame)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

local function GetBuffCountAnchor(vName)
    if vName == VIEWERS.BUFF then
        return styleCache.countPositionMain, styleCache.countOffsetXMain, styleCache.countOffsetYMain
    end
    return nil, nil, nil
end

local function EnsureFrameScaleOne(frame)
    if not (frame and frame.SetScale) then return end
    if frame.GetScale and frame:GetScale() == 1 then return end
    frame:SetScale(1)
end

local function SnapToPixel(value)
    return CDM_C.SnapOffsetToPixel(value, UIParent)
end

local function GetResolvedBorderTexturePath()
    local borderKey = CDM_C.GetConfigValue("borderFile", "Ayije_Thin")
    if borderKey == "None" then
        return nil
    end

    if LSM then
        local path = LSM:Fetch("border", borderKey)
        if path and path ~= "" then
            return path
        end
    end

    return "Interface\\AddOns\\Ayije_CDM\\Media\\Borders\\Ayije_Thin.tga"
end

local GetPixelForRegion = CDM_C.GetPixelSizeForRegion

local IsPixelIconBorderMode = CDM_C.IsPixelIconBorderMode

local function ConfigurePixelBorderLineTexture(line, texPath, r, g, b, a)
    if not line then
        return
    end
    line:SetTexture(texPath)
    if line.SetHorizTile then line:SetHorizTile(false) end
    if line.SetVertTile then line:SetVertTile(false) end
    if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
    if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
    line:SetVertexColor(r, g, b, a)
    line:Show()
end

local function EnsurePixelIconBorder(frameData, frame)
    if not frameData.pixelIconBorderFrame then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        if frame.GetFrameStrata then
            overlay:SetFrameStrata(frame:GetFrameStrata())
        end
        overlay:SetFrameLevel(frame:GetFrameLevel() + 3)
        frameData.pixelIconBorderFrame = overlay

        frameData.pixelIconBorderLines = {}
        for i = 1, 4 do
            local line = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
            frameData.pixelIconBorderLines[i] = line
        end
    end

    local overlay = frameData.pixelIconBorderFrame
    overlay:SetAllPoints(frame)
    if frame.GetFrameStrata then
        overlay:SetFrameStrata(frame:GetFrameStrata())
    end
    overlay:SetFrameLevel(frame:GetFrameLevel() + 3)
    overlay:Show()
    return overlay, frameData.pixelIconBorderLines
end

local function RemoveBarIconMask(iconFrame, iconTexture, frameData)
    if not (iconFrame and iconTexture and iconTexture.RemoveMaskTexture and frameData) then
        return
    end

    if frameData.cdmBarIconMaskRemoved then
        return
    end

    local regions = { iconFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.IsObjectType and region:IsObjectType("MaskTexture") then
            if SafeEquals(region:GetAtlas(), BLIZZARD_ICON_MASK_ATLAS) then
                pcall(iconTexture.RemoveMaskTexture, iconTexture, region)
                frameData.cdmBarIconMaskRemoved = true
                break
            end
        end
    end
end

local function HidePixelIconBorder(frameData)
    if frameData and frameData.pixelIconBorderFrame then
        frameData.pixelIconBorderFrame:Hide()
    end
end

local function ApplyPixelIconBorder(frameData, frame, color)
    local overlay, lines = EnsurePixelIconBorder(frameData, frame)
    local texPath = CDM_C.TEX_WHITE8X8
    local onePx = GetPixelForRegion(overlay)
    local configuredSize = CDM_C.GetConfigValue("borderSize", 1) or 1
    local borderPixels = math.max(1, math.floor(configuredSize / onePx))
    local px = borderPixels * onePx
    local r = (color and color.r) or 1
    local g = (color and color.g) or 1
    local b = (color and color.b) or 1
    local a = (color and color.a) or 1

    local top = lines[1]
    local bottom = lines[2]
    local left = lines[3]
    local right = lines[4]

    for _, line in ipairs(lines) do
        ConfigurePixelBorderLineTexture(line, texPath, r, g, b, a)
    end

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", overlay, "TOPLEFT", px, 0)
    top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -px, 0)
    top:SetHeight(px)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", px, 0)
    bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -px, 0)
    bottom:SetHeight(px)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
    left:SetWidth(px)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(px)
end

local function EnsurePixelContentMask(frameData, frame)
    if not (frame and frame.CreateMaskTexture) then
        return nil
    end

    if not frameData.pixelContentMask then
        local mask = frame:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture(CDM_C.TEX_WHITE8X8)
        frameData.pixelContentMask = mask
    end

    frameData.pixelContentMask:SetAllPoints(frame)
    return frameData.pixelContentMask
end

local function TryAddMaskTexture(region, mask, flagName, frameData)
    if region and region.AddMaskTexture and not frameData[flagName] then
        region:AddMaskTexture(mask)
        frameData[flagName] = true
    end
end

local function TryRemoveMaskTexture(region, mask, flagName, frameData)
    if mask and region and region.RemoveMaskTexture and frameData[flagName] then
        pcall(region.RemoveMaskTexture, region, mask)
        frameData[flagName] = false
    end
end

local function ApplyPixelContentClip(frameData, frame)
    local mask = EnsurePixelContentMask(frameData, frame)
    if not mask then
        if frame and frame.SetClipsChildren then
            frame:SetClipsChildren(true)
        end
        frameData.pixelContentClipUsesFrameClip = true
        return
    end

    local icon = frame and frame.Icon
    TryAddMaskTexture(icon, mask, "pixelIconMaskApplied", frameData)

    local cooldown = frame and frame.Cooldown
    TryAddMaskTexture(cooldown, mask, "pixelCooldownMaskApplied", frameData)

    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(false)
    end
    frameData.pixelContentClipUsesFrameClip = false
end

local function RemovePixelContentClip(frameData, frame)
    if not frameData then return end

    local mask = frameData.pixelContentMask
    local icon = frame and frame.Icon
    TryRemoveMaskTexture(icon, mask, "pixelIconMaskApplied", frameData)

    local cooldown = frame and frame.Cooldown
    TryRemoveMaskTexture(cooldown, mask, "pixelCooldownMaskApplied", frameData)

    if frame and frame.SetClipsChildren and frameData.pixelContentClipUsesFrameClip then
        frame:SetClipsChildren(false)
    end
    frameData.pixelContentClipUsesFrameClip = false
end

local function DisablePixelIconBorderMode(frameData, frame)
    HidePixelIconBorder(frameData)
    RemovePixelContentClip(frameData, frame)
end

function CDM:ApplyStyle(frame, vName, forceUpdate)
    if not frame then return end

    EnsureFrameScaleOne(frame)

    local frameData = GetFrameData(frame)
    frameData.cdmViewerName = vName
    local fullUpdate = forceUpdate or not frameData.hooksInitialized or frameData.cdmLastStyledVName ~= vName
    local styleVersion = CDM.styleCacheVersion or 0
    if frameData.cdmAuraStyleVersion ~= styleVersion then
        frameData.cdmAuraStyleVersion = styleVersion
        frameData.cdmAuraStateDirty = true
    end

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local sizes = CDM.Sizes
    if not sizes then return end

    local isBuff = vName == VIEWERS.BUFF

    local isCooldown =
        vName == VIEWERS.ESSENTIAL
        or vName == VIEWERS.UTILITY
        or vName == "CDM_Racials"
        or vName == "CDM_Defensives"
        or vName == "CDM_Trinkets"

    local borderActive = IsBorderStyleActive()
    local usePixelIconBorder = borderActive and (isCooldown or isBuff) and IsPixelIconBorderMode()
    local pixelBorderModeChanged = (frameData.cdmUsePixelIconBorder ~= usePixelIconBorder)

    local iconWidth, iconHeight = GetViewerIconSize(vName, frameData, sizes, isBuff)
    iconWidth = SnapToPixel(iconWidth)
    iconHeight = SnapToPixel(iconHeight)

    local actualW = frame:GetWidth() or 0
    local actualH = frame:GetHeight() or 0

    local needsVisualUpdate = fullUpdate
        or frameData.cdmLastStyleVersion ~= styleVersion
        or frameData.cdmLastStyledW ~= iconWidth
        or frameData.cdmLastStyledH ~= iconHeight
        or pixelBorderModeChanged
        or (actualW > 1 and math.abs(actualW - iconWidth) > 0.01)
        or (actualH > 1 and math.abs(actualH - iconHeight) > 0.01)

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
        local tex = frame.Icon
        local hasTexture = tex ~= nil and (type(tex) ~= "number" or not issecretvalue(tex))

        if hasTexture then
            ApplyIconTextureLayout(tex, frame, iconWidth, iconHeight, zoomIcons)
        end

        if frame.Cooldown then
            frame.Cooldown:ClearAllPoints()
            frame.Cooldown:SetAllPoints(frame)

            if frame.Cooldown.SetSwipeTexture then
                if zoomIcons then
                    frame.Cooldown:SetSwipeTexture(CDM_C.TEX_WHITE8X8)
                else
                    frame.Cooldown:SetSwipeTexture(DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE)
                end
            end
            if frame.Cooldown.SetDrawEdge then
                frame.Cooldown:SetDrawEdge(false)
            end

            if frame.Cooldown.SetCountdownFont then
                frame.Cooldown:SetCountdownFont(isBuff and "AyijeCDM_CDFont_Buff" or "AyijeCDM_CDFont")
            end
        end

        if zoomIcons then
            if fullUpdate or not frameData.cdmOverlayHidden then
                HideBlizzardIconOverlayFromRegions(frame:GetRegions())
                frameData.cdmOverlayHidden = true
            end
        else
            if fullUpdate or frameData.cdmOverlayHidden then
                RestoreBlizzardIconOverlayInRegions(frame:GetRegions())
            end
            frameData.cdmOverlayHidden = false
        end

        if borderActive then
            if not frameData.borderFrame then
                frameData.borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
                frameData.borderFrame:SetAllPoints()
            end

            local borderVersion = CDM.borderStyleVersion or 0
            local borderForce = forceUpdate or (frameData.borderVersionApplied ~= borderVersion)
            if usePixelIconBorder then
                local pixelBorderRefreshNeeded = fullUpdate or needsVisualUpdate or borderForce or pixelBorderModeChanged
                if frameData.borderFrame.border then
                    frameData.borderFrame.border:Hide()
                end
                if pixelBorderRefreshNeeded then
                    ApplyPixelIconBorder(frameData, frame, styleCache.borderColor)
                    ApplyPixelContentClip(frameData, frame)
                end
                frameData.borderVersionApplied = borderVersion
            else
                DisablePixelIconBorderMode(frameData, frame)
                if BORDER and BORDER.CreateBorder and
                    (fullUpdate or needsVisualUpdate or pixelBorderModeChanged or not frameData.borderInitialized or borderForce) then
                    BORDER:CreateBorder(frameData.borderFrame, { forceUpdate = borderForce })
                    frameData.borderInitialized = true
                    frameData.borderVersionApplied = borderVersion
                end
            end
            frameData.cdmUsePixelIconBorder = usePixelIconBorder
        else
            DisablePixelIconBorderMode(frameData, frame)
            frameData.cdmUsePixelIconBorder = false
        end

        local textFontOutline = styleCache.textFontOutline
        local fontPath = styleCache.fontPath
        local cooldownColor = GetEffectiveCooldownColor(vName, isBuff)
        local effectiveCooldownFontSize = GetEffectiveCooldownFontSize(vName, isBuff)
        local cooldownText = frame.Cooldown and (frame.Cooldown.Text or frame.Cooldown.text)
        local chargeText = frame.ChargeCount and frame.ChargeCount.Current
        local countText = frame.Applications and frame.Applications.Applications

        StyleCooldownTextElement(cooldownText, fontPath, effectiveCooldownFontSize, textFontOutline, cooldownColor)

        if frame.Cooldown then
            StyleCooldownFontStringsInRegions(
                fontPath,
                effectiveCooldownFontSize,
                textFontOutline,
                cooldownColor,
                frame.Cooldown:GetRegions()
            )
        end

        if frame.Time then
            StyleCooldownTextElement(frame.Time, fontPath, effectiveCooldownFontSize, textFontOutline, cooldownColor)
        end
        if frame.Duration then
            StyleCooldownTextElement(frame.Duration, fontPath, effectiveCooldownFontSize, textFontOutline, cooldownColor)
        end

        if isCooldown then
            if frame.ChargeCount then
                frame.ChargeCount:SetFrameLevel(frame:GetFrameLevel() + 7)
            end

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
                chargeText:ClearAllPoints()
                chargeText:SetPoint(styleCache.chargePosition, frame, styleCache.chargePosition, styleCache.chargeOffsetX, styleCache.chargeOffsetY)
                chargeText:SetFont(fontPath, CDM_C.GetPixelFontSize(styleCache.chargeFontSize), textFontOutline)
                chargeText:SetTextColor(styleCache.chargeColor.r, styleCache.chargeColor.g, styleCache.chargeColor.b)
                chargeText:SetDrawLayer("OVERLAY", 7)
                chargeText:SetShadowOffset(0, 0)
            end
        end

        if isBuff then
            if frame.Applications then
                frame.Applications:SetFrameLevel(frame:GetFrameLevel() + 7)
            end

            if countText then
                countText:SetIgnoreParentScale(true)
                countText:SetFont(fontPath, CDM_C.GetPixelFontSize(styleCache.countFontSize), textFontOutline)
                countText:SetTextColor(styleCache.countColor.r, styleCache.countColor.g, styleCache.countColor.b)
                countText:SetDrawLayer("OVERLAY", 7)
                countText:SetShadowOffset(0, 0)

                local frameAnchor, offsetX, offsetY = GetBuffCountAnchor(vName)
                if frameAnchor then
                    countText:ClearAllPoints()
                    countText:SetPoint("CENTER", frame, frameAnchor, offsetX, offsetY)
                end

                frameData.cdmLastCountFS = nil
            end

            if frame.Cooldown then
                frame.Cooldown:SetReverse(true)
            end
        end

        frameData.cdmLastStyleVersion = styleVersion
        frameData.cdmLastStyledW = iconWidth
        frameData.cdmLastStyledH = iconHeight
        frameData.cdmLastStyledVName = vName
    end

    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY then
        local KB = CDM.Keybinds
        if KB and KB.IsEnabled and KB:IsEnabled() then
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

            local kbCacheVer = KB:GetCacheVersion()
            local baseSpellID = GetCachedBaseSpellID(self, frame)
            if not baseSpellID and frame.spellID then
                baseSpellID = CDM.NormalizeToBase(frame.spellID)
            end

            if frameData.cdmLastKeybindCacheVer ~= kbCacheVer
                or frameData.cdmLastKeybindStyleVer ~= styleVersion
                or frameData.cdmLastKeybindSpellID ~= baseSpellID then

                local kbFS = frameData.cdmKeybindFS
                if frameData.cdmLastKeybindStyleVer ~= styleVersion then
                    kbFS:SetIgnoreParentScale(true)
                    kbFS:ClearAllPoints()
                    kbFS:SetPoint(styleCache.assistPosition, frame, styleCache.assistPosition,
                                  styleCache.assistOffsetX, styleCache.assistOffsetY)
                    local kbFontPath = styleCache.fontPath or CDM_C.GetBaseFontPath()
                    local kbOutline = styleCache.textFontOutline or ""
                    kbFS:SetFont(kbFontPath, CDM_C.GetPixelFontSize(styleCache.assistFontSize), kbOutline)
                    kbFS:SetTextColor(styleCache.assistColor.r, styleCache.assistColor.g, styleCache.assistColor.b)
                end

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

                frameData.cdmLastKeybindCacheVer = kbCacheVer
                frameData.cdmLastKeybindStyleVer = styleVersion
                frameData.cdmLastKeybindSpellID = baseSpellID
            end
        elseif frameData.cdmKeybindContainer then
            frameData.cdmKeybindContainer:Hide()
            frameData.cdmLastKeybindCacheVer = nil
            frameData.cdmLastKeybindStyleVer = nil
            frameData.cdmLastKeybindSpellID = nil
        end
    end

    if isBuff then
        if fullUpdate then
            self:SetupBuffViewerHooks(frame)
        end

        self:ProcessBuffViewerOverrides(frame)

        local borderColor = frameData.borderFrame and frameData.borderFrame.border
        local pixelBorderLines = frameData.cdmUsePixelIconBorder and frameData.pixelIconBorderLines
        local currentSpellID = frameData.buffCategorySpellID
        local borderVersion = CDM.borderStyleVersion or 0
        local borderColorDirty = needsVisualUpdate
            or frameData.cdmLastBorderColorID ~= currentSpellID
            or frameData.cdmLastBorderStyleVersion ~= borderVersion

        if borderColorDirty and ((borderColor and borderColor.SetBackdropBorderColor) or pixelBorderLines) then
            local configColor = styleCache.borderColor
            local r, g, b = configColor.r, configColor.g, configColor.b

            local customColor
            local candidates = GetSpellIDCandidates(self, frame, true)
            for _, id in ipairs(candidates) do
                customColor = GetColorForSpellID(id)
                if customColor then break end
            end
            if not customColor then
                local baseID = GetCachedBaseSpellID(self, frame)
                customColor = baseID and GetColorForSpellID(baseID)
            end

            if customColor then
                r, g, b = customColor.r or r, customColor.g or g, customColor.b or b
            end

            if pixelBorderLines then
                for _, line in ipairs(pixelBorderLines) do
                    if line and line.SetVertexColor then
                        line:SetVertexColor(r, g, b, 1)
                    end
                end
            end

            if borderColor and borderColor.SetBackdropBorderColor then
                borderColor:SetBackdropBorderColor(r, g, b, 1)
                borderColor.backdropBorderColor = CreateColor(r, g, b)
                borderColor.backdropBorderColorAlpha = 1
            end
            frameData.cdmLastBorderColorID = currentSpellID
            frameData.cdmLastBorderStyleVersion = borderVersion
        end
    else
        if fullUpdate then
            self:SetupCooldownViewerHooks(frame)
        end
        if vName == VIEWERS.UTILITY then
            SetupUtilityVisibilityHooks(frame, frameData)
        end

        if styleCache.hidePandemicIndicator and frame.PandemicIcon then
            frame.PandemicIcon:Hide()
        end
    end

    if VIEWERS_WITH_OVERRIDE[vName] then
        local iconTex = frame.Icon
        if fullUpdate then
            if iconTex and not frameData.cdmDesatHooked then
                frameData.cdmDesatHooked = true
                local function onDesatChange()
                    local fd = GetFrameData(frame)
                    if not fd.isUpdatingCD and not fd.isProcessingOverride then
                        fd.cdmAuraStateDirty = true
                        self:ProcessAuraOverride(frame)
                    end
                end
                hooksecurefunc(iconTex, "SetDesaturated", onDesatChange)
                if iconTex.SetDesaturation then
                    hooksecurefunc(iconTex, "SetDesaturation", onDesatChange)
                end
            end

            if frame.Cooldown and not frameData.cdmCooldownHooked then
                frameData.cdmCooldownHooked = true
                local function onCooldownSet()
                    local fd = GetFrameData(frame)
                    if not fd.isUpdatingCD and not fd.isProcessingOverride then
                        self:ProcessAuraOverride(frame)
                    end
                end
                hooksecurefunc(frame.Cooldown, "SetCooldown", onCooldownSet)
                if frame.Cooldown.SetCooldownFromDurationObject then
                    hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", onCooldownSet)
                end

                hooksecurefunc(frame.Cooldown, "SetSwipeColor", function(_, r)
                    if r ~= 1 then return end
                    local fd = GetFrameData(frame)
                    local sid = fd and fd.cdmAuraLastSpellID or GetSpellIDForCooldown(frame)
                    if sid and DOT_OVERRIDE_SPELLS[sid] then
                        frame.Cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
                    end
                end)
            end
        end

        self:ProcessAuraOverride(frame)
    end

    if fullUpdate then
        frameData.hooksInitialized = true
    end
end

function CDM:ApplyTrackerStyle(frame, vName, forceUpdate)
    if not frame then return end

    if not styleCache.fontPath then
        RefreshStyleCache()
    end

    local sizes = CDM.Sizes
    if not sizes then return end

    -- Trinkets share FrameData with ApplyStyle (essential mode); Racials/Defensives
    -- store directly on frame to avoid the heavier frameData overhead.
    local useFD = (vName == "CDM_Trinkets")
    local store, borderRef, borderInit, borderVer
    local lastVerKey, lastWKey, lastHKey, lastVNameKey

    if useFD then
        store = GetFrameData(frame)
        borderRef, borderInit, borderVer = "borderFrame", "borderInitialized", "borderVersionApplied"
        lastVerKey, lastWKey, lastHKey, lastVNameKey = "cdmLastStyleVersion", "cdmLastStyledW", "cdmLastStyledH", "cdmLastStyledVName"
    else
        store = frame
        borderRef, borderInit, borderVer = "cdmBorderFrame", "cdmBorderInitialized", "cdmBorderVersionApplied"
        lastVerKey, lastWKey, lastHKey, lastVNameKey = "cdmTrackerStyleVersion", "cdmTrackerStyledW", "cdmTrackerStyledH", "cdmTrackerLastStyledVName"
    end

    local styleVersion = CDM.styleCacheVersion or 0
    local borderActive = IsBorderStyleActive()
    local usePixelIconBorder = borderActive and IsPixelIconBorderMode()
    local pixelBorderModeChanged = (store.cdmUsePixelIconBorder ~= usePixelIconBorder)

    local iconWidth, iconHeight = GetViewerIconSize(vName, store, sizes, false)
    iconWidth = SnapToPixel(iconWidth)
    iconHeight = SnapToPixel(iconHeight)

    local needsVisualUpdate = forceUpdate
        or store[lastVerKey] ~= styleVersion
        or store[lastWKey] ~= iconWidth
        or store[lastHKey] ~= iconHeight
        or store[lastVNameKey] ~= vName
        or pixelBorderModeChanged

    if not needsVisualUpdate then return end

    frame:SetSize(iconWidth, iconHeight)

    local zoomIcons = styleCache.zoomIcons
    local tex = frame.Icon
    if tex then
        ApplyIconTextureLayout(tex, frame, iconWidth, iconHeight, zoomIcons)
    end

    if frame.Cooldown then
        frame.Cooldown:ClearAllPoints()
        frame.Cooldown:SetAllPoints(frame)

        if frame.Cooldown.SetSwipeTexture then
            if zoomIcons then
                frame.Cooldown:SetSwipeTexture(CDM_C.TEX_WHITE8X8)
            else
                frame.Cooldown:SetSwipeTexture(DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE)
            end
        end
        if frame.Cooldown.SetDrawEdge then
            frame.Cooldown:SetDrawEdge(false)
        end

        if frame.Cooldown.SetCountdownFont then
            frame.Cooldown:SetCountdownFont("AyijeCDM_CDFont")
        end
    end

    if borderActive then
        local bdrFrame = store[borderRef]
        if not bdrFrame then
            bdrFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            bdrFrame:SetAllPoints()
            store[borderRef] = bdrFrame
        end

        local currentBorderVersion = CDM.borderStyleVersion or 0
        local borderForce = forceUpdate or (store[borderVer] ~= currentBorderVersion)
        if usePixelIconBorder then
            if bdrFrame.border then
                bdrFrame.border:Hide()
            end
            ApplyPixelIconBorder(store, frame, styleCache.borderColor)
            ApplyPixelContentClip(store, frame)
            store[borderVer] = currentBorderVersion
        else
            DisablePixelIconBorderMode(store, frame)
            if not store[borderInit] or borderForce or pixelBorderModeChanged then
                BORDER:CreateBorder(bdrFrame, { forceUpdate = borderForce or pixelBorderModeChanged })
                store[borderInit] = true
                store[borderVer] = currentBorderVersion
            end
        end
        store.cdmUsePixelIconBorder = usePixelIconBorder
    else
        DisablePixelIconBorderMode(store, frame)
        store.cdmUsePixelIconBorder = false
    end

    local textFontOutline = styleCache.textFontOutline
    local fontPath = styleCache.fontPath
    local cooldownColor = styleCache.cooldownColor
    local effectiveCooldownFontSize = GetEffectiveCooldownFontSize(vName, false)
    local cooldownText = frame.Cooldown and (frame.Cooldown.Text or frame.Cooldown.text)

    StyleCooldownTextElement(cooldownText, fontPath, effectiveCooldownFontSize, textFontOutline, cooldownColor)

    if frame.Cooldown then
        StyleCooldownFontStringsInRegions(
            fontPath,
            effectiveCooldownFontSize,
            textFontOutline,
            cooldownColor,
            frame.Cooldown:GetRegions()
        )
    end

    store[lastVerKey] = styleVersion
    store[lastWKey] = iconWidth
    store[lastHKey] = iconHeight
    store[lastVNameKey] = vName
end

local function ShouldShowBuffBarElement(dbKey)
    local db = CDM.db or {}
    return db[dbKey] ~= false
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

    EnsureFrameScaleOne(frame)

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
    local borderForce = not frameData.barBorderInitialized or (frameData.barBorderVersionApplied ~= borderVersion)

    local bar = frame.Bar

    if not frameData.cdmBarHidesDone then
        if frame.DebuffBorder then
            frame.DebuffBorder:Hide()

            if not frameData.debuffBorderHooked then
                frameData.debuffBorderHooked = true
                hooksecurefunc(frame.DebuffBorder, "Show", function(self)
                    if styleCache.hideDebuffBorder and not frameData.isProcessingBuffOverride then
                        self:Hide()
                    end
                end)
                if frame.DebuffBorder.UpdateFromAuraData then
                    hooksecurefunc(frame.DebuffBorder, "UpdateFromAuraData", function(self)
                        if styleCache.hideDebuffBorder and not frameData.isProcessingBuffOverride then
                            self:Hide()
                        end
                    end)
                end
            end
        end

        if frame.ShowPandemicStateFrame and not frameData.pandemicHooked then
            frameData.pandemicHooked = true
            hooksecurefunc(frame, "ShowPandemicStateFrame", function(self)
                if styleCache.hidePandemicIndicator and self.PandemicIcon then
                    self.PandemicIcon:Hide()
                end
            end)
        end

        if frameData.borderFrame then
            frameData.borderFrame:Hide()
        end

        if frame.CooldownFlash and not frameData.cooldownFlashHooked then
            frameData.cooldownFlashHooked = true

            hooksecurefunc(frame.CooldownFlash, "Show", function(self)
                if styleCache.hideCooldownBling then
                    self:Hide()
                    if self.FlashAnim then
                        self.FlashAnim:Stop()
                    end
                end
            end)

            if frame.CooldownFlash.FlashAnim and frame.CooldownFlash.FlashAnim.Play then
                hooksecurefunc(frame.CooldownFlash.FlashAnim, "Play", function(self)
                    if styleCache.hideCooldownBling then
                        self:Stop()
                        frame.CooldownFlash:Hide()
                    end
                end)
            end
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

    if not frameData.cdmIconShowHooked and frame.Icon then
        frameData.cdmIconShowHooked = true
        hooksecurefunc(frame.Icon, "Show", function(self)
            local fd = GetFrameData(frame)
            if fd and fd.cdmLastBarIconPosition == "HIDDEN" then
                self:Hide()
            end
        end)
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
                    CDM_C.SetPixelPerfectPoint(bar, "LEFT", frame, "LEFT", 0, 0)
                    CDM_C.SetPixelPerfectPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
                end
            end
        end)
    end

    if not barStyleNeedsUpdate and not borderForce then
        return
    end

    local barHeight = (targetFrameHeight and targetFrameHeight > 0) and targetFrameHeight or styleCache.buffBarHeight
    local iconGap = CDM_C.SnapOffsetToPixel(styleCache.buffBarIconGap or 0, UIParent)
    local showName = styleCache.buffBarShowName
    local showDuration = styleCache.buffBarShowDuration
    local barTextureName = styleCache.buffBarTexture
    local barColor = styleCache.buffBarColor
    local bgColor = styleCache.buffBarBackgroundColor
    local fontPath = styleCache.fontPath
    local textFontOutline = styleCache.textFontOutline
    local zoomIcons = styleCache.zoomIcons
    local nameFontSize = styleCache.buffBarNameFontSize
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
            if frameData.barIconPixelBorderStore then
                DisablePixelIconBorderMode(frameData.barIconPixelBorderStore, iconFrame)
            end
            if frameData.iconBorderFrame and frameData.iconBorderFrame.border then
                frameData.iconBorderFrame.border:Hide()
            end
            iconFrame:Hide()
        else
            iconFrame:Show()
            iconFrame:SetSize(iconSize, iconSize)

            iconFrame:ClearAllPoints()
            if iconPosition == "RIGHT" then
                CDM_C.SetPixelPerfectPoint(iconFrame, "RIGHT", frame, "RIGHT", 0, 0)
            else
                CDM_C.SetPixelPerfectPoint(iconFrame, "LEFT", frame, "LEFT", 0, 0)
            end

            local iconTex = iconFrame.Icon
            if iconTex then
                if iconTex.ClearAllPoints then
                    iconTex:ClearAllPoints()
                    if IsPixelIconBorderMode() then
                        local onePx = GetPixelForRegion(iconFrame)
                        local configuredSize = CDM_C.GetConfigValue("borderSize", 1) or 1
                        local borderPixels = math.max(1, math.floor(configuredSize / onePx))
                        local inset = math.max(0, (borderPixels * onePx) - onePx)
                        iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", inset, -inset)
                        iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset, inset)
                    else
                        iconTex:SetAllPoints(iconFrame)
                    end
                end
                RemoveBarIconMask(iconFrame, iconTex, frameData)
                CDM_C.ApplyIconTexCoord(iconTex, zoomIcons, iconSize, iconSize)
                if iconTex.SetSnapToPixelGrid then iconTex:SetSnapToPixelGrid(false) end
                if iconTex.SetTexelSnappingBias then iconTex:SetTexelSnappingBias(0) end
            end

            HideBarIconOverlay(zoomIcons, iconFrame:GetRegions())

            local borderActive = IsBorderStyleActive()
            if borderActive then
                local usePixelBorder = IsPixelIconBorderMode()
                if not frameData.iconBorderFrame then
                    frameData.iconBorderFrame = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
                    frameData.iconBorderFrame:SetAllPoints()
                    frameData.iconBorderFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)
                end

                if usePixelBorder then
                    if frameData.iconBorderFrame.border then
                        frameData.iconBorderFrame.border:Hide()
                    end

                    frameData.barIconPixelBorderStore = frameData.barIconPixelBorderStore or {}
                    ApplyPixelIconBorder(frameData.barIconPixelBorderStore, iconFrame, styleCache.borderColor)
                else
                    if frameData.barIconPixelBorderStore then
                        DisablePixelIconBorderMode(frameData.barIconPixelBorderStore, iconFrame)
                    end

                    if BORDER and BORDER.CreateBorder and (borderForce or not frameData.iconBorderFrame.border) then
                        BORDER:CreateBorder(frameData.iconBorderFrame, { forceUpdate = true })
                    end

                    local iconBorderColor = frameData.iconBorderFrame and frameData.iconBorderFrame.border
                    if iconBorderColor and iconBorderColor.SetBackdropBorderColor then
                        local configColor = styleCache.borderColor
                        iconBorderColor:SetBackdropBorderColor(configColor.r, configColor.g, configColor.b, 1)
                    end
                end
            elseif frameData.barIconPixelBorderStore or frameData.iconBorderFrame then
                if frameData.barIconPixelBorderStore then
                    DisablePixelIconBorderMode(frameData.barIconPixelBorderStore, iconFrame)
                end
                if frameData.iconBorderFrame and frameData.iconBorderFrame.border then
                    frameData.iconBorderFrame.border:Hide()
                end
            end
        end
    end
    if bar then
        bar:ClearAllPoints()
        bar:SetHeight(barHeight)

        if iconPosition == "HIDDEN" then
            CDM_C.SetPixelPerfectPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            CDM_C.SetPixelPerfectPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        elseif iconPosition == "RIGHT" then
            CDM_C.SetPixelPerfectPoint(bar, "LEFT", frame, "LEFT", 0, 0)
            CDM_C.SetPixelPerfectPoint(bar, "RIGHT", iconFrame or frame, iconFrame and "LEFT" or "RIGHT", iconFrame and -iconGap or 0, 0)
        else
            CDM_C.SetPixelPerfectPoint(bar, "LEFT", iconFrame or frame, iconFrame and "RIGHT" or "LEFT", iconFrame and iconGap or 0, 0)
            CDM_C.SetPixelPerfectPoint(bar, "RIGHT", frame, "RIGHT", 0, 0)
        end

        bar:SetStatusBarTexture(barTexture)
        bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)

        if not frameData.barBackground then
            frameData.barBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        end
        frameData.barBackground:ClearAllPoints()
        frameData.barBackground:SetAllPoints(bar)
        frameData.barBackground:SetSnapToPixelGrid(false)
        frameData.barBackground:SetTexelSnappingBias(0)
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
                frameData.barTextContainer:SetFrameLevel(bar:GetFrameLevel() + 4)
            end
            frameData.barTextContainer:Show()

            if nameText then
                InstallBuffBarVisibilityShowHook(frameData, "cdmNameHooked", nameText, "buffBarShowName")
                nameText:SetParent(frameData.barTextContainer)
                if showName then
                    nameText:SetAlpha(1)
                    nameText:Show()
                    nameText:SetIgnoreParentScale(true)
                    nameText:SetFont(fontPath, CDM_C.GetPixelFontSize(nameFontSize), textFontOutline)
                    nameText:SetTextColor(nameColor.r, nameColor.g, nameColor.b, nameColor.a or 1)
                    nameText:SetShadowOffset(0, 0)
                    nameText:SetDrawLayer("OVERLAY", 7)
                    nameText:ClearAllPoints()
                    CDM_C.SetPixelPerfectPoint(nameText, "LEFT", bar, "LEFT", nameOffsetX, nameOffsetY)
                    CDM_C.SetPixelPerfectPoint(nameText, "RIGHT", bar, "RIGHT", -30, nameOffsetY)
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
                    durationText:SetFont(fontPath, CDM_C.GetPixelFontSize(durationFontSize), textFontOutline)
                    durationText:SetTextColor(durationColor.r, durationColor.g, durationColor.b, durationColor.a or 1)
                    durationText:SetShadowOffset(0, 0)
                    durationText:SetDrawLayer("OVERLAY", 7)
                    durationText:ClearAllPoints()
                    CDM_C.SetPixelPerfectPoint(durationText, "RIGHT", bar, "RIGHT", durationOffsetX, durationOffsetY)
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
                    frameData.barAppTextContainer:SetFrameLevel(bar:GetFrameLevel() + 4)
                end

                frameData.barAppTextContainer:Show()
                InstallBuffBarVisibilityShowHook(frameData, "cdmAppHooked", appText, "buffBarShowApplications")
                appText:SetParent(frameData.barAppTextContainer)
                appText:SetAlpha(1)
                appText:Show()
                appText:SetIgnoreParentScale(true)
                appText:SetFont(fontPath, CDM_C.GetPixelFontSize(appFontSize), textFontOutline)
                appText:SetTextColor(appColor.r, appColor.g, appColor.b, appColor.a or 1)
                appText:SetShadowOffset(0, 0)
                appText:SetDrawLayer("OVERLAY", 7)
                appText:SetJustifyH("CENTER")
                appText:SetSize(0, 0)
                appText:ClearAllPoints()
                CDM_C.SetPixelPerfectPoint(appText, "CENTER", bar, appPosition, appOffsetX, appOffsetY)
            else
                if frameData.barAppTextContainer then frameData.barAppTextContainer:Hide() end
                appText:Hide()
                appText:SetAlpha(0)
            end
        end

        local borderActive = IsBorderStyleActive()
        if borderActive then
            local usePixelBorder = IsPixelIconBorderMode()
            if not frameData.barBorderFrame then
                frameData.barBorderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            end
            frameData.barBorderFrame:ClearAllPoints()
            frameData.barBorderFrame:SetAllPoints(bar)
            if frame.GetFrameStrata then
                frameData.barBorderFrame:SetFrameStrata(frame:GetFrameStrata())
            end
            frameData.barBorderFrame:SetFrameLevel((bar:GetFrameLevel() or 0) + 1)

            if usePixelBorder then
                if frameData.barBorderFrame.border then
                    frameData.barBorderFrame.border:Hide()
                end

                frameData.barPixelBorderStore = frameData.barPixelBorderStore or {}
                ApplyPixelIconBorder(frameData.barPixelBorderStore, frameData.barBorderFrame, styleCache.borderColor)
            else
                if frameData.barPixelBorderStore then
                    DisablePixelIconBorderMode(frameData.barPixelBorderStore, frameData.barBorderFrame)
                end

                if BORDER and BORDER.CreateBorder and (borderForce or not frameData.barBorderFrame.border) then
                    BORDER:CreateBorder(frameData.barBorderFrame, { forceUpdate = true })
                end

                local barBorderColor = frameData.barBorderFrame and frameData.barBorderFrame.border
                if barBorderColor and barBorderColor.SetBackdropBorderColor then
                    local configColor = styleCache.borderColor
                    barBorderColor:SetBackdropBorderColor(configColor.r, configColor.g, configColor.b, 1)
                end
            end
        elseif frameData.barPixelBorderStore or frameData.barBorderFrame then
            if frameData.barPixelBorderStore then
                DisablePixelIconBorderMode(frameData.barPixelBorderStore, frameData.barBorderFrame)
            end
            if frameData.barBorderFrame and frameData.barBorderFrame.border then
                frameData.barBorderFrame.border:Hide()
            end
        end
    end

    if borderForce then
        frameData.barBorderInitialized = true
        frameData.barBorderVersionApplied = borderVersion
    end

    if barStyleNeedsUpdate then
        frameData.cdmLastBarStyleVersion = styleVersion
        frameData.cdmLastBarW = targetFrameWidth
        frameData.cdmLastBarH = targetFrameHeight
    end

    frameData.cdmBarStyled = true
end
