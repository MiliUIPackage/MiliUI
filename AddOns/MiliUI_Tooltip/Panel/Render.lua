------------------------------------------------------------
-- 重繪面板：view 表 → 畫
--
-- view 是一張純資料表，由各型別的 view 函式從 reader 的 model 組出來（版面骨架參考成熟同類實作）。
-- 寬度照內容量出來，量與畫用同一套函式，兩邊不會對不上。
--
-- view = {
--     icon = 貼圖, iconSize = 設計單位,       標題各行從圖示右邊開始
--     portrait = 單位 token, portraitKey = 字串  單位頭像（SetPortraitTexture）；key 一樣就不重抓，icon 當讀不到時的退路
--     badge = "字", badgeColor = { r, g, b }, 圖示上方的等級徽章（字色省略＝白）
--     badgeBelow = true,                      徽章改放圖示下方（單位：跟暴雪目標框一樣，等級在頭像底下）
--     header = {                              依序，在圖示旁
--         { text = "名字", style = "title", color = { r, g, b } },
--         { badges = { { "被動", color }, { "等級 2/3" } }, style = "small" },   中間用 · 隔開
--         { rows = { { left = , right = , color = , rightColor = } }, style = "body" },
--     },
--     tag = "已裝備",                         比價框：panel 左上方外側的小標籤
--     sections = {                            依序，在標題區下面
--         { separator = { divider = true } | { rule = true } | { caption = "材料" } | { space = n },
--           kind = "prose", paragraphs = { ... }, style, color, numbers = "hex" },
--         { separator = ..., kind = "rows", rows = { { left, right, color, rightColor, indent } },
--           style, color, wrap = true },     wrap：沒有右欄的行在段落寬換行
--         { kind = "custom", draw = function(panel, y, ctx) return y end,
--           measure = function(panel, ctx) return width end },
--     },
--     footer = { rows = { ... }, style, color }   底部實心帶
--             | { draw = function(panel, y, ctx) return y end, measure = function(panel, ctx) return w end },
--     minWidth = 設計單位,
--     decorate = function(panel, ctx) end,   全部畫完（寬高已定）之後再補的裝飾（單位的陣營浮水印）
-- }
--
-- 色一律是明文 { r, g, b }；邊框色例外（Skin 給的，可能是秘密分量，只交給 SetVertexColor）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel
local Patterns = ns.Patterns
local LOOK = Panel.LOOK

local BADGE_SEPARATOR = " · "

------------------------------------------------------------
-- 一次 render 的量尺寸（設計單位 → 貼好像素的 panel 單位）
------------------------------------------------------------
local function Metrics(panel)
    local function sc(n) return Panel.Scale(panel, n) end
    return {
        px = Panel.Pixel(panel, 1),
        pad = sc(LOOK.PAD),
        padTop = sc(LOOK.PAD + LOOK.PAD_TOP_EXTRA),
        padBottom = sc(LOOK.PAD + LOOK.PAD_BOTTOM_EXTRA),
        minW = sc(LOOK.MIN_W), maxW = sc(LOOK.MAX_W), proseW = sc(LOOK.PROSE_W),
        columnGap = sc(LOOK.COLUMN_GAP),
        rowGap = sc(LOOK.ROW_GAP),
        headerGap = sc(LOOK.HEADER_GAP),
        headerBottom = sc(LOOK.HEADER_BOTTOM),
        ruleSpace = sc(LOOK.RULE_SPACE),
        diamond = sc(LOOK.DIAMOND),
        captionLineGap = sc(LOOK.CAPTION_LINE_GAP),
        iconGap = sc(LOOK.ICON_GAP),
        badgeGap = sc(LOOK.BADGE_GAP), badgeH = sc(LOOK.BADGE_H), badgePad = sc(LOOK.BADGE_PAD),
        footerTop = sc(LOOK.FOOTER_TOP), footerPad = sc(LOOK.FOOTER_PAD),
        closeSize = sc(LOOK.CLOSE_SIZE), closeLen = sc(LOOK.CLOSE_LEN), closeThick = sc(LOOK.CLOSE_THICK),
        tagH = sc(LOOK.TAG_H), tagPad = sc(LOOK.TAG_PAD), tagGap = sc(LOOK.TAG_GAP),
        edgeMargin = sc(LOOK.EDGE_MARGIN),
        sc = sc,
    }
end
Panel.Metrics = Metrics

local function StyleOf(ctx, style)
    if type(style) == "table" then return style end
    return ctx.styles[style or "body"] or ctx.styles.body
end

local function Separators()
    local p = ns.db and ns.db.panel
    return not p or p.separators ~= false
end

------------------------------------------------------------
-- 原件
------------------------------------------------------------
-- 拆出來的行內圖示：貼一張貼圖，垂直置中在 cy
local function DrawInlineIcon(panel, icon, x, cy, style)
    local w, h = Panel.IconSize(icon, style)
    local tex = Panel.Texture(panel, 3)
    if icon.atlas then
        tex:SetAtlas(icon.atlas)
    else
        tex:SetTexture(icon.file)
        if icon.coords then tex:SetTexCoord(icon.coords[1], icon.coords[2], icon.coords[3], icon.coords[4]) end
    end
    tex:SetSize(w, h)
    tex:SetPoint("LEFT", panel, "TOPLEFT", x, -cy)
    return w, h
end

local TextAtRaw

-- 頭／尾圖示比一行字高時，多出來的那截要**上下各分一半**：圖示是垂直置中在那一行上的，
-- 只把高度往下加的話上緊下鬆（2026-10-19：附魔行尾的品質圖示，上離 ◆ 線近、下離細線遠）。
-- 回傳 (top, bottom)：字要往下讓的量、最後一行底下要多留的量。換行時頭圖示只管第一行、尾圖示只管最後一行
local function IconPads(lead, body, trail, style, width)
    if not lead and not trail then return 0, 0 end
    local lineH = style.size + 2
    local gap = Panel.ICON_TEXT_GAP
    local function over(icon)
        if not icon then return 0 end
        local _, h = Panel.IconSize(icon, style)
        return math.max(0, (h - lineH) / 2)
    end
    local textW = width
    if lead and body ~= "" then textW = textW - Panel.IconSize(lead, style) - gap end
    if trail then textW = textW - Panel.IconSize(trail, style) - ((body ~= "") and gap or 0) end
    local leadO, trailO = over(lead), over(trail)
    if body ~= "" and Panel.MeasureRaw(body, style) > textW then return leadO, trailO end
    local o = math.max(leadO, trailO)
    return o, o
end

-- 一段字的頂端要往下讓多少（DrawRow 左右兩欄對齊用）
function Panel.TextTopPad(text, style, width)
    local lead, body, trail = Panel.SplitIcons(text)
    return (IconPads(lead, body, trail, style, width))
end

-- 一段字放在 (x, y)、寬 width；回傳佔掉的高。頭／尾那一顆行內圖示拆出來另外畫（Panel.SplitIcons）
local function TextAt(panel, ctx, text, x, y, width, style, color, justify)
    local lead, body, trail = Panel.SplitIcons(text)
    if not lead and not trail then
        return TextAtRaw(panel, ctx, text, x, y, width, style, color, justify)
    end
    local top, bottom = IconPads(lead, body, trail, style, width)
    local y0 = y
    y = y + top
    local gap = Panel.ICON_TEXT_GAP
    local lineH = style.size + 2
    if lead then
        local w = DrawInlineIcon(panel, lead, x, y + lineH / 2, style)
        if body ~= "" then x, width = x + w + gap, width - w - gap end
    end
    local textW, tw, th = width, 0, 0
    if trail then
        local w = Panel.IconSize(trail, style)
        textW = width - w - ((body ~= "") and gap or 0)
    end
    if body ~= "" then
        th = TextAtRaw(panel, ctx, body, x, y, textW, style, color, justify)
        tw = math.min(Panel.MeasureRaw(body, style), textW)
    end
    if trail then
        local ix
        if justify == "RIGHT" then
            ix = x + textW + gap
        elseif justify == "CENTER" then
            ix = x + (textW + tw) / 2 + gap
        else
            ix = x + tw + ((body ~= "") and gap or 0)
        end
        -- 文字換行了：貼在最後一行
        local wrapped = body ~= "" and Panel.MeasureRaw(body, style) > textW
        local cy = wrapped and (y + th - lineH / 2) or (y + lineH / 2)
        DrawInlineIcon(panel, trail, ix, cy, style)
    end
    return (y - y0) + math.max(th, lineH) + bottom
end

function TextAtRaw(panel, ctx, text, x, y, width, style, color, justify)
    local fs = Panel.Text(panel, style)
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    color = color or LOOK.TEXT
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText(text)
    local h = S.PlainNumber(fs:GetStringHeight()) or 0
    return math.max(style.size + 2, h)
end
Panel.TextAt = TextAt

-- 一列：左欄（可換行）＋右欄（靠右、自動量寬）
local function RowWidth(row, style, columnGap)
    local w = Panel.Measure(row.left or "", style)
    if row.right and row.right ~= "" then
        -- +2 跟 DrawRow 給右欄的餘裕一致
        w = w + (columnGap or LOOK.COLUMN_GAP) + Panel.Measure(row.right, style) + 2
    end
    return w
end
Panel.RowWidth = RowWidth

local function DrawRow(panel, ctx, row, y, style, color, indent, gap)
    local m = ctx.m
    indent, gap = indent or 0, gap or m.rowGap
    local inner = panel.width - 2 * m.pad - indent
    local left, right = row.left or "", row.right
    local leftColor = row.color or color
    if right and right ~= "" then
        local rightW = math.min(Panel.Measure(right, style) + 2,
            math.max(inner * 0.5, inner - Panel.Measure(left, style) - m.columnGap))
        local leftW = inner - rightW - m.columnGap
        -- 兩欄第一行對齊：圖示撐高的那一欄往下讓多少，另一欄也跟著讓
        local lt, rt = Panel.TextTopPad(left, style, leftW), Panel.TextTopPad(right, style, rightW)
        local top = math.max(lt, rt)
        local lh = TextAt(panel, ctx, left, m.pad + indent, y + top - lt, leftW, style, leftColor) + top - lt
        local rh = TextAt(panel, ctx, right, panel.width - m.pad - rightW, y + top - rt, rightW, style,
            row.rightColor or leftColor, "RIGHT") + top - rt
        return y + math.max(lh, rh) + gap
    end
    return y + TextAt(panel, ctx, left, m.pad + indent, y, inner, style, leftColor) + gap
end
Panel.DrawRow = DrawRow

local function Line(panel, ctx, x, y, w, color, alpha)
    local tex = Panel.Texture(panel, 1)
    tex:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -Panel.Snap(panel, y))
    tex:SetSize(w, ctx.m.px)
    color = color or LOOK.TEXT
    tex:SetVertexColor(color[1], color[2], color[3], alpha or LOOK.LINE_ALPHA)
    return tex
end

-- 整寬 1px 線；before 是線上方的空白（省略＝RULE_SPACE）。
-- 下方多補一個 rowGap：上方已經有前一行尾端的 rowGap，這樣線離上下文字一樣遠
local function Rule(panel, ctx, y, before)
    local m = ctx.m
    y = y + (before or m.ruleSpace)
    if not Separators() then return y end
    Line(panel, ctx, m.pad, y, panel.width - 2 * m.pad)
    return y + m.px + m.ruleSpace + m.rowGap
end
Panel.Rule = Rule

-- 左右兩段 1px 線 ＋ 中央 ◆（玩家職業色）
-- 間距跟 Rule 一樣（線的位置相同），◆ 置中在線上
local function Divider(panel, ctx, y, before)
    local m = ctx.m
    y = y + (before or m.ruleSpace)
    if not Separators() then return y end
    local d = m.diamond
    -- ◆ 是正方形轉 45°，外接寬約 d·√2；兩側線各留一點空
    local gap = Panel.Snap(panel, d * 0.75 + m.px * 3)
    local side = Panel.Snap(panel, (panel.width - 2 * m.pad) / 2 - gap)
    local mid = y
    Line(panel, ctx, m.pad, mid, side)
    Line(panel, ctx, panel.width - m.pad - side, mid, side)
    local diamond = Panel.Texture(panel, 2)
    diamond:SetSize(d, d)
    diamond:SetPoint("CENTER", panel, "TOP", 0, -(Panel.Snap(panel, mid) + m.px / 2))
    diamond:SetRotation(math.rad(45))
    local c = ctx.accent
    diamond:SetVertexColor(c[1], c[2], c[3], LOOK.DIAMOND_ALPHA)
    return mid + m.px + m.ruleSpace + m.rowGap
end
Panel.Divider = Divider

-- 置中小字 ＋ 左右兩條線
local function Caption(panel, ctx, y, text, before)
    local m = ctx.m
    local style = ctx.styles.caption
    y = y + (before or m.ruleSpace)
    local tw = Panel.Measure(text, style) + 2
    local gray = { LOOK.CAPTION_GRAY, LOOK.CAPTION_GRAY, LOOK.CAPTION_GRAY }
    local h = TextAt(panel, ctx, text, (panel.width - tw) / 2, y, tw, style, gray, "CENTER")
    if Separators() then
        local side = (panel.width - 2 * m.pad - tw) / 2 - m.captionLineGap
        if side > 0 then
            local mid = y + math.floor(style.size / 2) + 1
            side = Panel.Snap(panel, side)
            Line(panel, ctx, m.pad, mid, side)
            Line(panel, ctx, panel.width - m.pad - side, mid, side)
        end
    end
    return y + h + m.ruleSpace + m.rowGap
end
Panel.Caption = Caption

local function DrawSeparator(panel, ctx, y, sep)
    if not sep then return y end
    if sep.divider then return Divider(panel, ctx, y, sep.before) end
    if sep.rule then return Rule(panel, ctx, y, sep.before) end
    if sep.caption then return Caption(panel, ctx, y, sep.caption, sep.before) end
    return y + ctx.m.sc(sep.space or 0)
end

local function BadgeText(list)
    local words = {}
    for i, badge in ipairs(list) do
        local c = badge[2]
        if c then
            words[i] = ("|cff%02x%02x%02x%s|r"):format(
                math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5), badge[1])
        else
            words[i] = badge[1]
        end
    end
    return table.concat(words, BADGE_SEPARATOR)
end
Panel.BadgeText = BadgeText

------------------------------------------------------------
-- Strip：一排等寬的格子（格標題小字灰 ＋ 值大字），格間 1px 直線。
-- 法術的「耗能／施法／冷卻／距離」（P2）用；回傳一個 custom section。
--   cells = { { label = "耗能", value = "50 法力", color = { r, g, b }, dim = true }, ... }
------------------------------------------------------------
function Panel.Strip(cells)
    local section = { kind = "custom", strip = true }
    section.measure = function(panel, ctx)
        local m, widest = ctx.m, 0
        for _, cell in ipairs(cells) do
            widest = math.max(widest, Panel.Measure(cell.label or "", ctx.styles.caption),
                Panel.Measure(cell.value or "", ctx.styles.big))
        end
        return #cells * (widest + 2 * m.pad) + 2 * m.pad
    end
    section.draw = function(panel, y, ctx)
        local m, n = ctx.m, #cells
        if n == 0 then return y end
        local inner = panel.width - 2 * m.pad
        local cellW = inner / n
        local bottom = y
        for i, cell in ipairs(cells) do
            local x = m.pad + (i - 1) * cellW
            local ly = y + TextAt(panel, ctx, cell.label or "", x, y, cellW, ctx.styles.caption,
                LOOK.SECONDARY, "CENTER")
            local color = cell.dim and LOOK.DIM or (cell.color or LOOK.TEXT)
            ly = ly + TextAt(panel, ctx, cell.value or "", x, ly, cellW, ctx.styles.big, color, "CENTER")
            bottom = math.max(bottom, ly)
            if i > 1 and Separators() then
                local tex = Panel.Texture(panel, 1)
                tex:SetPoint("TOPLEFT", panel, "TOPLEFT", Panel.Snap(panel, x), -Panel.Snap(panel, y))
                tex:SetSize(m.px, Panel.Snap(panel, ly - y))
                tex:SetVertexColor(1, 1, 1, LOOK.LINE_ALPHA)
            end
        end
        return bottom + m.rowGap
    end
    return section
end

------------------------------------------------------------
-- 段落
------------------------------------------------------------
local DRAW = {
    prose = function(panel, ctx, y, section)
        local style = StyleOf(ctx, section.style)
        for _, text in ipairs(section.paragraphs or {}) do
            if section.numbers then text = Patterns.ColorNumbers(text, section.numbers) end
            y = DrawRow(panel, ctx, { left = text }, y, style, section.color or LOOK.DESCRIPTION, 0, section.gap)
        end
        return y
    end,
    rows = function(panel, ctx, y, section)
        local style = StyleOf(ctx, section.style)
        for _, row in ipairs(section.rows or {}) do
            y = DrawRow(panel, ctx, row, y, style, section.color, ctx.m.sc(row.indent or 0), section.gap)
        end
        return y
    end,
    custom = function(panel, ctx, y, section)
        return section.draw(panel, y, ctx)
    end,
}

------------------------------------------------------------
-- 寬度：view 裡最寬的東西＋左右內距，夾在上下限之間
------------------------------------------------------------
local function IconIndent(ctx, view)
    if not view.icon and not view.portrait then return 0 end
    return ctx.m.sc(view.iconSize or LOOK.ICON_ITEM) + ctx.m.iconGap
end

local function FitWidth(panel, ctx, view)
    local m = ctx.m
    local indent, need = IconIndent(ctx, view), 0
    local function consider(w) if w > need then need = w end end
    for _, item in ipairs(view.header or {}) do
        local style = StyleOf(ctx, item.style)
        if item.text then
            consider(math.min(Panel.Measure(item.text, style), m.maxW) + indent)
        elseif item.badges and #item.badges > 0 then
            consider(Panel.Measure(BadgeText(item.badges), style) + indent)
        elseif item.rows then
            for _, row in ipairs(item.rows) do consider(RowWidth(row, style, m.columnGap) + indent) end
        end
    end
    for _, section in ipairs(view.sections or {}) do
        local style = StyleOf(ctx, section.style)
        if section.kind == "prose" then
            for _, text in ipairs(section.paragraphs or {}) do
                consider(math.min(Panel.Measure(text, style), m.proseW))
            end
        elseif section.kind == "rows" then
            for _, row in ipairs(section.rows or {}) do
                local w = RowWidth(row, style, m.columnGap)
                if section.wrap and (not row.right or row.right == "") then w = math.min(w, m.proseW) end
                consider(w + m.sc(row.indent or 0))
            end
        elseif section.kind == "custom" and section.measure then
            consider(section.measure(panel, ctx))
        end
        if section.separator and section.separator.caption then
            consider(Panel.Measure(section.separator.caption, ctx.styles.caption) + 2 * m.captionLineGap)
        end
    end
    local footer = view.footer
    if footer then
        if footer.measure then consider(footer.measure(panel, ctx)) end
        local style = StyleOf(ctx, footer.style)
        for _, row in ipairs(footer.rows or {}) do consider(RowWidth(row, style, m.columnGap)) end
    end
    local minW = view.minWidth and m.sc(view.minWidth) or m.minW
    return math.max(minW, math.min(m.maxW, math.ceil(need + 2 * m.pad)))
end
Panel.FitWidth = FitWidth

------------------------------------------------------------
-- 圖示、徽章、關閉鈕、比價標籤
------------------------------------------------------------
-- 回傳標題區至少要多高（徽章＋圖示）。徽章在**上**、圖示在下（2026-10-19 使用者要求對調：
-- 等級數字跟名字同一列高度，一眼先看到等級）；徽章置中在圖示欄上
local function SetIcon(icon, panel, view)
    if view.portrait then
        if panel.portraitKey ~= nil and panel.portraitKey == view.portraitKey then return end
        -- 第三參數 disableMasking：要方形的頭像（預設是圓形遮罩）。我們自己的貼圖、明文 token
        if SetPortraitTexture and pcall(SetPortraitTexture, icon, view.portrait, true) then
            panel.portraitKey = view.portraitKey
            return
        end
    end
    panel.portraitKey = nil
    icon:SetTexture(view.icon)
end

local function DrawIcon(panel, ctx, view)
    local m = ctx.m
    panel.badgeTint = view.badge and view.badge ~= "" and view.badgeTint or nil
    if not view.icon and not view.portrait then return 0 end
    local size = m.sc(view.iconSize or LOOK.ICON_ITEM)
    local icon, border = panel.icon, panel.iconBorder
    local top = m.padTop
    local hasBadge = view.badge and view.badge ~= ""
    local badgeH = 0
    if hasBadge then
        local style = ctx.styles.small
        local text = panel.badgeText
        Panel.ApplyFont(text, style)
        local tint = view.badgeTint
        local bc = view.badgeColor or LOOK.TEXT
        if tint then
            local t = LOOK.PLATE_TEXT
            bc = { tint[1] * (1 - t) + t, tint[2] * (1 - t) + t, tint[3] * (1 - t) + t }
        end
        text:SetTextColor(bc[1], bc[2], bc[3])
        text:SetText(view.badge)
        local w = math.max(size + 2 * m.px, Panel.Measure(view.badge, style) + m.badgePad)
        badgeH = Panel.Snap(panel, math.max(m.badgeH, style.size + m.sc(6)))
        local badge, fill = panel.badge, panel.badgeFill
        badge:SetSize(Panel.Snap(panel, w), badgeH)
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", badge, "TOPLEFT", m.px, -m.px)
        fill:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -m.px, m.px)
        if tint then
            local k = LOOK.PLATE_FILL
            fill:SetVertexColor(tint[1] * k, tint[2] * k, tint[3] * k, 1)
        else
            fill:SetVertexColor(LOOK.BADGE_BG, LOOK.BADGE_BG, LOOK.BADGE_BG, 1)
        end
        if not view.badgeBelow then top = top + badgeH + m.badgeGap end
    end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", m.pad, -top)
    icon:SetSize(size, size)
    SetIcon(icon, panel, view)
    icon:SetDesaturated(view.desaturate and true or false)
    icon:Show()
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -m.px, m.px)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", m.px, -m.px)
    border:Show()
    if hasBadge then
        local badge = panel.badge
        badge:ClearAllPoints()
        if view.badgeBelow then
            badge:SetPoint("TOP", icon, "BOTTOM", 0, -(m.badgeGap + m.px))
        else
            badge:SetPoint("BOTTOM", icon, "TOP", 0, m.badgeGap + m.px)
        end
        badge:Show(); panel.badgeFill:Show(); panel.badgeText:Show()
        if view.badgeBelow then return top + size + m.px + m.badgeGap + badgeH end
    end
    return top + size
end

------------------------------------------------------------
-- 聊天連結提示的 ×：我們只畫、不收滑鼠；點擊交給暴雪那顆原生關閉鈕。
--
-- ⚠ 不能在我們的程式裡 ItemRefCloseButton:Click()：它的 OnClick 是 HideUIPanel(ItemRefTooltip)，
--   從我們的執行呼叫等於讓 UIParent 的面板管理與 GameTooltip_OnHide（清比價管理器的共用狀態）在**污染的執行**裡跑，
--   之後暴雪讀那些欄位的執行都會被連坐（wow-121-secret-values「暴雪會讀的欄位一個都不能寫」）。
-- ⇒ 原生那顆跟著原生框一起 alpha 0（看不見但點得到），用 SetPoint 疊到我們畫的 × 上；
--   玩家點到的是原生按鈕本人，走它自己的安全路徑。面板退回時貼回原位（Panel.ResetNativeClose）。
------------------------------------------------------------
local CLOSE_HOME = { "TOPRIGHT", -4, -4 }    -- 跟 Core/Hooks.lua 的 Install 一致

function Panel.ResetNativeClose(tip)
    local native = _G.ItemRefCloseButton
    if not native or S.IsForbiddenObject(native) or tip ~= _G.ItemRefTooltip then return end
    native:ClearAllPoints()
    native:SetPoint(CLOSE_HOME[1], tip, CLOSE_HOME[1], CLOSE_HOME[2], CLOSE_HOME[3])
end

local function EnsureClose(panel, tip)
    if panel.close then return panel.close end
    -- 純 Frame、不 EnableMouse：滑鼠穿過去點到底下的原生關閉鈕
    local close = CreateFrame("Frame", nil, panel)
    local lines = {}
    for i, angle in ipairs({ 45, -45 }) do
        local line = close:CreateTexture(nil, "ARTWORK")
        line:SetTexture(ns.Media.WHITE8X8)
        line:SetPoint("CENTER")
        line:SetRotation(math.rad(angle))
        lines[i] = line
    end
    for _, l in ipairs(lines) do l:SetVertexColor(0.65, 0.65, 0.65, 1) end
    close.lines = lines
    panel.close = close
    return close
end

local function DrawClose(panel, ctx, tip)
    if tip ~= _G.ItemRefTooltip then return end
    local m = ctx.m
    local close = EnsureClose(panel, tip)
    close:SetSize(m.closeSize, m.closeSize)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -m.sc(3), -m.sc(3))
    for _, l in ipairs(close.lines) do l:SetSize(m.closeLen, m.closeThick) end
    close:Show()
    -- 接觸面 #11：原生關閉鈕疊到 × 上（點擊走它自己的安全路徑）
    local native = _G.ItemRefCloseButton
    if native and not S.IsForbiddenObject(native) then
        native:ClearAllPoints()
        native:SetPoint("CENTER", close, "CENTER", 0, 0)
    end
    -- 標題文字不要壓到 ×
    return m.closeSize
end

local function DrawTag(panel, ctx, view)
    if not view.tag or view.tag == "" then return end
    local m = ctx.m
    local tag = panel.tag
    if not tag then
        tag = CreateFrame("Frame", nil, panel)
        tag.border = tag:CreateTexture(nil, "BACKGROUND")
        tag.border:SetTexture(ns.Media.WHITE8X8)
        tag.border:SetAllPoints()
        tag.fill = tag:CreateTexture(nil, "BORDER")
        tag.fill:SetTexture(ns.Media.WHITE8X8)
        tag.fill:SetVertexColor(LOOK.TAG_BG, LOOK.TAG_BG, LOOK.TAG_BG, 1)
        tag.text = tag:CreateFontString(nil, "OVERLAY")
        Panel.ApplyFont(tag.text, ctx.styles.small)
        tag.text:SetPoint("CENTER")
        panel.tag = tag
    end
    Panel.ApplyFont(tag.text, ctx.styles.small)
    tag.text:SetTextColor(1, 1, 1)
    tag.text:SetText(view.tag)
    tag.fill:ClearAllPoints()
    tag.fill:SetPoint("TOPLEFT", m.px, -m.px)
    tag.fill:SetPoint("BOTTOMRIGHT", -m.px, m.px)
    tag:ClearAllPoints()
    tag:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, m.tagGap)
    tag:SetSize(Panel.Snap(panel, Panel.Measure(view.tag, ctx.styles.small) + 2 * m.tagPad),
        Panel.Snap(panel, math.max(m.tagH, ctx.styles.small.size + m.sc(6))))
    tag:Show()
end

------------------------------------------------------------
-- 主入口
------------------------------------------------------------
local function Accent()
    local cls = ns.playerClass
    local c = cls and ((_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[cls]) or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[cls]))
    if c and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { 1, 1, 1 }
end

------------------------------------------------------------
-- 附屬框：別的插件（含我們自己的 ID 行）後加的行另開一框接在主面板下面。
-- 寬同主面板、底色同主面板、邊框用基底邊色（Panel.BaseBorderColor：職業色或 general.borderColor；不吃品質色，看起來是從屬的）。
-- 它有自己的 texts／textures 池與 width，DrawRow 直接拿它當 panel 用，不另寫排版。
------------------------------------------------------------
local function EnsureBox(panel)
    local box = panel.extrasBox
    if box then return box end
    box = CreateFrame("Frame", nil, panel)
    box.texts, box.textsUsed = {}, 0
    box.textures, box.texturesUsed = {}, 0
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetTexture(ns.Media.WHITE8X8)
    box.bg:SetAllPoints()
    box.edges = {}
    for i = 1, 4 do
        local e = box:CreateTexture(nil, "OVERLAY", nil, 7)
        e:SetTexture(ns.Media.WHITE8X8)
        box.edges[i] = e
    end
    box:Hide()
    panel.extrasBox = box
    return box
end

local function ClearPools(frame)
    for i = 1, #frame.texts do frame.texts[i]:Hide() end
    for i = 1, #frame.textures do frame.textures[i]:Hide() end
    frame.textsUsed, frame.texturesUsed = 0, 0
end

local function HideBox(panel)
    if panel.extrasBox then panel.extrasBox:Hide() end
    panel.totalHeight = panel.height
end

local function DrawBox(panel, ctx, rows)
    local m = ctx.m
    local box = EnsureBox(panel)
    ClearPools(box)
    box.width = panel.width
    box:SetFrameLevel(panel:GetFrameLevel())
    box:ClearAllPoints()
    local gap = m.sc(LOOK.FRAME_GAP)
    box:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -gap)
    box:SetWidth(box.width)
    local y = m.padTop
    for _, row in ipairs(rows) do
        y = DrawRow(box, ctx, row, y, ctx.styles.body, LOOK.SECONDARY, m.sc(row.indent or 0), m.rowGap)
    end
    box.height = Panel.Snap(panel, y + m.padBottom)
    box:SetHeight(box.height)
    local g = ns.db and ns.db.general
    local bgc = g and g.background
    if bgc then
        box.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, 1)
        box.bg:SetAlpha(S.PlainNumber(bgc.a) or 1)
    else
        box.bg:SetVertexColor(0.133, 0.133, 0.133, 1)
    end
    Panel.LayoutEdges(box)
    local br, bgr, bb, ba = Panel.BaseBorderColor()
    for i = 1, 4 do box.edges[i]:SetVertexColor(br, bgr, bb, ba) end
    box:Show()
    panel.totalHeight = panel.height + gap + box.height
end

-- 畫完回傳 true；panel 不在這裡 Show，也不錨（Try 負責 Align → Native.Hide → Show）
-- panel.height＝主面板高；panel.totalHeight＝連附屬框（Native.Fit 撐原生用這個）
function Panel.RenderView(panel, tip, view, state)
    -- 先脫離錨點鏈：量測與 GetStringHeight 不能沾到 tooltip 的秘密錨點
    Panel.Detach(panel, true)
    local scale = ns.db and ns.db.general and S.PlainNumber(ns.db.general.scale) or 1
    if scale <= 0 then scale = 1 end
    panel:SetScale(scale)
    -- 層級 = tooltip + 5（預覽也一樣：預覽 tip 在設定視窗 +20，panel 再往上）
    panel.syncedLevel = nil
    Panel.SyncLevel(panel, tip)
    Panel.Clear(panel)
    -- 單位目標列的秘密名字那顆 FontString 會回到池裡被別的行借走：每次重畫都放掉，畫到的時候 ViewUnit 再記
    if state then state.panelTargetFS = nil end

    local ctx = { m = Metrics(panel), styles = Panel.Styles(), accent = Accent(), tip = tip, state = state }
    local m = ctx.m

    -- 別人加的行：設定開著另開一框；關著接回 sections 尾端（細線分隔）。量寬兩種都算進去
    local extraRows = view.extras and view.extras.rows
    if extraRows and #extraRows == 0 then extraRows = nil end
    local useBox = extraRows and Panel.Option("extrasBox")
    local extrasSection = extraRows and {
        separator = { rule = true }, kind = "rows", rows = extraRows, wrap = true, color = LOOK.SECONDARY,
    }
    local sections = view.sections or {}
    local fitView = view
    if extrasSection then
        local withExtras = {}
        for i, s in ipairs(sections) do withExtras[i] = s end
        withExtras[#withExtras + 1] = extrasSection
        if not useBox then sections = withExtras end
        fitView = setmetatable({ sections = withExtras }, { __index = view })
    end

    -- 只長不縮（同一件）：Try 記的最大寬
    panel.width = Panel.Snap(panel, math.max(FitWidth(panel, ctx, fitView), state.panelMaxWidth or 0))
    panel:SetWidth(panel.width)

    -- 外框：提示皮的底色、1 實體像素的邊
    local g = ns.db and ns.db.general
    local bgc = g and g.background
    if bgc then
        panel.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, 1)
        panel.bg:SetAlpha(S.PlainNumber(bgc.a) or 1)
    else
        panel.bg:SetVertexColor(0.133, 0.133, 0.133, 1)
    end
    Panel.LayoutEdges(panel)
    Panel.PaintEdges(panel, state)

    -- 標題區
    local headerMin = DrawIcon(panel, ctx, view)
    local closeW = DrawClose(panel, ctx, tip) or 0
    DrawTag(panel, ctx, view)
    Panel.PaintEdges(panel, state)    -- 徽章／標籤剛建好，邊框色補上

    local indent = IconIndent(ctx, view)
    local inner = panel.width - 2 * m.pad - indent
    local y = m.padTop
    local header = view.header or {}
    for i, item in ipairs(header) do
        local style = StyleOf(ctx, item.style)
        local gap = (i < #header) and (item.gap and m.sc(item.gap) or m.headerGap) or 0
        if item.text then
            -- 第一行要讓開關閉鈕
            local w = inner - ((i == 1) and closeW or 0)
            y = y + TextAt(panel, ctx, item.text, m.pad + indent, y, w, style, item.color) + gap
        elseif item.badges and #item.badges > 0 then
            y = y + TextAt(panel, ctx, BadgeText(item.badges), m.pad + indent, y, inner, style,
                LOOK.SECONDARY) + gap
        elseif item.rows then
            for _, row in ipairs(item.rows) do
                y = DrawRow(panel, ctx, row, y, style, item.color, indent, m.rowGap)
            end
        end
    end
    local footer = view.footer
    local hasFooter = footer and (footer.draw or (footer.rows and #footer.rows > 0))
    if #header > 0 or view.icon or view.portrait then
        if #sections > 0 or hasFooter then
            -- 文字與「圖示（或徽章）的底」都要離第一段至少 HEADER_BOTTOM：只有一行名字時文字比圖示矮，
            -- 只加在文字後面的話圖示底就貼著第一段（實機：單行名字的法術，圖示底黏著四格頂）
            -- 第一段前面是線（Rule／Divider／Caption）：線自己會留 RULE_SPACE，這裡只補段落尾端那個 rowGap，
            -- 線離標題跟離下一段一樣遠
            local sep = sections[1] and sections[1].separator
            local gap = (sep and (sep.rule or sep.divider or sep.caption)) and m.rowGap or m.headerBottom
            y = math.max(y + gap, headerMin > 0 and (headerMin + gap) or 0)
            if sections[1] and sections[1].strip then y = y + m.rowGap end
        else
            y = math.max(y, headerMin)
        end
    end

    for _, section in ipairs(sections) do
        y = DrawSeparator(panel, ctx, y, section.separator)
        local draw = DRAW[section.kind]
        if draw then y = draw(panel, ctx, y, section) end
    end

    if hasFooter then
        y = y + m.footerTop
        local top = y
        y = y + m.footerPad
        if footer.draw then
            y = footer.draw(panel, y, ctx)
        else
            local style = StyleOf(ctx, footer.style)
            for i, row in ipairs(footer.rows) do
                y = DrawRow(panel, ctx, row, y, style, footer.color, 0, (i < #footer.rows) and m.rowGap or 0)
            end
        end
        local band = panel.footer
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", panel, "TOPLEFT", m.px, -Panel.Snap(panel, top))
        band:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -m.px, m.px)
        band:SetVertexColor(LOOK.FOOTER_BG, LOOK.FOOTER_BG, LOOK.FOOTER_BG, 1)
        band:Show()
    end

    -- 頁尾帶內上下同距（上 FOOTER_PAD，下也 FOOTER_PAD；draw 回傳的 y 不帶行距）
    panel.height = Panel.Snap(panel, y + (hasFooter and m.footerPad or m.padBottom))
    panel:SetHeight(panel.height)
    if view.decorate then view.decorate(panel, ctx) end
    if useBox then
        DrawBox(panel, ctx, extraRows)
    else
        HideBox(panel)
    end
    -- 夾邊是原生在夾（Native.UpdateClamp 每次 Fit 重算）：這裡只記下露在面板外、原生範圍沒涵蓋的那一塊——
    -- 上方的「已裝備」標籤（底下的附屬框已經在原生撐高的總高裡）——以及四邊的呼吸。面板本身不夾
    if not state.isPreview then
        panel.clampOwnTop = (panel.tag and panel.tag:IsShown()) and (m.tagGap + m.tagH) or 0
        panel.clampMargin = m.edgeMargin
    end
    return true
end
