------------------------------------------------------------
-- Api.lua（MiliUITip_API.Adopt）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Api_test.lua
--
-- 覆蓋：opts.ignoreParentAlpha 會 SetIgnoreParentAlpha(true)、不帶就不碰；已經接管過也照套；
-- 還沒初始化（ns.db 沒有）回 false 且什麼都不碰；keepScale 照原樣交給 TrackTip；
-- followPanel：貼到有面板顯示中的 tooltip 時改由我們定位——貼整條面板鏈外側、上緣對齊根、換邊有遲滯、
-- 跟隨期間夾邊（L3／O1）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq

local function Setup()
    local env = H.Env({ SlashCmdList = {}, MiliUI_MenuEntries = nil })
    local State, tracked = {}, {}
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        db = {},
        Skin = {
            State = State,
            Get = function(t) return State[t] end,
            ApplyBase = function() end,
        },
        Options = { Open = function() end },
    }
    ns.TrackTip = function(tip, isPreview, opts)
        tracked[#tracked + 1] = { tip = tip, opts = opts }
        State[tip] = {}
    end
    ns.Media = { WHITE8X8 = "white", Font = function() return "default.ttf" end }
    H.Load(env, ns, "Libs/MiliUIWidgets/Secret.lua")
    H.Load(env, ns, "Panel/Frame.lua")
    H.Load(env, ns, "Api.lua")
    return env, ns, tracked, State
end

local function Frame()
    local f = H.Region("Frame")
    f.ignoreCalls = 0
    function f:SetIgnoreParentAlpha(v) self.ignoreParentAlpha = v; self.ignoreCalls = self.ignoreCalls + 1 end
    return f
end

do
    local env, ns, tracked = Setup()
    local api = env.MiliUITip_API
    local f = Frame()
    eq("帶 ignoreParentAlpha：接管成功", api.Adopt(f, { keepScale = true, ignoreParentAlpha = true }), true)
    eq("帶 ignoreParentAlpha：SetIgnoreParentAlpha(true)", f.ignoreParentAlpha, true)
    eq("keepScale 照原樣交給 TrackTip", tracked[1].opts.keepScale, true)
    eq("再叫一次（已接管）：照樣套", api.Adopt(f, { ignoreParentAlpha = true }), true)
    eq("再叫一次：setter 又呼叫一次（冪等）", f.ignoreCalls, 2)
    eq("再叫一次：沒有第二層 skin", #tracked, 1)

    local g = Frame()
    api.Adopt(g, { keepScale = true })
    eq("不帶：不碰 SetIgnoreParentAlpha", g.ignoreCalls, 0)
    local h = Frame()
    api.Adopt(h)
    eq("沒有 opts：不碰", h.ignoreCalls, 0)

    local noMethod = H.Region("Frame")
    check("框沒有這個方法：不炸", api.Adopt(noMethod, { ignoreParentAlpha = true }))

    ns.db = nil
    local k = Frame()
    eq("還沒初始化：回 false", api.Adopt(k, { ignoreParentAlpha = true }), false)
    eq("還沒初始化：什麼都不碰", k.ignoreCalls, 0)
    eq("不是框：回 false", api.Adopt("x"), false)
end

------------------------------------------------------------
-- followPanel（L3／O1）：後掛勾 SetPoint，貼到有面板顯示中的 tooltip ⇒ 不照它的點，由我們定位
--   貼整條面板鏈外側、上緣對齊根、換邊有遲滯、跟隨期間夾邊
-- 座標：UIParent 縮放 1、螢幕寬 1600；根面板 left 400 寬 300 top 800；預覽框 280×380
------------------------------------------------------------
local function Pt(f)
    local p = f.points[1]
    return ("%s>%s|%g,%g"):format(p[1], p[3], p[4], p[5]), p[2]
end

do
    local env, ns, _, State = Setup()
    local api = env.MiliUITip_API
    local tip = H.Tip(env, "GameTooltip", {})
    local panel = H.Region("Frame")
    panel:Show()
    panel.left, panel.w, panel.top, panel.h = 200, 300, 800, 200
    State[tip] = { panel = panel }
    local other = H.Tip(env, "OtherTooltip", {})          -- 沒接管的
    local f = Frame()
    f.w, f.h = 280, 380
    local setCalls = 0
    local raw = f.SetPoint
    f.SetPoint = function(...) setCalls = setCalls + 1; return raw(...) end
    api.Adopt(f, { keepScale = true, ignoreParentAlpha = true, followPanel = true })
    api.Adopt(f, { followPanel = true })                   -- 第二次：不再掛一層

    -- 它要貼左邊；左邊放不下（200 < 280+6）、右邊放得下 ⇒ 右邊
    setCalls = 0
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    local sig, rel = Pt(f)
    eq("O1：只剩一個點", #f.points, 1)
    eq("O1：對象換成面板", rel, panel)
    eq("O1：它要的左邊放不下 ⇒ 貼鏈右側、上緣對齊、留縫 6", sig, "TOPLEFT>TOPRIGHT|6,0")
    eq("O1：同一顆只掛一次（呼叫 1 次＋改貼 1 次）", setCalls, 2)
    eq("O1：跟隨期間開夾邊", f.clamped, true)

    -- 它下一輪改要求「貼在上方」（原生超出螢幕時的亂判斷）⇒ 我們不理，還是右側
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", "GameTooltip", "TOPLEFT", 3, -2)
    sig, rel = Pt(f)
    eq("O1：名字字串也認、它換點我們不跟", sig .. "@" .. tostring(rel == panel), "TOPLEFT>TOPRIGHT|6,0@true")

    -- 比價面板鏡射在根上、在右邊（left 506）⇒ 貼最外側那顆
    local tip2 = H.Tip(env, "ShoppingTooltip1", {})
    local sp = H.Region("Frame")
    sp:Show()
    sp.left, sp.w, sp.top, sp.h, sp.mirrorOf = 506, 300, 800, 180, panel
    State[tip2] = { panel = sp }
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("O1：比價面板出現 ⇒ 貼鏈最外側那顆", rel, sp)
    eq("O1：仍是右側、上緣對齊", sig, "TOPLEFT>TOPRIGHT|6,0")

    -- 鏈變寬不等它的 0.2 秒：Align 之後 PlaceFollowers 當幀重算（這裡直接叫）
    sp.left = 710
    sp:Hide()
    ns.Panel.PlaceFollowers(panel)
    sig, rel = Pt(f)
    eq("PlaceFollowers：比價面板消失 ⇒ 回到貼根", rel, panel)
    sp:Show()
    ns.Panel.PlaceFollowers(panel)
    sig, rel = Pt(f)
    eq("PlaceFollowers：又出現 ⇒ 貼回最外側", rel, sp)
    local before = setCalls
    ns.Panel.PlaceFollowers(panel)
    eq("PlaceFollowers：貼法沒變就不重貼", setCalls, before)

    -- 鏈移到右邊緣（右側放不下）：剛換過邊／第一次放的 0.3 秒內不換（遲滯），之後才換到左邊、貼最左那顆
    panel.left, sp.left = 1200, 1506
    env.now = 0.1
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("遲滯：0.3 秒內放不下也不換邊", sig .. "@" .. tostring(rel == sp), "TOPLEFT>TOPRIGHT|6,0@true")
    env.now = 1
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("遲滯：過了 0.3 秒 ⇒ 換到左側、貼根的左緣", sig .. "@" .. tostring(rel == panel), "TOPRIGHT>TOPLEFT|-6,0@true")

    -- 左側放得下就一直留在左側（即使右側更寬）
    panel.left, sp.left = 400, 706
    env.now = 2
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("遲滯：這一邊放得下就不換", sig .. "@" .. tostring(rel == panel), "TOPRIGHT>TOPLEFT|-6,0@true")

    -- 左側放不下、右側放得下但比價面板比根低 20 ⇒ 換右側、上緣仍對齊根（y 位移 +20）
    panel.left, sp.left, sp.top = 100, 406, 780
    env.now = 3
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("上緣對齊根：貼在比較低的比價面板上時 y 補差", sig .. "@" .. tostring(rel == sp), "TOPLEFT>TOPRIGHT|6,20@true")

    -- 兩邊都放不下（螢幕 500 寬）：選比較寬的那邊，仍貼著面板（夾邊會把它留在螢幕內）
    env.screenW = 500
    panel.left, sp.left, sp.top = 120, 426, 800
    env.now = 4
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("兩邊都放不下：留在比較寬的左邊（左 120、右 −226）", sig .. "@" .. tostring(rel == panel), "TOPRIGHT>TOPLEFT|-6,0@true")
    env.screenW = nil

    -- 面板退回：貼著的那顆比價面板退了、根還在 ⇒ 重貼到鏈上；根退了 ⇒ 貼回原本的 tooltip、夾邊還原
    panel.left, sp.left = 400, 706
    env.now = 5
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT", 1, 1)
    eq("前提：左側放得下、留在左側貼根", select(2, Pt(f)), panel)
    panel.left, sp.left = 100, 406
    env.now = 6
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT", 1, 1)
    eq("前提：換到右側貼比價面板", select(2, Pt(f)), sp)
    sp:Hide()
    ns.Panel.ReturnFollowers(sp)
    sig, rel = Pt(f)
    eq("ReturnFollowers（比價面板）：根還在 ⇒ 重貼到根", rel, panel)
    eq("ReturnFollowers（比價面板）：仍在右側", sig, "TOPLEFT>TOPRIGHT|6,0")
    ns.Panel.ReturnFollowers(panel)
    sig, rel = Pt(f)
    eq("ReturnFollowers（根）：貼回原本的 tooltip", rel, tip)
    eq("ReturnFollowers（根）：點與位移原樣", sig, "TOPRIGHT>TOPLEFT|1,1")
    eq("ReturnFollowers（根）：夾邊還原", f.clamped, false)
    local n = setCalls
    ns.Panel.PlaceFollowers(panel)
    eq("放手之後 PlaceFollowers 不再動它", setCalls, n)

    -- 對象不是接管的／面板沒顯示／秘密 ⇒ 不碰它的點；放手時夾邊還原
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("前提：又貼上面板", select(2, Pt(f)), panel)
    eq("前提：夾邊開", f.clamped, true)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", other, "TOPLEFT")
    eq("對象不是接管的 ⇒ 原樣", f.points[1][2], other)
    eq("對象不是接管的 ⇒ 放手、夾邊還原", f.clamped, false)
    panel:Hide()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("面板沒顯示 ⇒ 原樣", f.points[1][2], tip)
    f:ClearAllPoints()
    f:SetPoint("CENTER", H.SECRET, "CENTER")
    check("秘密對象 ⇒ 不碰", rawequal(f.points[1][2], H.SECRET))

    -- 幾何讀不到（面板還沒排版）、從來沒貼過：退回「對象換成面板、點照它的」＋縫
    panel:Show()
    panel.left = nil
    env.timers = {}
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("幾何讀不到、沒貼過：對象換成面板、點照它的、留縫", sig .. "@" .. tostring(rel == panel), "TOPRIGHT>TOPLEFT|-6,0@true")
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, 0)
    eq("幾何讀不到＋N1：底貼頂 ⇒ y 往上推 6", select(1, Pt(f)), "BOTTOMLEFT>TOPLEFT|0,6")
    eq("幾何讀不到：只排一次下一幀重算", #env.timers, 1)
    -- 下一幀幾何回來 ⇒ 自己貼到我們算的位置（左 100 放不下、右側放得下 ⇒ 右側）
    panel.left = 100
    env.FlushTimers()
    sig, rel = Pt(f)
    eq("下一幀重算：貼到我們算的位置", sig .. "@" .. tostring(rel == panel), "TOPLEFT>TOPRIGHT|6,0@true")

    -- 已經貼過之後幾何又讀不到：沿用上一次的貼法，**不**退回它的點（以前這裡左右閃）
    panel.left = nil
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    sig, rel = Pt(f)
    eq("幾何讀不到、貼過：沿用上一次（右側），不照它的左側", sig .. "@" .. tostring(rel == panel), "TOPLEFT>TOPRIGHT|6,0@true")
    eq("幾何讀不到：記次數給 /mtip panel", ns.Panel.followers[f].fails >= 2, true)
    panel.left = 100

    -- 它要貼的那顆此刻沒有面板（比價框重建中）、鏈的根還在 ⇒ 繼續跟鏈，不放手、不照它的點
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", tip2, "TOPRIGHT")               -- tip2 的面板 sp 已隱藏
    sig, rel = Pt(f)
    eq("對象暫時沒有面板、根還在：仍貼鏈", sig .. "@" .. tostring(rel == panel), "TOPLEFT>TOPRIGHT|6,0@true")
    eq("對象暫時沒有面板、根還在：夾邊沒放", f.clamped, true)

    -- 配合它的偏好：第一次選邊時，它要的那邊放得下就照它的（即使另一邊更寬）；之後它的偏好變了不跟
    panel.left = 400                                         -- 左 400、右 900 都放得下
    local f2 = Frame()
    f2.w, f2.h = 280, 380
    api.Adopt(f2, { keepScale = true, ignoreParentAlpha = true, followPanel = true })
    f2:SetPoint("TOPRIGHT", tip, "TOPLEFT")                  -- 它要左側
    eq("偏好：第一次照它要的左側（右側雖然更寬）", select(1, Pt(f2)) .. "@" .. tostring(select(2, Pt(f2)) == panel), "TOPRIGHT>TOPLEFT|-6,0@true")
    f2:ClearAllPoints()
    f2:SetPoint("TOPLEFT", tip, "TOPRIGHT")                  -- 下一輪它改要右側
    eq("偏好：之後它改要右側、左側還放得下 ⇒ 不跟", select(1, Pt(f2)), "TOPRIGHT>TOPLEFT|-6,0")
    f2:ClearAllPoints()
    f2:SetPoint("BOTTOMLEFT", tip, "TOPLEFT")                -- 上下貼法：沒有左右偏好
    eq("偏好：上下貼法沒有偏好、位置不變", select(1, Pt(f2)), "TOPRIGHT>TOPLEFT|-6,0")

    local g = Frame()
    api.Adopt(g, { keepScale = true })
    g:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("不帶 followPanel：不改貼", g.points[1][2], tip)

    -- GapOffset 本身（N1）
    local G = ns.Panel.GapOffset
    eq("N1：右貼左 x−", select(1, G("TOPRIGHT", "TOPLEFT", 6)), -6)
    eq("N1：左貼右 x+", select(1, G("LEFT", "RIGHT", 6)), 6)
    eq("N1：底貼頂 y+", select(2, G("BOTTOMLEFT", "TOPLEFT", 6)), 6)
    eq("N1：頂貼底 y−", select(2, G("TOPLEFT", "BOTTOMLEFT", 6)), -6)
    eq("N1：同邊對齊不推", ("%g,%g"):format(G("TOP", "TOP", 6)), "0,0")
end

H.finish("Api_test")
