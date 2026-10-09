------------------------------------------------------------
-- 自訂時間軸的執行：開戰後照秒數把提示寫進暴雪的時間軸
--
-- 寫進暴雪時間軸（AddScriptEvent）而不是只畫在自己的框上：這樣暴雪自己的時間軸、
-- DBM 的計時條（它會把 Script 來源的事件也畫成條）、本插件的重畫，三邊看到的都是同一條。
--
-- 每一條在「t − lead」秒時放上去、倒數 lead 秒；t 比 lead 小就開戰當下放、倒數 t 秒。
-- 首領戰結束（ENCOUNTER_END）把還沒放的計時器取消、已經在時間軸上的撤掉。
--
-- 測試：Scheduler.Test(id) 不必開戰就照同樣的節奏跑一遍（時間軸在戰鬥外也收 Script 事件），
-- Scheduler.Stop() 結束。
------------------------------------------------------------
local _, ns = ...

ns.Scheduler = {}
local Sch = ns.Scheduler

local timers = {}     -- C_Timer 物件
local liveIDs = {}    -- 已經放上時間軸的事件 ID
local running         -- { id = encounterID, test = bool }

local function Post(text, icon, spell, duration)
    if not C_EncounterTimeline or not C_EncounterTimeline.AddScriptEvent then return end
    local ok, id = pcall(C_EncounterTimeline.AddScriptEvent, {
        spellID          = spell or 0,
        iconFileID       = icon,
        duration         = duration,
        overrideName     = text,
        maxQueueDuration = 0,
        paused           = false,
    })
    if ok and id then
        liveIDs[#liveIDs + 1] = id
        ns.Events.MarkMine(id)
    elseif not ok then
        ns.ReportError(id)
    end
end

function Sch.Stop()
    for _, t in ipairs(timers) do t:Cancel() end
    wipe(timers)
    if C_EncounterTimeline and C_EncounterTimeline.CancelScriptEvent then
        for _, id in ipairs(liveIDs) do
            pcall(C_EncounterTimeline.CancelScriptEvent, id)
        end
    end
    wipe(liveIDs)
    running = nil
    ns.Fire("SchedulerChanged")
end

local function Run(encounterID, plan, test)
    Sch.Stop()
    running = { id = encounterID, test = test }
    for _, e in ipairs(plan.entries) do
        if e.enabled ~= false and (e.t or 0) > 0 then
            local icon, text = ns.Plans.Resolve(e)
            local lead = math.max(1, e.lead or ns.Plans.DEFAULT_LEAD)
            local showAt = e.t - lead
            local spell = e.spell
            if showAt <= 0 then
                Post(text, icon, spell, e.t)
            else
                timers[#timers + 1] = C_Timer.NewTimer(showAt, function()
                    Post(text, icon, spell, lead)
                end)
            end
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
-- 事件
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID)
    if not ns.db then return end
    if event == "ENCOUNTER_START" then
        ns.db.lastEncounter = { id = encounterID, name = ns.Secret.PlainText(encounterName), difficulty = difficultyID }
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
