------------------------------------------------------------
-- 快速設定面板：ESC 選單「米利UI設定」按鈕左鍵開的那一扇
--
-- 左：分組標籤（第一顆「全部」），右：三欄卡片（縮圖在上、標題＋兩行簡介在下），
-- 點卡片直接開那支插件的設定。取代原本「滑過按鈕往上展開一整排插件名」的選單。
--
-- 資料全部是被動的，這裡沒有任何清單要維護：
--   · 收錄＝名冊（Options/Roster.lua）裡「有設定入口、已安裝、啟用中」的條目
--   · 分組＝各插件 TOC 的 Category（-語系），跟插件總覽同一支函式
--   · 縮圖＝Media\Shots\<key>.png，沒有就露出底下的佔位層（插件圖示放大）
--   · 標題／簡介＝TOC 的 Title／Notes（名冊的 desc 優先）
-- 開設定的路由也是插件總覽那一套（ns.AddonInfo.OpenSettings）。
--
-- 啟用／停用插件不在這裡做——那是插件總覽的事（按鈕右鍵，或面板右上角那顆）。
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P
local Info = ns.AddonInfo

local PANEL_W, PANEL_H = 780, 620
local TOP_Y      = -44          -- 標籤欄與卡片區的上緣（上面那一列是說明字＋「插件總覽」鈕）
local TAB_X      = 16
local TAB_W      = 146          -- 標籤欄（含捲軸讓出的 20，列實際寬 126）
local TAB_H      = 26
local GRID_X     = TAB_X + TAB_W
local COLS       = 3
local CARD_W     = 190
local GAP        = 8
local SHOT_H     = CARD_W / 2   -- 擷圖 2:1（檔案 840x420）
local TEXT_PAD   = 8
local DESC_LINES = 2
local CARD_H     = SHOT_H + 6 + 16 + 4 + 28 + 8
local SHOTS_PATH = "Interface\\AddOns\\MiliUI\\Media\\Shots\\"
local ALL        = "\001all"    -- 「全部」標籤的鍵；不會跟任何 TOC 分類撞名

local CARD_BG, CARD_BG_HOVER = { 0.115, 0.115, 0.115, 1 }, { 0.17, 0.17, 0.17, 1 }

local panel, tabList, grid
local cards = {}
local groups = {}               -- { { key =, label =, entries = {} }, ... }，第一筆是「全部」
local selected = ALL

------------------------------------------------------------
-- 文字整理
------------------------------------------------------------
-- 卡片上的標題：剝掉色碼、開頭的「[標籤]」與「米利的／MiliUI」前綴。
-- 標籤那一段就是分組，左邊已經有了；前綴在這扇叫「米利UI設定」的視窗裡是雜訊。
local function CardTitle(entry)
    local s = Info.StripCodes(Info.EntryTitle(entry))
    s = s:gsub("^%s*%[.-%]%s*", "")
    s = s:gsub("^MiliUI[%s_]*", ""):gsub("^米利UI%s*", ""):gsub("^米利的", "")
    if s == "" then s = entry.folders[1] end
    return s
end

-- 卡片上的簡介：壓成一段純文字再交給 SetMaxLines 截斷。
-- ⚠ 一定要先把跳脫序列全部拿掉：截斷點落在 |c／|n 中間，漏出來的半截會被當字面印出來
--   （插件總覽的詳情區為此乾脆不截斷；這裡只有兩行的位置，只能截）。
local function CardDesc(entry)
    local s = entry.desc or Info.EntryMeta(entry, "Notes") or ""
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    s = Info.StripCodes(s)
    s = s:gsub("|n", " "):gsub("\n", " "):gsub("|", "")
    s = s:gsub("%s+", " "):gsub("^ ", "")
    return s
end

------------------------------------------------------------
-- 名冊 → 分組
------------------------------------------------------------
local function HasEntry(entry)
    return (entry.menuKey or entry.slash or entry.category or entry.settings) and not entry.locked
end

local function Rebuild()
    wipe(groups)
    local installed = Info.GetInstalled()
    local all = { key = ALL, label = "全部", entries = {} }
    local byCat, order = {}, {}

    for _, e in ipairs(ns.AddonRoster.entries) do
        if HasEntry(e) and installed[e.folders[1]] and Info.EntryEnabled(e) then
            local cat = Info.EntryCategory(e)
            local g = byCat[cat]
            if not g then
                g = { key = cat, label = cat, entries = {} }
                byCat[cat] = g
                order[#order + 1] = cat
            end
            g.entries[#g.entries + 1] = e
        end
    end

    -- 跟插件總覽同一套排序：分組照名稱、組內照剝掉色碼的標題。
    -- 「全部」就是各組照順序接起來，同組的卡片才會排在一起。
    table.sort(order)
    groups[1] = all
    for _, cat in ipairs(order) do
        local g = byCat[cat]
        table.sort(g.entries, function(a, b)
            return Info.StripCodes(Info.EntryTitle(a)) < Info.StripCodes(Info.EntryTitle(b))
        end)
        groups[#groups + 1] = g
        for _, e in ipairs(g.entries) do all.entries[#all.entries + 1] = e end
    end

    -- 上次選的那一組不見了（插件被停用）就退回「全部」
    local found
    for _, g in ipairs(groups) do
        if g.key == selected then found = true break end
    end
    if not found then selected = ALL end
end

------------------------------------------------------------
-- 卡片
------------------------------------------------------------
local function PaintCard(card, hover)
    card:SetBackdropColor(unpack(hover and CARD_BG_HOVER or CARD_BG))
    if hover then
        card:SetBackdropBorderColor(W.Accent(1))
    else
        card:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

local function CreateCard(parent)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(card, CARD_W, CARD_H)
    W.Stylize(card, CARD_BG)

    -- 縮圖區：佔位層墊在底下，擷圖檔存在時整片蓋過去、不存在時 SetTexture 靜默失敗
    -- 露出佔位層（跟插件總覽的詳情區同一招，不用偵測檔案在不在）。
    -- 貼著卡片的 1px 邊：內縮用 P.Pixel、貼圖關像素貼齊（.claude/notes/wow-1px-border-rules.md）
    local bpx = P.Pixel(1, card)
    local shotH = P.Scale(SHOT_H)

    local ph = P.NoSnap(card:CreateTexture(nil, "BACKGROUND", nil, 1))
    ph:SetPoint("TOPLEFT", bpx, -bpx)
    ph:SetPoint("TOPRIGHT", -bpx, -bpx)
    ph:SetHeight(shotH)
    ph:SetColorTexture(1, 1, 1, 1)
    local ar, ag, ab = W.Accent()
    ph:SetGradient("VERTICAL", CreateColor(ar, ag, ab, 0.02), CreateColor(ar, ag, ab, 0.14))

    card.phIcon = card:CreateTexture(nil, "ARTWORK")
    P.Size(card.phIcon, 40, 40)
    card.phIcon:SetPoint("CENTER", ph, "CENTER")
    card.phIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.shot = P.NoSnap(card:CreateTexture(nil, "OVERLAY"))
    card.shot:SetAllPoints(ph)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    P.Size(card.icon, 14, 14)
    card.icon:SetPoint("TOPLEFT", ph, "BOTTOMLEFT", TEXT_PAD - 1, -7)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.title = card:CreateFontString(nil, "OVERLAY")
    card.title:SetFontObject(W.fontNormal)
    card.title:SetPoint("LEFT", card.icon, "RIGHT", 5, 0)
    card.title:SetPoint("RIGHT", card, "RIGHT", -TEXT_PAD, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)

    card.desc = card:CreateFontString(nil, "OVERLAY")
    card.desc:SetFontObject(W.fontSmall)
    card.desc:SetTextColor(0.6, 0.6, 0.6)
    card.desc:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -5)
    card.desc:SetPoint("RIGHT", card, "RIGHT", -TEXT_PAD, 0)
    card.desc:SetJustifyH("LEFT")
    card.desc:SetJustifyV("TOP")
    card.desc:SetSpacing(2)
    card.desc:SetWordWrap(true)
    card.desc:SetMaxLines(DESC_LINES)

    card:SetScript("OnEnter", function(self) PaintCard(self, true) end)
    card:SetScript("OnLeave", function(self) PaintCard(self, false) end)
    -- ⚠ 卡片會回收：一律讀 self.entry，不把資料抓進 closure
    card:SetScript("OnClick", function(self)
        local entry = self.entry
        if not entry then return end
        if InCombatLockdown() then
            ns.Print("戰鬥中無法開啟。")
            return
        end
        -- 別家的設定視窗多半在比較低的 strata，先讓路
        panel:Hide()
        Info.OpenSettings(entry)
    end)
    return card
end

local function FillCard(card, entry)
    card.entry = entry
    local icon = Info.EntryMeta(entry, "IconTexture") or "Interface\\Icons\\INV_Misc_QuestionMark"
    card.phIcon:SetTexture(icon)
    card.icon:SetTexture(icon)
    card.shot:SetTexture(nil)
    card.shot:SetTexture(SHOTS_PATH .. entry.key .. ".png")
    card.title:SetText(CardTitle(entry))
    card.desc:SetText(CardDesc(entry))
    PaintCard(card, card:IsMouseOver())
end

local function CurrentGroup()
    for _, g in ipairs(groups) do
        if g.key == selected then return g end
    end
    return groups[1]
end

local function RefreshGrid()
    local g = CurrentGroup()
    local list = g and g.entries or {}
    -- 尺寸與位移用同一個換算後的值累加，卡片之間才不會依縮放露縫或疊到
    local cw, ch, gap = P.Scale(CARD_W), P.Scale(CARD_H), P.Scale(GAP)
    for i, entry in ipairs(list) do
        local card = cards[i]
        if not card then
            card = CreateCard(grid.child)
            cards[i] = card
        end
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", grid.child, "TOPLEFT", col * (cw + gap), -row * (ch + gap))
        FillCard(card, entry)
        card:Show()
    end
    for i = #list + 1, #cards do
        cards[i]:Hide()
        cards[i].entry = nil
    end
    local rows = math.ceil(#list / COLS)
    grid:SetContentHeight(math.max(1, rows * (ch + gap)))
    grid:SetVerticalScroll(0)
    grid.empty:SetShown(#list == 0)
end

------------------------------------------------------------
-- 分組標籤（左欄）
------------------------------------------------------------
local RefreshTabs

local function BuildTab(row)
    row:EnableMouse(true)

    row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(W.Accent(0.16))
    row.sel:Hide()

    row.hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 3)
    row.hoverTex:SetAllPoints()
    row.hoverTex:SetColorTexture(1, 1, 1, 0.05)
    row.hoverTex:Hide()

    row.indicator = row:CreateTexture(nil, "ARTWORK")
    row.indicator:SetColorTexture(W.Accent(0.9))
    row.indicator:SetPoint("TOPLEFT", 0, 0)
    row.indicator:SetPoint("BOTTOMLEFT", 0, 0)
    row.indicator:SetWidth(P.Scale(3))
    row.indicator:Hide()

    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFontObject(W.fontSmall)
    row.count:SetTextColor(0.5, 0.5, 0.5)
    row.count:SetPoint("RIGHT", -8, 0)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFontObject(W.fontNormal)
    row.label:SetPoint("LEFT", 10, 0)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row:SetScript("OnEnter", function(self) self.hoverTex:Show() end)
    row:SetScript("OnLeave", function(self) self.hoverTex:Hide() end)
    row:SetScript("OnMouseDown", function(self)
        if not self.groupKey or self.groupKey == selected then return end
        selected = self.groupKey
        RefreshTabs()
        RefreshGrid()
    end)
end

-- ⚠ 列會回收：每一格都重設
local function UpdateTab(row, g)
    row.groupKey = g.key
    row.stripe:Hide()               -- 標籤欄不要斑馬紋，選中／滑過才有底
    row.label:SetText(g.label)
    row.count:SetText(#g.entries)
    local isSel = (g.key == selected)
    row.sel:SetShown(isSel)
    row.indicator:SetShown(isSel)
    row.label:SetAlpha(isSel and 1 or 0.75)
end

function RefreshTabs()
    tabList:Update(groups, UpdateTab)
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIPack_Quick", UIParent, PANEL_W, PANEL_H)
    panel:Hide()                    -- CreateFrame 預設顯示
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    panel:SetPoint("CENTER")        -- 位置不存檔：這扇是「點一下就走」的跳板，每場從中央開
    tinsert(UISpecialFrames, "MiliUIPack_Quick")

    W.CreateTitleBar(panel, "米利UI設定")

    local close = W.CreateButton(panel, "", "red", 20, 20)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetFrameLevel(panel:GetFrameLevel() + 200)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() panel:Hide() end)

    local hint = panel:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", TAB_X + 2, -18)
    hint:SetText("|cff888888點一張卡片開啟該插件的設定。要啟用／停用插件請到「插件總覽」。|r")

    local overview = W.CreateButton(panel, "插件總覽", "normal", 90, 22)
    W.FitButton(overview, 90, 22)
    overview:SetPoint("TOPRIGHT", -30, -12)
    overview:SetScript("OnClick", function()
        panel:Hide()
        ns.OpenOptions("addons")
    end)

    tabList = W.CreateRowList(panel, TAB_W, 1, TAB_H, BuildTab)
    tabList:SetPoint("TOPLEFT", TAB_X, TOP_Y)
    tabList:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", TAB_X, 12)
    -- 分組通常十來個、裝得下：捲軸用不到就收起來，不要留一條空軌道在標籤與卡片之間
    local bar = tabList.scroll.ScrollBar
    if bar and bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end

    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", GRID_X, TOP_Y)
    holder:SetPoint("BOTTOMRIGHT", -8, 12)
    grid = W.CreateScrollFrame(holder)

    grid.empty = holder:CreateFontString(nil, "OVERLAY")
    grid.empty:SetFontObject(W.fontSmall)
    grid.empty:SetPoint("TOP", 0, -40)
    grid.empty:SetText("|cff888888這一組目前沒有啟用中的插件|r")
    grid.empty:Hide()

    panel:SetScript("OnShow", function(self)
        -- ⚠ 第一件事：重算 1px 外框。Stylize 當初 HookScript 的 OnShow 對帳被這個
        -- SetScript 蓋掉了（.claude/notes/wow-1px-border-rules.md）
        W.RefreshEdge(self)
        Rebuild()
        RefreshTabs()
        RefreshGrid()
    end)

    -- 進戰鬥就收：卡片點下去要開的多半是別家的視窗，戰鬥中開不得；
    -- 留著一扇每張卡都按不動的面板沒有意義
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:SetScript("OnEvent", function(self) self:Hide() end)
end

-- 再叫一次＝收起來（跟主設定視窗的 /miliui 同一個手感）
function ns.OpenQuickPanel()
    if InCombatLockdown() then
        ns.Print("戰鬥中無法開啟。")
        return
    end
    CreatePanel()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    panel:Show()
    panel:Raise()
end
