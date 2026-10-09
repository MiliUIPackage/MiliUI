------------------------------------------------------------
-- 時間軸的畫法（直式／橫式）
--
-- 一支 Display 就是一條軸：一條線、刻度、一排會沿著軸滑向「現在」那端的方形圖示。
-- 畫面上的那一條（Screen.lua）跟設定頁的預覽是**同一支程式的兩個實例**，差別只在
-- 資料從哪來（Events.Collect 或 Mock.Collect）—— 所以預覽看到的就是實際長相。
--
-- 軸的座標：p = 剩餘秒數 / window × length。p = 0 是「現在」那一端。
--   直式：flip = false 時「現在」在下面（事件往下掉）；flip = true 在上面
--   橫式：flip = false 時「現在」在左邊（事件往左走）；flip = true 在右邊
-- 兩條靠太近時把後面那條往遠端推（至少隔一個圖示），跟暴雪的 Sorted 軌道同一個想法：
-- 位置稍微不準換到每一條都看得清楚；精確秒數看倒數文字。
--
-- 秘密值：首領事件的名稱、圖示、顏色可能是秘密值，這裡只把它們交給 SetText／SetTexture／
-- SetVertexColor，不比較、不串字。要比較的（剩餘秒數、key、kind）都是明文。
-- 顏色那一步包 pcall：GetEventColor 的回傳整包都可能是秘密，連 .r 都不能取。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local P = ns.P
local O = ns.Owners

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local ALL_ICONS = 1023    -- Constants.EncounterTimelineIconMasks.EncounterTimelineAllIcons
local INDICATORS = 4
local TICK_STEP = 5
local LABEL_STEP = 10
local FADE_IN = 1.5       -- 秒：從遠端滑進來時淡入多久
local NAME_ALLOW = 150    -- 估計名稱最寬多少（只用在預覽的「縮放到放得下」）

ns.Display = {}

local Display = {}
Display.__index = Display

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function Tex(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(WHITE)
    return t
end

local function NewFont(parent, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    -- ⚠ 一定要先有字型才能 SetText（沒字型 SetText 是硬錯）；真正的字型在 Apply 換
    fs:SetFont(ns.Media.Font(), 12, "")
    fs:SetWordWrap(false)
    return fs
end

function ns.Display.New(parent)
    local d = setmetatable({}, Display)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, 1)
    d.frame = f

    d.bg = Tex(f, "BACKGROUND")
    d.line = Tex(f, "BORDER")
    d.now = Tex(f, "BORDER", 1)
    d.ticks, d.tickLabels = {}, {}

    d.pool = {}
    d.items = {}
    d.collect = nil
    d.filter = nil

    -- 只有跑起來的時候才有 OnUpdate
    d.driver = function() d:Render() end
    f:Hide()
    return d
end

local function NewEventFrame(d)
    local f = CreateFrame("Frame", nil, d.frame)
    f:SetFrameLevel(d.frame:GetFrameLevel() + 5)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.edges = {}
    for i = 1, 4 do f.edges[i] = Tex(f, "OVERLAY") end
    f.name = NewFont(f)
    f.cd = NewFont(f)
    f.cd:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.ind = {}
    for i = 1, INDICATORS do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 2)
        f.ind[i] = t
    end
    f:Hide()
    return f
end

------------------------------------------------------------
-- 樣式與版面
------------------------------------------------------------
local function ApplyFont(fs, conf)
    fs:SetFont(ns.Media.Font(conf.font), conf.size or 12, conf.outline or "")
    if conf.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    local c = conf.color
    if c then fs:SetTextColor(c.r, c.g, c.b, c.a or 1) end
end

-- 邊框四條：畫在圖示**裡面**（圖示內縮一條邊的寬度），方框的外緣就是框的外緣
local function LayoutIcon(f, size, conf)
    local px = conf.border and P.Scale(1) or 0
    f:SetSize(size, size)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", px, -px)
    f.icon:SetPoint("BOTTOMRIGHT", -px, px)
    if conf.zoom then
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
    local e = f.edges
    for i = 1, 4 do
        e[i]:ClearAllPoints()
        e[i]:SetShown(conf.border and true or false)
    end
    if conf.border then
        e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
        e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
        e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(px)
        e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(px)
    end
    -- 職責／致命小圖示：右下角往左排
    local isz = math.floor(size * 0.42 + 0.5)
    for i, t in ipairs(f.ind) do
        t:ClearAllPoints()
        t:SetSize(isz, isz)
        t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(i - 1) * isz + 2, -2)
    end
end

local function LayoutName(f, vertical, after)
    local n = f.name
    n:ClearAllPoints()
    if vertical then
        if after then
            n:SetPoint("LEFT", f, "RIGHT", 5, 0)
            n:SetJustifyH("LEFT")
        else
            n:SetPoint("RIGHT", f, "LEFT", -5, 0)
            n:SetJustifyH("RIGHT")
        end
    else
        n:SetJustifyH("CENTER")
        if after then
            n:SetPoint("TOP", f, "BOTTOM", 0, -3)
        else
            n:SetPoint("BOTTOM", f, "TOP", 0, 3)
        end
    end
end

-- settings = db.display；layout = 那個方向的版面；orientation = "vertical"/"horizontal"
function Display:Apply(settings, layout, orientation)
    self.settings, self.layout = settings, layout
    self.vertical = orientation ~= "horizontal"
    local size = layout.iconSize
    local length = layout.length
    local half = size / 2
    local f = self.frame

    if self.vertical then
        f:SetSize(size, length + size)
    else
        f:SetSize(length + size, size)
    end

    -- 底色：整個框再往外留 4px
    local tr = settings.track
    self.bg:ClearAllPoints()
    self.bg:SetPoint("TOPLEFT", -4, 4)
    self.bg:SetPoint("BOTTOMRIGHT", 4, -4)
    self.bg:SetVertexColor(tr.bgColor.r, tr.bgColor.g, tr.bgColor.b, tr.bgColor.a)
    self.bg:SetShown(tr.background and true or false)

    -- 軸線：沿著圖示中心線，從「現在」到最遠端
    local th = P.Scale(math.max(1, tr.thickness or 1))
    local line, now = self.line, self.now
    line:ClearAllPoints()
    now:ClearAllPoints()
    if self.vertical then
        line:SetPoint("TOP", f, "TOP", 0, -half)
        line:SetPoint("BOTTOM", f, "BOTTOM", 0, half)
        line:SetWidth(th)
        now:SetSize(size + 8, th * 2)
        now:SetPoint("CENTER", f, layout.flip and "TOP" or "BOTTOM", 0, layout.flip and -half or half)
    else
        line:SetPoint("LEFT", f, "LEFT", half, 0)
        line:SetPoint("RIGHT", f, "RIGHT", -half, 0)
        line:SetHeight(th)
        now:SetSize(th * 2, size + 8)
        now:SetPoint("CENTER", f, layout.flip and "RIGHT" or "LEFT", layout.flip and -half or half, 0)
    end
    local c = tr.color
    line:SetVertexColor(c.r, c.g, c.b, c.a)
    now:SetVertexColor(c.r, c.g, c.b, math.min(1, (c.a or 1) * 2.5))
    line:SetShown(tr.show and true or false)
    now:SetShown(tr.show and true or false)

    self:LayoutTicks()

    -- 事件框：全部重排一次（之後每幀只動位置）
    local after = layout.textSide ~= "before"
    for _, ef in ipairs(self.pool) do
        self:StyleEventFrame(ef, after)
    end
    self.after = after
end

function Display:StyleEventFrame(ef, after)
    local s, layout = self.settings, self.layout
    LayoutIcon(ef, layout.iconSize, s.icon)
    LayoutName(ef, self.vertical, after)
    ApplyFont(ef.name, s.name)
    ApplyFont(ef.cd, s.countdown)
    ef.name:SetShown(layout.showName and true or false)
    ef.cd:SetShown(s.countdown.show and true or false)
    ef.boundKey = nil     -- 強制重新綁定（顏色、文字都要重套）
    ef.hl = nil
end

function Display:LayoutTicks()
    local s, layout = self.settings, self.layout
    local tr = s.track
    local f = self.frame
    local half = layout.iconSize / 2
    local window, length = layout.window, layout.length
    local count = (tr.show and tr.ticks) and math.floor(window / TICK_STEP) or 0
    local th = P.Scale(1)
    local tickLen = math.floor(layout.iconSize * 0.35 + 0.5)
    local labelAfter = layout.textSide == "before"   -- 刻度數字放在名稱的另一邊
    local c = tr.color
    for i = 1, math.max(count, #self.ticks) do
        local t = self.ticks[i]
        local lbl = self.tickLabels[i]
        if i <= count then
            if not t then
                t = Tex(f, "BORDER", 1)
                self.ticks[i] = t
                lbl = NewFont(f, "ARTWORK")
                self.tickLabels[i] = lbl
            end
            local sec = i * TICK_STEP
            local p = sec / window * length + half
            t:ClearAllPoints()
            lbl:ClearAllPoints()
            if self.vertical then
                t:SetSize(tickLen, th)
                local y = layout.flip and -p or p
                local anchor = layout.flip and "TOP" or "BOTTOM"
                t:SetPoint("CENTER", f, anchor, 0, y)
                if labelAfter then
                    lbl:SetPoint("LEFT", f, anchor, tickLen / 2 + 3, y)
                else
                    lbl:SetPoint("RIGHT", f, anchor, -tickLen / 2 - 3, y)
                end
            else
                t:SetSize(th, tickLen)
                local x = layout.flip and -p or p
                local anchor = layout.flip and "RIGHT" or "LEFT"
                t:SetPoint("CENTER", f, anchor, x, 0)
                if labelAfter then
                    lbl:SetPoint("TOP", f, anchor, x, -tickLen / 2 - 2)
                else
                    lbl:SetPoint("BOTTOM", f, anchor, x, tickLen / 2 + 2)
                end
            end
            t:SetVertexColor(c.r, c.g, c.b, math.min(1, (c.a or 1) * 2))
            t:Show()
            lbl:SetFont(ns.Media.Font(s.countdown.font), 9, "OUTLINE")
            lbl:SetTextColor(1, 1, 1, 0.45)
            if sec % LABEL_STEP == 0 then
                lbl:SetText(sec)
                lbl:Show()
            else
                lbl:Hide()
            end
        elseif t then
            t:Hide()
            lbl:Hide()
        end
    end
end

-- 預覽用：框中心往四個方向各佔多少（含名稱與刻度數字的估計寬度），回傳 left, right, top, bottom
function Display:GetBounds()
    local layout = self.layout
    local w, h = self.frame:GetSize()
    local l, r, t, b = w / 2, w / 2, h / 2, h / 2
    local after = layout.textSide ~= "before"
    if self.vertical then
        local nameW = layout.showName and NAME_ALLOW or 0
        if after then r = r + nameW; l = l + 18 else l = l + nameW; r = r + 18 end
    else
        local nameH = layout.showName and (self.settings.name.size + 6) or 0
        if after then b = b + nameH; t = t + 14 else t = t + nameH; b = b + 14 end
    end
    return l, r, t, b
end

------------------------------------------------------------
-- 資料來源
------------------------------------------------------------
function Display:SetCollector(fn)
    self.collect = fn
end

function Display:SetFilter(fn)
    self.filter = fn
end

function Display:SetRunning(on)
    local f = self.frame
    if on then
        f:SetScript("OnUpdate", self.driver)
        f:Show()
    else
        f:SetScript("OnUpdate", nil)
        f:Hide()
        for _, ef in ipairs(self.pool) do ef:Hide() end
    end
end

------------------------------------------------------------
-- 每幀
------------------------------------------------------------
local function ByRemaining(a, b)
    if a.rem ~= b.rem then return a.rem < b.rem end
    return tostring(a.key) < tostring(b.key)
end

local function FormatRemaining(rem, decimals)
    if rem <= 0 then return "0" end
    if rem >= 60 then return ("%d:%02d"):format(math.floor(rem / 60), math.floor(rem % 60)) end
    if decimals and rem < 3 then return ("%.1f"):format(rem) end
    return tostring(math.ceil(rem))
end

-- 顯示名稱：其他插件加的條前面標出插件名（只有明文名稱才串得起來）
local function DisplayName(it, showOwner)
    if showOwner and it.kind == "other" and it.owner then
        local plain = S.PlainText(it.name)
        if plain then
            return "|cff9d9d9d" .. O.Label(it.owner) .. "|r " .. plain
        end
    end
    return it.name
end

local function SetBorderColor(ef, r, g, b, a)
    for i = 1, 4 do ef.edges[i]:SetVertexColor(r, g, b, a) end
end

local function SetEventBorderColor(ef, color)
    ef.edges[1]:SetVertexColor(color.r, color.g, color.b, 1)
    ef.edges[2]:SetVertexColor(color.r, color.g, color.b, 1)
    ef.edges[3]:SetVertexColor(color.r, color.g, color.b, 1)
    ef.edges[4]:SetVertexColor(color.r, color.g, color.b, 1)
end

function Display:Bind(ef, it)
    local s = self.settings
    ef.boundKey = it.key
    ef.boundOwner = it.owner
    ef.icon:SetTexture(it.icon or 134400)     -- 134400 = 問號
    ef.name:SetText(DisplayName(it, s.name.showOwner))
    ef.cdText = nil
    ef.hl = nil
    -- 職責／致命小圖示：只有真的時間軸事件拿得到（暴雪幫我們把秘密的圖示集合貼上去）
    for _, t in ipairs(ef.ind) do t:SetTexture(nil) end
    if s.icon.indicators and it.id and C_EncounterTimeline.SetEventIconTextures then
        pcall(C_EncounterTimeline.SetEventIconTextures, it.id, ALL_ICONS, ef.ind)
    end
end

-- hl：nil＝還沒套過、true＝快到了、false＝平常
function Display:PaintBorder(ef, it, hl)
    local s = self.settings
    if hl then
        local c = s.highlight.color
        SetBorderColor(ef, c.r, c.g, c.b, c.a or 1)
        local cc = s.highlight.countdownColor
        ef.cd:SetTextColor(cc.r, cc.g, cc.b, cc.a or 1)
        return
    end
    local cc = s.countdown.color
    ef.cd:SetTextColor(cc.r, cc.g, cc.b, cc.a or 1)
    if s.icon.useEventColor and it.color and pcall(SetEventBorderColor, ef, it.color) then
        return
    end
    local c = s.icon.borderColor
    SetBorderColor(ef, c.r, c.g, c.b, c.a or 1)
end

function Display:Render()
    if not self.collect or not self.layout then return end
    local items = self.items
    local n = self.collect(items, self.filter)
    if n > 1 then table.sort(items, ByRemaining) end

    local s, layout = self.settings, self.layout
    local window, length = layout.window, layout.length
    local size = layout.iconSize
    local half = size / 2
    local minGap = size + (layout.spacing or 2)
    local flip, vertical = layout.flip, self.vertical
    local hlTime = s.highlight.time or 0
    local decimals = s.countdown.decimals
    local now = GetTime()
    local f = self.frame

    local used = 0
    local lastP = -math.huge
    for i = 1, n do
        local it = items[i]
        local rem = it.rem
        if rem <= window then
            local p = (rem > 0 and rem or 0) / window * length
            if p < lastP + minGap then p = lastP + minGap end
            if p > length then break end    -- 推到軸外了：後面的都更遠，不畫
            lastP = p

            used = used + 1
            local ef = self.pool[used]
            if not ef then
                ef = NewEventFrame(self)
                self.pool[used] = ef
                self:StyleEventFrame(ef, self.after)
            end
            if ef.boundKey ~= it.key or ef.boundOwner ~= it.owner then
                self:Bind(ef, it)
            end

            -- 位置
            ef:ClearAllPoints()
            local off = half + p
            if vertical then
                if flip then ef:SetPoint("CENTER", f, "TOP", 0, -off)
                else ef:SetPoint("CENTER", f, "BOTTOM", 0, off) end
            else
                if flip then ef:SetPoint("CENTER", f, "RIGHT", -off, 0)
                else ef:SetPoint("CENTER", f, "LEFT", off, 0) end
            end

            -- 狀態：暫停去色、排隊中閃、剛進場淡入、快到了換邊框色
            local hl = (not it.paused) and rem <= hlTime
            if ef.hl ~= hl then
                self:PaintBorder(ef, it, hl)
                ef.hl = hl
            end
            ef.icon:SetDesaturated(it.paused and true or false)
            local alpha = 1
            if it.paused then
                alpha = 0.55
            elseif it.queued then
                alpha = 0.6 + 0.4 * math.abs(math.sin(now * 5))
            elseif rem > window - FADE_IN then
                alpha = (window - rem) / FADE_IN
            end
            ef:SetAlpha(alpha)

            -- 倒數文字：字串一樣就不重設
            local text = FormatRemaining(rem, decimals)
            if ef.cdText ~= text then
                ef.cd:SetText(text)
                ef.cdText = text
            end
            ef:Show()
        end
    end
    for i = used + 1, #self.pool do
        local ef = self.pool[i]
        if ef:IsShown() then
            ef:Hide()
            ef.boundKey = nil
        end
    end
end
