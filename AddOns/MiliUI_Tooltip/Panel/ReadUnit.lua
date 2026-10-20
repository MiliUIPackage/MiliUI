------------------------------------------------------------
-- 單位（玩家／NPC）reader：Unit API 的明文事實 ＋ 暴雪原樣的提示行 → model
--
-- 跟物品／法術同一條「重繪面板」管線（Try.lua），差在三件事：
--   1. 入口 Panel.TryUnit：先問開關（玩家／NPC 各一個；兩個都關＝Hooks 連這支都不叫，零成本）、
--      解析出**明文**的單位 token、問身分是不是秘密（C_Secrets.ShouldUnitIdentityBeSecret）——受限就走下面的受限畫法。
--      拿不到明文 token ⇒ 不接，舊樣式（Modules/UnitLines.lua 就地改寫）照常跑。
--   2. 面板接手時**不改寫暴雪的行**（舊樣式那條才寫）：reader 讀到的是暴雪原樣的行，認法比較單純；
--      別人後加的行（lineIndex 不在 data 裡）照物品的規矩進附屬框。
--   3. 目標、死亡、暫離這些不在行裡 ⇒ Panel.UnitDynamic 給一段簽章，輪詢比它（Try.lua）。
--
-- 秘密值：明文單位的面板只畫明文；它的**目標的名字**受限時原封不動交給 SetText（ViewUnit 的目標列）。
--
-- 身分受限的單位（2026-10-21 起也接；探針 _MiliProbe_SecretUnit 在副本與 M+（含戰鬥、首領戰）實測，進副本就受限）：
--   * GUID、名字、生物類型、PvP 是秘密；等級、分類、立場、被搶怪、死亡、是否存在是明文
--   * GetUnit 的 token 是秘密字串，餵 UnitLevel 這些會被擋（Usage 錯誤）⇒ 世界游標的提示改用明文 "mouseover"
--   * 提示行的文字、顏色是秘密，type／lineIndex 是明文。NPC 的等級行、類型行、PvP 行都是 type 0（None）：
--     認不出哪一行是哪一行，但順序固定——名字後的第一個 None 行是等級行（面板用等級底板＋分類徽章畫），
--     其餘 None 行照順序原封不動交給 SetText 放在標題區（類型行只有部分生物有；M+ 的怪多兩行）。
--     認得出型別的（任務、主人、仇恨、M+ 敵軍部隊的進度 type 50）一樣原封不動交給 SetText
--   * 原生 GameTooltip 的幾何（GetPoint／寬高／padding）一直是明文（戰鬥、首領戰也是）⇒ 替身照常撐、照常對齊；
--     秘密字串的寬照原生排好的寬留
--   ⇒ 標題區：頭像、等級底板、名字（秘密、單行）、暴雪的其餘 None 行（秘密、單行）、分類／立場／死亡徽章。
--     頭銜（極少見）會被當成等級行吃掉；「被誰當目標」比不了單位，不畫
--
-- 純邏輯 Panel.ReadUnitRows(rows, facts) 吃 CollectLines 的 rows ＋ 已經讀好的事實，可離線測。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel
local Patterns = ns.Patterns

local LT = Enum and Enum.TooltipDataLineType or {}
Panel.readers = Panel.readers or {}

local function Strip(text)
    if type(text) ~= "string" then return "" end
    local s = Patterns.StripColors(Patterns.StripTextures(text))
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

------------------------------------------------------------
-- 認行用的字（全部從 GlobalStrings 讀，不寫語言字面）
------------------------------------------------------------
local words
local function Words()
    if words then return words end
    words = { exact = {}, skin = {} }
    local function add(t, key) local v = _G[key]; if type(v) == "string" and v ~= "" then t[v] = key end end
    -- 由 API 畫的（陣營、PvP、死亡、屍體）：行本身丟掉
    for _, key in ipairs({ "FACTION_ALLIANCE", "FACTION_HORDE", "PVP", "DEAD", "CORPSE" }) do add(words.exact, key) end
    -- 可剝皮／需要草藥學…：留成狀態徽章（原字）
    for _, key in ipairs({ "UNIT_SKINNABLE_LEATHER", "UNIT_SKINNABLE_HERB", "UNIT_SKINNABLE_ROCK",
        "UNIT_SKINNABLE_BOLTS", "UNIT_SKINNABLE_ENGINEERING" }) do add(words.skin, key) end
    words.level = type(_G.LEVEL) == "string" and _G.LEVEL ~= "" and _G.LEVEL or nil
    words.hint = type(_G.UNIT_POPUP_RIGHT_CLICK) == "string" and _G.UNIT_POPUP_RIGHT_CLICK or nil
    return words
end
Panel.ResetUnitWords = function() words = nil end      -- 離線測試換語系用

local function IsLevelLine(text)
    local w = Words()
    return w.level ~= nil and text:sub(1, #w.level) == w.level
end

-- 公會行兩種寫法：「<公會> 階級」，以及不帶角括號的「公會-伺服器」（另起一行，標題區已經畫了公會 ⇒ 都丟）
local function IsGuildLine(text, guild)
    if text:sub(1, 1) == "<" then return text:find(guild, 1, true) ~= nil end
    return text == guild or text:sub(1, #guild + 1) == guild .. "-"
end

local function IsBreak(row)
    if row.type ~= nil and (row.type == LT.Blank or row.type == LT.Separator) then return true end
    return Strip(row.left) == "" and not row.right
end

------------------------------------------------------------
-- 純邏輯：rows（CollectLines）＋ facts → model
--   facts = { isPlayer, name, guild, className, ... }（Panel.UnitFacts；離線測試直接給）
--   model.npcTitle：NPC 名字與等級行之間的第一行（「<旅店老闆>」）
--   model.specLine：玩家含職業名的最短一行（暴雪的「毀滅 術士」）——資訊行用它取代單純的職業名
--   model.owner：UnitOwner 型別（「某某的寵物」）
--   model.skin：可剝皮／需要採礦…（狀態徽章）
--   model.quests：任務標題與目標（QuestTitle／QuestObjective／QuestPlayer）
--   model.others：認不出用途的暴雪行（NPC 的第二行頭銜、威脅…）
--   model.extras：別人後加的行（附屬框）
------------------------------------------------------------
function Panel.ReadUnitRows(rows, facts, hideHint)
    local w = Words()
    local model = { facts = facts, quests = {}, others = {}, extras = {}, skin = {} }
    local nameSeen, levelSeen = false, false
    local beforeLevel = {}           -- NPC：名字之後、等級行之前的行（頭銜候選）
    local className = facts.isPlayer and (facts.classLine or facts.className) or nil
    local guildLine = facts.isPlayer and (facts.guildLine or facts.guild) or nil
    local specIndex, specLen
    local pending = {}               -- 還沒歸類的一般行（等找完職業行再放進 others）

    for _, row in ipairs(rows) do
        local text = Strip(row.left)
        if row.appended then
            if text ~= "" or (row.right and row.right ~= "") then
                if not (hideHint and w.hint and text == w.hint) then
                    model.extras[#model.extras + 1] = row
                end
            end
        elseif not nameSeen then
            if not IsBreak(row) then nameSeen = true end           -- 第一行＝名字（API 畫）
        elseif IsBreak(row) then
            -- 空行：面板自己分段
        elseif w.hint and text == w.hint then
            -- 右鍵提示：設定開著就丟，關著放其他
            if not hideHint then pending[#pending + 1] = row end
        elseif LT.UnitOwner and row.type == LT.UnitOwner then
            model.owner = row.left
        elseif (LT.QuestTitle and row.type == LT.QuestTitle) then
            model.quests[#model.quests + 1] = { left = row.left, right = row.right, color = row.color,
                rightColor = row.rightColor, title = true }
        elseif (LT.QuestObjective and row.type == LT.QuestObjective) or (LT.QuestPlayer and row.type == LT.QuestPlayer) then
            model.quests[#model.quests + 1] = { left = row.left, right = row.right, color = row.color,
                rightColor = row.rightColor }
        elseif IsLevelLine(text) then
            levelSeen = true
            -- NPC 的頭銜：等級行之前的那幾行，第一行當頭銜、其他放其他
            if not facts.isPlayer then
                for i, r in ipairs(beforeLevel) do
                    if i == 1 then model.npcTitle = r.left else pending[#pending + 1] = r end
                end
                beforeLevel = {}
            end
        elseif w.exact[text] then
            -- 陣營、PvP、死亡：API 畫
        elseif w.skin[text] then
            model.skin[#model.skin + 1] = row.left
        elseif guildLine and IsGuildLine(text, guildLine) then
            -- 公會行：API 畫
        elseif not facts.isPlayer and not levelSeen then
            beforeLevel[#beforeLevel + 1] = row
        else
            pending[#pending + 1] = row
            -- 玩家的職業行：含職業名的最短一行（不是等級行、不是 <…>）
            if className and className ~= "" and text:sub(1, 1) ~= "<" and text:find(className, 1, true) then
                if not specLen or #text < specLen then specIndex, specLen = #pending, #text end
            end
        end
    end
    -- 沒有等級行的 NPC（寵物、有些物件）：頭銜候選照「第一行頭銜、其他放其他」
    for i, r in ipairs(beforeLevel) do
        if i == 1 then model.npcTitle = r.left else pending[#pending + 1] = r end
    end
    for i, r in ipairs(pending) do
        if i == specIndex then
            model.specLine = Strip(r.left)
        else
            model.others[#model.others + 1] = { left = r.left, right = r.right, color = r.color, rightColor = r.rightColor }
        end
    end
    return model
end

------------------------------------------------------------
-- 明文 token：GetUnit 的 token 可能是秘密字串（世界游標），也可能是過期的 mouseover ⇒ 用 data 的 GUID 驗證／反查
------------------------------------------------------------
local function GuidOf(token)
    return S.PlainText((S.SafeCall(UnitGUID, token)))
end

-- 回傳 token, guid, restricted。restricted＝身分受限（data 的 GUID 是秘密）：guid 是 nil，只能靠明文 token——
-- 明文的就用它（目標框、首領框）；秘密的（世界游標）用 mouseover 代替：世界游標的提示就是游標下那一隻，
-- 而受限時 GUID、UnitIsUnit 都比不了，沒有別的辦法確認
function Panel.UnitToken(unit, data)
    local rawGuid = type(data) == "table" and data.guid or nil
    local guid = S.PlainText(rawGuid)
    local plain = S.PlainText(unit)
    if S.IsSecret(rawGuid) then
        if plain and plain ~= "" then return plain, nil, true end
        if S.IsSecret(unit) and S.SafeBool(UnitExists, "mouseover") then return "mouseover", nil, true end
        return nil
    end
    if plain and plain ~= "" then
        if not guid or GuidOf(plain) == guid then return plain, guid end
    end
    if not guid then return nil end
    if UnitTokenFromGUID then
        local t = S.PlainText((S.SafeCall(UnitTokenFromGUID, guid)))
        if t and t ~= "" then return t, guid end
    end
    if GuidOf("mouseover") == guid then return "mouseover", guid end
end

-- 身分受限 ⇒ 整組是秘密值，不接（秘密布林、問不到都當受限）
local function IdentitySecret(token)
    local api = C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
    if not api then return false end
    local ok, v = pcall(api, token)
    if not ok or S.IsSecret(v) then return true end
    return v and true or false
end

------------------------------------------------------------
-- 入口（Core/Hooks.lua 的 OnUnit；兩個開關都關時 Hooks 根本不會叫到這裡）
------------------------------------------------------------
local function Restore(tip, state)
    if state.native or (state.panel and state.panel:IsShown()) then Panel.Restore(tip, state) end
    return false
end

function Panel.UnitWanted()
    local u = ns.db and ns.db.unit
    return u ~= nil and ((u.player and u.player.panel) or (u.npc and u.npc.panel)) and true or false
end

function Panel.TryUnit(tip, state, unit, data)
    local token, guid, restricted = Panel.UnitToken(unit, data)
    if not token or not (guid or restricted) then return Restore(tip, state) end
    local isPlayer = S.SafeBool(UnitIsPlayer, token)
    local config = ns.db.unit[isPlayer and "player" or "npc"]
    if not (config and config.panel) then return Restore(tip, state) end
    -- GUID 讀得到、但 C_Secrets 說身分受限（秘密布林、問不到都算）：一樣走受限的畫法
    if not restricted and IdentitySecret(token) then restricted, guid = true, nil end
    -- 剛從面板退回舊樣式的同一個單位：1 秒內不再接（不然「退回 → Show 重跑 → 又接 → 又退」來回）。
    -- 受限的單位沒有 GUID ⇒ 共用一把
    local blockKey = restricted and Panel.UNIT_BLOCK_RESTRICTED or ("unit:" .. guid)
    if state.unitBlockKey == blockKey and GetTime() < (state.unitBlockUntil or 0) then
        return Restore(tip, state)
    end
    state.panelUnit, state.panelGuid, state.panelRestricted = token, guid, restricted or nil
    return Panel.Try(tip, state, "unit", data)
end

-- 單位不在了（滑開、淡出中、token 換人了）：面板維持最後的畫面，不重讀。
-- 受限的單位 GUID 是秘密：只能確定還存在（換成另一隻時暴雪會重設提示、post-call 照新的一隻重畫）
function Panel.UnitGone(state)
    local token = state.panelUnit
    if not token then return true end
    local exists = S.SafeCall(UnitExists, token)
    if not S.IsSecret(exists) and exists ~= nil and not exists then return true end
    if state.panelRestricted then return false end
    local guid = GuidOf(token)
    return guid == nil or guid ~= state.panelGuid
end

------------------------------------------------------------
-- 動態簽章：不在提示行裡、靠 API 讀的東西（輪詢 0.1 秒比一次，變了就重畫）。
-- 單位不在了回 nil（不動）。秘密的目標記成 "?"——名字由 Panel.UnitTick 直接 SetText，不重畫
------------------------------------------------------------
local function B(fn, token) return S.SafeBool(fn, token) and "1" or "0" end

function Panel.UnitDynamic(state)
    if Panel.UnitGone(state) then return nil end
    local token = state.panelUnit
    local target = "-"
    local tt = token .. "target"
    if S.SafeBool(UnitExists, tt) then
        target = GuidOf(tt) or "?"
    end
    local cache = ""
    local info = ns.UnitInfo
    local guid = state.panelGuid
    if info and guid then
        local ins = info.inspectState and info.inspectState.cache[guid]
        local ach = info.achieveState and info.achieveState.cache[guid]
        cache = (ins and ins.level or "") .. "/" .. (ach and ach.points or "")
    end
    return table.concat({ target, B(UnitIsDead, token), B(UnitIsAFK, token), B(UnitIsDND, token),
        B(UnitIsTapDenied, token), B(UnitIsPVP, token), cache,
        (IsAltKeyDown() or IsControlKeyDown()) and "m" or "" }, "|")
end

-- 秘密的目標名字：每次輪詢重新交給 SetText（不讀、不量）
function Panel.UnitTick(state)
    local fs = state.panelTargetFS
    if not fs or not state.panelUnit then return end
    local name = S.SafeCall(UnitName, state.panelUnit .. "target")
    if name ~= nil then fs:SetText(name) end
end

------------------------------------------------------------
-- 事實：Unit API → 明文表（元素開關／顯示條件照舊樣式那套：config.elements[x].enable ＋ filter，
-- 按住修飾鍵且開著 modifierShowAll 時全部顯示）
------------------------------------------------------------
local function ColorTable(r, g, b)
    r, g, b = S.PlainNumber(r), S.PlainNumber(g), S.PlainNumber(b)
    if r and g and b then return { r, g, b } end
end

local function ClassColor(classFile)
    classFile = S.PlainText(classFile)
    local c = classFile and ((_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[classFile]) or
        (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]))
    if c and type(c.r) == "number" then return { c.r, c.g, c.b } end
end
Panel.ClassColor = ClassColor

-- 單位色：玩家職業色；其他走立場（Colors.UnitColor，玩家控制的照敵我）
local function UnitColorOf(token)
    if S.SafeBool(UnitIsPlayer, token) then
        local _, cls = S.SafeCall(UnitClass, token)
        local c = ClassColor(cls)
        if c then return c end
    end
    local r, g, b = ns.Colors.UnitColor(token)
    return ColorTable(ns.Colors.Readable(r, g, b)) or { 1, 1, 1 }
end
Panel.UnitColorOf = UnitColorOf

local function DifficultyColor(level)
    if level == -1 then return { 1, 0.1, 0.1 } end
    if GetCreatureDifficultyColor then
        local ok, c = pcall(GetCreatureDifficultyColor, level)
        if ok and type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    end
    return { 1, 0.82, 0 }
end

local function Target(token)
    local tt = token .. "target"
    if not S.SafeBool(UnitExists, tt) then return nil end
    if S.SafeBool(UnitIsUnit, tt, "player") then return { you = true } end
    local name = S.SafeCall(UnitName, tt)
    if name == nil then return nil end
    if S.IsSecret(name) then return { secret = true, color = { 1, 1, 1 } } end
    if name == "" then return nil end
    return { name = name, color = UnitColorOf(tt) }
end

-- 隊伍／團隊裡把這個單位當目標的人（不含自己）：小隊列名字、團隊只數人數（跟舊樣式一樣）
local function TargetedBy(token)
    local num = GetNumGroupMembers and GetNumGroupMembers() or 0
    if num < 1 then return nil end
    local prefix = IsInRaid() and "raid" or "party"
    local names, count = {}, 0
    for i = 1, num do
        local member = prefix .. i
        if S.SafeBool(UnitIsUnit, token, member .. "target") and not S.SafeBool(UnitIsUnit, member, "player") then
            count = count + 1
            if prefix == "party" then
                local name = S.PlainText((S.SafeCall(UnitName, member)))
                local _, cls = S.SafeCall(UnitClass, member)
                if name then names[#names + 1] = { name = name, color = ClassColor(cls) } end
            end
        end
    end
    if count == 0 then return nil end
    return { count = count, names = (prefix == "party") and names or nil }
end

function Panel.UnitFacts(token, config)
    local UnitInfo = ns.UnitInfo
    local raw = UnitInfo.GetUnitInfo(token)          -- 共用表：這裡只讀，抄成自己的明文欄位
    local name = S.PlainText(raw.name)
    if not name or name == "" then return nil end
    local showAll = UnitInfo.ModifierShowAll(config)
    local el = config.elements or {}
    local function on(key)
        local c = el[key]
        return c ~= nil and UnitInfo.CheckFilter(c, raw, showAll) and true or false
    end
    local isPlayer = S.SafeBool(UnitIsPlayer, token)
    local f = { isPlayer = isPlayer, name = name, showAll = showAll }

    -- 名字列：頭銜、跨服、好友／職責小圖示
    if isPlayer then
        if on("title") then f.title, f.titlePrefix = S.PlainText(raw.title), raw.titleIsPrefix end
        local _, realm = S.SafeCall(UnitName, token)
        realm = S.PlainText(realm)
        if on("realm") and realm and realm ~= "" then f.realm = realm end
        if on("friendIcon") then f.friendIcon = raw.friendIcon end
        if on("roleIcon") then f.roleIcon = raw.roleIcon end
    end

    -- 等級（徽章）
    local level = S.PlainNumber(raw.level)
    if on("levelValue") and level then
        f.level = level
        local lv = S.PlainNumber(raw.effectiveLevel) or level
        f.levelColor = DifficultyColor(level == -1 and -1 or lv)
    end

    if isPlayer then
        -- 認行用的（不管元素開不開都要知道，暴雪的公會行／職業行才丟得掉）
        f.guildLine = S.PlainText(raw.guildName)
        f.classLine = S.PlainText(raw.className)
        if on("guildName") then f.guild = f.guildLine end
        if f.guild and on("guildRank") then f.guildRank = S.PlainText(raw.guildRank) end
        if on("raceName") then f.race = S.PlainText(raw.raceName) end
        if on("className") then f.className = S.PlainText(raw.className) end
        if on("gender") then f.gender = S.PlainText(raw.gender) end
        f.classFile = S.PlainText(raw.class)
        if on("factionName") then
            local fn = S.PlainText(raw.factionName)
            if fn then
                local r, g, b = ns.Colors.colorfunc.faction(raw)
                f.factionName, f.factionColor = fn, ColorTable(r, g, b)
            end
        end
        if on("statusAFK") then f.afk = raw.statusAFK ~= nil end
        if on("statusDND") then f.dnd = raw.statusDND ~= nil end
        if on("statusDC") then f.dc = raw.statusDC ~= nil end
        if on("isPlayer") then f.playerTag = _G.PLAYER end
    else
        if on("creature") then f.creature = S.PlainText(raw.creature) end
        local classif = S.PlainText(raw.classif)
        if level == -1 or classif == "worldboss" then
            if on("classifBoss") then f.classif = "boss" end
        elseif classif == "rareelite" then
            f.classif = on("classifRare") and (on("classifElite") and "rareelite" or "rare") or (on("classifElite") and "elite") or nil
        elseif classif == "rare" then
            if on("classifRare") then f.classif = "rare" end
        elseif classif == "elite" then
            if on("classifElite") then f.classif = "elite" end
        end
        if on("reactionName") then f.reactionName = S.PlainText(raw.reactionName) end
        f.npcTitleOn = on("npcTitle")
        f.tapped = S.SafeBool(UnitIsTapDenied, token)
    end
    f.factionGroup = S.PlainText(raw.factionGroup)
    f.classifPlain = S.PlainText(raw.classif)
    f.pvp = S.SafeBool(UnitIsPVP, token)
    f.dead = S.SafeBool(UnitIsDeadOrGhost, token)

    -- 細節列
    if isPlayer then
        if on("mount") then
            UnitInfo.FillMount(raw, token)
            local mount = S.PlainText(raw.mountName)
            if mount then f.mount, f.mountCollected = mount, raw.mountCollected end
        end
        if on("itemLevel") then
            local v = raw.itemLevel
            if v == ns.L["unknown"] then UnitInfo.RequestInspect(token) end
            f.itemLevel = v
            if type(v) == "number" then
                local r, g, b = ns.Colors.colorfunc.itemLevel(raw)
                f.itemLevelColor = ColorTable(r, g, b)
            end
        end
        if on("achievementPoints") then
            local v = raw.achievementPoints
            if v == ns.L["unknown"] then UnitInfo.RequestAchievements(token) end
            f.achievement = v
            if type(v) == "number" then
                local r, g, b = ns.Colors.colorfunc.achievement(raw)
                f.achievementColor = ColorTable(r, g, b)
            end
        end
        if on("mplusScore") and type(raw.mplusScoreNumber) == "number" and raw.mplusScoreNumber > 0 then
            local r, g, b = ns.Colors.colorfunc.mplus(raw)
            f.mplus, f.mplusBest, f.mplusColor = raw.mplusScoreNumber, raw.mplusBestText, ColorTable(r, g, b)
        end
        if on("zone") then f.zone = S.PlainText(raw.zone) end
    end
    if on("moveSpeed") and type(raw.moveSpeed) == "number" then f.speed = raw.moveSpeed end

    -- 顏色：名字、邊框
    if isPlayer then
        f.color = ClassColor(f.classFile) or { 1, 1, 1 }
    else
        local r, g, b = ns.Colors.UnitColor(token)
        f.color = ColorTable(ns.Colors.Readable(r, g, b)) or { 1, 1, 1 }
    end
    if f.tapped then f.color = { 0.6, 0.6, 0.6 } end
    local token2 = config.coloredBorder
    local cf = token2 and ns.Colors.colorfunc[token2]
    if cf then
        local r, g, b = cf(raw)
        f.border = ColorTable(r, g, b)
    elseif type(token2) == "string" and token2:match("^%x%x%x%x%x%x$") then
        f.border = { ns.Colors.FromHex(token2) }
    end
    if config.grayForDead and f.dead then
        f.gray = true
        f.color = { 0.6, 0.6, 0.6 }
        f.border = { 0.6, 0.6, 0.6 }
        if f.levelColor then f.levelColor = { 0.6, 0.6, 0.6 } end
    end

    -- 目標／被誰當目標
    if config.showTarget then f.target = Target(token) end
    if config.showTargetBy then f.targetedBy = TargetedBy(token) end
    return f
end

------------------------------------------------------------
-- 身分受限的單位：只叫受限時仍明文的 API（API 文件沒有秘密旗標、探針實測明文），名字原封不動帶著
-- （f.name 是秘密字串，只交給 SetText；f.restricted 讓 ViewUnit 走秘密的畫法）。生物類型不從 API 畫：
-- 暴雪自己的類型行（有的話）跟著 None 行原封不動畫出來，兩邊都畫會重複
-- 不走 UnitInfo.GetUnitInfo：那支會拿名字、伺服器、職業去查表／比對，餵秘密值不保證安全。
-- 元素開關的顯示條件（filterfunc）只讀 raw 的立場、伺服器、公會，這裡給一張只有明文欄位的 raw
------------------------------------------------------------
local function Plain(fn, ...)
    local v = S.SafeCall(fn, ...)
    if S.IsSecret(v) then return nil end
    return v
end

function Panel.UnitFactsRestricted(token, config)
    local level = S.PlainNumber(Plain(UnitLevel, token))
    local effective = S.PlainNumber(Plain(UnitEffectiveLevel, token)) or level
    local reaction = S.PlainNumber(Plain(UnitReaction, token, "player"))
    local classif = S.PlainText(Plain(UnitClassification, token))
    local raw = { unit = token, level = level, effectiveLevel = effective, reaction = reaction, classif = classif }
    local UnitInfo = ns.UnitInfo
    local showAll = UnitInfo.ModifierShowAll(config)
    local el = config.elements or {}
    local function on(key)
        local c = el[key]
        return c ~= nil and UnitInfo.CheckFilter(c, raw, showAll) and true or false
    end
    local isPlayer = S.SafeBool(UnitIsPlayer, token)
    local f = { restricted = true, isPlayer = isPlayer, showAll = showAll, classifPlain = classif }
    f.name = S.SafeCall(UnitName, token)
    if f.name == nil then return nil end
    if on("levelValue") and level then
        f.level = level
        f.levelColor = DifficultyColor(level == -1 and -1 or effective)
    end
    if not isPlayer then
        if level == -1 or classif == "worldboss" then
            if on("classifBoss") then f.classif = "boss" end
        elseif classif == "rareelite" then
            f.classif = on("classifRare") and (on("classifElite") and "rareelite" or "rare") or (on("classifElite") and "elite") or nil
        elseif classif == "rare" then
            if on("classifRare") then f.classif = "rare" end
        elseif classif == "elite" then
            if on("classifElite") then f.classif = "elite" end
        end
        if on("reactionName") and reaction then f.reactionName = S.PlainText(_G["FACTION_STANDING_LABEL" .. reaction]) end
        f.tapped = S.SafeBool(UnitIsTapDenied, token)
    end
    f.dead = S.SafeBool(UnitIsDeadOrGhost, token)

    -- 顏色：立場（UnitPlayerControlled／UnitCanAttack／UnitReaction 都是明文）；邊框照設定，職業色讀不到就是預設白
    local r, g, b = ns.Colors.UnitColor(token)
    f.color = ColorTable(ns.Colors.Readable(r, g, b)) or { 1, 1, 1 }
    if f.tapped then f.color = { 0.6, 0.6, 0.6 } end
    local token2 = config.coloredBorder
    local cf = token2 and ns.Colors.colorfunc[token2]
    if cf then
        f.border = ColorTable(cf(raw))
    elseif type(token2) == "string" and token2:match("^%x%x%x%x%x%x$") then
        f.border = { ns.Colors.FromHex(token2) }
    end
    if config.grayForDead and f.dead then
        f.gray = true
        f.color = { 0.6, 0.6, 0.6 }
        f.border = { 0.6, 0.6, 0.6 }
        if f.levelColor then f.levelColor = { 0.6, 0.6, 0.6 } end
    end
    -- 目標：存在與否是明文、名字秘密（Target 已經會交給 SetText）；被誰當目標要比單位 ⇒ 受限時一定是秘密，不畫
    if config.showTarget then f.target = Target(token) end
    return f
end

------------------------------------------------------------
-- 身分受限單位的行：文字與顏色是秘密，type／lineIndex 是明文（2026-10-21 探針）。
-- 文字原封不動帶著（row.secretText，只交給 SetText；row.left 留空字串給指紋用）；空行、分隔線不收。
-- 別人後加的行讀得到明文才收（讀到秘密只跳過那一行）
------------------------------------------------------------
local RESTRICTED_USE
local function RestrictedUse()
    if RESTRICTED_USE then return RESTRICTED_USE end
    RESTRICTED_USE = {}
    local function use(name, how) if LT[name] then RESTRICTED_USE[LT[name]] = how end end
    use("None", "none")
    use("QuestTitle", "questTitle")
    use("QuestObjective", "quest")
    use("QuestPlayer", "quest")
    use("UnitOwner", "other")
    use("UnitThreat", "other")
    use("UnitCriteriaProgress", "other")
    return RESTRICTED_USE
end

function Panel.CollectRestrictedLines(tip, data)
    if type(data) ~= "table" then return end
    local lines = data.lines
    if type(lines) ~= "table" or S.IsSecret(lines) then return end
    local okName, name = pcall(tip.GetName, tip)
    name = okName and S.PlainText(name)
    if not name then return end
    local use = RestrictedUse()
    local rows, covered = {}, {}
    for _, line in ipairs(lines) do
        if type(line) ~= "table" or S.IsSecret(line) then return end
        local lineType, index = line.type, line.lineIndex
        if S.IsSecret(lineType) or S.IsSecret(index) then return end
        if type(index) == "number" then covered[index] = true end
        local how = lineType ~= nil and use[lineType]
        if how then
            rows[#rows + 1] = { left = "", type = lineType, lineIndex = index, use = how, secretText = line.leftText }
        end
    end
    local n = Panel.CollectAppended(tip, name, covered, rows, true)
    if not n then return end
    return rows, n
end

-- rows（CollectRestrictedLines）→ model：第一個 None 行（等級行）丟掉、其餘 None 行進標題區（secretHeader），
-- 任務一段、其他（主人、仇恨、M+ 進度）一段，別人的行進附屬框
function Panel.ReadRestrictedUnitRows(rows, facts, hideHint)
    local w = Words()
    local model = { facts = facts, quests = {}, others = {}, extras = {}, skin = {},
        secretHeader = {}, secretQuests = {}, secretOthers = {} }
    local levelSeen = false
    for _, row in ipairs(rows) do
        if row.appended then
            local text = Strip(row.left)
            if (text ~= "" or (row.right and row.right ~= "")) and not (hideHint and w.hint and text == w.hint) then
                model.extras[#model.extras + 1] = row
            end
        elseif row.use == "none" then
            if levelSeen then
                model.secretHeader[#model.secretHeader + 1] = { value = row.secretText }
            else
                levelSeen = true          -- 等級行：面板的等級底板＋分類徽章已經畫了
            end
        elseif row.use == "questTitle" then
            model.secretQuests[#model.secretQuests + 1] = { value = row.secretText, title = true }
        elseif row.use == "quest" then
            model.secretQuests[#model.secretQuests + 1] = { value = row.secretText }
        elseif row.use == "other" then
            model.secretOthers[#model.secretOthers + 1] = { value = row.secretText }
        end
    end
    return model
end

------------------------------------------------------------
-- 設定視窗的 NPC 預覽：沒有能 SetUnit 的 NPC ⇒ 從假 raw（Options/Preview.lua）組 model，元素開關照樣生效
------------------------------------------------------------
function Panel.UnitPreviewModel(raw, config, icon)
    local UnitInfo = ns.UnitInfo
    local showAll = UnitInfo.ModifierShowAll(config)
    local el = config.elements or {}
    local function on(key)
        local c = el[key]
        return c ~= nil and UnitInfo.CheckFilter(c, raw, showAll) and true or false
    end
    local f = { isPlayer = false, name = raw.name, classifPlain = raw.classif }
    if on("levelValue") and type(raw.level) == "number" then
        f.level, f.levelColor = raw.level, DifficultyColor(raw.level)
    end
    if on("creature") then f.creature = raw.creature end
    if raw.classif == "elite" and on("classifElite") then f.classif = "elite" end
    if on("reactionName") then f.reactionName = raw.reactionName end
    local c = _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[raw.reaction or 4]
    f.color = c and { c.r, c.g, c.b } or { 1, 0.82, 0 }
    if config.showTarget then
        local name = S.PlainText((S.SafeCall(UnitName, "player")))
        local _, cls = S.SafeCall(UnitClass, "player")
        if name then f.target = { name = name, color = ClassColor(cls) } end
    end
    return { kind = "unit", facts = f, quests = {}, others = {}, extras = {}, skin = {}, icon = icon }
end

------------------------------------------------------------
-- reader（Try.lua 的 Render 叫）：token 是 TryUnit 存在 state 的明文 token
------------------------------------------------------------
Panel.readers.unit = function(tip, data, _, rows, n, state)
    if not state or not state.panelUnit or not rows then return end
    local token = state.panelUnit
    local isPlayer = S.SafeBool(UnitIsPlayer, token)
    local config = ns.db.unit[isPlayer and "player" or "npc"]
    local hideHint = ns.db.general and ns.db.general.hideUnitFrameHint
    local facts, model
    if state.panelRestricted then
        facts = Panel.UnitFactsRestricted(token, config)
        if not facts then return end
        model = Panel.ReadRestrictedUnitRows(rows, facts, hideHint)
    else
        facts = Panel.UnitFacts(token, config)
        if not facts then return end
        model = Panel.ReadUnitRows(rows, facts, hideHint)
    end
    model.kind, model.numLines, model.rows = "unit", n, rows
    model.unit, model.guid = token, state.panelGuid
    if not facts.npcTitleOn then model.npcTitle = nil end
    -- 邊框色：記在 state（同一個單位重建時 ClearTransient 會把邊色清回基底，Try 用這份補回）
    local b = facts.border
    if b and ns.Skin and ns.Skin.SetBorderColor then
        state.panelBorder = { b[1], b[2], b[3], 1 }
        ns.Skin.SetBorderColor(tip, b[1], b[2], b[3], 1)
    else
        state.panelBorder = nil
    end
    return model
end
