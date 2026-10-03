------------------------------------------------------------
-- Core/Presets.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Presets_test.lua
--
-- 做法：載進一張**沒有任何 stub** 的環境表（偷用任何 WoW 全域都會當場 nil 報錯），確認它是純資料＋純函式。
--
-- 覆蓋：過濾函式（學了沒由呼叫端注入）、SpellEntry／ItemEntry／AuraEntry 的形狀（含陣營換主 ID）、
-- 表的健全性（ID 都是正整數、沒有重複、每組至少一個、key 不重複）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Presets.lua"

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
local function list(t) local o = {} for i, v in ipairs(t or {}) do o[i] = tostring(v) end return table.concat(o, ",") end

-- 只留 Lua 標準函式庫：WoW 全域一個都沒有
local bare = { ipairs = ipairs, pairs = pairs, type = type, table = table, math = math, tostring = tostring }
local ns = {}
do
    local chunk, err
    if setfenv then
        chunk, err = loadfile(PATH)
        if chunk then setfenv(chunk, bare) end
    else
        chunk, err = loadfile(PATH, "t", bare)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
local P = ns.Presets
check("ns.Presets 存在", type(P) == "table")

------------------------------------------------------------
-- 1. 過濾
------------------------------------------------------------
local known = { [20572] = true, [33702] = true }
local function isKnown(id) return known[id] == true end
eq("種族：只留學了的", list(P.Racials("Orc", isKnown)), "20572,33702")
eq("種族：沒學任何一個 ⇒ 空", #P.Racials("Human", isKnown), 0)
eq("種族：不認得的 token ⇒ 空", #P.Racials("Murloc", isKnown), 0)
eq("種族：token 不是字串 ⇒ 空", #P.Racials(nil, isKnown), 0)
eq("種族：沒給 isKnown ⇒ 全部", #P.Racials("Orc"), 3)
eq("種族：一個都不能少（排序照表）", list(P.Racials("Draenei", function() return true end)), list(P.RACIALS.Draenei))
eq("防禦：只留學了的", list(P.Defensives("WARRIOR", function(id) return id == 871 or id == 97462 end)), "871,97462")
eq("防禦：不認得的職業 ⇒ 空", #P.Defensives("TINKER", isKnown), 0)
check("過濾回的是新表（呼叫端改了不會動到資料）", P.Racials("Orc") ~= P.RACIALS.Orc)

------------------------------------------------------------
-- 2. 一筆自訂項目的形狀
------------------------------------------------------------
local s = P.SpellEntry(20594, "essential")
eq("SpellEntry kind", s.kind, "spell")
eq("SpellEntry spellID", s.spellID, 20594)
eq("SpellEntry bar", s.bar, "essential")

local it = P.ItemEntry({ key = "x", items = { 11, 12, 13 } }, "g1")
eq("ItemEntry kind", it.kind, "item")
eq("ItemEntry 主＝第一個", it.itemID, 11)
eq("ItemEntry alts＝其餘照順序", list(it.alts), "12,13")
eq("ItemEntry bar", it.bar, "g1")
local single = P.ItemEntry({ key = "y", items = { 5512 } }, "g1")
eq("ItemEntry 只有一個：沒有 alts 欄位", single.alts, nil)
eq("ItemEntry 壞資料 ⇒ nil", P.ItemEntry({ key = "z" }, "g1"), nil)
eq("ItemEntry 空 items ⇒ nil", P.ItemEntry({ key = "z", items = {} }, "g1"), nil)

local lust
for _, d in ipairs(P.AURAS) do if d.key == "bloodlust" then lust = d end end
check("有嗜血那一組", lust ~= nil)
local a = P.AuraEntry(lust, "buffs", "Horde")
eq("AuraEntry kind", a.kind, "aura")
eq("AuraEntry 只收增益", a.filter, "HELPFUL")
eq("AuraEntry 有占位", a.placeholder, true)
eq("AuraEntry bar", a.bar, "buffs")
eq("部落：主＝ids[1]", a.spellID, lust.ids[1])
eq("部落：spellIDs＝其餘", #a.spellIDs, #lust.ids - 1)
local al = P.AuraEntry(lust, "buffs", "Alliance")
eq("聯盟：主換成 lead", al.spellID, 32182)
do
    local hasMain, hasFirst = false, false
    for _, id in ipairs(al.spellIDs) do
        if id == 32182 then hasMain = true end
        if id == lust.ids[1] then hasFirst = true end
    end
    check("聯盟：主不重複出現在 spellIDs", not hasMain)
    check("聯盟：原本的 ids[1] 進 spellIDs", hasFirst)
    eq("聯盟：總數不變", #al.spellIDs + 1, #lust.ids)
end
eq("陣營讀不到 ⇒ ids[1]", P.AuraEntry(lust, "buffs", nil).spellID, lust.ids[1])
eq("lead 不在 ids 裡 ⇒ ids[1]", P.AuraEntry({ ids = { 7, 8 }, lead = { Alliance = 99 } }, "b", "Alliance").spellID, 7)
local one = P.AuraEntry({ key = "p", ids = { 1236616 } }, "buffs")
eq("單一法術：沒有 spellIDs 欄位", one.spellIDs, nil)
eq("AuraEntry 壞資料 ⇒ nil", P.AuraEntry({ key = "q" }, "b"), nil)
eq("AuraIDs：全部", #P.AuraIDs(lust), #lust.ids)
check("AuraIDs：新表", P.AuraIDs(lust) ~= lust.ids)

------------------------------------------------------------
-- 3. 表的健全性
------------------------------------------------------------
local function PositiveInt(v) return type(v) == "number" and v > 0 and v == math.floor(v) end

local function CheckList(name, ids, seen)
    check(name .. "：至少一個", type(ids) == "table" and #ids > 0)
    for _, id in ipairs(ids or {}) do
        check(name .. "：正整數 " .. tostring(id), PositiveInt(id))
        check(name .. "：沒有重複 " .. tostring(id), not seen[id])
        seen[id] = true
    end
end

do
    local seen = {}            -- 種族技能整張表不重複（同一個 ID 不會屬於兩個種族）
    for race, ids in pairs(P.RACIALS) do
        check("種族 token 是字串", type(race) == "string")
        CheckList("種族 " .. race, ids, seen)
    end
end
do
    for class, ids in pairs(P.DEFENSIVES) do
        check("職業 token 全大寫", type(class) == "string" and class == class:upper())
        CheckList("防禦 " .. class, ids, {})
    end
    local n = 0
    for _ in pairs(P.DEFENSIVES) do n = n + 1 end
    eq("十三個職業都有", n, 13)
end
do
    local seen, keys = {}, {}
    for _, d in ipairs(P.ITEMS) do
        check("物品組有 key", type(d.key) == "string")
        check("物品組 key 不重複 " .. tostring(d.key), not keys[d.key])
        keys[d.key] = true
        CheckList("物品 " .. tostring(d.key), d.items, seen)
    end
    check("有治療石那一組", keys.healthstone)
end
do
    local seen, keys = {}, {}
    for _, d in ipairs(P.AURAS) do
        check("光環組有 key", type(d.key) == "string")
        check("光環組 key 不重複 " .. tostring(d.key), not keys[d.key])
        keys[d.key] = true
        CheckList("光環 " .. tostring(d.key), d.ids, seen)
        for faction, id in pairs(d.lead or {}) do
            local inIds = false
            for _, x in ipairs(d.ids) do if x == id then inIds = true end end
            check("lead 在 ids 裡 " .. tostring(faction), inIds)
        end
    end
    check("有時間螺旋那一組", keys.timeSpiral)
end

------------------------------------------------------------
-- 種族技能的動態解析（P8：戰隊層的那一筆 kind = "racial"，每個角色照自己的種族解析；isKnown 由呼叫端注入）
------------------------------------------------------------
do
    local known = { [33702] = true, [20572] = false, [33697] = false }
    local function isKnown(id) return known[id] end
    eq("解析：這個種族學了的那一個", P.ResolveRacial("Orc", isKnown), 33702)
    eq("解析：讀不到（nil）當學了 ⇒ 表裡第一個", P.ResolveRacial("Orc", function() return nil end), 20572)
    eq("解析：一個都沒學 ⇒ nil", P.ResolveRacial("Orc", function() return false end), nil)
    eq("解析：沒給 isKnown ⇒ 表裡第一個", P.ResolveRacial("Dwarf"), 20594)
    eq("解析：不認得的種族 ⇒ nil", P.ResolveRacial("Murloc", isKnown), nil)
    eq("解析：種族不是字串 ⇒ nil", P.ResolveRacial(nil, isKnown), nil)
    local e = P.RacialEntry("essential")
    check("種族技能那一筆：不帶 ID", e.kind == "racial" and e.bar == "essential" and e.spellID == nil)
    check("每次回新表", P.RacialEntry("essential") ~= e)
end

print(("Presets_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
