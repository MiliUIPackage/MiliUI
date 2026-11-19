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

local PANEL_W, PANEL_H = 660, 470
local FORM_W = 600          -- 捲動內容寬度（扣掉捲軸）

-- 視窗位置存在自己的 SavedVariables 裡（頂層，跟 Chatbar 那張表分開：
-- 那張是「聊天列本身」的設定，全部重置會整個丟掉）
local function WindowPos()
    ns.InitDB()
    if type(MiliUI_ChatBar_DB.optionsWindow) ~= "table" then
        MiliUI_ChatBar_DB.optionsWindow = { x = 0, y = 0 }
    end
    return MiliUI_ChatBar_DB.optionsWindow
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIChatBar_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r  v" .. ns.VERSION end,
    position = WindowPos,
    tabMinW  = 74,
    tabs = {
        { id = "general",  label = L["TAB_GENERAL"] },
        { id = "channels", label = L["SETTINGS_CHANNELS"] },
        { id = "about",    label = L["TAB_ABOUT"] },
    },
    defaultTab  = "general",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() ns.InitDB() end,
    onBuilt = function(win, panel)
        Options.panel = panel

        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        W.CreateGridToggle(panel, { db = WindowPos })

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r v" .. ns.VERSION,
            "",
            L["SETTINGS_MAIN_DESC"],
            "",
            L["ABOUT_USAGE"],
            L["ABOUT_TAB"],
            "",
            L["ABOUT_AUTHOR"],
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
Options.PANEL_W, Options.PANEL_H = PANEL_W, PANEL_H

function Options.Open(tabId)
    win.Open(tabId)
end
