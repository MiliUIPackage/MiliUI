------------------------------------------------------------
-- 資源條：資源定義（從 Modules/Resources.lua 切出，2026-10-18；TOC 緊接在 Resources.lua 之後載入）
--
-- 每種資源的定義表 RESOURCES、專精 → 候選清單 SPEC_RESOURCES、職業 → 專精 CLASS_SPECS 等純資料，
-- 與只查這些表的純函式（候選清單、預設開關、遷移 v3）。表都掛在 R 上（R.RESOURCES、R.SPEC_RESOURCES…），
-- Resources.lua 本體與 Resources_Rows.lua 都從 R 上讀（這支在它們之後／之前載入，執行期才會查）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local R = ns.Resources
local PT = (Enum and Enum.PowerType) or {}

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

-- 光環的層數上限：C_Spell.GetSpellMaxCumulativeAuraApplications（明文；讀不到、秘密或不合理用 fallback）
local function MaxApps(spellID, fallback)
    local fn = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications
    if fn then
        local ok, v = pcall(fn, spellID)
        if ok and type(v) == "number" and not (ns.IsSecret and ns.IsSecret(v)) and v >= 1 and v <= 100 then
            return math.floor(v + 0.5)
        end
    end
    return fallback
end
-- 秘法齊射：點了 1260616 上限 25，否則 20（API 讀得到就照 API）
local function ArcaneSalvoMax() return MaxApps(1242974, Known(1260616) and 25 or 20) end
local function DemonicCoreMax() return MaxApps(264173, 4) end
local function FrozenMax() return MaxApps(1221389, 20) end

-- 火焰衝擊的充能：目前值直接轉手（可能是秘密值；點數型每格 SetValue 照樣畫得對），上限明文才給
-- （秘密時回 nil，SegmentsFor 沿用上次的明文上限）
local FIRE_BLAST = 108853
local function FireBlastValue()
    local fn = C_Spell and C_Spell.GetSpellCharges
    if not fn then return 0, nil end
    local ok, info = pcall(fn, FIRE_BLAST)
    if not ok or type(info) ~= "table" then return 0, nil end
    local cur, max = info.currentCharges, info.maxCharges
    if max ~= nil and ns.IsSecret and ns.IsSecret(max) then max = nil end
    return cur or 0, max
end

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
    -- 鐵鬃：12.1 實測是**一顆光環疊層數**（每施放一次是獨立一層、各自到期，遊戲併成一顆光環＋層數）。
    -- 畫法比照 YHUD／EllesmereUI：剩餘時間條（auraTimer，光環到期＝最晚那層）＋中間層數（引擎寫）＋
    -- 每層一根刻度線（依施放推算，見「每層刻度線」）
    Ironfur         = { name = SpellName(192081, "Ironfur"), nameSpell = 192081, mode = "auraTimer",
                        auras = { 192081 }, passive = 192081, castTimers = true },
    -- 2026-10-08 補（對照 YHUD）：惡魔核心、秘法齊射（引擎寫層數）；Frozen 是**目標身上**你上的減益層數
    -- （unit ＝ target、HARMFUL|PLAYER；敵對單位上的減益可以用 ID 過濾，換目標時 AB.Refresh）
    DemonicCore     = { name = SpellName(264173, "Demonic Core"), nameSpell = 264173, mode = "auraBar",
                        auras = { 264173 }, maxFn = DemonicCoreMax, max = 4 },
    ArcaneSalvo     = { name = SpellName(1242974, "Arcane Salvo"), nameSpell = 1242974, mode = "auraBar",
                        auras = { 1242974 }, maxFn = ArcaneSalvoMax, max = 20 },
    Frozen          = { name = SpellName(1221389, "Frozen"), nameSpell = 1221389, mode = "auraBar",
                        auras = { 1221389 }, maxFn = FrozenMax, max = 20, unit = "target", filter = "HARMFUL|PLAYER" },
    -- 火焰衝擊的充能（點數型，值是 C_Spell.GetSpellCharges 轉手）
    FireBlast       = { name = SpellName(FIRE_BLAST, "Fire Blast"), nameSpell = FIRE_BLAST, mode = "pip",
                        get = FireBlastValue, passive = FIRE_BLAST, charges = true },
    -- 光環剩餘時間條（auraTimer）。名字用光環的法術名
    --   黯黑力量：增輝的招牌技能 395152、身上的增益是 395296（基礎 10 秒，會被延長）
    --   秘法靈魂：Sunfury 英雄天賦「歐爾的記憶」449619 給的 451038（4 秒）；1223522 是 11.1 起同名同圖示的
    --   另一個 ID，一起放進過濾（沒出現就永遠比對不到，無害）。英雄樹 39 ＝ Sunfury
    EbonMight       = { name = SpellName(395296, "Ebon Might"), nameSpell = 395296, mode = "auraTimer",
                        auras = { 395296 }, passive = 395152 },
    ArcaneSoul      = { name = SpellName(451038, "Arcane Soul"), nameSpell = 451038, mode = "auraTimer",
                        auras = { 451038, 1223522 }, passive = 449619, heroTree = 39, gcdText = true },
    -- 狂暴（狂怒戰 184362）
    Enrage          = { name = SpellName(184362, "Enrage"), nameSpell = 184362, mode = "auraTimer", auras = { 184362 } },
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
    [71]  = { "Rage", "SweepingStrikes" },       [72]  = { "Rage", "WhirlwindStacks", "Enrage" },
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
    [62]  = { "ArcaneCharges", "ArcaneSoul", "ArcaneSalvo" },  [63]  = { "FireBlast" },  [64] = { "Icicles", "Frozen" },
    [265] = { "SoulShards" },                    [266] = { "SoulShards", "DemonicCore" },  [267] = { "SoulShards" },
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
    [65] = true, [66] = true, [70] = true,             -- 聖騎（防騎、懲戒預設不顯示，見 DEFAULT_OFF）
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
    [66] = MANA_OFF, [70] = MANA_OFF,                  -- 防騎、懲戒（玩家要勾得到法力，2026-10-13）
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
