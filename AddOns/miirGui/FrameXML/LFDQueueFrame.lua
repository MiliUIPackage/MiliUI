local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

PVPReadyDialogFiligree:Hide()
PVPReadyDialogBottomArt:Hide()
PVPReadyDialogBackground:Hide()
local hideit= select(1,LFGDungeonReadyDialogInstanceInfoFrame:GetRegions() )
hideit:Hide() 
LFGDungeonReadyDialogFiligree:Hide()
LFGDungeonReadyDialogBottomArt:Hide()
LFGDungeonReadyDialogBackground:Hide()
LFDQueueFrameRandomScrollFrameScrollBackground:Hide()
LFDQueueFrameBackground:Hide()
RaidFinderQueueFrameBackground:Hide()
local ScenarioBG= select(1,ScenarioQueueFrame:GetRegions())
ScenarioBG:Hide()
local RaidFinderFrameNoRaidsCoverBG=select(1,RaidFinderFrame.NoRaidsCover:GetRegions())
RaidFinderFrameNoRaidsCoverBG:Hide()
m_border(LFDQueueFrame,336,262,"CENTER",-1,-60,14,"MEDIUM")
m_border(RaidFinderFrame,332,87,"TOP",-2,-24,14,"HIGH")
m_border(RaidFinderQueueFrame,336,262,"CENTER",-1,-58,14,"HIGH")
m_border(ScenarioQueueFrame,334,336,"CENTER",-2,-22,14,"MEDIUM")

LFGDungeonReadyDialog:SetBackdrop({
bgFile = "Interface/Tooltips/UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
edgeSize = 14, 
insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
LFGDungeonReadyDialog:SetBackdropColor(0,0,0,0.8);

local function miirgui_LFGDungeonReadyDialogReward_SetReward()
	LFGDungeonReadyDialog:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
	edgeSize = 14, 
	insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	LFGDungeonReadyDialog:SetBackdropColor(0,0,0,0.8);
	for i=1,4 do
		if not _G["m_border_LFGDungeonReadyDialogRewardsFrameReward"..i] and _G["LFGDungeonReadyDialogRewardsFrameReward"..i] then			
			_G["LFGDungeonReadyDialogRewardsFrameReward"..i.."Border"]:Hide()
			_G["LFGDungeonReadyDialogRewardsFrameReward"..i.."Texture"]:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			m_border(_G["LFGDungeonReadyDialogRewardsFrameReward"..i],36,36,"CENTER",-3,3,14,"DIALOG")			
		end
	end		
end

hooksecurefunc("LFGDungeonReadyDialogReward_SetReward",miirgui_LFGDungeonReadyDialogReward_SetReward)

local function miirgui_LFGDungeonReadyDialog_UpdateRewards()
	if LFGDungeonReadyDialogRewardsFrameReward3 then
		LFGDungeonReadyDialogRewardsFrameReward1:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward1:SetPoint("CENTER",LFGDungeonReadyDialogRoleIcon,74,16)	
		LFGDungeonReadyDialogRewardsFrameReward2:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward2:SetPoint("CENTER",LFGDungeonReadyDialogRewardsFrameReward1,38,0)
		LFGDungeonReadyDialogRewardsFrameReward3:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward3:SetPoint("BOTTOM",LFGDungeonReadyDialogRewardsFrameReward1,0,-38)
		LFGDungeonReadyDialogRewardsFrameLabel:Hide()
	end
	if LFGDungeonReadyDialogRewardsFrameReward4 then
		LFGDungeonReadyDialogRewardsFrameReward1:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward1:SetPoint("CENTER",LFGDungeonReadyDialogRoleIcon,74,16)	
		LFGDungeonReadyDialogRewardsFrameReward2:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward2:SetPoint("CENTER",LFGDungeonReadyDialogRewardsFrameReward1,38,0)
		LFGDungeonReadyDialogRewardsFrameReward3:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward3:SetPoint("BOTTOM",LFGDungeonReadyDialogRewardsFrameReward1,0,-38)
		LFGDungeonReadyDialogRewardsFrameReward4:ClearAllPoints()
		LFGDungeonReadyDialogRewardsFrameReward4:SetPoint("CENTER",LFGDungeonReadyDialogRewardsFrameReward3,38,0)
		LFGDungeonReadyDialogRewardsFrameLabel:Hide()
	end
end

hooksecurefunc("LFGDungeonReadyDialog_UpdateRewards",miirgui_LFGDungeonReadyDialog_UpdateRewards)

end)