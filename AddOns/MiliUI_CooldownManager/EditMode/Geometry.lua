------------------------------------------------------------
-- 編輯模式的幾何：純函式，離線可測（Tests/EditMode_test.lua）
--
--   EM.PointXY(point, l, r, t, b)          矩形上某個錨點的座標
--   EM.PosFromRect(ap, pp, rect, parent)   容器的 ap 那一點相對 parent 的 pp 那一點的偏移
--   EM.SnapDelta(ap, l, r, t, b, ox, oy, step)
--                                          把 ap 那一點吸到以 (ox, oy) 為原點的格線上要挪多少
--   EM.AlignDelta(rect, others, range)     跟其他條的邊／中心對齊要挪多少（沒得吸的軸回 nil）
--   EM.ReadPos(key)                        放手時把容器現況換算回 bars[key].pos（面板是 profile[key].pos）
--
-- 位置語意（Core/Bars.lua 的 ApplyStructure）：容器用版面算出來的錨點
-- （state[key].anchorPoint：CENTER_DOWN → TOP、LEFT_UP → BOTTOMLEFT…）貼在
-- UIParent 的 pos.point 上加 (x, y)。所以反推＝「容器錨點那一點」減「UIParent 的
-- pos.point 那一點」，兩個都是 UIParent 座標系裡的值。
--
-- ⚠ 這支**只准碰** ns.Bars.Get／ns.Bars.AnchorPoint／ns.profile／UIParent 的 GetLeft 系列：
--   離線測試用一個只有這幾樣的環境直接載入它。
------------------------------------------------------------
local _, ns = ...

ns.EditMode = ns.EditMode or {}
local EM = ns.EditMode

local floor = math.floor

-- 錨點在矩形上的位置：x 由左到右 0～1、y 由下到上 0～1
local FRAC = {
    TOPLEFT    = { 0,   1   }, TOP    = { 0.5, 1   }, TOPRIGHT    = { 1, 1   },
    LEFT       = { 0,   0.5 }, CENTER = { 0.5, 0.5 }, RIGHT       = { 1, 0.5 },
    BOTTOMLEFT = { 0,   0   }, BOTTOM = { 0.5, 0   }, BOTTOMRIGHT = { 1, 0   },
}
EM.POINT_FRAC = FRAC

function EM.PointXY(point, l, r, t, b)
    local f = FRAC[point] or FRAC.CENTER
    return l + (r - l) * f[1], b + (t - b) * f[2]
end

-- rect／parent = { l, r, t, b }
function EM.PosFromRect(anchorPoint, posPoint, rect, parent)
    local ax, ay = EM.PointXY(anchorPoint, rect[1], rect[2], rect[3], rect[4])
    local px, py = EM.PointXY(posPoint, parent[1], parent[2], parent[3], parent[4])
    return ax - px, ay - py
end

-- 存檔用：四捨五入到整數（跟套組其他拖曳一致；ApplyStructure 套用時再像素對齊）
function EM.Round(v)
    return floor(v + 0.5)
end

function EM.SnapValue(v, step)
    if not step or step <= 0 then return v end
    return floor(v / step + 0.5) * step
end

-- 吸附範圍：離吸附點 SNAP_RANGE（UIParent 座標）以內才吸，格線與條對齊共用。
-- 歷史：原本永遠吸最近的格線（半格 16px）太黏 → 09-30 改成格距的 1/6；但格距調大時範圍跟著
-- 放大（100 的格距＝17px，「很遠就飄過去」），10-02 改成固定值、不隨格距。
EM.SNAP_RANGE = 4

-- 只吸錨點那一邊：錨點（相對原點）離格線夠近才吸過去，兩軸各自判斷，回傳整個矩形要挪的量
function EM.SnapDelta(anchorPoint, l, r, t, b, ox, oy, step)
    if not step or step <= 0 then return 0, 0 end
    local ax, ay = EM.PointXY(anchorPoint, l, r, t, b)
    local rx, ry = ax - ox, ay - oy
    local range = EM.SNAP_RANGE
    local dx, dy = EM.SnapValue(rx, step) - rx, EM.SnapValue(ry, step) - ry
    if dx > range or dx < -range then dx = 0 end
    if dy > range or dy < -range then dy = 0 end
    return dx, dy
end

-- 對齊其他條：rect／others[i] = { l, r, t, b }。X 軸試左貼左、右貼右、左貼右、右貼左、中心對中心，
-- Y 軸同理；兩軸各自挑最近的一個，超出 range 的那一軸回 nil（呼叫端再退去吸格線）
function EM.AlignDelta(rect, others, range)
    local l, r, t, b = rect[1], rect[2], rect[3], rect[4]
    local cx, cy = (l + r) / 2, (t + b) / 2
    local bx, by
    local function tx(d) if d >= -range and d <= range and (not bx or math.abs(d) < math.abs(bx)) then bx = d end end
    local function ty(d) if d >= -range and d <= range and (not by or math.abs(d) < math.abs(by)) then by = d end end
    for i = 1, #(others or {}) do
        local o = others[i]
        local ol, orr, ot, ob = o[1], o[2], o[3], o[4]
        tx(ol - l); tx(orr - r); tx(orr - l); tx(ol - r); tx((ol + orr) / 2 - cx)
        ty(ot - t); ty(ob - b); ty(ob - t); ty(ot - b); ty((ot + ob) / 2 - cy)
    end
    return bx, by
end

-- 框的矩形；任一邊讀不到（還沒錨定、秘密值）回 nil
local function Plain(v)
    if type(v) ~= "number" then return nil end
    local sec = ns.IsSecret
    if sec and sec(v) then return nil end
    return v
end

function EM.RectOf(frame)
    if not frame then return nil end
    local l, r = Plain(frame:GetLeft()), Plain(frame:GetRight())
    local t, b = Plain(frame:GetTop()), Plain(frame:GetBottom())
    if not (l and r and t and b) then return nil end
    return { l, r, t, b }
end

-- 放手時的位置：{ point = pos.point（維持既有，預設 CENTER）, x, y }；讀不到回 nil
function EM.ReadPos(key)
    local B = ns.Bars
    local c = B and B.Get(key)
    local p = ns.profile
    local bar = p and type(p.bars) == "table" and p.bars[key]
    -- 面板（資源條、施法條）存在 profile[key]（ns.PANEL_KEYS 由 Core/DB.lua 給；離線測試可以不給）
    if bar == nil and p and ns.PANEL_KEYS and ns.PANEL_KEYS[key] then bar = p[key] end
    if not (c and type(bar) == "table") then return nil end
    local rect, parent = EM.RectOf(c), EM.RectOf(UIParent)
    if not (rect and parent) then return nil end
    local anchorPoint = B.AnchorPoint and B.AnchorPoint(key) or "CENTER"
    local point = type(bar.pos) == "table" and FRAC[bar.pos.point] and bar.pos.point or "CENTER"
    local x, y = EM.PosFromRect(anchorPoint, point, rect, parent)
    return { point = point, x = EM.Round(x), y = EM.Round(y) }
end
