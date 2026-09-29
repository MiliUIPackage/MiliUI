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

------------------------------------------------------------
-- 倒數 formatter（依設定簽章快取；同一顆可以給很多個 Cooldown 共用）
------------------------------------------------------------
local formatters = {}

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
    for _, t in ipairs(cuts) do
        local rule
        if t >= 5401 then
            rule = { threshold = t, step = 1, rounding = down, min = 1, format = "%dh",
                     components = { { div = 3600, rounding = up } } }
        elseif t >= 91 then
            rule = { threshold = t, step = 1, rounding = down, min = 1, format = "%dm",
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

------------------------------------------------------------
-- 圖示類（核心／輔助／增益圖示）
--   style：Decorate 解好的那一包（見 Decorate.Resolve）
--   spell：{ hideCooldownText, hideStackText }
------------------------------------------------------------
function T.ApplyIcon(item, style, spell)
    local font, outline = style.font, style.outline

    -- 倒數
    local cd = item.Cooldown
    if cd then
        local hide = spell.hideCooldownText and true or false
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(hide) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        local c = style.cooldownText or {}
        if fs then
            SetFont(fs, c.size or 16, outline, font)
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
    end

    -- 充能（核心／輔助）
    local charge = item.ChargeCount and item.ChargeCount.Current
    if charge then
        local c = style.chargeText or {}
        SetFont(charge, c.size or 12, outline, font)
        charge:SetTextColor(Color(c.color))
        Anchor(charge, item, c.point or "BOTTOMRIGHT", c.x, c.y)
    end

    -- 層數（增益圖示）
    local stack = item.Applications and item.Applications.Applications
    if stack then
        local c = style.stackText or {}
        SetFont(stack, c.size or 12, outline, font)
        stack:SetTextColor(Color(c.color))
        Anchor(stack, item, c.point or "TOP", c.x, c.y)
        stack:SetAlpha(spell.hideStackText and 0 or 1)
    end
end

------------------------------------------------------------
-- 增益長條：名字／時間／層數
--   名字讓暴雪寫；我們只調樣式與位置，要藏就熄 alpha
------------------------------------------------------------
function T.ApplyBar(item, style, spell, bar)
    local font, outline = style.font, style.outline
    local b = item.Bar
    if b then
        local name = b.Name
        if name then
            SetFont(name, bar.nameSize or 12, outline, font)
            name:SetTextColor(1, 1, 1, 1)
            local s = PixelScale()
            name:ClearAllPoints()
            name:SetPoint("LEFT", b, "LEFT", 4 * s, 0)
            name:SetPoint("RIGHT", b, "RIGHT", -((bar.timeSize or 12) * 3) * s, 0)
            if name.SetJustifyH then name:SetJustifyH("LEFT") end
            name:SetAlpha(bar.showName and 1 or 0)
        end
        local dur = b.Duration
        if dur then
            SetFont(dur, bar.timeSize or 12, outline, font)
            dur:SetTextColor(1, 1, 1, 1)
            Anchor(dur, b, "RIGHT", -4, 0)
            dur:SetAlpha((bar.showTime and not spell.hideCooldownText) and 1 or 0)
        end
    end
    local icon = item.Icon
    local stack = icon and icon.Applications
    if stack then
        local c = style.stackText or {}
        SetFont(stack, bar.stackSize or c.size or 12, outline, font)
        stack:SetTextColor(Color(c.color))
        Anchor(stack, icon, "BOTTOMRIGHT", -1, 1)
        stack:SetAlpha((bar.showStacks and not spell.hideStackText) and 1 or 0)
    end
end

------------------------------------------------------------
-- 設定頁的預覽格（圖示類）：同一套字型／顏色／錨點，套在我們自己的 FontString 上
--   cell.cdText     假倒數（冷卻中的格才顯示；增益格一律顯示）
--   cell.chargeText 假充能（技能類）
--   cell.stackText  假層數（增益類）
-- 字是預覽自己寫的（「15」「2」），這裡只管樣式與顯示與否。
------------------------------------------------------------
function T.ApplyPreviewIcon(cell, style, spell)
    local font, outline = style.font, style.outline
    local cdText = cell.cdText
    if cdText then
        local c = style.cooldownText or {}
        SetFont(cdText, c.size or 16, outline, font)
        cdText:SetTextColor(Color(c.color))
        Anchor(cdText, cell, c.point or "CENTER", c.x, c.y)
        cdText:SetAlpha(((cell.onCD or cell.aura) and not spell.hideCooldownText) and 1 or 0)
    end
    local charge = cell.chargeText
    if charge then
        local c = style.chargeText or {}
        SetFont(charge, c.size or 12, outline, font)
        charge:SetTextColor(Color(c.color))
        Anchor(charge, cell, c.point or "BOTTOMRIGHT", c.x, c.y)
        charge:SetAlpha(cell.aura and 0 or 1)
    end
    local stack = cell.stackText
    if stack then
        local c = style.stackText or {}
        SetFont(stack, c.size or 12, outline, font)
        stack:SetTextColor(Color(c.color))
        Anchor(stack, cell, c.point or "TOP", c.x, c.y)
        stack:SetAlpha((cell.aura and not spell.hideStackText) and 1 or 0)
    end
end
