local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local C = CDM.CONST
local L = Runtime.L

local Pixel = CDM.Pixel


local function RefreshAutoWidthLinkedElements()
    if CDM.UpdateResources and (CDM.db.resourcesBarWidth or 0) == 0 then
        API:UpdateResources()
    end
    if CDM.UpdatePlayerCastBar and (CDM.db.castBarWidth or 0) == 0 then
        API:UpdatePlayerCastBar()
    end
end

local function EnsurePosition(viewerName, defaults)
    if not CDM.db.editModePositions then
        CDM.db.editModePositions = {}
    end
    if not CDM.db.editModePositions[viewerName] then
        CDM.db.editModePositions[viewerName] = {}
    end
    if not CDM.db.editModePositions[viewerName]["Default"] then
        CDM.db.editModePositions[viewerName]["Default"] = defaults
    end
    return CDM.db.editModePositions[viewerName]["Default"]
end

local function CreateLockSection(parent, anchor, page, fieldName, lockKey, viewerName)
    page[fieldName] = UI.CreateModernCheckbox(
        parent,
        L["Lock Container"],
        CDM.db[lockKey] ~= false,
        function(checked)
            CDM.db[lockKey] = checked
            local container = CDM.anchorContainers and CDM.anchorContainers[viewerName]
            if container then
                container:SetMovable(not checked)
                container:EnableMouse(not checked)
                if container.UpdateHelperText then
                    container.UpdateHelperText()
                end
            end
        end
    )
    page[fieldName]:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)

    local helpText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    helpText:SetPoint("TOPLEFT", page[fieldName], "BOTTOMLEFT", 0, -5)
    helpText:SetText(L["Unlock to drag the container freely.\nUse sliders below for precise positioning."])
    UI.SetTextMuted(helpText)
    helpText:SetJustifyH("LEFT")

    return helpText
end

local function CreatePositionControls(parent, anchor, page, cfg)
    local pos = EnsurePosition(cfg.viewerName, cfg.defaults)

    local display = parent:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    display:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)
    display:SetText(string.format(L["Current: %s (%d, %d)"],pos.point, pos.x, pos.y))
    UI.SetTextSuccess(display)
    if cfg.displayField then
        page[cfg.displayField] = display
    end

    local function UpdateDisplay()
        local p = EnsurePosition(cfg.viewerName, cfg.defaults)
        display:SetText(string.format(L["Current: %s (%d, %d)"],p.point, p.x, p.y))
    end

    local function OnSliderChanged(axis, v)
        local p = EnsurePosition(cfg.viewerName, cfg.defaults)
        p[axis] = v

        local container = CDM.anchorContainers and CDM.anchorContainers[cfg.viewerName]
        if container then
            if cfg.reanchor then
                cfg.reanchor()
            else
                container:ClearAllPoints()
                local anchorPt = cfg.getAnchorPoint and cfg.getAnchorPoint() or cfg.anchorPoint
                Pixel.SetPoint(container, anchorPt, UIParent, p.point, p.x, p.y)
            end
            if cfg.postMove then cfg.postMove() end
        end
        UpdateDisplay()
    end

    page.controls[cfg.xKey] = UI.CreateModernSlider(
        parent, L["X Position"], -2000, 2000, pos.x,
        function(v) OnSliderChanged("x", v) end
    )
    page.controls[cfg.xKey]:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -10)

    page.controls[cfg.yKey] = UI.CreateModernSlider(
        parent, L["Y Position"], -2000, 2000, pos.y,
        function(v) OnSliderChanged("y", v) end
    )
    page.controls[cfg.yKey]:SetPoint("TOPLEFT", page.controls[cfg.xKey], "BOTTOMLEFT", 0, -10)

    return page.controls[cfg.yKey], display, UpdateDisplay
end

local function CreatePositionsTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_PosScrollFrame", 720, 700)

    local essHeader = UI.CreateHeader(scrollChild, L["Essential Container Position"])
    essHeader:SetPoint("TOPLEFT", 0, 0)

    local essYSlider, essDisplay, essUpdateDisplay = CreatePositionControls(scrollChild, essHeader, page, {
        viewerName = "EssentialCooldownViewer",
        defaults = { point = "CENTER", x = 0, y = -201 },
        displayField = "posDisplay",
        anchorPoint = "TOP",
        reanchor = function() CDM:ReanchorContainer("EssentialCooldownViewer") end,
        xKey = "xPos",
        yKey = "yPos",
        postMove = function()
            if CDM.UpdateUtilityContainerPosition then
                API:UpdateUtilityContainerPosition()
            end
            RefreshAutoWidthLinkedElements()
        end,
    })

    local utilYOffsetSlider = UI.CreateModernSlider(scrollChild, L["Utility Y Offset"], -600, 600, CDM.db.utilityYOffset, function(v)
        CDM.db.utilityYOffset = v; API:Refresh()
    end)
    utilYOffsetSlider:SetPoint("TOPLEFT", essYSlider, "BOTTOMLEFT", 0, -10)

    local buffHeader = UI.CreateHeader(scrollChild, L["Main Buff Container Position"])
    buffHeader:SetPoint("TOPLEFT", utilYOffsetSlider, "BOTTOMLEFT", 0, -15)

    local buffYSlider, buffDisplay, buffUpdateDisplay = CreatePositionControls(scrollChild, buffHeader, page, {
        viewerName = "BuffIconCooldownViewer",
        defaults = { point = "CENTER", x = 0, y = -149 },
        displayField = "buffPosDisplay",
        anchorPoint = "BOTTOM",
        xKey = "buffXPos",
        yKey = "buffYPos",
    })

    local buffBarHeader = UI.CreateHeader(scrollChild, L["Buff Bar Container Position"])
    buffBarHeader:SetPoint("TOPLEFT", buffYSlider, "BOTTOMLEFT", 0, -15)

    local buffBarHelpText = CreateLockSection(scrollChild, buffBarHeader, page,
        "buffBarLockCheckbox", "buffBarContainerLocked", "BuffBarCooldownViewer")

    local _, buffBarDisplay, buffBarUpdateDisplay = CreatePositionControls(scrollChild, buffBarHelpText, page, {
        viewerName = "BuffBarCooldownViewer",
        defaults = { point = "CENTER", x = 0, y = -324 },
        displayField = "buffBarPosDisplay",
        xKey = "buffBarXPos",
        yKey = "buffBarYPos",
        reanchor = function() CDM:UpdateBuffBarContainerPosition() end,
        getAnchorPoint = function()
            local growDirection = CDM.db.buffBarGrowDirection or "DOWN"
            return growDirection == "DOWN" and "TOP" or "BOTTOM"
        end,
    })

    local sliderGroups = {
        essential = {
            x = page.controls.xPos,
            y = page.controls.yPos,
            display = essDisplay,
            updateDisplay = essUpdateDisplay,
        },
        buff = {
            x = page.controls.buffXPos,
            y = page.controls.buffYPos,
            display = buffDisplay,
            updateDisplay = buffUpdateDisplay,
        },
        buffBar = {
            x = page.controls.buffBarXPos,
            y = page.controls.buffBarYPos,
            display = buffBarDisplay,
            updateDisplay = buffBarUpdateDisplay,
        },
    }

    local function UpdateSliderControl(control, value)
        if not control then return end
        if control.UpdateUIValue then
            control:UpdateUIValue(value)
        elseif control.Slider then
            control.Slider:SetValue(value)
        end
    end

    local function RegisterSliderUpdater(name)
        API:RegisterPositionSliderUpdater(name, function(x, y)
            local sliderGroup = sliderGroups[name]
            if not sliderGroup then return end
            UpdateSliderControl(sliderGroup.x, x)
            UpdateSliderControl(sliderGroup.y, y)
            if sliderGroup.updateDisplay then
                sliderGroup.updateDisplay()
            end
        end)
    end

    RegisterSliderUpdater("essential")
    RegisterSliderUpdater("buff")
    RegisterSliderUpdater("buffBar")
end

API:RegisterConfigTab("positions", L["Positions"], CreatePositionsTab, 3)
