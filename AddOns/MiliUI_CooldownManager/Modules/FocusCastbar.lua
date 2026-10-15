------------------------------------------------------------
-- 專注目標施法條（獨立 HUD，容器 MiliUICDM_Bar_focuscast）
--
-- 專注目標在唱什麼。做法照套組的專注目標助手那條施法條，引擎（框、秘密模式、版面）照玩家施法條
-- （Modules/Castbar.lua）那一套；兩條刻意分開寫：玩家那條有刻度／延遲／蓄力／隱藏暴雪條，這條沒有，
-- 這條多的是「我能不能斷」三態上色、重要法術發光與「!」、被打斷時印斷法者。
-- 純函式（時間文字、截字、材質）直接用 ns.Castbar 的。
--
-- 12.1 鐵律（跟玩家施法條同一套，勿改）：
--   * 秘密模式：起訖時間是秘密值 → UnitCastingDuration 等 duration 物件餵 SetTimerDuration，
--     不掛每幀 OnUpdate，改 10Hz ticker（時間文字＋顏色）
--   * GetTotalDuration() 可能回秘密數字，落地前必 issecretvalue 檢查
--   * notInterruptible、我方斷法是否就緒都是秘密布林，永不 if，只餵 EvaluateColorValueFromBoolean
--   * 重要不重要（C_Spell.IsSpellImportant）也是秘密布林：發光永遠開著、掛在自己的宿主框上，
--     秘密布林只餵宿主的 SetAlphaFromBoolean；「!」版的名字另一顆 FontString，兩顆 alpha 互補
--   * 名字／圖示可能是秘密值：只交給 SetText／SetTexture，不比較、不截字（CB.Truncate 會原樣回）
--   * 斷法者 GUID 只比 nil；職業是秘密字串就不上色（秘密值不能當 table key、SetTextColor 不收秘密值）
--   * 事件處理器只轉手 ns.Defer
--
-- 專注目標換了（PLAYER_FOCUS_CHANGED）：新的專注目標正在唱就直接接上，沒在唱就收條。
-- 音效留在專注目標助手（那邊獨立於施法條開關；12.1 起音效不能依斷法狀態挑，這裡不另做一份）。
--
-- 跟玩家施法條分得開的兩樣（使用者 2026-10-16 指定，不靠顏色也認得出這不是自己的條）：
--   * 法術名前面印施法者的名字「張三：治療鍊」（showCaster）。UnitName("focus") 受限內容是秘密字串：只串接、只交給 SetText
--   * 條尾（圖示的對邊）一顆自己的斷法技能圖示＋冷卻轉圈（showKick）：圖示是自己的法術（明文），冷卻餵
--     GetSpellCooldownDuration(id, true) 的 duration 物件給自己的 Cooldown 框（SetCooldownFromDurationObject，秘密值下照樣成立），
--     圖示 alpha 餵 IsZero() 的布林（就緒亮、冷卻中暗）。沒有斷法的專精不畫、不佔寬
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.FocusCastbar = {}
local FC = ns.FocusCastbar

local IsSecret = ns.IsSecret
local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local LCG = ns.MiliUIGlow

local KEY = "focuscast"
local UNIT = "focus"
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local FADE_TIME = 0.3
local INTERRUPT_HOLD = 1.0           -- 打斷停留：要讀得到斷法者的名字（玩家施法條是 0.4）
local PREVIEW_TIME = 10
local PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_TimeStop"

local function Plain(v)
    if type(v) ~= "number" or IsSecret(v) then return nil end
    return v
end

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
FC.Cfg = Cfg

-- 玩家施法條的純函式
local function CB() return ns.Castbar end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, f, ev

-- 施法狀態：castState 1 施法、2 引導、3 淡出、4 打斷停留；nil ＝ 閒置
local S = { displayToken = 0 }
FC.state = S

local function Width(cfg)
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = ns.Bars and ns.Bars.AutoWidth and ns.Bars.AutoWidth(KEY) or 0
        if w <= 0 then w = 200 end
    end
    return w
end
FC.Width = Width

local function MinSize()
    local cfg = Cfg() or {}
    return Width(cfg), tonumber(cfg.height) or 20
end

-- 斷法圖示要不要畫：開關開著、而且這個專精有斷法（Modules/Interrupt.lua 挑的那顆）
local function KickSpell(cfg)
    if (cfg or Cfg() or {}).showKick == false then return nil end
    local I = ns.Interrupt
    return I and I.SpellID and I.SpellID() or nil
end
FC.KickSpell = KickSpell

local function C4(c, dr, dg, db, da)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b, c.a or da end
    return dr, dg, db, da
end

local function Build()
    f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)

    f.iconFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.barHolder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.bgTex = f.barHolder:CreateTexture(nil, "BACKGROUND")
    f.bgTex:SetTexture(SOLID)
    f.bar = CreateFrame("StatusBar", nil, f.barHolder)
    f.bar:SetStatusBarTexture(SOLID)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:Hide()

    -- 條尾的斷法圖示（圖示的對邊）：邊框＋圖示＋冷卻轉圈（不畫數字、不畫邊緣線、不畫閃光）
    f.kickFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.kickIcon = f.kickFrame:CreateTexture(nil, "ARTWORK")
    f.kickIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local okCD, kcd = pcall(CreateFrame, "Cooldown", nil, f.kickFrame, "CooldownFrameTemplate")
    if okCD and kcd then
        if kcd.SetDrawBling then kcd:SetDrawBling(false) end
        if kcd.SetDrawEdge then kcd:SetDrawEdge(false) end
        if kcd.SetHideCountdownNumbers then kcd:SetHideCountdownNumbers(true) end
        kcd:EnableMouse(false)
        f.kickCD = kcd
    end
    f.kickFrame:Hide()

    f.textFrame = CreateFrame("Frame", nil, f)
    f.textFrame:SetAllPoints(f.barHolder)
    -- ⚠ 先給字型才能 SetText
    f.nameText = f.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(f.nameText, 12, "OUTLINE")
    f.nameText:SetJustifyH("LEFT")
    f.nameText:SetWordWrap(false)
    -- 重要法術版的名字（前面加「!」）疊在同一個位置：是不是重要是秘密布林，不能在 Lua 挑要寫哪段字，
    -- 兩段都寫好、交給 SetAlphaFromBoolean 二選一
    f.bangText = f.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(f.bangText, 12, "OUTLINE")
    f.bangText:SetJustifyH("LEFT")
    f.bangText:SetWordWrap(false)
    f.bangText:SetAlpha(0)
    f.timeText = f.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(f.timeText, 12, "OUTLINE")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetWordWrap(false)

    f.glowHosts = {}
    f:Hide()
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
function FC.Layout()
    if not f then return end
    local cfg = Cfg() or {}
    local W, H = Width(cfg), tonumber(cfg.height) or 20
    W, H = ns.P.Scale(W), ns.P.Scale(H)
    ns.Bars.SetPanelSize(KEY, W, H)

    local showIcon = cfg.showIcon ~= false
    local iconW = showIcon and H or 0
    local gap = showIcon and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    local left = cfg.iconSide ~= "RIGHT"
    f.iconFrame:SetShown(showIcon)
    f.iconFrame:ClearAllPoints()
    f.iconFrame:SetSize(iconW > 0 and iconW or 1, H)
    f.iconFrame:SetPoint(left and "TOPLEFT" or "TOPRIGHT", f, left and "TOPLEFT" or "TOPRIGHT", 0, 0)
    local edge = ns.P.Pixel(1)
    f.iconFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    f.iconFrame:SetBackdropColor(0, 0, 0, 1)
    f.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f.iconFrame, "TOPLEFT", edge, -edge)
    f.icon:SetPoint("BOTTOMRIGHT", f.iconFrame, "BOTTOMRIGHT", -edge, edge)

    -- 斷法圖示在圖示的對邊（圖示左 ⇒ 斷法右），跟圖示同大小、同間距；沒有斷法就不佔寬
    local kickID = KickSpell(cfg)
    local kickW = kickID and H or 0
    local kickGap = kickID and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    f.kickFrame:SetShown(kickID ~= nil)
    f.kickFrame:ClearAllPoints()
    f.kickFrame:SetSize(kickW > 0 and kickW or 1, H)
    f.kickFrame:SetPoint(left and "TOPRIGHT" or "TOPLEFT", f, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
    f.kickFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    f.kickFrame:SetBackdropColor(0, 0, 0, 1)
    f.kickFrame:SetBackdropBorderColor(0, 0, 0, 1)
    f.kickIcon:ClearAllPoints()
    f.kickIcon:SetPoint("TOPLEFT", f.kickFrame, "TOPLEFT", edge, -edge)
    f.kickIcon:SetPoint("BOTTOMRIGHT", f.kickFrame, "BOTTOMRIGHT", -edge, edge)
    if f.kickCD then
        f.kickCD:ClearAllPoints()
        f.kickCD:SetAllPoints(f.kickIcon)
        if f.kickCD.SetSwipeColor then
            f.kickCD:SetSwipeColor(C4(ns.Setting("theme", "icon.swipeColor"), 0, 0, 0, 0.8))
        end
    end

    local barW = W - iconW - gap - kickW - kickGap
    if barW < 4 then barW = 4 end
    f.barHolder:ClearAllPoints()
    f.barHolder:SetSize(barW, H)
    f.barHolder:SetPoint(left and "TOPRIGHT" or "TOPLEFT", f.kickFrame, left and "TOPLEFT" or "TOPRIGHT", left and -kickGap or kickGap, 0)
    local inset = ns.Media.BorderInset(1)
    f.barHolder:SetBackdrop({ edgeFile = SOLID, edgeSize = inset })
    f.barHolder:SetBackdropBorderColor(0, 0, 0, 1)
    f.bgTex:ClearAllPoints()
    f.bgTex:SetPoint("TOPLEFT", f.barHolder, "TOPLEFT", inset, -inset)
    f.bgTex:SetPoint("BOTTOMRIGHT", f.barHolder, "BOTTOMRIGHT", -inset, inset)
    local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    f.bgTex:SetVertexColor(bg.r or 0.1, bg.g or 0.1, bg.b or 0.1, bg.a or 0.8)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f.barHolder, "TOPLEFT", inset, -inset)
    f.bar:SetPoint("BOTTOMRIGHT", f.barHolder, "BOTTOMRIGHT", -inset, inset)
    CB().SetFillTexture(f.bar, cfg.texture)
    S.reversed = ns.FillReversed(cfg)
    f.bar:SetReverseFill(S.reversed)

    -- 層級：底 L → 條 L+1 → 文字 L+3；圖示 L+1；發光宿主 L+20（GlowHost）
    local lvl = f:GetFrameLevel()
    f.barHolder:SetFrameLevel(lvl)
    f.bar:SetFrameLevel(lvl + 1)
    f.textFrame:SetFrameLevel(lvl + 3)
    f.iconFrame:SetFrameLevel(lvl + 1)
    f.kickFrame:SetFrameLevel(lvl + 1)

    local general = ns.Setting(nil, "font")
    local outline = ns.Media.ThemeOutline()
    local nameFont = ns.Media.ElementFont(cfg.font, general)
    local nameSize = tonumber(cfg.textSize) or 12
    ns.Media.SetFont(f.nameText, nameSize, outline, nameFont)
    ns.Media.SetFont(f.bangText, nameSize, outline, nameFont)
    ns.Media.SetFont(f.timeText, tonumber(cfg.timeTextSize) or 12, outline, ns.Media.ElementFont(cfg.timeFont, general))
    local no = type(cfg.nameOffset) == "table" and cfg.nameOffset or {}
    local to = type(cfg.timeOffset) == "table" and cfg.timeOffset or {}
    f.timeText:ClearAllPoints()
    f.timeText:SetPoint("RIGHT", f.textFrame, "RIGHT", tonumber(to.x) or -4, tonumber(to.y) or 0)
    f.nameText:ClearAllPoints()
    f.nameText:SetPoint("LEFT", f.textFrame, "LEFT", tonumber(no.x) or 4, tonumber(no.y) or 0)
    f.nameText:SetPoint("RIGHT", f.timeText, "LEFT", -4, 0)
    f.bangText:ClearAllPoints()
    f.bangText:SetAllPoints(f.nameText)
    local showName = cfg.showName ~= false
    f.nameText:SetShown(showName)
    f.bangText:SetShown(showName)
    f.timeText:SetShown(cfg.showTime ~= false)

    f.spark:SetSize(10, H * 2.2)
    f.spark:ClearAllPoints()
    local tex = f.bar:GetStatusBarTexture()
    if tex then f.spark:SetPoint("CENTER", tex, S.reversed and "LEFT" or "RIGHT", 0, 0) end
    f.spark:SetShown(cfg.showSpark ~= false and S.castState ~= nil and S.castState ~= 3 and S.castState ~= 4)
end

------------------------------------------------------------
-- 顏色：可斷法（斷法就緒）／可斷法（斷法冷卻中）／不可中斷
--   cd 起底 → 我方斷法就緒（Modules/Interrupt.lua，可能是秘密布林）蓋成 ready → 不可打斷蓋成 immune
------------------------------------------------------------
local function Colors()
    local cfg = Cfg()
    return cfg and cfg.colors or {}
end

local function C(c, dr, dg, db)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return dr, dg, db
end

local function EvalTriple(cond, col, r, g, b)
    local cr, cg, cb = C(col, r, g, b)
    return Eval(cond, cr, r), Eval(cond, cg, g), Eval(cond, cb, b)
end

-- 曲線串接的保險：第一次被擋就永久放掉斷法就緒色，保住「不可打斷灰」
local chainOK = true

local function ApplyColor()
    local tex = f.bar:GetStatusBarTexture()
    if not tex then return end
    local c = Colors()
    local br, bg, bb = C(c.cd, 0.906, 0.424, 0.2)
    local r, g, b = br, bg, bb
    local tinted = false
    if chainOK and ns.Interrupt then
        local ready, has = ns.Interrupt.IsReady()
        if has then
            if IsSecret(ready) then
                if Eval then
                    local ok, rr, gg, b2 = pcall(EvalTriple, ready, c.ready, r, g, b)
                    if ok then r, g, b = rr, gg, b2; tinted = true end
                end
            elseif ready then
                r, g, b = C(c.ready, 1, 0.741, 0)
            end
        end
    end
    local ni = S.castNotInterruptible
    if ni ~= nil then
        if IsSecret(ni) then
            if Eval then
                local ok, rr, gg, b2 = pcall(EvalTriple, ni, c.immune, r, g, b)
                if ok then
                    r, g, b = rr, gg, b2
                elseif tinted then
                    chainOK = false
                    r, g, b = EvalTriple(ni, c.immune, br, bg, bb)
                end
            end
        elseif ni then
            r, g, b = C(c.immune, 0.529, 0.529, 0.529)
        end
    end
    tex:SetVertexColor(r, g, b, 1)
end

------------------------------------------------------------
-- 重要法術發光
--
-- 判定是暴雪的 C_Spell.IsSpellImportant(spellID)，不維護法術清單。受限內容裡 spellID 與回傳值都是秘密值，
-- 這裡只當傳遞者：發光照開，SetAlphaFromBoolean 交給引擎決定看不看得到。
-- 發光一律掛在自己的宿主框（glowHosts[style]）上：發光引擎內部會自己 SetAlpha（動畫），
-- 掛在宿主上才不會互相蓋掉，也不會讀回秘密 alpha 做算術。施法一結束就停掉，不讓 driver 對看不見的發光空轉。
------------------------------------------------------------
local GLOW_STYLES = { pixel = true, autocast = true, proc = true }
local IsSpellImportant = C_Spell and C_Spell.IsSpellImportant

local function GlowStyle()
    local st = (Cfg() or {}).glowStyle
    return GLOW_STYLES[st] and st or "pixel"
end

local function GlowHost(style)
    local host = f.glowHosts[style]
    if host then return host end
    local target = (style == "proc") and f.iconFrame or f
    host = CreateFrame("Frame", nil, target)
    host:SetAllPoints(target)
    host:SetFrameLevel(f:GetFrameLevel() + 20)
    f.glowHosts[style] = host
    return host
end

local function StopGlow()
    if not (f and S.glowShown and LCG) then S.glowShown = nil return end
    local host = f.glowHosts[S.glowShown]
    if host then
        if S.glowShown == "pixel" then
            pcall(LCG.PixelGlow_Stop, host)
        elseif S.glowShown == "autocast" then
            pcall(LCG.AutoCastGlow_Stop, host)
        else
            pcall(LCG.ProcGlow_Stop, host)
        end
    end
    S.glowShown = nil
end

-- important：明文或秘密布林；nil ＝ 不問直接亮（預覽）
local function ShowGlow(important)
    local cfg = Cfg() or {}
    if not cfg.glowImportant or not LCG then StopGlow() return end
    local style = GlowStyle()
    if S.glowShown ~= style then
        StopGlow()
        local host = GlowHost(style)
        local cr, cg, cb = C(Colors().glow, 0.95, 0.95, 0.32)
        local color = { cr, cg, cb, 1 }
        local ok
        if style == "pixel" then
            -- 2px、往外推 1px：蓋住條本身的 1px 黑邊再多出去 1px。border=false：條自己有底
            ok = pcall(LCG.PixelGlow_Start, host, color, 8, 0.25, nil, 2, 1, 1, false)
        elseif style == "autocast" then
            ok = pcall(LCG.AutoCastGlow_Start, host, color, 6, 0.125, 1.2, 1, 1)
        else
            ok = pcall(LCG.ProcGlow_Start, host, { color = color })
        end
        if not ok then return end
        S.glowShown = style
    end
    local host = f.glowHosts[style]
    if important == nil then
        host:SetAlpha(1)
    else
        host:SetAlphaFromBoolean(important, 1, 0)
    end
end

-- spellID 可能是秘密值：只比 nil、原封不動交給 C 端。回傳 nil ＝ 判斷不了（不發光、不加「!」）
local function QueryImportant(spellID)
    if spellID == nil or not IsSpellImportant then return nil end
    local ok, v = pcall(IsSpellImportant, spellID)
    if ok and v ~= nil then return v end
    return nil
end

-- 顯示的名字（純函式）：施法者名字 ＋ 分隔 ＋ 法術名（截字只截法術名；兩段都可能是秘密字串，只串接）
function FC.DisplayName(caster, spell, showCaster, maxChars)
    local shown = CB().Truncate(spell, maxChars) or ""
    if showCaster ~= false and caster ~= nil then
        return caster .. L[": "] .. shown
    end
    return shown
end

-- 名字：important ＝ 明文或秘密布林，nil ＝ 不標。caster ＝ 施法者名字（nil ＝ 不印）。都可能是秘密字串：只串接、只交給 SetText
local function SetName(name, important, caster)
    local cfg = Cfg() or {}
    local shown = FC.DisplayName(caster, name, cfg.showCaster, cfg.nameMaxChars)
    f.nameText:SetText(shown)
    if important == nil or not cfg.bangImportant then
        f.bangText:SetAlpha(0)
        f.nameText:SetAlpha(1)
        return
    end
    local cr, cg, cb = C(Colors().glow, 0.95, 0.95, 0.32)
    f.bangText:SetText(string.format("|cff%02x%02x%02x!|r ", cr * 255, cg * 255, cb * 255) .. shown)
    f.bangText:SetAlphaFromBoolean(important, 1, 0)
    f.nameText:SetAlphaFromBoolean(important, 0, 1)
end

------------------------------------------------------------
-- 顯示流程
------------------------------------------------------------
local function SetTimeText(text)
    if S.lastTime == text then return end
    S.lastTime = text
    f.timeText:SetText(text)
end

local function ShowSpark()
    f.spark:SetShown((Cfg() or {}).showSpark ~= false)
end

-- 斷法圖示：圖示（自己的法術，明文）、冷卻轉圈（duration 物件原封轉交）、就緒亮／冷卻中暗（IsZero 的布林只餵 alpha）。
-- 餵不進去就 Clear（圖示留著）。開唱、SPELL_UPDATE_COOLDOWN（條顯示中）、預覽、套用設定時叫
local function UpdateKick()
    if not (f and f.kickFrame:IsShown()) then return end
    local id = KickSpell()
    if not id then return end
    local getTex = C_Spell and C_Spell.GetSpellTexture
    if getTex then
        local ok, tex = pcall(getTex, id)
        if ok and tex ~= nil then f.kickIcon:SetTexture(tex) end
    end
    local dur
    local getDur = C_Spell and C_Spell.GetSpellCooldownDuration
    if getDur then
        local ok, d = pcall(getDur, id, true)
        if ok and d then dur = d end
    end
    local cd = f.kickCD
    if cd then
        local fed = false
        if dur and cd.SetCooldownFromDurationObject then
            fed = pcall(cd.SetCooldownFromDurationObject, cd, dur, true)
        end
        if not fed and cd.Clear then pcall(cd.Clear, cd) end
    end
    local zero
    if dur and dur.IsZero then
        local ok, z = pcall(dur.IsZero, dur)
        if ok then zero = z end
    end
    if zero == nil then
        f.kickIcon:SetAlpha(1)
    elseif IsSecret(zero) then
        if not pcall(f.kickIcon.SetAlphaFromBoolean, f.kickIcon, zero, 1, 0.55) then f.kickIcon:SetAlpha(1) end
    else
        f.kickIcon:SetAlpha(zero and 1 or 0.55)
    end
end
FC.UpdateKick = UpdateKick

local function HideBar()
    local wasPreview = S.preview
    S.active = false
    S.castState = nil
    S.preview = false
    S.displayToken = S.displayToken + 1
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    f.spark:Hide()
    f:SetAlpha(1)
    StopGlow()
    S.lastTime = nil
    S.tStart, S.tEnd, S.total = nil, nil, 0
    S.castChannel, S.castSecret, S.castNotInterruptible = false, false, nil
    local cfg = Cfg() or {}
    if cfg.hideWhenNotCasting ~= false then
        f:Hide()
    else
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(0)
        f.nameText:SetText("")
        f.nameText:SetAlpha(1)
        f.bangText:SetAlpha(0)
        f.timeText:SetText("")
        f.icon:SetTexture(nil)
        f:Show()
        UpdateKick()
    end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
    if wasPreview and ns.Fire then ns.Fire("FocusCastPreview", false) end
end
FC.HideBar = function() if f then HideBar() end end

local function FadeOnUpdate(self)
    local t = GetTime() - (S.fadeStart or 0)
    if t >= FADE_TIME then
        HideBar()
    else
        self:SetAlpha(1 - t / FADE_TIME)
    end
end

local function EndFade()
    S.active = false
    S.castState = 3
    S.fadeStart = GetTime()
    S.displayToken = S.displayToken + 1
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f.spark:Hide()
    StopGlow()
    f.timeText:SetText("")
    f:SetScript("OnUpdate", FadeOnUpdate)
    f:Show()
end

-- 被打斷：凍結滿條變紅、名字換「已打斷」、右側印斷法者（職業色），停留後淡出。
-- interrupterGUID 只比 nil；名字可能是秘密字串（SetText 收得下）；職業是秘密字串就維持白字
local function ShowInterrupted(interrupterGUID)
    S.active = false
    S.castState = 4
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    f.spark:Hide()
    StopGlow()                                 -- 施法已經斷了，紅條不再標重要
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    local tex = f.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(C(Colors().interrupted, 1, 0.204, 0.145)) end
    SetName(L["Interrupted"], nil)
    f.timeText:SetText("")
    if interrupterGUID ~= nil and (Cfg() or {}).showInterrupter ~= false then
        local name, class
        if UnitNameFromGUID then
            local ok, n = pcall(UnitNameFromGUID, interrupterGUID)
            if ok then name = n end
            if GetPlayerInfoByGUID then
                local ok2, _, c = pcall(GetPlayerInfoByGUID, interrupterGUID)
                if ok2 then class = c end
            end
        elseif UnitTokenFromGUID then
            local ok, u = pcall(UnitTokenFromGUID, interrupterGUID)
            if ok and u ~= nil and not IsSecret(u) then
                name = UnitName(u)
                class = UnitClassBase and UnitClassBase(u) or nil
            end
        end
        if name ~= nil then
            local r, g, b = 1, 1, 1
            if class ~= nil and not IsSecret(class) then
                local color = C_ClassColor and C_ClassColor.GetClassColor(class)
                    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if color then r, g, b = color:GetRGB() end
            end
            f.timeText:SetTextColor(r, g, b)
            f.timeText:SetText(name)
        end
    end
    S.displayToken = S.displayToken + 1
    local tok = S.displayToken
    C_Timer.After(INTERRUPT_HOLD, function()
        if tok ~= S.displayToken then return end
        EndFade()
    end)
end

local function Elapsed(now)
    if S.tStart then return now - S.tStart end
    return now - (S.localStart or now)
end

local function SecretTick()
    if not (S.active and S.castSecret) then
        if S.ticker then S.ticker:Cancel(); S.ticker = nil end
        return
    end
    local now = GetTime()
    local elapsed = Elapsed(now)
    if S.total > 0 then
        if elapsed > S.total + 0.3 then HideBar() return end      -- STOP 事件漏掉也會收條
    else
        if UnitCastingInfo(UNIT) == nil and UnitChannelInfo(UNIT) == nil then HideBar() return end
    end
    SetTimeText(CB().FormatTime((Cfg() or {}).timeFormat, elapsed, S.total))
    ApplyColor()
end

local function PlainOnUpdate(self, dt)
    if not S.active then HideBar() return end
    local now = GetTime()
    local total = (S.tEnd or 0) - (S.tStart or 0)
    if total <= 0 or now >= S.tEnd then
        if S.preview then EndFade() else HideBar() end
        return
    end
    local ratio
    if S.castChannel then
        ratio = (S.tEnd - now) / total
    else
        ratio = (now - S.tStart) / total
    end
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    self.bar:SetValue(ratio)
    S.textAccum = (S.textAccum or 1) + (dt or 0)
    if S.textAccum >= 0.05 then
        S.textAccum = 0
        SetTimeText(CB().FormatTime((Cfg() or {}).timeFormat, now - S.tStart, total))
        ApplyColor()                          -- 我方斷法冷卻會變
    end
end

local function StartDisplay()
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then return end
    local cName, _, cTex, cS4, cS5, _, _, cNotInt, cSpellID = UnitCastingInfo(UNIT)
    local isCast = cName ~= nil
    local hName, hTex, hS4, hS5, hNotInt, hSpellID, hEmp
    if not isCast then
        local n, _, tex, s4, s5, _, ni, sid, emp = UnitChannelInfo(UNIT)
        hName, hTex, hS4, hS5, hNotInt, hSpellID, hEmp = n, tex, s4, s5, ni, sid, emp
    end
    local isChannel = (not isCast) and (hName ~= nil)
    if not (isCast or isChannel) then
        if not S.preview then HideBar() end
        return
    end

    local name, texture, notInt, s4, s5, isEmpowered, spellID
    if isCast then
        name, texture, notInt, s4, s5, spellID, isEmpowered = cName, cTex, cNotInt, cS4, cS5, cSpellID, false
    else
        name, texture, notInt, s4, s5, spellID = hName, hTex, hNotInt, hS4, hS5, hSpellID
        isEmpowered = (hEmp ~= nil and not IsSecret(hEmp) and hEmp) and true or false
    end

    local wasPreview = S.preview
    S.preview = false
    S.displayToken = S.displayToken + 1
    S.castChannel = isChannel
    S.castEmpowered = isEmpowered
    S.castState = isChannel and 2 or 1
    S.castNotInterruptible = notInt
    S.lastTime = nil
    f:SetScript("OnUpdate", nil)
    f:SetAlpha(1)
    f.icon:SetTexture(texture)
    f.timeText:SetTextColor(1, 1, 1)          -- 打斷顯示會把右側文字染職業色，這裡還原
    local important = QueryImportant(spellID)
    local caster = UnitName(UNIT)              -- 可能是秘密字串：只串接
    SetName(name, important, caster)
    if important == nil then StopGlow() else ShowGlow(important) end
    f.timeText:SetText("")
    UpdateKick()

    local ps, pe = Plain(s4), Plain(s5)
    S.tStart = ps and ps / 1000 or nil
    S.tEnd = pe and pe / 1000 or nil
    S.total = (S.tStart and S.tEnd) and (S.tEnd - S.tStart) or 0

    if CB().SecretsActive() then
        S.castSecret = true
        S.localStart = GetTime()
        local dur
        if isChannel then
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(UNIT, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(UNIT)
            end
        elseif UnitCastingDuration then
            dur = UnitCastingDuration(UNIT)
        end
        f.bar:SetMinMaxValues(0, 1)
        if dur and f.bar.SetTimerDuration then
            if S.total <= 0 and dur.GetTotalDuration then
                local ok, total = pcall(dur.GetTotalDuration, dur)
                if ok and Plain(total) then S.total = total end
            end
            f.bar:SetTimerDuration(dur, nil, CB().TimerDir(isChannel, isEmpowered))
        else
            f.bar:SetValue(1)
        end
        S.active = true
        ApplyColor()
        if not S.ticker then
            S.ticker = C_Timer.NewTicker(0.1, SecretTick)
        end
    else
        S.castSecret = false
        if S.ticker then S.ticker:Cancel(); S.ticker = nil end
        if not (S.tStart and S.tEnd) then
            HideBar()
            return
        end
        ApplyColor()
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(isChannel and 1 or 0)
        S.textAccum = 1
        S.active = true
        f:SetScript("OnUpdate", PlainOnUpdate)
    end
    ShowSpark()
    f:Show()
    if ns.Visibility then ns.Visibility.Apply(KEY) end
    if wasPreview and ns.Fire then ns.Fire("FocusCastPreview", false) end
end

-- 延遲／推條：只重設計時來源，不重讀圖示／名稱（文字不跳）
local function ResyncTiming()
    if not S.active then return end
    local s4, s5
    if S.castSecret then
        local castName = UnitCastingInfo(UNIT)
        local dur, isChannel, isEmpowered
        if castName ~= nil then
            isChannel, isEmpowered = false, false
            if UnitCastingDuration then dur = UnitCastingDuration(UNIT) end
            local _, _, _, a, b = UnitCastingInfo(UNIT)
            s4, s5 = a, b
        else
            local c1, _, _, c4, c5, _, _, _, c9 = UnitChannelInfo(UNIT)
            if c1 == nil then return end
            s4, s5 = c4, c5
            isChannel = true
            isEmpowered = (c9 ~= nil and not IsSecret(c9) and c9) and true or false
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(UNIT, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(UNIT)
            end
        end
        if dur and f.bar.SetTimerDuration then
            f.bar:SetTimerDuration(dur, nil, CB().TimerDir(isChannel, isEmpowered))
        end
    else
        local castName, _, _, cs4, cs5 = UnitCastingInfo(UNIT)
        if castName ~= nil then
            s4, s5 = cs4, cs5
        else
            local c1, _, _, c4, c5 = UnitChannelInfo(UNIT)
            if c1 == nil then return end
            s4, s5 = c4, c5
        end
    end
    local ps, pe = Plain(s4), Plain(s5)
    if ps and pe then
        S.tStart, S.tEnd = ps / 1000, pe / 1000
        S.total = S.tEnd - S.tStart
    end
end

-- 專注目標換了／重新整理：正在唱就接上，沒在唱就收條（預覽中不蓋掉）
local function RefreshFromFocus()
    if not f then return end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then HideBar() return end
    if S.preview then return end
    StartDisplay()
end
FC.Refresh = RefreshFromFocus

------------------------------------------------------------
-- 預覽（設定頁的按鈕）：十秒的假施法，當重要法術（看得到「!」與發光），走明文路徑
------------------------------------------------------------
function FC.StartPreview()
    if not f then return false end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then return false end
    if S.castState == 1 or S.castState == 2 then return false end    -- 專注目標真的在唱
    local now = GetTime()
    S.preview = true
    S.displayToken = S.displayToken + 1
    S.castChannel, S.castEmpowered, S.castSecret = false, false, false
    S.castNotInterruptible = false
    S.castState = 1
    S.tStart, S.tEnd, S.total = now, now + PREVIEW_TIME, PREVIEW_TIME
    S.lastTime = nil
    f:SetAlpha(1)
    f.icon:SetTexture(PREVIEW_ICON)
    f.timeText:SetTextColor(1, 1, 1)
    SetName(L["Preview cast"], true, L["Focus target"])
    ShowGlow(nil)
    f.timeText:SetText("")
    UpdateKick()
    ApplyColor()
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)
    S.textAccum = 1
    S.active = true
    f:SetScript("OnUpdate", PlainOnUpdate)
    ShowSpark()
    f:Show()
    if ns.Visibility then ns.Visibility.Apply(KEY) end
    if ns.Fire then ns.Fire("FocusCastPreview", true) end
    return true
end

function FC.StopPreview()
    if f and S.preview then HideBar() end
end

function FC.IsPreviewing() return f and S.preview or false end

-- 施法中、淡出中、打斷停留中、預覽中都算（Visibility 的 hideWhenNotCasting 看這個）
function FC.IsActive()
    return (f and S.castState ~= nil) and true or false
end

------------------------------------------------------------
-- 事件（全部 focus 單位；處理器只轉手 ns.Defer）
------------------------------------------------------------
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

-- payload：(unit, castGUID, spellID[, interrupterGUID])；EMPOWER_STOP 多一個 complete，interrupterGUID 在第 5 位。
-- unit 不比對（RegisterUnitEvent 已經只收 focus；unit token 本身在受限內容可能是秘密字串）
local function OnCastEvent(event, _, _, _, arg4, arg5)
    local cfg = Cfg()
    if not (f and cfg and cfg.enabled ~= false) then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START" then
        StartDisplay()
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        ResyncTiming()
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        -- 值從事件名稱拿（明文），不回頭讀 UnitCastingInfo（受限內容是秘密布林）
        if S.castState == 1 or S.castState == 2 then
            S.castNotInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
            ApplyColor()
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if S.castState == 1 or S.castState == 2 then ShowInterrupted(arg4) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if S.castState ~= 2 then return end
        if arg4 ~= nil then ShowInterrupted(arg4) else EndFade() end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if S.castState ~= 2 then return end
        if arg5 ~= nil then ShowInterrupted(arg5) else EndFade() end
    else    -- STOP／FAILED：專注目標的施法，FAILED 不分「哪一條」（別人的 castGUID 我們沒有理由比對）
        if S.castState ~= 1 then return end
        EndFade()
    end
end

local function RegisterEvents()
    if ev then return end
    ev = CreateFrame("Frame")
    for _, event in ipairs(CAST_EVENTS) do ev:RegisterUnitEvent(event, UNIT) end
    ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
    -- 斷法圖示的轉圈：自己的冷卻變了就重餵（戰鬥中每個 GCD 都派，只在條顯示著時做事）
    ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_FOCUS_CHANGED" then
            ns.Defer(RefreshFromFocus)
            return
        end
        if event == "SPELL_UPDATE_COOLDOWN" then
            if f and f:IsShown() and f.kickFrame:IsShown() then ns.Defer(UpdateKick) end
            return
        end
        ns.Defer(OnCastEvent, event, ...)
    end)
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Castbar 之後）
------------------------------------------------------------
function FC.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "CENTER",
        minSize     = MinSize,
        relayout    = function() FC.Layout() end,
    })
    Build()
    FC.Layout()
    RegisterEvents()
    HideBar()
    -- 重載時專注目標正在唱：直接接上
    ns.Defer(RefreshFromFocus)
    ns.RegisterCallback("FirstRowWidthChanged", KEY, function()
        local cfg = Cfg()
        if cfg and (tonumber(cfg.width) or 0) <= 0 then FC.Layout() end
    end)
    ns.RegisterCallback("ProfileChanged", KEY, function() FC.Apply() end)
    -- 斷法技能換了（法術書／天賦／專精／術士換惡魔）：Interrupt 會重挑，條尾的圖示跟著重排（有無、圖）
    local function KickLater() ns.Defer(function() FC.Layout(); UpdateKick() end) end
    ns.Events.Register("SPELLS_CHANGED", KEY .. "_kick", KickLater)
    ns.Events.Register("PLAYER_TALENT_UPDATE", KEY .. "_kick", KickLater)
    ns.Events.Register("UNIT_PET", KEY .. "_kick", KickLater, "player")
    ns.RegisterCallback("SpecChanged", KEY .. "_kick", KickLater)
    if ns.Fire then ns.Fire("FocusCastBarChanged") end
end

-- 設定頁改了值：版面、結構、alpha；對外廣播（專注目標助手聽了讓位）
function FC.Apply()
    if not f then return end
    FC.Layout()
    local cfg = Cfg() or {}
    if cfg.enabled == false then
        HideBar()
    elseif not FC.IsActive() then
        HideBar()                  -- 「沒在施法時隱藏」切換：空條出現／消失
        RefreshFromFocus()         -- 剛打開：專注目標正在唱就接上
    else
        ApplyColor()
        UpdateKick()
        if S.preview then ShowGlow(nil) end
    end
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
    if ns.Fire then ns.Fire("FocusCastBarChanged") end
end

-- 公開 API（Api.lua）：這條現在有沒有在接手專注目標施法條（開著就算，不管專注目標在不在）
function FC.Enabled()
    local cfg = Cfg()
    return (f ~= nil and cfg ~= nil and cfg.enabled ~= false) and true or false
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
local STATE_NAME = { [1] = "施法", [2] = "引導", [3] = "淡出", [4] = "打斷停留" }

function FC.DebugLines()
    local out = {}
    if not f then
        out[1] = "  專注目標施法條：沒有初始化"
        return out
    end
    local cfg = Cfg() or {}
    out[#out + 1] = ("  專注目標施法條：%s  狀態 %s%s  秘密模式 %s  明文時間軸 %s（總長 %.2f）  發光 %s  斷法圖示 %s  alpha %s")
        :format(cfg.enabled ~= false and "開" or "關", STATE_NAME[S.castState] or "閒置",
                S.preview and "（預覽）" or "", S.castSecret and "是" or "否",
                S.tStart and "有" or "無", S.total or 0, tostring(S.glowShown or "無"),
                tostring(KickSpell(cfg) or "無"),
                tostring(ns.Visibility and ns.Visibility.Current(KEY)))
    return out
end
