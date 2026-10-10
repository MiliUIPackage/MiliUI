------------------------------------------------------------
-- 筆記資料模型
--
-- 一筆筆記 = { id, title, blocks = { ... }, time }
-- 一個區塊 = { type = "text"/"checkbox"/"bullet"/"number", text, checked, indent }
--
-- 兩個存放處，結構一樣、入口不同：
--   帳號層（戰隊共用）   db.notes                       陣列，順序可拖曳
--   分身層（角色專屬）   db.charNotes[charKey].notes    同上，另帶 meta
--
-- 以前還有副本層（db.instanceNotes），功能已經拔掉；存檔裡留著的資料不讀也不刪。
------------------------------------------------------------
local _, ns = ...

ns.Notes = {}
local Notes = ns.Notes

------------------------------------------------------------
-- 常數
------------------------------------------------------------
Notes.SCOPE_ACCOUNT = "account"
Notes.SCOPE_CHAR    = "char"

Notes.TYPE_TEXT     = "text"
Notes.TYPE_CHECKBOX = "checkbox"
Notes.TYPE_BULLET   = "bullet"
Notes.TYPE_NUMBER   = "number"

Notes.MAX_INDENT = 5

local VALID_TYPES = {
    [Notes.TYPE_TEXT]     = true,
    [Notes.TYPE_CHECKBOX] = true,
    [Notes.TYPE_BULLET]   = true,
    [Notes.TYPE_NUMBER]   = true,
}
Notes.VALID_TYPES = VALID_TYPES

------------------------------------------------------------
-- 清理：SavedVariables 可能被手改、也可能來自更舊的版本
------------------------------------------------------------
local function SanitizeBlocks(blocks)
    if type(blocks) ~= "table" then return nil end
    local clean = {}
    for _, b in ipairs(blocks) do
        if type(b) == "table" and type(b.type) == "string" and VALID_TYPES[b.type] then
            local nb = {
                type = b.type,
                text = type(b.text) == "string" and b.text or "",
            }
            if b.type == Notes.TYPE_CHECKBOX then
                nb.checked = b.checked == true
            end
            if type(b.indent) == "number" then
                nb.indent = math.max(0, math.min(Notes.MAX_INDENT, math.floor(b.indent)))
                if nb.indent == 0 then nb.indent = nil end
            end
            clean[#clean + 1] = nb
        end
    end
    return clean
end
Notes.SanitizeBlocks = SanitizeBlocks

local function SanitizeNote(n)
    if type(n) ~= "table" or type(n.id) ~= "string" or n.id == "" then return false end
    if type(n.title) ~= "string" then n.title = ns.L["Untitled"] end
    if type(n.content) ~= "string" then n.content = nil end
    if type(n.time) ~= "number" then n.time = 0 end
    -- 區塊：有就清理，沒有就留 nil（讀取時才 migrate，登入不用碰全部筆記）
    if n.blocks ~= nil then n.blocks = SanitizeBlocks(n.blocks) end
    return true
end
Notes.SanitizeNote = SanitizeNote

local function SanitizeList(list)
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
        if not SanitizeNote(list[i]) then table.remove(list, i) end
    end
end
Notes.SanitizeList = SanitizeList

------------------------------------------------------------
-- 舊的 content 字串 → blocks（一行一個文字區塊）
--
-- 讀取時才做，而且做完就寫回 note，所以每筆只會轉一次。
------------------------------------------------------------
function Notes.EnsureBlocks(note)
    if type(note) ~= "table" then return end
    if type(note.blocks) == "table" and #note.blocks > 0 then return end
    note.blocks = {}
    if type(note.content) == "string" and note.content ~= "" then
        for line in (note.content .. "\n"):gmatch("(.-)\n") do
            note.blocks[#note.blocks + 1] = { type = Notes.TYPE_TEXT, text = line }
        end
    end
    if #note.blocks == 0 then
        note.blocks[1] = { type = Notes.TYPE_TEXT, text = "" }
    end
end

-- 「這筆筆記等於空的嗎」：覆寫確認與清單上的小圓點都靠它
function Notes.IsEmpty(note)
    if type(note) ~= "table" then return true end
    if type(note.blocks) ~= "table" then
        return type(note.content) ~= "string" or strtrim(note.content) == ""
    end
    for _, b in ipairs(note.blocks) do
        if strtrim(b.text or "") ~= "" then return false end
        if b.type == Notes.TYPE_CHECKBOX then return false end
    end
    return true
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
function Notes.GenerateID()
    return time() .. "-" .. math.random(10000, 99999)
end

function Notes.New(title)
    return {
        id     = Notes.GenerateID(),
        title  = title or ns.L["Untitled"],
        blocks = { { type = Notes.TYPE_TEXT, text = "" } },
        time   = time(),
    }
end

-- 「新筆記 N」：掃現有標題找最大的 N 再 +1
function Notes.NextTitle(list)
    local pattern = "^" .. ns.L["New note"] .. " (%d+)$"
    local maxN = 0
    for _, n in ipairs(list) do
        local num = tostring(n.title or ""):match(pattern)
        local v = num and tonumber(num)
        if v and v > maxN then maxN = v end
    end
    return ns.L["New note"] .. " " .. (maxN + 1)
end

function Notes.Touch(note)
    if type(note) == "table" then note.time = time() end
end

------------------------------------------------------------
-- 帳號層 / 分身層
------------------------------------------------------------
-- 延後清理：登入時不掃所有分身，首次存取某分身才清理
local sanitizedChars = {}

function Notes.CharEntry(key)
    local db = ns.db
    if type(db.charNotes[key]) ~= "table" then db.charNotes[key] = {} end
    local e = db.charNotes[key]
    if type(e.notes) ~= "table" then e.notes = {} end
    if type(e.meta) ~= "table" then e.meta = {} end
    return e
end

function Notes.CharList(key)
    local e = Notes.CharEntry(key)
    if not sanitizedChars[key] then
        sanitizedChars[key] = true
        SanitizeList(e.notes)
    end
    return e.notes
end

function Notes.AccountList()
    return ns.db.notes
end

-- scope + charKey → 陣列
function Notes.GetList(scope, charKey)
    if scope == Notes.SCOPE_CHAR then
        return Notes.CharList(charKey or ns.CurrentCharKey())
    end
    return Notes.AccountList()
end

-- 有「同名」的分身才需要在標籤上補伺服器名
function Notes.DuplicateNames()
    local count, dup = {}, {}
    for _, e in pairs(ns.db.charNotes) do
        local nm = type(e) == "table" and type(e.meta) == "table" and e.meta.name
        if type(nm) == "string" then count[nm] = (count[nm] or 0) + 1 end
    end
    for nm, c in pairs(count) do
        if c > 1 then dup[nm] = true end
    end
    return dup
end

-- 分身 key 排序：當前角色置頂，其餘字典序
function Notes.SortedCharKeys()
    local curKey = ns.CurrentCharKey()
    local keys = {}
    for k in pairs(ns.db.charNotes) do keys[#keys + 1] = k end
    -- 當前角色就算一筆筆記都沒有也要在清單裡（不然新分身選不到自己）
    if type(ns.db.charNotes[curKey]) ~= "table" then keys[#keys + 1] = curKey end
    table.sort(keys, function(a, b)
        if a == curKey then return true end
        if b == curKey then return false end
        return a < b
    end)
    return keys
end

------------------------------------------------------------
-- 序列化（分享用）------------------------------------------------------------
-- 序列化（分享用）
--
-- 走插件通訊頻道，而那個頻道容不下 `|`、換行與 NUL；`~` 是我們自己的欄位分隔符。
-- 逃逸之後字串裡就不會再出現生的 `~`，所以拆欄位可以直接 gmatch。
------------------------------------------------------------
local ESCAPE = {
    ["\\"] = "\\\\", ["~"] = "\\T", ["|"] = "\\P",
    ["\n"] = "\\N",  ["\r"] = "\\R", ["\0"] = "\\Z",
}
local UNESCAPE = {
    ["\\"] = "\\", T = "~", P = "|", N = "\n", R = "\r", Z = "\0",
}

local function Esc(s)
    return (tostring(s or ""):gsub("[\\~|\n\r%z]", ESCAPE))
end

local function Unesc(s)
    return (tostring(s or ""):gsub("\\(.)", function(c) return UNESCAPE[c] or c end))
end

-- v2 的表頭多了一個「難度」欄位。v1 還讀得動（只有今天這批測試版會產生），
-- 差別就是表頭 6 欄還是 7 欄、區塊從第幾欄開始。
--
-- 表頭的 kind／副本／首領／難度／context 是副本筆記時代留下的欄位。那個功能拔掉了，
-- 但格式不動：還裝著舊版的人收發都要對得上。送出一律填 kind = "note"、其餘留空。
local PROTOCOL   = "MNOTE2"
local PROTOCOL_1 = "MNOTE1"

-- info = { kind = "note" }
function Notes.Serialize(note, info)
    if type(note) ~= "table" then return nil end
    Notes.EnsureBlocks(note)
    info = info or {}
    local out = {
        PROTOCOL,
        Esc(info.kind or "note"),
        Esc(info.instanceID or ""),
        Esc(info.encounterID or ""),
        Esc(info.diff or "all"),
        Esc(info.context or ""),
        Esc(note.title or ""),
    }
    for _, b in ipairs(note.blocks) do
        out[#out + 1] = Esc(b.type)
        out[#out + 1] = tostring(b.indent or 0)
        out[#out + 1] = b.checked and "1" or "0"
        out[#out + 1] = Esc(b.text or "")
    end
    return table.concat(out, "~")
end

-- 回傳 note, info；壞掉就回 nil
function Notes.Deserialize(str)
    if type(str) ~= "string" or str == "" then return nil end
    local f = {}
    for field in (str .. "~"):gmatch("(.-)~") do f[#f + 1] = field end

    local headLen
    if f[1] == PROTOCOL then headLen = 7
    elseif f[1] == PROTOCOL_1 then headLen = 6
    else return nil end
    if #f < headLen then return nil end

    -- 副本／首領那幾欄只讀不用：舊版送來的一律當一般筆記收（見 Share.SaveIncoming）
    local info = { kind = Unesc(f[2]) }

    local note = {
        id     = Notes.GenerateID(),
        title  = Unesc(f[headLen]),
        blocks = {},
        time   = time(),
    }
    for i = headLen + 1, #f - 3, 4 do
        local btype = Unesc(f[i])
        if VALID_TYPES[btype] then
            local indent = tonumber(f[i + 1]) or 0
            local block = { type = btype, text = Unesc(f[i + 3]) }
            indent = math.max(0, math.min(Notes.MAX_INDENT, math.floor(indent)))
            if indent > 0 then block.indent = indent end
            if btype == Notes.TYPE_CHECKBOX then block.checked = (f[i + 2] == "1") end
            note.blocks[#note.blocks + 1] = block
        end
    end
    if #note.blocks == 0 then
        note.blocks[1] = { type = Notes.TYPE_TEXT, text = "" }
    end
    if note.title == "" then note.title = ns.L["Untitled"] end
    return note, info
end

------------------------------------------------------------
-- 啟動時的清理
------------------------------------------------------------
function Notes.InitDB()
    local db = ns.db
    SanitizeList(db.notes)

    -- 當前角色 meta：每次登入刷新，下拉才顯示得出職業圖示與職業色
    local key, name, realm = ns.CurrentCharKey()
    local entry = Notes.CharEntry(key)
    entry.meta.name  = name
    entry.meta.realm = realm
    entry.meta.class = ns.playerClass
    -- 只清當前角色；其他分身首次檢視時才清（見 Notes.CharList）
    Notes.CharList(key)
end
