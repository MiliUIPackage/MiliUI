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
local blockBar
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
    end)

    -- 工具列：加入區塊
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
        -- 一顆接一顆錨著，撐開會一路往右讓位（整排最寬的語系也還在編輯器寬度內）
        W.FitButton(b, 60, TOOLBAR_H - 4)
        b:SetPoint("LEFT", prev, "RIGHT", 5, 0)
        local blockType = t.type
        b:SetScript("OnClick", function()
            if blockEditor then blockEditor:AddBlock(blockType) end
        end)
        prev = b
    end

    -- 區塊清單
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", blockBar, "BOTTOMLEFT", 0, -6)
    holder:SetPoint("BOTTOMRIGHT", -8, 8)
    local scroll = W.CreateScrollFrame(holder)
    blockEditor = ns.Blocks.CreateEditor(scroll)

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
-- 對外
------------------------------------------------------------
-- ctx = {
--   label           標題列上的來源說明
--   onTitleChanged  標題改了要通知宿主刷新清單
--   share           分享用的中繼資料 { kind }
-- }
function Editor.Open(note, ctx)
    if not note then return end
    Build()
    current = { note = note, ctx = ctx or {} }

    Notes.EnsureBlocks(note)
    titleBox:SetText(note.title or "")
    titleBox:SetCursorPosition(0)

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
