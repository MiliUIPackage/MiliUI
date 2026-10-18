------------------------------------------------------------
-- Api.lua（MiliUITip_API.Adopt）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Api_test.lua
--
-- 覆蓋：opts.ignoreParentAlpha 會 SetIgnoreParentAlpha(true)、不帶就不碰；已經接管過也照套；
-- 還沒初始化（ns.db 沒有）回 false 且什麼都不碰；keepScale 照原樣交給 TrackTip。
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
            Get = function(t) return State[t] end,
            ApplyBase = function() end,
        },
        Options = { Open = function() end },
    }
    ns.TrackTip = function(tip, isPreview, opts)
        tracked[#tracked + 1] = { tip = tip, opts = opts }
        State[tip] = {}
    end
    H.Load(env, ns, "Api.lua")
    return env, ns, tracked
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

H.finish("Api_test")
