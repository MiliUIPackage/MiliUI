------------------------------------------------------------
-- 法術 reader：CollectLines 的 rows → model
--
-- 純邏輯（Panel.ReadSpellRows 吃 rows＋game 介面，可離線測）。行的認法：
--   * 型別優先：SpellName（名字）、SpellPassive、SpellDescription、UsageRequirement、NestedBlock
--   * 沒型別的行，左右欄各自丟 Patterns：耗能／施法／冷卻（含充能恢復）／距離／最大充能／
--     天賦等級／剩餘冷卻／「需要 X」／材料、工具前綴
--   * 都不是 ⇒ extras（保留顏色）。**一行都不丟**：一列裡認得的欄位拿走、認不得的那半照樣進 extras
--
-- 描述整段不切句（中文沒有句點加大寫可切），|n 原樣保留。
-- 天賦：暴雪的天賦面板把名字與等級寫在 data 之外（後加的行），第 1 行沒被 data 蓋到就當名字；
-- TOOLTIP_TALENT_NEXT_RANK 標籤之後的後加行歸「下一等級」。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel
local Patterns = ns.Patterns

local LT = Enum and Enum.TooltipDataLineType or {}
Panel.readers = Panel.readers or {}
Panel.views = Panel.views or {}

local function Trim(s)
    return (type(s) == "string" and s:match("^%s*(.-)%s*$")) or ""
end
Panel.Trim = Trim

-- 暴雪把「不可用」寫成紅字
function Panel.IsRed(c)
    return c ~= nil and c[1] > 0.9 and c[2] < 0.3 and c[3] < 0.3
end

-- 不是白字（白＝暴雪的一般行）
local function Colored(c)
    return c ~= nil and not (c[1] > 0.95 and c[2] > 0.95 and c[3] > 0.95)
end

-- 描述的金色（NORMAL_FONT_COLOR 1, .82, 0）
local function IsGold(c)
    return c ~= nil and c[1] > 0.9 and c[2] > 0.65 and c[2] < 0.9 and c[3] < 0.3
end

-- 「1,234」「1.5」→ 數字
local function Num(s)
    if type(s) ~= "string" then return tonumber(s) end
    return tonumber((s:gsub(",", "")))
end
Panel.Num = Num

local function NewPart()
    return { requirements = {}, details = {}, description = {}, extras = {} }
end

local function Typed(row, name)
    return row.type ~= nil and LT[name] ~= nil and row.type == LT[name]
end

-- 一段文字認成哪個欄位；認得就寫進 part、回 true
local function ClassifyText(part, text, row)
    local plain = Trim(Patterns.StripColors(text))
    if plain == "" then return true end

    if Patterns.Match("SPELL_PASSIVE", plain) then
        part.passive = plain
        return true
    end
    local key, a, b = Patterns.Find("talent", plain)
    if key then
        part.talent = { text = plain, rank = Num(a), max = Num(b) }
        return true
    end
    key, a = Patterns.Find("cost", plain)
    if key then
        part.cost = { text = plain, key = key, power = Patterns.PowerOf(key) }
        return true
    end
    key, a = Patterns.Find("cast", plain)
    if key then
        part.cast = { text = plain, key = key, value = (a ~= true) and a or nil }
        return true
    end
    -- 剩餘冷卻先問：「冷卻時間尚有：12秒」跟「冷卻時間8秒」開頭一樣
    key = Patterns.Find("cooldownLeft", plain)
    if key then
        part.details[#part.details + 1] = { left = plain, remaining = true }
        return true
    end
    key, a = Patterns.Find("cooldown", plain)
    if key then
        part.cooldown = {
            text = plain, key = key, value = (a ~= true) and a or nil,
            recharge = key:find("_CHARGES_", 1, true) ~= nil,
        }
        return true
    end
    key, a = Patterns.Find("range", plain)
    if key then
        part.range = { text = plain, key = key }
        return true
    end
    key, a = Patterns.Find("charges", plain)
    if key then
        part.charges = { text = plain, count = Num(a) }
        return true
    end
    key = Patterns.Find("requires", plain)
    if key then
        part.requirements[#part.requirements + 1] = { left = plain, unmet = Panel.IsRed(row and row.color) }
        return true
    end
    if Patterns.Prefix("SPELL_REAGENTS", plain) or Patterns.Prefix("SPELL_TOTEMS", plain) then
        part.details[#part.details + 1] = { left = text }
        return true
    end
    return false
end

-- 需求行是否未達成：usable == false、紅字、或「需要等級 N」高過自己
local function Unmet(row, text, game)
    if row.usable == false then return true end
    if Panel.IsRed(row.color) then return true end
    local level = Patterns.Match("ITEM_MIN_LEVEL", Trim(Patterns.StripColors(text)))
    local mine = game and game.playerLevel and game.playerLevel()
    if level and level ~= true and mine then return mine < (Num(level) or 0) end
    return false
end
Panel.Unmet = Unmet

-- 認不得的行：暴雪 data 的進主面板「其他」區；別人後加的（appended）進附屬框那一桶（model.appended）
local function Extra(part, row, left, right, model)
    local list = row.appended and model and model.appended or part.extras
    list[#list + 1] = {
        left = left or "", right = right, color = row.color, rightColor = row.rightColor,
    }
end

-- rows：Panel.CollectLines 的結果；game：{ spellIcon(id), playerLevel() }；id：data.id（明文才用）
function Panel.ReadSpellRows(rows, game, id)
    local model = NewPart()
    model.kind = "spell"
    model.appended = {}
    model.tags = {}            -- 名字之後、本體之前的帶色行（坐騎：「戰隊坐騎」｜「飛行」）→ 徽章列、保留原色
    local seenBody = false
    local part = model
    local nextRank             -- 天賦面板「下一等級」那一段
    local nameTaken = false

    -- 名字：SpellName 型別行；沒有就畫在第 1 行的那一行（天賦面板把名字寫在 data 之外，
    -- 第 1 行是後加的；那時 data 的第一行是描述，不能拿來當名字）；都沒有才退第一個 data 行
    -- （只看巢狀法術之前的行：巢狀那段有自己的 SpellName）
    local outer = {}
    for _, row in ipairs(rows) do
        if Typed(row, "NestedBlock") then break end
        outer[#outer + 1] = row
    end
    for _, row in ipairs(rows) do
        if row.appended then outer[#outer + 1] = row end
    end
    local nameRow
    for _, row in ipairs(outer) do
        if Typed(row, "SpellName") then nameRow = row break end
    end
    if not nameRow then
        for _, row in ipairs(outer) do
            if row.lineIndex == 1 and Trim(row.left) ~= "" then nameRow = row break end
        end
    end
    if not nameRow then
        for _, row in ipairs(outer) do
            if not row.appended and Trim(row.left) ~= "" then nameRow = row break end
        end
    end

    for _, row in ipairs(rows) do
        local left, right = row.left or "", row.right
        if row == nameRow and not nameTaken then
            nameTaken = true
            model.name = Trim(Patterns.StripTextures(left))
            model.nameColor = row.color
            if right and Trim(right) ~= "" then model.subtitle = Trim(right) end
        elseif Typed(row, "NestedBlock") then
            -- 另一個法術（變形後的版本、召喚物）：之後的 data 行都屬於它
            local sub = NewPart()
            sub.kind = "spell"
            sub.id = S.PlainNumber(row.tooltipID)
            sub.icon = sub.id and game and game.spellIcon and game.spellIcon(sub.id) or nil
            model.nested = sub
            part = sub
        elseif part == model.nested and not part.name and Typed(row, "SpellName") then
            part.name = Trim(Patterns.StripTextures(left))
        elseif row.appended and nextRank and not left:find("|c", 1, true) then
            -- 暴雪自己的行不帶色碼；帶色碼的是別的插件（含我們的 ID 行）接在後面的，歸 extras
            nextRank[#nextRank + 1] = { left = left, right = right, color = row.color, rightColor = row.rightColor }
        elseif row.appended and Patterns.Find("nextRank", Trim(Patterns.StripColors(left))) then
            nextRank = {}
            model.nextRank = { label = Trim(left), rows = nextRank }
        elseif Typed(row, "Blank") or Typed(row, "Separator") then
            -- 描述之後的空行：後面是另一段（實機：復仇之怒的雕紋段「復仇展翅雕紋」／「神聖、懲戒」／金字說明），
            -- 原樣原色自成一段，不拆進主描述或「其他」
            if seenBody or #part.description > 0 then part.tail = part.tail or {} end
        elseif part.tail and not row.appended then
            part.tail[#part.tail + 1] = { left = left, right = right, color = row.color, rightColor = row.rightColor }
        elseif Typed(row, "SpellPassive") and not right then
            part.passive = Trim(left)
        elseif Typed(row, "SpellDescription") then
            seenBody = true
            if Trim(left) ~= "" then part.description[#part.description + 1] = (left:gsub("\r", "")) end
        elseif Typed(row, "UsageRequirement") then
            part.requirements[#part.requirements + 1] = {
                left = Trim(left), right = right, unmet = Unmet(row, left, game),
            }
        else
            local okLeft = Trim(left) == "" or ClassifyText(part, left, row)
            local okRight = not right or ClassifyText(part, right, row)
            if not seenBody and not row.appended and part == model then
                -- 本體之前認不得、但帶顏色的半列 ⇒ 徽章
                if not okLeft and Colored(row.color) then
                    model.tags[#model.tags + 1] = { Trim(left), row.color }
                    okLeft = true
                end
                if not okRight and Colored(row.rightColor) then
                    model.tags[#model.tags + 1] = { Trim(right), row.rightColor }
                    okRight = true
                end
            end
            if part.cost or part.cast or part.cooldown or part.range then seenBody = true end
            if not okLeft and not row.appended and not right and (row.wrap or IsGold(row.color)) then
                -- 沒型別的描述（金字或會換行的單欄長行）
                part.description[#part.description + 1] = left
            elseif not okLeft or not okRight then
                Extra(part, row, okLeft and "" or left, (not okRight) and right or nil, model)
            end
        end
    end

    if not model.name or model.name == "" then return end
    model.id = S.PlainNumber(id)
    model.icon = model.id and game and game.spellIcon and game.spellIcon(model.id) or nil
    return model
end

------------------------------------------------------------
-- 遊戲端介面（測試換成假的）
------------------------------------------------------------
Panel.Game = Panel.Game or {}
local Game = Panel.Game

function Game.spellIcon(id)
    if not (C_Spell and C_Spell.GetSpellTexture) then return end
    local ok, icon = pcall(C_Spell.GetSpellTexture, id)
    return ok and S.PlainNumber(icon) or nil
end

function Game.playerLevel()
    local ok, level = pcall(UnitLevel, "player")
    return ok and S.PlainNumber(level) or nil
end

-- rows／n 可以由呼叫端先讀好（Try 要先比指紋）
Panel.readers.spell = function(tip, data, _, rows, n)
    if not rows then rows, n = Panel.CollectLines(tip, data) end
    if not rows then return end
    local model = Panel.ReadSpellRows(rows, Panel.Game, data.id)
    if not model then return end
    model.rows, model.numLines = rows, n
    return model
end
