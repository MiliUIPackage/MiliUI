------------------------------------------------------------
-- 暴雪「選項 > 插件」入口頁：名稱＋版本＋開啟設定按鈕
-- 分類名沿用「0米利UI設定」排最前，顯示名由 Enhance/AddonNames.lua 洗掉開頭的 0
------------------------------------------------------------
local _, ns = ...

local panel = CreateFrame("Frame")

local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
header:SetPoint("CENTER", panel, "CENTER", 0, 70)
header:SetText(ns.PREFIX_COLOR .. "米利UI套組|r")

local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
version:SetPoint("CENTER", panel, "CENTER", 0, 40)
version:SetText("|cffffffff版本：" .. ns.VERSION .. "|r")

local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
instructions:SetPoint("CENTER", panel, "CENTER", 0, 14)
instructions:SetText("|cffffffff輸入 /miliui，或從 ESC 選單的「米利UI設定」按鈕開啟|r")

local template = "SharedButtonLargeTemplate"
if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo(template)) then
    template = "UIPanelDynamicResizeButtonTemplate"
end
local button = CreateFrame("Button", nil, panel, template)
button:SetText("開啟設定")
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

local category = Settings.RegisterCanvasLayoutCategory(panel, "0米利UI設定")
-- 不覆寫 category.ID：Blizzard 12.0+ OpenSettingsPanel 內部需要 numeric ID
Settings.RegisterAddOnCategory(category)
-- 舊接口：其他模組曾經用它開暴雪面板，留著指向這一頁
MiliUI = MiliUI or {}
MiliUI.SettingsCategory = category
