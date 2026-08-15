------------------------------------------------------------
-- 12.1 秘密值工具
-- 鐵律：
--   1. 秘密值不做算術、比較、當 table key；boolean 秘密值不做布林測試
--   2. `x or default` 擋不住秘密值（非 boolean 秘密的布林測試合法且恆為真）
--   3. 秘密值只進「接受秘密值的 C API」：SetValue / SetText / SetFormattedText /
--      SetMinMaxValues / SetVertexColor(經曲線) / SetRaidTargetIconTexture …
--   4. 被 SetValue(secret) 餵過的 frame 幾何回讀全變秘密且會傳染 →
--      任何尺寸/位置一律來自設定值，絕不回讀單位框子樹的 GetWidth/GetHeight/GetPoint
------------------------------------------------------------
local _, ns = ...

local _issecretvalue = issecretvalue

function ns.IsSecret(v)
    return _issecretvalue and _issecretvalue(v) and true or false
end

-- 秘密值或 nil → default。要拿去當 table key / 比較 / 算術之前必經這裡。
function ns.Desecret(v, default)
    if v == nil or ns.IsSecret(v) then return default end
    return v
end

-- 秘密 boolean → nil（布林測試前必經）
function ns.ToBool(v)
    if ns.IsSecret(v) then return nil end
    if v then return true end
    return nil
end

-- pcall 包裝：秘密值算術逃逸用（部分布林測試的 taint error 會穿透 pcall，
-- 只對「算術/比較」類使用，不要拿來包布林測試）
function ns.SafeCall(fn, ...)
    return pcall(fn, ...)
end

------------------------------------------------------------
-- StatusBar 原生平滑：SetValue(value, interpolation) 是 C 端做的，吃秘密值
-- （Platynator 12.1 出貨的寫法）。絕不用 SmoothStatusBarMixin（Lua Clamp 會對秘密值算術）
------------------------------------------------------------
local INTERP = Enum.StatusBarInterpolation
function ns.BarInterp()
    if INTERP and ns.db and ns.db.global.smoothBars ~= false then
        return INTERP.ExponentialEaseOut
    end
    return nil          -- nil = 立即（等同單參數 SetValue）
end

------------------------------------------------------------
-- 曲線快取（曲線物件可重複使用，建一次）
------------------------------------------------------------
ns.Curves = {}

-- 秘密 boolean 選色：回傳可直接餵 SetVertexColor 的三個值（可能是秘密）
local _EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
function ns.Curves.BoolColor(secretBool, rT, gT, bT, rF, gF, bF)
    if not _EvalBool then return rF, gF, bF end
    return _EvalBool(secretBool, rT, rF), _EvalBool(secretBool, gT, gF), _EvalBool(secretBool, bT, bF)
end

-- 0→0 / 1→100 曲線（百分比文字用）
local percent100
function ns.Curves.Percent100()
    if not percent100 and C_CurveUtil and C_CurveUtil.CreateCurve then
        percent100 = C_CurveUtil.CreateCurve()
        percent100:AddPoint(0, 0)
        percent100:AddPoint(1, 100)
    end
    return percent100
end
