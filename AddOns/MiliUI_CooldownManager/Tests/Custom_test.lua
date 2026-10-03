------------------------------------------------------------
-- 自訂項目的資料路徑：Core/DB.lua 的新增／刪除（id 往前挪）／搬條／刪群組，
-- Core/Catalog.lua 的清單（排序、光環格照 order 排、隱藏、長條也收）與 Info，
-- Modules/Custom.lua 依條的 kind 取框（圖示框／長條框、光環持有框各一顆）、長條框的形狀、EndFlush（不進 TOC）
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
load("Modules/Custom.lua")          -- 替代品／多法術的純函式（第 8 節起）；載入時不建任何框
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
-- 3. 清單：光環格照 order 排（沒有 order 時照清單順序）、隱藏
------------------------------------------------------------
eqList("沒有 order：暴雪的在前、自訂照清單順序接在後（光環格不拉到最前）", C.Bar("essential"), { 11, 12, "c:1", "c:2", "c:3", "c:4" })
check("BarHasAuraSlot 核心", C.BarHasAuraSlot("essential"))
check("BarHasAuraSlot 輔助沒有", not C.BarHasAuraSlot("utility"))
local sp = DB.SpecSpells(true)
sp.order.essential = { 11, "c:1", 12 }
eqList("光環格夾在兩個暴雪 id 之間：順序保留，沒列到的照原順序接在後", C.Bar("essential"), { 11, "c:1", 12, "c:2", "c:3", "c:4" })
sp.order.essential = { "c:3", 12, "c:4", "c:2", 11, "c:1" }
eqList("光環格照 order 排，跟其他格一樣", C.Bar("essential"), { "c:3", 12, "c:4", "c:2", 11, "c:1" })
sp.hidden["c:3"] = true
local vis, hid = C.Bar("essential", true)
-- hidden 對自訂項目無效：自己加的「移除」就是整筆刪掉，沒有「藏著」這種狀態（舊存檔留著的旗標不會讓它憑空消失）
eqList("自訂項目不吃 hidden：不進移除清單", hid, {})
eqList("自訂項目不吃 hidden：照樣顯示", vis, { "c:3", 12, "c:4", "c:2", 11, "c:1" })
sp.hidden[12] = true
vis, hid = C.Bar("essential", true)
eqList("暴雪清單上的法術移除：進移除清單", hid, { 12 })
eqList("暴雪清單上的法術移除：不顯示", vis, { "c:3", "c:4", "c:2", 11, "c:1" })
sp.hidden[12] = nil
sp.hidden["c:3"] = nil
DB.SetCustomBar("c:2", "buffbars")
eqList("長條也收自訂項目（接在暴雪的後面）", C.Bar("buffbars"), { 41, "c:2" })
DB.SetCustomBar("c:1", "buffbars")
eqList("長條上的光環格也照清單順序（沒有固定前綴）", C.Bar("buffbars"), { 41, "c:1", "c:2" })
check("長條 BarHasAuraSlot", C.BarHasAuraSlot("buffbars"))
DB.SetCustomBar("c:1", "essential")
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
eq("AddCustom 襯衣欄不收", DB.AddCustom({ kind = "slot", slot = 4, bar = "essential" }), nil)
check("ValidCustom：裝備欄收、襯衣／外袍不收", C.ValidCustom({ kind = "slot", slot = 13 }) and C.ValidCustom({ kind = "slot", slot = 16 })
    and not C.ValidCustom({ kind = "slot", slot = 4 }) and not C.ValidCustom({ kind = "slot", slot = 19 }))
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

------------------------------------------------------------
-- 8. 替代品與多法術：純函式（Modules/Custom.lua）
------------------------------------------------------------
local CU = ns.Custom
eqList("ItemIDs：主在前、alts 照順序", CU.ItemIDs({ kind = "item", itemID = 5, alts = { 6, 7 } }), { 5, 6, 7 })
eqList("ItemIDs：沒有 alts", CU.ItemIDs({ kind = "item", itemID = 5 }), { 5 })
eqList("ItemIDs：alts 不是表就當沒有", CU.ItemIDs({ kind = "item", itemID = 5, alts = "6,7" }), { 5 })
eqList("ItemIDs：壞值、重複、跟主重複的跳過", CU.ItemIDs({ kind = "item", itemID = 5, alts = { 5, 0, -1, 2.5, "8", 6, 6 } }), { 5, 6 })
eqList("ItemIDs：不是表", CU.ItemIDs(nil), {})

local counts = { [6] = 3 }
local function countOf(id) return counts[id] end
eq("PickItem：第一個有的", CU.PickItem({ 5, 6, 7 }, countOf), 6)
counts[5] = 1
eq("PickItem：主的有就用主的", CU.PickItem({ 5, 6, 7 }, countOf), 5)
counts[5], counts[6] = 0, nil
eq("PickItem：都沒有 ⇒ 主的", CU.PickItem({ 5, 6, 7 }, countOf), 5)
eq("PickItem：讀不到（nil）⇒ 主的", CU.PickItem({ 5, 6 }, function() return nil end), 5)
eq("PickItem：數量不是數字當沒有", CU.PickItem({ 5, 6 }, function(id) if id == 6 then return "1" end end), 5)
eq("PickItem：沒給 countOf ⇒ 主的", CU.PickItem({ 5, 6 }), 5)
eq("PickItem：不是表 ⇒ nil", CU.PickItem(nil, countOf), nil)

eqList("AuraIDs：主＋spellIDs", CU.AuraIDs({ kind = "aura", spellID = 2825, spellIDs = { 32182, 80353 }, filter = "HELPFUL" }), { 2825, 32182, 80353 })
eqList("AuraIDs：沒 filter 當增益", CU.AuraIDs({ kind = "aura", spellID = 2825, spellIDs = { 32182 } }), { 2825, 32182 })
eqList("AuraIDs：減益只認主的", CU.AuraIDs({ kind = "aura", spellID = 800, spellIDs = { 801 }, filter = "HARMFUL" }), { 800 })
eqList("AuraIDs：spellIDs 不是表就當沒有", CU.AuraIDs({ kind = "aura", spellID = 700, spellIDs = 701 }), { 700 })
eq("AuraIDSig：單一法術＝那個 ID（跟以前的簽章一樣）", CU.AuraIDSig({ 700 }), "700")
eq("AuraIDSig：排序後串起來", CU.AuraIDSig({ 32182, 2825, 80353 }), "2825,32182,80353")
eq("AuraIDSig：順序不影響", CU.AuraIDSig({ 80353, 2825, 32182 }), CU.AuraIDSig({ 2825, 32182, 80353 }))
check("AuraIDSig：多一個 ID 簽章就不同", CU.AuraIDSig({ 2825, 32182 }) ~= CU.AuraIDSig({ 2825, 32182, 80353 }))
local srcIDs = { 32182, 2825 }
CU.AuraIDSig(srcIDs)
eqList("AuraIDSig：不動到傳進來的表", srcIDs, { 32182, 2825 })
eqList("AuraIDsOf：照 entry", CU.AuraIDsOf({ spellID = 2825, entry = { kind = "aura", spellID = 2825, spellIDs = { 32182 } } }), { 2825, 32182 })
eqList("AuraIDsOf：entry 拿掉了 ⇒ 主的", CU.AuraIDsOf({ spellID = 2825 }), { 2825 })

-- ResolveItem：包包數量走 C_Item.GetItemCount（明文才算）
local bag = {}
env.C_Item.GetItemCount = function(id) return bag[id] or 0 end
eq("ResolveItem：沒有替代品 ⇒ 主的（不問包包）", CU.ResolveItem({ kind = "item", itemID = 5 }), 5)
bag[7] = 2
eq("ResolveItem：挑包包裡有的", CU.ResolveItem({ kind = "item", itemID = 5, alts = { 6, 7 } }), 7)
bag[7] = nil
eq("ResolveItem：都沒有 ⇒ 主的", CU.ResolveItem({ kind = "item", itemID = 5, alts = { 6, 7 } }), 5)

------------------------------------------------------------
-- 9. 帶替代品／多法術的自訂項目：形狀、判重、Info
------------------------------------------------------------
check("ValidCustom：物品帶 alts", C.ValidCustom({ kind = "item", itemID = 5, alts = { 6 } }))
check("ValidCustom：alts 壞掉不算整筆壞", C.ValidCustom({ kind = "item", itemID = 5, alts = "x" }))
check("ValidCustom：光環帶 spellIDs", C.ValidCustom({ kind = "aura", spellID = 2825, spellIDs = { 32182 }, filter = "HELPFUL" }))
check("ValidCustom：spellIDs 壞掉不算整筆壞", C.ValidCustom({ kind = "aura", spellID = 2825, spellIDs = true }))
check("ValidCustom：主 ID 壞掉照樣整筆壞", not C.ValidCustom({ kind = "item", alts = { 6 } }))

local nPot = DB.AddCustom({ kind = "item", itemID = 241308, alts = { 241309, 245897 }, bar = "essential" })
local nLust = DB.AddCustom({ kind = "aura", spellID = 2825, spellIDs = { 32182 }, filter = "HELPFUL", placeholder = true, bar = "essential" })
check("加得進去", nPot ~= nil and nLust ~= nil)
eq("FindCustom 照主 ID", DB.FindCustom("item", 241308), nPot)
eq("FindCustom 替代品的 ID 不算", DB.FindCustom("item", 241309), nil)
eq("FindCustom 光環照主 ID", DB.FindCustom("aura", 2825, "HELPFUL"), nLust)
eq("FindCustom 光環的其他 ID 不算", DB.FindCustom("aura", 32182, "HELPFUL"), nil)
bag[245897] = 1
local ip = C.Info("c:" .. nPot)
eq("物品 Info：圖示照包包裡有的那件", ip and ip.icon, 800000 + 245897)
eq("物品 Info：名字照包包裡有的那件", ip and ip.name, "物品245897")
eq("物品 Info：itemID 是解析後的", ip and ip.itemID, 245897)
eq("物品 Info：mainItemID 留主的", ip and ip.mainItemID, 241308)
bag[245897] = nil
ip = C.Info("c:" .. nPot)
eq("物品 Info：都沒有 ⇒ 主的圖示", ip and ip.icon, 800000 + 241308)
local il = C.Info("c:" .. nLust)
eq("多法術光環 Info：圖示用主的", il and il.icon, 900000 + 2825)
check("多法術光環是光環格", C.IsAuraSlot("c:" .. nLust))

------------------------------------------------------------
-- 10. UpdateItem 的替代品路徑（CU.Update；框與引擎都 stub）
------------------------------------------------------------
do
    local function Tex()
        local t = { tex = nil, desat = nil }
        function t:SetTexture(v) self.tex = v end
        function t:SetDesaturation(v) self.desat = v end
        return t
    end
    local cleared = 0
    local frame = {
        Icon = Tex(),
        Cooldown = { Clear = function() cleared = cleared + 1 end },
        ChargeCount = { Current = { SetText = function(self, v) self.text = v end } },
        SetAlpha = function(self, a) self.alpha = a end,
    }
    local inval, requests = 0, {}
    ns.Keybinds = { Invalidate = function() inval = inval + 1 end }
    ns.Clickable = { Enabled = function(bar) return bar == "g9" end }
    ns.Bars = { Request = function(key, level) requests[#requests + 1] = key .. ":" .. level end }
    local savedSS = ns.SpellSetting
    ns.SpellSetting = function() return nil end
    local entry = { kind = "item", itemID = 241308, alts = { 241309 }, bar = "g9" }
    local rec = { kind = "item", itemID = 241308, entry = entry, frame = frame, placedBar = "g9",
                  armedStart = 10, armedDur = 300 }
    bag[241309] = 4
    CU.Update(rec)
    eq("換成包包裡有的", rec.itemID, 241309)
    eq("換了就清武裝", rec.armedStart, nil)
    eq("換了就清轉圈", cleared, 1)
    eq("換了就叫 Keybinds.Invalidate", inval, 1)
    eq("可點擊的條：要求重排", table.concat(requests, ","), "g9:layout")
    eq("圖示是新的那件", frame.Icon.tex, 800000 + 241309)
    eq("數量是新的那件", frame.ChargeCount.Current.text, "4")
    CU.Update(rec)
    eq("沒換：不再清、不再重排", inval .. "/" .. #requests, "1/1")
    bag[241309], bag[241308] = nil, 2
    CU.Update(rec, true)             -- Place 途中：同一輪的 Clickable.Place 會讀到，不必再要求
    eq("換回主的", rec.itemID, 241308)
    eq("Place 途中換：不要求重排", #requests, 1)
    eq("Place 途中換：照樣 Invalidate", inval, 2)
    -- 舊存檔的物品（沒有 alts）：永遠是主的，什麼都不清
    local plain = { kind = "item", itemID = 7, entry = { kind = "item", itemID = 7, bar = "g9" },
                    frame = frame, placedBar = "g9", armedStart = 5, armedDur = 60 }
    bag[7] = 0
    CU.Update(plain)
    eq("沒有替代品：itemID 不變", plain.itemID, 7)
    eq("沒有替代品：不清武裝（讀不到冷卻時沿用）", plain.armedStart, 5)
    eq("沒有替代品：不 Invalidate", inval, 2)
    ns.Keybinds, ns.Clickable, ns.Bars, ns.SpellSetting = nil, nil, nil, savedSS
end

------------------------------------------------------------
-- 11. 依條的 kind 取框：圖示框／長條框、光環持有框各一顆；長條框的形狀；EndFlush 不收長條
--     （框是假的：任何方法都記帳、少數幾個回值；Decorate／Glow／Text 都 stub）
------------------------------------------------------------
do
    -- 這幾個是框上的**欄位**（子框／區域），不是方法：沒設就是 nil（真的框也是）
    local FIELDS = { Bar = true, Timer = true, Cooldown = true, ChargeCooldown = true, ChargeCount = true, Icon = true,
                     Name = true, Duration = true, BarBG = true, Pip = true, Applications = true, Current = true,
                     SpellActivationAlert = true, SetBarContent = true }
    local function Obj(otype, parent)
        local o = { otype = otype, parent = parent, shown = true, calls = {}, level = 1 }
        setmetatable(o, { __index = function(t, k)
            if FIELDS[k] or type(k) ~= "string" or not k:match("^%u") then return nil end
            local fn = function(_, ...)
                t.calls[k] = (t.calls[k] or 0) + 1
                t["last_" .. k] = { ... }
            end
            rawset(t, k, fn)
            return fn
        end })
        function o:Hide() self.shown = false end
        function o:Show() self.shown = true end
        function o:SetShown(v) self.shown = v and true or false end
        function o:IsShown() return self.shown end
        function o:SetParent(p2) self.parent = p2 end
        function o:GetParent() return self.parent end
        function o:GetFrameLevel() return self.level end
        function o:SetFrameLevel(v) self.level = v end
        function o:CreateTexture() return Obj("Texture", self) end
        function o:CreateFontString() return Obj("FontString", self) end
        function o:SetText(v) self.text = v end
        o.hooks, o.scripts = {}, {}
        function o:HookScript(ev, fn) self.hooks[ev] = fn end
        function o:SetScript(ev, fn) self.scripts[ev] = fn end
        if otype == "StatusBar" then
            o.fill = Obj("Texture", o)
            function o:GetStatusBarTexture() return self.fill end
            function o:SetTimerDuration(d, _, dir)
                if self.rejectZero and d and d.zero then error("rejected") end
                self.timer = d; self.timerDir = dir
            end
        elseif otype == "Cooldown" then
            o.countdown = Obj("FontString", o)
            function o:GetCountdownFontString() return self.countdown end
            function o:SetCooldownFromDurationObject(d) self.duo = d end
            function o:Clear() self.duo = nil; self.cleared = (self.cleared or 0) + 1 end
        elseif otype == "AuraContainer" then
            function o:AddAuraSlot(key, filter, opts) self.slot = { key = key, filter = filter, opts = opts } end
        end
        return o
    end
    local savedCF, savedUI = env.CreateFrame, env.UIParent
    env.CreateFrame = function(otype, _, parent) return Obj(otype, parent) end
    env.UIParent = Obj("Frame")
    function env.UIParent:GetEffectiveScale() return 1 end
    env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
    env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
    local fakeDur = { name = "spellDur" }
    env.C_Spell.GetSpellCooldownDuration = function() return fakeDur end
    env.C_Spell.GetSpellCharges = function() return nil end
    env.C_Spell.IsSpellUsable = function() return true end
    env.C_Spell.SpellHasRange = function() return false end
    env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
    env.C_DurationUtil = { CreateDuration = function()
        local d = { zero = false }
        function d:SetTimeFromStart(_, du) self.zero = (du == 0) end
        return d
    end }

    local saved = { ns.Decorate, ns.Glow, ns.Keybinds, ns.Text, ns.Media, ns.Write, ns.Layout, ns.P, ns.Sound, ns.MiliUIGlow }
    local applied, parked = {}, 0
    ns.Decorate = {
        Apply = function(f, rec, barKey) applied[#applied + 1] = { f = f, bar = barKey }; rec.decorated = "deco:" .. barKey end,
        Resolve = function() return { bar = { showTime = true, timeSize = 14 }, font = "DEFAULT", outline = "" } end,
        IconOverrideOf = function() return nil end,
        StateAlphas = function() return 1, 1 end,
    }
    ns.Glow = { OnParked = function() parked = parked + 1 end, Sync = function() end, ArmProbe = function() end,
                CooldownStarted = function() end, SetProcActive = function() end }
    ns.Keybinds = { Apply = function() end, Invalidate = function() end }
    ns.Text = { SetFont = function() end, Anchor = function(fs, rel, point, x, y) fs.anchor = { rel, point, x, y } end,
                PixelScale = function() return 1 end, PlainFormatter = function(d) return { formatter = true, decimals = d } end }
    ns.Media = { SetFont = function() end, Font = function(t) return "font:" .. tostring(t) end,
                 ElementFont = function(own, gen) if own ~= nil and own ~= "INHERIT" then return own end return gen end,
                 Texture = function(t) return "tex:" .. tostring(t) end }
    ns.Write = function(frame, fn) fn(frame) return true end
    ns.Layout = { Snap = function(v) return v end }
    ns.P = { Scale = function(v) return v end }
    ns.Sound = { RequestAuraSync = function() end }
    ns.MiliUIGlow = nil

    -- 本專精重來一份乾淨的清單：法術（會被覆寫成 501）＋光環
    local list = DB.CustomList(true)
    for i = #list, 1, -1 do list[i] = nil end
    local iSpell = DB.AddCustom({ kind = "spell", spellID = 500, bar = "essential" })
    local iAura = DB.AddCustom({ kind = "aura", spellID = 700, filter = "HELPFUL", placeholder = true, bar = "essential" })
    CU.Sync()
    local rec = CU.Get("c:" .. iSpell)
    local arec = CU.Get("c:" .. iAura)
    check("Sync 建 rec 但不建框（第一次放進那種條才建）", rec and rec.frame == nil and next(rec.frames) == nil)
    eq("ShapeOf：核心是圖示", CU.ShapeOf("essential"), "icons")
    eq("ShapeOf：增益長條是長條", CU.ShapeOf("buffbars"), "bars")

    local cont1, cont2 = Obj("Frame"), Obj("Frame")
    CU.Place(rec, cont1, { x = 0, y = 0, w = 36, h = 36 }, "essential", 1)
    local iconFrame = rec.frame
    check("圖示類的條：圖示框（.Cooldown、沒有 .Bar）", iconFrame and iconFrame.Cooldown ~= nil and iconFrame.Bar == nil)
    eq("圖示類的條：shape", rec.shape, "icons")
    eq("圖示框掛在容器上", iconFrame:GetParent(), cont1)
    check("圖示類：不擋發光", not rec.noGlow)
    eq("圖示框吃法術冷卻", iconFrame.Cooldown.duo, fakeDur)

    -- 有 overlay（Decorate 建的）時，搬條要把它帶到新框
    rec.overlay = Obj("Frame", iconFrame)
    CU.Place(rec, cont2, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 2)
    local barFrame = rec.frame
    check("長條類的條：換成長條框", barFrame ~= iconFrame and barFrame.Bar ~= nil)
    eq("長條類的條：shape", rec.shape, "bars")
    check("長條框形狀：.Icon 是框、底下 .Icon 貼圖與 .Applications",
        barFrame.Icon and barFrame.Icon.otype == "Frame" and barFrame.Icon.Icon and barFrame.Icon.Icon.otype == "Texture"
        and barFrame.Icon.Applications and barFrame.Icon.Applications.otype == "FontString")
    local b = barFrame.Bar
    check("長條框形狀：.Bar 是 StatusBar，有 .Name／.Duration／.BarBG／.Pip＋ownPip",
        b.otype == "StatusBar" and b.Name and b.Duration and b.BarBG and b.Pip and b.ownPip == true)
    check("長條框形狀：秒數那顆 Cooldown（.Bar.Timer）", b.Timer and b.Timer.otype == "Cooldown")
    eq("秒數 Cooldown 不畫轉圈", b.Timer.last_SetDrawSwipe and b.Timer.last_SetDrawSwipe[1], false)
    eq("秒數 Cooldown 開倒數數字", b.Timer.last_SetHideCountdownNumbers and b.Timer.last_SetHideCountdownNumbers[1], false)
    eq("秒數整數（毫秒門檻 0）", b.Timer.last_SetCountdownMillisecondsThreshold and b.Timer.last_SetCountdownMillisecondsThreshold[1], 0)
    eq("舊的圖示框收起來", iconFrame.shown, false)
    eq("overlay 搬到新框", rec.overlay:GetParent(), barFrame)
    check("長條：擋發光（rec.noGlow）", rec.noGlow == true)
    check("搬條：發光熄掉", parked >= 1)
    eq("Decorate.Apply 套在長條框上", applied[#applied].f, barFrame)
    eq("條身吃引擎的 duration 物件", b.timer, fakeDur)
    eq("條身方向：剩餘時間", b.timerDir, env.Enum.StatusBarTimerDirection.RemainingTime)
    eq("秒數吃同一顆物件", b.Timer.duo, fakeDur)
    eq("名字寫法術名（覆寫後的）", b.Name.text, "法術501")
    eq("秒數字樣排在條的右邊", b.Timer.countdown.anchor and b.Timer.countdown.anchor[2], "RIGHT")
    eq("長條框掛在容器上", barFrame:GetParent(), cont2)

    -- 搬回圖示類：同一顆圖示框（池化），長條框收起來
    CU.Place(rec, cont1, { x = 0, y = 0, w = 36, h = 36 }, "essential", 3)
    eq("搬回圖示類：拿回同一顆圖示框", rec.frame, iconFrame)
    eq("搬回圖示類：長條框收起來", barFrame.shown, false)
    check("搬回圖示類：不再擋發光", not rec.noGlow)
    eq("搬回圖示類：overlay 跟回來", rec.overlay:GetParent(), iconFrame)
    CU.Place(rec, cont2, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 4)
    eq("再搬到長條：拿回同一顆長條框", rec.frame, barFrame)

    -- 清掉條身：零長度物件被收 ⇒ "zero"；被拒 ⇒ 退回 SetValue(0)
    CU.ClearBar(barFrame)
    eq("清條：零長度物件", CU.clearPath, "zero")
    check("清條：秒數 Cooldown 也清", (b.Timer.cleared or 0) >= 1)
    b.rejectZero = true
    CU.ClearBar(barFrame)
    eq("清條：零長度被拒 ⇒ SetValue(0)", CU.clearPath, "value")
    eq("清條：SetValue(0)", b.last_SetValue and b.last_SetValue[1], 0)
    b.rejectZero = nil

    -- 光環：長條的持有框＋容器；initializeFrame 走長條版
    CU.Place(arec, cont2, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 5)
    local barHolder = arec.frame
    check("光環在長條上：持有框（有容器池）", barHolder and type(barHolder.containers) == "table")
    eq("光環在長條上：shape", arec.shape, "bars")
    local c = arec.container
    check("建了容器", c and c.otype == "AuraContainer" and c.slot ~= nil)
    check("簽章帶長條的外觀", type(arec.sig) == "string" and arec.sig:find("|bars,", 1, true) ~= nil)
    eq("容器在持有框上", c and c:GetParent(), barHolder)
    eq("鏡像：rec.containers 是持有框的池", arec.containers, barHolder.containers)
    check("占位：底色、圖示、灰名字", barHolder.phBG and barHolder.phBG.shown and barHolder.phIcon.shown
        and barHolder.phName.text == "法術700")
    -- 跑一次 initializeFrame（假按鈕）
    local btn = Obj("Frame")
    local got = {}
    function btn:SetIcon(t) got.icon = t end
    function btn:SetDurationBar(bar, opts) got.bar, got.barOpts = bar, opts end
    function btn:SetDurationText(fs, opts) got.text, got.textOpts = fs, opts end
    function btn:SetApplicationCount(...) got.countArgs = { n = select("#", ...), ... } end
    arec.lastError = nil
    c.slot.opts.initializeFrame(btn)
    eq("initializeFrame 沒有錯誤", arec.lastError, nil)
    check("長條：條交給 SetDurationBar", got.bar and got.bar.otype == "StatusBar")
    eq("長條：剩餘時間方向", got.barOpts and got.barOpts.direction, env.Enum.StatusBarTimerDirection.RemainingTime)
    check("長條：秒數交給 SetDurationText（整數 formatter）", got.text and got.textOpts and got.textOpts.textFormatter
        and got.textOpts.textFormatter.decimals == 0)
    check("長條：層數 SetApplicationCount(fs, {})（不給格式器）", got.countArgs and got.countArgs.n == 2
        and type(got.countArgs[2]) == "table" and next(got.countArgs[2]) == nil)
    check("長條：圖示交給 SetIcon", got.icon and got.icon.otype == "Texture")
    check("長條：條身沒自己寫值", got.bar and got.bar.calls.SetValue == nil and got.bar.calls.SetMinMaxValues == nil)

    -- 光環搬到圖示類：另一顆持有框、另一個容器池
    CU.Place(arec, cont1, { x = 0, y = 0, w = 36, h = 36 }, "essential", 6)
    check("光環搬到圖示類：換一顆持有框", arec.frame ~= barHolder)
    eq("光環搬到圖示類：舊持有框收起來", barHolder.shown, false)
    check("光環搬到圖示類：容器是新持有框的", arec.container ~= c and arec.container:GetParent() == arec.frame)
    check("圖示版的簽章不帶長條", not arec.sig:find("|bars,", 1, true))
    CU.Place(arec, cont2, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 7)
    eq("光環搬回長條：同一顆持有框", arec.frame, barHolder)
    eq("光環搬回長條：同簽章拿回同一個容器（不重建）", arec.container, c)

    -- EndFlush：長條類的條上的不收；條不在了才收
    CU.EndFlush()
    eq("EndFlush：長條上的法術照放著", rec.placedBar, "buffbars")
    eq("EndFlush：長條上的光環照放著", arec.placedBar, "buffbars")
    rec.placedBar = "gone"
    CU.EndFlush()
    eq("EndFlush：條不在了 ⇒ 收", rec.placedBar, nil)
    eq("EndFlush：收起來的框藏起來", barFrame.shown, false)

    local n = CU.Counts()
    check("Counts：容器數照持有框算", n.containers >= 2)
    check("Counts：裝備欄種類不炸（slot 欄位在）", n.slot ~= nil)

    for i = #list, 1, -1 do list[i] = nil end
    CU.Sync()
    env.CreateFrame, env.UIParent = savedCF, savedUI
    ns.Decorate, ns.Glow, ns.Keybinds, ns.Text, ns.Media, ns.Write, ns.Layout, ns.P, ns.Sound, ns.MiliUIGlow =
        saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7], saved[8], saved[9], saved[10]
end

------------------------------------------------------------
-- 11. 三層範圍（P8）：Sync／Catalog 吃合併後的生效清單（戰隊 → 職業 → 專精、窄蓋寬、沒學就不列、種族技能）
------------------------------------------------------------
do
    load("Core/Presets.lua")                    -- 種族技能的解析表（純資料）
    env.UnitRace = function() return "矮人", "Dwarf", 3 end
    local list = DB.CustomList(true)
    for i = #list, 1, -1 do list[i] = nil end
    p.customShared, p.customClass, p.customNextUID = nil, nil, nil
    local sp = DB.SpecSpells(true)
    sp.order.essential = nil

    local wPot  = DB.AddCustomTo("shared", { kind = "item", itemID = 7, bar = "essential" })
    local wRace = DB.AddCustomTo("shared", { kind = "racial", bar = "essential" })
    local kDef  = DB.AddCustomTo("class", { kind = "spell", spellID = 500, bar = "essential" })
    local kGone = DB.AddCustomTo("class", { kind = "spell", spellID = 600, bar = "essential" })   -- 600 沒學
    local cAura = DB.AddCustomTo("spec", { kind = "aura", spellID = 700, filter = "HELPFUL", placeholder = true, bar = "essential" })
    eq("三層的 id", table.concat({ wPot, wRace, kDef, kGone, cAura }, ","), "w:1,w:2,k:3,k:4,c:1")
    eqList("C.Bar：戰隊 → 職業 → 專精接在暴雪的後面；沒學的職業層法術不列", C.Bar("essential"), { 11, 12, "w:1", "w:2", "k:3", "c:1" })
    local _, hid = C.Bar("essential", true)
    eqList("沒學就不列：設定頁的隱藏清單也沒有（不是玩家藏的）", hid, {})
    local ir = C.Info(wRace)
    check("種族技能：解析成這個角色的那一個", ir and ir.kind == "spell" and ir.spellID == 20594 and ir.racial == true)
    eq("Info 帶範圍：戰隊", ir and ir.scope, "shared")
    eq("Info 帶範圍：職業", C.Info(kDef) and C.Info(kDef).scope, "class")
    eq("Info 帶範圍：專精", C.Info(cAura) and C.Info(cAura).scope, "spec")
    eq("Info 寬層的編號是 uid", C.Info(kDef) and C.Info(kDef).index, 3)
    eq("Info 沒學、不列的寬層 ⇒ nil", C.Info(kGone), nil)
    check("IsCustom：寬層 id 也算", C.IsCustom("w:1") and C.IsCustom("k:3"))
    eq("C.CustomIndex 只認專精層", C.CustomIndex("w:1"), nil)
    eq("SourceOf 寬層 ＝ 它的 bar", C.SourceOf(kDef), "essential")

    CU.Sync()
    local rPot, rRace, rDef, rAura = CU.Get(wPot), CU.Get(wRace), CU.Get(kDef), CU.Get(cAura)
    check("Sync：每一層都有 rec", rPot and rRace and rDef and rAura)
    eq("Sync：沒學的不建", CU.Get(kGone), nil)
    eq("Sync：rec 記著自己的 id", rDef and rDef.cooldownID, kDef)
    eq("Sync：種族技能的 rec 是那個法術", rRace and rRace.spellID, 20594)
    eq("Sync：種族技能的 rec 種類是法術", rRace and rRace.kind, "spell")

    -- 窄蓋寬：專精層加同一個物品 ⇒ 戰隊那筆在這個專精不見，框照身分池化（同一個 rec 換 id）
    local cPot = DB.AddCustomTo("spec", { kind = "item", itemID = 7, bar = "utility" })
    eq("專精層的同一個物品 ⇒ c:2", cPot, "c:2")
    eqList("被蓋掉的戰隊層物品不在核心技能上", C.Bar("essential"), { 11, 12, "w:2", "k:3", "c:1" })
    eqList("專精層那筆在它自己的條上", C.Bar("utility"), { 21, "c:2" })
    CU.Sync()
    eq("Sync：被蓋掉的 id 沒有 rec", CU.Get(wPot), nil)
    eq("Sync：同一個身分拿同一顆 rec", CU.Get(cPot), rPot)
    eq("Sync：rec 換成窄層的 id", rPot.cooldownID, cPot)

    -- hideUnknown 關掉 ⇒ 沒學的照列（問號格）
    DB.CustomEntry(kGone).hideUnknown = false
    eqList("hideUnknown = false ⇒ 沒學的照列", C.Bar("essential"), { 11, 12, "w:2", "k:3", "k:4", "c:1" })
    eq("問號格：isKnown false", C.Info(kGone) and C.Info(kGone).isKnown, false)

    -- 種族技能解不到（種族不認得）⇒ 不列
    env.UnitRace = function() return "?", "Murloc", 99 end
    eqList("種族技能解不到 ⇒ 不列", C.Bar("essential"), { 11, 12, "k:3", "k:4", "c:1" })
    env.UnitRace = nil

    -- 刪寬層的一筆 ⇒ 不用挪位，其他 id 不變
    check("RemoveCustom k:3", DB.RemoveCustom(kDef))
    eqList("刪掉之後其他 id 不變", C.Bar("essential"), { 11, 12, "k:4", "c:1" })

    for i = #list, 1, -1 do list[i] = nil end
    p.customShared, p.customClass, p.customNextUID = nil, nil, nil
    CU.Sync()
end

print(("Custom_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
