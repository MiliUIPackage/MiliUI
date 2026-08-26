------------------------------------------------------------
-- 筆記本主視窗：分頁 ＋ 工具列 ＋ 清單
--
-- 三個分頁共用同一個清單與同一組列（列會回收），差別只在餵給它的資料：
--   戰隊共用 / 角色專屬  一維陣列，可拖曳排序
--   副本                  副本 → （副本總覽 ＋ 各首領）的兩層樹，不可排序
--
-- 編輯是另一個視窗（UI/Editor.lua），依附在這個視窗右側。
------------------------------------------------------------
local _, ns = ...

ns.Window = {}
local Window = ns.Window

local W, P, L = ns.W, ns.P, ns.L
local Notes, Media, Journal = ns.Notes, ns.Media, ns.Journal

local WINDOW_W, WINDOW_H = 380, 520
local HEADER_H  = 24
local TAB_H     = 22
local TOOLBAR_H = 26
local ROW_H     = 26
local PAD       = 8

local TAB_ACCOUNT  = Notes.SCOPE_ACCOUNT
local TAB_CHAR     = Notes.SCOPE_CHAR
local TAB_INSTANCE = Notes.SCOPE_INSTANCE

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local frame, listScroll, listContent, searchRow, searchBox, toolbar
local tabButtons, highlightTab = {}, nil
local addButton, charButton, filterButton, emptyLabel
local deletePopup, deleteTarget

local currentTab     = TAB_ACCOUNT
local selectedChar               -- 角色專屬分頁看的是哪個分身
local filterText     = ""
local selectedNoteID             -- 平面清單的選取
local selectedInst               -- 副本分頁的選取 { instanceID, encounterID, diff }
local expanded       = {}        -- [instanceID] = true
local selectedDiff   = {}        -- [instanceID] = 難度 key（團本才用得到）
local instScope      = "season"  -- season / all / noted
local instType       = "all"     -- all / party / raid
local catalogueReady = false

local rows = {}
local rowItems = {}
local dragState, dragLine

-- 前向宣告：列的 OnClick 在這兩支之前就寫好了，不宣告的話它們會被當成全域
-- （`luac -p` 抓不到，只有 `luac -l` 掃 _ENV 讀取才看得出來）
local Refresh, ShowDiffMenu

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
    selectedInst = nil
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

local function OpenInstanceNote(instanceID, encounterID, diffKey)
    diffKey = Notes.NormalizeDiffKey(diffKey)
    local instName = Journal.InstanceName(instanceID) or "?"
    local title, context
    if encounterID then
        local bossName = Journal.EncounterName(instanceID, encounterID) or "?"
        title   = bossName
        context = instName .. " - " .. bossName
    else
        title   = instName
        context = instName
    end
    -- 標題列要看得出這是哪個難度的那一份，不然兩份筆記長得一模一樣
    local label = context
    if diffKey ~= Notes.DIFF_ALL then
        label = context .. " |cff808080[" .. Journal.DifficultyName(diffKey) .. "]|r"
    end

    local info = Journal.InstanceInfo(instanceID)
    local note = Notes.EnsureInstanceNote(instanceID, encounterID, diffKey, title, {
        name   = instName,
        isRaid = info and info.isRaid,
    })
    Journal.StampDungeonID(note, instanceID, encounterID)

    selectedNoteID = nil
    selectedInst = { instanceID = instanceID, encounterID = encounterID, diff = diffKey }
    ns.Editor.Open(note, {
        label = label,
        readonlyTitle = true,
        plainBlocks   = true,
        onEdited = function() ns.Sync.SchedulePush(instanceID) end,
        share = {
            kind        = encounterID and "boss" or "instance",
            instanceID  = instanceID,
            encounterID = encounterID,
            diff        = diffKey,
            context     = context,
        },
    })
    ns.Fire("NotesChanged")
end

------------------------------------------------------------
-- 清單資料：把三個分頁攤成同一種「列描述」
------------------------------------------------------------
local function BuildFlatItems(out)
    local list = CurrentList()
    for i, note in ipairs(list) do
        if NoteMatches(note) then
            out[#out + 1] = {
                kind     = "note",
                note     = note,
                index    = i,
                label    = note.title ~= "" and note.title or L["Untitled"],
                selected = note.id == selectedNoteID,
                dot      = not Notes.IsEmpty(note),
            }
        end
    end
end

local function InstancePasses(entry)
    if instType == "party" and entry.isRaid then return false end
    if instType == "raid" and not entry.isRaid then return false end
    if instScope == "noted" then return Notes.InstanceHasNotes(entry.id) end
    if instScope == "season" then
        if Journal.SeasonInstances()[entry.id] then return true end
        -- 有寫過筆記的舊副本一律留著，不然玩家會以為筆記不見了
        return Notes.InstanceHasNotes(entry.id)
    end
    return true
end

-- 這個副本目前看的是哪個難度（地城沒有難度這回事，一律 all）
local function DiffFor(entry)
    if not entry.isRaid then return Notes.DIFF_ALL end
    return selectedDiff[entry.id] or Notes.DIFF_ALL
end

local function BuildInstanceItems(out)
    local cat = Journal.Catalogue()
    local curInst = Journal.CurrentInstance()

    for _, entry in ipairs(cat.list) do
      -- ⚠ 篩選條件要先過。下面那段為了「用首領名字搜尋」會去列舉首領清單，
      --   而那是每個副本一次冒險指南查詢 —— 先過濾能把它從幾百次降到十幾次。
      if InstancePasses(entry) then
        local encounters = nil
        local nameHit = Matches(entry.name)
        local childHit = false

        if filterText ~= "" and not nameHit then
            encounters = Journal.Encounters(entry.id)
            for _, e in ipairs(encounters) do
                if Matches(e.name) then childHit = true break end
            end
        end

        if nameHit or childHit then
            -- 搜尋命中首領時強制展開，否則玩家看不到自己找的那一行
            local isOpen = expanded[entry.id] or childHit
            out[#out + 1] = {
                kind       = "instance",
                instanceID = entry.id,
                label      = entry.name,
                isRaid     = entry.isRaid,
                expanded   = isOpen,
                current    = entry.id == curInst,
                dot        = Notes.InstanceHasNotes(entry.id),
            }
            if isOpen then
                local diff = DiffFor(entry)
                local function IsSelected(encID)
                    return selectedInst ~= nil and selectedInst.instanceID == entry.id
                       and selectedInst.encounterID == encID and selectedInst.diff == diff
                end

                -- 團本多一列難度切換。地城沒有這一列 —— 鑰石等級不影響打法筆記，
                -- 多一列只是每個副本都要多讀一行
                if entry.isRaid then
                    out[#out + 1] = {
                        kind       = "diff",
                        instanceID = entry.id,
                        diff       = diff,
                        label      = L["Difficulty"] .. "：" .. Journal.DifficultyName(diff),
                        dot        = Notes.BucketHasNotes(entry.id, diff),
                    }
                end

                local overview = Notes.GetInstanceNote(entry.id, nil, diff)
                out[#out + 1] = {
                    kind       = "instanceNote",
                    instanceID = entry.id,
                    diff       = diff,
                    label      = L["Dungeon overview"],
                    dot        = overview ~= nil and not Notes.IsEmpty(overview),
                    selected   = IsSelected(nil),
                }
                encounters = encounters or Journal.Encounters(entry.id)
                for _, e in ipairs(encounters) do
                    local note = Notes.GetInstanceNote(entry.id, e.id, diff)
                    out[#out + 1] = {
                        kind        = "instanceNote",
                        instanceID  = entry.id,
                        encounterID = e.id,
                        diff        = diff,
                        label       = e.name,
                        dot         = note ~= nil and not Notes.IsEmpty(note),
                        selected    = IsSelected(e.id),
                    }
                end
            end
        end
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

local function ShowInstanceNoteMenu(row)
    local instanceID, encID = row._instanceID, row._encounterID
    local diff = Notes.NormalizeDiffKey(row._diff)
    local note = Notes.GetInstanceNote(instanceID, encID, diff)
    local instName = Journal.InstanceName(instanceID) or "?"
    local label = encID and (Journal.EncounterName(instanceID, encID) or "?") or instName
    local title = label
    if diff ~= Notes.DIFF_ALL then
        title = label .. " |cff808080[" .. Journal.DifficultyName(diff) .. "]|r"
    end
    local items = { { text = title, isTitle = true } }

    if note then
        items[#items + 1] = { text = L["Share..."], onClick = function()
            ns.Share.ShowShareMenu(row, note, {
                kind        = encID and "boss" or "instance",
                instanceID  = instanceID,
                encounterID = encID,
                diff        = diff,
                context     = encID and (instName .. " - " .. label) or instName,
            })
        end }
        items[#items + 1] = { isSeparator = true }
        items[#items + 1] = { text = "|cffff5555" .. L["Delete"] .. "|r", onClick = function()
            ConfirmDelete(label, function()
                if ns.Editor.IsEditing(note) then ns.Editor.Close() end
                Notes.DeleteInstanceNote(instanceID, encID, diff)
                selectedInst = nil
                Refresh()
            end)
        end }
    else
        items[#items + 1] = { text = "|cff808080" .. L["Nothing written here yet"] .. "|r",
                              onClick = function() end }
    end
    W.Menu.Show(items, row)
end

------------------------------------------------------------
-- 拖曳排序（只有平面清單）
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
        if r:IsShown() and r._kind == "note" then
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

    row.arrow = row:CreateFontString(nil, "OVERLAY")
    row.arrow:SetFontObject(W.fontSmall)
    row.arrow:SetPoint("LEFT", 6, 0)
    row.arrow:SetWidth(12)
    row.arrow:SetJustifyH("CENTER")

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFontObject(Media.fontBody)
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetPoint("RIGHT", -18, 0)
    row.text:SetJustifyH("LEFT")
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
        if self._kind == "note" then
            if button == "RightButton" then ShowNoteMenu(self) return end
            OpenNote(self._note)
            Refresh()
        elseif self._kind == "instance" then
            if button == "RightButton" then return end
            expanded[self._instanceID] = not expanded[self._instanceID]
            Refresh()
        elseif self._kind == "diff" then
            ShowDiffMenu(self)
        elseif self._kind == "instanceNote" then
            if button == "RightButton" then ShowInstanceNoteMenu(self) return end
            OpenInstanceNote(self._instanceID, self._encounterID, self._diff)
            Refresh()
        end
    end)

    row:SetScript("OnDragStart", function(self)
        if self._kind ~= "note" then return end
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
    row._kind        = item.kind
    row._note        = item.note
    row._index       = item.index
    row._instanceID  = item.instanceID
    row._encounterID = item.encounterID
    row._diff        = item.diff
    row._selected    = item.selected == true
    row:SetAlpha(1)

    -- ⚠ 每次都重下錨點：同一顆列會在三種縮排之間輪流被回收使用
    row.text:ClearAllPoints()
    row.text:SetPoint("RIGHT", -18, 0)

    if item.kind == "instance" then
        row.arrow:Show()
        row.arrow:SetText(item.expanded and "-" or "+")
        row.arrow:SetTextColor(W.Accent(1))
        row.text:SetPoint("LEFT", 22, 0)
        row.text:SetFontObject(Media.fontHead)
        local prefix = item.current and ("|cff00ff00" .. L["Here"] .. "|r ") or ""
        row.text:SetText(prefix .. (item.label or "?"))
        row.text:SetTextColor(1, 1, 1)
    elseif item.kind == "diff" then
        -- 難度切換列：長得像下拉而不是像筆記（右邊一個小三角，字用弱一階的灰）
        row.arrow:Hide()
        row.text:SetFontObject(Media.fontBody)
        row.text:SetPoint("LEFT", 30, 0)
        row.text:SetText((item.label or "?") .. " |cff808080v|r")
        row.text:SetTextColor(W.Accent(1))
    else
        row.arrow:Hide()
        row.text:SetFontObject(Media.fontBody)
        if item.kind == "instanceNote" then
            row.text:SetPoint("LEFT", 30, 0)
            row.text:SetTextColor(0.85, 0.85, 0.85)
        else
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetTextColor(0.92, 0.92, 0.92)
        end
        row.text:SetText(item.label or "?")
    end

    row.dot:SetShown(item.dot == true)
    StyleRow(row, row._selected)
end

------------------------------------------------------------
-- 重繪
------------------------------------------------------------
Refresh = function()
    if not frame then return end

    -- 工具列跟著分頁換
    addButton:SetShown(currentTab ~= TAB_INSTANCE)
    charButton:SetShown(currentTab == TAB_CHAR)
    filterButton:SetShown(currentTab == TAB_INSTANCE)
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
    if currentTab == TAB_INSTANCE then
        if catalogueReady then BuildInstanceItems(rowItems) end
    else
        BuildFlatItems(rowItems)
    end

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
    if currentTab == TAB_INSTANCE and not catalogueReady then
        msg = L["Loading the dungeon list..."]
    elseif #rowItems == 0 then
        if filterText ~= "" then
            msg = L["Nothing matches your search."]
        elseif currentTab == TAB_INSTANCE then
            msg = L["No dungeons match this filter."]
        else
            msg = L["No notes yet. Use New to write one."]
        end
    end
    emptyLabel:SetText(msg or "")
    emptyLabel:SetShown(msg ~= nil)
end

Window.Refresh = Refresh

------------------------------------------------------------
-- 副本清單的建立（很貴，只在第一次進副本分頁時做）
------------------------------------------------------------
local function EnsureCatalogue()
    if catalogueReady then return end
    Refresh()                       -- 先把「載入中」畫出來
    C_Timer.After(0, function()
        Journal.Catalogue()
        catalogueReady = true
        -- 開在目前所在的副本上，省得玩家自己找
        local cur = Journal.CurrentInstance()
        if cur then expanded[cur] = true end
        Refresh()
    end)
end

------------------------------------------------------------
-- 分頁切換
------------------------------------------------------------
local function SwitchTab(id)
    if currentTab == id then return end
    ns.Editor.Commit()
    currentTab = id
    selectedNoteID = nil
    selectedInst = nil
    ns.Editor.Close()
    if searchBox then searchBox:SetText("") end
    filterText = ""

    local key = ns.CurrentCharKey()
    ns.db.perChar[key] = ns.db.perChar[key] or {}
    ns.db.perChar[key].lastScope = id

    if id == TAB_INSTANCE then EnsureCatalogue() end
    Refresh()
end

------------------------------------------------------------
-- 篩選選單（副本分頁）
------------------------------------------------------------
ShowDiffMenu = function(row)
    local instanceID = row._instanceID
    local written = Notes.WrittenDifficulties(instanceID)
    local cur = selectedDiff[instanceID] or Notes.DIFF_ALL

    local function Item(key)
        return {
            text = Journal.DifficultyName(key) .. (written[key] and " |cff808080*|r" or ""),
            isActive = cur == key,
            onClick = function()
                ns.Editor.Close()
                selectedDiff[instanceID] = key
                selectedInst = nil
                Refresh()
            end,
        }
    end

    local items = { { text = L["Difficulty"], isTitle = true }, Item(Notes.DIFF_ALL) }
    items[#items + 1] = { isSeparator = true }
    for _, d in ipairs(Journal.RaidDifficulties()) do
        items[#items + 1] = Item(d.key)
    end
    W.Menu.Show(items, row)
end

local function ShowFilterMenu(anchor)
    local items = {
        { text = L["Show"], isTitle = true },
        { text = L["This season"], isActive = instScope == "season",
          onClick = function() instScope = "season" Refresh() end },
        { text = L["All expansions"], isActive = instScope == "all",
          onClick = function() instScope = "all" Refresh() end },
        { text = L["Only ones I wrote in"], isActive = instScope == "noted",
          onClick = function() instScope = "noted" Refresh() end },
        { isSeparator = true },
        { text = L["Type"], isTitle = true },
        { text = L["Everything"], isActive = instType == "all",
          onClick = function() instType = "all" Refresh() end },
        { text = L["Dungeons"], isActive = instType == "party",
          onClick = function() instType = "party" Refresh() end },
        { text = L["Raids"], isActive = instType == "raid",
          onClick = function() instType = "raid" Refresh() end },
    }
    local cur, _, instanceType, difficultyID = Journal.CurrentInstance()
    if cur then
        items[#items + 1] = { isSeparator = true }
        items[#items + 1] = { text = L["Jump to where I am"], onClick = function()
            expanded[cur] = true
            instScope = "all"
            -- 團本順便切到現在打的難度，省得玩家還要再點一次
            if instanceType == "raid" and type(difficultyID) == "number" then
                selectedDiff[cur] = difficultyID
            end
            Refresh()
        end }
    end
    W.Menu.Show(items, anchor)
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
        { id = TAB_INSTANCE, label = L["Instances"] },
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

    filterButton = W.CreateButton(toolbar, L["Filter"], "normal", 70, TOOLBAR_H - 2)
    filterButton:SetPoint("LEFT", toolbar, "LEFT", 4, 0)
    filterButton:SetScript("OnClick", function(self) ShowFilterMenu(self) end)

    -- 搜尋：放大鏡當開關，搜尋條插在工具列與清單之間
    local searchToggle = W.CreateButton(toolbar, "", "normal", TOOLBAR_H - 2, TOOLBAR_H - 2)
    searchToggle:SetPoint("RIGHT", -4, 0)
    local searchIcon = searchToggle:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("CENTER")
    searchIcon:SetVertexColor(0.9, 0.9, 0.9)

    -- 「試試看」：把副本浮動視窗叫出來。放在搜尋左邊、跟著右緣走 ——
    -- 它是驗證用的動作，不該跟左邊那排「新增／篩選」搶主要位置。
    local tryBtn = W.CreateButton(toolbar, L["Try it"], "normal", 64, TOOLBAR_H - 2)
    tryBtn:SetPoint("RIGHT", searchToggle, "LEFT", -4, 0)
    tryBtn:SetScript("OnClick", function() ns.Overlay.Toggle() end)
    tryBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self._colors[2]))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Show the dungeon note window"])
        GameTooltip:AddLine(L["Works anywhere, so you can try the layout out before a run."],
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    tryBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self._colors[1]))
        GameTooltip:Hide()
    end)

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
    if startTab ~= TAB_CHAR and startTab ~= TAB_INSTANCE then startTab = TAB_ACCOUNT end
    currentTab = startTab
    for _, b in ipairs(tabButtons) do
        if b.id == startTab then highlightTab(b) break end
    end
    if startTab == TAB_INSTANCE then EnsureCatalogue() end
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

-- 副本浮動視窗的「編輯」按鈕：開主視窗、切到副本分頁、直接開那一筆
function Window.EditInstanceNote(instanceID, encounterID, diffKey)
    Window.Show()
    if currentTab ~= TAB_INSTANCE then
        currentTab = TAB_INSTANCE
        for _, b in ipairs(tabButtons) do
            if b.id == TAB_INSTANCE then highlightTab(b) break end
        end
        EnsureCatalogue()
    end
    expanded[instanceID] = true
    diffKey = Notes.NormalizeDiffKey(diffKey)
    selectedDiff[instanceID] = diffKey
    -- 「本季」看不到的舊副本也要跳得過去（浮動視窗是從實際所在的副本叫過來的）
    if instScope == "season" and not Journal.SeasonInstances()[instanceID] then
        instScope = "all"
    end
    OpenInstanceNote(instanceID, encounterID, diffKey)
    Refresh()
end

ns.RegisterCallback("NotesChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)

ns.RegisterCallback("SettingsChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
