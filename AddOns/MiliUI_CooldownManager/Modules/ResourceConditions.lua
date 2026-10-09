------------------------------------------------------------
-- 資源條的條件規則：資料模型與求值（純邏輯，不碰任何 WoW API，離線可測）
--
--   conditions[資源key] = { rule, rule, ... }   由上而下，**第一條成立的就用它**
--   rule  = { target    = nil | 格子索引,          nil ＝整條，數字＝只作用在第 N 格
--             check     = leaf | { op = "and", children = { leaf, ... } },
--             overrides = { color, bgColor, alpha, tagColor } }   每一項都可缺
--   leaf  = { var = "always" / "powerValue" / "powerPercent" / "powerFull"
--                   / "spec" / "pipRecharging",
--             cmp = ">=" / ">" / "<=" / "<" / "==" / "~=",  value = 數字 | 布林 }
--
-- 形狀跟單位框架（MiliUI_UnitFrames）的資源條一模一樣：套組接線階段那邊會讀這裡的規則
-- （公開 API GetResourceConditions），兩邊必須是同一套 schema、同一套語意。
--
-- ⚠ 規則表是玩家的存檔、也可能來自匯入字串：每一步都驗型別，壞掉的規則當作不成立，
--   **絕對不報錯** —— 這段掛在能量事件上，一秒好幾次，在這裡拋一次例外就是整條資源條消失。
--   遞迴另外設深度上限，防自我參照的壞資料。
--
-- ⚠ 求值只吃**明文**：資源值是秘密值時呼叫端（Modules/Resources.lua）整段不求值
--   （條件不成立＝照原本的顏色），不在這裡比較秘密值。
--
-- ⚠ 效能：狀態寫在呼叫端給的 scratch 表（RC.NewState 建一次、重複用），
--   熱路徑上一個 table／closure／字串都不配。
------------------------------------------------------------
local _, ns = ...

ns.ResCond = {}
local RC = ns.ResCond

-- 白名單：不在這張表裡的 cmp 一律當規則不成立。順序給設定頁列下拉用
local CMP_OPS = {
    [">="] = function(a, b) return a >= b end,
    [">"]  = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"]  = function(a, b) return a < b end,
    ["=="] = function(a, b) return a == b end,
    ["~="] = function(a, b) return a ~= b end,
}
RC.CMP_OPS = CMP_OPS
RC.CMP_LIST = { ">=", ">", "<=", "<", "==", "~=" }

RC.CHECK_VARS = {
    always = true, powerValue = true, powerPercent = true,
    powerFull = true, spec = true, pipRecharging = true,
}

RC.MAX_CHECK_DEPTH = 4
RC.MAX_SEGMENTS = 30

function RC.ValidColor(c)
    if type(c) ~= "table" then return nil end
    if type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then return nil end
    return c
end
local ValidColor = RC.ValidColor

function RC.NewState()
    return { powerValue = 0, powerPercent = 0, powerFull = false, spec = 0, pipRecharging = false }
end

-- cur/max 是這一列的「值」與「上限」（**明文**）：
-- 連續條＝目前值／上限；點數型＝目前點數／格數；符文列＝已經轉好的顆數／格數
function RC.FillState(state, cur, max, spec)
    cur = cur or 0
    state.powerValue = cur
    state.powerPercent = (max and max > 0) and (cur / max * 100) or 0
    state.powerFull = (max and max > 0 and cur >= max) or false
    state.spec = spec or 0
    state.pipRecharging = false
    return state
end

function RC.EvalLeaf(node, state)
    local var = node.var
    if var == "always" then return true end
    if var == "powerFull" then
        if type(node.value) ~= "boolean" then return false end
        return state.powerFull == node.value
    end
    if var == "pipRecharging" then
        if type(node.value) ~= "boolean" then return false end
        return state.pipRecharging == node.value
    end
    local fn = CMP_OPS[node.cmp]
    if not fn or type(node.value) ~= "number" then return false end
    if var == "powerValue" then return fn(state.powerValue, node.value) end
    if var == "powerPercent" then return fn(state.powerPercent, node.value) end
    if var == "spec" then return fn(state.spec, node.value) end
    return false
end
local EvalLeaf = RC.EvalLeaf

-- op 只有 and：任何非 nil 的 op 都當 and。空的 children 判成立
local function EvalCheck(node, state, depth)
    if type(node) ~= "table" then return false end
    if depth > RC.MAX_CHECK_DEPTH then return false end
    if node.op then
        local children = node.children
        if type(children) ~= "table" then return false end
        local n = #children
        if n == 0 then return true end
        for i = 1, n do
            if not EvalCheck(children[i], state, depth + 1) then return false end
        end
        return true
    end
    return EvalLeaf(node, state)
end
RC.EvalCheck = EvalCheck

-- index = nil  只看「整條」的規則（target 沒設的那些）
-- index = i    看「整條或指定第 i 格」的規則
-- 回傳 overrides, 規則序號；都不成立回 nil
function RC.FirstMatch(conds, state, index)
    if type(conds) ~= "table" then return nil end
    for i = 1, #conds do
        local rule = conds[i]
        if type(rule) == "table" then
            local t = rule.target
            -- t 是壞值（字串之類）時兩個條件都不成立 ⇒ 整條規則被跳過
            if t == nil or (index ~= nil and t == index) then
                local ov = rule.overrides
                if type(ov) == "table" and rule.check ~= nil and EvalCheck(rule.check, state, 1) then
                    return ov, i
                end
            end
        end
    end
    return nil
end

-- 設定表裡這個資源的規則（**既有的表**，不複製）；沒有或是空的回 nil
function RC.Resolve(cfg, key)
    local root = type(cfg) == "table" and cfg.conditions
    local t = type(root) == "table" and root[key]
    if type(t) == "table" and t[1] ~= nil then return t end
    return nil
end

------------------------------------------------------------
-- 檢查：一律當成**陣列**看（設定頁用）
--
-- 存法：只有一條就直接存 leaf，兩條以上才包成 { op = "and", children }。
------------------------------------------------------------
function RC.CheckCount(rule)
    local c = type(rule) == "table" and rule.check
    if type(c) ~= "table" then return 0 end
    if c.op then
        local ch = c.children
        return (type(ch) == "table") and #ch or 0
    end
    return 1
end

function RC.CheckAt(rule, i)
    local c = type(rule) == "table" and rule.check
    if type(c) ~= "table" then return nil end
    if c.op then
        local ch = c.children
        return (type(ch) == "table") and ch[i] or nil
    end
    return (i == 1) and c or nil
end

function RC.ChecksArray(rule)
    local out = {}
    for i = 1, RC.CheckCount(rule) do out[i] = RC.CheckAt(rule, i) end
    return out
end

function RC.SetChecks(rule, list)
    if list[2] == nil then
        rule.check = list[1]
    else
        rule.check = { op = "and", children = list }
    end
end

-- 表單形狀的簽章：哪幾條規則、每條幾個檢查、有沒有 target（設定頁據此決定要不要換一份表單）
function RC.Signature(cfg, key)
    local rules = RC.Resolve(cfg, key)
    if not rules then return "0" end
    local parts = { tostring(#rules) }
    for i = 1, #rules do
        local r = rules[i]
        parts[#parts + 1] = tostring(RC.CheckCount(r)) .. ((type(r) == "table" and r.target) and ("t" .. tostring(r.target)) or "")
    end
    return table.concat(parts, ".")
end

------------------------------------------------------------
-- 秘密值時的整條換色：規則 → 階梯色曲線的點（純函式，Tests/Resources_test.lua）
--
-- 12.1 戰鬥中連續條（漩渦、怒氣、能量…）的 UnitPower 是秘密值，Lua 不能比較 ⇒ 不在 Lua 求值，
-- 改把「整條」的規則（target 沒設的）事先展開成一條 Step 曲線，交給 UnitPowerPercent(…, curve) 在 C 端挑顏色。
-- 規則只看得到「值」：powerValue／powerPercent／powerFull 由 x（0～1）推得出來，spec 用建曲線時的專精，
-- pipRecharging 在連續條上恆為 false ⇒ 每一種檢查都展得開。只轉顏色（overrides.color）；
-- 底色、透明度、文字色這幾項秘密值時不套（呼叫端照常清掉）。
--
-- 斷點：0、每個門檻的 t 與 t⁺（t 加一點點），powerFull 的 1。Step 取「最後一個 x ≤ 目前比例」的點，
-- 每個點的顏色＝把那個點當成目前值、跑一次 FirstMatch（規則順序、第一條成立的優先，跟明文時一樣）。
--   max ＝ 明文的上限（powerValue 的門檻要換成比例）；nil 而規則用到 powerValue ⇒ 回 nil（展不開）
--   base ＝ 沒有規則成立時的顏色
-- 回傳 { { x, r, g, b, a }, … }（x 由小到大、去重）；沒有整條規則或展不開回 nil
------------------------------------------------------------
local EPS = 1e-4

local function CollectLeaves(node, out, depth)
    if type(node) ~= "table" or depth > RC.MAX_CHECK_DEPTH then return end
    if node.op then
        if type(node.children) ~= "table" then return end
        for i = 1, #node.children do CollectLeaves(node.children[i], out, depth + 1) end
        return
    end
    out[#out + 1] = node
end

-- 斷點帶著精確的值與百分比（不從 x 反推：0.9 * 100 是 90.00000000000001，門檻那一點會判錯）
local function AddPoint(pts, x, v, p)
    pts[#pts + 1] = { x = x, v = v, p = p }
end

function RC.CurvePoints(conds, max, spec, base)
    if type(conds) ~= "table" or not ValidColor(base) then return nil end
    if max ~= nil and (type(max) ~= "number" or max <= 0) then max = nil end
    local cand, any = {}, false
    AddPoint(cand, 0, 0, 0)
    for i = 1, #conds do
        local rule = conds[i]
        if type(rule) == "table" and rule.target == nil and type(rule.overrides) == "table" then
            any = true
            local leaves = {}
            CollectLeaves(rule.check, leaves, 1)
            for _, lf in ipairs(leaves) do
                local val = lf.value
                if lf.var == "powerValue" and type(val) == "number" then
                    if not max then return nil end
                    AddPoint(cand, val / max, val, val / max * 100)
                    AddPoint(cand, val / max + EPS, val + EPS * max, val / max * 100 + EPS * 100)
                elseif lf.var == "powerPercent" and type(val) == "number" then
                    AddPoint(cand, val / 100, max and val * max / 100 or 0, val)
                    AddPoint(cand, val / 100 + EPS, max and (val / 100 + EPS) * max or 0, val + EPS * 100)
                elseif lf.var == "powerFull" then
                    AddPoint(cand, 1, max or 0, 100)
                end
            end
        end
    end
    if not any then return nil end
    table.sort(cand, function(a, b) return a.x < b.x end)
    local state = RC.NewState()
    local pts = {}
    local last
    for _, c0 in ipairs(cand) do
        local x = c0.x
        if x >= 0 and x <= 1 and x ~= last then
            last = x
            state.powerPercent = c0.p
            state.powerValue = c0.v
            state.powerFull = x >= 1
            state.spec = spec or 0
            state.pipRecharging = false
            local ov = RC.FirstMatch(conds, state, nil)
            local c = (ov and ValidColor(ov.color)) or base
            pts[#pts + 1] = { x, c.r, c.g, c.b, c.a or 1 }
        end
    end
    return pts
end
