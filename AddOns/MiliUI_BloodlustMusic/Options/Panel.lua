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

local PANEL_W, PANEL_H = 700, 480
local FORM_W = 640          -- 捲動內容寬度（扣掉捲軸）

-- 視窗位置存在自己的 SavedVariables 裡。Config.lua 的 DB_DEFAULTS 沒有這一格，
-- 從舊版升上來的 DB 也不會有，所以在這裡補而不是假設它存在。
local function WindowPos()
    local db = ns.GetDB()
    if type(db.optionsWindow) ~= "table" then db.optionsWindow = { x = 0, y = 0 } end
    return db.optionsWindow
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIBLM_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r  v" .. ns.VERSION end,
    position = WindowPos,
    tabMinW  = 74,
    tabs = {
        { id = "music",    label = L["SETTINGS_MUSIC"] },
        { id = "tracks",   label = L["TAB_TRACKS"] },
        { id = "bar",      label = L["SETTINGS_BAR"] },
        { id = "reminder", label = L["SETTINGS_REMINDER"] },
        { id = "about",    label = L["TAB_ABOUT"] },
    },
    defaultTab  = "music",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() ns.InitDB() end,
    onHide = function()
        ns.StopPreview()          -- 關窗還在試聽的話，聲音會一直放到 40 秒結束
    end,
    onBuilt = function(win, panel)
        Options.panel = panel

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r v" .. ns.VERSION,
            "",
            L["SETTINGS_MAIN_DESC"],
            "",
            L["ABOUT_SLASH"],
            "",
            L["CREDIT_DFTL"],
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
