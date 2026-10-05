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
--   * 直向（只有圖示）：grow ＝ "<伸展>_<換列>"，伸展 DOWN／UP、換列 RIGHT／LEFT（"DOWN_RIGHT"…）。
--     一列（直的那一排）由第一格往伸展方向排，滿了 maxPerRow 往換列那一邊開下一列；每列各自貼齊
--     起點那一端（DOWN 貼頂、UP 貼底）。第二列起用 row2Size。anchorPoint：伸展 DOWN → TOP…、
--     UP → BOTTOM…；換列 RIGHT → …LEFT、LEFT → …RIGHT（起點那個角不動）。
--   * 長條（kind = "bars"）一列一條，橫向那半不看：錨點只有 TOP／BOTTOM。
--     長條存了直向的 grow（"UP_RIGHT"…，直向長條切回橫向時留下的）⇒ 伸展那半當縱向（UP → 往上）。
--   * 直向長條（kind = "bars" 且 layout.vertical，F8c）：條一條一條並排，等於直向圖示 maxPerRow ＝ 1：
--     grow 用直向那組（伸展 DOWN／UP ＝ 貼頂／貼底，換列 RIGHT／LEFT ＝ 往右／往左排）；
--     存的是橫向長條的 grow（"CENTER_DOWN"／"CENTER_UP"）⇒ 縱向那半當伸展、往右排。
--     size 由呼叫端給好（w ＝ 條的粗細、h ＝ 條長）。
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

-- "DOWN_RIGHT" → "DOWN", "RIGHT"；不是直向的值回 nil（橫向那一套照舊走 ParseGrow）
local COL_GROW = { DOWN = true, UP = true }
local COL_WRAP = { LEFT = true, RIGHT = true }
function Layout.ParseColumn(grow)
    if type(grow) ~= "string" then return nil end
    local g, w = grow:match("^(%u+)_(%u+)$")
    if COL_GROW[g] and COL_WRAP[w] then return g, w end
    return nil
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

-- 直向：一列是直的一排，列往左或右開
local function ComputeColumns(n, layout, growDir, wrapDir)
    local anchorPoint = ((growDir == "UP") and "BOTTOM" or "TOP") .. ((wrapDir == "LEFT") and "RIGHT" or "LEFT")
    local rects = {}
    if n == 0 then return rects, 0, 0, anchorPoint end
    local perCol = floor(tonumber(layout.maxPerRow) or n)
    if perCol < 1 then perCol = 1 end
    local w1, h1 = Dim(layout.size, 36, 36)
    local w2, h2 = w1, h1
    if type(layout.row2Size) == "table" then
        w2, h2 = Dim(layout.row2Size, w1, h1)
    end
    w1, h1, w2, h2 = Snap(w1), Snap(h1), Snap(w2), Snap(h2)
    local spacing = Snap(max(0, tonumber(layout.spacing) or 0))

    local cols = {}
    local totalW, totalH = 0, 0
    local i = 1
    while i <= n do
        local c = #cols + 1
        local count = n - i + 1
        if count > perCol then count = perCol end
        local w, h = w1, h1
        if c > 1 then w, h = w2, h2 end
        local colH = count * h + (count - 1) * spacing
        cols[c] = { first = i, count = count, w = w, h = h }
        if colH > totalH then totalH = colH end
        totalW = totalW + w + (c > 1 and spacing or 0)
        i = i + count
    end

    local cursor = 0
    for c = 1, #cols do
        local col = cols[c]
        local x
        if wrapDir == "LEFT" then x = totalW - cursor - col.w else x = cursor end
        cursor = cursor + col.w + spacing
        for k = 0, col.count - 1 do
            local y = k * (col.h + spacing)
            if growDir == "UP" then y = totalH - y - col.h end
            rects[col.first + k] = { x = x, y = y, w = col.w, h = col.h }
        end
    end
    return rects, totalW, totalH, anchorPoint
end

-- 直向長條的 grow：直向那組照收；橫向那組（長條只有 CENTER_DOWN／CENTER_UP）換成「同一個縱向、往右排」
function Layout.VerticalBarGrow(grow)
    local g, w = Layout.ParseColumn(grow)
    if g then return g, w end
    local _, v = Layout.ParseGrow(grow)
    return v, "RIGHT"
end

function Layout.Compute(items, layout, kind)
    layout = type(layout) == "table" and layout or {}
    local n0 = type(items) == "table" and #items or 0
    if kind ~= "bars" then
        local g, w = Layout.ParseColumn(layout.grow)
        if g then return ComputeColumns(n0, layout, g, w) end
    elseif layout.vertical then
        local g, w = Layout.VerticalBarGrow(layout.grow)
        return ComputeColumns(n0, { maxPerRow = 1, spacing = layout.spacing, size = layout.size }, g, w)
    end
    local hAlign, vDir = Layout.ParseGrow(layout.grow)
    if kind == "bars" then
        -- 直向長條切回橫向時留下的直向 grow：伸展那半當縱向
        local g = Layout.ParseColumn(layout.grow)
        if g then vDir = g end
    end
    local anchorPoint = Layout.AnchorPoint(hAlign, vDir, kind)

    local n = n0
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

-- 長條格子的尺寸（F8c）：橫向 w ＝ 條長、h ＝ 粗細；直向反過來（w ＝ 粗細、h ＝ 條長）
function Layout.BarCellSize(length, thickness, vertical)
    if vertical then return thickness, length end
    return length, thickness
end

-- 第一列的寬度（長條「寬 0 ＝ 跟核心技能第一列同寬」用）
function Layout.FirstRowWidth(n, layout)
    layout = type(layout) == "table" and layout or {}
    if not n or n <= 0 then return 0 end
    -- 直向：看得到的寬是全部列加起來（第一列只有一格寬，拿它當基準沒意義）
    if Layout.ParseColumn(layout.grow) then
        local items = {}
        for k = 1, n do items[k] = k end
        local _, w = Layout.Compute(items, layout, "icons")
        return w
    end
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
--   Layout.StackTarget(key, cfgOf, keys, rankOf [, skip])  → 實際該貼的 key（沒有錨定回 nil）
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
-- active(key)：這條現在佔不佔位（開著、而且沒有收合）
local function EffParent(key, cfgOf, active)
    local a = Layout.AnchorOf(key, cfgOf)
    if not a then return nil end
    local side = Layout.AnchorSide(a)
    local to = a.to
    if not side then return to, nil end
    for _ = 1, 32 do
        local ta = Layout.AnchorOf(to, cfgOf)
        local ts = ta and Layout.AnchorSide(ta)
        if not ts then break end
        if ts == OPPOSITE[side] or (ts == side and not active(to)) then
            to = ta.to
        else
            break
        end
    end
    return to, side
end

local function Siblings(parent, side, cfgOf, keys, rankOf, active)
    local out = {}
    for i = 1, #keys do
        local k = keys[i]
        if k ~= parent and active(k) then
            local to, s = EffParent(k, cfgOf, active)
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
local function Tail(key, side, cfgOf, keys, rankOf, active, depth)
    if depth > 32 then return key end
    local kids = Siblings(key, side, cfgOf, keys, rankOf, active)
    if #kids == 0 then return key end
    return Tail(kids[#kids], side, cfgOf, keys, rankOf, active, depth + 1)
end

-- skip(key)（可省）：回 true 的當作不佔位——收合中的面板（沒有內容、高度 0）。
-- ⚠ 不能讓別人貼在收合的面板上：高度 0 的框在遊戲裡沒有有效的矩形，貼在它身上的整條都畫不出來
--   （沒有自訂格子的專精，輔助技能整條消失就是這樣來的）。所以收合跟關掉一樣處理：後面的接到它的上一層。
function Layout.StackTarget(key, cfgOf, keys, rankOf, skip)
    local a = Layout.AnchorOf(key, cfgOf)
    if not a then return nil end
    local function active(k)
        return Enabled(cfgOf(k)) and not (skip and skip(k))
    end
    local parent, side = EffParent(key, cfgOf, active)
    -- 自己不佔位（關掉／收合）：貼在有效的上一層上，只是給照字面錨在它身上的東西一個位置
    if not active(key) then return parent end
    if not side then return parent end
    local sibs = Siblings(parent, side, cfgOf, keys, rankOf, active)
    local prev
    for i = 1, #sibs do
        if sibs[i] == key then break end
        prev = sibs[i]
    end
    if not prev then return parent end
    return Tail(prev, side, cfgOf, keys, rankOf, active, 0)
end

------------------------------------------------------------
-- 就地比較的序列（Bars 的「這一輪認領有沒有變」，決定要不要重建法術索引）
--
--   changed = Layout.SeqPut(seq, i, v, changed)   seq[i] 跟 v 不同就覆寫並回 true，否則回原本的 changed
--   changed = Layout.SeqTrim(seq, n, changed)     n 之後的尾巴清掉（上一輪比較長 ⇒ 變了）
--   Layout.SameIDs(a, b)                          兩個序列逐格相同（只讀，測試／除錯用）
--
-- 不配置新表：上一輪的序列就地改寫成這一輪的。nil 存成 false（序列不能有洞，# 才準）。
------------------------------------------------------------
function Layout.SeqPut(seq, i, v, changed)
    if v == nil then v = false end
    if seq[i] ~= v then
        seq[i] = v
        return true
    end
    return changed
end

function Layout.SeqTrim(seq, n, changed)
    for i = #seq, n + 1, -1 do
        seq[i] = nil
        changed = true
    end
    return changed
end

function Layout.SameIDs(a, b)
    a, b = a or {}, b or {}
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

------------------------------------------------------------
-- 增益 item 這一格怎麼排（Bars.Relayout 放格與 Bars.Occupancy 佔位判斷共用同一個判準）
--
--   mode = Layout.AuraSlot(shown, fixed, placeholder)
--     shown        這一刻在（AuraPresent）
--     fixed        條的固定格位開著／被強制（光環格、可點擊）
--     placeholder  這一招逐法術勾了「無增益時保留空位」（ns.SpellSetting(…, "placeholder") == true）
--   → "item"         放 item 本身
--     "placeholder"  不在、但格子照留（畫占位；長條類照 layout.emptyStyle）
--     nil            收合：不佔格、不認領
--
-- 回非 nil ＝ 認領這顆 item（claimedBy）、也算一顆（溢出的顆數）。
------------------------------------------------------------
function Layout.AuraSlot(shown, fixed, placeholder)
    if shown then return "item" end
    if fixed or placeholder == true then return "placeholder" end
    return nil
end

------------------------------------------------------------
-- 被「沒有物品時隱藏／被動飾品不顯示」收掉的格怎麼排（Bars.Relayout 放格與 Bars.Occupancy 佔位判斷共用）
--
--   mode = Layout.HiddenSlot(reason, fixed)
--     reason  Catalog.HideReason 的結果（"noItem"／"passive"／"noBuff"；nil ＝ 照常顯示）
--     fixed   條的固定格位開著／被強制（光環格、飾品疊增益、可點擊）
--   → nil      照常放
--     "blank"  收掉、格子照留（固定格位：這一格空著，後面的不往前補；佔一格、算顆數）
--     "skip"   收掉、讓位（不佔格、不算顆數，後面的往前補）
------------------------------------------------------------
function Layout.HiddenSlot(reason, fixed)
    if not reason then return nil end
    if fixed then return "blank" end
    return "skip"
end
