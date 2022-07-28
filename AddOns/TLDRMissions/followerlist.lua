local addonName = ...
local addon = _G[addonName]
addon.followerList = {}
addon = addon.followerList

local CAMPAIGN = TRACKER_HEADER_CAMPAIGN_QUESTS
local RENOWN = COVENANT_SANCTUM_TAB_RENOWN
local info = C_Map.GetMapInfo(1645)
local name = ""
if info then name = info.name end
local TORGHAST = name.." "..string.gsub(MYTHIC_PLUS_POWER_LEVEL, " %%d", "")

-- database of Garrison Follower IDs, from https://wowpedia.fandom.com/wiki/GarrFollowerID
local gDB = {
    [1208] = {["name"] = "Nadjia the Mistblade", covenantID = 2, source = CAMPAIGN,},
    [1209] = {["name"] = "General Draven", covenantID = 2, source = CAMPAIGN,},
    [1210] = {["name"] = "Theotar", covenantID = 2, source = CAMPAIGN,},
    [1213] = {["name"] = "Thela Soulsipper", covenantID = 2, source = TORGHAST.." "..1,},
    [1214] = {["name"] = "Dug Gravewell", covenantID = 2, source = TORGHAST.." "..3,},
    [1215] = {["name"] = "Nerith Darkwing", covenantID = 2, source = TORGHAST.." "..1,},
    [1216] = {["name"] = "Stonehuck", covenantID = 2, source = TORGHAST.." "..1,},
    [1217] = {["name"] = "Kaletar", covenantID = 2, source = TORGHAST.." "..2,},
    [1220] = {["name"] = "Ayeleth", covenantID = 2, source = TORGHAST.." "..3,},
    [1221] = {["name"] = "Teliah", covenantID = 1, source = TORGHAST.." "..3,},
    [1222] = {["name"] = "Kythekios", covenantID = 1, source = TORGHAST.." "..2,},
    [1223] = {["name"] = "Telethakas", covenantID = 1, source = TORGHAST.." "..3,},
    [1250] = {["name"] = "Rahel", covenantID = 2, source = RENOWN.." "..4,},
    [1251] = {["name"] = "Stonehead", covenantID = 2, source = RENOWN.." "..12,},
    [1252] = {["name"] = "Simone", covenantID = 2, source = RENOWN.." "..17,},
    [1253] = {["name"] = "Bogdan", covenantID = 2, source = RENOWN.." "..38,},
    [1254] = {["name"] = "Lost Sybille", covenantID = 2, source = RENOWN.." "..27,},
    [1255] = {["name"] = "Vulca", covenantID = 2, source = RENOWN.." "..33,},
    [1257] = {["name"] = "Meatball", covenantID = 0, source = TORGHAST.." "..4,},
    [1258] = {["name"] = "Mikanikos", covenantID = 1, source = CAMPAIGN,},
    [1259] = {["name"] = "Pelagos", covenantID = 1, source = CAMPAIGN,},
    [1260] = {["name"] = "Kleia", covenantID = 1, source = CAMPAIGN,},
    [1261] = {["name"] = "Plague Deviser Marileth", covenantID = 4, source = CAMPAIGN,},
    [1262] = {["name"] = "Bonesmith Heirmir", covenantID = 4, source = CAMPAIGN,},
    [1263] = {["name"] = "Emeni", covenantID = 4, source = CAMPAIGN,},
    [1264] = {["name"] = "Dreamweaver", covenantID = 3, source = CAMPAIGN,},
    [1265] = {["name"] = "Niya", covenantID = 3, source = CAMPAIGN,},
    [1266] = {["name"] = "Hunt-Captain Korayn", covenantID = 3, source = CAMPAIGN,},
    [1267] = {["name"] = "Hala", covenantID = 1, source = TORGHAST.." "..1,},
    [1268] = {["name"] = "Molako", covenantID = 1, source = TORGHAST.." "..1,},
    [1269] = {["name"] = "Ispiron", covenantID = 1, source = TORGHAST.." "..1,},
    [1270] = {["name"] = "Nemea", covenantID = 1, source = RENOWN.." "..4,},
    [1271] = {["name"] = "Pelodis", covenantID = 1, source = RENOWN.." "..4,},
    [1272] = {["name"] = "Sika", covenantID = 1, source = RENOWN.." "..12,},
    [1273] = {["name"] = "Clora", covenantID = 1, source = RENOWN.." "..17,},
    [1274] = {["name"] = "Disciple Kosmas", covenantID = 1, source = RENOWN.." "..38,},
    [1275] = {["name"] = "Bron", covenantID = 1, source = RENOWN.." "..33,},
    [1276] = {["name"] = "Apolon", covenantID = 1, source = RENOWN.." "..27,},
    [1277] = {["name"] = "Blisswing", covenantID = 3, source = TORGHAST.." "..4,},
    [1278] = {["name"] = "Duskleaf", covenantID = 3, source = TORGHAST.." "..1,},
    [1279] = {["name"] = "Karynmwylyann", covenantID = 3, source = TORGHAST.." "..1,},
    [1280] = {["name"] = "Chalkyth", covenantID = 3, source = TORGHAST.." "..3,},
    [1281] = {["name"] = "Lloth'wellyn", covenantID = 3, source = TORGHAST.." "..1,},
    [1282] = {["name"] = "Yira'lya", covenantID = 3, source = TORGHAST.." "..2,},
    [1283] = {["name"] = "Guardian Kota", covenantID = 3, source = RENOWN.." "..4,},
    [1284] = {["name"] = "Master Sha'lor", covenantID = 3, source = RENOWN.." "..17,},
    [1285] = {["name"] = "Te'zan", covenantID = 3, source = RENOWN.." "..12,},
    [1286] = {["name"] = "Qadarin", covenantID = 3, source = RENOWN.." "..27,},
    [1287] = {["name"] = "Watcher Vesperbloom", covenantID = 3, source = RENOWN.." "..33,},
    [1288] = {["name"] = "Groonoomcrooek", covenantID = 3, source = RENOWN.." "..38,},
    [1300] = {["name"] = "Secutor Mevix", covenantID = 4, source = RENOWN.." "..4,},
    [1301] = {["name"] = "Gunn Gorgebone", covenantID = 4, source = RENOWN.." "..12,},
    [1302] = {["name"] = "Rencissa the Dynamo", covenantID = 4, source = RENOWN.." "..17,},
    [1303] = {["name"] = "Khaliiq", covenantID = 4, source = RENOWN.." "..27,},
    [1304] = {["name"] = "Plaguey", covenantID = 4, source = RENOWN.." "..33,},
    [1305] = {["name"] = "Rathan", covenantID = 4, source = RENOWN.." "..38,},
    [1306] = {["name"] = "Gorgelimb", covenantID = 4, source = TORGHAST.." "..2,},
    [1307] = {["name"] = "Talethi", covenantID = 4, source = TORGHAST.." "..3,},
    [1308] = {["name"] = "Velkein", covenantID = 4, source = TORGHAST.." "..3,},
    [1309] = {["name"] = "Assembler Xertora", covenantID = 4, source = TORGHAST.." "..1,},
    [1310] = {["name"] = "Rattlebag", covenantID = 4, source = TORGHAST.." "..1,},
    [1311] = {["name"] = "Ashraka", covenantID = 4, source = TORGHAST.." "..1,},
    [1325] = {["name"] = "Croman", covenantID = 0, source = TORGHAST.." "..4,},
    [1326] = {["name"] = "Spore of Marasmius", covenantID = 3, source = TORGHAST.." "..5,},
    [1328] = {["name"] = "ELGU - 007", covenantID = 1, source = TORGHAST.." "..5,},
    [1329] = {["name"] = "Kiaranyka", covenantID = 1, source = TORGHAST.." "..5,},
    [1330] = {["name"] = "Ryuja Shockfist", covenantID = 4, source = TORGHAST.." "..5,},
    [1331] = {["name"] = "Kinessa the Absorbent", covenantID = 4, source = TORGHAST.." "..5,},
    [1332] = {["name"] = "Steadyhands", covenantID = 2, source = TORGHAST.." "..5,},
    [1333] = {["name"] = "Lassik Spinebender", covenantID = 2, source = TORGHAST.." "..5,},
    [1334] = {["name"] = "Lyra Hailstorm", covenantID = 4, source = RENOWN.." "..44,},
    [1335] = {["name"] = "Enceladus", covenantID = 4, source = RENOWN.." "..62,},
    [1336] = {["name"] = "Deathfang", covenantID = 4, source = RENOWN.." "..71,},
    [1337] = {["name"] = "Sulanoom", covenantID = 3, source = RENOWN.." "..44,},
    [1338] = {["name"] = "Elwyn", covenantID = 3, source = RENOWN.." "..62,},
    [1339] = {["name"] = "Yanlar", covenantID = 3, source = RENOWN.." "..71,},
    [1327] = {["name"] = "Ella", covenantID = 3, source = TORGHAST.." "..5,},
    [1341] = {["name"] = "Hermestes", covenantID = 1, source = RENOWN.." "..44,},
    [1342] = {["name"] = "Cromas the Mystic", covenantID = 1, source = RENOWN.." "..62,},
    [1343] = {["name"] = "Auric Spiritguide", covenantID = 1, source = RENOWN.." "..71,},
    [1345] = {["name"] = "Chachi the Artiste", covenantID = 2, source = RENOWN.." "..44,},
    [1346] = {["name"] = "Madame Iza", covenantID = 2, source = RENOWN.." "..62,},
    [1347] = {["name"] = "Lucia", covenantID = 2, source = RENOWN.." "..71,}, 
}

local FOLLOWER_BUTTON_HEIGHT = 56;
local CATEGORY_BUTTON_HEIGHT = 20;
local FOLLOWER_LIST_BUTTON_OFFSET = -6;
local FOLLOWER_LIST_BUTTON_INITIAL_OFFSET = -7;
local GARRISON_FOLLOWER_LIST_BUTTON_FULL_XP_WIDTH = 205;

local doOnce = true
function addon:Init()
    if not doOnce then return end
    doOnce = false
    
    -- This code was adapted from Blizzard_GarrisonSharedTemplates.lua
    
    local function newUpdateData(self)
    	local followerFrame = self:GetParent();
    	local followers = self.followers;
        followers = CopyTable(followers)
    	local followersList = self.followersList;
        followersList = CopyTable(followersList)
    	local categoryLabels = self.followersLabels;
        categoryLabels = CopyTable(categoryLabels)
    	local numFollowers = #followersList;
        
        --@@
        if self.followerType == 123 then
            local uncollectedFollowers = {}
            local nemea
            for garrFollowerID, data in pairs(gDB) do
                local known
                for _, follower in pairs(followers) do
                    if (garrFollowerID == follower.garrFollowerID) then
                        known = true
                        if (garrFollowerID == 1270) or (garrFollowerID == 1271) then
                            nemea = true
                        end
                        break
                    end
                end
                if (not known) and ((data.covenantID == 0) or (data.covenantID == C_Covenants.GetActiveCovenantID())) then
                    local continue = true
                    if (garrFollowerID == 1270) or (garrFollowerID == 1271) then
                        if nemea then continue = false end
                    end
                    if continue then
                        local info = C_Garrison.GetFollowerInfo(garrFollowerID)
                        info.source = data.source
                        info.status = GARRISON_FOLLOWER_ON_MISSION
                        table.insert(uncollectedFollowers, info)
                    end
                end
            end
            if #uncollectedFollowers > 0 then
                table.insert(followersList, 0)
                table.insert(categoryLabels, #followersList, FOLLOWERLIST_LABEL_UNCOLLECTED)
                for _, follower in pairs(uncollectedFollowers) do
                    table.insert(followers, follower)
                    table.insert(followersList, #followers)
                end
                numFollowers = #followersList
            end
        end
        --@@
        

    	local scrollFrame = self.listScroll;
    	local offset = HybridScrollFrame_GetOffset(scrollFrame);
    	local buttons = scrollFrame.buttons;
    	local numButtons = #buttons;
    	local showCounters = self.showCounters;
    	local canExpand = self.canExpand;
    	local totalHeight = 7;
    
    	for i = 1, numButtons do
    		local button = buttons[i];
    		local index = offset + i; -- adjust index
    		if ( index <= numFollowers and followersList[index] == 0 ) then
    			GarrisonFollowerList_SetButtonMode(self, button, "CATEGORY");
    			button.Category:SetText(categoryLabels[index]);
    			button:Show();
    		elseif ( index <= numFollowers ) then
    			local follower = followers[followersList[index]];
    
    			GarrisonFollowerList_SetButtonMode(self, button, "FOLLOWER");
    			button.Follower.DurabilityFrame:SetShown(follower.isTroop);
    
    			button.Follower.id = follower.followerID;
    			button.Follower.info = follower;
    			button.Follower.Name:SetText(follower.name);
    			if ( button.Follower.Class) then
    				button.Follower.Class:SetAtlas(follower.classAtlas);
    			end
    			button.Follower.Status:SetText(follower.status);
    			if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then
    				button.Follower.Status:SetTextColor(1, 0.1, 0.1);
    			else
    				button.Follower.Status:SetTextColor(0.698, 0.941, 1);
    			end
    			button.Follower.PortraitFrame:SetupPortrait(follower);
    
    			local abilityGridAreaWidth = GarrisonFollowerButton_UpdateCounters(self:GetParent(), button.Follower, follower, showCounters, followerFrame.lastUpdate);
    			if not showCounters then
    				--This should be used to replace counter width, as they're currently exclusive sets.
    				abilityGridAreaWidth = GarrisonFollowerButton_UpdateAutoSpells(self:GetParent(), button.Follower, follower);
    			end
    
    			if ( follower.isCollected ) then
    				-- have this follower
    				button.Follower.isCollected = true;
    				button.Follower.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
    				if( button.Follower.Class ) then
    					button.Follower.Class:SetDesaturated(false);
    					button.Follower.Class:SetAlpha(0.2);
    				end
    				if button.Follower.PortraitFrame.quality ~= Enum.GarrFollowerQuality.Title then
    					button.Follower.PortraitFrame.PortraitRingQuality:Show();
    				end
    				button.Follower.PortraitFrame.Portrait:SetDesaturated(false);
    				if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then
    					button.Follower.PortraitFrame.PortraitRingCover:Show();
    					button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.5);
    					button.Follower.BusyFrame:Show();
    					button.Follower.BusyFrame.Texture:SetColorTexture(unpack(GARRISON_FOLLOWER_INACTIVE_COLOR));
    				elseif ( follower.status ) then
    					button.Follower.PortraitFrame.PortraitRingCover:Show();
    					button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.5);
    					button.Follower.BusyFrame:Show();
    					button.Follower.BusyFrame.Texture:SetColorTexture(unpack(GARRISON_FOLLOWER_BUSY_COLOR));
    					-- get time remaining for follower
    					self:UpdateMissionRemainingTime(follower, button.Follower.Status);
    				else
    					button.Follower.PortraitFrame.PortraitRingCover:Hide();
    					button.Follower.BusyFrame:Hide();
    				end
    				if( button.Follower.DownArrow ) then
    					if ( canExpand ) then
    						button.Follower.DownArrow:SetAlpha(1);
    					else
    						button.Follower.DownArrow:SetAlpha(0);
    					end
    				end
    				-- adjust text position if we have additional text to show below name
    				local nameOffsetY = 0;
    				if (follower.status) then
    					nameOffsetY = nameOffsetY + 8;
    				end
    				-- show iLevel for max level followers
    				if (ShouldShowILevelInFollowerList(follower)) then
    					nameOffsetY = nameOffsetY + 9;
    					if (COLLAPSE_ORDER_HALL_FOLLOWER_ITEM_LEVEL_DISPLAY) then
    						button.Follower.ILevel:SetPoint("TOPLEFT", button.Follower.Name, "BOTTOMLEFT", 0, -1);
    						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "BOTTOMLEFT", -1, 1);
    					else
    						button.Follower.ILevel:SetPoint("TOPLEFT", button.Follower.Name, "BOTTOMLEFT", 0, -4);
    						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "BOTTOMLEFT", -1, -2);
    					end
    					button.Follower.ILevel:SetText(POWER_LEVEL_ABBR.." "..follower.iLevel);
    					button.Follower.ILevel:Show();
    				else
    					button.Follower.ILevel:SetText(nil);
    					button.Follower.ILevel:Hide();
    					button.Follower.Status:SetPoint("TOPLEFT", button.Follower.Name, "BOTTOMLEFT", 0, -2);
    				end
    
    				if (button.Follower.DurabilityFrame:IsShown()) then
    					nameOffsetY = nameOffsetY + 9;
    
    					if (follower.status) then
    						button.Follower.DurabilityFrame:SetPoint("TOPLEFT", button.Follower.Status, "BOTTOMLEFT", 0, -4);
    					elseif (ShouldShowILevelInFollowerList(follower)) then
    						button.Follower.DurabilityFrame:SetPoint("TOPLEFT", button.Follower.ILevel, "BOTTOMLEFT", 0, -6);
    					else
    						button.Follower.DurabilityFrame:SetPoint("TOPLEFT", button.Follower.Name, "BOTTOMLEFT", 0, -6);
    					end
    				end
    				button.Follower.Name:SetPoint("LEFT", button.Follower.PortraitFrame, "LEFT", 66, nameOffsetY);
    				button.Follower.Status:SetPoint("RIGHT", -abilityGridAreaWidth, 0);
    
    				if ( button.Follower.XPBar ) then
    					if (follower.xp == 0 or follower.levelXP == 0) then
    						button.Follower.XPBar:Hide();
    					else
    						button.Follower.XPBar:Show();
    						button.Follower.XPBar:SetWidth((follower.xp/follower.levelXP) * GARRISON_FOLLOWER_LIST_BUTTON_FULL_XP_WIDTH);
    					end
    				end
                else
    				-- don't have this follower
    				button.Follower.isCollected = nil;
    				button.Follower.Name:SetTextColor(0.5, 0.5, 0.5);
    				button.Follower.ILevel:SetText(nil);
                    if follower.source then
                        button.Follower.Status:SetText(string.format(RUNEFORGE_LEGENDARY_POWER_SOURCE_FORMAT, follower.source));
                    end
    				button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "TOPRIGHT", 0, 0);
    				if( button.Follower.Class ) then
    					button.Follower.Class:SetDesaturated(true);
    					button.Follower.Class:SetAlpha(0.1);
    				end
    				button.Follower.PortraitFrame.PortraitRingQuality:Hide();
    				button.Follower.PortraitFrame.Portrait:SetDesaturated(true);
    				button.Follower.PortraitFrame.PortraitRingCover:Show();
    				button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.6);
    				button.Follower.PortraitFrame:SetQuality(0);
    				if ( button.Follower.XPBar ) then
    					button.Follower.XPBar:Hide();
    				end
                    button.Follower.PortraitFrame.PortraitRingCover:Hide();
    				button.Follower.BusyFrame:Hide();
    			end
    
    			--if (canExpand and button.Follower.id == self.expandedFollower and button.Follower.id == followerFrame.selectedFollower) then
    			--	self:ExpandButton(button.Follower, self);
    			--else
    			--	self:CollapseButton(button.Follower);
    			--end
    
    			button:SetHeight(button.Follower:GetHeight());
    			if ( button.Follower.id == followerFrame.selectedFollower ) then
    				button.Follower.Selection:Show();
    			else
    				button.Follower.Selection:Hide();
    			end
    
    			if (follower.isTroop) then
    				button.Follower.DurabilityFrame:SetDurability(follower.durability, follower.maxDurability);
    			end
    
    			button:Show();
    		else
    			button:Hide();
    		end
        end
    
    	-- calculate the total height to pass to the HybridScrollFrame
    	for i = 1, numFollowers do
    		if (followersList[i] == 0) then
    			totalHeight = totalHeight + CATEGORY_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
    		else
    			totalHeight = totalHeight + FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
    		end
    	end
    	if (self.expandedFollower) then
    		totalHeight = totalHeight + self.expandedFollowerHeight - (FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET);
    	end
    
    	local displayedHeight = numButtons * scrollFrame.buttonHeight;
    	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
    
    	followerFrame.lastUpdate = GetTime();
    end
    
    local o = GarrisonFollowerList_GetTopButton
    function GarrisonFollowerList_GetTopButton(self, offset)
        if not((self == GarrisonLandingPageFollowerList) or (self == CovenantMissionFrame.FollowerList)) then return o(self, offset) end
        
    	local followerFrame = self;
    	local buttonHeight = followerFrame.listScroll.buttonHeight;
    	local expandedFollower = followerFrame.expandedFollower;
    	local followers = followerFrame.followers;
        
        --@@
        local uncollectedFollowers = {}
        local nemea
        for garrFollowerID, data in pairs(gDB) do
            local known
            for _, follower in pairs(followers) do
                if (garrFollowerID == follower.garrFollowerID) then
                    known = true
                    if (garrFollowerID == 1270) or (garrFollowerID == 1271) then
                        nemea = true
                    end
                    break
                end
            end
            if (not known) and ((data.covenantID == 0) or (data.covenantID == C_Covenants.GetActiveCovenantID())) then
                local continue = true
                if (garrFollowerID == 1270) or (garrFollowerID == 1271) then
                    if nemea then continue = false end
                end
                if continue then
                    local info = C_Garrison.GetFollowerInfo(garrFollowerID)
                    table.insert(uncollectedFollowers, info)
                end
            end
        end
        --@@
        
    	local sortedList = followerFrame.followersList;
    	local totalHeight = 0;
    	for i = 1, #sortedList do
    		local height;
    		if ( sortedList[i] == 0 ) then
    			height = CATEGORY_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
    		elseif ( followers[sortedList[i]].followerID == expandedFollower ) then
    			height = followerFrame.expandedFollowerHeight;
    		else
    			height = FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
    		end
    		totalHeight = totalHeight + height;
    		if ( totalHeight > offset ) then
    			return i - 1, height + offset - totalHeight;
    		end
    	end
        
        if #uncollectedFollowers > 0 then
            local height = CATEGORY_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET
            totalHeight = totalHeight + height
            if ( totalHeight > offset ) then
    			return #sortedList, height + offset - totalHeight;
    		end
        end
        
        for i = 1, #uncollectedFollowers do
    		local height;
    		height = FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
    		totalHeight = totalHeight + height;
    		if ( totalHeight > offset ) then
    			return (i + #sortedList), height + offset - totalHeight;
    		end
    	end
        
    	--We're scrolled completely off the bottom
    	return #followers, 0;
    end
    
    GarrisonLandingPageFollowerList.UpdateData = newUpdateData
    CovenantMissionFrame.FollowerList.UpdateData = newUpdateData
end
