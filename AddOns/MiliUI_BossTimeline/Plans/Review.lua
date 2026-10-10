------------------------------------------------------------
-- 戰後回顧：上一場實際的節奏 vs 自訂時間軸
--
-- 能比的是「錨在首領技能第 n 次施放」的提示：上一場紀錄裡認得出來的首領技能（Identify 認的，
-- 記在 db.recorded[id].events 的 spell 欄位）照順序數第 n 次，就是那條提示這一場「該在」的時間。
-- 跟提示存的備援時間 t 比，差太多代表沒認出來時會提早或太晚 —— 一鍵把 t 改成上一場的。
-- 沒有錨點的提示沒有東西可比（它本來就是寫死的秒數），只提供整份平移。
-- 「每一次」的提示整個跳過：它沒有備援秒數，每一次都跟著實際施放走，沒有東西可改。
--
-- 每次打完會在聊天框提醒一次（這隻首領生效中的設定檔裡，差超過 NOTIFY 秒的有幾條）。
-- 紀錄是照首領存的（encounterID），提示是照設定檔存的（profileID）：Rows 吃 profileID、自己找首領。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Plans = ns.Plans

ns.Review = {}
local Review = ns.Review

local MERGE = 3        -- 跟 Scheduler／MRTData 同一條合併規則
local NOTIFY = 2

-- 上一場：[spell] = { 第 1 次的秒數, 第 2 次的秒數, … }（id＝encounterID）
function Review.Actuals(id)
    local rec = id and ns.db.recorded[id]
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

-- 每一條提示：{ entry, planned, actual（沒得比就 nil）, delta }；「每一次」的不列
local function RowsFor(entries, actuals)
    local rows = {}
    for _, e in ipairs(entries) do
        if not Plans.IsEvery(e) then
            local row = { entry = e, planned = e.t }
            local a = e.anchor
            local list = a and actuals[a.spell]
            if list and list[a.n] then
                row.actual = list[a.n] + (a.offset or 0)
                row.delta = row.actual - e.t
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- pid：設定檔 ID
function Review.Rows(pid)
    local profile = Plans.Get(pid)
    if not profile then return {} end
    return RowsFor(profile.entries, Review.Actuals(Plans.BossOf(pid)))
end

-- 錨點提示的備援時間改成上一場的；回傳改了幾條
function Review.ApplyAnchored(pid)
    if not Plans.Get(pid) then return 0 end
    return Plans.Batch(pid, function() return Review.ApplyAnchoredNow(pid) end)
end

function Review.ApplyAnchoredNow(pid)
    local n = 0
    for _, row in ipairs(Review.Rows(pid)) do
        if row.delta and math.abs(row.delta) >= 0.1 then
            row.entry.t = math.max(0.1, math.floor(row.actual * 10 + 0.5) / 10)
            n = n + 1
        end
    end
    if n > 0 then Plans.SortEntries(Plans.Get(pid)) end
    return n
end

-- 整份平移 delta 秒（錨點的偏移不動：錨點認得出來時本來就跟著實際施放走）
function Review.ShiftAll(pid, delta)
    local profile = Plans.Get(pid)
    if not profile or not delta or delta == 0 then return 0 end
    Plans.Checkpoint(pid)
    local n = 0
    for _, e in ipairs(profile.entries) do
        if not Plans.IsEvery(e) then       -- 「每一次」的沒有秒數可平移
            e.t = math.max(0.1, math.floor(((e.t or 0) + delta) * 10 + 0.5) / 10)
            n = n + 1
        end
    end
    return n
end

-- 打完一場：生效中的設定檔裡、錨點提示差太多就提醒（id＝encounterID）
ns.RegisterCallback("RecordedChanged", "review", function(id)
    if not Plans.Boss(id) then return end
    local actuals = Review.Actuals(id)
    local off = 0
    for _, p in ipairs(Plans.Profiles(id)) do
        if p.active then
            for _, row in ipairs(RowsFor(p.entries, actuals)) do
                if row.delta and math.abs(row.delta) >= NOTIFY then off = off + 1 end
            end
        end
    end
    if off > 0 then
        ns.Print(L["%d anchored reminders were more than %d seconds off this pull. Open Custom timelines → Review to update them."]:format(off, NOTIFY))
    end
end)
