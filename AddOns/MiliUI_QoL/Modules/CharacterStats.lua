------------------------------------------------------------
-- MiliUI_QoL: 角色面板的自建屬性清單（取代暴雪右側的屬性欄；2026-10-15 從 MiliUI_Skin 搬來）
--
-- 做法照 EllesmereUI 的角色面板（EllesmereUIBlizzardSkin_CharacterSheet.lua 的
-- stock 樣式：清單是 `CharacterStatsPane` 的子框、停在 InsetRight 那一格，暴雪
-- 自己的側邊欄分頁 Show/Hide 那個 pane 就帶著它顯隱）。
--
-- 分區（key ＝ `db.charSheet.statsOrder`／`statsCollapsed`／`statsColors` 裡的 sectionKey）
-- 與每一列的定義、讀值、tooltip 全在共用的 `ns.Stats`（Libs/MiliUIStats.lua）：
--   itemlevel／attributes／secondary／tertiary／attack／defense。
-- 每一區一個顏色（`statsColors[sectionKey]`，沒有就 `Stats.SECTION_COLORS[sectionKey]`），
-- 點標題收合；百分比一律顯示到小數第二位（暴雪的屬性欄是 `%d%%` 四捨五入）。
--
-- **編輯狀態**（角色面板右上角的齒輪開的設定面板開著時，`X.IsEditing()`，
-- 見 CharacterStatsSettings.lua）：
--   * 拖曳區標題排序（物品等級固定第一、不能拖、也不能被插到它前面）；
--   * 每一列左邊一顆勾選框決定顯示（`statsHidden[defKey]`）——被隱藏的列在編輯狀態
--     照樣列出來（alpha 0.4）好讓人勾回來，編輯狀態關掉之後才真的不排；
--   * 區標題右端一顆色票換這一區的顏色（共用層 `W.CreateColorPicker`，暴雪的選色器）。
-- 編輯狀態外色票照樣佔位（alpha 0、不吃滑鼠）：右線一律錨在色票左邊，版面不跳。
--
-- ## 刻意沒做
--
-- * 隱藏整區——把那一區的每一列都取消勾選就等於隱藏整區（標題跟著收起來）。
-- * 把暴雪的 pane 停到螢幕外（EllesmereUI 的 `CharSheetParkStatsPane`，SetPoint 到
--   y=-10000）——那是重排暴雪框，不做；改成整個 pane alpha 0（下表）。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | CharacterStatsPane | `X.Neutralize`（SetAlpha 0）——暴雪的 UpdateStats 照跑、沒人看得到 |
-- | CharacterStatsPane | 當我們宿主框的 parent（CreateFrame 的 parent 參數）＋ SetAllPoints 的錨點 |
-- | CharacterStatsPane | `GetFrameLevel()`（`X.TargetLevel`）——宿主框的層級 ＝ 它 +5 |
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
-- 顯示走 `Stats.ValueTemplate` ＋ `FontString:SetFormattedText`（Libs/MiliUIStats.lua 檔頭）：
-- 數字當**參數**交給引擎畫，戰鬥中照樣是真的數字、照樣會動；「—」只留給 nil。
-- hideZero 只在明碼時判斷，秘密時維持上一次的可見性。
-- tooltip 要在 Lua 裡讀數字 ⇒ 過 `Stats.Num`：秘密值整段收手、不給 tooltip。
-- 物品等級的顏色（`GetItemLevelColor()`）只原封不動交給 SetTextColor／SetVertexColor
-- （傳遞者規則）。這支**不量**任何餵過數值的 FontString（版面是固定列高）。
------------------------------------------------------------
local _, ns = ...

local X = ns.CharSheet
local C = X.C
local S = ns.Secret
local P = ns.P
local W = ns.W
local Stats = ns.Stats

local Num, Try = Stats.Num, Stats.Try
local IsSecret = Stats.IsSecret
local SECTIONS = Stats.SECTIONS
local SECTION_BY_KEY = Stats.SectionByKey

-- 版面（框架單位）。照 EllesmereUI：標題 16 高、列從標題下 22 開始、列高 16、區間距 6。
local TITLE_H     = 16
local TITLE_GAP   = 6
local ROW_H       = 16
local SECTION_GAP = 8
local ILVL_ROW_H  = 26
local SWATCH      = 10    -- 區標題右端的色票（編輯狀態外 alpha 0，疊在右線末端上）
local RULE_GAP    = 6     -- 線與字／色票之間
local PAD         = 6     -- 宿主框的內距（左右上下）
local CHECK       = 14    -- 編輯狀態每列左邊的勾選框
local CHECK_INDENT = 18   -- 編輯狀態標籤往右讓的距離
local HIDDEN_ALPHA = 0.4  -- 編輯狀態裡被隱藏的列
local DRAG_ALPHA   = 0.4  -- 拖曳中的那一個區標題

local FONT_TITLE = 12
local FONT_ROW   = 11
local FONT_ILVL  = 20

local DASH = Stats.DASH

local function DB()
    return X.DB()
end

-- 一區的顏色：玩家換過的（`statsColors`）優先，其次是共用層的預設
local function SectionColor(key)
    local over = DB().statsColors
    local c = type(over) == "table" and over[key]
    if type(c) == "table" and type(c[1]) == "number" then return c end
    return Stats.SECTION_COLORS[key] or C.text
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
    for _, key in ipairs(Stats.DEFAULT_ORDER) do
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
    fs:SetFont(X.Font(), size, "")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    if justify then fs:SetJustifyH(justify) end
    return fs
end

local function SetColor(fs, c, a)
    fs:SetTextColor(c[1], c[2], c[3], a or 1)
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
        local tmpl, args = Stats.ValueTemplate(def, ctx, v, v2)
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
    local bd = X.Backdrop(b, C.fillCheck, C.border)
    -- 勾的貼圖邊長：同 checkGlyphHeight 對 checkBoxSize 的比例，再除掉貼圖留白（勾往外溢）
    local glyph = b:CreateTexture(nil, "OVERLAY")
    glyph:SetTexture(C.checkOutlineTexture)
    local size = CHECK * C.checkGlyphHeight / C.checkBoxSize / C.checkOutlineGlyphFrac
    glyph:SetSize(size, size)
    glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    glyph:SetVertexColor(X.Accent())
    b.glyph = glyph

    b:SetScript("OnEnter", function() bd:SetBorder({ X.Accent() }) end)
    b:SetScript("OnLeave", function() bd:SetBorder(C.border) end)
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
        SetColor(row.label, C.textDim)
        row.value = NewFont(row, FONT_ROW, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        SetColor(row.value, SectionColor(sec.key))
        -- 標籤與數值之間的引導線
        local leader = X.Hairline(row, C.statLeader, "ARTWORK")
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
    ui.ruleL:SetVertexColor(c[1], c[2], c[3], C.statRuleAlpha)
    ui.ruleR:SetVertexColor(c[1], c[2], c[3], C.statRuleAlpha)
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
    local def = Stats.SECTION_COLORS[key]
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

    local rule = { color[1], color[2], color[3], C.statRuleAlpha }
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
        -- 色票只在編輯狀態出現（平時 alpha 0、不吃滑鼠），直接疊在右線末端上
        -- （層級比線高、自帶底色蓋得住）⇒ 兩條線跟物品等級那一區一樣兩端到底，版面不跳
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

        ruleL:SetPoint("LEFT", header, "LEFT", 0, 0)
        ruleL:SetPoint("RIGHT", title, "LEFT", -RULE_GAP, 0)
        ruleR:SetPoint("LEFT", title, "RIGHT", RULE_GAP, 0)
        ruleR:SetPoint("RIGHT", header, "RIGHT", 0, 0)

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
            SetColor(title, C.text)
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
    ui.ruleL:SetVertexColor(r, g, b, C.statRuleAlpha)
    ui.ruleR:SetVertexColor(r, g, b, C.statRuleAlpha)
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
                local tmpl, args = Stats.ValueTemplate(def, ctx, v, v2)
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
    ctx = Stats.BuildContext(DB().statsValueFormat)
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
    -- ⚠ unit 事件一律 RegisterUnitEvent：C 端就濾掉別人，處理器裡不必比對 arg1——
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
        X.Missing("CharacterStatsPane")
        return
    end

    host = CreateFrame("Frame", nil, pane)
    host:SetAllPoints(pane)
    host:SetFrameLevel((X.TargetLevel(pane) or 1) + 5)
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
    X.Neutralize(pane, "CharacterStatsPane")

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

-- 設定頁的「顯示數值」是即時的：改了就重讀一次
function X.RefreshStats()
    X.NotifyStatsChanged("rating")
end

X.Register("statsPanel", Build)
