------------------------------------------------------------
-- 自建功能：角色面板的屬性清單（取代暴雪右側的屬性欄）
--
-- 做法照 EllesmereUI 的角色面板（EllesmereUIBlizzardSkin_CharacterSheet.lua 的
-- stock 樣式：清單是 `CharacterStatsPane` 的子框、停在 InsetRight 那一格，暴雪
-- 自己的側邊欄分頁 Show/Hide 那個 pane 就帶著它顯隱）；樣式套這包的 Tokens。
--
-- 分區（key ＝ `db.extras.statsOrder`／`statsCollapsed`／`statsColors` 裡的 sectionKey）：
--   itemlevel   物品等級（永遠第一、不能收合、不能拖、沒有色票；顏色轉交 GetItemLevelColor）
--   attributes  屬性：主屬性（依專精）、耐力、生命、法力（有法力的才列）
--   secondary   次要屬性：致命一擊、加速、精通、臨機應變
--   tertiary    第三屬性：汲取、迴避、速度
--   attack      攻擊：法術強度（主屬性是智力）或攻擊強度、攻擊速度
--   defense     防禦：護甲、閃躲、招架、格擋、醉拳
-- 每一區一個顏色（`statsColors[sectionKey]`，沒有就 `T.statCategory[sectionKey]`），
-- 點標題收合；百分比一律顯示到小數第二位（暴雪的屬性欄是 `%d%%` 四捨五入）。
--
-- **編輯狀態**（角色面板右上角的齒輪開的設定面板開著時，`X.IsEditing()`，
-- 見 StatsSettings.lua）：
--   * 拖曳區標題排序（物品等級固定第一、不能拖、也不能被插到它前面）；
--   * 每一列左邊一顆勾選框決定顯示（`statsHidden[defKey]`）—— 被隱藏的列在編輯狀態
--     照樣列出來（alpha 0.4）好讓人勾回來，編輯狀態關掉之後才真的不排；
--   * 區標題右端一顆色票換這一區的顏色（共用層 `W.CreateColorPicker`，暴雪的選色器）。
-- 編輯狀態外色票照樣佔位（alpha 0、不吃滑鼠）：右線一律錨在色票左邊，版面不跳。
--
-- 計算照暴雪自己的 `PaperDollFrame_Set*`（Blizzard_UIPanels_Game/Mainline/
-- PaperDollFrame.lua，12.1 live）：哪一種爆擊、哪一種加速、法術強度取哪幾個法術系、
-- 攻擊強度遠程／近戰與「以法術強度換算」那條分支，全部照抄它的挑法；顯示條件照
-- `PAPERDOLL_STATCATEGORIES`（:246）的 roles／hideAt／showFunc。
-- tooltip 的說明行用暴雪自己組 `statFrame.tooltip2` 的那些全域格式字串
-- （CR_*_TOOLTIP、STAT_*_TOOLTIP…）⇒ 語系免費、跟暴雪原本的說明一字不差。
-- 列的定義（`DEF_BY_KEY`）與讀值也給畫面上的屬性顯示用（`X.StatDefs`，StatsHud.lua）。
--
-- ## 刻意沒做
--
-- * EllesmereUI 的「紋章」與「PvP」兩區 —— 紋章的通貨代碼每季都變（套組另有每季
--   維護的清單，不想再多一份會過期的表）；PvP 那區跟角色屬性無關。
-- * 移動速度（暴雪屬性欄的 MOVESPEED）—— 暴雪自己也沒放進 PAPERDOLL_STATCATEGORIES。
-- * 隱藏整區 —— 把那一區的每一列都取消勾選就等於隱藏整區（標題跟著收起來）。
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
-- | ColorPickerFrame | 色票走共用層 `W.CreateColorPicker` → `SetupColorPickerAndShow`（暴雪公開的進入點） |
--
-- 寫入暴雪欄位：無。hook：無（Show/Hide 跟著 parent 走，用的是**自己框**的 OnShow/OnHide）。
-- 讀暴雪物件：只有上面那一個 GetFrameLevel。其餘全部是讀 API（UnitStat、GetCombatRating…）。
-- 拖曳中的影子是**自己的**框（parent UIParent、TOOLTIP strata），不碰暴雪物件。
--
-- 宿主框 `SetIgnoreParentAlpha(true)`：pane 是 alpha 0，不忽略就跟著看不見。
-- 代價：別的插件對 CharacterFrame 整體做淡入淡出時，這一塊不會跟著淡。
-- 宿主框 `EnableMouse(true)`：暴雪那些 alpha 0 的屬性列**還在收滑鼠**（OnEnter 會跳
-- 暴雪的 tooltip），我們的框蓋在上面把它們擋掉。
--
-- ## 12.1 秘密值
--
-- 顯示走 `X.ValueParts` ＋ `FontString:SetFormattedText`（Common.lua 那一節）：數字當
-- **參數**交給引擎畫，戰鬥中照樣是真的數字、照樣會動；「—」只留給 nil。
-- 要相加／挑選的（臨機應變、爆擊挑哪一種、法術強度取哪個法術系、攻擊強度）只在明碼時
-- 算，秘密時沿用上一次明碼的結果或挑法（EllesmereUI 的 Secondary Stats overlay 同）。
-- hideZero 只在明碼時判斷，秘密時維持上一次的可見性。
-- tooltip 要在 Lua 裡讀數字 ⇒ 照舊過 `X.Num`：秘密值整段收手、不給 tooltip。
-- 物品等級的顏色（`GetItemLevelColor()`）只原封不動交給 SetTextColor／SetVertexColor
-- （傳遞者規則）。這支**不量**任何餵過數值的 FontString（版面是固定列高）。
------------------------------------------------------------
local _, ns = ...

local X = ns.Extras
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local P = ns.P
local W = ns.W
local L = ns.L

local Num, Try = X.Num, X.Try
local IsSecret = X.IsSecret

-- 版面（框架單位）。照 EllesmereUI：標題 16 高、列從標題下 22 開始、列高 16、區間距 6。
local TITLE_H     = 16
local TITLE_GAP   = 6
local ROW_H       = 16
local SECTION_GAP = 8
local ILVL_ROW_H  = 26
local SWATCH      = 10    -- 區標題右端的色票（編輯狀態外 alpha 0、照樣佔位）
local RULE_GAP    = 6     -- 線與字／色票之間
local PAD         = 6     -- 宿主框的內距（左右上下）
local CHECK       = 14    -- 編輯狀態每列左邊的勾選框
local CHECK_INDENT = 18   -- 編輯狀態標籤往右讓的距離
local HIDDEN_ALPHA = 0.4  -- 編輯狀態裡被隱藏的列
local DRAG_ALPHA   = 0.4  -- 拖曳中的那一個區標題

local FONT_TITLE = 12
local FONT_ROW   = 11
local FONT_ILVL  = 20

local DASH = X.DASH

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
    ctx.valueFormat = X.ValueFormat(ns.db and ns.db.extras and ns.db.extras.statsValueFormat)
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

local function ArmorReduction(armor)
    return Num(C_PaperDollInfo.GetArmorEffectiveness(armor, Num(UnitEffectiveLevel("player")))) * 100
end

local function ArmorReductionTarget(armor)
    local v = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget and C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(armor)
    if v == nil then return nil end
    return Num(v) * 100
end

------------------------------------------------------------
-- 顯示用的讀值：**不檢查**數值，秘密值原封不動往外交（給 SetFormattedText 當參數）
--
-- 要挑選或相加的四支只在明碼時算，秘密時沿用上一次明碼的挑法／結果
-- （照 EllesmereUI 的 `PlayerCritChance` 與 overlay 的 `_versLastClean`）。
------------------------------------------------------------
local critPick, critSchool = "spell", 2

-- PaperDollFrame.lua:1020 的挑法；回傳 (爆擊率, 對應的 CR_*)
local function CritValue()
    local ranged, melee = GetRangedCritChance(), GetCritChance()
    local spell, school = GetSpellCritChance(2), 2
    local secret = IsSecret(ranged) or IsSecret(melee) or IsSecret(spell)
    if not secret then
        for i = 3, MAX_SPELL_SCHOOLS or 7 do
            local v = GetSpellCritChance(i)
            if IsSecret(v) then secret = true break end
            if v < spell then spell, school = v, i end
        end
    end
    if secret then
        if critPick == "spell" then return GetSpellCritChance(critSchool), CR_CRIT_SPELL end
        if critPick == "ranged" then return ranged, CR_CRIT_RANGED end
        return melee, CR_CRIT_MELEE
    end
    if spell >= ranged and spell >= melee then
        critPick, critSchool = "spell", school
        return spell, CR_CRIT_SPELL
    elseif ranged >= melee then
        critPick = "ranged"
        return ranged, CR_CRIT_RANGED
    end
    critPick = "melee"
    return melee, CR_CRIT_MELEE
end

-- PaperDollFrame.lua:972：法術系 2..MAX 取最小；秘密時回上一次挑中那一系的（秘密）值
local spSchool = 2
local function SpellPowerValue()
    local v, school = GetSpellBonusDamage(2), 2
    if IsSecret(v) then return GetSpellBonusDamage(spSchool) end
    for i = 3, MAX_SPELL_SCHOOLS or 7 do
        local s = GetSpellBonusDamage(i)
        if IsSecret(s) then return GetSpellBonusDamage(spSchool) end
        if s < v then v, school = s, i end
    end
    spSchool = school
    return v
end

-- 攻擊強度要把 base／加成／減益加起來（還有以法術強度換算那條）⇒ 秘密時沿用上一次
local lastAP
local function AttackPowerValue()
    local ok, v = Try("CharacterStats.ap", AttackPowerInfo)
    if ok then lastAP = v end
    return lastAP
end

-- 臨機應變 ＝ 評等加成 ＋ 固定加成（PaperDollFrame.lua:1276）⇒ 秘密時沿用上一次
local lastVers
local function VersValue()
    local a = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    local b = GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
    if IsSecret(a) or IsSecret(b) or type(a) ~= "number" or type(b) ~= "number" then
        return lastVers
    end
    lastVers = a + b
    return lastVers
end

------------------------------------------------------------
-- 列的定義
--
-- 每一列：
--   key             defKey（`statsHidden` 的 key；畫面顯示也用它找定義）
--   label(ctx)      標籤
--   value(ctx)      回傳 (v, v2)：要顯示的數值，**可能是秘密值**、可能是 nil（讀不到）
--   kind            "pct"（%.2f%%）、"int"（BreakUpLargeNumbers）、"dec"（%.2f）、"speed"
--   rating(ctx, v, v2)  評等的 CR_* 常數（statsValueFormat 要評等時才讀）
--   hideZero        值等於 0 就不列（暴雪的 hideAt = 0；只在明碼時判斷）
--   show(ctx)       顯示條件（暴雪的 roles／showFunc）
--   tip(ctx, v, v2) 回傳 tooltip 的說明行陣列。進來之前 v 已經過 Num（明碼）；
--                   要用的其他數字自己讀、自己過 Num
------------------------------------------------------------
local function StatTip(statIndex)
    return function(ctx, eff)
        local stat, _, pos, neg = UnitStat("player", statIndex)
        stat, pos, neg = Num(stat), Num(pos), Num(neg)
        return { BuffLine(stat - pos - neg, pos, neg), StatTooltip(statIndex, eff, ctx) }
    end
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
                value = function() return (select(2, GetAverageItemLevel())) end,
                -- PaperDollFrame.lua:1293 `PaperDollFrame_SetItemLevel`
                tip = function(_, equipped)
                    local avg, _, pvp = GetAverageItemLevel()
                    avg, pvp = Num(avg), Num(pvp)
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
            {
                key = "primary",
                label = function(ctx) return StatName(ctx.primary) end,
                kind = "int",
                value = function(ctx) return (select(2, UnitStat("player", ctx.primary))) end,
                tip = function(ctx, eff) return StatTip(ctx.primary)(ctx, eff) end,
            },
            {
                key = "stamina",
                label = function() return StatName(STA) end,
                kind = "int",
                value = function() return (select(2, UnitStat("player", STA))) end,
                tip = StatTip(STA),
            },
            {
                key = "health",
                label = function() return G("HEALTH", "Health") end,
                kind = "int",
                value = function() return UnitHealthMax("player") end,
                tip = function() return { G("STAT_HEALTH_TOOLTIP") } end,
            },
            {
                key = "mana",
                label = function() return G("MANA", "Mana") end,
                kind = "int",
                show = function(ctx) return ctx.hasMana end,
                value = function() return UnitPowerMax("player", Enum.PowerType.Mana) end,
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
                rating = function(_, _, cr) return cr end,
                value = CritValue,
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
                value = function() return GetHaste() end,
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
                value = function() return (GetMasteryEffect()) end,
                -- PaperDollFrame.lua:1185 `Mastery_OnEnter`：精通法術的說明 ＋ 評等那一行
                tip = function(ctx, mastery)
                    local coeff = S.PlainNumber(select(2, GetMasteryEffect()))
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
                        SecondaryBonus(CR_MASTERY, mastery, coeff))
                    return lines
                end,
            },
            {
                key = "versatility",
                label = function() return G("STAT_VERSATILITY", "Versatility") end,
                kind = "pct",
                hideZero = true,
                rating = function() return CR_VERSATILITY_DAMAGE_DONE end,
                value = VersValue,
                tip = function()
                    -- 秘密時 value 回的是上一次的明碼值；tooltip 要的是「現在」⇒ 重讀、過 Num
                    local dmg = Num(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE))
                        + Num(GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
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
                value = function() return GetLifesteal() end,
                tip = function()
                    return { format(CR_LIFESTEAL_TOOLTIP, Big(Num(GetCombatRating(CR_LIFESTEAL))), Num(GetCombatRatingBonus(CR_LIFESTEAL))) }
                end,
            },
            {
                key = "avoidance",
                label = function() return G("STAT_AVOIDANCE", "Avoidance") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_AVOIDANCE end,
                value = function() return GetAvoidance() end,
                tip = function()
                    return { format(CR_AVOIDANCE_TOOLTIP, Big(Num(GetCombatRating(CR_AVOIDANCE))), Num(GetCombatRatingBonus(CR_AVOIDANCE))) }
                end,
            },
            {
                key = "speed",
                label = function() return G("STAT_SPEED", "Speed") end,
                kind = "pct", hideZero = true,
                rating = function() return CR_SPEED end,
                value = function() return GetSpeed() end,
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
                value = function(ctx)
                    if ctx.primary == INT then return SpellPowerValue() end
                    return AttackPowerValue()
                end,
                tip = function(ctx)
                    if ctx.primary == INT then return { G("STAT_SPELLPOWER_TOOLTIP") } end
                    local _, base, pos, neg, line = AttackPowerInfo()
                    return { BuffLine(base, pos, neg), line }
                end,
            },
            {
                key = "attackspeed",
                label = function() return G("WEAPON_SPEED", "Attack Speed") end,
                kind = "speed",
                -- PaperDollFrame.lua:908：主手（有副手就「主 / 副」）
                value = function() return UnitAttackSpeed("player") end,
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
                value = function() return (select(2, UnitArmor("player"))) end,
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
                value = function() return GetDodgeChance() end,
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
                value = function() return GetParryChance() end,
                tip = function()
                    return { format(CR_PARRY_TOOLTIP, Num(GetCombatRating(CR_PARRY)), Num(GetCombatRatingBonus(CR_PARRY))) }
                end,
            },
            {
                key = "block",
                label = function() return G("STAT_BLOCK", "Block") end,
                kind = "pct", hideZero = true,
                show = function(ctx) return ctx.hasShield end,
                value = function() return GetBlockChance() end,
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
                value = function() return (C_PaperDollInfo.GetStaggerPercentage("player")) end,
                -- PaperDollFrame.lua:722
                tip = function(_, stagger)
                    local lines = { format(STAT_STAGGER_TOOLTIP, stagger) }
                    local vsTarget = S.PlainNumber(select(2, C_PaperDollInfo.GetStaggerPercentage("player")))
                    if vsTarget then lines[#lines + 1] = format(STAT_STAGGER_TARGET_TOOLTIP, vsTarget) end
                    return lines
                end,
            },
        },
    },
}

local SECTION_BY_KEY = {}
local DEF_BY_KEY = {}
local SECTION_OF = {}     -- defKey → sectionKey
for _, sec in ipairs(SECTIONS) do
    SECTION_BY_KEY[sec.key] = sec
    for _, def in ipairs(sec.defs) do
        DEF_BY_KEY[def.key] = def
        SECTION_OF[def.key] = sec.key
    end
end

------------------------------------------------------------
-- 匯出給畫面上的屬性顯示（StatsHud.lua）：同一份定義與讀值，不抄第二份
------------------------------------------------------------
X.StatDefs = DEF_BY_KEY
X.StatSectionOf = SECTION_OF
X.BuildStatContext = BuildContext

local function DB()
    return ns.db.extras
end

-- 一區的顏色：玩家換過的（`statsColors`）優先，其次是 Tokens 的預設
local function SectionColor(key)
    local over = DB().statsColors
    local c = type(over) == "table" and over[key]
    if type(c) == "table" and type(c[1]) == "number" then return c end
    return T.statCategory[key] or T.text
end
X.SectionColor = SectionColor

------------------------------------------------------------
-- 狀態與 UI
------------------------------------------------------------
local host, scroll
local built = {}         -- sectionKey → { header, title, ruleL, ruleR, swatch, rows = {} }
local ctx                -- 最後一次 BuildContext 的結果（tooltip 用）

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

local function IsHidden(defKey)
    local t = DB().statsHidden
    return type(t) == "table" and t[defKey] == true
end

local function SubTable(name)
    local t = DB()[name]
    if type(t) ~= "table" then t = {}; DB()[name] = t end
    return t
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
-- 數值 → FontString（秘密值當參數交給引擎畫，見 Common.lua）
------------------------------------------------------------
local function ValueMode(c)
    return c.valueFormat or "pct"
end

-- 回傳 (template, args)；rating 讀不到（nil）就只少括號那一段
local function ValueTemplate(def, c, v, v2)
    local rating
    if X.FormatNeedsRating(c.valueFormat) and def.rating then
        local cr = def.rating(c, v, v2)
        if cr then rating = GetCombatRating(cr) end
    end
    local args = { n = 0 }
    local tmpl = X.ValueParts(args, def.kind, v, v2, rating, ValueMode(c))
    return tmpl, args
end

------------------------------------------------------------
-- tooltip（要在 Lua 裡讀數字 ⇒ 只在明碼時給）
------------------------------------------------------------
local function ShowTooltip(row)
    local def, sec = row.def, row.sec
    if not def or not ctx then return end
    local ok, lines, head = Try("CharacterStats.tip." .. def.key, function()
        local v, v2 = def.value(ctx)
        Num(v)
        if v2 ~= nil then Num(v2) end
        local tmpl, args = ValueTemplate(def, ctx, v, v2)
        for i = 1, args.n do
            if IsSecret(args[i]) then Num(args[i]) end   -- 評等是秘密值 ⇒ 收手
        end
        local headText = format(PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s:", row.labelText or "") .. " "
            .. format(tmpl, unpack(args, 1, args.n))
        local out = def.tip and def.tip(ctx, v, v2) or {}
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
-- 編輯狀態每列左邊的勾選框（自己畫：同共用層 `W.CreateCheckButton` 那張勾、同一個色）
------------------------------------------------------------
local function NewRowCheck(row)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(CHECK, CHECK)
    b:SetPoint("LEFT", row, "LEFT", 0, 0)
    local bd = X.Backdrop(b, T.fillCheck, T.border)
    -- 勾的貼圖邊長：同 T.checkGlyphHeight 對 T.checkBoxSize 的比例，再除掉貼圖留白（勾往外溢）
    local glyph = b:CreateTexture(nil, "OVERLAY")
    glyph:SetTexture(T.checkOutlineTexture)
    local size = CHECK * T.checkGlyphHeight / T.checkBoxSize / T.checkOutlineGlyphFrac
    glyph:SetSize(size, size)
    glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    glyph:SetVertexColor(T.AccentCheck())
    b.glyph = glyph

    b:SetScript("OnEnter", function() bd:SetBorder({ T.Accent() }) end)
    b:SetScript("OnLeave", function() bd:SetBorder(T.border) end)
    b:SetScript("OnClick", function()
        local key = row.def.key
        local t = SubTable("statsHidden")
        t[key] = (not IsHidden(key)) or nil
        Layout()
    end)
    b:Hide()
    return b
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
    row.check = NewRowCheck(row)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

------------------------------------------------------------
-- 區的顏色：標題字、兩條線、色票、每列的數值
------------------------------------------------------------
local function PaintSection(key)
    local ui = built[key]
    if not ui or SECTION_BY_KEY[key].fixed then return end
    local c = SectionColor(key)
    if not ui.hover then SetColor(ui.title, c) end
    ui.ruleL:SetVertexColor(c[1], c[2], c[3], T.statRuleAlpha)
    ui.ruleR:SetVertexColor(c[1], c[2], c[3], T.statRuleAlpha)
    if ui.swatch then ui.swatch:SetColor({ r = c[1], g = c[2], b = c[3], a = 1 }) end
    for _, row in ipairs(ui.rows) do
        if row.label then SetColor(row.value, c) end
    end
end

local function PaintAll()
    for key in pairs(built) do PaintSection(key) end
end

-- 色票選了顏色：跟預設一樣就不存（「重設顏色」之後再點開取消，不該留下一筆覆寫）
local function SetSectionColor(key, r, g, b)
    local def = T.statCategory[key]
    local t = SubTable("statsColors")
    if def and math.abs(def[1] - r) < 0.002 and math.abs(def[2] - g) < 0.002 and math.abs(def[3] - b) < 0.002 then
        t[key] = nil
    else
        t[key] = { r, g, b }
    end
    X.NotifyStatsChanged("colors")
end

------------------------------------------------------------
-- 拖曳排序（只在編輯狀態）
--
-- 影子是**自己的**框：parent UIParent、TOOLTIP strata，同字同色的 FontString 跟著游標。
-- 放手時拿游標的 y 跟各區標題的 GetTop／GetBottom（自己的框，量得到）比：
-- 中線在游標上面的那幾區排在前面，拖的那一區插在它們後面。物品等級不在排序裡 ⇒
-- 永遠第一、也插不到它前面。
------------------------------------------------------------
local ghost
local dragging

local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(1, 1)
    ghost.text = NewFont(ghost, FONT_TITLE, "CENTER")
    ghost.text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
    end)
    ghost:Hide()
    return ghost
end

local function BeginDrag(key)
    local ui = built[key]
    dragging = key
    ui.header:SetAlpha(DRAG_ALPHA)
    local g = Ghost()
    local hs, us = ui.header:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if hs and us and us > 0 then g:SetScale(hs / us) end
    g.text:SetText(ui.title:GetText() or "")
    SetColor(g.text, SectionColor(key))
    g:Show()
end

-- cancel：清單被收起來／編輯狀態被關掉時只收尾、不改順序
local function EndDrag(key, cancel)
    if dragging ~= key then return end
    dragging = nil
    local ui = built[key]
    ui.header:SetAlpha(1)
    if ghost then ghost:Hide() end
    if cancel then return end

    local _, cy = GetCursorPosition()
    local others = {}
    for _, k in ipairs(Order()) do
        if k ~= key then others[#others + 1] = k end
    end
    local pos = 0
    for i, k in ipairs(others) do
        local h = built[k].header
        if h:IsShown() then
            local top, bottom = h:GetTop(), h:GetBottom()
            local s = h:GetEffectiveScale()
            if top and bottom and s and s > 0 and (top + bottom) / 2 > cy / s then pos = i end
        end
    end
    table.insert(others, pos + 1, key)
    DB().statsOrder = others
    Layout()
end

------------------------------------------------------------
-- 區標題：「——— 標題 ——— ■」（■ 是編輯狀態的色票）
--   點標題＝收合／展開；編輯狀態拖標題＝排序。
------------------------------------------------------------
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
        -- 色票永遠佔位（編輯狀態外 alpha 0、不吃滑鼠）⇒ 右線一律錨在它左邊，版面不跳；
        -- 左線讓出同樣寬，標題才置中在兩條線之間
        local swatch = W.CreateColorPicker(header, nil, false, function(r, g, b)
            SetSectionColor(key, r, g, b)
        end)
        P.Size(swatch, SWATCH, SWATCH)
        swatch:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        swatch:SetFrameLevel(header:GetFrameLevel() + 2)
        swatch:SetColor({ r = color[1], g = color[2], b = color[3], a = 1 })
        swatch:SetAlpha(0)
        swatch:EnableMouse(false)
        ui.swatch = swatch

        ruleL:SetPoint("LEFT", header, "LEFT", SWATCH + RULE_GAP, 0)
        ruleL:SetPoint("RIGHT", title, "LEFT", -RULE_GAP, 0)
        ruleR:SetPoint("LEFT", title, "RIGHT", RULE_GAP, 0)
        ruleR:SetPoint("RIGHT", swatch, "LEFT", -RULE_GAP, 0)

        header:RegisterForClicks("LeftButtonUp")
        header:RegisterForDrag("LeftButton")
        -- 拖過就不算點（拖完放手時 OnClick 可能還會來）；按下時重置，不然沒來的那次會吃掉下一次點擊
        header:SetScript("OnMouseDown", function(self) self.dragged = false end)
        header:SetScript("OnDragStart", function(self)
            if not X.IsEditing() then return end
            self.dragged = true
            BeginDrag(key)
        end)
        header:SetScript("OnDragStop", function() EndDrag(key) end)
        header:SetScript("OnClick", function(self)
            if self.dragged then
                self.dragged = false
                return
            end
            local t = SubTable("statsCollapsed")
            t[key] = (not IsCollapsed(key)) or nil
            Layout()
        end)
        -- 滑過標題：字提亮成白，告訴玩家這一條可以點（狀態只換明暗）
        header:SetScript("OnEnter", function()
            ui.hover = true
            SetColor(title, T.text)
        end)
        header:SetScript("OnLeave", function()
            ui.hover = false
            SetColor(title, SectionColor(key))
        end)
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
-- 排版：只在「可顯示的列」、順序／收合／隱藏、編輯狀態變了的時候跑
--
-- row.avail   ＝ 這一列現在有資料可顯示（show 條件 ＋ hideZero，Refresh 決定）
-- 列出來的條件 ＝ avail 而且（編輯狀態 或 沒被玩家隱藏）
------------------------------------------------------------
function Layout()
    if not scroll then return end
    local child = scroll.child
    local editing = X.IsEditing()
    local y = 0
    local keys = { "itemlevel" }
    for _, k in ipairs(Order()) do keys[#keys + 1] = k end

    for _, key in ipairs(keys) do
        local ui = built[key]
        local anyListed = false
        for _, row in ipairs(ui.rows) do
            row.listed = row.avail and (editing or not IsHidden(row.def.key)) or false
            if row.listed then anyListed = true end
        end
        if ui.swatch then
            ui.swatch:SetAlpha(editing and 1 or 0)
            ui.swatch:EnableMouse(editing)
        end
        -- 整區沒有可列的（例如低等級的物品等級、整區被取消勾選）⇒ 連標題一起收起來
        if not anyListed then
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
                if row.listed and not collapsed then
                    local hidden = IsHidden(row.def.key)
                    row:Show()
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
                    row:SetAlpha((editing and hidden) and HIDDEN_ALPHA or 1)
                    row.check:SetShown(editing)
                    row.check.glyph:SetShown(not hidden)
                    if row.label then
                        row.label:ClearAllPoints()
                        row.label:SetPoint("LEFT", row, "LEFT", editing and CHECK_INDENT or 0, 0)
                    end
                    y = y + (row.def.big and ILVL_ROW_H or ROW_H)
                else
                    row:Hide()
                end
            end
            y = y + SECTION_GAP
        end
    end
    scroll:SetContentHeight(y)
end

------------------------------------------------------------
-- 讀值：每一列跑一次 value，決定可不可顯示與文字
------------------------------------------------------------
local function UpdateRow(row)
    local def = row.def
    local avail = (def.show == nil) or (def.show(ctx) and true or false)
    if avail then
        local v, v2 = def.value(ctx)
        if v == nil then
            row.value:SetText(DASH)
        else
            -- hideZero：明碼才判斷；秘密時維持上一次的可見性（第一次就當可見）
            if def.hideZero then
                if IsSecret(v) then
                    if row.avail == false then avail = false end
                elseif v == 0 then
                    avail = false
                end
            end
            if avail then
                local tmpl, args = ValueTemplate(def, ctx, v, v2)
                row.value:SetFormattedText(tmpl, unpack(args, 1, args.n))
            end
        end
    end
    local label = def.label(ctx)
    row.labelText = label
    if row.label then row.label:SetText(label) end
    return avail
end

local function Refresh()
    if not host then return end
    ctx = BuildContext()
    local changed = false
    for _, sec in ipairs(SECTIONS) do
        for _, row in ipairs(built[sec.key].rows) do
            local ok, avail = Try("CharacterStats." .. row.def.key, UpdateRow, row)
            if not ok then
                row.value:SetText(DASH)
                avail = true
            end
            if row.avail ~= avail then
                row.avail = avail
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
        -- 拖到一半清單被收起來（關角色面板）：OnDragStop 不一定會來
        if dragging then EndDrag(dragging, true) end
    end)
    host:SetScript("OnEvent", Queue)

    -- 暴雪的 pane 整個藏起來（alpha 0），它自己的更新照跑
    E.Neutralize(pane, "CharacterStatsPane")

    -- 編輯狀態切換、設定面板改了東西：重畫
    X.OnEditChanged(function()
        if dragging then EndDrag(dragging, true) end
        Layout()
    end)
    X.OnStatsChanged(function()
        PaintAll()
        if host:IsVisible() then Refresh() end
        Layout()
    end)

    Refresh()
    Layout()
    if host:IsVisible() then RegisterEvents(host) end
end

-- 設定頁的「百分比旁顯示評等值」是即時的：改了就重讀一次
function X.RefreshStats()
    X.NotifyStatsChanged("rating")
end

X.Register("statsPanel", Build)
