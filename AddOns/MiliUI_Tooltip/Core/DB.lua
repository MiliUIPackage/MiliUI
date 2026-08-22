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
            quickFocusModKey = "none",
            chatHover = true,
        },
        statusbar = {
            enable = true,
            height = 4,
            position = "bottom",           -- bottom | top
            texture = "solid",
            textFormat = "healthmaxpercent", -- none | percent | healthmax | healthmaxpercent
            fontSize = 10,
            color = "auto",                -- auto（職業/立場色）| custom
            customColor = Color(0, 0.9, 0.1, 1),
        },
        anchor = DefaultAnchor(false),
        unit = {
            player = {
                coloredBorder = "class",   -- default | class | level | reaction | selection | faction | HEX
                background = { colorfunc = "default", alpha = 0.9 },
                anchor = DefaultAnchor(true),
                showTarget = true,
                showTargetBy = true,
                showModel = true,
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
                    guildRealm  = { enable = true, color = "00cccc", wildcard = "%s",   filter = "none" },
                    levelValue  = { enable = true, color = "level",  wildcard = "%s",   filter = "none" },
                    itemLevel   = { enable = true, color = "itemLevel", wildcard = "%s", filter = "none", icon = false },
                    achievementPoints = { enable = true, color = "ffffff", wildcard = "%s", filter = "none", icon = false },
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
            modifierShowAll = false,
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
            modifierShowAll = false,
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
-- elements 的「列版面」（數字鍵的陣列）整組跟著預設走 v1 不開放編輯，
-- 直接覆蓋可以讓未來新增元素自動出現在正確的列上。
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

local function OverwriteElementRows(db)
    local defaults = BuildDefaults()
    for _, key in ipairs({ "player", "npc" }) do
        local saved = db.unit and db.unit[key] and db.unit[key].elements
        local def = defaults.unit[key].elements
        if saved then
            for i = #saved, 1, -1 do saved[i] = nil end
            for i, row in ipairs(def) do saved[i] = CopyTable(row) end
        end
    end
end

------------------------------------------------------------
-- 遷移鏈：版本閘（只跑一次）＋值閘（只動「還等於舊預設」的欄位，
-- 使用者自己調過的一個都不碰）。加條目時 Init.lua 的 DB_VERSION 一起 bump。
------------------------------------------------------------
local MIGRATIONS = {
    -- v2（2026-08-22）：預設縮放 1.2 → 1（實測 1.2 太大）
    [2] = function(db)
        if db.general.scale == 1.2 then db.general.scale = 1 end
    end,
}

function DB.Init()
    if type(MiliUI_Tooltip_DB) ~= "table" then
        MiliUI_Tooltip_DB = {}
    end
    local db = MiliUI_Tooltip_DB
    local isFresh = db.schemaVersion == nil
    MergeDefaults(db, BuildDefaults())
    OverwriteElementRows(db)

    -- 降版 clamp：拿新版 SV 回舊版不重跑遷移
    if type(db.schemaVersion) ~= "number" or db.schemaVersion > ns.DB_VERSION then
        db.schemaVersion = ns.DB_VERSION
    end
    if not isFresh then
        for v = db.schemaVersion + 1, ns.DB_VERSION do
            if MIGRATIONS[v] then MIGRATIONS[v](db) end
        end
    end
    db.schemaVersion = ns.DB_VERSION

    ns.db = db
    return db
end

function DB.ResetAll()
    MiliUI_Tooltip_DB = nil
    ReloadUI()
end
