local lib = LibStub:GetLibrary("EditModeExpanded-1.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- old character specific database, will remove legacy support eventually
local legacyDefaults = {
    profile = {
        MicroButtonAndBagsBar = {},
        BackpackBar = {},
        StatusTrackingBarManager = {},
        QueueStatusButton = {},
        TotemFrame = {},
        PetFrame = {},
        DurabilityFrame = {},
        VehicleSeatIndicator = {},
        HolyPower = {},
        Achievements = {},
        SoulShards = {},
    }
}
-- end legacy

local defaults = {
    global = {
        EMEOptions = {
            menu = true,
            xp = true,
            lfg = true,
            durability = true,
            vehicle = true,
            holyPower = true,
            totem = true,
            soulShards = true,
            pet = true,
            achievementAlert = true,
            targetOfTarget = true,
            targetCast = true,
            focusCast = true,
        },
        MicroButtonAndBagsBar = {},
        BackpackBar = {},
        StatusTrackingBarManager = {},
        QueueStatusButton = {},
        TotemFrame = {},
        PetFrame = {},
        DurabilityFrame = {},
        VehicleSeatIndicator = {},
        HolyPower = {},
        Achievements = {},
        SoulShards = {},
        ToT = {},
        TargetSpellBar = {},
        FocusSpellBar = {},
		CompactRaidFrameManager = {},
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
        menu = {
            name = "微型選單",
            desc = "啟用/停用支援微型選單",
            type = "toggle",
        },
        xp = {
            name = "經驗條",
            desc = "啟用/停用支援經驗條",
            type = "toggle",
        },
        lfg = {
            name = "排隊資訊",
            desc = "啟用/停用支援排隊資訊",
            type = "toggle", 
        },
        durability = {
            name = "裝備耐久度",
            desc = "啟用/停用支援裝備耐久度",
            type = "toggle",
        },
        vehicle = {
            name = "坐騎座位",
            desc = "啟用/停用支援坐騎座位",
            type = "toggle",
        },
        holyPower = {
            name = "聖能",
            desc = "啟用/停用支援聖能",
            type = "toggle",
        },
        totem = {
            name = "圖騰",
            desc = "啟用/停用支援",
            type = "toggle",
        },
        soulShards = {
            name = "靈魂裂片",
            desc = "啟用/停用支援靈魂裂片",
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
        
        --
        -- Start legacy db import - remove this eventually
        --
        local legacydb = LibStub("AceDB-3.0"):New("EditModeExpandedDB", legacyDefaults)
        legacydb = legacydb.profile
        for buttonName, buttonData in pairs(legacydb) do
            for k, v in pairs(buttonData) do
                if not db[buttonName].profiles then db[buttonName].profiles = {} end
                if buttonData.profiles then
                    for profileName, profileData in pairs(buttonData.profiles) do
                        if not db[buttonName].profiles[profileName] then
                            local t = {}
                            for str in string.gmatch(profileName, "([^\-]+)") do
                                table.insert(t, str)
                            end
                            local layoutType = t[1]
                            local layoutName = t[2]
                            
                            if layoutType == (Enum.EditModeLayoutType.Character.."") then
                                local unitName, unitRealm = UnitFullName("player")
                                profileName = layoutType.."-"..unitName.."-"..unitRealm.."-"..layoutName
                            end
                            
                            db[buttonName].profiles[profileName] = profileData
                        end
                    end
                end
                
                legacydb[buttonName] = {}
                break
            end
            
        end
        --
        -- End legacy db import
        --
        
        AceConfigRegistry:RegisterOptionsTable("EditModeExpanded", options)
        AceConfigDialog:AddToBlizOptions("EditModeExpanded", "編輯模式")
        
        if not IsAddOnLoaded("Dominos") and not IsAddOnLoaded("Bartender4") then -- moving/resizing found to be incompatible
            if db.EMEOptions.menu then
                lib:RegisterFrame(MicroButtonAndBagsBar, "微型選單", db.MicroButtonAndBagsBar)
                lib:RegisterResizable(MicroButtonAndBagsBarMovable)
                lib:RegisterHideable(MicroButtonAndBagsBarMovable)
                lib:RegisterResizable(EditModeExpandedBackpackBar)
                lib:RegisterHideable(EditModeExpandedBackpackBar)
            end
        
			if db.EMEOptions.xp then
				lib:RegisterFrame(StatusTrackingBarManager, "經驗條", db.StatusTrackingBarManager)
				lib:RegisterResizable(StatusTrackingBarManager)
			end
			
			if db.EMEOptions.lfg then
				QueueStatusButton:SetParent(UIParent)
				lib:RegisterFrame(QueueStatusButton, "排隊資訊", db.QueueStatusButton)
				lib:RegisterResizable(QueueStatusButton)
				lib:RegisterMinimapPinnable(QueueStatusButton)
			end
		end

        if db.EMEOptions.durability then
            DurabilityFrame:SetParent(UIParent)
            lib:RegisterFrame(DurabilityFrame, "裝備耐久度", db.DurabilityFrame)
            lib:RegisterResizable(DurabilityFrame)
        end
        
        if db.EMEOptions.vehicle then
            VehicleSeatIndicator:SetParent(UIParent)
            VehicleSeatIndicator:SetPoint("TOPLEFT", DurabilityFrame, "TOPLEFT")
            lib:RegisterFrame(VehicleSeatIndicator, "坐騎座位", db.VehicleSeatIndicator)
            lib:RegisterResizable(VehicleSeatIndicator)
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
                local i = 60
                hooksecurefunc(WarlockPowerFrame, "IsDirty", function()
                    if not EditModeManagerFrame.editModeActive then
                        lib:RepositionFrame(WarlockPowerFrame)
                    end
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
            lib:RegisterFrame(AchievementAlertSystem.alertContainer, "成就通知", f.db.global.Achievements)
            lib:SetDefaultSize(AchievementAlertSystem.alertContainer, 20, 20)
            AchievementAlertSystem.alertContainer.Selection:HookScript("OnMouseDown", function()
                AchievementAlertSystem:AddAlert(6)
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
            --TargetFrameSpellBar:HookScript("OnShow", function(self)
            --    lib:RepositionFrame(TargetFrameSpellBar)
            --end)
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