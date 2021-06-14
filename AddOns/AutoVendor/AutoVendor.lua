AV = LibStub("AceAddon-3.0"):NewAddon("AutoVendor", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("AutoVendor")

local options = {
  name = "AutoVendor",
  handler = AV,
  type = 'group',
  args = {
  	enable = {
  		type = 'toggle',
  		order = 1,
  		name = L['Autovendor enabled'],
  		desc = L['Autovendor enabled description'],
  		set = function(info, val) if (val) then AV:Enable() else AV:Disable() end end,
  		get = function(info) return AV.enabledState end,
  	},
  	empty = {
  		type = 'header',
  		order = 2,
  		cmdHidden = true,
  		dropdownHidden = true,
  		name = L['Sales header'],
  	},
    soulbound = {
    	type = 'toggle',
    	order = 3,
    	name = L['Sell unusable'],
    	desc = L['Sell unusable description'],
    	disabled = function() return not AV.enabledState end,
    	set = function(info, val) AV.db.profile.soulbound = val; AV:ResetJunkCache() end,
    	get = function(info) return AV.db.profile.soulbound end,
    	width = 'full',
    	confirm = function(info, val) if val then return L['Sell unusable confirmation'] else return false end end,
    },
    nonoptimal = {
    	type = 'toggle',
    	order = 4,
    	name = L['Sell non-optimal'],
    	desc = L['Sell non-optimal description'],
    	disabled = function() return not AV.enabledState end,
    	set = function(info, val) AV.db.profile.nonoptimal = val; AV:ResetJunkCache() end,
    	get = function(info) return AV.db.profile.nonoptimal end,
    	width = 'full',
    	confirm = function(info, val) if val then return L['Sell non-optimal confirmation'] else return false end end,
    },
    legionArtifactRelics = {
    	type = 'toggle',
    	order = 4,
    	name = L['Sell Legion artifact relics'],
    	desc = L['Sell legion artifact relics description'],
    	disabled = function() return not AV.enabledState end,
    	set = function(info, val) AV.db.profile.selllegionartifact = val; AV:ResetJunkCache() end,
    	get = function(info) return AV.db.profile.selllegionartifact end,
    	width = 'full'
    },
    fortunecards = { 
    	type = 'toggle',
    	order = 5,
    	name = L['Sell cheap fortune cards'],
    	desc = L['Sell cheap fortune cards description'],
    	disabled = function() return not AV.enabledState end,
    	set = function(info, val) AV.db.profile.sellfortunecards = val; AV:ResetJunkCache() end,
    	get = function(info) return AV.db.profile.sellfortunecards end,
    	width = 'full',
    },
	selllowlevelitems = {
		type = 'toggle',
		order = 6,
		name = L['Sell low level'],
		desc = L['Sell low level description'],
		set = function(info, val) AV.db.profile.selllowlevelitems = val; AV:ResetJunkCache() end,
		get = function(info) return AV.db.profile.selllowlevelitems end,
		disabled = function() return not AV.enabledState end,
		width = 'full',
    	confirm = function(info, val) if val then return L['Sell low level confirmation'] else return false end end,
	},
	sellbelowitemlevel = {
		type = 'range',
		order = 7,
		name = L['Sell items below'],
		desc = L['Sell items below description'],
		set = function(info, val) AV.db.profile.sellbelowitemlevel = val; AV:ResetJunkCache() end,
		get = function(info) return AV.db.profile.sellbelowitemlevel end,
		disabled = function() return not AV.enabledState or not AV.db.profile.selllowlevelitems end,
		width = 'full',
		min = 2,
		max = 1000,
		step = 1,
		bigStep = 5,
	},
    verbosity = {
      type = 'select',
      order = 8,
      name = L['Verbosity'],
      desc = L['Verbosity description'],
      disabled = function() return not AV.enabledState end,
      values = {
      	none = L['Verbosity none'],
      	summary = L['Verbosity summary'],
      	all = L['Verbosity all'],
      },
      set = 'SetVerbosity',
      get = 'GetVerbosity',
    },
  	empty2 = {
  		type = 'header',
  		order = 9,
  		cmdHidden = true,
  		dropdownHidden = true,
  		name = L['Auto repair'],
  	},
    autorepair = {
    	type = 'toggle',
    	order = 10,
    	name = L['Auto repair'],
    	desc = L['Auto repair description'],
    	disabled = function() return not AV.enabledState end,
    	set = function(info, val) AV.db.profile.autorepair = val end,
    	get = function(info) return AV.db.profile.autorepair end,
    	width = 'full',
    },
    guildbankrepair = {
    	type = 'toggle',
    	order = 11,
    	name = L['Auto repair guild bank'],
    	desc = L['Auto repair guild bank description'],
    	disabled = function() return not AV.enabledState or not AV.db.profile.autorepair end,
    	set = function(info, val) AV.db.profile.guildbankrepair = val end,
    	get = function(info) return AV.db.profile.guildbankrepair end,
    	width = 'full',
    },
    junk = {
    	type = 'input',
    	name = L['Toggle junk'],
    	desc = L['Toggle junk description'],
    	guiHidden = true,
    	dialogHidden = true,
    	dropdownHidden = true,
    	get = function() return listFormatWithoutPrint(AV.db.profile.junk) end,
    	set = function(info, val) AV:ToggleJunk(val, editbox) end,
    },
    notjunk = {
    	type = 'input',
    	name = L['Toggle NotJunk'],
    	desc = L['Toggle NotJunk description'],
    	guiHidden = true,
    	dialogHidden = true,
    	dropdownHidden = true,
    	get = function() return listFormatWithoutPrint(AV.db.profile.notjunk) end,
    	set = function(info, val) AV:ToggleNotJunk(val, editbox) end,
    },
	debug = {
		type = 'input',
		name = L['Debug'],
		desc = L['Debug description'],
		guiHidden = true,
		dialogHidden = true,
		dropdownHidden = true,
		get = function() return -1 end,
		set = function(info, val) AV:Debug(val, editbox) end,
	}
  },
}

local defaults = {
	profile = {
		verbosity = 'summary',
		autorepair = true,
		guildbankrepair = false,
		soulbound = false,
		sellnonoptimal = false,
		selllegionartifact = false,
		sellfortunecards = false,
		selllowlevelitems = false,
		sellbelowitemlevel = 2,
		not_junk = {
			[1485] = "Pitchfork",
			[39202] = "Rusted Pitchfork",
			[3944] = "Twill Belt",
			[3945] = "Twill Boots",
			[3946] = "Twill Bracers",
			[3947] = "Twill Cloak",
			[8754] = "Twill Cover",
			[3948] = "Twill Gloves",
			[3949] = "Twill Pants",
			[3950] = "Twill Shoulderpads",
			[3951] = "Twill Vest",
			[18230] = "Broken I.W.I.N. Button",
			[33820] = "Weather-Beaten Fishing Hat",
			[38506] = "Don Carlos' Famous Hat",
			[116913] = "Peon's Mining Pick",
			[116916] = "Gorepetal's Gentle Grasp",
			[113547] = "Bouquet of Dried Flowers",
			[168804] = "Powered Piscine Procurement Pole",
			[86125] = "Kafa Press",
			[19969] = "Nat Pagle's Extreme Anglin' Boots",
			[88710] = "Nat's Hat",
			[155459] = "Anglin' Art's Sandals",
			[155484] = "Anglin' Art's Stompers",
			[155476] = "Anglin' Art's Waders",
			[155468] = "Anglin' Art's Treads",
			[19970] = "Arcanite Fishing Pole",
			[19979] = "Hook of the Master Angler",
			[133755] = "Underlight Angler",
			[180136] = "The Brokers Angle\'r"
		},
		junk = {
		},
	}
}

local updateBrokerDisplay = true
local totalSellValue = 0.0
local numSlots = 0
local itemsBOP = {} -- caching items so we don't have to scan tooltips all the time
local itemsUseEquip = {} -- caching items which have a Use: or Equip: tag so we don't have to scan tooltips all the time
local itemsJunk = {} -- caching which items are junk
local cheapestJunkItem = {}

function AV:ResetJunkCache()
	itemsJunk = {}
	cheapestJunkItem = {}
	updateBrokerDisplay = true
end

function AV:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("AutoVendorDB", defaults)
	local parent = LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoVendor", options, {"autovendor", "av"})
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AutoVendor", "AutoVendor")
	profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoVendor.profiles", profiles)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AutoVendor.profiles", "Profiles", "AutoVendor")

	local UPDATEPERIOD, elapsed = 1, 0
	local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
	if ldb then
		local avDataObj = ldb:NewDataObject("AutoVendor", {type = "data source", text = "AutoVendor", icon = "Interface\\Icons\\Inv_Misc_MonsterScales_08"})
		local avF = CreateFrame("frame")
	
		avF:SetScript("OnUpdate", function(self, elap)
			elapsed = elapsed + elap
			if elapsed < UPDATEPERIOD then return end
		
			elapsed = 0
			local iconSize = select(2, GetChatWindowInfo(1)) - 2
			local repairCost = GetRepairAllCost()
			if repairCost >= 100 then
				repaircost = math.floor(repairCost / 100) * 100
			end
			if updateBrokerDisplay then
				totalSellValue, numSlots = AV:GetJunkAmount()
				if totalSellValue >= 100 then
					totalSellValue = math.floor(totalSellValue / 100) * 100
				end
				updateBrokerDisplay = false
			end
			avDataObj.text = "Repair: "..GetCoinTextureString(repairCost, iconSize).." / Junk: "..GetCoinTextureString(totalSellValue, iconSize).." ("..numSlots.." slots)"
			avDataObj.label = "AutoVendor"
		end)
	end
end

function AV:Debug(val, editbox)
	self:Print('Loaded language: ' .. L["Loaded language"])
	self:Print('Player class: "' .. select(1, UnitClass('player')) .. '"')
	self:Print('Player level: ' .. select(1, UnitLevel('player')))

	if val:len() < 10 then
		self:Print('Add an item link to the debug statement to get information about that item.')
		return
	end
	
	self:Print('Showing information about: ' .. val)

	local link = GetItemInfo(val)
	local _, _, itemQuality, _, _, _, _, _, itemEquipLoc, _, _, itemClassId, itemSubClassId = GetItemInfo(link)
	local itemLevel = GetDetailedItemLevelInfo(link)
	
	if itemQuality then
		self:Print('Item quality: "' .. itemQuality .. '"')
	end
	if itemLevel then
		self:Print('Item level: ' .. itemLevel)
	end
	if itemClassId then
		self:Print('Item Class ID: ' .. itemClassId)
	end
	if itemSubClassId then
		self:Print('Item Subclass ID: ' .. itemSubClassId)
	end
	if itemEquipLoc then
		self:Print('Item equip location: "' .. itemEquipLoc .. '"')
	end
end

function AV:GetJunkAmount()
	local totalSellValue = 0
	local numSlots = 0
	
	for bag=0,4 do
		for slot=1,GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link and AV:IsJunk(link) then
				local itemCount = select(2, GetContainerItemInfo(bag, slot))
				if itemCount then
					local vendorWorth = select(11, GetItemInfo(link))
					if vendorWorth then
						local sellValue = itemCount * vendorWorth
						if sellValue > 0 then
							numSlots = numSlots + 1
							totalSellValue = totalSellValue + sellValue
						end

						if cheapestJunkItem["link"] == nil or cheapestJunkItem["price"] > sellValue then
							cheapestJunkItem["link"] = link
							cheapestJunkItem["price"] = sellValue
							cheapestJunkItem["bag"] = bag
							cheapestJunkItem["slot"] = slot
						end
					end
				end
			end
		end
	end
	
	return totalSellValue, numSlots
end

function AV:OnEnable()
	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterChatCommand("junklist", "JunkList")
	self:RegisterChatCommand("notjunklist", "NotJunkList")
	self:RegisterChatCommand("junk", "ToggleJunk")
	self:RegisterChatCommand("notjunk", "ToggleNotJunk")
	self:RegisterChatCommand("dropcheapest", "DropCheapest")
end

function AV:OnDisable()
end

function AV:SetVerbosity(info, val)
	self.db.profile.verbosity = val
	self:Print("Setting verbosity level to '"..val.."'.")
end

function AV:GetVerbosity(info)
	return self.db.profile.verbosity
end

local function listFormatWithoutPrint(list)
	local tmpList = {}
	for _,v in pairs(list) do
		table.insert(tmpList, v)
	end
	table.sort(tmpList)
	tmpString = ''
	for k,v in pairs(list) do
		local item_link = select(2, GetItemInfo(k))
		if item_link == nil then
			item_link = v
		end
		if #tmpString > 0 and #tmpString + #item_link <= 255 then
			tmpString = tmpString .. ', ' .. item_link
		else
			if #tmpString == 0 then
				tmpString = item_link
			else
				AV:Print(tmpString)
				tmpString = item_link
			end
		end
	end
	return tmpString
end

local function listFormat(list)
	tmpString = listFormatWithoutPrint(list)
	if #tmpString ~= 0 then
		AV:Print(tmpString)
	end
end

local function listRemove(list, item)
	found = false
	for k,v in pairs(list) do
		if string.lower(v) == string.lower(item) then
			list[k] = nil
			found = true
		end
	end
	return found
end

local function listToggle(list, listName, itemId, itemName)
	if list[itemId] then
		list[itemId] = nil
		AV:Print(string.format(L['Removed from list'], itemName, listName))
	else
		table.insert(list, itemId, itemName)
		AV:Print(string.format(L['Added to list'], itemName, listName))
	end
end

function AV:ToggleJunk(msg, editbox)
	if msg then
		self:ResetJunkCache()
		local itemId = tonumber(strmatch(msg, "item:(%d+)"))
		local itemName = select(1, GetItemInfo(msg))
		if itemId and itemName then
			listToggle(self.db.profile.junk, 'junk list', itemId, itemName)
		else
			if msg and listRemove(self.db.profile.junk, msg) then
				self:Print(string.format(L['Removed from list'], msg, 'junk list'))
			else
				self:Print(L['No item link'])
			end
		end
	else
		self:Print(L['No item link'])
	end
end

function AV:ToggleNotJunk(msg, editbox)
	if msg then
		self:ResetJunkCache()
		local itemId = tonumber(strmatch(msg, "item:(%d+)"))
		local itemName = select(1, GetItemInfo(msg))
		if itemId and itemName then
			listToggle(self.db.profile.not_junk, 'not junk list', itemId, itemName)
		else
			if msg and listRemove(self.db.profile.not_junk, msg) then
				self:Print(string.format(L['Removed from list'], msg, 'not junk list.'))
			else
				self:Print(L['No item link'])
			end
		end
	else
		self:Print(L['No item link'])
	end
end

function AV:JunkList(msg, editbox)
	local empty = true
	for _,_ in pairs(self.db.profile.junk) do
		empty = false
	end
	if empty then
		self:Print(L['Junk list empty'])
	else
		self:Print(L['Items in junk list'])
	end
	listFormat(self.db.profile.junk)
end

function AV:NotJunkList(msg, editbox)
	local empty = true
	for _,_ in pairs(self.db.profile.not_junk) do
		empty = false
	end
	if empty then
		self:Print(L['Not-junk list empty'])
	else
		self:Print(L['Items in not-junk list'])
	end
	listFormat(self.db.profile.not_junk)
end

function AV:DropCheapest(msg, editbox)
	if cheapestJunkItem["link"] ~= nil then
		self:Print(string.format(L['Throwing away'], cheapestJunkItem["link"]))
		if not CursorHasItem() then
			PickupContainerItem(cheapestJunkItem["bag"], cheapestJunkItem["slot"])
			DeleteCursorItem()
		end
	else 
		self:Print(L['No junk to throw away'])
	end
end

function AV:IsJunk(link)
	local itemId = tonumber(strmatch(link, "item:(%d+)"))
	
	if itemId == nil then
		return false
	else
		if itemsJunk[itemId] == nil then
			itemsJunk[itemId] = self:ShouldSell(link)
		end
		
		return itemsJunk[itemId]
	end
end

function AV:ShouldSell(link)
	local itemId = tonumber(strmatch(link, "item:(%d+)"))
	local itemName, _, itemQuality, _, _, _, _, _, itemEquipLoc, _, _, itemClassId, itemSubClassId = GetItemInfo(link)
	local itemLevel = GetDetailedItemLevelInfo(link)
	
	-- Noboru's Cudgel
	if itemId == 6196 then 
		return false 
	end 
	
	-- Peon's Mining Pick
	if itemId == 116913 then
		return false
	end
	
	-- Don't sell legendary, artifact or heirloom items
	if itemQuality and itemQuality > 4 then
		return false
	end
	
	-- item is in the "always sell" list
	if self.db.profile.junk[itemId] then
		return true
	end
	
	-- item is in the "never sell" list
	if self.db.profile.not_junk[itemId] then
		return false
	end
	
	if self.db.profile.sellfortunecards and AV_FORTUNE_CARDS[itemId] == true then
		return true
	end

	if self.db.profile.selllegionartifact and itemClassId == LE_ITEM_CLASS_GEM and itemSubClassId == LE_ITEM_GEM_ARTIFACTRELIC then
		return true
	end
	
	-- item is level 1, don't sell
	if itemLevel == 1 and itemQuality ~= 0 then
		return false
	end
	
	if itemsBOP[itemId] == nil or itemsUseEquip[itemId] == nil then
		local soulbound, useEquip = self:GetTooltipInfo(link)
		itemsBOP[itemId] = soulbound
		itemsUseEquip[itemId] = useEquip
	end
	
	local _,class = UnitClass('player')

	if itemClassId == LE_ITEM_CLASS_WEAPON or itemClassId == LE_ITEM_CLASS_ARMOR then
		-- sell items below a certain item level 
		if itemsBOP[itemId] and not itemsUseEquip[itemId] and AV.db.profile.selllowlevelitems and itemLevel < AV.db.profile.sellbelowitemlevel then
			return true
		end
			
		-- sell unusable soulbound items
		if self.db.profile.soulbound then
			-- sell unusable items
			if itemsBOP[itemId] and AV:CannotUse(class, itemClassId, itemSubClassId) then
				return true
			end
		end
	end

	-- sell non-optimal soulbound items
	if self.db.profile.nonoptimal then
		local _,class = UnitClass('player')
		
		if itemClassId == LE_ITEM_CLASS_ARMOR and itemEquipLoc ~= 'INVTYPE_CLOAK' and itemsBOP[itemId] then
			if AV:NonOptimal(class, itemClassId, itemSubClassId) then
				return true
			end
		end
	end
	
	-- item is grey
	if itemQuality == 0 then
		return true
	else
		return false
	end
end

function AV:GetTooltipInfo(link)
	local soulbound = false
	local useEquip = false
	
	local f = CreateFrame('GameTooltip', 'AVTooltip', UIParent, 'GameTooltipTemplate')
	f:SetOwner(UIParent, 'ANCHOR_NONE')
	f:SetHyperlink(link)
	
	for i = 0,20 do
		local tooltipLine = _G['AVTooltipTextLeft' .. i]
		if tooltipLine ~= nil then
			local tooltipString = tooltipLine:GetText()
	
			if self:FindString(tooltipString, ITEM_BIND_ON_PICKUP) then
				soulbound = true
			end
			
			if self:FindString(tooltipString, USE_COLON) or self:FindString(tooltipString, L['Equip:']) then
				useEquip = true
			end
		end
	end
	
	f:Hide()
	
	return soulbound, useEquip
end

function AV:FindString(haystack, needle)
	if haystack == nil then 
		return false 
	end
	
	return string.find(haystack, needle)
end

function AV:MERCHANT_SHOW()
	local iconSize = select(2, GetChatWindowInfo(1)) - 2
	local totalSellValue = 0
	local totalItemsSold = 0
	local repairCost = 0
	local usedGuildBankRepair = false
	local warningShown = false

	if self.db.profile.autorepair and CanMerchantRepair() then
		repairCost, canRepair = GetRepairAllCost()
		if canRepair then
			if self.db.profile.guildbankrepair and CanGuildBankRepair() and GetGuildBankWithdrawMoney() >= repairCost then
				usedGuildBankRepair = true
				RepairAllItems(true)
			else
				RepairAllItems()
			end
		end
	end
	
	for bag=0,4 do
		for slot=1,GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local itemId = tonumber(strmatch(link, "item:(%d+)"))
				if AV:IsJunk(link) then
					if totalItemsSold == 12 then
						if not warningShown then
							self:Print(L['12 items sold'])
							warningShown = true
						end
					else
						local itemCount = select(2, GetContainerItemInfo(bag, slot))
						local sellValue = itemCount * select(11, GetItemInfo(link))
						if sellValue > 0 then
							totalSellValue = totalSellValue + sellValue
							totalItemsSold = totalItemsSold + 1
							UseContainerItem(bag, slot)
							if self.db.profile.verbosity == 'all' then
								self:Print(format(L['Selling x of y for z'], link, itemCount, GetCoinTextureString(sellValue, iconSize)))
							end
						else
							if self.db.profile.verbosity == 'all' then
								self:Print(format(L['Item has no vendor worth'], link))
							end
						end
					end
				end
			end
		end
	end
	
	if self.db.profile.verbosity == 'all' or self.db.profile.verbosity == 'summary' then
		if totalItemsSold > 0 then
			local items = L['Multiple items']
			if totalItemsSold == 1 then
				items = L['Single item']
			end
			self:Print(format(L['Summary sold x item(s) for z'], totalItemsSold, items, GetCoinTextureString(totalSellValue, iconSize)))
		end
		if repairCost > 0 then
			if usedGuildBankRepair then
				self:Print(format(L['Repaired all items for x from guild bank'], GetCoinTextureString(repairCost, iconSize)))
			else
				self:Print(format(L['Repaired all items for x'], GetCoinTextureString(repairCost, iconSize)))
			end
		end
	end
end

function AV:BAG_UPDATE()
	cheapestJunkItem = {}
	updateBrokerDisplay = true
end

function AV:CannotUse(class, itemClassId, itemSubClassId)
	for _,v in pairs(AV_UNUSABLE_ITEMS[class][itemClassId]) do
		if itemSubClassId == v then
			return true
		end
	end
	return false
end

function AV:NonOptimal(class, itemClassId, itemSubClassId)
	for _,v in pairs(AV_NON_OPTIMAL_ITEMS[class][itemClassId]) do
		if itemSubClassId == v then
			return true
		end
	end
	return false
end

-- Format: AV_UNUSABLE_ITEMS[class][itemClassId][itemSubClassId]
AV_UNUSABLE_ITEMS = {
	['DEATHKNIGHT'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_STAFF, LE_ITEM_WEAPON_UNARMED, LE_ITEM_WEAPON_DAGGER, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['DEMONHUNTER'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_STAFF, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_MACE1H },
	},
	['DRUID'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_AXE1H, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_SWORD1H, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['HUNTER'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_MACE1H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['MAGE'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_AXE1H, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_MACE1H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_UNARMED, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['MONK'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_DAGGER, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['PALADIN'] = {
		[LE_ITEM_CLASS_ARMOR] = { },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_STAFF, LE_ITEM_WEAPON_UNARMED, LE_ITEM_WEAPON_DAGGER, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['PRIEST'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_AXE1H, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_SWORD1H, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_UNARMED, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['ROGUE'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_STAFF, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['SHAMAN'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_PLATE },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_SWORD1H, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['WARLOCK'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL, LE_ITEM_ARMOR_PLATE, LE_ITEM_ARMOR_SHIELD },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_AXE1H, LE_ITEM_WEAPON_AXE2H, LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_MACE1H, LE_ITEM_WEAPON_MACE2H, LE_ITEM_WEAPON_POLEARM, LE_ITEM_WEAPON_SWORD2H, LE_ITEM_WEAPON_UNARMED, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_WARGLAIVE },
	},
	['WARRIOR'] = {
		[LE_ITEM_CLASS_ARMOR] = { },
		[LE_ITEM_CLASS_WEAPON] = { LE_ITEM_WEAPON_WAND, LE_ITEM_WEAPON_BOWS, LE_ITEM_WEAPON_GUNS, LE_ITEM_WEAPON_CROSSBOW, LE_ITEM_WEAPON_THROWN, LE_ITEM_WEAPON_WARGLAIVE },
	},
}

-- Format: AV_NON_OPTIMAL_ITEMS[class][itemClassId][itemSubClassId]
AV_NON_OPTIMAL_ITEMS = {
	['DEATHKNIGHT'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH, LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL },
	},
	['DEMONHUNTER'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH },
	},
	['DRUID'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH },
	},
	['HUNTER'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH, LE_ITEM_ARMOR_LEATHER },
	},
	['MAGE'] = {
		[LE_ITEM_CLASS_ARMOR] = { },
	},
	['MONK'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH },
	},
	['PALADIN'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH, LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL },
	},
	['PRIEST'] = {
		[LE_ITEM_CLASS_ARMOR] = { },
	},
	['ROGUE'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH },
	},
	['SHAMAN'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH, LE_ITEM_ARMOR_LEATHER },
	},
	['WARLOCK'] = {
		[LE_ITEM_CLASS_ARMOR] = { },
	},
	['WARRIOR'] = {
		[LE_ITEM_CLASS_ARMOR] = { LE_ITEM_ARMOR_CLOTH, LE_ITEM_ARMOR_LEATHER, LE_ITEM_ARMOR_MAIL },
	},
}

AV_FORTUNE_CARDS = { 
	[62590] = true,
	[60845] = true,
	[62606] = true,
	[60842] = true,
	[60841] = true,
	[62602] = true,
	[62603] = true,
	[62604] = true,
	[62605] = true,
	[60839] = true,
	[62598] = true,
	[62599] = true,
	[62600] = true,
	[62601] = true,
	[62246] = true,
	[62577] = true,
	[62578] = true,
	[62579] = true,
	[62580] = true,
	[62581] = true,
	[62582] = true,
	[62583] = true,
	[62584] = true,
	[62585] = true,
	[62586] = true,
	[62587] = true,
	[62588] = true,
	[62589] = true,
	[60843] = true,
	[62591] = true,
	[62247] = true,
	[62552] = true,
	[62553] = true,
	[62554] = true,
	[62555] = true,
	[62556] = true,
	[62557] = true,
	[62558] = true,
	[62559] = true,
	[62560] = true,
	[62561] = true,
	[62562] = true,
	[62563] = true,
	[62564] = true,
	[62565] = true,
	[62566] = true,
	[62567] = true,
	[62568] = true,
	[62569] = true,
	[62570] = true,
	[62571] = true,
	[62572] = true,
	[62573] = true,
	[62574] = true,
	[62575] = true,
	[62576] = true,
}
