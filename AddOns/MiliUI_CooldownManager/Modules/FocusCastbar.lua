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
--   * 法術打向誰（showTarget，2026-10-19）：12.x UnitSpellTargetName／UnitSpellTargetClass。名字只交給 SetText；
--     職業交給 C_ClassColor.GetClassColor 再把分量餵 SetTextColor（名條插件在正式服就這樣畫，分量是秘密數字也收——
--     跟上一行的「不收」是兩回事：那條說的是自己查表算 RGB；這條是 C 端回的色物件原封轉交）。
--     UnitShouldDisplaySpellTargetName 的布林：明文 if、秘密餵 SetAlphaFromBoolean
--   * 事件處理器只轉手 ns.Defer
--
-- 動畫材質（Core/Media.lua 的 M.FX；2026-11-06 使用者要求這條也要有動畫）：效果層整套借玩家施法條的（ns.Castbar.Fx／
-- FxHost，宿主各一份）。圖自己的顏色＝「可斷法、我方斷法冷卻中」那一態（底色白、動畫照播）；斷法就緒與不可打斷要讓人
-- 看得到那個顏色 ⇒ 那兩態效果層讓位（秘密布林各餵一層的 SetAlphaFromBoolean）、露出底下染好色的靜態底圖。被打斷、收條時停。
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

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

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

-- 一條專注目標施法條的零件（圖示、條、火花、斷法圖示、文字、發光宿主表）建在框 h 上。畫面上那條（f）與設定頁的
-- 內嵌樣本（FC.CreateSample）各建一份，版面也走同一支 LayoutParts ⇒ 樣本跟畫面上的不會各排各的
local function BuildParts(h)
    h.iconFrame = CreateFrame("Frame", nil, h, "BackdropTemplate")
    h.icon = NoSnap(h.iconFrame:CreateTexture(nil, "ARTWORK"))     -- 圖示、底跟 1px 黑邊相接：不貼齊
    h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    h.barHolder = CreateFrame("Frame", nil, h, "BackdropTemplate")
    h.bgTex = NoSnap(h.barHolder:CreateTexture(nil, "BACKGROUND"))
    h.bgTex:SetTexture(SOLID)
    h.bar = CreateFrame("StatusBar", nil, h.barHolder)
    h.bar:SetStatusBarTexture(SOLID)
    h.bar:SetMinMaxValues(0, 1)
    h.bar:SetValue(0)

    -- 動畫材質的效果層（玩家施法條那一套，Modules/Castbar.lua 的 CB.Fx）：裁切框 → host → 每一層一張貼圖
    CB().FxHost(h, h.bar)
    -- 火花掛在效果層上面那一層（掛在條上會被效果層蓋掉半邊）
    h.top = CreateFrame("Frame", nil, h.bar)
    h.top:SetAllPoints(h.bar)
    h.spark = h.top:CreateTexture(nil, "OVERLAY")
    h.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    h.spark:SetBlendMode("ADD")
    h.spark:Hide()

    -- 條尾的斷法圖示（圖示的對邊）：邊框＋圖示＋冷卻轉圈（不畫數字、不畫邊緣線、不畫閃光）
    h.kickFrame = CreateFrame("Frame", nil, h, "BackdropTemplate")
    h.kickIcon = NoSnap(h.kickFrame:CreateTexture(nil, "ARTWORK"))
    h.kickIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local okCD, kcd = pcall(CreateFrame, "Cooldown", nil, h.kickFrame, "CooldownFrameTemplate")
    if okCD and kcd then
        if kcd.SetDrawBling then kcd:SetDrawBling(false) end
        if kcd.SetDrawEdge then kcd:SetDrawEdge(false) end
        if kcd.SetHideCountdownNumbers then kcd:SetHideCountdownNumbers(true) end
        kcd:EnableMouse(false)
        h.kickCD = kcd
    end
    h.kickFrame:Hide()

    h.textFrame = CreateFrame("Frame", nil, h)
    h.textFrame:SetAllPoints(h.barHolder)
    -- ⚠ 先給字型才能 SetText
    h.nameText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.nameText, 12, "OUTLINE")
    h.nameText:SetJustifyH("LEFT")
    h.nameText:SetWordWrap(false)
    -- 重要法術版的名字（前面加「!」）疊在同一個位置：是不是重要是秘密布林，不能在 Lua 挑要寫哪段字，
    -- 兩段都寫好、交給 SetAlphaFromBoolean 二選一
    h.bangText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.bangText, 12, "OUTLINE")
    h.bangText:SetJustifyH("LEFT")
    h.bangText:SetWordWrap(false)
    h.bangText:SetAlpha(0)
    h.timeText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.timeText, 12, "OUTLINE")
    h.timeText:SetJustifyH("RIGHT")
    h.timeText:SetWordWrap(false)
    -- 法術打向誰：條下方右靠齊、比法術名小一號（位置與字級在 Layout）
    h.targetText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.targetText, 10, "OUTLINE")
    h.targetText:SetJustifyH("RIGHT")
    h.targetText:SetWordWrap(false)

    h.glowHosts = {}
end

local function Build()
    f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)
    BuildParts(f)
    f:Hide()
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
-- 零件的版面：W／H 是整條的寬高（呼叫端已經換算好）。回傳是不是反向填充。火花要不要顯示由呼叫端決定。
-- casting ＝ 這一條正在唱（施法／引導中）：動畫材質的效果層設好之後直接接著播
local function LayoutParts(h, cfg, W, H, casting)
    local showIcon = cfg.showIcon ~= false
    local iconW = showIcon and H or 0
    local gap = showIcon and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    local left = cfg.iconSide ~= "RIGHT"
    h.iconFrame:SetShown(showIcon)
    h.iconFrame:ClearAllPoints()
    h.iconFrame:SetSize(iconW > 0 and iconW or 1, H)
    h.iconFrame:SetPoint(left and "TOPLEFT" or "TOPRIGHT", h, left and "TOPLEFT" or "TOPRIGHT", 0, 0)
    local edge = ns.P.Pixel(1)
    h.iconFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(h.iconFrame) end
    h.iconFrame:SetBackdropColor(0, 0, 0, 1)
    h.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    h.icon:ClearAllPoints()
    h.icon:SetPoint("TOPLEFT", h.iconFrame, "TOPLEFT", edge, -edge)
    h.icon:SetPoint("BOTTOMRIGHT", h.iconFrame, "BOTTOMRIGHT", -edge, edge)

    -- 斷法圖示在圖示的對邊（圖示左 ⇒ 斷法右），跟圖示同大小、同間距；沒有斷法就不佔寬
    local kickID = KickSpell(cfg)
    local kickW = kickID and H or 0
    local kickGap = kickID and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    h.kickFrame:SetShown(kickID ~= nil)
    h.kickFrame:ClearAllPoints()
    h.kickFrame:SetSize(kickW > 0 and kickW or 1, H)
    h.kickFrame:SetPoint(left and "TOPRIGHT" or "TOPLEFT", h, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
    h.kickFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(h.kickFrame) end
    h.kickFrame:SetBackdropColor(0, 0, 0, 1)
    h.kickFrame:SetBackdropBorderColor(0, 0, 0, 1)
    h.kickIcon:ClearAllPoints()
    h.kickIcon:SetPoint("TOPLEFT", h.kickFrame, "TOPLEFT", edge, -edge)
    h.kickIcon:SetPoint("BOTTOMRIGHT", h.kickFrame, "BOTTOMRIGHT", -edge, edge)
    if h.kickCD then
        h.kickCD:ClearAllPoints()
        h.kickCD:SetAllPoints(h.kickIcon)
        if h.kickCD.SetSwipeColor then
            h.kickCD:SetSwipeColor(C4(ns.Setting("theme", "icon.swipeColor"), 0, 0, 0, 0.8))
        end
    end

    local barW = W - iconW - gap - kickW - kickGap
    if barW < 4 then barW = 4 end
    h.barHolder:ClearAllPoints()
    h.barHolder:SetSize(barW, H)
    h.barHolder:SetPoint(left and "TOPRIGHT" or "TOPLEFT", h.kickFrame, left and "TOPLEFT" or "TOPRIGHT", left and -kickGap or kickGap, 0)
    local inset = ns.Media.BorderInset(1)
    h.barHolder:SetBackdrop({ edgeFile = SOLID, edgeSize = inset })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(h.barHolder) end
    h.barHolder:SetBackdropBorderColor(0, 0, 0, 1)
    h.bgTex:ClearAllPoints()
    h.bgTex:SetPoint("TOPLEFT", h.barHolder, "TOPLEFT", inset, -inset)
    h.bgTex:SetPoint("BOTTOMRIGHT", h.barHolder, "BOTTOMRIGHT", -inset, inset)
    local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    h.bgTex:SetVertexColor(bg.r or 0.1, bg.g or 0.1, bg.b or 0.1, bg.a or 0.8)
    h.bar:ClearAllPoints()
    h.bar:SetPoint("TOPLEFT", h.barHolder, "TOPLEFT", inset, -inset)
    h.bar:SetPoint("BOTTOMRIGHT", h.barHolder, "BOTTOMRIGHT", -inset, inset)
    CB().SetFillTexture(h.bar, cfg.texture)
    local reversed = ns.FillReversed(cfg)
    h.bar:SetReverseFill(reversed)

    -- 層級：底 L → 條 L+1 → 效果層 L+2 → 火花 L+3 → 文字 L+4；圖示 L+1；發光宿主 L+20（GlowHost）
    local lvl = h:GetFrameLevel()
    h.barHolder:SetFrameLevel(lvl)
    h.bar:SetFrameLevel(lvl + 1)
    h.flowClip:SetFrameLevel(lvl + 2)
    h.top:SetFrameLevel(lvl + 3)
    h.textFrame:SetFrameLevel(lvl + 4)
    h.iconFrame:SetFrameLevel(lvl + 1)
    h.kickFrame:SetFrameLevel(lvl + 1)

    -- 邊緣陰影（Core/Shape.lua，同玩家施法條）：條身、圖示、斷法圖示各一圈，層級都在 h − 1；藏著的那顆不畫
    local SH = ns.Shape
    if SH then
        local spx, sa = SH.ShadowOf(cfg.shadow, cfg.shadowSize, cfg.shadowAlpha)
        SH.EdgeShadow(h, h.barHolder, spx, sa)
        SH.EdgeShadow(h, h.iconFrame, showIcon and spx or nil, sa)
        SH.EdgeShadow(h, h.kickFrame, kickID and spx or nil, sa)
    end

    local general = ns.Setting(nil, "font")
    local outline = ns.Media.ThemeOutline()
    local nameFont = ns.Media.ElementFont(cfg.font, general)
    local nameSize = tonumber(cfg.textSize) or 12
    ns.Media.SetFont(h.nameText, nameSize, outline, nameFont)
    ns.Media.SetFont(h.bangText, nameSize, outline, nameFont)
    ns.Media.SetFont(h.timeText, tonumber(cfg.timeTextSize) or 12, outline, ns.Media.ElementFont(cfg.timeFont, general))
    local no = type(cfg.nameOffset) == "table" and cfg.nameOffset or {}
    local to = type(cfg.timeOffset) == "table" and cfg.timeOffset or {}
    h.timeText:ClearAllPoints()
    h.timeText:SetPoint("RIGHT", h.textFrame, "RIGHT", tonumber(to.x) or -4, tonumber(to.y) or 0)
    h.nameText:ClearAllPoints()
    h.nameText:SetPoint("LEFT", h.textFrame, "LEFT", tonumber(no.x) or 4, tonumber(no.y) or 0)
    h.nameText:SetPoint("RIGHT", h.timeText, "LEFT", -4, 0)
    h.bangText:ClearAllPoints()
    h.bangText:SetAllPoints(h.nameText)
    local showName = cfg.showName ~= false
    h.nameText:SetShown(showName)
    h.bangText:SetShown(showName)
    h.timeText:SetShown(cfg.showTime ~= false)
    ns.Media.SetFont(h.targetText, tonumber(cfg.targetTextSize) or 10, outline, nameFont)
    local tg = type(cfg.targetOffset) == "table" and cfg.targetOffset or {}
    h.targetText:ClearAllPoints()
    h.targetText:SetPoint("TOPRIGHT", h.barHolder, "BOTTOMRIGHT", tonumber(tg.x) or -2, tonumber(tg.y) or 0)
    h.targetText:SetPoint("TOPLEFT",  h.barHolder, "BOTTOMLEFT",  0,                     tonumber(tg.y) or 0)
    h.targetText:SetShown(cfg.showTarget ~= false)

    h.spark:SetSize(10, H * 2.2)
    h.spark:ClearAllPoints()
    local tex = h.bar:GetStatusBarTexture()
    if tex then h.spark:SetPoint("CENTER", tex, reversed and "LEFT" or "RIGHT", 0, 0) end

    -- 效果層（動畫材質、animate 開著才有）：做法同玩家施法條的 LayoutParts——裁切框的前緣錨在填充貼圖上
    -- （換材質後貼圖是新的，所以每次版面重下），有往上竄的層（火舌）時上緣跟著加高。先停再設：秒數、方向可能都換了。
    -- 開著沒有記在 h.fxOn；狀態色要露出來時由 PaintColorOn 把這層壓透明
    local Fx = CB().Fx
    Fx.Stop(h)
    local layers = tex and Fx.Wanted(cfg) or nil
    local okFx, overflow = false, 0
    if layers then okFx, overflow = Fx.Setup(h, layers, cfg, reversed, H - inset * 2) else Fx.HideAll(h) end
    h.fxOn = okFx
    if okFx then
        Fx.Anchor(h, tex, reversed, overflow)
        if casting then Fx.Play(h) end
    end
    return reversed
end

function FC.Layout()
    if not f then return end
    local cfg = Cfg() or {}
    local W, H = Width(cfg), tonumber(cfg.height) or 20
    W, H = ns.P.Scale(W), ns.P.Scale(H)
    ns.Bars.SetPanelSize(KEY, W, H)
    S.reversed = LayoutParts(f, cfg, W, H, S.castState == 1 or S.castState == 2)
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

-- ⚠ 以下「…On(h, …)」這幾支是**畫面上那條（f）與設定頁的樣本（FC.CreateSample）共用**的：樣本不另寫一份上色／
-- 發光／名字／打斷畫面，餵明文的假狀態走同一條路 ⇒ 樣本上看到的就是實際的套用結果，這裡寫錯兩邊一起錯、看得出來。
-- ready／has ＝ 我方斷法就緒與否、這個專精有沒有斷法（Modules/Interrupt.lua 的 IsReady 兩個回傳，ready 可能是秘密布林）；
-- ni ＝ 不可打斷（nil／明文／秘密布林）
local function PaintColorOn(h, ni, ready, has)
    local tex = h.bar:GetStatusBarTexture()
    if not tex then return end
    local c = Colors()
    local br, bg, bb = C(c.cd, 0.906, 0.424, 0.2)
    -- 動畫材質（Core/Media.lua 的 M.FX）：底色白（圖自己的顏色＝「斷法冷卻中」那一態），斷法就緒／不可打斷照舊蓋上去；
    -- 那兩態要讓人看得到顏色 ⇒ 效果層在函式尾巴讓位
    if CB().IsFx and CB().IsFx((Cfg() or {}).texture) then br, bg, bb = 1, 1, 1 end
    local r, g, b = br, bg, bb
    local tinted = false
    if chainOK and has then
        if IsSecret(ready) then
            if Eval then
                local ok, rr, gg, b2 = pcall(EvalTriple, ready, c.ready, r, g, b)
                if ok then r, g, b = rr, gg, b2; tinted = true end
            end
        elseif ready then
            r, g, b = C(c.ready, 1, 0.741, 0)
        end
    end
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
    -- 效果層：不可打斷 → 裁切框的 alpha、斷法就緒 → host 的 alpha（兩個布林各管一層，秘密布林餵 SetAlphaFromBoolean），
    -- 壓透明之後露出底下照上面算好顏色的填充貼圖。兩個都不成立（可斷法、我方斷法冷卻中／沒有斷法）才看得到動畫
    if h.fxOn then
        local Fx = CB().Fx
        Fx.Alpha(h.flowClip, ni)
        Fx.Alpha(h.flowHost, (chainOK and has) and ready or nil)
    end
end

local function ApplyColor()
    local ready, has
    if ns.Interrupt then ready, has = ns.Interrupt.IsReady() end
    PaintColorOn(f, S.castNotInterruptible, ready, has)
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

-- h ＝ 帶 glowHosts 的那條（畫面上的 f、設定頁的樣本）
local function GlowHost(h, style)
    local host = h.glowHosts[style]
    if host then return host end
    local target = (style == "proc") and h.iconFrame or h
    host = CreateFrame("Frame", nil, target)
    host:SetAllPoints(target)
    host:SetFrameLevel(h:GetFrameLevel() + 20)
    h.glowHosts[style] = host
    return host
end

-- 在宿主上開／關一種樣式的發光（color ＝ { r, g, b, a }）。開的回傳成功與否
local function GlowStart(host, style, color)
    if style == "pixel" then
        -- 2px、往外推 1px：蓋住條本身的 1px 黑邊再多出去 1px。border=false：條自己有底
        return (pcall(LCG.PixelGlow_Start, host, color, 8, 0.25, nil, 2, 1, 1, false))
    elseif style == "autocast" then
        return (pcall(LCG.AutoCastGlow_Start, host, color, 6, 0.125, 1.2, 1, 1))
    end
    return (pcall(LCG.ProcGlow_Start, host, { color = color }))
end

local function GlowStop(host, style)
    if style == "pixel" then
        pcall(LCG.PixelGlow_Stop, host)
    elseif style == "autocast" then
        pcall(LCG.AutoCastGlow_Stop, host)
    else
        pcall(LCG.ProcGlow_Stop, host)
    end
end

-- 亮著哪一種樣式記在那條自己身上（h.glowShown）
local function StopGlowOn(h)
    if not h then return end
    if h.glowShown and LCG then
        local host = h.glowHosts[h.glowShown]
        if host then GlowStop(host, h.glowShown) end
    end
    h.glowShown = nil
end
local function StopGlow() StopGlowOn(f) end

-- important：明文或秘密布林；nil ＝ 不問直接亮（頁首的預覽）
local function ShowGlowOn(h, important)
    local cfg = Cfg() or {}
    if not cfg.glowImportant or not LCG then StopGlowOn(h) return end
    local style = GlowStyle()
    if h.glowShown ~= style then
        StopGlowOn(h)
        local host = GlowHost(h, style)
        local cr, cg, cb = C(Colors().glow, 0.95, 0.95, 0.32)
        if not GlowStart(host, style, { cr, cg, cb, 1 }) then return end
        h.glowShown = style
    end
    local host = h.glowHosts[style]
    if important == nil then
        host:SetAlpha(1)
    else
        host:SetAlphaFromBoolean(important, 1, 0)
    end
end
local function ShowGlow(important) ShowGlowOn(f, important) end

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
local function PaintNameOn(h, name, important, caster)
    local cfg = Cfg() or {}
    local shown = FC.DisplayName(caster, name, cfg.showCaster, cfg.nameMaxChars)
    h.nameText:SetText(shown)
    if important == nil or not cfg.bangImportant then
        h.bangText:SetAlpha(0)
        h.nameText:SetAlpha(1)
        return
    end
    local cr, cg, cb = C(Colors().glow, 0.95, 0.95, 0.32)
    h.bangText:SetText(string.format("|cff%02x%02x%02x!|r ", cr * 255, cg * 255, cb * 255) .. shown)
    h.bangText:SetAlphaFromBoolean(important, 1, 0)
    h.nameText:SetAlphaFromBoolean(important, 0, 1)
end
local function SetName(name, important, caster) PaintNameOn(f, name, important, caster) end

-- 法術打向誰（條右下角、職業色）。name 可能是秘密字串（只交給 SetText）；class 明文或秘密 token（只交給 GetClassColor）
local function ClearSpellTargetOn(h)
    h.targetText:SetText("")
    h.targetText:SetAlpha(1)
    h.targetText:SetTextColor(1, 1, 1)
end
local function ClearSpellTarget() ClearSpellTargetOn(f) end

local function PaintSpellTargetOn(h, name, class)
    h.targetText:SetAlpha(1)
    local r, g, b = 1, 1, 1
    if class ~= nil and (Cfg() or {}).targetClassColor ~= false then
        local color = C_ClassColor and C_ClassColor.GetClassColor(class)
            or (not IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if color then r, g, b = color:GetRGB() end
    end
    h.targetText:SetTextColor(r, g, b)
    h.targetText:SetText(name)
end
local function PaintSpellTarget(name, class) PaintSpellTargetOn(f, name, class) end

local function SetSpellTarget()
    local cfg = Cfg() or {}
    if cfg.showTarget == false or not UnitSpellTargetName then ClearSpellTarget() return end
    local name = UnitSpellTargetName(UNIT)
    if name == nil then ClearSpellTarget() return end            -- 秘密字串可測 nil
    local class = UnitSpellTargetClass and UnitSpellTargetClass(UNIT) or nil
    PaintSpellTarget(name, class)
    if UnitShouldDisplaySpellTargetName then
        local show = UnitShouldDisplaySpellTargetName(UNIT)
        if show ~= nil then
            if IsSecret(show) then
                f.targetText:SetAlphaFromBoolean(show, 1, 0)
            elseif not show then
                ClearSpellTarget()
            end
        end
    end
end

------------------------------------------------------------
-- 顯示流程
------------------------------------------------------------
local function SetTimeText(text)
    if S.lastTime == text then return end
    S.lastTime = text
    f.timeText:SetText(text)
end

-- 開唱：火花＋動畫材質的效果層開始播（同玩家施法條的 ShowSparkOn）
local function ShowSparkOn(h)
    h.spark:SetShown((Cfg() or {}).showSpark ~= false)
    if h.fxOn then CB().Fx.Play(h) end
end
local function ShowSpark() ShowSparkOn(f) end

-- 斷法圖示：圖示（自己的法術，明文）、冷卻轉圈（duration 物件原封轉交）、就緒亮／冷卻中暗（IsZero 的布林只餵 alpha）。
-- 餵不進去就 Clear（圖示留著）。開唱、SPELL_UPDATE_COOLDOWN（條顯示中）、預覽、套用設定時叫
-- 兩段畫面共用（見 PaintColorOn 上面的說明）：圖示的圖、就緒亮／冷卻中暗（zero ＝ 冷卻是不是 0：nil 不知道／明文／秘密布林）
local function PaintKickIconOn(h, id)
    local getTex = C_Spell and C_Spell.GetSpellTexture
    if getTex then
        local ok, tex = pcall(getTex, id)
        if ok and tex ~= nil then h.kickIcon:SetTexture(tex) end
    end
end
local function PaintKickReadyOn(h, zero)
    if zero == nil then
        h.kickIcon:SetAlpha(1)
    elseif IsSecret(zero) then
        if not pcall(h.kickIcon.SetAlphaFromBoolean, h.kickIcon, zero, 1, 0.55) then h.kickIcon:SetAlpha(1) end
    else
        h.kickIcon:SetAlpha(zero and 1 or 0.55)
    end
end

local function UpdateKick()
    if not (f and f.kickFrame:IsShown()) then return end
    local id = KickSpell()
    if not id then return end
    PaintKickIconOn(f, id)
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
    PaintKickReadyOn(f, zero)
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
    CB().Fx.Stop(f)
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
        ClearSpellTarget()
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
    CB().Fx.Stop(f)
    StopGlow()
    f.timeText:SetText("")
    f:SetScript("OnUpdate", FadeOnUpdate)
    f:Show()
end

-- 被打斷：凍結滿條變紅、名字換「已打斷」、右側印斷法者（職業色），停留後淡出。
-- interrupterGUID 只比 nil；名字可能是秘密字串（SetText 收得下）；職業是秘密字串就維持白字
-- 打斷畫面本身（共用，見 PaintColorOn 上面的說明）：滿條、打斷色、名字換「已打斷」、右側印斷法者。
-- who ＝ 斷法者的名字（nil ＝ 不印；可能是秘密字串）、class ＝ 職業 token（秘密字串就維持白字）
local function PaintInterruptedOn(h, who, class)
    h.spark:Hide()
    CB().Fx.Stop(h)                            -- 滿條的打斷色要露出來
    StopGlowOn(h)                              -- 施法已經斷了，紅條不再標重要
    h.bar:SetMinMaxValues(0, 1)
    h.bar:SetValue(1)
    local tex = h.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(C(Colors().interrupted, 1, 0.204, 0.145)) end
    PaintNameOn(h, L["Interrupted"], nil)
    h.timeText:SetText("")
    ClearSpellTargetOn(h)                      -- 施法斷了，打向誰已經不重要
    if who ~= nil then
        local r, g, b = 1, 1, 1
        if class ~= nil and not IsSecret(class) then
            local color = C_ClassColor and C_ClassColor.GetClassColor(class)
                or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if color then r, g, b = color:GetRGB() end
        end
        h.timeText:SetTextColor(r, g, b)
        h.timeText:SetText(who)
    end
end

local function ShowInterrupted(interrupterGUID)
    S.active = false
    S.castState = 4
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    local name, class
    if interrupterGUID ~= nil and (Cfg() or {}).showInterrupter ~= false then
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
    end
    PaintInterruptedOn(f, name, class)
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
    SetSpellTarget()
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
    if (cfg.showTarget ~= false) then
        PaintSpellTarget(UnitName("player"), ns.playerClass or (UnitClassBase and UnitClassBase("player")))   -- 範例：打向自己
    else
        ClearSpellTarget()
    end
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

------------------------------------------------------------
-- 設定頁的內嵌樣本（Options/Tab_FocusCast.lua「材質」上方那一列）：一條自己循環填滿的假施法條。
-- **零件、版面、上色、發光、名字、斷法圖示、火花、打斷畫面全部是畫面上那條用的同一批函式**（BuildParts／LayoutParts／
-- PaintColorOn／ShowGlowOn／PaintNameOn／PaintKick…On／ShowSparkOn／PaintInterruptedOn／PaintSpellTargetOn），
-- **呼叫順序照 StartDisplay／StartPreview、疊層照 LayoutParts**，樣本只是另一個框 h、只負責餵明文的假狀態
-- ⇒ 樣本上的樣式與上色就是實際的套用結果（使用者 2026-11-06 指定：套用方式、呼叫順序、疊層都要跟實際一模一樣，
-- 才能順便拿它看樣式或上色有沒有錯）。**要改畫法就改那批共用函式，不要在這裡另外寫。**
-- 所以設定關著的東西樣本也不畫：glowImportant／bangImportant 關著時，「重要法術」那兩顆按鈕按了沒有畫面。
-- 不碰畫面上那條的狀態（S）與任何施法 API。
--   local s = FC.CreateSample(parent)    s 是框，位置由呼叫端擺
--   s:Refresh(maxW)                      照目前設定重排重畫（寬放不下縮到 maxW、高上限 FC.SAMPLE_MAX_H：列高是固定的）
--   s.state ＝ "ready"｜"cd"｜"immune"｜"interrupted"   假施法的狀態，四選一：
--       ready        可斷法、我方斷法就緒        cd   可斷法、我方斷法冷卻中
--       immune       不可中斷                    interrupted   被打斷（斷法者＝自己）
--   s.glowOn／s.bangOn                   這個法術算不算重要法術——發光與「!」各餵各的（實際上是同一個布林，
--                                        分開是為了兩種標示可以各自看）
--   s:Paint()                            改了上面三個欄位之後叫
------------------------------------------------------------
local SAMPLE_TIME, SAMPLE_HOLD = 3, 0.6
FC.SAMPLE_MAX_H = 24

function FC.CreateSample(parent)
    local s = CreateFrame("Frame", nil, parent)
    BuildParts(s)
    s.state, s.glowOn, s.bangOn = "ready", true, true

    local t, acc, wantSpark, lastTime, glowSig = 0, 1, true, nil, nil
    s:SetScript("OnUpdate", function(self, dt)
        if self.state == "interrupted" then return end
        t = t + dt
        if t >= SAMPLE_TIME + SAMPLE_HOLD then t = t % (SAMPLE_TIME + SAMPLE_HOLD) end
        local filling = t < SAMPLE_TIME
        self.bar:SetValue(filling and t / SAMPLE_TIME or 1)
        self.spark:SetShown(wantSpark and filling)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        local text = CB().FormatTime((Cfg() or {}).timeFormat, filling and t or SAMPLE_TIME, SAMPLE_TIME)
        if text ~= lastTime then
            lastTime = text
            self.timeText:SetText(text)
        end
    end)

    function s:Paint()
        local cfg = Cfg() or {}
        local st = self.state
        local me = UnitName and UnitName("player") or nil
        local class = ns.playerClass or (UnitClassBase and UnitClassBase("player")) or nil

        -- 開唱：以下照 StartDisplay／StartPreview 的順序，一支都不換位置
        self.icon:SetTexture(PREVIEW_ICON)
        self.timeText:SetTextColor(1, 1, 1)
        PaintNameOn(self, L["Preview cast"], self.bangOn, L["Focus target"])
        -- 發光：畫面上那條每次開唱都是新的一份（照開的那一刻的顏色與尺寸畫）⇒ 這幾樣變了就當成新的一次開唱，先停再開
        local c = Colors().glow
        local sig = table.concat({ GlowStyle(), tostring(type(c) == "table" and c.r), tostring(type(c) == "table" and c.g),
            tostring(type(c) == "table" and c.b), self:GetWidth(), self:GetHeight() }, "|")
        if sig ~= glowSig then
            glowSig = sig
            StopGlowOn(self)
        end
        ShowGlowOn(self, self.glowOn)
        lastTime = nil
        self.timeText:SetText("")
        if cfg.showTarget ~= false and me ~= nil then
            PaintSpellTargetOn(self, me, class)          -- 範例：打向自己（同頁首的預覽）
        else
            ClearSpellTargetOn(self)
        end
        -- 斷法圖示（UpdateKick 的三步）：圖、冷卻轉圈（沒有真的冷卻可以餵 ⇒ 清掉）、就緒亮／冷卻中暗
        if self.kickFrame:IsShown() then
            local id = KickSpell(cfg)
            if id then
                PaintKickIconOn(self, id)
                if self.kickCD and self.kickCD.Clear then pcall(self.kickCD.Clear, self.kickCD) end
                PaintKickReadyOn(self, st ~= "cd")
            end
        end
        PaintColorOn(self, st == "immune", st == "ready", true)
        self.bar:SetMinMaxValues(0, 1)
        ShowSparkOn(self)

        -- 被打斷：接在一次開唱後面（畫面上也是唱到一半才被斷），照 ShowInterrupted
        if st == "interrupted" then
            PaintInterruptedOn(self, cfg.showInterrupter ~= false and me or nil, class)
        end
    end

    function s:Refresh(maxW)
        local cfg = Cfg() or {}
        local W, H = ns.P.Scale(Width(cfg)), ns.P.Scale(tonumber(cfg.height) or 20)
        if maxW and W > maxW then W = maxW end
        if W < 80 then W = 80 end
        if H > FC.SAMPLE_MAX_H then H = FC.SAMPLE_MAX_H elseif H < 6 then H = 6 end
        self:SetSize(W, H)
        LayoutParts(self, cfg, W, H, self.state ~= "interrupted")
        wantSpark = cfg.showSpark ~= false
        self:Paint()
    end
    -- 框藏起來時動畫組會停（換頁、換表單、關視窗）：重新顯示時接著播
    s:SetScript("OnShow", function(self)
        if self.fxOn and self.state ~= "interrupted" then CB().Fx.Play(self) end
    end)
    return s
end

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
                S.tStart and "有" or "無", S.total or 0, tostring(f and f.glowShown or "無"),
                tostring(KickSpell(cfg) or "無"),
                tostring(ns.Visibility and ns.Visibility.Current(KEY)))
    return out
end
