local addonName = ...
local addon = _G[addonName]
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local LibStub = addon.LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("TLDRMissions")

addon.GUI = CreateFrame("Frame", "TLDRMissionsFrame", UIParent, "BackdropTemplate")
local gui = addon.GUI
gui:Hide()
gui:SetSize(350, 640)
if not gui:IsUserPlaced() then
    gui:SetPoint("CENTER")
end
gui:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11, },
})
gui:SetFrameStrata("DIALOG")
gui:EnableMouse(true)
gui:SetMovable(true)
gui:SetClampedToScreen(true)
gui:RegisterForDrag("LeftButton")
gui:SetScript("OnDragStart", function(self)
    self:SetUserPlaced(true)
    self:StartMoving()
  end)
gui:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local tldrRight = gui:GetRight()
    local tldrTop = gui:GetTop()
    local covLeft = CovenantMissionFrame:GetLeft()
    local covTop = CovenantMissionFrame:GetTop()
    
    -- accomodate other addons that can make the mission frame movable - allow clamping the GUI back to the left side of the mission frame
    if CovenantMissionFrame and CovenantMissionFrame:IsMovable() then
        if (((covLeft - 20) < tldrRight) and ((covLeft + 20) > tldrRight)) and (((covTop - 25) < tldrTop) and ((covTop + 5) > tldrTop)) then
            self:SetUserPlaced(false)
            self:ClearAllPoints()
            self:SetPoint("RIGHT", CovenantMissionFrame, "LEFT")
        end
    end
  end)

gui.CloseButton = CreateFrame("Button", "TLDRMissionsFrameCloseButton", gui, "UIPanelCloseButton")
gui.CloseButton:SetPoint("TOPRIGHT", -6, -4)
gui.CloseButton:SetScript("OnClick", function()
    gui:SetShown(false)
end) 

gui.TitleBarTexture = gui:CreateTexture("TLDRMissionsTitleBar", "BORDER", nil, -1)
gui.TitleBarTexture:SetPoint("TOPLEFT", gui, "TOPLEFT", 10, 7)
gui.TitleBarTexture:SetPoint("TOPRIGHT", gui, "TOPRIGHT", -10, 7)
gui.TitleBarTexture:SetHeight(40)
gui.TitleBarTexture:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Top")
gui.TitleBarTexture:SetTexCoord(0, 1, 0, 0.14)

gui.TitleBarLabel = gui:CreateFontString("TLDRMissionsTitleBarLabel", "OVERLAY", "GameFontNormal")
gui.TitleBarLabel:SetPoint("CENTER", gui.TitleBarTexture, "CENTER", 0, -7)
gui.TitleBarLabel:SetText(addonName.." "..GetAddOnMetadata(addonName, "Version"))

--
-- Tab one: main frame
--

gui.MainTabButton = CreateFrame("Button", "TLDRMissionsFrameTab1", gui, "PanelTabButtonTemplate")
gui.MainTabButton:SetPoint("TOPLEFT", gui, "BOTTOMLEFT", 0, 5)
gui.MainTabButton:SetText(GARRISON_MISSIONS)
gui.MainTabButton:SetScript("OnClick", function()
    PanelTemplates_SetTab(gui, 1)
    gui.AdvancedTabPanel:Hide()
    gui.MainTabPanel:Show()
end)
gui.MainTabButton:SetID(1)

gui.MainTabPanel = CreateFrame("Frame", "TLDRMissionsFrameMainPanel", gui)
gui.MainTabPanel:SetPoint("TOPLEFT", gui, "TOPLEFT")

local function setupButton(categoryName, setPointTo, text, acSetPointTo)
    local name = categoryName.."CheckButton"
    gui[name] = CreateFrame("CheckButton", "TLDRMissionsFrame"..categoryName.."CheckButton", gui.MainTabPanel, "UICheckButtonTemplate")
    gui[name]:SetPoint("TOPLEFT", setPointTo, 0, -22)
    _G["TLDRMissionsFrame"..categoryName.."CheckButtonText"]:SetText(text)
    
    gui[name].ExclusionLabel = gui[name]:CreateFontString("TLDRMissions"..categoryName.."ExclusionLabel", "OVERLAY", "GameFontNormalLarge")
    gui[name].ExclusionLabel:SetText("X")
    gui[name].ExclusionLabel:SetPoint("CENTER", gui[name], "CENTER", 0, 0)
    gui[name].ExclusionLabel:SetTextColor(1, 0, 0)
    gui[name].ExclusionLabel:Hide()

    local plname = categoryName.."PriorityLabel"
    gui[plname] = gui.MainTabPanel:CreateFontString("TLDRMissions"..categoryName.."PriorityLabel", "OVERLAY", "GameFontNormal")
    gui[plname]:SetPoint("TOPLEFT", gui[name], -15, -10)

    local acname = categoryName.."AnimaCostDropDown"
    gui[acname] = LibDD:Create_UIDropDownMenu("TLDRMissions"..categoryName.."AnimaCostDropDown", gui.MainTabPanel)
    gui[acname]:SetPoint("TOPRIGHT", acSetPointTo, 0, -22)
    LibDD:UIDropDownMenu_SetWidth(gui[acname], 10)
    LibDD:UIDropDownMenu_SetText(gui[acname], "")
end

setupButton("Gold", gui.TitleBarTexture, BONUS_ROLL_REWARD_MONEY, gui.TitleBarTexture)
gui.GoldCheckButton:SetPoint("TOPLEFT", gui.TitleBarTexture, "BOTTOMLEFT", 20, 0)
gui.GoldAnimaCostDropDown:SetPoint("TOPRIGHT", gui.TitleBarTexture, "BOTTOMRIGHT", 10, 0)

setupButton("Anima", gui.GoldCheckButton, "靈魄", gui.GoldAnimaCostDropDown)

gui.AnimaDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsAnimaDropDown", gui.MainTabPanel)
gui.AnimaDropDown:SetPoint("TOPRIGHT", gui.AnimaAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.AnimaDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.AnimaDropDown, "")

setupButton("FollowerXPItems", gui.AnimaCheckButton, L["FollowerXPItems"], gui.AnimaAnimaCostDropDown)

gui.FollowerXPItemsDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsFollowerXPItemsDropDown", gui.MainTabPanel)
gui.FollowerXPItemsDropDown:SetPoint("TOPRIGHT", gui.FollowerXPItemsAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.FollowerXPItemsDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.FollowerXPItemsDropDown, "")

setupButton("PetCharms", gui.FollowerXPItemsCheckButton, L["PetCharms"], gui.FollowerXPItemsAnimaCostDropDown)
setupButton("AugmentRunes", gui.PetCharmsCheckButton, L["AugmentRunes"], gui.PetCharmsAnimaCostDropDown)
setupButton("Reputation", gui.AugmentRunesCheckButton, L["ReputationTokens"], gui.AugmentRunesAnimaCostDropDown)

gui.ReputationDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsReputationDropDown", gui.MainTabPanel)
gui.ReputationDropDown:SetPoint("TOPRIGHT", gui.ReputationAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.ReputationDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.ReputationDropDown, "")

setupButton("FollowerXP", gui.ReputationCheckButton, L["BonusFollowerXP"], gui.ReputationAnimaCostDropDown)
setupButton("CraftingCache", gui.FollowerXPCheckButton, L["CraftingMaterials"], gui.FollowerXPAnimaCostDropDown)

gui.CraftingCacheDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsCraftingCacheDropDown", gui.MainTabPanel)
gui.CraftingCacheDropDown:SetPoint("TOPRIGHT", gui.CraftingCacheAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.CraftingCacheDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.CraftingCacheDropDown, "")

setupButton("Runecarver", gui.CraftingCacheCheckButton, L["RunecarverRewards"], gui.CraftingCacheAnimaCostDropDown)

gui.RunecarverDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsRunecarverDropDown", gui.MainTabPanel)
gui.RunecarverDropDown:SetPoint("TOPRIGHT", gui.RunecarverAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.RunecarverDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.RunecarverDropDown, "")

setupButton("Campaign", gui.RunecarverCheckButton, L["CampaignProgress"], gui.RunecarverAnimaCostDropDown)

gui.CampaignDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsCampaignDropDown", gui.MainTabPanel)
gui.CampaignDropDown:SetPoint("TOPRIGHT", gui.CampaignAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.CampaignDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.CampaignDropDown, "")

setupButton("Gear", gui.CampaignCheckButton, WORLD_QUEST_REWARD_FILTERS_EQUIPMENT, gui.CampaignAnimaCostDropDown)

gui.GearDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsGearDropDown", gui.MainTabPanel)
gui.GearDropDown:SetPoint("TOPRIGHT", gui.GearAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.GearDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.GearDropDown, "")

setupButton("SanctumFeature", gui.GearCheckButton, COVENANT_PREVIEW_SANCTUM_FEATURE, gui.GearAnimaCostDropDown)

gui.SanctumFeatureDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsSanctumFeatureDropDown", gui.MainTabPanel)
gui.SanctumFeatureDropDown:SetPoint("TOPRIGHT", gui.SanctumFeatureAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.SanctumFeatureDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.SanctumFeatureDropDown, "")

setupButton("AnythingForXP", gui.SanctumFeatureCheckButton, L["AnythingForXPLabel"], gui.SanctumFeatureAnimaCostDropDown)

gui.AnythingForXPDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsAnythingForXPDropDown", gui.MainTabPanel)
gui.AnythingForXPDropDown:SetPoint("TOPRIGHT", gui.AnythingForXPAnimaCostDropDown, "TOPLEFT", 20, 0)
LibDD:UIDropDownMenu_SetWidth(gui.AnythingForXPDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.AnythingForXPDropDown, "")

gui.SacrificeCheckButton = CreateFrame("CheckButton", "TLDRMissionsFrameSacrificeCheckButton", gui.MainTabPanel, "UICheckButtonTemplate")
gui.SacrificeCheckButton:SetPoint("TOPLEFT", gui.AnythingForXPCheckButton, 0, -22)
TLDRMissionsFrameSacrificeCheckButtonText:SetText(L["SacrificeLabel"])

gui.CalculateButton = CreateFrame("Button", "TLDRMissionsFrameCalculateButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.CalculateButton:SetPoint("TOPLEFT", gui.SacrificeCheckButton, -10, -30)
gui.CalculateButton:SetText(L["Calculate"])
gui.CalculateButton:SetWidth(100)
gui.CalculateButton:SetEnabled(false)

gui.AbortButton = CreateFrame("Button", "TLDRMissionsFrameAbortButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.AbortButton:SetPoint("TOPLEFT", gui.CalculateButton, "TOPRIGHT", 10, 0)
gui.AbortButton:SetText(CANCEL)
gui.AbortButton:SetWidth(60)
gui.AbortButton:SetEnabled(false)

gui.SkipCalculationButton = CreateFrame("Button", "TLDRMissionsFrameSkipCalculationButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.SkipCalculationButton:SetPoint("TOPLEFT", gui.AbortButton, "TOPRIGHT", 10, 0)
gui.SkipCalculationButton:SetText(L["Skip"])
gui.SkipCalculationButton:SetWidth(60)
gui.SkipCalculationButton:SetEnabled(false)

gui.FailedCalcLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameFailedCalcLabel", "OVERLAY", "GameFontNormal")
gui.FailedCalcLabel:SetPoint("TOPLEFT", gui.CalculateButton, 0, -30)
gui.FailedCalcLabel:SetSize(280,40)
gui.FailedCalcLabel:SetNonSpaceWrap(true)
gui.FailedCalcLabel:SetWordWrap(true)
gui.FailedCalcLabel:SetMaxLines(3)
gui.FailedCalcLabel:SetJustifyH("LEFT")
gui.FailedCalcLabel:SetJustifyV("TOP")
gui.FailedCalcLabel:SetTextColor(1, 0.5, 0)

gui.NextMissionLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextMissionLabel", "OVERLAY", "GameFontNormal")
gui.NextMissionLabel:SetPoint("TOPLEFT", gui.CalculateButton, 0, -30)

gui.NextFollower1Label = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextFollower1Label", "OVERLAY", "GameFontNormal")
gui.NextFollower1Label:SetPoint("TOPLEFT", gui.NextMissionLabel, 0, -15)

gui.NextFollower2Label = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextFollower2Label", "OVERLAY", "GameFontNormal")
gui.NextFollower2Label:SetPoint("TOPLEFT", gui.NextFollower1Label, 0, -15)

gui.NextFollower3Label = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextFollower3Label", "OVERLAY", "GameFontNormal")
gui.NextFollower3Label:SetPoint("TOPLEFT", gui.NextFollower2Label, 0, -15)

gui.NextFollower4Label = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextFollower4Label", "OVERLAY", "GameFontNormal")
gui.NextFollower4Label:SetPoint("TOPLEFT", gui.NextFollower3Label, 0, -15)

gui.NextFollower5Label = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameNextFollower5Label", "OVERLAY", "GameFontNormal")
gui.NextFollower5Label:SetPoint("TOPLEFT", gui.NextFollower4Label, 0, -15)

gui.RewardsLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameRewardsLabel", "OVERLAY", "GameFontNormal")
gui.RewardsLabel:SetPoint("TOPLEFT", gui.NextFollower5Label, 0, -20)
gui.RewardsLabel:SetText(GUILD_TAB_REWARDS..":")

gui.RewardsDetailLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameRewardsDetailLabel", "OVERLAY", "GameFontNormal")
gui.RewardsDetailLabel:SetPoint("TOPLEFT", gui.RewardsLabel, "TOPRIGHT", 10, 0)
gui.RewardsDetailLabel:SetSize(200,40)
gui.RewardsDetailLabel:SetNonSpaceWrap(true)
gui.RewardsDetailLabel:SetWordWrap(true)
gui.RewardsDetailLabel:SetMaxLines(3)
gui.RewardsDetailLabel:SetJustifyH("LEFT")
gui.RewardsDetailLabel:SetJustifyV("TOP")

gui.StartMissionButton = CreateFrame("Button", "TLDRMissionsFrameStartMissionButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.StartMissionButton:SetPoint("TOPLEFT", gui.RewardsLabel, 0, -50)
gui.StartMissionButton:SetText(GARRISON_START_MISSION)
gui.StartMissionButton:SetWidth(100)
gui.StartMissionButton:SetEnabled(false)

gui.SkipMissionButton = CreateFrame("Button", "TLDRMissionsFrameSkipMissionButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.SkipMissionButton:SetPoint("TOPLEFT", gui.StartMissionButton, "TOPRIGHT", 10, 0)
gui.SkipMissionButton:SetText(L["Skip"])
gui.SkipMissionButton:SetWidth(60)
gui.SkipMissionButton:SetEnabled(false)

gui.CostLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameCostLabel", "OVERLAY", "GameFontNormal")
gui.CostLabel:SetPoint("TOPLEFT", gui.SkipMissionButton, "TOPRIGHT", 5, -4)
gui.CostLabel:SetText(COSTS_LABEL)
gui.CostLabel:Hide()

gui.CostResultLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameCostResultLabel", "OVERLAY", "GameFontNormal")
gui.CostResultLabel:SetPoint("TOPLEFT", gui.CostLabel, "TOPRIGHT", 2, 0)

gui.LowTimeWarningLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameLowTimeWarningLabel", "OVERLAY", "GameFontNormal")
gui.LowTimeWarningLabel:SetPoint("BOTTOMLEFT", gui.StartMissionButton, "TOPLEFT", 0, 2)
gui.LowTimeWarningLabel:SetTextColor(1, 0, 0)

gui.EstimateLabel = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameEstimateLabel", "OVERLAY", "GameFontNormal")
gui.EstimateLabel:SetPoint("TOPLEFT", gui.StartMissionButton, 0, -25)

for i = 1, 5 do
    gui["EstimateFollower"..i.."Label"] = gui.MainTabPanel:CreateFontString("TLDRMissionsFrameEstimateFollower"..i.."Label", "OVERLAY", "GameFontNormal")
    local g = gui["EstimateFollower"..i.."Label"]
    if i == 1 then
        g:SetPoint("TOPLEFT", gui.EstimateLabel, "BOTTOMLEFT", 0, -2)
    elseif i == 3 then
        g:SetPoint("TOPLEFT", gui.EstimateLabel, "TOPRIGHT", 10, 0)
    else
        g:SetPoint("TOPLEFT", gui["EstimateFollower"..(i-1).."Label"], "BOTTOMLEFT", 0, -2)
    end
end

gui.CompleteMissionsButton = CreateFrame("Button", "TLDRMissionsFrameCompleteMissionsButton", gui.MainTabPanel, "UIPanelButtonTemplate")
gui.CompleteMissionsButton:SetPoint("BOTTOM", gui, "BOTTOM", 0, 10)
gui.CompleteMissionsButton:SetText(L["CompleteMissionButtonText"])
TLDRMissionsFrameCompleteMissionsButtonText:SetScale(1.2)
gui.CompleteMissionsButton:SetWidth(240)
gui.CompleteMissionsButton:SetHeight(25)
gui.CompleteMissionsButton:SetEnabled(true)

--
-- Advanced tab
--

gui.AdvancedTabPanel = CreateFrame("Frame", "TLDRMissionsFrameAdvancedPanel", gui)
gui.AdvancedTabPanel:SetPoint("TOPLEFT", gui, "TOPLEFT")
gui.AdvancedTabPanel:Hide()

gui.AdvancedTabButton = CreateFrame("Button", "TLDRMissionsFrameTab2", gui, "PanelTabButtonTemplate")
gui.AdvancedTabButton:SetPoint("TOPLEFT", gui.MainTabButton, "TOPRIGHT", 0, 0)
gui.AdvancedTabButton:SetText(ADVANCED_LABEL)
gui.AdvancedTabButton:SetScript("OnClick", function()
    PanelTemplates_SetTab(gui, 2)
    gui.AdvancedTabPanel:Show()
    gui.MainTabPanel:Hide()
end)
gui.AdvancedTabButton:SetID(2)

gui.HardestOrEasiestLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsFrameHardestOrEasiestLabel", "OVERLAY", "GameFontNormal")
gui.HardestOrEasiestLabel:SetPoint("TOPLEFT", gui.TitleBarTexture, "BOTTOMLEFT", 25, 0)
gui.HardestOrEasiestLabel:SetText(L["HardestOrEasiest"])

gui.HardestRadioButton = CreateFrame("CheckButton", "TLDRMissionsHardestRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.HardestRadioButton:SetPoint("TOPLEFT", gui.HardestOrEasiestLabel, 0, -20)
TLDRMissionsHardestRadioButtonText:SetText(L["Hardest"])
gui.HardestRadioButton:SetChecked(false)

gui.EasiestRadioButton = CreateFrame("CheckButton", "TLDRMissionsEasiestRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.EasiestRadioButton:SetPoint("LEFT", gui.HardestRadioButton, "RIGHT", 60, 0)
TLDRMissionsEasiestRadioButtonText:SetText(L["Easiest"])
gui.EasiestRadioButton:SetChecked(true)

gui.HardestRadioButton:HookScript("OnClick", function()
    addon.db.profile.hardestOrEasiest = "hard"
    gui.EasiestRadioButton:SetChecked(false)
end)

gui.EasiestRadioButton:HookScript("OnClick", function()
    addon.db.profile.hardestOrEasiest = "easy"
    gui.HardestRadioButton:SetChecked(false)
end)

gui.FewestOrMostLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsFrameFewestOrMostLabel", "OVERLAY", "GameFontNormal")
gui.FewestOrMostLabel:SetPoint("TOPLEFT", gui.HardestRadioButton, 0, -20)
gui.FewestOrMostLabel:SetText(L["FewestOrMost"])

gui.FewestRadioButton = CreateFrame("CheckButton", "TLDRMissionsFewestRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.FewestRadioButton:SetPoint("TOPLEFT", gui.FewestOrMostLabel, 0, -20)
TLDRMissionsFewestRadioButtonText:SetText(L["Fewest"])
gui.FewestRadioButton:SetChecked(true)

gui.MostRadioButton = CreateFrame("CheckButton", "TLDRMissionsMostRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.MostRadioButton:SetPoint("LEFT", gui.FewestRadioButton, "RIGHT", 60, 0)
TLDRMissionsMostRadioButtonText:SetText(L["Most"])
gui.MostRadioButton:SetChecked(false)

gui.FewestRadioButton:HookScript("OnClick", function()
    addon.db.profile.fewestOrMost = "fewest"
    gui.MostRadioButton:SetChecked(false)
end)

gui.MostRadioButton:HookScript("OnClick", function()
    addon.db.profile.fewestOrMost = "most"
    gui.FewestRadioButton:SetChecked(false)
end)

gui.LowestOrHighestLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsFrameLowestOrHighestLabel", "OVERLAY", "GameFontNormal")
gui.LowestOrHighestLabel:SetPoint("TOPLEFT", gui.FewestRadioButton, 0, -20)
gui.LowestOrHighestLabel:SetText(L["LowestOrHighest"])

gui.LowestRadioButton = CreateFrame("CheckButton", "TLDRMissionsLowestRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.LowestRadioButton:SetPoint("TOPLEFT", gui.LowestOrHighestLabel, 0, -20)
TLDRMissionsLowestRadioButtonText:SetText(L["Lowest"])
gui.LowestRadioButton:SetChecked(true)

gui.HighestRadioButton = CreateFrame("CheckButton", "TLDRMissionsHighestRadioButton", gui.AdvancedTabPanel, "UIRadioButtonTemplate")
gui.HighestRadioButton:SetPoint("LEFT", gui.LowestRadioButton, "RIGHT", 60, 0)
TLDRMissionsHighestRadioButtonText:SetText(L["Highest"])
gui.HighestRadioButton:SetChecked(false)

gui.LowestRadioButton:HookScript("OnClick", function()
    addon.db.profile.lowestOrHighest = "lowest"
    gui.HighestRadioButton:SetChecked(false)
end)

gui.HighestRadioButton:HookScript("OnClick", function()
    addon.db.profile.lowestOrHighest = "highest"
    gui.LowestRadioButton:SetChecked(false)
end)

gui.MinimumTroopsLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsMinimumTroopsLabel", "OVERLAY", "GameFontNormal")
gui.MinimumTroopsLabel:SetPoint("TOPLEFT", gui.LowestRadioButton, -20, -20)
gui.MinimumTroopsLabel:SetText(L["MinimumTroops"])
gui.MinimumTroopsLabel:SetWordWrap(true)
gui.MinimumTroopsLabel:SetWidth(300)

gui.MinimumTroopsSlider = CreateFrame("Slider", "TLDRMissionsFrameMinimumTroopsSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.MinimumTroopsSlider:SetPoint("TOPLEFT", gui.MinimumTroopsLabel, 20, -10)
gui.MinimumTroopsSlider:SetSize(280, 20)
TLDRMissionsFrameMinimumTroopsSliderLow:SetText("0")
TLDRMissionsFrameMinimumTroopsSliderHigh:SetText("4")
TLDRMissionsFrameMinimumTroopsSliderText:SetText("4")
TLDRMissionsFrameMinimumTroopsSliderText:ClearAllPoints()
TLDRMissionsFrameMinimumTroopsSliderText:SetPoint("TOP", TLDRMissionsFrameMinimumTroopsSlider, "BOTTOM", 0, 3)
TLDRMissionsFrameMinimumTroopsSliderText:SetFontObject("GameFontHighlightSmall")
TLDRMissionsFrameMinimumTroopsSliderText:SetTextColor(0, 1, 0)
gui.MinimumTroopsSlider:SetOrientation('HORIZONTAL')
gui.MinimumTroopsSlider:SetValueStep(1)
gui.MinimumTroopsSlider:SetObeyStepOnDrag(true)
gui.MinimumTroopsSlider:SetMinMaxValues(0, 4)
gui.MinimumTroopsSlider:SetValue(4)

gui.FollowerXPSpecialTreatmentCheckButton = CreateFrame("CheckButton", "TLDRMissionsFrameFollowerXPSpecialTreatmentCheckButton", gui.AdvancedTabPanel, "UICheckButtonTemplate")
gui.FollowerXPSpecialTreatmentCheckButton:SetPoint("TOPLEFT", gui.MinimumTroopsSlider, -20, -30)
TLDRMissionsFrameFollowerXPSpecialTreatmentCheckButtonText:SetText(L["FollowerXPSpecialTreatment"])

gui.FollowerXPSpecialTreatmentCheckButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(gui.FollowerXPSpecialTreatmentCheckButton, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["FollowerXPSpecialTreatmentTooltip"], 1, 1, 1,  0.75, true)
    GameTooltip:Show()
end)
gui.FollowerXPSpecialTreatmentCheckButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

gui.FollowerXPSpecialTreatmentCheckButton:HookScript("OnClick", function()
    addon.db.profile.followerXPSpecialTreatment = gui.FollowerXPSpecialTreatmentCheckButton:GetChecked()
end)

gui.FollowerXPSpecialTreatmentDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsFollowerXPSpecialTreatmentDropDown", gui.AdvancedTabPanel)
gui.FollowerXPSpecialTreatmentDropDown:SetPoint("TOPLEFT", TLDRMissionsFrameFollowerXPSpecialTreatmentCheckButtonText, "TOPRIGHT", -10, 8)
LibDD:UIDropDownMenu_SetWidth(gui.FollowerXPSpecialTreatmentDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.FollowerXPSpecialTreatmentDropDown, "")

gui.FollowerXPSpecialTreatmentAlgorithmDropDown = LibDD:Create_UIDropDownMenu("TLDRMissionsFollowerXPSpecialTreatmentAlgorithmDropDown", gui.AdvancedTabPanel)
gui.FollowerXPSpecialTreatmentAlgorithmDropDown:SetPoint("TOPLEFT", gui.FollowerXPSpecialTreatmentDropDown, "TOPRIGHT", -30, 0)
LibDD:UIDropDownMenu_SetWidth(gui.FollowerXPSpecialTreatmentAlgorithmDropDown, 10)
LibDD:UIDropDownMenu_SetText(gui.FollowerXPSpecialTreatmentAlgorithmDropDown, "")

gui.LowerBoundLevelRestrictionLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsLowerBoundLevelRestrictionLabel", "OVERLAY", "GameFontNormal")
gui.LowerBoundLevelRestrictionLabel:SetPoint("TOPLEFT", gui.FollowerXPSpecialTreatmentCheckButton, 0, -30)
gui.LowerBoundLevelRestrictionLabel:SetText(L["LevelRestriction"])
gui.LowerBoundLevelRestrictionLabel:SetWordWrap(true)
gui.LowerBoundLevelRestrictionLabel:SetWidth(300)

gui.LowerBoundLevelRestrictionSlider = CreateFrame("Slider", "TLDRMissionsFrameSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.LowerBoundLevelRestrictionSlider:SetPoint("TOPLEFT", gui.LowerBoundLevelRestrictionLabel, 20, -20)
gui.LowerBoundLevelRestrictionSlider:SetSize(280, 20)
TLDRMissionsFrameSliderLow:SetText("1")
TLDRMissionsFrameSliderHigh:SetText("60")
TLDRMissionsFrameSliderText:SetText("3")
TLDRMissionsFrameSliderText:ClearAllPoints()
TLDRMissionsFrameSliderText:SetPoint("TOP", TLDRMissionsFrameSlider, "BOTTOM", 0, 3)
TLDRMissionsFrameSliderText:SetFontObject("GameFontHighlightSmall")
TLDRMissionsFrameSliderText:SetTextColor(0, 1, 0)
gui.LowerBoundLevelRestrictionSlider:SetOrientation('HORIZONTAL')
gui.LowerBoundLevelRestrictionSlider:SetValueStep(1)
gui.LowerBoundLevelRestrictionSlider:SetObeyStepOnDrag(true)
gui.LowerBoundLevelRestrictionSlider:SetMinMaxValues(1, 60)
gui.LowerBoundLevelRestrictionSlider:SetValue(3)

gui.AnimaCostLimitLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsAnimaCostLimitLabel", "OVERLAY", "GameFontNormal")
gui.AnimaCostLimitLabel:SetPoint("TOPLEFT", gui.LowerBoundLevelRestrictionSlider, -20, -30)
gui.AnimaCostLimitLabel:SetText(L["AnimaCostLimit"])
gui.AnimaCostLimitLabel:SetWordWrap(true)
gui.AnimaCostLimitLabel:SetWidth(300)

gui.AnimaCostLimitSlider = CreateFrame("Slider", "TLDRMissionsFrameAnimaCostSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.AnimaCostLimitSlider:SetPoint("TOPLEFT", gui.AnimaCostLimitLabel, 20, -10)
gui.AnimaCostLimitSlider:SetSize(280, 20)
TLDRMissionsFrameAnimaCostSliderLow:SetText("10")
TLDRMissionsFrameAnimaCostSliderHigh:SetText("300")
TLDRMissionsFrameAnimaCostSliderText:SetText("300")
TLDRMissionsFrameAnimaCostSliderText:ClearAllPoints()
TLDRMissionsFrameAnimaCostSliderText:SetPoint("TOP", TLDRMissionsFrameAnimaCostSlider, "BOTTOM", 0, 3)
TLDRMissionsFrameAnimaCostSliderText:SetFontObject("GameFontHighlightSmall")
TLDRMissionsFrameAnimaCostSliderText:SetTextColor(0, 1, 0)
gui.AnimaCostLimitSlider:SetOrientation('HORIZONTAL')
gui.AnimaCostLimitSlider:SetValueStep(10)
gui.AnimaCostLimitSlider:SetObeyStepOnDrag(true)
gui.AnimaCostLimitSlider:SetMinMaxValues(10, 300)
gui.AnimaCostLimitSlider:SetValue(300)

gui.SimulationsPerFrameLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsSimulationsPerFrameLabel", "OVERLAY", "GameFontNormal")
gui.SimulationsPerFrameLabel:SetPoint("TOPLEFT", gui.AnimaCostLimitSlider, -20, -30)
gui.SimulationsPerFrameLabel:SetText(L["SimsPerFrameLabel"])
gui.SimulationsPerFrameLabel:SetWidth(300)
gui.SimulationsPerFrameLabel:SetWordWrap(true)

gui.SimulationsPerFrameSlider = CreateFrame("Slider", "TLDRMissionsFrameSimulationsSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.SimulationsPerFrameSlider:SetPoint("TOPLEFT", gui.SimulationsPerFrameLabel, 20, -10)
gui.SimulationsPerFrameSlider:SetSize(280, 20)
TLDRMissionsFrameSimulationsSliderLow:SetText("2")
TLDRMissionsFrameSimulationsSliderHigh:SetText("200")
TLDRMissionsFrameSimulationsSliderText:SetText("10")
TLDRMissionsFrameSimulationsSliderText:ClearAllPoints()
TLDRMissionsFrameSimulationsSliderText:SetPoint("TOP", TLDRMissionsFrameSimulationsSlider, "BOTTOM", 0, 3)
TLDRMissionsFrameSimulationsSliderText:SetFontObject("GameFontHighlightSmall")
TLDRMissionsFrameSimulationsSliderText:SetTextColor(0, 1, 0)
gui.SimulationsPerFrameSlider:SetOrientation("HORIZONTAL")
gui.SimulationsPerFrameSlider:SetValueStep(2)
gui.SimulationsPerFrameSlider:SetObeyStepOnDrag(true)
gui.SimulationsPerFrameSlider:SetMinMaxValues(2, 200)
gui.SimulationsPerFrameSlider:SetValue(10)
gui.SimulationsPerFrameSlider.tooltipText = L["SimsPerFrameTooltip"]

gui.MaxSimulationsEditBox = CreateFrame("EditBox", "TLDRMissionsFrameMaxSimulationsEditBox", gui.AdvancedTabPanel, "InputBoxTemplate")
gui.MaxSimulationsEditBox:SetPoint("TOPLEFT", gui.SimulationsPerFrameSlider, 0, -30)
gui.MaxSimulationsEditBox:SetSize(50, 20)
gui.MaxSimulationsEditBox:SetNumeric(true)
gui.MaxSimulationsEditBox:SetAutoFocus(false)
gui.MaxSimulationsEditBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    addon.db.profile.estimateLimit = tonumber(self:GetText())
    if (not addon.db.profile.estimateLimit) or (addon.db.profile.estimateLimit < 100) then
        addon.db.profile.estimateLimit = 100
    end
end)

gui.MaxSimulationsLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsMaxSimulationsLabel", "OVERLAY", "GameFontNormal")
gui.MaxSimulationsLabel:SetPoint("TOPLEFT", gui.MaxSimulationsEditBox, "TOPRIGHT", 5, -3)
gui.MaxSimulationsLabel:SetText(L["MaxSimulationsLabel"])
gui.MaxSimulationsLabel:SetTextColor(0.8, 0.8, 0.8) 

gui.DurationLabel = gui.AdvancedTabPanel:CreateFontString("TLDRMissionsDurationLabel", "OVERLAY", "GameFontNormal")
gui.DurationLabel:SetPoint("TOPLEFT", gui.MaxSimulationsEditBox, -20, -20)
gui.DurationLabel:SetText(L["DurationLabel"])
gui.DurationLabel:SetWidth(300)
gui.DurationLabel:SetWordWrap(true)

gui.DurationLowerSlider = CreateFrame("Slider", "TLDRMissionsFrameDurationLowerSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.DurationLowerSlider:SetPoint("TOPLEFT", gui.DurationLabel, 20, -10)
gui.DurationLowerSlider:SetSize(280, 20)
TLDRMissionsFrameDurationLowerSliderLow:SetText("1")
TLDRMissionsFrameDurationLowerSliderHigh:SetText("24")
TLDRMissionsFrameDurationLowerSliderText:ClearAllPoints()
TLDRMissionsFrameDurationLowerSliderText:SetPoint("TOP", TLDRMissionsFrameDurationLowerSlider, "BOTTOM", 0, 3)
TLDRMissionsFrameDurationLowerSliderText:SetFontObject("GameFontHighlightSmall")
TLDRMissionsFrameDurationLowerSliderText:SetTextColor(0, 1, 0)
gui.DurationLowerSlider:SetOrientation("HORIZONTAL")
gui.DurationLowerSlider:SetValueStep(1)
gui.DurationLowerSlider:SetObeyStepOnDrag(true)
gui.DurationLowerSlider:SetMinMaxValues(1, 24)
gui.DurationLowerSlider:SetValue(1)

gui.DurationHigherSlider = CreateFrame("Slider", "TLDRMissionsFrameDurationHigherSlider", gui.AdvancedTabPanel, "OptionsSliderTemplate")
gui.DurationHigherSlider:SetPoint("TOPLEFT", gui.DurationLabel, 20, -40)
gui.DurationHigherSlider:SetSize(280, 20)
TLDRMissionsFrameDurationHigherSliderLow:SetText("")
TLDRMissionsFrameDurationHigherSliderHigh:SetText("")
TLDRMissionsFrameDurationHigherSliderText:SetText("")
gui.DurationHigherSlider:SetOrientation("HORIZONTAL")
gui.DurationHigherSlider:SetValueStep(1)
gui.DurationHigherSlider:SetObeyStepOnDrag(true)
gui.DurationHigherSlider:SetMinMaxValues(1, 24)
gui.DurationHigherSlider:SetValue(24)

gui.AutoShowButton = CreateFrame("CheckButton", "TLDRMissionsFrameAutoShowButton", gui.AdvancedTabPanel, "UICheckButtonTemplate")
gui.AutoShowButton:SetPoint("TOPLEFT", gui.DurationHigherSlider, -20, -30)
TLDRMissionsFrameAutoShowButtonText:SetText(L["AutoShowLabel"])

gui.AutoShowButton:HookScript("OnClick", function()
    addon.db.profile.autoShowUI = gui.AutoShowButton:GetChecked()
end)

gui.AllowProcessingAnywhereButton = CreateFrame("CheckButton", "TLDRMissionsFrameAllowProcessingAnywhereButton", gui.AdvancedTabPanel, "UICheckButtonTemplate")
gui.AllowProcessingAnywhereButton:SetPoint("TOPLEFT", gui.AutoShowButton, 0, -25)
TLDRMissionsFrameAllowProcessingAnywhereButtonText:SetText(L["AllowProcessing"])

gui.AllowProcessingAnywhereButton:HookScript("OnClick", function()
    addon.db.profile.allowProcessingAnywhere = gui.AllowProcessingAnywhereButton:GetChecked()
    addon.db.profile.autoStart = false
    gui.AutoStartButton:SetChecked(false)
end)

gui.AllowProcessingAnywhereButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(gui.AllowProcessingAnywhereButton, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["AllowProcessingTooltip"], 1, 1, 1,  0.75, true)
    GameTooltip:Show()
end)
gui.AllowProcessingAnywhereButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

gui.AutoStartButton = CreateFrame("CheckButton", "TLDRMissionsFrameAutoStartButton", gui.AdvancedTabPanel, "UICheckButtonTemplate")
gui.AutoStartButton:SetPoint("TOPLEFT", gui.AllowProcessingAnywhereButton, 0, -25)
TLDRMissionsFrameAutoStartButtonText:SetText(L["AutoStart"])

gui.AutoStartButton:HookScript("OnClick", function()
    addon.db.profile.autoStart = gui.AutoStartButton:GetChecked()
    addon.db.profile.allowProcessingAnywhere = false
    gui.AllowProcessingAnywhereButton:SetChecked(false)
end)

--
-- Tab 3
--

gui.ProfileTabButton = CreateFrame("Button", "TLDRMissionsFrameTab3", gui, "PanelTabButtonTemplate")
gui.ProfileTabButton:SetPoint("TOPLEFT", gui.AdvancedTabButton, "TOPRIGHT", 0, 0)
gui.ProfileTabButton:SetText(L["Profiles"])
gui.ProfileTabButton:SetScript("OnClick", function()
    LibStub("AceConfigDialog-3.0"):Open("TLDRMissions")
end)

--
--
--

PanelTemplates_SetNumTabs(gui, 3)
PanelTemplates_SetTab(gui, 1)