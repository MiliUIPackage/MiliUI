------------------------------------------------------------
-- Core/Catalog.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Catalog_test.lua
--
-- 做法：Catalog.lua 載進自己的環境表，WoW API 全部 stub。暴雪版面字串的解碼鏈
-- （DecodeBase64 → DecompressString → DeserializeCBOR）stub 成「查表」：字串 "1|B64<名字>"
-- 解出 fixtures[<名字>] 這張手工組的表（形狀照暴雪 CooldownViewerSettingsDataStoreSerialization
-- 存檔格式 v5：data[1]=版本、data[2][specTag]=layoutID、data[3][specTag][layoutID]={順序, 分類覆寫}）。
--
-- 覆蓋：玩家順序解析（去重、丟掉不存在的、新 id 接在後面）、分類覆寫（含蓋過 HideByDefault）、
-- 候選池類別、isKnown／隱形項目過濾、各種解不開的退路（無感）、字串鍵、簽章比對、
-- 設定面板開關的暫停與「沒變就不重讀」、profile 的 order／groupOf／hidden 套用、
-- 天賦條件（TalentCondPass、TalentKnown、C.Bar 正式清單不收／設定頁清單照收、結果變了才廣播）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Catalog.lua"

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
-- 假資料
------------------------------------------------------------
local CAT = {
    Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, GroupBuff = 4,
    SpecAgnosticEssential = 5, SpecAgnosticTracked = 6, EquipSlotEssential = 7, EquipSlotTracked = 8,
}
local sets = {
    [0] = { 101, 102, 103 },
    [1] = { 201, 202 },
    [2] = { 301, 302 },
    [3] = { 401 },
    [5] = { 501 },
    [6] = { 601 },
    [7] = { 701 },
    [8] = {},
}
local infos = {}
local function def(id, cat, extra)
    local t = { cooldownID = id, spellID = id * 10, category = cat, isKnown = true, flags = 0,
                hasAura = false, charges = false, isInvisible = false, linkedSpellIDs = {} }
    for k, v in pairs(extra or {}) do t[k] = v end
    infos[id] = t
end
def(101, 0); def(102, 0, { charges = true }); def(103, 0, { isKnown = false })
def(201, 1); def(202, 1, { flags = 2 })            -- HideByDefault
def(301, 2, { hasAura = true }); def(302, 2, { isInvisible = true })
def(401, 3); def(501, 5); def(601, 6); def(701, 7, { equipSlot = 13 })

local fixtures = {}
-- 聖騎士（classID 2）第一專精 ⇒ specTag 21
fixtures.main = {
    [1] = 5,
    [2] = { [21] = 7, [22] = 3 },
    [3] = {
        [21] = {
            [7] = {
                [1] = { 103, 102, 201, 101, 701, 999, 102 },     -- 999 已不存在、102 重複
                [2] = { [0] = { 701, 202 }, [1] = { 101 } },       -- 701、202 → 核心；101 → 輔助
            },
        },
    },
    [4] = { [7] = "我的版面" },
}
fixtures.oldver = { [1] = 3, [2] = { [21] = "Layout 1" } }
fixtures.defaultLayout = { [1] = 5, [2] = { [21] = 1 }, [3] = {} }       -- 預設版面沒有存檔
fixtures.otherSpec = { [1] = 5, [2] = { [22] = 3 }, [3] = { [22] = { [3] = { [1] = { 102, 101 } } } } }
fixtures.stringKeys = {
    ["1"] = 5,
    ["2"] = { ["21"] = 7 },
    ["3"] = { ["21"] = { ["7"] = { ["1"] = { 102, 101 } } } },
}
fixtures.main2 = {
    [1] = 5,
    [2] = { [21] = 7 },
    [3] = { [21] = { [7] = { [1] = { 101, 102 } } } },
}

local layoutString = ""
local cborCalls = 0

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env                 -- Catalog 用 _G.xxx 讀暴雪全域
env.Enum = {
    CooldownViewerCategory = CAT,
    CooldownSetSpellFlags = { HideAura = 1, HideByDefault = 2 },
    CompressionMethod = { Deflate = 1 },
}
env.CDM_HIDE_INVISIBLE_ITEMS = false
env.canaccessvalue = function() return true end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetSpecialization = function() return 1 end
env.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(cat, allowUnlearned)
        assert(allowUnlearned == true, "要帶 allowUnlearned=true（跟暴雪一樣先全拿再濾 isKnown）")
        local s = sets[cat]
        if not s then error("unknown category") end
        local out = {}
        for i, v in ipairs(s) do out[i] = v end
        return out
    end,
    GetCooldownViewerCooldownInfo = function(id)
        local t = infos[id]
        if not t then error("no info") end
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        return copy
    end,
    GetLayoutData = function() return layoutString end,
}
env.C_EncodingUtil = {
    DecodeBase64 = function(s)
        if s:sub(1, 3) ~= "B64" then error("bad base64") end
        return s:sub(4)
    end,
    DecompressString = function(s, method)
        assert(method == 1, "要用 Deflate")
        return s
    end,
    DeserializeCBOR = function(s)
        cborCalls = cborCalls + 1
        local t = fixtures[s]
        if not t then error("bad cbor") end
        return t
    end,
}
env.C_Spell = {
    GetSpellTexture = function(id) return 1000000 + id end,
    GetSpellName = function(id) return "法術" .. id end,
}
local callbacks = {}
env.EventRegistry = {
    RegisterCallback = function(self, event, fn) callbacks[event] = fn end,
}

local fired = {}
local ns = {
    IsSecret = function() return false end,
    Events = { Register = function() end },
    Defer = function(fn, ...) fn(...) end,
    Fire = function(event, ...) fired[#fired + 1] = event end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
    specIndex = 1,
    specID = 65,
}

-- 自訂項目的 id 解析與三層合併在 Core/DB.lua（DB.ParseCustomID／EffectiveCustom）：先載 DB 再載 Catalog（TOC 也是這個順序）
local function LoadInto(path)
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
env.CreateFrame = env.CreateFrame or function()    -- DB.lua 載入時建一個等脫戰的框（這裡用不到）
    return { SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
end
LoadInto(here .. "/../Core/DB.lua")
LoadInto(PATH)
local C = ns.Catalog

local function countFired(name)
    local n = 0
    for _, e in ipairs(fired) do if e == name then n = n + 1 end end
    return n
end

------------------------------------------------------------
-- 1. 解碼器本身
------------------------------------------------------------
do
    local d, why = C.DecodeLayoutString("1|B64main")
    check("解碼：正常", type(d) == "table", why)
    eq("specTag", C.SpecTag(), 21)
    local order, ov, src = C.ExtractSpecLayout(d, 21)
    eqList("解碼：順序去重、保留未知 id（交給建置時丟）", order, { 103, 102, 201, 101, 701, 999 })
    eq("解碼：覆寫 701 → 核心", ov[701], 0)
    eq("解碼：覆寫 101 → 輔助", ov[101], 1)
    eq("解碼：來源", src, "layout")

    local cases = {
        { "", "empty" }, { "1|", "no-payload" }, { "abc", "no-version" },
        { "2|B64main", "encoding-2" }, { "1|xxmain", "base64" }, { "1|B64nope", "cbor" },
        { "1|B64oldver", "data-3" },
    }
    for _, c in ipairs(cases) do
        local r, w = C.DecodeLayoutString(c[1])
        check("解碼退路 " .. c[2], r == nil and w == c[2], tostring(w))
    end
    local r, w = C.DecodeLayoutString(nil)
    check("解碼退路 nil", r == nil and w == "not-string")

    local _, _, why2 = C.ExtractSpecLayout(C.DecodeLayoutString("1|B64defaultLayout"), 21)
    eq("預設版面（沒有存檔）", why2, "default-layout")
    local _, _, why3 = C.ExtractSpecLayout(C.DecodeLayoutString("1|B64otherSpec"), 21)
    eq("別的專精才有版面", why3, "no-active-layout")
    local o4 = C.ExtractSpecLayout(C.DecodeLayoutString("1|B64stringKeys"), 21)
    eqList("CBOR 字串鍵也吃", o4, { 102, 101 })
end

------------------------------------------------------------
-- 2. 建置：玩家順序＋分類覆寫
------------------------------------------------------------
layoutString = "1|B64main"
eq("第一次 Refresh 有變", C.Refresh("test"), true)
eq("順序來源", C.source, "layout")
eqList("完整順序", C.ordered, { 103, 102, 201, 101, 701, 202, 301, 302, 401, 501, 601 })
eqList("核心（覆寫進來的 701、202；未學會的 103 不列）", C.lists.essential, { 102, 701, 202 })
eqList("輔助（101 被覆寫過來）", C.lists.utility, { 201, 101 })
eqList("增益圖示（隱形項目照暴雪預設也列）", C.lists.buffs, { 301, 302 })
eqList("增益長條", C.lists.buffbars, { 401 })
eqList("候選池：核心那邊", C.Pool("essential"), { 501 })
eqList("候選池：增益那邊", C.Pool("buffs"), { 601 })
eq("Info：spellID", C.Info(102).spellID, 1020)
eq("Info：圖示", C.Info(102).icon, 1000000 + 1020)
eq("Info：名字", C.Info(102).name, "法術1020")
eq("Info：charges", C.Info(102).charges, true)
eq("Info：equipSlot", C.Info(701).equipSlot, 13)
eq("Info：有效類別", C.Info(101).effectiveCategory, 1)
eq("SourceOf 覆寫後", C.SourceOf(101), "utility")
eq("SourceOf 候選池", C.SourceOf(501), nil)
eq("CatalogChanged 廣播一次", countFired("CatalogChanged"), 1)

------------------------------------------------------------
-- 3. 簽章：沒變就不廣播
------------------------------------------------------------
eq("同內容 Refresh 無變化", C.Refresh("again"), false)
eq("CatalogChanged 仍是一次", countFired("CatalogChanged"), 1)
local sigBefore = C.sig
layoutString = "1|B64main2"
eq("版面字串換了 ⇒ 有變", C.Refresh("changed"), true)
check("簽章換了", C.sig ~= sigBefore)
eqList("新順序：核心", C.lists.essential, { 101, 102 })
eqList("新順序：沒覆寫 ⇒ 202 回到 HideByDefault 隱藏", C.lists.utility, { 201 })

-- 暴雪在它自己的下一幀才存版面：沒有事件，排版前的新鮮度檢查要抓得到
eq("CheckFresh：沒變", C.CheckFresh(), false)
layoutString = "1|B64main"
eq("CheckFresh：字串偷偷變了", C.CheckFresh(), true)
eqList("CheckFresh 之後清單是新的", C.lists.essential, { 102, 701, 202 })
env.GetSpecialization = function() return 2 end
ns.specIndex = nil
eq("CheckFresh：專精換了", C.CheckFresh(), true)
eq("CheckFresh：新 specTag", C.specTag, 22)
env.GetSpecialization = function() return 1 end
ns.specIndex = 1
C.Refresh("back")
layoutString = "1|B64main2"
C.Refresh("back2")

------------------------------------------------------------
-- 4. 退路：解不開一律回類別集合順序，而且無感
------------------------------------------------------------
for _, s in ipairs({ "", "2|B64main", "1|B64nope", "1|B64oldver", "1|B64defaultLayout" }) do
    layoutString = s
    C.Refresh("fallback")
    check("退路 [" .. s .. "] 來源", C.source:sub(1, 9) == "fallback:", C.source)
    eqList("退路 [" .. s .. "] 核心", C.lists.essential, { 101, 102 })
    eqList("退路 [" .. s .. "] 輔助（202 預設隱藏）", C.lists.utility, { 201 })
    eqList("退路 [" .. s .. "] 候選池（701 還在裝備欄類別）", C.Pool("essential"), { 701, 501 })
end

------------------------------------------------------------
-- 5. 隱形項目：暴雪那個全域開了才濾
------------------------------------------------------------
env.CDM_HIDE_INVISIBLE_ITEMS = true
C.Refresh("invisible")
eqList("隱形項目過濾", C.lists.buffs, { 301 })
env.CDM_HIDE_INVISIBLE_ITEMS = false
C.Refresh("invisible-off")

------------------------------------------------------------
-- 6. 設定面板開關：開著暫停；關掉時版面字串沒變就不重讀
------------------------------------------------------------
layoutString = "1|B64main"
C.Refresh("reset")
C.Init()
check("EventRegistry OnShow 掛上", type(callbacks["CooldownViewerSettings.OnShow"]) == "function")
check("EventRegistry OnHide 掛上", type(callbacks["CooldownViewerSettings.OnHide"]) == "function")
callbacks["CooldownViewerSettings.OnShow"]()
eq("面板開著 ⇒ 暫停", C.IsPaused(), true)
local builds = C.builds
local calls = cborCalls
callbacks["CooldownViewerSettings.OnHide"]()
eq("面板關掉 ⇒ 恢復", C.IsPaused(), false)
eq("字串沒變 ⇒ 不重建", C.builds, builds)
eq("字串沒變 ⇒ 不解碼", cborCalls, calls)
eq("恢復時廣播 CatalogResumed", countFired("CatalogResumed"), 1)
callbacks["CooldownViewerSettings.OnShow"]()
layoutString = "1|B64main2"
local changedBefore = countFired("CatalogChanged")
callbacks["CooldownViewerSettings.OnHide"]()
eq("字串變了 ⇒ 重建", C.builds, builds + 1)
eq("字串變了 ⇒ CatalogChanged", countFired("CatalogChanged"), changedBefore + 1)

------------------------------------------------------------
-- 7. profile 覆寫：groupOf／hidden／order
------------------------------------------------------------
layoutString = "1|B64main"
C.Refresh("profile")
ns.profile = {
    bars = {
        essential = { source = "essential" },
        utility   = { source = "utility" },
        buffs     = { source = "buffs" },
        buffbars  = { source = "buffbars" },
        g1        = { source = "custom" },
    },
    spells = {
        [65] = {
            order   = { essential = { 202, 999, 102 }, g1 = { 102 } },
            groupOf = { [102] = "g1", [201] = "essential", [301] = "gone" },
            hidden  = { [701] = true },
        },
    },
}
eqList("核心：102 拉走、701 隱藏、201 拉進來、照 order 排", C.Bar("essential"), { 202, 201 })
eqList("輔助：201 被拉走", C.Bar("utility"), { 101 })
eqList("自訂群組 g1", C.Bar("g1"), { 102 })
eqList("拉到不存在的群組 ⇒ 留在原條", C.Bar("buffs"), { 301, 302 })
eqList("不存在的條 ⇒ 空", C.Bar("nope"), {})
ns.specID = 66
eqList("別的專精沒有覆寫", C.Bar("essential"), { 102, 701, 202 })
ns.specID = 65
do
    -- withHidden：隱藏的另外回一張（照 order 排），顯示的那張不變
    local vis, hid = C.Bar("essential", true)
    eqList("withHidden：顯示的不變", vis, { 202, 201 })
    eqList("withHidden：隱藏的另回一張", hid, { 701 })
    local _, none = C.Bar("utility", true)
    eqList("withHidden：沒有隱藏 ⇒ 空表", none, {})
    eq("不帶 withHidden 只回一張", select("#", C.Bar("essential")) == 2 and select(2, C.Bar("essential")), nil)
end
local b1 = C.Bar("essential")
b1[1] = "x"
eqList("回傳的是新表", C.Bar("essential"), { 202, 201 })
do
    -- GroupTargets：某條檢視器有動靜時，從它拉法術出去的條（Bars.RequestSource 只標這些＋來源條）
    local function keys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = k end
        table.sort(out)
        return out
    end
    eqList("GroupTargets：核心的 102 拉到 g1", keys(C.GroupTargets("essential")), { "g1" })
    eqList("GroupTargets：輔助的 201 拉到核心", keys(C.GroupTargets("utility")), { "essential" })
    eqList("GroupTargets：拉到不存在的條不算", keys(C.GroupTargets("buffs")), {})
    local acc = { buffs = true }
    C.GroupTargets("essential", acc)
    eqList("GroupTargets：累加進傳進來的表", keys(acc), { "buffs", "g1" })
    ns.specID = 66
    eqList("GroupTargets：別的專精沒有 groupOf", keys(C.GroupTargets("essential")), {})
    ns.specID = 65
end
ns.profile = nil
eqList("沒有 profile ⇒ 空", C.Bar("essential"), {})

------------------------------------------------------------
-- 8. 讀不到的欄位不收（canaccessvalue 回 false）
------------------------------------------------------------
env.canaccessvalue = function(v) return v ~= 1020 end
C.Refresh("secret")
eq("秘密 spellID 不收", C.Info(102).spellID, nil)
eq("其他欄位照收", C.Info(101).spellID, 1010)
env.canaccessvalue = function() return true end

------------------------------------------------------------
-- 9. CheckFresh 的輪詢節流：最多每秒讀一次版面字串；事件路徑（標髒）不受限
------------------------------------------------------------
do
    local clock, reads = 100, 0
    local realGet = env.C_CooldownViewer.GetLayoutData
    env.C_CooldownViewer.GetLayoutData = function() reads = reads + 1; return realGet() end
    env.GetTime = function() return clock end
    layoutString = "1|B64main"
    C.Refresh("throttle")
    eq("節流：第一次照讀", C.CheckFresh(), false)
    local r1 = reads
    check("節流：第一次有讀版面字串", r1 > 0)
    clock = 100.5
    layoutString = "1|B64main2"
    eq("節流：一秒內不讀（字串變了也先不管）", C.CheckFresh(), false)
    eq("節流：一秒內沒有呼叫 GetLayoutData", reads, r1)
    clock = 101.2
    eq("節流：過了一秒照讀、抓到變化", C.CheckFresh(), true)
    eqList("節流：清單是新的", C.lists.essential, { 101, 102 })
    clock = 101.3
    layoutString = "1|B64main"
    C.MarkDirty()
    eq("節流：標髒（事件路徑）不受限", C.CheckFresh(), true)
    eqList("節流：標髒後清單是新的", C.lists.essential, { 102, 701, 202 })
    -- 戰鬥中不輪詢（#16b）：過了一秒、字串也變了，照樣不讀；標髒（事件路徑）照做
    local combat = true
    env.InCombatLockdown = function() return combat end
    clock = 105
    layoutString = "1|B64main2"
    local r2 = reads
    eq("戰鬥中：不輪詢", C.CheckFresh(), false)
    eq("戰鬥中：沒有呼叫 GetLayoutData", reads, r2)
    C.MarkDirty()
    eq("戰鬥中：標髒照樣重讀", C.CheckFresh(), true)
    eqList("戰鬥中：標髒後清單是新的", C.lists.essential, { 101, 102 })
    combat = false
    layoutString = "1|B64main"
    clock = 107
    eq("脫戰：輪詢回來、抓到變化", C.CheckFresh(), true)
    env.InCombatLockdown = nil
    env.GetTime = nil
    env.C_CooldownViewer.GetLayoutData = realGet
end

------------------------------------------------------------
-- 收養：暴雪正在顯示、清單卻漏掉的 id（API 在進場／換專精那幾幀回的東西不完整）
------------------------------------------------------------
do
    local timers = {}
    env.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
    local realInfo = env.C_CooldownViewer.GetCooldownViewerCooldownInfo
    local realSet = env.C_CooldownViewer.GetCooldownViewerCategorySet
    local savedProfile = ns.profile
    ns.profile = { bars = { essential = { source = "essential", kind = "icons" }, utility = { source = "utility", kind = "icons" },
                            buffs = { source = "buffs", kind = "icons" }, buffbars = { source = "buffbars", kind = "bars" } },
                   spells = {} }
    layoutString = "1|B64main2"
    C.Refresh("adopt-base")
    eqList("收養前：核心清單", C.lists.essential, { 101, 102 })
    local utilBefore = list(C.lists.utility)

    -- 過渡狀態：輔助那一類整個查不到、102 的資訊暫時拿不到
    env.C_CooldownViewer.GetCooldownViewerCategorySet = function(cat, allow)
        if cat == 1 then return {} end
        return realSet(cat, allow)
    end
    env.C_CooldownViewer.GetCooldownViewerCooldownInfo = function(id)
        if id == 102 then error("transient") end
        return realInfo(id)
    end
    C.Refresh("adopt-transient")
    eqList("過渡：核心少了 102", C.lists.essential, { 101 })
    eqList("過渡：輔助是空的", C.lists.utility, {})

    -- 暴雪的檢視器上其實都在（有 cooldownID 的作用中 item）
    local n = C.Adopt({ essential = { 101, 102 }, utility = { 201 } })
    eq("收養：兩個", n, 2)
    eqList("收養：核心補回 102（接在尾端）", C.lists.essential, { 101, 102 })
    eqList("收養：輔助補回 201", C.lists.utility, { 201 })
    eqList("收養：C.Bar 也看得到", C.Bar("utility"), { 201 })
    check("收養：有資訊表、標記 adopted", type(C.Info(102)) == "table" and C.Info(102).adopted == true and C.Info(102).bar == "essential")
    eq("收養：排了一次重讀", #timers, 1)
    eq("收養：同一輪再對一次不重複收", C.Adopt({ essential = { 101, 102 }, utility = { 201 } }), 0)
    eqList("收養：清單沒有長出重複的", C.lists.essential, { 101, 102 })
    -- 玩家藏掉的照舊生效
    ns.profile.spells[ns.specID or 0] = nil
    eq("收養：不是數字的 id 不收", C.Adopt({ essential = { "c:1" } }), 0)
    eq("收養：nil 不炸", C.Adopt(nil), 0)

    -- 重讀時 API 還沒好：清單又漏、下一輪排版再收一次，重讀排第二次
    timers[1].fn()
    eqList("重讀後（API 還沒好）：又漏了", C.lists.utility, {})
    eq("再收一次", C.Adopt({ essential = { 101, 102 }, utility = { 201 } }), 2)
    eq("重讀排了第二次", #timers, 2)
    check("重讀的間隔越來越長", timers[2].delay > timers[1].delay)

    -- API 恢復：清單自己就完整，不必收養
    env.C_CooldownViewer.GetCooldownViewerCategorySet = realSet
    env.C_CooldownViewer.GetCooldownViewerCooldownInfo = realInfo
    timers[2].fn()
    eqList("恢復：核心清單", C.lists.essential, { 101, 102 })
    eq("恢復：輔助清單跟原本一樣", list(C.lists.utility), utilBefore)
    eq("恢復：不必收養", C.Adopt({ essential = { 101, 102 }, utility = { 201 } }), 0)
    check("恢復：102 不再標 adopted", C.Info(102).adopted == nil)

    ns.profile = savedProfile
    env.C_Timer = nil
end

------------------------------------------------------------
-- 沒有 spellID 的項目：物品冷卻類別（藥水／治療石）與空的裝備欄，圖示與名字另外找
------------------------------------------------------------
do
    def(801, 5); infos[801].spellID = nil; infos[801].spellCategoryID = 30      -- 治療藥水
    def(802, 5); infos[802].spellCategoryID = 1711                               -- 治療石（有 spellID）
    def(803, 7, { equipSlot = 14 }); infos[803].spellID = nil                   -- 空的飾品欄
    def(804, 5); infos[804].spellID = nil; infos[804].spellCategoryID = 99999   -- 不認得的類別
    sets[5] = { 501, 801, 802, 804 }
    sets[7] = { 701, 803 }
    env.COOLDOWN_VIEWER_TOOLTIP_POTION_HEALTH_TITLE = "治療藥水"
    env.COOLDOWN_VIEWER_TOOLTIP_POTION_HEALTHSTONE_TITLE = "治療石"
    env.TRINKET1SLOT = "飾品"
    env.GetInventorySlotInfo = function(token)
        if token == "TRINKET1SLOT" then return 14, "EmptyTrinketTexture" end
        error("unknown slot")
    end
    local savedSpell = env.C_Spell
    env.C_Spell = { GetSpellTexture = function(id) return "tex" .. id end, GetSpellName = function(id) return "法術" .. id end }
    layoutString = "1|B64main2"
    C.Refresh("category-icons")
    local a, b, c2, d = C.Info(801), C.Info(802), C.Info(803), C.Info(804)
    check("類別項目（沒有 spellID）：圖示用類別的", type(a) == "table" and type(a.icon) == "string" and a.icon:find("INV_Potion_54", 1, true) ~= nil)
    eq("類別項目（沒有 spellID）：名字用類別標題", a and a.name, "治療藥水")
    eq("類別項目：記下 spellCategoryID", a and a.spellCategoryID, 30)
    check("類別項目（有 spellID）：圖示仍用類別的", b and type(b.icon) == "string" and b.icon:find("Healthstone", 1, true) ~= nil)
    eq("類別項目（有 spellID）：名字用法術名", b and b.name, "法術8020")
    eq("空的裝備欄：圖示用空格圖", c2 and c2.icon, "EmptyTrinketTexture")
    eq("空的裝備欄：名字用欄位名", c2 and c2.name, "飾品")
    check("不認得的類別：維持沒有圖示（交給呼叫端的問號）", d and d.icon == nil and d.name == nil)
    env.C_Spell = savedSpell
    env.GetInventorySlotInfo = nil
    sets[5] = { 501 }; sets[7] = { 701 }
    infos[801], infos[802], infos[803], infos[804] = nil, nil, nil, nil
    C.Refresh("category-icons-reset")
end

------------------------------------------------------------
-- 自訂項目的兩個選用欄位（物品的 alts、光環格的 spellIDs）：形狀檢查只看主 ID，選用欄位壞了不算整筆壞
------------------------------------------------------------
do
    local V = C.ValidCustom
    check("物品帶 alts", V({ kind = "item", itemID = 241308, alts = { 241309 } }))
    check("物品 alts 不是表", V({ kind = "item", itemID = 241308, alts = 5 }))
    check("物品沒有主 ID ⇒ 壞", not V({ kind = "item", alts = { 241309 } }))
    check("光環帶 spellIDs", V({ kind = "aura", spellID = 2825, spellIDs = { 32182 }, filter = "HELPFUL" }))
    check("光環 spellIDs 不是表", V({ kind = "aura", spellID = 2825, spellIDs = "x" }))
    check("光環沒有主 ID ⇒ 壞", not V({ kind = "aura", spellIDs = { 32182 } }))
end

------------------------------------------------------------
-- 以增益取代（overrides[A].replaceWith = B）：成立條件、B 從每一條拿掉、GroupTargets、放格判斷
------------------------------------------------------------
do
    local function keys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = k end
        table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
        return out
    end
    layoutString = "1|B64main"
    C.Refresh("replace")
    -- 核心 {102, 701, 202}、輔助 {201, 101}、增益圖示 {301, 302}、增益長條 {401}
    local sp = { order = {}, groupOf = {}, hidden = {}, overrides = {} }
    ns.profile = {
        bars = {
            essential = { source = "essential", kind = "icons" },
            utility   = { source = "utility", kind = "icons" },
            buffs     = { source = "buffs", kind = "icons" },
            buffbars  = { source = "buffbars", kind = "bars" },
            g1        = { source = "custom", kind = "icons" },
        },
        spells = { [65] = sp },
    }
    ns.specID = 65

    local byA, byB = C.Replacements()
    eq("沒設 ⇒ 空", #keys(byA) + #keys(byB), 0)
    eqList("沒設 ⇒ 增益圖示照舊", C.Bar("buffs"), { 301, 302 })

    sp.overrides[102] = { replaceWith = 301 }
    byA, byB = C.Replacements()
    eq("成立：A → B", byA[102], 301)
    eq("成立：B → A", byB[301], 102)
    eq("ReplacedSet", C.ReplacedSet()[301], 102)
    eq("ReplaceTarget", C.ReplaceTarget(102), 301)
    eq("ReplaceTarget：沒設的 A", C.ReplaceTarget(701), nil)
    eq("ReplaceTarget：不是數字", C.ReplaceTarget("c:1"), nil)
    eqList("C.Bar：B 從增益圖示拿掉", C.Bar("buffs"), { 302 })
    eqList("C.Bar：A 那條照舊（B 的位置就是 A 那一格）", C.Bar("essential"), { 102, 701, 202 })
    do
        local vis, hid = C.Bar("buffs", true)
        eqList("withHidden：顯示的沒有 B", vis, { 302 })
        eqList("withHidden：被移除清單也不列 B", hid, {})
        sp.hidden[301] = true
        vis, hid = C.Bar("buffs", true)
        eqList("B 被玩家移除過：被移除清單照樣不列", hid, {})
        sp.hidden[301] = nil
    end
    -- B 被拉去自訂群組：那一條也不列
    sp.groupOf[301] = "g1"
    eqList("B 拉去群組：群組也不列", C.Bar("g1"), {})
    sp.groupOf[301] = nil
    eqList("SourceIDs：增益圖示檢視器自己的清單（含被取代的 B）", C.SourceIDs("buffs"), { 301, 302 })

    -- 不成立的情況（設定留著，條件回來自動生效）
    sp.hidden[102] = true
    eq("A 被移除 ⇒ 不成立", C.ReplaceTarget(102), nil)
    eqList("A 被移除 ⇒ B 回到增益圖示", C.Bar("buffs"), { 301, 302 })
    sp.hidden[102] = nil
    sp.overrides[102] = { replaceWith = 999 }
    eq("B 不在目錄（天賦沒點）⇒ 不成立", C.ReplaceTarget(102), nil)
    sp.overrides[102] = { replaceWith = 401 }
    eq("B 是增益長條 ⇒ 不收", C.ReplaceTarget(102), nil)
    eqList("B 是增益長條 ⇒ 長條照舊", C.Bar("buffbars"), { 401 })
    sp.overrides[102] = { replaceWith = 201 }
    eq("B 是輔助技能 ⇒ 不收", C.ReplaceTarget(102), nil)
    sp.overrides[102] = nil
    sp.overrides[301] = { replaceWith = 302 }
    eq("A 是增益 ⇒ 不收", C.ReplaceTarget(301), nil)
    sp.overrides[301] = nil
    sp.overrides[103] = { replaceWith = 301 }
    eq("A 沒學會（不在清單上）⇒ 不成立", C.ReplaceTarget(103), nil)
    eqList("A 沒學會 ⇒ B 照舊在增益圖示", C.Bar("buffs"), { 301, 302 })
    sp.overrides[103] = nil
    sp.overrides[102] = { replaceWith = 102 }
    eq("取代自己 ⇒ 不收", C.ReplaceTarget(102), nil)
    sp.overrides[102] = { replaceWith = "301" }
    eq("不是數字 ⇒ 不收", C.ReplaceTarget(102), nil)
    sp.overrides[102] = { replaceWith = false }
    eq("false ＝ 不取代", C.ReplaceTarget(102), nil)

    -- 同一個 B 兩個 A：取 cooldownID 小的（結果固定）
    sp.overrides[201] = { replaceWith = 301 }
    sp.overrides[101] = { replaceWith = 301 }
    byA, byB = C.Replacements()
    eq("重複：小的 A 拿到", byB[301], 101)
    eq("重複：大的 A 不成立", byA[201], nil)
    sp.overrides[101] = nil
    eq("重複解除：輔助的 201 拿到", C.ReplaceTarget(201), 301)

    -- 別的專精：各管各的
    ns.specID = 66
    eq("別的專精沒有取代", C.ReplaceTarget(201), nil)
    eqList("別的專精：增益圖示照舊", C.Bar("buffs"), { 301, 302 })
    ns.specID = 65

    -- GroupTargets：增益圖示有動靜 ⇒ A 所在的條也算
    sp.overrides = { [102] = { replaceWith = 301 } }
    eqList("GroupTargets：B 在增益圖示 ⇒ A 的來源條（核心）", keys(C.GroupTargets("buffs")), { "essential" })
    eqList("GroupTargets：別條檢視器的動靜不算", keys(C.GroupTargets("buffbars")), {})
    sp.groupOf[102] = "g1"
    eqList("GroupTargets：A 拉去群組 ⇒ 那個群組（核心的動靜也照舊算 g1）", keys(C.GroupTargets("buffs")), { "g1" })
    sp.groupOf[102] = nil
    sp.overrides = {}
    eqList("GroupTargets：沒設 ⇒ 跟以前一樣", keys(C.GroupTargets("buffs")), {})

    -- 天賦條件（master 的 overrides[id].talentCond）：A 被擋 ⇒ 沒有那一格，B 不能跟著消失；B 被擋 ⇒ 不換
    local savedBook, savedPlayer = env.C_SpellBook, env.IsPlayerSpell
    env.C_SpellBook = nil
    env.IsPlayerSpell = function(id) return id == 10 end
    sp.overrides = { [102] = { replaceWith = 301, talentCond = { spellID = 11, mode = "known" } } }
    eq("A 被天賦條件擋掉 ⇒ 不成立", C.ReplaceTarget(102), nil)
    eqList("A 被天賦條件擋掉 ⇒ B 回到增益圖示", C.Bar("buffs"), { 301, 302 })
    sp.overrides[102].talentCond = { spellID = 10, mode = "known" }
    eq("A 的天賦條件成立 ⇒ 成立", C.ReplaceTarget(102), 301)
    sp.overrides[102].talentCond = nil
    sp.overrides[301] = { talentCond = { spellID = 11, mode = "known" } }
    eq("B 被天賦條件擋掉 ⇒ 不成立", C.ReplaceTarget(102), nil)
    sp.overrides = {}
    env.C_SpellBook, env.IsPlayerSpell = savedBook, savedPlayer

    -- 放格判斷（純函式）：B 有框、沒被別條認領、顯示中、IsActive 明文 true 才換
    local R = C.ReplaceNow
    eq("放格：全部成立 ⇒ B", R({ item = true, free = true, shown = true, active = true }), true)
    eq("放格：沒生效 ⇒ A", R({ item = true, free = true, shown = true, active = false }), false)
    eq("放格：讀不到（nil）⇒ A", R({ item = true, free = true, shown = true }), false)
    eq("放格：不是 true 的真值 ⇒ A", R({ item = true, free = true, shown = true, active = 1 }), false)
    eq("放格：沒顯示 ⇒ A", R({ item = true, free = true, shown = false, active = true }), false)
    eq("放格：被別條認領 ⇒ A", R({ item = true, free = false, shown = true, active = true }), false)
    eq("放格：沒有框 ⇒ A", R({ item = false, free = true, shown = true, active = true }), false)
    eq("放格：nil ⇒ A", R(nil), false)
    do
        local SEC = {}
        local saved = ns.IsSecret
        ns.IsSecret = function(v) return v == SEC end
        eq("放格：秘密值 ⇒ A（副本戰鬥中）", R({ item = true, free = true, shown = true, active = SEC }), false)
        ns.IsSecret = saved
    end
    ns.profile = nil
end

------------------------------------------------------------
-- 長條類的條也列自訂項目（光環格跟其他格同走 order 表、沒有固定前綴）
------------------------------------------------------------
do
    local savedProfile = ns.profile
    layoutString = "1|B64main2"
    C.Refresh("custom-bars")
    ns.profile = {
        bars = {
            essential = { source = "essential", kind = "icons" },
            buffbars  = { source = "buffbars", kind = "bars" },
            g2        = { source = "custom", kind = "bars" },
        },
        spells = {
            [65] = {
                custom = {
                    { kind = "spell", spellID = 9000, bar = "buffbars" },
                    { kind = "aura", spellID = 8000, filter = "HELPFUL", placeholder = true, bar = "buffbars" },
                    { kind = "item", itemID = 241308, bar = "g2" },
                    { kind = "slot", slot = 13, bar = "g2" },
                    { kind = "aura", spellID = 8001, filter = "HELPFUL", placeholder = false, bar = "g2" },
                },
                order = { g2 = { "c:4", "c:3", "c:5" } },
            },
        },
    }
    eqList("增益長條：暴雪的長條在前、自訂照清單順序接在後（光環格不拉到最前）", C.Bar("buffbars"), { 401, "c:1", "c:2" })
    eqList("長條型自訂群組：照順序覆寫，光環格也照 order（沒列進去的接在後）", C.Bar("g2"), { "c:4", "c:3", "c:5" })
    check("長條 BarHasAuraSlot（固定格位強制打開）", C.BarHasAuraSlot("buffbars") and C.BarHasAuraSlot("g2"))
    eq("長條上的自訂項目 SourceOf ＝ 它的 bar", C.SourceOf("c:3"), "g2")
    ns.profile = savedProfile
end

------------------------------------------------------------
-- 天賦條件（overrides[id].talentCond）：純函式＋ C.Bar 的正式清單／設定頁清單
------------------------------------------------------------
do
    local Pass = C.TalentCondPass
    local function known(set) return function(id) return set[id] end end
    local K = known({ [1] = true, [2] = false })
    check("沒條件 ⇒ 成立", Pass(nil, K))
    check("known：學了 ⇒ 成立", Pass({ spellID = 1, mode = "known" }, K))
    check("known：沒學 ⇒ 不成立", not Pass({ spellID = 2, mode = "known" }, K))
    check("unknown：沒學 ⇒ 成立", Pass({ spellID = 2, mode = "unknown" }, K))
    check("unknown：學了 ⇒ 不成立", not Pass({ spellID = 1, mode = "unknown" }, K))
    check("isKnown 回 nil（讀不到）⇒ 成立", Pass({ spellID = 3, mode = "known" }, K))
    check("isKnown 回 nil、unknown 也成立", Pass({ spellID = 3, mode = "unknown" }, K))
    check("沒給 isKnown ⇒ 成立", Pass({ spellID = 2, mode = "known" }, nil))
    check("壞資料：mode 不認得", Pass({ spellID = 2, mode = "maybe" }, K))
    check("壞資料：spellID 是字串", Pass({ spellID = "2", mode = "known" }, K))
    check("壞資料：spellID 是 0", Pass({ spellID = 0, mode = "known" }, K))
    check("壞資料：spellID 是小數", Pass({ spellID = 2.5, mode = "known" }, K))
    check("壞資料：只有 mode", Pass({ mode = "known" }, K))
    check("壞資料：不是表", Pass(true, K))

    -- 遊戲裡的 isKnown：兩支 API 任一明文 true 就算學了，都明文 false 才算沒學，讀不到 nil
    local book, player = {}, {}
    env.C_SpellBook = { IsSpellKnown = function(id) return book[id] end }
    env.IsPlayerSpell = function(id) return player[id] end
    book[10], player[10] = false, true
    eq("TalentKnown：天賦被動只有 IsPlayerSpell 是 true", C.TalentKnown(10), true)
    book[11], player[11] = false, false
    eq("TalentKnown：兩個都 false ⇒ false", C.TalentKnown(11), false)
    book[12] = false
    eq("TalentKnown：一個讀不到又沒有 true ⇒ nil", C.TalentKnown(12), nil)
    env.IsPlayerSpell = function() error("boom") end
    eq("TalentKnown：pcall 失敗算讀不到", C.TalentKnown(11), nil)
    env.IsPlayerSpell = function(id) return player[id] end

    local savedProfile = ns.profile
    layoutString = "1|B64main2"
    C.Refresh("talent-cond")
    ns.profile = {
        bars = {
            essential = { source = "essential", kind = "icons" },
        },
        spells = {
            [65] = {
                custom = {
                    { kind = "spell", spellID = 9000, bar = "essential" },
                    { kind = "spell", spellID = 9001, bar = "essential" },
                },
                overrides = {
                    [101]  = { talentCond = { spellID = 11, mode = "known" } },     -- 沒學 ⇒ 擋掉
                    [102]  = { talentCond = { spellID = 10, mode = "known" } },     -- 學了 ⇒ 留著
                    ["c:1"] = { talentCond = { spellID = 10, mode = "unknown" } },  -- 學了 ⇒ 擋掉
                    ["c:2"] = { talentCond = { spellID = 12, mode = "known" } },    -- 讀不到 ⇒ 留著
                },
            },
        },
    }
    eqList("天賦條件：正式清單沒有不成立的（暴雪的與自訂的）", C.Bar("essential"), { 102, "c:2" })
    local vis, hid = C.Bar("essential", true)
    eqList("天賦條件：withHidden 的第一張照樣有", vis, { 101, 102, "c:1", "c:2" })
    eqList("天賦條件：不進隱藏那張", hid, {})
    check("TalentBlocked：暴雪的", C.TalentBlocked(101) and not C.TalentBlocked(102))
    check("TalentBlocked：自訂的", C.TalentBlocked("c:1") and not C.TalentBlocked("c:2"))
    check("TalentBlocked：沒條件", not C.TalentBlocked(701))

    -- 換天賦：條件結果變了 ⇒ 簽章變、廣播 CatalogChanged；沒變 ⇒ 不廣播
    C.Refresh("talents-baseline")
    local before = countFired("CatalogChanged")
    C.Refresh("talents-same")
    eq("天賦條件結果沒變 ⇒ 不廣播", countFired("CatalogChanged"), before)
    player[11] = true
    C.Refresh("talents")
    eq("天賦條件結果變了 ⇒ CatalogChanged", countFired("CatalogChanged"), before + 1)
    eqList("學了之後正式清單有它", C.Bar("essential"), { 101, 102, "c:2" })
    player[11] = false
    ns.profile = savedProfile
    env.C_SpellBook, env.IsPlayerSpell = nil, nil
end

------------------------------------------------------------
-- 自訂項目的三層範圍（P8）：C.Bar 列三層、被窄層蓋掉的連設定頁清單都不列（挑選器「已在…」區跟著不列）、
-- 寬層的天賦條件存在那一筆身上、寬層「沒學就不列」的結果變了 ⇒ 簽章變、廣播 CatalogChanged
------------------------------------------------------------
do
    local savedProfile, savedClass = ns.profile, ns.playerClass
    layoutString = "1|B64main2"
    C.Refresh("scopes")
    ns.playerClass = "PALADIN"
    local learned = { [9100] = true, [11] = false }      -- 11：天賦條件要的天賦沒點
    env.C_SpellBook = { IsSpellKnown = function(id) local v = learned[id]; if v == nil then return true end return v end }
    ns.profile = {
        bars = {
            essential = { source = "essential", kind = "icons" },
            buffs     = { source = "buffs", kind = "icons" },
        },
        customShared = {
            { kind = "spell", spellID = 9000, bar = "essential", uid = 1, hideUnknown = true },
            { kind = "aura", spellID = 8000, filter = "HELPFUL", placeholder = true, bar = "buffs", uid = 2, hideUnknown = true },
            { kind = "item", itemID = 241308, bar = "essential", uid = 3, hideUnknown = true,
              overrides = { talentCond = { spellID = 11, mode = "known" } } },     -- 寬層的條件存在那一筆身上
        },
        customClass = {
            PALADIN = {
                { kind = "spell", spellID = 9000, bar = "essential", uid = 4, hideUnknown = true },   -- 蓋掉戰隊層的 9000
                { kind = "spell", spellID = 9100, bar = "essential", uid = 5, hideUnknown = true },
            },
            MAGE = { { kind = "spell", spellID = 9200, bar = "essential", uid = 6 } },             -- 別的職業：不列
        },
        spells = {
            [65] = {
                custom = { { kind = "spell", spellID = 9300, bar = "essential" } },
                order = { essential = { "c:1", 102, "k:5" } },
            },
        },
    }
    eqList("三層都列，照 order 排（沒列到的照戰隊 → 職業 → 專精接在後）", C.Bar("essential"), { "c:1", 102, "k:5", 101, "k:4" })
    local vis, hid = C.Bar("essential", true)
    check("被窄層蓋掉的連設定頁清單都不列", (function()
        for _, id in ipairs(vis) do if id == "w:1" then return false end end
        for _, id in ipairs(hid or {}) do if id == "w:1" then return false end end
        return true
    end)())
    eqList("寬層的天賦條件不成立：設定頁清單照樣有", vis, { "c:1", 102, "k:5", 101, "w:3", "k:4" })
    check("TalentBlocked：寬層的", C.TalentBlocked("w:3"))
    check("BarHasAuraSlot：戰隊層的光環格", C.BarHasAuraSlot("buffs"))
    eq("Info：被蓋掉的 ⇒ nil", C.Info("w:1"), nil)
    eq("Info：別的職業的 ⇒ nil", C.Info("k:6"), nil)
    eq("Info：範圍", C.Info("k:5") and C.Info("k:5").scope, "class")

    -- 換天賦：職業層的 9100 忘掉 ⇒ 不列（hideUnknown），簽章變了 ⇒ CatalogChanged
    C.Refresh("scopes-baseline")
    local before = countFired("CatalogChanged")
    C.Refresh("scopes-same")
    eq("沒變 ⇒ 不廣播", countFired("CatalogChanged"), before)
    learned[9100] = false
    C.Refresh("spells")
    eq("寬層沒學就不列的結果變了 ⇒ CatalogChanged", countFired("CatalogChanged"), before + 1)
    eqList("忘掉之後職業層的 9100 不列", C.Bar("essential"), { "c:1", 102, 101, "k:4" })

    ns.profile, ns.playerClass = savedProfile, savedClass
    env.C_SpellBook = nil
end

------------------------------------------------------------
-- 法術索引的作廢點（效能 #6）：目錄每重建一次（C.info 整張換新）就把 SpellIndex.dirty 標起來——
-- 覆寫法術不在目錄簽章裡，簽章沒變也可能換了
------------------------------------------------------------
do
    local savedSI = ns.SpellIndex
    ns.SpellIndex = { dirty = false }
    C.Refresh("si-dirty")
    eq("目錄重建：SpellIndex.dirty 標起來", ns.SpellIndex.dirty, true)
    ns.SpellIndex.dirty = false
    eq("版面沒變的 CheckFresh 不重建、不標髒", (function() C.CheckFresh(); return ns.SpellIndex.dirty end)(), false)
    ns.SpellIndex = savedSI
end

------------------------------------------------------------
-- 讀取端的 memo（效能修整 E2 #5）：customGen 在每個自訂項目寫入 API 之後都變；EffectiveCustom 同幀同 gen
-- 回同一張表、同一幀寫完立刻讀拿得到新的、換幀重算；Catalog.Info（自訂）／CustomEntry／Replacements 跟著作廢
------------------------------------------------------------
do
    local DB = ns.DB
    local savedProfile, savedClass, savedSpec = ns.profile, ns.playerClass, ns.specID
    local clock = 500
    env.GetTime = function() return clock end
    ns.playerClass = "PALADIN"
    ns.specID = 65
    local sp = { order = {}, groupOf = {}, hidden = {}, overrides = {} }
    ns.profile = {
        bars = {
            essential = { source = "essential", kind = "icons" },
            utility   = { source = "utility", kind = "icons" },
            buffs     = { source = "buffs", kind = "icons" },
            buffbars  = { source = "buffbars", kind = "bars" },
            g9        = { source = "custom", kind = "icons" },
        },
        spells = { [65] = sp },
    }
    layoutString = "1|B64main"
    C.Refresh("memo")

    local function Changes(name, fn)
        local before = DB.customGen
        local r = fn()
        check("customGen 變了：" .. name, DB.customGen ~= before, "還是 " .. tostring(before))
        return r
    end

    -- EffectiveCustom：同幀同 gen ⇒ 同一張
    local e1 = DB.EffectiveCustom()
    check("同幀同 gen：同一張表", DB.EffectiveCustom() == e1)
    clock = clock + 1
    check("換幀：重算（新表）", DB.EffectiveCustom() ~= e1)

    -- 同一幀寫完立刻讀：拿得到新的（作廢點在寫入出口）
    local e2 = DB.EffectiveCustom()
    local cid = Changes("AddCustom（CustomList(true)）", function()
        return DB.AddCustom({ kind = "spell", spellID = 9300, bar = "essential" })
    end)
    local e3 = DB.EffectiveCustom()
    check("同幀寫完立刻讀：新表", e3 ~= e2)
    eq("同幀寫完立刻讀：新的那筆在", e3[#e3] and e3[#e3].id, "c:" .. tostring(cid))
    local info = C.Info("c:1")
    check("Info：同幀同 gen 回同一張", info ~= nil and C.Info("c:1") == info)
    eq("CustomEntry：查得到", (C.CustomEntry("c:1") or {}).spellID, 9300)

    local wid = Changes("AddCustomTo 職業層（ScopeList(true)）", function()
        return DB.AddCustomTo("class", { kind = "spell", spellID = 9400, bar = "essential" })
    end)
    eq("CustomEntry：同幀新增的寬層查得到", (C.CustomEntry(wid) or {}).spellID, 9400)
    Changes("AddCustomTo 戰隊層", function() DB.AddCustomTo("shared", { kind = "aura", spellID = 8100, bar = "buffs" }) end)
    Changes("SetCustomBar", function() DB.SetCustomBar("c:1", "g9") end)
    eq("Info：同幀改了條 ⇒ 讀得到新的條", C.Info("c:1") and C.Info("c:1").bar, "g9")
    local moved = Changes("MoveCustomScope", function() return DB.MoveCustomScope(wid, "shared") end)
    check("MoveCustomScope 成功", moved ~= nil)
    eq("CustomEntry：搬走的舊 id 查不到", C.CustomEntry(wid), nil)
    Changes("CopyCustomEntry", function() DB.CopyCustomEntry("c:1", 66) end)
    Changes("RemoveCustom（專精層）", function() DB.RemoveCustom("c:1") end)
    eq("CustomEntry：同幀刪掉 ⇒ 查不到", C.CustomEntry("c:1"), nil)
    Changes("RemoveCustom（寬層）", function() DB.RemoveCustom(moved) end)
    Changes("DeleteBar（自訂項目回家）", function() DB.DeleteBar("g9") end)
    Changes("TouchCustom（設定頁直接改欄位）", function() DB.TouchCustom() end)

    -- 只讀不動世代
    local g = DB.customGen
    DB.EffectiveCustom(); DB.CustomList(false); DB.ScopeList("class", false); DB.CustomEntry("w:1"); C.Info("w:1")
    eq("只讀不動 customGen", DB.customGen, g)

    -- Replacements：同幀同鍵 ⇒ 同一張；覆寫寫入、hidden 寫入（SpecSpells(true)）、收養 ⇒ 同幀就作廢
    sp = ns.profile.spells[65]
    local a1 = C.Replacements()
    check("Replacements：同幀同鍵 ⇒ 同一張", C.Replacements() == a1)
    DB.SetOverride(102, "replaceWith", 301)
    eq("Replacements：同幀寫覆寫 ⇒ 立刻成立", C.ReplaceTarget(102), 301)
    DB.SpecSpells(true).hidden[102] = true
    eq("Replacements：同幀寫 hidden ⇒ 立刻不成立", C.ReplaceTarget(102), nil)
    DB.SpecSpells(true).hidden[102] = nil
    eq("Replacements：同幀拿掉 hidden ⇒ 回來", C.ReplaceTarget(102), 301)
    local bg = C.buildGen
    C.Adopt({ essential = { 777 } })
    check("Adopt 收養 ⇒ buildGen 變", C.buildGen ~= bg)
    local a2 = C.Replacements()
    clock = clock + 1
    check("Replacements：換幀 ⇒ 新表", C.Replacements() ~= a2)

    -- 換專精、換設定檔：鍵裡有專精／設定檔
    local e4 = DB.EffectiveCustom()
    ns.specID = 66
    check("EffectiveCustom：換專精 ⇒ 新表", DB.EffectiveCustom() ~= e4)
    ns.specID = 65

    ns.profile, ns.playerClass, ns.specID = savedProfile, savedClass, savedSpec
    env.GetTime = nil
    C.Refresh("memo-done")
end

------------------------------------------------------------
-- 格數上限＋溢出（Core/Overflow.lua）：C.Bar 套溢出、withHidden 只回 base、GroupTargets、
-- 接收條算「有光環格」、佔位判斷、memo 的鍵
------------------------------------------------------------
do
    LoadInto(here .. "/../Core/Overflow.lua")
    local function keys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = k end
        table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
        return out
    end
    local savedProfile, savedSpec = ns.profile, ns.specID
    layoutString = "1|B64main"
    C.Refresh("overflow")
    ns.specID = 65
    -- 核心 {102, 701, 202}、輔助 {201, 101}、增益圖示 {301, 302}、增益長條 {401}
    local sp = { order = {}, groupOf = {}, hidden = {}, overrides = {} }
    local function Icons(src, max, to)
        return { source = src, kind = "icons", layout = { maxIcons = max, overflowTo = to } }
    end
    ns.profile = {
        barOrder = { "essential", "utility", "buffs", "buffbars", "g1" },
        bars = {
            essential = Icons("essential", 0, false),
            utility   = Icons("utility", 0, false),
            buffs     = Icons("buffs", 0, false),
            buffbars  = { source = "buffbars", kind = "bars", layout = {} },
            g1        = Icons("custom", 0, false),
        },
        spells = { [65] = sp },
    }
    eqList("沒設 ⇒ 核心照舊", C.Bar("essential"), { 102, 701, 202 })
    eq("沒設 ⇒ Overflow() nil", C.Overflow(), nil)
    eq("沒設 ⇒ OverflowPairs nil", C.OverflowPairs(), nil)

    ns.profile.bars.essential.layout.maxIcons = 2
    eqList("有上限沒目標 ⇒ 不截斷", C.Bar("essential"), { 102, 701, 202 })
    ns.profile.bars.essential.layout.overflowTo = "utility"
    eqList("核心留兩顆", C.Bar("essential"), { 102, 701 })
    eqList("輔助尾端接溢來的", C.Bar("utility"), { 201, 101, 202 })
    eqList("BarBase：核心照舊", C.BarBase("essential"), { 102, 701, 202 })
    do
        local vis, hid = C.Bar("essential", true)
        eqList("withHidden 只回 base（設定頁自己畫溢出）", vis, { 102, 701, 202 })
        eqList("withHidden 第二張照舊", hid, {})
        local u = C.Bar("utility", true)
        eqList("withHidden：接收條不含溢來的", u, { 201, 101 })
    end
    local b1 = C.Bar("utility")
    b1[1] = "x"
    eqList("C.Bar 回的是複本", C.Bar("utility"), { 201, 101, 202 })
    eq("不帶 withHidden 回兩個值", select("#", C.Bar("utility")), 2)
    -- 順序覆寫：溢出的是 order 後的最後幾顆
    sp.order.essential = { 202, 102, 701 }
    eqList("order：核心留 order 的前兩顆", C.Bar("essential"), { 202, 102 })
    eqList("order：溢出的是 701", C.Bar("utility"), { 201, 101, 701 })
    sp.order.essential = nil
    -- 被移除的不算顆數
    sp.hidden[701] = true
    eqList("hidden 的不算：剛好兩顆", C.Bar("essential"), { 102, 202 })
    eqList("hidden 的不算：沒有溢出", C.Bar("utility"), { 201, 101 })
    sp.hidden[701] = nil

    -- 佔位判斷（Bars 交進來）：202 沒框 ⇒ 不佔位 ⇒ 留在核心
    C.SetOccupancy(function(_, id) return id ~= 701 end, {})
    eqList("occ：不佔位的不算、不搬", C.Bar("essential"), { 102, 701, 202 })
    eqList("occ：輔助照舊", C.Bar("utility"), { 201, 101 })
    C.SetOccupancy(nil, nil)

    -- 以增益取代：A 溢出去之後 B 照樣從每一條拿掉（Replacements 看 placed，不看條）
    sp.overrides[202] = { replaceWith = 301 }
    eq("取代：A 溢到輔助也成立", C.ReplaceTarget(202), 301)
    eqList("取代：B 照樣從增益圖示拿掉", C.Bar("buffs"), { 302 })
    eqList("取代：A 在接收條上", C.Bar("utility"), { 201, 101, 202 })
    sp.overrides[202] = nil

    -- 成立條件不成立 ⇒ 整條照舊
    ns.profile.bars.utility.layout.maxIcons = 1
    eqList("目標自己有上限 ⇒ 不截斷", C.Bar("essential"), { 102, 701, 202 })
    ns.profile.bars.utility.layout.maxIcons = 0
    ns.profile.bars.essential.layout.overflowTo = "buffbars"
    eqList("目標是長條類 ⇒ 不截斷", C.Bar("essential"), { 102, 701, 202 })
    ns.profile.bars.essential.layout.overflowTo = "nope"
    eqList("目標不存在 ⇒ 不截斷", C.Bar("essential"), { 102, 701, 202 })

    -- GroupTargets：來源條受影響 ⇒ 接收條也算
    ns.profile.bars.essential.layout.overflowTo = "g1"
    eqList("溢到群組：群組尾端", C.Bar("g1"), { 202 })
    eqList("GroupTargets：核心檢視器有動靜 ⇒ 接收條", keys(C.GroupTargets("essential")), { "g1" })
    eqList("GroupTargets：別條檢視器不算", keys(C.GroupTargets("utility")), {})
    eqList("GroupTargets：傳進來的表裡已經有來源條（認領）也算",
        keys(C.GroupTargets("buffs", { essential = true })), { "essential", "g1" })
    eqList("GroupTargets：接收條的動靜不牽動來源條", keys(C.GroupTargets("g1")), {})
    -- 以增益取代＋溢出：B 在增益圖示 ⇒ A 所在的條（核心）⇒ 接著接收條
    sp.overrides[202] = { replaceWith = 301 }
    eqList("GroupTargets：取代那一段算到核心 ⇒ 溢出那一段再算到群組", keys(C.GroupTargets("buffs")), { "essential", "g1" })
    sp.overrides[202] = nil

    -- 接收條算「有光環格」（固定格位強制、不能跟著游標）：成立的來源條上有光環格才算
    local savedEff = ns.DB.EffectiveCustom
    ns.DB.EffectiveCustom = function()
        return { { id = "c:1", entry = { kind = "aura", spellID = 1, bar = "essential" } } }
    end
    eq("BarHasAuraSlot：來源條自己", C.BarHasAuraSlot("essential"), true)
    eq("BarHasAuraSlot：接收條也算", C.BarHasAuraSlot("g1"), true)
    eq("BarHasAuraSlot：無關的條", C.BarHasAuraSlot("utility"), false)
    ns.profile.bars.essential.layout.maxIcons = 0
    eq("BarHasAuraSlot：溢出不成立 ⇒ 接收條不算", C.BarHasAuraSlot("g1"), false)
    ns.profile.bars.essential.layout.maxIcons = 2
    ns.DB.EffectiveCustom = savedEff

    -- memo：同幀同鍵回同一份；Bars.flushes、occ 代號、設定檔換了就重算
    local clock = 900
    env.GetTime = function() return clock end
    local savedBars = ns.Bars
    ns.Bars = { flushes = 1 }
    local r1 = C.Overflow()
    check("memo：同幀同鍵同一份", r1 ~= nil and C.Overflow() == r1)
    ns.Bars.flushes = 2
    local r2 = C.Overflow()
    check("memo：flushes 變了 ⇒ 重算", r2 ~= r1)
    C.SetOccupancy(function() return true end, {})
    check("memo：occ 代號換了 ⇒ 重算", C.Overflow() ~= r2)
    local r3 = C.Overflow()
    ns.DB.SpecSpells(true).hidden[701] = true
    check("memo：hidden 寫入（overrideGen）⇒ 同幀重算", C.Overflow() ~= r3)
    eqList("memo：同幀寫 hidden 立刻反映", C.Bar("essential"), { 102, 202 })
    ns.DB.SpecSpells(true).hidden[701] = nil
    local r4 = C.Overflow()
    clock = clock + 1
    check("memo：換幀 ⇒ 重算", C.Overflow() ~= r4)
    C.SetOccupancy(nil, nil)
    env.GetTime = nil
    ns.Bars = savedBars

    -- BarKeys：barOrder 在前、其他照字母
    ns.profile.bars.z9 = Icons("custom", 0, false)
    ns.profile.bars.a1 = Icons("custom", 0, false)
    eqList("BarKeys", C.BarKeys(), { "essential", "utility", "buffs", "buffbars", "g1", "a1", "z9" })

    ns.profile, ns.specID = savedProfile, savedSpec
    C.Refresh("overflow-done")
end

print(("Catalog_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
