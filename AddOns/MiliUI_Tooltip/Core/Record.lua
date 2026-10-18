------------------------------------------------------------
-- 記錄模式（/mtip record on|off|clear）：滑的時候自動記下物品／法術提示的原始資料
--
-- 重繪面板的 reader 要照「真實的行長什麼樣」寫，而行的結構（型別、左右欄、顏色、
-- 別的插件後加的行）只有遊戲裡看得到。開著記錄到處滑，/reload 後 SV 裡就有一份
-- 可以直接複製成 Tests/fixtures/*.lua 的純 Lua 表。
--
--   * 入口：Core/Hooks.lua 的 OnItem／OnSpell（post-call，在 Panel.Try 之前）
--   * 每筆：data 整張結構＋當下所有 FontString 的文字與顏色＋語系＋tip 名字
--   * 秘密值不讀內容，一律標 "<secret>"（連 key 都是秘密就整個欄位略過）
--   * 去重：同一個 data.id＋型別＋行數只留一筆——比價框每秒重建二十幾次
--   * 上限 60 筆，滿了印一次提醒；存帳號層 MiliUI_Tooltip_DB.dumps（/reload 或登出才落地）
--   * 開關也存帳號層：/reload 之後還開著，登入時印一行提醒，免得忘了關
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L

ns.Record = {}
local Record = ns.Record

Record.LIMIT = 60
Record.SECRET = "<secret>"
local MAX_DEPTH = 4

------------------------------------------------------------
-- 序列化（純函式，測試直接呼叫）
------------------------------------------------------------
-- 任意值 → 可存進 SV 的純值；函式／userdata／框（table 帶 GetObjectType）丟掉
local function Ser(v, depth)
    if S.IsSecret(v) then return Record.SECRET end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" then return nil end
    if depth >= MAX_DEPTH then return "<table>" end
    if type(rawget(v, 0)) == "userdata" then return "<frame>" end   -- 框物件
    local out = {}
    for k, item in pairs(v) do
        local kt = type(k)
        if not S.IsSecret(k) and (kt == "string" or kt == "number") then
            local sv = Ser(item, depth + 1)
            if sv ~= nil then out[k] = sv end
        end
    end
    return out
end
Record.Serialize = function(v) return Ser(v, 0) end

local function PlainOrMark(v)
    if v == nil then return nil end
    if S.IsSecret(v) then return Record.SECRET end
    return v
end

-- 一顆 FontString 的現況：文字、顏色、有沒有顯示
local function ReadFontString(fs)
    if not fs then return nil end
    local ok, text = pcall(fs.GetText, fs)
    local okC, r, g, b, a = pcall(fs.GetTextColor, fs)
    local okS, shown = pcall(fs.IsShown, fs)
    local out = {}
    if ok then out.text = PlainOrMark(text) end
    if okC then out.color = { PlainOrMark(r), PlainOrMark(g), PlainOrMark(b), PlainOrMark(a) } end
    -- ⚠ 不寫成 `okS and v or nil`：false 會被吃成 nil
    if okS then out.shown = PlainOrMark(shown) end
    return out
end

-- tip 上 1..NumLines 的左右欄
function Record.ReadLines(tip)
    local out = {}
    local okN, n = pcall(tip.NumLines, tip)
    local okName, name = pcall(tip.GetName, tip)
    n = okN and S.PlainNumber(n) or 0
    name = okName and S.PlainText(name)
    if not name then return out end
    for i = 1, n do
        out[i] = {
            left = ReadFontString(_G[name .. "TextLeft" .. i]),
            right = ReadFontString(_G[name .. "TextRight" .. i]),
        }
    end
    return out
end

-- 去重 key：型別＋id＋行數（id 秘密就用標記，同型別同行數的秘密筆數只留一筆）
function Record.Key(kind, data, numLines)
    local id = type(data) == "table" and data.id or nil
    if S.IsSecret(id) then
        id = Record.SECRET
    elseif id == nil then
        id = "?"
    end
    return ("%s:%s:%d"):format(tostring(kind), tostring(id), numLines or 0)
end

function Record.Build(tip, kind, data)
    local lines = Record.ReadLines(tip)
    local okName, name = pcall(tip.GetName, tip)
    local entry = {
        kind = kind,
        locale = GetLocale(),
        tip = okName and PlainOrMark(name) or nil,
        numLines = #lines,
        data = Ser(data, 0),
        lines = lines,
    }
    entry.key = Record.Key(kind, data, #lines)
    return entry
end

-- 收進清單：回 "added"｜"dup"｜"full"
function Record.Add(list, entry, limit)
    limit = limit or Record.LIMIT
    for _, old in ipairs(list) do
        if old.key == entry.key then return "dup" end
    end
    if #list >= limit then return "full" end
    list[#list + 1] = entry
    return "added"
end

------------------------------------------------------------
-- 遊戲內接線
------------------------------------------------------------
local PREFIX = "|cff4DD2FF[" .. L["MiliUI Tooltip"] .. "]|r "
local fullWarned = false

local function Account()
    return type(MiliUI_Tooltip_DB) == "table" and MiliUI_Tooltip_DB or nil
end

function Record.IsOn()
    local db = Account()
    return db and db.recording == true or false
end

local function Store()
    local db = Account()
    if not db then return end
    if type(db.dumps) ~= "table" then db.dumps = {} end
    return db.dumps
end

-- post-call 入口。記錄關著時只付一次 boolean 檢查。
function Record.OnPostCall(tip, kind, data)
    if not Record.IsOn() then return end
    local list = Store()
    if not list then return end
    local result = Record.Add(list, Record.Build(tip, kind, data))
    if result == "full" and not fullWarned then
        fullWarned = true
        print(PREFIX .. L["Recording is full (%d entries). /reload to save them, then /mtip record clear to start over."]:format(Record.LIMIT))
    end
end

local function Status()
    local list = Store() or {}
    local fmt = Record.IsOn() and L["Recording is on (%d / %d entries)."] or L["Recording is off (%d / %d entries)."]
    print(PREFIX .. fmt:format(#list, Record.LIMIT))
end

function Record.Command(arg)
    local db = Account()
    if not db then return end
    if arg == "on" then
        db.recording = true
        fullWarned = false
        print(PREFIX .. L["Recording on: hover items and spells, then /reload to save. Turn it off with /mtip record off."])
    elseif arg == "off" then
        db.recording = false
        Status()
    elseif arg == "clear" then
        db.dumps = {}
        fullWarned = false
        Status()
    else
        Status()
    end
end

-- 開著記錄登入（/reload 之後）印一行提醒
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if Record.IsOn() then
            local list = Store() or {}
            print(PREFIX .. L["Recording is still on (%d / %d entries). /mtip record off to stop."]:format(#list, Record.LIMIT))
        end
    end)
end
