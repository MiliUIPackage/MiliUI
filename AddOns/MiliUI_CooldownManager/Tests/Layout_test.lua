------------------------------------------------------------
-- Core/Layout.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Layout_test.lua
--
-- Layout 是純函式，唯一的外部依賴是 ns.P.Scale（像素對齊），這裡 stub 成 identity。
-- 另外跑一輪「對齊到 0.5 的倍數」的 P，確認對齊有套在每個座標上。
--
-- 覆蓋：單列、兩列不同尺寸、置中奇偶數、向上換列、LEFT／RIGHT、長條、空清單、maxPerRow=1、
-- 錨點對照、認不得的 grow、第一列寬；就地比較的序列（SeqPut／SeqTrim／SameIDs，Bars 的認領序列用）；
-- 增益 item 的放格判準（AuraSlot：在／「增益不在時」三態；BarEmptyMode／SpellEmptyMode）；
-- 圓環（同心幾何：1 圈、5 圈、inward、留空位照佔一圈、偏移為整數、Snap 0.5、RingTexture 選最近、參數夾範圍、文字位置）。
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

    -- 固定格位（條上有光環格）：占位的 entry 跟真的一樣各佔一列，後面的位置不因為前面不在而往上補
    lay.grow = "CENTER_DOWN"
    local mixed = { { id = "c:1", crec = {} }, { id = 401, placeholder = true }, { id = "c:2", crec = {} } }
    r = Lay.Compute(mixed, lay, "bars")
    rect("長條固定格位：光環格在第一列", r[1], 0, 0, 200, 20)
    rect("長條固定格位：占位那列照佔", r[2], 0, 22, 200, 20)
    rect("長條固定格位：後面的不往上補", r[3], 0, 44, 200, 20)
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

------------------------------------------------------------
-- 錨定的排開（AnchorSide／AnchorOf／StackTarget）
------------------------------------------------------------
do
    local ABOVE = function(to, off) return { to = to, point = "BOTTOM", relPoint = "TOP", x = 0, y = off or 1 } end
    local BELOW = function(to, off) return { to = to, point = "TOP", relPoint = "BOTTOM", x = 0, y = off or -1 } end
    local LEFTOF = function(to) return { to = to, point = "RIGHT", relPoint = "LEFT", x = 0, y = 0 } end
    local RIGHTOF = function(to) return { to = to, point = "LEFT", relPoint = "RIGHT", x = 0, y = 0 } end
    local RANK = { resources = 1, pips = 2, utility = 3, castbar = 4, buffs = 5, buffbars = 6, essential = 7 }
    local function rank(k) return RANK[k] or 100 end
    local function resolver(cfg)
        local keys = {}
        for k in pairs(cfg) do keys[#keys + 1] = k end
        table.sort(keys)
        local function cfgOf(k) return cfg[k] end
        return function(k) return Lay.StackTarget(k, cfgOf, keys, rank) end, cfgOf, keys
    end

    eq("邊：上方", Lay.AnchorSide(ABOVE("x")), "above")
    eq("邊：下方", Lay.AnchorSide(BELOW("x")), "below")
    eq("邊：左", Lay.AnchorSide(LEFTOF("x")), "left")
    eq("邊：右", Lay.AnchorSide(RIGHTOF("x")), "right")
    eq("邊：TOPLEFT→BOTTOMLEFT 也算下方", Lay.AnchorSide({ point = "TOPLEFT", relPoint = "BOTTOMLEFT" }), "below")
    eq("邊：置中對置中不算", Lay.AnchorSide({ point = "CENTER", relPoint = "CENTER" }), nil)
    eq("邊：不是表", Lay.AnchorSide(false), nil)

    -- 預設：資源條、施法條在核心上方；自訂格子、輔助在核心下方
    local cfg = {
        essential = { anchor = false },
        resources = { enabled = true, anchor = ABOVE("essential") },
        castbar   = { enabled = true, anchor = ABOVE("essential") },
        pips      = { enabled = true, anchor = BELOW("essential") },
        utility   = { anchor = BELOW("essential") },
        buffs     = { anchor = false },
    }
    local T = resolver(cfg)
    eq("預設：核心沒有錨定", T("essential"), nil)
    eq("預設：資源條貼核心", T("resources"), "essential")
    eq("預設：施法條貼在資源條外面", T("castbar"), "resources")
    eq("預設：自訂格子貼核心", T("pips"), "essential")
    eq("預設：輔助貼在自訂格子外面", T("utility"), "pips")

    -- 自訂格子改到上方：跟資源條排開，輔助留在核心下方
    cfg.pips.anchor = ABOVE("essential")
    eq("格子改上方：資源條仍貼核心", T("resources"), "essential")
    eq("格子改上方：格子貼在資源條外面", T("pips"), "resources")
    eq("格子改上方：施法條貼在格子外面", T("castbar"), "pips")
    eq("格子改上方：輔助直接貼核心", T("utility"), "essential")

    -- 舊存檔的鏈（施法條跟資源條、輔助跟自訂格子），格子改到上方
    cfg.castbar.anchor = ABOVE("resources")
    cfg.utility.anchor = BELOW("pips")
    eq("舊鏈：施法條貼資源條", T("castbar"), "resources")
    eq("舊鏈：格子排在資源條那一串的最外面", T("pips"), "castbar")
    eq("舊鏈：輔助在格子「下方」＝改排到核心下方", T("utility"), "essential")
    -- 格子回到下方：輔助照字面貼在格子下面
    cfg.pips.anchor = BELOW("essential")
    eq("舊鏈：格子回下方，輔助貼格子", T("utility"), "pips")
    eq("舊鏈：格子回下方，格子貼核心", T("pips"), "essential")

    -- 關掉的面板不佔位
    cfg.resources.enabled = false
    eq("資源條關掉：跟著它的施法條接到核心", T("castbar"), "essential")
    eq("資源條關掉：自己照字面貼", T("resources"), "essential")
    cfg.castbar.anchor = ABOVE("essential")
    eq("資源條關掉：施法條（跟核心）直接貼核心", T("castbar"), "essential")
    cfg.resources.enabled = true
    eq("資源條開回來：施法條又排到外面", T("castbar"), "resources")
    cfg.pips.enabled = false
    eq("格子關掉：輔助（跟格子）接到核心", T("utility"), "essential")
    cfg.pips.enabled = true

    -- 收合的面板（沒有內容、高度 0）不佔位：別人不能貼在它身上
    do
        local collapsed = {}
        local keys = {}
        for k in pairs(cfg) do keys[#keys + 1] = k end
        table.sort(keys)
        local function cfgOf(k) return cfg[k] end
        local function skip(k) return collapsed[k] == true end
        local function TS(k) return Lay.StackTarget(k, cfgOf, keys, rank, skip) end
        -- 新預設（輔助跟核心）
        cfg.utility.anchor = BELOW("essential")
        collapsed.pips = true
        eq("格子收合：輔助貼核心（不貼在高度 0 的框上）", TS("utility"), "essential")
        eq("格子收合：格子自己貼核心", TS("pips"), "essential")
        collapsed.pips = nil
        eq("格子展開：輔助貼格子", TS("utility"), "pips")
        -- 舊存檔（輔助指名跟著格子）
        cfg.utility.anchor = BELOW("pips")
        collapsed.pips = true
        eq("舊鏈＋格子收合：輔助接到核心", TS("utility"), "essential")
        collapsed.pips = nil
        eq("舊鏈＋格子展開：輔助貼格子", TS("utility"), "pips")
        -- 收合的夾在上方那一疊中間
        cfg.pips.anchor = ABOVE("essential")
        cfg.castbar.anchor = ABOVE("essential")
        collapsed.pips = true
        eq("格子在上方收合：施法條直接貼資源條", TS("castbar"), "resources")
        collapsed.pips = nil
        eq("格子在上方展開：施法條貼格子", TS("castbar"), "pips")
        cfg.pips.anchor = BELOW("essential")
        cfg.utility.anchor = BELOW("pips")
    end

    -- 不同邊互不影響；左右也排
    cfg.g1 = { anchor = RIGHTOF("essential") }
    cfg.g2 = { anchor = RIGHTOF("essential") }
    cfg.g3 = { anchor = LEFTOF("essential") }
    local T2 = resolver(cfg)
    eq("右邊第一個貼核心", T2("g1"), "essential")
    eq("右邊第二個貼第一個", T2("g2"), "g1")
    eq("左邊自己一疊", T2("g3"), "essential")
    eq("左右不影響上方", T2("resources"), "essential")
    -- 掛在某一條身上同一邊的，排在那一條與下一個兄弟之間
    cfg.g4 = { anchor = RIGHTOF("g1") }
    local T3 = resolver(cfg)
    eq("g4 貼 g1", T3("g4"), "g1")
    eq("g2 貼在 g1 那一串的最外面", T3("g2"), "g4")
    -- 不是四個邊的錨定照字面
    cfg.g5 = { anchor = { to = "essential", point = "CENTER", relPoint = "CENTER" } }
    eq("置中錨定照字面", resolver(cfg)("g5"), "essential")
    -- 目標不存在／成環
    cfg.g6 = { anchor = ABOVE("nope") }
    eq("目標不存在＝沒有錨定", resolver(cfg)("g6"), nil)
    cfg.g7 = { anchor = ABOVE("g8") }
    cfg.g8 = { anchor = ABOVE("g7") }
    local T4 = resolver(cfg)
    eq("成環＝沒有錨定 (1)", T4("g7"), nil)
    eq("成環＝沒有錨定 (2)", T4("g8"), nil)
    eq("成環不影響別人", T4("resources"), "essential")

    -- 隨機樹：算出來的「誰貼誰」不成環，而且開著的元件沒有兩個貼在同一條的同一邊
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end
    local SIDES = { ABOVE, BELOW, LEFTOF, RIGHTOF }
    local acyclic, unique, literal = true, true, true
    local onFolded = false
    for _ = 1, 400 do
        local n = 2 + rnd(7)
        local c = {}
        local names = {}
        for i = 1, n do names[i] = "n" .. i end
        c[names[1]] = { anchor = false }
        for i = 2, n do
            local to = names[rnd(i - 1)]
            local pick = rnd(6)
            local a
            if pick <= 4 then a = SIDES[pick](to)
            elseif pick == 5 then a = { to = to, point = "CENTER", relPoint = "CENTER" }
            else a = false end
            c[names[i]] = { anchor = a, enabled = (rnd(5) ~= 1) and true or false }
        end
        local ranks = {}
        for i = 1, n do ranks[names[i]] = rnd(4) end
        local folded = {}
        for i = 2, n do folded[names[i]] = (rnd(6) == 1) end
        local function cfgOf(k) return c[k] end
        local function rk(k) return ranks[k] end
        local function skip(k) return folded[k] == true end
        local target = {}
        local used = {}
        for i = 1, n do
            local k = names[i]
            local t = Lay.StackTarget(k, cfgOf, names, rk, skip)
            -- 開著的東西不會貼在「同一條軸上」收合的框上（那種一定接得到上一層）。
            -- 收合的框自己沒有錨定、或掛在另一條軸上時沒有上一層可接，照字面貼（框本身留 1 的高度，矩形有效）
            if t and c[k].enabled ~= false and not folded[k] and folded[t] and c[k].anchor then
                local mine = Lay.AnchorSide(c[k].anchor)
                local ta = Lay.AnchorOf(t, cfgOf)
                local theirs = ta and Lay.AnchorSide(ta)
                local sameAxis = mine and theirs and ((mine == "above" or mine == "below") == (theirs == "above" or theirs == "below"))
                if sameAxis then onFolded = true end
            end
            target[k] = t
            local a = c[k].anchor
            if not a then
                if t ~= nil then literal = false end
            elseif t == nil then
                literal = false
            elseif c[k].enabled ~= false and not folded[k] then
                local side = Lay.AnchorSide(a)
                if side then
                    local id = t .. "/" .. side
                    if used[id] then unique = false end
                    used[id] = true
                end
            end
        end
        for i = 1, n do
            local cur, hops = names[i], 0
            while cur and hops <= n do cur = target[cur]; hops = hops + 1 end
            if cur then acyclic = false end
        end
    end
    check("隨機樹：貼附關係不成環", acyclic)
    check("隨機樹：同一條的同一邊只貼一個", unique)
    check("隨機樹：有錨定才有目標", literal)
    check("隨機樹：同一條軸上沒有東西貼在收合的框上", not onFolded)
end

------------------------------------------------------------
-- 直向：往下／往上長，滿了往右／往左換列
------------------------------------------------------------
do
    local lay = { maxPerRow = 3, spacing = 1, grow = "DOWN_RIGHT", size = { w = 30, h = 20 }, row2Size = false }
    local r, w, h, a = Lay.Compute(N(5), lay, "icons")
    eq("DOWN_RIGHT：錨點 TOPLEFT", a, "TOPLEFT")
    eq("DOWN_RIGHT：寬 ＝ 兩列", w, 61)
    eq("DOWN_RIGHT：高 ＝ 最長那列", h, 62)
    rect("DOWN_RIGHT #1", r[1], 0, 0, 30, 20)
    rect("DOWN_RIGHT #3", r[3], 0, 42, 30, 20)
    rect("DOWN_RIGHT #4（第二列貼頂）", r[4], 31, 0, 30, 20)

    lay.grow = "UP_LEFT"
    r, w, h, a = Lay.Compute(N(5), lay, "icons")
    eq("UP_LEFT：錨點 BOTTOMRIGHT", a, "BOTTOMRIGHT")
    rect("UP_LEFT #1（右下角）", r[1], 31, 42, 30, 20)
    rect("UP_LEFT #2 往上", r[2], 31, 21, 30, 20)
    rect("UP_LEFT #4（第二列在左、貼底）", r[4], 0, 42, 30, 20)

    lay.grow = "DOWN_LEFT"
    local _, _, _, a2 = Lay.Compute(N(2), lay, "icons")
    eq("DOWN_LEFT：錨點 TOPRIGHT", a2, "TOPRIGHT")
    lay.grow = "UP_RIGHT"
    local _, _, _, a3 = Lay.Compute(N(2), lay, "icons")
    eq("UP_RIGHT：錨點 BOTTOMLEFT", a3, "BOTTOMLEFT")

    lay.grow, lay.row2Size = "DOWN_RIGHT", { w = 20, h = 10 }
    r, w, h = Lay.Compute(N(4), lay, "icons")
    rect("第二列起用 row2Size", r[4], 31, 0, 20, 10)
    eq("row2Size：寬", w, 51)

    eq("直向的 FirstRowWidth ＝ 全部列的寬", Lay.FirstRowWidth(5, { maxPerRow = 3, spacing = 1, grow = "DOWN_RIGHT", size = { w = 30, h = 20 } }), 61)
    eq("ParseColumn：橫向值 → nil", Lay.ParseColumn("RIGHT_UP"), nil)
    eq("ParseColumn：直向值", select(2, Lay.ParseColumn("UP_LEFT")), "LEFT")
    local _, _, _, ab = Lay.Compute(N(2), { grow = "DOWN_RIGHT" }, "bars")
    eq("長條不吃直向：退回 TOP", ab, "TOP")
    eq("ParseGrow 對直向值退回預設", (Lay.ParseGrow("DOWN_RIGHT")), "CENTER")
end

------------------------------------------------------------
-- 就地比較的序列（Bars 的認領序列 → 要不要重建法術索引，效能 #6）
------------------------------------------------------------
do
    local itemA, itemB = {}, {}
    local seq = {}
    -- 第一輪：從空的開始 ⇒ 變了
    local ch = false
    ch = Lay.SeqPut(seq, 1, 101, ch); ch = Lay.SeqPut(seq, 2, itemA, ch); ch = Lay.SeqPut(seq, 3, false, ch)
    ch = Lay.SeqTrim(seq, 3, ch)
    eq("序列：第一輪是變了", ch, true)
    check("序列：寫進去了", Lay.SameIDs(seq, { 101, itemA, false }))
    local before = seq
    -- 第二輪一模一樣 ⇒ 沒變，而且是同一張表（不配置）
    ch = false
    ch = Lay.SeqPut(seq, 1, 101, ch); ch = Lay.SeqPut(seq, 2, itemA, ch); ch = Lay.SeqPut(seq, 3, false, ch)
    ch = Lay.SeqTrim(seq, 3, ch)
    eq("序列：一樣 ⇒ 沒變", ch, false)
    check("序列：就地改寫（同一張表）", seq == before)
    -- 同一個 id 換了一顆框（暴雪池子重取） ⇒ 變了
    ch = false
    ch = Lay.SeqPut(seq, 1, 101, ch); ch = Lay.SeqPut(seq, 2, itemB, ch); ch = Lay.SeqPut(seq, 3, false, ch)
    eq("序列：同 id 換框 ⇒ 變了", Lay.SeqTrim(seq, 3, ch), true)
    -- 停放旗標變了 ⇒ 變了
    ch = Lay.SeqPut(seq, 3, true, false)
    eq("序列：停放旗標 ⇒ 變了", ch, true)
    -- nil 存成 false（不留洞）
    eq("序列：nil 跟 false 視為相同", Lay.SeqPut(seq, 4, nil, false), true)
    eq("序列：nil 存成 false", seq[4], false)
    eq("序列：再放一次 nil ⇒ 沒變", Lay.SeqPut(seq, 4, nil, false), false)
    -- 變短 ⇒ 尾巴清掉、算變了
    eq("序列：變短 ⇒ 變了", Lay.SeqTrim(seq, 3, false), true)
    eq("序列：尾巴清掉", #seq, 3)
    eq("序列：長度沒變的 Trim ⇒ 沒變", Lay.SeqTrim(seq, 3, false), false)
    eq("序列：全部清空", Lay.SeqTrim(seq, 0, false), true)
    eq("序列：清空後長度 0", #seq, 0)
    -- SameIDs
    check("SameIDs：相同", Lay.SameIDs({ 1, 2 }, { 1, 2 }))
    check("SameIDs：長度不同", not Lay.SameIDs({ 1, 2 }, { 1 }))
    check("SameIDs：順序不同", not Lay.SameIDs({ 1, 2 }, { 2, 1 }))
    check("SameIDs：nil 當空", Lay.SameIDs(nil, {}))
end

-- 增益 item 這一格怎麼排（Bars.Relayout／Occupancy 共用，F7）
do
    local Lay = ns.Layout
    eq("AuraSlot：在 ⇒ item", Lay.AuraSlot(true, "dim"), "item")
    eq("AuraSlot：在、收合也一樣", Lay.AuraSlot(true, "collapse"), "item")
    eq("AuraSlot：不在、收合 ⇒ nil", Lay.AuraSlot(false, "collapse"), nil)
    eq("AuraSlot：不在、沒有 mode ⇒ nil", Lay.AuraSlot(false, nil), nil)
    eq("AuraSlot：不在、留空位 ⇒ blank", Lay.AuraSlot(false, "blank"), "blank")
    eq("AuraSlot：不在、暗圖示 ⇒ 占位", Lay.AuraSlot(false, "dim"), "placeholder")
    eq("AuraSlot：壞值 ⇒ nil", Lay.AuraSlot(false, "yes"), nil)
    eq("BarEmptyMode：forced 圖示類退暗圖示", Lay.BarEmptyMode("collapse", true, false), "dim")
    local m, own = Lay.SpellEmptyMode("blank", "dim", true)
    check("SpellEmptyMode：自己設的留空位", m == "blank" and own == true)
end

-- 「增益不在時」的判準（Core/Layout.lua 的純函式）
do
    local Lay = ns.Layout
    eq("條層：存 collapse ⇒ collapse", Lay.BarEmptyMode("collapse", false, false), "collapse")
    eq("條層：沒存 ⇒ collapse", Lay.BarEmptyMode(nil, false, false), "collapse")
    eq("條層：壞值 ⇒ collapse", Lay.BarEmptyMode("x", false, false), "collapse")
    eq("條層：blank", Lay.BarEmptyMode("blank", true, false), "blank")
    eq("條層：forced＋collapse 圖示類 ⇒ dim", Lay.BarEmptyMode("collapse", true, false), "dim")
    eq("條層：forced＋collapse 長條 ⇒ blank", Lay.BarEmptyMode("collapse", true, true), "blank")
    eq("條層：forced＋collapse 長條＋舊空長條 ⇒ dim", Lay.BarEmptyMode("collapse", true, true, "bar"), "dim")
    local m, own = Lay.SpellEmptyMode(nil, "blank", false)
    check("逐法術：沒覆寫 ⇒ 跟隨條", m == "blank" and own == false)
    m, own = Lay.SpellEmptyMode("dim", "collapse", false)
    check("逐法術：自己設 dim", m == "dim" and own == true)
    m, own = Lay.SpellEmptyMode("collapse", "dim", true)
    check("逐法術：forced 時 collapse ⇒ 跟隨條", m == "dim" and own == false)
    m, own = Lay.SpellEmptyMode("collapse", "blank", false)
    check("逐法術：沒 forced 時 collapse 照用", m == "collapse" and own == true)
    eq("AuraSlot：在 ⇒ item", Lay.AuraSlot(true, "collapse"), "item")
    eq("AuraSlot：collapse ⇒ nil", Lay.AuraSlot(false, "collapse"), nil)
    eq("AuraSlot：blank", Lay.AuraSlot(false, "blank"), "blank")
    eq("AuraSlot：dim ⇒ placeholder", Lay.AuraSlot(false, "dim"), "placeholder")
end

------------------------------------------------------------
-- 直向長條（F8c）：條並排（等於直向圖示 maxPerRow 1）；grow 兩套值互通；格子尺寸轉 90 度
------------------------------------------------------------
do
    local lay = { spacing = 2, grow = "CENTER_DOWN", size = { w = 20, h = 200 }, vertical = true }
    local r, w, h, a = Lay.Compute(N(4), lay, "bars")
    eq("直向長條：橫向 grow 換成貼頂往右 ⇒ 錨 TOPLEFT", a, "TOPLEFT")
    eq("直向長條：寬＝四條並排", w, 4 * 20 + 3 * 2)
    eq("直向長條：高＝條長", h, 200)
    rect("直向長條 #1", r[1], 0, 0, 20, 200)
    rect("直向長條 #4", r[4], 66, 0, 20, 200)
    lay.grow = "UP_LEFT"
    r, w, h, a = Lay.Compute(N(2), lay, "bars")
    eq("直向長條 UP_LEFT：錨 BOTTOMRIGHT", a, "BOTTOMRIGHT")
    rect("直向長條 UP_LEFT #1 在最右", r[1], 22, 0, 20, 200)
    lay.grow = "CENTER_UP"
    local _, _, _, a2 = Lay.Compute(N(2), lay, "bars")
    eq("直向長條：CENTER_UP ⇒ 貼底往右", a2, "BOTTOMLEFT")
    -- 不同長度的條一起並排：貼底時 y 對齊底
    eq("VerticalBarGrow：直向值照收", select(2, Lay.VerticalBarGrow("DOWN_LEFT")), "LEFT")
    eq("VerticalBarGrow：橫向值 ⇒ 縱向＋RIGHT", Lay.VerticalBarGrow("CENTER_UP"), "UP")
    eq("VerticalBarGrow：亂寫 ⇒ DOWN", Lay.VerticalBarGrow(nil), "DOWN")
    -- 切回橫向時留下直向的 grow：伸展那半當縱向
    local _, _, _, a3 = Lay.Compute(N(2), { spacing = 2, grow = "UP_RIGHT", size = { w = 200, h = 20 } }, "bars")
    eq("橫向長條吃到直向 grow：UP ⇒ BOTTOM", a3, "BOTTOM")
    local rr = Lay.Compute(N(2), { spacing = 2, grow = "DOWN_LEFT", size = { w = 200, h = 20 } }, "bars")
    rect("橫向長條吃到直向 grow：照一列一條", rr[2], 0, 22, 200, 20)
    -- 格子尺寸
    local cw, ch = Lay.BarCellSize(200, 20, true)
    check("BarCellSize 直向：寬＝粗細、高＝長", cw == 20 and ch == 200)
    cw, ch = Lay.BarCellSize(200, 20, false)
    check("BarCellSize 橫向：照舊", cw == 200 and ch == 20)
end

-- 圖示 texcoord：縮放＋非正方形裁切
do
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    local l, r, t, b = Lay.IconTexCoord(0.1, 36, 36, true)
    check("IconTexCoord 正方形：四邊各切 z", near(l, 0.1) and near(r, 0.9) and near(t, 0.1) and near(b, 0.9))
    l, r, t, b = Lay.IconTexCoord(0, 60, 20, true)
    check("IconTexCoord 寬圖裁切：左右不動", near(l, 0) and near(r, 1))
    check("IconTexCoord 寬圖裁切：上下留 1/3 置中", near(t, 1 / 3) and near(b, 2 / 3))
    l, r, t, b = Lay.IconTexCoord(0.1, 20, 40, true)
    check("IconTexCoord 高圖裁切：縮放後再切左右", near(t, 0.1) and near(b, 0.9) and near(l, 0.3) and near(r, 0.7))
    l, r, t, b = Lay.IconTexCoord(0.1, 60, 20, false)
    check("IconTexCoord 拉伸：照舊", near(t, 0.1) and near(b, 0.9) and near(l, 0.1))
end

-- 圓環：同心幾何（layout.style ＝ "rings"）
do
    local function ring(thick, gap, dir, w)
        return { style = "rings", size = { w = w or 40, h = 30 }, maxPerRow = 2, grow = "LEFT_UP", row2Size = { w = 99, h = 99 },
            ring = { thickness = thick, gap = gap, direction = dir } }
    end
    -- 空清單：錨點 CENTER
    local r0, w0, h0, a0 = Lay.Compute({}, ring(8, 3), "icons")
    check("圓環：空清單", #r0 == 0 and w0 == 0 and h0 == 0 and a0 == "CENTER")
    -- 1 圈：基準直徑＝size.w（h、maxPerRow、row2Size、grow 不看）
    local r1, w1, h1, a1 = Lay.Compute(N(1), ring(8, 3), "icons")
    rect("圓環 1 圈", r1[1], 0, 0, 40, 40)
    check("圓環 1 圈：容器＝基準直徑、CENTER", w1 == 40 and h1 == 40 and a1 == "CENTER")
    eq("圓環 1 圈：第 1 圈", r1[1].ring, 1)
    -- 5 圈（往外）：第 1 個最內圈；D_k ＝ 40 ＋ 2(k−1)·11
    local r5, w5, h5 = Lay.Compute(N(5), ring(8, 3, "outward"), "icons")
    eq("圓環 5 圈：容器", w5, 40 + 2 * 4 * 11)
    eq("圓環 5 圈：正方形", h5, w5)
    rect("圓環 5 圈 #1（最內）", r5[1], 44, 44, 40, 40)
    rect("圓環 5 圈 #3", r5[3], 22, 22, 84, 84)
    rect("圓環 5 圈 #5（最外）", r5[5], 0, 0, 128, 128)
    local allInt, centered = true, true
    for i = 1, 5 do
        local r = r5[i]
        if r.x ~= math.floor(r.x) or r.y ~= math.floor(r.y) then allInt = false end
        if r.x + r.w / 2 ~= w5 / 2 or r.y + r.h / 2 ~= h5 / 2 then centered = false end
    end
    check("圓環：偏移都是整數", allInt)
    check("圓環：每圈同一個圓心", centered)
    eq("圓環 5 圈：ring 欄＝從內往外第幾圈", r5[4].ring, 4)
    -- 往內：第 1 個是最外圈
    local ri = Lay.Compute(N(5), ring(8, 3, "inward"), "icons")
    rect("圓環往內 #1（最外）", ri[1], 0, 0, 128, 128)
    rect("圓環往內 #5（最內）", ri[5], 44, 44, 40, 40)
    eq("圓環往內：#1 是第 5 圈", ri[1].ring, 5)
    -- 留空位的 entry 照樣佔一圈（Compute 只看格數）：第 3 個留空，第 4 個照舊在第 4 圈
    local blank = { { id = 1 }, { id = 2 }, { blank = true }, { id = 4 } }
    local rb = Lay.Compute(blank, ring(8, 3), "icons")
    eq("圓環留空位：第 4 個在第 4 圈", rb[4].ring, 4)
    eq("圓環留空位：第 4 個直徑", rb[4].w, 40 + 2 * 3 * 11)
    -- 長條類存著 style ＝ rings 不算
    local rbar = Lay.Compute(N(2), { style = "rings", spacing = 2, size = { w = 200, h = 20 } }, "bars")
    rect("長條類不吃圓環", rbar[2], 0, 22, 200, 20)
    check("IsRings：圖示類＋rings", Lay.IsRings({ style = "rings" }, "icons"))
    check("IsRings：長條類不算", not Lay.IsRings({ style = "rings" }, "bars"))
    check("IsRings：icons 不算", not Lay.IsRings({ style = "icons" }, "icons"))
    -- 參數夾範圍、取整、方向認不得退往外
    local t, g, d = Lay.RingParams({ thickness = 99, gap = -3, direction = "?" })
    check("RingParams：夾範圍、方向退 outward", t == 24 and g == 0 and d == "outward")
    t, g = Lay.RingParams({ thickness = 7.6, gap = 2.4 })
    check("RingParams：取整", t == 8 and g == 2)
    t, g, d = Lay.RingParams(nil)
    check("RingParams：沒存＝預設 8／3／往外", t == 8 and g == 3 and d == "outward")
    eq("RingIconSize：夾範圍", Lay.RingIconSize(99), 32)
    eq("RingIconSize：沒存＝14", Lay.RingIconSize(nil), 14)
    -- 第一列寬（長條寬 0 跟核心技能走）：圓環＝整組直徑
    eq("FirstRowWidth 圓環", Lay.FirstRowWidth(3, ring(8, 3)), 40 + 2 * 2 * 11)

    -- RingTexture：比例取對數距離最近的那張
    eq("RingRatio 頭", Lay.RingRatio(1), 0.02)
    check("RingRatio 尾", math.abs(Lay.RingRatio(20) - 0.30) < 1e-9)
    eq("RingTexture：比最細還細 ⇒ 1", Lay.RingTexture(1, 100), 1)
    eq("RingTexture：比最粗還粗 ⇒ 20", Lay.RingTexture(20, 40), 20)
    eq("RingTexture：剛好第 12 張", Lay.RingTexture(Lay.RingRatio(12) * 1000, 1000), 12)
    eq("RingTexture：壞值退中間", Lay.RingTexture(nil, 0), 10)
    -- 每一個比例都挑到對數距離最近的那張（窮舉對照）
    local worst = true
    for thick = 2, 24 do
        for d = 20, 300, 7 do
            local j = Lay.RingTexture(thick, d)
            local r = thick / d
            local best, bd = nil, nil
            for k = 1, 20 do
                local dist = math.abs(math.log(r) - math.log(Lay.RingRatio(k)))
                if not bd or dist < bd - 1e-12 then best, bd = k, dist end
            end
            if j ~= best then worst = false end
        end
    end
    check("RingTexture：窮舉都挑最近", worst)
    -- 同心圓每圈的貼圖：內圈比例大 ⇒ 編號不小於外圈
    local mono = true
    for i = 2, 5 do if r5[i].tex > r5[i - 1].tex then mono = false end end
    check("圓環：外圈的貼圖編號不大於內圈", mono)
    check("RingFile：路徑與兩位數編號", Lay.RingFile(3):match("Media\\ring%-03%.png$") ~= nil)
    eq("RingFile：超出範圍夾住", Lay.RingFile(99):match("ring%-(%d+)%.png$"), "20")

    -- 文字位置
    local p1 = Lay.RingTextPlace({ thick = 8 }, 10)
    check("RingTextPlace 沒圖示：倒數置中、在環帶中間", p1.cdPoint == "CENTER" and p1.cdX == 0 and p1.y == -4)
    check("RingTextPlace 沒圖示：層數在倒數右邊", p1.extraX > 0)
    local p2 = Lay.RingTextPlace({ thick = 8, showIcon = true, iconSize = 14 }, 10)
    check("RingTextPlace 有圖示：倒數接在圖示右緣外", p2.cdPoint == "LEFT" and p2.cdX == 9)
    check("RingTextPlace 有圖示：層數再往右", p2.extraX > p2.cdX)
end

-- 圓環的像素對齊：P 對齊到 0.5 的倍數，base 與 step 各自對齊後累加
do
    local ns2 = { P = { Scale = function(v) return math.floor(v * 2 + 0.5) / 2 end } }
    local c2, e2
    if setfenv then
        c2, e2 = loadfile(PATH)
        if c2 then setfenv(c2, env) end
    else
        c2, e2 = loadfile(PATH, "t", env)
    end
    assert(c2, e2)
    c2("MiliUI_CooldownManager", ns2)
    local r = ns2.Layout.Compute(N(3), { style = "rings", size = { w = 40.3 }, ring = { thickness = 8, gap = 3 } }, "icons")
    local ok = true
    for i = 1, 3 do
        for _, k in ipairs({ "x", "y", "w", "h" }) do
            local v = r[i][k]
            if v * 2 ~= math.floor(v * 2) then ok = false end
        end
    end
    check("圓環 Snap 0.5：每個值都在 0.5 格上", ok)
    eq("圓環 Snap 0.5：基準直徑對齊", r[1].w, 40.5)
end

print(("Layout_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
