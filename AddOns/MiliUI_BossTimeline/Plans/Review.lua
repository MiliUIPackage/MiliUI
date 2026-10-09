------------------------------------------------------------
-- 戰後回顧：上一場實際的節奏 vs 自訂時間軸
--
-- 能比的是「錨在首領技能第 n 次施放」的提示：上一場紀錄裡認得出來的首領技能（Identify 認的，
-- 記在 db.recorded[id].events 的 spell 欄位）照順序數第 n 次，就是那條提示這一場「該在」的時間。
-- 跟提示存的備援時間 t 比，差太多代表沒認出來時會提早或太晚 —— 一鍵把 t 改成上一場的。
-- 沒有錨點的提示沒有東西可比（它本來就是寫死的秒數），只提供整份平移。
--
-- 每次打完會在聊天框提醒一次（差超過 NOTIFY 秒的有幾條）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Plans = ns.Plans

ns.Review = {}
local Review = ns.Review

local MERGE = 3        -- 跟 Scheduler／MRTData 同一條合併規則
local NOTIFY = 2

-- 上一場：[spell] = { 第 1 次的秒數, 第 2 次的秒數, … }
function Review.Actuals(id)
    local rec = ns.db.recorded[id]
    local out = {}
    if not rec then return out end
    local last = {}
    for _, ev in ipairs(rec.events) do       -- events 已照秒數排好
        local spell = ev.src == "blizzard" and ev.spell
        if spell and not (last[spell] and ev.t - last[spell] <= MERGE) then
            last[spell] = ev.t
            local list = out[spell] or {}
            list[#list + 1] = ev.t
            out[spell] = list
        end
    end
    return out
end

-- 每一條提示：{ entry, planned, actual（沒得比就 nil）, delta }
function Review.Rows(id)
    local plan = Plans.Get(id)
    local rows = {}
    if not plan then return rows end
    local actuals = Review.Actuals(id)
    for _, e in ipairs(plan.entries) do
        local row = { entry = e, planned = e.t }
        local a = e.anchor
        local list = a and actuals[a.spell]
        if list and list[a.n] then
            row.actual = list[a.n] + (a.offset or 0)
            row.delta = row.actual - e.t
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- 錨點提示的備援時間改成上一場的；回傳改了幾條
function Review.ApplyAnchored(id)
    if not Plans.Get(id) then return 0 end
    return Plans.Batch(id, function() return Review.ApplyAnchoredNow(id) end)
end

function Review.ApplyAnchoredNow(id)
    local n = 0
    for _, row in ipairs(Review.Rows(id)) do
        if row.delta and math.abs(row.delta) >= 0.1 then
            row.entry.t = math.max(0.1, math.floor(row.actual * 10 + 0.5) / 10)
            n = n + 1
        end
    end
    if n > 0 then
        local plan = Plans.Get(id)
        table.sort(plan.entries, function(a, b) return (a.t or 0) < (b.t or 0) end)
    end
    return n
end

-- 整份平移 delta 秒（錨點的偏移不動：錨點認得出來時本來就跟著實際施放走）
function Review.ShiftAll(id, delta)
    local plan = Plans.Get(id)
    if not plan or not delta or delta == 0 then return 0 end
    Plans.Checkpoint(id)
    for _, e in ipairs(plan.entries) do
        e.t = math.max(0.1, math.floor(((e.t or 0) + delta) * 10 + 0.5) / 10)
    end
    return #plan.entries
end

-- 打完一場：有自訂時間軸、而且錨點提示差太多就提醒
ns.RegisterCallback("RecordedChanged", "review", function(id)
    if not Plans.Get(id) then return end
    local off = 0
    for _, row in ipairs(Review.Rows(id)) do
        if row.delta and math.abs(row.delta) >= NOTIFY then off = off + 1 end
    end
    if off > 0 then
        ns.Print(L["%d anchored reminders were more than %d seconds off this pull. Open Custom timelines → Review to update them."]:format(off, NOTIFY))
    end
end)
