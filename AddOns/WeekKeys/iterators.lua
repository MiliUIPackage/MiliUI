
WeekKeys.Iterators = {}
local Iterators = WeekKeys.Iterators

--- Return iterator to 'for ... in' loop
---@param list table with player data
---@param writeRealm boolean write (*) or not
---@return function iterator loop iterator
function Iterators.FormatPlayerList(list,writeRealm)

    if #list == 0 then return function() end end

    local _, realm = UnitFullName("player")
    realm = realm or GetRealmName() or ""
    realm = realm:gsub(" ","")
    local formatted = {}
    local i = 0
    ---'for ... in' iterator
    ---@return table formatted table with formatted data
    return function()
        i = i + 1
        local char = list[i]
        table.wipe(formatted)
        if not char then return end

        local _, classFile, _ = GetClassInfo(char.classID)
        local _, _, _, argbHex = GetClassColor(classFile)
        local colored_nickname = "|c"..argbHex..char.name.."|r"
        if writeRealm and char.realm ~= realm then
            colored_nickname = colored_nickname .. " (*)"
        end

        local keystone = ""
        if char.keyID then
            keystone = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)
            -- add icon if instance have covenant bonuss
            if char.keyID == 375 or char.keyID == 377 then
                keystone = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. keystone
            elseif char.keyID == 376 or char.keyID == 381 then
                keystone = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. keystone
            elseif char.keyID == 378 or char.keyID == 380 then
                keystone =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. keystone
            elseif char.keyID == 379 or char.keyID == 382 then
                keystone =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. keystone
            end
        end
        formatted.colored = colored_nickname
        formatted.realm = char.realm
        formatted.ilvl = char.ilvl
        formatted.record = char.record
        formatted.keystone = keystone
        formatted.faction = char.faction
        formatted.covenant = char.covenant
        formatted.reward = char.reward
        return i, formatted
    end
end


--- 'for' loop iterator loops LootList
---@return function iterator loop iterator
function Iterators.LootList()
    if #LootFinder.loot_list == 0 then return function() end end
    local index = 0
    --- iterator
    ---@return integer index position in LootList table
    ---@return string source instance/raid
    ---@return string name dungeon name
    ---@return string boss boss name
    ---@return string itemlink modified itemlink
    ---@return integer icon  items iconID
    ---@return integer mainatr str/agi/int value
    ---@return integer crit crit value
    ---@return integer haste haste value
    ---@return integer mastery mastery value
    ---@return integer versality versality value
    return function()
        index = index + 1
        local tbl = LootFinder.loot_list[index]
        if not tbl then return end
        --index, name, boss, itemlink, icon, mainstat, crit, haste, mastery, versality
        return index, tbl.source, tbl.name, tbl.boss, tbl.itemlink, tbl.icon, tbl.mainstat, tbl.crit, tbl.haste, tbl.mastery, tbl.versality
    end
end
