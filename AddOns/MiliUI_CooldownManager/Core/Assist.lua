------------------------------------------------------------
-- 戰鬥輔助：下一招建議的訊號來源＋醒目標示
--
--   ns.Assist.Current()          目前建議的法術（明文 spellID；沒有／沒在輪詢 ＝ nil）
--   ns.Assist.Refresh()          重判「該不該輪詢」：設定變了、進出戰鬥、換目標時叫（冪等）
--   ns.Assist.Reapply()          醒目標示照目前建議與法術索引重接（Bars 每輪排版結尾、設定變了）
--   ns.Assist.Available()        這個客戶端有沒有 C_AssistedCombat.GetNextCastSpell
--   純函式（離線可測）：ShouldPoll(state)、Normalize(v, isSecret)、Targets(entries, isAura)
--   建議換了廣播 "AssistSpellChanged"(spellID|nil)（下一招圖示 Modules/AssistIcon.lua 聽）
--
-- 訊號：暴雪自己的管理器（Blizzard_ActionBar 的 AssistedCombatManager）只在玩家開了
-- 「輔助醒目標示」那個 CVar 時才用 OnUpdate 輪詢 GetNextCastSpell 並廣播。我們不掛它、不改 CVar，
-- **自己輪詢**：0.1 秒一次的 C_Timer ticker，GetNextCastSpell(false)（pcall；回傳過 Plain，
-- 秘密值／不是正數一律當沒有）。
--   * ticker 只在「功能有開（醒目標示，或下一招圖示而且不受只在戰鬥中限制）**而且**（戰鬥中或目標可攻擊）」
--     時存在，其餘時間取消、建議清成 nil。每一拍也重判一次（目標死了、脫戰後的那一拍自己停）。
--   * 進出戰鬥（PLAYER_REGEN_*）、換目標（PLAYER_TARGET_CHANGED：按 Tab 的 secure 流程裡同步派送，
--     一律 ns.Defer）、設定變了 ⇒ Refresh。
--   * 建議變了才通知。
--   ⚠ 「沒開那個 CVar 時自己呼叫 GetNextCastSpell 有沒有值」沒有實機驗過（README 待實機驗證）；
--     設定頁說明列寫「沒有反應就到遊戲設定開啟輔助醒目標示」。
--
-- 醒目標示：建議的那一招在我們任何一條上（暴雪技能或自訂法術）就亮一圈。
--   * 找格子：ns.SpellIndex.Lookup(spellID)（索引已收 spellID 與 overrideSpellID）。
--   * 增益類的格不亮（暴雪的增益兩條、搬進群組的增益 item）：那不是要按的東西。
--   * 畫法沿用 Core/Glow.lua 的第四種發光 "assist"（G.Start／G.Stop，宿主在 overlay 底下）。
--     換建議時舊的熄、新的亮；G.Sync 不碰它，排版結尾由 Bars 叫 Reapply 重接；停放時 Glow 熄。
--   * 設定在主題層（不逐條）：theme.assist = { highlight, type, color, lines, thickness, frequency }。
------------------------------------------------------------
local _, ns = ...

ns.Assist = {}
local A = ns.Assist

local TICK = 0.1

local current            -- 目前建議（明文 spellID 或 nil）
local ticker
local inCombat = false
local lit = setmetatable({}, { __mode = "k" })   -- rec → true：正在亮的格
A.polls, A.changes, A.starts = 0, 0, 0

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
-- state = { api, highlight, icon, iconOnlyCombat, combat, attackable }
function A.ShouldPoll(s)
    if type(s) ~= "table" or not s.api then return false end
    local icon = s.icon and (s.combat or not s.iconOnlyCombat)
    if not (s.highlight or icon) then return false end
    return (s.combat or s.attackable) and true or false
end

-- API 的回傳 → 明文正整數或 nil。⚠ 秘密值連跟 nil 比都不行：先問是不是秘密值
function A.Normalize(v, isSecret)
    if isSecret and isSecret(v) then return nil end
    if type(v) ~= "number" or v <= 0 then return nil end
    return v
end

-- 索引查到的 entry 清單 → 要亮的那幾筆（同一個 rec 只算一次）
--   isAura(rec) → 真 ＝ 增益類（不亮）
function A.Targets(entries, isAura)
    local out, seen = {}, {}
    for _, e in ipairs(entries or {}) do
        local rec = type(e) == "table" and e.rec
        if rec and not seen[rec] and not rec.parked and not rec.hidden then
            seen[rec] = true
            local ok = true
            if rec.custom then
                ok = rec.kind == "spell"
            elseif isAura and isAura(rec) then
                ok = false
            end
            if ok then out[#out + 1] = e end
        end
    end
    return out
end

------------------------------------------------------------
-- 遊戲端
------------------------------------------------------------
local function Secret(v) return ns.IsSecret and ns.IsSecret(v) or false end

function A.Available()
    local ac = _G.C_AssistedCombat
    return type(ac) == "table" and type(ac.GetNextCastSpell) == "function"
end

function A.Current() return current end

local function HighlightOn()
    return ns.Setting and ns.Setting("theme", "assist.highlight") == true or false
end
A.HighlightOn = HighlightOn

local function IconCfg()
    return ns.DB and ns.DB.ConfigTable("assistIcon") or nil
end

local function IconOn()
    local cfg = IconCfg()
    return cfg ~= nil and cfg.enabled ~= false
end
A.IconOn = IconOn

-- 讀單位狀態：拋錯當否；秘密值當「是」（寧可多輪詢一下，不要漏掉）
local function Flag(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    if not ok then return false end
    if Secret(v) then return true end
    return v and true or false
end

local function Attackable()
    if not Flag(_G.UnitExists, "target") then return false end
    if not Flag(_G.UnitCanAttack, "player", "target") then return false end
    -- 死掉的目標不算（秘密值時 Flag 回真 ⇒ 這裡要明文的「死了」才排除）
    local ok, dead = pcall(_G.UnitIsDeadOrGhost or function() return false end, "target")
    if ok and not Secret(dead) and dead then return false end
    return true
end

local function State()
    local cfg = IconCfg()
    return {
        api            = A.Available(),
        highlight      = HighlightOn(),
        icon           = IconOn(),
        iconOnlyCombat = cfg ~= nil and cfg.onlyCombat ~= false,
        combat         = inCombat,
        attackable     = Attackable(),
    }
end

local function IsAuraRec(rec)
    local V = ns.Viewers
    return V ~= nil and V.AURA_KIND ~= nil and V.AURA_KIND[rec.barKey] ~= nil
end

function A.Reapply()
    local G = ns.Glow
    if not G then return end
    local want = {}
    if current and HighlightOn() and ns.SpellIndex then
        for _, e in ipairs(A.Targets(ns.SpellIndex.Lookup(current), IsAuraRec)) do
            want[e.rec] = true
        end
    end
    for rec in pairs(lit) do
        if not want[rec] then
            lit[rec] = nil
            G.Stop(rec, "assist")
        end
    end
    local c = ns.Setting("theme", "assist")
    c = type(c) == "table" and c or {}
    for rec in pairs(want) do
        lit[rec] = true
        G.Start(rec, "assist", nil, c)        -- 同樣式同尺寸已經亮著就不重畫（Glow 的簽章）
    end
end

local function Set(id)
    if id == current then return end
    current = id
    A.changes = A.changes + 1
    A.Reapply()
    if ns.Fire then ns.Fire("AssistSpellChanged", id) end
end

local function Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    Set(nil)
end

local function Poll()
    local ok, id = pcall(_G.C_AssistedCombat.GetNextCastSpell, false)
    A.polls = A.polls + 1
    Set(ok and A.Normalize(id, Secret) or nil)
end

local function Tick()
    if not A.ShouldPoll(State()) then return Stop() end
    Poll()
end

local function OnTick()
    local ok, err = xpcall(Tick, ns.ReportError)
    if not ok then
        -- 每 0.1 秒一次的錯誤不能一直刷：停掉，等下一次 Refresh 再試
        A.lastError = err
        Stop()
    end
end

function A.Refresh()
    if A.ShouldPoll(State()) then
        if not ticker then
            ticker = C_Timer.NewTicker(TICK, OnTick)
            A.starts = A.starts + 1
            OnTick()                          -- 不等第一拍
        end
    else
        Stop()
    end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function A.DebugLine()
    local n = 0
    for _ in pairs(lit) do n = n + 1 end
    local name
    if current and C_Spell and C_Spell.GetSpellName then
        local ok, s = pcall(C_Spell.GetSpellName, current)
        if ok and type(s) == "string" and not Secret(s) then name = s end
    end
    return ("  戰鬥輔助：API %s  醒目標示 %s  下一招圖示 %s  輪詢 %s（開過 %d 次、輪詢 %d 次）  目前建議 %s  亮著 %d 格  換建議 %d 次%s")
        :format(A.Available() and "有" or "|cffff5555沒有|r", HighlightOn() and "開" or "關", IconOn() and "開" or "關",
                ticker and "進行中" or "停", A.starts, A.polls,
                current and (tostring(current) .. (name and ("（" .. name .. "）") or "")) or "無",
                n, A.changes, A.lastError and "  最近錯誤（已停）" or "")
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Castbar 之後）
------------------------------------------------------------
local initialized = false
local armed = false
local function Later()
    if armed then return end
    armed = true
    ns.Defer(function()
        armed = false
        A.Refresh()
    end)
end
A.Later = Later

function A.Init()
    if initialized then return end
    initialized = true
    inCombat = InCombatLockdown() and true or false
    local E = ns.Events
    -- 戰鬥狀態自己記（PLAYER_REGEN_DISABLED 派送當下 InCombatLockdown 還不一定是真）
    E.Register("PLAYER_REGEN_DISABLED", "assist", function() inCombat = true; Later() end)
    E.Register("PLAYER_REGEN_ENABLED", "assist", function() inCombat = false; Later() end)
    E.Register("PLAYER_TARGET_CHANGED", "assist", Later)
    ns.RegisterCallback("ProfileChanged", "assist", function() Later(); A.Reapply() end)
    Later()
end
