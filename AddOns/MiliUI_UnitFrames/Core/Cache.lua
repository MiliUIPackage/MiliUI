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
local UnitIsUnit = UnitIsUnit
local UnitPowerType, UnitClassification = UnitPowerType, UnitClassification
local UnitIsDeadOrGhost, UnitIsGhost, UnitIsConnected = UnitIsDeadOrGhost, UnitIsGhost, UnitIsConnected
local UnitIsAFK, UnitIsDND, UnitIsTapDenied = UnitIsAFK, UnitIsDND, UnitIsTapDenied
local UnitCanAssist, UnitCanAttack, UnitIsEnemy = UnitCanAssist, UnitCanAttack, UnitIsEnemy
local UnitIsVisible, UnitAffectingCombat = UnitIsVisible, UnitAffectingCombat
local UnitHealthPercent, UnitPowerPercent = UnitHealthPercent, UnitPowerPercent

-- ⚠ pcall 的第一個參數一定要是「已經存在的函式」，不要現寫 function() end：
-- 這支落在每個陣營更新上，每次呼叫都新建一顆 closure 就是白配記憶體。
-- 值改用參數傳進去，語意跟原本抓 upvalue 完全一樣。
local function Eq(a, b) return a == b end

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

-- 抽百分比：ScaleTo100 曲線在**沒受限**的單位上回明文 0-100，受限單位（副本／競技場
-- 裡的敵對玩家等）仍然是秘密數字，乘 0.01 會被擋下來。
--
-- ⚠ 這裡**先問再算**，不要用 pcall 去試乘法。被封鎖的算術是一顆真的 Lua error：
-- 它落在血量／能量事件的熱路徑上（受限單位每次更新丟一顆），而且會在 taint.log
-- 裡刷出「An attempt to perform arithmetic on a secret value was blocked because of
-- taint from MiliUI_UnitFrames」—— 看起來像我們污染了什麼，其實是自己故意撞的。
-- issecretvalue 是免費的查詢，語意跟原本完全一樣（上面 PlainReaction 就是這個寫法）。
--
-- 第三個參數是 curve 物件（health 是第 3、power 是第 4 位）。備援不能是 `or true` ——
-- 那會把布林塞進 curve 的位置。拿不到就傳 nil，讓引擎回未經曲線的百分比。
local _scale = CurveConstants and CurveConstants.ScaleTo100
local function PlainFrac(rawpct, old)
    if type(rawpct) == "number" and not IsSecret(rawpct) then
        return rawpct * 0.01
    end
    -- 問不到就沿用上一次的值（開場沒有舊值就當滿）。這裡只餵漸層上色，
    -- 玩家看到的 [perchp] 文字走 Core/Tags.lua 的曲線路徑，不受影響。
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
    -- ⚠ 第二個參數是 **usePredicted**，官方預設就是 true（引擎用戰鬥記錄補上伺服器
    -- 還沒確認的傷害，值比較即時）。這裡原本傳 false —— 看起來是照抄下面那行
    -- UnitPowerPercent 的位置，但**那個位置在能量那支是 unmodified**，false 才對。
    -- 傳 false 的後果：百分比比暴雪自己的框與名條慢一拍，猛烈掉血時差距很明顯
    -- （玩家回報「數據不準」就是拿名條對比出來的）。
    -- 這個布林**不控制秘密值**，決定型別的是第三個參數 curve。
    cache.frachp = PlainFrac(UnitHealthPercent(unit, true, _scale), cache.frachp)
    cache.perchp = cache.frachp * 100
    cache.dead = UnitIsDeadOrGhost(unit) and true or false
    cache.ghost = UnitIsGhost(unit) and true or false
end

local function UpdatePowerFields(uf)
    local cache, unit = uf.cache, uf.unit
    -- ⚠ 抽不出明文時要留 nil，**不要**退成 0 —— 0 就是 MANA，受限的怒氣／能量怪會被
    -- 當成法力：UnitPowerPercent 會照法力去算（[percmp] 顯示錯的資源），顏色也變法力藍。
    -- 傳 nil 進 UnitPowerPercent 是讓引擎自己解析單位當前的資源；讀 cache.powertype
    -- 的三處（Colors.power / ClassPower / Tags）本來就都寫成 `or 0`，沒有回歸。
    local ptype = Desecret(UnitPowerType(unit))
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
------------------------------------------------------------
-- 寵物／載具的「主人職業」
--
-- 寵物沒有自己的職業：`UnitClassBase("pet")` 回 nil，所以 methods.class 一路掉到
-- 最後的 WHITE —— 症狀是寵物框看起來是灰白的，完全沒有職業色。而玩家的直覺
-- （以及 Cell 的做法）是「我的寵物要吃我的職業色」。
--
-- 只認得「主人一定是玩家自己」這幾種情況。**別人的寵物查不到主人**（沒有 owner API），
-- 那種就維持原本行為，不要瞎猜。
local function OwnerClassOf(uf)
    if uf.baseUnit == "pet" then return ns.playerClass end
    local unit = uf.unit
    if unit == "pet" or unit == "vehicle" then return ns.playerClass end
    -- 把自己的寵物設成目標／專注／目標的目標時也算（明文為真才算，秘密值不下結論）
    local same = UnitIsUnit(unit, "pet")
    if not IsSecret(same) and same then return ns.playerClass end
    return nil
end

------------------------------------------------------------
-- 自己寵物的專精 specID（狂野 74／狡詐 79／堅韌 81），給 methods.petspec 用
--
-- 只有獵人寵物有專精；術士惡魔、死騎食屍鬼等問下去是 nil／0 ⇒ 回 nil，
-- 上色那邊退主人職業色。專精 API 讀的是玩家自己的資料，不是秘密值，
-- 但照樣防：pcall ＋ IsSecret，拿不到就當沒有。
------------------------------------------------------------
local CSI = C_SpecializationInfo
local GetSpecIndex = (CSI and CSI.GetSpecialization) or GetSpecialization
local GetSpecInfo  = (CSI and CSI.GetSpecializationInfo) or GetSpecializationInfo

local function PlainPositive(ok, v)
    if not ok or IsSecret(v) or type(v) ~= "number" or v < 1 then return nil end
    return v
end

function Cache.PlayerPetSpec()
    if not (GetSpecIndex and GetSpecInfo) then return nil end
    -- (isInspect, isPet)。GetSpecializationInfo 的 isInspect 不可為 nil，要明寫 false
    local idx = PlainPositive(pcall(GetSpecIndex, false, true))
    if not idx then return nil end
    return PlainPositive(pcall(GetSpecInfo, idx, false, true))
end

-- ⚠ 專精 API 問的是「玩家的寵物欄」，跟 unit token 無關 —— 所以要先確定這個框畫的
-- 真的是那隻寵物，不然目標框選到隨便一隻怪也會被塗上你寵物的專精色。
-- 呼叫端已經用 ownerClass 閘過（主人是自己），這裡再排除載具：
-- 載具坐在寵物欄（見 Core/UnitFrame.lua 的 ResolveUnit），有載具介面時 "pet" 指的是
-- 載具，專精 API 卻可能還回獵人寵物那份。
local function PetSpecOf(uf)
    local unit = uf.unit
    if unit == "vehicle" then return nil end
    if unit ~= "pet" then
        local same = UnitIsUnit(unit, "pet")
        if IsSecret(same) or not same then return nil end
    end
    if UnitHasVehicleUI and ToBool(UnitHasVehicleUI("player")) then return nil end
    return Cache.PlayerPetSpec()
end

local function UpdateNameFields(uf)
    local cache, unit = uf.cache, uf.unit
    cache.name      = Desecret(UnitName(unit), "")
    cache.creaturetype = Desecret(UnitCreatureType(unit), "")
    -- isPlayer = 真玩家（種族／職業才有意義）。放這組是因為「一個單位是不是玩家」
    -- 不會中途改變，只有換人才會 —— 而換人時兩組都會跑。
    -- ⚠ UpdateFlagFields 的 cache.pc 讀它，所以 unitchanged 一定要先跑這組。
    -- ⚠ 也必須排在下面三個之前：它們拿它當閘。
    cache.isPlayer  = ToBool(UnitIsPlayer(unit)) or false

    ------------------------------------------------------------
    -- ⚠⚠ 職業／種族只對「真玩家」有意義，非玩家一律清成 nil。
    --
    -- `UnitClassBase` 對非玩家會回一個**看起來完全合法、實際上沒有意義**的職業 token
    -- ——術士的惡魔僕從回 "ROGUE"（實測 rgb 255,244,104）。於是 methods.class 第一段
    -- 就命中 RAID_CLASS_COLORS["ROGUE"]，寵物框被塗成盜賊黃，而且因為第一段就 return，
    -- 後面「吃主人職業色」的備援永遠走不到。
    -- `UnitClass` 更糟：對非玩家回的是**單位的名字**。
    --
    -- 這跟 Tags 的 race/class 用 UnitIsPlayer 閘是同一類問題，只是 cache 這層之前漏了。
    -- 見筆記 wow-unitclass-npc-returns-name。
    ------------------------------------------------------------
    if cache.isPlayer then
        cache.classFile = Desecret(UnitClassBase(unit), nil)
        cache.class     = Desecret((UnitClass(unit)), "")
        cache.race      = Desecret((UnitRace(unit)), "")
    else
        cache.classFile, cache.class, cache.race = nil, "", ""
    end
    -- 非玩家但受玩家控制（寵物／載具）→ 記下主人的職業給上色用（見 OwnerClassOf）
    if cache.isPlayer then
        cache.ownerClass = nil
    else
        cache.ownerClass = OwnerClassOf(uf)
    end

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
    -- 寵物專精放 flag 組而不是 name 組：它決定的是**顏色**，而血條與能量條都訂閱
    -- reaction 桶（info 桶沒有能量條），PET_SPECIALIZATION_CHANGED 推這一個桶就兩條一起
    -- 重算。ownerClass 是 name 組填的；unitchanged 時 name 組先跑，讀得到當下的值。
    cache.petSpec   = cache.ownerClass and PetSpecOf(uf) or nil
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

------------------------------------------------------------
-- 團隊小隊編號（Elements/Icons.lua 的小框與 Tags 的 [group] 共用）
--
-- 不進 cache：只有開了小框、或文字裡寫了 [group] 的框才需要。放進
-- UpdateFlagFields 等於每次 reaction 更新都讓每個框多讀一次團隊名冊。
--
-- ⚠ 不照抄暴雪 PlayerFrame_UpdateGroupIndicator 的「逐一比名字」迴圈：那段是
-- untainted 才比得動，插件拿別人的秘密名字去比會直接報錯。改用 UnitInRaid
-- 直接拿團隊索引。
-- 2026-09-14 實測副本首領戰中索引與小隊號都是明文；戰場（PvP 限制）還沒測，
-- 所以秘密值照樣接得住：索引是秘密就放棄，小隊號是秘密就原樣回傳
-- （呼叫端只拿去 format／SetText，兩者都吃秘密值）。
--
-- 回傳 nil ＝ 不顯示（不在團隊、這個單位不在你的團隊、或讀不到）。
------------------------------------------------------------
function Cache.RaidGroup(uf)
    if not IsInRaid() then return nil end
    -- 載具中玩家框的 uf.unit 是 "vehicle"，UnitInRaid("vehicle") 回 nil ⇒ 上車編號就消失
    local unit = (uf.baseUnit == "player") and "player" or uf.unit
    local index = UnitInRaid(unit)
    if IsSecret(index) or index == nil then return nil end
    return (select(3, GetRaidRosterInfo(index)))
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
