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
            hideInCombat = true,   -- 戰鬥中收起（值其實畫得出來——C 端呈現，純粹清爽）
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
                    guildRealm  = { enable = true, color = "00cccc", wildcard = "%s",   filter = "none" },
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

function DB.Init()
    if type(MiliUI_Tooltip_DB) ~= "table" then
        MiliUI_Tooltip_DB = {}
    end
    local db = MiliUI_Tooltip_DB
    MergeDefaults(db, BuildDefaults())
    EnsureElementRows(db)
    -- 尚未發佈、沒有遷移鏈；schemaVersion 先佔位，發佈後改預設值要配遷移
    db.schemaVersion = ns.DB_VERSION
    ns.db = db
    return db
end

function DB.ResetAll()
    MiliUI_Tooltip_DB = nil
    ReloadUI()
end
