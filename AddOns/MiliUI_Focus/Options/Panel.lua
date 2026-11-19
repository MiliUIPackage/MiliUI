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

local PANEL_W, PANEL_H = 680, 470
local FORM_W = 620          -- 捲動內容寬度（扣掉捲軸）

local win = W.CreateOptionsWindow({
    name     = "MiliUIFocus_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Focus"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 74,
    tabs = {
        { id = "focus", label = L["Focus"] },
        { id = "bar",   label = L["Marker bar"] },
        { id = "cast",  label = L["Cast bar"] },
        { id = "about", label = L["About"] },
    },
    defaultTab  = "focus",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.db ~= nil end,
    onShow = function()
        ns.CastBar.SetSettingsOpen(true)   -- 施法條顯示範例、可直接拖
    end,
    onHide = function()
        ns.CastBar.SetSettingsOpen(false)
    end,
    onBuilt = function(win, panel)
        Options.panel = panel

        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        W.CreateGridToggle(panel, { db = function() return ns.db.optionsWindow end })

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["MiliUI Focus"] .. "|r v" .. ns.VERSION,
            "",
            L["Set focus with shift-click, mark it automatically, watch what it casts."],
            L["Marking goes through Blizzard's secure raid target action, so it works in combat."],
            "",
            L["Commands: |cffffd200/mfocus|r opens the options, |cffffd200/mfocus check|r reports which frames are hooked, |cffffd200/mfocus reset|r resets everything"],
            "",
            L["Author: Mili (MiliUI package)"],
            "",
            L["This used to be the \"Focus target\" section of the MiliUI package; your old settings were imported the first time this addon ran."],
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
