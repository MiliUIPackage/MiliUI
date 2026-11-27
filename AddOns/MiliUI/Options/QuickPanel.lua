------------------------------------------------------------
-- 「快速設定」分頁：主設定視窗的第一頁（預設頁），ESC 選單「米利UI設定」按鈕左鍵直達
--
-- 左：分組標籤（第一顆「全部」），右：三欄卡片（縮圖在上、標題＋兩行簡介在下），
-- 點卡片直接開那支插件的設定（主設定視窗不關，退到後面讓路），卡片最底下那一列
-- （左：狀態字，右：滑動開關，整列可點）切換插件的啟用狀態。取代原本「滑過按鈕往上展開一整排插件名」的選單。
--
-- 資料全部是被動的，這裡沒有任何清單要維護：
--   · 收錄＝全部已安裝的插件，跟插件總覽同一份（Info.CollectVisible：名冊條目＋沒列名冊的
--     自動條目）。停用中的也列，整張壓暗——不列的話關掉之後就沒地方開回來。
--     沒有設定入口的（函式庫、純功能型）一樣有卡片，只是點了沒反應、滑過不反白，只能開關。
--   · 分組＝各插件 TOC 的 Category（-語系），跟插件總覽同一支函式
--   · 縮圖＝Media\Shots\<key>.png，沒有就露出底下的佔位層（插件圖示放大）
--   · 標題／簡介＝TOC 的 Title／Notes（名冊的 desc 優先）
-- 開設定的路由也是插件總覽那一套（ns.AddonInfo.OpenSettings）。
--
-- 開關是批次的，而且跟隔壁「插件總覽」共用同一份待套用清單（Info.SetDesired／GetDesired）：
-- 按卡片底部那一列只是記下來，底部浮出「N 項變更待套用」列，按「套用並重載介面」才一次生效。
-- 除錯模式、完整說明、CPU 用量仍然只在插件總覽。
-- 戰鬥中由主視窗的戰鬥遮罩整頁蓋住（Options/Panel.lua），這裡不用自己擋。
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P
local Info = ns.AddonInfo

local TOP_Y      = -46          -- 標籤欄與卡片區的上緣（上面是分頁標題），跟插件總覽對齊
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
local FOOT_H     = 22           -- 卡片底部的開關列
local SW_W, SW_H = 28, 14       -- 滑動開關（直角：外框＋一塊會左右移的滑塊）
local CARD_H     = SHOT_H + 6 + 16 + 4 + 28 + 8 + FOOT_H
local SHOTS_PATH = "Interface\\AddOns\\MiliUI\\Media\\Shots\\"
local BAR_H      = 34           -- 底部套用列（有待套用變更才出現），跟插件總覽同高
local ALL        = "\001all"    -- 「全部」標籤的鍵；不會跟任何 TOC 分類撞名

local CARD_BG, CARD_BG_HOVER = { 0.115, 0.115, 0.115, 1 }, { 0.17, 0.17, 0.17, 1 }
local OFF_ALPHA  = 0.4          -- 停用卡片的圖與字

local tab, tabList, grid, gridHolder
local applyText, applyBtn, discardBtn
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

-- 卡片上的簡介：壓成一段純文字再交給 SetMaxLines 截斷。只有兩行的位置，所以先把
-- 跟卡片標題重複的開場白拿掉。套組 TOC 的 Notes 幾乎都長這樣（段落用 |n 隔開）：
--     MiliUI QoL            ← 英文名（整段沒有中文字）
--     米利的便利功能。      ← 把標題再講一次
--     商人自動修裝與賣垃圾…  ← 真正的說明
--     使用方法: …           ← 怎麼開設定（卡片本身就是入口）
-- 前兩段與「使用方法」那段都丟掉；丟到沒東西了就退回用「使用方法」，再沒有就整段照舊。
-- ⚠ 一定要先把跳脫序列全部拿掉：截斷點落在 |c／|n 中間，漏出來的半截會被當字面印出來
--   （插件總覽的詳情區為此乾脆不截斷；這裡只有兩行的位置，只能截）。
local function CardDesc(entry, title)
    local raw = entry.desc or Info.EntryMeta(entry, "Notes") or ""
    raw = raw:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    raw = Info.StripCodes(raw)
    raw = raw:gsub("|n", "\n")

    local parts, usage = {}, {}
    for line in raw:gmatch("[^\n]+") do
        local para = line:gsub("|", ""):gsub("%s+", " "):gsub("^ ", "")
        para = para:gsub(" $", "")
        if para ~= "" then
            if para:find("使用方法", 1, true) then
                usage[#usage + 1] = para
            else
                parts[#parts + 1] = para
            end
        end
    end
    local all = table.concat(parts, " ")

    -- 英文名那一段：整段沒有任何非 ASCII 位元組
    if #parts + #usage > 1 and parts[1] and not parts[1]:find("[\128-\255]") then
        table.remove(parts, 1)
    end
    -- 把標題再講一次的那一段：剝掉句號與「米利的／MiliUI」前綴後就是卡片標題（或它的結尾）
    if #parts + #usage > 1 and parts[1] then
        local head = parts[1]:gsub("。$", "")
        head = head:gsub("^MiliUI[%s_]*", ""):gsub("^米利UI%s*", ""):gsub("^米利的", "")
        if head ~= "" and (head == title or title:sub(-#head) == head) then
            table.remove(parts, 1)
        end
    end
    if #parts == 0 then parts = usage end
    if #parts == 0 then return all end
    return table.concat(parts, " ")
end

------------------------------------------------------------
-- 名冊 → 分組
------------------------------------------------------------
-- 這張卡片點了能不能開設定。locked 的（套組本體）設定就在這扇視窗的其他分頁，不算。
local function HasEntry(entry)
    return (entry.menuKey or entry.slash or entry.category or entry.settings) and not entry.locked
end

local function Rebuild()
    wipe(groups)
    local all = { key = ALL, label = "全部", entries = {} }
    local byCat, order = {}, {}

    for _, e in ipairs(Info.CollectVisible()) do
        local cat = Info.EntryCategory(e)
        local g = byCat[cat]
        if not g then
            g = { key = cat, label = cat, entries = {} }
            byCat[cat] = g
            order[#order + 1] = cat
        end
        g.entries[#g.entries + 1] = e
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

    -- 上次選的那一組不見了（插件被移除）就退回「全部」
    local found
    for _, g in ipairs(groups) do
        if g.key == selected then found = true break end
    end
    if not found then selected = ALL end
end

------------------------------------------------------------
-- 卡片
------------------------------------------------------------
local UpdateApplyBar

-- card.on＝畫面上的開關狀態（有待套用的變更就看變更後的）；card.changed＝有待套用的變更。
-- 停用的卡片點了不開設定，所以滑過也不反白；有變更的卡片邊框換橘色（跟「待套用」同色）。
local function PaintCard(card, hover)
    hover = hover and card.on and card.canOpen
    card:SetBackdropColor(unpack(hover and CARD_BG_HOVER or CARD_BG))
    if card.changed then
        card:SetBackdropBorderColor(1, 0.6, 0, 1)
    elseif hover then
        card:SetBackdropBorderColor(W.Accent(1))
    else
        card:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

-- 開關列的底：平時跟卡片同色（只靠上緣那條線分開），滑過亮一階
local function PaintFoot(foot, hover)
    foot.bg:SetColorTexture(1, 1, 1, hover and 0.07 or 0)
end

-- 開關狀態 → 卡片外觀。
-- 開關列左邊的字：已啟用（白）／已停用（灰）；有待套用的變更就換成橘字講「套用後會變怎樣」。
-- 滑動開關：開＝職業色框與滑塊、滑塊靠右；關＝黑框灰滑塊、靠左。
local function PaintState(card)
    local entry = card.entry
    local on = Info.EntryEnabled(entry)
    local want = Info.GetDesired(entry)
    -- 不能寫 want ~= nil and want or on：want 是 false 時會 fall through
    if want ~= nil then on = want end
    card.on, card.changed = on, (want ~= nil)
    card.canOpen = HasEntry(entry) and true or false

    local a = on and 1 or OFF_ALPHA
    card.shot:SetDesaturated(not on)
    card.shot:SetAlpha(a)
    card.phIcon:SetDesaturated(not on)
    card.phIcon:SetAlpha(a)
    card.icon:SetDesaturated(not on)
    card.icon:SetAlpha(a)
    card.title:SetAlpha(a)
    card.desc:SetAlpha(a)

    local foot = card.foot
    if entry.locked then
        foot.text:SetText("無法停用")
        foot.text:SetTextColor(0.5, 0.5, 0.5)
    elseif want ~= nil then
        foot.text:SetText(on and "待套用：啟用" or "待套用：停用")
        foot.text:SetTextColor(1, 0.6, 0)
    elseif on then
        foot.text:SetText("已啟用")
        foot.text:SetTextColor(0.9, 0.9, 0.9)
    else
        foot.text:SetText("已停用")
        foot.text:SetTextColor(0.5, 0.5, 0.5)
    end
    local sw, r, g, b = foot.switch, W.Accent()
    sw.thumb:ClearAllPoints()
    if on then
        sw:SetBackdropColor(r * 0.3, g * 0.3, b * 0.3, 1)
        sw:SetBackdropBorderColor(r * 0.6, g * 0.6, b * 0.6, 1)
        sw.thumb:SetColorTexture(r, g, b, 1)
        sw.thumb:SetPoint("TOPRIGHT", -sw.inset, -sw.inset)
        sw.thumb:SetPoint("BOTTOMRIGHT", -sw.inset, sw.inset)
    else
        sw:SetBackdropColor(0.17, 0.17, 0.17, 1)
        sw:SetBackdropBorderColor(0, 0, 0, 1)
        sw.thumb:SetColorTexture(0.45, 0.45, 0.45, 1)
        sw.thumb:SetPoint("TOPLEFT", sw.inset, -sw.inset)
        sw.thumb:SetPoint("BOTTOMLEFT", sw.inset, sw.inset)
    end
    sw:SetAlpha(entry.locked and 0.4 or 1)
    PaintCard(card, card:IsMouseOver() and not foot:IsMouseOver())
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

    -- 開關列：卡片最底下一整列都是點擊區（左：狀態字，右：滑動開關），跟上面「點了開設定」
    -- 的區域分開，不會誤點。上緣一條 1px 線。
    -- ⚠ 卡片會回收：一律讀 card.entry，不把資料抓進 closure
    local foot = CreateFrame("Button", nil, card)
    foot:SetPoint("BOTTOMLEFT", bpx, bpx)
    foot:SetPoint("BOTTOMRIGHT", -bpx, bpx)
    foot:SetHeight(P.Scale(FOOT_H))
    card.foot = foot

    foot.bg = foot:CreateTexture(nil, "BACKGROUND")
    foot.bg:SetAllPoints()

    local line = P.NoSnap(foot:CreateTexture(nil, "BORDER"))
    line:SetColorTexture(0, 0, 0, 1)
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(bpx)

    foot.text = foot:CreateFontString(nil, "OVERLAY")
    foot.text:SetFontObject(W.fontSmall)
    foot.text:SetPoint("LEFT", TEXT_PAD - 1, 0)

    local sw = CreateFrame("Frame", nil, foot, "BackdropTemplate")
    P.Size(sw, SW_W, SW_H)
    sw:SetPoint("RIGHT", -(TEXT_PAD - 1), 0)
    W.Stylize(sw, { 0.17, 0.17, 0.17, 1 })
    sw.inset = P.Pixel(2, sw)           -- 1px 框＋1px 空隙
    sw.thumb = P.NoSnap(sw:CreateTexture(nil, "ARTWORK"))
    sw.thumb:SetWidth(P.Scale(SW_W / 2 - 2))
    foot.switch = sw

    foot:SetScript("OnClick", function()
        local entry = card.entry
        if not entry then return end
        Info.SetDesired(entry, not card.on)
        PaintState(card)
        UpdateApplyBar()
    end)
    -- 子框會搶走滑鼠焦點：滑進開關列的瞬間卡片收到 OnLeave，滑出來時卡片不一定收到 OnEnter。
    -- 所以卡片的反白一律用 IsMouseOver（幾何判定）重畫；游標在開關列上時卡片本體不反白——
    -- 那時候點下去是切換、不是開設定。
    foot:SetScript("OnEnter", function(self)
        PaintFoot(self, true)
        PaintCard(card, false)
    end)
    foot:SetScript("OnLeave", function(self)
        PaintFoot(self, false)
        PaintCard(card, card:IsMouseOver())
    end)

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
    card:SetScript("OnLeave", function(self)
        PaintCard(self, self:IsMouseOver() and not self.foot:IsMouseOver())
    end)
    card:SetScript("OnClick", function(self)
        local entry = self.entry
        -- 停用的（含「待套用：停用」「待套用：啟用」還沒重載的）不開設定
        if not entry or not self.canOpen or not self.on or not Info.EntryEnabled(entry) then return end
        if InCombatLockdown() then
            ns.Print("戰鬥中無法開啟。")
            return
        end
        Info.OpenSettings(entry)    -- 主設定視窗不關，退到後面讓路給別家的視窗
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
    local title = CardTitle(entry)
    card.title:SetText(title)
    card.desc:SetText(CardDesc(entry, title))
    PaintState(card)
end

------------------------------------------------------------
-- 套用列（底部，有待套用變更才出現；卡片區跟著讓出高度）
------------------------------------------------------------
function UpdateApplyBar()
    local n = Info.PendingCount()
    local show = n > 0
    if show then
        applyText:SetText(("|cffff9900%d 項變更待套用|r"):format(n))
    end
    applyText:SetShown(show)
    applyBtn:SetShown(show)
    discardBtn:SetShown(show)
    gridHolder:SetPoint("BOTTOMRIGHT", -8, show and (BAR_H + 8) or 12)
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
-- 分頁組裝
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, "快速設定", ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    local hint = tab:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 7)
    hint:SetJustifyH("RIGHT")
    hint:SetText("|cff888888點卡片開啟該插件的設定（滑過會亮的才有）；卡片底部的開關切換啟用，套用並重載後生效|r")

    tabList = W.CreateRowList(tab, TAB_W, 1, TAB_H, BuildTab)
    tabList:SetPoint("TOPLEFT", TAB_X, TOP_Y)
    tabList:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", TAB_X, 12)
    -- 分組通常十來個、裝得下：捲軸用不到就收起來，不要留一條空軌道在標籤與卡片之間
    local bar = tabList.scroll.ScrollBar
    if bar and bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end

    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", GRID_X, TOP_Y)
    holder:SetPoint("BOTTOMRIGHT", -8, 12)
    gridHolder = holder
    grid = W.CreateScrollFrame(holder)

    -- 套用列：位置、用字、配色都跟插件總覽那一列一樣（同一份待套用清單的兩個入口）
    applyBtn = W.CreateButton(tab, "套用並重載介面", "green", 140, 24)
    applyBtn:SetPoint("BOTTOMRIGHT", -16, 8)
    applyBtn:SetScript("OnClick", Info.ApplyPending)
    applyBtn:Hide()

    discardBtn = W.CreateButton(tab, "放棄變更", "normal", 90, 24)
    discardBtn:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)
    discardBtn:SetScript("OnClick", function()
        Info.DiscardPending()
        UpdateApplyBar()
        for _, card in ipairs(cards) do
            if card.entry then PaintState(card) end
        end
    end)
    discardBtn:Hide()

    applyText = tab:CreateFontString(nil, "OVERLAY")
    applyText:SetFontObject(W.fontNormal)
    applyText:SetPoint("RIGHT", discardBtn, "LEFT", -12, 0)
    applyText:Hide()

    grid.empty = holder:CreateFontString(nil, "OVERLAY")
    grid.empty:SetFontObject(W.fontSmall)
    grid.empty:SetPoint("TOP", 0, -40)
    grid.empty:SetText("|cff888888這一組目前沒有插件|r")
    grid.empty:Hide()
end

-- 每次切進來都重讀名冊：待套用的開關可能剛在隔壁「插件總覽」改過
ns.RegisterCallback("ShowOptionsTab", "quickTab", function(id)
    if id ~= "quick" then
        if tab then tab:Hide() end
        return
    end
    Init()
    Rebuild()
    RefreshTabs()
    RefreshGrid()
    UpdateApplyBar()
    tab:Show()
end)
