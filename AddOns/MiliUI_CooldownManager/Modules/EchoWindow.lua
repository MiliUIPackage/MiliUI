------------------------------------------------------------
-- 事件視窗：施放後「N 秒後才發生」的效果，畫在那個技能的格子上（目前只有鮮血死騎的沸點）
--
-- 沸點（1265982）：心臟打擊有機率讓下一發血液沸騰（50842）強化，強化的那發 3 秒後回聲再炸一次。
-- 這段 3 秒不是光環、冷卻管理器也沒有它，只能自己算（照 YUI_Halo 的做法）：
--   開始：SPELL_UPDATE_COOLDOWN 的參數帶 1265982（明文）⇒ 開一段 3 秒
--   接續：視窗還沒結束時血液沸騰的觸發發光又亮（又觸發了一次強化）⇒ 這段結束時接著跑下一段
--   清空：死亡、讀取畫面
-- 畫法：血液沸騰那一格（暴雪的冷卻格或自訂法術，SpellIndex 查得到的）overlay 上面一條頂端的倒數條＋秒數，
-- 不新增格子、不重排版面（戰鬥中照樣能畫，全是自己的框）。
--
-- ⚠ 待實機驗證：戰鬥中 SPELL_UPDATE_COOLDOWN 帶的 1265982 是不是明文。探針（/mcdm echo）一直在記，
--   印出明文／秘密參數的次數與最近的事件；秘密的話這個功能等於不會動（只會在脫戰時亮）。
--
--   EW.DEFS                         每一種事件視窗的資料（專精、要畫的法術、觸發法術、秒數）
--   EW.New()                        一份狀態
--   EW.OnTrigger(st, def, now)      觸發事件 → true ＝ 狀態變了
--   EW.OnGlow(st, show)             那個法術的觸發發光開／關（只看亮起來的那一下）
--   EW.Tick(st, def, now)           時間到了沒：到了 ⇒ 接續或結束；回 true ＝ 狀態變了
--   EW.Reset(st)
-- 純邏輯（時間從參數進來），離線測得到；畫面與事件在檔尾。
------------------------------------------------------------
local _, ns = ...

ns.EchoWindow = {}
local EW = ns.EchoWindow

EW.DEFS = {
    { key = "boilingPoint", class = "DEATHKNIGHT", spec = 250, spell = 50842, triggers = { 1265982 }, secs = 3 },
}

-- 同一次觸發，引擎有時連派兩次事件／回聲剛好在接續的那一刻又報一次：這麼近的不算新的一次
local DUP_WINDOW, ECHO_CONFIRM = 0.05, 0.25

function EW.New()
    return { active = false, startAt = 0, endAt = 0, pending = false, glowOn = false, continuedAt = nil }
end

local function Start(st, def, at, continued)
    st.active = true
    st.startAt, st.endAt = at, at + def.secs
    st.pending = false
    st.continuedAt = continued and at or nil
end

function EW.Reset(st)
    st.active, st.startAt, st.endAt = false, 0, 0
    st.pending, st.glowOn, st.continuedAt = false, false, nil
end

function EW.IsTrigger(def, spellID, baseSpellID)
    for _, id in ipairs(def.triggers) do
        if spellID == id or baseSpellID == id then return true end
    end
    return false
end

function EW.OnTrigger(st, def, now)
    if st.continuedAt and now - st.continuedAt <= ECHO_CONFIRM then return false end
    if st.active and now - st.startAt < DUP_WINDOW then return false end
    Start(st, def, now, false)
    return true
end

-- 亮起來的那一下（重複的 SHOW 不重複排）：視窗進行中 ⇒ 這段結束接下一段
function EW.OnGlow(st, show)
    local rising = show and not st.glowOn
    st.glowOn = show and true or false
    if rising and st.active then st.pending = true end
end

function EW.Tick(st, def, now)
    if not st.active or now < st.endAt then return false end
    local nextStart = st.endAt
    if st.pending and now < nextStart + def.secs then
        Start(st, def, nextStart, true)
        return true
    end
    EW.Reset(st)
    st.glowOn = false
    return true
end

function EW.Remaining(st, now)
    if not st.active then return 0 end
    local r = st.endAt - now
    return r > 0 and r or 0
end

------------------------------------------------------------
-- 探針：觸發事件的參數是明文還是秘密（記數＋最近 30 行，/mcdm echo 印）
------------------------------------------------------------
local PROBE_MAX = 30
EW.probe = { lines = {}, plain = { combat = 0, idle = 0 }, secret = { combat = 0, idle = 0 }, glow = 0 }

local function InCombat()
    local f = _G.InCombatLockdown
    return f and f() and true or false
end

local function ProbeLine(text)
    local p = EW.probe
    local t = _G.GetTime and _G.GetTime() or 0
    p.lines[#p.lines + 1] = ("%.2f %s %s"):format(t, InCombat() and "戰鬥" or "脫戰", text)
    while #p.lines > PROBE_MAX do table.remove(p.lines, 1) end
end
EW.ProbeLine = ProbeLine

------------------------------------------------------------
-- 畫面：格子 overlay 上的倒數條＋秒數
------------------------------------------------------------
local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local BAR_H = 3
local states, shown = {}, {}         -- states[key] ＝ 狀態；shown[rec] ＝ 正在畫的 fx 框
local ticker

local function Fx(rec)
    local ov = rec.overlay
    if not ov then return nil end
    local fx = rec.echoFx
    if not fx then
        fx = CreateFrame("Frame", nil, ov)
        fx:SetAllPoints(ov)
        local bg = fx:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0, 0, 0, 0.8)
        bg:SetPoint("TOPLEFT", fx, "TOPLEFT", 0, 0)
        bg:SetPoint("TOPRIGHT", fx, "TOPRIGHT", 0, 0)
        bg:SetHeight(BAR_H)
        local bar = fx:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(WHITE)
        bar:SetVertexColor(1, 1, 1, 1)
        bar:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
        bar:SetHeight(BAR_H)
        fx.bg, fx.bar = bg, bar
        fx.text = fx:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(fx.text, 11, "OUTLINE")
        fx.text:SetPoint("TOP", bg, "BOTTOM", 0, -1)
        fx.text:SetTextColor(1, 1, 1, 1)
        fx:Hide()
        rec.echoFx = fx
    end
    fx:SetFrameLevel(ov:GetFrameLevel() + 4)
    return fx
end

local function Paint(fx, rem, secs)
    local w = fx:GetWidth() or 0
    local frac = secs > 0 and rem / secs or 0
    if w > 0 and frac > 0 then
        fx.bar:SetWidth(w * frac)
        fx.bar:Show()
    else
        fx.bar:Hide()
    end
    fx.text:SetFormattedText("%.1f", rem)
end

local function Render()
    local now = GetTime()
    local want = {}
    local SI = ns.SpellIndex
    for _, def in ipairs(EW.DEFS) do
        local st = states[def.key]
        if st and st.active and SI and SI.Lookup then
            local rem = EW.Remaining(st, now)
            for _, e in ipairs(SI.Lookup(def.spell)) do
                local fx = e.rec and Fx(e.rec)
                if fx then
                    want[e.rec] = fx
                    Paint(fx, rem, def.secs)
                    fx:Show()
                end
            end
        end
    end
    for rec, fx in pairs(shown) do
        if not want[rec] then fx:Hide() end
    end
    shown = want
end

local function AnyActive()
    for _, st in pairs(states) do if st.active then return true end end
    return false
end

local function StopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

local function OnTick()
    local now = GetTime()
    for _, def in ipairs(EW.DEFS) do
        local st = states[def.key]
        if st and EW.Tick(st, def, now) then
            ProbeLine(st.active and ("接續下一段（回聲）%s"):format(def.key) or ("結束 %s"):format(def.key))
        end
    end
    Render()
    if not AnyActive() then StopTicker() end
end

local function EnsureTicker()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(0.05, function() xpcall(OnTick, ns.ReportError) end)
end

-- 這個專精的事件視窗（SPELL_UPDATE_COOLDOWN 很頻繁：照專精快取，不每次配新表）
local specDefs, specDefsFor = {}, false
local function DefsForSpec()
    if specDefsFor ~= ns.specID then
        specDefs, specDefsFor = {}, ns.specID
        for _, def in ipairs(EW.DEFS) do
            if def.class == ns.playerClass and def.spec == ns.specID then specDefs[#specDefs + 1] = def end
        end
    end
    return specDefs
end

local IsSecret = function(v) return ns.IsSecret and ns.IsSecret(v) end

local function OnCooldown(spellID, baseSpellID)
    if IsSecret(spellID) or IsSecret(baseSpellID) then
        local p = EW.probe.secret
        if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
        return
    end
    local now = GetTime()
    for _, def in ipairs(DefsForSpec()) do
        if EW.IsTrigger(def, spellID, baseSpellID) then
            local p = EW.probe.plain
            if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
            states[def.key] = states[def.key] or EW.New()
            local started = EW.OnTrigger(states[def.key], def, now)
            ProbeLine(("觸發 %s spellID=%s base=%s%s"):format(def.key, tostring(spellID), tostring(baseSpellID),
                started and "" or "（重複，略過）"))
            if started then
                EnsureTicker()
                Render()
            end
        end
    end
end

local function OnOverlay(show, id)
    if IsSecret(id) or type(id) ~= "number" then return end
    for _, def in ipairs(DefsForSpec()) do
        if id == def.spell then
            local st = states[def.key] or EW.New()
            states[def.key] = st
            local wasPending = st.pending
            EW.OnGlow(st, show)
            if show then EW.probe.glow = EW.probe.glow + 1 end
            ProbeLine(("發光%s %d%s"):format(show and "亮" or "熄", id, (st.pending and not wasPending) and "（排下一段）" or ""))
        end
    end
end

local function ResetAll(why)
    for _, st in pairs(states) do
        if st.active then ProbeLine("清空（" .. why .. "）") end
        EW.Reset(st)
    end
    StopTicker()
    Render()
end

-- 只有用得到的職業才聽（SPELL_UPDATE_COOLDOWN 很頻繁）；專精不對時處理器第一行就走
local function WantClass()
    for _, def in ipairs(EW.DEFS) do
        if def.class == ns.playerClass then return true end
    end
    return false
end

if ns.Events and ns.Events.Register and WantClass() then
    local E = ns.Events
    E.Register("SPELL_UPDATE_COOLDOWN", "echo_window", function(spellID, baseSpellID)
        if ns.released then return end
        OnCooldown(spellID, baseSpellID)
    end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "echo_window", function(id) OnOverlay(true, id) end)
    E.Register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "echo_window", function(id) OnOverlay(false, id) end)
    E.Register("PLAYER_DEAD", "echo_window", function() ResetAll("死亡") end)
    E.Register("PLAYER_ENTERING_WORLD", "echo_window", function() ResetAll("讀取畫面") end)
end
if ns.RegisterCallback then
    ns.RegisterCallback("SpecChanged", "echo_window", function() ResetAll("換專精") end)
end

-- /mcdm echo：探針結果（字串不進語系檔，開發用）
function EW.ProbeReport()
    local p = EW.probe
    local out = {
        ("[米利冷卻 echo] 職業=%s 專精=%s 這個專精的事件視窗=%d 個"):format(tostring(ns.playerClass), tostring(ns.specID), #DefsForSpec()),
        ("  觸發參數是明文：戰鬥中 %d 次、脫戰 %d 次"):format(p.plain.combat, p.plain.idle),
        ("  SPELL_UPDATE_COOLDOWN 參數是秘密值（不分法術）：戰鬥中 %d 次、脫戰 %d 次"):format(p.secret.combat, p.secret.idle),
        ("  血液沸騰觸發發光亮起：%d 次"):format(p.glow),
    }
    if p.plain.combat == 0 and p.secret.combat > 0 then
        out[#out + 1] = "  ⚠ 戰鬥中沒看到明文的觸發、但有秘密參數 ⇒ 觸發參數戰鬥中可能是秘密值"
    end
    out[#out + 1] = "  最近的事件："
    if #p.lines == 0 then out[#out + 1] = "    （還沒有）" end
    for _, line in ipairs(p.lines) do out[#out + 1] = "    " .. line end
    if ns.Diag and ns.Diag.SaveEcho then ns.Diag.SaveEcho(out) end
    return out
end
