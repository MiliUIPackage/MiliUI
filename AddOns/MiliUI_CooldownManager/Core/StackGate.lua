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
--   stackColors     { { at = N, color = {r,g,b,a} }, … } 最多 3 筆（增益長條才有）；false／沒設 ＝ 關
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

SG.MAX_COLORS = 3
SG.MAX_STACK  = 99
SG.DEFAULT_THRESHOLD = 3

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

-- stackColors 清洗：丟掉壞資料、門檻由低到高排、同門檻留第一筆、最多 3 筆；一筆都沒有回 nil
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
function SG.Config(barKey, id, aura, isBar)
    if not aura or type(id) ~= "number" then return nil end
    local n = SG.Threshold(ns.SpellSetting(barKey, id, "stackGlow"))
    local colors = isBar and SG.CleanColors(ns.SpellSetting(barKey, id, "stackColors")) or nil
    if not n and not colors then return nil end
    return { glow = n, style = n and SG.GlowStyle(barKey, id) or nil, colors = colors }
end

-- 簽章：門檻、發光樣式、各段門檻與顏色、格子尺寸、條身材質與底色（換色那一層自己畫）
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
        bar = type(bar) == "table" and bar or {}
        parts[#parts + 1] = tostring(bar.texture) .. "/" .. CSig(bar.color) .. "/" .. CSig(bar.bgColor)
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

-- 換色那一組（增益長條）：條身底下一顆根框（item 的子框）＋底色＋原色填充＋各段閘／裁切框／色塊
local function BuildColors(item, rec, cfg, bar)
    local ui = UI(rec)
    local b, fill = BlizzBar(item)
    if not cfg.colors or not (b and fill) then
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
    local lv = math.max(1, bl - (SG.MAX_COLORS + 1))
    root:SetFrameLevel(lv)
    local tex = ns.Media.Texture(bar.texture)
    -- 底色：照條的底色（暴雪的 BarBG 調成透明）
    root.bg:ClearAllPoints()
    root.bg:SetAllPoints(b)
    root.bg:SetTexture(SOLID)
    root.bg:SetVertexColor(C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8))
    -- 原色填充：錨在暴雪的填充貼圖上（只錨不讀）
    root.base:ClearAllPoints()
    root.base:SetAllPoints(fill)
    root.base:SetTexture(tex)
    root.base:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1))
    for k, e in ipairs(cfg.colors) do
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
        seg.gate:SetFrameLevel(lv + k)
        seg.clip:SetFrameLevel(lv + k)
        seg.tex:ClearAllPoints()
        seg.tex:SetAllPoints(fill)
        seg.tex:SetTexture(tex)
        seg.tex:SetVertexColor(C4(e.color, 1, 1, 1, 1))
        seg.gate:Show()
        seg.clip:Show()
    end
    for k = #cfg.colors + 1, #ui.colors do
        ui.colors[k].gate:Hide()
        ui.colors[k].clip:Hide()
    end
    ui.barStyle = { color = bar.color, bgColor = bar.bgColor }
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
    if ui.under and cfg.colors then
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
        if cfg.colors then Conceal(item, rec) end
        return
    end
    BuildGlow(rec, cfg, w, h)
    BuildColors(item, rec, cfg, bar)
    rec.stackSig = sig
    rec.stackOff = false
    PaintGlow(rec)
    FeedNow(item, rec, true)
end

-- 無損刷新把條身換回原色（Glow.ApplyPandemic）之後：換色那一層開著就把暴雪的調回透明
function SG.Reconceal(item, rec)
    if not (rec and rec.stackCfg and rec.stackCfg.colors) or rec.stackOff then return end
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
-- 除錯
------------------------------------------------------------
function SG.Counts()
    local glow, colors, lit = 0, 0, 0
    for _, rec in pairs(ns.Viewers.frames) do
        local cfg = rec.stackCfg
        if cfg then
            if cfg.glow then glow = glow + 1 end
            if cfg.colors then colors = colors + 1 end
            if rec.stackGlowOn then lit = lit + 1 end
        end
    end
    return glow, colors, lit
end

local LAST_TEXT = { plain = "明文", secret = "秘密", none = "沒有光環資料（0）", inactive = "沒生效（0）" }

function SG.DebugLine()
    local glow, colors, lit = SG.Counts()
    return ("  層數門檻：發光 %d 格（宿主在畫 %d）  換色 %d 格  掛了 RefreshApplications %d 格  餵了 %d 次  最近一次 %s")
        :format(glow, lit, colors, SG.hooked, SG.feeds, SG.last and (LAST_TEXT[SG.last] or SG.last) or "—")
end
