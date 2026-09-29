------------------------------------------------------------
-- 我方斷法技能是否就緒（施法條的「斷法就緒上色」用）
--
-- ⚠⚠ 回傳的是**可能是秘密的布林**，呼叫端一律不准 if 它 —— 只能餵給
-- `C_CurveUtil.EvaluateColorValueFromBoolean` 這類 C 端函式：
--
--   local dur = C_Spell.GetSpellCooldownDuration(spellID)   -- 引擎給的 duration 物件
--   Eval(dur:IsZero(), 就緒色, 原色)                          -- 取得布林但**不測試**
--
-- 「取得」跟「測試」的差別很關鍵：`dur:IsZero()` 拿到手沒問題，`if dur:IsZero() then` 才會炸。
-- 見 .claude/notes/wow-121-duration-objects.md。
------------------------------------------------------------
local _, ns = ...

ns.Interrupt = {}
local I = ns.Interrupt

local CLASS = ns.playerClass
local CSB = C_SpellBook

-- 各職業的斷法候選（專精不同 ID 不同、有些只有某專精有）。術士的斷法在**寵物法術書**裡、
-- 跟著召喚的惡魔走，所以查詢要兩個 bank 都問
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
    WARLOCK     = { 19647, 89766, 119910, 1276467, 132409 },
    WARRIOR     = { 6552 },             -- 拳擊
}

local spellID           -- 目前這個專精能用的那顆（nil = 沒有斷法）
local built = false

local PET_BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet

local function KnownIn(id, bank)
    if not CSB then return false end
    if CSB.IsSpellKnownOrInSpellBook then
        local ok, v = pcall(CSB.IsSpellKnownOrInSpellBook, id, bank)
        return ok and not ns.IsSecret(v) and v == true
    end
    if not bank and CSB.IsSpellKnown then
        local ok, v = pcall(CSB.IsSpellKnown, id)
        return ok and not ns.IsSecret(v) and v == true
    end
    return false
end

-- 寵物法術書的命中壓過玩家法術書的：帶惡魔守衛時牠的斧頭投擲才是真的能按的那顆
local function Rebuild()
    spellID = nil
    local petHit, playerHit
    for _, id in ipairs(INTERRUPTS[CLASS] or {}) do
        if PET_BANK and KnownIn(id, PET_BANK) then
            petHit = petHit or id
        elseif not playerHit and KnownIn(id) then
            playerHit = id
        end
    end
    spellID = petHit or playerHit
    built = true
end
I.Rebuild = Rebuild

function I.SpellID()
    if not built then Rebuild() end
    return spellID
end

-- 回傳 ready（**可能是秘密布林**）, has（**明文**：這次有沒有拿到值）。
-- 同一幀問幾次只算一次（施法條的 10Hz ticker 會問）
local cachedReady, cachedHas, cachedAt = nil, false, -1

function I.IsReady()
    if not built then Rebuild() end
    local get = C_Spell and C_Spell.GetSpellCooldownDuration
    if not (spellID and get) then return nil, false end
    local now = GetTime()
    if cachedAt == now then return cachedReady, cachedHas end
    cachedAt = now
    cachedReady, cachedHas = nil, false
    local ok, dur = pcall(get, spellID)
    if ok and dur and dur.IsZero then
        local ok2, zero = pcall(dur.IsZero, dur)
        if ok2 then cachedReady, cachedHas = zero, true end
    end
    return cachedReady, cachedHas
end

-- 事件（ns.StartEngine 之後才派送）。法術書／專精／天賦／召喚的惡魔換了就重挑
local function Later() built = false end
function I.Init()
    local E = ns.Events
    E.Register("SPELLS_CHANGED", "interrupt", Later)
    E.Register("PLAYER_TALENT_UPDATE", "interrupt", Later)
    E.Register("UNIT_PET", "interrupt", Later, "player")
    ns.RegisterCallback("SpecChanged", "interrupt", Later)
end
