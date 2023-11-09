local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

function addon:initChatButtons()
    local db = addon.db.global
    if not db.EMEOptions.chatButtons then return end
    lib:RegisterFrame(QuickJoinToastButton, "社交", db.QuickJoinToastButton)
    lib:SetDontResize(QuickJoinToastButton)
    lib:RegisterHideable(QuickJoinToastButton)
    
    lib:RegisterFrame(ChatFrameChannelButton, "頻道", db.ChatFrameChannelButton)
    lib:SetDontResize(ChatFrameChannelButton)
    lib:RegisterHideable(ChatFrameChannelButton)
    
    lib:RegisterFrame(ChatFrameMenuButton, "聊天選單", db.ChatFrameMenuButton)
    lib:SetDontResize(ChatFrameMenuButton)
    lib:RegisterHideable(ChatFrameMenuButton)
    
    lib:GroupOptions({QuickJoinToastButton, ChatFrameChannelButton, ChatFrameMenuButton}, "聊天按鈕")
end
