------------------------------------------------------------
-- Core/Record.lua（/mtip record 記錄模式）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Record_test.lua
--
-- 覆蓋：序列化（秘密值標記、函式丟掉、秘密 key 略過、深度上限）、FontString 撿行、
-- 去重 key、上限、post-call 入口（關著不記、比價風暴只留一筆、滿了只提醒一次）、指令。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local SECRET = H.SECRET

local printed = {}
local env = H.Env({ print = function(s) printed[#printed + 1] = s end })
env.MiliUI_Tooltip_DB = {}
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
H.Load(env, ns, "Libs/MiliUIWidgets/Secret.lua")
H.Load(env, ns, "Core/Record.lua")
local R = ns.Record

------------------------------------------------------------
-- 1. 序列化
------------------------------------------------------------
do
    local color = { r = 1, g = 0.5, b = 0, a = 1, GetRGB = function() end }
    local data = {
        type = 0, id = 19019, hyperlink = "|Hitem:19019|h[x]|h",
        lines = {
            { type = 23, lineIndex = 1, leftText = "Thunderfury", leftColor = color },
            { type = 0, lineIndex = 2, leftText = SECRET, rightText = "x", price = SECRET },
        },
        [SECRET] = "秘密 key 的欄位",
        deep = { a = { b = { c = { d = { e = 1 } } } } },
    }
    local out = R.Serialize(data)
    eq("序列化：數字", out.id, 19019)
    eq("序列化：行文字", out.lines[1].leftText, "Thunderfury")
    eq("序列化：顏色分量", out.lines[1].leftColor.g, 0.5)
    eq("序列化：顏色的函式丟掉", out.lines[1].leftColor.GetRGB, nil)
    eq("序列化：秘密值標記", out.lines[2].leftText, "<secret>")
    eq("序列化：秘密 price 標記", out.lines[2].price, "<secret>")
    local secretKeys = 0
    for k in pairs(out) do if type(k) ~= "string" and type(k) ~= "number" then secretKeys = secretKeys + 1 end end
    eq("序列化：秘密 key 整個略過", secretKeys, 0)
    eq("序列化：深度上限", out.deep.a.b.c, "<table>")
    eq("序列化：整值秘密", R.Serialize(SECRET), "<secret>")
end

------------------------------------------------------------
-- 2. 撿行、去重 key、上限
------------------------------------------------------------
local tip = H.Tip(env, "GameTooltip", {
    { left = "Thunderfury", color = { 1, 0.5, 0 } },
    { left = "Binds when picked up" },
    { left = "Item ID: 19019", color = { 1, 0.82, 0 } },     -- 別人（我們的 ID 行）後加的
})
env.GameTooltipTextLeft2.text = SECRET

do
    local lines = R.ReadLines(tip)
    eq("撿行：行數", #lines, 3)
    eq("撿行：文字", lines[1].left.text, "Thunderfury")
    eq("撿行：顏色", lines[1].left.color[2], 0.5)
    eq("撿行：秘密文字標記", lines[2].left.text, "<secret>")
    eq("撿行：右欄沒顯示", lines[1].right.shown, false)

    eq("Key：一般", R.Key("item", { id = 19019 }, 12), "item:19019:12")
    eq("Key：秘密 id", R.Key("spell", { id = SECRET }, 5), "spell:<secret>:5")
    eq("Key：沒有 id", R.Key("item", {}, 1), "item:?:1")

    local entry = R.Build(tip, "item", { id = 19019, lines = {} })
    eq("Build：語系", entry.locale, "zhTW")
    eq("Build：tip 名字", entry.tip, "GameTooltip")
    eq("Build：行數", entry.numLines, 3)
    eq("Build：key", entry.key, "item:19019:3")

    local list = {}
    eq("Add：第一筆", R.Add(list, { key = "a" }, 2), "added")
    eq("Add：同 key 去重", R.Add(list, { key = "a" }, 2), "dup")
    eq("Add：第二筆", R.Add(list, { key = "b" }, 2), "added")
    eq("Add：滿了", R.Add(list, { key = "c" }, 2), "full")
    eq("Add：滿了也先認重複", R.Add(list, { key = "a" }, 2), "dup")
    eq("Add：清單長度", #list, 2)
end

------------------------------------------------------------
-- 3. post-call 入口與指令
------------------------------------------------------------
do
    local db = env.MiliUI_Tooltip_DB
    R.OnPostCall(tip, "item", { id = 1 })
    eq("關著不記", db.dumps, nil)

    R.Command("on")
    eq("on：存帳號層", db.recording, true)
    check("on：印提醒", #printed == 1)
    for _ = 1, 25 do R.OnPostCall(tip, "item", { id = 19019, lines = {} }) end   -- 比價風暴
    eq("風暴只留一筆", #db.dumps, 1)

    tip:SetLines({ { left = "A" } })
    R.OnPostCall(tip, "item", { id = 19019, lines = {} })
    eq("行數不同另記一筆", #db.dumps, 2)
    R.OnPostCall(tip, "spell", { id = 19019, lines = {} })
    eq("型別不同另記一筆", #db.dumps, 3)

    local before = #printed
    for i = 1, R.LIMIT + 5 do R.OnPostCall(tip, "item", { id = 1000 + i, lines = {} }) end
    eq("上限", #db.dumps, R.LIMIT)
    eq("滿了只提醒一次", #printed - before, 1)

    R.Command("off")
    eq("off", db.recording, false)
    R.OnPostCall(tip, "item", { id = 5, lines = {} })
    eq("off 之後不記", #db.dumps, R.LIMIT)
    R.Command("clear")
    eq("clear 清空", #db.dumps, 0)
    R.Command("")
    check("不帶參數印狀態", printed[#printed]:find("Recording is off", 1, true) ~= nil, printed[#printed])

    -- 登入時記錄還開著 ⇒ 提醒
    db.recording = true
    local loginFrame
    -- Record.lua 載入時建了一個 PLAYER_LOGIN 框：重新載一次抓住它
    local captured = {}
    local env2 = H.Env({ print = function(s) captured[#captured + 1] = s end })
    env2.MiliUI_Tooltip_DB = { recording = true, dumps = { {}, {} } }
    local made
    local create = env2.CreateFrame
    env2.CreateFrame = function(...) made = create(...); return made end
    local ns2 = { L = ns.L }
    H.Load(env2, ns2, "Libs/MiliUIWidgets/Secret.lua")
    H.Load(env2, ns2, "Core/Record.lua")
    loginFrame = made
    loginFrame.scripts.OnEvent(loginFrame, "PLAYER_LOGIN")
    check("登入提醒", captured[1] and captured[1]:find("still on", 1, true) ~= nil, captured[1])
end

H.finish("Record_test")
