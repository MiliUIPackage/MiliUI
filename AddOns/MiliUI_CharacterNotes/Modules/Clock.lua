------------------------------------------------------------
-- 戰鬥計時
--
-- 筆記裡的 {time:1:30} 要有個「從哪裡開始算」的基準。三種來源，優先序由高到低：
--   test       測試模式手動開始的（會一直跑到手動停掉）
--   encounter  ENCOUNTER_START（首領戰）
--   combat     PLAYER_REGEN_DISABLED（一般戰鬥，地城王道拉怪也算）
--
-- 為什麼首領戰與一般戰鬥要分開：首領戰的時間軸從開打那一刻算才有意義，而
-- PLAYER_REGEN_DISABLED 在首領戰之前就會因為拉小怪先觸發。有 encounter 就以它為準。
------------------------------------------------------------
local _, ns = ...

ns.Clock = {}
local Clock = ns.Clock

local startedAt = { test = nil, encounter = nil, combat = nil }

-- 依優先序回傳目前這一輪的來源
local function ActiveKind()
    if startedAt.test then return "test" end
    if startedAt.encounter then return "encounter" end
    if startedAt.combat then return "combat" end
    return nil
end

-- 目前計時到第幾秒；沒有在計時就回 nil
function Clock.Elapsed()
    local kind = ActiveKind()
    if not kind then return nil end
    return GetTime() - startedAt[kind], kind
end

function Clock.IsTest()
    return startedAt.test ~= nil
end

function Clock.IsRunning()
    return ActiveKind() ~= nil
end

-- "1:23"；沒在計時回 nil
function Clock.Label()
    local elapsed = Clock.Elapsed()
    if not elapsed then return nil end
    if elapsed < 0 then elapsed = 0 end
    return ("%d:%02d"):format(math.floor(elapsed / 60), math.floor(elapsed % 60))
end

-- 一律通知。訂閱者收到只是重開一個每秒的 ticker，很便宜；而「同一種來源重新開始」
-- （團滅重拉、重按測試）也必須通知，靠比對 ActiveKind 是看不出來的。
local function Set(kind, on)
    startedAt[kind] = on and GetTime() or nil
    ns.Fire("ClockChanged")
end

function Clock.StartTest() Set("test", true) end
function Clock.StopTest()  Set("test", false) end

function Clock.ToggleTest()
    if startedAt.test then Clock.StopTest() else Clock.StartTest() end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_START" then
        Set("encounter", true)
    elseif event == "ENCOUNTER_END" then
        Set("encounter", false)
    elseif event == "PLAYER_REGEN_DISABLED" then
        Set("combat", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Set("combat", false)
    end
end)

ns.RegisterCallback("Init", "clock", function()
    ev:RegisterEvent("ENCOUNTER_START")
    ev:RegisterEvent("ENCOUNTER_END")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
end)
