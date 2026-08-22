------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟選項按鈕
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local panel = CreateFrame("Frame")

local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
header:SetPoint("CENTER", panel, "CENTER", 0, 70)
header:SetText(ns.PREFIX_COLOR .. L["MiliUI Focus"] .. "|r")

local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
version:SetPoint("CENTER", panel, "CENTER", 0, 40)
version:SetText(("|cffffffff" .. L["Version: %s"] .. "|r"):format(ns.VERSION))

local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
instructions:SetPoint("CENTER", panel, "CENTER", 0, 14)
instructions:SetText("|cffffffff" .. L["Use /mfocus to open options"] .. "|r")

local template = "SharedButtonLargeTemplate"
if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo(template)) then
    template = "UIPanelDynamicResizeButtonTemplate"
end
local button = CreateFrame("Button", nil, panel, template)
button:SetText(L["Open options"])
button.padding = 40
if DynamicResizeButton_Resize then DynamicResizeButton_Resize(button) end
button:SetPoint("CENTER", panel, "CENTER", 0, -30)
button:SetScript("OnClick", function()
    -- 設定視窗是 DIALOG strata，會被暴雪選項蓋住——先關掉再開
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    ns.OpenOptions()
end)

panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function() end

local category = Settings.RegisterCanvasLayoutCategory(panel, L["MiliUI Focus"])
category.ID = L["MiliUI Focus"]
Settings.RegisterAddOnCategory(category)
