
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

    return function()
        i = i + 1
        if list[i] then list[i].reward = nil end
        while type(list[i]) == "table" and next(list[i]) == nil do
            table.remove(list, i)
        end
        local char = list[i]

        table.wipe(formatted)
        if not char then return  end

        local colored_nickname
        if char.classID then
            local _, classFile, _ = GetClassInfo(char.classID)
            local _, _, _, argbHex = GetClassColor(classFile)
            colored_nickname = "|c"..argbHex..char.name.."|r"
        else
            colored_nickname = char.name
        end
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
        formatted.mscore = char.mscore
        formatted.recordtable = char.recordtable
        return i, formatted
    end
end
