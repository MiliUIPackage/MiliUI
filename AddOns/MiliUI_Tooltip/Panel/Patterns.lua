------------------------------------------------------------
-- 語系 pattern：從 GlobalStrings 動態產生，不寫任何語言的字面
--
-- 重繪面板要從 tooltip 的行文字認出「這是耗能／施法時間／冷卻／屬性…」。
-- 那些行沒有型別，只能比對文字；而文字是暴雪拿 GlobalStrings 的格式字串
-- format 出來的 ⇒ 把同一支格式字串反轉成 Lua pattern，三個語系自動成立。
--
--   Patterns.FromGlobal(fmt)     格式字串 → pattern 陣列（|4 單複數展開）＋ capture 順序
--   Patterns.Match(key, text)    _G[key] 存在才編（lazy、cache），回所有 capture（照參數順序）
--   Patterns.Find(field, text)   語意表那一欄的 key 逐一試，回 key, captures...
--   Patterns.Stat(text)          屬性行 → 數值、key、分類（primary／secondary／tertiary／other）
--   Patterns.PowerOf(costKey)    耗能 key → PowerBarColor 的資源名（上色用）
--   Patterns.ColorNumbers(text, hex)   數字上色（跳過跳脫碼；緊接的 % 一起上色）
--   Patterns.StripTextures／StripColors
--
-- 純邏輯：只讀 _G 的字串與 PowerBarColor，不碰任何框。秘密值不准進來——
-- 呼叫端（reader）要先過 S.PlainText，這裡收到的一律當明文。
------------------------------------------------------------
local _, ns = ...

ns.Patterns = {}
local Patterns = ns.Patterns

local _G = _G
local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local strfind, strsub, strgsub, strmatch = string.find, string.sub, string.gsub, string.match
local tconcat, tsort = table.concat, table.sort
local unpack = unpack or table.unpack

------------------------------------------------------------
-- 格式字串 → pattern
------------------------------------------------------------
local function Escape(s)
    return (strgsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- 數字（含千分位與小數點）；%s／%c 非貪婪任意字。
-- ⚠ %.2g／%.1f 也要只吃數字：「冷卻時間%.2g秒」用任意字的話會吞下「冷卻時間尚有：12秒」
local NUMBER_CAPTURE = "([%d,%.]+)"
local ANY_CAPTURE = "(.-)"
local NUMERIC_CONV = { d = true, i = true, u = true, f = true, g = true, G = true, e = true, E = true }

-- 回傳 parts：{ lit = "..." } | { cap = pattern, arg = n } | { plural = { one, many, raw } }
local function Tokenize(fmt)
    local parts, buf = {}, {}
    local function flush()
        if #buf > 0 then
            parts[#parts + 1] = { lit = tconcat(buf) }
            buf = {}
        end
    end
    local i, n, nextArg = 1, #fmt, 0
    while i <= n do
        local c = strsub(fmt, i, i)
        if c == "%" then
            if strsub(fmt, i + 1, i + 1) == "%" then
                buf[#buf + 1] = "%"
                i = i + 2
            else
                -- 位置參數 %1$s
                local j, pos = i + 1, nil
                local _, posEnd, posStr = strfind(fmt, "^(%d+)%$", j)
                if posEnd then
                    pos = tonumber(posStr)
                    j = posEnd + 1
                end
                local _, convEnd, conv = strfind(fmt, "^[%-%+ #0]*%d*%.?%d*([sdifgGeExXcuq])", j)
                if convEnd then
                    flush()
                    nextArg = nextArg + 1
                    parts[#parts + 1] = {
                        cap = NUMERIC_CONV[conv] and NUMBER_CAPTURE or ANY_CAPTURE,
                        arg = pos or nextArg,
                    }
                    i = convEnd + 1
                else
                    -- 不認得的 % ⇒ 當字面
                    buf[#buf + 1] = "%"
                    i = i + 1
                end
            end
        elseif c == "|" and strsub(fmt, i + 1, i + 1) == "4" then
            -- |4單數:複數; —— 遊戲在畫字時才挑。資料裡的字串可能已經挑好（單或複），
            -- 也可能原封不動帶著跳脫碼，三種都要認
            local close = strfind(fmt, ";", i + 2, true)
            local one, many
            if close then
                -- ⚠ 不能寫 `body and strmatch(...)`：and 會把第二個回傳值截掉
                one, many = strmatch(strsub(fmt, i + 2, close - 1), "^(.-):(.*)$")
            end
            if one then
                flush()
                parts[#parts + 1] = { plural = { one, many, strsub(fmt, i, close) } }
                i = close + 1
            else
                buf[#buf + 1] = c
                i = i + 1
            end
        else
            buf[#buf + 1] = c
            i = i + 1
        end
    end
    flush()
    return parts
end

-- 回傳 pattern 陣列與 capture 順序（order[k] = 第 k 個 capture 對應的參數編號）。
-- 有 |4 時展開成「全單數／全複數／原跳脫碼」三條（去重）。
function Patterns.FromGlobal(fmt)
    if type(fmt) ~= "string" then return {}, {} end
    fmt = strmatch(fmt, "^%s*(.-)%s*$")    -- 頭尾空白交給 ^%s*／%s*$
    if fmt == "" then return {}, {} end
    local parts = Tokenize(fmt)
    local order, hasPlural = {}, false
    for _, p in ipairs(parts) do
        if p.cap then order[#order + 1] = p.arg end
        if p.plural then hasPlural = true end
    end
    local list, seen = {}, {}
    for variant = 1, hasPlural and 3 or 1 do
        local out = { "^%s*" }
        for _, p in ipairs(parts) do
            if p.lit then
                out[#out + 1] = Escape(p.lit)
            elseif p.cap then
                out[#out + 1] = p.cap
            else
                out[#out + 1] = Escape(p.plural[variant])
            end
        end
        out[#out + 1] = "%s*$"
        local pat = tconcat(out)
        if not seen[pat] then
            seen[pat] = true
            list[#list + 1] = pat
        end
    end
    return list, order
end

------------------------------------------------------------
-- 編譯快取（key → { pats, order }）；_G 沒這個字串就記 false
------------------------------------------------------------
local compiled = {}

local function Compile(key)
    local c = compiled[key]
    if c == nil then
        local fmt = _G[key]
        if type(fmt) == "string" and fmt ~= "" then
            local pats, order = Patterns.FromGlobal(fmt)
            c = { pats = pats, order = order }
        else
            c = false
        end
        compiled[key] = c
    end
    return c or nil
end

-- 把 capture 照參數編號排回去（%2$s 在 %1$s 前面的語系）
-- 格式沒有任何 conversion 時 strmatch 回的是整段比對字串，不是 capture ⇒ 一律回 true
local function Reorder(order, ...)
    local n = select("#", ...)
    if n == 0 or #order == 0 then return true end
    local caps, maxArg = {}, 0
    for k = 1, n do
        local arg = order[k] or k
        caps[arg] = (select(k, ...))
        if arg > maxArg then maxArg = arg end
    end
    return unpack(caps, 1, maxArg)
end

-- 符合回所有 capture（沒有 capture 的格式回 true）；不符回 nil
function Patterns.Match(key, text)
    if type(text) ~= "string" then return end
    local c = Compile(key)
    if not c then return end
    for _, pat in ipairs(c.pats) do
        if strfind(text, pat) then
            return Reorder(c.order, strmatch(text, pat))
        end
    end
end

-- 純文字標籤（「Use:」「Reagents: |n」）：text 以它開頭就回剩下的部分（去前導空白）。
-- 標籤尾巴的空白與 |n 不算（行文字裡那段可能已經換成真的換行或被修剪掉）
function Patterns.Prefix(key, text)
    local label = _G[key]
    if type(label) ~= "string" or type(text) ~= "string" then return end
    label = strgsub(strgsub(label, "|n", ""), "%s+$", "")
    if label == "" then return end
    if strsub(text, 1, #label) == label then
        local rest = strgsub(strsub(text, #label + 1), "^|n", "")
        return (strgsub(rest, "^%s+", ""))
    end
end

------------------------------------------------------------
-- 語意表：欄位 → GlobalString keys（試的順序就是陣列順序）
--
-- ⚠ 欄位之間的優先順序是 reader 的事：例如 skill 的 ITEM_REQ_SKILL「Requires %s」
--   也吃得下「Requires Level 70」，reader 要先問 level 再問 skill。
------------------------------------------------------------
local function Expand(prefix, suffixes)
    local out = {}
    for i, s in ipairs(suffixes) do out[i] = prefix .. s end
    return out
end

local TIME_UNITS = { "_SEC", "_MIN", "_HOURS", "_DAYS", "_INSTANT" }

local function Concat(...)
    local out = {}
    for i = 1, select("#", ...) do
        for _, k in ipairs((select(i, ...))) do out[#out + 1] = k end
    end
    return out
end

local STATIC = {
    cast = {
        "SPELL_CAST_TIME_SEC", "SPELL_CAST_TIME_MIN", "SPELL_CAST_TIME_INSTANT",
        "SPELL_CAST_TIME_INSTANT_NO_MANA", "SPELL_CAST_CHANNELED", "SPELL_ON_NEXT_SWING",
        "SPELL_CAST_TIME_RANGED",
    },
    -- 冷卻總長：法術的冷卻／充能恢復／蓄能，物品的「(N 秒冷卻時間)」
    cooldown = Concat(
        Expand("SPELL_RECAST_TIME", TIME_UNITS),
        Expand("SPELL_RECAST_TIME_CHARGES", TIME_UNITS),
        Expand("SPELL_RECAST_TIME_CHARGEUP", TIME_UNITS),
        { "ITEM_COOLDOWN_TOTAL_SEC", "ITEM_COOLDOWN_TOTAL_MIN", "ITEM_COOLDOWN_TOTAL_HOURS",
          "ITEM_COOLDOWN_TOTAL_DAYS", "ITEM_COOLDOWN_TOTAL" }),
    -- 剩餘冷卻（物品、法術書裡冷卻中的法術）
    cooldownLeft = {
        "ITEM_COOLDOWN_TIME_SEC", "ITEM_COOLDOWN_TIME_MIN", "ITEM_COOLDOWN_TIME_HOURS",
        "ITEM_COOLDOWN_TIME_DAYS", "ITEM_COOLDOWN_TIME",
    },
    range = { "SPELL_RANGE_DUAL", "SPELL_RANGE", "SPELL_RANGE_AREA", "SPELL_RANGE_UNLIMITED", "MELEE_RANGE" },
    charges = { "SPELL_MAX_CHARGES" },
    -- 法術的「需要 X」（裝備某類武器、某個專精技能）
    requires = { "SPELL_EQUIPPED_ITEM", "SPELL_EQUIPPED_ITEM_NOSPACE" },
    -- 天賦面板：下一等級的標籤
    nextRank = { "TOOLTIP_TALENT_NEXT_RANK" },
    passive = { "SPELL_PASSIVE" },
    talent = { "TOOLTIP_TALENT_RANK" },
    level = { "ITEM_LEVEL_RANGE_CURRENT", "ITEM_LEVEL_RANGE", "ITEM_MIN_LEVEL" },
    skill = { "ITEM_MIN_SKILL", "ITEM_REQ_SKILL" },
    armor = { "ARMOR_TEMPLATE" },
    damage = { "DAMAGE_TEMPLATE" },
    dps = { "DPS_TEMPLATE" },
    speed = { "WEAPON_SPEED" },
    durability = { "DURABILITY_TEMPLATE" },
    setName = { "ITEM_SET_NAME" },
    setBonus = { "ITEM_SET_BONUS_GRAY", "ITEM_SET_BONUS", "ITEM_SET_BONUS_NO_VALID_SPEC" },
    unique = { "ITEM_UNIQUE_MULTIPLE", "ITEM_UNIQUE_EQUIPPABLE", "ITEM_UNIQUE" },
    trigger = { "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONPROC" },
    maker = { "ITEM_CREATED_BY", "ITEM_WRAPPED_BY" },
    equipped = { "CURRENTLY_EQUIPPED" },
    itemLevel = { "ITEM_LEVEL_ALT", "ITEM_LEVEL" },
    upgrade = { "ITEM_UPGRADE_TOOLTIP_FORMAT_STRING", "ITEM_UPGRADE_TOOLTIP_FORMAT" },
    craftQuality = { "PROFESSIONS_CRAFTING_QUALITY" },
    enchant = { "ENCHANTED_TOOLTIP_LINE" },
    -- 綁定沒有型別時（舊資料、別的路徑）用整句比對
    binding = {
        "ITEM_SOULBOUND", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_USE", "ITEM_BIND_QUEST",
        "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT",
        "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND",
    },
    -- 需求類（職業／種族／聲望／專精）：放頁尾、未達成紅
    restriction = { "ITEM_CLASSES_ALLOWED", "ITEM_RACES_ALLOWED", "ITEM_REQ_REPUTATION", "ITEM_REQ_SPECIALIZATION" },
    misc = {
        "ITEM_SOCKET_BONUS", "ITEM_SPELL_KNOWN", "ITEM_STARTS_QUEST", "ITEM_CLASSES_ALLOWED",
        "ITEM_RACES_ALLOWED", "ITEM_REQ_REPUTATION", "ITEM_REQ_SPECIALIZATION", "SELL_PRICE",
    },
}
Patterns.STATIC = STATIC

------------------------------------------------------------
-- 耗能：掃 _G 的 *_COST 系列（每個資源一支，數量會隨改版變）
------------------------------------------------------------
local COST_SUFFIXES = {
    "_COST", "_COST_PER_TIME", "_COST_PER_TIME_NO_BASE",
    "_COST_LARGE", "_COST_LARGE_PER_TIME", "_COST_LARGE_PER_TIME_NO_BASE",
    "_COST_PCT",
}
-- 不是法術耗能的同名字串（訓練師、郵件、修裝、拍賣、確認框…）。
-- POWER_DISPLAY_ 是「%s %s」這種泛用格式，什麼兩個字的行都吃得下，不收。
local COST_EXCLUDE = {
    "TRAINER_", "SEND_MAIL_", "REPAIR_", "BUYOUT_", "SKILL_", "BONUS_ROLL_", "RESEARCH",
    "HOUSING", "CONFIRM_", "BALANCE_", "POWER_DISPLAY_", "ORDER_HALL_", "REAGENT_",
}
Patterns.COST_EXCLUDE = COST_EXCLUDE

local function CostSuffixOf(key)
    -- 最長的後綴先比（_COST_PER_TIME_NO_BASE 不能被 _COST_PER_TIME 吃掉）
    local best
    for _, suf in ipairs(COST_SUFFIXES) do
        if #key > #suf and strsub(key, -#suf) == suf and (not best or #suf > #best) then
            best = suf
        end
    end
    return best
end

local function IsCostKey(key)
    if type(key) ~= "string" or not strfind(key, "^[A-Z_]+$") then return false end
    if not CostSuffixOf(key) then return false end
    for _, prefix in ipairs(COST_EXCLUDE) do
        if strsub(key, 1, #prefix) == prefix then return false end
    end
    return true
end
Patterns.IsCostKey = IsCostKey

-- 依「後綴長的在前、再照字母」排序：同一個資源的每秒版本先試；結果固定，測試可重現
local function SortCostKeys(keys)
    tsort(keys, function(a, b)
        local sa, sb = #CostSuffixOf(a), #CostSuffixOf(b)
        if sa ~= sb then return sa > sb end
        return a < b
    end)
    return keys
end

local scanned = {}

local function ScanCostKeys()
    local keys = {}
    for k, v in pairs(_G) do
        if type(v) == "string" and IsCostKey(k) then keys[#keys + 1] = k end
    end
    return SortCostKeys(keys)
end

function Patterns.Keys(field)
    if field == "cost" then
        scanned.cost = scanned.cost or ScanCostKeys()
        return scanned.cost
    end
    return STATIC[field]
end

-- 回 key, captures...；都不符回 nil
function Patterns.Find(field, text)
    local keys = Patterns.Keys(field)
    if not keys or type(text) ~= "string" then return end
    for _, key in ipairs(keys) do
        local c = Compile(key)
        if c then
            for _, pat in ipairs(c.pats) do
                if strfind(text, pat) then
                    return key, Reorder(c.order, strmatch(text, pat))
                end
            end
        end
    end
end

-- 耗能 key → PowerBarColor 的資源名：去掉後綴，查不到就從前面一節一節剝
-- （BLUE_ESSENCE → ESSENCE）。PowerBarColor 不存在（測試環境）就回剝完後綴的名字。
function Patterns.PowerOf(key)
    local suf = type(key) == "string" and CostSuffixOf(key)
    if not suf then return end
    local name = strsub(key, 1, #key - #suf)
    local colors = _G.PowerBarColor
    if type(colors) ~= "table" then return name end
    local probe = name
    while probe and probe ~= "" do
        if colors[probe] then return probe end
        probe = strmatch(probe, "^[^_]+_(.+)$")
    end
end

------------------------------------------------------------
-- 屬性
------------------------------------------------------------
local PRIMARY = { STRENGTH = true, AGILITY = true, INTELLECT = true, STAMINA = true }
local SECONDARY = { CRIT_RATING = true, HASTE_RATING = true, MASTERY_RATING = true, VERSATILITY = true }
local TERTIARY = { CR_LIFESTEAL = true, CR_AVOIDANCE = true, CR_SPEED = true, CR_STURDINESS = true }
local CATEGORY_RANK = { primary = 1, secondary = 2, tertiary = 3, other = 4 }

-- ITEM_MOD_X_SHORT → "X"
local function StatCore(key)
    return strmatch(key, "^ITEM_MOD_(.+)_SHORT$") or strmatch(key, "^ITEM_MOD_(.+)$")
end

function Patterns.StatCategory(key)
    local core = type(key) == "string" and StatCore(key)
    if not core then return "other" end
    if PRIMARY[core] then return "primary" end
    -- 組合主屬性（AGILITY_OR_INTELLECT…）：每一節都是主屬性才算
    if strfind(core, "_OR_", 1, true) then
        local all = true
        for part in (core .. "_OR_"):gmatch("(.-)_OR_") do
            if not PRIMARY[part] then all = false end
        end
        if all then return "primary" end
    end
    if SECONDARY[core] then return "secondary" end
    if TERTIARY[core] then return "tertiary" end
    return "other"
end

-- 名字 → key。不同 key 撞同一個字（同義的舊屬性）時，分類排前面的贏、同分照字母
local function BuildStatNames()
    local map = {}
    local function consider(key, name)
        if type(name) ~= "string" or name == "" then return end
        local cur = map[name]
        if cur then
            local a, b = CATEGORY_RANK[Patterns.StatCategory(key)], CATEGORY_RANK[Patterns.StatCategory(cur)]
            if a > b or (a == b and key > cur) then return end
        end
        map[name] = key
    end
    for k, v in pairs(_G) do
        if type(k) == "string" and strfind(k, "^ITEM_MOD_.+_SHORT$") then consider(k, v) end
    end
    consider("ITEM_MOD_VERSATILITY", _G.ITEM_MOD_VERSATILITY)
    return map
end

-- 「+150 力量」→ 150, "ITEM_MOD_STRENGTH_SHORT", "primary"
function Patterns.Stat(text)
    if type(text) ~= "string" then return end
    local plain = Patterns.StripColors(text)
    local value, name = strmatch(plain, "^%s*%+%s*([%d,%.]+)%%?%s*(.-)%s*$")
    if not value then return end
    scanned.stats = scanned.stats or BuildStatNames()
    local key = scanned.stats[name]
    if not key then return end
    return value, key, Patterns.StatCategory(key)
end

------------------------------------------------------------
-- 文字工具
------------------------------------------------------------
function Patterns.StripTextures(text)
    if type(text) ~= "string" then return text end
    text = strgsub(text, "|T.-|t", "")
    text = strgsub(text, "|A.-|a", "")
    return (strgsub(text, "^%s+", ""))
end

function Patterns.StripColors(text)
    if type(text) ~= "string" then return text end
    text = strgsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = strgsub(text, "|cn[^:]*:", "")   -- 12.x 的具名色 |cnRED_FONT_COLOR:…|r
    return (strgsub(text, "|r", ""))
end

-- 遊戲自己的跳脫碼：裡面的數字（色碼、圖示尺寸、|4 單複數）不准上色
local ESCAPES = {
    "|c%x%x%x%x%x%x%x%x", "|cn[^:]*:", "|r", "|T.-|t", "|A.-|a", "|H.-|h", "|K.-|k", "|4[^;]*;", "|n",
}

-- 「1 |4hour:hrs;」的單複數看前面的數字；數字一上色兩者就分開了 ⇒ 先挑好
local function ResolvePlurals(text)
    return (strgsub(text, "(%d+)(%s*)|4([^:;]*):([^;]*);", function(number, space, one, many)
        return number .. space .. (tonumber(number) == 1 and one or many)
    end))
end

local function ColorPlain(text, hex)
    -- 數字要在詞首（x2 不動）；句尾的句點留在色碼外；緊接的 % 一起上色
    return (strgsub(text, "%f[%w](%d+%.?%d*%%?)", function(number)
        local trailing = ""
        if strsub(number, -1) == "." then number, trailing = strsub(number, 1, -2), "." end
        return "|cff" .. hex .. number .. "|r" .. trailing
    end))
end

function Patterns.ColorNumbers(text, hex)
    if type(text) ~= "string" or type(hex) ~= "string" or hex == "" then return text end
    text = ResolvePlurals(text)
    local out, plainStart, pos = {}, 1, 1
    while true do
        local bar = strfind(text, "|", pos, true)
        if not bar then break end
        local escapeEnd
        for _, pattern in ipairs(ESCAPES) do
            local _, stop = strfind(text, "^" .. pattern, bar)
            if stop then escapeEnd = stop break end
        end
        -- 不認得的跳脫碼至少保護它的第一個字
        escapeEnd = escapeEnd or math.min(bar + 1, #text)
        out[#out + 1] = ColorPlain(strsub(text, plainStart, bar - 1), hex)
        out[#out + 1] = strsub(text, bar, escapeEnd)
        plainStart, pos = escapeEnd + 1, escapeEnd + 1
    end
    out[#out + 1] = ColorPlain(strsub(text, plainStart), hex)
    return tconcat(out)
end

-- 測試／換語系用：清掉所有快取
function Patterns.Reset()
    compiled = {}
    scanned = {}
end
