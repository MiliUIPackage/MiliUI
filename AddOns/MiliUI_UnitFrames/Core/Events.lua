------------------------------------------------------------
-- 事件引擎：事件 → 刷新桶 對照集中在這裡，單一 frame 分派
-- Metro：共用 ticker（tot/focustarget 換人偵測、施法條秘密模式等）
------------------------------------------------------------
local _, ns = ...

ns.Events = {}
ns.Metro = {}

local eventFrame = CreateFrame("Frame")

-- 單位事件 → 桶（arg1 = unit token，直接查 ns.frames）
local UNIT_EVENT_BUCKET = {
    UNIT_HEALTH = "health",
    UNIT_MAXHEALTH = "health",
    UNIT_HEAL_PREDICTION = "health",
    UNIT_ABSORB_AMOUNT_CHANGED = "health",
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "health",
    UNIT_POWER_UPDATE = "power",
    UNIT_MAXPOWER = "power",
    UNIT_DISPLAYPOWER = "powertype",
    UNIT_CONNECTION = "death",
    UNIT_NAME_UPDATE = "identity",
    UNIT_FACTION = "identity",
    UNIT_LEVEL = "identity",
    UNIT_FLAGS = "identity",
    UNIT_CLASSIFICATION_CHANGED = "identity",
    UNIT_MODEL_CHANGED = "identity",
    UNIT_PORTRAIT_UPDATE = "identity",
    PLAYER_FLAGS_CHANGED = "identity",
}

local function RefreshUnit(unitToken, bucket)
    local uf = ns.frames[unitToken]
    if uf and uf:IsVisible() then
        ns.Refresh(uf, bucket)
    end
end

-- 非單位事件的特殊處理
local SPECIAL = {
    PLAYER_TARGET_CHANGED = function()
        RefreshUnit("target", "identity")
        RefreshUnit("targettarget", "identity")
    end,
    PLAYER_FOCUS_CHANGED = function()
        RefreshUnit("focus", "identity")
        RefreshUnit("focustarget", "identity")
    end,
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = function()
        for i = 1, 5 do RefreshUnit("boss" .. i, "identity") end
    end,
    GROUP_ROSTER_UPDATE = function()
        RefreshUnit("player", "identity")
    end,
    PLAYER_ENTERING_WORLD = function()
        ns.RefreshAll("identity")
    end,
    -- UNIT_TARGET：某單位的目標換了 → 對應的 xxtarget 框刷新
    UNIT_TARGET = function(unit)
        if unit == "target" then
            RefreshUnit("targettarget", "identity")
        elseif unit == "focus" then
            RefreshUnit("focustarget", "identity")
        end
    end,
    -- UNIT_PET：寵物換了（arg 是主人）
    UNIT_PET = function(unit)
        if unit == "player" then RefreshUnit("pet", "identity") end
    end,
}

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    local special = SPECIAL[event]
    if special then
        special(arg1)
        return
    end
    local bucket = UNIT_EVENT_BUCKET[event]
    if bucket and arg1 then
        RefreshUnit(arg1, bucket)
    end
end)

-- 麵包屑：ADDON_ACTION_FORBIDDEN 只會告訴我們「Frame:RegisterEvent()」，
-- 不會說是哪個事件。註冊前先記下來，攔截器就能指名（見 Core/Init.lua）
local function Reg(event)
    ns.trace = "RegisterEvent(" .. tostring(event) .. ")"
    pcall(eventFrame.RegisterEvent, eventFrame, event)
    ns.trace = nil
end

function ns.Events.Start()
    for event in pairs(UNIT_EVENT_BUCKET) do Reg(event) end
    for event in pairs(SPECIAL) do Reg(event) end
end

------------------------------------------------------------
-- 外掛事件（元件模組用：ClassPower 等）
------------------------------------------------------------
-- callback key 查表算一次就好。原本每次派發都現串 "EVENT_" .. event，
-- 而 UNIT_AURA 這種在團隊戰是每秒數百次的量。
local FIRE_KEY = setmetatable({}, { __index = function(t, event)
    local k = "EVENT_" .. event
    t[event] = k
    return k
end })

local externalEvents = {}      -- 註冊在全域 eventFrame 上的
local unitScoped = {}          -- 已經改走 RegisterUnitEvent 的（不可再上全域，會雙送）
local unitFrames = {}          -- unit token → frame

-- 只關心特定單位的事件走這裡：RegisterUnitEvent 讓客戶端在 C 端就過濾掉，
-- 不相干的單位根本不會進 Lua。全域 RegisterEvent 是「每個單位都送進來、
-- 我們才判斷關不關自己的事」，團隊戰差距很大。
local function UnitReg(event, token)
    local f = unitFrames[token]
    if not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(_, ev, ...)
            ns.Fire(FIRE_KEY[ev], ...)
        end)
        unitFrames[token] = f
    end
    ns.trace = "RegisterUnitEvent(" .. tostring(event) .. ")"
    pcall(f.RegisterUnitEvent, f, event, token)
    ns.trace = nil
end

-- unitToken 給了就走 C 端過濾。⚠ 同一個事件不能同時出現在 UNIT_EVENT_BUCKET
-- （全域）與這裡的 unit 範圍註冊，否則會被送兩次。
function ns.Events.Register(event, key, fn, unitToken)
    ns.RegisterCallback(FIRE_KEY[event], key, fn)
    if unitToken then
        if not unitScoped[event] then
            unitScoped[event] = true
            UnitReg(event, unitToken)
        end
    elseif not externalEvents[event] then
        externalEvents[event] = true
        Reg(event)
    end
end

-- 讓外掛事件也走同一顆 frame：包一層（只對有人註冊的事件 Fire）
local origHandler = eventFrame:GetScript("OnEvent")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    origHandler(self, event, ...)
    if externalEvents[event] then
        ns.Fire(FIRE_KEY[event], ...)
    end
end)

------------------------------------------------------------
-- Metro：共用 0.1s ticker，依 key 節流
------------------------------------------------------------
local metroEntries = {}
local metroTicker

local function MetroTick()
    for _, entry in pairs(metroEntries) do
        entry.elapsed = entry.elapsed + 0.1
        if entry.elapsed >= entry.interval then
            entry.elapsed = 0
            entry.fn()
        end
    end
end

-- ⚠ 既有項目只更新欄位、不重置 elapsed：Add 會被重複呼叫（Bind 每次 OnShow
-- 都會叫一次），每次都歸零的話間隔長的項目永遠等不到觸發
function ns.Metro.Add(key, interval, fn)
    local e = metroEntries[key]
    if e then
        e.interval, e.fn = interval, fn
    else
        metroEntries[key] = { interval = interval, elapsed = 0, fn = fn }
    end
    if not metroTicker then
        metroTicker = C_Timer.NewTicker(0.1, MetroTick)
    end
end

function ns.Metro.Remove(key)
    metroEntries[key] = nil
    if metroTicker and not next(metroEntries) then
        metroTicker:Cancel()
        metroTicker = nil
    end
end

-- 把一個輪詢項目綁在框架的可見度上：框藏起來就卸下，整張表空了 ticker 才停得掉。
-- 沒有這層的話一個永久項目就會讓 0.1 秒的 ticker 從登入轉到登出。
-- OnShow/OnHide 只掛一次（Build 是冪等的，會被重跑）。
function ns.Metro.Bind(uf, key, interval, fn)
    local bound = uf.metroBound
    if not bound then bound = {}; uf.metroBound = bound end
    local function sync()
        if uf:IsShown() then
            ns.Metro.Add(key, interval, fn)
        else
            ns.Metro.Remove(key)
        end
    end
    bound[key] = sync
    if not uf.metroHooked then
        uf.metroHooked = true
        local function syncAll()
            for _, s in pairs(uf.metroBound) do s() end
        end
        uf:HookScript("OnShow", syncAll)
        uf:HookScript("OnHide", syncAll)
    end
    sync()
end

function ns.Metro.Unbind(uf, key)
    if uf.metroBound then uf.metroBound[key] = nil end
    ns.Metro.Remove(key)
end
