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
local BLOCK_TOOLBAR_HEIGHT = 26
local BLOCK_ROW_MIN_HEIGHT = 24
local BLOCK_MAX_INDENT     = 5
local BLOCK_INDENT_PX      = 20

-- 區塊類型
local BLOCK_TYPE_TEXT     = "text"
local BLOCK_TYPE_CHECKBOX = "checkbox"
local BLOCK_TYPE_BULLET   = "bullet"
local BLOCK_TYPE_NUMBER   = "number"

local VALID_BLOCK_TYPES = {
    [BLOCK_TYPE_TEXT]     = true,
    [BLOCK_TYPE_CHECKBOX] = true,
    [BLOCK_TYPE_BULLET]   = true,
    [BLOCK_TYPE_NUMBER]   = true,
}

------------------------------------------------------------
-- DB
------------------------------------------------------------
local function GetAccountDB()
    if type(MiliUI_DB) ~= "table" then MiliUI_DB = {} end
    if type(MiliUI_DB.notes) ~= "table" then MiliUI_DB.notes = {} end
    return MiliUI_DB.notes
end

-- 舊版：每角色獨立 SavedVariables，僅用於一次性遷移來源
local function GetCharDB()
    if type(MiliUI_CharDB) ~= "table" then MiliUI_CharDB = {} end
    if type(MiliUI_CharDB.notes) ~= "table" then MiliUI_CharDB.notes = {} end
    return MiliUI_CharDB.notes
end

------------------------------------------------------------
-- 角色筆記改存帳號層，才能跨分身檢視
-- 結構：MiliUI_DB.charNotes[key] = { meta = {name, realm, class}, notes = {...} }
------------------------------------------------------------
-- 目前選取要檢視的分身 key（角色專屬模式用；登入時預設為當前角色）
local selectedCharKey

-- 延後清理：登入時不掃所有分身，首次存取某分身才 Sanitize
local sanitizedChars = {}
local SanitizeCharNotes  -- 前向宣告（實作需用到稍後定義的 SanitizeNoteList）

local function GetCharNotesDB()
    if type(MiliUI_DB) ~= "table" then MiliUI_DB = {} end
    if type(MiliUI_DB.charNotes) ~= "table" then MiliUI_DB.charNotes = {} end
    return MiliUI_DB.charNotes
end

-- 回傳 當前角色 key, 名稱, 伺服器
local function GetCurrentCharKey()
    local name  = UnitName("player") or "?"
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    return name .. "-" .. realm, name, realm
end

-- 取得（必要時建立）某分身的容器：{ meta=..., notes={...} }
local function GetCharEntry(key)
    local db = GetCharNotesDB()
    if type(db[key]) ~= "table" then db[key] = {} end
    if type(db[key].notes) ~= "table" then db[key].notes = {} end
    return db[key]
end

local function GetNotesForCharKey(key)
    SanitizeCharNotes(key)  -- 首次存取才清理（把登入成本攤到實際檢視時）
    return GetCharEntry(key).notes
end

------------------------------------------------------------
-- DB 清理：移除損毀條目、補齊缺欄位
------------------------------------------------------------
local function SanitizeBlocks(blocks)
    if type(blocks) ~= "table" then return nil end
    local clean = {}
    for _, b in ipairs(blocks) do
        if type(b) == "table" and type(b.type) == "string" and VALID_BLOCK_TYPES[b.type] then
            local nb = {
                type = b.type,
                text = type(b.text) == "string" and b.text or "",
            }
            if b.type == BLOCK_TYPE_CHECKBOX then
                nb.checked = b.checked == true
            end
            if type(b.indent) == "number" then
                nb.indent = math.max(0, math.min(BLOCK_MAX_INDENT, math.floor(b.indent)))
                if nb.indent == 0 then nb.indent = nil end
            end
            table.insert(clean, nb)
        end
    end
    return clean
end

local function SanitizeNoteList(notes)
    if type(notes) ~= "table" then return end
    for i = #notes, 1, -1 do
        local n = notes[i]
        if type(n) ~= "table" or type(n.id) ~= "string" or n.id == "" then
            table.remove(notes, i)
        else
            if type(n.title) ~= "string" then n.title = "無標題" end
            if type(n.content) ~= "string" then n.content = "" end
            if type(n.time) ~= "number" then n.time = 0 end
            -- 區塊：若有則清理，沒有就保留 nil（讀取時再 migrate）
            if n.blocks ~= nil then
                n.blocks = SanitizeBlocks(n.blocks)
            end
        end
    end
end

-- 延後清理某分身的筆記（每個 key 只做一次）
SanitizeCharNotes = function(key)
    if not key or sanitizedChars[key] then return end
    sanitizedChars[key] = true
    local entry = GetCharNotesDB()[key]
    if type(entry) == "table" then SanitizeNoteList(entry.notes) end
end

------------------------------------------------------------
-- 將舊的 content 字串遷移成 blocks（一行 = 一個 text block）
------------------------------------------------------------
local function MigrateNoteToBlocks(note)
    if type(note.blocks) == "table" and #note.blocks > 0 then return end
    note.blocks = {}
    if type(note.content) == "string" and note.content ~= "" then
        for line in (note.content .. "\n"):gmatch("(.-)\n") do
            table.insert(note.blocks, { type = BLOCK_TYPE_TEXT, text = line })
        end
    end
    if #note.blocks == 0 then
        table.insert(note.blocks, { type = BLOCK_TYPE_TEXT, text = "" })
    end
end

local function InitDB()
    GetAccountDB()  -- 觸發 type-check 與初始化
    GetCharDB()
    GetCharNotesDB()
    SanitizeNoteList(MiliUI_DB.notes)

    local curKey, curName, curRealm = GetCurrentCharKey()
    local charDB = GetCharNotesDB()

    -- 一次性遷移：舊的 per-character SavedVariables → 帳號層 charNotes[curKey]
    local legacy = MiliUI_CharDB and MiliUI_CharDB.notes
    if type(legacy) == "table" and #legacy > 0
       and not (type(charDB[curKey]) == "table" and charDB[curKey].migrated) then
        local entry = GetCharEntry(curKey)
        if #entry.notes == 0 then
            for _, n in ipairs(legacy) do table.insert(entry.notes, n) end
        end
        entry.migrated = true
        MiliUI_CharDB.notes = {}  -- 清掉舊資料，避免重複遷移
    end

    -- 更新當前角色 meta（每次登入刷新名稱/伺服器/職業，供下拉選單顯示）
    local entry = GetCharEntry(curKey)
    entry.meta = type(entry.meta) == "table" and entry.meta or {}
    local _, classFile = UnitClass("player")
    entry.meta.name  = curName
    entry.meta.realm = curRealm
    entry.meta.class = classFile

    -- 只清理當前角色；其他分身於首次檢視時才清理（見 GetNotesForCharKey）
    SanitizeCharNotes(curKey)

    selectedCharKey = curKey  -- 預設檢視當前角色

    -- 編輯器位置
    if MiliUI_DB.notesEditorPos and type(MiliUI_DB.notesEditorPos) ~= "table" then
        MiliUI_DB.notesEditorPos = nil
    end
end

-- 讀取此角色上次使用的 tab；回傳合法 scope 或 nil（呼叫端在 currentScope 在 scope 時再賦值）
local function ReadSavedScope()
    if not MiliUI_CharDB then return nil end
    if MiliUI_CharDB.lastScope == NOTE_SCOPE_CHAR
       or MiliUI_CharDB.lastScope == NOTE_SCOPE_ACCOUNT then
        return MiliUI_CharDB.lastScope
    end
    return nil
end

-- 寫入目前 tab 至本角色 SavedVariables
local function WriteSavedScope(scope)
    if type(MiliUI_CharDB) ~= "table" then MiliUI_CharDB = {} end
    MiliUI_CharDB.lastScope = scope
end

local function GetNotesForScope(scope)
    if scope == NOTE_SCOPE_CHAR then
        return GetNotesForCharKey(selectedCharKey or (GetCurrentCharKey()))
    end
    return GetAccountDB()
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local currentScope    = NOTE_SCOPE_ACCOUNT
local currentFilter   = ""    -- 搜尋關鍵字（小寫；空字串表示無篩選）
local selectedNoteID  = nil
local selectedButton          -- O(1) 選取狀態切換用
local noteListButtons = {}
local dragState       = nil   -- 列表筆記拖曳：{ sourceID, targetIndex }
local dragLine                -- 列表拖曳指示線
local listScroll              -- 列表 ScrollFrame（在 BuildUI 中初始化）

-- 區塊編輯器狀態
local currentNoteForBlocks    -- 目前正在編輯區塊的 note 參考
local blockRows       = {}    -- 區塊 row 物件池
local blockDragState          -- 區塊拖曳：{ sourceIdx, targetIdx }
local blockDragLine           -- 區塊拖曳指示線
local blockContainer          -- ScrollChild 容器（在 BuildUI 中初始化）
local bodyScroll              -- 區塊 ScrollFrame（在 BuildUI 中初始化）

-- 前向宣告
local RefreshNoteList, LoadNoteToEditor, SaveCurrentNote, ClearEditor
local SetButtonSelected, DragMonitor, CancelDrag
local RefreshBlocks, RelayoutBlocks, BlockDragMonitor, AddBlock, DeleteBlock
local CancelBlockDrag

------------------------------------------------------------
-- 產生唯一 ID
------------------------------------------------------------
local function GenerateID()
    return time() .. "-" .. math.random(10000, 99999)
end

------------------------------------------------------------
-- 新筆記預設標題：在現有「新筆記 N」中找最大 N 並 +1
------------------------------------------------------------
local function NextNewNoteTitle(notes)
    local maxN = 0
    for _, n in ipairs(notes) do
        local num = tostring(n.title or ""):match("^新筆記 (%d+)$")
        if num then
            local v = tonumber(num)
            if v and v > maxN then maxN = v end
        end
    end
    return string.format("新筆記 %d", maxN + 1)
end

------------------------------------------------------------
-- 選取狀態視覺切換（O(1)，避免每次點擊掃整列表）
------------------------------------------------------------
SetButtonSelected = function(btn, selected)
    if not btn then return end
    if selected then
        btn:SetBackdropColor(unpack(S.Colors.bgHover))
        btn:SetBackdropBorderColor(unpack(S.Colors.borderHover))
    else
        btn:SetBackdropColor(unpack(S.Colors.bg))
        btn:SetBackdropBorderColor(unpack(S.Colors.border))
    end
end

------------------------------------------------------------
-- 拖曳：取消狀態（用於 OnDragStop / 異常關閉時清理殘留）
------------------------------------------------------------
CancelDrag = function()
    dragState = nil
    if dragLine then dragLine:Hide() end
    if listScroll then listScroll:SetScript("OnUpdate", nil) end
    for _, b in ipairs(noteListButtons) do
        if b:GetAlpha() < 1 then b:SetAlpha(1) end
    end
end

------------------------------------------------------------
-- 拖曳監控：僅在拖曳期間綁定 OnUpdate
------------------------------------------------------------
DragMonitor = function()
    if not dragState then return end

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
        return
    end

    -- 游標不在任何按鈕上：若在最後一筆下方，drop 到尾端
    local last
    for _, b in ipairs(noteListButtons) do
        if b:IsShown() then last = b end
    end
    if last then
        local _, cy = GetCursorPosition()
        cy = cy / last:GetEffectiveScale()
        if cy < last:GetBottom() then
            dragState.targetIndex = #GetNotesForScope(currentScope) + 1
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

------------------------------------------------------------
-- UI 建構（延遲到角色面板載入後）
------------------------------------------------------------
local tabFrame       -- 筆記標籤頁的主容器（CharacterFrame 內）
local listContent    -- 列表捲動內容
local editorFrame    -- 獨立浮動編輯視窗（parent: UIParent）
local titleEditBox   -- 標題輸入
local scopeButton    -- 帳號/角色 切換按鈕（OnClick 內要更新文字）
local addButton      -- 新增按鈕（LayoutToolbar 時要重新錨定）
local charDropdown   -- 分身選擇下拉（僅角色專屬模式顯示）
local searchBox      -- 搜尋輸入框
local charTab        -- 標籤按鈕
-- listScroll / bodyScroll 已宣告於上方狀態區（CancelDrag/CancelBlockDrag 需要先看見它們）

------------------------------------------------------------
-- 分身標籤：職業圖示 + 職業色名稱
------------------------------------------------------------
local CLASS_ICON_TEX = "Interface\\TargetingFrame\\UI-Classes-Circles"

local function ClassIconMarkup(classFile, size)
    size = size or 14
    local c = classFile and CLASS_ICON_TCOORDS[classFile]
    if not c then return "" end
    local function px(v) return math.floor(v * 256 + 0.5) end
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
        CLASS_ICON_TEX, size, size, px(c[1]), px(c[2]), px(c[3]), px(c[4]))
end

local function ClassColoredName(name, classFile)
    name = name or "?"
    local col = classFile and RAID_CLASS_COLORS[classFile]
    if col then
        return string.format("|cff%02x%02x%02x%s|r",
            col.r * 255, col.g * 255, col.b * 255, name)
    end
    return name
end

local function CharLabelMarkup(meta, size, showRealm)
    if type(meta) ~= "table" then return "?" end
    local icon = ClassIconMarkup(meta.class, size)
    local name = ClassColoredName(meta.name, meta.class)
    local label = (icon ~= "") and (icon .. " " .. name) or name
    -- 同名跨服分身：補上淡灰色伺服器名以區分
    if showRealm and type(meta.realm) == "string" and meta.realm ~= "" then
        label = label .. "|cff808080-" .. meta.realm .. "|r"
    end
    return label
end

-- 找出有「同名」的分身（同名才需要顯示伺服器來區分）
local function GetDuplicateNameSet()
    local db = GetCharNotesDB()
    local count, dup = {}, {}
    for _, e in pairs(db) do
        local nm = type(e) == "table" and type(e.meta) == "table" and e.meta.name
        if nm then count[nm] = (count[nm] or 0) + 1 end
    end
    for nm, c in pairs(count) do
        if c > 1 then dup[nm] = true end
    end
    return dup
end

-- 分身 key 排序：當前角色置頂，其餘字典序
local function GetSortedCharKeys()
    local db = GetCharNotesDB()
    local curKey = GetCurrentCharKey()
    local keys = {}
    for k in pairs(db) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if a == curKey then return true end
        if b == curKey then return false end
        return a < b
    end)
    return keys
end

local function UpdateCharDropdownText()
    if not charDropdown then return end
    local entry = GetCharEntry(selectedCharKey or (GetCurrentCharKey()))
    local meta = entry and entry.meta
    local showRealm = meta and GetDuplicateNameSet()[meta.name]
    charDropdown._text:SetText(CharLabelMarkup(meta, 14, showRealm))
end

-- 工具列依目前 scope 重新排版：角色專屬時顯示分身下拉
local function LayoutToolbar()
    if not charDropdown or not addButton or not scopeButton then return end
    if currentScope == NOTE_SCOPE_CHAR then
        charDropdown:Show()
        UpdateCharDropdownText()
        addButton:ClearAllPoints()
        addButton:SetPoint("LEFT", charDropdown, "RIGHT", 4, 0)
    else
        charDropdown:Hide()
        addButton:ClearAllPoints()
        addButton:SetPoint("LEFT", scopeButton, "RIGHT", 4, 0)
    end
end

local function ShowCharSelectMenu(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local keys = GetSortedCharKeys()
    local dup = GetDuplicateNameSet()
    MenuUtil.CreateContextMenu(anchor, function(owner, root)
        root:CreateTitle("選擇分身")
        for _, key in ipairs(keys) do
            local entry = GetCharEntry(key)
            local meta = entry and entry.meta
            local label = CharLabelMarkup(meta, 16, meta and dup[meta.name])
            local k = key
            root:CreateButton(label, function()
                SaveCurrentNote()
                selectedCharKey = k
                selectedNoteID = nil
                ClearEditor()
                if searchBox then searchBox:SetText("") end
                currentFilter = ""
                UpdateCharDropdownText()
                RefreshNoteList()
            end)
        end
    end)
end

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
    local toolbar = CreateFrame("Frame", nil, tabFrame, "BackdropTemplate")
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    toolbar:SetPoint("TOPLEFT", NOTE_PADDING, -NOTE_PADDING)
    toolbar:SetPoint("TOPRIGHT", -NOTE_PADDING, -NOTE_PADDING)
    toolbar:SetBackdrop(S.Backdrop)
    toolbar:SetBackdropColor(unpack(S.Colors.bg))
    toolbar:SetBackdropBorderColor(unpack(S.Colors.border))

    -- 帳號/角色 切換按鈕
    scopeButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    scopeButton:SetSize(96, TOOLBAR_HEIGHT - 4)
    scopeButton:SetPoint("LEFT", 4, 0)
    S.ApplyButton(scopeButton, "戰隊共用", nil, 11)
    -- 同步初始文字到還原後的 currentScope
    if scopeButton._miliText then
        scopeButton._miliText:SetText(
            (currentScope == NOTE_SCOPE_CHAR) and "角色專屬" or "戰隊共用"
        )
    end

    scopeButton:SetScript("OnClick", function()
        SaveCurrentNote()
        if currentScope == NOTE_SCOPE_ACCOUNT then
            currentScope = NOTE_SCOPE_CHAR
            scopeButton._miliText:SetText("角色專屬")
            -- 進入角色專屬：確保 selectedCharKey 有效（預設當前角色）
            if not selectedCharKey or type(GetCharNotesDB()[selectedCharKey]) ~= "table" then
                selectedCharKey = GetCurrentCharKey()
            end
        else
            currentScope = NOTE_SCOPE_ACCOUNT
            scopeButton._miliText:SetText("戰隊共用")
        end
        WriteSavedScope(currentScope)  -- 寫回此角色 SavedVariables
        selectedNoteID = nil
        ClearEditor()
        if searchBox then searchBox:SetText("") end
        currentFilter = ""
        LayoutToolbar()
        RefreshNoteList()
    end)

    -- 分身選擇下拉（僅角色專屬模式顯示，由 LayoutToolbar 控制）
    charDropdown = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    charDropdown:SetSize(150, TOOLBAR_HEIGHT - 4)
    charDropdown:SetPoint("LEFT", scopeButton, "RIGHT", 4, 0)
    charDropdown:SetBackdrop(S.Backdrop)
    charDropdown:SetBackdropColor(unpack(S.Colors.bg))
    charDropdown:SetBackdropBorderColor(unpack(S.Colors.border))
    charDropdown:Hide()

    local cdText = charDropdown:CreateFontString(nil, "OVERLAY")
    cdText:SetFont(S.Font, 11, "OUTLINE")
    cdText:SetPoint("LEFT", 6, 0)
    cdText:SetPoint("RIGHT", -16, 0)
    cdText:SetJustifyH("LEFT")
    cdText:SetWordWrap(false)
    charDropdown._text = cdText

    local cdArrow = charDropdown:CreateFontString(nil, "OVERLAY")
    cdArrow:SetFont(S.Font, 9, "OUTLINE")
    cdArrow:SetPoint("RIGHT", -5, 0)
    cdArrow:SetText("v")
    cdArrow:SetTextColor(unpack(S.Colors.text))

    charDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(S.Colors.bgHover)) end)
    charDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(S.Colors.bg)) end)
    charDropdown:SetScript("OnClick", function(self) ShowCharSelectMenu(self) end)

    -- 新增按鈕
    addButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    addButton:SetSize(50, TOOLBAR_HEIGHT - 4)
    addButton:SetPoint("LEFT", scopeButton, "RIGHT", 4, 0)
    S.ApplyButton(addButton, "新增", nil, 11)

    addButton:SetScript("OnClick", function()
        SaveCurrentNote()
        -- 新增前清掉篩選，確保新筆記可見
        if searchBox then searchBox:SetText("") end
        currentFilter = ""

        local notes = GetNotesForScope(currentScope)
        local newNote = {
            id      = GenerateID(),
            title   = NextNewNoteTitle(notes),
            content = "",  -- 留欄位給舊版相容
            blocks  = { { type = BLOCK_TYPE_TEXT, text = "" } },
            time    = time(),
        }
        table.insert(notes, 1, newNote)
        selectedNoteID = newNote.id
        RefreshNoteList()
        LoadNoteToEditor(newNote)
        titleEditBox:SetFocus()
        titleEditBox:HighlightText()
    end)

    -- 搜尋框
    searchBox = CreateFrame("EditBox", nil, toolbar, "BackdropTemplate")
    searchBox:SetPoint("LEFT", addButton, "RIGHT", 4, 0)
    searchBox:SetPoint("RIGHT", toolbar, "RIGHT", -4, 0)
    searchBox:SetHeight(TOOLBAR_HEIGHT - 4)
    searchBox:SetFont(S.Font, 11, "")
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetTextInsets(8, 6, 0, 0)
    searchBox:SetBackdrop(S.Backdrop)
    searchBox:SetBackdropColor(0.1, 0.1, 0.15, 0.5)
    searchBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)

    -- 佔位文字
    local placeholder = searchBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(S.Font, 11, "")
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetTextColor(0.5, 0.5, 0.5, 1)
    placeholder:SetText("搜尋…")

    local function UpdatePlaceholder()
        if searchBox:GetText() == "" then placeholder:Show() else placeholder:Hide() end
    end

    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        currentFilter = (self:GetText() or ""):lower()
        UpdatePlaceholder()
        RefreshNoteList()
    end)

    ------------------------------------------------------------
    -- 筆記列表（佔滿 tabFrame 下半部）
    ------------------------------------------------------------
    local listBg = CreateFrame("Frame", nil, tabFrame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    listBg:SetPoint("BOTTOMRIGHT", -NOTE_PADDING, NOTE_PADDING)
    listBg:SetBackdrop(S.Backdrop)
    listBg:SetBackdropColor(unpack(S.Colors.bg))
    listBg:SetBackdropBorderColor(unpack(S.Colors.border))

    listScroll = CreateFrame("ScrollFrame", "MiliUI_NotesListScroll", listBg, "UIPanelScrollFrameTemplate")  -- 寫入模組級 listScroll
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

    ------------------------------------------------------------
    -- 獨立浮動編輯視窗（parent: UIParent）
    ------------------------------------------------------------
    editorFrame = CreateFrame("Frame", "MiliUI_NoteEditorFrame", UIParent, "BackdropTemplate")
    editorFrame:SetSize(EDITOR_WIDTH, EDITOR_HEIGHT)
    editorFrame:SetFrameStrata("HIGH")
    editorFrame:SetFrameLevel(50)
    editorFrame:SetClampedToScreen(true)
    editorFrame:SetMovable(true)
    editorFrame:Hide()

    -- 位置：優先使用使用者上次存的，沒有就預設貼在 CharacterFrame 右側
    local savedPos = MiliUI_DB and MiliUI_DB.notesEditorPos
    if savedPos and savedPos.point then
        editorFrame:ClearAllPoints()
        editorFrame:SetPoint(savedPos.point, UIParent, savedPos.relPoint or savedPos.point,
            savedPos.x or 0, savedPos.y or 0)
    else
        editorFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 8, 0)
    end
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
        -- 持久化位置
        if not MiliUI_DB then MiliUI_DB = {} end
        local point, _, relPoint, x, y = editorFrame:GetPoint(1)
        MiliUI_DB.notesEditorPos = { point = point, relPoint = relPoint, x = x, y = y }
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
        -- 跳到第一個區塊
        local firstRow = blockRows[1]
        if firstRow and firstRow:IsShown() and firstRow.editBox then
            firstRow.editBox:SetFocus()
        end
    end)
    titleEditBox:SetScript("OnEditFocusLost", function() SaveCurrentNote() end)

    -- 分隔線
    local editorDivider = editorFrame:CreateTexture(nil, "ARTWORK")
    editorDivider:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    editorDivider:SetHeight(1)
    editorDivider:SetPoint("TOPLEFT", titleEditBox, "BOTTOMLEFT", 0, -6)
    editorDivider:SetPoint("TOPRIGHT", titleEditBox, "BOTTOMRIGHT", 0, -6)

    ------------------------------------------------------------
    -- 區塊式內文編輯器：工具列 + ScrollFrame + 區塊容器
    ------------------------------------------------------------
    local blockToolbar = CreateFrame("Frame", nil, editorFrame, "BackdropTemplate")
    blockToolbar:SetHeight(BLOCK_TOOLBAR_HEIGHT)
    blockToolbar:SetPoint("TOPLEFT", editorDivider, "BOTTOMLEFT", 6, -4)
    blockToolbar:SetPoint("TOPRIGHT", editorDivider, "BOTTOMRIGHT", -6, -4)

    local function MakeBlockTypeButton(label, blockType, anchorRef, anchorRel)
        local b = CreateFrame("Button", nil, blockToolbar, "BackdropTemplate")
        b:SetSize(64, BLOCK_TOOLBAR_HEIGHT - 4)
        b:SetPoint("LEFT", anchorRef, anchorRel, 4, 0)
        S.ApplyButton(b, label, nil, 11)
        b:SetScript("OnClick", function() AddBlock(blockType) end)
        return b
    end

    -- 標籤：加入區塊：
    local addLabel = blockToolbar:CreateFontString(nil, "OVERLAY")
    addLabel:SetFont(S.Font, 12, "OUTLINE")
    addLabel:SetPoint("LEFT", blockToolbar, "LEFT", 0, 0)
    addLabel:SetText("加入區塊：")
    addLabel:SetTextColor(unpack(S.Colors.text))

    local addText  = CreateFrame("Button", nil, blockToolbar, "BackdropTemplate")
    addText:SetSize(64, BLOCK_TOOLBAR_HEIGHT - 4)
    addText:SetPoint("LEFT", addLabel, "RIGHT", 6, 0)
    S.ApplyButton(addText, "文字", nil, 11)
    addText:SetScript("OnClick", function() AddBlock(BLOCK_TYPE_TEXT) end)

    local addCheck  = MakeBlockTypeButton("勾選", BLOCK_TYPE_CHECKBOX, addText,  "RIGHT")
    local addBullet = MakeBlockTypeButton("項目", BLOCK_TYPE_BULLET,   addCheck, "RIGHT")
    local addNumber = MakeBlockTypeButton("編號", BLOCK_TYPE_NUMBER,   addBullet,"RIGHT")

    -- 內文捲動容器（寫入模組級 bodyScroll）
    bodyScroll = CreateFrame("ScrollFrame", "MiliUI_NoteBodyScroll", editorFrame, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", blockToolbar, "BOTTOMLEFT", 0, -4)
    bodyScroll:SetPoint("BOTTOMRIGHT", -26, 8)

    -- 區塊容器（ScrollChild）
    blockContainer = CreateFrame("Frame", nil, bodyScroll)
    blockContainer:SetSize(1, 1)
    bodyScroll:SetScrollChild(blockContainer)

    bodyScroll:SetScript("OnSizeChanged", function(self, w)
        blockContainer:SetWidth(math.max(1, w))
        if RelayoutBlocks then RelayoutBlocks() end
    end)

    -- 區塊拖曳指示線
    blockDragLine = blockContainer:CreateTexture(nil, "OVERLAY")
    blockDragLine:SetColorTexture(unpack(S.Colors.borderHover))
    blockDragLine:SetHeight(2)
    blockDragLine:Hide()

    ClearEditor()
    LayoutToolbar()  -- 依還原後的 scope 設定工具列（角色專屬時顯示分身下拉）
end

------------------------------------------------------------
-- 區塊編輯器：拖曳監控
------------------------------------------------------------
BlockDragMonitor = function()
    if not blockDragState then return end

    local hovered
    for _, r in ipairs(blockRows) do
        if r:IsShown() and r:IsMouseOver() then
            hovered = r
            break
        end
    end

    if hovered then
        local _, cy = GetCursorPosition()
        cy = cy / hovered:GetEffectiveScale()
        local mid = hovered:GetTop() - hovered:GetHeight() / 2
        local idx = hovered._index or 1
        blockDragState.targetIdx = (cy >= mid) and idx or (idx + 1)

        blockDragLine:ClearAllPoints()
        if cy >= mid then
            blockDragLine:SetPoint("TOPLEFT", hovered, "TOPLEFT", 0, 1)
            blockDragLine:SetPoint("TOPRIGHT", hovered, "TOPRIGHT", 0, 1)
        else
            blockDragLine:SetPoint("BOTTOMLEFT", hovered, "BOTTOMLEFT", 0, -1)
            blockDragLine:SetPoint("BOTTOMRIGHT", hovered, "BOTTOMRIGHT", 0, -1)
        end
        blockDragLine:Show()
    else
        blockDragLine:Hide()
        blockDragState.targetIdx = nil
    end
end

CancelBlockDrag = function()
    blockDragState = nil
    if blockDragLine then blockDragLine:Hide() end
    if bodyScroll then bodyScroll:SetScript("OnUpdate", nil) end
    for _, r in ipairs(blockRows) do
        if r:GetAlpha() < 1 then r:SetAlpha(1) end
    end
end

------------------------------------------------------------
-- 子樹範圍：回傳 [startIdx, endIdx]
-- 一個區塊的「子樹」= 它本身 + 緊接其後、縮排比它「更深」的連續區塊。
-- 用於拖曳 parent 時連同底下的 child 一起搬移。
------------------------------------------------------------
local function GetBlockGroupRange(blocks, idx)
    local baseIndent = blocks[idx].indent or 0
    local endI = idx
    for j = idx + 1, #blocks do
        if (blocks[j].indent or 0) > baseIndent then
            endI = j
        else
            break
        end
    end
    return idx, endI
end

------------------------------------------------------------
-- 區塊 row 建立（每個區塊一個 row，object pool 重用）
------------------------------------------------------------
local function CreateBlockRow()
    local row = CreateFrame("Frame", nil, blockContainer)
    row:SetHeight(BLOCK_ROW_MIN_HEIGHT)

    -- 拖曳把手：2×3 點陣（字體無關）
    -- 用 Button 才能 RegisterForClicks 接收右鍵
    row.dragHandle = CreateFrame("Button", nil, row)
    row.dragHandle:SetSize(14, BLOCK_ROW_MIN_HEIGHT)
    row.dragHandle:SetPoint("TOPLEFT", 2, 0)
    row.dragHandle._dots = {}
    for r = 1, 3 do
        for c = 1, 2 do
            local dot = row.dragHandle:CreateTexture(nil, "OVERLAY")
            dot:SetColorTexture(0.45, 0.45, 0.45, 1)
            dot:SetSize(2, 2)
            dot:SetPoint("CENTER", row.dragHandle, "CENTER", (c - 1.5) * 4, (2 - r) * 5)
            table.insert(row.dragHandle._dots, dot)
        end
    end

    local function SetHandleColor(rr, gg, bb)
        for _, d in ipairs(row.dragHandle._dots) do
            d:SetColorTexture(rr, gg, bb, 1)
        end
    end

    row.dragHandle:EnableMouse(true)
    row.dragHandle:RegisterForDrag("LeftButton")
    row.dragHandle:SetScript("OnEnter", function()
        local r2, g2, b2 = unpack(S.Colors.text)
        SetHandleColor(r2, g2, b2)
    end)
    row.dragHandle:SetScript("OnLeave", function()
        SetHandleColor(0.45, 0.45, 0.45)
    end)
    row.dragHandle:SetScript("OnDragStart", function()
        if not row._block or not bodyScroll then return end
        blockDragState = { sourceIdx = row._index, targetIdx = nil }
        -- 計算子樹範圍，整段一起淡化（讓使用者看出 child 會跟著走）
        local blocks = currentNoteForBlocks and currentNoteForBlocks.blocks
        if blocks then
            local s, e = GetBlockGroupRange(blocks, row._index)
            for k = s, e do
                if blockRows[k] then blockRows[k]:SetAlpha(0.4) end
            end
        else
            row:SetAlpha(0.4)
        end
        bodyScroll:SetScript("OnUpdate", BlockDragMonitor)
    end)
    row.dragHandle:SetScript("OnDragStop", function()
        local state = blockDragState
        CancelBlockDrag()
        SetHandleColor(0.45, 0.45, 0.45)

        if not state or not state.targetIdx then return end
        local srcIdx = state.sourceIdx
        if not srcIdx then return end
        local blocks = currentNoteForBlocks and currentNoteForBlocks.blocks
        if not blocks then return end

        -- 取出整段子樹（parent + 其下更深縮排的 child）
        local s, e = GetBlockGroupRange(blocks, srcIdx)
        local tgt = state.targetIdx
        -- 不允許把 parent 放進自己的子樹內部（s < tgt <= e 為段落內的插入點）
        if tgt > s and tgt <= e then return end

        local count = e - s + 1
        local moving = {}
        for k = s, e do moving[#moving + 1] = blocks[k] end
        for k = e, s, -1 do table.remove(blocks, k) end

        -- 移除段落後，落在段落之後的插入點需往前位移整段長度
        if tgt > e then tgt = tgt - count end
        if tgt < 1 then tgt = 1 end
        if tgt > #blocks + 1 then tgt = #blocks + 1 end
        for k = #moving, 1, -1 do
            table.insert(blocks, tgt, moving[k])
        end
        RefreshBlocks()
    end)

    -- 前綴容器
    row.prefix = CreateFrame("Frame", nil, row)
    row.prefix:SetSize(22, BLOCK_ROW_MIN_HEIGHT)
    row.prefix:SetPoint("TOPLEFT", row.dragHandle, "TOPRIGHT", 2, 0)

    -- (a) Checkbox：使用內建模板（locale 字體不影響）
    row.prefixCheckbox = CreateFrame("CheckButton", nil, row.prefix, "UICheckButtonTemplate")
    row.prefixCheckbox:SetSize(20, 20)
    row.prefixCheckbox:SetPoint("CENTER", 0, 0)
    row.prefixCheckbox:Hide()
    row.prefixCheckbox:SetScript("OnClick", function(self)
        local block = row._block
        if block and block.type == BLOCK_TYPE_CHECKBOX then
            block.checked = self:GetChecked() and true or false
        end
    end)

    -- (b) Bullet：用小色塊取代 • 字符
    row.prefixBullet = row.prefix:CreateTexture(nil, "OVERLAY")
    row.prefixBullet:SetSize(5, 5)
    row.prefixBullet:SetPoint("CENTER", 0, 0)
    row.prefixBullet:SetColorTexture(unpack(S.Colors.text))
    row.prefixBullet:Hide()

    -- (c) Number：純 ASCII 文字 "1." "2." ...，使用通用字體
    row.prefixText = row.prefix:CreateFontString(nil, "OVERLAY")
    row.prefixText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.prefixText:SetPoint("CENTER", 0, 0)
    row.prefixText:SetTextColor(unpack(S.Colors.text))
    row.prefixText:Hide()

    -- EditBox
    row.editBox = CreateFrame("EditBox", nil, row)
    row.editBox:SetMultiLine(true)
    row.editBox:SetMaxLetters(0)
    row.editBox:SetAutoFocus(false)
    row.editBox:SetFontObject("ChatFontNormal")
    row.editBox:SetPoint("TOPLEFT", row.prefix, "TOPRIGHT", 4, -2)
    row.editBox:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.editBox:SetTextInsets(2, 2, 2, 2)
    row.editBox:SetCountInvisibleLetters(false)
    row.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Tab / Shift+Tab：調整縮排
    row.editBox:SetScript("OnTabPressed", function(self)
        local block = row._block
        if not block then return end
        local cur = block.indent or 0
        local new
        if IsShiftKeyDown() then
            new = math.max(0, cur - 1)
        else
            new = math.min(BLOCK_MAX_INDENT, cur + 1)
        end
        if new == cur then return end
        block.indent = (new == 0) and nil or new
        RefreshBlocks()
        -- RefreshBlocks 不會動 focus，但保險起見再 set 一次
        if row.editBox then row.editBox:SetFocus() end
    end)
    row.editBox:SetScript("OnTextChanged", function(self)
        local block = row._block
        if block then block.text = self:GetText() or "" end
        -- 高度自動跟隨 EditBox（多行折行時 EditBox 高度會增加）
        local desired = math.max(BLOCK_ROW_MIN_HEIGHT, math.ceil(self:GetHeight()) + 4)
        if math.abs((row:GetHeight() or 0) - desired) > 0.5 then
            row:SetHeight(desired)
            RelayoutBlocks()
        end
    end)

    -- 拖曳把手右鍵選單：轉換類型 / 刪除
    -- 左鍵 / 右鍵都接收，左鍵的「拖曳」與「點擊」由 RegisterForDrag 自動分流
    -- （有移動 → OnDragStart；單純點擊 → OnClick）
    row.dragHandle:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local CONVERT_OPTIONS = {
        { type = BLOCK_TYPE_TEXT,     label = "轉為文字" },
        { type = BLOCK_TYPE_CHECKBOX, label = "轉為勾選框" },
        { type = BLOCK_TYPE_BULLET,   label = "轉為項目符號" },
        { type = BLOCK_TYPE_NUMBER,   label = "轉為編號" },
    }

    local function ConvertBlockTo(targetType)
        local block = row._block
        if not block or block.type == targetType then return end
        block.type = targetType
        if targetType == BLOCK_TYPE_CHECKBOX and block.checked == nil then
            block.checked = false
        end
        RefreshBlocks()
    end

    local function IndentBlock(delta)
        local block = row._block
        if not block then return end
        local cur = block.indent or 0
        local new = math.max(0, math.min(BLOCK_MAX_INDENT, cur + delta))
        if new == cur then return end
        block.indent = (new == 0) and nil or new
        RefreshBlocks()
    end

    row.dragHandle:SetScript("OnClick", function(self, mouseButton)
        -- 左鍵單擊（沒拖動）和右鍵都開選單，方便試 UX
        if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
        local block = row._block
        if not block then return end

        local curIndent = block.indent or 0
        local canIndent  = curIndent < BLOCK_MAX_INDENT
        local canOutdent = curIndent > 0

        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(owner, root)
                for _, opt in ipairs(CONVERT_OPTIONS) do
                    if opt.type ~= block.type then
                        root:CreateButton(opt.label, function() ConvertBlockTo(opt.type) end)
                    end
                end
                if canIndent or canOutdent then
                    root:CreateDivider()
                    if canIndent then
                        root:CreateButton("增加縮排 (Tab)", function() IndentBlock(1) end)
                    end
                    if canOutdent then
                        root:CreateButton("減少縮排 (Shift+Tab)", function() IndentBlock(-1) end)
                    end
                end
                root:CreateDivider()
                root:CreateButton("|cffff5555刪除此區塊|r", function()
                    DeleteBlock(row._index)
                end)
            end)
        else
            local menuFrame = _G.MiliUI_BlockContextMenu
            if not menuFrame then
                menuFrame = CreateFrame("Frame", "MiliUI_BlockContextMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local menu = {}
            for _, opt in ipairs(CONVERT_OPTIONS) do
                if opt.type ~= block.type then
                    local t = opt.type
                    table.insert(menu, {
                        text = opt.label, notCheckable = true,
                        func = function() ConvertBlockTo(t) end,
                    })
                end
            end
            if canIndent then
                table.insert(menu, {
                    text = "增加縮排 (Tab)", notCheckable = true,
                    func = function() IndentBlock(1) end,
                })
            end
            if canOutdent then
                table.insert(menu, {
                    text = "減少縮排 (Shift+Tab)", notCheckable = true,
                    func = function() IndentBlock(-1) end,
                })
            end
            table.insert(menu, {
                text = "|cffff5555刪除此區塊|r", notCheckable = true,
                func = function() DeleteBlock(row._index) end,
            })
            EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
        end
    end)

    return row
end

------------------------------------------------------------
-- 區塊 row 配置（依照 block 內容更新顯示）
------------------------------------------------------------
local function ConfigureBlockRow(row, block, index, numberPrefix)
    row._block = block
    row._index = index

    -- 套用縮排：把 prefix 整體往右推；editBox 因錨定 prefix 會自動跟著縮短
    local indent = block.indent or 0
    indent = math.max(0, math.min(BLOCK_MAX_INDENT, indent))
    row.prefix:ClearAllPoints()
    row.prefix:SetPoint("TOPLEFT", row.dragHandle, "TOPRIGHT", 2 + indent * BLOCK_INDENT_PX, 0)

    -- 先全部隱藏，再依類型顯示對應 prefix
    row.prefixCheckbox:Hide()
    row.prefixBullet:Hide()
    row.prefixText:Hide()

    if block.type == BLOCK_TYPE_CHECKBOX then
        row.prefix:Show()
        row.prefixCheckbox:Show()
        row.prefixCheckbox:SetChecked(block.checked == true)
    elseif block.type == BLOCK_TYPE_BULLET then
        row.prefix:Show()
        row.prefixBullet:Show()
    elseif block.type == BLOCK_TYPE_NUMBER then
        row.prefix:Show()
        row.prefixText:SetText((numberPrefix or 1) .. ".")
        row.prefixText:Show()
    else  -- text
        row.prefix:Hide()
    end

    -- 同步 EditBox 文字（避免重新觸發 OnTextChanged）
    if row.editBox:GetText() ~= (block.text or "") then
        row.editBox:SetText(block.text or "")
    end
end

------------------------------------------------------------
-- 重新排列所有 row 的位置（高度可能因換行而變動）
------------------------------------------------------------
RelayoutBlocks = function()
    if not blockContainer then return end
    local y = 4
    for i, row in ipairs(blockRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", blockContainer, "TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", blockContainer, "RIGHT", 0, 0)
            y = y + row:GetHeight() + 2
        end
    end
    blockContainer:SetHeight(math.max(1, y + 4))
end

------------------------------------------------------------
-- 重繪所有區塊
------------------------------------------------------------
RefreshBlocks = function()
    if not blockContainer then return end

    -- 隱藏所有 row
    for _, row in ipairs(blockRows) do row:Hide() end

    if not currentNoteForBlocks then
        blockContainer:SetHeight(1)
        return
    end

    local blocks = currentNoteForBlocks.blocks
    if not blocks or #blocks == 0 then
        blockContainer:SetHeight(1)
        return
    end

    -- 計算 number 區塊的連續編號（依縮排階層獨立計數）
    -- 規則：
    --   1) 同階層連續的 number 區塊共用一個計數，遇到非 number 同層或更高層 → 中斷重置
    --   2) 進入更深階層時，淺階層的計數保留（不被重置）
    --   3) 從深階層回到淺階層後，深階層計數會被清掉，下次再進入時從 1 開始
    local numberPrefixes = {}
    local counters = {}  -- counters[indent] = 當前階層計數
    for i, b in ipairs(blocks) do
        local indent = b.indent or 0
        if b.type == BLOCK_TYPE_NUMBER then
            counters[indent] = (counters[indent] or 0) + 1
            numberPrefixes[i] = counters[indent]
            -- 重置「更深」層級
            for k in pairs(counters) do
                if k > indent then counters[k] = nil end
            end
        else
            -- 同層或更深的計數歸零（淺層保留）
            for k in pairs(counters) do
                if k >= indent then counters[k] = nil end
            end
        end
    end

    for i, block in ipairs(blocks) do
        local row = blockRows[i] or CreateBlockRow()
        blockRows[i] = row
        ConfigureBlockRow(row, block, i, numberPrefixes[i])
        row:Show()
    end

    RelayoutBlocks()
end

------------------------------------------------------------
-- 新增 / 刪除區塊
------------------------------------------------------------
AddBlock = function(blockType)
    if not currentNoteForBlocks then return end
    local block = { type = blockType, text = "" }
    if blockType == BLOCK_TYPE_CHECKBOX then block.checked = false end
    table.insert(currentNoteForBlocks.blocks, block)
    RefreshBlocks()
    -- focus 新區塊
    local idx = #currentNoteForBlocks.blocks
    local row = blockRows[idx]
    if row and row.editBox then row.editBox:SetFocus() end
    -- 捲到底部
    if blockContainer then
        local scroll = blockContainer:GetParent()
        if scroll and scroll.SetVerticalScroll then
            local maxScroll = math.max(0, blockContainer:GetHeight() - scroll:GetHeight())
            scroll:SetVerticalScroll(maxScroll)
        end
    end
end

DeleteBlock = function(index)
    if not currentNoteForBlocks or not currentNoteForBlocks.blocks then return end
    if not index then return end
    table.remove(currentNoteForBlocks.blocks, index)
    if #currentNoteForBlocks.blocks == 0 then
        table.insert(currentNoteForBlocks.blocks, { type = BLOCK_TYPE_TEXT, text = "" })
    end
    RefreshBlocks()
end

------------------------------------------------------------
-- 刪除確認對話框
------------------------------------------------------------
StaticPopupDialogs["MILIUI_NOTES_DELETE_CONFIRM"] = {
    text = "確定要刪除筆記「%s」？\n\n|cffff8800此操作無法復原。|r",
    button1 = "刪除",
    button2 = "取消",
    OnAccept = function(self, data)
        if data and data.confirm then data.confirm() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

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
    local noteTitle = (btn._noteData and btn._noteData.title) or "筆記"
    local thisScope = currentScope
    local otherScope = (thisScope == NOTE_SCOPE_ACCOUNT) and NOTE_SCOPE_CHAR or NOTE_SCOPE_ACCOUNT
    local moveLabel = (thisScope == NOTE_SCOPE_ACCOUNT) and "移到角色專屬" or "移到戰隊共用"

    local function DoMove()
        if selectedNoteID == noteID then SaveCurrentNote() end
        if MoveNoteToScope(noteID, thisScope, otherScope) then
            if selectedNoteID == noteID then
                selectedNoteID = nil
                ClearEditor()
            end
            RefreshNoteList()
        end
    end

    local function ConfirmDelete()
        local dialog = StaticPopup_Show("MILIUI_NOTES_DELETE_CONFIRM", noteTitle)
        if dialog then
            dialog.data = { confirm = function()
                DeleteNoteByID(noteID, thisScope)
                if selectedNoteID == noteID then
                    selectedNoteID = nil
                    ClearEditor()
                end
                RefreshNoteList()
            end }
        end
    end

    -- 優先使用 retail 12.x 的 MenuUtil API
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(btn, function(owner, root)
            root:CreateTitle(noteTitle)
            root:CreateButton(moveLabel, DoMove)
            root:CreateDivider()
            root:CreateButton("|cffff5555刪除|r", ConfirmDelete)
        end)
        return
    end

    -- Fallback：舊版 EasyMenu
    local menuFrame = _G.MiliUI_NoteContextMenu
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "MiliUI_NoteContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = {
        { text = noteTitle, isTitle = true, notCheckable = true },
        { text = moveLabel, notCheckable = true, func = DoMove },
        { text = "|cffff5555刪除|r", notCheckable = true, func = ConfirmDelete },
    }
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

------------------------------------------------------------
-- 筆記列表更新
------------------------------------------------------------
RefreshNoteList = function()
    if not listContent then return end
    local allNotes = GetNotesForScope(currentScope)

    -- 套用搜尋篩選
    local notes
    if currentFilter ~= "" then
        notes = {}
        for _, n in ipairs(allNotes) do
            local match = (n.title or ""):lower():find(currentFilter, 1, true)
            if not match and type(n.blocks) == "table" then
                for _, b in ipairs(n.blocks) do
                    if (b.text or ""):lower():find(currentFilter, 1, true) then
                        match = true
                        break
                    end
                end
            end
            if not match and type(n.content) == "string" then
                match = n.content:lower():find(currentFilter, 1, true)
            end
            if match then table.insert(notes, n) end
        end
    else
        notes = allNotes
    end

    -- 隱藏所有按鈕；selectedButton 會在下方的迴圈重新指定
    selectedButton = nil
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

            -- 拖曳開始：記錄來源筆記 ID，啟動 OnUpdate 監控
            btn:SetScript("OnDragStart", function(self)
                if currentFilter ~= "" then return end  -- 篩選中不允許排序
                if not self._noteID then return end
                dragState = { sourceID = self._noteID, targetIndex = nil }
                self:SetAlpha(0.4)
                listScroll:SetScript("OnUpdate", DragMonitor)
            end)

            -- 拖曳結束：套用排序，停掉 OnUpdate
            btn:SetScript("OnDragStop", function(self)
                local state = dragState
                CancelDrag()
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
                if self ~= selectedButton then
                    self:SetBackdropColor(unpack(S.Colors.bgHover))
                    self:SetBackdropBorderColor(unpack(S.Colors.borderHover))
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if self ~= selectedButton then
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
                -- O(1) 切換：只更新前一個與當前
                if selectedButton and selectedButton ~= self then
                    SetButtonSelected(selectedButton, false)
                end
                selectedNoteID = self._noteID
                selectedButton = self
                SetButtonSelected(self, true)
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
            selectedButton = btn
            SetButtonSelected(btn, true)
        else
            SetButtonSelected(btn, false)
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
    titleEditBox:SetCursorPosition(0)
    -- 區塊：必要時自動 migrate
    MigrateNoteToBlocks(note)
    currentNoteForBlocks = note
    if RefreshBlocks then RefreshBlocks() end
end

ClearEditor = function()
    if not titleEditBox then return end
    titleEditBox:SetText("")
    titleEditBox:ClearFocus()
    currentNoteForBlocks = nil
    if RefreshBlocks then RefreshBlocks() end
end

SaveCurrentNote = function()
    if not selectedNoteID then return end
    if not titleEditBox then return end
    local notes = GetNotesForScope(currentScope)
    for _, note in ipairs(notes) do
        if note.id == selectedNoteID then
            local newTitle  = titleEditBox:GetText()
            local finalTitle = (newTitle ~= "") and newTitle or "無標題"
            local titleChanged = (finalTitle ~= note.title)
            note.title = finalTitle
            note.time  = time()
            -- 區塊內容已透過各 EditBox 的 OnTextChanged 即時寫入 note.blocks，
            -- 這裡不需另外處理。
            if titleChanged and selectedButton and selectedButton._noteID == selectedNoteID then
                selectedButton._text:SetText(finalTitle)
            end
            return
        end
    end
end

------------------------------------------------------------
-- 標籤頁管理
------------------------------------------------------------
local TAB_NAME = "角色筆記"

local function ShowNotesTab()
    if not tabFrame then return end
    tabFrame:Show()
    if editorFrame then editorFrame:Show() end
end

local function HideNotesTab()
    if not tabFrame then return end
    SaveCurrentNote()
    CancelDrag()       -- 安全清理：列表拖曳殘留
    CancelBlockDrag()  -- 區塊拖曳殘留
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

    local origNumTabs   = #existingTabs > 0 and #existingTabs or 3
    local notesTabIndex = origNumTabs + 1

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

    -- 切換離開時還原 tab 視覺：依靠下方原生 tab 的 OnClick hook
    -- 不 hook 全域 PanelTemplates_SetTab —— retail 的 TabSystem 會在我們之後
    -- 再次呼叫該函式並把 selectedTab 重設成預設 id，導致 tabFrame 立刻被隱藏。

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

    -- 原生子面板被顯示時（例如按 C 走 ToggleCharacter 切回角色頁，
    -- 或其他插件程式化切換 tab），收起筆記浮層，避免它蓋在角色頁上方。
    -- 這條路徑不會觸發原生 tab 的 OnClick，故需另外掛 OnShow。
    local nativeSubFrames = { PaperDollFrame, ReputationFrame, TokenFrame, CurrencyFrame }
    for _, f in ipairs(nativeSubFrames) do
        if f and f.HookScript then
            f:HookScript("OnShow", function()
                if tabFrame and tabFrame:IsShown() then
                    HideNotesTab()
                    if charTab._SetTabSelected then
                        charTab._isSelected = false
                        charTab:_SetTabSelected(false)
                    end
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
-- 初始化
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_LOGIN")
    InitDB()
    -- 還原本角色上次使用的 tab
    local saved = ReadSavedScope()
    if saved then currentScope = saved end
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
