local addonName, addonTable = ...

-- 开关控制：true 显示 ID，false 隐藏 ID
-- fix from MiliUI: 预设关闭。ID 只是拿来找 gossipOptionID 的除错显示，
-- 自动对话逻辑直接读 C_GossipInfo.GetOptions()，不靠这段文字。要找新 ID 时 /togid 打开。
addonTable.ShowGossipIDs = false

addonTable.EnabledGossipIDs = {
    [135009] = true, -- 洞穴 (门口)
    [135010] = true, -- 洞穴 (老二)
    [131567] = true, -- 密谋
    [131502] = true, -- 密谋
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

-------------------------------------------------------------------------------
-- 1. 自动选择对话选项的核心逻辑
-------------------------------------------------------------------------------
frame:SetScript("OnEvent", function(self, event, interactionType)
    if interactionType ~= Enum.PlayerInteractionType.Gossip then return end

    local options = C_GossipInfo.GetOptions()
    if not options then return end

    for _, option in ipairs(options) do
        if addonTable.EnabledGossipIDs[option.gossipOptionID] then
            C_Timer.After(0.05, function()
                if addonTable and addonTable.GetMediaPath then
                    PlaySoundFile(addonTable.GetMediaPath() .. "ZiDongDuiHua.ogg", DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master")
                end
                C_GossipInfo.SelectOption(option.gossipOptionID)
            end)
            break
        end
    end
end)

-------------------------------------------------------------------------------
-- 2. 对话框渲染修改逻辑（受 ShowGossipIDs 控制）
-------------------------------------------------------------------------------
local function UpdateButtonText(button)
    if not button or not button:IsShown() then return end

    local elementData = button.GetElementData and button:GetElementData()
    if not elementData then return end

    local info = elementData.info or elementData
    local gossipID = info and info.gossipOptionID
    local originalName = info and info.name

    if gossipID then
        local textFrame = button.Text or button.FontString
        local currentText = textFrame and textFrame:GetText() or button:GetText() or originalName or ""

        -- 【开启显示 ID】
        if addonTable.ShowGossipIDs then
            if currentText ~= "" and not string.find(currentText, "ID:") then
                local colorStr = addonTable.EnabledGossipIDs[gossipID] and "|cff00ff00" or "|cff808080"
                local newText = string.format("%s %s[ID: %d]|r", currentText, colorStr, gossipID)

                if textFrame and textFrame.SetText then
                    textFrame:SetText(newText)
                elseif button.SetText then
                    button:SetText(newText)
                end
            end
        -- 【关闭显示 ID】如果之前追加了 ID，还原为原始文字
        else
            if originalName and string.find(currentText, "ID:") then
                if textFrame and textFrame.SetText then
                    textFrame:SetText(originalName)
                elseif button.SetText then
                    button:SetText(originalName)
                end
            end
        end
    end
end

local function AppendGossipIDs()
    if not GossipFrame or not GossipFrame:IsShown() then return end

    local greetingPanel = GossipFrame.GreetingPanel
    if not greetingPanel and GossipFrame.InteractionDataFrame then
        greetingPanel = GossipFrame.InteractionDataFrame.GreetingPanel
    end

    if not greetingPanel or not greetingPanel.ScrollBox then return end

    greetingPanel.ScrollBox:ForEachFrame(function(button)
        UpdateButtonText(button)
    end)
end

-------------------------------------------------------------------------------
-- 3. Hook 机制
-------------------------------------------------------------------------------
if GossipFrame then
    hooksecurefunc(GossipFrame, "Update", function()
        C_Timer.After(0.02, AppendGossipIDs)
    end)
end

local function HookScrollBox()
    local greetingPanel = GossipFrame and (GossipFrame.GreetingPanel or (GossipFrame.InteractionDataFrame and GossipFrame.InteractionDataFrame.GreetingPanel))
    if greetingPanel and greetingPanel.ScrollBox and not greetingPanel.ScrollBox._hasIDHook then
        greetingPanel.ScrollBox._hasIDHook = true
        hooksecurefunc(greetingPanel.ScrollBox, "Update", function()
            C_Timer.After(0.01, AppendGossipIDs)
        end)
    end
end

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
hookFrame:SetScript("OnEvent", function(_, _, interactionType)
    if interactionType == Enum.PlayerInteractionType.Gossip then
        HookScrollBox()
        C_Timer.After(0.05, AppendGossipIDs)
    end
end)

-------------------------------------------------------------------------------
-- 4. 命令控制：输入 /togid 开关 ID 显示
-------------------------------------------------------------------------------
SLASH_TOGGLEGOSSIPID1 = "/togid"
SlashCmdList["TOGGLEGOSSIPID"] = function()
    addonTable.ShowGossipIDs = not addonTable.ShowGossipIDs
    local status = addonTable.ShowGossipIDs and "|cff00ff00开启|r" or "|cffff0000关闭|r"
    print("[AutoGossip] 对话框 ID 显示已" .. status)
    
    -- 如果当前打开着对话框，立即刷新显示
    if GossipFrame and GossipFrame:IsShown() then
        AppendGossipIDs()
    end
end