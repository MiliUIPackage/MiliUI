local pvp_gear_list = {
    185125,
    185314,
    185202,
    185316,
    185199,
    185200,
    185315,
    185312,
    185301,
    185201,
    185317,
    185300,
    185203,
    185126,
    185177,
    185258,
    185186,
    185267,
    185165,
    185246,
    185193,
    185274,
    185175,
    185256,
    185189,
    185270,
    185181,
    185262,
    185170,
    185251,
    185198,
    185279,
    185283,
    185164,
    185245,
    185280,
    185313,
    185192,
    185273,
    185281,
    185304,
    185306,
    185305,
    185197,
    185278,
    185282
}
--[[
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local name = GetMerchantItemInfo(i)
        local itemType, itemSubType, _, _, iconID, _, classID, subclassID = select(6, GetItemInfo(link))
        testDB[#testDB + 1] = {
            itemlink = link,
            name = name,
            itemType = itemType,
            itemSubType = itemSubType,
            iconID = iconID,
            classID = classID,
            subclassID = subclassID
        }
    end
--]]

local pvprank = {
    6628, -- unranked
    6627, -- Combatant
    6626, -- Challenger
    6625, -- Rival
    6623, -- Duelist
    6624  -- Elite
}

local rating = {
    "0-1399",
    "1400-1599",
    "1600-1799",
    "1800-2099",
    "2100+",
}

local pvpilvl = {
    220,  -- unranked
    226,  -- Combatant
    233,  -- Challenger
    240,  -- Rival
    246,  -- Duelist
}

function LF:PvPSearch()
    if self:IsBlacklisted("pvp") then return end
    for _, id in ipairs(pvp_gear_list) do

        local itemlink = select(2, GetItemInfo(id))
        local pvprating = rating[self.pvptier]
        local ilvl = pvpilvl[self.pvptier]
        local rank = pvprank[self.pvptier]

        if itemlink then
            itemlink = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. rank ..":"..(1272 + ilvl) .. ":6646:1:28:807:::")
        end

        if self:FilterCheck(itemlink) then
            self:AddResult("pvp", PLAYER_V_PLAYER, pvprating,itemlink)
        end

    end
end
