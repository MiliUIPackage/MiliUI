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

local PANEL_W, PANEL_H = 640, 440
local FORM_W = 580          -- 捲動內容寬度（扣掉捲軸）

local win = W.CreateOptionsWindow({
    name     = "MiliUICSAA_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Crusading Strikes"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 74,
    tabs = {
        { id = "general",    label = L["General"] },
        { id = "appearance", label = L["Appearance"] },
        { id = "about",      label = L["About"] },
    },
    defaultTab  = "general",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.db ~= nil end,
    onBuilt = function(win, panel)
        Options.panel = panel

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["MiliUI Crusading Strikes"] .. "|r v" .. ns.VERSION,
            "",
            L["Shows how long until your next Crusading Strikes swing, as a bar under your target's nameplate health bar."],
            L["The timing is mirrored straight from Blizzard's Cooldown Manager bar, so it stays accurate in raids and Mythic+."],
            "",
            L["Commands: |cffffd200/dermo|r opens the options, |cffffd200/dermo check|r prints a diagnosis, |cffffd200/dermo reset|r restores the defaults"],
            "",
            L["Author: Mili (MiliUI package)"],
        })

        ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
            aboutTab:SetShown(id == "about")
        end)
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody
Options.FORM_W = FORM_W

function Options.Open(tabId)
    win.Open(tabId)
end
