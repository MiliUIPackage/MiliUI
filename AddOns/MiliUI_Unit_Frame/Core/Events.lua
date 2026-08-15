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

function ns.Events.Start()
    for event in pairs(UNIT_EVENT_BUCKET) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    for event in pairs(SPECIAL) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

-- 外掛事件（元件模組用：ClassPower 等）
local externalEvents = {}
function ns.Events.Register(event, key, fn)
    ns.RegisterCallback("EVENT_" .. event, key, fn)
    if not externalEvents[event] then
        externalEvents[event] = true
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

-- 讓外掛事件也走同一顆 frame：包一層（只對有人註冊的事件 Fire，避免高頻事件白做字串串接）
local origHandler = eventFrame:GetScript("OnEvent")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    origHandler(self, event, ...)
    if externalEvents[event] then
        ns.Fire("EVENT_" .. event, ...)
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

function ns.Metro.Add(key, interval, fn)
    metroEntries[key] = { interval = interval, elapsed = 0, fn = fn }
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
