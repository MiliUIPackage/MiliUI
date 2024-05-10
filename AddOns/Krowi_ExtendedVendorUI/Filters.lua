local _, addon = ...;
addon.Filters = {};
local filters = addon.Filters;

_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_NEW_RANGE"] = 100;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_PETS"] = 101;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_MOUNTS"] = 102;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TOYS"] = 103;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TRANSMOG"] = 104;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_CUSTOM"] = 200;
_G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_SEARCH"] = 201;

local defaults = {
	profile = {
		HideCollectedPets = false,
		HideCollectedMounts = false,
		HideCollectedToys = false,
		HideCollectedTransmog = false,
		Custom = {
			Pets = true,
			Mounts = true,
			Toys = true,
			Transmog = true,
			Other = true
		}
	}
};

function filters:RefreshFilters()
    -- for t, _ in next, addon.Tabs do
    --     addon.Tabs[t].Filters = self.db.profile.Tabs[t];
    -- end
end

function filters:Load()
	self.db = LibStub("AceDB-3.0"):New("KrowiEVU_Filters", defaults, true);
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshFilters");
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshFilters");
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshFilters");
end

function filters:Validate(lootFilter, itemId)
	if lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_PETS"] then
		return self:ValidatePetsOnly(itemId);
    elseif lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_MOUNTS"] then
		return self:ValidateMountsOnly(itemId);
    elseif lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TOYS"] then
		return self:ValidateToysOnly(itemId);
    elseif lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TRANSMOG"] then
		return self:ValidateTransmogOnly(itemId);
    elseif lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_CUSTOM"] then
		return self:ValidateCustom(itemId);
    elseif lootFilter == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_SEARCH"] then
		return self:ValidateSearch(itemId);
	else
		if self.IsPet(itemId) and addon.Filters.db.profile.HideCollectedPets then
			return not self.IsPetCollected(itemId);
		end

		if self.IsMount(itemId) and addon.Filters.db.profile.HideCollectedMounts then
			return not self.IsMountCollected(itemId);
		end

		if self.IsToy(itemId) and addon.Filters.db.profile.HideCollectedToys then
			return not self.IsToyCollected(itemId);
		end
		
		if self.IsTransmog(itemId) and addon.Filters.db.profile.HideCollectedTransmog then
			return not self.IsTransmogCollected(itemId);
		end
	end

	return true;
end

do -- Pets
	function filters:ValidatePetsOnly(itemId)
		if not self.IsPet(itemId) then
			return false;
		end
		if addon.Filters.db.profile.HideCollectedPets then
			return not self.IsPetCollected(itemId);
		end
		return true;
	end

	function filters.IsPet(itemId)
		local classId, subclassId = select(12, GetItemInfo(itemId));
		if classId ~= Enum.ItemClass.Miscellaneous or subclassId ~= Enum.ItemMiscellaneousSubclass.CompanionPet then
			return false;
		end

		local name = C_PetJournal.GetPetInfoByItemID(itemId);
		return name ~= nil;
	end

	function filters.IsPetCollected(itemId)
		return (C_PetJournal.GetNumCollectedInfo((select(13, C_PetJournal.GetPetInfoByItemID(itemId))))) ~= 0;
	end
end

do -- Mounts
	function filters:ValidateMountsOnly(itemId)
		if not self.IsMount(itemId) then
			return false;
		end
		if addon.Filters.db.profile.HideCollectedMounts then
			return not self.IsMountCollected(itemId);
		end
		return true;
	end

	function filters.IsMount(itemId)
		local classId, subclassId = select(12, GetItemInfo(itemId));
		return classId == Enum.ItemClass.Miscellaneous and subclassId == Enum.ItemMiscellaneousSubclass.Mount;
	end

	function filters.IsMountCollected(itemId)
		return (select(11, C_MountJournal.GetMountInfoByID(C_MountJournal.GetMountFromItem(itemId))));
	end
end

do -- Toys
	function filters:ValidateToysOnly(itemId)
		if not self.IsToy(itemId) then
			return false;
		end
		if addon.Filters.db.profile.HideCollectedToys then
			return not self.IsToyCollected(itemId);
		end
		return true;
	end

	function filters.IsToy(itemId)
		itemId = C_ToyBox.GetToyInfo(itemId);
		return itemId ~= nil;
	end

	function filters.IsToyCollected(itemId)
		return PlayerHasToy(itemId);
	end
end

do -- Transmog
	function filters:ValidateTransmogOnly(itemId)
		if not self.IsTransmog(itemId) then
			return false;
		end
		if addon.Filters.db.profile.HideCollectedTransmog then
			return not self.IsTransmogCollected(itemId);
		end
		return true;
	end

	function filters.IsTransmog(itemId)
		itemId = C_TransmogCollection.GetItemInfo(itemId);
		return itemId ~= nil;
	end

	function filters.IsTransmogCollected(itemId)
		return C_TransmogCollection.PlayerHasTransmog(itemId);
	end
end

do -- Custom
	function filters:ValidateCustom(itemId)
		if self.IsPet(itemId) then
			if addon.Filters.db.profile.Custom.Pets then
				if addon.Filters.db.profile.HideCollectedPets then
					return not self.IsPetCollected(itemId);
				end
				return true;
			end
			return false;
		end

		if self.IsMount(itemId) then
			if addon.Filters.db.profile.Custom.Mounts then
				if addon.Filters.db.profile.HideCollectedMounts then
					return not self.IsMountCollected(itemId);
				end
				return true;
			end
			return false;
		end

		if self.IsToy(itemId) then
			if addon.Filters.db.profile.Custom.Toys then
				if addon.Filters.db.profile.HideCollectedToys then
					return not self.IsToyCollected(itemId);
				end
				return true;
			end
			return false;
		end

		if self.IsTransmog(itemId) then
			if addon.Filters.db.profile.Custom.Transmog then
				if addon.Filters.db.profile.HideCollectedTransmog then
					return not self.IsTransmogCollected(itemId);
				end
				return true;
			end
			return false;
		end

		return addon.Filters.db.profile.Custom.Other;
	end
end

do -- Search
	function filters:ValidateSearch(itemId)
		local name = GetItemInfo(itemId);
		if name and strfind(name:lower(), KrowiEVU_SearchBox:GetText():lower(), 1, true) then
			return true;
		end
		return false;
	end
end