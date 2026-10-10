------------------------------------------------------------
-- 預覽播放：在設定視窗裡把整份自訂時間軸跑一遍
--
-- 「立即測試」是真的寫進暴雪時間軸（DBM 的條也會跟著冒出來、要等真實秒數）；這裡是假的時鐘：
--   * 左邊一塊預覽，用的是畫面上那條時間軸的同一支 Display、同一份外觀（直式／橫式／計時條）
--   * 右邊播放控制：播放／暫停、從頭、1x／2x／4x、可以拖的進度條
--   * 自己的提示照實際規則出現（提前 lead 秒上軸）；MRT 的首領技能一起放（暴雪的顏色），看得出對不對得上
--   * 播放中到點會真的播音效、朗讀（可以關）；拖進度條不會補播跳過的
--   * 跟隨首領的提示：有 MRT 資料就放在「第 n 次施放＋偏移」的位置（＝戰鬥中認出來時會在的地方）
--   * 「每一次」的提示：有 MRT 資料就在那個技能每一次施放＋偏移各放一條；沒有 MRT 資料就不出現
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Plans = ns.Plans
local MD = ns.MRTData

ns.PlanPreview = {}
local PV = ns.PlanPreview

local POP_W, POP_H = 680, 470
local BOX_W, BOX_H = 330, 380
local PAD = 8
local SOON = 5

local popup, clip, display, timeLabel, slider, playBtn, speedButtons, highlightSpeed
local cbSound, cbMRT, cbMine
-- id＝設定檔 ID；enc＝它的首領戰 ID（MRT 資料照首領存）；diff＝開預覽時看的難度分頁（MRT 預設挑哪一份）
local state = { t = 0, playing = false, speed = 1, length = 60, id = nil, enc = nil, diff = nil, sound = true, mrt = true, onlyMine = true }
local entries, bossEvents = {}, {}

------------------------------------------------------------
-- 資料：把計畫攤成「何時發生」的清單
------------------------------------------------------------
local function Rebuild()
    wipe(entries)
    wipe(bossEvents)
    local plan = Plans.Get(state.id)
    if not plan then return end
    local variant = plan.mrtVariant
    if not variant and MD.Has(state.enc) then variant = MD.DefaultVariant(state.enc, state.diff) end
    local nth = {}           -- [spell] = { 第 n 次的秒數 }
    local length = 60
    if variant then
        for i, ev in ipairs(MD.Events(state.enc, variant)) do
            local list = nth[ev.spell] or {}
            list[#list + 1] = ev.t
            nth[ev.spell] = list
            bossEvents[#bossEvents + 1] = { key = "pvb" .. i, due = ev.t, name = ev.name, icon = ev.icon }
            length = math.max(length, ev.t)
        end
    end
    local function Add(key, e, due)
        local icon, text = Plans.Resolve(e)
        entries[#entries + 1] = {
            key = key, entry = e, due = due, lead = math.max(1, e.lead or Plans.DEFAULT_LEAD),
            icon = icon, text = text,
        }
        length = math.max(length, due)
    end
    for i, e in ipairs(plan.entries) do
        if e.enabled ~= false and (not state.onlyMine or Plans.EntryApplies(e)) then
            local a = e.anchor
            if Plans.IsEvery(e) then
                for k, at in ipairs(nth[a.spell] or {}) do
                    local due = at + (a.offset or 0)
                    if due > 0 then Add("pve" .. i .. "_" .. k, e, due) end
                end
            else
                local due = e.t or 0
                if a and nth[a.spell] and nth[a.spell][a.n] then due = nth[a.spell][a.n] + (a.offset or 0) end
                Add("pve" .. i, e, due)
            end
        end
    end
    state.length = length + 10
    slider:SetMinMaxValues(0, state.length)
end

local itemPool = {}
local function Item(n)
    local it = itemPool[n]
    if not it then
        it = {}
        itemPool[n] = it
    end
    return it
end

-- Display 的資料來源（欄位同 Events.Collect）
local function Collect(out, filter)
    local T = state.t
    local n = 0
    for _, x in ipairs(entries) do
        local rem = x.due - T
        if T >= x.due - x.lead and rem > -1 and (not filter or filter("mine")) then
            n = n + 1
            local it = Item(n)
            it.key, it.id, it.kind, it.owner = x.key, nil, "mine", nil
            it.name, it.icon, it.color = x.text, x.icon, nil
            it.rem, it.duration, it.paused, it.queued, it.mock = rem, x.lead, false, rem <= 0, true
            out[n] = it
        end
    end
    if state.mrt then
        for _, x in ipairs(bossEvents) do
            local rem = x.due - T
            if rem <= 60 and rem > -1 and (not filter or filter("blizzard")) then
                n = n + 1
                local it = Item(n)
                it.key, it.id, it.kind, it.owner = x.key, nil, "blizzard", nil
                it.name, it.icon, it.color = x.name, x.icon or 134400, nil
                it.rem, it.duration, it.paused, it.queued, it.mock = rem, 60, false, rem <= 0, true
                out[n] = it
            end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return n
end

------------------------------------------------------------
-- 時鐘
------------------------------------------------------------
local function AlertAt(x)
    local when = x.entry.soundWhen or "due"
    if when == "show" then return x.due - x.lead end
    if when == "soon" then return x.due - SOON end
    return x.due
end

local function UpdateLabel()
    timeLabel:SetText(("%s / %s"):format(Plans.FormatTime(math.floor(state.t)), Plans.FormatTime(math.floor(state.length))))
    playBtn:SetText(state.playing and L["Pause"] or L["Play"])
end

local suppressSlider = false
local function SetTime(t, fromPlay)
    local prev = state.t
    state.t = math.max(0, math.min(state.length, t))
    -- 播放中跨過提醒時機就播；拖進度條（fromPlay = false）不補播
    if fromPlay and state.sound then
        for _, x in ipairs(entries) do
            local at = AlertAt(x)
            if prev < at and at <= state.t and (x.entry.sound or x.entry.tts) then
                ns.Scheduler.Alert(x.entry, x.text)
            end
        end
    end
    suppressSlider = true
    slider:SetValue(state.t)
    suppressSlider = false
    UpdateLabel()
end

local function OnUpdate(_, elapsed)
    if not state.playing then return end
    SetTime(state.t + elapsed * state.speed, true)
    if state.t >= state.length then
        state.playing = false
        UpdateLabel()
    end
end

------------------------------------------------------------
-- 版面
------------------------------------------------------------
local function ApplyDisplay()
    local d = ns.db.display
    display:Apply(d, ns.DB.Layout(), d.orientation)
    local l, r, t, b = display:GetBounds()
    local scale = math.min(1, (BOX_W - PAD * 2) / (l + r), (BOX_H - PAD * 2) / (t + b))
    if scale <= 0 then scale = 1 end
    local f = display.frame
    f:SetScale(scale)
    f:ClearAllPoints()
    -- 被縮放的框，位移也會被縮放：給「框自己的單位」（同外觀分頁的預覽）
    f:SetPoint("CENTER", clip, "CENTER", -(r - l) / 2, -(t - b) / 2)
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

    popup = W.CreateFrame("MiliUIBT_PlanPreview", parent, POP_W, POP_H)
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        state.playing = false
        display:SetRunning(false)
        if C_VoiceChat and C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
    end)
    popup:SetScript("OnUpdate", OnUpdate)

    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetFontObject(W.fontTitle)
    popup.title:SetPoint("TOP", 0, -12)

    -- 左：預覽框（卡片底＋剪裁）
    local box = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -40)
    box:SetSize(BOX_W, BOX_H)
    W.Stylize(box, W.CARD_FILL)
    clip = CreateFrame("Frame", nil, box)
    clip:SetPoint("TOPLEFT", 1, -1)
    clip:SetPoint("BOTTOMRIGHT", -1, 1)
    clip:SetClipsChildren(true)
    display = ns.Display.New(clip)
    display:SetCollector(Collect)
    display:SetFilter(function(kind) return ns.db.display.sources[kind] ~= false end)

    -- 右：控制
    local x = 14 + BOX_W + 20
    timeLabel = popup:CreateFontString(nil, "OVERLAY")
    timeLabel:SetFont(ns.Media.Font(), 26, "OUTLINE")
    timeLabel:SetPoint("TOPLEFT", x, -46)

    playBtn = W.CreateButton(popup, L["Play"], "primary", 90, 24)
    playBtn:SetPoint("TOPLEFT", x, -90)
    playBtn:SetScript("OnClick", function() PV.Toggle() end)
    local restart = W.CreateButton(popup, L["From the start"], "normal", 90, 24)
    W.FitButton(restart, 90, 24)
    restart:SetPoint("LEFT", playBtn, "RIGHT", 6, 0)
    restart:SetScript("OnClick", function() SetTime(0) end)

    local speedLbl = popup:CreateFontString(nil, "OVERLAY")
    speedLbl:SetFontObject(W.fontNormal)
    speedLbl:SetPoint("TOPLEFT", x, -130)
    speedLbl:SetText(L["Speed"])
    speedButtons = {}
    local prev
    for _, sp in ipairs({ 1, 2, 4 }) do
        local b = W.CreateButton(popup, sp .. "x", "accent-hover", 40, 20)
        b.id = sp
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("LEFT", speedLbl, "RIGHT", 10, 0) end
        speedButtons[#speedButtons + 1] = b
        prev = b
    end
    highlightSpeed = W.CreateButtonGroup(speedButtons, function(id) state.speed = id end)

    -- 進度條（拖了就跳過去，不補播中間的音效）
    slider = CreateFrame("Slider", nil, popup, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", x, -170)
    slider:SetSize(POP_W - x - 20, 10)
    W.Stylize(slider, { 0.12, 0.12, 0.12, 1 })
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(W.Accent(1))
    thumb:SetSize(8, 14)
    slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(0, 60)
    slider:SetValueStep(0.5)
    slider:SetScript("OnValueChanged", function(_, v)
        if not suppressSlider then SetTime(v, false) end
    end)

    cbSound = W.CreateCheckButton(popup, L["Play sounds and speech"], function(c) state.sound = c end)
    cbSound:SetPoint("TOPLEFT", x, -200)
    cbMRT = W.CreateCheckButton(popup, L["Show the boss's abilities (MRT)"], function(c) state.mrt = c end)
    cbMRT:SetPoint("TOPLEFT", x, -226)
    cbMine = W.CreateCheckButton(popup, L["Only reminders for my role and class"], function(c)
        state.onlyMine = c
        Rebuild()
    end)
    cbMine:SetPoint("TOPLEFT", x, -252)

    local note = popup:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("TOPLEFT", x, -284)
    note:SetWidth(POP_W - x - 20)
    note:SetJustifyH("LEFT")
    note:SetSpacing(3)
    note:SetText(L["This only plays inside this window; nothing is written to Blizzard's timeline. Reminders that follow a boss cast sit where MRT says that cast happens. The look matches the Appearance tab."])

    local close = W.CreateButton(popup, L["Okay"], "normal", 90, 22)
    close:SetPoint("BOTTOMRIGHT", -20, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
    popup:Hide()
end

function PV.Toggle()
    if state.t >= state.length then SetTime(0) end
    state.playing = not state.playing
    UpdateLabel()
end

function PV.Seek(t)
    SetTime(t, false)
end

-- pid：設定檔 ID；difficultyID：目前的難度分頁（選填）
function PV.Open(pid, difficultyID)
    local profile = Plans.Get(pid)
    if not profile then return end
    if not popup then Build() end
    state.id = pid
    state.enc = Plans.BossOf(pid)
    state.diff = difficultyID
    state.playing = false
    local boss = Plans.Boss(state.enc)
    popup.title:SetText(L["Preview: %s"]:format(((boss and boss.name) or tostring(state.enc)) .. " · " .. (profile.name or "")))
    cbSound:SetChecked(state.sound)
    cbMRT:SetChecked(state.mrt)
    cbMRT:SetShown(MD.Has(state.enc))
    cbMine:SetChecked(state.onlyMine)
    for _, b in ipairs(speedButtons) do
        if b.id == state.speed then highlightSpeed(b) end
    end
    Rebuild()
    popup:Show()
    ApplyDisplay()
    display:SetRunning(true)
    SetTime(0)
end
