------------------------------------------------------------
-- 逐法術面板：音效分頁的三件、沸點分頁、自訂文字分頁、文字分頁
-- （從 Options/SpellPopover.lua 切出，2026-10-18；TOC 緊接在 SpellPopover.lua 之後載入）
--
-- 共用的常數、控件表與幫手都掛在 ns.SpellPopover 上，這裡取回成 local；會變的狀態（目前那一格 Pop.cur、
-- 建列時的 Pop.buildTab／buildSub／buildGroup）直接讀寫 Pop 上的欄位。面板本體還沒建就不會被叫：
-- Build 建好框之後才叫這裡的 Build*，所以 BuildTextTab 開頭 Pop.Frame() 一定有值。
-- 給 SpellPopover.lua 回頭叫的：Pop.BuildTextTab（Build）、Pop.RefreshLabelTab（Refresh）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Pop = ns.SpellPopover

local PAD, LABEL_W, CTRL_X, ROW_W = Pop.PAD, Pop.LABEL_W, Pop.CTRL_X, Pop.ROW_W
local SUB_CARD_OUT, SUB_CARD_TOP = Pop.SUB_CARD_OUT, Pop.SUB_CARD_TOP
local curSub, toggles, textCtl, textLabels, labelCtl, sounds, followItems =
    Pop.curSub, Pop.toggles, Pop.textCtl, Pop.textLabels, Pop.labelCtl, Pop.sounds, Pop.followItems
local AddRow, Note, CurSlot, FollowText, CastWhen = Pop.AddRow, Pop.Note, Pop.CurSlot, Pop.FollowText, Pop.CastWhen
local Override, Changed, NewRow, RightClickClears = Pop.Override, Pop.Changed, Pop.NewRow, Pop.RightClickClears
local IsAura, OnBars, SoundItems, BlizzAura, SpellNameOf = Pop.IsAura, Pop.OnBars, Pop.SoundItems, Pop.BlizzAura, Pop.SpellNameOf

------------------------------------------------------------
-- 音效分頁的 H3 三件（Build 叫；拆成 Pop 上的函式：Build 的 upvalue 貼著 Lua 5.1 的 60 上限）
--   施放後提醒：音效列＋語音播報列走 SOUNDS 那一圈（castSound／castSpeak）；這裡接「施放後幾秒」「倒數播報」兩個數字框
--     ＋下一列灰字。倒數播報要有語音 API；延遲不到倒數＋1 秒時倒數框停用、寫入時夾範圍（Sound.Logic.Countdown）。
--   天賦條件（soundTalent）：所有格都有。下拉（不限／有這個天賦才響／沒有這個天賦才響）＋下一列 ID 框、圖示與名字
--     （查不到紅字）＋灰字。ID 框有焦點時收 Shift 點天賦樹（同一般分頁的天賦條件：看不見的代理框當 Picker 的收件者）。
--   每一列右鍵標籤清掉那一格。
------------------------------------------------------------
function Pop.BuildCastRows(NoteRow)
    local Logic = ns.Sound.Logic
    local ctl = {}
    Pop.castCtl = ctl
    local dr, dh = NewRow(L["Seconds after cast"], CastWhen)
    local dnum
    dnum = W.CreateNumberBox(dr, 40, 1, function(v)
        if not Pop.cur then return end
        local d = Logic.CastDelay(v)
        if dnum:GetValue() ~= d then dnum:SetValue(d) end
        ns.DB.SetOverride(Pop.cur.id, "castDelay", d)
        -- 倒數跟著夾：延遲縮短到不夠倒數時，存著的倒數一起降
        local c = ns.SpellOverride(Pop.cur.id, "castCountdown")
        if c ~= nil and Logic.Countdown(c, d) ~= c then
            ns.DB.SetOverride(Pop.cur.id, "castCountdown", Logic.Countdown(c, d))
        end
        Changed()
    end)
    dnum:SetPoint("LEFT", dr, "LEFT", CTRL_X, 0)
    RightClickClears(dr, dh, "castDelay")
    ctl.delay = dnum

    local cr, ch = NewRow(L["Spoken countdown"], function(kind, class)
        return CastWhen(kind, class) and ns.Sound.CanSpeak()
    end, L["Reads the last seconds aloud before the after-cast alert, for example 3, 2, 1. The delay has to be at least one second longer than the countdown."])
    local cnum
    cnum = W.CreateNumberBox(cr, 40, 1, function(v)
        if not Pop.cur then return end
        local c = Logic.Countdown(v, ns.SpellSetting(Pop.cur.key, Pop.cur.id, "castDelay"))
        if cnum:GetValue() ~= c then cnum:SetValue(c) end
        ns.DB.SetOverride(Pop.cur.id, "castCountdown", c)
        Changed()
    end)
    cnum:SetPoint("LEFT", cr, "LEFT", CTRL_X, 0)
    RightClickClears(cr, ch, "castCountdown")
    ctl.count, ctl.countRow = cnum, cr

    NoteRow(L["Plays this many seconds after you cast the spell (0 plays right away); casting it again starts over. It counts from your cast, so haste and cooldown reductions don't move it."], CastWhen)
end

function Pop.BuildSoundTalent(NoteRow)
    local ctl = {}
    Pop.soundTalentCtl = ctl
    local function Write(need, id)
        if not Pop.cur then return end
        local v = nil
        if need ~= nil then v = { id = id, need = need } end
        ns.DB.SetOverride(Pop.cur.id, "soundTalent", v)
        Changed()
    end
    local r, h = NewRow(L["Talent condition"])
    local items = {
        { text = L["Any talents"],              value = "any" },
        { text = L["Only with this talent"],    value = "have" },
        { text = L["Only without this talent"], value = "lack" },
    }
    local dd = W.CreateDropdown(r, ROW_W - CTRL_X, items, function(value)
        if not Pop.cur then return end
        local o = Override("soundTalent")
        local id = type(o) == "table" and o.id or nil
        if value == "have" or value == "lack" then Write(value == "have", id) else Write(nil) end
    end)
    dd:SetMaxWidth(ROW_W - CTRL_X)
    dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    RightClickClears(r, h, "soundTalent")
    ctl.dd = dd

    -- ID 框＋圖示＋名字（下一列，沒有標籤，對齊控件欄）
    local ir = NewRow(nil)
    local box = W.CreateEditBox(ir, 70, 20)
    box:SetPoint("LEFT", ir, "LEFT", CTRL_X, 0)
    box:SetNumeric(true)
    box:SetMaxLetters(10)
    local icon = ir:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", box, "RIGHT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local name = ir:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(W.fontSmall)
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", ir, "RIGHT", 0, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    ctl.box, ctl.icon, ctl.name = box, icon, name
    -- 提交：沒選「有／沒有」時填了 ID ⇒ 當成「有這個天賦才響」；清空 ⇒ 留著選項、拿掉 ID（引擎當不限）
    local function Commit()
        if not Pop.cur then return end
        local n = ns.Picker.ParseID(box:GetText())
        local o = Override("soundTalent")
        local need = type(o) == "table" and o.need
        if type(need) ~= "boolean" then need = nil end
        local old = type(o) == "table" and o.id or nil
        if n == old and (n == nil or need ~= nil) then return end
        if n and need == nil then need = true end
        if need == nil then return end
        Write(need, n)
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:HookScript("OnEditFocusLost", Commit)
    box:HookScript("OnTextChanged", function(_, userInput)
        if not userInput and box.filling == nil then Commit() end
    end)
    -- Shift 點天賦：同一般分頁的天賦條件（ID 框有焦點才收，不吃掉玩家平常 Shift 點進聊天的連結）
    local proxy = CreateFrame("Frame", nil, ir)
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", ir, "TOPLEFT", 0, 0)
    proxy:SetAlpha(0)
    proxy.boxes = { id = box }
    function proxy:IsShown() return self:IsVisible() and box:HasFocus() and true or false end
    box:HookScript("OnEditFocusGained", function()
        ns.Picker.WatchInput(proxy, "spell", L["That is an item link. Enter a spell ID here."])
    end)

    NoteRow(L["This spell's sounds and spoken alerts only play while you have (or don't have) this talent. Enter the talent's spell ID, or click the box and Shift-click the talent in the talent tree."])
end

-- Refresh 叫：施放後提醒的兩個數字框、音效的天賦條件
function Pop.RefreshSoundExtras()
    if not Pop.cur then return end
    local key, id = Pop.cur.key, Pop.cur.id
    local Logic = ns.Sound.Logic
    local c = Pop.castCtl
    if c then
        local delay = Logic.CastDelay(ns.SpellSetting(key, id, "castDelay"))
        c.delay:SetValue(delay)
        c.count:SetValue(Logic.Countdown(ns.SpellSetting(key, id, "castCountdown"), delay))
        local can = Logic.CountdownMax(delay) > 0
        c.count:SetEnabled(can)
        c.count:SetAlpha(can and 1 or 0.4)
    end
    local t = Pop.soundTalentCtl
    if t then
        local o = Override("soundTalent")
        local need = type(o) == "table" and o.need
        t.dd:SetSelectedValue(need == true and "have" or need == false and "lack" or "any")
        local tid = type(o) == "table" and type(o.id) == "number" and o.id > 0 and o.id or nil
        t.box.filling = true                     -- 回填不算 Shift 點擊（OnTextChanged 不提交）
        t.box:SetText(tid and tostring(tid) or "")
        t.box.filling = nil
        t.box:SetCursorPosition(0)
        local tn = tid and SpellNameOf(tid)
        if tn then
            t.name:SetText(tn)
            t.name:SetTextColor(0.8, 0.8, 0.8)
            t.icon:SetTexture(ns.Picker.LinkIcon("spell", tid) or 134400)
            t.icon:Show()
        else
            t.name:SetText(tid and L["Spell not found"] or "")
            t.name:SetTextColor(1, 0.3, 0.3)
            t.icon:Hide()
        end
        -- 名字左邊沒有圖示時貼回輸入框
        t.name:ClearAllPoints()
        t.name:SetPoint("LEFT", tn and t.icon or t.box, "RIGHT", tn and 4 or 6, 0)
        t.name:SetPoint("RIGHT", t.box:GetParent(), "RIGHT", 0, 0)
    end
end

------------------------------------------------------------
-- 沸點（事件視窗，Modules/EchoWindow.lua）分頁：只在鮮血死騎的沸血術那一格出現。
-- 值存在 profile.echo[def.key]（EchoWindow.EnsureCfg），不是逐法術覆寫；右鍵標籤 ＝ 那一欄寫 nil（讀的時候當預設：
-- 開關＝開、音效＝無、語音＝關）。開關關著時音效與語音那兩列變暗停用。
------------------------------------------------------------
local function EchoDef()
    local EW = ns.EchoWindow
    return Pop.cur and EW and EW.DefForCell and EW.DefForCell(Pop.cur.id) or nil
end
function Pop.EchoWhen() return EchoDef() ~= nil end
function Pop.EchoNoTalent()
    local def = EchoDef()
    return def ~= nil and ns.EchoWindow.TalentKnown(def) == false
end

local function EchoWrite(field, v)
    local def = EchoDef()
    local cfg = def and ns.EchoWindow.EnsureCfg(def)
    if not cfg then return end
    cfg[field] = v
    ns.EchoWindow.Apply()
    Pop.Refresh()
end

-- 右鍵標籤 ＝ 那一欄還原預設（寫 nil）
local function EchoRightClick(r, field)
    local hit = CreateFrame("Frame", nil, r)
    hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    hit:SetWidth(LABEL_W)
    hit:EnableMouse(true)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then EchoWrite(field, nil) end
    end)
end

function Pop.BuildEchoTab(NoteRow)
    local prevTab = Pop.buildTab
    Pop.buildTab = "echo"
    local ctl = {}
    Pop.echoCtl = ctl
    local When = Pop.EchoWhen

    local er = NewRow(L["Echo alert"], When)
    local ecb = W.CreateCheckButton(er, nil, function(on) EchoWrite("enabled", on and true or false) end)
    ecb:SetPoint("LEFT", er, "LEFT", CTRL_X, 0)
    EchoRightClick(er, "enabled")
    ctl.enabled = ecb
    NoteRow(L["An empowered Blood Boil strikes again 3 seconds later. While it counts down, this icon shows a bar and the seconds left at the top, and the sound below plays the moment it strikes again."], When)

    -- 回聲音效：下拉＋試聽（同音效分頁）
    local sr = NewRow(L["Echo sound"], When)
    local listen = W.CreateButton(sr, L["Listen"], "normal", 44, 20)
    W.FitButton(listen, 44, 20)
    listen:SetPoint("RIGHT", sr, "RIGHT", 0, 0)
    local ddW = ROW_W - CTRL_X - (listen:GetWidth() or 44) - 6
    local sdd = W.CreateDropdown(sr, ddW, {}, function(value)
        EchoWrite("sound", (type(value) == "string" and value ~= "") and value or false)
    end)
    sdd:SetPoint("LEFT", sr, "LEFT", CTRL_X, 0)
    listen:SetScript("OnClick", function()
        local v = sdd:GetSelected()
        if type(v) == "string" and ns.Sound then ns.Sound.Preview(v) end
    end)
    EchoRightClick(sr, "sound")
    ctl.sound, ctl.listen, ctl.soundRow = sdd, listen, sr

    -- 語音播報：勾著才寫（字串或 true）；沒勾時輸入框只是記著字
    local kr = NewRow(L["Speak"], function() return When() and ns.Sound.CanSpeak() end,
        L["Reads the text aloud with the game's text-to-speech. Leave it empty to read the spell's name."])
    local kcb = W.CreateCheckButton(kr, nil, function(on)
        if on then
            local txt = strtrim(ctl.box:GetText() or "")
            EchoWrite("speak", txt ~= "" and txt or true)
        else
            EchoWrite("speak", false)
        end
    end)
    kcb:SetPoint("LEFT", kr, "LEFT", CTRL_X, 0)
    local klisten = W.CreateButton(kr, L["Listen"], "normal", 44, 20)
    W.FitButton(klisten, 44, 20)
    klisten:SetPoint("RIGHT", kr, "RIGHT", 0, 0)
    local kbox = W.CreateEditBox(kr, 80, 20)
    kbox:SetPoint("LEFT", kcb, "RIGHT", 6, 0)
    kbox:SetPoint("RIGHT", klisten, "LEFT", -6, 0)
    kbox:SetMaxLetters(100)
    kbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    kbox:HookScript("OnEditFocusLost", function(self)
        if not kcb:GetChecked() then return end
        local txt = strtrim(self:GetText() or "")
        local want = txt ~= "" and txt or true
        local def = EchoDef()
        local cfg = def and ns.EchoWindow.Cfg(def)
        if cfg and cfg.speak == want then return end
        EchoWrite("speak", want)
    end)
    klisten:SetScript("OnClick", function()
        local def = EchoDef()
        if not def then return end
        local txt = strtrim(kbox:GetText() or "")
        local S = ns.Sound
        S.PreviewSpeak(S.Logic.SpeakText(txt ~= "" and txt or true, SpellNameOf(def.spell)))
    end)
    EchoRightClick(kr, "speak")
    ctl.speak, ctl.box, ctl.speakListen, ctl.speakRow = kcb, kbox, klisten, kr

    NoteRow(L["These settings are saved in your profile, not on this icon. Right-click a row's label to restore its default."], When)
    Pop.buildTab = prevTab
end

function Pop.RefreshEchoTab()
    local ctl = Pop.echoCtl
    local def = EchoDef()
    if not (ctl and def) then return end
    local on, sound, speak = ns.EchoWindow.Settings(ns.EchoWindow.Cfg(def))
    ctl.enabled:SetChecked(on)
    ctl.sound:SetItems(SoundItems())
    ctl.sound:SetSelectedValue(sound or false)
    ctl.speak:SetChecked(speak ~= nil)
    if not ctl.box:HasFocus() then
        ctl.box:SetText(type(speak) == "string" and speak or "")
        ctl.box:SetCursorPosition(0)
    end
    -- 開關關著：音效與語音那兩列停用變暗
    for _, w in ipairs({ ctl.sound, ctl.listen, ctl.speak, ctl.box, ctl.speakListen }) do
        if w.SetEnabled then w:SetEnabled(on) end
    end
    ctl.soundRow:SetAlpha(on and 1 or 0.4)
    ctl.speakRow:SetAlpha(on and 1 or 0.4)
end

------------------------------------------------------------
-- 自訂文字（M）：增益圖示類的格（暴雪的增益圖示、圖示形的光環格與飾品欄增益）才有；長條不出現（長條本來就有名字）。
-- 欄位全是逐法術覆寫、沒有條層值（Core/DB.lua 的 SPELL_CONST，引擎在 Core/Text.lua 的 LabelStyle）：
--   文字   輸入框；按 Enter 或失焦才寫（不每個字重排），Esc 放棄這次的修改；空白 ＝ 清掉（不畫）
--   字型   下拉；第一項「跟隨通用字型」＝清掉（條的通用字型）
--   字級   拉桿，放開才寫（預設 12）
--   顏色   直接一個色票（沒設 ＝ 白；不繼承，沒有「自訂」勾選）
--   錨點   九宮格（圖示內的那個角／邊，同倒數；預設「下」）
--   偏移   X／Y（預設 0／-2：字的下半略壓過圖示下緣）
-- 描邊吃條的設定。每一列右鍵標籤清掉那一格（回預設）；沒覆寫的標籤變暗（同文字分頁）
------------------------------------------------------------
local function BuildLabelTab(NoteRow, PointRow, Track)
    Pop.buildTab = "label"
    local function LabelWhen(kind, class)
        return (IsAura(kind) or BlizzAura(kind, class)) and not OnBars()
    end
    local function Default(field) return ns.DB.SPELL_CONST[field] end

    -- 文字
    do
        local r, h = NewRow(L["Text"], LabelWhen)
        local box = W.CreateEditBox(r, ROW_W - CTRL_X, 20)
        box:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        box:SetMaxLetters(60)
        -- 打字中換了一格（小窗還開著、點了別的預覽格）：失焦時 cur 已經是別格 ⇒ 這次的字丟掉，不寫到別格上
        local function Commit(self)
            if not Pop.cur or Pop.cur.id ~= self.editID then return end
            local txt = strtrim(self:GetText() or "")
            local want = txt ~= "" and txt or nil
            if Override("labelText") == want then return end
            ns.DB.SetOverride(Pop.cur.id, "labelText", want)
            Changed()
        end
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self)
            self.cancel = true
            local v = Override("labelText")
            self:SetText(type(v) == "string" and v or "")
            self:ClearFocus()
        end)
        box:HookScript("OnEditFocusGained", function(self) self.editID = Pop.cur and Pop.cur.id end)
        box:HookScript("OnEditFocusLost", function(self)
            if self.cancel then self.cancel = nil return end
            Commit(self)
        end)
        RightClickClears(r, h, "labelText")
        labelCtl[#labelCtl + 1] = { kind = "text", box = box }
        Track(r, { "labelText" })
    end
    NoteRow(L["A short note on this icon, for example what the buff is. Leave it blank to show nothing."], LabelWhen)

    -- 字型：第一項「跟隨通用字型」（INHERIT）＝清掉
    do
        local r, h = NewRow(L["Font"], LabelWhen)
        local dd = W.CreateDropdown(r, ROW_W - CTRL_X, ns.Specs.ElementFontItems(), function(value)
            if not Pop.cur then return end
            local v = (type(value) == "string" and value ~= "" and value ~= ns.Media.INHERIT) and value or nil
            ns.DB.SetOverride(Pop.cur.id, "labelFont", v)
            Changed()
        end)
        dd:SetMaxWidth(ROW_W - CTRL_X)
        dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, "labelFont")
        labelCtl[#labelCtl + 1] = { kind = "font", dd = dd }
        Track(r, { "labelFont" })
    end

    -- 字級：放開才寫
    do
        local r, h = NewRow(L["Font size"], LabelWhen)
        local sl = W.CreateSlider(r, 6, 40, ROW_W - CTRL_X, 1, nil, function(v)
            if not Pop.cur then return end
            ns.DB.SetOverride(Pop.cur.id, "labelSize", v)
            Changed()
        end)
        sl:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, "labelSize")
        labelCtl[#labelCtl + 1] = { kind = "size", slider = sl }
        Track(r, { "labelSize" })
    end

    -- 顏色：直接一個色票（不繼承：沒設 ＝ 白），右鍵標籤回白
    do
        local r, h = NewRow(L["Color"], LabelWhen)
        local sw = W.CreateColorPicker(r, nil, false, function(rr, g, b)
            if not Pop.cur then return end
            ns.DB.SetOverride(Pop.cur.id, "labelColor", { r = rr, g = g, b = b, a = 1 })
            Changed()
        end)
        sw:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, "labelColor")
        labelCtl[#labelCtl + 1] = { kind = "color", swatch = sw }
        Track(r, { "labelColor" })
    end

    -- 錨點：九宮格（文字分頁那一支；沒覆寫 ＝ 預設「下」）
    PointRow("labelPoint", LabelWhen, nil, Default("labelPoint") or "BOTTOM")

    -- 偏移：X／Y（沒覆寫 ＝ 固定預設 0／-2）；右鍵標籤兩個一起清
    do
        local r = NewRow(L["Offset"], LabelWhen)
        local px = CTRL_X
        local boxes = {}
        for _, f in ipairs({ { "X", "labelX" }, { "Y", "labelY" } }) do
            local tag = r:CreateFontString(nil, "OVERLAY")
            tag:SetFontObject(W.fontSmall)
            tag:SetTextColor(0.6, 0.6, 0.6)
            tag:SetPoint("LEFT", r, "LEFT", px, 0)
            tag:SetText(f[1])
            px = px + (tag:GetStringWidth() or 8) + 4
            local field = f[2]
            local nb = W.CreateNumberBox(r, 46, 1, function(v)
                if not Pop.cur then return end
                ns.DB.SetOverride(Pop.cur.id, field, v)
                Changed()
            end)
            nb:SetPoint("LEFT", r, "LEFT", px, 0)
            px = px + 46 + 10
            boxes[#boxes + 1] = { nb = nb, field = field }
        end
        local hit = CreateFrame("Frame", nil, r)
        hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        hit:SetWidth(LABEL_W)
        hit:EnableMouse(true)
        hit:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and Pop.cur then
                ns.DB.SetOverride(Pop.cur.id, "labelX", nil)
                ns.DB.SetOverride(Pop.cur.id, "labelY", nil)
                Changed()
            end
        end)
        labelCtl[#labelCtl + 1] = { kind = "offset", boxes = boxes }
        Track(r, { "labelX", "labelY" })
    end
end

-- 自訂文字分頁的回填（Pop.Refresh 叫）：值＝覆寫，沒有就是固定預設
local function RefreshLabelTab()
    local C = ns.DB.SPELL_CONST
    local function Val(field)
        local v = Override(field)
        if v == nil then v = C[field] end
        return v
    end
    for _, c in ipairs(labelCtl) do
        if c.kind == "text" then
            -- 打字打到一半換了一格：那段字是上一格的，丟掉（Commit 也會擋），框換成這一格的字
            if c.box:HasFocus() and Pop.cur and c.box.editID ~= Pop.cur.id then
                c.box.cancel = true
                c.box:ClearFocus()
            end
            if not c.box:HasFocus() then
                local v = Override("labelText")
                c.box:SetText(type(v) == "string" and v or "")
                c.box:SetCursorPosition(0)
            end
        elseif c.kind == "font" then
            local v = Override("labelFont")
            c.dd:SetSelectedValue((type(v) == "string" and v ~= "") and v or ns.Media.INHERIT)
        elseif c.kind == "size" then
            c.slider:SetValue(tonumber(Val("labelSize")) or 12)
        elseif c.kind == "color" then
            local v = Override("labelColor")
            c.swatch:SetColor(type(v) == "table" and v or { r = 1, g = 1, b = 1, a = 1 })
        elseif c.kind == "offset" then
            for _, b in ipairs(c.boxes) do b.nb:SetValue(tonumber(Val(b.field)) or 0) end
        end
    end
end
Pop.RefreshLabelTab = RefreshLabelTab

------------------------------------------------------------
-- 「文字」分頁（H）：Build 叫一次。DurationRows／ColorOverrideRow／NoteRow 是 Build 裡的區域函式，傳進來用
------------------------------------------------------------
local function BuildTextTab(DurationRows, ColorOverrideRow, NoteRow)
    local frame = Pop.Frame()           -- Build 建好框才叫這裡（見檔頭）
    local body = frame.body
    --------------------------------------------------------
    -- 文字（H）：倒數／充能／層數／按鍵文字，每一列都是逐法術覆寫（三態：沒覆寫＝跟隨條；右鍵標籤清掉）。
    -- 控件照條頁「文字」節：字型與錨點是下拉（第一項「跟隨『條名』」＝清掉）、字級與門檻是拉桿、顏色是「自訂」＋色票、
    -- 偏移是 X／Y 兩個數字框。拉桿與數字框看不出有沒有覆寫 ⇒ 這一頁的標籤沒覆寫時變暗（Refresh），最上面一列灰字說明。
    -- 值一律照 Text.SpellText 合併後的回填（長條的秒數另有自己的底，見那支）。
    -- 哪些列出現：
    --   名字  長條上的格（橫向；直向長條不畫名字）：顯示名字（三態 barShowName）、字型、字級，排在倒數前面（Text.SpellText 的 "barName"）
    --   倒數  每一種格都有（長條上的格標題叫「時間」、隱藏叫「隱藏時間」）；小數門檻與低秒變色長條沒有（秒數是暴雪寫的字串／整數 formatter）
    --         換色開關＋兩個字色＝「先倒增益」那一段（暴雪的冷卻格、飾品欄），從原本的「增益持續時間」分頁搬來
    --         從小數門檻開始分子分頁「冷卻｜增益持續時間」（K）：各四列（小數門檻＋低秒變色＋變色顏色＋變色秒數）；
    --         增益持續時間那組（I／J）＝有增益持續時間的格（增益類、暴雪的冷卻格、飾品欄），沒有的格不出子分頁鈕、只有冷卻那組；
    --         長條兩組都沒有。增益持續時間的變色顏色與秒數只在它的低秒變色生效時可改
    --   充能  圖示類的冷卻格（暴雪核心／輔助、自訂法術／物品／飾品欄）；增益類與長條沒有
    --   層數  增益類（暴雪的增益、光環格）、飾品欄（疊在上面的增益按鈕）、長條上的格（圖示右下那個數字）；
    --         長條的層數固定在圖示右下 ⇒ 沒有錨點列（同條頁）
    --   按鍵  條層有這一節的（不是長條、不是增益圖示列；Keybinds.NoKeybind）而且不是光環格
    --------------------------------------------------------
    Pop.buildTab = "text"
    -- 倒數那一段在這一格讀哪個底：長條 ⇒ 長條的秒數（"barTime"），其餘 ⇒ 條層的倒數
    local function CdSection() return OnBars() and "barTime" or "cooldownText" end
    local function Always() return true end
    local function NotBarsRow() return not OnBars() end
    local function ChargeRows(_, class) return not OnBars() and class ~= "aura" end
    local function StackRows(kind, class)
        return class == "aura" or OnBars() or kind == "slot" or CurSlot() ~= nil
    end
    local function StackAnchorRow(kind, class) return StackRows(kind, class) and not OnBars() end
    -- 內建冷卻是被動、不在快捷列上，沒有按鍵文字可畫（Core/Keybinds.lua 的 TextFor 也只認法術／物品）
    local function KeyRows(kind)
        return Pop.cur ~= nil and kind ~= "aura" and kind ~= "timer" and not ns.Keybinds.NoKeybind(Pop.cur.key)
    end
    local function KeyOff(kind)
        return KeyRows(kind) and not ns.Setting(Pop.cur.key, "keybind.enabled")
    end

    local function Track(r, fields)
        if r and r.label then
            textLabels[#textLabels + 1] = { fs = r.label, fields = fields }
        end
    end

    -- 小節標題（同條頁的 nested 標題：accent 小字、右緣對齊標籤欄）
    local function HeaderRow(text, when)
        local hr = CreateFrame("Frame", nil, body)
        local fs = W.CreateGroupLabel(hr, text)
        fs:SetPoint("BOTTOMRIGHT", hr, "BOTTOMLEFT", LABEL_W, 4)
        fs:SetJustifyH("RIGHT")
        hr:SetSize(ROW_W, 22)
        AddRow({ frame = hr, h = 22, when = when })
    end

    -- 勾選（隱藏）：寫 true／false；旁邊灰字講值從哪來（同上面的 TOGGLES）
    local function ToggleRow(field, label, when)
        local tr, th = NewRow(label, when)
        local cb = W.CreateCheckButton(tr, nil, function(on)
            if not Pop.cur then return end
            ns.DB.SetOverride(Pop.cur.id, field, on and true or false)
            Changed()
        end)
        cb:SetPoint("LEFT", tr, "LEFT", CTRL_X, 0)
        local note = Note(tr)
        note:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        note:SetPoint("RIGHT", tr, "RIGHT", 0, 0)
        note:SetWordWrap(false)
        toggles[#toggles + 1] = { field = field, cb = cb, note = note, row = tr }
        RightClickClears(tr, th, field)
        Track(tr, { field })
    end

    -- 字型：第一項「跟隨『條名』」＝清掉，第二項「跟隨通用字型」（INHERIT，這也是一個覆寫值），其餘照 LibSharedMedia（Refresh 時才列）
    local function FontRow(section, field, when)
        local r, h = NewRow(L["Font"], when)
        local dd = W.CreateDropdown(r, ROW_W - CTRL_X, { { text = FollowText(), value = false } }, function(value)
            if not Pop.cur then return end
            ns.DB.SetOverride(Pop.cur.id, field, (type(value) == "string" and value ~= "") and value or nil)
            Changed()
        end)
        dd:SetMaxWidth(ROW_W - CTRL_X)
        dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "font", dd = dd, field = field, section = section }
        Track(r, { field })
    end

    -- 錨點：九宮格（同條頁 Options/Specs.lua 的 PointGridTS）。格子顯示生效的值（沒覆寫＝條的值，標籤變暗）；
    -- 點一格＝這一招覆寫成那個錨點，右鍵標籤清掉回跟隨條
    local GRID_CELL, GRID_GAP, GRID_PAD = 14, 2, 4
    local GRID_IDLE, GRID_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }
    local POINT_TEXT = {}
    for _, it in ipairs(ns.Specs.POINT_ITEMS) do POINT_TEXT[it.value] = it.text end
    local function PointRow(field, when, section, fallback)
        local r, h, row = NewRow(L["Anchor"], when)
        local side = GRID_CELL * 3 + GRID_GAP * 2
        local gridH = side + GRID_PAD * 2
        local function Fit()
            local nh = math.max(row.h or h, gridH)
            r:SetHeight(nh)
            row.h = nh
        end
        local remeasure = row.remeasure
        row.remeasure = function()
            if remeasure then remeasure() end
            Fit()
        end
        Fit()
        local holder = CreateFrame("Frame", nil, r)
        holder:SetSize(side, side)
        holder:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        local name = r:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontSmall)
        name:SetTextColor(0.65, 0.65, 0.65)
        name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
        local ctl = { kind = "point", field = field, section = section, fallback = fallback, cells = {}, name = name }
        function ctl.Paint()
            for _, b in ipairs(ctl.cells) do
                if b.point == ctl.cur then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and GRID_HOVER or GRID_IDLE)) end
            end
            name:SetText(POINT_TEXT[ctl.cur] or "")
        end
        for i, it in ipairs(ns.Specs.POINT_ITEMS) do
            local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
            b:SetSize(GRID_CELL, GRID_CELL)
            b:SetPoint("TOPLEFT", ((i - 1) % 3) * (GRID_CELL + GRID_GAP), -math.floor((i - 1) / 3) * (GRID_CELL + GRID_GAP))
            W.Stylize(b, GRID_IDLE, { 0, 0, 0, 1 })
            b.point = it.value
            b:SetScript("OnEnter", function() b.hover = true; ctl.Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; ctl.Paint() end)
            b:SetScript("OnClick", function()
                if not Pop.cur then return end
                ns.DB.SetOverride(Pop.cur.id, field, it.value)
                ctl.cur = it.value
                ctl.Paint()
                Changed()
            end)
            ctl.cells[i] = b
        end
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = ctl
        Track(r, { field })
    end

    -- 拉桿（字級、小數門檻、變色秒數）：放開才寫（拖動中不寫）；顯示合併後的值
    local function SizeRow(label, section, key, field, lo, hi, when)
        local r, h = NewRow(label, when)
        local sl = W.CreateSlider(r, lo, hi, ROW_W - CTRL_X, 1, nil, function(v)
            if not Pop.cur then return end
            ns.DB.SetOverride(Pop.cur.id, field, v)
            Changed()
        end)
        sl:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "size", slider = sl, section = section, key = key, field = field, lo = lo }
        Track(r, { field })
    end

    -- 顏色：勾「自訂」才寫覆寫（初值＝目前生效的顏色），同上面的顏色列
    local function TextColorRow(label, section, key, field, fallback, when)
        local r, h = NewRow(label, when)
        local cb = W.CreateCheckButton(r, L["Custom"], function(on)
            if not Pop.cur then return end
            if on then
                local t = ns.Text.SpellText(Pop.cur.key, Pop.cur.id, type(section) == "function" and section() or section, true)
                local c = type(t[key]) == "table" and t[key] or fallback
                ns.DB.SetOverride(Pop.cur.id, field, { r = c.r or 1, g = c.g or 1, b = c.b or 1, a = c.a or 1 })
            else
                ns.DB.SetOverride(Pop.cur.id, field, nil)
            end
            Changed()
        end)
        cb:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
        local sw = W.CreateColorPicker(r, nil, false, function(rr, g, b)
            if not Pop.cur or type(Override(field)) ~= "table" then return end
            ns.DB.SetOverride(Pop.cur.id, field, { r = rr, g = g, b = b, a = 1 })
            Changed()
        end)
        sw:SetPoint("LEFT", cb.label, "RIGHT", 10, 0)
        RightClickClears(r, h, field)
        textCtl[#textCtl + 1] = { kind = "color", cb = cb, swatch = sw, section = section, key = key, field = field,
                                  fallback = fallback }
        Track(r, { field })
    end

    -- 偏移：X／Y 兩個數字框（同條頁）；右鍵標籤兩個一起清
    local function OffsetRow(section, fx, fy, when)
        local r = NewRow(L["Offset"], when)
        local px = CTRL_X
        local boxes = {}
        for _, f in ipairs({ { "X", fx, "x" }, { "Y", fy, "y" } }) do
            local tag = r:CreateFontString(nil, "OVERLAY")
            tag:SetFontObject(W.fontSmall)
            tag:SetTextColor(0.6, 0.6, 0.6)
            tag:SetPoint("LEFT", r, "LEFT", px, 0)
            tag:SetText(f[1])
            px = px + (tag:GetStringWidth() or 8) + 4
            local field = f[2]
            local nb = W.CreateNumberBox(r, 46, 1, function(v)
                if not Pop.cur then return end
                ns.DB.SetOverride(Pop.cur.id, field, v)
                Changed()
            end)
            nb:SetPoint("LEFT", r, "LEFT", px, 0)
            px = px + 46 + 10
            boxes[#boxes + 1] = { nb = nb, key = f[3] }
        end
        local hit = CreateFrame("Frame", nil, r)
        hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        hit:SetWidth(LABEL_W)
        hit:EnableMouse(true)
        hit:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and Pop.cur then
                ns.DB.SetOverride(Pop.cur.id, fx, nil)
                ns.DB.SetOverride(Pop.cur.id, fy, nil)
                Changed()
            end
        end)
        textCtl[#textCtl + 1] = { kind = "offset", boxes = boxes, section = section }
        Track(r, { fx, fy })
    end

    -- 名字（長條的格才有，排最前面：長條上第一個看到的就是名字；直向長條不畫名字 ⇒ 不出）。
    -- 開關是三態的 barShowName：沒覆寫＝跟隨條的「顯示名字」（勾選框照條的值、灰字「（跟隨『條名』）」），
    -- 點了寫 true／false（條關著也能只開這一招、反之亦然），右鍵標籤回跟隨。字型／字級的底是條的名字字型／字級
    local function NameRows() return OnBars() and not ns.Setting(Pop.cur.key, "bar.vertical") end
    HeaderRow(L["Name text"], NameRows)
    ToggleRow("barShowName", L["Show name"], NameRows)
    FontRow("barName", "barNameFont", NameRows)
    SizeRow(L["Font size"], "barName", "size", "barNameSize", 6, 30, NameRows)

    -- 倒數（長條的格叫「時間」：倒的是長條右邊的秒數；存檔欄位同一個）
    HeaderRow(L["Countdown"], NotBarsRow)
    HeaderRow(L["Time text"], OnBars)
    ToggleRow("hideCooldownText", L["Hide countdown"], NotBarsRow)
    ToggleRow("hideCooldownText", L["Hide time"], OnBars)
    FontRow(CdSection, "cooldownTextFont", Always)
    SizeRow(L["Font size"], CdSection, "size", "cooldownTextSize", 6, 40, Always)
    TextColorRow(L["Color"], CdSection, "color", "cooldownTextColor", { r = 1, g = 1, b = 1, a = 1 }, Always)
    PointRow("cooldownTextPoint", Always, "cooldownText", "CENTER")
    OffsetRow(CdSection, "cooldownTextX", "cooldownTextY", Always)
    -- 從小數門檻開始分兩個子分頁「冷卻｜增益持續時間」（K，同條頁）：兩組各四列（小數門檻、低秒變色、變色顏色、
    -- 變色秒數），標籤不帶前綴。增益持續時間那組只在有增益持續時間的格出現（增益類、暴雪的冷卻格、飾品欄；長條的秒數
    -- 換不了 ⇒ 長條兩組都沒有）；沒有增益持續時間的格不出子分頁鈕、只有冷卻那組
    local function BuffTimeRows(kind, class) return not OnBars() and (class == "aura" or DurationRows(kind, class)) end
    -- 子分頁鈕＋卡片（L，W.CreateTabCard）：卡片左右比列寬各多出 SUB_CARD_OUT（包住標籤與控件），
    -- 上緣＝鈕列底、底＝最後一個子分頁的列（Layout 排的時候補）。鈕列本身就是這一列的 frame
    -- labels：卡片裡的標籤，所有卡片的一起量、最長的定左緣（兩張卡片左緣對齊，使用者 2026-10-06）；
    -- gap：鈕列上方多留的（cs 緊接在 cd 卡片底下）
    frame.subCards = {}
    local cardLabels = {}
    local function SubCard(group, tabs, help, labels, gap, when)
        for _, k in ipairs(labels) do cardLabels[#cardLabels + 1] = k end
        local tc = W.CreateTabCard(body, {
            tabs = tabs,
            help = help,
            selected = curSub[group],
            onSelect = function(id)
                if id == curSub[group] then return end
                curSub[group] = id
                if Pop.cur then Pop.Layout(frame.kind, frame.soundClass) end
            end,
        })
        frame.subCards[group] = tc
        AddRow({ frame = tc.strip, h = 0, when = when, subStrip = group,
            place = function(y)
                -- 左緣＝卡片裡最長的標籤再外推一點（標籤欄靠右對齊；不包空著的標籤欄左半，使用者 2026-10-06），
                -- 右緣＝列的右緣再外推 SUB_CARD_OUT
                local measure = frame.subCardMeasure
                if not measure then
                    measure = frame:CreateFontString(nil, "OVERLAY")
                    measure:SetFontObject(W.fontNormal)
                    measure:Hide()
                    frame.subCardMeasure = measure
                end
                local lw = 0
                for _, k in ipairs(cardLabels) do
                    measure:SetText(L[k])
                    lw = math.max(lw, math.ceil(measure:GetStringWidth() or 0))
                end
                local left = math.max(PAD - SUB_CARD_OUT, PAD + CTRL_X - 10 - math.min(lw, LABEL_W) - 10)
                local right = PAD + ROW_W + SUB_CARD_OUT
                local top = SUB_CARD_TOP + gap
                local sh = tc:Place(left, y - top, right - left)
                return top + sh + W.TAB_CARD_PAD
            end,
            paint = function(id) tc:Select(id) end })
    end
    SubCard("cd", { { id = "cooldown", label = L["Cooldown"] }, { id = "duration", label = L["Buff duration"] } },
        ns.Specs.SubTabHelp, { "Decimals below", "Color when low", "Low color", "Low below (sec)" }, 0, BuffTimeRows)
    Pop.buildGroup = "cd"

    -- 冷卻：低秒變色的開關（cooldownTextLowColorOn）跟變色秒數（cooldownTextLowBelow）分兩個覆寫，同條頁與增益持續時間那組：
    -- 取消勾選只寫開關，秒數不動（2026-10-06 拆開；舊存檔的「秒數覆寫 0 ＝ 關」由 DB 的 MIGRATIONS[5] 搬）
    Pop.buildSub = "cooldown"
    SizeRow(L["Decimals below"], "cooldownText", "decimalsBelow", "cooldownTextDecimals", 0, 10, NotBarsRow)
    NoteRow(L["Shows one decimal place under this many seconds; 0 never shows decimals."], NotBarsRow)
    ToggleRow("cooldownTextLowColorOn", L["Color when low"], NotBarsRow)
    TextColorRow(L["Low color"], "cooldownText", "lowColor", "cooldownTextLowColor", { r = 1, g = 0.3, b = 0.3, a = 1 }, NotBarsRow)
    SizeRow(L["Low below (sec)"], "cooldownText", "lowBelow", "cooldownTextLowBelow", 1, 30, NotBarsRow)

    -- 增益持續時間（I／J）：覆寫 key 跟條層同名（變色顏色是 durationLowColor）；變色顏色只在增益持續時間的低秒變色
    -- 生效（合併後）時可改
    Pop.buildSub = "duration"
    local function BuffLowOn(key, id)
        if OnBars() then return false end
        return ns.Text.SpellText(key, id, "cooldownText", true).buffLowColor == true
    end
    SizeRow(L["Decimals below"], "cooldownText", "buffDecimalsBelow", "buffDecimalsBelow", 0, 10, BuffTimeRows)
    NoteRow(L["Shows one decimal place under this many seconds; 0 never shows decimals."], BuffTimeRows)
    ToggleRow("buffLowColor", L["Color when low"], BuffTimeRows)
    Track(ColorOverrideRow(L["Low color"], "durationLowColor", false, { r = 0.95, g = 0.45, b = 0.70, a = 1 },
        BuffTimeRows, BuffLowOn, true), { "durationLowColor" })
    SizeRow(L["Low below (sec)"], "cooldownText", "buffLowBelow", "buffLowBelow", 1, 30, BuffTimeRows)

    -- 增益那一段的換色＋字色：也是增益持續時間的設定 ⇒ 歸「增益持續時間」子分頁（切到「冷卻」時不出現，免得看起來像冷卻的）。
    -- 原本在「增益持續時間」分頁：五個欄位跟主題頁同一套、
    -- 同一套連動——「顯示增益持續時間」生效是不顯示 ⇒ 換色列停用；換色生效是關 ⇒ 顏色列停用（Refresh）
    local cdr, cdh = NewRow(L["Recolor buff duration"], DurationRows)
    local cdItems = {
        { text = FollowText(), value = "follow" },
        { text = L["Recolor"],         value = "on" },
        { text = L["Don't recolor"],   value = "off" },
    }
    local cddd = W.CreateDropdown(cdr, ROW_W - CTRL_X, cdItems, function(value)
        if not Pop.cur then return end
        local v = nil
        if value == "on" then v = true elseif value == "off" then v = false end
        ns.DB.SetOverride(Pop.cur.id, "colorDuration", v)
        Changed()
    end)
    cddd:SetMaxWidth(ROW_W - CTRL_X)
    cddd:SetPoint("LEFT", cdr, "LEFT", CTRL_X, 0)
    frame.colorDurDD = cddd
    followItems[#followItems + 1] = { items = cdItems, dd = cddd }
    RightClickClears(cdr, cdh, "colorDuration")
    Track(cdr, { "colorDuration" })
    Track(ColorOverrideRow(L["Buff duration color"],     "durationColor",    false, { r = 1,    g = 0.85, b = 0.1,  a = 1 }), { "durationColor" })
    Pop.buildSub = nil

    -- 充能｜層數（cs 組）：兩種都有的格才出鈕＋卡片；只有一種的格那一節照舊帶小節標題
    local function BothCS(kind, class) return ChargeRows(kind, class) and StackRows(kind, class) end
    SubCard("cs", { { id = "charges", label = L["Charges"] }, { id = "stacks", label = L["Stacks"] } }, nil,
        { "Hide charges", "Hide stacks", "Font", "Font size", "Color", "Anchor", "Offset" }, 6, BothCS)
    Pop.buildGroup = "cs"

    -- 充能
    Pop.buildSub = "charges"
    HeaderRow(L["Charges"], function(kind, class) return ChargeRows(kind, class) and not StackRows(kind, class) end)
    ToggleRow("hideChargeText", L["Hide charges"], ChargeRows)
    FontRow("chargeText", "chargeTextFont", ChargeRows)
    SizeRow(L["Font size"], "chargeText", "size", "chargeTextSize", 6, 30, ChargeRows)
    TextColorRow(L["Color"], "chargeText", "color", "chargeTextColor", { r = 1, g = 1, b = 1, a = 1 }, ChargeRows)
    PointRow("chargeTextPoint", ChargeRows, "chargeText", "BOTTOMRIGHT")
    OffsetRow("chargeText", "chargeTextX", "chargeTextY", ChargeRows)

    -- 層數
    Pop.buildSub = "stacks"
    HeaderRow(L["Stacks"], function(kind, class) return StackRows(kind, class) and not ChargeRows(kind, class) end)
    ToggleRow("hideStackText", L["Hide stacks"], StackRows)
    FontRow("stackText", "stackTextFont", StackRows)
    SizeRow(L["Font size"], "stackText", "size", "stackTextSize", 6, 30, StackRows)
    TextColorRow(L["Color"], "stackText", "color", "stackTextColor", { r = 1, g = 1, b = 1, a = 1 }, StackRows)
    PointRow("stackTextPoint", StackAnchorRow, "stackText", "TOP")
    OffsetRow("stackText", "stackTextX", "stackTextY", StackRows)
    Pop.buildSub, Pop.buildGroup = nil, nil

    -- 按鍵文字（沒有顏色：一律白字，同條層）
    HeaderRow(L["Keybind text"], KeyRows)
    ToggleRow("hideKeybind", L["Hide keybind text"], KeyRows)
    FontRow("keybind", "keybindFont", KeyRows)
    SizeRow(L["Font size"], "keybind", "size", "keybindSize", 6, 24, KeyRows)
    PointRow("keybindPoint", KeyRows, "keybind", "TOPRIGHT")
    OffsetRow("keybind", "keybindX", "keybindY", KeyRows)
    NoteRow(L["Keybind text is turned off for this bar, so these only show once it's on (Text, Keybind text)."], KeyOff)

    -- 自訂文字分頁（M）：借這裡的九宮格與標籤變暗；從這裡叫（Build 的 upvalue 貼著 Lua 5.1 的 60 上限）
    BuildLabelTab(NoteRow, PointRow, Track)
end
Pop.BuildTextTab = BuildTextTab

-- 不顯示（只給其他插件讀取；逐法術 hidden，判準 Catalog.CanHide）：一般分頁最上面一列勾選框＋下一列灰字。
-- 勾了之後只跟畫面有關的停用（Pop.HIDE_VISUAL_TABS 那幾個分頁鈕、一般分頁的「增益不在時」），音效分頁照常。
-- 掛在 Pop 上不當 local：Build 的 upvalue 貼著 Lua 5.1 的 60 上限（Build 只多叫一次 Pop.BuildHideRow，Pop 本來就抓著）
