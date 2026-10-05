------------------------------------------------------------
-- 設定表單的規格與接線（條頁與主題頁共用）
--
--   Specs.Themed(mode, key)       圖示／文字／效果／音效四節（mode = "bar" | "theme"；key ＝ 哪一條，長條沒有按鍵文字那一節）
--   Specs.Layout(key)             版面（條頁）
--   Specs.Visibility()            顯示條件（條頁）
--   Specs.Anchor(key)             錨定（條頁）
--   Specs.MakeCtx(info, onApply)  info = { mode, key }；onApply(spec) 在值寫進去之後叫
--   Specs.BuildForm(parent, controls, ctx, width) → form（content／height／Refresh）
--   Specs.SplitTabs(controls) ／ Specs.CreateTabStrip(...)  主題頁與條頁的分頁（檔尾，J）
--   Specs.FilterSubTab(specs, cur)  分頁裡的子分頁（倒數文字的冷卻｜增益持續時間，K）
--
-- 每條 spec 除了 Controls 要的欄位，另外帶：
--   root     "theme"：主題形狀的欄位（ns.Setting 的 path，條頁讀的是三層繼承後的值、
--            寫進條自己的子表；主題頁直接讀寫 profile.theme）
--            "bar"：條自己的欄位（版面、長條、顯示條件、錨定），不繼承
--            "bar@<key>"：同 "bar"，但讀寫**別的**條或面板（資源條頁上的自訂格子位置／錨定寫進
--            profile.pips）。帶在 root 上是因為 numbers 型的子格只會把 root／sub 往下傳
--   path     點分路徑（numbers 用 sub ＋ 欄位 key 拼）
--   section  "icon" | "text" | "glow" | "fade"：條頁勾著「跟隨全域主題」時整節蓋遮罩
--   get/set  自訂的讀寫（開關型的淡出、第二列尺寸、錨定…），收 info
--   refreshPage  寫完要重建表單（有列會出現／消失）
--   level    真實條的重排等級（預設 layout；錨定是 structure）
--   resetPaths  右鍵「重設為預設」要清哪些 path（預設就是 path）
--   disabled function(info) → 真 ＝ 這一列停用：蓋一層暗色遮罩（擋點擊與右鍵重設，值不動）。
--            表單引擎（共用層）沒有停用狀態，遮罩是 BuildForm 自己畫的；每次套用後重判
--   reloadCheck  寫完（含右鍵重設）檢查圖示外觀要不要重載（Specs.CheckSkinReload）
--   tab      頂層 header 才帶：這一節放在哪個分頁（Specs.SplitTabs；沒分頁的頁不看）
--   subTab   "cooldown" | "duration"：只進那個子分頁的表單（倒數文字的子分頁，K；Specs.FilterSubTab）
--   breakMask  跟隨遮罩在這一列斷開、這一列不蓋（子分頁鈕）
--
-- ⚠ 條頁的主題欄位**讀的是繼承後的值**：沒跟隨、但這一格自己沒存的，看到的是主題的值。
--   顏色若直接回主題那張表，Controls 的色票會就地改掉主題（它拿到表就直接寫 r/g/b）。
--   所以條頁的主題顏色回一個代理表：讀照繼承、第一次寫才把值複製進條自己的子表。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Specs = {}
local Specs = ns.Specs

local LABEL_W = ns.WidgetsEnv.LABEL_W or 128
local FixedSlotsRow      -- 版面那一節的固定格位列（定義在下面）
local CursorRow          -- 錨定那一節的「跟著游標」列（定義在下面）
local GlowSampleRow      -- 發光的預覽圖示（定義在下面）

------------------------------------------------------------
-- 下拉清單
------------------------------------------------------------
local function GrowItems(kind, vertical)
    if kind == "bars" and vertical then
        -- 直向長條（F8c）：條並排；值是直向圖示那組「伸展_換列」（Core/Layout.lua 的 VerticalBarGrow）
        return {
            { text = L["Align top, add bars to the right"],    value = "DOWN_RIGHT" },
            { text = L["Align top, add bars to the left"],     value = "DOWN_LEFT" },
            { text = L["Align bottom, add bars to the right"], value = "UP_RIGHT" },
            { text = L["Align bottom, add bars to the left"],  value = "UP_LEFT" },
        }
    end
    if kind == "bars" then
        return {
            { text = L["Downward"], value = "CENTER_DOWN" },
            { text = L["Upward"],   value = "CENTER_UP" },
        }
    end
    return {
        -- 橫向（值是「對齊_換列」；靠左 ＝ 往右長、靠右 ＝ 往左長，文字講伸展方向）
        { text = L["Grow outward from center, new rows below"], value = "CENTER_DOWN" },
        { text = L["Grow outward from center, new rows above"], value = "CENTER_UP" },
        { text = L["Grow right, new rows below"],               value = "LEFT_DOWN" },
        { text = L["Grow right, new rows above"],               value = "LEFT_UP" },
        { text = L["Grow left, new rows below"],                value = "RIGHT_DOWN" },
        { text = L["Grow left, new rows above"],                value = "RIGHT_UP" },
        -- 直向（值是「伸展_換列」，Core/Layout.lua 的 ParseColumn）
        { text = L["Grow down, new rows to the right"],         value = "DOWN_RIGHT" },
        { text = L["Grow down, new rows to the left"],          value = "DOWN_LEFT" },
        { text = L["Grow up, new rows to the right"],           value = "UP_RIGHT" },
        { text = L["Grow up, new rows to the left"],            value = "UP_LEFT" },
    }
end

local POINT_ITEMS = {
    { text = L["Top left"],     value = "TOPLEFT" },
    { text = L["Top"],          value = "TOP" },
    { text = L["Top right"],    value = "TOPRIGHT" },
    { text = L["Left"],         value = "LEFT" },
    { text = L["Center"],       value = "CENTER" },
    { text = L["Right"],        value = "RIGHT" },
    { text = L["Bottom left"],  value = "BOTTOMLEFT" },
    { text = L["Bottom"],       value = "BOTTOM" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}
Specs.POINT_ITEMS = POINT_ITEMS           -- 單一法術小窗的「文字」分頁（Options/SpellPopover.lua）也用這張

local GLOW_ITEMS = {
    { text = L["Pixel"],          value = "pixel" },
    { text = L["Autocast"],       value = "autocast" },
    { text = L["Action button"],  value = "button" },
    { text = L["Proc"],           value = "proc" },
}
Specs.GLOW_ITEMS = GLOW_ITEMS

-- 就緒發光亮多久（glow.ready.mode，Core/Glow.lua）
local READY_MODE_ITEMS = {
    { text = L["A few seconds"],         value = "timed" },
    { text = L["Until used"],            value = "untilUsed" },
    { text = L["Whenever it's ready"],   value = "whileReady" },
}

-- 冷卻狀態（icon.cdState，Core/Decorate.lua 的冷卻狀態效果）
local CDSTATE_ITEMS = {
    { text = L["No change"],              value = "none" },
    { text = L["Dim while on cooldown"],  value = "dim" },
    { text = L["Hide while on cooldown"], value = "hideOnCD" },
    { text = L["Hide when ready"],        value = "hideReady" },
}
Specs.CDSTATE_ITEMS = CDSTATE_ITEMS

local SIDE_ITEMS = {
    { text = L["Left"],  value = "LEFT" },
    { text = L["Right"], value = "RIGHT" },
    { text = L["None"],  value = "NONE" },
}
-- 直向長條（F8c）：同一個欄位，LEFT ＝ 上、RIGHT ＝ 下
local SIDE_ITEMS_V = {
    { text = L["Top"],    value = "LEFT" },
    { text = L["Bottom"], value = "RIGHT" },
    { text = L["None"],   value = "NONE" },
}

local EMPTY_STYLE_ITEMS = {
    { text = L["Hidden"],    value = "hide" },
    { text = L["Empty bar"], value = "bar" },
}

local GROUP_ITEMS = {
    { text = L["Any"],   value = "any" },
    { text = L["Solo"],  value = "solo" },
    { text = L["Party"], value = "party" },
    { text = L["Raid"],  value = "raid" },
}

-- 音效聲道（PlaySoundFile 的第二個參數；值是暴雪的聲道名，不翻）
local CHANNEL_ITEMS = {
    { text = L["Master"],        value = "Master" },
    { text = L["Sound effects"], value = "SFX" },
    { text = L["Music"],         value = "Music" },
    { text = L["Ambience"],      value = "Ambience" },
    { text = L["Dialog"],        value = "Dialog" },
}

local OUTLINE_ITEMS = {
    { text = L["None"],          value = "" },
    { text = L["Outline"],       value = "OUTLINE" },
    { text = L["Thick outline"], value = "THICKOUTLINE" },
    -- 單色＝關掉反鋸齒：像素字體用（一般字型選了邊緣會有鋸齒）
    { text = L["Monochrome outline"],       value = "MONOCHROME,OUTLINE" },
    { text = L["Monochrome thick outline"], value = "MONOCHROME,THICKOUTLINE" },
}
Specs.OUTLINE_ITEMS = OUTLINE_ITEMS       -- 自訂格子每一列的數字描邊（Options/Tab_Resources.lua）也用這張

-- 錨定的「邊」：本條貼在目標的哪一邊
local EDGE_ITEMS = {
    { text = L["Below it"],       value = "BELOW" },
    { text = L["Above it"],       value = "ABOVE" },
    { text = L["To its left"],    value = "LEFTOF" },
    { text = L["To its right"],   value = "RIGHTOF" },
}
local EDGE_POINTS = {
    BELOW   = { "TOP", "BOTTOM" },
    ABOVE   = { "BOTTOM", "TOP" },
    LEFTOF  = { "RIGHT", "LEFT" },
    RIGHTOF = { "LEFT", "RIGHT" },
}

local function MediaItems(first, kind)
    return function()
        local items = { first }
        for _, name in ipairs(ns.Media.List(kind)) do
            items[#items + 1] = { text = name, value = name }
        end
        return items
    end
end
local BorderItems  = MediaItems({ text = L["Solid"], value = "solid" }, "border")
local TextureItems = MediaItems({ text = L["Solid"], value = "solid" }, "statusbar")
local FontItems    = MediaItems({ text = L["Default font"], value = "DEFAULT" }, "font")
Specs.TextureItems, Specs.FontItems = TextureItems, FontItems

-- 各段文字自己的字型：第一項「跟隨通用字型」（存 "INHERIT"），接著同通用字型的清單
local function ElementFontItems()
    local items = FontItems()
    table.insert(items, 1, { text = L["Follow general font"], value = ns.Media.INHERIT })
    return items
end
Specs.ElementFontItems = ElementFontItems

-- 下拉的值：沒存過（舊存檔、自訂群組）一律顯示成「跟隨通用字型」
local function InheritOr(v)
    return (type(v) == "string" and v ~= "") and v or ns.Media.INHERIT
end
Specs.InheritOr = InheritOr

------------------------------------------------------------
-- 讀寫（主題欄位在條頁與主題頁走不同的表）
------------------------------------------------------------
local function PathOf(spec)
    if spec.path then return spec.path end
    if spec.sub then return spec.sub .. "." .. spec.key end
    return spec.key
end
Specs.PathOf = PathOf

local function ReadThemed(info, path)
    if info.mode == "theme" then return ns.Setting("theme", path) end
    return ns.Setting(info.key, path)
end

local function WriteThemed(info, path, v)
    local p = ns.profile
    if not p then return end
    if info.mode == "theme" then
        ns.DB.SetPath(p.theme, path, v)
    else
        ns.DB.OwnSet(info.key, path, v)
    end
end
Specs.ReadThemed, Specs.WriteThemed = ReadThemed, WriteThemed

-- 代理表本身沒有狀態（每次存取都現讀 ns.Setting／現寫 DB.OwnSet），換設定檔也照樣對 ⇒
-- 以 key|path 快取，表單每次刷新都 ctx.get 不必每次配一張新表
local proxyCache = {}
local function ColorProxy(key, path)
    local ck = tostring(key) .. "|" .. tostring(path)
    local hit = proxyCache[ck]
    if hit then return hit end
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local c = ns.Setting(key, path)
            return type(c) == "table" and c[k] or nil
        end,
        __newindex = function(_, k, v)
            local own = ns.DB.OwnGet(key, path)
            if type(own) ~= "table" then
                own = {}
                local src = ns.Setting(key, path)
                if type(src) == "table" then
                    for kk, vv in pairs(src) do own[kk] = vv end
                end
                ns.DB.OwnSet(key, path, own)
            end
            own[k] = v
        end,
    })
    proxyCache[ck] = proxy
    return proxy
end

-- root 是 "bar@<key>" 時的目標；其他回 nil（讀寫表單自己的 info.key）
local function TargetOf(spec)
    local r = spec and spec.root
    return type(r) == "string" and r:match("^bar@(.+)$") or nil
end
Specs.TargetOf = TargetOf

function Specs.MakeCtx(info, onApply)
    local ctx
    ctx = ns.Controls.MakeCtx(function() return {} end, function()
        onApply(ctx.lastSpec)
    end)
    ctx.info = info
    ctx.get = function(spec)
        if spec.get then return spec.get(info) end
        local path = PathOf(spec)
        if spec.root == "theme" then
            if info.mode ~= "theme" and spec.type == "color" then return ColorProxy(info.key, path) end
            return ReadThemed(info, path)
        end
        return ns.DB.GetPath(ns.DB.ConfigTable(TargetOf(spec) or info.key), path)
    end
    ctx.set = function(spec, v)
        ctx.lastSpec = spec
        if spec.set then spec.set(info, v) return end
        local path = PathOf(spec)
        if spec.root == "theme" then
            WriteThemed(info, path, v)
        else
            ns.DB.SetPath(ns.DB.ConfigTable(TargetOf(spec) or info.key), path, v)
        end
    end
    return ctx
end

------------------------------------------------------------
-- spec 小工具
------------------------------------------------------------
local function Merge(s, extra)
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function TS(section, kind, path, label, extra)
    return Merge({ type = kind, root = "theme", path = path, key = path, label = label, section = section }, extra)
end

local function BS(kind, path, label, extra)
    return Merge({ type = kind, root = "bar", path = path, key = path, label = label }, extra)
end

-- 某段文字的字型下拉（主題繼承那一類）
local function FontTS(section, path)
    return TS(section, "dropdown", path, L["Font"], { items = ElementFontItems,
        get = function(info) return InheritOr(ReadThemed(info, path)) end })
end

-- 某段文字的字型下拉（條自己的欄位）
local function FontBS(path, label)
    return BS("dropdown", path, label, { items = ElementFontItems,
        get = function(info) return InheritOr(ns.DB.GetPath(ns.DB.ConfigTable(info.key), path)) end })
end

-- 錨點九宮格（取代錨點下拉）：3×3 小方格對應圖示的九個角／邊／中心，選中的塗職業色，右邊灰字寫名稱。
-- 讀寫照一般主題欄位（ctx.get／ctx.set 看 root／path），右鍵標籤照樣重設（resettable）
local POINT_TEXT = {}
for _, it in ipairs(POINT_ITEMS) do POINT_TEXT[it.value] = it.text end
local GRID_CELL, GRID_GAP, GRID_PAD = 14, 2, 4
local GRID_IDLE, GRID_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }

local function PointGridTS(section, path, label, fallback)
    local side = GRID_CELL * 3 + GRID_GAP * 2
    local spec = TS(section, "custom", path, label, { resettable = true, h = side + GRID_PAD * 2 })
    spec.build = function(parent, x, y, _, ctx)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(side, side)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - GRID_PAD)
        local name = parent:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontSmall)
        name:SetTextColor(0.65, 0.65, 0.65)
        name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
        local cells, cur = {}, nil
        local function Paint()
            for _, b in ipairs(cells) do
                if b.point == cur then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and GRID_HOVER or GRID_IDLE)) end
            end
            name:SetText(POINT_TEXT[cur] or "")
        end
        for i, it in ipairs(POINT_ITEMS) do
            local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
            b:SetSize(GRID_CELL, GRID_CELL)
            b:SetPoint("TOPLEFT", ((i - 1) % 3) * (GRID_CELL + GRID_GAP), -math.floor((i - 1) / 3) * (GRID_CELL + GRID_GAP))
            W.Stylize(b, GRID_IDLE, { 0, 0, 0, 1 })
            b.point = it.value
            b:SetScript("OnEnter", function() b.hover = true; Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; Paint() end)
            b:SetScript("OnClick", function()
                if cur == it.value then return end
                cur = it.value
                ctx.set(spec, cur)
                ctx.apply()
                Paint()
            end)
            cells[i] = b
        end
        return spec.h, function()
            cur = ctx.get(spec) or fallback
            Paint()
        end
    end
    return spec
end

local function Note(label, section)
    return { type = "text", label = label, section = section }
end

local function Nested(label, section)
    return { type = "header", label = label, nested = true, section = section }
end

------------------------------------------------------------
-- 子分頁（K：倒數文字的「冷卻｜增益持續時間」）
--
-- 表單引擎沒有「藏列」：子分頁的每一個選擇各是一張表單（同分頁的做法往下一層）。spec 帶 subTab 的列
-- 只進那個子分頁的表單（Specs.FilterSubTab）；子分頁鈕那一列（SubTabRow）點了叫 ctx.onSubTab(id)，
-- 頁面換一張表單、捲動位置不動（子分頁鈕上面的列兩張表單一模一樣）。目前選哪個存在 ctx.subTab（頁面建表單時填）。
-- 子分頁鈕那一列 breakMask：跟隨遮罩在這裡斷開（鈕本身不蓋）
-- 卡片（L）：子分頁鈕＋底下一張卡片包住子分頁的列（W.CreateTabCard）。卡片是 content 上的貼圖 ⇒ 列與遮罩都在它上面；
-- 鈕列這一列建卡片、記在 ctx.tabCard，底緣等 BuildForm 排完才知道（最後一個帶 subTab 的列）
------------------------------------------------------------
local SUBTAB_DEFS = {
    { id = "cooldown", label = L["Cooldown"] },
    { id = "duration", label = L["Buff duration"] },
}
Specs.SUBTAB_DEFS = SUBTAB_DEFS

-- 子分頁卡片的「!」說明（W.CreateTabCard 的 help）：兩種各一行，名稱上強調黃（共用層 W.EMPHASIS_COLOR）
function Specs.SubTabHelp()
    local c = W.EMPHASIS_COLOR or { r = 1, g = 0.82, b = 0 }
    local hex = string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
    local function Y(t) return "|c" .. hex .. t .. "|r" end
    return L["%s: the countdown while the spell recharges."]:format(Y(L["Cooldown"])) .. "\n"
        .. L["%s: the countdown of a buff, on buff icons and in the part where a spell shows its buff's time first."]:format(Y(L["Buff duration"]))
end
local SUBTAB_BTN_H, SUBTAB_BTN_MIN_W = 20, 56
-- 卡片（L，W.CreateTabCard）：左右邊跟設定列同寬（見 SubTabRow）；
-- 上緣＝子分頁鈕列底，底＝這張表單最後一個帶 subTab 的列（BuildForm 排完之後補）
local CARD_TOP = 4
-- 卡片左右界：控件欄起點 x 往左扣「標籤與控件的間距＋最長標籤＋內距」，往右到標準控件寬＋內距（共用層 Controls 的版面常數）
local CARD_GAP, CARD_PAD_X, CARD_CTRL_W, CARD_LABEL_MAX = 12, 10, 230, 128
local CARD_LABELS = { "Decimals below", "Color when low", "Low color", "Low below (sec)" }

local function Sub(id, spec)
    if spec then spec.subTab = id end
    return spec
end

local function SubTabRow()
    return { type = "custom", noReset = true, breakMask = true, build = function(parent, x, y, width, ctx)
        local tc = W.CreateTabCard(parent, {
            tabs = SUBTAB_DEFS, tabHeight = SUBTAB_BTN_H, tabMinWidth = SUBTAB_BTN_MIN_W,
            help = Specs.SubTabHelp,
            selected = ctx.subTab,
            onSelect = function(id)
                if id ~= ctx.subTab and ctx.onSubTab then ctx.onSubTab(id) end
            end,
        })
        -- 卡片跟上面的設定列同寬（使用者 2026-10-06：「太胖了，應該和上面一樣的縮排」）：
        -- 左緣＝卡片裡最長的標籤再外推一點（標籤欄靠右對齊，長度依語系），右緣＝控件欄的右緣（標準控件寬）
        local measure = parent:CreateFontString(nil, "OVERLAY")
        measure:SetFontObject(W.fontNormal)
        local labelW = 0
        for _, k in ipairs(CARD_LABELS) do
            measure:SetText(L[k])
            labelW = math.max(labelW, math.ceil(measure:GetStringWidth() or 0))
        end
        measure:Hide()
        labelW = math.min(labelW, CARD_LABEL_MAX)
        local left = math.max(0, x - CARD_GAP - labelW - CARD_PAD_X)
        local right = math.min(x + width, x + CARD_CTRL_W + CARD_PAD_X)
        local h = tc:Place(left, y - CARD_TOP, right - left)
        ctx.tabCard = tc
        ctx.tabCardX = { left = left, right = right }   -- 卡片裡停用列的遮罩只蓋卡片內（BuildForm）
        local function Paint() tc:Select(ctx.subTab or SUBTAB_DEFS[1].id) end
        Paint()
        return CARD_TOP + h + W.TAB_CARD_PAD, Paint
    end }
end

-- → 這個子分頁要的列（沒帶 subTab 的列一律留下）, 這串列有沒有子分頁
function Specs.FilterSubTab(specs, cur)
    cur = cur or SUBTAB_DEFS[1].id
    local out, has = {}, false
    for _, spec in ipairs(specs) do
        if spec.subTab then has = true end
        if not spec.subTab or spec.subTab == cur then out[#out + 1] = spec end
    end
    return out, has
end

-- 「本條 N 個法術有覆寫 ［清除覆寫］」：畫在小節標題那一行的右側，本身不佔高度
local function OverrideRow(group)
    return { type = "custom", h = 0, noReset = true, build = function(parent, x, y, width, ctx)
        local btn = W.CreateButton(parent, L["Clear overrides"], "normal", 90, 18)
        W.FitButton(btn, 90, 18)
        -- 小節標題的字在這一列上方 12 左右（HEADER_H 24 的中線）
        btn:SetPoint("RIGHT", parent, "TOPLEFT", x + width, y + 12)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("RIGHT", btn, "LEFT", -8, 0)
        fs:SetTextColor(0.65, 0.65, 0.65)
        local confirm
        local function Ids()
            local out, hid = ns.Catalog.Bar(ctx.info.key, true)
            for _, id in ipairs(hid or {}) do out[#out + 1] = id end
            return out
        end
        btn:SetScript("OnClick", function()
            if not confirm then
                confirm = W.CreateConfirmPopup(ns.Options.panel, 320,
                    L["Clear this section's per-spell overrides on this bar?"], function()
                        ns.DB.ClearOverrides(Ids(), group)
                        ctx.lastSpec = { level = "layout" }
                        ctx.apply()
                        if ctx.form then ctx.form:Refresh() end
                    end)
            end
            confirm:Show()
        end)
        local function Refresh()
            local n = ns.DB.CountOverrides(Ids(), group)
            fs:SetText(L["%d spells on this bar have overrides"]:format(n))
            fs:SetShown(n > 0)
            btn:SetShown(n > 0)
        end
        return 0, Refresh
    end }
end

-- 自訂語音那一列：按鈕寫著目前筆數，點開是編輯器（Options/CustomSounds.lua）
local function CustomSoundsRow()
    return { type = "custom", label = L["Custom sounds"], h = 30, noReset = true, build = function(parent, x, y)
        local btn = W.CreateButton(parent, "", "normal", 160, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(L["Edit list (%d)"]:format(ns.CustomSounds.Count()))
            W.FitButton(btn, 160, 22)
        end
        btn:SetScript("OnClick", function() ns.CustomSounds.Open(UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
end

local function FollowToggle(group)
    -- 圖示那一節的跟隨：開關一切換，這條實際要的圖示外觀（米利／Masque）可能就變了
    return BS("toggle", "follow." .. group, L["Follow global theme"],
        { refreshPage = true, level = "layout", reloadCheck = group == "icon" or nil })
end

------------------------------------------------------------
-- 圖示外觀（米利／Masque）
--
-- 值是 icon.skin，跟其他圖示設定一樣走主題 → 條的繼承。切換**要重載才生效**（Core/Masque.lua：
-- 每條的模式登入時就定了）⇒ 值寫進去之後，只要有哪一條「設定要的」跟「現在畫的」不同就問要不要重載；
-- 取消就留著設定、下次重載生效，同一個組合不再追問。
-- 選 Masque 時，交給 Masque 的那幾項（邊框材質／粗細／顏色、圖示縮放）停用。
-- 判斷看**設定值**（Desired）而不是現在畫面上的樣子：玩家選了 Masque，那幾格就已經不歸這裡管。
------------------------------------------------------------
local SKIN_ITEMS = {
    { text = L["MiliUI style"], value = "miliui" },
    { text = "Masque",          value = "masque" },
}

local function SkinKey(info) return info.mode == "theme" and "theme" or info.key end

local function MasqueOwns(info)
    return ns.Masque and ns.Masque.Desired(SkinKey(info)) == "masque" or false
end

local reloadPopup, askedSig
function Specs.CheckSkinReload()
    local Mq = ns.Masque
    if not (Mq and Mq.NeedsReload()) then return end
    local sig = Mq.ModesSig()
    if sig == askedSig then return end
    askedSig = sig
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(ns.Options.panel, 320,
            L["The icon style change takes effect after reloading the UI. Reload now?"], function() ReloadUI() end)
    end
    reloadPopup:Show()
end

-- 「開啟 Masque 設定」：只在這條現在真的交給 Masque 的時候能按（群組登入時才建，
-- 還沒重載的話 Masque 裡找不到我們）
local function MasqueOptionsRow()
    return { type = "custom", h = 30, section = "icon", noReset = true, build = function(parent, x, y, width, ctx)
        local btn = W.CreateButton(parent, L["Open Masque settings"], "normal", 140, 22)
        W.FitButton(btn, 140, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        btn:SetScript("OnClick", function() ns.Masque.OpenOptions() end)
        local function Refresh()
            btn:SetEnabled(ns.Masque.Mode(SkinKey(ctx.info)) == "masque")
        end
        return 30, Refresh
    end }
end

local function SkinRows()
    local available = ns.Masque and ns.Masque.Available()
    local rows = {
        TS("icon", "dropdown", "icon.skin", L["Icon style"], {
            items = SKIN_ITEMS, reloadCheck = true,
            get = function(info) return ReadThemed(info, "icon.skin") or "miliui" end,
            disabled = function() return not (ns.Masque and ns.Masque.Available()) end,
        }),
    }
    if available then
        rows[#rows + 1] = Note(L["Masque draws the border, icon crop and swipe texture with the skin picked in its own settings; text, colors and glows stay here. Switching needs a UI reload."], "icon")
        rows[#rows + 1] = MasqueOptionsRow()
    else
        rows[#rows + 1] = Note(L["Install Masque to pick its skins here."], "icon")
    end
    return unpack(rows)
end

------------------------------------------------------------
-- 圖示／文字／效果（條頁與主題頁同一份）
------------------------------------------------------------
function Specs.Themed(mode, key)
    local bar = mode == "bar"
    local list = {}
    local function add(...)
        for i = 1, select("#", ...) do
            local s = select(i, ...)
            if s then list[#list + 1] = s end
        end
    end
    -- 增益兩條（內建）沒有冷卻：觸發發光（技能的觸發亮框）、就緒發光、冷卻中去飽和、隱藏 GCD 轉圈都用不到
    local auraBar = bar and key and ns.DB.IsBuiltinBar(key) and ns.Viewers.AURA_KIND[key] and true or false
    local function CD(s) if auraBar then return nil end return s end
    -- 反過來：核心／輔助（內建的冷卻兩條）沒有光環，減益邊框用不到
    local cdBar = bar and key and ns.DB.IsBuiltinBar(key) and not ns.Viewers.AURA_KIND[key] and true or false
    local function AU(s) if cdBar then return nil end return s end
    -- 冷卻狀態效果：增益兩條（內建）與長條類的條用不到（長條上的自訂冷卻也不套：Decorate 對長條不給 cdState）
    local bt = bar and key and ns.DB.BarTable(key)
    local barsKind = type(bt) == "table" and bt.kind == "bars" or false
    local function CS(s) if auraBar or barsKind then return nil end return s end
    -- 長條類的條：倒數與充能的文字樣式用不到（長條的秒數字型／字級在「長條」節；秒數是暴雪每幀寫的，
    -- 小數門檻與低秒變色都換不了），只留層數
    local function NB(s) if barsKind then return nil end return s end
    -- 按鍵鏡射：長條類與增益圖示列不做（Core/Keybinds.lua 的 NoKeybind 同時涵蓋兩者）
    local noPress = bar and key and ns.Keybinds.NoKeybind(key) or false
    local function NK(s) if noPress then return nil end return s end
    local function NotDim(info) return (ReadThemed(info, "icon.cdState") or "none") ~= "dim" end
    -- 像素發光的線條數／粗細：粗細只有像素樣式吃；線條數像素與自動施法都吃（玩家回報邊框太粗、以前習慣設 1）
    local function NotPixel(path) return function(info) return (ReadThemed(info, path) or "pixel") ~= "pixel" end end
    local function NoLines(path)
        return function(info)
            local t = ReadThemed(info, path) or "pixel"
            return t ~= "pixel" and t ~= "autocast"
        end
    end
    local function AuraTimeOff(info) return ReadThemed(info, "icon.showAuraTime") == false end
    local function DurationOff(info) return AuraTimeOff(info) or not ReadThemed(info, "icon.colorDuration") end
    -- 增益持續時間的變色顏色／變色秒數：只有增益持續時間的低秒變色（I）用得到 ⇒ 開關關著就停用
    -- （換色那一段的字色是「增益持續時間顏色」，低秒那一段的顏色不歸換色開關管：Text.BuffTiming）
    local function BuffLowOff(info) return not ReadThemed(info, "cooldownText.buffLowColor") end
    -- 冷卻那一組同理：開關 lowColorOn 關著時變色顏色／變色秒數停用（跟增益持續時間那組一樣蓋遮罩）。
    -- 開關只認 false 是關（引擎 Text.CdLowBelow 同一個判準：沒存 ＝ 開）
    local function CdLowOff(info) return ReadThemed(info, "cooldownText.lowColorOn") == false end

    -- 圖示
    add({ type = "header", label = L["Icons"], tab = "icon" })
    if bar then add(OverrideRow("icon"), FollowToggle("icon"),
        Note(L["While checked, this section uses the Theme page. Uncheck it to give this bar its own values."])) end
    add(SkinRows())
    add(TS("icon", "dropdown", "border.texture", L["Border texture"], { items = BorderItems, disabled = MasqueOwns }),
        TS("icon", "slider", "border.size", L["Border size"], { min = 0, max = 4, step = 1, disabled = MasqueOwns }),
        TS("icon", "color", "border.color", L["Border color"], { disabled = MasqueOwns }),
        TS("icon", "slider", "icon.zoom", L["Icon zoom"], { min = 0, max = 0.2, step = 0.01, disabled = MasqueOwns }),
        Note(L["Crops the icon edges; 0 shows the whole texture."], "icon"),
        TS("icon", "color", "icon.swipeColor", L["Cooldown swipe color"], { hasAlpha = true }),
        CD(TS("icon", "toggle", "icon.hideGCDSwipe", L["Hide GCD swipe"])),
        CD(TS("icon", "toggle", "icon.desaturateOnCooldown", L["Desaturate on cooldown"])),
        CS(TS("icon", "dropdown", "icon.cdState", L["Cooldown state"], { items = CDSTATE_ITEMS,
            get = function(info) return ReadThemed(info, "icon.cdState") or "none" end })),
        CS(TS("icon", "slider", "icon.cdStateAlpha", L["Dimmed opacity"],
            { min = 10, max = 90, step = 5, scale = 100, disabled = NotDim })),
        CS(Note(L["Hidden icons keep their place. The global cooldown doesn't count, and a spell with a charge left counts as ready. Buffs aren't affected."], "icon")),
        -- 增益持續中顯示持續時間（核心／輔助才有「先倒增益」那一段：增益兩條與長條類的條不顯示）
        CS(TS("icon", "toggle", "icon.showAuraTime", L["Show buff duration"])),
        CS(Note(L["After you use a spell that gives you a buff, the icon counts down the buff first and the cooldown after it ends. Off shows the cooldown right away."], "icon")),
        -- 增益那一段的倒數換色：開關關著時沒有那一段可換色 ⇒ 兩列停用
        CS(TS("icon", "toggle", "icon.colorDuration", L["Recolor buff duration"], { disabled = AuraTimeOff })),
        CS(TS("icon", "color", "icon.durationColor", L["Buff duration color"], { disabled = DurationOff })),
        -- 增益持續時間的變色顏色（icon.durationLowColor）搬到「文字」節增益持續時間那一組（J），資料路徑不變
        CS(TS("icon", "color", "icon.durationSwipeColor", L["Buff duration swipe color"], { hasAlpha = true, disabled = DurationOff })),
        CS(Note(L["After you use a spell that gives you a buff, the countdown shows the buff's remaining time first and the cooldown only after it ends. This colors that first part."], "icon")),
        AU(TS("icon", "toggle", "icon.hideDebuffBorder", L["Hide debuff type border"])),
        AU(Note(L["Blizzard frames debuffs you track (on your target) in their dispel-type color."], "icon")),
        -- 沒有物品時隱藏（自訂物品）／被動飾品不顯示（飾品欄、代畫格）：收掉＝讓位（Core/Bars.lua）；逐法術小窗可以蓋
        TS("icon", "toggle", "icon.hideNoItem", L["Hide when none in bags"]),
        Note(L["Items you added yourself don't show once none are left in your bags (alternatives count too), and the icons after them move up. Bars with fixed slots keep the slot empty."], "icon"),
        TS("icon", "toggle", "icon.hidePassiveTrinket", L["Hide passive trinkets"]),
        Note(L["Equipment slot icons don't show while the equipped item has no use effect, such as a passive trinket. Trinket buff icons don't show while the trinket has no buff to track. Empty slots still show."], "icon"),
        TS("icon", "toggle", "icon.tooltips", L["Show tooltip on hover"]),
        Note(L["Off also hides Blizzard's own tooltip for these icons. Clicks still pass through."], "icon"),
        -- 按鍵鏡射（Core/Keybinds.lua）：長條類與增益圖示列不做（同按鍵文字的 NoKeybind），條頁不出現這三列
        NK(TS("icon", "toggle", "icon.pressFlash", L["Flash on key press"])),
        NK(Note(L["Flashes when you press the key bound to this spell's action bar slot. Only key bindings count; clicking the action bar doesn't."], "icon")),
        NK(TS("icon", "slider", "icon.pressFlashAlpha", L["Flash opacity"],
            { min = 10, max = 80, step = 5, scale = 100,
              disabled = function(info) return not ReadThemed(info, "icon.pressFlash") end })))

    -- 文字
    add({ type = "header", label = L["Text"], tab = "text" })
    if bar then add(OverrideRow("text"), FollowToggle("text")) end
    -- 通用字型：每段文字的字型沒另外挑時用這個（條頁沒跟隨主題時也能改）
    add(TS("text", "dropdown", "font", L["General font"], { items = FontItems }),
        TS("text", "dropdown", "outline", L["Outline"], { items = OUTLINE_ITEMS }))
    add(NB(Nested(L["Countdown"], "text")),
        NB(FontTS("text", "cooldownText.font")),
        NB(TS("text", "slider", "cooldownText.size", L["Font size"], { min = 6, max = 40, step = 1 })),
        NB(TS("text", "color", "cooldownText.color", L["Color"])),
        -- 從小數門檻開始分兩個子分頁「冷卻｜增益持續時間」（K）：同一組四列（小數門檻、低秒變色、變色顏色、變色秒數），
        -- 標籤不帶前綴（子分頁已經講了是哪一種）。子分頁鈕那一列不歸任何 section（勾著跟隨也要點得到：
        -- 增益持續時間那組的變色顏色歸「圖示」的跟隨管，文字跟隨著時照樣要切得過去），也切斷跟隨遮罩的那一段
        NB(SubTabRow()),
        -- 冷卻：低秒變色的開關（lowColorOn）與變色秒數（lowBelow）分兩欄，取消勾選不動秒數（2026-10-06 拆開，舊存檔 MIGRATIONS[5]）
        NB(Sub("cooldown", TS("text", "slider", "cooldownText.decimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }))),
        NB(Sub("cooldown", Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"))),
        NB(Sub("cooldown", TS("text", "toggle", "cooldownText.lowColorOn", L["Color when low"]))),
        NB(Sub("cooldown", TS("text", "color", "cooldownText.lowColor", L["Low color"], { disabled = CdLowOff }))),
        -- 拉桿最小 1：關交給上面的勾選（跟增益持續時間那組一樣從 1 起）
        NB(Sub("cooldown", TS("text", "slider", "cooldownText.lowBelow", L["Low below (sec)"],
            { min = 1, max = 30, step = 1, disabled = CdLowOff }))),
        -- 增益持續時間（I／J）：自己的小數門檻、低秒變色開關、變色顏色、變色秒數。長條類的條沒有
        -- （秒數是暴雪寫的／整數）。變色顏色的資料在 icon.durationLowColor（跟「圖示」那一節的跟隨與覆寫分組），
        -- 所以那一列的 section 是 icon：條頁勾著圖示跟隨時蓋的是圖示的遮罩
        NB(Sub("duration", TS("text", "slider", "cooldownText.buffDecimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }))),
        NB(Sub("duration", Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"))),
        NB(Sub("duration", TS("text", "toggle", "cooldownText.buffLowColor", L["Color when low"]))),
        NB(Sub("duration", TS("icon", "color", "icon.durationLowColor", L["Low color"], { disabled = BuffLowOff }))),
        NB(Sub("duration", TS("text", "slider", "cooldownText.buffLowBelow", L["Low below (sec)"],
            { min = 1, max = 30, step = 1, disabled = BuffLowOff }))),
        NB(Nested(L["Charges"], "text")),
        NB(FontTS("text", "chargeText.font")),
        NB(TS("text", "slider", "chargeText.size", L["Font size"], { min = 6, max = 30, step = 1 })),
        NB(TS("text", "color", "chargeText.color", L["Color"])),
        NB(PointGridTS("text", "chargeText.point", L["Anchor"], "BOTTOMRIGHT")),
        NB(TS("text", "numbers", nil, L["Offset"], { sub = "chargeText", path = false,
            resetPaths = { "chargeText.x", "chargeText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })),
        Nested(L["Stacks"], "text"),
        FontTS("text", "stackText.font"),
        TS("text", "slider", "stackText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
        TS("text", "color", "stackText.color", L["Color"]),
        NB(PointGridTS("text", "stackText.point", L["Anchor"], "TOP")),
        -- 長條的層數另存一個錨點（圖示小、預設右下）：主題頁兩個都列，長條類的條頁只列這個、標籤就叫「錨點」
        (not bar or barsKind) and PointGridTS("text", "stackText.barPoint",
            bar and L["Anchor"] or L["Anchor (bars)"], "BOTTOMRIGHT") or nil,
        TS("text", "numbers", nil, L["Offset"], { sub = "stackText", path = false,
            resetPaths = { "stackText.x", "stackText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))

    -- 效果（發光、無損刷新、按鍵文字）＋淡出
    add({ type = "header", label = L["Effects"], tab = "glow" })
    if bar then add(OverrideRow("glow"), FollowToggle("glow")) end
    if not auraBar then
        add(Nested(L["Proc glow"], "glow"),
            TS("glow", "toggle", "glow.proc.enabled", L["Enable"]),
            Note(L["Replaces Blizzard's proc glow. When off, Blizzard's own glow shows."], "glow"),
            TS("glow", "dropdown", "glow.proc.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.proc.color", L["Color"]),
            TS("glow", "slider", "glow.proc.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.proc.type") }),
            TS("glow", "slider", "glow.proc.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NotPixel("glow.proc.type") }),
            GlowSampleRow("proc"),
            Nested(L["Ready glow"], "glow"),
            TS("glow", "toggle", "glow.ready.enabled", L["Enable"]),
            Note(L["Glows when a cooldown is ready. The global cooldown doesn't count."], "glow"),
            TS("glow", "dropdown", "glow.ready.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.ready.color", L["Color"]),
            TS("glow", "slider", "glow.ready.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.ready.type") }),
            TS("glow", "slider", "glow.ready.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NotPixel("glow.ready.type") }),
            GlowSampleRow("ready"),
            TS("glow", "dropdown", "glow.ready.mode", L["Glow for"], { items = READY_MODE_ITEMS }),
            Note(L["\"Until used\" starts when a cooldown finishes, so after a reload it waits for the first use. Spells with charges still go out after the duration."], "glow"),
            TS("glow", "slider", "glow.ready.duration", L["Duration (sec)"], { min = 1, max = 10, step = 1,
                disabled = function(info) return (ReadThemed(info, "glow.ready.mode") or "timed") == "whileReady" end }),
            TS("glow", "toggle", "glow.ready.requireUsable", L["Wait for resources"],
                { disabled = function(info) return (ReadThemed(info, "glow.ready.mode") or "timed") == "whileReady" end }),
            Note(L["If the cooldown is ready but you lack the resources, the glow waits until you have enough."], "glow"),
            -- 充能滿了發光（Core/Glow.lua 的 SyncFull）：同一套開關＋樣式，預設關
            Nested(L["Glow at max charges"], "glow"),
            TS("glow", "toggle", "glow.full.enabled", L["Enable"]),
            Note(L["Glows while a spell with charges has all of them back. Spells without charges never glow."], "glow"),
            TS("glow", "dropdown", "glow.full.type", L["Style"], { items = GLOW_ITEMS }),
            TS("glow", "color", "glow.full.color", L["Color"]),
            TS("glow", "slider", "glow.full.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.full.type") }),
            TS("glow", "slider", "glow.full.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NotPixel("glow.full.type") }),
            GlowSampleRow("full"))
    end
    -- 生效期間發光：跟觸發／就緒同一套（開關、樣式、顏色、線條、粗細、預覽，跟隨主題的繼承也一樣；使用者 2026-10-03）。
    -- 預設關：多半只在幾個法術上個別打開（預覽點圖示）
    add(Nested(L["Glow during buff"], "glow"),
        TS("glow", "toggle", "glow.active.enabled", L["Enable"]),
        Note(L["Glows while the buff is up; on Essential and Utility, while the icon shows the buff's time. Off by default: turn it on for single spells by clicking their icon in the preview."], "glow"),
        TS("glow", "dropdown", "glow.active.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.active.color", L["Color"]),
        TS("glow", "slider", "glow.active.lines", L["Lines"], { min = 2, max = 16, step = 1, disabled = NoLines("glow.active.type") }),
        TS("glow", "slider", "glow.active.thickness", L["Thickness"], { min = 1, max = 4, step = 1, disabled = NotPixel("glow.active.type") }),
        GlowSampleRow("active"))
    add(Nested(L["Pandemic"], "glow"),
        TS("glow", "toggle", "pandemic.enabled", L["Color the border"]),
        Note(L["While a buff or debuff can be refreshed without losing time, its border turns this color."], "glow"),
        TS("glow", "color", "pandemic.color", L["Pandemic border color"]),
        TS("glow", "toggle", "pandemic.bars", L["Color bars too"]))
    -- 按鍵文字：長條與增益圖示列沒有這一節，引擎也不畫（Core/Keybinds.lua 的 NoKeybind）
    if not (bar and key and ns.Keybinds.NoKeybind(key)) then
        add(Nested(L["Keybind text"], "glow"),
            TS("glow", "toggle", "keybind.enabled", L["Show keybind text"]),
            FontTS("glow", "keybind.font"),
            TS("glow", "slider", "keybind.size", L["Font size"], { min = 6, max = 24, step = 1 }),
            PointGridTS("glow", "keybind.point", L["Anchor"], "TOPRIGHT"),
            TS("glow", "numbers", nil, L["Offset"], { sub = "keybind", path = false,
                resetPaths = { "keybind.x", "keybind.y" },
                fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))
    end
    add(Nested(L["Fade"]))
    if bar then add(BS("toggle", "follow.fade", L["Follow global theme"], { refreshPage = true })) end
    add(TS("fade", "toggle", "fade.enabled", L["Fade the bar"]),
        TS("fade", "slider", "fade.alpha", L["Faded opacity"], { min = 0, max = 100, step = 5, scale = 100 }),
        Note(L["0 hides it completely."], "fade"),
        Nested(L["Stay fully visible when"], "fade"),
        TS("fade", "toggle", "fade.keepInCombat", L["In combat"]),
        TS("fade", "toggle", "fade.keepWithTarget", L["Has a target"]),
        Note(L["Any checked condition that holds keeps the bar fully visible. With none checked it stays faded whenever fading is on."], "fade"),
        TS("fade", "toggle", "fade.whenMounted", L["Always fade while mounted"]),
        Note(L["Mounted or in a vehicle: fades regardless of the conditions above."], "fade"))

    -- 音效：響什麼是逐法術設定（預覽裡點圖示）；主題頁放總開關與聲道，條頁只有覆寫數＋清除。
    -- 不掛 section：音效不走「跟隨全域主題」，條頁不蓋遮罩
    add({ type = "header", label = L["Sounds"], tab = "sound" })
    if bar then
        add(OverrideRow("sound"),
            Note(L["Sounds are set per spell: click an icon in the preview above. The on/off switch and channel are on the Theme page."]))
    else
        add(TS(nil, "toggle", "sound.enabled", L["Enable"]),
            TS(nil, "dropdown", "sound.channel", L["Channel"], { items = CHANNEL_ITEMS }),
            CustomSoundsRow(),
            Note(L["Which sound plays is set per spell: click an icon in a bar's preview. Nothing plays for 2 seconds after a loading screen, and the same spell doesn't repeat within 1.5 seconds."]))
    end
    return list
end

------------------------------------------------------------
-- 固定格位：條上有光環格（含飾品欄增益）、疊著增益的飾品欄（Catalog.BarHasAuraSlot）、或這條可點擊時強制打開
-- （勾選框停用、說明換成原因；存的值不動）
--
-- 表單引擎的 toggle 沒有「停用」這個狀態，所以自己畫一列（custom）：勾選框＋下一列灰字，
-- 灰字依狀態換三種說法（一般／有光環格／可點擊），高度取三種裡最高的那個（列高在建表單時就定了）。
------------------------------------------------------------
function FixedSlotsRow(key, isBars)
    local NORMAL = isBars and L["Buffs that aren't up keep their place, so the others don't shift."]
        or L["Buffs that aren't up keep their place as a dimmed icon, so the others don't shift."]
    local FORCED = L["Always on while this bar has aura slots or trinkets showing their buff: they need fixed positions, because they can't move during combat."]
    local FORCED_CLICK = L["Always on while this bar is clickable: the click targets can't move during combat."]
    -- 強制的原因：有光環格優先（兩者都成立時講光環格那句）；nil ＝ 沒有強制
    local function ForcedText()
        if ns.Catalog.BarHasAuraSlot(key) then return FORCED end
        if ns.DB.BarClickable(key) then return FORCED_CLICK end
        return nil
    end
    return { type = "custom", label = L["Keep empty slots for missing buffs"], h = 26, root = "bar",
             path = "layout.fixedSlots", key = "layout.fixedSlots",
             build = function(parent, x, y, width, ctx)
        local cb = W.CreateCheckButton(parent, nil, function(on)
            local b = ns.DB.BarTable(key)
            if not b or ForcedText() then return end
            b.layout.fixedSlots = on and true or false
            ctx.lastSpec = { level = "layout" }
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(FORCED)
        local h1 = fs:GetStringHeight() or 14
        fs:SetText(FORCED_CLICK)
        local h3 = fs:GetStringHeight() or 14
        fs:SetText(NORMAL)
        local h2 = fs:GetStringHeight() or 14
        local h = 30 + math.max(14, h1, h2, h3) + 8
        local function Refresh()
            local reason = ForcedText()
            local forced = reason ~= nil
            local b = ns.DB.BarTable(key)
            local v = b and type(b.layout) == "table" and b.layout.fixedSlots
            cb:SetChecked((forced or v) and true or false)
            cb:SetEnabled(not forced)
            cb:SetAlpha(forced and 0.5 or 1)
            fs:SetText(reason or NORMAL)
            fs:SetTextColor(forced and 1 or 0.65, forced and 0.82 or 0.65, forced and 0 or 0.65)
        end
        return h, Refresh
    end }
end

------------------------------------------------------------
-- 跟著游標（自訂圖示群組，Core/Cursor.lua）：勾選框＋下一列灰字。條上有光環格、或勾了可點擊時不能跟
-- （容器變保護框，戰鬥中不能移）：勾選框停用、灰字換成原因（黃字）；存的值不動，條件解除就回來。
-- 寫法同 FixedSlotsRow（表單引擎的 toggle 沒有停用狀態），高度取三種說法裡最高的。
------------------------------------------------------------
function CursorRow(key)
    local NORMAL = L["The group stays next to your mouse pointer. It goes back to its own position in Edit Mode and while this window is open."]
    local NO_AURA = L["Not available while this group has aura slots or trinkets showing their buff: they can't move during combat."]
    local NO_CLICK = L["Not available while this group is clickable: the click targets can't move during combat."]
    local function Blocked()
        local b = ns.DB.BarTable(key)
        local ok, why = ns.Cursor.Eligible(b, ns.Catalog.BarHasAuraSlot(key))
        if ok then return nil end
        if why == "aura" then return NO_AURA end
        if why == "click" then return NO_CLICK end
        return nil
    end
    return { type = "custom", label = L["Follow the mouse pointer"], h = 26, root = "bar",
             path = "cursor.enabled", key = "cursor.enabled",
             build = function(parent, x, y, width, ctx)
        local cb = W.CreateCheckButton(parent, nil, function(on)
            local b = ns.DB.BarTable(key)
            if not b or Blocked() then return end
            if type(b.cursor) ~= "table" then b.cursor = { x = ns.Cursor.DEFAULT_X, y = ns.Cursor.DEFAULT_Y } end
            b.cursor.enabled = on and true or false
            ctx.lastSpec = { level = "structure" }
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 30)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        local hs = {}
        for i, t in ipairs({ NO_AURA, NO_CLICK, NORMAL }) do
            fs:SetText(t)
            hs[i] = fs:GetStringHeight() or 14
        end
        local h = 30 + math.max(14, hs[1], hs[2], hs[3]) + 8
        local function Refresh()
            local reason = Blocked()
            local blocked = reason ~= nil
            local b = ns.DB.BarTable(key)
            local v = b and type(b.cursor) == "table" and b.cursor.enabled == true
            cb:SetChecked((v and not blocked) and true or false)
            cb:SetEnabled(not blocked)
            cb:SetAlpha(blocked and 0.5 or 1)
            fs:SetText(reason or NORMAL)
            fs:SetTextColor(blocked and 1 or 0.65, blocked and 0.82 or 0.65, blocked and 0 or 0.65)
        end
        return h, Refresh
    end }
end

------------------------------------------------------------
-- 發光預覽：一顆樣本圖示一直亮著目前的樣式與顏色，切樣式當場看得到效果。
-- 引擎跟格子共用（ns.Glow.PaintOn／StopOn）；就緒發光在格子上只亮幾秒，樣本則常亮。
-- 表單引擎在值變了之後只叫 ctx.apply、不叫 refreshers ⇒ 包一層 ctx.apply 讓樣本跟著換。
-- path（可省）：樣式表在主題的哪裡，預設 "glow.<which>"（戰鬥輔助頁的醒目標示是 "assist"）
------------------------------------------------------------
local SAMPLE_ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"
local SAMPLE_SIZE = 36

function GlowSampleRow(which, path)
    path = path or ("glow." .. which)
    return { type = "custom", label = L["Preview"], h = SAMPLE_SIZE + 8, section = "glow", noReset = true,
             build = function(parent, x, y, width, ctx)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(SAMPLE_SIZE, SAMPLE_SIZE)
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 1)
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexture(SAMPLE_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local host = CreateFrame("Frame", nil, f)
        host:SetAllPoints()
        host:SetFrameLevel(f:GetFrameLevel() + 2)

        local shown, sig
        local function Refresh()
            local G = ns.Glow
            if not (G and G.PaintOn) then return end
            local c = ReadThemed(ctx.info, path)
            c = type(c) == "table" and c or {}
            local col = type(c.color) == "table" and c.color or {}
            local now = table.concat({ tostring(c.type), tostring(col.r), tostring(col.g),
                tostring(col.b), tostring(col.a), tostring(c.lines), tostring(c.thickness),
                tostring(c.frequency) }, "|")
            if shown and now == sig then return end
            if shown then G.StopOn(host, shown, which) end
            shown = G.PaintOn(host, c, which, which, false)
            sig = now
        end
        local apply = ctx.apply
        ctx.apply = function(...)
            apply(...)
            Refresh()
        end
        return SAMPLE_SIZE + 8, Refresh
    end }
end
Specs.GlowSampleRow = function(which, path) return GlowSampleRow(which, path) end

------------------------------------------------------------
-- 版面（條自己的欄位）
------------------------------------------------------------
------------------------------------------------------------
-- 格數上限＋溢出（Core/Overflow.lua）：「最多顆數」滑桿＋灰字、「超出的放到」下拉＋灰字。圖示類的條才有。
--   * 下拉的候選：其他圖示類、自己沒設上限的條（接收條不能再溢出）；目前存的目標就算不成立也列出來（灰字寫原因）
--   * 自己沒設上限時下拉停用（值不動）
--   * 被別條指為接收條（那條有設上限）：滑桿停用、灰字寫原因
-- 誰指到誰、誰有上限都進 BarSignature（自己的上限除外：拖滑桿過 0 不能整張表單重建），所以候選清單與原因字
-- 在建表單時算就準
------------------------------------------------------------
local function OverflowRows(key)
    local O, C = ns.Overflow, ns.Catalog
    local cfgOf = C.BarCfgOf
    local keys = C.BarKeys()
    local function Title(k) return ns.Options.BarTitle(k) or tostring(k) end
    local rows = {}
    local recv = O.Receivers(keys, cfgOf)[key]
    local function Receiving() return O.Receivers(C.BarKeys(), cfgOf)[key] ~= nil end
    rows[#rows + 1] = BS("slider", "layout.maxIcons", L["Max icons"], { min = 0, max = O.MAX, step = 1,
        fallback = 0,
        get = function() return O.MaxOf(cfgOf(key)) end,
        disabled = Receiving })
    if recv then
        local names = {}
        for i, k in ipairs(recv) do names[i] = Title(k) end
        rows[#rows + 1] = Note(L["This bar takes the overflow from %s, so it can't have a limit of its own."]
            :format(table.concat(names, " / ")))
    else
        rows[#rows + 1] = Note(L["0 means no limit. Icons past the limit move to the bar chosen below."])
    end

    local cur = O.TargetKey(cfgOf(key))
    local items = { { text = L["None"], value = "none" } }
    for _, k in ipairs(keys) do
        local b = cfgOf(k)
        if k ~= key and (k == cur or (b.kind ~= "bars" and O.MaxOf(b) == 0)) then
            items[#items + 1] = { text = Title(k), value = k }
        end
    end
    rows[#rows + 1] = BS("dropdown", "layout.overflowTo", L["Overflow to"], { items = items, refreshPage = true,
        resetPaths = { "layout.overflowTo" },
        get = function()
            local to = O.TargetKey(cfgOf(key))
            return (to and cfgOf(to)) and to or "none"
        end,
        set = function(_, v)
            local b = ns.DB.BarTable(key)
            if not b then return end
            if type(b.layout) ~= "table" then b.layout = {} end
            b.layout.overflowTo = (v ~= "none" and v ~= key) and v or false
        end,
        disabled = function() return O.MaxOf(cfgOf(key)) <= 0 end })
    -- 存的目標不成立的原因（跟自己的上限無關的那三種）；成立或沒選就是一般說明
    local why
    if cur and cur ~= key then
        local t = cfgOf(cur)
        if not t then why = "missing"
        elseif t.kind == "bars" then why = "notIcons"
        elseif O.MaxOf(t) > 0 then why = "capped" end
    end
    if why == "notIcons" then
        rows[#rows + 1] = Note(L["%s shows bars, not icons, so the number of icons isn't limited."]:format(Title(cur)))
    elseif why == "capped" then
        rows[#rows + 1] = Note(L["%s has a limit of its own, so the number of icons isn't limited."]:format(Title(cur)))
    else
        rows[#rows + 1] = Note(L["Without a target, the number of icons isn't limited."])
    end
    return rows
end

-- 表單簽章裡的溢出那一段：別條的「有沒有上限／指到誰／類型」＋自己指到誰（自己的上限不進：見 OverflowRows）
function Specs.OverflowSig(key)
    local O, C = ns.Overflow, ns.Catalog
    if not (O and C and C.BarKeys) then return "" end
    local parts = {}
    for _, k in ipairs(C.BarKeys()) do
        local b = C.BarCfgOf(k)
        local to = O.TargetKey(b) or "-"
        if k == key then
            parts[#parts + 1] = "@>" .. to
        else
            parts[#parts + 1] = k .. (b.kind == "bars" and "b" or "i") .. (O.MaxOf(b) > 0 and "#" or "") .. ">" .. to
        end
    end
    return table.concat(parts, ",")
end

-- 漸層填充（bar.gradient，F8a）：勾選＋方向＋終點色＋灰字。關 ＝ false；勾下去給一組預設
-- （方向橫、終點色＝條色往白混一半）。方向與終點色沒勾時停用、右鍵不重設（整組由勾選那列重設）
local GRADIENT_DIR_ITEMS = {
    { text = L["Horizontal"], value = "H" },
    { text = L["Vertical"],   value = "V" },
}
local function GradientRows(key)
    local function Cfg(info)
        local b = ns.DB.ConfigTable(info and info.key or key)
        return type(b) == "table" and type(b.bar) == "table" and b.bar or nil
    end
    local function On(info)
        local bar = Cfg(info)
        return bar ~= nil and ns.Decorate.CleanGradient(bar.gradient) ~= nil
    end
    return {
        BS("toggle", "bar.gradient", L["Gradient"], {
            get = function(info) return On(info) end,
            set = function(info, on)
                local bar = Cfg(info)
                if not bar then return end
                if on then
                    local c = type(bar.color) == "table" and bar.color or {}
                    local function mix(v, d) return ((tonumber(v) or d) + 1) / 2 end
                    bar.gradient = { dir = "H", color2 = { r = mix(c.r, 0.4), g = mix(c.g, 0.6), b = mix(c.b, 0.9),
                                                           a = tonumber(c.a) or 1 } }
                else
                    bar.gradient = false
                end
            end }),
        BS("dropdown", "bar.gradient.dir", L["Gradient direction"], { items = GRADIENT_DIR_ITEMS, noReset = true,
            get = function(info)
                local bar = Cfg(info)
                local g = bar and type(bar.gradient) == "table" and bar.gradient or nil
                return (g and g.dir == "V") and "V" or "H"
            end,
            set = function(info, v)
                local bar = Cfg(info)
                if bar and type(bar.gradient) == "table" then bar.gradient.dir = (v == "V") and "V" or "H" end
            end,
            disabled = function(info) return not On(info) end }),
        BS("color", "bar.gradient.color2", L["Gradient end color"], { noReset = true,
            get = function(info)
                local bar = Cfg(info)
                local g = bar and type(bar.gradient) == "table" and bar.gradient or nil
                return g and type(g.color2) == "table" and g.color2 or nil
            end,
            set = function(info, c)
                local bar = Cfg(info)
                if bar and type(bar.gradient) == "table" and type(c) == "table" then bar.gradient.color2 = c end
            end,
            disabled = function(info) return not On(info) end }),
        Note(L["The fill fades from the bar color to the end color: left to right when horizontal, bottom to top when vertical."]),
    }
end

function Specs.Layout(key)
    local bar = ns.DB.BarTable(key) or {}
    local kind = bar.kind == "bars" and "bars" or "icons"
    local list = { { type = "header", label = L["Layout"], tab = "layout" } }
    local function add(s) list[#list + 1] = s end

    if kind == "icons" then
        add(BS("slider", "layout.maxPerRow", L["Icons per row"], { min = 1, max = 20, step = 1 }))
        for _, row in ipairs(OverflowRows(key)) do add(row) end
    end
    add(BS("slider", "layout.spacing", L["Spacing"], { min = 0, max = 20, step = 1 }))
    local vertical = kind == "bars" and type(bar.bar) == "table" and bar.bar.vertical and true or false
    if kind == "bars" then
        -- 長條的 grow 兩套值互通（Layout.Compute 兩邊都認）：顯示時換成這個方向那一套的值
        add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind, vertical),
            get = function(info)
                local g = ns.DB.GetPath(ns.DB.ConfigTable(info.key), "layout.grow")
                if vertical then
                    local a, b = ns.Layout.VerticalBarGrow(g)
                    return a .. "_" .. b
                end
                local col = ns.Layout.ParseColumn(g)
                if col then return "CENTER_" .. col end
                local _, v = ns.Layout.ParseGrow(g)
                return "CENTER_" .. v
            end }))
    else
        add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind) }))
    end
    if kind == "icons" then
        add(BS("numbers", nil, L["Icon size"], { sub = "layout.size", path = false, resetPaths = { "layout.size" },
            fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        add(BS("toggle", "layout.row2Size", L["Separate size for row 2+"], {
            refreshPage = true,
            get = function() return type(ns.DB.GetPath(ns.DB.BarTable(key), "layout.row2Size")) == "table" end,
            set = function(_, on)
                local b = ns.DB.BarTable(key)
                if not b then return end
                if on then
                    local size = b.layout and b.layout.size or {}
                    b.layout.row2Size = { w = tonumber(size.w) or 36, h = tonumber(size.h) or 36 }
                else
                    b.layout.row2Size = false
                end
            end,
        }))
        if type(bar.layout) == "table" and type(bar.layout.row2Size) == "table" then
            add(BS("numbers", nil, L["Row 2+ size"], { sub = "layout.row2Size", path = false,
                resetPaths = { "layout.row2Size" }, refreshPage = true,
                fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        end
        if bar.source == "custom" then
            -- 可點擊：勾了之後固定格位被強制打開（下一列的原因字），所以排在它前面
            add(BS("toggle", "clickable", L["Clickable"], { level = "layout", refreshPage = true }))
            add(Note(L["Icons cast their spell or use their item when clicked, like action bar buttons. Aura slots are not affected."]))
        end
        if bar.source == "buffs" or bar.source == "custom" then
            add(FixedSlotsRow(key))
        end
    else
        add(BS("slider", "bar.width", L["Width"], { min = 0, max = 600, step = 1 }))
        add(Note(L["0 matches the first row of Essential Cooldowns."]))
        add(BS("slider", "bar.height", L["Height"], { min = 6, max = 60, step = 1 }))
        -- 直向（F8c）：整條轉 90 度；表單要換圖示位置的字與成長方向的選項 ⇒ 重建
        add(BS("toggle", "bar.vertical", L["Vertical"], { refreshPage = true }))
        add(Note(L["The bar stands upright and fills from the bottom; bars line up side by side. Width is the bar's length and height its thickness. Names aren't shown, and the time sits at the top of the bar."]))
        add(BS("dropdown", "bar.iconSide", L["Icon position"], { items = vertical and SIDE_ITEMS_V or SIDE_ITEMS }))
        add(BS("slider", "bar.iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }))
        -- 充能分段（F8b，Modules/Custom.lua）：只對自己加的、有充能的法術；分隔線色沒勾時停用
        add(BS("toggle", "bar.chargeSegments", L["Charge segments"]))
        add(BS("color", "bar.chargeLineColor", L["Divider color"], { hasAlpha = true,
            disabled = function(info) return not ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.chargeSegments") end }))
        add(Note(L["Spells with charges that you added yourself: one segment per charge, and the one recharging fills up."]))
        if bar.source == "buffbars" or bar.source == "custom" then
            add(FixedSlotsRow(key, true))
            -- 空位的樣子：預設隱藏（位置照佔、什麼都不畫，同 EllesmereUI 圖示的 Keep Buffs in Same Place）；
            -- 空長條＝EllesmereUI 長條「未作用時隱藏」關掉時那一條。固定格位沒開（也沒被強制）、
            -- 也沒有任何一招逐法術勾「無增益時保留空位」（F7，同樣照這個樣子畫）時停用
            add(BS("dropdown", "layout.emptyStyle", L["Empty slots"], { items = EMPTY_STYLE_ITEMS, level = "layout",
                get = function() local b = ns.DB.BarTable(key); local l = b and b.layout
                    return type(l) == "table" and l.emptyStyle == "bar" and "bar" or "hide" end,
                disabled = function()
                    local b = ns.DB.BarTable(key)
                    local on = b and type(b.layout) == "table" and b.layout.fixedSlots
                    if on or ns.Catalog.BarHasAuraSlot(key) or ns.DB.BarClickable(key) then return false end
                    return ns.DB.CountOverrides(ns.Catalog.Bar(key), "slot") == 0
                end }))
        end
        add(BS("dropdown", "bar.texture", L["Texture"], { items = TextureItems }))
        add(BS("color", "bar.color", L["Bar color"]))
        add(BS("color", "bar.bgColor", L["Background color"]))
        for _, row in ipairs(GradientRows(key)) do add(row) end
        add(BS("toggle", "bar.spark", L["Show spark"]))
        add(Note(L["A bright marker at the moving end of the bar."]))
        -- 長條上的名字／時間：字型與字級（層數跟著「文字」那一節的層數）
        add(Nested(L["Bar text"]))
        -- 直向不畫名字（上面「垂直」的灰字寫了原因）⇒ 兩列停用
        local function NoName(info) return ns.DB.GetPath(ns.DB.ConfigTable(info.key), "bar.vertical") and true or false end
        local nf = FontBS("bar.nameFont", L["Name font"])
        nf.disabled = NoName
        add(nf)
        add(BS("slider", "bar.nameSize", L["Name size"], { min = 6, max = 30, step = 1, disabled = NoName }))
        add(FontBS("bar.timeFont", L["Time font"]))
        add(BS("slider", "bar.timeSize", L["Time size"], { min = 6, max = 30, step = 1 }))
    end
    return list
end

------------------------------------------------------------
-- 顯示條件
------------------------------------------------------------
function Specs.Visibility()
    return {
        { type = "header", label = L["Visibility"], tab = "visibility" },
        Nested(L["Show when"]),
        BS("toggle", "visibility.showCombat", L["In combat"]),
        BS("toggle", "visibility.showTarget", L["Has a target"]),
        BS("toggle", "visibility.showEnemy", L["Has a hostile target"]),
        Note(L["Leave all unchecked to always show. Check any to show only while one of them is true."]),
        Nested(L["Restrictions"]),
        BS("toggle", "visibility.hideMounted", L["Hide while mounted"]),
        BS("toggle", "visibility.hideSkyriding", L["Hide while skyriding"]),
        Note(L["While on a mount that can skyride, even on the ground."]),
        BS("toggle", "visibility.hideHousing", L["Hide in housing"]),
        Note(L["While inside a house or on a housing plot."]),
        BS("toggle", "visibility.hideResting", L["Hide while resting"]),
        Note(L["While in an inn or a major city."]),
        BS("toggle", "visibility.hideVehicle", L["Hide in vehicle"]),
        Note(L["Only while in a vehicle; riding a mount does not count. \"Hide while mounted\" covers both."]),
        BS("toggle", "visibility.onlyInstances", L["Only in instances"]),
        BS("dropdown", "visibility.group", L["Group"], { items = GROUP_ITEMS }),
        Note(L["Restrictions win over \"Show when\"."]),
    }
end

------------------------------------------------------------
-- 錨定
------------------------------------------------------------
-- 候選：左欄的條（barOrder）＋ 面板（資源條、自訂格子、施法條；它們不在 barOrder 裡）
local function AnchorItems(key)
    local items = { { text = L["None (own position)"], value = "none" } }
    local p = ns.profile
    local cand = {}
    for _, other in ipairs(p and p.barOrder or {}) do cand[#cand + 1] = other end
    for _, other in ipairs(ns.DB.PANEL_ORDER) do cand[#cand + 1] = other end
    for _, other in ipairs(cand) do
        -- 跟著游標的條不能被錨定（Core/Bars.lua 把它當不存在）
        if other ~= key and ns.DB.ConfigTable(other) and not ns.DB.AnchorWouldCycle(key, other)
            and not (ns.Cursor and ns.Cursor.Configured(other)) then
            items[#items + 1] = { text = ns.Options.PageTitle(other) or ns.Options.BarTitle(other), value = other }
        end
    end
    return items
end

local function EdgeOf(a)
    for id, pts in pairs(EDGE_POINTS) do
        if a.point == pts[1] and a.relPoint == pts[2] then return id end
    end
    return "BELOW"
end

-- opts（可省）：
--   other   true ＝ key 不是這張表單自己的條（資源條頁上的自訂格子）：讀寫走 root "bar@<key>"
--   header  小節標題（預設「錨定」）；nested ＝ 畫成小標題
function Specs.Anchor(key, opts)
    opts = opts or {}
    local bar = ns.DB.ConfigTable(key) or {}
    local anchored = type(bar.anchor) == "table"
    local root = opts.other and ("bar@" .. key) or "bar"
    -- 跟著游標開著（而且條件成立）時錨定／位置那幾列停用（值不動，關掉就回來）
    local cursorCapable = not opts.other and bar.kind == "icons" and bar.source == "custom"
    local function CursorOn() return ns.Cursor and ns.Cursor.Configured(key) or false end
    local function AS(kind, path, label, extra)
        local s = BS(kind, path, label, extra)
        s.root = root
        if cursorCapable then s.disabled = CursorOn end
        return s
    end
    local list = {
        -- 分頁：條頁的錨定跟版面同一頁（Specs.SplitTabs）；沒分頁的頁（施法條、資源條…）不看這欄
        { type = "header", label = opts.header or L["Anchoring"], nested = opts.nested or nil,
          tab = not opts.nested and "layout" or nil },
    }
    -- 自訂的圖示群組：跟著游標（勾選＋原因字）、離游標的位移
    if cursorCapable then
        list[#list + 1] = CursorRow(key)
        list[#list + 1] = BS("numbers", nil, L["Offset from the pointer"], { sub = "cursor", path = false,
            resetPaths = { "cursor.x", "cursor.y" }, fallback = 0,
            disabled = function() return not CursorOn() end,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    list[#list + 1] = AS("dropdown", "anchor", L["Follow bar"], {
        items = AnchorItems(key), refreshPage = true, level = "structure",
        get = function()
            local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
            return type(a) == "table" and a.to or "none"
        end,
        set = function(_, v)
            local b = ns.DB.ConfigTable(key)
            if not b then return end
            if v == "none" then
                -- 換成目前畫面上的位置，放開錨定的當下不跳
                local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(key)
                if pos then b.pos = pos end
                b.anchor = false
            else
                local a = type(b.anchor) == "table" and b.anchor
                    or { point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
                a.to = v
                b.anchor = a
            end
        end,
    })
    if anchored then
        list[#list + 1] = AS("dropdown", "anchor.point", L["Side"], {
            items = EDGE_ITEMS, level = "structure", resetPaths = { "anchor.point", "anchor.relPoint" },
            get = function()
                local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
                return type(a) == "table" and EdgeOf(a) or "BELOW"
            end,
            set = function(_, v)
                local a = ns.DB.GetPath(ns.DB.ConfigTable(key), "anchor")
                local pts = EDGE_POINTS[v]
                if type(a) == "table" and pts then a.point, a.relPoint = pts[1], pts[2] end
            end,
        })
        list[#list + 1] = AS("numbers", nil, L["Offset"], { sub = "anchor", path = false, level = "structure",
            resetPaths = { "anchor.x", "anchor.y" }, fallback = 0,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    else
        -- 自己的位置：pos 的偏移（相對畫面上 pos.point 那一點；拖曳／方向鍵改的就是它）
        list[#list + 1] = AS("numbers", nil, L["Position"], { sub = "pos", path = false, level = "structure",
            resetPaths = { "pos" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    list[#list + 1] = Note(L["Hover a bar and press the arrow keys to nudge it by 1 (Shift: 10)."])
    list[#list + 1] = Note(L["A bar that follows another moves with it. Dragging it in Edit Mode stops the following."])
    list[#list + 1] = Note(L["Elements that follow the same side of the same bar stack outward instead of overlapping."])
    return list
end

-- 整張錨定圖（誰錨在誰身上）：錨定下拉的候選要排除成環的，候選清單是建表單當下算的，
-- 別條的錨定一變，這條的候選就過期了 ⇒ 圖本身進表單的形狀簽章
function Specs.AnchorGraphSig()
    local p = ns.profile
    local parts = {}
    local keys = {}
    for k in pairs(p and p.bars or {}) do keys[#keys + 1] = k end
    for _, k in ipairs(ns.DB.PANEL_ORDER) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local t = ns.DB.ConfigTable(k)
        local a = t and t.anchor
        if type(a) == "table" and type(a.to) == "string" then parts[#parts + 1] = k .. ">" .. a.to end
        -- 跟著游標的條不是錨定候選：開關一變，別條的候選清單就過期
        if ns.Cursor and ns.Cursor.Configured(k) then parts[#parts + 1] = k .. "~" end
    end
    return table.concat(parts, ",")
end

-- 表單的「形狀」：有列會出現或消失的設定。形狀一樣就重用建好的表單（frame 刪不掉）
function Specs.BarSignature(key)
    local bar = ns.DB.BarTable(key) or {}
    local layout = type(bar.layout) == "table" and bar.layout or {}
    local p = ns.profile
    return table.concat({
        tostring(bar.kind), tostring(bar.source),
        type(layout.row2Size) == "table" and "r2" or "-",
        type(bar.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        Specs.AnchorGraphSig(),
        Specs.OverflowSig(key),
    }, "|")
end

------------------------------------------------------------
-- 表單：Controls.Build ＋ 跟隨遮罩 ＋ 右鍵重設
------------------------------------------------------------
local RESETTABLE = { toggle = true, slider = true, number = true, numbers = true, color = true, dropdown = true }

local function ResetSpec(ctx, spec)
    local info = ctx.info
    local paths = spec.resetPaths or { PathOf(spec) }
    local p = ns.profile
    if not p then return end
    for _, path in ipairs(paths) do
        if spec.root == "theme" then
            if info.mode == "theme" then
                ns.DB.SetPath(p.theme, path, ns.DB.DefaultFor("theme", nil, path))
            else
                ns.DB.OwnSet(info.key, path, nil)
            end
        else
            local target = TargetOf(spec) or info.key
            local v = ns.DB.DefaultFor("bar", target, path)
            if v == nil then v = spec.fallback end
            ns.DB.SetPath(ns.DB.ConfigTable(target), path, v)
        end
    end
    ctx.lastSpec = spec
    ctx.apply()
    if ctx.form then ctx.form:Refresh() end
end

local function ResetCatcher(content, row, ctx, x0)
    local spec = row.spec
    local f = CreateFrame("Frame", nil, content)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x0, row.top)
    f:SetSize(LABEL_W, math.max(1, row.top - row.bottom))
    f:SetFrameLevel(content:GetFrameLevel() + 5)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then return end
        if W.Menu.IsOpenFor(self) then W.Menu.Hide() return end
        W.Menu.Show({
            { text = spec.label or "", isTitle = true },
            { text = L["Reset to default"], onClick = function() ResetSpec(ctx, spec) end },
        }, self)
    end)
    return f
end

function Specs.BuildForm(parent, controls, ctx, width)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local x0 = 4
    local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, x0, -4, width)
    local form = { content = content, height = height + 20, refreshers = refreshers, rows = rows, masks = {}, ctx = ctx }
    content:SetHeight(form.height)
    ctx.form = form

    -- 子分頁的卡片（L）：底緣＝最後一個帶 subTab 的列（底下接的是小節標題，上方本來就留了 HEADER_GAP，內距吃得下）
    if ctx.tabCard then
        local last
        for _, row in ipairs(rows) do
            if row.spec.subTab then last = row end
        end
        if last then ctx.tabCard:SetBottom(last.bottom - W.TAB_CARD_PAD) else ctx.tabCard:SetBottom(nil) end
    end

    -- 跟隨遮罩的範圍：同一個 section 連續的那一段（中間夾的沒有 section 的列算進去）。
    -- 以前是一節一個矩形（第一列到最後一列）；「文字」節裡夾了一列歸「圖示」管的（增益持續時間的變色顏色，J），
    -- 一節一個矩形的話文字的遮罩會連它一起蓋 ⇒ 改成一段一段。breakMask 的列（子分頁鈕，K）把那一段切斷、自己不蓋
    local runs, run = {}, nil
    for _, row in ipairs(rows) do
        local sec = row.spec.section
        if row.spec.breakMask then
            run = nil
        elseif sec then
            if run and run.sec == sec then
                run.bottom = row.bottom
            else
                run = { sec = sec, top = row.top, bottom = row.bottom }
                runs[#runs + 1] = run
            end
        end
    end
    if ctx.info.mode == "bar" then
        for _, r in ipairs(runs) do
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            m:SetPoint("TOPLEFT", content, "TOPLEFT", 0, r.top)
            m:SetSize(width, math.max(1, r.top - r.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 40)
            m:EnableMouse(true)              -- 擋點擊；滾輪不擋（沒開 MouseWheel，照樣捲得動）
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            m.sec = r.sec
            form.masks[#form.masks + 1] = m
        end
    end
    for _, row in ipairs(rows) do
        if (RESETTABLE[row.spec.type] or row.spec.resettable) and not row.spec.noReset then ResetCatcher(content, row, ctx, x0) end
    end

    -- 停用的列：暗色遮罩蓋整列（層級在右鍵重設的接收框之上、跟隨遮罩之下）
    local gates, watchReload = {}, false
    for _, row in ipairs(rows) do
        local spec = row.spec
        if spec.reloadCheck then watchReload = true end
        if spec.disabled then
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            -- 子分頁卡片裡的列：遮罩左右收在卡片框線內（不然整個表單寬，會凸出卡片兩側）
            local mx, mw = 0, width
            local cx = spec.subTab and ctx.tabCardX
            if cx then mx, mw = cx.left + 1, cx.right - cx.left - 2 end
            m:SetPoint("TOPLEFT", content, "TOPLEFT", mx, row.top)
            m:SetSize(mw, math.max(1, row.top - row.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 30)
            m:EnableMouse(true)
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            -- 整節已經被跟隨遮罩蓋住（條頁）就不再疊一層
            gates[#gates + 1] = function()
                local covered = false
                if ctx.info.mode == "bar" and spec.section then
                    local bar = ns.DB.BarTable(ctx.info.key)
                    local follow = bar and type(bar.follow) == "table" and bar.follow or {}
                    covered = follow[spec.section] ~= false
                end
                m:SetShown((not covered and spec.disabled(ctx.info)) and true or false)
            end
        end
    end
    form.gates = gates
    -- 表單引擎在值變了之後只叫 ctx.apply（不叫 refreshers）⇒ 包一層：停用狀態重判、圖示外觀問重載
    if #gates > 0 or watchReload then
        local apply = ctx.apply
        ctx.apply = function(...)
            apply(...)
            for _, g in ipairs(gates) do g() end
            local last = ctx.lastSpec
            if last and last.reloadCheck then Specs.CheckSkinReload() end
        end
    end

    function form:Refresh()
        for _, fn in ipairs(self.refreshers) do fn() end
        for _, g in ipairs(self.gates) do g() end
        if ctx.info.mode == "bar" then
            local bar = ns.DB.BarTable(ctx.info.key)
            local follow = bar and type(bar.follow) == "table" and bar.follow or {}
            for _, m in ipairs(self.masks) do m:SetShown(follow[m.sec] ~= false) end
        end
    end
    return form
end

------------------------------------------------------------
-- 分頁（主題頁／條頁，J）
--
-- 表單引擎不動：頂層 header 帶一個 tab 欄位（"layout"…），Specs.SplitTabs 把一串 spec 照它切成幾份，
-- 每一份各自 BuildForm 成一張表單，頁面只顯示目前那一張（每張表單一個 ctx：BuildForm 會把 ctx.form
-- 指向自己、包 ctx.apply）。沒帶 tab 的 header（小標題、沒分頁的頁）跟著上一個分頁走；
-- 第一個 header 之前的列歸第一個分頁。分頁鈕跟單一法術小窗同一款（accent-hover ＋ W.CreateButtonGroup），
-- 放不下就換行（W.FlowLayout）。
------------------------------------------------------------
local TAB_DEFS = {
    { id = "layout",     label = L["Layout"] },        -- 版面＋錨定
    { id = "visibility", label = L["Visibility"] },
    { id = "icon",       label = L["Icons"] },
    { id = "text",       label = L["Text"] },
    { id = "glow",       label = L["Effects"] },       -- 效果＋淡出
    { id = "sound",      label = L["Sounds"] },
}
Specs.TAB_DEFS = TAB_DEFS

-- → byTab（id → spec 清單）, ids（有東西的分頁，照 TAB_DEFS 的順序）
function Specs.SplitTabs(controls)
    local byTab, cur = {}, nil
    for _, spec in ipairs(controls) do
        if spec.type == "header" and spec.tab then cur = spec.tab end
        local id = cur or TAB_DEFS[1].id
        local t = byTab[id]
        if not t then t = {}; byTab[id] = t end
        t[#t + 1] = spec
    end
    local ids = {}
    for _, d in ipairs(TAB_DEFS) do
        if byTab[d.id] then ids[#ids + 1] = d.id end
    end
    return byTab, ids
end

-- 分頁鈕列：strip:SetTabs(ids, cur) 只顯示 ids 裡的鈕、高亮 cur、換行排好，回傳高度（也設成 strip 的高）。
-- 點鈕叫 onSelect(id)
local TAB_BTN_H, TAB_BTN_MIN_W = 20, 56
function Specs.CreateTabStrip(parent, width, onSelect)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(width, TAB_BTN_H)
    local btns, byId = {}, {}
    for i, d in ipairs(TAB_DEFS) do
        local b = W.CreateButton(strip, d.label, "accent-hover", TAB_BTN_MIN_W, TAB_BTN_H)
        W.FitButton(b, TAB_BTN_MIN_W, TAB_BTN_H)
        b.id = d.id
        btns[i], byId[d.id] = b, b
    end
    local highlight = W.CreateButtonGroup(btns, function(id) onSelect(id) end)
    function strip:SetTabs(ids, cur)
        local has = {}
        for _, id in ipairs(ids) do has[id] = true end
        local list = {}
        for _, b in ipairs(btns) do
            b:SetShown(has[b.id] == true)
            if has[b.id] then list[#list + 1] = b end
        end
        if byId[cur] then highlight(byId[cur]) end
        local _, h = W.FlowLayout(strip, list, width, 4, 4, TAB_BTN_H)
        strip:SetHeight(h)
        return h
    end
    return strip
end
