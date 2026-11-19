------------------------------------------------------------
-- 設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 620, 400
local FORM_W = 560          -- 捲動內容寬度（扣掉捲軸）

local function WindowDB()
    if type(ns.db.windows.options) ~= "table" then
        ns.db.windows.options = { x = 0, y = 0 }
    end
    return ns.db.windows.options
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIShop_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Shopping List"] .. "|r  v" .. ns.VERSION end,
    position = WindowDB,
    tabMinW  = 84,
    tabs = {
        { id = "general", label = L["General"] },
        { id = "about",   label = L["About"] },
    },
    defaultTab  = "general",
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
