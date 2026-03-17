-- AutoStoryStroll: 自動點擊故事漫遊 Gossip 選項
-- /story 開關功能，按住 Shift 暫停自動選擇
local KEYWORD = "故事漫遊"
local TELEPORT_KEYWORD = "傳送"
local EXIT_KEYWORD = "退出"

local enabled = false

-- 斜線指令 /story 開關
SLASH_AUTOSTORYSTROLL1 = "/story"
SlashCmdList["AUTOSTORYSTROLL"] = function()
    enabled = not enabled
    if enabled then
        print("|cff00ff00[MiliUI]|r 故事漫遊自動點擊：|cff00ff00已啟用|r")
    else
        print("|cff00ff00[MiliUI]|r 故事漫遊自動點擊：|cffff4444已停用|r")
    end
end

-- 自動選擇 Gossip 選項：優先「傳送」，其次「故事漫遊」（排除「退出」）
-- 自動確認 Gossip 確認彈窗（GOSSIP_CONFIRM）
local frame = CreateFrame("Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CONFIRM")
frame:SetScript("OnEvent", function(self, event, ...)
    if not enabled or IsShiftKeyDown() then return end

    if event == "GOSSIP_SHOW" then
        local options = C_GossipInfo.GetOptions()
        if not options then return end

        -- 優先找「傳送」或「重新開始」（加 confirmed 跳過確認）
        for _, opt in ipairs(options) do
            if opt.name and (opt.name:find(TELEPORT_KEYWORD) or opt.name:find("重新開始")) then
                C_GossipInfo.SelectOption(opt.gossipOptionID, "", true)
                return
            end
        end

        -- 其次找「故事漫遊」但排除「退出故事漫遊」
        for _, opt in ipairs(options) do
            if opt.name and opt.name:find(KEYWORD) and not opt.name:find(EXIT_KEYWORD) then
                C_GossipInfo.SelectOption(opt.gossipOptionID, "", true)
                return
            end
        end

    elseif event == "GOSSIP_CONFIRM" then
        local gossipID, text = ...
        C_GossipInfo.SelectOption(gossipID, "", true)
        StaticPopup_Hide("GOSSIP_CONFIRM")
    end
end)

-- 自動確認「重新開始」的 StaticPopup（確定/取消）
local function TryAutoConfirmRestart(popup, index)
    if not enabled then return end
    C_Timer.After(0.5, function()
        if not popup:IsShown() then return end
        local displayedText = ""
        local textRegion = _G["StaticPopup" .. index .. "Text"]
        if textRegion and textRegion.GetText then
            displayedText = textRegion:GetText() or ""
        end
        if displayedText:find(KEYWORD) and displayedText:find("從頭開始") then
            local dialog = popup.which and StaticPopupDialogs[popup.which]
            if dialog and dialog.OnAccept then
                dialog.OnAccept(popup, popup.data, popup.data2)
            end
            popup:Hide()
        end
    end)
end

for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup then
        popup:HookScript("OnShow", function(self)
            TryAutoConfirmRestart(self, i)
        end)
    end
end
