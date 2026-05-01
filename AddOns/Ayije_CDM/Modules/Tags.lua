local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local LSM = LibStub("LibSharedMedia-3.0")
local TAGS = {}
CDM.TAGS = TAGS
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local UnitPower = UnitPower
local UnitStagger = UnitStagger
local UnitHealthMax = UnitHealthMax
local UnitPowerPercent = UnitPowerPercent
local AbbreviateNumbers = AbbreviateNumbers
local UIParent = UIParent
local canaccessvalue = canaccessvalue
local type = type
local pairs = pairs
local math_floor = math.floor
local math_abs = math.abs
local GetSpellCastCount = C_Spell.GetSpellCastCount
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetTime = GetTime
local TruncateWhenZero = C_StringUtil.TruncateWhenZero
local PowerTypeMana = Enum.PowerType.Mana
local PowerTypeSoulShards = Enum.PowerType.SoulShards
local ScaleTo100 = CurveConstants.ScaleTo100
local IsSafeNumber = CDM.IsSafeNumber

TAGS.textFrames = {}
TAGS.styleDirty = true
TAGS.lastScale = nil

local VALID_TAG_ANCHORS = { LEFT = true, CENTER = true, RIGHT = true }

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

local function GetTagBarKey(textFrame)
    if not textFrame then return nil end
    if textFrame.barKey then return textFrame.barKey end
    local parentBar = textFrame.parentBar
    if parentBar and parentBar.barKey then return parentBar.barKey end
    local pt = textFrame.powerType
    if pt and CDM.POWER_TYPE_TO_BAR_KEY then
        return CDM.POWER_TYPE_TO_BAR_KEY[pt] or pt
    end
    return pt
end

local function AlignCenteredTagToBar(textFrame, force)
    if not textFrame or textFrame._anchor ~= "CENTER" then
        return
    end

    local text = textFrame.text
    local bar = textFrame.parentBar
    if not (text and bar) then
        return
    end

    if not force and textFrame._alignedCenterDone then
        return
    end

    local offsetX = Snap(textFrame._offsetX or 0)
    local offsetY = Snap(textFrame._offsetY or 0)

    text:ClearAllPoints()
    Pixel.SetPoint(text, "CENTER", bar, "CENTER", offsetX, offsetY)
    textFrame._alignedCenterDone = true
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
            return GetSpellCastCount(CDM_C.SOUL_CLEAVE_SPELL_ID) or 0
        elseif powerType == "DevourerSoulFragments" then
            return CDM.GetDevourerSoulValueMax() or 0
        elseif powerType == "MaelstromWeapon" then
            local auraData = GetPlayerAuraBySpellID(CDM_C.MAELSTROM_WEAPON_SPELL_ID)
            return auraData and auraData.applications or 0
        elseif powerType == "Stagger" then
            local bar = CDM.resourceBars and CDM.resourceBars[powerType]
            if bar and bar.staggerPercent then
                return math_floor(bar.staggerPercent + 0.5)
            end
            local stagger = UnitStagger("player")
            local maxHealth = UnitHealthMax("player")
            if not IsSafeNumber(stagger) or not IsSafeNumber(maxHealth) or maxHealth == 0 then
                return 0
            end
            return math_floor((stagger / maxHealth) * 100 + 0.5)
        elseif powerType == "Ironfur" then
            return CDM.GetIronfurStackCount and CDM:GetIronfurStackCount() or 0
        elseif powerType == "IgnorePain" then
            return CDM.GetIgnorePainValue and CDM:GetIgnorePainValue() or 0
        elseif powerType == "TipOfTheSpear" then
            return CDM.GetTipOfTheSpearStacks and CDM:GetTipOfTheSpearStacks() or 0
        end
        return 0
    end

    if powerType == PowerTypeSoulShards then
        if CDM:GetCurrentSpecID() == 267 then
            return UnitPower("player", powerType, true) or 0
        end
        return UnitPower("player", powerType) or 0
    end

    local current = UnitPower("player", powerType)
    return current or 0
end

local function RenderToSTimeText(textFrame)
    local exp = CDM.GetTipOfTheSpearExpirationTime and CDM:GetTipOfTheSpearExpirationTime()
    if not exp then
        textFrame.text:SetText("")
        return
    end
    local remaining = exp - GetTime()
    if remaining <= 0 then
        textFrame.text:SetText("")
        return
    end
    textFrame.text:SetFormattedText("%d", math_floor(remaining + 0.5))
end

local function ToSTagOnUpdate(textFrame, elapsed)
    textFrame._tosTimeAccum = (textFrame._tosTimeAccum or 0) + elapsed
    if textFrame._tosTimeAccum < 0.1 then return end
    textFrame._tosTimeAccum = 0
    RenderToSTimeText(textFrame)
end

local function AttachToSTimeTicker(textFrame)
    if textFrame._tosTimeActive then return end
    textFrame._tosTimeActive = true
    textFrame._tosTimeAccum = 0
    textFrame:SetScript("OnUpdate", ToSTagOnUpdate)
end

local function DetachToSTimeTicker(textFrame)
    if not textFrame._tosTimeActive then return end
    textFrame._tosTimeActive = nil
    textFrame._tosTimeAccum = nil
    textFrame:SetScript("OnUpdate", nil)
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
    text:SetFont(CDM_C.FONT_PATH, Pixel.FontSize(14), CDM_C.FONT_OUTLINE)

    textFrame.text = text
    textFrame.powerType = powerType
    textFrame.parentBar = bar
    textFrame.barKey = bar.barKey or (CDM.POWER_TYPE_TO_BAR_KEY and CDM.POWER_TYPE_TO_BAR_KEY[powerType]) or powerType

    TAGS:UpdateTagStyle(textFrame)
    TAGS:UpdateTagPosition(textFrame)

    TAGS.textFrames[powerType] = textFrame

    return textFrame
end

function TAGS:UpdateTagText(textFrame)
    if not textFrame or not textFrame.text or not textFrame.parentBar or not textFrame.powerType then
        return
    end

    local barKey = GetTagBarKey(textFrame)

    local enabled = barKey and CDM:GetBarSetting(barKey, "tagEnabled")
    if not enabled then
        textFrame:Hide()
        return
    end

    if textFrame.powerType == "TipOfTheSpear" and CDM:GetBarSetting("TipOfTheSpear", "tagShowAuraTime") == true then
        AttachToSTimeTicker(textFrame)
        RenderToSTimeText(textFrame)
        textFrame._lastDisplayValue = nil
        textFrame:Show()
        AlignCenteredTagToBar(textFrame)
        return
    elseif textFrame.powerType == "TipOfTheSpear" then
        DetachToSTimeTicker(textFrame)
    end

    local current = GetCurrentPower(textFrame.powerType)

    local isSecret = (type(current) == "number" and not canaccessvalue(current))
    local lastSecret = (type(textFrame._lastDisplayValue) == "number" and not canaccessvalue(textFrame._lastDisplayValue))

    if isSecret or lastSecret or (textFrame._lastDisplayValue ~= current) then
        textFrame._lastDisplayValue = isSecret and nil or current
        if textFrame.powerType == "Stagger" or textFrame.powerType == "SoulFragments" or textFrame.powerType == "DevourerSoulFragments" or textFrame.powerType == "Ironfur" or textFrame.powerType == "IgnorePain" or textFrame.powerType == "MaelstromWeapon" or textFrame.powerType == "TipOfTheSpear" then
            textFrame.text:SetText(TruncateWhenZero(current))
        elseif textFrame.powerType == PowerTypeMana then
            if CDM:GetBarSetting("Mana", "displayAsPercent") then
                local pct = UnitPowerPercent("player", PowerTypeMana, false, ScaleTo100) or 0
                textFrame.text:SetFormattedText("%d", pct)
            elseif manaAbbrevData then
                -- MiliUI: 開啟在地化縮寫時忽略 K-suffix config，改用語系預設（zhTW 為「萬 / 億」）
                if _G.MiliUI_DB and _G.MiliUI_DB.localeNumberAbbrev ~= false then
                    textFrame.text:SetText(AbbreviateNumbers(current))
                else
                    textFrame.text:SetText(AbbreviateNumbers(current, manaAbbrevData))
                end
            else
                textFrame.text:SetFormattedText("%d", current)
            end
        elseif textFrame.powerType == PowerTypeSoulShards then
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

    local barKey = GetTagBarKey(textFrame)
    local anchor = barKey and CDM:GetBarSetting(barKey, "tagAnchor") or "CENTER"
    if not VALID_TAG_ANCHORS[anchor] then anchor = "CENTER" end
    local offsetX = barKey and CDM:GetBarSetting(barKey, "tagOffsetX") or 0
    local offsetY = barKey and CDM:GetBarSetting(barKey, "tagOffsetY") or 0
    textFrame._anchor = anchor
    textFrame._offsetX = offsetX
    textFrame._offsetY = offsetY

    textFrame.text:SetJustifyH(anchor)
    textFrame.text:ClearAllPoints()
    Pixel.SetPoint(textFrame.text, anchor, textFrame.parentBar, anchor, offsetX, offsetY)
    textFrame._alignedCenterDone = false
    AlignCenteredTagToBar(textFrame, true)
end

function TAGS:UpdateTagStyle(textFrame)
    if not textFrame or not textFrame.text or not textFrame.parentBar then
        return
    end

    local barKey = GetTagBarKey(textFrame)
    local fontSize = barKey and CDM:GetBarSetting(barKey, "tagFontSize") or 14
    local color = barKey and CDM:GetBarSetting(barKey, "tagColor") or { r = 1, g = 1, b = 1, a = 1 }
    local db = CDM.db

    local textFontName = db and db.textFont or "Friz Quadrata TT"
    local rawOutline = db and db.textFontOutline or "OUTLINE"
    local textFontOutline = CDM_C.ResolveOutlineFlags(rawOutline)
    local fontPath = LSM:Fetch("font", textFontName) or CDM_C.FONT_PATH

    textFrame.text:SetIgnoreParentScale(true)
    textFrame.text:SetFont(fontPath, Pixel.FontSize(fontSize), textFontOutline)
    textFrame.text:SetTextColor(color.r, color.g, color.b, color.a)
    textFrame.text:SetShadowOffset(0, 0)
end

function TAGS:UpdateAllTags()
    local needsStyleUpdate = self.styleDirty
    local currentScale = (UIParent and UIParent.GetEffectiveScale) and UIParent:GetEffectiveScale() or 1
    if not self.lastScale then
        self.lastScale = currentScale
    elseif math_abs(currentScale - self.lastScale) > 0.001 then
        needsStyleUpdate = true
        self.lastScale = currentScale
    end

    local hasTextFrames = false

    for powerType, textFrame in pairs(self.textFrames) do
        hasTextFrames = true
        local barKey = GetTagBarKey(textFrame)
        local enabled = barKey and CDM:GetBarSetting(barKey, "tagEnabled") ~= false

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

CDM:RegisterRefreshCallback("tags", function()
    CDM.TAGS:MarkDirty()
    RefreshAllTagsIfAny()
end, 52, { "RESOURCES", "STYLE" })
