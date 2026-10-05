------------------------------------------------------------
-- Masque 套在**我們自己的框**上的形狀，讀回來存成純數字／字串
--
--   ns.MasqueShape.ReadShape(frame, icon, w, h[, normal]) → { ix, iy, iw, ih, l, r, t, b, mask, normal, sig }／nil
--   ns.MasqueShape.AssetOf(texture)                         → atlas, file（都沒有 ⇒ nil, nil）
--
-- 使用者：Modules/Custom.lua 光環格的探針與疊層（圖示形狀＋遮罩＋皮外框，烘進引擎按鈕）、
--         Core/Keybinds.lua 按鍵鏡射的閃光（只取遮罩，掛到閃光貼圖上）。
-- 只讀：GetPoint／GetSize／GetTexCoord／遮罩與貼圖的 getter，全部 pcall＋Plain；讀不懂 ⇒ nil（呼叫端當方形）。
-- 讀的是 Masque 套過皮的 region（我們交給它的 Icon、它回給我們的 Normal），不讀 Masque 自己的表。
------------------------------------------------------------
local _, ns = ...

ns.MasqueShape = {}
local MS = ns.MasqueShape

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end
local function Str(v)
    v = Plain(v)
    return (type(v) == "string" and v ~= "") and v or nil
end

-- region 的矩形 → { x, y（中心相對基準框中心）, w, h }。只認錨在 known 裡的框上的：一點錨（任何錨點＋偏移），
-- 或 SetAllPoints（兩點、同一個框、錨點對錨點、偏移 0）。其他排法讀不懂 ⇒ nil
local PX = { LEFT = -1, TOPLEFT = -1, BOTTOMLEFT = -1, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
local PY = { TOP = 1, TOPLEFT = 1, TOPRIGHT = 1, BOTTOM = -1, BOTTOMLEFT = -1, BOTTOMRIGHT = -1 }
local function RectOf(region, known)
    local n = Num(Try(region.GetNumPoints, region))
    if n == 1 then
        local p, rel, rp, ox, oy = Try(region.GetPoint, region, 1)
        p, rp, rel = Str(p), Str(rp), Plain(rel) or Try(region.GetParent, region)
        local base = rel ~= nil and known[rel] or nil
        local w, h = Num(Try(region.GetWidth, region)), Num(Try(region.GetHeight, region))
        if not (base and p and rp and w and h and w > 0 and h > 0) then return nil end
        ox, oy = Num(ox) or 0, Num(oy) or 0
        return { x = base.x + (PX[rp] or 0) * base.w / 2 + ox - (PX[p] or 0) * w / 2,
                 y = base.y + (PY[rp] or 0) * base.h / 2 + oy - (PY[p] or 0) * h / 2, w = w, h = h }
    elseif n == 2 then
        local p1, rel1, rp1, x1, y1 = Try(region.GetPoint, region, 1)
        local p2, rel2, rp2, x2, y2 = Try(region.GetPoint, region, 2)
        rel1, rel2 = Plain(rel1), Plain(rel2)
        local base = rel1 ~= nil and rel1 == rel2 and known[rel1] or nil
        if base and Str(p1) and Str(p1) == Str(rp1) and Str(p2) and Str(p2) == Str(rp2) and Str(p1) ~= Str(p2)
            and Num(x1) == 0 and Num(y1) == 0 and Num(x2) == 0 and Num(y2) == 0 then
            return { x = base.x, y = base.y, w = base.w, h = base.h }
        end
    end
    return nil
end

local function F2(v) return string.format("%.2f", v) end
local function F4x4(a, b2, c2, d) return string.format("%.4f,%.4f,%.4f,%.4f", a, b2, c2, d) end

-- 貼圖的內容：圖集優先，其次檔案路徑、檔案 ID。都沒有 ⇒ nil, nil
local function AssetOf(t)
    local atlas = Str(Try(t.GetAtlas, t))
    if atlas then return atlas, nil end
    local file = Str(Try(t.GetTextureFilePath, t))
    if not file then
        -- ⚠ 插件自己的貼圖（皮的檔案都是）檔案編號是**負數**（實測 Raeli 的外框 -5272）：只要不是 0 都收。
        -- 再退 GetTexture（回編號或路徑）
        local id = Num(Try(t.GetTextureFileID, t))
        if id and id ~= 0 then
            file = id
        else
            local v = Plain(Try(t.GetTexture, t))
            if (type(v) == "number" and v ~= 0) or (type(v) == "string" and v ~= "") then file = v end
        end
    end
    return nil, file
end

-- GetTexCoord：左上 x,y、左下 x,y、右上 x,y、右下 x,y（八個值，Try 只回五個 ⇒ 直接 pcall）。讀不到 ⇒ 0,1,0,1
local function TexCoordOf(t)
    local ok, l, tp, _, _, _, _, r, b = pcall(t.GetTexCoord, t)
    if ok then l, tp, r, b = Num(l), Num(tp), Num(r), Num(b) end
    if not (ok and l and tp and r and b) then return 0, 1, 0, 1 end
    return l, r, tp, b
end

local DRAW_LAYERS = { BACKGROUND = true, BORDER = true, ARTWORK = true, OVERLAY = true }
local BLENDS = { BLEND = true, ADD = true, MOD = true, ALPHAKEY = true, DISABLE = true }

-- 皮外框（Normal）的外觀：false ＝ 讀到了、這張皮沒有外框（藏著／沒貼圖／透明）；nil ＝ 讀不到
local function ReadNormal(nt, known)
    if not nt then return nil end
    local shown = Plain(Try(nt.IsShown, nt))
    if shown == nil then return nil end
    local alpha = Num(Try(nt.GetAlpha, nt))
    local atlas, file = AssetOf(nt)
    if shown == false or alpha == 0 or not (atlas or file) then return false end
    local rr = RectOf(nt, known)
    if not rr then return nil end
    local okC, cr, cg, cb, ca = pcall(nt.GetVertexColor, nt)
    if okC then cr, cg, cb, ca = Num(cr), Num(cg), Num(cb), Num(ca) end
    if not (okC and cr and cg and cb) then cr, cg, cb, ca = 1, 1, 1, 1 end
    ca = (ca or 1) * (alpha or 1)
    local blend = Str(Try(nt.GetBlendMode, nt))
    if not BLENDS[blend] then blend = "BLEND" end
    local okL, layer, sub = pcall(nt.GetDrawLayer, nt)
    layer, sub = okL and Str(layer) or nil, okL and Num(sub) or nil
    -- 至少 ARTWORK：圖示在 BACKGROUND，外框要在圖示上面
    if not DRAW_LAYERS[layer] or layer == "BACKGROUND" then layer = "ARTWORK" end
    sub = math.max(-8, math.min(7, math.floor(sub or 0)))
    local l, r, t, b = TexCoordOf(nt)
    local n = { atlas = atlas, file = file, x = rr.x, y = rr.y, w = rr.w, h = rr.h, l = l, r = r, t = t, b = b,
                cr = cr, cg = cg, cb = cb, ca = ca, blend = blend, layer = layer, sub = sub }
    n.sig = table.concat({ tostring(atlas or file), F2(rr.x), F2(rr.y), F2(rr.w), F2(rr.h), F4x4(l, r, t, b),
        F4x4(cr, cg, cb, ca), blend, layer, sub }, ",")
    return n
end

-- 從**我們自己的**框與它的 Icon（normal 給了的話連皮外框）讀回 Masque 套上去的形狀（框 w×h）。
-- Icon 的矩形讀不懂 ⇒ nil（方形；這時也不讀外框，按鈕畫米利邊）
local function ReadShape(frame, icon, w, h, normal)
    if not (frame and icon and tonumber(w) and tonumber(h) and w > 0 and h > 0) then return nil end
    local known = { [frame] = { x = 0, y = 0, w = w, h = h } }
    local ir = RectOf(icon, known)
    if not ir then return nil end
    known[icon] = ir
    local l, r, t, b = TexCoordOf(icon)
    local mask
    local n = Num(Try(icon.GetNumMaskTextures, icon)) or 0
    for i = 1, n do
        local mk = Plain(Try(icon.GetMaskTexture, icon, i))
        if mk then
            local atlas, file = AssetOf(mk)
            if atlas or file then
                -- 遮罩錨在 Icon（皮的 Mask）或探針（按鈕遮罩）上；讀不懂就當跟 Icon 同一個矩形
                local mr = RectOf(mk, known) or ir
                mask = { atlas = atlas, file = file, x = mr.x, y = mr.y, w = mr.w, h = mr.h }
                break
            end
        end
    end
    local shape = { ix = ir.x, iy = ir.y, iw = ir.w, ih = ir.h, l = l, r = r, t = t, b = b, mask = mask }
    if normal then shape.normal = ReadNormal(normal, known) end
    shape.sig = table.concat({ F2(ir.x), F2(ir.y), F2(ir.w), F2(ir.h), F4x4(l, r, t, b),
        mask and (tostring(mask.atlas or mask.file) .. "@" .. F2(mask.x) .. "," .. F2(mask.y) .. "," .. F2(mask.w)
            .. "," .. F2(mask.h)) or "square",
        shape.normal and ("N:" .. shape.normal.sig) or (shape.normal == false and "N:none" or "N:?") }, ",")
    return shape
end
MS.ReadShape = ReadShape
MS.AssetOf = AssetOf
