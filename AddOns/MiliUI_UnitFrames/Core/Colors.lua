------------------------------------------------------------
-- 顏色方法（讀 uf.cache 明文資料）
-- 簽名：fn(uf, edb, value01, choiceKey, alphaKey) → r, g, b, a
--   value01  : 0-1（血量顏色的預覽路內插用，通常傳 cache.frachp）
--   choiceKey: edb 內自訂色欄位名（solid 用，預設 "bgColor"）
--   alphaKey : edb 內 alpha 欄位名（如 "barAlpha"/"bgAlpha"）
-- cache 已在 Cache.lua 消毒完畢，這裡可以放心做比較與查表。
------------------------------------------------------------
local _, ns = ...

ns.Colors = {}
local Colors = ns.Colors
local methods = {}

local WHITE = { r = 1, g = 1, b = 1, a = 1 }

local function alphaOf(edb, alphaKey, fallback)
    local a = alphaKey and edb and edb[alphaKey]
    if a == nil then a = fallback end
    return a or 1
end

local function G()   -- 全域色票
    return ns.db.global.colors
end

-- 「暗色」變體共用的守衛。秘密值不能做算術，而上色法是使用者自由指定、彼此還會
-- 互相委派的（classreactiondark → classdark／reactiondark），所以不要只在會出事的
-- 那一支加閘 —— 七個變體一律走這裡。
-- 遇到秘密分量就原色回傳：顏色沒變暗，總比整條 Refresh 拋錯好。
local function Dim(r, g, b, a)
    if ns.IsSecret(r) then return r, g, b, a end
    return r * 0.3, g * 0.3, b * 0.3, a
end

-- 職業色：明文查表；受限身分的玩家（PvP 敵方玩家等）class 是秘密 → 走官方顯示管道
-- C_ClassColor.GetClassColor(secretClass) 拿色物件，分量是秘密，只能餵貼圖 SetVertexColor
-- （Platynator Colors.lua:290 同法）。呼叫端要用 IsSecret 判斷後決定能不能做暗色/塞文字色碼。
local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
methods.class = function(uf, edb, value, choice, alphaKey)
    local a = alphaOf(edb, alphaKey, 1)
    local c = uf.cache.classFile and RAID_CLASS_COLORS[uf.cache.classFile]
    if c then return c.r, c.g, c.b, a end
    -- 寵物／載具沒有自己的職業（UnitClassBase 回 nil），吃主人的 —— 少了這段就會一路
    -- 掉到最後的 WHITE，寵物框變成灰白的沒有職業色（Cell 也是給主人的職業色）
    local owner = uf.cache.ownerClass
    if owner then
        c = RAID_CLASS_COLORS[owner]
        if c then return c.r, c.g, c.b, a end
    end
    if uf.cache.pc and not uf.isPreview and GetClassColor then
        local raw = UnitClassBase(uf.unit)
        if raw ~= nil and ns.IsSecret(raw) then          -- nil-ness 對秘密值可讀
            local ok, col = pcall(GetClassColor, raw)
            if ok and col then return col.r, col.g, col.b, a end
        end
    end
    return WHITE.r, WHITE.g, WHITE.b, a
end
methods.classdark = function(uf, edb, value, choice, alphaKey)
    return Dim(methods.class(uf, edb, value, choice, alphaKey))
end

-- ⚠ cache.reaction 在受限單位上可能抽不出明文（nil）。以前這種情況直接落到 WHITE，
-- 於是副本裡的敵人血條變純白、看不出敵我 —— 而 cache.hostile / cache.attackable
-- 就在同一支 UpdateFlagFields 裡算好了，沒被拿來用。
-- 退階順序：明文 reaction → 敵對(2) → 可攻擊但不敵對＝中立(4) → 才是 WHITE。
-- 旗標本身也抽不出來時兩個都是 false，結果跟改動前一樣，不會憑空塗成友好色。
methods.reaction = function(uf, edb, value, choice, alphaKey)
    local cache = uf.cache
    local c = G().reaction[cache.reaction or 0]
    if not c then
        local pal = G().reaction
        c = (cache.hostile and pal[2]) or (cache.attackable and pal[4]) or WHITE
    end
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, 1)
end
methods.reactiondark = function(uf, edb, value, choice, alphaKey)
    local r, g, b, a = methods.reaction(uf, edb, value, choice, alphaKey)
    return Dim(r, g, b, a)
end

-- 玩家用職業色、NPC/敵對(2)/中立(4)用陣營色
--
-- ⚠ 自己的寵物／載具例外，一律走職業色（它們有 ownerClass = 主人的職業）。
-- 不排除的話，寵物的 UnitReaction 只要回 4（中立）就會被塗成陣營黃，而
-- 「自己的寵物用中立色」沒有任何意義 —— 而且 classreaction 會在這裡短路，
-- 根本走不到 methods.class 的 ownerClass 那段。
local function reactish(cache)
    if cache.ownerClass then return false end
    return not cache.pc or cache.reaction == 2 or cache.reaction == 4
end
methods.classreaction = function(uf, edb, value, choice, alphaKey)
    return methods[reactish(uf.cache) and "reaction" or "class"](uf, edb, value, choice, alphaKey)
end
methods.classreactiondark = function(uf, edb, value, choice, alphaKey)
    return methods[reactish(uf.cache) and "reactiondark" or "classdark"](uf, edb, value, choice, alphaKey)
end

methods.reactionnpc = function(uf, edb, value, choice, alphaKey)
    return methods[uf.cache.pc and "class" or "reaction"](uf, edb, value, choice, alphaKey)
end
methods.reactionnpcdark = function(uf, edb, value, choice, alphaKey)
    return methods[uf.cache.pc and "classdark" or "reactiondark"](uf, edb, value, choice, alphaKey)
end

local GetDifficultyColor = GetQuestDifficultyColor or function() return WHITE end
methods.difficulty = function(uf, edb, value, choice, alphaKey)
    local lvl = uf.cache.level
    local c = GetDifficultyColor((type(lvl) ~= "number" and 999) or lvl or 1)
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, 1)
end
methods.difficultydark = function(uf, edb, value, choice, alphaKey)
    local r, g, b, a = methods.difficulty(uf, edb, value, choice, alphaKey)
    return Dim(r, g, b, a)
end

-- Enum.PowerType index → PowerBarColor 的字串鍵（數字鍵不一定存在，缺了會錯退成法力藍）
local POWER_TOKEN = {
    [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [6] = "RUNIC_POWER",
    [8] = "LUNAR_POWER", [11] = "MAELSTROM", [13] = "INSANITY", [17] = "FURY", [18] = "PAIN",
}
methods.power = function(uf, edb, value, choice, alphaKey)
    local ptype = uf.cache.powertype or 0
    local c = G().power[ptype]
        or (PowerBarColor and (PowerBarColor[ptype] or PowerBarColor[POWER_TOKEN[ptype] or ""]))
        or G().power[0]
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, 1)
end
methods.powerdark = function(uf, edb, value, choice, alphaKey)
    local r, g, b, a = methods.power(uf, edb, value, choice, alphaKey)
    return Dim(r, g, b, a)
end

methods.hpgreen = function(uf, edb, value, choice, alphaKey)
    local c = G().hpGreen
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, c.a)
end
methods.hpgreendark = function(uf, edb, value, choice, alphaKey)
    local r, g, b, a = methods.hpgreen(uf, edb, value, choice, alphaKey)
    return Dim(r, g, b, a)
end
methods.hpred = function(uf, edb, value, choice, alphaKey)
    local c = G().hpRed
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, c.a)
end
methods.hpreddark = function(uf, edb, value, choice, alphaKey)
    local r, g, b, a = methods.hpred(uf, edb, value, choice, alphaKey)
    return Dim(r, g, b, a)
end

------------------------------------------------------------
-- 血量顏色：把顏色曲線交給引擎求值
--
-- ⚠ 這是整個檔案裡唯一**不讀血量**的血量相關上色。舊的 hpthreshold 要先把百分比
-- 抽成明文才能內插，而受限單位（副本／M+／團隊）抽不出來 ⇒ 顏色凍在上一個值，
-- 或者從沒抽到過就一路顯示滿血色。改成交一條曲線給 UnitHealthPercent，由引擎在
-- C 端求值，回傳的顏色分量可能是秘密值 —— 直接餵 SetStatusBarColor / SetVertexColor
-- 就好，**不要再對它做任何算術**（所以沒有 dark 變體，要暗就把顏色點調暗）。
--
-- 曲線物件共用一顆、每次求值重新加點：ClearPoints + 幾個 AddPoint 很便宜，
-- 省掉「設定改了要失效重建」那一整套。
------------------------------------------------------------
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local healthCurve

-- 點要照百分比排序才餵得進曲線。就地排序：點很少，而且排過的下次是 no-op
local function SortedPoints()
    local cfg = G().healthColor
    if type(cfg) ~= "table" or type(cfg.points) ~= "table" or #cfg.points == 0 then
        return nil, nil
    end
    table.sort(cfg.points, function(x, y) return (x.pct or 0) < (y.pct or 0) end)
    return cfg.points, cfg.mode
end

local function HealthCurve()
    if not (CreateColorCurve and CreateColor) then return nil end
    local points, mode = SortedPoints()
    if not points then return nil end

    if not healthCurve then healthCurve = CreateColorCurve() end
    local T = Enum.LuaCurveType
    if T then
        healthCurve:SetType((mode == "step" and T.Step) or T.Linear or T.Step)
    end
    healthCurve:ClearPoints()
    for _, p in ipairs(points) do
        local c = p.color or WHITE
        healthCurve:AddPoint(p.pct or 0, CreateColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1))
    end
    return healthCurve
end

-- 預覽孿生用：血量是假的明文，曲線路會去讀**真實玩家**的血，所以這裡自己內插。
-- 這條全程明文，不受秘密值限制。
local function PlainEval(frac)
    local points, mode = SortedPoints()
    if not points then return nil end
    local pct = (frac or 1) * 100
    local prev
    for _, p in ipairs(points) do
        local at = p.pct or 0
        if pct <= at then
            local c = p.color or WHITE
            if not prev or mode == "step" then return c.r, c.g, c.b end
            local pc, span = prev.color or WHITE, at - (prev.pct or 0)
            local t = span > 0 and (pct - (prev.pct or 0)) / span or 0
            return pc.r + (c.r - pc.r) * t,
                   pc.g + (c.g - pc.g) * t,
                   pc.b + (c.b - pc.b) * t
        end
        prev = p
    end
    local c = (prev and prev.color) or WHITE
    return c.r, c.g, c.b
end

methods.healthcolor = function(uf, edb, value, choice, alphaKey)
    local a = alphaOf(edb, alphaKey, 1)

    if uf.isPreview then
        local r, g, b = PlainEval(value or uf.cache.frachp or 1)
        if r then return r, g, b, a end
        return WHITE.r, WHITE.g, WHITE.b, a
    end

    local curve = HealthCurve()
    if curve then
        -- 第二個參數留 nil ＝ usePredicted 用官方預設（true）
        local ok, col = pcall(UnitHealthPercent, uf.unit, nil, curve)
        if ok and col then return col.r, col.g, col.b, a end
    end
    return WHITE.r, WHITE.g, WHITE.b, a
end

methods.gray = function(uf, edb, value, choice, alphaKey)
    local c = G().gray
    return c.r, c.g, c.b, alphaOf(edb, alphaKey, c.a)
end

methods.solid = function(uf, edb, value, choice, alphaKey)
    local c = edb and edb[choice or "bgColor"]
    if c then
        return c.r, c.g, c.b, alphaOf(edb, alphaKey, c.a)
    end
    return 1, 1, 1, 1
end
methods.custom = methods.solid

methods.hide = function() return 0, 0, 0, 0 end

Colors.methods = methods

-- 對外開放：讓其他模組登記自訂的顏色方法
function Colors.Register(name, fn)
    methods[name] = fn
end

function Colors.Get(method, uf, edb, value01, choiceKey, alphaKey)
    return (methods[method or "hide"] or methods.hide)(uf, edb, value01, choiceKey, alphaKey)
end
