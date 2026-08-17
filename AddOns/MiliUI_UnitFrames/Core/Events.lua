------------------------------------------------------------
-- 事件引擎：事件 → 刷新桶 對照集中在這裡，單一 frame 分派
-- Metro：共用 ticker（tot/focustarget 換人偵測、施法條秘密模式等）
------------------------------------------------------------
local _, ns = ...

ns.Events = {}
ns.Metro = {}

local eventFrame = CreateFrame("Frame")

------------------------------------------------------------
-- 單位事件 → 刷新桶
--
-- ⚠ 這裡的分桶就是效能本身。以前 UNIT_FACTION / UNIT_FLAGS / UNIT_MODEL_CHANGED
-- 這些通通對到 identity，而 identity 會跑**所有**元件——包含彈光環容器（強制整組
-- 重掃）和重載 3D 模型。等於進出一次戰鬥、改一次 PvP 旗標就付一次全量重畫。
--
--   unitchanged  這個框現在看的是**另一個單位**了 → 全量（只有這個桶跑所有元件）
--   info         名字／等級／分類 → 只有文字
--   reaction     陣營／旗標 → 只有顏色與狀態文字
--   portrait     模型換了 → 只有頭像
--   health / power / powertype / death   數值類，照舊
--   metro        輪詢（超出距離）
------------------------------------------------------------
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
    UNIT_NAME_UPDATE = "info",
    UNIT_LEVEL = "info",
    UNIT_CLASSIFICATION_CHANGED = "info",
    UNIT_FACTION = "reaction",
    UNIT_FLAGS = "reaction",
    -- ⚠ 這兩個語意不同，不可以合併：
    --   model    模型真的換了（變身／幻化／變形術）→ 3D 要重載
    --   portrait 頭像貼圖該更新（主要是 2D 那條路）→ 3D **不可以**重載，
    --            這個事件在戰鬥中會反覆來，每次重載就是肉眼可見的閃爍
    UNIT_MODEL_CHANGED = "model",
    UNIT_PORTRAIT_UPDATE = "portrait",
}

local function RefreshUnit(unitToken, bucket)
    local uf = ns.frames[unitToken]
    if uf and uf:IsVisible() then
        ns.Refresh(uf, bucket)
    end
end

------------------------------------------------------------
-- 每個 unit token 一顆 tracker frame
--
-- 全域 RegisterEvent 的語意是「**每一個**單位的事件都送進 Lua，我們才判斷關不關
-- 自己的事」。20 人團隊戰裡 raid1-20、寵物、名條、首領的 UNIT_HEALTH 全部都會來，
-- 而我們只在乎 11 個 token —— 九成以上是白工。RegisterUnitEvent 讓客戶端在 C 端
-- 就過濾掉。
--
-- 副 token 在**註冊期**就一起收（EUI 的做法）：玩家框同時收 player 與 vehicle、
-- 寵物框同時收 pet 與 player。這樣進出載具時 uf.unit 換掉就好，事件完全不用重註冊。
------------------------------------------------------------
local SECONDARY_TOKEN = { player = "vehicle", pet = "player" }
local trackers = {}

local function TrackerOnEvent(self, event)
    local uf = self.uf
    if not (uf and uf:IsVisible()) then return end
    local bucket = UNIT_EVENT_BUCKET[event]
    if bucket then ns.Refresh(uf, bucket) end
end

-- 單位框生出來時呼叫（SpawnUnitFrame）
function ns.Events.AttachUnit(uf)
    local token = uf.baseUnit
    local t = trackers[token]
    if t then t.uf = uf; return end
    t = CreateFrame("Frame")
    t.uf = uf
    t:SetScript("OnEvent", TrackerOnEvent)
    trackers[token] = t
    local secondary = SECONDARY_TOKEN[token]
    for event in pairs(UNIT_EVENT_BUCKET) do
        -- 麵包屑同 Reg()：ADDON_ACTION_FORBIDDEN 不會說是哪個事件
        ns.trace = "RegisterUnitEvent(" .. event .. ")"
        if secondary then
            pcall(t.RegisterUnitEvent, t, event, token, secondary)
        else
            pcall(t.RegisterUnitEvent, t, event, token)
        end
        ns.trace = nil
    end
end

-- 非單位事件（沒有 unit 參數，或參數不是「這個框在看的單位」）走全域 frame。
-- 這些都是低頻事件，留在全域沒有成本問題。
local SPECIAL = {
    PLAYER_TARGET_CHANGED = function()
        RefreshUnit("target", "unitchanged")
        RefreshUnit("targettarget", "unitchanged")
    end,
    PLAYER_FOCUS_CHANGED = function()
        RefreshUnit("focus", "unitchanged")
        RefreshUnit("focustarget", "unitchanged")
    end,
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = function()
        for i = 1, 5 do RefreshUnit("boss" .. i, "unitchanged") end
    end,
    -- 隊伍組成變了：影響的是隊長圖示與陣營色，不是「換人」。
    -- ⚠ 要刷**所有**框不是只刷玩家：隊長圖示畫在每個框上（目標、目標的目標、寵物都可能
    -- 是隊友），只刷玩家的話別人的隊長圖示會停在舊狀態，直到那個框因為別的原因重畫。
    GROUP_ROSTER_UPDATE = function()
        ns.RefreshAll("reaction")
    end,
    -- 隊長換人。GROUP_ROSTER_UPDATE **不涵蓋這個**——組成沒變、只是權杖換人時
    -- 只會發這一個事件。同樣走 reaction 桶（隊長圖示在裡面）
    PARTY_LEADER_CHANGED = function()
        ns.RefreshAll("reaction")
    end,
    PLAYER_ENTERING_WORLD = function()
        ns.RefreshAll("unitchanged")
    end,
    -- AFK／DND。不是 UNIT_ 事件，不確定 RegisterUnitEvent 吃不吃，留在全域比較保險
    PLAYER_FLAGS_CHANGED = function(unit)
        RefreshUnit(unit, "reaction")
    end,
    -- UNIT_TARGET：某單位的目標換了 → 對應的 xxtarget 框換人
    UNIT_TARGET = function(unit)
        if unit == "target" then
            RefreshUnit("targettarget", "unitchanged")
        elseif unit == "focus" then
            RefreshUnit("focustarget", "unitchanged")
        end
    end,
    -- UNIT_PET：寵物換了（arg 是主人）
    UNIT_PET = function(unit)
        if unit == "player" then RefreshUnit("pet", "unitchanged") end
    end,
}

-- 全域 frame 只負責 SPECIAL；單位事件已經全部移到 per-token tracker
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    local special = SPECIAL[event]
    if special then special(arg1) end
end)

-- 麵包屑：ADDON_ACTION_FORBIDDEN 只會告訴我們「Frame:RegisterEvent()」，
-- 不會說是哪個事件。註冊前先記下來，攔截器就能指名（見 Core/Init.lua）
local function Reg(event)
    ns.trace = "RegisterEvent(" .. tostring(event) .. ")"
    pcall(eventFrame.RegisterEvent, eventFrame, event)
    ns.trace = nil
end

function ns.Events.Start()
    -- UNIT_EVENT_BUCKET 的事件**不在這裡註冊**：它們走 ns.Events.AttachUnit 的
    -- per-token tracker。同時上全域會被送兩次。
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

-- 給 /muf debug：輪詢項目有沒有真的掛上去
function ns.Metro.Debug()
    local out = {}
    for key, e in pairs(metroEntries) do
        out[#out + 1] = ("%s(%.1fs)"):format(key, e.interval or 0)
    end
    table.sort(out)
    return out, metroTicker ~= nil
end

function ns.Metro.Unbind(uf, key)
    if uf.metroBound then uf.metroBound[key] = nil end
    ns.Metro.Remove(key)
end
