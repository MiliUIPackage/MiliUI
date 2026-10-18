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
--   * 長條、圓環、資源條不套（Resolve 回 nil）。長條類另有一套「邊緣陰影」，在檔案後半（SH.EdgeShadow），
--     由各模組在畫邊框的地方直接叫，跟上面的形狀／圖示陰影互不相干。
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

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
            NoSnap(u)
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
            NoSnap(s)
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

------------------------------------------------------------
-- 長條的邊緣陰影（資源條、施法條、自訂計時條、自訂格子、增益長條、觸發牌堆列、天空騎術列；2026-10-19）
--
--   ns.Shape.ShadowOf(on, size, alpha)        → px, alpha | nil   設定的三鍵解成生效值（純函式；關／壞資料 ⇒ nil）
--   ns.Shape.EdgeShadowGeometry(px)           → outset, edgeSize | nil   版面單位（兩個都 ＝ P.Pixel(px)）；px ≤ 0 ⇒ nil
--   ns.Shape.NewEdgeShadow(parent)            → sh   一圈陰影（parent 的子框＋八張貼圖），給要自己池化的呼叫端（AuraBar 的裝飾）
--   ns.Shape.PaintEdgeShadow(sh, region, px, alpha, ext, under)   畫／藏（px、alpha 任一 nil／≤ 0 ＝ 藏）；回傳有沒有在畫。
--                                             ext ＝ { l, r, t, b } 額外延伸（版面單位，可省）；under ＝ 層級照哪個框減一（省略 ＝ 父框）
--   ns.Shape.EdgeShadow(host, region, px, alpha, ext)      一個 region 一圈（弱鍵表 shadowOf[region]），陰影框是 host 的子框
--   ns.Shape.HideEdgeShadow(region)
--
-- 為什麼不用上面那張圖示陰影：那是一張 128×128 的模糊圖整張拉伸、四邊外擴「邊長 × SHADOW_PAD」，
-- 長條 300×20 拉上去橫邊只剩 5px、兩端卻 75px。這裡走 backdrop 的「八格邊緣」：角落固定 edgeSize 見方、直邊夾在兩角之間
-- 沿長度拉長，任何長寬比都對，粗細是實體像素（ElvUI CreateShadow／NDui CreateSD 同一種畫法）。
--
-- 貼圖 Media/shadow-edge.png（.claude/skills/miliui-cdm-shape-masks 的腳本畫的）：128×16、八格，順序與朝向照暴雪
-- SharedXML/Backdrop.lua 的 textureUVs（下面的 EDGE_UV 就是那張表；上下兩格是旋轉過的）。
-- 不套 BackdropTemplate、自己建八張貼圖：引擎列「只在生效時顯示」的裝飾建在 AuraButton 的 initializeFrame 裡
-- （Modules/AuraBar.lua），那裡不能掛 script，BackdropTemplate 自帶 OnSizeChanged。直邊沿長度是同一個值，
-- 拉伸＝重複，texcoord 把 Backdrop 的 repeatX／repeatY 換成格子的另一端就好，尺寸變了不必重算。
--
-- 幾何：陰影框＝region 每邊外擴 outset（＋ext 的額外延伸，例：自訂列把圖示也圍進去），八張貼圖都在外擴的那一圈裡，
-- region 本身不蓋任何東西（半透明的條底下不會變暗）。
-- 疊層：陰影框的 frame level ＝ host（或 under）− 1（每次畫都重設：父層的 level 可能被結構套用改過）。子框比父框低是允許的、
-- 同 strata 照 level 畫 ⇒ 多列堆疊時鄰列的條身壓在陰影上面。陰影框沿用 host 的 strata 與 alpha（條件淡出一起淡）。
-- 契約：
--   * 只建在 host 底下、狀態記在弱鍵表或呼叫端的池子裡，**不寫 host／region 的欄位**（region 可能是暴雪 item）。
--   * 值沒變不重寫（region、外擴、ext、透明度進快取；外擴是 P.Pixel(px) ⇒ UI 縮放改了自然重排）。
--   * 只做 SetPoint／SetSize／SetFrameLevel／SetVertexColor／Show／Hide：放在各模組畫邊框的同一個呼叫點，
--     自然吃到同一道戰鬥閘。
------------------------------------------------------------
SH.EDGE_SHADOW = MEDIA .. "shadow-edge.png"
SH.EDGE_MIN, SH.EDGE_MAX, SH.EDGE_DEFAULT = 1, 8, 3

-- 暴雪 Backdrop.lua 的 textureUVs（coordStart ＝ 0.0625、coordEnd ＝ 0.9375；x 每格內縮 1/128），
-- repeatX／repeatY 換成 coordEnd（拉伸）。順序 ＝ SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
local CS, CE = 0.0625, 0.9375
local unpack = unpack or table.unpack           -- 離線測試的 Lua 5.2+ 沒有全域 unpack
SH.EDGE_UV = {
    TopLeftCorner     = { 0.5078125, CS, 0.5078125, CE, 0.6171875, CS, 0.6171875, CE },
    TopRightCorner    = { 0.6328125, CS, 0.6328125, CE, 0.7421875, CS, 0.7421875, CE },
    BottomLeftCorner  = { 0.7578125, CS, 0.7578125, CE, 0.8671875, CS, 0.8671875, CE },
    BottomRightCorner = { 0.8828125, CS, 0.8828125, CE, 0.9921875, CS, 0.9921875, CE },
    TopEdge           = { 0.2578125, CE, 0.3671875, CE, 0.2578125, CS, 0.3671875, CS },
    BottomEdge        = { 0.3828125, CE, 0.4921875, CE, 0.3828125, CS, 0.4921875, CS },
    LeftEdge          = { 0.0078125, CS, 0.0078125, CE, 0.1171875, CS, 0.1171875, CE },
    RightEdge         = { 0.1328125, CS, 0.1328125, CE, 0.2421875, CS, 0.2421875, CE },
}
local CORNERS = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
local CORNER_POINT = { TopLeftCorner = "TOPLEFT", TopRightCorner = "TOPRIGHT",
                       BottomLeftCorner = "BOTTOMLEFT", BottomRightCorner = "BOTTOMRIGHT" }
-- 直邊夾在兩個角之間：{ 自己的 TOPLEFT 錨到哪個角的哪一點, 自己的 BOTTOMRIGHT 錨到哪個角的哪一點 }
local EDGES = {
    TopEdge    = { "TopLeftCorner", "TOPRIGHT", "TopRightCorner", "BOTTOMLEFT" },
    BottomEdge = { "BottomLeftCorner", "TOPRIGHT", "BottomRightCorner", "BOTTOMLEFT" },
    LeftEdge   = { "TopLeftCorner", "BOTTOMLEFT", "BottomLeftCorner", "TOPRIGHT" },
    RightEdge  = { "TopRightCorner", "BOTTOMLEFT", "BottomRightCorner", "TOPRIGHT" },
}
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                 "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
SH.EDGE_PIECES = PIECES

-- 設定三鍵 → 生效值。on 不是 true ⇒ nil；粗細取整、夾 1～8（壞資料 ＝ 3）；透明度夾 0.1～1（壞資料 ＝ 0.6、≤ 0 ＝ 不畫）
function SH.ShadowOf(on, size, alpha)
    if on ~= true then return nil end
    local px = tonumber(size)
    px = px and math.floor(px + 0.5) or SH.EDGE_DEFAULT
    if px < SH.EDGE_MIN then px = SH.EDGE_MIN elseif px > SH.EDGE_MAX then px = SH.EDGE_MAX end
    local a = tonumber(alpha)
    if a and a <= 0 then return nil end
    return px, ClampAlpha(a)
end

-- 外擴與 edgeSize（版面單位）：N 個實體像素換回版面單位（同 Media.BorderInset 的換算）。超過 8 夾回 8
function SH.EdgeShadowGeometry(px)
    px = tonumber(px)
    if not px then return nil end
    px = math.floor(px + 0.5)
    if px <= 0 then return nil end
    if px > SH.EDGE_MAX then px = SH.EDGE_MAX end
    local P = ns.P
    local v = (P and P.Pixel) and P.Pixel(px) or px
    if type(v) ~= "number" or v <= 0 then return nil end
    return v, v
end

function SH.NewEdgeShadow(parent)
    if not (parent and CreateFrame) then return nil end
    local f = CreateFrame("Frame", nil, parent)
    f:Hide()
    local sh = { frame = f, parent = parent, tex = {}, on = false }
    for _, name in ipairs(PIECES) do
        local t = f:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(SH.EDGE_SHADOW)
        t:SetTexCoord(unpack(SH.EDGE_UV[name]))
        NoSnap(t)
        sh.tex[name] = t
    end
    for _, name in ipairs(CORNERS) do
        local p = CORNER_POINT[name]
        sh.tex[name]:SetPoint(p, f, p, 0, 0)
    end
    for name, a in pairs(EDGES) do
        local t = sh.tex[name]
        t:SetPoint("TOPLEFT", sh.tex[a[1]], a[2], 0, 0)
        t:SetPoint("BOTTOMRIGHT", sh.tex[a[3]], a[4], 0, 0)
    end
    return sh
end

local function Ext(ext, k)
    local v = type(ext) == "table" and tonumber(ext[k]) or nil
    return v or 0
end

function SH.PaintEdgeShadow(sh, region, px, alpha, ext, under)
    if not sh then return false end
    local f = sh.frame
    local e
    alpha = tonumber(alpha)
    if region and alpha and alpha > 0 then e = SH.EdgeShadowGeometry(px) end
    if not e then
        if sh.on then f:Hide() end
        sh.on = false
        return false
    end
    if alpha > 1 then alpha = 1 end
    under = under or sh.parent
    local lvl = (under.GetFrameLevel and under:GetFrameLevel() or 1) - 1
    if lvl < 0 then lvl = 0 end
    if f:GetFrameLevel() ~= lvl then f:SetFrameLevel(lvl) end
    local l, r, t, b = Ext(ext, "l"), Ext(ext, "r"), Ext(ext, "t"), Ext(ext, "b")
    if sh.region ~= region or sh.e ~= e or sh.l ~= l or sh.r ~= r or sh.t ~= t or sh.b ~= b then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", region, "TOPLEFT", -(e + l), e + t)
        f:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", e + r, -(e + b))
        if sh.e ~= e then
            for _, name in ipairs(CORNERS) do sh.tex[name]:SetSize(e, e) end
        end
        sh.region, sh.e, sh.l, sh.r, sh.t, sh.b = region, e, l, r, t, b
    end
    if sh.alpha ~= alpha then
        for _, name in ipairs(PIECES) do sh.tex[name]:SetVertexColor(0, 0, 0, alpha) end
        sh.alpha = alpha
    end
    if not sh.on then f:Show() end
    sh.on = true
    return true
end

local shadowOf = setmetatable({}, { __mode = "k" })     -- region → sh（不寫 region／host 的欄位）
SH.shadowOf = shadowOf                                   -- 測試用

function SH.EdgeShadow(host, region, px, alpha, ext)
    if not region then return false end
    local sh = shadowOf[region]
    if not (px and alpha) then
        if sh then SH.PaintEdgeShadow(sh, nil) end
        return false
    end
    if not host then return false end
    if not sh then
        sh = SH.NewEdgeShadow(host)
        if not sh then return false end
        shadowOf[region] = sh
    elseif sh.parent ~= host then
        sh.frame:SetParent(host)
        sh.parent = host
    end
    return SH.PaintEdgeShadow(sh, region, px, alpha, ext)
end

function SH.HideEdgeShadow(region)
    local sh = region and shadowOf[region]
    if sh then SH.PaintEdgeShadow(sh, nil) end
end
