local _, addon = ...;

KrowiEVU_FilterButtonMixin = {};

function KrowiEVU_FilterButtonMixin:ShowHide()
    if addon.Options.db.profile.ShowOptionsButton then
        self:Show();
        return;
    end
    self:Hide();
end

function KrowiEVU_FilterButtonMixin:AddTitle(menu, text)
	menu:AddFull({
		Text = text,
		IsTitle = true
	});
end

function KrowiEVU_FilterButtonMixin:AddLootFilterRadioButton(parentMenu, _menu, text, lootFilter)
    _menu:AddFull({
		Text = text,
		Checked = function()
			return GetMerchantFilter() == lootFilter;
		end,
		Func = function()
			MerchantFrame_SetFilter(nil, lootFilter);
			parentMenu:SetSelectedName(text);
			self:SetText(text);
		end,
		NotCheckable = false,
		KeepShownOnClick = true
	});
end

function KrowiEVU_FilterButtonMixin:AddCheckBox(_menu, text, keys)
	local _filters = addon.Filters.db.profile;
    _menu:AddFull({
		Text = text,
		Checked = function() -- Using function here, we force the GUI to get the value again instead of only once (caused visual bugs)
			return addon.Util.ReadNestedKeys(_filters, keys); -- e.g.: return filters.Completion.Completed;
		end,
		Func = function()
			addon.Util.WriteNestedKeys(_filters, keys, not addon.Util.ReadNestedKeys(_filters, keys));
			MerchantFrame_SetFilter(nil, GetMerchantFilter());
		end,
		IsNotRadio = true,
		NotCheckable = false,
		KeepShownOnClick = true,
		IgnoreAsMenuSelection = true
	});
end

local menu = LibStub("Krowi_Menu-1.0");
local menuItem = LibStub("Krowi_MenuItem-1.0");
function KrowiEVU_FilterButtonMixin:BuildMenu()
	-- Reset menu
	menu:Clear();

	local className = UnitClass("player");
	self:AddTitle(menu, addon.L["Default filters"]);
	local class = menuItem:New({
		Text = className,
		Checked = function()
			return GetMerchantFilter() >= LE_LOOT_FILTER_CLASS and GetMerchantFilter() <= LE_LOOT_FILTER_SPEC4;
		end,
		Func = function()
			MerchantFrame_SetFilter(nil, LE_LOOT_FILTER_CLASS);
			menu:SetSelectedName(className);
			self:SetText(className);
		end,
		NotCheckable = false,
		KeepShownOnClick = true
	});
	local numSpecs = GetNumSpecializations();
	local sex = UnitSex("player");
	for i = 1, numSpecs do
		local _, name = GetSpecializationInfo(i, nil, nil, nil, sex);
		self:AddLootFilterRadioButton(menu, class, name, LE_LOOT_FILTER_SPEC1 + i - 1, className, name);
	end
	self:AddLootFilterRadioButton(menu, class, ALL_SPECS, LE_LOOT_FILTER_CLASS, ALL_SPECS, className);
	menu:Add(class);

	self:AddLootFilterRadioButton(menu, menu, ITEM_BIND_ON_EQUIP, LE_LOOT_FILTER_BOE, ITEM_BIND_ON_EQUIP, ITEM_BIND_ON_EQUIP);

	self:AddLootFilterRadioButton(menu, menu, ALL, LE_LOOT_FILTER_ALL, ALL, ALL);

	menu:AddSeparator();

	self:AddTitle(menu, addon.L["Only show"]);
	self:AddLootFilterRadioButton(menu, menu, addon.L["Pets"], _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_PETS"]);
	self:AddLootFilterRadioButton(menu, menu, addon.L["Mounts"], _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_MOUNTS"]);
	self:AddLootFilterRadioButton(menu, menu, addon.L["Toys"], _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TOYS"]);
	self:AddLootFilterRadioButton(menu, menu, addon.L["Transmog"], _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_TRANSMOG"]);

	local custom = menuItem:New({
		Text = addon.L["Custom"],
		Checked = function()
			return GetMerchantFilter() == _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_CUSTOM"];
		end,
		Func = function()
			MerchantFrame_SetFilter(nil, _G[addon.Metadata.Prefix .. "_LE_LOOT_FILTER_CUSTOM"]);
			menu:SetSelectedName(addon.L["Custom"]);
			self:SetText(addon.L["Custom"]);
		end,
		NotCheckable = false,
		KeepShownOnClick = true
	});
	self:AddCheckBox(custom, addon.L["Pets"], {"Custom", "Pets"});
	self:AddCheckBox(custom, addon.L["Mounts"], {"Custom", "Mounts"});
	self:AddCheckBox(custom, addon.L["Toys"], {"Custom", "Toys"});
	self:AddCheckBox(custom, addon.L["Transmog"], {"Custom", "Transmog"});
	self:AddCheckBox(custom, addon.L["Other"], {"Custom", "Other"});
	menu:Add(custom);

	menu:AddSeparator();

	self:AddTitle(menu, addon.L["Hide collected"]);
	self:AddCheckBox(menu, addon.L["Pets"], {"HideCollectedPets"});
	self:AddCheckBox(menu, addon.L["Mounts"], {"HideCollectedMounts"});
	self:AddCheckBox(menu, addon.L["Toys"], {"HideCollectedToys"});
	self:AddCheckBox(menu, addon.L["Transmog"], {"HideCollectedTransmog"});

	return menu;
end

function KrowiEVU_FilterButtonMixin:MyOnMouseDown()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	self:BuildMenu();
    menu:Toggle(self, 96, 15);
end