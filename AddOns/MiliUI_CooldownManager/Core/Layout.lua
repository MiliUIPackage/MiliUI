------------------------------------------------------------
-- 版面：純函式，給一串格子與版面設定，回每格的 (x, y, w, h) 與容器大小
--
--   local rects, totalW, totalH, anchorPoint = ns.Layout.Compute(items, layout, kind)
--
-- 輸入
--   items   有序陣列，只看長度（每項是什麼由呼叫端決定；之後的自訂項目也只是一格）
--   layout  { maxPerRow, spacing, grow, size = { w, h }, row2Size = false | { w, h } }
--   kind    "icons" | "bars"
--
-- 輸出
--   rects[i] = { x = , y = , w = , h = }   相對容器 **左上角**、x 往右、y 往下為正
--            （呼叫端寫成 SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)）
--   totalW, totalH                          容器該設的大小（最寬那列 × 全部列高加間距）
--   anchorPoint                             容器該用的錨點（見下）
--
-- 規則（計畫 §4.3）
--   * grow ＝ "<橫向>_<縱向>"。橫向 CENTER／LEFT／RIGHT 是**對齊**：每列各自置中／靠左／
--     靠右，列內順序一律由左到右（第一格在最左）。縱向 DOWN／UP 是換列方向：DOWN 第一列在
--     最上面、往下長；UP 第一列在最下面、往上長。
--   * 長條（kind = "bars"）一列一條，橫向那半不看：錨點只有 TOP／BOTTOM。
--   * 第一列用 size，第二列起用 row2Size（false ＝ 跟第一列一樣）。
--   * 容器寬取最寬那列，每列在容器裡各自對齊。
--   * anchorPoint：縱向 DOWN → TOP…、UP → BOTTOM…；橫向 CENTER 不加、LEFT／RIGHT 接在後面
--     （CENTER_DOWN → TOP、LEFT_UP → BOTTOMLEFT）。位置存的是這個錨點那一邊的座標，
--     格子增減時那一邊不動。
--   * 所有尺寸、間距、座標都過 P.Scale（像素對齊）。先把 w／h／間距對齊再累加，
--     累加出來的座標本來就落在像素格上；只有置中那半格要再對齊一次。
--
-- ⚠ 這支**不准呼叫任何 WoW API**：離線測試（Tests/Layout_test.lua）直接載入它，
--   P 在測試裡是 identity。ns.P 在呼叫當下才取，所以檔案層不依賴載入順序。
------------------------------------------------------------
local _, ns = ...

ns.Layout = {}
local Layout = ns.Layout

local floor, max = math.floor, math.max

-- 像素對齊：P.Scale 只保證非負數，負數（理論上不會出現）照樣對稱處理
local function Snap(v)
    local P = ns.P
    if not (P and P.Scale) or v == 0 then return v end
    if v < 0 then return -P.Scale(-v) end
    return P.Scale(v)
end
Layout.Snap = Snap

-- "CENTER_DOWN" → "CENTER", "DOWN"；認不得的一律退回 CENTER／DOWN
local H_OK = { CENTER = true, LEFT = true, RIGHT = true }
local V_OK = { DOWN = true, UP = true }
function Layout.ParseGrow(grow)
    local h, v
    if type(grow) == "string" then
        h, v = grow:match("^(%u+)_(%u+)$")
    end
    if not H_OK[h] then h = "CENTER" end
    if not V_OK[v] then v = "DOWN" end
    return h, v
end

function Layout.AnchorPoint(h, v, kind)
    local vert = (v == "UP") and "BOTTOM" or "TOP"
    if kind == "bars" or h == "CENTER" then return vert end
    return vert .. h
end

local function Dim(size, fallbackW, fallbackH)
    local w = type(size) == "table" and tonumber(size.w) or nil
    local h = type(size) == "table" and tonumber(size.h) or nil
    return max(0, w or fallbackW), max(0, h or fallbackH)
end

function Layout.Compute(items, layout, kind)
    layout = type(layout) == "table" and layout or {}
    local hAlign, vDir = Layout.ParseGrow(layout.grow)
    local anchorPoint = Layout.AnchorPoint(hAlign, vDir, kind)

    local n = type(items) == "table" and #items or 0
    local rects = {}
    if n == 0 then return rects, 0, 0, anchorPoint end

    local perRow
    if kind == "bars" then
        perRow = 1
    else
        perRow = floor(tonumber(layout.maxPerRow) or n)
        if perRow < 1 then perRow = 1 end
    end

    local w1, h1 = Dim(layout.size, 36, 36)
    local w2, h2 = w1, h1
    if type(layout.row2Size) == "table" then
        w2, h2 = Dim(layout.row2Size, w1, h1)
    end
    w1, h1, w2, h2 = Snap(w1), Snap(h1), Snap(w2), Snap(h2)
    local spacing = Snap(max(0, tonumber(layout.spacing) or 0))

    -- 先算每列的格數、格子大小、列寬；容器寬＝最寬那列，高＝列高相加＋列間距
    local rows = {}
    local totalW, totalH = 0, 0
    local i = 1
    while i <= n do
        local r = #rows + 1
        local count = n - i + 1
        if count > perRow then count = perRow end
        local w, h = w1, h1
        if r > 1 then w, h = w2, h2 end
        local rowW = count * w + (count - 1) * spacing
        rows[r] = { first = i, count = count, w = w, h = h, rowW = rowW }
        if rowW > totalW then totalW = rowW end
        totalH = totalH + h + (r > 1 and spacing or 0)
        i = i + count
    end

    -- 縱向：DOWN 第一列貼頂、往下累加；UP 第一列貼底、往上累加
    local cursor = 0
    for r = 1, #rows do
        local row = rows[r]
        local y
        if vDir == "UP" then
            y = totalH - cursor - row.h
        else
            y = cursor
        end
        cursor = cursor + row.h + spacing

        local x0
        if hAlign == "LEFT" or kind == "bars" then
            x0 = 0
        elseif hAlign == "RIGHT" then
            x0 = totalW - row.rowW
        else
            x0 = Snap((totalW - row.rowW) / 2)
        end

        for k = 0, row.count - 1 do
            rects[row.first + k] = {
                x = x0 + k * (row.w + spacing),
                y = y,
                w = row.w,
                h = row.h,
            }
        end
    end

    return rects, totalW, totalH, anchorPoint
end

-- 第一列的寬度（長條「寬 0 ＝ 跟核心技能第一列同寬」用）
function Layout.FirstRowWidth(n, layout)
    layout = type(layout) == "table" and layout or {}
    if not n or n <= 0 then return 0 end
    local perRow = floor(tonumber(layout.maxPerRow) or n)
    if perRow < 1 then perRow = 1 end
    local count = n < perRow and n or perRow
    local w = Snap((Dim(layout.size, 36, 36)))
    local spacing = Snap(max(0, tonumber(layout.spacing) or 0))
    return count * w + (count - 1) * spacing
end

------------------------------------------------------------
-- 錨定的排開（純函式）
--
-- 設定裡的錨定是「跟著誰、在它哪一邊」（anchor = { to, point, relPoint, x, y }）。
-- 照字面各自貼上去的話，兩個東西都選「核心技能上方」就會疊在一起，所以實際要貼在誰身上由
-- 這裡算：**跟著同一個目標、同一邊的算一疊，照固定順序往外排**，後面那個貼在前面那個的外緣
-- （前面那個自己身上同一邊還掛著東西的話，貼在那一串的最外面）。
--
--   Layout.AnchorOf(key, cfgOf)                   → anchor 表或 nil（目標不存在／成環＝沒有錨定）
--   Layout.AnchorSide(anchor)                     → "above"｜"below"｜"left"｜"right"｜nil（其他組合不排）
--   Layout.StackTarget(key, cfgOf, keys, rankOf)  → 實際該貼的 key（沒有錨定回 nil）
--
--   cfgOf(key)   那條的設定表（讀 .anchor 與 .enabled；enabled == false ＝ 關掉的面板）
--   keys         所有條與面板的 key
--   rankOf(key)  數字，小的靠近目標
--
-- 「有效的上一層」往上讓位的兩種情況（都是照字面貼一定會壓到東西的組合）：
--   * 目標關掉了、而且它自己也掛在同一邊 ⇒ 當它不存在，接到它的上一層
--   * 目標掛在**相反**那一邊（輔助技能「在自訂格子下方」，而自訂格子在核心技能「上方」）：
--     自訂格子的下方就是核心技能那一疊 ⇒ 改排到核心技能的下方去
--
-- 這樣算出來的「誰貼誰」不會成環（對有效上一層的樹做前序走訪，每條邊都指向更早的節點）；
-- Tests/Layout_test.lua 有一輪隨機樹在驗。
------------------------------------------------------------
local OPPOSITE = { above = "below", below = "above", left = "right", right = "left" }

function Layout.AnchorSide(a)
    if type(a) ~= "table" then return nil end
    local p, r = tostring(a.point or "TOP"), tostring(a.relPoint or "BOTTOM")
    if p:find("^TOP") and r:find("^BOTTOM") then return "below" end
    if p:find("^BOTTOM") and r:find("^TOP") then return "above" end
    if p:find("RIGHT$") and r:find("LEFT$") then return "left" end
    if p:find("LEFT$") and r:find("RIGHT$") then return "right" end
    return nil
end

function Layout.AnchorOf(key, cfgOf)
    local bar = cfgOf(key)
    local a = type(bar) == "table" and bar.anchor
    if type(a) ~= "table" or type(a.to) ~= "string" or not cfgOf(a.to) then return nil end
    -- 環檢查：沿著 to 走，走回自己就是環
    local seen, cur = { [key] = true }, a.to
    while cur do
        if seen[cur] then return nil end
        seen[cur] = true
        local nb = cfgOf(cur)
        local na = type(nb) == "table" and nb.anchor
        cur = (type(na) == "table" and type(na.to) == "string" and cfgOf(na.to)) and na.to or nil
    end
    return a
end

local function Enabled(cfg)
    return type(cfg) == "table" and cfg.enabled ~= false
end

-- 有效的上一層與邊。side == nil ＝ 這個錨定不參與排開（照字面貼）
local function EffParent(key, cfgOf)
    local a = Layout.AnchorOf(key, cfgOf)
    if not a then return nil end
    local side = Layout.AnchorSide(a)
    local to = a.to
    if not side then return to, nil end
    for _ = 1, 32 do
        local ta = Layout.AnchorOf(to, cfgOf)
        local ts = ta and Layout.AnchorSide(ta)
        if not ts then break end
        if ts == OPPOSITE[side] or (ts == side and not Enabled(cfgOf(to))) then
            to = ta.to
        else
            break
        end
    end
    return to, side
end

local function Siblings(parent, side, cfgOf, keys, rankOf)
    local out = {}
    for i = 1, #keys do
        local k = keys[i]
        if k ~= parent and Enabled(cfgOf(k)) then
            local to, s = EffParent(k, cfgOf)
            if to == parent and s == side then out[#out + 1] = k end
        end
    end
    table.sort(out, function(x, y)
        local rx, ry = tonumber(rankOf(x)) or 0, tonumber(rankOf(y)) or 0
        if rx ~= ry then return rx < ry end
        return x < y
    end)
    return out
end

-- key 身上同一邊那一串的最外面那個（沒掛東西就是它自己）
local function Tail(key, side, cfgOf, keys, rankOf, depth)
    if depth > 32 then return key end
    local kids = Siblings(key, side, cfgOf, keys, rankOf)
    if #kids == 0 then return key end
    return Tail(kids[#kids], side, cfgOf, keys, rankOf, depth + 1)
end

function Layout.StackTarget(key, cfgOf, keys, rankOf)
    local a = Layout.AnchorOf(key, cfgOf)
    if not a then return nil end
    -- 關掉的面板不佔位：照字面貼在它的目標上（只是給錨在它身上的東西一個位置）
    if not Enabled(cfgOf(key)) then return a.to end
    local parent, side = EffParent(key, cfgOf)
    if not side then return parent end
    local sibs = Siblings(parent, side, cfgOf, keys, rankOf)
    local prev
    for i = 1, #sibs do
        if sibs[i] == key then break end
        prev = sibs[i]
    end
    if not prev then return parent end
    return Tail(prev, side, cfgOf, keys, rankOf, 0)
end
