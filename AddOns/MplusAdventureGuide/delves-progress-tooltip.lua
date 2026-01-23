local addonName, addon = ...

-- from Blizzard_DelvesDashboardUI.lua
local function hasActiveSeason()
	local uiDisplaySeason = C_DelvesUI.GetCurrentDelvesSeasonNumber();
    return uiDisplaySeason and uiDisplaySeason > 0;
end

local function addTopDelveRunsToTooltip(runsNeeded)
	local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
	local totalMaxCompleted = 0
	for _, activity in ipairs(activities) do
		if activity.level and (activity.level >= 8) then
			totalMaxCompleted = activity.progress
		end
	end
    
    if totalMaxCompleted >= runsNeeded then return end
    
    GameTooltip_AddBlankLineToTooltip(GameTooltip);
    GameTooltip_AddHighlightLine(GameTooltip, "Delves needed at Tier 8: "..(runsNeeded - totalMaxCompleted))
    
    GameTooltip:Show()
end

function addon:initDelvesProgressTooltip()
    if not addon.db.profile.delvesProgressTooltip then return end
    if not hasActiveSeason() then return end
    
    for _, activity in ipairs(WeeklyRewardsFrame.Activities) do
        if activity ~= WeeklyRewardsFrame.ConcessionFrame then
            hooksecurefunc(activity, "ShowIncompleteTooltip", function(self, _, description)
                -- Check Blizzard_WeeklyRewards.lua for any important changes
                if (description == GREAT_VAULT_REWARDS_WORLD_INCOMPLETE) then
                    addTopDelveRunsToTooltip(2)
                elseif (description == GREAT_VAULT_REWARDS_WORLD_COMPLETED_FIRST) then
                    addTopDelveRunsToTooltip(4)
                elseif (description == GREAT_VAULT_REWARDS_WORLD_COMPLETED_SECOND) then
                    addTopDelveRunsToTooltip(8)
                end
            end)
            
            hooksecurefunc(activity, "HandlePreviewWorldRewardTooltip", function(self, _, upgradeItemLevel)
                if upgradeItemLevel then
                    local runsNeeded = 2^self.index
                    addTopDelveRunsToTooltip(runsNeeded)
                end
            end)
        end
    end
end
