		-------------------------------------------------
		-- Paragon Reputation 1.34 by Fail US-Ragnaros --
		-------------------------------------------------

		  --[[	  Special thanks to Ammako for
				  helping me with the vars and
				  the options.						]]--

local ADDON_NAME,ParagonReputation = ...
local PR = ParagonReputation

local ACTIVE_TOAST = false
local WAITING_TOAST = {}

local PARAGON_QUESTS = { --[questID] = factionID
	--Legion
		[48976] = 2170, -- Argussian Reach
		[46777] = 2045, -- Armies of Legionfall
		[48977] = 2165, -- Army of the Light
		[46745] = 1900, -- Court of Farondis
		[46747] = 1883, -- Dreamweavers
		[46743] = 1828, -- Highmountain Tribes
		[46748] = 1859, -- The Nightfallen
		[46749] = 1894, -- The Wardens
		[46746] = 1948, -- Valarjar
	
	--Battle for Azeroth
		--Neutral
		[54453] = 2164, --Champions of Azeroth
		[58096] = 2415, --Rajani
		[55348] = 2391, --Rustbolt Resistance
		[54451] = 2163, --Tortollan Seekers
		[58097] = 2417, --Uldum Accord
		
		--Horde
		[54460] = 2156, --Talanji's Expedition
		[54455] = 2157, --The Honorbound
		[53982] = 2373, --The Unshackled
		[54461] = 2158, --Voldunai
		[54462] = 2103, --Zandalari Empire
		
		--Alliance
		[54456] = 2161, --Order of Embers
		[54458] = 2160, --Proudmoore Admiralty
		[54457] = 2162, --Storm's Wake
		[54454] = 2159, --The 7th Legion
		[55976] = 2400, --Waveblade Ankoan
	
	--Shadowlands
		[61100] = 2413, --Court of Harvesters
		[61097] = 2407, --The Ascended
		[61095] = 2410, --The Undying Army
		[61098] = 2465, --The Wild Hunt
}

local PARAGON_REWARDS = {
	
	--Legion
		[2170] = { -- Argussian Reach
			cache = 152922,
		}, 
		[2045] = { -- Armies of Legionfall
			cache = 152108,
			rewards = {
				{ -- Orphaned Felbat
					type = "PET",
					itemID = 147841,
				},
			},
		}, 
		[2165] = { -- Army of the Light
			cache = 152923,
			rewards = {
				{ -- Holy Lightsphere
					type = "TOY",
					itemID = 153182,
				},
				{ -- Avenging Felcrushed
					type = "MOUNT",
					itemID = 153044,
					mountID = 985,
				},
				{ -- Blessed Felcrushed
					type = "MOUNT",
					itemID = 153043,
					mountID = 984,
				},
				{ -- Glorious Felcrushed
					type = "MOUNT",
					itemID = 153042,
					mountID = 983,
				},
			},
		}, 
		[1900] = { -- Court of Farondis
			cache = 152102,
			rewards = {
				{ -- Cloudwing Hippogryph
					type = "MOUNT",
					itemID = 147806,
					mountID = 943,
				},
			},
		}, 
		[1883] = { -- Dreamweavers
			cache = 152103,
			rewards = {
				{ -- Wild Dreamrunner
					type = "MOUNT",
					itemID = 147804,
					mountID = 942,
				},
			},
		}, 
		[1828] = { -- Highmountain Tribes
			cache = 152104,
			rewards = {
				{ -- Highmountain Elderhorn
					type = "MOUNT",
					itemID = 147807,
					mountID = 941,
				},
			},
		}, 
		[1859] = { -- The Nightfallen
			cache = 152105,
			rewards = {
				{ -- Leywoven Flying Carpet
					type = "MOUNT",
					itemID = 143764,
					mountID = 905,
				},
			},
		}, 
		[1894] = { -- The Wardens
			cache = 152107,
			rewards = {
				{ -- Sira's Extra Cloak
					type = "TOY",
					itemID = 147843,
				},
			},
		}, 
		[1948] = { -- Valarjar
			cache = 152106,
			rewards = {
				{ -- Valarjar Stormwing
					type = "MOUNT",
					itemID = 147805,
					mountID = 944,
				},
			},
		}, 
	
	--Battle for Azeroth
		--Neutral
		[2164] = { --Champions of Azeroth
			cache = 166298,
			rewards = {
				{ -- Azerite Firework Launcher
					type = "TOY",
					itemID = 166877,
				},
			},
		}, 
		[2415] = { --Rajani
			cache = 174483,
			rewards = {
				{ -- Jade Defender
					type = "PET",
					itemID = 174479,
				},
			},
		},
		[2391] = { --Rustbolt Resistance
			cache = 170061,
			rewards = {
				{ -- Blueprint: Microbot XD
					type = "QUEST",
					itemID = 169171,
					questID = 55079,
				},
				{ -- Blueprint: Holographic Digitalization Relay
					type = "QUEST",
					itemID = 168906,
					questID = 56086,
				},
				{ -- Blueprint: Rustbolt Resistance Insignia
					type = "QUEST",
					itemID = 168494,
					questID = 55073,
				},
			},
		},
		[2163] = { --Tortollan Seekers
			cache = 166245,
			rewards = {
				{ -- Bowl of Glowing Pufferfish
					type = "TOY",
					itemID = 166704,
				},
			},
		},
		[2417] = { --Uldum Accord
			cache = 174484,
			rewards = {
				{ -- Cursed Dune Watcher
					type = "PET",
					itemID = 174481,
				},
			},
		},
		
		--Horde
		[2156] = { --Talanji's Expedition
			cache = 166282,
			rewards = {
				{ -- Pair of Tiny Bat Wings
					type = "PET",
					itemID = 166716,
				},
				{ -- For da Blood God!
					type = "TOY",
					itemID = 166308,
				},
			},
		},
		[2157] = { --The Honorbound
			cache = 166299,
			rewards = {
				{ -- Rallying War Banner
					type = "TOY",
					itemID = 166879,
				},
			},
		},
		[2373] = { --The Unshackled
			cache = 169940,
			rewards = {
				{ -- Royal Snapdragon
					type = "MOUNT",
					itemID = 169198,
					mountID = 1237,
				},
				{ -- Flopping Fish
					type = "TOY",
					itemID = 170203,
				},
				{ -- Memento of the Deeps
					type = "TOY",
					itemID = 170469,
				},
			},
		},
		[2158] = { --Voldunai
			cache = 166290,
			rewards = {
				{ -- Goldtusk Inn Breakfast Buffet
					type = "TOY",
					itemID = 166703,
				},
				{ -- Meerah's Jukebox
					type = "TOY",
					itemID = 166880,
				},
			},
		},
		[2103] = { --Zandalari Empire
			cache = 166292,
			rewards = {
				{ -- Warbeast Kraal Dinner Bell
					type = "TOY",
					itemID = 166701,
				},
			},
		},
		
		--Alliance
		[2161] = { --Order of Embers
			cache = 166297,
			rewards = {
				{ -- Cobalt Raven Hatchling
					type = "PET",
					itemID = 166718,
				},
				{ -- Bewitching Tea Set
					type = "TOY",
					itemID = 166808,
				},
			},
		},
		[2160] = { --Proudmoore Admiralty
			cache = 166295,
			rewards = {
				{ -- Albatross Feather
					type = "PET",
					itemID = 166714,
				},
				{ -- Proudmoore Music Box
					type = "TOY",
					itemID = 166702,
				},
			},
		},
		[2162] = { --Storm's Wake
			cache = 166294,
			rewards = {
				{ -- Violet Abyssal Eel
					type = "PET",
					itemID = 166719,
				},
			},
		},
		[2159] = { --The 7th Legion
			cache = 166300,
			rewards = {
				{ -- Rallying War Banner
					type = "TOY",
					itemID = 166879,
				},
			},
		},
		[2400] = { --Waveblade Ankoan
			cache = 169939,
			rewards = {
				{ -- Royal Snapdragon
					type = "MOUNT",
					itemID = 169198,
					mountID = 1237,
				},
				{ -- Flopping Fish
					type = "TOY",
					itemID = 170203,
				},
				{ -- Memento of the Deeps
					type = "TOY",
					itemID = 170469,
				},
			},
		},
	
	--Shadowlands
		[2413] = { --Court of Harvesters
			cache = 180648,
			rewards = {
				{ -- Stonewing Dredwing Pup
					type = "PET",
					itemID = 180601,
				},
			},
		},
		[2407] = { --The Ascended
			cache = 180647,
			rewards = {
				{ -- Larion Cub
					type = "PET",
					itemID = 184399,
				},
				{ -- Malfunctioning Goliath Gauntlet
					type = "TOY",
					itemID = 184396,
				},
				{ -- Mark of Purity
					type = "TOY",
					itemID = 184435,
				},
			},
		},
		[2410] = { --The Undying Army
			cache = 180646,
			rewards = {
				{ -- Reins of the Colossal Slaughterclaw
					type = "MOUNT",
					itemID = 182081,
					mountID = 1350,
				},
				{ -- Micromancer's Mystical Cowl
					type = "PET",
					itemID = 181269,
				},
				{ -- Infested Arachnid Casing
					type = "TOY",
					itemID = 184495,
				},
			},
		},
		[2465] = { --The Wild Hunt
			cache = 180649,
			rewards = {
				{ -- Amber Ardenmoth
					type = "MOUNT",
					itemID = 183800,
					mountID = 1428,
				},
				{ -- Hungry Burrower
					type = "PET",
					itemID = 180635,
				},
			},
		},
}

-- [Reputation Watchbar] Color the Reputation Watchbar by the settings. (Thanks Hoalz)
hooksecurefunc(ReputationBarMixin,"Update",function(self)
	local _,_,_,_,_,factionID = GetWatchedFactionInfo()
	if factionID and C_Reputation.IsFactionParagon(factionID) then
		self:SetBarColor(unpack(PR.DB.value))
	end
end)

-- [ParagonTooltip] Setup the Paragon Tooltip accordingly.
hooksecurefunc("ReputationParagonFrame_SetupParagonTooltip",function(self)
	local _,_,rewardQuestID,hasRewardPending = C_Reputation.GetFactionParagonInfo(self.factionID)
	if hasRewardPending then
		local factionName = GetFactionInfoByID(self.factionID)
		local questIndex = C_QuestLog.GetLogIndexForQuestID(rewardQuestID)
		local description = GetQuestLogCompletionText(questIndex) or ""
		EmbeddedItemTooltip:SetText(PR.L["PARAGON"])
		EmbeddedItemTooltip:AddLine(description,HIGHLIGHT_FONT_COLOR.r,HIGHLIGHT_FONT_COLOR.g,HIGHLIGHT_FONT_COLOR.b,1)
		GameTooltip_AddQuestRewardsToTooltip(EmbeddedItemTooltip,rewardQuestID)
		EmbeddedItemTooltip:Show()
	else
		EmbeddedItemTooltip:Hide()
	end
end)

-- [Pet Rewards] Check if a Pet Reward is already owned.
local ParagonPetSearchTooltip = CreateFrame("GameTooltip","ParagonPetSearchTooltip",nil,"GameTooltipTemplate")
local ParagonIsPetOwned = function(link)
	ParagonPetSearchTooltip:SetOwner(UIParent,"ANCHOR_NONE")
	ParagonPetSearchTooltip:SetHyperlink(link)
	for index=3,5 do
		local text = _G["ParagonPetSearchTooltipTextLeft"..index] and _G["ParagonPetSearchTooltipTextLeft"..index]:GetText()
		if text and string.find(text,"(%d)/(%d)") then
			return true
		end
	end
	return false
end

-- [GameTooltip] Add Paragon Rewards to the Tooltip.
local function AddParagonRewardsToTooltip(tooltip,rewards)
	if rewards then
		for index,data in ipairs(rewards) do
			local collected
			local name,link,quality,_,_,_,_,_,_,icon = GetItemInfo(data.itemID)
			if data.type == "MOUNT" then
				collected = select(11,C_MountJournal.GetMountInfoByID(data.mountID))
			elseif data.type == "PET" and link then
				collected = ParagonIsPetOwned(link)
			elseif data.type == "TOY" then
				collected = PlayerHasToy(data.itemID)
			elseif data.type == "QUEST" then
				collected = C_QuestLog.IsQuestFlaggedCompleted(data.questID)
			end
			if name then
				local color = ITEM_QUALITY_COLORS[quality]
				tooltip:AddLine(string.format("%s|T%d:0|t %s",collected and "|A:common-icon-checkmark:14:14|a " or "|A:common-icon-redx:14:14|a ",icon,name),color.r,color.g,color.b)
			else
				tooltip:AddLine(ERR_TRAVEL_PASS_NO_INFO,1,0,0)
			end
		end
	else
		tooltip:AddLine(VIDEO_OPTIONS_NONE,1,0,0)
	end
end

-- [GameTooltip] Show the GameTooltip with the Item Reward on mouseover. (Thanks Brudarek)
function ParagonReputation:Tooltip(self,event)
	if not self.factionID or not PARAGON_REWARDS[self.factionID] then return end
	if event == "OnEnter" then
		local name,_,quality = GetItemInfo(PARAGON_REWARDS[self.factionID].cache)
		if name ~= nil then
			GameTooltip:SetOwner(self,"ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT",self,"BOTTOMRIGHT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(self.name)
			local color = ITEM_QUALITY_COLORS[quality]
			GameTooltip:AddLine(name..self.count,color.r,color.g,color.b)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(GUILD_TAB_REWARDS)
			AddParagonRewardsToTooltip(GameTooltip,PARAGON_REWARDS[self.factionID].rewards)
			GameTooltip:Show()
		end
	elseif event == "OnLeave" then
		GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
		GameTooltip:Hide()
	end
end

-- [GameTooltip] Hook the Reputation Bars Scripts to show the Tooltip.
function ParagonReputation:HookScript()
	for n=1,NUM_FACTIONS_DISPLAYED do
		if _G["ReputationBar"..n] then
			_G["ReputationBar"..n]:HookScript("OnEnter",function(self)
				PR:Tooltip(self,"OnEnter")
			end)
			_G["ReputationBar"..n]:HookScript("OnLeave",function(self)
				PR:Tooltip(self,"OnLeave")
			end)
		end
	end
end

-- [Paragon Toast] Show the Paragon Toast if a Paragon Reward Quest is accepted.
function ParagonReputation:ShowToast(name,text)
	ACTIVE_TOAST = true
	if PR.DB.sound then PlaySound(44295,"master",true) end
	PR.toast:EnableMouse(false)
	PR.toast.title:SetText(name)
	PR.toast.title:SetAlpha(0)
	PR.toast.description:SetText(text)
	PR.toast.description:SetAlpha(0)
	PR.toast.reset:Hide()
	PR.toast.lock:Hide()
	UIFrameFadeIn(PR.toast,.5,0,1)
	C_Timer.After(.5,function()
		UIFrameFadeIn(PR.toast.title,.5,0,1)
	end)
	C_Timer.After(.75,function()
		UIFrameFadeIn(PR.toast.description,.5,0,1)
	end)
	C_Timer.After(PR.DB.fade,function()
		UIFrameFadeOut(PR.toast,1,1,0)
	end)
	C_Timer.After(PR.DB.fade+1.25,function()
		PR.toast:Hide()
		ACTIVE_TOAST = false
		if #WAITING_TOAST > 0 then
			PR:WaitToast()
		end
	end)
end

-- [Paragon Toast] Get next Paragon Reward Quest if more than two are accepted at the same time.
function ParagonReputation:WaitToast()
	local name,text = unpack(WAITING_TOAST[1])
	table.remove(WAITING_TOAST,1)
	PR:ShowToast(name,text)
end

-- [Paragon Toast] Handle the QUEST_ACCEPTED event.
local reward = CreateFrame("FRAME")
reward:RegisterEvent("QUEST_ACCEPTED")
reward:SetScript("OnEvent",function(self,event,questID)
	if PR.DB.toast and PARAGON_QUESTS[questID] then
		local name = GetFactionInfoByID(PARAGON_QUESTS[questID])
		local text = GetQuestLogCompletionText(C_QuestLog.GetLogIndexForQuestID(questID))
		if ACTIVE_TOAST then
			WAITING_TOAST[#WAITING_TOAST+1] = {name,text} --Toast is already active, put this info on the line.
		else
			PR:ShowToast(name,text)
		end
	end
end)

-- [Paragon Overlay] Create the Overlay for the Reputation Bar.
function ParagonReputation:CreateBarOverlay(factionBar)
	local overlay = CreateFrame("FRAME",nil,factionBar)
	overlay:SetAllPoints(factionBar)
	overlay:SetFrameLevel(3)
	overlay.bar = overlay:CreateTexture("ARTWORK",nil,nil,-1)
	overlay.bar:SetTexture((ElvUI and ElvUI[1].private and ElvUI[1].private.skins and ElvUI[1].private.skins.blizzard and ElvUI[1].private.skins.blizzard.enable and ElvUI[1].private.skins.blizzard.character and ElvUI[1].media and ElvUI[1].media.normTex) or "Interface\\TARGETINGFRAME\\UI-StatusBar") -- Checks for ElvUI and it's values in case they are skinning the Character Frame.
	overlay.bar:SetPoint("TOP",overlay)
	overlay.bar:SetPoint("BOTTOM",overlay)
	overlay.bar:SetPoint("LEFT",overlay)
	overlay.edge = overlay:CreateTexture("ARTWORK",nil,nil,-1)
	overlay.edge:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	overlay.edge:SetPoint("CENTER",overlay.bar,"RIGHT")
	overlay.edge:SetBlendMode("ADD")
	overlay.edge:SetSize(38,38) --Arbitrary value, I hope there isn't an AddOn that skins the bar and the glow doesnt look right with this size.
	factionBar.ParagonOverlay = overlay
end

-- [Reputation Frame] Change the Reputation Bars accordingly.
hooksecurefunc("ReputationFrame_Update",function()
	ReputationFrame.paragonFramesPool:ReleaseAll()
	local factionOffset = FauxScrollFrame_GetOffset(ReputationListScrollFrame)
	for n=1,NUM_FACTIONS_DISPLAYED,1 do
		local factionIndex = factionOffset+n
		local factionRow = _G["ReputationBar"..n]
		local factionBar = _G["ReputationBar"..n.."ReputationBar"]
		local factionStanding = _G["ReputationBar"..n.."ReputationBarFactionStanding"]
		if factionIndex <= GetNumFactions() then
			local name,_,_,_,_,_,_,_,_,_,_,_,_,factionID = GetFactionInfo(factionIndex)
			if factionID and C_Reputation.IsFactionParagon(factionID) then
				local currentValue,threshold,rewardQuestID,hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
				factionRow.name = name
				factionRow.count = " |cffffffffx"..floor(currentValue/threshold)-(hasRewardPending and 1 or 0).."|r"
				factionRow.factionID = factionID
				if currentValue then
					local r,g,b = unpack(PR.DB.value)
					local value = mod(currentValue,threshold)
					if hasRewardPending then
						local paragonFrame = ReputationFrame.paragonFramesPool:Acquire()
						paragonFrame.factionID = factionID
						paragonFrame:SetPoint("RIGHT",factionRow,11,0)
						paragonFrame.Glow:SetShown(true)
						paragonFrame.Check:SetShown(true)
						paragonFrame:Show()
						-- If value is 0 we force it to 1 so we don't get 0 as result, math...
						local over = ((value <= 0 and 1) or value)/threshold
						if not factionBar.ParagonOverlay then PR:CreateBarOverlay(factionBar) end
						factionBar.ParagonOverlay:Show()
						factionBar.ParagonOverlay.bar:SetWidth(factionBar.ParagonOverlay:GetWidth()*over)
						factionBar.ParagonOverlay.bar:SetVertexColor(r+.15,g+.15,b+.15)
						factionBar.ParagonOverlay.edge:SetVertexColor(r+.2,g+.2,b+.2,(over > .05 and .75) or 0)
						value = value+threshold
					else
						if factionBar.ParagonOverlay then factionBar.ParagonOverlay:Hide() end
					end
					factionBar:SetMinMaxValues(0,threshold)
					factionBar:SetValue(value)
					factionBar:SetStatusBarColor(r,g,b)
					factionRow.rolloverText = HIGHLIGHT_FONT_COLOR_CODE.." "..format(REPUTATION_PROGRESS_FORMAT,BreakUpLargeNumbers(value),BreakUpLargeNumbers(threshold))..FONT_COLOR_CODE_CLOSE
					if PR.DB.text == "PARAGON" then
						factionStanding:SetText(PR.L["PARAGON"])
						factionRow.standingText = PR.L["PARAGON"]
					elseif PR.DB.text == "CURRENT"  then
						factionStanding:SetText(BreakUpLargeNumbers(value))
						factionRow.standingText = BreakUpLargeNumbers(value)
					elseif PR.DB.text == "VALUE" then
						factionStanding:SetText(" "..BreakUpLargeNumbers(value).." / "..BreakUpLargeNumbers(threshold))
						factionRow.standingText = (" "..BreakUpLargeNumbers(value).." / "..BreakUpLargeNumbers(threshold))
						factionRow.rolloverText = nil					
					elseif PR.DB.text == "DEFICIT" then
						if hasRewardPending then
							value = value-threshold
							factionStanding:SetText("+"..BreakUpLargeNumbers(value))
							factionRow.standingText = "+"..BreakUpLargeNumbers(value)
						else
							value = threshold-value
							factionStanding:SetText(BreakUpLargeNumbers(value))
							factionRow.standingText = BreakUpLargeNumbers(value)
						end
						factionRow.rolloverText = nil
					end
				end
			else
				factionRow.name = nil
				factionRow.count = nil
				factionRow.factionID = nil
				if factionBar.ParagonOverlay then factionBar.ParagonOverlay:Hide() end
			end
		else
			factionRow:Hide()
		end
	end
end)