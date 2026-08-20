local addonName, AutoGossip = ...

AutoGossip.EnabledGossipIDs = {
    [135009] = true, -- 洞穴 (门口)
    [135010] = true, -- 洞穴 (老二)
    [137021] = true, -- 密谋
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

frame:SetScript("OnEvent", function(self, event, interactionType)
    if interactionType ~= Enum.PlayerInteractionType.Gossip then return end
    
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if not (level and level >= 2) then return end

    local options = C_GossipInfo.GetOptions()
    if not options then return end

    for _, option in ipairs(options) do
        if AutoGossip.EnabledGossipIDs[option.gossipOptionID] then
            C_Timer.After(0.05, function()
                C_GossipInfo.SelectOption(option.gossipOptionID)
            end)
            break
        end
    end
end)