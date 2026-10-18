------------------------------------------------------------
-- 自訂項目的資料層（從 Core/DB.lua 切出，2026-10-18；TOC 緊接在 DB.lua 之後載入）
--
-- 四層範圍（戰隊／職業／角色／專精）的清單、身分、生效清單合併、新增／刪除／搬層／複製到其他專精。
-- 用到的 DB.lua 幫手：DB.DeepCopy、DB.CharKey（在那邊宣告成 local 再掛到 DB 上）。
------------------------------------------------------------
local _, ns = ...

local DB = ns.DB
local DeepCopy, CharKey = DB.DeepCopy, DB.CharKey

------------------------------------------------------------
-- 自訂項目：spells[specID].custom = { { kind, spellID|itemID, filter, placeholder, bar }, … }
--
--   kind         "aura"（光環格）| "spell"（法術冷卻）| "item"（物品冷卻）| "slot"（裝備欄位：slot = 13／14，追蹤裝在那一格的物品）
--                | "slotbuff"（飾品欄增益：slot = 13／14、buff = N（暴雪的 buffSlot，正整數、不設上限、缺 ＝ 1），
--                  那件飾品第 N 個增益生效時才出現的光環格；身分「slotbuff:<slot>:<N>」，同一層同槽同 N 只能一筆）
--   filter       光環格才有："HELPFUL" | "HARMFUL"
--   placeholder  光環格才有：光環不在時畫去飽和的占位圖示
--   bar          放在哪一條（只收圖示類的條）
--   alts         物品才有（選用）：替代品 { itemID, … }，顯示「主＋alts」裡第一個包包裡有的（Modules/Custom.lua）
--   spellIDs     光環格才有（選用，只認增益）：主 ID 以外也算這一格的法術 { spellID, … }
--   ⚠ 兩個選用欄位舊存檔都沒有 ＝ 行為跟以前一樣；判重（FindCustom）、身分都只看主的那個 ID。
--
-- 在順序、隱藏、覆寫裡的 id 是 "c:<index>"。index 是陣列位置，所以**刪掉中間一筆時
-- 後面的 id 全部要往前挪**（DB.RemoveCustom 負責，不然第 3 筆的覆寫會跑到原本的第 4 筆上）。
--
-- ── 四層範圍（2026-10-03 三層、2026-10-12 加角色層）：戰隊 ＞ 職業 ＞ 角色 ＞ 專精，窄的蓋寬的 ──────
--   profile.customShared            戰隊層：用這份設定檔的每個角色、每個專精都看得到
--   profile.customClass[classFile]  職業層：這個職業的所有專精
--   profile.customChar[charKey]     角色層：這個角色（DB.CharKey()，「名字 - 伺服器」）的所有專精
--   spells[specID].custom           專精層（上面那張，不動；仍是最窄：玩家對單一專精的選擇）
--   三張寬層表（戰隊／職業／角色）的一筆跟專精層同形狀，另外多：
--     uid          穩定編號（設定檔層的流水號 profile.customNextUID，三個寬層共用一個號碼空間）；
--                  id 是 "w:<uid>"（戰隊）／"k:<uid>"（職業）／"p:<uid>"（角色），刪掉別筆也不會變（不用挪位）
--     overrides    這一筆的逐法術覆寫（跟著項目走；所有看得到它的專精讀同一份）
--     hideUnknown  這個角色用不到（法術沒學）時整格不列；nil／true ＝ 不列（預設），false ＝ 照舊畫問號格
--   順序、隱藏、群組仍存在專精層（spells[specID].order[bar] 可以放 "k:3"／"w:7"／"p:9"）。
--   ⚠ 專精表是同設定檔、同專精的角色共用的 ⇒ 別隻角色的 "p:<uid>" 會留在順序表裡；這隻角色的角色層沒有那個 uid
--     ＝ 對這隻角色不存在（生效清單裡沒有，排版照常略過）。號碼空間共用，所以不會撞到這隻角色自己的。
--   種類多一個 "racial"（種族技能）：沒有 spellID，照這個角色的種族解析成學會的那一個（Presets.ResolveRacial）；
--   解不到 ＝ 當成沒學（不列）。
--   種類多一個 "timer"（內建冷卻，Modules/Timers.lua）：{ kind = "timer", key = "naturesGuardian", bar }，沒有 spellID；
--   key 不認得（定義拿掉了、匯入別人的設定）＝ 不存在；寬層照 hideUnknown 問天賦點了沒（opts.talentKnown）。
--   **窄的蓋寬的**：同一個身分（同種類＋同主 ID，光環還要同 filter）在多層都有時只有最窄的那層生效，
--   寬的那筆對這個專精當不存在（DB.ResolveScopes，純函式）。
--   舊存檔沒有這幾張表 ＝ 只有專精層，行為跟以前一樣（不遷移、DB_VERSION 不動）。
------------------------------------------------------------
DB.CUSTOM_KINDS = { aura = true, spell = true, item = true, slot = true, slotbuff = true, racial = true, timer = true }

-- 範圍：越大越窄（窄的蓋寬的）
DB.SCOPE_RANK = { shared = 1, class = 2, char = 3, spec = 4 }
DB.SCOPE_ORDER = { "shared", "class", "char", "spec" }
local SCOPE_PREFIX = { spec = "c", class = "k", shared = "w", char = "p" }
local PREFIX_SCOPE = { c = "spec", k = "class", w = "shared", p = "char" }

-- 寬層（戰隊／職業／角色）：uid 編號、覆寫跟著那一筆走、沒學的法術預設不列。專精層與不認得的範圍回 false
function DB.IsWideScope(scope)
    return scope ~= nil and scope ~= "spec" and DB.SCOPE_RANK[scope] ~= nil
end

function DB.CustomID(i) return "c:" .. tostring(i) end

-- 範圍＋編號 → id（專精層的編號是陣列位置、另外兩層是 uid）
function DB.ScopedCustomID(scope, key)
    local pre = SCOPE_PREFIX[scope]
    if not pre or key == nil then return nil end
    return pre .. ":" .. tostring(key)
end

-- **解析自訂項目 id 的唯一出口**：
--   "c:3" → "spec", 3（陣列位置）｜"k:5" → "class", 5（uid）｜"w:7" → "shared", 7（uid）｜"p:9" → "char", 9（uid）
--   不是自訂項目的 id（數字 cooldownID、格式不對）→ nil
function DB.ParseCustomID(id)
    if type(id) ~= "string" then return nil end
    local pre, n = id:match("^(%a):(%d+)$")
    local scope = pre and PREFIX_SCOPE[pre]
    if not scope then return nil end
    return scope, tonumber(n)
end

-- "c:3" → 3；不是專精層自訂項目的 id 回 nil（"k:"／"w:"／"p:" 也是 nil：它們沒有陣列位置）
function DB.CustomIndex(id)
    local scope, n = DB.ParseCustomID(id)
    if scope == "spec" then return n end
    return nil
end

local function PositiveInt(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end

-- 角色層的 key：DB.CharKey()（「名字 - 伺服器」）；名字還讀不到（太早、離線測試沒有 UnitName）⇒ nil，
-- 不能落到 "? - ?" 那一格（每隻讀不到名字的角色會共用它）
local function CharScopeKey()
    if type(UnitName) ~= "function" or type(GetRealmName) ~= "function" then return nil end
    local name, realm = UnitName("player"), GetRealmName()
    if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then return nil end
    return CharKey()
end

-- 某一層的清單（"spec" ＝ 這個專精的 custom；"class" ＝ 這個角色職業的；"char" ＝ 這個角色的；"shared" ＝ 戰隊層）
-- create ＝ 呼叫端要寫 ⇒ DB.customGen 的作廢點（"spec" 走 CustomList，同一個規矩）
function DB.ScopeList(scope, create, specID)
    if scope == "spec" then return DB.CustomList(create, specID) end
    local p = ns.profile
    if not p then return nil end
    if create then DB.TouchCustom() end
    if scope == "shared" then
        if type(p.customShared) ~= "table" then
            if not create then return nil end
            p.customShared = {}
        end
        return p.customShared
    elseif scope == "class" then
        local cls = ns.playerClass
        if type(cls) ~= "string" or cls == "" then return nil end
        if type(p.customClass) ~= "table" then
            if not create then return nil end
            p.customClass = {}
        end
        local list = p.customClass[cls]
        if type(list) ~= "table" then
            if not create then return nil end
            list = {}
            p.customClass[cls] = list
        end
        return list
    elseif scope == "char" then
        local key = CharScopeKey()
        if not key then return nil end
        if type(p.customChar) ~= "table" then
            if not create then return nil end
            p.customChar = {}
        end
        local list = p.customChar[key]
        if type(list) ~= "table" then
            if not create then return nil end
            list = {}
            p.customChar[key] = list
        end
        return list
    end
    return nil
end

local function FindUID(list, uid)
    if type(list) ~= "table" or uid == nil then return nil end
    for pos, e in ipairs(list) do
        if type(e) == "table" and e.uid == uid then return e, pos end
    end
    return nil
end

-- 每一張寬層清單（戰隊層＋所有職業的＋所有角色的）：fn(list)。
-- 角色層也要掃全部角色：NextCustomUID 靠它找最大的 uid（別隻角色的號碼不能撞），覆寫遷移、刪條改家也要顧到
local function EachWideList(p, fn)
    if type(p) ~= "table" then return end
    if type(p.customShared) == "table" then fn(p.customShared) end
    for _, field in ipairs({ "customClass", "customChar" }) do
        if type(p[field]) == "table" then
            for _, list in pairs(p[field]) do
                if type(list) == "table" then fn(list) end
            end
        end
    end
end
DB.EachWideList = EachWideList

-- 新的 uid：流水號；比現有的最大 uid 小（匯入的設定檔、手改過的存檔）就從最大的下一號接
function DB.NextCustomUID()
    local p = ns.profile
    if not p then return nil end
    local n = PositiveInt(p.customNextUID) and p.customNextUID or 1
    local maxSeen = 0
    EachWideList(p, function(list)
        for _, e in ipairs(list) do
            if type(e) == "table" and PositiveInt(e.uid) and e.uid > maxSeen then maxSeen = e.uid end
        end
    end)
    if n <= maxSeen then n = maxSeen + 1 end
    p.customNextUID = n + 1
    return n
end

-- 身分：同種類＋同主 ID（光環還要同 filter）。判重、窄蓋寬、池化都看這個。種族技能（還沒解析的那一筆）是 "racial"
function DB.CustomIdentity(e)
    if type(e) ~= "table" then return nil end
    local k = e.kind
    if k == "racial" then return "racial" end
    if k == "timer" then return type(e.key) == "string" and ("timer:" .. e.key) or nil end
    if k == "item" then return e.itemID ~= nil and ("item:" .. tostring(e.itemID)) or nil end
    if k == "slot" then return e.slot ~= nil and ("slot:" .. tostring(e.slot)) or nil end
    if k == "slotbuff" then
        if e.slot == nil then return nil end
        return "slotbuff:" .. tostring(e.slot) .. ":" .. tostring(PositiveInt(e.buff) and e.buff or 1)
    end
    if e.spellID == nil then return nil end
    if k == "spell" then return "spell:" .. tostring(e.spellID) end
    if k == "aura" then
        return "aura:" .. tostring(e.spellID) .. ":" .. (e.filter == "HARMFUL" and "HARMFUL" or "HELPFUL")
    end
    return nil
end

-- 這一筆在這個角色身上長什麼樣（純函式；opts 由呼叫端注入）：
--   opts.racial()        → 這個角色學會的種族技能 spellID（解不到 nil）
--   opts.isKnown(id)     → 學了沒（false ＝ 沒學；nil／true ＝ 學了或讀不到）
--   opts.timerDef(key)   → 內建冷卻的定義（Modules/Timers.lua 的 TM.Def；DB 是純函式、不碰 ns.Timers，由呼叫端注入）
--   opts.talentKnown(id) → 天賦點了沒（同 isKnown 的三態；天賦被動要問 Catalog.TalentKnown，SpellKnown 會誤判沒學）
-- 種族技能 ⇒ 換成一筆唯讀的法術「視圖」（metatable 讀原本那筆：bar、placeholder、overrides 都是原本的）；
-- 寬層（戰隊／職業／角色）的法術沒學而且 hideUnknown 沒關 ⇒ nil（整格不列）。回 nil ＝ 這個專精當它不存在。
-- 內建冷卻：key 不認得 ⇒ nil；寬層的天賦沒點（明確 false）而且 hideUnknown 沒關 ⇒ nil；專精層照列（問號格）
function DB.CustomView(raw, scope, opts)
    if type(raw) ~= "table" then return raw end
    opts = opts or {}
    if raw.kind == "timer" then
        local def = opts.timerDef and opts.timerDef(raw.key)
        if not def then return nil end
        if scope ~= "spec" and raw.hideUnknown ~= false and opts.talentKnown
            and opts.talentKnown(def.talent) == false then
            return nil
        end
        return raw
    end
    local view = raw
    if raw.kind == "racial" then
        local sid = opts.racial and opts.racial()
        if not PositiveInt(sid) then return nil end
        view = setmetatable({ kind = "spell", spellID = sid, racial = true }, { __index = raw })
    end
    if scope ~= "spec" and raw.hideUnknown ~= false and view.kind == "spell" and opts.isKnown then
        if opts.isKnown(view.spellID) == false then return nil end
    end
    return view
end

-- 四層合併（純函式）：sharedList／classList／charList／specList 是四層的原始清單，resolve(raw, scope) → 視圖或 nil
-- （省略 ＝ 原樣）。回傳 { { id, key, entry, raw, scope }, … }，戰隊 → 職業 → 角色 → 專精的順序接；
-- 同一個身分只留最窄那層的（同一層的重複照留，匯入帶進來的重複項由 Custom.Sync 自己分 key）。
-- 寬層沒有 uid 的壞資料跳過（沒有 id 可以放進順序表）。
function DB.ResolveScopes(sharedList, classList, charList, specList, resolve)
    local items = {}
    local function Take(list, scope)
        if type(list) ~= "table" then return end
        for i, raw in ipairs(list) do
            local key
            if scope == "spec" then
                key = i
            elseif type(raw) == "table" and PositiveInt(raw.uid) then
                key = raw.uid
            end
            if key then
                local view = raw
                if resolve then view = resolve(raw, scope) end
                if view ~= nil then
                    items[#items + 1] = { id = DB.ScopedCustomID(scope, key), key = key, entry = view, raw = raw, scope = scope }
                end
            end
        end
    end
    Take(sharedList, "shared")
    Take(classList, "class")
    Take(charList, "char")
    Take(specList, "spec")
    local RANK = DB.SCOPE_RANK
    local narrow = {}
    for _, it in ipairs(items) do
        local k = DB.CustomIdentity(it.entry)
        if k and (narrow[k] or 0) < RANK[it.scope] then narrow[k] = RANK[it.scope] end
    end
    local out = {}
    for _, it in ipairs(items) do
        local k = DB.CustomIdentity(it.entry)
        if not k or narrow[k] == RANK[it.scope] then out[#out + 1] = it end
    end
    return out
end

-- 遊戲裡的 opts：學了沒（Catalog.SpellKnown，讀不到當學了）、種族（UnitRace 的英文 token，明文才收）。
-- 同一幀裡重複問的結果共用（Catalog.Bar／Info 一輪排版會問很多次），換幀就作廢
local runtimeCache, runtimeAt = {}, nil
local function RuntimeFresh()
    local now = _G.GetTime and _G.GetTime() or nil
    if now == nil or now ~= runtimeAt then
        runtimeCache = {}
        runtimeAt = now
    end
    return runtimeCache
end

local function RuntimeKnown(spellID)
    local C = ns.Catalog
    if not (C and C.SpellKnown) then return nil end
    local cache = RuntimeFresh()
    local v = cache[spellID]
    if v == nil then
        v = C.SpellKnown(spellID) and true or false
        cache[spellID] = v
    end
    return v
end

local function PlayerRace()
    local fn = _G.UnitRace
    if type(fn) ~= "function" then return nil end
    local ok, _, race = pcall(fn, "player")
    if not ok or race == nil or (ns.IsSecret and ns.IsSecret(race)) then return nil end
    return type(race) == "string" and race or nil
end

local function RuntimeRacial()
    local P = ns.Presets
    if not (P and P.ResolveRacial) then return nil end
    local cache = RuntimeFresh()
    if cache.racial == nil then
        cache.racial = P.ResolveRacial(PlayerRace(), RuntimeKnown) or false
    end
    return cache.racial or nil
end

-- 天賦點了沒（Catalog.TalentKnown：讀不到 nil ⇒ 當點了）；同一幀共用，跟 RuntimeKnown 分開存（三態，key 帶前綴）
local function RuntimeTalent(spellID)
    local C = ns.Catalog
    if not (C and C.TalentKnown) then return nil end
    local cache = RuntimeFresh()
    local k = "t:" .. tostring(spellID)
    local v = cache[k]
    if v == nil then
        v = C.TalentKnown(spellID)
        if v == nil then v = "?" end
        cache[k] = v
    end
    if v == "?" then return nil end
    return v
end

local function RuntimeTimerDef(key)
    local T = ns.Timers
    return T and T.Def and T.Def(key) or nil
end

local RUNTIME_OPTS = { isKnown = RuntimeKnown, racial = RuntimeRacial, talentKnown = RuntimeTalent, timerDef = RuntimeTimerDef }
local function RuntimeView(raw, scope) return DB.CustomView(raw, scope, RUNTIME_OPTS) end

-- 這個專精實際生效的自訂項目（四層合併、窄蓋寬、種族技能解析、用不到的不列）。
-- Catalog／Custom.Sync／設定頁都吃這支；一輪排版會被叫很多次（每條的 Catalog.Bar、BarHasAuraSlot、CustomEntry…）。
-- memo（效能修整 E2）：DB.customGen、GetTime() 戳記、專精、設定檔四樣都相同才回上一次的表。
--   * customGen 是寫入出口的作廢點（見檔頭「寫入世代」）⇒ 同一幀寫完立刻讀也拿得到新的
--   * 每幀戳記是第二道保險，也讓「學了沒」「種族技能解成哪一個」（RuntimeFresh，本來就是每幀）跟著換幀重算
--   * 讀不到 GetTime（離線測試）⇒ 不 memo
-- ⚠ 回傳的表（連同裡面每一項）**呼叫端不准改**：同一幀的其他呼叫拿到的是同一張
local effMemo = { gen = -1 }
function DB.EffectiveCustom(specID)
    local p = ns.profile
    if not p then return {} end
    local spec = specID or ns.specID
    local now = _G.GetTime and _G.GetTime() or nil
    local m = effMemo
    if now ~= nil and m.at == now and m.gen == DB.customGen and m.spec == spec and m.profile == p then
        return m.list
    end
    local list = DB.ResolveScopes(DB.ScopeList("shared", false), DB.ScopeList("class", false),
        DB.ScopeList("char", false), DB.CustomList(false, specID), RuntimeView)
    m.gen, m.at, m.spec, m.profile, m.list = DB.customGen, now, spec, p, list
    return list
end

-- 生效清單裡的那一項（不在 ＝ nil）
function DB.EffectiveItem(id)
    if not DB.ParseCustomID(id) then return nil end
    for _, it in ipairs(DB.EffectiveCustom()) do
        if it.id == id then return it end
    end
    return nil
end

function DB.CustomList(create, specID)
    local sp = DB.SpecSpells(create, specID)
    if not sp then return nil end
    if create then DB.TouchCustom() end
    if type(sp.custom) ~= "table" then
        if not create then return nil end
        sp.custom = {}
    end
    return sp.custom
end

-- id → 存著的那一筆（原始資料，不是種族技能解析後的視圖；不存在回 nil）。第二個回傳值是編號
-- （專精層的陣列位置／寬層的 uid）、第三個是範圍
function DB.CustomEntry(id, specID)
    local scope, key = DB.ParseCustomID(id)
    if not scope then return nil end
    if scope == "spec" then
        local list = DB.CustomList(false, specID)
        local e = list and list[key]
        return type(e) == "table" and e or nil, key, scope
    end
    local e = FindUID(DB.ScopeList(scope, false), key)
    return e, key, scope
end

-- 這一層已經有同身分的（種族技能：這一層已經有一筆種族技能）→ 位置或 nil
function DB.FindInScope(scope, e, specID)
    local want = DB.CustomIdentity(e)
    if not want then return nil end
    for pos, x in ipairs(DB.ScopeList(scope, false, specID) or {}) do
        if DB.CustomIdentity(x) == want then return pos end
    end
    return nil
end

-- 這個專精現在看得到的（任何一層，窄蓋寬之後）裡有沒有同身分的 → 那一項的 id 或 nil
-- 種族技能那一筆：比原本那筆的種類（這一層有種族技能就算），也比解析後的法術
function DB.FindEffective(e)
    local want = DB.CustomIdentity(e)
    if not want then return nil end
    for _, it in ipairs(DB.EffectiveCustom()) do
        if DB.CustomIdentity(it.entry) == want or DB.CustomIdentity(it.raw) == want then return it.id end
    end
    return nil
end

-- 同一個專精裡已經有同樣的項目（同種類、同 ID、光環還要同 filter）。
-- 飾品欄增益（kind "slotbuff"）：id ＝ 槽、filter 的位置放第幾個增益（缺 ＝ 1）
function DB.FindCustom(kind, id, filter, specID)
    for i, e in ipairs(DB.CustomList(false, specID) or {}) do
        if type(e) == "table" and e.kind == kind then
            local same
            if kind == "item" then same = e.itemID == id
            elseif kind == "slot" then same = e.slot == id
            elseif kind == "slotbuff" then
                same = e.slot == id and (PositiveInt(e.buff) and e.buff or 1) == (PositiveInt(filter) and filter or 1)
            elseif kind == "timer" then same = e.key == id
            else same = e.spellID == id and (kind ~= "aura" or (e.filter or "HELPFUL") == (filter or "HELPFUL")) end
            if same then return i end
        end
    end
    return nil
end

-- 某一筆在 specID 那個專精裡有沒有同樣的（同種類同主 ID；光環還要同 filter）→ index 或 nil
function DB.FindCustomLike(e, specID)
    if type(e) ~= "table" then return nil end
    local id
    local filter = e.filter
    if e.kind == "item" then id = e.itemID
    elseif e.kind == "slot" then id = e.slot
    elseif e.kind == "slotbuff" then id, filter = e.slot, e.buff
    elseif e.kind == "timer" then id = e.key
    else id = e.spellID end
    if id == nil then return nil end
    return DB.FindCustom(e.kind, id, filter, specID)
end

-- 裝備欄位／飾品欄增益的槽對不對（其他種類一律 true）
local function SlotEntryOK(entry)
    local C = ns.Catalog
    if entry.kind == "slot" then return (C and C.CUSTOM_SLOTS[entry.slot]) == true end
    if entry.kind == "slotbuff" then
        return (C and C.SLOTBUFF_SLOTS and C.SLOTBUFF_SLOTS[entry.slot]) == true
            and (entry.buff == nil or PositiveInt(entry.buff))
    end
    return true
end

-- 新增（專精層），回傳 index（沒有專精 ⇒ nil）
function DB.AddCustom(entry)
    if type(entry) ~= "table" or not DB.CUSTOM_KINDS[entry.kind] then return nil end
    if not SlotEntryOK(entry) then return nil end
    local list = DB.CustomList(true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

-- 新增到某一層，回傳 id（"c:<i>"／"k:<uid>"／"p:<uid>"／"w:<uid>"；失敗 nil）。寬層的那一筆配 uid、hideUnknown 預設開
function DB.AddCustomTo(scope, entry)
    if scope == nil or scope == "spec" then
        local i = DB.AddCustom(entry)
        return i and DB.CustomID(i) or nil
    end
    if not DB.SCOPE_RANK[scope] then return nil end
    if type(entry) ~= "table" or not DB.CUSTOM_KINDS[entry.kind] then return nil end
    if not SlotEntryOK(entry) then return nil end
    if not ns.specID then return nil end          -- 跟專精層同一個前提（設定頁要先有專精）
    local list = DB.ScopeList(scope, true)
    if not list then return nil end
    entry.uid = DB.NextCustomUID()
    entry.overrides = nil
    if entry.hideUnknown == nil then entry.hideUnknown = true end
    list[#list + 1] = entry
    return DB.ScopedCustomID(scope, entry.uid)
end

function DB.SetCustomBar(id, bar)
    local e = DB.CustomEntry(id)
    if not e or type(bar) ~= "string" then return false end
    e.bar = bar
    DB.TouchCustom()                      -- Catalog.CustomInfo 的 memo 帶著 bar
    return true
end

-- 刪掉第 i 筆，後面的 "c:j" 全部改成 "c:(j-1)"（順序、隱藏、覆寫、群組）
local function Shift(id, removed)
    local j = DB.CustomIndex(id)
    if not j then return id end
    if j == removed then return false end
    if j > removed then return DB.CustomID(j - 1) end
    return id
end

-- 某個 id 在一個專精表裡改名（順序、隱藏、群組；覆寫一併搬，寬層的覆寫本來就不在這裡）。new ＝ nil ＝ 拿掉
local function RenameIn(sp, old, new)
    if type(sp) ~= "table" then return end
    if type(sp.order) == "table" then
        for bar, ids in pairs(sp.order) do
            if type(ids) == "table" then
                local out = {}
                for _, v in ipairs(ids) do
                    if v == old then
                        if new ~= nil then out[#out + 1] = new end
                    else
                        out[#out + 1] = v
                    end
                end
                sp.order[bar] = out
            end
        end
    end
    for _, field in ipairs({ "hidden", "groupOf", "overrides" }) do
        local t = sp[field]
        if type(t) == "table" and t[old] ~= nil then
            local v = t[old]
            t[old] = nil
            if new ~= nil then t[new] = v end
        end
    end
end

-- 所有專精表都拿掉這個 id（寬層的一筆刪掉／搬走時）
local function PurgeEverywhere(id, exceptSp)
    local p = ns.profile
    for _, sp in pairs(p and type(p.spells) == "table" and p.spells or {}) do
        if sp ~= exceptSp then RenameIn(sp, id, nil) end
    end
end

function DB.RemoveCustom(id, specID)
    local scope, key = DB.ParseCustomID(id)
    if DB.IsWideScope(scope) then
        -- 寬層：uid 穩定，不用挪位；所有專精的順序／隱藏／群組裡的這個 id 一起清掉（覆寫跟著那一筆走了）
        local list = DB.ScopeList(scope, false)
        local _, pos = FindUID(list, key)
        if not pos then return false end
        table.remove(list, pos)
        PurgeEverywhere(id)
        DB.TouchCustom()
        return true
    end
    local i = DB.CustomIndex(id)
    local sp = DB.SpecSpells(false, specID)
    local list = sp and type(sp.custom) == "table" and sp.custom
    if not (i and list and list[i] ~= nil) then return false end
    table.remove(list, i)
    if type(sp.order) == "table" then
        for bar, ids in pairs(sp.order) do
            if type(ids) == "table" then
                local out = {}
                for _, v in ipairs(ids) do
                    local nv = Shift(v, i)
                    if nv then out[#out + 1] = nv end
                end
                sp.order[bar] = out
            end
        end
    end
    for _, field in ipairs({ "hidden", "overrides", "groupOf" }) do
        local t = sp[field]
        if type(t) == "table" then
            local moved = {}
            for k, v in pairs(t) do
                if DB.CustomIndex(k) then moved[k] = v end
            end
            for k in pairs(moved) do t[k] = nil end
            for k, v in pairs(moved) do
                local nk = Shift(k, i)
                if nk then t[nk] = v end
            end
        end
    end
    DB.TouchCustom()                      -- 清單挪位、覆寫跟著挪
    return true
end

------------------------------------------------------------
-- 範圍切換：把一筆連覆寫搬到另一層（配新 id），回傳新 id；失敗 nil, 原因（"bad"｜"missing"｜"exists"）
--
--   * 專精 → 寬層：目前專精的順序／隱藏／群組裡的舊 id 換成新 id，覆寫從 spells[spec].overrides 搬到那一筆身上；
--     專精層那一筆照 RemoveCustom 拿掉（後面的 "c:j" 往前挪）
--   * 寬層 → 專精：只搬到**目前專精**（追加到尾端）；目前專精的舊 id 換成新 id，其他專精的舊 id 清掉
--     （其他專精就看不到了，設定頁會先問）
--   * 寬層 ↔ 寬層：配新 uid，所有專精的舊 id 換成新 id
--   目標層已經有同身分的 ⇒ "exists"（不合併、不動）。往寬搬時**其他專精**若已有同身分的自己那筆，
--   照「窄的蓋寬的」自然不會重複，不自動刪。
------------------------------------------------------------
function DB.MoveCustomScope(id, newScope)
    local scope, key = DB.ParseCustomID(id)
    if not scope or not DB.SCOPE_RANK[newScope] then return nil, "bad" end
    if scope == newScope then return id end
    local raw = DB.CustomEntry(id)
    if type(raw) ~= "table" then return nil, "missing" end
    if not ns.specID then return nil, "bad" end
    if DB.FindInScope(newScope, raw) then return nil, "exists" end

    local ov
    if scope == "spec" then
        local sp = DB.SpecSpells(false)
        ov = sp and type(sp.overrides) == "table" and sp.overrides[id] or nil
    else
        ov = raw.overrides
    end
    local copy = DeepCopy(raw)
    copy.uid, copy.overrides = nil, nil
    local hasOv = type(ov) == "table" and next(ov) ~= nil

    local newID
    if newScope == "spec" then
        local list = DB.CustomList(true)
        if not list then return nil, "bad" end
        list[#list + 1] = copy
        newID = DB.CustomID(#list)
    else
        local list = DB.ScopeList(newScope, true)
        if not list then return nil, "bad" end
        copy.uid = DB.NextCustomUID()
        if copy.hideUnknown == nil then copy.hideUnknown = true end
        if hasOv then copy.overrides = DeepCopy(ov) end
        list[#list + 1] = copy
        newID = DB.ScopedCustomID(newScope, copy.uid)
    end

    local cur = DB.SpecSpells(true)
    if scope == "spec" then
        -- 舊的覆寫已經搬到新那筆身上：先拿掉，RenameIn 才不會把它搬到新 id 底下
        if type(cur.overrides) == "table" then cur.overrides[id] = nil end
        RenameIn(cur, id, newID)
        DB.RemoveCustom(id)
        DB.TouchCustom()                  -- 覆寫跟著搬（RemoveCustom 也 +1，這裡寫明出口）
        return newID
    end
    -- 舊的在寬層
    if newScope == "spec" then
        RenameIn(cur, id, newID)
        if hasOv then cur.overrides[newID] = DeepCopy(ov) end
        PurgeEverywhere(id, cur)
    else
        local p = ns.profile
        for _, sp in pairs(type(p.spells) == "table" and p.spells or {}) do RenameIn(sp, id, newID) end
    end
    local list = DB.ScopeList(scope, false)
    local _, pos = FindUID(list, key)
    if pos then table.remove(list, pos) end
    DB.TouchCustom()                      -- 舊的拿掉、覆寫跟著搬
    return newID
end

------------------------------------------------------------
-- 複製到其他專精
--
-- 目前專精的第 id 筆深複製、追加到 spells[target].custom 尾端；它在目前專精的覆寫（overrides[id]）
-- 一併複製到目標的新 id 底下。bar 照抄（條是設定檔層、各專精共用）。
-- 目標已有同種類同主 ID（光環同 filter）⇒ 回 false 不動。成功回新的 index。
------------------------------------------------------------
function DB.CopyCustomEntry(id, targetSpecID)
    if targetSpecID == nil or targetSpecID == ns.specID then return false end
    if DB.ParseCustomID(id) ~= "spec" then return false end      -- 寬層本來就每個專精都看得到
    local e = DB.CustomEntry(id)
    if not e or not DB.CUSTOM_KINDS[e.kind] then return false end
    if DB.FindCustomLike(e, targetSpecID) then return false end
    local list = DB.CustomList(true, targetSpecID)
    if not list then return false end
    list[#list + 1] = DeepCopy(e)
    local n = #list
    local sp = DB.SpecSpells(false)
    local o = sp and type(sp.overrides) == "table" and sp.overrides[id]
    if type(o) == "table" and next(o) ~= nil then
        local tsp = DB.SpecSpells(true, targetSpecID)
        tsp.overrides[DB.CustomID(n)] = DeepCopy(o)
    end
    DB.TouchCustom()
    return n
end

-- 這個職業的專精：{ { id, name, icon }, … }（讀不到回空表）
function DB.ClassSpecs()
    local out = {}
    local num = GetNumSpecializations
    local info = GetSpecializationInfo
    if type(num) ~= "function" or type(info) ~= "function" then return out end
    local ok, n = pcall(num)
    if not ok or type(n) ~= "number" then return out end
    for i = 1, n do
        local ok2, id, name, _, icon = pcall(info, i)
        if ok2 and type(id) == "number" and id > 0 then
            out[#out + 1] = { id = id, name = type(name) == "string" and name or tostring(id), icon = icon }
        end
    end
    return out
end
