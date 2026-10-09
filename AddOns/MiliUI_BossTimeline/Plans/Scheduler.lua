------------------------------------------------------------
-- 自訂時間軸的執行：開戰後照秒數把提示寫進暴雪的時間軸、到點播音效／朗讀
--
-- 寫進暴雪時間軸（AddScriptEvent）而不是只畫在自己的框上：這樣暴雪自己的時間軸、
-- DBM 的計時條（它會把 Script 來源的事件也畫成條）、本插件的重畫，三邊看到的都是同一條。
--
-- 每一條是一個 job：
--   * 在「t − lead」秒時放上時間軸、倒數 lead 秒；t 比 lead 小就開戰當下放、倒數剩下的秒數
--   * 音效／朗讀在 soundWhen 那一刻：show＝放上時間軸時、soon＝t − 5、due＝t（預設）
--   * 錨點（entry.anchor = { spell, n, offset }）：戰鬥中 Identify 認出這個技能的第 n 次施放時，
--     把 t 改成「那一次會發生的秒數 ＋ offset」，已經放上時間軸的撤掉重放、計時器重排。
--     認不出來就照原本的 t 跑（備援）。換階段時間每場會漂，錨點就是為了跟著漂。
-- 條件（職責／職業）不合的那條整條不跑（Plans.EntryApplies）。
-- 首領戰結束（ENCOUNTER_END）把還沒放的計時器取消、已經在時間軸上的撤掉。
--
-- 測試：Scheduler.Test(id) 不必開戰就照同樣的節奏跑一遍（錨點不會動，因為沒有首領事件可認），
-- Scheduler.Stop() 結束。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Scheduler = {}
local Sch = ns.Scheduler

local SOON = 5            -- 「快到時」＝到點前幾秒
local REPOST_MIN = 0.3    -- 錨點修正小於這個秒數就不動
local COUNT_MERGE = 3     -- 同一技能幾秒內連發算同一次（跟 MRTData 的合併規則一樣）

local jobs = {}           -- 這一場的 job
local running             -- { id, test, start }
local spellCount = {}     -- [spellID] = 認到第幾次
local spellLast = {}      -- [spellID] = 上一次的秒數（合併連發用）

------------------------------------------------------------
-- 音效與朗讀
------------------------------------------------------------
local ttsVoice
local function Speak(text)
    if not (C_VoiceChat and C_VoiceChat.SpeakText) or not text or text == "" then return end
    if not ttsVoice and C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        ttsVoice = S.SafeCall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType and Enum.TtsVoiceType.Standard or 0)
    end
    pcall(C_VoiceChat.SpeakText, ttsVoice or 0, text, 0, 100, true)
end

function Sch.Alert(entry, text)
    local path = entry.sound and ns.Media.Sound(entry.sound)
    if path then PlaySoundFile(path, "Master") end
    if entry.tts then Speak(text) end
end

------------------------------------------------------------
-- 放上時間軸
------------------------------------------------------------
local function Post(job, duration)
    if not C_EncounterTimeline or not C_EncounterTimeline.AddScriptEvent or duration <= 0 then return end
    local ok, id = pcall(C_EncounterTimeline.AddScriptEvent, {
        spellID          = job.spell or 0,
        iconFileID       = job.icon,
        duration         = duration,
        overrideName     = job.text,
        maxQueueDuration = 0,
        paused           = false,
    })
    if ok and id then
        job.eventID = id
        ns.Events.MarkMine(id)
    elseif not ok then
        ns.ReportError(id)
    end
end

local function Unpost(job)
    if job.eventID and C_EncounterTimeline and C_EncounterTimeline.CancelScriptEvent then
        pcall(C_EncounterTimeline.CancelScriptEvent, job.eventID)
    end
    job.eventID = nil
end

local function CancelTimers(job)
    for _, t in ipairs(job.timers) do t:Cancel() end
    wipe(job.timers)
end

local function After(job, delay, fn)
    if delay <= 0 then
        fn()
    else
        job.timers[#job.timers + 1] = C_Timer.NewTimer(delay, fn)
    end
end

-- 依 job.t 排這一條的所有計時器（第一次與錨點修正都走這裡）
local function Schedule(job)
    CancelTimers(job)
    local elapsed = GetTime() - running.start
    local untilDue = job.t - elapsed
    if untilDue <= 0 then return end
    local e = job.entry

    if job.eventID then
        -- 已經在時間軸上（錨點修正）：撤掉重放成正確的剩餘秒數
        Unpost(job)
        Post(job, untilDue)
    else
        local showIn = untilDue - job.lead
        After(job, showIn, function()
            Post(job, math.min(job.lead, job.t - (GetTime() - running.start)))
            if e.soundWhen == "show" then Sch.Alert(e, job.text) end
        end)
    end

    local when = e.soundWhen or "due"
    if when == "soon" then
        After(job, untilDue - SOON, function() Sch.Alert(e, job.text) end)
    elseif when == "due" then
        After(job, untilDue, function() Sch.Alert(e, job.text) end)
    end
end

function Sch.Stop()
    for _, job in ipairs(jobs) do
        CancelTimers(job)
        Unpost(job)
    end
    wipe(jobs)
    wipe(spellCount)
    wipe(spellLast)
    running = nil
    ns.Fire("SchedulerChanged")
end

local function Run(encounterID, plan, test)
    Sch.Stop()
    running = { id = encounterID, test = test, start = GetTime() }
    for _, e in ipairs(plan.entries) do
        if (e.t or 0) > 0 and ns.Plans.EntryApplies(e) then
            local icon, text = ns.Plans.Resolve(e)
            local job = {
                entry = e, t = e.t, lead = math.max(1, e.lead or ns.Plans.DEFAULT_LEAD),
                icon = icon, text = text, spell = e.spell, timers = {},
            }
            jobs[#jobs + 1] = job
            Schedule(job)
        end
    end
    ns.Fire("SchedulerChanged")
end

function Sch.Test(encounterID)
    local plan = ns.Plans.Get(encounterID)
    if not plan or #plan.entries == 0 then return false end
    Run(encounterID, plan, true)
    return true
end

function Sch.Running()
    return running
end

------------------------------------------------------------
-- 錨點：Identify 認出首領技能 → 算第幾次 → 修正掛在它上面的提示
------------------------------------------------------------
ns.RegisterCallback("TimelineIdentified", "scheduler", function(rec)
    if not running or running.test or not rec.ident or not rec.ident.spell then return end
    local spell = rec.ident.spell
    local rem = S.PlainNumber(S.SafeCall(C_EncounterTimeline.GetEventTimeRemaining, rec.id)) or rec.duration
    if not rem then return end
    local due = GetTime() - running.start + rem
    -- 連發（多段、分批點名）算同一次
    if spellLast[spell] and due - spellLast[spell] <= COUNT_MERGE then return end
    spellLast[spell] = due
    local n = (spellCount[spell] or 0) + 1
    spellCount[spell] = n

    for _, job in ipairs(jobs) do
        local a = job.entry.anchor
        if a and a.spell == spell and a.n == n then
            local newT = due + (a.offset or 0)
            if math.abs(newT - job.t) >= REPOST_MIN then
                job.t = newT
                Schedule(job)
            end
        end
    end
end)

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID)
    if not ns.db then return end
    if event == "ENCOUNTER_START" then
        ns.db.lastEncounter = { id = encounterID, name = S.PlainText(encounterName), difficulty = difficultyID }
        local plan = ns.Plans.Active(encounterID, difficultyID)
        if plan then
            Run(encounterID, plan, false)
        elseif running and running.test then
            Sch.Stop()     -- 測試跑到一半開戰了：收掉，免得跟真的混在一起
        end
    elseif event == "ENCOUNTER_END" then
        if running and not running.test then Sch.Stop() end
    end
end)
