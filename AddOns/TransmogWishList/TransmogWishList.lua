local _addonName, _addon = ...;

local TWL = LibStub("AceAddon-3.0"):NewAddon("TransmogWishlist");
local WARDROBE_MODEL_SETUP = {
	["INVTYPE_HEAD"] 		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true,  INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = false } },
	["INVTYPE_SHOULDER"]	= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_CLOAK"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_CHEST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_ROBE"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_TABARD"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_BODY"]		= { useTransmogSkin = true,  slots = { CHESTSLOT = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_WRIST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_HAND"]		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true,  INVTYPE_HAND = false, INVTYPE_LEGS = true,  INVTYPE_FEET = true, INVTYPE_HEAD = true } },
	["INVTYPE_WAIST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_LEGS"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_FEET"]		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true, INVTYPE_HAND = true, INVTYPE_LEGS = true,  INVTYPE_FEET = false, INVTYPE_HEAD = true } },	
}
local WARDROBE_MODEL_SETUP_GEAR = {
	["INVTYPE_CHEST"] = 78420,
	["INVTYPE_ROBE"] = 78420,
	["INVTYPE_LEGS"] = 78425,
	["INVTYPE_FEET"] = 78427,
	["INVTYPE_HAND"] = 78426,
	["INVTYPE_HEAD"] = 78416,
}

local _illusionSources = {
	[138787] = { -- Tome of Illusions: Azeroth
		["spell"] = 217151
		,["visuals"] = {25, 161, 27}
	}
	,[138790] = { -- Tome of Illusions: Northrend
		["spell"] = 217172
		,["visuals"] = {178, 172, 126}
	}
	,[138793] = { -- Tome of Illusions: Pandaria
		["spell"] = 217175
		,["visuals"] = {252, 236, 345}
	}
	,[138789] = { -- Tome of Illusions: Outland
		["spell"] = 217171
		,["visuals"] = {159, 160, 344}
	}
	,[138792] = { -- Tome of Illusions: Elemental Lords
		["spell"] = 217174
		,["visuals"] = {192, 195, 198}
	}
	,[138791] = { -- Tome of Illusions: Cataclysm
		["spell"] = 217173
		,["visuals"] = {193, 200, 213}
	}
	,[138794] = { -- Tome of Illusions: Secrets of the Shado-Pan
		["spell"] = 217177
		,["visuals"] = {237, 235}
	}
	,[138795] = { -- Tome of Illusions: Draenor
		["spell"] = 217180
		,["visuals"] = {283, 275}
	}
}

local FORMAT_TOOLTIP_NAME = "%s  |TInterface\\Addons\\TransmogWishList\\Images\\WishIcon:12|t";
local FORMAT_CHAT_ICON = "|TInterface\\Addons\\TransmogWishList\\Images\\WishIcon:12|t%s";
local FORMAT_MODID_SELECTED = "已選擇: |cFFFFD100%d|r ";
local FORMAT_MODPICKER_INFO = "物品 ID |cFFFFD100%d|r 共有 |cFFFFD100%d|r 個外觀模組，|n請選擇要加入願望清單的那一個。";
local FORMAT_APPEARANCE_ADDED = "|c%s%s|r 的外觀已加入願望清單";
TWL_INFO1 = [[可以透過下列方式加入外觀:

 - 在物品標籤頁面中，滑鼠指向尚未收集的外觀，然後點右上角的星星圖示。
 
 - 在套裝標籤頁面中，選擇一個套裝，然後點左上角的星星圖示。
 
 - 在本頁右上方的文字欄位中輸入物品 ID，然後按下 Enter 鍵。]]
TWL_SOUNDS = {
	["FX_Shimmer_Whoosh_Generic"] = 39672
	,["PickUpRing"] = 1193
	,["PutDownRing"] = 1210
}

local TWL_DEFAULTS = {
	global = {	
		wishList = {};
	}
}

local function ConvertOldData(wishList)
	local visualIDs = {};
	for k, item in ipairs(wishList) do
		if (item.visualID) then
			tinsert(visualIDs, item.visualID);
		end
	end
	wipe(wishList);
	for k, visualID in ipairs(visualIDs) do
		wishList[visualID] = true;
	end
end

function TWL:UpdateAllWishButtons()
	if (WardrobeCollectionFrame) then
		local models = WardrobeCollectionFrame.ItemsCollectionFrame.Models;
		
		for k, model in ipairs(models) do
			model.TWLWishButton:Update();
		end
	end
end

-----------------------------------------------------------------------
--	TooltipLine
-----------------------------------------------------------------------

local function AddTooltipLine(tooltip)
	local name, itemLink = tooltip:GetItem();
	-- If the tooltip doesn't have an itemLink, don't continue
	if (not itemLink) then return; end
	
	local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink);
	
	-- Check if the item appearance is on the wish list and not yet collected
	local itemInfo = TransmogWishListFrame.dataProvider:GetListItemByVisualID(appearanceID);

	if(itemInfo and not itemInfo.collected) then
		-- Add the wish list icon after the name
		local ttName = tooltip:GetName();
		local line = _G[ttName.."TextLeft"..1];
		local text = line:GetText();
		if(not text:find("|T")) then -- Prevent adding multiple times e.g. encounter journal
			line:SetText(FORMAT_TOOLTIP_NAME:format(text));
		end
	end
end

GameTooltip:HookScript("OnTooltipSetItem", AddTooltipLine);
GameTooltip.ItemTooltip.Tooltip:HookScript('OnTooltipSetItem', AddTooltipLine);
hooksecurefunc(GameTooltip, "SetHyperlink", AddTooltipLine);
ItemRefTooltip:HookScript("OnTooltipSetItem", AddTooltipLine);
ShoppingTooltip1:HookScript("OnTooltipSetItem", AddTooltipLine);

local wqthooked = false;
local function HookWQTTooltip()
	if (WQT_Tooltip and not wqthooked) then
		WQT_Tooltip.ItemTooltip.Tooltip:HookScript('OnTooltipSetItem', AddTooltipLine);
		wqthooked = true;
	end
end


-----------------------------------------------------------------------
--	TransmogWishListDataProviderMixin
-----------------------------------------------------------------------

TransmogWishListDataProviderMixin = {}

function TransmogWishListDataProviderMixin:OnLoad()
	self.wishList = {};
	self.waitingList = {}; -- For when data doesn't load right away
	self.lastAddition = nil;
	self.sourceInfo = {};
	self.dropInfo = {};
	self.recentlyChanged = {};
	self.recentUnlocks = {};
	self.recentLocks = {};
	self.illusions = {};
	for k, illusion in ipairs(C_TransmogCollection.GetIllusions()) do
		self.illusions[illusion.visualID] = illusion;
	end
end

function TransmogWishListDataProviderMixin:GetAppearanceSources(visualID, forceUpdate)
	local needsUpdate = false;
	local sources = self.sourceInfo[visualID];
	if (sources) then
		-- Check if all sources have their name loaded
		for k, source in ipairs(sources) do
			if (not source.name) then
				needsUpdate = true;
				break;
			end
		end
	else
		-- first time getting info
		self.sourceInfo[visualID] = {};
		sources = self.sourceInfo[visualID];
		needsUpdate = true;
	end

	if (needsUpdate or forceUpdate) then
		-- Clear out current source info
		wipe(sources);
		for k, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID)) do
			tinsert(sources, C_TransmogCollection.GetSourceInfo(sourceID));
		end
	end
	
	return sources;
end

function TransmogWishListDataProviderMixin:GetAppearanceSourceDrops(sourceID)
	if (not self.dropInfo[sourceID]) then
		self.dropInfo[sourceID] = C_TransmogCollection.GetAppearanceSourceDrops(sourceID);
	end
	
	return self.dropInfo[sourceID];
end

function TransmogWishListDataProviderMixin:Sort()
	if #self.wishList < 2 then return; end
	table.sort(self.wishList, function (a, b) 
			if a.collected ~= b.collected then
				return a.collected and not b.collected;
			end
			if a.obtainable ~= b.obtainable then
				return a.obtainable and not b.obtainable;
			end
			if not a.itemID or not b.itemID then
				return not a.itemID and b.itemID;
			end
			if a.isArmor ~= b.isArmor then
				return a.isArmor and not b.isArmor;
			end
			if a.equipLocation ~= b.equipLocation then
				return a.equipLocation < b.equipLocation;
			end
			return a.visualID < b.visualID;
		end)
end

function TransmogWishListDataProviderMixin:RemoveByVisualID(appearanceID)
	for i = #self.wishList, 1, -1 do
		if (self.wishList[i].visualID == appearanceID) then
			table.remove(self.wishList, i);
			TWL.settings.wishList[appearanceID] = nil;
			return;
		end
	end
end

function TransmogWishListDataProviderMixin:GetListItemByVisualID(visualID)
	for k, item in ipairs(self.wishList) do
		if (item.visualID == visualID ) then
			return item;
		end
	end
end

function TransmogWishListDataProviderMixin:GetListItemBySourceID(sourceID)
	for k, item in ipairs(self.wishList) do
		if (item.sources) then
			for ks, source in ipairs(item.sources) do
				if (source.sourceID == sourceID ) then
					return item;
				end
			end
		end
	end
end

function TransmogWishListDataProviderMixin:HasObtainableSource(visualID, sourceID)
	if sourceID and (select(2, C_TransmogCollection.PlayerCanCollectSource(sourceID))) then -- 暫時修正
		return true;
	end

	local sources = self:GetAppearanceSources(visualID);
	if sources then
		for k, source in ipairs(sources) do
			if select(2, C_TransmogCollection.PlayerCanCollectSource(source.sourceID)) then
				return true;
			end
		end
	end
	
	return false;
end

function TransmogWishListDataProviderMixin:LoadSaveData(data)
	for visualID, v  in pairs(data) do
		self:AddVisualIDToList(visualID, true);
	end
	self:Sort();
end

function TransmogWishListDataProviderMixin:AddSetIDToList(setID)
	setID = tonumber(setID);
	if not setID then return; end

	local sources = C_TransmogSets.GetSetSources(setID);
	local total, numAdded = 0, 0;
	for sourceID, isCollected in pairs(sources) do
		total = total + 1;
		if not isCollected then
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
			local wasAdded = self:AddItemIDToList(sourceInfo.itemID, sourceInfo.itemModID);
			if wasAdded then
				numAdded = numAdded + 1;
			end
		end
	end
	if numAdded > 0 then
		local setInfo = C_TransmogSets.GetSetInfo(setID);
		TransmogWishListSetsPopUp:Announce("已加入 " .. setInfo.name .. " 缺少的外觀");
	else
		TransmogWishListSetsPopUp:Announce("沒有新的外觀可供加入到願望清單");
	end
	
end

function TransmogWishListDataProviderMixin:AddVisualIDToList(visualID, fromLoad)
	if not type(visualID) == "number" then return; end
	
	local illusion = self.illusions[visualID];
	
	if (illusion) then
		self:AddIllusionToList(illusion, fromLoad);
	else
		local sources = self:GetAppearanceSources(visualID)
		if (sources and sources[1]) then
			self:AddItemIDToList(sources[1].itemID, sources[1].itemModID, fromLoad);
		end
	end
end

function TransmogWishListDataProviderMixin:AddIllusionToList(illusion, fromLoad)
	local appearanceID, name, link = C_TransmogCollection.GetIllusionSourceInfo(illusion.sourceID);
	
	local item = {["visualID"] = appearanceID, ["collected"] = false, ["obtainable"] = true, ["illusion"] = illusion};
	table.insert(self.wishList, item);
	
	self:Sort();
	TransmogWishListFrame:Update();
	if (not fromLoad) then
		local _, _, _, hex = GetItemQualityColor(6);
		TransmogWishListPopUp:Announce(FORMAT_APPEARANCE_ADDED:format(hex, name, appearanceID));
	end
	TWL:UpdateAllWishButtons();
	TWL.settings.wishList[appearanceID] = true;
end

function TransmogWishListDataProviderMixin:AddItemIDToList(itemID, modID, fromLoad)
	if not type(itemID) == "number" then return; end
	local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID, modID);
	if not appearanceID then
		TransmogWishListPopUp:Announce("無效的物品 ID");
		return;
	end
	
	local sources = self:GetAppearanceSources(appearanceID);
	
	for k, source in ipairs(sources) do
		local sourceInfo = C_TransmogCollection.GetSourceInfo(source.sourceID)
	
		if sourceInfo.isCollected then
			TransmogWishListPopUp:Announce("你已經收集了這個外觀");
			return;
		end
	end

	if (not self:GetListItemByVisualID(appearanceID)) then
		local name, link, quality, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID, modID);
		if not link then
			self.waitingList[itemID] = {["itemID"] = itemID, ["modID"] = modID};
			return;
		end
		local obtainable = false;
		for k, source in ipairs(sources) do 
			if (select(2, C_TransmogCollection.PlayerCanCollectSource(source.sourceID))) then
				obtainable = true;
				break;
			end
		end

		local isArmor = WARDROBE_MODEL_SETUP[itemEquipLoc] and true or false;
		local item = {["itemID"] = itemID, ["visualID"] = appearanceID, ["collected"] = false, ["sources"] = sources; ["sourceID"] = sourceID, ["isArmor"] = isArmor, ["equipLocation"] = itemEquipLoc, ["obtainable"] = self:HasObtainableSource(appearanceID, sourceID)};
		self.lastAddition = item;
		table.insert(self.wishList, item);
		
		self:Sort();
		
		TransmogWishListFrame:Update();
		if (not fromLoad) then
			local _, _, _, hex = GetItemQualityColor(quality or 1);
			TransmogWishListPopUp:Announce(FORMAT_APPEARANCE_ADDED:format(hex, name, appearanceID));
			-- Update in case we added something that was currently visible
		end
		TWL:UpdateAllWishButtons();
		TWL.settings.wishList[appearanceID] = true;
		
		return true;
	else
		TransmogWishListPopUp:Announce("這個外觀已經在願望清單中");
	end
end

function TransmogWishListDataProviderMixin:EnumerateWishList()
	return ipairs(self.wishList);
end

function TransmogWishListDataProviderMixin:UnlockSource(sourceID)
	local listItem = self:GetListItemBySourceID(sourceID);
	if (listItem) then
		listItem.collected = true;
		self.recentUnlocks[sourceID] = true;
	end
end

function TransmogWishListDataProviderMixin:LockSource(sourceID)
	local listItem = self:GetListItemBySourceID(sourceID);
	if (listItem) then
		listItem.collected = false;
		
		if (self.recentUnlocks[sourceID]) then
			self.recentUnlocks[sourceID] = nil;
			return;
		end
		self.recentLocks[sourceID] = true;
	end
end

function TransmogWishListDataProviderMixin:ClearRecent()
	wipe(self.recentUnlocks);
	wipe(self.recentLocks);
end

function TransmogWishListDataProviderMixin:GetNumRecentUnlocks()
	local count = 0;
	for k, v in pairs(self.recentUnlocks) do
		count = count + 1;
	end
	return count;
end

function TransmogWishListDataProviderMixin:GetNumRecentLocks()
	local count = 0;
	for k, v in pairs(self.recentLocks) do
		count = count + 1;
	end
	return count;
end

local _wishListDataProvider = CreateFromMixins(TransmogWishListDataProviderMixin);

-----------------------------------------------------------------------
--	TransmogWishListMixin
-----------------------------------------------------------------------

TransmogWishListMixin = {};

function TransmogWishListMixin:OnLoad() 
	_wishListDataProvider:OnLoad();
	
	self.dataProvider = _wishListDataProvider;
	self.NUM_ROWS = 3;
	self.NUM_COLS = 6;
	self.PAGE_SIZE = self.NUM_ROWS * self.NUM_COLS;
	
	self:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_REMOVED");
	self:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED");
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE");

	self:SetScript("OnEvent", function(self, event, ...)self:OnEvent(event, ...) end)
end

function TransmogWishListMixin:OnEvent(event, ...)
	
	if(event == "TRANSMOG_COLLECTION_SOURCE_ADDED") then
		local sourceID = ...;
		_wishListDataProvider:UnlockSource(sourceID);
	elseif (event == "TRANSMOG_COLLECTION_SOURCE_REMOVED") then
		local sourceID = ...;
		_wishListDataProvider:LockSource(sourceID);
	end
	
	if (event == "ADDON_LOADED") then
		local addon = ...;
		if (addon ==  "Blizzard_Collections") then
			self:StickToItemCollectionFrame();
		elseif (addon == "WorldQuestTab") then
			HookWQTTooltip();
		end
		return;
	end
	if (event == "TRANSMOG_COLLECTION_UPDATED") then
		self:Update();
		
		local totalUnlocked = _wishListDataProvider:GetNumRecentUnlocks();
		local totalLocked = _wishListDataProvider:GetNumRecentLocks();

		_wishListDataProvider:Sort();
		TransmogWishListFrame.PagingFrame:SetCurrentPage(1)
		TransmogWishListFrame:Update();

		if (totalUnlocked > 0) then
			if (totalUnlocked == 1) then
				print(FORMAT_CHAT_ICON:format("你收集到了願望清單中的外觀!"));
			else
				print(FORMAT_CHAT_ICON:format("你收集了願望清單中的 " .. totalUnlocked .. " 個外觀!"));
			end

			PlaySound(TWL_SOUNDS.FX_Shimmer_Whoosh_Generic);
		end
		
		if (totalLocked > 0) then
			if (totalLocked == 1) then
				print(FORMAT_CHAT_ICON:format("願望清單中有個外觀從收藏中被移除了。"));
			else
				print(FORMAT_CHAT_ICON:format("願望清單中有 " .. totalLocked .. " 個外觀從收藏中被移除了。"));
			end
		end
		
		_wishListDataProvider:ClearRecent();
		
		return;
	end
	
	if (event == "GET_ITEM_INFO_RECEIVED") then
		local itemID = ...;
		local waiting = _wishListDataProvider.waitingList[itemID];
		if (waiting) then
			_wishListDataProvider:AddItemIDToList(waiting.itemID, waiting.modID);
			_wishListDataProvider.waitingList[itemID] = nil;
		elseif TransmogWishListModPicker.needsData then
			TransmogWishListModPicker:ReceivedDataForItemID(itemID);
		end
		return;
	end
	
	if (event == "TRANSMOG_COLLECTION_ITEM_UPDATE") then	
		-- if no lastAddition it's because we loaded save data
		-- we just started the game and don't have data cached yet
		if (not _wishListDataProvider.lastAddition) then
			for k, item in _wishListDataProvider:EnumerateWishList() do
				local obtainable = item.obtainable;
				item.obtainable = _wishListDataProvider:HasObtainableSource(item.visualID, item.sourceID);
				if (obtainable ~= item.obtainable) then
					_wishListDataProvider:Sort();
					self:Update();
				end
			end
		else
			local item = _wishListDataProvider.lastAddition;
			local obtainable = item.obtainable;
			item.obtainable = _wishListDataProvider:HasObtainableSource(item.visualID, item.sourceID);
			if (obtainable ~= item.obtainable) then
				_wishListDataProvider:Sort();
				self:Update();
			end
		end
		return;
	end
	
end

function TransmogWishListMixin:OnShow() 
	self:Update();
	WardrobeCollectionFrameSearchBox:Hide();
	WardrobeCollectionFrame.FilterButton:Hide();
end

function TransmogWishListMixin:OnHide() 
	WardrobeCollectionFrameSearchBox:Show();
	WardrobeCollectionFrame.FilterButton:Show();	
end

function TransmogWishListMixin:OnEnter() 
	for k, model in pairs(self.Models) do
		model.RemoveButton:Hide();
	end
end

function TransmogWishListMixin:StickToItemCollectionFrame()
	-- Stuff we have to after Blizzard_Collections is loaded as it doesn't do so until you open it the first time
	local collectionFrame = WardrobeCollectionFrame.ItemsCollectionFrame;
	local setsFrame = WardrobeCollectionFrame.SetsCollectionFrame;
	
	self:ClearAllPoints();
	self:SetParent(collectionFrame);
	self:SetFrameLevel(collectionFrame:GetFrameLevel()+10);
	self:SetAllPoints();
	
	TransmogWishListButton:SetParent(collectionFrame);
	TransmogWishListButton:SetPoint("BOTTOMRIGHT", collectionFrame, "BOTTOMRIGHT", -75, 42);
	
	TransmogWishListPopUp:SetParent(collectionFrame);
	TransmogWishListPopUp:SetPoint("BOTTOM", collectionFrame, "BOTTOM", 0, 15);
	TransmogWishListPopUp:SetFrameLevel(20)
	
	TransmogWishListSetsPopUp:SetParent(setsFrame.Model);
	TransmogWishListSetsPopUp:SetPoint("BOTTOM", setsFrame.Model, "BOTTOM", 0, 15);
	TransmogWishListSetsPopUp:SetFrameLevel(20)
	
	TWLSetsWishButton:SetParent(setsFrame.Model);
	TWLSetsWishButton:SetPoint("TOPLEFT", setsFrame.Model, "TOPLEFT", 5, -5);
	TWLSetsWishButton:Show();

	for k, model in ipairs(collectionFrame.Models) do
		model.TWLWishButton = CreateFrame("FRAME", nil, model, "TWLWishButtonTemplate");
		model:HookScript("OnEnter", function(self)
				self.TWLWishButton:Show();
				self.TWLWishButton:Update(true);
			end)
		model:HookScript("OnLeave", function(self)
				TWL:UpdateAllWishButtons()
			end)
	end
	
	hooksecurefunc("WardrobeCollectionFrame_SetTab", function(...) 
			local tabID = ...;
			if (tabID == 1) then
				self:Hide();
			end
		end) 
	
	hooksecurefunc(collectionFrame, "UpdateItems", function(...)
			TWL:UpdateAllWishButtons();
		end);
	
	-- Hide the button when transmogging
	WardrobeTransmogFrame:HookScript("OnShow", function(...)
			TransmogWishListButton:Hide();
		end);
	CollectionsJournal:HookScript("OnShow", function(...)
			TransmogWishListButton:Show();
		end);
end

function TransmogWishListMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta);
end

function TransmogWishListMixin:OnPageChanged(userAction)
	PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN);
	if ( userAction ) then
		self:Update();
	end
end

function TransmogWishListMixin:Update()
	if not CollectionsJournal or not CollectionsJournal:IsShown() or not self:IsShown() then return end;
	local wishList = _wishListDataProvider.wishList;
	
	self.EmptyListInfo:SetShown(#wishList == 0);
	self.PagingFrame:SetMaxPages(ceil(#wishList / self.PAGE_SIZE));
	local indexOffset = (self.PagingFrame:GetCurrentPage() - 1) * self.PAGE_SIZE;
	for i=1, self.PAGE_SIZE do
		local model = self.Models[i];
		local index = indexOffset + i;
		local itemInfo = wishList[index];
		model:Hide();
		if itemInfo then
			model.itemInfo = itemInfo;
			model:Show();
			model:SetKeepModelOnHide(true);
			model:ShowWishlistItem();
		end
	end
end

function TransmogWishListMixin:RemoveCollected()
	for k, itemInfo in _wishListDataProvider:EnumerateWishList() do
		if itemInfo.collected then
			_wishListDataProvider:RemoveByVisualID(itemInfo.visualID);
		end
	end
end

-----------------------------------------------------------------------
--	TransMogWishListModelMixin
-----------------------------------------------------------------------

local function UpdateModelTooltip(tooltip) 
	local modelFrame = tooltip:GetOwner();
	local itemInfo = tooltip:GetOwner().itemInfo;
	if (not itemInfo or not modelFrame) then return; end
	GameTooltip:SetOwner(modelFrame, "ANCHOR_RIGHT");

	-- Don't do anything if we are collected and playing the animation
	if (itemInfo.collected) then return end;
	modelFrame.RemoveButton:Show();
		
	if (itemInfo.itemID) then
		local sources = _wishListDataProvider:GetAppearanceSources(itemInfo.visualID);
		local itemName, _, titleQuality = GetItemInfo(itemInfo.itemID);
		-- Data not yet available
		if (not itemName) then
			GameTooltip:SetText("資料載入中");
			return;
		end

		-- Can't obtain on this character
		if not itemInfo.obtainable then
			GameTooltip:AddLine("此角色無法取得。", 1, 0.25, 0.25)
		elseif sources then 
			-- Display sources if available
			GameTooltip:AddLine("獲取途徑");
			for k, source in ipairs(sources) do
				if (source.name and source.sourceType) then
					GameTooltip:AddLine(source.name, GetItemQualityColor(source.quality or 1));
					if source.sourceType == TRANSMOG_SOURCE_BOSS_DROP then
						local drops = _wishListDataProvider:GetAppearanceSourceDrops(source.sourceID);
						for k, drop in pairs(drops) do
							GameTooltip:AddDoubleLine("  " .. drop.instance, drop.encounter, 1, 1, 1, 1, 1, 1);
							if (#drop.difficulties > 0) then
								GameTooltip:AddLine("  - " ..table.concat(drop.difficulties, ", "), 0.75, 0.75, 0.75);
							end
						end
					elseif (source.sourceType) then
						GameTooltip:AddLine("  " ..  _G["TRANSMOG_SOURCE_" .. source.sourceType], 1, 1, 1);
					end
				end
			end
		else
			GameTooltip:AddLine("沒有來源的資料。");
		end
	elseif (itemInfo.illusion) then
		local visualID, name, link = C_TransmogCollection.GetIllusionSourceInfo(itemInfo.illusion.sourceID);
		GameTooltip:AddLine("Available sources");
		GameTooltip:AddLine(name, GetItemQualityColor(6));
		if (itemInfo.illusion.sourceText) then
			GameTooltip:AddLine(" " .. itemInfo.illusion.sourceText, 1, 1, 1);
		end
	end
	
	GameTooltip:Show();
	
end

TransMogWishListModelMixin = {};

function TransMogWishListModelMixin:OnLoad()
	self:SetAutoDress(false);
	for slot, id in pairs(WARDROBE_MODEL_SETUP_GEAR) do
		self:TryOn(id);
	end
	
	local lightValues = { enabled=true, omni=false, dirX=-1, dirY=1, dirZ=-1, ambIntensity=1.05, ambR=1, ambG=1, ambB=1, dirIntensity=0, dirR=1, dirG=1, dirB=1 };
	self:SetLight(lightValues.enabled, lightValues.omni,
			lightValues.dirX, lightValues.dirY, lightValues.dirZ,
			lightValues.ambIntensity, lightValues.ambR, lightValues.ambG, lightValues.ambB,
			lightValues.dirIntensity, lightValues.dirR, lightValues.dirG, lightValues.dirB);
end

function TransMogWishListModelMixin:OnShow()
	self.CollectedString:SetAlpha(0);
	self.CollectedGlow:SetAlpha(0);
	self:SetAlpha(1);
end

function TransMogWishListModelMixin:OnMouseDown()
	local itemInfo = self.itemInfo
	if(itemInfo and (itemInfo.illusion or self.itemInfo.sourceID)) then
		if (IsModifiedClick("DRESSUP")) then
			if (itemInfo.itemID) then
				DressUpVisual(itemInfo.sourceID);
			elseif (itemInfo.illusion) then
				local slot = "MAINHANDSLOT";
				local weaponSourceID = WardrobeCollectionFrame_GetWeaponInfoForEnchant(slot);
				DressUpVisual(weaponSourceID, slot, itemInfo.illusion.sourceID);
			end
		end
	end
end

function TransMogWishListModelMixin:OnModelLoaded()
	if (self.cameraID) then
		Model_ApplyUICamera(self, self.cameraID);
	end
end

function TransMogWishListModelMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip.UpdateTooltip = UpdateModelTooltip;
	UpdateModelTooltip(GameTooltip);
	if IsModifiedClick("DRESSUP") then
		ShowInspectCursor();
	else
		ResetCursor();
	end
end

function TransMogWishListModelMixin:OnLeave()
	self.RemoveButton:Hide();
	GameTooltip:Hide();
	ResetCursor();
end

function TransMogWishListModelMixin:OnUpdate()
	if IsModifiedClick("DRESSUP") then
		ShowInspectCursor();
	else
		ResetCursor();
	end
end

function TransMogWishListModelMixin:RemoveButtonOnClick()
	_wishListDataProvider:RemoveByVisualID(self.itemInfo.visualID);
	self:GetParent():Update();
end

function TransMogWishListModelMixin:CollectedAnimOnEnd()
	TransmogWishListFrame:RemoveCollected();
	TransmogWishListFrame:Update();
end

function TransMogWishListModelMixin:PlayCollectedAnimation()
	if self.CollectedAnim then
		self.CollectedAnim:Play();
	end
end

function TransMogWishListModelMixin:ShowWishlistItem()
	local cameraID;
	local itemInfo = self.itemInfo;
	self:Undress();
	
	if (itemInfo.itemID) then
	
		if (itemInfo.isArmor) then
			cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(itemInfo.sourceID);
			self:SetUseTransmogSkin(WARDROBE_MODEL_SETUP[itemInfo.equipLocation].useTransmogSkin);
			self:SetUnit("player", false);
			self:TryOn(itemInfo.sourceID)
			
			for slot, equip in pairs(WARDROBE_MODEL_SETUP[itemInfo.equipLocation].slots) do
				if ( equip ) then
					self:TryOn(WARDROBE_MODEL_SETUP_GEAR[slot]);
				end
			end
			
		else
			cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(itemInfo.sourceID);
			self:SetItemAppearance(itemInfo.visualID)
		end
	elseif (itemInfo.illusion) then
		local location = TransmogUtil.CreateTransmogLocation("MAINHANDSLOT", Enum.TransmogType.Illusion, Enum.TransmogModification.None);
		local appearanceSourceID, appearanceVisualID = WardrobeCollectionFrame_GetWeaponInfoForEnchant(location);
		
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(appearanceSourceID);
		self:SetItemAppearance(appearanceVisualID, itemInfo.illusion.visualID)
	end
	
	if (cameraID) then
		Model_ApplyUICamera(self, cameraID);
		self.cameraID = cameraID;
	end
		
	self.CollectedString:Hide();
	self.CollectedGlow:Hide();
	if itemInfo.collected then
		self.CollectedString:Show();
		self.CollectedGlow:Show();
		self:PlayCollectedAnimation();
		self.Border:SetAtlas("transmog-wardrobe-border-collected");
	elseif itemInfo.obtainable then
		self.Border:SetAtlas("transmog-wardrobe-border-uncollected");
	else
		self.Border:SetAtlas("transmog-wardrobe-border-unusable");
	end
end

-----------------------------------------------------------------------
--	TransmogWishListPagingMixin
-----------------------------------------------------------------------
		
TransmogWishListPagingMixin = { };

function TransmogWishListPagingMixin:OnLoad()
	self.currentPage = 1;
	self.maxPages = 1;
	self:Update();
end

function TransmogWishListPagingMixin:SetMaxPages(maxPages)
	maxPages = math.max(maxPages, 1);
	if ( self.maxPages == maxPages ) then
		return;
	end
	self.maxPages= maxPages;
	if ( self.maxPages < self.currentPage ) then
		self.currentPage = self.maxPages;
	end
	self:Update();
end

function TransmogWishListPagingMixin:GetMaxPages()
	return self.maxPages;
end

function TransmogWishListPagingMixin:SetCurrentPage(page, userAction)
	page = Clamp(page, 1, self.maxPages);
	if ( self.currentPage ~= page ) then
		self.currentPage = page;
		self:Update();
		if ( self:GetParent().OnPageChanged ) then
			self:GetParent():OnPageChanged(userAction);
		end
	end
end

function TransmogWishListPagingMixin:GetCurrentPage()
	return self.currentPage;
end

function TransmogWishListPagingMixin:NextPage()
	self:SetCurrentPage(self.currentPage + 1, true);
end

function TransmogWishListPagingMixin:PreviousPage()
	self:SetCurrentPage(self.currentPage - 1, true);
end

function TransmogWishListPagingMixin:OnMouseWheel(delta)
	if ( delta > 0 ) then
		self:PreviousPage();
	else
		self:NextPage();
	end
end

function TransmogWishListPagingMixin:Update()
	self.PageText:SetFormattedText(COLLECTION_PAGE_NUMBER, self.currentPage, self.maxPages);
	if ( self.currentPage <= 1 ) then
		self.PrevPageButton:Disable();
	else
		self.PrevPageButton:Enable();
	end
	if ( self.currentPage >= self.maxPages ) then
		self.NextPageButton:Disable();
	else
		self.NextPageButton:Enable();
	end
end
		
-----------------------------------------------------------------------
--	TWLWishButtonMixin
-----------------------------------------------------------------------
		
TWLWishButtonMixin = {}

function TWLWishButtonMixin:Update(enteredParent)
	local visualInfo = self:GetParent().visualInfo;
	if (not visualInfo or visualInfo.isCollected) then 
		self:Hide();
		return; 
	end

	self.visualInfo = visualInfo;
	self.isWished = _wishListDataProvider:GetListItemByVisualID(visualInfo.visualID) and true;
	if (not enteredParent) then
		if (not self.isWished) then
			self:Hide();
		else
			self:Show();
		end
	end
	
	self.texture:SetAlpha(self.isWished and 0.75 or 0.4);
end
		
function TWLWishButtonMixin:OnEnter()
	self:Show();
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("加入願望清單");
	GameTooltip:Show();
	self.texture:SetAlpha(1.0);
end

function TWLWishButtonMixin:OnLeave()
	self:Hide();
	GameTooltip:Hide();
	self:Update()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
end

function TWLWishButtonMixin:OnMouseDown()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1);
end

function TWLWishButtonMixin:OnMouseUp()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);

	if self.isWished  then
		_wishListDataProvider:RemoveByVisualID(self.visualInfo.visualID);
		TransmogWishListFrame:Update();
	else
		--if self.visualInfo.isHideVisual ~= nil then
		_wishListDataProvider:AddVisualIDToList(self.visualInfo.visualID);
		--end
	end
	PlaySound(TWL_SOUNDS.PutDownRing);
	self:Update(true);
end

-----------------------------------------------------------------------
--	TWLSetsWishButtonMixin
-----------------------------------------------------------------------
		
TWLSetsWishButtonMixin = {}
		
function TWLSetsWishButtonMixin:OnEnter()
	self:Show();
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("加入願望清單");
	GameTooltip:AddLine("加入此套裝中所有尚未收集的外觀。");
	GameTooltip:Show();
	self.texture:SetAlpha(1.0);
end

function TWLSetsWishButtonMixin:OnLeave()
	--self:Hide();
	GameTooltip:Hide();
	self.texture:SetAlpha(0.4);
	--self.texture:SetAlpha(self.isWished and 0.75 or 0.4);
	self.texture:SetPoint("CENTER", self, "CENTER", 0, 0);
end

function TWLSetsWishButtonMixin:OnMouseDown()
	self.texture:SetPoint("CENTER", self, "CENTER", 1, -1);
end

function TWLSetsWishButtonMixin:OnMouseUp()
	self.texture:SetPoint("CENTER", self, "CENTER", 0, 0);
	local setID = self:GetParent():GetParent().selectedSetID;
	_wishListDataProvider:AddSetIDToList(setID);
	PlaySound(TWL_SOUNDS.PutDownRing);
end

-----------------------------------------------------------------------
--	TWLModPickerMixin
-----------------------------------------------------------------------

TWLModPickerMixin = {};

function TWLModPickerMixin:AddButtonOnClick()
	_wishListDataProvider:AddItemIDToList(self.itemID, self.selected.modID);
	self:Close();
end

function TWLModPickerMixin:Close()
	self.itemID = nil;
	self.isArmor = nil;
	self.itemEquipLoc = nil; 
	self.mods = nil;
	self.selected = nil; 
	self.PreviewModel:SetKeepModelOnHide(false);
	TransmogWishListFrame.modpickerOverlay:Hide();
end

function TWLModPickerMixin:ReceivedDataForItemID(itemID)
	if (tonumber(itemID) == tonumber(self.itemID)) then
		self:Setup(self.itemID, self.mods);
	end
end

function TWLModPickerMixin:Setup(itemID, mods)
	self.itemID = itemID;
	self.mods = mods;
	local name, link, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID, modID);
	if not name then
		self.needsData = true;
		return;
	end
	self.needsData = nil;

	self.isArmor = WARDROBE_MODEL_SETUP[itemEquipLoc] and true or false;
	self.itemEquipLoc = itemEquipLoc; 
	self.selected = self.mods[1]; 
	self:Show();
	TransmogWishListFrame.modpickerOverlay:Show();
	self.Info:SetText(FORMAT_MODPICKER_INFO:format(itemID, #mods));
	
	self.PreviewModel:SetKeepModelOnHide(true);
	for k, button in ipairs(self.ModList.ModButtons) do
		button:Hide();
	end
	
	self:Update();
end

function TWLModPickerMixin:Update()
	for i = 1, #self.mods do
		local button = self.ModList.ModButtons[i];
		button:Setup(self.mods[i]);
	end
	
	self.SelectedText:SetText(FORMAT_MODID_SELECTED:format(self.selected.modID));
	
	self:ShowModel(self.selected)
end

function TWLModPickerMixin:OnModelLoaded()
	if (self.PreviewModel.cameraID) then
		Model_ApplyUICamera(self.PreviewModel, self.PreviewModel.cameraID);
	end
end

function TWLModPickerMixin:ShowModel(modInfo)
	local cameraID;
	local model = self.PreviewModel;
	if (model.itemID == self.itemID and model.modID == modInfo.modID) then return; end;
	model.modInfo = modInfo;
	model.itemID = self.itemID;
	model.modID = modInfo.modID;
	model:Undress();
	
	if (self.isArmor) then
		model:SetUnit("player", false);
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(modInfo.sourceID);
		model:SetUseTransmogSkin(WARDROBE_MODEL_SETUP[self.itemEquipLoc].useTransmogSkin);
		for slot, equip in pairs(WARDROBE_MODEL_SETUP[self.itemEquipLoc].slots) do
			if ( equip ) then
				model:TryOn(WARDROBE_MODEL_SETUP_GEAR[slot]);
			end
		end
		model:TryOn(modInfo.sourceID)
	else
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(modInfo.sourceID);
		model:SetItemAppearance(modInfo.visualID);
	end

	model.cameraID = cameraID;
	Model_ApplyUICamera(model, cameraID);
end

-----------------------------------------------------------------------
--	TWLModButtonMixin
-----------------------------------------------------------------------

TWLModButtonMixin = {};

function TWLModButtonMixin:OnClick()
	TransmogWishListModPicker.selected = self.modInfo;
	TransmogWishListModPicker:Update();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

function TWLModButtonMixin:OnEnter()
	TransmogWishListModPicker:ShowModel(self.modInfo);
end

function TWLModButtonMixin:OnLeave()
	TransmogWishListModPicker:ShowModel(TransmogWishListModPicker.selected);
end

function TWLModButtonMixin:Setup(modInfo)
	self.SelectTexture:SetShown(modInfo.modID == TransmogWishListModPicker.selected.modID);
	self:SetText(modInfo.modID);
	self.modInfo = modInfo;
	self:Show();
end
		
function TWL:OnEnable()
	self.db = LibStub("AceDB-3.0"):New("TWLDB", TWL_DEFAULTS, true);

	self.settings = self.db.global;
	
	if (not self.settings.versionCheck) then
		ConvertOldData(self.settings.wishList);
	end
	self.settings.versionCheck  = GetAddOnMetadata(_addonName, "version");
	
	if (IsAddOnLoaded("Blizzard_Collections")) then
		TransmogWishListFrame:StickToItemCollectionFrame();
	end
	
	if (IsAddOnLoaded("WorldQuestTab")) then
		HookWQTTooltip();
	end
	
	_wishListDataProvider:LoadSaveData(self.settings.wishList) 
	
	-- Clean up collected illustrations just in case 
	for k, itemInfo in _wishListDataProvider:EnumerateWishList() do
		if (itemInfo.illusion and not itemInfo.illusion.sourceText) then
			itemInfo.collected = true;
		end
	end
end

TWLPopUpMixin = {}

function TWLPopUpMixin:CollectedAnimOnEnd()
	self:Hide();
end

function TWLPopUpMixin:OnShow()
	self.FadeInAnim:Play();
end

function TWLPopUpMixin:Announce(text)	
	self.FadeInAnim:Stop();
	self.CollectedAnim:Stop();
	self:Hide();
	self.Text:SetWidth(0);
	self.Text:SetText(text);
	if (self.Text:GetWidth() > self:GetWidth()) then
		self.Text:SetWidth(self:GetWidth());
	end
	self:Show();
end

-----------------------------------------------------------------------
--	TWLAddBoxMixin
-----------------------------------------------------------------------

TWLAddBoxMixin = {}

function TWLAddBoxMixin:OnLoad()
	self:SetTextInsets(2, 20, 0, 0);
	self.Instructions:SetText("加入物品ID");
	self.Instructions:ClearAllPoints();
	self.Instructions:SetPoint("TOPLEFT", self, "TOPLEFT", 2, 0);
	self.Instructions:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 0);
end

function TWLAddBoxMixin:OnEscapePressed()
	self:SetText("");
	EditBox_ClearFocus(self);
end

function TWLAddBoxMixin:OnEnterPressed()
	local input = self:GetText();
	self:SetText("");
	EditBox_ClearFocus(self);
	if input:find("(%d+)") then
		local itemID, modID = string.match(input, "(%d+) (%d+)");
		itemID = itemID or input;
		itemID = tonumber(itemID);
		
		local mods = {modID}
		if not modID then
				
			for i=0, 10 do
				local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID, i);
				if appearanceID then
					tinsert(mods, {["modID"] = i, ["visualID"] = appearanceID, ["sourceID"] = sourceID});
				end
			end
			
		end
	
		if #mods == 1 then
			-- If there is only 1 itemModID, just use that one!
			_wishListDataProvider:AddItemIDToList(tonumber(itemID), tonumber(mods[1]));
		elseif (#mods > 1) then
			TransmogWishListModPicker:Setup(itemID, mods);
		else 
			-- If there are no mods, the item has no appearance;
			TransmogWishListPopUp:Announce("這個物品 ID 沒有任何外觀");
		end
	end
end

function TWLAddBoxMixin:OnTextChanged()
	InputBoxInstructions_OnTextChanged(self);
end

