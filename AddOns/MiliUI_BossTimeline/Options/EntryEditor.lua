------------------------------------------------------------
-- 一條自訂提示的編輯視窗（清單與時間軸編輯器共用）
--
--   ┌──────────────────────────────────────────────────┐
--   │ 新增提示  『纏魂者』尼札利                      [×] │
--   │ ┌[圖]纏魂點燃──────────────────────────────────┐   │  ← 即時摘要：改了什麼一眼看完
--   │ └開戰 0:13 · 提前 8 秒上軸 · 中等警告 · 念「躲」┘   │
--   │ 何時                                               │
--   │   (●) 開戰後 [0:13]                                 │
--   │   ( ) 跟著技能 [法術 ID] 名稱  第 [1] 次／每一次 …   │
--   │   ( ) 第 [2 ▼] 階段開始後 [10] 秒                    │
--   │ 內容                                               │
--   │   文字 [______________________]                      │
--   │   圖示 [法術 ID] 名稱                                │
--   │ 怎麼提醒                                           │
--   │   時機     [到點時 ▼]                                │
--   │   時間軸   [✓] 提前 [8] 秒出現                        │
--   │   首領警告 [✓] [輕微][中等][重大] 顯示 [3] 秒 [試看]   │
--   │   音效     [無 ▼][試聽]                               │
--   │   語音     [✓][要念的字__________][試聽]              │
--   │ 只給誰                      所有人      [挑選對象]   │
--   │   （展開後）職責／職業／位置／小隊／玩家               │
--   │                                     [確定] [取消]   │
--   └──────────────────────────────────────────────────┘
--
-- 2026-10-11 從五個分頁改成一頁三段：玩家要回答的只有三個問題 ——「什麼時候」「提醒什麼」「怎麼提醒」，
-- 分頁把同一個決定拆到不同頁（時間在「基本」、跟隨在「跟著首領」、提前秒數在「顯示」），看不出彼此的關係。
-- 「只給誰」多數人用不到，收起來一列，要用再展開。
--
-- 「何時」三選一（current.when）：
--   time   開戰後第幾秒
--   spell  跟著首領技能：第 n 次（戰鬥中認出時跟著漂，認不出照備援秒數）或每一次（不用秒數）
--   phase  第 n 階段開始後幾秒：階段起點來自 MRT 統計，存檔時換成絕對秒數（Scheduler 只讀 t），
--          另記 phase／phaseOffset 讓視窗再開時還是階段模式。換階段每場會漂，畫面上要講
--
-- 「怎麼提醒」：時間軸（noTimeline＝不放）、首領警告（warn＝嚴重度 0/1/2、warnDur 秒）、音效、語音；
-- 「時機」（soundWhen）是音效／語音／警告共用的一刻。
--
-- 遮罩／層級照共用層輸入彈窗的規則：遮罩 400、視窗 410（戰鬥遮罩 500 之下，不 Raise）。
--
--   EntryEditor.Open(values, onAccept, title, encounterID, ctx)
--     values：Plans.SaveEntry 的欄位（t 用數字；「每一次」的沒有 t），外加 anchorName（錨點技能的名稱，顯示用）
--     onAccept(values)：回傳 false＝不合法、視窗不關
--     encounterID：這份時間軸的首領戰 ID（標題旁的首領名稱、MRT 的階段與施放時間用；nil 就不顯示）
--     ctx.mrtVariant：MRT 用哪一份統計（階段起點、第 n 次施放的秒數）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Plans = ns.Plans
local MD = ns.MRTData

ns.EntryEditor = {}
local EE = ns.EntryEditor

local POP_W   = 520
local PAD     = 14
local LABEL_W = 88
local CTRL_X  = LABEL_W + 10
local ROW_W   = POP_W - PAD * 2
local ROW_H   = 28
local FOOT_H  = 22 + 12 + 10             -- 按鈕高＋按鈕到底邊＋內容到按鈕
local SEP     = "  ·  "
local SOON    = 5

local popup, f, current
local rows = {}                          -- 依序排下來的列：{ frame, group, measure }
local cursorY

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

-- 一列：右對齊的標籤＋控件從 CTRL_X 開始。group 用來整段顯示／隱藏（「只給誰」收起來）
local function Row(label, h, group)
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
    rows[#rows + 1] = { frame = row, group = group, measure = function() return h or ROW_H end }
    return row
end

-- 小節標題：accent 小字＋髮絲線（有標題的小節前面不放隔線）
local function Header(text, group)
    local row = Row(nil, 24, group)
    local fs = W.CreateGroupLabel(row, text)
    fs:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(W.Accent(0.35))
    line:SetHeight(ns.P.Scale(1))
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.title = fs
    return row
end

-- 標籤後面的「?」：說明會夾在兩列中間時改成滑過看
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
local function NoteRow(text, group, indent)
    local row = CreateFrame("Frame", nil, popup)
    row:SetWidth(ROW_W)
    local fs = Small(row, text)
    fs:SetPoint("TOPLEFT", indent or CTRL_X, -2)
    fs:SetWidth(ROW_W - (indent or CTRL_X))
    fs:SetSpacing(2)
    rows[#rows + 1] = { frame = row, group = group, measure = function()
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
local function After(row, ctrl, text, gap)
    local fs = Small(row, text)
    fs:SetPoint("LEFT", ctrl, "RIGHT", gap or 8, 0)
    return fs
end

-- 單選：勾選框當 radio（點已選的那個不會取消；共用層的 onChange 只給 checked，自己抓框）
local function Radio(row, label, x, onPick)
    local cb
    cb = W.CreateCheckButton(row, label, function(checked)
        if not checked then cb:SetChecked(true) return end
        onPick()
    end)
    cb:SetPoint("LEFT", row, "LEFT", x, 0)
    return cb
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
    { text = L["When it happens"], value = "due" },
    { text = L["5 seconds before"], value = "soon" },
    { text = L["When it appears on the timeline"], value = "show" },
}
local function WhenText(v)
    for _, it in ipairs(WHEN_ITEMS) do if it.value == v then return it.text end end
    return ""
end

local SEVERITY = { { 0, L["Minor"] }, { 1, L["Medium"] }, { 2, L["Critical"] } }
local function SeverityText(v)
    for _, s in ipairs(SEVERITY) do if s[1] == v then return s[2] end end
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
-- MRT 資料：階段起點、第 n 次施放的秒數
------------------------------------------------------------
local function Variant()
    if not current or not current.enc or not MD.Has(current.enc) then return end
    local v = current.mrtVariant
    if v and MD.Variants(current.enc)[v] then return v end
    return MD.DefaultVariant(current.enc)
end

local function PhaseList()
    local v = Variant()
    return v and MD.Phases(current.enc, v) or {}
end

local function PhaseStart(n)
    for _, ph in ipairs(PhaseList()) do
        if ph.phase == n then return ph.t end
    end
end

-- 這個技能第 n 次施放的秒數（MRT 統計）；沒有就 nil
local function NthCast(spell, n)
    local v = Variant()
    if not v or not spell then return end
    local k = 0
    for _, ev in ipairs(MD.Events(current.enc, v)) do
        if ev.spell == spell then
            k = k + 1
            if k == n then return ev.t end
        end
    end
end

local function SpellName(id)
    if not id or not C_Spell or not C_Spell.GetSpellName then return end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and type(name) == "string" and name ~= "" then return name end
end

------------------------------------------------------------
-- 「何時」的狀態
------------------------------------------------------------
local function AnchorSpell()
    return tonumber(f.anchorSpell:GetText()) or tonumber(f.spell:GetText())
end

local function AnchorName(spell)
    if not spell then return end
    if current.anchor and current.anchor.spell == spell and current.anchorName then return current.anchorName end
    return SpellName(spell)
end

local function IsEveryMode()
    return current.when == "spell" and current.mode == "every"
end

-- 跟著技能、第 n 次：備援秒數。玩家沒自己填過就照 MRT「第 n 次＋偏移」自動帶
local function AutoFallback()
    if current.when ~= "spell" or current.mode ~= "n" or current.tTouched then return end
    local t = NthCast(AnchorSpell(), math.max(1, math.floor(tonumber(f.anchorN:GetText()) or 1)))
    if t then
        t = t + (tonumber(f.offset:GetText()) or 0)
        if t > 0 then
            f.fallback:SetText(Plans.FormatTime(t))
            f.fallback:SetCursorPosition(0)
        end
    end
end

-- 階段模式的秒數：階段起點＋偏移
local function PhaseTime()
    local n = f.phase:GetSelected()
    local start = n and PhaseStart(n)
    if not start then return end
    return start + (tonumber(f.phaseOffset:GetText()) or 0)
end

-- 三種模式各自的控件變暗停用
local function SyncWhen()
    local when = current.when
    f.whenTime:SetChecked(when == "time")
    f.whenSpell:SetChecked(when == "spell")
    f.whenPhase:SetChecked(when == "phase")
    local function Dim(list, on)
        for _, w in ipairs(list) do
            w:SetEnabled(on)
            w:SetAlpha(on and 1 or 0.5)
        end
    end
    Dim({ f.t }, when == "time")
    Dim({ f.anchorSpell, f.modeN, f.modeEvery, f.offset }, when == "spell")
    Dim({ f.anchorN, f.fallback }, when == "spell" and current.mode == "n")
    f.modeN:SetChecked(current.mode == "n")
    f.modeEvery:SetChecked(current.mode == "every")
    local hasPhases = #PhaseList() > 0
    Dim({ f.phase, f.phaseOffset }, when == "phase" and hasPhases)
    f.whenPhase:SetEnabled(hasPhases)
    f.whenPhase.label:SetTextColor(hasPhases and 1 or 0.5, hasPhases and 1 or 0.5, hasPhases and 1 or 0.5)

    -- 跟著技能：法術欄留白＝用「內容」的法術 ID，旁邊寫出是哪一個
    local own = tonumber(f.anchorSpell:GetText())
    local spell = AnchorSpell()
    if spell then
        local name = AnchorName(spell) or ("|cffff6666" .. L["Unknown spell"] .. "|r")
        f.anchorName:SetText(own and name or L["%s (from Content)"]:format(name))
    else
        f.anchorName:SetText(L["Uses the spell ID under Content"])
    end

    -- 階段：換算出來的秒數寫在旁邊
    if when == "phase" then
        local t = PhaseTime()
        f.phaseHint:SetText(t and L["About %s after the pull (MRT average; drifts from pull to pull)"]:format(Plans.FormatTime(math.max(0, t)))
            or (hasPhases and "" or L["MRT has no phase times for this boss."]))
    else
        f.phaseHint:SetText(hasPhases and "" or L["MRT has no phase times for this boss."])
    end
end

------------------------------------------------------------
-- 「怎麼提醒」的狀態
------------------------------------------------------------
local function SyncHow()
    local onTL = f.onTimeline:GetChecked()
    f.lead:SetEnabled(onTL)
    f.lead:SetAlpha(onTL and 1 or 0.5)
    local warn = f.warn:GetChecked()
    for _, b in ipairs(f.sevButtons) do
        b:SetEnabled(warn)
        b:SetAlpha(warn and 1 or 0.5)
    end
    f.warnDur:SetEnabled(warn)
    f.warnDur:SetAlpha(warn and 1 or 0.5)
    f.warnTry:SetEnabled(warn)
    -- 「時機」只有在有音效／語音／警告時才有意義
    local any = warn or f.tts:GetChecked() or ((f.sound:GetSelected() or "") ~= "")
    f.when:SetAlpha(any and 1 or 0.5)
end

------------------------------------------------------------
-- 「只給誰」：收起來一列（摘要＋展開鈕），展開才看得到勾選
------------------------------------------------------------
local function WhoSummary()
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
    return who
end

local Relayout

local function SetWhoOpen(open)
    current.whoOpen = open
    f.whoToggle:SetText(open and L["Done picking"] or L["Pick people"])
    Relayout()
end

------------------------------------------------------------
-- 即時摘要：標題區那一塊跟著欄位變
------------------------------------------------------------
local function UpdatePreview()
    if not popup or not current then return end
    SyncWhen()
    SyncHow()
    local spell = tonumber(f.spell:GetText())
    local text = strtrim(f.text:GetText() or "")
    local icon, shown = Plans.Resolve({ spell = spell, text = text ~= "" and text or nil })
    f.chipIcon:SetTexture(icon)
    f.chipText:SetText(shown)

    -- 法術 ID 旁邊：認得就寫名字，認不得講一聲
    if spell then
        local name = SpellName(spell)
        f.spellName:SetText(name or ("|cffff6666" .. L["Unknown spell"] .. "|r"))
    else
        f.spellName:SetText("")
    end

    local parts = {}
    if current.when == "spell" then
        local a = AnchorSpell()
        local name = AnchorName(a) or (a and ("#" .. a)) or "?"
        local off = tonumber(f.offset:GetText()) or 0
        local offText = off ~= 0 and (" %+gs"):format(off) or ""
        if current.mode == "every" then
            parts[#parts + 1] = L["Every cast of %s"]:format(name) .. offText
        else
            parts[#parts + 1] = L["Cast #%d of %s"]:format(math.max(1, math.floor(tonumber(f.anchorN:GetText()) or 1)), name) .. offText
        end
    elseif current.when == "phase" then
        local n = f.phase:GetSelected()
        parts[#parts + 1] = L["Phase %s + %gs"]:format(tostring(n or "?"), tonumber(f.phaseOffset:GetText()) or 0)
    else
        local t = Plans.ParseTime(f.t:GetText())
        parts[#parts + 1] = L["Pull + %s"]:format(t and Plans.FormatTime(t) or "?")
    end
    if f.onTimeline:GetChecked() then
        parts[#parts + 1] = L["on the timeline %d s early"]:format(math.max(1, tonumber(f.lead:GetText()) or Plans.DEFAULT_LEAD))
    end
    local alerts = {}
    if f.warn:GetChecked() then alerts[#alerts + 1] = L["%s warning"]:format(SeverityText(current.severity)) end
    local sound = f.sound:GetSelected()
    if sound and sound ~= "" then alerts[#alerts + 1] = sound end
    if f.tts:GetChecked() then
        local said = strtrim(f.ttsText:GetText() or "")
        alerts[#alerts + 1] = said ~= "" and L["say \"%s\""]:format(said) or L["speak it"]
    end
    if #alerts > 0 then
        parts[#parts + 1] = table.concat(alerts, "+") .. " (" .. WhenText(f.when:GetSelected() or "due") .. ")"
    end
    local who = WhoSummary()
    if #who > 0 then parts[#parts + 1] = L["Only %s"]:format(table.concat(who, "、")) end
    f.chipSummary:SetText(table.concat(parts, SEP))
    f.whoText:SetText(#who > 0 and table.concat(who, "、") or L["Everyone"])
end

------------------------------------------------------------
-- 版面：列照順序疊；「只給誰」那一段收起來時不算高
------------------------------------------------------------
Relayout = function()
    local y = cursorY
    for _, r in ipairs(rows) do
        local show = r.group ~= "who" or current.whoOpen
        r.frame:SetShown(show)
        if show then
            local h = r.measure()
            r.frame:ClearAllPoints()
            r.frame:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, y)
            y = y - h
        end
    end
    popup:SetHeight(-y + FOOT_H)
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

    -- 摘要塊：看起來就是時間軸上那一條提示
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
    cursorY = -PAD - 30 - 44 - 4
end

local function SetWhen(mode)
    current.when = mode
    UpdatePreview()
end

local function SetMode(mode)
    current.mode = mode
    if mode == "n" then AutoFallback() end
    UpdatePreview()
end

local function BuildWhen()
    Header(L["When?"])

    -- 開戰後
    local r = Row()
    f.whenTime = Radio(r, L["After the pull"], 0, function() SetWhen("time") end)
    f.t = Box(r, 70, CTRL_X + 30)
    f.tHint = After(r, f.t, L["1:30 or 90 = 90 seconds after the pull"])

    -- 跟著技能
    r = Row()
    f.whenSpell = Radio(r, L["Following an ability"], 0, function() SetWhen("spell") end)
    f.anchorSpell = Box(r, 80, CTRL_X + 30)
    f.anchorName = After(r, f.anchorSpell, "")
    f.anchorName:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.anchorName:SetWordWrap(false)

    r = Row()
    f.modeN = W.CreateCheckButton(r, L["Cast #"], function(checked)
        if not checked then f.modeN:SetChecked(true) return end
        SetMode("n")
    end)
    f.modeN:SetPoint("LEFT", r, "LEFT", CTRL_X + 30, 0)
    f.anchorN = Box(r, 36, CTRL_X + 30 + 24 + math.ceil(f.modeN.label:GetStringWidth()) + 4)
    f.modeEvery = W.CreateCheckButton(r, L["Every cast"], function(checked)
        if not checked then f.modeEvery:SetChecked(true) return end
        SetMode("every")
    end)
    f.modeEvery:SetPoint("LEFT", f.anchorN, "RIGHT", 14, 0)
    local offLbl = Small(r, L["Offset"])
    offLbl:SetPoint("LEFT", f.modeEvery.label, "RIGHT", 18, 0)
    f.offset = W.CreateEditBox(r, 44, 20)
    f.offset:SetPoint("LEFT", offLbl, "RIGHT", 6, 0)
    After(r, f.offset, L["s (negative = earlier)"], 4)

    r = Row()
    local fbLbl = Small(r, L["If not recognized"])
    fbLbl:SetPoint("LEFT", r, "LEFT", CTRL_X + 30, 0)
    f.fallback = W.CreateEditBox(r, 70, 20)
    f.fallback:SetPoint("LEFT", fbLbl, "RIGHT", 6, 0)
    f.fallback:HookScript("OnTextChanged", function(_, userInput)
        if userInput then current.tTouched = true end
    end)
    After(r, f.fallback, L["Backup time; filled in from MRT when it has this cast"])

    -- 階段
    r = Row()
    f.whenPhase = Radio(r, L["Phase"], 0, function() SetWhen("phase") end)
    f.phase = W.CreateDropdown(r, 150, {}, UpdatePreview)
    f.phase:SetPoint("LEFT", r, "LEFT", CTRL_X + 30, 0)
    local plusLbl = Small(r, L["start +"])
    plusLbl:SetPoint("LEFT", f.phase, "RIGHT", 8, 0)
    f.phaseOffset = W.CreateEditBox(r, 44, 20)
    f.phaseOffset:SetPoint("LEFT", plusLbl, "RIGHT", 6, 0)
    After(r, f.phaseOffset, L["s"], 4)
    f.phaseHint = NoteRow("", nil, CTRL_X + 30).text
end

local function BuildContent()
    Header(L["Content"])
    local r = Row(L["Text"])
    f.text = Box(r, ROW_W - CTRL_X)

    r = Row(L["Spell ID"])
    HelpMark(r, L["Optional. The icon and, when the text is empty, the name come from this spell. Following an ability fills it in for you."])
    f.spell = Box(r, 80)
    f.spellName = After(r, f.spell, "")
    f.spellName:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.spellName:SetWordWrap(false)
end

local function BuildHow()
    Header(L["How to remind"])

    local r = Row(L["Timing"])
    HelpMark(r, L["The moment the sound, speech and boss warning fire. The timeline entry always appears early (below)."])
    f.when = W.CreateDropdown(r, 200, WHEN_ITEMS, UpdatePreview)
    f.when:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)

    r = Row(L["Timeline"])
    f.onTimeline = W.CreateCheckButton(r, L["Show on the timeline"], UpdatePreview)
    f.onTimeline:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    local leadLbl = Small(r, L["appearing"])
    leadLbl:SetPoint("LEFT", f.onTimeline.label, "RIGHT", 14, 0)
    f.lead = W.CreateEditBox(r, 40, 20)
    f.lead:SetPoint("LEFT", leadLbl, "RIGHT", 6, 0)
    After(r, f.lead, L["s before it happens"], 4)

    r = Row(L["Boss warning"])
    f.warn = W.CreateCheckButton(r, "", UpdatePreview)
    f.warn:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    f.sevButtons = {}
    local prev
    for _, s in ipairs(SEVERITY) do
        local b = W.CreateButton(r, s[2], "accent-hover", 44, 20)
        W.FitButton(b, 44, 20)
        b.id = s[1]
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("LEFT", f.warn, "RIGHT", 6, 0) end
        f.sevButtons[#f.sevButtons + 1] = b
        prev = b
    end
    f.highlightSeverity = W.CreateButtonGroup(f.sevButtons, function(id)
        current.severity = id
        f.warn:SetChecked(true)
        UpdatePreview()
    end)
    local durLbl = Small(r, L["for"])
    durLbl:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    f.warnDur = W.CreateEditBox(r, 36, 20)
    f.warnDur:SetPoint("LEFT", durLbl, "RIGHT", 6, 0)
    After(r, f.warnDur, L["s"], 4)
    f.warnTry = W.CreateButton(r, L["Try it"], "normal", 60, 20)
    W.FitButton(f.warnTry, 60, 20)
    f.warnTry:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.warnTry:SetScript("OnClick", function()
        if ns.Warnings and ns.Warnings.Show then
            ns.Warnings.Show({
                text = f.chipText:GetText(), icon = f.chipIcon:GetTexture(),
                severity = current.severity, duration = tonumber(f.warnDur:GetText()) or 3,
                sound = ns.db.warnings and ns.db.warnings.blizzardSound,
            })
        end
    end)
    NoteRow(L["Same place and style as Blizzard's boss warnings (Edit Mode → Boss Warnings moves them)."])

    r = Row(L["Sound"])
    f.sound = W.CreateDropdown(r, 200, ns.Media.SoundItems(), UpdatePreview)
    f.sound:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    local test = W.CreateButton(r, L["Try it"], "normal", 60, 20)
    W.FitButton(test, 60, 20)
    test:SetPoint("LEFT", f.sound, "RIGHT", 6, 0)
    test:SetScript("OnClick", function()
        ns.Scheduler.Alert({ sound = f.sound:GetSelected() }, f.chipText:GetText())
    end)

    -- 語音播報：勾選＋要念的字（空白＝念提示文字）＋試聽
    r = Row(L["Speak"])
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
    NoteRow(L["Leave the words empty to read the reminder text. Voice, speed and volume are under General."])
end

local function BuildWho()
    local h = Header(L["Only for"])
    f.whoText = Small(h, "")
    f.whoText:SetPoint("BOTTOMLEFT", h.title, "BOTTOMRIGHT", 12, 0)
    f.whoText:SetPoint("RIGHT", h, "RIGHT", -100, 0)
    f.whoText:SetWordWrap(false)
    f.whoToggle = W.CreateButton(h, L["Pick people"], "normal", 90, 20)
    W.FitButton(f.whoToggle, 90, 20)
    f.whoToggle:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 3)
    f.whoToggle:SetScript("OnClick", function() SetWhoOpen(not current.whoOpen) end)

    local r = Row(L["Role"], nil, "who")
    f.roles = {}
    local x = CTRL_X
    for _, role in ipairs(ROLE_ORDER) do
        local cb = W.CreateCheckButton(r, role[2], UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.roles[role[1]] = cb
        x = x + 30 + math.ceil(cb.label:GetStringWidth())
    end
    f.positions = {}
    x = x + 10
    for _, p in ipairs(POSITION_ORDER) do
        local cb = W.CreateCheckButton(r, p[2], UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.positions[p[1]] = cb
        x = x + 30 + math.ceil(cb.label:GetStringWidth())
    end

    r = Row(L["Class"], nil, "who")
    f.class = W.CreateDropdown(r, 200, ClassItems(), UpdatePreview)
    f.class:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)

    -- 小隊 1～8：八個小勾選框排一列
    r = Row(L["Group"], nil, "who")
    f.groups = {}
    x = CTRL_X
    for g = 1, 8 do
        local cb = W.CreateCheckButton(r, tostring(g), UpdatePreview)
        cb:SetPoint("LEFT", r, "LEFT", x, 0)
        f.groups[g] = cb
        x = x + 18 + cb.labelGap + math.ceil(cb.label:GetStringWidth()) + 10
    end

    r = Row(L["Players"], nil, "who")
    f.players = Box(r, ROW_W - CTRL_X)

    NoteRow(L["Nothing ticked in a row = no limit from that row; different rows must all match. Melee includes tanks. Players: names separated by commas, without the realm."], "who")
end

local function Accept()
    local anchor, t, phase, phaseOffset
    if current.when == "spell" then
        local spell = AnchorSpell()
        if not spell or spell <= 0 then
            ns.Print(L["Enter the spell ID of the boss ability to follow."])
            f.anchorSpell:SetFocus()
            return
        end
        local offset = math.max(-600, math.min(600, tonumber(f.offset:GetText()) or 0))
        if current.mode == "every" then
            anchor = { spell = spell, every = true, offset = offset }
        else
            local n = tonumber(f.anchorN:GetText())
            if not n or n < 1 then
                ns.Print(L["Cast # must be 1 or more."])
                f.anchorN:SetFocus()
                return
            end
            anchor = { spell = spell, n = math.floor(n), offset = offset }
            t = Plans.ParseTime(f.fallback:GetText())
            if not t or t <= 0 then
                ns.Print(L["Enter a backup time (like 1:30) for when the ability isn't recognized."])
                f.fallback:SetFocus()
                return
            end
        end
    elseif current.when == "phase" then
        phase = f.phase:GetSelected()
        phaseOffset = tonumber(f.phaseOffset:GetText()) or 0
        t = PhaseTime()
        if not phase or not t or t <= 0 then
            ns.Print(L["Pick a phase; MRT needs phase times for this boss."])
            return
        end
    else
        t = Plans.ParseTime(f.t:GetText())
        if not t or t <= 0 then
            ns.Print(L["Time must look like 1:30 or 90."])
            f.t:SetFocus()
            return
        end
    end
    local lead = tonumber(f.lead:GetText())
    local roles = {}
    for role, cb in pairs(f.roles) do
        if cb:GetChecked() then roles[role] = true end
    end
    local positions, groups = {}, {}
    for key, cb in pairs(f.positions) do
        if cb:GetChecked() then positions[key] = true end
    end
    for g, cb in pairs(f.groups) do
        if cb:GetChecked() then groups[g] = true end
    end
    local warn = f.warn:GetChecked() and current.severity or nil
    local values = {
        t           = t,
        lead        = lead and math.max(1, lead) or nil,
        noTimeline  = (not f.onTimeline:GetChecked()) or nil,
        spell       = tonumber(f.spell:GetText()),
        text        = strtrim(f.text:GetText() or ""),
        sound       = f.sound:GetSelected() or "",
        soundWhen   = f.when:GetSelected() or "due",
        tts         = f.tts:GetChecked() and true or nil,
        ttsText     = f.tts:GetChecked() and strtrim(f.ttsText:GetText() or "") or nil,
        warn        = warn,
        warnDur     = warn and math.max(1, math.min(10, tonumber(f.warnDur:GetText()) or 3)) or nil,
        roles       = roles,
        class       = f.class:GetSelected() or "",
        anchor      = anchor,
        positions   = positions,
        groups      = groups,
        players     = ParsePlayers(f.players:GetText()),
        phase       = phase,
        phaseOffset = phaseOffset,
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
    -- 視窗比設定面板高：置中在螢幕上，不然會偏到面板的某一邊
    popup:SetPoint("CENTER", UIParent, "CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        W.CloseDropdowns()
    end)

    f = {}
    BuildHeader()
    BuildWhen()
    BuildContent()
    BuildHow()
    BuildWho()

    local cancel = W.CreateButton(popup, L["Cancel"], "normal", 80, 22)
    W.FitButton(cancel, 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", -PAD, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    local ok = W.CreateButton(popup, L["Okay"], "primary", 80, 22)
    W.FitButton(ok, 80, 22)
    ok:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
    ok:SetScript("OnClick", Accept)

    -- 打字就更新摘要；Enter 收鍵盤
    for _, eb in ipairs({ f.t, f.spell, f.text, f.lead, f.offset, f.players, f.ttsText, f.anchorSpell, f.anchorN,
                          f.fallback, f.phaseOffset, f.warnDur }) do
        eb:SetScript("OnEnterPressed", function() eb:ClearFocus() end)
        eb:HookScript("OnTextChanged", UpdatePreview)   -- Hook：ttsText／fallback 先掛了自己的 OnTextChanged
    end
    -- 在「跟著技能」那幾格打字＝就是要跟著技能；改了法術／第幾次／偏移就重新帶備援時間（玩家自己填過的不動）
    for _, eb in ipairs({ f.anchorSpell, f.anchorN, f.offset }) do
        eb:HookScript("OnEditFocusGained", function() if current.when ~= "spell" then SetWhen("spell") end end)
        eb:HookScript("OnTextChanged", function(_, userInput)
            if userInput then
                current.tTouched = false
                AutoFallback()
            end
        end)
    end
    f.t:HookScript("OnEditFocusGained", function() if current.when ~= "time" then SetWhen("time") end end)
    f.phaseOffset:HookScript("OnEditFocusGained", function() if current.when ~= "phase" and #PhaseList() > 0 then SetWhen("phase") end end)
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

local function PhaseItems()
    local items = {}
    for _, ph in ipairs(PhaseList()) do
        items[#items + 1] = { text = L["Phase %s (about %s)"]:format(tostring(ph.phase), Plans.FormatTime(math.floor(ph.t))), value = ph.phase }
    end
    return items
end

function EE.Open(values, onAccept, title, encounterID, ctx)
    if not popup then Build() end
    values = values or {}
    current = {
        onAccept = onAccept, anchor = values.anchor, anchorName = values.anchorName,
        enc = encounterID, mrtVariant = ctx and ctx.mrtVariant,
        severity = values.warn or 1, whoOpen = false, tTouched = values.t ~= nil,
    }
    f.title:SetText(title or L["Add reminder"])
    ShowBoss(encounterID)

    -- 何時
    local a = values.anchor
    if a then
        current.when = "spell"
    elseif values.phase and values.phaseOffset then
        current.when = "phase"
    else
        current.when = "time"
    end
    current.mode = (a and not a.every) and "n" or "every"
    SetBox(f.t, values.t and Plans.FormatTime(values.t))
    SetBox(f.fallback, values.t and Plans.FormatTime(values.t))
    SetBox(f.anchorSpell, a and a.spell)
    SetBox(f.anchorN, a and a.n or 1)
    SetBox(f.offset, a and a.offset or 0)
    f.phase:SetItems(PhaseItems())
    local phases = PhaseList()
    f.phase:SetSelectedValue(values.phase or (phases[1] and phases[1].phase) or nil)
    SetBox(f.phaseOffset, values.phaseOffset or 0)

    -- 內容
    SetBox(f.spell, values.spell)
    SetBox(f.text, values.text)

    -- 怎麼提醒
    f.when:SetSelectedValue(values.soundWhen or "due")
    f.onTimeline:SetChecked(not values.noTimeline)
    SetBox(f.lead, values.lead or Plans.DEFAULT_LEAD)
    f.warn:SetChecked(values.warn ~= nil)
    for _, b in ipairs(f.sevButtons) do
        if b.id == current.severity then f.highlightSeverity(b) end
    end
    SetBox(f.warnDur, values.warnDur or 3)
    f.sound:SetSelectedValue(values.sound or "")
    f.tts:SetChecked(values.tts and true or false)
    SetBox(f.ttsText, values.ttsText)

    -- 只給誰
    for role, cb in pairs(f.roles) do cb:SetChecked(values.roles and values.roles[role] and true or false) end
    f.class:SetSelectedValue(values.class or "")
    for key, cb in pairs(f.positions) do cb:SetChecked(values.positions and values.positions[key] and true or false) end
    for g, cb in pairs(f.groups) do cb:SetChecked(values.groups and values.groups[g] and true or false) end
    SetBox(f.players, PlayersText(values.players))
    local function Any(t) return type(t) == "table" and next(t) ~= nil end
    current.whoOpen = Any(values.roles) or (values.class or "") ~= "" or Any(values.positions) or Any(values.groups) or Any(values.players)
    f.whoToggle:SetText(current.whoOpen and L["Done picking"] or L["Pick people"])

    UpdatePreview()
    Relayout()
    popup:Show()
    if current.when == "time" then f.t:SetFocus()
    elseif current.when == "spell" and not IsEveryMode() then f.anchorN:SetFocus()
    else f.text:SetFocus() end
end
