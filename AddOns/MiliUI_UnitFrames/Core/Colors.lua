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

-- 前向宣告：methods.classreaction 排在定義之前就用到它
-- （檔案層的 local 一定要先宣告，不然抓到的是同名全域 nil）
local ClassOrReaction

-- 職業色的三個分量（**可能是秘密值**），拿不到回 nil。
--
-- ⚠ cache.classFile 只在 cache.isPlayer 為真時才填，而 isPlayer 對**身分受限**的單位
-- （PvP 敵方玩家、不同隊的路人）抽不出明文 ⇒ 存的是 false ⇒ classFile 是 nil。
-- 這就是「PvP 看不到職業色」的成因：不是查不到職業，是我們自己先把路封了。
-- 所以受限時直接問 UnitClassBase 拿秘密字串，交給官方顯示管道換成顏色。
--
-- ⚠⚠ 這支**不保證回來的是玩家的**顏色：UnitClassBase 對非玩家會回一個假職業
-- （惡魔僕從回 ROGUE，見筆記 wow-unitclassbase-npc-returns-rogue）。
-- 呼叫端必須自己決定「這單位算不算玩家」——見下面的 ClassOrReaction。
local function ClassRGB(uf)
    local c = uf.cache.classFile and RAID_CLASS_COLORS[uf.cache.classFile]
    if c then return c.r, c.g, c.b end
    -- 寵物／載具沒有自己的職業，吃主人的（Cell 也是給主人的職業色）
    local owner = uf.cache.ownerClass
    if owner then
        c = RAID_CLASS_COLORS[owner]
        if c then return c.r, c.g, c.b end
    end
    if uf.isPreview or not GetClassColor then return nil end
    local raw = UnitClassBase(uf.unit)
    if raw == nil then return nil end                -- nil-ness 對秘密值可讀
    local ok, col = pcall(GetClassColor, raw)
    if ok and col then return col.r, col.g, col.b end
    return nil
end

-- 職業色；拿不到就退陣營色。
-- ⚠ 以前這裡退的是 WHITE —— 症狀是「上色方式選職業，打 NPC 時血條整條純白」。
-- 陣營色至少還分得出敵我，比純白有用。
methods.class = function(uf, edb, value, choice, alphaKey)
    local a = alphaOf(edb, alphaKey, 1)
    local r, g, b = ClassRGB(uf)
    if r then return r, g, b, a end
    return methods.reaction(uf, edb, value, choice, alphaKey)
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
-- ⚠ 這裡**不能**再用 `not cache.pc` 當「不是玩家」：pc 對受限單位是 false，
-- 於是不同隊的友方玩家（路人）也被當成 NPC 塗成陣營色。改成只認明文的敵對／中立，
-- 其餘一律交給 ClassOrReaction —— 它自己會用引擎的秘密布林分辨玩家與小怪。
local function reactish(cache)
    if cache.ownerClass then return false end
    return cache.reaction == 2 or cache.reaction == 4
end
methods.classreaction = function(uf, edb, value, choice, alphaKey)
    if reactish(uf.cache) then
        return methods.reaction(uf, edb, value, choice, alphaKey)
    end
    return ClassOrReaction(uf, edb, value, choice, alphaKey)
end
methods.classreactiondark = function(uf, edb, value, choice, alphaKey)
    if reactish(uf.cache) then
        return methods.reactiondark(uf, edb, value, choice, alphaKey)
    end
    return Dim(ClassOrReaction(uf, edb, value, choice, alphaKey))
end

------------------------------------------------------------
-- 職業優先：是玩家就職業色，其餘（小怪、寵物…）陣營色
--
-- ⚠ 「是不是玩家」在受限單位上是**秘密布林**，Lua 不能 if 它。三段處理：
--   明文 false → 直接陣營色
--   明文 true  → 直接職業色（保持明文，dark 變體才暗得下去）
--   抽不出來   → 兩組顏色都算好，交給引擎用那顆秘密布林挑
--                （C_CurveUtil.EvaluateColorValueFromBoolean，ns.Curves.BoolColor 包好的）
-- 第三段正是 PvP 敵方玩家與路人會走的那條 —— 也只有這條救得到「職業色出不來」。
------------------------------------------------------------
ClassOrReaction = function(uf, edb, value, choice, alphaKey)
    local a = alphaOf(edb, alphaKey, 1)
    -- 自己的寵物／載具直接吃主人職業色，不必問它是不是玩家（它本來就不是）
    if uf.cache.ownerClass then
        local c = RAID_CLASS_COLORS[uf.cache.ownerClass]
        if c then return c.r, c.g, c.b, a end
    end

    local rr, rg, rb = methods.reaction(uf, edb, value, choice, alphaKey)
    if uf.isPreview then
        if uf.cache.isPlayer then
            local cr, cg, cb = ClassRGB(uf)
            if cr then return cr, cg, cb, a end
        end
        return rr, rg, rb, a
    end

    local plain = ns.ToBool(UnitIsPlayer(uf.unit))
    if plain == false then return rr, rg, rb, a end

    local cr, cg, cb = ClassRGB(uf)
    if not cr then return rr, rg, rb, a end
    if plain == true then return cr, cg, cb, a end

    local r, g, b = ns.Curves.BoolColor(UnitIsPlayer(uf.unit), cr, cg, cb, rr, rg, rb)
    return r, g, b, a
end

methods.classfirst = ClassOrReaction
methods.classfirstdark = function(uf, edb, value, choice, alphaKey)
    return Dim(ClassOrReaction(uf, edb, value, choice, alphaKey))
end

-- 舊名，語意相同（沒出現在設定下拉裡，留著給既有設定檔用）
methods.reactionnpc = ClassOrReaction
methods.reactionnpcdark = methods.classfirstdark

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
-- 閾值上色：血量低於門檻就換色，蓋過該單位血條選的任何一種上色方式
--
-- 設定在**每個單位的血條**上（edb.thresholdEnabled / edb.thresholds），可以放
-- 好幾個門檻，愈低的愈優先：例如 50% 橘、20% 紅 —— 20 以下紅、20~50 橘、
-- 50 以上維持原色。
--
-- ⚠ 判斷交給引擎，插件端不讀血量。受限單位（副本／M+／團隊）的血量是秘密值，
-- 自己抽明文抽不到就只能用舊值或猜，顏色會凍住。改成餵一條 Step 曲線給
-- UnitHealthPercent，由 C 端決定落在哪一段。門檻由低到高排序後：
--     (0,      最低門檻的顏色)
--     (t1,     第二低門檻的顏色)
--     ...
--     (t最高,  原本的顏色)
-- Step ＝取「最後一個 x ≤ 目前血量」的點，所以每一段都吃到正確的顏色。
--
-- ⚠⚠ 曲線的 x 軸是**原生的 0~1 血量比例**，不是 0~100。餵 0/50/100 的話所有值都
-- 落在第一個點上 ⇒ 整條血條永遠是第一個點的顏色（實測：野外全紅）。
------------------------------------------------------------
local CreateColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve
local thresholdCurve

-- 由低到高。就地排序 edb.thresholds，排過的下次是 no-op
local function SortedThresholds(edb)
    local list = edb and edb.thresholds
    if type(list) ~= "table" or #list == 0 then return nil end
    table.sort(list, function(x, y) return (x.pct or 0) < (y.pct or 0) end)
    return list
end

function Colors.Threshold(uf, edb, r, g, b, a)
    if not (edb and edb.thresholdEnabled) then return r, g, b, a end
    local list = SortedThresholds(edb)
    if not list then return r, g, b, a end

    -- 預覽孿生的血量是假的明文，而曲線路會去讀**真實玩家**的血 → 自己判斷
    if uf.isPreview then
        local pct = (uf.cache.frachp or 1) * 100
        for _, t in ipairs(list) do
            if pct < (t.pct or 0) then
                local c = t.color or WHITE
                return c.r, c.g, c.b, a
            end
        end
        return r, g, b, a
    end

    if not (CreateColorCurve and CreateColor) then return r, g, b, a end
    -- ⚠ 原色要當成曲線的最後一個點餵進去，所以它必須讀得出來。職業色在受限單位上
    -- 是秘密顏色（C_ClassColor 那條路）⇒ 這種情況放棄套用、維持原色，
    -- 不要拿秘密值去組曲線。
    if ns.IsSecret(r) then return r, g, b, a end

    if not thresholdCurve then thresholdCurve = CreateColorCurve() end
    local T = Enum.LuaCurveType
    if T and T.Step then thresholdCurve:SetType(T.Step) end
    thresholdCurve:ClearPoints()

    -- 0 那個點吃最低門檻的顏色；第 i 個門檻的點吃「下一個門檻」的顏色；
    -- 最高門檻的點吃原色
    local first = (list[1] and list[1].color) or WHITE
    thresholdCurve:AddPoint(0, CreateColor(first.r, first.g, first.b, 1))
    for i = 1, #list do
        local nextC = list[i + 1] and list[i + 1].color
        local x = (list[i].pct or 0) / 100
        if nextC then
            thresholdCurve:AddPoint(x, CreateColor(nextC.r, nextC.g, nextC.b, 1))
        else
            thresholdCurve:AddPoint(x, CreateColor(r, g, b, 1))
        end
    end

    local ok, col = pcall(UnitHealthPercent, uf.unit, nil, thresholdCurve)
    if ok and col then return col.r, col.g, col.b, a end
    return r, g, b, a
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
    local fn = methods[method or "hide"]
    -- ⚠ 認不得的名字**不要**退回 hide —— 那是全透明，症狀是「血條整條消失」，
    -- 而原因（設定檔留著一個已經改名／移除的方式）完全看不出來。設定值是 nil
    -- 才當成刻意隱藏；是字串但查不到就給一個看得見的顏色。
    if not fn then fn = (method == nil) and methods.hide or methods.hpgreen end
    return fn(uf, edb, value01, choiceKey, alphaKey)
end
