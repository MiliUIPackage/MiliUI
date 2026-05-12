------------------------------------------------------------
-- MiliUI: 在地化數字縮寫
-- 將 Ayije_CDM 的法力顯示從 K 改為在地語系格式（zhTW 為萬/億）。
--
-- 實作方式：
--   hooksecurefunc post-hook CDM.TAGS:UpdateTagText，
--   在原函式設完 K 格式後，用 AbbreviateNumbers(current)
--   覆蓋為語系預設格式。不修改 Ayije_CDM 原檔。
------------------------------------------------------------

local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

MiliUI_LocaleNumberAbbrev = MiliUI_LocaleNumberAbbrev or {}
local M = MiliUI_LocaleNumberAbbrev

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.localeNumberAbbrev == nil then
        MiliUI_DB.localeNumberAbbrev = true
    end

    local CDM = _G.Ayije_CDM
    if not CDM or not CDM.TAGS then return end

    local PowerTypeMana = Enum.PowerType.Mana
    local ScaleTo100 = CurveConstants.ScaleTo100
    local UnitPower = UnitPower
    local AbbreviateNumbers = AbbreviateNumbers

    hooksecurefunc(CDM.TAGS, "UpdateTagText", function(_, textFrame)
        if not MiliUI_DB.localeNumberAbbrev then return end
        if not textFrame or not textFrame.text or textFrame.powerType ~= PowerTypeMana then return end
        if CDM:GetBarSetting("Mana", "displayAsPercent") then return end

        local current = UnitPower("player", PowerTypeMana)
        if textFrame._miliLastMana == current then return end
        textFrame._miliLastMana = current
        textFrame.text:SetText(AbbreviateNumbers(current))
    end)
end)

function M.SetEnabled(v)
    v = v and true or false
    if not MiliUI_DB then MiliUI_DB = {} end
    MiliUI_DB.localeNumberAbbrev = v
end

function M.IsEnabled()
    if not MiliUI_DB then return true end
    return MiliUI_DB.localeNumberAbbrev ~= false
end

function M.IsAvailable()
    return _G.Ayije_CDM ~= nil
end
