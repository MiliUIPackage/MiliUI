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
    name     = "MiliUIInfo_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r  v" .. ns.VERSION end,
    position = WindowPos,
    tabMinW  = 74,
    tabs = {
        { id = "general",    label = L["TAB_GENERAL"] },
        { id = "blocks",     label = L["TAB_BLOCKS"] },
        { id = "micro",      label = L["TAB_MICRO"] },
        { id = "mounts",     label = L["TAB_MOUNTS"] },
        { id = "repair",     label = L["TAB_REPAIR"] },
        { id = "readycheck", label = L["TAB_READYCHECK"] },
        { id = "about",      label = L["TAB_ABOUT"] },
    },
    defaultTab  = "general",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() ns.InitDB() end,
    -- 設定開著時在資訊列上蓋「拖曳移動」遮罩（玩家開設定多半就是要調位置），
    -- 關掉就收。跟編輯模式的藍框是兩套視覺。
    lockAfterOnShow = true,
    onShow = function() ns.SetBarMoveOverlayShown(true) end,
    onHide = function() ns.SetBarMoveOverlayShown(false) end,
    onBuilt = function(win, panel)
        Options.panel = panel

        ------------------------------------------------------------
        -- 「關於」分頁
        ------------------------------------------------------------
        local aboutTab, aboutText = win.MakeAboutTab({
            ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r v" .. ns.VERSION,
            "",
            L["SETTINGS_MAIN_DESC"],
            "",
            L["ABOUT_SLASH"],
            "",
            L["ABOUT_AUTHOR"],
        })

        ------------------------------------------------------------
        -- 還原全部設定
        --
        -- 破壞性動作，所以 (1) 收在「關於」分頁最下面、不跟日常設定混在一起，
        -- (2) 紅色按鈕，(3) 一定要過確認彈窗。
        -- 還原之後把當前分頁重跑一次，畫面上的控制項才會顯示新值——
        -- 各分頁的 refreshers 只在 ShowOptionsTab 時才重讀。
        ------------------------------------------------------------
        local resetBtn = W.CreateButton(aboutTab, L["RESET_ALL"], "red", 180, 24)
        resetBtn:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -24)
        resetBtn:SetScript("OnClick", function(self)
            if not self.popup then
                self.popup = W.CreateConfirmPopup(panel, 320, L["RESET_ALL_CONFIRM"], function()
                    ns.ResetDB()
                    win.ShowTab(win.CurrentTab() or "about")
                    print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r " .. L["MSG_RESET_ALL"])
                end)
            end
            self.popup:Show()
        end)

        local resetHint = aboutTab:CreateFontString(nil, "OVERLAY")
        resetHint:SetFontObject(W.fontSmall)
        resetHint:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
        resetHint:SetWidth(PANEL_W - 48)
        resetHint:SetJustifyH("LEFT")
        resetHint:SetTextColor(0.6, 0.6, 0.6)
        resetHint:SetText(L["RESET_ALL_DESC"])

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
