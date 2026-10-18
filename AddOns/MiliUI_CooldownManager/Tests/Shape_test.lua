------------------------------------------------------------
-- Core/Shape.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Shape_test.lua
--
-- 覆蓋：純函式（Normalize／Resolve：Masque 模式、長條、圓環停用／Sig／SwipeTexture／GlowShape）、
-- 襯底與陰影的幾何換算、設定繼承（主題 → 條、跟隨關掉讀條自己的）、Paint 的冪等與還原
-- （遮罩只掛一次、被別人拔掉會補回、換目標拿掉舊的、切回方形全部拿掉、襯底色、陰影外擴）、
-- 發光形狀的來源優先順序（Masque 讀回的皮 ＞ 內建設定；沒裝 Masque 一律方形；圓角當方形）。
-- 長條的邊緣陰影（SH.ShadowOf／EdgeShadowGeometry 的夾範圍、八格 texcoord 照 Backdrop.lua、貼圖尺寸、
-- EdgeShadow 的冪等（同 region 只建一個框、值沒變不重寫、UI 縮放改了重排、透明度改了只重上色）、層級 host − 1、
-- ext 延伸、under、HideEdgeShadow、不寫 host／region 的欄位）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local env = setmetatable({}, { __index = _G })
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return false end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
local masqueLib
env.LibStub = setmetatable({}, { __call = function(self, ...) return self:GetLibrary(...) end })
function env.LibStub:GetLibrary(name) if name == "Masque" then return masqueLib end end

local ns = {
    playerClass = "PALADIN",
    Events = { Register = function() end },
    Fire = function() end,
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function() return false end,
    Guard = function(fn) return fn end,
    Viewers = { AURA_KIND = { buffs = true, buffbars = true } },
    Media = { BorderInset = function(v) return v * 0.75 end },     -- Retina 那種 P.Scale(1) < 1 的情況
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end

local function Load(path)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

Load(here .. "/../Core/Shape.lua")
local SH = ns.Shape

------------------------------------------------------------
-- 1. 純函式
------------------------------------------------------------
eq("Normalize：沒存 ⇒ 方形", SH.Normalize(nil), "square")
eq("Normalize：壞值 ⇒ 方形", SH.Normalize("hexagon"), "square")
eq("Normalize：圓形", SH.Normalize("circle"), "circle")

do
    local s, a = SH.Resolve("circle", true, 0.5, false, "icons", nil)
    check("Resolve：圓形＋陰影", s == "circle" and a == 0.5)
    s, a = SH.Resolve("square", false, 0.5, false, "icons", nil)
    check("Resolve：方形無陰影 ⇒ 兩個 nil（＝現狀）", s == nil and a == nil)
    s, a = SH.Resolve("square", true, nil, false, "icons", nil)
    check("Resolve：方形也能有陰影（預設透明度）", s == nil and a == SH.DEFAULT_SHADOW_ALPHA)
    s, a = SH.Resolve("circle", true, 0.5, true, "icons", nil)
    check("Resolve：Masque 模式 ⇒ 停用（皮決定）", s == nil and a == nil)
    s, a = SH.Resolve("circle", true, 0.5, false, "bars", nil)
    check("Resolve：長條類 ⇒ 不套", s == nil and a == nil)
    s, a = SH.Resolve("circle", true, 0.5, false, "icons", { thick = 4 })
    check("Resolve：圓環條 ⇒ 不套", s == nil and a == nil)
    s, a = SH.Resolve("rounded", "yes", 0.5, false, "icons", nil)
    check("Resolve：陰影只認 true", s == "rounded" and a == nil)
    eq("Resolve：透明度夾到 0.1", select(2, SH.Resolve(nil, true, 0, false, "icons")), 0.1)
    eq("Resolve：透明度夾到 1", select(2, SH.Resolve(nil, true, 3, false, "icons")), 1)
end

eq("Sig：方形無陰影 ＝ -", SH.Sig(nil, nil), "-")
eq("Sig：圓形＋陰影", SH.Sig("circle", 0.6), "circle/0.60")
eq("Sig：方形＋陰影", SH.Sig(nil, 0.6), "square/0.60")
check("Sig：形狀不同簽章不同", SH.Sig("rounded", nil) ~= SH.Sig("circle", nil))
eq("SwipeTexture：方形 WHITE8X8", SH.SwipeTexture(nil), "Interface\\BUTTONS\\WHITE8X8")
eq("SwipeTexture：圓形＝遮罩那張", SH.SwipeTexture("circle"), SH.MASK.circle)
eq("GlowShape：圓形 ⇒ Circle", SH.GlowShape("circle"), "Circle")
eq("GlowShape：圓角當方形", SH.GlowShape("rounded"), nil)
eq("GlowShape：方形", SH.GlowShape(nil), nil)
check("貼圖路徑：五張都在 Media 底下", SH.MASK.rounded:find("Media\\shape-rounded.png", 1, true)
    and SH.SHADOW.square:find("Media\\shadow-square.png", 1, true) and SH.SHADOW.circle and SH.MASK.circle)

------------------------------------------------------------
-- 2. 幾何
------------------------------------------------------------
eq("UnderOutset：粗細 0 ⇒ 0", SH.UnderOutset(0), 0)
eq("UnderOutset：照 Media.BorderInset（像素對齊同邊框）", SH.UnderOutset(2), 1.5)
do
    local x, y = SH.ShadowOutset(40, 40, 0)
    near("ShadowOutset：方形 40 ⇒ 10", x, 10)
    near("ShadowOutset：方形 40（y）", y, 10)
    x, y = SH.ShadowOutset(40, 40, 1)
    near("ShadowOutset：含襯底 1 ⇒ 1 ＋ 42 × 0.25", x, 1 + 42 * 0.25)
    x, y = SH.ShadowOutset(60, 20, 0)
    check("ShadowOutset：非正方形各算各的", math.abs(x - 15) < 1e-9 and math.abs(y - 5) < 1e-9)
    -- 陰影圖裡圖示佔中間 1/(1+2×PAD)：外擴後的邊長 × 那個比例 ＝ 圖示
    local w = 40
    near("ShadowOutset：跟貼圖比例一致", (w + 2 * SH.ShadowOutset(w, w, 0)) / (1 + 2 * SH.SHADOW_PAD), w)
end

------------------------------------------------------------
-- 3. 設定繼承（Core/DB.lua 的 ns.Setting）
------------------------------------------------------------
Load(here .. "/../Core/DB.lua")
Load(here .. "/../Core/DB_Custom.lua")
ns.RefreshSpec()
ns.DB.Init()
local P = ns.profile
local S = ns.Setting
eq("預設：方形", S("theme", "icon.shape"), "square")
eq("預設：沒有陰影", S("theme", "icon.shadow"), false)
eq("預設：陰影透明度", S("theme", "icon.shadowAlpha"), 0.6)
P.theme.icon.shape = "circle"
eq("條跟隨主題", S("essential", "icon.shape"), "circle")
P.bars.essential.follow.icon = false
P.bars.essential.icon = P.bars.essential.icon or {}
P.bars.essential.icon.shape = "rounded"
eq("跟隨關掉讀條自己的", S("essential", "icon.shape"), "rounded")
eq("別條照舊跟主題", S("utility", "icon.shape"), "circle")
P.bars.essential.follow.icon = true
eq("跟隨打開回到主題", S("essential", "icon.shape"), "circle")
P.theme.icon.shape = "square"

------------------------------------------------------------
-- 4. Paint（假框）
------------------------------------------------------------
local function Region(kind)
    local r = { kind = kind, masks = {}, shown = true, points = {} }
    function r:AddMaskTexture(m) self.masks[#self.masks + 1] = m; self.adds = (self.adds or 0) + 1 end
    function r:RemoveMaskTexture(m)
        for i = #self.masks, 1, -1 do if self.masks[i] == m then table.remove(self.masks, i) end end
    end
    function r:GetNumMaskTextures() return #self.masks end
    function r:GetMaskTexture(i) return self.masks[i] end
    function r:SetTexture(v) self.tex = v end
    function r:SetVertexColor(...) self.color = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAllPoints(rel) self.all = rel end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    return r
end
local function Host()
    local h = { texs = {}, masks = {} }
    function h:CreateTexture(_, layer, _, sub)
        local t = Region("tex"); t.layer, t.sub = layer, sub
        self.texs[#self.texs + 1] = t
        return t
    end
    function h:CreateMaskTexture()
        local m = Region("mask")
        self.masks[#self.masks + 1] = m
        return m
    end
    return h
end

do
    local frame, icon, oor = Host(), Region("icon"), Region("oor")
    local ov = Host()
    local art = {}
    local o = { maskHost = ov, underHost = frame, region = frame, targets = { icon, oor }, shape = "circle", shadow = 0.5,
                t = 1, color = { 0.1, 0.2, 0.3, 1 }, w = 40, h = 40 }
    local drawing = SH.Paint(art, o)
    eq("Paint：襯底有畫", drawing, true)
    eq("Paint：遮罩建在 maskHost（我們的框）", #ov.masks, 1)
    eq("Paint：遮罩貼圖", ov.masks[1].tex, SH.MASK.circle)
    eq("Paint：遮罩照格子排", ov.masks[1].all, frame)
    check("Paint：圖示與暗影都掛上", icon.masks[1] == art.mask and oor.masks[1] == art.mask)
    local under = art.under
    check("Paint：襯底在圖示底下（BACKGROUND −7）", under and under.layer == "BACKGROUND" and under.sub == -7)
    check("Paint：襯底色＝邊框色", under.color and under.color[1] == 0.1 and under.color[3] == 0.3)
    check("Paint：襯底每邊大 t", under.points[1][4] == -1 and under.points[1][5] == 1 and under.points[2][4] == 1)
    check("Paint：襯底自己有一張同形狀的遮罩", under.masks[1] == art.umask and art.umask.tex == SH.MASK.circle)
    local sh = art.shadowTex
    check("Paint：陰影在襯底更底下（−8）、黑＋透明度", sh and sh.sub == -8 and sh.color[1] == 0 and sh.color[4] == 0.5)
    eq("Paint：陰影貼圖照形狀", sh.tex, SH.SHADOW.circle)
    near("Paint：陰影外擴從襯底算起", sh.points[2][4], 1 + 42 * 0.25)

    -- 冪等：再畫一次不重複掛、不重建
    SH.Paint(art, o)
    eq("Paint 冪等：圖示只掛一次", #icon.masks, 1)
    eq("Paint 冪等：遮罩不重建", #ov.masks, 1)
    eq("Paint 冪等：襯底不重建", #frame.texs, 2)

    -- 別人（Unmask：拔掉圖示上全部的遮罩）拔掉了 ⇒ 下一次補回
    icon.masks = {}
    SH.Paint(art, o)
    eq("Paint：被拔掉的遮罩補回", icon.masks[1], art.mask)

    -- 換目標（暗影不在了）⇒ 舊的拿掉
    o.targets = { icon }
    SH.Paint(art, o)
    eq("Paint：不在清單的目標拿掉遮罩", #oor.masks, 0)

    -- 粗細 0 ⇒ 不畫襯底、陰影從圖示算
    o.t = 0
    eq("Paint：粗細 0 ⇒ 沒有襯底", SH.Paint(art, o), false)
    eq("Paint：襯底藏起來", under.shown, false)
    near("Paint：陰影外擴從圖示算", sh.points[2][4], 10)
    o.t = 1

    -- 換形狀：遮罩換貼圖
    o.shape = "rounded"
    SH.Paint(art, o)
    eq("Paint：換形狀 ⇒ 遮罩換貼圖", art.mask.tex, SH.MASK.rounded)
    eq("Paint：襯底遮罩也換", art.umask.tex, SH.MASK.rounded)
    eq("Paint：陰影也換", sh.tex, SH.SHADOW.rounded)

    -- 方形＋陰影：遮罩拿掉、襯底不畫、陰影照畫（方形那張）
    o.shape = nil
    eq("Paint：方形 ⇒ 不畫襯底", SH.Paint(art, o), false)
    eq("Paint：方形 ⇒ 遮罩拿掉", #icon.masks, 0)
    check("Paint：方形 ⇒ 陰影照畫方形那張", sh.shown and sh.tex == SH.SHADOW.square)

    -- 全部關掉 ⇒ 完全回到原樣
    o.shadow = nil
    SH.Paint(art, o)
    check("Paint：全關 ⇒ 陰影、襯底、遮罩都收起來", not sh.shown and not under.shown and not art.mask.shown and #icon.masks == 0)

    -- 只拿掉自己的：別人的遮罩（暴雪的、Masque 的）不碰
    local other = Region("mask")
    icon:AddMaskTexture(other)
    o.shape = "circle"
    SH.Paint(art, o)
    SH.Clear(art)
    check("Clear：別人的遮罩留著", #icon.masks == 1 and icon.masks[1] == other)
end

------------------------------------------------------------
-- 5. 發光的形狀來源（Core/Glow.lua 的 GlowShape：Masque 讀回的皮 ＞ 內建設定）
------------------------------------------------------------
do
    ns.MiliUIGlow = {}
    Load(here .. "/../Core/Masque.lua")
    Load(here .. "/../Core/Glow.lua")
    local G, M = ns.Glow, ns.Masque
    local rec = { iconShape = "circle" }
    eq("沒裝 Masque：內建圓形也是方形發光（沒有形狀貼圖）", G.GlowShape(rec, "essential"), nil)
    masqueLib = { Group = function() return { db = {}, RegisterCallback = function() end } end }
    env.C_AddOns = { IsAddOnLoaded = function(n) return n == "Masque" end }
    check("裝了 Masque", M.Available())
    eq("內建圓形 ⇒ Circle", G.GlowShape(rec, "essential"), "Circle")
    eq("內建圓角 ⇒ 方形", G.GlowShape({ iconShape = "rounded" }, "essential"), nil)
    eq("內建方形 ⇒ 方形", G.GlowShape({}, "essential"), nil)
    eq("長條不問", G.GlowShape({ iconShape = "circle", barGeometry = {} }, "essential"), nil)
    eq("圓環不問", G.GlowShape({ iconShape = "circle", ring = true }, "essential"), nil)
    -- 交給 Masque 的格：皮讀回的形狀優先（這裡皮是六角形，內建設定是圓形也照皮）
    local saved = M.Mode
    M.Mode = function() return "masque" end
    local btn = { _MSQ_CFG = { Shape = "Hexagon" } }
    eq("Masque 讀回 ＞ 內建", G.GlowShape({ iconShape = "circle", msqSkinned = true, msqButton = btn }, "essential"), "Hexagon")
    eq("Masque 方形皮 ⇒ 方形（不退回內建）", G.GlowShape({ iconShape = "circle", msqSkinned = true,
        msqButton = { _MSQ_CFG = { Shape = "Square" } } }, "essential"), nil)
    M.Mode = saved
    eq("BuiltinShape：nil", G.BuiltinShape(nil), nil)
end


------------------------------------------------------------
-- 6. 長條的邊緣陰影（SH.EdgeShadow）
------------------------------------------------------------
do
    -- 設定三鍵 → 生效值
    eq("ShadowOf：沒開 ⇒ nil", SH.ShadowOf(false, 3, 0.6), nil)
    eq("ShadowOf：不是 true（字串）⇒ nil", SH.ShadowOf("yes", 3, 0.6), nil)
    local px, a = SH.ShadowOf(true, nil, nil)
    check("ShadowOf：開、沒存 ⇒ 3 像素 0.6", px == 3 and a == 0.6, tostring(px) .. "/" .. tostring(a))
    eq("ShadowOf：粗細取整", (SH.ShadowOf(true, 4.6, 0.5)), 5)
    eq("ShadowOf：粗細 0 夾成 1", (SH.ShadowOf(true, 0, 0.5)), 1)
    eq("ShadowOf：粗細 12 夾成 8", (SH.ShadowOf(true, 12, 0.5)), 8)
    eq("ShadowOf：粗細壞資料 ⇒ 3", (SH.ShadowOf(true, "x", 0.5)), 3)
    eq("ShadowOf：透明度 0 ⇒ 不畫", SH.ShadowOf(true, 3, 0), nil)
    eq("ShadowOf：透明度負的 ⇒ 不畫", SH.ShadowOf(true, 3, -1), nil)
    eq("ShadowOf：透明度超過 1 夾 1", select(2, SH.ShadowOf(true, 3, 2)), 1)
    eq("ShadowOf：透明度太小夾 0.1", select(2, SH.ShadowOf(true, 3, 0.02)), 0.1)
    eq("ShadowOf：透明度壞資料 ⇒ 0.6", select(2, SH.ShadowOf(true, 3, "x")), 0.6)

    -- 外擴：P.Pixel(px)；這裡 1 實體像素 ＝ 0.75 版面單位（UI 縮放 ≠ 1 的情況）
    local scale = 0.75
    ns.P = { Pixel = function(n) return n * scale end }
    eq("Geometry：nil ⇒ nil", SH.EdgeShadowGeometry(nil), nil)
    eq("Geometry：0 ⇒ nil", SH.EdgeShadowGeometry(0), nil)
    eq("Geometry：負的 ⇒ nil", SH.EdgeShadowGeometry(-2), nil)
    eq("Geometry：0.4 取整成 0 ⇒ nil", SH.EdgeShadowGeometry(0.4), nil)
    local o, e = SH.EdgeShadowGeometry(3)
    check("Geometry：3 像素 ⇒ outset ＝ edgeSize ＝ P.Pixel(3)", o == 2.25 and e == 2.25, tostring(o) .. "/" .. tostring(e))
    eq("Geometry：超過 8 夾 8", SH.EdgeShadowGeometry(20), 6)
    eq("Geometry：2.6 取整成 3", SH.EdgeShadowGeometry(2.6), 2.25)

    -- 八格 texcoord：照暴雪 Backdrop.lua 的 textureUVs（左、右、上、下、左上、右上、左下、右下）
    local CELL = { LeftEdge = 0, RightEdge = 1, TopEdge = 2, BottomEdge = 3,
                   TopLeftCorner = 4, TopRightCorner = 5, BottomLeftCorner = 6, BottomRightCorner = 7 }
    eq("八格：八張", #SH.EDGE_PIECES, 8)
    for name, cell in pairs(CELL) do
        local uv = SH.EDGE_UV[name]
        local ok = type(uv) == "table" and #uv == 8
        if ok then
            for i = 1, 8, 2 do
                if math.floor(uv[i] * 8) ~= cell then ok = false end           -- x 落在自己那一格
                if uv[i + 1] < 0.0625 or uv[i + 1] > 0.9375 then ok = false end  -- y 在內縮的範圍裡
            end
        end
        check("八格：" .. name .. " 在第 " .. cell .. " 格", ok)
    end
    local te, le = SH.EDGE_UV.TopEdge, SH.EDGE_UV.LeftEdge
    check("八格：上邊是旋轉過的（螢幕上→下＝貼圖左→右）", te[1] < te[3] and te[2] == te[4] and te[6] < te[2])
    check("八格：左邊不旋轉（螢幕左→右＝貼圖左→右）", le[1] == le[3] and le[5] > le[1] and le[4] > le[2])
    do  -- 貼圖檔：PNG 的 IHDR 寫著 128×16
        local f = io.open(here .. "/../Media/shadow-edge.png", "rb")
        local head = f and f:read(24)
        if f then f:close() end
        local function u32(sv, i) local a1, b1, c1, d1 = sv:byte(i, i + 3); return ((a1 * 256 + b1) * 256 + c1) * 256 + d1 end
        check("貼圖：Media/shadow-edge.png 是 128×16", head and #head == 24 and u32(head, 17) == 128 and u32(head, 21) == 16)
    end

    -- 假框：記下每一次寫入（冪等要看「值沒變不重寫」）
    local made = 0
    local function Fake(parent, level)
        local o2 = { parent = parent, level = level or 1, shown = true, points = {}, writes = 0, kids = {} }
        function o2:GetFrameLevel() return self.level end
        function o2:SetFrameLevel(v) self.level = v; self.writes = self.writes + 1 end
        function o2:SetParent(p2) self.parent = p2 end
        function o2:GetParent() return self.parent end
        function o2:Show() self.shown = true end
        function o2:Hide() self.shown = false end
        function o2:IsShown() return self.shown end
        function o2:ClearAllPoints() self.points = {}; self.writes = self.writes + 1 end
        function o2:SetPoint(...) self.points[#self.points + 1] = { ... }; self.writes = self.writes + 1 end
        function o2:SetSize(w, h) self.w, self.h = w, h; self.writes = self.writes + 1 end
        function o2:SetTexture(t) self.tex = t end
        function o2:SetTexCoord(...) self.uv = { ... } end
        function o2:SetVertexColor(...) self.color = { ... }; self.colorWrites = (self.colorWrites or 0) + 1 end
        function o2:CreateTexture(_, layer)
            local t = Fake(self)
            t.layer = layer
            self.kids[#self.kids + 1] = t
            return t
        end
        return o2
    end
    local savedCF = env.CreateFrame
    env.CreateFrame = function(_, _, parent)
        made = made + 1
        return Fake(parent, (parent and parent.level or 0) + 1)
    end
    local host, region = Fake(nil, 5), Fake(nil, 6)
    local function keys(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
    local hostKeys, regionKeys = keys(host), keys(region)

    check("EdgeShadow：畫了", SH.EdgeShadow(host, region, 3, 0.5) == true)
    local sh = SH.shadowOf[region]
    local f = sh and sh.frame
    eq("EdgeShadow：建了一個框", made, 1)
    check("EdgeShadow：陰影框是 host 的子框", f and f.parent == host)
    eq("EdgeShadow：層級 ＝ host − 1", f and f.level, 4)
    check("EdgeShadow：顯示", f and f.shown)
    eq("EdgeShadow：八張貼圖", f and #f.kids, 8)
    local tl = sh and sh.tex.TopLeftCorner
    check("EdgeShadow：貼圖是 shadow-edge.png、texcoord 照表", tl and tl.tex == SH.EDGE_SHADOW and tl.uv[1] == SH.EDGE_UV.TopLeftCorner[1])
    check("EdgeShadow：角落 edgeSize 見方", tl and tl.w == 2.25 and tl.h == 2.25)
    check("EdgeShadow：黑色＋透明度", tl and tl.color[1] == 0 and tl.color[4] == 0.5)
    local p1, p2 = f.points[1], f.points[2]
    check("EdgeShadow：每邊外擴 outset（圍住 region）", p1[2] == region and p1[4] == -2.25 and p1[5] == 2.25
        and p2[2] == region and p2[4] == 2.25 and p2[5] == -2.25)
    eq("EdgeShadow：不寫 host 的欄位", keys(host), hostKeys)
    eq("EdgeShadow：不寫 region 的欄位", keys(region), regionKeys)

    -- 冪等：值沒變 ⇒ 不重建、不重排、不重上色
    local w0, c0 = f.writes, tl.colorWrites
    SH.EdgeShadow(host, region, 3, 0.5)
    eq("冪等：不重建", made, 1)
    eq("冪等：值沒變不重排", f.writes, w0)
    eq("冪等：值沒變不重上色", tl.colorWrites, c0)
    -- 透明度改了：只重上色
    SH.EdgeShadow(host, region, 3, 0.8)
    check("透明度改了：重上色、不重排", tl.color[4] == 0.8 and f.writes == w0)
    -- UI 縮放改了（1 實體像素換算值變）：重排、角落改尺寸
    scale = 0.5
    SH.EdgeShadow(host, region, 3, 0.8)
    check("UI 縮放改了：重排", f.points[1][4] == -1.5 and tl.w == 1.5)
    scale = 0.75
    SH.EdgeShadow(host, region, 3, 0.8)
    -- host 的層級變了：跟著改
    host.level = 9
    SH.EdgeShadow(host, region, 3, 0.8)
    eq("host 層級變了：陰影跟著 host − 1", f.level, 8)
    -- ext：往左多圍一截（自訂列把圖示圍進去）
    SH.EdgeShadow(host, region, 3, 0.8, { l = 10 })
    check("ext：左邊多延伸", f.points[1][4] == -12.25 and f.points[2][4] == 2.25)
    -- under：層級照另一個框減一
    SH.PaintEdgeShadow(sh, region, 3, 0.8, nil, Fake(nil, 20))
    eq("under：層級照 under − 1", f.level, 19)
    host.level = 0
    SH.EdgeShadow(host, region, 3, 0.8)
    eq("層級不低於 0", f.level, 0)
    host.level = 5
    -- 關掉／Hide
    SH.EdgeShadow(host, region, nil, 0.8)
    check("px nil ⇒ 藏起來", not f.shown and sh.on == false)
    SH.EdgeShadow(host, region, 3, 0.8)
    check("再開 ⇒ 顯示、沿用同一個框", f.shown and made == 1)
    SH.HideEdgeShadow(region)
    check("HideEdgeShadow ⇒ 藏起來", not f.shown)
    SH.HideEdgeShadow(Fake())          -- 沒畫過的 region：不報錯
    SH.EdgeShadow(host, Fake(), nil, 0.5)
    eq("沒畫過、又是關的 ⇒ 不建框", made, 1)
    -- 同一個 host 圍兩個 region（施法條：條身＋圖示）⇒ 兩個框，層級都是 host − 1
    local icon = Fake(nil, 7)
    SH.EdgeShadow(host, icon, 2, 0.6)
    local f2 = SH.shadowOf[icon].frame
    check("同 host 兩個 region ⇒ 兩個框、層級都 host − 1", made == 2 and f2 ~= f and f2.level == 4)
    -- NewEdgeShadow／PaintEdgeShadow（池化用）
    local own = SH.NewEdgeShadow(host)
    check("PaintEdgeShadow：沒有 region ⇒ 不畫", SH.PaintEdgeShadow(own, nil, 3, 0.5) == false and not own.frame.shown)
    check("PaintEdgeShadow：透明度 0 ⇒ 不畫", SH.PaintEdgeShadow(own, region, 3, 0) == false)
    check("PaintEdgeShadow：畫", SH.PaintEdgeShadow(own, region, 3, 0.5) == true and own.frame.shown)
    env.CreateFrame = savedCF
    ns.P = nil
end

print(("Shape_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
