------------------------------------------------------------
-- 自訂項目：光環格（從 Modules/Custom.lua 切出，2026-10-18；TOC 緊接在 Custom.lua 之後載入）
--
-- 持有框、AuraContainer 與按鈕樣式（initializeFrame 裡烘的那一套）、飾品欄增益、光環格的 Masque、
-- 引擎補位（只有光環格的條）。規則與 12.1 的硬限制見 Custom.lua 檔頭「光環格」那一段。
-- 用到的 Custom.lua 幫手與共用表都掛在 CU 上（Plain、Try、AnchorPip、WHITE、QUESTION、pendingBuild、
-- pendingKick、flows），這裡取回成 local；給 Custom.lua 回頭叫的掛回 CU（Kick、NewHolder、RGBA、GLOW_TYPES、
-- AttachGlow、EnsureContainer、RING_LIFT、HideParts、SyncSkinLayer、OverlayShape、UpdatePlaceholder、
-- EnsureFlowContainer、HideFlow）。
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

local CU = ns.Custom

local WHITE, QUESTION = CU.WHITE, CU.QUESTION
local pendingBuild, pendingKick, flows = CU.pendingBuild, CU.pendingKick, CU.flows
local Plain, Try, AnchorPip = CU.Plain, CU.Try, CU.AnchorPip


------------------------------------------------------------
-- 光環格：持有框、容器、按鈕樣式
------------------------------------------------------------
local function Kick(c)
    pcall(function() c:Hide(); c:Show() end)
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end
CU.Kick = Kick

local function OnHolderShow(rec, h)
    if h and rec.frame ~= h then return end         -- 搬條收起來的那顆（另一種 kind 的持有框）
    local c = rec.container
    if not c or not rec.placedBar then return end
    if InCombatLockdown() then
        pendingKick[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
    else
        pendingKick[rec] = nil
        Kick(c)
    end
end

local function NewHolder(rec)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetSize(1, 1)
    h:Hide()
    h:EnableMouse(false)
    -- 圖示類的占位與探針（h.ph／h.skin）是條容器的子框，第一次要用才建（見「光環格的 Masque」）
    -- 容器池掛在持有框上（一種 kind 一顆持有框、各自的池）
    h.containers = {}
    h.container, h.sig = nil, nil
    -- 掛勾裡只記帳（容器層的 Show 可能在別人的流程裡），工作丟到下一幀
    h:HookScript("OnShow", function() ns.Defer(OnHolderShow, rec, h) end)
    return h
end
CU.NewHolder = NewHolder

-- 光環格的樣式：全部解成純數字與預先建好的物件（initializeFrame 裡只查這張表）
local colorCurves = {}
local function ColorCurve(lowBelow, low, normal)
    local key = string.format("%s|%.3f,%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f", tostring(lowBelow),
        low[1], low[2], low[3], low[4], normal[1], normal[2], normal[3], normal[4])
    local hit = colorCurves[key]
    if hit ~= nil then return hit or nil end
    colorCurves[key] = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local okC, cl, cn = pcall(function()
        return CreateColor(low[1], low[2], low[3], low[4]), CreateColor(normal[1], normal[2], normal[3], normal[4])
    end)
    if not okC then return nil end
    local added = pcall(function()
        curve:AddPoint(0, cl)
        curve:AddPoint(lowBelow, cl)
        curve:AddPoint(lowBelow + 0.01, cn)
        curve:AddPoint(lowBelow + 86400, cn)
    end)
    if not added then return nil end
    colorCurves[key] = curve
    return curve
end

local function RGBA(c, dr, dg, db, da)
    if type(c) ~= "table" then return { dr, dg, db, da } end
    return { c.r or dr, c.g or dg, c.b or db, c.a or da }
end
CU.RGBA = RGBA

local GLOW_TYPES = { pixel = true, autocast = true, button = true, proc = true, border = true }
CU.GLOW_TYPES = GLOW_TYPES

-- shape ＝ "bars"：長條的外觀（ApplyBarGeometry／ApplyBarLook／Text.ApplyBar 讀的那幾格）也解進來、進簽章
-- ring：圓環條上這一格的 rect（{ ring ＝ 從內往外第幾圈, tex ＝ 第幾張環形貼圖 }，CU.Place 從 Layout.Compute 的 rect 記下來）；
--       給了而且這條真的是圓環條（Decorate.RingStyle）⇒ st.shape ＝ "rings"，見「光環格畫成圓環」那一節
local gradCache = {}        -- 光環長條的漸層顏色物件（F8a）：依「方向＋兩色」快取，換容器時不重配
local function AuraStyle(rec, barKey, w, h, shape, ring)
    -- 飾品欄的觸發發光疊層：只畫發光、樣式讀 glow.proc（CU.ProcStyle，見「飾品欄的觸發發光疊層」）
    if rec.procOf then return CU.ProcStyle(rec, barKey, w, h) end
    local S, SS, id = ns.Setting, ns.SpellSetting, rec.cooldownID
    local border = S(barKey, "border") or {}
    -- 文字：條層 ⊕ 這一招的文字覆寫（Text.SpellText；疊層照冷卻格那一筆的 id）。值全部解進 st、進簽章
    -- ⇒ 改了換一顆容器（戰鬥中記旗標、脫戰建）
    local TX = ns.Text
    local cdT, hideCDText = TX.SpellText(barKey, id, "cooldownText")
    local stT, hideStText, stOwn = TX.SpellText(barKey, id, "stackText")
    local scale = UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    local st = {
        zoom     = tonumber(S(barKey, "icon.zoom")) or 0,
        bsize    = tonumber(border.size) or 0,
        bcolor   = RGBA(SS(barKey, id, "borderColor") or border.color, 0, 0, 0, 1),
        swipe    = RGBA(S(barKey, "icon.swipeColor"), 0, 0, 0, 0.8),
        cdFont   = ns.Media.Font(ns.Media.ElementFont(cdT.font, S(barKey, "font"))),
        stFont   = ns.Media.Font(ns.Media.ElementFont(stT.font, S(barKey, "font"))),
        outline  = S(barKey, "outline") or "",
        scale    = scale,
        hideCD   = hideCDText and true or false,
        cdSize   = tonumber(cdT.size) or 16,
        cdColor  = RGBA(cdT.color, 1, 1, 1, 1),
        cdPoint  = cdT.point or "CENTER", cdX = tonumber(cdT.x) or 0, cdY = tonumber(cdT.y) or 0,
        hideStack = hideStText and true or false,
        stSize   = tonumber(stT.size) or 12,
        stColor  = RGBA(stT.color, 1, 1, 1, 1),
        stPoint  = stT.point or "TOP", stX = tonumber(stT.x) or 0, stY = tonumber(stT.y) or 0,
    }
    -- 小數與低秒變色（decimals／lowBelow／lowColor）：光環格家族倒的全是增益持續時間 ⇒ 照「增益持續時間」那一組
    -- （I／J：cooldownText.buffDecimalsBelow／buffLowColor／buffLowBelow，預設 0／關／5；低秒色＝增益持續時間低秒顏色，沒有退倒數的低秒色），
    -- 冷卻倒數的小數門檻與低秒變色不看。解法跟暴雪格同一支（Text.BuffTiming）
    do
        local d, l, lc = TX.BuffTiming(cdT, SS(barKey, id, "durationLowColor"))
        st.decimals, st.lowBelow = d, l
        st.lowColor = RGBA(lc, 0.95, 0.45, 0.70, 1)
        -- 時間格式（分鐘／分:秒）照這一條的倒數，跟暴雪格同一支（Text.TimeFormat）
        st.timeFormat = TX.TimeFormat and TX.TimeFormat(barKey) or "mmss"
    end
    local function C(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4]) end
    -- 圓環（見「光環格畫成圓環」）：圈數、貼圖、環寬、軌道色、填色、文字位置全部解成純數字、進簽章。
    -- 發光、Masque、自訂文字、邊框在圓環上一律不畫（下面各段看 ringOn）
    local ringSig = "-"
    local D0 = ns.Decorate
    local rs = (shape ~= "bars" and type(ring) == "table" and D0 and D0.RingStyle) and D0.RingStyle(barKey) or nil
    local ringOn = rs ~= nil
    if ringOn then
        local LY = ns.Layout
        local k, tex = tonumber(ring.ring) or 1, tonumber(ring.tex) or 1
        -- 填色：這一招的圓環顏色 ＞ 條的填色（ringColor 的退路就是 ring.fillColor，ns.SpellSetting 解）；false ＝ 職業色
        local fr, fg, fb, fa = D0.RingFill(SS(barKey, id, "ringColor"))
        local tc = rs.track
        local pl = LY.RingTextPlace(rs, st.cdSize)
        st.shape = "rings"
        st.ring = {
            rank = k, tex = tex, path = LY.RingFile(tex), thick = rs.thick,
            track = RGBA(tc, 0.04, 0.06, 0.08, 0.9),
            fill = { fr or 1, fg or 1, fb or 1, fa or 1 },
            showIcon = rs.showIcon, iconSize = rs.iconSize,
            y = pl.y, cdPoint = pl.cdPoint, cdX = pl.cdX, extraX = pl.extraX,
        }
        -- 「倒數文字：不顯示」＝ 這一格不建倒數（跟這一招的隱藏倒數同一個開關）
        if rs.timeText == "hide" then st.hideCD = true end
        local rg = st.ring
        ringSig = table.concat({ "rings", rg.rank, rg.tex, rg.thick, C(rg.track), C(rg.fill), tostring(rg.showIcon), rg.iconSize,
            string.format("%.2f,%.2f,%.2f", rg.y, rg.cdX, rg.extraX), rg.cdPoint }, ",")
    end
    -- 圖示形狀與陰影（Core/Shape.lua；條層生效值＝Decorate.Resolve 的 ishape／ishadow）：米利樣式、圖示類、不是圓環才有，
    -- 這一格交給 Masque（hd.msqOn）時由皮決定。疊層（rec.overlayOf）不畫陰影：底下的冷卻格自己有一張。
    -- 遮罩路徑、陰影外擴全部先算成純值（initializeFrame 裡只查表）、進簽章 ⇒ 換形狀換一顆容器
    local shapeSig = "-"
    do
        local hdS = rec.frame
        local SH = ns.Shape
        if SH and shape ~= "bars" and not ringOn and not (hdS and hdS.msqOn) and D0 and D0.Resolve then
            local r0 = D0.Resolve(barKey)
            local ish, ishd = r0.ishape, r0.ishadow
            if rec.overlayOf then ishd = nil end
            st.ishape, st.shadow = ish, ishd
            st.maskPath = ish and SH.MASK[ish] or nil
            st.shadowPath = ishd and SH.SHADOW[ish or "square"] or nil
            st.cellW, st.cellH = tonumber(w) or 0, tonumber(h) or 0
            if ish or ishd then shapeSig = "shp:" .. SH.Sig(ish, ishd) end     -- 方形無陰影 ＝ "-"（跟沒有這個功能時同一個簽章）
        end
    end
    -- 長條：圖示一邊留 h×h、其餘是條身（照 Decorate.ApplyBarGeometry）；字型、顏色、開關全部解成純數字
    local barSig
    if shape == "bars" then
        local bar = S(barKey, "bar")
        bar = type(bar) == "table" and bar or {}
        local font = S(barKey, "font")
        -- 圖示位置：這一招的生效值（逐法術覆寫 → 主題／條層，ns.BarIconSide）
        local side = ns.BarIconSide and ns.BarIconSide(barKey, id) or S(barKey, "icon.barIconSide")
        if side ~= "RIGHT" and side ~= "NONE" then side = "LEFT" end
        st.shape     = "bars"
        st.bh        = tonumber(h) or tonumber(bar.height) or 20
        st.side      = side
        st.bgap      = ns.Layout.Snap(tonumber(bar.iconGap) or 0)
        -- 暴雪樣式（Decorate.BarLook；直向不會是）：填充／底／火花換暴雪的圖集、細條身、圖示套圓角遮罩＋外框圖、不畫邊框；
        -- 尺寸照格高等比（Decorate.BlizzBarMetrics），在這裡先算成純數字
        local D0b = ns.Decorate
        st.blizz     = (D0b and D0b.BarLook and D0b.BarLook(bar) == "blizzard") and true or false
        st.btex      = st.blizz and D0b.BLIZZ_ATLAS.fill or ns.Media.Texture(bar.texture)
        -- 填充色：這一招的長條顏色（逐法術覆寫 barColor，單色、不套漸層）＞ 條的（D0b.BarFillStyle 解）
        local bc = SS(barKey, id, "barColor")
        local ownFill = type(bc) == "table"
        st.bfill     = RGBA((D0b and D0b.BarFillStyle) and D0b.BarFillStyle(bar, bc).color or (ownFill and bc or bar.color),
            0.4, 0.6, 0.9, 1)
        st.bbg       = st.blizz and { 1, 1, 1, 1 } or RGBA(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
        st.spark     = bar.spark and true or false
        -- 名字：「長條」節的名字 ⊕ 這一招的覆寫（Text.SpellText 的 "barName"：開關三態、字型、字級）
        local nt = TX.SpellText(barKey, id, "barName")
        st.nameFont  = ns.Media.Font(ns.Media.ElementFont(nt.font, font))
        st.nameSize  = tonumber(nt.size) or 12
        st.nameX, st.nameY = TX.BarOffset(bar.nameOffset)
        -- 秒數：「長條」節的秒數 ⊕ 這一招的覆寫（Text.SpellText 的 "barTime"；位置照 Text.BarTimePlace）
        local tt, _, tOwn = TX.SpellText(barKey, id, "barTime")
        st.timeFont  = ns.Media.Font(ns.Media.ElementFont(tt.font, font))
        st.timeSize  = tonumber(tt.size) or 12
        st.timeColor = RGBA(tt.color, 1, 1, 1, 1)
        st.timePoint, st.timeX, st.timeY, st.timeJustify = TX.BarTimePlace(tOwn, bar.vertical, bar.timeOffset)
        -- 層數字級：這一招自己改過的優先，其次條層「層數」的字級（同 Text.ApplyBar）
        st.barStack  = tonumber(stOwn.size) or tonumber(stT.size) or 12
        -- 長條的層數錨點＋往內縮的 1px（同 Text.ApplyBar／Text.BarStackInset；這裡先算好，initializeFrame 只查欄位）
        st.stBarPoint = S(barKey, "stackText.barPoint") or "BOTTOMRIGHT"
        st.stBarIX = st.stBarPoint:find("RIGHT") and -1 or (st.stBarPoint:find("LEFT") and 1 or 0)
        st.stBarIY = st.stBarPoint:find("BOTTOM") and 1 or (st.stBarPoint:find("TOP") and -1 or 0)
        st.showName  = nt.show and true or false
        st.showTime  = bar.showTime and true or false
        st.showStacks = bar.showStacks and true or false
        st.name      = Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
        -- 直向（F8c）：格子是 w（粗細）× h（條長），圖示 w×w 在上／下（side 的 LEFT／RIGHT），名字不畫
        st.vert      = bar.vertical and true or false
        st.rev       = bar.reverseFill and true or false     -- 反向填充：條＝SetReverseFill、火花換到另一端
        st.isz       = st.vert and (tonumber(w) or 20) or st.bh
        -- 漸層（F8a）：顏色物件在這裡（容器建立之前）建好，initializeFrame 裡只查表。
        -- 反向填充時起點色跟著填充起點（Decorate.GradientFlip，同 PaintFill 的決定）⇒ 兩色對調、對調也進快取鍵
        local D = ns.Decorate
        local cg = (not st.blizz) and (not ownFill) and D and D.CleanGradient and D.CleanGradient(bar.gradient)
        if cg and CreateColor then
            local flip = D.GradientFlip and D.GradientFlip(bar) or false
            local gsig = cg.dir .. (flip and "~" or "") .. C(st.bfill) .. ">" .. C({ cg.color2.r, cg.color2.g, cg.color2.b, cg.color2.a })
            local hit = gradCache[gsig]
            if not hit then
                local a = CreateColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4])
                local z = CreateColor(cg.color2.r, cg.color2.g, cg.color2.b, cg.color2.a)
                if flip then a, z = z, a end
                hit = { o = cg.dir == "V" and "VERTICAL" or "HORIZONTAL", sig = gsig, c1 = a, c2 = z }
                gradCache[gsig] = hit
            end
            st.bgrad = hit
        end
        barSig = table.concat({ "bars", string.format("%.2f,%.2f", st.bh, st.bgap), st.side, st.btex, C(st.bfill), C(st.bbg),
            tostring(st.spark), st.nameFont, st.nameSize, st.nameX, st.nameY, st.timeFont, st.timeSize, st.barStack, st.stBarPoint,
            C(st.timeColor), st.timePoint, st.timeX, st.timeY,
            tostring(st.showName), tostring(st.showTime), tostring(st.showStacks), st.name,
            tostring(st.vert), string.format("%.2f", st.isz), st.bgrad and st.bgrad.sig or "-", tostring(st.rev) }, ",")
        if st.blizz then
            -- 等比尺寸＋火花圖集原尺寸（initializeFrame 裡不呼叫 C_Texture）
            local m = D0b.BlizzBarMetrics(st.bh)
            st.bm = m
            local CT = C_Texture
            local ok, info = pcall(function() return CT and CT.GetAtlasInfo and CT.GetAtlasInfo(D0b.BLIZZ_ATLAS.pip) end)
            if ok and type(info) == "table" and tonumber(info.width) and tonumber(info.height) then
                st.pipW, st.pipH = info.width * m.pipScale, info.height * m.pipScale
            else
                st.pipW, st.pipH = 2, m.thick
            end
            st.pipY = ns.Layout.Snap(m.pipScale)
            st.atlas = D0b.BLIZZ_ATLAS
            barSig = barSig .. ",blizz," .. string.format("%.2f", m.thick)
        end
    end
    -- 生效發光：開著而且知道格子尺寸才畫；關著時不進簽章（尺寸變了不必換容器）。
    -- 長條畫在圖示那一格（h×h；直向 w×w）；沒有圖示（NONE）時畫整格
    if shape == "bars" and st.side ~= "NONE" then
        if st.vert then h = w else w = h end
    end
    local glowSig = "-"
    -- 層數發光（層數 ≥ N 才亮；欄位跟暴雪增益的 Core/StackGate.lua 同一組，光環格只做 ≥、不收比較子）：
    -- 有設就取代生效發光（互斥，層數的為準）。圓環不畫（跟暴雪增益一樣，層數發光是方形的）。
    -- 閘在 AttachGlow 建（gl.stack）：引擎寫層數的 StatusBar ＋ 裁切框，插件端零讀取
    local SG = ns.StackGate
    local stackN = (not ringOn and SG) and SG.Threshold(SS(barKey, id, "stackGlow")) or nil
    if not ringOn and (stackN or SS(barKey, id, "activeGlow")) and tonumber(w) and tonumber(h) and w > 0 and h > 0 then
        -- 樣式只讀條層（跟觸發／就緒同一套），逐法術只開關；層數發光多了逐法術的樣式與顏色（StackGate.GlowStyle）
        local g = stackN and SG.GlowStyle(barKey, id) or S(barKey, "glow.active")
        g = type(g) == "table" and g or {}
        st.glow = {
            type      = GLOW_TYPES[g.type] and g.type or "pixel",
            color     = RGBA(g.color, 0.95, 0.95, 0.32, 1),
            lines     = tonumber(g.lines) or 8,
            thickness = tonumber(g.thickness) or 2,
            frequency = tonumber(g.frequency) or 0.2,
            w = w, h = h,
            stack     = stackN,                 -- 層數門檻（nil ＝ 生效發光）
        }
        local gl = st.glow
        -- Masque 非方形的皮（圓形、六角形）：發光跟著皮的形狀，映射照 Core/Glow.lua（觸發／閃光換貼圖、像素與自動施法
        -- 改畫該形狀的觸發）。形狀從交給 Masque 的框讀（探針、或疊層底下的冷卻格；hd.msqFrame）。
        -- hd.msqOn 只在這條是 Masque 模式、而且那一格真的交出去了才是 true ⇒ 沒裝 Masque／米利模式第一個條件就走
        local hd0 = rec.frame
        if hd0 and hd0.msqOn and shape ~= "bars" and ns.Glow and ns.Glow.SkinShape then
            local gshape = ns.Glow.SkinShape(hd0.msqFrame, barKey)
            if gshape then gl.type, gl.art = ns.Glow.ShapedStyle(gl.type, gshape) end
        elseif st.ishape and ns.Glow and ns.Glow.BuiltinShape then
            -- 內建圖示形狀（米利樣式）：圓形走同一條（Masque 有載入才拿得到形狀的貼圖，沒裝照舊方形）
            local gshape = ns.Glow.BuiltinShape(st.ishape)
            if gshape then gl.type, gl.art = ns.Glow.ShapedStyle(gl.type, gshape) end
        end
        glowSig = table.concat({ gl.type, C(gl.color), gl.lines, gl.thickness, gl.frequency,
            string.format("%.2f,%.2f", w, h), gl.art and gl.art.sig or "-", stackN and ("s" .. stackN) or "-" }, ",")
    end
    -- 飾品欄的增益疊層（rec.overlayOf）：整段都是增益持續時間 ⇒ 套「增益那一段」的設定（跟暴雪冷卻格倒增益時同一組，
    -- Core/Decorate.lua 的 PhaseColors）：換色開著 ⇒ 倒數字色＝durationColor、轉圈色＝durationSwipeColor
    -- （小數與低秒變色上面已照「增益持續時間」那一組解好）。隱藏倒數照 hideCooldownText（上面）。
    -- 這幾個值本來就在簽章裡，另外加一個 "ov" 記號（同一個法術組的光環格與疊層不共用容器）
    local ovSig = "-"
    if rec.overlayOf then
        local dc = ns.Decorate and ns.Decorate.DurationColorOf
            and ns.Decorate.DurationColorOf(SS(barKey, id, "colorDuration"), SS(barKey, id, "durationColor")) or nil
        if dc then
            st.cdColor  = RGBA(dc, 1, 0.85, 0.1, 1)
            st.swipe    = RGBA(SS(barKey, id, "durationSwipeColor"), 1, 0.9, 0.5, 0.5)
        end
        ovSig = dc and "ov+" or "ov"
    end
    -- Masque（圖示類，見「光環格的 Masque」）：從皮上讀回來的形狀（遮罩、圖示尺寸與偏移、texcoord）照烘；
    --   光環格／飾品欄增益：皮外框讀到了 ⇒ 按鈕自己畫那張（st.normal）、不畫米利邊；這張皮沒有外框（false）⇒ 兩種都不畫；
    --                       讀不到 ⇒ 退回米利 1px 邊。
    --   疊層：外框是底下冷卻格自己的皮 ⇒ 一律不畫米利邊、也不畫外框。都進簽章
    local msqSig = "-"
    local hd = rec.frame
    if hd and hd.msqOn and shape ~= "bars" and not ringOn then
        st.msq = hd.msqShape
        if rec.overlayOf then
            st.noEdge = true
        else
            local nm = st.msq and st.msq.normal
            if nm ~= nil then
                st.noEdge = true
                st.normal = nm or nil
            end
        end
        msqSig = "msq:" .. (st.msq and st.msq.sig or "square") .. (st.noEdge and "" or "+edge")
    end
    -- 自訂文字（M）：圖示形的光環格與飾品欄增益才有（長條本來就有名字；飾品冷卻格的增益疊層是冷卻格，不畫）。
    -- 值全部解成純數字／字串（initializeFrame 裡只查表），整段進簽章 ⇒ 改了換一顆容器（戰鬥中記旗標、脫戰建）
    local labelSig = "-"
    if shape ~= "bars" and not rec.overlayOf and not ringOn then
        local lb = TX.LabelStyle(barKey, id)
        if lb then
            local p, j = TX.LabelPlace(lb.point)
            local lc = lb.color
            st.label = { text = lb.text, font = ns.Media.Font(lb.font), size = lb.size,
                color = { lc.r, lc.g, lc.b, lc.a }, point = p, justify = j, x = lb.x, y = lb.y }
            labelSig = "lb:" .. lb.sig
        end
    end
    -- 圖示的 texcoord（縮放＋非正方形裁切）：正方形時跟尺寸無關，改大小不會白換容器
    st.tc = { ns.Layout.IconTexCoord(st.zoom, w, h, S(barKey, "icon.aspect") ~= "stretch") }
    -- 圓環：圖示是頂端環帶上的小方塊（iconSize × iconSize），照條的縮放裁（同 Decorate 的 ApplyRing）
    if ringOn then st.tc = { ns.Layout.IconTexCoord(st.zoom, st.ring.iconSize, st.ring.iconSize, true) } end
    -- 認哪些法術也進簽章（多法術的光環格：整組排序後串進去；單一法術時就是那個 ID）
    st.ids = CU.AuraIDsOf(rec)
    st.sig = table.concat({
        ovSig, msqSig, rec.filter, CU.AuraIDSig(st.ids), st.zoom, string.format("%.4f,%.4f,%.4f,%.4f", st.tc[1], st.tc[2], st.tc[3], st.tc[4]), st.bsize, C(st.bcolor), C(st.swipe), st.cdFont, st.stFont, st.outline,
        string.format("%.4f", st.scale), tostring(st.hideCD), st.cdSize, C(st.cdColor), st.cdPoint, st.cdX, st.cdY,
        st.decimals, st.lowBelow, C(st.lowColor), st.timeFormat, tostring(st.hideStack), st.stSize, C(st.stColor),
        st.stPoint, st.stX, st.stY, glowSig, labelSig, shapeSig,
    }, "|")
    if barSig then st.sig = st.sig .. "|" .. barSig end
    if ringOn then st.sig = st.sig .. "|" .. ringSig end
    return st
end
CU.AuraStyle = AuraStyle              -- 測試用

-- 物件（formatter、曲線、列舉值）在容器建立前先解好：initializeFrame 裡一次 CreateColor 都不做
local function Warm(st)
    if st.procOnly then return end                  -- 觸發發光疊層：沒有倒數、邊框、陰影，發光的值 ProcStyle 已經解好
    if st.shape == "bars" then
        -- 長條的秒數：整數（跟暴雪的長條一致），不做低秒變色
        st.formatter = ns.Text.PlainFormatter(0)
        local SB = Enum and Enum.StatusBarTimerDirection
        st.remaining = SB and SB.RemainingTime or nil
        local IP = Enum and Enum.StatusBarInterpolation
        st.interp = IP and IP.Immediate or nil
    else
        st.formatter = ns.Text.PlainFormatter(st.decimals, st.timeFormat)
        if st.lowBelow > 0 then st.colorCurve = ColorCurve(st.lowBelow, st.lowColor, st.cdColor) end
    end
    local P = Enum and Enum.DurationTextBindingProperty
    st.remainingProp = P and P.RemainingDuration or 0
    st.inset = (st.bsize > 0) and ns.P.Pixel(st.bsize) or 0
    -- 陰影外擴（Core/Shape.lua 的 ShadowOutset）：形狀不是方形而且有畫襯底時，外擴從襯底那一圈算起
    if st.shadow and ns.Shape then
        local t = (st.ishape and not st.noEdge) and st.inset or 0
        st.shadowX, st.shadowY = ns.Shape.ShadowOutset(st.cellW, st.cellH, t)
    end
end

-- 生效發光（只能從 initializeFrame 呼叫）：按鈕底下自己的子框，圍住 anchor；尺寸用 gl 給的、不讀
-- 層數發光的閘（光環格，gl.stack ＝ N）：一顆透明的 StatusBar 交給 SetApplicationBar(bar, { maxApplications = N })
-- （引擎在安全端把層數寫進去，插件端零讀取；跟 Modules/AuraBar.lua 的層數列同一條路）。條寬 N 段、右緣對齊
-- 發光區的右緣 ⇒ 填到第 N 段才蓋到發光區；裁切框錨在填充貼圖上、發光宿主當裁切框的子孫 ⇒ 層數 ≥ N 才看得到
-- （Core/StackGate.lua 的閘是 SetMinMaxValues(N-1, N)，這裡上下限是引擎定的 0～N，改用「宿主放在最後一段」）。
-- 第 N-1 段的右緣跟發光區左緣之間留 1px：引擎的除法誤差不會露一條邊。發光區 ＝ 格子四邊外擴 StackGate.Margin
-- （按鈕／觸發樣式畫 1.4 倍，每邊多 0.2，外擴量 ≥ 0.4 蓋得住）。
-- 全是我們自己的框、只在 initializeFrame 視窗內建；閘餵過層數之後幾何是秘密的 ⇒ 除了裁切框沒有東西錨在它的
-- 填充貼圖上，閘、裁切框與子孫一律不讀（同 StackGate）。回傳裁切框（發光宿主的父框）；
-- 引擎沒有 SetApplicationBar／拿不到填充貼圖 ⇒ nil，發光不畫（不能退成常亮）
local function StackGateFrame(btn, anchor, gl, level, rec)
    if type(btn.SetApplicationBar) ~= "function" then return nil end
    local n = gl.stack
    local mx, my = ns.StackGate.Margin(gl.w, gl.h)
    local aw, ah = gl.w + 2 * mx, gl.h + 2 * my
    local bar = CreateFrame("StatusBar", nil, btn)
    bar:SetStatusBarTexture(WHITE)
    local fill = bar:GetStatusBarTexture()
    if not fill then return nil end
    fill:SetVertexColor(0, 0, 0, 0)
    bar:SetSize((aw + 1) * n, ah)
    bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", mx, my)
    if level then bar:SetFrameLevel(level) end
    local clip = CreateFrame("Frame", nil, btn)
    clip:SetClipsChildren(true)
    clip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    if level then clip:SetFrameLevel(level) end
    btn:SetApplicationBar(bar, { maxApplications = n })
    rec.stackGated = (rec.stackGated or 0) + 1       -- 測試用
    return clip
end

local function AttachGlow(btn, anchor, gl, level, rec)
    local LCG = ns.MiliUIGlow
    if not (gl and LCG and LCG.PixelGlow_Attach) then return end
    local parent = btn
    if gl.stack then
        parent = StackGateFrame(btn, anchor, gl, level, rec)
        if not parent then return end
        if level then level = level + 1 end          -- 宿主在裁切框上一層
    end
    local f = CreateFrame("Frame", nil, parent)
    if level then f:SetFrameLevel(level) end        -- nil ＝ 子框預設（按鈕＋1）
    local gw, gh = gl.w, gl.h
    if gl.type == "button" or gl.type == "proc" then
        -- 這兩種畫成格子的 1.4 倍（跟 Start 系列一樣）
        local dx, dy = gw * 0.2, gh * 0.2
        f:SetPoint("TOPLEFT", anchor, "TOPLEFT", -dx, dy)
        f:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", dx, -dy)
        gw, gh = gw * 1.4, gh * 1.4
    else
        f:SetAllPoints(anchor)
    end
    f:Show()
    local anim
    if gl.type == "autocast" then
        LCG.AutoCastGlow_Attach(f, gl.color, gl.lines, gl.frequency, 1, gw, gh)
    elseif gl.type == "button" then
        anim = LCG.ButtonGlow_Attach(f, gl.color, gl.frequency, gw, gh)
    elseif gl.type == "proc" then
        anim = LCG.ProcGlow_Attach(f, gl.color, 1, gw, gh)
    elseif gl.type == "border" and ns.Glow and ns.Glow.BorderAttach then
        -- 只變邊框顏色：四張純色貼圖、沒有動畫（Core/Glow.lua 的「只變邊框顏色」）
        ns.Glow.BorderAttach(f, gl.color, gl.thickness)
    else
        LCG.PixelGlow_Attach(f, gl.color, gl.lines, gl.frequency, nil, gl.thickness, gw, gh)
    end
    -- 皮的形狀（AuraStyle 解好的 gl.art）：換成那個形狀的貼圖，還在 initializeFrame 視窗裡
    if gl.art and ns.Glow and ns.Glow.SkinAttached then ns.Glow.SkinAttached(f, gl.art) end
    -- 入場動畫：交給引擎在光環出現時播（我們不 Play）
    if anim and btn.AddAuraShownAnimation then pcall(btn.AddAuraShownAnimation, btn, anim) end
    rec.glowAttached = (rec.glowAttached or 0) + 1
end
CU.AttachGlow = AttachGlow

-- 遮罩（只能從 initializeFrame 呼叫，外面包 pcall）：在按鈕上建一張新的遮罩貼圖、照讀回來的矩形排、掛到圖示上。
-- 包法照 Masque 的預設（CLAMPTOBLACKADDITIVE）
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local function BakeMask(btn, icon, mk)
    local t = btn:CreateMaskTexture()
    if mk.atlas then t:SetAtlas(mk.atlas) else t:SetTexture(mk.file, MASK_WRAP, MASK_WRAP) end
    t:SetSize(mk.w, mk.h)
    t:SetPoint("CENTER", btn, "CENTER", mk.x, mk.y)
    icon:AddMaskTexture(t)
    CU.masksBaked = (CU.masksBaked or 0) + 1          -- 測試用
end

-- 內建圖示形狀（只能從 initializeFrame 呼叫，外面包 pcall）：按鈕上一張形狀遮罩、鋪滿按鈕、掛到圖示上
local function BakeShapeMask(btn, icon, path)
    local t = btn:CreateMaskTexture()
    t:SetTexture(path, MASK_WRAP, MASK_WRAP)
    t:SetAllPoints(btn)
    icon:AddMaskTexture(t)
    CU.shapesBaked = (CU.shapesBaked or 0) + 1        -- 測試用
end

-- 邊框襯底（同 Core/Shape.lua 的畫法）：邊框色的純色貼圖套同一個形狀、每邊大 t、在圖示（ARTWORK）底下
local function BakeUnder(btn, path, t, bc)
    local u = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -7))
    u:SetTexture(WHITE)
    u:SetVertexColor(bc[1], bc[2], bc[3], bc[4])
    u:SetPoint("TOPLEFT", btn, "TOPLEFT", -t, t)
    u:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", t, -t)
    local m = btn:CreateMaskTexture()
    m:SetTexture(path, MASK_WRAP, MASK_WRAP)
    m:SetAllPoints(u)
    u:AddMaskTexture(m)
end

-- 陰影（同 Core/Shape.lua）：襯底更底下、四邊外擴（AuraStyle／Warm 先算好的純數字）
local function BakeShadow(btn, st)
    local s = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
    s:SetTexture(st.shadowPath)
    s:SetVertexColor(0, 0, 0, st.shadow)
    s:SetPoint("TOPLEFT", btn, "TOPLEFT", -st.shadowX, st.shadowY)
    s:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", st.shadowX, -st.shadowY)
end

-- 皮外框（只能從 initializeFrame 呼叫，外面包 pcall）：照讀回來的 Normal 外觀在按鈕本體上畫一張新貼圖。顏色純數字
local function BakeNormal(btn, n)
    local t = btn:CreateTexture(nil, n.layer, nil, n.sub)
    if n.atlas then
        t:SetAtlas(n.atlas)
    else
        t:SetTexture(n.file)
        t:SetTexCoord(n.l, n.r, n.t, n.b)
    end
    t:SetSize(n.w, n.h)
    t:SetPoint("CENTER", btn, "CENTER", n.x, n.y)
    t:SetVertexColor(n.cr, n.cg, n.cb, n.ca)
    t:SetBlendMode(n.blend)
    CU.normalsBaked = (CU.normalsBaked or 0) + 1      -- 測試用
end

-- 按鈕放哪：slot（固定格位）的按鈕不參與 flow layout ⇒ 鋪滿容器；引擎補位（st.cell，見「引擎補位」）的按鈕由
-- flow layout 錨定（暴雪只 SetPoint、不設大小）⇒ 這裡只給大小（尺寸來自設定，不從按鈕讀）
local function Seat(btn, c, st)
    pcall(function()
        local cell = st.cell
        if cell then
            btn:SetSize(cell[1], cell[2])
        else
            btn:ClearAllPoints()
            btn:SetAllPoints(c)
        end
    end)
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitAuraButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    Seat(btn, c, st)

    -- Masque：圖示放 BACKGROUND（皮外框在它上面；Masque 的 Icon 也是這一層）
    local m = st.msq
    local icon = btn:CreateTexture(nil, m and "BACKGROUND" or "ARTWORK")
    -- Masque：照從皮上讀回來的形狀排（尺寸、相對中心的偏移、texcoord、遮罩）；沒有就整格＋條的縮放
    if m then
        icon:SetSize(m.iw, m.ih)
        icon:SetPoint("CENTER", btn, "CENTER", m.ix, m.iy)
        icon:SetTexCoord(m.l, m.r, m.t, m.b)
        if m.mask then pcall(BakeMask, btn, icon, m.mask) end
    else
        icon:SetAllPoints(btn)
        icon:SetTexCoord(st.tc[1], st.tc[2], st.tc[3], st.tc[4])
        if st.maskPath then pcall(BakeShapeMask, btn, icon, st.maskPath) end
    end
    btn:SetIcon(icon)
    if st.shadowPath and st.shadowX then pcall(BakeShadow, btn, st) end

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    -- 轉圈：Cooldown 框吃不了遮罩 ⇒ 照 Masque 自己的做法，轉圈材質換成遮罩那張圖（白色＋alpha 的形狀）、
    -- 框排在遮罩的矩形上。遮罩是圖集（SetSwipeTexture 不收）或讀不到 ⇒ 方形
    local mk = m and m.mask
    if m then
        local rr = mk or { x = m.ix, y = m.iy, w = m.iw, h = m.ih }
        cd:SetSize(rr.w, rr.h)
        cd:SetPoint("CENTER", btn, "CENTER", rr.x, rr.y)
    else
        cd:SetAllPoints(btn)
    end
    cd:SetSwipeTexture((mk and mk.file) or st.maskPath or WHITE)    -- 內建形狀：轉圈換成形狀遮罩那張
    cd:SetSwipeColor(st.swipe[1], st.swipe[2], st.swipe[3], st.swipe[4])
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    -- 方向跟暴雪的增益圖示一致（CooldownViewer.xml 的增益 item 是 reverse="true"）：剛拿到是亮的、暗色隨時間長滿。
    -- 模板預設 false 是「暗色蓋剩餘那段」，剛拿到增益整格全暗（玩家回報看不清圖示，2026-10-18）。
    -- 圓環版（InitAuraRingButton）另有自己的方向（亮的那截＝剩餘時間），不在此列
    cd:SetReverse(true)
    btn:SetDurationCooldown(cd)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((cd:GetFrameLevel() or 1) + 2)

    -- Masque 的皮外框：按鈕本體上的一張貼圖（圖示 BACKGROUND 之上、轉圈與 ov 的文字子框之下，跟 Masque 對一般按鈕的疊法一樣）
    if st.normal then pcall(BakeNormal, btn, st.normal) end

    local t = st.inset
    if t > 0 and not st.noEdge and st.maskPath then
        pcall(BakeUnder, btn, st.maskPath, t, st.bcolor)  -- 內建形狀：邊框是襯底
    elseif t > 0 and not st.noEdge then          -- Masque：外框是皮的（上面那張，或疊層底下冷卻格自己的）
        local bc = st.bcolor
        local function Edge()
            local e = NoSnap(ov:CreateTexture(nil, "OVERLAY", nil, 7))
            e:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
            return e
        end
        local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
        top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0); top:SetHeight(t)
        bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(t)
        left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -t); left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, t); left:SetWidth(t)
        right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -t); right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, t); right:SetWidth(t)
    end

    local s = st.scale
    if not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.cdFont, st.cdSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.cdColor[1], st.cdColor[2], st.cdColor[3], st.cdColor[4])
        fs:SetPoint(st.cdPoint, btn, st.cdPoint, st.cdX * s, st.cdY * s)
        local opts = st.formatter and { textFormatter = st.formatter } or {}
        if st.colorCurve then opts.textColor = { curve = st.colorCurve, property = st.remainingProp } end
        -- 備援也包 pcall（SetDurationText 內部可能碰到被污染時不給存取的表）
        if not pcall(btn.SetDurationText, btn, fs, next(opts) and opts or nil) then
            if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
                pcall(btn.SetDurationText, btn, fs)
            end
        end
    end

    -- 層數：**絕不傳 formatter**（暴雪會在 Lua 對秘密層數跑 FormatNumber，整個容器當掉）
    if not st.hideStack and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.stSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint(st.stPoint, btn, st.stPoint, st.stX * s, st.stY * s)
        pcall(btn.SetApplicationCount, btn, fs)
    end

    -- 自訂文字（M）：玩家打的明文，直接 SetText（自己的 FontString，不經暴雪）；錨點同倒數（圖示內的那個角／邊）
    local lb = st.label
    if lb then
        -- 字放在 ov 上面一層的子框：ov 的 OVERLAY 7 是米利邊框，同框同層誰在上不保證（子框一定蓋過父框的貼圖）
        local lf = CreateFrame("Frame", nil, ov)
        lf:SetAllPoints(btn)
        lf:SetFrameLevel((ov:GetFrameLevel() or 1) + 3)
        local fs = lf:CreateFontString(nil, "OVERLAY")
        fs:SetFont(lb.font, lb.size * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetWordWrap(false)
        fs:SetJustifyH(lb.justify)
        fs:SetTextColor(lb.color[1], lb.color[2], lb.color[3], lb.color[4])
        fs:SetPoint(lb.point, btn, lb.point, lb.x * s, lb.y * s)
        fs:SetText(lb.text)
        rec.labelsBaked = (rec.labelsBaked or 0) + 1      -- 測試用
    end

    -- 生效發光：按鈕底下自己的子框（只在這個視窗內建得了），尺寸用 st 給的、不讀
    AttachGlow(btn, btn, st.glow, (ov:GetFrameLevel() or 1) + 1, rec)
    rec.inits = (rec.inits or 0) + 1
end

-- 1px 邊（四條純色細條，跟圖示版的光環格同一套）：畫在 parent 上、圍住 region
local function Edges(parent, region, t, bc)
    local function Edge()
        local e = NoSnap(parent:CreateTexture(nil, "OVERLAY", nil, 7))
        e:SetColorTexture(bc[1], bc[2], bc[3], bc[4])
        return e
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0); top:SetHeight(t)
    bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(t)
    left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -t); left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, t); left:SetWidth(t)
    right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -t); right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, t); right:SetWidth(t)
end

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。光環長條：圖示（h×h，條的「長條」節決定在哪一邊）＋
-- 整格寬的 StatusBar 交給 SetDurationBar（剩餘時間往下縮，值與上限都不經 Lua）＋秒數 SetDurationText＋
-- 層數 SetApplicationCount（**不給格式器**）＋名字（明文，自己寫）。不 CreateColor、不掛 script、顏色純數字、
-- 尺寸全部來自 st（不從按鈕讀）
local function InitAuraBarButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    Seat(btn, c, st)
    local H, gap, side, s = st.isz or st.bh, st.bgap, st.side, st.scale
    local vert = st.vert

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(H, H)
    if vert then
        if side == "RIGHT" then icon:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0) else icon:SetPoint("TOP", btn, "TOP", 0, 0) end
    elseif side == "RIGHT" then icon:SetPoint("RIGHT", btn, "RIGHT", 0, 0) else icon:SetPoint("LEFT", btn, "LEFT", 0, 0) end
    local z = st.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    if side == "NONE" then icon:SetAlpha(0) end
    local bm, atl = st.blizz and st.bm, st.atlas
    if bm then
        -- 暴雪樣式：圓角遮罩（新建的遮罩貼圖，按鈕上）
        local mask = btn.CreateMaskTexture and btn:CreateMaskTexture()
        if mask then
            mask:SetAtlas(atl.mask)
            mask:SetAllPoints(icon)
            icon:AddMaskTexture(mask)
        end
    end
    btn:SetIcon(icon)

    local bar = CreateFrame("StatusBar", nil, btn)
    if bm then
        -- 暴雪樣式（只有橫向）：條身高照等比、垂直置中（同 Decorate.ApplyBarGeometry 的暴雪分支）
        bar:SetHeight(bm.thick)
        if side == "NONE" then
            bar:SetPoint("LEFT", btn, "LEFT", 0, 0)
            bar:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        elseif side == "RIGHT" then
            bar:SetPoint("LEFT", btn, "LEFT", 0, 0)
            bar:SetPoint("RIGHT", btn, "RIGHT", -(H + gap), 0)
        else
            bar:SetPoint("LEFT", btn, "LEFT", H + gap, 0)
            bar:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        end
    elseif side == "NONE" then
        bar:SetAllPoints(btn)
    elseif vert and side == "RIGHT" then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, H + gap)
    elseif vert then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -(H + gap))
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    elseif side == "RIGHT" then
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -(H + gap), 0)
    else
        bar:SetPoint("TOPLEFT", btn, "TOPLEFT", H + gap, 0)
        bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    end
    if vert then bar:SetOrientation("VERTICAL") end
    bar:SetReverseFill(st.rev and true or false)          -- 新建的條：只換填充起點，引擎寫的值不碰
    bar:SetStatusBarTexture(st.btex)
    NoSnap(bar)                                           -- 填充跟 1px 邊相接：不貼齊
    local fill = bar:GetStatusBarTexture()
    if fill then
        local gr = st.bgrad
        if gr and fill.SetGradient then
            fill:SetVertexColor(1, 1, 1, 1)
            if not pcall(fill.SetGradient, fill, gr.o, gr.c1, gr.c2) then
                fill:SetVertexColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4])
            end
        else
            fill:SetVertexColor(st.bfill[1], st.bfill[2], st.bfill[3], st.bfill[4])
        end
    end
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    if bm then
        -- 暴雪樣式的底：圖集、右下凸出的陰影（等比偏移）
        bg:SetPoint("TOPLEFT", bar, "TOPLEFT", bm.bgL, bm.bgT)
        bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", bm.bgR, bm.bgB)
        bg:SetAtlas(atl.bg)
    else
        bg:SetAllPoints(bar)
        bg:SetTexture(WHITE)
    end
    bg:SetVertexColor(st.bbg[1], st.bbg[2], st.bbg[3], st.bbg[4])
    if st.spark and fill then
        local pip = bar:CreateTexture(nil, "OVERLAY")
        if bm then
            -- 暴雪樣式的火花：圖集、CENTER 錨填充移動的那一端（同 Decorate.AnchorOwnPip）
            pip:SetAtlas(atl.pip)
            pip:SetSize(st.pipW, st.pipH)
            pip:SetPoint("CENTER", fill, st.rev and "LEFT" or "RIGHT", 0, -st.pipY)
        else
            pip:SetTexture(WHITE)
            pip:SetVertexColor(1, 1, 1, 0.9)
            if vert then pip:SetHeight(2) else pip:SetWidth(2) end
            AnchorPip(pip, fill, vert, st.rev)
        end
    end
    -- 不自己 SetMinMaxValues／SetValue：剩餘時間由引擎寫（CustomAuraButtonDurationBarOptions：interpolation、direction）
    local opts = {}
    if st.remaining then opts.direction = st.remaining end
    if st.interp then opts.interpolation = st.interp end
    btn:SetDurationBar(bar, opts)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
    local t = st.inset
    if bm then
        -- 暴雪樣式：不畫邊框，圖示疊暴雪的外框圖（ov 上、文字底下）
        if side ~= "NONE" then
            local art = ov:CreateTexture(nil, "OVERLAY", nil, -8)
            art:SetAtlas(atl.overlay)
            art:SetPoint("TOPLEFT", icon, "TOPLEFT", -bm.ovX, bm.ovY)
            art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", bm.ovX, -bm.ovY)
        end
    elseif t > 0 then
        if side ~= "NONE" then Edges(ov, icon, t, st.bcolor) end
        Edges(ov, bar, t, st.bcolor)
    end

    -- 名字：主法術的名字（明文），按鈕只在光環存在時顯示 ⇒ 名字跟著出現
    if st.showName and not vert and st.name ~= "" then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.nameFont, st.nameSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("LEFT", bar, "LEFT", (4 + st.nameX) * s, st.nameY * s)
        fs:SetPoint("RIGHT", bar, "RIGHT", (st.nameX - st.timeSize * 3) * s, st.nameY * s)
        fs:SetJustifyH("LEFT")
        pcall(fs.SetWordWrap, fs, false)
        fs:SetText(st.name)
    end

    -- 秒數：引擎寫（整數 formatter 在容器建立前建好）；失敗只丟文字、不丟條
    if st.showTime and not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.timeFont, st.timeSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        local tc = st.timeColor
        fs:SetTextColor(tc[1], tc[2], tc[3], tc[4])
        -- 位置：AuraStyle 解好的（Text.BarTimePlace：預設橫向右緣、直向頂端，逐法術可蓋錨點與偏移）
        fs:SetJustifyH(st.timeJustify)
        fs:SetPoint(st.timePoint, bar, st.timePoint, st.timeX * s, st.timeY * s)
        if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
            pcall(btn.SetDurationText, btn, fs)
        end
    end

    -- 層數：照 Text.ApplyBar（長條錨點，角落往內縮 1px ＋層數的 X／Y 位移）。**絕不傳 formatter**
    if st.showStacks and not st.hideStack and side ~= "NONE" and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.barStack * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint(st.stBarPoint, icon, st.stBarPoint, (st.stBarIX + st.stX) * s, (st.stBarIY + st.stY) * s)
        pcall(btn.SetApplicationCount, btn, fs, {})
    end

    -- 生效發光：圖示那一格（沒有圖示時整格）
    AttachGlow(btn, side ~= "NONE" and icon or btn, st.glow, (ov:GetFrameLevel() or 1) + 1, rec)
    rec.inits = (rec.inits or 0) + 1
end
CU.InitAuraBarButton = InitAuraBarButton      -- 測試用

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。光環格畫成一圈（見「光環格畫成圓環」）：軌道貼圖＋環形 swipe 的 Cooldown
-- 交給 SetDurationCooldown（剩餘時間由引擎驅動）＋倒數／層數錨在這一圈頂端的環帶上。不 CreateColor、不掛 script、
-- 顏色純數字、尺寸全部來自 st（不從按鈕讀）。邊框、發光、Masque、自訂文字一律不畫
local function InitAuraRingButton(btn, c, st, rec)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, true)          -- 讓暴雪自己的光環提示照常出現
    pcall(function()
        btn:ClearAllPoints()
        btn:SetAllPoints(c)                              -- slot 的按鈕不參與 flow layout
    end)
    local rg, s = st.ring, st.scale

    -- 軌道（深色底環）：按鈕本體最底層，按鈕跟著光環出現 ⇒ 光環不在時只剩占位那一圈軌道（UpdatePlaceholder）
    local track = btn:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(btn)
    track:SetTexture(rg.path)
    track:SetVertexColor(rg.track[1], rg.track[2], rg.track[3], rg.track[4])

    -- 進度：環形 swipe。方向跟暴雪增益 item 的圓環一致（Decorate.ReapplyRingCore：SetReverse(false)，亮的部分＝剩餘時間）
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:SetSwipeTexture(rg.path)
    cd:SetSwipeColor(rg.fill[1], rg.fill[2], rg.fill[3], rg.fill[4])
    cd:SetReverse(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    btn:SetDurationCooldown(cd)

    -- 圖示：引擎要寫圖示，一定要給；畫在 Cooldown 上面一層的子框（同 Decorate 的 ringIcon）。
    -- 沒開「顯示法術圖示」⇒ 子框 alpha 0（引擎哪天對圖示 SetAlpha 也露不出來）
    local lvl = cd:GetFrameLevel() or 1
    local iconF = CreateFrame("Frame", nil, btn)
    iconF:SetAllPoints(btn)
    iconF:SetFrameLevel(lvl + 1)
    local icon = iconF:CreateTexture(nil, "ARTWORK")
    if rg.showIcon then
        icon:SetSize(rg.iconSize, rg.iconSize)
        icon:SetPoint("CENTER", btn, "TOP", 0, -rg.thick / 2)
    else
        icon:SetAllPoints(btn)
        iconF:SetAlpha(0)
    end
    icon:SetTexCoord(st.tc[1], st.tc[2], st.tc[3], st.tc[4])
    btn:SetIcon(icon)

    local ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel(lvl + 2)

    -- 倒數：照 InitAuraButton（formatter、低秒色曲線在 Warm 建好），錨點換成這一圈頂端的環帶（Layout.RingTextPlace）
    if not st.hideCD and btn.SetDurationText then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.cdFont, st.cdSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.cdColor[1], st.cdColor[2], st.cdColor[3], st.cdColor[4])
        fs:SetPoint(rg.cdPoint, btn, "TOP", rg.cdX * s, rg.y * s)
        local opts = st.formatter and { textFormatter = st.formatter } or {}
        if st.colorCurve then opts.textColor = { curve = st.colorCurve, property = st.remainingProp } end
        if not pcall(btn.SetDurationText, btn, fs, next(opts) and opts or nil) then
            if not (st.formatter and pcall(btn.SetDurationText, btn, fs, { textFormatter = st.formatter })) then
                pcall(btn.SetDurationText, btn, fs)
            end
        end
    end

    -- 層數：接在倒數右邊（同 Text.ApplyRing 的估算偏移，不錨在倒數那顆字上）。**絕不傳 formatter**
    if not st.hideStack and btn.SetApplicationCount then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetFont(st.stFont, st.stSize * s, st.outline)
        pcall(fs.SetIgnoreParentScale, fs, true)
        fs:SetTextColor(st.stColor[1], st.stColor[2], st.stColor[3], st.stColor[4])
        fs:SetPoint("LEFT", btn, "TOP", rg.extraX * s, rg.y * s)
        pcall(btn.SetApplicationCount, btn, fs)
    end
    rec.inits = (rec.inits or 0) + 1
    rec.ringInits = (rec.ringInits or 0) + 1          -- 測試用
end
CU.InitAuraRingButton = InitAuraRingButton    -- 測試用

local function BuildContainer(rec, st)
    local h = rec.frame
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    c:SetAllPoints(h)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 slot 之前、SetEnabled 最後（本套組實跑過的順序）
    c:SetUnit("player")
    local handler = function(err)
        rec.lastError = tostring(err)
        if ns.ReportError then ns.ReportError(err) end
    end
    local include = {}
    for _, id in ipairs(st.ids or { rec.spellID }) do include[id] = true end
    local init = st.procOnly and CU.InitProcButton
        or (st.shape == "bars") and InitAuraBarButton or (st.shape == "rings") and InitAuraRingButton or InitAuraButton
    c:AddAuraSlot("slot", rec.filter, {
        candidateFilters = { includeSpellIDs = include },
        initializeFrame = function(btn)
            xpcall(init, handler, btn, c, st, rec)
        end,
    })
    -- ⚠ 不對容器掛任何 script（forbidden intrinsic）；重新可見的補踢掛在持有框上
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

-- 簽章對上容器：同簽章不動；換了就從池子拿（沒有才建）。戰鬥中只記旗標。
-- 池子、目前的容器與簽章記在**持有框**上（一種 kind 一顆持有框）；rec.container／sig／containers 是目前那顆的鏡像
local function EnsureContainer(rec, barKey, w, h)
    local holder = rec.frame
    if not holder then return end
    -- 圓環條上的格：圈數與貼圖照最後一次放格的（CU.Place 記在 rec.placeRing；脫戰補建也用這份）
    local st = AuraStyle(rec, barKey, w, h, rec.shape, rec.placeRing)
    rec.wantSig = st.sig
    if holder.sig == st.sig and holder.container then return end
    -- 一個法術都認不到（裝備欄的增益解不出來）：不建，舊的收起來。空的 includeSpellIDs 不保證是「什麼都不收」
    if #st.ids == 0 then
        if not holder.container then return end
        if InCombatLockdown() then
            pendingBuild[rec] = true
            ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
            return
        end
        pendingBuild[rec] = nil
        pcall(holder.container.Hide, holder.container)
        holder.container, holder.sig = nil, nil
        rec.container, rec.sig = nil, nil
        return
    end
    if InCombatLockdown() then
        pendingBuild[rec] = true
        ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
        return
    end
    pendingBuild[rec] = nil
    holder.containers = holder.containers or {}
    local old = holder.container
    local c = holder.containers[st.sig]
    if c then
        pcall(c.Show, c)
        Kick(c)
    else
        Warm(st)
        local ok, built = pcall(BuildContainer, rec, st)
        if not ok or not built then
            rec.lastError = tostring(built)
            if ns.ReportError then ns.ReportError(built) end
            return
        end
        c = built
        holder.containers[st.sig] = c
        CU.builds = CU.builds + 1
    end
    if old and old ~= c then pcall(old.Hide, old) end
    holder.container, holder.sig = c, st.sig
    rec.container, rec.sig, rec.containers = c, st.sig, holder.containers
end
CU.EnsureContainer = EnsureContainer

------------------------------------------------------------
-- 飾品欄增益（rec.slotBuff）
--
-- 存檔 { kind = "slotbuff", slot = 13|14, buff = N }，New 把它變成光環格（kind = "aura"、filter HELPFUL）。差別只有：
--   * 認的法術：CU.AuraIDsOf → Catalog.SlotBuffIDs(slot, N)，照現在裝的飾品解（暴雪 EquipSlotTracked 的
--     linkedSpellIDs；第 1 個退使用效果）。換飾品（PLAYER_EQUIPMENT_CHANGED → Catalog 作廢快取 → 重排）⇒
--     放格時 rec.spellID 換成新的第一個、簽章（AuraStyle 帶 ids）變了換一顆容器；戰鬥中只記旗標、脫戰建。
--   * 解不出來（空格、這件沒有可追蹤的增益、存了第 3 個而這件只有 1 個）：不建容器（EnsureContainer 的空 ids 分支）、
--     占位照畫（下面兩支的貼圖：飾品圖示，空格用欄位空格圖），設定頁是問號格（Catalog.CustomInfo）。不報錯。
--   * 占位圖示用飾品圖示、長條占位的名字用增益名（解不出來用飾品名）
------------------------------------------------------------
local function SlotBuffPlaceholder(rec)
    local sb = rec.slotBuff
    local C = ns.Catalog
    local itemID = C.SlotItemID and C.SlotItemID(sb.slot)
    local tex = itemID and Plain(Try(C_Item and C_Item.GetItemIconByID, itemID)) or nil
    if not tex then
        local token = C.EQUIP_SLOT_NAME and C.EQUIP_SLOT_NAME[sb.slot]
        if token and _G.GetInventorySlotInfo then tex = Plain(select(2, Try(_G.GetInventorySlotInfo, token))) end
    end
    local name = rec.spellID and Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or nil
    if not name then
        name = (itemID and Plain(Try(C_Item and C_Item.GetItemNameByID, itemID))) or (C.SlotName and C.SlotName(sb.slot)) or ""
    end
    return tex or QUESTION, name
end
CU.SlotBuffPlaceholder = SlotBuffPlaceholder     -- 測試用

-- 占位畫什麼：光環格是主法術的圖示與名字；飾品欄增益見上
local function PlaceholderLook(rec)
    if rec.slotBuff then return SlotBuffPlaceholder(rec) end
    return Plain(Try(C_Spell and C_Spell.GetSpellTexture, rec.spellID)) or QUESTION,
        Plain(Try(C_Spell and C_Spell.GetSpellName, rec.spellID)) or ""
end

-- 光環長條的占位：去飽和圖示＋空條（底色）＋灰名字，畫在持有框上（按鈕出現自然蓋住）。
-- 排法照 Decorate.ApplyBarGeometry（圖示一邊 h×h、間距、其餘是條身）；排法變了才重排，重排走 ns.Write
-- （持有框整條鏈是保護框，戰鬥中記帳）
-- 光環格的占位畫不畫：照這一格生效的「增益不在時」（逐法術覆寫 emptyMode ＞ 條層 layout.emptyMode，判準 Layout.SpellEmptyMode）。
-- 光環格所在的條「收合」不成立（forced）⇒ 只剩留空位（不畫，格子照留）／暗圖示（圖示類畫去飽和圖示、長條類畫空長條）。
-- 條層存著收合時退回圖示類暗圖示、長條類照舊欄位 emptyStyle（Layout.BarEmptyMode）——跟 Core/Bars.lua 的暴雪增益同一套。
-- 存檔的 e.placeholder 已經不影響畫面（舊欄位）
local function WantPlaceholder(rec, barKey, shape)
    local b = ns.DB and ns.DB.BarTable and ns.DB.BarTable(barKey)
    local layout = type(b) == "table" and type(b.layout) == "table" and b.layout or {}
    local barMode = ns.Layout.BarEmptyMode(layout.emptyMode, true, shape == "bars", layout.emptyStyle)
    local own = rec.cooldownID ~= nil and ns.SpellSetting(barKey, rec.cooldownID, "emptyMode") or nil
    return (ns.Layout.SpellEmptyMode(own, barMode, true)) == "dim"
end
CU.WantPlaceholder = WantPlaceholder  -- 測試用

local function UpdateBarPlaceholder(rec, barKey, w, h)
    local hd = rec.frame
    local e = rec.entry
    local function HideAll()
        if hd.phBG then hd.phBG:Hide(); hd.phIcon:Hide(); hd.phName:Hide() end
        hd.phSig = nil
    end
    if not (e and WantPlaceholder(rec, barKey, "bars")) then HideAll() return end
    local bar = ns.Setting(barKey, "bar")
    bar = type(bar) == "table" and bar or {}
    local side = bar.iconSide
    if side ~= "RIGHT" and side ~= "NONE" then side = "LEFT" end
    local vert = bar.vertical and true or false        -- 直向（F8c）：圖示 w×w 在上／下、名字不畫
    local H = vert and (tonumber(w) or 20) or (tonumber(h) or 20)
    local gap = ns.Layout.Snap(tonumber(bar.iconGap) or 0)
    -- 名字：「長條」節 ⊕ 這一格的覆寫（Text.SpellText 的 "barName"，同光環長條本體）；右緣留的字寬照這一格的秒數字級
    local nt = ns.Text.SpellText(barKey, rec.cooldownID, "barName")
    local tt = ns.Text.SpellText(barKey, rec.cooldownID, "barTime")
    local nameSize, timeSize = tonumber(nt.size) or 12, tonumber(tt.size) or 12
    local nx, ny = ns.Text.BarOffset(bar.nameOffset)
    local showName = (nt.show and not vert) and true or false
    local font = ns.Media.ElementFont(nt.font, ns.Setting(barKey, "font"))
    local outline = ns.Setting(barKey, "outline") or ""
    local tex, name = PlaceholderLook(rec)
    local z = tonumber(ns.Setting(barKey, "icon.zoom")) or 0
    -- 暴雪樣式（Decorate.BarLook）：空條畫成暴雪的底（圖集＋右下陰影）、細條身垂直置中；圖示不套遮罩（占位是暗圖示，看不出圓角）
    local D = ns.Decorate
    local bm = (D and D.BarLook and D.BarLook(bar) == "blizzard") and D.BlizzBarMetrics(H) or nil
    local bgc = bm and { 1, 1, 1, 1 } or RGBA(bar.bgColor, 0.1, 0.1, 0.1, 0.8)
    local sig = table.concat({ side, string.format("%.2f,%.2f", H, gap), tostring(font), outline, tostring(tex), name, z,
        nameSize, timeSize, nx, ny, tostring(showName),
        string.format("%.3f,%.3f,%.3f,%.3f", bgc[1], bgc[2], bgc[3], bgc[4]), tostring(vert), tostring(bm and bm.thick) }, "|")
    if hd.phSig == sig and hd.phBG and hd.phBG:IsShown() then return end
    hd.phSig = sig
    if not hd.phBG then
        hd.phBG = hd:CreateTexture(nil, "BACKGROUND")
        hd.phIcon = hd:CreateTexture(nil, "ARTWORK")
        hd.phName = hd:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(hd.phName, 12, "OUTLINE")         -- 先有字型才能 SetText
    end
    ns.Write(hd, function(fr)
        local bgT, icon, fs = fr.phBG, fr.phIcon, fr.phName
        bgT:ClearAllPoints()
        if bm then
            -- 條身（橫向）垂直置中、高 thick，底再照等比偏移往外凸
            local inset = (H - bm.thick) / 2
            local x1, x2 = 0, 0
            if side == "RIGHT" then x2 = -(H + gap) elseif side ~= "NONE" then x1 = H + gap end
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", x1 + bm.bgL, -inset + bm.bgT)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", x2 + bm.bgR, inset + bm.bgB)
        elseif vert and side == "RIGHT" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, H + gap)
        elseif vert and side ~= "NONE" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, -(H + gap))
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
        elseif side == "RIGHT" then
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -(H + gap), 0)
        elseif side == "NONE" then
            bgT:SetAllPoints(fr)
        else
            bgT:SetPoint("TOPLEFT", fr, "TOPLEFT", H + gap, 0)
            bgT:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 0, 0)
        end
        if bm then
            bgT:SetAtlas(D.BLIZZ_ATLAS.bg)
        else
            bgT:SetTexture(WHITE)
            bgT:SetTexCoord(0, 1, 0, 1)                 -- 從暴雪樣式換回來：圖集的裁切座標不留
        end
        bgT:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4])
        bgT:Show()
        icon:ClearAllPoints()
        icon:SetSize(H, H)
        if vert then
            if side == "RIGHT" then icon:SetPoint("BOTTOM", fr, "BOTTOM", 0, 0) else icon:SetPoint("TOP", fr, "TOP", 0, 0) end
        elseif side == "RIGHT" then icon:SetPoint("RIGHT", fr, "RIGHT", 0, 0) else icon:SetPoint("LEFT", fr, "LEFT", 0, 0) end
        icon:SetTexture(tex)
        icon:SetTexCoord(z, 1 - z, z, 1 - z)
        icon:SetDesaturated(true)
        icon:SetAlpha(0.35)
        icon:SetShown(side ~= "NONE")
        ns.Text.SetFont(fs, nameSize, outline, font)
        fs:SetTextColor(0.6, 0.6, 0.6, 1)
        local s = ns.Text.PixelScale()
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", bgT, "LEFT", (4 + nx) * s, ny * s)
        fs:SetPoint("RIGHT", bgT, "RIGHT", (nx - timeSize * 3) * s, ny * s)
        if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
        fs:SetText(name)
        fs:SetShown(showName)
    end, "placeholder")
end

------------------------------------------------------------
-- 光環格的 Masque（圖示類的條，ns.Masque.Mode(條) == "masque"）
--
-- AuraButton 建好就 forbidden，Masque 碰不到按鈕 ⇒ 全部在**我們自己的普通框**上做，再把結果烘進按鈕：
--   1. 占位（hd.ph = { frame, tex }）：獨立的框，交給 Decorate.ApplyPlaceholder（跟暴雪增益的占位同一支，Masque 模式下
--      它把框交給同一個群組）。米利模式也是這顆框（去飽和 0.35 圖示＋米利邊框，跟以前一樣）。占位關掉 ⇒ 增益不在時什麼都沒有。
--   2. 探針（hd.skin = { frame, icon, normal }）：**永遠看不見**（框 SetAlpha(0)）的普通框，regions 給一張透明 Icon（顏色
--      0,0,0,0、貼圖 alpha 1——alpha 0 會被 Masque 當成空格，換空格外框）＋一張我們建的 Normal，交給同一個群組、同一個
--      型別（TypeFor）。Masque 照樣對它套皮，我們只讀：
--        Icon   遮罩（GetNumMaskTextures／GetMaskTexture＋GetAtlas 或 GetTextureFilePath／GetTextureFileID）、矩形（錨點＋尺寸
--               換算成相對探針中心）、texcoord
--        Normal 皮外框那張貼圖（Masque 的公開 API GetNormal——它多半另建一張、把我們給的藏起來）：圖集／檔案、矩形、texcoord、
--               vertex color、blend mode、draw layer、有沒有顯示（沒顯示 ＝ 這張皮沒有外框，是讀得到的結果）
--      存成純數字／字串（hd.msqShape）⇒ AuraStyle 進簽章、InitAuraButton 照烘。全部 pcall＋Plain；Icon 讀不到 ⇒ 方形圖示，
--      Normal 讀不到 ⇒ 按鈕退回米利 1px 邊（不會變成沒框）。
--      Masque 換皮（回呼讓 Masque.Generation 加一）或格子尺寸變了才重讀；沒讀到遮罩時每輪看一眼有沒有冒出來（套皮可能晚到）。
--      米利模式不建（建過的從群組拿掉、收起來）。
--   3. 按鈕（InitAuraButton）：圖示照讀回來的形狀排＋新的遮罩貼圖；轉圈材質換成遮罩那張、排在遮罩矩形；皮外框是**按鈕自己的**
--      一張貼圖（照讀回來的 Normal 畫，跟按鈕一起出現／消失），建在按鈕本體上——跟 Masque 對一般按鈕的疊法一樣：
--      圖示（BACKGROUND）< 皮外框（讀回來的層，至少 ARTWORK）< 轉圈（子框）< ov 的倒數／層數字（再上一層子框）。
--   4. 生效發光：交給 Masque 的那顆框（探針、或疊層底下的冷卻格；hd.msqFrame）的皮是非方形 ⇒ AuraStyle 照 Core/Glow.lua
--      的映射換樣式＋貼圖（gl.art，進簽章），AttachGlow 在 Attach 之後換貼圖（ns.Glow.SkinAttached）。換皮 ⇒ 簽章變 ⇒ 換容器。
--   飾品冷卻格的增益疊層（rec.overlayOf）不建探針、不畫外框：底下的冷卻格自己就交給 Masque（Decorate.Apply），外框是它的；
--   疊層只從冷卻格的 Icon 讀回形狀、不畫米利邊（rec.msqSkinned ＝ 冷卻格現在是 Masque 在畫）。
--
-- 保護鏈：占位與探針都是 parent＝條容器 c、直接 SetPoint 到 c（同一個矩形），**不錨持有框、持有框也不錨它們** ⇒
-- 不是保護框、戰鬥中照寫（不走 ns.Write）。收起來（HideRec）、搬條（Retire）時跟著持有框一起收。
-- 層級（同一個 strata，跨父層比得出高低；c ＝ 條容器的層級）：
--   占位、探針 c＋0（探針看不見，層級無所謂）→ 持有框 c＋2 → 容器 c＋3 → 按鈕 c＋4（圖示、皮外框都在它身上）
--   → 按鈕的 Cooldown c＋5 → 按鈕裡的 ov（倒數、層數、米利邊）c＋7 → 生效發光 c＋8（像素發光的裁切子框 c＋9）
------------------------------------------------------------
local PH_LIFT = 0
CU.PH_LIFT = PH_LIFT
-- 圓環條：持有框依圈數往上墊（內圈高），同 Core/Decorate.lua 的 RING_LIFT
local RING_LIFT = 40
CU.RING_LIFT = RING_LIFT

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end
local function Str(v)
    v = Plain(v)
    return (type(v) == "string" and v ~= "") and v or nil
end

-- 自己的框（占位、探針）放到 c 的 r 上：直接錨容器，位置沒變不重寫
local function PlacePart(part, c, r, lift)
    local f = part.frame
    local lvl = (c:GetFrameLevel() or 1) + lift
    local sig = table.concat({ tostring(c), r.x, r.y, r.w, r.h, lvl }, "|")
    if part.posSig ~= sig then
        part.posSig = sig
        if f:GetParent() ~= c then f:SetParent(c) end
        f:SetFrameLevel(lvl)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)     -- ⚠ 錨容器，不錨持有框
        f:SetSize(r.w, r.h)
    end
    f:Show()
end

local function HideParts(hd)
    if not hd then return end
    if hd.ph then hd.ph.frame:Hide() end
    if hd.skin then hd.skin.frame:Hide() end
end
CU.HideParts = HideParts

-- 從自己的框讀回 Masque 套上去的形狀（ReadShape／AssetOf）在 Core/MasqueShape.lua：按鍵鏡射的閃光（Core/Keybinds.lua）也用同一支
local function ReadShape(...) return ns.MasqueShape.ReadShape(...) end
local function AssetOf(t) return ns.MasqueShape.AssetOf(t) end
CU.ReadShape = ReadShape              -- 測試用

-- 形狀快取（cache.msqShape／shapeGen／shapeSize）：Masque 換過設定、尺寸變了才重讀；沒遮罩時看一眼有沒有冒出來。
-- normalOf：要讀皮外框時，回傳那張貼圖的函式（探針用；疊層不讀）
local function ShapeFor(cache, frame, icon, w, h, normalOf)
    local M = ns.Masque
    local g = M and M.Generation and M.Generation() or 0
    local size = tostring(w) .. "x" .. tostring(h)
    local stale = cache.shapeGen ~= g or cache.shapeSize ~= size
    if not stale and not (cache.msqShape and cache.msqShape.mask) then
        stale = (Num(Try(icon.GetNumMaskTextures, icon)) or 0) > 0
    end
    -- 外框也一樣：上次沒讀到（nil／false），現在那張貼圖顯示著而且有貼圖 ⇒ 重讀（套皮晚到）
    if not stale and normalOf and not (cache.msqShape and type(cache.msqShape.normal) == "table") then
        local nt = normalOf()
        if nt and Plain(Try(nt.IsShown, nt)) == true then
            local _, f = AssetOf(nt)
            stale = f ~= nil or Str(Try(nt.GetAtlas, nt)) ~= nil
        end
    end
    if stale then
        cache.msqShape = ReadShape(frame, icon, w, h, normalOf and normalOf() or nil)
        cache.shapeGen, cache.shapeSize = g, size
    end
    return cache.msqShape
end

-- 探針（光環格與飾品欄增益；圖示類的條）。結果記在持有框上：hd.msqOn（Masque 在畫這一格）、hd.msqShape（形狀）
local function SyncSkinLayer(rec, c, r, barKey)
    local hd = rec.frame
    local M = ns.Masque
    local L = hd.skin
    local skinned = false
    -- 圓環條（rec.placeRing）不進 Masque 群組（跟暴雪 item 在圓環條上一樣）：探針收起來、按鈕不烘皮
    if rec.shape ~= "bars" and not rec.placeRing and M and M.Mode and M.Mode(barKey) == "masque" then
        if not L then
            local f = CreateFrame("Frame", nil, c)
            f:EnableMouse(false)
            f:SetAlpha(0)                                   -- 永遠看不見：只當 Masque 的參考
            local icon = f:CreateTexture(nil, "BACKGROUND")
            icon:SetAllPoints(f)
            icon:SetColorTexture(0, 0, 0, 0)
            local normal = f:CreateTexture(nil, "ARTWORK")
            normal:SetAllPoints(f)
            L = { frame = f, icon = icon, normal = normal }
            hd.skin = L
        end
        PlacePart(L, c, r, PH_LIFT)
        skinned = M.Sync(L, L.frame, { Icon = L.icon, Normal = L.normal }, M.TypeFor(barKey), r.w, r.h)
    elseif L and L.msqButton and M then
        M.Release(L)
    end
    if not skinned then
        -- 米利模式、或 Masque 群組停用／這一格還沒交出去：探針收起來，按鈕畫米利邊
        if L then L.frame:Hide() end
        hd.msqOn, hd.msqShape, hd.msqFrame = nil, nil, nil
        return
    end
    hd.msqOn, hd.msqFrame = true, L.frame
    hd.msqShape = ShapeFor(L, L.frame, L.icon, r.w, r.h, function()
        return M.GetNormal and M.GetNormal(L.frame) or nil
    end)
end
CU.SyncSkinLayer = SyncSkinLayer      -- 測試用

-- 飾品冷卻格的增益疊層：照底下冷卻格的皮（Decorate.Apply 交給 Masque 的那一格）讀形狀，不建探針、不讀外框
local function OverlayShape(rec, h, shape, r)
    local f = rec.frame
    if shape == "bars" or not (rec.msqSkinned and f and f.Icon) then
        h.msqOn, h.msqShape, h.msqFrame = nil, nil, nil
        return
    end
    h.msqOn, h.msqFrame = true, f
    h.msqShape = ShapeFor(h, f, f.Icon, r.w, r.h, nil)
end
CU.OverlayShape = OverlayShape

-- 圖示類的占位：獨立的框（見上）；長條類照舊畫在持有框上（UpdateBarPlaceholder）
local function UpdatePlaceholder(rec, c, r, barKey)
    if rec.shape == "bars" then return UpdateBarPlaceholder(rec, barKey, r.w, r.h) end
    local hd = rec.frame
    local e = rec.entry
    local look = hd.ph
    if not (e and WantPlaceholder(rec, barKey, "icons")) then
        if look then look.frame:Hide() end
        return
    end
    if not look then
        local f = CreateFrame("Frame", nil, c)
        f:EnableMouse(false)
        local tex = f:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(f)
        look = { frame = f, tex = tex }
        hd.ph = look
    end
    PlacePart(look, c, r, PH_LIFT)
    -- 圓環條：只畫這一圈的軌道（跟暴雪增益格在圓環條上的占位同一支；不交給 Masque）
    if rec.placeRing and ns.Decorate and ns.Decorate.ApplyRingPlaceholder then
        ns.Decorate.ApplyRingPlaceholder(look, barKey, rec.placeRing)
        return
    end
    local tex = look.tex
    tex:SetTexture((PlaceholderLook(rec)))
    tex:SetDesaturated(true)
    tex:SetAlpha(0.35)                       -- 只有圖示暗，邊框照真實格的顏色
    -- 邊框、縮放（米利）或整張皮（Masque）：跟暴雪增益格的占位（Core/Bars.lua）同一支
    if ns.Decorate and ns.Decorate.ApplyPlaceholder then
        ns.Decorate.ApplyPlaceholder(look, barKey, rec.cooldownID, r.w, r.h)
    else
        tex:SetTexCoord(ns.Layout.IconTexCoord(ns.Setting(barKey, "icon.zoom"), r.w, r.h,
            ns.Setting(barKey, "icon.aspect") ~= "stretch"))
    end
end
CU.UpdatePlaceholder = UpdatePlaceholder

------------------------------------------------------------
-- 引擎補位（只有光環格的條：Catalog.BarAuraFlow 成立、條層「增益不在時」收合 ⇒ Bars.AuraFlow）
--
-- 一條一份 flows[條] = { key, holder, containers = { 簽章 → 容器 }, container, sig, recs, fp, gen, active, pending… }：
--   * **補位持有框**：普通 Frame、parent 條容器、SetAllPoints(條容器)、層級 c＋2；寫入一律走 ns.Write（底下掛著
--     AuraContainer ⇒ 保護框）。條上每一格自己的持有框收起來（CU.Place 的 flow 分支），不畫占位。
--   * 條容器的尺寸照「全部都在」算（Bars 的 Layout.Compute 本來就這樣）⇒ 錨點、排開、別條貼在它身上都不會因為
--     光環出現／消失而動；戰鬥中 Lua 不下任何 SetPoint、不讀任何秘密值。
--   * **一顆 AuraContainer**（CustomAuraContainerTemplate）：SetUnit("player") → 逐格 AddAuraGroup → flow 參數 → SetEnabled(true)。
--     每格一個 group：key "g<順序>"、filter 照那格、maxFrameCount ＝ 1、candidateFilters.includeSpellIDs ＝ 那格認的法術、
--     initializeFrame 用**那一格自己的** AuraStyle（樣式、發光、Masque 探針讀回的形狀全部照舊烘）＋ st.cell（按鈕大小，Seat）。
--     group 的 layout：layoutIndex ＝ 順序、elementWidth／Height ＝ 格子、**elementSpacing ＝ 條的間距、groupSpacing ＝ 0**、
--     lineSpacing ＝ groupLineSpacing ＝ 條的間距。暴雪的 AnchorUtil.ApplyFlowLayout：每放一個元素游標前進「元素＋elementSpacing」，
--     下一個 group 開始時（groupSpacing > 0 才）再加 groupSpacing ⇒ 兩個都給條的間距會變成兩倍；而且 groupSpacing 只在
--     > 0 時生效。所以格與格的間距由 elementSpacing 帶（maxFrameCount ＝ 1 也一樣），groupSpacing 留 0。
--     自然換列用的是那個 group 的 lineSpacing；groupLineSpacing 只在 forceNewLine 或 groupSpacing 擠到換列時用（照樣給齊）。
--   * 容器層 flow（Layout.FlowParams）：主軸、起點角、生長方向、每列的像素預算。**對齊交給容器自己的錨點**：暴雪排完會把
--     容器的大小設成內容大小（OnLayoutComplete → SetSize(secretwrap(…))），容器用 fp.point 錨在補位持有框的同一個點
--     ⇒ 置中的條（point ＝ TOP／BOTTOM）內容置中、靠右的貼右。容器的大小是秘密值：**我們不讀、也沒有任何框錨在容器上**。
--     每個 setter 各自 pcall、結果記在 fl.applied（/mcdm aura 看）。
--   * 簽章 ＝ Layout.FlowSig(fp) ＋ 每一格的 AuraStyle 簽章（順序就是串接的順序）：換專精、增刪格子、改順序、改樣式、改尺寸／間距／
--     每列上限都是簽章變更 ⇒ 從池子拿或建一顆新的（frame 刪不掉，舊的 Hide 留池）。**戰鬥中只記旗標，脫戰建**（CU.OnRegen）。
--   * 補位持有框 OnShow（ns.Defer）補踢：戰鬥外 Hide→Show→SetEnabled(true)，戰鬥中記旗標。
--   * 音效（AddAuraSound）跟框無關：rec.placedBar 照設 ⇒ Core/Sound.lua 照樣登記同一批法術。
--   * 一個法術都認不到的格（飾品欄增益解不出來）不建 group（簽章記 "-"）。
--   * 補位靠的是暴雪那一頭：不在的光環 ⇒ 那個 group 沒有元素 ⇒ ApplyFlowLayout 整個跳過它（不佔位、不加間距）。
--   * ⚠ 成本：AddAuraGroup 一律先建一批按鈕（CustomAuraContainerConstants.FrameCreationBatchSize ＝ 10，跟 maxFrameCount
--     無關；AddAuraSlot 只建 1 顆），每顆都跑一次 initializeFrame ⇒ 一顆補位容器 ≈ 格數 × 10 顆按鈕，換簽章再一批
--     （frame 刪不掉，靠簽章池重用）。所以簽章只放會影響按鈕外觀與排法的東西。
--   * 這一輪沒在補位的條（不再成立、條被刪）：補位持有框收起來（CU.EndBar／EndFlush），容器留在池裡。
------------------------------------------------------------
local function FlowEnums()
    local AU = _G.AnchorUtil
    local ax = AU and AU.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
    local dir = AU and AU.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
    return ax, dir
end

-- 容器層的 flow 參數：每個 setter 各自 pcall（一支斷言失敗不能讓後面的都沒套），回傳 { setter → "ok"｜錯誤字串｜"missing" }
local function ApplyFlowLayout(c, fp)
    local ax, dir = FlowEnums()
    local res = {}
    local function Do(name, ...)
        local fn = c[name]
        if not fn then res[name] = "missing" return end
        local ok, err = pcall(fn, c, ...)
        res[name] = ok and "ok" or tostring(err)
    end
    Do("SetFlowLayoutAxis", fp.axis == "V" and ax.Vertical or ax.Horizontal)
    Do("SetFlowLayoutAnchorPoint", fp.flowPoint)
    Do("SetFlowLayoutGrowthDirection", fp.hDir == "LEFT" and dir.Left or dir.Right, fp.vDir == "UP" and dir.Up or dir.Down)
    Do("SetFlowLayoutPadding", 0, 0, 0, 0)
    Do("SetFlowLayoutMaximumLineSize", fp.lineSize)          -- nil ＝ 不換列（暴雪收 nil 當 math.huge）
    return res
end
CU.ApplyFlowLayout = ApplyFlowLayout  -- 測試用

-- group 的 layout 選項（純函式；欄位名照暴雪 ValidateAuraGroupLayoutOptions，未知的鍵會被靜靜丟掉）
function CU.FlowGroupLayout(i, fp)
    return {
        layoutIndex = i,
        elementWidth = fp.w, elementHeight = fp.h,
        elementSpacing = fp.spacing, lineSpacing = fp.spacing,
        groupSpacing = 0, groupLineSpacing = fp.spacing,
    }
end

-- 每一格的樣式（AuraStyle，格子尺寸 fp.w × fp.h）與整條的簽章
local function FlowGroups(fl)
    local fp = fl.fp
    local groups, parts = {}, { ns.Layout.FlowSig(fp) }
    for _, rec in ipairs(fl.recs or {}) do
        local st = AuraStyle(rec, fl.key, fp.w, fp.h, rec.shape, nil)
        if #st.ids > 0 then
            st.cell = { fp.w, fp.h }
            groups[#groups + 1] = { rec = rec, st = st }
            parts[#parts + 1] = st.sig
        else
            parts[#parts + 1] = "-"
        end
    end
    return groups, table.concat(parts, "||")
end
CU.FlowGroups = FlowGroups            -- 測試用

local function BuildFlowContainer(fl, groups)
    local h, fp = fl.holder, fl.fp
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    -- 單點錨：容器排完會自己設大小（內容大小），對齊靠這個點（見上）
    c:SetPoint(fp.point, h, fp.point, 0, 0)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 group 之前、SetEnabled 最後
    c:SetUnit("player")
    for i, g in ipairs(groups) do
        local rec, st = g.rec, g.st
        Warm(st)
        local include = {}
        for _, id in ipairs(st.ids) do include[id] = true end
        local init = (st.shape == "bars") and InitAuraBarButton or InitAuraButton
        local handler = function(err)
            rec.lastError = tostring(err)
            if ns.ReportError then ns.ReportError(err) end
        end
        c:AddAuraGroup("g" .. i, rec.filter, {
            maxFrameCount = 1,
            candidateFilters = { includeSpellIDs = include },
            initializeFrame = function(btn)
                xpcall(init, handler, btn, nil, st, rec)
            end,
            layout = CU.FlowGroupLayout(i, fp),
        })
    end
    fl.applied = ApplyFlowLayout(c, fp)
    -- ⚠ 不對容器掛任何 script（forbidden intrinsic）；重新可見的補踢掛在補位持有框上
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    return c
end

local function ArmRegen()
    ns.Events.Register("PLAYER_REGEN_ENABLED", "custom", CU.OnRegen)
end

-- 簽章對上容器：同簽章不動；換了就從池子拿（沒有才建）。戰鬥中只記旗標
local function EnsureFlowContainer(fl)
    local groups, sig = FlowGroups(fl)
    fl.wantSig = sig
    if fl.sig == sig and (fl.container or #groups == 0) then return end
    if InCombatLockdown() then
        fl.pending = true
        ArmRegen()
        return
    end
    fl.pending = nil
    local old = fl.container
    local c = nil
    if #groups > 0 then
        c = fl.containers[sig]
        if c then
            pcall(c.Show, c)
            Kick(c)
        else
            local ok, built = pcall(BuildFlowContainer, fl, groups)
            if not ok or not built then
                fl.lastError = tostring(built)
                CU.lastError = fl.lastError
                if ns.ReportError then ns.ReportError(built) end
                return
            end
            c = built
            fl.containers[sig] = c
            CU.builds = CU.builds + 1
            fl.builds = (fl.builds or 0) + 1
        end
    end
    if old and old ~= c then pcall(old.Hide, old) end
    fl.container, fl.sig = c, sig
end
CU.EnsureFlowContainer = EnsureFlowContainer

local function OnFlowHolderShow(fl)
    local c = fl.container
    if not (c and fl.active) then return end
    if InCombatLockdown() then
        fl.pendingKick = true
        ArmRegen()
    else
        fl.pendingKick = nil
        Kick(c)
    end
end

local function NewFlow(barKey)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetSize(1, 1)
    h:Hide()
    h:EnableMouse(false)
    local fl = { key = barKey, holder = h, containers = {} }
    -- 掛勾裡只記帳，工作丟到下一幀（同光環格的持有框）
    h:HookScript("OnShow", function() ns.Defer(OnFlowHolderShow, fl) end)
    return fl
end

-- Bars.Relayout 叫（這條在補位、格子都 CU.Place(…, true) 過之後）：list ＝ { { rec, r }… }（清單順序）、fp ＝ Layout.FlowParams
function CU.PlaceFlow(barKey, c, list, fp, gen)
    local fl = flows[barKey]
    if not fl then
        fl = NewFlow(barKey)
        flows[barKey] = fl
    end
    local recs = {}
    for i, it in ipairs(list or {}) do recs[i] = it.rec end
    fl.recs, fl.fp, fl.gen, fl.active, fl.c = recs, fp, gen, true, c
    local lvl = (c:GetFrameLevel() or 1) + 2
    local psig = tostring(c) .. "|" .. lvl
    if fl.posSig ~= psig then
        fl.posSig = psig
        ns.Write(fl.holder, function(fr)
            if fr:GetParent() ~= c then fr:SetParent(c) end
            fr:SetFrameLevel(lvl)
            fr:ClearAllPoints()
            fr:SetAllPoints(c)
            fr:Show()
        end, "place")
    end
    EnsureFlowContainer(fl)
end

-- 收起來（這條不再補位、條被刪）：補位持有框 Hide 走 ns.Write；容器留在池裡
local function HideFlow(fl)
    if not fl.active then return end
    fl.active, fl.posSig, fl.pending, fl.pendingKick = false, nil, nil, nil
    ns.Write(fl.holder, function(fr) fr:Hide() end, "place")
end
CU.HideFlow = HideFlow

function CU.Flows() return flows end
function CU.FlowOf(barKey) return flows[barKey] end

------------------------------------------------------------
