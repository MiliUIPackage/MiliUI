------------------------------------------------------------
-- 分享自訂時間軸：匯出成字串、貼上匯入
--
-- 兩種格式：
--   * 米利字串 "!MBT1!…"：一份設定檔（含音效、條件、錨點）。前綴沿用 !MBT1!，版本看 payload.v：
--       v1（舊）{ v, id, name＝首領名, difficulty＝單一難度（0＝全部）, entries }
--       v2      { v, id, boss＝首領名, name＝設定檔名, author, difficulties = { [難度]=true }, entries }
--     走暴雪內建的 C_EncodingUtil：SerializeCBOR → CompressString（Deflate）→ EncodeBase64，
--     匯入反過來。不用 loadstring 解析別人貼來的東西 —— CBOR 解出來只會是資料。
--   * MRT 筆記行 "{time:01:30}{spell:N} 文字"：有損（只有時間、法術、文字），MRT 筆記與其他吃
--     {time:} 格式的插件讀得懂。匯入走 Plans.ImportNote。
--   * 只匯入不匯出：DreamForgeTools 的 "DSR1!…" 方案字串與 NSRT 筆記（Plans/Convert.lua 轉成
--     跟 Decode 一樣的 payload，再走 Share.Import／ImportInto／Overwrite）。
--
-- 條目的對象條件：roles／class／positions（近戰遠程）／groups（小隊 1～8）／players（名字），
-- 匯出 v2 全部帶上，匯入時一律重新清洗。
--
-- 匯入預設是**新增一份設定檔**（預設不生效，免得一貼上就跟自己的疊起來響）；「併入目前的設定檔」
-- 是選項（Share.ImportInto，同秒同法術同文字的不重複加）。
--
-- 不做團隊即時同步：首領戰與傳奇鑰石中插件通訊被封鎖（.claude/notes/wow-12x-addon-restrictions.md），
-- 戰鬥外同步價值也不高 —— 貼字串最實在。
--
-- ⚠ 匯入的東西一律當不可信資料：每個欄位檢查型別與範圍，認不得的欄位丟掉。
------------------------------------------------------------
local _, ns = ...

local Plans = ns.Plans

ns.Share = {}
local Share = ns.Share

local PREFIX = "!MBT1!"
local MAX_ENTRIES = 500
local MAX_TEXT = 120

local function Enc()
    local E = C_EncodingUtil
    if E and E.SerializeCBOR and E.CompressString and E.EncodeBase64 then return E end
end

function Share.Available()
    return Enc() ~= nil
end

------------------------------------------------------------
-- 欄位清洗（匯出與匯入共用：只留認得的欄位）
------------------------------------------------------------
local function Num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return end        -- NaN
    if lo and v < lo then return end
    if hi and v > hi then return end
    return v
end

local function Str(v, maxLen)
    if type(v) ~= "string" then return end
    v = v:gsub("[%c]", "")
    if v == "" then return end
    return v:sub(1, maxLen or MAX_TEXT)
end

local ROLES = { TANK = true, HEALER = true, DAMAGER = true }
local WHEN = { show = true, soon = true, due = true }
local POSITIONS = { melee = true, ranged = true }
local MAX_PLAYERS = 40       -- 一條提示最多指定幾個人

-- 對象條件（位置／小隊／玩家）：只收認得的值，其他丟掉；清完是空的就 nil
local function CleanPositions(v)
    if type(v) ~= "table" then return end
    local out = {}
    for p in pairs(POSITIONS) do
        if v[p] then out[p] = true end
    end
    return next(out) and out or nil
end

local function CleanGroups(v)
    if type(v) ~= "table" then return end
    local out = {}
    for g = 1, 8 do
        if v[g] then out[g] = true end
    end
    return next(out) and out or nil
end

local function CleanPlayers(v)
    if type(v) ~= "table" then return end
    local out, n = {}, 0
    for name, on in pairs(v) do
        local bare = on and Plans.BareName(Str(name, 48))
        if bare and not out[bare] then
            out[bare] = true
            n = n + 1
            if n >= MAX_PLAYERS then break end
        end
    end
    return next(out) and out or nil
end
Share.CleanPlayers = CleanPlayers

local function CleanEntry(e)
    if type(e) ~= "table" then return end
    local t = Num(e.t, 0.1, 3600)
    if not t then return end
    local out = {
        t         = t,
        text      = Str(e.text),
        spell     = Num(e.spell, 1, 1e8),
        icon      = Num(e.icon, 1, 1e8),
        lead      = Num(e.lead, 1, 120),
        sound     = Str(e.sound, 80),
        soundWhen = WHEN[e.soundWhen] and e.soundWhen or nil,
        tts       = e.tts == true or nil,
        ttsText   = e.tts == true and Str(e.ttsText, 100) or nil,
        class     = Str(e.class, 20),
        enabled   = e.enabled ~= false,
        positions = CleanPositions(e.positions),
        groups    = CleanGroups(e.groups),
        players   = CleanPlayers(e.players),
    }
    local phase = Num(e.phase, 2, 20)
    if phase then out.phase = math.floor(phase) end
    if type(e.roles) == "table" then
        local roles = {}
        for r in pairs(ROLES) do
            if e.roles[r] then roles[r] = true end
        end
        if next(roles) then out.roles = roles end
    end
    if type(e.anchor) == "table" then
        local spell, n = Num(e.anchor.spell, 1, 1e8), Num(e.anchor.n, 1, 500)
        if spell and n then
            out.anchor = { spell = spell, n = math.floor(n), offset = Num(e.anchor.offset, -600, 600) or 0 }
        end
    end
    return out
end

------------------------------------------------------------
-- 匯出
------------------------------------------------------------
-- 「角色-伺服器」：匯入的人看得到這份是誰的
local function Author()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not name then return end
    return (realm and realm ~= "") and (name .. "-" .. realm) or name
end
Share.Author = Author

function Share.Export(pid)
    local E = Enc()
    local profile, encID = Plans.Get(pid), Plans.BossOf(pid)
    if not E or not profile then return end
    local entries = {}
    for _, e in ipairs(profile.entries) do
        local c = CleanEntry(e)
        if c then entries[#entries + 1] = c end
    end
    local boss = Plans.Boss(encID)
    local payload = {
        v = 2, id = encID, boss = boss and boss.name, name = profile.name,
        author = profile.author or Author(),
        difficulties = profile.difficulties and CopyTable(profile.difficulties) or nil,
        entries = entries,
    }
    local ok, out = pcall(function()
        return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload)))
    end)
    if ok then return out end
    ns.ReportError(out)
end

-- MRT 筆記行（有損）
function Share.ExportNote(pid)
    local profile = Plans.Get(pid)
    if not profile then return "" end
    local lines = {}
    for _, e in ipairs(profile.entries) do
        local t = e.t or 0
        local m = math.floor(t / 60)
        local sec = t - m * 60
        local line = ("{time:%02d:%04.1f}"):format(m, sec)
        if e.spell then line = line .. ("{spell:%d}"):format(e.spell) end
        if e.text then line = line .. " " .. e.text end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

------------------------------------------------------------
-- 匯入
------------------------------------------------------------
function Share.IsShareString(text)
    return type(text) == "string" and strtrim(text):sub(1, #PREFIX) == PREFIX
end

local function CleanDifficulties(v)
    if type(v) ~= "table" then return end
    local out, n = {}, 0
    for key, on in pairs(v) do
        local d = Num(key, 1, 1000)
        if d and on == true and n < 20 then
            out[math.floor(d)] = true
            n = n + 1
        end
    end
    return next(out) and out or nil
end

-- 回傳清洗過的 payload（v1／v2 都整理成 v2 的欄位），或 nil, 錯誤訊息：
--   { id, boss, name（v1 是 nil）, author, difficulties, entries }
function Share.Decode(text)
    local E = C_EncodingUtil
    if not (E and E.DecodeBase64 and E.DecompressString and E.DeserializeCBOR) then
        return nil, ns.L["This game client can't read share strings."]
    end
    text = strtrim(text or ""):gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, ns.L["Not a MiliUI Boss Timeline string."] end
    local ok, data = pcall(function()
        return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(text:sub(#PREFIX + 1))))
    end)
    if not ok or type(data) ~= "table" then return nil, ns.L["The string is damaged or incomplete."] end
    local id = Num(data.id, 1, 1e8)
    if not id or type(data.entries) ~= "table" then return nil, ns.L["The string is damaged or incomplete."] end
    local out = { id = math.floor(id), entries = {} }
    if (Num(data.v) or 1) >= 2 then
        out.boss = Str(data.boss, 60)
        out.name = Str(data.name, 60)
        out.author = Str(data.author, 60)
        out.difficulties = CleanDifficulties(data.difficulties)
    else
        -- v1：name 是首領名、難度只有一個（0＝全部）
        out.boss = Str(data.name, 60)
        local d = Num(data.difficulty, 0, 1000) or 0
        if d ~= 0 then out.difficulties = { [math.floor(d)] = true } end
    end
    for i, e in ipairs(data.entries) do
        if i > MAX_ENTRIES then break end
        local c = CleanEntry(e)
        if c then out.entries[#out.entries + 1] = c end
    end
    return out
end

-- 新增一份設定檔到 payload 的首領（首領沒有就建）。預設不生效。回傳 added, skipped, profileID
-- payload.source（"import"／"dft"）、payload.dftBoardId 有給就記在設定檔上（DreamForgeTools 再匯入同一份時認得出來）
function Share.Import(payload)
    Plans.EnsureBoss(payload.id, payload.boss)
    local profile = Plans.AddProfile(payload.id, {
        name = payload.name or ns.L["Imported plan"],
        difficulties = payload.difficulties and CopyTable(payload.difficulties) or nil,
        active = false,
        source = payload.source or "import",
        author = payload.author,
        dftBoardId = payload.dftBoardId,
    })
    if not profile then return 0, 0 end
    local added, skipped = Plans.Batch(profile.id, function() return Share.ImportInto(profile.id, payload) end)
    return added, skipped, profile.id
end

-- 併進 pid 那份設定檔；同一秒同文字同法術的不重複加。回傳 added, skipped
-- （呼叫端自己決定要不要包 Plans.Batch：併入目前那份時要包，才能一步復原）
function Share.ImportInto(pid, payload)
    local profile = Plans.Get(pid)
    if not profile then return 0, 0 end
    local added, skipped = 0, 0
    for _, e in ipairs(payload.entries) do
        local dup = false
        for _, x in ipairs(profile.entries) do
            -- 同秒同字但給不同人的不算重複（DreamForgeTools 的「坦克或第 1 隊」拆成兩條就是這樣）
            if Plans.SameEntry(x, e) and Plans.SameAudience(x, e) then
                dup = true
                break
            end
        end
        if dup then
            skipped = skipped + 1
        else
            local enabled = e.enabled
            local saved = Plans.SaveEntry(pid, e)
            if saved then saved.enabled = enabled end
            added = added + 1
        end
    end
    return added, skipped
end

-- 覆蓋 pid 那份設定檔（DreamForgeTools 同一份方案再匯入、選「覆蓋」）：條目整份換掉，
-- 名稱、難度、作者跟著新的；生效與否、MRT 變體照舊。包在 Plans.Batch 裡，條目可以 Ctrl+Z 一步回到覆蓋前
-- （名稱與難度不在復原堆疊裡）。
-- 回傳 added, skipped
function Share.Overwrite(pid, payload)
    local profile = Plans.Get(pid)
    if not profile then return 0, 0 end
    return Plans.Batch(pid, function()
        profile.entries = {}
        profile.name = payload.name or profile.name
        profile.difficulties = payload.difficulties and CopyTable(payload.difficulties) or nil
        profile.author = payload.author or profile.author
        profile.source = payload.source or profile.source
        return Share.ImportInto(pid, payload)
    end)
end

-- 這隻首領底下有沒有同一份 DreamForgeTools 方案（boardId 相同）匯入過的設定檔
function Share.FindDftProfile(encID, boardId)
    local boss = boardId and Plans.Boss(encID)
    if not boss then return end
    for pid, p in pairs(boss.profiles) do
        if p.dftBoardId == boardId then return pid end
    end
end
