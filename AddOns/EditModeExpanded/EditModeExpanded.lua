local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
        EMEOptions = {
            lfg = true,
            holyPower = true,
            totem = true,
            soulShards = true,
            achievementAlert = true,
            targetOfTarget = true,
            targetCast = true,
            focusTargetOfTarget = true,
            focusCast = true,
            compactRaidFrameContainer = true,
            talkingHead = true,
            minimap = true,
            uiWidgetTopCenterContainerFrame = false,
            stanceBar = true,
            runes = true,
            arcaneCharges = true,
            chi = true,
            evokerEssences = true,
            showCoordinates = false,
            playerFrame = true,
            mainStatusTrackingBarContainer = true,
            secondaryStatusTrackingBarContainer = true,
            menu = true,
            menuResizable = false,
            bags = true,
            comboPoints = true,
            bonusRoll = true,
            actionBars = false,
            groupLootContainer = true,
            auctionMultisell = true,
            chatButtons = true,
            backpack = true,
        },
        QueueStatusButton = {},
        TotemFrame = {},
        HolyPower = {},
        Achievements = {},
        SoulShards = {},
        ToT = {},
        TargetSpellBar = {},
        FocusToT = {},
        FocusSpellBar = {},
        UIWidgetTopCenterContainerFrame = {},
        StanceBar = {},
        Runes = {},
        ArcaneCharges = {},
        Chi = {},
        EvokerEssences = {},
        PlayerFrame = {},
        MainStatusTrackingBarContainer = {},
        SecondaryStatusTrackingBarContainer = {},
        MicroMenu = {},
        ComboPoints = {},
        BonusRoll = {},
        MainMenuBar = {},
        MultiBarBottomLeft = {},
        MultiBarBottomRight = {},
        MultiBarRight = {},
        MultiBarLeft = {},
        MultiBar5 = {},
        MultiBar6 = {},
        MultiBar7 = {},
        CompactRaidFrameManager = {},
        ExpansionLandingPageMinimapButton = {},
        GroupLootContainer = {},
        AuctionHouseMultisellProgressFrame = {},
        QuickJoinToastButton = {},
        ChatFrameChannelButton = {},
        ChatFrameMenuButton = {},
        ContainerFrame1 = {},
        ContainerFrameCombinedBags = {},
    }
}

local f = CreateFrame("Frame")

local options = {
    type = "group",
    name = "編輯模式擴充包",
	set = function(info, value) f.db.global.EMEOptions[info[#info]] = value end,
    get = function(info) return f.db.global.EMEOptions[info[#info]] end,
    args = {
        description = {
            name = "所有變更都需要重新載入介面 /reload ! 如果你不想要插件動到某個框架，請取消勾選。",
            type = "description",
            fontSize = "medium",
            order = 0,
        },
        lfg = {
            name = "排隊資訊",
            desc = "啟用/停用支援排隊資訊",
            type = "toggle", 
        },
        holyPower = {
            name = "聖能",
            desc = "啟用/停用支援聖騎士的聖能",
            type = "toggle",
        },
        totem = {
            name = "圖騰",
            desc = "啟用/停用支援",
            type = "toggle",
        },
        soulShards = {
            name = "靈魂裂片",
            desc = "啟用/停用支援術士的靈魂裂片",
            type = "toggle",
        },
        achievementAlert = {
            name = "成就通知",
            desc = "啟用/停用支援成就通知",
            type = "toggle",
        },
        targetOfTarget = {
            name = "目標的目標",
            desc = "啟用/停用支援目標的目標框架",
            type = "toggle",
        },
        targetCast = {
            name = "目標施法條",
            desc = "啟用/停用支援目標施法條",
            type = "toggle",
        },
        focusTargetOfTarget = {
            name = "專注目標的目標",
            desc = "啟用/停用支援專注目標的目標",
            type = "toggle",
        },
        focusCast = {
            name = "專注目標施法條",
            desc = "啟用/停用支援專注目標施法條",
            type = "toggle",
        },
        compactRaidFrameContainer = {
            name = "團隊框架",
            desc = "啟用/停用團隊框架的額外選項",
            type = "toggle",
        },
        talkingHead = {
            name = "對話頭像",
            desc = "啟用/停用對話頭像的額外選項",
            type = "toggle",
        },
        minimap = {
            name = "小地圖",
            desc = "啟用/停用對話小地圖的額外選項",
            type = "toggle",
        },
        uiWidgetTopCenterContainerFrame = {
            name = "子區域資訊",
            desc = "啟用/停用支援畫面最頂端的子區域資訊。請注意，這個框架的行為...通常...如果你不在有顯示任何東西的地區時!",
            type = "toggle",
        },
        stanceBar = {
            name = "形態列",
            desc = "啟用/停用形態列的額外選項",
            type = "toggle",
        },
        runes = {
            name = "符文",
            desc = "啟用/停用支援死亡騎士的符文",
            type = "toggle",
        },
        arcaneCharges = {
            name = "祕法充能",
            desc = "啟用/停用支援法師的祕法充能",
            type = "toggle",
        },
        chi = {
            name = "真氣",
            desc = "啟用/停用支援武僧的真氣",
            type = "toggle",
        },
        evokerEssences = {
            name = "龍能",
            desc = "啟用/停用支援喚能師的龍能",
            type = "toggle",
        },
        showCoordinates = {
            name = "顯示座標",
            type = "toggle",
            desc = "顯示選取框架的視窗座標",
        },
        playerFrame = {
            name = "玩家框架",
            type = "toggle",
            desc = "啟用/停用玩家框架的額外選項",
        },
        mainStatusTrackingBarContainer = {
            name = "經驗條",
            desc = "啟用/停用玩經驗條的額外選項",
            type = "toggle",
        },
        secondaryStatusTrackingBarContainer = {
            name = "聲望條",
            desc = "啟用/停用玩聲望條的額外選項",
            type = "toggle",
        },
        menu = {
            name = "微型選單",
            desc = "啟用/停用玩微型選單的額外選項",
            type = "toggle",
        },
        bags = {
            name = "背包列",
            desc = "啟用/停用玩背包列的額外選項",
            type = "toggle",
        },
        menuResizable = {
            name = "調整微型選單大小",
            desc = "讓微型選單可以調整大小，比預設的選項了一些選項。警告: 這會覆蓋遊戲內建的調整大小滑桿，如果你兩種滑桿都使用，可能會發生不可預期的結果!",
            type = "toggle",
        },
        comboPoints = {
            name = "連擊點數",
            desc = "啟用/停用支援連擊點數",
            type = "toggle",
        },
        bonusRoll = {
            name = "骰子面板",
            desc = "啟用/停用支援骰子面板",
            type = "toggle",
        },
        actionBars = {
            name = "快捷列",
            desc = "允許快捷列的間距為零。警告: 所有快捷列都一定要至少移動過一次，不能完全不動，否則會發生錯誤。就算是移動後再移回原本的位置也可以!",
            type = "toggle",
        },
        groupLootContainer = {
            name = "獲得物品通知",
            desc = "啟用/停用獲得物品通知",
            type = "toggle",
        },
        auctionMultisell = {
            name = "拍賣場批次賣出",
            desc = "啟用/停用支援拍賣場批次賣出",
            type = "toggle",
        },
        chatButtons = {
            name = "聊天按鈕",
            desc = "啟用/停用支援聊天按鈕",
            type = "toggle",
        },
        backpack = {
            name = "背包",
            desc = "啟用/停用支援骰子面板",
            type = "toggle",
        },
    },
}

local achievementFrameLoaded
local addonLoaded
local totemFrameLoaded
local ahLoaded

local function registerTotemFrame(db)
    TotemFrame:SetParent(UIParent)
    lib:RegisterFrame(TotemFrame, "圖騰", db.TotemFrame)
    lib:SetDefaultSize(TotemFrame, 100, 40)
    lib:RegisterHideable(TotemFrame)
    lib:RegisterToggleInCombat(TotemFrame)
    lib:RegisterResizable(TotemFrame)
    totemFrameLoaded = true
end

f:SetScript("OnEvent", function(__, event, arg1)
    if (event == "ADDON_LOADED") and (arg1 == "EditModeExpanded") and (not addonLoaded) then
        addonLoaded = true
        f.db = LibStub("AceDB-3.0"):New("EditModeExpandedADB", defaults)
        
        local db = f.db.global
        
        AceConfigRegistry:RegisterOptionsTable("EditModeExpanded", options)
        AceConfigDialog:AddToBlizOptions("EditModeExpanded", "編輯模式")
        
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            local name = frame:GetName()
            
            -- was changed from MicroMenu to MicroMenuContainer in 10.1
            if name == "MicroMenuContainer" then
                name = "MicroMenu"
            end
            
            if not db[name] then db[name] = {} end
            lib:RegisterFrame(frame, "", db[name])
        end
        
        if db.EMEOptions.talkingHead then
            lib:RegisterHideable(TalkingHeadFrame)
            lib:RegisterToggleInCombat(TalkingHeadFrame)
            TalkingHeadFrame:HookScript("OnEvent", function(...)
                if lib:IsFrameMarkedHidden(TalkingHeadFrame) then
                    TalkingHeadFrame:Close()
                    TalkingHeadFrame:Hide()
                end
            end)
            lib:RegisterResizable(TalkingHeadFrame)
            -- should be moved to PLAYER_ENTERING_WORLD or something
            C_Timer.After(1, function()
                lib:UpdateFrameResize(TalkingHeadFrame)
            end)
        end
        
    elseif (event == "PLAYER_ENTERING_WORLD") and (not achievementFrameLoaded) and (addonLoaded) then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        achievementFrameLoaded = true
        local db = f.db.global
        
        if db.EMEOptions.achievementAlert then
            if ( not AchievementFrame ) then
    			AchievementFrame_LoadUI()
            end
            lib:RegisterFrame(AlertFrame, "成就通知", f.db.global.Achievements)
            lib:SetDefaultSize(AlertFrame, 20, 20)
            AlertFrame.Selection:HookScript("OnMouseDown", function()
                AchievementAlertSystem:AddAlert(6)
            end)
            AlertFrame:HookScript("OnEvent", function()
                lib:RepositionFrame(AlertFrame)
            end)
        end
        
        if db.EMEOptions.targetOfTarget then
            lib:RegisterFrame(TargetFrameToT, "目標的目標", f.db.global.ToT)
            lib:RegisterResizable(TargetFrameToT)
            TargetFrameToT:HookScript("OnHide", function()
                if (not InCombatLockdown()) and EditModeManagerFrame.editModeActive and lib:IsFrameEnabled(TargetFrameToT) then
                    TargetFrameToT:Show()
                end
            end)
        end
        
        if db.EMEOptions.targetCast then
            lib:RegisterFrame(TargetFrameSpellBar, "目標施法條", f.db.global.TargetSpellBar, TargetFrame, "TOPLEFT")
            hooksecurefunc(TargetFrameSpellBar, "AdjustPosition", function(self)
                lib:RepositionFrame(TargetFrameSpellBar)
                if EditModeManagerFrame.editModeActive then
                    TargetFrameSpellBar:Show()
                end
            end)
            TargetFrameSpellBar:HookScript("OnShow", function(self)
                lib:RepositionFrame(TargetFrameSpellBar)
            end)
            lib:SetDontResize(TargetFrameSpellBar)
            lib:RegisterResizable(TargetFrameSpellBar)            
        end
        
        if db.EMEOptions.focusTargetOfTarget then
            FocusFrameToT:SetUserPlaced(false) -- bug with frame being saved in layout cache leading to errors in TargetFrame.lua
            lib:RegisterFrame(FocusFrameToT, "專注目標的目標", f.db.global.FocusToT, FocusFrame, "TOPRIGHT")
            lib:RegisterResizable(FocusFrameToT)
            FocusFrameToT:HookScript("OnHide", function()
                if (not InCombatLockdown()) and EditModeManagerFrame.editModeActive and lib:IsFrameEnabled(FocusFrameToT) then
                    FocusFrameToT:Show()
                end
            end)
            hooksecurefunc(FocusFrameToT, "SetPoint", function()
                if FocusFrameToT:IsUserPlaced() then
                    FocusFrameToT:SetUserPlaced(false)
                end
            end)
        end
        
        if db.EMEOptions.focusCast then
            lib:RegisterFrame(FocusFrameSpellBar, "專注目標施法條", f.db.global.FocusSpellBar, FocusFrame, "TOPLEFT")
            lib:SetDontResize(FocusFrameSpellBar)
            hooksecurefunc(FocusFrameSpellBar, "AdjustPosition", function(self)
                if EditModeManagerFrame.editModeActive then
                    FocusFrameSpellBar:Show()
                end
                lib:RepositionFrame(FocusFrameSpellBar)
            end)
            FocusFrameSpellBar:HookScript("OnShow", function(self)
                lib:RepositionFrame(FocusFrameSpellBar)
            end)
        end
        
        if db.EMEOptions.lfg then
            QueueStatusButton:SetParent(UIParent)
            lib:RegisterFrame(QueueStatusButton, "排隊資訊", db.QueueStatusButton)
            hooksecurefunc(MicroMenu, "UpdateQueueStatusAnchors", function()
                lib:RepositionFrame(QueueStatusButton)
            end)
            hooksecurefunc(MicroMenuContainer, "Layout", function()
                MicroMenuContainer:SetWidth(MicroMenu:GetWidth()*MicroMenu:GetScale())
            end)
            MicroMenuContainer:SetWidth(MicroMenu:GetWidth()*MicroMenu:GetScale())
            
            -- the wasVisible saved in the library when entering Edit Mode cannot be relied upon, as entering Edit Mode shows the queue status button even if its hidden
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
                if InCombatLockdown() then return end
                QueueStatusFrame:Update()
            end)
        end
        
        if db.EMEOptions.minimap then
            local isDefault = true
            lib:RegisterCustomCheckbox(MinimapCluster, "Square",
                function()
                    isDefault = false
                    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
                    MinimapBackdrop:Hide()
                end,
                
                function()
                    -- don't change it to circle if it is already a circle from the last login
                    if isDefault then return end
                    Minimap:SetMaskTexture("Interface\\Masks\\CircleMask")
                    MinimapBackdrop:Show()
                end
            )
            
            if ExpansionLandingPageMinimapButton then
                ExpansionLandingPageMinimapButton:SetParent(UIParent)
                ExpansionLandingPageMinimapButton:SetFrameStrata("MEDIUM")
                lib:RegisterFrame(ExpansionLandingPageMinimapButton, "資料片功能按鈕", db.ExpansionLandingPageMinimapButton)
                lib:RegisterResizable(ExpansionLandingPageMinimapButton)
                hooksecurefunc(ExpansionLandingPageMinimapButton, "UpdateIcon", function()
                    lib:RepositionFrame(ExpansionLandingPageMinimapButton)
                end)
            end
        end
        
        if db.EMEOptions.uiWidgetTopCenterContainerFrame then
            lib:RegisterFrame(UIWidgetTopCenterContainerFrame, "子區域資訊", db.UIWidgetTopCenterContainerFrame)
            lib:SetDontResize(UIWidgetTopCenterContainerFrame)
        end
        
        if db.EMEOptions.stanceBar then
            lib:RegisterHideable(StanceBar)
            lib:RegisterToggleInCombat(StanceBar)
            hooksecurefunc(StanceBar, "Show", function()
                if lib:IsFrameMarkedHidden(StanceBar) then
                    StanceBar:Hide()
                end
            end)
            hooksecurefunc(StanceBar, "SetShown", function()
                if lib:IsFrameMarkedHidden(StanceBar) then
                    StanceBar:Hide()
                end
            end)
            
            C_Timer.After(1, function()
                if lib:IsFrameMarkedHidden(StanceBar) then
                    StanceBar:Hide()
                end
            end)
        end
        
        if db.EMEOptions.showCoordinates then 
            hooksecurefunc(EditModeExpandedSystemSettingsDialog, "AttachToSystemFrame", function(self, frame)
                self.Title:SetText(frame:GetSystemName().." ("..math.floor(frame:GetLeft())..","..math.floor(frame:GetBottom())..")")
            end)
            hooksecurefunc(EditModeExpandedSystemSettingsDialog, "UpdateSettings", function(self, frame)
                self.Title:SetText(frame:GetSystemName().." ("..math.floor(frame:GetLeft())..","..math.floor(frame:GetBottom())..")")
            end)
        end
        
        if db.EMEOptions.playerFrame then
            lib:RegisterHideable(PlayerFrame)
            lib:RegisterToggleInCombat(PlayerFrame)
            C_Timer.After(4, function()
                if lib:IsFrameMarkedHidden(PlayerFrame) then
                    PlayerFrame:Hide()
                end
            end)
            
            local checked = false
            lib:RegisterCustomCheckbox(PlayerFrame, "隱藏資源條", 
                -- on checked
                function()
                    checked = true
                    PlayerFrame.manabar:Hide()
                end,
                
                -- on unchecked
                function()
                    checked = false
                    PlayerFrame.manabar:Show()
                end
            )
            PlayerFrame.manabar:HookScript("OnShow", function()
                if checked then
                    PlayerFrame.manabar:Hide()
                end
            end)
        end
        
        if db.EMEOptions.mainStatusTrackingBarContainer then
            lib:RegisterResizable(MainStatusTrackingBarContainer)
            lib:RegisterHideable(MainStatusTrackingBarContainer)
            lib:RegisterToggleInCombat(MainStatusTrackingBarContainer)
            C_Timer.After(1, function() lib:UpdateFrameResize(MainStatusTrackingBarContainer) end)
            hooksecurefunc(MainStatusTrackingBarContainer, "SetScale", function(frame, scale)
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == MainStatusTrackingBarContainer then
                        bar:SetScale(scale) 
                    end
                end
            end)
            hooksecurefunc(MainStatusTrackingBarContainer, "SetScaleOverride", function(frame, scale)
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == MainStatusTrackingBarContainer then
                        bar:SetScale(scale) 
                    end
                end
            end)
            
            hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", function()
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == MainStatusTrackingBarContainer then
                        bar:SetScale(MainStatusTrackingBarContainer:GetScale()) 
                    end
                end
            end)
        end
        
        if db.EMEOptions.secondaryStatusTrackingBarContainer then
            lib:RegisterResizable(SecondaryStatusTrackingBarContainer)
            lib:RegisterHideable(SecondaryStatusTrackingBarContainer)
            lib:RegisterToggleInCombat(SecondaryStatusTrackingBarContainer)
            C_Timer.After(1, function() lib:UpdateFrameResize(SecondaryStatusTrackingBarContainer) end)
            hooksecurefunc(SecondaryStatusTrackingBarContainer, "SetScale", function(frame, scale)
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == SecondaryStatusTrackingBarContainer then
                        bar:SetScale(scale) 
                    end
                end
            end)
            hooksecurefunc(SecondaryStatusTrackingBarContainer, "SetScaleOverride", function(frame, scale)
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == SecondaryStatusTrackingBarContainer then
                        bar:SetScale(scale) 
                    end
                end
            end)
            
            hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", function()
                for _, bar in ipairs(StatusTrackingBarManager.barContainers) do
                    local _, anchor = bar:GetPoint(1)
                    if anchor == SecondaryStatusTrackingBarContainer then
                        bar:SetScale(SecondaryStatusTrackingBarContainer:GetScale()) 
                    end
                end
            end)
        end
        
        if db.EMEOptions.menu then
            lib:RegisterHideable(MicroMenuContainer)
            lib:RegisterToggleInCombat(MicroMenuContainer)
            C_Timer.After(1, function()
                if lib:IsFrameMarkedHidden(MicroMenuContainer) then
                    MicroMenuContainer:Hide()
                end
            end)
            local enabled = false
            local padding
            lib:RegisterCustomCheckbox(MicroMenuContainer, "Set padding to zero",
                function()
                    enabled = true
                    for key, button in ipairs(MicroMenu:GetLayoutChildren()) do
                        if key ~= 1 then
                            local a, b, c, d, e = button:GetPoint(1)
                            if (key == 2) and (not padding) then
                                padding = d
                            end
                            button:ClearAllPoints()
                            button:SetPoint(a, b, c, d-(3*(key-1)), e)
                        end
                    end
                    MicroMenu:SetWidth(MicroMenu:GetWidth() - 30)
                    MicroMenuContainer:SetWidth(MicroMenu:GetWidth()*MicroMenu:GetScale())
                end,
                
                function(init)
                    if not init then
                        enabled = false
                        for key, button in ipairs(MicroMenu:GetLayoutChildren()) do
                            if key ~= 1 then
                                local a, b, c, d, e = button:GetPoint(1)
                                button:ClearAllPoints()
                                button:SetPoint(a, b, c, d+(3*(key-1)), e)
                            end
                        end
                        MicroMenu:SetWidth(MicroMenu:GetWidth() + 30)
                        MicroMenuContainer:SetWidth(MicroMenu:GetWidth()*MicroMenu:GetScale())
                    end
                end
            )
            hooksecurefunc(MicroMenuContainer, "Layout", function(...)
                if OverrideActionBar.isShown then return end
                if PetBattleFrame and PetBattleFrame:IsShown() then return end

                if enabled and padding and ((math.floor((select(4, MicroMenu:GetLayoutChildren()[2]:GetPoint(1))*100) + 0.5)/100) == (math.floor((padding*100) + 0.5)/100)) then
                    for key, button in ipairs(MicroMenu:GetLayoutChildren()) do
                        if key ~= 1 then
                            local a, b, c, d, e = button:GetPoint(1)
                            button:ClearAllPoints()
                            button:SetPoint(a, b, c, d-(3*(key-1)), e)
                        end
                    end
                    MicroMenu:SetWidth(MicroMenu:GetWidth() - 30)
                end
            end)
        end
        
        if db.EMEOptions.menuResizable then
            lib:RegisterResizable(MicroMenuContainer)
            C_Timer.After(1, function()
                lib:UpdateFrameResize(MicroMenuContainer)
            end)
            
            -- triggers when player leaves a vehicle or pet battle
            hooksecurefunc("ResetMicroMenuPosition", function(...)
                lib:UpdateFrameResize(MicroMenuContainer)
            end)
        end
        
        if db.EMEOptions.bags then
            lib:RegisterHideable(BagsBar)
            lib:RegisterToggleInCombat(BagsBar)
            C_Timer.After(1, function()
                if lib:IsFrameMarkedHidden(BagsBar) then
                    BagsBar:Hide()
                end
            end)
        end
        
        if db.EMEOptions.bonusRoll then
            local alreadyInitialized
            
            BonusRollFrame:HookScript("OnShow", function()
                if alreadyInitialized then
                    lib:RepositionFrame(BonusRollFrame)
                    return
                end
                alreadyInitialized = true
                lib:RegisterFrame(BonusRollFrame, "骰子面板", db.BonusRoll)
                lib:HideByDefault(BonusRollFrame)
                BonusRollFrame.Selection:SetFrameStrata("TOOLTIP")
            end)
        end
        
        if db.EMEOptions.groupLootContainer then
            local alreadyInitialized
            GroupLootContainer:HookScript("OnShow", function()
                if alreadyInitialized then
                    lib:RepositionFrame(GroupLootContainer)
                    return
                end
                alreadyInitialized = true
                lib:RegisterFrame(GroupLootContainer, "獲得物品通知", db.GroupLootContainer)
                local noInfinite
                hooksecurefunc(GroupLootContainer, "SetPoint", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(GroupLootContainer)
                    noFinite = nil
                end)
                hooksecurefunc("GroupLootContainer_Update", function()
                    lib:RepositionFrame(GroupLootContainer)
                end)
                hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", function()
                    lib:RepositionFrame(GroupLootContainer)
                end)
            end)
        end
        
        if db.EMEOptions.actionBars then
            C_Timer.After(10, function()
                if InCombatLockdown() then return end 
                local bars = {MainMenuBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7}

                for _, bar in ipairs(bars) do
                    lib:RegisterCustomCheckbox(bar, "圖示內間距設為零", 
                        -- on checked
                        function()
                            bar.minButtonPadding = 0
                            bar.buttonPadding = 0
                            bar:UpdateGridLayout()
                        end,
                        
                        -- on unchecked
                        function()
                            bar.minButtonPadding = 2
                            bar.buttonPadding = 2
                            bar:UpdateGridLayout()
                        end,
                        
                        "OverrideIconPadding"
                    )
                end
            end)
        end
        
        if db.EMEOptions.chatButtons then
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
        
        do
            local alreadyInit, noInfinite
            ContainerFrame1:HookScript("OnShow", function()
                if alreadyInit then return end
                alreadyInit = true
                lib:RegisterFrame(ContainerFrame1, "主背包", db.ContainerFrame1)
                hooksecurefunc("UpdateContainerFrameAnchors", function()
                    if noInfinite then return end
                    if InCombatLockdown() then return end
                    noInfinite = true
                    lib:RepositionFrame(ContainerFrame1)
                    noInfinite = false
                end)
            end)
        end
        
        do
            local alreadyInit, noInfinite
            ContainerFrameCombinedBags:HookScript("OnShow", function()
                if alreadyInit then return end
                alreadyInit = true
                lib:RegisterFrame(ContainerFrameCombinedBags, "合併背包", db.ContainerFrameCombinedBags)
                hooksecurefunc("UpdateContainerFrameAnchors", function()
                    if noInfinite then return end
                    if InCombatLockdown() then return end
                    noInfinite = true
                    lib:RepositionFrame(ContainerFrameCombinedBags)
                    noInfinite = false
                end)
            end)
        end
        
        local class = UnitClassBase("player")
        
        if class == "PALADIN" then
            if db.EMEOptions.holyPower then
                lib:RegisterFrame(PaladinPowerBarFrame, "聖能", db.HolyPower)
                C_Timer.After(4, function() lib:RepositionFrame(PaladinPowerBarFrame) end)
                lib:RegisterHideable(PaladinPowerBarFrame)
                lib:RegisterToggleInCombat(PaladinPowerBarFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(PaladinPowerBarFrame)
                        if lib:IsFrameMarkedHidden(PaladinPowerBarFrame) then
                            PaladinPowerBarFrame:Hide()
                        end
                    end
                end)
                local noInfinite
                hooksecurefunc(PaladinPowerBarFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(PaladinPowerBarFrame)
                    noInfinite = false
                end)
            end
            
            -- Totem Frame is used for Consecration
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
        elseif class == "WARLOCK" then
            if db.EMEOptions.soulShards then
                lib:RegisterFrame(WarlockPowerFrame, "靈魂裂片", db.SoulShards)
                lib:RegisterHideable(WarlockPowerFrame)
                lib:RegisterToggleInCombat(WarlockPowerFrame)
                lib:SetDontResize(WarlockPowerFrame)
                lib:RegisterResizable(WarlockPowerFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(WarlockPowerFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(WarlockPowerFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(WarlockPowerFrame)
                    noInfinite = false
                end)
            end
            
            -- Totem Frame is used for Summon Darkglare
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
        elseif class == "SHAMAN" then
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
        elseif class == "MONK" then
            -- Summon black ox uses totem frame
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
            
            if db.EMEOptions.chi then
                lib:RegisterFrame(MonkHarmonyBarFrame, "真氣", db.Chi)
                lib:SetDontResize(MonkHarmonyBarFrame)
                lib:RegisterHideable(MonkHarmonyBarFrame)
                lib:RegisterToggleInCombat(MonkHarmonyBarFrame)
                lib:RegisterResizable(MonkHarmonyBarFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(MonkHarmonyBarFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(MonkHarmonyBarFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(MonkHarmonyBarFrame)
                    noInfinite = false
                end)
            end
        elseif class == "DEATHKNIGHT" then
            if db.EMEOptions.runes then
                lib:RegisterFrame(RuneFrame, "符文", db.Runes)
                lib:RegisterHideable(RuneFrame)
                lib:RegisterToggleInCombat(RuneFrame)
                lib:SetDontResize(RuneFrame)
                lib:RegisterResizable(RuneFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(RuneFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(RuneFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(RuneFrame)
                    noInfinite = false
                end)
                lib:RegisterCustomCheckbox(RuneFrame, "取消和玩家框架的連結 (需要重新載入)", 
                    --onChecked
                    function()
                        RuneFrame:SetParent(UIParent)
                    end,
                    --onUnchecked
                    function()
                        RuneFrame:SetParent(PlayerFrameBottomManagedFramesContainer)
                    end
                )
            end
        elseif class == "MAGE" then
            if db.EMEOptions.arcaneCharges then
                lib:RegisterFrame(MageArcaneChargesFrame, "祕法充能", db.ArcaneCharges)
                lib:RegisterHideable(MageArcaneChargesFrame)
                lib:RegisterToggleInCombat(MageArcaneChargesFrame)
                lib:SetDontResize(MageArcaneChargesFrame)
                lib:RegisterResizable(MageArcaneChargesFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(MageArcaneChargesFrame)
                    end
                end)
                hooksecurefunc(MageArcaneChargesFrame, "HandleBarSetup", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(MageArcaneChargesFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(MageArcaneChargesFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(MageArcaneChargesFrame)
                    noInfinite = false
                end)
            end
        elseif class == "EVOKER" then
            if db.EMEOptions.evokerEssences then
                lib:RegisterFrame(EssencePlayerFrame, "龍能", db.EvokerEssences)
                lib:SetDontResize(EssencePlayerFrame)
                lib:RegisterHideable(EssencePlayerFrame)
                lib:RegisterToggleInCombat(EssencePlayerFrame)
                lib:RegisterResizable(EssencePlayerFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(EssencePlayerFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(EssencePlayerFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(EssencePlayerFrame)
                    noInfinite = false
                end)
            end
            
        elseif class == "ROGUE" then
            if db.EMEOptions.comboPoints then
                lib:RegisterFrame(RogueComboPointBarFrame, "連擊點數", db.ComboPoints)
                lib:SetDontResize(RogueComboPointBarFrame)
                lib:RegisterHideable(RogueComboPointBarFrame)
                lib:RegisterToggleInCombat(RogueComboPointBarFrame)
                lib:RegisterResizable(RogueComboPointBarFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(RogueComboPointBarFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(RogueComboPointBarFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(RogueComboPointBarFrame)
                    noInfinite = false
                end)
            end
        elseif class == "PRIEST" then
            -- shadowfiend uses totem frame
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
        elseif class == "DRUID" then
            if db.EMEOptions.comboPoints then
                lib:RegisterFrame(DruidComboPointBarFrame, "連擊點數", db.ComboPoints)
                lib:SetDontResize(DruidComboPointBarFrame)
                lib:RegisterHideable(DruidComboPointBarFrame)
                lib:RegisterToggleInCombat(DruidComboPointBarFrame)
                lib:RegisterResizable(DruidComboPointBarFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(DruidComboPointBarFrame)
                    end
                end)
                local noInfinite
                hooksecurefunc(DruidComboPointBarFrame, "Show", function()
                    if noInfinite then return end
                    noInfinite = true
                    lib:RepositionFrame(DruidComboPointBarFrame)
                    noInfinite = false
                end)
            end
        end
    elseif (event == "PLAYER_TOTEM_UPDATE") and addonLoaded then
        if totemFrameLoaded then
            lib:RepositionFrame(TotemFrame)
        end
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        local db = f.db.global
        if db.EMEOptions.compactRaidFrameContainer then
            local layoutInfo = EditModeManagerFrame:GetActiveLayoutInfo()
            if layoutInfo.layoutType == 0 then return end
            f:UnregisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
            
            lib:RegisterFrame(CompactRaidFrameManager, "團隊管理員", db.CompactRaidFrameManager, nil, nil, false)
            
            local expanded
            hooksecurefunc("CompactRaidFrameManager_Expand", function()
                if InCombatLockdown() then return end
                if expanded then return end
                expanded = true
                CompactRaidFrameManager:ClearPoint("TOPLEFT")
                lib:RepositionFrame(CompactRaidFrameManager)
                for i = 1, CompactRaidFrameManager:GetNumPoints() do
                    local a, b, c, x, e = CompactRaidFrameManager:GetPoint(i)
                    x = x + 175
                    CompactRaidFrameManager:SetPoint(a,b,c,x,e)
                end
            end)
            hooksecurefunc("CompactRaidFrameManager_Collapse", function()
                if InCombatLockdown() then return end
                if not expanded then return end
                expanded = false
                CompactRaidFrameManager:ClearPoint("TOPLEFT")
                lib:RepositionFrame(CompactRaidFrameManager)
            end)
            lib:RegisterHideable(CompactRaidFrameManager)
            lib:RegisterToggleInCombat(CompactRaidFrameManager)
            
            -- the wasVisible saved in the library when entering Edit Mode cannot be relied upon, as entering Edit Mode shows the raid manager in some situations, before we can detect if it was already visible
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
                if InCombatLockdown() then return end
                CompactRaidFrameManager:SetShown(IsInGroup() or IsInRaid())
            end)
            
            do
                local noInfinite
                hooksecurefunc(CompactRaidFrameManager, "SetShown", function()
                    if noInfinite then return end
                    if InCombatLockdown() then return end
                    if EditModeManagerFrame.editModeActive then
                        CompactRaidFrameManager:Show()
                    else
                        noInfinite = true
                        lib:RepositionFrame(CompactRaidFrameManager)
                        if not (IsInGroup() or IsInRaid()) then
                            CompactRaidFrameManager:Hide()
                        end
                        noInfinite = false
                    end
                end)
                hooksecurefunc(CompactRaidFrameManager, "Show", function()
                    if noInfinite then return end
                    if InCombatLockdown() then return end
                    if not EditModeManagerFrame.editModeActive then
                        noInfinite = true
                        lib:RepositionFrame(CompactRaidFrameManager)
                        if not (IsInGroup() or IsInRaid()) then
                            CompactRaidFrameManager:Hide()
                        end
                        noInfinite = false
                    end
                end)
                
            end
        end
    elseif (event == "ADDON_LOADED") and (arg1 == "Blizzard_AuctionHouseUI") and (not ahLoaded) then
        ahLoaded = true
        local db = f.db.global
        
        if db.EMEOptions.auctionMultisell then
            local alreadyInitialized
            AuctionHouseMultisellProgressFrame:HookScript("OnShow", function()
                if alreadyInitialized then
                    lib:RepositionFrame(AuctionHouseMultisellProgressFrame)
                    return
                end
                alreadyInitialized = true
                lib:RegisterFrame(AuctionHouseMultisellProgressFrame, "拍賣場批次賣出", db.AuctionHouseMultisellProgressFrame)
                hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", function()
                    lib:RepositionFrame(AuctionHouseMultisellProgressFrame)
                end)
            end)
        end
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TOTEM_UPDATE")
f:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
