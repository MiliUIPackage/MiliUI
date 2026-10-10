------------------------------------------------------------
-- 版面：純函式，給一串格子與版面設定，回每格的 (x, y, w, h) 與容器大小
--
--   local rects, totalW, totalH, anchorPoint = ns.Layout.Compute(items, layout, kind)
--
-- 輸入
--   items   有序陣列，只看長度（每項是什麼由呼叫端決定；之後的自訂項目也只是一格）
--   layout  { maxPerRow, spacing, grow, size = { w, h }, row2Size = false | { w, h } }
--   kind    "icons" | "bars"
--   圓環（layout.style ＝ "rings"，只有圖示類）另外讀 layout.ring ＝ { thickness, gap, direction }（呼叫端從條的 ring 子表塞進來）
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
--   * 圓環（layout.style ＝ "rings"）：同心圓，見下面「圓環」那一節（ComputeRings）。maxPerRow／row2Size／grow 不看。
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

------------------------------------------------------------
-- 圓環（layout.style ＝ "rings"）：每格一圈同心圓
--
--   * 第 1 個 entry 是最內圈（direction ＝ "outward"）；"inward" 反過來，第 1 個是最外圈。
--   * 基準直徑 base ＝ size.w；第 k 圈（k ＝ 從內往外數）直徑 D_k ＝ base ＋ 2·(k−1)·(thick ＋ gap)；容器 Dmax × Dmax。
--   * 每格是邊長 D_k 的正方形，x ＝ y ＝ (Dmax − D_k) / 2 ＝ (n − k)·step：thick、gap 是整數 px，偏移永遠是整數，
--     中心不會因奇偶跑掉；base 與 step 各自過 Snap 再累加 ⇒ 每個值都落在像素格上。
--   * 錨點固定 CENTER（圈數增減時圓心不動）。
--   * rect 多帶兩欄：ring ＝ k（從內往外第幾圈；Decorate 拿來排 overlay 層級：內圈高）、
--     tex ＝ Layout.RingTexture(thick, D_k)（這一圈用第幾張環形貼圖）。
--   留空位（emptyMode ＝ "blank"）的 entry 照樣佔一圈 ⇒ 每個效果固定在同一圈。
------------------------------------------------------------
-- 環形貼圖：Media/ring-01.png ～ ring-20.png，第 j 張的環寬比例（環寬 ÷ 直徑）＝ RING_MIN × (RING_MAX / RING_MIN)^((j−1)/(STEPS−1))。
-- ⚠ 跟 .claude/skills/miliui-cdm-ring-textures/scripts/rings.py 的 STEPS／RATIO_MIN／RATIO_MAX 綁在一起
Layout.RING_STEPS, Layout.RING_MIN, Layout.RING_MAX = 20, 0.02, 0.30
Layout.RING_THICK = { min = 2, max = 24, default = 8 }
Layout.RING_GAP   = { min = 0, max = 16, default = 3 }
Layout.RING_ICON  = { min = 8, max = 32, default = 14 }

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- 第 j 張貼圖的環寬比例
function Layout.RingRatio(j)
    local n = Layout.RING_STEPS
    return Layout.RING_MIN * (Layout.RING_MAX / Layout.RING_MIN) ^ ((j - 1) / (n - 1))
end

-- 環寬 thick、直徑 d 的那一圈該用第幾張：比例 thick / d 取對數距離最近的（比例是等比級數，對數下等距）。
-- 比最細的還細／比最粗的還粗就用頭尾那張；壞值退回中間
function Layout.RingTexture(thick, d)
    thick, d = tonumber(thick), tonumber(d)
    local n = Layout.RING_STEPS
    if not (thick and d) or thick <= 0 or d <= 0 then return math.floor((n + 1) / 2) end
    local r = thick / d
    local lo, hi = Layout.RING_MIN, Layout.RING_MAX
    if r <= lo then return 1 end
    if r >= hi then return n end
    local t = math.log(r / lo) / math.log(hi / lo) * (n - 1)
    return Clamp(floor(t + 0.5) + 1, 1, n)
end

function Layout.RingFile(j)
    return ("Interface\\AddOns\\MiliUI_CooldownManager\\Media\\ring-%02d.png"):format(Clamp(floor(tonumber(j) or 1), 1, Layout.RING_STEPS))
end

-- 條的 ring 子表 → 環寬、間距（整數 px，夾在範圍內）、方向
function Layout.RingParams(ring)
    ring = type(ring) == "table" and ring or {}
    local T, G = Layout.RING_THICK, Layout.RING_GAP
    local t = Clamp(floor((tonumber(ring.thickness) or T.default) + 0.5), T.min, T.max)
    local g = Clamp(floor((tonumber(ring.gap) or G.default) + 0.5), G.min, G.max)
    local dir = ring.direction == "inward" and "inward" or "outward"
    return t, g, dir
end

-- 圖示大小（開「顯示法術圖示」時）：整數 px，夾在範圍內
function Layout.RingIconSize(v)
    local I = Layout.RING_ICON
    return Clamp(floor((tonumber(v) or I.default) + 0.5), I.min, I.max)
end

-- 這條是不是圓環（圖示類才有；長條類存著 style 也不算）。
-- source：條的來源（給了才看）。圓環條只收增益：核心／輔助（冷卻類的暴雪檢視器）存著 rings 也當圖示
-- （⚠ 跟 Core/DB.lua 的 BarIsRings 同一份規則）。只拿排版用的表（Bars 的 BarSize 解好的）時不給，
-- 那張表已經照來源濾過（Layout.AsIcons）
Layout.RING_DENY_SOURCE = { essential = true, utility = true }
function Layout.IsRings(layout, kind, source)
    return kind ~= "bars" and not Layout.RING_DENY_SOURCE[source] and type(layout) == "table" and layout.style == "rings"
end

-- 存著 rings、但這條不出圓環（核心／輔助）：排版照圖示排。淺複製一份、style 換成 icons（存檔不動）
function Layout.AsIcons(layout)
    local out = {}
    for k, v in pairs(type(layout) == "table" and layout or {}) do out[k] = v end
    out.style = "icons"
    return out
end

local function ComputeRings(n, layout)
    local rects = {}
    if n == 0 then return rects, 0, 0, "CENTER" end
    local thick, gap, dir = Layout.RingParams(layout.ring)
    local base = Snap((Dim(layout.size, 36, 36)))
    local step = Snap(thick + gap)
    local dmax = base + 2 * (n - 1) * step
    for i = 1, n do
        local k = (dir == "inward") and (n - i + 1) or i
        local d = base + 2 * (k - 1) * step
        local off = (n - k) * step
        rects[i] = { x = off, y = off, w = d, h = d, ring = k, tex = Layout.RingTexture(thick, d) }
    end
    return rects, dmax, dmax, "CENTER"
end

-- 圓環條的文字位置（純函式；Core/Text.lua 與設定頁預覽共用）：一律錨在那一圈的 TOP，往下 thick/2 ＝ 落在頂端的環帶上。
--   rs      Decorate.RingStyle 解好的那包（thick、showIcon、iconSize）
--   cdSize  倒數的字級
-- 回傳 { y, iconX, cdPoint, cdX, extraX }：
--   沒開圖示：倒數 CENTER 在正中；層數／充能 LEFT 接在倒數右邊（估倒數兩位數寬的一半＋一點）
--   開了圖示：圖示置中；倒數 LEFT 接在圖示右緣外 2；層數／充能再往右（估倒數兩位數寬）
-- 層數不錨在倒數那顆 FontString 上（它的字是引擎寫的，寬度可能是秘密值，錨定鏈會傳染），一律用估的偏移
function Layout.RingTextPlace(rs, cdSize)
    rs = type(rs) == "table" and rs or {}
    local thick = tonumber(rs.thick) or Layout.RING_THICK.default
    local size = tonumber(cdSize) or 10
    local p = { y = -thick / 2, iconX = 0 }
    if rs.showIcon then
        local half = (tonumber(rs.iconSize) or Layout.RING_ICON.default) / 2
        p.cdPoint, p.cdX = "LEFT", half + 2
        p.extraX = half + 2 + floor(size * 1.3 + 0.5)
    else
        p.cdPoint, p.cdX = "CENTER", 0
        p.extraX = floor(size * 0.9 + 0.5)
    end
    return p
end

function Layout.Compute(items, layout, kind)
    layout = type(layout) == "table" and layout or {}
    local n0 = type(items) == "table" and #items or 0
    if Layout.IsRings(layout, kind) then return ComputeRings(n0, layout) end
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

------------------------------------------------------------
-- 引擎補位的 flow 參數（只有光環格的條，Modules/Custom.lua 的「引擎補位」；純函式）
--
--   fp = Layout.FlowParams(layout, kind)     layout ＝ 跟 Compute 同一張（Bars 的 BarSize 解好的）
--   fp = { axis = "H"|"V", point, flowPoint, hDir = "RIGHT"|"LEFT", vDir = "DOWN"|"UP",
--          w, h, spacing, perLine, lineSize }
--
-- 做法：容器（AuraContainer）排完會把自己的大小設成內容的大小（暴雪 FlowLayout 的 OnLayoutComplete），
-- 所以**對齊交給容器自己的錨點**：容器用 point 錨在補位持有框（＝條容器的矩形）的同一個點，
-- 容器裡的元素一律從 flowPoint 那個角開始、往 hDir／vDir 長。
--   * 橫排（圖示、橫向長條）：axis H，flowPoint ＝ TOPLEFT／BOTTOMLEFT（縱向 DOWN／UP），往右長、往下／上換列；
--     point ＝ Compute 的 anchorPoint（CENTER_DOWN → TOP：容器的頂邊中點貼條的頂邊中點 ⇒ 整排置中）。
--     列內順序跟 Compute 一樣由左到右。⚠ 多列時每一列在容器裡都靠左（引擎沒有逐列對齊）：
--     置中／靠右的條只有「最寬那列」對得準，最後一列不足時靠左（Compute 是每列各自置中／靠右）。
--   * 直排（直向圖示、直向長條）：axis V，point ＝ flowPoint ＝ Compute 的 anchorPoint（起點那個角），
--     往伸展方向（DOWN／UP）排、往換列方向（RIGHT／LEFT）開下一列——跟 ComputeColumns 一致。
--   * 長條一列一條：perLine ＝ 1。
--   * lineSize ＝ 主軸上的**像素預算**（暴雪 FlowLayout 拿累積的元素尺寸跟它比，不是顆數）：
--     perLine × 主軸尺寸 ＋ (perLine − 1) × 間距 ＋ 半格容忍（浮點誤差不讓第 perLine 顆被擠到下一列；
--     第 perLine＋1 顆需要再多一整格加間距，半格擋得住）。沒設每列上限 ⇒ perLine／lineSize 都是 nil（不換列）。
--   * 尺寸、間距照 Compute 對齊（Snap、間距不小於 0）。第二列尺寸不進來（BarAuraFlow 的 "row2" 擋掉）。
------------------------------------------------------------
function Layout.FlowParams(layout, kind)
    layout = type(layout) == "table" and layout or {}
    local w, h = Dim(layout.size, 36, 36)
    w, h = Snap(w), Snap(h)
    local spacing = Snap(max(0, tonumber(layout.spacing) or 0))
    local fp = { w = w, h = h, spacing = spacing }
    local colGrow, colWrap
    if kind == "bars" then
        if layout.vertical then colGrow, colWrap = Layout.VerticalBarGrow(layout.grow) end
    else
        colGrow, colWrap = Layout.ParseColumn(layout.grow)
    end
    local per
    if kind == "bars" then
        per = 1
    elseif tonumber(layout.maxPerRow) then
        per = floor(tonumber(layout.maxPerRow))
        if per < 1 then per = 1 end
    end
    local main
    if colGrow then
        fp.axis = "V"
        fp.point = ((colGrow == "UP") and "BOTTOM" or "TOP") .. ((colWrap == "LEFT") and "RIGHT" or "LEFT")
        fp.flowPoint = fp.point
        fp.hDir = (colWrap == "LEFT") and "LEFT" or "RIGHT"
        fp.vDir = (colGrow == "UP") and "UP" or "DOWN"
        main = h
    else
        local hAlign, vDir = Layout.ParseGrow(layout.grow)
        if kind == "bars" then
            local g = Layout.ParseColumn(layout.grow)
            if g then vDir = g end
        end
        fp.axis = "H"
        fp.point = Layout.AnchorPoint(hAlign, vDir, kind)
        fp.flowPoint = ((vDir == "UP") and "BOTTOM" or "TOP") .. "LEFT"
        fp.hDir = "RIGHT"
        fp.vDir = vDir
        main = w
    end
    if per then
        fp.perLine = per
        fp.lineSize = per * main + (per - 1) * spacing + main / 2
    end
    return fp
end

-- flow 參數的簽章（換了就換一顆容器；Modules/Custom.lua 的引擎補位串進容器簽章）
function Layout.FlowSig(fp)
    fp = type(fp) == "table" and fp or {}
    return table.concat({ tostring(fp.axis), tostring(fp.point), tostring(fp.flowPoint), tostring(fp.hDir), tostring(fp.vDir),
        string.format("%.2f,%.2f,%.2f", tonumber(fp.w) or 0, tonumber(fp.h) or 0, tonumber(fp.spacing) or 0),
        tostring(fp.perLine), fp.lineSize and string.format("%.2f", fp.lineSize) or "-" }, ",")
end

-- 圖示的 texcoord：zoom 先四邊各切 z；crop（非正方形「裁切」）再把長邊多的那段兩頭對半切掉，
-- 圖案維持正方形比例不被拉扁。crop 關（「拉伸」）或正方形 ⇒ 照舊四邊各切 z
function Layout.IconTexCoord(z, w, h, crop)
    z = tonumber(z) or 0
    if z < 0 then z = 0 elseif z > 0.45 then z = 0.45 end
    local l, r, t, b = z, 1 - z, z, 1 - z
    w, h = tonumber(w), tonumber(h)
    if crop and w and h and w > 0 and h > 0 and w ~= h then
        local span = 1 - 2 * z
        if w > h then
            local m = span * (1 - h / w) / 2
            t, b = t + m, b - m
        else
            local m = span * (1 - w / h) / 2
            l, r = l + m, r - m
        end
    end
    return l, r, t, b
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
    -- 圓環：整組同心圓的直徑
    if Layout.IsRings(layout, "icons") then
        local items = {}
        for k = 1, n do items[k] = k end
        local _, w = Layout.Compute(items, layout, "icons")
        return w
    end
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
-- 增益不在時（條層 layout.emptyMode ＋ 逐法術覆寫 emptyMode；設定頁同一個三態下拉）
--
--   "collapse"  隱藏，後面的往前補（收合：不佔格）
--   "blank"     隱藏，留空位（格子照留、什麼都不畫）
--   "dim"       暗圖示佔位（圖示類畫去飽和圖示；長條類畫空長條）
--
-- 條上有光環格或可點擊（forced）：格子戰鬥中不能動 ⇒ "collapse" 不成立。
--   條層存著 collapse ⇒ 退回圖示類 "dim"、長條類照舊欄位 layout.emptyStyle（"bar" ⇒ "dim"，其餘 "blank"）——
--   跟以前「強制固定格位」的畫面一樣（emptyStyle 已經沒有控件，只剩這個用途；v7 遷移不刪它）。
--   逐法術存著 collapse ⇒ 當跟隨條（讀取時判，不改存檔：光環格可以只在某個專精，條是整個設定檔共用的）。
--
--   mode = Layout.BarEmptyMode(stored, forced, isBars, legacyStyle)
--   mode, own = Layout.SpellEmptyMode(override, barMode, forced)   own ＝ 這一格自己設的（不是跟隨條）
------------------------------------------------------------
Layout.EMPTY_MODES = { collapse = true, blank = true, dim = true }

function Layout.BarEmptyMode(stored, forced, isBars, legacyStyle)
    local m = Layout.EMPTY_MODES[stored] and stored or "collapse"
    if forced and m == "collapse" then
        if isBars then return legacyStyle == "bar" and "dim" or "blank" end
        return "dim"
    end
    return m
end

function Layout.SpellEmptyMode(override, barMode, forced)
    if Layout.EMPTY_MODES[override] and not (forced and override == "collapse") then return override, true end
    return barMode, false
end

------------------------------------------------------------
-- 增益 item 這一格怎麼排（Bars.Relayout 放格與 Bars.Occupancy 佔位判斷共用同一個判準）
--
--   slot = Layout.AuraSlot(shown, mode)
--     shown  這一刻在（AuraPresent）
--     mode   這一格生效的「增益不在時」（Layout.SpellEmptyMode 的結果）
--   → "item"         放 item 本身
--     "placeholder"  不在、格子照留、畫占位（mode ＝ dim）
--     "blank"        不在、格子照留、什麼都不畫（mode ＝ blank）
--     nil            收合：不佔格、不認領
------------------------------------------------------------
function Layout.AuraSlot(shown, mode)
    if shown then return "item" end
    if mode == "dim" then return "placeholder" end
    if mode == "blank" then return "blank" end
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
