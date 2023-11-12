local addonName, addon = ...

function addon:initKeystoneMovable()
    if not addon.db.profile.keystoneMovable then return end
    
	ChallengesKeystoneFrame:SetMovable(true)
    ChallengesKeystoneFrame:RegisterForDrag("LeftButton")
    ChallengesKeystoneFrame:SetScript("OnDragStart", ChallengesKeystoneFrame.StartMoving)
    ChallengesKeystoneFrame:SetScript("OnDragStop", ChallengesKeystoneFrame.StopMovingOrSizing)
end
