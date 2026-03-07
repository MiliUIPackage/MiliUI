local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateLayoutTab(page, tabId)
    local layoutHeader = UI.CreateHeader(page, L["Layout Settings"])
    layoutHeader:SetPoint("TOPLEFT", 35, -40)

    page.controls.l1 = UI.CreateModernSlider(page, L["Icon Spacing"], -1, 30, CDM.db.spacing, function(v) CDM.db.spacing = v; API:RefreshConfig() end)
    page.controls.l1:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -15)

    page.controls.l2 = UI.CreateModernSlider(page, L["Max Icons Per Row"], 1, 20, CDM.db.maxRowEss, function(v) CDM.db.maxRowEss = v; API:RefreshConfig() end)
    page.controls.l2:SetPoint("TOPLEFT", page.controls.l1, "BOTTOMLEFT", 0, -10)

    page.controls.l3 = UI.CreateModernSlider(page, L["Utility Y Offset"], -600, 600, CDM.db.utilityYOffset, function(v) CDM.db.utilityYOffset = v; API:RefreshConfig() end)
    page.controls.l3:SetPoint("TOPLEFT", page.controls.l2, "BOTTOMLEFT", 0, -10)

    local utilWrapSlider, unlockCheckbox, xOffsetSlider, verticalCheckbox

    local function UpdateUnlockControls()
        local wrapOn = CDM.db.utilityWrap == true
        local unlockOn = CDM.db.utilityUnlock == true
        utilWrapSlider:SetShown(wrapOn)
        unlockCheckbox:SetShown(wrapOn)
        xOffsetSlider:SetShown(wrapOn and unlockOn)
        verticalCheckbox:SetShown(wrapOn and unlockOn)
    end

    page.controls.utilWrapCheckbox = UI.CreateModernCheckbox(
        page,
        L["Wrap Utility Bar"],
        CDM.db.utilityWrap,
        function(checked)
            CDM.db.utilityWrap = checked
            UpdateUnlockControls()
            API:RefreshConfig()
        end
    )
    page.controls.utilWrapCheckbox:SetPoint("TOPLEFT", page.controls.l3, "BOTTOMLEFT", 0, -10)

    utilWrapSlider = UI.CreateModernSlider(page, L["Utility Max Icons Per Row"], 1, 20, CDM.db.maxRowUtil, function(v) CDM.db.maxRowUtil = v; API:RefreshConfig() end)
    utilWrapSlider:SetPoint("TOPLEFT", page.controls.utilWrapCheckbox, "BOTTOMLEFT", 0, -10)
    page.controls.utilWrapSlider = utilWrapSlider

    unlockCheckbox = UI.CreateModernCheckbox(
        page,
        L["Unlock Utility Bar"],
        CDM.db.utilityUnlock,
        function(checked)
            CDM.db.utilityUnlock = checked
            UpdateUnlockControls()
            API:RefreshConfig()
        end
    )
    unlockCheckbox:SetPoint("TOPLEFT", utilWrapSlider, "BOTTOMLEFT", 0, -10)
    page.controls.unlockCheckbox = unlockCheckbox

    xOffsetSlider = UI.CreateModernSlider(page, L["Utility X Offset"], -600, 600, CDM.db.utilityXOffset, function(v) CDM.db.utilityXOffset = v; API:RefreshConfig() end)
    xOffsetSlider:SetPoint("TOPLEFT", unlockCheckbox, "BOTTOMLEFT", 0, -10)
    page.controls.xOffsetSlider = xOffsetSlider

    verticalCheckbox = UI.CreateModernCheckbox(
        page,
        L["Display Vertical"],
        CDM.db.utilityVertical,
        function(checked)
            CDM.db.utilityVertical = checked
            UpdateUnlockControls()
            API:RefreshConfig()
        end
    )
    verticalCheckbox:SetPoint("TOPLEFT", xOffsetSlider, "BOTTOMLEFT", 0, -10)
    page.controls.verticalCheckbox = verticalCheckbox

    UpdateUnlockControls()
end

API:RegisterConfigTab("layout", L["Layout"], CreateLayoutTab, 2)
