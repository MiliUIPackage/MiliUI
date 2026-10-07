------------------------------------------------------------
-- 資源條：專精 → 該專精要看的資源清單，一種資源一列（獨立 HUD，容器 MiliUICDM_Bar_resources）
--
-- 引擎從套組自己的單位框架（MiliUI_UnitFrames 的資源條與能量條）改來，差別：
--   * **有法力**：單位框自己有能量條，所以那邊刻意不做法力；這裡是獨立 HUD，
--     有法力的專精在最下面多一列法力條（做法照能量條：上限／目前值直接餵 StatusBar）。
--   * **主資源也列**：那邊把「單位框能量條已經在畫的主資源」剔掉，這裡不剔。
--   * **血量**：每個專精的候選都多一列血量條（Health，預設關），見下面「血量」一節。
--
-- 列的順序：預設照專精的清單（法力、血量排最下面），玩家可以在設定頁上下移（resources.order，
-- 整份設定檔共用、不分專精；見 R.ApplyOrder）。
-- 哪幾列要顯示是**分專精**存的（resources.rows[specID][key]，見 R.RowOn／R.SetRow）。
-- 高度（resources.heights[key]）與外觀（resources.style[key]，見 R.StyleFor）是逐列的、所有專精共用。
--
-- 每一列自己決定長相：
--   pip        分段（點數型：聖能／連擊點數／真氣／碎片／充能／精華／符文，以及光環堆疊型：冰刺…）
--   bar        連續長條（怒氣／能量／集中值／符文能量／星能／元能／狂亂值／魔怒／法力；
--              def.get 型：醉仙緩勁 UnitStagger／UnitHealthMax、噬靈魂碎片、血量 UnitHealth／UnitHealthMax）
--   auraPct    **引擎寫百分比**（無視苦痛）：增益 190456 的「層數」欄位是盾量佔上限的百分比（0～100）。
--              單格 AuraContainer ＋ SetApplicationBar(bar, { maxApplications = 100 })，畫成連續條（列上的
--              裝飾不畫分格）；showText 時層數走 SetApplicationCount、後面接一個自己的「%」。
--              只算這個增益自己的盾（別人套的盾、其他吸收不算）。條件規則不適用。
--              容器沒好（戰鬥中、建失敗）時退回下面的 absorbBar（所有吸收盾的總量）。
--   absorbBar  吸收盾（auraPct 的退路）：值 UnitGetTotalAbsorbs("player")、上限「最大生命的三成」。
--              ⚠ 不對秘密的最大生命乘 0.3：用幾何做 —— 裁切框寬 W（SetClipsChildren），裡面的 StatusBar
--              寬 W / 0.3、貼在填充起點那一側，SetMinMaxValues(0, UnitHealthMax)，於是只看得到前三成。
--              這條 StatusBar 的填充貼圖上不錨任何東西、不讀它的尺寸。
--   auraBar    **引擎寫層數**（Modules/AuraBar.lua）：GetPlayerAuraBySpellID 讀不到的增益（旋風斬、橫掃攻擊）
--              用一顆單格 AuraContainer ＋ SetApplicationBar；每施放一次多一顆獨立光環的（鐵鬃）用
--              AddAuraGroup ＋ 每顆 SetDurationBar（一格一層、各自倒數；目前沒有使用者，鐵鬃實測是疊層數）。
--              條件規則不適用；showText 時文字也交給引擎，內容照 R.AuraText（層數／秒數／兩者）。
--              容器是受保護的 intrinsic ⇒ 有這種列時面板在戰鬥中不重排（記旗標、脫戰補）。
--   auraTimer  **光環剩餘時間條**（黯黑力量、秘法靈魂）：同一支 AuraBar 的 kind = "duration"，單格 AuraContainer
--              ＋ SetDurationBar（RemainingTime）：光環在身上時引擎往下縮、不在時是空條（列上畫的暗底）。
--              上限秒數不經 Lua（引擎用光環自己的持續時間，含延長）；showText 時秒數走 SetDurationText。
--              秘法靈魂可以改印「剩幾個 GCD」（arcaneSoulText = "gcd"）：數字格式器一個 GCD 一段，
--              GCD 長度在建容器前用明文算好、進簽章（R.GcdLength）。
--              條件規則不適用；容器沒好（戰鬥中、建失敗）時先畫空條（timerIdle）。
--
-- 12.1 秘密值（見 .claude/notes/wow-121-secret-values.md）：
--   * 連續條：UnitPowerMax／UnitPower **直接**餵 SetMinMaxValues／SetValue（引擎收秘密值），
--     明文且上限 <= 0 才顯示空條。
--   * 點數型：「第 i 格亮不亮」**不在 Lua 比**。每一格是一顆 StatusBar，
--     SetMinMaxValues(i-1, i)＋SetValue(目前值) —— 秘密值照樣畫得對。
--     毀滅術（267）的靈魂裂片改讀原始單位（UnitPower(…, true)，一顆 ＝ per 單位）：
--     第 i 格 SetMinMaxValues((i-1)·per, i·per)＋SetValue(原始值)，碎片的零頭也由引擎畫。
--     明文時正在累積的那一格用暗一階的顏色、文字印一位小數（R.ShardSplit）。
--   * 喚能師精華：下一格畫回充進度（UnitPartialPower，讀不到改用回充速度推算；明文才算，R.EssenceFrac），
--     跟符文共用「有格子在回充才跑」的 0.1 秒 ticker。
--   * 氣漩武器摺疊（maelstromFold）：10 層摺成 5 格，每格疊兩顆 StatusBar，
--     底層 (i-1, i)、上層 (i+4, i+5) 都 SetValue(層數)；上層用溢出色（R.FoldRange）。
--   * 條件規則、數值文字、充能格判斷只吃**明文**（canaccessvalue）；讀不到就不求值
--     （照原本的顏色）、不印字。玩家自己的資源在目前的客戶端是明文，這是保底。
--   * 格子一律錨在列本身（不串在前一格上）：SetValue(秘密值) 會讓那顆 StatusBar 的幾何
--     變成秘密，錨在它身上的東西會被傳染。
--
-- 事件處理器只標髒、下一幀做（ns.Defer）。能量走 UNIT_POWER_FREQUENT（UNIT_POWER_UPDATE
-- 在回能／衰減時兩秒才一次，留著當回滿的保底）。
--
-- 自訂格子（cfg.customRows[specID]）是另一個面板（Modules/Pips.lua，容器 MiliUICDM_Bar_pips）：
-- 清單存在這張設定表、樣式（列高、格距、材質、填充方向、寬度）沿用這裡，位置與錨定是它自己的。
-- 這支只出借共用的小工具（Plain、AuraStacks、Edges、Width、RowHeight、DIM）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Resources = {}
local R = ns.Resources

local RC = ns.ResCond
local CLASS = ns.playerClass
local PT = (Enum and Enum.PowerType) or {}
local MAX_SEGMENTS = RC.MAX_SEGMENTS
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local DIM = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
R.DIM = DIM
local WHITE = { r = 1, g = 1, b = 1 }

local function Plain(v)
    if type(v) ~= "number" then return nil end
    if ns.IsSecret(v) then return nil end
    return v
end
R.Plain = Plain

-- 死騎符文列的數字：「長條上顯示數值」（showText）是總開關，開著時這裡二選一
-- （使用者 2026-10-01 試過兩者並列後定案：一排數字裡再夾一個顆數會分不出哪個是顆數、
-- 哪個是秒數，不要再拆成兩個獨立開關）。
--   countdown 在轉的格子印剩餘秒數（預設）／count 中間印轉好的顆數
-- 排序與回充進度不受影響，兩種都有
function R.RuneText(cfg)
    local v = type(cfg) == "table" and cfg.runeText
    if v == "count" then return v end
    return "countdown"
end

------------------------------------------------------------
-- 資源定義
--
-- mode   pip / bar
-- power  Enum.PowerType（標準資源）
-- aura   光環 spellID（層數當點數）
-- cast   GetSpellCastCount 的 spellID
-- fill   pip 專用的特殊填充：rune（符文冷卻）、essence（下一格畫精華回充進度）
-- fractionalSpec 這個專精改讀原始單位、畫碎片零頭（毀滅術的靈魂裂片）
-- foldable 可以摺疊成一半的格數（maelstromFold：氣漩武器 10 層 → 5 格兩層）
-- appMax auraPct 專用：層數欄位的上限（無視苦痛的百分比 100）
-- auras  光環 spellID 清單（auraBar／auraTimer：交給 AuraContainer 的 includeSpellIDs，Lua 不讀）
-- passive 天賦閘：這個法術學了才列；heroTree：或是目前的英雄天賦樹是這一棵（C_ClassTalents）
-- mana   法力列（數值文字走縮寫、預設排在職業資源下面）
-- health 血量列（秘密值：條件規則不適用，顏色走職業色／門檻換色，見「血量」一節）
--
-- 資源名稱一律用暴雪的全域字串：那是十二個語系的官方譯名，比插件自己翻準。
-- 全域不存在時退回英文。
------------------------------------------------------------
local function PowerName(global, fallback)
    local s = _G[global]
    if type(s) ~= "string" or s == "" then return fallback end
    -- 有些暴雪字串帶複數轉義（zhTW 的 SOUL_SHARDS 是「靈魂|4裂片:裂片;」），
    -- 要由前面的數字驅動才會被客戶端解開；拿來當標籤時取單數形。
    return (s:gsub("|4([^:;]*):[^;]*;", "%1"))
end
R.PowerName = PowerName

-- 法術名當資源名（C_Spell.GetSpellName 是官方譯名；載入當下讀不到時 R.Name 會再問一次）
local function SpellName(id, fallback)
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, n = pcall(fn, id)
        if ok and type(n) == "string" and not (ns.IsSecret and ns.IsSecret(n)) and n ~= "" then return n end
    end
    return fallback
end

-- 取值函式（def.get）：回傳 cur, max 的**原始值**（可能是秘密值），只轉手不比較
local function PlayerAura(id)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return nil end
    local ok, a = pcall(get, id)
    if ok then return a end
    return nil
end

local function AuraApps(id)
    local a = PlayerAura(id)
    if not a then return 0 end
    local ok, n = pcall(function() return a.applications end)
    if not ok or n == nil then return 0 end
    return n
end

local function Known(id)
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return false end
    local ok, v = pcall(fn, id)
    if not ok or (ns.IsSecret and ns.IsSecret(v)) then return false end
    return v and true or false
end

-- 醉仙緩勁：UnitStagger／UnitHealthMax 直接轉手（兩個都可能是秘密值）
local function StaggerValue()
    local s = UnitStagger and UnitStagger("player")
    local m = UnitHealthMax and UnitHealthMax("player")
    return s or 0, m or 0
end

-- 血量：UnitHealth／UnitHealthMax 直接轉手（12.1 連脫戰都是秘密值）
local function HealthValue()
    local c = UnitHealth and UnitHealth("player")
    local m = UnitHealthMax and UnitHealthMax("player")
    return c or 0, m or 0
end

-- 無視苦痛：身上所有吸收盾的總量／最大生命（上限的三成由幾何處理，這裡不乘）
local function AbsorbValue()
    local a = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player")
    local m = UnitHealthMax and UnitHealthMax("player")
    return a or 0, m or 0
end

-- 噬靈魂碎片（專精 1480）：虛空化身中看 1227702、平常看 1225789 的層數。
-- 上限：化身中 40；平常 50（點了 1247534 是 35），PvP 天賦 1261423 再加 50。全部是明文查詢
local DEVOURER_META, DEVOURER_META_STACKS, DEVOURER_STACKS = 1217607, 1227702, 1225789
local function DevourerValue()
    if PlayerAura(DEVOURER_META) then return AuraApps(DEVOURER_META_STACKS), 40 end
    local m = Known(1247534) and 35 or 50
    if Known(1261423) then m = m + 50 end
    return AuraApps(DEVOURER_STACKS), m
end

-- 橫掃攻擊：點了 1261049 上限 18，否則 12
local function SweepingMax() return Known(1261049) and 18 or 12 end

-- ⚠ 顏色不寫在這裡：預設色的單一來源是 Core/DB.lua 的 RESOURCE_COLORS
local RESOURCES = {
    Mana            = { name = PowerName("MANA", "Mana"),             mode = "bar", power = PT.Mana, mana = true },
    Rage            = { name = PowerName("RAGE", "Rage"),             mode = "bar", power = PT.Rage },
    Energy          = { name = PowerName("ENERGY", "Energy"),         mode = "bar", power = PT.Energy },
    Focus           = { name = PowerName("FOCUS", "Focus"),           mode = "bar", power = PT.Focus },
    RunicPower      = { name = PowerName("RUNIC_POWER", "Runic Power"), mode = "bar", power = PT.RunicPower },
    LunarPower      = { name = PowerName("LUNAR_POWER", "Astral Power"), mode = "bar", power = PT.LunarPower },
    Maelstrom       = { name = PowerName("MAELSTROM", "Maelstrom"),   mode = "bar", power = PT.Maelstrom },
    Insanity        = { name = PowerName("INSANITY", "Insanity"),     mode = "bar", power = PT.Insanity },
    Fury            = { name = PowerName("FURY", "Fury"),             mode = "bar", power = PT.Fury },
    HolyPower       = { name = PowerName("HOLY_POWER", "Holy Power"), mode = "pip", power = PT.HolyPower },
    ComboPoints     = { name = PowerName("COMBO_POINTS", "Combo Points"), mode = "pip", power = PT.ComboPoints },
    Chi             = { name = PowerName("CHI", "Chi"),               mode = "pip", power = PT.Chi },
    -- 靈魂裂片：只有毀滅術（267）有碎片零頭，另外兩系照整數
    SoulShards      = { name = PowerName("SOUL_SHARDS", "Soul Shards"), mode = "pip", power = PT.SoulShards,
                        fractionalSpec = 267 },
    ArcaneCharges   = { name = PowerName("ARCANE_CHARGES", "Arcane Charges"), mode = "pip", power = PT.ArcaneCharges },
    Essence         = { name = PowerName("ESSENCE", "Essence"),       mode = "pip", power = PT.Essence, fill = "essence" },
    Runes           = { name = PowerName("RUNES", "Runes"),           mode = "pip", power = PT.Runes, fill = "rune" },
    -- 光環／技能次數型（資料來源都是暴雪開放的查詢）
    MaelstromWeapon = { name = L["Maelstrom Weapon"], mode = "pip", aura = 344179, max = 10, passive = 187880, foldable = true },
    TipOfTheSpear   = { name = L["Tip of the Spear"], mode = "pip", aura = 260286, max = 3,  passive = 260285 },
    SoulFragments   = { name = L["Soul Fragments"],   mode = "pip", cast = 228477, max = 6,  passive = 203981 },
    -- 2026-09-30 補齊
    Icicles         = { name = SpellName(205473, "Icicles"), nameSpell = 205473, mode = "pip", aura = 205473, max = 5 },
    -- meta：這一列另外畫虛空化身計時＋崩陷之星計數（Modules/DevourerMeta.lua）
    DevourerFragments = { name = L["Soul Fragments"], mode = "bar", get = DevourerValue, bigNumber = false, auraRead = true,
                          meta = true },
    Stagger         = { name = PowerName("STAGGER", SpellName(115069, "Stagger")), mode = "bar", get = StaggerValue,
                        passive = 115069, stagger = true, bigNumber = true },
    -- 無視苦痛：引擎寫增益 190456 的層數（＝盾量佔上限的百分比）；get／cap 是容器沒好時的 absorbBar 退路
    IgnorePain      = { name = SpellName(190456, "Ignore Pain"), nameSpell = 190456, mode = "auraPct", auras = { 190456 },
                        appMax = 100, get = AbsorbValue, passive = 190456, cap = 0.3, bigNumber = true, absorb = true },
    WhirlwindStacks = { name = SpellName(85739, "Whirlwind"), nameSpell = 85739, mode = "auraBar",
                        auras = { 85739, 190411 }, max = 4, passive = 12950 },
    SweepingStrikes = { name = SpellName(260708, "Sweeping Strikes"), nameSpell = 260708, mode = "auraBar",
                        auras = { 260708 }, maxFn = SweepingMax, max = 12, passive = 260708 },
    -- 鐵鬃：12.1 實測是**一顆光環疊層數**（施放一次層數 1、暴雪追蹤長條顯示層數），不是一施放一顆獨立光環 ⇒
    -- 跟旋風斬同一型（引擎寫 applications）。AuraBar 的 instances 型目前沒有使用者
    Ironfur         = { name = SpellName(192081, "Ironfur"), nameSpell = 192081, mode = "auraBar",
                        auras = { 192081 }, max = 5, passive = 192081 },
    -- 光環剩餘時間條（auraTimer）。名字用光環的法術名
    --   黯黑力量：增輝的招牌技能 395152、身上的增益是 395296（基礎 10 秒，會被延長）
    --   秘法靈魂：Sunfury 英雄天賦「歐爾的記憶」449619 給的 451038（4 秒）；1223522 是 11.1 起同名同圖示的
    --   另一個 ID，一起放進過濾（沒出現就永遠比對不到，無害）。英雄樹 39 ＝ Sunfury
    EbonMight       = { name = SpellName(395296, "Ebon Might"), nameSpell = 395296, mode = "auraTimer",
                        auras = { 395296 }, passive = 395152 },
    ArcaneSoul      = { name = SpellName(451038, "Arcane Soul"), nameSpell = 451038, mode = "auraTimer",
                        auras = { 451038, 1223522 }, passive = 449619, heroTree = 39, gcdText = true },
    -- 征戰聖擊（懲戒天賦 404542：普攻換成聖擊）：**鏡射**暴雪「追蹤的量條」裡那條（mode = "mirror"，見下面「征戰聖擊」一節）。
    --   這一列有自己的高度、填充方向與底色（crusadingHeight／crusadingFill／colors.CrusadingStrikes.backColor，
    --   預設值照德莫的征戰聖擊助手：高 4、已揮的時間左→右長出、黑底 60%），不印秒數（1.5 秒一刀，數字讀不完）
    CrusadingStrikes = { name = SpellName(404542, "Crusading Strikes"), nameSpell = 404542, mode = "mirror",
                        passive = 404542, crusading = true, noText = true },
    -- 血量：每個專精都是候選、預設關（R.DefaultOn）；不在 RawList 裡，R.Candidates 附加在最後
    Health          = { name = PowerName("HEALTH", "Health"), mode = "bar", get = HealthValue, health = true },
}
R.RESOURCES = RESOURCES

-- 顯示用的名字：法術名在載入當下可能還沒有資料，之後再問一次（拿到就記下）
function R.Name(key)
    local def = RESOURCES[key]
    if not def then return key end
    if def.nameSpell and not def.nameResolved then
        local n = SpellName(def.nameSpell, nil)
        if n then def.name, def.nameResolved = n, true end
    end
    return def.name or key
end

-- 醉仙緩勁中度／重度的標籤：暴雪自己的減益名（124274 中度、124273 重度）。
-- 第 3／4 段暴雪沒有對應的減益，標籤寫門檻本身（≥ N%，N 讀 cfg 的門檻）。
-- 「≥」走語系字串：西文介面的字型不一定有這個字，那幾個語系寫成文字
local STAGGER_LABEL = { moderate = { 124274, "Moderate Stagger" }, heavy = { 124273, "Heavy Stagger" } }
local STAGGER_TIER_AT = { tier3 = { "staggerTier3At", 90 }, tier4 = { "staggerTier4At", 150 } }
R.STAGGER_TIER_AT = STAGGER_TIER_AT
function R.StaggerLabel(band, cfg)
    local tier = STAGGER_TIER_AT[band]
    if tier then
        local v = tonumber(type(cfg) == "table" and cfg[tier[1]]) or tier[2]
        return L["At least %d%%"]:format(math.floor(v + 0.5))
    end
    local t = STAGGER_LABEL[band]
    if not t then return tostring(band) end
    return SpellName(t[1], t[2])
end

-- 引擎寫值的列（auraBar 層數、auraTimer 剩餘時間、auraPct 百分比）：Lua 這邊沒有值
-- mirror（征戰聖擊）也算：值是從暴雪的條原封轉手的秘密值，Lua 一樣沒得比
local ENGINE_MODES = { auraBar = true, auraTimer = true, auraPct = true, mirror = true }
function R.EngineDriven(key)
    local def = RESOURCES[key]
    return def ~= nil and ENGINE_MODES[def.mode] == true
end

-- 條件規則只對 Lua 讀得到值的列有意義；引擎寫的沒有，血量（永遠是秘密值）也沒有
function R.SupportsConditions(key)
    local def = RESOURCES[key]
    return def ~= nil and not ENGINE_MODES[def.mode] and not def.health
end

-- 純函式：一列實際的畫法。容器就緒 ⇒ engine；沒好時 auraBar 退回明文點數、auraTimer 退回空條、
-- auraPct 退回吸收盾總量（absorbBar）
function R.DrawMode(mode, engineReady)
    if mode == "auraBar" then return engineReady and "engine" or "pip" end
    if mode == "auraTimer" then return engineReady and "engine" or "timerIdle" end
    if mode == "auraPct" then return engineReady and "engine" or "absorbBar" end
    return mode
end

-- 專精 → 資源清單（法力另外看 MANA_SPECS，預設排最下面；玩家可以重排，見 R.ApplyOrder）
local SPEC_RESOURCES = {
    [71]  = { "Rage", "SweepingStrikes" },       [72]  = { "Rage", "WhirlwindStacks" },
    [73]  = { "Rage", "IgnorePain" },
    [65]  = { "HolyPower" },                     [66]  = { "HolyPower" },
    [70]  = { "CrusadingStrikes", "HolyPower" },   -- 征戰聖擊預設在聖能上方（同助手的預設位置）
    [253] = { "Focus" },                         [254] = { "Focus" },
    [255] = { "Focus", "TipOfTheSpear" },
    [259] = { "Energy", "ComboPoints" },         [260] = { "Energy", "ComboPoints" },
    [261] = { "Energy", "ComboPoints" },
    [256] = {},                                  [257] = {},
    [258] = { "Insanity" },
    [250] = { "RunicPower", "Runes" },           [251] = { "RunicPower", "Runes" },
    [252] = { "RunicPower", "Runes" },
    [262] = { "Maelstrom" },                     [263] = { "MaelstromWeapon" },  [264] = {},
    [62]  = { "ArcaneCharges", "ArcaneSoul" },                 [63]  = {},  [64] = { "Icicles" },
    [265] = { "SoulShards" },                    [266] = { "SoulShards" },  [267] = { "SoulShards" },
    [268] = { "Energy", "Stagger" },
    [269] = { "Energy", "Chi" },                 [270] = {},
    [102] = { "LunarPower" },                    [103] = { "Energy", "ComboPoints" },
    [104] = { "Rage" },                          -- 守護：熊形態另外多「鐵鬃」（RawList）
    [105] = {},
    [577] = { "Fury" },                          [581] = { "Fury", "SoulFragments" },
    [1480] = { "Fury", "DevourerFragments" },
    [1467] = { "Essence" },                      [1468] = { "Essence" },  [1473] = { "Essence", "EbonMight" },
}
R.SPEC_RESOURCES = SPEC_RESOURCES

-- 用法力施法的專精：底部多一列法力條
local MANA_SPECS = {
    [62] = true, [63] = true, [64] = true,             -- 法師
    [65] = true,                                       -- 神聖聖騎
    [256] = true, [257] = true, [258] = true,          -- 牧師（暗牧：狂亂值之外還是要看法力）
    [262] = true, [263] = true, [264] = true,          -- 薩滿
    [265] = true, [266] = true, [267] = true,          -- 術士
    [270] = true,                                      -- 織霧
    [102] = true, [105] = true,                        -- 平衡、恢復德魯伊
    [1467] = true, [1468] = true, [1473] = true,       -- 喚能師
}
R.MANA_SPECS = MANA_SPECS

-- 候選有、但**預設不顯示**的（玩家在「這個專精要顯示哪些」勾起來才顯示）：
-- 法力只在治療專精預設顯示；輸出專精（暗牧、元素、增強、術士、平衡、湮滅、強化）有自己的主資源，
-- 法力平常不需要一條在那裡佔位（使用者 2026-10-02 指定，跟 Ayije_CDM 的預設一致）
local MANA_OFF = { Mana = true }
local DEFAULT_OFF = {
    [258] = MANA_OFF,                                  -- 暗牧
    [262] = MANA_OFF, [263] = MANA_OFF,                -- 元素、增強
    [265] = MANA_OFF, [266] = MANA_OFF, [267] = MANA_OFF, -- 術士
    [102] = MANA_OFF,                                  -- 平衡
    [1467] = MANA_OFF, [1473] = MANA_OFF,              -- 湮滅、強化
}
-- 每個專精都預設不顯示的：血量（單位框架本來就有血條，這裡是給想看的人勾起來的）
local ALWAYS_OFF = { Health = true }
-- 純函式：這個專精的這一列預設是不是顯示
function R.DefaultOn(specID, key)
    if ALWAYS_OFF[key] then return false end
    local t = specID and DEFAULT_OFF[specID]
    return not (t and t[key])
end
-- 玩家的開關（rows[specID][key]：nil ＝ 照預設、false ＝ 關、true ＝ 開）套上預設後的結果。
-- 分專精存：同一個 key（法力、血量、怒氣…）在每個專精各自開關
function R.RowOn(cfg, specID, key)
    -- ⚠ 值可能是 false，不能用 `a and b or nil` 取（false 會被吃成 nil）
    local v
    if specID and type(cfg) == "table" and type(cfg.rows) == "table" then
        local t = cfg.rows[specID]
        if type(t) == "table" then v = t[key] end
    end
    if v == nil then return R.DefaultOn(specID, key) end
    return v and true or false
end

-- 寫一個專精的開關：跟這個專精的預設一樣就清掉（＝照預設），子表清空了也拿掉
function R.SetRow(cfg, specID, key, on)
    if type(cfg) ~= "table" or not specID or type(key) ~= "string" then return end
    if type(cfg.rows) ~= "table" then cfg.rows = {} end
    on = on and true or false
    local t = cfg.rows[specID]
    if on == R.DefaultOn(specID, key) then
        if type(t) == "table" then
            t[key] = nil
            if next(t) == nil then cfg.rows[specID] = nil end
        end
        return
    end
    if type(t) ~= "table" then
        t = {}
        cfg.rows[specID] = t
    end
    t[key] = on
end

-- 職業 → 專精（設定遷移與匯入要「這個 key 在哪幾個專精是候選」，玩家當下的職業不夠）
local CLASS_SPECS = {
    WARRIOR = { 71, 72, 73 },        PALADIN = { 65, 66, 70 },       HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 },       PRIEST = { 256, 257, 258 },     DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 },      MAGE = { 62, 63, 64 },          WARLOCK = { 265, 266, 267 },
    MONK = { 268, 269, 270 },        DRUID = { 102, 103, 104, 105 }, DEMONHUNTER = { 577, 581, 1480 },
    EVOKER = { 1467, 1468, 1473 },
}
R.CLASS_SPECS = CLASS_SPECS
local SPEC_CLASS = {}
for class, specs in pairs(CLASS_SPECS) do
    for _, id in ipairs(specs) do SPEC_CLASS[id] = class end
end
R.SPEC_CLASS = SPEC_CLASS

-- 德魯伊看「現在的型態」：熊＝怒氣、貓＝能量＋連擊點、其餘照專精（梟＝星能；野性／守護＝法力）
local DRUID_BEAR, DRUID_CAT = 5, 1

-- 純函式（離線測試用）：職業、專精、德魯伊型態 → 這個專精該有的資源 key（還沒套天賦閘）
function R.RawList(class, specID, form)
    local out = {}
    if class == "DRUID" then
        if form == DRUID_BEAR then
            out[1] = "Rage"
            if specID == 104 then out[2] = "Ironfur" end
        elseif form == DRUID_CAT then
            out[1], out[2] = "Energy", "ComboPoints"
        elseif specID == 102 then
            out[1] = "LunarPower"
        elseif specID == 103 or specID == 104 then
            -- 野性／守護在人形（以及旅行等其他型態）沒有怒氣能量可看，整條空著很尷尬：給法力
            --（玩家回報 2026-10-03）。平衡、恢復本來就在 MANA_SPECS，這裡不重複加
            out[1] = "Mana"
        end
    else
        for _, key in ipairs(SPEC_RESOURCES[specID or 0] or {}) do out[#out + 1] = key end
    end
    if specID and MANA_SPECS[specID] then out[#out + 1] = "Mana" end
    return out
end

-- 純函式：這個專精**任何情況下**可能出現的 key（集合；德魯伊把人形／熊／貓三種型態併起來，
-- 每個專精都有血量）。不套天賦閘——遷移與匯入要的是「這個開關在這個專精有沒有意義」
function R.SpecCandidates(specID)
    local set = {}
    local class = specID and SPEC_CLASS[specID]
    if not class then return set end
    local forms = (class == "DRUID") and { 0, DRUID_BEAR, DRUID_CAT } or { 0 }
    for _, f in ipairs(forms) do
        for _, key in ipairs(R.RawList(class, specID, f ~= 0 and f or nil)) do set[key] = true end
    end
    set.Health = true
    return set
end

-- 純函式：所有專精（由小到大，結果穩定）
function R.AllSpecIDs()
    local out = {}
    for id in pairs(SPEC_CLASS) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- 純函式（設定遷移 v3，Core/DB.lua 呼叫）：舊的平面開關 rows[key] = true／false（整份設定檔共用）
-- 改成 rows[specID][key]。每個「這個 key 是候選」的專精：值跟那個專精的預設不同才寫；平面的鍵拿掉。
-- 已經是新形狀的（數字鍵的子表）不碰，所以跑兩次結果一樣。回傳寫了幾筆
function R.MigrateFlatRows(rows)
    if type(rows) ~= "table" then return 0 end
    local flat = {}
    for k, v in pairs(rows) do
        if type(k) == "string" and type(v) == "boolean" then flat[k] = v end
    end
    for k in pairs(flat) do rows[k] = nil end
    local n = 0
    for _, specID in ipairs(R.AllSpecIDs()) do
        local cand = R.SpecCandidates(specID)
        for key, v in pairs(flat) do
            if cand[key] and v ~= R.DefaultOn(specID, key) then
                local t = rows[specID]
                if type(t) ~= "table" then
                    t = {}
                    rows[specID] = t
                end
                -- 新形狀已經有值（玩家在新版調過）就不蓋
                if t[key] == nil then
                    t[key] = v
                    n = n + 1
                end
            end
        end
    end
    return n
end

------------------------------------------------------------
-- 取值：**原始值**（可能是秘密值）。要比較、要當文字之前一律過 Plain
------------------------------------------------------------
local function AuraStacks(spellID)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return 0 end
    local ok, a = pcall(get, spellID)
    if not ok or not a then return 0 end
    local ok2, n = pcall(function() return a.applications end)
    if not ok2 or n == nil then return 0 end
    return n
end
R.AuraStacks = AuraStacks

-- 回傳 cur, max（原始值）
local function GetValue(key)
    local def = RESOURCES[key]
    if not def then return 0, 0 end
    if def.mode == "auraTimer" or def.mode == "mirror" then return 0, 0 end     -- 剩餘時間只在引擎／暴雪的條那邊，Lua 不讀
    if def.get then return def.get() end
    if def.aura then return AuraStacks(def.aura), def.max end
    if def.auras then return AuraStacks(def.auras[1]), R.SegmentsFor(key) end
    if def.cast then
        local fn = C_Spell and C_Spell.GetSpellCastCount
        if not fn then return 0, def.max end
        local ok, n = pcall(fn, def.cast)
        if not ok or n == nil then n = 0 end
        return n, def.max
    end
    if def.power == nil then return 0, 0 end
    local cur = UnitPower("player", def.power)
    local max = UnitPowerMax("player", def.power)
    return cur or 0, max or 0
end
R.GetValue = GetValue

------------------------------------------------------------
-- 設定
------------------------------------------------------------
local function Cfg() return ns.DB and ns.DB.ConfigTable("resources") end
R.Cfg = Cfg

-- 虛空化身門檻規則的清理（設定頁寫入前；純函式本體在 Modules/DevourerMeta.lua）
function R.CleanMetaRules(rules) return ns.DevourerMeta.CleanRules(rules) end

-- 顏色：玩家調的 cfg.colors[key][field] → Core/DB.lua 的預設。回傳既有的表，一次都不配新的
local function DefaultColor(key, field)
    local t = ns.DB and ns.DB.RESOURCE_COLORS and ns.DB.RESOURCE_COLORS[key]
    local c = t and t[field]
    if RC.ValidColor(c) then return c end
    -- 充能色缺了退回主色（不要退成白色：白色比主色還亮，充能格的判讀會反過來）
    if field ~= "color" then return DefaultColor(key, "color") end
    return WHITE
end
R.DefaultColor = DefaultColor

local function ResolveColor(cfg, key, field)
    local own = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors[key]
    local c = type(own) == "table" and own[field]
    if RC.ValidColor(c) then return c end
    return DefaultColor(key, field)
end
R.ResolveColor = ResolveColor

------------------------------------------------------------
-- 天賦判斷
--
--   標準資源看 UnitPowerMax > 0（沒點到那個天賦時上限就是 0；秘密值當有）。
--   光環堆疊型查被動是否已學；被動 ID 萬一寫錯會誤判，所以**目前有層數就一律顯示**。
------------------------------------------------------------
local function SpellKnown(id)
    if not id then return true end
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return true end
    local ok, known = pcall(fn, id)
    if not ok then return true end
    if ns.IsSecret(known) then return true end
    return known and true or false
end

-- 目前的英雄天賦樹（明文才算；讀不到回 nil）
local function ActiveHeroTree()
    local fn = C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec
    if not fn then return nil end
    local ok, v = pcall(fn)
    if not ok then return nil end
    return Plain(v)
end

local gateLog = {}
R.gateLog = gateLog

local function Available(key)
    local def = RESOURCES[key]
    if not def then return false, "沒有定義" end
    if def.mode == "mirror" then
        if SpellKnown(def.passive) then return true, "被動已學" end
        return false, "被動未學（天賦沒點）"
    end
    if def.aura or def.cast or def.auras or def.get then
        if SpellKnown(def.passive) then return true, def.passive and "被動已學" or "不需要天賦" end
        if def.heroTree and ActiveHeroTree() == def.heroTree then return true, "英雄天賦樹 " .. tostring(def.heroTree) end
        -- 剩餘時間條沒有 Lua 讀得到的值，沒有「目前有層數」這條保險
        if def.mode == "auraTimer" then return false, "被動未學（天賦沒點）" end
        local cur = Plain((GetValue(key)))
        if (cur or 0) > 0 then return true, "被動查不到但目前有層數" end
        return false, "被動未學（天賦沒點）"
    end
    local _, max = GetValue(key)
    local pm = Plain(max)
    if pm == nil then return true, "上限讀不到（秘密值），照列" end
    if pm <= 0 then return false, "上限 0（天賦沒點／此型態沒有）" end
    return true, "上限 " .. tostring(pm)
end

local function CurrentSpecID()
    return ns.specID
end

local function DruidForm()
    if CLASS ~= "DRUID" then return nil end
    local fn = GetShapeshiftFormID
    local form = fn and fn()
    return Plain(form)
end

------------------------------------------------------------
-- 列的順序（resources.order：資源 key 的陣列，整份設定檔共用、不分專精）
--
-- 在 order 裡的照它的位置；不在的維持原本（專精清單）的相對順序、排在所有排過的後面。
-- 不分專精 ⇒ 兩個專精共有的 key（法力、血量…）在一邊調了另一邊也跟著；只差在各自有哪幾列。
------------------------------------------------------------
-- 純函式：回傳排好的新表（list 不動）。穩定：同樣沒排過的照原順序；order 裡重複的 key 只認第一次
function R.ApplyOrder(list, order)
    local out = {}
    if type(list) ~= "table" then return out end
    if type(order) ~= "table" or #order == 0 then
        for i, key in ipairs(list) do out[i] = key end
        return out
    end
    local present, placed = {}, {}
    for _, key in ipairs(list) do present[key] = true end
    for _, key in ipairs(order) do
        if present[key] and not placed[key] then
            out[#out + 1] = key
            placed[key] = true
        end
    end
    for _, key in ipairs(list) do
        if not placed[key] then
            out[#out + 1] = key
            placed[key] = true
        end
    end
    return out
end

-- 純函式：設定頁上下移之後要存的 order。cand ＝ 這個專精排好的完整清單（照它排），
-- 舊 order 裡不在 cand 的 key（別的專精排過的）依原相對位置接在後面
function R.MergeOrder(old, cand)
    local out, seen = {}, {}
    for _, key in ipairs(type(cand) == "table" and cand or {}) do
        if not seen[key] then
            out[#out + 1] = key
            seen[key] = true
        end
    end
    for _, key in ipairs(type(old) == "table" and old or {}) do
        if type(key) == "string" and not seen[key] then
            out[#out + 1] = key
            seen[key] = true
        end
    end
    return out
end

-- 這個專精「可以顯示」哪些資源（已套天賦／型態與玩家排的順序，不看玩家的開關）。有快取，
-- 專精／型態／天賦／上限變動時 Reevaluate 清掉（設定頁改順序走 R.Apply，同樣清）
local cachedList, cachedSpec

function R.Candidates()
    if cachedList then return cachedList, cachedSpec end
    local specID = CurrentSpecID()
    local raw = R.RawList(CLASS, specID, DruidForm())
    -- 血量每個專精都有（預設關，見 R.DefaultOn）：RawList 不動，在這裡接到最後
    if specID then raw[#raw + 1] = "Health" end
    for k in pairs(gateLog) do gateLog[k] = nil end
    local list = {}
    for _, key in ipairs(raw) do
        local ok, why = Available(key)
        gateLog[key] = (ok and "顯示：" or "隱藏：") .. why
        if ok then list[#list + 1] = key end
    end
    local cfg = Cfg()
    list = R.ApplyOrder(list, cfg and cfg.order)
    cachedList, cachedSpec = list, specID
    return list, specID
end

function R.Invalidate() cachedList = nil end

function R.Info(key) return RESOURCES[key] end

-- 實際要畫的清單（套上玩家的開關 rows[key] 與每個專精的預設，見 R.RowOn）。scratch 表，呼叫端不可留著
local activeRows = {}
local function ActiveRows(cfg)
    local cand, specID = R.Candidates()
    for i = #activeRows, 1, -1 do activeRows[i] = nil end
    for _, key in ipairs(cand) do
        if RESOURCES[key] and R.RowOn(cfg, specID, key) then activeRows[#activeRows + 1] = key end
    end
    return activeRows
end

------------------------------------------------------------
-- 氣漩武器摺疊（maelstromFold，預設關）：10 層摺成 5 格，每格兩顆疊起來的 StatusBar
--   底層 (i-1, i)、上層 (i-1+5, i+5)，同樣 SetValue(層數) ⇒ 6 層時第 1 格的上層亮、2～5 格只有底層
-- 上層用溢出色（colors.MaelstromWeapon.overflowColor）。條件規則：整條的覆寫照舊，
-- 逐格的顏色只套在底層（格子序號是 1～5）
------------------------------------------------------------
local FOLD_SEGMENTS = 5
R.FOLD_SEGMENTS = FOLD_SEGMENTS

function R.Folded(cfg, key)
    local def = RESOURCES[key]
    return def ~= nil and def.foldable == true and type(cfg) == "table" and cfg.maelstromFold == true
end

-- 純函式：摺疊時第 i 格第 layer 層（1 底、2 上）的 min／max
function R.FoldRange(i, layer, n)
    n = n or FOLD_SEGMENTS
    if layer == 2 then return i - 1 + n, i + n end
    return i - 1, i
end

------------------------------------------------------------
-- 毀滅術的碎片零頭（專精 267）
--   UnitPower(…, true)／UnitPowerMax(…, true) 是原始單位（一顆 ＝ 10）；per ＝ 原始上限 ／ 整顆上限，
--   讀不到（秘密值、0）就 10。第 i 格 (i-1)·per ～ i·per，SetValue 原始值（秘密值也畫得對）
------------------------------------------------------------
local SHARD_UNITS = 10
function R.ShardPer(rawMax, max)
    local rm, m = Plain(rawMax), Plain(max)
    if rm and m and m > 0 and rm > 0 then return rm / m end
    return SHARD_UNITS
end

-- 純函式（明文才叫）：原始值 → 整顆數、正在累積的那一格（沒有 ＝ nil）、顆數（帶小數）
function R.ShardSplit(raw, per, n)
    if type(raw) ~= "number" or type(per) ~= "number" or per <= 0 then return nil end
    local value = raw / per
    local whole = math.floor(value + 1e-6)
    local partial
    if raw - whole * per > 1e-6 and whole < (n or math.huge) then partial = whole + 1 end
    return whole, partial, value
end

------------------------------------------------------------
-- 精華回充（喚能師）
--   來源優先 UnitPartialPower（0～1000，明文且 > 0 才用）；拿不到 → 回充速度（每秒幾顆，
--   GetPowerRegenForPowerType，明文才收、記住上次的）× 距離上次精華變動的秒數。兩者都沒有 ＝ 不畫
------------------------------------------------------------
function R.EssenceFrac(partial, rate, elapsed)
    local f
    if type(partial) == "number" and partial > 0 then
        f = partial / 1000
    elseif type(rate) == "number" and rate > 0 and type(elapsed) == "number" and elapsed >= 0 then
        f = elapsed * rate
    else
        return nil
    end
    if f < 0 then f = 0 elseif f > 0.999 then f = 0.999 end
    return f
end

------------------------------------------------------------
-- 秘法靈魂的「剩幾個 GCD」：GCD 長度（明文才算）
--   C_Spell.GetSpellCooldown(61304) 正在 GCD 時的 duration；不在 GCD（0）或讀不到 ⇒ 1.5 ／（1 ＋ 加速 ／ 100）；
--   加速也讀不到 ⇒ 上次的、再沒有就 1.5。夾在 0.75～1.5，四捨五入到 0.05 秒（進容器簽章，別讓小數抖動換容器）
------------------------------------------------------------
local GCD_BASE, GCD_MIN = 1.5, 0.75
function R.GcdLength(cdDuration, haste, last)
    local g
    if type(cdDuration) == "number" and cdDuration > 0 then
        g = cdDuration
    elseif type(haste) == "number" and haste > -100 then
        g = GCD_BASE / (1 + haste / 100)
    else
        g = tonumber(last) or GCD_BASE
    end
    if g < GCD_MIN then g = GCD_MIN elseif g > GCD_BASE then g = GCD_BASE end
    return math.floor(g / 0.05 + 0.5) * 0.05
end

local GCD_SPELL = 61304
local gcdLast
function R.ReadGcd()
    local dur
    local fn = C_Spell and C_Spell.GetSpellCooldown
    if fn then
        local ok, info = pcall(fn, GCD_SPELL)
        if ok and type(info) == "table" then
            local ok2, d = pcall(function() return info.duration end)
            if ok2 then dur = Plain(d) end
        end
    end
    local haste
    if UnitSpellHaste then
        local ok, h = pcall(UnitSpellHaste, "player")
        if ok then haste = Plain(h) end
    end
    gcdLast = R.GcdLength(dur, haste, gcdLast)
    return gcdLast
end

-- 引擎寫層數的列（auraBar：鐵鬃、旋風斬、橫掃攻擊）的文字，showText 開著才有；逐資源存在 auraText[key]：
--   stacks 疊層數字（預設）／time 剩餘秒數／stacksTime 疊層數字 (剩餘秒數)／timeStacks 剩餘秒數 (疊層數字)
-- 自訂格子的層數列用同一組值（entry.text.mode，Pips.TextMode）
R.AURA_TEXT_MODES = { stacks = true, time = true, stacksTime = true, timeStacks = true }
function R.AuraText(cfg, key)
    local t = type(cfg) == "table" and cfg.auraText
    local v = type(t) == "table" and t[key]
    if R.AURA_TEXT_MODES[v] then return v end
    return "stacks"
end

-- 秘法靈魂的文字：seconds（剩餘秒數，預設）／gcd（剩幾個 GCD）
function R.ArcaneSoulText(cfg)
    local v = type(cfg) == "table" and cfg.arcaneSoulText
    if v == "gcd" then return v end
    return "seconds"
end

-- 一列現在要幾格（bar 回 0）。上限讀不到（秘密值）時沿用上次的明文值，沒有就 5
local lastMax = {}
local function SegmentsFor(key)
    local def = RESOURCES[key]
    if not def then return 0 end
    if def.mode == "auraBar" then
        -- 引擎畫的連續填色：格數不受點數型的 30 格上限限制（橫掃攻擊 18 層）
        local m = def.maxFn and def.maxFn() or def.max
        return math.max(1, math.min(30, math.floor(tonumber(m) or 1)))
    end
    if def.mode ~= "pip" then return 0 end
    if def.foldable and R.Folded(Cfg(), key) then return FOLD_SEGMENTS end
    if def.max then return def.max end
    local _, max = GetValue(key)
    local pm = Plain(max)
    if pm == nil then pm = lastMax[key] or 5 else lastMax[key] = pm end
    if pm <= 0 then return 0 end
    return math.min(MAX_SEGMENTS, pm)
end
R.SegmentsFor = SegmentsFor

------------------------------------------------------------
-- 充能的連擊點
--
--   盜賊  GetUnitChargedPowerPoints("player") → 被充能的**索引**陣列；事件 UNIT_POWER_POINT_CHARGE
--   野德  光環 405189 的層數 n ⇒ 第 1..n 格算充能
-- 查表用檔案層級的表重用（Update 掛在能量事件上）。索引一律驗過明文才當 key。
------------------------------------------------------------
local FERAL_OVERFLOW_AURA = 405189
local chargedLookup = {}
local chargedDirty = true

local function Wipe(t) for k in pairs(t) do t[k] = nil end end

local function RefreshChargedLookup()
    chargedDirty = false
    Wipe(chargedLookup)
    local fn = GetUnitChargedPowerPoints
    if type(fn) ~= "function" then return end
    local ok, list = pcall(fn, "player")
    if not ok or type(list) ~= "table" then return end
    for i = 1, #list do
        local idx = Plain(list[i])
        if idx and idx > 0 then chargedLookup[idx] = true end
    end
end

local function ChargedPoints(key)
    if key ~= "ComboPoints" then return nil end
    if CLASS == "ROGUE" then
        if chargedDirty then RefreshChargedLookup() end
        return next(chargedLookup) and chargedLookup or nil
    end
    if CLASS == "DRUID" then
        local n = Plain(AuraStacks(FERAL_OVERFLOW_AURA))
        if not n or n <= 0 then return nil end
        Wipe(chargedLookup)
        for i = 1, math.min(n, MAX_SEGMENTS) do chargedLookup[i] = true end
        return chargedLookup
    end
    return nil
end

------------------------------------------------------------
-- 數值文字
------------------------------------------------------------
-- 法力縮寫：none（完整數字）／k（K、M）／wan（萬、億；中日韓讀法）
function R.FormatMana(v, max, cfg)
    if type(v) ~= "number" then return "" end
    if cfg and cfg.manaPercent then
        if not max or max <= 0 then return "" end
        return ("%d%%"):format(math.floor(v / max * 100 + 0.5))
    end
    local mode = cfg and cfg.manaAbbrev or "k"
    if mode == "wan" then
        if v >= 1e8 then return ("%.2f"):format(v / 1e8) .. L["yi"] end
        if v >= 1e4 then return ("%.1f"):format(v / 1e4) .. L["wan"] end
        return ("%d"):format(v)
    elseif mode == "k" then
        if v >= 1e6 then return ("%.1fM"):format(v / 1e6) end
        if v >= 1e4 then return ("%.0fK"):format(v / 1e3) end
        if v >= 1e3 then return ("%.1fK"):format(v / 1e3) end
        return ("%d"):format(v)
    end
    return ("%d"):format(v)
end

-- 秘密值（12.1 起法力、戰鬥中的其他資源）Lua 讀不到：縮寫與百分比全交給 C 端，Lua 只當傳遞者。
-- 分段照 R.FormatMana：significand ＝ floor(v ／ significandDivisor)，印 significand ／ fractionDivisor
local abbrevCfg = {}
local function AbbrevConfig(mode)
    if abbrevCfg[mode] ~= nil then return abbrevCfg[mode] end
    local opts
    if mode == "wan" then
        opts = {
            { breakpoint = 1e8, abbreviation = L["yi"],  significandDivisor = 1e6, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1e4, abbreviation = L["wan"], significandDivisor = 1e3, fractionDivisor = 10,  abbreviationIsGlobal = false },
            { breakpoint = 1,   abbreviation = "",       significandDivisor = 1,   fractionDivisor = 1,   abbreviationIsGlobal = false },
        }
    elseif mode == "k" then
        opts = {
            { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
            { breakpoint = 1e4, abbreviation = "K", significandDivisor = 1e3, fractionDivisor = 1,  abbreviationIsGlobal = false },
            { breakpoint = 1e3, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
            { breakpoint = 1,   abbreviation = "",  significandDivisor = 1,   fractionDivisor = 1,  abbreviationIsGlobal = false },
        }
    end
    local cfg = false
    if opts and CreateAbbreviateConfig then
        local ok, c = pcall(CreateAbbreviateConfig, opts)
        if ok and c then cfg = { config = c } end
    end
    abbrevCfg[mode] = cfg
    return cfg
end

-- 數值寫進 FontString：明文走 R.FormatMana，秘密值原樣交給 AbbreviateNumbers／SetFormattedText
-- percentOf ＝ 要印百分比時的 power type（秘密值的百分比只能問 UnitPowerPercent）
function R.SetNumberText(fs, v, max, cfg, percentOf)
    if not ns.IsSecret(v) and (max == nil or not ns.IsSecret(max)) then
        fs:SetText(R.FormatMana(v, max, cfg))      -- 不是數字時 FormatMana 回空字串
        return
    end
    if cfg and cfg.manaPercent and percentOf then
        local scale = CurveConstants and CurveConstants.ScaleTo100
        if UnitPowerPercent and scale then
            fs:SetFormattedText("%d%%", UnitPowerPercent("player", percentOf, false, scale))
        else
            fs:SetText("")
        end
        return
    end
    local ac = AbbrevConfig(cfg and cfg.manaAbbrev or "k")
    if ac and AbbreviateNumbers then
        fs:SetText(AbbreviateNumbers(v, ac))
    else
        fs:SetFormattedText("%d", v)
    end
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local rows = {}                 -- 池化的列（frame 刪不掉，換專精只換內容）
local condState = RC.NewState()

-- 邊框：疊在填充之上（不是內縮），線寬換成整數實體像素。
-- 粗細與顏色是資源條的外觀設定（borderSize 0～4 實體像素、borderColor；每種資源可在自己的外觀裡蓋，
-- R.StyleFor 的代理表）。預設 1px 不透明黑 ＝ 加設定以前的樣子。0 ＝ 不畫邊框
R.BORDER_MIN, R.BORDER_MAX, R.BORDER_DEFAULT = 0, 4, 1
local BORDER_BLACK = { r = 0, g = 0, b = 0, a = 1 }

function R.BorderSize(cfg)
    local v = tonumber(type(cfg) == "table" and cfg.borderSize or nil)
    if not v then return R.BORDER_DEFAULT end
    v = math.floor(v + 0.5)
    if v < R.BORDER_MIN then v = R.BORDER_MIN elseif v > R.BORDER_MAX then v = R.BORDER_MAX end
    return v
end

-- 回傳色表 { r, g, b, a }（壞資料／沒存 ＝ 不透明黑）
function R.BorderColor(cfg)
    local c = type(cfg) == "table" and RC.ValidColor(cfg.borderColor) or nil
    return c or BORDER_BLACK
end

local function MakeEdge(parent, p1, p2)
    local e = parent:CreateTexture(nil, "OVERLAY")
    e:SetTexture(SOLID)
    e:SetVertexColor(0, 0, 0, 1)
    e:SetPoint(p1)
    e:SetPoint(p2)
    return e
end

-- 一組四條邊（上、下、左、右）的粗細與顏色。t ＝ 實體像素整數（0 ＝ 藏起來）、c ＝ 色表。
-- 值沒變就不碰貼圖（重排時每列都會叫，設定沒改就零寫入）。
-- ⚠ 線寬是 ns.P.Scale(t)：UI 縮放改了要重算 ⇒ 握柄也記下當時的 1px 換算值
local function PaintEdges(edges, t, c)
    if type(edges) ~= "table" then return end
    t = tonumber(t) or R.BORDER_DEFAULT
    c = c or BORDER_BLACK
    local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
    local px = ns.P.Scale(1)
    if edges.t == t and edges.px == px and edges.r == r and edges.g == g and edges.b == b and edges.a == a then return end
    edges.t, edges.px, edges.r, edges.g, edges.b, edges.a = t, px, r, g, b, a
    if t <= 0 then
        for i = 1, 4 do edges[i]:Hide() end
        return
    end
    local w = ns.P.Scale(t)
    edges[1]:SetHeight(w)
    edges[2]:SetHeight(w)
    edges[3]:SetWidth(w)
    edges[4]:SetWidth(w)
    for i = 1, 4 do
        edges[i]:SetVertexColor(r, g, b, a)
        edges[i]:Show()
    end
end
R.PaintEdges = PaintEdges

-- 給 AuraBar 裝飾（geom.px／geom.edge）：邊框粗細換成 UI 單位（0 ＝ 不畫）、顏色換成 { r, g, b, a } 陣列
function R.DecorPx(cfg)
    local t = R.BorderSize(cfg)
    if t <= 0 then return 0 end
    return ns.P.Scale(t)
end

function R.EdgeArray(cfg)
    local c = R.BorderColor(cfg)
    return { c.r or 0, c.g or 0, c.b or 0, c.a or 1 }
end

-- 一格一個框的分段（點數型、自訂格子）：第 i 格的 x 與寬（從填充起點量）。
-- 整列先換成整數實體像素再切：每格的左右邊界各自四捨五入，零頭平均分到各格，最後一格的右緣一定落在 W 上。
-- ⚠ 不能「格寬先對齊像素、再乘 n」：每格的捨入誤差會累積，6 格的符文列比同寬的符能條多出 2px
-- （玩家回報「自動同寬下兩列對不齊」）。
-- border ＝ 邊框粗細（實體像素；沒給 ＝ 1，天空騎術這種不吃資源條設定的呼叫端照舊）。
-- 每格自帶邊框，格距 0 時相鄰兩條邊並排成 2t ⇒ 改成重疊 t 實體像素，兩格共用同一條邊；
-- 邊框 0 時格距 0 ＝ 剛好相貼（不重疊）。格距 > 0 跟邊框無關：兩格之間空 spacing 實體像素
function R.SegCell(W, n, spacing, i, border)
    local px = ns.P.Scale(1)
    if not px or px <= 0 then px = 1 end
    local t = math.floor((tonumber(border) or 1) + 0.5)
    if t < 0 then t = 0 end
    local gp = math.floor((tonumber(spacing) or 1) + 0.5)
    if gp <= 0 then gp = -t end
    local Wp = math.floor(W / px + 0.5)
    local span = Wp + gp
    local x0 = math.floor((i - 1) * span / n + 0.5)
    local x1 = math.floor(i * span / n + 0.5) - gp
    return x0 * px, (x1 - x0) * px
end

-- 在 frame 上建四條邊，回傳握柄（給 PaintEdges 改粗細／顏色）。沒給 t／c ＝ 1px 黑
-- （天空騎術照這個預設，不吃資源條的設定）
local function Edges(frame, t, c)
    local edges = {
        MakeEdge(frame, "TOPLEFT", "TOPRIGHT"),
        MakeEdge(frame, "BOTTOMLEFT", "BOTTOMRIGHT"),
        MakeEdge(frame, "TOPLEFT", "BOTTOMLEFT"),
        MakeEdge(frame, "TOPRIGHT", "BOTTOMRIGHT"),
    }
    PaintEdges(edges, t or R.BORDER_DEFAULT, c or BORDER_BLACK)
    return edges
end
R.Edges = Edges

-- 一格＝一顆 StatusBar（min i-1、max i，SetValue 目前值 ⇒ 秘密值也畫得對）
local function MakeSegment(row)
    local seg = CreateFrame("StatusBar", nil, row)
    seg:SetStatusBarTexture(SOLID)
    local bg = seg:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(SOLID)
    bg:SetAllPoints(seg)
    seg.bg = bg
    seg.edges = Edges(seg)
    seg:Hide()
    return seg
end

-- 符文格的秒數（懶建；只有符文列、倒數開著才顯示）。
-- 顯示／隱藏只在排版時做，更新只換字（SetText("")），熱路徑上不碰 Show／Hide
-- 數字的描邊：資源條自己的 textOutline（全域；每種資源可在自己的外觀裡蓋，R.StyleFor 的代理表）；
-- 沒存／"INHERIT" ＝ 跟主題的描邊（玩家回報「法力條不支援改描邊」，2026-10-03）
local function TextOutline(cfg)
    local v = type(cfg) == "table" and cfg.textOutline
    if type(v) == "string" and v ~= "" and v ~= ns.Media.INHERIT then return ns.Media.Outline(v) end
    return ns.Media.ThemeOutline()
end
R.TextOutline = TextOutline          -- 虛空化身那兩段字「跟隨這一列的數字」用（Modules/DevourerMeta.lua）

local function LayoutRuneTimer(seg, on, cfg)
    if not on then
        if seg.timer then seg.timer:Hide() end
        return
    end
    if not seg.timer then
        local fs = seg:CreateFontString(nil, "OVERLAY")
        -- ⚠ 先給字型才能 SetText
        ns.Media.SetPixelFont(fs, 10, "OUTLINE")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", seg, "CENTER", 0, 0)
        fs:SetTextColor(1, 1, 1, 1)
        seg.timer = fs
    end
    ns.Media.SetPixelFont(seg.timer, tonumber(cfg.textSize) or 10, TextOutline(cfg), ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font")))
    seg.timer:SetText("")
    seg.timerSec = nil
    seg.timer:Show()
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.segs = {}
    for i = 1, MAX_SEGMENTS do row.segs[i] = MakeSegment(row) end
    row.barBG = row:CreateTexture(nil, "BACKGROUND")
    row.barBG:SetAllPoints(row)
    row.barBG:SetTexture(SOLID)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetStatusBarTexture(SOLID)
    -- 邊框建在 bar 上：bar 是層級更高的子框，建在 row 上會被填充蓋掉
    row.barEdges = Edges(row.bar)
    -- 數值掛在獨立的高層框上，父層是 row（點數型會把 bar 整個藏起來）
    -- 懶建的零件先放 false（有就是框、沒有就是 false；沒寫過的欄位別指望是 nil 以外的東西）
    row.ab, row.abDecor, row.absorbClip, row.absorbBar = false, false, false, false
    row.overs, row.folded = false, false      -- 氣漩武器摺疊的上層（懶建）
    row.metaTime, row.metaStars = false, false   -- 噬滅的虛空化身計時／崩陷之星計數（懶建，Modules/DevourerMeta.lua）
    row.textFrame = CreateFrame("Frame", nil, row)
    row.textFrame:SetAllPoints(row)
    row.text = row.textFrame:CreateFontString(nil, "OVERLAY")
    -- ⚠ 先給字型才能 SetText（沒字型的 FontString SetText 是硬錯）
    ns.Media.SetPixelFont(row.text, 10, "OUTLINE")
    row.text:SetDrawLayer("OVERLAY", 7)
    row.text:SetJustifyH("CENTER")
    row.text:SetPoint("CENTER", row.textFrame, "CENTER", 0, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row:Hide()
    return row
end

------------------------------------------------------------
-- 條件規則的整條層級覆寫（透明度與數值文字色）。列是池化重用的：
-- 規則不成立要還原、換列也要還原（row 是我們自己的框，欄位可以寫）
------------------------------------------------------------
local function ClearRowOverrides(row)
    if not row.condApplied then return end
    row:SetAlpha(1)
    row.text:SetTextColor(1, 1, 1, 1)
    row.condApplied = nil
    row.condAlpha = nil
end

local function ApplyRowOverrides(row, ov)
    if not ov then
        ClearRowOverrides(row)
        return
    end
    local a = (type(ov.alpha) == "number") and ov.alpha or 1
    if row.condAlpha ~= a then
        row:SetAlpha(a)
        row.condAlpha = a
    end
    local tc = RC.ValidColor(ov.tagColor)
    if tc then row.text:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1) else row.text:SetTextColor(1, 1, 1, 1) end
    row.condApplied = true
end

-- 背景（空的那截）的玩家設定（玩家回報 2026-10-03：以前只能換成空材質才透明）：
--   bgAlpha   乘在最後的不透明度上（1 ＝ 預設的深淺；0 ＝ 全透明）。條件規則的 bgColor 也照乘
--   bgCustom＋bgColor  換掉「自動推的」底色（點數型的暗灰、連續條的主色 × 0.25）；條件規則命中時規則優先
--   征戰聖擊那種自己有 backColor 的列：顏色照它，只乘 bgAlpha
local function BgAlpha(cfg)
    local a = tonumber(type(cfg) == "table" and cfg.bgAlpha) or 1
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end
R.BgAlpha = BgAlpha

local function BgCustom(cfg)
    if type(cfg) ~= "table" or not cfg.bgCustom then return nil end
    return RC.ValidColor(cfg.bgColor)
end
R.BgCustom = BgCustom

-- 「未填滿」的顏色（點數型）：整條層級規則的 bgColor 命中時取代暗色 → 色表, alpha
local function DimColor(barOv, cfg)
    local m = BgAlpha(cfg)
    if barOv then
        local bc = RC.ValidColor(barOv.bgColor)
        if bc then return bc, (bc.a or DIM.a) * m end
    end
    local cc = BgCustom(cfg)
    if cc then return cc, DIM.a * m end
    return DIM, DIM.a * m
end
R.DimColor = DimColor

-- 同上，給 AuraBar 的 geom.dim（{ r, g, b, a } 陣列）
function R.DimArray(cfg)
    local c, a = DimColor(nil, cfg)
    return { c.r, c.g, c.b, a }
end

-- 連續條的背景：規則 bgColor ＞ 自訂背景色 ＞ 主色 × 0.25；alpha 乘 bgAlpha
local function PaintBarBG(row, cfg, barOv, fc)
    local m = BgAlpha(cfg)
    local bgc = barOv and RC.ValidColor(barOv.bgColor)
    if bgc then
        row.barBG:SetVertexColor(bgc.r, bgc.g, bgc.b, (bgc.a or 0.8) * m)
        return
    end
    local cc = BgCustom(cfg)
    if cc then
        row.barBG:SetVertexColor(cc.r, cc.g, cc.b, 0.8 * m)
    else
        row.barBG:SetVertexColor(fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, 0.8 * m)
    end
end

------------------------------------------------------------
-- 版面
------------------------------------------------------------
function R.Width(cfg)
    cfg = cfg or Cfg() or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = ns.Bars and ns.Bars.FirstRowWidth and ns.Bars.FirstRowWidth("essential") or 0
        if w <= 0 then w = 200 end
    end
    return w
end

local function RowHeight(cfg) return tonumber(type(cfg) == "table" and cfg.rowHeight) or 8 end

-- 背景（空的那截）的材質路徑：沒挑或「跟填充相同」就用填充那張（自訂格子也走這支）
function R.BgTexture(cfg)
    local v = type(cfg) == "table" and cfg.bgTexture
    if type(v) ~= "string" or v == "" or v == ns.Media.INHERIT then
        return ns.Media.Texture(type(cfg) == "table" and cfg.texture or nil)
    end
    return ns.Media.Texture(v)
end
R.RowHeight = RowHeight

------------------------------------------------------------
-- 每種資源自己的外觀（resources.style[key]；設定頁每一列「設定…」視窗裡那一節，Options/ResourceSettings.lua）
--
--   style[key] = { follow = true|false, texture, bgTexture, barAlpha, bgAlpha, bgCustom, bgColor, smooth, showText,
--                  textFont, textSize, textOutline, borderSize, borderColor }
--   follow 沒存 ＝ 跟（舊存檔沒有這張表 ⇒ 畫面一模一樣，不遷移）；跟著時其餘欄位不讀。
--
-- 不跟時，那一列的排版與更新（LayoutRow／UpdateRow 那一整串）讀 R.StyleFor 回的**代理表**：
-- 外觀欄位（STYLE_FIELDS）先查 style[key]、沒存的退回資源條的全域值；其他欄位（manaAbbrev、colors、conditions、
-- fillDirection、segmentSpacing…）一律照讀 cfg。
-- ⚠ 代理表只給引擎讀值：不存進 SV、不 pairs（Lua 5.1 沒有 __pairs，遍歷是空的）、不寫（寫就報錯）。
--   設定頁與匯出一律讀原表。每個 key 快取一張（cfg／style[key] 換了表就重建），R.Apply 時作廢
------------------------------------------------------------
local STYLE_FIELDS = { texture = true, bgTexture = true, barAlpha = true, smooth = true,
                       showText = true, textFont = true, textSize = true, textOutline = true,
                       bgAlpha = true, bgCustom = true, bgColor = true,
                       borderSize = true, borderColor = true }
R.STYLE_FIELDS = STYLE_FIELDS

local function OwnStyle(cfg, key)
    local st = type(cfg) == "table" and cfg.style
    local s = type(st) == "table" and st[key]
    return type(s) == "table" and s or nil
end

-- 這一列的外觀跟不跟資源條（判準是 follow ~= false）
function R.StyleFollows(cfg, key)
    local own = OwnStyle(cfg, key)
    return not (own and own.follow == false)
end

local styleProxies = {}          -- [key] = { cfg, own, proxy }

local function ProxyWrite() error("MiliUI_CooldownManager: resource style proxy is read-only", 2) end

-- 不看 follow 的欄位：「長條上顯示數值」在設定視窗的「版面」節，每一列各自存、沒存＝照全域（使用者 2026-10-03 指定）
local INDEPENDENT = { showText = true }
R.INDEPENDENT_FIELDS = INDEPENDENT

function R.StyleFor(cfg, key)
    local own = OwnStyle(cfg, key)
    if not own then return cfg end
    local follow = own.follow ~= false
    if follow and own.showText == nil then return cfg end
    local hit = styleProxies[key]
    if hit and hit.cfg == cfg and hit.own == own then return hit.proxy end
    local proxy = setmetatable({}, {
        __index = function(_, k)
            if INDEPENDENT[k] or (STYLE_FIELDS[k] and own.follow == false) then
                local v = own[k]
                if v ~= nil then return v end
            end
            return cfg[k]
        end,
        __newindex = ProxyWrite,
    })
    styleProxies[key] = { cfg = cfg, own = own, proxy = proxy }
    return proxy
end

function R.InvalidateStyles()
    for k in pairs(styleProxies) do styleProxies[k] = nil end
end

-- 一列的高度：resources.heights[key]（每種資源設定視窗的「高」，所有專精共用，跟 order 一樣）。
-- 沒設過的退回舊的共用值：征戰聖擊 crusadingHeight（預設 4）、其他 rowHeight（預設 14）——
-- 這兩個欄位不再有控件，留著當起始值，舊存檔不用遷移
R.HEIGHT_MIN, R.HEIGHT_MAX = 1, 30
function R.KeyRowHeight(cfg, key)
    local t = type(cfg) == "table" and cfg.heights
    local h = type(t) == "table" and tonumber(t[key])
    if h then return h end
    local def = RESOURCES[key]
    if def and def.crusading then
        return tonumber(type(cfg) == "table" and cfg.crusadingHeight) or 4
    end
    return RowHeight(cfg)
end

function R.SetKeyHeight(cfg, key, v)
    if type(cfg) ~= "table" or type(key) ~= "string" then return end
    v = math.floor((tonumber(v) or R.KeyRowHeight(cfg, key)) + 0.5)
    v = math.max(R.HEIGHT_MIN, math.min(R.HEIGHT_MAX, v))
    if type(cfg.heights) ~= "table" then cfg.heights = {} end
    cfg.heights[key] = v
end

-- 征戰聖擊的填充：elapsed 已揮的時間長出來（預設）／remaining 剩餘時間縮短
function R.CrusadingFill(cfg)
    local v = type(cfg) == "table" and cfg.crusadingFill
    if v == "remaining" then return v end
    return "elapsed"
end

-- 吸收盾列的零件（懶建）：裁切框（跟列一樣大）＋裡面一條寬 W / cap 的 StatusBar
local function EnsureAbsorb(row)
    if row.absorbClip then return end
    local clip = CreateFrame("Frame", nil, row)
    clip:SetAllPoints(row)
    clip:SetClipsChildren(true)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture(SOLID)
    row.absorbClip, row.absorbBar = clip, bar
end

local function HideAbsorb(row)
    if row.absorbClip then row.absorbClip:Hide() end
end

local function OnAuraRegen() R.Mark(true) end

-- 引擎寫層數的列。回傳 true ＝ 容器就緒（這一列交給引擎）；false ＝ 退回明文畫法
-- 剩餘時間條（與層數列選了秒數時）的秒數：低於這個秒數印一位小數（秘法靈魂 4 秒整段都有小數；黯黑力量剩 5 秒起）
local TIMER_DECIMALS_BELOW = 5

local function LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local gap = ns.P.Scale(tonumber(cfg.segmentSpacing) or 1)
    local geom = {
        W = W, H = H, n = numSeg, gap = gap, segW = (W - gap * (numSeg - 1)) / numSeg, reversed = reversed,
        segments = true, dim = R.DimArray(cfg), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
    }
    local cc = ResolveColor(cfg, key, "color")
    local count
    if cfg.showText and not def.instances then
        -- 文字交給引擎（層數 SetApplicationCount／秒數 SetDurationText）：字級換成實體像素，樣式進簽章
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        count = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg),
            mode = R.AuraText(cfg, key),
            decimals = TIMER_DECIMALS_BELOW,
        }
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = def.instances and "instances" or "applications",
        spellIDs = def.auras, max = numSeg, texture = tex, color = cc, alpha = tonumber(cfg.barAlpha) or 1,
        reversed = reversed, cell = def.instances and geom or nil, count = count,
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    ns.AuraBar.RowDecor(row, geom, (row:GetFrameLevel() or 1) + 8)
    return true
end


-- 空條的底色：跟連續條同一套（主色 × 0.25、alpha 0.8）。out 給了就填進去（熱路徑上不配表）
function R.TimerDim(c, out)
    out = out or {}
    out[1], out[2], out[3], out[4] = c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.8
    return out
end
local timerDimScratch = {}

-- 剩餘時間條的底色：有自己底色的列（征戰聖擊的 backColor，含 alpha）照它，其他照主色推
function R.TimerBack(cfg, key, cc, out)
    local colors = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors
    local t = colors and type(colors[key]) == "table" and colors[key].backColor
    if type(t) == "table" and t.r then
        out = out or {}
        out[1], out[2], out[3], out[4] = t.r, t.g, t.b, tonumber(t.a) or 1
        return out
    end
    return R.TimerDim(cc, out)
end

-- 剩餘時間條「當背景畫」的底色：TimerBack 再套玩家的背景設定（自己有 backColor 的列只乘 bgAlpha）。
-- ⚠ 征戰聖擊「經過時間」模式拿 TimerBack 當**填充**色（PaintMirror），那裡照用 TimerBack
function R.TimerBg(cfg, key, cc, out)
    out = R.TimerBack(cfg, key, cc, out)
    local colors = type(cfg) == "table" and type(cfg.colors) == "table" and cfg.colors
    local own = colors and type(colors[key]) == "table" and type(colors[key].backColor) == "table"
    local custom = not own and BgCustom(cfg)
    if custom then out[1], out[2], out[3] = custom.r, custom.g, custom.b end
    out[4] = out[4] * BgAlpha(cfg)
    return out
end

-- 光環剩餘時間條。回傳 true ＝ 容器就緒（這一列交給引擎）；false ＝ 先畫空條
local function LayoutAuraTimer(row, key, def, cfg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local cc = ResolveColor(cfg, key, "color")
    local text
    if cfg.showText then
        -- 字級換成實體像素（同 row.text 的 SetPixelFont）：按鈕子樹裡的 FontString 忽略父層縮放
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        text = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg),
            decimals = TIMER_DECIMALS_BELOW,
        }
    end
    if text and def.gcdText and R.ArcaneSoulText(cfg) == "gcd" then
        -- 剩幾個 GCD：格式器只能在 initializeFrame 給 ⇒ GCD 長度（明文、0.05 秒一格）進簽章，變了換容器
        text.gcd = R.ReadGcd()
        text.last = L["Last"]
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = "duration", spellIDs = def.auras, max = 1, texture = tex, color = cc,
        alpha = tonumber(cfg.barAlpha) or 1, reversed = reversed, text = text,
    })
    row.gcdUsed = text and text.gcd or nil
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    -- 空條（暗底＋1px 黑邊）畫在列上：光環不在時按鈕藏著，看到的就是這個
    ns.AuraBar.RowDecor(row, {
        W = W, H = H, n = 1, gap = 0, segW = W, reversed = reversed, segments = false,
        dim = R.TimerBg(cfg, key, cc), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
    }, (row:GetFrameLevel() or 1) + 8)
    return true
end

-- 百分比條（無視苦痛）：單格容器、層數欄位當 0～appMax 的條值，連續條（裝飾不分格）。
-- 回傳 true ＝ 容器就緒；false ＝ 退回吸收盾總量（absorbBar）
local function LayoutAuraPct(row, key, def, cfg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local cc = ResolveColor(cfg, key, "color")
    local count
    if cfg.showText then
        -- 層數走 SetApplicationCount（不給格式器：引擎拿格式器處理秘密層數會整顆容器壞掉），後面接自己的「%」
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        count = {
            font = ns.Media.Font(ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font"))),
            size = (tonumber(cfg.textSize) or 10) * scale,
            outline = TextOutline(cfg),
            suffix = "%",
        }
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = "applications", spellIDs = def.auras, max = tonumber(def.appMax) or 100, texture = tex, color = cc,
        alpha = tonumber(cfg.barAlpha) or 1, reversed = reversed, count = count,
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    -- 空條（暗底＋1px 黑邊、不分格）畫在列上：增益不在時按鈕藏著，看到的就是這個
    ns.AuraBar.RowDecor(row, {
        W = W, H = H, n = 1, gap = 0, segW = W, reversed = reversed, segments = false,
        dim = R.TimerBg(cfg, key, cc), px = R.DecorPx(cfg), edge = R.EdgeArray(cfg), bgTex = R.BgTexture(cfg),
    }, (row:GetFrameLevel() or 1) + 8)
    return true
end

-- 摺疊的上層（一格一顆，錨在列上、位置跟底層同一格；層級比底層高、自帶黑邊）
local function LayoutFold(row, on, numSeg, W, H, cfg, tex, reversed)
    local bt, bc = R.BorderSize(cfg), R.BorderColor(cfg)
    if not on then
        if row.overs then for _, o in ipairs(row.overs) do o:Hide() end end
        row.folded = false
        return
    end
    row.overs = row.overs or {}
    local lv = row:GetFrameLevel() or 1
    for i = 1, numSeg do
        local o = row.overs[i]
        if not o then
            o = CreateFrame("StatusBar", nil, row)
            o:SetStatusBarTexture(SOLID)
            o.edges = Edges(o)
            row.overs[i] = o
        end
        local x, segW = R.SegCell(W, numSeg, cfg.segmentSpacing, i, bt)
        PaintEdges(o.edges, bt, bc)
        o:SetSize(segW, H)
        o:ClearAllPoints()
        if reversed then
            o:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            o:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        o:SetFrameLevel(lv + 2)
        o:SetStatusBarTexture(tex)
        o:SetMinMaxValues(R.FoldRange(i, 2, numSeg))
        o:SetValue(0)
        o:Show()
    end
    for i = numSeg + 1, #row.overs do row.overs[i]:Hide() end
    -- 數值文字蓋在上層之上
    row.textFrame:SetFrameLevel(lv + 3)
    row.folded = true
end

local function LayoutRow(row, key, cfg, numSeg, W, H)
    local def = RESOURCES[key]
    row:SetSize(W, H)
    -- 換列：上一個資源的條件殘留一律先還原
    row:SetAlpha(1)
    row.condAlpha, row.condApplied = nil, nil
    row.text:SetTextColor(1, 1, 1, 1)
    row.gcdUsed = nil

    local reversed = ns.FillReversed(cfg)
    local tex = ns.Media.Texture(cfg.texture)
    local showText = cfg.showText and true or false
    if def.fill == "rune" then showText = showText and R.RuneText(cfg) == "count" end
    ns.Media.SetPixelFont(row.text, tonumber(cfg.textSize) or 10, TextOutline(cfg), ns.Media.ElementFont(cfg.textFont, ns.Setting(nil, "font")))
    row.text:SetText("")

    -- 這一列實際的畫法：容器沒好時 auraBar 退回 pip（明文層數）、auraTimer 退回空條
    local mode = def.mode
    if mode == "auraBar" then
        mode = R.DrawMode(mode, LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex))
    elseif mode == "auraTimer" then
        mode = R.DrawMode(mode, LayoutAuraTimer(row, key, def, cfg, W, H, reversed, tex))
    elseif mode == "auraPct" then
        mode = R.DrawMode(mode, LayoutAuraPct(row, key, def, cfg, W, H, reversed, tex))
    else
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
        if ns.AuraBar then ns.AuraBar.HideRowDecor(row) end
    end
    -- 退回點數型時照點數型的格數上限
    if mode == "pip" and numSeg and numSeg > MAX_SEGMENTS then
        numSeg = MAX_SEGMENTS
        row.numSeg = numSeg
    end
    row.mode = mode
    -- 引擎寫的列沒有 Lua 讀得到的數字：不印數值文字（剩餘時間條的秒數在按鈕子樹裡，引擎印）
    row.text:SetShown(showText and mode ~= "engine" and mode ~= "timerIdle" and not def.noText)

    local isPip = mode == "pip" and numSeg and numSeg > 0
    local isBar = mode == "bar" or mode == "absorbBar" or mode == "timerIdle" or mode == "mirror"
    row.barBG:SetShown(isBar)
    row.bar:SetShown(isBar)
    if isBar then PaintEdges(row.barEdges, R.BorderSize(cfg), R.BorderColor(cfg)) end
    if mode ~= "absorbBar" then HideAbsorb(row) end

    LayoutFold(row, isPip and R.Folded(cfg, key) or false, numSeg, W, H, cfg, tex, reversed)

    if not isPip then
        for i = 1, MAX_SEGMENTS do row.segs[i]:Hide() end
        if not isBar then return end
        row.bar:SetStatusBarTexture(tex)
        row.bar:SetReverseFill(reversed)
        row.barBG:SetTexture(R.BgTexture(cfg))
        if mode == "mirror" then
            R.PaintMirror(row, key, cfg, reversed)
            return
        end
        if mode == "absorbBar" then
            -- 列本身的 bar 只剩邊框（值 0），真正的填色在裁切框裡那條寬的
            EnsureAbsorb(row)
            local lv = row:GetFrameLevel() or 1
            row.absorbClip:SetFrameLevel(lv + 1)
            row.bar:SetFrameLevel(lv + 2)
            row.textFrame:SetFrameLevel(lv + 3)
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(0)
            local ab = row.absorbBar
            ab:SetStatusBarTexture(tex)
            ab:SetReverseFill(reversed)
            ab:ClearAllPoints()
            -- 寬度是自己的設定算出來的明文：W / cap（上限＝最大生命的 cap 倍 ⇒ 只看得到前 cap）
            local cap = tonumber(def.cap) or 1
            ab:SetSize(W / cap, H)
            if reversed then
                ab:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            else
                ab:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end
            row.absorbClip:Show()
        end
        return
    end

    -- 格寬是除出來的小數 → 對齊實體像素；每格直接錨在列上（不串在前一格）
    local isRune = def.fill == "rune" and cfg.showText and R.RuneText(cfg) == "countdown"
    local bt, bc = R.BorderSize(cfg), R.BorderColor(cfg)
    local bgTex = R.BgTexture(cfg)
    for i = 1, numSeg do
        local seg = row.segs[i]
        local x, segW = R.SegCell(W, numSeg, cfg.segmentSpacing, i, bt)
        PaintEdges(seg.edges, bt, bc)
        seg:SetSize(segW, H)
        seg:ClearAllPoints()
        -- 從右到左：第 1 格在最右邊
        if reversed then
            seg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            seg:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        seg:SetStatusBarTexture(tex)
        seg.bg:SetTexture(bgTex)
        seg:SetMinMaxValues(i - 1, i)
        LayoutRuneTimer(seg, isRune, cfg)
        seg:Show()
    end
    for i = numSeg + 1, MAX_SEGMENTS do row.segs[i]:Hide() end
end

------------------------------------------------------------
-- 一列的更新
------------------------------------------------------------
local function SetSegColor(seg, c, a)
    local t = seg:GetStatusBarTexture()
    if t then t:SetVertexColor(c.r, c.g, c.b, a) end
end

------------------------------------------------------------
-- 符文（死亡騎士）
--
-- GetRuneCooldown(i) 的 start／duration／ready 在 12.1 是明文；仍一律過 Plain／IsSecret，
-- 讀不到的那顆當「在轉、進度不明」（不填、不印秒數），排序照樣排在最後，不會跳格。
-- 同時最多三顆在轉，其餘的 start 在未來（排隊中）。cfg.runeQueued（預設開）決定排隊中的怎麼畫：
--   開  秒數印 start＋duration－now（＝從現在到這顆轉好的總等待時間）；填充照「花掉那一刻 → 轉好」
--       整段等待時間走（R.RuneProgress），排隊轉成在轉時不跳回 0
--   關  舊行為：排隊中進度 0、不印秒數，填充只算自己那段冷卻
-- 「花掉那一刻」沒有 API，自己記（runeSpentAt：看到某顆從轉好變成沒轉好的那次更新）。
------------------------------------------------------------
local RUNE_RECHARGE_SHADE = 0.55     -- 在轉的格子：同色系暗一階（狀態只換明暗不換色）
local runeReady, runeRemain, runeProgress, runeQueued, runeOrder = {}, {}, {}, {}, {}
local runeSpentAt = {}               -- [符文編號] = 看到它沒轉好的第一個時間點；轉好時清掉
local runeRechargeColor = { r = 0, g = 0, b = 0 }
local shadeColor = { r = 0, g = 0, b = 0 }  -- 碎片累積中／精華回充中的那一格（同一個係數）

-- 精華回充的狀態：上一次的明文顆數、這一輪回充從什麼時候開始、上次讀到的明文回充速度
local essence = { last = nil, since = nil, rate = nil }

-- 回傳下一格的進度（0～1）或 nil（滿了、讀不到）。pc 是明文顆數
local function EssenceProgress(pc, n)
    local now = GetTime()
    if pc >= n then
        essence.last, essence.since = pc, nil
        return nil
    end
    -- 多一顆 ＝ 上一輪回充完成、下一輪從現在起算；從滿的掉下來 ＝ 回充從現在開始。
    -- 花掉（變少）但沒滿過：回充照原本的節奏繼續，不重算
    if essence.since == nil or essence.last == nil or pc > essence.last then essence.since = now end
    essence.last = pc
    local partial
    if UnitPartialPower then
        local ok, v = pcall(UnitPartialPower, "player", PT.Essence)
        if ok then partial = Plain(v) end
    end
    if GetPowerRegenForPowerType then
        local ok, r = pcall(GetPowerRegenForPowerType, PT.Essence)
        r = ok and Plain(r) or nil
        if r and r > 0 then essence.rate = r end
    end
    return R.EssenceFrac(partial, essence.rate, now - essence.since)
end

-- 純函式：沒轉好的符文的填充進度（0～1）。countQueued 關：只算自己那段冷卻（排隊中＝0）；
-- 開：從 spentAt（花掉那一刻）到 start＋duration 的整段等待時間，spentAt 晚於 start 時以 start 為準
function R.RuneProgress(now, start, duration, spentAt, countQueued)
    local t0, span = start, duration
    if countQueued and type(spentAt) == "number" and spentAt < start then
        t0 = spentAt
        span = start + duration - spentAt
    end
    if span <= 0 then return 0 end
    local prog = (now - t0) / span
    if prog < 0 then prog = 0 elseif prog > 1 then prog = 1 end
    return prog
end

-- 回傳轉好的顆數、有沒有在轉的
local function ReadRunes(n, now, countQueued)
    local readyCount, anyRecharging = 0, false
    for i = 1, n do
        local ok, start, duration, isReady = pcall(GetRuneCooldown, i)
        local r, rem, prog, queued = false, nil, nil, false
        if ok and isReady ~= nil and not ns.IsSecret(isReady) then r = isReady and true or false end
        if r then
            readyCount = readyCount + 1
            runeSpentAt[i] = nil
        else
            anyRecharging = true
            if not runeSpentAt[i] then runeSpentAt[i] = now end
            local s, d = ok and Plain(start), ok and Plain(duration)
            if s and d and d > 0 then
                rem = s + d - now
                if rem < 0 then rem = 0 end
                queued = s > now
                prog = R.RuneProgress(now, s, d, runeSpentAt[i], countQueued)
            end
        end
        runeReady[i], runeRemain[i], runeProgress[i], runeQueued[i] = r, rem, prog, queued
    end
    return readyCount, anyRecharging
end

-- 純函式：order[格位] = 符文編號。轉好的靠左（照編號）、在轉的依剩餘時間由短到長，
-- 剩餘讀不到的排最後；同分照編號（插入排序，最多六顆，不配表、不建 closure）
function R.RuneOrder(ready, remain, n, order)
    order = order or {}
    local k = 0
    for i = 1, n do
        if ready[i] then k = k + 1; order[k] = i end
    end
    local first = k + 1
    for i = 1, n do
        if not ready[i] then
            local key = remain[i] or math.huge
            local j = k
            while j >= first and (remain[order[j]] or math.huge) > key do
                order[j + 1] = order[j]
                j = j - 1
            end
            order[j + 1] = i
            k = k + 1
        end
    end
    for i = n + 1, #order do order[i] = nil end
    return order
end

-- 純函式：沒轉好的格子要印的秒數（無條件進位，跟冷卻數字同一種讀法）；
-- 排隊中的：countQueued 開印總等待時間、關不印；讀不到／轉完回 nil
function R.RuneSeconds(remain, queued, countQueued)
    if type(remain) ~= "number" or remain <= 0 then return nil end
    if queued and not countQueued then return nil end
    return math.ceil(remain)
end

local function UpdatePipRow(row, cfg, def, key, numSeg, cc, conds)
    local alpha = tonumber(cfg.barAlpha) or 1
    if def.fill == "rune" then
        -- 符文：先排序再畫（轉好的靠左、在轉的依剩餘時間往右排），在轉的格子填進度
        local countQueued = cfg.runeQueued ~= false
        local readyCount, anyRecharging = ReadRunes(numSeg, GetTime(), countQueued)
        local order = R.RuneOrder(runeReady, runeRemain, numSeg, runeOrder)
        local barOv
        if conds then
            RC.FillState(condState, readyCount, numSeg, CurrentSpecID())
            barOv = RC.FirstMatch(conds, condState, nil)
        end
        local dimC, dimA = DimColor(barOv, cfg)
        local runeText = cfg.showText and R.RuneText(cfg) or nil
        local countdown = runeText == "countdown"
        local rc = runeRechargeColor
        rc.r, rc.g, rc.b = cc.r * RUNE_RECHARGE_SHADE, cc.g * RUNE_RECHARGE_SHADE, cc.b * RUNE_RECHARGE_SHADE
        for slot = 1, numSeg do
            local idx = order[slot]
            local seg = row.segs[slot]
            local ready = runeReady[idx]
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(ready and 1 or (runeProgress[idx] or 0))
            local c = ready and cc or rc
            if conds then
                -- 符文是唯一「沒轉好的格子也吃條件色」的列（pipRecharging）；格子序號是排序後的位置
                condState.pipRecharging = not ready
                local ov = RC.FirstMatch(conds, condState, slot)
                local oc = ov and RC.ValidColor(ov.color)
                if oc then
                    c = oc
                    if not ready then seg:SetValue(1) end    -- 命中時整格上色，暗底上看不出來
                end
            end
            SetSegColor(seg, c, alpha)
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
            if seg.timer then
                local sec = countdown and not ready and R.RuneSeconds(runeRemain[idx], runeQueued[idx], countQueued)
                if sec then
                    if seg.timerSec ~= sec then
                        seg.timerSec = sec
                        seg.timer:SetFormattedText("%d", sec)
                    end
                elseif seg.timerSec then
                    seg.timerSec = nil
                    seg.timer:SetText("")
                end
            end
        end
        ApplyRowOverrides(row, barOv)
        -- 中間的顆數只在選了「顆數」時印（見 R.RuneText；列的文字顯示與否在 LayoutRow 照同一個設定）
        if runeText == "count" then row.text:SetFormattedText("%d", readyCount) end
        if anyRecharging then R.ArmTicker() end
        return
    end

    local cur = GetValue(key)
    -- 每格的單位數：一般 1；毀滅術的碎片改讀原始單位（一顆 ＝ per），零頭也畫
    local per, fractional = 1, false
    if def.fractionalSpec and def.fractionalSpec == CurrentSpecID() then
        fractional = true
        cur = UnitPower("player", def.power, true) or 0
        per = R.ShardPer(UnitPowerMax("player", def.power, true), UnitPowerMax("player", def.power))
    end
    local pc = Plain(cur)
    -- 整顆數（條件規則與「哪幾格吃條件色」看這個）、正在累積的那一格（暗一階）
    local whole, partialIdx, shown = pc, nil, nil
    if fractional and pc then whole, partialIdx, shown = R.ShardSplit(pc, per, numSeg) end
    -- 精華：下一格畫回充進度（明文才算）；值 ＝ 目前顆數 ＋ 進度
    local value = cur or 0
    if def.fill == "essence" then
        local frac = pc and EssenceProgress(pc, numSeg)
        if frac then
            value = pc + frac
            partialIdx = pc + 1
            R.ArmTicker()
        end
    end
    local shade
    if partialIdx then
        shade = shadeColor
        shade.r, shade.g, shade.b = cc.r * RUNE_RECHARGE_SHADE, cc.g * RUNE_RECHARGE_SHADE, cc.b * RUNE_RECHARGE_SHADE
    end
    local charged = ChargedPoints(key)
    local chargedCC, chargedEmptyCC
    if charged then
        chargedCC = ResolveColor(cfg, key, "chargedColor")
        chargedEmptyCC = ResolveColor(cfg, key, "chargedEmptyColor")
    end
    local barOv
    if conds and whole then
        -- 摺疊時格數只有一半，百分比／已滿要照真正的上限（10 層）算
        RC.FillState(condState, whole, row.folded and numSeg * 2 or numSeg, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local dimC, dimA = DimColor(barOv, cfg)
    local overs = row.folded and row.overs or nil
    local overCC = overs and ResolveColor(cfg, key, "overflowColor") or nil
    for i = 1, numSeg do
        local seg = row.segs[i]
        seg:SetMinMaxValues((i - 1) * per, i * per)
        seg:SetValue(value)                       -- 秘密值照樣：引擎決定這格亮多少
        local isCharged = charged and charged[i]
        local c = isCharged and chargedCC or cc
        if i == partialIdx then c = shade end
        -- 充能且已填滿的格子跳過條件：充能色是「這一格值兩點」的訊號，不能被蓋掉。
        -- 摺疊時格子序號 1～5、條件只套底層
        if conds and whole and not isCharged and i <= whole then
            condState.pipRecharging = false
            local ov = RC.FirstMatch(conds, condState, i)
            local oc = ov and RC.ValidColor(ov.color)
            if oc then c = oc end
        end
        SetSegColor(seg, c, alpha)
        if isCharged then
            -- 充能但還沒填到：底色畫成暗的充能色（打滿之前就看得出哪幾格是充能格）
            seg.bg:SetVertexColor(chargedEmptyCC.r, chargedEmptyCC.g, chargedEmptyCC.b, DIM.a * BgAlpha(cfg))
        else
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
        end
        local o = overs and overs[i]
        if o then
            o:SetValue(value)
            SetSegColor(o, overCC, alpha)
        end
    end
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        -- 光環／技能次數型沒累積時不畫（空著比一顆「0」乾淨）；讀不到明文也不印
        if pc == nil or ((def.aura or def.cast or def.auras) and pc <= 0) then
            row.text:SetText("")
        elseif fractional then
            row.text:SetFormattedText("%.1f", shown or 0)
        else
            row.text:SetFormattedText("%d", pc)
        end
    end
end

-- 醉仙緩勁的段落（純函式）：pct ＝ 醉仙緩勁 ／ 最大生命 × 100（明文才算）。
-- tier3At／tier4At 是第 3／4 段的門檻，nil ＝ 那一段關著（預設關）；高的段先比
function R.StaggerBand(pct, moderateAt, heavyAt, tier3At, tier4At)
    if type(pct) ~= "number" then return nil end
    heavyAt, moderateAt = tonumber(heavyAt) or 60, tonumber(moderateAt) or 30
    tier3At, tier4At = tonumber(tier3At), tonumber(tier4At)
    if tier4At and pct >= tier4At then return "tier4" end
    if tier3At and pct >= tier3At then return "tier3" end
    if pct >= heavyAt then return "heavy" end
    if pct >= moderateAt then return "moderate" end
    return "light"
end
local STAGGER_FIELD = { light = "color", moderate = "moderateColor", heavy = "heavyColor",
                        tier3 = "tier3Color", tier4 = "tier4Color" }
R.STAGGER_FIELD = STAGGER_FIELD

-- 純函式：設定裡開著的第 3／4 段門檻（關著的回 nil）
function R.StaggerTiers(cfg)
    if type(cfg) ~= "table" then return nil, nil end
    local t3 = cfg.staggerTier3Enabled == true and (tonumber(cfg.staggerTier3At) or STAGGER_TIER_AT.tier3[2]) or nil
    local t4 = cfg.staggerTier4Enabled == true and (tonumber(cfg.staggerTier4At) or STAGGER_TIER_AT.tier4[2]) or nil
    return t3, t4
end

-- 滿條上限（% 最大生命）：1～300（第 4 段預設 150%，上限只到 100 的話看不到那一段）
local STAGGER_CEILING_MAX = 300
R.STAGGER_CEILING_MAX = STAGGER_CEILING_MAX
function R.StaggerCeiling(cfg)
    local v = tonumber(type(cfg) == "table" and cfg.staggerCeiling) or 100
    if v < 1 then v = 1 elseif v > STAGGER_CEILING_MAX then v = STAGGER_CEILING_MAX end
    return v
end

-- 醉仙緩勁：上一次明文算出來的段落與滿條上限（副本戰鬥中兩個值會間歇變成秘密值，那幾下沿用）
local staggerLast = { band = nil, max = nil }
R.staggerLast = staggerLast

-- 回傳：條的上限（明文或原始的秘密最大生命）、這次的顏色欄位
local function StaggerResolve(cfg, cur, maxHealth)
    local pc, pmh = Plain(cur), Plain(maxHealth)
    local barMax
    if pmh and pmh > 0 then
        barMax = pmh * R.StaggerCeiling(cfg) / 100
        staggerLast.max = barMax
    elseif staggerLast.max then
        barMax = staggerLast.max
    else
        barMax = maxHealth              -- 從來沒讀到過明文：原始值直接餵（上限 100%）
    end
    if pc and pmh and pmh > 0 then
        local t3, t4 = R.StaggerTiers(cfg)
        staggerLast.band = R.StaggerBand(pc / pmh * 100, cfg.staggerModerateAt, cfg.staggerHeavyAt, t3, t4)
    end
    return barMax, STAGGER_FIELD[staggerLast.band or "light"]
end

-- 大數字（醉仙緩勁、吸收盾）的文字：照法力的縮寫設定，不印百分比
local bigFmt = {}
local function SetBigNumber(fs, v, cfg)
    bigFmt.manaAbbrev = cfg.manaAbbrev
    R.SetNumberText(fs, v, nil, bigFmt)
end

local function UpdateBarRow(row, cfg, def, key, cc, conds)
    local cur, max = GetValue(key)
    if def.stagger then
        local field
        max, field = StaggerResolve(cfg, cur, max)
        cc = ResolveColor(cfg, key, field)
    end
    local pm = Plain(max)
    if pm ~= nil and pm <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    local pc = Plain(cur)
    local barOv
    if conds and pc and pm then
        RC.FillState(condState, pc, pm, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local fc = (barOv and RC.ValidColor(barOv.color)) or cc
    -- 上限與目前值直接交給引擎（可能是秘密值）
    row.bar:SetMinMaxValues(0, max)
    if type(cur) == "number" then
        row.bar:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        row.bar:SetValue(0)
    end
    local t = row.bar:GetStatusBarTexture()
    if t then t:SetVertexColor(fc.r, fc.g, fc.b, tonumber(cfg.barAlpha) or 1) end
    PaintBarBG(row, cfg, barOv, fc)
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        -- 秘密值也照印（交給 C 端），不能先過 Plain：12.1 的法力永遠是秘密值，過了就永遠空白
        if type(cur) ~= "number" then
            row.text:SetText("")
        elseif def.mana then
            R.SetNumberText(row.text, cur, max, cfg, def.power)
        elseif def.bigNumber then
            SetBigNumber(row.text, cur, cfg)
        else
            row.text:SetFormattedText("%d", cur)
        end
    end
end

-- 吸收盾：值與最大生命直接餵那條寬的 StatusBar（上限的 cap 倍由幾何處理）
local function UpdateAbsorbRow(row, cfg, def, key, cc, conds)
    local cur, maxHealth = GetValue(key)
    local ab = row.absorbBar
    if not ab then return end
    local pc, pmh = Plain(cur), Plain(maxHealth)
    local cap = tonumber(def.cap) or 1
    local pm = pmh and pmh * cap or nil        -- 明文才乘（條件規則的百分比用）
    local barOv
    if conds and pc and pm and pm > 0 then
        RC.FillState(condState, math.min(pc, pm), pm, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local fc = (barOv and RC.ValidColor(barOv.color)) or cc
    ab:SetMinMaxValues(0, maxHealth)
    if type(cur) == "number" then
        ab:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        ab:SetValue(0)
    end
    local t = ab:GetStatusBarTexture()
    if t then t:SetVertexColor(fc.r, fc.g, fc.b, tonumber(cfg.barAlpha) or 1) end
    PaintBarBG(row, cfg, barOv, fc)
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        if type(cur) ~= "number" or (pc ~= nil and pc <= 0) then row.text:SetText("") else SetBigNumber(row.text, cur, cfg) end
    end
end

------------------------------------------------------------
-- 征戰聖擊（mode = "mirror"）：鏡射暴雪「追蹤的量條」裡那條
--
-- 為什麼不是 auraTimer（引擎寫光環剩餘時間）：試過（2026-10-02 實機），整列一直是空底。
-- 暴雪冷卻清單登記的是天賦本身 404542（CooldownSetSpell 148597，懲戒 set 901、TrackedBar），
-- 那是被動光環，AuraContainer 的 HELPFUL 候選裡看不到。其他路（戰鬥記錄、施法事件、
-- GetAuraDuration、自建 duration、自己算時間）德莫的征戰聖擊助手都查證過走不通。
--
-- 走得通的只有這條：暴雪的 BuffBarCooldownViewer item 是 untainted 程式每幀往 item.Bar 寫
-- SetMinMaxValues／SetValue（戰鬥中是秘密值），**原生 StatusBar 之間原封轉手是允許的**：
--     row.bar:SetMinMaxValues(src:GetMinMaxValues()); row.bar:SetValue(src:GetValue())
-- 中間沒有任何比較或算術。那個 item 本來就是我們認領的框（buffbars），**只讀不寫**。
-- ⇒ 前置條件：征戰聖擊要在暴雪冷卻管理器的「追蹤的量條」裡。
-- 這一列顯示時，增益長條上那條征戰聖擊自動藏起來（crusadingHideBar，預設開；R.HidesTrackedBar 給
-- Catalog.Bar 濾掉）：沒有格子的 item 會被停到畫面外＋alpha 0，不 Hide，暴雪照樣每幀更新，鏡射不受影響。
--
-- 規矩（同血量列）：餵過秘密值的 row.bar 不回讀幾何／值，也沒有東西錨在它身上。
-- 活性訊號用 item:IsVisible()（暴雪對沒亮的 item SetShown(false)，永遠明文）——
-- **不要問 item:IsActive()**，那是從光環時間算的，戰鬥中是秘密布林。
--
-- 已揮的時間（elapsed，預設）：暴雪的條是剩餘時間。反向填充讓「剩餘」那截貼在另一邊，
-- 兩層的角色互換：條的材質＝還沒到的時間（底色），列的背景＝看到的進度（主色）。
-- 沒在揮（item 沒亮）時整條畫成底色：elapsed 填滿遮罩（值 1/1）、remaining 填 0。
------------------------------------------------------------
local CS_IDS = {
    [404542] = true, [406833] = true, [408385] = true, [1226662] = true, [1307499] = true,
}

local mirrorMemo = {}          -- cooldownID → 是不是征戰聖擊（只記讀得到時的結果）
local function Hit(v) return v ~= nil and not ns.IsSecret(v) and CS_IDS[v] == true end
local function MirrorMatches(id)
    if id == nil or ns.IsSecret(id) then return false end
    local m = mirrorMemo[id]
    if m ~= nil then return m end
    local get = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if not get then return false end
    local ok, r = pcall(function()
        local info = get(id)
        if type(info) ~= "table" or ns.IsSecret(info) then return nil end
        if Hit(info.spellID) or Hit(info.overrideSpellID) or Hit(info.overrideTooltipSpellID) then return true end
        local linked = info.linkedSpellIDs
        if type(linked) == "table" and not ns.IsSecret(linked) then
            for _, v in ipairs(linked) do if Hit(v) then return true end end
        end
        return false
    end)
    if not ok or r == nil then return false end     -- 讀不到不記，下次再問
    mirrorMemo[id] = r
    return r
end

local mirrorItem, mirrorID
local mirrorScanAt = 0
-- 手上那個 item 還是征戰聖擊嗎：cooldownID 換了就是池子發給別人了。
-- ⚠ 戰鬥中身分讀不到（Viewers 記成 nil）時當作沒換 —— 框重發只在換天賦／專精，不在戰鬥中
local function MirrorStillCurrent()
    local rec = mirrorItem and ns.Viewers.frames[mirrorItem]
    if not rec then return false end
    if rec.cooldownID == mirrorID then return true end
    return rec.cooldownID == nil and InCombatLockdown()
end

-- 找來源 item：手上的還算數就用；否則最多每 0.5 秒掃一次增益長條的池子（亮著的優先）
function R.MirrorSource()
    if mirrorItem and MirrorStillCurrent() then return mirrorItem end
    mirrorItem, mirrorID = nil, nil
    local now = GetTime()
    if now - mirrorScanAt < 0.5 then return nil end
    mirrorScanAt = now
    if not (ns.Viewers and ns.Viewers.EnumerateItems) then return nil end
    local found, fid, lit
    ns.Viewers.EnumerateItems(function(item, rec)
        if lit then return end
        if MirrorMatches(rec.cooldownID) then
            if item:IsVisible() then
                found, fid, lit = item, rec.cooldownID, true
            elseif not found then
                found, fid = item, rec.cooldownID
            end
        end
    end, "buffbars")
    mirrorItem, mirrorID = found, fid
    return found
end

function R.PaintMirror(row, key, cfg, reversed)
    local cc = ResolveColor(cfg, key, "color")
    local bk = R.TimerBack(cfg, key, cc)
    local elapsed = R.CrusadingFill(cfg) == "elapsed"
    row.mirrorElapsed = elapsed
    local t = row.bar:GetStatusBarTexture()
    if elapsed then
        row.bar:SetReverseFill(not reversed)
        if t then t:SetVertexColor(bk[1], bk[2], bk[3], bk[4]) end
        row.barBG:SetVertexColor(cc.r, cc.g, cc.b, 1)
    else
        if t then t:SetVertexColor(cc.r, cc.g, cc.b, 1) end
        local bg = R.TimerBg(cfg, key, cc)
        row.barBG:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    end
    R.MirrorRow(row)
end

function R.MirrorRow(row)
    local item = R.MirrorSource()
    local src = item and item:IsVisible() and item.Bar
    if src and src.GetValue then
        -- ⚠ 先落地再餵：SetValue 的第二個參數是插值模式，直接串接多回傳值會把多出來的值當旗標
        local mn, mx = src:GetMinMaxValues()
        row.bar:SetMinMaxValues(mn, mx)
        local v = src:GetValue()
        row.bar:SetValue(v)
    else
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(row.mirrorElapsed and 1 or 0)
    end
end

-- 暴雪每幀在寫來源 ⇒ 有 mirror 列時每幀轉手一次（獨立的 driver 框：列被淡出時照樣跑）
local mirrorDriver
local mirrorRows, mirrorCount = nil, 0
local mirrorHides = false      -- 增益長條上的征戰聖擊要不要藏（有 mirror 列 ∧ crusadingHideBar）

-- Catalog.Bar 問：這個 cooldownID 要不要從條上拿掉（不是「藏著」：預覽、挑選器也不列，
-- 設定面板上看到什麼畫面上就是什麼）
function R.HidesTrackedBar(id)
    return mirrorHides and MirrorMatches(id) or false
end
R.mirrorTicks, R.valueFlushes = 0, 0   -- /mcdm perf：征戰聖擊鏡射的 OnUpdate 跑幾幀／只重畫值的 Flush 幾次
-- 來源不可見時不每幀跑（效能修整 E3 #11）：以前來源（增益長條的征戰聖擊 item）沒亮時照樣每幀寫
-- SetMinMaxValues(0,1)＋SetValue。現在 MirrorTick 一看到來源不可見：每列寫一次閒置狀態（row.mirrorIdle 守衛）、
-- 卸掉 OnUpdate、起一顆 0.25 秒的探針（C_Timer.NewTicker）；探針看到來源 IsVisible() ⇒ 停探針、掛回 OnUpdate。
-- 增益剛出現時 Viewers 的 OnActiveStateChanged → Signal → Flush → 資源條 Relayout → SetMirrorDriver 也順手探一次，
-- 不必等 0.25 秒。SetMirrorDriver 沒有 mirror 列時兩個都收。這是「不新增輪詢」的例外：探針只在來源不可見時跑、可見就停
local mirrorProbe              -- 閒置時的探針（ticker）；nil ＝ 沒在閒置（OnUpdate 掛著，或根本沒有 mirror 列）
local MirrorTick

local function StopMirrorProbe()
    if mirrorProbe then
        mirrorProbe:Cancel()
        mirrorProbe = nil
    end
end

local function SourceVisible()
    local item = R.MirrorSource()
    return item ~= nil and item:IsVisible() and true or false
end

function R.MirrorProbe()
    if not mirrorProbe then return end
    if not SourceVisible() then return end
    StopMirrorProbe()
    for i = 1, mirrorCount do
        local row = mirrorRows[i]
        if row then row.mirrorIdle = nil end
    end
    if mirrorDriver then mirrorDriver:SetScript("OnUpdate", MirrorTick) end
    MirrorTick()                                     -- 這一幀就轉手一次
end

MirrorTick = function()
    R.mirrorTicks = R.mirrorTicks + 1
    if not SourceVisible() then
        -- 閒置：每列寫一次閒置狀態（MirrorRow 的 else 分支），之後交給探針
        for i = 1, mirrorCount do
            local row = mirrorRows[i]
            if row and row.mode == "mirror" and not row.mirrorIdle then
                R.MirrorRow(row)
                row.mirrorIdle = true
            end
        end
        if mirrorDriver then mirrorDriver:SetScript("OnUpdate", nil) end
        if not mirrorProbe and C_Timer and C_Timer.NewTicker then
            mirrorProbe = C_Timer.NewTicker(0.25, R.MirrorProbe)
        end
        return
    end
    for i = 1, mirrorCount do
        local row = mirrorRows[i]
        if row and row.mode == "mirror" then
            row.mirrorIdle = nil
            R.MirrorRow(row)
        end
    end
end
function R.SetMirrorDriver(list, count, cfg)
    local any = false
    for i = 1, count do
        if list[i] and list[i].mode == "mirror" then any = true break end
    end
    mirrorRows, mirrorCount = list, count
    if any and not mirrorDriver then mirrorDriver = CreateFrame("Frame") end
    if not any then
        StopMirrorProbe()
        if mirrorDriver then mirrorDriver:SetScript("OnUpdate", nil) end
    elseif mirrorProbe then
        R.MirrorProbe()                              -- 閒置中：順手探一次（增益剛出現就不必等 0.25 秒）
    elseif mirrorDriver then
        mirrorDriver:SetScript("OnUpdate", MirrorTick)
    end
    if any and R.ScheduleTrackedCheck then R.ScheduleTrackedCheck() end
    local hides = any and not (type(cfg) == "table" and cfg.crusadingHideBar == false)
    if hides ~= mirrorHides then
        mirrorHides = hides
        -- 那條可能被拉進自訂群組，整套重取清單
        if ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("membership") end
    end
end

-- 征戰聖擊在不在暴雪「追蹤的量條」裡（＝我們目錄的 buffbars 清單：那就是玩家在暴雪面板的選擇）
-- → "yes" | "no" | "unknown"（目錄還沒建好；戰鬥中身分讀不到又沒記過）
function R.CrusadingTracked()
    local C = ns.Catalog
    if not (C and C.sig ~= nil and type(C.lists) == "table") then return "unknown" end
    for _, id in ipairs(C.lists.buffbars or {}) do
        if MirrorMatches(id) then return "yes" end
    end
    if InCombatLockdown() then return "unknown" end
    return "no"
end

-- 有征戰聖擊列、卻沒有來源 ⇒ 聊天框提示一次（玩家不一定會打開設定頁，條就默默空著）。
-- 進場／換專精那幾秒暴雪的清單不完整（README「進場、換專精」），所以等 5 秒、脫戰再看；
-- 同一段「沒有」只講一次，放進去之後又拿掉才會再講
local warnPending, warnedMissing = false, false
local function CheckTracked()
    warnPending = false
    if not (mirrorCount > 0 and mirrorRows) then return end
    local any = false
    for i = 1, mirrorCount do
        if mirrorRows[i] and mirrorRows[i].mode == "mirror" then any = true break end
    end
    if not any then return end
    if InCombatLockdown() then
        ns.Events.Register("PLAYER_REGEN_ENABLED", "resources_cstrack", function()
            ns.Events.Unregister("PLAYER_REGEN_ENABLED", "resources_cstrack")
            CheckTracked()
        end)
        return
    end
    local st = R.CrusadingTracked()
    if st == "yes" then
        warnedMissing = false
    elseif st == "no" and not warnedMissing then
        warnedMissing = true
        ns.Print(L["Crusading Strikes isn't in the Tracked Bars row of Blizzard's Cooldown Manager, so the Crusading Strikes row on the resource bar stays empty. Add it there (Edit Mode → Cooldown Manager → Tracked Bars)."])
    end
end
function R.ScheduleTrackedCheck()
    if warnPending then return end
    warnPending = true
    C_Timer.After(5, CheckTracked)
end

function R.MirrorStatus()
    local item = mirrorItem
    return item ~= nil, item ~= nil and item:IsVisible() or false
end

------------------------------------------------------------
-- 血量（Health）
--
-- UnitHealth／UnitHealthMax 在 12.1 連脫戰都是秘密值（.claude/notes/wow-121-unit-api-secrets.md）：
-- Lua 這邊只轉手（SetMinMaxValues／SetValue／AbbreviateNumbers），不比較、不算。
-- 條件規則不適用（沒有明文可比），顏色改走兩層：
--   底色     healthClassColor（預設）＝ 玩家職業色，關掉用 colors.Health.color。兩者都是明文
--   門檻換色 healthThresholdEnabled ＋ healthThresholds（{ pct = 1..99, color }，最多 6 個）：
--            由低到高排 → Step 色彩曲線（x 是 0～1 的血量比例，**不是 0～100**）→
--            UnitHealthPercent("player", nil, 曲線) 由 C 端挑色 → 填充貼圖 SetVertexColor。
--            曲線組法照套組單位框架的血量門檻（同一套語意：低的門檻優先）。
-- 曲線物件只建一次；點在**排版時**比簽章、變了才重建（UNIT_HEALTH 上不 ClearPoints／AddPoint、不組字串）。
-- 曲線挑出來的顏色可能是秘密值 ⇒ 只交給 SetVertexColor；暗底一律用明文的底色算。
------------------------------------------------------------
local HEALTH_MAX_THRESHOLDS = 6
R.HEALTH_MAX_THRESHOLDS = HEALTH_MAX_THRESHOLDS

-- 純函式：門檻 → 曲線的點 { { x, r, g, b }, … }（x 由小到大）。設定表不動（排序在副本上）；
-- 壞資料跳過、百分比夾在 1～99、超過上限的不要。沒有有效門檻回 nil
--   (0,      最低門檻的顏色)
--   (t1,     第二低門檻的顏色)
--   …
--   (t最高,  底色)
-- Step 取「最後一個 x ≤ 目前比例」的點，所以「低於 t1」吃最低門檻的色、t 最高以上維持底色
function R.HealthCurvePoints(list, base)
    if type(list) ~= "table" or not RC.ValidColor(base) then return nil end
    local valid = {}
    for _, t in ipairs(list) do
        local pct = type(t) == "table" and tonumber(t.pct)
        local c = type(t) == "table" and RC.ValidColor(t.color)
        if pct and c and #valid < HEALTH_MAX_THRESHOLDS then
            pct = math.floor(pct + 0.5)
            if pct < 1 then pct = 1 elseif pct > 99 then pct = 99 end
            valid[#valid + 1] = { pct = pct, color = c, i = #valid + 1 }
        end
    end
    if #valid == 0 then return nil end
    -- 同百分比照原本的順序（table.sort 不穩定，自己補次序鍵）
    table.sort(valid, function(a, b)
        if a.pct ~= b.pct then return a.pct < b.pct end
        return a.i < b.i
    end)
    local first = valid[1].color
    local pts = { { 0, first.r, first.g, first.b } }
    for i = 1, #valid do
        local nc = valid[i + 1] and valid[i + 1].color or base
        pts[#pts + 1] = { valid[i].pct / 100, nc.r, nc.g, nc.b }
    end
    return pts
end

-- 純函式：曲線點的簽章（排版時比，變了才重建曲線）
function R.HealthCurveSig(pts)
    if not pts then return "" end
    local parts = {}
    for i, p in ipairs(pts) do
        parts[i] = ("%.3f:%.3f,%.3f,%.3f"):format(p[1], p[2], p[3], p[4])
    end
    return table.concat(parts, "|")
end

-- 底色：職業色（預設）或玩家調的顏色。職業色填進檔案層級的表（熱路徑上不配表）
local healthClassColor = { r = 1, g = 1, b = 1 }
local function HealthBase(cfg)
    if type(cfg) == "table" and cfg.healthClassColor ~= false then
        local r, g, b = ns.Style.Accent()
        healthClassColor.r, healthClassColor.g, healthClassColor.b = r, g, b
        return healthClassColor
    end
    return ResolveColor(cfg, "Health", "color")
end
R.HealthBase = HealthBase

local healthCurve, healthCurveSig
local healthCurveOn = false       -- 這一輪排版的結果：門檻換色有沒有在用

-- 排版時叫（不在 UNIT_HEALTH 上）：門檻有變才重建曲線的點
local function PrepareHealthCurve(cfg)
    healthCurveOn = false
    if not cfg.healthThresholdEnabled then return end
    local pts = R.HealthCurvePoints(cfg.healthThresholds, HealthBase(cfg))
    local make = C_CurveUtil and C_CurveUtil.CreateColorCurve
    if not (pts and make and CreateColor and UnitHealthPercent) then return end
    if not healthCurve then
        local ok, c = pcall(make)
        if not ok or not c then return end
        local T = Enum and Enum.LuaCurveType
        if T and T.Step then c:SetType(T.Step) end
        healthCurve = c
    end
    local sig = R.HealthCurveSig(pts)
    if sig ~= healthCurveSig then
        healthCurveSig = nil
        local ok = pcall(function()
            healthCurve:ClearPoints()
            for _, p in ipairs(pts) do healthCurve:AddPoint(p[1], CreateColor(p[2], p[3], p[4], 1)) end
        end)
        if not ok then return end
        healthCurveSig = sig
    end
    healthCurveOn = true
end

-- 血量的數字：縮寫沿用法力的設定；healthPercent 印百分比（秘密值時問 UnitHealthPercent，curve 是第 3 個參數）
local function SetHealthText(fs, cur, max, cfg)
    if not cfg.healthPercent then
        SetBigNumber(fs, cur, cfg)
        return
    end
    if not ns.IsSecret(cur) and not ns.IsSecret(max) then
        if type(max) == "number" and max > 0 then
            fs:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5))
        else
            fs:SetText("")
        end
        return
    end
    local scale = CurveConstants and CurveConstants.ScaleTo100
    if UnitHealthPercent and scale then
        fs:SetFormattedText("%d%%", UnitHealthPercent("player", nil, scale))
    else
        fs:SetText("")
    end
end

local function UpdateHealthRow(row, cfg, key)
    local cur, max = GetValue(key)
    local pm = Plain(max)
    if pm ~= nil and pm <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    -- 上限與目前值直接交給引擎（秘密值）
    row.bar:SetMinMaxValues(0, max)
    if type(cur) == "number" then
        row.bar:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        row.bar:SetValue(0)
    end
    local base = HealthBase(cfg)
    local a = tonumber(cfg.barAlpha) or 1
    local t = row.bar:GetStatusBarTexture()
    if t then
        local col
        if healthCurveOn and healthCurve then
            local ok, c = pcall(UnitHealthPercent, "player", nil, healthCurve)
            if ok then col = c end
        end
        if col then
            t:SetVertexColor(col.r, col.g, col.b, a)        -- 可能是秘密值：只交給引擎
        else
            t:SetVertexColor(base.r, base.g, base.b, a)
        end
    end
    PaintBarBG(row, cfg, nil, base)
    ClearRowOverrides(row)
    if cfg.showText then
        if type(cur) ~= "number" then row.text:SetText("") else SetHealthText(row.text, cur, max, cfg) end
    end
end

local function UpdateRow(row, cfg)
    local key = row.key
    local def = key and RESOURCES[key]
    if not def then return end
    -- 外觀：這一列自己的（R.StyleFor；往下傳的函式只讀不寫、不拿 cfg 當 key）
    cfg = R.StyleFor(cfg, key)
    if row.mode == "engine" then
        -- 引擎寫層數：Lua 這邊沒有東西要畫
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    if row.mode == "mirror" then
        R.MirrorRow(row)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    if row.mode == "timerIdle" then
        -- 剩餘時間條的容器還沒好（戰鬥中、建失敗）：空條，底色同連續條
        local d = R.TimerBg(cfg, key, ResolveColor(cfg, key, "color"), timerDimScratch)
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.barBG:SetVertexColor(d[1], d[2], d[3], d[4])
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    -- 顏色與條件一列解析一次，往下傳（掛在能量事件上）
    local cc = ResolveColor(cfg, key, "color")
    local conds = R.SupportsConditions(key) and RC.Resolve(cfg, key) or nil
    if def.health then
        UpdateHealthRow(row, cfg, key)
    elseif row.mode == "absorbBar" then
        UpdateAbsorbRow(row, cfg, def, key, cc, conds)
    elseif row.mode == "pip" then
        local n = row.numSeg or 0
        if n <= 0 then
            row.text:SetText("")
            ClearRowOverrides(row)
            return
        end
        UpdatePipRow(row, cfg, def, key, n, cc, conds)
    else
        UpdateBarRow(row, cfg, def, key, cc, conds)
    end
    -- 虛空化身計時／崩陷之星計數：對齊化身狀態、值變了才換字
    if def.meta and row.metaTime and ns.DevourerMeta then ns.DevourerMeta.Update(row) end
end

------------------------------------------------------------
-- 重排與重畫
------------------------------------------------------------
local shownCount = 0
local SyncUnitEvents             -- 定義在事件那一段（前置宣告；Relayout 結尾與整條關掉時叫）
local healthShown = false        -- 畫面上有沒有血量列（沒有的職業不必為 UNIT_HEALTH 重畫）
local laidOut = false            -- 排過版了沒（false ＝ 下一次 Update 一定重排）
local pendingRelayout = false    -- 戰鬥中面板是保護框（有 auraBar 的容器）、該重排的時候記在這裡

-- auraBar 的 AuraContainer 讓列與面板變成保護框：戰鬥中不能 SetSize／SetPoint／Show／Hide ⇒ 記旗標、脫戰補
local function MustDefer()
    return InCombatLockdown() and root ~= nil and ns.IsProtectedFrame and ns.IsProtectedFrame(root)
end

local function OnRegenRelayout()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "resources_relayout")
    if pendingRelayout then
        pendingRelayout = false
        R.Mark(true)
    end
end

local function DeferRelayout()
    pendingRelayout = true
    ns.Events.Register("PLAYER_REGEN_ENABLED", "resources_relayout", OnRegenRelayout)
end

local function Relayout(cfg, list, W)
    local total = 0
    local gap = ns.P.Scale(tonumber(cfg.rowSpacing) or 1)
    W = ns.P.Scale(W)
    local prev
    healthShown = false
    local metaShown = false
    local DM = ns.DevourerMeta
    for i, key in ipairs(list) do
        local row = rows[i]
        if not row then
            row = MakeRow(root)
            rows[i] = row
        end
        row.key = key
        row.numSeg = SegmentsFor(key)
        if RESOURCES[key] and RESOURCES[key].health then
            healthShown = true
            PrepareHealthCurve(cfg)
        end
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        end
        prev = row
        row:Show()
        local H = ns.P.Scale(R.KeyRowHeight(cfg, key))
        total = total + H
        -- 外觀：這一列自己的（不跟資源條時是代理表，見 R.StyleFor）；高度、列距、錨定照全域
        LayoutRow(row, key, R.StyleFor(cfg, key), row.numSeg, W, H)
        if row.ab and ns.AuraBar then ns.AuraBar.KickPending(row.ab) end
        -- 噬靈魂碎片列上的虛空化身計時／崩陷之星計數（池化的列換成別的資源就收起來）
        if DM and RESOURCES[key] and RESOURCES[key].meta then
            DM.Layout(row, R.StyleFor(cfg, key), cfg)
            metaShown = true
        elseif DM and row.metaTime then
            DM.Hide(row)
        end
    end
    -- 沒有靈魂碎片列了（換專精、列被關）：狀態整個重設
    if DM and not metaShown then DM.Reset() end
    for i = #list + 1, #rows do
        local row = rows[i]
        row:Hide()
        row.key, row.mode = nil, nil
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
    end
    shownCount = #list
    R.SetMirrorDriver(rows, shownCount, cfg)
    SyncUnitEvents()
    local n = #list
    ns.Bars.SetPanelSize("resources", W, n > 0 and (total + (n - 1) * gap) or 1)
end

-- force：重排（清單、格數、尺寸設定、寬度都可能變了）。不給 ＝ 只重畫值（能量事件走這條，
-- 熱路徑上不重算清單、不配任何表或字串）
function R.Update(force)
    if not root then return end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then
        if MustDefer() then DeferRelayout() return end
        for i = 1, #rows do
            rows[i]:Hide()
            if rows[i].ab and ns.AuraBar then ns.AuraBar.HideContainer(rows[i].ab) end
        end
        shownCount = 0
        healthShown = false
        laidOut = false
        if ns.DevourerMeta then ns.DevourerMeta.Reset() end
        R.SetMirrorDriver(rows, 0, cfg)
        SyncUnitEvents()
        return
    end
    if force or not laidOut then
        if MustDefer() then
            DeferRelayout()
        else
            Relayout(cfg, ActiveRows(cfg), R.Width(cfg))
            laidOut = true
        end
    end
    for i = 1, shownCount do
        local ok, err = xpcall(UpdateRow, ns.ReportError, rows[i], cfg)
        if not ok then R.lastError = err end
    end
end

-- 符文回充的進度與秒數、精華的回充進度都沒有事件可等（RUNE_POWER_UPDATE 只在轉好／用掉時來，
-- 精華的回充中間沒有能量事件）：有格子在回充時開一個 0.1 秒的 ticker 只重畫這兩種列，
-- 全部回充好（或列不見了）就停
local TICKED_FILL = { rune = true, essence = true }
local rechargeTicker
local rechargeRearmed = false    -- 這一趟有沒有人說「還有格子在回充」

-- 虛空化身計時（噬滅）也搭這班：化身中、或還有「結束後保留」沒清時，每趟只重畫那兩段字（DM.Paint，
-- 整數秒變了才換字），不重畫整列。停止條件 ＝ 回充與化身計時都沒人要
local function RechargeTick()
    rechargeRearmed = false
    local cfg = Cfg()
    local busy = false
    if cfg and cfg.enabled ~= false then
        local DM = ns.DevourerMeta
        for i = 1, shownCount do
            local row = rows[i]
            local def = row.key and RESOURCES[row.key]
            if def and TICKED_FILL[def.fill] and row.mode == "pip" and row:IsShown() then
                busy = true
                local ok, err = xpcall(UpdateRow, ns.ReportError, row, cfg)
                if not ok then R.lastError = err end
            elseif def and def.meta and DM and row.metaTime and DM.NeedsTick(DM.state) then
                busy = true
                rechargeRearmed = true          -- 化身計時自己續班（DM.Paint 清掉過期的保留後下一趟就不續了）
                local ok, err = xpcall(DM.Paint, ns.ReportError, row)
                if not ok then R.lastError = err end
            end
        end
    end
    -- UpdatePipRow 在還有格子回充時會再呼叫 ArmTicker；這一趟沒人呼叫 ⇒ 全部好了
    if not busy or not rechargeRearmed then
        if rechargeTicker then rechargeTicker:Cancel() end
        rechargeTicker = nil
    end
end

function R.ArmTicker()
    rechargeRearmed = true
    if rechargeTicker or not (C_Timer and C_Timer.NewTicker) then return end
    rechargeTicker = C_Timer.NewTicker(0.1, RechargeTick)
end

-- 專精／型態／天賦／上限變動：清單與格數都可能變
function R.Reevaluate()
    R.Invalidate()
    chargedDirty = true
    R.Update(true)
end

------------------------------------------------------------
-- 事件：只標髒，下一幀做
------------------------------------------------------------
local dirtyReeval, dirtyValues, armed = false, false, false

local function Flush()
    armed = false
    local re, va = dirtyReeval, dirtyValues
    dirtyReeval, dirtyValues = false, false
    if re then
        R.Reevaluate()
    elseif va then
        R.valueFlushes = R.valueFlushes + 1
        R.Update(false)
    end
end

-- what：true ＝ 重算清單與重排；其他 ＝ 只重畫值
local function Mark(what)
    if what then
        dirtyReeval = true
    else
        dirtyValues = true
    end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
R.Mark = Mark

-- MAGE：冰刺；MONK：醉仙緩勁（減益每跳都會發 UNIT_AURA）
local AURA_DRIVEN_CLASSES = { SHAMAN = true, HUNTER = true, DEMONHUNTER = true, DRUID = true, MAGE = true, MONK = true }
-- 只重畫值的生命／吸收事件（醉仙緩勁的上限是最大生命、每跳扣血；無視苦痛看吸收量與最大生命）。
-- UNIT_HEALTH／UNIT_MAXHEALTH 每個職業都註冊（血量列）；這張表列的是「沒有血量列也要重畫」的
local HEALTH_EVENTS = {
    MONK    = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true },
    WARRIOR = { UNIT_ABSORB_AMOUNT_CHANGED = true, UNIT_MAXHEALTH = true },
}
local CLASS_HEALTH = HEALTH_EVENTS[CLASS] or {}

local REEVAL_EVENTS = {
    UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_ENTERING_WORLD = true, UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true,
    SPELLS_CHANGED = true,
}

local evFrame

------------------------------------------------------------
-- 光環／生命事件依列動態註冊（效能修整 E3 #16a）
--
--   R.WantedEvents(keys, class [, out])   純函式：畫面上的列（資源 key 陣列）＋職業 → 要註冊的事件集合
--     UNIT_AURA                     職業在 AURA_DRIVEN_CLASSES（以前就只有這六個職業註冊）而且有列要吃它：
--                                   層數型（def.aura／def.auras）、施放次數型（def.cast：靈魂碎片）、醉仙緩勁
--                                   （def.stagger：減益每跳都發）、讀光環層數的取值（def.auraRead：噬靈魂碎片）、
--                                   野德的連擊點（滿溢之力畫在連擊點上，ChargedPoints）
--     UNIT_HEALTH                   血量列（def.health）、醉仙緩勁
--     UNIT_MAXHEALTH                血量列、醉仙緩勁、無視苦痛（def.absorb：上限是最大生命）
--     UNIT_ABSORB_AMOUNT_CHANGED    無視苦痛（以前只有戰士註冊，這一列只有戰士有）
--     UNIT_SPELLCAST_SUCCEEDED      噬靈魂碎片列（def.meta：崩陷之星計數，只有專精 1480 有這一列）
--   能量、符文、點數充能、急速照舊一次註冊。作廢點＝Relayout 結尾（Reevaluate、R.Apply、Bars 的 relayout 都經過它）
--   與整條關掉的那一支；戰鬥中重排延後時畫面上的列沒變，事件集合跟著不變
------------------------------------------------------------
local UNIT_EVENTS = { "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }

function R.WantedEvents(keys, class, out)
    out = out or {}
    for k in pairs(out) do out[k] = nil end
    local auraClass = AURA_DRIVEN_CLASSES[class] == true
    for _, key in ipairs(keys or {}) do
        local def = RESOURCES[key]
        if def then
            if auraClass and (def.aura or def.auras or def.cast or def.stagger or def.auraRead
                or (key == "ComboPoints" and class == "DRUID")) then
                out.UNIT_AURA = true
            end
            if def.health or def.stagger then
                out.UNIT_HEALTH, out.UNIT_MAXHEALTH = true, true
            end
            if def.absorb then
                out.UNIT_MAXHEALTH, out.UNIT_ABSORB_AMOUNT_CHANGED = true, true
            end
            if def.meta then out.UNIT_SPELLCAST_SUCCEEDED = true end
        end
    end
    return out
end

local unitEvOn = {}                  -- 事件 → true（現在註冊著）
local shownKeys, wantScratch = {}, {}
R.unitEvOn = unitEvOn                 -- /mcdm debug、測試用

SyncUnitEvents = function()
    if not evFrame then return end
    for i = #shownKeys, 1, -1 do shownKeys[i] = nil end
    for i = 1, shownCount do
        local row = rows[i]
        if row and row.key then shownKeys[#shownKeys + 1] = row.key end
    end
    local want = R.WantedEvents(shownKeys, CLASS, wantScratch)
    for _, ev in ipairs(UNIT_EVENTS) do
        if want[ev] and not unitEvOn[ev] then
            unitEvOn[ev] = true
            evFrame:RegisterUnitEvent(ev, "player")
        elseif not want[ev] and unitEvOn[ev] then
            unitEvOn[ev] = nil
            evFrame:UnregisterEvent(ev)
        end
    end
end

local function OnEvent(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 崩陷之星計數：計數變了才重畫（施法很頻繁，別的法術不標髒）
        if ns.DevourerMeta and ns.DevourerMeta.OnSpellcast(...) then Mark(false) end
        return
    end
    if event == "UNIT_POWER_POINT_CHARGE" then chargedDirty = true end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -- 沒有血量列、這個職業的資源也不看生命 ⇒ 不重畫（每次受傷都來，別白做）
        if healthShown or CLASS_HEALTH[event] then Mark(false) end
        return
    end
    if event == "UNIT_SPELL_HASTE" then
        -- 秘法靈魂印「剩幾個 GCD」時：GCD 長度（0.05 秒一格）變了才重排（戰鬥中照樣記旗標、脫戰補）
        for i = 1, shownCount do
            local used = rows[i].gcdUsed
            if used then
                if R.ReadGcd() ~= used then Mark(true) end
                return
            end
        end
        return
    end
    if event == "UNIT_AURA" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        Mark(false)
        return
    end
    Mark(REEVAL_EVENTS[event] == true)
end

local function RegisterEvents()
    if evFrame then return end
    evFrame = CreateFrame("Frame")
    -- 綁 "player" 走 RegisterUnitEvent：團隊裡其他人的能量事件在 C 端就被擋掉
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_SPECIALIZATION_CHANGED" }) do
        evFrame:RegisterUnitEvent(e, "player")
    end
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
                         "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
        evFrame:RegisterEvent(e)
    end
    if CLASS == "DEATHKNIGHT" then evFrame:RegisterEvent("RUNE_POWER_UPDATE") end
    if CLASS == "ROGUE" then evFrame:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player") end
    -- 秘法靈魂的「剩幾個 GCD」：格式器的分段跟著 GCD 長度
    if CLASS == "MAGE" then evFrame:RegisterUnitEvent("UNIT_SPELL_HASTE", "player") end
    -- UNIT_AURA／UNIT_HEALTH／UNIT_MAXHEALTH／UNIT_ABSORB_AMOUNT_CHANGED／UNIT_SPELLCAST_SUCCEEDED：
    -- 依畫面上的列動態註冊（SyncUnitEvents）
    evFrame:SetScript("OnEvent", OnEvent)
    SyncUnitEvents()
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Bars 之後）
------------------------------------------------------------
local function MinSize()
    local cfg = Cfg() or {}
    return R.Width(cfg), RowHeight(cfg)
end

function R.Init()
    if container then return end
    container = ns.Bars.RegisterPanel("resources", {
        anchorPoint = "BOTTOM",               -- 貼在核心技能上方、列數增減時下緣不動
        minSize     = MinSize,
        relayout    = function() R.Update(true) end,
    })
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    RegisterEvents()
    ns.RegisterCallback("FirstRowWidthChanged", "resources", function()
        local cfg = Cfg()
        if cfg and (tonumber(cfg.width) or 0) <= 0 then Mark(true) end
    end)
    ns.RegisterCallback("ProfileChanged", "resources", function() Mark(true) end)
    ns.RegisterCallback("SpecChanged", "resources", function() Mark(true) end)
    -- 玩家在暴雪面板把征戰聖擊放進／拿出追蹤的量條
    ns.RegisterCallback("CatalogChanged", "resources_cstrack", function() R.ScheduleTrackedCheck() end)
    -- 職業色晚到（自訂職業色表）：血量列的底色與門檻曲線的最後一個點要重組
    ns.RegisterCallback("AccentChanged", "resources", function() Mark(true) end)
    -- 虛空化身那兩段字的預覽（設定視窗開著／暴雪編輯模式中）：進出時重畫值
    ns.RegisterCallback("OptionsShown", "resources_meta", function() Mark(false) end)
    ns.RegisterCallback("OptionsHidden", "resources_meta", function() Mark(false) end)
    ns.RegisterCallback("EditModeChanged", "resources_meta", function() Mark(false) end)
    R.Reevaluate()
end

-- 設定頁改了值：重排＋結構（錨點、strata、開關）＋ alpha
function R.Apply()
    R.InvalidateStyles()
    if not container then return end
    R.Invalidate()
    R.Update(true)
    -- 結構（錨點、strata、開關）：戰鬥外當場套；戰鬥中交給排程記帳到脫戰
    if InCombatLockdown() then ns.Bars.Request("resources", "structure") else ns.Bars.ApplyStructure("resources") end
    if ns.Visibility then ns.Visibility.Apply("resources") end
end

------------------------------------------------------------
-- 公開 API 與除錯
------------------------------------------------------------
-- powerType（Enum.PowerType）或資源 key（字串，沒有 PowerType 的資源：Stagger、IgnorePain…）→ 那一列的框；
-- 沒有這一列、藏著、整條關著都回 nil
function R.GetRowFrame(powerType)
    if powerType == nil or not container then return nil end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false or not container:IsShown() then return nil end
    local byKey = type(powerType) == "string"
    for i = 1, shownCount do
        local row = rows[i]
        local def = row and row.key and RESOURCES[row.key]
        if def and row:IsShown() then
            if byKey then
                if row.key == powerType then return row end
            elseif def.power == powerType then
                return row
            end
        end
    end
    return nil
end

function R.DebugLines()
    local out = {}
    local cfg = Cfg()
    if not container then
        out[1] = "  資源條：沒有初始化"
        return out
    end
    local cand, specID = R.Candidates()
    out[#out + 1] = ("  資源條：%s  專精 %s  候選 %d  顯示 %d 列  寬 %s  alpha %s%s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", tostring(specID), #cand, shownCount,
                tostring(R.Width(cfg)), tostring(ns.Visibility and ns.Visibility.Current("resources")),
                pendingRelayout and "  （戰鬥中，重排延到脫戰）" or "")
    for i = 1, shownCount do
        local row = rows[i]
        local key = row.key
        local def = RESOURCES[key]
        local cur, max = GetValue(key)
        local secret = ns.IsSecret(cur) or ns.IsSecret(max)
        local n = RC.Resolve(cfg, key)
        local extra = ""
        if R.EngineDriven(key) and row.ab and ns.AuraBar then
            local bound = ns.AuraBar.Bound(row.ab)
            extra = ("  容器 %s／交條 %s"):format(tostring(row.engineStatus),
                bound == true and "是" or bound == false and "失敗" or "未知")
        end
        out[#out + 1] = ("    %d. %-15s %s%s  畫法 %s  秘密 %s  條件 %d  %s%s")
            :format(i, key, def.mode, (def.mode == "pip" or def.mode == "auraBar") and ("×" .. tostring(row.numSeg)) or "",
                    tostring(row.mode), secret and "是" or "否", n and #n or 0, tostring(gateLog[key] or ""), extra)
        -- 引擎寫的列：容器、按鈕、身上光環的細節（「整列空白」分得出卡在哪一段）＋列本身的尺寸／可見
        if R.EngineDriven(key) and row.ab and ns.AuraBar and ns.AuraBar.DebugLines then
            local okS, rw, rh = pcall(row.GetSize, row)
            local okV, vis = pcall(row.IsVisible, row)
            out[#out + 1] = ("       列：尺寸 %sx%s  可見 %s  格數 %s"):format(
                okS and tostring(Plain(rw)) or "?", okS and tostring(Plain(rh)) or "?",
                okV and tostring(Plain(vis)) or "?", tostring(row.numSeg))
            for _, line in ipairs(ns.AuraBar.DebugLines(row.ab, def.auras)) do out[#out + 1] = line end
        end
    end
    if CLASS == "DEMONHUNTER" and ns.DevourerMeta then out[#out + 1] = "  " .. ns.DevourerMeta.DebugLine() end
    for key, why in pairs(gateLog) do
        local listed = false
        for i = 1, shownCount do if rows[i].key == key then listed = true end end
        if not listed then out[#out + 1] = ("    （%s）%s"):format(key, why) end
    end
    return out
end
