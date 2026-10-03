------------------------------------------------------------
-- 法術 → 格子的索引，與「這次 SPELL_UPDATE_COOLDOWN 只要重算哪幾格」的判斷
--
--   ns.SpellIndex.Rebuild()               照現在認領／放好的格子重建。目錄變了（CatalogChanged）當場叫一次；
--                                         Bars 每輪排版結尾只在「認領變了（Bars.claimsChanged）或 SI.dirty」時叫
--   ns.SpellIndex.dirty                   索引的輸入在認領之外變了 ⇒ 下一輪排版結尾要重建。設的地方（寫入出口）：
--                                         Catalog 重建目錄（C.info 整張換新：覆寫法術不在目錄簽章裡，
--                                         簽章沒變也可能換了）、Catalog.Adopt 收養、自訂法術的 overrideID 換了
--                                         （Modules/Custom.lua 的 UpdateSpell）。Rebuild 清掉
--   ns.SpellIndex.Lookup(spellID)         → { { owner, rec, key }, … }（沒有回共用的空表，唯讀）
--   ns.SpellIndex.Build(sources)          純函式：sources = { { ids = { … }, owner, rec, key }, … } → 索引表
--   ns.SpellIndex.Classify(lookup, isSecret, spellID, baseSpellID, category, startRecoveryCategory, itemID)
--                                         純函式：nil ＝ 全掃；否則回這次事件命中的 entry 清單
--   ns.SpellIndex.NewBatch() / Add(batch, …) / Take(batch)
--                                         同一幀多次事件合併：任何一次是「全掃」就全掃，否則收集命中的格子
--
-- 只收「認領中／放在條上」的：暴雪 item 收 Catalog 的 spellID 與 overrideSpellID，自訂法術收
-- rec.spellID 與 rec.overrideID。key 一律是明文數字（秘密值不進來，Catalog／Custom 讀的時候已過 Plain）。
--
-- 事件參數（warcraft.wiki.gg：11.1.5 加 spellID／baseSpellID／category／startRecoveryCategory，12.1 加 itemID；
-- spellID 是 nil ＝ 全部冷卻都要更新）。暴雪自己的檢視器對 category（共用冷卻）、startRecoveryCategory
-- （GCD 開始 ⇒ 每一格都刷新計時）、itemID（物品）都另外比對 ⇒ 這三個任一有值、或 spellID 讀不懂（nil／秘密／
-- 不是數字）、或索引裡查不到，一律全掃。**「讀不懂就全掃」是安全退路**：參數形狀沒有實機驗過（README 待實機驗證）。
------------------------------------------------------------
local _, ns = ...

ns.SpellIndex = {}
local SI = ns.SpellIndex

local EMPTY = setmetatable({}, { __newindex = function() error("SpellIndex: EMPTY is read-only", 2) end })
SI.EMPTY = EMPTY

local index = {}
SI.dirty = true                 -- 見檔頭；開機第一輪一定建
SI.rebuilds = 0
SI.precise, SI.full = 0, 0      -- 合併後的批次各走了幾次（debug）

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
function SI.Build(sources)
    local out = {}
    for _, s in ipairs(sources or {}) do
        local entry = { owner = s.owner, rec = s.rec, key = s.key }
        local seen = {}
        for _, id in ipairs(s.ids or {}) do
            if type(id) == "number" and not seen[id] then
                seen[id] = true
                local list = out[id]
                if not list then list = {}; out[id] = list end
                list[#list + 1] = entry
            end
        end
    end
    return out
end

-- lookup(id) → 清單（沒有回空表或 nil）；isSecret(v) → 布林
function SI.Classify(lookup, isSecret, spellID, baseSpellID, category, startRecoveryCategory, itemID)
    -- 秘密值連跟 nil 比都會拋錯：每個參數先問是不是秘密值
    if isSecret(spellID) or isSecret(baseSpellID) or isSecret(category)
        or isSecret(startRecoveryCategory) or isSecret(itemID) then
        return nil
    end
    if type(spellID) ~= "number" then return nil end
    if category ~= nil or startRecoveryCategory ~= nil or itemID ~= nil then return nil end
    local hits, seen = {}, {}
    local function take(id)
        if type(id) ~= "number" then return end
        for _, e in ipairs(lookup(id) or EMPTY) do
            if not seen[e] then
                seen[e] = true
                hits[#hits + 1] = e
            end
        end
    end
    take(spellID)
    if baseSpellID ~= spellID then take(baseSpellID) end
    if #hits == 0 then return nil end
    return hits
end

function SI.NewBatch()
    return { all = false, entries = {}, n = 0 }
end

function SI.Add(batch, lookup, isSecret, ...)
    if batch.all then return end
    local hits = SI.Classify(lookup, isSecret, ...)
    if not hits then
        batch.all = true
        batch.entries, batch.n = {}, 0
        return
    end
    for _, e in ipairs(hits) do
        if not batch.entries[e] then
            batch.entries[e] = true
            batch.n = batch.n + 1
        end
    end
end

-- 取出並清空：回 all, entries（set：entry → true）
function SI.Take(batch)
    local all, entries = batch.all, batch.entries
    batch.all, batch.entries, batch.n = false, {}, 0
    return all, entries
end

------------------------------------------------------------
-- 遊戲端
------------------------------------------------------------
function SI.Lookup(spellID)
    if type(spellID) ~= "number" then return EMPTY end
    return index[spellID] or EMPTY
end

function SI.Rebuild()
    SI.dirty = false
    local sources = {}
    local p = ns.profile
    local B, C = ns.Bars, ns.Catalog
    if B and B.ForEachClaimed and C and C.Info and type(p) == "table" and type(p.bars) == "table" then
        for key in pairs(p.bars) do
            B.ForEachClaimed(key, function(item, rec)
                local info = C.Info(rec.cooldownID)
                if info then
                    sources[#sources + 1] = { ids = { info.spellID, info.overrideSpellID }, owner = item, rec = rec, key = key }
                end
            end)
        end
    end
    if ns.Custom and ns.Custom.ForEachPlaced then
        ns.Custom.ForEachPlaced(function(f, rec, key)
            if rec.kind == "spell" then
                sources[#sources + 1] = { ids = { rec.spellID, rec.overrideID }, owner = f, rec = rec, key = key }
            end
        end)
    end
    index = SI.Build(sources)
    SI.rebuilds = SI.rebuilds + 1
end

function SI.Count()
    local n = 0
    for _ in pairs(index) do n = n + 1 end
    return n
end
