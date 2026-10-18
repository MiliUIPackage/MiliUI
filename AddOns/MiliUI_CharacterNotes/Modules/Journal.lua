------------------------------------------------------------
-- 冒險指南查表：副本清單、首領清單、玩家現在在哪個副本
--
-- 兩套 ID 不要搞混：
--   journalInstanceID / journalEncounterID   冒險指南自己的編號，我們拿它當存檔的 key
--   dungeonEncounterID                       ENCOUNTER_START 事件給的那個
-- 兩者 ID 空間不同，換算要靠 EJ_GetEncounterInfoByIndex 的第 7 個回傳值。
--
-- ⚠ EJ_SelectTier / EJ_SelectInstance / EJ_SetDifficulty 會改動玩家的冒險指南狀態
--   （暴雪那個視窗開著的話看得出來），所以列舉前後都要存檔還原。
--
-- ⚠ 全副本清單很貴（十幾個資料片 × 幾十個副本），只有玩家打開「副本」分頁才建，
--   而且一輩子只建一次。走進副本的偵測走另一條便宜的路（EJ_GetInstanceForMap），
--   不需要清單。
------------------------------------------------------------
local _, ns = ...

ns.Journal = {}
local Journal = ns.Journal

------------------------------------------------------------
-- 冒險指南的資料
--
-- EJ_* 是 C 端函式、隨時叫得動，但**資料**在某些情況下要等暴雪那支隨選插件載入
-- 才問得到（問到的會是 nil，不是錯誤 —— 靜默）。所以先便宜地問一次層數，
-- 問不到才去載，而且只試一次。
------------------------------------------------------------
local journalLoadTried = false

local function EnsureJournalLoaded()
    if journalLoadTried then return end
    journalLoadTried = true
    local n = EJ_GetNumTiers and EJ_GetNumTiers()
    if type(n) == "number" and n > 0 then return end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    end
end

------------------------------------------------------------
-- 首領清單（每個副本各自快取）
------------------------------------------------------------
local encounterCache = {}

-- 有些副本要先挑一個「這個副本真的有」的難度，EJ_GetEncounterInfoByIndex 才回得出東西
local CANDIDATE_DIFFICULTIES = { 1, 2, 23, 8, 14, 15, 16, 17 }

local function EnumerateEncounters(instanceID)
    local list = {}
    local i = 1
    while true do
        local ok, name, _, jEncID, _, _, _, dungeonEncID =
            pcall(EJ_GetEncounterInfoByIndex, i, instanceID)
        if not ok or not name or not jEncID then break end
        list[#list + 1] = {
            id                 = jEncID,
            name               = name,
            dungeonEncounterID = dungeonEncID,
        }
        i = i + 1
        if i > 60 then break end   -- 保險：清單長度異常時不要卡死
    end
    return list
end

function Journal.Encounters(instanceID)
    if type(instanceID) ~= "number" then return {} end
    local cached = encounterCache[instanceID]
    if cached then return cached end
    if not (EJ_SelectInstance and EJ_GetEncounterInfoByIndex) then return {} end
    EnsureJournalLoaded()

    local savedDiff = EJ_GetDifficulty and EJ_GetDifficulty()
    pcall(EJ_SelectInstance, instanceID)
    local list = EnumerateEncounters(instanceID)

    -- 空的話換難度再試一輪
    if #list == 0 and EJ_SetDifficulty then
        for _, diff in ipairs(CANDIDATE_DIFFICULTIES) do
            local valid = true
            if EJ_IsValidInstanceDifficulty then
                local ok, v = pcall(EJ_IsValidInstanceDifficulty, diff)
                valid = ok and v
            end
            if valid then
                pcall(EJ_SetDifficulty, diff)
                list = EnumerateEncounters(instanceID)
                if #list > 0 then break end
            end
        end
    end

    if savedDiff and EJ_SetDifficulty then pcall(EJ_SetDifficulty, savedDiff) end
    encounterCache[instanceID] = list
    return list
end

-- dungeonEncounterID → journalEncounterID, 名稱
function Journal.EncounterByDungeonID(instanceID, dungeonEncounterID)
    if not dungeonEncounterID then return nil end
    for _, e in ipairs(Journal.Encounters(instanceID)) do
        if e.dungeonEncounterID == dungeonEncounterID then return e.id, e.name end
    end
    return nil
end

-- 把 dungeonEncounterID 記在筆記上。
-- ENCOUNTER_START 只給那個編號，而冒險指南有查不到的時候（資料片下架、
-- 客戶端還沒載入）；筆記上自己有一份就永遠對得回來。
function Journal.StampDungeonID(note, instanceID, encounterID)
    if type(note) ~= "table" or not encounterID then return end
    if note.dungeonEncounterID then return end
    for _, e in ipairs(Journal.Encounters(instanceID)) do
        if e.id == encounterID then
            note.dungeonEncounterID = e.dungeonEncounterID
            return
        end
    end
end

function Journal.EncounterName(instanceID, encounterID)
    for _, e in ipairs(Journal.Encounters(instanceID)) do
        if e.id == encounterID then return e.name end
    end
    -- 冒險指南查不到（資料片下架、或客戶端還沒載入）就退回單獨查一次
    if EJ_GetEncounterInfo then
        local ok, name = pcall(EJ_GetEncounterInfo, encounterID)
        if ok and name then return name end
    end
    return nil
end

------------------------------------------------------------
-- 全副本清單（只有「副本」分頁會叫）
------------------------------------------------------------
local catalogue      -- { list = {...}, byID = { [id] = entry } }

local function BuildCatalogue()
    local out = {
        list = {}, byID = {}, byInstanceMap = {},
        byTier = {},          -- [tier] = { party = { id... }, raid = { id... }, name = }
        maxTier = 0, maxRaidTier = 0,
        counts = { party = 0, raid = 0, skipped = 0 },   -- 只給 /mnote debug 用
    }
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then
        return out
    end

    EnsureJournalLoaded()
    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local numTiers = EJ_GetNumTiers() or 0

    for tier = 1, numTiers do
        -- ⚠ 這裡不能 break：某一個資料片選不動就跳過它，不要把後面的整片丟掉
        if pcall(EJ_SelectTier, tier) then
            local tierName
            if EJ_GetTierInfo then
                local ok, name = pcall(EJ_GetTierInfo, tier)
                tierName = ok and name or nil
            end

            for pass = 1, 2 do
                local isRaid = (pass == 2)
                local idx = 1
                while true do
                    local ok, instanceID, name, _, _, _, _, _, dungeonAreaMapID, _,
                          showsDifficulty, mapID =
                        pcall(EJ_GetInstanceByIndex, idx, isRaid)
                    if not ok or not instanceID then break end

                    -- 世界首領那種「不是真的能走進去」的條目要濾掉。
                    -- ⚠ 判準是**兩個都是 0**：世界首領沒有地圖也沒有 instance ID，
                    --   而真的副本至少會有其中一個。只看 dungeonAreaMapID 的話，
                    --   哪天某個團本那一欄是 0 就會整個消失（而且是靜默的）。
                    local isWorldBoss = (dungeonAreaMapID or 0) == 0 and (mapID or 0) == 0

                    -- ⚠ 「這一層有哪些副本」要在去重**之前**記。同一個副本會同時出現在
                    --   它的資料片層與「當前賽季」層；去重只留第一次遇到的（資料片層），
                    --   結果就是當前賽季那一層看起來空空如也 —— 團本消失的第二個成因。
                    if not isWorldBoss then
                        local t = out.byTier[tier]
                        if not t then
                            t = { party = {}, raid = {}, name = tierName }
                            out.byTier[tier] = t
                        end
                        local bucket = isRaid and t.raid or t.party
                        bucket[#bucket + 1] = instanceID
                    end

                    if out.byID[instanceID] or isWorldBoss then
                        if isWorldBoss then out.counts.skipped = out.counts.skipped + 1 end
                    else
                        local entry = {
                            id       = instanceID,
                            name     = name,
                            isRaid   = isRaid,
                            tier     = tier,
                            tierName = tierName,
                            uiMapID  = dungeonAreaMapID,
                            mapID    = mapID,
                            -- 有難度選單＝真的能挑普通/英雄/傳奇的團本。
                            -- 世界首領那種容器只有一種難度，這一欄是 false。
                            showsDifficulty = showsDifficulty and true or false,
                        }
                        if tier > out.maxTier then out.maxTier = tier end
                        if isRaid then
                            out.counts.raid = out.counts.raid + 1
                            if tier > out.maxRaidTier then out.maxRaidTier = tier end
                        else
                            out.counts.party = out.counts.party + 1
                        end
                        out.list[#out.list + 1] = entry
                        out.byID[instanceID] = entry
                        if type(mapID) == "number" and mapID > 0 then
                            out.byInstanceMap[mapID] = instanceID
                        end
                    end
                    idx = idx + 1
                    if idx > 200 then break end
                end
            end
        end
    end

    if savedTier then pcall(EJ_SelectTier, savedTier) end

    -- 新的資料片排前面；同資料片先團隊後地城，再依名字
    table.sort(out.list, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier end
        if a.isRaid ~= b.isRaid then return a.isRaid end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

function Journal.Catalogue()
    if not catalogue then catalogue = BuildCatalogue() end
    return catalogue
end

function Journal.IsCatalogueBuilt()
    return catalogue ~= nil
end

function Journal.InstanceInfo(instanceID)
    if type(instanceID) ~= "number" then return nil end
    -- 已經建過清單就直接查；沒建過不要為了一個名字去建整份
    if catalogue and catalogue.byID[instanceID] then return catalogue.byID[instanceID] end
    if EJ_GetInstanceInfo then
        local ok, name = pcall(EJ_GetInstanceInfo, instanceID)
        if ok and name then return { id = instanceID, name = name } end
    end
    return nil
end

-- 名字：先問冒險指南，查不到退回存檔裡記的（資料片下架也還顯示得出來）
function Journal.InstanceName(instanceID)
    local info = Journal.InstanceInfo(instanceID)
    if info and info.name then return info.name end
    local entry = ns.Notes.InstanceEntry(instanceID, false)
    if entry and entry.meta and entry.meta.name then return entry.meta.name end
    return nil
end

------------------------------------------------------------
-- 玩家現在在哪個副本
--
-- 便宜的路：uiMap → 冒險指南。查一次記一次（同一張地圖不會變答案）。
------------------------------------------------------------
local mapToInstance = {}

local function ResolveFromMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil end
    local cached = mapToInstance[uiMapID]
    if cached ~= nil then return cached ~= false and cached or nil end

    local jInst
    if EJ_GetInstanceForMap then
        local ok, id = pcall(EJ_GetInstanceForMap, uiMapID)
        if ok and type(id) == "number" and id > 0 then jInst = id end
    end
    if not jInst and C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
        local ok, id = pcall(C_EncounterJournal.GetInstanceForGameMap, uiMapID)
        if ok and type(id) == "number" and id > 0 then jInst = id end
    end
    mapToInstance[uiMapID] = jInst or false
    return jInst
end

-- 回傳 journalInstanceID, 副本名稱, instanceType, difficultyID
-- 不在副本裡（或查不到）就回 nil
function Journal.CurrentInstance()
    local name, instanceType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" and instanceType ~= "scenario" then
        return nil, nil, instanceType, difficultyID
    end

    local jInst = ResolveFromMap()

    -- 備援：清單已經建過的話，用 GetInstanceInfo 的 instanceMapID 反查。
    -- 只在清單「已經存在」時走這條——不為了偵測而去建整份清單。
    if not jInst and catalogue and type(instanceMapID) == "number" then
        jInst = catalogue.byInstanceMap[instanceMapID]
    end

    -- 名字可能是秘密值（12.1 對受限身分的字串），拿來當顯示文字之前先擋
    if ns.issecret(name) then name = nil end
    return jInst, name, instanceType, difficultyID
end

------------------------------------------------------------
-- 團隊難度
--
-- 只給「主要」那四個（隨機／普通／英雄／傳奇）。10/25 人那套是舊資料片的東西，
-- 列進來只會讓選單變長；真的要寫舊團本的筆記，用「全部」那一格就好。
------------------------------------------------------------
local RAID_DIFF_FALLBACK = { 17, 14, 15, 16 }   -- 隨機 / 普通 / 英雄 / 傳奇

local raidDiffs

function Journal.RaidDifficulties()
    if raidDiffs then return raidDiffs end
    raidDiffs = {}
    local ids = {}
    local U = DifficultyUtil and DifficultyUtil.ID
    if U and U.PrimaryRaidLFR then
        ids = { U.PrimaryRaidLFR, U.PrimaryRaidNormal, U.PrimaryRaidHeroic, U.PrimaryRaidMythic }
    else
        ids = RAID_DIFF_FALLBACK
    end
    for _, id in ipairs(ids) do
        if type(id) == "number" then
            raidDiffs[#raidDiffs + 1] = { key = id, name = Journal.DifficultyName(id) }
        end
    end
    return raidDiffs
end

-- key 是 ns.Notes.DIFF_ALL 或難度 ID
function Journal.DifficultyName(key)
    if key == nil or key == ns.Notes.DIFF_ALL then return ns.L["All difficulties"] end
    if DifficultyUtil and DifficultyUtil.GetDifficultyName then
        local ok, name = pcall(DifficultyUtil.GetDifficultyName, key)
        if ok and name and name ~= "" then return name end
    end
    if GetDifficultyInfo then
        local ok, name = pcall(GetDifficultyInfo, key)
        if ok and name and name ~= "" then return name end
    end
    return tostring(key)
end

------------------------------------------------------------
-- 本季的副本
--
-- 地城 = 這一季的傳奇鑰石名單（`C_ChallengeMode.GetMapTable`），團本 = 最新資料片的
-- 團隊副本。鑰石名單跨資料片（每季會抓幾個舊地城回來），所以**不能**用「最新資料片」
-- 當本季地城的近似值 —— 那正是這條路存在的理由。
--
-- 換算靠**名字**：鑰石那套 API 只給 challengeMapID 與名稱，跟冒險指南的
-- journalInstanceID 之間沒有公開的對照。兩邊的名字都由客戶端依語系吐出來，
-- 對得起來；大型地城拆成上下半場時鑰石那邊的名字會比較長，所以再補一次前綴比對。
------------------------------------------------------------
------------------------------------------------------------
-- 本季團本的黑名單（journalInstanceID）
--
-- 下面那條「跟資料片同名＝世界首領容器」的規則應該就夠了；這張表是留給
-- 「暴雪又塞了別的東西進當前賽季、而它不叫資料片的名字」那種情況。
-- 要加的話 `/mnote debug` 會把每一格的 ID 一起印出來，照著填就好。
------------------------------------------------------------
local SEASON_RAID_BLACKLIST = {
    -- [12345] = true,   -- 範例：某個不該出現在本季清單的格子
}
Journal.SeasonRaidBlacklist = SEASON_RAID_BLACKLIST

local seasonSet
local seasonStats = { matched = 0, unmatched = {}, dropped = {}, tier = nil, tierName = nil }

-- 比對用的正規化：拿掉空白與標點，避免「破碎大廳」與「破碎大廳 」這種差一格就對不上
local function NormName(name)
    if type(name) ~= "string" then return nil end
    return (name:lower():gsub("[%s%p]", ""))
end

function Journal.SeasonInstances()
    if seasonSet then return seasonSet end

    local cat = Journal.Catalogue()
    local set, matched = {}, 0
    local unmatched = {}
    seasonStats.dropped = {}

    local byName = {}
    for _, e in ipairs(cat.list) do
        local n = NormName(e.name)
        if n then byName[n] = e.id end
    end

    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local ok, maps = pcall(C_ChallengeMode.GetMapTable)
        if ok and type(maps) == "table" then
            for _, cmID in ipairs(maps) do
                local ok2, name = pcall(C_ChallengeMode.GetMapUIInfo, cmID)
                local n = ok2 and NormName(name)
                if n then
                    local id = byName[n]
                    if not id then
                        -- 前綴比對：其中一邊是另一邊的開頭就算同一個副本
                        for other, otherID in pairs(byName) do
                            if #other >= 4 and (n:find(other, 1, true) == 1
                                             or other:find(n, 1, true) == 1) then
                                id = otherID
                                break
                            end
                        end
                    end
                    if id then
                        set[id] = true
                        matched = matched + 1
                    else
                        unmatched[#unmatched + 1] = tostring(name)
                    end
                end
            end
        end
    end

    ------------------------------------------------------------
    -- 本季團本
    --
    -- 冒險指南自己就有「當前賽季」那一層（資料片下拉的第一個），團隊頁列的正好是
    -- 本季的團本。問題是要**認出它是哪一層**，而它的名字會跟著語系跑。
    --
    -- 認法不靠名字，靠結構：本季的鑰石地城橫跨好幾個資料片，
    -- **同時裝得下這幾個地城的那一層只有「當前賽季」**。所以拿上面已經對出來的
    -- 那批地城去比對每一層的成員，命中最多的那層就是它。
    -- （拿資料片層當近似值會撈到整片的團本 —— 實測 7 個，而本季只有 3 個。）
    ------------------------------------------------------------
    local seasonTier, bestHits = nil, 0
    for tier, members in pairs(cat.byTier) do
        local hits = 0
        for _, id in ipairs(members.party) do
            if set[id] then hits = hits + 1 end
        end
        if hits > bestHits then seasonTier, bestHits = tier, hits end
    end
    -- 對到的地城要夠多才算數：只中一兩個代表那只是某個資料片剛好有幾個同名地城
    if seasonTier and matched > 0 and bestHits < math.ceil(matched / 2) then
        seasonTier = nil
    end

    local raidIDs
    if seasonTier then
        raidIDs = cat.byTier[seasonTier].raid
    elseif cat.maxRaidTier > 0 then
        -- 沒有「當前賽季」那一層（或認不出來）就退回「有團本的最新資料片」。
        -- ⚠ 不能退回 maxTier —— 最新那個資料片可能只有地城、團本還沒上線。
        raidIDs = cat.byTier[cat.maxRaidTier] and cat.byTier[cat.maxRaidTier].raid
    end

    -- 團隊清單裡混著兩種「不是團本」的格子，兩種都要剔掉：
    --
    --   1. 沒有首領的 —— 資料片總覽那種格子，寫不了首領筆記。
    --   2. **世界首領容器** —— 暴雪確實把它放進當前賽季（實測「至暗之夜」那一格
    --      裡面是四隻世界首領），但它不是一個能進去打的團本，寫筆記沒有意義。
    --      判準：**名字跟某個資料片的名字一樣**。世界首領容器就是以資料片命名的，
    --      而正規團本不會叫這個名字。比對的是兩邊都由客戶端吐出來的字串，
    --      不是寫死的中文，換語系照樣成立。
    --      ⚠ 代價：哪天真的有團本跟資料片同名就會被誤殺（只影響「本季」這個
    --        篩選，切到「全部」還是找得到），而且 debug 會把剔除清單印出來。
    local tierNames = {}
    for _, members in pairs(cat.byTier) do
        local n = NormName(members.name)
        if n then tierNames[n] = true end
    end

    for _, id in ipairs(raidIDs or {}) do
        local entry = cat.byID[id]
        local bosses = #Journal.Encounters(id)
        local namedAfterTier = (entry and tierNames[NormName(entry.name) or ""]) and true or false
        local why
        if SEASON_RAID_BLACKLIST[id] then why = "黑名單"
        elseif bosses == 0 then why = "沒有首領"
        elseif namedAfterTier then why = "世界首領（跟資料片同名）" end

        if why then
            seasonStats.dropped[#seasonStats.dropped + 1] = ("%s#%d(%d隻，%s)"):format(
                tostring((entry and entry.name) or Journal.InstanceName(id) or id),
                id, bosses, why)
        else
            set[id] = true
        end
    end
    seasonStats.tier = seasonTier
    seasonStats.tierName = seasonTier and cat.byTier[seasonTier].name or nil

    -- ⚠ 一律記起來。呼叫端是在**逐筆過濾的迴圈裡**問這個，「這次算不準就先不快取」
    -- 等於每一列都重掃一次整份清單。名單晚點才到的情況改由事件處理（見下），
    -- 那才是「什麼時候該重算」的正確訊號。
    seasonStats.matched = matched
    seasonStats.unmatched = unmatched
    seasonSet = set
    return seasonSet
end

------------------------------------------------------------
-- /mnote debug 的副本清單報告
--
-- 「團本沒出現」這種問題只看程式碼是猜不完的（冒險指南在不同改版階段回什麼
-- 沒有保證），所以直接把手上的數字印出來：清單裡有幾個團本、最新的團本在哪個
-- 資料片、本季挑了哪幾個、鑰石名單有哪幾個名字對不回冒險指南。
------------------------------------------------------------
function Journal.DebugLines()
    local cat = Journal.Catalogue()
    local season = Journal.SeasonInstances()

    local seasonParty, seasonRaid, raidNames = 0, 0, {}
    for _, e in ipairs(cat.list) do
        if season[e.id] then
            if e.isRaid then
                seasonRaid = seasonRaid + 1
                -- 帶上首領數與有沒有難度選單：一眼看得出哪一筆其實是世界首領容器
                raidNames[#raidNames + 1] = ("%s#%d(%d隻/%s)"):format(
                    e.name, e.id, #Journal.Encounters(e.id),
                    e.showsDifficulty and "有難度" or "無難度")
            else
                seasonParty = seasonParty + 1
            end
        end
    end

    local lines = {
        ("  冒險指南：資料片 %d 個，地城 %d、團本 %d（略過世界首領 %d）")
            :format(EJ_GetNumTiers and (EJ_GetNumTiers() or 0) or 0,
                    cat.counts.party, cat.counts.raid, cat.counts.skipped),
        ("  maxTier=%d  maxRaidTier=%d"):format(cat.maxTier, cat.maxRaidTier),
        ("  本季：地城 %d、團本 %d"):format(seasonParty, seasonRaid),
    }
    if #raidNames > 0 then
        lines[#lines + 1] = "  本季團本：" .. table.concat(raidNames, "、")
    end

    -- 團本一個都沒有的時候，把最新那一片的團本列出來，一眼看得出是「清單裡沒有」
    -- 還是「有但被本季篩掉」
    if seasonRaid == 0 then
        local top = {}
        for _, e in ipairs(cat.list) do
            if e.isRaid and e.tier == cat.maxRaidTier then top[#top + 1] = e.name end
        end
        lines[#lines + 1] = "  最新資料片的團本：" ..
            (#top > 0 and table.concat(top, "、") or "（清單裡一個都沒有）")
    end

    lines[#lines + 1] = ("  當前賽季那一層：tier=%s（%s）")
        :format(tostring(seasonStats.tier), tostring(seasonStats.tierName))
    if #seasonStats.dropped > 0 then
        lines[#lines + 1] = "  剔除（不是能寫首領筆記的團本）：" ..
            table.concat(seasonStats.dropped, "、")
    end
    lines[#lines + 1] = ("  鑰石名單對到 %d 個"):format(seasonStats.matched)
    if #seasonStats.unmatched > 0 then
        lines[#lines + 1] = "  對不回冒險指南的鑰石地城：" ..
            table.concat(seasonStats.unmatched, "、")
    end
    return lines
end

function Journal.ResetSeason()
    seasonSet = nil
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function()
    -- 鑰石名單到貨（或換季）→ 下次問的時候重算
    Journal.ResetSeason()
end)

ns.RegisterCallback("Init", "journal", function()
    -- 鑰石名單要跟伺服器要一次才會有東西；早點要，玩家打開副本分頁時就已經在了
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        pcall(C_MythicPlus.RequestMapInfo)
    end
    ev:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
end)
