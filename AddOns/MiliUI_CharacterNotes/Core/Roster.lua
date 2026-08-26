------------------------------------------------------------
-- 分組變數（roster）
--
-- 使用者的模型：時間軸用**變數**寫（{p:主坦}），變數裡再填「這場實際是誰」。
-- 下次組團只要重新分配變數內的名單，所有時間軸筆記就自動指到新的人。
--
-- 資料（帳號層，跟副本筆記一樣全分身共用）：
--   db.roster.groups  = { { id, name, members = { "Name1", ... } }, ... }
--   db.roster.classOf = { [name] = classFile }   -- 盡力而為的職業色快取
--
-- 為什麼變數靠**名字**參照而不是 id：玩家是直接在筆記裡打 {p:主坦} 的，名字就是
-- 介面。改名會讓舊筆記對不上（跟同類插件一樣），但插入選單一律插入目前的名字，
-- 新寫的不會錯。id 只用在設定介面的列表 key。
--
-- ⚠ 12.1：讀隊友職業要擋秘密值。名字本身在受限身分下也可能是秘密值，一律先擋
--   再拿去當 table key 或比對。
------------------------------------------------------------
local _, ns = ...

ns.Roster = {}
local Roster = ns.Roster

------------------------------------------------------------
-- 存取
------------------------------------------------------------
local function DB()
    local db = ns.db
    if type(db.roster) ~= "table" then db.roster = {} end
    local r = db.roster
    if type(r.groups) ~= "table" then r.groups = {} end
    if type(r.classOf) ~= "table" then r.classOf = {} end
    return r
end

local function GenID()
    return "g" .. time() .. math.random(1000, 9999)
end

------------------------------------------------------------
-- 內建範例分組：第一次啟動塞幾個常見的當範本。
-- 只塞一次（seeded 印記）——玩家把它們刪光是刻意的，不要又長回來。
-- 名字走 L[]（英文系客戶端會是英文），玩家可以改。
------------------------------------------------------------
function Roster.EnsureDefaults()
    local r = DB()
    if r.seeded then return end
    r.seeded = true
    if #r.groups > 0 then return end
    for _, key in ipairs({ "Main tank", "Off tank", "Main healer", "Healers", "Interrupts" }) do
        r.groups[#r.groups + 1] = { id = GenID(), name = ns.L[key], members = {} }
    end
end

------------------------------------------------------------
-- 職業色快取
------------------------------------------------------------
local function RememberClass(name, classFile)
    if type(name) ~= "string" or ns.issecret(name) then return end
    if type(classFile) ~= "string" or ns.issecret(classFile) then return end
    DB().classOf[name] = classFile
end
Roster.RememberClass = RememberClass

function Roster.ClassOf(name)
    if type(name) ~= "string" then return nil end
    -- 自己的職業最準（player token 不受限）
    local me = UnitName("player")
    if me and not ns.issecret(me) and name == me then return ns.playerClass end
    return DB().classOf[name]
end

------------------------------------------------------------
-- 分組查詢／編輯
------------------------------------------------------------
function Roster.Groups()
    return DB().groups
end

local function FindByName(name)
    if type(name) ~= "string" then return nil end
    local key = strtrim(name):lower()
    if key == "" then return nil end
    for _, g in ipairs(DB().groups) do
        if g.name:lower() == key then return g end
    end
    return nil
end
Roster.FindByName = FindByName

function Roster.FindByID(id)
    for _, g in ipairs(DB().groups) do
        if g.id == id then return g end
    end
    return nil
end

-- 回傳這個名字（變數或直接玩家名）解出來的名單；不是變數就回 nil（＝當字面名字）
function Roster.Resolve(name)
    local g = FindByName(name)
    if not g then return nil end
    return g.members
end

function Roster.AddGroup(name)
    name = strtrim(name or "")
    if name == "" then return nil end
    if FindByName(name) then return nil end   -- 同名視為已存在
    local g = { id = GenID(), name = name, members = {} }
    DB().groups[#DB().groups + 1] = g
    ns.Fire("RosterChanged")
    return g
end

function Roster.RenameGroup(id, newName)
    newName = strtrim(newName or "")
    if newName == "" then return false end
    local exist = FindByName(newName)
    if exist and exist.id ~= id then return false end
    local g = Roster.FindByID(id)
    if not g then return false end
    g.name = newName
    ns.Fire("RosterChanged")
    return true
end

function Roster.DeleteGroup(id)
    local groups = DB().groups
    for i, g in ipairs(groups) do
        if g.id == id then
            table.remove(groups, i)
            ns.Fire("RosterChanged")
            return true
        end
    end
    return false
end

local function HasMember(g, name)
    local key = name:lower()
    for _, m in ipairs(g.members) do
        if m:lower() == key then return true end
    end
    return false
end

-- name 是短名（Name）或全名（Name-Realm）。classFile 給了就記進快取
function Roster.AddMember(id, name, classFile)
    name = strtrim(name or "")
    if name == "" or ns.issecret(name) then return false end
    local g = Roster.FindByID(id)
    if not g then return false end
    if not HasMember(g, name) then
        g.members[#g.members + 1] = name
    end
    RememberClass(name, classFile)
    ns.Fire("RosterChanged")
    return true
end

function Roster.RemoveMember(id, name)
    local g = Roster.FindByID(id)
    if not g then return false end
    local key = tostring(name):lower()
    for i, m in ipairs(g.members) do
        if m:lower() == key then
            table.remove(g.members, i)
            ns.Fire("RosterChanged")
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- 目前隊伍／團隊成員（給「不打字直接選」的選單用）
--
-- 回傳陣列 { { name = 短名, class = classFile|nil }, ... }，含自己。
-- 讀得到職業就順手記進快取，之後渲染 chip 才有色。
------------------------------------------------------------
function Roster.LiveMembers()
    local out, seen = {}, {}

    local function add(unit)
        local name = UnitName(unit)
        if not name or ns.issecret(name) then return end
        local key = name:lower()
        if seen[key] then return end
        seen[key] = true
        local classFile = select(2, UnitClass(unit))
        if type(classFile) == "string" and not ns.issecret(classFile) then
            RememberClass(name, classFile)
        else
            classFile = Roster.ClassOf(name)
        end
        out[#out + 1] = { name = name, class = classFile }
    end

    add("player")
    if IsInRaid() then
        for i = 1, (GetNumGroupMembers() or 0) do add("raid" .. i) end
    elseif IsInGroup() then
        for i = 1, (GetNumGroupMembers() or 0) - 1 do add("party" .. i) end
    end
    return out
end

------------------------------------------------------------
-- 標記用：把 `{p:X}` 裡的 X 解成一串名字
--
-- X 是分組變數就回那組的名單，不是就當成直接打的玩家名字（回它自己）。
-- 空字串回空陣列 —— 呼叫端據此顯示「還沒分配」。
------------------------------------------------------------
function Roster.ResolveNames(who)
    who = strtrim(tostring(who or ""))
    if who == "" then return {} end
    local g = FindByName(who)
    if g then return g.members end
    return { who }
end
