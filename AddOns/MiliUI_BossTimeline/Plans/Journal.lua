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
            local name, _, journalEncounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i, journalInstanceID)
            if not name then break end
            if dungeonEncounterID then
                out[#out + 1] = { value = dungeonEncounterID, text = name, journal = journalEncounterID }
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
-- 自訂時間軸頁的側欄：只讀「最新資料片」＋「現在所在的副本」，結果整個登入期間快取
--
-- ⚠ 不准走 NameFor 那種整本掃描（切遍所有資料片，會卡）。舊資料片的首領一律落在側欄的
--   「其他首領」（存檔裡有、但不在這幾個副本裡的）。
------------------------------------------------------------
local sidebarInstances
local encounterCache = {}

-- { { value = journalInstanceID, text, isRaid, tier }, ... }：最新資料片的團隊副本在前、地城在後
-- （現在所在的副本不在裡面時由呼叫端補，見 J.CurrentInstanceInfo）
function J.SidebarInstances()
    if sidebarInstances then return sidebarInstances end
    local out = {}
    if not J.Available() then return out end
    local newest = EJ_GetNumTiers and EJ_GetNumTiers()
    if newest and newest > 0 then
        for _, inst in ipairs(J.Instances(newest)) do
            out[#out + 1] = { value = inst.value, text = inst.text, isRaid = inst.isRaid, tier = newest }
        end
    end
    -- 空的不快取：冒險指南資料還沒準備好時第一次可能是空的
    if #out > 0 then sidebarInstances = out end
    return out
end

-- 現在所在的副本（冒險指南 ID、名稱、是不是團隊副本）；不在副本裡或冒險指南沒收就 nil
function J.CurrentInstanceInfo()
    local id = J.CurrentInstance()
    if not id then return end
    local name = EJ_GetInstanceInfo and S.PlainText(S.SafeCall(EJ_GetInstanceInfo, id))
    local _, instanceType, difficultyID = GetInstanceInfo()
    return { value = id, text = name or tostring(id), isRaid = instanceType == "raid", difficulty = difficultyID }
end

-- 同 J.Encounters，但每個副本只讀一次（側欄每次重畫都要問）
function J.EncountersCached(journalInstanceID, tier)
    if not journalInstanceID then return {} end
    local hit = encounterCache[journalInstanceID]
    if hit then return hit end
    local list = J.Encounters(journalInstanceID, tier)
    -- 空的不快取：冒險指南資料還沒準備好時第一次可能是空的
    if #list > 0 then encounterCache[journalInstanceID] = list end
    return list
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

------------------------------------------------------------
-- 首領戰 ID → 冒險指南裡第一隻首領的模型（「自訂時間軸」頁的頭像）
--
-- ⚠ 不走 NameFor 那種整本掃描（切遍所有資料片，第一次會卡一下）。只找：
--   1. 呼叫端已經知道的冒險指南首領 ID（新增首領時從選單記下來、或上次找到後存進時間軸）
--   2. 現在所在的副本（一個副本，便宜）
--   3. 最新資料片的副本（當季要打的幾乎都在這）
-- 都找不到就算了（頭像退回骷髏），同一次登入不再重找。
-- 回傳 displayInfo, journalEncounterID；查不到 nil
------------------------------------------------------------
local art, missed = {}, {}

local function FindIn(journalInstanceID, encounterID, tier)
    for _, enc in ipairs(J.Encounters(journalInstanceID, tier)) do
        if enc.value == encounterID then return enc.journal end
    end
end

local function FindJournalEncounter(encounterID)
    local cur = J.CurrentInstance()
    local hit = cur and FindIn(cur, encounterID)
    if hit then return hit end
    local newest = EJ_GetNumTiers and EJ_GetNumTiers()
    if not newest or newest < 1 then return end
    for _, inst in ipairs(J.Instances(newest)) do
        hit = FindIn(inst.value, encounterID, newest)
        if hit then return hit end
    end
end

function J.BossArt(encounterID, journalEncounterID)
    if not encounterID or not EJ_GetCreatureInfo or not J.Available() then return end
    local hit = art[encounterID]
    if hit then return hit.display, hit.journal end
    if missed[encounterID] then return end
    local jEnc = journalEncounterID or FindJournalEncounter(encounterID)
    local display
    if jEnc then
        display = select(4, S.SafeCall(EJ_GetCreatureInfo, 1, jEnc))
        display = type(display) == "number" and display > 0 and display or nil
    end
    if not display then
        missed[encounterID] = true
        return
    end
    art[encounterID] = { display = display, journal = jEnc }
    return display, jEnc
end

------------------------------------------------------------
-- 首領戰 ID → 冒險指南的位置（首領、副本、資料片）
--
-- 先找現在所在的副本、再找最新資料片，最後才整本掃（切遍所有資料片，會卡一下）——
-- 只有 /mbt ej 這種玩家自己叫的檢查會走到整本掃，結果整個登入期間快取。
-- 回傳 { journal = journalEncounterID, instance = journalInstanceID, tier, name }；查不到 nil
------------------------------------------------------------
local located = {}

local function ScanInstance(journalInstanceID, encounterID, tier)
    for _, enc in ipairs(J.Encounters(journalInstanceID, tier)) do
        if enc.value == encounterID then
            return { journal = enc.journal, instance = journalInstanceID, tier = tier, name = enc.text }
        end
    end
end

function J.Locate(encounterID)
    if not encounterID or not J.Available() then return end
    local hit = located[encounterID]
    if hit ~= nil then return hit or nil end
    local cur = J.CurrentInstance()
    hit = cur and ScanInstance(cur, encounterID)
    if not hit then
        for _, t in ipairs(J.Tiers()) do
            for _, inst in ipairs(J.Instances(t.value)) do
                hit = ScanInstance(inst.value, encounterID, t.value)
                if hit then break end
            end
            if hit then break end
        end
    end
    located[encounterID] = hit or false
    return hit
end

------------------------------------------------------------
-- 冒險指南「技能」頁的段落樹（給首領技能分組用，見 JournalAbilities.lua）
--
-- EJ_GetEncounterInfo(journalEncounterID) 第 4 個回傳＝第一個段落；之後
-- C_EncounterJournal.GetSectionInfo(sectionID) 的 firstChildSectionID／siblingSectionID 走完整棵樹。
-- 最上層開頭可能有幾段「概覽」（headerType 3：坦／補／輸出各一段的摘要，暴雪在技能頁跳過它們），
-- 照樣收、標 overview。
--
-- 段落會依難度過濾（filteredByDifficulty 跟著冒險指南「目前選中的難度」走）：
-- 每個這副本有的難度各切一次記下來。選中的副本／難度都是跟暴雪冒險指南視窗共用的狀態，
-- 讀完全部切回原本的；冒險指南視窗開著時不切難度（只記目前那一個），免得畫面跟著跳。
--
-- 回傳 { info = Locate 的結果, root, diffs = { difficultyID... }, diffsSkipped,
--        sections = { { id, parent, depth, title, spell, headerType, flags = { 索引... },
--                       overview, hidden = { [difficultyID] = true } }, ... } }（照冒險指南的順序）
-- 或 nil, 原因字串（"journal" 找不到首領／"api" 這版沒有段落 API／"empty" 沒有段落）
------------------------------------------------------------
local HTYPE_OVERVIEW = 3
-- 團隊（隨機／普通／英雄／傳奇）、地城（普通／英雄／傳奇／鑰石）；這副本沒有的由 EJ_IsValidInstanceDifficulty 濾掉
local DIFFS = { 17, 14, 15, 16, 1, 2, 23, 8 }
local MAX_SECTIONS = 600

function J.Sections(encounterID)
    if not (C_EncounterJournal and C_EncounterJournal.GetSectionInfo and EJ_GetEncounterInfo) then return nil, "api" end
    local info = J.Locate(encounterID)
    if not info or not info.journal then return nil, "journal" end

    local function Read()
        local prevInst = EJ_GetCurrentInstance and S.SafeCall(EJ_GetCurrentInstance)
        local prevDiff = EJ_GetDifficulty and S.SafeCall(EJ_GetDifficulty)
        local journalOpen = EncounterJournal and EncounterJournal:IsShown()
        if not journalOpen then
            pcall(EJ_SelectInstance, info.instance)
            if EJ_SelectEncounter then pcall(EJ_SelectEncounter, info.journal) end
        end

        local _, _, _, root = S.SafeCall(EJ_GetEncounterInfo, info.journal)
        root = S.PlainNumber(root)
        local out = { info = info, root = root, diffs = {}, sections = {} }
        if root and root > 0 then
            local seen = {}
            local function Walk(sectionID, parent, depth, overview)
                while sectionID and sectionID > 0 and not seen[sectionID] and #out.sections < MAX_SECTIONS do
                    seen[sectionID] = true
                    local s = S.SafeCall(C_EncounterJournal.GetSectionInfo, sectionID)
                    if type(s) ~= "table" then break end
                    local htype = S.PlainNumber(s.headerType)
                    local ov = overview or (depth == 0 and htype == HTYPE_OVERVIEW)
                    local flags = S.SafeCall(C_EncounterJournal.GetSectionIconFlags, sectionID)
                    local rec = {
                        id = sectionID, parent = parent, depth = depth,
                        title = S.PlainText(s.title) or "",
                        spell = S.PlainNumber(s.spellID),
                        headerType = htype,
                        creature = (S.PlainNumber(s.creatureDisplayID) or 0) > 0,
                        flags = type(flags) == "table" and flags or {},
                        overview = ov and true or false,
                        hidden = {},
                    }
                    if rec.spell == 0 then rec.spell = nil end
                    out.sections[#out.sections + 1] = rec
                    Walk(S.PlainNumber(s.firstChildSectionID), sectionID, depth + 1, ov)
                    sectionID = S.PlainNumber(s.siblingSectionID)
                end
            end
            Walk(root, nil, 0, false)

            -- 各難度的過濾
            local function Mark(diff)
                for _, rec in ipairs(out.sections) do
                    local s = S.SafeCall(C_EncounterJournal.GetSectionInfo, rec.id)
                    if type(s) == "table" and S.ToBool(s.filteredByDifficulty) then rec.hidden[diff] = true end
                end
                out.diffs[#out.diffs + 1] = diff
            end
            if journalOpen or not (EJ_SetDifficulty and EJ_IsValidInstanceDifficulty) then
                if prevDiff then Mark(prevDiff) end
                out.diffsSkipped = true
            else
                for _, d in ipairs(DIFFS) do
                    if S.SafeBool(EJ_IsValidInstanceDifficulty, d) then
                        pcall(EJ_SetDifficulty, d)
                        Mark(d)
                    end
                end
                if prevDiff then pcall(EJ_SetDifficulty, prevDiff) end
            end
        end

        if not journalOpen and prevInst and prevInst ~= 0 then pcall(EJ_SelectInstance, prevInst) end
        return out
    end

    local out
    if info.tier then
        out = WithTier(info.tier, Read)
    else
        local ok, res = pcall(Read)
        out = ok and res or nil
    end
    if not out then return nil, "api" end
    if #out.sections == 0 then return nil, "empty" end
    return out
end
