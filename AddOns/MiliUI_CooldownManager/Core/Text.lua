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
-- 低秒變色兩段各一顆 formatter（門檻與小數共用、色碼不同：增益那一段用 icon.durationLowColor），ApplyPhaseColor 一起換。
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

function T.CountdownFormatter(cdStyle)
    if type(cdStyle) ~= "table" then return nil end
    local d = tonumber(cdStyle.decimalsBelow) or 0
    local lowHex = (cdStyle.lowColor and tonumber(cdStyle.lowBelow) and tonumber(cdStyle.lowBelow) > 0)
        and Hex(cdStyle.lowColor) or nil
    local key = d .. "|" .. tostring(cdStyle.lowBelow) .. "|" .. tostring(lowHex)
    local f = formatters[key]
    if f == nil then
        f = BuildFormatter(d, cdStyle.lowBelow, lowHex) or false
        formatters[key] = f
    end
    return f or nil
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
-- 圖示類（核心／輔助／增益圖示）
--   style：Decorate 解好的那一包（見 Decorate.Resolve）
--   spell：{ hideCooldownText, hideStackText }
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
        local c = style.cooldownText or {}
        if fs then
            SetFont(fs, c.size or 16, outline, ns.Media.ElementFont(c.font, font))
            fs:SetTextColor(Color(c.color))
            Anchor(fs, item, c.point or "CENTER", c.x, c.y)
        end
        local fmt = T.CountdownFormatter(c)
        if fmt and cd.SetCountdownFormatter then
            local ok = pcall(cd.SetCountdownFormatter, cd, fmt)
            if not ok then fmt = nil end
        end
        if not fmt and cd.SetCountdownMillisecondsThreshold then
            pcall(cd.SetCountdownMillisecondsThreshold, cd, tonumber(c.decimalsBelow) or 0)
        end
        -- 現在倒的是增益那一段就換色（上面先寫了倒數原色）
        if rec then T.ApplyPhaseColor(item, rec) end
    end

    -- 充能（核心／輔助）
    local charge = item.ChargeCount and item.ChargeCount.Current
    if charge then
        Lift(item.ChargeCount, rec)
        local c = style.chargeText or {}
        SetFont(charge, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        charge:SetTextColor(Color(c.color))
        Anchor(charge, item, c.point or "BOTTOMRIGHT", c.x, c.y)
    end

    -- 層數（增益圖示）
    local stack = item.Applications and item.Applications.Applications
    if stack then
        Lift(item.Applications, rec)
        local c = style.stackText or {}
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
            SetFont(dur, bar.timeSize or 12, outline, ns.Media.ElementFont(bar.timeFont, font))
            dur:SetTextColor(1, 1, 1, 1)
            -- 直向：秒數疊在條身內的頂端（層數照舊在圖示右下）
            if bar.vertical then
                Anchor(dur, b, "TOP", 0, -4)
                if dur.SetJustifyH then dur:SetJustifyH("CENTER") end
            else
                Anchor(dur, b, "RIGHT", -4, 0)
            end
            dur:SetAlpha((bar.showTime and not spell.hideCooldownText) and 1 or 0)
        end
    end
    local icon = item.Icon
    local stack = icon and icon.Applications
    if stack then
        LiftRegion(stack, rec)            -- 設定頁的預覽格沒有 rec：不動
        local c = style.stackText or {}
        SetFont(stack, bar.stackSize or c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        stack:SetTextColor(Color(c.color))
        -- 錨點照「層數」的長條錨點（stackText.barPoint，九宮格選；預設右下＝舊行為），往內縮 1px 不貼邊，
        -- X／Y 位移加在上面（玩家回報「層數的 XY 改了不會動」，2026-10-03）
        local pt = style.stackBarPoint or "BOTTOMRIGHT"
        local ix, iy = T.BarStackInset(pt)
        Anchor(stack, icon, pt, ix + (tonumber(c.x) or 0), iy + (tonumber(c.y) or 0))
        -- 圖示藏起來（side ＝ NONE 只熄 item.Icon 的 alpha）：換了父層就不會跟著熄，這裡自己熄
        local noIcon = rec and rec.barGeometry and rec.barGeometry.side == "NONE"
        stack:SetAlpha((bar.showStacks and not spell.hideStackText and not noIcon) and 1 or 0)
    end
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
        local c = style.cooldownText or {}
        SetFont(cdText, c.size or 16, outline, ns.Media.ElementFont(c.font, font))
        cdText:SetTextColor(Color(cell.durColor or c.color))
        Anchor(cdText, cell, c.point or "CENTER", c.x, c.y)
        cdText:SetAlpha((cell.onCD and not cell.aura and not spell.hideCooldownText) and 1 or 0)
    end
    local charge = cell.chargeText
    if charge then
        local c = style.chargeText or {}
        SetFont(charge, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        charge:SetTextColor(Color(c.color))
        Anchor(charge, cell, c.point or "BOTTOMRIGHT", c.x, c.y)
        charge:SetAlpha((cell.charges and not cell.aura) and 1 or 0)   -- 真的有充能的格才印（Preview.Fill 查的）
    end
    local stack = cell.stackText
    if stack then
        local c = style.stackText or {}
        SetFont(stack, c.size or 12, outline, ns.Media.ElementFont(c.font, font))
        stack:SetTextColor(Color(c.color))
        Anchor(stack, cell, c.point or "TOP", c.x, c.y)
        stack:SetAlpha(0)
    end
end
