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

local function UpdateIdentityFields(uf)
    local cache, unit = uf.cache, uf.unit
    cache.name      = Desecret(UnitName(unit), "")
    cache.classFile = Desecret(UnitClassBase(unit), nil)
    cache.class     = Desecret((UnitClass(unit)), "")
    cache.race      = Desecret((UnitRace(unit)), "")
    cache.creaturetype = Desecret(UnitCreatureType(unit), "")
    -- isPlayer = 真玩家（種族／職業才有意義）；pc = 玩家陣營控制（含寵物，染色用）
    cache.isPlayer  = ToBool(UnitIsPlayer(unit)) or false
    cache.pc        = cache.isPlayer or ToBool(UnitPlayerControlled(unit)) or false
    cache.reaction  = PlainReaction(unit)
    cache.afk       = SafeFlag(UnitIsAFK, unit) or false
    cache.dnd       = SafeFlag(UnitIsDND, unit) or false
    cache.tapped    = ToBool(UnitIsTapDenied(unit)) or false
    cache.assist    = ToBool(UnitCanAssist("player", unit)) or false
    cache.attackable = ToBool(UnitCanAttack("player", unit)) or false
    cache.hostile   = ToBool(UnitIsEnemy("player", unit)) or false
    cache.incombat  = ToBool(UnitAffectingCombat(unit)) or false

    local lvl = Desecret(UnitLevel(unit), nil)
    if lvl == nil or lvl == -1 then
        cache.level = ns.db.global.classification.unknown or "??"
    else
        cache.level = lvl
    end

    local cls = Desecret(UnitClassification(unit), "normal")
    cache.classification = ns.db.global.classification[cls] or ""
end

-- 超出距離：assist 對象且不可見（UnitIsVisible 秘密時當可見，避免誤灰）
function Cache.IsOOR(uf)
    local cache, unit = uf.cache, uf.unit
    if unit == "player" or not cache.assist or cache.dead or cache.offline then
        return false
    end
    local vis = UnitIsVisible(unit)
    if IsSecret(vis) then return false end
    return not vis
end

function Cache.Update(uf, bucket)
    if bucket == "identity" then
        UpdateIdentityFields(uf)
        UpdateHealthFields(uf)
        UpdatePowerFields(uf)
        UpdateDeathFields(uf)
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
