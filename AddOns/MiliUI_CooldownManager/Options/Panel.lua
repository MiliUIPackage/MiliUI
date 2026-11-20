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
--
-- 收合（畫面編輯，Options/LiveEdit.lua；2026-11-21）：分頁列右側、格線開關左邊一顆「畫面編輯」，
-- 按了視窗收成一條（COMPACT_W 寬、高照說明字數）：標題列照舊在外側，裡面一行灰字＋一顆 primary「展開設定」；
-- 分頁鈕、左欄、頁面區收起來。**視窗本身不 Hide**（逐法術小窗、挑選器、彈窗都是它的子框，聽 OptionsHidden 就收）。
--   * 收合與展開都以當下的左上角為準（標題列、分頁列在框外上方，左上角不動它們就不跳）。
--   * 收合期間位置不存（position 回 nil）：存的是中心點，收合後的中心不是展開視窗的中心；展開後再存一次。
--   * 夾在螢幕內的範圍上下各多留 COMPACT_CLAMP：確認／輸入彈窗是對視窗置中的（共用層），視窗只剩一條時
--     比它高的彈窗會從上下凸出去，貼在螢幕邊上就被切掉。
--   * Options.ShowPage 被外部叫到（點擊層、條名籤、Options.Open(pageId)）而視窗是收合的 ⇒ 先展開。
--     換專精／換設定檔時的重讀不展開，等展開時 ShowPage 一起重讀。
--   * 關視窗（含 ESC）先展開再廣播 OptionsHidden ⇒ 每次開都是展開的（狀態只存執行期）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

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

-- 分頁鈕（上緣外側，骨架在共用層 Libs/MiliUIWidgets/Window.lua）。74 是下限不是固定寬
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

local panel, content, fullContent
local win       -- 設定視窗骨架（W.CreateOptionsWindow），在下面「位置」之後建
local pages, pageDefs = {}, {}
local currentPage, currentTab
local debugTabOn = false
local gridToggle
local compact = false           -- 收合中（畫面編輯）
local compactRow, liveBtn, savedInsets
local COMPACT_W, COMPACT_MIN_H, COMPACT_CLAMP = 420, 56, 110

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
    custombars = { host = "resources", title = L["Custom bars"] },
    procdeck   = { host = "resources", title = L["Proc decks"] },
    assistIcon = { host = "assist",    title = L["Next cast icon"] },
}

-- 這個 id 的設定在哪一頁（一般的條／頁就是自己）。獨立擺放的資源列（"res:<key>"）在資源條頁
function Options.HostPage(id)
    local sp = SUBPANELS[id]
    if sp then return sp.host end
    if ns.DB.DetachedResource(id) then return "resources" end
    return id
end

function Options.PageTitle(id)
    local def = pageDefs[id]
    if not def then
        local sp = SUBPANELS[id]
        if sp then return sp.title end
        -- 獨立擺放的資源列：資源名稱（錨定視窗標題、編輯模式覆蓋層的名字都走這裡）
        local rk = ns.DB.DetachedResource(id)
        if rk and ns.Resources and ns.Resources.Name then return ns.Resources.Name(rk) end
        return nil
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
-- 存／套位置在骨架裡（回 nil ＝ 還沒有存檔，不存不套）
local function WindowDB()
    return ns.sv and ns.sv.optionsWindow
end

------------------------------------------------------------
-- 視窗骨架（共用層 Libs/MiliUIWidgets/Window.lua）：面板、標題列、關閉鈕、分頁鈕列、
-- 戰鬥遮罩都在那裡。這裡只寫這支插件不一樣的地方；開關（Options.Open）自己組，
-- 因為切的是「頁」不是分頁（高亮由 ShowPage → SetTab 補）
------------------------------------------------------------
win = W.CreateOptionsWindow({
    name     = "MiliUICDM_Options",
    width    = PANEL_W, height = PANEL_H,
    title    = function() return ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r  v" .. ns.VERSION end,
    -- 收合中不存不套（見檔頭「收合」）
    position = function()
        if compact then return nil end
        return WindowDB()
    end,
    escape   = "panels",    -- ESC 關閉；開天賦／法術書不關（要從那裡 Shift 點法術填 ID）
    tabMinW  = 74,
    tabs     = TABS,
    onSelectTab = function(id) Options.ShowTab(id) end,
    onShow = function()
        ns.Sidebar.Relayout()                    -- 顯示之後才量得到字高（換行的語系）
        ns.Fire("OptionsShown")
    end,
    onHide = function()
        if W.Menu and W.Menu.Hide then W.Menu.Hide() end
        -- 收合著被關（關閉鈕、ESC）：先展開，下次開才是完整的視窗；位置照展開後的存
        if compact then Options.SetCompact(false, true) end
        ns.Fire("OptionsHidden")
    end,
    onBuilt = function(_, p)
        panel = p
        Options.panel = p

        -- 「一般」分頁：左欄 ＋ 右側頁面區
        content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", SIDEBAR_W + 1, 0)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
        ns.Sidebar.Build(panel, SIDEBAR_W)

        -- 主題／設定檔／關於：佔滿整個視窗
        fullContent = CreateFrame("Frame", nil, panel)
        fullContent:SetAllPoints(panel)
        fullContent:Hide()

        -- 右上角「格線: ON／OFF」（共用層）：開著設定視窗就能拖條，給一張對齊用的格線，
        -- 拖曳吸附也吸它（EditMode.lua 的 ActiveGridSpacing）。
        -- 骨架的 SetScript 已經排在前面，共用層走 HookScript 不會被蓋掉
        gridToggle = W.CreateGridToggle(panel, { db = WindowDB })

        -- 「畫面編輯」：格線開關左邊（同一排、上緣外側）。不是主動作，用 normal
        liveBtn = W.CreateButton(panel, L["Edit on screen"], "normal", 80, 22)
        W.FitButton(liveBtn, 80, 22)
        liveBtn:SetPoint("BOTTOMRIGHT", gridToggle.button, "BOTTOMLEFT", -3, 0)
        liveBtn:SetScript("OnEnter", function(self)
            W.PaintButton(self, true)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Edit on screen"])
            GameTooltip:AddLine(L["Collapses this window and shows every icon of each bar right where the bar is on screen, including ones not showing right now. Edit them there."], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        liveBtn:SetScript("OnLeave", function(self)
            W.PaintButton(self, false)
            GameTooltip:Hide()
        end)
        liveBtn:SetScript("OnClick", function()
            GameTooltip:Hide()
            Options.SetCompact(true)
        end)

        -- 收合時的那一條：一行灰字＋「展開設定」（右邊讓出關閉鈕）
        compactRow = CreateFrame("Frame", nil, panel)
        compactRow:SetAllPoints(panel)
        compactRow:Hide()
        local expand = W.CreateButton(compactRow, L["Expand settings"], "primary", 90, 22)
        local expandW = W.FitButton(expand, 90, 22)
        expand:SetPoint("RIGHT", compactRow, "RIGHT", -30, 0)
        expand:SetScript("OnClick", function() Options.SetCompact(false) end)
        local note = compactRow:CreateFontString(nil, "OVERLAY")
        note:SetFontObject(W.fontSmall)
        note:SetTextColor(0.65, 0.65, 0.65)
        note:SetJustifyH("LEFT")
        note:SetJustifyV("MIDDLE")
        note:SetWordWrap(true)
        -- 寬度寫死（不靠兩個錨點撐）：收合當下就要量換行後的高，錨點撐出來的寬那一刻還沒解析
        note:SetPoint("LEFT", compactRow, "LEFT", 12, 0)
        note:SetWidth(COMPACT_W - 12 - 10 - 30 - expandW)
        note:SetText(L["Click an icon to set it up, drag icons to reorder, drag a bar's name to move the bar."])
        compactRow.note = note
    end,
})

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
    win.Highlight(id)
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
    -- 收合著（畫面編輯）被叫到切頁：先展開（不在這裡重叫 ShowPage，下面就是）
    if compact then Options.SetCompact(false, true) end
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
        "",
        "|cffffd200" .. L["Credits"] .. "|r",
        L["This addon's design owes much to Ayije's Ayije_CDM, and the look of the Skyriding panel is modeled on Yuyuli's Skyriding Falcon. Sincere thanks to both authors."],
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
    win.SetTabShown("debug", true)
    Options.Open("debug")
end

------------------------------------------------------------
-- 開關
------------------------------------------------------------
-- pageId 省略 ＝ 開關切換（開著就關），開的時候回到上次那一頁
function Options.Open(pageId)
    if not ns.ready then return end
    win.Build()
    -- 收合著、要開某一頁：先展開（Present 才會照存檔套位置）
    if compact and pageId then Options.SetCompact(false, true) end
    if panel:IsShown() and not pageId then
        panel:Hide()
        return
    end
    Options.SyncBarPages()
    win.Present()        -- 套位置、Show、Raise（已開但被別的對話框蓋住時拉到最前）
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
    -- 收合中不切頁（切頁會展開）：展開時 ShowPage 會照新的設定檔重讀
    if panel and panel:IsShown() and not compact then
        Options.ShowPage(pageDefs[currentPage] and currentPage or "essential")
    end
end)
ns.RegisterCallback("SpecChanged", "options", function()
    if panel and panel:IsShown() and currentPage and not compact then Options.ShowPage(currentPage) end
end)

function Options.Close()
    if panel then panel:Hide() end
end

------------------------------------------------------------
-- 收合（畫面編輯）
------------------------------------------------------------
function Options.IsCompact()
    return compact
end

-- 收合列的高：說明字換行後的高度＋上下內距，至少 COMPACT_MIN_H（字型要在顯示中才量得準）
local function CompactHeight()
    local note = compactRow and compactRow.note
    local h = note and note:GetStringHeight() or 0
    if type(h) ~= "number" then h = 0 end
    return math.max(COMPACT_MIN_H, math.ceil(h) + 24)
end

-- 以 (l, t) 為左上角重新貼（UIParent 座標）；夾在螢幕內交給 SetClampedToScreen
local function PlaceTopLeft(l, t)
    if not (l and t) then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
end

-- on：收合／展開。noReshow：展開後不重叫 ShowPage（呼叫端自己會叫，例如 ShowPage 本身、關視窗）
function Options.SetCompact(on, noReshow)
    on = on and true or false
    if not panel or on == compact then return end
    local l, t = panel:GetLeft(), panel:GetTop()
    if on then
        -- 綁著頁面預覽格的東西先收（錨點要藏起來了）；錨定視窗貼著視窗右緣，留著
        W.CloseDropdowns()
        if W.Menu and W.Menu.Hide then W.Menu.Hide() end
        if ns.Picker and ns.Picker.IsShown() then ns.Picker.Close() end
        if ns.SpellPopover and ns.SpellPopover.IsShown() then ns.SpellPopover.Close() end
        compact = true
        if ns.Sidebar and ns.Sidebar.SetShown then ns.Sidebar.SetShown(false) end
        if content then content:Hide() end
        if fullContent then fullContent:Hide() end
        for _, b in ipairs(win.tabButtons) do b:Hide() end
        if liveBtn then liveBtn:Hide() end
        compactRow:Show()
        savedInsets = { panel:GetClampRectInsets() }
        local il, ir, it, ib = unpack(savedInsets)
        panel:SetClampRectInsets(il or 0, ir or 0, math.max(it or 0, COMPACT_CLAMP), math.min(ib or 0, -COMPACT_CLAMP))
        P.Size(panel, COMPACT_W, CompactHeight())
        PlaceTopLeft(l, t)
    else
        compact = false
        compactRow:Hide()
        for _, b in ipairs(win.tabButtons) do b:SetShown(b.id ~= "debug" or debugTabOn) end
        if liveBtn then liveBtn:Show() end
        if savedInsets then panel:SetClampRectInsets(unpack(savedInsets)) end
        P.Size(panel, PANEL_W, PANEL_H)
        PlaceTopLeft(l, t)
        SetTab(currentTab or "general")
        win.SavePosition()
    end
    ns.Fire("OptionsCompactChanged", compact)
    if not on and not noReshow and panel:IsShown() then
        Options.ShowPage(pageDefs[currentPage] and currentPage or "essential")
    end
end
