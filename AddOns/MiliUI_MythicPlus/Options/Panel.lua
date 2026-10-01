------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
--
-- 骨架照套組裡其他單體插件的同名檔案，分頁只有兩頁，所以沒有 callback 註冊表：
-- 各分頁自己呼叫 `Options.RegisterTab(id, show)` 掛上來，切換時就地叫一遍。
--
-- ⚠ 這是「設定視窗皮」（不透明底、純黑邊），跟結算面板的提示皮是兩套並存。
--   判準：常駐在遊戲畫面上、背後有地形在動的走 HUD／提示皮；獨立的設定視窗走這套。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 560, 420
local FORM_W = 500          -- 捲動內容寬度（扣掉捲軸）

local TAB_MIN_W = 84
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20

local panel
local tabButtons = {}
local highlightTab
local closeBtn

local TABS = {
    { id = "general", label = L["General"] },
    { id = "keystone", label = L["Keystone"] },
    { id = "chat",     label = L["Chat"] },
    { id = "about",   label = L["About"] },
}

local tabHandlers = {}

function Options.RegisterTab(id, show)
    tabHandlers[id] = show
end

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
    local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, 4, -4, width or FORM_W)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers, rows
end

Options.FORM_W = FORM_W

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    if not (cx and fx) then return end
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
    for tabId, show in pairs(tabHandlers) do
        show(id == tabId)
    end
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

    panel = W.CreateFrame("MiliUIMythicPlus_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUIMythicPlus_Options")

    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. L["MiliUI Mythic Plus"] .. "|r  v" .. ns.VERSION, SavePosition)

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

    -- 結算面板的入口：分頁那一排的最右邊，每一頁都看得到（使用者點名：每次打 /mmp 太不直覺）。
    -- 那排右半本來就空著，米利頭像的設定搜尋框也放這個位置。
    -- ⚠ 先關設定視窗再開面板：面板是 HIGH、設定視窗是 DIALOG，不關的話面板開在視窗
    --   底下、大半被蓋住，看起來像按了沒反應（原本放在「一般」分頁裡那顆就是這樣）。
    -- 錨在視窗外側、戰鬥遮罩蓋不到，戰鬥中照樣點得到 —— 面板是自己的非保護框，沒有風險。
    local openPanel = W.CreateButton(panel, L["Open the settlement panel"], "accent-hover", TAB_MIN_W, TAB_H)
    W.FitButton(openPanel, TAB_MIN_W, TAB_H)
    openPanel:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 1)
    openPanel:SetScript("OnClick", function()
        panel:Hide()
        ns.Panel.Show()
    end)

    panel:SetScript("OnHide", function() W.CloseDropdowns() end)

    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)
    panel:SetScript("OnShow", function()
        SetCombatLocked(InCombatLockdown())
    end)
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
    tabId = tabId or "general"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end
