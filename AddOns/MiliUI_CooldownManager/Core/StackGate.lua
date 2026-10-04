------------------------------------------------------------
-- 層數門檻：增益「層數到 N 才發光」＋增益長條「層數到 N 換色」
--
--   ns.StackGate.HookItem(item, rec)                 Decorate.HookItem 叫（每框一次）
--   ns.StackGate.Apply(item, rec, barKey, w, h, isBar) Decorate.Apply 叫（設定／尺寸變了照簽章重建）
--   ns.StackGate.Feed(item, rec)                     Bars 放格時叫（Glow.Sync 旁邊）：餵一次目前層數
--   ns.StackGate.OnParked(rec)                       停放／還給暴雪：全收
--   ns.StackGate.Reconceal(item, rec)                無損刷新把條身換回原色之後叫（長條換色才有事）
--
-- 設定（逐法術覆寫，DB.SPELL_CONST 給 false；覆寫分組 "stack"）：
--   stackGlow       門檻 N（1～99）；false／沒設 ＝ 關
--   stackGlowType   發光樣式；沒設 ＝ glow.active 的樣式
--   stackGlowColor  發光顏色；沒設 ＝ glow.active 的顏色
--   stackColors     { { at = N, color = {r,g,b,a} }, … } 最多 5 筆（增益長條才有）；false／沒設 ＝ 關
--   stackBar        { max = N }：條身改畫層數（0～N 的填充），不畫時間（增益長條才有）；false ＝ 關
--   stackTicks      { at = { 1, 5, 8 } | "all", max = N, color = rgba }：條身上第 k 層的位置畫 1px 刻度
--                   （增益長條才有）；N 有 stackBar 時用它的 max、沒有才用這裡的 max；false ＝ 關
-- 只對暴雪的增益 item（增益圖示列、增益長條，搬進自訂群組也算）。自訂光環格（AuraContainer）不做：
-- 引擎的層數條只能 0～上限，做不出「到 N 才開」的閘。
-- 跟生效發光互斥：這格開了層數發光，生效發光不畫（Core/Glow.lua 的 SyncActive 看 rec.stackCfg）。
--
-- ── 原理（秘密層數也成立）─────────────────────────────────────────────
-- 層數在副本戰鬥中是秘密值，Lua 不能比較。跟自訂格子的充能列（Modules/Pips.lua）同一招：
--   閘     一顆自己的透明 StatusBar，SetMinMaxValues(N-1, N)＋SetValue(層數)（秘密值原樣餵）。
--          層數 ≥ N ⇒ 填充貼圖是滿的；< N ⇒ 寬 0。夾值是引擎做的。
--   裁切框 SetClipsChildren(true)，兩點錨在閘的**填充貼圖**上 ⇒ 滿＝跟閘一樣大、空＝寬 0。
--   要「到門檻才出現」的東西當裁切框的子孫，但**錨在格子／條身上**（被裁切，不是被壓扁）。
-- ⚠ 閘餵過秘密值之後幾何是秘密的：除了裁切框以外沒有東西錨在閘的填充貼圖上；
--   閘、裁切框與它們的子孫，我們一律不讀任何值／幾何／alpha。
--
-- 發光：閘比格子大一圈（四邊各外擴 Margin(w, h)：發光會超出圖示，按鈕／觸發樣式是 1.4 倍），
--   宿主在裁切框底下、錨在 overlay 中央、尺寸照排版的 w／h；發光用 MiliUIGlow 的 Start 系列
--   （G.PaintOn）一直畫著，看不看得到由裁切框決定。
--
-- 換色（增益長條）：各段各自一組「閘＋裁切框＋色塊」，照門檻由低到高建、層級由低到高疊 ⇒
--   「高的贏」由繪製順序決定，Lua 不比較。色塊是一張貼圖，材質同條身、SetAllPoints 到**暴雪條的
--   填充貼圖**（只錨不讀）⇒ 只蓋住已填的那一截，條縮短時跟著縮。
--   ⚠ 疊層：暴雪條的名字／時間是條身（frameLevel 511）自己的 OVERLAY 字，任何疊在條上面的框都會
--   蓋住字。所以換色那一層整組放在條身**底下**（item 的子框，層級 = 條身 − 4），並把暴雪條的
--   填充與底色調成全透明（SetVertexColor 的 alpha 0，純 C 端 setter）；底色、原色的填充、各段色塊
--   都由我們畫在條身下面，字照舊在最上面。無損刷新（Glow.ApplyPandemic）把暴雪的填充換成不透明的
--   提醒色 ⇒ 期間整條是提醒色、蓋過層數換色；換回原色時叫 Reconceal 再調回透明。
--   停放／還給暴雪時把暴雪的填充與底色還原。
--
-- 層數當填充（stackBar，增益長條）：原色填充那一層換成一顆自己的 StatusBar（填充條），
--   SetMinMaxValues(0, N)＋SetValue(層數)（秘密值原樣餵，跟閘同一招只是範圍不同），材質／顏色照條的
--   bar.texture／bar.color；時間的那層（錨在暴雪填充貼圖上的原色填充）不畫，暴雪條的火花也調透明
--   （它跟著時間走）。換色各段的色塊改錨在**填充條的填充貼圖**上（只錨不讀）⇒ 蓋住的是層數那一截。
--   名字／時間字照舊是暴雪條身的字，在最上面。
-- 層數刻度（stackTicks，增益長條）：一顆刻度框（條身底下、在各段色塊上面），N-1 條（或指定的幾條）
--   1px 直線，x ＝ 條身寬 × k/N。條身寬是**我們排版給的**（格寬 − 圖示 − 間距，SG.BodyWidth），
--   不讀暴雪的；線錨在暴雪條身的左緣（那是我們 ApplyBarGeometry 錨的明文幾何）。貼圖池化。
-- 三者（換色／層數當填充／刻度）任一成立 ⇒ 暴雪的填充與底色調透明、底色由我們畫。
-- 疊法（由下往上，全在條身底下）：根框（底色、原色填充）→ 填充條 → 各段色塊 → 刻度框 → 暴雪條身。
--
-- ── 層數從哪來（2026-10-03 對過 Gethe/wow-ui-source live 分支 12.1.0 (69933) 的
--    Blizzard_CooldownViewer/CooldownViewer.lua、CooldownViewerItemData.lua）──────────────
--   * CooldownViewerBuffIconItemMixin:RefreshApplications 與 CooldownViewerBuffBarItemMixin:RefreshApplications
--     都存在；兩者的 RefreshData 都是 RefreshAuraInstance → … → RefreshApplications → RefreshIconBorder →
--     RefreshActive。RefreshData 由檢視器的 UNIT_AURA（OnUnitAuraUpdatedEvent／Added／Removed）、換目標、
--     冷卻刷新等叫 ⇒ 後掛勾 RefreshApplications 跑到時，光環快取已經是這一次的。
--     ⚠ 那一刻 RefreshActive 還沒跑：IsActive() 是上一次的值 ⇒ 這條路只看光環資料，不看 IsActive；
--     生效狀態的變化另外掛 OnActiveStateChanged（暴雪 SetIsActive 狀態變了才叫）。
--   * CooldownViewerItemDataMixin:GetAuraDataCached() 只是 `return self.auraDataCached`（沒有運算）；
--     快取由 GetAuraData（C_UnitAuras.GetUnitAuras 的那一筆）或 SetAuraInstanceInfo 寫。
--     暴雪自己的 GetApplicationsText 做 `auraData.applications > 1`——那是安全端，污染端照抄會炸，
--     所以我們只把 applications 原樣轉手，表的取值也包 pcall。
--   * 光環實例的欄位名是 auraInstanceID（getter GetAuraSpellInstanceID）；GetAuraDataUnit() 回
--     auraDataUnit（"player"／"target"／nil）。退路：auraInstanceID 是明文數字時
--     C_UnitAuras.GetAuraDataByAuraInstanceID(unit, iid)。
--   * 暴雪把 1 層顯示成空字串（> 1 才寫字）；資料裡沒有疊層的增益是 0 還是 1 沒查證 ⇒ 門檻 1 的行為待實機驗證。
-- 讀法：拿不到資料（光環不在）⇒ 0；applications 是明文 nil ⇒ 0；秘密值 ⇒ 原樣餵。
-- 「是不是 nil」一律先 ns.IsSecret 再比。
--
-- 效能：兩個後掛勾的第一行就是 rec.stackCfg 檢查（沒有任何層數設定的格立刻 return）；
-- 框刪不掉：閘／裁切框／色塊建在 rec 上池化、照簽章重用，用不到的藏起來。
------------------------------------------------------------
local _, ns = ...

ns.StackGate = {}
local SG = ns.StackGate

SG.MAX_COLORS = 5
SG.MAX_STACK  = 99
SG.DEFAULT_THRESHOLD = 3
SG.DEFAULT_BAR_MAX = 5         -- 層數當填充／刻度沒給最大層數時
SG.TICK_COLOR = { r = 0, g = 0, b = 0, a = 0.6 }

local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local BAR_LEVEL = 511          -- 暴雪增益長條的條身（CooldownViewer.xml：frameLevel="511"），讀不到時用

-- debug
SG.hooked  = 0                 -- 掛了 RefreshApplications 的 item 數
SG.feeds   = 0                 -- 餵過幾次
SG.last    = nil               -- 最近一次餵的是什麼："plain" | "secret" | "none" | "inactive"

-- rec → item（停放時只拿得到 rec，要還原暴雪條）
local itemOf = setmetatable({}, { __mode = "kv" })

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

------------------------------------------------------------
-- 純函式（Tests/StackGate_test.lua）
------------------------------------------------------------
-- 閘的 min／max：SetValue(層數) 之後層數 ≥ n 是滿的、≤ n-1 是空的
function SG.GateRange(n) return n - 1, n end

-- 發光閘四邊外擴量（水平、垂直）：至少 12，或那一邊長的 0.4（按鈕／觸發樣式畫成 1.4 倍，每邊多 0.2）
function SG.Margin(w, h)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    return math.max(12, w * 0.4), math.max(12, h * 0.4)
end

-- 門檻：1～99 的整數；false／nil／壞值 ＝ 關（nil）
function SG.Threshold(v)
    if type(v) ~= "number" or v ~= v then return nil end
    v = math.floor(v)
    if v < 1 then return nil end
    if v > SG.MAX_STACK then v = SG.MAX_STACK end
    return v
end

local function CleanColor(c)
    if type(c) ~= "table" then return nil end
    local r, g, b, a = c.r, c.g, c.b, c.a
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if type(a) ~= "number" then a = 1 end
    return { r = r, g = g, b = b, a = a }
end

-- stackColors 清洗：丟掉壞資料、門檻由低到高排、同門檻留第一筆、最多 MAX_COLORS（5）筆；一筆都沒有回 nil
function SG.CleanColors(list)
    if type(list) ~= "table" then return nil end
    local tmp, seen = {}, {}
    for i, e in ipairs(list) do
        local at = type(e) == "table" and SG.Threshold(e.at) or nil
        local c = at and CleanColor(e.color)
        if at and c and not seen[at] then
            seen[at] = true
            tmp[#tmp + 1] = { at = at, color = c, i = i }
        end
    end
    table.sort(tmp, function(a, b) return a.at < b.at end)
    local out = {}
    for i = 1, math.min(#tmp, SG.MAX_COLORS) do
        out[i] = { at = tmp[i].at, color = tmp[i].color }
    end
    if out[1] == nil then return nil end
    return out
end

-- stackBar 清洗：{ max = N } 的 N（1～99）；false／壞資料 ＝ 關（nil）
function SG.BarMax(v)
    if type(v) ~= "table" then return nil end
    return SG.Threshold(v.max)
end

-- 刻度位置清單清洗：1～99 的整數、去重、由小到大；一個都沒有回 nil
local function CleanAtList(list)
    if type(list) ~= "table" then return nil end
    local seen, out = {}, {}
    for _, v in ipairs(list) do
        local k = SG.Threshold(v)
        if k and not seen[k] then
            seen[k] = true
            out[#out + 1] = k
        end
    end
    table.sort(out)
    if out[1] == nil then return nil end
    return out
end

-- stackTicks 清洗：{ at = "all"|{…}, n = N, color = rgba }；barN ＝ 層數當填充的 N（有就用它）。
-- at 不是清單（或清單一個能用的都沒有）＝ "all"；N 少於 2 畫不出任何刻度 ⇒ nil
function SG.CleanTicks(v, barN)
    if type(v) ~= "table" then return nil end
    local n = barN or SG.Threshold(v.max) or SG.DEFAULT_BAR_MAX
    if n < 2 then return nil end
    local at = v.at ~= "all" and CleanAtList(v.at) or "all"
    return { at = at, n = n, color = CleanColor(v.color) or CleanColor(SG.TICK_COLOR) }
end

-- 要畫的刻度（層數 k）：只畫 1～N-1（第 N 層就是條的右緣）
function SG.TickPositions(n, at)
    n = tonumber(n) or 0
    local out = {}
    if n < 2 then return out end
    if at == "all" or type(at) ~= "table" then
        for k = 1, n - 1 do out[#out + 1] = k end
        return out
    end
    for _, k in ipairs(at) do
        if type(k) == "number" and k >= 1 and k < n then out[#out + 1] = k end
    end
    return out
end

-- 第 k 條刻度離條身左緣多遠：條身寬 × k/N（像素對齊在畫的時候做）
function SG.TickX(bodyW, n, k)
    bodyW, n = tonumber(bodyW) or 0, tonumber(n) or 0
    if n <= 0 then return 0 end
    return bodyW * k / n
end

-- 條身寬：格寬扣掉圖示（正方形，邊長 ＝ 格高）與間距；圖示「無」時整格都是條身
-- （跟 Decorate.ApplyBarGeometry 的錨法對應；不讀暴雪的框）
function SG.BodyWidth(w, h, side, gap)
    w, h, gap = tonumber(w) or 0, tonumber(h) or 0, tonumber(gap) or 0
    if side == "NONE" then return math.max(0, w) end
    return math.max(0, w - h - gap)
end

-- 刻度輸入框的字 → 存檔的 at：留白或「all」＝ "all"；否則逗號／空白分隔的整數，
-- 只收 1～max-1（第 max 層是右緣），去重、排序。一個能用的都沒有回 nil（呼叫端不收、還原）
function SG.ParseTicks(text, max)
    if text == nil then return "all" end
    if type(text) ~= "string" then return nil end
    local t = text:gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" or t:lower() == "all" then return "all" end
    max = tonumber(max) or SG.MAX_STACK + 1
    local list = {}
    for tok in t:gmatch("[^,，%s]+") do
        local v = tonumber(tok)
        if v and v == math.floor(v) and v >= 1 and v < max then list[#list + 1] = v end
    end
    return CleanAtList(list)
end

-- 存檔的 at → 輸入框的字（"all" ＝ 留白）
function SG.TicksText(at)
    if type(at) ~= "table" then return "" end
    local parts = {}
    for i, k in ipairs(at) do parts[i] = tostring(k) end
    return table.concat(parts, ",")
end

local function CSig(c)
    if type(c) ~= "table" then return tostring(c) end
    return string.format("%.3f,%.3f,%.3f,%.3f", c.r or 0, c.g or 0, c.b or 0, c.a or 1)
end

-- 層數發光的樣式：glow.active（生效發光的預設樣式）＋逐法術的 stackGlowType／stackGlowColor
function SG.GlowStyle(barKey, id)
    local base = ns.Setting(barKey, "glow.active")
    local t = {}
    if type(base) == "table" then for k, v in pairs(base) do t[k] = v end end
    local typ = ns.SpellSetting(barKey, id, "stackGlowType")
    local col = ns.SpellSetting(barKey, id, "stackGlowColor")
    if type(typ) == "string" then t.type = typ end
    if type(col) == "table" then t.color = col end
    return t
end

-- 這一格的層數設定（快取在 rec.stackCfg）；沒有任何層數設定回 nil。
--   aura：暴雪的增益 item（不是自訂項目）；isBar：增益長條（才有換色）
--   回傳 { glow, style, colors, stackBar = N, ticks = { at, n, color } }
function SG.Config(barKey, id, aura, isBar)
    if not aura or type(id) ~= "number" then return nil end
    local n = SG.Threshold(ns.SpellSetting(barKey, id, "stackGlow"))
    local colors, barN, ticks
    if isBar then
        colors = SG.CleanColors(ns.SpellSetting(barKey, id, "stackColors"))
        barN = SG.BarMax(ns.SpellSetting(barKey, id, "stackBar"))
        ticks = SG.CleanTicks(ns.SpellSetting(barKey, id, "stackTicks"), barN)
    end
    if not n and not colors and not barN and not ticks then return nil end
    return { glow = n, style = n and SG.GlowStyle(barKey, id) or nil, colors = colors,
        stackBar = barN, ticks = ticks }
end

-- 條身底下那一層（換色／層數當填充／刻度）要不要建
function SG.HasLayers(cfg)
    return cfg ~= nil and (cfg.colors ~= nil or cfg.stackBar ~= nil or cfg.ticks ~= nil)
end

-- 簽章：門檻、發光樣式、各段門檻與顏色、層數當填充的 N、刻度、格子尺寸、
-- 條身材質／顏色／底色、圖示邊與間距（條身寬）、火花（條身底下那一層自己畫）
function SG.Signature(cfg, w, h, bar)
    if not cfg then return nil end
    local parts = { tostring(cfg.glow), tostring(w), tostring(h) }
    local s = cfg.style
    if s then
        parts[#parts + 1] = table.concat({ tostring(s.type), tostring(s.lines), tostring(s.thickness),
            tostring(s.frequency), CSig(s.color) }, ",")
    end
    if cfg.colors then
        for _, e in ipairs(cfg.colors) do parts[#parts + 1] = tostring(e.at) .. "=" .. CSig(e.color) end
    end
    if cfg.stackBar then parts[#parts + 1] = "bar=" .. tostring(cfg.stackBar) end
    local t = cfg.ticks
    if t then
        local at = type(t.at) == "table" and table.concat(t.at, ",") or tostring(t.at)
        parts[#parts + 1] = "ticks=" .. at .. "/" .. tostring(t.n) .. "/" .. CSig(t.color)
    end
    if SG.HasLayers(cfg) then
        bar = type(bar) == "table" and bar or {}
        parts[#parts + 1] = tostring(bar.texture) .. "/" .. CSig(bar.color) .. "/" .. CSig(bar.bgColor)
            .. "/" .. tostring(bar.iconSide) .. "/" .. tostring(bar.iconGap) .. "/" .. tostring(bar.spark)
    end
    return table.concat(parts, "|")
end

------------------------------------------------------------
-- 讀層數（全 pcall，不比較、不算術）
------------------------------------------------------------
local function GetApps(t) return t.applications end

-- 回傳 (要餵的值, 種類)；值可能是秘密值。表的真假用 type() 判斷（不碰值）。
-- 取值拋錯回 (nil, nil)：呼叫端只看種類，**不准拿值跟 nil 比**
local function FromAuraTable(data)
    local ok, a = pcall(GetApps, data)
    if not ok then return nil end
    if ns.IsSecret(a) then return a, "secret" end
    if type(a) == "number" then return a, "plain" end
    return 0, "none"                 -- 明文 nil／怪東西
end

local function ReadStacks(item)
    -- 1. 暴雪自己的 getter（只 return 欄位）
    local fn = item.GetAuraDataCached
    if type(fn) == "function" then
        local ok, data = pcall(fn, item)
        if ok then
            if type(data) ~= "table" then return 0, "none" end      -- 光環不在
            local v, kind = FromAuraTable(data)
            if kind then return v, kind end      -- ⚠ 不能拿 v 比 nil：可能是秘密值
        end
    end
    -- 2. 退路：明文的光環實例 ID 自己問
    local iid = Plain(rawget(item, "auraInstanceID"))
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if type(iid) == "number" and get then
        local unit
        local uf = item.GetAuraDataUnit
        if type(uf) == "function" then
            local ok, u = pcall(uf, item)
            if ok then unit = Plain(u) end
        end
        if type(unit) ~= "string" then unit = "player" end
        local ok, data = pcall(get, unit, iid)
        if ok and type(data) == "table" then
            local v, kind = FromAuraTable(data)
            if kind then return v, kind end      -- ⚠ 不能拿 v 比 nil：可能是秘密值
        end
    end
    return 0, "none"
end
SG.ReadStacks = ReadStacks

-- 暴雪的生效狀態：明文 false 才算「沒生效」；秘密／讀不到 ＝ 不知道
local function PlainInactive(item)
    local fn = item.IsActive
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, item)
    if not ok then return false end
    return Plain(v) == false
end

------------------------------------------------------------
-- 框（全是我們自己的；建在 rec 上池化）
------------------------------------------------------------
local function NewGate(parent)
    local gate = CreateFrame("StatusBar", nil, parent)
    gate:SetStatusBarTexture(SOLID)
    local fill = gate:GetStatusBarTexture()
    if fill then fill:SetVertexColor(0, 0, 0, 0) end
    gate:SetMinMaxValues(0, 1)
    gate:SetValue(0)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetClipsChildren(true)
    -- ⚠ 只有裁切框錨在閘的填充貼圖上（見檔頭）
    if fill then
        clip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    end
    return { gate = gate, clip = clip }
end

local function UI(rec)
    local ui = rec.stackUI
    if not ui then
        ui = { colors = {} }
        rec.stackUI = ui
    end
    return ui
end

local function StopGlow(rec)
    local ui = rec.stackUI
    local t = rec.stackGlowOn
    if not (ui and ui.glow and t) then return end
    rec.stackGlowOn = nil
    if ns.Glow and ns.Glow.StopOn then ns.Glow.StopOn(ui.glow.host, t, "stack") end
end

local function PaintGlow(rec)
    local cfg, ui = rec.stackCfg, rec.stackUI
    if not (cfg and cfg.glow and ui and ui.glow) or rec.stackGlowOn then return end
    if not (ns.Glow and ns.Glow.PaintOn) then return end
    rec.stackGlowOn = ns.Glow.PaintOn(ui.glow.host, cfg.style or {}, "active", "stack", false)
end

-- 暴雪條的填充與底色：換色那一層在條身底下，暴雪的要調成全透明（只動 alpha，色照設定）
local function BlizzBar(item)
    local b = item and item.Bar
    if not (b and b.GetStatusBarTexture) then return nil end
    local ok, fill = pcall(b.GetStatusBarTexture, b)
    if not ok then fill = nil end
    return b, fill
end

local function C4(c, dr, dg, db, da)
    if type(c) ~= "table" then return dr, dg, db, da end
    return c.r or dr, c.g or dg, c.b or db, c.a or da
end

local function Conceal(item, rec)
    local ui = rec.stackUI
    local bar = ui and ui.barStyle
    if not (ui and ui.under and bar) then return end
    local b, fill = BlizzBar(item)
    if not b then return end
    local r, g, bl = C4(bar.color, 0.4, 0.6, 0.9, 1)
    if fill then fill:SetVertexColor(r, g, bl, 0) end
    local bg = b.BarBG
    if bg then
        local br, bgg, bb = C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
        bg:SetVertexColor(br, bgg, bb, 0)
    end
    -- 層數當填充：暴雪的火花跟著時間走，跟層數那條對不上 ⇒ 一起調透明（同 ApplyBarLook 的 alpha 寫法）
    if bar.stackBar and b.Pip then b.Pip:SetAlpha(0) end
    ui.concealed = true
end

local function Restore(item, rec)
    local ui = rec.stackUI
    if not (ui and ui.concealed) then return end
    ui.concealed = false
    local bar = ui.barStyle or {}
    local b, fill = BlizzBar(item)
    if not b then return end
    if fill then fill:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1)) end
    if b.BarBG then b.BarBG:SetVertexColor(C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8)) end
    if bar.stackBar and b.Pip then b.Pip:SetAlpha(bar.spark and 1 or 0) end
end

local function HideAll(rec)
    local ui = rec.stackUI
    if not ui then return end
    if ui.glow then
        ui.glow.gate:Hide()
        ui.glow.clip:Hide()
    end
    if ui.under then ui.under:Hide() end
end

-- 發光那一組：閘（比格子大一圈）→ 裁切框 → 宿主（錨在 overlay 中央、排版給的尺寸）
local function BuildGlow(rec, cfg, w, h)
    local ui = UI(rec)
    local ov = rec.overlay
    if not cfg.glow or not ov then
        if ui.glow then
            StopGlow(rec)
            ui.glow.gate:Hide()
            ui.glow.clip:Hide()
        end
        return
    end
    local gs = ui.glow
    if not gs then
        gs = NewGate(ov)
        gs.host = CreateFrame("Frame", nil, gs.clip)
        ui.glow = gs
    end
    StopGlow(rec)                    -- 樣式／尺寸可能變了：重畫
    local mx, my = SG.Margin(w, h)
    gs.gate:ClearAllPoints()
    gs.gate:SetPoint("TOPLEFT", ov, "TOPLEFT", -mx, my)
    gs.gate:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", mx, -my)
    gs.gate:SetMinMaxValues(SG.GateRange(cfg.glow))
    local lv = (ov:GetFrameLevel() or 1) + 1      -- 跟生效發光的宿主同一層（兩者互斥）
    gs.gate:SetFrameLevel(lv)
    gs.clip:SetFrameLevel(lv)
    gs.host:ClearAllPoints()
    gs.host:SetPoint("CENTER", ov, "CENTER", 0, 0)
    gs.host:SetSize(tonumber(w) or 36, tonumber(h) or 36)
    gs.host:SetFrameLevel(lv + 1)
    gs.gate:Show()
    gs.clip:Show()
    gs.host:Show()
end

------------------------------------------------------------
-- 刻度（真實條與設定頁預覽共用）：host 是自己的框（貼圖池 host.tickLines），線錨在 anchor
-- （條身）左緣往右 x；x 與線寬像素對齊。ticks ＝ CleanTicks 的結果；nil 全藏
------------------------------------------------------------
function SG.DrawTicks(host, anchor, bodyW, ticks)
    if not host then return end
    local pool = host.tickLines
    if not pool then
        pool = {}
        host.tickLines = pool
    end
    local ks = ticks and anchor and SG.TickPositions(ticks.n, ticks.at) or {}
    local snap = ns.Layout and ns.Layout.Snap or function(v) return v end
    local px = (ns.Media and ns.Media.BorderInset) and ns.Media.BorderInset(1) or 1
    local r, g, b, a = C4(ticks and ticks.color, 0, 0, 0, 0.6)
    for i, k in ipairs(ks) do
        local line = pool[i]
        if not line then
            line = host:CreateTexture(nil, host.tickLayer or "OVERLAY", nil, host.tickSub)
            line:SetTexture(SOLID)
            pool[i] = line
        end
        local x = snap(SG.TickX(bodyW, ticks.n, k))
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", x, 0)
        line:SetWidth(px)
        line:SetVertexColor(r, g, b, a)
        line:Show()
    end
    for i = #ks + 1, #pool do pool[i]:Hide() end
end

-- 條身底下那一層（增益長條）：根框（item 的子框；底色＋原色填充）→ 填充條（層數當填充）→
-- 各段閘／裁切框／色塊（換色）→ 刻度框。換色／層數當填充／刻度任一成立才建（見檔頭）
local function BuildLayers(item, rec, cfg, bar, w, h)
    local ui = UI(rec)
    local b, fill = BlizzBar(item)
    if not SG.HasLayers(cfg) or not (b and fill) then
        if ui.under then ui.under:Hide() end
        Restore(item, rec)
        ui.barStyle = nil
        return
    end
    local root = ui.under
    if not root then
        root = CreateFrame("Frame", nil, item)
        root.bg = root:CreateTexture(nil, "BACKGROUND")
        root.base = root:CreateTexture(nil, "ARTWORK")
        ui.under = root
    end
    root:ClearAllPoints()
    root:SetAllPoints(item)
    local okLv, bl = pcall(b.GetFrameLevel, b)
    bl = okLv and Plain(bl) or nil
    if type(bl) ~= "number" then bl = BAR_LEVEL end
    -- 層級：根框 lv、填充條 lv+1、第 k 段 lv+1+k、刻度 lv+2+MAX_COLORS（＝ 條身 − 1）
    local lv = math.max(1, bl - (SG.MAX_COLORS + 3))
    root:SetFrameLevel(lv)
    local tex = ns.Media.Texture(bar.texture)
    -- 底色：照條的底色（暴雪的 BarBG 調成透明）
    root.bg:ClearAllPoints()
    root.bg:SetAllPoints(b)
    root.bg:SetTexture(SOLID)
    root.bg:SetVertexColor(C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8))
    -- 色塊錨在哪一張填充貼圖：層數當填充＝我們的填充條、否則＝暴雪的（時間）。兩者都只錨不讀
    local segAnchor = fill
    if cfg.stackBar then
        -- 層數當填充：自己的 StatusBar（0～N，SetValue 秘密原樣餵），時間那層不畫
        local fb = ui.fillBar
        if not fb then
            fb = CreateFrame("StatusBar", nil, root)
            fb:SetStatusBarTexture(SOLID)
            ui.fillBar = fb
        end
        fb:ClearAllPoints()
        fb:SetAllPoints(b)
        fb:SetFrameLevel(lv + 1)
        fb:SetStatusBarTexture(tex)
        local ft = fb:GetStatusBarTexture()
        if ft then ft:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1)) end
        fb:SetMinMaxValues(0, cfg.stackBar)
        fb:Show()
        root.base:Hide()
        segAnchor = ft or fill
    else
        if ui.fillBar then ui.fillBar:Hide() end
        -- 原色填充：錨在暴雪的填充貼圖上（只錨不讀）
        root.base:ClearAllPoints()
        root.base:SetAllPoints(fill)
        root.base:SetTexture(tex)
        root.base:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1))
        root.base:Show()
    end
    local colors = cfg.colors or {}
    for k, e in ipairs(colors) do
        local seg = ui.colors[k]
        if not seg then
            seg = NewGate(root)
            seg.tex = seg.clip:CreateTexture(nil, "ARTWORK")
            ui.colors[k] = seg
        end
        seg.gate:ClearAllPoints()
        seg.gate:SetAllPoints(root)
        seg.gate:SetMinMaxValues(SG.GateRange(e.at))
        -- 門檻由低到高、層級由低到高：高的蓋住低的
        seg.gate:SetFrameLevel(lv + 1 + k)
        seg.clip:SetFrameLevel(lv + 1 + k)
        seg.tex:ClearAllPoints()
        seg.tex:SetAllPoints(segAnchor)
        seg.tex:SetTexture(tex)
        seg.tex:SetVertexColor(C4(e.color, 1, 1, 1, 1))
        seg.gate:Show()
        seg.clip:Show()
    end
    for k = #colors + 1, #ui.colors do
        ui.colors[k].gate:Hide()
        ui.colors[k].clip:Hide()
    end
    -- 刻度：自己的框、在各段色塊上面、條身底下；條身寬照排版算（不讀暴雪）
    if cfg.ticks then
        local tf = ui.ticks
        if not tf then
            tf = CreateFrame("Frame", nil, root)
            ui.ticks = tf
        end
        tf:ClearAllPoints()
        tf:SetAllPoints(root)
        tf:SetFrameLevel(lv + 2 + SG.MAX_COLORS)
        SG.DrawTicks(tf, b, SG.BodyWidth(w, h, bar.iconSide or "LEFT", bar.iconGap or 0), cfg.ticks)
        tf:Show()
    elseif ui.ticks then
        ui.ticks:Hide()
    end
    ui.barStyle = { color = bar.color, bgColor = bar.bgColor, spark = bar.spark,
        stackBar = cfg.stackBar ~= nil }
    root:Show()
    Conceal(item, rec)
end

-- 全部收掉（這格不再有層數設定）
local function Release(item, rec)
    StopGlow(rec)
    HideAll(rec)
    Restore(item, rec)
    rec.stackCfg, rec.stackSig, rec.stackOff = nil, nil, nil
end

------------------------------------------------------------
-- 餵值
------------------------------------------------------------
local function SetAll(rec, v)
    local ui = rec.stackUI
    if not ui then return end
    if ui.glow and rec.stackCfg.glow then pcall(ui.glow.gate.SetValue, ui.glow.gate, v) end
    local colors = rec.stackCfg.colors
    if colors and ui.under then
        for k = 1, #colors do
            local seg = ui.colors[k]
            if seg then pcall(seg.gate.SetValue, seg.gate, v) end
        end
    end
    if rec.stackCfg.stackBar and ui.fillBar then pcall(ui.fillBar.SetValue, ui.fillBar, v) end
end

-- checkActive：暴雪的生效狀態已經是這一次的（放格、OnActiveStateChanged）時才看；
-- RefreshApplications 那一刻 RefreshActive 還沒跑，只看光環資料
local function FeedNow(item, rec, checkActive)
    local v, kind
    if checkActive and PlainInactive(item) then
        v, kind = 0, "inactive"
    else
        v, kind = ReadStacks(item)
    end
    SetAll(rec, v)
    SG.feeds = SG.feeds + 1
    SG.last = kind
end

-- 停放之後重新放格：框亮回來、暴雪條調回透明、發光重畫
local function Unpark(item, rec)
    if not rec.stackOff then return end
    rec.stackOff = false
    local ui = rec.stackUI
    if not ui then return end
    local cfg = rec.stackCfg
    if ui.glow and cfg.glow then
        ui.glow.gate:Show()
        ui.glow.clip:Show()
    end
    if ui.under and SG.HasLayers(cfg) then
        ui.under:Show()
        Conceal(item, rec)
    end
end

function SG.Feed(item, rec)
    if not (rec and rec.stackCfg) or ns.released then return end
    if rec.stackID ~= rec.cooldownID then return end        -- 換了身分、還沒重套
    Unpark(item, rec)
    PaintGlow(rec)
    FeedNow(item, rec, true)
end

------------------------------------------------------------
-- 後掛勾（第一行：沒有層數設定的格立刻走）
------------------------------------------------------------
local function OnRefreshApplications(item)
    local rec = ns.Viewers.frames[item]
    if not (rec and rec.stackCfg) then return end
    if rec.stackOff or ns.released or rec.stackID ~= rec.cooldownID then return end
    FeedNow(item, rec, false)
end

local function OnActiveStateChanged(item)
    local rec = ns.Viewers.frames[item]
    if not (rec and rec.stackCfg) then return end
    if rec.stackOff or ns.released or rec.stackID ~= rec.cooldownID then return end
    FeedNow(item, rec, true)
end

function SG.HookItem(item, rec)
    if rec.stackHooked or rec.custom then return end
    rec.stackHooked = true
    if not (ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey]) then return end
    if type(item.RefreshApplications) == "function" then
        hooksecurefunc(item, "RefreshApplications", ns.Guard(OnRefreshApplications))
        SG.hooked = SG.hooked + 1
    end
    if type(item.OnActiveStateChanged) == "function" then
        hooksecurefunc(item, "OnActiveStateChanged", ns.Guard(OnActiveStateChanged))
    end
end

------------------------------------------------------------
-- 套用（Decorate.Apply 叫；長條在 ApplyBarLook 之後，暴雪的填充貼圖才有材質）
------------------------------------------------------------
function SG.Apply(item, rec, barKey, w, h, isBar)
    if not (item and rec) then return end
    local aura = not rec.custom and ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey] or false
    local cfg = (not ns.released) and SG.Config(barKey, rec.cooldownID, aura, isBar) or nil
    if not cfg then
        if rec.stackCfg or rec.stackUI then Release(item, rec) end
        return
    end
    local bar = ns.Setting(barKey, "bar")
    bar = type(bar) == "table" and bar or {}
    local sig = SG.Signature(cfg, w, h, bar)
    rec.stackCfg, rec.stackID = cfg, rec.cooldownID
    itemOf[rec] = item
    if rec.stackSig == sig and not rec.stackOff then
        -- 樣式重套過（ApplyBarLook 把暴雪條的填充／底色寫回不透明）：調回透明
        if SG.HasLayers(cfg) then Conceal(item, rec) end
        return
    end
    BuildGlow(rec, cfg, w, h)
    BuildLayers(item, rec, cfg, bar, w, h)
    rec.stackSig = sig
    rec.stackOff = false
    PaintGlow(rec)
    FeedNow(item, rec, true)
end

-- 無損刷新把條身換回原色（Glow.ApplyPandemic）之後：條身底下那一層開著就把暴雪的調回透明
function SG.Reconceal(item, rec)
    if not (rec and SG.HasLayers(rec.stackCfg)) or rec.stackOff then return end
    Conceal(item, rec)
end

-- 停放（alpha 0、畫面外）與還給暴雪：發光停、框藏、暴雪條還原；重新放格時 Feed 接回來
function SG.OnParked(rec)
    if not (rec and rec.stackUI) then return end
    StopGlow(rec)
    HideAll(rec)
    local item = itemOf[rec]
    if item then Restore(item, rec) end
    if rec.stackCfg then rec.stackOff = true end
end

------------------------------------------------------------
-- 設定頁預覽的假長條（Options/Preview.lua 的 Fill 叫；假條是我們自己的框，直接畫在它上面）：
--   層數當填充 ⇒ cell.stackPreviewMax ＝ N（Tick 把條畫成 2/N，不跑時間）；刻度照真實條的算法畫。
-- 層數換色在預覽上不畫（跟原本一樣，見 README 已知限制）。格子是池化的：每次都把兩樣蓋掉
------------------------------------------------------------
function SG.ApplyPreview(cell, barKey, id, w, h)
    if not (cell and cell.Bar) then return end
    local aura = cell.aura and not cell.custom
    local cfg = (not ns.released) and SG.Config(barKey, id, aura, true) or nil
    cell.stackPreviewMax = cfg and cfg.stackBar or nil
    local bar = ns.Setting(barKey, "bar")
    bar = type(bar) == "table" and bar or {}
    local host = cell.Bar
    host.tickLayer, host.tickSub = "ARTWORK", 7          -- 在填充上面、名字／時間字底下
    SG.DrawTicks(host, host, SG.BodyWidth(w, h, bar.iconSide or "LEFT", bar.iconGap or 0), cfg and cfg.ticks)
end

-- 預覽條的值（0～1）：層數當填充畫 2 層（N 小於 2 就是滿的）
function SG.PreviewFill(n)
    n = tonumber(n) or 0
    if n <= 0 then return 0 end
    return math.min(2, n) / n
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function SG.Counts()
    local glow, colors, lit, bars, ticks = 0, 0, 0, 0, 0
    for _, rec in pairs(ns.Viewers.frames) do
        local cfg = rec.stackCfg
        if cfg then
            if cfg.glow then glow = glow + 1 end
            if cfg.colors then colors = colors + 1 end
            if cfg.stackBar then bars = bars + 1 end
            if cfg.ticks then ticks = ticks + 1 end
            if rec.stackGlowOn then lit = lit + 1 end
        end
    end
    return glow, colors, lit, bars, ticks
end

local LAST_TEXT = { plain = "明文", secret = "秘密", none = "沒有光環資料（0）", inactive = "沒生效（0）" }

function SG.DebugLine()
    local glow, colors, lit, bars, ticks = SG.Counts()
    return ("  層數門檻：發光 %d 格（宿主在畫 %d）  換色 %d 格  層數當填充 %d 格  刻度 %d 格  掛了 RefreshApplications %d 格  餵了 %d 次  最近一次 %s")
        :format(glow, lit, colors, bars, ticks, SG.hooked, SG.feeds, SG.last and (LAST_TEXT[SG.last] or SG.last) or "—")
end
