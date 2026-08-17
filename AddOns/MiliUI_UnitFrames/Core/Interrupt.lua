------------------------------------------------------------
-- 我方斷法技能是否就緒
--
-- 用途：敵方施法條在「你的斷法好了」時換色（C8）。
--
-- ⚠⚠ 回傳的是**可能是秘密的布林**，呼叫端一律不准 if 它 ——
-- 只能餵給 `C_CurveUtil.EvaluateColorValueFromBoolean` 這類 C 端函式。
-- 這是 Platynator 的 CastBar 打斷標記在用的同一套（Display/Utilities.lua）：
--
--   local dur = C_Spell.GetSpellCooldownDuration(spellID)   -- 引擎給的 duration 物件
--   Eval(dur:IsZero(), 就緒色, 原色)                          -- 取得布林但**不測試**
--
-- 「取得」跟「測試」的差別很關鍵：`dur:IsZero()` 拿到手沒問題，
-- `if dur:IsZero() then` 才會炸（Plumber 的 CooldownUtil 就是踩這個）。
------------------------------------------------------------
local _, ns = ...

ns.Interrupt = {}
local I = ns.Interrupt

local CLASS = ns.playerClass
local CSB = C_SpellBook
local GetCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration

------------------------------------------------------------
-- 各職業的斷法
--
-- 給一串候選而不是單一 ID，理由同 Core/Range.lua 的探針：專精不同 ID 不同
-- （獵人的反制射擊／脈衝彈）、有些只有某專精有（暗牧的沉默）。
-- 術士的法術鎖定在**寵物法術書**裡，所以查詢要兩個 bank 都問。
------------------------------------------------------------
local INTERRUPTS = {
    DEATHKNIGHT = { 47528 },            -- 心靈凍結
    DEMONHUNTER = { 183752 },           -- 瓦解
    DRUID       = { 106839 },           -- 迎頭痛擊
    EVOKER      = { 351338 },           -- 平息
    HUNTER      = { 147362, 187707 },   -- 反制射擊／脈衝彈（生存）
    MAGE        = { 2139 },             -- 法術反制
    MONK        = { 116705 },           -- 手刀
    PALADIN     = { 96231 },            -- 譴責
    PRIEST      = { 15487 },            -- 沉默（暗影）
    ROGUE       = { 1766 },             -- 腳踢
    SHAMAN      = { 57994 },            -- 風剪
    WARLOCK     = { 19647 },            -- 法術鎖定（寵物）
    WARRIOR     = { 6552 },             -- 拳擊
}

local spellID          -- 目前這個專精能用的那顆（nil = 沒有斷法）
local built = false

local function Known(id)
    if not CSB then return false end
    -- 兩個 bank 都問：術士／獵人的斷法在寵物法術書裡
    if CSB.IsSpellKnownOrInSpellBook then
        if CSB.IsSpellKnownOrInSpellBook(id) then return true end
        local pet = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
        if pet and CSB.IsSpellKnownOrInSpellBook(id, pet) then return true end
    end
    if CSB.IsSpellKnown and CSB.IsSpellKnown(id) then return true end
    return false
end

local function Rebuild()
    spellID = nil
    for _, id in ipairs(INTERRUPTS[CLASS] or {}) do
        if Known(id) then spellID = id; break end
    end
    built = true
end

ns.Events.Register("SPELLS_CHANGED", "interrupt_spells", Rebuild)
ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "interrupt_spec", Rebuild)
ns.Events.Register("PLAYER_TALENT_UPDATE", "interrupt_talent", Rebuild)

-- 給 /muf debug
function I.SpellID()
    if not built then Rebuild() end
    return spellID
end

------------------------------------------------------------
-- 就緒判定
--
-- 回傳兩個值：`ready`（**可能是秘密的布林**）與 `has`（**一定是明文**的「有沒有值」）。
--
-- ⚠ 為什麼要多回一個明文旗標：呼叫端要知道「這次有沒有拿到」，但如果只回一個值、
-- 讓呼叫端寫 `if ready == nil`，那就是拿秘密布林去做比較 —— 秘密布林連布林測試都
-- 不准，比較更不用說。旗標由這裡用明文算好，呼叫端只判斷旗標。
--
-- duration 物件每幀重建沒必要，但也不能快取太久（冷卻在跑）。
-- 同一幀內問幾次就只算一次 —— 施法條有多個框、每個 0.1s ticker 都會問。
------------------------------------------------------------
local cachedReady, cachedAt = nil, -1

local cachedHas = false

function I.IsReady()
    if not built then Rebuild() end
    if not (spellID and GetCooldownDuration) then return nil, false end
    local now = GetTime()
    if cachedAt == now then return cachedReady, cachedHas end
    cachedAt = now
    cachedReady, cachedHas = nil, false
    local ok, dur = pcall(GetCooldownDuration, spellID)
    if ok and dur and dur.IsZero then
        -- ⚠ 只「取得」不「測試」。回傳值直接交給呼叫端餵曲線函式
        local ok2, zero = pcall(dur.IsZero, dur)
        if ok2 then cachedReady, cachedHas = zero, true end
    end
    return cachedReady, cachedHas
end
