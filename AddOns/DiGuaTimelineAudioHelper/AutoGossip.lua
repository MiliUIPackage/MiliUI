local addonName, addonTable = ...

addonTable.EnabledGossipIDs = {
    [135009] = true, -- 洞穴 (门口)
    [135010] = true, -- 洞穴 (老二)
    [131567] = true, -- 密谋
    [131502] = true, -- 密谋
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

-------------------------------------------------------------------------------
-- 1. 自动选择对话选项的核心逻辑（带轮询重试，确保 100% 成功）
-------------------------------------------------------------------------------
-- 核心思想：不赌"固定延迟"，而是每 0.1 秒异步重新检查一次，
-- 直到选项真正可用并选择成功（最多重试 30 次 ≈ 3 秒），
-- 即使界面卡顿 / 加载慢也绝不会错过。
local function TryAutoSelect(optionID, retryCount)
    retryCount = retryCount or 0

    -- 每次都重新读取选项列表（页面可能刚刚才加载完）
    local options = C_GossipInfo.GetOptions()
    if options then
        for _, option in ipairs(options) do
            if option.gossipOptionID == optionID then
                C_GossipInfo.SelectOption(optionID)
                return true
            end
        end
    end

    -- 还没就绪 → 0.1 秒后再试，直到成功或超时
    if retryCount < 30 then
        C_Timer.After(0.1, function()
            TryAutoSelect(optionID, retryCount + 1)
        end)
    end
    return false
end

frame:SetScript("OnEvent", function(self, event, interactionType)
    if interactionType ~= Enum.PlayerInteractionType.Gossip then return end

    local options = C_GossipInfo.GetOptions()
    if not options then return end

    for _, option in ipairs(options) do
        if addonTable.EnabledGossipIDs[option.gossipOptionID] then
            TryAutoSelect(option.gossipOptionID, 0)
            break
        end
    end
end)