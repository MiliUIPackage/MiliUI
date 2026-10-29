------------------------------------------------------------
-- Api.lua（MiliUITip_API.Adopt）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Api_test.lua
--
-- 覆蓋：opts.ignoreParentAlpha 會 SetIgnoreParentAlpha(true)、不帶就不碰；已經接管過也照套；
-- 還沒初始化（ns.db 沒有）回 false 且什麼都不碰；keepScale 照原樣交給 TrackTip；
-- followPanel：貼到有面板顯示中的 tooltip 時改貼面板、點與位移原樣、相鄰邊留縫（L3）。
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
    ns.Media = { WHITE8X8 = "white", NoSnap = function(t) return t end, Font = function() return "default.ttf" end }
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
------------------------------------------------------------
-- followPanel（L3）：後掛勾 SetPoint，貼到有面板顯示中的 tooltip ⇒ 對象換成面板、點與位移原樣、相鄰邊留縫
-- （O1 那套「由我們決定左右、交棒、停在原地」2026-10-19 拿掉：原生幾何真實化之後它自己的判斷可信）
------------------------------------------------------------
do
    local env, ns, _, State = Setup()
    local api = env.MiliUITip_API
    local tip = H.Tip(env, "GameTooltip", {})
    local panel = H.Region("Frame")
    panel:Show()
    State[tip] = { panel = panel }
    local other = H.Tip(env, "OtherTooltip", {})          -- 沒接管的
    local f = Frame()
    local setCalls = 0
    local raw = f.SetPoint
    f.SetPoint = function(...) setCalls = setCalls + 1; return raw(...) end
    api.Adopt(f, { keepScale = true, ignoreParentAlpha = true, followPanel = true })
    api.Adopt(f, { followPanel = true })                   -- 第二次：不再掛一層

    setCalls = 0
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("followPanel：只剩一個點", #f.points, 1)
    eq("followPanel：對象換成面板", f.points[1][2], panel)
    eq("followPanel：點原樣", f.points[1][1] .. ">" .. f.points[1][3], "TOPRIGHT>TOPLEFT")
    eq("followPanel＋N1：相鄰邊（右貼左）往外推 6", f.points[1][4], -6)
    eq("followPanel：y 位移補 0", f.points[1][5], 0)
    eq("followPanel：同一顆只掛一次（呼叫 1 次＋改貼 1 次）", setCalls, 2)

    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", "GameTooltip", "TOPLEFT", 3, -2)
    eq("followPanel：名字字串也認", f.points[1][2], panel)
    eq("followPanel：位移原樣＋縫", ("%g,%g"):format(f.points[1][4], f.points[1][5]), "-3,-2")
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, 0)
    eq("N1：底貼頂 ⇒ y 往上推 6、x 不動", ("%g,%g"):format(f.points[1][4], f.points[1][5]), "0,6")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, 0)
    eq("N1：頂貼底 ⇒ y 往下推 6", ("%g,%g"):format(f.points[1][4], f.points[1][5]), "0,-6")
    f:ClearAllPoints()
    f:SetPoint("TOP", tip, "TOP", 2, 0)
    eq("N1：同邊對齊不推", ("%g,%g"):format(f.points[1][4], f.points[1][5]), "2,0")
    f:ClearAllPoints()
    f:SetPoint("LEFT", tip, "RIGHT", 0, 0)
    eq("N1：左貼右 ⇒ x 往右推 6", f.points[1][4], 6)

    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", other, "TOPLEFT")
    eq("followPanel：對象不是接管的 ⇒ 原樣", f.points[1][2], other)

    panel:Hide()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("followPanel：面板沒顯示 ⇒ 原樣", f.points[1][2], tip)

    f:ClearAllPoints()
    f:SetPoint("CENTER", H.SECRET, "CENTER")
    check("followPanel：秘密對象 ⇒ 不碰", rawequal(f.points[1][2], H.SECRET))

    -- 面板退回：貼在它上面的框當場貼回原本的 tooltip
    panel:Show()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT", 1, 1)
    eq("前提：貼在面板上", f.points[1][2], panel)
    ns.Panel.ReturnFollowers(panel)
    eq("ReturnFollowers：貼回原本的 tooltip", f.points[1][2], tip)
    eq("ReturnFollowers：點與位移原樣", table.concat({ f.points[1][1], f.points[1][3], f.points[1][4], f.points[1][5] }, ","), "TOPRIGHT,TOPLEFT,1,1")

    local g = Frame()
    api.Adopt(g, { keepScale = true })
    g:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("不帶 followPanel：不改貼", g.points[1][2], tip)
end

------------------------------------------------------------
-- 隨行框（Panel.AdoptSidecar／AdoptKnownSidecars，2026-10-29）：不靠 Adopt、PLAYER_LOGIN 時自己認已知的全域框
-- ⇒ SetIgnoreParentAlpha(true)＋跟隨面板；沒裝那支插件就什麼都不做；Adopt 再套一次不會多掛一層
------------------------------------------------------------
do
    local env, ns, _, State = Setup()
    local api = env.MiliUITip_API
    ns.Panel.AdoptKnownSidecars()
    check("沒裝外觀預覽：不炸、沒登記", next(ns.Panel.followers) == nil)

    local f = Frame()
    env.AppearanceTooltipTooltip = f
    local setCalls = 0
    local raw = f.SetPoint
    f.SetPoint = function(...) setCalls = setCalls + 1; return raw(...) end
    ns.Panel.AdoptKnownSidecars()
    eq("已知的隨行框：SetIgnoreParentAlpha(true)", f.ignoreParentAlpha, true)
    check("已知的隨行框：登記跟隨", ns.Panel.followers[f] ~= nil)

    local tip = H.Tip(env, "GameTooltip", {})
    local panel = H.Region("Frame")
    panel:Show()
    State[tip] = { panel = panel }
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("已知的隨行框：貼到有面板的 tooltip ⇒ 改貼面板", f.points[1][2], panel)

    api.Adopt(f, { keepScale = true, ignoreParentAlpha = true, followPanel = true })   -- Skin 的委派再來一次
    eq("Adopt 再套：setter 又一次（冪等）", f.ignoreCalls, 2)
    setCalls = 0
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", tip, "TOPLEFT")
    eq("Adopt 再套：掛勾沒多一層（呼叫 1 次＋改貼 1 次）", setCalls, 2)

    eq("AdoptSidecar：不是框 ⇒ false", ns.Panel.AdoptSidecar("x"), false)
    check("AdoptSidecar：框沒有 SetIgnoreParentAlpha ⇒ 不炸、仍登記跟隨", ns.Panel.AdoptSidecar(H.Region("Frame")))
end

H.finish("Api_test")
