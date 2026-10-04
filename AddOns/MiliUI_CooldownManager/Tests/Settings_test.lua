------------------------------------------------------------
-- 設定介面在 Core/DB.lua 用到的寫入路徑（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Settings_test.lua
--
-- 覆蓋：主題欄位寫進條的哪張子表（OwnSet／OwnGet）、預設值（右鍵重設）、自訂群組的
-- 新增／刪除（groupOf／order／錨定一併清）、錨定成環、逐法術覆寫的計數與清除、
-- 設定檔改名／取不重複的名字／匯入、匯出字串的來回與每一種錯誤代碼。
-- 環境表做法同 DB_test.lua：這支本身不寫任何全域。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local DB_PATH = here .. "/../Core/DB.lua"

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

------------------------------------------------------------
-- WoW API stub
------------------------------------------------------------
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
env.Enum = { CompressionMethod = { Deflate = 1 } }

-- C_EncodingUtil：CBOR 用登記表假裝（序列化＝存一份深拷貝、回一個代號）
local reg, n = {}, 0
local function deep(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deep(v) end
    return o
end
env.C_EncodingUtil = {
    SerializeCBOR   = function(t) n = n + 1; reg["c" .. n] = deep(t); return "c" .. n end,
    DeserializeCBOR = function(s) local t = reg[s]; if not t then error("cbor") end return deep(t) end,
    CompressString   = function(s) return "z" .. s end,
    DecompressString = function(s) if s:sub(1, 1) ~= "z" then error("inflate") end return s:sub(2) end,
    EncodeBase64 = function(s) return "B" .. s end,
    DecodeBase64 = function(s) if s:sub(1, 1) ~= "B" then error("b64") end return s:sub(2) end,
}

local ns = {
    playerClass = "PALADIN",
    Events = { Register = function() end },
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end

local chunk, err
if setfenv then
    chunk, err = loadfile(DB_PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(DB_PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
local DB = ns.DB
ns.RefreshSpec()
DB.Init()
local p = ns.profile
local S = ns.Setting

------------------------------------------------------------
-- 1. 主題欄位寫進條的哪張子表
------------------------------------------------------------
eq("StoragePath 文字", DB.BarStoragePath("cooldownText.size"), "text.cooldownText.size")
eq("StoragePath 邊框", DB.BarStoragePath("border.color"), "icon.border.color")
eq("StoragePath 圖示（沒有 sub）", DB.BarStoragePath("icon.zoom"), "icon.zoom")
eq("StoragePath 發光", DB.BarStoragePath("glow.proc.type"), "glow.proc.type")
eq("StoragePath 按鍵文字", DB.BarStoragePath("keybind.enabled"), "glow.keybind.enabled")
eq("StoragePath 淡出", DB.BarStoragePath("fade.mounted"), "fade.mounted")
eq("StoragePath 條自己的欄位不變", DB.BarStoragePath("layout.spacing"), "layout.spacing")
eq("主題有 keybind 預設", S("theme", "keybind.enabled"), true)

DB.OwnSet("essential", "cooldownText.size", 22)
eq("OwnSet 落在 text 子表", p.bars.essential.text.cooldownText.size, 22)
eq("跟隨中讀主題", S("essential", "cooldownText.size"), 16)
p.bars.essential.follow.text = false
eq("不跟隨讀條", S("essential", "cooldownText.size"), 22)
eq("OwnGet", DB.OwnGet("essential", "cooldownText.size"), 22)
DB.OwnSet("essential", "cooldownText.size", nil)
eq("OwnSet nil ＝ 回到主題", S("essential", "cooldownText.size"), 16)
eq("OwnGet 沒存 ＝ nil（不退回主題）", DB.OwnGet("essential", "cooldownText.color"), nil)
DB.OwnSet("essential", "keybind.enabled", false)
p.bars.essential.follow.glow = false
eq("按鍵文字走 glow 子表", S("essential", "keybind.enabled"), false)
eq("主題沒被動到", p.theme.keybind.enabled, true)
check("OwnSet 不存在的條 ＝ false", DB.OwnSet("nope", "icon.zoom", 1) == false)

------------------------------------------------------------
-- 2. 預設值（右鍵「重設為預設」）
------------------------------------------------------------
eq("主題頁的預設", DB.DefaultFor("theme", nil, "cooldownText.size"), 16)
eq("條頁的主題欄位預設 ＝ nil（跟主題）", DB.DefaultFor("theme", "essential", "cooldownText.size"), nil)
eq("條自己的欄位", DB.DefaultFor("bar", "essential", "layout.size.w"), 46)
local d1 = DB.DefaultFor("theme", nil, "border.color")
d1.r = 0.9
eq("預設值是複本", p.theme.border.color.r, 0)
eq("輔助的錨定預設", DB.DefaultFor("bar", "utility", "anchor.to"), "essential")

------------------------------------------------------------
-- 3. 自訂群組
------------------------------------------------------------
eq("NextBarKey", DB.NextBarKey(), "g1")
local g1 = DB.CreateBar("icons", "  防禦  ")
eq("CreateBar 回 key", g1, "g1")
eq("名字去頭尾空白", p.bars.g1.name, "防禦")
eq("source custom", p.bars.g1.source, "custom")
eq("kind icons", p.bars.g1.kind, "icons")
eq("follow 全 true", p.bars.g1.follow.icon and p.bars.g1.follow.text and p.bars.g1.follow.glow and p.bars.g1.follow.fade, true)
eq("沒有錨定", p.bars.g1.anchor, false)
eq("barOrder 接在後面", p.barOrder[#p.barOrder], "g1")
local g2 = DB.CreateBar("bars", "長條")
eq("第二個 g2", g2, "g2")
eq("長條群組 kind", p.bars.g2.kind, "bars")
eq("長條群組有 bar 子表", type(p.bars.g2.bar), "table")
eq("自訂群組的預設（重設用）", DB.DefaultFor("bar", "g2", "bar.height"), 20)
eq("自訂圖示群組的預設尺寸", DB.DefaultFor("bar", "g1", "layout.size.w"), 36)

local sp = DB.SpecSpells(true)
check("SpecSpells 建出四張表", type(sp.order) == "table" and type(sp.groupOf) == "table"
    and type(sp.hidden) == "table" and type(sp.overrides) == "table")
eq("SpecSpells 用目前 specID", p.spells[61], sp)
sp.groupOf[101] = "g1"
sp.groupOf[102] = "g2"
sp.order.g1 = { 101 }
p.spells[62] = { groupOf = { [201] = "g1" }, order = { g1 = { 201 } } }
p.bars.buffs.anchor = { to = "g1", point = "TOP", relPoint = "BOTTOM", x = 0, y = 0 }
check("四條檢視器不給刪", DB.DeleteBar("essential") == false)
check("DeleteBar g1", DB.DeleteBar("g1"))
eq("bars.g1 清掉", p.bars.g1, nil)
eq("groupOf 指向它的清掉", sp.groupOf[101], nil)
eq("別的群組不動", sp.groupOf[102], "g2")
eq("別的專精的 groupOf 也清", p.spells[62].groupOf[201], nil)
eq("order 清掉", sp.order.g1, nil)
eq("別的專精的 order 也清", p.spells[62].order.g1, nil)
eq("錨在它身上的條改成不錨定", p.bars.buffs.anchor, false)
local inOrder = false
for _, k in ipairs(p.barOrder) do if k == "g1" then inOrder = true end end
check("barOrder 移除", not inOrder)
eq("刪掉之後 NextBarKey 補回 g1", DB.NextBarKey(), "g1")

------------------------------------------------------------
-- 4. 錨定成環
------------------------------------------------------------
check("核心錨到輔助 ＝ 成環（輔助錨在核心上）", DB.AnchorWouldCycle("essential", "utility"))
check("增益錨到核心不成環", not DB.AnchorWouldCycle("buffs", "essential"))
check("錨到自己 ＝ 成環", DB.AnchorWouldCycle("buffs", "buffs"))

------------------------------------------------------------
-- 5. 逐法術覆寫
------------------------------------------------------------
DB.SetOverride(11, "borderColor", { r = 1, g = 0, b = 0, a = 1 })
DB.SetOverride(11, "procGlow", false)
DB.SetOverride(12, "hideStackText", true)
eq("SpellSetting 讀覆寫", ns.SpellSetting("essential", 11, "procGlow"), false)
eq("圖示節 1 個", DB.CountOverrides({ 11, 12, 13 }, "icon"), 1)
eq("效果節 1 個", DB.CountOverrides({ 11, 12, 13 }, "glow"), 1)
eq("文字節 1 個", DB.CountOverrides({ 11, 12, 13 }, "text"), 1)
eq("不分節 2 個法術", DB.CountOverrides({ 11, 12, 13 }), 2)
DB.ClearOverrides({ 11, 12 }, "icon")
eq("清圖示節：borderColor 沒了", sp.overrides[11].borderColor, nil)
eq("清圖示節：procGlow 還在", sp.overrides[11].procGlow, false)
DB.ClearOverrides({ 11, 12 }, "text")
eq("整張空了就拿掉", sp.overrides[12], nil)
DB.SetOverride(11, "procGlow", nil)
eq("SetOverride nil 清到空 ⇒ 拿掉", sp.overrides[11], nil)
eq("沒覆寫退回條層", ns.SpellSetting("essential", 11, "procGlow"), true)

-- 不在時顯示占位（F7，暴雪的增益）：沒有條層值（SPELL_CONST false）、自成一組 "slot"
eq("placeholder：SPELL_CONST ＝ false", DB.SPELL_CONST.placeholder, false)
eq("placeholder：沒有條層對應", DB.SPELL_FALLBACK.placeholder, nil)
eq("placeholder：覆寫分組 slot", DB.OVERRIDE_GROUP.placeholder, "slot")
eq("placeholder：沒覆寫 ＝ false（舊存檔不變）", ns.SpellSetting("buffs", 31, "placeholder"), false)
eq("placeholder：任何條都一樣（沒有條層）", ns.SpellSetting("buffbars", 31, "placeholder"), false)
DB.SetOverride(31, "placeholder", true)
DB.SetOverride(31, "borderColor", { r = 1, g = 0, b = 0, a = 1 })
eq("placeholder：讀覆寫", ns.SpellSetting("buffs", 31, "placeholder"), true)
eq("placeholder：SpellOverride 讀得到", ns.SpellOverride(31, "placeholder"), true)
eq("placeholder：占位節 1 個", DB.CountOverrides({ 31 }, "slot"), 1)
DB.ClearOverrides({ 31 }, "icon")
eq("placeholder：清圖示節不清它", ns.SpellSetting("buffs", 31, "placeholder"), true)
eq("placeholder：圖示節的清掉了", sp.overrides[31].borderColor, nil)
DB.ClearOverrides({ 31 }, "glow")
eq("placeholder：清發光節也不清它", ns.SpellSetting("buffs", 31, "placeholder"), true)
DB.SetOverride(31, "placeholder", nil)
eq("placeholder：右鍵清 ⇒ 回 false", ns.SpellSetting("buffs", 31, "placeholder"), false)
eq("placeholder：清到空 ⇒ 整張拿掉", sp.overrides[31], nil)
DB.SetOverride(32, "placeholder", true)
DB.ClearOverrides({ 32 }, "slot")
eq("placeholder：清占位節", sp.overrides[32], nil)

------------------------------------------------------------
-- 6. 設定檔改名／不重複的名字／匯入
------------------------------------------------------------
local sv = ns.sv
check("建一份 A", DB.CreateProfile("A"))
DB.SwitchProfile("A")
sv.specProfiles["米利 - 世界之樹"] = { enabled = true, [2] = "A" }
check("改名 A → B", DB.RenameProfile("A", "B"))
eq("目前名字跟著改", ns.profileName, "B")
eq("profileKeys 跟著改", sv.profileKeys["米利 - 世界之樹"], "B")
eq("專精綁定跟著改", sv.specProfiles["米利 - 世界之樹"][2], "B")
check("Default 不能改名", DB.RenameProfile("Default", "X") == false)
check("撞名不能改", select(2, DB.RenameProfile("B", "Default")) == "exists")
eq("不重複：沒撞", DB.UniqueProfileName("New"), "New")
eq("不重複：撞 Default", DB.UniqueProfileName("Default"), "Default (2)")
DB.CreateProfile("Default (2)")
eq("不重複：再撞", DB.UniqueProfileName("Default"), "Default (3)")
eq("空名字 ⇒ Imported", DB.UniqueProfileName("  "), "Imported")

------------------------------------------------------------
-- 7. 匯出字串
------------------------------------------------------------
local str, e = DB.EncodeProfile()
check("匯出成功", type(str) == "string" and str:sub(1, #DB.WIRE_PREFIX) == DB.WIRE_PREFIX, e)
local data = DB.DecodeProfileString("  " .. str .. "\n")
check("解得回來（前後空白忽略）", type(data) == "table" and type(data.profile) == "table")
eq("帶著名字", data.name, "B")
eq("帶著版本", data.schemaVersion, ns.DB_VERSION)
eq("內容一致", data.profile.bars.essential.layout.size.w, 46)
eq("錯誤：空", select(2, DB.DecodeProfileString("")), "empty")
eq("錯誤：前綴", select(2, DB.DecodeProfileString("MILIUF!1!Bzc1")), "prefix")
eq("錯誤：base64", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "xx")), "base64")
eq("錯誤：解壓", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bxx")), "inflate")
eq("錯誤：cbor", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bznope")), "cbor")
reg.bad1 = { schemaVersion = 1, profile = "x" }
eq("錯誤：形狀（profile 不是表）", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bzbad1")), "shape")
reg.bad2 = { schemaVersion = 1, profile = { bars = { essential = 5 } } }
eq("錯誤：形狀（條不是表）", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bzbad2")), "shape")
reg.newer = { schemaVersion = ns.DB_VERSION + 1, profile = {} }
eq("錯誤：較新的版本", select(2, DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bznewer")), "newer")

local name = DB.ImportProfile(data.profile, data.schemaVersion, "B")
eq("匯入撞名加序號", name, "B (2)")
check("匯入是複本", sv.profiles[name] ~= data.profile and sv.profiles[name].bars.essential.layout.size.w == 46)
eq("目前這份沒被換掉", ns.profileName, "B")
local builtin, custom = DB.SummarizeProfile(data.profile)
eq("摘要：四條", #builtin, 4)
eq("摘要：順序", builtin[1] .. "," .. builtin[4], "essential,buffbars")
eq("摘要：自訂群組（g2 長條）", custom[1], nil)   -- A 是從預設建的，沒有自訂群組
local b2, c2 = DB.SummarizeProfile({ bars = { essential = {}, g5 = { name = "防禦" }, g6 = {} } })
eq("摘要：有名字的用名字、沒有的用 key", table.concat(c2, ","), "g6,防禦")
eq("摘要：只算帶了的檢視器", #b2, 1)

------------------------------------------------------------
-- 8. 自訂項目的寬層（戰隊／職業）跟著字串走；形狀不對的丟掉、不擋整份
------------------------------------------------------------
do
    local P = ns.profile
    P.customShared = { { kind = "item", itemID = 5512, bar = "essential", uid = 1, hideUnknown = true,
                         overrides = { readySound = "Ding" } } }
    P.customClass = { PALADIN = { { kind = "spell", spellID = 642, bar = "essential", uid = 2, hideUnknown = true } } }
    P.customNextUID = 3
    local s2 = DB.EncodeProfile()
    local d2 = DB.DecodeProfileString(s2)
    check("匯出再匯入：戰隊層還在", d2 and d2.profile.customShared and d2.profile.customShared[1].itemID == 5512)
    eq("匯出再匯入：戰隊層的覆寫跟著那一筆", d2 and d2.profile.customShared[1].overrides.readySound, "Ding")
    eq("匯出再匯入：職業層還在", d2 and d2.profile.customClass.PALADIN[1].spellID, 642)
    eq("匯出再匯入：流水號還在", d2 and d2.profile.customNextUID, 3)
    reg.wide1 = { schemaVersion = 1, profile = { customShared = "x", customClass = { PALADIN = 5, MAGE = {} },
                                                 customNextUID = "7" } }
    local d3, why3 = DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bzwide1")
    check("寬層形狀不對不擋整份", d3 ~= nil, why3)
    eq("戰隊層不是表 ⇒ 丟掉", d3 and d3.profile.customShared, nil)
    eq("職業層裡不是表的那個職業 ⇒ 丟掉", d3 and d3.profile.customClass.PALADIN, nil)
    check("職業層裡正常的留著", d3 and type(d3.profile.customClass.MAGE) == "table")
    eq("流水號不是數字 ⇒ 丟掉", d3 and d3.profile.customNextUID, nil)
    reg.wide2 = { schemaVersion = 1, profile = { customClass = 9 } }
    local d4 = DB.DecodeProfileString(DB.WIRE_PREFIX .. "Bzwide2")
    eq("職業層整張不是表 ⇒ 丟掉", d4 and d4.profile.customClass, nil)
    P.customShared, P.customClass, P.customNextUID = nil, nil, nil
end

------------------------------------------------------------
-- 9. 覆寫的寫入世代（效能修整 E2 #4／#5）：每個寫入 API 之後 DB.overrideGen 都變；
--    OverrideTable 只回一個值；DropOverrideTable 整張拿掉
------------------------------------------------------------
do
    local function Changes(name, fn)
        local before = DB.overrideGen
        fn()
        check("overrideGen 變了：" .. name, DB.overrideGen ~= before, "還是 " .. tostring(before))
    end
    local P = ns.profile
    Changes("SetOverride 寫", function() DB.SetOverride(21, "procGlow", false) end)
    Changes("SetOverride 清（nil）", function() DB.SetOverride(21, "procGlow", nil) end)
    Changes("SetOverride 再寫", function() DB.SetOverride(21, "borderColor", { r = 1, g = 1, b = 1, a = 1 }) end)
    Changes("ClearOverrides", function() DB.ClearOverrides({ 21 }, "icon") end)
    DB.SetOverride(22, "procGlow", false)
    Changes("ResetOverrides", function() DB.ResetOverrides(22) end)
    DB.SetOverride(23, "procGlow", false)
    Changes("DropOverrideTable", function() DB.DropOverrideTable(23) end)
    Changes("OverrideTable(create)", function() DB.OverrideTable(24, true) end)
    Changes("SpecSpells(create)", function() DB.SpecSpells(true) end)
    Changes("ImportProfile", function() DB.ImportProfile({ bars = {} }, ns.DB_VERSION, "Gen") end)
    Changes("SwitchProfile（Activate）", function() DB.SwitchProfile("Gen") end)
    Changes("ResetProfile", function() DB.ResetProfile() end)
    DB.SwitchProfile(DB.DEFAULT_PROFILE)

    -- 讀不動世代
    local g = DB.overrideGen
    DB.OverrideTable(21, false)
    ns.SpellSetting("essential", 21, "procGlow")
    DB.HasOverrides(21)
    DB.CountOverrides({ 21, 22 })
    eq("只讀不動 overrideGen", DB.overrideGen, g)

    -- OverrideTable 只回表
    DB.SetOverride(25, "procGlow", false)
    eq("OverrideTable 只回一個值", select("#", DB.OverrideTable(25, false)), 1)
    check("OverrideTable 回的是那張表", DB.OverrideTable(25, false).procGlow == false)
    DB.DropOverrideTable(25)
    eq("DropOverrideTable：整張拿掉", DB.OverrideTable(25, false), nil)
    eq("DropOverrideTable：讀回條層", ns.SpellSetting("essential", 25, "procGlow"), true)
    DB.DropOverrideTable(25)        -- 沒有也不出錯

    -- 寬層的自訂項目：覆寫跟著那一筆走，DropOverrideTable 拿掉那一筆身上的
    P = ns.profile
    P.customShared = { { kind = "spell", spellID = 100, bar = "essential", uid = 9, overrides = { procGlow = false } } }
    eq("寬層：OverrideTable 回那一筆身上的", DB.OverrideTable("w:9", false).procGlow, false)
    local g2 = DB.overrideGen
    DB.DropOverrideTable("w:9")
    eq("寬層：DropOverrideTable 拿掉 entry.overrides", P.customShared[1].overrides, nil)
    check("寬層：DropOverrideTable 動世代", DB.overrideGen ~= g2)
    Changes("寬層：SetOverride", function() DB.SetOverride("w:9", "procGlow", true) end)
    eq("寬層：SetOverride 寫在那一筆身上", P.customShared[1].overrides.procGlow, true)
    Changes("寬層：SetOverride 清到空", function() DB.SetOverride("w:9", "procGlow", nil) end)
    eq("寬層：清到空 ⇒ entry.overrides 拿掉", P.customShared[1].overrides, nil)
    P.customShared = nil
end

print(("Settings_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
