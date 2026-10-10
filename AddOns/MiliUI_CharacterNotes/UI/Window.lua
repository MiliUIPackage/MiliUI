------------------------------------------------------------
-- 筆記本主視窗：分頁 ＋ 工具列 ＋ 清單
--
-- 兩個分頁（戰隊共用／角色專屬）共用同一個清單與同一組列（列會回收），
-- 差別只在餵給它的陣列；都是一維、可拖曳排序。
--
-- 編輯是另一個視窗（UI/Editor.lua），依附在這個視窗右側。
------------------------------------------------------------
local _, ns = ...

ns.Window = {}
local Window = ns.Window

local W, P, L = ns.W, ns.P, ns.L
local Notes, Media = ns.Notes, ns.Media

local WINDOW_W, WINDOW_H = 380, 520
local HEADER_H  = 24
local TAB_H     = 22
local TOOLBAR_H = 26
local ROW_H     = 26
local PAD       = 8

local TAB_ACCOUNT  = Notes.SCOPE_ACCOUNT
local TAB_CHAR     = Notes.SCOPE_CHAR

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local frame, listScroll, listContent, searchRow, searchBox, toolbar
local tabButtons, highlightTab = {}, nil
local addButton, charButton, emptyLabel
local deletePopup, deleteTarget

local currentTab     = TAB_ACCOUNT
local selectedChar               -- 角色專屬分頁看的是哪個分身
local filterText     = ""
local selectedNoteID

local rows = {}
local rowItems = {}
local dragState, dragLine

-- 前向宣告：列的 OnClick 在它之前就寫好了，不宣告的話它會被當成全域
-- （`luac -p` 抓不到，只有 `luac -l` 掃 _ENV 讀取才看得出來）
local Refresh

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Matches(text)
    if filterText == "" then return true end
    return tostring(text or ""):lower():find(filterText, 1, true) ~= nil
end

local function NoteMatches(note)
    if filterText == "" then return true end
    if Matches(note.title) then return true end
    if type(note.blocks) == "table" then
        for _, b in ipairs(note.blocks) do
            if Matches(b.text) then return true end
        end
    end
    return Matches(note.content)
end

local function CurrentList()
    if currentTab == TAB_CHAR then
        return Notes.CharList(selectedChar or ns.CurrentCharKey())
    end
    return Notes.AccountList()
end

------------------------------------------------------------
-- 開啟編輯視窗
------------------------------------------------------------
local function OpenNote(note)
    selectedNoteID = note and note.id or nil
    if not note then
        ns.Editor.Close()
        return
    end
    ns.Editor.Open(note, {
        label = (currentTab == TAB_CHAR) and L["Character note"] or L["Shared notes"],
        onTitleChanged = function() Refresh() end,
        share = { kind = "note" },
    })
end

------------------------------------------------------------
-- 清單資料：攤成「列描述」
------------------------------------------------------------
local function BuildFlatItems(out)
    local list = CurrentList()
    for i, note in ipairs(list) do
        if NoteMatches(note) then
            out[#out + 1] = {
                note     = note,
                index    = i,
                label    = note.title ~= "" and note.title or L["Untitled"],
                selected = note.id == selectedNoteID,
                dot      = not Notes.IsEmpty(note),
            }
        end
    end
end

------------------------------------------------------------
-- 右鍵選單
------------------------------------------------------------
local function ConfirmDelete(label, onAccept)
    if not deletePopup then
        deletePopup = W.CreateConfirmPopup(frame, 330, "", function()
            if deleteTarget then deleteTarget() end
            deleteTarget = nil
        end)
    end
    deleteTarget = onAccept
    deletePopup.text:SetText(L["Delete \"%s\"? This cannot be undone."]:format(label))
    deletePopup:Show()
end

local function ShowNoteMenu(row)
    local note = row._note
    if not note then return end
    local fromChar = (currentTab == TAB_CHAR)
    local items = {
        { text = note.title ~= "" and note.title or L["Untitled"], isTitle = true },
        { text = L["Share..."], onClick = function()
            ns.Share.ShowShareMenu(row, note, { kind = "note" })
        end },
        { text = fromChar and L["Move to shared notes"] or L["Move to this character"],
          onClick = function()
            local from = CurrentList()
            local to = fromChar and Notes.AccountList()
                                or Notes.CharList(selectedChar or ns.CurrentCharKey())
            for i, n in ipairs(from) do
                if n.id == note.id then
                    table.remove(from, i)
                    table.insert(to, 1, n)
                    break
                end
            end
            if ns.Editor.IsEditing(note) then ns.Editor.Close() end
            selectedNoteID = nil
            Refresh()
          end },
        { isSeparator = true },
        { text = "|cffff5555" .. L["Delete"] .. "|r", onClick = function()
            ConfirmDelete(note.title or L["Untitled"], function()
                local list = CurrentList()
                for i, n in ipairs(list) do
                    if n.id == note.id then table.remove(list, i) break end
                end
                if ns.Editor.IsEditing(note) then ns.Editor.Close() end
                selectedNoteID = nil
                Refresh()
            end)
        end },
    }
    W.Menu.Show(items, row)
end

------------------------------------------------------------
-- 拖曳排序
------------------------------------------------------------
local function CancelDrag()
    dragState = nil
    if dragLine then dragLine:Hide() end
    if listScroll then listScroll:SetScript("OnUpdate", nil) end
    for _, r in ipairs(rows) do
        if r:GetAlpha() < 1 then r:SetAlpha(1) end
    end
end

local function DragMonitor()
    if not dragState then return end
    local hovered, last
    for _, r in ipairs(rows) do
        if r:IsShown() then
            last = r
            if r:IsMouseOver() then hovered = r break end
        end
    end

    local _, cy = GetCursorPosition()
    local ref = hovered or last
    if not ref then return end
    cy = cy / ref:GetEffectiveScale()

    if hovered then
        local mid = hovered:GetTop() - hovered:GetHeight() / 2
        local idx = hovered._index or 1
        dragState.targetIndex = (cy >= mid) and idx or (idx + 1)
        dragLine:ClearAllPoints()
        if cy >= mid then
            dragLine:SetPoint("TOPLEFT", hovered, "TOPLEFT", 0, 1)
            dragLine:SetPoint("TOPRIGHT", hovered, "TOPRIGHT", 0, 1)
        else
            dragLine:SetPoint("BOTTOMLEFT", hovered, "BOTTOMLEFT", 0, -1)
            dragLine:SetPoint("BOTTOMRIGHT", hovered, "BOTTOMRIGHT", 0, -1)
        end
        dragLine:Show()
    elseif cy < last:GetBottom() then
        dragState.targetIndex = #CurrentList() + 1
        dragLine:ClearAllPoints()
        dragLine:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", 0, -1)
        dragLine:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, -1)
        dragLine:Show()
    else
        dragLine:Hide()
        dragState.targetIndex = nil
    end
end

------------------------------------------------------------
-- 列
------------------------------------------------------------
-- 列的三態只換底色明暗，邊框一律留 Stylize 的黑。原本選中／滑過是把邊框換成 accent
-- 亮線，但捲動區最上緣那一列的上邊會被裁掉，四邊只亮三邊反而比完全不亮還礙眼。亮框線
-- 整個讓給設定視窗當記號，內容視窗一律黑框，兩種視窗一眼分得出來。
local ROW_FILL      = { 0.115, 0.115, 0.115, 1 }
local ROW_FILL_OVER = { 0.23, 0.23, 0.23, 1 }   -- 對齊 Widgets 按鈕 hover 的 0.23

local function StyleRow(row, selected, hover)
    if selected then
        row:SetBackdropColor(W.Accent(hover and 0.5 or 0.35))
    else
        row:SetBackdropColor(unpack(hover and ROW_FILL_OVER or ROW_FILL))
    end
end

local function CreateRow()
    local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
    row:SetHeight(P.Scale(ROW_H))
    W.Stylize(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFontObject(Media.fontBody)
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetPoint("RIGHT", -18, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetTextColor(0.92, 0.92, 0.92)
    row.text:SetWordWrap(false)

    row.dot = row:CreateTexture(nil, "OVERLAY")
    row.dot:SetSize(5, 5)
    row.dot:SetPoint("RIGHT", -7, 0)
    row.dot:SetColorTexture(W.Accent(1))

    row:SetScript("OnEnter", function(self)
        StyleRow(self, self._selected, true)
    end)
    row:SetScript("OnLeave", function(self)
        StyleRow(self, self._selected, false)
    end)

    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ShowNoteMenu(self) return end
        OpenNote(self._note)
        Refresh()
    end)

    row:SetScript("OnDragStart", function(self)
        if filterText ~= "" then return end        -- 篩選中的順序不是真實順序
        dragState = { sourceID = self._note.id, targetIndex = nil }
        self:SetAlpha(0.4)
        listScroll:SetScript("OnUpdate", DragMonitor)
    end)

    row:SetScript("OnDragStop", function()
        local state = dragState
        CancelDrag()
        if not (state and state.targetIndex) then return end
        local list = CurrentList()
        local srcIdx
        for i, n in ipairs(list) do
            if n.id == state.sourceID then srcIdx = i break end
        end
        if not srcIdx then return end
        local note = table.remove(list, srcIdx)
        local tgt = state.targetIndex
        if tgt > srcIdx then tgt = tgt - 1 end
        tgt = math.max(1, math.min(#list + 1, tgt))
        table.insert(list, tgt, note)
        Refresh()
    end)

    return row
end

local function ConfigureRow(row, item)
    row._note        = item.note
    row._index       = item.index
    row._selected    = item.selected == true
    row:SetAlpha(1)
    row.text:SetText(item.label or "?")
    row.dot:SetShown(item.dot == true)
    StyleRow(row, row._selected)
end

------------------------------------------------------------
-- 重繪
------------------------------------------------------------
Refresh = function()
    if not frame then return end

    -- 工具列跟著分頁換
    charButton:SetShown(currentTab == TAB_CHAR)
    addButton:ClearAllPoints()
    if currentTab == TAB_CHAR then
        addButton:SetPoint("LEFT", charButton, "RIGHT", 4, 0)
    else
        addButton:SetPoint("LEFT", toolbar, "LEFT", 4, 0)
    end
    if currentTab == TAB_CHAR then
        local entry = Notes.CharEntry(selectedChar or ns.CurrentCharKey())
        local dup = Notes.DuplicateNames()
        charButton.text:SetText(Media.CharLabel(entry.meta, 14, dup[entry.meta.name]))
    end

    wipe(rowItems)
    BuildFlatItems(rowItems)

    local y = 2
    for i, item in ipairs(rowItems) do
        local row = rows[i] or CreateRow()
        rows[i] = row
        ConfigureRow(row, item)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -y)
        row:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)
        row:Show()
        y = y + ROW_H + 2
    end
    for i = #rowItems + 1, #rows do rows[i]:Hide() end
    -- 寬度自己補一次：列是錨在 listContent 左右緣的，而 scroll child 的初始寬度
    -- 是 1 —— 只靠 OnSizeChanged 補的話，第一次畫出來有機會是一排 1px 的線
    listContent:SetWidth(math.max(1, listScroll:GetWidth()))
    listContent:SetHeight(math.max(1, y + 2))

    -- 空狀態說明
    local msg
    if #rowItems == 0 then
        if filterText ~= "" then
            msg = L["Nothing matches your search."]
        else
            msg = L["No notes yet. Use New to write one."]
        end
    end
    emptyLabel:SetText(msg or "")
    emptyLabel:SetShown(msg ~= nil)
end

Window.Refresh = Refresh

------------------------------------------------------------
-- 分頁切換
------------------------------------------------------------
local function SwitchTab(id)
    if currentTab == id then return end
    ns.Editor.Commit()
    currentTab = id
    selectedNoteID = nil
    ns.Editor.Close()
    if searchBox then searchBox:SetText("") end
    filterText = ""

    local key = ns.CurrentCharKey()
    ns.db.perChar[key] = ns.db.perChar[key] or {}
    ns.db.perChar[key].lastScope = id

    Refresh()
end

local function ShowCharMenu(anchor)
    local dup = Notes.DuplicateNames()
    local items = { { text = L["Pick a character"], isTitle = true } }
    for _, key in ipairs(Notes.SortedCharKeys()) do
        local entry = Notes.CharEntry(key)
        local k = key
        items[#items + 1] = {
            text = Media.CharLabel(entry.meta, 16, dup[entry.meta.name]),
            isActive = key == (selectedChar or ns.CurrentCharKey()),
            onClick = function()
                ns.Editor.Close()
                selectedChar = k
                selectedNoteID = nil
                if searchBox then searchBox:SetText("") end
                filterText = ""
                Refresh()
            end,
        }
    end
    W.Menu.Show(items, anchor)
end

------------------------------------------------------------
-- 建立視窗
------------------------------------------------------------
local function SavePos()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.windows.main = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
end

local function RestorePos()
    local p = ns.db.windows.main
    frame:ClearAllPoints()
    if type(p) == "table" and p.point then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
end

local function Build()
    if frame then return end

    frame = W.CreateFrame("MiliUINote_Window", UIParent, WINDOW_W, WINDOW_H)
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(50)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    RestorePos()
    W.CloseOnEscape(frame)

    -- 標題列兼拖曳把手
    local header = W.CreateFrame(nil, frame)
    header:SetHeight(P.Scale(HEADER_H))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePos()
        ns.Editor.Reanchor()
    end)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontNormal)
    title:SetPoint("LEFT", 8, 0)
    title:SetText(L["MiliUI Character Notes"])
    title:SetTextColor(W.Accent(1))

    local close = W.CreateButton(header, "", "red", 18, 18)
    close:SetPoint("RIGHT", -3, 0)
    local closeX = close:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(10, 10)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() Window.Hide() end)

    local settings = W.CreateButton(header, "", "normal", 18, 18)
    settings:SetPoint("RIGHT", close, "LEFT", -3, 0)
    local gear = settings:CreateTexture(nil, "OVERLAY")
    -- ICONS 底下的素材暴雪只增不減；Interface\Buttons\ 的檔案改版時會靜默消失
    gear:SetTexture("Interface\\ICONS\\INV_Misc_Gear_01")
    gear:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    gear:SetSize(12, 12)
    gear:SetPoint("CENTER")
    settings:SetScript("OnClick", function() ns.OpenOptions() end)
    settings:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self._colors[2]))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Settings"])
        GameTooltip:Show()
    end)
    settings:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self._colors[1]))
        GameTooltip:Hide()
    end)

    -- 分頁
    local TABS = {
        { id = TAB_ACCOUNT,  label = L["Shared"] },
        { id = TAB_CHAR,     label = L["Character"] },
    }
    local tabW = (WINDOW_W - PAD * 2 - 4 * (#TABS - 1)) / #TABS
    local prev
    for i, t in ipairs(TABS) do
        local b = W.CreateButton(frame, t.label, "accent-hover", tabW, TAB_H)
        b.id = t.id
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PAD, -PAD)
        end
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, SwitchTab)

    -- 工具列
    toolbar = CreateFrame("Frame", nil, frame)
    toolbar:SetHeight(P.Scale(TOOLBAR_H))
    toolbar:SetPoint("TOPLEFT", tabButtons[1], "BOTTOMLEFT", 0, -6)
    toolbar:SetPoint("TOPRIGHT", tabButtons[#tabButtons], "BOTTOMRIGHT", 0, -6)

    charButton = W.CreateButton(toolbar, "", "normal", 150, TOOLBAR_H - 2)
    charButton:SetPoint("LEFT", 4, 0)
    charButton.text = charButton:GetFontString()
    charButton:SetScript("OnClick", function(self) ShowCharMenu(self) end)

    addButton = W.CreateButton(toolbar, L["New"], "accent-hover", 56, TOOLBAR_H - 2)
    addButton:SetPoint("LEFT", toolbar, "LEFT", 4, 0)
    addButton:SetScript("OnClick", function()
        if searchBox then searchBox:SetText("") end
        filterText = ""
        local list = CurrentList()
        local note = Notes.New(Notes.NextTitle(list))
        table.insert(list, 1, note)
        OpenNote(note)
        Refresh()
    end)

    -- 搜尋：放大鏡當開關，搜尋條插在工具列與清單之間
    local searchToggle = W.CreateButton(toolbar, "", "normal", TOOLBAR_H - 2, TOOLBAR_H - 2)
    searchToggle:SetPoint("RIGHT", -4, 0)
    local searchIcon = searchToggle:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("CENTER")
    searchIcon:SetVertexColor(0.9, 0.9, 0.9)

    searchRow = CreateFrame("Frame", nil, frame)
    searchRow:SetHeight(P.Scale(TOOLBAR_H))
    searchRow:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    searchRow:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -4)
    searchRow:Hide()

    searchBox = W.CreateEditBox(searchRow, WINDOW_W - PAD * 2, TOOLBAR_H)
    searchBox:SetPoint("TOPLEFT", 0, 0)
    searchBox:SetPoint("BOTTOMRIGHT", 0, 0)
    searchBox:SetMaxLetters(50)
    searchBox:SetTextInsets(6, 6, 0, 0)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFontObject(W.fontSmall)
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetTextColor(0.5, 0.5, 0.5)
    placeholder:SetText(L["Search titles and text..."])

    local listBg = W.CreateFrame(nil, frame)
    local function LayoutList()
        local top = searchRow:IsShown() and searchRow or toolbar
        listBg:ClearAllPoints()
        listBg:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -4)
        listBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
    end
    LayoutList()

    local function ToggleSearch()
        if searchRow:IsShown() then
            searchRow:Hide()
            searchBox:SetText("")
            searchBox:ClearFocus()
        else
            searchRow:Show()
            searchBox:SetFocus()
        end
        LayoutList()
    end
    searchToggle:SetScript("OnClick", ToggleSearch)
    searchBox:SetScript("OnEscapePressed", ToggleSearch)
    searchBox:SetScript("OnTextChanged", function(self)
        filterText = (self:GetText() or ""):lower()
        placeholder:SetShown(filterText == "")
        Refresh()
    end)

    listScroll = W.CreateScrollFrame(listBg)
    listScroll:SetPoint("TOPLEFT", 2, -2)
    listScroll:SetPoint("BOTTOMRIGHT", -20, 2)
    listContent = listScroll.child

    dragLine = listContent:CreateTexture(nil, "OVERLAY")
    dragLine:SetColorTexture(W.Accent(1))
    dragLine:SetHeight(P.Scale(2))
    dragLine:Hide()

    emptyLabel = listBg:CreateFontString(nil, "OVERLAY")
    emptyLabel:SetFontObject(W.fontSmall)
    emptyLabel:SetPoint("TOPLEFT", 14, -14)
    emptyLabel:SetPoint("TOPRIGHT", -14, -14)
    emptyLabel:SetJustifyH("LEFT")
    emptyLabel:SetSpacing(3)
    emptyLabel:Hide()

    frame:SetScript("OnHide", function()
        CancelDrag()
        ns.Editor.Commit()
        ns.Editor.Close()
        W.Menu.Hide()
    end)

    -- 還原上次的分頁
    local saved = ns.db.perChar[ns.CurrentCharKey()]
    local startTab = saved and saved.lastScope
    -- 拔掉的副本分頁存檔裡可能還留著 "instance"，一併退回戰隊共用
    if startTab ~= TAB_CHAR then startTab = TAB_ACCOUNT end
    currentTab = startTab
    for _, b in ipairs(tabButtons) do
        if b.id == startTab then highlightTab(b) break end
    end
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Window.Frame()
    return frame
end

function Window.Show()
    Build()
    frame:Show()
    frame:Raise()
    Refresh()
end

function Window.Hide()
    if frame then frame:Hide() end
end

function Window.Toggle()
    Build()
    if frame:IsShown() then Window.Hide() else Window.Show() end
end

function Window.IsShown()
    return frame and frame:IsShown()
end

ns.RegisterCallback("NotesChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)

ns.RegisterCallback("SettingsChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
