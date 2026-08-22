------------------------------------------------------------
-- 12.1 秘密值 / forbidden object 工具
--
-- 通則（詳見 .claude/notes/wow-121-secret-values.md）：
--   允許：存變數、傳參數、字串串接、format、對非布林做布林測試（x or y）
--   禁止：算術、比較、# 、當 table key、index、對布林秘密做布林測試
-- 「當傳遞者，不當讀取者」——秘密值原封不動交給 C 端 API，判斷讓暴雪做。
------------------------------------------------------------
local _, ns = ...

local _issecretvalue = _G.issecretvalue

ns.Secret = {}
local S = ns.Secret

function S.IsSecret(v)
    return _issecretvalue and _issecretvalue(v) and true or false
end

-- 秘密 / nil → default。要比較、要當 table key 之前先過這裡。
function S.SafeValue(v, default)
    if v == nil or S.IsSecret(v) then return default end
    return v
end

-- pcall 包呼叫，最多回十個值；失敗回 nil
function S.SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
end

-- 呼叫 + 「結果是否明文 true」。秘密布林 / 失敗一律回 false（fail-open 方向由呼叫端負責）
function S.SafeBool(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok then return false end
    if S.IsSecret(value) then return false end
    return value == true
end

-- 明文字串才回傳（秘密字串不能做 gsub/find，要跑字串運算前先過這裡）
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
-- forbidden object：12.1 之後某些 tooltip 會被系統借走、動態變成 forbidden，
-- 對它呼叫任何方法（連 NumLines()）都會拋錯。這是動態狀態，每個入口都要重問；
-- IsForbidden 本身在 forbidden object 上永遠可以呼叫。
------------------------------------------------------------
function S.IsForbiddenObject(obj)
    return (obj and obj.IsForbidden and obj:IsForbidden()) and true or false
end
