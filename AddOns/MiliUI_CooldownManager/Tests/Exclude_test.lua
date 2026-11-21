------------------------------------------------------------
-- 戰隊層自訂項目的排除（Core/DB_Custom.lua「戰隊層的排除」）：
--   DB.ExcludeKindOf／CustomExcludedKind／SetCustomExclude／CustomExcludeList、EffectiveCustom 不含被排除的、
--   ExcludedCustom（設定頁）、Catalog.Bar(key, true) 列得到、Catalog.Info／CustomEntry 解得出、MoveCustomScope、
--   RemoveCustom、下拉值的推導（DB.ScopeChoice／ParseScopeChoice）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Exclude_test.lua
--
-- DB.lua、DB_Custom.lua 與 Catalog.lua 載進同一個環境表（WoW API stub），共用同一個 ns（同 Custom_test.lua）。
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
local charName = "米利"
env.UnitName = function() return charName end
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
env.C_Spell = {
    GetSpellTexture = function(id) return 900000 + id end,
    GetSpellName = function(id) return "法術" .. id end,
    GetOverrideSpell = function(id) return id end,
}
env.C_SpellBook = { IsSpellKnown = function() return true end }
env.C_Item = {
    GetItemIconByID = function(id) return 800000 + id end,
    GetItemNameByID = function(id) return "物品" .. id end,
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
load("Libs/MiliUIDB.lua")
load("Core/DB.lua")
load("Core/DB_Custom.lua")
load("Core/Catalog.lua")
local DB, C = ns.DB, ns.Catalog
ns.RefreshSpec()
DB.Init()
C.Refresh("test")
local p = ns.profile

local ME = "米利 - 世界之樹"

local function ids(items)
    local out = {}
    for _, it in ipairs(items or {}) do out[#out + 1] = it.id end
    return table.concat(out, ",")
end

local function Reset()
    local l = DB.CustomList(false)
    if l then for i = #l, 1, -1 do l[i] = nil end end
    p.customShared, p.customClass, p.customChar, p.customNextUID = nil, nil, nil, nil
    local sp = DB.SpecSpells(true)
    sp.order.essential = nil
    ns.playerClass, ns.specID, charName = "PALADIN", 61, "米利"
end

------------------------------------------------------------
-- 1. 純函式：ExcludeKindOf（三種各自生效／不生效的對象、順序、壞形狀）
------------------------------------------------------------
do
    local keys = { class = "PALADIN", char = ME, spec = 61 }
    eq("沒有 exclude ＝ 沒有排除", DB.ExcludeKindOf({ kind = "spell", spellID = 1 }, keys), nil)
    eq("職業", DB.ExcludeKindOf({ exclude = { class = { PALADIN = true } } }, keys), "class")
    eq("職業：別的職業不算", DB.ExcludeKindOf({ exclude = { class = { MAGE = true } } }, keys), nil)
    eq("角色", DB.ExcludeKindOf({ exclude = { char = { [ME] = true } } }, keys), "char")
    eq("角色：別的角色不算", DB.ExcludeKindOf({ exclude = { char = { ["別人 - 世界之樹"] = true } } }, keys), nil)
    eq("專精", DB.ExcludeKindOf({ exclude = { spec = { [61] = true } } }, keys), "spec")
    eq("專精：別的專精不算", DB.ExcludeKindOf({ exclude = { spec = { [62] = true } } }, keys), nil)
    eq("多種對得上：char → spec → class",
        DB.ExcludeKindOf({ exclude = { class = { PALADIN = true }, spec = { [61] = true }, char = { [ME] = true } } }, keys), "char")
    eq("多種對得上：spec 先於 class",
        DB.ExcludeKindOf({ exclude = { class = { PALADIN = true }, spec = { [61] = true } } }, keys), "spec")
    eq("讀不到角色 key ⇒ 角色排除不算", DB.ExcludeKindOf({ exclude = { char = { [ME] = true } } }, { class = "PALADIN", spec = 61 }), nil)
    -- 壞形狀：不崩、當沒有
    eq("exclude 是字串", DB.ExcludeKindOf({ exclude = "x" }, keys), nil)
    eq("子表是數字", DB.ExcludeKindOf({ exclude = { class = 3, char = "y" } }, keys), nil)
    eq("值不是 true", DB.ExcludeKindOf({ exclude = { class = { PALADIN = 1 } } }, keys), nil)
    eq("raw 不是表", DB.ExcludeKindOf("x", keys), nil)
    eq("keys 不是表", DB.ExcludeKindOf({ exclude = { class = { PALADIN = true } } }, nil), nil)
end

------------------------------------------------------------
-- 2. SetCustomExclude：單選、只管這隻角色對得上的三格、不動別人的、空表清成 nil
------------------------------------------------------------
do
    Reset()
    local w = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    local k = DB.AddCustomTo("class", { kind = "spell", spellID = 501, bar = "essential" })
    eq("戰隊層 id", w, "w:1")
    local raw = DB.CustomEntry(w)

    eq("職業層不支援排除", DB.SetCustomExclude(k, "class"), false)
    eq("職業層那筆沒有 exclude", DB.CustomEntry(k).exclude, nil)
    eq("kind 不認得 ⇒ false", DB.SetCustomExclude(w, "realm"), false)
    eq("找不到那一筆 ⇒ false", DB.SetCustomExclude("w:99", "char"), false)
    eq("不是自訂 id ⇒ false", DB.SetCustomExclude(11, "char"), false)
    eq("沒有排除 ⇒ CustomExcludedKind nil", DB.CustomExcludedKind(w), nil)

    local gen = DB.customGen
    check("排除這個角色", DB.SetCustomExclude(w, "char"))
    check("寫入走 TouchCustom", DB.customGen > gen)
    eq("對這隻角色：角色除外", DB.CustomExcludedKind(w), "char")
    eq("存檔形狀", raw.exclude and raw.exclude.char and raw.exclude.char[ME], true)
    eq("沒用到的子表不留", raw.exclude.class, nil)

    -- 單選：改成職業 ⇒ 角色那格清掉
    check("改成這個職業", DB.SetCustomExclude(w, "class"))
    eq("對這隻角色：職業除外", DB.CustomExcludedKind(w), "class")
    eq("角色那格清掉、子表清成 nil", raw.exclude.char, nil)
    eq("職業那格", raw.exclude.class and raw.exclude.class.PALADIN, true)

    -- 不動別人的：別隻角色、別的職業、別的專精已有的排除留著
    raw.exclude.char = { ["別人 - 世界之樹"] = true }
    raw.exclude.class.MAGE = true
    raw.exclude.spec = { [62] = true }
    check("改成這個專精", DB.SetCustomExclude(w, "spec"))
    eq("對這隻角色：專精除外", DB.CustomExcludedKind(w), "spec")
    eq("這個職業那格清掉", raw.exclude.class.PALADIN, nil)
    eq("別的職業留著", raw.exclude.class.MAGE, true)
    eq("別隻角色留著", raw.exclude.char["別人 - 世界之樹"], true)
    eq("別的專精留著", raw.exclude.spec[62], true)
    eq("這個專精", raw.exclude.spec[61], true)

    -- 列出全部（class → char → spec）
    local all = DB.CustomExcludeList(w)
    local txt = {}
    for _, x in ipairs(all) do txt[#txt + 1] = x.kind .. "=" .. tostring(x.key) end
    eq("CustomExcludeList 列全部", table.concat(txt, ","), "class=MAGE,char=別人 - 世界之樹,spec=61,spec=62")
    eq("職業層的 CustomExcludeList 是空的", #DB.CustomExcludeList(k), 0)

    -- nil ＝ 只清這隻角色的三格
    check("全清（這隻角色）", DB.SetCustomExclude(w, nil))
    eq("對這隻角色沒有排除了", DB.CustomExcludedKind(w), nil)
    eq("別人的照留（MAGE）", raw.exclude.class.MAGE, true)
    eq("別人的照留（62）", raw.exclude.spec[62], true)
    eq("這個專精清掉", raw.exclude.spec[61], nil)

    -- 別人的也清掉之後 ⇒ exclude 整個 nil
    raw.exclude = { class = { PALADIN = true } }
    check("清掉最後一格", DB.SetCustomExclude(w, nil))
    eq("空的 exclude 清成 nil", raw.exclude, nil)

    -- 壞形狀的 exclude：寫入時當沒有、重建
    raw.exclude = "壞掉"
    eq("壞形狀：讀時當沒有", DB.CustomExcludedKind(w), nil)
    check("壞形狀：照樣設得進去", DB.SetCustomExclude(w, "char"))
    eq("壞形狀：重建成表", type(raw.exclude) == "table" and raw.exclude.char[ME], true)
    raw.exclude = { char = "壞", class = { PALADIN = true } }
    check("子表壞形狀：照樣設得進去", DB.SetCustomExclude(w, "spec"))
    eq("壞的子表清掉", raw.exclude.char, nil)
    eq("職業那格（這隻角色的）清掉", raw.exclude.class, nil)
    eq("專精那格", raw.exclude.spec[61], true)
    DB.SetCustomExclude(w, nil)
    eq("清完 nil", raw.exclude, nil)

    -- 讀不到名字 ⇒ 不能排除角色（不動任何東西）
    raw.exclude = { class = { PALADIN = true } }
    charName = nil
    eq("讀不到名字 ⇒ 排除角色 false", DB.SetCustomExclude(w, "char"), false)
    eq("失敗不動既有的", raw.exclude.class.PALADIN, true)
    check("讀不到名字 ⇒ 職業照樣可以", DB.SetCustomExclude(w, "spec"))
    charName = "米利"
    raw.exclude = nil
end

------------------------------------------------------------
-- 3. 執行期：EffectiveCustom 不含被排除的；換職業／換角色／換專精只影響對得上的
------------------------------------------------------------
do
    Reset()
    local w1 = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    local w2 = DB.AddCustomTo("shared", { kind = "item", itemID = 7, bar = "essential" })
    eq("兩筆都在", ids(DB.EffectiveCustom()), "w:1,w:2")
    eqList("C.Bar：兩筆都在", C.Bar("essential"), { 11, 12, "w:1", "w:2" })
    C.MarkDirty()
    C.Refresh("test")
    local sig0 = C.sig

    DB.SetCustomExclude(w1, "char")
    eq("角色除外 ⇒ 生效清單沒有它", ids(DB.EffectiveCustom()), "w:2")
    eq("ExcludedCustom 有它", ids(DB.ExcludedCustom()), "w:1")
    eq("ExcludedCustom 帶種類", DB.ExcludedCustom()[1].excluded, "char")
    eqList("C.Bar（執行期）沒有它", C.Bar("essential"), { 11, 12, "w:2" })
    C.MarkDirty()
    C.Refresh("test")
    check("簽章反映排除（CustomSig）", C.sig ~= sig0)

    charName = "別人"
    eq("換角色 ⇒ 看得到", ids(DB.EffectiveCustom()), "w:1,w:2")
    eq("換角色 ⇒ 沒有被排除的", ids(DB.ExcludedCustom()), "")
    charName = "米利"

    DB.SetCustomExclude(w1, "class")
    eq("職業除外 ⇒ 不在", ids(DB.EffectiveCustom()), "w:2")
    ns.playerClass = "MAGE"
    eq("換職業 ⇒ 看得到", ids(DB.EffectiveCustom()), "w:1,w:2")
    charName = "別人"
    ns.playerClass = "PALADIN"
    eq("同職業的別隻角色 ⇒ 也看不到", ids(DB.EffectiveCustom()), "w:2")
    charName = "米利"

    DB.SetCustomExclude(w1, "spec")
    eq("專精除外 ⇒ 不在", ids(DB.EffectiveCustom()), "w:2")
    eq("指定別的專精問 ⇒ 看得到", ids(DB.EffectiveCustom(62)), "w:1,w:2")
    charName = "別人"
    eq("同專精的別隻角色 ⇒ 也看不到", ids(DB.EffectiveCustom()), "w:2")
    charName = "米利"
    ns.specID = 62
    eq("換專精 ⇒ 看得到", ids(DB.EffectiveCustom()), "w:1,w:2")
    ns.specID = 61

    DB.SetCustomExclude(w1, nil)
    eq("取消排除 ⇒ 回來", ids(DB.EffectiveCustom()), "w:1,w:2")
    C.MarkDirty()
    C.Refresh("test")
    eq("取消排除 ⇒ 簽章回到原本", C.sig, sig0)
end

------------------------------------------------------------
-- 4. 窄蓋寬：被排除的不參與（生效清單跟「先拿掉再合併」一樣）；被窄層蓋掉的不列進 ExcludedCustom
------------------------------------------------------------
do
    Reset()
    local w = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    local c = DB.AddCustomTo("spec", { kind = "spell", spellID = 500, bar = "utility" })
    eq("窄蓋寬：只有專精層那筆", ids(DB.EffectiveCustom()), "c:1")
    DB.SetCustomExclude(w, "char")
    eq("排除寬的那筆 ⇒ 專精層照在", ids(DB.EffectiveCustom()), "c:1")
    eq("被窄層蓋掉的不列進 ExcludedCustom（畫面上已有窄層那格）", ids(DB.ExcludedCustom()), "")
    -- 跟「先拿掉再合併」比
    local manual = DB.ResolveScopes(nil, nil, nil, DB.CustomList(false))
    eq("同「先拿掉再合併」", ids(DB.EffectiveCustom()), ids(manual))
    DB.RemoveCustom(c)
    eq("專精層那筆刪掉 ⇒ 戰隊層那筆還是被排除", ids(DB.EffectiveCustom()), "")
    eq("⇒ 這時列進 ExcludedCustom", ids(DB.ExcludedCustom()), "w:1")
end

------------------------------------------------------------
-- 5. 設定頁：Catalog.Bar(key, true) 列得到（照 order）、Info／CustomEntry 解得出；執行期的清單看不到
------------------------------------------------------------
do
    Reset()
    local w1 = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    local w2 = DB.AddCustomTo("shared", { kind = "aura", spellID = 700, filter = "HELPFUL", placeholder = true, bar = "essential" })
    DB.SpecSpells(true).order.essential = { "w:2", 11, "w:1", 12 }
    DB.SetCustomExclude(w1, "char")
    eqList("執行期清單沒有它", C.Bar("essential"), { "w:2", 11, 12 })
    local shown = C.Bar("essential", true)
    eqList("設定頁的清單列得到，照 order 排", shown, { "w:2", 11, "w:1", 12 })
    eq("ExcludedKind", C.ExcludedKind(w1), "char")
    eq("ExcludedKind：沒被排除的", C.ExcludedKind(w2), nil)
    eq("ExcludedKind：暴雪的", C.ExcludedKind(11), nil)
    local e, key, scope, ex = C.CustomEntry(w1)
    check("CustomEntry 解得出", e and e.spellID == 500 and key == 1 and scope == "shared" and ex == "char")
    local info = C.Info(w1)
    check("Info 解得出（名稱、圖示）", info and info.name == "法術500" and info.icon == 900500)
    eq("Info 帶 excluded", info and info.excluded, "char")
    eq("Info 範圍", info and info.scope, "shared")
    eq("SourceOf ＝ 它的 bar（設定頁的「移到」與條的下拉）", C.SourceOf(w1), "essential")
    eq("沒被排除的 Info 沒有 excluded", C.Info(w2) and C.Info(w2).excluded, nil)
    -- 執行期的列舉
    eqList("BarAuraSlotIDs 只看生效的", C.BarAuraSlotIDs("essential"), { "w:2" })
    check("DB.EffectiveItem 看不到", DB.EffectiveItem(w1) == nil)
    check("DB.FindEffective 看不到", DB.FindEffective({ kind = "spell", spellID = 500 }) == nil)
    -- 逐法術覆寫照常寫得進去（存在那一筆身上）
    local o = DB.OverrideTable(w1, true)
    check("覆寫表拿得到", type(o) == "table")
end

------------------------------------------------------------
-- 6. MoveCustomScope：搬離戰隊層丟掉 exclude；搬進戰隊層＋排除
------------------------------------------------------------
do
    Reset()
    local w = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    local raw = DB.CustomEntry(w)
    raw.exclude = { class = { MAGE = true }, char = { [ME] = true } }
    local k = DB.MoveCustomScope(w, "class")
    check("搬到職業層", k and DB.ParseCustomID(k) == "class")
    eq("職業層那筆沒有 exclude", DB.CustomEntry(k).exclude, nil)
    eq("搬過去就看得到", ids(DB.EffectiveCustom()), k)

    local w2 = DB.MoveCustomScope(k, "shared")
    check("搬回戰隊層", w2 and DB.ParseCustomID(w2) == "shared")
    eq("搬回來不會變出 exclude", DB.CustomEntry(w2).exclude, nil)
    check("搬進戰隊層後排除", DB.SetCustomExclude(w2, "spec"))
    eq("排除生效", ids(DB.EffectiveCustom()), "")
    eq("設定頁列得到", ids(DB.ExcludedCustom()), w2)

    local c = DB.MoveCustomScope(w2, "spec")
    check("搬到專精層", c and DB.ParseCustomID(c) == "spec")
    eq("專精層那筆沒有 exclude", DB.CustomEntry(c).exclude, nil)
    local ch = DB.MoveCustomScope(c, "char")
    eq("角色層那筆沒有 exclude", ch and DB.CustomEntry(ch).exclude, nil)
end

------------------------------------------------------------
-- 7. RemoveCustom：被排除的那筆整筆刪掉，不留殘骸（清單、順序）
------------------------------------------------------------
do
    Reset()
    local w = DB.AddCustomTo("shared", { kind = "spell", spellID = 500, bar = "essential" })
    DB.SpecSpells(true).order.essential = { 11, w, 12 }
    DB.SetCustomExclude(w, "char")
    check("刪掉被排除的", DB.RemoveCustom(w))
    eq("戰隊層清單空了", #p.customShared, 0)
    eq("設定頁不再列它", ids(DB.ExcludedCustom()), "")
    eq("Info nil", C.Info(w), nil)
    eqList("順序表裡拿掉了", DB.SpecSpells(false).order.essential, { 11, 12 })
    eqList("設定頁清單也沒有", C.Bar("essential", true), { 11, 12 })
end

------------------------------------------------------------
-- 8. 下拉值的推導（DB.ScopeChoice／ParseScopeChoice）
------------------------------------------------------------
do
    eq("戰隊", DB.ScopeChoice("shared", nil), "shared")
    eq("戰隊＋角色除外", DB.ScopeChoice("shared", "char"), "shared-char")
    eq("戰隊＋職業除外", DB.ScopeChoice("shared", "class"), "shared-class")
    eq("戰隊＋專精除外", DB.ScopeChoice("shared", "spec"), "shared-spec")
    eq("職業層不帶排除", DB.ScopeChoice("class", "char"), "class")
    eq("專精層", DB.ScopeChoice("spec", nil), "spec")
    eq("不認得的範圍", DB.ScopeChoice("realm", nil), nil)
    eq("不認得的排除當沒有", DB.ScopeChoice("shared", "realm"), "shared")
    local s, k = DB.ParseScopeChoice("shared-spec")
    check("解 shared-spec", s == "shared" and k == "spec")
    s, k = DB.ParseScopeChoice("char")
    check("解 char", s == "char" and k == nil)
    eq("解不認得的", DB.ParseScopeChoice("shared-realm"), nil)
    eq("解 nil", DB.ParseScopeChoice(nil), nil)
    eq("七項", #DB.SCOPE_CHOICES, 7)
    for _, v in ipairs(DB.SCOPE_CHOICES) do
        local sc, kd = DB.ParseScopeChoice(v)
        eq("來回一致：" .. v, DB.ScopeChoice(sc, kd), v)
    end
end

print(("Exclude_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
