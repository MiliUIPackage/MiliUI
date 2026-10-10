------------------------------------------------------------
-- 內建圖示形狀＋陰影（米利樣式；Masque 模式由皮決定，這裡不管）
--
--   ns.Shape.Resolve(shape, shadowOn, shadowAlpha, masque, kind, ring) → shape|nil, alpha|nil   條層的生效值（純函式）
--   ns.Shape.Sig(shape, alpha)                     進簽章的字串
--   ns.Shape.SwipeTexture(shape)                   轉圈材質：方形 WHITE8X8，其餘＝形狀遮罩那張
--   ns.Shape.GlowShape(shape)                      發光要跟的形狀（Masque 的形狀名）：圓形 "Circle"，其餘 nil（圓角當方形）
--   ns.Shape.UnderOutset(borderSize)               邊框襯底比圖示每邊大多少（＝ Media.BorderInset，像素對齊同現有邊框）
--   ns.Shape.ShadowOutset(w, h, t)                 陰影每邊外擴多少（x, y）：圖示＋襯底那一圈之外再 SHADOW_PAD 倍
--   ns.Shape.Paint(art, o)                         在自己的框上畫：形狀遮罩、邊框襯底、陰影（冪等；shape／shadow 都 nil ＝ 全部拿掉）
--   ns.Shape.Clear(art)                            全部拿掉（還給暴雪、切回方形、換成長條／圓環）
--
-- 設定（主題 → 條，跟「圖示」那一節的跟隨；沒有逐法術）：
--   icon.shape        "square"（預設＝完全現狀）｜"rounded"｜"circle"
--   icon.shadow       false（預設）｜true；icon.shadowAlpha 0.1～1（預設 0.6）
-- 舊存檔沒有這三欄 ＝ 合併預設補成方形、關，行為不變、不遷移。
--
-- 畫法（形狀不是方形時）：
--   * 圖示：一張 MaskTexture（貼圖 Media/shape-*.png、SetAllPoints 圖示那一格）掛到圖示貼圖上；暴雪 item 另外掛到
--     「超出距離」的暗影（OutOfRange）與 GCD 閃光（CooldownFlash 底下的貼圖）——蓋在圖示上的方形貼圖，不掛就露方角。
--   * 轉圈：Cooldown:SetSwipeTexture(同一張遮罩)（Masque 對非方形皮也是這招）。
--   * 邊框：原本的四條細條藏起來，改畫**襯底**：一張邊框色的純色貼圖、套同一個形狀的遮罩、比圖示每邊大「邊框粗細」、
--     層級在圖示底下 ⇒ 露出來的那一圈就是邊框。粗細 0 ＝ 不畫。
-- 陰影（任何形狀都行，方形也有）：襯底更底下一張 Media/shadow-<形狀>.png，黑色、透明度照設定，四邊外擴。
--
-- 契約：
--   * 暴雪框一個欄位都不寫：只對它的貼圖呼叫 AddMaskTexture／RemoveMaskTexture、對它的 Cooldown 呼叫 SetSwipeTexture；
--     遮罩物件建在圖示貼圖所在的框上（呼叫端給 maskHost；暴雪 item 就是 item 本身——只呼叫 CreateMaskTexture、不寫欄位；跨框遮罩沒有文件依據所以不用），掛了哪些貼圖記在 art（呼叫端存在弱鍵表 rec 上）。
--   * 跟「拔掉暴雪圓角遮罩」那套（Decorate 的 Unmask／Remask，maskOf）完全分開：我們只拿掉自己掛的那一張，
--     暴雪的遮罩拔了就是拔了、裝回去照舊由 Remask 管，不會重複裝也不會漏。Unmask 把我們的也拔掉時（Masque 卸皮後重拔），
--     下一次 Paint 看到沒掛著就補回去（每次都照 GetMaskTexture 確認）。
--   * 長條、圓環、資源條不套（Resolve 回 nil）。
------------------------------------------------------------
local _, ns = ...

ns.Shape = {}
local SH = ns.Shape

local MEDIA = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\"
local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local WRAP = "CLAMPTOBLACKADDITIVE"

SH.SHAPES = { square = true, rounded = true, circle = true }
SH.MASK = { rounded = MEDIA .. "shape-rounded.png", circle = MEDIA .. "shape-circle.png" }
SH.SHADOW = { square = MEDIA .. "shadow-square.png", rounded = MEDIA .. "shadow-rounded.png", circle = MEDIA .. "shadow-circle.png" }
-- ⚠ 跟 .claude/skills/miliui-cdm-shape-masks/scripts/shapes.py 的 SHADOW_PAD 是同一個數：陰影圖中間 1/(1+2×PAD) 是圖示本身
SH.SHADOW_PAD = 0.25
SH.DEFAULT_SHADOW_ALPHA = 0.6

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
function SH.Normalize(v)
    return SH.SHAPES[v] and v or "square"
end

local function ClampAlpha(a)
    a = tonumber(a) or SH.DEFAULT_SHADOW_ALPHA
    if a < 0.1 then a = 0.1 elseif a > 1 then a = 1 end
    return a
end
SH.ClampAlpha = ClampAlpha

-- 條層的生效值：shape 只在非方形時回字串（nil ＝ 方形＝現狀），陰影開著回透明度（nil ＝ 關）。
-- Masque 模式、長條類的條、圓環條：兩個都 nil（形狀由皮決定／不適用）
function SH.Resolve(shape, shadowOn, shadowAlpha, masque, kind, ring)
    if masque or kind == "bars" or ring then return nil, nil end
    local s = SH.Normalize(shape)
    if s == "square" then s = nil end
    local a = shadowOn == true and ClampAlpha(shadowAlpha) or nil
    return s, a
end

function SH.Sig(shape, alpha)
    if not shape and not alpha then return "-" end
    return tostring(shape or "square") .. "/" .. (alpha and string.format("%.2f", alpha) or "0")
end

function SH.SwipeTexture(shape)
    return (shape and SH.MASK[shape]) or WHITE
end

function SH.GlowShape(shape)
    if shape == "circle" then return "Circle" end
    return nil
end

function SH.UnderOutset(borderSize)
    local size = tonumber(borderSize) or 0
    if size <= 0 then return 0 end
    local M = ns.Media
    if M and M.BorderInset then return M.BorderInset(size) end
    return size
end

-- 陰影外擴：圖示（w×h）＋襯底一圈（t）之後的那個矩形，每邊再外擴 PAD 倍的邊長
function SH.ShadowOutset(w, h, t)
    w, h, t = tonumber(w) or 0, tonumber(h) or 0, tonumber(t) or 0
    local W, H = w + 2 * t, h + 2 * t
    return t + W * SH.SHADOW_PAD, t + H * SH.SHADOW_PAD
end

------------------------------------------------------------
-- 畫（自己的框上）
--
-- art：呼叫端存的狀態表（rec.shapeArt／cell.shapeArt／ph.shapeArt）
-- o = {
--   maskHost  遮罩物件建在哪個框上（我們的）
--   underHost 襯底與陰影的貼圖建在哪個框上（我們的；層級要在圖示底下：同一個框就靠 BACKGROUND 的 sublevel）
--   region    圖示那一格（遮罩、襯底、陰影都照它排）
--   targets   要掛遮罩的貼圖（第一個是圖示）
--   shape     nil／"rounded"／"circle"
--   shadow    nil／透明度
--   t         襯底外擴（UnderOutset 的結果；0 ＝ 不畫襯底）
--   color     { r, g, b, a } 襯底色（＝邊框色）
--   w, h      格子尺寸（陰影外擴用；尺寸由排版給，不讀框）
-- }
-- 回傳：襯底有沒有在畫（呼叫端據此藏掉原本的四條邊框）
------------------------------------------------------------
local function Attached(tex, m)
    if not (tex and tex.GetNumMaskTextures) then return false end
    local ok, n = pcall(tex.GetNumMaskTextures, tex)
    if not ok or type(n) ~= "number" then return false end
    for i = 1, n do
        local ok2, cur = pcall(tex.GetMaskTexture, tex, i)
        if ok2 and cur == m then return true end
    end
    return false
end

local function Detach(art)
    local on = art.on
    if not (on and art.mask) then return end
    for tex in pairs(on) do
        if tex.RemoveMaskTexture and Attached(tex, art.mask) then pcall(tex.RemoveMaskTexture, tex, art.mask) end
        on[tex] = nil
    end
end

local function HideTex(t) if t then t:Hide() end end

function SH.Clear(art)
    if not art then return end
    Detach(art)
    if art.mask then art.mask:Hide() end
    HideTex(art.under)
    HideTex(art.shadowTex)
    art.shape, art.drawing = nil, false
end

function SH.Paint(art, o)
    if not (art and o) then return false end
    local shape, shadow = o.shape, o.shadow
    if not shape and not shadow then
        SH.Clear(art)
        return false
    end
    local region = o.region
    -- 遮罩：圖示與蓋在它上面的方形貼圖
    if shape then
        local m = art.mask
        if not m and o.maskHost and o.maskHost.CreateMaskTexture then
            m = o.maskHost:CreateMaskTexture()
            art.mask = m
        end
        if m then
            if art.shape ~= shape then m:SetTexture(SH.MASK[shape], WRAP, WRAP) end
            m:ClearAllPoints()
            m:SetAllPoints(region)
            m:Show()
            art.on = art.on or {}
            local want = {}
            for _, tex in ipairs(o.targets or {}) do
                if tex and tex.AddMaskTexture then
                    want[tex] = true
                    if not Attached(tex, m) then pcall(tex.AddMaskTexture, tex, m) end
                    art.on[tex] = true
                end
            end
            for tex in pairs(art.on) do
                if not want[tex] then
                    if Attached(tex, m) then pcall(tex.RemoveMaskTexture, tex, m) end
                    art.on[tex] = nil
                end
            end
        end
    else
        Detach(art)
        if art.mask then art.mask:Hide() end
    end
    local host = o.underHost
    -- 襯底（邊框）：形狀、粗細 > 0 才畫
    local t = tonumber(o.t) or 0
    local drawing = false
    if shape and t > 0 and host and host.CreateTexture then
        local u = art.under
        if not u then
            u = host:CreateTexture(nil, "BACKGROUND", nil, -7)
            u:SetTexture(WHITE)
            art.under = u
            art.umask = host:CreateMaskTexture()
            art.umask:SetAllPoints(u)
            u:AddMaskTexture(art.umask)
        end
        if art.ushape ~= shape then
            art.umask:SetTexture(SH.MASK[shape], WRAP, WRAP)
            art.ushape = shape
        end
        local c = o.color or {}
        u:SetVertexColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        u:ClearAllPoints()
        u:SetPoint("TOPLEFT", region, "TOPLEFT", -t, t)
        u:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", t, -t)
        u:Show()
        drawing = true
    else
        HideTex(art.under)
    end
    -- 陰影：任何形狀都可以；外擴照圖示＋襯底那一圈
    if shadow and host and host.CreateTexture then
        local s = art.shadowTex
        if not s then
            s = host:CreateTexture(nil, "BACKGROUND", nil, -8)
            art.shadowTex = s
        end
        s:SetTexture(SH.SHADOW[shape or "square"])
        s:SetVertexColor(0, 0, 0, shadow)
        local ox, oy = SH.ShadowOutset(o.w, o.h, drawing and t or 0)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", region, "TOPLEFT", -ox, oy)
        s:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", ox, -oy)
        s:Show()
    else
        HideTex(art.shadowTex)
    end
    art.shape, art.drawing = shape, drawing
    return drawing
end
