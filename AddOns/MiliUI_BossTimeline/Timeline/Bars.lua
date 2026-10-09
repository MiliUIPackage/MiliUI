------------------------------------------------------------
-- 計時條畫法（Display 的第三種方向）
--
-- 跟 DBM／BigWigs 的計時條同一種讀法：一條一個技能，最快到的排最前面，條身是剩餘時間。
-- 吃同一份資料（Events.Collect / Mock.Collect）、同一份樣式（字型、描邊、顏色、邊框、快到了），
-- 版面另存一份（display.bars）：
--   length    條寬（不含左邊的圖示）
--   iconSize  條高（圖示是正方形，邊長＝條高）
--   window    剩幾秒內的才出條
--   flip      false＝最快到的在最上面、往下排；true＝最快到的在最下面、往上排
--   showName  條上顯示技能名稱
-- 條數上限 MAX_BARS：時間軸上同時十幾條的時候，最遠的那幾條本來就不急。
--
-- 秘密值：名稱、圖示、顏色照舊只往 SetText／SetTexture／SetStatusBarColor 傳；
-- 條的長度用剩餘秒數（明文）餵 StatusBar。
------------------------------------------------------------
local _, ns = ...

local P = ns.P
local Display = ns.Display.Mixin
local H = ns.Display.Helpers

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local MAX_BARS = 8
local FADE_IN = 1.5

local function Edges(f)
    local e = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(WHITE)
        e[i] = t
    end
    return e
end

local function LayoutEdges(e, f, on)
    local px = P.Scale(1)
    for i = 1, 4 do
        e[i]:ClearAllPoints()
        e[i]:SetShown(on)
    end
    if not on then return end
    e[1]:SetPoint("TOPLEFT", f); e[1]:SetPoint("TOPRIGHT", f); e[1]:SetHeight(px)
    e[2]:SetPoint("BOTTOMLEFT", f); e[2]:SetPoint("BOTTOMRIGHT", f); e[2]:SetHeight(px)
    e[3]:SetPoint("TOPLEFT", f); e[3]:SetPoint("BOTTOMLEFT", f); e[3]:SetWidth(px)
    e[4]:SetPoint("TOPRIGHT", f); e[4]:SetPoint("BOTTOMRIGHT", f); e[4]:SetWidth(px)
end

local function NewBar(d)
    local b = CreateFrame("Frame", nil, d.frame)
    b:SetFrameLevel(d.frame:GetFrameLevel() + 5)
    -- 圖示：沿用時間軸的圖示框（方框＋邊）
    b.iconFrame = CreateFrame("Frame", nil, b)
    b.iconFrame.icon = b.iconFrame:CreateTexture(nil, "ARTWORK")
    b.iconFrame.edges = Edges(b.iconFrame)
    b.iconFrame.ind = {}
    -- 條身
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bg = b.bar:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(WHITE)
    b.edges = Edges(b.bar)
    b.name = H.NewFont(b.bar)
    b.cd = H.NewFont(b.bar)
    b:Hide()
    return b
end

function Display:StyleBar(b)
    local s, layout = self.settings, self.layout
    local h, w = layout.iconSize, layout.length
    b:SetSize(h + w, h)
    local ic = b.iconFrame
    ic:ClearAllPoints()
    ic:SetPoint("LEFT", b, "LEFT", 0, 0)
    H.LayoutIcon(ic, h, s.icon)
    b.bar:ClearAllPoints()
    b.bar:SetPoint("TOPLEFT", ic, "TOPRIGHT", P.Scale(1), 0)
    b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.bar:SetStatusBarTexture(ns.Media.BarTexture(s.bar.texture))
    local c, bg = s.bar.color, s.bar.bgColor
    b.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    b.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 1)
    LayoutEdges(b.edges, b.bar, s.icon.border and true or false)
    H.ApplyFont(b.name, s.name)
    H.ApplyFont(b.cd, s.countdown)
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b.bar, "LEFT", 4, 0)
    b.name:SetPoint("RIGHT", b.cd, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.cd:ClearAllPoints()
    b.cd:SetPoint("RIGHT", b.bar, "RIGHT", -4, 0)
    b.name:SetShown(layout.showName and true or false)
    b.cd:SetShown(s.countdown.show and true or false)
    b.boundKey, b.hl = nil, nil
end

function Display:ApplyBars()
    local layout = self.layout
    local h = layout.iconSize
    local spacing = layout.spacing or 2
    self.frame:SetSize(h + layout.length, MAX_BARS * h + (MAX_BARS - 1) * spacing)
    local tr = self.settings.track
    self.bg:ClearAllPoints()
    self.bg:SetPoint("TOPLEFT", -4, 4)
    self.bg:SetPoint("BOTTOMRIGHT", 4, -4)
    self.bg:SetVertexColor(tr.bgColor.r, tr.bgColor.g, tr.bgColor.b, tr.bgColor.a)
    self.bg:SetShown(tr.background and true or false)
    self.barPool = self.barPool or {}
    for _, b in ipairs(self.barPool) do self:StyleBar(b) end
end

local function PaintBar(self, b, it, hl)
    local s = self.settings
    local border = hl and s.highlight.color or s.icon.borderColor
    for _, e in ipairs({ b.edges, b.iconFrame.edges }) do
        for i = 1, 4 do e[i]:SetVertexColor(border.r, border.g, border.b, border.a or 1) end
    end
    local cc = hl and s.highlight.countdownColor or s.countdown.color
    b.cd:SetTextColor(cc.r, cc.g, cc.b, cc.a or 1)
    -- 條身顏色：技能在時間軸上的顏色（玩家或 DBM 設的）優先，沒有就用計時條顏色
    local c = s.bar.color
    if not (s.icon.useEventColor and it.color and pcall(b.bar.SetStatusBarColor, b.bar, it.color.r, it.color.g, it.color.b, 1)) then
        b.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    end
end

function Display:RenderBars()
    local items = self.items
    local n = self.collect(items, self.filter)
    if n > 1 then table.sort(items, H.ByRemaining) end
    local s, layout = self.settings, self.layout
    local window = layout.window
    local h = layout.iconSize
    local step = h + (layout.spacing or 2)
    local hlTime = s.highlight.time or 0
    local now = GetTime()
    local f = self.frame
    local pool = self.barPool

    local used = 0
    for i = 1, n do
        local it = items[i]
        local rem = it.rem
        if rem > window then break end
        if used >= MAX_BARS then break end
        used = used + 1
        local b = pool[used]
        if not b then
            b = NewBar(self)
            pool[used] = b
            self:StyleBar(b)
        end
        if b.boundKey ~= it.key or b.boundOwner ~= it.owner then
            b.boundKey, b.boundOwner = it.key, it.owner
            b.iconFrame.icon:SetTexture(it.icon or 134400)
            b.name:SetText(H.DisplayName(it, s.name.showOwner))
            b.bar:SetMinMaxValues(0, window)
            b.cdText, b.hl = nil, nil
        end
        b:ClearAllPoints()
        local off = (used - 1) * step
        if layout.flip then
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, off)
        else
            b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -off)
        end
        b.bar:SetValue(rem > 0 and rem or 0)

        local hl = (not it.paused) and rem <= hlTime
        if b.hl ~= hl then
            PaintBar(self, b, it, hl)
            b.hl = hl
        end
        b.iconFrame.icon:SetDesaturated(it.paused and true or false)
        local alpha = 1
        if it.paused then
            alpha = 0.55
        elseif it.queued then
            alpha = 0.6 + 0.4 * math.abs(math.sin(now * 5))
        elseif rem > window - FADE_IN then
            alpha = (window - rem) / FADE_IN
        end
        b:SetAlpha(alpha)
        local text = H.FormatRemaining(rem, s.countdown.decimals)
        if b.cdText ~= text then
            b.cd:SetText(text)
            b.cdText = text
        end
        b:Show()
    end
    for i = used + 1, #pool do
        if pool[i]:IsShown() then
            pool[i]:Hide()
            pool[i].boundKey = nil
        end
    end
end
