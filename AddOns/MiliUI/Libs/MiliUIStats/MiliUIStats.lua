------------------------------------------------------------
-- MiliUIStats：角色屬性的列定義、暴雪的算法、秘密值畫法、分區色
--
-- 給「自建屬性清單」（角色面板）與「畫面上顯示屬性」（HUD）共用的計算層：
-- 哪些列、怎麼讀值、哪一種爆擊、法術強度取哪個法術系、tooltip 的說明行、
-- 以及 12.1 秘密值要怎麼畫得出來。**不畫任何東西、不碰任何框**——畫列是消費者的事。
--
-- 這是 vendor 複製：每支插件帶一份，全域 `MiliUI_Stats` 先到先贏、版本高的蓋掉舊的。
-- 跟 MiliUISnap 同一個理由——插件之間沒有相依宣告，玩家可能只裝其中一支。
-- 唯一 source 在 MiliUI/Libs/MiliUIStats/，改完跑 `python3 .claude/scripts/sync-widgets.py`
-- 鋪到各插件。**不依賴任何插件的 Engine／Tokens／Secret**：秘密值判斷自己帶一份。
--
-- 消費者要做的事：
--   Stats.SetStrings{ secondary = "次要屬性", tertiary = "第三屬性" }
--       兩個暴雪沒有的區標題（其餘標題一律用暴雪的 GlobalStrings，語系免費）。
--       沒設就退回英文。
--   Stats.SetErrorHandler(fn)
--       `Stats.Try` 遇到**不是**秘密值的錯誤時交給它（每個 label 只報一次）。
--       沒設就走 geterrorhandler()。
--   ctx = Stats.BuildContext(valueFormat)   每次重算一次，傳給每一列
--   Stats.SECTIONS / Stats.DefByKey / Stats.SectionOf / Stats.DEFAULT_ORDER
--   Stats.ValueTemplate(def, ctx, v, v2, sign) → template, args  （餵 SetFormattedText）
--   Stats.SECTION_COLORS                    五個分區的預設色（見下）
--
------------------------------------------------------------
-- ## 12.1 秘密值
--
-- 戰鬥中（與受限內容裡）屬性 API 回的是秘密值。秘密值**拒絕被檢查**——比較、算術、
-- 在 Lua 裡 `format`／`tostring` 都會炸——但**畫得出來**：`FontString:SetFormattedText`
-- 是 C 端的 sink，秘密值當**參數**丟進去，引擎照樣把真的數字畫在畫面上，戰鬥中照樣跳動。
-- 做法照 EllesmereUI QoL 的 Secondary Stats overlay：
--
--   * 數字一律當參數，**template 只由明碼組成**（標籤先過 `Stats.Esc` 把 `%` 跳脫，
--     不然翻譯裡的「%」會變成多出來的格式符）。
--   * 只在**明碼**時做的事：hideZero 的「等於 0」、兩個 getter 相加（臨機應變）、
--     多個法術系取最小（法術強度、爆擊）、評等的 BreakUpLargeNumbers。秘密時：
--     要相加／挑選的沿用**上一次明碼的結果**（從沒拿過明碼就顯示「—」），
--     hideZero 由消費者維持上一次的可見性，評等改用 `%d` 直接把秘密值當參數。
--   * ⚠ **餵過秘密值的 FontString 不能 GetStringWidth／GetStringHeight**（會炸），
--     而且**下一次明碼那一幀也還是秘密**。要量尺寸只在「這一輪全部明碼」時量，
--     量到的寬高還要再問一次 `IsSecret`。
--   * 要在 Lua 裡**讀**數字的（tooltip）一律包在 `Stats.Try` 裡、數字先過 `Stats.Num`：
--     拿到秘密值就丟一個哨兵錯誤，整段收手。哨兵以外的錯誤才是真的 bug。
--   * 「—」只留給 nil（真的讀不到）；秘密值不顯示「—」。
--   * unit 事件一律 `RegisterUnitEvent(…, "player")`，處理器裡不比對 arg1
--     （unit token 本身可能是秘密字串）——這是消費者的事，寫在這裡提醒。
------------------------------------------------------------
local _, ns = ...

local VERSION = 1

local Stats = _G.MiliUI_Stats
if not Stats or (Stats.version or 0) < VERSION then
    Stats = Stats or {}
    Stats.version = VERSION

    ------------------------------------------------------------
    -- 秘密值（自帶一份，不讀宿主的 Secret.lua）
    ------------------------------------------------------------
    local _issecretvalue = _G.issecretvalue

    local function IsSecret(v)
        return _issecretvalue and _issecretvalue(v) and true or false
    end
    Stats.IsSecret = IsSecret

    local function PlainNumber(v)
        if type(v) ~= "number" or IsSecret(v) then return nil end
        return v
    end
    Stats.PlainNumber = PlainNumber

    local function PlainText(v)
        if type(v) ~= "string" or IsSecret(v) then return nil end
        return v
    end
    Stats.PlainText = PlainText

    local function ToBool(v)
        if v == nil or IsSecret(v) then return nil end
        return v and true or false
    end
    Stats.ToBool = ToBool

    ------------------------------------------------------------
    -- 分區色（2026-10-15）
    --
    -- 做法照 EllesmereUI 的角色面板：一個分區一個顏色，標題字、標題兩側的髮絲線、
    -- 底下每一列的**數值**全用同一個顏色，標籤降到灰字。
    --
    -- 調色**不照抄** EllesmereUI：它那五色是高飽和、其中兩個（紫 0.47/0.26/0.78、
    -- 青綠 0.05/0.82/0.62）比白字還暗，五個擺在一起像霓虹燈。這裡換成**同一個亮度帶**
    -- （相對亮度約 0.75–0.8）、中等飽和的五色——讀起來像一家人，而且白色標籤
    -- （滑過標題時的白）永遠是畫面上最亮的那個：
    --   屬性＝金沙、次要＝冰藍、第三＝薰衣草、攻擊＝珊瑚、防禦＝青瓷。
    -- 玩家可以在角色面板的設定齒輪裡逐區換色（消費者的 statsColors 蓋過這張表）。
    --
    -- 正式服的暴雪屬性欄只有兩塊分類（屬性／強化），「強化」把次要、第三、防禦屬性
    -- 全裝在一起 ⇒ 用「次要屬性」那個顏色（MiliUI_Skin 的 Skins/Character.lua 照這樣對映）。
    -- 「物品等級」那一塊沒有固定色：跟著暴雪替物品等級數字挑的顏色走（`GetItemLevelColor()`）。
    -- key ＝ 分區的 sectionKey。
    ------------------------------------------------------------
    Stats.SECTION_COLORS = {
        attributes = { 0.98, 0.80, 0.42 },   -- 金沙
        secondary  = { 0.46, 0.78, 1.00 },   -- 冰藍
        tertiary   = { 0.78, 0.66, 1.00 },   -- 薰衣草
        attack     = { 1.00, 0.53, 0.47 },   -- 珊瑚
        defense    = { 0.50, 0.88, 0.70 },   -- 青瓷
    }

    ------------------------------------------------------------
    -- 語系：暴雪沒有的兩個區標題由呼叫端給
    ------------------------------------------------------------
    Stats.strings = Stats.strings or { secondary = "Secondary Stats", tertiary = "Tertiary Stats" }

    function Stats.SetStrings(t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            if type(v) == "string" then Stats.strings[k] = v end
        end
    end

    ------------------------------------------------------------
    -- 錯誤處理：秘密值是「預期中的拒絕」，其他錯誤才報
    ------------------------------------------------------------
    local SECRET = {}
    Stats.SECRET = SECRET

    function Stats.SetErrorHandler(fn)
        Stats.errorHandler = fn
    end

    local function Report(err)
        local fn = Stats.errorHandler or geterrorhandler()
        if fn then pcall(fn, err) end
    end

    local function Num(v)
        if type(v) ~= "number" or IsSecret(v) then error(SECRET, 0) end
        return v
    end
    Stats.Num = Num

    local reported = {}
    local function Handler(err)
        if err == SECRET then return SECRET end
        return err
    end

    -- 多重回傳值打包：中間有 nil 也不掉（`{ ... }` ＋ `unpack` 遇到洞會截斷）
    local function Pack(...)
        return { n = select("#", ...), ... }
    end
    Stats.Pack = Pack

    -- 回傳 ok, ...。ok == false 時第二個值是錯誤（或 SECRET）。
    local function Try(label, fn, ...)
        local res = Pack(xpcall(fn, Handler, ...))
        if not res[1] and res[2] ~= SECRET and not reported[label] then
            reported[label] = true
            Report(res[2])
        end
        return unpack(res, 1, res.n)
    end
    Stats.Try = Try

    ------------------------------------------------------------
    -- 數值顯示方式與 template
    ------------------------------------------------------------
    local DASH = "\226\128\148"   -- 「—」
    Stats.DASH = DASH

    Stats.VALUE_FORMATS = { pct = true, rating = true, pct_rating = true, rating_pct = true }

    function Stats.ValueFormat(v)
        return (type(v) == "string" and Stats.VALUE_FORMATS[v]) and v or "pct"
    end

    -- 這種顯示方式要不要讀評等
    function Stats.FormatNeedsRating(v)
        return Stats.ValueFormat(v) ~= "pct"
    end

    -- 放進 template 的明碼字串：`%` 跳脫成 `%%`
    function Stats.Esc(s)
        return (tostring(s or ""):gsub("%%", "%%%%"))
    end

    local function Push(args, v)
        args.n = (args.n or 0) + 1
        args[args.n] = v
    end

    -- 一格數值的 template ＋ 參數。把參數依序 push 進 `args`（`args.n` 記長度，中間不會有 nil），
    -- 回傳 (template, 這一格有沒有餵秘密值)。
    --   kind    "pct"｜"int"｜"dec"｜"speed"
    --   v, v2   數值（可能是秘密值；nil ＝ 讀不到 ⇒「—」）。v2 只有 speed 用（副手）
    --   rating  評等（可能是秘密值；nil ＝ 這一格沒有評等）
    --   mode    pct 才看："pct"｜"rating"｜"pct_rating"｜"rating_pct"
    --   sign    pct 才看：false ＝ 不要「%」
    function Stats.ValueParts(args, kind, v, v2, rating, mode, sign)
        if v == nil then return DASH, false end
        local secret = IsSecret(v)
        if kind == "int" then
            if secret then
                Push(args, v)
                return "%.0f", true
            end
            Push(args, BreakUpLargeNumbers(math.floor(v + 0.5)))
            return "%s", false
        elseif kind == "dec" then
            Push(args, v)
            return "%.2f", secret
        elseif kind == "speed" then
            Push(args, v)
            if v2 ~= nil then
                Push(args, v2)
                return "%.2f / %.2f", secret or IsSecret(v2)
            end
            return "%.2f", secret
        end
        -- pct
        local pct = (sign == false) and "%.2f" or "%.2f%%"
        if rating == nil or mode == nil or mode == "pct" then
            Push(args, v)
            return pct, secret
        end
        local rt, rSecret
        if IsSecret(rating) then
            rt, rSecret = "%d", true
        else
            rt = "%s"
            rating = BreakUpLargeNumbers(math.floor(rating + 0.5))
        end
        if mode == "rating" then
            Push(args, rating)
            return rt, rSecret
        elseif mode == "rating_pct" then
            Push(args, rating)
            Push(args, v)
            return rt .. " (" .. pct .. ")", secret or rSecret
        end
        Push(args, v)
        Push(args, rating)
        return pct .. " (" .. rt .. ")", secret or rSecret
    end

    -- 一列的 template ＋ 參數（評等依 ctx.valueFormat 決定要不要讀）。
    -- 回傳 (template, args, 有沒有餵秘密值)；rating 讀不到（nil）就只少括號那一段。
    function Stats.ValueTemplate(def, ctx, v, v2, sign)
        local rating
        if Stats.FormatNeedsRating(ctx.valueFormat) and def.rating and v ~= nil then
            local cr = def.rating(ctx, v, v2)
            if cr then rating = GetCombatRating(cr) end
        end
        local args = { n = 0 }
        local tmpl, secret = Stats.ValueParts(args, def.kind, v, v2, rating, ctx.valueFormat or "pct", sign)
        return tmpl, args, secret
    end

    ------------------------------------------------------------
    -- 暴雪的計算（照 Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua 原樣搬過來，
    -- 數字一律先過 Num）
    ------------------------------------------------------------
    local STR, AGI, STA, INT = 1, 2, 3, 4   -- LE_UNIT_STAT_*
    Stats.STR, Stats.AGI, Stats.STA, Stats.INT = STR, AGI, STA, INT

    local function G(name, fallback)
        local v = _G[name]
        if type(v) == "string" then return v end
        return fallback
    end
    Stats.GlobalString = G

    local function Big(n)
        return BreakUpLargeNumbers(n)
    end

    ------------------------------------------------------------
    -- 專精脈絡：主屬性、是不是坦克、有沒有法力、有沒有盾。每次重算一次，傳給每一列。
    ------------------------------------------------------------
    local lastHasMana = false

    function Stats.BuildContext(valueFormat)
        local ctx = {}
        local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
        spec = PlainNumber(spec)
        if spec and spec > 0 then
            ctx.spec = spec
            local ok, primary = pcall(function()
                return select(6, C_SpecializationInfo.GetSpecializationInfo(spec, false, false, nil, UnitSex("player")))
            end)
            ctx.primary = ok and PlainNumber(primary) or nil
            if GetSpecializationRoleEnum and Enum and Enum.LFGRole then
                local role = GetSpecializationRoleEnum(spec)
                ctx.tank = PlainNumber(role) == Enum.LFGRole.Tank
            end
        end
        -- 還沒有專精（低等級）：三個主屬性挑最高的那個，挑不出來（秘密值）就當力量
        if not ctx.primary then
            local best, bestV = STR, -1
            for _, i in ipairs({ STR, AGI, INT }) do
                local v = PlainNumber(select(2, UnitStat("player", i)))
                if v and v > bestV then best, bestV = i, v end
            end
            ctx.primary = best
        end
        -- 法力：秘密值就沿用上一次的判斷（職業有沒有法力不會在戰鬥中變）
        local mana = Enum and Enum.PowerType and PlainNumber(UnitPowerMax("player", Enum.PowerType.Mana))
        if mana then lastHasMana = mana > 0 end
        ctx.hasMana = lastHasMana
        ctx.hasShield = C_PaperDollInfo and C_PaperDollInfo.OffhandHasShield
            and ToBool(C_PaperDollInfo.OffhandHasShield()) == true or false
        ctx.valueFormat = Stats.ValueFormat(valueFormat)
        return ctx
    end

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
    Stats.StatName = StatName

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
    Stats.CritValue = CritValue

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
    Stats.SpellPowerValue = SpellPowerValue

    -- 攻擊強度要把 base／加成／減益加起來（還有以法術強度換算那條）⇒ 秘密時沿用上一次
    local lastAP
    local function AttackPowerValue()
        local ok, v = Try("MiliUIStats.ap", AttackPowerInfo)
        if ok then lastAP = v end
        return lastAP
    end
    Stats.AttackPowerValue = AttackPowerValue

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
    Stats.VersValue = VersValue

    ------------------------------------------------------------
    -- 列的定義
    --
    -- 分區（sectionKey）：
    --   itemlevel   物品等級（永遠第一、不能收合、不能拖、沒有色票；顏色轉交 GetItemLevelColor）
    --   attributes  屬性：主屬性（依專精）、耐力、生命、法力（有法力的才列）
    --   secondary   次要屬性：致命一擊、加速、精通、臨機應變
    --   tertiary    第三屬性：汲取、迴避、速度
    --   attack      攻擊：法術強度（主屬性是智力）或攻擊強度、攻擊速度
    --   defense     防禦：護甲、閃躲、招架、格擋、醉拳
    -- 顯示條件照 `PAPERDOLL_STATCATEGORIES`（PaperDollFrame.lua:246）的 roles／hideAt／showFunc；
    -- tooltip 的說明行用暴雪自己組 `statFrame.tooltip2` 的那些全域格式字串
    -- （CR_*_TOOLTIP、STAT_*_TOOLTIP…）⇒ 語系免費、跟暴雪原本的說明一字不差。
    --
    -- 每一列：
    --   key             defKey（消費者的 statsHidden 用它；HUD 也用它找定義）
    --   label(ctx)      標籤
    --   value(ctx)      回傳 (v, v2)：要顯示的數值，**可能是秘密值**、可能是 nil（讀不到）
    --   kind            "pct"（%.2f%%）、"int"（BreakUpLargeNumbers）、"dec"（%.2f）、"speed"
    --   rating(ctx, v, v2)  評等的 CR_* 常數（valueFormat 要評等時才讀）
    --   hideZero        值等於 0 就不列（暴雪的 hideAt = 0；只在明碼時判斷）
    --   show(ctx)       顯示條件（暴雪的 roles／showFunc）
    --   big             物品等級那一列（大字、置中、沒有標籤）
    --   tip(ctx, v, v2) 回傳 tooltip 的說明行陣列（可能有洞）。進來之前 v 已經過 Num（明碼）；
    --                   要用的其他數字自己讀、自己過 Num
    -- 每一區：key、title()、fixed（物品等級）、defs
    --
    -- ## 刻意沒做
    -- * EllesmereUI 的「紋章」與「PvP」兩區——紋章的通貨代碼每季都變；PvP 那區跟角色屬性無關。
    -- * 移動速度（暴雪屬性欄的 MOVESPEED）——暴雪自己也沒放進 PAPERDOLL_STATCATEGORIES。
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
                        local lvl = PlainNumber(UnitLevel("player"))
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
            title = function() return Stats.strings.secondary end,
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
                        local cls = PlainText(select(2, UnitClass("player")))
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
                        local coeff = PlainNumber(select(2, GetMasteryEffect()))
                        local lines = {}
                        if ctx.spec and C_SpecializationInfo.GetSpecializationMasterySpells then
                            for _, id in ipairs(C_SpecializationInfo.GetSpecializationMasterySpells(ctx.spec) or {}) do
                                local name = PlainText(C_Spell.GetSpellName(id))
                                local desc = PlainText(C_Spell.GetSpellDescription(id))
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
            title = function() return Stats.strings.tertiary end,
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
                        local vsTarget = PlainNumber(select(2, C_PaperDollInfo.GetStaggerPercentage("player")))
                        if vsTarget then lines[#lines + 1] = format(STAT_STAGGER_TARGET_TOOLTIP, vsTarget) end
                        return lines
                    end,
                },
            },
        },
    }
    Stats.SECTIONS = SECTIONS

    -- 可排序的五區預設順序（物品等級不在裡面：永遠第一）
    Stats.DEFAULT_ORDER = { "attributes", "secondary", "tertiary", "attack", "defense" }

    local SECTION_BY_KEY, DEF_BY_KEY, SECTION_OF = {}, {}, {}
    for _, sec in ipairs(SECTIONS) do
        SECTION_BY_KEY[sec.key] = sec
        for _, def in ipairs(sec.defs) do
            DEF_BY_KEY[def.key] = def
            SECTION_OF[def.key] = sec.key
        end
    end
    Stats.SectionByKey = SECTION_BY_KEY
    Stats.DefByKey = DEF_BY_KEY
    Stats.SectionOf = SECTION_OF      -- defKey → sectionKey

    _G.MiliUI_Stats = Stats
end

ns.Stats = Stats
