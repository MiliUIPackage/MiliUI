------------------------------------------------------------
-- 筆記資料模型
--
-- 一筆筆記 = { id, title, blocks = { ... }, time }
-- 一個區塊 = { type = "text"/"checkbox"/"bullet"/"number", text, checked, indent }
--
-- 三個存放處，結構一樣、入口不同：
--   帳號層（戰隊共用）   db.notes                       陣列，順序可拖曳
--   分身層（角色專屬）   db.charNotes[charKey].notes    同上，另帶 meta
--   副本層（副本／首領） db.instanceNotes[instanceID]   一個副本一筆總覽 ＋ 每隻首領一筆
--
-- 副本層刻意**一格一筆**（不是清單）：走進副本時要能毫不猶豫地決定「顯示哪一筆」，
-- 有清單就得再問玩家一次。
------------------------------------------------------------
local _, ns = ...

ns.Notes = {}
local Notes = ns.Notes

------------------------------------------------------------
-- 常數
------------------------------------------------------------
Notes.SCOPE_ACCOUNT = "account"
Notes.SCOPE_CHAR    = "char"
Notes.SCOPE_INSTANCE = "instance"

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

-- scope + charKey → 陣列。副本層不走這裡（它不是清單）
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
-- 副本層
--
-- entry = {
--   meta  = { name, isRaid },
--   diffs = { [key] = { overview = note, bosses = { [encID] = note } } },
-- }
--
-- key 是 `"all"`（不分難度）或難度 ID（團本才用得到）。讀取時**該難度沒有就退回
-- all**，所以 all 的語意是「每個難度都適用的那一份」，而不是「還沒分類的那一份」。
-- 刻意不做「all ＋ 該難度疊在一起顯示」：疊起來之後編輯與分享都要回答
-- 「這一行是哪一份的」，而打副本時要的是一眼看到一份確定的內容。
------------------------------------------------------------
Notes.DIFF_ALL = "all"

local function NormalizeDiffKey(key)
    if key == nil or key == Notes.DIFF_ALL then return Notes.DIFF_ALL end
    return tonumber(key) or Notes.DIFF_ALL
end
Notes.NormalizeDiffKey = NormalizeDiffKey

function Notes.InstanceEntry(instanceID, create)
    if type(instanceID) ~= "number" then return nil end
    local db = ns.db
    local e = db.instanceNotes[instanceID]
    if type(e) ~= "table" then
        if not create then return nil end
        e = { meta = {}, diffs = {} }
        db.instanceNotes[instanceID] = e
    end
    if type(e.meta) ~= "table" then e.meta = {} end
    if type(e.diffs) ~= "table" then e.diffs = {} end

    -- 更早的結構是「一個副本一組總覽＋首領」，沒有難度這一層。就地升成 diffs.all。
    if e.overview ~= nil or type(e.bosses) == "table" then
        local bucket = e.diffs[Notes.DIFF_ALL]
        if type(bucket) ~= "table" then
            bucket = { bosses = {} }
            e.diffs[Notes.DIFF_ALL] = bucket
        end
        if type(bucket.bosses) ~= "table" then bucket.bosses = {} end
        if e.overview ~= nil and bucket.overview == nil then bucket.overview = e.overview end
        if type(e.bosses) == "table" then
            for encID, note in pairs(e.bosses) do
                if bucket.bosses[encID] == nil then bucket.bosses[encID] = note end
            end
        end
        e.overview, e.bosses = nil, nil
    end
    return e
end

function Notes.Bucket(instanceID, diffKey, create)
    local e = Notes.InstanceEntry(instanceID, create)
    if not e then return nil end
    diffKey = NormalizeDiffKey(diffKey)
    local b = e.diffs[diffKey]
    if type(b) ~= "table" then
        if not create then return nil end
        b = { bosses = {} }
        e.diffs[diffKey] = b
    end
    if type(b.bosses) ~= "table" then b.bosses = {} end
    return b
end

function Notes.GetInstanceNote(instanceID, encounterID, diffKey)
    local b = Notes.Bucket(instanceID, diffKey, false)
    if not b then return nil end
    if encounterID then return b.bosses[encounterID] end
    return b.overview
end

-- 「現在該顯示哪一份」：指定難度寫過就用它，沒有就退回 all。
-- 回傳 note（可能是 nil）, 實際用到的難度 key
function Notes.ResolveInstanceNote(instanceID, encounterID, diffKey)
    diffKey = NormalizeDiffKey(diffKey)
    if diffKey ~= Notes.DIFF_ALL then
        local note = Notes.GetInstanceNote(instanceID, encounterID, diffKey)
        if note and not Notes.IsEmpty(note) then return note, diffKey end
    end
    return Notes.GetInstanceNote(instanceID, encounterID, Notes.DIFF_ALL), Notes.DIFF_ALL
end

-- 沒有就開一格（會順手把副本／首領名字記進 meta 與 title，之後就算冒險指南
-- 查不到也還顯示得出名字）
function Notes.EnsureInstanceNote(instanceID, encounterID, diffKey, title, meta)
    local e = Notes.InstanceEntry(instanceID, true)
    if not e then return nil end
    if type(meta) == "table" then
        for k, v in pairs(meta) do e.meta[k] = v end
    end
    local b = Notes.Bucket(instanceID, diffKey, true)
    if not b then return nil end

    -- ⚠ 不要寫成 `encounterID and b.bosses[id] or b.overview` —— 那一格還沒建立時
    --   `and` 這半邊是 nil，整條會**掉到總覽那一筆**。
    local note
    if encounterID then note = b.bosses[encounterID] else note = b.overview end
    if not note then
        note = Notes.New(title)
        if encounterID then b.bosses[encounterID] = note else b.overview = note end
    elseif title and title ~= "" then
        note.title = title      -- 冒險指南的名字才是權威，語言換了要跟著換
    end
    Notes.EnsureBlocks(note)
    return note
end

function Notes.SetInstanceNote(instanceID, encounterID, diffKey, note)
    local b = Notes.Bucket(instanceID, diffKey, true)
    if not b then return end
    if encounterID then b.bosses[encounterID] = note else b.overview = note end
end

function Notes.DeleteInstanceNote(instanceID, encounterID, diffKey)
    local b = Notes.Bucket(instanceID, diffKey, false)
    if not b then return end
    if encounterID then b.bosses[encounterID] = nil else b.overview = nil end

    -- 空掉的難度收掉，整個副本都空了就把那格拿掉 —— 「只顯示寫過的」才不會留空殼
    local e = ns.db.instanceNotes[instanceID]
    if type(e) ~= "table" then return end
    for key, bucket in pairs(e.diffs) do
        if bucket.overview == nil and next(bucket.bosses) == nil then e.diffs[key] = nil end
    end
    if next(e.diffs) == nil then ns.db.instanceNotes[instanceID] = nil end
end

-- 這個難度有沒有寫過東西（清單的小圓點用）
function Notes.BucketHasNotes(instanceID, diffKey)
    local b = Notes.Bucket(instanceID, diffKey, false)
    if not b then return false end
    if b.overview and not Notes.IsEmpty(b.overview) then return true end
    for _, note in pairs(b.bosses) do
        if not Notes.IsEmpty(note) then return true end
    end
    return false
end

-- 這個副本任何一個難度有沒有寫過東西
function Notes.InstanceHasNotes(instanceID)
    local e = Notes.InstanceEntry(instanceID, false)
    if not e then return false end
    for key in pairs(e.diffs) do
        if Notes.BucketHasNotes(instanceID, key) then return true end
    end
    return false
end

-- 這個副本寫過哪些難度（給難度選單標小圓點）
function Notes.WrittenDifficulties(instanceID)
    local out = {}
    local e = Notes.InstanceEntry(instanceID, false)
    if not e then return out end
    for key in pairs(e.diffs) do
        if Notes.BucketHasNotes(instanceID, key) then out[key] = true end
    end
    return out
end

------------------------------------------------------------
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
local PROTOCOL   = "MNOTE2"
local PROTOCOL_1 = "MNOTE1"

-- info = { kind = "note"/"instance"/"boss", instanceID, encounterID, diff, context }
function Notes.Serialize(note, info)
    if type(note) ~= "table" then return nil end
    Notes.EnsureBlocks(note)
    info = info or {}
    local out = {
        PROTOCOL,
        Esc(info.kind or "note"),
        Esc(info.instanceID or ""),
        Esc(info.encounterID or ""),
        Esc(info.diff or Notes.DIFF_ALL),
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

    local info = {
        kind        = Unesc(f[2]),
        instanceID  = tonumber(f[3]),
        encounterID = tonumber(f[4]),
    }
    if headLen == 7 then
        info.diff    = NormalizeDiffKey(Unesc(f[5]))
        info.context = Unesc(f[6])
    else
        info.diff    = Notes.DIFF_ALL
        info.context = Unesc(f[5])
    end

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

    -- 副本層：格數不多（有寫過的副本才會存在），登入時清一次不貴。
    -- InstanceEntry 順便把舊的「沒有難度那一層」結構就地升上來。
    for id, e in pairs(db.instanceNotes) do
        if type(e) ~= "table" or type(id) ~= "number" then
            db.instanceNotes[id] = nil
        else
            Notes.InstanceEntry(id, false)
            for key, bucket in pairs(e.diffs) do
                if type(bucket) ~= "table" or not (key == Notes.DIFF_ALL or type(key) == "number") then
                    e.diffs[key] = nil
                else
                    if type(bucket.bosses) ~= "table" then bucket.bosses = {} end
                    if bucket.overview and not SanitizeNote(bucket.overview) then
                        bucket.overview = nil
                    end
                    for encID, note in pairs(bucket.bosses) do
                        if type(encID) ~= "number" or not SanitizeNote(note) then
                            bucket.bosses[encID] = nil
                        end
                    end
                end
            end
        end
    end

    -- 當前角色 meta：每次登入刷新，下拉才顯示得出職業圖示與職業色
    local key, name, realm = ns.CurrentCharKey()
    local entry = Notes.CharEntry(key)
    entry.meta.name  = name
    entry.meta.realm = realm
    entry.meta.class = ns.playerClass
    -- 只清當前角色；其他分身首次檢視時才清（見 Notes.CharList）
    Notes.CharList(key)
end
