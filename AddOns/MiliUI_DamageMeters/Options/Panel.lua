------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 骨架在共用層（Libs/MiliUIWidgets/Window.lua 的 W.CreateOptionsWindow），這裡只寫差異
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 500
local FORM_W = 640

-- 64 不是 72：分頁列右邊還有「預覽」「格線」兩顆開關（74 ＋ 74），除錯分頁出現時
-- 八顆分頁要在 700 − 154 的寬度內排完，72 會跟預覽鈕疊在一起
local TAB_MIN_W = 64
local TAB_H     = 22
local TAB_GAP   = 3

-- 「預覽: ON／OFF」：分頁列右側、格線開關的左邊。開著時統計視窗畫範例資料（Meter/Preview.lua）。
-- 長相跟格線開關一樣：開＝primary、關＝normal（套組開關型按鈕的規則）。
-- 顯示的是「畫面上現在是不是預覽」而不是玩家按過什麼：戰鬥把它關掉時按鈕要跟著變 OFF
local PREVIEW_BTN_W = 74

local function CreatePreviewToggle(panel, gridBtn)
    local b = W.CreateButton(panel, "", "normal", PREVIEW_BTN_W, TAB_H)
    b:SetPoint("BOTTOMRIGHT", gridBtn, "BOTTOMLEFT", -TAB_GAP, 0)
    -- 寬度照 ON／OFF 比較寬的那個一次定死（同格線開關）：切換時不伸縮，左邊的分頁才不會被擠到
    local fs = b:GetFontString()
    local w = PREVIEW_BTN_W
    for _, v in ipairs({ "ON", "OFF" }) do
        b:SetText(L["Preview"] .. ": " .. v)
        w = math.max(w, math.ceil(fs:GetStringWidth()) + W.BTN_TEXT_PAD)
    end
    P.Size(b, w, TAB_H)
    local function Paint()
        local on = ns.Preview.IsActive()
        b:SetText(L["Preview"] .. ": " .. (on and "ON" or "OFF"))
        W.SetButtonVariant(b, on and "primary" or "normal")
    end
    b:SetScript("OnClick", function() ns.Preview.Set(not ns.Preview.IsActive()) end)
    -- HookScript：CreateButton 的 OnEnter／OnLeave 管滑過的配色，不能蓋掉
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Preview"], 1, 1, 1)
        GameTooltip:AddLine(L["While on, the meters show sample data so you can see how your style changes look. Turn it off to see your real data. Edit Mode shows the preview too, and combat turns it off."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ns.RegisterCallback("PreviewChanged", "optionsPanel", Paint)
    Paint()
end

local win = W.CreateOptionsWindow({
    name     = "MiliUIDM_Options",
    width    = PANEL_W, height = PANEL_H, formW = FORM_W,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Damage Meters"] .. "|r  v" .. ns.VERSION end,
    -- 視窗位置是帳號層的，不跟設定檔走
    position = function() return ns.DB.Account().optionsWindow end,
    tabMinW  = TAB_MIN_W,
    tabs = {
        { id = "general", label = L["General"] },
        { id = "bars",    label = L["Bars"] },
        { id = "text",    label = L["Text"] },
        { id = "window",  label = L["Window"] },
        { id = "each",    label = L["Per window"] },
        { id = "share",   label = L["Profile"] },
        { id = "about",   label = L["About"] },
        { id = "debug",   label = L["Debug"], hidden = true },   -- /mdm debug 之後才出現（Options/Tab_Debug.lua）
    },
    defaultTab  = "general",
    onSelectTab = function(id) ns.Fire("ShowOptionsTab", id) end,
    beforeOpen  = function() return ns.db ~= nil end,
    lockAfterOnShow = true,
    onShow = function()
        ns._optionsOpen = true
        if ns.Windows then ns.Windows.UpdateVisibility() end
        ns.Preview.Sync()   -- 每次打開都重新預覽（見 Meter/Preview.lua）
    end,
    onHide = function()
        ns._optionsOpen = false
        -- 設定開著時所有視窗強制顯示，關掉要把顯示條件放回去
        if ns.Windows then
            ns.Windows.HideIdentify()   -- 「各視窗」分頁的編號標示不能留在畫面上
            ns.Windows.UpdateVisibility()
        end
        ns.Preview.Sync()   -- 預覽跟著設定視窗收掉，換回真資料
    end,
    onBuilt = function(_, panel)
        Options.panel = panel
        -- 右上角「格線: ON／OFF」（共用層，滑過調間距）：開著設定視窗拖框時對齊用。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        local grid = W.CreateGridToggle(panel, { db = function() return ns.DB.Account().optionsWindow end })
        CreatePreviewToggle(panel, grid.button)
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

-- /mdm debug：「除錯」分頁鈕現身（這次登入期間一直在）並切過去
function Options.ShowDebugTab()
    win.Build()
    win.SetTabShown("debug", true)
    Options.Open("debug")
end
