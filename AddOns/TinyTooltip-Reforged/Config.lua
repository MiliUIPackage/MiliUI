
local addon = TinyTooltipReforged
 
addon.db = {
    version = 3.3,
    general = {
        scale             = 1.2,                    --縮放
        mask              = false,                  --頂部遮罩層
        bgfile            = "Solid",                --背景
        background        = {0.133, 0.133, 0.133, 1},  --背景顔色和透明度
        borderSize        = 1,                      --邊框大小（直角邊框才生效）
        borderCorner      = "angular",              --邊框類型 default|angular:直角邊框
        borderColor       = {0.18, 0.18, 0.18, 1},  --邊框顔色和透明度
        statusbarHeight   = 4,                      --HP高度
        statusbarPosition = "bottom",               --HP位置 default|bottom|top
        statusbarOffsetX  = 0,                      --HP X偏移 0:自動
        statusbarOffsetY  = 0,                      --HP Y偏移 0:自動
	    statusbarFont	  = "default",
        statusbarFontSize = 10,                     --HP文字大小
        statusbarFontFlag = "THINOUTLINE",          --HP文字樣式
        statusbarText     = true,                   --HP文字
        statusbarColor    = "auto",                 --HP顔色 default|auto|smooth
        statusbarTexture  = "Interface\\AddOns\\TinyTooltip-Reforged\\texture\\StatusBar",
	    statusbarTextFormat = "healthmaxpercent",
        anchor            = { position = "cursorRight", hiddenInCombat = false, returnInCombat = false, returnOnUnitFrame = false, cp = "BOTTOM", p = "BOTTOMRIGHT", y = 240, x = -5, }, --鼠標位置 default|cursor|static|cursorRight
        alwaysShowIdInfo  = false,
        skinMoreFrames    = true,
        headerFont        = "default",
        headerFontSize    = "default",
        headerFontFlag    = "default",
        bodyFont          = "default",
        bodyFontSize      = "default",
        bodyFontFlag      = "default",
        SavedVariablesPerCharacter = false,
     },
    unit = {
        player = {
            coloredBorder = "class",
            background = { colorfunc = "default", alpha = 0.9, },
            anchor = { position = "inherit", hiddenInCombat = false, defaultInCombat = false, defaultOnUnitFrame = false, cp = "BOTTOM", p = "BOTTOMRIGHT", },
            showTarget = true, 
	        showSpec = true,
            showTargetBy = true,
            showModel = true,  
            grayForDead = false, 
	        showIlevelAndSpecialization = false,
            elements = {
                raidIcon    = { enable = true, filter = "none" },
                roleIcon    = { enable = true, filter = "none" },
                pvpIcon     = { enable = true, filter = "none" },
                factionIcon = { enable = true, filter = "none" },
                factionBig  = { enable = true, filter = "none" },
                classIcon   = { enable = true, filter = "none" },
                friendIcon  = { enable = true, filter = "none" },
                title       = { enable = true, color = "ccffff", wildcard = "%s",   filter = "none" },
                name        = { enable = true, color = "class",  wildcard = "%s",   filter = "none" },
                realm       = { enable = true, color = "00eeee", wildcard = "%s",   filter = "none" },
                statusAFK   = { enable = true, color = "ffd200", wildcard = "(%s)", filter = "none" },
                statusDND   = { enable = true, color = "ffd200", wildcard = "(%s)", filter = "none" },
                statusDC    = { enable = true, color = "999999", wildcard = "(%s)", filter = "none" },
                guildName   = { enable = true, color = "ff00ff", wildcard = "<%s>", filter = "none" },
                guildIndex  = { enable = true, color = "cc88ff", wildcard = "%s",  filter = "none" },
                guildRank   = { enable = true, color = "cc88ff", wildcard = "(%s)", filter = "none" },
                guildRealm  = { enable = false, color = "00cccc", wildcard = "%s",   filter = "none" },
                levelValue  = { enable = true, color = "level",   wildcard = "%s",  filter = "none" }, 
                factionName = { enable = true, color = "faction", wildcard = "%s",  filter = "none" }, 
                gender      = { enable = false, color = "999999",  wildcard = "%s", filter = "none" }, 
                raceName    = { enable = true, color = "cccccc",  wildcard = "%s",  filter = "none" }, 
                className   = { enable = true, color = "ffffff",  wildcard = "%s",  filter = "none" }, 
                isPlayer    = { enable = false, color = "ffffff",  wildcard = "(%s)", filter = "none" }, 
                role        = { enable = false, color = "ffffff",  wildcard = "(%s)", filter = "none" },
                moveSpeed   = { enable = false, color = "e8e7a8",  wildcard = "%d%%", filter = "none" },
                zone        = { enable = true,  color = "ffffff",  wildcard = "%s", filter = "none" },
                { "raidIcon", "roleIcon", "pvpIcon", "factionIcon", "classIcon", "title", "name", "realm", "statusAFK", "statusDND", "statusDC", },
                { "guildName", "guildIndex", "guildRank", "guildRealm", },
                { "levelValue", "factionName", "gender", "raceName", "className", "isPlayer", "role", "moveSpeed", },
                { "zone" },
            },
        },
        npc = {
            coloredBorder = "reaction",
            background = { colorfunc = "default", alpha = 1, },
            showTarget = true,
            showTargetBy = true,
            grayForDead = false,
            showModel = false,
            anchor = { position = "inherit", hiddenInCombat = false, defaultInCombat = false, defaultOnUnitFrame = false, cp = "BOTTOM", p = "BOTTOMRIGHT", },
            elements = {
                factionBig   = { enable = false, filter = "none" },
                raidIcon     = { enable = true,  filter = "none" },
                classIcon    = { enable = false, filter = "none" },
                questIcon    = { enable = true,  filter = "none" },
                name         = { enable = true, color = "default",wildcard = "%s",    filter = "none" },
                npcTitle     = { enable = true, color = "99e8e8", wildcard = "<%s>",  filter = "none" },
                levelValue   = { enable = true, color = "level",  wildcard = "%s",    filter = "none" }, 
                classifBoss  = { enable = true, color = "ff0000", wildcard = "(%s)",  filter = "none" },
                classifElite = { enable = true, color = "ffff33", wildcard = "(%s)",  filter = "none" }, 
                classifRare  = { enable = true, color = "ffaaff", wildcard = "(%s)",  filter = "none" }, 
                creature     = { enable = true, color = "selection", wildcard = "%s", filter = "none" },
                reactionName = { enable = true, color = "33ffff", wildcard = "<%s>",  filter = "reaction6" },
                moveSpeed    = { enable = false, color = "e8e7a8",  wildcard = "%d%%", filter = "none" },
                { "raidIcon", "classIcon", "questIcon", "name", },
                { "levelValue", "classifBoss", "classifElite", "classifRare", "creature", "reactionName", "moveSpeed", },
            },
        },
    },
    item = {
        coloredItemBorder = true,
        showItemIcon = true,    
    },
    spell = {
        borderColor = {0.133, 0.133, 0.133, 1},
        background = {0.133, 0.133, 0.133, 1},
        showIcon = true,
    },
    quest = {
        coloredQuestBorder = true, 
    },
    variables = {},
}