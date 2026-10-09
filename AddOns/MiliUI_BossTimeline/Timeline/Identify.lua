------------------------------------------------------------
-- 戰鬥中認出暴雪的首領事件是哪個技能
--
-- 首領事件的名稱、法術、圖示在戰鬥中是秘密值：畫得出來（SetText 照傳），但插件拿不到明文，
-- 所以記不進紀錄、也沒辦法「藏掉某個技能」。兩條路補明文名稱，可靠的先：
--
--   1. DBM（有開的話）：DBM 的首領模組在收到 ENCOUNTER_TIMELINE_EVENT_ADDED 的同一刻，
--      靠「這個時長是哪個技能」的規則認出事件，然後發 DBM_TimerBegin 回呼，帶著明文的
--      技能名、法術 ID、圖示與時長。我們拿「同一幀＋時長一樣」配對到自己收的那一條。
--      DBM 的回呼與我們的 ADDED 誰先誰後不一定（同一幀、各自的事件框），兩種順序都接：
--      回呼先到 → 排進 pending；事件先到 → 回呼來時回頭認領。
--   2. MRT 時間軸對時間：開戰後第幾秒「會發生」（放上時間軸那一刻的經過秒數＋剩餘秒數），
--      在 MRT 這一場難度的統計裡找 TOLERANCE 秒內最近、還沒被認領過的那一次。
--      統計值會漂，所以：最近的兩個候選（不同技能）差不到 AMBIGUOUS 秒就不猜。
--      MRT 猜的標 source = "mrt"，之後 DBM 認出不同答案時以 DBM 為準。
--
-- 結果寫在事件記錄上：rec.ident = { name, spell, icon, source = "dbm"/"mrt" }（全是明文）。
-- 用到的地方：上一場紀錄記得住名稱、一般分頁列得出名稱、「在時間軸上隱藏」某個技能。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local MD = ns.MRTData

ns.Identify = {}
local I = ns.Identify

local SAME_FRAME   = 0.05    -- 秒：DBM 回呼與事件「同一刻」的容許差
local DUR_TOL      = 0.25    -- 秒：時長的容許差（DBM 可能已經套過變異量）
local PENDING_LIFE = 1.0
local TOLERANCE    = 3.0     -- MRT 對時：最多差幾秒
local AMBIGUOUS    = 0.75    -- 前兩名差不到這麼多就不猜

local pending = {}           -- DBM 先到的
local fight                  -- { id, difficulty, start, variant, claimed = { [mrtEventIndex] = true }, events }

local function Settings()
    return ns.db and ns.db.identify
end

local function Assign(rec, ident)
    local cur = rec.ident
    -- DBM 的答案蓋過 MRT 的猜測；DBM 對 DBM 不重複蓋
    if cur and (cur.source == "dbm" or ident.source == "mrt") then return end
    local first = cur == nil
    rec.ident = ident
    -- 第一次認出來才通知錨點（Scheduler 照順序數第幾次施放，同一條不能數兩次）
    if first then ns.Fire("TimelineIdentified", rec) end
    ns.Fire("TimelineChanged")
end

------------------------------------------------------------
-- DBM
------------------------------------------------------------
local function Matches(rec, p)
    return rec.kind == "blizzard" and math.abs(rec.added - p.t) <= SAME_FRAME
        and rec.duration and p.timer and math.abs(rec.duration - p.timer) <= DUR_TOL
end

local function OnDBMTimer(_, _, msg, timer, icon, _, spellId, _, _, _, _, name)
    local s = Settings()
    if not s or not s.dbm then return end
    local text = S.PlainText(name) or S.PlainText(msg)
    timer = S.PlainNumber(timer)
    if not text or not timer then return end
    local p = {
        t = GetTime(), timer = timer,
        ident = { name = text, spell = S.PlainNumber(spellId), icon = S.PlainNumber(icon) or S.PlainText(icon), source = "dbm" },
    }
    -- 事件已經先進來了：直接認領
    for _, rec in ns.Events.Iterate() do
        if (not rec.ident or rec.ident.source ~= "dbm") and Matches(rec, p) then
            Assign(rec, p.ident)
            return
        end
    end
    local now = p.t
    for i = #pending, 1, -1 do
        if now - pending[i].t > PENDING_LIFE then table.remove(pending, i) end
    end
    pending[#pending + 1] = p
end

local dbmHooked = false
local function HookDBM()
    if dbmHooked then return end
    local dbm = _G.DBM
    if type(dbm) ~= "table" or type(dbm.RegisterCallback) ~= "function" then return end
    local ok = pcall(dbm.RegisterCallback, dbm, "DBM_TimerBegin", function(...)
        xpcall(OnDBMTimer, ns.ReportError, ...)
    end)
    dbmHooked = ok
end

function I.DBMHooked()
    return dbmHooked
end

------------------------------------------------------------
-- MRT 對時
------------------------------------------------------------
local function MatchMRT(rec)
    if not fight or not fight.events then return end
    local rem = S.PlainNumber(S.SafeCall(C_EncounterTimeline.GetEventTimeRemaining, rec.id)) or rec.duration
    if not rem then return end
    local due = GetTime() - fight.start + rem
    -- 最近的一個；再找「不同技能」裡最近的一個，兩者太接近就不猜
    local best, bestD
    for i, ev in ipairs(fight.events) do
        if not fight.claimed[i] then
            local d = math.abs(ev.t - due)
            if d <= TOLERANCE and (not bestD or d < bestD) then best, bestD = i, d end
        end
    end
    if not best then return end
    local bestSpell = fight.events[best].spell
    for i, ev in ipairs(fight.events) do
        if not fight.claimed[i] and ev.spell ~= bestSpell and math.abs(ev.t - due) - bestD < AMBIGUOUS then
            return
        end
    end
    fight.claimed[best] = true
    local ev = fight.events[best]
    if not ev.name then ev.name, ev.icon = MD.SpellInfo(ev.spell) end
    if not ev.name then return end
    Assign(rec, { name = ev.name, spell = ev.spell, icon = ev.icon, source = "mrt" })
end

ns.RegisterCallback("TimelineEventAdded", "identify", function(rec)
    if rec.kind ~= "blizzard" then return end
    -- DBM 先到的
    for i, p in ipairs(pending) do
        if Matches(rec, p) then
            table.remove(pending, i)
            Assign(rec, p.ident)
            return
        end
    end
    local s = Settings()
    if s and s.mrt then MatchMRT(rec) end
end)

------------------------------------------------------------
-- 首領戰開始／結束
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, a1, _, a3)
    if event == "ADDON_LOADED" then
        if a1 == "DBM-Core" then HookDBM() end
        return
    elseif event == "ENCOUNTER_START" then
        -- 只拿難度對得上的那份來猜：英雄的節奏拿去套傳奇，猜錯比不猜糟
        local variant
        for _, v in ipairs(MD.Variants(a1)) do
            if v.difficulty == a3 then variant = v.index break end
        end
        fight = {
            id = a1, difficulty = a3, start = GetTime(), claimed = {},
            events = variant and MD.Events(a1, variant) or nil,
        }
        wipe(pending)
    else
        fight = nil
    end
end)

ns.RegisterCallback("Init", "identify", HookDBM)
