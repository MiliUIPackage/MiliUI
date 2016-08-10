SellOMatic_Item = LibStub("AceAddon-3.0"):NewAddon("SellOMatic_Item", "AceEvent-3.0", "AceConsole-3.0");
local SellOMatic = _G.SellOMatic
local item_tooltip = LibStub("LibGratuity-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("SellOMatic");

local function getOption(info)
	return (info.arg and SellOMatic.db.profile[info.arg] or SellOMatic.db.profile[info[#info]]);
end;

local function setOption(info, value)
	local key = info.arg or info[#info];
	SellOMatic.db.profile[key] = value;
end;

local max_iLevel = 650

local item_options = {
	type = "group",
	name = L["Item Options"],
	args = {
		item_white = {
			name = L["White quality item options"],
			type = "group",
			guiInline = true,
			order = 1,
			args = {
				item_white_enable = {
					name = L["Enable white items"],
					desc = L["Enables the addon to sell white items with the following rules"],
					order = 1,
					width = "full",
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_white_ilevel = {
					name = L["Sell by iLevel"],
					desc = L["Enables the addon to sell white items based on its iLevel"],
					order = 2,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_white_ilevel_value = {
					name = L["iLevel value"],
					desc = L["Sets the iLevel value to filter the items to be sold"],
					order = 3,
					type = "range",
					min = 1,
					max = max_iLevel,
					step = 1,
					get = getOption,
					set = setOption,
				},
			},
		},
		item_green = {
			name = L["Green quality item options"],
			type = "group",
			guiInline = true,
			order = 2,
			args = {
				item_green_enable = {
					name = L["Enable green items"],
					desc = L["Enables de addon to sell green items with the following rules"],
					order = 1,
					width = "full",
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_green_bop = {
					name = L["Sell BoP items"],
					desc = L["Enables the addon to sell Bind on Pickup green items"],
					order = 2,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_green_boe = {
					name = L["Sell BoE items"],
					desc = L["Enables the addon to sell Bind on Equip green items"],
					order = 3,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_green_ilevel = {
					name = L["Sell by iLevel"],
					desc = L["Enables the addon to sell green items based on its iLevel"],
					order = 4,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_green_ilevel_value = {
					name = L["iLevel value"],
					desc = L["Sets the iLevel value to filter the items to be sold"],
					order = 5,
					type = "range",
					min = 1,
					max = max_iLevel,
					step = 1,
					get = getOption,
					set = setOption,
				},
			},
		},
		item_blue = {
			name = L["Blue quality item options"],
			type = "group",
			guiInline = true,
			order = 3,
			args = {
				item_blue_enable = {
					name = L["Enable blue items"],
					desc = L["Enables de addon to sell blue items with the following rules"],
					order = 1,
					width = "full",
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_blue_bop = {
					name = L["Sell BoP items"],
					desc = L["Enables the addon to sell Bind on Pickup blue items"],
					order = 2,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_blue_boe = {
					name = L["Sell BoE items"],
					desc = L["Enables the addon to sell Bind on Equip blue items"],
					order = 3,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_blue_ilevel = {
					name = L["Sell by iLevel"],
					desc = L["Enables the addon to sell blue items based on its iLevel"],
					order = 4,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_blue_ilevel_value = {
					name = L["iLevel value"],
					desc = L["Sets the iLevel value to filter the items to be sold"],
					order = 5,
					type = "range",
					min = 1,
					max = max_iLevel,
					step = 1,
					get = getOption,
					set = setOption,
				},
			},
		},
		item_epic = {
			name = L["Epic quality item options"],
			type = "group",
			guiInline = true,
			order = 4,
			args = {
				item_epic_enable = {
					name = L["Enable epic items"],
					desc = L["Enables de addon to sell epic items with the following rules"],
					order = 1,
					width = "full",
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_epic_bop = {
					name = L["Sell BoP items"],
					desc = L["Enables the addon to sell Bind on Pickup epic items"],
					order = 2,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_epic_boe = {
					name = L["Sell BoE items"],
					desc = L["Enables the addon to sell Bind on Equip epic items"],
					order = 3,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_epic_ilevel = {
					name = L["Sell by iLevel"],
					desc = L["Enables the addon to sell epic items based on its iLevel"],
					order = 4,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				item_epic_ilevel_value = {
					name = L["iLevel value"],
					desc = L["Sets the iLevel value to filter the items to be sold"],
					order = 5,
					type = "range",
					min = 1,
					max = max_iLevel,
					step = 1,
					get = getOption,
					set = setOption,
				},
			},
		},
	},
}

function SellOMatic_Item:OnInitialize()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SellOMatic_Item", item_options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SellOMatic_Item", L["Item Options"], "Sell-O-Matic");
end;

function SellOMatic:Scan_Item()
	local item_BoP = ITEM_SOULBOUND
	local item_BoE = ITEM_BIND_ON_EQUIP
	-- Patch for ptBR locale and BoE items
	if (GetLocale() == "ptBR") then item_BoE = "se quando equipado" end
	local bag, slot, add, texture, itemCount, quality, itemLink, itemName, itemLevel, itemSellPrice
	for bag = 0, NUM_BAG_SLOTS, 1 do
		for slot = 1, GetContainerNumSlots(bag), 1 do
			texture, itemCount, _, quality, _, _, itemLink, _ = GetContainerItemInfo(bag, slot)
			if texture ~= nil then
				add = 0
				itemName, _, _, itemLevel, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)
				if quality == 1 and SellOMatic.db.profile.item_white_enable then
					-- White item options
					add = 1
					if SellOMatic.db.profile.item_white_ilevel and SellOMatic.db.profile.item_white_ilevel_value < itemLevel then
						add = 0
					end
				elseif quality == 2 and SellOMatic.db.profile.item_green_enable then
					-- Green item options
					if SellOMatic.db.profile.item_green_bop or SellOMatic.db.profile.item_green_boe then
						item_tooltip:SetBagItem(bag,slot)
						if SellOMatic.db.profile.item_green_bop and item_tooltip:Find(item_BoP,1,4) then
							add = 1
						elseif SellOMatic.db.profile.item_green_boe and item_tooltip:Find(item_BoE,1,4) then
							add = 1
						end
					end
					if type(itemLevel) == "number" then
						if SellOMatic.db.profile.item_green_ilevel and SellOMatic.db.profile.item_green_ilevel_value < itemLevel then
							add = 0
						end
					end
				elseif quality == 3 and SellOMatic.db.profile.item_blue_enable then
					-- Blue item options
					if SellOMatic.db.profile.item_blue_bop or SellOMatic.db.profile.item_blue_boe then
						item_tooltip:SetBagItem(bag,slot)
						if SellOMatic.db.profile.item_blue_bop and item_tooltip:Find(item_BoP,1,4) then
							add = 1
						elseif SellOMatic.db.profile.item_blue_boe and item_tooltip:Find(item_BoE,1,4) then
							add = 1
						end
					end
					if type(itemLevel) == "number" then
						if SellOMatic.db.profile.item_blue_ilevel and SellOMatic.db.profile.item_blue_ilevel_value < itemLevel then
							add = 0
						end
					end
				elseif quality == 4 and SellOMatic.db.profile.item_epic_enable then
					-- Epic item options
					if SellOMatic.db.profile.item_epic_bop or SellOMatic.db.profile.item_epic_boe then
						item_tooltip:SetBagItem(bag,slot)
						if SellOMatic.db.profile.item_epic_bop and item_tooltip:Find(item_BoP,1,4) then
							add = 1
						elseif SellOMatic.db.profile.item_epic_boe and item_tooltip:Find(item_BoE,1,4) then
							add = 1
						end
					end
					if type(itemLevel) == "number" then
						if SellOMatic.db.profile.item_epic_ilevel and SellOMatic.db.profile.item_epic_ilevel_value < itemLevel then
							add = 0
						end
					end
				end
				if add == 1 then
					if itemCount > 1 then
						itemSellPrice = itemSellPrice * itemCount
					end
					SellOMatic:Add_Shopping_List(itemName, itemLink, quality, itemLevel, itemSellPrice, itemCount)
				end
			end
		end
	end
end
