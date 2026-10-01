------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
-- （骨架照 MiliUI_DamageMeters / MiliUI_Focus 的 Options/Panel.lua）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 620, 470
local FORM_W = 560

local TAB_MIN_W = 72
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20

local panel
local tabButtons = {}
local highlightTab
local closeBtn

local TABS = {
    { id = "map",     label = L["Minimap"] },
    { id = "buttons", label = L["Addon buttons"] },
    { id = "info",    label = L["Social bar"] },
    { id = "about", label = L["About"] },
}

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

function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width or FORM_W, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, width or FORM_W)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers
end

Options.FORM_W = FORM_W
-- 頁面內容的寬度：左右各留 16，跟頁首那條標題線一樣長。表單控件用的是比較窄的
-- FORM_W（滑桿右邊要留手感空間），但**佔滿一行的東西**——標題線、清單——
-- 一律用這個，否則右邊界會有兩套，看起來就是「右邊沒對齊」。
Options.CONTENT_W = PANEL_W - 32

-- 每個分頁都長一樣的 ctx：讀寫都在 db 最上層，套用就是「重跑一次外觀」。
function Options.MakeCtx()
    return {
        get = function(spec) return ns.DB.Get()[spec.key] end,
        set = function(spec, v) ns.DB.Get()[spec.key] = v end,
        apply = function() ns.Fire("ConfigChanged") end,
    }
end

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    local w = ns.DB.OptionsWindow()
    w.x = math.floor(fx - cx + 0.5)
    w.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.DB.OptionsWindow()
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local function ShowTab(id)
    W.CloseDropdowns()
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
--
-- ⚠ 關閉鈕**不能單獨設 strata**。子框一旦 SetFrameStrata 過，面板之後被抬層級時它就不跟著走：
--   面板 Raise（Open 裡）、拖曳的 StartMoving（會自動 Raise）都會把面板抬上去，關閉鈕留在原地
--   ⇒ 掉到面板背景後面，看起來暗掉、點不到。所以一般狀態的關閉鈕只設相對層級；
--   戰鬥中用的是**建在遮罩裡的另一顆**，跟著遮罩的 strata。
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

    panel = W.CreateFrame("MiliUIMap_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUIMap_Options")

    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. L["MiliUI Minimap"] .. "|r  v" .. ns.VERSION, SavePosition)

    -- +200：頁面裡有層級比較高的子框，關閉鈕要壓得過它們。
    -- 相對層級在面板被抬高時會跟著平移，所以只要設這一次。
    closeBtn = CreateCloseButton(panel, panel:GetFrameLevel() + 200)

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

    -- 設定開著時一律顯示拖曳遮罩（玩家開設定多半就是要調位置，不該逼他先去找
    -- 「鎖定位置」那個勾選框），關掉就回到設定值。
    -- ⚠ 走 RefreshDrag 不是 SetLocked —— 後者會寫進 DB，等於每開一次設定就把
    --   玩家的鎖定狀態洗掉一次。
    panel:SetScript("OnShow", function()
        ns._optionsOpen = true
        ns.Skin.RefreshDrag()
        SetCombatLocked(InCombatLockdown())
    end)
    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
        ns._optionsOpen = false
        ns.Skin.RefreshDrag()
    end)

    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)
end

function Options.Open(tabId)
    if not ns.DB.Get() then return end
    CreatePanel()
    if panel:IsShown() and not tabId then
        panel:Hide()
        return
    end
    ApplyPosition()
    panel:Show()
    panel:Raise()
    tabId = tabId or "map"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then highlightTab(b); break end
    end
    ShowTab(tabId)
end
