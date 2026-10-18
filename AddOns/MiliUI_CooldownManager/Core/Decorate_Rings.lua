------------------------------------------------------------
-- 外觀：圓環顯示（從 Core/Decorate.lua 切出，2026-10-18；TOC 緊接在 Decorate_Bars.lua 之後載入）
--
-- 跨檔的幫手都掛在 ns.Decorate 上（Plain、C4、CSig、MakeBorder、LayoutBorder、SquareSwipe、ApplyShape），這裡取回成 local。
-- 給 Decorate.lua 回頭叫的：D.ApplyRing（Apply）。
------------------------------------------------------------
local _, ns = ...

local D = ns.Decorate
local Plain, C4, CSig = D.Plain, D.C4, D.CSig
local MakeBorder, LayoutBorder, SquareSwipe, ApplyShape = D.MakeBorder, D.LayoutBorder, D.SquareSwipe, D.ApplyShape

------------------------------------------------------------
-- 圓環顯示（條層 layout.style ＝ "rings"；幾何在 Core/Layout.lua 的 ComputeRings）
--
-- 圓環條只收增益（2026-10-08）：這裡改造的是暴雪增益檢視器的 item；核心／輔助的冷卻格 Core/Bars.lua 不放上圓環條
-- （核心／輔助本身也沒有圓環，DB.BarIsRings）。自訂光環格的圓環是按鈕自己烘的（Modules/Custom.lua 的「光環格畫成圓環」），
-- 方向、軌道、填色、文字位置跟這裡一致。
--
-- 我們沒有把暴雪格子的光環時間轉到自己 Cooldown 上的路（GetCooldownTimes 回秘密值；SetCooldown 後掛勾轉交參數
-- 在秘密下會被拒；探針那條 duration 物件拿的是法術冷卻不是光環）⇒ **讓暴雪照常驅動它自己的 item.Cooldown，只換外觀**：
--   * cd:SetSwipeTexture(環形貼圖)：跟 SquareSwipe 同一招。暴雪的 Lua 不會重設 swipe 貼圖（只在 XML 宣告一次）
--   * cd:SetReverse(false)：增益圖示的 XML 是 reverse="true"（畫已經過去的那段）；圓環要畫剩下的那段
--     （亮的部分隨時間縮短）。暴雪的 Lua 也不會呼叫 SetReverse ⇒ 設一次。核心／輔助的 XML 本來就是 false
--   * 填色：暴雪每次刷新都 SetSwipeColor ⇒ rec.style.swipe 換成填色，AfterCooldown 照舊每次蓋
--   * 不畫邊緣（rec.style.drawEdge ＝ false，AfterCooldown 每次寫）、不畫 bling（設一次）
--   * 軌道（深色底環）：我們自己的子框（rec.ringTrack，item 的子框、層級低於 Cooldown）貼同一張環形貼圖、SetVertexColor 上軌道色
--   * 圖示：item.Icon 換父層到我們的框（rec.ringIcon，層級在 Cooldown 上面、overlay 底下）。關著「顯示法術圖示」時那個框
--     alpha 0（暴雪自己哪天對圖示 SetAlpha 也露不出來）；開著時圖示錨在這一圈頂端的環帶正中央
--   * 方形的東西不畫：我們的邊框、暴雪的減益框（alpha 0）、觸發／就緒／生效發光（Glow 看 rec.ring）、層數門檻（StackGate）、
--     按鍵文字（Keybinds）；不交給 Masque
-- 全程不讀任何秘密值；暴雪 item 不是保護框，戰鬥中改尺寸／錨點沒問題（引擎本來就這樣放格）。
-- 暴雪框上一個欄位都不寫：狀態都在 rec（弱鍵表 Viewers.frames 的值）上。
--
-- 還原（D.RestoreRing）：條改回圖示、item 搬去別條（D.Apply 開頭判 rec.ring 而這一輪不是圓環）、
-- 還給暴雪（Bars.ReleaseAll）都走這支：swipe 貼圖改回方形（SquareSwipe 的 WHITE；交給 Masque 的格子由接著的 Sync 換成皮的）、
-- reverse／bling 照第一次套圓環前讀到的值、圖示換回 item 並貼回整格、軌道收起來、倒數錨點交回圖示中央（接著 Text.ApplyIcon 照設定重錨）。
------------------------------------------------------------
local RING_TRACK = { r = 0.04, g = 0.06, b = 0.08, a = 0.9 }

-- 條層的圓環設定解好（Resolve 叫）；不是圓環條回 nil
function D.RingStyle(barKey)
    local S = ns.Setting
    local LY = ns.Layout
    if not (S and LY) or (S(barKey, "kind") or "icons") == "bars" or S(barKey, "layout.style") ~= "rings" then return nil end
    -- 核心／輔助存著 rings 也不算（圓環條只收增益，判準 DB.BarIsRings）
    if ns.DB and ns.DB.BarIsRings and not ns.DB.BarIsRings(barKey) then return nil end
    local ring = S(barKey, "ring")
    ring = type(ring) == "table" and ring or {}
    local thick, gap, dir = LY.RingParams(ring)
    return {
        thick    = thick,
        gap      = gap,
        dir      = dir,
        track    = type(ring.trackColor) == "table" and ring.trackColor or RING_TRACK,
        timeText = ring.timeText == "hide" and "hide" or "top",
        showIcon = ring.showIcon and true or false,
        iconSize = LY.RingIconSize(ring.iconSize),
    }
end

function D.RingSig(rs)
    if not rs then return "-" end
    return table.concat({ "ring", rs.thick, rs.gap, rs.dir, CSig(rs.track), rs.timeText, tostring(rs.showIcon), rs.iconSize }, ",")
end

-- 填色：色表照用；false／nil ＝ 職業色（套組的強調色函式）
function D.RingFill(c)
    if type(c) == "table" then return C4(c, 1, 1, 1, 1) end
    local St = ns.Style
    if St and St.Accent then return St.Accent(1) end
    return 1, 1, 1, 1
end

local function ReadBool(fn, obj)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, obj)
    v = ok and Plain(v) or nil
    if type(v) ~= "boolean" then return nil end
    return v
end

-- 軌道框：item 的子框、貼滿 item，層級低於 Cooldown（不然蓋住環形 swipe）
local function RingTrack(item, rec)
    local f = rec.ringTrack
    if not f then
        f = CreateFrame("Frame", nil, item)
        f.tex = f:CreateTexture(nil, "BACKGROUND")
        f.tex:SetAllPoints(f)
        rec.ringTrack = f
    end
    f:ClearAllPoints()
    f:SetAllPoints(item)
    local base = item:GetFrameLevel() or 1
    local cd = item.Cooldown
    local cl = cd and cd.GetFrameLevel and cd:GetFrameLevel() or nil
    f:SetFrameLevel((cl and cl > base) and (cl - 1) or base)
    f:Show()
    return f
end

-- 圖示框：Cooldown 上面一層（圖示蓋在環形 swipe 上）、overlay（＋10 起跳）底下
local function RingIconHolder(item, rec)
    local h = rec.ringIcon
    if not h then
        h = CreateFrame("Frame", nil, item)
        rec.ringIcon = h
    end
    h:ClearAllPoints()
    h:SetAllPoints(item)
    local cd = item.Cooldown
    local cl = (cd and cd.GetFrameLevel and cd:GetFrameLevel()) or item:GetFrameLevel() or 1
    h:SetFrameLevel(cl + 1)
    h:Show()
    return h
end

-- 暴雪取出時理論上不會重設、但保險起見 Reattach 也重套的三樣（swipe 貼圖、reverse、bling）
function D.ReapplyRingCore(item, rec)
    local cd = item and item.Cooldown
    if not (cd and rec and rec.ringPath) then return end
    if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, rec.ringPath, 1, 1, 1, 1) end
    if cd.SetReverse then pcall(cd.SetReverse, cd, false) end
    if cd.SetDrawBling then pcall(cd.SetDrawBling, cd, false) end
end

-- ring：這一格的 rect（ring ＝ 從內往外第幾圈、tex ＝ 第幾張環形貼圖）
local function ApplyRing(item, rec, style, ring)
    local rs = style.ring
    local cd, icon = item.Cooldown, item.Icon
    if not rec.ring and cd then
        -- 第一次套：記下原本的 reverse／bling（還原用；讀不到就照模板的預設，見 RestoreRing）
        rec.ringRev0 = ReadBool(cd.GetReverse, cd)
        rec.ringBling0 = ReadBool(cd.GetDrawBling, cd)
    end
    rec.ring = true                 -- Glow／StackGate／Keybinds 看這個
    rec.swipeSquare = nil           -- 轉圈材質現在是環形的（RestoreRing 換回方形）
    rec.ringPath = ns.Layout.RingFile(ring.tex)
    rec.ringHideTime = rs.timeText == "hide"
    if cd then
        cd:ClearAllPoints()         -- 模板是 setAllPoints；圖示會被搬走，明確貼滿 item
        cd:SetAllPoints(item)
        D.ReapplyRingCore(item, rec)
    end
    local track = RingTrack(item, rec)
    track.tex:SetTexture(rec.ringPath)
    track.tex:SetVertexColor(C4(rs.track, 0.04, 0.06, 0.08, 0.9))
    local holder = RingIconHolder(item, rec)
    if icon and icon.SetParent then
        if icon:GetParent() ~= holder then icon:SetParent(holder) end
        icon:ClearAllPoints()
        if rs.showIcon then
            local isz = rs.iconSize
            icon:SetPoint("CENTER", item, "TOP", 0, -rs.thick / 2)
            icon:SetSize(isz, isz)
            icon:SetTexCoord(ns.Layout.IconTexCoord(style.zoom, isz, isz, true))
        else
            icon:SetAllPoints(item)
        end
    end
    holder:SetAlpha(rs.showIcon and 1 or 0)
end
D.ApplyRing = ApplyRing

function D.RestoreRing(item, rec)
    if not (item and rec and rec.ring) then return end
    rec.ring, rec.ringPath, rec.ringHideTime = nil, nil, nil
    local cd = item.Cooldown
    if cd then
        rec.swipeSquare = nil
        SquareSwipe(cd, rec)
        local aura = ns.Viewers and ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey]
        local rev = rec.ringRev0
        if rev == nil then rev = aura and true or false end     -- 模板：增益圖示 reverse="true"、核心／輔助沒寫（false）
        local bling = rec.ringBling0
        if bling == nil then bling = true end                   -- 模板沒寫 ⇒ Cooldown 的預設（畫）
        if cd.SetReverse then pcall(cd.SetReverse, cd, rev) end
        if cd.SetDrawBling then pcall(cd.SetDrawBling, cd, bling) end
        cd:ClearAllPoints()
        cd:SetAllPoints(item)
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", item, "CENTER", 0, 0)
        end
    end
    if rec.ringTrack then rec.ringTrack:Hide() end
    local icon = item.Icon
    if icon and icon.SetParent then
        if icon:GetParent() ~= item then icon:SetParent(item) end
        icon:ClearAllPoints()
        icon:SetAllPoints(item)
    end
    if rec.ringIcon then rec.ringIcon:Hide() end
end

-- 圓環條上「增益不在時：暗圖示」的占位：只畫這一圈的軌道（Bars 的占位框是我們自己的框）
function D.ApplyRingPlaceholder(ph, barKey, r)
    if not (ph and ph.frame and ph.tex and r) then return end
    local style = D.Resolve(barKey)
    local rs = style.ring
    if not rs then return end
    if ph.msqButton then ns.Masque.Release(ph) end
    ph.border = ph.border or MakeBorder(ph.frame)
    LayoutBorder(ph.border, nil)
    if ph.shapeArt then ApplyShape(ph, ph.frame, ph.tex, false, nil, nil, nil, 0, nil, 0, 0, ph.border) end   -- 圓環不套形狀
    if ph.label and ns.Text and ns.Text.ApplyLabel then ns.Text.ApplyLabel(ph.label, ph.frame, nil) end
    ph.ring = true
    local tex = ph.tex
    tex:SetTexture(ns.Layout.RingFile(r.tex))
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetDesaturated(false)
    tex:SetVertexColor(C4(rs.track, 0.04, 0.06, 0.08, 0.9))
    tex:SetAlpha(1)
end

-- 設定頁預覽的圓環格（Options/Preview.lua：cell.ringTrack、cell.ringIcon（圖示框）、cell.ringTex、cell.ringRank）
function D.ApplyRingPreview(cell, style, spell)
    local rs = style.ring
    local path = ns.Layout.RingFile(cell.ringTex)
    if cell.msqButton and ns.Masque then ns.Masque.Release(cell) end
    cell.msqSkinned, cell.barGeometry = false, nil
    if cell.border then LayoutBorder(cell.border, nil) end
    cell.ringTrack:SetTexture(path)
    cell.ringTrack:SetVertexColor(C4(rs.track, 0.04, 0.06, 0.08, 0.9))
    local cd = cell.Cooldown
    if cd then
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, path, 1, 1, 1, 1) end
        if cd.SetReverse then cd:SetReverse(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        cd:SetDrawEdge(false)
        cd:SetSwipeColor(D.RingFill(spell.ringColor))
    end
    local icon = cell.Icon
    if icon then
        icon:SetDesaturated(false)
        icon:ClearAllPoints()
        if rs.showIcon then
            icon:SetPoint("CENTER", cell, "TOP", 0, -rs.thick / 2)
            icon:SetSize(rs.iconSize, rs.iconSize)
            icon:SetTexCoord(ns.Layout.IconTexCoord(style.zoom, rs.iconSize, rs.iconSize, true))
        else
            icon:SetAllPoints(cell)
        end
    end
    if cell.ringIcon then cell.ringIcon:SetAlpha(rs.showIcon and 1 or 0) end
    cell.buffTime, cell.durColor = false, nil
    ns.Text.ApplyPreviewIcon(cell, style, spell)
    ns.Text.ApplyRingPreview(cell, style, spell)
end
