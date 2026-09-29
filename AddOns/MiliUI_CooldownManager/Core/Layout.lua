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
