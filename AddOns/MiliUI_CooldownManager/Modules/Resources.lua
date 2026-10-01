------------------------------------------------------------
-- 資源條：專精 → 該專精要看的資源清單，一種資源一列（獨立 HUD，容器 MiliUICDM_Bar_resources）
--
-- 引擎從套組自己的單位框架（MiliUI_UnitFrames 的資源條與能量條）改來，差別：
--   * **有法力**：單位框自己有能量條，所以那邊刻意不做法力；這裡是獨立 HUD，
--     有法力的專精在最下面多一列法力條（做法照能量條：上限／目前值直接餵 StatusBar）。
--   * **主資源也列**：那邊把「單位框能量條已經在畫的主資源」剔掉，這裡不剔。
--
-- 每一列自己決定長相：
--   pip        分段（點數型：聖能／連擊點數／真氣／碎片／充能／精華／符文，以及光環堆疊型：冰刺…）
--   bar        連續長條（怒氣／能量／集中值／符文能量／星能／元能／狂亂值／魔怒／法力；
--              def.get 型：醉仙緩勁 UnitStagger／UnitHealthMax、噬靈魂碎片）
--   absorbBar  吸收盾（無視苦痛）：值 UnitGetTotalAbsorbs("player")、上限「最大生命的三成」。
--              ⚠ 不對秘密的最大生命乘 0.3：用幾何做 —— 裁切框寬 W（SetClipsChildren），裡面的 StatusBar
--              寬 W / 0.3、貼在填充起點那一側，SetMinMaxValues(0, UnitHealthMax)，於是只看得到前三成。
--              這條 StatusBar 的填充貼圖上不錨任何東西、不讀它的尺寸。
--   auraBar    **引擎寫層數**（Modules/AuraBar.lua）：GetPlayerAuraBySpellID 讀不到的增益（旋風斬、橫掃攻擊）
--              用一顆單格 AuraContainer ＋ SetApplicationBar；每施放一次多一顆獨立光環的（鐵鬃）用
--              AddAuraGroup ＋ 每顆 SetDurationBar（一格一層、各自倒數）。條件規則與數值文字不適用。
--              容器是受保護的 intrinsic ⇒ 有這種列時面板在戰鬥中不重排（記旗標、脫戰補）。
--   auraTimer  **光環剩餘時間條**（黯黑力量、秘法靈魂）：同一支 AuraBar 的 kind = "duration"，單格 AuraContainer
--              ＋ SetDurationBar（RemainingTime）：光環在身上時引擎往下縮、不在時是空條（列上畫的暗底）。
--              上限秒數不經 Lua（引擎用光環自己的持續時間，含延長）；showText 時秒數走 SetDurationText。
--              條件規則不適用；容器沒好（戰鬥中、建失敗）時先畫空條（timerIdle）。
--
-- 12.1 秘密值（見 .claude/notes/wow-121-secret-values.md）：
--   * 連續條：UnitPowerMax／UnitPower **直接**餵 SetMinMaxValues／SetValue（引擎收秘密值），
--     明文且上限 <= 0 才顯示空條。
--   * 點數型：「第 i 格亮不亮」**不在 Lua 比**。每一格是一顆 StatusBar，
--     SetMinMaxValues(i-1, i)＋SetValue(目前值) —— 秘密值照樣畫得對。
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
-- fill   pip 專用的特殊填充：rune（符文冷卻）
-- auras  光環 spellID 清單（auraBar／auraTimer：交給 AuraContainer 的 includeSpellIDs，Lua 不讀）
-- passive 天賦閘：這個法術學了才列；heroTree：或是目前的英雄天賦樹是這一棵（C_ClassTalents）
-- mana   法力列（數值文字走縮寫、預設排最下面）
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
    SoulShards      = { name = PowerName("SOUL_SHARDS", "Soul Shards"), mode = "pip", power = PT.SoulShards },
    ArcaneCharges   = { name = PowerName("ARCANE_CHARGES", "Arcane Charges"), mode = "pip", power = PT.ArcaneCharges },
    Essence         = { name = PowerName("ESSENCE", "Essence"),       mode = "pip", power = PT.Essence },
    Runes           = { name = PowerName("RUNES", "Runes"),           mode = "pip", power = PT.Runes, fill = "rune" },
    -- 光環／技能次數型（資料來源都是暴雪開放的查詢）
    MaelstromWeapon = { name = L["Maelstrom Weapon"], mode = "pip", aura = 344179, max = 10, passive = 187880 },
    TipOfTheSpear   = { name = L["Tip of the Spear"], mode = "pip", aura = 260286, max = 3,  passive = 260285 },
    SoulFragments   = { name = L["Soul Fragments"],   mode = "pip", cast = 228477, max = 6,  passive = 203981 },
    -- 2026-09-30 補齊
    Icicles         = { name = SpellName(205473, "Icicles"), nameSpell = 205473, mode = "pip", aura = 205473, max = 5 },
    DevourerFragments = { name = L["Soul Fragments"], mode = "bar", get = DevourerValue, bigNumber = false },
    Stagger         = { name = PowerName("STAGGER", SpellName(115069, "Stagger")), mode = "bar", get = StaggerValue,
                        passive = 115069, stagger = true, bigNumber = true },
    IgnorePain      = { name = SpellName(190456, "Ignore Pain"), nameSpell = 190456, mode = "absorbBar", get = AbsorbValue,
                        passive = 190456, cap = 0.3, bigNumber = true },
    WhirlwindStacks = { name = SpellName(85739, "Whirlwind"), nameSpell = 85739, mode = "auraBar",
                        auras = { 85739, 190411 }, max = 4, passive = 12950 },
    SweepingStrikes = { name = SpellName(260708, "Sweeping Strikes"), nameSpell = 260708, mode = "auraBar",
                        auras = { 260708 }, maxFn = SweepingMax, max = 12, passive = 260708 },
    Ironfur         = { name = SpellName(192081, "Ironfur"), nameSpell = 192081, mode = "auraBar", instances = true,
                        auras = { 192081 }, max = 5, passive = 192081 },
    -- 光環剩餘時間條（auraTimer）。名字用光環的法術名
    --   黯黑力量：增輝的招牌技能 395152、身上的增益是 395296（基礎 10 秒，會被延長）
    --   秘法靈魂：Sunfury 英雄天賦「歐爾的記憶」449619 給的 451038（4 秒）；1223522 是 11.1 起同名同圖示的
    --   另一個 ID，一起放進過濾（沒出現就永遠比對不到，無害）。英雄樹 39 ＝ Sunfury
    EbonMight       = { name = SpellName(395296, "Ebon Might"), nameSpell = 395296, mode = "auraTimer",
                        auras = { 395296 }, passive = 395152 },
    ArcaneSoul      = { name = SpellName(451038, "Arcane Soul"), nameSpell = 451038, mode = "auraTimer",
                        auras = { 451038, 1223522 }, passive = 449619, heroTree = 39 },
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

-- 醉仙緩勁中度／重度的標籤：暴雪自己的減益名（124274 中度、124273 重度）
local STAGGER_LABEL = { moderate = { 124274, "Moderate Stagger" }, heavy = { 124273, "Heavy Stagger" } }
function R.StaggerLabel(band)
    local t = STAGGER_LABEL[band]
    if not t then return tostring(band) end
    return SpellName(t[1], t[2])
end

-- 引擎寫值的列（auraBar 層數、auraTimer 剩餘時間）：Lua 這邊沒有值
local ENGINE_MODES = { auraBar = true, auraTimer = true }
function R.EngineDriven(key)
    local def = RESOURCES[key]
    return def ~= nil and ENGINE_MODES[def.mode] == true
end

-- 條件規則只對 Lua 讀得到值的列有意義；引擎寫的沒有
function R.SupportsConditions(key)
    local def = RESOURCES[key]
    return def ~= nil and not ENGINE_MODES[def.mode]
end

-- 純函式：一列實際的畫法。容器就緒 ⇒ engine；沒好時 auraBar 退回明文點數、auraTimer 退回空條
function R.DrawMode(mode, engineReady)
    if mode == "auraBar" then return engineReady and "engine" or "pip" end
    if mode == "auraTimer" then return engineReady and "engine" or "timerIdle" end
    return mode
end

-- 專精 → 資源清單（法力另外看 MANA_SPECS，一律排最下面）
local SPEC_RESOURCES = {
    [71]  = { "Rage", "SweepingStrikes" },       [72]  = { "Rage", "WhirlwindStacks" },
    [73]  = { "Rage", "IgnorePain" },
    [65]  = { "HolyPower" },                     [66]  = { "HolyPower" },  [70] = { "HolyPower" },
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
-- 增強薩的法力只在戰鬥外回血／補圖騰時有意義，平常不需要一條在那裡佔位（使用者 2026-10-01 指定）
local DEFAULT_OFF = {
    [263] = { Mana = true },
}
-- 純函式：這個專精的這一列預設是不是顯示
function R.DefaultOn(specID, key)
    local t = specID and DEFAULT_OFF[specID]
    return not (t and t[key])
end
-- 玩家的開關（rows[key]：nil ＝ 照預設、false ＝ 關、true ＝ 開）套上預設後的結果
function R.RowOn(cfg, specID, key)
    -- ⚠ 值可能是 false，不能用 `a and b or nil` 取（false 會被吃成 nil）
    local v
    if type(cfg) == "table" and type(cfg.rows) == "table" then v = cfg.rows[key] end
    if v == nil then return R.DefaultOn(specID, key) end
    return v and true or false
end

-- 德魯伊看「現在的型態」：熊＝怒氣、貓＝能量＋連擊點、其餘照專精（梟＝星能）
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
        end
    else
        for _, key in ipairs(SPEC_RESOURCES[specID or 0] or {}) do out[#out + 1] = key end
    end
    if specID and MANA_SPECS[specID] then out[#out + 1] = "Mana" end
    return out
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
    if def.mode == "auraTimer" then return 0, 0 end     -- 剩餘時間只在引擎那邊，Lua 不讀
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

-- 這個專精「可以顯示」哪些資源（已套天賦／型態，不看玩家的開關）。有快取，
-- 專精／型態／天賦／上限變動時 Reevaluate 清掉
local cachedList, cachedSpec

function R.Candidates()
    if cachedList then return cachedList, cachedSpec end
    local specID = CurrentSpecID()
    local raw = R.RawList(CLASS, specID, DruidForm())
    for k in pairs(gateLog) do gateLog[k] = nil end
    local list = {}
    for _, key in ipairs(raw) do
        local ok, why = Available(key)
        gateLog[key] = (ok and "顯示：" or "隱藏：") .. why
        if ok then list[#list + 1] = key end
    end
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

-- 一列現在要幾格（bar 回 0）。上限讀不到（秘密值）時沿用上次的明文值，沒有就 5
local lastMax = {}
local function SegmentsFor(key)
    local def = RESOURCES[key]
    if not def then return 0 end
    if def.mode == "auraBar" then
        -- 引擎畫的連續填色：格數不受點數型的 10 格上限限制（橫掃攻擊 18 層）
        local m = def.maxFn and def.maxFn() or def.max
        return math.max(1, math.min(30, math.floor(tonumber(m) or 1)))
    end
    if def.mode ~= "pip" then return 0 end
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

-- 1px 黑邊：疊在填充之上（不是內縮），線寬換成整數實體像素
local function MakeEdge(parent, p1, p2, w, h)
    local e = parent:CreateTexture(nil, "OVERLAY")
    e:SetTexture(SOLID)
    e:SetVertexColor(0, 0, 0, 1)
    e:SetPoint(p1)
    e:SetPoint(p2)
    if w then e:SetWidth(ns.P.Scale(w)) end
    if h then e:SetHeight(ns.P.Scale(h)) end
    return e
end

-- 一格一個框的分段（點數型、自訂格子）：格寬與步距。
-- 每格自帶 1px 黑邊，間距 0 時相鄰兩條邊並排成 2px ⇒ 改成重疊 1 實體像素，兩格共用同一條邊。
-- 回傳 segW, gap（gap 可能是負的；第 i 格的 x ＝ (i-1)·(segW+gap)）
-- 第 i 格的 x 與寬（從填充起點量）。整列先換成整數實體像素再切：每格的左右邊界各自四捨五入，
-- 零頭平均分到各格，最後一格的右緣一定落在 W 上。
-- ⚠ 不能「格寬先對齊像素、再乘 n」：每格的捨入誤差會累積，6 格的符文列比同寬的符能條多出 2px
-- （玩家回報「自動同寬下兩列對不齊」）。格距 0 ＝ 相鄰兩格重疊 1px 共用一條邊
function R.SegCell(W, n, spacing, i)
    local px = ns.P.Scale(1)
    if not px or px <= 0 then px = 1 end
    local gp = math.floor((tonumber(spacing) or 1) + 0.5)
    if gp <= 0 then gp = -1 end
    local Wp = math.floor(W / px + 0.5)
    local span = Wp + gp
    local x0 = math.floor((i - 1) * span / n + 0.5)
    local x1 = math.floor(i * span / n + 0.5) - gp
    return x0 * px, (x1 - x0) * px
end

local function Edges(frame)
    MakeEdge(frame, "TOPLEFT", "TOPRIGHT", nil, 1)
    MakeEdge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    MakeEdge(frame, "TOPLEFT", "BOTTOMLEFT", 1, nil)
    MakeEdge(frame, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
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
    Edges(seg)
    seg:Hide()
    return seg
end

-- 符文格的秒數（懶建；只有符文列、倒數開著才顯示）。
-- 顯示／隱藏只在排版時做，更新只換字（SetText("")），熱路徑上不碰 Show／Hide
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
    ns.Media.SetPixelFont(seg.timer, tonumber(cfg.textSize) or 10, "OUTLINE", ns.Setting(nil, "font"))
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
    Edges(row.bar)
    -- 數值掛在獨立的高層框上，父層是 row（點數型會把 bar 整個藏起來）
    -- 懶建的零件先放 false（有就是框、沒有就是 false；沒寫過的欄位別指望是 nil 以外的東西）
    row.ab, row.abDecor, row.absorbClip, row.absorbBar = false, false, false, false
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

-- 「未填滿」的顏色：整條層級規則的 bgColor 命中時取代暗色
local function DimColor(barOv)
    local a = DIM.a
    if barOv then
        local bc = RC.ValidColor(barOv.bgColor)
        if bc then return bc, bc.a or a end
    end
    return DIM, a
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
R.RowHeight = RowHeight

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
local function LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local gap = ns.P.Scale(tonumber(cfg.segmentSpacing) or 1)
    local geom = {
        W = W, H = H, n = numSeg, gap = gap, segW = (W - gap * (numSeg - 1)) / numSeg, reversed = reversed,
        segments = true, dim = { DIM.r, DIM.g, DIM.b, DIM.a }, px = ns.P.Scale(1),
    }
    local cc = ResolveColor(cfg, key, "color")
    local status = ns.AuraBar.Apply(row.ab, {
        kind = def.instances and "instances" or "applications",
        spellIDs = def.auras, max = numSeg, texture = tex, color = cc, alpha = tonumber(cfg.barAlpha) or 1,
        reversed = reversed, cell = def.instances and geom or nil,
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

-- 剩餘時間條的秒數：低於這個秒數印一位小數（秘法靈魂 4 秒整段都有小數；黯黑力量剩 5 秒起）
local TIMER_DECIMALS_BELOW = 5

-- 空條的底色：跟連續條同一套（主色 × 0.25、alpha 0.8）。out 給了就填進去（熱路徑上不配表）
function R.TimerDim(c, out)
    out = out or {}
    out[1], out[2], out[3], out[4] = c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.8
    return out
end
local timerDimScratch = {}

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
            font = ns.Media.Font(ns.Setting(nil, "font")),
            size = (tonumber(cfg.textSize) or 10) * scale,
            decimals = TIMER_DECIMALS_BELOW,
        }
    end
    local status = ns.AuraBar.Apply(row.ab, {
        kind = "duration", spellIDs = def.auras, max = 1, texture = tex, color = cc,
        alpha = tonumber(cfg.barAlpha) or 1, reversed = reversed, text = text,
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    -- 空條（暗底＋1px 黑邊）畫在列上：光環不在時按鈕藏著，看到的就是這個
    ns.AuraBar.RowDecor(row, {
        W = W, H = H, n = 1, gap = 0, segW = W, reversed = reversed, segments = false,
        dim = R.TimerDim(cc), px = ns.P.Scale(1),
    }, (row:GetFrameLevel() or 1) + 8)
    return true
end

local function LayoutRow(row, key, cfg, numSeg, W, H)
    local def = RESOURCES[key]
    row:SetSize(W, H)
    -- 換列：上一個資源的條件殘留一律先還原
    row:SetAlpha(1)
    row.condAlpha, row.condApplied = nil, nil
    row.text:SetTextColor(1, 1, 1, 1)

    local reversed = ns.FillReversed(cfg)
    local tex = ns.Media.Texture(cfg.texture)
    local showText = cfg.showText and true or false
    if def.fill == "rune" then showText = showText and R.RuneText(cfg) == "count" end
    ns.Media.SetPixelFont(row.text, tonumber(cfg.textSize) or 10, "OUTLINE", ns.Setting(nil, "font"))
    row.text:SetText("")

    -- 這一列實際的畫法：容器沒好時 auraBar 退回 pip（明文層數）、auraTimer 退回空條
    local mode = def.mode
    if mode == "auraBar" then
        mode = R.DrawMode(mode, LayoutAuraBar(row, key, def, cfg, numSeg, W, H, reversed, tex))
    elseif mode == "auraTimer" then
        mode = R.DrawMode(mode, LayoutAuraTimer(row, key, def, cfg, W, H, reversed, tex))
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
    row.text:SetShown(showText and mode ~= "engine" and mode ~= "timerIdle")

    local isPip = mode == "pip" and numSeg and numSeg > 0
    local isBar = mode == "bar" or mode == "absorbBar" or mode == "timerIdle"
    row.barBG:SetShown(isBar)
    row.bar:SetShown(isBar)
    if mode ~= "absorbBar" then HideAbsorb(row) end

    if not isPip then
        for i = 1, MAX_SEGMENTS do row.segs[i]:Hide() end
        if not isBar then return end
        row.bar:SetStatusBarTexture(tex)
        row.bar:SetReverseFill(reversed)
        row.barBG:SetTexture(tex)
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
    for i = 1, numSeg do
        local seg = row.segs[i]
        local x, segW = R.SegCell(W, numSeg, cfg.segmentSpacing, i)
        seg:SetSize(segW, H)
        seg:ClearAllPoints()
        -- 從右到左：第 1 格在最右邊
        if reversed then
            seg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            seg:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        seg:SetStatusBarTexture(tex)
        seg.bg:SetTexture(tex)
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
-- 同時最多三顆在轉，其餘的 start 在未來（排隊中）：進度 0、不印秒數。
------------------------------------------------------------
local RUNE_RECHARGE_SHADE = 0.55     -- 在轉的格子：同色系暗一階（狀態只換明暗不換色）
local runeReady, runeRemain, runeProgress, runeOrder = {}, {}, {}, {}
local runeRechargeColor = { r = 0, g = 0, b = 0 }

-- 回傳轉好的顆數、有沒有在轉的
local function ReadRunes(n, now)
    local readyCount, anyRecharging = 0, false
    for i = 1, n do
        local ok, start, duration, isReady = pcall(GetRuneCooldown, i)
        local r, rem, prog = false, nil, nil
        if ok and isReady ~= nil and not ns.IsSecret(isReady) then r = isReady and true or false end
        if r then
            readyCount = readyCount + 1
        else
            anyRecharging = true
            local s, d = ok and Plain(start), ok and Plain(duration)
            if s and d and d > 0 then
                rem = s + d - now
                if rem < 0 then rem = 0 end
                prog = (now - s) / d
                if prog < 0 then prog = 0 elseif prog > 1 then prog = 1 end
            end
        end
        runeReady[i], runeRemain[i], runeProgress[i] = r, rem, prog
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

-- 純函式：在轉的格子要印的秒數（無條件進位，跟冷卻數字同一種讀法）；排隊中／讀不到回 nil
function R.RuneSeconds(remain, progress)
    if type(remain) ~= "number" or type(progress) ~= "number" or progress <= 0 or remain <= 0 then return nil end
    return math.ceil(remain)
end

local function UpdatePipRow(row, cfg, def, key, numSeg, cc, conds)
    local alpha = tonumber(cfg.barAlpha) or 1
    if def.fill == "rune" then
        -- 符文：先排序再畫（轉好的靠左、在轉的依剩餘時間往右排），在轉的格子填進度
        local readyCount, anyRecharging = ReadRunes(numSeg, GetTime())
        local order = R.RuneOrder(runeReady, runeRemain, numSeg, runeOrder)
        local barOv
        if conds then
            RC.FillState(condState, readyCount, numSeg, CurrentSpecID())
            barOv = RC.FirstMatch(conds, condState, nil)
        end
        local dimC, dimA = DimColor(barOv)
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
                local sec = countdown and not ready and R.RuneSeconds(runeRemain[idx], runeProgress[idx])
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
        if anyRecharging then R.ArmRuneTicker() end
        return
    end

    local cur = GetValue(key)
    local pc = Plain(cur)
    local charged = ChargedPoints(key)
    local chargedCC, chargedEmptyCC
    if charged then
        chargedCC = ResolveColor(cfg, key, "chargedColor")
        chargedEmptyCC = ResolveColor(cfg, key, "chargedEmptyColor")
    end
    local barOv
    if conds and pc then
        RC.FillState(condState, pc, numSeg, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local dimC, dimA = DimColor(barOv)
    for i = 1, numSeg do
        local seg = row.segs[i]
        seg:SetMinMaxValues(i - 1, i)
        seg:SetValue(cur or 0)                    -- 秘密值照樣：引擎決定這格亮多少
        local isCharged = charged and charged[i]
        local c = isCharged and chargedCC or cc
        -- 充能且已填滿的格子跳過條件：充能色是「這一格值兩點」的訊號，不能被蓋掉
        if conds and pc and not isCharged and i <= pc then
            condState.pipRecharging = false
            local ov = RC.FirstMatch(conds, condState, i)
            local oc = ov and RC.ValidColor(ov.color)
            if oc then c = oc end
        end
        SetSegColor(seg, c, alpha)
        if isCharged then
            -- 充能但還沒填到：底色畫成暗的充能色（打滿之前就看得出哪幾格是充能格）
            seg.bg:SetVertexColor(chargedEmptyCC.r, chargedEmptyCC.g, chargedEmptyCC.b, DIM.a)
        else
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
        end
    end
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        -- 光環／技能次數型沒累積時不畫（空著比一顆「0」乾淨）；讀不到明文也不印
        if pc == nil or ((def.aura or def.cast or def.auras) and pc <= 0) then
            row.text:SetText("")
        else
            row.text:SetFormattedText("%d", pc)
        end
    end
end

-- 醉仙緩勁的段落（純函式）：pct ＝ 醉仙緩勁 ／ 最大生命 × 100（明文才算）
function R.StaggerBand(pct, moderateAt, heavyAt)
    if type(pct) ~= "number" then return nil end
    heavyAt, moderateAt = tonumber(heavyAt) or 60, tonumber(moderateAt) or 30
    if pct >= heavyAt then return "heavy" end
    if pct >= moderateAt then return "moderate" end
    return "light"
end
local STAGGER_FIELD = { light = "color", moderate = "moderateColor", heavy = "heavyColor" }
R.STAGGER_FIELD = STAGGER_FIELD

-- 醉仙緩勁：上一次明文算出來的段落與滿條上限（副本戰鬥中兩個值會間歇變成秘密值，那幾下沿用）
local staggerLast = { band = nil, max = nil }
R.staggerLast = staggerLast

-- 回傳：條的上限（明文或原始的秘密最大生命）、這次的顏色欄位
local function StaggerResolve(cfg, cur, maxHealth)
    local pc, pmh = Plain(cur), Plain(maxHealth)
    local barMax
    if pmh and pmh > 0 then
        local ceil = tonumber(cfg.staggerCeiling) or 100
        if ceil < 1 then ceil = 1 end
        barMax = pmh * ceil / 100
        staggerLast.max = barMax
    elseif staggerLast.max then
        barMax = staggerLast.max
    else
        barMax = maxHealth              -- 從來沒讀到過明文：原始值直接餵（上限 100%）
    end
    if pc and pmh and pmh > 0 then
        staggerLast.band = R.StaggerBand(pc / pmh * 100, cfg.staggerModerateAt, cfg.staggerHeavyAt)
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
    local bgc = barOv and RC.ValidColor(barOv.bgColor)
    if bgc then
        row.barBG:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a or 0.8)
    else
        row.barBG:SetVertexColor(fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, 0.8)
    end
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
    local bgc = barOv and RC.ValidColor(barOv.bgColor)
    if bgc then
        row.barBG:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a or 0.8)
    else
        row.barBG:SetVertexColor(fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, 0.8)
    end
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        if type(cur) ~= "number" or (pc ~= nil and pc <= 0) then row.text:SetText("") else SetBigNumber(row.text, cur, cfg) end
    end
end

local function UpdateRow(row, cfg)
    local key = row.key
    local def = key and RESOURCES[key]
    if not def then return end
    if row.mode == "engine" then
        -- 引擎寫層數：Lua 這邊沒有東西要畫
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    if row.mode == "timerIdle" then
        -- 剩餘時間條的容器還沒好（戰鬥中、建失敗）：空條，底色同連續條
        local d = R.TimerDim(ResolveColor(cfg, key, "color"), timerDimScratch)
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
    if row.mode == "absorbBar" then
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
end

------------------------------------------------------------
-- 重排與重畫
------------------------------------------------------------
local shownCount = 0
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
    local H = ns.P.Scale(RowHeight(cfg))
    local gap = ns.P.Scale(tonumber(cfg.rowSpacing) or 1)
    W = ns.P.Scale(W)
    local prev
    for i, key in ipairs(list) do
        local row = rows[i]
        if not row then
            row = MakeRow(root)
            rows[i] = row
        end
        row.key = key
        row.numSeg = SegmentsFor(key)
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        end
        prev = row
        row:Show()
        LayoutRow(row, key, cfg, row.numSeg, W, H)
        if row.ab and ns.AuraBar then ns.AuraBar.KickPending(row.ab) end
    end
    for i = #list + 1, #rows do
        local row = rows[i]
        row:Hide()
        row.key, row.mode = nil, nil
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
    end
    shownCount = #list
    local n = #list
    ns.Bars.SetPanelSize("resources", W, n > 0 and (n * H + (n - 1) * gap) or 1)
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
        laidOut = false
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

-- 符文回充的進度與秒數沒有事件可等（RUNE_POWER_UPDATE 只在轉好／用掉時來）：
-- 有符文在轉時開一個 0.1 秒的 ticker 只重畫符文列，全部轉好（或列不見了）就停
local runeTicker
local runeRearmed = false        -- 這一趟有沒有人說「還有符文在轉」

local function RuneTick()
    runeRearmed = false
    local cfg = Cfg()
    local busy = false
    if cfg and cfg.enabled ~= false then
        for i = 1, shownCount do
            local row = rows[i]
            local def = row.key and RESOURCES[row.key]
            if def and def.fill == "rune" and row.mode == "pip" and row:IsShown() then
                busy = true
                local ok, err = xpcall(UpdateRow, ns.ReportError, row, cfg)
                if not ok then R.lastError = err end
            end
        end
    end
    -- UpdatePipRow 在還有符文在轉時會再呼叫 ArmRuneTicker；這一趟沒人呼叫 ⇒ 全部轉好了
    if not busy or not runeRearmed then
        if runeTicker then runeTicker:Cancel() end
        runeTicker = nil
    end
end

function R.ArmRuneTicker()
    runeRearmed = true
    if runeTicker or not (C_Timer and C_Timer.NewTicker) then return end
    runeTicker = C_Timer.NewTicker(0.1, RuneTick)
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
-- 只重畫值的生命／吸收事件（醉仙緩勁的上限是最大生命、每跳扣血；無視苦痛看吸收量與最大生命）
local HEALTH_EVENTS = {
    MONK    = { "UNIT_HEALTH", "UNIT_MAXHEALTH" },
    WARRIOR = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" },
}

local REEVAL_EVENTS = {
    UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UPDATE_SHAPESHIFT_FORM = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_ENTERING_WORLD = true, UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true,
    SPELLS_CHANGED = true,
}

local evFrame

local function OnEvent(_, event)
    if event == "UNIT_POWER_POINT_CHARGE" then chargedDirty = true end
    if event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
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
    -- 光環堆疊型（漩渦之武／矛尖）與野德的滿溢之力只能吃 UNIT_AURA：有這種資源的職業才註冊
    -- （自訂格子的層數列另外由 Modules/Pips.lua 自己註冊）
    if AURA_DRIVEN_CLASSES[CLASS] then evFrame:RegisterUnitEvent("UNIT_AURA", "player") end
    for _, e in ipairs(HEALTH_EVENTS[CLASS] or {}) do evFrame:RegisterUnitEvent(e, "player") end
    evFrame:SetScript("OnEvent", OnEvent)
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
    R.Reevaluate()
end

-- 設定頁改了值：重排＋結構（錨點、strata、開關）＋ alpha
function R.Apply()
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
    end
    for key, why in pairs(gateLog) do
        local listed = false
        for i = 1, shownCount do if rows[i].key == key then listed = true end end
        if not listed then out[#out + 1] = ("    （%s）%s"):format(key, why) end
    end
    return out
end
