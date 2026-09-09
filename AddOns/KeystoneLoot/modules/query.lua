local AddonName, KeystoneLoot = ...;

KeystoneLoot.Query = {};

local Query = KeystoneLoot.Query;
local DB = KeystoneLoot.DB;
local Character = KeystoneLoot.Character;

local DIFFICULTY_MAP = {
    lfr = DifficultyUtil.ID.PrimaryRaidLFR,
    normal = DifficultyUtil.ID.PrimaryRaidNormal,
    heroic = DifficultyUtil.ID.PrimaryRaidHeroic,
    mythic = DifficultyUtil.ID.PrimaryRaidMythic
};

local WEAPON_SLOT = Enum.ItemSlotFilterType.MainHand;

local RANGED_WEAPON_SUBCLASSES = {
    [Enum.ItemWeaponSubclass.Bows] = true,
    [Enum.ItemWeaponSubclass.Guns] = true,
    [Enum.ItemWeaponSubclass.Crossbow] = true,
};

local function GetTierSortIndex(tier)
    return KeystoneLoot.Favorites.TIER_SORT_INDEX[tier] or 99;
end

local function SortResult(a, b)
    local aTier = KeystoneLoot.Favorites:GetTier(a.itemId);
    local bTier = KeystoneLoot.Favorites:GetTier(b.itemId);

    if (aTier ~= bTier) then
        return GetTierSortIndex(aTier) < GetTierSortIndex(bTier);
    end

    local aItem = Query:GetItemInfo(a.itemId);
    local bItem = Query:GetItemInfo(b.itemId);
    local aSlot = aItem and aItem.slotId or 0;
    local bSlot = bItem and bItem.slotId or 0;

    if (aSlot ~= bSlot) then
        return aSlot < bSlot;
    end

    return a.itemId < b.itemId;
end

local function SortResultFavorites(a, b)
    local aTier = KeystoneLoot.Favorites:GetAnyTier(a.itemId);
    local bTier = KeystoneLoot.Favorites:GetAnyTier(b.itemId);

    if (aTier ~= bTier) then
        return GetTierSortIndex(aTier) < GetTierSortIndex(bTier);
    end

    local aItem = Query:GetItemInfo(a.itemId);
    local bItem = Query:GetItemInfo(b.itemId);
    local aSlot = aItem and aItem.slotId or 0;
    local bSlot = bItem and bItem.slotId or 0;

    if (aSlot ~= bSlot) then
        return aSlot < bSlot;
    end

    return a.itemId < b.itemId;
end

local function CheckRaid(raid, slotId)
    local difficultyId = Query:GetRaidDifficultyId();
    local classId = DB:Get("filters.classId");
    local specId = DB:Get("filters.specId");

    for _, boss in ipairs(raid.bossList) do
        local loot = boss.lootTable[difficultyId] or {};

        for _, itemId in ipairs(loot) do
            local item = Query:GetItemInfo(itemId);

            if (item and item.slotId == slotId and item.classes[classId]) then
                if (specId == 0) then
                    return true;
                else
                    for _, itemSpecId in ipairs(item.classes[classId]) do
                        if (itemSpecId == specId) then
                            return true;
                        end
                    end
                end
            end
        end
    end

    return false;
end

local function GetFavoritesListSpecId()
    local info = Character:ParseKey(Character:GetSelectedKey());

    if (info and DB:Get("filters.classId") == info.classId) then
        return DB:Get("filters.specId");
    end

    return 0;
end

local function GetSlotFilter()
    local slotId = DB:Get("filters.slotId");

    if (slotId == -1 or slotId == -2) then
        return slotId;
    end

    local slotIds = DB:Get("filters.slotIds");
    if (DB:Get("settings.multiSlotFilter") and type(slotIds) == "table") then
        for _, selected in pairs(slotIds) do
            if (selected) then
                return nil, slotIds;
            end
        end
    end

    return slotId;
end

local function ItemMatchesSlot(item, slotId, slotIds, hideOtherItems)
    if (slotId == -2) then
        return not (hideOtherItems and item.slotId == 14);
    end

    if (slotIds) then
        return slotIds[item.slotId] == true;
    end

    return item.slotId == slotId;
end

local function GetWeaponTypeFilter()
    local weaponTypes = DB:Get("filters.weaponTypes");

    if (type(weaponTypes) == "table" and next(weaponTypes)) then
        return weaponTypes;
    end

    return nil;
end

local function ItemMatchesWeaponType(itemId, item, weaponTypes)
    return not weaponTypes or item.slotId ~= WEAPON_SLOT or weaponTypes[Query:GetWeaponType(itemId)] == true;
end

local function ItemMatchesSpec(item, classId, specId)
    if (not item.classes[classId]) then
        return false;
    end

    if (specId == 0) then
        return true;
    end

    for _, itemSpecId in ipairs(item.classes[classId]) do
        if (itemSpecId == specId) then
            return true;
        end
    end

    return false;
end

function Query:GetDungeons()
    return KeystoneLoot.DungeonDatabase;
end

function Query:GetDungeonItems(challengeModeId)
    local slotId, slotIds = GetSlotFilter();

    -- Favorites slot
    if (slotId == -1) then
        local results = KeystoneLoot.Favorites:GetList(challengeModeId, GetFavoritesListSpecId());
        table.sort(results, SortResultFavorites);
        return results;
    end

    local specId = DB:Get("filters.specId");
    local classId = DB:Get("filters.classId");
    local hideOtherItems = DB:Get("settings.hideOtherItems");
    local weaponTypes = GetWeaponTypeFilter();
    local results = {};

    for _, dungeon in ipairs(self:GetDungeons()) do
        if (dungeon.challengeModeId == challengeModeId) then
            for _, itemId in ipairs(dungeon.lootTable) do
                local item = self:GetItemInfo(itemId);

                if (item and ItemMatchesSlot(item, slotId, slotIds, hideOtherItems) and item.classes[classId] and ItemMatchesWeaponType(itemId, item, weaponTypes)) then
                    if (specId == 0) then
                        table.insert(results, { itemId = itemId, icon = item.icon });
                    else
                        for _, itemSpecId in ipairs(item.classes[classId]) do
                            if (itemSpecId == specId) then
                                table.insert(results, { itemId = itemId, icon = item.icon });
                                break;
                            end
                        end
                    end
                end
            end

            break;
        end
    end

    table.sort(results, SortResult);
    return results;
end

function Query:HasDungeonSlotItems(slotId)
    if (slotId == -2) then
        return true;
    end

    local specId = DB:Get("filters.specId");
    local classId = DB:Get("filters.classId");

    for _, dungeon in ipairs(self:GetDungeons()) do
        for _, itemId in ipairs(dungeon.lootTable) do
            local item = self:GetItemInfo(itemId);

            if (item and item.slotId == slotId and item.classes[classId]) then
                if (specId == 0) then
                    return true;
                else
                    for _, itemSpecId in ipairs(item.classes[classId]) do
                        if (itemSpecId == specId) then
                            return true;
                        end
                    end
                end
            end
        end
    end

    return false;
end

function Query:GetDungeonWeaponTypes()
    local specId = DB:Get("filters.specId");
    local classId = DB:Get("filters.classId");
    local weaponTypes = {};

    for _, dungeon in ipairs(self:GetDungeons()) do
        for _, itemId in ipairs(dungeon.lootTable) do
            local item = self:GetItemInfo(itemId);

            if (item and item.slotId == WEAPON_SLOT and ItemMatchesSpec(item, classId, specId)) then
                weaponTypes[self:GetWeaponType(itemId)] = true;
            end
        end
    end

    return weaponTypes;
end

function Query:GetRaids()
    return KeystoneLoot.RaidDatabase;
end

function Query:GetRaidItems(bossId)
    local slotId, slotIds = GetSlotFilter();

    -- Favorites slot
    if (slotId == -1) then
        local results = KeystoneLoot.Favorites:GetList(bossId, GetFavoritesListSpecId());
        table.sort(results, SortResultFavorites);
        return results;
    end

    local specId = DB:Get("filters.specId");
    local difficultyId = self:GetRaidDifficultyId();
    local classId = DB:Get("filters.classId");
    local hideOtherItems = DB:Get("settings.hideOtherItems");
    local weaponTypes = GetWeaponTypeFilter();
    local results = {};

    for _, raid in ipairs(self:GetRaids()) do
        for _, boss in ipairs(raid.bossList) do
            if (boss.bossId == bossId) then
                local loot = boss.lootTable[difficultyId] or {};

                for _, itemId in ipairs(loot) do
                    local item = self:GetItemInfo(itemId)

                    if (item and ItemMatchesSlot(item, slotId, slotIds, hideOtherItems) and item.classes[classId] and ItemMatchesWeaponType(itemId, item, weaponTypes)) then
                        if (specId == 0) then
                            table.insert(results, { itemId = itemId, icon = item.icon });
                        else
                            for _, itemSpecId in ipairs(item.classes[classId]) do
                                if (itemSpecId == specId) then
                                    table.insert(results, { itemId = itemId, icon = item.icon });
                                    break;
                                end
                            end
                        end
                    end
                end

                break;
            end
        end
    end

    table.sort(results, SortResult);
    return results;
end

function Query:IsItemFromRaid(itemId, instanceId)
    local difficultyId = self:GetRaidDifficultyId();

    for _, raid in ipairs(self:GetRaids()) do
        if (raid.instanceId == instanceId) then
            for _, boss in ipairs(raid.bossList) do
                local loot = boss.lootTable[difficultyId] or {};

                for _, id in ipairs(loot) do
                    if (id == itemId) then
                        return true;
                    end
                end
            end
        end
    end
end

function Query:HasRaidSlotItems(slotId)
    if (slotId == -2) then
        return true;
    end

    if (self:GetTotalRaidBosses() <= 10) then
        for _, raid in ipairs(self:GetRaids()) do
            if (CheckRaid(raid, slotId)) then
                return true;
            end
        end
    else
        local journalInstanceId = DB:Get("ui.selectedRaidTab");

        for _, raid in ipairs(self:GetRaids()) do
            if (raid.journalInstanceId == journalInstanceId) then
                return CheckRaid(raid, slotId);
            end
        end
    end

    return false;
end

function Query:GetRaidWeaponTypes()
    local specId = DB:Get("filters.specId");
    local classId = DB:Get("filters.classId");
    local difficultyId = self:GetRaidDifficultyId();
    local journalInstanceId = self:GetTotalRaidBosses() > 10 and DB:Get("ui.selectedRaidTab");
    local weaponTypes = {};

    for _, raid in ipairs(self:GetRaids()) do
        if (not journalInstanceId or raid.journalInstanceId == journalInstanceId) then
            for _, boss in ipairs(raid.bossList) do
                for _, itemId in ipairs(boss.lootTable[difficultyId] or {}) do
                    local item = self:GetItemInfo(itemId);

                    if (item and item.slotId == WEAPON_SLOT and ItemMatchesSpec(item, classId, specId)) then
                        weaponTypes[self:GetWeaponType(itemId)] = true;
                    end
                end
            end
        end
    end

    return weaponTypes;
end

function Query:GetRaidDifficultyId()
    return DIFFICULTY_MAP[DB:Get("filters.raid.difficulty")] or DIFFICULTY_MAP.lfr;
end

function Query:GetTotalRaidBosses()
    local totalRaidBosses = 0;

    for _, raid in ipairs(self:GetRaids()) do
        totalRaidBosses = totalRaidBosses + #raid.bossList;
    end

    return totalRaidBosses;
end

function Query:GetCatalystItems()
    local classId = DB:Get("filters.classId");
    local slotId, slotIds = GetSlotFilter();

    -- Favorites slot
    if (slotId == -1) then
        local results = KeystoneLoot.Favorites:GetList("catalyst", GetFavoritesListSpecId());
        table.sort(results, SortResultFavorites);
        return results;
    end

    local results = {};

    for itemId, item in pairs(KeystoneLoot.CatalystDatabase) do
        if (item.classId == classId and ItemMatchesSlot(item, slotId, slotIds)) then
            table.insert(results, {
                itemId = itemId,
                icon = item.icon
            });
        end
    end

    table.sort(results, SortResult);
    return results;
end

function Query:GetCustomItems()
    local slotId = GetSlotFilter();

    -- Favorites slot
    if (slotId == -1) then
        local results = KeystoneLoot.Favorites:GetList("custom", GetFavoritesListSpecId());
        table.sort(results, SortResultFavorites);
        return results;
    end

    return {};
end

function Query:GetItemInfo(itemId)
    return KeystoneLoot.ItemDatabase[itemId];
end

function Query:GetItemIcon(itemId)
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemId);
    return icon;
end

function Query:GetWeaponType(itemId)
    local _, _, _, equipLoc, _, _, subclassId = C_Item.GetItemInfoInstant(itemId);

    if (subclassId == Enum.ItemWeaponSubclass.Dagger) then
        return "dagger";
    end

    if (equipLoc == "INVTYPE_2HWEAPON" or RANGED_WEAPON_SUBCLASSES[subclassId]) then
        return "twoHand";
    end

    return "oneHand";
end

function Query:GetItemSource(itemId)
    -- Check catalyst
    if (KeystoneLoot.CatalystDatabase[itemId]) then
        return "catalyst";
    end

    -- Check item info
    if (not self:GetItemInfo(itemId)) then
        return "custom";
    end

    -- Check dungeons
    for _, dungeon in ipairs(self:GetDungeons()) do
        for _, lootItemId in ipairs(dungeon.lootTable) do
            if (lootItemId == itemId) then
                return dungeon.challengeModeId;
            end
        end
    end

    -- Check raids
    for _, raid in ipairs(self:GetRaids()) do
        for _, boss in ipairs(raid.bossList) do
            for _, lootTable in pairs(boss.lootTable) do
                for _, lootItemId in ipairs(lootTable) do
                    if (lootItemId == itemId) then
                        return boss.bossId;
                    end
                end
            end
        end
    end
end
