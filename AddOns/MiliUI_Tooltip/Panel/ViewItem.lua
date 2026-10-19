------------------------------------------------------------
-- 物品 view：model → view 表（Render.lua 畫）
--
--   標題：圖示＋物品等級徽章（panel.levelBadge）；名字（品質色）、「護甲類 · 部位」、
--         「綁定 · 唯一 · 需要等級 N · 技能需求」（未達成紅）、提升等級／製造品質
--   ◆ 分隔：武器（大字每秒傷害＋小字「傷害 · 速度」）／護甲（大字）、屬性（◆ 職業色＋文字，
--         主 1.0／次 0.85／三 0.7，三類之間 Rule；不適用的灰字照灰）
--   ◆ 分隔：效果（小標籤＋綠字）、需求、插槽、附魔、冷卻與其他細節、套裝、風味文字（金）
--   配方：Caption「製造」→ 成品（小圖示＋名字＋一行灰字＋屬性＋效果）、Caption「材料」→ 擁有 / 需要（不足紅）
--   其他（別人加的行、認不得的行）：Rule 後、0.65 灰
--   頁尾帶：需求類（職業／種族／聲望／專精，靠右、未達成紅）、耐久條＋「165 / 165」、售價
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Panel = ns.Panel
local LOOK = Panel.LOOK

local WHITE8 = "Interface\\BUTTONS\\WHITE8X8"

local function Gray(v) return { v, v, v } end

local function Badges(...)
    local out = {}
    for i = 1, select("#", ...) do
        local b = select(i, ...)
        if b and b[1] and b[1] ~= "" then out[#out + 1] = b end
    end
    return out
end

------------------------------------------------------------
-- 自訂段落
------------------------------------------------------------
-- 大數字＋小標籤（＋第二行小字）：每秒傷害、護甲
local function BigStat(value, label, sub)
    local section = { kind = "custom" }
    section.measure = function(_, ctx)
        local w = Panel.Measure(value, ctx.styles.stat) + ctx.m.sc(6) + Panel.Measure(label or "", ctx.styles.small)
        if sub then w = math.max(w, Panel.Measure(sub, ctx.styles.small)) end
        return w + 2 * ctx.m.pad
    end
    section.draw = function(panel, y, ctx)
        local m, st = ctx.m, ctx.styles
        local vw = Panel.Measure(value, st.stat) + 2
        local h = Panel.TextAt(panel, ctx, value, m.pad, y, vw, st.stat, LOOK.TEXT)
        if label and label ~= "" then
            local lw = Panel.Measure(label, st.small) + 2
            -- 小字對齊大字的下緣
            Panel.TextAt(panel, ctx, label, m.pad + vw + m.sc(4), y + (st.stat.size - st.small.size), lw,
                st.small, LOOK.SECONDARY)
        end
        y = y + h
        if sub and sub ~= "" then
            y = y + Panel.TextAt(panel, ctx, sub, m.pad, y, panel.width - 2 * m.pad, st.small, LOOK.SECONDARY)
        end
        return y + m.rowGap
    end
    return section
end
Panel.BigStat = BigStat

-- 屬性列：前面一顆 ◆（職業色），文字照分類的明暗；次要屬性照暴雪原生是綠字，
-- 但原生那個 (0,1,0) 太亮（2026-10-19 使用者），改用跟使用／裝備效果同一個綠（LOOK.EFFECT）。
-- 三屬性（速度、汲取、迴避、不滅）原生也是同一個綠 ⇒ 跟次要屬性一樣（N3：以前畫成灰字）
local function StatList(stats)
    local markers = Panel.Option("statMarkers")
    local section = { kind = "custom" }
    local function textOf(s) return s.text end
    section.measure = function(_, ctx)
        local w = 0
        for _, s in ipairs(stats) do w = math.max(w, Panel.Measure(textOf(s), ctx.styles.body)) end
        local lead = markers and (ctx.m.diamond * 2 + ctx.m.sc(2)) or 0
        return w + lead + 2 * ctx.m.pad
    end
    section.draw = function(panel, y, ctx)
        local m, style = ctx.m, ctx.styles.body
        local lead = markers and (m.diamond * 2 + m.sc(2)) or 0
        for _, s in ipairs(stats) do
            local shade = LOOK.STAT_SHADE[s.category] or LOOK.STAT_SHADE.other
            -- 不適用的（同職業其他專精的主屬性＝DisabledLine、或原本就灰字）：文字與 ◆ 都灰，不用職業色
            local dim = s.disabled or Panel.IsGray(s.color)
            local color
            if dim then
                color = LOOK.DIM
            elseif s.category == "secondary" or s.category == "tertiary" then
                color = LOOK.EFFECT
            else
                color = Gray(shade)
            end
            local h = Panel.TextAt(panel, ctx, textOf(s), m.pad + lead, y, panel.width - 2 * m.pad - lead, style, color)
            if markers then
                local d = Panel.Texture(panel, 2)
                d:SetSize(m.diamond, m.diamond)
                d:SetPoint("CENTER", panel, "TOPLEFT", m.pad + m.diamond * 0.75,
                    -Panel.Snap(panel, y + style.size / 2 + 1))
                d:SetRotation(math.rad(45))
                local c = dim and LOOK.DIM or ctx.accent
                d:SetVertexColor(c[1], c[2], c[3], LOOK.DIAMOND_ALPHA)
            end
            y = y + h + m.rowGap
        end
        return y
    end
    return section
end

-- 效果：小標籤（使用／裝備／擊中時可能）一行，正文綠字一段
local function Effects(effects)
    local section = { kind = "custom" }
    section.measure = function(_, ctx)
        local w = 0
        for _, e in ipairs(effects) do
            w = math.max(w, Panel.Measure(e.label or "", ctx.styles.small),
                math.min(Panel.Measure(e.text, ctx.styles.body), ctx.m.proseW))
        end
        return w + 2 * ctx.m.pad
    end
    section.draw = function(panel, y, ctx)
        local m = ctx.m
        for i, e in ipairs(effects) do
            if i > 1 then y = y + m.rowGap * 2 end
            if e.label and e.label ~= "" then
                y = Panel.DrawRow(panel, ctx, { left = e.label }, y, ctx.styles.small, LOOK.SECONDARY, 0, 0)
            end
            y = Panel.DrawRow(panel, ctx, { left = e.text }, y, ctx.styles.body, LOOK.EFFECT)
        end
        return y
    end
    return section
end

-- 配方成品的標題：小圖示＋名字（品質色）＋一行灰字
local function CreatedHeader(created)
    local section = { kind = "custom" }
    local sub = Panel.BadgeText(Badges({ created.armorType }, { created.slot },
        created.levelReq and { created.levelReq.text, created.levelReq.unmet and LOOK.UNUSABLE or nil }))
    section.measure = function(_, ctx)
        local icon = created.icon and (ctx.m.sc(LOOK.CREATED_ICON) + ctx.m.iconGap) or 0
        return math.max(Panel.Measure(created.name or "", ctx.styles.heading), Panel.Measure(sub, ctx.styles.small))
            + icon + 2 * ctx.m.pad
    end
    section.draw = function(panel, y, ctx)
        local m = ctx.m
        local size = m.sc(LOOK.CREATED_ICON)
        local indent = 0
        if created.icon then
            local r, g, b, a = Panel.BorderColor(ctx.state)
            local border = Panel.Texture(panel, 1)
            border:SetPoint("TOPLEFT", panel, "TOPLEFT", m.pad - m.px, -(y - m.px))
            border:SetSize(size + 2 * m.px, size + 2 * m.px)
            border:SetVertexColor(r, g, b, a)
            local icon = Panel.Texture(panel, 2)
            icon:SetTexture(created.icon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetPoint("TOPLEFT", panel, "TOPLEFT", m.pad, -y)
            icon:SetSize(size, size)
            indent = size + m.iconGap
        end
        local top = y
        local inner = panel.width - 2 * m.pad - indent
        y = y + Panel.TextAt(panel, ctx, created.name or "", m.pad + indent, y, inner, ctx.styles.heading,
            created.nameColor or LOOK.TEXT)
        if sub ~= "" then
            y = y + Panel.TextAt(panel, ctx, sub, m.pad + indent, y, inner, ctx.styles.small, LOOK.SECONDARY)
        end
        return math.max(y, top + (created.icon and size or 0)) + m.rowGap * 2
    end
    return section
end

-- 頁尾帶：需求類（靠右）、耐久條＋數字、售價（堆疊物品畫「單價 ×數量 = 總價」，單價拿不到就只畫總價）
local function PriceText(model)
    local total = model.price and Panel.Coins(model.price)
    if not total then return nil end
    local unit = model.unitPrice and model.stackCount and model.stackCount > 1 and Panel.Coins(model.unitPrice)
    if not unit then return total end
    return ("%s ×%d = %s"):format(unit, model.stackCount, total)
end
Panel.PriceText = PriceText

local function Footer(model)
    local coins = PriceText(model)
    local dur = model.durability
    if not coins and not dur and #model.restrictions == 0 then return nil end
    local footer = {}
    footer.measure = function(_, ctx)
        local m, w = ctx.m, 0
        for _, r in ipairs(model.restrictions) do w = math.max(w, Panel.Measure(r.text, ctx.styles.small)) end
        local row = 0
        if dur then row = m.sc(LOOK.BAR_W) + m.sc(6) + Panel.Measure(("%d / %d"):format(dur.cur or 0, dur.max or 0), ctx.styles.small) end
        if coins then row = row + m.columnGap + Panel.Measure(coins, ctx.styles.body) end
        if not dur and coins then row = row + Panel.Measure(_G.SELL_PRICE or "", ctx.styles.small) end
        return math.max(w, row) + 2 * m.pad
    end
    footer.draw = function(panel, y, ctx)
        local m, st = ctx.m, ctx.styles
        local last = (not dur and not coins) and #model.restrictions or nil
        for i, r in ipairs(model.restrictions) do
            -- 回傳的 y 不帶行距（頁尾帶內上下同距，Render 的 footerPad）
            y = Panel.DrawRow(panel, ctx, { left = "", right = r.text }, y, st.small,
                r.unmet and LOOK.UNUSABLE or LOOK.SECONDARY, 0, (i == last) and 0 or ctx.m.rowGap)
        end
        if not dur and not coins then return y end
        local rowH = math.max(st.small.size, coins and st.body.size or 0) + 2
        if dur then
            local bw, bh = m.sc(LOOK.BAR_W), m.sc(LOOK.BAR_H)
            local by = y + Panel.Snap(panel, (rowH - bh) / 2)
            local track = Panel.Texture(panel, 1)
            track:SetPoint("TOPLEFT", panel, "TOPLEFT", m.pad, -by)
            track:SetSize(bw, bh)
            track:SetVertexColor(0.06, 0.06, 0.06, 1)
            local frac = (dur.max and dur.max > 0) and math.max(0, math.min(1, (dur.cur or 0) / dur.max)) or 0
            if frac > 0 then
                local fill = Panel.Texture(panel, 2)
                local satin = ns.Media.BarTexture and ns.Media.BarTexture("satin") or WHITE8
                fill:SetTexture(satin)
                fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
                fill:SetSize(Panel.Snap(panel, bw * frac), bh)
                local c = ctx.accent
                fill:SetVertexColor(c[1], c[2], c[3], 1)
            end
            local text = ("%d / %d"):format(dur.cur or 0, dur.max or 0)
            Panel.TextAt(panel, ctx, text, m.pad + bw + m.sc(6), y + (rowH - st.small.size - 2) / 2,
                Panel.Measure(text, st.small) + 2, st.small, LOOK.SECONDARY)
        elseif coins then
            Panel.TextAt(panel, ctx, _G.SELL_PRICE or "", m.pad, y + (rowH - st.small.size - 2) / 2,
                Panel.Measure(_G.SELL_PRICE or "", st.small) + 2, st.small, LOOK.SECONDARY)
        end
        if coins then
            local cw = Panel.Measure(coins, st.body) + 2
            Panel.TextAt(panel, ctx, coins, panel.width - m.pad - cw, y, cw, st.body, LOOK.TEXT, "RIGHT")
        end
        return y + rowH
    end
    return footer
end

------------------------------------------------------------
-- 主體各段（本體與配方成品共用）
------------------------------------------------------------
local function StatsSections(part)
    local out = {}
    local w = part.weapon
    if w and w.dps then
        local sub = Panel.BadgeText(Badges({ w.damage and w.damage.text }, { w.speed and w.speed.text }))
        out[#out + 1] = BigStat(w.dps.value, _G.DAMAGE_PER_SECOND, sub ~= "" and sub or nil)
    elseif w and (w.damage or w.speed) then
        out[#out + 1] = { kind = "rows", rows = { { left = w.damage and w.damage.text or "", right = w.speed and w.speed.text } } }
    end
    -- 護甲（盾牌的格擋寫在第二行小字，跟武器的「傷害 · 速度」同款）
    if part.armor then
        out[#out + 1] = BigStat(part.armor.value, _G.ARMOR, part.block and part.block.text or nil)
    elseif part.block then
        out[#out + 1] = { kind = "rows", rows = { { left = part.block.text } } }
    end
    -- 屬性照分類分組；組間 Rule
    local order, groups = { "primary", "secondary", "tertiary", "other" }, {}
    for _, s in ipairs(part.stats) do
        groups[s.category] = groups[s.category] or {}
        table.insert(groups[s.category], s)
    end
    local first = true
    for _, cat in ipairs(order) do
        if groups[cat] then
            local section = StatList(groups[cat])
            if not first then section.separator = { rule = true } end
            out[#out + 1] = section
            first = false
        end
    end
    return out
end

local function RowsOf(list, colorFn)
    local rows = {}
    for i, r in ipairs(list) do rows[i] = { left = r.left or r.text or "", right = r.right, color = colorFn(r) } end
    return rows
end

local function BodySections(part)
    local out = {}
    local function add(section) out[#out + 1] = section end
    if #part.effects > 0 then add(Effects(part.effects)) end
    if #part.requirements > 0 then
        add({ kind = "rows", wrap = true, rows = RowsOf(part.requirements, function(r) return r.unmet and LOOK.UNUSABLE or LOOK.TEXT end) })
    end
    if #part.sockets > 0 then
        -- 寶石圖示（gemIcon）或空插槽圖示接在文字前面，拆成貼圖另外畫（Panel.TextAt）
        local rows = {}
        for i, r in ipairs(part.sockets) do
            local icon = r.gemIcon or (r.socketType and ("Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. r.socketType))
            rows[i] = { left = icon and ("|T" .. icon .. ":0|t " .. r.left) or r.left, right = r.right, color = r.color }
        end
        add({ kind = "rows", wrap = true, rows = rows })
    end
    if #part.enchants > 0 then add({ kind = "rows", wrap = true, rows = RowsOf(part.enchants, function(r) return r.color end) }) end
    local details = {}
    for _, d in ipairs(part.details) do
        details[#details + 1] = { left = d.left, color = d.color or (d.remaining and { 1, 0.6, 0.25 }) or LOOK.SECONDARY }
    end
    if part.maker then details[#details + 1] = { left = part.maker } end
    if #details > 0 then add({ kind = "rows", wrap = true, rows = details }) end
    local set = part.set
    if set or (part.bonuses and #part.bonuses > 0) then
        local rows = {}
        if set then
            rows[1] = { left = set.name, right = ("%d/%d"):format(set.owned or 0, set.total or 0), color = LOOK.SET_NAME }
            for _, it in ipairs(set.items) do
                rows[#rows + 1] = { left = "- " .. it.text, indent = 8, color = it.owned and LOOK.TEXT or LOOK.DIM }
            end
        end
        for _, b in ipairs((set and set.bonuses) or part.bonuses or {}) do
            rows[#rows + 1] = { left = b.text, color = b.active and LOOK.EFFECT or LOOK.DIM }
        end
        add({ kind = "rows", wrap = true, rows = rows, separator = { rule = true } })
    end
    if #part.flavor > 0 then add({ kind = "prose", paragraphs = part.flavor, color = LOOK.FLAVOR }) end
    return out
end

-- 段落組之間用 Divider，組內段落之間留一點空（自己指定 separator 的不動）
local function Join(view, groups, divider)
    for _, group in ipairs(groups) do
        if #group > 0 then
            for i, section in ipairs(group) do
                if i == 1 then
                    if #view.sections > 0 or divider then
                        section.separator = divider and { divider = true } or { rule = true }
                    end
                elseif not section.separator then
                    section.separator = { space = LOOK.ROW_GAP * 3 }
                end
                view.sections[#view.sections + 1] = section
            end
        end
    end
end

------------------------------------------------------------
-- view
------------------------------------------------------------
function Panel.ViewItem(model)
    local badgeOn = Panel.Option("levelBadge")
    local ilvl = model.itemLevel
    local view = {
        icon = model.icon, iconSize = LOOK.ICON_ITEM,
        badge = (badgeOn and ilvl and ilvl.value) and tostring(ilvl.value) or nil,
        header = { { text = model.name, style = "title", color = model.nameColor or LOOK.TEXT } },
        sections = {},
        tag = model.tag,
    }
    local line1 = Badges({ model.armorType }, { model.slot }, { model.quality },
        (not view.badge and ilvl) and { ilvl.text } or nil)
    if #line1 > 0 then view.header[#view.header + 1] = { badges = line1, style = "small" } end
    local unique = model.unique[1]
    local line2 = Badges({ model.binding }, { unique },
        model.levelReq and { model.levelReq.text, model.levelReq.unmet and LOOK.UNUSABLE or nil } or nil,
        model.skill and { model.skill.text, model.skill.unmet and LOOK.UNUSABLE or nil } or nil)
    if #line2 > 0 then view.header[#view.header + 1] = { badges = line2, style = "small" } end
    local more = {}
    -- 標題補充行（難度、虛無鍛造、已塑形為…）：原字串、原色
    for _, r in ipairs(model.headerRows or {}) do more[#more + 1] = { left = r.left, color = r.color } end
    for i = 2, #model.unique do more[#more + 1] = { left = model.unique[i] } end
    if model.upgrade then more[#more + 1] = { left = model.upgrade } end
    if model.craftQuality then more[#more + 1] = { left = model.craftQuality } end
    if #more > 0 then view.header[#view.header + 1] = { rows = more, style = "small", color = LOOK.SECONDARY } end

    Join(view, { StatsSections(model) }, true)
    Join(view, { BodySections(model) }, true)

    -- 配方
    local created = model.created
    if created and (created.name or #created.stats > 0) then
        local group = { CreatedHeader(created) }
        group[1].separator = { caption = L["Creates"] }
        for _, s in ipairs(StatsSections(created)) do group[#group + 1] = s end
        for _, s in ipairs(BodySections(created)) do group[#group + 1] = s end
        for i, s in ipairs(group) do
            if i > 1 and not s.separator then s.separator = { space = LOOK.ROW_GAP * 3 } end
            view.sections[#view.sections + 1] = s
        end
    end
    if model.reagents and #model.reagents > 0 then
        local rows = {}
        for i, r in ipairs(model.reagents) do
            local name = r.icon and ("|T%s:%d|t %s"):format(r.icon, LOOK.REAGENT_ICON, r.name) or r.name
            local enough = r.have == nil or r.have >= r.count
            rows[i] = {
                left = name,
                right = r.have and ("%d / %d"):format(r.have, r.count) or tostring(r.count),
                color = LOOK.TEXT, rightColor = enough and LOOK.TEXT or LOOK.UNUSABLE,
            }
        end
        view.sections[#view.sections + 1] = { separator = { caption = L["Reagents"] }, kind = "rows", rows = rows }
    end

    local extras = {}
    for _, e in ipairs(model.extras) do extras[#extras + 1] = e end
    if created then for _, e in ipairs(created.extras) do extras[#extras + 1] = e end end
    if #extras > 0 then
        view.sections[#view.sections + 1] = {
            separator = { rule = true }, kind = "rows", rows = extras, wrap = true, color = LOOK.SECONDARY,
        }
    end

    view.footer = Footer(model)
    -- 別人後加的行：附屬框（設定關掉時 RenderView 接回 sections 尾端）
    view.extras = { rows = model.appended or {} }
    return view
end

Panel.views = Panel.views or {}
Panel.views.item = Panel.ViewItem
