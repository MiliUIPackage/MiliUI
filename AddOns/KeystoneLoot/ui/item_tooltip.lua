local AddonName, KeystoneLoot = ...;

local Favorites = KeystoneLoot.Favorites;
local DB = KeystoneLoot.DB;
local Query = KeystoneLoot.Query;
local Character = KeystoneLoot.Character;

local function GetSourceInfo(itemId)
    -- Check catalyst first — no tooltip for catalyst items
    if (KeystoneLoot.CatalystDatabase[itemId]) then
        return;
    end

    -- Check dungeons
    for _, dungeon in ipairs(Query:GetDungeons()) do
        for _, lootItemId in ipairs(dungeon.lootTable) do
            if (lootItemId == itemId) then
                local name = C_ChallengeMode.GetMapUIInfo(dungeon.challengeModeId);
                return {
                    type = "dungeon",
                    name = name,
                    instanceId = dungeon.instanceId,
                };
            end
        end
    end

    -- Check raids
    for _, raid in ipairs(Query:GetRaids()) do
        for _, boss in ipairs(raid.bossList) do
            for _, lootTable in pairs(boss.lootTable) do
                for _, lootItemId in ipairs(lootTable) do
                    if (lootItemId == itemId) then
                        local bossName = EJ_GetEncounterInfo(boss.bossId);
                        local raidName = EJ_GetInstanceInfo(raid.journalInstanceId);
                        return {
                            type = "raid",
                            name = raidName,
                            bossName = bossName,
                            instanceId = raid.instanceId,
                        };
                    end
                end
            end
        end
    end
end

local function OnTooltipSetItem(Tooltip)
    -- GameTooltip and ItemRefTooltip only
    if (Tooltip ~= GameTooltip and Tooltip ~= ItemRefTooltip) then
        return;
    end

    -- Check if feature is enabled
    if (not DB:Get("settings.favoriteTooltip")) then
        return;
    end

    if (Tooltip.KeystoneLootOwned) then
        return;
    end

    -- Get item link from tooltip
    local _, itemLink = Tooltip:GetItem();
    if (not itemLink) then
        return;
    end

    local itemId = tonumber(itemLink:match("item:(%d+)"));
    if (not itemId) then
        return;
    end

    -- Catalyst items: no tooltip
    if (KeystoneLoot.CatalystDatabase[itemId]) then
        return;
    end

    local tier = Favorites:GetAnyTier(itemId, true);
    if (tier == 0) then
        return;
    end

    local sourceInfo = GetSourceInfo(itemId);
    if (not sourceInfo) then
        return;
    end

    local specTiers = Favorites:GetItemSpecTiers(itemId, true);
    local allSpecs = Character:GetAllSpecs();
    local tierSpecNames = {};
    local sourceName;

    for _, spec in ipairs(allSpecs) do
        local specTier = specTiers[spec.specId];
        if (specTier) then
            if (not tierSpecNames[specTier]) then
                tierSpecNames[specTier] = {};
            end
            table.insert(tierSpecNames[specTier], spec.name);
        end
    end

    if (sourceInfo.type == "dungeon") then
        sourceName = "|A:questlog-questtypeicon-dungeon:16:16:0:0|a " .. sourceInfo.name;
    elseif (sourceInfo.type == "raid") then
        sourceName = "|A:questlog-questtypeicon-raid:16:16:0:0|a " .. string.format("%s - %s", sourceInfo.name, sourceInfo.bossName);
    end

    -- Check if player is currently in the correct instance
    local _, _, _, _, _, _, _, currentInstanceId = GetInstanceInfo();
    local inCorrectInstance = currentInstanceId == sourceInfo.instanceId;

    Tooltip:AddLine(" ");
    Tooltip:AddLine("|cff9d5db8KeystoneLoot|r");
    for _, currentTier in ipairs(Favorites.TIER_ORDER) do
        local specNames = tierSpecNames[currentTier];
        if (specNames) then
            local specText = #specNames >= #allSpecs and ALL_SPECS or table.concat(specNames, " / ");
            Tooltip:AddLine(string.format("|T%s:16:16|t %s (%s)", Favorites:GetTierIcon(currentTier), Favorites:GetTierName(currentTier), specText));
        end
    end

    if (not inCorrectInstance) then
        Tooltip:AddLine(sourceName);
    end

    Tooltip:Show();
end

-- Register tooltip hook
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem);
