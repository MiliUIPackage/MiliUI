------------------------------------------------------------
-- 拖拉式的時間軸編輯器（自訂時間軸分頁的「時間軸」檢視）
--
--   ┌────────┬──────────────────────────────────────────── 0:00  0:30  1:00 …（尺規，跟著橫向捲）
--   │我的提示 │  ▕▔▔▔▔▔▔[圖]文字        ▕▔▔▔[圖]…            （可拖、可點、右鍵選單）
--   │[圖]技能A│     ■        ■         ■                    （MRT：每次施放一格，點了以此新增）
--   │[圖]技能B│          ■         ■                            …
--   │上一場   │   ·  ·   ·    ·                              （上一場紀錄，灰點）
--   └────────┴── 換階段：整欄一條直線＋「P2」
--
-- 我的提示畫成「從出現在時間軸上（t − lead）到發生（t）」的一條，右端是圖示＋文字 ——
-- 一眼看得出提示會提前多久跳出來、會不會跟別條疊在一起。重疊的自動往下排成子列。
--
-- 操作：
--   拖我的提示     改時間（0.5 秒吸附；按住 Shift 不吸附）。錨在首領技能上的，偏移跟著改
--   點我的提示     開編輯視窗；右鍵：編輯／停用／刪除
--   點 MRT 的格子  以這一次施放新增，並錨在「這個技能第 N 次施放」上
--   雙擊我的提示列的空白處   在那一秒新增
--   滾輪           左右捲；Ctrl＋滾輪 縮放（也可以拖右上角的縮放滑桿）
--
-- 版面：左邊標籤欄固定、右邊畫布橫向捲動；列多的時候整塊（標籤＋畫布）一起直向捲。
-- 尺規在直向捲動之外（永遠看得到），但跟畫布共用橫向的位移。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Plans = ns.Plans
local MD = ns.MRTData

ns.PlanEditor = {}
local PE = ns.PlanEditor

local GUTTER   = 130     -- 左邊標籤欄寬
local RULER_H  = 20
local LANE_H   = 22      -- MRT／上一場的列高
local MINE_H   = 22      -- 我的提示每一子列的高
local PAD_END  = 30      -- 時間軸尾端多留幾秒
local SNAP     = 0.5
local DRAG_PX  = 4
local ZOOM_MIN, ZOOM_MAX = 1.5, 16

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return t
end

local function Font(parent, small)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(small and W.fontSmall or W.fontNormal)
    fs:SetWordWrap(false)
    return fs
end

-- 物件池：每次重畫只是把用到的拿出來、沒用到的藏起來
local function Pool(create)
    local p = { items = {}, used = 0 }
    function p:Reset() self.used = 0 end
    function p:Get()
        self.used = self.used + 1
        local it = self.items[self.used]
        if not it then
            it = create()
            self.items[self.used] = it
        end
        it:Show()
        return it
    end
    function p:HideRest()
        for i = self.used + 1, #self.items do self.items[i]:Hide() end
    end
    return p
end

local function CursorX()
    local x = GetCursorPosition()
    return x / UIParent:GetEffectiveScale()
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
function PE.Create(parent, width, height, hooks)
    local ed = { hooks = hooks or {}, pps = 5, scrollX = 0, planID = nil }
    local root = CreateFrame("Frame", nil, parent)
    root:SetSize(width, height)
    ed.frame = root

    local canvasW = width - GUTTER - 14      -- 14：直向捲軸

    -- 尺規（不跟著直向捲）
    local rulerClip = CreateFrame("Frame", nil, root)
    rulerClip:SetPoint("TOPLEFT", GUTTER, 0)
    rulerClip:SetSize(canvasW, RULER_H)
    rulerClip:SetClipsChildren(true)
    local ruler = CreateFrame("Frame", nil, rulerClip)
    ruler:SetPoint("TOPLEFT")
    ruler:SetSize(1, RULER_H)
    ed.ruler = ruler
    Tex(rulerClip, "BACKGROUND", 0.12, 0.12, 0.12, 1):SetAllPoints()

    -- 直向捲動區：標籤欄＋畫布
    local holder = CreateFrame("Frame", nil, root)
    holder:SetPoint("TOPLEFT", 0, -RULER_H)
    holder:SetPoint("BOTTOMRIGHT", 0, 14)       -- 14：底下的橫向捲軸
    local vscroll = W.CreateScrollFrame(holder)
    ed.vscroll = vscroll
    local body = CreateFrame("Frame", nil, vscroll.child)
    body:SetPoint("TOPLEFT")
    body:SetSize(width - 14, 1)
    ed.body = body

    local gutter = CreateFrame("Frame", nil, body)
    gutter:SetPoint("TOPLEFT")
    gutter:SetSize(GUTTER, 1)
    ed.gutter = gutter

    local clip = CreateFrame("Frame", nil, body)
    clip:SetPoint("TOPLEFT", GUTTER, 0)
    clip:SetSize(canvasW, 1)
    clip:SetClipsChildren(true)
    ed.clip = clip
    local canvas = CreateFrame("Frame", nil, clip)
    canvas:SetPoint("TOPLEFT")
    canvas:SetSize(1, 1)
    ed.canvas = canvas
    ed.canvasW = canvasW

    -- 橫向捲軸
    local hbar = CreateFrame("Slider", nil, root, "BackdropTemplate")
    hbar:SetOrientation("HORIZONTAL")
    hbar:SetPoint("BOTTOMLEFT", GUTTER, 2)
    hbar:SetSize(canvasW, 8)
    W.Stylize(hbar, { 0.12, 0.12, 0.12, 1 })
    local thumb = hbar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(W.Accent(0.8))
    thumb:SetSize(40, 8)
    hbar:SetThumbTexture(thumb)
    hbar:SetMinMaxValues(0, 0)
    hbar:SetValueStep(1)
    hbar:SetScript("OnValueChanged", function(_, v)
        if math.abs(v - ed.scrollX) >= 0.5 then
            ed.scrollX = v
            ed:ApplyScroll()
        end
    end)
    ed.hbar, ed.thumb = hbar, thumb

    -- 縮放滑桿（尺規左邊那格）
    local zoomLbl = Font(root, true)
    zoomLbl:SetPoint("TOPLEFT", 4, -4)
    zoomLbl:SetText(L["Zoom"])
    local zoom = CreateFrame("Slider", nil, root, "BackdropTemplate")
    zoom:SetOrientation("HORIZONTAL")
    zoom:SetPoint("LEFT", zoomLbl, "RIGHT", 6, 0)
    zoom:SetSize(GUTTER - 50, 8)
    W.Stylize(zoom, { 0.12, 0.12, 0.12, 1 })
    local zthumb = zoom:CreateTexture(nil, "OVERLAY")
    zthumb:SetTexture(WHITE)
    zthumb:SetVertexColor(W.Accent(0.8))
    zthumb:SetSize(8, 10)
    zoom:SetThumbTexture(zthumb)
    zoom:SetMinMaxValues(ZOOM_MIN, ZOOM_MAX)
    zoom:SetValueStep(0.5)
    zoom:SetObeyStepOnDrag(true)
    zoom:SetScript("OnValueChanged", function(_, v)
        if math.abs(v - ed.pps) > 0.01 then ed:SetZoom(v) end
    end)
    ed.zoom = zoom

    -- 滾輪：左右捲；Ctrl＋滾輪縮放（以游標所在的秒數為中心）
    local function OnWheel(_, delta)
        if IsControlKeyDown() then
            local left = clip:GetLeft()
            local anchorSec = left and ((CursorX() - left + ed.scrollX) / ed.pps) or nil
            ed:SetZoom(ed.pps * (delta > 0 and 1.25 or 0.8), anchorSec)
        else
            ed:SetScroll(ed.scrollX - delta * 80)
        end
    end
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", OnWheel)
    rulerClip:EnableMouseWheel(true)
    rulerClip:SetScript("OnMouseWheel", OnWheel)

    -- 物件池
    ed.pools = {
        tick = Pool(function()
            local t = Tex(canvas, "BACKGROUND", 1, 1, 1, 0.06)
            return t
        end),
        rulerTick = Pool(function() return Tex(ruler, "ARTWORK", 1, 1, 1, 0.35) end),
        rulerLabel = Pool(function() return Font(ruler, true) end),
        laneBg = Pool(function() return Tex(canvas, "BACKGROUND", 1, 1, 1, 0.03) end),
        gutterLabel = Pool(function()
            local f = CreateFrame("Frame", nil, gutter)
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetSize(16, 16)
            f.icon:SetPoint("LEFT", 4, 0)
            f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f.text = Font(f, true)
            f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
            f.text:SetPoint("RIGHT", -4, 0)
            f.text:SetJustifyH("LEFT")
            return f
        end),
        phase = Pool(function()
            local f = CreateFrame("Frame", nil, canvas)
            f.line = Tex(f, "ARTWORK", 1, 0.82, 0, 0.5)
            f.line:SetAllPoints()
            f.text = Font(f, true)
            f.text:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, -1)
            f.text:SetTextColor(1, 0.82, 0)
            return f
        end),
        mark = Pool(function() return ed:NewMark() end),
        block = Pool(function() return ed:NewBlock() end),
        dot = Pool(function() return ed:NewDot() end),
        ghost = Pool(function() return ed:NewGhost() end),
    }

    -- 我的提示列：雙擊空白處新增
    local mineHit = CreateFrame("Button", nil, canvas)
    mineHit:RegisterForClicks("LeftButtonUp")
    mineHit:SetScript("OnDoubleClick", function()
        local left = canvas:GetLeft()
        if not left then return end
        local t = (CursorX() - left) / ed.pps
        t = math.max(SNAP, math.floor(t / SNAP + 0.5) * SNAP)
        if ed.hooks.onAdd then ed.hooks.onAdd({ t = t }) end
    end)
    mineHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(L["Double-click to add a reminder here"], 1, 1, 1)
        GameTooltip:Show()
    end)
    mineHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ed.mineHit = mineHit

    zoom:SetValue(ed.pps)
    return setmetatable(ed, { __index = PE })
end

------------------------------------------------------------
-- 元件
------------------------------------------------------------
local function ShowTip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    for i, l in ipairs(lines) do
        if i == 1 then GameTooltip:SetText(l, 1, 1, 1) else GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

-- MRT 的一次施放：點了以此新增（錨在第 N 次）
function PE:NewMark()
    local ed = self
    local b = CreateFrame("Button", nil, self.canvas)
    b:SetSize(14, 14)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = Font(b, true)
    b.count:SetPoint("BOTTOMRIGHT", 3, -2)
    b:SetScript("OnEnter", function(self)
        local ev = self.ev
        ShowTip(self, {
            ("%s  #%d"):format(ev.name or ("#" .. ev.spell), self.n),
            Plans.FormatTime(ev.t) .. (ev.cast and ("  " .. L["Cast %.1fs"]:format(ev.cast)) or "")
                .. (ev.count > 1 and ("  x" .. ev.count) or ""),
            L["Click to add a reminder that follows this cast"],
        })
        self.icon:SetVertexColor(1, 1, 1)
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.icon:SetVertexColor(0.85, 0.85, 0.85)
    end)
    b:SetScript("OnClick", function(self)
        if ed.hooks.onAdd then
            ed.hooks.onAdd({
                t = self.ev.t, spell = self.ev.spell,
                anchor = { spell = self.ev.spell, n = self.n, offset = 0 },
                anchorName = self.ev.name,
            })
        end
    end)
    return b
end

-- 上一場紀錄的一個點
function PE:NewDot()
    local ed = self
    local b = CreateFrame("Button", nil, self.canvas)
    b:SetSize(8, 8)
    b.tex = Tex(b, "ARTWORK", 0.6, 0.6, 0.6, 1)
    b.tex:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        local ev = self.ev
        ShowTip(self, {
            ev.text or L["Blizzard ability (name hidden by the game)"],
            Plans.FormatTime(ev.t) .. "  " .. (ev.src == "blizzard" and L["Blizzard"] or ns.Owners.Label(ev.owner)),
            L["Click to add a reminder at this time"],
        })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if ed.hooks.onAdd then
            ed.hooks.onAdd({ t = self.ev.t, spell = self.ev.spell,
                text = (self.ev.src ~= "blizzard" or not self.ev.spell) and self.ev.text or nil })
        end
    end)
    return b
end

-- 戰後回顧：錨點提示在上一場「實際該在」的位置（空心橘框），跟提示本身的位置一比就知道差多少
function PE:NewGhost()
    local b = CreateFrame("Frame", nil, self.canvas)
    b:SetSize(MINE_H - 6, MINE_H - 6)
    local px = P.Scale(1)
    for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                          { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = Tex(b, "OVERLAY", 1, 0.5, 0, 0.9)
        t:SetPoint(pt[1])
        t:SetPoint(pt[2])
        if pt[3] then t:SetHeight(px) else t:SetWidth(px) end
        b["e" .. i] = t
    end
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        ShowTip(self, {
            L["Last pull: %s"]:format(Plans.FormatTime(self.row.actual)),
            L["%+.1f seconds from this reminder"]:format(self.row.delta),
        })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- 我的提示：一條（出現 → 發生），右端圖示＋文字；拖曳改時間、點了編輯、右鍵選單
function PE:NewBlock()
    local ed = self
    local b = CreateFrame("Button", nil, self.canvas)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetHeight(MINE_H - 4)
    b.bar = Tex(b, "BACKGROUND", 0.33, 0.8, 0.33, 0.25)
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMRIGHT")
    b.edge = Tex(b, "BORDER", 0.33, 0.8, 0.33, 1)
    b.edge:SetPoint("TOPRIGHT")
    b.edge:SetPoint("BOTTOMRIGHT")
    b.edge:SetWidth(P.Scale(2))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(MINE_H - 6, MINE_H - 6)
    b.icon:SetPoint("LEFT", b, "RIGHT", 2, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.text = Font(b, true)
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)

    local function Finish(self, moved)
        self:SetScript("OnUpdate", nil)
        if not moved then return end
        local newT = self.dragT
        if not IsShiftKeyDown() then newT = math.floor(newT / SNAP + 0.5) * SNAP end
        if ed.hooks.onMove then ed.hooks.onMove(self.entry, newT) end
    end

    b:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.downX, self.moved, self.dragT = CursorX(), false, self.entry.t
        self:SetScript("OnUpdate", function(s)
            if not IsMouseButtonDown("LeftButton") then
                Finish(s, s.moved)
                return
            end
            local dx = CursorX() - s.downX
            if not s.moved and math.abs(dx) < DRAG_PX then return end
            s.moved = true
            s.dragT = math.max(0.1, s.entry.t + dx / ed.pps)
            local shown = IsShiftKeyDown() and s.dragT or math.floor(s.dragT / SNAP + 0.5) * SNAP
            s:ClearAllPoints()
            s:SetPoint("TOPRIGHT", ed.canvas, "TOPLEFT", shown * ed.pps, s.y)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(Plans.FormatTime(shown), 1, 1, 1)
            GameTooltip:Show()
        end)
    end)
    b:SetScript("OnClick", function(self, button)
        if self.moved then
            self.moved = false
            GameTooltip:Hide()
            return
        end
        if button == "RightButton" then
            if ed.hooks.onMenu then ed.hooks.onMenu(self.entry, self) end
        elseif ed.hooks.onEdit then
            ed.hooks.onEdit(self.entry)
        end
    end)
    b:SetScript("OnEnter", function(self)
        if self.moved then return end
        local e = self.entry
        local _, text = Plans.Resolve(e)
        local lines = { text, ("%s  %s"):format(Plans.FormatTime(e.t), L["shows %ds before"]:format(e.lead or Plans.DEFAULT_LEAD)) }
        if e.anchor then lines[#lines + 1] = L["Follows a boss cast"] end
        lines[#lines + 1] = L["Drag to move (Shift: no snapping) · Click to edit · Right-click for more"]
        ShowTip(self, lines)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

------------------------------------------------------------
-- 捲動與縮放
------------------------------------------------------------
function PE:ContentWidth()
    return math.max(self.canvasW, (self.length or 60) * self.pps)
end

function PE:ApplyScroll()
    self.canvas:ClearAllPoints()
    self.canvas:SetPoint("TOPLEFT", self.clip, "TOPLEFT", -self.scrollX, 0)
    self.ruler:ClearAllPoints()
    self.ruler:SetPoint("TOPLEFT", self.ruler:GetParent(), "TOPLEFT", -self.scrollX, 0)
end

function PE:SetScroll(x)
    local maxX = math.max(0, self:ContentWidth() - self.canvasW)
    x = math.max(0, math.min(maxX, x))
    self.scrollX = x
    self.hbar:SetMinMaxValues(0, maxX)
    self.hbar:SetValue(x)
    -- 拇指寬＝看得到的比例
    local ratio = self.canvasW / self:ContentWidth()
    self.thumb:SetWidth(math.max(24, self.canvasW * math.min(1, ratio)))
    self:ApplyScroll()
end

function PE:SetZoom(pps, anchorSec)
    pps = math.max(ZOOM_MIN, math.min(ZOOM_MAX, pps))
    local left = self.clip:GetLeft()
    local cursorOff = (anchorSec and left) and (CursorX() - left) or (self.canvasW / 2)
    anchorSec = anchorSec or ((self.scrollX + self.canvasW / 2) / self.pps)
    self.pps = pps
    if math.abs(self.zoom:GetValue() - pps) > 0.01 then self.zoom:SetValue(pps) end
    self:Redraw()
    self:SetScroll(anchorSec * pps - cursorOff)
end

------------------------------------------------------------
-- 資料 → 畫面
------------------------------------------------------------
-- 我的提示排子列：區間 [t − lead, t] 加上右端圖示文字的估計寬，重疊就往下一列
local LABEL_ALLOW = 110
local function PackMine(entries, pps)
    local lanesEnd = {}
    local out = {}
    for _, e in ipairs(entries) do
        local lead = e.lead or Plans.DEFAULT_LEAD
        local x1 = (e.t - lead) * pps
        local x2 = e.t * pps + LABEL_ALLOW
        local lane
        for i, endX in ipairs(lanesEnd) do
            if x1 >= endX + 4 then lane = i break end
        end
        if not lane then lane = #lanesEnd + 1 end
        lanesEnd[lane] = x2
        out[#out + 1] = { entry = e, lane = lane }
    end
    return out, math.max(1, #lanesEnd)
end

function PE:SetPlan(planID, opts)
    self.planID = planID
    self.opts = opts or {}
    self:Redraw()
    self:SetScroll(self.scrollX)
end

function PE:Redraw()
    local plan = Plans.Get(self.planID)
    for _, p in pairs(self.pools) do p:Reset() end
    if not plan then
        for _, p in pairs(self.pools) do p:HideRest() end
        return
    end
    local pps = self.pps
    local opts = self.opts or {}

    -- MRT：照技能分列（列的順序＝第一次施放的先後）
    local mrtLanes, phases = {}, {}
    local length = 60
    if opts.mrtVariant then
        local bySpell, order = {}, {}
        for _, ev in ipairs(MD.Events(self.planID, opts.mrtVariant)) do
            if not bySpell[ev.spell] then
                bySpell[ev.spell] = {}
                order[#order + 1] = ev.spell
            end
            local list = bySpell[ev.spell]
            list[#list + 1] = ev
            length = math.max(length, ev.t)
        end
        for _, spell in ipairs(order) do
            mrtLanes[#mrtLanes + 1] = { spell = spell, events = bySpell[spell] }
        end
        phases = MD.Phases(self.planID, opts.mrtVariant)
        for _, v in ipairs(MD.Variants(self.planID)) do
            if v.index == opts.mrtVariant and v.length then length = math.max(length, v.length) end
        end
    end
    local rec = opts.recorded and ns.db.recorded[self.planID]
    if rec then
        for _, ev in ipairs(rec.events) do length = math.max(length, ev.t) end
    end
    for _, e in ipairs(plan.entries) do length = math.max(length, e.t or 0) end
    self.length = length + PAD_END

    local contentW = self:ContentWidth()
    local packed, mineLanes = PackMine(plan.entries, pps)
    local mineH = mineLanes * MINE_H
    local totalH = mineH + #mrtLanes * LANE_H + (rec and LANE_H or 0) + 4
    self.canvas:SetSize(contentW, totalH)
    self.clip:SetHeight(totalH)
    self.gutter:SetHeight(totalH)
    self.body:SetHeight(totalH)
    self.vscroll:SetContentHeight(totalH)
    self.ruler:SetWidth(contentW)

    -- 尺規與格線：依縮放挑間距，讓標籤不擠
    local step = pps >= 8 and 10 or pps >= 4 and 15 or pps >= 2.5 and 30 or 60
    for sec = 0, self.length, step do
        local x = sec * pps
        local t = self.pools.rulerTick:Get()
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", self.ruler, "BOTTOMLEFT", x, 0)
        t:SetSize(P.Scale(1), 6)
        local lbl = self.pools.rulerLabel:Get()
        lbl:ClearAllPoints()
        lbl:SetPoint("BOTTOMLEFT", self.ruler, "BOTTOMLEFT", x + 2, 6)
        lbl:SetText(Plans.FormatTime(sec))
        local g = self.pools.tick:Get()
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", x, 0)
        g:SetSize(P.Scale(1), totalH)
    end

    local y = 0
    local function Lane(h, icon, text, shade)
        local bg = self.pools.laneBg:Get()
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 0, -y)
        bg:SetSize(contentW, h)
        bg:SetVertexColor(1, 1, 1, shade and 0.035 or 0.0)
        local g = self.pools.gutterLabel:Get()
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", self.gutter, "TOPLEFT", 0, -y)
        g:SetSize(GUTTER, math.min(h, LANE_H))
        g.icon:SetTexture(icon)
        g.icon:SetShown(icon ~= nil)
        g.text:ClearAllPoints()
        if icon then
            g.text:SetPoint("LEFT", g.icon, "RIGHT", 4, 0)
        else
            g.text:SetPoint("LEFT", 6, 0)
        end
        g.text:SetPoint("RIGHT", -4, 0)
        g.text:SetText(text)
    end

    -- 我的提示
    Lane(mineH, nil, "|cff55ff55" .. L["My reminders"] .. "|r", true)
    self.mineHit:ClearAllPoints()
    self.mineHit:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 0, 0)
    self.mineHit:SetSize(contentW, mineH)
    for _, item in ipairs(packed) do
        local e = item.entry
        local b = self.pools.block:Get()
        local lead = e.lead or Plans.DEFAULT_LEAD
        b.entry = e
        b.y = -(item.lane - 1) * MINE_H - 2
        b:SetFrameLevel(self.mineHit:GetFrameLevel() + 2)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", self.canvas, "TOPLEFT", e.t * pps, b.y)
        b:SetWidth(math.max(4, lead * pps))
        local icon, text = Plans.Resolve(e)
        b.icon:SetTexture(icon)
        local on = e.enabled ~= false
        b.icon:SetDesaturated(not on)
        local tags = ""
        -- 標記用文字不用符號：中文字型不一定有 ⚓／♪ 的字形（會變方框）
        if e.anchor then tags = tags .. " |cffffd100" .. L["[follows]"] .. "|r" end
        if e.sound or e.tts then tags = tags .. " |cff9d9d9d" .. L["[sound]"] .. "|r" end
        b.text:SetText((on and "" or "|cff808080") .. text .. (on and "" or "|r") .. tags)
        local r, g, bl = 0.33, 0.8, 0.33
        if not on then r, g, bl = 0.4, 0.4, 0.4 end
        b.bar:SetVertexColor(r, g, bl, 0.25)
        b.edge:SetVertexColor(r, g, bl, 1)
    end
    -- 戰後回顧的空心框
    if opts.review then
        local laneOf = {}
        for _, item in ipairs(packed) do laneOf[item.entry] = item.lane end
        for _, row in ipairs(opts.review) do
            if row.actual and math.abs(row.delta) >= 0.5 and laneOf[row.entry] then
                local g = self.pools.ghost:Get()
                g.row = row
                g:SetFrameLevel(self.mineHit:GetFrameLevel() + 1)
                g:ClearAllPoints()
                g:SetPoint("CENTER", self.canvas, "TOPLEFT", row.actual * pps, -(laneOf[row.entry] - 1) * MINE_H - MINE_H / 2)
            end
        end
    end
    y = y + mineH

    -- MRT
    for li, lane in ipairs(mrtLanes) do
        local first = lane.events[1]
        Lane(LANE_H, first.icon or 134400, first.name or ("#" .. lane.spell), li % 2 == 0)
        for n, ev in ipairs(lane.events) do
            local m = self.pools.mark:Get()
            m.ev, m.n = ev, n
            m:ClearAllPoints()
            m:SetPoint("CENTER", self.canvas, "TOPLEFT", ev.t * pps, -y - LANE_H / 2)
            m.icon:SetTexture(ev.icon or 134400)
            m.icon:SetVertexColor(0.85, 0.85, 0.85)
            m.count:SetText(ev.count > 1 and ev.count or "")
        end
        y = y + LANE_H
    end

    -- 上一場
    if rec then
        Lane(LANE_H, nil, "|cffff7f00" .. L["Last pull"] .. "|r", false)
        for _, ev in ipairs(rec.events) do
            local d = self.pools.dot:Get()
            d.ev = ev
            d:ClearAllPoints()
            d:SetPoint("CENTER", self.canvas, "TOPLEFT", ev.t * pps, -y - LANE_H / 2)
            if ev.src == "blizzard" then
                d.tex:SetVertexColor(1, 0.5, 0, ev.text and 1 or 0.5)
            else
                d.tex:SetVertexColor(0.4, 0.8, 1, 1)
            end
        end
        y = y + LANE_H
    end

    -- 換階段：整欄直線
    for _, ph in ipairs(phases) do
        local f = self.pools.phase:Get()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", ph.t * pps, 0)
        f:SetSize(P.Scale(1), totalH)
        f:SetFrameLevel(self.canvas:GetFrameLevel() + 1)
        f.text:SetText("P" .. tostring(ph.phase))
    end

    for _, p in pairs(self.pools) do p:HideRest() end
end
