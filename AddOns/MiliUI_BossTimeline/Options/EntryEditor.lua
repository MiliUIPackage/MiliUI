------------------------------------------------------------
-- 一條自訂提示的編輯視窗（清單與時間軸編輯器共用）
--
-- 共用層的輸入彈窗只有單行文字欄位，這裡要下拉（音效、時機、職業）與勾選（朗讀、職責、錨點），
-- 所以照它的遮罩／層級規則自己組：遮罩 400、視窗 410（戰鬥遮罩 500 之下，不 Raise）。
--
--   EntryEditor.Open(values, onAccept, title)
--     values：Plans.SaveEntry 的欄位（t 用數字），外加 anchorName（錨點技能的名稱，顯示用）
--     onAccept(values)：回傳 false＝不合法、視窗不關
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Plans = ns.Plans

ns.EntryEditor = {}
local EE = ns.EntryEditor

local POP_W = 470
local BTN_GAP, BTN_H, BTN_PAD = 16, 22, 12   -- 最後一段內容 → 按鈕的間距、按鈕高、按鈕到底邊
local popup, f, current

local function Label(parent, text, x, y, small)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(small and W.fontSmall or W.fontNormal)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function Box(parent, w, x, y)
    local eb = W.CreateEditBox(parent, w, 20)
    eb:SetPoint("TOPLEFT", x, y)
    return eb
end

local function Header(parent, text, y)
    local fs = W.CreateGroupLabel(parent, text)
    fs:SetPoint("TOPLEFT", 14, y)
    return fs
end

local function ClassItems()
    local items = { { text = L["All classes"], value = "" } }
    local order = _G.CLASS_SORT_ORDER or {}
    local names = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    for _, token in ipairs(order) do
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        local name = names[token] or token
        if c and c.colorStr then name = "|c" .. c.colorStr .. name .. "|r" end
        items[#items + 1] = { text = name, value = token }
    end
    return items
end

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

    popup = W.CreateFrame("MiliUIBT_EntryEditor", parent, POP_W, 400)
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
    f.title = popup:CreateFontString(nil, "OVERLAY")
    f.title:SetFontObject(W.fontTitle)
    f.title:SetPoint("TOP", 0, -12)

    -- 內容
    Label(popup, L["Time"], 14, -44)
    f.t = Box(popup, 80, 70, -42)
    Label(popup, L["On timeline"], 170, -44)
    f.lead = Box(popup, 50, 230, -42)
    Label(popup, L["seconds before"], 286, -44, true)

    Label(popup, L["Spell ID"], 14, -74)
    f.spell = Box(popup, 100, 70, -72)
    Label(popup, L["Icon ID"], 190, -74)
    f.icon = Box(popup, 100, 250, -72)

    Label(popup, L["Text"], 14, -104)
    f.text = Box(popup, POP_W - 84, 70, -102)

    local hint = Label(popup, L["With a spell ID the icon and text fill in by themselves. 1:30 or 90 both mean 90 seconds after the pull."], 14, -128, true)
    hint:SetWidth(POP_W - 28)
    hint:SetJustifyH("LEFT")

    Header(popup, L["Alert"], -154)
    Label(popup, L["Sound"], 14, -176)
    f.sound = W.CreateDropdown(popup, 170, ns.Media.SoundItems(), function() end)
    f.sound:SetPoint("TOPLEFT", 70, -174)
    Label(popup, L["When"], 252, -176)
    f.when = W.CreateDropdown(popup, 150, {
        { text = L["When it appears on the timeline"], value = "show" },
        { text = L["5 seconds before"], value = "soon" },
        { text = L["When it happens"], value = "due" },
    }, function() end)
    f.when:SetPoint("TOPLEFT", 296, -174)

    f.tts = W.CreateCheckButton(popup, L["Read the text aloud (text to speech)"])
    f.tts:SetPoint("TOPLEFT", 14, -204)
    local test = W.CreateButton(popup, L["Try it"], "normal", 70, 20)
    W.FitButton(test, 70, 20)
    test:SetPoint("TOPRIGHT", -14, -202)
    test:SetScript("OnClick", function()
        local entry = { sound = f.sound:GetSelected(), tts = f.tts:GetChecked() }
        local text = strtrim(f.text:GetText() or "")
        if text == "" then text = select(2, Plans.Resolve({ spell = tonumber(f.spell:GetText()) })) end
        ns.Scheduler.Alert(entry, text)
    end)

    Header(popup, L["Only for"], -234)
    f.roles = {}
    local x = 14
    for _, r in ipairs({ { "TANK", L["Tank"] }, { "HEALER", L["Healer"] }, { "DAMAGER", L["Damage"] } }) do
        local cb = W.CreateCheckButton(popup, r[2])
        cb:SetPoint("TOPLEFT", x, -254)
        f.roles[r[1]] = cb
        x = x + 30 + math.ceil(cb.label:GetStringWidth())
    end
    Label(popup, L["Class"], 252, -256)
    f.class = W.CreateDropdown(popup, 150, ClassItems(), function() end)
    f.class:SetPoint("TOPLEFT", 296, -254)
    f.roleHint = Label(popup, L["No role ticked = everyone."], 14, -278, true)
    f.roleHint:SetWidth(POP_W - 28)

    -- 錨點：只有從 MRT 列建立（或原本就有錨點）的提示才顯示
    f.anchorHeader = Header(popup, L["Follow the boss"], -302)
    f.anchor = W.CreateCheckButton(popup, "")
    f.anchor:SetPoint("TOPLEFT", 14, -322)
    f.offsetLabel = Label(popup, L["Offset"], 300, -324)
    f.offset = Box(popup, 50, 340, -322)
    f.anchorHint = Label(popup, L["When this ability is recognized in combat (DBM or MRT), the reminder moves with its real cast. Otherwise the time above is used."], 14, -346, true)
    f.anchorHint:SetWidth(POP_W - 28)
    f.anchorHint:SetJustifyH("LEFT")

    local ok = W.CreateButton(popup, L["Okay"], "green", 80, 22)
    ok:SetPoint("BOTTOMLEFT", 26, 12)
    local cancel = W.CreateButton(popup, L["Cancel"], "red", 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", -26, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    ok:SetScript("OnClick", function()
        local t = Plans.ParseTime(f.t:GetText())
        if not t or t <= 0 then
            ns.Print(L["Time must look like 1:30 or 90."])
            return
        end
        local lead = tonumber(f.lead:GetText())
        local roles = {}
        for role, cb in pairs(f.roles) do
            if cb:GetChecked() then roles[role] = true end
        end
        local anchor
        if current.anchor and f.anchor:GetChecked() then
            anchor = {
                spell  = current.anchor.spell,
                n      = current.anchor.n,
                offset = tonumber(f.offset:GetText()) or 0,
            }
        end
        local values = {
            t         = t,
            lead      = lead and math.max(1, lead) or nil,
            spell     = tonumber(f.spell:GetText()),
            icon      = tonumber(f.icon:GetText()),
            text      = strtrim(f.text:GetText() or ""),
            sound     = f.sound:GetSelected() or "",
            soundWhen = f.when:GetSelected() or "due",
            tts       = f.tts:GetChecked() and true or nil,
            roles     = roles,
            class     = f.class:GetSelected() or "",
            anchor    = anchor,
        }
        if current.onAccept and current.onAccept(values) == false then return end
        popup:Hide()
    end)

    -- Tab／Enter 在輸入框之間跳
    local order = { f.t, f.lead, f.spell, f.icon, f.text }
    for i, eb in ipairs(order) do
        eb:SetScript("OnTabPressed", function() (order[i + 1] or order[1]):SetFocus() end)
        eb:SetScript("OnEnterPressed", function() eb:ClearFocus() end)
    end
    popup:Hide()
end

local function SetBox(eb, v)
    eb:SetText(v ~= nil and tostring(v) or "")
    eb:SetCursorPosition(0)
end

function EE.Open(values, onAccept, title)
    if not popup then Build() end
    values = values or {}
    current = { onAccept = onAccept, anchor = values.anchor }
    f.title:SetText(title or L["Add reminder"])
    SetBox(f.t, values.t and Plans.FormatTime(values.t))
    SetBox(f.lead, values.lead or Plans.DEFAULT_LEAD)
    SetBox(f.spell, values.spell)
    SetBox(f.icon, values.icon)
    SetBox(f.text, values.text)
    f.sound:SetSelectedValue(values.sound or "")
    f.when:SetSelectedValue(values.soundWhen or "due")
    f.tts:SetChecked(values.tts and true or false)
    for role, cb in pairs(f.roles) do cb:SetChecked(values.roles and values.roles[role] and true or false) end
    f.class:SetSelectedValue(values.class or "")

    local a = values.anchor
    local showAnchor = a ~= nil
    for _, w in ipairs({ f.anchorHeader, f.anchor, f.offsetLabel, f.offset, f.anchorHint }) do w:SetShown(showAnchor) end
    if a then
        local name = values.anchorName or (L["Spell"] .. " #" .. a.spell)
        f.anchor.label:SetText(L["Follow cast #%d of %s"]:format(a.n, name))
        f.anchor:SetChecked(values.anchorOn ~= false)
        SetBox(f.offset, a.offset or 0)
    end
    -- 高度照最後一段說明的實際行數算：說明會依語系換行，寫死高度會壓到按鈕
    local last = showAnchor and f.anchorHint or f.roleHint
    local _, _, _, _, y = last:GetPoint(1)
    popup:SetHeight(math.ceil(-y + last:GetStringHeight()) + BTN_GAP + BTN_H + BTN_PAD)
    popup:Show()
    f.t:SetFocus()
end
