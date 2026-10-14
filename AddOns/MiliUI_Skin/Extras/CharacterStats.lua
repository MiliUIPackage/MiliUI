------------------------------------------------------------
-- 自建功能：角色面板的屬性清單（取代暴雪右側的屬性欄）
--
-- 做法照 EllesmereUI 的角色面板（EllesmereUIBlizzardSkin_CharacterSheet.lua 的
-- stock 樣式：清單是 `CharacterStatsPane` 的子框、停在 InsetRight 那一格，暴雪
-- 自己的側邊欄分頁 Show/Hide 那個 pane 就帶著它顯隱）；樣式套這包的 Tokens。
--
-- 分區（key ＝ `db.extras.statsOrder`／`statsCollapsed` 裡的 sectionKey）：
--   itemlevel   物品等級（永遠第一、不能收合、沒有箭頭；顏色轉交 GetItemLevelColor）
--   attributes  屬性：主屬性（依專精）、耐力、生命、法力（有法力的才列）
--   secondary   次要屬性：致命一擊、加速、精通、臨機應變
--   tertiary    第三屬性：汲取、迴避、速度
--   attack      攻擊：法術強度（主屬性是智力）或攻擊強度、攻擊速度
--   defense     防禦：護甲、閃躲、招架、格擋、醉拳
-- 每一區一個顏色（`T.statCategory[sectionKey]`），可收合、可用標題兩端的箭頭排序，
-- 百分比一律顯示到小數第二位（暴雪的屬性欄是 `%d%%` 四捨五入）。
--
-- 計算照暴雪自己的 `PaperDollFrame_Set*`（Blizzard_UIPanels_Game/Mainline/
-- PaperDollFrame.lua，12.1 live）：哪一種爆擊、哪一種加速、法術強度取哪幾個法術系、
-- 攻擊強度遠程／近戰與「以法術強度換算」那條分支，全部照抄它的挑法；顯示條件照
-- `PAPERDOLL_STATCATEGORIES`（:246）的 roles／hideAt／showFunc。
-- tooltip 的說明行用暴雪自己組 `statFrame.tooltip2` 的那些全域格式字串
-- （CR_*_TOOLTIP、STAT_*_TOOLTIP…）⇒ 語系免費、跟暴雪原本的說明一字不差。
--
-- ## 刻意沒做
--
-- * EllesmereUI 的「紋章」與「PvP」兩區 —— 紋章的通貨代碼每季都變（套組另有每季
--   維護的清單，不想再多一份會過期的表）；PvP 那區跟角色屬性無關。
-- * 移動速度（暴雪屬性欄的 MOVESPEED）—— 暴雪自己也沒放進 PAPERDOLL_STATCATEGORIES。
-- * 自訂分區顏色、隱藏整區 —— EllesmereUI 有，這包先不開設定。
-- * 把暴雪的 pane 停到螢幕外（EllesmereUI 的 `CharSheetParkStatsPane`，SetPoint 到
--   y=-10000）—— 那是重排暴雪框，我們不做；改成整個 pane alpha 0（下表）。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | CharacterStatsPane | `Engine.Neutralize`（SetAlpha 0）—— 暴雪的 UpdateStats 照跑、沒人看得到 |
-- | CharacterStatsPane | 當我們宿主框的 parent（CreateFrame 的 parent 參數）＋ SetAllPoints 的錨點 |
-- | CharacterStatsPane | `GetFrameLevel()`（`Engine.TargetLevel`，三道守衛）—— 宿主框的層級 ＝ 它 +5 |
-- | GameTooltip | SetOwner／SetText／AddLine／Show／Hide（全套組共用的提示框，一般用法） |
--
-- 寫入暴雪欄位：無。hook：無（Show/Hide 跟著 parent 走，用的是**自己框**的 OnShow/OnHide）。
-- 讀暴雪物件：只有上面那一個 GetFrameLevel。其餘全部是讀 API（UnitStat、GetCombatRating…）。
--
-- 宿主框 `SetIgnoreParentAlpha(true)`：pane 是 alpha 0，不忽略就跟著看不見。
-- 代價：別的插件對 CharacterFrame 整體做淡入淡出時，這一塊不會跟著淡。
-- 宿主框 `EnableMouse(true)`：暴雪那些 alpha 0 的屬性列**還在收滑鼠**（OnEnter 會跳
-- 暴雪的 tooltip），我們的框蓋在上面把它們擋掉。
--
-- ## 12.1 秘密值
--
-- 每個讀值都過 `X.Num`（Extras/Common.lua）：秘密值或不是數字 ⇒ 整格收手、顯示「—」、
-- 不給 tooltip。秘密值從不拿來比較、算術、當 key。戰鬥中 `UnitHealthMax` 這類可能是
-- 秘密值（.claude/notes/wow-121-unit-api-secrets.md）。
-- 物品等級的顏色（`GetItemLevelColor()`）只原封不動交給 SetTextColor／SetVertexColor
-- （傳遞者規則）。
------------------------------------------------------------
local _, ns = ...

local X = ns.Extras
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

local Num, Try = X.Num, X.Try

-- 版面（框架單位）。照 EllesmereUI：標題 16 高、列從標題下 22 開始、列高 16、區間距 6。
local TITLE_H     = 16
local TITLE_GAP   = 6
local ROW_H       = 16
local SECTION_GAP = 8
local ILVL_ROW_H  = 26
local ARROW       = 12
local RULE_GAP    = 6     -- 線與字／箭頭之間
local PAD         = 6     -- 宿主框的內距（左右上下）

local FONT_TITLE = 12
local FONT_ROW   = 11
local FONT_ILVL  = 20

local DASH = "—"

local STR, AGI, STA, INT = 1, 2, 3, 4   -- LE_UNIT_STAT_*

-- 可排序的五區預設順序（物品等級不在裡面：永遠第一）
local DEFAULT_ORDER = { "attributes", "secondary", "tertiary", "attack", "defense" }

local function G(name, fallback)
    local v = _G[name]
    if type(v) == "string" then return v end
    return fallback
end

local function Big(n)
    return BreakUpLargeNumbers(n)
end

local function Round(n)
    return math.floor(n + 0.5)
end

------------------------------------------------------------
-- 專精脈絡：主屬性、是不是坦克、有沒有法力、有沒有盾。每次重算一次，傳給每一列。
------------------------------------------------------------
local lastHasMana = false

local function BuildContext()
    local ctx = {}
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    spec = S.PlainNumber(spec)
    if spec and spec > 0 then
        ctx.spec = spec
        local ok, primary = pcall(function()
            return select(6, C_SpecializationInfo.GetSpecializationInfo(spec, false, false, nil, UnitSex("player")))
        end)
        ctx.primary = ok and S.PlainNumber(primary) or nil
        if GetSpecializationRoleEnum and Enum and Enum.LFGRole then
            local role = GetSpecializationRoleEnum(spec)
            ctx.tank = S.PlainNumber(role) == Enum.LFGRole.Tank
        end
    end
    -- 還沒有專精（低等級）：三個主屬性挑最高的那個，挑不出來（秘密值）就當力量
    if not ctx.primary then
        local best, bestV = STR, -1
        for _, i in ipairs({ STR, AGI, INT }) do
            local v = S.PlainNumber(select(2, UnitStat("player", i)))
            if v and v > bestV then best, bestV = i, v end
        end
        ctx.primary = best
    end
    -- 法力：秘密值就沿用上一次的判斷（職業有沒有法力不會在戰鬥中變）
    local mana = Enum and Enum.PowerType and S.PlainNumber(UnitPowerMax("player", Enum.PowerType.Mana))
    if mana then lastHasMana = mana > 0 end
    ctx.hasMana = lastHasMana
    ctx.hasShield = C_PaperDollInfo and C_PaperDollInfo.OffhandHasShield
        and S.ToBool(C_PaperDollInfo.OffhandHasShield()) == true or false
    ctx.showRating = ns.db and ns.db.extras and ns.db.extras.statsShowRating == true
    return ctx
end

------------------------------------------------------------
-- 暴雪的計算（照 PaperDollFrame.lua 原樣搬過來，數字一律先過 Num）
------------------------------------------------------------

-- PaperDollFrame.lua:1008 `GetSecondaryBonus`（local，搬一份）
local function SecondaryBonus(rating, base, coeff)
    if PlayerIsTimerunning and PlayerIsTimerunning() then
        return base
    end
    return Num(GetCombatRatingBonus(rating)) * (coeff or 1)
end

-- PaperDollFrame.lua:1020 `PaperDollFrame_SetCritChance`：法術系（2..MAX_SPELL_SCHOOLS 取最小）、
-- 遠程、近戰三者取最大，評等跟著挑中的那一種走
local function CritInfo()
    local holy = 2
    local spell = Num(GetSpellCritChance(holy))
    for i = holy + 1, MAX_SPELL_SCHOOLS or 7 do
        spell = math.min(spell, Num(GetSpellCritChance(i)))
    end
    local ranged = Num(GetRangedCritChance())
    local melee = Num(GetCritChance())
    if spell >= ranged and spell >= melee then
        return spell, CR_CRIT_SPELL
    elseif ranged >= melee then
        return ranged, CR_CRIT_RANGED
    end
    return melee, CR_CRIT_MELEE
end

-- PaperDollFrame.lua:972 `PaperDollFrame_SetSpellPower`：法術系 2..MAX 取最小
local function SpellPower()
    local holy = 2
    local v = Num(GetSpellBonusDamage(holy))
    for i = holy + 1, MAX_SPELL_SCHOOLS or 7 do
        v = math.min(v, Num(GetSpellBonusDamage(i)))
    end
    return v
end

-- PaperDollFrame.lua:927 `PaperDollFrame_SetAttackPower`
-- 回傳：顯示值、base、posBuff、negBuff、tooltip 用的說明
local function AttackPowerInfo()
    local ranged = IsRangedWeapon and IsRangedWeapon()
    local base, pos, neg, tip
    if ranged then
        base, pos, neg = UnitRangedAttackPower("player")
        tip = G("RANGED_ATTACK_POWER_TOOLTIP")
    else
        base, pos, neg = UnitAttackPower("player")
        tip = G("MELEE_ATTACK_POWER_TOOLTIP")
    end
    base, pos, neg = Num(base), Num(pos), Num(neg)
    local magic = ATTACK_POWER_MAGIC_NUMBER or 3.5
    local damageBonus = Big(math.max(base + pos + neg, 0) / magic)
    local value
    local overrideBySP = Num(GetOverrideAPBySpellPower and GetOverrideAPBySpellPower() or 0)
    if overrideBySP > 0 then
        local sp = SpellPower()
        sp = math.min(sp, Num(GetSpellBonusHealing())) * overrideBySP
        value = sp
        pos, neg = 0, 0
        base = sp
        damageBonus = Big(sp / magic)
    else
        value = math.max(0, base + pos + neg)
    end
    local effectiveAP = math.max(0, base + pos + neg)
    local spByAP = Num(GetOverrideSpellPowerByAP and GetOverrideSpellPowerByAP() or 0)
    local line
    if spByAP > 0 then
        line = format(G("MELEE_ATTACK_POWER_SPELL_POWER_TOOLTIP", "%s %s"), damageBonus, Big(effectiveAP * spByAP + 0.5))
    elseif tip then
        line = format(tip, damageBonus)
    end
    return value, base, pos, neg, line
end

-- 「基礎 ＋ 加成」那一行（照 PaperDollFrame.lua:621 `_SetStat` 的組法）
local function BuffLine(base, pos, neg)
    if pos == 0 and neg == 0 then return nil end
    local s = HIGHLIGHT_FONT_COLOR_CODE .. "(" .. Big(base) .. FONT_COLOR_CODE_CLOSE
    if pos > 0 then
        s = s .. GREEN_FONT_COLOR_CODE .. "+" .. Big(pos) .. FONT_COLOR_CODE_CLOSE
    end
    if neg < 0 then
        s = s .. RED_FONT_COLOR_CODE .. " " .. Big(neg) .. FONT_COLOR_CODE_CLOSE
    end
    return s .. HIGHLIGHT_FONT_COLOR_CODE .. ")" .. FONT_COLOR_CODE_CLOSE
end

-- PaperDollFrame.lua:603 `PaperDollFrame_SetStat` 的 tooltip2（主屬性與耐力）
local function StatTooltip(statIndex, effective, ctx)
    local tip = G("DEFAULT_STAT" .. statIndex .. "_TOOLTIP")
    local primary = ctx.primary
    local noBenefit = G("STAT_NO_BENEFIT_TOOLTIP")
    local apsp = HasAPEffectsSpellPower and HasAPEffectsSpellPower()
    if statIndex == STR then
        local ap = Num(GetAttackPowerForStat(statIndex, effective))
        if apsp then tip = G("STAT_TOOLTIP_BONUS_AP_SP") end
        if primary == STR then
            tip = tip and format(tip, Big(ap))
            if ctx.tank then
                local parry = Num(GetParryChanceFromAttribute())
                if parry > 0 then
                    tip = (tip or "") .. "|n|n" .. format(G("CR_PARRY_BASE_STAT_TOOLTIP", "%.2f"), parry)
                end
            end
        else
            tip = noBenefit
        end
    elseif statIndex == AGI then
        if primary == AGI then
            tip = apsp and G("STAT_TOOLTIP_BONUS_AP_SP") or G("STAT_TOOLTIP_BONUS_AP")
            if ctx.tank then
                local dodge = Num(GetDodgeChanceFromAttribute())
                if dodge > 0 then
                    tip = (tip or "") .. "|n|n" .. format(G("CR_DODGE_BASE_STAT_TOOLTIP", "%.2f"), dodge)
                end
            end
        else
            tip = noBenefit
        end
    elseif statIndex == STA then
        local hp = effective * Num(UnitHPPerStamina("player")) * Num(GetUnitMaxHealthModifier("player"))
        tip = tip and format(tip, Big(hp))
    elseif statIndex == INT then
        if apsp then
            tip = noBenefit
        elseif HasSPEffectsAttackPower and HasSPEffectsAttackPower() then
            tip = G("STAT_TOOLTIP_BONUS_AP_SP")
        elseif primary == INT then
            tip = tip and format(tip, math.max(0, effective))
        else
            tip = noBenefit
        end
    end
    return tip
end

local function StatName(i)
    local fallback = ({ "Strength", "Agility", "Stamina", "Intellect" })[i]
    return G("SPELL_STAT" .. i .. "_NAME", fallback)
end

-- 評等：`(N)`，N 走 BreakUpLargeNumbers
local function RatingText(cr)
    return Big(Round(Num(GetCombatRating(cr))))
end

local function ArmorReduction(armor)
    return Num(C_PaperDollInfo.GetArmorEffectiveness(armor, Num(UnitEffectiveLevel("player")))) * 100
end

local function ArmorReductionTarget(armor)
    local v = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget and C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(armor)
    if v == nil then return nil end
    return Num(v) * 100
end

------------------------------------------------------------
-- 列的定義
--
-- 每一列：
--   label(ctx)      標籤（字串或函式）
--   get(ctx)        回傳要顯示的數字（之後的回傳值給 tip 用），秘密值在 Num 就收手
--   kind            "pct"（%.2f%%）、"int"（BreakUpLargeNumbers）、"dec"（%.2f）、"speed"
--   rating          評等的 CR_* 常數或函式（statsShowRating 開著才顯示）
--   hideZero        值等於 0 就不列（暴雪的 hideAt = 0）
--   show(ctx)       顯示條件（暴雪的 roles／showFunc）
--   tip(ctx, ...)   回傳 tooltip 的說明行陣列（get 的全部回傳值照順序傳進來）
------------------------------------------------------------
local function PrimaryDef()
    return {
        key = "primary",
        label = function(ctx) return StatName(ctx.primary) end,
        kind = "int",
        get = function(ctx)
            local stat, eff, pos, neg = UnitStat("player", ctx.primary)
            return Num(eff), Num(stat), Num(pos), Num(neg)
        end,
        tip = function(ctx, eff, stat, pos, neg)
            return { BuffLine(stat - pos - neg, pos, neg), StatTooltip(ctx.primary, eff, ctx) }
        end,
    }
end

local SECTIONS = {
    {
        key = "itemlevel",
        title = function() return G("STAT_AVERAGE_ITEM_LEVEL", "Item Level") end,
        fixed = true,
        defs = {
            {
                key = "ilvl",
                kind = "dec",
                big = true,
                show = function()
                    local lvl = S.PlainNumber(UnitLevel("player"))
                    return not lvl or lvl >= (MIN_PLAYER_LEVEL_FOR_ITEM_LEVEL_DISPLAY or 10)
                end,
                label = function() return G("STAT_AVERAGE_ITEM_LEVEL", "Item Level") end,
                get = function()
                    local avg, equipped, pvp = GetAverageItemLevel()
                    return Num(equipped), Num(avg), Num(pvp)
                end,
                -- PaperDollFrame.lua:1293 `PaperDollFrame_SetItemLevel`
                tip = function(_, equipped, avg, pvp)
                    local lines = {}
                    if math.floor(equipped) ~= math.floor(avg) then
                        lines[#lines + 1] = HIGHLIGHT_FONT_COLOR_CODE .. G("STAT_AVERAGE_ITEM_LEVEL", "") .. " "
                            .. math.floor(avg) .. FONT_COLOR_CODE_CLOSE
                    end
                    local tip = G("STAT_AVERAGE_ITEM_LEVEL_TOOLTIP")
                    if math.floor(avg) ~= math.floor(pvp) and G("STAT_AVERAGE_PVP_ITEM_LEVEL") then
                        tip = (tip or "") .. "\n\n" .. G("STAT_AVERAGE_PVP_ITEM_LEVEL"):format(pvp)
                    end
                    lines[#lines + 1] = tip
                    return lines
                end,
            },
        },
    },
    {
        key = "attributes",
        title = function() return G("STAT_CATEGORY_ATTRIBUTES", "Attributes") end,
        defs = {
            PrimaryDef(),
            {
                key = "stamina",
                label = function() return StatName(STA) end,
                kind = "int",
                get = function()
                    local stat, eff, pos, neg = UnitStat("player", STA)
                    return Num(eff), Num(stat), Num(pos), Num(neg)
                end,
                tip = function(ctx, eff, stat, pos, neg)
                    return { BuffLine(stat - pos - neg, pos, neg), StatTooltip(STA, eff, ctx) }
                end,
            },
            {
                key = "health",
                label = function() return G("HEALTH", "Health") end,
                kind = "int",
                get = function() return Num(UnitHealthMax("player")) end,
                tip = function() return { G("STAT_HEALTH_TOOLTIP") } end,
            },
            {
                key = "mana",
                label = function() return G("MANA", "Mana") end,
                kind = "int",
                show = function(ctx) return ctx.hasMana end,
                get = function() return Num(UnitPowerMax("player", Enum.PowerType.Mana)) end,
                tip = function() return { G("STAT_MANA_TOOLTIP") } end,
            },
        },
    },
    {
        key = "secondary",
        title = function() return L["Secondary Stats"] end,
        defs = {
            {
                key = "crit",
                label = function() return G("STAT_CRITICAL_STRIKE", "Critical Strike") end,
                kind = "pct",
                hideZero = true,
                rating = function() return select(2, CritInfo()) end,
                get = function() return CritInfo() end,
                -- PaperDollFrame.lua:1056
                tip = function(_, chance, cr)
                    local rating = Num(GetCombatRating(cr))
                    local extra = SecondaryBonus(cr, chance)
                    if GetCritChanceProvidesParryEffect and GetCritChanceProvidesParryEffect() then
                        return { format(CR_CRIT_PARRY_RATING_TOOLTIP, Big(rating), extra,
                            Num(GetCombatRatingBonusForCombatRatingValue(CR_PARRY, rating))) }
                    end
                    return { format(CR_CRIT_TOOLTIP, Big(rating), extra) }
                end,
            },
            {
                key = "haste",
                label = function() return G("STAT_HASTE", "Haste") end,
                kind = "pct",
                hideZero = true,
                rating = function() return CR_HASTE_MELEE end,
                get = function() return Num(GetHaste()) end,
                -- PaperDollFrame.lua:1129
                tip = function(_, haste)
                    local cls = S.PlainText(select(2, UnitClass("player")))
                    local line = (cls and G("STAT_HASTE_" .. cls .. "_TOOLTIP")) or G("STAT_HASTE_TOOLTIP", "")
                    line = line .. format(STAT_HASTE_BASE_TOOLTIP, Big(Num(GetCombatRating(CR_HASTE_MELEE))),
                        SecondaryBonus(CR_HASTE_MELEE, haste))
                    return { line }
                end,
            },
            {
                key = "mastery",
                label = function() return G("STAT_MASTERY", "Mastery") end,
                kind = "pct",
                hideZero = true,
                rating = function() return CR_MASTERY end,
                get = function()
                    local mastery, coeff = GetMasteryEffect()
                    return Num(mastery), coeff
                end,
                -- PaperDollFrame.lua:1185 `Mastery_OnEnter`：精通法術的說明 ＋ 評等那一行
                tip = function(ctx, mastery, coeff)
                    local lines = {}
                    if ctx.spec and C_SpecializationInfo.GetSpecializationMasterySpells then
                        for _, id in ipairs(C_SpecializationInfo.GetSpecializationMasterySpells(ctx.spec) or {}) do
                            local name = S.PlainText(C_Spell.GetSpellName(id))
                            local desc = S.PlainText(C_Spell.GetSpellDescription(id))
                            if name then lines[#lines + 1] = HIGHLIGHT_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE end
                            if desc and desc ~= "" then lines[#lines + 1] = desc end
                        end
                    end
                    lines[#lines + 1] = format(STAT_MASTERY_TOOLTIP, Big(Num(GetCombatRating(CR_MASTERY))),
                        SecondaryBonus(CR_MASTERY, mastery, S.PlainNumber(coeff)))
                    return lines
                end,
            },
            {
                key = "versatility",
                label = function() return G("STAT_VERSATILITY", "Versatility") end,
                kind = "pct",
                hideZero = true,
                rating = function() return CR_VERSATILITY_DAMAGE_DONE end,
                -- PaperDollFrame.lua:1276：傷害加成 ＝ 評等加成 ＋ 臨機應變的固定加成
                get = function()
                    return Num(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE))
                        + Num(GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
                end,
                tip = function(_, dmg)
                    local taken = Num(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN))
                        + Num(GetVersatilityBonus(CR_VERSATILITY_DAMAGE_TAKEN))
                    local rating = Num(GetCombatRating(CR_VERSATILITY_DAMAGE_DONE))
                    return { format(CR_VERSATILITY_TOOLTIP, dmg, taken, Big(rating), dmg, taken) }
                end,
            },
        },
    },
    {
        key = "tertiary",
        title = function() return L["Tertiary Stats"] end,
        defs = {
            -- PaperDollFrame.lua:1229-1274：GetLifesteal／GetAvoidance／GetSpeed 是總百分比
            -- （含天賦／種族），CR 那三支只算評等
            {
                key = "lifesteal",
                label = function() return G("STAT_LIFESTEAL", "Leech") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_LIFESTEAL end,
                get = function() return Num(GetLifesteal()) end,
                tip = function()
                    return { format(CR_LIFESTEAL_TOOLTIP, Big(Num(GetCombatRating(CR_LIFESTEAL))), Num(GetCombatRatingBonus(CR_LIFESTEAL))) }
                end,
            },
            {
                key = "avoidance",
                label = function() return G("STAT_AVOIDANCE", "Avoidance") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_AVOIDANCE end,
                get = function() return Num(GetAvoidance()) end,
                tip = function()
                    return { format(CR_AVOIDANCE_TOOLTIP, Big(Num(GetCombatRating(CR_AVOIDANCE))), Num(GetCombatRatingBonus(CR_AVOIDANCE))) }
                end,
            },
            {
                key = "speed",
                label = function() return G("STAT_SPEED", "Speed") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_SPEED end,
                get = function() return Num(GetSpeed()) end,
                tip = function()
                    return { format(CR_SPEED_TOOLTIP, Big(Num(GetCombatRating(CR_SPEED))), Num(GetCombatRatingBonus(CR_SPEED))) }
                end,
            },
        },
    },
    {
        key = "attack",
        title = function() return G("STAT_CATEGORY_ATTACK", "Attack") end,
        defs = {
            {
                key = "power",
                -- 主屬性是智力 ⇒ 法術強度（PaperDollFrame.lua:972），否則攻擊強度（:927）
                label = function(ctx)
                    if ctx.primary == INT then return G("STAT_SPELLPOWER", "Spell Power") end
                    return G("STAT_ATTACK_POWER", "Attack Power")
                end,
                kind = "int",
                get = function(ctx)
                    if ctx.primary == INT then return SpellPower() end
                    return AttackPowerInfo()
                end,
                tip = function(ctx, _, base, pos, neg, line)
                    if ctx.primary == INT then return { G("STAT_SPELLPOWER_TOOLTIP") } end
                    return { BuffLine(base, pos, neg), line }
                end,
            },
            {
                key = "attackspeed",
                label = function() return G("WEAPON_SPEED", "Attack Speed") end,
                kind = "speed",
                -- PaperDollFrame.lua:908：主手（有副手就「主 / 副」）
                get = function()
                    local main, off = UnitAttackSpeed("player")
                    return Num(main), off ~= nil and Num(off) or nil
                end,
                tip = function()
                    return { format(STAT_ATTACK_SPEED_BASE_TOOLTIP, Big(Num(GetMeleeHaste()))) }
                end,
            },
        },
    },
    {
        key = "defense",
        title = function() return G("STAT_CATEGORY_DEFENSE", "Defense") end,
        defs = {
            {
                key = "armor",
                label = function() return G("STAT_ARMOR", "Armor") end,
                kind = "int",
                get = function()
                    local _, effective = UnitArmor("player")
                    return Num(effective)
                end,
                -- PaperDollFrame.lua:706
                tip = function(_, armor)
                    local lines = { format(STAT_ARMOR_TOOLTIP, ArmorReduction(armor)) }
                    local vsTarget = ArmorReductionTarget(armor)
                    if vsTarget then lines[#lines + 1] = format(STAT_ARMOR_TARGET_TOOLTIP, vsTarget) end
                    return lines
                end,
            },
            {
                key = "dodge",
                label = function() return G("STAT_DODGE", "Dodge") end,
                kind = "pct",
                rating = function() return CR_DODGE end,
                show = function(ctx) return ctx.tank end,
                get = function() return Num(GetDodgeChance()) end,
                tip = function()
                    return { format(CR_DODGE_TOOLTIP, Num(GetCombatRating(CR_DODGE)), Num(GetCombatRatingBonus(CR_DODGE))) }
                end,
            },
            {
                key = "parry",
                label = function() return G("STAT_PARRY", "Parry") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_PARRY end,
                show = function(ctx) return ctx.tank end,
                get = function() return Num(GetParryChance()) end,
                tip = function()
                    return { format(CR_PARRY_TOOLTIP, Num(GetCombatRating(CR_PARRY)), Num(GetCombatRatingBonus(CR_PARRY))) }
                end,
            },
            {
                key = "block",
                label = function() return G("STAT_BLOCK", "Block") end,
                kind = "pct", hideZero = true,
                show = function(ctx) return ctx.hasShield end,
                get = function() return Num(GetBlockChance()) end,
                -- PaperDollFrame.lua:750
                tip = function()
                    local shield = Num(GetShieldBlock())
                    local lines = { CR_BLOCK_TOOLTIP:format(ArmorReduction(shield)) }
                    local vsTarget = ArmorReductionTarget(shield)
                    if vsTarget then lines[#lines + 1] = format(STAT_BLOCK_TARGET_TOOLTIP, vsTarget) end
                    return lines
                end,
            },
            {
                key = "stagger",
                label = function() return G("STAT_STAGGER", "Stagger") end,
                kind = "pct", hideZero = true,
                show = function(ctx) return ctx.tank end,
                get = function()
                    local stagger, vsTarget = C_PaperDollInfo.GetStaggerPercentage("player")
                    return Num(stagger), vsTarget
                end,
                -- PaperDollFrame.lua:722
                tip = function(_, stagger, vsTarget)
                    local lines = { format(STAT_STAGGER_TOOLTIP, stagger) }
                    vsTarget = S.PlainNumber(vsTarget)
                    if vsTarget then lines[#lines + 1] = format(STAT_STAGGER_TARGET_TOOLTIP, vsTarget) end
                    return lines
                end,
            },
        },
    },
}

local SECTION_BY_KEY = {}
for _, sec in ipairs(SECTIONS) do SECTION_BY_KEY[sec.key] = sec end

------------------------------------------------------------
-- 文字格式
------------------------------------------------------------
local function FormatValue(def, ctx, v, v2)
    local kind = def.kind
    local text
    if kind == "pct" then
        text = format("%.2f%%", v)
    elseif kind == "dec" then
        text = format("%.2f", v)
    elseif kind == "speed" then
        text = format("%.2f", v)
        if v2 then text = text .. " / " .. format("%.2f", v2) end
    else
        text = Big(Round(v))
    end
    if ctx.showRating and def.rating then
        -- 評等讀不到（秘密值）就只少括號那一段，百分比照樣顯示
        local ok, r = pcall(function() return RatingText(def.rating(ctx)) end)
        if ok and r then text = text .. " (" .. r .. ")" end
    end
    return text
end

------------------------------------------------------------
-- 狀態與 UI
------------------------------------------------------------
local host, scroll
local built = {}         -- sectionKey → { header, title, ruleL, ruleR, up, down, rows = {} }
local ctx                -- 最後一次 BuildContext 的結果（tooltip 用）

local function DB()
    return ns.db.extras
end

local function SectionColor(key)
    return T.statCategory[key] or T.text
end

-- 排序：存檔裡認得的 key 照存檔順序，缺的照預設補在後面（新增一區時舊存檔照樣能用）
local function Order()
    local saved = DB().statsOrder
    local out, seen = {}, {}
    if type(saved) == "table" then
        for _, key in ipairs(saved) do
            if type(key) == "string" and SECTION_BY_KEY[key] and not SECTION_BY_KEY[key].fixed and not seen[key] then
                out[#out + 1] = key
                seen[key] = true
            end
        end
    end
    for _, key in ipairs(DEFAULT_ORDER) do
        if not seen[key] then out[#out + 1] = key end
    end
    return out
end

local function IsCollapsed(key)
    if SECTION_BY_KEY[key].fixed then return false end
    local t = DB().statsCollapsed
    return type(t) == "table" and t[key] == true
end

local Layout   -- forward

local function NewFont(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(T.Font(), size, "")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    if justify then fs:SetJustifyH(justify) end
    return fs
end

local function SetColor(fs, c, a)
    fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

------------------------------------------------------------
-- tooltip
------------------------------------------------------------
local function ShowTooltip(row)
    local def, sec = row.def, row.sec
    if not def or not ctx then return end
    local ok, lines, head = Try("CharacterStats.tip." .. def.key, function()
        local vals = X.Pack(def.get(ctx))
        local headText = format(PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s:", row.labelText or "") .. " "
            .. FormatValue(def, ctx, vals[1], vals[2])
        local out = def.tip and def.tip(ctx, unpack(vals, 1, vals.n)) or {}
        return out, headText
    end)
    if not ok then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if sec.key == "itemlevel" then
        local okc, r, g, b = pcall(GetItemLevelColor)
        if okc and r then
            GameTooltip:SetText(head, r, g, b)
        else
            GameTooltip:SetText(head, 1, 1, 1)
        end
    else
        local c = SectionColor(sec.key)
        GameTooltip:SetText(head, c[1], c[2], c[3])
    end
    -- lines 可能有洞（BuffLine 沒有加成時回 nil）⇒ 走到 maxn，不用 ipairs
    for i = 1, table.maxn(lines) do
        local line = lines[i]
        if type(line) == "string" and line ~= "" then
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local function HideTooltip(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

------------------------------------------------------------
-- 建一列
------------------------------------------------------------
local function NewRow(sec, big)
    local row = CreateFrame("Button", nil, scroll.child)
    row:SetHeight(big and ILVL_ROW_H or ROW_H)
    row.sec = sec
    if big then
        row.value = NewFont(row, FONT_ILVL, "CENTER")
        row.value:SetPoint("CENTER", row, "CENTER", 0, 0)
    else
        row.label = NewFont(row, FONT_ROW, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        SetColor(row.label, T.textDim)
        row.value = NewFont(row, FONT_ROW, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        SetColor(row.value, SectionColor(sec.key))
        -- 標籤與數值之間的引導線（同 Skins/Character.lua 第十輪的屬性列）
        local leader = X.Hairline(row, T.statLeader, "ARTWORK")
        leader:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
        leader:SetPoint("RIGHT", row.value, "LEFT", -10, 0)
    end
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

------------------------------------------------------------
-- 區標題：「∧ ——— 標題 ——— ∨」
--   點標題＝收合／展開；左箭頭＝跟上一區交換、右箭頭＝跟下一區交換。
------------------------------------------------------------
local function Swap(key, dir)
    local order = Order()
    for i, k in ipairs(order) do
        if k == key then
            local j = i + dir
            if j < 1 or j > #order then return end
            order[i], order[j] = order[j], order[i]
            DB().statsOrder = order
            Layout()
            return
        end
    end
end

local arrowEnabled = setmetatable({}, { __mode = "k" })

local function NewArrow(header, dir, color)
    local b = CreateFrame("Button", nil, header)
    b:SetSize(ARROW, ARROW)
    b:SetFrameLevel(header:GetFrameLevel() + 2)
    X.Chevron(b, dir, 8, color)
    b:SetAlpha(T.statArrowAlpha)
    b:SetScript("OnEnter", function(self) self:SetAlpha(T.statArrowHoverAlpha) end)
    b:SetScript("OnLeave", function(self)
        if arrowEnabled[self] ~= false then self:SetAlpha(T.statArrowAlpha) end
    end)
    return b
end

-- 箭頭能不能按：第一區的上、最後一區的下灰到 0.25 且不吃滑鼠（EllesmereUI 同）。
-- 狀態記在自己的表：交換之後滑鼠還停在那顆上，OnLeave 不能把灰掉的又點亮。
local function SetArrowEnabled(b, enabled)
    arrowEnabled[b] = enabled
    b:EnableMouse(enabled)
    if not enabled then
        b:SetAlpha(T.statArrowDisabledAlpha)
    elseif not b:IsMouseOver() then
        b:SetAlpha(T.statArrowAlpha)
    end
end

local function BuildSection(sec)
    local key = sec.key
    local color = SectionColor(key)
    local ui = { rows = {} }
    built[key] = ui

    local header = CreateFrame("Button", nil, scroll.child)
    header:SetHeight(TITLE_H)
    ui.header = header

    local title = NewFont(header, FONT_TITLE, "CENTER")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText(sec.title())
    SetColor(title, color)
    ui.title = title

    local rule = { color[1], color[2], color[3], T.statRuleAlpha }
    local ruleL = X.Hairline(header, rule)
    local ruleR = X.Hairline(header, rule)
    ui.ruleL, ui.ruleR = ruleL, ruleR

    if sec.fixed then
        ruleL:SetPoint("LEFT", header, "LEFT", 0, 0)
        ruleL:SetPoint("RIGHT", title, "LEFT", -RULE_GAP, 0)
        ruleR:SetPoint("LEFT", title, "RIGHT", RULE_GAP, 0)
        ruleR:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        header:EnableMouse(false)
    else
        local up = NewArrow(header, "up", color)
        up:SetPoint("LEFT", header, "LEFT", 0, 0)
        up:SetScript("OnClick", function() Swap(key, -1) end)
        local down = NewArrow(header, "down", color)
        down:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        down:SetScript("OnClick", function() Swap(key, 1) end)
        ui.up, ui.down = up, down

        ruleL:SetPoint("LEFT", up, "RIGHT", RULE_GAP, 0)
        ruleL:SetPoint("RIGHT", title, "LEFT", -RULE_GAP, 0)
        ruleR:SetPoint("LEFT", title, "RIGHT", RULE_GAP, 0)
        ruleR:SetPoint("RIGHT", down, "LEFT", -RULE_GAP, 0)

        header:RegisterForClicks("LeftButtonUp")
        header:SetScript("OnClick", function()
            local t = DB().statsCollapsed
            if type(t) ~= "table" then t = {}; DB().statsCollapsed = t end
            t[key] = (not IsCollapsed(key)) or nil
            Layout()
        end)
        -- 滑過標題：字提亮成白，告訴玩家這一條可以點（狀態只換明暗）
        header:SetScript("OnEnter", function() SetColor(title, T.text) end)
        header:SetScript("OnLeave", function() SetColor(title, color) end)
    end

    for i, def in ipairs(sec.defs) do
        local row = NewRow(sec, def.big)
        row.def = def
        ui.rows[i] = row
    end
end

-- 物品等級那一區的顏色：轉交暴雪給的品質色（傳遞者規則：分量只往 setter 送）
local function PaintItemLevelColor()
    local ui = built.itemlevel
    if not ui or type(GetItemLevelColor) ~= "function" then return end
    local ok, r, g, b = pcall(GetItemLevelColor)
    if not ok or r == nil then return end
    ui.title:SetTextColor(r, g, b, 1)
    ui.ruleL:SetVertexColor(r, g, b, T.statRuleAlpha)
    ui.ruleR:SetVertexColor(r, g, b, T.statRuleAlpha)
    local row = ui.rows[1]
    if row then row.value:SetTextColor(r, g, b, 1) end
end

------------------------------------------------------------
-- 排版：只在「顯示的列」或順序／收合變了的時候跑（每次讀值不一定要重排）
------------------------------------------------------------
function Layout()
    if not scroll then return end
    local child = scroll.child
    local y = 0
    local keys = { "itemlevel" }
    for _, k in ipairs(Order()) do keys[#keys + 1] = k end

    local orderable = #keys - 1
    for idx, key in ipairs(keys) do
        local ui = built[key]
        local anyVisible = false
        for _, row in ipairs(ui.rows) do
            if row.visible then anyVisible = true break end
        end
        -- 整區沒有可顯示的列（例如低等級的物品等級）⇒ 連標題一起收起來
        if not anyVisible then
            ui.header:Hide()
            for _, row in ipairs(ui.rows) do row:Hide() end
        else
            ui.header:Show()
            ui.header:ClearAllPoints()
            ui.header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            ui.header:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
            y = y + TITLE_H
            local collapsed = IsCollapsed(key)
            if not collapsed then y = y + TITLE_GAP end
            for _, row in ipairs(ui.rows) do
                if row.visible and not collapsed then
                    row:Show()
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
                    y = y + (row.def.big and ILVL_ROW_H or ROW_H)
                else
                    row:Hide()
                end
            end
            y = y + SECTION_GAP
        end
        if ui.up then
            SetArrowEnabled(ui.up, idx > 2)                 -- keys[1] 是物品等級
            SetArrowEnabled(ui.down, idx - 1 < orderable)
        end
    end
    scroll:SetContentHeight(y)
end

------------------------------------------------------------
-- 讀值：每一列跑一次 get，決定顯示與否與文字
------------------------------------------------------------
local function Refresh()
    if not host then return end
    ctx = BuildContext()
    local changed = false
    for _, sec in ipairs(SECTIONS) do
        local ui = built[sec.key]
        for _, row in ipairs(ui.rows) do
            local def = row.def
            local visible = (def.show == nil) or (def.show(ctx) and true or false)
            local text
            if visible then
                local ok, v, v2 = Try("CharacterStats." .. def.key, function()
                    local a, b = def.get(ctx)
                    return a, b
                end)
                if ok then
                    if def.hideZero and v == 0 then
                        visible = false
                    else
                        local okf, s = Try("CharacterStats.format." .. def.key, FormatValue, def, ctx, v, v2)
                        text = okf and s or DASH
                    end
                else
                    text = DASH       -- 秘密值（或讀不到）：照樣列出來，數值顯示「—」
                end
            end
            if row.label then
                local label = def.label(ctx)
                row.labelText = label
                row.label:SetText(label)
            else
                row.labelText = def.label(ctx)
            end
            if visible then row.value:SetText(text) end
            if row.visible ~= visible then
                row.visible = visible
                changed = true
            end
        end
    end
    PaintItemLevelColor()
    if changed then Layout() end
end

------------------------------------------------------------
-- 事件：只在清單顯示時註冊，同一幀的多發合併成一次
------------------------------------------------------------
local UNIT_EVENTS = {
    "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_SPELL_HASTE",
    "UNIT_ATTACK_SPEED", "UNIT_MAXPOWER", "UNIT_MAXHEALTH",
    "PLAYER_SPECIALIZATION_CHANGED",
}
local EVENTS = {
    "COMBAT_RATING_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "MASTERY_UPDATE",
    "SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
}

local pending = false
local function Flush()
    pending = false
    if host and host:IsVisible() then Refresh() end
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0, Flush)
end

local function RegisterEvents(f)
    -- ⚠ unit 事件一律 RegisterUnitEvent：C 端就濾掉別人，處理器裡不必比對 arg1 ——
    --   12.1 的 unit token 參數本身可能是秘密字串，拿來 `== "player"` 會炸
    --   （.claude/notes/wow-121-unit-api-secrets.md）。
    for _, ev in ipairs(UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, ev, "player") end
    for _, ev in ipairs(EVENTS) do pcall(f.RegisterEvent, f, ev) end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Build()
    local pane = _G.CharacterStatsPane
    if not pane then
        E.Missing("CharacterStatsPane")
        return
    end

    host = CreateFrame("Frame", nil, pane)
    host:SetAllPoints(pane)
    host:SetFrameLevel((E.TargetLevel(pane) or 1) + 5)
    host:SetIgnoreParentAlpha(true)
    host:EnableMouse(true)
    host:EnableMouseWheel(true)

    scroll = X.CreateScroll(host, { step = ROW_H * 3 })
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, PAD)

    for _, sec in ipairs(SECTIONS) do BuildSection(sec) end

    host:SetScript("OnShow", function(self)
        RegisterEvents(self)
        Refresh()
        Layout()
    end)
    host:SetScript("OnHide", function(self)
        self:UnregisterAllEvents()
    end)
    host:SetScript("OnEvent", Queue)

    -- 暴雪的 pane 整個藏起來（alpha 0），它自己的更新照跑
    E.Neutralize(pane, "CharacterStatsPane")

    Refresh()
    Layout()
    if host:IsVisible() then RegisterEvents(host) end
end

-- 設定頁的「百分比旁顯示評等值」是即時的：改了就重讀一次
function X.RefreshStats()
    if host and host:IsVisible() then Refresh() end
end

X.Register("statsPanel", Build)
