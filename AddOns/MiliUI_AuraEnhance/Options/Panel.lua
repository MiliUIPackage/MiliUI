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

local PANEL_W, PANEL_H = 640, 420
local FORM_W = 580          -- 捲動內容寬度（扣掉捲軸）

local win = W.CreateOptionsWindow({
    name     = "MiliUIAura_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Aura Enhance"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 84,
    tabs = {
        { id = "duration", label = L["Duration text"] },
        { id = "count",    label = L["Stacks"] },
        { id = "skin",     label = L["Icon skin"] },
        { id = "about",    label = L["About"] },
    },
    defaultTab  = "duration",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.db ~= nil end,
    onBuilt = function(_, panel)
        Options.panel = panel
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

function Options.Open(tabId)
    win.Open(tabId)
end
