local AddonName, KeystoneLoot = ...;

local DB = KeystoneLoot.DB;
local Query = KeystoneLoot.Query;

local SLOTS = {
    INVTYPE_HEAD,
    INVTYPE_NECK,
    INVTYPE_SHOULDER,
    INVTYPE_CLOAK,
    INVTYPE_CHEST,
    INVTYPE_WRIST,
    INVTYPE_HAND,
    INVTYPE_WAIST,
    INVTYPE_LEGS,
    INVTYPE_FEET,
    INVTYPE_WEAPONMAINHAND,
    INVTYPE_WEAPONOFFHAND,
    INVTYPE_FINGER,
    INVTYPE_TRINKET,
    EJ_LOOT_SLOT_FILTER_OTHER
};

local WEAPON_SLOT = Enum.ItemSlotFilterType.MainHand;

local WEAPON_TYPES = { "dagger", "oneHand", "twoHand" };
local WEAPON_TYPE_NAME = {
    dagger  = C_Item.GetItemSubClassInfo(Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass.Dagger),
    oneHand = INVTYPE_WEAPON,
    twoHand = INVTYPE_2HWEAPON,
};

KeystoneLootSlotDropdownMixin = {};

local function GetSelectedSlots()
    local slotId = DB:Get("filters.slotId");
    if (not DB:Get("settings.multiSlotFilter") or slotId == -1 or slotId == -2) then
        return {};
    end

    local selectedSlots = DB:Get("filters.slotIds");

    if (type(selectedSlots) == "table") then
        for _, selected in pairs(selectedSlots) do
            if (selected) then
                return selectedSlots;
            end
        end
    end

    if (slotId and slotId >= 0) then
        return { [slotId] = true };
    end

    return {};
end

local function HasSelectedSlot(selectedSlots)
    for _, selected in pairs(selectedSlots) do
        if (selected) then
            return true;
        end
    end

    return false;
end

local function GetFirstSelectedSlot(selectedSlots)
    local firstSlotId;

    for slotId, selected in pairs(selectedSlots) do
        if (selected and (not firstSlotId or slotId < firstSlotId)) then
            firstSlotId = slotId;
        end
    end

    return firstSlotId;
end

local function GetSelectedSlotCount(selectedSlots)
    local count = 0;

    for _, selected in pairs(selectedSlots) do
        if (selected) then
            count = count + 1;
        end
    end

    return count;
end

local function GetSelectedWeaponTypes()
    local weaponTypes = DB:Get("filters.weaponTypes");

    if (type(weaponTypes) == "table") then
        return weaponTypes;
    end

    return {};
end

local function GetSlotName(slotId)
    if (slotId == WEAPON_SLOT) then
        local selectedWeaponTypes = GetSelectedWeaponTypes();

        for _, weaponType in ipairs(WEAPON_TYPES) do
            if (selectedWeaponTypes[weaponType]) then
                return WEAPON_TYPE_NAME[weaponType];
            end
        end
    end

    return SLOTS[slotId + 1];
end

function KeystoneLootSlotDropdownMixin:Init()
    self:SetSelectionText(function(selections)
        local slotId = DB:Get("filters.slotId");

        if (slotId == -1) then
            return FAVORITES;
        end

        if (slotId == -2) then
            return ALL_INVENTORY_SLOTS;
        end

        if (not DB:Get("settings.multiSlotFilter")) then
            return GetSlotName(slotId);
        end

        local selectedSlots = GetSelectedSlots();
        local count = GetSelectedSlotCount(selectedSlots);
        local firstSlotId = GetFirstSelectedSlot(selectedSlots);

        if (count == 0 or not firstSlotId) then
            return ALL_INVENTORY_SLOTS;
        end

        local firstSlotName = SLOTS[firstSlotId + 1];
        if (count == 1) then
            return firstSlotName;
        end

        return string.format("%s + %d", firstSlotName, count - 1);
    end);

    self:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MENU_KEYSTONELOOT_SLOT_DROPDOWN");

        local function IsSpecialSelected(data)
            return DB:Get("filters.slotId") == data.slotId;
        end

        local function SetSpecialSelected(data)
            DB:Set("filters.slotIds", {});
            DB:Set("filters.weaponTypes", {});
            DB:Set("filters.slotId", data.slotId);
        end

        local function SetSlotSelected(data)
            DB:Set("filters.slotIds", {});
            DB:Set("filters.weaponTypes", {});
            DB:Set("filters.slotId", data.slotId);
        end

        local function IsSlotSelected(data)
            if (not DB:Get("settings.multiSlotFilter")) then
                return DB:Get("filters.slotId") == data.slotId;
            end

            local selectedSlots = GetSelectedSlots();
            return selectedSlots[data.slotId];
        end

        local function ToggleSlot(data)
            local selectedSlots = GetSelectedSlots();
            selectedSlots[data.slotId] = not selectedSlots[data.slotId] or nil;

            if (data.slotId == WEAPON_SLOT) then
                DB:Set("filters.weaponTypes", {});
            end

            if (HasSelectedSlot(selectedSlots)) then
                DB:Set("filters.slotIds", selectedSlots);
                DB:Set("filters.slotId", GetFirstSelectedSlot(selectedSlots));
            else
                DB:Set("filters.slotIds", {});
                DB:Set("filters.slotId", -2);
            end
        end

        local function IsWeaponTypeSelected(weaponType)
            return IsSlotSelected({ slotId = WEAPON_SLOT }) and GetSelectedWeaponTypes()[weaponType] == true;
        end

        local function SetWeaponTypeSelected(weaponType)
            DB:Set("filters.slotIds", {});
            DB:Set("filters.weaponTypes", { [weaponType] = true });
            DB:Set("filters.slotId", WEAPON_SLOT);
        end

        local function ToggleWeaponType(weaponType)
            local selectedSlots = GetSelectedSlots();
            selectedSlots[WEAPON_SLOT] = true;

            local selectedWeaponTypes = GetSelectedWeaponTypes();
            selectedWeaponTypes[weaponType] = not selectedWeaponTypes[weaponType] or nil;

            DB:Set("filters.slotIds", selectedSlots);
            DB:Set("filters.weaponTypes", selectedWeaponTypes);
            DB:Set("filters.slotId", GetFirstSelectedSlot(selectedSlots));
        end

        rootDescription:CreateRadio(FAVORITES, IsSpecialSelected, SetSpecialSelected, { slotId = -1 });
        rootDescription:CreateDivider();
        rootDescription:CreateRadio(ALL_INVENTORY_SLOTS, IsSpecialSelected, SetSpecialSelected, { slotId = -2 });

        local weaponTypes = self:GetWeaponTypes();

        for index, slotName in ipairs(SLOTS) do
            local slotId = index - 1; -- 0-based
            local checkbox;
            if (DB:Get("settings.multiSlotFilter")) then
                checkbox = rootDescription:CreateCheckbox(slotName, IsSlotSelected, ToggleSlot, { slotId = slotId });
            else
                checkbox = rootDescription:CreateRadio(slotName, IsSlotSelected, SetSlotSelected, { slotId = slotId });
            end

            if (not self:SlotHasItems(slotId)) then
                checkbox:SetEnabled(false);

                checkbox:SetTooltip(function(Tooltip, elementDescription)
                    GameTooltip_AddColoredLine(Tooltip, BROWSE_NO_RESULTS, RED_FONT_COLOR);
                end);
            elseif (slotId == WEAPON_SLOT and next(weaponTypes)) then
                checkbox:SetShouldRespondIfSubmenu(true);

                for _, weaponType in ipairs(WEAPON_TYPES) do
                    if (weaponTypes[weaponType]) then
                        if (DB:Get("settings.multiSlotFilter")) then
                            checkbox:CreateCheckbox(WEAPON_TYPE_NAME[weaponType], IsWeaponTypeSelected, ToggleWeaponType, weaponType);
                        else
                            checkbox:CreateRadio(WEAPON_TYPE_NAME[weaponType], IsWeaponTypeSelected, SetWeaponTypeSelected, weaponType);
                        end
                    end
                end
            end
        end
    end);

    local function OnChanged()
        local weaponTypes = self:GetWeaponTypes();
        local selectedWeaponTypes = GetSelectedWeaponTypes();
        local removedWeaponType = false;

        for weaponType in pairs(selectedWeaponTypes) do
            if (not weaponTypes[weaponType]) then
                selectedWeaponTypes[weaponType] = nil;
                removedWeaponType = true;
            end
        end

        if (removedWeaponType) then
            DB:Set("filters.weaponTypes", selectedWeaponTypes);
        end

        -- Check if current slot still has items
        local currentSlot = DB:Get("filters.slotId");

        -- Skip favorites and all-slots modes
        if (currentSlot ~= -1 and currentSlot ~= -2) then
            if (not DB:Get("settings.multiSlotFilter")) then
                DB:Set("filters.slotIds", {});

                if (not self:SlotHasItems(currentSlot)) then
                    DB:Set("filters.slotId", -2);
                end

                self:GenerateMenu();
                return;
            end

            local selectedSlots = GetSelectedSlots();
            for slotId, selected in pairs(selectedSlots) do
                if (selected and not self:SlotHasItems(slotId)) then
                    selectedSlots[slotId] = nil;
                end
            end

            -- If selected slots are now empty, reset to all slots.
            if (HasSelectedSlot(selectedSlots)) then
                DB:Set("filters.slotIds", selectedSlots);
                DB:Set("filters.slotId", GetFirstSelectedSlot(selectedSlots));
            else
                DB:Set("filters.slotIds", {});
                DB:Set("filters.slotId", -2);
            end
        end

        self:GenerateMenu();
    end

    DB:AddObserver("ui.selectedTab", OnChanged);
    DB:AddObserver("ui.selectedRaidTab", OnChanged);
    DB:AddObserver("filters.specId", OnChanged);
    DB:AddObserver("settings.multiSlotFilter", OnChanged);
    DB:AddObserver("filters.slotId", function()
        if (not self:IsMenuOpen()) then
            self:GenerateMenu();
        end
    end);
end

function KeystoneLootSlotDropdownMixin:SlotHasItems(slotId)
    local selectedTab = DB:Get("ui.selectedTab");

    if (selectedTab == "dungeons") then
        return Query:HasDungeonSlotItems(slotId);
    end

    return Query:HasRaidSlotItems(slotId);
end

function KeystoneLootSlotDropdownMixin:GetWeaponTypes()
    local selectedTab = DB:Get("ui.selectedTab");
    local weaponTypes;

    if (selectedTab == "dungeons") then
        weaponTypes = Query:GetDungeonWeaponTypes();
    else
        weaponTypes = Query:GetRaidWeaponTypes();
    end

    local count = 0;
    for _ in pairs(weaponTypes) do
        count = count + 1;
    end

    if (count < 2) then
        return {};
    end

    return weaponTypes;
end
