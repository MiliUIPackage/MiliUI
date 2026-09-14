------------------------------------------------------------
-- 坐騎：資料層 ＋ 召喚（不碰任何框）
--
-- ⚠ 遊戲沒有任何 API 能問出「這隻坐騎有沒有修裝／拍賣功能」：
-- GetMountInfoByID／GetMountInfoExtraByID 只有取得方式、陸飛水、isSelfMount，
-- 收藏冊的篩選器也沒有這個維度。所以清單只能硬編 —— 而硬編一定會漏，
-- 所以玩家必須能自己新增分類與坐騎（Options/Tab_Mounts.lua）。
--
-- 硬編用 **spellID** 不用 mountID：spellID 跨陣營、跨客戶端穩定，
-- mountID 才是執行期用 GetMountFromSpell 換出來的東西（換不到＝這個客戶端
-- 沒有這隻，直接跳過）。名字與圖示一律執行期讀，各語系免費。
--
-- 召喚走 C_MountJournal.SummonByID（明文 mountID，插件 Lua 直接呼叫合法），
-- 所以方塊維持普通 Button、**不需要 secure 轉發**。戰鬥中本來就不能上坐騎，
-- 自己擋掉並印一行訊息，不要讓引擎跳紅字。
--
-- 設定預設**整個戰隊共用**一份（db.mounts.shared），玩家可以讓某隻角色
-- 切成專屬（db.mounts.chars[角色key]）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local S = ns.Secret

ns.Mounts = {}
local M = ns.Mounts

local SEED_VERSION = 1

------------------------------------------------------------
-- 種子資料
--
-- 表裡的順序就是預設分類的顯示順序，各分類裡的順序就是自動挑選的優先序。
-- 名字只是註解——執行期一律從收藏冊讀。
------------------------------------------------------------
M.FUNCTIONAL = {
    -- 修裝：商隊雷龍 → 大遠征犛牛 → 灰白丘陵馱獸 → 凍原猛獁象（聯盟／部落）
    -- ⚠ 猛獁象的修裝功能待遊戲內確認：wiki 說會修，另有第三方說法是只買賣不修。
    --   先照 wiki 放進來——它排在最後，前面幾隻有收藏就輪不到它。
    { id = "repair",  spells = { 264058, 122708, 457485, 61425, 61447 } },
    -- 塑形
    { id = "xmog",    spells = { 122708, 457485 } },
    -- 拍賣：鍍金雷龍（拍賣＋信箱）排在商隊雷龍前面
    { id = "auction", spells = { 465235, 264058 } },
    -- 信箱
    { id = "mail",    spells = { 465235 } },
}

-- 兩顆鍵的自動挑選：左鍵挑修裝、右鍵挑拍賣，取**第一隻已收藏**的。
-- 每次點擊現算，不存進 DB —— 之後學到更好的坐騎會自動跟上。
M.PRIORITY = {
    left  = { 264058, 122708, 457485, 61425, 61447 },
    right = { 465235, 264058 },
}

local BUILTIN = {}
for _, def in ipairs(M.FUNCTIONAL) do BUILTIN[def.id] = true end

local function Msg(text)
    print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r " .. text)
end

------------------------------------------------------------
-- 監聽者：方塊圖示、彈出面板、設定分頁都靠它重畫
-- （逐個 xpcall，一支壞掉不連坐——同 Core/Warband.lua）
------------------------------------------------------------
local listeners = {}

function M.AddListener(key, fn)
    listeners[key] = fn
end

function M.RemoveListener(key)
    listeners[key] = nil
end

function M.Fire()
    for _, fn in pairs(listeners) do
        xpcall(fn, ns.ReportError)
    end
end

------------------------------------------------------------
-- 設定檔（戰隊共用 / 角色專屬）
--
-- ⚠ 種子**不能**放進 ns.DB_DEFAULTS：CopyDefaults 是遞迴合併，陣列會按索引
-- 補洞，玩家刪掉第 2 個分類之後每次登入又會被補回來。所以 DB_DEFAULTS 只有
-- `{ shared = {}, chars = {} }`，種子在這裡種、用 version 當印記
-- （同 warband.migration 的思路）。ResetDB 清掉整包之後也會走同一條路重種。
------------------------------------------------------------
local function Root()
    local db = ns.GetDB()
    if type(db.mounts) ~= "table" then db.mounts = {} end
    local root = db.mounts
    if type(root.shared) ~= "table" then root.shared = {} end
    if type(root.chars) ~= "table" then root.chars = {} end
    return root
end

local function Seed(profile)
    if profile.version ~= nil then return profile end
    profile.version = SEED_VERSION
    profile.categories = {}
    for i, def in ipairs(M.FUNCTIONAL) do
        local spells = {}
        for j, id in ipairs(def.spells) do spells[j] = id end
        profile.categories[i] = { id = def.id, spells = spells }
    end
    return profile
end

local function CopyProfile(src)
    local out = { version = src.version, left = src.left, right = src.right, categories = {} }
    for i, cat in ipairs(src.categories or {}) do
        local spells = {}
        for j, id in ipairs(cat.spells or {}) do spells[j] = id end
        out.categories[i] = { id = cat.id, name = cat.name, spells = spells }
    end
    return out
end

function M.IsCharSpecific()
    local own = Root().chars[ns.CharKey()]
    return (own and own.enabled) and true or false
end

-- 生效的那一份：角色專屬開著就用它，否則用戰隊共用
function M.Profile()
    local root = Root()
    local own = root.chars[ns.CharKey()]
    if own and own.enabled then return Seed(own) end
    return Seed(root.shared)
end

-- 切成角色專屬時**深拷貝**一份共用的過去（從現況繼續改，不是從零開始）；
-- 切回共用只把 enabled 關掉，專屬那份留著，下次再打開不會丟。
function M.SetCharSpecific(on)
    local root = Root()
    local key = ns.CharKey()
    if on then
        local own = root.chars[key]
        if not own then
            own = CopyProfile(Seed(root.shared))
            root.chars[key] = own
        end
        own.enabled = true
    elseif root.chars[key] then
        root.chars[key].enabled = false
    end
    M.Fire()
end

------------------------------------------------------------
-- spellID → mountID → 顯示資訊
--
-- 快取兩層：spellID 換 mountID（幾乎不會變）、收藏清單（上千筆的掃描）。
-- 兩層都在 NEW_MOUNT_ADDED 時作廢。
------------------------------------------------------------
local idCache = {}          -- spellID -> mountID
local collectedCache        -- 排序過的收藏清單，第一次要用才掃

-- ⚠ **只快取查到的**。登入那一刻收藏冊不一定就緒，把「查不到」也記起來的話，
-- 那隻坐騎在這一場遊戲裡就永遠解不出來了（而且完全不報錯）。查不到的成本只是
-- 一次 C 呼叫，而清單就那幾筆。
function M.Resolve(spellID)
    if type(spellID) ~= "number" then return nil end
    local cached = idCache[spellID]
    if cached then return cached end
    local id
    if C_MountJournal and C_MountJournal.GetMountFromSpell then
        id = S.PlainNumber(S.SafeCall(C_MountJournal.GetMountFromSpell, spellID))
    end
    if id then idCache[spellID] = id end
    return id
end

-- 玩家陣營：0 ＝ 部落、1 ＝ 聯盟（對上 GetMountInfoByID 的 faction 編碼）。
-- 讀不到或中立（還沒選邊的熊貓人）回 nil ＝ **不過濾**：寧可多列一隻，
-- 也不要因為讀不到就把整份清單砍掉。
local function PlayerFactionID()
    local group = S.PlainText(UnitFactionGroup("player"))
    if group == "Alliance" then return 1 end
    if group == "Horde" then return 0 end
    return nil
end

-- 讀回來的東西全部洗過一次：名字要 SetText、圖示要 SetTexture、
-- collected/usable 要進 if。
--
-- ⚠ collected 讀不到（秘密布林）時當成**已收藏**：坐騎冊不在 12.1 的秘密值
-- 清單裡，這是防禦性的一道。fail-open 的後果是面板多列幾隻召喚不出來的；
-- fail-closed 的後果是整個面板空掉，玩家不知道發生什麼事。
--
-- ⚠ **收藏了不等於這隻角色能騎**：陣營限定的坐騎（旅者的凍原長毛象聯盟版
-- 61425／部落版 61447）兩隻的 isCollected 都是 true，於是修裝分類裡同一隻
-- 長毛象出現兩次、其中一隻點了沒反應。判準是 available，不是 collected。
local function ReadInfo(mountID)
    local name, spellID, icon, _, isUsable, _, _,
          isFactionSpecific, faction, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)

    local collected = S.ToBool(isCollected)
    if collected == nil then collected = true end

    -- 陣營：只有「限定陣營」而且兩邊的編號都讀得到時才比對
    local factionOK = true
    if S.ToBool(isFactionSpecific) == true then
        local mountFaction, playerFaction = S.PlainNumber(faction), PlayerFactionID()
        if mountFaction and playerFaction then
            factionOK = (mountFaction == playerFaction)
        end
    end
    -- 暴雪自己的「這隻角色的收藏冊要藏起來」旗標（職業／種族限定那類）
    local hidden = S.ToBool(shouldHideOnChar) == true

    return {
        mountID   = mountID,
        spellID   = S.PlainNumber(spellID),
        name      = S.PlainText(name),
        icon      = S.PlainNumber(icon) or S.PlainText(icon),
        collected = collected,
        factionOK = factionOK,
        hidden    = hidden,
        -- 「這隻角色現在真的能召喚它」——面板、自動挑選、隨機、選擇器一律看這個
        available = collected and factionOK and not hidden,
        usable    = S.ToBool(isUsable) ~= false,
    }
end

function M.Info(spellID)
    local mountID = M.Resolve(spellID)
    if not mountID then return nil end
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return nil end
    local ok, info = pcall(ReadInfo, mountID)
    if not ok then return nil end
    info.spellID = spellID          -- 查表用的那個才是權威（同一隻可能有多個法術）
    return info
end

-- 名字讀不到（秘密字串／資料還沒到）時給一個不會讓版面塌掉的替代字
function M.Name(spellID)
    local info = M.Info(spellID)
    return (info and info.name) or "?"
end

------------------------------------------------------------
-- 可用清單（設定視窗的選擇器用）
--
-- 名字留著 CollectedMounts，但判準是 **available**：把別的陣營／這隻角色用不了
-- 的坐騎列進選擇器，只會讓玩家加一筆自己永遠看不到的東西進分類。
--
-- ⚠ GetMountIDs() 是上千筆，**只在設定視窗真的打開時才掃**，而且掃完快取。
-- 登入與方塊建立時一律不碰（效能紀律）。
------------------------------------------------------------
function M.CollectedMounts()
    if collectedCache then return collectedCache end
    local out = {}
    if C_MountJournal and C_MountJournal.GetMountIDs then
        for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
            local ok, info = pcall(ReadInfo, mountID)
            if ok and info.available and info.name and info.spellID then
                idCache[info.spellID] = mountID
                out[#out + 1] = info
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    collectedCache = out
    return out
end

local function InvalidateCaches()
    wipe(idCache)
    collectedCache = nil
end

------------------------------------------------------------
-- 分類
------------------------------------------------------------
function M.Categories()
    return M.Profile().categories or {}
end

-- 內建分類沒有存名字（name = nil）→ 顯示語系字串；玩家改過名就存字串。
-- 內建分類本身就是普通資料：可以改名、排序、刪除，「重設為預設」整包換回種子。
function M.CategoryName(cat)
    if type(cat.name) == "string" and cat.name ~= "" then return cat.name end
    if BUILTIN[cat.id] then return L["MOUNT_CAT_" .. cat.id:upper()] end
    return cat.id or "?"
end

function M.AddCategory(name)
    local cats = M.Categories()
    cats[#cats + 1] = { id = "u" .. time(), name = name, spells = {} }
    M.Fire()
end

function M.RenameCategory(index, name)
    local cat = M.Categories()[index]
    if not cat then return end
    cat.name = (type(name) == "string" and strtrim(name) ~= "") and strtrim(name) or nil
    M.Fire()
end

function M.MoveCategory(index, delta)
    local cats = M.Categories()
    local target = index + delta
    if not (cats[index] and cats[target]) then return end
    cats[index], cats[target] = cats[target], cats[index]
    M.Fire()
end

function M.RemoveCategory(index)
    local cats = M.Categories()
    if not cats[index] then return end
    table.remove(cats, index)
    M.Fire()
end

function M.HasMount(index, spellID)
    local cat = M.Categories()[index]
    if not cat then return false end
    for _, id in ipairs(cat.spells) do
        if id == spellID then return true end
    end
    return false
end

function M.AddMount(index, spellID)
    local cat = M.Categories()[index]
    if not (cat and type(spellID) == "number") then return end
    if M.HasMount(index, spellID) then return end       -- 去重
    cat.spells[#cat.spells + 1] = spellID
    M.Fire()
end

function M.RemoveMount(index, spellID)
    local cat = M.Categories()[index]
    if not cat then return end
    for i, id in ipairs(cat.spells) do
        if id == spellID then
            table.remove(cat.spells, i)
            M.Fire()
            return
        end
    end
end

function M.ResetToDefaults()
    local profile = M.Profile()
    profile.version = nil
    profile.left, profile.right = nil, nil
    Seed(profile)
    M.Fire()
end

------------------------------------------------------------
-- 兩顆鍵
------------------------------------------------------------
function M.AutoPick(side)
    for _, spellID in ipairs(M.PRIORITY[side] or {}) do
        local info = M.Info(spellID)
        -- available 不是 collected：兩隻長毛象都在優先序裡，挑的要是這隻角色騎得動的那隻
        if info and info.available then return spellID end
    end
    return nil
end

-- 玩家指定的優先；沒指定就現算。回 nil ＝ 那顆鍵沒有坐騎。
function M.Assigned(side)
    local explicit = M.Profile()[side]
    if explicit then return explicit end
    return M.AutoPick(side)
end

function M.IsAuto(side)
    return M.Profile()[side] == nil
end

function M.SetAssigned(side, spellID)
    M.Profile()[side] = spellID
    M.Fire()
end

-- 這隻坐騎現在綁在哪顆鍵上（面板右側的灰色小標）
function M.BoundSide(spellID)
    local left, right = M.Assigned("left"), M.Assigned("right")
    if left == spellID and right == spellID then return "both" end
    if left == spellID then return "left" end
    if right == spellID then return "right" end
    return nil
end

------------------------------------------------------------
-- 召喚
------------------------------------------------------------
function M.Summon(spellID)
    if not spellID then return false, "unset" end
    -- 戰鬥中本來就上不了坐騎：自己擋掉，引擎才不會跳紅字
    if InCombatLockdown() then
        Msg(L["MSG_COMBAT_MOUNT"])
        return false, "combat"
    end
    local info = M.Info(spellID)
    if not info then
        Msg(L["MSG_MOUNT_NOT_COLLECTED"])
        return false, "missing"
    end
    -- 收藏了但是另一個陣營的版本：講清楚為什麼，不要跟「沒收藏」混為一談
    if info.collected and not info.factionOK then
        Msg(L["MSG_MOUNT_OTHER_FACTION"])
        return false, "faction"
    end
    if not info.collected then
        Msg(L["MSG_MOUNT_NOT_COLLECTED"])
        return false, "missing"
    end
    if info.hidden then
        Msg(L["MSG_MOUNT_UNUSABLE"])
        return false, "hidden"
    end
    if C_MountJournal.GetMountUsabilityByID then
        -- MayReturnNothing：兩個回傳都可能沒有，先落地再判斷
        local usable, err = S.SafeCall(C_MountJournal.GetMountUsabilityByID, info.mountID, true)
        if S.ToBool(usable) == false then
            Msg(S.PlainText(err) or L["MSG_MOUNT_UNUSABLE"])
            return false, "unusable"
        end
    end
    C_MountJournal.SummonByID(info.mountID)
    return true
end

-- 某個分類裡隨機一隻（只從「這隻角色能召喚而且現在能用」的裡面挑）
function M.RandomIn(index)
    local cat = M.Categories()[index]
    if not cat then return false end
    local pool = {}
    for _, spellID in ipairs(cat.spells) do
        local info = M.Info(spellID)
        if info and info.available and info.usable then
            pool[#pool + 1] = spellID
        end
    end
    if #pool == 0 then
        Msg(L["MSG_NO_USABLE_MOUNT"])
        return false
    end
    return M.Summon(pool[math.random(#pool)])
end

-- 某個分類裡「這隻角色能召喚」的隻數（面板決定要不要畫這一段、要不要給隨機鈕）
function M.CollectedCountIn(cat)
    local n = 0
    for _, spellID in ipairs(cat.spells or {}) do
        local info = M.Info(spellID)
        if info and info.available then n = n + 1 end
    end
    return n
end

------------------------------------------------------------
-- 事件
--
-- 學到新坐騎：兩層快取都作廢（新的那隻可能就是優先序裡的第一名）。
-- 可用性變了（進副本、變形、水下）：只要通知重畫。
-- 進世界：收藏清單快取裡的 available 是**當時那隻角色**算出來的，換角色（或熊貓人
-- 選了陣營）之後陣營就不一樣了。丟掉重算——反正只有選擇器打開時才會真的去掃。
------------------------------------------------------------
local inited = false

function M.Init()
    if inited then return end
    inited = true
    ns.Events.Register("NEW_MOUNT_ADDED", "mounts", function()
        InvalidateCaches()
        M.Fire()
    end)
    ns.Events.Register("MOUNT_JOURNAL_USABILITY_CHANGED", "mounts", M.Fire)
    ns.Events.Register("PLAYER_ENTERING_WORLD", "mounts", InvalidateCaches)
end

ns.Events.Register("PLAYER_LOGIN", "mounts-init", M.Init)
