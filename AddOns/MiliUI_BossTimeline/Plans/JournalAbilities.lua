------------------------------------------------------------
-- 冒險指南的技能段落 ↔ 暴雪的首領技能記錄（encounterEventID）比對
--
-- 為什麼要比：技能記錄沒有「屬於哪隻首領」的欄位，「首領技能」分頁目前靠 MRT 的時間軸分組
-- （Abilities.lua）。冒險指南的段落樹本身就是「首領 → 技能」而且有分組（階段／小怪）、
-- 角色標記，如果段落的 spellID 跟技能記錄的 spellID 對得上，就能不靠 MRT。
-- 這支只做比對、不改任何設定；結果由 /mbt ej 的報告（Options/JournalReport.lua）印出來，
-- 拿去實機驗證「對得上多少」再決定要不要正式換資料來源。
--
-- 比對分三層：
--   1. 法術直接對上：段落 spellID ＝ 記錄 spellID
--   2. 名稱對上：ID 不同但法術名稱（或段落標題）跟記錄的法術名稱一樣 ——
--      冒險指南常用「說明用」的法術，施放用的是另一個 ID
--   3. 對不上
-- 直接對上的記錄 ID 會分群（同一隻首領的記錄通常連號）：最大那群當這隻首領的範圍，
-- 其他群多半是共用法術（狂怒之類）對到別隻首領，標「遠處」。名稱對上只收範圍附近的。
--
-- 另外拿 MRT 的分組（A.FromMRT）當對照組，比較兩邊各自找到哪些記錄；
-- 並檢查冒險指南的角色／效果標記跟記錄的 icons 位元是否一致（兩邊是同一組概念）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local A = ns.Abilities
local MD = ns.MRTData

ns.JournalAbilities = {}
local JA = ns.JournalAbilities

local CLUSTER_GAP = 12      -- 直接對上的記錄 ID 相差在這之內算同一群
local NEAR_MARGIN = 10      -- 名稱對上時，範圍外這麼多筆以內仍算「附近」
local EDGE = 5              -- 報告列出範圍兩端外各幾筆

-- 冒險指南段落標記（GetSectionIconFlags 回的是 0 起算的索引，＝ Enum.JournalEncounterIconFlags 的位元位置）
-- → 技能記錄 icons 位元（Enum.EncounterEventIconmask）。沒有對應的（英雄、重要、可斷法、傳奇）不比。
JA.FLAG_TO_ICON = {
    [0]  = 128,   -- Tank
    [1]  = 512,   -- Dps
    [2]  = 256,   -- Healer
    [4]  = 1,     -- Deadly
    [7]  = 8,     -- Magic
    [8]  = 32,    -- Curse
    [9]  = 64,    -- Poison
    [10] = 16,    -- Disease
    [11] = 2,     -- Enrage
    [13] = 4,     -- Bleed
}
local ICON_TO_FLAG = {}
for flag, bitv in pairs(JA.FLAG_TO_ICON) do ICON_TO_FLAG[bitv] = flag end
local ICON_MASK = 0
for bitv in pairs(ICON_TO_FLAG) do ICON_MASK = ICON_MASK + bitv end

local FLAG_EN = {
    [0] = "Tank", [1] = "Dps", [2] = "Healer", [3] = "Heroic", [4] = "Deadly", [5] = "Important",
    [6] = "Interruptible", [7] = "Magic", [8] = "Curse", [9] = "Poison", [10] = "Disease",
    [11] = "Enrage", [12] = "Mythic", [13] = "Bleed",
}

-- 標記索引 → 名稱（用遊戲自己的在地化字串，冒險指南滑過圖示時顯示的那個）
function JA.FlagName(flag)
    local s = _G["ENCOUNTER_JOURNAL_SECTION_FLAG" .. flag]
    if type(s) == "string" and s ~= "" then return s end
    return FLAG_EN[flag] or tostring(flag)
end

-- 冒險指南標記清單 → icons 位元（只算有對應的）
function JA.FlagsToMask(flags)
    local m = 0
    for _, f in ipairs(flags or {}) do
        local b = JA.FLAG_TO_ICON[f]
        if b and bit.band(m, b) == 0 then m = m + b end
    end
    return m
end

-- icons 位元 → 標記索引清單（拿來印名稱）
function JA.MaskToFlags(mask)
    local out = {}
    if not mask then return out end
    for b, flag in pairs(ICON_TO_FLAG) do
        if bit.band(mask, b) ~= 0 then out[#out + 1] = flag end
    end
    table.sort(out)
    return out
end

local function Lower(s)
    if type(s) ~= "string" or s == "" then return end
    return strlower(strtrim(s))
end

local function Add(t, k, v)
    if k == nil then return end
    local l = t[k]
    if not l then l = {}; t[k] = l end
    l[#l + 1] = v
end

local function SortedKeys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

------------------------------------------------------------
-- 全遊戲的記錄索引（spellID → 記錄、名稱 → 記錄）
-- 法術名稱還沒載入的記錄先不進名稱索引，回報 missingNames 讓呼叫端晚點重跑
------------------------------------------------------------
function JA.BuildIndex()
    local idx = { bySpell = {}, byName = {}, info = {}, missingNames = 0, total = 0 }
    for _, id in ipairs(A.AllEventIDs()) do
        local info = A.Info(id)
        if info then
            idx.total = idx.total + 1
            idx.info[id] = info
            Add(idx.bySpell, info.spell, id)
            local n = Lower(info.name)
            if n then Add(idx.byName, n, id) else idx.missingNames = idx.missingNames + 1 end
        end
    end
    return idx
end

-- 連號分群：ids = { [記錄ID] = { [冒險指南 spellID] = true } }
-- 回傳 { { lo, hi, ids = {...}, spells = 落在這群的不同法術數 }, ... }，最像這隻首領的在前。
-- ⚠ 排序看「幾個不同法術」而不是「幾筆記錄」：狂怒這類共用法術一個 spellID 就對到每隻首領各一筆，
--   按筆數排會跟真正的首領群打平甚至贏過它。
local function Clusters(ids)
    local sorted = SortedKeys(ids)
    local out, cur = {}, nil
    for _, id in ipairs(sorted) do
        if cur and id - cur.hi <= CLUSTER_GAP then
            cur.hi = id
            cur.ids[#cur.ids + 1] = id
        else
            cur = { lo = id, hi = id, ids = { id }, spellSet = {} }
            out[#out + 1] = cur
        end
        for spell in pairs(ids[id]) do cur.spellSet[spell] = true end
    end
    for _, c in ipairs(out) do
        c.spells = #SortedKeys(c.spellSet)
        c.spellSet = nil
    end
    table.sort(out, function(a, b)
        if a.spells ~= b.spells then return a.spells > b.spells end
        if #a.ids ~= #b.ids then return #a.ids > #b.ids end
        return a.lo < b.lo
    end)
    return out
end

------------------------------------------------------------
-- 比對一隻首領（idx：JA.BuildIndex() 的結果，連跑多隻時共用；省略就現建）。回傳 result 或 nil, 原因（"events" 沒有記錄 API／Journal.Sections 的原因）
--
-- result = {
--   encounterID, name, journal = J.Sections 的結果,
--   index（全遊戲記錄索引）, sections（同 journal.sections，每段多了 match 欄位）,
--   clusters, range = { lo, hi } 或 nil,
--   events = { [記錄ID] = { sections = {段落...}, how = "exact"/"name", mrt = "match"/"guess"/nil } },
--   mrt = { available, has, list },
--   stats = { ... 見下方 },
-- }
-- 段落的 match = { kind = "exact"/"name"/"far"/"none"/"nospell", ids = {範圍內的記錄}, far = {範圍外的記錄},
--                  spellName, flagMask, flagCheck = { [記錄ID] = { agree, missing, extra } } }
------------------------------------------------------------
function JA.Compare(encounterID, idx)
    if not A.Available() then return nil, "events" end
    local journal, why = ns.Journal.Sections(encounterID)
    if not journal then return nil, why end

    idx = idx or JA.BuildIndex()
    local res = {
        encounterID = encounterID,
        name = journal.info.name,
        journal = journal,
        index = idx,
        sections = journal.sections,
        events = {},
        stats = {},
    }
    local st = res.stats
    st.sections, st.withSpell, st.overview, st.headers = #journal.sections, 0, 0, 0
    st.missingSectionSpellNames = 0

    -- 1. 直接對上（概覽段落不參與分群：它們只是摘要，常引用同一批法術）
    local exactIDs = {}
    local spellsSeen = {}
    for _, sec in ipairs(journal.sections) do
        local m = { ids = {}, far = {}, flagMask = JA.FlagsToMask(sec.flags), flagCheck = {} }
        sec.match = m
        if sec.overview then st.overview = st.overview + 1 end
        if sec.spell then
            st.withSpell = st.withSpell + 1
            spellsSeen[sec.spell] = true
            m.spellName = MD.SpellInfo(sec.spell)
            if not m.spellName then st.missingSectionSpellNames = st.missingSectionSpellNames + 1 end
            m.exact = idx.bySpell[sec.spell]
            if m.exact and not sec.overview then
                for _, id in ipairs(m.exact) do
                    exactIDs[id] = exactIDs[id] or {}
                    exactIDs[id][sec.spell] = true
                end
            end
        else
            st.headers = st.headers + 1
        end
    end
    st.uniqueSpells = #SortedKeys(spellsSeen)

    res.clusters = Clusters(exactIDs)
    local main = res.clusters[1]
    if main then res.range = { lo = main.lo, hi = main.hi } end
    local function InRange(id, margin)
        local r = res.range
        if not r then return false end
        margin = margin or 0
        return id >= r.lo - margin and id <= r.hi + margin
    end

    -- 2. 分類每一段：範圍內直接對上／名稱對上／只對到遠處／對不上
    local function Link(id, sec, how)
        local e = res.events[id]
        if not e then
            e = { sections = {}, how = how }
            res.events[id] = e
        elseif how == "exact" then
            e.how = "exact"
        end
        e.sections[#e.sections + 1] = sec
    end

    for _, sec in ipairs(journal.sections) do
        local m = sec.match
        if not sec.spell and not Lower(sec.title) then
            m.kind = "nospell"
        else
            for _, id in ipairs(m.exact or {}) do
                if InRange(id) then m.ids[#m.ids + 1] = id else m.far[#m.far + 1] = id end
            end
            if #m.ids > 0 then
                m.kind = "exact"
            else
                -- 名稱：法術名稱與段落標題都試（純標題段落沒有 spellID，但標題常就是技能名）
                local cands, seen = {}, {}
                for _, n in ipairs({ Lower(m.spellName), Lower(sec.title) }) do
                    for _, id in ipairs(idx.byName[n] or {}) do
                        if not seen[id] then seen[id] = true; cands[#cands + 1] = id end
                    end
                end
                table.sort(cands)
                local near = {}
                for _, id in ipairs(cands) do
                    if InRange(id, NEAR_MARGIN) then near[#near + 1] = id end
                end
                if #near > 0 then
                    m.kind = "name"
                    m.ids = near
                elseif #m.far > 0 then
                    m.kind = "far"
                elseif sec.spell then
                    m.kind = "none"
                    -- 範圍外的同名記錄也記下來，報告裡看得出是「別隻首領的同名技能」
                    for _, id in ipairs(cands) do m.far[#m.far + 1] = id end
                else
                    m.kind = "nospell"
                end
            end
            for _, id in ipairs(m.ids) do Link(id, sec, m.kind == "exact" and "exact" or "name") end
        end
    end

    -- 3. 標記一致性（只看有對應位元的標記；概覽段落不算）
    st.flagPairs, st.flagAgree = 0, 0
    st.flagMismatch = {}
    for _, sec in ipairs(journal.sections) do
        local m = sec.match
        if not sec.overview and (m.kind == "exact" or m.kind == "name") then
            for _, id in ipairs(m.ids) do
                local info = idx.info[id]
                local ev = bit.band(info and info.icons or 0, ICON_MASK)
                local ej = m.flagMask
                local check = {
                    agree = ev == ej,
                    missing = bit.band(ej, bit.bnot(ev)),   -- 冒險指南有、記錄沒有
                    extra = bit.band(ev, bit.bnot(ej)),     -- 記錄有、冒險指南沒有
                }
                m.flagCheck[id] = check
                st.flagPairs = st.flagPairs + 1
                if check.agree then
                    st.flagAgree = st.flagAgree + 1
                else
                    st.flagMismatch[#st.flagMismatch + 1] = { section = sec, id = id, check = check }
                end
            end
        end
    end

    -- 4. MRT 對照組
    local mrtList, viaMRT = A.FromMRT(encounterID)
    res.mrt = { available = MD.Available(), has = viaMRT and #mrtList > 0, list = mrtList }
    st.mrtMatch, st.mrtGuess = 0, 0
    local mrtLo, mrtHi
    for _, item in ipairs(mrtList) do
        local id = item.info.id
        local e = res.events[id]
        if not e then
            e = { sections = {} }
            res.events[id] = e
        end
        e.mrt = item.guessed and "guess" or "match"
        if item.guessed then st.mrtGuess = st.mrtGuess + 1 else st.mrtMatch = st.mrtMatch + 1 end
        mrtLo = (not mrtLo or id < mrtLo) and id or mrtLo
        mrtHi = (not mrtHi or id > mrtHi) and id or mrtHi
    end
    if mrtLo then res.mrtRange = { lo = mrtLo, hi = mrtHi } end

    -- 5. 統計
    local count = {}
    for _, sec in ipairs(journal.sections) do
        if not sec.overview then
            local k = sec.match.kind
            count[k] = (count[k] or 0) + 1
        end
    end
    st.kind = count

    -- 範圍內的每一筆記錄：冒險指南有沒有蓋到
    st.rangeSize, st.rangeCovered = 0, 0
    st.gaps = {}
    if res.range then
        for _, id in ipairs(A.AllEventIDs()) do
            if id >= res.range.lo and id <= res.range.hi and idx.info[id] then
                st.rangeSize = st.rangeSize + 1
                local e = res.events[id]
                if e and #e.sections > 0 then
                    st.rangeCovered = st.rangeCovered + 1
                else
                    st.gaps[#st.gaps + 1] = id
                end
            end
        end
        table.sort(st.gaps)
    end

    -- 兩邊各自找到的記錄（MRT 只算直接對上的，連號推測的另外算）
    st.both, st.ejOnly, st.mrtOnly, st.mrtGuessCoveredByEJ = 0, 0, 0, 0
    for _, e in pairs(res.events) do
        local ej = #e.sections > 0
        if ej and e.mrt == "match" then st.both = st.both + 1
        elseif ej and e.mrt == "guess" then st.ejOnly = st.ejOnly + 1; st.mrtGuessCoveredByEJ = st.mrtGuessCoveredByEJ + 1
        elseif ej then st.ejOnly = st.ejOnly + 1
        elseif e.mrt == "match" then st.mrtOnly = st.mrtOnly + 1 end
    end

    -- 一段對到多筆／一筆被多段引用
    st.multiEvent, st.multiSection = 0, 0
    for _, sec in ipairs(journal.sections) do
        if not sec.overview and #sec.match.ids > 1 then st.multiEvent = st.multiEvent + 1 end
    end
    for _, e in pairs(res.events) do
        local n = 0
        for _, sec in ipairs(e.sections) do if not sec.overview then n = n + 1 end end
        if n > 1 then st.multiSection = st.multiSection + 1 end
    end

    -- 粗略的結論：範圍內冒險指南蓋到幾成
    st.coverage = st.rangeSize > 0 and st.rangeCovered / st.rangeSize or nil
    return res
end

-- 範圍兩端外 EDGE 筆以內的記錄（看範圍邊界是不是切對了）
function JA.Edges(res)
    local before, after = {}, {}
    if not res.range then return before, after end
    for _, id in ipairs(A.AllEventIDs()) do
        if id < res.range.lo and id >= res.range.lo - EDGE then before[#before + 1] = id end
        if id > res.range.hi and id <= res.range.hi + EDGE then after[#after + 1] = id end
    end
    table.sort(before)
    table.sort(after)
    return before, after
end

JA.SortedKeys = SortedKeys

------------------------------------------------------------
-- 「首領技能」分頁的清單（A.ForEncounter 轉來這裡）
--
-- 依 2026-10-11 /mbt ej tier 實測（43 隻首領）定的規則：
--   * 段落 spellID ＝ 記錄 spellID 的**全收**，不管 ID 離多遠 —— 「遠處」的實測幾乎都是同一隻
--     （傳奇限定、後補的技能排在很後面，MRT 也對得上），真正的共用法術一隻都沒踩到。
--   * 同名不同 ID 的只收「離任一筆同 ID 記錄 NEAR_MARGIN 筆以內」的：名稱全遊戲重複很多（吞噬…）。
--   * 照冒險指南的順序排，用沒有法術的標題段落（階段、小怪、多首領戰的各隻）當分組。
--   * MRT 對上、冒險指南沒有的補在「其他」組；最後補小縫（A.Gaps）。
-- difficultyID：首領頁選的難度，只列冒險指南在這個難度有寫的技能（nil＝不濾）。
-- 回傳 items, src：items 是 { header = 文字 } 或 { info, how = "journal"/"name"/"mrt"/"guess", tags }；
-- src = { journal = 冒險指南有段落, mrt = MRT 有這隻 }（清單空的時候分頁拿來決定提示哪一句）
------------------------------------------------------------
local sectionCache = {}

local function CachedSections(encounterID)
    local hit = sectionCache[encounterID]
    if hit == nil then
        -- 失敗也快取：每次重畫都去切冒險指南的副本／難度沒有意義
        hit = ns.Journal.Sections(encounterID) or false
        sectionCache[encounterID] = hit
    end
    return hit or nil
end

-- 段落的分組：往上找沒有法術的標題段落（階段、小怪、首領名），由外到內串起來
local function GroupLabel(sec, byID)
    local titles = {}
    local p = sec.parent and byID[sec.parent]
    while p do
        if not p.spell and not p.overview and p.title ~= "" then table.insert(titles, 1, p.title) end
        p = p.parent and byID[p.parent]
    end
    return #titles > 0 and table.concat(titles, " › ") or nil
end

-- 段落上的難度標記（英雄／傳奇）照遊戲的字串顯示
local DIFF_FLAGS = { [3] = true, [12] = true }
local function Tags(sec)
    local out = {}
    for _, f in ipairs(sec.flags or {}) do
        if DIFF_FLAGS[f] then out[#out + 1] = JA.FlagName(f) end
    end
    return #out > 0 and table.concat(out, " ") or nil
end

-- 首領頁選的難度 → 冒險指南的難度（鑰石沒有自己的一份，看傳奇）
local DIFF_ALIAS = { [8] = 23 }

function JA.ForEncounter(encounterID, difficultyID)
    local src = { journal = false, mrt = false }
    if not A.Available() or not encounterID then return {}, src end
    local idx = JA.BuildIndex()
    local journal = CachedSections(encounterID)

    local groups, groupOf = {}, {}
    local taken = {}
    local visible = {}       -- [記錄ID] = { [難度] = true }：任一個對到它的段落在這個難度看得到
    local function Take(id, label, how, sec)
        if taken[id] or not idx.info[id] then return end
        taken[id] = true
        local key = label or ""
        local g = groupOf[key]
        if not g then
            g = { label = label, items = {} }
            groupOf[key] = g
            groups[#groups + 1] = g
        end
        g.items[#g.items + 1] = { info = idx.info[id], how = how, tags = sec and Tags(sec) }
    end

    if journal then
        src.journal = true
        local byID = {}
        for _, sec in ipairs(journal.sections) do byID[sec.id] = sec end
        -- 第一輪：同 ID 的全收（名稱比對要用它們當「附近」的基準）
        local exact = {}
        for _, sec in ipairs(journal.sections) do
            if not sec.overview and sec.spell then
                for _, id in ipairs(idx.bySpell[sec.spell] or {}) do exact[id] = true end
            end
        end
        local exactList = SortedKeys(exact)
        local function Near(id)
            for _, e in ipairs(exactList) do
                if math.abs(id - e) <= NEAR_MARGIN then return true end
            end
            return false
        end
        local function See(id, sec)
            local v = visible[id] or {}
            visible[id] = v
            for _, d in ipairs(journal.diffs) do
                if not sec.hidden[d] then v[d] = true end
            end
        end
        -- 第二輪：照冒險指南的順序放進各組
        for _, sec in ipairs(journal.sections) do
            if not sec.overview then
                local label = GroupLabel(sec, byID)
                local ids = {}
                for _, id in ipairs(sec.spell and idx.bySpell[sec.spell] or {}) do ids[#ids + 1] = id end
                table.sort(ids)
                for _, id in ipairs(ids) do
                    See(id, sec)
                    Take(id, label, "journal", sec)
                end
                local names = {}
                if sec.spell then names[#names + 1] = Lower(MD.SpellInfo(sec.spell)) end
                names[#names + 1] = Lower(sec.title)
                for _, n in ipairs(names) do
                    local cands = {}
                    for _, id in ipairs(idx.byName[n] or {}) do cands[#cands + 1] = id end
                    table.sort(cands)
                    for _, id in ipairs(cands) do
                        if Near(id) then
                            See(id, sec)
                            Take(id, label, "name", sec)
                        end
                    end
                end
            end
        end
    end

    local mrtList, viaMRT = A.FromMRT(encounterID)
    src.mrt = viaMRT
    for _, item in ipairs(mrtList) do
        if not item.guessed then Take(item.info.id, L["Other abilities (from MRT)"], "mrt") end
    end

    for _, id in ipairs(A.Gaps(taken)) do
        Take(id, L["Probably this boss too (between its records)"], "guess")
    end

    -- 難度：只留冒險指南在這個難度有寫的（MRT／推測的沒有難度資訊，照列）。
    -- 冒險指南沒檢查過這個難度（例如地城沒有隨機）就不濾
    local d = difficultyID and (DIFF_ALIAS[difficultyID] or difficultyID)
    local checked = false
    for _, x in ipairs(journal and journal.diffs or {}) do
        if x == d then checked = true end
    end
    local function Keep(it)
        local v = checked and visible[it.info.id]
        return not v or v[d] == true
    end

    -- 攤平：只有一組（而且沒有標題）就不印分組列；沒標題的那組在有其他組時用首領名當標題；濾完空掉的組整組不印
    local kept = {}
    for _, g in ipairs(groups) do
        local items = {}
        for _, it in ipairs(g.items) do
            if Keep(it) then items[#items + 1] = it end
        end
        if #items > 0 then kept[#kept + 1] = { label = g.label, items = items } end
    end
    local out = {}
    local onlyRoot = #kept == 1 and kept[1].label == nil
    for _, g in ipairs(kept) do
        if not onlyRoot then
            out[#out + 1] = { header = g.label or (journal and journal.info.name) or L["Boss"] }
        end
        for _, it in ipairs(g.items) do out[#out + 1] = it end
    end
    return out, src
end
