------------------------------------------------------------
-- 倒數／充能／層數文字
--
-- ⚠ 做法：**不自己畫字，改暴雪自己在寫的那幾顆 FontString 的樣式。**
--   倒數  item.Cooldown 的內建倒數數字（Cooldown:GetCountdownFontString()）
--   充能  item.ChargeCount.Current（核心／輔助）
--   層數  item.Applications.Applications（增益圖示）、item.Icon.Applications（增益長條）
-- 我們只呼叫 C 端的樣式 setter（SetFont／SetTextColor／SetPoint／SetAlpha），
-- **從不 SetText、從不讀字**。要藏就熄 alpha（暴雪只在顯示中才寫字，見
-- wow-cooldownviewer-buffbar-text-gate），不 Hide。
--
-- ── 倒數文字選了哪一條路 ───────────────────────────────────────────────
--
-- ✗ 自己算：`Cooldown:GetCooldownTimes()`／`GetCooldownDuration()` 在生成的 API 文件標著
--   `SecretReturnsForAspect = { Cooldown }` —— 暴雪用秘密值 SetCooldown 過的框，讀回來就是
--   秘密數字，污染端不能相減、不能比大小，連「剩幾秒」都算不出來。**不可行。**
--
-- ✗ 低秒變色用 C_CurveUtil 的 Step 曲線：曲線要有一支 API「把曲線收進去、由引擎自己求值」
--   才用得上。`LuaCurveObject:Evaluate(x)` 是 AllowedWhenUntainted（污染端傳秘密 x 被擋），
--   而 `SetCooldownFromDurationObject(duration, clearIfZero)` 的簽章**沒有曲線參數**，
--   Cooldown 也沒有任何 *ColorCurve setter；何況暴雪的冷卻管理器是用 SetCooldown(start,
--   duration) 驅動倒數，根本沒有我們拿得到的 duration 物件。**不可行。**
--
-- ✓ 採用：打開暴雪 Cooldown 的內建倒數數字（`SetHideCountdownNumbers(false)`），
--   用 `GetCountdownFontString()` 拿到那顆 FontString 換字型／字級／顏色／錨點；
--   小數門檻交給 `SetCountdownMillisecondsThreshold`；低秒變色交給
--   `SetCountdownFormatter(NumericRuleFormatter)`：分段規則裡「低於 lowBelow 秒」那幾段的
--   format 字串包 `|cffRRGGBB…|r`。剩餘秒數始終只在引擎裡，Lua 端零讀取。
--   ⚠ 待實機驗證：Cooldown 倒數是否照 FontString 規則解析 |c 色碼（光環按鈕的
--   SetDurationText 在某個 build 上不吃 formatter 裡的色碼，Cooldown 是另一條路徑）。
--   建 formatter 失敗（API 不在、AddBreakpoint 拒收）時退回只設小數門檻、不變色。
--
-- ── 增益持續時間那一段換色（ApplyPhaseColor）──────────────────────────────
-- 技能用掉後暴雪先倒增益的持續時間、增益掉了才倒冷卻；前半段的數字換 durationColor。
-- 一樣只是多叫一次 SetTextColor：要換哪個色看 rec.auraTime（Decorate 的 SetUseAuraDisplayTime
-- 後掛勾記的明文旗標）與 rec.style.cdColor／durColor（Decorate.Apply 算好的）。零讀取。
-- 兩段各一顆 formatter（ApplyPhaseColor 一起換）：冷卻那一段照倒數的小數門檻／低秒變色；增益那一段照下面的「增益持續時間」。
--
-- ── 增益持續時間的小數與低秒變色（I）─────────────────────────────────────────
-- 增益持續時間的倒數自己一組，冷卻倒數不受影響、也不借冷卻的：小數門檻 cooldownText.buffDecimalsBelow（預設 0 ＝ 不顯示小數）、
-- 低秒變色開關 cooldownText.buffLowColor（預設關）、變色秒數 cooldownText.buffLowBelow（J，預設 5）、
-- 變色顏色 icon.durationLowColor（沒有退倒數的低秒色）。逐法術同名覆寫，合併照 SpellText（在 cooldownText 那一段）。
-- 「增益持續時間的倒數」三種格：暴雪增益圖示（ApplyIcon 依 rec.barKey 是 AURA_KIND）、技能格倒增益那一段
-- （Decorate 的 durFmt）、光環格家族（Custom.AuraStyle：formatter＋色彩曲線）。解法只在 T.BuffTiming 一處。
------------------------------------------------------------
local _, ns = ...

ns.Text = {}
local T = ns.Text

local function Hex(c)
    if type(c) ~= "table" then return "ffffff" end
    local function b(v) v = tonumber(v) or 1; if v < 0 then v = 0 elseif v > 1 then v = 1 end return math.floor(v * 255 + 0.5) end
    return string.format("%02x%02x%02x", b(c.r), b(c.g), b(c.b))
end
T.Hex = Hex

local function Color(c)
    if type(c) ~= "table" then return 1, 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end
T.Color = Color

-- 疊在圖示上的小字：像素字型（見 Media.SetPixelFont）。偏移量也要換成同一個尺度：
-- 區域忽略父層縮放之後，它的 SetPoint 偏移是以縮放 1 計，所以乘上 UIParent 的有效縮放。
local function PixelScale()
    local s = UIParent and UIParent:GetEffectiveScale() or 1
    if not s or s <= 0 then s = 1 end
    return s
end

local function SetFont(fs, size, outline, font)
    if not (fs and fs.SetFont) then return end
    ns.Media.SetPixelFont(fs, size, outline or "", font)
end

local function Anchor(fs, relTo, point, x, y)
    if not (fs and relTo) then return end
    local s = PixelScale()
    fs:ClearAllPoints()
    fs:SetPoint(point or "CENTER", relTo, point or "CENTER", (x or 0) * s, (y or 0) * s)
end

T.PixelScale, T.SetFont, T.Anchor = PixelScale, SetFont, Anchor

-- 充能／層數那一框墊到 overlay 之上：overlay（邊框、發光、層數閘）在 item ＋10 起跳，
-- 暴雪的 ChargeCount／Applications 比它低，數字一錨到邊上就被邊框蓋掉（玩家回報，2026-10-04）。
-- 只叫 C 端的 SetFrameLevel，不寫欄位；倒數數字在 Cooldown 框上，墊它會連轉圈一起蓋過邊框，不動。
T.TEXT_LIFT = 5                    -- 高過發光宿主（Glow.lua 最高＋3；StackGate 的發光宿主＋2）
local function Lift(frame, rec)
    local ov = rec and rec.overlay
    if not (frame and frame.SetFrameLevel and ov) then return end
    local lvl = (ov:GetFrameLevel() or 1) + T.TEXT_LIFT
    if lvl > 9000 then lvl = 9000 end
    if frame:GetFrameLevel() ~= lvl then frame:SetFrameLevel(lvl) end
end

-- 增益長條的層數是 item.Icon 框上的一顆 FontString，跟圖示貼圖同一框：墊 item.Icon 會連圖示一起
-- 蓋過邊框。改把那顆 FontString 換父層到 overlay 底下自己的框（同樣 ＋TEXT_LIFT）。字照舊由暴雪寫，
-- 我們不讀；holder 是 item 的孫框，item 被池化挪去別條時跟著走
-- overlay 底下墊高的文字框（＋TEXT_LIFT，高過發光）：搬過來的層數、按鍵文字（Core/Keybinds.lua）都放這裡
function T.TextHolder(rec)
    local ov = rec and rec.overlay
    if not ov then return nil end
    local h = rec.textHolder
    if not h then
        h = CreateFrame("Frame", nil, ov)
        h:SetAllPoints(ov)
        rec.textHolder = h
    end
    local lvl = (ov:GetFrameLevel() or 1) + T.TEXT_LIFT
    if lvl > 9000 then lvl = 9000 end
    if h:GetFrameLevel() ~= lvl then h:SetFrameLevel(lvl) end
    return h
end

local function LiftRegion(fs, rec)
    if not (fs and fs.SetParent) then return end
    local h = T.TextHolder(rec)
    if not h then return end
    if fs:GetParent() ~= h then fs:SetParent(h) end
end

------------------------------------------------------------
-- 倒數 formatter（依設定簽章快取；同一顆可以給很多個 Cooldown 共用）
------------------------------------------------------------
local formatters = {}

-- 「分／時」的寫法照客戶端語系：用暴雪自己給冷卻倒數的全域字串
-- （COOLDOWN_DURATION_MIN／_HOURS：enUS "%dm"／"%dh"、zhTW "%d分"／"%d小時"、koKR "%d분"／"%d시간"…）。
-- 規則格式器一段只餵一個數字 ⇒ 只收「恰好一個格式符、而且是 %d」的字串，其餘退回英文縮寫；
-- 有的語系字串裡夾著換行，空白一律收成一格。
local function UnitFormat(name, fallback)
    local s = _G[name]
    if type(s) ~= "string" then return fallback end
    s = s:gsub("%s+", " ")
    local _, n = s:gsub("%%", "")
    if n ~= 1 or not s:find("%%d") then return fallback end
    return s
end
T.UnitFormat = UnitFormat

local function BuildFormatter(decimalsBelow, lowBelow, lowHex)
    local SU = C_StringUtil
    if not (SU and SU.CreateNumericRuleFormatter) then return nil end
    local R = Enum and Enum.NumericRuleFormatRounding
    if not R then return nil end
    local down, up = R.Down, R.Up

    local d = tonumber(decimalsBelow) or 0
    local l = lowHex and (tonumber(lowBelow) or 0) or 0
    -- 切點：0、小數門檻、變色門檻、91 秒（改印分）、5401 秒（改印時）；91／5401 是暴雪自己的升位點
    local cuts, seen = {}, {}
    for _, t in ipairs({ 0, d, l, 91, 5401 }) do
        if t >= 0 and not seen[t] then seen[t] = true; cuts[#cuts + 1] = t end
    end
    table.sort(cuts)

    local ok, fmt = pcall(SU.CreateNumericRuleFormatter)
    if not ok or not fmt then return nil end
    local minFmt = UnitFormat("COOLDOWN_DURATION_MIN", "%dm")
    local hourFmt = UnitFormat("COOLDOWN_DURATION_HOURS", "%dh")
    for _, t in ipairs(cuts) do
        local rule
        if t >= 5401 then
            rule = { threshold = t, step = 1, rounding = down, min = 1, format = hourFmt,
                     components = { { div = 3600, rounding = up } } }
        elseif t >= 91 then
            rule = { threshold = t, step = 1, rounding = down, min = 1, format = minFmt,
                     components = { { div = 60, rounding = up } } }
        elseif t < d then
            rule = { threshold = t, step = 0.1, rounding = down, format = "%.1f" }
        else
            -- 有小數段時整數段往下取（3.2→3，接著 2.9），沒有時照暴雪往上取（剩 0.4 秒還是 1）
            rule = { threshold = t, step = 1, rounding = (d > 0) and down or up, format = "%d" }
        end
        if l > 0 and t < l and t < 91 then
            rule.format = "|cff" .. lowHex .. rule.format .. "|r"
        end
        local added = pcall(fmt.AddBreakpoint, fmt, rule)
        if not added then return nil end     -- 半成品收不回來：整顆不用
    end
    return fmt
end

-- 依（小數門檻, 低秒門檻, 色碼）取一顆；不變色時門檻一律記成 0（同一顆不重建）
local function Formatter(decimalsBelow, lowBelow, lowColor)
    local d = tonumber(decimalsBelow) or 0
    local l = tonumber(lowBelow) or 0
    local lowHex = (type(lowColor) == "table" and l > 0) and Hex(lowColor) or nil
    if not lowHex then l = 0 end
    local key = d .. "|" .. l .. "|" .. tostring(lowHex)
    local f = formatters[key]
    if f == nil then
        f = BuildFormatter(d, l, lowHex) or false
        formatters[key] = f
    end
    return f or nil
end

-- 冷卻倒數的低秒門檻（關 ＝ 0）：開關 lowColorOn 跟變色秒數 lowBelow 是兩個欄位（2026-10-06 拆開：
-- 以前 lowBelow 兼作開關、0 ＝ 關，取消勾選就把玩家調的秒數洗掉；舊存檔的 0 由 DB 的 MIGRATIONS[5] 改成 關＋5 秒）。
-- 開關只認 false 是關：沒存（nil）＝ 開，跟預設值一致，也讓只帶幾格的倒數表（條自己的子表、測試）照舊
function T.CdLowBelow(c)
    if type(c) ~= "table" or c.lowColorOn == false then return 0 end
    return math.max(0, tonumber(c.lowBelow) or 0)
end

-- 冷卻倒數：倒數表（條層或合併後的）的 decimalsBelow／lowColorOn＋lowBelow／lowColor
function T.CountdownFormatter(cdStyle)
    if type(cdStyle) ~= "table" then return nil end
    return Formatter(cdStyle.decimalsBelow, T.CdLowBelow(cdStyle), cdStyle.lowColor)
end

-- 增益持續時間的倒數（I）：c ＝ 倒數表（條層或 SpellText 合併後的），lowColor ＝ 增益持續時間低秒顏色（nil 退倒數的低秒色）
-- 回傳 小數門檻, 低秒門檻（關 ＝ 0）, 低秒顏色。舊存檔沒有這幾欄 ⇒ 0／關／5（合併預設值補上）
-- 門檻只讀增益持續時間自己的 buffLowBelow（J）：冷卻倒數的 lowBelow 不管開關都不看
function T.BuffTiming(c, lowColor)
    if type(c) ~= "table" then return 0, 0, nil end
    local d = tonumber(c.buffDecimalsBelow) or 0
    local l = 0
    if c.buffLowColor == true then l = math.max(0, tonumber(c.buffLowBelow) or 0) end
    return d, l, (type(lowColor) == "table" and lowColor) or c.lowColor
end

function T.BuffFormatter(c, lowColor)
    if type(c) ~= "table" then return nil end
    return Formatter(T.BuffTiming(c, lowColor))
end

-- 不帶色碼的版本（光環格的 SetDurationText 用：那條路不吃 format 裡的 |c，變色改走色彩曲線）
function T.PlainFormatter(decimalsBelow)
    local d = tonumber(decimalsBelow) or 0
    local key = d .. "|plain"
    local f = formatters[key]
    if f == nil then
        f = BuildFormatter(d, 0, nil) or false
        formatters[key] = f
    end
    return f or nil
end

-- 「剩幾個 GCD」（資源條的秘法靈魂）：剩餘秒數 x、GCD 長度 g
--   x ≥ g    印 ceil(x ／ g)（元件 div = g、step 1 往上取）
--   x < g    印 last（最後一個 GCD；這一段沒有數字格式符）
-- g 是建容器前算好的明文（四捨五入到 0.05 秒），同一個 g 共用一顆
function T.GcdFormatter(gcd, last)
    local g = tonumber(gcd)
    if not g or g <= 0 then return nil end
    local label = (type(last) == "string" and last ~= "") and last or "1"
    local key = ("gcd|%.2f|%s"):format(g, label)
    local f = formatters[key]
    if f ~= nil then return f or nil end
    f = false
    local SU = C_StringUtil
    local RD = Enum and Enum.NumericRuleFormatRounding
    if SU and SU.CreateNumericRuleFormatter and RD then
        local ok, fmt = pcall(SU.CreateNumericRuleFormatter)
        if ok and fmt then
            -- 標籤裡的 % 要跳脫（format 字串）
            local rules = {
                { threshold = 0, rounding = RD.Down, format = (label:gsub("%%", "%%%%")) },
                { threshold = g, rounding = RD.Up, format = "%d",
                  components = { { div = g, step = 1, rounding = RD.Up } } },
            }
            local all = true
            for _, rule in ipairs(rules) do
                if not pcall(fmt.AddBreakpoint, fmt, rule) then all = false break end
            end
            if all then f = fmt end
        end
    end
    formatters[key] = f
    return f or nil
end

------------------------------------------------------------
-- 逐法術的文字樣式（單一法術小窗的「文字」分頁，H）：條層 ⊕ 逐法術覆寫的**唯一**合併點
--
--   ns.Text.SpellText(barKey, id, section [, fresh]) → t, hide, own
--     section  "cooldownText" | "chargeText" | "stackText" | "keybind"：底＝條層同名那張表（ns.Setting）
--              "barTime"：長條的秒數（暴雪增益長條、自訂長條框、光環長條）。底＝條層「長條」節的秒數字型／字級
--              （bar.timeFont／timeSize），顏色白、錨點照長條的預設；覆寫欄位跟倒數同一組（cooldownTextFont…）
--     t        合併後的表（讀法跟條層那張一樣：t.size、t.font…）。沒有任何覆寫 ＝ 條層那張表本身（唯讀）
--     hide     這一段要不要藏（hideCooldownText／hideChargeText／hideStackText／hideKeybind；沒覆寫 ＝ false）
--     own      只有覆寫的欄位（沒有 ＝ EMPTY）：要分得出「這一招自己改了」的地方用
--              （長條秒數的錨點：沒覆寫時照預設位置＋偏移）
--   ns.Text.OverrideSig(id)   這一招的文字覆寫串成一段字（簽章用：Decorate／自訂長條的 timerSig）
--
-- 快取：每個（條、id、段）一筆，對 Decorate.styleGen（條層設定）與 DB.overrideGen（逐法術覆寫）兩個世代；
-- 命中時不配置任何表（Keybinds.Apply 每次排版都叫）。合併的表用 __index 指回條層那張，條層原地改值
-- （色票）也讀得到；換了表一定經過 InvalidateAll（styleGen +1）。
-- fresh ＝ true：不讀也不寫快取（設定頁預覽：滑桿拖動中只重畫預覽、還沒 InvalidateAll）。
------------------------------------------------------------
local EMPTY = {}
T.EMPTY = EMPTY

-- 段 → { hide ＝ 隱藏欄位, keys ＝ { 條層欄位 ＝ 覆寫欄位 } }；順序表給簽章用（pairs 的順序不固定）
local CD_KEYS = {
    { "font", "cooldownTextFont" }, { "size", "cooldownTextSize" }, { "color", "cooldownTextColor" },
    { "point", "cooldownTextPoint" }, { "x", "cooldownTextX" }, { "y", "cooldownTextY" },
    { "decimalsBelow", "cooldownTextDecimals" }, { "lowColorOn", "cooldownTextLowColorOn" },
    { "lowBelow", "cooldownTextLowBelow" }, { "lowColor", "cooldownTextLowColor" },
    -- 增益持續時間的小數門檻與低秒變色開關（I）：覆寫 key 跟條層同名
    { "buffDecimalsBelow", "buffDecimalsBelow" }, { "buffLowColor", "buffLowColor" },
    { "buffLowBelow", "buffLowBelow" },
}
local function Pos(prefix)
    return { { "font", prefix .. "Font" }, { "size", prefix .. "Size" }, { "color", prefix .. "Color" },
             { "point", prefix .. "Point" }, { "x", prefix .. "X" }, { "y", prefix .. "Y" } }
end
local SECTIONS = {
    cooldownText = { hide = "hideCooldownText", keys = CD_KEYS },
    -- 長條秒數：秒數是暴雪每幀寫的字串（或整數 formatter），小數門檻與低秒變色換不了 ⇒ 只收位置與外觀
    barTime      = { hide = "hideCooldownText", keys = { CD_KEYS[1], CD_KEYS[2], CD_KEYS[3], CD_KEYS[4], CD_KEYS[5], CD_KEYS[6] } },
    chargeText   = { hide = "hideChargeText", keys = Pos("chargeText") },
    stackText    = { hide = "hideStackText", keys = Pos("stackText") },
    -- 按鍵文字沒有顏色（一律白字，同條層）
    keybind      = { hide = "hideKeybind", keys = { { "font", "keybindFont" }, { "size", "keybindSize" },
                     { "point", "keybindPoint" }, { "x", "keybindX" }, { "y", "keybindY" } } },
}
T.TEXT_SECTIONS = SECTIONS

local function Base(barKey, section)
    local S = ns.Setting
    if section == "barTime" then
        local bar = S and S(barKey, "bar")
        bar = type(bar) == "table" and bar or EMPTY
        return { font = bar.timeFont, size = tonumber(bar.timeSize) or 12 }
    end
    local t = S and S(barKey, section)
    return type(t) == "table" and t or EMPTY
end

local textCache = {}            -- barKey → id → section → { sg, og, t, hide, own }

local function Gens()
    local D, DB = ns.Decorate, ns.DB
    return (D and D.styleGen) or 0, (DB and DB.overrideGen) or 0
end

function T.SpellText(barKey, id, section, fresh)
    local spec = SECTIONS[section]
    if not spec then return EMPTY, false, EMPTY end
    local bk = barKey or "theme"
    local sg, og = Gens()
    local byId
    if not fresh then
        local byBar = textCache[bk]
        byId = byBar and id ~= nil and byBar[id]
        local e = byId and byId[section]
        if e and e.sg == sg and e.og == og then return e.t, e.hide, e.own end
    end
    local base = Base(barKey, section)
    local DB = ns.DB
    local ov = (id ~= nil and DB and DB.OverrideTable) and DB.OverrideTable(id, false) or nil
    local own, hide = nil, false
    if type(ov) == "table" then
        for _, kv in ipairs(spec.keys) do
            local v = ov[kv[2]]
            if v ~= nil then
                own = own or {}
                own[kv[1]] = v
            end
        end
        hide = ov[spec.hide] and true or false
    end
    local t = base
    if own then
        t = {}
        for k, v in pairs(own) do t[k] = v end
        setmetatable(t, { __index = base })
    end
    own = own or EMPTY
    if not fresh and id ~= nil then
        local byBar = textCache[bk]
        if not byBar then byBar = {}; textCache[bk] = byBar end
        byId = byBar[id]
        if not byId then byId = {}; byBar[id] = byId end
        local e = byId[section]
        if not e then e = {}; byId[section] = e end
        e.sg, e.og, e.t, e.hide, e.own = sg, og, t, hide, own
    end
    return t, hide, own
end

-- 這一招的文字覆寫（倒數／充能／層數三段＋三個隱藏；按鍵文字不在內，Keybinds.Apply 有自己的簽章）串成字。
-- 沒有 ＝ ""。依 DB.overrideGen 快取（Decorate 只在前置鍵沒中時叫；自訂光環格的 AuraStyle 每次放格都叫）
local sigCache = {}             -- id → { og, s }
local SIG_FIELDS = { "hideCooldownText", "hideChargeText", "hideStackText" }
for _, sec in ipairs({ "cooldownText", "chargeText", "stackText" }) do
    for _, kv in ipairs(SECTIONS[sec].keys) do SIG_FIELDS[#SIG_FIELDS + 1] = kv[2] end
end
T.SIG_FIELDS = SIG_FIELDS

function T.OverrideSig(id)
    if id == nil then return "" end
    local _, og = Gens()
    local e = sigCache[id]
    if e and e.og == og then return e.s end
    local DB = ns.DB
    local ov = DB and DB.OverrideTable and DB.OverrideTable(id, false) or nil
    local s = ""
    if type(ov) == "table" then
        local parts
        for _, f in ipairs(SIG_FIELDS) do
            local v = ov[f]
            if v ~= nil then
                parts = parts or {}
                if type(v) == "table" then v = Hex(v) .. string.format("%.2f", tonumber(v.a) or 1) end
                parts[#parts + 1] = f .. "=" .. tostring(v)
            end
        end
        if parts then s = table.concat(parts, ";") end
    end
    if not e then e = {}; sigCache[id] = e end
    e.og, e.s = og, s
    return s
end

-- 長條秒數的位置：沒覆寫錨點 ＝ 長條的預設（橫向右緣內縮 4、直向頂端內縮 4）＋覆寫的偏移；
-- 覆寫了錨點 ＝ 那個錨點＋覆寫的偏移（沒寫 0）。回傳 point, x, y, justifyH（偏移是縮放 1 的單位）
function T.BarTimePlace(own, vertical)
    own = own or EMPTY
    local ox, oy = tonumber(own.x) or 0, tonumber(own.y) or 0
    local p = own.point
    if type(p) == "string" and p ~= "" then
        local j = p:find("RIGHT") and "RIGHT" or (p:find("LEFT") and "LEFT" or "CENTER")
        return p, ox, oy, j
    end
    if vertical then return "TOP", ox, -4 + oy, "CENTER" end
    return "RIGHT", -4 + ox, oy, "RIGHT"
end

------------------------------------------------------------
-- 圖示類（核心／輔助／增益圖示）
--   style：Decorate 解好的那一包（見 Decorate.Resolve）
--   spell：Decorate 的 SpellStyle（hideCooldownText／hideChargeText／hideStackText；cooldownText／chargeText／
--          stackText ＝ Text.SpellText 合併好的表，沒有就退條層）
--   rec：  暴雪 item 的記錄（增益持續時間換色用；自訂框沒有那一段，rec.style.cdColor 是 nil 就不動）
------------------------------------------------------------

-- 倒數數字照「現在倒的是增益還是冷卻」上色（rec.style.cdColor 沒有 ＝ 這格不做）
function T.ApplyPhaseColor(item, rec)
    local st = rec and rec.style
    local cd = item and item.Cooldown
    if not (st and st.cdColor and cd and cd.GetCountdownFontString) then return end
    local fs = cd:GetCountdownFontString()
    if not fs then return end
    -- allAura：以增益取代時頂著技能格的增益，整段都算增益那一段（Decorate.Apply）
    local aura = rec.auraTime or st.allAura
    local c = (aura and st.durColor) or st.cdColor
    fs:SetTextColor(c[1], c[2], c[3], c[4])
    -- 低秒變色：增益那一段用它自己的 formatter（色碼不同、門檻同）；兩顆都有才換，少一顆就留 ApplyIcon 設的那顆
    local fmt = (aura and st.durFmt) or st.cdFmt
    if fmt and st.durFmt and st.cdFmt and cd.SetCountdownFormatter then pcall(cd.SetCountdownFormatter, cd, fmt) end
end

function T.ApplyIcon(item, style, spell, rec)
    local font, outline = style.font, style.outline

    -- 倒數
    local cd = item.Cooldown
    if cd then
        local hide = spell.hideCooldownText and true or false
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(hide) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        local c = spell.cooldownText or style.cooldownText or {}
        if fs then
            SetFont(fs, c.size or 16, outline, ns.Media.ElementFont(c.font, font))
            fs:SetTextColor(Color(c.color))
            Anchor(fs, item, c.point or "CENTER", c.x, c.y)
        end
        -- 暴雪的增益圖示（rec.barKey 是增益類；自訂框與預覽格不算）整條都是增益持續時間 ⇒ 照「增益持續時間」那一組
        local buff = rec and not rec.custom and rec.barKey and ns.Viewers and ns.Viewers.AURA_KIND
            and ns.Viewers.AURA_KIND[rec.barKey]
        local fmt
        if buff then fmt = T.BuffFormatter(c, spell.durationLowColor) else fmt = T.CountdownFormatter(c) end
        if fmt and cd.SetCountdownFormatter then
            local ok = pcall(cd.SetCountdownFormatter, cd, fmt)
            if not ok then fmt = nil end
        end
        if not fmt and cd.SetCountdownMillisecondsThreshold then
            local d = tonumber(c.decimalsBelow) or 0
            if buff then d = (T.BuffTiming(c)) end
            pcall(cd.SetCountdownMillisecondsThreshold, cd, d)
        end
        -- 現在倒的是增益那一段就換色（上面先寫了倒數原色）
        if rec then T.ApplyPhaseColor(item, rec) end
    end

    -- 充能（核心／輔助）
    local charge = item.ChargeCount and item.ChargeCount.Current
    if charge then
        Lift(item.ChargeCount, rec)
        local c = spell.chargeText or style.chargeText or {}
        SetFont(charge, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        charge:SetTextColor(Color(c.color))
        Anchor(charge, item, c.point or "BOTTOMRIGHT", c.x, c.y)
        charge:SetAlpha(spell.hideChargeText and 0 or 1)
    end

    -- 層數（增益圖示）
    local stack = item.Applications and item.Applications.Applications
    if stack then
        Lift(item.Applications, rec)
        local c = spell.stackText or style.stackText or {}
        SetFont(stack, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        stack:SetTextColor(Color(c.color))
        Anchor(stack, item, c.point or "TOP", c.x, c.y)
        stack:SetAlpha(spell.hideStackText and 0 or 1)
    end
end

------------------------------------------------------------
-- 增益長條：名字／時間／層數
--   名字讓暴雪寫；我們只調樣式與位置，要藏就熄 alpha
------------------------------------------------------------
-- 長條層數錨在圖示角落時往內縮 1px（右下 ＝ -1, 1，舊的固定位置）；置中的那一軸不縮
function T.BarStackInset(pt)
    local ix = pt:find("RIGHT") and -1 or (pt:find("LEFT") and 1 or 0)
    local iy = pt:find("BOTTOM") and 1 or (pt:find("TOP") and -1 or 0)
    return ix, iy
end

function T.ApplyBar(item, style, spell, bar, rec)
    local font, outline = style.font, style.outline
    local b = item.Bar
    if b then
        local name = b.Name
        if name then
            SetFont(name, bar.nameSize or 12, outline, ns.Media.ElementFont(bar.nameFont, font))
            name:SetTextColor(1, 1, 1, 1)
            local s = PixelScale()
            name:ClearAllPoints()
            name:SetPoint("LEFT", b, "LEFT", 4 * s, 0)
            name:SetPoint("RIGHT", b, "RIGHT", -((bar.timeSize or 12) * 3) * s, 0)
            if name.SetJustifyH then name:SetJustifyH("LEFT") end
            -- 直向（F8c）：FontString 不能轉，名字不畫
            name:SetAlpha((bar.showName and not bar.vertical) and 1 or 0)
        end
        local dur = b.Duration
        if dur then
            -- 字型／字級／顏色／位置：條層「長條」節的秒數 ⊕ 逐法術覆寫（Text.SpellText 的 "barTime"）
            local tt, own = spell.barTime or { font = bar.timeFont, size = bar.timeSize }, spell.barTimeOwn
            SetFont(dur, tt.size or 12, outline, ns.Media.ElementFont(tt.font, font))
            dur:SetTextColor(Color(tt.color))
            -- 直向：秒數疊在條身內的頂端（層數照舊在圖示右下）
            local p, x, y, j = T.BarTimePlace(own, bar.vertical)
            Anchor(dur, b, p, x, y)
            if dur.SetJustifyH then dur:SetJustifyH(j) end
            dur:SetAlpha((bar.showTime and not spell.hideCooldownText) and 1 or 0)
        end
    end
    local icon = item.Icon
    local stack = icon and icon.Applications
    if stack then
        LiftRegion(stack, rec)            -- 設定頁的預覽格沒有 rec：不動
        local c = spell.stackText or style.stackText or {}
        -- 字級：c 已經是這一招覆寫 ⊕ 條層「層數」的字級（v6 起沒有長條自己的層數字級）
        SetFont(stack, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        stack:SetTextColor(Color(c.color))
        -- 錨點照「層數」的長條錨點（stackText.barPoint，九宮格選；預設右下＝舊行為），往內縮 1px 不貼邊，
        -- X／Y 位移加在上面（玩家回報「層數的 XY 改了不會動」，2026-10-03）
        local pt = style.stackBarPoint or "BOTTOMRIGHT"
        local ix, iy = T.BarStackInset(pt)
        Anchor(stack, icon, pt, ix + (tonumber(c.x) or 0), iy + (tonumber(c.y) or 0))
        -- 暴雪的 XML 把這顆字定成 32×10、靠右對齊：錨在右下看不出來，換成置中／靠左時字會被推到框的右緣
        -- （預覽格的字是自動尺寸，兩邊對不上）⇒ 解開成自動尺寸，錨點就是字本身的那一角
        if stack.SetSize then stack:SetSize(0, 0) end
        -- 圖示藏起來（side ＝ NONE 只熄 item.Icon 的 alpha）：換了父層就不會跟著熄，這裡自己熄
        local noIcon = rec and rec.barGeometry and rec.barGeometry.side == "NONE"
        stack:SetAlpha((bar.showStacks and not spell.hideStackText and not noIcon) and 1 or 0)
    end
end

------------------------------------------------------------
-- 自訂文字（M）：玩家逐格打的提醒字（「這個增益是什麼」），只畫在增益圖示類的格上
--
--   ns.Text.LabelStyle(barKey, id [, fresh]) → st 或 nil（沒打字 ＝ nil ＝ 不畫）
--     st = { text, font（字型 token，已退條的通用字型）, size, color = { r, g, b, a }, point, x, y, outline, sig }
--   ns.Text.LabelPlace(point) → 錨點（文字與圖示同一點）, 對齊
--   ns.Text.ApplyLabel(fs, relTo, st [, alpha])   套在**我們自己的** FontString 上（st nil ＝ 收起來）
--   ns.Text.ItemLabel(item, rec, st)              暴雪增益格：FontString 建在 overlay 的墊高文字框（TextHolder）
--
-- 欄位全是逐法術覆寫（沒有條層值，Core/DB.lua 的 SPELL_CONST）：labelText／labelFont／labelSize／labelColor／
-- labelPoint／labelX／labelY。描邊吃條的 outline，不另給。字是玩家打的明文 ⇒ 直接 SetText，不拼色碼；顏色走 SetTextColor。
--
-- ── 錨點的語意：九宮格＝「圖示內的那個角／邊」（跟倒數、層數、充能的錨點同一套：文字的那一點貼圖示的那一點）──
--   使用者 2026-10-06 給了參考圖：預設在圖示內、下緣置中，字的下半略壓過下緣（超出一點點可以）
--   ⇒ 預設 labelPoint ＝ BOTTOM、labelY ＝ -2（DB 的 SPELL_CONST；偏移跟其他文字同一個單位，Text.Anchor 的換算）。
--   預設的 -2 就是 Y 框裡看得到的值，玩家改成 0 就整個收在圖示裡。
--
-- 三種格怎麼畫：
--   暴雪的增益圖示（增益圖示列、放增益的自訂圖示群組）：Decorate.Apply → ItemLabel；跟著 item 顯示／alpha，暴雪框零寫入
--   光環格家族（自訂光環格、飾品欄增益；圖示形）：Custom.AuraStyle 解進 st.label、進簽章，InitAuraButton 在按鈕的 ov 上建
--     （改了換容器、戰鬥中等脫戰）；飾品冷卻格上的增益疊層不畫（那一格是冷卻格）
--   占位（Bars 的增益占位、自訂光環格的占位）：Decorate.ApplyPlaceholder 在占位框上畫一份，跟占位圖示一樣半透明
--     （光環格的占位一直在、按鈕出現時蓋在上面：兩份字同位置同樣式，看起來就是一份）
------------------------------------------------------------
T.LABEL_PH_ALPHA = 1               -- 占位上的那一份：不透明（半透明時底下的框線會透過字顯出來，看起來像被蓋住；使用者 2026-10-06）

local LABEL_POINTS = {
    TOP = "CENTER", BOTTOM = "CENTER", CENTER = "CENTER", LEFT = "LEFT", RIGHT = "RIGHT",
    TOPLEFT = "LEFT", BOTTOMLEFT = "LEFT", TOPRIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT",
}
T.LABEL_POINTS = LABEL_POINTS

function T.LabelPlace(point)
    if not LABEL_POINTS[point] then point = "BOTTOM" end
    return point, LABEL_POINTS[point]
end

local labelCache = {}           -- barKey → id → { sg, og, st }（st 可以是 false ＝ 沒字）

function T.LabelStyle(barKey, id, fresh)
    if id == nil then return nil end
    local bk = barKey or "theme"
    local sg, og = Gens()
    if not fresh then
        local byBar = labelCache[bk]
        local e = byBar and byBar[id]
        if e and e.sg == sg and e.og == og then return e.st or nil end
    end
    local DB = ns.DB
    local ov = (DB and DB.OverrideTable) and DB.OverrideTable(id, false) or nil
    local st = false
    local text = type(ov) == "table" and ov.labelText
    if type(text) == "string" and text:find("%S") then           -- 空字串、只有空白 ＝ 沒字
        local S = ns.Setting
        local C = DB.SPELL_CONST or EMPTY
        local col = type(ov.labelColor) == "table" and ov.labelColor or nil
        local point = ov.labelPoint
        if not LABEL_POINTS[point] then point = C.labelPoint or "BOTTOM" end
        st = {
            -- 玩家打的原字：「|」跳脫成「||」，免得被當成色碼／貼圖／連結的控制碼（照原樣顯示）
            text    = (text:gsub("|", "||")),
            font    = ns.Media.ElementFont(ov.labelFont, S and S(barKey, "font")),
            size    = tonumber(ov.labelSize) or C.labelSize or 12,
            color   = { r = col and tonumber(col.r) or 1, g = col and tonumber(col.g) or 1,
                        b = col and tonumber(col.b) or 1, a = col and tonumber(col.a) or 1 },
            point   = point,
            x       = tonumber(ov.labelX) or C.labelX or 0,
            y       = tonumber(ov.labelY) or C.labelY or 0,
            outline = (S and S(barKey, "outline")) or "",
        }
        st.sig = table.concat({ text, tostring(st.font), st.size, Hex(st.color), string.format("%.2f", st.color.a),
            point, st.x, st.y, st.outline }, "\031")
    end
    if not fresh then
        local byBar = labelCache[bk]
        if not byBar then byBar = {}; labelCache[bk] = byBar end
        local e = byBar[id]
        if not e then e = {}; byBar[id] = e end
        e.sg, e.og, e.st = sg, og, st
    end
    return st or nil
end

-- 簽章用（Decorate.Signature）：沒字 ＝ "-"
function T.LabelSig(st) return st and st.sig or "-" end

function T.ApplyLabel(fs, relTo, st, alpha)
    if not fs then return end
    if not (st and relTo) then fs:Hide() return end
    SetFont(fs, st.size, st.outline, st.font)              -- 先有字型才能 SetText
    local c = st.color
    fs:SetTextColor(c.r, c.g, c.b, c.a)
    local p, j = T.LabelPlace(st.point)
    Anchor(fs, relTo, p, st.x, st.y)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetJustifyH then fs:SetJustifyH(j) end
    fs:SetText(st.text)
    fs:SetAlpha(alpha or 1)
    fs:Show()
end

-- 暴雪的增益圖示：只寫我們自己的 FontString（overlay 底下的墊高文字框，跟著 item 顯示／alpha）
function T.ItemLabel(item, rec, st)
    if not rec then return end
    local fs = rec.labelFS
    if not st then
        if fs then fs:Hide() end
        return
    end
    if not fs then
        local h = T.TextHolder(rec)
        if not h then return end
        fs = h:CreateFontString(nil, "OVERLAY")
        rec.labelFS = fs
    end
    T.ApplyLabel(fs, item, st)
end

------------------------------------------------------------
-- 設定頁的預覽格（圖示類）：同一套字型／顏色／錨點，套在我們自己的 FontString 上
--   cell.cdText     假倒數（冷卻中的格才顯示）
--   cell.chargeText 充能上限（技能類；真的有充能才印，cell.charges）
--   cell.stackText  假層數
-- 增益格（增益圖示條、光環格）的預覽不印字：整排 2／15 礙眼（使用者 2026-10-03），
-- 增益格的字型樣式只影響數字外觀、看冷卻格的就夠
--   cell.durColor   假冷卻格裡標成「增益那一段」的，倒數用這個色（Decorate.ApplyPreview 算好；nil ＝ 原色）
-- 字是預覽自己寫的（「15」「2」），這裡只管樣式與顯示與否。
------------------------------------------------------------
function T.ApplyPreviewIcon(cell, style, spell)
    local font, outline = style.font, style.outline
    local cdText = cell.cdText
    if cdText then
        local c = spell.cooldownText or style.cooldownText or {}
        SetFont(cdText, c.size or 16, outline, ns.Media.ElementFont(c.font, font))
        cdText:SetTextColor(Color(cell.durColor or c.color))
        Anchor(cdText, cell, c.point or "CENTER", c.x, c.y)
        cdText:SetAlpha((cell.onCD and not cell.aura and not spell.hideCooldownText) and 1 or 0)
    end
    local charge = cell.chargeText
    if charge then
        local c = spell.chargeText or style.chargeText or {}
        SetFont(charge, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        charge:SetTextColor(Color(c.color))
        Anchor(charge, cell, c.point or "BOTTOMRIGHT", c.x, c.y)
        -- 真的有充能的格才印（Preview.Fill 查的）；這一招設了隱藏充能就不印
        charge:SetAlpha((cell.charges and not cell.aura and not spell.hideChargeText) and 1 or 0)
    end
    local stack = cell.stackText
    if stack then
        local c = spell.stackText or style.stackText or {}
        SetFont(stack, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        stack:SetTextColor(Color(c.color))
        Anchor(stack, cell, c.point or "TOP", c.x, c.y)
        stack:SetAlpha(0)
    end
    -- 自訂文字（M）：增益類的格才畫（光環格、暴雪的增益圖示；冷卻格不畫）
    if cell.labelText then T.ApplyLabel(cell.labelText, cell, cell.aura and spell.label or nil) end
end
