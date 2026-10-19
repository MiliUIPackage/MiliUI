------------------------------------------------------------
-- 重繪面板：框、池、量尺、像素工具、外觀常數
--
-- 物品／法術提示改成「原生 tooltip 留在底下當定位與夾邊的替身（alpha 0、padding 撐大），
-- 旁邊畫一個自己的 panel」。這支只管 panel 本身；藏原生在 Native.lua、流程在 Try.lua。
--
-- ⚠ panel 是**自己的** frame（parent UIParent；預覽時 parent 是設定視窗），上面的欄位
--   隨便寫。暴雪的 tooltip 只被讀（GetPoint／GetLeft…一律先過 S.IsSecret）。
-- ⚠ 量測與排版**只讀自己記的數字**（panel.width／panel.height），不讀 panel:GetWidth()：
--   panel 錨在 tooltip 上，tooltip 的錨點鏈帶秘密時幾何會沿鏈傳染（wow-121-secret-values）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Media = ns.Media

ns.Panel = ns.Panel or {}
local Panel = ns.Panel

local WHITE = Media.WHITE8X8

-- panel 區塊的布林設定（沒有這欄＝開）
function Panel.Option(key)
    local p = ns.db and ns.db.panel
    return not p or p[key] ~= false
end

------------------------------------------------------------
-- 外觀常數（plan「視覺規格」那張表，單位是設計單位，畫的時候才 Snap／Pixel）
-- 提示皮：底與邊框色由 Skin 那套給（general.background、state.borderColor），這裡不重複定義
------------------------------------------------------------
Panel.LOOK = {
    PAD = 10,                 -- 左右內距；上多 2、下少 2
    PAD_TOP_EXTRA = 2,
    PAD_BOTTOM_EXTRA = -2,
    MIN_W = 220, MAX_W = 440, -- 寬度夾在這之間
    PROSE_W = 300,            -- 換行段落的內容寬
    COLUMN_GAP = 12,          -- 左右欄之間
    ROW_GAP = 2,              -- 行距
    HEADER_GAP = 4,           -- 標題各行之間
    HEADER_BOTTOM = 6,        -- 標題區與第一段之間

    LINE_ALPHA = 0.22,        -- Rule／Divider／Caption 兩側線：白、這個 alpha
    -- 線（Rule／Divider／Caption）離上下文字一樣遠：上方＝前一行尾端的 ROW_GAP ＋ RULE_SPACE，
    -- 下方＝RULE_SPACE ＋ ROW_GAP 補成對稱。Divider 跟 Rule 同距，◆ 置中在線上
    -- （以前 Divider 另有 8 ＋ ◆ 半高，夾在 Rule 與 Divider 之間的段落上 6 下 14，2026-10-19 回報上下不一致）
    RULE_SPACE = 8,
    DIAMOND = 5,              -- 中央 ◆ 的邊長（旋轉 45°）
    DIAMOND_ALPHA = 0.9,      -- ◆ 用玩家職業色
    CAPTION_GRAY = 0.65,
    CAPTION_LINE_GAP = 8,     -- Caption 文字與兩側線之間

    TEXT = { 1, 1, 1 },             -- 主文
    SECONDARY = { 0.65, 0.65, 0.65 },
    DIM = { 0.45, 0.45, 0.45 },
    UNUSABLE = { 1, 0.34, 0.28 },   -- 不可用／未達成
    DESCRIPTION = { 1, 1, 1 },      -- 描述也用白，不用米黃

    ICON_ITEM = 40, ICON_SPELL = 36,
    ICON_GAP = 10,            -- 圖示與標題文字之間
    BADGE_GAP = 4, BADGE_H = 16, BADGE_PAD = 10, BADGE_BG = 0.08,

    FOOTER_BG = 0.102,        -- HUD 皮的「實心橫條」
    FOOTER_TOP = 9,           -- 頁尾帶上方留白
    FOOTER_PAD = 6,           -- 頁尾帶內距

    CLOSE_SIZE = 16, CLOSE_LEN = 11, CLOSE_THICK = 1.5,
    TAG_H = 16, TAG_PAD = 8, TAG_GAP = 2, TAG_BG = 0.08,
    EDGE_MARGIN = 4,        -- 夾邊時離螢幕邊留的呼吸（貼死的話 1px 邊框整條看不見）

    SMALL_SHRINK = 2, SMALL_MIN = 9,   -- caption／徽章字級 = body − 2（最小 9）
    BIG_GROW = 2,                      -- strip 的值 = body + 2
    STAT_GROW = 3,                     -- 物品的每秒傷害／護甲大數字 = body + 3

    EFFECT = { 0.48, 0.88, 0.48 },     -- 使用／裝備效果（暴雪原色的綠）
    FLAVOR = { 0.86, 0.74, 0.45 },     -- 風味文字
    SET_NAME = { 1, 0.82, 0 },         -- 套裝名（金）
    STAT_SHADE = { primary = 1, secondary = 0.85, tertiary = 0.85, other = 0.7 },   -- 三屬性跟次屬性同一級（N3）
    CREATED_ICON = 24,                 -- 配方成品的小圖示
    REAGENT_ICON = 14,
    BAR_W = 54, BAR_H = 6,             -- 頁尾耐久條
    FRAME_GAP = 6,                     -- 框與框之間的縫：附屬框與主面板、比價面板之間、貼在面板旁的別家框（N1）
}
local LOOK = Panel.LOOK

------------------------------------------------------------
-- 像素：基準是 **panel 自己的** 有效縮放（panel 會跟著 tooltip 的 general.scale 一起 SetScale，
-- 拿 UIParent 的基準算會整組偏掉，見 wow-setscale-offset-units）。scale = 1 時跟 P.Scale／P.Pixel 一樣。
------------------------------------------------------------
local function EffectiveScale(region)
    local ok, scale = pcall(region.GetEffectiveScale, region)
    scale = ok and S.PlainNumber(scale)
    if scale and scale > 0 then return scale end
end
Panel.EffectiveScale = EffectiveScale

-- 尺寸／間距：n 個設計單位貼到最近的整數像素（＝ P.Scale 的語意）
function Panel.Scale(panel, n)
    if n == 0 then return 0 end
    local scale = EffectiveScale(panel)
    if scale and PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(n, scale)
    end
    return n
end

-- 剛好 n 個實體像素（＝ P.Pixel 的語意）：邊框、細線
function Panel.Pixel(panel, n)
    n = math.floor((n or 1) + 0.5)
    if n <= 0 then return 0 end
    local scale = EffectiveScale(panel)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    if not (scale and factor) then return n end
    return n * factor / scale
end

-- 任意值（已經是 panel 單位）貼到整數像素
function Panel.Snap(panel, value)
    local scale = EffectiveScale(panel)
    if scale and PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(value, scale)
    end
    return math.floor(value + 0.5)
end

------------------------------------------------------------
-- 字型：只讀全域字型物件（Fonts.lua 已經替使用者設好），render 時讀
------------------------------------------------------------
local function ReadFont(obj, fallbackSize)
    local path, size, flags
    if obj and obj.GetFont then
        path, size, flags = obj:GetFont()
    end
    if type(path) ~= "string" or path == "" then path = Media.Font("default") end
    if type(size) ~= "number" or size <= 0 then size = fallbackSize end
    if type(flags) ~= "string" then flags = "" end
    local sx, sy, sr, sg, sb, sa = 1, -1, 0, 0, 0, 0.9
    if obj and obj.GetShadowOffset then
        local ox, oy = obj:GetShadowOffset()
        if type(ox) == "number" then sx, sy = ox, oy end
    end
    if obj and obj.GetShadowColor then
        local r, g, b, a = obj:GetShadowColor()
        if type(r) == "number" then sr, sg, sb, sa = r, g, b, a or 1 end
    end
    return { font = path, size = size, flags = flags, shadow = { sx, sy, sr, sg, sb, sa } }
end

local function Derive(base, size)
    return { font = base.font, size = size, flags = base.flags, shadow = base.shadow }
end

-- 一次 render 用的整組字型
function Panel.Styles()
    local title = ReadFont(_G.GameTooltipHeaderText, 14)
    local body = ReadFont(_G.GameTooltipText, 12)
    local small = math.max(LOOK.SMALL_MIN, body.size - LOOK.SMALL_SHRINK)
    return {
        title = title,
        heading = Derive(title, math.max(body.size, title.size - 2)),   -- 巢狀法術／配方成品的小一號標題
        body = body,
        small = Derive(body, small),
        caption = Derive(body, small),
        big = Derive(body, body.size + LOOK.BIG_GROW),
        stat = Derive(body, body.size + LOOK.STAT_GROW),   -- 每秒傷害／護甲的大數字
    }
end

-- 字型設給一顆 FontString；同樣的值不重設（重繪時大多數行的字型沒變）。
-- SetFont 失敗（字型檔讀不到）就退在地化預設字型，否則之後的 SetText 會硬錯
function Panel.ApplyFont(fs, style)
    if fs.mtFont ~= style.font or fs.mtSize ~= style.size or fs.mtFlags ~= style.flags then
        -- 不靠 SetFont 的回傳值（各版本不一），設完問 GetFont 有沒有字型
        local ok = pcall(fs.SetFont, fs, style.font, style.size, style.flags)
        if not ok or not fs:GetFont() then
            fs:SetFont(Media.Font("default"), style.size, style.flags)
        end
        fs.mtFont, fs.mtSize, fs.mtFlags = style.font, style.size, style.flags
    end
    local sh = style.shadow
    if sh and fs.mtShadow ~= sh then
        fs:SetShadowOffset(sh[1], sh[2])
        fs:SetShadowColor(sh[3], sh[4], sh[5], sh[6])
        fs.mtShadow = sh
    end
end

------------------------------------------------------------
-- 量尺：獨立一顆、不錨在任何 tooltip 上（量測不能沾到秘密錨點鏈）
------------------------------------------------------------
local ruler
local function Ruler()
    if ruler then return ruler end
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    holder:SetAlpha(0)
    ruler = holder:CreateFontString(nil, "OVERLAY")
    ruler:SetPoint("TOPLEFT")
    Panel.ApplyFont(ruler, ReadFont(_G.GameTooltipText, 12))
    return ruler
end

------------------------------------------------------------
-- 行內圖示：頭或尾那一顆拆出來另外畫（Panel.TextAt），不靠 FontString 的行內排版。
-- 實機：附魔行結尾的品質圖示（|A…|a）比文字低半行、掉進行距。
-- 只拆「整串只有這一顆圖示」的情況：錢幣字串一串三顆，只拆最後一顆會跟另外兩顆對不齊。
------------------------------------------------------------
Panel.ICON_TEXT_GAP = 3

local function ParseIcon(code)
    if code:sub(2, 2) == "T" then
        local body = code:match("^|T(.-)|t$")
        if not body then return end
        local p = {}
        for v in (body .. ":"):gmatch("(.-):") do p[#p + 1] = v end
        -- 檔案編號（寶石的 gemIcon、|T7549137:0|t）要以數字餵 SetTexture；字串形式的數字會被當成路徑找不到
        local icon = { file = tonumber(p[1]) or p[1], h = tonumber(p[2]), w = tonumber(p[3]) }
        local tw, th, l, r, t, b = tonumber(p[6]), tonumber(p[7]), tonumber(p[8]), tonumber(p[9]), tonumber(p[10]), tonumber(p[11])
        if tw and th and tw > 0 and th > 0 and l and r and t and b then
            icon.coords = { l / tw, r / tw, t / th, b / th }
        end
        return icon
    end
    local body = code:match("^|A:?(.-)|a$")
    if not body then return end
    local p = {}
    for v in (body .. ":"):gmatch("(.-):") do p[#p + 1] = v end
    return { atlas = p[1], h = tonumber(p[2]), w = tonumber(p[3]) }
end

local function IconCount(text)
    local n = 0
    for _ in text:gmatch("|[TA]") do n = n + 1 end
    return n
end

-- 回傳 lead, body, trail（lead／trail 是圖示表或 nil）
function Panel.SplitIcons(text)
    if type(text) ~= "string" or IconCount(text) ~= 1 then return nil, text, nil end
    local code, rest = text:match("^(|T[^|]*|t)%s?(.*)$")
    if not code then code, rest = text:match("^(|A[^|]*|a)%s?(.*)$") end
    if code then return ParseIcon(code), rest, nil end
    local before
    before, code = text:match("^(.-)%s?(|T[^|]*|t)$")
    if not code then before, code = text:match("^(.-)%s?(|A[^|]*|a)$") end
    if code then return nil, before, ParseIcon(code) end
    return nil, text, nil
end

-- 圖示尺寸：字串裡給的；0 或沒給就用那一行的字級（寬沒給＝高）
function Panel.IconSize(icon, style)
    local h = (icon.h and icon.h > 0) and icon.h or style.size
    local w = (icon.w and icon.w > 0) and icon.w or h
    return w, h
end

local function MeasureRaw(text, style)
    if type(text) ~= "string" or text == "" then return 0 end
    local fs = Ruler()
    Panel.ApplyFont(fs, style)
    fs:SetText(text)
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return S.PlainNumber(w) or 0
end
Panel.MeasureRaw = MeasureRaw

-- 一行字不換行時的寬（拆出來另外畫的圖示也算進去）
function Panel.Measure(text, style)
    if type(text) ~= "string" or text == "" then return 0 end
    local lead, body, trail = Panel.SplitIcons(text)
    local w = MeasureRaw(body, style)
    for _, icon in ipairs({ lead or false, trail or false }) do
        if icon then
            local iw = Panel.IconSize(icon, style)
            w = w + iw + ((body ~= "") and Panel.ICON_TEXT_GAP or 0)
        end
    end
    return w
end

------------------------------------------------------------
-- 池：FontString／Texture 只增不刪，Clear 只藏（frame 刪不掉，見 wow-frame-lifecycle-costs）
------------------------------------------------------------
function Panel.Text(panel, style)
    panel.textsUsed = panel.textsUsed + 1
    local fs = panel.texts[panel.textsUsed]
    if not fs then
        fs = panel:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        panel.texts[panel.textsUsed] = fs
    end
    Panel.ApplyFont(fs, style)       -- 建立當下就給字型，SetText 才不會硬錯
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

function Panel.Texture(panel, sublevel)
    panel.texturesUsed = panel.texturesUsed + 1
    local tex = panel.textures[panel.texturesUsed]
    if not tex then
        tex = panel:CreateTexture(nil, "ARTWORK")
        panel.textures[panel.texturesUsed] = tex
    end
    -- 池裡的貼圖可能上次是圖示：材質與裁切每次都重設
    tex:SetTexture(WHITE)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetDrawLayer("ARTWORK", sublevel or 0)
    tex:SetRotation(0)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

function Panel.Clear(panel)
    for i = 1, #panel.texts do panel.texts[i]:Hide() end
    for i = 1, #panel.textures do panel.textures[i]:Hide() end
    panel.textsUsed, panel.texturesUsed = 0, 0
    panel.icon:Hide()
    panel.iconBorder:Hide()
    panel.badge:Hide()
    panel.badgeFill:Hide()
    panel.badgeText:Hide()
    panel.footer:Hide()
    if panel.close then panel.close:Hide() end
    if panel.tag then panel.tag:Hide() end
end

------------------------------------------------------------
-- 建立：每個接管的 tooltip 一個 panel，放在 state.panel
------------------------------------------------------------
local function MakeTexture(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel or 0)
    tex:SetTexture(WHITE)
    return tex
end

local function Create(tip, state)
    local parent = UIParent
    if state.isPreview then
        -- 預覽：掛在設定視窗底下跟著開關與層級走。
        -- ⚠ 不單獨設 strata：設定視窗是 toplevel，子框自設 strata 之後就不跟著抬層（Options/Panel.lua 檔頭）
        local ok, p = pcall(tip.GetParent, tip)
        if ok and p then parent = p end
    end
    local panel = CreateFrame("Frame", nil, parent)
    if not state.isPreview then
        -- 跟 tooltip 同一層 strata（接管的那幾支都是 TOOLTIP；讀不到或秘密才退 TOOLTIP）
        local ok, strata = pcall(tip.GetFrameStrata, tip)
        strata = ok and S.PlainText(strata)
        panel:SetFrameStrata(strata or "TOOLTIP")
        -- 不夾邊：原生照暴雪的夾邊、面板貼著原生（Native.UpdateClamp）
    end
    panel:Hide()

    panel.texts, panel.textsUsed = {}, 0
    panel.textures, panel.texturesUsed = {}, 0

    panel.bg = MakeTexture(panel, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.footer = MakeTexture(panel, "BORDER")
    panel.edges = {}
    -- 邊框不貼齊：鏡射（Mirror）那條路不做整數像素修正，貼齊開著會偶爾整條捨入成 0px（Media.NoSnap）
    for i = 1, 4 do panel.edges[i] = Media.NoSnap(MakeTexture(panel, "OVERLAY", 7)) end

    panel.icon = MakeTexture(panel, "ARTWORK", 2)
    panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panel.iconBorder = MakeTexture(panel, "ARTWORK", 1)
    panel.badge = MakeTexture(panel, "ARTWORK", 1)
    panel.badgeFill = MakeTexture(panel, "ARTWORK", 2)
    panel.badgeText = panel:CreateFontString(nil, "OVERLAY")
    Panel.ApplyFont(panel.badgeText, ReadFont(_G.GameTooltipText, 12))
    panel.badgeText:SetPoint("CENTER", panel.badge, "CENTER", 0, 0)

    state.panel = panel
    return panel
end

function Panel.Get(tip, state)
    return state.panel or Create(tip, state)
end

-- 層級 = tooltip + 5。ItemRefTooltip 是 toplevel＋可拖曳：點它、拖它時暴雪會把它的 level 抬高，
-- alpha 0 的原生框就壓到 panel 上、把 × 的點擊吃掉 ⇒ render 時設一次不夠，輪詢每次都對一次
function Panel.SyncLevel(panel, tip)
    local ok, level = pcall(tip.GetFrameLevel, tip)
    level = ok and S.PlainNumber(level)
    if not level then return end
    if panel.syncedLevel ~= level then
        panel.syncedLevel = level
        panel:SetFrameLevel(level + 5)
        if panel.extrasBox then panel.extrasBox:SetFrameLevel(level + 5) end
    end
end

-- 邊框：四張 1 實體像素的貼圖，上下橫貫全寬、左右夾在中間
function Panel.LayoutEdges(panel)
    local px = Panel.Pixel(panel, 1)
    local e = panel.edges
    for i = 1, 4 do e[i]:ClearAllPoints() end
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
    e[3]:SetPoint("TOPLEFT", 0, -px); e[3]:SetPoint("BOTTOMLEFT", 0, px); e[3]:SetWidth(px)
    e[4]:SetPoint("TOPRIGHT", 0, -px); e[4]:SetPoint("BOTTOMRIGHT", 0, px); e[4]:SetWidth(px)
    panel.px = px
end

-- 邊框色：Skin.SetBorderColor 記下的那組（分量可能是秘密值，原封不動交給 SetVertexColor）
-- 基底邊色（沒有內容色時的邊）：設定 borderClassColor 開著＝玩家職業色（HUD 皮的 1px 職業色邊），
-- 關掉＝general.borderColor。透明度一律照 general.borderColor 的 a。
-- Skin.ResetColors、面板的退路、附屬框都從這裡拿；品質色／立場色由 Skin.SetBorderColor 蓋過去
function Panel.BaseBorderColor()
    local g = ns.db and ns.db.general
    local bc = g and g.borderColor
    local a = bc and bc.a or 1
    if g and g.borderClassColor ~= false then
        local cls = ns.playerClass
        local c = cls and ((_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[cls])
            or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[cls]))
        if c and type(c.r) == "number" then return c.r, c.g, c.b, a end
    end
    if bc then return bc.r, bc.g, bc.b, a end
    return 0.18, 0.18, 0.18, 1
end

function Panel.BorderColor(state)
    local c = state and state.borderColor
    if c then return c[1], c[2], c[3], c[4] or 1 end
    return Panel.BaseBorderColor()
end

function Panel.PaintEdges(panel, state)
    local r, gg, b, a = Panel.BorderColor(state)
    for i = 1, 4 do panel.edges[i]:SetVertexColor(r, gg, b, a or 1) end
    panel.iconBorder:SetVertexColor(r, gg, b, a or 1)
    panel.badge:SetVertexColor(r, gg, b, a or 1)
    if panel.tag then panel.tag.border:SetVertexColor(r, gg, b, a or 1) end
end

------------------------------------------------------------
-- 對齊：照 tooltip 第一個含 LEFT／RIGHT 的錨點那一側貼齊上緣
-- （原生撐大後可能比 panel 寬，多出來的那截朝向「不是它被錨的那邊」）。
-- 角落要在整數像素上，不然 1px 線會在半像素處被捨入成 0 或 2（gridOffset 修正）。
-- 任何一個讀值是秘密 ⇒ 回 false，呼叫端整格退回原生樣式。
------------------------------------------------------------
-- 回傳水平側（LEFT／RIGHT）與垂直側（TOP／BOTTOM）：各取第一個含那個字的點；都沒有就 LEFT／TOP。
-- 貼「被錨定的那一角」：原生的高度在兩幀之間暫時不對（暴雪重設提示時 padding 被清掉）時，
-- 被錨定的那一邊不動，panel 就不跟著跳（2026-10-18 實機：從下緣錨定的跟隨游標／固定右下／比價框都上下跳）。
local function AnchoredSide(tip)
    local ok, n = pcall(tip.GetNumPoints, tip)
    n = ok and S.PlainNumber(n)
    if not n then return nil end
    local h, v
    for i = 1, n do
        local okP, point, rel, relPoint, x, y = pcall(tip.GetPoint, tip, i)
        if not okP then return nil end
        if S.IsSecret(point) or S.IsSecret(rel) or S.IsSecret(relPoint) or S.IsSecret(x) or S.IsSecret(y) then
            return nil
        end
        if type(point) == "string" then
            if not h and point:find("RIGHT") then h = "RIGHT" end
            if not h and point:find("LEFT") then h = "LEFT" end
            if not v and point:find("TOP") then v = "TOP" end
            if not v and point:find("BOTTOM") then v = "BOTTOM" end
        end
    end
    return h or "LEFT", v or "TOP"
end
Panel.AnchoredSide = AnchoredSide

local function GridOffset(panel, tip, side, vside)
    local okX, x = pcall(side == "RIGHT" and tip.GetRight or tip.GetLeft, tip)
    local okY, y = pcall(vside == "BOTTOM" and tip.GetBottom or tip.GetTop, tip)
    if not okX or not okY then return nil end
    if S.IsSecret(x) or S.IsSecret(y) then return nil end
    -- 還沒排版（剛 SetOwner／ClearAllPoints 過）：回「未定」，呼叫端照 J3 不改貼法
    if type(x) ~= "number" or type(y) ~= "number" then return nil, nil, nil, nil, true end
    local tipScale, panelScale = EffectiveScale(tip), EffectiveScale(panel)
    if not (tipScale and panelScale) then return nil, nil, nil, nil, true end
    x, y = x * tipScale / panelScale, y * tipScale / panelScale
    return Panel.Snap(panel, x) - x, Panel.Snap(panel, y) - y, x, y
end

------------------------------------------------------------
-- 鏡射錨點：原生錨在「另一顆已接管、面板顯示中的 tooltip」上（比價框 TOP→GameTooltip:TOP、
-- RIGHT→GameTooltip:LEFT；ShoppingTooltip2 → ShoppingTooltip1）⇒ 面板照原生的每一個點，
-- 把 relativeTo 換成對方的 **panel**，point／relativePoint／位移原樣。
-- 原生的幾何依賴（主提示的自然寬高每次重設都短暫變一下 ⇒ 比價框的原生跟著動）就不會傳到面板上：
-- 比價面板只依賴主面板，主面板的穩定（貼被錨定的一角、只長不縮）就傳下去（2026-10-18 實機：比價面板上下、左右抖）。
------------------------------------------------------------
-- 回傳點的陣列（可以是空的）；讀到秘密值或失敗回 nil
local function ReadPoints(tip)
    local ok, n = pcall(tip.GetNumPoints, tip)
    n = ok and S.PlainNumber(n)
    if not n then return nil end
    local points = {}
    for i = 1, n do
        local okP, point, rel, relPoint, x, y = pcall(tip.GetPoint, tip, i)
        if not okP then return nil end
        if S.IsSecret(point) or S.IsSecret(rel) or S.IsSecret(relPoint) or S.IsSecret(x) or S.IsSecret(y) then
            return nil
        end
        points[i] = { point, rel, relPoint, x or 0, y or 0 }
    end
    return points
end

-- 這個框是我們接管、而且面板正顯示著的 tooltip ⇒ 回它的面板
function Panel.PanelFor(frame)
    if type(frame) ~= "table" or not (ns.Skin and ns.Skin.State) then return nil end
    local st = ns.Skin.State[frame]
    local panel = st and st.panel
    if panel and panel:IsShown() then return panel end
end

local function PanelOf(rel, tip, panel)
    if rel == tip then return nil end
    local other = Panel.PanelFor(rel)
    if other ~= panel then return other end
end

------------------------------------------------------------
-- 別的插件自己建的框貼在我們接管的 tooltip 旁邊（外觀預覽，經 MiliUITip_API.Adopt 的 followPanel）：
-- 它每 0.2 秒自己 ClearAllPoints＋SetPoint(點, 原生 tooltip, 對方點)，點是它照原生的幾何決定的（貼哪一邊、放不放得下）。
-- 接管期間原生的幾何是**真實的**（跟面板一樣大、照暴雪的夾邊留在螢幕內，見 Native.lua）⇒ 它的判斷可信，
-- 我們只做一件事：對象換成那顆 tooltip 的面板、點與位移原樣、相鄰邊留一個縫（N1）。
-- 為什麼要換：比價面板跟它的原生差一個縫（鏡射時往外推 FRAME_GAP），貼原生會壓到面板邊上。
-- 2026-10-19 曾經改成「不照它的點、由我們決定左右、交棒、停在原地」那一套（O1），那是在原生不夾邊、
-- 幾何是假的前提下補下游症狀；原生幾何真實化之後整套拿掉，見 notes/project-miliui-tooltip.md。
-- 它不是我們的框、會自己重貼 ⇒ 後掛勾 SetPoint（接觸面 #14）同一幀改貼；只掛在別的插件自己建的 Frame 上
--（不是暴雪物件），每顆只掛一次；掛勾裡重入旗標擋自己的 SetPoint。只保留最後一個點（它每次先 ClearAllPoints）。
-- 面板退回時（Restore）把貼在那個面板上的框當場貼回原生，不等它下一次自己重貼（錨在沒有點的框上那一下會跑掉）。
------------------------------------------------------------
local MAX_CHAIN = 8        -- 鏡射鏈最深幾層（夾邊預留沿鏈收到根）

local followers = {}       -- [frame] = { point, rel, relPoint, x, y, panel }（rel 是它原本要貼的 tooltip）
local following = false
Panel.followers = followers

local function Reanchor(frame, point, rel, relPoint, x, y)
    following = true
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(point, rel, relPoint, x, y)
    end)
    following = false
end

function Panel.Follow(frame)
    if type(frame) ~= "table" or followers[frame] or type(frame.SetPoint) ~= "function" then return end
    followers[frame] = {}
    hooksecurefunc(frame, "SetPoint", function(self, point, rel, relPoint, x, y)
        if following then return end
        if S.IsSecret(point) or S.IsSecret(rel) or S.IsSecret(relPoint) or S.IsSecret(x) or S.IsSecret(y) then return end
        if type(rel) == "string" then rel = _G[rel] end
        -- SetPoint(點, 對象, x, y) 的寫法：沒有對方點
        if type(relPoint) == "number" then relPoint, x, y = point, relPoint, x end
        local rec = followers[self]
        rec.panel = nil
        if type(point) ~= "string" then return end
        local panel = Panel.PanelFor(rel)
        if not panel then return end
        relPoint = type(relPoint) == "string" and relPoint or point
        rec[1], rec[2], rec[3], rec[4], rec[5], rec.panel = point, rel, relPoint, x or 0, y or 0, panel
        -- 跟面板之間留縫（N1）：縫的單位是這顆框自己的（位移照它的縮放算）
        local gx, gy = Panel.GapOffset(point, relPoint, Panel.Scale(self, LOOK.FRAME_GAP))
        Reanchor(self, point, panel, relPoint, (x or 0) + gx, (y or 0) + gy)
    end)
end

-- 面板 gone 要退了：貼在它上面的框貼回原本的 tooltip
function Panel.ReturnFollowers(gone)
    for frame, rec in pairs(followers) do
        if rec.panel == gone then
            rec.panel = nil
            Reanchor(frame, rec[1], rec[2], rec[3], rec[4], rec[5])
        end
    end
end

-- 套一組錨點；跟上次一樣（而且還貼著）就什麼都不做。記下來的 anchorArgs 給「原生暫時沒有點」時照貼回去
local function Apply(panel, sig, args)
    if panel.alignSig == sig and panel.anchored then return true end
    panel:ClearAllPoints()
    for _, a in ipairs(args) do panel:SetPoint(a[1], a[2], a[3], a[4], a[5]) end
    if ns.logEnabled and ns.Log then
        ns.Log("面板 重貼 %s（之前 %s）", sig, tostring(panel.alignSig))
    end
    panel.alignSig, panel.anchorArgs, panel.anchored = sig, args, true
    return true
end

-- J3：原生暫時沒有點（暴雪每次重設比價框都先 SetOwner(ANCHOR_NONE)＝ClearAllPoints，post-call 之後才 SetPoint）、
-- 或還沒排版 ⇒ **不改貼法**：還貼著就沿用；重畫時 Detach 過就照上次的貼回去；從來沒貼過才暫貼自己原生的
-- TOPLEFT（sig = "provisional"，下一次有點時一定重算）。
-- 之前在這裡退成「沒有點 ⇒ LEFT/TOP、位移 0」，每個重設循環先貼原生的 TOPLEFT、下一幀再鏡射回主面板 ⇒
-- 兩種貼法輪流＝抖，鏈越長越兇（2026-10-18 實機兩份 dump 對出來）
local function Keep(panel, tip)
    if panel.anchored then return true end
    if panel.anchorArgs then return Apply(panel, panel.alignSig, panel.anchorArgs) end
    return Apply(panel, "provisional", { { "TOPLEFT", tip, "TOPLEFT", 0, 0 } })
end

------------------------------------------------------------
-- 夾邊：**原生照暴雪的夾邊**（接管期間我們只替它設夾邊範圍，Native.UpdateClamp）。面板錨在原生被錨定的那一角、
-- 跟原生一樣大，原生留在螢幕內面板就在螢幕內；面板自己不夾（兩邊都夾會互相拉開）。
-- 原生要預留的上緣：自己露在面板外的那一塊（RenderView 記 clampOwnTop：上方的「已裝備」標籤），
-- 再加上**鏡射在自己身上的面板**的——比價面板的原生錨在主提示的原生上（TOP→TOP），兩顆各自夾的話
-- 有標籤的那顆被多推一個標籤高、身體錯開（2026-10-19 實機）；由根多留出最大的那一份，依附者就不必自己夾。
-- 鏡射可以串（第二顆比價框貼第一顆）⇒ 沿鏈收到根。單位是面板的，呼叫端換算成原生的
------------------------------------------------------------
local function Reserve(panel, depth)
    local top = panel.clampOwnTop or 0
    local states = ns.Skin and ns.Skin.State
    if states and depth < MAX_CHAIN then
        for _, st in pairs(states) do
            local p = st.panel
            if p and p ~= panel and p.mirrorOf == panel and p:IsShown() then
                top = math.max(top, Reserve(p, depth + 1))
            end
        end
    end
    return top
end

-- 回這顆面板的原生該預留的上緣（面板單位）與四邊呼吸；還沒畫過回 nil
function Panel.ClampReserve(panel)
    if not panel or panel.clampOwnTop == nil then return nil end
    return Reserve(panel, 0), panel.clampMargin or 0
end

-- 換鏡射目標（Reserve 沿 mirrorOf 收預留用）
local function SetMirror(panel, target)
    panel.mirrorOf = target
end

------------------------------------------------------------
-- 框與框之間留縫（N1）：點對是「相鄰邊」（我的右邊貼對方的左邊、我的頂貼對方的底…）時往外推 FRAME_GAP；
-- 同邊對齊（TOP→TOP、RIGHT→RIGHT）不動。暴雪的比價框是緊貼的，面板之間貼死看起來像一塊
------------------------------------------------------------
function Panel.GapOffset(point, relPoint, gap)
    if type(point) ~= "string" or type(relPoint) ~= "string" then return 0, 0 end
    local p, r = point:upper(), relPoint:upper()
    local dx, dy = 0, 0
    if p:find("RIGHT", 1, true) and r:find("LEFT", 1, true) then dx = -gap
    elseif p:find("LEFT", 1, true) and r:find("RIGHT", 1, true) then dx = gap end
    if p:find("BOTTOM", 1, true) and r:find("TOP", 1, true) then dy = gap
    elseif p:find("TOP", 1, true) and r:find("BOTTOM", 1, true) then dy = -gap end
    return dx, dy
end

local function Mirror(panel, tip, points)
    local mirrored, target = {}, nil
    for i, p in ipairs(points) do
        local other = PanelOf(p[2], tip, panel)
        if other then target = other end
        mirrored[i] = { p[1], other or p[2], p[3], p[4], p[5] }
    end
    if not target then return nil end
    -- 位移換成 panel 的單位、修整數像素（對方面板的角本來就在整數像素上）
    local tipScale, panelScale = EffectiveScale(tip), EffectiveScale(panel)
    local ratio = (tipScale and panelScale) and (tipScale / panelScale) or 1
    local sig = {}
    local gap = Panel.Scale(panel, LOOK.FRAME_GAP)
    for i, p in ipairs(mirrored) do
        p[4], p[5] = Panel.Snap(panel, p[4] * ratio), Panel.Snap(panel, p[5] * ratio)
        if p[2] ~= points[i][2] then           -- 換成面板的點才留縫（貼原本對象的照舊）
            local gx, gy = Panel.GapOffset(p[1], p[3], gap)
            p[4], p[5] = p[4] + gx, p[5] + gy
        end
        sig[i] = ("%s|%s|%s|%.3f|%.3f"):format(p[1], tostring(p[2]), tostring(p[3]), p[4], p[5])
    end
    SetMirror(panel, target)
    return Apply(panel, "mirror:" .. table.concat(sig, ";"), mirrored)
end

function Panel.Align(panel, tip)
    local points = ReadPoints(tip)
    if not points then return false end
    if #points == 0 then return Keep(panel, tip) end
    if Mirror(panel, tip, points) then return true end
    SetMirror(panel, nil)

    local side, vside = AnchoredSide(tip)
    if not side then return false end
    local dx, dy, rawX, rawY, unlaid = GridOffset(panel, tip, side, vside)
    if unlaid then return Keep(panel, tip) end
    if not dx then return false end
    -- 遲滯：同一個角、角的位置移動不到半個實體像素 ⇒ 沿用上次的整數像素修正。
    -- 原生角停在半像素附近時，每次重算的捨入會在相鄰兩個像素之間翻轉（浮點誤差就夠），面板左右或上下抖 1px
    -- （2026-10-18 實機：鏡射接上之後還剩約 1px 的左右抖）
    local corner = vside .. side
    if panel.gridCorner == corner and panel.gridTip == tip and panel.gridRawX then
        local half = Panel.Pixel(panel, 1) * 0.5
        if math.abs(rawX - panel.gridRawX) <= half and math.abs(rawY - panel.gridRawY) <= half then
            dx, dy = panel.gridDX, panel.gridDY
            rawX, rawY = panel.gridRawX, panel.gridRawY
        end
    end
    panel.gridCorner, panel.gridTip = corner, tip
    panel.gridRawX, panel.gridRawY, panel.gridDX, panel.gridDY = rawX, rawY, dx, dy
    -- 從下緣貼：原生的底是整組（主面板＋縫＋附屬框）的底 ⇒ 主面板往上讓出附屬框那一截
    if vside == "BOTTOM" then
        dy = dy + ((panel.totalHeight or panel.height or 0) - (panel.height or 0))
    end
    local sig = ("own:%s|%s|%.3f|%.3f"):format(corner, tostring(tip), dx, dy)
    return Apply(panel, sig, { { corner, tip, corner, dx, dy } })
end

-- 脫離錨點鏈（重排前、退回時）。keep：重畫時保留「上次怎麼貼的」與對齊的遲滯記憶，
-- 只有退回時才全清——不然每次重畫都重新捨入一次、或在原生暫時沒有點的那一刻失去貼法
function Panel.Detach(panel, keep)
    panel:ClearAllPoints()
    panel.anchored = false
    if not keep then
        SetMirror(panel, nil)
        panel.alignSig, panel.anchorArgs = nil, nil
        panel.gridCorner, panel.gridTip, panel.gridRawX = nil, nil, nil
    end
end
