------------------------------------------------------------
-- 自訂項目的資料路徑：Core/DB.lua 的新增／刪除（id 往前挪）／搬條／刪群組，
-- Core/Catalog.lua 的清單（排序、光環格固定前綴、隱藏、長條不收）與 Info（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Custom_test.lua
--
-- DB.lua 與 Catalog.lua 載進同一個環境表（WoW API stub），共用同一個 ns。
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
local function list(t) return table.concat(t or {}, ",") end
local function eqList(name, got, want) eq(name, list(got), list(want)) end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return false end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
env.Enum = {
    CompressionMethod = { Deflate = 1 },
    CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 },
    CooldownSetSpellFlags = { HideByDefault = 2 },
}
env.canaccessvalue = function() return true end
env.CDM_HIDE_INVISIBLE_ITEMS = false
local SETS = { [0] = { 11, 12 }, [1] = { 21 }, [2] = { 31, 32 }, [3] = { 41 } }
env.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(cat) return SETS[cat] or {} end,
    GetCooldownViewerCooldownInfo = function(id)
        return { cooldownID = id, spellID = id * 100, category = math.floor(id / 10) - 1, isKnown = true, flags = 0 }
    end,
    GetLayoutData = function() return "" end,
}
local known = { [500] = true, [600] = false }
env.C_Spell = {
    GetSpellTexture = function(id) return 900000 + id end,
    GetSpellName = function(id) return "法術" .. id end,
    GetOverrideSpell = function(id) if id == 500 then return 501 end return id end,
}
env.C_SpellBook = { IsSpellKnown = function(id) local v = known[id]; if v == nil then return true end return v end }
env.C_Item = {
    GetItemIconByID = function(id) return 800000 + id end,
    GetItemNameByID = function(id) if id == 7 then return nil end return "物品" .. id end,
    GetItemInfoInstant = function(id) return id, "", "", "", 800000 + id end,
}

local ns = {
    playerClass = "PALADIN",
    IsSecret = function() return false end,
    Events = { Register = function() end },
    Defer = function(fn, ...) fn(...) end,
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end

local function load(rel)
    local path = here .. "/../" .. rel
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
load("Core/DB.lua")
load("Core/Catalog.lua")
local DB, C = ns.DB, ns.Catalog
ns.RefreshSpec()
DB.Init()
C.Refresh("test")
local p = ns.profile

------------------------------------------------------------
-- 1. id 小工具
------------------------------------------------------------
eq("CustomIndex", DB.CustomIndex("c:12"), 12)
eq("CustomIndex 不是自訂", DB.CustomIndex(12), nil)
eq("CustomIndex 格式不對", DB.CustomIndex("c:x"), nil)
eq("Catalog 同一套", C.CustomIndex("c:3"), 3)
check("IsCustom", C.IsCustom("c:1") and not C.IsCustom(11))

------------------------------------------------------------
-- 2. 新增、找重複
------------------------------------------------------------
eq("沒有清單時 CustomList(false) ＝ nil", DB.CustomList(false), nil)
eq("AddCustom 光環 → 1", DB.AddCustom({ kind = "aura", spellID = 700, filter = "HELPFUL", placeholder = true, bar = "essential" }), 1)
eq("AddCustom 法術 → 2", DB.AddCustom({ kind = "spell", spellID = 500, bar = "essential" }), 2)
eq("AddCustom 物品 → 3", DB.AddCustom({ kind = "item", itemID = 7, bar = "essential" }), 3)
eq("AddCustom 光環（減益）→ 4", DB.AddCustom({ kind = "aura", spellID = 800, filter = "HARMFUL", placeholder = false, bar = "essential" }), 4)
eq("AddCustom 不認得的種類", DB.AddCustom({ kind = "totem", spellID = 1 }), nil)
eq("FindCustom 裝備欄位：還沒有", DB.FindCustom("slot", 13), nil)
eq("FindCustom 光環同 filter", DB.FindCustom("aura", 700, "HELPFUL"), 1)
eq("FindCustom 光環不同 filter", DB.FindCustom("aura", 700, "HARMFUL"), nil)
eq("FindCustom 法術", DB.FindCustom("spell", 500), 2)
eq("FindCustom 物品", DB.FindCustom("item", 7), 3)
eq("FindCustom 光環跟法術不混", DB.FindCustom("spell", 700), nil)

------------------------------------------------------------
-- 3. 清單：光環格固定前綴、順序覆寫照舊、隱藏
------------------------------------------------------------
eqList("核心：暴雪的在前、自訂接在後、光環格拉到最前", C.Bar("essential"), { "c:1", "c:4", 11, 12, "c:2", "c:3" })
check("BarHasAuraSlot 核心", C.BarHasAuraSlot("essential"))
check("BarHasAuraSlot 輔助沒有", not C.BarHasAuraSlot("utility"))
local sp = DB.SpecSpells(true)
sp.order.essential = { "c:3", 12, "c:4", "c:2", 11, "c:1" }
eqList("順序覆寫照舊，光環格仍在最前（彼此照覆寫的順序）", C.Bar("essential"), { "c:4", "c:1", "c:3", 12, "c:2", 11 })
sp.hidden["c:3"] = true
local vis, hid = C.Bar("essential", true)
-- hidden 對自訂項目無效：自己加的「移除」就是整筆刪掉，沒有「藏著」這種狀態（舊存檔留著的旗標不會讓它憑空消失）
eqList("自訂項目不吃 hidden：不進移除清單", hid, {})
eqList("自訂項目不吃 hidden：照樣顯示", vis, { "c:4", "c:1", "c:3", 12, "c:2", 11 })
sp.hidden[12] = true
vis, hid = C.Bar("essential", true)
eqList("暴雪清單上的法術移除：進移除清單", hid, { 12 })
eqList("暴雪清單上的法術移除：不顯示", vis, { "c:4", "c:1", "c:3", "c:2", 11 })
sp.hidden[12] = nil
sp.hidden["c:3"] = nil
DB.SetCustomBar("c:2", "buffbars")
eqList("長條不收自訂項目", C.Bar("buffbars"), { 41 })
DB.SetCustomBar("c:2", "essential")

------------------------------------------------------------
-- 4. Info / SourceOf
------------------------------------------------------------
local ia = C.Info("c:1")
eq("光環 Info kind", ia.kind, "aura")
eq("光環 Info 圖示", ia.icon, 900700)
eq("光環 Info filter", ia.filter, "HELPFUL")
local is = C.Info("c:2")
eq("法術 Info 用覆寫的圖示", is.icon, 900501)
eq("法術 Info 覆寫 id", is.overrideSpellID, 501)
eq("法術 Info bar", is.bar, "essential")
local ii = C.Info("c:3")
eq("物品 Info 圖示", ii.icon, 800007)
eq("物品名字還沒快取 ⇒ #id", ii.name, "#7")
DB.AddCustom({ kind = "spell", spellID = 600, bar = "utility" })
local iu = C.Info("c:5")
eq("沒學會 ⇒ 問號", iu.icon, 134400)

-- 裝備欄位（飾品 1／2）：追蹤現在裝的物品；空格用空格圖與欄位名
local equipped = { [13] = 7 }
env.GetInventoryItemID = function(unit, slot) return equipped[slot] end
env.GetInventorySlotInfo = function(token) if token == "TRINKET1SLOT" then return 14, "EmptyTrinket" end end
env.TRINKET1SLOT = "飾品"
eq("AddCustom 裝備欄位 → 6", DB.AddCustom({ kind = "slot", slot = 13, bar = "essential" }), 6)
eq("AddCustom 裝備欄位 2 → 7", DB.AddCustom({ kind = "slot", slot = 14, bar = "essential" }), 7)
eq("AddCustom 不是飾品欄位的 slot", DB.AddCustom({ kind = "slot", slot = 1, bar = "essential" }), nil)
check("ValidCustom：只收 13／14", C.ValidCustom({ kind = "slot", slot = 13 }) and not C.ValidCustom({ kind = "slot", slot = 16 }))
eq("FindCustom 裝備欄位", DB.FindCustom("slot", 13), 6)
local s1 = C.Info("c:6")
check("裝備欄位 Info：照現在裝的物品（itemID、圖示）", s1 and s1.kind == "slot" and s1.slot == 13 and s1.itemID == 7 and s1.icon == 800007)
local s2 = C.Info("c:7")
check("空的飾品欄：空格圖、欄位名、沒有 itemID", s2 and s2.itemID == nil and s2.icon == "EmptyTrinket" and s2.name == "飾品")
check("裝備欄位在清單上", (function() for _, id in ipairs(C.Bar("essential")) do if id == "c:6" then return true end end end)())
DB.RemoveCustom("c:7"); DB.RemoveCustom("c:6")
eq("沒學會 ⇒ isKnown false", iu.isKnown, false)
eq("SourceOf 自訂 ＝ 它的 bar", C.SourceOf("c:5"), "utility")
eq("Info 不存在的自訂", C.Info("c:99"), nil)
check("IsAuraSlot", C.IsAuraSlot("c:1") and not C.IsAuraSlot("c:2"))

-- 壞資料（匯入字串帶進來的）一律當不存在
DB.CustomList(false)[6] = { kind = "spell" }
eq("壞資料不進清單", list(C.Bar("utility")), "21,c:5")
eq("壞資料 Info ＝ nil", C.Info("c:6"), nil)
DB.CustomList(false)[6] = nil

------------------------------------------------------------
-- 5. 刪除：後面的 id 往前挪（順序、隱藏、覆寫）
------------------------------------------------------------
sp.hidden["c:4"] = true
sp.overrides["c:2"] = { borderColor = { r = 1, g = 0, b = 0, a = 1 } }
sp.overrides["c:4"] = { hideStackText = true }
sp.overrides[11] = { procGlow = false }
check("RemoveCustom c:2", DB.RemoveCustom("c:2"))
eq("刪掉之後剩四筆", #DB.CustomList(false), 4)
eq("原本的 c:3（物品）變成 c:2", DB.CustomEntry("c:2").itemID, 7)
eq("原本的 c:4（減益）變成 c:3", DB.CustomEntry("c:3").spellID, 800)
eqList("順序裡的 id 跟著挪、刪掉的拿掉", sp.order.essential, { "c:2", 12, "c:3", 11, "c:1" })
eq("隱藏跟著挪", sp.hidden["c:3"], true)
eq("舊的隱藏位置清掉", sp.hidden["c:4"], nil)
eq("刪掉那筆的覆寫不見", sp.overrides["c:2"], nil)
eq("覆寫跟著挪", sp.overrides["c:3"] and sp.overrides["c:3"].hideStackText, true)
eq("暴雪法術的覆寫不動", sp.overrides[11] and sp.overrides[11].procGlow, false)
eq("刪不存在的", DB.RemoveCustom("c:9"), false)
eq("刪非自訂 id", DB.RemoveCustom(11), false)

------------------------------------------------------------
-- 6. 刪群組：放在上面的自訂項目回預設的條
------------------------------------------------------------
local g = DB.CreateBar("icons", "防禦")
DB.SetCustomBar("c:1", g)      -- 光環
DB.SetCustomBar("c:2", g)      -- 物品
eqList("群組裡的自訂項目（光環在前）", C.Bar(g), { "c:1", "c:2" })
check("群組 BarHasAuraSlot", C.BarHasAuraSlot(g))
check("DeleteBar", DB.DeleteBar(g))
eq("光環格回增益圖示", DB.CustomEntry("c:1").bar, "buffs")
eq("物品回核心技能", DB.CustomEntry("c:2").bar, "essential")

------------------------------------------------------------
-- 7. 專精換了：清單是另一份
------------------------------------------------------------
ns.specID = 62
eqList("別的專精沒有自訂項目", C.Bar("essential"), { 11, 12 })
eq("別的專精 CustomEntry ＝ nil", DB.CustomEntry("c:1"), nil)
ns.specID = 61

print(("Custom_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
