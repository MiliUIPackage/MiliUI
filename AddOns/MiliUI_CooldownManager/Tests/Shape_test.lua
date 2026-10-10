------------------------------------------------------------
-- Core/Shape.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Shape_test.lua
--
-- 覆蓋：純函式（Normalize／Resolve：Masque 模式、長條、圓環停用／Sig／SwipeTexture／GlowShape）、
-- 襯底與陰影的幾何換算、設定繼承（主題 → 條、跟隨關掉讀條自己的）、Paint 的冪等與還原
-- （遮罩只掛一次、被別人拔掉會補回、換目標拿掉舊的、切回方形全部拿掉、襯底色、陰影外擴）、
-- 發光形狀的來源優先順序（Masque 讀回的皮 ＞ 內建設定；沒裝 Masque 一律方形；圓角當方形）。
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

print(("Shape_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
