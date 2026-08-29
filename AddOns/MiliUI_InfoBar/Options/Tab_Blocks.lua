------------------------------------------------------------
-- 「區塊」分頁：方塊拖曳看板
--
-- 照 MiliUI_Tooltip 的 Options/Tab_Unit.lua 那套互動：一條 strip 就是
-- 資訊列的實際順序，拖曳方塊換位、拖進「不顯示」（或點一下方塊）開關，
-- 滑過方塊看說明。資訊列只有一列，所以沒有「新增一列」的放置區。
--
-- DB 仍是 blocks[key] = { enabled, order }——看板只是它的視圖：
-- 拖放後把整條序列重新編成 10、20、30…寫回 order。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, board, descText

local STRIP_LINE_H = 24
local CHIP_H = 20
local CHIP_GAP = 4
local BOARD_W = 620

-- 滑過方塊時的說明（沒有條目的就只顯示名稱）
local BLOCK_NOTES = {
    ilvl       = "BLOCK_ILVL_DESC",
    durability = "BLOCK_DURABILITY_DESC",
    micromenu  = "BLOCK_MICROMENU_DESC",
    spec       = "BLOCK_SPEC_DESC",
    lootspec   = "BLOCK_LOOTSPEC_DESC",
    cpu        = "BLOCK_CPU_DESC",
    mem        = "BLOCK_MEM_DESC",
}

local function BlockLabel(key)
    return L["BLOCK_" .. key:upper()]
end

------------------------------------------------------------
-- 資料視圖
------------------------------------------------------------
local function EnabledOrdered()
    local db = ns.GetDB()
    local list = {}
    for _, def in ipairs(ns.BLOCK_DEFS) do
        local cfg = db.blocks[def.key]
        if cfg and cfg.enabled then list[#list + 1] = def.key end
    end
    table.sort(list, function(a, b)
        local oa, ob = db.blocks[a].order or 0, db.blocks[b].order or 0
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return list
end

local function DisabledList()
    local db = ns.GetDB()
    local list = {}
    for _, def in ipairs(ns.BLOCK_DEFS) do
        local cfg = db.blocks[def.key]
        if cfg and not cfg.enabled then list[#list + 1] = def.key end
    end
    return list
end

local function Renumber(seq)
    local db = ns.GetDB()
    for i, key in ipairs(seq) do
        db.blocks[key].order = i * 10
    end
end

------------------------------------------------------------
-- 拖曳幽靈（跟著游標跑的那塊）
------------------------------------------------------------
local ghost
local function EnsureGhost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ghost:SetFrameStrata("TOOLTIP")
    W.Stylize(ghost, { 0.2, 0.2, 0.2, 0.9 })
    ghost:SetBackdropBorderColor(W.Accent(1))
    ghost:SetHeight(CHIP_H)
    ghost.text = ghost:CreateFontString(nil, "OVERLAY")
    ghost.text:SetFontObject(W.fontSmall)
    ghost.text:SetPoint("CENTER", 0, 0)
    ghost:Hide()
    return ghost
end

local function CursorPos(frame)
    local scale = frame:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local function CursorIn(frame)
    if not frame:IsVisible() then return false end
    local x, y = CursorPos(frame)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not l then return false end
    return x >= l and x <= r and y <= t and y >= b
end

------------------------------------------------------------
-- 看板
------------------------------------------------------------
local function CreateBoard(parent, width, onHeight)
    local bd = CreateFrame("Frame", nil, parent)
    bd:SetSize(width, 10)
    bd.chips, bd.strips = {}, {}
    bd.chipCount, bd.stripCount = 0, 0

    ------------------------------------------------------------
    -- 元件池（frame 刪不掉，一律重用）
    ------------------------------------------------------------
    local function AcquireStrip()
        bd.stripCount = bd.stripCount + 1
        local strip = bd.strips[bd.stripCount]
        if not strip then
            strip = CreateFrame("Frame", nil, bd, "BackdropTemplate")
            W.Stylize(strip, { 0.085, 0.085, 0.085, 1 })
            bd.strips[bd.stripCount] = strip
        end
        strip.chipList = {}
        strip.isBar = nil
        strip.isPool = nil
        strip:SetBackdropBorderColor(0, 0, 0, 1)
        strip:Show()
        return strip
    end

    local function AcquireChip()
        bd.chipCount = bd.chipCount + 1
        local chip = bd.chips[bd.chipCount]
        if not chip then
            chip = CreateFrame("Button", nil, bd, "BackdropTemplate")
            W.Stylize(chip, { 0.16, 0.16, 0.16, 1 })
            chip.text = chip:CreateFontString(nil, "OVERLAY")
            chip.text:SetFontObject(W.fontSmall)
            chip.text:SetPoint("CENTER", 0, 0)
            chip:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" then bd:BeginPress(self) end
            end)
            chip:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then bd:EndPress(self) end
            end)
            chip:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(W.Accent(1))
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(BlockLabel(self.key), 1, 1, 1)
                local note = BLOCK_NOTES[self.key]
                if note then
                    GameTooltip:AddLine(L[note], 0.8, 0.8, 0.8, true)
                end
                GameTooltip:Show()
            end)
            chip:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0, 0, 0, 1)
                GameTooltip:Hide()
            end)
            bd.chips[bd.chipCount] = chip
        end
        chip:SetBackdropBorderColor(0, 0, 0, 1)
        chip:Show()
        return chip
    end

    -- 把方塊排進一條 strip（超寬自動換行），回傳用掉的行數
    local function FlowChips(strip, keys, dimmed)
        local x, line = CHIP_GAP, 1
        for _, key in ipairs(keys) do
            local chip = AcquireChip()
            chip.key = key
            chip.text:SetText(BlockLabel(key))
            if dimmed then
                chip.text:SetTextColor(0.55, 0.55, 0.55)
                chip:SetBackdropColor(0.11, 0.11, 0.11, 1)
            else
                chip.text:SetTextColor(1, 1, 1)
                chip:SetBackdropColor(0.16, 0.16, 0.16, 1)
            end
            local w = math.ceil(chip.text:GetStringWidth()) + 14
            if x + w + CHIP_GAP > width and x > CHIP_GAP then
                x = CHIP_GAP
                line = line + 1
            end
            chip.lineNo = line
            chip:SetParent(strip)
            chip:SetSize(w, CHIP_H)
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -((line - 1) * STRIP_LINE_H + 2))
            x = x + w + CHIP_GAP
            tinsert(strip.chipList, chip)
        end
        return line
    end

    ------------------------------------------------------------
    -- 重排整個看板
    ------------------------------------------------------------
    function bd:Rebuild()
        for _, c in ipairs(self.chips) do c:Hide() end
        for _, s in ipairs(self.strips) do s:Hide() end
        self.chipCount, self.stripCount = 0, 0

        local y = 0

        if not self.barLabel then
            self.barLabel = W.CreateGroupLabel(self, L["BOARD_SHOWN"])
        end
        self.barLabel:ClearAllPoints()
        self.barLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + 16

        local barStrip = AcquireStrip()
        barStrip.isBar = true
        barStrip:ClearAllPoints()
        barStrip:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        local lines = 1
        local shown = EnabledOrdered()
        if #shown > 0 then
            lines = FlowChips(barStrip, shown, false)
        end
        barStrip:SetSize(width, lines * STRIP_LINE_H + 4)
        y = y + lines * STRIP_LINE_H + 4 + 10

        -- 不顯示（停用池）
        if not self.poolLabel then
            self.poolLabel = W.CreateGroupLabel(self, L["BOARD_HIDDEN"])
        end
        self.poolLabel:ClearAllPoints()
        self.poolLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + 16

        local hidden = DisabledList()
        local pool = AcquireStrip()
        pool.isPool = true
        pool:ClearAllPoints()
        pool:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        pool:SetBackdropColor(0.06, 0.06, 0.06, 1)
        lines = 1
        if #hidden > 0 then
            lines = FlowChips(pool, hidden, true)
        end
        pool:SetSize(width, lines * STRIP_LINE_H + 4)
        y = y + lines * STRIP_LINE_H + 4

        self:SetHeight(y)
        if onHeight then onHeight(y) end
    end

    ------------------------------------------------------------
    -- 拖曳
    ------------------------------------------------------------
    local function ClearHighlights()
        for _, s in ipairs(bd.strips) do
            s:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end

    local function HighlightTarget()
        ClearHighlights()
        for i = 1, bd.stripCount do
            local s = bd.strips[i]
            if CursorIn(s) then
                s:SetBackdropBorderColor(W.Accent(1))
                return
            end
        end
    end

    -- 游標落在哪：回傳 "pool"，或 "bar" + 錨點 key（要插在它前面；nil = 排最後）
    local function DropTarget(dragChip)
        for i = 1, bd.stripCount do
            local s = bd.strips[i]
            if CursorIn(s) then
                if s.isPool then return "pool" end
                local x, cy = CursorPos(s)
                local top = s:GetTop()
                local cursorLine = math.floor((top - cy) / STRIP_LINE_H) + 1
                for _, chip in ipairs(s.chipList) do
                    if chip ~= dragChip then
                        local centerX = chip:GetLeft() and (chip:GetLeft() + chip:GetWidth() / 2)
                        if centerX and (chip.lineNo > cursorLine
                            or (chip.lineNo == cursorLine and centerX > x)) then
                            return "bar", chip.key
                        end
                    end
                end
                return "bar", nil
            end
        end
        return nil
    end

    function bd:BeginPress(chip)
        local x, y = GetCursorPosition()
        self.pressX, self.pressY = x, y
        self.dragging = false
        chip:SetScript("OnUpdate", function(c)
            if self.dragging then
                local g = EnsureGhost()
                local cx, cy = GetCursorPosition()
                local s = UIParent:GetEffectiveScale()
                g:ClearAllPoints()
                g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / s, cy / s + 10)
                HighlightTarget()
            else
                local cx, cy = GetCursorPosition()
                if math.abs(cx - self.pressX) > 6 or math.abs(cy - self.pressY) > 6 then
                    self.dragging = true
                    local g = EnsureGhost()
                    g.text:SetText(c.text:GetText())
                    g:SetWidth(c:GetWidth())
                    g:Show()
                end
            end
        end)
    end

    function bd:EndPress(chip)
        chip:SetScript("OnUpdate", nil)
        local wasDragging = self.dragging
        self.dragging = false
        if ghost then ghost:Hide() end
        ClearHighlights()

        local key = chip.key
        local cfg = ns.GetDB().blocks[key]
        if not cfg then return end

        if not wasDragging then
            -- 點一下 = 快速開關（order 不動，回來時還在原位）
            cfg.enabled = not cfg.enabled
        else
            local target, anchorKey = DropTarget(chip)
            if target == "pool" then
                cfg.enabled = false
            elseif target == "bar" then
                local seq = {}
                for _, k in ipairs(EnabledOrdered()) do
                    if k ~= key then seq[#seq + 1] = k end
                end
                local at = #seq + 1
                if anchorKey then
                    for i, k in ipairs(seq) do
                        if k == anchorKey then at = i break end
                    end
                end
                tinsert(seq, at, key)
                cfg.enabled = true
                Renumber(seq)
            end
            -- 放到看板外＝不變
        end

        ns.ApplyAll()
        self:Rebuild()
    end

    return bd
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Layout()
    local h = 8 + descText:GetStringHeight() + 12 + board:GetHeight() + 20
    scroll:SetContentHeight(h)
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_BLOCKS"])

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(ns.Options.FORM_W, 1)

    descText = content:CreateFontString(nil, "OVERLAY")
    descText:SetFontObject(W.fontNormal)
    descText:SetPoint("TOPLEFT", 4, -8)
    descText:SetWidth(BOARD_W)
    descText:SetJustifyH("LEFT")
    descText:SetSpacing(3)
    descText:SetTextColor(0.75, 0.75, 0.75)
    descText:SetText(L["BLOCKS_DESC"])

    board = CreateBoard(content, BOARD_W, Layout)
    board:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -12)
end

ns.RegisterCallback("ShowOptionsTab", "blocksTab", function(id)
    if id ~= "blocks" then
        if tab then tab:Hide() end
        return
    end
    Init()
    board:Rebuild()
    tab:Show()
end)
