local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateLayoutTab(page, tabId)
    local tabBar = UI.CreateSubTabBar(page, {
        { id = "cooldowns", label = L["Cooldowns"] },
        { id = "general", label = L["General"] },
        { id = "externals", label = L["Externals"] },
    }, "cooldowns")

    local subPages = tabBar.subPages

    if ns._CreateCooldownGroupsPanel then
        ns._CreateCooldownGroupsPanel(subPages.cooldowns, page)
    end

    local generalPage = subPages.general

    local divider = generalPage:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", generalPage, "TOP", 0, 0)

    local content, scrollFrame = UI.CreateScrollableTab(generalPage, "AyijeCDM_LayoutGeneralScrollFrame", 520)
    local scrollChild = scrollFrame:GetScrollChild()

    local swipeHeader = UI.CreateHeader(content, L["Cooldown Swipe"])
    swipeHeader:SetPoint("TOPLEFT", 0, 0)

    generalPage.hideGCDSwipeCheckbox = UI.CreateModernCheckbox(
        content,
        L["Hide GCD Swipe"],
        CDM.db.hideGCDSwipe,
        function(checked)
            CDM.db.hideGCDSwipe = checked
            API:Refresh("STYLE")
        end
    )
    generalPage.hideGCDSwipeCheckbox:SetPoint("TOPLEFT", swipeHeader, "BOTTOMLEFT", 0, -15)

    local swipeColorLabel = content:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    swipeColorLabel:SetText(L["Swipe Color"])
    swipeColorLabel:SetPoint("TOPLEFT", generalPage.hideGCDSwipeCheckbox, "BOTTOMLEFT", 0, -14)

    local swipeInit = CDM.db.swipeColor or { r = 0, g = 0, b = 0, a = 0.6 }
    local swipeColorPicker = UI.CreateSimpleColorPicker(content, swipeInit, function(r, g, b)
        CDM.db.swipeColor = { r = r, g = g, b = b, a = CDM.db.swipeColor and CDM.db.swipeColor.a or 0.6 }
        API:Refresh("STYLE")
    end)
    swipeColorPicker:SetPoint("LEFT", swipeColorLabel, "RIGHT", 6, 0)

    local swipeAlphaSlider = UI.CreateModernSlider(content, L["Swipe Opacity"], 0, 100,
        math.floor((swipeInit.a or 0.6) * 100),
        function(v)
            local sc = CDM.db.swipeColor or { r = 0, g = 0, b = 0, a = 0.6 }
            CDM.db.swipeColor = { r = sc.r, g = sc.g, b = sc.b, a = v / 100 }
            API:Refresh("STYLE")
        end)
    swipeAlphaSlider:SetPoint("TOPLEFT", swipeColorLabel, "BOTTOMLEFT", 0, -10)

    local layoutHeader = UI.CreateHeader(content, L["Layout Settings"])
    layoutHeader:SetPoint("TOPLEFT", swipeAlphaSlider, "BOTTOMLEFT", 0, -20)

    generalPage.controls.l1 = UI.CreateModernSlider(content, L["Icon Spacing"], -1, 30, CDM.db.spacing, function(v) CDM.db.spacing = v; API:Refresh("LAYOUT") end)
    generalPage.controls.l1:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -15)

    local essHeader = UI.CreateHeader(content, L["Essential"])
    essHeader:SetPoint("TOPLEFT", generalPage.controls.l1, "BOTTOMLEFT", 0, -20)

    local maxRowEssSlider = UI.CreateModernSlider(content, L["Max Icons Per Row"], 1, 20, CDM.db.maxRowEss, function(v)
        CDM.db.maxRowEss = v; API:Refresh("LAYOUT")
    end)
    maxRowEssSlider:SetPoint("TOPLEFT", essHeader, "BOTTOMLEFT", 0, -15)

    local utilHeader = UI.CreateHeader(content, L["Utility"])
    utilHeader:SetPoint("TOPLEFT", maxRowEssSlider, "BOTTOMLEFT", 0, -20)

    local wrapCheckbox, utilWrapSlider, unlockCheckbox, xOffsetSlider, verticalCheckbox

    local function UpdateScrollHeight()
        C_Timer.After(0, function()
            local top = swipeHeader:GetTop()
            local lastWidget = wrapCheckbox
            if CDM.db.utilityWrap then
                lastWidget = unlockCheckbox
                if CDM.db.utilityUnlock then lastWidget = verticalCheckbox end
            end
            local bottom = lastWidget:GetBottom()
            if top and bottom then
                local h = top - bottom + 40
                scrollChild:SetHeight(h)
                content:SetHeight(h)
            end
        end)
    end

    local function UpdateUnlockControls()
        local wrapOn = CDM.db.utilityWrap == true
        local unlockOn = CDM.db.utilityUnlock == true
        utilWrapSlider:SetShown(wrapOn)
        unlockCheckbox:SetShown(wrapOn)
        xOffsetSlider:SetShown(wrapOn and unlockOn)
        verticalCheckbox:SetShown(wrapOn and unlockOn)
        UpdateScrollHeight()
    end

    wrapCheckbox = UI.CreateModernCheckbox(
        content,
        L["Wrap Utility Bar"],
        CDM.db.utilityWrap,
        function(checked)
            CDM.db.utilityWrap = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    wrapCheckbox:SetPoint("TOPLEFT", utilHeader, "BOTTOMLEFT", 0, -15)

    utilWrapSlider = UI.CreateModernSlider(content, L["Utility Max Icons Per Row"], 1, 20, CDM.db.maxRowUtil, function(v)
        CDM.db.maxRowUtil = v; API:Refresh("LAYOUT")
    end)
    utilWrapSlider:SetPoint("TOPLEFT", wrapCheckbox, "BOTTOMLEFT", 0, -10)

    unlockCheckbox = UI.CreateModernCheckbox(
        content,
        L["Unlock Utility Bar"],
        CDM.db.utilityUnlock,
        function(checked)
            CDM.db.utilityUnlock = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    unlockCheckbox:SetPoint("TOPLEFT", utilWrapSlider, "BOTTOMLEFT", 0, -10)

    xOffsetSlider = UI.CreateModernSlider(content, L["Utility X Offset"], -600, 600, CDM.db.utilityXOffset, function(v)
        CDM.db.utilityXOffset = v; API:Refresh("LAYOUT")
    end)
    xOffsetSlider:SetPoint("TOPLEFT", unlockCheckbox, "BOTTOMLEFT", 0, -10)

    verticalCheckbox = UI.CreateModernCheckbox(
        content,
        L["Display Vertical"],
        CDM.db.utilityVertical,
        function(checked)
            CDM.db.utilityVertical = checked
            UpdateUnlockControls()
            API:Refresh("LAYOUT")
        end
    )
    verticalCheckbox:SetPoint("TOPLEFT", xOffsetSlider, "BOTTOMLEFT", 0, -10)

    UpdateUnlockControls()
    generalPage:HookScript("OnShow", UpdateScrollHeight)

    if ns._CreateExternalsPanel then
        ns._CreateExternalsPanel(subPages.externals, page)
    end
end

API:RegisterConfigTab("layout", L["Layout"], CreateLayoutTab, 2)
