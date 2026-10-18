------------------------------------------------------------
-- 法術 view：model → view 表（Render.lua 畫）
--
--   標題：圖示、名字（白）、徽章列（被動｜天賦等級｜副標｜最大充能，0.65 灰、中間 ·）
--   四格（panel.strip）：耗能／施法／冷卻（或充能恢復）／距離，固定順序；缺的格顯示含義並用 0.45 灰。
--     值字級 body+2；耗能值用資源色亮化。格標題不轉大寫（中文沒大寫，enUS 也不轉，保持一致）
--   需求（未達成紅）、描述（整段、數字上色——**只上色不加粗**，FontString 不能局部換字型）、
--   剩餘冷卻（橘）、材料／工具、下一等級（天賦面板）、巢狀法術（小一號標題＋同一套）、其他（0.65 灰）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Panel = ns.Panel
local LOOK = Panel.LOOK

local REMAINING = { 1, 0.6, 0.25 }

local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5))
end

local function Brighten(c)
    return { c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5 }
end
Panel.Brighten = Brighten

local function ClassColor()
    local cls = ns.playerClass
    local c = cls and ((_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[cls])
        or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[cls]))
    if c and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end
Panel.ClassColor = ClassColor

-- 描述數字的色碼：設定 "class"＝職業色亮化、"custom"＝numberCustom 那個色、"none"＝不上色、
-- 六位 hex＝那個色（手改存檔用）
function Panel.NumberHex()
    local p = ns.db and ns.db.panel
    local v = p and p.numberColor or "class"
    if v == "none" then return nil end
    if v == "custom" then
        local c = p.numberCustom
        if type(c) == "table" and type(c.r) == "number" then return Hex({ c.r, c.g, c.b }) end
    end
    if type(v) == "string" and v:match("^%x%x%x%x%x%x$") then return v end
    return Hex(Brighten(ClassColor()))
end

local Option = Panel.Option

------------------------------------------------------------
-- 時間的精簡寫法：從 GlobalStrings 挑短格式（「冷卻時間8秒」→「8秒」），沒把握就整句原樣
------------------------------------------------------------
local SHORT_TIME = {
    SEC = { int = "INT_SPELL_DURATION_SEC", frac = "SPELL_DURATION_SEC" },
    MIN = { int = "INT_SPELL_DURATION_MIN", frac = "SPELL_DURATION_MIN" },
    HOURS = { int = "GARRISON_DURATION_HOURS" },
    DAYS = { int = "DAYS_ABBR" },
}

function Panel.ShortTime(entry)
    if not entry then return end
    local unit = entry.key and entry.key:match("_(%u+)$")
    local spec = unit and SHORT_TIME[unit]
    local n = Panel.Num(entry.value)
    if not spec or not n then return entry.text end
    local isInt = math.floor(n) == n
    local fmt = _G[isInt and spec.int or (spec.frac or spec.int)]
    if type(fmt) ~= "string" then return entry.text end
    local ok, out = pcall(string.format, fmt, isInt and n or n)
    return ok and out or entry.text
end

local function PowerColor(power)
    local colors = _G.PowerBarColor
    local c = power and type(colors) == "table" and colors[power]
    if c and type(c.r) == "number" then return Brighten({ c.r, c.g, c.b }) end
end

------------------------------------------------------------
-- 一段（本體或巢狀）的 sections
------------------------------------------------------------
local function HasCells(part)
    return part.cost or part.cast or part.cooldown or part.range
end

local function Cells(part)
    local cooldownLabel = (part.cooldown and part.cooldown.recharge) and L["Recharge"] or L["Cooldown"]
    return {
        { label = L["Cost"], value = part.cost and part.cost.text or _G.NONE or L["None"],
          color = part.cost and PowerColor(part.cost.power), dim = not part.cost },
        { label = L["Cast"], value = part.cast and Panel.ShortTime(part.cast) or _G.SPELL_CAST_TIME_INSTANT,
          dim = not part.cast },
        { label = cooldownLabel, value = part.cooldown and Panel.ShortTime(part.cooldown) or _G.NONE or L["None"],
          dim = not part.cooldown },
        { label = L["Range"], value = part.range and part.range.text or L["Self"], dim = not part.range },
    }
end

-- 四格關掉時：照原生的兩欄排（耗能｜距離、施法｜冷卻）
local function StatRows(part)
    local rows = {}
    local function pair(l, r)
        if l or r then rows[#rows + 1] = { left = l and l.text or "", right = r and r.text or nil } end
    end
    pair(part.cost, part.range)
    pair(part.cast, part.cooldown)
    return rows
end

local function AddBody(sections, part, numberHex)
    local after = #sections > 0 and { space = LOOK.RULE_SPACE } or nil
    local function push(section)
        section.separator = section.separator or after
        sections[#sections + 1] = section
        after = { space = LOOK.ROW_GAP * 2 }
    end

    if HasCells(part) then
        if Option("strip") then
            push(Panel.Strip(Cells(part)))
            after = { rule = true }
        else
            push({ kind = "rows", rows = StatRows(part) })
        end
    end
    if #part.requirements > 0 then
        local rows = {}
        for i, r in ipairs(part.requirements) do
            rows[i] = { left = r.left, right = r.right, color = r.unmet and LOOK.UNUSABLE or LOOK.TEXT }
        end
        push({ kind = "rows", rows = rows, wrap = true })
    end
    if #part.description > 0 then
        push({ kind = "prose", paragraphs = part.description, numbers = numberHex, color = LOOK.DESCRIPTION })
    end
    if #part.details > 0 then
        local rows = {}
        for i, d in ipairs(part.details) do
            rows[i] = { left = d.left, right = d.right, color = d.remaining and REMAINING or LOOK.SECONDARY }
        end
        push({ kind = "rows", rows = rows, wrap = true })
    end
end

function Panel.ViewSpell(model)
    local view = {
        icon = model.icon, iconSize = LOOK.ICON_SPELL,
        header = { { text = model.name, style = "title", color = LOOK.TEXT } },
        sections = {},
    }
    local badges = {}
    if model.passive then badges[#badges + 1] = { model.passive } end
    if model.talent then badges[#badges + 1] = { model.talent.text } end
    if model.subtitle then badges[#badges + 1] = { model.subtitle } end
    if model.charges then badges[#badges + 1] = { model.charges.text } end
    for _, tag in ipairs(model.tags or {}) do badges[#badges + 1] = { tag[1], tag[2] } end
    if #badges > 0 then view.header[2] = { badges = badges, style = "small" } end

    local numberHex = Panel.NumberHex()
    AddBody(view.sections, model, numberHex)

    if model.nextRank and #model.nextRank.rows > 0 then
        view.sections[#view.sections + 1] = {
            separator = { caption = model.nextRank.label }, kind = "rows", rows = model.nextRank.rows,
            wrap = true, color = LOOK.TEXT,
        }
    end

    local extras = {}
    for _, e in ipairs(model.extras) do extras[#extras + 1] = e end
    local nested = model.nested
    if nested and (nested.name or HasCells(nested) or #nested.description > 0) then
        local sub = {}
        if nested.name then
            view.sections[#view.sections + 1] = {
                separator = { rule = true }, kind = "rows", style = "heading",
                rows = { { left = nested.name, color = LOOK.TEXT } },
            }
        end
        AddBody(sub, nested, numberHex)
        if not nested.name and sub[1] then sub[1].separator = { rule = true } end
        for _, s in ipairs(sub) do view.sections[#view.sections + 1] = s end
        for _, e in ipairs(nested.extras) do extras[#extras + 1] = e end
    end

    if #extras > 0 then
        view.sections[#view.sections + 1] = {
            separator = { rule = true }, kind = "rows", rows = extras, wrap = true, color = LOOK.SECONDARY,
        }
    end
    -- 別人後加的行：附屬框（設定關掉時 RenderView 接回 sections 尾端）
    view.extras = { rows = model.appended or {} }
    return view
end

Panel.views = Panel.views or {}
Panel.views.spell = Panel.ViewSpell
