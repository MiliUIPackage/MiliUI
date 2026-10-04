------------------------------------------------------------
-- 格數上限＋溢出到別條（純函式；不碰任何 WoW API，離線可測）
--
--   ns.Overflow.Target(key, cfgOf)                    → 目標 key, 上限  或  nil, 原因
--   ns.Overflow.Receivers(keys, cfgOf)                → { [目標] = { 來源 key… } }（設定頁：誰指到我）
--   ns.Overflow.Resolve(barKeys, baseOf, cfgOf, occ)  → res（見下）或 nil（沒有任何一條成立）
--
-- 資料：條的 layout.maxIcons（0 ＝ 不限；1～20）、layout.overflowTo（false 或另一條的 key）。
-- 只有圖示類的條（kind ~= "bars"）。舊存檔沒有這兩欄 ＝ 0／false ＝ 不限（行為不變）。
--
-- 成立條件（全部要成立，否則整條照舊、**不截斷**）：
--   * 自己是圖示類、maxIcons > 0
--   * overflowTo 指到存在、不是自己、同為圖示類、而且自己 maxIcons == 0 的條（不連鎖：接收條不能再溢出；
--     兩條互指時兩邊都有上限 ⇒ 兩邊都不成立）
--
-- 截法：溢出的是「清單順序最後的那幾顆」。佔一格的才算顆數——occ(key, id) 回 false 的（收合中不在的增益、
-- 暴雪沒給框的）不佔位、不算，也不搬（留在來源條，出現了下一輪再算）。沒給 occ ＝ 每一顆都算
-- （設定頁的預覽用這個：預覽本來就每格都畫）。固定格位的占位、自訂項目都佔一格。
-- 接收條的清單 ＝ 自己的 ＋ 溢來的（接在尾端；多條溢到同一條時照 barKeys 的順序，每條內保留來源條的順序）。
--
-- res：
--   out[key]      這條套完溢出的清單（只有來源條與接收條有；其他條 nil ＝ 照 base）
--   to[key]       來源條溢出去的 id（順序同清單）
--   toSet[key]    同上，集合
--   from[key]     接收條上溢來的 id → 來源 key
--   into[key]     接收條的來源 key 清單（照 barKeys 順序；只列真的有東西溢過來的）
--   target[key]   來源條成立的目標（就算這一輪沒有東西溢出也記）
------------------------------------------------------------
local _, ns = ...

local O = {}
ns.Overflow = O

O.MAX = 20

local function IsIcons(b)
    return type(b) == "table" and b.kind ~= "bars"
end

local function MaxOf(b)
    local l = type(b) == "table" and type(b.layout) == "table" and b.layout or nil
    local n = l and tonumber(l.maxIcons) or 0
    if n ~= n or n <= 0 then return 0 end          -- NaN、負數、0
    n = math.floor(n)
    if n > O.MAX then n = O.MAX end
    return n
end
O.MaxOf = MaxOf

local function TargetKey(b)
    local l = type(b) == "table" and type(b.layout) == "table" and b.layout or nil
    local to = l and l.overflowTo
    if type(to) == "string" and to ~= "" and to ~= "none" then return to end
    return nil
end
O.TargetKey = TargetKey

-- 原因：kind（自己不是圖示類）、nomax（沒設上限）、notarget（沒選目標）、self、missing（目標不存在）、
--       notIcons（目標是長條類）、capped（目標自己有上限）
function O.Target(key, cfgOf)
    local b = cfgOf(key)
    if not IsIcons(b) then return nil, "kind" end
    local max = MaxOf(b)
    if max <= 0 then return nil, "nomax" end
    local to = TargetKey(b)
    if not to then return nil, "notarget" end
    if to == key then return nil, "self" end
    local t = cfgOf(to)
    if type(t) ~= "table" then return nil, "missing" end
    if not IsIcons(t) then return nil, "notIcons" end
    if MaxOf(t) > 0 then return nil, "capped" end
    return to, max
end

-- 誰指到我（設定頁：接收條的「最多顆數」停用並寫原因）。只算有設上限的來源（沒設上限時那個指向是休眠的）
function O.Receivers(keys, cfgOf)
    local out = {}
    for _, k in ipairs(keys) do
        local b = cfgOf(k)
        local to = IsIcons(b) and MaxOf(b) > 0 and TargetKey(b) or nil
        if to and to ~= k then
            local list = out[to]
            if not list then list = {}; out[to] = list end
            list[#list + 1] = k
        end
    end
    return out
end

-- 成立的 (來源, 目標) 對，照 barKeys 順序
function O.Pairs(barKeys, cfgOf)
    local list
    for _, k in ipairs(barKeys) do
        local to = O.Target(k, cfgOf)
        if to then
            list = list or {}
            list[#list + 1] = { src = k, dst = to }
        end
    end
    return list
end

function O.Resolve(barKeys, baseOf, cfgOf, occ)
    local pairsList = O.Pairs(barKeys, cfgOf)
    if not pairsList then return nil end
    local res = { out = {}, to = {}, toSet = {}, from = {}, into = {}, target = {} }
    local moved = {}         -- [dst] = { { src, ids }… }
    for _, pr in ipairs(pairsList) do
        local src, dst = pr.src, pr.dst
        local _, max = O.Target(src, cfgOf)
        res.target[src] = dst
        local base = baseOf(src) or {}
        local keep, gone, set = {}, {}, {}
        local n = 0
        for _, id in ipairs(base) do
            local counts = (occ == nil) or occ(src, id) ~= false
            if counts then
                n = n + 1
                if n > max then
                    gone[#gone + 1] = id
                    set[id] = true
                else
                    keep[#keep + 1] = id
                end
            else
                keep[#keep + 1] = id
            end
        end
        res.out[src] = keep
        if #gone > 0 then
            res.to[src], res.toSet[src] = gone, set
            local m = moved[dst]
            if not m then m = {}; moved[dst] = m end
            m[#m + 1] = { src = src, ids = gone }
        end
    end
    -- 接收條：自己的＋溢來的（照來源順序接在尾端；已經在清單上的不重複放）
    for _, pr in ipairs(pairsList) do
        local dst = pr.dst
        if res.out[dst] == nil then
            local base = baseOf(dst) or {}
            local list, have = {}, {}
            for _, id in ipairs(base) do list[#list + 1] = id; have[id] = true end
            local from, into = {}, {}
            for _, m in ipairs(moved[dst] or {}) do
                local any = false
                for _, id in ipairs(m.ids) do
                    if not have[id] then
                        have[id] = true
                        list[#list + 1] = id
                        from[id] = m.src
                        any = true
                    end
                end
                if any then into[#into + 1] = m.src end
            end
            res.out[dst] = list
            if #into > 0 then res.from[dst], res.into[dst] = from, into end
        end
    end
    return res
end
