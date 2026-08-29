local addonName, addonTable = ...

addonTable.EnabledGossipIDs = {
    [135009] = true, -- 洞穴 (门口)
    [135010] = true, -- 洞穴 (老二)
    [137693] = true, -- 洞穴 (熏香人形态)
    [137694] = true, -- 洞穴 (熏香熊形态)
    [131567] = true, -- 密谋
    [131502] = true, -- 密谋
    [141729] = true, -- 毒牙
    [141730] = true, -- 毒牙
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

-------------------------------------------------------------------------------
-- 1. 自动选择对话选项的核心逻辑（带轮询重试，确保 100% 成功）
-------------------------------------------------------------------------------
-- 核心思想：不赌"固定延迟"，而是每 0.1 秒异步重新检查一次，
-- 直到选项真正可用并选择成功（最多重试 30 次 ≈ 3 秒）。
--
-- 【修复】之前只有"第一次读取就找到目标选项"时才启动重试，
-- 而首次打开对话时选项往往还没加载完（GetOptions 返回 nil 或不含目标项），
-- 于是第一轮直接 return / 找不到 → 从不重试 → 首次自动对话失败；
-- 关闭重开后数据已缓存，才碰巧成功。
-- 现在改为：打开对话就【无条件】进入轮询，选项一就绪立即选中；对话关闭则作废轮询。
-------------------------------------------------------------------------------

-- 轮询会话令牌：防止"关闭后残留的旧轮询"干扰下一次打开
local pollToken = 0

local function PollAndSelect(token, retryCount)
    retryCount = retryCount or 0
    -- 对话已关闭 / 已重新打开 → 立即放弃旧轮询
    if token ~= pollToken then return false end

    -- 每次都重新读取选项列表（页面可能刚刚才加载完）
    local options = C_GossipInfo.GetOptions()
    if options then
        for _, option in ipairs(options) do
            if addonTable.EnabledGossipIDs[option.gossipOptionID] then
                C_GossipInfo.SelectOption(option.gossipOptionID)
                pollToken = pollToken + 1 -- 选中成功，作废本次轮询
                return true
            end
        end
    end

    -- 还没就绪 → 0.1 秒后再试，直到成功或超时
    if retryCount < 30 then
        C_Timer.After(0.1, function()
            PollAndSelect(token, retryCount + 1)
        end)
    end
    return false
end

frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
frame:SetScript("OnEvent", function(self, event, interactionType)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if interactionType ~= Enum.PlayerInteractionType.Gossip then return end
        -- 兜底：不依赖第一次读取结果，直接进入轮询直到选项可用
        pollToken = pollToken + 1
        PollAndSelect(pollToken, 0)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        -- 对话关闭：作废进行中的轮询，避免残留选择
        pollToken = pollToken + 1
    end
end)