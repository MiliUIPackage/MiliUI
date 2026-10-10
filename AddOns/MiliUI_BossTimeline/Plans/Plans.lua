------------------------------------------------------------
-- 自訂時間軸的資料
--
-- db.plans[encounterID] = {
--     name       = "首領名稱",           顯示用（玩家可改）
--     enabled    = true,
--     difficulty = 0,                    0 = 不分難度；其餘是 GetInstanceInfo 的 difficultyID
--     entries    = { { t, text, spell, icon, lead, enabled }, ... }   照 t 排好
--     journal    = 冒險指南的首領 ID（選填，頁面頭像用；新增首領時從選單記下、或找到模型時補上）
--     display    = 首領模型的 displayInfo（選填，找到一次就存，之後不再查冒險指南）
-- }
--   t      開戰後第幾秒「發生」
--   lead   提前幾秒放上時間軸（在時間軸上倒數多久）
--   spell  法術 ID（選填）：圖示與預設文字都從它來
--   icon   圖示 fileID（選填）：沒填法術時用
--
-- encounterID 是 ENCOUNTER_START 給的那個數字（冒險指南的 journalEncounterID 不一樣，不要混）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L

ns.Plans = {}
local Plans = ns.Plans

local DEFAULT_ICON = 134400     -- 問號
local DEFAULT_LEAD = 8

-- 難度選單：0 = 全部；其餘是常見的 difficultyID
Plans.DIFFICULTIES = {
    { value = 0,  label = "All difficulties" },
    { value = 14, label = "Normal raid" },
    { value = 15, label = "Heroic raid" },
    { value = 16, label = "Mythic raid" },
    { value = 17, label = "Raid Finder" },
    { value = 1,  label = "Normal dungeon" },
    { value = 2,  label = "Heroic dungeon" },
    { value = 23, label = "Mythic dungeon" },
    { value = 8,  label = "Mythic Keystone" },
}

function Plans.DifficultyLabel(value)
    for _, d in ipairs(Plans.DIFFICULTIES) do
        if d.value == (value or 0) then return L[d.label] end
    end
    return tostring(value)
end

------------------------------------------------------------
-- 時間字串：「90」「1:30」「1:30.5」都收；顯示一律 m:ss
------------------------------------------------------------
function Plans.ParseTime(text)
    text = strtrim(tostring(text or ""))
    if text == "" then return end
    local m, s = text:match("^(%d+):(%d+%.?%d*)$")
    if m then
        s = tonumber(s)
        if not s or s >= 60 then return end
        return tonumber(m) * 60 + s
    end
    local n = tonumber(text)
    if n and n >= 0 then return n end
end

function Plans.FormatTime(t)
    t = tonumber(t) or 0
    local m = math.floor(t / 60)
    local s = t - m * 60
    if s == math.floor(s) then
        return ("%d:%02d"):format(m, s)
    end
    return ("%d:%04.1f"):format(m, s)
end

------------------------------------------------------------
-- 一條提示實際要用的圖示與文字
------------------------------------------------------------
function Plans.Resolve(entry)
    local icon, text = entry.icon, entry.text
    if entry.spell and C_Spell and C_Spell.GetSpellInfo then
        local info = S.SafeCall(C_Spell.GetSpellInfo, entry.spell)
        if type(info) == "table" then
            icon = icon or S.PlainNumber(info.iconID)
            if not text or text == "" then text = S.PlainText(info.name) end
        end
    end
    if not text or text == "" then text = L["Reminder"] end
    return icon or DEFAULT_ICON, text
end

------------------------------------------------------------
-- 存取
------------------------------------------------------------
local function All()
    return ns.db.plans
end

function Plans.Get(id)
    return id and All()[id]
end

-- 依名稱排序的清單：{ { id =, plan = }, ... }
function Plans.List()
    local out = {}
    for id, plan in pairs(All()) do out[#out + 1] = { id = id, plan = plan } end
    table.sort(out, function(a, b)
        local an, bn = a.plan.name or "", b.plan.name or ""
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return out
end

function Plans.Ensure(id, name)
    local all = All()
    if not all[id] then
        all[id] = { name = name or tostring(id), enabled = true, difficulty = 0, entries = {} }
    elseif name and name ~= "" then
        all[id].name = name
    end
    return all[id]
end

function Plans.Delete(id)
    All()[id] = nil
end

------------------------------------------------------------
-- 復原：每次改動前把整份 entries 拷一份進堆疊（每隻首領各一疊、最多 UNDO_MAX 步、只存在這次登入）
-- 一個動作內改很多條（匯入、整份平移）包在 Plans.Batch 裡，只記一步
------------------------------------------------------------
local UNDO_MAX = 20
local undoStacks = {}
local batching = 0

function Plans.Checkpoint(id)
    if batching > 0 then return end
    local plan = Plans.Get(id)
    if not plan then return end
    local st = undoStacks[id] or {}
    st[#st + 1] = CopyTable(plan.entries)
    if #st > UNDO_MAX then table.remove(st, 1) end
    undoStacks[id] = st
end

function Plans.Batch(id, fn)
    Plans.Checkpoint(id)
    batching = batching + 1
    local ok, a, b, c = pcall(fn)
    batching = batching - 1
    if not ok then error(a, 0) end
    return a, b, c
end

function Plans.CanUndo(id)
    local st = undoStacks[id]
    return st ~= nil and #st > 0
end

function Plans.Undo(id)
    local plan, st = Plans.Get(id), undoStacks[id]
    if not plan or not st or #st == 0 then return false end
    plan.entries = table.remove(st)
    return true
end

function Plans.SetEnabled(id, entry, on)
    Plans.Checkpoint(id)
    entry.enabled = on and true or false
end

local function SortEntries(plan)
    table.sort(plan.entries, function(a, b) return (a.t or 0) < (b.t or 0) end)
end

-- values：{ t, text, spell, icon, lead, sound, soundWhen, tts, roles, class, anchor }
-- index 有給就是改那一條。沒給的欄位（nil）就是清掉 —— 編輯器每次都整筆送過來
--   sound      LSM 音效名稱；soundWhen = "show"（放上時間軸時）／"soon"（5 秒前）／"due"（到點，預設）
--   tts        到 soundWhen 那一刻朗讀提示文字（文字轉語音）
--   roles      { TANK = true, HEALER = true, DAMAGER = true } 只給這些職責；nil = 全部
--   class      "PRIEST" 之類，只給這個職業；nil = 全部
--   anchor     { spell, n, offset }：跟著這個首領技能的第 n 次施放走（Scheduler 戰鬥中認得出來時改時間），
--              t 仍然是沒認出來時的備援秒數
function Plans.SaveEntry(id, values, index)
    local plan = Plans.Get(id)
    if not plan then return end
    Plans.Checkpoint(id)
    local e = index and plan.entries[index]
    if not e then
        e = { enabled = true }
        plan.entries[#plan.entries + 1] = e
    end
    e.t         = values.t or 0
    e.text      = values.text ~= "" and values.text or nil
    e.spell     = values.spell
    e.icon      = values.icon
    e.lead      = values.lead or DEFAULT_LEAD
    e.sound     = values.sound ~= "" and values.sound or nil
    e.soundWhen = values.soundWhen
    e.tts       = values.tts or nil
    e.roles     = (values.roles and next(values.roles)) and values.roles or nil
    e.class     = values.class ~= "" and values.class or nil
    e.anchor    = values.anchor
    SortEntries(plan)
    return e
end

-- 拖曳：只改時間（錨點的偏移跟著平移，讓「第 n 次施放後幾秒」維持玩家拖到的位置）
function Plans.MoveEntry(id, entry, newT)
    local plan = Plans.Get(id)
    if not plan or not entry then return end
    Plans.Checkpoint(id)
    newT = math.max(0.1, math.floor(newT * 10 + 0.5) / 10)
    if entry.anchor then
        entry.anchor.offset = (entry.anchor.offset or 0) + (newT - (entry.t or 0))
    end
    entry.t = newT
    SortEntries(plan)
end

function Plans.IndexOf(id, entry)
    local plan = Plans.Get(id)
    if not plan then return end
    for i, e in ipairs(plan.entries) do
        if e == entry then return i end
    end
end

------------------------------------------------------------
-- 條件：這一條給不給目前這隻角色
-- 職責看自己的專精（player 讀專精不受 12.1 限制；UnitGroupRolesAssigned 是秘密值，不用）
------------------------------------------------------------
local function PlayerRole()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local idx = getSpec and S.SafeCall(getSpec)
    if not idx then return end
    local getRole = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole) or GetSpecializationRole
    return getRole and S.PlainText(S.SafeCall(getRole, idx))
end
Plans.PlayerRole = PlayerRole

function Plans.EntryApplies(e)
    if e.enabled == false then return false end
    if e.class and e.class ~= ns.playerClass then return false end
    if e.roles then
        local role = PlayerRole()
        -- 讀不到專精（剛登入）就照給：寧可多一條提示，也不要漏
        if role and not e.roles[role] then return false end
    end
    return true
end

function Plans.RemoveEntry(id, index)
    local plan = Plans.Get(id)
    if plan and plan.entries[index] then
        Plans.Checkpoint(id)
        table.remove(plan.entries, index)
    end
end

-- 這一場要不要跑、跑哪一份
function Plans.Active(encounterID, difficultyID)
    local plan = Plans.Get(encounterID)
    if not plan or not plan.enabled or #plan.entries == 0 then return end
    if (plan.difficulty or 0) ~= 0 and plan.difficulty ~= difficultyID then return end
    return plan
end

------------------------------------------------------------
-- 匯入 MRT 筆記／lorrgs 的提示行
--
-- 一行一條，時間寫在 {time:mm:ss} 裡（DreamForgeTools 的 Personal Tactics 收的也是這個格式）：
--   {time:00:12} - {spell:31821} 光環精通
--   {time:1:30.5}{spell:62618} 真言術：壁
-- 規則：
--   * {spell:N} 取第一個當法術（圖示與預設文字從它來）
--   * 其他 {…}（團隊標記 {skull}／{rt1}、職業標籤）與色碼一律剝掉，剩下的字當提示文字
--   * 時間後面帶階段的（{time:00:54.8,p2}，lorrgs 的「動態計時」）不支援 —— 那是「從第二階段
--     開始算」，我們的自訂時間軸只認開戰後的絕對秒數；算成略過，回報給玩家
--   * 同一秒、同文字、同法術的已經有了就不重複加
-- 回傳 added, skipped, phased
------------------------------------------------------------
local function CleanText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("{[^}]*}", " ")
    -- ⚠ 全形破折號／冒號是多位元組字元，不能塞進 [...] 字元集（會把中文字的尾位元組一起剝掉），
    --   所以 ASCII 的用字元集、多位元組的一個一個當字串剝，剝到兩端都不再變為止
    local SEPS = { "–", "—", "：" }
    local prev
    repeat
        prev = text
        text = text:gsub("^[%s%-:|]+", ""):gsub("[%s%-|]+$", "")
        for _, sep in ipairs(SEPS) do
            if text:sub(1, #sep) == sep then text = text:sub(#sep + 1) end
            if #text >= #sep and text:sub(-#sep) == sep then text = text:sub(1, -#sep - 1) end
        end
    until text == prev
    text = text:gsub("%s%s+", " ")
    return strtrim(text)
end

local function ImportNote(id, note)
    local plan = Plans.Get(id)
    if not plan then return 0, 0, 0 end
    local added, skipped, phased = 0, 0, 0
    for line in tostring(note or ""):gmatch("[^\r\n]+") do
        local timeText, extra = line:match("{[Tt][Ii][Mm][Ee]:([%d:%.]+)([^}]*)}")
        if timeText then
            local t = Plans.ParseTime(timeText)
            if extra and strtrim(extra) ~= "" then
                phased = phased + 1
            elseif not t or t <= 0 then
                skipped = skipped + 1
            else
                local spell = tonumber(line:match("{[Ss][Pp][Ee][Ll][Ll]:(%d+)}"))
                local rest = line:gsub("{[Tt][Ii][Mm][Ee]:[^}]*}", "", 1)
                local text = CleanText(rest)
                if text == "" and not spell then
                    skipped = skipped + 1
                else
                    local dup = false
                    for _, e in ipairs(plan.entries) do
                        if math.abs((e.t or 0) - t) < 0.05 and (e.text or "") == text and e.spell == spell then
                            dup = true
                            break
                        end
                    end
                    if dup then
                        skipped = skipped + 1
                    else
                        Plans.SaveEntry(id, { t = t, text = text, spell = spell, lead = DEFAULT_LEAD })
                        added = added + 1
                    end
                end
            end
        end
    end
    return added, skipped, phased
end

function Plans.ImportNote(id, note)
    if not Plans.Get(id) then return 0, 0, 0 end
    return Plans.Batch(id, function() return ImportNote(id, note) end)
end

Plans.DEFAULT_LEAD = DEFAULT_LEAD
