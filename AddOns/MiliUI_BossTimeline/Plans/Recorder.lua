------------------------------------------------------------
-- 記下這一場時間軸上出現過什麼（給編輯器當唯讀參考）
--
-- 每個事件記「開戰後第幾秒會發生」＝ 放上時間軸那一刻的經過秒數 ＋ 當時的剩餘秒數。
--
-- ⚠ 暴雪的首領事件名稱、圖示在戰鬥中是秘密值：**存不進 SavedVariables、也不能拿來比**。
--   所以首領事件只留下「第幾秒、倒數多久」，編輯器上顯示成鎖住的「暴雪事件」——
--   除非 Identify.lua 認出了是哪個技能（DBM 回呼或 MRT 對時），那就連名稱一起記；
--   其他插件加的（Script 來源）是明文，名稱與是哪個插件都記得住。
--   自己的自訂時間軸不記（那本來就在編輯器裡）。
--
-- 只留每隻首領最近一場；一場最多記 MAX_EVENTS 條。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

local MAX_EVENTS = 300

local session    -- { id, name, difficulty, start, list = { { entry =, rec = } } }

local function Round1(x)
    return math.floor(x * 10 + 0.5) / 10
end

ns.RegisterCallback("TimelineEventAdded", "recorder", function(rec)
    if not session or rec.kind == "mine" or rec.kind == "editmode" then return end
    if #session.list >= MAX_EVENTS then return end
    local rem = S.PlainNumber(S.SafeCall(C_EncounterTimeline.GetEventTimeRemaining, rec.id)) or rec.duration
    if not rem then return end
    local entry = {
        t   = Round1(GetTime() - session.start + rem),
        d   = rec.duration and Round1(rec.duration) or nil,
        src = rec.kind,
    }
    if rec.kind ~= "blizzard" then
        entry.text = S.PlainText(rec.name)
    end
    -- 插件歸屬可能晚一點才認領到，結束時再從 rec 抄一次
    session.list[#session.list + 1] = { entry = entry, rec = rec }
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, _, success)
    if not ns.db then return end
    if event == "ENCOUNTER_START" then
        session = { id = encounterID, name = S.PlainText(encounterName), difficulty = difficultyID, start = GetTime(), list = {} }
    elseif event == "ENCOUNTER_END" and session and session.id == encounterID then
        if #session.list > 0 then
            local events = {}
            for _, item in ipairs(session.list) do
                -- 自己的提示可能比 MarkMine 早一步進來（事件同步派送），收尾時以 rec 的最終歸屬為準
                if item.rec.kind ~= "mine" then
                    local e, rec = item.entry, item.rec
                    e.owner = rec.owner
                    -- 戰鬥中認出來的暴雪技能（DBM／MRT）：名稱與法術是明文，記得住
                    if rec.ident then
                        e.text, e.spell, e.icon, e.ident = rec.ident.name, rec.ident.spell, rec.ident.icon, rec.ident.source
                    end
                    events[#events + 1] = e
                end
            end
            if #events > 0 then
                table.sort(events, function(a, b) return a.t < b.t end)
                ns.db.recorded[encounterID] = {
                    name       = session.name,
                    difficulty = session.difficulty,
                    kill       = success == 1,
                    duration   = Round1(GetTime() - session.start),
                    when       = time(),
                    events     = events,
                }
                ns.Fire("RecordedChanged", encounterID)
            end
        end
        session = nil
    end
end)
