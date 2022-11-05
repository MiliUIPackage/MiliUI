local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

local defaults = {
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
    }
}

local petFrameLoaded
local addonLoaded
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(__, event, arg1)
    if (event == "ADDON_LOADED") and (arg1 == "EditModeExpanded") and (not addonLoaded) then
        addonLoaded = true
        f.db = LibStub("AceDB-3.0"):New("EditModeExpandedDB", defaults)
        
        local db = f.db.profile

        lib:RegisterFrame(MicroButtonAndBagsBar, "微型選單", db.MicroButtonAndBagsBar)
        lib:RegisterResizable(MicroButtonAndBagsBarMovable)
        lib:RegisterResizable(EditModeExpandedBackpackBar)
        lib:RegisterHideable(MicroButtonAndBagsBarMovable)
        lib:RegisterHideable(EditModeExpandedBackpackBar)
        
        lib:RegisterFrame(StatusTrackingBarManager, "經驗條", db.StatusTrackingBarManager)
        lib:RegisterResizable(StatusTrackingBarManager)
        
        QueueStatusButton:SetParent(UIParent)
        lib:RegisterFrame(QueueStatusButton, "排隊資訊", db.QueueStatusButton)
        lib:RegisterResizable(QueueStatusButton)
        
        TotemFrame:SetParent(UIParent)
        lib:RegisterFrame(TotemFrame, "圖騰", db.TotemFrame)
        lib:SetDefaultSize(TotemFrame, 100, 40)

        DurabilityFrame:SetParent(UIParent)
        lib:RegisterFrame(DurabilityFrame, "裝備耐久度", db.DurabilityFrame)
        lib:RegisterResizable(DurabilityFrame)
        
        VehicleSeatIndicator:SetParent(UIParent)
        VehicleSeatIndicator:SetPoint("TOPLEFT", DurabilityFrame, "TOPLEFT")
        lib:RegisterFrame(VehicleSeatIndicator, "坐騎座位", db.VehicleSeatIndicator)
        lib:RegisterResizable(VehicleSeatIndicator)
        
        if UnitClassBase("player") == "PALADIN" then
            lib:RegisterFrame(PaladinPowerBarFrame, "聖能", db.HolyPower)
        end
        
        if ( not AchievementFrame ) then
			AchievementFrame_LoadUI()
        end
        lib:RegisterFrame(AchievementAlertSystem.alertContainer, "成就通知", db.Achievements)
        lib:SetDefaultSize(AchievementAlertSystem.alertContainer, 300, 80)
    elseif (event == "UNIT_PET") and (not petFrameLoaded) and (addonLoaded) then
        petFrameLoaded = true
        --PetFrame:SetParent(UIParent)
        --lib:RegisterFrame(PetFrame, "寵物", f.db.profile.PetFrame)
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("UNIT_PET")