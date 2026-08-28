------------------------------------------------------------
-- 12.1 秘密值工具（共用層）
--
-- 通則（完整版在 .claude/notes/wow-121-secret-values.md）：
--   允許：存變數、傳參數、字串串接、format、對**非布林**做布林測試（`x or y`）、
--         `type(v)`、原封不動交給吃得下秘密值的 C API
--   禁止：算術、比較（`==` `<`）、`#`、當 table **key**、對它 index、
--         對**布林**秘密做布林測試、`tostring`
--
-- 一句話：**當傳遞者，不當讀取者。**
--
-- ⚠⚠ 為什麼這包要進共用層：**這組規則已經改過三輪，還會再改。**
--   （PTR 7 的 Unit API 清單、PTR 8 的 UnitIsCharmed 例外、UnitName 在 PvP 的放寬）
--   2026-08-28 體檢時全套組有 15 處各自宣告 `issecretvalue`、四種不同命名，
--   下一輪規則變動要改 15 個地方，而漏掉的那個不會報錯 —— 只會在某個副本裡
--   顯示錯的東西。
--
-- ⚠ 這支**沒有任何相依**（不讀 Env、不讀語系），所以要排在 TOC 最前面，
--   跟 PixelPerfect.lua 一起。宿主的 Core 檔在檔案層就會用到它。
------------------------------------------------------------
local _, ns = ...

local _issecretvalue = _G.issecretvalue

ns.Secret = {}
local S = ns.Secret

------------------------------------------------------------
-- 判斷
------------------------------------------------------------
-- 舊客戶端沒有這個全域 ⇒ 沒有秘密值 ⇒ 一律回 false（而不是炸）
function S.IsSecret(v)
    return _issecretvalue and _issecretvalue(v) and true or false
end

------------------------------------------------------------
-- 洗值
------------------------------------------------------------
-- 秘密或 nil → default。**要比較、要當 table key、要做算術之前一律先過這裡。**
function S.SafeValue(v, default)
    if v == nil or S.IsSecret(v) then return default end
    return v
end

-- 秘密布林 → nil。布林秘密值連 `v and true or false` 都會炸，所以「不給知道」
-- 必須是第三種答案，讓呼叫端自己決定要 fail-open 還是 fail-closed
-- （範本見 .claude/notes/wow-121-identity-gate-failopen.md）。
function S.ToBool(v)
    if v == nil or S.IsSecret(v) then return nil end
    return v and true or false
end

-- 明文字串才回傳。秘密字串不能 gsub / find / sub / #，跑字串運算前先過這裡。
function S.PlainText(v)
    if type(v) ~= "string" then return end
    if S.IsSecret(v) then return end
    return v
end

-- 明文數字才回傳
function S.PlainNumber(v)
    if type(v) ~= "number" then return end
    if S.IsSecret(v) then return end
    return v
end

------------------------------------------------------------
-- 包呼叫
------------------------------------------------------------
-- pcall 包，最多回十個值；失敗回 nil。
-- ⚠ 這支**吃掉 ok 旗標**（跟裸 pcall 不同）—— 呼叫端拿到 nil 就是「問不到」。
function S.SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
end

-- 呼叫 ＋「結果是不是明文 true」。秘密布林與失敗一律回 false。
-- ⚠ 需要分辨「false」與「不給知道」的地方**不要用這支**，用 SafeCall + ToBool。
function S.SafeBool(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok then return false end
    if S.IsSecret(value) then return false end
    return value == true
end

------------------------------------------------------------
-- forbidden object
--
-- 12.1 之後某些暴雪物件（tooltip 最常見）會被系統借走、**動態**變成 forbidden，
-- 對它呼叫任何方法（連 NumLines()）都會拋錯。這是動態狀態，每個入口都要重問；
-- IsForbidden 本身在 forbidden object 上永遠可以呼叫。
------------------------------------------------------------
function S.IsForbiddenObject(obj)
    return (obj and obj.IsForbidden and obj:IsForbidden()) and true or false
end

------------------------------------------------------------
-- 顯示秘密值而不讀取它的官方管道
------------------------------------------------------------
-- StatusBar 的原生內插：`SetValue(value, interpolation)` 是 C 端做的，吃秘密值。
-- **絕不用 SmoothStatusBarMixin** —— 那是 Lua，會對秘密值做 Clamp 算術。
-- 呼叫端自己決定要不要平滑（通常是個設定），這裡只給列舉值。
local INTERP = Enum and Enum.StatusBarInterpolation
function S.BarInterp(smooth)
    if smooth and INTERP then return INTERP.ExponentialEaseOut end
    return nil          -- nil = 立即（等同單參數 SetValue）
end

-- 秘密布林選色：回傳可直接餵 SetVertexColor 的三個值（可能是秘密）
local _EvalBool = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
function S.BoolColor(secretBool, rT, gT, bT, rF, gF, bF)
    if not _EvalBool then return rF, gF, bF end
    return _EvalBool(secretBool, rT, rF), _EvalBool(secretBool, gT, gF), _EvalBool(secretBool, bT, bF)
end
