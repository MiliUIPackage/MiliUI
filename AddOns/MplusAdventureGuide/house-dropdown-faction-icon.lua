local addonName, addon = ...

local currentFaction, otherFaction
if UnitFactionGroup("player") == "Horde" then 
	currentFaction = "communities-icon-faction-horde"
    otherFaction = "communities-icon-faction-alliance"
else 
	currentFaction = "communities-icon-faction-alliance"
    otherFaction = "communities-icon-faction-horde"
end 

function addon:initHouseDropdownFactionIcon()
    if not addon.db.profile.houseDropdownFactionIcon then return end
    local houseInfoList
    
    local ddFactionIcon = HousingDashboardFrame.HouseInfoContent.HouseDropdown:CreateTexture(nil, "OVERLAY")
    ddFactionIcon:SetPoint("RIGHT", HousingDashboardFrame.HouseInfoContent.HouseDropdown, "RIGHT", -25, 0)
    ddFactionIcon:SetSize(18, 18)
    
    local function updateDDFactionIcon()
        for houseInfoID, houseInfo in ipairs(houseInfoList) do
            if HousingDashboardFrame.HouseInfoContent.selectedHouseID == houseInfoID then
                if C_Housing.DoesFactionMatchNeighborhood(houseInfo.neighborhoodGUID) then
                    ddFactionIcon:SetAtlas(currentFaction)
                else
                    ddFactionIcon:SetAtlas(otherFaction)
                end
            end
        end
    end
    
    hooksecurefunc(HousingDashboardFrame.HouseInfoContent, "OnHouseListUpdated", function(self, list)
        houseInfoList = list
        updateDDFactionIcon()
    end)
    
    hooksecurefunc(HousingDashboardFrame.HouseInfoContent.HouseDropdown, "OpenMenu", function()
        if not houseInfoList then return end
        if not HousingDashboardFrame.HouseInfoContent.HouseDropdown.menu then return end
        
        for houseInfoID, row in ipairs(HousingDashboardFrame.HouseInfoContent.HouseDropdown.menu:GetLayoutChildren()) do
            local houseInfo = houseInfoList[houseInfoID];
            if not row.MPAGFactionIcon then
                row.MPAGFactionIcon = row:AttachTexture(nil, "OVERLAY")
            end
            local icon = row.MPAGFactionIcon
            icon:SetPoint("RIGHT", row, "RIGHT")
            icon:SetSize(18, 18)
            if C_Housing.DoesFactionMatchNeighborhood(houseInfo.neighborhoodGUID) then
                icon:SetAtlas(currentFaction)
            else
                icon:SetAtlas(otherFaction)
            end
        end
    end)
    
    hooksecurefunc(HousingDashboardFrame.HouseInfoContent.HouseDropdown, "onMenuClosedCallback", updateDDFactionIcon)
end