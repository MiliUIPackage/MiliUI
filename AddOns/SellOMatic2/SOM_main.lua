SellOMatic = LibStub("AceAddon-3.0"):NewAddon("SellOMatic", "AceEvent-3.0", "AceConsole-3.0")
local SellOMatic = _G.SellOMatic
local L = LibStub("AceLocale-3.0"):GetLocale("SellOMatic")

local function getOption(info)
	return (info.arg and SellOMatic.db.profile[info.arg] or SellOMatic.db.profile[info[#info]])
end

local function setOption(info, value)
	local key = info.arg or info[#info]
	SellOMatic.db.profile[key] = value
end

local options = {
	name = "Sell-O-Matic",
	handler = SellOMatic,
	type = "group",
	args = {
		general = {
			type = "group",
			name = L["General Options"],
			guiInline = true,
			args = {
				autoSell = {
					name = L["Auto sell"],
					desc = L["Toggles auto sell mode"],
					order = 1,
					type = "select",
					values = {
						["NONE"] = L["No auto sell"],
						["JUNK"] = L["Auto sell junk"],
						["ALL"] = L["Auto sell all"],
					},
					style = "dropdown",
					get = getOption,
					set = setOption,
				},
				showFullInfo = {
					name = L["Information type"],
					desc = L["Choose the amount of information displayed"],
					order = 2,
					type = "select",
					values = {
						["1-FULL"] = L["FULL"],
						["2-LITE"] = L["LITE"],
					},
					style = "dropdown",
					get = getOption,
					set = setOption,
				},
				preview = {
					name = L["Preview"],
					desc = L["Toggles ON/OFF preview before sell"],
					order = 3,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
				safe_mode = {
					name = L["Safe Mode"],
					desc = L["Toggles ON/OFF the safe mode (won't sell more than 12 items)"],
					order = 5,
					type = "toggle",
					get = getOption,
					set = setOption,
				},
			},
		},
		showlist = {
			name = "showlist",
			hidden = true,
			type = "execute",
			func = "ShowSOMList",
		},
		destroy = {
			name = "destroy",
			hidden = true,
			type = "input",
			set = "CallDestroyJunk",
			get = false,
		},
		dump = {
			name = "dump",
			hidden = true,
			type = "execute",
			func = "DumpVars",
		},
		addItem = {
			name = "addItem",
			hidden = true,
			type = "execute",
			func = "CallAddItem",
		},
		delItem = {
			name = "delItem",
			hidden = true,
			type = "execute",
			func = "CallDelItem",
		},
		resetlist = {
			name = "resetList",
			hidden = true,
			type = "execute",
			func = "CallResetList",
		},
		help = {
			name = "help",
			hidden = true,
			type = "execute",
			func = "ShowHelp",
		},
	},
}

local defaults = {
	profile = {
		-- CORE
		autoSell = "NONE",
		preview = true,
		showFullInfo = "1-FULL",
		safe_mode = true,
		-- ITEM
		item_allowWhite = false,
		item_allowGreen = false,
		item_allowBlue = false,
		item_allowEpic = false,
		item_allowBoP = false,
		item_allowBoE = false,
		item_iLevelValue = 1,
		item_useILevel = false,
		-- LIST
		sellList = {},
		saveList = {},
		caseSensitiveList = false,
		list_allowBoP = false,
		list_allowBoE = false,
		list_allowWhite = false,
		list_allowGreen = false,
		list_allowBlue = false,
		list_allowEpic = false,
		list_useILevel = false,
		list_iLevelValue = 1,
		-- DESTROY
		destroy_warning = true,
		-- CLASS
		class_filter_strict = false,
		-- New item defaults
		item_white_enable = false,
		item_white_ilevel = false,
		item_white_ilevel_value = 1,
		item_green_enable = false,
		item_green_bop = false,
		item_green_boe = false,
		item_green_ilevel = false,
		item_green_ilevel_value = 1,
		item_blue_enable = false,
		item_blue_bop = false,
		item_blue_boe = false,
		item_blue_ilevel = false,
		item_blue_ilevel_value = 1,
		item_epic_enable = false,
		item_epic_bop = false,
		item_epic_boe = false,
		item_epic_ilevel = false,
		item_epic_ilevel_value = 1,
	},
}

local command_list = {
	name = L["Command List"],
	type = "group",
	args = {
		command_header = {
			name = "Sell-O-Matic Command List",
			type = "header",
			order = 1,
		},
		command_description = {
			name = "|cffffd700/som|r".." "..L["display the addon options"]..".".."|n"..
					"|cffffd700/som help|r".." "..L["display these commands"]..".".."|n"..
					"|cffffd700/som showlist|r".." "..L["display the contents of the sell and save lists"]..".".."|n"..
					"|cffffd700/som additem|r".." "..L["add items to the sell/save lists"]..".".."|n"..
					"|cffffd700/som delitem|r".." "..L["delete items from the sell/save lists"]..".".."|n"..
					"|cffffd700/som resetlist|r".." "..L["resets the save/sell list"]..".".."|n"..
					"|cffffd700/som destroy|r".." "..L["destroy all junk items in your backpack"]..".".."|n"..
					"|cffffd700/som destroy x|r".. " "..L["destroy x junk items, where x is the number of items to destroy"]..".",
			type = "description",
			fontSize = "medium",
			order = 2,
		},
	},
}

local modules = { destroy = 1, list = 1, item = 1 , class = 0 }
-- item_container: Name, Link, Rarity, Level, Price, Stack, Amount
local shopping_list, SOMPreview, duplicates, check_preview, cash_flow, init_cash, merchant
local _, bag, slot, name, itemName, itemLink, itemRarity, itemSellPrice, itemStackCount, itemLevel

function SellOMatic:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SellOMatic2DB", defaults, "Default")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SellOMatic", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SellOMatic", "Sell-O-Matic")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SellOMatic_Command", command_list)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SellOMatic_Command", L["Command List"], "Sell-O-Matic")
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(L["Profile Options"], profiles)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(L["Profile Options"], L["Profile Options"], "Sell-O-Matic")
	self:RegisterChatCommand("sellomatic", "ChatCommand")
	self:RegisterChatCommand("som", "ChatCommand")
end

function SellOMatic:OnEnable()
	local SOM_List = LoadAddOn("SellOMatic2_List")
	if not SOM_List then modules.list = 0 end
	local SOM_Item = LoadAddOn("SellOMatic2_Item")
	if not SOM_Item then modules.item = 0 end
	local SOM_Destroy = LoadAddOn("SellOMatic2_Destroy")
	if not SOM_Destroy then modules.destroy = 0 end
	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterEvent("MERCHANT_CLOSED")
	self:RegisterEvent("BAG_UPDATE_DELAYED")
	SellButton:Hide()
	shopping_list = {}
	merchant = false
	if MerchantFrame:IsShown() then SellOMatic:MERCHANT_SHOW() end
end

function SellOMatic:ChatCommand(input)
	if not input or input:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(SellOMatic, "sellomatic", "SellOMatic", input)
	end
end

function SellOMatic:MERCHANT_SHOW()
	if merchant == false then
		merchant = true
		SellButton:Show()
		SellOMatic:AttachToMerchant()
		if modules.list == 1 then SellOMatic:ShowButtonFrame() end
		if modules.class == 1 then SellOMatic:CheckVariables() end
		if SellOMatic.db.profile.autoSell == "ALL" then
			SellOMatic:Autosell()
		else
			SellOMatic:Autosell()
			SellOMatic:Scan()
		end
	end
end

function SellOMatic:MERCHANT_CLOSED()
	if merchant == true then
		merchant = false
		SellButton:Hide()
		if modules.list == 1 then SellOMatic:HideButtonFrame() end
		SellOMatic:SetPreview(0)
		SellOMatic:SOMNone("hide")
		SOMDynamic:Hide()
		SellOMatic:Clean_Shopping_List()
	end
end

function SellOMatic:BAG_UPDATE_DELAYED()
	if merchant == true then
		SellOMatic:Clean_Shopping_List()
		SellOMatic:Scan()
	end
end

function SellOMatic:Autosell()
	init_cash = GetMoney()
	if SellOMatic.db.profile.autoSell == "JUNK" then
		if SellOMatic.db.profile.showFullInfo == "1-FULL" then SellOMatic:Print("-- "..L["Autoselling junk"].." --") end
		SellOMatic:Scan_Junk()
		SellOMatic:Sell("junk")
	elseif SellOMatic.db.profile.autoSell == "ALL" then
		if SellOMatic.db.profile.showFullInfo == "1-FULL" then SellOMatic:Print("-- "..L["Autoselling"].." --") end
		SellOMatic:Scan()
		SellOMatic:Sell()
	end
end

function SellOMatic:Sell(type)
	if #shopping_list ~= 0 and type == "junk" and SellOMatic.db.profile.safe_mode then
		SellOMatic:Sell_Shopping_List()
		SellOMatic:Scan()
	elseif #shopping_list ~= 0 and type == "junk" and not SellOMatic.db.profile.safe_mode then
		SellOMatic:Sell_Shopping_List()
		SellOMatic:SOMNone("show")
		SellOMatic:Clean_Shopping_List()
	elseif #shopping_list ~= 0 and type ~= "junk" then
		if SellOMatic.db.profile.preview and check_preview ~= 1 then
			SellOMatic:Preview_Shopping_List(shopping_list)
			SellOMatic:SOMPreview_Show()
		elseif SellOMatic.db.profile.safe_mode then
			SellOMatic:Sell_Shopping_List()
			SellOMatic:Scan()
		else
			SellOMatic:Sell_Shopping_List()
			SellOMatic:SOMNone("show")
			SellOMatic:Clean_Shopping_List()
		end
	end
end

function SellOMatic:Scan()
	-- Reset preview switch every time Scan() is called - Ticket #45
	SellOMatic:SetPreview(0)
	SellOMatic:Scan_Junk()
	if modules.item == 1 then SellOMatic:Scan_Item() end
	if modules.class == 1 then SellOMatic:Scan_Class() end
	if modules.list == 1 then SellOMatic:Scan_List() end
	if merchant and #shopping_list == 0 then
		SellOMatic:SOMNone("show")
	else
		SellOMatic:SOMNone("hide")
	end
end

function SellOMatic:Scan_Junk()
	for bag = 0,NUM_BAG_SLOTS,1 do
		for slot = 1, GetContainerNumSlots(bag), 1 do
			local texture, itemCount, _, quality, _, _, itemLink, _ = GetContainerItemInfo(bag, slot);
			if texture ~= nil and quality == 0 then
				local itemName, _, _, itemLevel, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink);
				itemSellPrice = itemSellPrice * itemCount;
				SellOMatic:Add_Shopping_List(itemName,itemLink,quality,itemLevel,itemSellPrice,itemCount)
			end
		end
	end
end

function SellOMatic:Sell_Shopping_List()
	local i
	local num = 0
	local profit = SellOMatic:ShowProfit()
	if SellOMatic:CheckMerchant() then
		for bag = 0,NUM_BAG_SLOTS,1 do
			for slot = 1, GetContainerNumSlots(bag), 1 do
				local texture, _, _, _, _, _, itemLink, _ = GetContainerItemInfo(bag, slot);
				if texture ~= nil then
					local itemName, itemLink, itemRarity, _, _, _, _, _, _, _, _ = GetItemInfo(itemLink);
					for i = 1, #shopping_list, 1 do
						if shopping_list[i][1] == itemName and shopping_list[i][3] == itemRarity then
							-- Safe Mode: Don't sell if you've already sold 12 items
							if SellOMatic.db.profile.safe_mode and num >= 12 then break end
							if not CursorHasItem() then
								-- Sell item
								UseContainerItem(bag,slot)
								if SellOMatic.db.profile.showFullInfo == "1-FULL" then SellOMatic:Print(L["Selling"]..": "..itemLink) end
								num = num + 1
							end
						end
					end
				end
			end
		end
		if SellOMatic.db.profile.showFullInfo == "1-FULL" then
			SellOMatic:Print(num.." "..L["item(s) sold"])
			cash_flow = GetMoney() - init_cash
			if cash_flow > profit then
				profit = cash_flow
			end
			SellOMatic:Print(L["You've earned"]..": "..GetCoinText(profit," "))
		else
			SellOMatic:Print(num.." "..L["item(s) sold for"].." "..GetCoinTextureString(profit))
		end
	end
end

function SellOMatic:Add_Shopping_List(name,link,rarity,level,price,stack)
	local x
	local found = 0
	if price > 0 and #shopping_list > 1 then
		for x=1, #shopping_list, 1 do
			if shopping_list[x][1] == name then
				found = 1
				shopping_list[x][5] = shopping_list[x][5] + price
				shopping_list[x][6] = shopping_list[x][6] + stack
				shopping_list[x][7] = shopping_list[x][7] + 1
			end
		end
	end
	if price > 0 and #shopping_list == 0 or price > 0 and found == 0 then
		shopping_list[#shopping_list+1] = { name,link,rarity,level,price,stack,1 }
	end
end

function SellOMatic:Del_Shopping_List(index)
	table.remove(shopping_list, index)
end

function SellOMatic:Get_Shopping_List()
	return shopping_list
end

function SellOMatic:ShowProfit()
	local profit = 0
	local x
	for x=1, #shopping_list, 1 do
		profit = profit + shopping_list[x][5]
	end
	return profit
end

function SellOMatic:Clean_Shopping_List()
	shopping_list = {}
end

function SellOMatic:CheckMerchant()
	local items = GetMerchantNumItems()
	if merchant and items > 0 then
		return true
	else
		return false
	end
end

function SellOMatic:CallDestroyJunk(x,arg1)
	if modules.destroy == 1 then
		if arg1 ~= nil and arg1 ~= "" then
			SellOMatic:ScanXJunk(arg1)
		else
			SellOMatic:DestroyJunk()
		end
	end
end

function SellOMatic:ShowSOMList()
	if modules.list == 1 then
		SellOMatic:ShowList()
	end
end

function SellOMatic:CallAddItem()
	if modules.list == 1 then
		SellOMatic:AddItem()
	end
end

function SellOMatic:CallDelItem()
	if modules.list == 1 then
		SellOMatic:DelItem()
	end
end

function SellOMatic:CallResetList()
	if modules.list == 1 then
		SellOMatic:ResetList()
	end
end

function SellOMatic:EmptyList(list)
	if list == "sell" then
		SellOMatic.db.profile.sellList = {}
		SellOMatic:Print(L["Sell List"].." "..L["has been reset"]..".")
	end
	if list == "save" then
		SellOMatic.db.profile.saveList = {}
		SellOMatic:Print(L["Save List"].." "..L["has been reset"]..".")
	end
end

function SellOMatic:SetPreview(value)
	check_preview = value
end

function SellOMatic:ShowHelp()
	SellOMatic:Print(L["Command List"])
	print("|cffffd700/som|r".." "..L["display the addon options"])
	print("|cffffd700/som help|r".." "..L["display these commands"])
	print("|cffffd700/som showlist|r".." "..L["display the contents of the sell and save lists"])
	print("|cffffd700/som additem|r".." "..L["add items to the sell/save lists"])
	print("|cffffd700/som delitem|r".." "..L["delete items from the sell/save lists"])
	print("|cffffd700/som resetlist|r".." "..L["resets the save/sell list"])
	print("|cffffd700/som destroy|r".." "..L["destroy all junk items in your backpack"])
	print("|cffffd700/som destroy x|r".. " "..L["destroy x junk items, where x is the number of items to destroy"])
end
