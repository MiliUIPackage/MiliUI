------------------------------------------------------------
-- 冒險指南：資料片 → 副本 → 首領，換成首領戰 ID（ENCOUNTER_START 的那個）
--
-- 玩家不知道首領戰 ID，以前只能先打一場讓它自動帶入。冒險指南的
-- EJ_GetEncounterInfoByIndex(index, journalInstanceID) 第 7 個回傳值就是首領戰 ID
-- （dungeonEncounterID；MRT/Functions.lua 也這樣拿），所以選單整個走冒險指南。
--
-- ⚠ EJ_GetInstanceByIndex 吃的是「目前選中的資料片」（EJ_SelectTier），那是跟暴雪冒險指南視窗
--   共用的狀態：選完一定要切回原本的（Cell 的 RaidDebuffs 也是這樣做）。
-- ⚠⚠ EJ_GetEncounterInfoByIndex 的第二個參數（副本 ID）**單獨傳沒有用**：沒先 EJ_SelectInstance
--   選中那個副本，回傳是空的（2026-10-09 實測：首領下拉整個空白）。MRT／Cell 都是先 Select 再讀，
--   照做，讀完把原本選中的副本切回去。
-- 名稱一律明文（冒險指南的資料不是秘密值）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Journal = {}
local J = ns.Journal

function J.Available()
    return EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex and true or false
end

-- 在指定資料片的狀態下跑 fn，跑完切回原本的資料片
local function WithTier(tier, fn)
    local prev = S.SafeCall(EJ_GetCurrentTier)
    pcall(EJ_SelectTier, tier)
    local ok, a, b = pcall(fn)
    if prev then pcall(EJ_SelectTier, prev) end
    if ok then return a, b end
end

-- { { value = 資料片序號, text = 名稱 }, ... }，新的在前面
function J.Tiers()
    local out = {}
    if not J.Available() then return out end
    for i = (EJ_GetNumTiers() or 0), 1, -1 do
        local name = S.PlainText(S.SafeCall(EJ_GetTierInfo, i))
        if name then out[#out + 1] = { value = i, text = name } end
    end
    return out
end

-- 這個資料片的副本：團隊副本在前、地城在後。{ { value = journalInstanceID, text, isRaid }, ... }
function J.Instances(tier)
    if not J.Available() then return {} end
    return WithTier(tier, function()
        local out, seen = {}, {}
        for _, isRaid in ipairs({ true, false }) do
            for i = 1, 100 do
                local id, name = EJ_GetInstanceByIndex(i, isRaid)
                if not id then break end
                if not seen[id] then
                    seen[id] = true
                    out[#out + 1] = { value = id, text = name, isRaid = isRaid }
                end
            end
        end
        return out
    end) or {}
end

-- 這個副本的首領：{ { value = 首領戰 ID, text = 名稱 }, ... }
-- tier：這個副本所在的資料片（選副本之前要先選對資料片，MRT 也是這個順序）
function J.Encounters(journalInstanceID, tier)
    if not J.Available() or not journalInstanceID or not EJ_SelectInstance then return {} end
    local function Read()
        local prevInst = EJ_GetCurrentInstance and S.SafeCall(EJ_GetCurrentInstance)
        pcall(EJ_SelectInstance, journalInstanceID)
        local out = {}
        for i = 1, 40 do
            local name, _, _, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i, journalInstanceID)
            if not name then break end
            if dungeonEncounterID then
                out[#out + 1] = { value = dungeonEncounterID, text = name }
            end
        end
        if prevInst and prevInst ~= 0 and prevInst ~= journalInstanceID then pcall(EJ_SelectInstance, prevInst) end
        return out
    end
    if tier then return WithTier(tier, Read) or {} end
    return Read()
end

-- 現在所在的副本（不在副本裡回 nil）
function J.CurrentInstance()
    if not (C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap) then return end
    local _, instanceType, _, _, _, _, _, mapID = GetInstanceInfo()
    if instanceType == "none" or not mapID then return end
    return S.SafeCall(C_EncounterJournal.GetInstanceForGameMap, mapID)
end

-- 這個副本在哪個資料片（找不到就 nil）
function J.TierOf(journalInstanceID)
    if not journalInstanceID then return end
    for _, t in ipairs(J.Tiers()) do
        for _, inst in ipairs(J.Instances(t.value)) do
            if inst.value == journalInstanceID then return t.value end
        end
    end
end

------------------------------------------------------------
-- 首領戰 ID → 名稱（清單上只剩 ID 的時候補名字用）
-- 整個冒險指南掃一次要切好幾個資料片，所以只在第一次查不到時掃、結果快取
------------------------------------------------------------
local names, scanned

function J.NameFor(encounterID)
    if not encounterID then return end
    if names and names[encounterID] then return names[encounterID] end
    if scanned or not J.Available() then return end
    scanned = true
    names = names or {}
    for _, t in ipairs(J.Tiers()) do
        for _, inst in ipairs(J.Instances(t.value)) do
            for _, enc in ipairs(J.Encounters(inst.value, t.value)) do
                names[enc.value] = names[enc.value] or enc.text
            end
        end
    end
    return names[encounterID]
end
