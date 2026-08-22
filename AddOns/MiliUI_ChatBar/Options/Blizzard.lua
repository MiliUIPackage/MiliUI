------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟選項按鈕
-- 真正的設定在自己的視窗（Options/Panel.lua），這裡只負責把玩家帶過去
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local panel = CreateFrame("Frame")

local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
header:SetPoint("CENTER", panel, "CENTER", 0, 70)
header:SetText(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r")

local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
version:SetPoint("CENTER", panel, "CENTER", 0, 40)
version:SetText(("|cffffffff" .. L["VERSION_FORMAT"] .. "|r"):format(ns.VERSION))

local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
instructions:SetPoint("CENTER", panel, "CENTER", 0, 14)
instructions:SetText("|cffffffff" .. L["OPEN_HINT"] .. "|r")

local template = "SharedButtonLargeTemplate"
if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo(template)) then
    template = "UIPanelDynamicResizeButtonTemplate"
end
local button = CreateFrame("Button", nil, panel, template)
button:SetText(L["BTN_OPEN_OPTIONS"])
button.padding = 40
if DynamicResizeButton_Resize then DynamicResizeButton_Resize(button) end
button:SetPoint("CENTER", panel, "CENTER", 0, -30)
button:SetScript("OnClick", function()
    -- 設定視窗是 DIALOG strata，會被暴雪選項蓋住——先關掉再開
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    ns.OpenSettings()
end)

panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function() end

local category = Settings.RegisterCanvasLayoutCategory(panel, L["ADDON_NAME"])
category.ID = L["ADDON_NAME"]
Settings.RegisterAddOnCategory(category)
