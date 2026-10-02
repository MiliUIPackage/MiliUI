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

print(("Catalog_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
