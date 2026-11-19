------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
--
-- 視窗開著的時候，畫面上的時間軸會用假資料跑（Screen.SetOptionsOpen）：
-- 玩家一邊調、一邊看到實際位置與大小，也可以直接拖。右上角的格線開關幫忙對齊。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 780, 520
local FORM_W = 720          -- 單欄表單分頁的捲動內容寬度（扣掉捲軸）

Options.PANEL_W, Options.PANEL_H, Options.FORM_W = PANEL_W, PANEL_H, FORM_W

local win = W.CreateOptionsWindow({
    name     = "MiliUIBT_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r  v" .. ns.VERSION end,
    position = function() return ns.db.optionsWindow end,
    tabMinW  = 74,
    tabs = {
        { id = "general", label = L["General"] },
        { id = "style",   label = L["Appearance"] },
        { id = "plans",   label = L["Bosses"] },
        { id = "about",   label = L["About"] },
    },
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    -- 沒指定就回到上次那一頁；「首領」頁的兩個區塊可以直接指定（導覽卡用）：
    -- abilities／reminders → plans 分頁
    resolveTab = function(tabId, current)
        if tabId == "abilities" or tabId == "reminders" then
            ns.db.planView.section = tabId
            tabId = "plans"
        end
        return tabId or current or "general"
    end,
    beforeOpen = function() return ns.db ~= nil end,
    onShow = function()
        ns.Screen.SetOptionsOpen(true)
        -- 第一次打開：導覽卡（分頁還沒切好，晚一幀再開，才蓋在正確的分頁上）
        if not ns.db.seenIntro then C_Timer.After(0, ns.Intro.Show) end
    end,
    onHide = function()
        ns.Screen.SetOptionsOpen(false)
        ns.Fire("OptionsClosed")
    end,
    onBuilt = function(win, panel)
        Options.panel = panel

        -- 格線：拖畫面上的時間軸時對齊用（骨架的 SetScript 已經排在前面，共用層走 HookScript）
        W.CreateGridToggle(panel, { db = function() return ns.db.optionsWindow end })

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab, aboutText = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r v" .. ns.VERSION,
            "",
            L["Redraws Blizzard's boss timeline: text, outline, colors, square icons, vertical or horizontal."],
            L["Every entry shows who put it there — Blizzard, your own custom timeline, or another addon such as DiGua Voice."],
            L["Custom timelines are written into Blizzard's timeline when the pull starts, so DBM's bars and Blizzard's own timeline show them too."],
            "",
            L["Commands: |cffffd200/mbt|r opens the options, |cffffd200/mbt check|r prints what is on the timeline, |cffffd200/mbt reset|r restores the defaults"],
            "",
            L["Author: Mili (MiliUI package)"],
        })

        local again = W.CreateButton(aboutTab, L["Show the intro again"], "normal", 140, 22)
        W.FitButton(again, 140, 22)
        again:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -16)
        again:SetScript("OnClick", function() ns.Intro.Show() end)

        ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
            aboutTab:SetShown(id == "about")
        end)
    end,
})

Options.NewTabFrame     = win.NewTabFrame
Options.MakeFormTab     = win.MakeFormTab
Options.BuildScrollBody = win.BuildScrollBody

-- 分頁共用的 ctx：spec.root = "layout" 讀寫目前方向那一份版面，其餘照 sub 走 db
function Options.MakeCtx(apply)
    return ns.Controls.MakeCtx(function(spec)
        if spec.root == "layout" then return ns.DB.Layout() end
        return ns.db
    end, apply)
end

function Options.CurrentTab()
    return win.CurrentTab()
end

function Options.Open(tabId)
    win.Open(tabId)
end
