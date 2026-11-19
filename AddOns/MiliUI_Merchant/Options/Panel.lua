------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
--
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫
-- 這支插件不一樣的地方。分頁只有兩頁，所以沒有帶 callback 註冊表：各分頁自己呼叫
-- `Options.RegisterTab(id, show)` 掛上來，切換時就地叫一遍。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 560, 460
local FORM_W = 500          -- 捲動內容寬度（扣掉捲軸）

-- id → show(id)。分頁檔在載入時自己報到
local tabHandlers = {}

function Options.RegisterTab(id, show)
    tabHandlers[id] = show
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIMerchant_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Merchant"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 84,
    tabs = {
        { id = "general", label = L["General"] },
        { id = "about",   label = L["About"] },
    },
    defaultTab = "general",
    onSelectTab = function(id)
        for tabId, show in pairs(tabHandlers) do
            show(id == tabId)
        end
    end,
    beforeOpen = function() return ns.db ~= nil end,
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
