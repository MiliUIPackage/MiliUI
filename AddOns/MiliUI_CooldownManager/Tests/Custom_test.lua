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
load("Core/MasqueShape.lua")
load("Modules/Custom.lua")          -- 替代品／多法術的純函式（第 8 節起）；載入時不建任何框
load("Core/Text.lua")               -- 逐法術文字樣式的合併（Text.SpellText）：下面 stub 掉 ns.Text 的地方借用真的那幾支
local RealText = ns.Text
local function TextStub(t)
    t.SpellText, t.BarTimePlace, t.Color, t.EMPTY = RealText.SpellText, RealText.BarTimePlace, RealText.Color, RealText.EMPTY
    t.BuffTiming = RealText.BuffTiming
    t.LabelStyle, t.LabelPlace, t.LabelSig = RealText.LabelStyle, RealText.LabelPlace, RealText.LabelSig
    return t
end
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
                     SpellActivationAlert = true, SetBarContent = true, Seg = true }
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
    ns.Text = TextStub({ SetFont = function() end, Anchor = function(fs, rel, point, x, y) fs.anchor = { rel, point, x, y } end,
                PixelScale = function() return 1 end, PlainFormatter = function(d) return { formatter = true, decimals = d } end })
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

    -- 充能分段（F8b）：計數條＋進度條＋分隔線；上限讀不到明文 ⇒ 退回舊行為
    do
        local savedDeco, savedSG, savedDiag = ns.Decorate, ns.StackGate, ns.Diag
        local barCfg = { showTime = true, timeSize = 14, chargeSegments = true, iconSide = "LEFT", iconGap = 2,
                         texture = "solid", color = { r = 0.4, g = 0.6, b = 0.9, a = 1 } }
        local painted = 0
        ns.Decorate = setmetatable({
            Resolve = function() return { bar = barCfg, font = "DEFAULT", outline = "" } end,
            PaintFill = function() painted = painted + 1 end,
            GradientSig = function() return "-" end,
        }, { __index = savedDeco })
        local ticks
        ns.StackGate = {
            BodyWidth = function(w, h, side, gap, vertical)
                if vertical then w, h = h, w end
                return w - h - gap
            end,
            DrawTicks = function(host, anchor, len, t, vertical) ticks = { host = host, anchor = anchor, len = len, t = t, v = vertical } end,
        }
        local notes = 0
        ns.Diag = { Note = function() notes = notes + 1 end }
        local chargeDur = { name = "chargeDur" }
        local charges = { maxCharges = 2, currentCharges = 1 }
        env.C_Spell.GetSpellCharges = function() return charges end
        env.C_Spell.GetSpellChargeDuration = function() return chargeDur end
        rec.placeW, rec.placeH = 200, 20
        CU.Update(rec)
        local seg = b.Seg
        check("分段：建了計數條／進度條", seg and seg.count and seg.prog and seg.count.otype == "StatusBar")
        eq("分段：條身裁切子框", b.last_SetClipsChildren and b.last_SetClipsChildren[1], true)
        eq("分段：計數條上限＝充能上限", seg.count.last_SetMinMaxValues and seg.count.last_SetMinMaxValues[2], 2)
        eq("分段：計數條吃現有充能", seg.count.last_SetValue and seg.count.last_SetValue[1], 1)
        eq("分段：進度條吃回充物件", seg.prog.timer, chargeDur)
        eq("分段：進度條方向＝已過時間", seg.prog.timerDir, env.Enum.StatusBarTimerDirection.ElapsedTime)
        eq("分段：進度條錨在計數條的填充貼圖", seg.prog.last_SetPoint and seg.prog.last_SetPoint[2], seg.count.fill)
        eq("分段：進度條寬＝條身長／上限", seg.prog.last_SetWidth and seg.prog.last_SetWidth[1], (200 - 20 - 2) / 2)
        eq("分段：分隔線的段數", ticks and ticks.t.n, 2)
        eq("分段：分隔線錨條身", ticks and ticks.anchor, b)
        eq("分段：自己的填充調透明", b.fill.last_SetAlpha and b.fill.last_SetAlpha[1], 0)
        eq("分段：名字搬到字框", b.Name:GetParent(), seg.text)
        eq("分段：火花跟著進度條", b.pipAnchor, seg.prog.fill)
        eq("分段：秒數照吃回充物件", b.Timer.duo, chargeDur)
        check("分段：兩條的填充都上色", painted >= 2)
        -- 戰鬥中秘密：上限讀不到明文 ⇒ 沿用最後一次明文的
        charges = { maxCharges = nil, currentCharges = 0 }
        CU.Update(rec)
        eq("秘密上限：沿用明文的那次", b.segOn, true)
        eq("秘密上限：計數條照餵", seg.count.last_SetValue[1], 0)
        -- 從沒讀到明文 ⇒ 退回舊行為、記 debug
        rec.maxCharges = nil
        CU.Update(rec)
        eq("讀不到上限 ⇒ 不分段", b.segOn, false)
        eq("退回：計數條藏起來", seg.count.shown, false)
        eq("退回：名字搬回條身", b.Name:GetParent(), b)
        eq("退回：自己的填充不透明", b.fill.last_SetAlpha[1], 1)
        eq("退回：記一行 diag", notes, 1)
        check("退回：debug 行", CU.SegDebugLine():find("退回舊行為", 1, true) ~= nil)
        -- 關掉設定
        charges = { maxCharges = 3, currentCharges = 3 }
        CU.Update(rec)
        eq("再開：三段", seg.count.last_SetMinMaxValues[2], 3)
        barCfg.chargeSegments = false
        CU.Update(rec)
        eq("設定關 ⇒ 不分段", b.segOn, false)
        ns.Decorate, ns.StackGate, ns.Diag = savedDeco, savedSG, savedDiag
        env.C_Spell.GetSpellCharges = function() return nil end
        rec.isCharge, rec.maxCharges = nil, nil
    end

    -- 光環：長條的持有框＋容器；initializeFrame 走長條版
    -- 長條的占位跟暴雪增益長條同一套：「空位樣式」是 bar 才畫（Custom.WantPlaceholder）
    do
        local bt = DB.BarTable("buffbars")
        bt.layout = bt.layout or {}
        bt.layout.emptyStyle = "bar"
    end
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
    -- 自訂文字（M）：圖示形的光環格才烘（值解進 st.label、進簽章 ⇒ 換容器；initializeFrame 在按鈕的 ov 上建）；長條形不烘
    do
        local aid = arec.cooldownID
        local sig0, c0 = arec.sig, arec.container
        eq("自訂文字：沒設 ⇒ 不解", CU.AuraStyle(arec, "essential", 36, 36, "icons").label, nil)
        DB.SetOverride(aid, "labelText", "提醒")
        DB.SetOverride(aid, "labelColor", { r = 0, g = 1, b = 0, a = 1 })
        local stL = CU.AuraStyle(arec, "essential", 36, 36, "icons")
        local lb = stL.label
        check("自訂文字：解進 st.label（字、預設圖示內下緣、y -2、字級 12、顏色）", lb and lb.text == "提醒"
            and lb.point == "BOTTOM" and lb.justify == "CENTER" and lb.x == 0 and lb.y == -2 and lb.size == 12
            and lb.color[1] == 0 and lb.color[2] == 1)
        CU.Place(arec, cont1, { x = 0, y = 0, w = 36, h = 36 }, "essential", 61)
        check("自訂文字 ⇒ 簽章變、換容器", arec.sig ~= sig0 and arec.container ~= c0)
        local lbtn = Obj("Frame")
        function lbtn:SetIcon() end
        function lbtn:SetDurationText() end
        function lbtn:SetApplicationCount() end
        arec.labelsBaked, arec.lastError = 0, nil
        arec.container.slot.opts.initializeFrame(lbtn)
        eq("initializeFrame：沒有錯誤", arec.lastError, nil)
        eq("initializeFrame：烘了一顆自訂文字", arec.labelsBaked, 1)
        DB.SetOverride(aid, "labelPoint", "TOPLEFT")
        DB.SetOverride(aid, "labelY", 0)
        lb = CU.AuraStyle(arec, "essential", 36, 36, "icons").label
        check("自訂文字：九宮格＝圖示內的角（左上靠左）、偏移 0 也是覆寫", lb.point == "TOPLEFT" and lb.justify == "LEFT" and lb.y == 0)
        eq("自訂文字：長條形不解", CU.AuraStyle(arec, "buffbars", 200, 20, "bars").label, nil)
        for _, f in ipairs({ "labelText", "labelColor", "labelPoint", "labelY" }) do DB.SetOverride(aid, f, nil) end
        eq("自訂文字：清掉 ⇒ 不解", CU.AuraStyle(arec, "essential", 36, 36, "icons").label, nil)
        DB.SetOverride(aid, "labelText", "   ")
        eq("自訂文字：只有空白 ＝ 沒字", CU.AuraStyle(arec, "essential", 36, 36, "icons").label, nil)
        DB.SetOverride(aid, "labelText", nil)
        CU.Place(arec, cont1, { x = 0, y = 0, w = 36, h = 36 }, "essential", 62)
        eq("清掉 ⇒ 拿回原本那顆容器（池化）", arec.container, c0)
    end
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

------------------------------------------------------------
-- 12. 效能修整 E3 #10：SPELL_UPDATE_USABLE 只重算顏色、事件動態註冊（CU.WantedEvents／SyncEvents）
------------------------------------------------------------
do
    local CU = ns.Custom
    -- WantedEvents（純函式）
    local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
    local w = CU.WantedEvents({}, {})
    eq("沒有項目 ⇒ 一個都不聽", Count(w), 0)
    w = CU.WantedEvents({ a = { kind = "aura" } }, {})
    eq("只有光環格 ⇒ 一個都不聽", Count(w), 0)
    w = CU.WantedEvents({ a = { kind = "item" } }, {})
    eq("有物品 ⇒ 全標那五個", Count(w), #CU.MARK_EVENTS)
    check("有物品 ⇒ BAG_UPDATE_COOLDOWN", w.BAG_UPDATE_COOLDOWN == true)
    eq("只有物品 ⇒ 不聽 SPELL_UPDATE_USABLE", w.SPELL_UPDATE_USABLE, nil)
    w = CU.WantedEvents({ a = { kind = "spell" }, b = { kind = "aura" } }, {})
    eq("有法術 ⇒ SPELL_UPDATE_USABLE", w.SPELL_UPDATE_USABLE, true)
    eq("距離表空 ⇒ 不聽距離事件", w.SPELL_RANGE_CHECK_UPDATE, nil)
    eq("距離表空 ⇒ 不聽換目標", w.PLAYER_TARGET_CHANGED, nil)
    eq("冷卻事件不在這裡（SpellIndex 管）", w.SPELL_UPDATE_COOLDOWN, nil)
    w = CU.WantedEvents({ a = { kind = "spell" } }, { [500] = 1 })
    eq("距離表非空 ⇒ SPELL_RANGE_CHECK_UPDATE", w.SPELL_RANGE_CHECK_UPDATE, true)
    eq("距離表非空 ⇒ PLAYER_TARGET_CHANGED", w.PLAYER_TARGET_CHANGED, true)
    local out = { STALE = true }
    local w2 = CU.WantedEvents({}, {}, out)
    check("給了 out ⇒ 重複用同一張、清乾淨", w2 == out and out.STALE == nil)

    -- colorDirty：只走 RefreshColor（UpdateSpell 不跑）；dirty 照舊整套
    local saveUpdate, saveColor = CU.Update, CU.RefreshColor
    local recs = CU.Records()
    local sp = { kind = "spell", placedBar = "essential", frame = {}, spellID = 500 }
    local it = { kind = "item", placedBar = "essential", frame = {}, itemID = 5 }
    recs["test:sp"], recs["test:it"] = sp, it
    local updated = {}
    CU.Update = function(rec) updated[rec] = (updated[rec] or 0) + 1; rec.dirty, rec.colorDirty = nil, nil end
    -- RefreshColor 是 local：stub 它讀的 API，用 colorOnly 計數驗證
    local u0, c0 = CU.updates, CU.colorOnly
    CU.OnUsable()
    eq("SPELL_UPDATE_USABLE：法術標 colorDirty", sp.colorDirty, nil)    -- Defer 同步 ⇒ 已經 Flush 掉
    eq("SPELL_UPDATE_USABLE：不整套更新", updated[sp], nil)
    eq("SPELL_UPDATE_USABLE：物品不動", updated[it], nil)
    eq("SPELL_UPDATE_USABLE：colorOnly +1", CU.colorOnly, c0 + 1)
    eq("SPELL_UPDATE_USABLE：UpdateSpell 沒跑", CU.updates, u0)
    -- 同時髒兩級：整套那條吃掉 colorDirty（不重算兩次）
    sp.dirty, sp.colorDirty = true, true
    CU.Flush()
    eq("兩級都髒 ⇒ 整套一次", updated[sp], 1)
    eq("兩級都髒 ⇒ 不另外只算顏色", CU.colorOnly, c0 + 1)
    eq("兩級都髒 ⇒ colorDirty 清掉", sp.colorDirty, nil)
    -- 沒放在條上的：留著 colorDirty（之後 Place 會整套 Update）
    sp.placedBar = nil
    CU.OnUsable()
    eq("沒放在條上 ⇒ 不重算", CU.colorOnly, c0 + 1)
    eq("沒放在條上 ⇒ 旗標留著", sp.colorDirty, true)
    sp.colorDirty = nil
    -- 冷卻事件的消費者：GCD 開始照舊全標（自訂框沒有 SetCooldown 後掛勾當安全網）；精準只標命中的
    sp.dirty, it.dirty = nil, nil
    it.placedBar = nil
    CU.OnCooldownBatch(false, {}, true)
    eq("GCD 開始：全標（法術）", sp.dirty, true)
    eq("GCD 開始：全標（物品）", it.dirty, true)
    sp.dirty, it.dirty = nil, nil
    CU.OnCooldownBatch(false, { [{ rec = it }] = true }, false)
    eq("精準：只標命中的（暴雪那邊的 entry 沒有 custom 旗標 ⇒ 不標）", it.dirty, nil)
    it.custom = true
    CU.OnCooldownBatch(false, { [{ rec = it }] = true }, false)
    eq("精準：命中的自訂項目標髒", it.dirty, true)
    eq("精準：沒命中的不標", sp.dirty, nil)
    recs["test:sp"], recs["test:it"] = nil, nil
    CU.Update, CU.RefreshColor = saveUpdate, saveColor

    -- SyncEvents：照生效清單註冊／反註冊（Sync 結尾叫）
    local reg = {}
    ns.Events = {
        Register = function(ev, key) reg[ev] = key end,
        Unregister = function(ev, key) if reg[ev] == key then reg[ev] = nil end end,
    }
    for k in pairs(CU.evOn) do CU.evOn[k] = nil end
    CU.Sync()
    local anyNonAura = CU.activeNonAura > 0
    CU.SyncEvents()
    eq("SyncEvents：有非光環項目 ⇔ 註冊了 SPELL_UPDATE_CHARGES", reg.SPELL_UPDATE_CHARGES ~= nil, anyNonAura)
    eq("SyncEvents：SPELL_UPDATE_COOLDOWN 從不在這裡註冊", reg.SPELL_UPDATE_COOLDOWN, nil)
    -- 距離表從空到有、從有到空
    local saveRange = next(CU.rangeOn)
    if saveRange == nil then
        CU.rangeOn[123] = 1
        CU.SyncEvents()
        eq("距離表有東西 ⇒ 註冊 SPELL_RANGE_CHECK_UPDATE", reg.SPELL_RANGE_CHECK_UPDATE, "custom_range")
        CU.rangeOn[123] = nil
        CU.SyncEvents()
        eq("距離表空了 ⇒ 反註冊", reg.SPELL_RANGE_CHECK_UPDATE, nil)
        eq("距離表空了 ⇒ 換目標也反註冊", reg.PLAYER_TARGET_CHANGED, nil)
    end
    ns.Events = { Register = function() end }
end

------------------------------------------------------------
-- 12. 充能分段的純函式（F8b）：要不要分段、分段幾何
------------------------------------------------------------
do
    local CU = ns.Custom
    eq("分段：關 ⇒ nil", (CU.SegmentMode(false, true, 2)), nil)
    eq("分段：關的原因", select(2, CU.SegmentMode(false, true, 2)), "off")
    eq("分段：不是充能 ⇒ notcharge", select(2, CU.SegmentMode(true, false, 2)), "notcharge")
    eq("分段：上限讀不到 ⇒ unknown", select(2, CU.SegmentMode(true, true, nil)), "unknown")
    eq("分段：上限 1 ⇒ 不分", (CU.SegmentMode(true, true, 1)), nil)
    eq("分段：上限 3", (CU.SegmentMode(true, true, 3)), 3)
    local segLen, lines = CU.SegmentGeometry(180, 3)
    eq("幾何：一段長", segLen, 60)
    check("幾何：分隔線位置", #lines == 2 and lines[1] == 60 and lines[2] == 120, list(lines))
    eq("幾何：上限 1 ⇒ nil", CU.SegmentGeometry(180, 1), nil)
    eq("幾何：長度 0 ⇒ nil", CU.SegmentGeometry(0, 3), nil)
    eq("預設值：充能分段關", ns.DB.NewBarTable("bars", "x").bar.chargeSegments, false)
end

------------------------------------------------------------
-- 13. 飾品欄冷卻格的增益疊層（A）：要不要疊、持有框錨容器與層級、容器的法術與外觀、戰鬥中只記旗標、
--     換形狀、收起來、BarHasAuraSlot 認得疊層
------------------------------------------------------------
do
    local FIELDS = { Bar = true, Timer = true, Cooldown = true, ChargeCooldown = true, ChargeCount = true, Icon = true,
                     Name = true, Duration = true, BarBG = true, Pip = true, Applications = true, Current = true,
                     SpellActivationAlert = true, SetBarContent = true, Seg = true }
    local function Obj(otype, parent)
        local o = { otype = otype, parent = parent, shown = true, calls = {},
                    level = parent and (parent.level or 1) + 1 or 1 }
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
        function o:CreateTexture(_, layer, _, sub)
            self.texCount = self.texCount + 1
            local t = Obj("Texture", self)
            t.layer, t.sub = layer, sub
            self.texs = self.texs or {}
            self.texs[#self.texs + 1] = t
            return t
        end
        function o:CreateFontString() return Obj("FontString", self) end
        function o:SetText(v) self.text = v end
        o.hooks, o.scripts = {}, {}
        function o:HookScript(ev, fn) self.hooks[ev] = fn end
        function o:SetScript(ev, fn) self.scripts[ev] = fn end
        function o:SetSwipeColor(...) self.swipe = { ... } end
        function o:SetTextColor(...) self.color = { ... } end
        -- 幾何（光環格的 Masque：從自己的框讀回形狀）：寫什麼記什麼、讀回來
        o.points = {}
        function o:SetPoint(p, rel, rp, x, y)
            self.last_SetPoint = { p, rel, rp, x, y }
            self.points[#self.points + 1] = { p, rel or self.parent, rp or p, x or 0, y or 0 }
        end
        function o:ClearAllPoints() self.points = {} end
        function o:SetAllPoints(rel)
            rel = rel or self.parent
            self.points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
        end
        function o:GetNumPoints() return #self.points end
        function o:GetPoint(i) local q = self.points[i]; if q then return q[1], q[2], q[3], q[4], q[5] end end
        function o:SetSize(w, h) self.last_SetSize = { w, h }; self.w, self.h = w, h end
        function o:GetWidth() return self.w end
        function o:GetHeight() return self.h end
        function o:SetTexCoord(l, r, t, b) self.tc = { l, r, t, b } end
        function o:GetTexCoord()
            local c = self.tc or { 0, 1, 0, 1 }
            return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
        end
        function o:SetTexture(v, ...) self.last_SetTexture = { v, ... }; self.file = v end
        function o:GetTextureFilePath() return type(self.file) == "string" and self.file or nil end
        function o:SetAtlas(a) self.atlas = a end
        function o:GetAtlas() return self.atlas end
        function o:CreateMaskTexture() return Obj("MaskTexture", self) end
        function o:AddMaskTexture(m) self.masks = self.masks or {}; self.masks[#self.masks + 1] = m end
        function o:GetNumMaskTextures() return #(self.masks or {}) end
        function o:GetMaskTexture(i) return (self.masks or {})[i] end
        function o:SetSwipeTexture(v) self.swipeTex = v end
        function o:SetAlpha(a) self.last_SetAlpha = { a }; self.alpha = a end
        function o:GetAlpha() return self.alpha or 1 end
        function o:SetVertexColor(...) self.vc = { ... } end
        function o:GetVertexColor() local v = self.vc or { 1, 1, 1, 1 }; return v[1], v[2], v[3], v[4] end
        function o:SetBlendMode(b) self.blend = b end
        function o:GetBlendMode() return self.blend or "BLEND" end
        function o:SetDrawLayer(l, sub) self.layer, self.sub = l, sub end
        function o:GetDrawLayer() return self.layer or "ARTWORK", self.sub or 0 end
        o.texCount = 0
        if otype == "StatusBar" then
            o.fill = Obj("Texture", o)
            function o:GetStatusBarTexture() return self.fill end
            function o:SetTimerDuration(d) self.timer = d end
        elseif otype == "Cooldown" then
            o.countdown = Obj("FontString", o)
            function o:GetCountdownFontString() return self.countdown end
            function o:SetCooldownFromDurationObject(d) self.duo = d end
            function o:Clear() self.duo = nil end
        elseif otype == "AuraContainer" then
            function o:AddAuraSlot(key, filter, opts) self.slot = { key = key, filter = filter, opts = opts } end
        end
        return o
    end
    local savedCF, savedUI, savedICL, savedEv = env.CreateFrame, env.UIParent, env.InCombatLockdown, ns.Events
    ns.Events = { Register = function() end, Unregister = function() end }
    local combat = false
    env.InCombatLockdown = function() return combat end
    env.CreateFrame = function(otype, _, parent) return Obj(otype, parent) end
    env.UIParent = Obj("Frame")
    function env.UIParent:GetEffectiveScale() return 1 end
    env.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function() end } end }
    env.C_Item.GetItemCooldown = function() return 0, 0, 1 end
    env.C_Item.GetItemCount = function() return 1 end
    env.C_Item.IsConsumableItem = function() return false end

    -- 裝備欄：槽 13 裝 270175，暴雪的 EquipSlotTracked（類別 8）兩筆增益
    local equipped = { [13] = 270175 }
    env.GetInventoryItemID = function(_, slot) return equipped[slot] end
    local itemSpell = { [270175] = 1297761, [280000] = 1400000 }
    env.C_Item.GetItemSpell = function(id) local sp = itemSpell[id]; if sp then return "使用效果", sp end end
    env.Enum.CooldownViewerCategory.EquipSlotTracked = 8
    local linked = { [801] = { 13, 1, { 1297761 } }, [802] = { 13, 2, { 1305376 } } }
    local CV = env.C_CooldownViewer
    local savedSet, savedInfo = CV.GetCooldownViewerCategorySet, CV.GetCooldownViewerCooldownInfo
    CV.GetCooldownViewerCategorySet = function(cat, ...)
        if cat == 8 then return { 801, 802 } end
        return savedSet(cat, ...)
    end
    CV.GetCooldownViewerCooldownInfo = function(id)
        local l = linked[id]
        if l then return { cooldownID = id, equipSlot = l[1], buffSlot = l[2], linkedSpellIDs = l[3], category = 8 } end
        return savedInfo(id)
    end
    C.InvalidateSlotBuffs()

    local saved = { ns.Decorate, ns.Glow, ns.Keybinds, ns.Text, ns.Media, ns.Write, ns.Layout, ns.P, ns.Sound, ns.MiliUIGlow }
    ns.Decorate = {
        Apply = function(_, rec, barKey) rec.decorated = "deco:" .. barKey end,
        Resolve = function() return { bar = { showTime = true, timeSize = 14 }, font = "DEFAULT", outline = "" } end,
        IconOverrideOf = function() return nil end,
        StateAlphas = function() return 1, 1 end,
        DurationColorOf = function(on, color) if on and type(color) == "table" then return color end end,
    }
    ns.Glow = { OnParked = function() end, Sync = function() end, ArmProbe = function() end,
                CooldownStarted = function() end, SetProcActive = function() end }
    ns.Keybinds = { Apply = function() end, Invalidate = function() end }
    ns.Text = TextStub({ SetFont = function() end, Anchor = function() end, PixelScale = function() return 1 end,
                PlainFormatter = function(d) return { formatter = true, decimals = d } end })
    ns.Media = { SetFont = function() end, Font = function(t) return "font:" .. tostring(t) end,
                 ElementFont = function(own, gen) if own ~= nil and own ~= "INHERIT" then return own end return gen end,
                 Texture = function(t) return "tex:" .. tostring(t) end }
    local writes = {}
    ns.Write = function(frame, fn, key)
        writes[#writes + 1] = { frame = frame, key = key }
        fn(frame)
        return true
    end
    ns.Layout = { Snap = function(v) return v end }
    ns.P = { Scale = function(v) return v end }
    local soundSyncs = 0
    ns.Sound = { RequestAuraSync = function() soundSyncs = soundSyncs + 1 end }
    ns.MiliUIGlow = nil

    local list = DB.CustomList(true)
    for i = #list, 1, -1 do list[i] = nil end
    local iSlot = DB.AddCustom({ kind = "slot", slot = 13, bar = "essential" })
    local iSlot2 = DB.AddCustom({ kind = "slot", slot = 14, bar = "utility" })
    local sid = "c:" .. iSlot
    CU.Sync()
    local rec = CU.Get(sid)
    check("飾品欄 rec", rec and rec.kind == "slot" and rec.slot == 13)

    -- 判準（Catalog.SlotOverlayIDs）
    -- 冷卻格只認使用效果那個增益（暴雪 EquipSlotEssential 那一筆沒給 ⇒ 退第 1 個），不合併第 2 個（常是被動觸發）
    eqList("SlotOverlayIDs：只認第 1 個", (C.SlotOverlayIDs("essential", sid, 13)), { 1297761 })
    eq("SlotOverlayIDs：槽 14 沒東西 ⇒ 不疊", C.SlotOverlayIDs("utility", "c:" .. iSlot2, 14), nil)
    check("BarHasAuraSlot：有會疊增益的飾品欄 ⇒ 是", C.BarHasAuraSlot("essential"))
    check("BarHasAuraSlot：飾品欄沒東西 ⇒ 不是", not C.BarHasAuraSlot("utility"))

    local cont = Obj("Frame"); cont.level = 10
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 1)
    local o = rec.buffOverlay
    check("疊層：建了子 rec（光環格形狀、增益、overlayOf）", o and o.kind == "aura" and o.filter == "HELPFUL" and o.overlayOf == rec)
    local h = o and o.frame
    check("疊層：持有框", h ~= nil and h == o.holder)
    eq("疊層：持有框 parent ＝ 條容器", h and h:GetParent(), cont)
    eq("疊層：錨在條容器上（不是冷卻格）", h and h.last_SetPoint and h.last_SetPoint[2], cont)
    eq("疊層：同一個矩形（x）", h and h.last_SetPoint and h.last_SetPoint[4], 40)
    eq("疊層：尺寸", h and h.last_SetSize and h.last_SetSize[1], 36)
    eq("冷卻格：容器＋2", rec.frame:GetFrameLevel(), 12)
    eq("疊層：容器＋4（冷卻格的轉圈之上）", h and h:GetFrameLevel(), 14)
    check("疊層：在 Decorate 的 overlay（冷卻格＋10）底下", h and h:GetFrameLevel() < rec.frame:GetFrameLevel() + 10)
    local wroteHolder = false
    for _, w in ipairs(writes) do if w.frame == h then wroteHolder = true end end
    check("疊層：持有框的寫入走 ns.Write", wroteHolder)
    eq("冷卻格本身不是保護框的子框（持有框不是它的孩子）", h:GetParent() ~= rec.frame, true)
    local c = o.container
    check("疊層：建了容器", c and c.otype == "AuraContainer" and c.slot ~= nil)
    eq("疊層：容器 filter", c and c.slot.filter, "HELPFUL")
    local inc = c and c.slot.opts.candidateFilters.includeSpellIDs or {}
    check("疊層：includeSpellIDs ＝ 使用效果的增益（不含第 2 個）", inc[1297761] and not inc[1305376])
    check("疊層：簽章帶 ov 記號與增益 ID", o.sig and o.sig:find("^ov") and o.sig:find("1297761", 1, true))
    eq("鏡像：rec.buffOverlay.containers 是持有框的池", o.containers, h.containers)
    check("疊層：音效對帳", soundSyncs > 0)
    eq("Counts：疊層一顆", CU.Counts().overlays, 1)

    -- 外觀：增益那一段的顏色（預設 colorDuration 開、durationColor 黃）
    local btn = Obj("Frame", c)
    local got = {}
    function btn:SetIcon(t) got.icon = t end
    function btn:SetDurationCooldown(cd) got.cd = cd end
    function btn:SetDurationText(fs, opts) got.text, got.textOpts = fs, opts end
    function btn:SetApplicationCount(fs) got.count = fs end
    o.lastError = nil
    c.slot.opts.initializeFrame(btn)
    eq("initializeFrame 沒有錯誤", o.lastError, nil)
    local dc = ns.SpellSetting("essential", sid, "durationColor")
    check("倒數字色＝durationColor", got.text and got.text.color and dc and math.abs(got.text.color[1] - dc.r) < 1e-6
        and math.abs(got.text.color[2] - dc.g) < 1e-6)
    local sc = ns.SpellSetting("essential", sid, "durationSwipeColor")
    check("轉圈色＝durationSwipeColor", got.cd and got.cd.swipe and sc and math.abs(got.cd.swipe[4] - sc.a) < 1e-6
        and math.abs(got.cd.swipe[1] - sc.r) < 1e-6)
    -- 換色關掉 ⇒ 簽章變（換一顆容器）、字色回倒數原色
    local sig1 = o.sig
    DB.SpecSpells(true).overrides[sid] = { colorDuration = false }
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 2)
    check("換色關掉 ⇒ 簽章變、換容器", o.sig ~= sig1 and o.container ~= c)
    -- 隱藏倒數 ⇒ 不掛 SetDurationText
    DB.SpecSpells(true).overrides[sid] = { hideCooldownText = true }
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 3)
    local btn2 = Obj("Frame", o.container)
    local got2 = {}
    function btn2:SetIcon() end
    function btn2:SetDurationCooldown() end
    function btn2:SetDurationText(fs) got2.text = fs end
    function btn2:SetApplicationCount() end
    o.container.slot.opts.initializeFrame(btn2)
    eq("隱藏倒數 ⇒ 不掛 SetDurationText", got2.text, nil)

    -- 逐法術的文字覆寫（H）：疊層照冷卻格那一筆的 id 讀，值解進 st、進簽章 ⇒ 改了換一顆容器
    DB.SpecSpells(true).overrides[sid] = nil
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 5)
    local sigT0, contT0 = o.sig, o.container
    DB.SetOverride(sid, "cooldownTextSize", 22)
    DB.SetOverride(sid, "cooldownTextPoint", "BOTTOM")
    DB.SetOverride(sid, "stackTextColor", { r = 0, g = 1, b = 0, a = 1 })
    local stT = CU.AuraStyle(o, "essential", 36, 36, "icons")
    eq("文字覆寫：倒數字級", stT.cdSize, 22)
    eq("文字覆寫：倒數錨點", stT.cdPoint, "BOTTOM")
    eq("文字覆寫：沒覆寫的欄位退條層（倒數 X）", stT.cdX, tonumber(ns.Setting("essential", "cooldownText.x")) or 0)
    eq("文字覆寫：層數顏色", stT.stColor[2], 1)
    eq("文字覆寫：層數顏色（紅）", stT.stColor[1], 0)
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 6)
    check("文字覆寫 ⇒ 簽章變、換容器", o.sig ~= sigT0 and o.container ~= contT0)
    -- 長條形狀：秒數的底是「長條」節，覆寫蓋字級；錨點沒蓋 ⇒ 預設右緣；層數字級覆寫優先於條層
    DB.SetOverride(sid, "cooldownTextPoint", nil)
    DB.SetOverride(sid, "stackTextSize", 9)
    local stB = CU.AuraStyle(o, "essential", 120, 20, "bars")
    eq("長條：秒數字級吃覆寫", stB.timeSize, 22)
    eq("長條：秒數錨點預設右緣", stB.timePoint, "RIGHT")
    eq("長條：秒數預設內縮 4", stB.timeX, -4)
    eq("長條：層數字級覆寫優先", stB.barStack, 9)
    local sigB = stB.sig
    DB.SetOverride(sid, "cooldownTextX", 3)
    check("長條：秒數偏移進簽章", CU.AuraStyle(o, "essential", 120, 20, "bars").sig ~= sigB)
    for _, f in ipairs({ "cooldownTextSize", "cooldownTextX", "stackTextColor", "stackTextSize" }) do DB.SetOverride(sid, f, nil) end
    eq("右鍵清光 ⇒ 回條層字級", CU.AuraStyle(o, "essential", 36, 36, "icons").cdSize,
        tonumber(ns.Setting("essential", "cooldownText.size")) or 16)
    -- 自訂文字（M）：飾品冷卻格上的增益疊層是冷卻格 ⇒ 就算覆寫裡有字也不畫
    DB.SetOverride(sid, "labelText", "不畫")
    eq("疊層不解自訂文字", CU.AuraStyle(o, "essential", 36, 36, "icons").label, nil)
    DB.SetOverride(sid, "labelText", nil)

    -- 增益持續時間的小數與低秒變色（I）：疊層倒的是增益持續時間 ⇒ 預設沒有小數、低秒變色開在 5 秒（冷卻倒數的 3／5 不看）；
    -- 逐法術開了 ⇒ 小數與變色秒數照增益自己的（J：不借 lowBelow）、顏色＝增益持續時間低秒顏色；改了進簽章
    local stI = CU.AuraStyle(o, "essential", 36, 36, "icons")
    check("增益持續時間預設：0 小數、5 秒變色", stI.decimals == 0 and stI.lowBelow == 5)
    local sigI = stI.sig
    DB.SetOverride(sid, "buffDecimalsBelow", 2)
    DB.SetOverride(sid, "buffLowColor", true)
    DB.SetOverride(sid, "durationLowColor", { r = 0, g = 0, b = 1, a = 1 })
    DB.SetOverride(sid, "buffLowBelow", 8)
    stI = CU.AuraStyle(o, "essential", 36, 36, "icons")
    eq("逐法術：增益持續時間小數門檻", stI.decimals, 2)
    eq("逐法術：變色門檻＝增益持續時間自己的變色秒數", stI.lowBelow, 8)
    eq("逐法術：增益持續時間低秒顏色", stI.lowColor[3], 1)
    check("改了進簽章", stI.sig ~= sigI)
    for _, f in ipairs({ "buffDecimalsBelow", "buffLowColor", "durationLowColor", "buffLowBelow" }) do DB.SetOverride(sid, f, nil) end

    -- showAuraTime 關掉 ⇒ 不疊（持有框收起來、容器留在池裡）
    local pooled = 0
    for _ in pairs(h.containers) do pooled = pooled + 1 end
    DB.SpecSpells(true).overrides[sid] = { showAuraTime = false }
    eq("showAuraTime false ⇒ SlotOverlayIDs nil", C.SlotOverlayIDs("essential", sid, 13), nil)
    check("showAuraTime false ⇒ BarHasAuraSlot 不再因它成立", not C.BarHasAuraSlot("essential"))
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 4)
    eq("不疊 ⇒ 持有框收起來", h.shown, false)
    eq("不疊 ⇒ placedBar 清掉（音效撤）", o.placedBar, nil)
    local pooled2 = 0
    for _ in pairs(h.containers) do pooled2 = pooled2 + 1 end
    eq("不疊 ⇒ 容器留在池裡", pooled2, pooled)
    eq("Counts：不疊 ⇒ 0 顆", CU.Counts().overlays, 0)
    DB.SpecSpells(true).overrides[sid] = nil
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 5)
    eq("打開回來 ⇒ 持有框顯示", h.shown, true)

    -- 解不出增益（換成沒有使用效果的飾品）⇒ 不疊
    equipped[13] = 290000
    linked[801], linked[802] = nil, nil                -- 暴雪那邊跟著物品換：沒有增益項目
    C.InvalidateSlotBuffs()
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 6)
    eq("解不出增益 ⇒ 不疊", h.shown, false)

    -- 戰鬥中換成別的增益：只記旗標，容器不換；脫戰補建
    equipped[13] = 280000                              -- 暴雪沒有增益項目 ⇒ 退使用效果
    C.InvalidateSlotBuffs()
    local before = o.container
    local builds = CU.builds
    combat = true
    CU.Place(rec, cont, { x = 40, y = 0, w = 36, h = 36 }, "essential", 7)
    eq("戰鬥中：容器不換", o.container, before)
    eq("戰鬥中：沒建容器", CU.builds, builds)
    check("戰鬥中：記旗標", (CU.IsPending(o)))
    eqList("戰鬥中：要的法術已經是新的", o.auraIDs, { 1400000 })
    combat = false
    CU.OnRegen()
    check("脫戰：補建", CU.builds == builds + 1 and o.container ~= before)
    check("脫戰：新容器認新的增益", o.container.slot.opts.candidateFilters.includeSpellIDs[1400000] == true)
    check("脫戰：簽章帶新的 ID", o.sig:find("1400000", 1, true) ~= nil)
    check("脫戰：旗標清掉", not (CU.IsPending(o)))

    -- 搬到長條類的條：另一顆持有框（長條形）、層級＋8，舊的收起來
    local cont2 = Obj("Frame"); cont2.level = 20
    CU.Place(rec, cont2, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 8)
    local hb = o.frame
    check("長條：換一顆持有框", hb ~= h and o.shape == "bars")
    eq("長條：舊持有框收起來", h.shown, false)
    eq("長條：層級＝容器＋8", hb:GetFrameLevel(), 28)
    check("長條：簽章帶長條外觀", o.sig:find("|bars,", 1, true) ~= nil)

    -- 冷卻格收起來（這條這一輪沒放到）⇒ 疊層跟著收
    CU.EndBar("buffbars", 9)
    eq("收起來：冷卻格", rec.placedBar, nil)
    eq("收起來：疊層持有框", hb.shown, false)
    eq("收起來：疊層 placedBar", o.placedBar, nil)

    -- 不是飾品欄的不疊
    local iItem = DB.AddCustom({ kind = "item", itemID = 7, bar = "essential" })
    CU.Sync()
    local irec = CU.Get("c:" .. iItem)
    CU.Place(irec, cont, { x = 80, y = 0, w = 36, h = 36 }, "essential", 10)
    eq("自訂物品不疊", irec.buffOverlay, nil)

    -- AuraIDsOf：slotBuff（給之後的「飾品欄增益」種類用）
    eqList("AuraIDsOf：slotBuff 第 1 個", CU.AuraIDsOf({ slotBuff = { slot = 13, buff = 1 } }), { 1400000 })
    eqList("AuraIDsOf：slotBuff 第 2 個解不出 ⇒ 空", CU.AuraIDsOf({ slotBuff = { slot = 13, buff = 2 } }), {})
    eqList("AuraIDsOf：auraIDs 優先", CU.AuraIDsOf({ auraIDs = { 5, 6 }, spellID = 1 }), { 5, 6 })

    ------------------------------------------------------------
    -- 14. 代畫暴雪缺框的裝備欄冷卻格（B）：Bars.Relayout 放 Custom.Proxy、IsMissing／IsProxied、[proxy] 稽核、
    --     暴雪恢復給框就收起來、Sync 不誤殺、事件照聽、Occupancy、BarHasAuraSlot 認得代畫格（不管有沒有框）
    ------------------------------------------------------------
    do
        -- 核心技能清單：11、12（一般法術）＋198603（飾品的冷卻格：equipSlot 13，玩家拖進核心）
        local savedInfo2 = CV.GetCooldownViewerCooldownInfo
        local savedSet0 = SETS[0]
        SETS[0] = { 11, 12, 198603 }
        CV.GetCooldownViewerCooldownInfo = function(id)
            if id == 198603 then
                return { cooldownID = id, spellID = 1297761, category = 0, equipSlot = 13, isKnown = true, flags = 0 }
            end
            return savedInfo2(id)
        end
        C.Refresh("test")
        local savedB, savedLayout, savedStyle, savedViewers, savedDiag, savedP = ns.Bars, ns.Layout, ns.Style, ns.Viewers, ns.Diag, ns.P
        local notes = {}
        ns.Diag = { Note = function(kind, text) notes[#notes + 1] = "[" .. kind .. "] " .. text end }
        ns.Style = { ApplyPanel = function() end }
        ns.P = { Scale = function(v) return v end }
        ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {}, EnsureScale = function() end,
                       Get = function() return nil end }
        ns.Decorate.ApplyItemAlpha = function() end
        load("Core/Layout.lua")
        load("Core/Bars.lua")
        local B = ns.Bars

        eq("ProxySlotOf：飾品冷卻格 ⇒ 槽", C.ProxySlotOf(198603), 13)
        eq("ProxySlotOf：一般法術 ⇒ nil", C.ProxySlotOf(12), nil)
        eq("ProxySlotOf：自訂項目 ⇒ nil", C.ProxySlotOf(sid), nil)

        local item11 = Obj("Frame")
        ns.Viewers.frames[item11] = { barKey = "essential", cooldownID = 11 }
        local index = { [11] = item11 }              -- 12 與 198603 暴雪都沒給框
        B.Relayout("essential", 2, index, 100)
        eq("缺框的一般法術照舊算 missing", B.IsMissing("essential", 12), true)
        eq("缺框的飾品冷卻格不算 missing", B.IsMissing("essential", 198603), false)
        eq("IsProxied：槽 13", B.IsProxied("essential", 198603), 13)
        eq("IsProxied：一般法術不代畫", B.IsProxied("essential", 12), nil)
        local prx = CU.Proxies()[198603]
        check("代畫 rec：飾品欄形狀、暴雪的數字 id", prx and prx.proxy and prx.kind == "slot" and prx.slot == 13
            and prx.cooldownID == 198603 and prx.custom)
        eq("代畫 rec：放在核心", prx and prx.placedBar, "essential")
        eq("代畫 rec：bar ＝ 放的那條", prx and prx.bar, "essential")
        eq("代畫 rec：不進 byId", CU.Get(198603), nil)
        eq("代畫 rec：一般法術沒有代畫", CU.Proxies()[12], nil)
        check("代畫 rec：增益疊層照疊（cooldownID 是數字 id）", prx and prx.buffOverlay and prx.buffOverlay.placedBar == "essential")
        eq("Counts：代畫 1 顆", CU.Counts().proxy, 1)
        local proxyNote = false
        for _, n in ipairs(notes) do if n:find("[proxy] essential：代畫 198603（槽13）", 1, true) then proxyNote = true end end
        check("稽核：記 [proxy]", proxyNote, table.concat(notes, " / "))
        local before = #notes
        B.Relayout("essential", 2, index, 101)
        eq("稽核：沒變不重記", #notes, before)
        eq("同一顆 rec（池化）", CU.Proxies()[198603], prx)
        check("事件：代畫格算進生效清單", CU.LiveRecs()[198603] == prx)
        local occ = B.Occupancy(index)
        eq("Occupancy：代畫格佔一格", occ("essential", 198603), true)
        eq("Occupancy：缺框的一般法術不佔", occ("essential", 12), false)

        -- Sync 不能誤殺（代畫不在生效清單裡）
        CU.Sync()
        eq("Sync 之後：代畫格還在條上", prx.placedBar, "essential")
        eq("Sync 之後：cooldownID 還在", prx.cooldownID, 198603)

        -- BarHasAuraSlot：自訂飾品欄關掉增益持續時間之後，代畫格（不管有沒有框）照樣讓核心強制固定格位
        local ovs = DB.SpecSpells(true).overrides
        ovs[sid] = { showAuraTime = false }
        check("BarHasAuraSlot：代畫格會疊增益 ⇒ 是", C.BarHasAuraSlot("essential"))
        ovs[198603] = { showAuraTime = false }
        check("BarHasAuraSlot：代畫格也關掉增益持續時間 ⇒ 不是", not C.BarHasAuraSlot("essential"))
        ovs[198603] = nil
        check("BarHasAuraSlot：輔助沒有裝備欄冷卻格", not C.BarHasAuraSlot("utility"))

        -- 暴雪恢復給框：這一輪放暴雪的 item，代畫格收起來
        local item603 = Obj("Frame")
        local rec603 = { barKey = "essential", cooldownID = 198603 }
        ns.Viewers.frames[item603] = rec603
        index[198603] = item603
        B.Relayout("essential", 2, index, 102)
        eq("給框之後：不算代畫", B.IsProxied("essential", 198603), nil)
        eq("給框之後：也不算 missing", B.IsMissing("essential", 198603), false)
        eq("給框之後：暴雪的 item 放進核心", rec603.claimKey, "essential")
        eq("給框之後：代畫格收起來", prx.placedBar, nil)
        eq("給框之後：疊層跟著收", prx.buffOverlay.placedBar, nil)
        eq("給框之後：事件不再算它", CU.LiveRecs()[198603], nil)
        eq("Counts：代畫 0 顆", CU.Counts().proxy, 0)
        eq("缺框的一般法術仍是 missing", B.IsMissing("essential", 12), true)
        ovs[sid] = nil

        ns.Bars, ns.Layout, ns.Style, ns.Viewers, ns.Diag, ns.P = savedB, savedLayout, savedStyle, savedViewers, savedDiag, savedP
        ns.Decorate.ApplyItemAlpha = nil
        CV.GetCooldownViewerCooldownInfo = savedInfo2
        SETS[0] = savedSet0
        C.Refresh("test")
    end

    ------------------------------------------------------------
    -- 15. 飾品欄增益（C，kind "slotbuff"）：身分、驗證、重複、範圍搬移；Catalog.Info（問號格）；引擎當光環格
    --     （第幾個增益認不同的法術、占位用飾品圖示、換飾品換容器、戰鬥中只記旗標、存了第 3 個而這件只有 1 個不報錯）；
    --     BarHasAuraSlot／IsAuraSlot；SlotBuffTooltip（標題、每個增益一段、資料沒載入時等載完、序號擋舊的）
    ------------------------------------------------------------
    do
        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
        equipped[13], equipped[14] = 270175, nil
        linked[801] = { 13, 1, { 1297761 } }
        linked[802] = { 13, 2, { 1305376 } }
        C.InvalidateSlotBuffs()

        -- 身分與驗證
        eq("身分：slotbuff:13:2", DB.CustomIdentity({ kind = "slotbuff", slot = 13, buff = 2 }), "slotbuff:13:2")
        eq("身分：buff 缺 ＝ 1", DB.CustomIdentity({ kind = "slotbuff", slot = 13 }), "slotbuff:13:1")
        check("ValidCustom：槽 13 buff 5（不設上限）", C.ValidCustom({ kind = "slotbuff", slot = 13, buff = 5 }))
        check("ValidCustom：buff 缺也收", C.ValidCustom({ kind = "slotbuff", slot = 14 }))
        check("ValidCustom：不是飾品欄的槽不收", not C.ValidCustom({ kind = "slotbuff", slot = 1, buff = 1 }))
        check("ValidCustom：buff 0 不收", not C.ValidCustom({ kind = "slotbuff", slot = 13, buff = 0 }))
        check("ValidCustom：buff 1.5 不收", not C.ValidCustom({ kind = "slotbuff", slot = 13, buff = 1.5 }))
        eq("AddCustom：不是飾品欄的槽 ⇒ nil", DB.AddCustom({ kind = "slotbuff", slot = 16, buff = 1, bar = "buffs" }), nil)
        local i1 = DB.AddCustom({ kind = "slotbuff", slot = 13, buff = 1, placeholder = true, bar = "buffs" })
        local i2 = DB.AddCustom({ kind = "slotbuff", slot = 13, buff = 2, placeholder = true, bar = "buffs" })
        local i3 = DB.AddCustom({ kind = "slotbuff", slot = 13, buff = 3, placeholder = true, bar = "buffs" })
        check("AddCustom：三筆", i1 and i2 and i3)
        eq("FindCustom：槽＋第幾個", DB.FindCustom("slotbuff", 13, 2), i2)
        eq("FindCustom：第 4 個沒有", DB.FindCustom("slotbuff", 13, 4), nil)
        eq("FindCustomLike：同槽同 buff", DB.FindCustomLike({ kind = "slotbuff", slot = 13, buff = 3 }), i3)
        eq("FindCustomLike：別的槽不算", DB.FindCustomLike({ kind = "slotbuff", slot = 14, buff = 1 }), nil)
        check("重複：這個專精看得到同槽同 buff", DB.FindEffective({ kind = "slotbuff", slot = 13, buff = 1 }) ~= nil)
        check("重複：第 4 個不算", DB.FindEffective({ kind = "slotbuff", slot = 13, buff = 4 }) == nil)
        check("重複：跟飾品欄（冷卻格）不混", DB.FindEffective({ kind = "slot", slot = 13 }) == nil)

        -- Catalog.Info：光環格形狀、飾品圖示、「飾品名（增益 N）」；第 3 個這件沒有 ⇒ 問號格
        local id1, id2, id3 = "c:" .. i1, "c:" .. i2, "c:" .. i3
        local inf1 = C.Info(id1)
        check("Info：kind aura＋slotBuff", inf1 and inf1.kind == "aura" and inf1.slotBuff and inf1.slotBuff.slot == 13
            and inf1.slotBuff.buff == 1)
        eq("Info：圖示＝飾品圖示", inf1 and inf1.icon, 800000 + 270175)
        eq("Info：名字", inf1 and inf1.name, "物品270175 (buff 1)")
        eq("Info：spellID ＝ 第 1 個增益", inf1 and inf1.spellID, 1297761)
        eq("Info：解得出 ⇒ isKnown", inf1 and inf1.isKnown, true)
        local inf3 = C.Info(id3)
        eq("Info：第 3 個這件沒有 ⇒ isKnown false", inf3 and inf3.isKnown, false)
        eq("Info：第 3 個 ⇒ 問號", inf3 and inf3.icon, 134400)
        check("IsAuraSlot：飾品欄增益算", C.IsAuraSlot(id1))
        check("BarHasAuraSlot：增益圖示列有飾品欄增益", C.BarHasAuraSlot("buffs"))
        eqList("清單：照順序列在增益圖示列", C.Bar("buffs"), { 31, 32, id1, id2, id3 })

        -- 引擎：光環格那一套
        CU.Sync()
        local r1, r2, r3 = CU.Get(id1), CU.Get(id2), CU.Get(id3)
        check("rec：光環格（kind aura、HELPFUL、slotBuff）", r1 and r1.kind == "aura" and r1.filter == "HELPFUL"
            and r1.slotBuff and r1.slotBuff.buff == 1)
        check("rec：三個 buff 各一顆（身分不同）", r1 ~= r2 and r2 ~= r3)
        local bc = Obj("Frame"); bc.level = 30
        CU.Place(r1, bc, { x = 0, y = 0, w = 36, h = 36 }, "buffs", 20)
        CU.Place(r2, bc, { x = 40, y = 0, w = 36, h = 36 }, "buffs", 20)
        local ok3, err3 = pcall(CU.Place, r3, bc, { x = 80, y = 0, w = 36, h = 36 }, "buffs", 20)
        check("存了第 3 個、這件只有 2 個：放格不報錯", ok3, err3)
        local inc1 = r1.container and r1.container.slot.opts.candidateFilters.includeSpellIDs or {}
        local inc2 = r2.container and r2.container.slot.opts.candidateFilters.includeSpellIDs or {}
        check("buff 1：容器只認第 1 個增益", inc1[1297761] and not inc1[1305376])
        check("buff 2：容器只認第 2 個增益", inc2[1305376] and not inc2[1297761])
        eq("buff 2：rec.spellID ＝ 第 2 個增益", r2.spellID, 1305376)
        eq("buff 3：解不出 ⇒ 不建容器", r3.container, nil)
        eq("buff 3：持有框照放（位置照佔）", r3.frame and r3.frame.shown, true)
        local ph3 = r3.frame and r3.frame.ph
        eq("buff 3：占位用飾品圖示", ph3 and ph3.tex.last_SetTexture and ph3.tex.last_SetTexture[1], 800000 + 270175)
        eq("buff 3：占位顯示", ph3 and ph3.frame.shown, true)
        eq("buff 3：占位是條容器的子框（不在持有框上）", ph3 and ph3.frame:GetParent(), bc)
        -- 增益不在時：隱藏（保留空位）⇒ 占位不畫、持有框照放；改回來占位回來
        r3.entry.hideMissing = true
        CU.Place(r3, bc, { x = 80, y = 0, w = 36, h = 36 }, "buffs", 20)
        eq("hideMissing：占位藏起來", ph3 and ph3.frame.shown, false)
        eq("hideMissing：持有框照放（格子照留）", r3.frame and r3.frame.shown, true)
        r3.entry.hideMissing = nil
        CU.Place(r3, bc, { x = 80, y = 0, w = 36, h = 36 }, "buffs", 20)
        eq("hideMissing 清掉：占位回來", ph3 and ph3.frame.shown, true)
        eq("buff 1：持有框 parent ＝ 條容器", r1.frame:GetParent(), bc)

        -- 換飾品（脫戰）：buff 1 換成新飾品的使用效果、換容器；buff 2 這件沒有 ⇒ 舊容器收起來
        local c1, c2, s1 = r1.container, r2.container, r1.sig
        equipped[13] = 280000
        linked[801], linked[802] = nil, nil
        C.InvalidateSlotBuffs()
        CU.Place(r1, bc, { x = 0, y = 0, w = 36, h = 36 }, "buffs", 21)
        CU.Place(r2, bc, { x = 40, y = 0, w = 36, h = 36 }, "buffs", 21)
        eq("換飾品：buff 1 的 spellID", r1.spellID, 1400000)
        check("換飾品：buff 1 簽章變、換容器", r1.sig ~= s1 and r1.container ~= c1)
        check("換飾品：新容器認新的增益", r1.container.slot.opts.candidateFilters.includeSpellIDs[1400000] == true)
        eq("換飾品：buff 2 解不出 ⇒ 容器拿掉", r2.container, nil)
        eq("換飾品：buff 2 的舊容器收起來", c2.shown, false)
        eq("換飾品：Info buff 2 變問號", C.Info(id2).isKnown, false)

        -- 戰鬥中換回來：只記旗標，脫戰建
        equipped[13] = 270175
        linked[801] = { 13, 1, { 1297761 } }
        linked[802] = { 13, 2, { 1305376 } }
        C.InvalidateSlotBuffs()
        local b0 = CU.builds
        combat = true
        CU.Place(r2, bc, { x = 40, y = 0, w = 36, h = 36 }, "buffs", 22)
        eq("戰鬥中：不建容器", CU.builds, b0)
        check("戰鬥中：記旗標", (CU.IsPending(r2)))
        combat = false
        CU.OnRegen()
        check("脫戰：補建（buff 2 回來）", r2.container ~= nil
            and r2.container.slot.opts.candidateFilters.includeSpellIDs[1305376] == true)

        -- 空格：Info 問號、占位用欄位空格圖（沒有 API 就問號）、不報錯
        equipped[13] = nil
        C.InvalidateSlotBuffs()
        eq("空格：Info 問號", C.Info(id1).isKnown, false)
        local okE = pcall(CU.Place, r1, bc, { x = 0, y = 0, w = 36, h = 36 }, "buffs", 23)
        check("空格：放格不報錯", okE)
        equipped[13] = 270175
        C.InvalidateSlotBuffs()

        -- 範圍搬移：專精 → 戰隊（新 id）；戰隊已經有同身分 ⇒ exists
        local nid = DB.MoveCustomScope(id3, "shared")
        check("範圍搬移：新 id 在戰隊層", nid and DB.ParseCustomID(nid) == "shared")
        eq("範圍搬移：戰隊層找得到", DB.FindInScope("shared", { kind = "slotbuff", slot = 13, buff = 3 }) ~= nil, true)
        local i3b = DB.AddCustom({ kind = "slotbuff", slot = 13, buff = 3, bar = "buffs" })
        local _, why = DB.MoveCustomScope("c:" .. i3b, "shared")
        eq("範圍搬移：目標層已經有 ⇒ exists", why, "exists")
        p.customShared = nil
        DB.TouchCustom()

        -- 滑鼠提示（Catalog.SlotBuffTooltip）
        local function FakeTip(owner)
            local t = { lines = {}, shown = true, owner = owner, textures = 0 }
            function t:SetText(txt, r, g, b) self.title = { txt, r, g, b }; self.lines = {} end
            function t:AddLine(txt, r, g, b, wrap, off) self.lines[#self.lines + 1] = { txt, r, g, b, wrap, off } end
            function t:AddTexture() self.textures = self.textures + 1 end
            function t:GetOwner() return self.owner end
            function t:IsShown() return self.shown end
            return t
        end
        local function Has(t, txt)
            for _, l in ipairs(t.lines) do if l[1] == txt then return true end end
            return false
        end
        env.C_Item.GetItemQualityByID = function() return 4 end
        env.C_Item.GetItemQualityColor = function() return 0.64, 0.21, 0.93 end
        env.C_Spell.GetSpellDescription = function(id) return "說明" .. id end
        local cached = { [1297761] = true, [1305376] = true }
        local waiting = {}
        env.Spell = {
            CreateFromSpellID = function(_, id)
                return {
                    IsSpellDataCached = function() return cached[id] == true end,
                    ContinueOnSpellLoad = function(_, fn) waiting[#waiting + 1] = fn end,
                    GetSpellDescriptionForItemLocation = function(_, loc) return "裝等說明" .. id .. "@" .. tostring(loc and loc.slot) end,
                }
            end,
        }
        env.ItemLocation = { CreateFromEquipmentSlot = function(_, slot) return { slot = slot } end }
        local owner = Obj("Frame")
        local tip = FakeTip(owner)
        C.SlotBuffTooltip(tip, 13, 2)
        eq("提示：標題＝飾品名", tip.title and tip.title[1], "物品270175")
        eq("提示：標題品質色", tip.title and tip.title[2], 0.64)
        check("提示：增益名", Has(tip, "法術1305376"))
        check("提示：照裝備等級算過的說明（ItemLocation 是那一格）", Has(tip, "裝等說明1305376@13"))
        check("提示：只畫第 2 個增益", not Has(tip, "法術1297761"))
        check("提示：增益標籤", Has(tip, "Buff 2"))
        eq("提示：一個增益一個圖示", tip.textures, 1)
        local all = FakeTip(owner)
        C.SlotBuffTooltip(all, 13, nil)
        check("提示：buff nil ＝ 全部增益", Has(all, "法術1297761") and Has(all, "法術1305376")
            and Has(all, "Buff 1") and Has(all, "Buff 2"))
        local none = FakeTip(owner)
        C.SlotBuffTooltip(none, 13, 3)
        check("提示：第 3 個這件沒有 ⇒ 原因", Has(none, "This trinket has no buff to track."))
        equipped[14] = nil
        local empty = FakeTip(owner)
        C.SlotBuffTooltip(empty, 14, 1)
        check("提示：空格 ⇒ 欄位名＋（空的）", Has(empty, "(empty)"))
        -- 資料沒載入：只畫標題、等載完；提示還開著、同一個擁有者、中間沒被蓋過才刷
        cached[1305376] = false
        local refreshed = 0
        local lt = FakeTip(owner)
        C.SlotBuffTooltip(lt, 13, 2, function() refreshed = refreshed + 1 end)
        eq("沒載入：只有標題", #lt.lines, 0)
        eq("沒載入：等一個", #waiting, 1)
        waiting[1]()
        eq("載完：刷新一次", refreshed, 1)
        C.SlotBuffTooltip(lt, 13, 2, function() refreshed = refreshed + 100 end)
        eq("沒載入：又等一個", #waiting, 2)
        local stale = waiting[2]
        C.SlotBuffTooltip(lt, 13, 1, function() refreshed = refreshed + 1000 end)   -- 同一顆擁有者換成別的內容
        stale()
        eq("被蓋過的舊等待不刷", refreshed, 1)
        C.SlotBuffTooltip(lt, 13, 2, function() refreshed = refreshed + 10 end)
        lt.shown = false
        waiting[#waiting]()
        eq("提示關了不刷", refreshed, 1)
        lt.shown, lt.owner = true, Obj("Frame")
        waiting[#waiting]()
        eq("擁有者換了不刷", refreshed, 1)
        env.Spell, env.ItemLocation = nil, nil
        env.C_Item.GetItemQualityByID, env.C_Item.GetItemQualityColor, env.C_Spell.GetSpellDescription = nil, nil, nil

        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
    end

    ------------------------------------------------------------
    -- 16. 光環格的 Masque（E）：占位是條容器上的獨立框（米利／Masque 都是）、探針（Masque 模式才建、看不見、錨容器、
    --     regions＝Icon＋Normal）、讀回形狀與皮外框進簽章、按鈕烘遮罩＋自己畫皮外框（不畫米利邊）、外框讀不到 ⇒ 米利 1px 邊、
    --     皮沒有外框 ⇒ 兩種都不畫、Icon 讀不到 ⇒ 方形、群組停用 ⇒ 米利、收起來一起收、
    --     飾品冷卻格疊層照冷卻格的皮讀形狀（不建探針、不畫外框）、戰鬥中只記旗標、ReadShape 的錨點換算與秘密值
    ------------------------------------------------------------
    do
        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
        local phCalls = {}
        ns.Decorate.ApplyPlaceholder = function(...)
            phCalls[#phCalls + 1] = { n = select("#", ...), ... }
        end
        -- 跑一次 initializeFrame，抓按鈕底下建的 Cooldown 與 ov
        local function RunInit(container)
            local btn = Obj("Frame", container)
            local got = { frames = {} }
            function btn:SetIcon(t) got.icon = t end
            function btn:SetDurationCooldown(cd) got.cd = cd end
            function btn:SetDurationText(fs) got.text = fs end
            function btn:SetApplicationCount(fs) got.count = fs end
            local cf = env.CreateFrame
            env.CreateFrame = function(otype, name, parent, tmpl)
                local f = cf(otype, name, parent, tmpl)
                if parent == btn then got.frames[#got.frames + 1] = f end
                return f
            end
            container.slot.opts.initializeFrame(btn)
            env.CreateFrame = cf
            for _, f in ipairs(got.frames) do
                if f.otype == "Frame" and not got.ov then got.ov = f end
            end
            got.btn = btn
            -- 按鈕本體上除了圖示以外的貼圖 ＝ 皮外框
            for _, t in ipairs(btn.texs or {}) do
                if t ~= got.icon then got.normal = t end
            end
            return got
        end

        -- 新的法術 ID：前面幾節放過的光環格（700）的框是別一版假框建的，池化會拿回同一顆
        local ia = DB.AddCustom({ kind = "aura", spellID = 710, filter = "HELPFUL", placeholder = true, bar = "buffs" })
        CU.Sync()
        local ar = CU.Get("c:" .. ia)
        local bc = Obj("Frame"); bc.level = 40
        local R = { x = 8, y = 0, w = 36, h = 36 }

        -- (a) 沒裝 Masque（ns.Masque nil）：占位是獨立框、沒有探針、簽章沒有 Masque 那段、按鈕畫米利邊
        local savedM = ns.Masque
        ns.Masque = nil
        CU.Place(ar, bc, R, "buffs", 30)
        local hd = ar.frame
        local ph = hd.ph
        check("占位：獨立框（不是持有框）", ph and ph.frame ~= hd and ph.tex ~= nil)
        eq("占位：parent ＝ 條容器", ph and ph.frame:GetParent(), bc)
        eq("占位：錨條容器（不錨持有框）", ph and ph.frame.last_SetPoint and ph.frame.last_SetPoint[2], bc)
        eq("占位：同一個矩形（x）", ph and ph.frame.last_SetPoint[4], 8)
        eq("占位：層級＝容器（持有框底下）", ph and ph.frame:GetFrameLevel(), 40)
        check("占位：持有框在它上面", hd:GetFrameLevel() > ph.frame:GetFrameLevel())
        eq("占位：去飽和 0.35", ph and ph.tex.last_SetAlpha and ph.tex.last_SetAlpha[1], 0.35)
        eq("占位：圖示", ph and ph.tex.file, 900710)
        local pc = phCalls[#phCalls]
        check("占位：交給 Decorate.ApplyPlaceholder（五個參數，沒有 noMasque）", pc and pc[1] == ph and pc[2] == "buffs" and pc.n == 5)
        eq("沒裝 Masque：沒有探針", hd.skin, nil)
        check("沒裝 Masque：簽章沒有 Masque 那段", ar.sig and not ar.sig:find("msq:", 1, true))
        local g0 = RunInit(ar.container)
        eq("米利：圖示整格", g0.icon and g0.icon.points[1] and g0.icon.points[1][1], "TOPLEFT")
        eq("米利：圖示 ARTWORK", g0.icon and g0.icon.layer, "ARTWORK")
        eq("米利：沒有遮罩", g0.icon and g0.icon.masks, nil)
        eq("米利：方形轉圈", g0.cd and g0.cd.swipeTex, "Interface\\BUTTONS\\WHITE8X8")
        eq("米利：按鈕畫 1px 邊（四條）", g0.ov and g0.ov.texCount, 4)
        eq("米利：沒有皮外框", g0.normal, nil)
        local sigMili = ar.sig

        -- (b) 裝了 Masque、這條是米利模式：跟沒裝一樣
        -- 假 Masque：照它的做法——Icon 改尺寸／錨點／texcoord、圓形皮掛遮罩；皮外框另建一張（把我們給的 Normal 藏起來），
        -- GetNormal 回那一張
        local fakeM = { mode = "miliui", active = true, gen = 0, syncs = 0, released = 0, normalMode = "draw" }
        local NORMAL_ATLAS = "UI-HUD-ActionBar-IconFrame"
        local function Skin(button, regions, w, h)
            local icon = regions.Icon
            if regions.Normal then
                regions.Normal:SetAlpha(0); regions.Normal:Hide()
                local nt = button.msqNormal
                if not nt then nt = button:CreateTexture(); button.msqNormal = nt end
                nt:SetAtlas(fakeM.normalMode == "none" and nil or NORMAL_ATLAS)
                nt:SetAlpha(1)
                if fakeM.normalMode == "none" then nt:Hide() else nt:Show() end
                nt:SetSize(w * 1.1, h * 1.1)
                nt:ClearAllPoints()
                nt:SetPoint("CENTER", button, "CENTER", 0, 0)
                nt:SetVertexColor(0.5, 0.6, 0.7, 0.8)
                nt:SetBlendMode("BLEND")
                nt:SetDrawLayer("ARTWORK", 1)
            end
            if fakeM.unknownAnchor then
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", Obj("Frame"), "CENTER", 0, 0)     -- 錨在讀不懂的框上
                icon:SetSize(w, h)
                return
            end
            icon:ClearAllPoints()
            icon:SetSize(w * 0.9, h * 0.9)
            icon:SetPoint("CENTER", button, "CENTER", 1, -1)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if fakeM.round and not icon.masks then
                local m = button:CreateMaskTexture()
                m:SetTexture("Interface\\AddOns\\Masque\\Textures\\Circle\\Mask")
                m:SetAllPoints(icon)
                icon:AddMaskTexture(m)
            end
        end
        fakeM.Mode = function() return fakeM.mode end
        fakeM.TypeFor = function() return "Debuff" end
        fakeM.Generation = function() return fakeM.gen end
        fakeM.GetNormal = function(b)
            if fakeM.normalMode == "unreadable" then return nil end
            return b.msqNormal
        end
        fakeM.Release = function(holder) holder.msqButton = nil; fakeM.released = fakeM.released + 1 end
        fakeM.Sync = function(holder, button, regions, btype, w, hh)
            fakeM.syncs = fakeM.syncs + 1
            fakeM.lastType, fakeM.lastRegions = btype, regions
            holder.msqButton, holder.msqSize = button, tostring(w) .. "x" .. tostring(hh)
            Skin(button, regions, w, hh)
            return fakeM.active
        end
        ns.Masque = fakeM
        CU.Place(ar, bc, R, "buffs", 31)
        eq("米利模式：不建探針", hd.skin, nil)
        eq("米利模式：不交給 Masque", fakeM.syncs, 0)
        eq("米利模式：簽章不變", ar.sig, sigMili)

        -- (c) Masque 模式、圓形皮：探針、形狀＋皮外框進簽章、按鈕烘遮罩＋自己畫外框、不畫米利邊
        fakeM.mode, fakeM.round = "masque", true
        local builds = CU.builds
        CU.Place(ar, bc, R, "buffs", 32)
        local L = hd.skin
        check("Masque：建了探針", L and L.frame and L.icon and L.normal)
        eq("探針：看不見（框 alpha 0）", L and L.frame.alpha, 0)
        eq("探針：parent ＝ 條容器", L and L.frame:GetParent(), bc)
        eq("探針：錨條容器（不錨持有框）", L and L.frame.last_SetPoint and L.frame.last_SetPoint[2], bc)
        eq("探針：同一個矩形（寬）", L and L.frame.w, 36)
        eq("探針：不吃滑鼠", L and L.frame.last_EnableMouse and L.frame.last_EnableMouse[1], false)
        check("探針：regions ＝ Icon＋Normal（我們建的）", fakeM.lastRegions and fakeM.lastRegions.Icon == L.icon
            and fakeM.lastRegions.Normal == L.normal)
        eq("探針：Icon 透明但不是 alpha 0（顏色 0,0,0,0）", L and L.icon.last_SetColorTexture and L.icon.last_SetColorTexture[4], 0)
        eq("探針：型別照 TypeFor", fakeM.lastType, "Debuff")
        check("持有框沒有錨在探針上", hd.last_SetPoint and hd.last_SetPoint[2] == bc)
        local pc2 = phCalls[#phCalls]
        check("Masque：占位照樣交給 ApplyPlaceholder（五個參數）", pc2 and pc2[1] == ph and pc2.n == 5)
        check("Masque：hd.msqOn", hd.msqOn == true)
        local m = hd.msqShape
        check("讀回形狀：圖示 0.9 倍、偏移 (1,-1)", m and math.abs(m.iw - 32.4) < 1e-6 and m.ix == 1 and m.iy == -1)
        check("讀回形狀：texcoord", m and math.abs(m.l - 0.07) < 1e-6 and math.abs(m.b - 0.93) < 1e-6)
        check("讀回形狀：遮罩（檔案、跟圖示同一個矩形）", m and m.mask and m.mask.file == "Interface\\AddOns\\Masque\\Textures\\Circle\\Mask"
            and math.abs(m.mask.w - 32.4) < 1e-6 and m.mask.x == 1)
        local nm = m and m.normal
        check("讀回皮外框：GetNormal 那張（不是我們給的）的圖集、尺寸、中心", nm and nm.atlas == NORMAL_ATLAS
            and math.abs(nm.w - 39.6) < 1e-6 and nm.x == 0)
        check("讀回皮外框：顏色、blend、draw layer", nm and nm.cr == 0.5 and math.abs(nm.ca - 0.8) < 1e-6 and nm.blend == "BLEND"
            and nm.layer == "ARTWORK" and nm.sub == 1)
        check("簽章帶 Masque、遮罩與皮外框", ar.sig:find("msq:", 1, true) and ar.sig:find("Circle", 1, true)
            and ar.sig:find(NORMAL_ATLAS, 1, true) and not ar.sig:find("+edge", 1, true))
        check("簽章變了 ⇒ 換一顆容器", ar.sig ~= sigMili and CU.builds == builds + 1)
        local st = CU.AuraStyle(ar, "buffs", 36, 36, "icons")
        check("AuraStyle：noEdge、msq、normal", st.noEdge == true and st.msq == m and st.normal == nm)
        local g1 = RunInit(ar.container)
        eq("Masque：按鈕不畫米利邊", g1.ov and g1.ov.texCount, 0)
        eq("Masque：圖示 BACKGROUND", g1.icon and g1.icon.layer, "BACKGROUND")
        eq("Masque：圖示尺寸照讀回來的", g1.icon and g1.icon.w, m.iw)
        eq("Masque：圖示錨中心＋偏移", g1.icon and g1.icon.points[1] and g1.icon.points[1][4], 1)
        eq("Masque：texcoord", g1.icon and g1.icon.tc and g1.icon.tc[1], m.l)
        local bm = g1.icon and g1.icon.masks and g1.icon.masks[1]
        check("Masque：圖示掛上遮罩（按鈕上的新遮罩貼圖）", bm and bm.otype == "MaskTexture" and bm.parent == g1.btn
            and bm.file == m.mask.file and bm.w == m.mask.w)
        eq("Masque：轉圈材質＝遮罩那張", g1.cd and g1.cd.swipeTex, m.mask.file)
        eq("Masque：轉圈排在遮罩的矩形", g1.cd and g1.cd.w, m.mask.w)
        local bn = g1.normal
        check("Masque：皮外框畫在按鈕本體（不是 ov）", bn and bn.parent == g1.btn)
        check("Masque：皮外框照讀回來的（圖集、尺寸、顏色、blend、層）", bn and bn.atlas == NORMAL_ATLAS and bn.w == nm.w
            and bn.vc and bn.vc[1] == 0.5 and bn.blend == "BLEND" and bn.layer == "ARTWORK" and bn.sub == 1)
        check("Masque：倒數／層數的 ov 是比按鈕高的子框（文字在外框上面）", g1.ov and g1.ov.level > g1.btn.level)
        CU.Place(ar, bc, R, "buffs", 33)
        eq("同簽章：不換容器", CU.builds, builds + 1)

        -- (d) 皮外框讀不到（GetNormal 沒有）⇒ 退回米利 1px 邊；遮罩照樣烘
        fakeM.normalMode = "unreadable"
        fakeM.gen = fakeM.gen + 1
        CU.Place(ar, bc, R, "buffs", 34)
        eq("外框讀不到 ⇒ normal nil", hd.msqShape and hd.msqShape.normal, nil)
        check("外框讀不到 ⇒ 簽章 +edge", ar.sig:find("+edge", 1, true) ~= nil)
        local g4 = RunInit(ar.container)
        eq("外框讀不到 ⇒ 米利 1px 邊（四條）", g4.ov and g4.ov.texCount, 4)
        eq("外框讀不到 ⇒ 沒有皮外框", g4.normal, nil)
        check("外框讀不到 ⇒ 遮罩照樣", g4.icon and g4.icon.masks and #g4.icon.masks == 1)

        -- (e) 這張皮沒有外框（Normal 藏著）⇒ 兩種邊都不畫
        fakeM.normalMode = "none"
        fakeM.gen = fakeM.gen + 1
        CU.Place(ar, bc, R, "buffs", 35)
        eq("皮沒有外框 ⇒ normal false", hd.msqShape and hd.msqShape.normal, false)
        check("皮沒有外框 ⇒ 簽章 N:none", ar.sig:find("N:none", 1, true) ~= nil)
        local g5 = RunInit(ar.container)
        eq("皮沒有外框 ⇒ 不畫米利邊", g5.ov and g5.ov.texCount, 0)
        eq("皮沒有外框 ⇒ 不畫皮外框", g5.normal, nil)
        fakeM.normalMode = "draw"

        -- (f) 皮的 Icon 錨在讀不懂的地方 ⇒ 方形、外框也不讀 ⇒ 米利邊
        fakeM.unknownAnchor = true
        fakeM.gen = fakeM.gen + 1
        CU.Place(ar, bc, R, "buffs", 36)
        eq("讀不到形狀 ⇒ msqShape nil", hd.msqShape, nil)
        check("讀不到形狀 ⇒ 簽章 msq:square+edge", ar.sig:find("msq:square+edge", 1, true) ~= nil)
        local g2 = RunInit(ar.container)
        eq("方形：圖示整格", g2.icon and g2.icon.points[1] and g2.icon.points[1][1], "TOPLEFT")
        eq("方形：沒有遮罩", g2.icon and g2.icon.masks, nil)
        eq("方形：方形轉圈", g2.cd and g2.cd.swipeTex, "Interface\\BUTTONS\\WHITE8X8")
        eq("方形：米利邊", g2.ov and g2.ov.texCount, 4)
        fakeM.unknownAnchor = nil
        fakeM.gen = fakeM.gen + 1

        -- (g) 群組停用（Sync 回 false）：探針收起來、回到米利樣式
        fakeM.active = false
        CU.Place(ar, bc, R, "buffs", 37)
        eq("群組停用：探針收起來", L.frame.shown, false)
        eq("群組停用：msqOn 清掉", hd.msqOn, nil)
        eq("群組停用：簽章回到米利（池裡拿回原容器）", ar.sig, sigMili)
        fakeM.active = true
        CU.Place(ar, bc, R, "buffs", 38)
        check("重新啟用：Masque 那段回來", hd.msqOn and ar.sig:find(NORMAL_ATLAS, 1, true))

        -- (h) 戰鬥中換皮：容器不建、記旗標；脫戰補建
        fakeM.round = false
        L.icon.masks = nil
        fakeM.gen = fakeM.gen + 1
        local b0 = CU.builds
        combat = true
        CU.Place(ar, bc, R, "buffs", 39)
        eq("戰鬥中：容器不建", CU.builds, b0)
        check("戰鬥中：記旗標", (CU.IsPending(ar)))
        combat = false
        CU.OnRegen()
        check("脫戰：補建（方形皮沒有遮罩）", CU.builds == b0 + 1 and ar.sig:find("msq:", 1, true) and not ar.sig:find("Circle", 1, true))

        -- (i) 收起來：占位、探針跟著收
        CU.EndBar("buffs", 99)
        eq("收起來：持有框", hd.shown, false)
        eq("收起來：占位", ph.frame.shown, false)
        eq("收起來：探針", L.frame.shown, false)
        CU.Place(ar, bc, R, "buffs", 100)
        check("放回來：占位、探針出現", ph.frame.shown and L.frame.shown)

        -- (j) 搬到長條：長條不歸 Masque（不建探針），圖示那顆的占位／探針收起來
        local bb = Obj("Frame"); bb.level = 60
        CU.Place(ar, bb, { x = 0, y = 0, w = 200, h = 20 }, "buffbars", 101)
        check("長條：換一顆持有框", ar.frame ~= hd)
        eq("長條：沒有探針", ar.frame.skin, nil)
        eq("長條：圖示那顆的占位收起來", ph.frame.shown, false)
        eq("長條：圖示那顆的探針收起來", L.frame.shown, false)
        check("長條：簽章沒有 Masque 那段", not ar.sig:find("msq:", 1, true))
        CU.Place(ar, bc, R, "buffs", 102)
        eq("搬回圖示：同一顆持有框", ar.frame, hd)

        -- (k) 存檔的占位關掉也照畫：有光環格的條固定格位一定被強制，不在的一律保留占位（跟暴雪增益同一套）
        ar.entry.placeholder = false
        CU.Place(ar, bc, R, "buffs", 103)
        eq("占位關：固定格位照樣畫占位", ph.frame.shown, true)
        ar.entry.placeholder = true

        -- (l) 飾品冷卻格的疊層：不建探針；冷卻格是 Masque 在畫 ⇒ 照它的 Icon 讀形狀、不畫米利邊也不畫皮外框
        local isl = DB.AddCustom({ kind = "slot", slot = 13, bar = "essential" })
        CU.Sync()
        local sr = CU.Get("c:" .. isl)
        local deco = ns.Decorate.Apply
        local skinCD = false
        ns.Decorate.Apply = function(f, rec, barKey)
            rec.decorated = "deco:" .. barKey
            rec.msqSkinned = skinCD
            if skinCD and f.Icon then
                fakeM.round = true
                Skin(f, { Icon = f.Icon }, 36, 36)
            end
        end
        local ec = Obj("Frame"); ec.level = 10
        CU.Place(sr, ec, { x = 0, y = 0, w = 36, h = 36 }, "essential", 104)
        local o = sr.buffOverlay
        check("疊層（米利）：沒有 msq", o and o.frame and not o.frame.msqOn and not o.sig:find("msq:", 1, true))
        skinCD = true
        CU.Place(sr, ec, { x = 0, y = 0, w = 36, h = 36 }, "essential", 105)
        local oh = o.frame
        eq("疊層（Masque）：不建探針", oh.skin, nil)
        eq("疊層（Masque）：不建占位", oh.ph, nil)
        check("疊層（Masque）：照冷卻格的 Icon 讀形狀", oh.msqOn and oh.msqShape and oh.msqShape.mask
            and oh.msqShape.mask.file:find("Circle", 1, true))
        eq("疊層（Masque）：不讀皮外框", oh.msqShape and oh.msqShape.normal, nil)
        check("疊層（Masque）：簽章帶遮罩、不退米利邊", o.sig:find("msq:", 1, true) and o.sig:find("Circle", 1, true)
            and o.sig:find("^ov") and not o.sig:find("+edge", 1, true))
        local g3 = RunInit(o.container)
        eq("疊層（Masque）：不畫米利邊", g3.ov and g3.ov.texCount, 0)
        eq("疊層（Masque）：不畫皮外框", g3.normal, nil)
        check("疊層（Masque）：圖示掛遮罩", g3.icon and g3.icon.masks and #g3.icon.masks == 1)
        eq("疊層：層級表不變（容器＋4）", oh:GetFrameLevel(), 14)
        ns.Decorate.Apply = deco

        -- (m) ReadShape：一點錨（TOPLEFT＋偏移）、SetAllPoints、圖集遮罩、秘密值 ⇒ 讀不到
        local fr = Obj("Frame"); fr.w, fr.h = 40, 40
        local ic = Obj("Texture", fr)
        ic:SetSize(30, 20)
        ic:SetPoint("TOPLEFT", fr, "TOPLEFT", 2, -3)
        local sh = CU.ReadShape(fr, ic, 40, 40)
        check("ReadShape：TOPLEFT＋偏移 ⇒ 中心", sh and sh.ix == -20 + 2 + 15 and sh.iy == 20 - 3 - 10 and sh.iw == 30 and sh.ih == 20)
        check("ReadShape：沒遮罩 ⇒ mask nil、簽章 square", sh and sh.mask == nil and sh.sig:find("square", 1, true))
        check("ReadShape：沒給外框 ⇒ normal nil（N:?）", sh and sh.normal == nil and sh.sig:find("N:?", 1, true))
        local ic2 = Obj("Texture", fr)
        ic2:SetAllPoints(fr)
        local mk = Obj("MaskTexture", fr)
        mk:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
        mk:SetSize(36, 36)
        mk:SetPoint("CENTER", fr, "CENTER", 0, 0)
        ic2:AddMaskTexture(mk)
        local sh2 = CU.ReadShape(fr, ic2, 40, 40)
        check("ReadShape：SetAllPoints ⇒ 整格", sh2 and sh2.ix == 0 and sh2.iw == 40)
        check("ReadShape：圖集遮罩（錨在探針上）", sh2 and sh2.mask and sh2.mask.atlas == "UI-HUD-ActionBar-IconFrame-Mask"
            and sh2.mask.file == nil and sh2.mask.w == 36)
        -- 皮外框錨在 Icon 上（皮的 Anchor）＋檔案貼圖、draw layer BACKGROUND ⇒ 抬到 ARTWORK
        local nt = Obj("Texture", fr)
        nt:SetTexture("Interface\\Skin\\Border")
        nt:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        nt:SetSize(44, 44)
        nt:SetPoint("CENTER", ic, "CENTER", 0, 0)
        nt:SetDrawLayer("BACKGROUND", 2)
        local sh3 = CU.ReadShape(fr, ic, 40, 40, nt)
        local n3 = sh3 and sh3.normal
        check("ReadShape：外框錨在 Icon 上 ⇒ 中心跟 Icon", n3 and n3.x == sh3.ix and n3.y == sh3.iy and n3.w == 44)
        check("ReadShape：外框檔案＋texcoord", n3 and n3.file == "Interface\\Skin\\Border" and math.abs(n3.l - 0.1) < 1e-6)
        eq("ReadShape：BACKGROUND 抬到 ARTWORK（在圖示上面）", n3 and n3.layer, "ARTWORK")
        -- 插件自己的貼圖：沒有路徑、檔案編號是負數（實測 Raeli 外框 -5272）⇒ 照收
        local ntNeg = Obj("Texture", fr)
        ntNeg:SetSize(44, 44)
        ntNeg:SetPoint("CENTER", ic, "CENTER", 0, 0)
        ntNeg.GetTextureFileID = function() return -5272 end
        local nNeg = CU.ReadShape(fr, ic, 40, 40, ntNeg).normal
        check("ReadShape：負的檔案編號照收（不是「沒有外框」）", type(nNeg) == "table" and nNeg.file == -5272)
        nt:SetAlpha(0)
        eq("ReadShape：外框透明 ⇒ false（這張皮沒有外框）", CU.ReadShape(fr, ic, 40, 40, nt).normal, false)
        local savedIsSecret = ns.IsSecret
        local SECRET = {}
        ns.IsSecret = function(v) return v == SECRET end
        local ic3 = Obj("Texture", fr)
        ic3:SetPoint("CENTER", fr, "CENTER", 0, 0)
        ic3.w, ic3.h = SECRET, 20
        eq("ReadShape：秘密尺寸 ⇒ nil（不報錯）", CU.ReadShape(fr, ic3, 40, 40), nil)
        nt:SetAlpha(1)
        nt.w = SECRET
        eq("ReadShape：外框秘密尺寸 ⇒ normal nil（讀不到 ⇒ 米利邊）", CU.ReadShape(fr, ic, 40, 40, nt).normal, nil)
        ns.IsSecret = savedIsSecret
        eq("ReadShape：沒有尺寸 ⇒ nil", CU.ReadShape(fr, ic, nil, 40), nil)

        -- (n) 生效發光跟著皮的形狀（F）：形狀從交給 Masque 的框讀（探針／疊層底下的冷卻格）、映射後的樣式＋貼圖進簽章、
        --     AttachGlow 在 Attach 之後換貼圖；米利模式不問形狀
        eq("疊層：交給 Masque 的框＝冷卻格", oh.msqFrame, sr.frame)
        local shapeAsk, attached, attachedType = {}, nil, nil
        local shapeVal = "Circle"
        local ART = { t = "proc", shape = "Circle", sig = "Circle:loop", loop = { tex = "circle-loop", w = 84, h = 84 } }
        ns.Glow.SkinShape = function(frame, barKey)
            shapeAsk[#shapeAsk + 1] = { frame, barKey }
            return shapeVal
        end
        ns.Glow.ShapedStyle = function(t, s)
            if s == "Circle" then return "proc", ART end
            return t, nil
        end
        ns.Glow.SkinAttached = function(f, art) attached = { f, art } end
        local function Att(kind) return function() attachedType = kind end end
        ns.MiliUIGlow = { PixelGlow_Attach = Att("pixel"), AutoCastGlow_Attach = Att("autocast"),
                          ButtonGlow_Attach = Att("button"), ProcGlow_Attach = Att("proc") }
        DB.SpecSpells(true).overrides[ar.cooldownID] = { activeGlow = true }
        fakeM.mode, fakeM.round, fakeM.active, fakeM.gen = "masque", true, true, fakeM.gen + 1
        CU.Place(ar, bc, R, "buffs", 110)
        check("發光形狀：問的是探針（交給 Masque 的框）", #shapeAsk >= 1 and shapeAsk[#shapeAsk][1] == hd.skin.frame
            and shapeAsk[#shapeAsk][2] == "buffs")
        check("發光形狀：映射後的貼圖進簽章", ar.sig:find("Circle:loop", 1, true) ~= nil)
        local stG = CU.AuraStyle(ar, "buffs", 36, 36, "icons")
        eq("發光形狀：像素改畫觸發", stG.glow and stG.glow.type, "proc")
        eq("發光形狀：art 帶進 st.glow", stG.glow and stG.glow.art, ART)
        local gG = RunInit(ar.container)
        eq("發光形狀：Attach 的是觸發", attachedType, "proc")
        check("發光形狀：Attach 之後換貼圖", attached and attached[2] == ART and attached[1] and attached[1].otype == "Frame")
        check("發光形狀：觸發畫成 1.4 倍（跟方形觸發一樣）", gG.btn and attached and attached[1].last_SetPoint
            and attached[1].last_SetPoint[1] == "BOTTOMRIGHT")
        -- 方形皮：SkinShape 回 nil ⇒ 照原樣式、不換貼圖、簽章沒有形狀
        shapeVal, attached, attachedType = nil, nil, nil
        fakeM.gen = fakeM.gen + 1
        CU.Place(ar, bc, R, "buffs", 111)
        check("方形皮：簽章沒有形狀", not ar.sig:find("Circle:loop", 1, true))
        RunInit(ar.container)
        eq("方形皮：照原樣式（像素）", attachedType, "pixel")
        eq("方形皮：不換貼圖", attached, nil)
        -- 米利模式：hd.msqOn 是 nil ⇒ 不問形狀
        shapeVal = "Circle"
        fakeM.mode = "miliui"
        local asked = #shapeAsk
        CU.Place(ar, bc, R, "buffs", 112)
        eq("米利模式：不問形狀", #shapeAsk, asked)
        eq("米利模式：沒有交給 Masque 的框", hd.msqFrame, nil)
        check("米利模式：簽章沒有形狀", not ar.sig:find("Circle:loop", 1, true))
        DB.SpecSpells(true).overrides[ar.cooldownID] = nil
        ns.Glow.SkinShape, ns.Glow.ShapedStyle, ns.Glow.SkinAttached, ns.MiliUIGlow = nil, nil, nil, nil

        ns.Masque = savedM
        ns.Decorate.ApplyPlaceholder = nil
        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
    end

    ------------------------------------------------------------
    -- 17. 沒有物品時隱藏／被動飾品不顯示（G）：純函式（ItemsGone／PassiveOf／Layout.HiddenSlot）、HideReason
    --     （條層／逐格覆寫、替代品、讀不到不收、資料沒載入等載入）、Relayout 讓位（非固定）／留空格（固定）、
    --     Occupancy 同一個判準、代畫格、戰鬥中、事件只在有需要時註冊、事件來了結果變了才重排
    ------------------------------------------------------------
    do
        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
        local th = p.theme.icon
        eq("預設：沒有物品時隱藏 關", th.hideNoItem, false)
        eq("預設：被動飾品不顯示 開", th.hidePassiveTrinket, true)
        eq("SPELL_FALLBACK hideNoItem", DB.SPELL_FALLBACK.hideNoItem, "icon.hideNoItem")
        eq("SPELL_FALLBACK hidePassiveTrinket", DB.SPELL_FALLBACK.hidePassiveTrinket, "icon.hidePassiveTrinket")
        eq("覆寫分組：圖示節", DB.OVERRIDE_GROUP.hidePassiveTrinket, "icon")

        -- 純函式
        local cnt = { [1] = 0, [2] = 0, [3] = 2 }
        local function cof(id) return cnt[id] end
        eq("ItemsGone：全都 0", C.ItemsGone({ 1, 2 }, cof), true)
        eq("ItemsGone：替代品有 ⇒ 不收", C.ItemsGone({ 1, 3 }, cof), false)
        eq("ItemsGone：讀不到 ⇒ 不收", C.ItemsGone({ 1, 9 }, cof), false)
        eq("ItemsGone：空清單 ⇒ 不收", C.ItemsGone({}, cof), false)
        eq("PassiveOf：沒裝東西", C.PassiveOf(nil, true, nil), nil)
        eq("PassiveOf：資料沒載入", C.PassiveOf(5, false, nil), "pending")
        eq("PassiveOf：判不出來 ⇒ 不收", C.PassiveOf(5, nil, nil), nil)
        eq("PassiveOf：沒有使用效果", C.PassiveOf(5, true, nil), "passive")
        eq("PassiveOf：有使用效果", C.PassiveOf(5, true, 123), nil)

        -- 環境：槽 13 有使用效果、槽 14 被動（290000 沒有 GetItemSpell）；包包數量、物品資料快取
        local savedB, savedLayout, savedStyle, savedViewers, savedDiag, savedEvents = ns.Bars, ns.Layout, ns.Style, ns.Viewers, ns.Diag, ns.Events
        local savedCount, savedCached = env.C_Item.GetItemCount, env.C_Item.IsItemDataCachedByID
        local savedReq = env.C_Item.RequestLoadItemDataByID
        local bag = { [5512] = 0, [5513] = 0 }
        env.C_Item.GetItemCount = function(id) return bag[id] or 1 end
        local cached = {}
        env.C_Item.IsItemDataCachedByID = function(id) if cached[id] == nil then return true end return cached[id] end
        local requested = {}
        env.C_Item.RequestLoadItemDataByID = function(id) requested[#requested + 1] = id end
        equipped[13], equipped[14] = 270175, 290000
        C.InvalidateSlotBuffs()
        local evs = {}
        ns.Events = { Register = function(ev, key) if key == "bars_hide" then evs[ev] = key end end,
                      Unregister = function(ev, key) if key == "bars_hide" then evs[ev] = nil end end }
        ns.Diag = { Note = function() end }
        ns.Style = { ApplyPanel = function() end }
        ns.Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {}, EnsureScale = function() end,
                       Get = function() return nil end }
        ns.Decorate.ApplyItemAlpha = function() end
        load("Core/Layout.lua")
        load("Core/Bars.lua")
        local B = ns.Bars
        eq("HiddenSlot：照常", ns.Layout.HiddenSlot(nil, true), nil)
        eq("HiddenSlot：固定格位 ⇒ 空格", ns.Layout.HiddenSlot("noItem", true), "blank")
        eq("HiddenSlot：非固定 ⇒ 讓位", ns.Layout.HiddenSlot("passive", false), "skip")

        -- 輔助：21（暴雪）＋物品 5512（替代品 5513）＋槽 14（被動）＋法術 500
        local iItem = DB.AddCustom({ kind = "item", itemID = 5512, alts = { 5513 }, bar = "utility" })
        local iPas = DB.AddCustom({ kind = "slot", slot = 14, bar = "utility" })
        local iSp = DB.AddCustom({ kind = "spell", spellID = 500, bar = "utility" })
        local idItem, idPas, idSp = "c:" .. iItem, "c:" .. iPas, "c:" .. iSp
        CU.Sync()
        check("輔助不是固定格位（槽 14 被動、沒有增益可疊）", not C.BarHasAuraSlot("utility"))

        eq("HideReason：被動飾品（預設開）", C.HideReason("utility", idPas), "passive")
        eq("HideReason：物品（預設關）⇒ 不收", C.HideReason("utility", idItem), nil)
        eq("HideReason：法術不適用", C.HideReason("utility", idSp), nil)
        th.hideNoItem = true
        local why, watch = C.HideReason("utility", idItem)
        eq("HideReason：條層開＋主與替代品都 0 ⇒ 收", why, "noItem")
        eq("HideReason：物品要聽包包", watch, "bag")
        bag[5513] = 2
        eq("HideReason：替代品有 ⇒ 不收", C.HideReason("utility", idItem), nil)
        bag[5513] = 0
        DB.SetOverride(idItem, "hideNoItem", false)
        eq("HideReason：逐格覆寫關 ⇒ 不收", C.HideReason("utility", idItem), nil)
        DB.SetOverride(idItem, "hideNoItem", nil)
        th.hideNoItem = false
        DB.SetOverride(idItem, "hideNoItem", true)
        eq("HideReason：條層關、逐格覆寫開 ⇒ 收", C.HideReason("utility", idItem), "noItem")
        local savedSecret = ns.IsSecret
        ns.IsSecret = function(v) return v == 0 end
        eq("HideReason：數量是秘密值 ⇒ 不收", C.HideReason("utility", idItem), nil)
        ns.IsSecret = savedSecret
        DB.SetOverride(idPas, "hidePassiveTrinket", false)
        eq("HideReason：被動飾品逐格關 ⇒ 不收", C.HideReason("utility", idPas), nil)
        DB.SetOverride(idPas, "hidePassiveTrinket", nil)
        cached[290000] = false
        local pw, pwatch = C.HideReason("utility", idPas)
        eq("HideReason：物品資料沒載入 ⇒ 不收", pw, nil)
        eq("HideReason：等物品資料", pwatch, "info")
        eq("HideReason：要求載入一次", requested[1], 290000)
        C.HideReason("utility", idPas)
        eq("HideReason：不重複要求", #requested, 1)
        cached[290000] = nil
        equipped[14] = nil
        eq("HideReason：空格不屬於這條 ⇒ 不收", C.HideReason("utility", idPas), nil)
        equipped[14] = 290000
        equipped[13] = 270175

        -- Relayout：非固定 ⇒ 讓位
        -- 每一輪換一顆暴雪 item（直接叫 Relayout 不經 Flush，上一輪的認領不會放掉）
        local index = {}
        local function Fresh()
            local it = Obj("Frame")
            ns.Viewers.frames[it] = { barKey = "utility", cooldownID = 21 }
            index[21] = it
        end
        Fresh()
        local rItem, rPas, rSp = CU.Get(idItem), CU.Get(idPas), CU.Get(idSp)
        Fresh()
        B.Relayout("utility", 2, index, 300)
        eq("讓位：4 格收 2 格 ⇒ 2", B.Count("utility"), 2)
        eq("讓位：物品沒放", rItem.placedBar, nil)
        eq("讓位：被動飾品沒放", rPas.placedBar, nil)
        eq("讓位：法術往前補（第 2 格 x）", rSp.frame and rSp.frame.last_SetPoint and rSp.frame.last_SetPoint[4] ~= nil
            and rSp.frame.last_SetPoint[4] > 0 and rSp.frame.last_SetPoint[4] < 80, true)
        B.SyncHideEvents()
        eq("事件：包包數量（有物品格開著）", evs.BAG_UPDATE_DELAYED, "bars_hide")
        eq("事件：物品資料都到了 ⇒ 不聽", evs.GET_ITEM_INFO_RECEIVED, nil)
        local occ = B.Occupancy(index)
        eq("Occupancy：讓位的物品不佔", occ("utility", idItem), false)
        eq("Occupancy：讓位的被動飾品不佔", occ("utility", idPas), false)
        eq("Occupancy：法術照佔", occ("utility", idSp), true)

        -- 有了 ⇒ 放回來（事件：結果變了才要求重排）
        local reqs = {}
        local savedReqFn = B.Request
        B.Request = function(k, lv) reqs[#reqs + 1] = k .. ":" .. lv end
        B.HideRecheck()
        eq("事件：沒變 ⇒ 不重排", #reqs, 0)
        bag[5512] = 3
        B.HideRecheck()
        check("事件：數量變了 ⇒ 重排", #reqs > 0)
        B.Request = savedReqFn
        Fresh()
        B.Relayout("utility", 2, index, 301)
        eq("有了 ⇒ 3 格", B.Count("utility"), 3)
        eq("有了 ⇒ 物品放回輔助", rItem.placedBar, "utility")
        eq("被動飾品照樣收著", rPas.placedBar, nil)

        -- 戰鬥中用掉最後一個（非固定的條）：照常即時讓位
        combat = true
        bag[5512] = 0
        Fresh()
        B.Relayout("utility", 2, index, 302)
        eq("戰鬥中（非固定）：即時讓位", B.Count("utility"), 2)
        eq("戰鬥中（非固定）：物品收起來", rItem.placedBar, nil)
        combat = false

        -- 固定格位 ⇒ 留空格（格數不變、後面的不往前補、不佔位以外照算）
        local util = DB.BarTable("utility")
        util.layout = util.layout or {}
        util.layout.fixedSlots = true
        local xFixed
        Fresh()
        B.Relayout("utility", 2, index, 303)
        eq("固定格位：4 格照留", B.Count("utility"), 4)
        eq("固定格位：物品不放", rItem.placedBar, nil)
        eq("固定格位：被動飾品不放", rPas.placedBar, nil)
        xFixed = rSp.frame.last_SetPoint[4]
        check("固定格位：法術留在第 4 格（不往前補）", xFixed and xFixed > 80, xFixed)
        local occ2 = B.Occupancy(index)
        eq("Occupancy：固定格位的空格照佔", occ2("utility", idItem), true)
        combat = true
        bag[5512] = 1
        Fresh()
        B.Relayout("utility", 2, index, 304)
        eq("戰鬥中（固定）：放回原格，格數不變", B.Count("utility"), 4)
        eq("戰鬥中（固定）：物品放回", rItem.placedBar, "utility")
        combat = false
        util.layout.fixedSlots = nil

        -- 代畫格：被動飾品不顯示（槽 14 被動）；收掉時不拿代畫 rec
        local savedInfo3 = CV.GetCooldownViewerCooldownInfo
        local savedSet1 = SETS[1]
        SETS[1] = { 21, 198604 }
        CV.GetCooldownViewerCooldownInfo = function(id)
            if id == 198604 then
                return { cooldownID = id, spellID = 1400001, category = 1, equipSlot = 14, isKnown = true, flags = 0 }
            end
            return savedInfo3(id)
        end
        C.Refresh("test")
        bag[5512] = 1
        eq("ProxySlotOf：槽 14", C.ProxySlotOf(198604), 14)
        eq("HideReason：代畫格被動 ⇒ 收", C.HideReason("utility", 198604), "passive")
        Fresh()
        B.Relayout("utility", 2, index, 305)
        eq("代畫格被動：還是記成代畫（預覽要畫暗）", B.IsProxied("utility", 198604), 14)
        eq("代畫格被動：不算 missing", B.IsMissing("utility", 198604), false)
        local px = CU.Proxies()[198604]
        check("代畫格被動：沒放（沒拿 rec 或收著）", px == nil or px.placedBar == nil)
        eq("Occupancy：讓位的代畫格不佔", B.Occupancy(index)("utility", 198604), false)
        equipped[14] = 280000                         -- 換成有使用效果的
        C.InvalidateSlotBuffs()
        eq("代畫格換成主動飾品 ⇒ 不收", C.HideReason("utility", 198604), nil)
        Fresh()
        B.Relayout("utility", 2, index, 306)
        px = CU.Proxies()[198604]
        eq("代畫格主動：放上輔助", px and px.placedBar, "utility")
        equipped[14] = 290000
        C.InvalidateSlotBuffs()
        Fresh()
        B.Relayout("utility", 2, index, 307)
        eq("代畫格換回被動：收起來", px.placedBar, nil)
        CV.GetCooldownViewerCooldownInfo = savedInfo3
        SETS[1] = savedSet1
        C.Refresh("test")

        -- 物品資料沒載入 ⇒ 聽 GET_ITEM_INFO_RECEIVED；到了就不聽
        cached[290000] = false
        Fresh()
        B.Relayout("utility", 2, index, 308)
        B.SyncHideEvents()
        eq("事件：等物品資料", evs.GET_ITEM_INFO_RECEIVED, "bars_hide")
        eq("資料沒載入：被動飾品先顯示", rPas.placedBar, "utility")
        cached[290000] = nil
        Fresh()
        B.Relayout("utility", 2, index, 309)
        B.SyncHideEvents()
        eq("事件：資料到了就不聽", evs.GET_ITEM_INFO_RECEIVED, nil)
        eq("資料到了：被動飾品收起來", rPas.placedBar, nil)

        -- 都關掉 ⇒ 一個事件都不聽
        DB.SetOverride(idItem, "hideNoItem", nil)
        th.hideNoItem = false
        Fresh()
        B.Relayout("utility", 2, index, 310)
        B.SyncHideEvents()
        eq("事件：沒有格子需要 ⇒ 不聽包包", evs.BAG_UPDATE_DELAYED, nil)

        DB.SetOverride(idItem, "hideNoItem", nil)
        th.hideNoItem = false
        env.C_Item.GetItemCount, env.C_Item.IsItemDataCachedByID = savedCount, savedCached
        env.C_Item.RequestLoadItemDataByID = savedReq
        ns.Bars, ns.Layout, ns.Style, ns.Viewers, ns.Diag, ns.Events = savedB, savedLayout, savedStyle, savedViewers, savedDiag, savedEvents
        ns.Decorate.ApplyItemAlpha = nil
        equipped[13], equipped[14] = 270175, nil
        C.InvalidateSlotBuffs()
        for i = #list, 1, -1 do list[i] = nil end
        CU.Sync()
    end

    for i = #list, 1, -1 do list[i] = nil end
    CU.Sync()
    env.CreateFrame, env.UIParent, env.InCombatLockdown, ns.Events = savedCF, savedUI, savedICL, savedEv
    CV.GetCooldownViewerCategorySet, CV.GetCooldownViewerCooldownInfo = savedSet, savedInfo
    env.Enum.CooldownViewerCategory.EquipSlotTracked = nil
    env.GetInventoryItemID = nil
    C.InvalidateSlotBuffs()
    ns.Decorate, ns.Glow, ns.Keybinds, ns.Text, ns.Media, ns.Write, ns.Layout, ns.P, ns.Sound, ns.MiliUIGlow =
        saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7], saved[8], saved[9], saved[10]
end

print(("Custom_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
