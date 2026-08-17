------------------------------------------------------------
-- uf.cache：單位資料快取
-- 唯一的消毒層——寫進 cache 的值保證全是明文，下游（顏色查表、tag 比較、
-- 條件式）可以放心做比較與查表。秘密值（curhp 等原始數字）不進 cache，
-- 由元件在使用點直接取用並餵給 C API。
------------------------------------------------------------
local _, ns = ...

ns.Cache = {}
local Cache = ns.Cache

local Desecret, ToBool, IsSecret = ns.Desecret, ns.ToBool, ns.IsSecret

local UnitName, UnitLevel = UnitName, UnitLevel
local UnitClass, UnitClassBase, UnitRace, UnitCreatureType = UnitClass, UnitClassBase, UnitRace, UnitCreatureType
local UnitIsPlayer, UnitPlayerControlled, UnitReaction = UnitIsPlayer, UnitPlayerControlled, UnitReaction
local UnitPowerType, UnitClassification = UnitPowerType, UnitClassification
local UnitIsDeadOrGhost, UnitIsGhost, UnitIsConnected = UnitIsDeadOrGhost, UnitIsGhost, UnitIsConnected
local UnitIsAFK, UnitIsDND, UnitIsTapDenied = UnitIsAFK, UnitIsDND, UnitIsTapDenied
local UnitCanAssist, UnitCanAttack, UnitIsEnemy = UnitCanAssist, UnitCanAttack, UnitIsEnemy
local UnitIsVisible, UnitAffectingCombat = UnitIsVisible, UnitAffectingCombat
local UnitHealthPercent, UnitPowerPercent = UnitHealthPercent, UnitPowerPercent

-- ⚠ pcall 的第一個參數一定要是「已經存在的函式」，不要現寫 function() end：
-- 這兩個函式落在每個血量／能量事件上，每次呼叫都新建一顆 closure 就是白配記憶體。
-- 值改用參數傳進去，語意跟原本抓 upvalue 完全一樣。
local function Eq(a, b) return a == b end
local function Hundredth(v) return v * 0.01 end

-- UnitReaction 在受限單位上可能回秘密值：用 pcall 逐一比對抽出明文
-- （比較錯誤可被 pcall 捕捉；布林測試的 taint error 不行，所以不能用別的寫法）
local function PlainReaction(unit)
    local r = UnitReaction(unit, "player")
    if r == nil then return nil end
    if not IsSecret(r) then return r end
    for i = 1, 10 do
        local ok, match = pcall(Eq, r, i)
        if ok and match then return i end
    end
    return nil
end

-- pcall 抽百分比（rawpct 可能是秘密值，* 0.01 需要逃逸）
local _scale = (CurveConstants and CurveConstants.ScaleTo100) or true
local function PlainFrac(rawpct, old)
    local ok, frac = pcall(Hundredth, rawpct)
    if ok and type(frac) == "number" then return frac end
    return old or 1
end

-- AFK / DND：可能對受限單位拋錯或回秘密 boolean
local function SafeFlag(fn, unit)
    if not fn then return nil end
    local ok, v = pcall(fn, unit)
    if not ok then return nil end
    return ToBool(v)
end

local function UpdateHealthFields(uf)
    local cache, unit = uf.cache, uf.unit
    cache.frachp = PlainFrac(UnitHealthPercent(unit, false, _scale), cache.frachp)
    cache.perchp = cache.frachp * 100
    cache.dead = UnitIsDeadOrGhost(unit) and true or false
    cache.ghost = UnitIsGhost(unit) and true or false
end

local function UpdatePowerFields(uf)
    local cache, unit = uf.cache, uf.unit
    local ptype = Desecret(UnitPowerType(unit), 0)
    cache.powertype = ptype
    cache.fracmp = PlainFrac(UnitPowerPercent(unit, ptype, false, _scale), cache.fracmp)
    cache.percmp = cache.fracmp * 100
end

local function UpdateDeathFields(uf)
    local cache, unit = uf.cache, uf.unit
    cache.offline = (not UnitIsConnected(unit)) and UnitIsPlayer(unit) and true or false
    cache.dead  = UnitIsDeadOrGhost(unit) and true or false
    cache.ghost = UnitIsGhost(unit) and true or false
end

------------------------------------------------------------
-- 身分欄位分兩組
--
-- 以前 info 與 reaction 兩個桶都跑同一支 17 個 API 的 UpdateIdentityFields。
-- 而 reaction 是被 UNIT_FACTION / UNIT_FLAGS / GROUP_ROSTER_UPDATE /
-- PARTY_LEADER_CHANGED 推的，那些事件裡名字、等級、種族職業一個都不會變。
-- 隊伍變動走 ns.RefreshAll("reaction") ⇒ 11 個框 × 17 個 API，其中一半是白工。
--
-- ⚠ 這裡省下的只有「cache 重讀」那一段。真正貴的元件重畫本來就已經細分過了
-- （Texts.Update 用 Tags.GetBuckets 算出的 f.buckets 逐條文字擋，pattern 是
--  [name] 的文字不會因為 reaction 而重畫）。所以這是筆小帳，不要期待它解決什麼。
--
-- 桶名與元件訂閱**完全不動**。cache 從不整體 wipe，沒重讀的欄位仍然是有效值。
--
--   name 組  名字／種族職業／等級／分類／是不是玩家   → info 桶
--   flag 組  陣營／PvP／AFK／可否協助攻擊／戰鬥中     → reaction 桶
------------------------------------------------------------
local function UpdateNameFields(uf)
    local cache, unit = uf.cache, uf.unit
    cache.name      = Desecret(UnitName(unit), "")
    cache.classFile = Desecret(UnitClassBase(unit), nil)
    cache.class     = Desecret((UnitClass(unit)), "")
    cache.race      = Desecret((UnitRace(unit)), "")
    cache.creaturetype = Desecret(UnitCreatureType(unit), "")
    -- isPlayer = 真玩家（種族／職業才有意義）。放這組是因為「一個單位是不是玩家」
    -- 不會中途改變，只有換人才會 —— 而換人時兩組都會跑。
    -- ⚠ UpdateFlagFields 的 cache.pc 讀它，所以 unitchanged 一定要先跑這組。
    cache.isPlayer  = ToBool(UnitIsPlayer(unit)) or false

    local lvl = Desecret(UnitLevel(unit), nil)
    if lvl == nil or lvl == -1 then
        cache.level = ns.db.global.classification.unknown or "??"
    else
        cache.level = lvl
    end

    local cls = Desecret(UnitClassification(unit), "normal")
    cache.classification = ns.db.global.classification[cls] or ""
end

local function UpdateFlagFields(uf)
    local cache, unit = uf.cache, uf.unit
    -- pc = 玩家陣營控制（含寵物，染色用）；isPlayer 由 UpdateNameFields 維護
    cache.pc        = cache.isPlayer or ToBool(UnitPlayerControlled(unit)) or false
    cache.reaction  = PlainReaction(unit)
    cache.afk       = SafeFlag(UnitIsAFK, unit) or false
    cache.dnd       = SafeFlag(UnitIsDND, unit) or false
    cache.tapped    = ToBool(UnitIsTapDenied(unit)) or false
    cache.assist    = ToBool(UnitCanAssist("player", unit)) or false
    cache.attackable = ToBool(UnitCanAttack("player", unit)) or false
    cache.hostile   = ToBool(UnitIsEnemy("player", unit)) or false
    cache.incombat  = ToBool(UnitAffectingCombat(unit)) or false
end

-- 超出距離。以前只看 UnitIsVisible（那其實是「有沒有載入」，不是距離），
-- 現在走 ns.Range 的探針技能判定，見那個檔的說明。
-- ⚠ 不再限定 assist 對象：敵人超出攻擊距離同樣算超出，tag 名字本來就叫 oor。
function Cache.IsOOR(uf)
    local cache, unit = uf.cache, uf.unit
    if unit == "player" or cache.dead or cache.offline then return false end
    -- 不可見（不同分流、遠到沒載入）一定算超出；秘密值時不下結論，往下問距離
    local vis = UnitIsVisible(unit)
    if not IsSecret(vis) and not vis then return true end
    return ns.Range.IsOut(unit)
end

function Cache.Update(uf, bucket)
    if bucket == "unitchanged" then
        -- 換人：全部重讀。⚠ name 一定要在 flag 之前（cache.pc 讀 cache.isPlayer）
        UpdateNameFields(uf)
        UpdateFlagFields(uf)
        UpdateHealthFields(uf)
        UpdatePowerFields(uf)
        UpdateDeathFields(uf)
    elseif bucket == "info" then
        UpdateNameFields(uf)
    elseif bucket == "reaction" then
        UpdateFlagFields(uf)
    elseif bucket == "health" then
        UpdateHealthFields(uf)
    elseif bucket == "power" then
        UpdatePowerFields(uf)
    elseif bucket == "powertype" then
        UpdatePowerFields(uf)
    elseif bucket == "death" then
        UpdateDeathFields(uf)
    end
end
