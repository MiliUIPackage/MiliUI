------------------------------------------------------------
-- 觸發牌堆的「資源條列」樣式：一個牌堆一列（獨立面板，容器 MiliUICDM_Bar_procdeck）
--
-- 狀態與牌堆定義在 Modules/ProcDeck.lua（兩種畫法共用同一份狀態，切換樣式不重算）；這支只畫 style ＝ "row" 的牌堆。
--
-- 資料與樣式都借資源條的（同自訂列，Modules/CustomBars.lua）：
--   * 每個牌堆的設定：profile.resources.procDecks[specID][key]（PD.Setting：高、圖示、名字、文字模式、顏色、刻度）
--   * 樣式：寬（0 ＝ 錨定目標的第一列，預設資源條 → 退回核心技能）、材質、背景材質／透明度／自訂底色、填充透明度、
--     邊框粗細／顏色、列距、字型與描邊一律讀 profile.resources
--   * 自己的只有 profile.procdeck：enabled、pos、anchor、fadeWithEssential、loadConditions、strata
-- 預設錨在資源條下方（anchor TOP → resources BOTTOM）、往下長。資源條預設在核心技能上方 ⇒ 照排開的通則
-- （Core/Layout.lua 的 StackTarget）實際排到核心技能下方那一疊、自訂格子與輔助技能之前（Core/Bars.lua 的 STACK_RANK 1.1）。
-- 沒有任何一列時面板收合（不佔位）。
--
-- 一列：左圖示（可關）＋條身（StatusBar，最大值＝這疊幾張、值＝翻了幾張：**自己數的明文**，直接餵）＋白色刻度
-- （這疊實際中的位置）＋左文字（牌堆名，C_Spell.GetSpellName）＋右文字（PD.RowText：機率／位置·剩餘數／剩餘數）。
-- 條色照 PD.State（滿牌／用掉一部分／用完／漂移），暗底＝條色 × 0.25（同自訂列，自訂底色優先），狀態一變就地重上色。
--
-- 12.1：這個面板沒有 AuraContainer、不讀任何秘密值，不是保護框；但面板可能被錨在保護框上（錨定鏈），
-- 戰鬥中重排照自訂列那套（MustDefer／DeferRelayout）判斷，保險。值的重畫（SetValue、上色、SetText）戰鬥中照做。
--
-- 預覽（Options/ResourcePreview.lua 的 procdeck 模式）借 PDR.NewRow／LayoutRow／PaintRow 畫假資料。
--
-- 跟自訂列（custombars）的接線點逐一對過（grep custombars）：面板登記、DB 預設／PANEL_KEYS／PANEL_ORDER、STACK_RANK、顯示條件、
-- 設定頁分頁、恢復預設、預覽框、/mcdm debug、資源條樣式視窗的 Apply 都有對應；**沒接的兩處**：
--   * Core/Sound.lua 的光環音效登記（CB.SoundWants）：牌堆不做音效（觸發本身格子會亮、本來就有「出現」音效可用）
--   * Modules/AuraBar.lua：列是自己數的明文，不需要 AuraContainer
------------------------------------------------------------
local _, ns = ...

ns.ProcDeckRows = {}
local PDR = ns.ProcDeckRows

local KEY = "procdeck"
PDR.KEY = KEY

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
local function StyleCfg() return ns.DB and ns.DB.ConfigTable("resources") end
local function PD() return ns.ProcDeck end

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local TEXT_PAD = 3

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function SpellName(id)
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, n = pcall(fn, id)
        n = ok and Plain(n) or nil
        if type(n) == "string" and n ~= "" then return n end
    end
    return "#" .. tostring(id)
end
PDR.SpellName = SpellName

local function SpellIcon(id)
    local fn = C_Spell and C_Spell.GetSpellTexture
    if fn then
        local ok, t = pcall(fn, id)
        t = ok and Plain(t) or nil
        if t then return t end
    end
    return 134400
end
PDR.SpellIcon = SpellIcon

-- 字級照列高（同自訂列的自動字級）
local function TextSize(h)
    local v = h - 4
    if v < 8 then v = 8 elseif v > 30 then v = 30 end
    return v
end

------------------------------------------------------------
-- 一列（引擎與預覽框共用）
------------------------------------------------------------
function PDR.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.iconFrame = row:CreateTexture(nil, "BACKGROUND")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.bar = CreateFrame("Frame", nil, row)
    row.sb = CreateFrame("StatusBar", nil, row.bar)
    row.sb:SetAllPoints(row.bar)
    row.sb:SetMinMaxValues(0, 1)
    row.sb:SetValue(0)
    row.textFrame = CreateFrame("Frame", nil, row.bar)
    row.textFrame:SetAllPoints(row.bar)
    row.ticks = {}
    row.name = row.textFrame:CreateFontString(nil, "OVERLAY")
    row.value = row.textFrame:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ row.name, row.value }) do
        ns.Media.SetPixelFont(fs, 10, "OUTLINE")       -- 先給字型才能 SetText（樣式在排版時重套）
        fs:SetWordWrap(false)
    end
    row:Hide()
    return row
end

local function PlaceText(fs, parent, point, padPx, offY)
    fs:ClearAllPoints()
    fs:SetJustifyH(point)
    fs:SetPoint(point, parent, point, point == "LEFT" and padPx or -padPx, offY or 0)
end

-- 版面（樣式、尺寸、名字）。W 已經是 P.Scale 過的寬
function PDR.LayoutRow(row, def, s, style, W)
    local R, P = ns.Resources, ns.P
    local H = P.Scale(s.height)
    row:SetSize(W, H)
    local g = ns.CustomBars.Geometry(W, H, s.icon and "left" or "none", P.Pixel(1))
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local _, oy = R.TextOffset(style)
    local look = {
        texture = ns.Media.Texture(style.texture), bgTex = R.BgTexture(style),
        alpha = tonumber(style.barAlpha) or 1, bgA = R.BgAlpha(style), bgCustom = R.BgCustom(style),
        px = R.DecorPx(style), edge = R.EdgeArray(style),
        token = ns.Media.ElementFont(style.textFont, ns.Setting(nil, "font")), outline = R.TextOutline(style),
        size = TextSize(s.height), padPx = TEXT_PAD * scale, offY = oy, g = g, H = H,
    }
    row.look, row.def, row.s = look, def, s
    local lv = row:GetFrameLevel() or 1
    -- 圖示：框色＝邊框色、圖示內縮邊框粗細（同自訂列）
    if s.icon then
        row.iconFrame:ClearAllPoints()
        row.iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", g.iconX, 0)
        row.iconFrame:SetSize(g.iconW, H)
        local e = look.edge
        row.iconFrame:SetColorTexture(e[1], e[2], e[3], e[4])
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", look.px, -look.px)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -look.px, look.px)
        row.icon:SetTexture(SpellIcon(def.icon))
        row.iconFrame:Show()
        row.icon:Show()
    else
        row.iconFrame:Hide()
        row.icon:Hide()
    end
    row.bar:ClearAllPoints()
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", g.barX, 0)
    row.bar:SetSize(g.barW, H)
    row.sb:SetFrameLevel(lv + 2)
    row.sb:SetStatusBarTexture(look.texture)
    row.sb:SetMinMaxValues(0, def.size)
    row.textFrame:SetFrameLevel(lv + 12)
    -- 暗底與邊框：自訂列同一支（暗底在條身底下、邊框蓋在填色上）。顏色在 PaintRow 照狀態就地改
    ns.AuraBar.RowDecor(row.bar, { W = g.barW, H = H, n = 1, gap = 0, segW = g.barW, segments = false,
        reversed = false, dim = { 0, 0, 0, look.bgA }, px = look.px, edge = look.edge, bgTex = look.bgTex }, lv + 8)
    row.decorState = nil
    for _, fs in ipairs({ row.name, row.value }) do
        ns.Media.SetPixelFont(fs, look.size, look.outline, look.token)
    end
    row.name:SetWidth(math.max(1, (g.barW - 2 * TEXT_PAD) * 0.62) * scale)
    PlaceText(row.name, row.bar, "LEFT", look.padPx, look.offY)
    PlaceText(row.value, row.bar, "RIGHT", look.padPx, look.offY)
    if s.name then
        row.name:SetTextColor(1, 1, 1, 1)
        row.name:SetText(SpellName(def.name))
        row.name:Show()
    else
        row.name:SetText("")
        row.name:Hide()
    end
end

-- 值（翻到哪、顏色、刻度、右文字）
function PDR.PaintRow(row, st)
    local def, s, look = row.def, row.s, row.look
    if not (def and s and look and st) then return end
    local pd = PD()
    local state = pd.State(st, def)
    local r, g, b, a = pd.Color(s, state)
    row.sb:SetValue(st.drawn)
    local t = row.sb:GetStatusBarTexture()
    if t then t:SetVertexColor(r, g, b, (a or 1) * look.alpha) end
    if row.decorState ~= state then
        row.decorState = state
        local bc = look.bgCustom
        local dim = bc and { bc.r, bc.g, bc.b, look.bgA } or { r * 0.25, g * 0.25, b * 0.25, look.bgA }
        ns.AuraBar.RecolorRowDecor(row.bar, dim, look.edge, look.bgTex)
    end
    local n = 0
    if s.ticks and not st.drift then
        local W, H = look.g.barW, look.H
        for i, f in ipairs(pd.TickFractions(st, def)) do
            local tk = row.ticks[i]
            if not tk then
                tk = row.textFrame:CreateTexture(nil, "ARTWORK")
                tk:SetTexture(WHITE)
                tk:SetVertexColor(1, 1, 1, 1)
                row.ticks[i] = tk
            end
            tk:ClearAllPoints()
            tk:SetPoint("TOPLEFT", row.bar, "TOPLEFT", math.floor(W * f + 0.5), 0)
            tk:SetSize(ns.P.Pixel(1), H)
            tk:Show()
            n = i
        end
    end
    for i = n + 1, #row.ticks do row.ticks[i]:Hide() end
    if state == "drift" then row.value:SetTextColor(pd.DRIFT_COLOR.r, pd.DRIFT_COLOR.g, pd.DRIFT_COLOR.b, 1)
    else row.value:SetTextColor(1, 1, 1, 1) end
    row.value:SetText(pd.RowText(st, def, s.text, s.spend))
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
local container, root
local rows = {}                 -- 池化的列（frame 刪不掉）
local shown = 0
local planSig = ""
local pendingRelayout = false

local function Plans(style)
    local pd = PD()
    if not (pd and style) then return {} end
    local out = {}
    for _, item in ipairs(pd.Plan(style, ns.playerClass, ns.specID, "row")) do
        if pd.Talented(item.def) then out[#out + 1] = item end
    end
    return out
end
PDR.Plans = Plans

local function SigOf(plans)
    local t = {}
    for i, p in ipairs(plans) do t[i] = p.def.key end
    return table.concat(t, ",")
end

local function HideRows(from)
    for i = from, #rows do
        rows[i]:Hide()
        rows[i].def = nil
    end
end

-- 面板被錨在保護框上時，戰鬥中重排會被 ns.Write 記帳；這裡照自訂列的判斷延到脫戰，保險
local function MustDefer()
    return InCombatLockdown() and root ~= nil and ns.IsProtectedFrame and ns.IsProtectedFrame(root)
end

local Mark
local function OnRegenRelayout()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "procdeck_relayout")
    if pendingRelayout then
        pendingRelayout = false
        Mark(true)
    end
end

local function DeferRelayout()
    pendingRelayout = true
    ns.Events.Register("PLAYER_REGEN_ENABLED", "procdeck_relayout", OnRegenRelayout)
end

local function PaintAll()
    local pd = PD()
    for i = 1, shown do
        local row = rows[i]
        local st = row.def and pd.StateOf(row.def.key)
        if st then PDR.PaintRow(row, st) end
    end
end

local function Relayout(style, plans)
    local cfg = Cfg()
    local W = ns.P.Scale(ns.Resources.Width(style, KEY))
    local gap = ns.P.Scale(tonumber(style.rowSpacing) or 1)
    local heights = {}
    for i, p in ipairs(plans) do heights[i] = ns.P.Scale(p.s.height) end
    local offsets = ns.CustomBars.RowOffsets(heights, gap)
    local down = ns.CustomBars.Grow(cfg and cfg.anchor) == "down"
    for i, p in ipairs(plans) do
        local row = rows[i]
        if not row then
            row = PDR.NewRow(root)
            rows[i] = row
        end
        row:ClearAllPoints()
        if down then
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -offsets[i])
        else
            row:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, offsets[i])
        end
        row:SetAlpha(1)
        row:Show()
        PDR.LayoutRow(row, p.def, p.s, style, W)
    end
    HideRows(#plans + 1)
    shown = #plans
    planSig = SigOf(plans)
    ns.Bars.SetPanelSize(KEY, W, ns.CustomBars.PanelHeight(heights, gap))
end

-- force：重排（牌堆、樣式、寬度都可能變了）。不給 ＝ 只重畫值；要畫的牌堆換了照樣重排
function PDR.Update(force)
    if not root then return end
    local cfg, style = Cfg(), StyleCfg()
    local plans = (cfg and cfg.enabled ~= false) and Plans(style) or {}
    if not force and SigOf(plans) ~= planSig then force = true end
    if force then
        if MustDefer() then DeferRelayout() return end
        if plans[1] == nil then
            HideRows(1)
            shown, planSig = 0, ""
            ns.Bars.SetPanelSize(KEY, ns.P.Scale(ns.Resources.Width(style, KEY)), 0)
            return
        end
        Relayout(style, plans)
    end
    PaintAll()
end

-- 牌堆狀態變了（Modules/ProcDeck.lua 的 PD.Changed，已經是下一幀）
function PDR.Paint()
    PDR.Update(false)
end

local dirty, armed = false, false
local function Flush()
    armed = false
    local re = dirty
    dirty = false
    PDR.Update(re)
end

Mark = function(relayout)
    if relayout then dirty = true end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
PDR.Mark = Mark

------------------------------------------------------------
-- 初始化（ns.StartEngine：ProcDeck 之後）
------------------------------------------------------------
local function MinSize()
    local style = StyleCfg() or {}
    return ns.Resources.Width(style, KEY), ns.ProcDeck.HEIGHT_DEFAULT
end

function PDR.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "TOP",                  -- 貼在資源條下方、往下長，列數增減時上緣不動
        collapsible = true,                   -- 沒有列 ＝ 收合（不佔位）
        minSize     = MinSize,
        relayout    = function() PDR.Update(true) end,
    })
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    ns.RegisterCallback("FirstRowWidthChanged", KEY, function()
        local style = StyleCfg()
        if style and (tonumber(style.width) or 0) <= 0 then Mark(true) end
    end)
    ns.RegisterCallback("ProfileChanged", KEY, function() Mark(true) end)
    ns.RegisterCallback("SpecChanged", KEY, function() Mark(true) end)
    -- 錨定改了（設定頁、編輯模式拖了脫離錨定）：往上長還是往下長可能跟著變
    ns.RegisterCallback("AnchorChanged", KEY, function(key) if key == KEY then Mark(true) end end)
    ns.RegisterCallback("BarMoved", KEY, function(key) if key == KEY then Mark(true) end end)
    PDR.Update(true)
end

-- 設定頁改了值（牌堆的開關／樣式／高…、資源條的樣式、這裡的位置／錨定／淡出）：重排＋結構＋ alpha
function PDR.Apply()
    if not container then return end
    PDR.Update(true)
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function PDR.DebugLines()
    local out = {}
    if not container then
        out[1] = "  觸發牌堆列：沒有初始化"
        return out
    end
    local cfg = Cfg()
    local h = container.GetHeight and container:GetHeight()
    local a = type(cfg) == "table" and cfg.anchor
    local where = type(a) == "table" and ("錨 %s %s→%s"):format(tostring(a.to), tostring(a.point), tostring(a.relPoint)) or "自己的位置"
    out[#out + 1] = ("  觸發牌堆列：%s  顯示 %d 列（%s）  高 %s  %s（%s）  收合 %s  alpha %s%s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", shown, planSig, tostring(Plain(h)), where,
            ns.CustomBars.Grow(a) == "down" and "往下長" or "往上長",
            tostring(ns.Bars.IsCollapsed and ns.Bars.IsCollapsed(KEY)), tostring(ns.Visibility and ns.Visibility.Current(KEY)),
            pendingRelayout and "  （戰鬥中，重排延到脫戰）" or "")
    return out
end
