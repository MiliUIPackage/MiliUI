
local _addonName, _addon = ...;

local ADD = LibStub("AddonDropDown-2.0");
local _L = _addon.L;
local _V = _addon.variables;
local WQT_V;
local WQT_Utils = WQT_WorldQuestFrame.WQT_Utils;
local WQTU = _addon.WQTU;

local DISTANCE_FORMAT = GetLocale() == "enUS" and "%syd" or "%sm"
local SORT_DISTANCE = 50;
local MAX_NUM_TALLIES = 16;
local HISTORY_DAYS = 14;
local FORMAT_REWARD = "|T%s:0|t %s";
local FORMAT_REWARD_AMOUNT = "|T%s:0|t %s\nTotal: %d";
local TALLY_WIDTH = 75;
local TALLY_WIDTH_COLLAPSED = 26;
local GRAPH_MAX_BUTTON_ROWS = 9;

local _nullVector = CreateVector2D(0, 0);
local _playerFaction = GetPlayerFactionGroup();
local _playerName = UnitName("player");
local _playerRealm = GetRealmName();

local _priorities = {
	["anima"] = 1;
	["azerite"] = 2;
	["gold"] = 3;
	["tokens"] = 4;
	["reagents"] = 5;
	["consumables"] = 6;
	["misc"] = 7;
	["currencies"] = 8;
	["reputation"] = 9;
	["honor"] = 10;
}

local _warmodeTypes = {
		["azerite"] = true;
		["gold"] = true;
		["currencies"] = true;
	}

local _tallyLabels = {
			["gold"] = WORLD_QUEST_REWARD_FILTERS_GOLD;
			["azerite"] = ITEM_QUALITY6_DESC;
			["honor"] = HONOR;
			["currencies"] = WORLD_QUEST_REWARD_FILTERS_RESOURCES;
			["reputation"] = REPUTATION;
			["reagents"] = MINIMAP_TRACKING_VENDOR_REAGENT;
			["consumables"] = BAG_FILTER_CONSUMABLES;
			["tokens"] = TOKENS;
			["misc"] = BINDING_HEADER_COMMENTATORMISC;
			["anima"] = ANIMA;
		}

local WQTU_DEFAULTS = {
	global = {	
		versionCheck = "";
		updateSeen = false;

		["directionLine"] = true;
		["tallies"] = {
				["gold"] = true;
				["azerite"] = true;
				["anima"] = true;
				["honor"] = true;
				["currencies"] = true;
				["reputation"] = true;
				["reagents"] = true;
				["consumables"] = true;
				["tokens"] = true;
				["misc"] = true;
			};
		["history"] = {};
	}
}

local _rewardInfoCache = {
		["gold"] = {
			["texture"] = 133784
			,["name"] = WORLD_QUEST_REWARD_FILTERS_GOLD
			,["quality"] = 1
		}
		,["honor"] = {
			["texture"] = 1455894
			,["name"] = HONOR
			,["quality"] = 1
		}
		,["azerite"] = {
			["texture"] = 2032607
			,["name"] = "Azerite"
			,["quality"] = 1
		}
		,["anima"] = {
			["texture"] = 3528288
			,["name"] = "anima"
			,["quality"] = 1
		}
		,["currency"] = {}
		,["item"] = {}
	};
	

local _azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();

local function Lerp(a, b, v)
	return a + (b-a) * v;
end

local function FilterMatchesFaction(filterId, faction)
	return (filterId == 1) or
		(filterId == 2 and faction == "Alliance") or
		(filterId == 3 and faction == "Horde")
end

local function CallFunctionOnHistory(history, func, factionFilterId, scopeFilterId)
	if (not history) then return; end
	
	factionFilterId = factionFilterId or 1;
	scopeFilterId = scopeFilterId or 1;
	
	for realm, realmInfo in pairs(history) do
		if (scopeFilterId < 2 or realm == _playerRealm) then
			for character, charInfo in pairs(realmInfo) do
				-- Check faction filtering
				if (FilterMatchesFaction(factionFilterId, charInfo.faction) and (scopeFilterId < 3 or character == _playerName)) then
					for index, amount in pairs(charInfo.rewards) do
						func(index, amount);
					end
				end
			end
		end
	end
end

local function GetRewardHistory(timeStamp, matchIndex, factionFilterId, scopeFilterId)
	local history = WQTU.settings.history[timeStamp];
	if (not history) then
		return 0;
	end
	
	local total = 0;
	CallFunctionOnHistory(history, function(index, amount) if (index == matchIndex) then total = total + amount end  end, factionFilterId, scopeFilterId);
	
	if (matchIndex == "gold") then
		total = floor(total/10000);
	end
	
	return total;
end

local WQTU_Utilities = {};

function WQTU_Utilities:GetRewardInfo(index)
	if (not index) then return nil; end
	local category, rewardId = index:match("(%a+);?(%d*)");
	rewardId = tonumber(rewardId);
	if (not rewardId) then
		return _rewardInfoCache[category];
	end
	if (not _rewardInfoCache[category]) then return; end
	
	if (_rewardInfoCache[category][rewardId] and not _rewardInfoCache[category][rewardId].isMissingData) then
		return _rewardInfoCache[category][rewardId];
	end
	if (category == "currency") then
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(rewardId);
		local name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(rewardId, 1, currencyInfo.name, currencyInfo.iconFileID, currencyInfo.quality); 
		_rewardInfoCache[category][rewardId] = { ["texture"] = texture, ["name"] = name, ["quality"] = quality};
	elseif (category == "item") then
		local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(rewardId);
		local isMissingData = not name and true or nil;
		name = name or index;
		texture = texture or 134400 ;-- questionmark
		quality = quality or 1;
		_rewardInfoCache[category][rewardId] = { ["texture"] = texture, ["name"] = name, ["quality"] = quality};
		_rewardInfoCache[category][rewardId].isMissingData = isMissingData;
	end
	
	return _rewardInfoCache[category][rewardId];
end

function WQTU_Utilities:AddRewardToList(list, questId, category, rewardType, rewardId, amount, warmodeBonus)
	-- Cache the data while we're at it
	local index = rewardId and category ..";"..rewardId or category;

	-- Only caching
	if (not list) then return; end
	
	local rewardInfo = self:GetRewardInfo(index)
	if (not rewardInfo) then return end
	
	if (not list[index]) then
		list[index] = {};
		list[index].rewardType = rewardType;
		list[index].name = rewardInfo.name;
		list[index].texture = rewardInfo.texture;
		list[index].quality = rewardInfo.quality;
		list[index].amount = 0;
		list[index].quests = {};
		list[index].id = rewardId;
	end
	list[index].amount = list[index].amount + amount;
	list[index].quests[questId] = true
end

function WQTU_Utilities:AddQuestInfoRewardsToList(list, questInfo, includeWarMode)
	local settings = WQTU.settings;
	for k, reward in questInfo:IterateRewards() do
		local amount = reward.amount;
		if (includeWarMode) then
			amount = WQT_Utils:CalculateWarmodeAmount(reward.type, amount);
		end
		
		local catA, catB, id, _, allowTally = WQTU_Utilities:GetRewardCategoryInfo(reward.type, reward.id);

		if (allowTally and catA and catB) then
			WQTU_Utilities:AddRewardToList(list, questInfo.questId, catA, catB, id, amount);
		end
	end
end

function WQTU_Utilities:GetRewardCategoryInfo(rewardType, rewardId)
	local catA, catB, id, index, allowTally;
	local settings = WQTU.settings;
	
	if (rewardType == WQT_REWARDTYPE.gold) then
		catA = "gold";
		catB = "gold";
		allowTally = settings.tallies.gold;
	elseif (rewardType == WQT_REWARDTYPE.honor) then
		catA = "honor";
		catB = "honor";
		allowTally = settings.tallies.honor;
	elseif (rewardType == WQT_REWARDTYPE.anima) then
		catA = "anima";
		catB = "anima";
		allowTally = settings.tallies.anima;
	elseif (rewardType == WQT_REWARDTYPE.artifact) then
		catA = "azerite";
		catB = "azerite";
		allowTally = settings.tallies.azerite;
	elseif (rewardType == WQT_REWARDTYPE.reputation) then
		catA = "currency";
		catB = "reputation";
		id = rewardId;
		allowTally = settings.tallies.reputation;
	elseif (rewardType == WQT_REWARDTYPE.currency) then
		catA = "currency";
		catB = "currencies";
		allowTally = settings.tallies.currencies;
		id = rewardId;
	elseif (rewardType == WQT_REWARDTYPE.item and rewardId) then
		catA = "item";
		local name, _, rarity, ilvl, _, _, _, _, _, texture, price, itemClassID, itemSubClassID = GetItemInfo(rewardId);
		id = rewardId;
		if (itemClassID == 0) then
			if (itemSubClassID == 8 and price == 0 and ilvl > 100) then 
				catB = "tokens";
				allowTally = settings.tallies.tokens;
			else
				catB = "consumables";
				allowTally = settings.tallies.consumables;
			end
		elseif (itemClassID == 7) then
			catB = "reagents";
			allowTally = settings.tallies.reagents;
		elseif (itemClassID == 15 and itemSubClassID == LE_ITEM_MISCELLANEOUS_OTHER) then
			catB = "misc";
			allowTally = settings.tallies.misc;
		end
	end
	
	if (catA) then
		index = id and catA ..";"..id or catA;
	end
	
	return catA, catB, id, index, allowTally;
end 

function WQTU_Utilities:AddQuestRewardsToHistory(questInfo) 
	local history = WQTU.settings.history;
	local t = date("*t", time());
	local timestamp = time({["year"] = t.year, ["month"] = t.month, ["day"] = t.day});
	local historyToday = history[timestamp];
	if (not historyToday) then
		historyToday = {};
		history[timestamp] = historyToday;
	end
	local realm = GetRealmName();
	local historyRealm = historyToday[realm];
	if (not historyRealm) then
		historyRealm = {};
		historyToday[realm] = historyRealm;
	end
	local playerName = UnitName("player");
	local historyCharacter = historyRealm[playerName];
	if (not historyCharacter) then
		historyCharacter = {["rewards"] = {}};
		historyRealm[playerName] = historyCharacter;
	end
	historyCharacter.faction = GetPlayerFactionGroup(); -- In case a panda grows up to pick a side
	
	for k, reward in questInfo:IterateRewards() do
		local amount = WQT_Utils:CalculateWarmodeAmount(reward.type, reward.amount);
		local _, _, _, index = WQTU_Utilities:GetRewardCategoryInfo(reward.type, reward.id);
		-- Filter out rewards we don't want to count (i.e. armor)
		if (index) then
			local storedAmount = historyCharacter.rewards[index] or 0;
			storedAmount = storedAmount + amount;
			historyCharacter.rewards[index] = storedAmount;
		end
	end
end

local function TallyAreaBlocked()
	return GetUIPanel("center") and GetUIPanel("center"):GetName() ~= "FlightMapFrame";
end

local function UpdateQuestDistances()
	for k, questInfo in ipairs(WQT_QuestScrollFrame.questList) do
		local playerContinent = WQTU_DirectLineFrame.playerContinent;
		local continent = questInfo.mapInfo.continent; 
		local distance = math.huge;
		-- Only count the current continent. Player's coordinates are per map file
		if (playerContinent and playerContinent == continent) then 
			local distSq = C_QuestLog.GetDistanceSqToQuest(questInfo.questId);
			distance =  distSq and math.sqrt(distSq) or math.huge;
		end
		questInfo.mapInfo.distance = distance;
	end
end

WQTU_GraphPointMixin = {};

function WQTU_GraphPointMixin:OnEnter()
	if (not self.value) then return; end
	
	self.Icon:SetAtlas("Object");
	self.Icon:SetDesaturated(false);
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -5, -5);
	if(self.label) then
		GameTooltip:SetText(self.label, 1, 1, 1, 1, true);
		GameTooltip:AddLine(self.value, nil, nil, nil, nil, true)
	else
		GameTooltip:SetText(self.value, 1, 1, 1, 1, true);
	end
		
	GameTooltip:Show();
end

function WQTU_GraphPointMixin:OnLeave()
	self.Icon:SetAtlas(self.value == 0 and "RaidMember" or "PlayerFriend");
	GameTooltip:Hide();
end

function WQTU_GraphPointMixin:SetValue(value, label)
	self.value = value;
	self.label = label;
	self.Icon:SetAtlas(self.value == 0 and "RaidMember" or "PlayerFriend");
end

WQTU_GraphMixin = {};

function WQTU_GraphMixin:OnLoad()
	self.linePool = CreateFramePool("FRAME", self, "WQTU_GraphLineTemplate");
	self.scaleLinePool = CreateFramePool("FRAME", self, "WQTU_GraphScaleLineTemplate");
	self.lines = {};
	self.pointPool = CreateFramePool("FRAME", self, "WQTU_GraphPointTemplate");
	self.points = {};
	self.labelPool = CreateFramePool("FRAME", self, "WQTU_GraphLabelTemplate");
	self.padding = {["left"] = 15, ["right"] = 15, ["top"] = 15, ["bottom"] = 10};
	self.shiftSpeed = .5; -- 1 sec;
	self.shiftcurrent = 0;
end

function WQTU_GraphMixin:OnUpdate(elapsed)
	if (self.isShiftingPoints) then
		self.shiftcurrent = self.shiftcurrent + elapsed;
		
		if (self.shiftcurrent >= self.shiftSpeed) then
			self.shiftcurrent = self.shiftSpeed;
			self.isShiftingPoints = false;
		end
		
		local numPoints = self.pointPool.numActiveObjects;
		local progress = self.shiftcurrent / self.shiftSpeed;
		-- smoothing
		progress = (sin((progress*180)-90)+1)/2;
		
		for i = 1, numPoints  do
			local graphPoint = self.points[i];
			
			local currentY = Lerp(graphPoint.oldY, graphPoint.newY, progress );
			local point, relativeTo, relativePoint, xOfs = graphPoint:GetPoint(1);
			graphPoint:SetPoint(point, relativeTo, relativePoint, xOfs, currentY);
			
			if (i < numPoints) then
				local line = self.lines[i];
				local point, relativeTo, xOfs = line.Fill:GetStartPoint();
				line.Fill:SetStartPoint(point, relativeTo, xOfs, currentY);
			end
			if (i > 1) then
				local line = self.lines[i-1];
				local point, relativeTo, xOfs = line.Fill:GetEndPoint();
				line.Fill:SetEndPoint(point, relativeTo, xOfs, currentY);
			end
		end
	end
end

function WQTU_GraphMixin:DrawScaleLines(amount, scaleValue)
	self.scaleLinePool:ReleaseAll();
	local labelHeight = self:GetLabelAreaHeight();
	local xStart = self.padding.left;
	local xEnd = self:GetWidth() - self.padding.right;
	local graphHeight = self:GetHeight() - self.padding.top - self.padding.bottom - labelHeight;
	if (self.Title:GetText() ~= "") then
		graphHeight = graphHeight - self.Title:GetStringHeight()  - self.padding.top;
	end
	local distance = graphHeight / (amount-1);
	for i = 0, amount-1 do
		local y = self.padding.bottom + distance * i + labelHeight;
		local line = self.scaleLinePool:Acquire();
		line.Fill:SetStartPoint("BOTTOMLEFT", self, xStart, y);
		line.Fill:SetEndPoint("BOTTOMLEFT", self, xEnd, y);
		line.Fill:SetVertexColor(1, 1, 1);
		line:Show();
		line.Fill:Show();
		
		if (i > 0) then
			local label = self.labelPool:Acquire();
			label.Text:SetText(scaleValue*i);
			label:SetSize(label.Text:GetSize());
			label:SetPoint("TOPLEFT", self, "BOTTOMLEFT", xStart, y);
			label:Show();
		end	
	end
end

function WQTU_GraphMixin:GetLabelAreaHeight()
	if (self.labelPool.numActiveObjects == 0) then
		return 0;
	end
	
	for label in self.labelPool:EnumerateActive() do
		return label:GetHeight() + 7;
	end
end

function WQTU_GraphMixin:DisplayValues(values, title, labels)
	self.labelPool:ReleaseAll();
	
	if (not values or #values <= 1 or (labels and #values ~= #labels)) then
		self.linePool:ReleaseAll();
		self.pointPool :ReleaseAll();
		return; 
	end

	self.Title:SetText(title or "");
	self.Title:SetPoint("TOPLEFT", self, self.padding.left, -self.padding.top);

	if (labels) then
		local label = self.labelPool:Acquire();
		label.Text:SetText(labels[1]);
		label:SetSize(label.Text:GetSize());
		label:SetPoint("BOTTOMRIGHT", self, -self.padding.right, self.padding.bottom);
		label:Show();
		
		label= self.labelPool:Acquire();
		label.Text:SetText(labels[#labels]);
		label:SetSize(label.Text:GetSize());
		label:SetPoint("BOTTOMLEFT", self, self.padding.left, self.padding.bottom);
		label:Show();
	end
	
	local numValues = #values;
	
	local maxValue = 0;
	for i = 1, numValues do
		local value = values[i];
		if (value > maxValue) then 
			maxValue = value;
		end
	end

	-- Why are you like this? Stop it.
	if (maxValue == math.huge) then return; end
	local labelHeight = self:GetLabelAreaHeight();
	local graphWidth = self:GetWidth() - self.padding.left - self.padding.right;
	local graphHeight = self:GetHeight() - self.padding.top - self.padding.bottom - labelHeight;

	local numScaleLines = 3;
	local scaleValue = 1;
	if(maxValue <= 10) then
		maxValue = 10;
		scaleValue = 5;
	elseif(maxValue <= 100) then
		maxValue = 100;
		scaleValue = 50;
	elseif(maxValue <= 500) then
		maxValue = 500;
		scaleValue = 250;
	elseif(maxValue <= 1000) then
		maxValue = 1000;
		numScaleLines = 5;
		scaleValue = 250;
	else
		maxValue = ceil(maxValue/1000)*1000;
		numScaleLines = maxValue / 1000 + 1;
		scaleValue = 1000;
	end
	
	self:DrawScaleLines(numScaleLines, scaleValue);
	
	if (self.Title:GetText() ~= "") then
		graphHeight = graphHeight - self.Title:GetStringHeight()  - self.padding.top;
	end
	local gapDistance = graphWidth / (numValues-1);
	local line;

	if (#values == self.pointPool.numActiveObjects) then
		self.isShiftingPoints = true;
		self.shiftcurrent = 0;
		
		for i = 1, self.pointPool.numActiveObjects do
			local point = self.points[i];
			local oldY = select(5, point:GetPoint(1))
			local value = values[i];
			local newY =  graphHeight * (value/maxValue) + self.padding.bottom + labelHeight;
			point:SetValue(value, labels and labels[i]);
			point.oldY = oldY;
			point.newY = newY;
		end
		
		return;
	end

	wipe(self.points);
	wipe(self.lines);
	self.linePool:ReleaseAll();
	self.pointPool :ReleaseAll();
	
	for i = 1, numValues do
		local value = values[i];
		local x = graphWidth - (i-1) * gapDistance + self.padding.left;
		local y = graphHeight * (value/maxValue) + self.padding.bottom + labelHeight;
		-- Set end point of previous line
		if (line) then
			line.Fill:SetEndPoint("BOTTOMLEFT", self, x, y);
		end
		
		if (i < numValues) then
			line = self.linePool:Acquire();
			tinsert(self.lines, line);
			line:SetAllPoints();
			line.Fill:SetStartPoint("BOTTOMLEFT", self, x, y);
			line:Show();
			line.Fill:Show();
		end
		
		local point = self.pointPool:Acquire();
		point:SetPoint("CENTER", self, "BOTTOMLEFT", x, y);
		point:SetValue(value, labels and labels[i]);
		point:Show();
		tinsert(self.points, point);
	end
end


WQTU_GraphFrameMixin = {};

local function InitFilterButton(button, options, ddFrame)
	local selectedValue = button.selectedValue;
	local info = ddFrame:CreateButtonInfo();
	info.func = function(ddButton, selected) 
			if(selected ~= selectedValue) then
				button.selectedValue = selected;
				button:SetDisplayText(options[selected]);
				button:GetParent():CreateButtons();
			end
		end
	
	for k, option in pairs(options) do
		info.text = option;
		info.arg1 = k;
		info.value = k;
		if k == selectedValue then
			info.checked = 1;
		else
			info.checked = nil;
		end
		ddFrame:AddButton(info);
	end
end

function WQTU_GraphFrameMixin:OnLoad()
	self.buttonPool = CreateFramePool("BUTTON", self, "WQTU_GraphButtonTemplate");
	
	self.factionButton = ADD:CreateMenuTemplate("WQTU_GraphFactionButton", self);
	self.factionButton:SetHeight(22);
	self.factionButton:SetPoint("TOPLEFT", self.Graph, "BOTTOMLEFT", 10, -10);
	self.factionButton:SetPoint("RIGHT", self.Graph, "CENTER", -3, 0);
	self.factionButton.selectedValue = 1;
	self.factionButton:SetDisplayText(_V["HISTORY_SORT_FACTION"][1]);
	ADD:LinkDropDown(self.factionButton, function(...) InitFilterButton(self.factionButton, _V["HISTORY_SORT_FACTION"], ...) end, nil, nil, nil, nil, "LIST");

	self.scopeButton = ADD:CreateMenuTemplate("WQTU_GraphScopeButton", self);
	self.scopeButton:SetHeight(22);
	self.scopeButton:SetPoint("TOPRIGHT", self.Graph, "BOTTOMRIGHT", -10, -10);
	self.scopeButton:SetPoint("LEFT", self.Graph, "CENTER", 3, 0);
	self.scopeButton.selectedValue = 1;
	self.scopeButton:SetDisplayText(_V["HISTORY_FILTER_SCOPE"][1]);
	ADD:LinkDropDown(self.scopeButton, function(...) InitFilterButton(self.scopeButton, _V["HISTORY_FILTER_SCOPE"], ...) end, nil, nil, nil, nil, "LIST");
end

function WQTU_GraphFrameMixin:AddButton(index, offsetx, offsetY)
	if (not index) then return; end
	local rewardInfo = WQTU_Utilities:GetRewardInfo(index);
	if (not rewardInfo or rewardInfo.isMissingData) then return; end
	offsetx = offsetx or 0;
	offsetY = offsetY or 0;
	local button = self.buttonPool:Acquire();
	local numObjects = self.buttonPool.numActiveObjects - 1;
	local width = button:GetWidth() + 5;
	local height = button:GetHeight() + 5;
	local xPos = width * (numObjects % 3);
	local yPos = -height * floor(numObjects / 3);
	button.index = index;
	button:SetPoint("TOPLEFT", self, xPos + offsetx, yPos + offsetY);
	button:SetRewardIndex(index)
	button:Show()
end

function WQTU_GraphFrameMixin:CreateButtons()
	self.buttonPool:ReleaseAll();
	local t = date("*t", time());
	local timeStamp = time({["year"] = t.year, ["month"] = t.month, ["day"] = t.day});
	
	local scopeId = self.scopeButton.selectedValue;
	local rewardIndexes = {};
	for i = 0, HISTORY_DAYS-1 do
		local history = WQTU.settings.history[timeStamp - i * 86400];
		CallFunctionOnHistory(history, function(index) if (not rewardIndexes[index]) then rewardIndexes[index] = true; end  end, self.factionButton.selectedValue, self.scopeButton.selectedValue);
	end
	
	local sortedIndexes = {};
	for index in pairs(rewardIndexes) do
		tinsert(sortedIndexes, index);
	end
	
	table.sort(sortedIndexes, function(a, b) 
			local infoA = WQTU_Utilities:GetRewardInfo(a);
			local infoB = WQTU_Utilities:GetRewardInfo(b);
			if (not infoA or not infoB) then
				if(infoA == infoB) then
					return a < b;
				end
				return infoA and not infoB;
			end
			
			if (infoA.isMissingData ~= infoB.isMissingData) then
				return not infoA.isMissingData and infoB.isMissingData;
			end
			return infoA.name < infoB.name;
		end);

	
	local buttonsPerRow = math.max(math.min(ceil(#sortedIndexes / GRAPH_MAX_BUTTON_ROWS), 6), 1);
	local sidePadding = 10;
	local buttonPadding = 5;
	local usableWidth = self:GetWidth() - 2*sidePadding;
	local widthPerButton = (usableWidth - (buttonPadding * (buttonsPerRow - 1))) / buttonsPerRow
	local offsetY = -WQTU_Graph:GetHeight() - 45;
	
	for k, index in ipairs(sortedIndexes) do
		-- Failsafe Let's hope no one gets more than 54 different rewards
		if (k <= buttonsPerRow * GRAPH_MAX_BUTTON_ROWS) then
			local rewardInfo = WQTU_Utilities:GetRewardInfo(index);
			if (rewardInfo and not rewardInfo.isMissingData) then
				local button = self.buttonPool:Acquire();
				local numObjects = self.buttonPool.numActiveObjects - 1;
				button:SetWidth(widthPerButton);
				local width = button:GetWidth() + buttonPadding;
				local height = button:GetHeight() + buttonPadding;
				local xPos = width * (numObjects % buttonsPerRow);
				local yPos = -height * floor(numObjects / buttonsPerRow);
				button.index = index;
				button:SetPoint("TOPLEFT", self, xPos + sidePadding, yPos + offsetY);
				button:SetRewardIndex(index)
				button:Show()
			end
		end
	end
	
	self:UpdateGraph();
	
	wipe(sortedIndexes);
	wipe(rewardIndexes);
end

function WQTU_GraphFrameMixin:UpdateGraph(index)
	index = index or self.index;
	
	local t = date("*t", time());
	local timeStamp = time({["year"] = t.year, ["month"] = t.month, ["day"] = t.day});
	local labels = {};
	if (not index) then
		local values = {};
		for i=0, HISTORY_DAYS-1 do
			tinsert(values, 0);
			tinsert(labels,  date("%B %d", timeStamp - i*SECONDS_PER_DAY));
		end
		WQTU_Graph:DisplayValues(values, "\n", labels);
		return;
	end

	for button in self.buttonPool:EnumerateActive() do
		button:SetBorderHighlighted(button.index == index);
	end
	
	local rewardInfo = WQTU_Utilities:GetRewardInfo(index);
	if (not rewardInfo) then return end;
	
	local totalAmount = 0;
	
	local rewardValues = {};
	
	local factionFilterId = self.factionButton.selectedValue;
	local scopeFilterId = self.scopeButton.selectedValue;
	for i = 0, HISTORY_DAYS-1 do
		local ts = timeStamp - i * 86400;
		tinsert(labels, date("%B %d", ts));
		tinsert(rewardValues, GetRewardHistory(ts, index, factionFilterId, scopeFilterId));
	end
	for i = 1, #rewardValues do
		totalAmount = totalAmount + rewardValues[i];
	end
	
	local titleText = FORMAT_REWARD_AMOUNT:format(rewardInfo.texture, rewardInfo.name, totalAmount);
	WQTU_Graph:DisplayValues(rewardValues, titleText, labels)
	self.index = index;
end

WQTU_CoreMixin = {};

function WQTU_CoreMixin:OnLoad()
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	
	self.updateTicker = C_Timer.NewTicker(0.5, function() 
			if (WorldMapFrame:IsShown() and (GetUnitSpeed("player") > 0 or UnitOnTaxi("player") == 1 or C_LossOfControl.GetActiveLossOfControlDataCount() > 0)) then
				UpdateQuestDistances();
				WQT_QuestScrollFrame:ApplySort();
				WQT_QuestScrollFrame:DisplayQuestList();
			end
		end);
end

function WQTU_CoreMixin:OnEvent(event, ...)
	if (event == "GET_ITEM_INFO_RECEIVED") then
		local itemId, success = ...;
		if (success and _rewardInfoCache["item"][itemId] and _rewardInfoCache["item"][itemId].isMissingData and WQTU_GraphFrame:IsShown()) then
			WQTU_GraphFrame:CreateButtons();
		end
	end
end

WQTU_TallyListMixin = {};

function WQTU_TallyListMixin:OnLoad()
	self.rewards = {};
	self.sortedRewards = {};
	
	self.framePool = CreateFramePool("BUTTON", self, "WQTU_TallyTemplate");
	self.previousEntry = nil;
	self.displayIndex = 1;
end

function WQTU_TallyListMixin:ChangeIndex(delta)
	self.displayIndex = self.displayIndex + delta;
	
	self:ShowRewards();
end

function WQTU_TallyListMixin:Collapse(value)
	for frame, v in pairs(self.framePool.activeObjects) do
		local collapse = (value or frame.amount == "")
		frame:SetWidth(collapse and TALLY_WIDTH_COLLAPSED or TALLY_WIDTH);
		frame.Amount:SetAlpha(collapse and 0 or 1);
	end
end

function WQTU_TallyListMixin:TallyRewards()
	wipe(self.sortedRewards);
	-- Reset rewards
	for k, reward in pairs(self.rewards) do
		reward.amount = 0;
		wipe(reward.quests)
	end

	-- Calculate everything
	for k, questInfo in ipairs(WQT_QuestScrollFrame.questListDisplay) do
		WQTU_Utilities:AddQuestInfoRewardsToList(self.rewards, questInfo, true);
	end
	
	-- Transfer relevant to sortable list
	for k, reward in pairs(self.rewards) do
		if(reward.amount > 0) then
			tinsert(self.sortedRewards, reward);
		end
	end
	
	table.sort(self.sortedRewards, function(a, b)
			local priorityA = _priorities[a.rewardType];
			local priorityB = _priorities[b.rewardType];
			if (priorityA ~= priorityB) then
				return priorityA < priorityB;
			end
			return a.name < b.name;
		end)
end

function WQTU_TallyListMixin:AddEntry(name, texture, amount, quests, quality, delta, disable)
	local entry = self.framePool:Acquire();
	local color = ITEM_QUALITY_COLORS[quality or 1].color;
	delta = delta or 0;
	
	entry.delta = delta;
	entry.name = name;
	entry.amount = amount;
	entry.quests = quests;
	entry.color = color;
	entry.Icon:SetTexture(texture);
	entry.Icon:SetDesaturated(disable);
	entry.Amount:SetText(amount);
	entry:SetEnabled(not disable);
	
	entry.BG:SetVertexColor(color:GetRGB());
	entry.BGCap:SetVertexColor(color:GetRGB());
	entry.Ring:SetVertexColor(color:GetRGB());
	
	
	if (self.previousEntry) then
		entry:SetPoint("TOPLEFT", self.previousEntry, "BOTTOMLEFT", 0, -1);
	else
		local offset = 0;
		if delta < 0 then
			offset = entry:GetHeight() + 1;
		end
		entry:SetPoint("TOPLEFT", 0, offset);
	end
	entry:Show();

	self.previousEntry = entry;
end

function WQTU_TallyListMixin:ShowRewards()
	self.framePool:ReleaseAll();
	self.previousEntry = nil;

	if (#self.sortedRewards == 0) then 
		WQT_WorldMapContainer.margins.right = 0;
		return; 
	end
	WQT_WorldMapContainer.margins.right = TALLY_WIDTH;
	if(WorldMapFrame:IsMaximized()) then
		WQT_WorldMapContainer:ConstrainPosition();
	end
	
	self.displayIndex = max(self.displayIndex , 1);
	local maxIndex = max(#self.sortedRewards - MAX_NUM_TALLIES+1, 1);
	self.displayIndex = min(self.displayIndex , maxIndex);
	
	if (#self.sortedRewards  > MAX_NUM_TALLIES) then
		local numPrev = self.displayIndex - 1
		self:AddEntry("", 450907, numPrev == 0 and "" or "+"..numPrev, nil, 1, -1, self.displayIndex == 1);
	end
	
	local displayCount = 0;
	local earlyExit = false;
	local numShown = 0;
	for i = self.displayIndex, #self.sortedRewards do
		if (numShown == MAX_NUM_TALLIES) then
			earlyExit = true;
			break; 
		end
		local reward = self.sortedRewards[i];
		local amount = reward.name == WORLD_QUEST_REWARD_FILTERS_GOLD and floor(reward.amount/10000) or reward.amount;
		self:AddEntry(reward.name, reward.texture, amount, reward.quests, reward.quality);
		numShown = numShown + 1;
	end
	
	if (#self.sortedRewards  > MAX_NUM_TALLIES) then
		local numNext = #self.sortedRewards + 1 - numShown - self.displayIndex;
		self:AddEntry("", 450905,  numNext == 0 and "" or "+"..numNext, nil, 1, 1, not earlyExit);
	end
	
	self:Collapse(TallyAreaBlocked());
end

function WQTU_TallyListMixin:UpdateList()
	self:TallyRewards();
	self:ShowRewards();
end

function WQTU_TallyListMixin:HighlightQuests(quests, value)
	for i=1, #WQT_QuestScrollFrame.buttons do
		local button = WQT_QuestScrollFrame.buttons[i];
		button.Highlight:SetShown(quests and quests[button.questId] and value);
	end
	
	if (quests) then
		if (value) then
			for questId in pairs(quests) do
				WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(questId, true);
			end
		else
			for questId in pairs(quests) do
				WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(questId, false);
			end
		end
	end
	
end

local function AddToFilters(ddFrame)
	local level = ddFrame.level;
	local info = ddFrame:CreateButtonInfo();
	info.keepShownOnClick = false;	
	info.tooltipWhileDisabled = true;
	info.tooltipOnButton = true;
	info.motionScriptsWhileDisabled = true;
	info.disabled = nil;
	info.isNotRadio = true;
	
	local settings = WQTU.settings;
	if level == 1 then
		info.notCheckable = true;
		info.isNotRadio = nil;
		info.tooltipTitle = nil;
		info.tooltipText = nil;
		info.hasArrow = false;
		local newText = settings.updateSeen and "" or "|TInterface\\FriendsFrame\\InformationIcon:14|t ";
		
		info.text = newText .. _L["WHATS_NEW"];
		info.tooltipTitle = _L["WHATS_NEW"];
		info.tooltipText =  _L["WHATS_NEW_TT"];
		info.func = function()
						local scrollFrame = WQT_VersionFrame;
						local blockerText = scrollFrame.Text;
						
						blockerText:SetText(_V["LATEST_UPDATE"]);
						blockerText:SetHeight(blockerText:GetContentHeight());
						scrollFrame.limit = max(0, blockerText:GetHeight() - scrollFrame:GetHeight());
						scrollFrame.scrollBar:SetMinMaxValues(0, scrollFrame.limit)
						scrollFrame.scrollBar:SetValue(0);
						settings.updateSeen = true;
						
						WQT_WorldQuestFrame:ShowOverlayFrame(scrollFrame, 10, -18, -3, 3);
						
					end
		ddFrame:AddButton(info)
		
		info.text = _L["REWARD_GRAPH"];
		info.tooltipTitle = _L["REWARD_GRAPH"];
		info.tooltipText =  _L["REWARD_GRAPH_TT"];
		info.func = function()
						WQT_WorldQuestFrame:ShowOverlayFrame(WQTU_GraphFrame);
						WQTU_GraphFrame:CreateButtons();
					end
		ddFrame:AddButton(info)
	end
end


local function UpdateQuestsContinent()
	for k, questInfo in ipairs(WQT_QuestScrollFrame.questList) do
		if (questInfo.questId) then
			local mapInfo = WQT_Utils:GetMapInfoForQuest(questInfo.questId);
			local mapPos = CreateVector2D(questInfo.mapInfo.mapX, questInfo.mapInfo.mapY);
			questInfo.mapInfo.continent = C_Map.GetWorldPosFromMapPos(mapInfo.mapID, mapPos);
		end
	end
	WQT_QuestScrollFrame:UpdateQuestList();
end

------------------------------------
-- WQTU_DirectioLineMixin
------------------------------------ 
-- OnLoad()
-- OnEvent(event, ...)
-- UpdatePlayerPosition()	Update locations and continents used for drawing the line. Updates less than often other functions
-- UpdateLineVisibility()
-- UpdateLinePosition()		Positions the line. Happens OnUpdate of the world map

WQTU_DirectioLineMixin = {}

function WQTU_DirectioLineMixin:OnLoad()
	local mapChild = WorldMapFrame.ScrollContainer.Child;
	self:SetParent(mapChild);
	self:SetFrameLevel(3000);
	self:ClearAllPoints();
	self:SetAllPoints();
	
	self:RegisterEvent("PLAYER_STOPPED_MOVING");
	
	-- Updates the player direction
	self.updateTicker = C_Timer.NewTicker(0.5, function() 
			if (WorldMapFrame:IsShown() and (GetUnitSpeed("player") > 0 or UnitOnTaxi("player") == 1 or C_LossOfControl.GetActiveLossOfControlDataCount() > 0)) then
				self:UpdatePlayerPosition();
			end
		end);
		
	WorldMapFrame:HookScript("OnUpdate", function() 
			self:UpdateLinePosition();
		end)
		
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			self:UpdatePlayerPosition();
		end)
end

function WQTU_DirectioLineMixin:OnEvent(event, ...)
	if (event == "PLAYER_STOPPED_MOVING") then
		self:UpdatePlayerPosition();
	end
end

function WQTU_DirectioLineMixin:UpdatePlayerPosition()
	self.playerContinent = nil;
	self.playerWorldPos = nil;
	self.currentMapPlayerPos = nil;
	self.currentContinent = nil;

	local map = C_Map.GetBestMapForUnit("player");
	if (map) then
		local position = C_Map.GetPlayerMapPosition(map, "player");
		if (position and WorldMapFrame.mapID) then
			self.playerContinent, self.playerWorldPos = C_Map.GetWorldPosFromMapPos(map, position);
			self.currentMapPlayerPos = select(2, C_Map.GetMapPosFromWorldPos(self.playerContinent, self.playerWorldPos, WorldMapFrame.mapID));
			self.currentContinent = C_Map.GetWorldPosFromMapPos(WorldMapFrame.mapID, _nullVector);
		end
	end
	
	self.validPosition = self.playerContinent and self.currentMapPlayerPos and self.currentContinent and true or false;
	self:UpdateLineVisibility();
end

function WQTU_DirectioLineMixin:UpdateLineVisibility()
	local shouldShow = WQTU.settings.directionLine and self.validPosition;
	self.Line:SetShown(shouldShow);
end

function WQTU_DirectioLineMixin:UpdateLinePosition()
	if (not self.Line:IsShown() or not self.validPosition) then 
		return;
	end

	local facing = GetPlayerFacing();
	if (facing) then
		local mapScale = self:GetEffectiveScale();
		local scale = 0.5/mapScale;
		local degr = deg(facing)+90;
		local mapChild = WorldMapFrame.ScrollContainer.Child;
		local w, h = mapChild:GetSize();
		local startX = self.currentMapPlayerPos.x * w;
		local startY = (1-self.currentMapPlayerPos.y )* h;
		
		self.Line:ClearAllPoints();
		self.Line:SetStartPoint("BOTTOMLEFT", startX, startY);
		self.Line:SetEndPoint("BOTTOMLEFT", mapChild, startX + cos(degr)*12000*scale, startY + sin(degr)*12000*scale);
		self.Line:SetThickness(scale * 2);
	end
end



function WQTU:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WQTUDB", WQTU_DEFAULTS, true);
	self.settings = self.db.global;

	WQT_V = WQT_WorldQuestFrame.variables;
	WQT_V["WQT_SORT_OPTIONS"][SORT_DISTANCE] = "Distance";
	WQT_V["SORT_OPTION_ORDER"][SORT_DISTANCE] = { "distance", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title" };
	WQT_V["SORT_FUNCTIONS"]["distance"] = function(a, b)
			if (a.mapInfo.distance ~= b.mapInfo.distance) then
				return a.mapInfo.distance < b.mapInfo.distance;
			end
		end
	
	self.currentSort = WQT_Utils:GetSetting("general", "sortBy");
	
	-- Wipe expired history data
	local t = date("*t", time());
	local tsLimit = time({["year"] = t.year, ["month"] = t.month, ["day"] = t.day});
	tsLimit = tsLimit - SECONDS_PER_DAY * HISTORY_DAYS;
	for timeStamp in pairs(WQTU.settings.history) do
		if (timeStamp <= tsLimit) then
			WQTU.settings.history[timeStamp] = nil;
		end
	end
	
	-- Version change
	local currentVersion = GetAddOnMetadata(_addonName, "version");
	if (self.settings.versionCheck < currentVersion) then
		self.settings.updateSeen = false;
		self.settings.versionCheck = currentVersion;
	end
	
	if (_addon.debug and LDHDebug) then
		LDHDebug:Monitor(_addonName);
	end
end

function WQTU:OnEnable()
	WQTU_DirectLineFrame:UpdatePlayerPosition();
	
	WQT_WorldQuestFrame:RegisterCallback("InitSettings", AddToFilters);
	WQT_WorldQuestFrame:RegisterCallback("FilterQuestList", function() WQTU_TallyList:UpdateList() end);
	WQT_WorldQuestFrame:RegisterCallback("WorldQuestCompleted", function(questId, questInfo) WQTU_Utilities:AddQuestRewardsToHistory(questInfo) end);
	
	-- Replace quest zone text with distance when needed
	WQT_WorldQuestFrame:RegisterCallback("ListButtonUpdate", function(button) 
			if (WQT_Utils:GetSetting("general", "sortBy") == SORT_DISTANCE and WQT_Utils:GetSetting("list", "showZone")) then
				
				local text = UNKNOWN;
				local distance = button.questInfo.mapInfo.distance;
				WQT_Utils:GetSetting("list", "zone")
				if (distance and distance < math.huge) then
					text =  DISTANCE_FORMAT:format(floor(distance));
				end
				
				local showFactionIcon = WQT_Utils:GetSetting("list", "factionIcon");
				local showTypeIcon = WQT_Utils:GetSetting("list", "typeIcon");
				local fullTime = WQT_Utils:GetSetting("list", "fullTime");
				local extraSpace = showFactionIcon and 0 or 14;
				extraSpace = extraSpace + (showTypeIcon and 0 or 14);
				local timeWidth = extraSpace + (fullTime and 70 or 60);
				local zoneWidth = extraSpace + (fullTime and 80 or 90);
				button.Time:SetWidth(timeWidth)
				button.Extra:SetWidth(zoneWidth)
				
				button.Extra:SetText(text);
			end
		end);
	WQT_WorldQuestFrame:RegisterCallback("SortChanged", function(category) 
			WQTU.currentSort = category; 
			if (WQTU.currentSort == SORT_DISTANCE) then
				UpdateQuestsContinent();
				UpdateQuestDistances();
				WQT_QuestScrollFrame:ApplySort();
				WQT_QuestScrollFrame:DisplayQuestList();
			end
		end);
	WQT_WorldQuestFrame:RegisterCallback("QuestsLoaded", function() 
			if (WQTU.currentSort == SORT_DISTANCE) then
				UpdateQuestsContinent();
				UpdateQuestDistances();
				WQT_QuestScrollFrame:ApplySort();
				WQT_QuestScrollFrame:DisplayQuestList();
			end
		end);
		

	hooksecurefunc("ShowUIPanel", function(frame) 
			if (not WorldMapFrame:IsShown()) then return end
			WQTU_TallyList:Collapse(TallyAreaBlocked());
		end);

	hooksecurefunc("HideUIPanel", function(frame) 
			if (not WorldMapFrame:IsShown()) then return end
			WQTU_TallyList:Collapse(TallyAreaBlocked());
		end);

	
	
	local sortedTallies = {};
	for key, value in pairs(WQTU.settings.tallies) do
		local entry = {["key"] = key, ["label"] = _tallyLabels[key] or key};
		tinsert(sortedTallies, entry);
	end
	
	table.sort(sortedTallies, function(a, b) return a.label < b.label; end);
	
	for key, entry in ipairs(sortedTallies) do
		local value = WQTU.settings.tallies[entry.key];
		tinsert(_V["WQTU_SETTING_LIST"], {["type"] = WQT_V["SETTING_TYPES"].checkBox, ["categoryID"] = "WQTU_TALLIES", ["label"] = entry.label
				, ["valueChangedFunc"] = function(value) 
					WQTU.settings.tallies[entry.key] = value;
					WQTU_TallyList:UpdateList();
				end
				,["getValueFunc"] = function() return WQTU.settings.tallies[entry.key] end;
				})
				
	end
	wipe(sortedTallies);
	
	-- Add WQTU settings to WQT's list
	WQT_SettingsFrame:RegisterCategories(_V["WQTU_SETTINGS_CATEGORIES"])
	WQT_SettingsFrame:AddSettingList(_V["WQTU_SETTING_LIST"]);
end

WQTU_GraphButtonMixin = {}

function WQTU_GraphButtonMixin:OnClick()
	if (not self.index) then return end;
	self:GetParent():UpdateGraph(self.index);
end

function WQTU_GraphButtonMixin:SetBorderHighlighted(value)
	self.Art.SelectedLeft:SetAlpha(value and 0.75 or 0);
	self.Art.SelectedRight:SetAlpha(value and 0.75 or 0);
	self.Art.SelectedMiddle:SetAlpha(value and 0.75 or 0);
	if (value) then
		self.Art.HLLeft:SetAlpha(0);
		self.Art.HLRight:SetAlpha(0);
		self.Art.HLMiddle:SetAlpha(0);
	end
end

function WQTU_GraphButtonMixin:SetRewardIndex(index)
	self.index = index;
	local displayText = "";
	local useTiny = self:GetWidth() < 50;
	local rewardInfo = WQTU_Utilities:GetRewardInfo(index);
	if (rewardInfo and not useTiny) then
		displayText = FORMAT_REWARD:format(rewardInfo.texture, rewardInfo.name);
	end
	self.Art.Icon:SetAlpha(useTiny and 1 or 0);
	self.Art.Icon:SetTexture(rewardInfo.texture);
	self.Art.CustomText:SetAlpha(useTiny and 0 or 1);
	self.Art.CustomText:SetText(displayText);
	self.name = rewardInfo.name;
end

SLASH_WQTU1 = '/wqtu';
local function slashcmd(msg, editbox)

end
SlashCmdList["WQTU"] = slashcmd

