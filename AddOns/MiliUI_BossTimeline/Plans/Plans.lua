------------------------------------------------------------
-- 自訂時間軸的資料：首領 → 設定檔 → 條目
--
-- db.bosses[encounterID] = {
--     name       = "首領名稱",           顯示用
--     journal    = 冒險指南的首領 ID（選填，頁面頭像用）
--     display    = 首領模型的 displayInfo（選填，找到一次就存，之後不再查冒險指南）
--     instance   = 冒險指南的副本 ID（選填，側欄分組用）
--     profiles   = { [profileID] = profile, ... }
-- }
-- profile = {
--     id, name,
--     difficulties = { [difficultyID] = true } | nil    nil／空＝全部難度
--     active       = true|false     開戰時要不要跑；同一隻首領可以同時生效好幾份（團長的＋自己的）
--     entries      = { { t, text, spell, icon, lead, ... }, ... }   照 t 排好（「每一次」的沒有 t，排最前面）
--     mrtVariant, source = "local"|"import", author, createdAt, updatedAt,
-- }
--   t      開戰後第幾秒「發生」
--   lead   提前幾秒放上時間軸（在時間軸上倒數多久）
--   spell  法術 ID（選填）：圖示與預設文字都從它來
--   icon   圖示 fileID（選填）：沒填法術時用
--
-- 開戰時把「生效中、而且適用這個難度」的設定檔合併起來跑（Plans.Active）；
-- 完全相同的條目（同秒、同法術、同文字）只跑一次 —— 團長的跟自己的重疊時不會響兩次。
--
-- encounterID 是 ENCOUNTER_START 給的那個數字（冒險指南的 journalEncounterID 不一樣，不要混）。
-- profileID 全域唯一（"p<時間>_<亂數>"），條目操作與復原堆疊都只吃 profileID。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L

ns.Plans = {}
local Plans = ns.Plans

local DEFAULT_ICON = 134400     -- 問號
local DEFAULT_LEAD = 8
local DUP_EPS = 0.05            -- 同一秒的容許誤差（去重用）

-- 難度名稱（摘要、匯出、上一場紀錄的說明用）：0 = 全部
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

-- 自訂時間軸頁的難度分頁：團隊副本一組、地城一組（短名稱，分頁鈕上用）
Plans.RAID_DIFFICULTIES = {
    { value = 17, label = "LFR" },
    { value = 14, label = "Normal" },
    { value = 15, label = "Heroic" },
    { value = 16, label = "Mythic" },
}
Plans.DUNGEON_DIFFICULTIES = {
    { value = 1,  label = "Normal" },
    { value = 2,  label = "Heroic" },
    { value = 23, label = "Mythic" },
    { value = 8,  label = "Mythic Keystone" },
}

-- 短名稱：團隊與地城的「普通」同字，摘要裡兩組不會混在一起（一隻首領只屬於一種副本）
function Plans.DifficultyShort(value)
    for _, group in ipairs({ Plans.RAID_DIFFICULTIES, Plans.DUNGEON_DIFFICULTIES }) do
        for _, d in ipairs(group) do
            if d.value == value then return L[d.label] end
        end
    end
    return Plans.DifficultyLabel(value)
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
-- 首領
------------------------------------------------------------
local function AllBosses()
    return ns.db.bosses
end

function Plans.Boss(encounterID)
    return encounterID and AllBosses()[encounterID]
end

-- 沒有就建（空的設定檔表）；name／journal／instance 有給就補上（不蓋掉已有的 journal／instance）
function Plans.EnsureBoss(encounterID, name, journal, instance)
    if not encounterID then return end
    local all = AllBosses()
    local boss = all[encounterID]
    if not boss then
        boss = { name = name or tostring(encounterID), profiles = {} }
        all[encounterID] = boss
    elseif name and name ~= "" then
        boss.name = name
    end
    boss.profiles = boss.profiles or {}
    boss.journal = boss.journal or journal
    boss.instance = boss.instance or instance
    return boss
end

-- 存檔裡有紀錄的首領：{ { id =, boss = }, ... }，依名稱排序
function Plans.Bosses()
    local out = {}
    for id, boss in pairs(AllBosses()) do out[#out + 1] = { id = id, boss = boss } end
    table.sort(out, function(a, b)
        local an, bn = a.boss.name or "", b.boss.name or ""
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return out
end

-- 這隻首領有幾份設定檔、其中有沒有生效中的（側欄的數字與綠點）
function Plans.BossSummary(encounterID)
    local boss = Plans.Boss(encounterID)
    local n, active = 0, false
    if boss then
        for _, p in pairs(boss.profiles) do
            n = n + 1
            if p.active then active = true end
        end
    end
    return n, active
end

------------------------------------------------------------
-- 設定檔
------------------------------------------------------------
-- profileID → encounterID 的索引；找不到（新建、刪除、遷移後）就整個重建，首領數量很少，便宜
local ownerOf = {}

local function RebuildIndex()
    wipe(ownerOf)
    for encID, boss in pairs(AllBosses()) do
        for pid in pairs(boss.profiles or {}) do ownerOf[pid] = encID end
    end
end

function Plans.BossOf(pid)
    if not pid then return end
    local enc = ownerOf[pid]
    local boss = enc and AllBosses()[enc]
    if boss and boss.profiles[pid] then return enc end
    RebuildIndex()
    return ownerOf[pid]
end

function Plans.Get(pid)
    local enc = Plans.BossOf(pid)
    return enc and AllBosses()[enc].profiles[pid]
end

function Plans.AppliesTo(profile, difficultyID)
    if not profile then return false end
    local set = profile.difficulties
    if not set or not next(set) then return true end
    return difficultyID ~= nil and set[difficultyID] == true
end

-- 這隻首領適用這個難度的設定檔（difficultyID 是 nil 就全部）：生效的在前，再依名稱
function Plans.Profiles(encounterID, difficultyID)
    local out = {}
    local boss = Plans.Boss(encounterID)
    if not boss then return out end
    for _, p in pairs(boss.profiles) do
        if difficultyID == nil or Plans.AppliesTo(p, difficultyID) then out[#out + 1] = p end
    end
    table.sort(out, function(a, b)
        if (a.active and 1 or 0) ~= (b.active and 1 or 0) then return a.active == true end
        local an, bn = a.name or "", b.name or ""
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return out
end

local function NewID()
    local id
    repeat
        id = "p" .. time() .. "_" .. math.random(1000, 9999)
    until not Plans.Get(id)
    return id
end
Plans.NewID = NewID

-- 直接把一份設定檔掛到首領底下（遷移與匯入共用）。回傳 profile
function Plans.AddProfile(encounterID, profile)
    local boss = Plans.EnsureBoss(encounterID)
    if not boss then return end
    profile.id = profile.id or NewID()
    profile.entries = profile.entries or {}
    profile.createdAt = profile.createdAt or time()
    profile.updatedAt = profile.updatedAt or profile.createdAt
    boss.profiles[profile.id] = profile
    ownerOf[profile.id] = encounterID
    return profile
end

-- 新建：只用在 difficultyID 這個難度（nil＝全部）、預設生效
function Plans.NewProfile(encounterID, name, difficultyID)
    return Plans.AddProfile(encounterID, {
        name = (name and name ~= "") and name or L["My plan"],
        difficulties = difficultyID and { [difficultyID] = true } or nil,
        active = true,
        source = "local",
    })
end

-- 複製：同一隻首領、同樣的難度，預設不生效（不然一按複製，同樣的提示就變兩份在跑 —— 雖然會去重，
-- 但之後改了其中一份就會疊起來響）
function Plans.CopyProfile(pid)
    local src, enc = Plans.Get(pid), Plans.BossOf(pid)
    if not src then return end
    local p = CopyTable(src)
    p.id, p.createdAt, p.updatedAt = nil, nil, nil
    p.name = L["%s (copy)"]:format(src.name or "")
    p.active = false
    return Plans.AddProfile(enc, p)
end

function Plans.RenameProfile(pid, name)
    local p = Plans.Get(pid)
    if not p or not name or name == "" then return end
    p.name = name
    p.updatedAt = time()
end

-- 刪掉最後一份時首領紀錄留著（頭像、副本歸屬還用得到），只是變成沒有設定檔
local undoStacks = {}

function Plans.DeleteProfile(pid)
    local enc = Plans.BossOf(pid)
    if not enc then return end
    AllBosses()[enc].profiles[pid] = nil
    ownerOf[pid] = nil
    undoStacks[pid] = nil
end

function Plans.SetActive(pid, on)
    local p = Plans.Get(pid)
    if p then p.active = on and true or false end
end

-- set：{ [difficultyID] = true }；nil 或空表＝全部難度
function Plans.SetDifficulties(pid, set)
    local p = Plans.Get(pid)
    if not p then return end
    if set and next(set) then
        local copy = {}
        for d, on in pairs(set) do
            if on then copy[d] = true end
        end
        p.difficulties = next(copy) and copy or nil
    else
        p.difficulties = nil
    end
end

------------------------------------------------------------
-- 復原：每次改動前把整份 entries 拷一份進堆疊（每份設定檔各一疊、最多 UNDO_MAX 步、只存在這次登入）
-- 一個動作內改很多條（匯入、整份平移）包在 Plans.Batch 裡，只記一步
------------------------------------------------------------
local UNDO_MAX = 20
local batching = 0

function Plans.Checkpoint(pid)
    local p = Plans.Get(pid)
    if not p then return end
    p.updatedAt = time()
    if batching > 0 then return end
    local st = undoStacks[pid] or {}
    st[#st + 1] = CopyTable(p.entries)
    if #st > UNDO_MAX then table.remove(st, 1) end
    undoStacks[pid] = st
end

function Plans.Batch(pid, fn)
    Plans.Checkpoint(pid)
    batching = batching + 1
    local ok, a, b, c = pcall(fn)
    batching = batching - 1
    if not ok then error(a, 0) end
    return a, b, c
end

function Plans.CanUndo(pid)
    local st = pid and undoStacks[pid]
    return st ~= nil and #st > 0
end

function Plans.Undo(pid)
    local p, st = Plans.Get(pid), pid and undoStacks[pid]
    if not p or not st or #st == 0 then return false end
    p.entries = table.remove(st)
    p.updatedAt = time()
    return true
end

function Plans.SetEnabled(pid, entry, on)
    Plans.Checkpoint(pid)
    entry.enabled = on and true or false
end

-- 「每一次施放」的提示：anchor = { spell, every = true, offset }，沒有 t（戰鬥中每認出一次就放一條）
local function IsEvery(e)
    return type(e) == "table" and type(e.anchor) == "table" and e.anchor.every == true
end
Plans.IsEvery = IsEvery

-- 這份設定檔有幾條「每一次」的提示（匯出 MRT 筆記、測試鈕、時間軸編輯器的說明用）
function Plans.CountEvery(profile)
    local n = 0
    for _, e in ipairs(profile and profile.entries or {}) do
        if IsEvery(e) then n = n + 1 end
    end
    return n
end

-- 排序：「每一次」的排最前面（它們之間照偏移、再照法術），其他照秒數
local function EntryLess(a, b)
    local ea, eb = IsEvery(a), IsEvery(b)
    if ea ~= eb then return ea end
    if ea then
        local oa, ob = a.anchor.offset or 0, b.anchor.offset or 0
        if oa ~= ob then return oa < ob end
        return (a.anchor.spell or 0) < (b.anchor.spell or 0)
    end
    return (a.t or 0) < (b.t or 0)
end
Plans.EntryLess = EntryLess

local function SortEntries(p)
    table.sort(p.entries, EntryLess)
end
Plans.SortEntries = SortEntries

-- values：{ t, text, spell, icon, lead, sound, soundWhen, tts, roles, class, anchor }
-- index 有給就是改那一條。沒給的欄位（nil）就是清掉 —— 編輯器每次都整筆送過來
--   sound      LSM 音效名稱；soundWhen = "show"（放上時間軸時）／"soon"（5 秒前）／"due"（到點，預設）
--   tts        到 soundWhen 那一刻朗讀（文字轉語音）
--   ttsText    要念的字（選填）：空白就念提示文字
--   roles      { TANK = true, HEALER = true, DAMAGER = true } 只給這些職責；nil = 全部
--   class      "PRIEST" 之類，只給這個職業；nil = 全部
--   anchor     { spell, n, offset }：跟著這個首領技能的第 n 次施放走（Scheduler 戰鬥中認得出來時改時間），
--              t 仍然是沒認出來時的備援秒數
--              { spell, every = true, offset }：這個技能「每一次」施放都提醒一次（t 不存、n 不存；
--              認不出來就不會出現）
--   positions  { melee = true, ranged = true } 只給近戰／遠程（坦克算近戰）；nil = 全部
--   groups     { [1..8] = true } 只給這幾個小隊；nil = 全部
--   players    { ["名字"] = true } 只給這幾個人（不含伺服器）；nil = 全部
--   phase      這一條原本寫在第幾階段（匯入 DreamForgeTools 時記下來，給未來的換階段偵測；現在 Scheduler 不讀）
function Plans.SaveEntry(pid, values, index)
    local p = Plans.Get(pid)
    if not p then return end
    Plans.Checkpoint(pid)
    local e = index and p.entries[index]
    if not e then
        e = { enabled = true }
        p.entries[#p.entries + 1] = e
    end
    local every = IsEvery(values)
    e.t         = (not every) and (values.t or 0) or nil
    e.text      = values.text ~= "" and values.text or nil
    e.spell     = values.spell
    e.icon      = values.icon
    e.lead      = values.lead or DEFAULT_LEAD
    e.sound     = values.sound ~= "" and values.sound or nil
    e.soundWhen = values.soundWhen
    e.tts       = values.tts or nil
    e.ttsText   = (values.tts and values.ttsText ~= "") and values.ttsText or nil
    e.roles     = (values.roles and next(values.roles)) and values.roles or nil
    e.class     = values.class ~= "" and values.class or nil
    if every then
        e.anchor = { spell = values.anchor.spell, every = true, offset = values.anchor.offset or 0 }
    else
        e.anchor = values.anchor
    end
    e.positions = (values.positions and next(values.positions)) and values.positions or nil
    e.groups    = (values.groups and next(values.groups)) and values.groups or nil
    e.players   = (values.players and next(values.players)) and values.players or nil
    e.phase     = values.phase
    SortEntries(p)
    return e
end

-- 拖曳：只改時間（錨點的偏移跟著平移，讓「第 n 次施放後幾秒」維持玩家拖到的位置）
-- 「每一次」的提示沒有 t：fromT 是被拖的那一個重複標記原本的秒數，只把差值加進偏移
function Plans.MoveEntry(pid, entry, newT, fromT)
    local p = Plans.Get(pid)
    if not p or not entry then return end
    Plans.Checkpoint(pid)
    if IsEvery(entry) then
        local delta = math.floor((newT - (fromT or newT)) * 10 + 0.5) / 10
        local offset = math.floor(((entry.anchor.offset or 0) + delta) * 10 + 0.5) / 10
        entry.anchor.offset = math.max(-600, math.min(600, offset))
        SortEntries(p)
        return
    end
    newT = math.max(0.1, math.floor(newT * 10 + 0.5) / 10)
    if entry.anchor then
        entry.anchor.offset = (entry.anchor.offset or 0) + (newT - (entry.t or 0))
    end
    entry.t = newT
    SortEntries(p)
end

function Plans.IndexOf(pid, entry)
    local p = Plans.Get(pid)
    if not p then return end
    for i, e in ipairs(p.entries) do
        if e == entry then return i end
    end
end

-- 同秒（DUP_EPS 內）、同法術、同文字＝同一條（匯入去重、多份合併去重共用）
-- 「每一次」的提示沒有秒數：改比綁定的技能與偏移（偏移就是它的「秒數」）；跟一般提示永遠不同
local function SameEntry(a, b)
    local ea, eb = IsEvery(a), IsEvery(b)
    if ea ~= eb then return false end
    if (a.text or "") ~= (b.text or "") or a.spell ~= b.spell then return false end
    if ea then
        return a.anchor.spell == b.anchor.spell
            and math.abs((a.anchor.offset or 0) - (b.anchor.offset or 0)) < DUP_EPS
    end
    return math.abs((a.t or 0) - (b.t or 0)) < DUP_EPS
end
Plans.SameEntry = SameEntry

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

-- 近戰專精（跟 DreamForgeTools 的近戰判斷同一張表：神聖騎士、織霧武僧也算近戰 —— 他們本來就站近戰），
-- 坦克一律算近戰（在 IsMelee 裡判斷，不列專精）
local MELEE_SPECS = {
    [71] = true, [72] = true,                   -- 武器、狂怒戰士
    [65] = true, [70] = true,                   -- 神聖、懲戒聖騎士
    [255] = true,                               -- 生存獵人
    [259] = true, [260] = true, [261] = true,   -- 盜賊
    [251] = true, [252] = true,                 -- 冰霜、穢邪死騎
    [263] = true,                               -- 增強薩滿
    [103] = true,                               -- 野性德魯伊
    [269] = true, [270] = true,                 -- 御風、織霧武僧
    [577] = true,                               -- 浩劫惡魔獵人
}
Plans.MELEE_SPECS = MELEE_SPECS

-- true／false；讀不到專精就 nil（呼叫端照給）
local function PlayerIsMelee()
    if PlayerRole() == "TANK" then return true end
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local idx = getSpec and S.PlainNumber(S.SafeCall(getSpec))
    if not idx then return end
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local specID = getInfo and S.PlainNumber(S.SafeCall(getInfo, idx))
    if not specID then return end
    return MELEE_SPECS[specID] == true
end
Plans.PlayerIsMelee = PlayerIsMelee

-- 自己在第幾小隊：UnitInRaid("player") 給團隊索引，GetRaidRosterInfo 的第三個回傳是小隊號
-- （首領戰中兩個都是明文，見 .claude/notes/wow-121-unit-api-secrets.md）。不在團隊＝第 1 隊
local function PlayerSubgroup()
    local idx = UnitInRaid and S.PlainNumber(S.SafeCall(UnitInRaid, "player"))
    if not idx or not GetRaidRosterInfo then return 1 end
    local sub = S.PlainNumber(select(3, S.SafeCall(GetRaidRosterInfo, idx)))
    return sub or 1
end
Plans.PlayerSubgroup = PlayerSubgroup

-- 名字比對：去掉「-伺服器」、ASCII 不分大小寫（中文名字 lower 不會變）
local function BareName(name)
    if type(name) ~= "string" then return end
    name = strtrim(name:match("^([^%-]+)") or name)
    if name == "" then return end
    return name
end
Plans.BareName = BareName

local function NameKey(name)
    name = BareName(name)
    return name and name:lower()
end

local function IsMe(name)
    local me = NameKey(S.PlainText(UnitName("player")))
    return me ~= nil and NameKey(name) == me
end
Plans.IsMe = IsMe

-- 條件之間是 AND（職責、職業、位置、小隊、玩家都要合），同一類裡是 OR（勾坦克＋治療＝兩種都給）。
-- 讀不到的（專精還沒載）照給：寧可多一條提示，也不要漏。走查：
--   positions={melee}       坦克／近戰專精 → 給；遠程專精 → 不給；專精讀不到 → 給
--   groups={2,3}            第 2 或 3 隊 → 給；不在團隊（當第 1 隊）→ 不給
--   players={"米利"}        自己叫米利（不管伺服器、ASCII 大小寫）→ 給；其他人 → 不給
--   roles={HEALER} ＋ groups={1}   兩個都要合：第 1 隊的治療才給
function Plans.EntryApplies(e)
    if e.enabled == false then return false end
    if e.class and e.class ~= ns.playerClass then return false end
    if e.roles then
        local role = PlayerRole()
        if role and not e.roles[role] then return false end
    end
    if e.positions and next(e.positions) then
        local melee = PlayerIsMelee()
        if melee ~= nil and not e.positions[melee and "melee" or "ranged"] then return false end
    end
    if e.groups and next(e.groups) then
        if not e.groups[PlayerSubgroup()] then return false end
    end
    if e.players and next(e.players) then
        local hit = false
        for name in pairs(e.players) do
            if IsMe(name) then
                hit = true
                break
            end
        end
        if not hit then return false end
    end
    return true
end

-- 兩條的對象條件一樣嗎（匯入去重用：同秒同字但給不同人的，不算重複）
local function SetKey(set)
    if type(set) ~= "table" then return "" end
    local keys = {}
    for k, on in pairs(set) do
        if on then keys[#keys + 1] = tostring(k):lower() end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

function Plans.SameAudience(a, b)
    return (a.class or "") == (b.class or "")
        and SetKey(a.roles) == SetKey(b.roles)
        and SetKey(a.positions) == SetKey(b.positions)
        and SetKey(a.groups) == SetKey(b.groups)
        and SetKey(a.players) == SetKey(b.players)
end

-- 有任何對象條件嗎（清單上標「只給部分人」用）
function Plans.HasAudience(e)
    return (e.roles or e.class or e.positions or e.groups or e.players) and true or false
end

function Plans.RemoveEntry(pid, index)
    local p = Plans.Get(pid)
    if p and p.entries[index] then
        Plans.Checkpoint(pid)
        table.remove(p.entries, index)
    end
end

-- 這一場要跑的條目：所有「生效中、而且適用這個難度」的設定檔合併、照秒數排好；
-- 完全相同的（SameEntry）只留第一條。沒有就 nil。
-- 回傳的是原本的條目表（不是複本）：Scheduler 錨點修正改的是 job.t，不會動到條目本身
function Plans.Active(encounterID, difficultyID)
    local boss = Plans.Boss(encounterID)
    if not boss then return end
    local out = {}
    for _, p in ipairs(Plans.Profiles(encounterID, difficultyID)) do
        if p.active then
            for _, e in ipairs(p.entries) do
                -- 先濾掉不會跑的（停用、職責／職業不合）再去重：不然 A 份停用或只給坦克的那條，
                -- 會把 B 份給所有人的同一條當成重複吃掉
                local dup = not Plans.EntryApplies(e)
                for _, x in ipairs(out) do
                    if SameEntry(x, e) then
                        dup = true
                        break
                    end
                end
                if not dup then out[#out + 1] = e end
            end
        end
    end
    if #out == 0 then return end
    table.sort(out, EntryLess)
    return out
end

------------------------------------------------------------
-- 匯入 MRT 筆記／lorrgs 的提示行
--
-- 一行一條，時間寫在 {time:mm:ss} 裡（MRT 筆記的計時格式）：
--   {time:00:12} - {spell:31821} 光環精通
--   {time:1:30.5}{spell:62618} 真言術：壁
-- 規則：
--   * {spell:N} 取第一個當法術（圖示與預設文字從它來）
--   * 其他 {…}（團隊標記 {skull}／{rt1}、職業標籤）與色碼一律剝掉，剩下的字當提示文字
--   * 時間後面帶階段的（{time:00:54.8,p2}，lorrgs 的「動態計時」）不支援 —— 那是「從第二階段
--     開始算」，我們的自訂時間軸只認開戰後的絕對秒數；算成略過，回報給玩家
--   * 同一秒、同文字、同法術的已經有了就不重複加
-- 筆記行沒有首領資訊：呼叫端決定進哪一份設定檔（目前選的首領，新增一份或併入目前那份）。
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
Plans.CleanText = CleanText     -- DreamForgeTools／NSRT 匯入也用（Plans/Convert.lua）

local function ImportNote(pid, note)
    local p = Plans.Get(pid)
    if not p then return 0, 0, 0 end
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
                    local cand = { t = t, text = text ~= "" and text or nil, spell = spell }
                    local dup = false
                    for _, e in ipairs(p.entries) do
                        if SameEntry(e, cand) then
                            dup = true
                            break
                        end
                    end
                    if dup then
                        skipped = skipped + 1
                    else
                        Plans.SaveEntry(pid, { t = t, text = text, spell = spell, lead = DEFAULT_LEAD })
                        added = added + 1
                    end
                end
            end
        end
    end
    return added, skipped, phased
end

function Plans.ImportNote(pid, note)
    if not Plans.Get(pid) then return 0, 0, 0 end
    return Plans.Batch(pid, function() return ImportNote(pid, note) end)
end

-- 筆記裡有沒有任何一行 {time:}（匯入前先判斷，免得白建一份空的設定檔）
function Plans.LooksLikeNote(note)
    return tostring(note or ""):find("{[Tt][Ii][Mm][Ee]:") ~= nil
end

Plans.DEFAULT_LEAD = DEFAULT_LEAD
