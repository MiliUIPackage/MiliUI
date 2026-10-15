------------------------------------------------------------
-- 資源條頁「自訂格子」「自訂列」「觸發牌堆」三個分頁上方的固定預覽框
--
--   local pv = ns.ResPreview.Create(page, width)   資源條頁建一次（Options/Tab_Resources.lua）
--   pv:SetMode("pips"|"custombars"|"procdeck"|其他) 換分頁；其他 ＝ 整框藏起來（職業資源分頁不出）
--   pv:Refresh()                                   照目前設定重畫（任何改值、拖曳排序、增刪、換專精、切分頁、頁面重新顯示）
--
-- 放在捲動區外面（照圖示條頁的預覽框：W.Stylize 深底黑邊、頁面上方），表單捲到哪都看得到。
-- 畫的是**我們自己的假框**，一個秘密值都不碰、不碰引擎容器（AuraContainer）：只有 Frame／StatusBar／FontString／Texture，
-- 外觀與排版借引擎的純函式與小工具，跟遊戲裡同一套算法：
--   自訂列    CB.Plan（順序、哪些列會建：壞資料／關閉／沒學會的冷卻法術不建）、CB.Grow（往上／往下長）、CB.RowOffsets、
--            CB.PanelHeight、CB.Geometry、CB.Look（填色、材質、底色、邊框、圖示、字型、文字位置）、AuraBar.RowDecor（條身的
--            暗底與邊框，引擎的一直顯示列也是這支）
--   自訂格子  Pips.PlanCustomRows（格數：充能上限讀得到明文就用、讀不到退存檔、再退 2）、Pips.CustomColor、Pips.RowText、
--            Pips.TextMode、Pips.ChargeAlpha（顯示時機）；充能列一格一框（R.SegCell＋R.Edges／PaintEdges＋R.DimColor，
--            同 LayoutCustomRow）、層數列是裝飾＋分段（AuraBar.RowDecor＋AuraBar.Geometry，同 LayoutStackEngine）。
--            自訂格子在遊戲裡一律從面板上緣往下排（Relayout 不看錨定），預覽照做
-- 寬、列距照資源條（R.Width(style, 面板)、rowSpacing），放不下就縮到框內寬；高度＝上下內距＋各列高＋列距，
-- 超過 MAX_H 就裁掉離錨點最遠的那幾列（往上長的貼底、往下長的貼頂）。整組關著（enabled = false）照畫、整組 0.35 透明。
--
-- 假動畫（OnUpdate 只在框看得到、而且有列時跑）：
--   自訂列    每列倒 RUN 秒（8～14 秒，各列不同）、停 IDLE 秒循環，起點各列錯開。小數門檻、低時間變色、名字顯示時機、
--            「只在生效時顯示」（停的那段整列透明，跟遊戲一樣照樣佔位）都看得到
--   充能列    滿 HOLD 秒 → 用掉一格 → 下一格平滑長回來（回充 6～10 秒，數字開著時印回充秒數）→ 滿
--   層數列    0 → 上限每秒加一層、到頂停 HOLD 秒 → 歸零；光環剩餘時間每加一層刷新一次（文字照 TextMode）。
--            「只在有光環時顯示」在 0 層那段整列透明（遊戲裡裝飾與填色都在按鈕子樹，沒光環整列不見、照樣佔位）
--   觸發牌堆  只畫 row 樣式、勾了的牌堆（PD.Plan），列借引擎的 ProcDeckRows.NewRow／LayoutRow／PaintRow，值是固定假資料
--            （翻到 37%、中了一個、刻度在 20%），不動。疊在格子上的樣式不畫（看畫面上的格子）
-- 沒有任何一列：框縮成一行灰字（框照樣在，跟圖示條頁「這條目前沒有技能」時框還在一致，加第一列時表單不跳）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.ResPreview = {}
local RP = ns.ResPreview

local PAD      = 8            -- 框內上下左右的內距
local MAX_H    = 150          -- 框最高多高（設定視窗只有 520 高，表單要留位置）
local EMPTY_H  = 30           -- 沒有列時（一行灰字）
local IDLE     = 2            -- 自訂列：倒完停幾秒
local HOLD     = 2            -- 自訂格子：滿／到頂停幾秒
local AURA_DUR = 10           -- 層數列的光環持續時間（秒數文字用）
local OFF_ALPHA = 0.35        -- 整組關著

------------------------------------------------------------
-- 純函式（離線測得到：Tests/CustomBars_test.lua 第 9 節）
------------------------------------------------------------
-- 第 i 列的倒數長度（8～14 秒）與起點偏移（各列錯開）
function RP.BarRun(i) return 8 + ((i - 1) * 3) % 7 end
function RP.Phase(i) return (i - 1) * 3.7 end
-- 充能列一格回充幾秒（6～10）
function RP.Recharge(i) return 6 + ((i - 1) * 2) % 5 end

-- 秒數的格式照 Core/Text.lua 的 CountdownFormatter：門檻以下一位小數（無條件捨去）、以上整數（無條件進位）
function RP.TimeText(rem, decimals)
    decimals = tonumber(decimals) or 0
    if decimals > 0 and rem < decimals then return string.format("%.1f", math.floor(rem * 10) / 10) end
    return tostring(math.ceil(rem))
end

-- 自訂列：t 秒時生不生效、剩幾秒
function RP.BarState(t, run)
    t = t % (run + IDLE)
    if t < run then return true, run - t end
    return false, 0
end

-- 充能列：t 秒時 → 目前充能數, 下一格回充進度（0～1；沒在回充 nil）, 回充剩幾秒
function RP.ChargeState(t, n, recharge)
    t = t % (HOLD + recharge)
    if t < HOLD then return n, nil, 0 end
    local e = t - HOLD
    return n - 1, e / recharge, recharge - e
end

-- 層數列：t 秒時 → 層數, 光環剩幾秒（0 層 ＝ 沒有光環）。0 層 1 秒、每秒加一層、到頂多停 HOLD 秒
function RP.StackState(t, max)
    t = t % (max + 1 + HOLD)
    local s = math.floor(t)
    if s > max then s = max end
    return s, AURA_DUR - (t - s)
end

-- 層數列的文字（Pips.TextMode：stacks／time／stacksTime／timeStacks）
function RP.StackText(mode, stacks, rem)
    local sec = tostring(math.ceil(rem))
    if mode == "time" then return sec end
    if mode == "stacksTime" then return stacks .. " (" .. sec .. ")" end
    if mode == "timeStacks" then return sec .. " (" .. stacks .. ")" end
    return tostring(stacks)
end

------------------------------------------------------------
-- 自訂列的一列：版面（LayoutBarRow）＋每幀的值（TickBarRow）。外觀照 Modules/CustomBars.lua 的 LayoutRow
------------------------------------------------------------
local function NewBarRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.iconFrame = row:CreateTexture(nil, "BACKGROUND")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.barFrame = CreateFrame("Frame", nil, row)
    row.bar = CreateFrame("StatusBar", nil, row.barFrame)
    row.bar:SetAllPoints(row.barFrame)
    row.bar:SetMinMaxValues(0, 1)
    row.textFrame = CreateFrame("Frame", nil, row.barFrame)
    row.textFrame:SetAllPoints(row.barFrame)
    for _, k in ipairs({ "name", "time", "stacks" }) do
        local fs = row.textFrame:CreateFontString(nil, "OVERLAY")
        ns.Media.SetPixelFont(fs, 10, "OUTLINE")       -- 先給字型才能 SetText（樣式在版面時重套）
        fs:SetWordWrap(false)
        row[k] = fs
    end
    return row
end

-- 字忽略父層縮放：偏移是像素（同引擎的 PlaceText）
local function PlaceText(fs, parent, point, look)
    fs:ClearAllPoints()
    fs:SetJustifyH(point)
    local pad = (point == "LEFT" and look.padPx) or (point == "RIGHT" and -look.padPx) or 0
    fs:SetPoint(point, parent, point, pad, look.offY or 0)
end

local function LayoutBarIcon(row, st, look, g, H)
    if st.icon == "none" then
        row.iconFrame:Hide()
        row.icon:Hide()
        return
    end
    -- 框色＝邊框色、圖示內縮邊框粗細（同 LayoutRowParts）
    local ec, px = look.edge, look.px or 0
    row.iconFrame:ClearAllPoints()
    row.iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", g.iconX, 0)
    row.iconFrame:SetSize(g.iconW, H)
    row.iconFrame:SetColorTexture(ec[1], ec[2], ec[3], ec[4])
    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", px, -px)
    row.icon:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -px, px)
    row.icon:SetTexture(look.iconFile)
    row.iconFrame:Show()
    row.icon:Show()
end

local function LayoutBarText(row, st, look)
    for _, k in ipairs({ "name", "time", "stacks" }) do
        ns.Media.SetPixelFont(row[k], look.size, look.outline, look.token)
        row[k]:SetTextColor(1, 1, 1, 1)
    end
    row.name:SetWidth(look.nameWpx)
    PlaceText(row.name, row.barFrame, st.namePoint, look)
    row.name:SetText(look.name)
    PlaceText(row.time, row.barFrame, st.timePoint, look)
    PlaceText(row.stacks, row.barFrame, st.stacksPoint, look)
    row.stacks:SetText("3")
end

local function LayoutBarRow(row, plan, style, Wd)
    local st = plan.st
    local H = P.Scale(st.height)
    row:SetSize(Wd, H)
    local g = ns.CustomBars.Geometry(Wd, H, st.icon, P.Pixel(1))
    local look = ns.CustomBars.Look(style, plan, g)
    local lv = row:GetFrameLevel() or 1
    LayoutBarIcon(row, st, look, g, H)
    row.barFrame:ClearAllPoints()
    row.barFrame:SetPoint("TOPLEFT", row, "TOPLEFT", g.barX, 0)
    row.barFrame:SetSize(g.barW, H)
    -- 暗底與邊框：引擎一直顯示的列同一支（暗底在條身底下、邊框蓋在填色上）
    ns.AuraBar.RowDecor(row.barFrame, { W = g.barW, H = H, n = 1, gap = 0, segW = g.barW, segments = false,
        reversed = st.reverse, dim = look.dim, px = look.px, edge = look.edge, bgTex = look.bgTex }, lv + 8)
    row.bar:SetFrameLevel(lv + 2)
    row.bar:SetStatusBarTexture(look.texture)
    row.bar:SetStatusBarColor(look.r, look.g, look.b, look.alpha or 1)
    row.bar:SetReverseFill(st.reverse)
    row.textFrame:SetFrameLevel(lv + 12)
    LayoutBarText(row, st, look)
    row.st = st
end

local function TickBarRow(row, t)
    local st = row.st
    local active, rem = RP.BarState(t, row.run)
    -- 只在生效時顯示：停的那段整列透明（照樣佔位）。判準同引擎的冷卻列（CB.CooldownAlpha）
    row:SetAlpha(ns.CustomBars.CooldownAlpha(st.showWhen, active and "active" or "idle") or 1)
    row.bar:SetValue(active and rem / row.run or 0)
    if st.timeShow and active then
        row.time:SetText(RP.TimeText(rem, st.decimals))
        local c = (st.lowOn and rem < st.lowBelow) and st.lowColor or nil
        if c then row.time:SetTextColor(c.r, c.g, c.b, 1) else row.time:SetTextColor(1, 1, 1, 1) end
        row.time:Show()
    else
        row.time:Hide()
    end
    row.stacks:SetShown(st.stacksShow and active)
    row.name:SetShown(st.nameShow and (active or st.nameWhen == "always"))
end

------------------------------------------------------------
-- 自訂格子的一列
------------------------------------------------------------
local function NewPipRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.cells = {}               -- 充能列：一格一框（懶建）
    row.fills = {}               -- 層數列：每格的填色貼圖（懶建）
    row.fillFrame = CreateFrame("Frame", nil, row)
    row.fillFrame:SetAllPoints(row)
    row.textFrame = CreateFrame("Frame", nil, row)
    row.textFrame:SetAllPoints(row)
    row.text = row.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetPixelFont(row.text, 8, "OUTLINE")
    return row
end

local function NewCell(row)
    local cell = CreateFrame("Frame", nil, row)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints(cell)
    cell.rc = CreateFrame("StatusBar", nil, cell)      -- 回充條（這一列顏色的暗版）
    cell.rc:SetAllPoints(cell)
    cell.rc:SetMinMaxValues(0, 1)
    cell.bar = CreateFrame("StatusBar", nil, cell)     -- 填色
    cell.bar:SetAllPoints(cell)
    cell.edges = ns.Resources.Edges(cell.bar)
    cell.tf = CreateFrame("Frame", nil, cell)
    cell.tf:SetAllPoints(cell)
    cell.text = cell.tf:CreateFontString(nil, "OVERLAY")
    ns.Media.SetPixelFont(cell.text, 8, "OUTLINE")
    return cell
end

local function HideFrom(list, from)
    for i = from, #list do list[i]:Hide() end
end

-- 充能列：同 LayoutCustomRow 的格子（R.SegCell、每格四條邊、暗底、填色、暗版回充條、置中秒數）
local function LayoutChargeCells(row, plan, style, Wd, H, look)
    local R = ns.Resources
    local n = plan.numSeg
    local bt, bc = R.BorderSize(style), R.BorderColor(style)
    local dc, da = R.DimColor(nil, style)
    local ox, oy = R.TextOffset(style)
    for i = 1, n do
        local cell = row.cells[i] or NewCell(row)
        row.cells[i] = cell
        local x, segW = R.SegCell(Wd, n, style.segmentSpacing, i, bt)
        R.PaintEdges(cell.edges, bt, bc)
        cell:SetSize(segW, H)
        cell:ClearAllPoints()
        if look.reversed then cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0) else cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0) end
        local lv = cell:GetFrameLevel()
        cell.bg:SetTexture(look.bgTex)
        cell.bg:SetVertexColor(dc.r, dc.g, dc.b, da)
        cell.rc:SetFrameLevel(lv + 2)
        cell.rc:SetStatusBarTexture(look.tex)
        cell.rc:SetStatusBarColor(look.r * 0.5, look.g * 0.5, look.b * 0.5, look.alpha)
        cell.rc:SetReverseFill(look.reversed)
        cell.bar:SetFrameLevel(lv + 4)
        cell.bar:SetStatusBarTexture(look.tex)
        cell.bar:SetStatusBarColor(look.r, look.g, look.b, look.alpha)
        cell.bar:SetMinMaxValues(ns.Pips.FillRange(i))
        cell.tf:SetFrameLevel(lv + 5)
        ns.Media.SetPixelFont(cell.text, look.size, look.outline, look.font)
        cell.text:SetTextColor(1, 1, 1, 1)
        cell.text:ClearAllPoints()
        cell.text:SetPoint("CENTER", cell, "CENTER", ox, oy)
        cell:Show()
    end
    HideFrom(row.cells, n + 1)
end

-- 層數列：同 LayoutStackEngine（AuraBar.RowDecor 的暗底與邊框；填色在 AuraBar.Geometry 的格子上，等於引擎整條填色挖掉格距）
local function LayoutStackCells(row, plan, style, Wd, H, look)
    local R = ns.Resources
    local n = plan.numSeg
    local gap = P.Pixel(tonumber(style.segmentSpacing) or 1)
    local segW = (Wd - gap * (n - 1)) / n
    local lv = row:GetFrameLevel() or 1
    ns.AuraBar.RowDecor(row, { W = Wd, H = H, n = n, gap = gap, segW = segW, reversed = look.reversed, segments = true,
        dim = R.DimArray(style), px = R.DecorPx(style), edge = R.EdgeArray(style), bgTex = look.bgTex, mask = gap > 0 }, lv + 8)
    row.fillFrame:SetFrameLevel(lv + 2)
    local geo = ns.AuraBar.Geometry(Wd, n, gap, segW, P.Pixel(1))
    for i, c in ipairs(geo.cells) do
        local t = row.fills[i]
        if not t then
            t = row.fillFrame:CreateTexture(nil, "ARTWORK")
            row.fills[i] = t
        end
        t:SetTexture(look.tex)
        t:SetVertexColor(look.r, look.g, look.b, look.alpha)
        t:ClearAllPoints()
        if look.reversed then t:SetPoint("TOPRIGHT", row, "TOPRIGHT", -c.x, 0) else t:SetPoint("TOPLEFT", row, "TOPLEFT", c.x, 0) end
        t:SetSize(c.w, H)
    end
    HideFrom(row.fills, #geo.cells + 1)
    row.textFrame:SetFrameLevel(lv + 10)
    ns.Media.SetPixelFont(row.text, look.size, look.outline, look.font)
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:ClearAllPoints()
    row.text:SetPoint("CENTER", row, "CENTER", R.TextOffset(style))
end

local function LayoutPipRow(row, plan, style, Wd)
    local Pips = ns.Pips
    local H = P.Scale(plan.height)
    row:SetSize(Wd, H)
    local r, g, b = Pips.CustomColor(plan.entry)
    local show, size, font, outline = Pips.RowText(plan, style)
    local look = { r = r, g = g, b = b, alpha = tonumber(style.barAlpha) or 1, tex = ns.Media.Texture(style.texture),
        bgTex = ns.Resources.BgTexture(style), reversed = ns.FillReversed(style),
        show = show, size = size, font = font, outline = outline }
    row.plan, row.look = plan, look
    if plan.kind == "charges" then
        HideFrom(row.fills, 1)
        ns.AuraBar.HideRowDecor(row)
        row.text:Hide()
        LayoutChargeCells(row, plan, style, Wd, H, look)
    else
        HideFrom(row.cells, 1)
        LayoutStackCells(row, plan, style, Wd, H, look)
    end
end

local function TickChargeRow(row, t)
    local plan, look = row.plan, row.look
    local n = plan.numSeg
    local cur, prog, rem = RP.ChargeState(t, n, row.run)
    local a = ns.Pips.ChargeAlpha(plan.showWhen, cur < n, InCombatLockdown() and true or false, 1)
    row:SetAlpha(a or 1)
    for i = 1, n do
        local cell = row.cells[i]
        cell.bar:SetValue(cur)
        local isNext = prog and i == cur + 1
        cell.rc:SetShown(isNext and true or false)
        if isNext then
            cell.rc:SetValue(prog)
            cell.text:SetText(look.show and tostring(math.ceil(rem)) or "")
        else
            cell.text:SetText("")
        end
    end
end

local function TickStackRow(row, t)
    local plan, look = row.plan, row.look
    local stacks, rem = RP.StackState(t, plan.numSeg)
    -- 只在有光環時顯示：0 層（沒有光環）整列透明、照樣佔位
    row:SetAlpha((plan.showWhen == "active" and stacks == 0) and 0 or 1)
    -- 填充方向反向時格子本來就是從右邊排過來的：第 i 個貼圖就是第 i 層
    for i = 1, plan.numSeg do
        local f = row.fills[i]
        if f then f:SetShown(i <= stacks) end
    end
    if look.show and stacks > 0 then
        row.text:SetText(RP.StackText(ns.Pips.TextMode(plan.entry), stacks, rem))
        row.text:Show()
    else
        row.text:Hide()
    end
end

------------------------------------------------------------
-- 預覽框
------------------------------------------------------------
local Proto = {}
Proto.__index = Proto

function RP.Create(parent, width)
    local pv = setmetatable({ width = width, mode = nil, barRows = {}, pipRows = {}, deckRows = {}, shown = {}, t0 = GetTime() }, Proto)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Stylize(f, { 0.06, 0.06, 0.06, 1 }, { 0, 0, 0, 1 })
    f:SetSize(width, EMPTY_H)
    pv.frame = f
    -- 裁切：列太多時離錨點最遠的那幾列被切掉，不畫出框外
    local clip = CreateFrame("Frame", nil, f)
    clip:SetPoint("TOPLEFT", 1, -1)
    clip:SetPoint("BOTTOMRIGHT", -1, 1)
    clip:SetClipsChildren(true)
    pv.stack = CreateFrame("Frame", nil, clip)
    pv.clip = clip
    local empty = f:CreateFontString(nil, "OVERLAY")
    empty:SetFontObject(W.fontSmall)
    empty:SetTextColor(0.65, 0.65, 0.65)
    empty:SetPoint("LEFT", f, "LEFT", PAD + 2, 0)
    empty:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    empty:SetJustifyH("LEFT")
    empty:SetWordWrap(false)
    pv.empty = empty
    pv.onUpdate = function() pv:Tick() end
    f:Hide()
    return pv
end

function Proto:SetMode(mode)
    self.mode = (mode == "pips" or mode == "custombars" or mode == "procdeck") and mode or nil
    self:Refresh()
end

-- 沒有列：一行灰字（框照樣在）
function Proto:ShowEmpty(text)
    for _, row in ipairs(self.shown) do row:Hide() end
    self.shown = {}
    self.stack:Hide()
    self.empty:SetText(text)
    self.empty:Show()
    self.frame:SetHeight(EMPTY_H)
    self.frame:SetScript("OnUpdate", nil)
end

-- 這一頁要畫哪些列（照遊戲裡的規劃）→ plans, 原始清單有沒有東西
function Proto:Plans(style)
    local specID = ns.specID
    if self.mode == "custombars" then
        local CB = ns.CustomBars
        local list = CB.List(style, specID)
        return CB.Plan(style, specID, CB.gameProbe), list ~= nil and list[1] ~= nil
    end
    local Pips = ns.Pips
    local list = Pips.CustomRowList(style, specID)
    return Pips.PlanCustomRows(style, specID, Pips.gameProbe), list ~= nil and list[1] ~= nil
end

function Proto:Refresh()
    local f = self.frame
    if not self.mode then
        f:Hide()
        f:SetScript("OnUpdate", nil)
        return
    end
    f:Show()
    local style = ns.DB.ConfigTable("resources")
    if not style then return end
    if not ns.specID then return self:ShowEmpty(L["Pick a specialization first."]) end
    if self.mode == "procdeck" then return self:RefreshDecks(style) end
    local plans, hasList = self:Plans(style)
    if plans[1] == nil then
        if hasList then return self:ShowEmpty(L["Nothing to show right now: the spells on this list aren't learned."]) end
        return self:ShowEmpty(self.mode == "custombars" and L["No custom bars for this specialization yet."]
            or L["No custom segments for this specialization yet."])
    end
    self:Layout(plans, style)
end

function Proto:Layout(plans, style)
    local bars = self.mode == "custombars"
    local pool = bars and self.barRows or self.pipRows
    local other = bars and self.pipRows or self.barRows
    for _, row in ipairs(other) do row:Hide() end
    for _, row in ipairs(self.deckRows) do row:Hide() end
    local inner = self.width - 2 * PAD - 2
    local Wd = P.Scale(math.min(ns.Resources.Width(style, self.mode), inner))
    local gap = P.Scale(tonumber(style.rowSpacing) or 1)
    local heights = {}
    for i, plan in ipairs(plans) do heights[i] = P.Scale(bars and plan.st.height or plan.height) end
    local offsets = ns.CustomBars.RowOffsets(heights, gap)
    local contentH = ns.CustomBars.PanelHeight(heights, gap)
    -- 自訂列照錨定往上或往下長（CB.Grow，同引擎 Relayout）；自訂格子在遊戲裡一律往下排
    local down = true
    if bars then
        local cfg = ns.DB.ConfigTable("custombars")
        down = ns.CustomBars.Grow(cfg and cfg.anchor) == "down"
    end
    local stack = self.stack
    stack:ClearAllPoints()
    stack:SetSize(Wd, contentH)
    if down then stack:SetPoint("TOP", self.clip, "TOP", 0, -(PAD - 1)) else stack:SetPoint("BOTTOM", self.clip, "BOTTOM", 0, PAD - 1) end
    local panel = ns.DB.ConfigTable(self.mode)
    stack:SetAlpha((panel and panel.enabled == false) and OFF_ALPHA or 1)
    stack:Show()
    self.empty:Hide()
    local shown = {}
    for i, plan in ipairs(plans) do
        local row = pool[i] or (bars and NewBarRow(stack) or NewPipRow(stack))
        pool[i] = row
        row:ClearAllPoints()
        if down then row:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -offsets[i]) else row:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", 0, offsets[i]) end
        if bars then
            row.run = RP.BarRun(i)
            LayoutBarRow(row, plan, style, Wd)
        else
            row.run = (plan.kind == "charges") and RP.Recharge(i) or nil
            LayoutPipRow(row, plan, style, Wd)
        end
        row.phase = RP.Phase(i)
        row:Show()
        shown[i] = row
    end
    for i = #plans + 1, #pool do pool[i]:Hide() end
    self.shown = shown
    self.frame:SetHeight(math.min(MAX_H, contentH + 2 * PAD))
    self.frame:SetScript("OnUpdate", self.onUpdate)
    self:Tick()
end

-- 觸發牌堆：勾了、樣式是資源條列的牌堆，畫固定的假資料（不跑動畫）
function Proto:RefreshDecks(style)
    local PD, PDR = ns.ProcDeck, ns.ProcDeckRows
    if PD.DefsFor(ns.playerClass, ns.specID)[1] == nil then
        return self:ShowEmpty(L["This specialization has no proc decks to track."])
    end
    local plans = PD.Plan(style, ns.playerClass, ns.specID, "row")
    if plans[1] == nil then
        return self:ShowEmpty(L["No deck is shown as a resource bar row; decks on a cooldown icon show on the icon itself."])
    end
    for _, row in ipairs(self.barRows) do row:Hide() end
    for _, row in ipairs(self.pipRows) do row:Hide() end
    local inner = self.width - 2 * PAD - 2
    local Wd = P.Scale(math.min(ns.Resources.Width(style, PDR.KEY), inner))
    local gap = P.Scale(tonumber(style.rowSpacing) or 1)
    local heights = {}
    for i, p in ipairs(plans) do heights[i] = P.Scale(p.s.height) end
    local offsets = ns.CustomBars.RowOffsets(heights, gap)
    local contentH = ns.CustomBars.PanelHeight(heights, gap)
    local cfg = ns.DB.ConfigTable(PDR.KEY)
    local down = ns.CustomBars.Grow(cfg and cfg.anchor) == "down"
    local stack = self.stack
    stack:ClearAllPoints()
    stack:SetSize(Wd, contentH)
    if down then stack:SetPoint("TOP", self.clip, "TOP", 0, -(PAD - 1)) else stack:SetPoint("BOTTOM", self.clip, "BOTTOM", 0, PAD - 1) end
    stack:SetAlpha((cfg and cfg.enabled == false) and OFF_ALPHA or 1)
    stack:Show()
    self.empty:Hide()
    for i, p in ipairs(plans) do
        local row = self.deckRows[i] or PDR.NewRow(stack)
        self.deckRows[i] = row
        row:ClearAllPoints()
        if down then row:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -offsets[i]) else row:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", 0, offsets[i]) end
        row:Show()
        PDR.LayoutRow(row, p.def, p.s, style, Wd)
        local st = PD.New()
        st.drawn, st.hit, st.ticks = math.floor(p.def.size * 0.37), 1, { math.floor(p.def.size * 0.2) }
        PDR.PaintRow(row, st)
    end
    for i = #plans + 1, #self.deckRows do self.deckRows[i]:Hide() end
    self.shown = {}
    self.frame:SetHeight(math.min(MAX_H, contentH + 2 * PAD))
    self.frame:SetScript("OnUpdate", nil)
end

function Proto:Tick()
    local now = GetTime() - self.t0
    local bars = self.mode == "custombars"
    for _, row in ipairs(self.shown) do
        local t = now + row.phase
        if bars then
            TickBarRow(row, t)
        elseif row.plan.kind == "charges" then
            TickChargeRow(row, t)
        else
            TickStackRow(row, t)
        end
    end
end
