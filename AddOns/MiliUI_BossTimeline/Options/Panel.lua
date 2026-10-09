------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
-- （骨架照 MiliUI_CrusadingStrikes 的 Options/Panel.lua）
--
-- 視窗開著的時候，畫面上的時間軸會用假資料跑（Screen.SetOptionsOpen）：
-- 玩家一邊調、一邊看到實際位置與大小，也可以直接拖。右上角的格線開關幫忙對齊。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 780, 520
local FORM_W = 720          -- 單欄表單分頁的捲動內容寬度（扣掉捲軸）

local TAB_MIN_W = 74
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20

local panel
local tabButtons = {}
local highlightTab
local currentTab

local TABS = {
    { id = "general", label = L["General"] },
    { id = "style",   label = L["Appearance"] },
    { id = "plans",   label = L["Custom timelines"] },
    { id = "abilities", label = L["Boss abilities"] },
    { id = "about",   label = L["About"] },
}

Options.PANEL_W, Options.PANEL_H, Options.FORM_W = PANEL_W, PANEL_H, FORM_W

function Options.NewTabFrame()
    local tab = CreateFrame("Frame", nil, Options.panel)
    tab:SetAllPoints(Options.panel)
    tab:Hide()
    return tab
end

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 12, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 串接。回傳 content, refreshers
function Options.BuildScrollBody(scroll, controls, ctx, width)
    width = width or FORM_W
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, width)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers
end

-- 分頁共用的 ctx：spec.root = "layout" 讀寫目前方向那一份版面，其餘照 sub 走 db
function Options.MakeCtx(apply)
    return ns.Controls.MakeCtx(function(spec)
        if spec.root == "layout" then return ns.DB.Layout() end
        return ns.db
    end, apply)
end

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    ns.db.optionsWindow.x = math.floor(fx - cx + 0.5)
    ns.db.optionsWindow.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.db.optionsWindow
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local function ShowTab(id)
    W.CloseDropdowns()
    currentTab = id
    ns.Fire("ShowOptionsTab", id)
end

local function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    if locked then
        W.CloseDropdowns()
        panel.combatMask:Show()
    else
        panel.combatMask:Hide()
    end
end

-- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
-- ⚠ 不能單獨設 strata（理由見 MiliUI_CrusadingStrikes/Options/Panel.lua 同名函式）
local function CreateCloseButton(parent, level)
    local b = W.CreateButton(parent, "", "red", 20, 20)
    b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    b:SetFrameLevel(level)
    local x = b:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.85, 0.85)
    b:SetScript("OnClick", function() panel:Hide() end)
    return b
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIBT_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUIBT_Options")

    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r  v" .. ns.VERSION, SavePosition)

    CreateCloseButton(panel, panel:GetFrameLevel() + 200)

    local prev
    for i, tab in ipairs(TABS) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
        b.id = tab.id
        local fs = b:GetFontString()
        local w = TAB_MIN_W
        if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
        P.Size(b, w, TAB_H)
        if prev then
            b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
        else
            b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
        end
        W.MakeDragHandle(b, panel, SavePosition)
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, ShowTab)

    -- ⚠ 要在格線開關之前設（共用層走 HookScript，排在宿主的 SetScript 之後才不會被蓋掉）
    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
        ns.Screen.SetOptionsOpen(false)
        ns.Fire("OptionsClosed")
    end)
    panel:SetScript("OnShow", function()
        SetCombatLocked(InCombatLockdown())
        ns.Screen.SetOptionsOpen(true)
    end)

    -- 格線：拖畫面上的時間軸時對齊用
    W.CreateGridToggle(panel, { db = function() return ns.db.optionsWindow end })

    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    ------------------------------------------------------------
    -- 「關於」分頁
    ------------------------------------------------------------
    local aboutTab = CreateFrame("Frame", nil, panel)
    aboutTab:SetAllPoints(panel)
    aboutTab:Hide()

    local aboutText = aboutTab:CreateFontString(nil, "OVERLAY")
    aboutText:SetFontObject(W.fontNormal)
    aboutText:SetPoint("TOPLEFT", 24, -30)
    aboutText:SetWidth(PANEL_W - 48)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetSpacing(6)
    aboutText:SetText(table.concat({
        ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r v" .. ns.VERSION,
        "",
        L["Redraws Blizzard's boss timeline: text, outline, colors, square icons, vertical or horizontal."],
        L["Every entry shows who put it there — Blizzard, your own custom timeline, or another addon such as DiGua Voice."],
        L["Custom timelines are written into Blizzard's timeline when the pull starts, so DBM's bars and Blizzard's own timeline show them too."],
        "",
        L["Commands: |cffffd200/mbt|r opens the options, |cffffd200/mbt check|r prints what is on the timeline, |cffffd200/mbt reset|r restores the defaults"],
        "",
        L["Author: Mili (MiliUI package)"],
    }, "\n"))

    ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
        aboutTab:SetShown(id == "about")
    end)
end

function Options.CurrentTab()
    return currentTab
end

function Options.Open(tabId)
    if not ns.db then return end
    CreatePanel()
    if panel:IsShown() and not tabId then
        panel:Hide()
        return
    end
    ApplyPosition()
    panel:Show()
    panel:Raise()
    tabId = tabId or currentTab or "general"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end
