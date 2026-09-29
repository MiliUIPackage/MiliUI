------------------------------------------------------------
-- Core/Layout.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Layout_test.lua
--
-- Layout 是純函式，唯一的外部依賴是 ns.P.Scale（像素對齊），這裡 stub 成 identity。
-- 另外跑一輪「對齊到 0.5 的倍數」的 P，確認對齊有套在每個座標上。
--
-- 覆蓋：單列、兩列不同尺寸、置中奇偶數、向上換列、LEFT／RIGHT、長條、空清單、maxPerRow=1、
-- 錨點對照、認不得的 grow、第一列寬。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Layout.lua"

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
local function rect(name, r, x, y, w, h)
    if not r then check(name, false, "missing rect") return end
    check(name, r.x == x and r.y == y and r.w == w and r.h == h,
        ("got %s,%s %sx%s, want %s,%s %sx%s"):format(r.x, r.y, r.w, r.h, x, y, w, h))
end

-- 沒有任何 WoW 全域：環境表只繼承標準庫，Layout 若偷用 WoW API 會當場 nil 報錯
local env = setmetatable({}, { __index = _G })
local ns = { P = { Scale = function(v) return v end } }

local chunk, err
if setfenv then
    chunk, err = loadfile(PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
local Lay = ns.Layout

local function N(n) local t = {} for i = 1, n do t[i] = { key = i } end return t end

------------------------------------------------------------
-- 1. 空清單
------------------------------------------------------------
do
    local r, w, h, a = Lay.Compute({}, { maxPerRow = 8, spacing = 1, grow = "CENTER_DOWN", size = { w = 46, h = 40 } }, "icons")
    eq("空清單：沒有格子", #r, 0)
    eq("空清單：寬 0", w, 0)
    eq("空清單：高 0", h, 0)
    eq("空清單：錨點照算", a, "TOP")
    local r2, w2 = Lay.Compute(nil, nil, "icons")
    eq("nil 參數：不炸", #r2, 0)
    eq("nil 參數：寬 0", w2, 0)
end

------------------------------------------------------------
-- 2. 單列
------------------------------------------------------------
do
    local lay = { maxPerRow = 8, spacing = 1, grow = "CENTER_DOWN", size = { w = 46, h = 40 }, row2Size = false }
    local r, w, h, a = Lay.Compute(N(3), lay, "icons")
    eq("單列：寬", w, 3 * 46 + 2)
    eq("單列：高", h, 40)
    eq("單列：錨點 TOP", a, "TOP")
    rect("單列 #1", r[1], 0, 0, 46, 40)
    rect("單列 #2", r[2], 47, 0, 46, 40)
    rect("單列 #3", r[3], 94, 0, 46, 40)
end

------------------------------------------------------------
-- 3. 兩列不同尺寸 ＋ 置中（奇數：第二列比第一列窄）
------------------------------------------------------------
do
    local lay = { maxPerRow = 4, spacing = 2, grow = "CENTER_DOWN",
                  size = { w = 40, h = 40 }, row2Size = { w = 30, h = 20 } }
    local r, w, h = Lay.Compute(N(7), lay, "icons")
    -- 第一列 4 格：4*40+3*2 = 166；第二列 3 格：3*30+2*2 = 94
    eq("兩列：寬取最寬列", w, 166)
    eq("兩列：高＝40＋2＋20", h, 62)
    rect("兩列 第一列 #1", r[1], 0, 0, 40, 40)
    rect("兩列 第一列 #4", r[4], 126, 0, 40, 40)
    -- 第二列置中：(166-94)/2 = 36
    rect("兩列 第二列 #5", r[5], 36, 42, 30, 20)
    rect("兩列 第二列 #7", r[7], 36 + 64, 42, 30, 20)
end

------------------------------------------------------------
-- 4. 置中：偶數差（半格）要對齊，奇數差照算
------------------------------------------------------------
do
    local lay = { maxPerRow = 3, spacing = 0, grow = "CENTER_DOWN", size = { w = 10, h = 10 } }
    local r, w = Lay.Compute(N(4), lay, "icons")
    eq("置中：容器寬 30", w, 30)
    rect("置中：第二列單格在正中", r[4], 10, 10, 10, 10)
    local r2 = Lay.Compute(N(5), lay, "icons")
    rect("置中：第二列兩格 #4", r2[4], 5, 10, 10, 10)
    rect("置中：第二列兩格 #5", r2[5], 15, 10, 10, 10)
end

------------------------------------------------------------
-- 5. 向上換列：第一列貼底
------------------------------------------------------------
do
    local lay = { maxPerRow = 2, spacing = 1, grow = "CENTER_UP", size = { w = 40, h = 36 } }
    local r, w, h, a = Lay.Compute(N(3), lay, "icons")
    eq("向上：錨點 BOTTOM", a, "BOTTOM")
    eq("向上：高", h, 36 + 1 + 36)
    rect("向上 第一列 #1 在底", r[1], 0, 37, 40, 36)
    rect("向上 第一列 #2", r[2], 41, 37, 40, 36)
    -- 第二列單格置中在上面：(81-40)/2 = 20.5 → identity P 不對齊
    rect("向上 第二列 #3 在頂", r[3], 20.5, 0, 40, 36)
end

------------------------------------------------------------
-- 6. LEFT／RIGHT 對齊
------------------------------------------------------------
do
    local lay = { maxPerRow = 3, spacing = 1, grow = "LEFT_DOWN", size = { w = 20, h = 20 } }
    local r, w, h, a = Lay.Compute(N(4), lay, "icons")
    eq("LEFT：錨點 TOPLEFT", a, "TOPLEFT")
    rect("LEFT 第二列靠左", r[4], 0, 21, 20, 20)

    lay.grow = "RIGHT_DOWN"
    r, w, h, a = Lay.Compute(N(4), lay, "icons")
    eq("RIGHT：錨點 TOPRIGHT", a, "TOPRIGHT")
    eq("RIGHT：寬", w, 62)
    rect("RIGHT 第二列靠右", r[4], 42, 21, 20, 20)
    rect("RIGHT 第一列從左排", r[1], 0, 0, 20, 20)

    lay.grow = "LEFT_UP"
    local _, _, _, a2 = Lay.Compute(N(4), lay, "icons")
    eq("LEFT_UP：錨點 BOTTOMLEFT", a2, "BOTTOMLEFT")
    lay.grow = "RIGHT_UP"
    local _, _, _, a3 = Lay.Compute(N(4), lay, "icons")
    eq("RIGHT_UP：錨點 BOTTOMRIGHT", a3, "BOTTOMRIGHT")
end

------------------------------------------------------------
-- 7. 長條：一列一條、橫向那半不看
------------------------------------------------------------
do
    local lay = { maxPerRow = 8, spacing = 2, grow = "LEFT_DOWN", size = { w = 200, h = 20 } }
    local r, w, h, a = Lay.Compute(N(3), lay, "bars")
    eq("長條：錨點只有 TOP", a, "TOP")
    eq("長條：寬＝條寬", w, 200)
    eq("長條：高", h, 3 * 20 + 2 * 2)
    rect("長條 #1", r[1], 0, 0, 200, 20)
    rect("長條 #3", r[3], 0, 44, 200, 20)

    lay.grow = "CENTER_UP"
    r, w, h, a = Lay.Compute(N(3), lay, "bars")
    eq("長條向上：錨點 BOTTOM", a, "BOTTOM")
    rect("長條向上 #1 在底", r[1], 0, 44, 200, 20)
    rect("長條向上 #3 在頂", r[3], 0, 0, 200, 20)
end

------------------------------------------------------------
-- 8. maxPerRow = 1：每格一列、置中在最寬（＝同寬）
------------------------------------------------------------
do
    local lay = { maxPerRow = 1, spacing = 3, grow = "CENTER_DOWN", size = { w = 30, h = 30 }, row2Size = { w = 20, h = 20 } }
    local r, w, h = Lay.Compute(N(3), lay, "icons")
    eq("maxPerRow=1：寬取最寬", w, 30)
    eq("maxPerRow=1：高", h, 30 + 3 + 20 + 3 + 20)
    rect("maxPerRow=1 #1", r[1], 0, 0, 30, 30)
    rect("maxPerRow=1 #2 置中", r[2], 5, 33, 20, 20)
    rect("maxPerRow=1 #3", r[3], 5, 56, 20, 20)
    local r0 = Lay.Compute(N(2), { maxPerRow = 0, size = { w = 10, h = 10 } }, "icons")
    rect("maxPerRow=0 當 1", r0[2], 0, 10, 10, 10)
end

------------------------------------------------------------
-- 9. 認不得的 grow 退回 CENTER_DOWN；缺 size 有預設
------------------------------------------------------------
do
    local _, _, _, a = Lay.Compute(N(1), { grow = "SIDEWAYS" }, "icons")
    eq("壞 grow → TOP", a, "TOP")
    local h, v = Lay.ParseGrow("RIGHT_UP")
    eq("ParseGrow 橫", h, "RIGHT")
    eq("ParseGrow 縱", v, "UP")
    local r = Lay.Compute(N(1), {}, "icons")
    rect("缺 size → 36", r[1], 0, 0, 36, 36)
end

------------------------------------------------------------
-- 10. 第一列寬
------------------------------------------------------------
do
    local lay = { maxPerRow = 8, spacing = 1, size = { w = 46, h = 40 } }
    eq("FirstRowWidth 3 格", Lay.FirstRowWidth(3, lay), 140)
    eq("FirstRowWidth 超過一列", Lay.FirstRowWidth(12, lay), 8 * 46 + 7)
    eq("FirstRowWidth 0 格", Lay.FirstRowWidth(0, lay), 0)
end

------------------------------------------------------------
-- 11. 像素對齊有套到每個值（P 對齊到 0.5 的倍數）
------------------------------------------------------------
do
    ns.P = { Scale = function(v) return math.floor(v * 2 + 0.5) / 2 end }
    local lay = { maxPerRow = 2, spacing = 1.2, grow = "CENTER_DOWN", size = { w = 10.3, h = 10.3 } }
    local r, w, h = Lay.Compute(N(3), lay, "icons")
    local function onGrid(v) return v * 2 == math.floor(v * 2) end
    local all = onGrid(w) and onGrid(h)
    for i = 1, 3 do
        all = all and onGrid(r[i].x) and onGrid(r[i].y) and onGrid(r[i].w) and onGrid(r[i].h)
    end
    check("對齊：每個座標與尺寸都在格上", all)
    eq("對齊：格寬先對齊", r[1].w, 10.5)
    eq("對齊：間距先對齊", r[2].x, 11.5)
    ns.P = { Scale = function(v) return v end }
end

print(("Layout_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
