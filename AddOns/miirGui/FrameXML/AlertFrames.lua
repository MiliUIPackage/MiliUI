local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

-- LootAlert Frame 

local function miirgui_LootAlertSystem()
	local LootAlertPool = LootAlertSystem.alertFramePool	
		for alertFrame in LootAlertPool:EnumerateActive() do	
			if ( alertFrame.BGAtlas ) then
				alertFrame.BGAtlas:Hide();
				alertFrame.Background:Show()
			end
			if alertFrame.SpecIcon then
				alertFrame.SpecIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			end
			alertFrame.RollValue:ClearAllPoints()
			alertFrame.RollValue:SetPoint("CENTER",alertFrame.Background,60,10)
			m_fontify(alertFrame.RollValue,"same")
			alertFrame.Background= select(1,alertFrame:GetRegions())
			alertFrame.Background:ClearAllPoints()
			alertFrame.Background:SetParent(alertFrame)	
			alertFrame.Background:SetPoint("LEFT",-68,-2)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
			alertFrame.Icon:SetSize(44,44)
			alertFrame.Icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			alertFrame.IconBorder:Hide()
			alertFrame.Label:ClearAllPoints()
			alertFrame.Label:SetPoint("CENTER",alertFrame.Background,30,10)
			m_fontify(alertFrame.Label,"color")
			alertFrame.ItemName:ClearAllPoints()
			alertFrame.ItemName:SetPoint("CENTER",alertFrame.Background,20,-10)
			m_fontify(alertFrame.ItemName,"same")
			alertFrame.glow:Hide()
		end		
end

hooksecurefunc(LootAlertSystem,"AddAlert",miirgui_LootAlertSystem)	

-- MoneyAlert Frame   

local function miirgui_MoneyWonAlertSystem()
	local MoneyWonAlertPool = MoneyWonAlertSystem.alertFramePool	
		for alertFrame in MoneyWonAlertPool:EnumerateActive() do		
			alertFrame.Background:ClearAllPoints()	
			alertFrame.Background:SetPoint("CENTER",alertFrame,0,0.5)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
			alertFrame.Icon:ClearAllPoints()	
			alertFrame.Icon:SetPoint("LEFT",alertFrame.Background,91,0)
			alertFrame.Icon:SetSize(44,44)
			alertFrame.Icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			alertFrame.IconBorder:Hide()
			m_fontify(alertFrame.Label,"color")
			m_fontify(alertFrame.Amount,"white")
		end			
end

hooksecurefunc(MoneyWonAlertSystem,"ShowAlert",miirgui_MoneyWonAlertSystem)

-- AchievementAlert Frame 

local function miirgui_AchievementAlertSystem()
	local achievementAlertPool = AchievementAlertSystem.alertFramePool
		for alertFrame in achievementAlertPool:EnumerateActive() do
			alertFrame.Icon:SetFrameStrata("MEDIUM")
			alertFrame.Background:ClearAllPoints()
			alertFrame.Background:SetParent(alertFrame.Icon)
			alertFrame.Background:SetPoint("LEFT",-51,3)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
			alertFrame.GuildBanner:Hide()
			alertFrame.GuildBorder:Hide()
			m_fontify(alertFrame.Unlocked,"color")
			m_fontify(alertFrame.Name,"white")
			m_fontify(alertFrame.Shield.Points,"white")
		end	
end
		
hooksecurefunc(AchievementAlertSystem,"ShowAlert",miirgui_AchievementAlertSystem)

--  AchievementCriteriaAlert Frame
				
local function miirgui_CriteriaAlertSystem()			
	local CriteriaAlertPool = CriteriaAlertSystem.alertFramePool	
		for alertFrame in CriteriaAlertPool:EnumerateActive() do	
			alertFrame.Icon.Texture:SetSize(44,44)
			alertFrame.Icon.Texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)	
			alertFrame.Background:ClearAllPoints()
			alertFrame.Background:SetParent(alertFrame)	
			alertFrame.Background:SetPoint("LEFT",-99,3)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")	
			m_fontify(alertFrame.Unlocked,"color")
			m_fontify(alertFrame.Name,"white")
		end			
end

hooksecurefunc(CriteriaAlertSystem,"ShowAlert",miirgui_CriteriaAlertSystem)
	
-- GuildchallengeAlert Frame
			
local function miirgui_GuildChallengeAlertSystem()
	GuildChallengeAlertFrameEmblemBackground:SetSize(50,50)
	GuildChallengeAlertFrameEmblemBackground:ClearAllPoints()
	GuildChallengeAlertFrameEmblemBackground:SetPoint("LEFT",7,0)	
	local GuildChallengeAlertFrameBackground= select(2,GuildChallengeAlertFrame:GetRegions() )
	GuildChallengeAlertFrameBackground:ClearAllPoints()
	GuildChallengeAlertFrameBackground:SetParent(GuildChallengeAlertFrame)	
	GuildChallengeAlertFrameBackground:SetPoint("CENTER",40,0.5)
	GuildChallengeAlertFrameBackground:SetSize(512,64)
	GuildChallengeAlertFrameBackground:SetTexCoord(0,1,1,0)
	GuildChallengeAlertFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	GuildChallengeAlertFrameEmblemBorder:Hide()
	GuildChallengeAlertFrameEmblemIcon:SetSize(44,44)
	GuildChallengeAlertFrameEmblemIcon:SetPoint("LEFT",10,0)
	local GuildChallengeAlertFrameName = select(5,GuildChallengeAlertFrame:GetRegions())	
	m_fontify(GuildChallengeAlertFrameName,"color")
	m_fontify(GuildChallengeAlertFrameType,"white")
	m_fontify(GuildChallengeAlertFrameCount,"color")	
end
		
hooksecurefunc(GuildChallengeAlertSystem,"AddAlert",miirgui_GuildChallengeAlertSystem)
	
-- DungeonCompletionAlert Frame
			
local function miirgui_DungeonCompletionAlertSystem()
	m_fontify(DungeonCompletionAlertFrameInstanceName,"white")
	local DungeonCompletionAlertFrameInstanceNamecomplete= select(7,DungeonCompletionAlertFrame:GetRegions() )
	m_fontify(DungeonCompletionAlertFrameInstanceNamecomplete,"color")
	local numRewards = select(10,GetLFGCompletionReward())
	for i =1, numRewards do
		_G["DungeonCompletionAlertFrameReward"..i.."Texture"]:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	end
end
		
hooksecurefunc(DungeonCompletionAlertSystem,"AddAlert",miirgui_DungeonCompletionAlertSystem)
		
-- InvasionAlert Frame

local function miirgui_InvasionAlertSystem()
	local ScenarioLegionInvasionAlertFrameCompleted = select(3,ScenarioLegionInvasionAlertFrame:GetRegions())
	local ScenarioLegionInvasionAlertFrameBackground= select(1,ScenarioLegionInvasionAlertFrame:GetRegions())
	ScenarioLegionInvasionAlertFrameBackground:ClearAllPoints()
	ScenarioLegionInvasionAlertFrameBackground:SetParent(ScenarioLegionInvasionAlertFrame)	
	ScenarioLegionInvasionAlertFrameBackground:SetPoint("CENTER",27,0)
	ScenarioLegionInvasionAlertFrameBackground:SetSize(512,64)
	ScenarioLegionInvasionAlertFrameBackground:SetTexCoord(0,1,1,0)
	ScenarioLegionInvasionAlertFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	m_fontify(ScenarioLegionInvasionAlertFrameCompleted,"color")
end
		
hooksecurefunc(InvasionAlertSystem,"AddAlert",miirgui_InvasionAlertSystem)
		
-- DigsiteCompleteAlert Frame
		
local function miirgui_DigsiteCompleteAlertSystem()
	DigsiteCompleteToastFrame.DigsiteTypeTexture:SetSize(82,82)
	DigsiteCompleteToastFrame.DigsiteTypeTexture:ClearAllPoints()
	DigsiteCompleteToastFrame.DigsiteTypeTexture:SetPoint("LEFT",14,-14)
	local DigsiteCompleteToastFrameBackground= select(1,DigsiteCompleteToastFrame:GetRegions())
	DigsiteCompleteToastFrameBackground:ClearAllPoints()
	DigsiteCompleteToastFrameBackground:SetParent(DigsiteCompleteToastFrame)	
	DigsiteCompleteToastFrameBackground:SetPoint("LEFT",-74.5,-1.5)
	DigsiteCompleteToastFrameBackground:SetSize(512,64)
	DigsiteCompleteToastFrameBackground:SetTexCoord(0,1,1,0)
	DigsiteCompleteToastFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach_ship.tga")
	local DigsiteCompleteToastFrameRace = select(2,DigsiteCompleteToastFrame:GetRegions());
	m_fontify(DigsiteCompleteToastFrameRace,"white")
	local DigsiteCompleteToastFrameComplete = select(3,DigsiteCompleteToastFrame:GetRegions());
	m_fontify(DigsiteCompleteToastFrameComplete,"color")
end
		
hooksecurefunc(DigsiteCompleteAlertSystem,"AddAlert",miirgui_DigsiteCompleteAlertSystem)
		
--  NewRecipeLearnedAlert Frame 
		
local function miirgui_NewRecipeLearnedAlertSystem(_, recipeID)	
	local NewRecipeLearnedAlertPool = NewRecipeLearnedAlertSystem.alertFramePool	
		for alertFrame in NewRecipeLearnedAlertPool:EnumerateActive() do	
		local tradeSkillID, _ = C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID);		
			alertFrame.Icon:Hide()
			
			local recipeIcon = CreateFrame("Frame",alertFrame)
			recipeIcon:SetSize(44,44)
			local texture = recipeIcon:CreateTexture(nil,"BACKGROUND")
			texture:SetTexture(C_TradeSkillUI.GetTradeSkillTexture(tradeSkillID))
			texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			texture:SetAllPoints(recipeIcon)
			recipeIcon.texture =texture
			recipeIcon:SetPoint("CENTER",alertFrame.Icon,-8,0)
			recipeIcon:SetParent(alertFrame)

			alertFrame.Background= select(1,alertFrame:GetRegions())
			alertFrame.Background:ClearAllPoints()
			alertFrame.Background:SetParent(alertFrame)	
			alertFrame.Background:SetPoint("LEFT",-71,0.5)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")

			m_fontify(alertFrame.Name,"color")
			m_fontify(alertFrame.Title,"white")
			alertFrame.Title:ClearAllPoints()
			alertFrame.Title:SetPoint("TOP",20,-30)
		end	
end
		
hooksecurefunc(NewRecipeLearnedAlertSystem,"ShowAlert",miirgui_NewRecipeLearnedAlertSystem)
		
--  LootUpgradeAlert Frame
	
local function miirgui_LootUpgradeAlertSystem(_, itemLink,_, _, baseQuality)
	local LootUpgradeAlertPool = LootUpgradeAlertSystem.alertFramePool	
		for alertFrame in LootUpgradeAlertPool:EnumerateActive() do	
			alertFrame.Background= select(1,alertFrame:GetRegions())
			alertFrame.Background:ClearAllPoints()
			alertFrame.Background:SetParent(alertFrame)	
			alertFrame.Background:SetPoint("CENTER",0,0)
			alertFrame.Background:SetSize(512,64)
			alertFrame.Background:SetTexCoord(0,1,1,0)
			alertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
		
			local itemRarity = select(3,GetItemInfo(itemLink))
			local baseQualityColor = ITEM_QUALITY_COLORS[baseQuality];
			local upgradeQualityColor = ITEM_QUALITY_COLORS[itemRarity];
			alertFrame.Icon:ClearAllPoints()
			alertFrame.Icon:SetParent(alertFrame)	
			alertFrame.Icon:SetSize(44,44)
			alertFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			alertFrame.Icon:SetPoint("LEFT",-27,0)	
			
			alertFrame.BaseQualityBorder:ClearAllPoints()
			alertFrame.BaseQualityBorder:SetSize(58,58)
			alertFrame.BaseQualityBorder:SetPoint("CENTER",alertFrame.Icon,0,0)		
			alertFrame.UpgradeQualityBorder:ClearAllPoints()
			alertFrame.UpgradeQualityBorder:SetSize(58,58)
			alertFrame.UpgradeQualityBorder:SetPoint("CENTER",alertFrame.Icon,0,0)	

			alertFrame.BaseQualityBorder:SetTexture("Interface\\LootFrame\\quality.blp")
			alertFrame.BaseQualityBorder:SetVertexColor(baseQualityColor.r, baseQualityColor.g, baseQualityColor.b)
			alertFrame.UpgradeQualityBorder:SetTexture("Interface\\LootFrame\\quality.blp")
			alertFrame.UpgradeQualityBorder:SetVertexColor(upgradeQualityColor.r, upgradeQualityColor.g, upgradeQualityColor.b);
			
			alertFrame.TitleText:ClearAllPoints()
			alertFrame.TitleText:SetPoint("CENTER",alertFrame,10,10)
			
			m_fontify(alertFrame.TitleText,"white")
			m_fontify(alertFrame.BaseQualityItemName,"same")
			m_fontify(alertFrame.UpgradeQualityItemName,"same")
			
			alertFrame.Sheen:Hide()
			alertFrame.Sheen:SetAlpha(0)
			alertFrame.Sheen:ClearAllPoints()
		end		
end
			
hooksecurefunc(LootUpgradeAlertSystem,"ShowAlert",miirgui_LootUpgradeAlertSystem)
	
-- GarrisonFollowerAlert Frame
		
local function miirgui_GarrisonFollowerAlertSystem()	
	local GarrisonFollowerAlertFrameBackground = select(5,GarrisonFollowerAlertFrame:GetRegions())
	GarrisonFollowerAlertFrameBackground:SetPoint("Center",2,5)
	GarrisonFollowerAlertFrameBackground:SetSize(512,64)
	GarrisonFollowerAlertFrameBackground:SetTexCoord(0,1,1,0)
	GarrisonFollowerAlertFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	
	GarrisonFollowerAlertFrame.FollowerBG:Hide()
	GarrisonFollowerAlertFrame.PortraitFrame.PortraitRing:Hide()	
	
	GarrisonFollowerAlertFrame.PortraitFrame.PortraitRingQuality:SetTexture("Interface\\ContainerFrame\\quality.blp")
	GarrisonFollowerAlertFrame.PortraitFrame.PortraitRingQuality:SetSize(52,52)
	GarrisonFollowerAlertFrame.PortraitFrame.PortraitRingQuality:ClearAllPoints()
	GarrisonFollowerAlertFrame.PortraitFrame.PortraitRingQuality:SetPoint("CENTER",GarrisonFollowerAlertFrame.PortraitFrame.Portrait,-1.5,0)
	
	GarrisonFollowerAlertFrame.PortraitFrame.LevelBorder:Hide()
	GarrisonFollowerAlertFrame.PortraitFrame.Portrait:ClearAllPoints()
	GarrisonFollowerAlertFrame.PortraitFrame.Portrait:SetPoint("LEFT",GarrisonFollowerAlertFrame,-4,5)
	GarrisonFollowerAlertFrame.PortraitFrame.Portrait:SetSize(44,44)
	GarrisonFollowerAlertFrame.PortraitFrame.Portrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	
	m_fontify(GarrisonFollowerAlertFrame.Name,"color")
	m_fontify(GarrisonFollowerAlertFrame.Title,"white")
	m_fontify(GarrisonFollowerAlertFrame.PortraitFrame.Level,"white")
	GarrisonFollowerAlertFrame.PortraitFrame.Level:ClearAllPoints()
	GarrisonFollowerAlertFrame.PortraitFrame.Level:SetPoint("BOTTOM",GarrisonFollowerAlertFrame.PortraitFrame.Portrait, 0,-10)
end
	
hooksecurefunc(GarrisonFollowerAlertSystem,"AddAlert",miirgui_GarrisonFollowerAlertSystem)
	
-- GarrisonShipAlert Frame 
	
local function miirgui_GarrisonShipFollowerAlertSystem()
	GarrisonShipFollowerAlertFrame.Background:ClearAllPoints()
	GarrisonShipFollowerAlertFrame.Background:SetParent(GarrisonShipFollowerAlertFrame)	
	GarrisonShipFollowerAlertFrame.Background:SetPoint("CENTER",20,2)
	GarrisonShipFollowerAlertFrame.Background:SetSize(512,64)
	GarrisonShipFollowerAlertFrame.Background:SetTexCoord(0,1,1,0)
	GarrisonShipFollowerAlertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	GarrisonShipFollowerAlertFrame.Portrait:ClearAllPoints()
	GarrisonShipFollowerAlertFrame.Portrait:SetPoint("LEFT",14,2)
	GarrisonShipFollowerAlertFrame.Portrait:SetSize(44,44)
	GarrisonShipFollowerAlertFrame.Portrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	GarrisonShipFollowerAlertFrame.Portrait:SetTexture("Interface\\Icons\\INV_Garrison_Cargoship.blp")
	m_fontify(GarrisonShipFollowerAlertFrame.Name,"color")
	m_fontify(GarrisonShipFollowerAlertFrame.Title,"white")
	m_fontify(GarrisonShipFollowerAlertFrame.Class,"white")
end
	
hooksecurefunc(GarrisonShipFollowerAlertSystem,"AddAlert",miirgui_GarrisonShipFollowerAlertSystem)
	
--Garrison Building Complete Frame

local function miirgui_GarrisonBuildingAlertSystem()
	local GarrisonBuildingAlertSystemBackground = select(1,GarrisonBuildingAlertFrame:GetRegions())
	GarrisonBuildingAlertSystemBackground:ClearAllPoints()
	GarrisonBuildingAlertSystemBackground:SetParent(GarrisonBuildingAlertFrame)	
	GarrisonBuildingAlertSystemBackground:SetPoint("Center",20,2)
	GarrisonBuildingAlertSystemBackground:SetSize(512,64)
	GarrisonBuildingAlertSystemBackground:SetTexCoord(0,1,1,0)
	GarrisonBuildingAlertSystemBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	GarrisonBuildingAlertFrame.Icon:ClearAllPoints()
	GarrisonBuildingAlertFrame.Icon:SetPoint("LEFT",14,2)
	GarrisonBuildingAlertFrame.Icon:SetSize(44,44)
	GarrisonBuildingAlertFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_fontify(GarrisonBuildingAlertFrame.Title,"color")
	m_fontify(GarrisonBuildingAlertFrame.Name,"white")
end
		
hooksecurefunc(GarrisonBuildingAlertSystem,"AddAlert",miirgui_GarrisonBuildingAlertSystem)
	
-- Garrison Mission Alert Frame
		
local function miirgui_GarrisonMissionAlertSystem()
	m_fontify(GarrisonMissionAlertFrame.Name,"white")
	m_fontify(GarrisonMissionAlertFrame.Title,"color")
	GarrisonMissionAlertFrame.IconBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")	
	GarrisonMissionAlertFrame.IconBG:SetSize(44,44)
	GarrisonMissionAlertFrame.IconBG:ClearAllPoints()
	GarrisonMissionAlertFrame.IconBG:SetPoint("LEFT",14,2)				
	GarrisonMissionAlertFrame.MissionType:SetSize(48,48)
	GarrisonMissionAlertFrame.MissionType:ClearAllPoints()
	GarrisonMissionAlertFrame.MissionType:SetPoint("LEFT",14,2)
	GarrisonMissionAlertFrame.Background:ClearAllPoints()
	GarrisonMissionAlertFrame.Background:SetParent(GarrisonMissionAlertFrame)	
	GarrisonMissionAlertFrame.Background:SetPoint("CENTER",20,2)
	GarrisonMissionAlertFrame.Background:SetSize(512,64)
	GarrisonMissionAlertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
end

hooksecurefunc(GarrisonMissionAlertSystem,"AddAlert",miirgui_GarrisonMissionAlertSystem)	
	
local function miirgui_GarrisonShipMissionAlertSystem()
	m_fontify(GarrisonShipMissionAlertFrame.Name,"white")
	m_fontify(GarrisonShipMissionAlertFrame.Title,"color")			
	GarrisonShipMissionAlertFrame.MissionType:SetSize(48,48)
	GarrisonShipMissionAlertFrame.MissionType:ClearAllPoints()
	GarrisonShipMissionAlertFrame.MissionType:SetPoint("LEFT",14,2)
	GarrisonShipMissionAlertFrame.Background:ClearAllPoints()
	GarrisonShipMissionAlertFrame.Background:SetParent(GarrisonShipMissionAlertFrame)	
	GarrisonShipMissionAlertFrame.Background:SetPoint("CENTER",20,2)
	GarrisonShipMissionAlertFrame.Background:SetSize(512,64)
	GarrisonShipMissionAlertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach_ship.tga")
end

hooksecurefunc(GarrisonShipMissionAlertSystem,"AddAlert",miirgui_GarrisonShipMissionAlertSystem)

-- Garrison Random Mission Alert Frame 
				
local function miirgui_GarrisonRandomMissionAlertSystem()
	m_fontify(GarrisonRandomMissionAlertFrame.Level,"white")
	m_fontify(GarrisonRandomMissionAlertFrame.ItemLevel,"white")
	m_fontify(GarrisonRandomMissionAlertFrame.Rare,"color")
	local GarrisonRandomMissionAlertFrameNewMission=select(5,GarrisonRandomMissionAlertFrame:GetRegions())
	m_fontify(GarrisonRandomMissionAlertFrameNewMission,"color")
	local GarrisonRandomMissionAlertFrameNewMission2=select(6,GarrisonRandomMissionAlertFrame:GetRegions())
	m_fontify(GarrisonRandomMissionAlertFrameNewMission2,"color")GarrisonRandomMissionAlertFrame.IconBG:Hide()
	GarrisonRandomMissionAlertFrame.MissionType:SetTexture("Interface\\Icons\\achievement_raregarrisonquests_x.blp")
	GarrisonRandomMissionAlertFrame.MissionType:ClearAllPoints()
	GarrisonRandomMissionAlertFrame.MissionType:SetPoint("LEFT",14,2)
	GarrisonRandomMissionAlertFrame.MissionType:SetSize(44,44)
	GarrisonRandomMissionAlertFrame.MissionType:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	GarrisonRandomMissionAlertFrame.Background:ClearAllPoints()
	GarrisonRandomMissionAlertFrame.Background:SetParent(GarrisonRandomMissionAlertFrame)	
	GarrisonRandomMissionAlertFrame.Background:SetPoint("CENTER",20,2)
	GarrisonRandomMissionAlertFrame.Background:SetSize(512,64)
	GarrisonRandomMissionAlertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	GarrisonRandomMissionAlertFrame.Blank:Hide()
end
		
hooksecurefunc(GarrisonRandomMissionAlertSystem,"AddAlert",miirgui_GarrisonRandomMissionAlertSystem)
		
-- LegendaryItemAlert Frame
		
local function miirgui_LegendaryItemAlertSystem()
	local LegendaryItemAlertFrameLegendaryItem=select(10,LegendaryItemAlertFrame:GetRegions())
	m_fontify(LegendaryItemAlertFrameLegendaryItem,"color")
	m_fontify(LegendaryItemAlertFrame.ItemName,"same")
	LegendaryItemAlertFrame.Background:ClearAllPoints()
	LegendaryItemAlertFrame.Background:SetParent(LegendaryItemAlertFrame)	
	LegendaryItemAlertFrame.Background:SetPoint("CENTER",20,2.5)
	LegendaryItemAlertFrame.Background:SetSize(512,64)
	LegendaryItemAlertFrame.Background:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	LegendaryItemAlertFrame.Icon:ClearAllPoints()
	LegendaryItemAlertFrame.Icon:SetParent(LegendaryItemAlertFrame)	
	LegendaryItemAlertFrame.Icon:SetPoint("Left",6,3)
	LegendaryItemAlertFrame.Icon:SetSize(46,46)
	LegendaryItemAlertFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	LegendaryItemAlertFrame.Background2:Hide()
	LegendaryItemAlertFrame.Background3:Hide()
	LegendaryItemAlertFrame.Starglow:Hide()
	LegendaryItemAlertFrame.Particles1:Hide()
	LegendaryItemAlertFrame.Particles2:Hide()
	LegendaryItemAlertFrame.Particles3:Hide()
	LegendaryItemAlertFrame.Ring1:Hide()
	LegendaryItemAlertFrameGlow:Hide()
end

hooksecurefunc(LegendaryItemAlertSystem,"AddAlert",miirgui_LegendaryItemAlertSystem)
		
-- WorldQuestCompleteAlert Frame
		
local function miirgui_WorldQuestCompleteAlertSystem()
	local WorldQuestCompleteAlertFrameCompleted=select(6,WorldQuestCompleteAlertFrame:GetRegions())
	m_fontify(WorldQuestCompleteAlertFrameCompleted,"white")	
	m_fontify(WorldQuestCompleteAlertFrame.QuestName,"color")
	for i=2,4 do
		local hideit=select(i,WorldQuestCompleteAlertFrame:GetRegions())
		hideit:Hide()
	end
	local WorldQuestCompleteAlertFrameBackground=select(5,WorldQuestCompleteAlertFrame:GetRegions())
	WorldQuestCompleteAlertFrameBackground:ClearAllPoints()
	WorldQuestCompleteAlertFrameBackground:SetParent(WorldQuestCompleteAlertFrame)	
	WorldQuestCompleteAlertFrameBackground:SetPoint("CENTER",20,2)
	WorldQuestCompleteAlertFrameBackground:SetSize(512,64)
	WorldQuestCompleteAlertFrameBackground:SetTexCoord(0,1,1,0)
	WorldQuestCompleteAlertFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	WorldQuestCompleteAlertFrame.QuestTexture:ClearAllPoints()
	WorldQuestCompleteAlertFrame.QuestTexture:SetParent(WorldQuestCompleteAlertFrame)	
	WorldQuestCompleteAlertFrame.QuestTexture:SetPoint("LEFT",9,3)
	WorldQuestCompleteAlertFrame.QuestTexture:SetSize(46,46)
	WorldQuestCompleteAlertFrame.QuestTexture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	if WorldQuestCompleteAlertFrameTexture then
		WorldQuestCompleteAlertFrameTexture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	end
end
		
hooksecurefunc(WorldQuestCompleteAlertSystem,"AddAlert",miirgui_WorldQuestCompleteAlertSystem)
	
-- Garison Talent AlertFrame

local function miirgui_GarrisonTalentAlertSystem()
	m_fontify(GarrisonTalentAlertFrame.Name,"white")
	m_fontify(GarrisonTalentAlertFrame.Title,"color")
	local GarrisonTalentAlertFrameBackground=select(1,GarrisonTalentAlertFrame:GetRegions())
	GarrisonTalentAlertFrameBackground:SetTexture("Interface\\Achievementframe\\miirgui_ach.tga")
	GarrisonTalentAlertFrameBackground:ClearAllPoints()
	GarrisonTalentAlertFrameBackground:SetParent(GarrisonTalentAlertFrame)	
	GarrisonTalentAlertFrameBackground:SetPoint("CENTER",20,2)
	GarrisonTalentAlertFrameBackground:SetSize(512,64)
	GarrisonTalentAlertFrameBackground:SetTexCoord(0,1,1,0)	
	GarrisonTalentAlertFrame.Icon:ClearAllPoints()
	GarrisonTalentAlertFrame.Icon:SetParent(GarrisonTalentAlertFrame)	
	GarrisonTalentAlertFrame.Icon:SetPoint("Left",12,3)
	GarrisonTalentAlertFrame.Icon:SetSize(46,46)
	GarrisonTalentAlertFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
end

hooksecurefunc(GarrisonTalentAlertSystem,"AddAlert",miirgui_GarrisonTalentAlertSystem)	

-- Talent Points to spent
TalentMicroButtonAlertBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
TalentMicroButtonAlertBg:SetColorTexture(0.078,0.078,0.078,1)
m_border(TalentMicroButtonAlert,226,76,"CENTER",0,0,14,"DIALOG")
m_border_TalentMicroButtonAlert:SetPoint("TOPLEFT","TalentMicroButtonAlert",-3,3)
m_border_TalentMicroButtonAlert:SetPoint("BOTTOMRIGHT","TalentMicroButtonAlert",3,-3)
m_fontify(TalentMicroButtonAlert.Text,"white")
-- Collectionsalert
CollectionsMicroButtonAlertBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
CollectionsMicroButtonAlertBg:SetColorTexture(0.078,0.078,0.078,1)
m_border(CollectionsMicroButtonAlert,226,76,"CENTER",0,0,14,"DIALOG")
m_fontify(CollectionsMicroButtonAlert.Text,"white")
end)