------------------------------------------------------------
-- MiliUIDB.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua AddOns/MiliUI/Libs/MiliUIDB/Tests/MiliUIDB_test.lua
--   （.claude/scripts/run_tests.sh 會一起跑）
--
-- 重點不是「函式會動」，而是**跟各插件原本那份一模一樣**：下面把換掉之前的四種
-- MergeDefaults（套組通用版、單位框的 USER_SIZED_ARRAYS 版、冷卻管理器的 ATOMIC 版、
-- 小地圖版）逐字抄進來當對照組，餵同一批存檔，結果要逐鍵相等。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local LIB_PATH = here .. "/../MiliUIDB.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

-- 載入：模擬 WoW 給 addon 檔的兩個 vararg（名字、私有表）
local ns = {}
local chunk = assert(loadfile(LIB_PATH))
chunk("MiliUIDB_test", ns)
local M = ns.MiliUIDB
check("掛在 ns.MiliUIDB", type(M) == "table")

------------------------------------------------------------
-- 對照組：換掉之前各插件的原文
------------------------------------------------------------
local function CopyTable(t)       -- WoW 的 CopyTable，純資料版
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and CopyTable(v) or v end
    return o
end

-- 套組通用版（Merchant／ShoppingList／Tooltip／Skin／QuestTracker… 十三支一字不差）
local function OldSimple(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = CopyTable(v)
            else
                OldSimple(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- 小地圖版
local function OldMinimap(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            OldMinimap(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- 單位框版
local USER_SIZED_ARRAYS = { texts = true }
local function OldUF(dst, src)
    for k, v in pairs(src) do
        local cur = dst[k]
        if USER_SIZED_ARRAYS[k] and type(cur) == "table" and cur[1] ~= nil then
            for i = 1, #cur do
                if type(cur[i]) == "table" and type(v[i]) == "table" then
                    OldUF(cur[i], v[i])
                end
            end
        elseif type(v) == "table" then
            if type(cur) ~= "table" then dst[k] = {}; cur = dst[k] end
            OldUF(cur, v)
        elseif cur == nil then
            dst[k] = v
        end
    end
end

-- 冷卻管理器版
local ATOMIC = setmetatable({}, { __mode = "k" })
local function Atomic(t) ATOMIC[t] = true; return t end
local function OldCDM(dst, src)
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" then
            local fresh = cur == nil
            if fresh then
                cur = {}
                dst[k] = cur
            end
            if type(cur) == "table" and (fresh or not ATOMIC[v]) then
                OldCDM(cur, v)
            end
        elseif cur == nil then
            dst[k] = v
        end
    end
end

------------------------------------------------------------
-- 深比對
------------------------------------------------------------
local function Same(a, b, path)
    path = path or ""
    if type(a) ~= type(b) then return false, path .. " type " .. type(a) .. " vs " .. type(b) end
    if type(a) ~= "table" then
        if a == b then return true end
        return false, path .. " " .. tostring(a) .. " vs " .. tostring(b)
    end
    for k, v in pairs(a) do
        local ok, why = Same(v, b[k], path .. "." .. tostring(k))
        if not ok then return false, why end
    end
    for k in pairs(b) do
        if a[k] == nil then return false, path .. "." .. tostring(k) .. " only in second" end
    end
    return true
end

local function Defaults()
    return {
        schemaVersion = 3,
        scale = 1, enabled = true, hidden = false, name = "x",
        anchor = { x = 0, y = 0, p = "CENTER" },
        color = { r = 1, g = 0, b = 0, a = 1 },
        texts = { { size = 12, color = { r = 1, g = 1, b = 1 } }, { size = 10, color = { r = 0, g = 0, b = 0 } }, { size = 8 } },
        reaction = { "a", "b", "c" },
        rules = Atomic({ { check = 1, color = { r = 1 } }, { check = 2 } }),
        nested = { deep = { deeper = { v = 1 } }, list = {} },
    }
end

-- 各種存檔：缺鍵、多鍵、false 蓋表、數字蓋表、短陣列、空表、自己的規則
local function Fixtures()
    return {
        {},
        { scale = 2, hidden = true, extra = "keep me", anchor = { x = 5 } },
        { anchor = false, color = 7, name = false },
        { texts = { { size = 20 } }, reaction = { "z" } },
        { texts = {}, rules = {}, nested = { list = { 1, 2 }, deep = false } },
        { rules = { { check = 9, mine = true } }, color = { r = 0.5 } },
        { schemaVersion = 1, nested = { deep = { deeper = { v = 2, w = 3 } } } },
    }
end

local function CompareAll(label, old, opts)
    for i, fx in ipairs(Fixtures()) do
        local a, b = CopyTable(fx), CopyTable(fx)
        old(a, Defaults())
        M.MergeDefaults(b, Defaults(), opts)
        local ok, why = Same(a, b)
        check(label .. " 存檔 #" .. i, ok, why)
    end
end

CompareAll("通用版", OldSimple, nil)
CompareAll("小地圖版", OldMinimap, nil)
CompareAll("單位框版", OldUF, { userSized = USER_SIZED_ARRAYS })
CompareAll("冷卻管理器版", OldCDM, { atomic = ATOMIC, keepScalar = true })

-- 直接驗幾條語意，免得對照組跟實作一起錯
do
    local db = { hidden = false, gone = 1 }
    M.MergeDefaults(db, { hidden = true, color = { r = 1 } })
    eq("false 不被補成 true", db.hidden, false)
    eq("預設沒有的鍵不回收", db.gone, 1)
    eq("缺的表補上", db.color and db.color.r, 1)
    check("回傳 dst", M.MergeDefaults(db, {}) == db)

    local d = Defaults()
    local out = M.MergeDefaults({}, d)
    out.anchor.x = 99
    eq("補進去的是拷貝不是預設值本身", d.anchor.x, 0)

    local a = { anchor = false }
    M.MergeDefaults(a, { anchor = { x = 1 } })
    eq("預設行為：false 被換成表", type(a.anchor), "table")
    local b = { anchor = false }
    M.MergeDefaults(b, { anchor = { x = 1 } }, { keepScalar = true })
    eq("keepScalar：false 保留", b.anchor, false)

    local c = { texts = { { size = 1 } } }
    M.MergeDefaults(c, { texts = { { size = 2, y = 0 }, { size = 3 } } }, { userSized = { texts = true } })
    eq("userSized：不補洞", #c.texts, 1)
    eq("userSized：既有條目補鍵", c.texts[1].y, 0)
    eq("userSized：既有值不動", c.texts[1].size, 1)

    local at = setmetatable({}, { __mode = "k" })
    local rules = { { a = 1 } }; at[rules] = true
    local e = { rules = {} }
    M.MergeDefaults(e, { rules = rules }, { atomic = at })
    eq("atomic：有鍵（空表）就不灌", #e.rules, 0)
    local f = {}
    M.MergeDefaults(f, { rules = rules }, { atomic = at })
    eq("atomic：沒鍵才整張給", f.rules[1].a, 1)
end

------------------------------------------------------------
-- Migrate
------------------------------------------------------------
do
    local log = {}
    local steps = {
        [2] = function(t) t.v2 = true; log[#log + 1] = 2 end,
        [3] = function() error("boom") end,
        [5] = function(t, v) t.v5 = v; log[#log + 1] = 5 end,
    }
    local errs = {}
    local t = {}
    local ran, bad = M.Migrate(t, steps, 1, 5, function(v, err) errs[#errs + 1] = v end)
    eq("跑了三步", ran, 3)
    eq("炸了一步", bad, 1)
    eq("炸的那步回報版本號", errs[1], 3)
    eq("炸了其他步照跑", t.v5, 5)
    eq("順序由小到大", log[1] * 10 + log[2], 25)

    t = {}
    ran = M.Migrate(t, steps, 5, 5)
    eq("from == to 不跑", ran, 0)
    ran = M.Migrate(t, steps, nil, 2)
    eq("from nil 當 0", ran, 1)
    ran = M.Migrate(nil, steps, 0, 5)
    eq("target 不是表就不跑", ran, 0)
    ran = M.Migrate(t, steps, "2", "5", function() end)
    eq("字串版本號也吃", ran, 2)
end

------------------------------------------------------------
-- Versioned
------------------------------------------------------------
do
    local CUR = 5
    -- 全新
    local sv = {}
    local from = M.Versioned(sv, CUR, function() error("不該跑") end)
    eq("全新：不跑", from, nil)
    eq("全新：寫版本號", sv.schemaVersion, CUR)
    eq("全新：seen 推到目前", sv.schemaVersionSeen, CUR)

    -- 舊版
    sv = { schemaVersion = 2 }
    local got, gotSeen
    from = M.Versioned(sv, CUR, function(f, s) got, gotSeen = f, s end)
    eq("舊版：回 from", from, 2)
    eq("舊版：run 收到 from", got, 2)
    eq("舊版：沒 seen 時 seen == from", gotSeen, 2)
    eq("舊版：版本號寫成目前", sv.schemaVersion, CUR)
    eq("舊版：seen 推到目前", sv.schemaVersionSeen, CUR)

    -- 退版再升版：seen 比 from 高
    sv = { schemaVersion = 2, schemaVersionSeen = 4 }
    M.Versioned(sv, CUR, function(f, s) got, gotSeen = f, s end)
    eq("升回來：from 是存檔的", got, 2)
    eq("升回來：seen 是看過的最高", gotSeen, 4)

    -- 來自較新版
    sv = { schemaVersion = 9 }
    from = M.Versioned(sv, CUR, function() error("不該跑") end)
    eq("較新版：不跑", from, nil)
    eq("較新版：壓回目前", sv.schemaVersion, CUR)
    eq("較新版：記住看過 9", sv.schemaVersionSeen, 9)

    -- 相同
    sv = { schemaVersion = CUR }
    from = M.Versioned(sv, CUR, function() error("不該跑") end)
    eq("同版：不跑", from, nil)
    eq("同版：seen 補上", sv.schemaVersionSeen, CUR)

    -- 不記 seen 的簡單插件
    sv = { schemaVersion = 9 }
    M.Versioned(sv, CUR, nil, { seenKey = false })
    eq("seenKey=false：不寫 seen", sv.schemaVersionSeen, nil)
    eq("seenKey=false：仍壓回目前", sv.schemaVersion, CUR)

    -- 自訂欄位名（小地圖的 dbVersion）
    sv = { dbVersion = 1 }
    from = M.Versioned(sv, 2, function(f) got = f end, { key = "dbVersion", seenKey = false })
    eq("自訂 key：跑", from, 1)
    eq("自訂 key：寫回", sv.dbVersion, 2)

    -- legacy：沒有版本號欄位的舊存檔
    sv = { something = 1 }
    from = M.Versioned(sv, 3, function(f) got = f end, { legacy = 1, seenKey = false })
    eq("legacy：從 legacy 起跑", from, 1)
    eq("legacy：寫回目前", sv.schemaVersion, 3)

    -- 字串版本號
    sv = { schemaVersion = "2" }
    from = M.Versioned(sv, CUR, function() end, { seenKey = false })
    eq("字串版本號當數字", from, 2)

    -- 壞參數
    eq("sv 不是表", M.Versioned(nil, CUR), nil)
end

print(("MiliUIDB: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
