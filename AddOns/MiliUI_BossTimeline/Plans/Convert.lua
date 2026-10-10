------------------------------------------------------------
-- 匯入別的插件的方案：DreamForgeTools 的 "DSR1!" 字串、NSRT 筆記
--
-- 兩種都轉成跟 Share.Decode 一樣的 payload，後面照常走 Share.Import／ImportInto／Overwrite：
--   { id, boss, name, author, difficulties, entries, source, dftBoardId, stats }
--   stats = { phased, skipped, personal, notMe, phaseSkipped }（給匯入結果訊息用）
--
-- ■ DSR1!（DreamForgeTools 時間軸方案，modules/Timeline/data/codec.lua）
--   "DSR1!" .. base64url(raw deflate(JSON(envelope)))，base64url 字元集 A-Za-z0-9-_、無補位。
--   解碼一律走暴雪內建的 C_EncodingUtil（不帶 LibDeflate、不 loadstring）：
--     base64url → 標準 base64（- → +、_ → /、補 =）→ DecodeBase64 → DecompressString → DeserializeJSON
--   ⚠ LibDeflate 的 raw deflate 跟 CompressionMethod.Deflate 相不相容要實機驗：Deflate 解不開再試 Zlib。
--   envelope = { schemaVersion = 2, boardId, encID, difficulty = "M"|"H"（也可能是 14～17／233）, name,
--                version, updatedAt, exportedBy（插件匯出時固定是 "addon"，不是人名）, data }
--   data.phases          = { { phaseNumber, phaseTimer（階段起點，開戰後秒數）, phaseDuration, ... } }
--   data.players         = { { id, name（可能帶 -伺服器）, class, spec, role, ... } }
--   data.playerAbilities = { { abilityId = "class_spec_<法術ID>", playerId, time, phaseNumber } }
--   data.bossNotes       = { { time, phaseNumber, text, target = { { type = "all"|"role"|"position"|"group"|"class", value } } } }
--   data.playerNotes     = { [playerId] = { { time, phaseNumber, text } } }
--   時間是「階段內」秒數：絕對秒數＝該階段的 phaseTimer ＋ time（DFT time_model.lua 的 ToAbsolute，
--   找不到那個階段就照原值）。第 2 階段以後的照換、記 entry.phase，回報「換階段時間每場會漂」。
--   bossNotes 全收；playerNotes／playerAbilities 只收「我」（players[].name 去伺服器後等於自己）。
--   DFT 的 target 是「任一條合就給」（OR），我們的條件是「不同類 AND」：同一類（例如兩個職責）
--   併成一條，跨類（坦克 或 第 1 隊）拆成幾條同秒同字的 —— 開戰合併時同秒同字只跑一次，所以
--   兩條都合的人也只會響一次。
--
-- ■ NSRT 筆記（DFT notes_manager.lua 的 ParseNSRT 同一套讀法）
--   表頭  EncounterID:3176;Difficulty:Mythic;Name:...
--   事件  time:12;ph:2;tag:healer;spellid:123;text:...
--   ph 沒有階段起點可換算：ph 缺或 = 1 的照絕對秒數收，ph > 1 的略過並計數。
--   tag：tank／healer／dps → 職責；melee／ranged → 位置；group1～8 → 小隊；職業英文 → 職業；
--   everyone／all → 不限；其他當玩家名字（寫進 players 條件，誰匯入都能用）。
--
-- ⚠ 匯入的東西一律當不可信資料：型別、範圍、數量、長度都檢查，認不得的丟掉。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Plans = ns.Plans

ns.Convert = {}
local Convert = ns.Convert

local DSR_PREFIX = "DSR1!"
local MAX_INPUT = 2000000      -- 字串長度上限（DSR1 一份整團方案約幾十 KB）
local MAX_ENTRIES = 500        -- 跟 Share 同一個上限
local MAX_LIST = 2000          -- 每張清單最多看幾項（players／abilities／notes）
local MAX_PHASES = 30
local MAX_TEXT = 120
local DEFAULT_LEAD = Plans.DEFAULT_LEAD

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return end
    if lo and v < lo then return end
    if hi and v > hi then return end
    return v
end

local function Str(v, maxLen)
    if type(v) ~= "string" then return end
    v = strtrim((v:gsub("%c", "")))
    if v == "" then return end
    return v:sub(1, maxLen or MAX_TEXT)
end

-- 提示文字：剝色碼與 {…} 標記，第一個 {spell:N} 當法術（跟 MRT 筆記同一套）
local function TextAndSpell(raw)
    raw = type(raw) == "string" and raw:sub(1, 1000) or ""
    local spell = Num(raw:match("{[Ss][Pp][Ee][Ll][Ll]:(%d+)}"), 1, 1e8)
    local text = Str(Plans.CleanText(raw))
    return text, spell
end

-- 難度代碼 → difficultyID：M／Mythic → 傳奇（16）、H → 英雄（15）、N → 普通（14）、LFR → 隨機（17）；
-- 數字照 DFT 的對照（233 也是傳奇）。認不得 → nil（全部難度）
local DIFF_CODES = {
    m = 16, mythic = 16, h = 15, heroic = 15, n = 14, normal = 14, lfr = 17,
    [14] = 14, [15] = 15, [16] = 16, [17] = 17, [233] = 16,
}
local function Difficulties(v)
    local key = tonumber(v) or (type(v) == "string" and strtrim(v):lower())
    local d = key and DIFF_CODES[key]
    return d and { [d] = true } or nil
end

local function Entry(t, text, spell)
    return { t = t, text = text, spell = spell, lead = DEFAULT_LEAD, enabled = true }
end

local function NewStats()
    return { phased = 0, skipped = 0, personal = 0, notMe = false, phaseSkipped = 0 }
end

------------------------------------------------------------
-- 偵測
------------------------------------------------------------
function Convert.IsDSR(text)
    return type(text) == "string" and strtrim(text):sub(1, #DSR_PREFIX) == DSR_PREFIX
end

-- 有任何一行以 EncounterID:<數字> 開頭
function Convert.IsNSRT(text)
    if type(text) ~= "string" then return false end
    for line in text:sub(1, MAX_INPUT):gmatch("[^\r\n]+") do
        if strtrim(line):match("^EncounterID:%s*%d") then return true end
    end
    return false
end

------------------------------------------------------------
-- DSR1!
------------------------------------------------------------
local function DecodeEnvelope(text)
    local E = C_EncodingUtil
    if not (E and E.DecodeBase64 and E.DecompressString and E.DeserializeJSON) then
        return nil, L["This game client can't read share strings."]
    end
    text = strtrim(text or ""):gsub("%s", "")
    if #text > MAX_INPUT then return nil, L["This string is too long."] end
    local body = text:sub(#DSR_PREFIX + 1)
    if body == "" or body:find("[^%w%-_=]") then return nil, L["Couldn't read this string."] end
    -- base64url → 標準 base64
    body = body:gsub("=", ""):gsub("%-", "+"):gsub("_", "/")
    local rem = #body % 4
    if rem == 1 then return nil, L["Couldn't read this string."] end
    if rem > 0 then body = body .. string.rep("=", 4 - rem) end

    local okB, raw = pcall(E.DecodeBase64, body)
    if not okB or type(raw) ~= "string" or raw == "" then return nil, L["Couldn't read this string."] end

    local CM = Enum and Enum.CompressionMethod
    local methods = CM and { CM.Deflate, CM.Zlib } or { false }
    local json
    for _, method in ipairs(methods) do
        local ok, out
        if method then
            ok, out = pcall(E.DecompressString, raw, method)
        else
            ok, out = pcall(E.DecompressString, raw)
        end
        if ok and type(out) == "string" and out ~= "" then
            json = out
            break
        end
    end
    if not json then return nil, L["Couldn't read this string."] end

    local okJ, env = pcall(E.DeserializeJSON, json)
    if not okJ or type(env) ~= "table" then return nil, L["Couldn't read this string."] end
    return env
end

-- 階段起點表：[phaseNumber] = phaseTimer
local function PhaseStarts(phases)
    local out = {}
    if type(phases) ~= "table" then return out end
    for i, p in ipairs(phases) do
        if i > MAX_PHASES then break end
        if type(p) == "table" then
            local n, start = Num(p.phaseNumber, 1, 100), Num(p.phaseTimer, 0, 3600)
            if n and start then out[math.floor(n)] = start end
        end
    end
    return out
end

-- DFT 的 target 清單 → 一組或幾組對象條件（見檔頭：同類 OR 併一條、跨類拆開）。
-- 回傳 { {條件欄位…}, ... }；空清單／有 all → { {} }（不限）
local ROLE_MAP = { tank = "TANK", healer = "HEALER", damager = "DAMAGER", dps = "DAMAGER" }
local function Audiences(target)
    if type(target) ~= "table" then return { {} } end
    local roles, positions, groups, classes = {}, {}, {}, {}
    local n = 0
    for i, t in ipairs(target) do
        if i > 40 then break end
        if type(t) == "table" then
            local kind = type(t.type) == "string" and t.type or ""
            local v = t.value
            if kind == "all" then return { {} } end
            local sv = type(v) == "string" and v:lower() or nil
            if kind == "role" and sv and ROLE_MAP[sv] then
                roles[ROLE_MAP[sv]] = true
            elseif (kind == "position" or kind == "role") and (sv == "melee" or sv == "ranged") then
                positions[sv] = true
            elseif kind == "group" or kind == "party" then
                local g = Num(v or t.slot, 1, 8)
                if g then groups[math.floor(g)] = true end
            elseif kind == "class" and sv and sv:match("^%a+$") and #sv <= 20 then
                classes[#classes + 1] = sv:upper()
            end
            n = n + 1
        end
    end
    local out = {}
    if next(roles) then out[#out + 1] = { roles = roles } end
    if next(positions) then out[#out + 1] = { positions = positions } end
    if next(groups) then out[#out + 1] = { groups = groups } end
    for _, c in ipairs(classes) do out[#out + 1] = { class = c } end
    -- 一個都認不得（未來的新類型）就給所有人：寧可多響也不要漏
    if #out == 0 then return { {} } end
    return out
end

local function FindMe(players)
    if type(players) ~= "table" then return end
    for i, pl in ipairs(players) do
        if i > MAX_LIST then break end
        if type(pl) == "table" and pl.id ~= nil and type(pl.name) == "string" and Plans.IsMe(pl.name:sub(1, 64)) then
            return tostring(pl.id)
        end
    end
end

local function CountPersonal(data)
    local n = 0
    if type(data.playerAbilities) == "table" then n = n + math.min(#data.playerAbilities, MAX_LIST) end
    if type(data.playerNotes) == "table" then
        local k = 0
        for _, list in pairs(data.playerNotes) do
            k = k + 1
            if k > MAX_LIST then break end
            if type(list) == "table" then n = n + math.min(#list, MAX_LIST) end
        end
    end
    return n
end

-- 回傳 payload，或 nil, 錯誤訊息
function Convert.DecodeDSR(text)
    local env, err = DecodeEnvelope(text)
    if not env then return nil, err end
    local encID = Num(env.encID, 1, 1e8)
    local data = env.data
    if not encID or type(data) ~= "table" then return nil, L["Couldn't read this string."] end

    local exportedBy = Str(env.exportedBy, 60)
    local payload = {
        id = math.floor(encID),
        name = Str(env.name, 60),
        author = (exportedBy and exportedBy ~= "addon") and exportedBy or nil,
        difficulties = Difficulties(env.difficulty),
        entries = {},
        source = "dft",
        dftBoardId = (type(env.boardId) == "string" or type(env.boardId) == "number")
            and Str(tostring(env.boardId), 80) or nil,
        stats = NewStats(),
    }
    local stats, entries = payload.stats, payload.entries
    local starts = PhaseStarts(data.phases)

    -- 一條「階段內秒數」→ 條目（nil＝略過，已計數）
    local function Make(time, phaseNumber, rawText, spell)
        if #entries >= MAX_ENTRIES then
            stats.skipped = stats.skipped + 1
            return
        end
        local rel = Num(time, -600, 3600)
        local ph = math.floor(Num(phaseNumber, 1, 100) or 1)
        if not rel then
            stats.skipped = stats.skipped + 1
            return
        end
        local t = (starts[ph] or 0) + rel
        local text, noteSpell = TextAndSpell(rawText)
        spell = spell or noteSpell
        if t < 0.1 or t > 3600 or (not text and not spell) then
            stats.skipped = stats.skipped + 1      -- 開戰前（倒數期間）的、空的
            return
        end
        local e = Entry(math.floor(t * 10 + 0.5) / 10, text, spell)
        if ph > 1 then
            e.phase = math.min(ph, 20)
            stats.phased = stats.phased + 1
        end
        return e
    end

    -- 首領筆記：全收，target 轉對象條件
    if type(data.bossNotes) == "table" then
        for i, note in ipairs(data.bossNotes) do
            if i > MAX_LIST then break end
            if type(note) == "table" then
                local base = Make(note.time, note.phaseNumber, note.text)
                if base then
                    local auds = Audiences(note.target)
                    for k, aud in ipairs(auds) do
                        if #entries >= MAX_ENTRIES then break end
                        -- 每一份都從乾淨的 base 拷（不能拿已經填過條件的那條再拷）
                        local e = (k == #auds) and base or CopyTable(base)
                        for key, v in pairs(aud) do e[key] = v end
                        entries[#entries + 1] = e
                    end
                end
            end
        end
    end

    -- 個人的：只收我
    local myID = FindMe(data.players)
    if not myID then
        stats.personal = CountPersonal(data)
        stats.notMe = stats.personal > 0
    else
        local notes = type(data.playerNotes) == "table" and data.playerNotes[myID]
        -- JSON 物件的 key 一定是字串；保險起見數字 ID 也試一次
        if notes == nil and tonumber(myID) and type(data.playerNotes) == "table" then
            notes = data.playerNotes[tonumber(myID)]
        end
        if type(notes) == "table" then
            for i, note in ipairs(notes) do
                if i > MAX_LIST then break end
                if type(note) == "table" then
                    local e = Make(note.time, note.phaseNumber, note.text)
                    if e then entries[#entries + 1] = e end
                end
            end
        end
        if type(data.playerAbilities) == "table" then
            for i, cd in ipairs(data.playerAbilities) do
                if i > MAX_LIST then break end
                if type(cd) == "table" and tostring(cd.playerId) == myID then
                    -- abilityId = "class_spec_<法術ID>"：取最後一段數字
                    local spell = Num(tostring(cd.abilityId or ""):sub(1, 80):match("(%d+)$"), 1, 1e8)
                    if spell then
                        local e = Make(cd.time, cd.phaseNumber, nil, spell)
                        if e then entries[#entries + 1] = e end
                    else
                        stats.skipped = stats.skipped + 1
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b) return a.t < b.t end)
    return payload
end

------------------------------------------------------------
-- NSRT 筆記
------------------------------------------------------------
local NSRT_ROLES = {
    tank = "TANK", tanks = "TANK", healer = "HEALER", healers = "HEALER",
    dps = "DAMAGER", damager = "DAMAGER", damagers = "DAMAGER",
}
local NSRT_CLASSES = {
    deathknight = "DEATHKNIGHT", demonhunter = "DEMONHUNTER", druid = "DRUID", evoker = "EVOKER",
    hunter = "HUNTER", mage = "MAGE", monk = "MONK", paladin = "PALADIN", priest = "PRIEST",
    rogue = "ROGUE", shaman = "SHAMAN", warlock = "WARLOCK", warrior = "WARRIOR",
}

-- 一個欄位的值：「key:值」到下一個分號為止，去掉前後空白
local function Field(line, key)
    local v = line:match("%f[%w]" .. key .. ":([^;]*)")
    v = v and strtrim(v)
    if v == "" then return end
    return v
end

local function ApplyTag(e, tag)
    if not tag then return end
    local lower = tag:lower()
    if lower == "everyone" or lower == "all" then return end
    if NSRT_ROLES[lower] then
        e.roles = { [NSRT_ROLES[lower]] = true }
    elseif lower == "melee" or lower == "ranged" then
        e.positions = { [lower] = true }
    elseif lower:match("^group(%d+)$") then
        local g = Num(lower:match("^group(%d+)$"), 1, 8)
        if g then e.groups = { [math.floor(g)] = true } end
    elseif NSRT_CLASSES[lower] then
        e.class = NSRT_CLASSES[lower]
    else
        local name = Plans.BareName(Str(tag, 48))
        if name then e.players = { [name] = true } end
    end
end

function Convert.ParseNSRT(text)
    text = tostring(text or "")
    if #text > MAX_INPUT then return nil, L["This string is too long."] end
    local payload = { entries = {}, source = "import", stats = NewStats() }
    local stats, entries = payload.stats, payload.entries
    local lines = 0
    for rawLine in text:gmatch("[^\r\n]+") do
        lines = lines + 1
        if lines > 5000 then break end
        local line = strtrim(rawLine)
        if line:find("EncounterID:", 1, true) then
            local id = Num(line:match("EncounterID:%s*(%d+)"), 1, 1e8)
            if id and not payload.id then
                payload.id = math.floor(id)
                payload.difficulties = Difficulties(Field(line, "Difficulty"))
                payload.name = Str(Field(line, "Name"), 60)
            end
        else
            local t = Num(line:match("%f[%w]time:%s*([+-]?%d*%.?%d+)"), -600, 3600)
            if t then
                local spell = Num(Field(line, "spellid"), 1, 1e8)
                local rawText = Field(line, "text")
                local ph = Num(Field(line, "ph"), 0, 100) or 1
                local cleanText, noteSpell = TextAndSpell(rawText)
                spell = spell or noteSpell
                if ph > 1 then
                    stats.phaseSkipped = stats.phaseSkipped + 1
                elseif t < 0.1 or (not cleanText and not spell) or #entries >= MAX_ENTRIES then
                    stats.skipped = stats.skipped + 1
                else
                    local e = Entry(math.floor(t * 10 + 0.5) / 10, cleanText, spell)
                    ApplyTag(e, Field(line, "tag"))
                    entries[#entries + 1] = e
                end
            end
        end
    end
    if not payload.id then return nil, L["This NSRT note has no EncounterID line."] end
    payload.name = payload.name or L["NSRT note"]
    table.sort(entries, function(a, b) return a.t < b.t end)
    return payload
end
