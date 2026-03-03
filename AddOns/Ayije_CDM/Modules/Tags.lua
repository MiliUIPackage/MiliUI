local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local LSM = LibStub("LibSharedMedia-3.0")
local TAGS = {}
CDM.TAGS = TAGS
local SetPixelPerfectPoint = CDM_C.SetPixelPerfectPoint
local ToPixelCountForRegion = CDM_C.ToPixelCountForRegion
local SetPointPixels = CDM_C.SetPointPixels

TAGS.textFrames = {}
TAGS.styleDirty = true
TAGS.lastScale = nil

-- AbbreviateNumbers handles secret values natively (Blizzard API)
local manaAbbrevData
if CreateAbbreviateConfig then
    manaAbbrevData = {
        config = CreateAbbreviateConfig({
            {breakpoint = 1000, abbreviation = "K", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false},
            {breakpoint = 100000, abbreviation = "K", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false},
        })
    }
end

function TAGS:MarkDirty()
    self.styleDirty = true
end

local function IsBar2(textFrame)
    if not textFrame or not textFrame.powerType then
        return false
    end

    local powerTypes = CDM.currentPowerTypes
    if powerTypes and #powerTypes >= 2 and powerTypes[2] == textFrame.powerType then
        return true
    end

    return false
end

local function AlignCenteredTagToBar(textFrame)
    if not textFrame or textFrame._anchor ~= "CENTER" then
        return
    end

    local text = textFrame.text
    local bar = textFrame.parentBar
    if not (text and bar) then
        return
    end

    local offsetXPx = ToPixelCountForRegion(textFrame._offsetX or 0, bar, 0)
    local offsetYPx = ToPixelCountForRegion(textFrame._offsetY or 0, bar, 0)
    local biasXSubPx, biasYPx = 0.5, 0

    text:ClearAllPoints()
    SetPointPixels(text, "CENTER", bar, "CENTER", offsetXPx + biasXSubPx, offsetYPx + biasYPx, bar)
end


local function RefreshAllTagsIfAny()
    if next(CDM.TAGS.textFrames) then
        CDM.TAGS:UpdateAllTags()
    end
end

local function GetCurrentPower(powerType)
    if not powerType then return 0 end

    if type(powerType) == "string" then
        if powerType == "SoulFragments" then
            return C_Spell.GetSpellCastCount(CDM_C.SOUL_CLEAVE_SPELL_ID) or 0
        elseif powerType == "MaelstromWeapon" then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(CDM_C.MAELSTROM_WEAPON_SPELL_ID)
            return auraData and auraData.applications or 0
        elseif powerType == "Stagger" then
            local bar = CDM.resourceBars and CDM.resourceBars[powerType]
            if bar and bar.staggerPercent then
                return math.floor(bar.staggerPercent + 0.5)
            end
            local stagger = UnitStagger("player")
            local maxHealth = UnitHealthMax("player")
            if not CDM.IsSafeNumber(stagger) or not CDM.IsSafeNumber(maxHealth) or maxHealth == 0 then
                return 0
            end
            return math.floor((stagger / maxHealth) * 100 + 0.5)
        end
        return 0
    end

    if powerType == Enum.PowerType.SoulShards then
        if CDM:GetCurrentSpecID() == 267 then
            return UnitPower("player", powerType, true) or 0
        end
        return UnitPower("player", powerType) or 0
    end

    local current = UnitPower("player", powerType)
    return current or 0
end

local function CreateTagText(bar, powerType)
    if not bar then
        return nil
    end

    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar)
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 15)

    local text = textFrame:CreateFontString(nil, "OVERLAY")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    text:SetIgnoreParentScale(true)
    text:SetFont(CDM_C.FONT_PATH, CDM_C.GetPixelFontSize(14), CDM_C.FONT_OUTLINE)

    textFrame.text = text
    textFrame.powerType = powerType
    textFrame.parentBar = bar

    TAGS:UpdateTagStyle(textFrame)
    TAGS:UpdateTagPosition(textFrame)

    TAGS.textFrames[powerType] = textFrame

    return textFrame
end

function TAGS:UpdateTagText(textFrame)
    if not textFrame or not textFrame.text or not textFrame.parentBar or not textFrame.powerType then
        return
    end

    local isBar2 = IsBar2(textFrame)

    local enabled = CDM:GetTagEnabled(isBar2)
    if not enabled then
        textFrame:Hide()
        return
    end

    local current = GetCurrentPower(textFrame.powerType)

    -- type() check prevents "forbidden table" error when calling issecretvalue()
    local isSecret = (type(current) == "number" and issecretvalue(current))
    local lastSecret = (type(textFrame._lastDisplayValue) == "number" and issecretvalue(textFrame._lastDisplayValue))

    if isSecret or lastSecret or (textFrame._lastDisplayValue ~= current) then
        textFrame._lastDisplayValue = isSecret and nil or current
        if textFrame.powerType == "Stagger" or textFrame.powerType == "SoulFragments" then
            textFrame.text:SetText(C_StringUtil.TruncateWhenZero(current))
        elseif textFrame.powerType == Enum.PowerType.Mana then
            if CDM.db and CDM.db.resourcesManaPercentage then
                local pct = UnitPowerPercent("player", Enum.PowerType.Mana, false, CurveConstants.ScaleTo100) or 0
                textFrame.text:SetFormattedText("%d", pct)
            elseif manaAbbrevData then
                textFrame.text:SetText(AbbreviateNumbers(current, manaAbbrevData))
            else
                textFrame.text:SetFormattedText("%d", current)
            end
        elseif textFrame.powerType == Enum.PowerType.SoulShards then
            if CDM:GetCurrentSpecID() == 267 then
                if not isSecret and current % 10 == 0 then
                    textFrame.text:SetFormattedText("%d", current / 10)
                else
                    textFrame.text:SetFormattedText("%.1f", current / 10)
                end
            else
                textFrame.text:SetFormattedText("%d", current)
            end
        else
            textFrame.text:SetFormattedText("%d", current)
        end
    end
    textFrame:Show()
    AlignCenteredTagToBar(textFrame)
end

function TAGS:UpdateTagPosition(textFrame)
    if not textFrame or not textFrame.text or not textFrame.parentBar then
        return
    end

    local isBar2 = IsBar2(textFrame)
    local anchorKey = isBar2 and "resourcesBar2TagAnchor" or "resourcesBar1TagAnchor"
    local offsetXKey = isBar2 and "resourcesBar2TagOffsetX" or "resourcesBar1TagOffsetX"
    local offsetYKey = isBar2 and "resourcesBar2TagOffsetY" or "resourcesBar1TagOffsetY"

    local db = CDM.db
    local anchor = db and db[anchorKey] or "CENTER"
    local validAnchors = { LEFT = true, CENTER = true, RIGHT = true }
    if not validAnchors[anchor] then anchor = "CENTER" end
    local offsetX = db and db[offsetXKey] or 0
    local offsetY = db and db[offsetYKey] or 0
    textFrame._anchor = anchor
    textFrame._offsetX = offsetX
    textFrame._offsetY = offsetY

    textFrame.text:SetJustifyH(anchor)
    textFrame.text:ClearAllPoints()
    SetPixelPerfectPoint(textFrame.text, anchor, textFrame.parentBar, anchor, offsetX, offsetY, textFrame.parentBar)
    AlignCenteredTagToBar(textFrame)
end

function TAGS:UpdateTagStyle(textFrame)
    if not textFrame or not textFrame.text or not textFrame.parentBar then
        return
    end

    local isBar2 = IsBar2(textFrame)
    local fontSizeKey = isBar2 and "resourcesBar2TagFontSize" or "resourcesBar1TagFontSize"
    local colorKey = isBar2 and "resourcesBar2TagColor" or "resourcesBar1TagColor"

    local db = CDM.db
    local fontSize = db and db[fontSizeKey] or 14
    local color = db and db[colorKey] or { r = 1, g = 1, b = 1, a = 1 }

    local textFontName = db and db.textFont or "Friz Quadrata TT"
    local rawOutline = db and db.textFontOutline or "OUTLINE"
    local textFontOutline = (rawOutline == "NONE") and "" or rawOutline
    local fontPath = LSM:Fetch("font", textFontName) or CDM_C.FONT_PATH

    textFrame.text:SetIgnoreParentScale(true)
    textFrame.text:SetFont(fontPath, CDM_C.GetPixelFontSize(fontSize), textFontOutline)
    textFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
    textFrame.text:SetShadowOffset(0, 0)
end

function TAGS:UpdateAllTags()
    local needsStyleUpdate = self.styleDirty
    local currentScale = (UIParent and UIParent.GetEffectiveScale) and UIParent:GetEffectiveScale() or 1
    if not self.lastScale then
        self.lastScale = currentScale
    elseif math.abs(currentScale - self.lastScale) > 0.001 then
        needsStyleUpdate = true
        self.lastScale = currentScale
    end

    local hasTextFrames = false

    for powerType, textFrame in pairs(self.textFrames) do
        hasTextFrames = true
        local isBar2 = IsBar2(textFrame)
        local enabled = CDM:GetTagEnabled(isBar2)

        if enabled then
            if needsStyleUpdate then
                self:UpdateTagPosition(textFrame)
                self:UpdateTagStyle(textFrame)
                textFrame._lastDisplayValue = nil
            end
            self:UpdateTagText(textFrame)
        else
            textFrame:Hide()
        end
    end

    if needsStyleUpdate and hasTextFrames then
        self.styleDirty = false
    end
end

function TAGS:CreateTag(bar, powerType)
    if self.textFrames[powerType] then
        return self.textFrames[powerType]
    end

    local textFrame = CreateTagText(bar, powerType)

    if textFrame then
        self:UpdateTagText(textFrame)
    end

    return textFrame
end

function TAGS:RemoveTag(powerType)
    local textFrame = self.textFrames[powerType]
    if textFrame then
        textFrame:Hide()
        textFrame:SetParent(nil)
        self.textFrames[powerType] = nil
    end
end

-- =========================================================================
--  REFRESH CALLBACK REGISTRATION
-- =========================================================================

CDM:RegisterRefreshCallback("tags", function()
    CDM.TAGS:MarkDirty()
    RefreshAllTagsIfAny()
end, 52)
