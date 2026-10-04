------------------------------------------------------------
-- Core/Overflow.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Overflow_test.lua
--
-- 覆蓋：成立條件（沒設上限／沒選目標／目標不存在／目標是長條類／目標自己有上限／指到自己／互指成環／
-- 自己是長條類）、截斷位置、接收條的順序、兩條溢到同一條、自訂項目與占位計數、佔位判斷（occ）、
-- Receivers、Pairs、MaxOf 的清洗。
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
local function list(t) return t and table.concat((function()
    local o = {}
    for i, v in ipairs(t) do o[i] = tostring(v) end
    return o
end)(), ",") or "nil" end
local function eqList(name, got, want) eq(name, list(got), list(want)) end

local ns = {}
do
    local chunk = assert(loadfile(here .. "/../Core/Overflow.lua"))
    chunk("MiliUI_CooldownManager", ns)
end
local O = ns.Overflow

local function Icons(max, to) return { kind = "icons", layout = { maxIcons = max, overflowTo = to } } end
local function Bars(max, to) return { kind = "bars", layout = { maxIcons = max, overflowTo = to } } end

local bars, base
local function cfgOf(k) return bars[k] end
local function baseOf(k) return base[k] end
local KEYS = { "essential", "utility", "buffs", "buffbars", "g1", "g2" }

local function Reset()
    bars = {
        essential = Icons(0, false), utility = Icons(0, false), buffs = Icons(0, false),
        buffbars = Bars(0, false), g1 = Icons(0, false), g2 = Icons(0, false),
    }
    base = {
        essential = { 1, 2, 3, 4, 5 }, utility = { 21, 22 }, buffs = { 31, 32, 33 },
        buffbars = { 41 }, g1 = { "c:1" }, g2 = {},
    }
end

------------------------------------------------------------
-- 1. MaxOf／TargetKey 的清洗
------------------------------------------------------------
eq("MaxOf：沒有 layout", O.MaxOf({}), 0)
eq("MaxOf：nil", O.MaxOf(nil), 0)
eq("MaxOf：字串數字", O.MaxOf({ layout = { maxIcons = "4" } }), 4)
eq("MaxOf：小數取整", O.MaxOf({ layout = { maxIcons = 3.7 } }), 3)
eq("MaxOf：負數 ⇒ 0", O.MaxOf({ layout = { maxIcons = -2 } }), 0)
eq("MaxOf：超過上限夾到 20", O.MaxOf({ layout = { maxIcons = 99 } }), 20)
eq("MaxOf：NaN ⇒ 0", O.MaxOf({ layout = { maxIcons = 0 / 0 } }), 0)
eq("TargetKey：false", O.TargetKey(Icons(3, false)), nil)
eq("TargetKey：none", O.TargetKey(Icons(3, "none")), nil)
eq("TargetKey：空字串", O.TargetKey(Icons(3, "")), nil)
eq("TargetKey：數字不算", O.TargetKey(Icons(3, 5)), nil)
eq("TargetKey：key", O.TargetKey(Icons(3, "g1")), "g1")

------------------------------------------------------------
-- 2. 成立條件
------------------------------------------------------------
Reset()
local function why(k) return select(2, O.Target(k, cfgOf)) end
eq("舊存檔（沒有兩欄）＝ 不成立", why("utility"), "nomax")
bars.essential = { kind = "icons", layout = {} }
eq("layout 空表 ⇒ nomax", why("essential"), "nomax")
bars.essential = Icons(3, false)
eq("有上限沒目標 ⇒ notarget", why("essential"), "notarget")
bars.essential = Icons(3, "essential")
eq("指到自己", why("essential"), "self")
bars.essential = Icons(3, "gone")
eq("目標不存在", why("essential"), "missing")
bars.essential = Icons(3, "buffbars")
eq("目標是長條類", why("essential"), "notIcons")
bars.essential = Icons(3, "utility"); bars.utility = Icons(1, false)
eq("目標自己有上限（不連鎖）", why("essential"), "capped")
bars.utility = Icons(1, "essential")
eq("互指：A 不成立", why("essential"), "capped")
eq("互指：B 也不成立", why("utility"), "capped")
bars.utility = Icons(0, false)
local to, max = O.Target("essential", cfgOf)
eq("成立：目標", to, "utility")
eq("成立：上限", max, 3)
bars.buffbars = Bars(2, "g1")
eq("自己是長條類 ⇒ kind", why("buffbars"), "kind")
bars.g2 = { layout = { maxIcons = 1, overflowTo = "g1" } }   -- kind 沒寫 ＝ 圖示類
eq("kind 沒寫當圖示類", (O.Target("g2", cfgOf)), "g1")

------------------------------------------------------------
-- 3. Resolve：截斷、接收條順序
------------------------------------------------------------
Reset()
eq("沒有任何一條成立 ⇒ nil", O.Resolve(KEYS, baseOf, cfgOf), nil)
bars.essential = Icons(3, false)
eq("設了上限但沒目標 ⇒ nil（不截斷）", O.Resolve(KEYS, baseOf, cfgOf), nil)
bars.essential = Icons(3, "utility")
local res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("來源：留前三顆", res.out.essential, { 1, 2, 3 })
eqList("來源：溢出最後兩顆（照順序）", res.to.essential, { 4, 5 })
eq("toSet", res.toSet.essential[4] and res.toSet.essential[5] and not res.toSet.essential[3], true)
eqList("接收條：自己的＋溢來的接尾端", res.out.utility, { 21, 22, 4, 5 })
eq("from：來源 key", res.from.utility[4], "essential")
eq("from：自己的不記", res.from.utility[21], nil)
eqList("into", res.into.utility, { "essential" })
eq("target", res.target.essential, "utility")
eq("沒牽涉的條 ⇒ out 沒有（照 base）", res.out.buffs, nil)
eq("Resolve 不改 base", list(base.essential), "1,2,3,4,5")

bars.essential = Icons(5, "utility")
res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("剛好等於上限：不溢出", res.out.essential, { 1, 2, 3, 4, 5 })
eq("剛好等於上限：to 沒有", res.to.essential, nil)
eqList("剛好等於上限：接收條照舊", res.out.utility, { 21, 22 })
eq("剛好等於上限：沒有 from", res.from.utility, nil)
eq("剛好等於上限：target 照記", res.target.essential, "utility")

-- 兩條溢到同一條：照 barKeys 順序接
bars.essential = Icons(4, "g2")
bars.buffs = Icons(1, "g2")
res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("兩條溢到同一條：先 essential 再 buffs", res.out.g2, { 5, 32, 33 })
eqList("into 照順序", res.into.g2, { "essential", "buffs" })
eq("from 分得出來源", res.from.g2[32], "buffs")
res = O.Resolve({ "buffs", "essential", "g2" }, baseOf, cfgOf)
eqList("barKeys 換順序 ⇒ 接收順序跟著換", res.out.g2, { 32, 33, 5 })

-- 自訂項目與占位都算一顆
Reset()
base.g1 = { "c:1", 11, "c:2", "w:3" }
bars.g1 = Icons(2, "g2")
res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("自訂項目也算顆數、也會溢出", res.out.g1, { "c:1", 11 })
eqList("溢出的自訂項目", res.out.g2, { "c:2", "w:3" })

-- 佔位判斷：不佔位的不算、不搬
Reset()
base.buffs = { 31, 32, 33, 34, 35 }
bars.buffs = Icons(2, "g1")
local present = { [31] = false, [32] = true, [33] = false, [34] = true, [35] = true }
res = O.Resolve(KEYS, baseOf, cfgOf, function(k, id)
    eq("occ 收到來源條的 key", k, "buffs")
    return present[id]
end)
eqList("occ：不在的留在來源條、不算顆數", res.out.buffs, { 31, 32, 33, 34 })
eqList("occ：第三顆佔位的才溢出", res.out.g1, { "c:1", 35 })
-- 全部都佔位（固定格位）＝ 跟沒給 occ 一樣
res = O.Resolve(KEYS, baseOf, cfgOf, function() return true end)
eqList("occ 全真 ＝ 照順序截", res.out.buffs, { 31, 32 })
-- occ 回 nil 當佔位（只有明確 false 才不算）
res = O.Resolve(KEYS, baseOf, cfgOf, function() return nil end)
eqList("occ 回 nil 當佔位", res.out.buffs, { 31, 32 })

-- 接收條清單上已經有的 id 不重複放
Reset()
base.utility = { 21, 5 }
bars.essential = Icons(3, "utility")
res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("接收條已有的不重複", res.out.utility, { 21, 5, 4 })
eq("重複的不記 from", res.from.utility[5], nil)

-- baseOf 回 nil（條還沒有清單）
Reset()
base.g2 = nil
bars.essential = Icons(4, "g2")
res = O.Resolve(KEYS, baseOf, cfgOf)
eqList("接收條沒有清單 ⇒ 只有溢來的", res.out.g2, { 5 })

------------------------------------------------------------
-- 4. Receivers／Pairs
------------------------------------------------------------
Reset()
bars.essential = Icons(4, "g2")
bars.buffs = Icons(0, "g2")          -- 沒設上限：休眠的指向，不算
bars.g1 = Icons(2, "g1")             -- 指到自己：不算
local r = O.Receivers(KEYS, cfgOf)
eqList("Receivers：只算有上限的來源", r.g2, { "essential" })
eq("Receivers：指到自己不算", r.g1, nil)
bars.utility = Icons(1, "g2")
r = O.Receivers(KEYS, cfgOf)
eqList("Receivers：多條照順序", r.g2, { "essential", "utility" })
bars.g2 = Icons(3, false)
r = O.Receivers(KEYS, cfgOf)
eqList("Receivers：目標自己有上限也照列（設定頁靠它停用滑桿）", r.g2, { "essential", "utility" })
eq("Pairs：都不成立 ⇒ nil", O.Pairs(KEYS, cfgOf), nil)
bars.g2 = Icons(0, false)
local pl = O.Pairs(KEYS, cfgOf)
eq("Pairs：兩對", pl and #pl, 2)
eq("Pairs：第一對", pl and (pl[1].src .. ">" .. pl[1].dst), "essential>g2")

print(("Overflow_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
