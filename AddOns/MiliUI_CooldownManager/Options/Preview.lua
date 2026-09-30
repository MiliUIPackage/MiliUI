------------------------------------------------------------
-- 設定頁的預覽（也是編輯器）
--
--   local pv = ns.Preview.Create(parent, key, width)   條頁建一次
--   pv:Refresh()                                       照目前設定重畫
--   ns.Preview.Refresh(key)                            設定改了（任何地方）叫這支
--
-- 畫的是**我們自己的假框**，不碰真實條：
--   * 真實尺寸：版面照 ns.Layout.Compute 算（每列上限、間距、兩列尺寸、成長方向），
--     比可用寬大就水平捲動，太高就垂直捲動（滾輪；有橫向溢出時 Shift＋滾輪橫捲）。
--   * 外觀走 ns.Decorate.ApplyPreview：跟真實條同一套邊框／縮放／轉圈色／文字樣式。
--   * 假資料：奇數格「冷卻中」（轉圈＋倒數「15」＋去飽和），偶數格就緒；技能印充能「2」、
--     增益印層數「2」；長條跑一個十五秒的循環（名字＝法術名、時間 15→0）。
--
-- 互動
--   左鍵點格         → 逐法術面板（Options/SpellPopover.lua）
--   中鍵點格         → 移除（從這條拿掉、不再顯示）。移除的不留在預覽上，要加回來按「＋」
--                      （暴雪清單上的法術記在 spells[spec].hidden、挑選器第一區列得到；自己加的項目整筆刪掉）
--   拖曳（門檻 3px） → 排序（spells[spec].order[key] 寫完整清單）；拖到左欄的自訂群組上
--                      ＝拉進那一群（groupOf），拖回原本的檢視器上＝清掉 groupOf
--   最右邊「＋」     → 挑選器（Options/Picker.lua）
-- 光環格（自訂項目 kind = "aura"）是固定前綴：cell.locked，蓋紅色半透明、拖不動、中鍵不藏，
-- 別的格也不能插到它們前面（插入線變紅）。左鍵照樣開逐法術面板。
-- 自訂項目（"c:<index>"）拖到左欄＝改它的 bar（圖示類的條都收，含四條檢視器）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Preview = {}
local Preview = ns.Preview

local WHITE     = "Interface\\BUTTONS\\WHITE8X8"
local QUESTION  = 134400
local PAD       = 10
local MAX_H     = 170
local MIN_H     = 56
local DRAG_MIN  = 3
local CYCLE     = 15
local AURA_SRC  = { buffs = true, buffbars = true }

local instances = {}

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Cursor(frame)
    local s = frame:GetEffectiveScale()
    if not s or s <= 0 then s = 1 end
    local x, y = GetCursorPosition()
    return x / s, y / s
end

local function BarCfg(key) return ns.DB.BarTable(key) end

-- 長條寬 0 ＝ 跟核心技能第一列同寬（跟 Bars 的算法同一條）
local function Sizing(key, bar)
    local layout = type(bar.layout) == "table" and bar.layout or {}
    if bar.kind ~= "bars" then return layout end
    local cfg = type(bar.bar) == "table" and bar.bar or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        local ess = BarCfg("essential")
        w = ess and ns.Layout.FirstRowWidth(#ns.Catalog.Bar("essential"), ess.layout) or 0
        if w <= 0 then w = (type(layout.size) == "table" and tonumber(layout.size.w)) or 200 end
    end
    local h = tonumber(cfg.height) or 20
    return { maxPerRow = 1, spacing = layout.spacing, grow = layout.grow, size = { w = w, h = h } }
end

local function SetupFont(fs, size)
    ns.Media.SetFont(fs, size or 12, "OUTLINE")
    fs:SetText("")
end

------------------------------------------------------------
-- 格子
------------------------------------------------------------
local function NewIconCell(canvas)
    local c = CreateFrame("Frame", nil, canvas)
    c:EnableMouse(true)
    c.Icon = c:CreateTexture(nil, "ARTWORK")
    c.Icon:SetAllPoints()
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, c, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, WHITE, 1, 1, 1, 1) end
        -- 循環：轉完一圈重來（自己的框，隨便掛）
        cd:SetScript("OnCooldownDone", function(self)
            if c.onCD and c:IsVisible() then self:SetCooldown(GetTime(), CYCLE) end
        end)
        c.Cooldown = cd
    end
    local ov = CreateFrame("Frame", nil, c)
    ov:SetAllPoints()
    ov:SetFrameLevel(c:GetFrameLevel() + 5)
    c.overlay = ov
    c.cdText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.cdText, 16)
    c.chargeText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.chargeText, 12)
    c.stackText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.stackText, 12)
    c.lock = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    c.lock:SetAllPoints()
    c.lock:SetTexture(WHITE)
    c.lock:SetVertexColor(0.8, 0.1, 0.1, 0.45)
    c.lock:Hide()
    c.kind = "icons"
    c.isPlus, c.hiddenItem, c.locked, c.dragging = false, false, false, false
    return c
end

local function NewBarCell(canvas)
    local c = CreateFrame("Frame", nil, canvas)
    c:EnableMouse(true)
    local icon = CreateFrame("Frame", nil, c)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Applications = icon:CreateFontString(nil, "OVERLAY")
    SetupFont(icon.Applications, 12)
    c.Icon = icon
    local bar = CreateFrame("StatusBar", nil, c)
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarTexture(WHITE)
    bar.BarBG = bar:CreateTexture(nil, "BACKGROUND")
    bar.Name = bar:CreateFontString(nil, "OVERLAY")
    SetupFont(bar.Name, 12)
    bar.Duration = bar:CreateFontString(nil, "OVERLAY")
    SetupFont(bar.Duration, 12)
    c.Bar = bar
    local ov = CreateFrame("Frame", nil, c)
    ov:SetAllPoints()
    ov:SetFrameLevel(c:GetFrameLevel() + 5)
    c.overlay = ov
    c.lock = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    c.lock:SetAllPoints()
    c.lock:SetTexture(WHITE)
    c.lock:SetVertexColor(0.8, 0.1, 0.1, 0.45)
    c.lock:Hide()
    c.kind = "bars"
    c.isPlus, c.hiddenItem, c.locked, c.dragging = false, false, false, false
    return c
end

local function NewPlusCell(canvas)
    local c = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    c:EnableMouse(true)
    W.Stylize(c, { 0.115, 0.115, 0.115, 1 }, { W.Accent(0.6) })
    local fs = c:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontTitle)
    fs:SetPoint("CENTER")
    fs:SetText("+")
    c.label = fs
    c.isPlus, c.hiddenItem, c.locked, c.dragging = true, false, false, false
    c:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.23, 0.23, 0.23, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Add spells to this bar"])
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.115, 0.115, 0.115, 1)
        GameTooltip:Hide()
    end)
    return c
end

------------------------------------------------------------
-- 寫入（本專精的 spells 表）
------------------------------------------------------------
local function Changed(level, ...)
    for i = 1, select("#", ...) do
        local k = select(i, ...)
        if k then Preview.Refresh(k) end
    end
    ns.Options.ApplyEngine(level or "membership")
end

function Preview.SetHidden(key, id, hidden)
    local sp = ns.DB.SpecSpells(true)
    if not sp or id == nil then return end
    sp.hidden[id] = hidden and true or nil
    Changed("membership", key)
end

-- 移除：從這條拿掉、不再顯示。對使用者只有這一個動作（設定面板上有什麼，畫面上就有什麼）：
--   * 暴雪清單上的法術 → 記進 spells[spec].hidden（暴雪那邊的清單我們不動；逐法術設定留著，加回來照舊）
--   * 自己用「＋」加的項目 → 整筆刪掉
-- 加回來一律走「＋」。
function Preview.Remove(key, id)
    if id == nil then return false end
    if ns.Catalog.IsCustom(id) then return Preview.RemoveCustom(key, id) end
    if ns.SpellPopover and ns.SpellPopover.Close then ns.SpellPopover.Close() end
    Preview.SetHidden(key, id, true)
    return true
end

-- 移除自訂項目（玩家自己用「＋」加的）：整筆刪掉，它的逐法術設定一起走。
function Preview.RemoveCustom(key, id)
    if not ns.Catalog.IsCustom(id) then return false end
    if ns.SpellPopover and ns.SpellPopover.Close then ns.SpellPopover.Close() end
    if not ns.DB.RemoveCustom(id) then return false end
    Preview.Refresh(key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(key) end
    ns.Options.ApplyEngine("membership")
    return true
end

-- 把 id 拉進 target（nil 或它原本的檢視器 ＝ 清掉 groupOf）
-- 自訂項目沒有「原本的檢視器」：直接改它的 bar
function Preview.MoveTo(id, target, fromKey)
    if ns.Catalog.IsCustom(id) then
        if not target or not ns.DB.SetCustomBar(id, target) then return end
        Changed("membership", fromKey, target)
        return
    end
    local sp = ns.DB.SpecSpells(true)
    if not sp or id == nil then return end
    local origin = ns.Catalog.SourceOf(id)
    if target == origin then target = nil end
    sp.groupOf[id] = target
    Changed("membership", fromKey, target or origin)
end

-- 拖到哪幾條上是合法的：同類型（長條只收長條）的自訂群組，以及它原本的檢視器
function Preview.DropCandidates(key, id)
    local out = {}
    if ns.Catalog.IsCustom(id) then
        -- 自訂項目：任何一條圖示類的條（長條的 item 是另一種框，放不進去）
        local p = ns.profile
        for k, bar in pairs(p and p.bars or {}) do
            if k ~= key and type(bar) == "table" and bar.kind ~= "bars" then out[k] = true end
        end
        return out
    end
    local origin = ns.Catalog.SourceOf(id)
    local originBar = origin and BarCfg(origin)
    local wantBars = originBar and originBar.kind == "bars"
    local p = ns.profile
    for k, bar in pairs(p and p.bars or {}) do
        if k ~= key and type(bar) == "table" and not ns.DB.IsBuiltinBar(k)
            and (bar.kind == "bars") == (wantBars and true or false) then
            out[k] = true
        end
    end
    if origin and origin ~= key then out[origin] = true end
    return out
end

------------------------------------------------------------
-- 預覽物件
------------------------------------------------------------
local Proto = {}
Proto.__index = Proto

function Preview.Create(parent, key, width)
    local pv = setmetatable({ key = key, width = width, cells = { icons = {}, bars = {} }, used = {} }, Proto)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Stylize(f, { 0.06, 0.06, 0.06, 1 }, { 0, 0, 0, 1 })
    P.Size(f, width, MIN_H)
    pv.frame = f

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 1, -1)
    scroll:SetPoint("BOTTOMRIGHT", -1, 1)
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetSize(width, MIN_H)
    scroll:SetScrollChild(canvas)
    pv.scroll, pv.canvas = scroll, canvas

    -- 橫向捲軸（溢出才出現）：細條＋職業色拇指
    local hbar = CreateFrame("Slider", nil, f, "BackdropTemplate")
    hbar:SetOrientation("HORIZONTAL")
    hbar:SetPoint("BOTTOMLEFT", 2, 2)
    hbar:SetPoint("BOTTOMRIGHT", -2, 2)
    hbar:SetHeight(6)
    W.Stylize(hbar, { 0.115, 0.115, 0.115, 1 }, { 0, 0, 0, 1 })
    local thumb = hbar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(W.Accent(0.8))
    thumb:SetSize(40, 6)
    hbar:SetThumbTexture(thumb)
    hbar:SetMinMaxValues(0, 0)
    hbar:SetValueStep(1)
    hbar:SetScript("OnValueChanged", function(_, v) scroll:SetHorizontalScroll(v) end)
    hbar:Hide()
    pv.hbar = hbar

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local maxX = pv.maxX or 0
        local maxY = pv.maxY or 0
        if maxX > 0 and (maxY <= 0 or IsShiftKeyDown()) then
            local v = math.min(maxX, math.max(0, (scroll:GetHorizontalScroll() or 0) - delta * 40))
            hbar:SetValue(v)
        elseif maxY > 0 then
            scroll:SetVerticalScroll(math.min(maxY, math.max(0, (scroll:GetVerticalScroll() or 0) - delta * 30)))
        end
    end)

    -- 插入位置的職業色線、拖曳中的鬼影
    local line = canvas:CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetTexture(WHITE)
    line:Hide()
    pv.line = line

    -- 長條的十五秒循環（只在顯示中跑）
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.05 then return end
        acc = 0
        pv:Tick()
    end)

    instances[key] = pv
    return pv
end

function Preview.Refresh(key)
    local pv = instances[key]
    if pv and pv.frame:IsVisible() then pv:Refresh() end
end

-- 引擎那邊「畫不出來的格子」變了：預覽跟著重畫
ns.RegisterCallback("MissingChanged", "preview", function(key) Preview.Refresh(key) end)

function Preview.RefreshAll()
    for _, pv in pairs(instances) do
        if pv.frame:IsVisible() then pv:Refresh() end
    end
end

function Proto:Height()
    return self.frame:GetHeight() or MIN_H
end

function Proto:Acquire(kind)
    local pool = self.cells[kind]
    local n = (self.used[kind] or 0) + 1
    self.used[kind] = n
    local c = pool[n]
    if not c then
        c = kind == "bars" and NewBarCell(self.canvas) or NewIconCell(self.canvas)
        pool[n] = c
        self:Wire(c)
    end
    return c
end

function Proto:Refresh()
    local key = self.key
    local bar = BarCfg(key)
    for _, pool in pairs(self.cells) do for _, c in ipairs(pool) do c:Hide() end end
    self.used = {}
    if not bar then return end
    local kind = bar.kind == "bars" and "bars" or "icons"
    self.kind = kind

    -- 移除的不畫在預覽上（要加回來按「＋」）：預覽上有什麼，畫面上就有什麼
    local visible, hidden = ns.Catalog.Bar(key, true)
    hidden = hidden or {}
    local entries = {}
    for _, id in ipairs(visible) do entries[#entries + 1] = { id = id } end
    entries[#entries + 1] = { plus = true }
    self.count, self.hiddenCount = #visible, #hidden

    local sizing = Sizing(key, bar)
    local rects, totalW, totalH = ns.Layout.Compute(entries, sizing, kind)

    -- 視窗：寬固定（頁面寬），高跟著內容、上限 MAX_H；內容比較窄時置中
    local viewW = self.width
    local contentW, contentH = totalW + PAD * 2, totalH + PAD * 2
    local viewH = math.max(MIN_H, math.min(MAX_H, contentH + 2))
    local ox = contentW < viewW and math.floor((viewW - totalW) / 2) or PAD
    self.maxX = math.max(0, contentW - viewW + 2)
    self.maxY = math.max(0, contentH - viewH + 2)
    if self.maxX > 0 then viewH = math.min(MAX_H + 8, viewH + 8) end   -- 讓出捲軸那一條
    P.Size(self.frame, viewW, viewH)
    self.canvas:SetSize(math.max(viewW, contentW), math.max(viewH, contentH))
    self.hbar:SetShown(self.maxX > 0)
    self.hbar:SetMinMaxValues(0, self.maxX)
    if self.maxX <= 0 then self.scroll:SetHorizontalScroll(0) end
    if self.maxY <= 0 then self.scroll:SetVerticalScroll(0) end

    local now = GetTime()
    self.slots = {}
    self.hasLocked = false
    local lockedCount = 0
    for i, e in ipairs(entries) do
        local r = rects[i]
        local c
        if e.plus then
            c = self.plus
            if not c then
                c = NewPlusCell(self.canvas)
                self.plus = c
                self:Wire(c)
            end
        else
            c = self:Acquire(kind)
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", ox + r.x, -(PAD + r.y))
        c:SetSize(r.w, r.h)
        c.id, c.hiddenItem, c.index = e.id, e.hidden and true or false, i
        c.locked = false        -- 光環格的固定前綴由 Fill 設
        if not e.plus then
            self:Fill(c, e, i, r, now)
            if c.locked then
                self.hasLocked = true
                if not e.hidden then lockedCount = lockedCount + 1 end
            end
            if not e.hidden then self.slots[#self.slots + 1] = c end
        end
        -- 清單上有、暴雪卻沒給框的：畫面上不會有，這裡標暗（提示有說明），不要假裝它在
        c.missing = (not e.plus and ns.Bars and ns.Bars.IsMissing and ns.Bars.IsMissing(key, e.id)) and true or false
        c:SetAlpha((e.hidden or c.missing) and 0.35 or 1)
        c:Show()
    end
    self.lockedCount = lockedCount
    if self.onRefresh then self.onRefresh(self) end
end

function Proto:Fill(c, e, i, r, now)
    local key, id = self.key, e.id
    local info = ns.Catalog.Info(id)
    local tex = (info and info.icon) or QUESTION
    if info and info.custom then
        c.aura = info.kind == "aura"
        c.locked = c.aura
        c.custom, c.known = info.kind, info.isKnown ~= false
    else
        local src = ns.Catalog.SourceOf(id)
        c.aura = AURA_SRC[src] and true or false
        c.custom, c.known = false, true    -- false 不是 nil：格子是池化的框，欄位要明確蓋掉
    end
    c.onCD = (not c.aura) and (i % 2 == 1) and not e.hidden
    c.name = (info and info.name) or ("#" .. tostring(id))
    c.decorated = nil
    if c.kind == "bars" then
        c.Icon.Icon:SetTexture(tex)
        c.cycleOffset = (i * 3) % CYCLE
    else
        c.Icon:SetTexture(tex)
        if c.Cooldown then
            if c.onCD then
                c.Cooldown:SetCooldown(now - ((i * 2) % CYCLE), CYCLE)
            else
                c.Cooldown:Clear()
            end
        end
    end
    ns.Decorate.ApplyPreview(c, key, id, r.w, r.h)
    if c.kind == "bars" then
        c.Bar.Name:SetText(c.name)
        c.Icon.Applications:SetText("2")
    else
        c.cdText:SetText("15")
        c.chargeText:SetText("2")
        c.stackText:SetText("2")
    end
    c.lock:SetShown(c.locked and true or false)
end

-- 長條的時間跑 15→0（名字＝法術名；小數門檻照設定）
function Proto:Tick()
    if self.kind ~= "bars" then return end
    local pool = self.cells.bars
    local now = GetTime()
    local dec = tonumber(ns.Setting(self.key, "cooldownText.decimalsBelow")) or 0
    for n = 1, self.used.bars or 0 do
        local c = pool[n]
        if c and c:IsShown() then
            local left = CYCLE - ((now + (c.cycleOffset or 0)) % CYCLE)
            c.Bar:SetValue(left / CYCLE)
            if left < dec then
                c.Bar.Duration:SetFormattedText("%.1f", left)
            else
                c.Bar.Duration:SetFormattedText("%d", math.ceil(left))
            end
        end
    end
end

------------------------------------------------------------
-- 滑鼠：點、中鍵、拖曳
------------------------------------------------------------
local ghost
local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(32, 32)
    ghost.tex = ghost:CreateTexture(nil, "ARTWORK")
    ghost.tex:SetAllPoints()
    ghost:SetAlpha(0.8)
    ghost:Hide()
    return ghost
end

local function ShowTip(c)
    if c.isPlus or c.dragging then return end
    GameTooltip:SetOwner(c, "ANCHOR_TOP")
    GameTooltip:SetText(c.name or "")
    if c.custom and not c.known then
        GameTooltip:AddLine(L["Not learned"], 1, 0.3, 0.3)
    end
    if c.missing then
        GameTooltip:AddLine(L["Blizzard's Cooldown Manager isn't showing this one right now, so it can't appear on the bar."], 1, 0.3, 0.3, true)
        local info = ns.Catalog.Info(c.id)
        if info and info.equipSlot then
            GameTooltip:AddLine(L["Blizzard's trinket tracking is unreliable. To track a trinket, add it with \"Item\" and its item ID instead."], 1, 0.82, 0, true)
        end
    end
    if c.locked then
        GameTooltip:AddLine(L["Aura slot: always at the front of the bar, can't be dragged."], 1, 0.82, 0, true)
        GameTooltip:AddLine(L["Left-click: settings for this spell"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Middle-click: remove"], 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(L["Left-click: settings for this spell"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Middle-click: remove"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Drag: reorder, or drop on a group on the left"], 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

function Proto:Wire(c)
    local pv = self
    if not c.isPlus then
        c:SetScript("OnEnter", ShowTip)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    c:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or self.isPlus or self.hiddenItem or self.locked then return end
        local x, y = Cursor(pv.canvas)
        pv.press = { cell = self, x = x, y = y }
        pv.frame:SetScript("OnUpdate", function(_, elapsed) pv:DragTick(elapsed) end)
    end)
    c:SetScript("OnMouseUp", function(self, button)
        local press = pv.press
        if press and press.dragging then pv:EndDrag(true) return end
        pv.press = nil
        pv:RestoreTicker()
        -- 拖曳剛在 OnUpdate 那邊收掉（放手的那一幀先跑到 DragTick）：這一下不算點擊
        if pv.dragEnded and GetTime() - pv.dragEnded < 0.2 then return end
        if not self:IsMouseOver() then return end
        if self.isPlus then
            if button == "LeftButton" and ns.Picker then ns.Picker.Open(pv.key, self) end
        elseif button == "MiddleButton" then
            -- 中鍵＝移除（不問）。要的話再按「＋」加回來
            GameTooltip:Hide()
            Preview.Remove(pv.key, self.id)
        elseif button == "LeftButton" then
            if ns.SpellPopover then ns.SpellPopover.Open(pv.key, self.id, self) end
        end
    end)
end

function Proto:RestoreTicker()
    local pv = self
    local acc = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.05 then return end
        acc = 0
        pv:Tick()
    end)
end

function Proto:BeginDrag()
    local press = self.press
    local c = press.cell
    press.dragging = true
    c.dragging = true
    GameTooltip:Hide()
    local g = Ghost()
    local info = ns.Catalog.Info(c.id)
    g.tex:SetTexture((info and info.icon) or QUESTION)
    g:Show()
    for _, s in ipairs(self.slots) do
        if s ~= c then s:SetAlpha(0.5) end
    end
    c:SetAlpha(0.25)
    press.candidates = Preview.DropCandidates(self.key, c.id)
    ns.Sidebar.BeginDrop(press.candidates)
end

-- 游標底下的插入位置：離游標最近的格，決定插在它前面或後面
function Proto:InsertionAt()
    if not self.frame:IsMouseOver() then return nil end
    local cx, cy = Cursor(self.canvas)
    local best, bestD
    for i, s in ipairs(self.slots) do
        local x, y = s:GetCenter()
        if x then
            local d = (x - cx) ^ 2 + (y - cy) ^ 2
            if not bestD or d < bestD then best, bestD = i, d end
        end
    end
    if not best then return nil end
    local s = self.slots[best]
    local x, y = s:GetCenter()
    local after
    if self.kind == "bars" then after = cy < y else after = cx > x end
    return best + (after and 1 or 0), s, after
end

function Proto:DragTick()
    local press = self.press
    if not press then return end
    if not IsMouseButtonDown("LeftButton") then
        if press.dragging then self:EndDrag(true) else self.press = nil; self:RestoreTicker() end
        return
    end
    local x, y = Cursor(self.canvas)
    if not press.dragging then
        if math.abs(x - press.x) < DRAG_MIN and math.abs(y - press.y) < DRAG_MIN then return end
        self:BeginDrag()
    end
    local g = Ghost()
    local ux, uy = Cursor(UIParent)
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux + 12, uy - 12)

    local line = self.line
    if ns.Sidebar.DropTargetAtCursor() then
        line:Hide()
        press.pos = nil
        return
    end
    local pos, s, after = self:InsertionAt()
    press.pos = pos
    if not pos then line:Hide() return end
    local invalid = pos <= (self.lockedCount or 0)
    press.invalid = invalid
    if invalid then line:SetVertexColor(1, 0.2, 0.2, 1) else line:SetVertexColor(W.Accent(1)) end
    line:ClearAllPoints()
    local t = P.Scale(2)
    if self.kind == "bars" then
        line:SetPoint(after and "TOPLEFT" or "BOTTOMLEFT", s, after and "BOTTOMLEFT" or "TOPLEFT", 0, after and -1 or 1)
        line:SetSize(s:GetWidth(), t)
    else
        line:SetPoint(after and "TOPLEFT" or "TOPRIGHT", s, after and "TOPRIGHT" or "TOPLEFT", after and 1 or -1, 0)
        line:SetSize(t, s:GetHeight())
    end
    line:Show()
end

function Proto:EndDrag(commit)
    local press = self.press
    self.press = nil
    self:RestoreTicker()
    self.line:Hide()
    if ghost then ghost:Hide() end
    if not (press and press.dragging) then return end
    self.dragEnded = GetTime()
    local c = press.cell
    c.dragging = false
    local target = ns.Sidebar.DropTargetAtCursor()
    ns.Sidebar.EndDrop()
    if not commit then self:Refresh() return end
    if target and press.candidates and press.candidates[target] then
        Preview.MoveTo(c.id, target, self.key)
        return
    end
    local pos = press.pos
    if not pos or press.invalid then self:Refresh() return end
    -- 新順序：可見的照畫面順序、拖的那顆移到插入位置；隱藏的接在後面
    local ids, from = {}, nil
    for i, s in ipairs(self.slots) do
        ids[i] = s.id
        if s == c then from = i end
    end
    if not from then self:Refresh() return end
    if pos == from or pos == from + 1 then self:Refresh() return end
    table.remove(ids, from)
    if pos > from then pos = pos - 1 end
    table.insert(ids, pos, c.id)
    local _, hidden = ns.Catalog.Bar(self.key, true)
    for _, id in ipairs(hidden or {}) do ids[#ids + 1] = id end
    local sp = ns.DB.SpecSpells(true)
    if not sp then self:Refresh() return end
    sp.order[self.key] = ids
    Changed("membership", self.key)
end
