------------------------------------------------------------
-- EditMode/Geometry.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/EditMode_test.lua
--
-- Geometry 只碰 ns.Bars.Get／ns.Bars.AnchorPoint／ns.profile／UIParent 的 GetLeft 系列，
-- 這裡全部 stub。容器的矩形照 Core/Bars.lua ApplyStructure 的語意擺：
-- 容器的 anchorPoint 那一點＝UIParent 的 pos.point 那一點 ＋ (x, y)。
-- 放手時 ReadPos 要把同一組 (point, x, y) 讀回來。
--
-- 覆蓋：九個錨點的座標、六種版面錨點 × pos.point CENTER／BOTTOM 的來回換算
-- （含 UIParent 不從 0 開始、負座標、非整數）、手算的兩個定值、pos.point 缺漏／亂填、
-- 讀不到時回 nil、四捨五入、格線吸附。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../EditMode/Geometry.lua"

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

-- 假框：直接給矩形
local function Rect(l, r, t, b)
    return {
        GetLeft = function() return l end, GetRight = function() return r end,
        GetTop = function() return t end, GetBottom = function() return b end,
    }
end

local env = setmetatable({}, { __index = _G })
env.UIParent = Rect(0, 1920, 1080, 0)

local containers, anchors = {}, {}
local ns = {
    profile = { bars = {} },
    Bars = {
        Get = function(key) return containers[key] end,
        AnchorPoint = function(key) return anchors[key] or "CENTER" end,
    },
}

local chunk, err
if setfenv then
    chunk, err = loadfile(PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
local EM = ns.EditMode

------------------------------------------------------------
-- 1. 九個錨點
------------------------------------------------------------
do
    local want = {
        TOPLEFT = { 10, 50 }, TOP = { 20, 50 }, TOPRIGHT = { 30, 50 },
        LEFT = { 10, 45 }, CENTER = { 20, 45 }, RIGHT = { 30, 45 },
        BOTTOMLEFT = { 10, 40 }, BOTTOM = { 20, 40 }, BOTTOMRIGHT = { 30, 40 },
    }
    for point, xy in pairs(want) do
        local x, y = EM.PointXY(point, 10, 30, 50, 40)
        near("PointXY " .. point .. " x", x, xy[1])
        near("PointXY " .. point .. " y", y, xy[2])
    end
    local x, y = EM.PointXY("NOPE", 10, 30, 50, 40)
    near("PointXY 認不得的錨點退回 CENTER x", x, 20)
    near("PointXY 認不得的錨點退回 CENTER y", y, 45)
end

------------------------------------------------------------
-- 2. 手算定值
------------------------------------------------------------
do
    -- 核心技能預設：上緣中點在畫面中心下方 202
    ns.profile.bars.essential = { pos = { point = "CENTER", x = 0, y = -202 } }
    containers.essential = Rect(865, 1055, 338, 297)
    anchors.essential = "TOP"
    local pos = EM.ReadPos("essential")
    eq("定值 TOP/CENTER point", pos and pos.point, "CENTER")
    eq("定值 TOP/CENTER x", pos and pos.x, 0)
    eq("定值 TOP/CENTER y", pos and pos.y, -202)

    -- 左下往上長、貼 UIParent 下緣中點
    ns.profile.bars.buffs = { pos = { point = "BOTTOM", x = 0, y = 300 } }
    containers.buffs = Rect(100, 300, 90, 50)
    anchors.buffs = "BOTTOMLEFT"
    pos = EM.ReadPos("buffs")
    eq("定值 BOTTOMLEFT/BOTTOM point", pos and pos.point, "BOTTOM")
    eq("定值 BOTTOMLEFT/BOTTOM x", pos and pos.x, -860)
    eq("定值 BOTTOMLEFT/BOTTOM y", pos and pos.y, 50)
end

------------------------------------------------------------
-- 3. 六種版面錨點 × pos.point CENTER／BOTTOM：照 ApplyStructure 擺，再讀回來
------------------------------------------------------------
local FRAC = EM.POINT_FRAC
local function Place(parentRect, ap, pp, x, y, w, h)
    local pl, pr, pt, pb = parentRect[1], parentRect[2], parentRect[3], parentRect[4]
    local px = pl + (pr - pl) * FRAC[pp][1]
    local py = pb + (pt - pb) * FRAC[pp][2]
    local ax, ay = px + x, py + y                 -- 容器錨點落在這裡
    local l = ax - w * FRAC[ap][1]
    local b = ay - h * FRAC[ap][2]
    return Rect(l, l + w, b + h, b)
end

local ANCHORS = { "TOP", "BOTTOM", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local PARENTS = {
    { name = "UIParent 0..1920",   rect = { 0, 1920, 1080, 0 } },
    { name = "UIParent 偏移",       rect = { 13.5, 1453.5, 912.25, 12.25 } },
}
local SAMPLES = { { 0, -202 }, { 37, 300 }, { -415, -12 }, { 250, 0 } }
for _, parent in ipairs(PARENTS) do
    env.UIParent = Rect(parent.rect[1], parent.rect[2], parent.rect[3], parent.rect[4])
    for _, ap in ipairs(ANCHORS) do
        for _, pp in ipairs({ "CENTER", "BOTTOM" }) do
            for _, s in ipairs(SAMPLES) do
                local tag = ("%s %s/%s (%d,%d)"):format(parent.name, ap, pp, s[1], s[2])
                ns.profile.bars.t = { pos = { point = pp, x = 999, y = 999 }, anchor = false }
                containers.t = Place(parent.rect, ap, pp, s[1], s[2], 187, 41)
                anchors.t = ap
                local pos = EM.ReadPos("t")
                eq(tag .. " point", pos and pos.point, pp)
                eq(tag .. " x", pos and pos.x, s[1])
                eq(tag .. " y", pos and pos.y, s[2])
            end
            -- 非整數的放手位置：四捨五入到整數
            ns.profile.bars.t = { pos = { point = pp } }
            containers.t = Place(parent.rect, ap, pp, 10.4, -20.6, 50, 20)
            anchors.t = ap
            local pos = EM.ReadPos("t")
            eq(parent.name .. " " .. ap .. "/" .. pp .. " 非整數 x", pos and pos.x, 10)
            eq(parent.name .. " " .. ap .. "/" .. pp .. " 非整數 y", pos and pos.y, -21)
        end
    end
end
env.UIParent = Rect(0, 1920, 1080, 0)

------------------------------------------------------------
-- 4. pos.point 缺漏／亂填、讀不到
------------------------------------------------------------
do
    ns.profile.bars.t = { pos = false }
    containers.t = Place({ 0, 1920, 1080, 0 }, "TOP", "CENTER", 5, 6, 40, 40)
    anchors.t = "TOP"
    local pos = EM.ReadPos("t")
    eq("pos 不是表 → CENTER", pos and pos.point, "CENTER")
    eq("pos 不是表 → x", pos and pos.x, 5)

    ns.profile.bars.t = { pos = { point = "MIDDLE", x = 0, y = 0 } }
    pos = EM.ReadPos("t")
    eq("pos.point 亂填 → CENTER", pos and pos.point, "CENTER")
    eq("pos.point 亂填 → y", pos and pos.y, 6)

    anchors.t = nil
    ns.profile.bars.t = { pos = { point = "CENTER" } }
    containers.t = Place({ 0, 1920, 1080, 0 }, "CENTER", "CENTER", -7, 8, 40, 40)
    pos = EM.ReadPos("t")
    eq("還沒排過版（錨點退回 CENTER）x", pos and pos.x, -7)
    eq("還沒排過版（錨點退回 CENTER）y", pos and pos.y, 8)

    eq("沒有容器 → nil", EM.ReadPos("nobody"), nil)
    containers.ghost = Rect(nil, nil, nil, nil)
    ns.profile.bars.ghost = { pos = { point = "CENTER" } }
    eq("容器還沒錨定（GetLeft 回 nil）→ nil", EM.ReadPos("ghost"), nil)
    containers.orphan = Rect(1, 2, 3, 4)
    eq("設定檔沒有這條 → nil", EM.ReadPos("orphan"), nil)

    -- 秘密值：當讀不到
    ns.IsSecret = function(v) return v == 1055 end
    containers.essential = Rect(865, 1055, 338, 297)
    eq("秘密值 → nil", EM.ReadPos("essential"), nil)
    ns.IsSecret = nil
end

------------------------------------------------------------
-- 5. 四捨五入與格線吸附
------------------------------------------------------------
do
    eq("Round 0.5", EM.Round(0.5), 1)
    eq("Round -0.4", EM.Round(-0.4), 0)
    eq("Round -1.6", EM.Round(-1.6), -2)
    eq("SnapValue 47/32", EM.SnapValue(47, 32), 32)
    eq("SnapValue 49/32", EM.SnapValue(49, 32), 64)
    eq("SnapValue -17/32", EM.SnapValue(-17, 32), -32)
    eq("SnapValue step 0 不動", EM.SnapValue(47, 0), 47)

    -- TOP 錨點在 (970, 340)，原點 (960, 540)：相對 (10, -200) → 吸到 (0, -192)
    -- 範圍：32 的格距只在 ±5.33 內才吸；離得遠就不動（拖起來不黏）
    local dx, dy = EM.SnapDelta("TOP", 943, 983, 350, 310, 960, 540, 32)   -- 錨點 (963,350)：rx 3→0、ry -190→-192
    near("SnapDelta TOP dx", dx, -3)
    near("SnapDelta TOP dy", dy, -2)
    dx, dy = EM.SnapDelta("TOP", 950, 990, 340, 300, 960, 540, 32)          -- rx 10、ry -200：都離格線 8～10，超出範圍
    check("SnapDelta 超出範圍不吸", dx == 0 and dy == 0)
    dx, dy = EM.SnapDelta("BOTTOMRIGHT", 950, 994, 340, 288, 960, 540, 32)   -- 錨點 (994,288)：rx 34→32、ry -252→-256
    near("SnapDelta BOTTOMRIGHT dx", dx, -2)
    near("SnapDelta BOTTOMRIGHT dy", dy, -4)
    dx, dy = EM.SnapDelta("TOP", 950, 990, 340, 300, 960, 540, nil)
    check("SnapDelta 沒有間距不動", dx == 0 and dy == 0)
    dx, dy = EM.SnapDelta("TOP", 950, 990, 360, 320, 960, 540, 128)          -- 格距放大不放大範圍：rx 10、ry -180→-192 差 12
    check("SnapDelta 大格距範圍不跟著放大", dx == 0 and dy == 0)

    -- 對齊其他條：左貼左 3、上貼下 -2；中心對中心；超出範圍那軸回 nil
    local ax, ay = EM.AlignDelta({ 103, 203, 50, 30 }, { { 100, 300, 28, 0 } }, 4)
    near("AlignDelta 左貼左", ax, -3)
    near("AlignDelta 上貼下", ay, -2)
    ax, ay = EM.AlignDelta({ 151, 251, 500, 480 }, { { 100, 300, 28, 0 } }, 4)   -- 中心 201 對 200
    near("AlignDelta 中心對中心", ax, -1)
    check("AlignDelta 遠的那軸 nil", ay == nil)
    ax, ay = EM.AlignDelta({ 0, 10, 10, 0 }, {}, 4)
    check("AlignDelta 沒目標", ax == nil and ay == nil)

    -- 吸完再 ReadPos：錨點那一邊落在格線上 ⇒ 存下來的偏移是間距的倍數
    local w, h = 187, 41
    local l, t = 813.5, 350      -- 離 16 的格線 2.5／2，在範圍內
    dx, dy = EM.SnapDelta("TOPLEFT", l, l + w, t, t - h, 960, 540, 16)
    ns.profile.bars.t = { pos = { point = "CENTER" } }
    containers.t = Rect(l + dx, l + dx + w, t + dy, t + dy - h)
    anchors.t = "TOPLEFT"
    local pos = EM.ReadPos("t")
    eq("吸附後 x 是 16 的倍數", pos and pos.x % 16, 0)
    eq("吸附後 y 是 16 的倍數", pos and pos.y % 16, 0)
end

------------------------------------------------------------
-- 面板（資源條、施法條）：設定在 profile[key]，不在 bars 裡
------------------------------------------------------------
do
    env.UIParent = Rect(0, 1920, 1080, 0)
    containers.resources = Place({ 0, 1920, 1080, 0 }, "BOTTOM", "CENTER", 30, -181, 250, 17)
    anchors.resources = "BOTTOM"
    ns.profile.resources = { pos = { point = "CENTER", x = 0, y = 0 }, anchor = false }
    eq("面板：沒有 PANEL_KEYS 時讀不到", EM.ReadPos("resources"), nil)
    ns.PANEL_KEYS = { resources = true, castbar = true }
    local pos = EM.ReadPos("resources")
    eq("面板 BOTTOM/CENTER x", pos and pos.x, 30)
    eq("面板 BOTTOM/CENTER y", pos and pos.y, -181)
    containers.castbar = Place({ 0, 1920, 1080, 0 }, "CENTER", "CENTER", -12, -260, 250, 20)
    anchors.castbar = "CENTER"
    ns.profile.castbar = { pos = { point = "CENTER" } }
    pos = EM.ReadPos("castbar")
    eq("施法條 CENTER x", pos and pos.x, -12)
    eq("施法條 CENTER y", pos and pos.y, -260)
    ns.profile.bars.castbar = nil
    eq("不是面板的 key 不會去讀 profile[key]", EM.ReadPos("theme"), nil)
end

print(("EditMode_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
