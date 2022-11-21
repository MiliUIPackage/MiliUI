--[[
	tooltipCounts.lua
		Adds item counts to tooltips
]]--

local ADDON, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(ADDON)
local TipCounts = Addon:NewModule('TooltipCounts')

local SILVER = '|cffc7c7cf%s|r'
local FIRST_BANK_SLOT = NUM_BAG_SLOTS + NUM_REAGENTBAG_FRAMES + 1					--4 + 1 + 1
local LAST_BANK_SLOT = NUM_BAG_SLOTS + NUM_REAGENTBAG_FRAMES + NUM_BANKBAGSLOTS		--4 + 1 + 7
local TOTAL = SILVER:format(L.Total)


--[[ Startup ]]--

function TipCounts:OnEnable()
	
	if Addon.sets.tipCount then

	--[[ Classic
		GameTooltip:HookScript("OnTooltipCleared", self.OnClear)
		ItemRefTooltip:HookScript("OnTooltipSetItem", self.OnItemClassic)
		ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", self.OnItemClassic)
		ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", self.OnItemClassic)
		ShoppingTooltip1:HookScript("OnTooltipSetItem", self.OnItemClassic)
		ShoppingTooltip2:HookScript("OnTooltipSetItem", self.OnItemClassic)
	]]--
		
		hooksecurefunc(ItemRefTooltip, "SetHyperlink", self.OnItemRetail)
		hooksecurefunc(GameTooltip, 'SetQuestItem', self.OnItemRetail)
		hooksecurefunc(GameTooltip, 'SetQuestLogItem', self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetHyperlink", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetLootItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetLootRollItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetInboxItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetSendMailItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetMerchantItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetMerchantCostItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetBuybackItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetBagItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetInventoryItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetGuildBankItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetTradeTargetItem", self.OnItemRetail)
		hooksecurefunc(GameTooltip, "SetTradePlayerItem", self.OnItemRetail)
		
		
		--TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, self.OnTest)
		self.__tamedCounts = false
		
		if not self.Text then
			self.Text, self.Counts = {}, {}
		end
	end
end

--[[ Events ]]--
function TipCounts.OnClear(self)
	self.__tamedCounts = true
end

function TipCounts.OnTest(tip, arg1, arg2, arg3, arg4)

	
	
	if tip.info.append then 
		print(C_Item.GetItemLinkByGUID(tip.info.tooltipData.guid), tip.info.tooltipData.id)
		TipCounts:AddOwners(tip, C_Item.GetItemLinkByGUID(tip.info.tooltipData.guid), tip.info.tooltipData.id)
		print(tip.info.getterName, arg1)
		for k,v in pairs (tip.info.tooltipData) do
			print(k,v)
		end
	else
		--print(tip:GetItem())
	end
	
	if arg1 and type(arg1)=='table' and #arg1 > 0 then
		local txt = ''
		for i=1,#arg1 do
			txt = txt .. arg1[i] .. ', '
		end
		
		--print('arg1:', txt)
	end
	
	--local link = select(2, tip:GetItem())
	--TipCounts:AddOwners(tip, select(2, tip:GetItem()))
end

function TipCounts.OnItemRetail(tip, arg1, arg2, arg3, arg4)
	if not tip.info then return end --happens if twice click on item in chat
	
	if  not tip.info.append then 
		TipCounts:AddOwners(tip, select(2, tip:GetItem())) 
	else
		TipCounts:AddOwners(tip, C_Item.GetItemLinkByGUID(tip.info.tooltipData.guid), tip.info.tooltipData.id)
	end
end

function TipCounts.OnItemClassic(tip)
	if tip:GetObjectType() ~= 'GameTooltip' or tip:GetObjectType() ~= 'ShoppingTooltip1' or tip:GetObjectType() ~= 'ShoppingTooltip2'  then return end

	local name, link
	if tip == ShoppingTooltip1 or tip == ShoppingTooltip2 then
		if tip.info and tip.info.tooltipData and tip.info.tooltipData.guid then
			local guid = tip.info.tooltipData.guid
			link = C_Item.GetItemLinkByGUID(guid)
		else
			name, link = tip:GetItem()
		end
	else
		name, link = tip:GetItem()
	end
	
    if not link then
		return
	end

	if name ~= '' then
		TipCounts:AddOwners(tip, link)
	end
end

function TipCounts.OnQuest(tip)
	TipCounts:AddOwners(tip, select(2, tip:GetItem()))
end

function TipCounts.OnTradeSkill(api)
	return function(tip, recipeID, ...)
		TipCounts:AddOwners(tip, tonumber(recipeID) and C_TradeSkillUI[api](recipeID, ...))
	end
end

function TipCounts.OnSetLootItem(tip, slot)
	if LootSlotHasItem(slot) then
		local link = GetLootSlotLink(slot)
		TipCounts:AddOwners(tip, link)
	end
end

function TipCounts.OnSetLootRollItem(tip, slot)
	TipCounts:AddOwners(tip, GetLootRollItemLink(slot))
end

function TipCounts.OnSetInboxItem(tip, mailIndex, attIndex)
	TipCounts:AddOwners(tip, GetInboxItemLink(mailIndex, attIndex or 1))
end

function TipCounts.OnSetSendMailItem(tip, index)
		local name = GetSendMailItem(index)
        local _, link = GetItemInfo(name)
        TipCounts:AddOwners(tip, link)
end

function TipCounts.OnSetGuildBankItem(tip, tab, slot)
	TipCounts:AddOwners(tip, GetGuildBankItemLink(tab, slot))
end

function TipCounts.OnSetTradeTargetItem(tip, index)
	TipCounts:AddOwners(tip, GetTradeTargetItemLink(index))
end

function TipCounts.OnSetTradePlayerItem(tip, index)
	TipCounts:AddOwners(tip, GetTradePlayerItemLink(index))
end

function TipCounts.OnSetMerchantCostItem(tip, slot, costIndex)
	TipCounts:AddOwners(tip, select(3,GetMerchantItemCostItem(slot, costIndex)))
end

--[[ API ]]--

function TipCounts:AddOwners(tip, link, arg1, arg2, arg3) 
	if not Addon.sets.tipCount or not link then
		return
	end

	--local itemID = tonumber(link and GetItemInfo(link) and link:match('item:(%d+)')) -- Blizzard doing craziness when doing GetItemInfo
	local itemID = arg1 and arg1 or tip.info.tooltipData.id
	if not itemID then --Debug
		--print('return 1', link, tip.info.getterArgs, tip.info.getterName)
		return
	end

	--hearthstone items	
	if itemID == HEARTHSTONE_ITEM_ID or itemID == 140192 or itemID == 171253 then 
		return
	end

    local isBattlepet = string.match(link, ".*(battlepet):.*") == "battlepet"
    if isBattlepet then
        tip.__tamedCounts = true
        return
    end

	local players = 0
	local total = 0
	
	tip:AddLine(" ")
	
	for owner in Addon:IterateOwners() do
		local info = Addon:GetOwnerInfo(owner)
		local color = Addon.Owners:GetColorString(info)
		local count, text = self.Counts[owner] and self.Counts[owner][itemID]

		if count then
			text = self.Text[owner][itemID]
		else
			if not info.isguild then
				local equip = self:GetCount(owner, 'equip', itemID)
				local vault = self:GetCount(owner, 'vault', itemID)
				local bags, bank = 0,0

				if info.cached then
					for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
						bags = bags + self:GetCount(owner, i, itemID)
					end

					for i = FIRST_BANK_SLOT, LAST_BANK_SLOT do
						bank = bank + self:GetCount(owner, i, itemID)
					end

					if REAGENTBANK_CONTAINER then
						bank = bank + self:GetCount(owner, REAGENTBANK_CONTAINER, itemID)
					end

					bank = bank + self:GetCount(owner, BANK_CONTAINER, itemID)
				else
					local owned = GetItemCount(itemID, true)
					local carrying = GetItemCount(itemID)

					bags = carrying - equip
					bank = owned - carrying
				end

				count, text = self:Format(color, L.TipCountEquip, equip, L.TipCountBags, bags, L.TipCountBank, bank, L.TipCountVault, vault)
			elseif Addon.sets.countGuild then
				local guild = 0
				for i = 1, GetNumGuildBankTabs() do
					guild = guild + self:GetCount(owner, i, itemID)
				end

				count, text = self:Format(color, L.TipCountGuild, guild)
			else
				count = 0
			end

			if info.cached then
				self.Text[owner] = self.Text[owner] or {}
				self.Text[owner][itemID] = text
				self.Counts[owner] = self.Counts[owner] or {}
				self.Counts[owner][itemID] = count
			end
		end

		if count > 0 then
			tip:AddDoubleLine(Addon.Owners:GetIconString(info, 12,0,0) .. ' ' .. color:format(info.name), text)
			total = total + count
			players = players + 1
		end
	end

	if players > 1 and total > 0 then
		tip:AddDoubleLine(TOTAL, SILVER:format(total))
	end

	tip:Show()
end

function TipCounts:AddOwnersTEST(tip, link, arg1, arg2, arg3)
	
	if not Addon.sets.tipCount or not link then
		print('return 1', not Addon.sets.tipCount , not link)
		return
	end
  
	--local itemID = tonumber(link and GetItemInfo(link) and link:match('item:(%d+)')) -- Blizzard doing craziness when doing GetItemInfo
	local itemID = arg1 and arg1 or tip.info.tooltipData.id
	if not itemID then --Debug
		print('return 1', link, tip.info.getterArgs, tip.info.getterName)
		return
	end

	--hearthstone items	
	if itemID == HEARTHSTONE_ITEM_ID or itemID == 140192 or itemID == 171253 then 
		return
	end
	
    local isBattlepet = string.match(link, ".*(battlepet):.*") == "battlepet"
    if isBattlepet then
        tip.__tamedCounts = true
		print('return 3', isBattlepet)
        return
    end

	local players = 0
	local total = 0
	
	tip:AddLine(" ")
	
	for owner in Addon:IterateOwners() do
		local info = Addon:GetOwnerInfo(owner)
		local color = Addon.Owners:GetColorString(info)
		local count, text = self.Counts[owner] and self.Counts[owner][itemID]

		if count then
			text = self.Text[owner][itemID]
		else
			if not info.isguild then
				local equip = self:GetCount(owner, 'equip', itemID)
				local vault = self:GetCount(owner, 'vault', itemID)
				local bags, bank = 0,0

				if info.cached then
					for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
						bags = bags + self:GetCount(owner, i, itemID)
					end

					for i = FIRST_BANK_SLOT, LAST_BANK_SLOT do
						bank = bank + self:GetCount(owner, i, itemID)
					end

					if REAGENTBANK_CONTAINER then
						bank = bank + self:GetCount(owner, REAGENTBANK_CONTAINER, itemID)
					end

					bank = bank + self:GetCount(owner, BANK_CONTAINER, itemID)
				else
					local owned = GetItemCount(itemID, true)
					local carrying = GetItemCount(itemID)

					bags = carrying - equip
					bank = owned - carrying
				end

				count, text = self:Format(color, L.TipCountEquip, equip, L.TipCountBags, bags, L.TipCountBank, bank, L.TipCountVault, vault)
			elseif Addon.sets.countGuild then
				local guild = 0
				for i = 1, GetNumGuildBankTabs() do
					guild = guild + self:GetCount(owner, i, itemID)
				end

				count, text = self:Format(color, L.TipCountGuild, guild)
			else
				count = 0
			end

			if info.cached then
				self.Text[owner] = self.Text[owner] or {}
				self.Text[owner][itemID] = text
				self.Counts[owner] = self.Counts[owner] or {}
				self.Counts[owner][itemID] = count
			end
		end

		if count > 0 then
			tip:AddDoubleLine(Addon.Owners:GetIconString(info, 12,0,0) .. ' ' .. color:format(info.name), text)
			total = total + count
			players = players + 1
		end
	end

	if players > 1 and total > 0 then
		tip:AddDoubleLine(TOTAL, SILVER:format(total))
	end

	tip.__tamedCounts = true
	tip:Show()
end

function TipCounts:GetCount(owner, bag, id)
	local count = 0
	local info = Addon:GetBagInfo(owner, bag)

	for slot = 1, (info.count or 0) do
		if Addon:GetItemID(owner, bag, slot) == id then
			count = count + (Addon:GetItemInfo(owner, bag, slot).count or 1)
		end
	end

	return count
end

function TipCounts:Format(color, ...)
	local total, places = 0, 0
	local text = ''

	for i = 1, select('#', ...), 2 do
		local title, count = select(i, ...)
		if count > 0 then
			text = text .. L.TipDelimiter .. title:format(count)
			total = total + count
			places = places + 1
		end
	end

	text = text:sub(#L.TipDelimiter + 1)
	if places > 1 then
		text = color:format(total) .. ' ' .. SILVER:format('('.. text .. ')')
	else
		text = color:format(text)
	end

	return total, total > 0 and text
end
