------------------------------------------------------------
-- 標題列按鈕的方塊拖曳看板（「一般」分頁裡的一個小節）
--
-- 做成看板而不是五個「隱藏 XX 按鈕」勾選框：勾選框只管得了顯不顯示，管不了順序，
-- 而且「隱藏」是反向敘述（勾起來＝看不到），一排下來很難讀。
-- 一條 strip 就是標題列上實際的排列，拖曳換位、拖進「不顯示」（或點一下方塊）開關。
--
-- DB 仍是 style.hdrButtons[id] = { enabled, order }（見 Core/DB.lua），
-- 看板只是它的視圖：拖放後把整條序列重新編成 10、20、30… 寫回 order。
--
-- 互動與元件池照 MiliUI_InfoBar 的「區塊」分頁移植過來，那一套已經用過一輪。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local STRIP_LINE_H = 24
local CHIP_H = 20
local CHIP_GAP = 4

-- 整列寬：custom 的 build 拿到的 x 是**控件欄**（標籤欄右邊）的起點，但看板要橫跨
-- 整列，所以它自己錨 parent 的 TOPLEFT、寬度從 FORM_W 扣出來。
local BOARD_X = 8
local BOARD_W = ns.Options.FORM_W - 20

------------------------------------------------------------
-- 固定列高
--
-- custom 的列高在建表當下就定死（見 Libs/MiliUIWidgets/Controls.lua），所以不能等
-- Rebuild 算完再回報。兩條 strip 各**以一行計**：五顆方塊在 620 寬下不會換行
-- （最長的英文標籤量過也不到 120px，中文更短）。
-- FlowChips 的換行邏輯留著當保險，但真的換行時只會往下溢出一點，不重排整個表單。
------------------------------------------------------------
local LABEL_H = 16
local STRIP_H = STRIP_LINE_H + 4
local BOARD_H = (LABEL_H + STRIP_H) * 2 + 10

------------------------------------------------------------
-- 方塊上的字（跟那顆按鈕自己的工具提示同一條 key，兩邊不會各說各話）
-- ＋ 滑過方塊時提示的第二行：這顆按鈕到底做什麼、有沒有別的入口。
--
-- ⚠ 在這裡就用**字面字串**查好，不要寫成 L[NOTES[id]] 間接查表 ——
--   那樣 miliui-locale-audit 掃不到，會把這幾條報成「多餘的譯文」
--   （統計類型的名稱表踩過同一個坑，見 Meter/Data.lua 的 TYPE_DEFS）。
------------------------------------------------------------
local BTN_DEFS = {
    segments = { label = L["Segments"],
                 note = L["Switch which segment this window shows."] },
    publish  = { label = L["Publish"],
                 note = L["Post the current ranking to a chat channel. Not available in combat or during a Mythic+ run."] },
    reset    = { label = L["Reset data"],
                 note = L["Clear every recorded segment. This cannot be undone; the right-click menu and /mdm reset do the same thing."] },
    settings = { label = L["Window menu"],
                 note = L["Open the window menu — the same one you get by right-clicking the title bar."] },
    lock     = { label = L["Lock window"],
                 note = L["Lock or unlock the window. The right-click menu has it too."] },
}

local function ButtonLabel(id)
    local def = BTN_DEFS[id]
    return def and def.label or id
end

------------------------------------------------------------
-- 資料視圖
------------------------------------------------------------
local function EnabledOrdered()
    local list = {}
    for _, id in ipairs(ns.DB.HDR_BUTTON_IDS) do
        if ns.DB.HdrButton(id).enabled then list[#list + 1] = id end
    end
    table.sort(list, function(a, b)
        local oa, ob = ns.DB.HdrButton(a).order, ns.DB.HdrButton(b).order
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return list
end

local function DisabledList()
    local list = {}
    for _, id in ipairs(ns.DB.HDR_BUTTON_IDS) do
        if not ns.DB.HdrButton(id).enabled then list[#list + 1] = id end
    end
    return list
end

local function Renumber(seq)
    for i, id in ipairs(seq) do
        ns.DB.HdrButton(id).order = i * 10
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
local function CreateBoard(parent, width)
    local bd = CreateFrame("Frame", nil, parent)
    bd:SetSize(width, BOARD_H)
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
                GameTooltip:SetText(ButtonLabel(self.id), 1, 1, 1)
                local def = BTN_DEFS[self.id]
                if def and def.note then
                    GameTooltip:AddLine(def.note, 0.8, 0.8, 0.8, true)
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
    local function FlowChips(strip, ids, dimmed)
        local x, line = CHIP_GAP, 1
        for _, id in ipairs(ids) do
            local chip = AcquireChip()
            chip.id = id
            chip.text:SetText(ButtonLabel(id))
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
            self.barLabel = W.CreateGroupLabel(self, L["Shown (left to right)"])
        end
        self.barLabel:ClearAllPoints()
        self.barLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + LABEL_H

        local barStrip = AcquireStrip()
        barStrip.isBar = true
        barStrip:ClearAllPoints()
        barStrip:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        local lines = 1
        local shown = EnabledOrdered()
        if #shown > 0 then lines = FlowChips(barStrip, shown, false) end
        barStrip:SetSize(width, lines * STRIP_LINE_H + 4)
        y = y + lines * STRIP_LINE_H + 4 + 10

        -- 不顯示（停用池）
        if not self.poolLabel then
            self.poolLabel = W.CreateGroupLabel(self, L["Not shown"])
        end
        self.poolLabel:ClearAllPoints()
        self.poolLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + LABEL_H

        local hidden = DisabledList()
        local pool = AcquireStrip()
        pool.isPool = true
        pool:ClearAllPoints()
        pool:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        pool:SetBackdropColor(0.06, 0.06, 0.06, 1)
        lines = 1
        if #hidden > 0 then lines = FlowChips(pool, hidden, true) end
        pool:SetSize(width, lines * STRIP_LINE_H + 4)
        y = y + lines * STRIP_LINE_H + 4

        self:SetHeight(y)
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

    -- 游標落在哪：回傳 "pool"，或 "bar" + 錨點 id（要插在它前面；nil = 排最後）
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
                            return "bar", chip.id
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

        local id = chip.id
        local cfg = ns.DB.HdrButton(id)
        if not cfg then return end

        if not wasDragging then
            -- 點一下 = 快速開關（order 不動，叫回來的時候還在原位）
            cfg.enabled = not cfg.enabled
        else
            local target, anchorId = DropTarget(chip)
            if target == "pool" then
                cfg.enabled = false
            elseif target == "bar" then
                local seq = {}
                for _, k in ipairs(EnabledOrdered()) do
                    if k ~= id then seq[#seq + 1] = k end
                end
                local at = #seq + 1
                if anchorId then
                    for i, k in ipairs(seq) do
                        if k == anchorId then at = i break end
                    end
                end
                tinsert(seq, at, id)
                cfg.enabled = true
                Renumber(seq)
            end
            -- 放到看板外＝不變
        end

        ns.Windows.ApplyStyle()
        self:Rebuild()
    end

    return bd
end

------------------------------------------------------------
-- 給 Controls 的 custom 型別用：回傳固定高度 ＋ refresh
-- （換設定檔／重開分頁時 refresh 會被叫，看板要跟著重畫）
------------------------------------------------------------
function ns.Options.BuildButtonBoard(parent, _, y)
    local board = CreateBoard(parent, BOARD_W)
    board:SetPoint("TOPLEFT", parent, "TOPLEFT", BOARD_X, y)
    board:Rebuild()
    return BOARD_H, function() board:Rebuild() end
end

ns.Options.BUTTON_BOARD_H = BOARD_H
