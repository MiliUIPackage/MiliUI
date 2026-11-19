------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 460
local FORM_W = 640          -- 捲動內容寬度（扣掉捲軸）

local TABS = {
    { id = "appearance", label = L["Appearance"] },
    { id = "visibility", label = L["Folding"] },
    { id = "mythicPlus", label = L["Mythic+"] },
    { id = "automation", label = L["Automation"] },
    { id = "about",      label = L["About"] },
}
-- 永恆版沒有傳奇鑰石：計時面板整個不啟動（Modules/MythicPlus.lua），分頁也不列
if ns.IS_FOREVER then
    for i = #TABS, 1, -1 do
        if TABS[i].id == "mythicPlus" then tremove(TABS, i) end
    end
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIQuest_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Quest Tracker"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 84,
    tabs     = TABS,
    defaultTab  = "appearance",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.db ~= nil end,
    onShow = function()
        -- 開設定多半就是要調位置：通知 Chrome 蓋上搬家遮罩
        ns.Fire("OptionsShown", true)
    end,
    onHide = function()
        ns.Fire("OptionsShown", false)
    end,
    onBuilt = function(_, panel)
        Options.panel = panel
        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        W.CreateGridToggle(panel, { db = function() return ns.db.optionsWindow end })
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

------------------------------------------------------------
-- 「這個改動要重載才看得到」的提示
--
-- 只給**真的救不回來**的設定用。設定改了畫面沒動，玩家的第一個結論是插件壞了，
-- 所以寧可多一個對話框也不要讓它靜靜地沒反應。
------------------------------------------------------------
local reloadPopup
function Options.AskReload(text)
    local panel = win.panel
    if not panel then return end
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(panel, 340, text, function() ReloadUI() end)
    else
        -- 訊息在共用層是 popup.text 這個 FontString，不是 popup 自己的方法
        reloadPopup.text:SetText(text)
    end
    reloadPopup:Show()
end

function Options.Open(tabId)
    win.Open(tabId)
end
