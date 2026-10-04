------------------------------------------------------------
-- 資源條（DB key 仍叫 classpower —— 原本只有「職業點數」，現在是多列資源引擎）
--
-- 顯示範圍對齊 Ayije_CDM/Modules/Resources.lua：專精 → 該專精要看的資源清單。
-- 每一列自己決定長相：
--   pip  分段（點數型：聖能／連擊點數／真氣／碎片／充能／精華／符文，以及光環堆疊型）
--   bar  連續長條（怒氣／能量／集中值／符文能量／星能／元能／狂亂值／復仇之怒）
-- 點數型裡「正在累積的那一格」畫部分填充、暗一階：符文回充、精華回充、毀滅術的碎片片段
-- （後兩者只在讀得到明文時畫，秘密時退回整數）
--
-- ⚠ **不做法力**：法力已經有單位框自己的能量條（mpbar）與型態外魔力小條（manabar），
-- 資源條再列一次是重複。Ayije_CDM 有 MANA_SPECS 那張表是因為它的資源條是獨立 HUD、
-- 沒有單位框可靠——我們的情境不同，照抄反而多一條。
--
-- 12.1 注意：玩家自己的 UnitPower/UnitPowerMax 是明文，但仍一律過 Desecret/pcall
-- （進載具、被控時來源會變）。光環堆疊走 spellID 查詢（12.1 仍開放），層數可能是
-- 秘密值 → Desecret 後才拿來比大小。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local Media = ns.Media
local CLASS = ns.playerClass

local SOLID = Media.WHITE8X8
local DIM = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
local MAX_SEGMENTS = 10
local PT = Enum.PowerType

------------------------------------------------------------
-- 資源定義
------------------------------------------------------------
-- mode   pip / bar
-- power  Enum.PowerType（標準資源）
-- aura   光環 spellID（層數當點數）
-- cast   GetSpellCastCount 的 spellID
-- fill   pip 專用的特殊填充：rune（符文冷卻）／essence（精華回充）
-- fractionSpec  這個專精的點數有小數（毀滅術的碎片片段）：正在累積的那一格畫部分填充
-- 資源名稱優先用暴雪的全域字串：那是十二個語系的官方譯名，比插件自己翻準。
-- 全域不存在時退回英文，不要讓 name 變 nil
local function PowerName(global, fallback)
    local s = _G[global]
    if type(s) ~= "string" or s == "" then return fallback end
    -- ⚠ 有些暴雪字串帶**複數轉義**：zhTW 的 SOUL_SHARDS 是「靈魂|4裂片:裂片;」。
    -- `|4單數:複數;` 要由前面的數字驅動才會被客戶端解開，而我們只是拿它當標籤，
    -- 所以會原樣印出來（實測設定面板與 /muf debug 都是「靈魂|4裂片:裂片;」）。
    -- 取單數形就好。三種形式的語系寫成 |4a:b:c;，同樣取第一個。
    return (s:gsub("|4([^:;]*):[^;]*;", "%1"))
end

-- ⚠ **顏色不寫在這裡**：預設色的單一來源是 Core/DB.lua 的 RESOURCE_COLORS
-- （那邊同時餵 classpower.colors 的預設值）。這裡寫第二份的話兩邊遲早漂掉。
-- 取色一律走下面的 ResolveColor。
local RESOURCES = {
    Rage            = { name = PowerName("RAGE", "Rage"),     mode = "bar", power = PT.Rage },
    Energy          = { name = PowerName("ENERGY", "Energy"),     mode = "bar", power = PT.Energy },
    Focus           = { name = PowerName("FOCUS", "Focus"),   mode = "bar", power = PT.Focus },
    RunicPower      = { name = PowerName("RUNIC_POWER", "Runic Power"), mode = "bar", power = PT.RunicPower },
    LunarPower      = { name = PowerName("LUNAR_POWER", "Astral Power"),     mode = "bar", power = PT.LunarPower },
    Maelstrom       = { name = PowerName("MAELSTROM", "Maelstrom"),     mode = "bar", power = PT.Maelstrom },
    Insanity        = { name = PowerName("INSANITY", "Insanity"),   mode = "bar", power = PT.Insanity },
    Fury            = { name = PowerName("FURY", "Fury"), mode = "bar", power = PT.Fury },
    HolyPower       = { name = PowerName("HOLY_POWER", "Holy Power"),     mode = "pip", power = PT.HolyPower },
    ComboPoints     = { name = PowerName("COMBO_POINTS", "Combo Points"), mode = "pip", power = PT.ComboPoints },
    Chi             = { name = PowerName("CHI", "Chi"),     mode = "pip", power = PT.Chi },
    SoulShards      = { name = PowerName("SOUL_SHARDS", "Soul Shards"), mode = "pip", power = PT.SoulShards, fractionSpec = 267 },
    ArcaneCharges   = { name = PowerName("ARCANE_CHARGES", "Arcane Charges"), mode = "pip", power = PT.ArcaneCharges },
    Essence         = { name = PowerName("ESSENCE", "Essence"),     mode = "pip", power = PT.Essence, fill = "essence" },
    Runes           = { name = PowerName("RUNES", "Runes"),     mode = "pip", power = PT.Runes, fill = "rune" },
    -- 光環／技能次數型（Ayije_CDM 的 custom power，資料來源都是明文 API）
    -- 中文名一律取自 Ayije_CDM/Locales/zhTW.lua（使用者已對過官方譯名，別自己翻）
    MaelstromWeapon = { name = L["Maelstrom Weapon"], mode = "pip", aura = 344179, max = 10,  passive = 187880 },
    TipOfTheSpear   = { name = L["Tip of the Spear"], mode = "pip", aura = 260286, max = 3,   passive = 260285 },
    SoulFragments   = { name = L["Soul Fragments"], mode = "pip", cast = 228477, max = 6,   passive = 203981 },
}

-- 專精 → 資源清單（照抄 Ayije_CDM/Modules/Resources.lua 的 SPEC_POWER_MAP）
local SPEC_RESOURCES = {
    [71]  = { "Rage" },                          [72]  = { "Rage" },
    [73]  = { "Rage" },                          -- 防戰的「無視苦痛」是吸收量，12.1 秘密值，不做
    [65]  = { "HolyPower" },                     [66]  = { "HolyPower" },  [70] = { "HolyPower" },
    [253] = { "Focus" },                         [254] = { "Focus" },
    [255] = { "Focus", "TipOfTheSpear" },
    [259] = { "Energy", "ComboPoints" },         [260] = { "Energy", "ComboPoints" },
    [261] = { "Energy", "ComboPoints" },
    [258] = { "Insanity" },
    [250] = { "RunicPower", "Runes" },           [251] = { "RunicPower", "Runes" },
    [252] = { "RunicPower", "Runes" },
    [262] = { "Maelstrom" },                     [263] = { "MaelstromWeapon" },
    [62]  = { "ArcaneCharges" },
    [265] = { "SoulShards" },                    [266] = { "SoulShards" },  [267] = { "SoulShards" },
    [268] = { "Energy" },                        -- 釀酒的「醉仙緩勁」是吸收量，同上不做
    [269] = { "Energy", "Chi" },
    [102] = { "LunarPower" },                    [103] = { "Energy", "ComboPoints" },
    [104] = { "Rage" },                          -- 「鐵鬃」同為吸收量
    [105] = {},
    [577] = { "Fury" },                          [581] = { "Fury", "SoulFragments" },
    [1480] = { "Fury" },
    [1467] = { "Essence" },                      [1468] = { "Essence" },  [1473] = { "Essence" },
}

local function CurrentSpecID()
    local idx = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
                and C_SpecializationInfo.GetSpecialization()
                or (GetSpecialization and GetSpecialization())
    if not idx then return nil end
    local id = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
               and C_SpecializationInfo.GetSpecializationInfo(idx)
               or (GetSpecializationInfo and GetSpecializationInfo(idx))
    return id
end

------------------------------------------------------------
-- 取值（全部明文；拿不到就回 nil 讓那一列自己隱藏）
------------------------------------------------------------
local function AuraStacks(spellID)
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return 0 end
    local ok, a = pcall(get, spellID)
    if not ok or not a then return 0 end
    return ns.Desecret(a.applications, 0) or 0
end

local function GetValue(key)
    local def = RESOURCES[key]
    if not def then return nil end
    if def.aura then return AuraStacks(def.aura), def.max end
    if def.cast then
        local fn = C_Spell and C_Spell.GetSpellCastCount
        if not fn then return 0, def.max end
        local ok, n = pcall(fn, def.cast)
        return (ok and ns.Desecret(n, 0)) or 0, def.max
    end
    local cur = ns.Desecret(UnitPower("player", def.power), 0) or 0
    local max = ns.Desecret(UnitPowerMax("player", def.power), 0) or 0
    return cur, max
end

------------------------------------------------------------
-- 顏色
--
-- 三層，由上而下：
--   1. 跟隨「冷卻管理器」（同一台電腦上另一支有資源條的插件）的顏色，來源依序：
--        a. MiliUI_CooldownManager 的公開 API（README「公開 API」，回傳形狀是契約）
--        b. 另一支冷卻管理器插件（舊來源）的 GetBarSetting（內部 API，不是契約）
--      兩支互斥（MiliUI_CooldownManager 偵測到舊來源就整支不初始化、GetResourceColors 回 nil），
--      實際上同時只有一個來源在答
--   2. 玩家在這裡自己調的 edb.colors[key][field]
--   3. 寫死的預設（Core/DB.lua 的 RESOURCE_COLORS，跟 DB 預設值同一份）
--
-- ⚠ 效能：Update 掛在 UNIT_POWER_FREQUENT 上，戰鬥中一秒好幾次。所以
--   * 顏色**每列每次 Update 解析一次**，解完當參數往下傳，不要每格解析
--   * 回傳的一律是「既有的表」（來源插件的／DB 的／預設那張），一次都不配新 table
--   * 充能色只有在真的有充能格時才解析（多數時候一列只解析一次 color）
--
-- ⚠ 對兩個來源都是**軟依賴**：任何一步失敗（沒載入、還沒就緒、方法改名、
-- 資料庫還沒建好、回傳不是顏色表）都靜默退到下一層，絕對不報錯 ——
-- 別人改名的代價只能是「顏色退回自己的」。
------------------------------------------------------------
local FALLBACK_COLOR = { r = 1, g = 1, b = 1 }

-- 我們的資源 key 跟兩個來源的資源 key 一模一樣（三邊都照暴雪的 PowerType 命名），
-- 所以不需要對照表。要分兩套的只有舊來源那邊充能那組欄位名：盜賊的「超級充能器」
-- 在舊來源叫 charged，野德的「滿溢之力」叫 overflowing。職業不會變，所以表在載入時
-- 就選好。⚠ 這張對照**只對舊來源用**：MiliUI_CooldownManager 的表已經是
-- color／chargedColor／chargedEmptyColor。
local AYIJE_FIELD = (CLASS == "DRUID")
    and { color = "color", chargedColor = "overflowingColor", chargedEmptyColor = "overflowingEmptyColor" }
    or  { color = "color", chargedColor = "chargedColor",     chargedEmptyColor = "chargedEmptyColor" }

local function DefaultColor(key, field)
    local t = ns.DB and ns.DB.RESOURCE_COLORS and ns.DB.RESOURCE_COLORS[key]
    local c = t and t[field]
    if type(c) == "table" and type(c.r) == "number" then return c end
    -- 充能色缺了就退回主色，不要退成白色：白色在深底上比主色還亮，
    -- 「哪幾格是充能」的判讀會整個反過來
    if field ~= "color" then return DefaultColor(key, "color") end
    return FALLBACK_COLOR
end
ns.ResourceDefaultColor = DefaultColor

-- ⚠ **畫的時候現查，不要在檔案載入時快取。** 插件之間的載入順序不保證
-- （OptionalDeps 只排順序、不是硬相依），玩家也可能事後才啟用來源插件、
-- MiliUI_CooldownManager 的引擎也要登入後幾拍才就緒 —— 快取下來的話「有沒有跟隨」會永遠停在
-- 登入那一刻的答案。IsAddOnLoaded 是 C 端查表，現查的代價可以忽略。
local function AddOnLoaded(name, global)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return (ok and loaded and _G[global] ~= nil) and true or false
end

local function MCDMLoaded() return AddOnLoaded("MiliUI_CooldownManager", "MiliUI_CooldownManager") end
local function AyijeLoaded() return AddOnLoaded("Ayije_CDM", "Ayije_CDM") end

-- MiliUI_CooldownManager 的公開 API 表：有載入、有 GetResourceColors 就回；否則 nil。
-- 不看 IsReady（那要等四條檢視器認領完才為真，資源顏色早在設定檔載入時就答得出來）：
-- 設定檔還沒載入、互斥偵測成立（整支沒初始化）時 GetResourceColors 自己回 nil，呼叫端照樣退下一個來源
local function MCDMApi()
    local api = _G.MiliUI_CooldownManager
    if type(api) ~= "table" or type(api.GetResourceColors) ~= "function" then return nil end
    return api
end

-- 它現在真的在答嗎（設定檔已載入）：法力的顏色表每份設定檔都有（預設值補得回來）
local function MCDMLive()
    local api = MCDMApi()
    if not api then return false end
    local ok, t = pcall(api.GetResourceColors, "Mana")
    return ok and type(t) == "table" or false
end

-- 設定頁改了資源顏色／條件規則：它廣播 ResourceStyleChanged，這裡照新的重畫
-- （不然要等下一次能量事件才換色）。登記一次；檔案層先試，Reevaluate 再補（載入順序不保證）
local mcdmHooked = false
local Reevaluate            -- 前置宣告（定義在下面）
local function OnMCDMStyle()
    if ns.ResourceFollowsCDM() and Reevaluate then Reevaluate() end
end
local function HookMCDM()
    if mcdmHooked then return end
    local api = _G.MiliUI_CooldownManager
    local fn = type(api) == "table" and api.RegisterCallback
    if type(fn) ~= "function" then return end
    local ok, res = pcall(fn, "ResourceStyleChanged", "MiliUI_UnitFrames.ClassPower", OnMCDMStyle)
    if ok and res ~= false then mcdmHooked = true end
end

-- 現在實際在答的來源："MiliUI_CooldownManager" / "Ayije_CDM" / nil（/muf debug 用）
function ns.ResourceCDMSource()
    if MCDMLive() then return "MiliUI_CooldownManager" end
    if AyijeLoaded() then return "Ayije_CDM" end
    return nil
end

-- 「跟隨冷卻管理器」現在生效嗎？回傳 (生效中, 有來源可跟)
--
-- 「有來源」看的是**載入**，不看就緒：MiliUI_CooldownManager 登入後要幾拍才就緒，這段期間勾選框
-- 若忽隱忽現，設定頁會被重建好幾次。還沒就緒時顏色退自己的，就緒後下一次更新就換過去。
--
-- edb.followAyije（鍵名是存檔相容留下來的，語意已經是「冷卻管理器」）是三態：
--   nil    玩家沒碰過 ⇒ 有來源就跟隨（兩支都裝的人本來就希望顏色一致）
--   true   跟隨（但沒有來源時等同不跟隨）
--   false  不跟隨，用自己的顏色
function ns.ResourceFollowsCDM(edb)
    if edb == nil then
        local u = ns.db and ns.db.units and ns.db.units.player
        edb = u and u.elements and u.elements.classpower
    end
    if not (MCDMLoaded() or AyijeLoaded()) then return false, false end
    local pref = edb and edb.followAyije
    if pref == nil then return true, true end
    return pref and true or false, true
end

local function MCDMColor(key, field)
    local api = MCDMApi()
    local fn = api and api.GetResourceColors
    if type(fn) ~= "function" then return nil end
    local ok, t = pcall(fn, key)
    if not ok or type(t) ~= "table" then return nil end
    local c = t[field]
    if type(c) ~= "table" then return nil end
    if type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then return nil end
    return c
end

local function AyijeColor(key, field)
    local cdm = _G.Ayije_CDM
    local fn = cdm and cdm.GetBarSetting
    if type(fn) ~= "function" then return nil end
    local ok, c = pcall(fn, cdm, key, AYIJE_FIELD[field] or field)
    if not ok or type(c) ~= "table" then return nil end
    if type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then return nil end
    return c
end

-- 冷卻管理器的顏色：MiliUI_CooldownManager 先答，沒有再問舊來源；都沒有回 nil
local function CDMColor(key, field)
    return MCDMColor(key, field) or AyijeColor(key, field)
end

-- field ∈ "color" / "chargedColor" / "chargedEmptyColor"
-- follow 由呼叫端算好一次往下傳（一列一次，不要每個欄位重算一遍「有沒有載入」）
local function ResolveColor(key, field, edb, follow)
    if follow then
        local c = CDMColor(key, field)
        if c then return c end
    end
    local own = edb and edb.colors and edb.colors[key]
    local c = own and own[field]
    if type(c) == "table" and type(c.r) == "number" then return c end
    return DefaultColor(key, field)
end

------------------------------------------------------------
-- 條件規則（依資源數值換顏色／透明度）
--
-- 資料模型跟冷卻管理器（兩個來源）的資源條條件**完全一致**。那不是為了長得像，而是
-- 「跟隨」勾著的時候我們直接吃它那張表 —— 兩套 schema 就沒辦法共用同一份求值器。
--
--   conditions = { rule, rule, ... }   由上而下，**第一條成立的就用它**
--   rule  = { target    = nil | 格子索引,          nil ＝整條，數字＝只作用在第 N 格
--             check     = leaf | { op = "and", children = { leaf, ... } },
--             overrides = { color, bgColor, alpha, tagColor } }   每一項都可缺
--   leaf  = { var = "always" / "powerValue" / "powerPercent" / "powerFull"
--                   / "spec" / "pipRecharging",
--             cmp = ">=" / ">" / "<=" / "<" / "==" / "~=",  value = 數字 | 布林 }
--
-- ⚠ 跟隨時讀到的是**別人的內部結構**：玩家可能裝著舊版，上游也可能改 schema。
-- 所以每一步都驗型別，壞掉的規則當作不成立，**絕對不報錯** —— 這段每秒跑好幾次，
-- 在這裡拋一次例外就是整條資源條當場消失。遞迴另外設深度上限，防自我參照的壞資料。
--
-- ⚠ Ayije 對連續條是用 Curve 串接，那是因為它直接餵秘密值；**我們不需要**：
-- 這個檔的值全部先過 ns.Desecret 變成明文（拿不到就是 0），純 Lua 比較即可。
--
-- ⚠ 效能：跟顏色同一套紀律 —— 條件**每列每次 Update 解析一次**，解完往下傳；
-- 狀態寫在檔案層級的 scratch 表，熱路徑上一個 table／closure／字串都不配。
-- 沒有條件的列走快路徑（一次取表、一次判空），成本接近零。
------------------------------------------------------------
-- 白名單：不在這張表裡的 cmp 一律當規則不成立。
-- 順序給設定面板列下拉用（ns.RESOURCE_CMP_LIST），比較符只有這一份定義
local CMP_OPS = {
    [">="] = function(a, b) return a >= b end,
    [">"]  = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"]  = function(a, b) return a < b end,
    ["=="] = function(a, b) return a == b end,
    ["~="] = function(a, b) return a ~= b end,
}
ns.RESOURCE_CMP_LIST = { ">=", ">", "<=", "<", "==", "~=" }

local MAX_CHECK_DEPTH = 4

local function ValidColor(c)
    if type(c) ~= "table" then return nil end
    if type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then return nil end
    return c
end

-- 這一列現在的狀態。檔案層級的 scratch，零配置（同 activeRows／segScratch）
local condState = {}

-- 專精：**不要每次 Update 都查**。ResourceCandidates 算候選清單時已經查過一次
-- 並快取起來（換專精／型態／天賦都會走 Reevaluate 把它清掉），直接借用那一份，
-- 就不必再開一個要記得失效的快取
local function StateSpec()
    local _, specID = ns.ResourceCandidates()
    return specID or 0
end

-- cur/max 是這一列的「值」與「上限」：
-- 連續條＝目前值／上限；點數型＝目前點數／格數；符文列＝**已經轉好的顆數**／格數
local function BuildCondState(cur, max)
    cur = cur or 0
    condState.powerValue = cur
    condState.powerPercent = (max and max > 0) and (cur / max * 100) or 0
    condState.powerFull = (max and max > 0 and cur >= max) or false
    condState.spec = StateSpec()
    condState.pipRecharging = false
    return condState
end

local function EvalLeaf(node, state)
    local var = node.var
    if var == "always" then return true end
    if var == "powerFull" then
        if type(node.value) ~= "boolean" then return false end
        return state.powerFull == node.value
    end
    if var == "pipRecharging" then
        if type(node.value) ~= "boolean" then return false end
        return state.pipRecharging == node.value
    end
    local fn = CMP_OPS[node.cmp]
    if not fn or type(node.value) ~= "number" then return false end
    if var == "powerValue" then return fn(state.powerValue, node.value) end
    if var == "powerPercent" then return fn(state.powerPercent, node.value) end
    if var == "spec" then return fn(state.spec, node.value) end
    return false
end

-- op 目前只有 and（Ayije 的設定介面會把 op 正規化成 AND），所以任何非 nil 的 op
-- 都當 and 處理。空的 children 判成立 —— 那是它的語意，跟隨時照它走
local function EvalCheck(node, state, depth)
    if type(node) ~= "table" then return false end
    if depth > MAX_CHECK_DEPTH then return false end
    if node.op then
        local children = node.children
        if type(children) ~= "table" then return false end
        local n = #children
        if n == 0 then return true end
        for i = 1, n do
            if not EvalCheck(children[i], state, depth + 1) then return false end
        end
        return true
    end
    return EvalLeaf(node, state)
end

-- index = nil  只看「整條」的規則（target 沒設的那些）
-- index = i    看「整條或指定第 i 格」的規則
-- 回傳 overrides, 規則序號；都不成立就回 nil
local function FirstMatch(conds, state, index)
    for i = 1, #conds do
        local rule = conds[i]
        if type(rule) == "table" then
            local t = rule.target
            -- t 是壞值（字串之類）時兩個條件都不成立 ⇒ 整條規則被跳過，這是對的
            if t == nil or (index ~= nil and t == index) then
                local ov = rule.overrides
                if type(ov) == "table" and rule.check ~= nil
                   and EvalCheck(rule.check, state, 1) then
                    return ov, i
                end
            end
        end
    end
    return nil
end

local function AyijeConditions(key)
    local cdm = _G.Ayije_CDM
    local fn = cdm and cdm.GetBarSetting
    if type(fn) ~= "function" then return nil end
    local ok, c = pcall(fn, cdm, key, "conditions")
    if not ok or type(c) ~= "table" or c[1] == nil then return nil end
    return c
end

-- MiliUI_CooldownManager 的條件規則（公開 API，形狀與我們的一致）；沒有規則回 nil
local function MCDMConditions(key)
    local fn = MCDMApi()
    fn = fn and fn.GetResourceConditions
    if type(fn) ~= "function" then return nil end
    local ok, c = pcall(fn, key)
    if not ok or type(c) ~= "table" or c[1] == nil then return nil end
    return c
end

-- 冷卻管理器的條件：MiliUI_CooldownManager **在答**（設定檔已載入）時只看它（它沒設規則＝沒有條件，
-- 不再往下問）；它沒在答才問舊來源。兩支互斥，實際上不會兩邊都有東西
local function CDMConditions(key)
    if MCDMLive() then return MCDMConditions(key) end
    return AyijeConditions(key)
end

-- 回傳**既有的那張表**（來源插件的或我們自己的），一次都不複製。
--
-- ⚠ 跟隨生效時就只看來源：它那邊沒設條件，就是「沒有條件」，不退回自己的。
-- 「跟隨」的意思就是照它；混著吃會出現「自己的規則配別人的底色」這種沒人要的組合。
local function ResolveConditions(key, edb, follow)
    if follow then return CDMConditions(key) end
    local root = edb and edb.conditions
    local t = root and root[key]
    if type(t) == "table" and t[1] ~= nil then return t end
    return nil
end

------------------------------------------------------------
-- 整條層級的覆寫（透明度與數值文字色）
--
-- ⚠ 列是**池化重用**的：Relayout 會把同一個 row 換成別的資源，殘留的透明度
-- 與文字色就會跑到別的資源身上。所以規則不成立要還原、換列也要還原
-- （換列那條在 LayoutRow，這裡負責「規則不再成立」那條）。
-- row.condApplied 是我們自己的 frame 上的欄位（不是暴雪的框），可以寫。
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
    local tc = ValidColor(ov.tagColor)
    if tc then
        row.text:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
    else
        row.text:SetTextColor(1, 1, 1, 1)
    end
    row.condApplied = true
end

------------------------------------------------------------
-- 從冷卻管理器複製一份顏色與條件過來（設定面板的「複製」按鈕）
--
-- ⚠ **深複製，而且只複製我們認得的欄位。** 絕對不能把它的表直接塞進我們的 DB：
-- 色票是「ctx.get 拿到 table 就原地改」，留著參照的話玩家在這裡調一次顏色
-- 就默默改壞它的存檔，而且那張表會被序列化進我們的 SavedVariables。
-- 每個值都驗過型別 —— 公開 API 的形狀是契約，但存檔內容仍是玩家的資料。
--
-- 語意是「鏡射來源目前的設定」：它沒有條件的資源，我們這邊也清掉。
-- 按鈕本來就帶確認彈窗。
------------------------------------------------------------
local COPY_COLOR_FIELDS = { "color", "chargedColor", "chargedEmptyColor" }
local CHECK_VARS = {
    always = true, powerValue = true, powerPercent = true,
    powerFull = true, spec = true, pipRecharging = true,
}

local function CopyColor(c)
    c = ValidColor(c)
    if not c then return nil end
    return { r = c.r, g = c.g, b = c.b, a = (type(c.a) == "number") and c.a or 1 }
end

local function CopyCheck(node, depth)
    if type(node) ~= "table" or depth > MAX_CHECK_DEPTH then return nil end
    if node.op then
        local src = node.children
        if type(src) ~= "table" then return nil end
        local out = {}
        for i = 1, #src do
            local child = CopyCheck(src[i], depth + 1)
            if child then out[#out + 1] = child end
        end
        if out[1] == nil then return nil end
        if out[2] == nil then return out[1] end       -- 只剩一條就不必包 and
        return { op = "and", children = out }
    end
    local var = node.var
    if not CHECK_VARS[var] then return nil end
    if var == "always" then return { var = "always" } end
    if var == "powerFull" or var == "pipRecharging" then
        if type(node.value) ~= "boolean" then return nil end
        return { var = var, value = node.value }
    end
    if not CMP_OPS[node.cmp] or type(node.value) ~= "number" then return nil end
    return { var = var, cmp = node.cmp, value = node.value }
end

local function CopyRule(rule)
    if type(rule) ~= "table" then return nil end
    local check = CopyCheck(rule.check, 1)
    if not check then return nil end
    if type(rule.overrides) ~= "table" then return nil end
    local src = rule.overrides
    local ov = {
        color = CopyColor(src.color),
        bgColor = CopyColor(src.bgColor),
        tagColor = CopyColor(src.tagColor),
    }
    if type(src.alpha) == "number" then ov.alpha = src.alpha end
    local out = { check = check, overrides = ov }
    local t = rule.target
    if type(t) == "number" and t >= 1 and t <= MAX_SEGMENTS then
        out.target = math.floor(t)
    end
    return out
end

-- 回傳「複製到幾種資源的設定」
function ns.ResourceCopyFromCDM(edb)
    if not edb or not ns.ResourceCDMSource() then return 0 end
    local colors = edb.colors
    if not colors then colors = {}; edb.colors = colors end
    local conds = edb.conditions
    if not conds then conds = {}; edb.conditions = conds end
    local n = 0
    for key in pairs(RESOURCES) do
        local touched = false
        for _, field in ipairs(COPY_COLOR_FIELDS) do
            -- 充能色只有連擊點數有，其餘資源查了也是空的
            if field == "color" or key == "ComboPoints" then
                local copy = CopyColor(CDMColor(key, field))
                if copy then
                    local t = colors[key]
                    if not t then t = {}; colors[key] = t end
                    t[field] = copy
                    touched = true
                end
            end
        end
        local src = CDMConditions(key)
        local out
        if src then
            out = {}
            for i = 1, #src do
                local r = CopyRule(src[i])
                if r then out[#out + 1] = r end
            end
            if out[1] == nil then out = nil end
        end
        if out then touched = true end
        if conds[key] ~= nil and not out then touched = true end
        conds[key] = out
        if touched then n = n + 1 end
    end
    return n
end

------------------------------------------------------------
-- 充能的連擊點
--
-- 盜賊天賦「超級充能器」會讓某幾格連擊點變成充能點（終結技吃到充能點時視同多花 2 點），
-- 暴雪內建 UI 把那幾格畫成藍色。野性德魯伊的「滿溢之力」是同一個概念的另一套來源。
--
--   盜賊  GetUnitChargedPowerPoints("player") → 被充能的**索引**陣列（可能是 nil）
--         事件 UNIT_POWER_POINT_CHARGE（綁 "player"）
--   野德  光環 405189 的層數 n ⇒ 第 1..n 格算充能
--
-- ⚠ 查表用檔案層級的表 wipe 重用，跟 activeRows／segScratch 同一個理由
-- （Update 掛在能量事件上，每次現配一張表就是純粹的垃圾）。盜賊那條再加一個
-- dirty 旗標：沒有充能事件的那幾百次 Update 一次 API 都不用打。
-- 盜賊與德魯伊共用同一張表沒問題 —— CLASS 在一場遊戲裡不會變，兩條路互斥。
------------------------------------------------------------
local FERAL_OVERFLOW_AURA = 405189
local chargedLookup = {}
local chargedDirty = true
-- 預覽孿生固定假裝第 1、2 格是充能格（設定面板調充能色才看得到效果）。
-- 獨立一張常數表，不會被 wipe 到
local PREVIEW_CHARGED = { [1] = true, [2] = true }

local function RefreshChargedLookup()
    chargedDirty = false
    wipe(chargedLookup)
    local fn = GetUnitChargedPowerPoints
    if type(fn) ~= "function" then return end
    local ok, list = pcall(fn, "player")
    if not ok or type(list) ~= "table" then return end
    for i = 1, #list do
        -- ⚠ 一律驗過型別才拿來當 table key／比大小。玩家自己的連擊點是明文，
        -- 但來源換人（載具、被控）時不保證，而秘密值當 key 會當場崩潰
        local idx = ns.Desecret(list[i], nil)
        if type(idx) == "number" and idx > 0 then chargedLookup[idx] = true end
    end
end

-- 這一輪哪幾格是充能格；沒有就回 nil（呼叫端據此整段跳過，含兩個充能色的解析）
local function ChargedPoints(key, isPreview)
    -- 只有連擊點數有這個概念
    if key ~= "ComboPoints" then return nil end
    if isPreview then return PREVIEW_CHARGED end
    if CLASS == "ROGUE" then
        if chargedDirty then RefreshChargedLookup() end
        return next(chargedLookup) and chargedLookup or nil
    end
    if CLASS == "DRUID" then
        -- ⚠ 走到這裡就表示「現在有 ComboPoints 這一列」，而德魯伊只有貓型態才有
        -- （見 ResourceCandidates 的型態分支）⇒ 型態閘不必再寫一次。
        -- 非野性專精讀這個光環一定是 0，多一次查詢換掉一次 CurrentSpecID()，划算。
        -- AuraStacks 已經 Desecret 過
        local n = AuraStacks(FERAL_OVERFLOW_AURA)
        if not n or n <= 0 then return nil end
        wipe(chargedLookup)
        for i = 1, math.min(n, MAX_SEGMENTS) do chargedLookup[i] = true end
        return chargedLookup
    end
    return nil
end

------------------------------------------------------------
-- 天賦判斷
--
-- 兩層，跟 Ayije_CDM 一致：
--   1. 德魯伊看「現在的型態」而不是專精（熊=怒氣、貓=能量+連擊點、梟=星能、其餘法力）
--      —— GetDruidPrimaryPowerType 的邏輯
--   2. 標準資源看 `UnitPowerMax > 0`。沒點到那個天賦時上限就是 0，
--      這比硬寫一張天賦表可靠得多（暴雪改天賦樹也不用跟著改）
--   3. 光環堆疊型沒有 UnitPowerMax 可查 → 查被動是否已學（IsSpellKnown）。
--      被動 ID 萬一寫錯會誤判，所以再加一條保險：**目前有層數就一律顯示**，
--      最壞情況是「平常不出現、用起來才出現」，不會整個消失。
------------------------------------------------------------
local DRUID_BEAR, DRUID_CAT = 5, 1

local function DruidPowerType(specID)
    local form = GetShapeshiftFormID and GetShapeshiftFormID()
    if form == DRUID_BEAR then return PT.Rage end
    if form == DRUID_CAT then return PT.Energy end
    if specID == 102 then return PT.LunarPower end
    return PT.Mana
end

local function SpellKnown(id)
    if not id then return true end
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return true end          -- API 不在就放行，寧可多顯示
    local ok, known = pcall(fn, id)
    if not ok then return true end
    return known and true or false
end

-- 給 /muf debug 用：這個資源為什麼在／不在
local gateLog = {}
function ns.ResourceGateLog() return gateLog end

local function Available(key)
    local def = RESOURCES[key]
    if not def then return false, "沒有定義" end
    if def.aura or def.cast then
        if SpellKnown(def.passive) then return true, "被動已學" end
        local cur = GetValue(key)
        if (cur or 0) > 0 then return true, "被動查不到但目前有層數" end
        return false, "被動未學（天賦沒點）"
    end
    local _, max = GetValue(key)
    if (max or 0) <= 0 then return false, "上限 0（天賦沒點／此型態沒有）" end
    return true, "上限 " .. tostring(max)
end

-- 現在的主資源（暗牧的狂亂值、戰士的怒氣、盜賊的能量…）。
-- 這些單位框自己的「能量條」(mpbar) 已經在畫了，資源條再列一次是重複 →
-- 一律從候選裡剔除。剩下的就是真正的「副資源」：連擊點數、聖能、真氣、
-- 碎片、充能、精華、符文，以及光環堆疊型那幾個。
local function PrimaryPowerType()
    return ns.Desecret(UnitPowerType("player"), nil)
end

-- 這個專精「可以顯示」哪些資源（不看使用者開關，但已套天賦／型態判斷）
--
-- ⚠ 有快取：ActiveRows 每次 Update 都會叫它，而能量類的 UNIT_POWER_FREQUENT
-- 一秒好幾次——不快取的話等於每幀重查一輪天賦與上限。
-- 專精／型態／天賦／上限變動時由 Reevaluate 清掉。
local cachedList, cachedSpec

function ns.InvalidateResourceCandidates() cachedList = nil end

function ns.ResourceCandidates()
    if cachedList then return cachedList, cachedSpec end
    local specID = CurrentSpecID()
    local raw = {}

    if CLASS == "DRUID" then
        -- 型態決定一切（專精只用來分辨梟德）
        local pt = DruidPowerType(specID)
        if pt == PT.Rage then
            raw = { "Rage" }
        elseif pt == PT.Energy then
            raw = { "Energy", "ComboPoints" }
        elseif pt == PT.LunarPower then
            raw = { "LunarPower" }
        end
    else
        for _, key in ipairs(SPEC_RESOURCES[specID or 0] or {}) do
            raw[#raw + 1] = key
        end
    end
    wipe(gateLog)
    local primary = PrimaryPowerType()
    local list = {}
    for _, key in ipairs(raw) do
        local def = RESOURCES[key]
        local ok, why
        if def and def.power and primary and def.power == primary then
            ok, why = false, "主資源（單位框的能量條已經在顯示）"
        else
            ok, why = Available(key)
        end
        gateLog[key] = (ok and "顯示：" or "隱藏：") .. why
        if ok then list[#list + 1] = key end
    end
    cachedList, cachedSpec = list, specID
    return list, specID
end

function ns.ResourceInfo(key) return RESOURCES[key] end

-- 實際要畫的清單（套上使用者開關）
--
-- ⚠ 用檔案層級的 scratch 表，不要每次現配一張：Update 掛在 power 桶上
-- （UNIT_POWER_FREQUENT，盜賊／武僧的能量一秒好幾次），每次配一張表就是純粹的垃圾。
-- 回傳的表**呼叫端不可以留著**，下一次呼叫就被 wipe 了。
local activeRows = {}

local function ActiveRows(edb)
    local cand = ns.ResourceCandidates()
    local off = edb.resources or {}
    wipe(activeRows)
    for _, key in ipairs(cand) do
        if off[key] ~= false and RESOURCES[key] then
            activeRows[#activeRows + 1] = key
        end
    end
    return activeRows
end

------------------------------------------------------------
-- 列的建構
------------------------------------------------------------
-- 分段的黑邊是疊在填充「之上」的貼圖（不是內縮），所以不會露縫；
-- 但線寬同樣要換算成整數實體像素，否則 Retina 上四邊粗細不一致
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

local function MakeSegment(row)
    local seg = CreateFrame("Frame", nil, row)
    local fg = seg:CreateTexture(nil, "ARTWORK")
    fg:SetTexture(SOLID)
    fg:SetAllPoints(seg)
    seg.fg = fg
    local bg = seg:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(SOLID)
    bg:SetAllPoints(seg)
    seg.bg = bg
    MakeEdge(seg, "TOPLEFT", "TOPRIGHT", nil, 1)
    MakeEdge(seg, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    MakeEdge(seg, "TOPLEFT", "BOTTOMLEFT", 1, nil)
    MakeEdge(seg, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    return seg
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.segs = {}
    for i = 1, MAX_SEGMENTS do
        row.segs[i] = MakeSegment(row)
        row.segs[i]:Hide()
    end
    -- 連續長條用
    row.barBG = row:CreateTexture(nil, "BACKGROUND")
    row.barBG:SetAllPoints(row)
    row.barBG:SetTexture(SOLID)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetFrameLevel(row:GetFrameLevel() + 1)
    -- 數值掛在獨立的高層 frame 上：直接建在 bar 上會被填充貼圖和黑邊壓過去。
    -- ⚠ 父層要是 row 不是 row.bar —— 點數型的列會把 bar 整個藏起來，
    -- 掛在 bar 底下的話點數型永遠看不到數字
    row.textFrame = CreateFrame("Frame", nil, row)
    row.textFrame:SetAllPoints(row)
    row.textFrame:SetFrameLevel(row:GetFrameLevel() + 20)
    row.text = row.textFrame:CreateFontString(nil, "OVERLAY")
    row.text:SetDrawLayer("OVERLAY", 7)
    row.text:SetJustifyH("CENTER")
    row.text:SetJustifyV("MIDDLE")
    row.text:SetTextColor(1, 1, 1, 1)
    row.text:SetShadowColor(0, 0, 0, 1)
    row.text:SetShadowOffset(1, -1)
    row.text:SetPoint("CENTER", row.textFrame, "CENTER", 0, 0)
    -- ⚠ 邊框要建在 row.bar 上，不能建在 row 上：bar 是層級更高的子 frame，
    -- 它的填充貼圖會蓋過 row 自己的 OVERLAY，黑框就看不見了
    row.barEdges = {
        MakeEdge(row.bar, "TOPLEFT", "TOPRIGHT", nil, 1),
        MakeEdge(row.bar, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
        MakeEdge(row.bar, "TOPLEFT", "BOTTOMLEFT", 1, nil),
        MakeEdge(row.bar, "TOPRIGHT", "BOTTOMRIGHT", 1, nil),
    }
    row:Hide()
    return row
end

-- 符文格的秒數（懶建；只有符文列、倒數開著才顯示）。
-- 顯示／隱藏只在排版時做，更新只換字
local function LayoutRuneTimer(seg, on, edb)
    if not on then
        if seg.timer then seg.timer:Hide() end
        return
    end
    if not seg.timer then
        local fs = seg:CreateFontString(nil, "OVERLAY")
        -- ⚠ 先給字型才能 SetText
        Media.SetPixelFont(fs, 10, "OUTLINE")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", seg, "CENTER", 0, 0)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        seg.timer = fs
    end
    Media.SetPixelFont(seg.timer, edb.textSize or 10, "OUTLINE", ns.db.global.font)
    seg.timer:SetText("")
    seg.timerSec = nil
    seg.timer:Show()
end

-- 死騎符文列的數字：「長條上顯示數值」（showText）是總開關，開著時這裡二選一
-- （使用者 2026-10-01 試過兩者並列後定案：一排數字裡再夾一個顆數會分不出哪個是顆數、
-- 哪個是秒數，不要再拆成兩個獨立開關）。
--   countdown 在轉的格子印剩餘秒數（預設）／count 中間印轉好的顆數
-- 排序與回充進度不受影響，兩種都有
local function RuneText(edb)
    local v = edb and edb.runeText
    if v == "count" then return v end
    return "countdown"
end

-- 一列的版面：pip 依段數切；bar 就整條
local function LayoutRow(row, key, edb, numSeg)
    local def = RESOURCES[key]
    local totalW = ns.P.Scale(edb.totalw or 200)
    local h = ns.P.Scale(edb.h or 6)
    row:SetSize(totalW, h)

    -- ⚠ 換列（列是池化重用的）：條件規則套上去的透明度與文字色一律先還原，
    -- 不然上一個資源的殘留狀態會跑到這個資源身上（見 ApplyRowOverrides）
    row:SetAlpha(1)
    row.condAlpha = nil
    row.condApplied = nil
    row.text:SetTextColor(1, 1, 1, 1)

    local isPip = def.mode == "pip" and numSeg and numSeg > 0
    -- 填充方向：連續條翻 StatusBar；點數型把格子從右邊排起（第 1 格在最右），
    -- 「亮到第幾格」的順序就跟著從右往左，PaintPip／符文那段完全不必知道方向。
    -- 改了方向要重排才會生效 —— Build 會清 f.sigKeys 逼下一次 Update 重排
    local reversed = ns.FillReversed(edb)
    for _, e in ipairs(row.barEdges) do e:SetShown(not isPip) end
    row.barBG:SetShown(not isPip)
    row.bar:SetShown(not isPip)
    -- 數值兩種模式都給：點數型（聖能、氣漩武器那種）一樣要看得到數字
    local showText = edb.showText and true or false
    if def.fill == "rune" then showText = showText and RuneText(edb) == "count" end
    row.text:SetShown(showText)
    if showText then
        Media.SetPixelFont(row.text, edb.textSize or 10, "OUTLINE", ns.db.global.font)
    end

    if not isPip then
        for i = 1, MAX_SEGMENTS do row.segs[i]:Hide() end
        row.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
        row.bar:SetReverseFill(reversed)
        return
    end

    -- 每格的左右邊界在整數實體像素上各自四捨五入，零頭平均分到各格，最後一格的右緣一定落在總寬上。
    -- ⚠ 不能「格寬先對齊像素、再一格接一格串」：每格的捨入誤差會累積，整列比同寬的長條多出幾 px
    local px = ns.P.Scale(1)
    if not px or px <= 0 then px = 1 end
    local gp = math.max(0, math.floor((edb.spacing or 1) + 0.5))
    local span = math.floor(totalW / px + 0.5) + gp
    local isRune = def.fill == "rune" and edb.showText and RuneText(edb) == "countdown"
    for i = 1, numSeg do
        local seg = row.segs[i]
        local x0 = math.floor((i - 1) * span / numSeg + 0.5)
        local x1 = math.floor(i * span / numSeg + 0.5) - gp
        local segW = (x1 - x0) * px
        seg:SetSize(segW, h)
        seg:ClearAllPoints()
        if reversed then
            seg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x0 * px, 0)
        else
            seg:SetPoint("TOPLEFT", row, "TOPLEFT", x0 * px, 0)
        end
        -- 填色貼在填充起點那一側、寬度由這裡給：符文回充時只改寬度（見 SetSegFill），其他資源永遠滿寬
        seg.fullW = segW
        seg.fg:ClearAllPoints()
        if reversed then
            seg.fg:SetPoint("TOPRIGHT", seg, "TOPRIGHT", 0, 0)
            seg.fg:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, 0)
        else
            seg.fg:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
            seg.fg:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)
        end
        seg.fg:SetWidth(segW)
        seg.fgW = segW
        LayoutRuneTimer(seg, isRune, edb)
        seg:Show()
    end
    for i = numSeg + 1, MAX_SEGMENTS do row.segs[i]:Hide() end
end

-- 一列現在要幾格（bar 回 0）
local function SegmentsFor(key, isPreview)
    local def = RESOURCES[key]
    if def.mode ~= "pip" then return 0 end
    if isPreview then return math.min(MAX_SEGMENTS, def.max or 5) end
    if def.max then return def.max end
    local _, max = GetValue(key)
    if not max or max <= 0 then return 0 end
    return math.min(MAX_SEGMENTS, max)
end

-- 這一輪各列要幾格：**算一次往下傳**。
-- ⚠ SegmentsFor 對標準資源內含 UnitPower ＋ UnitPowerMax 各一次、外加兩次 Desecret，
-- 而 Update 掛在能量事件上（戰鬥中一秒好幾次）。原本 LayoutMatches 與 UpdateRow
-- 各自重算一輪 ⇒ 盜賊（能量＋連擊點兩列）每次事件就是六次 API 呼叫在做同一件事。
-- 模組層級的 scratch 表重複使用，零配置。回傳的是共用表，呼叫端只讀、用完即棄
-- （RememberLayout 會自己複製一份存進 f.sigSegs，不能直接持有這張表）。
local segScratch = {}

local function ComputeSegments(rows, isPreview)
    for i = 1, #rows do segScratch[i] = SegmentsFor(rows[i], isPreview) end
    for i = #rows + 1, #segScratch do segScratch[i] = nil end
    return segScratch
end

------------------------------------------------------------
-- 元件
------------------------------------------------------------
------------------------------------------------------------
-- 這個框畫的是不是玩家？
--
-- ⚠ 看 baseUnit 不是 unit：進載具後 uf.unit 變成 "vehicle"，用 unit 判斷會讓整個
-- Build 被跳過 ⇒ 這時改設定（面板開著、脫戰）位置／層級都不會重套，要下車才生效。
-- baseUnit 是這個框「本來畫誰」，不隨載具改變。
--
-- ⚠ 預覽孿生沒有 baseUnit —— 它不對應任何真實單位，uf.unit 一律填 "player" 當安全
-- token，真正代表它畫誰的是 unitKey。少了這一段，資源條與魔力小條在預覽裡永遠不會
-- 被建出來（設定面板調它們完全看不到效果，而且不報錯）。
------------------------------------------------------------
local function IsPlayerFrame(uf)
    if uf.isPreview then return uf.unitKey == "player" end
    return uf.baseUnit == "player"
end

local function Build(uf, edb)
    if not IsPlayerFrame(uf) then return end
    local f = uf.elements.classpower
    if not f then
        f = CreateFrame("Frame", nil, uf)
        f.ename = "classpower"
        f.rows = {}
        uf.elements.classpower = f
    end
    -- 整條在框體下方，露出的那截也要接 ping，見 ArmPingReceiver
    ns.ArmPingReceiver(uf, f, uf.unitKey == "player" and "player-resource" or "unit")
    f:ClearAllPoints()
    -- holybar 語意：錨在框架底邊下方
    f:SetPoint("TOPLEFT", uf, "BOTTOMLEFT", ns.P.Scale(edb.x or 0), ns.P.Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 5)
    f.sigKeys = nil      -- 逼下一次 Update 重排（見 LayoutMatches）
    f:Show()
end

------------------------------------------------------------
-- 這組列跟上次排版的一樣嗎？（清單或格數變了就要重排）
--
-- ⚠ 以前是把 "key:段數" 串成一條字串當指紋再比字串 —— 每次 Update 都配一張表、
-- 組 N 段字串、跑一次 table.concat，而 Update 掛在能量事件上（一秒好幾次）。
-- 改成逐格比對：零配置，而且 SegmentsFor 的呼叫次數跟原本一樣。
--
-- f.sigKeys 為 nil 就一定不相符 —— Build 與 Reevaluate 靠 `f.sigKeys = nil` 強制重排
-- （刻意不抽成 InvalidateLayout 函式：Build 排在這一段**之前**，那裡呼叫得到的會是
--  同名的全域 nil，正是這個 repo 已經踩過幾次的坑）。
------------------------------------------------------------
local function LayoutMatches(f, rows, newSegs)
    local keys, segs = f.sigKeys, f.sigSegs
    if not (keys and segs) then return false end
    if #keys ~= #rows then return false end
    for i = 1, #rows do
        if keys[i] ~= rows[i] or segs[i] ~= newSegs[i] then return false end
    end
    return true
end

local function RememberLayout(f, rows, newSegs)
    local keys, segs = f.sigKeys, f.sigSegs
    if not keys then keys = {}; f.sigKeys = keys end
    if not segs then segs = {}; f.sigSegs = segs end
    wipe(keys)
    wipe(segs)
    -- 複製而不是持有 segScratch：那張表下一次 Update 就會被覆寫
    for i = 1, #rows do
        keys[i] = rows[i]
        segs[i] = newSegs[i]
    end
end

local function Relayout(f, edb, rows, newSegs)
    local h = ns.P.Scale(edb.h or 6)
    local gap = ns.P.Scale(edb.rowSpacing or 2)
    local prev
    for i, key in ipairs(rows) do
        local row = f.rows[i]
        if not row then
            row = MakeRow(f)
            f.rows[i] = row
        end
        row.key = key
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        end
        LayoutRow(row, key, edb, newSegs[i])
        row:Show()
        prev = row
    end
    for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
    local n = #rows
    f:SetSize(ns.P.Scale(edb.totalw or 200), n > 0 and (n * h + (n - 1) * gap) or 1)
end

------------------------------------------------------------
-- 部分填充（符文回充／精華回充／毀滅術的碎片片段共用）
--
-- 「正在累積的那一格」一律畫成同色系暗一階、寬度＝進度（狀態只換明暗不換色）。
-- 三者共用同一個係數，免得三種資源各暗各的
------------------------------------------------------------
local RECHARGE_SHADE = 0.55

local function PlainNumber(v)
    if type(v) ~= "number" or ns.IsSecret(v) then return nil end
    return v
end

-- 填色寬度＝格寬 × 進度（貼在填充起點那一側，見 LayoutRow）。0 寬的貼圖會被當成沒有尺寸，給一點點
local function SetSegFill(seg, prog)
    local w = (seg.fullW or 0) * prog
    if w < 0.01 then w = 0.01 end
    if seg.fgW ~= w then
        seg.fgW = w
        seg.fg:SetWidth(w)
    end
end

local function Clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

-- 毀滅術的碎片片段：UnitPower 帶第三個參數 true 拿「原始單位」（一顆＝10 片段）。
-- 回傳 (整顆數, 累積中那格的進度 0～1, 含小數的顆數)；讀不到明文就回 nil，
-- 呼叫端退回整數（＝加這個功能之前的樣子）。
-- 每顆幾個片段由 rawMax / max 推，讀不到就當 10 —— 不寫死，暴雪哪天改倍率也不會畫錯
local function ShardFraction(def, max)
    if not def.fractionSpec or StateSpec() ~= def.fractionSpec then return nil end
    local ok, raw = pcall(UnitPower, "player", def.power, true)
    raw = ok and PlainNumber(raw)
    if not raw or raw < 0 then return nil end
    local per = 10
    local ok2, rawMax = pcall(UnitPowerMax, "player", def.power, true)
    rawMax = ok2 and PlainNumber(rawMax)
    if rawMax and rawMax > 0 and max and max > 0 then per = rawMax / max end
    local value = raw / per
    local whole = math.floor(value)
    if max and max > 0 and whole >= max then return max, 0, value end
    return whole, value - whole, value
end

-- 喚能師的精華回充進度（下一顆回到幾成）。來源優先序：
--   1. UnitPartialPower（0～1000，明文才用）—— 暴雪內建精華條就是讀這個
--   2. 每秒回充量 GetPowerRegenForPowerType × 「上次精華數變動到現在」推算。
--      回充量只在明文時更新、秘密時沿用上次的明文值
--   3. 都沒有 ⇒ 不畫進度（回 nil）
-- 已滿（cur >= max）也回 nil。
-- ⚠ cur 在這裡自己重讀明文，不吃呼叫端那個 Desecret(…, 0) 的值：秘密時那邊是 0，
-- 拿 0 去推算會畫出一格假進度、ticker 也停不下來。秘密就整個不畫
local essenceLastCur, essenceChangeAt, essenceRegen

local function EssenceProgress(def, max, now)
    local okc, cur = pcall(UnitPower, "player", def.power)
    cur = okc and PlainNumber(cur)
    if not cur then return nil end
    if cur ~= essenceLastCur then
        essenceLastCur, essenceChangeAt = cur, now
    end
    if not max or max <= 0 or cur >= max then return nil end
    if UnitPartialPower then
        local ok, p = pcall(UnitPartialPower, "player", def.power)
        p = ok and PlainNumber(p)
        if p then return Clamp01(p / 1000) end
    end
    if GetPowerRegenForPowerType then
        local ok, r = pcall(GetPowerRegenForPowerType, def.power)
        r = ok and PlainNumber(r)
        if r and r > 0 then essenceRegen = r end
    end
    if essenceRegen and essenceChangeAt then
        return Clamp01((now - essenceChangeAt) * essenceRegen)
    end
    return nil
end

-- 「未填滿」那幾格的顏色：整條層級規則的 bgColor 命中時取代原本的暗色
-- （alpha 缺就沿用暗色那一份，不要突然變成不透明）
local function DimColor(edb, barOv)
    local dc = edb.dimColor or DIM
    local a = dc.a or 0.6
    if barOv then
        local bc = ValidColor(barOv.bgColor)
        if bc then return bc, bc.a or a end
    end
    return dc, a
end

-- charged/chargedCC/chargedEmptyCC 只有連擊點數會帶（見 ChargedPoints）；
-- 沒有充能格時三個都是 nil，整段判斷退化成原本那兩條路。
-- conds/barOv 只有這一列真的有條件規則時才會帶（見 ResolveConditions）；
-- 都是 nil 時整段跟加這個功能之前一模一樣。
-- partial（0～1 或 nil）＝第 filled+1 格正在累積的進度（精華回充／毀滅術碎片片段）：
-- 那一格填到進度、暗一階、不吃條件色（條件看的是整顆數，它還不算一顆）；
-- 其餘格子一律滿寬（列是池化的，上一輪的部分寬度要還原）
local function PaintPip(row, edb, numSeg, filled, cc, charged, chargedCC, chargedEmptyCC, conds, barOv, partial)
    local dc = edb.dimColor or DIM
    local alpha = edb.barAlpha or 1
    local dimC, dimA = DimColor(edb, barOv)
    local partialAt = partial and (filled + 1) or nil
    for i = 1, numSeg do
        local seg = row.segs[i]
        local isCharged = charged and charged[i]
        if i == partialAt then
            SetSegFill(seg, partial)
        else
            SetSegFill(seg, 1)
        end
        if i == partialAt then
            local k = RECHARGE_SHADE
            seg.fg:SetVertexColor(cc.r * k, cc.g * k, cc.b * k, alpha)
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
        elseif i <= filled then
            local c = isCharged and chargedCC or cc
            -- ⚠ 充能且已填滿的格子**跳過條件**：充能色是「這一格值兩點」的訊號，
            -- 被條件色蓋掉就讀不出來了，充能色優先
            if conds and not isCharged then
                condState.pipRecharging = false
                local ov = FirstMatch(conds, condState, i)
                local oc = ov and ValidColor(ov.color)
                if oc then c = oc end
            end
            seg.fg:SetVertexColor(c.r, c.g, c.b, alpha)
            seg.bg:SetVertexColor(c.r * 0.3, c.g * 0.3, c.b * 0.3, 0.8)
        elseif isCharged then
            -- 充能但還沒填到：畫在 fg 上、不透明度比照未填滿那條慣例（dc.a），
            -- 這樣打滿之前就看得出「哪幾格是充能格」，又不會比填滿的那幾格搶眼
            seg.fg:SetVertexColor(chargedEmptyCC.r, chargedEmptyCC.g, chargedEmptyCC.b, dc.a or 0.6)
            seg.bg:SetVertexColor(0, 0, 0, 0.4)
        else
            seg.fg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
            seg.bg:SetVertexColor(0, 0, 0, 0.4)
        end
    end
end

-- 點數型的數字。光環／技能次數型（氣漩武器、長矛之尖、靈魂碎片）沒累積時就不畫，
-- 空著比一顆「0」乾淨；標準職業點數（聖能、連擊點那種）照常顯示 0。
-- fracValue（含小數的顆數）只有毀滅術碎片讀得到明文時才帶：印一位小數（例 3.7）
local function SetPipText(row, def, edb, n, fracValue)
    if not edb.showText then return end
    if (def.aura or def.cast) and n <= 0 then
        row.text:SetText("")
        return
    end
    if fracValue then
        row.text:SetFormattedText("%.1f", fracValue)
        return
    end
    row.text:SetFormattedText("%d", n)
end

------------------------------------------------------------
-- 符文（死亡騎士）
--
-- GetRuneCooldown(i) 的 start／duration／ready 在 12.1 是明文；仍一律過 pcall／IsSecret，
-- 讀不到的那顆當「在轉、進度不明」（不填、不印秒數），排序照樣排在最後，不會跳格。
-- 同時最多三顆在轉，其餘的 start 在未來（排隊中）。edb.runeQueued（預設開）決定排隊中的怎麼畫：
--   開  秒數印 start＋duration－now（＝從現在到這顆轉好的總等待時間）；填充照「花掉那一刻 → 轉好」
--       整段等待時間走（RuneProgress），排隊轉成在轉時不跳回 0
--   關  舊行為：排隊中進度 0、不印秒數，填充只算自己那段冷卻
-- 「花掉那一刻」沒有 API，自己記（runeSpentAt：看到某顆從轉好變成沒轉好的那次更新）。
-- 檔案層級的 scratch（平行陣列，不配表）
------------------------------------------------------------
local runeReady, runeRemain, runeProgress, runeQueued, runeOrder = {}, {}, {}, {}, {}
local runeSpentAt = {}               -- [符文編號] = 看到它沒轉好的第一個時間點；轉好時清掉

-- 沒轉好的符文的填充進度（0～1）。countQueued 關：只算自己那段冷卻（排隊中＝0）；
-- 開：從 spentAt（花掉那一刻）到 start＋duration 的整段等待時間，spentAt 晚於 start 時以 start 為準
local function RuneProgress(now, start, duration, spentAt, countQueued)
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
            local st, d = ok and PlainNumber(start), ok and PlainNumber(duration)
            if st and d and d > 0 then
                rem = st + d - now
                if rem < 0 then rem = 0 end
                queued = st > now
                prog = RuneProgress(now, st, d, runeSpentAt[i], countQueued)
            end
        end
        runeReady[i], runeRemain[i], runeProgress[i], runeQueued[i] = r, rem, prog, queued
    end
    return readyCount, anyRecharging
end

-- runeOrder[格位] = 符文編號：轉好的靠左（照編號）、在轉的依剩餘時間由短到長，
-- 剩餘讀不到的排最後；同分照編號（插入排序，最多六顆）
local function RuneOrder(n)
    local order = runeOrder
    local k = 0
    for i = 1, n do
        if runeReady[i] then k = k + 1; order[k] = i end
    end
    local first = k + 1
    for i = 1, n do
        if not runeReady[i] then
            local key = runeRemain[i] or math.huge
            local j = k
            while j >= first and (runeRemain[order[j]] or math.huge) > key do
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

-- 沒轉好的格子要印的秒數（無條件進位，跟冷卻數字同一種讀法）；
-- 排隊中的：countQueued 開印總等待時間、關不印；讀不到／轉完回 nil
local function RuneSeconds(remain, queued, countQueued)
    if type(remain) ~= "number" or remain <= 0 then return nil end
    if queued and not countQueued then return nil end
    return math.ceil(remain)
end

-- 回充的進度與秒數沒有事件可等（RUNE_POWER_UPDATE 只在轉好／用掉時來）：
-- 有符文在轉時掛上共用的 0.1 秒 Metro，全部轉好就卸下
local RuneTick
local runeTicking = false
local function SetRuneTicking(on)
    if on == runeTicking then return end
    runeTicking = on
    if on then ns.Metro.Add("classpower_rune", 0.1, RuneTick) else ns.Metro.Remove("classpower_rune") end
end

-- 精華回充同理：進度沒有事件可等（UNIT_POWER 只在整顆回滿時來），有格子在回充時掛 Metro、回滿就卸
local EssenceTick
local essenceTicking = false
local function SetEssenceTicking(on)
    if on == essenceTicking then return end
    essenceTicking = on
    if on then ns.Metro.Add("classpower_essence", 0.1, EssenceTick) else ns.Metro.Remove("classpower_essence") end
end

local function UpdateRow(row, edb, isPreview, numSeg)
    local key = row.key
    local def = RESOURCES[key]
    if not def then return end
    -- 顏色一列解析一次（理由見 ResolveColor 上面的 ⚠ 效能那段）
    local follow = ns.ResourceFollowsCDM(edb)
    local cc = ResolveColor(key, "color", edb, follow)
    -- 條件同理，一列解析一次；沒有條件時 conds 是 nil，底下整段退化成原本的路
    local conds = ResolveConditions(key, edb, follow)

    if def.mode == "pip" then
        numSeg = numSeg or SegmentsFor(key, isPreview)   -- 沒帶進來才自己算
        if numSeg <= 0 then
            row.text:SetText("")
            ClearRowOverrides(row)
            return
        end
        if def.fill == "rune" and not isPreview then
            -- 符文：先排序再畫（轉好的靠左、在轉的依剩餘時間往右排），在轉的格子填進度
            local countQueued = edb.runeQueued ~= false
            local readyCount, anyRecharging = ReadRunes(numSeg, GetTime(), countQueued)
            local order = RuneOrder(numSeg)
            local barOv
            if conds then
                BuildCondState(readyCount, numSeg)
                barOv = FirstMatch(conds, condState, nil)
            end
            local dimC, dimA = DimColor(edb, barOv)
            local alpha = edb.barAlpha or 1
            local runeText = edb.showText and RuneText(edb) or nil
            local countdown = runeText == "countdown"
            for slot = 1, numSeg do
                local idx = order[slot]
                local seg = row.segs[slot]
                local ready = runeReady[idx]
                local prog = ready and 1 or (runeProgress[idx] or 0)
                -- 在轉的格子：同色系暗一階（狀態只換明暗不換色），底色照未填滿的暗色
                local k = ready and 1 or RECHARGE_SHADE
                local r, g, b, a = cc.r * k, cc.g * k, cc.b * k, alpha
                if conds then
                    -- ⚠ 符文是唯一「沒轉好的格子也吃條件色」的列：pipRecharging
                    -- 這個變數就是為它存在的。格子序號是排序後的位置
                    condState.pipRecharging = not ready
                    local ov = FirstMatch(conds, condState, slot)
                    local oc = ov and ValidColor(ov.color)
                    if oc then
                        r, g, b, a = oc.r, oc.g, oc.b, alpha
                        prog = 1          -- 命中時整格上色，暗底上看不出來
                    end
                end
                SetSegFill(seg, prog)
                seg.fg:SetVertexColor(r, g, b, a)
                if ready then
                    seg.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3, 0.8)
                else
                    seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
                end
                if seg.timer then
                    local sec = countdown and not ready and RuneSeconds(runeRemain[idx], runeQueued[idx], countQueued)
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
            -- 中間的顆數只在選了「顆數」時印（見 RuneText；不走 SetPipText，那支看 showText）
            if runeText == "count" then row.text:SetFormattedText("%d", readyCount) end
            SetRuneTicking(anyRecharging)
            return
        end
        local filled = isPreview and math.min(3, numSeg) or (GetValue(key) or 0)
        -- 正在累積的那一格（毀滅術碎片片段／精華回充）。預覽不畫；讀不到明文就是 nil ＝ 整數
        local partial, fracValue
        if not isPreview then
            if def.fractionSpec then
                local whole, frac, value = ShardFraction(def, numSeg)
                if whole then
                    filled = whole
                    fracValue = value
                    if frac > 0 then partial = frac end
                end
            elseif def.fill == "essence" then
                partial = EssenceProgress(def, numSeg, GetTime())
                SetEssenceTicking(partial ~= nil)
            end
        end
        -- 充能格：沒有的話兩個充能色連解析都不用（一般情況一列只解析一次顏色）
        local charged = ChargedPoints(key, isPreview)
        local chargedCC, chargedEmptyCC
        if charged then
            chargedCC = ResolveColor(key, "chargedColor", edb, follow)
            chargedEmptyCC = ResolveColor(key, "chargedEmptyColor", edb, follow)
        end
        -- 點數型的「值／上限」就是「幾格亮著／共幾格」
        local barOv
        if conds then
            BuildCondState(filled, numSeg)
            barOv = FirstMatch(conds, condState, nil)
        end
        PaintPip(row, edb, numSeg, filled, cc, charged, chargedCC, chargedEmptyCC, conds, barOv, partial)
        ApplyRowOverrides(row, barOv)
        SetPipText(row, def, edb, filled, fracValue)
        return
    end

    -- 連續條
    local cur, max
    if isPreview then
        cur, max = 62, 100
    else
        cur, max = GetValue(key)
    end
    if not max or max <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    local barOv
    if conds then
        BuildCondState(cur or 0, max)
        barOv = FirstMatch(conds, condState, nil)
    end
    -- 條件命中就換填充色；底色照既有規則取填充色的 25%（跟著一起換），
    -- 除非規則自己指定了 bgColor
    local fc = (barOv and ValidColor(barOv.color)) or cc
    row.bar:SetMinMaxValues(0, max)
    row.bar:SetValue(cur or 0)
    row.bar:SetStatusBarColor(fc.r, fc.g, fc.b, edb.barAlpha or 1)
    local bgc = barOv and ValidColor(barOv.bgColor)
    if bgc then
        row.barBG:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a or edb.bgAlpha or 0.8)
    else
        row.barBG:SetVertexColor(fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, edb.bgAlpha or 0.8)
    end
    ApplyRowOverrides(row, barOv)
    if edb.showText then
        row.text:SetFormattedText("%d", cur or 0)
    end
end

local function Update(uf, edb, bucket)
    local f = uf.elements.classpower
    if not f then return end
    local isPreview = uf.isPreview and true or false

    local rows = ActiveRows(edb)
    if #rows == 0 then
        f:Hide()
        return
    end
    f:Show()

    local segs = ComputeSegments(rows, isPreview)
    if not LayoutMatches(f, rows, segs) then
        Relayout(f, edb, rows, segs)
        RememberLayout(f, rows, segs)
    end
    for i = 1, #rows do
        UpdateRow(f.rows[i], edb, isPreview, segs[i])
    end
end

ns.RegisterElement{
    name = "classpower",
    order = 35,
    buckets = { "power", "powertype" },
    build = Build,
    update = Update,
}

-- 只重畫「符合條件的那幾列」：不重排、不重推導候選清單。
-- 給那些「值變了但資源種類沒變」的事件用（光環堆疊、連擊點充能）。
-- ⚠ 述詞用檔案層級的函式，不要在事件處理器裡現包 closure —— 這些事件在團隊戰
-- 很吵，每次派送配一個 closure 就是垃圾。
local function RepaintRows(match)
    local uf = ns.frames.player
    local edb = uf and uf.db.elements.classpower
    if not (uf and edb and edb.enabled ~= false and uf.elements.classpower) then return end
    for _, row in ipairs(uf.elements.classpower.rows or {}) do
        local def = row.key and RESOURCES[row.key]
        if row:IsShown() and def and match(row.key, def) then
            UpdateRow(row, edb, uf.isPreview)
        end
    end
end

local function IsComboRow(key) return key == "ComboPoints" end
local function IsRuneRow(_, def) return def.fill == "rune" end
local function IsEssenceRow(_, def) return def.fill == "essence" end

-- 符文列不在畫面上（框藏了、整列關了）就停：RepaintRows 沒走進符文那段 ⇒ 沒人說還在轉
RuneTick = function()
    local was = runeTicking
    runeTicking = false
    RepaintRows(IsRuneRow)
    if was and not runeTicking then ns.Metro.Remove("classpower_rune") end
end

-- 同上：精華列不在畫面上就停
EssenceTick = function()
    local was = essenceTicking
    essenceTicking = false
    RepaintRows(IsEssenceRow)
    if was and not essenceTicking then ns.Metro.Remove("classpower_essence") end
end

-- 型態／專精／符文／光環變動 → 重新評估（清單和格數都可能變）
Reevaluate = function()
    HookMCDM()
    ns.InvalidateResourceCandidates()
    chargedDirty = true          -- 換專精／型態之後充能狀態一定要重讀
    local uf = ns.frames.player
    if uf and uf.elements.classpower then
        local edb = uf.db.elements.classpower
        if edb and edb.enabled ~= false then
            uf.elements.classpower.sigKeys = nil    -- 強制重排（見 LayoutMatches）
            Update(uf, edb, "powertype")
        end
    end
end
ns.ResourceReevaluate = Reevaluate
HookMCDM()

-- 給設定面板列「第 N 格」用（條件規則的目標下拉）。連續條回 0
function ns.ResourceSegments(key)
    if not RESOURCES[key] then return 0 end
    return SegmentsFor(key, false)
end

-- 玩家框的資源條設定表（設定面板與 /muf debug 共用；框還沒建好時退回 DB）
local function PlayerEDB()
    local uf = ns.frames and ns.frames.player
    local edb = uf and uf.db and uf.db.elements and uf.db.elements.classpower
    if edb then return edb end
    local u = ns.db and ns.db.units and ns.db.units.player
    return u and u.elements and u.elements.classpower
end

-- 給 /muf debug 與設定面板用：這個資源現在有幾條條件、從哪來、目前命中第幾條。
-- 回傳 條數, 來源（"MiliUI_CooldownManager" / "Ayije_CDM" / "自己"）, 命中的序號或 nil
function ns.ResourceConditionDebug(key)
    local edb = PlayerEDB()
    local follow = ns.ResourceFollowsCDM(edb)
    local src = follow and (ns.ResourceCDMSource() or "冷卻管理器（尚未就緒）") or "自己"
    local conds = ResolveConditions(key, edb, follow)
    if not conds then return 0, src, nil end
    local def = RESOURCES[key]
    local cur, max
    if def and def.fill == "rune" then
        max = SegmentsFor(key, false)
        cur = 0
        for i = 1, max do
            local ok, _, _, isReady = pcall(GetRuneCooldown, i)
            if ok and isReady then cur = cur + 1 end
        end
    elseif def and def.mode == "pip" then
        cur, max = GetValue(key) or 0, SegmentsFor(key, false)
    else
        cur, max = GetValue(key)
    end
    BuildCondState(cur or 0, max or 0)
    local _, idx = FirstMatch(conds, condState, nil)
    return #conds, src, idx
end

-- 給 /muf debug 用：現在哪幾格是充能格（玩家回報「看不出充能」時最需要的一行）
function ns.ResourceChargedDebug()
    local t = ChargedPoints("ComboPoints", false)
    if not t then return nil end
    local out = {}
    for i = 1, MAX_SEGMENTS do
        if t[i] then out[#out + 1] = i end
    end
    return table.concat(out, ", ")
end

ns.Events.Register("UPDATE_SHAPESHIFT_FORM", "classpower", Reevaluate)
ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "classpower", Reevaluate)
-- ⚠ 符文變動只是「哪一格轉好了」——資源種類、上限、專精、天賦全都沒變。
-- 走 Reevaluate 等於每次符文轉好都重推導一輪候選清單（每個 key 一次 Available()，
-- 含 pcall(IsSpellKnown)，外加整排純 debug 用的字串）並強制重排整列，
-- 而這在戰鬥中每秒來好幾次。要顯示的那件事 UpdateRow 的 rune 分支自己就做完了。
ns.Events.Register("RUNE_POWER_UPDATE", "classpower_rune", function()
    local uf = ns.frames.player
    if not (uf and uf.elements.classpower) then return end
    local edb = uf.db.elements.classpower
    if edb and edb.enabled ~= false then Update(uf, edb, "power") end
end)
-- 天賦換了 → 資源上限與被動都可能變（沒點的天賦 UnitPowerMax 會是 0）
ns.Events.Register("PLAYER_TALENT_UPDATE", "classpower_talent", Reevaluate)
ns.Events.Register("TRAIT_CONFIG_UPDATED", "classpower_trait", Reevaluate)
-- 綁 "player" 走 RegisterUnitEvent：不綁的話是「團隊裡每一個單位的 UNIT_MAXPOWER
-- 都進 Lua，我們才丟掉」。下面 UNIT_AURA 已經是這樣寫，這裡跟上。
ns.Events.Register("UNIT_MAXPOWER", "classpower_maxpower", function(unit)
    if unit == "player" then Reevaluate() end
end, "player")
-- 連擊點的充能狀態（盜賊「超級充能器」）。只有盜賊有這個事件來源，
-- 所以只有盜賊註冊 —— 其他職業連 UNIT_POWER_POINT_CHARGE 都不必進 Lua。
-- 野德的「滿溢之力」走光環，見下面的 UNIT_AURA。
if CLASS == "ROGUE" then
ns.Events.Register("UNIT_POWER_POINT_CHARGE", "classpower_charge", function(unit)
    if unit ~= "player" then return end
    -- 只是「哪幾格變成充能」——資源種類、上限、格數全都沒變 ⇒ 重畫就好，
    -- 不要走 Reevaluate（那會重推導一輪候選清單並強制重排，理由同上面的符文那段）
    chargedDirty = true
    RepaintRows(IsComboRow)
end, "player")
end

-- 光環堆疊型資源（漩渦之武／矛尖／靈魂碎片）沒有 UNIT_POWER 可用，只能吃 UNIT_AURA。
-- UNIT_AURA 在團隊戰是全場最吵的事件之一，所以兩道閘都要：
--   1. 只有「這個職業真的有這種資源」才註冊
--   2. 綁 "player" 走 RegisterUnitEvent，其他單位的光環在 C 端就被擋掉、不進 Lua
--
-- DRUID 在名單裡不是因為它有光環堆疊型資源，而是野性的「滿溢之力」(405189)：
-- 那是連擊點的充能來源，同樣只能從光環讀層數。
local AURA_DRIVEN_CLASSES = { SHAMAN = true, HUNTER = true, DEMONHUNTER = true, DRUID = true }
-- 這個職業的 UNIT_AURA 除了 def.aura/def.cast 之外還要重畫哪一列。
-- ⚠ 只有德魯伊有；其他職業是 nil，而 row.key 一定是字串 ⇒ 比對永遠不成立，
-- 等於零成本（不要寫成 `CLASS == "DRUID" and ...` 塞進迴圈裡每列判斷一次）
local AURA_EXTRA_ROW = (CLASS == "DRUID") and "ComboPoints" or nil
if AURA_DRIVEN_CLASSES[CLASS] then
ns.Events.Register("UNIT_AURA", "classpower_aura", function(unit)
    if unit ~= "player" then return end
    local uf = ns.frames.player
    local edb = uf and uf.db.elements.classpower
    if not (uf and edb and edb.enabled ~= false and uf.elements.classpower) then return end
    for _, row in ipairs(uf.elements.classpower.rows or {}) do
        local def = row.key and RESOURCES[row.key]
        if row:IsShown() and def and (def.aura or def.cast or row.key == AURA_EXTRA_ROW) then
            UpdateRow(row, edb, uf.isPreview)
        end
    end
end, "player")
end

------------------------------------------------------------
-- manabar：型態外魔力小條（DRUID / PRIEST / SHAMAN）
------------------------------------------------------------
if CLASS == "DRUID" or CLASS == "PRIEST" or CLASS == "SHAMAN" then

local MANA = (Enum.PowerType and Enum.PowerType.Mana) or 0

local function Build(uf, edb)
    if not IsPlayerFrame(uf) then return end
    local f = uf.elements.manabar
    if not f then
        f = CreateFrame("Frame", nil, uf, "BackdropTemplate")
        f.ename = "manabar"
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetTexture(Media.WHITE8X8)
        f.bar = CreateFrame("StatusBar", nil, f)
        f.bar:SetAllPoints(f)
        -- 外觀跟資源條的列一致：底色 + 疊在上面的四條 1px 黑邊
        -- （邊建在 bar 上，不然 bar 的填充會蓋掉它，跟資源列同一個坑）
        f.edges = {
            MakeEdge(f.bar, "TOPLEFT", "TOPRIGHT", nil, 1),
            MakeEdge(f.bar, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
            MakeEdge(f.bar, "TOPLEFT", "BOTTOMLEFT", 1, nil),
            MakeEdge(f.bar, "TOPRIGHT", "BOTTOMRIGHT", 1, nil),
        }
        uf.elements.manabar = f
    end
    -- 整條在框體下方，露出的那截也要接 ping，見 ArmPingReceiver
    ns.ArmPingReceiver(uf, f, uf.unitKey == "player" and "player-resource" or "unit")
    -- 設定完全獨立（自己的 x/y/w/h/顏色）。跟資源條一致的只有兩件事：
    --   * 錨點語意：TOPLEFT 對單位框的 BOTTOMLEFT，也就是「掛在框下方、Y 往下為負」
    --   * 外觀：底色 + 四邊 1px 黑邊
    -- 預設值排在資源條「上面一點」，兩條不重疊（見 Core/DB.lua）
    f:SetSize(ns.P.Scale(edb.w or 200), ns.P.Scale(edb.h or 6))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "BOTTOMLEFT", ns.P.Scale(edb.x or 0), ns.P.Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 6)
    f:SetAlpha(edb.alpha or 1)

    f.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
    f.bar:SetFrameLevel(edb.level or 6)
    f.bar:SetReverseFill(ns.FillReversed(edb))
    -- 預設吃全域的「法力藍」，跟能量條的法力同一個顏色
    local c = edb.color or (ns.db.global.colors.power and ns.db.global.colors.power[0])
              or { r = 0.2, g = 0.5, b = 1, a = 1 }
    f.bar:SetStatusBarColor(c.r, c.g, c.b, (c.a or 1) * (edb.barAlpha or 1))
    -- 底色比照資源列：主色的 25%
    f.bg:SetVertexColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, edb.bgAlpha or 0.8)
    for _, e in ipairs(f.edges) do e:SetShown(edb.border ~= false) end
    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.manabar
    if not f then return end
    -- 主資源是法力時不顯示（powertype 已在 cache 消毒為明文）。
    -- 預覽孿生也照玩家「目前」的真實資源型態決定，否則會多出一條現實裡不存在的紫線
    local pt = uf.isPreview and ns.Desecret(UnitPowerType("player"), 0) or (uf.cache.powertype or 0)
    if pt == 0 then
        f:Hide()
        return
    end
    f:Show()
    if uf.isPreview then
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(70)
    else
        f.bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
        f.bar:SetValue(UnitPower("player", MANA))
    end
end

ns.RegisterElement{
    name = "manabar",
    order = 36,
    buckets = { "power", "powertype" },
    build = Build,
    update = Update,
}

end
