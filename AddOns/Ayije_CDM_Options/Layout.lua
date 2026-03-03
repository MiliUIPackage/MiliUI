-- Config/TabLayout.lua - Layout Settings Tab
-- Controls for spacing, max icons per row, and buff layout modes

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateLayoutTab(page, tabId)
    -- Layout Settings Header
    local layoutHeader = UI.CreateHeader(page, L["Layout Settings"])
    layoutHeader:SetPoint("TOPLEFT", 35, -40)

    -- Spacing and row controls
    page.controls.l1 = UI.CreateModernSlider(page, L["Icon Spacing"], -1, 30, CDM.db.spacing, function(v) CDM.db.spacing = v; API:RefreshConfig() end)
    page.controls.l1:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -15)

    page.controls.l2 = UI.CreateModernSlider(page, L["Max Icons Per Row"], 1, 20, CDM.db.maxRowEss, function(v) CDM.db.maxRowEss = v; API:RefreshConfig() end)
    page.controls.l2:SetPoint("TOPLEFT", page.controls.l1, "BOTTOMLEFT", 0, -10)

    page.controls.l3 = UI.CreateModernSlider(page, L["Utility Y Offset"], -600, 600, CDM.db.utilityYOffset, function(v) CDM.db.utilityYOffset = v; API:RefreshConfig() end)
    page.controls.l3:SetPoint("TOPLEFT", page.controls.l2, "BOTTOMLEFT", 0, -10)

    -- Utility Wrap checkbox
    local utilWrapSlider, unlockCheckbox, xOffsetSlider, verticalCheckbox, buffHeader

    -- Helper: find the bottom-most visible widget and re-anchor buffHeader
    local function UpdateBuffHeaderAnchor()
        local anchor = page.controls.utilWrapCheckbox
        if CDM.db.utilityWrap then
            if CDM.db.utilityUnlock then
                -- verticalCheckbox is always the bottom-most unlock sub-control
                anchor = verticalCheckbox
            else
                -- unlockCheckbox is the last visible control when unlock is off
                anchor = unlockCheckbox
            end
        end
        buffHeader:ClearAllPoints()
        buffHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)
    end

    -- Helper: show/hide the unlock sub-controls based on current state
    local function UpdateUnlockControls()
        local wrapOn = CDM.db.utilityWrap == true
        local unlockOn = CDM.db.utilityUnlock == true
        utilWrapSlider:SetShown(wrapOn)
        unlockCheckbox:SetShown(wrapOn)
        xOffsetSlider:SetShown(wrapOn and unlockOn)
        verticalCheckbox:SetShown(wrapOn and unlockOn)
        UpdateBuffHeaderAnchor()
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

    -- Utility Max Icons Per Row slider
    utilWrapSlider = UI.CreateModernSlider(page, L["Utility Max Icons Per Row"], 1, 20, CDM.db.maxRowUtil, function(v) CDM.db.maxRowUtil = v; API:RefreshConfig() end)
    utilWrapSlider:SetPoint("TOPLEFT", page.controls.utilWrapCheckbox, "BOTTOMLEFT", 0, -10)
    page.controls.utilWrapSlider = utilWrapSlider

    -- Unlock utility bar checkbox (shown when wrap=true)
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

    -- X Offset slider (shown when unlock=true, shifts whole utility viewer)
    xOffsetSlider = UI.CreateModernSlider(page, L["Utility X Offset"], -600, 600, CDM.db.utilityXOffset, function(v) CDM.db.utilityXOffset = v; API:RefreshConfig() end)
    xOffsetSlider:SetPoint("TOPLEFT", unlockCheckbox, "BOTTOMLEFT", 0, -10)
    page.controls.xOffsetSlider = xOffsetSlider

    -- Display Vertical checkbox (shown when unlock=true)
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

    -- Buff Layout Header (created before UpdateUnlockControls so anchor logic can position it)
    buffHeader = UI.CreateHeader(page, L["Buff Layout"])

    -- Initial visibility + anchor
    UpdateUnlockControls()

    -- Secondary Buff Layout Mode
    page.secBuffLayoutCheckbox = UI.CreateModernCheckbox(
        page,
        L["Secondary Buffs Grow Horizontally (Centered)"],
        CDM.db.buffSecondaryHorizontal,
        function(checked)
            CDM.db.buffSecondaryHorizontal = checked
            API:RefreshConfig()
        end
    )
    page.secBuffLayoutCheckbox:SetPoint("TOPLEFT", buffHeader, "BOTTOMLEFT", 0, -15)

    -- Tertiary Buff Layout Mode
    page.tertBuffLayoutCheckbox = UI.CreateModernCheckbox(
        page,
        L["Tertiary Buffs Grow Horizontally (Centered)"],
        CDM.db.buffTertiaryHorizontal,
        function(checked)
            CDM.db.buffTertiaryHorizontal = checked
            API:RefreshConfig()
        end
    )
    page.tertBuffLayoutCheckbox:SetPoint("TOPLEFT", page.secBuffLayoutCheckbox, "BOTTOMLEFT", 0, -10)
end

-- Register this tab
API:RegisterConfigTab("layout", L["Layout"], CreateLayoutTab, 2)
