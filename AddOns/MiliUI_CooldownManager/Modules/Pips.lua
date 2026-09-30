------------------------------------------------------------
-- 自訂格子：玩家自己加的「法術充能／光環層數」列，一組一列（獨立面板，容器 MiliUICDM_Bar_pips）
--
-- 資料與樣式都借資源條的：
--   * 清單：profile.resources.customRows[specID]（每個專精一份，設定頁在資源條頁）
--   * 樣式：列高、列距、格距、材質、填充方向、填充透明度、寬度（0 ＝ 核心技能第一列）一律讀
--     profile.resources，不另開一組
--   * 自己的只有 profile.pips：enabled、pos、anchor、fadeWithEssential、strata
-- 預設錨在核心技能下方（anchor TOP → essential BOTTOM），輔助技能預設錨在這裡的下方：
-- 核心 → 自訂格子 → 輔助。沒有任何一列時容器高度 0（Bars 的 collapsible 面板：錨定的
-- y 偏移一起收掉），輔助就跟原本一樣貼在核心下方 1px；有列時輔助自動往下讓。
--
--   charges  法術充能：C_Spell.GetSpellCharges 的 currentCharges 直接餵每格的 SetValue；
--            每格底下一顆 Cooldown 吃 C_Spell.GetSpellChargeDuration 的 duration 物件
--            （轉圈與秒數由引擎畫）。層級：底色貼圖 → Cooldown（+1）→ 填色 StatusBar（+2），
--            滿的格子被填色蓋住，只有空格看得到轉圈 ⇒ 秘密值下照樣對。
--            所有空格顯示的是同一個「下一格回充」時間（引擎只給這一個 duration 物件）。
--   stacks   光環層數：C_UnitAuras.GetPlayerAuraBySpellID 的 applications 直接餵；沒有光環 ＝ 0。
--
-- 12.1 秘密值：值一律只轉手、不比較不算術（`x and v or 0` 這種會把秘密值當布林的式子一律改寫成 if）。
-- 格子一律錨在列上（不串在前一格）：SetValue(秘密值) 會讓填色條的幾何變秘密，錨在它身上的框會被傳染。
--
-- 事件（SPELL_UPDATE_CHARGES／COOLDOWN、UNIT_AURA）只在真的有那一種列時才註冊，處理器只標髒、
-- 下一幀做（ns.Defer）。清單／格數／尺寸變了（專精、天賦、法術書、設定）才重排。
------------------------------------------------------------
local _, ns = ...

ns.Pips = {}
local Pips = ns.Pips

local R = ns.Resources
local RC = ns.ResCond
local MAX_SEGMENTS = RC.MAX_SEGMENTS
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local DIM = R.DIM
local Plain = R.Plain

local KEY = "pips"

-- 自己的設定（位置、錨定、開關、淡出）與借來的樣式／清單（資源條那張表）
local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
local function StyleCfg() return ns.DB and ns.DB.ConfigTable("resources") end
Pips.Cfg, Pips.StyleCfg = Cfg, StyleCfg

------------------------------------------------------------
-- 清單與「要建哪些列」
--
--   resources.customRows[specID] = { { kind = "charges"|"stacks", spellID, max, color, showTime, enabled }, … }
--
-- 清單的讀寫與規劃都是純函式（吃 cfg、specID 與一個查詢 probe），離線測試得到。
-- cfg 是**資源條的設定表**（清單存在那裡）。
------------------------------------------------------------
local CUSTOM_KINDS = { charges = true, stacks = true }
Pips.CUSTOM_KINDS = CUSTOM_KINDS
Pips.CUSTOM_DEFAULT_STACKS = 5

-- 這個專精的清單；create ＝ 沒有就建（寫入用），否則沒有回 nil
function Pips.CustomRowList(cfg, specID, create)
    if type(cfg) ~= "table" or specID == nil then return nil end
    local all = cfg.customRows
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        cfg.customRows = all
    end
    local list = all[specID]
    if type(list) ~= "table" then
        if not create then return nil end
        list = {}
        all[specID] = list
    end
    return list
end

-- 同一個專精裡已經有同種類、同法術的列 → 它的位置
function Pips.FindCustomRow(cfg, specID, kind, spellID)
    for i, e in ipairs(Pips.CustomRowList(cfg, specID) or {}) do
        if type(e) == "table" and e.kind == kind and e.spellID == spellID then return i end
    end
    return nil
end

function Pips.AddCustomRow(cfg, specID, entry)
    if type(entry) ~= "table" or not CUSTOM_KINDS[entry.kind] then return nil end
    local list = Pips.CustomRowList(cfg, specID, true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

-- 刪掉第 i 筆；清單空了就把這個專精的鍵拿掉（存檔不留空表）
function Pips.RemoveCustomRow(cfg, specID, i)
    local list = Pips.CustomRowList(cfg, specID)
    if not (list and type(i) == "number" and list[i] ~= nil) then return false end
    table.remove(list, i)
    if list[1] == nil then cfg.customRows[specID] = nil end
    return true
end

local function ClampSegments(n)
    n = math.floor(tonumber(n) or 0)
    if n < 1 then return nil end
    return math.min(MAX_SEGMENTS, n)
end
Pips.ClampSegments = ClampSegments

-- 純函式：這個專精實際要建哪些自訂列。
--   probe.known(spellID)      → 充能法術學了沒（stacks 不問：沒有光環 ＝ 全空，列照顯示）
--   probe.maxCharges(spellID) → 明文的充能上限或 nil（讀不到／秘密值）
-- 回傳 { { index, entry, kind, spellID, numSeg }, … }，順序照清單；壞資料、enabled = false、
-- 未學會的充能法術都不建
function Pips.PlanCustomRows(cfg, specID, probe)
    local out = {}
    local list = Pips.CustomRowList(cfg, specID)
    if not list then return out end
    probe = probe or {}
    for i, e in ipairs(list) do
        if type(e) == "table" and CUSTOM_KINDS[e.kind] and type(e.spellID) == "number" and e.enabled ~= false then
            local n
            if e.kind == "charges" then
                if not probe.known or probe.known(e.spellID) then
                    -- 充能上限：API 讀得到就用它（天賦會改），讀不到才退回存檔的 max
                    local m = probe.maxCharges and probe.maxCharges(e.spellID)
                    n = ClampSegments(m) or ClampSegments(e.max) or 2
                end
            else
                n = ClampSegments(e.max) or Pips.CUSTOM_DEFAULT_STACKS
            end
            if n then
                out[#out + 1] = { index = i, entry = e, kind = e.kind, spellID = e.spellID, numSeg = n }
            end
        end
    end
    return out
end

-- 純函式：容器高度（沒有列 ＝ 0：輔助技能貼回核心下方）
function Pips.PanelHeight(n, H, gap)
    if not n or n <= 0 then return 0 end
    return n * H + (n - 1) * gap
end

-- 遊戲裡的 probe：學了沒（兩支 API 過 pcall；秘密值當學了，API 都不在也當學了）與
-- 充能上限（明文才收，順手記下來，秘密值下沿用上次的明文值）
local lastChargeMax = {}

local function CustomKnown(id)
    local book = C_SpellBook
    local any = false
    for _, fn in ipairs({ book and book.IsSpellKnown, book and book.IsSpellInSpellBook }) do
        if fn then
            any = true
            local ok, v = pcall(fn, id)
            if ok then
                if ns.IsSecret(v) then return true end
                if v then return true end
            end
        end
    end
    return not any
end

local function CustomMaxCharges(id)
    local fn = C_Spell and C_Spell.GetSpellCharges
    if fn then
        local ok, info = pcall(fn, id)
        if ok and type(info) == "table" then
            local ok2, m = pcall(function() return info.maxCharges end)
            if ok2 then m = Plain(m) else m = nil end
            if m and m > 0 then
                lastChargeMax[id] = m
                return m
            end
        end
    end
    return lastChargeMax[id]
end

local gameProbe = { known = CustomKnown, maxCharges = CustomMaxCharges }
Pips.gameProbe = gameProbe

-- 自訂列的顏色：存檔的色 → 職業色
local function CustomColor(entry)
    local c = RC.ValidColor(entry and entry.color)
    if c then return c.r, c.g, c.b end
    local r, g, b = ns.Style.Accent()
    return r, g, b
end
Pips.CustomColor = CustomColor

-- 自訂列的目前值（原始值，可能是秘密值）與回充的 duration 物件。讀不到回 nil
local function CustomValue(plan)
    if plan.kind == "stacks" then return R.AuraStacks(plan.spellID), nil end
    local fn = C_Spell and C_Spell.GetSpellCharges
    local cur
    if fn then
        local ok, info = pcall(fn, plan.spellID)
        if ok and type(info) == "table" then
            local ok2, v = pcall(function() return info.currentCharges end)
            if ok2 then cur = v end
        end
    end
    local dfn = C_Spell and C_Spell.GetSpellChargeDuration
    local dur
    if dfn then
        local ok, d = pcall(dfn, plan.spellID)
        if ok then dur = d end
    end
    return cur, dur
end
Pips.CustomValue = CustomValue

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local customRows = {}           -- 池化的列（frame 刪不掉；每格多一顆 Cooldown，格子懶建）

-- 一格：cell（底色貼圖）→ Cooldown（level +1）→ 填色 StatusBar（level +2，邊框也在它上面）。
-- 三層都錨在 cell 上、cell 錨在列上；錨在填色條上的只有它自己的邊框貼圖
-- （SetValue(秘密值) 會讓填色條的幾何變秘密）
local function MakeCustomCell(row)
    local cell = CreateFrame("Frame", nil, row)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetTexture(SOLID)
    cell.bg:SetAllPoints(cell)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, cell, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(cell)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, SOLID) end
        -- 暗色的扇形從空的一側長出來：「正在充回來」讀起來像在填這一格
        if cd.SetReverse then cd:SetReverse(true) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        -- ⚠ 先給字型（像素字型、跟數值文字同一套）；樣式在 LayoutCustomRow 依列高重套
        if fs then ns.Media.SetPixelFont(fs, 8, "OUTLINE") end
        cell.cd = cd
    end
    cell.bar = CreateFrame("StatusBar", nil, cell)
    cell.bar:SetAllPoints(cell)
    cell.bar:SetStatusBarTexture(SOLID)
    R.Edges(cell.bar)
    cell:Hide()
    return cell
end

local function MakeCustomRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.cells = {}                    -- 懶建：要幾格建幾格（frame 刪不掉，建了就留著重用）
    row:Hide()
    return row
end

-- style：資源條的設定表（樣式照它）
local function LayoutCustomRow(row, plan, style, W, H)
    local numSeg = plan.numSeg
    row:SetSize(W, H)
    row:SetAlpha(1)
    local reversed = ns.FillReversed(style)
    local tex = ns.Media.Texture(style.texture)
    local gap = ns.P.Scale(tonumber(style.segmentSpacing) or 1)
    local segW = ns.P.Scale((W - gap * (numSeg - 1)) / numSeg)
    local r, g, b = CustomColor(plan.entry)
    local alpha = tonumber(style.barAlpha) or 1
    local charges = plan.kind == "charges"
    local showTime = plan.entry.showTime ~= false
    local fontSize = math.max(8, R.RowHeight(style) - 4)
    local font = ns.Setting(nil, "font")
    local fmt = ns.Text and ns.Text.PlainFormatter and ns.Text.PlainFormatter(0)
    for i = 1, numSeg do
        local cell = row.cells[i]
        if not cell then
            cell = MakeCustomCell(row)
            row.cells[i] = cell
        end
        cell:SetSize(segW, H)
        cell:ClearAllPoints()
        local x = (i - 1) * (segW + gap)
        if reversed then
            cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        -- 層級每次重排都重設：父層的 strata／level 可能被結構套用改過
        local lv = cell:GetFrameLevel()
        cell.bg:SetTexture(tex)
        cell.bg:SetVertexColor(DIM.r, DIM.g, DIM.b, DIM.a)
        cell.bar:SetFrameLevel(lv + 2)
        cell.bar:SetStatusBarTexture(tex)
        cell.bar:SetMinMaxValues(i - 1, i)
        local t = cell.bar:GetStatusBarTexture()
        if t then t:SetVertexColor(r, g, b, alpha) end
        local cd = cell.cd
        if cd then
            if charges then
                cd:SetFrameLevel(lv + 1)
                -- 扇形用這一列顏色的暗版（跟連續條的空底同一個算法）
                if cd.SetSwipeColor then cd:SetSwipeColor(r * 0.25, g * 0.25, b * 0.25, 0.8) end
                if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not showTime) end
                local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
                if fs then
                    ns.Media.SetPixelFont(fs, fontSize, "OUTLINE", font)
                    fs:SetTextColor(1, 1, 1, 1)
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", cell, "CENTER", 0, 0)
                end
                if fmt and cd.SetCountdownFormatter then pcall(cd.SetCountdownFormatter, cd, fmt) end
                if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
                cd:Show()
            else
                -- 光環層數沒有 duration：不放 Cooldown
                cd:Clear()
                cd:Hide()
            end
        end
        cell:Show()
    end
    for i = numSeg + 1, #row.cells do
        local cell = row.cells[i]
        if cell.cd then cell.cd:Clear() end
        cell:Hide()
    end
end

local function UpdateCustomRow(row)
    local plan = row.plan
    if not plan then return end
    local cur, dur = CustomValue(plan)
    -- 只看型別（type() 回真實型別，不讀值）：秘密數字照樣是 "number"
    local readable = type(cur) == "number"
    local vs = "unreadable"
    if readable then
        if ns.IsSecret(cur) then vs = "secret" else vs = "plain" end
    end
    row.valueState = vs
    row:SetAlpha(readable and 1 or 0.5)
    local charges = plan.kind == "charges"
    for i = 1, plan.numSeg do
        local cell = row.cells[i]
        -- ⚠ 不能寫 `readable and cur or 0`：`or` 要判斷 cur 的真假，秘密值當布林用會拋錯
        if readable then cell.bar:SetValue(cur) else cell.bar:SetValue(0) end   -- 引擎決定這格亮多少，秘密值照樣對
        local cd = cell.cd
        if charges and cd then
            if dur then
                pcall(cd.SetCooldownFromDurationObject, cd, dur, true)
            else
                cd:Clear()
            end
        end
    end
end

------------------------------------------------------------
-- 重排與重畫
------------------------------------------------------------
local customShown = 0
local laidOut = false            -- 排過版了沒（false ＝ 下一次 Update 一定重排）
local customHas = { charges = false, stacks = false }
local SyncEvents                 -- 定義在事件那一段（前置宣告）

local function HideRows(from)
    for i = from, #customRows do
        local row = customRows[i]
        row:Hide()
        row.plan, row.valueState = nil, nil
        for _, cell in ipairs(row.cells) do
            if cell.cd then cell.cd:Clear() end
        end
    end
end

local function Relayout(style, W)
    local H = ns.P.Scale(R.RowHeight(style))
    local gap = ns.P.Scale(tonumber(style.rowSpacing) or 1)
    W = ns.P.Scale(W)
    local plans = Pips.PlanCustomRows(style, ns.specID, gameProbe)
    customHas.charges, customHas.stacks = false, false
    local prev
    for i, plan in ipairs(plans) do
        local row = customRows[i]
        if not row then
            row = MakeCustomRow(root)
            customRows[i] = row
        end
        row.plan = plan
        customHas[plan.kind] = true
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        end
        prev = row
        LayoutCustomRow(row, plan, style, W, H)
        row:Show()
    end
    HideRows(#plans + 1)
    customShown = #plans
    SyncEvents()
    ns.Bars.SetPanelSize(KEY, W, Pips.PanelHeight(#plans, H, gap))
end

local function UpdateRows()
    for i = 1, customShown do
        local ok, err = xpcall(UpdateCustomRow, ns.ReportError, customRows[i])
        if not ok then Pips.lastError = err end
    end
end

-- force：重排（清單、格數、尺寸設定、寬度都可能變了）。不給 ＝ 只重畫值（充能／光環事件走這條）
function Pips.Update(force)
    if not root then return end
    local cfg, style = Cfg(), StyleCfg()
    if not cfg or cfg.enabled == false or not style then
        HideRows(1)
        customShown = 0
        customHas.charges, customHas.stacks = false, false
        SyncEvents()
        laidOut = false
        -- 關著也收成高度 0：錨在這裡的輔助技能貼回核心下方
        ns.Bars.SetPanelSize(KEY, ns.P.Scale(R.Width(style)), 0)
        return
    end
    if force or not laidOut then
        Relayout(style, R.Width(style))
        laidOut = true
    end
    UpdateRows()
end

------------------------------------------------------------
-- 事件：只標髒，下一幀做
------------------------------------------------------------
local dirtyRelayout, dirtyValues, armed = false, false, false

local function Flush()
    armed = false
    local re, va = dirtyRelayout, dirtyValues
    dirtyRelayout, dirtyValues = false, false
    if re then
        Pips.Update(true)
    elseif va then
        Pips.Update(false)
    end
end

-- relayout：true ＝ 重算清單與重排；其他 ＝ 只重畫值
local function Mark(relayout)
    if relayout then dirtyRelayout = true else dirtyValues = true end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
Pips.Mark = Mark

-- 清單可能變的事件（法術學會／忘掉、天賦改了充能上限、換專精、進世界）
local RELAYOUT_EVENTS = {
    SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_ENTERING_WORLD = true,
}
-- 值的事件（很密）：只在有那一種列時才註冊
local CHARGE_EVENTS = { SPELL_UPDATE_CHARGES = true, SPELL_UPDATE_COOLDOWN = true }

local evFrame
local evCharges, evAura = false, false

local function OnEvent(_, event)
    Mark(RELAYOUT_EVENTS[event] == true)
end

-- 重排時對一次帳：充能列 → SPELL_UPDATE_CHARGES／COOLDOWN；層數列 → UNIT_AURA（player）
SyncEvents = function()
    if not evFrame then return end
    local wantCharges = customHas.charges and true or false
    if wantCharges ~= evCharges then
        evCharges = wantCharges
        for e in pairs(CHARGE_EVENTS) do
            if wantCharges then evFrame:RegisterEvent(e) else evFrame:UnregisterEvent(e) end
        end
    end
    local wantAura = customHas.stacks and true or false
    if wantAura ~= evAura then
        evAura = wantAura
        if wantAura then evFrame:RegisterUnitEvent("UNIT_AURA", "player") else evFrame:UnregisterEvent("UNIT_AURA") end
    end
end

local function RegisterEvents()
    if evFrame then return end
    evFrame = CreateFrame("Frame")
    evFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD" }) do
        evFrame:RegisterEvent(e)
    end
    evFrame:SetScript("OnEvent", OnEvent)
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Resources 之後）
------------------------------------------------------------
local function MinSize()
    local style = StyleCfg() or {}
    return R.Width(style), R.RowHeight(style)
end

function Pips.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "TOP",                  -- 貼在核心技能下方、往下長，列數增減時上緣不動
        collapsible = true,                   -- 沒有列 ＝ 高度 0、錨定的 y 偏移一起收掉
        minSize     = MinSize,
        relayout    = function() Pips.Update(true) end,
    })
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    RegisterEvents()
    ns.RegisterCallback("FirstRowWidthChanged", KEY, function()
        local style = StyleCfg()
        if style and (tonumber(style.width) or 0) <= 0 then Mark(true) end
    end)
    ns.RegisterCallback("ProfileChanged", KEY, function() Mark(true) end)
    ns.RegisterCallback("SpecChanged", KEY, function() Mark(true) end)
    Pips.Update(true)
end

-- 設定頁改了值（資源條頁：清單、樣式、這裡的位置／錨定／淡出）：重排＋結構＋ alpha
function Pips.Apply()
    if not container then return end
    Pips.Update(true)
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
-- 第 i 列的框（除錯與冒煙用；不是公開 API）
function Pips.RowFrame(i)
    if type(i) ~= "number" or i < 1 or i > customShown then return nil end
    return customRows[i]
end

local function AnchorText(cfg)
    local a = type(cfg) == "table" and cfg.anchor
    if type(a) == "table" and type(a.to) == "string" then
        return ("錨 %s %s→%s (%s, %s)"):format(a.to, tostring(a.point), tostring(a.relPoint), tostring(a.x), tostring(a.y))
    end
    local pos = type(cfg) == "table" and type(cfg.pos) == "table" and cfg.pos or {}
    return ("位置 %s (%s, %s)"):format(tostring(pos.point), tostring(pos.x), tostring(pos.y))
end

function Pips.DebugLines()
    local out = {}
    if not container then
        out[1] = "  自訂格子：沒有初始化"
        return out
    end
    local cfg, style = Cfg(), StyleCfg()
    local specID = ns.specID
    local list = Pips.CustomRowList(style, specID)
    local h = container.GetHeight and container:GetHeight()
    out[#out + 1] = ("  自訂格子：%s  專精 %s  清單 %d 筆  顯示 %d 列  高 %s  %s  alpha %s  事件 充能 %s／光環 %s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", tostring(specID), list and #list or 0, customShown,
                tostring(Plain(h)), AnchorText(cfg), tostring(ns.Visibility and ns.Visibility.Current(KEY)),
                evCharges and "開" or "關", evAura and "開" or "關")
    -- 清單裡每一筆都印（沒建列的寫原因）
    for i, e in ipairs(list or {}) do
        local row
        for j = 1, customShown do
            if customRows[j].plan and customRows[j].plan.index == i then row = customRows[j] end
        end
        local kind = type(e) == "table" and tostring(e.kind) or "?"
        local id = type(e) == "table" and tostring(e.spellID) or "?"
        if row then
            -- 值是不是秘密：用上一次更新時記的狀態（只看型別與 issecretvalue，不讀值）
            local vs = row.valueState
            local state = vs == "secret" and "秘密" or vs == "plain" and "明文" or vs == "unreadable" and "讀不到" or "—"
            out[#out + 1] = ("    自訂 %d. %-7s spellID %s  ×%d  值 %s")
                :format(i, kind, id, row.plan.numSeg, state)
        else
            local why
            if type(e) ~= "table" or not CUSTOM_KINDS[e.kind] or type(e.spellID) ~= "number" then why = "壞資料"
            elseif cfg and cfg.enabled == false then why = "自訂格子關著"
            elseif e.enabled == false then why = "關閉"
            elseif e.kind == "charges" and not CustomKnown(e.spellID) then why = "法術未學會"
            else why = "沒有建列" end
            out[#out + 1] = ("    （自訂 %d. %s spellID %s）%s"):format(i, kind, id, why)
        end
    end
    return out
end
