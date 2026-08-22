------------------------------------------------------------
-- 滑鼠提示專屬的選單清單（共用層 Controls.lua 不放宿主資料）
------------------------------------------------------------
local _, ns = ...

local L = ns.WidgetsEnv.L

ns.Specs = {}
local Specs = ns.Specs

Specs.MOD_KEY_ITEMS = {
    { text = L["None"],  value = "none" },
    { text = "Alt",      value = "alt" },
    { text = "Ctrl",     value = "ctrl" },
    { text = "Shift",    value = "shift" },
}

Specs.ANCHOR_POSITION_ITEMS = {
    { text = L["Cursor right (default)"], value = "cursorRight" },
    { text = L["Follow cursor"],          value = "cursor" },
    { text = L["Fixed position"],         value = "static" },
    { text = L["Blizzard default"],       value = "default" },
}

Specs.STATIC_POINT_ITEMS = {
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
    { text = L["Bottom left"],  value = "BOTTOMLEFT" },
    { text = L["Top right"],    value = "TOPRIGHT" },
    { text = L["Top left"],     value = "TOPLEFT" },
    { text = L["Bottom"],       value = "BOTTOM" },
    { text = L["Center"],       value = "CENTER" },
}

Specs.FONT_FLAG_ITEMS = {
    { text = L["Default"],       value = "default" },
    { text = L["None"],          value = "NORMAL" },
    { text = L["Outline"],       value = "OUTLINE" },
    { text = L["Thick outline"], value = "THICKOUTLINE" },
}

Specs.BAR_POSITION_ITEMS = {
    { text = L["Bottom"], value = "bottom" },
    { text = L["Top"],    value = "top" },
}

Specs.BAR_FORMAT_ITEMS = {
    { text = L["Current / max (percent)"], value = "healthmaxpercent" },
    { text = L["Current / max"],           value = "healthmax" },
    { text = L["Percent only"],            value = "percent" },
    { text = L["No text"],                 value = "none" },
}

Specs.BAR_COLOR_ITEMS = {
    { text = L["Auto (class / reaction)"], value = "auto" },
    { text = L["Custom color"],            value = "custom" },
}

-- 邊框 / 背景著色方式（單位）
Specs.BORDER_COLOR_ITEMS = {
    { text = L["Global border color"], value = "default" },
    { text = L["Class color"],     value = "class" },
    { text = L["Reaction color"],  value = "reaction" },
    { text = L["Level color"],     value = "level" },
    { text = L["Selection color"], value = "selection" },
    { text = L["Faction color"],   value = "faction" },
}

Specs.BG_COLOR_ITEMS = {
    { text = L["Global background color"], value = "default" },
    { text = L["Class color"],     value = "class" },
    { text = L["Reaction color"],  value = "reaction" },
    { text = L["Level color"],     value = "level" },
    { text = L["Selection color"], value = "selection" },
    { text = L["Faction color"],   value = "faction" },
}

-- 元素顯示名（單位分頁的 toggle 標籤）
Specs.ELEMENT_LABELS = {
    raidIcon = L["Raid target icon"],
    roleIcon = L["Role icon"],
    pvpIcon = L["PvP icon"],
    factionIcon = L["Faction icon"],
    factionBig = L["Big faction watermark"],
    classIcon = L["Class icon"],
    friendIcon = L["Friend icon"],
    questIcon = L["Quest boss icon"],
    title = L["Title"],
    name = L["Name"],
    realm = L["Realm"],
    statusAFK = L["AFK status"],
    statusDND = L["DND status"],
    statusDC = L["Offline status"],
    guildName = L["Guild name"],
    guildIndex = L["Guild index"],
    guildRank = L["Guild rank"],
    guildRealm = L["Guild realm"],
    levelValue = L["Level"],
    itemLevel = L["Item level"],
    achievementPoints = L["Achievement points"],
    factionName = L["Faction name"],
    gender = L["Gender"],
    raceName = L["Race"],
    className = L["Class"],
    isPlayer = L["\"Player\" tag"],
    role = L["Role text"],
    moveSpeed = L["Move speed"],
    mplusScore = L["Mythic+ score"],
    zone = L["Zone (party members)"],
    mount = L["Mount"],
    npcTitle = L["NPC title"],
    classifBoss = L["Boss tag"],
    classifElite = L["Elite tag"],
    classifRare = L["Rare tag"],
    creature = L["Creature type"],
    reactionName = L["Reaction text"],
}

-- 元素的列排序改由玩家在「顯示元素」看板拖曳（Tab_Unit.lua），
-- 順序資料就是 DB elements 的數字鍵陣列，這裡不再維護靜態清單。
