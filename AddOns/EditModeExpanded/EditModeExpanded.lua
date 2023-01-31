local lib = LibStub:GetLibrary("EditModeExpanded-1.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
        EMEOptions = {
            lfg = true,
            vehicle = true,
            holyPower = true,
            totem = true,
            soulShards = true,
            pet = true,
            achievementAlert = true,
            targetOfTarget = true,
            targetCast = true,
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
            menu = true,
            menuResizable = false,
            bags = true,
            bagsResizable = false,
        },
        QueueStatusButton = {},
        TotemFrame = {},
        PetFrame = {},
        VehicleSeatIndicator = {},
        HolyPower = {},
        Achievements = {},
        SoulShards = {},
        ToT = {},
        TargetSpellBar = {},
        FocusSpellBar = {},
        UIWidgetTopCenterContainerFrame = {},
        StanceBar = {},
        Runes = {},
        ArcaneCharges = {},
        Chi = {},
        EvokerEssences = {},
        PlayerFrame = {},
        MainStatusTrackingBarContainer = {},
        MicroMenu = {},
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
        vehicle = {
            name = "坐騎座位",
            desc = "啟用/停用支援坐騎座位",
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
        pet = {
            name = "寵物框架",
            desc = "啟用/停用支援寵物頭像框架",
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
        bagsResizable = {
            name = "調整背包列大小",
            desc = "讓背包列可以調整大小，比預設的選項了一些選項。警告: 這會覆蓋遊戲內建的調整大小滑桿，如果你兩種滑桿都使用，可能會發生不可預期的結果!",
            type = "toggle",
        },
    },
}

local achievementFrameLoaded
local petFrameLoaded
local addonLoaded
local totemFrameLoaded

local function registerTotemFrame(db)
    TotemFrame:SetParent(UIParent)
    lib:RegisterFrame(TotemFrame, "圖騰", db.TotemFrame)
    lib:SetDefaultSize(TotemFrame, 100, 40)
    lib:RegisterHideable(TotemFrame)
    totemFrameLoaded = true
end

f:SetScript("OnEvent", function(__, event, arg1)
    if (event == "ADDON_LOADED") and (arg1 == "EditModeExpanded") and (not addonLoaded) then
        f:UnregisterEvent("ADDON_LOADED")
        addonLoaded = true
        f.db = LibStub("AceDB-3.0"):New("EditModeExpandedADB", defaults)
        
        local db = f.db.global
        
        AceConfigRegistry:RegisterOptionsTable("EditModeExpanded", options)
        AceConfigDialog:AddToBlizOptions("EditModeExpanded", "編輯模式")
        
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            local name = frame:GetName()
            if not db[name] then db[name] = {} end
            lib:RegisterFrame(frame, "", db[name])
        end
        
        if db.EMEOptions.compactRaidFrameContainer then
            local originalFrameManagerX, originalFrameManagerY = CompactRaidFrameManager:GetRect()
            local wasMoved = false
            lib:RegisterCustomCheckbox(CompactRaidFrameContainer, "隱藏團隊框架管理員", 
                -- on checked
                function()
                    if wasMoved then return end
                    wasMoved = true
                    
                    -- this frame cannot be :Hide() hidden, as other frames are parented to it. Cannot change the parenting either, without causing other problems.
                    -- So, instead, lets shove it off the screen.
                    --local x, y = CompactRaidFrameContainer:GetRect()
                    originalFrameManagerX, originalFrameManagerY = CompactRaidFrameManager:GetRect()
                    CompactRaidFrameManager:ClearAllPoints()
                    CompactRaidFrameManager:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 0, 0)
                    --CompactRaidFrameContainer:ClearAllPoints()
                    --CompactRaidFrameContainer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                end,
                
                -- on unchecked
                function()
                    if not wasMoved then return end
                    wasMoved = false
                    
                    local x, y = CompactRaidFrameContainer:GetRect()
                    CompactRaidFrameManager:ClearAllPoints()
                    CompactRaidFrameManager:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", originalFrameManagerX, originalFrameManagerY)
                    CompactRaidFrameContainer:ClearAllPoints()
                    CompactRaidFrameContainer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                end
            )
        end
        
        if db.EMEOptions.talkingHead then
            lib:RegisterHideable(TalkingHeadFrame)
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
        
        local class = UnitClassBase("player")
        
        if class == "PALADIN" then
            if db.EMEOptions.holyPower then
                lib:RegisterFrame(PaladinPowerBarFrame, "聖能", db.HolyPower)
                C_Timer.After(4, function() lib:RepositionFrame(PaladinPowerBarFrame) end)
                lib:RegisterHideable(PaladinPowerBarFrame)
            end
            
            -- Totem Frame is used for Consecration
            if db.EMEOptions.totem then
                registerTotemFrame(db)
            end
        elseif class == "WARLOCK" then
            if db.EMEOptions.soulShards then
                lib:RegisterFrame(WarlockPowerFrame, "靈魂裂片", db.SoulShards)
                lib:RegisterHideable(WarlockPowerFrame)
                lib:SetDontResize(WarlockPowerFrame)
                hooksecurefunc(WarlockPowerFrame, "IsDirty", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(WarlockPowerFrame)
                    end
                end)
                lib:RegisterResizable(WarlockPowerFrame)
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
                lib:RegisterResizable(MonkHarmonyBarFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(MonkHarmonyBarFrame)
                    end
                end)
            end
        elseif class == "DEATHKNIGHT" then
            if db.EMEOptions.runes then
                lib:RegisterFrame(RuneFrame, "符文", db.Runes)
                lib:RegisterHideable(RuneFrame)
                lib:SetDontResize(RuneFrame)
                lib:RegisterResizable(RuneFrame)
                hooksecurefunc(PlayerFrameBottomManagedFramesContainer, "Layout", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(RuneFrame)
                    end
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
            end
        elseif class == "EVOKER" then
            if db.EMEOptions.evokerEssences then
                lib:RegisterFrame(EssencePlayerFrame, "龍能", db.EvokerEssences)
                lib:SetDontResize(EssencePlayerFrame)
                lib:RegisterHideable(EssencePlayerFrame)
                lib:RegisterResizable(EssencePlayerFrame)
                hooksecurefunc(EssencePowerBar, "UpdatePower", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(EssencePlayerFrame)
                    end
                end)
            end
        end
        
        
    elseif (event == "UNIT_PET") and (not petFrameLoaded) and (addonLoaded) then
        f:UnregisterEvent("UNIT_PET")
        if f.db.global.EMEOptions.pet then
            local function init()
                PetFrame:SetParent(UIParent)
                lib:RegisterFrame(PetFrame, "寵物框架", f.db.global.PetFrame)
            end
            
            if InCombatLockdown() then
                -- delay registering until combat ends
                local tempFrame = CreateFrame("Frame")
                tempFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                local doOnce
                tempFrame:SetScript("OnEvent", function()
                    if doOnce then return end
                    doOnce = true
                    init()
                    tempFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    lib:RepositionFrame(PetFrame)
                end)
            else
                init()
            end
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
            lib:RegisterResizable(QueueStatusButton)
            lib:RegisterMinimapPinnable(QueueStatusButton)
        end
        
        if db.EMEOptions.minimap then
            lib:RegisterResizable(MinimapCluster)
            C_Timer.After(1, function() lib:UpdateFrameResize(MinimapCluster) end)
        end
        
        if db.EMEOptions.uiWidgetTopCenterContainerFrame then
            lib:RegisterFrame(UIWidgetTopCenterContainerFrame, "子區域資訊", db.UIWidgetTopCenterContainerFrame)
            lib:SetDontResize(UIWidgetTopCenterContainerFrame)
        end
        
        if db.EMEOptions.stanceBar then
            lib:RegisterHideable(StanceBar)
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
                self.Title:SetText(frame.systemName.." ("..math.floor(frame:GetLeft())..","..math.floor(frame:GetBottom())..")")
            end)
            hooksecurefunc(EditModeExpandedSystemSettingsDialog, "UpdateSettings", function(self, frame)
                self.Title:SetText(frame.systemName.." ("..math.floor(frame:GetLeft())..","..math.floor(frame:GetBottom())..")")
            end)
        end
        
        if db.EMEOptions.playerFrame then
            lib:RegisterHideable(PlayerFrame)
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
        
        if db.EMEOptions.vehicle then
            VehicleSeatIndicator:SetPoint("TOPLEFT", DurabilityFrame, "TOPLEFT")
            lib:RegisterFrame(VehicleSeatIndicator, "坐騎座位", db.VehicleSeatIndicator)
            lib:RegisterResizable(VehicleSeatIndicator)
        end
        
        if db.EMEOptions.mainStatusTrackingBarContainer then
            lib:RegisterResizable(MainStatusTrackingBarContainer)
            lib:RegisterHideable(MainStatusTrackingBarContainer)
            C_Timer.After(1, function() lib:UpdateFrameResize(MainStatusTrackingBarContainer) end)
            hooksecurefunc(MainStatusTrackingBarContainer, "SetScale", function(frame, scale)
                if UnitLevel("player") < GetMaxLevelForLatestExpansion() then
                    StatusTrackingBarManager.bars[4]:SetScale(scale)
                else
                    StatusTrackingBarManager.bars[1]:SetScale(scale)
                end
            end)
            hooksecurefunc(MainStatusTrackingBarContainer, "SetScaleOverride", function(frame, scale)
                if UnitLevel("player") < GetMaxLevelForLatestExpansion() then
                    StatusTrackingBarManager.bars[4]:SetScale(scale)
                else
                    StatusTrackingBarManager.bars[1]:SetScale(scale)
                end
            end)
        end
        
        if db.EMEOptions.menu then
            lib:RegisterHideable(MicroMenu)
            C_Timer.After(1, function()
                if lib:IsFrameMarkedHidden(MicroMenu) then
                    MicroMenu:Hide()
                end
            end)
        end
        
        if db.EMEOptions.menuResizable then
            lib:RegisterResizable(MicroMenu)
            C_Timer.After(1, function()
                lib:UpdateFrameResize(MicroMenu)
            end)
        end
        
        if db.EMEOptions.bags then
            lib:RegisterHideable(BagsBar)
            C_Timer.After(1, function()
                if lib:IsFrameMarkedHidden(BagsBar) then
                    BagsBar:Hide()
                end
            end)
        end
        
        if db.EMEOptions.bagsResizable then
            lib:RegisterResizable(BagsBar)
            C_Timer.After(1, function()
                lib:UpdateFrameResize(BagsBar)
            end)
        end
    elseif (event == "PLAYER_TOTEM_UPDATE") then
        if totemFrameLoaded then
            lib:RepositionFrame(TotemFrame)
        end
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TOTEM_UPDATE")