------------------------------------------------------------
-- 獨立設定視窗：只在沒有本體宿主時用（Options/Host.lua 決定）
--
-- 內容就是 ns.BuildBody —— 跟本體「便利功能」分頁同一支，寬度也同為 780，
-- 兩邊長得一模一樣。單一頁、沒有分頁鈕。
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
------------------------------------------------------------
local _, ns = ...

local W = ns.W

ns.Options = {}
local Options = ns.Options

-- 寬同本體設定視窗；高＝本體視窗扣掉頂部 banner 之後的內容高
local PANEL_W, PANEL_H = 780, 562

local refresh

local win = W.CreateOptionsWindow({
    name     = "MiliUIQoL_Options",
    width    = PANEL_W, height = PANEL_H,
    title    = function() return ns.PREFIX_COLOR .. ns.TITLE .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    escape   = "panels",
    beforeOpen = function() return ns.db ~= nil end,
    onShow = function()
        if refresh then refresh() end
    end,
    onBuilt = function(_, panel)
        Options.panel = panel
        refresh = ns.BuildBody(panel, PANEL_W)
    end,
})

function Options.Open()
    win.Open()
end
