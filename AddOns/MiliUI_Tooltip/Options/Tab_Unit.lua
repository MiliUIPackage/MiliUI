------------------------------------------------------------
-- 「玩家」「NPC」分頁：同一個建構器、兩份設定
--
-- 顯示元素是一個可拖曳的方塊看板：每一列一條，方塊可以在列內排序、
-- 拖到別列、拖到「不顯示」隱藏、拖到最下面自成一列；點一下快速開關。
-- 版面（列的組成與順序）直接寫回 DB 的 elements 數字鍵陣列。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Controls = ns.Controls
local Specs = ns.Specs

local tabs = {}   -- [kind] = { tab, refreshers, board }

------------------------------------------------------------
-- 表單（看板以外的控制項）
------------------------------------------------------------
local function BuildControls(kind)
    local controls = {
        { type = "header", label = L["Coloring"] },
        { type = "dropdown", key = "coloredBorder", label = L["Border tint"], items = Specs.BORDER_COLOR_ITEMS },
        { type = "dropdown", sub = "background", key = "colorfunc", label = L["Background tint"], items = Specs.BG_COLOR_ITEMS },
        { type = "slider", sub = "background", key = "alpha", label = L["Background opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "text", label = L["Opacity applies only when a background tint is selected; \"Global background color\" uses the alpha from the Style tab."] },

        { type = "header", label = L["Behavior"] },
        { type = "toggle", key = "showTarget", label = L["Show their target"] },
        { type = "toggle", key = "showTargetBy", label = L["Show teammates targeting them"] },
        { type = "toggle", key = "showModel", label = L["Show 3D model"] },
        { type = "toggle", key = "grayForDead", label = L["Gray out when dead"] },
        { type = "toggle", sub = "elements", sub2 = "factionBig", key = "enable", label = L["Big faction watermark"] },
    }
    if kind == "npc" then
        controls[#controls + 1] = { type = "toggle", sub = "elements", sub2 = "npcTitle", key = "enable", label = L["NPC title"] }
    end
    if kind == "player" then
        controls[#controls + 1] = { type = "header", label = L["Icon instead of text"] }
        for _, key in ipairs({ "className", "mplusScore", "itemLevel", "achievementPoints", "mount" }) do
            controls[#controls + 1] = {
                type = "toggle", sub = "elements", sub2 = key, key = "icon",
                label = Specs.ELEMENT_LABELS[key] or key,
            }
        end
        controls[#controls + 1] = { type = "text", label = L["Replaces the text label with a small icon (spec icon for class, dedicated icons for the rest)."] }
    end
    return controls
end

local function Resolve(root, spec)
    local t = root
    if spec.sub then t = t[spec.sub] end
    if spec.sub2 then t = t[spec.sub2] end
    return t
end

------------------------------------------------------------
-- 看板
------------------------------------------------------------
local STRIP_LINE_H = 22
local CHIP_H = 18
local CHIP_GAP = 4

-- 拖曳幽靈（共用一個）
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

local function RemoveFromRows(elements, key)
    for _, row in ipairs(elements) do
        for i = #row, 1, -1 do
            if row[i] == key then tremove(row, i) end
        end
    end
end

local function PruneEmptyRows(elements)
    for r = #elements, 1, -1 do
        if #elements[r] == 0 then tremove(elements, r) end
    end
end

local function KeyInRows(elements, key)
    for _, row in ipairs(elements) do
        for _, k in ipairs(row) do
            if k == key then return true end
        end
    end
    return false
end

-- 這個 kind 有哪些「列元素」（來自預設版面；factionBig / npcTitle 不在其中）
local function RowCapableList(kind)
    local def = ns.DB.BuildDefaults().unit[kind].elements
    local seen, list = {}, {}
    for _, row in ipairs(def) do
        for _, key in ipairs(row) do
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = key
            end
        end
    end
    return list
end

local function CreateBoard(parent, kind, width, onHeight)
    local board = CreateFrame("Frame", nil, parent)
    board:SetSize(width, 10)
    board.chips, board.strips = {}, {}
    board.chipCount, board.stripCount = 0, 0
    board.capable = RowCapableList(kind)

    local function GetElements()
        return ns.db.unit[kind].elements
    end

    ------------------------------------------------------------
    -- 元件池（frame 刪不掉，一律重用）
    ------------------------------------------------------------
    local function AcquireStrip()
        board.stripCount = board.stripCount + 1
        local strip = board.strips[board.stripCount]
        if not strip then
            strip = CreateFrame("Frame", nil, board, "BackdropTemplate")
            W.Stylize(strip, { 0.085, 0.085, 0.085, 1 })
            board.strips[board.stripCount] = strip
        end
        strip.chipList = {}
        strip.rowIndex = nil
        strip.isNew = nil
        strip.isPool = nil
        strip:SetBackdropBorderColor(0, 0, 0, 1)
        strip:Show()
        return strip
    end

    local function AcquireChip()
        board.chipCount = board.chipCount + 1
        local chip = board.chips[board.chipCount]
        if not chip then
            chip = CreateFrame("Button", nil, board, "BackdropTemplate")
            W.Stylize(chip, { 0.16, 0.16, 0.16, 1 })
            chip.text = chip:CreateFontString(nil, "OVERLAY")
            chip.text:SetFontObject(W.fontSmall)
            chip.text:SetPoint("CENTER", 0, 0)
            chip:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" then board:BeginPress(self) end
            end)
            chip:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then board:EndPress(self) end
            end)
            chip:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(W.Accent(1))
            end)
            chip:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0, 0, 0, 1)
            end)
            board.chips[board.chipCount] = chip
        end
        chip:SetBackdropBorderColor(0, 0, 0, 1)
        chip:Show()
        return chip
    end

    -- 把方塊排進一條 strip（超寬自動換行），回傳用掉的行數
    local function FlowChips(strip, keys, dimmed)
        local labels = Specs.ELEMENT_LABELS
        local x, line = CHIP_GAP, 1
        for _, key in ipairs(keys) do
            local chip = AcquireChip()
            chip.key = key
            chip.text:SetText(labels[key] or key)
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
    function board:Rebuild()
        for _, c in ipairs(self.chips) do c:Hide() end
        for _, s in ipairs(self.strips) do s:Hide() end
        self.chipCount, self.stripCount = 0, 0

        local elements = GetElements()
        local y = 0

        for r, row in ipairs(elements) do
            local shown = {}
            for _, key in ipairs(row) do
                local cfg = elements[key]
                if cfg and cfg.enable then tinsert(shown, key) end
            end
            local strip = AcquireStrip()
            strip.rowIndex = r
            strip:ClearAllPoints()
            strip:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            local lines = 1
            if #shown > 0 then
                lines = FlowChips(strip, shown, false)
            end
            strip:SetSize(width, lines * STRIP_LINE_H + 4)
            y = y + lines * STRIP_LINE_H + 4 + 4
        end

        -- 「新增一列」放置區
        local newStrip = AcquireStrip()
        newStrip.isNew = true
        newStrip:ClearAllPoints()
        newStrip:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        newStrip:SetSize(width, STRIP_LINE_H)
        newStrip:SetBackdropColor(0.06, 0.06, 0.06, 1)
        if not newStrip.hint then
            newStrip.hint = newStrip:CreateFontString(nil, "OVERLAY")
            newStrip.hint:SetFontObject(W.fontSmall)
            newStrip.hint:SetPoint("CENTER", 0, 0)
            newStrip.hint:SetTextColor(0.45, 0.45, 0.45)
        end
        newStrip.hint:SetText(L["Drop here to start a new line"])
        newStrip.hint:Show()
        y = y + STRIP_LINE_H + 10

        -- 不顯示（停用池）
        if not self.poolLabel then
            self.poolLabel = W.CreateGroupLabel(self, L["Hidden"])
        end
        self.poolLabel:ClearAllPoints()
        self.poolLabel:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
        y = y + 16

        local hidden = {}
        for _, key in ipairs(self.capable) do
            local cfg = elements[key]
            if cfg and not cfg.enable then tinsert(hidden, key) end
        end
        local pool = AcquireStrip()
        pool.isPool = true
        pool:ClearAllPoints()
        pool:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        pool:SetBackdropColor(0.06, 0.06, 0.06, 1)
        local lines = 1
        if #hidden > 0 then
            lines = FlowChips(pool, hidden, true)
        end
        pool:SetSize(width, lines * STRIP_LINE_H + 4)
        y = y + lines * STRIP_LINE_H + 4

        -- 別讓「新增一列」的提示殘留在其他 strip 上
        for _, s in ipairs(self.strips) do
            if s.hint and not s.isNew then s.hint:Hide() end
        end

        self:SetHeight(y)
        if onHeight then onHeight(y) end
    end

    ------------------------------------------------------------
    -- 拖曳
    ------------------------------------------------------------
    local function ClearHighlights()
        for _, s in ipairs(board.strips) do
            s:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end

    local function HighlightTarget()
        ClearHighlights()
        for i = 1, board.stripCount do
            local s = board.strips[i]
            if CursorIn(s) then
                s:SetBackdropBorderColor(W.Accent(1))
                return
            end
        end
    end

    -- 目前游標落在哪：回傳 "pool" / "new" / 列號 + 錨點 key（要插在它前面；nil = 排最後）
    local function DropTarget(dragChip)
        for i = 1, board.stripCount do
            local s = board.strips[i]
            if CursorIn(s) then
                if s.isPool then return "pool" end
                if s.isNew then return "new" end
                local x, cy = CursorPos(s)
                local top = s:GetTop()
                local cursorLine = math.floor((top - cy) / STRIP_LINE_H) + 1
                for _, chip in ipairs(s.chipList) do
                    if chip ~= dragChip then
                        local centerX = chip:GetLeft() and (chip:GetLeft() + chip:GetWidth() / 2)
                        if centerX and (chip.lineNo > cursorLine
                            or (chip.lineNo == cursorLine and centerX > x)) then
                            return s.rowIndex, chip.key
                        end
                    end
                end
                return s.rowIndex, nil
            end
        end
        return nil
    end

    function board:BeginPress(chip)
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

    function board:EndPress(chip)
        chip:SetScript("OnUpdate", nil)
        local wasDragging = self.dragging
        self.dragging = false
        if ghost then ghost:Hide() end
        ClearHighlights()

        local key = chip.key
        local elements = GetElements()
        local cfg = elements[key]
        if not cfg then return end

        if not wasDragging then
            -- 點一下 = 快速開關（保留原本的位置）
            cfg.enable = not cfg.enable
            if cfg.enable and not KeyInRows(elements, key) then
                if not elements[1] then elements[1] = {} end
                tinsert(elements[#elements], key)
            end
        else
            local target, anchorKey = DropTarget(chip)
            if target == "pool" then
                cfg.enable = false
            elseif target == "new" then
                RemoveFromRows(elements, key)
                tinsert(elements, { key })
                cfg.enable = true
            elseif type(target) == "number" then
                local row = elements[target]
                if row then
                    RemoveFromRows(elements, key)
                    local at = #row + 1
                    if anchorKey then
                        for i, k in ipairs(row) do
                            if k == anchorKey then at = i break end
                        end
                    end
                    tinsert(row, at, key)
                    cfg.enable = true
                end
            end
            -- 放到看板外＝不變
        end

        PruneEmptyRows(elements)
        ns.ApplyAll()
        self:Rebuild()
    end

    return board
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Init(kind)
    if tabs[kind] then return end
    local title = (kind == "player") and L["Player"] or "NPC"
    local tab, scroll = ns.Options.MakeFormTab(title)
    local ctx = {
        get = function(spec)
            local t = Resolve(ns.db.unit[kind], spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = Resolve(ns.db.unit[kind], spec)
            if t then t[spec.key] = v end
        end,
        apply = ns.ApplyAll,
    }

    local width = 600
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local formH, refreshers = Controls.Build(content, BuildControls(kind), ctx, 4, -4, width)

    -- 顯示元素看板（表單下方）
    local header = W.CreateGroupLabel(content, L["Lines and icons"])
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(formH + 14))
    local hint = content:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(formH + 32))
    hint:SetWidth(width - 20)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["One strip per tooltip line. Drag a block to reorder it, move it to another line, or drop it below to start a new line; drop it on \"Hidden\" (or just click it) to toggle it off. Hold Alt or Ctrl over a unit to temporarily show everything."])
    local boardTop = formH + 32 + hint:GetStringHeight() + 10

    local board
    board = CreateBoard(content, kind, width - 20, function(h)
        local total = boardTop + h + 24
        content:SetHeight(total)
        scroll:SetContentHeight(total)
    end)
    board:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -boardTop)

    tabs[kind] = { tab = tab, refreshers = refreshers, board = board }
end

local function Register(kind)
    ns.RegisterCallback("ShowOptionsTab", kind .. "Tab", function(id)
        if id ~= kind then
            if tabs[kind] then tabs[kind].tab:Hide() end
            return
        end
        Init(kind)
        for _, fn in ipairs(tabs[kind].refreshers) do fn() end
        tabs[kind].board:Rebuild()
        tabs[kind].tab:Show()
    end)
end

Register("player")
Register("npc")
