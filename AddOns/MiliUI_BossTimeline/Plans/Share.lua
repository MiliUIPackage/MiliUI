------------------------------------------------------------
-- 分享自訂時間軸：匯出成字串、貼上匯入
--
-- 兩種格式：
--   * 米利字串 "!MBT1!…"：整份計畫（含音效、條件、錨點）。
--     走暴雪內建的 C_EncodingUtil：SerializeCBOR → CompressString（Deflate）→ EncodeBase64，
--     匯入反過來。不用 loadstring 解析別人貼來的東西 —— CBOR 解出來只會是資料。
--   * MRT 筆記行 "{time:01:30}{spell:N} 文字"：有損（只有時間、法術、文字），但 MRT、
--     DreamForgeTools 的 Personal Tactics、其他吃這個格式的插件都讀得懂。匯入走 Plans.ImportNote。
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
        class     = Str(e.class, 20),
        enabled   = e.enabled ~= false,
    }
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
function Share.Export(id)
    local E = Enc()
    local plan = Plans.Get(id)
    if not E or not plan then return end
    local entries = {}
    for _, e in ipairs(plan.entries) do
        local c = CleanEntry(e)
        if c then entries[#entries + 1] = c end
    end
    local payload = { v = 1, id = id, name = plan.name, difficulty = plan.difficulty, entries = entries }
    local ok, out = pcall(function()
        return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload)))
    end)
    if ok then return out end
    ns.ReportError(out)
end

-- MRT 筆記行（有損）
function Share.ExportNote(id)
    local plan = Plans.Get(id)
    if not plan then return "" end
    local lines = {}
    for _, e in ipairs(plan.entries) do
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

-- 回傳 payload（清洗過）或 nil, 錯誤訊息
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
    local out = {
        id = math.floor(id),
        name = Str(data.name, 60),
        difficulty = Num(data.difficulty, 0, 1000) or 0,
        entries = {},
    }
    for i, e in ipairs(data.entries) do
        if i > MAX_ENTRIES then break end
        local c = CleanEntry(e)
        if c then out.entries[#out.entries + 1] = c end
    end
    return out
end

-- 併進那隻首領的自訂時間軸（沒有就建）；同一秒同文字同法術的不重複加。回傳 added, skipped
function Share.Import(payload)
    Plans.Ensure(payload.id, payload.name)
    return Plans.Batch(payload.id, function() return Share.ImportInto(payload) end)
end

function Share.ImportInto(payload)
    local plan = Plans.Get(payload.id)
    if (plan.difficulty or 0) == 0 and payload.difficulty ~= 0 and #plan.entries == 0 then
        plan.difficulty = payload.difficulty
    end
    local added, skipped = 0, 0
    for _, e in ipairs(payload.entries) do
        local dup = false
        for _, x in ipairs(plan.entries) do
            if math.abs((x.t or 0) - e.t) < 0.05 and x.text == e.text and x.spell == e.spell then
                dup = true
                break
            end
        end
        if dup then
            skipped = skipped + 1
        else
            local enabled = e.enabled
            local saved = Plans.SaveEntry(payload.id, e)
            if saved then saved.enabled = enabled end
            added = added + 1
        end
    end
    return added, skipped
end
