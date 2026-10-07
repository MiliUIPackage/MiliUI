------------------------------------------------------------
-- Modules/CastStacks.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/CastStacks_test.lua
--
-- 覆蓋：基礎 7 秒／Ursoc's Endurance 9 秒、Guardian of Elune（搗擊後 15 秒內 +3、用掉、狂暴恢復清掉、
-- 沒學不加）、到期剔除、排序（最晚到期在前）、NextExpiry、Reset、非鐵鬃與秘密值不收。
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

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ns = { IsSecret = function(v) return v == SECRET end }
_G.GetTime = _G.GetTime or function() return 0 end
do
    local chunk = assert(loadfile(here .. "/../Modules/CastStacks.lua"))
    chunk("MiliUI_CooldownManager", ns)
end
local CS = ns.CastStacks
local known = {}
CS.known = function(id) return known[id] == true end
local IRONFUR, MANGLE, FR = 192081, 33917, 22842

-- 基礎 7 秒
CS.Reset()
check("鐵鬃 ⇒ 清單變了", CS.OnSpellcast(IRONFUR, 100))
local s = CS.Sorted(100)
eq("一層", #s, 1)
eq("基礎 7 秒", s[1] and s[1].dur, 7)
check("別的法術 ⇒ 不變", not CS.OnSpellcast(12345, 100))
check("秘密 spellID ⇒ 不收", not CS.OnSpellcast(SECRET, 100))
eq("仍是一層", #CS.Sorted(100), 1)

-- Ursoc's Endurance 9 秒
known[393611] = true
CS.OnSpellcast(IRONFUR, 102)
s = CS.Sorted(102)
eq("兩層", #s, 2)
eq("排序：最晚到期在前（9 秒那層）", s[1].dur, 9)
eq("排序：第 2 格是先到期的", s[2].expire, 107)
eq("最近到期", CS.NextExpiry(102), 107)

-- 到期剔除
s = CS.Sorted(107.5)
eq("第一層到期後剩一層", #s, 1)
eq("剩下的是 9 秒那層", s[1].expire, 111)
eq("全部到期 ⇒ 沒有下一次", CS.NextExpiry(200), nil)

-- Guardian of Elune
CS.Reset()
known[393611] = nil
CS.OnSpellcast(MANGLE, 0)
CS.OnSpellcast(IRONFUR, 1)
eq("沒學 Guardian of Elune ⇒ 不加", CS.Sorted(1)[1].dur, 7)
known[155578] = true
CS.Reset()
CS.OnSpellcast(MANGLE, 0)
CS.OnSpellcast(IRONFUR, 5)
eq("搗擊後 15 秒內 ⇒ +3", CS.Sorted(5)[1].dur, 10)
CS.OnSpellcast(IRONFUR, 6)
local found10 = 0
for _, e in ipairs(CS.Sorted(6)) do if e.dur == 10 then found10 = found10 + 1 end end
eq("加成只給下一發", found10, 1)
CS.Reset()
CS.OnSpellcast(MANGLE, 0)
CS.OnSpellcast(IRONFUR, 16)
eq("超過 15 秒 ⇒ 不加", CS.Sorted(16)[1].dur, 7)
CS.Reset()
CS.OnSpellcast(MANGLE, 0)
CS.OnSpellcast(FR, 1)
CS.OnSpellcast(IRONFUR, 2)
eq("狂暴恢復用掉加成", CS.Sorted(2)[1].dur, 7)

-- Reset
CS.OnSpellcast(IRONFUR, 3)
CS.Reset()
eq("Reset 清空", #CS.Sorted(3), 0)

print(("CastStacks_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
