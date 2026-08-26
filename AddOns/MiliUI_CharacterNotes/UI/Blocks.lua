------------------------------------------------------------
-- 區塊：可編輯的區塊清單 ＋ 唯讀的區塊檢視
--
-- 兩個消費者的需求不一樣，所以做成兩支工廠而不是一支加開關：
--   CreateEditor  筆記本的編輯視窗——拖曳排序、轉換類型、縮排、自動長高
--   CreateViewer  副本浮動視窗與分享預覽——只讀，但勾選框照樣點得動
--
-- 兩支都吃 W.CreateScrollFrame 建出來的 scroll（有 .child 與 :SetContentHeight）。
------------------------------------------------------------
local _, ns = ...

ns.Blocks = {}
local Blocks = ns.Blocks

local W, P, L = ns.W, ns.P, ns.L
local Notes, Media = ns.Notes, ns.Media

local ROW_MIN_H  = 24
local INDENT_PX  = 20
local TIME_W     = 40      -- 倒數欄的寬度（"-10:59" 塞得下）
local TICK       = 0.5
local HANDLE_W   = 14
local PREFIX_W   = 22
local ROW_GAP    = 2

local T_TEXT     = Notes.TYPE_TEXT
local T_CHECKBOX = Notes.TYPE_CHECKBOX
local T_BULLET   = Notes.TYPE_BULLET
local T_NUMBER   = Notes.TYPE_NUMBER

------------------------------------------------------------
-- 編號計算
--
-- 規則：同一階層連續的編號區塊共用一個計數；遇到同層（或更淺層）的非編號區塊
-- 就中斷重置；進入更深階層時淺層的計數保留。
------------------------------------------------------------
local function ComputeNumbers(blocks)
    local prefixes, counters = {}, {}
    for i, b in ipairs(blocks) do
        local indent = b.indent or 0
        if b.type == T_NUMBER then
            counters[indent] = (counters[indent] or 0) + 1
            prefixes[i] = counters[indent]
            for k in pairs(counters) do
                if k > indent then counters[k] = nil end
            end
        else
            for k in pairs(counters) do
                if k >= indent then counters[k] = nil end
            end
        end
    end
    return prefixes
end
Blocks.ComputeNumbers = ComputeNumbers

------------------------------------------------------------
-- 子樹範圍：一個區塊 ＋ 緊接其後、縮排更深的連續區塊
-- 拖曳 parent 時整段一起搬。
------------------------------------------------------------
local function GroupRange(blocks, idx)
    local base = blocks[idx].indent or 0
    local endI = idx
    for j = idx + 1, #blocks do
        if (blocks[j].indent or 0) > base then endI = j else break end
    end
    return idx, endI
end

------------------------------------------------------------
-- 可編輯的區塊清單
------------------------------------------------------------
function Blocks.CreateEditor(scroll, onChanged)
    local ed = {
        scroll    = scroll,
        container = scroll.child,
        rows      = {},
        note      = nil,
        onChanged = onChanged,
    }

    -- 任何一處改到筆記都走這支：更新時間戳，並通知宿主（同步層要重推）
    local function Touched()
        if ed.note then Notes.Touch(ed.note) end
        if ed.onChanged then ed.onChanged() end
    end

    local dragLine = ed.container:CreateTexture(nil, "OVERLAY")
    dragLine:SetColorTexture(W.Accent(1))
    dragLine:SetHeight(P.Scale(2))
    dragLine:Hide()
    local dragState

    ------------------------------------------------------------
    -- 版面
    ------------------------------------------------------------
    function ed:Relayout()
        local y = 4
        for _, row in ipairs(self.rows) do
            if row:IsShown() then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", self.container, "RIGHT", 0, 0)
                y = y + row:GetHeight() + ROW_GAP
            end
        end
        scroll:SetContentHeight(math.max(1, y + 4))
    end

    ------------------------------------------------------------
    -- 拖曳
    ------------------------------------------------------------
    local function CancelDrag()
        dragState = nil
        dragLine:Hide()
        scroll:SetScript("OnUpdate", nil)
        for _, r in ipairs(ed.rows) do
            if r:GetAlpha() < 1 then r:SetAlpha(1) end
        end
    end
    ed.CancelDrag = CancelDrag

    local function DragMonitor()
        if not dragState then return end
        local hovered
        for _, r in ipairs(ed.rows) do
            if r:IsShown() and r:IsMouseOver() then hovered = r break end
        end
        if not hovered then
            dragLine:Hide()
            dragState.targetIdx = nil
            return
        end
        local _, cy = GetCursorPosition()
        cy = cy / hovered:GetEffectiveScale()
        local mid = hovered:GetTop() - hovered:GetHeight() / 2
        local idx = hovered._index or 1
        dragState.targetIdx = (cy >= mid) and idx or (idx + 1)

        dragLine:ClearAllPoints()
        if cy >= mid then
            dragLine:SetPoint("TOPLEFT", hovered, "TOPLEFT", 0, 1)
            dragLine:SetPoint("TOPRIGHT", hovered, "TOPRIGHT", 0, 1)
        else
            dragLine:SetPoint("BOTTOMLEFT", hovered, "BOTTOMLEFT", 0, -1)
            dragLine:SetPoint("BOTTOMRIGHT", hovered, "BOTTOMRIGHT", 0, -1)
        end
        dragLine:Show()
    end

    ------------------------------------------------------------
    -- 增刪
    ------------------------------------------------------------
    -- afterIdx 給 nil 就接在最後面
    function ed:AddBlock(blockType, afterIdx, indent)
        if not self.note then return end
        local block = { type = blockType, text = "" }
        if blockType == T_CHECKBOX then block.checked = false end
        if indent and indent > 0 then block.indent = indent end
        local at = afterIdx and (afterIdx + 1) or (#self.note.blocks + 1)
        table.insert(self.note.blocks, at, block)
        Touched()
        self:Refresh()
        local row = self.rows[at]
        if row and row.editBox then row.editBox:SetFocus() end
        if not afterIdx then
            -- 加在最後面：捲到底才看得到新的那一行
            local maxScroll = math.max(0, self.container:GetHeight() - scroll:GetHeight())
            scroll:SetVerticalScroll(maxScroll)
        end
        return at
    end

    ------------------------------------------------------------
    -- 併回上一個區塊：把自己的文字接到上一塊後面，游標停在接縫處
    ------------------------------------------------------------
    function ed:MergeIntoPrevious(index)
        if not self.note then return end
        local blocks = self.note.blocks
        local cur, prev = blocks[index], blocks[index - 1]
        if not (cur and prev) then return end

        local joinAt = #(prev.text or "")
        prev.text = (prev.text or "") .. (cur.text or "")
        table.remove(blocks, index)
        Notes.Touch(self.note)
        self:Refresh()

        local prevRow = self.rows[index - 1]
        if prevRow and prevRow.editBox then
            prevRow.editBox:SetFocus()
            prevRow.editBox:SetCursorPosition(joinAt)
        end
    end

    ------------------------------------------------------------
    -- 把標記插到游標處
    --
    -- back 給了就把游標往回移那麼多字（成對標記插完要停在中間）。
    -- 沒有任何一格有焦點時插到最後一格 —— 總比什麼都沒發生好。
    ------------------------------------------------------------
    function ed:InsertAtCursor(text, back)
        local eb = self.focused
        if not (eb and eb:IsVisible()) then
            local last
            for _, r in ipairs(self.rows) do
                if r:IsShown() then last = r end
            end
            eb = last and last.editBox
        end
        if not eb then return end
        if not eb:HasFocus() then eb:SetFocus() end
        eb:Insert(text)
        if back and back > 0 then
            eb:SetCursorPosition(math.max(0, eb:GetCursorPosition() - back))
        end
    end

    function ed:DeleteBlock(index)
        if not self.note or not index then return end
        local blocks = self.note.blocks
        if not blocks[index] then return end
        table.remove(blocks, index)
        if #blocks == 0 then
            blocks[1] = { type = T_TEXT, text = "" }
        end
        Touched()
        self:Refresh()
    end

    ------------------------------------------------------------
    -- 一列
    ------------------------------------------------------------
    local function CreateRow()
        local row = CreateFrame("Frame", nil, ed.container)
        row:SetHeight(ROW_MIN_H)

        -- 拖曳把手：2×3 點陣（不吃字型，換語系不會跑版）
        -- 用 Button 才收得到右鍵
        local handle = CreateFrame("Button", nil, row)
        handle:SetSize(HANDLE_W, ROW_MIN_H)
        handle:SetPoint("TOPLEFT", 2, 0)
        row.dragHandle = handle

        local dots = {}
        for r = 1, 3 do
            for c = 1, 2 do
                local dot = handle:CreateTexture(nil, "OVERLAY")
                dot:SetColorTexture(0.45, 0.45, 0.45, 1)
                dot:SetSize(2, 2)
                dot:SetPoint("CENTER", handle, "CENTER", (c - 1.5) * 4, (2 - r) * 5)
                dots[#dots + 1] = dot
            end
        end
        local function SetHandleColor(rr, gg, bb)
            for _, d in ipairs(dots) do d:SetColorTexture(rr, gg, bb, 1) end
        end

        handle:EnableMouse(true)
        handle:RegisterForDrag("LeftButton")
        handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        handle:SetScript("OnEnter", function() SetHandleColor(W.Accent(1)) end)
        handle:SetScript("OnLeave", function() SetHandleColor(0.45, 0.45, 0.45) end)

        handle:SetScript("OnDragStart", function()
            if not row._block or not ed.note then return end
            dragState = { sourceIdx = row._index, targetIdx = nil }
            local s, e = GroupRange(ed.note.blocks, row._index)
            for k = s, e do
                if ed.rows[k] then ed.rows[k]:SetAlpha(0.4) end
            end
            scroll:SetScript("OnUpdate", DragMonitor)
        end)

        handle:SetScript("OnDragStop", function()
            local state = dragState
            CancelDrag()
            SetHandleColor(0.45, 0.45, 0.45)
            if not (state and state.targetIdx and state.sourceIdx and ed.note) then return end

            local blocks = ed.note.blocks
            local s, e = GroupRange(blocks, state.sourceIdx)
            local tgt = state.targetIdx
            -- 不允許把 parent 丟進自己的子樹裡面
            if tgt > s and tgt <= e then return end

            local count = e - s + 1
            local moving = {}
            for k = s, e do moving[#moving + 1] = blocks[k] end
            for k = e, s, -1 do table.remove(blocks, k) end
            if tgt > e then tgt = tgt - count end
            tgt = math.max(1, math.min(#blocks + 1, tgt))
            for k = #moving, 1, -1 do table.insert(blocks, tgt, moving[k]) end
            Touched()
            ed:Refresh()
        end)

        -- 前綴容器
        row.prefix = CreateFrame("Frame", nil, row)
        row.prefix:SetSize(PREFIX_W, ROW_MIN_H)
        row.prefix:SetPoint("TOPLEFT", handle, "TOPRIGHT", 2, 0)

        row.prefixCheckbox = CreateFrame("CheckButton", nil, row.prefix, "UICheckButtonTemplate")
        row.prefixCheckbox:SetSize(20, 20)
        row.prefixCheckbox:SetPoint("CENTER", 0, 0)
        row.prefixCheckbox:Hide()
        row.prefixCheckbox:SetScript("OnClick", function(self)
            local b = row._block
            if b and b.type == T_CHECKBOX then
                b.checked = self:GetChecked() and true or false
                Touched()
            end
        end)

        row.prefixBullet = row.prefix:CreateTexture(nil, "OVERLAY")
        row.prefixBullet:SetSize(5, 5)
        row.prefixBullet:SetPoint("CENTER", 0, 0)
        row.prefixBullet:SetColorTexture(0.85, 0.85, 0.85, 1)
        row.prefixBullet:Hide()

        row.prefixText = row.prefix:CreateFontString(nil, "OVERLAY")
        row.prefixText:SetFontObject(Media.fontBody)
        row.prefixText:SetPoint("CENTER", 0, 0)
        row.prefixText:Hide()

        -- 內文
        local eb = CreateFrame("EditBox", nil, row)
        row.editBox = eb
        eb:SetMultiLine(true)
        eb:SetMaxLetters(0)
        eb:SetAutoFocus(false)
        eb:SetFontObject(Media.fontBody)
        eb:SetPoint("TOPLEFT", row.prefix, "TOPRIGHT", 4, -2)
        eb:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        eb:SetTextInsets(2, 2, 2, 2)
        eb:SetCountInvisibleLetters(false)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- 記住最後有焦點的那一格：標記工具列要知道插到哪裡去
        eb:SetScript("OnEditFocusGained", function(self) ed.focused = self end)

        ------------------------------------------------------------
        -- 在最前面按 Backspace ＝ 併回上一個區塊（一般編輯器的行為）
        --
        -- ⚠ 只能靠 OnKeyDown，不能靠 OnTextChanged：游標在 0 又沒有選取時，
        --   Backspace **什麼都不會刪**，所以文字根本不會變動，OnTextChanged 不會來。
        --
        -- ⚠ 真正的合併延到下一幀再做，而且要比對文字有沒有變。游標回報在 0 但其實
        --   有一段選取時，Backspace 刪的是那段選取 —— 那種情況不該合併。等一幀之後
        --   OnTextChanged 已經把刪除結果寫進 block.text，比對得出來。
        ------------------------------------------------------------
        eb:SetScript("OnKeyDown", function(self, key)
            if key ~= "BACKSPACE" then return end
            if self:GetCursorPosition() ~= 0 then return end
            local idx = row._index
            if not idx or idx <= 1 then return end
            local block = row._block
            if not block then return end
            local before = block.text or ""
            C_Timer.After(0, function()
                if row._block ~= block then return end          -- 這一列已經被回收去畫別的了
                if (block.text or "") ~= before then return end  -- 剛剛刪掉的是選取範圍
                ed:MergeIntoPrevious(idx)
            end)
        end)

        -- Tab / Shift+Tab 調整縮排
        eb:SetScript("OnTabPressed", function()
            local b = row._block
            if not b then return end
            local cur = b.indent or 0
            local new = IsShiftKeyDown() and math.max(0, cur - 1)
                                          or math.min(Notes.MAX_INDENT, cur + 1)
            if new == cur then return end
            b.indent = (new == 0) and nil or new
            Touched()
            ed:Refresh()
            if row.editBox then row.editBox:SetFocus() end
        end)

        eb:SetScript("OnTextChanged", function(self, userInput)
            local b = row._block
            if not b then return end
            local text = self:GetText() or ""

            -- 多行 EditBox 的 Enter 是插入換行，不會觸發 OnEnterPressed。
            -- 換行在這裡就地拆成新的區塊——同時也讓「整段貼上」自動變成一行一塊。
            if userInput and text:find("\n", 1, true) and ed.note then
                local parts = {}
                for piece in (text .. "\n"):gmatch("(.-)\n") do parts[#parts + 1] = piece end
                b.text = parts[1] or ""
                local at = row._index
                for i = 2, #parts do
                    at = at + 1
                    local nb = { type = b.type, text = parts[i] }
                    if b.indent then nb.indent = b.indent end
                    if b.type == T_CHECKBOX then nb.checked = false end
                    table.insert(ed.note.blocks, at, nb)
                end
                Touched()
                ed:Refresh()
                local newRow = ed.rows[at]
                if newRow and newRow.editBox then
                    newRow.editBox:SetFocus()
                    newRow.editBox:SetCursorPosition(#(newRow.editBox:GetText() or ""))
                end
                return
            end

            b.text = text
            Touched()
            -- 折行時 EditBox 自己會長高，列跟著走
            local desired = math.max(ROW_MIN_H, math.ceil(self:GetHeight()) + 4)
            if math.abs((row:GetHeight() or 0) - desired) > 0.5 then
                row:SetHeight(desired)
                ed:Relayout()
            end
        end)

        ------------------------------------------------------------
        -- 把手選單：轉換類型 / 縮排 / 刪除
        -- 左鍵單擊（沒拖動）與右鍵都開，RegisterForDrag 自己分流拖曳與點擊
        ------------------------------------------------------------
        local CONVERT = {
            { type = T_TEXT,     key = "Convert to text" },
            { type = T_CHECKBOX, key = "Convert to checkbox" },
            { type = T_BULLET,   key = "Convert to bullet" },
            { type = T_NUMBER,   key = "Convert to number" },
        }

        local function ConvertTo(targetType)
            local b = row._block
            if not b or b.type == targetType then return end
            b.type = targetType
            if targetType == T_CHECKBOX and b.checked == nil then b.checked = false end
            Touched()
            ed:Refresh()
        end

        local function Indent(delta)
            local b = row._block
            if not b then return end
            local cur = b.indent or 0
            local new = math.max(0, math.min(Notes.MAX_INDENT, cur + delta))
            if new == cur then return end
            b.indent = (new == 0) and nil or new
            Touched()
            ed:Refresh()
        end

        handle:SetScript("OnClick", function(self, mouseButton)
            if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
            local b = row._block
            if not b then return end
            local cur = b.indent or 0
            local items = {}
            for _, opt in ipairs(CONVERT) do
                if opt.type ~= b.type then
                    items[#items + 1] = { text = L[opt.key], onClick = function() ConvertTo(opt.type) end }
                end
            end
            if cur < Notes.MAX_INDENT or cur > 0 then
                items[#items + 1] = { isSeparator = true }
                if cur < Notes.MAX_INDENT then
                    items[#items + 1] = { text = L["Indent (Tab)"], onClick = function() Indent(1) end }
                end
                if cur > 0 then
                    items[#items + 1] = { text = L["Outdent (Shift+Tab)"], onClick = function() Indent(-1) end }
                end
            end
            items[#items + 1] = { isSeparator = true }
            items[#items + 1] = {
                text = "|cffff5555" .. L["Delete this block"] .. "|r",
                onClick = function() ed:DeleteBlock(row._index) end,
            }
            W.Menu.Show(items, self)
        end)

        return row
    end

    ------------------------------------------------------------
    -- 一列的內容
    ------------------------------------------------------------
    local function ConfigureRow(row, block, index, numberPrefix)
        row._block = block
        row._index = index

        local indent = math.max(0, math.min(Notes.MAX_INDENT, block.indent or 0))
        row.prefix:ClearAllPoints()
        row.prefix:SetPoint("TOPLEFT", row.dragHandle, "TOPRIGHT", 2 + indent * INDENT_PX, 0)

        row.prefixCheckbox:Hide()
        row.prefixBullet:Hide()
        row.prefixText:Hide()

        if block.type == T_CHECKBOX then
            row.prefix:Show()
            row.prefixCheckbox:Show()
            row.prefixCheckbox:SetChecked(block.checked == true)
        elseif block.type == T_BULLET then
            row.prefix:Show()
            row.prefixBullet:Show()
        elseif block.type == T_NUMBER then
            row.prefix:Show()
            row.prefixText:SetText((numberPrefix or 1) .. ".")
            row.prefixText:Show()
        else
            row.prefix:Hide()
        end

        -- 內容一樣就不要重設：SetText 會把游標打回開頭
        if row.editBox:GetText() ~= (block.text or "") then
            row.editBox:SetText(block.text or "")
        end
    end

    ------------------------------------------------------------
    function ed:Refresh()
        for _, row in ipairs(self.rows) do row:Hide() end
        if not self.note or type(self.note.blocks) ~= "table" or #self.note.blocks == 0 then
            scroll:SetContentHeight(1)
            return
        end
        local blocks = self.note.blocks
        local numbers = ComputeNumbers(blocks)
        for i, block in ipairs(blocks) do
            local row = self.rows[i] or CreateRow()
            self.rows[i] = row
            ConfigureRow(row, block, i, numbers[i])
            row:Show()
        end
        self:Relayout()
    end

    function ed:SetNote(note)
        CancelDrag()
        self.note = note
        if note then Notes.EnsureBlocks(note) end
        self:Refresh()
    end

    -- 內文都是即時寫回 note 的（OnTextChanged），這支只負責把焦點放掉，
    -- 讓還沒送出的最後一次輸入落地
    function ed:Commit()
        for _, row in ipairs(self.rows) do
            if row:IsShown() and row.editBox and row.editBox:HasFocus() then
                row.editBox:ClearFocus()
            end
        end
    end

    scroll:SetScript("OnSizeChanged", function(self, w)
        ed.container:SetWidth(math.max(1, w))
        ed:Relayout()
    end)

    return ed
end

------------------------------------------------------------
-- 唯讀檢視
--
-- 副本浮動視窗與分享預覽共用。勾選框仍然點得動（打副本時要能邊打邊打勾），
-- 但文字改不了——要改內容請開編輯視窗。
------------------------------------------------------------
-- 所有活著的唯讀檢視。戰鬥計時換人時要一起更新，而數量最多兩個
-- （副本浮動視窗＋分享預覽），不值得為它做弱表。
local viewers = {}

function Blocks.CreateViewer(scroll, opts)
    opts = opts or {}
    local vw = {
        scroll    = scroll,
        container = scroll.child,
        rows      = {},
        note      = nil,
        onChanged = opts.onChanged,   -- 勾選框被點時通知宿主（存檔／同步）
    }

    local function CreateRow()
        local row = CreateFrame("Frame", nil, vw.container)
        row:SetHeight(ROW_MIN_H)

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(18, 18)
        row.check:SetPoint("TOPLEFT", 0, -1)
        row.check:Hide()
        row.check:SetScript("OnClick", function(self)
            local b = row._block
            if b and b.type == T_CHECKBOX then
                b.checked = self:GetChecked() and true or false
                if vw.note then Notes.Touch(vw.note) end
                if vw.onChanged then vw.onChanged(vw.note, b) end
            end
        end)

        row.bullet = row:CreateTexture(nil, "OVERLAY")
        row.bullet:SetSize(4, 4)
        row.bullet:SetPoint("TOPLEFT", 5, -8)
        row.bullet:SetColorTexture(0.8, 0.8, 0.8, 1)
        row.bullet:Hide()

        row.num = row:CreateFontString(nil, "OVERLAY")
        row.num:SetFontObject(Media.fontBody)
        row.num:SetPoint("TOPLEFT", 0, -2)
        row.num:SetJustifyH("LEFT")
        row.num:Hide()

        -- 倒數欄：只有帶 {time:...} 的列才顯示
        row.time = row:CreateFontString(nil, "OVERLAY")
        row.time:SetFontObject(Media.fontBody)
        row.time:SetJustifyH("RIGHT")
        row.time:SetWidth(TIME_W - 6)
        row.time:Hide()

        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFontObject(Media.fontBody)
        row.text:SetJustifyH("LEFT")
        row.text:SetJustifyV("TOP")
        row.text:SetSpacing(2)
        return row
    end

    function vw:Relayout()
        local width = math.max(1, self.container:GetWidth())
        local y = 2
        for _, row in ipairs(self.rows) do
            if row:IsShown() then
                local indent = row._indent or 0
                local left = indent * INDENT_PX
                local timeW = row._timeSec and TIME_W or 0
                local textLeft = left + (row._gutter or 0) + timeW

                row.check:ClearAllPoints()
                row.check:SetPoint("TOPLEFT", left, -1)
                row.bullet:ClearAllPoints()
                row.bullet:SetPoint("TOPLEFT", left + 5, -8)
                row.num:ClearAllPoints()
                row.num:SetPoint("TOPLEFT", left, -2)
                row.time:ClearAllPoints()
                row.time:SetPoint("TOPLEFT", left + (row._gutter or 0), -2)

                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", textLeft, -2)
                row.text:SetWidth(math.max(20, width - textLeft - 4))

                local h = math.max(ROW_MIN_H - 6, math.ceil(row.text:GetStringHeight()) + 4)
                row:SetHeight(h)
                row._top = y                    -- 上緣位置（follow scroll 用）
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", self.container, "RIGHT", 0, 0)
                y = y + h + ROW_GAP
            end
        end
        scroll:SetContentHeight(math.max(1, y + 4))
    end

    function vw:Refresh()
        for _, row in ipairs(self.rows) do row:Hide() end
        local note = self.note
        if not note then
            scroll:SetContentHeight(1)
            return
        end
        Notes.EnsureBlocks(note)
        local numbers = ComputeNumbers(note.blocks)

        for i, b in ipairs(note.blocks) do
            local row = self.rows[i] or CreateRow()
            self.rows[i] = row
            row._block  = b
            row._indent = math.max(0, math.min(Notes.MAX_INDENT, b.indent or 0))

            row.check:Hide()
            row.bullet:Hide()
            row.num:Hide()

            if b.type == T_CHECKBOX then
                row.check:SetChecked(b.checked == true)
                row.check:SetEnabled(opts.interactive ~= false)
                row.check:Show()
                row._gutter = 22
            elseif b.type == T_BULLET then
                row.bullet:Show()
                row._gutter = 14
            elseif b.type == T_NUMBER then
                row.num:SetText((numbers[i] or 1) .. ".")
                row.num:Show()
                row._gutter = math.max(16, math.ceil(row.num:GetStringWidth()) + 6)
            else
                row._gutter = 0
            end

            -- 標記在**顯示**的時候才展開：存的永遠是玩家打的原文，
            -- 這樣編輯器改回去、分享出去的都還是原樣
            local display, seconds = ns.Tags.Render(b.text or "")
            row._timeSec = seconds
            row.time:SetShown(seconds ~= nil)
            row.text:SetText(display)
            if b.type == T_CHECKBOX and b.checked then
                row.text:SetTextColor(0.5, 0.5, 0.5)
            else
                row.text:SetTextColor(0.92, 0.92, 0.92)
            end
            row:Show()
        end
        self:Relayout()
        self:UpdateTimes()
        self:SyncTicker()
    end

    ------------------------------------------------------------
    -- 倒數
    --
    -- 沒在計時就顯示筆記上寫的那個時間點（靜態），計時中才變成剩幾秒。
    -- 顏色只有三階：還沒到＝一般、十秒內＝強調色、過去了＝暗。
    ------------------------------------------------------------
    function vw:UpdateTimes()
        local elapsed = ns.Clock.Elapsed()
        for _, row in ipairs(self.rows) do
            local sec = row:IsShown() and row._timeSec
            if sec then
                if elapsed then
                    local left = sec - elapsed
                    local neg = left < 0
                    local abs = math.abs(left)
                    row.time:SetText(("%s%d:%02d"):format(neg and "-" or "",
                        math.floor(abs / 60), math.floor(abs % 60)))
                    if neg then
                        row.time:SetTextColor(0.4, 0.4, 0.4)
                    elseif left <= 10 then
                        row.time:SetTextColor(W.Accent(1))
                    else
                        row.time:SetTextColor(0.75, 0.75, 0.75)
                    end
                else
                    row.time:SetText(("%d:%02d"):format(math.floor(sec / 60), sec % 60))
                    row.time:SetTextColor(0.55, 0.55, 0.55)
                end
            end
        end
        if opts.follow and elapsed then self:FollowScroll(elapsed) end
    end

    ------------------------------------------------------------
    -- 跟著時間軸捲動：把「下一個還沒到的時間點」擺在視窗上緣附近，
    -- 讓即將發生的事一直在畫面上（跟團隊筆記那類插件的行為一致）。
    --
    -- 只在計時中跑，而且玩家手動捲動後 5 秒內不搶方向盤 —— 不然玩家想往回看
    -- 前面的段落，畫面會一直被拉回去。
    ------------------------------------------------------------
    function vw:FollowScroll(elapsed)
        if self._grabbed and (GetTime() - self._grabbed) < 5 then return end
        -- 找第一個時間點還在未來的列；全都過去了就用最後一個有時間的
        local target
        for _, row in ipairs(self.rows) do
            if row:IsShown() and row._timeSec then
                if row._timeSec >= elapsed then target = row break end
                target = row
            end
        end
        if not target or not target._top then return end
        local margin = 8
        local want = math.max(0, target._top - margin)
        local maxScroll = math.max(0, self.container:GetHeight() - scroll:GetHeight())
        want = math.min(want, maxScroll)
        if math.abs((scroll:GetVerticalScroll() or 0) - want) > 1 then
            self._suppressGrab = true       -- 這一次是程式捲的，不算玩家插手
            scroll:SetVerticalScroll(want)
            self._suppressGrab = false
        end
    end

    -- 只有「看得見 ＋ 有倒數 ＋ 正在計時」三個條件都成立才跑 ticker
    function vw:SyncTicker()
        local want = false
        if scroll:IsVisible() and ns.Clock.IsRunning() then
            for _, row in ipairs(self.rows) do
                if row:IsShown() and row._timeSec then want = true break end
            end
        end
        if want and not self.ticker then
            self.ticker = C_Timer.NewTicker(TICK, function() vw:UpdateTimes() end)
        elseif not want and self.ticker then
            self.ticker:Cancel()
            self.ticker = nil
            self:UpdateTimes()
        end
    end

    function vw:SetNote(note)
        self.note = note
        self:Refresh()
    end

    viewers[#viewers + 1] = vw

    scroll:SetScript("OnSizeChanged", function(self, w)
        vw.container:SetWidth(math.max(1, w))
        vw:Relayout()
    end)

    -- 玩家自己捲動 → 暫停自動跟隨（程式自己捲的那次不算，見 _suppressGrab）
    if opts.follow then
        scroll:HookScript("OnVerticalScroll", function()
            if not vw._suppressGrab then vw._grabbed = GetTime() end
        end)
    end

    return vw
end

------------------------------------------------------------
-- 戰鬥計時換人（開打、打完、開始／結束測試）→ 所有檢視重新評估要不要跑 ticker
------------------------------------------------------------
ns.RegisterCallback("ClockChanged", "blocks", function()
    for _, vw in ipairs(viewers) do
        vw:UpdateTimes()
        vw:SyncTicker()
    end
end)

------------------------------------------------------------
-- 分組名單改了 → 唯讀檢視要重畫（{p:主坦} 顯示的是解出來的名字）
------------------------------------------------------------
ns.RegisterCallback("RosterChanged", "blocks", function()
    for _, vw in ipairs(viewers) do vw:Refresh() end
end)
