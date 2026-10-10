------------------------------------------------------------
-- 一條自訂提示的編輯視窗（清單與時間軸編輯器共用）
--
--   ┌────────────────────────────────────────────┐
--   │ 新增提示  『纏魂者』尼札利                [×] │
--   │ ┌[圖]纏魂點燃────────────────────────────┐   │  ← 即時預覽：圖示＋文字＋一行摘要
--   │ └開戰 0:03 · 提前 8 秒 · 音效…───────────┘   │    （其他分頁改了什麼，在這裡一眼看完）
--   │ [基本][顯示][音效][對象][跟著首領]           │
--   │ ┌──────────────────────────────────────────┐ │
--   │ │  一個分頁的欄位                           │ │  ← 第一眼只有「基本」：時間、法術、文字
--   │ └──────────────────────────────────────────┘ │
--   │                              [確定] [取消]   │
--   └────────────────────────────────────────────┘
--
-- 卡片高度取所有分頁裡最高的那個：切分頁時視窗不跳、按鈕不跑。
-- 「跟著首領」只有從 MRT 列建立（或原本就有錨點）的提示才有。
--
-- 首領 3D 模型不放這裡：放在「自訂時間軸」頁本身（Tab_Plans），這裡只寫首領名稱。
--
-- 遮罩／層級照共用層輸入彈窗的規則：遮罩 400、視窗 410（戰鬥遮罩 500 之下，不 Raise）。
--
--   EntryEditor.Open(values, onAccept, title, encounterID)
--     values：Plans.SaveEntry 的欄位（t 用數字），外加 anchorName（錨點技能的名稱，顯示用）
--     onAccept(values)：回傳 false＝不合法、視窗不關
--     encounterID：這份時間軸的首領戰 ID（標題旁的首領名稱用；nil 就不顯示）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Plans = ns.Plans

ns.EntryEditor = {}
local EE = ns.EntryEditor

local POP_W   = 480
local PAD     = 14
local HEAD_H  = 30 + 44                  -- 標題列＋預覽塊
local CARD_X  = PAD
local CARD_W  = POP_W - PAD * 2
local IN_PAD  = 12                       -- 卡片內距
local ROW_W   = CARD_W - IN_PAD * 2
local LABEL_W = 88
local CTRL_X  = LABEL_W + 10
local ROW_H   = 28
local FOOT_H  = 22 + 12 + 14             -- 按鈕高＋按鈕到底邊＋卡片到按鈕
local SEP     = "  ·  "

local popup, f, current, tabCard, cardTop
local rows = {}                          -- { frame, tab, measure = fn → 高 }
local curTab = "basic"

------------------------------------------------------------
-- 小零件
------------------------------------------------------------
local function Gray(fs) fs:SetTextColor(0.6, 0.6, 0.6) end

local function Small(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetJustifyH("LEFT")
    Gray(fs)
    fs:SetText(text or "")
    return fs
end

-- 一列：右對齊的標籤＋控件從 CTRL_X 開始。label 為 nil＝整列給控件（從 0 開始）
local function Row(tab, label, h)
    local row = CreateFrame("Frame", nil, popup)
    row:SetSize(ROW_W, h or ROW_H)
    if label then
        local fs = row:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetPoint("RIGHT", row, "LEFT", LABEL_W, 0)
        fs:SetWidth(LABEL_W)
        fs:SetJustifyH("RIGHT")
        fs:SetText(label)
        row.label = fs
    end
    rows[#rows + 1] = { frame = row, tab = tab, measure = function() return h or ROW_H end }
    return row
end

-- 標籤後面的「?」：說明會夾在兩列中間時改成滑過看（標籤往左讓出位置）
local HELP_W = 14
local function HelpMark(row, text)
    row.label:SetPoint("RIGHT", row, "LEFT", LABEL_W - HELP_W - 4, 0)
    local m = CreateFrame("Frame", nil, row, "BackdropTemplate")
    m:SetSize(HELP_W, HELP_W)
    m:SetPoint("RIGHT", row, "LEFT", LABEL_W, 0)
    W.Stylize(m, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 })
    local q = m:CreateFontString(nil, "OVERLAY")
    q:SetFontObject(W.fontSmall)
    q:SetPoint("CENTER")
    q:SetText("?")
    Gray(q)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        q:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function()
        Gray(q)
        GameTooltip:Hide()
    end)
    return m
end

-- 灰字說明列：整列寬、照實際行數長高
local function NoteRow(tab, text, indent)
    local row = CreateFrame("Frame", nil, popup)
    row:SetWidth(ROW_W)
    local fs = Small(row, text)
    fs:SetPoint("TOPLEFT", indent or 0, -2)
    fs:SetWidth(ROW_W - (indent or 0))
    fs:SetSpacing(2)
    rows[#rows + 1] = { frame = row, tab = tab, measure = function()
        local h = math.ceil(fs:GetStringHeight()) + 8
        row:SetHeight(h)
        return h
    end }
    row.text = fs
    return row
end

local function Box(row, w, x)
    local eb = W.CreateEditBox(row, w, 20)
    eb:SetPoint("LEFT", row, "LEFT", x or CTRL_X, 0)
    return eb
end

-- 控件右邊的灰色小字
local function After(row, ctrl, text)
    local fs = Small(row, text)
    fs:SetPoint("LEFT", ctrl, "RIGHT", 8, 0)
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

local WHEN_ITEMS = {
    { text = L["When it appears on the timeline"], value = "show" },
    { text = L["5 seconds before"], value = "soon" },
    { text = L["When it happens"], value = "due" },
}
local function WhenText(v)
    for _, it in ipairs(WHEN_ITEMS) do if it.value == v then return it.text end end
    return ""
end

local ROLE_ORDER = { { "TANK", L["Tank"] }, { "HEALER", L["Healer"] }, { "DAMAGER", L["Damage"] } }
local POSITION_ORDER = { { "melee", L["Melee"] }, { "ranged", L["Ranged"] } }

-- 「玩家」欄：逗號（全形、頓號也收）或空白分隔 → { [名字] = true }；名字去掉「-伺服器」
-- ⚠ 全形逗號／頓號是多位元組，不能放進 [...] 字元集，先當字串換成半形逗號
local function ParsePlayers(text)
    text = tostring(text or ""):gsub("，", ","):gsub("、", ",")
    local out = {}
    for part in text:gmatch("[^,%s]+") do
        local name = Plans.BareName(part)
        if name then out[name] = true end
    end
    return ns.Share.CleanPlayers(out)
end

local function PlayersText(set)
    if not set then return "" end
    local names = {}
    for name in pairs(set) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ", ")
end

------------------------------------------------------------
-- 即時預覽：標題區那一塊跟著欄位變
------------------------------------------------------------
local function SpellName(id)
    if not id or not C_Spell or not C_Spell.GetSpellName then return end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and type(name) == "string" and name ~= "" then return name end
end

local function UpdatePreview()
    if not popup or not current then return end
    local spell = tonumber(f.spell:GetText())
    local text = strtrim(f.text:GetText() or "")
    local icon, shown = Plans.Resolve({
        spell = spell, icon = tonumber(f.icon:GetText()), text = text ~= "" and text or nil,
    })
    f.chipIcon:SetTexture(icon)
    f.chipText:SetText(shown)

    -- 法術 ID 旁邊：認得就寫名字，認不得講一聲
    if spell then
        local name = SpellName(spell)
        f.spellName:SetText(name or ("|cffff6666" .. L["Unknown spell"] .. "|r"))
    else
        f.spellName:SetText("")
    end

    -- 摘要：只列有設定的東西
    local parts = {}
    local t = Plans.ParseTime(f.t:GetText())
    parts[#parts + 1] = L["Pull + %s"]:format(t and Plans.FormatTime(t) or "?")
    local lead = tonumber(f.lead:GetText()) or Plans.DEFAULT_LEAD
    parts[#parts + 1] = L["shows %d s early"]:format(math.max(1, lead))
    local sound = f.sound:GetSelected()
    if sound and sound ~= "" then
        parts[#parts + 1] = L["%s (%s)"]:format(sound, WhenText(f.when:GetSelected() or "due"))
    end
    if f.tts:GetChecked() then
        local said = strtrim(f.ttsText:GetText() or "")
        parts[#parts + 1] = said ~= "" and L["Speak \"%s\""]:format(said) or L["Text to speech"]
    end
    local who = {}
    for _, r in ipairs(ROLE_ORDER) do
        if f.roles[r[1]]:GetChecked() then who[#who + 1] = r[2] end
    end
    local class = f.class:GetSelected()
    if class and class ~= "" then
        who[#who + 1] = (_G.LOCALIZED_CLASS_NAMES_MALE or {})[class] or class
    end
    for _, p in ipairs(POSITION_ORDER) do
        if f.positions[p[1]]:GetChecked() then who[#who + 1] = p[2] end
    end
    local groups = {}
    for g = 1, 8 do
        if f.groups[g]:GetChecked() then groups[#groups + 1] = g end
    end
    if #groups > 0 then who[#who + 1] = L["Group %s"]:format(table.concat(groups, "/")) end
    local players = PlayersText(ParsePlayers(f.players:GetText()))
    if players ~= "" then who[#who + 1] = players end
    if #who > 0 then parts[#parts + 1] = L["Only %s"]:format(table.concat(who, "、")) end
    if current.anchor and f.anchor:GetChecked() then
        parts[#parts + 1] = L["Follows cast #%d"]:format(current.anchor.n)
    end
    f.chipSummary:SetText(table.concat(parts, SEP))
end

------------------------------------------------------------
-- 分頁與版面
------------------------------------------------------------
local TABS = {
    { id = "basic",   label = L["Basics"] },
    { id = "display", label = L["Display"] },
    { id = "sound",   label = L["Sound"] },
    { id = "who",     label = L["Only for"] },
    { id = "anchor",  label = L["Follow the boss"] },
}

-- 一個分頁從卡片上緣往下排，回傳內容高
local function StackTab(tab, place)
    local y = cardTop - IN_PAD
    for _, r in ipairs(rows) do
        if r.tab == tab then
            local h = r.measure()
            if place then
                r.frame:ClearAllPoints()
                r.frame:SetPoint("TOPLEFT", popup, "TOPLEFT", CARD_X + IN_PAD, y)
            end
            r.frame:SetShown(place or false)
            y = y - h
        end
    end
    return cardTop - y + IN_PAD
end

local function Relayout()
    -- 卡片高＝所有看得到的分頁裡最高的那個
    local cardH = 0
    for _, t in ipairs(TABS) do
        if t.id ~= "anchor" or current.anchor then
            cardH = math.max(cardH, StackTab(t.id, false))
        end
    end
    StackTab(curTab, true)
    tabCard:SetCardHeight(cardH)
    popup:SetHeight(math.ceil(-(cardTop - cardH)) + FOOT_H)
end

local function SelectTab(id)
    curTab = id
    tabCard:Select(id)
    Relayout()
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function BuildHeader()
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
    f.boss = Small(popup)
    f.boss:SetPoint("BOTTOMLEFT", f.title, "BOTTOMRIGHT", 10, 1)
    f.boss:SetPoint("RIGHT", popup, "RIGHT", -PAD - 24, 0)
    f.boss:SetWordWrap(false)

    -- 預覽塊：看起來就是時間軸上那一條提示
    local chip = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    chip:SetPoint("TOPLEFT", PAD, -PAD - 30)
    chip:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
    chip:SetHeight(44)
    W.Stylize(chip, W.CARD_FILL, { W.Accent(1) })
    f.chipIcon = chip:CreateTexture(nil, "ARTWORK")
    f.chipIcon:SetSize(32, 32)
    f.chipIcon:SetPoint("LEFT", 6, 0)
    f.chipIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.chipText = chip:CreateFontString(nil, "OVERLAY")
    f.chipText:SetFontObject(W.fontNormal)
    f.chipText:SetPoint("TOPLEFT", f.chipIcon, "TOPRIGHT", 8, -1)
    f.chipText:SetPoint("RIGHT", chip, "RIGHT", -8, 0)
    f.chipText:SetJustifyH("LEFT")
    f.chipText:SetWordWrap(false)
    f.chipSummary = Small(chip)
    f.chipSummary:SetPoint("BOTTOMLEFT", f.chipIcon, "BOTTOMRIGHT", 8, 1)
    f.chipSummary:SetPoint("RIGHT", chip, "RIGHT", -8, 0)
    f.chipSummary:SetWordWrap(false)
end

local function BuildBasic()
    local r = Row("basic", L["Time"])
    f.t = Box(r, 80)
    After(r, f.t, L["1:30 or 90 = 90 seconds after the pull"])

    r = Row("basic", L["Spell ID"])
    f.spell = Box(r, 100)
    f.spellName = After(r, f.spell, "")
    f.spellName:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.spellName:SetWordWrap(false)

    r = Row("basic", L["Text"])
    f.text = Box(r, ROW_W - CTRL_X)

    NoteRow("basic", L["With a spell ID the icon and text fill in by themselves; leave the text empty to use the spell name."], CTRL_X)
end

local function BuildDisplay()
    local r = Row("display", L["On timeline"])
    f.lead = Box(r, 50)
    After(r, f.lead, L["seconds before"])

    r = Row("display", L["Icon ID"])
    f.icon = Box(r, 100)
    After(r, f.icon, L["Optional: replaces the spell icon"])

    NoteRow("display", L["The reminder sits on the timeline from this many seconds before until it happens."], CTRL_X)
end

local function BuildSound()
    local r = Row("sound", L["Sound"])
    f.sound = W.CreateDropdown(r, 220, ns.Media.SoundItems(), UpdatePreview)
    f.sound:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    local test = W.CreateButton(r, L["Try it"], "normal", 60, 20)
    W.FitButton(test, 60, 20)
    test:SetPoint("LEFT", f.sound, "RIGHT", 8, 0)
    test:SetScript("OnClick", function()
        ns.Scheduler.Alert({ sound = f.sound:GetSelected() }, f.chipText:GetText())
    end)

    r = Row("sound", L["When"])
    f.when = W.CreateDropdown(r, 220, WHEN_ITEMS, UpdatePreview)
    f.when:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)

    -- 語音播報：勾選＋要念的字（空白＝念提示文字）＋試聽，同 MiliUI_CooldownManager 的那一列
    r = Row("sound", L["Speak"])
    HelpMark(r, L["Reads the text aloud with the game's text-to-speech. Leave it empty to read the reminder text."])
    f.tts = W.CreateCheckButton(r, nil, UpdatePreview)
    f.tts:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    local listen = W.CreateButton(r, L["Try it"], "normal", 60, 20)
    W.FitButton(listen, 60, 20)
    listen:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.ttsText = W.CreateEditBox(r, 80, 20)
    f.ttsText:SetPoint("LEFT", f.tts, "RIGHT", 6, 0)
    f.ttsText:SetPoint("RIGHT", listen, "LEFT", -6, 0)
    f.ttsText:SetMaxLetters(100)
    -- 打字就當作要念：不必先勾
    f.ttsText:HookScript("OnTextChanged", function(self, userInput)
        if userInput and strtrim(self:GetText() or "") ~= "" then f.tts:SetChecked(true) end
    end)
    listen:SetScript("OnClick", function()
        local txt = strtrim(f.ttsText:GetText() or "")
        ns.Scheduler.Alert({ tts = true }, txt ~= "" and txt or f.chipText:GetText())
    end)
end

local function BuildWho()
    local r = Row("who", L["Role"])
    f.roles = {}
    local x = CTRL_X
    for _, role in ipairs(ROLE_ORDER) do
        local cb = W.CreateCheckButton(r, role[2], UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.roles[role[1]] = cb
        x = x + 30 + math.ceil(cb.label:GetStringWidth())
    end

    r = Row("who", L["Class"])
    f.class = W.CreateDropdown(r, 220, ClassItems(), UpdatePreview)
    f.class:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)

    r = Row("who", L["Position"])
    f.positions = {}
    x = CTRL_X
    for _, p in ipairs(POSITION_ORDER) do
        local cb = W.CreateCheckButton(r, p[2], UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.positions[p[1]] = cb
        x = x + 30 + math.ceil(cb.label:GetStringWidth())
    end

    -- 小隊 1～8：八個小勾選框排一列
    r = Row("who", L["Group"])
    f.groups = {}
    x = CTRL_X
    for g = 1, 8 do
        local cb = W.CreateCheckButton(r, tostring(g), UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.groups[g] = cb
        x = x + 18 + cb.labelGap + math.ceil(cb.label:GetStringWidth()) + 8   -- 八個要塞進 330px
    end

    r = Row("who", L["Players"])
    f.players = Box(r, ROW_W - CTRL_X)

    NoteRow("who", L["Nothing ticked in a row = no limit from that row; different rows must all match. Melee includes tanks. Players: names separated by commas, without the realm."], CTRL_X)
end

local function BuildAnchor()
    local r = Row("anchor")
    f.anchor = W.CreateCheckButton(r, "", UpdatePreview)
    f.anchor:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)

    r = Row("anchor", L["Offset"])
    f.offset = Box(r, 50)
    After(r, f.offset, L["seconds"])

    NoteRow("anchor", L["When this ability is recognized in combat (DBM or MRT), the reminder moves with its real cast. Otherwise the time above is used."], CTRL_X)
end

local function Accept()
    local t = Plans.ParseTime(f.t:GetText())
    if not t or t <= 0 then
        ns.Print(L["Time must look like 1:30 or 90."])
        SelectTab("basic")
        f.t:SetFocus()
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
    local positions, groups = {}, {}
    for key, cb in pairs(f.positions) do
        if cb:GetChecked() then positions[key] = true end
    end
    for g, cb in pairs(f.groups) do
        if cb:GetChecked() then groups[g] = true end
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
        ttsText   = f.tts:GetChecked() and strtrim(f.ttsText:GetText() or "") or nil,
        roles     = roles,
        class     = f.class:GetSelected() or "",
        anchor    = anchor,
        positions = positions,
        groups    = groups,
        players   = ParsePlayers(f.players:GetText()),
        phase     = current.phase,      -- 匯入時記下的階段，編輯視窗不改它，原樣帶回去
    }
    if current.onAccept and current.onAccept(values) == false then return end
    popup:Hide()
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
    BuildHeader()

    tabCard = W.CreateTabCard(popup, {
        tabs = TABS,
        selected = curTab,
        onSelect = SelectTab,
    })
    local stripH = tabCard:Place(CARD_X, -PAD - HEAD_H - 12, CARD_W)
    cardTop = -PAD - HEAD_H - 12 - stripH

    BuildBasic()
    BuildDisplay()
    BuildSound()
    BuildWho()
    BuildAnchor()

    local cancel = W.CreateButton(popup, L["Cancel"], "normal", 80, 22)
    W.FitButton(cancel, 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    local ok = W.CreateButton(popup, L["Okay"], "primary", 80, 22)
    W.FitButton(ok, 80, 22)
    ok:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
    ok:SetScript("OnClick", Accept)

    -- Tab 在同一頁的輸入框之間跳；打字就更新預覽
    local order = { f.t, f.spell, f.text }
    for i, eb in ipairs(order) do
        eb:SetScript("OnTabPressed", function() (order[i + 1] or order[1]):SetFocus() end)
    end
    for _, eb in ipairs({ f.t, f.spell, f.text, f.lead, f.icon, f.offset, f.players, f.ttsText }) do
        eb:SetScript("OnEnterPressed", function() eb:ClearFocus() end)
        eb:HookScript("OnTextChanged", UpdatePreview)   -- Hook：ttsText 先掛了「打字就勾」，SetScript 會蓋掉它
    end
    popup:Hide()
end

------------------------------------------------------------
-- 開啟
------------------------------------------------------------
local function SetBox(eb, v)
    eb:SetText(v ~= nil and tostring(v) or "")
    eb:SetCursorPosition(0)
end

-- 只讀存檔裡的名字：不碰冒險指南（NameFor 第一次會整本掃，會卡）
local function ShowBoss(encounterID)
    local boss = encounterID and Plans.Boss(encounterID)
    f.boss:SetText(boss and boss.name or "")
end

function EE.Open(values, onAccept, title, encounterID)
    if not popup then Build() end
    values = values or {}
    current = { onAccept = onAccept, anchor = values.anchor, phase = values.phase }
    f.title:SetText(title or L["Add reminder"])
    ShowBoss(encounterID)

    SetBox(f.t, values.t and Plans.FormatTime(values.t))
    SetBox(f.lead, values.lead or Plans.DEFAULT_LEAD)
    SetBox(f.spell, values.spell)
    SetBox(f.icon, values.icon)
    SetBox(f.text, values.text)
    f.sound:SetSelectedValue(values.sound or "")
    f.when:SetSelectedValue(values.soundWhen or "due")
    f.tts:SetChecked(values.tts and true or false)
    SetBox(f.ttsText, values.ttsText)
    for role, cb in pairs(f.roles) do cb:SetChecked(values.roles and values.roles[role] and true or false) end
    f.class:SetSelectedValue(values.class or "")
    for key, cb in pairs(f.positions) do cb:SetChecked(values.positions and values.positions[key] and true or false) end
    for g, cb in pairs(f.groups) do cb:SetChecked(values.groups and values.groups[g] and true or false) end
    SetBox(f.players, PlayersText(values.players))

    local a = values.anchor
    local ids = {}
    for _, t in ipairs(TABS) do
        if t.id ~= "anchor" or a then ids[#ids + 1] = t.id end
    end
    tabCard:SetTabs(ids)
    if a then
        local name = values.anchorName or (L["Spell"] .. " #" .. a.spell)
        f.anchor.label:SetText(L["Follow cast #%d of %s"]:format(a.n, name))
        f.anchor:SetChecked(values.anchorOn ~= false)
        SetBox(f.offset, a.offset or 0)
    end

    UpdatePreview()
    SelectTab("basic")
    popup:Show()
    f.t:SetFocus()
end
