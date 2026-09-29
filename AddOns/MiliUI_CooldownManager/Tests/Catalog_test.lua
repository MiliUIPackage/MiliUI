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
-- 設定面板開關的暫停與「沒變就不重讀」、profile 的 order／groupOf／hidden 套用。
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

local chunk, err
if setfenv then
    chunk, err = loadfile(PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
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
local b1 = C.Bar("essential")
b1[1] = "x"
eqList("回傳的是新表", C.Bar("essential"), { 202, 201 })
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

print(("Catalog_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
