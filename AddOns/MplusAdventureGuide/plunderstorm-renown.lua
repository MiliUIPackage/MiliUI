-- Make the Plunderstorm faction's Renown button usable

local addonName, addon = ...

function addon:initEnablePlunderstormRenownButton()
    hooksecurefunc(ReputationFrame.ReputationDetailFrame.ViewRenownButton, "Refresh", function(self)
    	local factionID = C_Reputation.GetFactionDataByIndex(C_Reputation.GetSelectedFaction()).factionID
        if factionID == 2593 then
            self:Enable()
        end
    end)
end
