------------------------------------------------------------
-- 主設定視窗：700×520。上緣外側四個分頁鈕（一般／主題／設定檔／關於，跟套組其他插件同款，
-- 也是拖曳把手；打過 /mcdm debug 之後多一個「除錯」，這次登入期間一直在）；「一般」分頁裡是左欄導覽（Options/Sidebar.lua）＋ 右側一頁一頁，
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
    { id = "debug",   label = L["Debug"], hidden = true },   -- /mcdm debug 之後才出現
}
-- 佔滿整個視窗的頁（不是「一般」分頁裡的）
local FULL_PAGES = { theme = true, profile = true, about = true, debug = true }
Options.FULL_PAGES = FULL_PAGES

local panel, closeBtn, content, fullContent
local tabButtons, highlightTab = {}, nil
local pages, pageDefs = {}, {}
local currentPage, currentTab
local debugTabOn = false
local gridToggle

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
-- 自訂格子（pips）的設定在資源條頁；下一招圖示（assistIcon）在戰鬥輔助頁（Options/Tab_Assist.lua）
local SUBPANELS = {
    pips       = { host = "resources", title = L["Custom segments"] },
    assistIcon = { host = "assist",    title = L["Next cast icon"] },
}

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
    -- 「＋」挑選器與逐法術設定都綁著開它的那一條，換頁就跟著收（不然加進去的是上一條）
    if ns.Picker and ns.Picker.IsShown() then ns.Picker.Close() end
    if ns.SpellPopover and ns.SpellPopover.IsShown() then ns.SpellPopover.Close() end
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

-- 設定視窗的格線此刻畫在畫面上 ⇒ 間距（UIParent 單位，原點畫面中心）；否則 nil
function Options.GridSpacing()
    return gridToggle and gridToggle:Active() or nil
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
    else
        panel.combatMask:Hide()
    end
end

-- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
--
-- ⚠ 關閉鈕**不能單獨設 strata**。子框一旦 SetFrameStrata 過，面板之後被抬層級時它就不跟著走：
--   面板 Raise（Open 裡）、拖曳的 StartMoving（會自動 Raise）都會把面板抬上去，關閉鈕留在原地
--   ⇒ 掉到面板背景後面，看起來暗掉、點不到。原本為了戰鬥中壓過遮罩而在 DIALOG／
--   FULLSCREEN_DIALOG 之間切換，每次開窗都把它設成「自訂 strata」，這個 bug 修了又回來。
--   現在一般狀態的關閉鈕只設相對層級；戰鬥中用的是**建在遮罩裡的另一顆**，跟著遮罩的 strata。
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

    W.CloseOnEscape(panel)      -- ESC 關閉；開天賦／法術書不關（要從那裡 Shift 點法術填 ID）

    -- 看得見的拖曳把手 ＋ 標題；右鍵叫回畫面中央（共用層）
    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r  v" .. ns.VERSION,
        SavePosition)

    -- +200：頁面裡有比 +10 高的子框（表單遮罩 +40 起跳），關閉鈕要壓得過它們。
    -- 相對層級在面板被抬高時會跟著平移，所以只要設這一次。
    closeBtn = CreateCloseButton(panel, panel:GetFrameLevel() + 200)

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
        if tab.hidden then b:SetShown(debugTabOn) end
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

    -- 右上角「格線: ON／OFF」（共用層）：開著設定視窗就能拖條，給一張對齊用的格線，
    -- 拖曳吸附也吸它（EditMode.lua 的 ActiveGridSpacing）。
    -- ⚠ 要排在上面兩行 SetScript 之後：共用層走 HookScript
    gridToggle = W.CreateGridToggle(panel, { db = WindowDB })

    -- 戰鬥遮罩：事件掛在 panel 自己身上（隱藏的框照樣收得到事件）
    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
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

-- 除錯：/mcdm debug 的全文＋完整診斷記錄，玩家全選複製貼給作者（比找存檔直覺）。
-- 內容是程式產生的：一被輸入就還原（跟 W.CreateCopyBox 同一招），但要捲得動所以不用 CopyBox
Options.RegisterPage("debug", L["Debug"], function(parent, title)
    local page, y = Options.NewPage(parent, title)
    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", PAGE_PAD + 4, y - 4)
    note:SetWidth(PAGE_W_FULL - 8)
    note:SetJustifyH("LEFT")
    note:SetText(L["Click Select all, press Ctrl+C to copy, then paste it to the author."])
    local noteH = math.max(14, math.ceil(note:GetStringHeight()))

    local BTN_ROW = 22 + 12
    local boxTop = y - 4 - noteH - 8
    local box = W.CreateScrollEditBox(page, PAGE_W_FULL, PANEL_H + boxTop - PAGE_PAD - BTN_ROW)
    box:SetPoint("TOPLEFT", PAGE_PAD, boxTop)
    local eb = box.editBox
    eb:SetFontObject(W.fontSmall)
    local text = ""
    local function Fill()
        eb:SetText(text)
        eb:SetCursorPosition(0)
    end
    eb:SetScript("OnTextChanged", function(_, userInput)
        if userInput then Fill() end
    end)

    local selectBtn = W.CreateButton(page, L["Select all"], "primary", 100, 22)
    W.FitButton(selectBtn, 100, 22)
    selectBtn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
    selectBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)
    local regenBtn = W.CreateButton(page, L["Refresh"], "normal", 100, 22)
    W.FitButton(regenBtn, 100, 22)
    regenBtn:SetPoint("LEFT", selectBtn, "RIGHT", 6, 0)

    function page:OnShowPage()
        local ok, t = xpcall(ns.DebugText, ns.ReportError)
        text = ok and t or ""
        Fill()
    end
    regenBtn:SetScript("OnClick", function() page:OnShowPage() end)
    return page
end)

-- /mcdm debug：分頁鈕現身（這次登入期間一直在）並切過去
function Options.ShowDebugTab()
    debugTabOn = true
    for _, b in ipairs(tabButtons) do
        if b.id == "debug" then b:Show() end
    end
    Options.Open("debug")
end

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
    panel:Raise()        -- 已開但被別的對話框蓋住時拉到最前（關閉鈕跟著抬，見 CreateCloseButton）
    local w = WindowDB()
    local last = w and w.lastBar
    -- 上次停在除錯分頁、但這次登入還沒打過 /mcdm debug（分頁鈕藏著）⇒ 回第一頁
    if last == "debug" and not debugTabOn then last = nil end
    Options.ShowPage(pageId or last or "essential")
end

-- 從編輯模式點一下藍框、畫面上的點擊層直接跳到某條的頁面（自訂群組也要開得到）
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
    if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
    -- 暴雪增益 item 的層數增加音效（AddAuraSound）不經過放格：設定變了自己對一次帳（光環格放格時本來就會叫）
    if ns.Sound and ns.Sound.RequestAuraSync then ns.Sound.RequestAuraSync() end
    -- 施放後提醒：有格子設了才聽施法事件；設定拿掉的那格取消排程
    if ns.Sound and ns.Sound.SyncCast then ns.Sound.SyncCast() end
end

function Options.ApplyEngine(level, now)
    level = level or "layout"
    -- 設定剛寫進去（群組、以增益取代、條的來源…）：RequestSource 的目標快取當場作廢，
    -- 不等下面 0.2 秒合併後的 RequestAll（Core/Bars.lua 的 RequestSource 註解）
    if ns.Bars and ns.Bars.InvalidateSources then ns.Bars.InvalidateSources() end
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
