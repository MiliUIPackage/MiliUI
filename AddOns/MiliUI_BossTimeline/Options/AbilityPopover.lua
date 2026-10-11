------------------------------------------------------------
-- 一個首領技能的設定小窗（【技能】清單的「設定」鈕打開）
--
--   ┌────────────────────────────────────────────┐
--   │ 技能設定                                [×] │
--   │ [圖] 滴毒尖牙  #754                         │
--   │ 對這隻首領的所有難度都有效。                 │
--   │ 在時間軸上                                   │
--   │   顏色       [■] 沿用暴雪／DBM 的顏色        │
--   │   快到時顏色  [■] 約 5 秒前變成這個顏色       │
--   │   不顯示     [ ]                             │
--   │ 快到時（約 5 秒前）                           │
--   │   音效       [無 ▼][試聽]                    │
--   │   語音念出   [________________][試聽]        │
--   │ 施放時                                       │
--   │   音效       [無 ▼][試聽]                    │
--   │   語音念出   [________________][試聽]        │
--   │   灰字說明                                   │
--   │ [＋ 加一條提示]            [全部清除] [關閉]  │
--   └────────────────────────────────────────────┘
--
-- 為什麼從清單列的一排控件改成小窗：一列塞「顏色／快到／快到時音效／施放時音效／隱藏／＋／×」
-- 七個沒有標籤的控件，玩家看不出哪個勾是什麼（2026-10-11 使用者回報）。清單只留「設了什麼」的摘要，
-- 真正的設定放進有標籤、有說明的小窗。
--
-- 每個控件改了就立刻存（Plans/Abilities.lua 的 A.Set），沒有「確定」：跟原本清單列的行為一樣，
-- 而且顏色選好要馬上看得到時間軸上的變化。
--
-- 遮罩／層級照共用層輸入彈窗的規則：遮罩 400、視窗 410。
--
--   AbilityPopover.Open(info, opts)
--     info：Abilities.Info 的那張表 { id, spell, name, icon }
--     opts.onAddReminder(info)：「＋ 加一條提示」按下去（呼叫端負責切到【我的提示】）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local A = ns.Abilities

ns.AbilityPopover = {}
local AP = ns.AbilityPopover

local POP_W   = 440
local PAD     = 14
local LABEL_W = 88
local CTRL_X  = LABEL_W + 10
local ROW_W   = POP_W - PAD * 2
local ROW_H   = 28
local UNSET   = { r = 0.22, g = 0.22, b = 0.22, a = 1 }

local popup, f, current, cursorY

local function Gray(fs) fs:SetTextColor(0.6, 0.6, 0.6) end

local function Small(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetJustifyH("LEFT")
    Gray(fs)
    fs:SetText(text or "")
    return fs
end

-- 一列：右對齊標籤＋控件從 CTRL_X 起
local function Row(label, h)
    local row = CreateFrame("Frame", nil, popup)
    row:SetSize(ROW_W, h or ROW_H)
    row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, cursorY)
    cursorY = cursorY - (h or ROW_H)
    if label then
        local fs = row:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetPoint("RIGHT", row, "LEFT", LABEL_W, 0)
        fs:SetWidth(LABEL_W)
        fs:SetJustifyH("RIGHT")
        fs:SetText(label)
        row.label = fs
    end
    return row
end

-- 小節標題（accent 小字，底下一條髮絲線）
local function Header(text)
    cursorY = cursorY - 6
    local row = Row(nil, 20)
    local fs = W.CreateGroupLabel(row, text)
    fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(W.Accent(0.35))
    line:SetHeight(ns.P.Scale(1))
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    return row
end

-- 灰字說明列
local function Note(text, indent)
    local row = CreateFrame("Frame", nil, popup)
    row:SetWidth(ROW_W)
    row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, cursorY)
    local fs = Small(row, text)
    fs:SetPoint("TOPLEFT", indent or CTRL_X, -1)
    fs:SetWidth(ROW_W - (indent or CTRL_X))
    fs:SetSpacing(2)
    local h = math.ceil(fs:GetStringHeight()) + 8
    row:SetHeight(h)
    cursorY = cursorY - h
    return row
end

local function After(row, ctrl, text)
    local fs = Small(row, text)
    fs:SetPoint("LEFT", ctrl, "RIGHT", 8, 0)
    fs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    fs:SetWordWrap(false)
    return fs
end

local function Id() return current and current.info and current.info.id end

local function Set(field, value)
    if Id() then A.Set(Id(), field, value) end
end

local function PlayPreview(name)
    local path = ns.Media.Sound(name)
    if path then PlaySoundFile(path, "Master") end
end

local function Speak(text)
    text = strtrim(text or "")
    if text == "" then return end
    if ns.Scheduler and ns.Scheduler.Speak then ns.Scheduler.Speak(text) end
end

------------------------------------------------------------
-- 色塊：沒設的畫斜線（色票的「無」慣例），滑過說明
------------------------------------------------------------
local function MarkUnset(swatch, tip)
    local slash = swatch:CreateTexture(nil, "OVERLAY")
    slash:SetTexture("Interface\\Buttons\\WHITE8X8")
    slash:SetVertexColor(0.85, 0.25, 0.25, 1)
    slash:SetSize(18, ns.P.Scale(1.5))
    slash:SetPoint("CENTER")
    slash:SetRotation(math.rad(45))
    swatch.unset = slash
    swatch:HookScript("OnEnter", function(self)
        if not self.unset:IsShown() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Not set"], 1, 1, 1)
        GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    swatch:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function Build()
    local parent = ns.Options.panel
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    popup = W.CreateFrame("MiliUIBT_AbilityPopover", parent, POP_W, 400)
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        W.CloseDropdowns()
    end)

    f = {}
    local close = W.CreateButton(popup, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() popup:Hide() end)

    f.title = popup:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject(W.fontTitle)
    f.title:SetPoint("TOPLEFT", PAD, -PAD)
    f.title:SetText(L["Ability settings"])

    -- 技能一行：圖示＋名稱＋記錄 ID
    f.icon = popup:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(28, 28)
    f.icon:SetPoint("TOPLEFT", PAD, -PAD - 28)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.name = popup:CreateFontString(nil, "OVERLAY")
    f.name:SetFontObject(W.fontNormal)
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.name:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)

    cursorY = -PAD - 28 - 28 - 6
    Note(L["Applies to every difficulty of this boss."], 0)

    -- 在時間軸上
    Header(L["On the timeline"])
    local r = Row(L["Color"])
    f.color = W.CreateColorPicker(r, "", false, function(cr, cg, cb) Set("color", { r = cr, g = cg, b = cb }) end)
    f.color:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    MarkUnset(f.color, L["Uses Blizzard's color, or DBM's if it set one. Click to pick your own."])
    f.colorNote = After(r, f.color, L["Border and bar color of this ability on the timeline"])

    r = Row(L["Soon color"])
    f.highlight = W.CreateColorPicker(r, "", false, function(cr, cg, cb) Set("highlight", { r = cr, g = cg, b = cb }) end)
    f.highlight:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    MarkUnset(f.highlight, L["Uses Blizzard's color, or DBM's if it set one. Click to pick your own."])
    After(r, f.highlight, L["About 5 seconds before it happens"])

    r = Row(L["Don't show"])
    f.hide = W.CreateCheckButton(r, "", function(checked) Set("hide", checked or nil) end)
    f.hide:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    Note(L["Takes this ability off the timeline. Only works when it is recognized in combat (General → Advanced)."])

    -- 快到時
    local soundItems = ns.Media.SoundItems()
    local function SoundRow(field)
        local row = Row(L["Sound"])
        local dd = W.CreateDropdown(row, 200, soundItems, function(value)
            Set(field, value ~= "" and value or nil)
            PlayPreview(value)
        end)
        dd:SetPoint("LEFT", row, "LEFT", CTRL_X, 0)
        local try = W.CreateButton(row, L["Try it"], "normal", 60, 20)
        W.FitButton(try, 60, 20)
        try:SetPoint("LEFT", dd, "RIGHT", 6, 0)
        try:SetScript("OnClick", function() PlayPreview(dd:GetSelected()) end)
        return dd
    end
    local function SpeakRow(field)
        local row = Row(L["Speak"])
        local try = W.CreateButton(row, L["Try it"], "normal", 60, 20)
        W.FitButton(try, 60, 20)
        try:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local eb = W.CreateEditBox(row, 100, 20)
        eb:SetPoint("LEFT", row, "LEFT", CTRL_X, 0)
        eb:SetPoint("RIGHT", try, "LEFT", -6, 0)
        eb:SetMaxLetters(100)
        -- 失焦或按 Enter 才存（每敲一個字就 A.Set 會一直發 AbilitiesChanged 重畫清單）
        local function Commit()
            local t = strtrim(eb:GetText() or "")
            Set(field, t ~= "" and t or nil)
        end
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:HookScript("OnEditFocusLost", Commit)
        try:SetScript("OnClick", function()
            Commit()
            Speak(eb:GetText())
        end)
        return eb
    end

    Header(L["About 5 seconds before"])
    f.sndHl = SoundRow("soundHighlight")
    f.ttsSoon = SpeakRow("ttsSoon")

    Header(L["When it is cast"])
    f.sndCast = SoundRow("soundCast")
    f.ttsCast = SpeakRow("ttsCast")

    Note(L["Colors and sounds go through Blizzard's boss ability settings, so Blizzard's timeline and DBM see them too. Speech needs the ability to be recognized in combat (DBM or the MRT timeline)."], 0)

    -- 底排：＋ 加一條提示（主動作）、全部清除、關閉
    cursorY = cursorY - 8
    local add = W.CreateButton(popup, L["+ Add a reminder"], "primary", 110, 22)
    W.FitButton(add, 110, 22)
    add:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, cursorY)
    add:SetScript("OnClick", function()
        local info, onAdd = current and current.info, current and current.onAddReminder
        popup:Hide()
        if info and onAdd then onAdd(info) end
    end)
    f.add = add
    add:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Add a reminder for this ability"], 1, 1, 1)
        GameTooltip:AddLine(L["A reminder that follows this ability: your own words, a sound, speech or a boss warning. Switches to My reminders."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    add:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local closeBtn = W.CreateButton(popup, L["Close"], "normal", 70, 22)
    W.FitButton(closeBtn, 70, 22)
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, cursorY)
    closeBtn:SetScript("OnClick", function() popup:Hide() end)

    local clear = W.CreateButton(popup, L["Clear all"], "red", 70, 22)
    W.FitButton(clear, 70, 22)
    clear:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    clear:SetScript("OnClick", function()
        if Id() then A.Clear(Id()) end
        AP.Refresh()
    end)
    f.clear = clear
    clear:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Back to Blizzard's color and sound (or DBM's)."], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clear:HookScript("OnLeave", function() GameTooltip:Hide() end)

    popup:SetHeight(-cursorY + 22 + PAD)
    popup:Hide()
end

------------------------------------------------------------
-- 填值
------------------------------------------------------------
function AP.Refresh()
    if not popup or not popup:IsShown() or not current then return end
    local info = current.info
    local cfg = A.Get(info.id) or {}
    f.icon:SetTexture(info.icon or 134400)
    f.name:SetText((info.name or (L["Spell"] .. " #" .. tostring(info.spell))) .. "  |cff6f6f6f#" .. info.id .. "|r")
    f.color:SetColor(cfg.color or UNSET)
    f.highlight:SetColor(cfg.highlight or UNSET)
    f.color.unset:SetShown(cfg.color == nil)
    f.highlight.unset:SetShown(cfg.highlight == nil)
    f.hide:SetChecked(cfg.hide and true or false)
    f.sndHl:SetSelectedValue(cfg.soundHighlight or "")
    f.sndCast:SetSelectedValue(cfg.soundCast or "")
    if not f.ttsSoon:HasFocus() then f.ttsSoon:SetText(cfg.ttsSoon or "") end
    if not f.ttsCast:HasFocus() then f.ttsCast:SetText(cfg.ttsCast or "") end
    local sum = A.Summary(cfg)
    f.clear:SetEnabled(sum ~= nil and (sum.color or sum.sound or sum.tts or sum.hide))
    f.add:SetShown(info.spell ~= nil and current.onAddReminder ~= nil)
end

function AP.Open(info, opts)
    if not info then return end
    if not popup then Build() end
    current = { info = info, onAddReminder = opts and opts.onAddReminder }
    popup:Show()
    AP.Refresh()
end

ns.RegisterCallback("AbilitiesChanged", "abilityPopover", AP.Refresh)
