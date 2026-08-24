------------------------------------------------------------
-- 設定資料：預設值、nil-merge、遷移
--
-- 預設值 = 套組現行 TinyTooltip 的樣式（1px 直角深色框、cursorRight、底部細血條、
-- 玩家職業色邊框、NPC 立場色邊框、elements 版面照舊）。
--
-- ⚠ MergeDefaults 只補 nil：發佈後要改任何預設值，都得配一條遷移
--   （版本閘＋值閘，見 MiliUI_UnitFrames 的教訓）。發佈前可以直接改。
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

local function DefaultAnchor(inherit)
    return {
        position = inherit and "inherit" or "cursorRight",
        hiddenInCombat = false,
        modifierShowInCombatKey = inherit and "global" or "none",
        returnInCombat = false,
        returnOnUnitFrame = false,
        x = -30, y = 30, p = "BOTTOMRIGHT",   -- static 模式用（螢幕右下）
    }
end

local function BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,
        optionsWindow = { x = 0, y = 0 },
        general = {
            scale = 1,
            mask = false,
            bgfile = "solid",
            background = Color(0.133, 0.133, 0.133, 1),
            borderSize = 1,
            borderColor = Color(0.18, 0.18, 0.18, 1),
            headerFont = "default", headerFontSize = 0, headerFontFlag = "default",
            bodyFont = "default", bodyFontSize = 0, bodyFontFlag = "default",
            hideUnitFrameHint = true,
            chatHover = true,
        },
        statusbar = {
            enable = true,
            hideInCombat = false,  -- 戰鬥中照樣顯示（值畫得出來——C 端呈現；想清爽再自己開）
            height = 4,
            position = "bottom",           -- bottom | top
            texture = "tuktex",
            textFormat = "healthmaxpercent", -- none | percent | healthmax | healthmaxpercent
            fontSize = 10,
            color = "auto",                -- auto（職業/立場色）| custom
            customColor = Color(0, 0.9, 0.1, 1),
        },
        anchor = DefaultAnchor(false),
        unit = {
            player = {
                -- 預設職業色（使用者 2026-08-22 定案）。⚠ class 在 12.1 對 mouseover
                -- 是秘密值路徑（預覽的 player token 是明文），秘密分量走 C_ClassColor →
                -- SetVertexColor，拿不到時退白，兩邊可能不完全一致
                coloredBorder = "class",   -- default | class | level | reaction | selection | faction
                background = { colorfunc = "default", alpha = 0.9 },
                anchor = DefaultAnchor(true),
                showTarget = true,
                showTargetBy = true,
                showModel = false,
                grayForDead = false,
                elements = {
                    raidIcon    = { enable = true, filter = "none" },
                    roleIcon    = { enable = true, filter = "none" },
                    pvpIcon     = { enable = true, filter = "none" },
                    factionIcon = { enable = true, filter = "none" },
                    factionBig  = { enable = false, filter = "none" },
                    classIcon   = { enable = true, filter = "none" },
                    friendIcon  = { enable = true, filter = "none" },
                    title       = { enable = true, color = "ccffff", wildcard = "%s",   filter = "none" },
                    name        = { enable = true, color = "class",  wildcard = "%s",   filter = "none" },
                    realm       = { enable = true, color = "00eeee", wildcard = "%s",   filter = "none" },
                    statusAFK   = { enable = true, color = "ffd200", wildcard = "(%s)", filter = "none" },
                    statusDND   = { enable = true, color = "ffd200", wildcard = "(%s)", filter = "none" },
                    statusDC    = { enable = true, color = "999999", wildcard = "(%s)", filter = "none" },
                    guildName   = { enable = true, color = "ff00ff", wildcard = "<%s>", filter = "none" },
                    guildIndex  = { enable = true, color = "cc88ff", wildcard = "%s",   filter = "none" },
                    guildRank   = { enable = true, color = "cc88ff", wildcard = "(%s)", filter = "none" },
                    guildRealm  = { enable = false, color = "00cccc", wildcard = "%s",  filter = "none" },
                    levelValue  = { enable = true, color = "level",  wildcard = "%s",   filter = "none" },
                    itemLevel   = { enable = true, color = "itemLevel", wildcard = "%s", filter = "none", icon = false },
                    achievementPoints = { enable = true, color = "achievement", wildcard = "%s", filter = "none", icon = false },
                    factionName = { enable = true, color = "faction", wildcard = "%s",  filter = "none" },
                    gender      = { enable = false, color = "999999", wildcard = "%s",  filter = "none" },
                    raceName    = { enable = true, color = "cccccc", wildcard = "%s",   filter = "none" },
                    className   = { enable = true, color = "class",  wildcard = "%s",   filter = "none", icon = false },
                    isPlayer    = { enable = false, color = "ffffff", wildcard = "(%s)", filter = "none" },
                    role        = { enable = false, color = "ffffff", wildcard = "(%s)", filter = "none" },
                    moveSpeed   = { enable = false, color = "e8e7a8", wildcard = "%d%%", filter = "none" },
                    mplusScore  = { enable = true,  color = "mplus",  wildcard = "%s",   filter = "none", icon = false },
                    zone        = { enable = false, color = "ffffff", wildcard = "%s",   filter = "none" },
                    mount       = { enable = true,  color = "ffffff", wildcard = "%s",   filter = "none", icon = false },
                    { "friendIcon", "raidIcon", "roleIcon", "pvpIcon", "factionIcon", "classIcon", "title", "name", "realm", "statusAFK", "statusDND", "statusDC" },
                    { "guildName", "guildIndex", "guildRank", "guildRealm" },
                    { "levelValue", "factionName", "gender", "raceName", "className", "isPlayer", "role", "moveSpeed" },
                    { "mount" },
                    { "mplusScore" },
                    { "itemLevel" },
                    { "achievementPoints" },
                    { "zone" },
                },
            },
            npc = {
                coloredBorder = "reaction",
                background = { colorfunc = "default", alpha = 1 },
                anchor = DefaultAnchor(true),
                showTarget = true,
                showTargetBy = true,
                showModel = false,
                grayForDead = true,
                elements = {
                    factionBig   = { enable = false, filter = "none" },
                    raidIcon     = { enable = true,  filter = "none" },
                    classIcon    = { enable = false, filter = "none" },
                    questIcon    = { enable = true,  filter = "none" },
                    name         = { enable = true, color = "default", wildcard = "%s",   filter = "none" },
                    npcTitle     = { enable = true, color = "99e8e8", wildcard = "<%s>",  filter = "none" },
                    levelValue   = { enable = true, color = "level",  wildcard = "%s",    filter = "none" },
                    classifBoss  = { enable = true, color = "ff0000", wildcard = "(%s)",  filter = "none" },
                    classifElite = { enable = true, color = "ffff33", wildcard = "(%s)",  filter = "none" },
                    classifRare  = { enable = true, color = "ffaaff", wildcard = "(%s)",  filter = "none" },
                    creature     = { enable = true, color = "selection", wildcard = "%s", filter = "none" },
                    reactionName = { enable = true, color = "33ffff", wildcard = "<%s>",  filter = "reaction6" },
                    moveSpeed    = { enable = false, color = "e8e7a8", wildcard = "%d%%", filter = "none" },
                    { "raidIcon", "classIcon", "questIcon", "name" },
                    { "levelValue", "classifBoss", "classifElite", "classifRare", "creature", "reactionName", "moveSpeed" },
                },
            },
        },
        item = {
            modifierShowAll = true,
            coloredItemBorder = true,
            showItemIcon = true,
            showItemId = false,
            showItemBonusId = false,
            showItemEnhancementId = false,
            showItemGemId = false,
            showItemMaxStack = true,
            showItemIconId = false,
            showItemExpansion = true,
        },
        spell = {
            modifierShowAll = true,
            showIcon = true,
            showSpellId = false,
            showSpellIconId = false,
            showMountSource = true,
        },
        quest = {
            coloredQuestBorder = true,
            showQuestId = true,
        },
    }
end
DB.BuildDefaults = BuildDefaults

-- nil-merge：只補缺的鍵，不動玩家已有的值。
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = CopyTable(v)
            else
                MergeDefaults(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- 列版面（elements 的數字鍵陣列）存 SV，玩家可在設定頁拖曳排序。
-- 這裡只做健檢：清掉重複與未知 key、把「預設版面有、SV 列裡沒有」的元素
-- （通常是新版本加的）補進對應的列，最後清掉空列。
local function EnsureElementRows(db)
    local defaults = BuildDefaults()
    for _, kind in ipairs({ "player", "npc" }) do
        local elements = db.unit and db.unit[kind] and db.unit[kind].elements
        local def = defaults.unit[kind].elements
        if elements then
            local seen = {}
            for r = #elements, 1, -1 do
                local row = elements[r]
                if type(row) ~= "table" then
                    tremove(elements, r)
                else
                    for i = #row, 1, -1 do
                        local key = row[i]
                        if type(key) ~= "string" or seen[key] or type(elements[key]) ~= "table" then
                            tremove(row, i)
                        else
                            seen[key] = true
                        end
                    end
                end
            end
            for ri, drow in ipairs(def) do
                for _, key in ipairs(drow) do
                    if not seen[key] and type(elements[key]) == "table" then
                        local target = elements[math.min(ri, #elements + 1)]
                        if not target then
                            target = {}
                            elements[#elements + 1] = target
                        end
                        tinsert(target, key)
                        seen[key] = true
                    end
                end
            end
            for r = #elements, 1, -1 do
                if #elements[r] == 0 then tremove(elements, r) end
            end
        end
    end
end

------------------------------------------------------------
-- 設定檔
--
-- SV 結構：
--   MiliUI_Tooltip_DB = {
--       schemaVersion, optionsWindow, charClasses,          -- 帳號層，不跟設定檔走
--       profiles    = { ["Default"] = { general=, statusbar=, unit=, ... } },
--       profileKeys = { ["米利 - 世界之樹"] = "Default" },     -- 每角色指標
--   }
--
-- ns.db **就是那份設定檔本身**，不是另外組一張扁平表。這樣 ns.db.general 之類的
-- 既有讀取點全部不用改，而且純量寫入（ns.db.foo = 1）也真的會落進 SV。
-- 帳號層的東西改走 DB.Account()，目前只有 Options/Panel.lua 的視窗位置用到。
--
-- 換設定檔一律 ReloadUI：Skin／Fonts／Bar／Options 的 refresher 全都抓著舊表的
-- 參照，就地換指標要逐一補正，而換設定檔是罕見的刻意操作——重載最乾淨，
-- 也跟既有的「匯入並重載」一致。
------------------------------------------------------------
-- ⚠ 這是存進 SV 的 key，**不要翻譯**：翻了之後換客戶端語系就對不上，
-- 使用者會看到一份空白設定。顯示名稱由 Options 那邊翻（共用／角色專屬／自訂）。
DB.DEFAULT_PROFILE = "Default"

-- 「角色專屬」用保留前綴而不是另開一張表：這樣切換／刪除／匯出匯入全部共用
-- 同一套邏輯，不用到處寫特例。
local CHAR_PREFIX = "char:"

-- 一份設定檔裝哪些區塊。沒列到的頂層鍵就是帳號層的（optionsWindow、charClasses…）。
-- ⚠ 加新區塊時這裡要一起加，不然它會變成帳號層、切設定檔時不跟著換。
local PROFILE_KEYS = { "general", "statusbar", "anchor", "unit", "item", "spell", "quest" }

-- 一份全新設定檔。每次呼叫都是新表（BuildDefaults 自己就重建），
-- 所以拿去塞進 profiles 不會跟別份共用子表。
local function ProfileDefaults()
    local d = BuildDefaults()
    local out = {}
    for _, k in ipairs(PROFILE_KEYS) do out[k] = d[k] end
    return out
end
DB.ProfileDefaults = ProfileDefaults

-- 帳號層（SV 根）。設定視窗位置、角色職業表這類「不該跟著設定檔跑」的東西住這裡。
function DB.Account()
    return MiliUI_Tooltip_DB
end

local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end
DB.CharKey = CharKey

function DB.CharProfileKey()
    return CHAR_PREFIX .. CharKey()
end

function DB.IsCharProfile(name)
    return type(name) == "string" and name:sub(1, #CHAR_PREFIX) == CHAR_PREFIX
end

-- "char:米利 - 世界之樹" → "米利 - 世界之樹"（顯示層要用）
function DB.CharProfileOwner(name)
    if not DB.IsCharProfile(name) then return nil end
    return name:sub(#CHAR_PREFIX + 1)
end

-- 那隻角色的職業（沒登入過就查不到，回 nil）
function DB.CharClass(charKey)
    local db = MiliUI_Tooltip_DB
    return db and db.charClasses and db.charClasses[charKey]
end

-- 深拷貝：兩份設定檔絕不能共用同一張子表
local function DeepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and DeepCopy(v) or v end
    return o
end

-- 全部列出來，包含**別隻角色**的角色專屬——刻意的：想直接切去用別隻角色調好的
-- 版面，或從他那份複製一份出來，都靠這個。
function DB.ListProfiles()
    local out = {}
    for name in pairs(MiliUI_Tooltip_DB.profiles or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

------------------------------------------------------------
-- 遷移
------------------------------------------------------------
-- 帳號層：設定區塊原本住在 SV 最上層，具名設定檔上線後要搬進「共用」那份。
-- 判準用**結構**而不是版本號：這支的 schemaVersion 還只是佔位，而真正要問的
-- 問題就是「有沒有 profiles」。搬完把頂層那幾個鍵清掉，不留兩份會漂掉的資料。
local function MigrateAccount(db)
    if db.profiles then return end
    local moved
    for _, k in ipairs(PROFILE_KEYS) do
        if db[k] ~= nil then
            moved = moved or {}
            moved[k] = db[k]
            db[k] = nil
        end
    end
    if moved then
        db.profiles = { [DB.DEFAULT_PROFILE] = moved }
    end
end

-- 設定檔層：[版本號] = 把一份設定檔補到那個版本要做的事。
-- 目前是空的（還沒發佈過需要遷移的預設值變更）。發佈之後改任何預設值都要在這裡
-- 加一條並 bump ns.DB_VERSION——通則是「只動還等於舊預設值的欄位」（值閘），
-- 使用者調過的不碰。
--
-- 為什麼跟帳號層拆開：**匯入字串**帶著自己的 schemaVersion，可能比目前舊。那一份
-- 要補遷移，但不能把帳號層的版本號降下去——降了會讓遷移在所有設定檔上重跑一次。
local PROFILE_MIGRATIONS = {}

function DB.MigrateProfile(profile, fromVersion)
    if type(profile) ~= "table" then return end
    local from = tonumber(fromVersion) or 1
    for v = from + 1, ns.DB_VERSION do
        local step = PROFILE_MIGRATIONS[v]
        if step then pcall(step, profile) end
    end
end

------------------------------------------------------------
-- 啟用一份設定檔
--
-- 補齊預設值 → 指給 ns.db → 記下名字。登入與換設定檔走同一支，兩條路不會漂掉。
--
-- ⚠ MergeDefaults 一定要在這裡跑，不能只在登入時對「目前這一份」跑：別份設定檔
-- 可能是在某個鍵加進 BuildDefaults **之前**建立的，直接切過去會缺鍵。
------------------------------------------------------------
function DB.Activate(name)
    local db = MiliUI_Tooltip_DB
    local p = db.profiles and db.profiles[name]
    if not p then return nil end
    MergeDefaults(p, ProfileDefaults())
    EnsureElementRows(p)
    ns.db = p
    ns.profileName = name
    return p
end

function DB.Init()
    if type(MiliUI_Tooltip_DB) ~= "table" then
        MiliUI_Tooltip_DB = {}
    end
    local db = MiliUI_Tooltip_DB
    MigrateAccount(db)
    -- 尚未發佈、沒有遷移鏈；schemaVersion 先佔位，發佈後改預設值要配遷移
    db.schemaVersion = ns.DB_VERSION

    -- 帳號層預設值（設定視窗位置）
    MergeDefaults(db, { optionsWindow = BuildDefaults().optionsWindow })

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}
    -- 角色 → 職業。設定檔清單要用職業色顯示「角色-伺服器」，而別隻角色的職業
    -- 沒有 API 可查，只能靠每隻角色登入時自己記一筆。
    -- ⚠ 存在帳號層而不是設定檔裡：設定檔會被深拷貝／重新灌種子，放進去會被帶錯。
    db.charClasses = db.charClasses or {}
    db.charClasses[CharKey()] = ns.playerClass

    local key = CharKey()
    local name = db.profileKeys[key]
    if type(name) ~= "string" or not db.profiles[name] then
        name = DB.DEFAULT_PROFILE
        db.profileKeys[key] = name
    end
    db.profiles[name] = db.profiles[name] or {}
    return DB.Activate(name)
end

------------------------------------------------------------
-- 三種設定檔
--   共用      key = "Default"，所有角色的預設，不給刪
--   角色專屬  key = "char:<角色> - <伺服器>"，第一次選才建立，來源由彈窗問
--   自訂      使用者自己命名的
------------------------------------------------------------
-- 寫入角色專屬那份。seed 只接受這三種，**沒有預設值**——來源一律由使用者在切換前
-- 的選擇彈窗指定（見 Options/Tab_Share.lua），這裡不替他猜。
--   "current"  目前正在用的那份（眼前看到的樣子）
--   "shared"   共用那份
--   "fresh"    全新預設值
-- ⚠ 會覆蓋既有內容，呼叫端必須先問過。
function DB.SeedCharProfile(seed)
    local db = MiliUI_Tooltip_DB
    local key = DB.CharProfileKey()
    if seed == "fresh" then
        db.profiles[key] = ProfileDefaults()
        return key
    end
    local src
    if seed == "shared" then
        src = db.profiles[DB.DEFAULT_PROFILE]
    elseif seed == "current" then
        src = db.profiles[ns.profileName]
    end
    if not src then return nil end
    db.profiles[key] = DeepCopy(src)
    return key
end

-- copyFrom = nil 代表從預設值建立
function DB.CreateProfile(name, copyFrom)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false, "empty" end
    if DB.IsCharProfile(name) then return false, "reserved" end   -- char: 是保留前綴
    local db = MiliUI_Tooltip_DB
    if db.profiles[name] then return false, "exists" end
    if copyFrom then
        local src = db.profiles[copyFrom]
        if not src then return false, "nosource" end
        db.profiles[name] = DeepCopy(src)
    else
        db.profiles[name] = ProfileDefaults()
    end
    return true
end

-- 刪掉指定那份，指著它的角色改回共用。共用本身不給刪。
function DB.DeleteProfile(name)
    local db = MiliUI_Tooltip_DB
    if name == DB.DEFAULT_PROFILE or not db.profiles[name] then return false end
    db.profiles[name] = nil
    -- 指著它的角色全部改回共用，不然下次登入會看到一份空白設定
    for k, v in pairs(db.profileKeys) do
        if v == name then db.profileKeys[k] = DB.DEFAULT_PROFILE end
    end
    return true
end

-- 換設定檔：寫下指標再重載。
-- ⚠ profileKeys 一定要在 ReloadUI **之前**寫，重載之後就是靠它認得回來。
function DB.SwitchProfile(name)
    local db = MiliUI_Tooltip_DB
    if not (db.profiles and db.profiles[name]) then return false end
    db.profileKeys[CharKey()] = name
    if name == ns.profileName then return true end
    ReloadUI()
    return true
end

------------------------------------------------------------
-- 恢復預設
------------------------------------------------------------
-- 目前這份設定檔全部恢復預設後重載。
-- ⚠ 只動這一份，其他設定檔與帳號層（設定視窗位置）不碰——有設定檔系統之後，
-- 「重置」把整個帳號炸掉太超過了。想從零開始就切到一份新的設定檔。
function DB.ResetAll()
    local db = MiliUI_Tooltip_DB
    local name = db and db.profileKeys and db.profileKeys[CharKey()]
    if db and name and db.profiles then
        db.profiles[name] = ProfileDefaults()
    end
    ReloadUI()
end
