------------------------------------------------------------
-- MiliUI: 角色筆記
-- 在角色面板新增「筆記」標籤頁
-- 左側筆記列表 + 右側編輯區，支援戰隊共用 / 角色專屬
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local S = MiliUI.Style

------------------------------------------------------------
-- 常數
------------------------------------------------------------
local NOTE_SCOPE_ACCOUNT = "account"
local NOTE_SCOPE_CHAR    = "char"
local LIST_BTN_HEIGHT    = 28
local TOOLBAR_HEIGHT     = 30
local NOTE_PADDING       = 8
local EDITOR_WIDTH       = 420
local EDITOR_HEIGHT      = 500
local EDITOR_HEADER_HEIGHT = 24

------------------------------------------------------------
-- DB
------------------------------------------------------------
local function GetAccountDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.notes then MiliUI_DB.notes = {} end
    return MiliUI_DB.notes
end

local function GetCharDB()
    if not MiliUI_CharDB then MiliUI_CharDB = {} end
    if not MiliUI_CharDB.notes then MiliUI_CharDB.notes = {} end
    return MiliUI_CharDB.notes
end

local function GetNotesForScope(scope)
    if scope == NOTE_SCOPE_CHAR then
        return GetCharDB()
    end
    return GetAccountDB()
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local currentScope    = NOTE_SCOPE_ACCOUNT
local selectedNoteID  = nil
local noteListButtons = {}
local dragState       = nil  -- { sourceID = string, targetIndex = number }
local dragLine                 -- 拖曳時插入位置的指示線

-- 前向宣告
local RefreshNoteList, LoadNoteToEditor, SaveCurrentNote, ClearEditor

------------------------------------------------------------
-- 產生唯一 ID
------------------------------------------------------------
local function GenerateID()
    return time() .. "-" .. math.random(10000, 99999)
end

------------------------------------------------------------
-- UI 建構（延遲到角色面板載入後）
------------------------------------------------------------
local tabFrame       -- 筆記標籤頁的主容器（CharacterFrame 內）
local toolbar        -- 頂部工具列
local listBg         -- 列表背景（佔滿 tabFrame 下半部）
local listScroll     -- 列表捲動區
local listContent    -- 列表捲動內容
local editorFrame    -- 獨立浮動編輯視窗（parent: UIParent）
local titleEditBox   -- 標題輸入
local bodyEditBox    -- 內文輸入
local scopeButton    -- 帳號/角色 切換按鈕
local addButton      -- 新增按鈕
local charTab        -- 標籤按鈕

local function BuildUI()
    if tabFrame then return end

    ------------------------------------------------------------
    -- 主容器（parent 到 CharacterFrame、提高 strata，避免 Inset 內部元素遮擋）
    ------------------------------------------------------------
    local anchorRef = CharacterFrame.Inset or CharacterFrame
    tabFrame = CreateFrame("Frame", "MiliUI_CharacterNotesFrame", CharacterFrame, "BackdropTemplate")
    tabFrame:SetPoint("TOPLEFT", anchorRef, "TOPLEFT", 0, 0)
    tabFrame:SetPoint("BOTTOMRIGHT", anchorRef, "BOTTOMRIGHT", 0, 0)
    tabFrame:SetFrameStrata("HIGH")
    tabFrame:SetFrameLevel(50)
    tabFrame:Hide()
    tabFrame:SetBackdrop(S.Backdrop)
    tabFrame:SetBackdropColor(unpack(S.Colors.panelBg))
    tabFrame:SetBackdropBorderColor(unpack(S.Colors.border))

    ------------------------------------------------------------
    -- 頂部工具列
    ------------------------------------------------------------
    toolbar = CreateFrame("Frame", nil, tabFrame, "BackdropTemplate")
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    toolbar:SetPoint("TOPLEFT", NOTE_PADDING, -NOTE_PADDING)
    toolbar:SetPoint("TOPRIGHT", -NOTE_PADDING, -NOTE_PADDING)
    toolbar:SetBackdrop(S.Backdrop)
    toolbar:SetBackdropColor(unpack(S.Colors.bg))
    toolbar:SetBackdropBorderColor(unpack(S.Colors.border))

    -- 帳號/角色 切換按鈕
    scopeButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    scopeButton:SetSize(120, TOOLBAR_HEIGHT - 4)
    scopeButton:SetPoint("LEFT", 4, 0)
    S.ApplyButton(scopeButton, "戰隊共用", nil, 11)

    scopeButton:SetScript("OnClick", function()
        SaveCurrentNote()
        if currentScope == NOTE_SCOPE_ACCOUNT then
            currentScope = NOTE_SCOPE_CHAR
            scopeButton._miliText:SetText("角色專屬")
        else
            currentScope = NOTE_SCOPE_ACCOUNT
            scopeButton._miliText:SetText("戰隊共用")
        end
        selectedNoteID = nil
        ClearEditor()
        RefreshNoteList()
    end)

    -- 新增按鈕
    addButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    addButton:SetSize(60, TOOLBAR_HEIGHT - 4)
    addButton:SetPoint("LEFT", scopeButton, "RIGHT", 4, 0)
    S.ApplyButton(addButton, "新增", nil, 11)

    addButton:SetScript("OnClick", function()
        SaveCurrentNote()
        local notes = GetNotesForScope(currentScope)
        local newNote = {
            id      = GenerateID(),
            title   = "新筆記",
            content = "",
            time    = time(),
        }
        table.insert(notes, 1, newNote)
        selectedNoteID = newNote.id
        RefreshNoteList()
        LoadNoteToEditor(newNote)
        titleEditBox:SetFocus()
        titleEditBox:HighlightText()
    end)

    ------------------------------------------------------------
    -- 筆記列表（佔滿 tabFrame 下半部）
    ------------------------------------------------------------
    listBg = CreateFrame("Frame", nil, tabFrame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    listBg:SetPoint("BOTTOMRIGHT", -NOTE_PADDING, NOTE_PADDING)
    listBg:SetBackdrop(S.Backdrop)
    listBg:SetBackdropColor(unpack(S.Colors.bg))
    listBg:SetBackdropBorderColor(unpack(S.Colors.border))

    listScroll = CreateFrame("ScrollFrame", "MiliUI_NotesListScroll", listBg, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 2, -2)
    listScroll:SetPoint("BOTTOMRIGHT", -22, 2)

    listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(1, 1)
    listScroll:SetScrollChild(listContent)

    -- 動態調整 listContent 寬度跟隨 listScroll
    listScroll:SetScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(math.max(1, w))
    end)

    -- 拖曳排序：插入位置指示線
    dragLine = listContent:CreateTexture(nil, "OVERLAY")
    dragLine:SetColorTexture(unpack(S.Colors.borderHover))
    dragLine:SetHeight(2)
    dragLine:Hide()

    -- 拖曳監控：依據游標位置更新 dragLine 與 targetIndex
    listScroll:SetScript("OnUpdate", function()
        if not dragState then
            if dragLine and dragLine:IsShown() then dragLine:Hide() end
            return
        end

        local notes = GetNotesForScope(currentScope)
        local hovered
        for _, b in ipairs(noteListButtons) do
            if b:IsShown() and b:IsMouseOver() then
                hovered = b
                break
            end
        end

        if hovered then
            local _, cy = GetCursorPosition()
            cy = cy / hovered:GetEffectiveScale()
            local mid = hovered:GetTop() - hovered:GetHeight() / 2
            local idx = hovered._index or 1
            local targetIdx = (cy >= mid) and idx or (idx + 1)
            dragState.targetIndex = targetIdx

            dragLine:ClearAllPoints()
            if cy >= mid then
                dragLine:SetPoint("TOPLEFT", hovered, "TOPLEFT", 0, 1)
                dragLine:SetPoint("TOPRIGHT", hovered, "TOPRIGHT", 0, 1)
            else
                dragLine:SetPoint("BOTTOMLEFT", hovered, "BOTTOMLEFT", 0, -1)
                dragLine:SetPoint("BOTTOMRIGHT", hovered, "BOTTOMRIGHT", 0, -1)
            end
            dragLine:Show()
        else
            -- 游標不在任何按鈕上：找最後一個可見按鈕，若游標在它下方就 drop 到尾端
            local last
            for _, b in ipairs(noteListButtons) do
                if b:IsShown() then last = b end
            end
            if last then
                local _, cy = GetCursorPosition()
                cy = cy / last:GetEffectiveScale()
                if cy < last:GetBottom() then
                    dragState.targetIndex = #notes + 1
                    dragLine:ClearAllPoints()
                    dragLine:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", 0, -1)
                    dragLine:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, -1)
                    dragLine:Show()
                else
                    dragLine:Hide()
                    dragState.targetIndex = nil
                end
            end
        end
    end)

    ------------------------------------------------------------
    -- 獨立浮動編輯視窗（parent: UIParent）
    ------------------------------------------------------------
    editorFrame = CreateFrame("Frame", "MiliUI_NoteEditorFrame", UIParent, "BackdropTemplate")
    editorFrame:SetSize(EDITOR_WIDTH, EDITOR_HEIGHT)
    editorFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 8, 0)
    editorFrame:SetFrameStrata("HIGH")
    editorFrame:SetFrameLevel(50)
    editorFrame:SetClampedToScreen(true)
    editorFrame:SetMovable(true)
    editorFrame:Hide()
    editorFrame:SetBackdrop(S.Backdrop)
    editorFrame:SetBackdropColor(unpack(S.Colors.panelBg))
    editorFrame:SetBackdropBorderColor(unpack(S.Colors.border))

    -- 標題列（兼拖曳把手）
    local header = CreateFrame("Frame", nil, editorFrame, "BackdropTemplate")
    header:SetHeight(EDITOR_HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetBackdrop(S.Backdrop)
    header:SetBackdropColor(unpack(S.Colors.bg))
    header:SetBackdropBorderColor(unpack(S.Colors.border))
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() editorFrame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        editorFrame:StopMovingOrSizing()
        -- 紀錄使用者調整過位置，之後不再跟隨 CharacterFrame 的預設錨點
        editorFrame._userMoved = true
    end)

    local headerText = header:CreateFontString(nil, "OVERLAY")
    headerText:SetFont(S.Font, 12, "OUTLINE")
    headerText:SetPoint("CENTER", 0, 0)
    headerText:SetText("筆記內容")
    headerText:SetTextColor(unpack(S.Colors.text))

    -- 標題輸入
    titleEditBox = CreateFrame("EditBox", "MiliUI_NoteTitleEdit", editorFrame, "BackdropTemplate")
    titleEditBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -8)
    titleEditBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -8, -8)
    titleEditBox:SetHeight(28)
    titleEditBox:SetFontObject("GameFontNormalLarge")
    titleEditBox:SetAutoFocus(false)
    titleEditBox:SetMaxLetters(200)
    titleEditBox:SetBackdrop(S.Backdrop)
    titleEditBox:SetBackdropColor(0.1, 0.1, 0.15, 0.5)
    titleEditBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
    titleEditBox:SetTextInsets(6, 6, 0, 0)

    titleEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    titleEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        bodyEditBox:SetFocus()
    end)
    titleEditBox:SetScript("OnEditFocusLost", function() SaveCurrentNote() end)

    -- 分隔線
    local editorDivider = editorFrame:CreateTexture(nil, "ARTWORK")
    editorDivider:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    editorDivider:SetHeight(1)
    editorDivider:SetPoint("TOPLEFT", titleEditBox, "BOTTOMLEFT", 0, -6)
    editorDivider:SetPoint("TOPRIGHT", titleEditBox, "BOTTOMRIGHT", 0, -6)

    -- 內文捲動容器
    local bodyScroll = CreateFrame("ScrollFrame", "MiliUI_NoteBodyScroll", editorFrame, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", editorDivider, "BOTTOMLEFT", 0, -6)
    bodyScroll:SetPoint("BOTTOMRIGHT", -26, 8)

    bodyEditBox = CreateFrame("EditBox", "MiliUI_NoteBodyEdit", bodyScroll)
    bodyEditBox:SetWidth(bodyScroll:GetWidth() or EDITOR_WIDTH - 30)
    bodyEditBox:SetFontObject("ChatFontNormal")
    bodyEditBox:SetAutoFocus(false)
    bodyEditBox:SetMultiLine(true)
    bodyEditBox:SetMaxLetters(0)
    bodyEditBox:SetTextInsets(6, 6, 4, 4)
    bodyEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    bodyEditBox:SetScript("OnEditFocusLost", function() SaveCurrentNote() end)
    bodyScroll:SetScrollChild(bodyEditBox)

    -- 當 bodyScroll 大小改變時，同步 EditBox 寬度
    bodyScroll:SetScript("OnSizeChanged", function(self, w)
        bodyEditBox:SetWidth(math.max(1, w))
    end)

    ClearEditor()
end

------------------------------------------------------------
-- 移動 / 刪除筆記
------------------------------------------------------------
local function DeleteNoteByID(noteID, scope)
    local notes = GetNotesForScope(scope or currentScope)
    for i, note in ipairs(notes) do
        if note.id == noteID then
            table.remove(notes, i)
            return true
        end
    end
    return false
end

local function MoveNoteToScope(noteID, fromScope, toScope)
    if fromScope == toScope then return false end
    local from = GetNotesForScope(fromScope)
    local to   = GetNotesForScope(toScope)
    for i, note in ipairs(from) do
        if note.id == noteID then
            table.remove(from, i)
            table.insert(to, 1, note)
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- 右鍵內容選單
------------------------------------------------------------
local function ShowNoteContextMenu(btn)
    local noteID    = btn._noteID
    local thisScope = currentScope
    local otherScope = (thisScope == NOTE_SCOPE_ACCOUNT) and NOTE_SCOPE_CHAR or NOTE_SCOPE_ACCOUNT
    local moveLabel = (thisScope == NOTE_SCOPE_ACCOUNT) and "移到角色專屬" or "移到戰隊共用"

    -- 優先使用 retail 11.x 的 MenuUtil API
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(btn, function(owner, root)
            root:CreateTitle(btn._noteData and btn._noteData.title or "筆記")

            root:CreateButton(moveLabel, function()
                if selectedNoteID == noteID then
                    SaveCurrentNote()
                end
                if MoveNoteToScope(noteID, thisScope, otherScope) then
                    if selectedNoteID == noteID then
                        selectedNoteID = nil
                        ClearEditor()
                    end
                    RefreshNoteList()
                end
            end)

            root:CreateDivider()

            root:CreateButton("|cffff5555刪除|r", function()
                DeleteNoteByID(noteID, thisScope)
                if selectedNoteID == noteID then
                    selectedNoteID = nil
                    ClearEditor()
                end
                RefreshNoteList()
            end)
        end)
        return
    end

    -- Fallback：舊版 EasyMenu
    local menuFrame = _G.MiliUI_NoteContextMenu
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "MiliUI_NoteContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = {
        { text = btn._noteData and btn._noteData.title or "筆記", isTitle = true, notCheckable = true },
        {
            text = moveLabel, notCheckable = true,
            func = function()
                if selectedNoteID == noteID then SaveCurrentNote() end
                if MoveNoteToScope(noteID, thisScope, otherScope) then
                    if selectedNoteID == noteID then
                        selectedNoteID = nil
                        ClearEditor()
                    end
                    RefreshNoteList()
                end
            end,
        },
        {
            text = "|cffff5555刪除|r", notCheckable = true,
            func = function()
                DeleteNoteByID(noteID, thisScope)
                if selectedNoteID == noteID then
                    selectedNoteID = nil
                    ClearEditor()
                end
                RefreshNoteList()
            end,
        },
    }
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

------------------------------------------------------------
-- 筆記列表更新
------------------------------------------------------------
RefreshNoteList = function()
    if not listContent then return end
    local notes = GetNotesForScope(currentScope)

    -- 隱藏所有按鈕
    for _, btn in ipairs(noteListButtons) do
        btn:Hide()
    end

    for i, note in ipairs(notes) do
        local btn = noteListButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, listContent, "BackdropTemplate")
            btn:SetHeight(LIST_BTN_HEIGHT)
            btn:SetBackdrop(S.Backdrop)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:RegisterForDrag("LeftButton")

            -- 拖曳開始：記錄來源筆記 ID
            btn:SetScript("OnDragStart", function(self)
                if not self._noteID then return end
                dragState = { sourceID = self._noteID, targetIndex = nil }
                self:SetAlpha(0.4)
            end)

            -- 拖曳結束：套用排序
            btn:SetScript("OnDragStop", function(self)
                self:SetAlpha(1)
                if dragLine then dragLine:Hide() end

                local state = dragState
                dragState = nil
                if not state or not state.targetIndex then return end

                local notes = GetNotesForScope(currentScope)
                local srcIdx
                for i, n in ipairs(notes) do
                    if n.id == state.sourceID then srcIdx = i; break end
                end
                if not srcIdx then return end

                local note = table.remove(notes, srcIdx)
                local tgt = state.targetIndex
                -- 移除來源後，若目標在來源後面要往前位移一格
                if tgt > srcIdx then tgt = tgt - 1 end
                if tgt < 1 then tgt = 1 end
                if tgt > #notes + 1 then tgt = #notes + 1 end
                table.insert(notes, tgt, note)
                RefreshNoteList()
            end)

            local text = btn:CreateFontString(nil, "OVERLAY")
            text:SetFont(S.Font, 11, "OUTLINE")
            text:SetPoint("LEFT", 6, 0)
            text:SetPoint("RIGHT", -6, 0)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            btn._text = text

            btn:SetScript("OnEnter", function(self)
                if self._noteID ~= selectedNoteID then
                    self:SetBackdropColor(unpack(S.Colors.bgHover))
                    self:SetBackdropBorderColor(unpack(S.Colors.borderHover))
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if self._noteID ~= selectedNoteID then
                    self:SetBackdropColor(unpack(S.Colors.bg))
                    self:SetBackdropBorderColor(unpack(S.Colors.border))
                end
            end)
            btn:SetScript("OnClick", function(self, mouseButton)
                if mouseButton == "RightButton" then
                    ShowNoteContextMenu(self)
                    return
                end
                SaveCurrentNote()
                selectedNoteID = self._noteID
                for _, b in ipairs(noteListButtons) do
                    if b:IsShown() then
                        if b._noteID == selectedNoteID then
                            b:SetBackdropColor(unpack(S.Colors.bgHover))
                            b:SetBackdropBorderColor(unpack(S.Colors.borderHover))
                        else
                            b:SetBackdropColor(unpack(S.Colors.bg))
                            b:SetBackdropBorderColor(unpack(S.Colors.border))
                        end
                    end
                end
                local n = self._noteData
                if n then LoadNoteToEditor(n) end
            end)

            noteListButtons[i] = btn
        end

        btn._noteID   = note.id
        btn._noteData = note
        btn._index    = i
        btn:SetAlpha(1)  -- 重設透明度（避免拖曳殘留）
        btn._text:SetText(note.title or "無標題")
        btn._text:SetTextColor(unpack(S.Colors.text))

        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -((i - 1) * (LIST_BTN_HEIGHT + 2)) - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)

        if note.id == selectedNoteID then
            btn:SetBackdropColor(unpack(S.Colors.bgHover))
            btn:SetBackdropBorderColor(unpack(S.Colors.borderHover))
        else
            btn:SetBackdropColor(unpack(S.Colors.bg))
            btn:SetBackdropBorderColor(unpack(S.Colors.border))
        end

        btn:Show()
    end

    listContent:SetHeight(math.max(1, #notes * (LIST_BTN_HEIGHT + 2) + 4))
end

------------------------------------------------------------
-- 編輯區讀寫
------------------------------------------------------------
LoadNoteToEditor = function(note)
    if not titleEditBox then return end
    titleEditBox:SetText(note.title or "")
    bodyEditBox:SetText(note.content or "")
    titleEditBox:SetCursorPosition(0)
    bodyEditBox:SetCursorPosition(0)
end

ClearEditor = function()
    if not titleEditBox then return end
    titleEditBox:SetText("")
    bodyEditBox:SetText("")
    titleEditBox:ClearFocus()
    bodyEditBox:ClearFocus()
end

SaveCurrentNote = function()
    if not selectedNoteID then return end
    if not titleEditBox then return end
    local notes = GetNotesForScope(currentScope)
    for _, note in ipairs(notes) do
        if note.id == selectedNoteID then
            local newTitle = titleEditBox:GetText()
            note.title   = (newTitle ~= "") and newTitle or "無標題"
            note.content = bodyEditBox:GetText()
            note.time    = time()
            break
        end
    end
    RefreshNoteList()
end

------------------------------------------------------------
-- 標籤頁管理
------------------------------------------------------------
local TAB_NAME = "角色筆記"
local origNumTabs
local notesTabIndex

local function ShowNotesTab()
    if not tabFrame then return end
    tabFrame:Show()
    if editorFrame then editorFrame:Show() end
end

local function HideNotesTab()
    if not tabFrame then return end
    SaveCurrentNote()
    tabFrame:Hide()
    if editorFrame then editorFrame:Hide() end
end

------------------------------------------------------------
-- 偵測可用 Tab 樣板（retail 變動頻繁，逐一嘗試）
------------------------------------------------------------
local function HasTemplate(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        return C_XMLUtil.GetTemplateInfo(name) ~= nil
    end
    return false
end

local function PickTabTemplate()
    local candidates = {
        "CharacterFrameTabButtonTemplate",
        "CharacterFrameTabTemplate",
        "PanelTabButtonTemplate",
    }
    for _, name in ipairs(candidates) do
        if HasTemplate(name) then return name end
    end
    return nil
end

local function GetExistingTabs()
    -- retail：CharacterFrame.Tabs 通常是 array of Button
    if CharacterFrame.Tabs and #CharacterFrame.Tabs > 0 then
        return CharacterFrame.Tabs
    end
    -- 後備：抓全域 CharacterFrameTab1..N
    local tabs = {}
    for i = 1, 10 do
        local t = _G["CharacterFrameTab" .. i]
        if t then tabs[i] = t else break end
    end
    return tabs
end

------------------------------------------------------------
-- 套用「面板分頁」風格到自訂按鈕（樣板找不到時的後備）
------------------------------------------------------------
local function StyleAsPanelTab(btn, label)
    btn:SetSize(96, 28)
    btn:SetBackdrop(S.Backdrop)
    btn:SetBackdropColor(unpack(S.Colors.bg))
    btn:SetBackdropBorderColor(unpack(S.Colors.border))

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(S.Font, 12, "OUTLINE")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetTextColor(unpack(S.Colors.text))
    fs:SetText(label)
    btn._miliText = fs

    btn._SetTabSelected = function(self, selected)
        if selected then
            self:SetBackdropColor(unpack(S.Colors.bgHover))
            self:SetBackdropBorderColor(unpack(S.Colors.borderHover))
        else
            self:SetBackdropColor(unpack(S.Colors.bg))
            self:SetBackdropBorderColor(unpack(S.Colors.border))
        end
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(S.Colors.bgHover))
    end)
    btn:SetScript("OnLeave", function(self)
        if self._isSelected then
            self:SetBackdropColor(unpack(S.Colors.bgHover))
        else
            self:SetBackdropColor(unpack(S.Colors.bg))
        end
    end)
end

local function SetupTab()
    if charTab then return end
    if not CharacterFrame then return end

    BuildUI()

    -- 重要：snapshot 一份「原始 tab」清單。CharacterFrame.Tabs 是活引用，
    -- 待會 PanelTemplates_SetNumTabs / TabSystem 可能會把 charTab 自己塞進去，
    -- 若用活引用迴圈會 hook 到自己，造成點擊瞬間 Show 又 Hide。
    local liveTabs = GetExistingTabs()
    local existingTabs = {}
    for i, t in ipairs(liveTabs) do existingTabs[i] = t end

    origNumTabs   = #existingTabs > 0 and #existingTabs or 3
    notesTabIndex = origNumTabs + 1

    local lastTab = existingTabs[origNumTabs]

    -- 嘗試使用相同樣板，找不到就 fallback 到 BackdropTemplate
    local template = PickTabTemplate()
    if template then
        charTab = CreateFrame("Button", "MiliUI_CharacterFrameTab", CharacterFrame, template)
        charTab:SetID(notesTabIndex)
        if charTab.SetText then charTab:SetText(TAB_NAME) end
    else
        charTab = CreateFrame("Button", "MiliUI_CharacterFrameTab", CharacterFrame, "BackdropTemplate")
        charTab:SetID(notesTabIndex)
        StyleAsPanelTab(charTab, TAB_NAME)
    end

    if lastTab then
        charTab:SetPoint("LEFT", lastTab, "RIGHT", template and -16 or 4, 0)
    else
        charTab:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 11, -30)
    end

    -- 若 CharacterFrame 仍支援舊版 PanelTemplates 系統就一起更新
    if CharacterFrame.numTabs and PanelTemplates_SetNumTabs then
        pcall(PanelTemplates_SetNumTabs, CharacterFrame, notesTabIndex)
        pcall(PanelTemplates_EnableTab, CharacterFrame, notesTabIndex)
    end

    charTab:SetScript("OnClick", function(self)
        -- 切換選中狀態：先把所有原始 tab 視為未選
        for _, t in ipairs(existingTabs) do
            if t._SetTabSelected then
                t._isSelected = false
                t:_SetTabSelected(false)
            end
        end
        if charTab._SetTabSelected then
            charTab._isSelected = true
            charTab:_SetTabSelected(true)
        end

        if PanelTemplates_SetTab and CharacterFrame.numTabs then
            pcall(PanelTemplates_SetTab, CharacterFrame, notesTabIndex)
        end

        -- 隱藏其他原生面板（Inset 保留，當作我們的視覺底）
        if PaperDollFrame then PaperDollFrame:Hide() end
        if ReputationFrame then ReputationFrame:Hide() end
        if CurrencyFrame then CurrencyFrame:Hide() end
        if TokenFrame then TokenFrame:Hide() end

        -- 更新標題
        if CharacterFrameTitleText then
            CharacterFrameTitleText:SetText(TAB_NAME)
        end

        ShowNotesTab()
        RefreshNoteList()
    end)

    -- 切換離開時還原 tab 視覺：依靠原生 tab 的 OnClick hook 即可（見下方）
    -- 不再 hook 全域 PanelTemplates_SetTab —— retail 的 TabSystem 會在我們之後
    -- 再次呼叫該函式並把 selectedTab 重設成預設 id，導致 tabFrame 立刻被隱藏。

    -- DEBUG：追蹤是誰把 tabFrame 隱藏掉
    hooksecurefunc(tabFrame, "Hide", function()
        if MiliUI_NotesDebug then
            print("|cffff0000[Notes Hide]|r", debugstack(2, 4, 0))
        end
    end)
    hooksecurefunc(tabFrame, "Show", function()
        if MiliUI_NotesDebug then
            print("|cff00ff00[Notes Show]|r")
        end
    end)

    -- 也 hook 各個原始 tab 的 OnClick：使用者點別的 tab 時把筆記面板收起來
    -- 雙重保險：明確排除 charTab，避免 hook 到自己
    for _, t in ipairs(existingTabs) do
        if t and t ~= charTab and t.HookScript then
            t:HookScript("OnClick", function()
                HideNotesTab()
                if charTab._SetTabSelected then
                    charTab._isSelected = false
                    charTab:_SetTabSelected(false)
                end
            end)
        end
    end

    -- CharacterFrame 整個關閉時也存檔
    CharacterFrame:HookScript("OnHide", function()
        HideNotesTab()
    end)
end

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------
local function fmt(f)
    if not f then return "<nil>" end
    local sh = f.IsShown and f:IsShown() or false
    local vis = f.IsVisible and f:IsVisible() or false
    local w = f.GetWidth and f:GetWidth() or 0
    local h = f.GetHeight and f:GetHeight() or 0
    local strata = f.GetFrameStrata and f:GetFrameStrata() or "?"
    local lvl = f.GetFrameLevel and f:GetFrameLevel() or "?"
    local l, b = 0, 0
    if f.GetLeft and f:GetLeft() then l = math.floor(f:GetLeft()) end
    if f.GetBottom and f:GetBottom() then b = math.floor(f:GetBottom()) end
    return string.format("shown=%s vis=%s size=%dx%d pos=(%d,%d) strata=%s lvl=%s",
        tostring(sh), tostring(vis), w, h, l, b, strata, tostring(lvl))
end

local function PrintNoteDebug()
    print("|cff00ff00[MiliUI Notes]|r === DEBUG ===")
    print("CharacterFrame:", fmt(CharacterFrame))
    print("CharacterFrame.Inset:", fmt(CharacterFrame and CharacterFrame.Inset))
    print("tabFrame:", fmt(tabFrame))
    print("toolbar:", fmt(toolbar))
    print("listBg:", fmt(listBg))
    print("editorFrame:", fmt(editorFrame))
    print("scopeButton:", fmt(scopeButton))
    print("titleEditBox:", fmt(titleEditBox))
    print("bodyEditBox:", fmt(bodyEditBox))
    print("charTab:", fmt(charTab))
    if tabFrame then
        local kids = { tabFrame:GetChildren() }
        print("tabFrame children count:", #kids)
        for i, c in ipairs(kids) do
            print(string.format("  [%d] %s", i, fmt(c)))
        end
    end
end

SLASH_MILINOTE1 = "/minote"
SlashCmdList["MILINOTE"] = function(msg)
    if msg == "show" then
        if tabFrame then tabFrame:Show() end
    elseif msg == "hide" then
        if tabFrame then tabFrame:Hide() end
    elseif msg == "trace" then
        MiliUI_NotesDebug = not MiliUI_NotesDebug
        print("|cff00ff00[Notes]|r trace:", MiliUI_NotesDebug and "ON" or "OFF")
    else
        PrintNoteDebug()
    end
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_LOGIN")
    -- CharacterFrame 可能由 Blizzard_CharacterFrame 延遲載入
    if CharacterFrame then
        SetupTab()
    else
        -- 如果尚未載入，等 ADDON_LOADED
        self:RegisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", function(self2, ev, addon)
            if addon == "Blizzard_CharacterFrame" or CharacterFrame then
                self2:UnregisterEvent("ADDON_LOADED")
                SetupTab()
            end
        end)
    end
end)
