------------------------------------------------------------
-- 聊天視窗滑過連結直接顯示 tooltip（不用點）
------------------------------------------------------------
local _, ns = ...

local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
    or (Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows)
    or 10

local supported = {
    achievement = true, battlepet = true, currency = true, enchant = true,
    item = true, journal = true, mount = true, quest = true, spell = true,
}

local hookedFrames = {}
local showingTooltip

local function GetLinkType(link)
    if type(link) ~= "string" then return end
    return link:match("^([^:]+):")
end

local function OnHyperlinkEnter(frame, link, text)
    if not ns.db or not ns.db.general.chatHover then return end
    local linkType = GetLinkType(link)
    if linkType then linkType = string.lower(linkType) end
    if not linkType or not supported[linkType] then return end

    GameTooltip:Hide()
    ns.Anchor.skipNext = true
    GameTooltip:SetOwner(frame or UIParent, "ANCHOR_CURSOR")

    if linkType == "battlepet" and BattlePetToolTip_ShowLink and BattlePetTooltip then
        showingTooltip = BattlePetTooltip
        if BattlePetTooltip.SetOwner then
            pcall(BattlePetTooltip.SetOwner, BattlePetTooltip, frame or UIParent, "ANCHOR_CURSOR")
        end
        BattlePetToolTip_ShowLink(text)
        return
    end

    showingTooltip = GameTooltip
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if ok then
        GameTooltip:Show()
    else
        ns.Anchor.skipNext = nil
        showingTooltip = nil
    end
end

local function OnHyperlinkLeave()
    if showingTooltip and showingTooltip.Hide then
        showingTooltip:Hide()
    end
    ns.Anchor.skipNext = nil
    showingTooltip = nil
end

local function HookChatFrame(frame)
    if not frame or hookedFrames[frame] then return end
    frame:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
    frame:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
    hookedFrames[frame] = true
end

local function HookAll()
    for i = 1, NUM_CHAT_WINDOWS do
        HookChatFrame(_G["ChatFrame" .. i])
    end
    local communities = CommunitiesFrame and CommunitiesFrame.Chat and CommunitiesFrame.Chat.MessageFrame
    HookChatFrame(communities)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_CHAT_WINDOWS")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_Communities" then HookAll() end
        return
    end
    HookAll()
end)
