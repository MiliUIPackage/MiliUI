------------------------------------------------------------
-- 編輯視窗：標題 ＋ 區塊工具列 ＋ 區塊清單
--
-- 獨立浮動視窗，依附在筆記本主視窗的右上（偏移量存檔，跟著主視窗一起移動）。
-- 內容是**即時寫回**筆記的（每個 EditBox 的 OnTextChanged 就寫），所以沒有
-- 「儲存」按鈕，關窗也不會掉東西。
------------------------------------------------------------
local _, ns = ...

ns.Editor = {}
local Editor = ns.Editor

local W, P, L = ns.W, ns.P, ns.L
local Notes, Media = ns.Notes, ns.Media

local EDITOR_W, EDITOR_H = 420, 500
local HEADER_H  = 24
local TOOLBAR_H = 26

local frame, titleBox, blockEditor, contextLabel, shareBtn
local blockBar, tagBar, spellPopup, prevTag
local current           -- { note = , ctx = }

------------------------------------------------------------
-- 位置：以主視窗右上為錨點記錄偏移
------------------------------------------------------------
local function AnchorToMain()
    local main = ns.Window and ns.Window.Frame()
    local off = ns.db.windows.editorOffset
    local x = (type(off) == "table" and type(off.x) == "number") and off.x or 8
    local y = (type(off) == "table" and type(off.y) == "number") and off.y or 0
    frame:ClearAllPoints()
    if main then
        frame:SetPoint("TOPLEFT", main, "TOPRIGHT", x, y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
    end
end

local function SaveOffset()
    local main = ns.Window and ns.Window.Frame()
    if not main then return end
    -- StopMovingOrSizing 之後錨點會變成 UIParent 的絕對座標，換算回相對主視窗的偏移
    local es, cs = frame:GetEffectiveScale(), main:GetEffectiveScale()
    local x = (frame:GetLeft() * es - main:GetRight() * cs) / es
    local y = (frame:GetTop()  * es - main:GetTop()   * cs) / es
    ns.db.windows.editorOffset = { x = x, y = y }
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", main, "TOPRIGHT", x, y)
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function Build()
    if frame then return end

    frame = W.CreateFrame("MiliUINote_Editor", UIParent, EDITOR_W, EDITOR_H)
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(60)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    W.CloseOnEscape(frame)

    -- 標題列兼拖曳把手
    local header = W.CreateFrame(nil, frame, nil, nil)
    header:SetHeight(P.Scale(HEADER_H))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveOffset()
    end)

    contextLabel = header:CreateFontString(nil, "OVERLAY")
    contextLabel:SetFontObject(W.fontNormal)
    contextLabel:SetPoint("LEFT", 8, 0)
    contextLabel:SetPoint("RIGHT", -52, 0)
    contextLabel:SetJustifyH("LEFT")
    contextLabel:SetWordWrap(false)

    local close = W.CreateButton(header, "", "red", 18, 18)
    close:SetPoint("RIGHT", -3, 0)
    local closeX = close:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(10, 10)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() Editor.Close() end)

    shareBtn = W.CreateButton(header, "", "normal", 18, 18)
    shareBtn:SetPoint("RIGHT", close, "LEFT", -3, 0)
    local shareIcon = shareBtn:CreateTexture(nil, "OVERLAY")
    shareIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    shareIcon:SetSize(12, 12)
    shareIcon:SetPoint("CENTER")
    shareBtn:SetScript("OnClick", function(self)
        if not current then return end
        ns.Share.ShowShareMenu(self, current.note, current.ctx and current.ctx.share)
    end)
    shareBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self._colors[2]))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Share this note"])
        GameTooltip:Show()
    end)
    shareBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self._colors[1]))
        GameTooltip:Hide()
    end)

    -- 標題
    titleBox = W.CreateEditBox(frame, EDITOR_W - 16, 26)
    titleBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -8)
    titleBox:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -8, -8)
    titleBox:SetFontObject(Media.fontHead)
    titleBox:SetMaxLetters(200)
    titleBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local row = blockEditor and blockEditor.rows[1]
        if row and row:IsShown() and row.editBox then row.editBox:SetFocus() end
    end)
    titleBox:SetScript("OnTextChanged", function(self, userInput)
        if not (userInput and current) then return end
        current.note.title = self:GetText() or ""
        Notes.Touch(current.note)
        if current.ctx and current.ctx.onTitleChanged then
            current.ctx.onTitleChanged(current.note)
        end
        if current.ctx and current.ctx.onEdited then
            current.ctx.onEdited()
        end
    end)

    ------------------------------------------------------------
    -- 工具列
    --
    -- 兩排：上排「加入區塊」（副本／首領筆記用不到，見下面的 plainBlocks），
    -- 下排「插入標記」。標記全部走選單、能不打字就不打字 —— 團隊標記直接列圖示、
    -- 名字直接列目前隊友與分組變數、時間給常用的幾個offset。
    ------------------------------------------------------------
    blockBar = CreateFrame("Frame", nil, frame)
    blockBar:SetHeight(P.Scale(TOOLBAR_H))
    blockBar:SetPoint("TOPLEFT", titleBox, "BOTTOMLEFT", 0, -6)
    blockBar:SetPoint("TOPRIGHT", titleBox, "BOTTOMRIGHT", 0, -6)

    local addLabel = blockBar:CreateFontString(nil, "OVERLAY")
    addLabel:SetFontObject(W.fontSmall)
    addLabel:SetPoint("LEFT", 0, 0)
    addLabel:SetText(L["Add block:"])

    local prev = addLabel
    local TYPES = {
        { key = "Text",     type = Notes.TYPE_TEXT },
        { key = "Checkbox", type = Notes.TYPE_CHECKBOX },
        { key = "Bullet",   type = Notes.TYPE_BULLET },
        { key = "Numbered", type = Notes.TYPE_NUMBER },
    }
    for _, t in ipairs(TYPES) do
        local b = W.CreateButton(blockBar, L[t.key], "accent-hover", 60, TOOLBAR_H - 4)
        b:SetPoint("LEFT", prev, "RIGHT", 5, 0)
        local blockType = t.type
        b:SetScript("OnClick", function()
            if blockEditor then blockEditor:AddBlock(blockType) end
        end)
        prev = b
    end

    tagBar = CreateFrame("Frame", nil, frame)
    tagBar:SetHeight(P.Scale(TOOLBAR_H))
    tagBar:SetPoint("TOPLEFT", blockBar, "BOTTOMLEFT", 0, -4)
    tagBar:SetPoint("TOPRIGHT", blockBar, "BOTTOMRIGHT", 0, -4)

    local tagLabel = tagBar:CreateFontString(nil, "OVERLAY")
    tagLabel:SetFontObject(W.fontSmall)
    tagLabel:SetPoint("LEFT", 0, 0)
    tagLabel:SetText(L["Insert:"])

    -- 每一顆都是「按了開選單」，選單裡才是實際內容。按鈕上不放 ▾ ——
    -- 這一排全部都是選單，統一到沒有例外的時候，符號只是噪音。
    local function TagButton(labelKey, tooltipKey, builder)
        local b = W.CreateButton(tagBar, L[labelKey], "accent-hover", 58, TOOLBAR_H - 4)
        b:SetPoint("LEFT", prevTag or tagLabel, "RIGHT", 5, 0)
        b:SetScript("OnClick", function(self) W.Menu.Show(builder(), self) end)
        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(self._colors[2]))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L[labelKey])
            GameTooltip:AddLine(L[tooltipKey], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(self._colors[1]))
            GameTooltip:Hide()
        end)
        prevTag = b
        return b
    end

    local function Insert(text, back)
        if blockEditor then blockEditor:InsertAtCursor(text, back) end
    end

    ------------------------------------------------------------
    -- 時間
    ------------------------------------------------------------
    local TIME_PRESETS = { 5, 10, 15, 20, 30, 45, 60, 90, 120, 180 }

    TagButton("Time", "Marks when this line happens. It counts down once the fight starts.", function()
        local items = { { text = L["Time"], isTitle = true } }
        for _, sec in ipairs(TIME_PRESETS) do
            items[#items + 1] = {
                text = ("%d:%02d"):format(math.floor(sec / 60), sec % 60),
                onClick = function()
                    Insert(("{time:%d:%02d} "):format(math.floor(sec / 60), sec % 60))
                end,
            }
        end
        items[#items + 1] = { isSeparator = true }
        items[#items + 1] = {
            -- 游標停在冒號後面，直接打數字就好
            text = L["Type it myself..."],
            onClick = function() Insert("{time:}", 1) end,
        }
        return items
    end)

    ------------------------------------------------------------
    -- 團隊標記：選單裡直接畫出圖示，不用記哪個號碼是哪個
    ------------------------------------------------------------
    TagButton("Marker", "Raid target icons — star, circle, diamond and so on.", function()
        local items = { { text = L["Marker"], isTitle = true } }
        for i = 1, 8 do
            items[#items + 1] = {
                text = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t  %d"):format(i, i),
                onClick = function() Insert(("{rt%d} "):format(i)) end,
            }
        end
        return items
    end)

    ------------------------------------------------------------
    -- 法術
    ------------------------------------------------------------
    TagButton("Spell", "Shows a spell's icon and name. Paste a spell link or type its ID.", function()
        return { {
            text = L["Pick a spell..."],
            onClick = function()
                if not spellPopup then
                    spellPopup = W.CreateInputPopup(frame, 320, L["Insert a spell"], {
                        { key = "spell", label = L["Spell ID or link"],
                          hint = L["Shift-click a spell from your spellbook into the chat box to get its link, then paste it here."] },
                    })
                end
                spellPopup:Open({}, function(values)
                    -- 連結（|Hspell:12345:...|h）與純數字都吃
                    local raw = values.spell or ""
                    local id = raw:match("|Hspell:(%d+)") or raw:match("^%s*(%d+)%s*$")
                    if not id then return false end
                    Insert(("{spell:%s} "):format(id))
                end)
            end,
        } }
    end)

    ------------------------------------------------------------
    -- 名字：插入分組變數或隊友名字（顯示用）
    ------------------------------------------------------------
    TagButton("Name", "Inserts who does it. Use a group variable so next run you only reassign the roster.", function()
        return ns.RosterMenu.InsertItems(function(token) Insert(("{p:%s} "):format(token)) end)
    end)

    ------------------------------------------------------------
    -- 限定顯示：整段只給某些人看
    ------------------------------------------------------------
    TagButton("Only for", "Hides the rest of the line from everyone else.", function()
        local items = {
            { text = L["Only these people see it"], isTitle = true },
            { text = L["A person or group..."],
              submenu = ns.RosterMenu.InsertItems(function(token)
                  Insert(("{p:%s}{/p}"):format(token), 4)
              end) },
            { isSeparator = true },
            { text = L["Tanks"],   onClick = function() Insert("{t}{/t}", 4) end },
            { text = L["Healers"], onClick = function() Insert("{h}{/h}", 4) end },
            { text = L["Damage"],  onClick = function() Insert("{d}{/d}", 4) end },
            { isSeparator = true },
            { text = L["A class..."], submenu = ns.RosterMenu.ClassItems(function(classFile)
                  Insert(("{c:%s}{/c}"):format(classFile), 4)
              end) },
        }
        return items
    end)

    -- 區塊清單
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", tagBar, "BOTTOMLEFT", 0, -6)
    holder:SetPoint("BOTTOMRIGHT", -8, 8)
    local scroll = W.CreateScrollFrame(holder)
    blockEditor = ns.Blocks.CreateEditor(scroll, function()
        if current and current.ctx and current.ctx.onEdited then
            current.ctx.onEdited()
        end
    end)

    -- ⚠ 收尾掛在 OnHide，不能只寫在 Editor.Close() 裡：ESC 是繞過那支直接把框藏掉的
    frame:SetScript("OnHide", function()
        if blockEditor then
            blockEditor:Commit()
            blockEditor.CancelDrag()
        end
        W.Menu.Hide()
        current = nil
    end)
end

------------------------------------------------------------
-- 工具列版面
--
-- 副本／首領筆記是時間軸，一整篇都是文字行 —— 勾選框／項目符號／編號那一排
-- 在那裡是雜訊，整排收起來，標記那排往上補位。
------------------------------------------------------------
local function LayoutBars(plain)
    blockBar:SetShown(not plain)
    local ref = plain and titleBox or blockBar
    tagBar:ClearAllPoints()
    tagBar:SetPoint("TOPLEFT", ref, "BOTTOMLEFT", 0, -6)
    tagBar:SetPoint("TOPRIGHT", ref, "BOTTOMRIGHT", 0, -6)
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
-- ctx = {
--   label           標題列上的來源說明（「副本 · 首領名」之類）
--   readonlyTitle   true = 標題由副本／首領名字決定，玩家不能改
--   plainBlocks     true = 全部都是文字行，不顯示「加入區塊」那一排
--   onTitleChanged  標題改了要通知宿主刷新清單
--   share           分享用的中繼資料 { kind, instanceID, encounterID, context }
-- }
function Editor.Open(note, ctx)
    if not note then return end
    Build()
    current = { note = note, ctx = ctx or {} }

    Notes.EnsureBlocks(note)
    titleBox:SetText(note.title or "")
    titleBox:SetCursorPosition(0)

    -- 副本／首領筆記的標題就是那個副本／首領的名字，改了只會讓自己對不上，
    -- 所以停用輸入框（停用的 EditBox 連焦點都拿不到，玩家不會誤以為能改）
    local readonly = current.ctx.readonlyTitle == true
    if readonly then titleBox:Disable() else titleBox:Enable() end
    if readonly then
        titleBox:SetTextColor(0.75, 0.75, 0.75)
    else
        titleBox:SetTextColor(1, 1, 1)
    end

    LayoutBars(current.ctx.plainBlocks == true)
    contextLabel:SetText(current.ctx.label or L["Note"])
    contextLabel:SetTextColor(W.Accent(1))

    blockEditor:SetNote(note)
    AnchorToMain()
    frame:Show()
end

function Editor.Close()
    if frame then frame:Hide() end
    current = nil
end

function Editor.IsShown()
    return frame and frame:IsShown()
end

function Editor.GetNote()
    return current and current.note
end

-- 目前正在編輯這一筆嗎（清單重繪時判斷要不要跟著關掉編輯視窗）
function Editor.IsEditing(note)
    return current ~= nil and current.note == note
end

function Editor.Commit()
    if blockEditor then blockEditor:Commit() end
end

function Editor.Refresh()
    if not (frame and frame:IsShown() and current) then return end
    titleBox:SetText(current.note.title or "")
    titleBox:SetCursorPosition(0)
    blockEditor:Refresh()
end

ns.RegisterCallback("SettingsChanged", "editor", function()
    -- 換字型／字級之後每一列的高度都變了，不重排的話會互相疊到
    Editor.Refresh()
end)

function Editor.Reanchor()
    if frame then AnchorToMain() end
end
