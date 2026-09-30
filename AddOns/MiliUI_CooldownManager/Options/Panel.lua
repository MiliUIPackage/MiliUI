------------------------------------------------------------
-- 主設定視窗：700×520。上緣外側四個分頁鈕（一般／主題／設定檔／關於，跟套組其他插件同款，
-- 也是拖曳把手）；「一般」分頁裡是左欄導覽（Options/Sidebar.lua）＋ 右側一頁一頁，
-- 其餘三頁佔滿整個視窗。
--
-- 頁面是懶建的：Options.RegisterPage(id, title, build) 只登記，第一次切過去才建。
-- title 可以是函式（自訂群組改名之後標題跟著變）。
-- 建好的頁面留在快取裡，**不丟**（frame 刪不掉，丟了再建就是洩漏）：自訂群組刪掉
-- 只是取消登記、把頁面藏起來，之後同一個 key 再出現就拿回來用。
-- 頁面每次被切到都會叫 page:OnShowPage()（有的話），各頁在那裡照目前的設定檔重讀。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 520
local SIDEBAR_W = 150
Options.PANEL_W, Options.PANEL_H, Options.SIDEBAR_W = PANEL_W, PANEL_H, SIDEBAR_W

-- 頁面內容區的寬（標題與表單用）。右上角留 28 給關閉鈕，標題線才不會從鈕底下穿過去
local PAGE_PAD = 16
local PAGE_W = PANEL_W - SIDEBAR_W - PAGE_PAD * 2 - 12
local PAGE_W_FULL = PANEL_W - PAGE_PAD * 2 - 12          -- 沒有左欄的頁（主題／設定檔／關於）
Options.PAGE_PAD, Options.PAGE_W, Options.PAGE_W_FULL = PAGE_PAD, PAGE_W, PAGE_W_FULL

-- 分頁鈕（上緣外側）。74 是下限不是固定寬：標籤只錨 CENTER、不裁字，太長會往兩側溢出
-- 啃到隔壁，所以照實際文字寬撐開（單位框架同一套）。
local TAB_MIN_W, TAB_H, TAB_GAP, TAB_PAD = 74, 22, 3, 20
local TABS = {
    { id = "general", label = L["General"] },
    { id = "theme",   label = L["Theme"] },
    { id = "profile", label = L["Profiles"] },
    { id = "about",   label = L["About"] },
}
-- 佔滿整個視窗的頁（不是「一般」分頁裡的）
local FULL_PAGES = { theme = true, profile = true, about = true }
Options.FULL_PAGES = FULL_PAGES

local panel, closeBtn, content, fullContent
local tabButtons, highlightTab = {}, nil
local pages, pageDefs = {}, {}
local currentPage, currentTab

------------------------------------------------------------
-- 頁面登記
------------------------------------------------------------
function Options.RegisterPage(id, title, build)
    pageDefs[id] = { title = title, build = build }
end

function Options.UnregisterPage(id)
    pageDefs[id] = nil
    local page = pages[id]
    if page then page:Hide() end
end

function Options.HasPage(id)
    return pageDefs[id] ~= nil
end

-- 沒有自己一頁的面板：設定在哪一頁、給玩家看的名字（編輯模式覆蓋層、點擊層、錨定候選用）。
-- 自訂格子（pips）的設定在資源條頁
local SUBPANELS = { pips = { host = "resources", title = L["Custom segments"] } }

-- 這個 id 的設定在哪一頁（一般的條／頁就是自己）
function Options.HostPage(id)
    local sp = SUBPANELS[id]
    return sp and sp.host or id
end

function Options.PageTitle(id)
    local def = pageDefs[id]
    if not def then
        local sp = SUBPANELS[id]
        return sp and sp.title or nil
    end
    if type(def.title) == "function" then return def.title(id) end
    return def.title
end

-- 已經建好的頁面（沒建過回 nil）
function Options.GetPage(id)
    return pages[id]
end

-- 頁首：標題（accent 線）。回傳 page 與標題下緣的 y，頁面內容從那裡往下排。
-- 之後的表單頁在標題底下接 W.CreateScrollFrame ＋ ns.Controls.Build。
function Options.NewPage(parent, title)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    local head = W.CreateSectionTitle(page, title, parent == fullContent and PAGE_W_FULL or PAGE_W)
    head:SetPoint("TOPLEFT", PAGE_PAD, -14)
    page.head = head
    return page, -44
end

-- 這一階段所有頁面共用的殼：標題 ＋ 一行灰字
local function PlaceholderBuild(parent, title)
    local page, y = Options.NewPage(parent, title)
    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("TOPLEFT", PAGE_PAD + 4, y - 4)
    note:SetWidth(PAGE_W - 8)
    note:SetJustifyH("LEFT")
    note:SetText(L["Not implemented yet."])
    return page
end
Options.PlaceholderBuild = PlaceholderBuild

------------------------------------------------------------
-- 位置（存帳號層，換設定檔視窗不跳）
------------------------------------------------------------
local function WindowDB()
    return ns.sv and ns.sv.optionsWindow
end

local function SavePosition()
    local w = WindowDB()
    if not w then return end
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    w.x = math.floor(fx - cx + 0.5)
    w.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = WindowDB()
    if not w then return end
    -- 存到畫面外時拉回中央：不然視窗「其實開著但看不到」，下一次開窗會變成關掉它
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

------------------------------------------------------------
-- 切頁
------------------------------------------------------------
-- 分頁：一般（左欄＋右側頁）／主題／設定檔／關於（佔滿）。切分頁只是換「哪一區顯示」
local function SetTab(id)
    local full = id ~= "general"
    if ns.Sidebar and ns.Sidebar.SetShown then ns.Sidebar.SetShown(not full) end
    if content then content:SetShown(not full) end
    if fullContent then fullContent:SetShown(full) end
    currentTab = id
    for _, b in ipairs(tabButtons) do
        if b.id == id and highlightTab then highlightTab(b) end
    end
end

function Options.ShowTab(id)
    if id == "general" then
        local w = WindowDB()
        local last = w and w.lastBar
        Options.ShowPage((last and not FULL_PAGES[last] and pageDefs[last]) and last or "essential")
    else
        Options.ShowPage(id)
    end
end

function Options.ShowPage(id)
    local asked = id
    id = Options.HostPage(id)
    if not pageDefs[id] then id = "essential" end
    -- 下拉選單掛在 UIParent 的 TOOLTIP strata，不是頁面的子框 —— 切頁前先收
    W.CloseDropdowns()
    local full = FULL_PAGES[id] and true or false
    local page = pages[id]
    if not page then
        local ok, built = xpcall(pageDefs[id].build, ns.ReportError, full and fullContent or content,
            Options.PageTitle(id), id)
        if not ok or not built then return end
        page = built
        pages[id] = page
    end
    for pid, p in pairs(pages) do
        if pid ~= id then p:Hide() end
    end
    SetTab(full and id or "general")
    page:Show()
    currentPage = id
    -- 沒有自己一頁的面板（自訂格子）：宿主頁切到它那個分頁
    if asked ~= id and page.SetSub then
        xpcall(page.SetSub, ns.ReportError, page, asked)
    elseif page.OnShowPage then
        xpcall(page.OnShowPage, ns.ReportError, page)
    end
    local w = WindowDB()
    if w then w.lastBar = id end
    if not full and ns.Sidebar and ns.Sidebar.Highlight then ns.Sidebar.Highlight(id) end
end

function Options.CurrentTab()
    return currentTab
end

function Options.CurrentPage()
    return currentPage
end

------------------------------------------------------------
-- 戰鬥保護：設定區整片蓋起來並講明原因（後端戰鬥中本來就會排隊，
-- 但玩家看到的是「調了沒反應」）
------------------------------------------------------------
local function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    if locked then
        W.CloseDropdowns()
        panel.combatMask:Show()
        -- 關閉鈕留在遮罩之上，否則視窗只剩 ESC 能關
        closeBtn:SetFrameStrata("FULLSCREEN_DIALOG")
        closeBtn:SetFrameLevel(510)
    else
        panel.combatMask:Hide()
        closeBtn:SetFrameStrata("DIALOG")
        -- +200：頁面裡有比 +10 高的子框（表單遮罩 +40 起跳），關閉鈕要壓得過它們
        closeBtn:SetFrameLevel(panel:GetFrameLevel() + 200)
    end
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUICDM_Options", UIParent, PANEL_W, PANEL_H)
    -- ⚠ 建出來預設是顯示的。不先關掉，第一次 Open 會看到 IsShown()==true 而把它關掉
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUICDM_Options")      -- ESC 關閉

    -- 看得見的拖曳把手 ＋ 標題；右鍵叫回畫面中央（共用層）
    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r  v" .. ns.VERSION,
        SavePosition)

    -- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
    closeBtn = W.CreateButton(panel, "", "red", 20, 20)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 200)
    local closeX = closeBtn:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(12, 12)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- 分頁鈕：上緣外側一路排開，本身也是拖曳把手（看得見的那個在標題列上），
    -- 所以標題列與分頁列哪裡抓都能移動視窗
    local prev
    for i, tab in ipairs(TABS) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
        b.id = tab.id
        local fs = b:GetFontString()
        local w = TAB_MIN_W
        if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
        ns.P.Size(b, w, TAB_H)
        if prev then
            b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
        else
            b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
        end
        W.MakeDragHandle(b, panel, SavePosition)
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, Options.ShowTab)

    -- 「一般」分頁：左欄 ＋ 右側頁面區
    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", SIDEBAR_W + 1, 0)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    ns.Sidebar.Build(panel, SIDEBAR_W)

    -- 主題／設定檔／關於：佔滿整個視窗
    fullContent = CreateFrame("Frame", nil, panel)
    fullContent:SetAllPoints(panel)
    fullContent:Hide()

    panel:SetScript("OnShow", function()
        SetCombatLocked(InCombatLockdown())      -- 戰鬥中開窗也要鎖
        ns.Sidebar.Relayout()                    -- 顯示之後才量得到字高（換行的語系）
        ns.Fire("OptionsShown")
    end)
    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
        if W.Menu and W.Menu.Hide then W.Menu.Hide() end
        ns.Fire("OptionsHidden")
    end)

    -- 戰鬥遮罩：事件掛在 panel 自己身上（隱藏的框照樣收得到事件）
    W.CreateCombatMask(panel)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)
end

------------------------------------------------------------
-- 頁面清單（左欄的順序在 Sidebar.lua；這裡只管每一頁長什麼樣）
------------------------------------------------------------
local PLACEHOLDER_PAGES = {
    { "essential", L["Essential Cooldowns"] },
    { "utility",   L["Utility Cooldowns"] },
    { "buffs",     L["Tracked Buffs"] },
    { "buffbars",  L["Tracked Bars"] },
    { "resources", L["Resource Bars"] },
    { "castbar",   L["Cast Bar"] },
    { "theme",     L["Theme"] },
    { "profile",   L["Profiles"] },
}
for _, def in ipairs(PLACEHOLDER_PAGES) do
    Options.RegisterPage(def[1], def[2], PlaceholderBuild)
end

-- 關於：版本與指令
Options.RegisterPage("about", L["About"], function(parent, title)
    local page, y = Options.NewPage(parent, title)

    local text = page:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(W.fontNormal)
    text:SetPoint("TOPLEFT", PAGE_PAD + 4, y - 10)
    text:SetWidth(PAGE_W_FULL - 8)
    text:SetJustifyH("LEFT")
    text:SetSpacing(6)
    text:SetText(table.concat({
        ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r  v" .. ns.VERSION,
        "",
        L["Rearranges and restyles Blizzard's Cooldown Manager."],
        "",
        L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."],
        "",
        L["Author: Mili (MiliUI package)"],
    }, "\n"))
    return page
end)

------------------------------------------------------------
-- 開關
------------------------------------------------------------
-- pageId 省略 ＝ 開關切換（開著就關），開的時候回到上次那一頁
function Options.Open(pageId)
    if not ns.ready then return end
    CreatePanel()
    if panel:IsShown() and not pageId then
        panel:Hide()
        return
    end
    Options.SyncBarPages()
    ApplyPosition()
    panel:Show()
    panel:Raise()        -- 已開但被別的對話框蓋住時拉到最前
    -- ⚠ Raise 會把面板的層級往上抬（同一層有別的視窗時，例如暴雪冷卻管理器面板），但關閉鈕
    --   被單獨設過 strata、不會跟著抬 ⇒ 掉到面板背景後面：看起來暗掉、點不到。
    --   OnShow 設的那次在 Raise 之前，所以 Raise 之後要再對一次。
    SetCombatLocked(InCombatLockdown())
    local w = WindowDB()
    Options.ShowPage(pageId or (w and w.lastBar) or "essential")
end

-- 從編輯模式的齒輪、畫面上的點擊層直接跳到某條的頁面（自訂群組也要開得到）
function Options.FocusBar(key)
    Options.SyncBarPages()
    key = Options.HostPage(key)
    if not pageDefs[key] then key = "essential" end
    Options.Open(key)
end

------------------------------------------------------------
-- 自訂群組的頁面登記：跟著目前設定檔的 bars 走
------------------------------------------------------------
local function BarTitle(key)
    local bar = ns.DB.BarTable(key)
    local name = bar and bar.name
    if type(name) == "string" and name ~= "" then return name end
    return key
end
Options.BarTitle = BarTitle

function Options.SyncBarPages()
    local p = ns.profile
    local bars = p and p.bars or {}
    for id in pairs(pageDefs) do
        if not ns.DB.IsBuiltinBar(id) and pageDefs[id].customBar and not bars[id] then
            Options.UnregisterPage(id)
        end
    end
    for key in pairs(bars) do
        if not ns.DB.IsBuiltinBar(key) and not pageDefs[key] and ns.TabBar then
            Options.RegisterPage(key, BarTitle, ns.TabBar.Build)
            pageDefs[key].customBar = true
        end
    end
end

------------------------------------------------------------
-- 真實條的套用：設定頁改了值之後 0.2 秒合併一次（滑桿拖動中只重畫預覽）
------------------------------------------------------------
local engineLevel, engineArmed
local LEVEL_RANK = { membership = 1, layout = 2, structure = 3 }

local function FlushEngine()
    engineArmed = false
    local level = engineLevel or "layout"
    engineLevel = nil
    if ns.Decorate then ns.Decorate.InvalidateAll() end
    if ns.Bars then ns.Bars.RequestAll(level) end
    if ns.Visibility then ns.Visibility.ApplyAll() end
    if ns.EditMode and ns.EditMode.active and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
end

function Options.ApplyEngine(level, now)
    level = level or "layout"
    if not engineLevel or (LEVEL_RANK[level] or 0) > (LEVEL_RANK[engineLevel] or 0) then
        engineLevel = level
    end
    if now then FlushEngine() return end
    if engineArmed then return end
    engineArmed = true
    C_Timer.After(0.2, FlushEngine)
end

-- 設定檔換了：自訂群組重新登記、左欄重建、目前這頁照新的設定檔重讀
ns.RegisterCallback("ProfileChanged", "options", function()
    Options.SyncBarPages()
    if ns.Sidebar and ns.Sidebar.Rebuild then ns.Sidebar.Rebuild() end
    if panel and panel:IsShown() then
        Options.ShowPage(pageDefs[currentPage] and currentPage or "essential")
    end
end)
ns.RegisterCallback("SpecChanged", "options", function()
    if panel and panel:IsShown() and currentPage then Options.ShowPage(currentPage) end
end)

function Options.Close()
    if panel then panel:Hide() end
end
