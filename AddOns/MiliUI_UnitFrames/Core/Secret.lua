------------------------------------------------------------
-- 秘密值：這支只留「單位框自己的那幾樣」，通用的在共用層
-- （Libs/MiliUIWidgets/Secret.lua，TOC 排在本檔之前）。
--
-- 鐵律：
--   1. 秘密值不做算術、比較、當 table key；boolean 秘密值不做布林測試
--   2. `x or default` 擋不住秘密值（非 boolean 秘密的布林測試合法且恆為真）
--   3. 秘密值只進「接受秘密值的 C API」：SetValue / SetText / SetFormattedText /
--      SetMinMaxValues / SetVertexColor(經曲線) / SetRaidTargetIconTexture …
--   4. 被 SetValue(secret) 餵過的 frame 幾何回讀全變秘密且會傳染 →
--      任何尺寸/位置一律來自設定值，絕不回讀單位框子樹的 GetWidth/GetHeight/GetPoint
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

-- 沿用本插件原本的短名（26 個 ns.IsSecret、14 個 ns.Desecret… 散在各處，
-- 不值得為了統一命名去動那麼多呼叫點）。
-- ⚠ ns.ToBool 原本對 false 回 nil、共用層回 false —— 全部使用點都只做布林測試
--   或接 `or false`，兩者等價（2026-08-28 逐一核對過）。
ns.IsSecret = S.IsSecret
ns.Desecret = S.SafeValue
ns.ToBool   = S.ToBool

------------------------------------------------------------
-- StatusBar 原生平滑：SetValue(value, interpolation) 是 C 端做的，吃秘密值
-- （Platynator 12.1 出貨的寫法）。絕不用 SmoothStatusBarMixin（Lua Clamp 會對秘密值算術）。
-- 開關是本插件自己的設定，所以包一層。
------------------------------------------------------------
function ns.BarInterp()
    return S.BarInterp(ns.db and ns.db.global.smoothBars ~= false)
end

------------------------------------------------------------
-- 曲線
------------------------------------------------------------
ns.Curves = {
    -- 秘密布林選色：回傳可直接餵 SetVertexColor 的三個值（可能是秘密）
    BoolColor = S.BoolColor,
}
