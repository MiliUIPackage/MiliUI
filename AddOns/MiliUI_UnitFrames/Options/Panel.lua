------------------------------------------------------------
-- 主設定視窗：700×520，分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 520

-- 分頁鈕：74 是**下限**不是固定寬。
-- ⚠ 按鈕的 label 只錨 CENTER、`SetWordWrap(false)`，太長不會被裁掉而是**往兩側溢出**
-- （見 Widgets.lua 的 CreateButton 註解）。固定 74 的話德文的 "Beschwörungen"
-- 每邊要溢出 5px，而分頁間距只有 3px ⇒ 直接啃到隔壁分頁的文字。
-- 中日韓的標籤都短，仍然吃 74 的下限，外觀完全不變。
-- 自適應寬度的先例：Options/Tab_Unit.lua 的元件 chip。
local TAB_MIN_W = 74
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20        -- 文字左右各留 10

local panel
local tabButtons = {}
local highlightTab
local closeBtn

-- class = 只有這些職業看得到這個分頁（單一職業字串，或 { CLASS = true } 集合）
local TABS = {
    { id = "general",  label = L["General"] },
    { id = "units",    label = L["Units"] },
    { id = "resource", label = L["Resources"] },
    -- 沒有東西會進圖騰欄位的職業，這頁調什麼都不會有反應 → 直接不顯示
    { id = "totem",    label = L["Summons"], class = ns.TOTEM_CLASSES },
    { id = "share",    label = L["Profile"] },
    { id = "about",    label = L["About"] },
}

local PLAYER_CLASS = ns.playerClass

local function ClassAllowed(class)
    if not class then return true end
    if type(class) == "table" then return class[PLAYER_CLASS] == true end
    return class == PLAYER_CLASS
end

local function VisibleTabs()
    local list = {}
    for _, t in ipairs(TABS) do
        if ClassAllowed(t.class) then list[#list + 1] = t end
    end
    return list
end

------------------------------------------------------------
-- 分頁骨架（各分頁的 Init 本來逐字重複這幾段）
--
-- 拆成兩支是照實情走的：「一般／資源／召喚物」三頁是單純的表單，骨架完全一樣；
-- 而 Tab_Unit（左欄選單位＋上方 chip＋逐元件面板）與 Tab_Share（多個獨立區塊、
-- 沒有單一捲軸）只共用最外層那個蓋滿面板的 frame。硬把五頁塞進同一支會綁死版面。
------------------------------------------------------------
function Options.NewTabFrame()
    local tab = CreateFrame("Frame", nil, Options.panel)
    tab:SetAllPoints(Options.panel)
    tab:Hide()
    return tab
end

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, 660)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 的串接。回傳 content, rows, refreshers
-- （rows 是給設定搜尋捲到指定那一列用的，見 Options/Search.lua）
function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, 4, -4, width)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, rows, refreshers
end

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    ns.db.optionsWindow.x = math.floor(fx - cx + 0.5)
    ns.db.optionsWindow.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.db.optionsWindow
    -- 存到畫面外時拉回中央：不然視窗「其實開著但看不到」，
    -- 下一次點小地圖鈕會變成把它關掉，看起來就像「第一下沒反應」
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local function ShowTab(id)
    -- 下拉選單掛在 UIParent 的 TOOLTIP strata，不是分頁的子框——切分頁時分頁自己
    -- 藏起來，選單還會浮在那裡。切之前先收掉。
    W.CloseDropdowns()
    ns.Fire("ShowOptionsTab", id)
end

------------------------------------------------------------
-- 戰鬥保護
--
-- 後端本來就安全（ns.ApplySettings 戰鬥中排隊、出戰鬥再套），但玩家看到的是
-- 「調了沒反應」——所以直接把設定區蓋起來把原因講明白。
------------------------------------------------------------
local function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    if locked then
        W.CloseDropdowns()      -- 下拉選單在 TOOLTIP strata，遮罩蓋不到，直接收掉
        panel.combatMask:Show()
        -- 關閉鈕要留在遮罩之上，否則視窗只剩 ESC 能關
        closeBtn:SetFrameStrata("FULLSCREEN_DIALOG")
        closeBtn:SetFrameLevel(510)
    else
        panel.combatMask:Hide()
        closeBtn:SetFrameStrata("DIALOG")
        closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    end
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIUF_Options", UIParent, PANEL_W, PANEL_H)
    -- ⚠ CreateFrame 出來預設是「顯示」的。不先關掉的話，第一次點小地圖鈕時
    -- Open() 會看到 IsShown()==true 而判定成「已開著」→ 直接切換成關閉，
    -- 於是第一下永遠沒反應、第二下才開（實測 log 抓到的根因）
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    ApplyPosition()
    Options.panel = panel

    -- 設定面板不走 UIPanel 系統，要自己登記成遮擋來源：預覽孿生錨在真實框的位置上，
    -- 被面板蓋住的那幾個，3D 頭像會穿透過來（見 Elements/Portrait.lua 的說明）
    if ns.WatchOccluder then ns.WatchOccluder(panel) end

    -- ESC 關閉
    tinsert(UISpecialFrames, "MiliUIUF_Options")

    -- 標題列：看得見的拖曳把手（⠿ 拖曳移動）＋ 標題文字，整條都能拖著移動視窗。
    -- 右鍵把視窗叫回畫面中央。實作在共用層 Libs/MiliUIWidgets/Widgets.lua
    W.CreateTitleBar(panel, "|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r  v" .. ns.VERSION, SavePosition)

    -- 關閉鈕（右上角）
    -- 關閉鈕用貼圖不用「×」字元（中文字型可能沒這個字形）
    closeBtn = W.CreateButton(panel, "", "red", 20, 20)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    local closeX = closeBtn:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(12, 12)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- 分頁鈕：上緣外側，一路排開。分頁鈕本身也是拖曳把手（隱藏的便利功能，
    -- 看得見的那個在標題列上），所以標題列與分頁列哪裡抓都能移動視窗
    local prev
    local stripW = 0
    for i, tab in ipairs(VisibleTabs()) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
        b.id = tab.id
        -- 依實際文字寬撐開（下限 TAB_MIN_W）。要在 SetText 之後量，CreateButton 已經設好了
        local fs = b:GetFontString()
        local w = TAB_MIN_W
        if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
        P.Size(b, w, TAB_H)
        stripW = stripW + w + (i > 1 and TAB_GAP or 0)
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

    -- 交給 Search.CreateBox 決定搜尋框放哪。用**累計出來的**寬度而不是回讀幾何：
    -- 這裡每個值都是自己設下去的，沒有必要多一次 GetWidth。
    Options.lastTabButton = prev
    Options.tabRoom = PANEL_W - stripW - 8      -- 8 = 分頁列與搜尋框之間的間距

    panel:SetScript("OnHide", function()
        ns.LogClick("panel OnHide")
        W.CloseDropdowns()
        ns.Preview.Close()
        if ns.TotemsSetPreview then ns.TotemsSetPreview(false) end
    end)
    panel:SetScript("OnShow", function()
        ns.LogClick("panel OnShow")
        ns.Preview.Open()
        SetCombatLocked(InCombatLockdown())   -- 戰鬥中開窗也要鎖
    end)

    -- 搜尋框：跟標題同一列的另一端（標題在左、搜尋在右），不佔面板內部空間。
    -- ⚠ 一定要排在上面兩個 SetScript **之後**：CreateBox 內部用 HookScript 掛
    -- panel 的 OnHide 做關窗清理，先掛後 SetScript 會把它整個蓋掉 ⇒ 帶著搜尋結果
    -- 關窗，下次開窗那串字與結果清單還在。
    if ns.Search then ns.Search.CreateBox(panel) end

    ------------------------------------------------------------
    -- 戰鬥遮罩：事件掛在 panel 自己身上（隱藏的框照樣收得到事件）
    ------------------------------------------------------------
    W.CreateCombatMask(panel)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    ------------------------------------------------------------
    -- 「關於」分頁（簡單，直接放這裡）
    ------------------------------------------------------------
    local aboutTab = CreateFrame("Frame", nil, panel)
    aboutTab:SetAllPoints(panel)
    aboutTab:Hide()

    local aboutText = aboutTab:CreateFontString(nil, "OVERLAY")
    aboutText:SetFontObject(W.fontNormal)
    aboutText:SetPoint("TOPLEFT", 24, -40)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetSpacing(6)
    aboutText:SetText(table.concat({
        "|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r v" .. ns.VERSION,
        "",
        L["Unit frames rebuilt for 12.1, keeping the workflow of Stuf."],
        L["Secret-value safety is built into the architecture: health via HealPredictionCalculator,"],
        L["auras via AuraContainer, cast bars via Duration objects."],
        "",
        L["Commands: |cffffd200/muf|r opens the options, |cffffd200/muf reset|r resets everything"],
        "",
        L["Author: Mili (MiliUI package)"],
        "",
        L["|cffffd200Credits|r"],
        L["My two favourite addons are |cff33CCFFCell|r and |cff4DD2FFStuf Unit Frames|r,"],
        L["and both the look and the design thinking here owe a lot to them."],
        L["Thanks to |cffffffffenderneko|r, the author of Cell,"],
        L["and to |cffffffffKato|r, the author of Stuf."],
        L["Addon structure, options UI style and bar overlays follow Cell;"],
        L["text tag syntax and color methods follow Stuf."],
    }, "\n"))

    ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
        aboutTab:SetShown(id == "about")
    end)
end

function Options.Open(tabId)
    local first = panel == nil
    CreatePanel()
    ns.LogClick("Open(tab=%s) 首次建立=%s 目前IsShown=%s IsVisible=%s 戰鬥=%s",
        tostring(tabId), tostring(first), tostring(panel:IsShown()),
        tostring(panel:IsVisible()), tostring(InCombatLockdown()))
    if panel:IsShown() and not tabId then
        ns.LogClick("Open → 切換成關閉")
        panel:Hide()
        return
    end
    ApplyPosition()      -- 每次開啟都校正位置（存到畫面外會拉回中央）
    panel:Show()
    panel:Raise()        -- 已開但被其他對話框蓋住時拉到最前，免得看起來像沒反應
    ns.LogClick("Open → 顯示 IsShown=%s IsVisible=%s alpha=%.2f pos=(%s,%s) strata=%s",
        tostring(panel:IsShown()), tostring(panel:IsVisible()), panel:GetAlpha() or -1,
        tostring(ns.db.optionsWindow.x), tostring(ns.db.optionsWindow.y),
        tostring(panel:GetFrameStrata()))
    tabId = tabId or "units"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end

-- 入口統一走 Api.lua 的 ns.OpenOptions（委派到這裡的 Options.Open）
