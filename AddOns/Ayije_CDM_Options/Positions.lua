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
    if CDM.UpdateResources then
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

local function CreatePositionControls(parent, anchor, page, cfg)
    local pos = EnsurePosition(cfg.viewerName, cfg.defaults)

    local display = parent:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    display:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)
    display:SetText(string.format(L["Current: %s (%d, %d)"],pos.point, pos.x, pos.y))
    UI.SetTextSuccess(display)

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

    return page.controls[cfg.yKey]
end

local function CreatePositionsTab(page, tabId)
    local content = page

    local essHeader = UI.CreateHeader(content, L["Essential Container Position"])
    essHeader:SetPoint("TOPLEFT", 35, -40)

    local essYSlider = CreatePositionControls(content, essHeader, page, {
        viewerName = C.VIEWERS.ESSENTIAL,
        defaults = { point = "CENTER", x = 0, y = -201 },
        anchorPoint = "TOP",
        reanchor = function() CDM:ReanchorContainer(C.VIEWERS.ESSENTIAL) end,
        xKey = "xPos",
        yKey = "yPos",
        postMove = function()
            if CDM.UpdateUtilityContainerPosition then
                API:UpdateUtilityContainerPosition()
            end
            RefreshAutoWidthLinkedElements()
        end,
    })

    local utilYOffsetSlider = UI.CreateModernSlider(content, L["Utility Y Offset"], -600, 600, CDM.db.utilityYOffset, function(v)
        CDM.db.utilityYOffset = v; API:Refresh("LAYOUT")
    end)
    utilYOffsetSlider:SetPoint("TOPLEFT", essYSlider, "BOTTOMLEFT", 0, -10)

    local buffHeader = UI.CreateHeader(content, L["Main Buff Container Position"])
    buffHeader:SetPoint("TOPLEFT", utilYOffsetSlider, "BOTTOMLEFT", 0, -15)

    local buffAnchorInfo = content:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    buffAnchorInfo:SetText(L["Buffs are currently anchored to resources"] .. "\n" .. L["Resources tab > Global"])
    buffAnchorInfo:SetJustifyH("LEFT")
    buffAnchorInfo:SetPoint("LEFT", buffHeader, "RIGHT", 30, 0)
    UI.SetTextError(buffAnchorInfo)
    buffAnchorInfo:SetShown(CDM.db.moveBuffsDown == true)

    local buffYSlider = CreatePositionControls(content, buffHeader, page, {
        viewerName = C.VIEWERS.BUFF,
        defaults = { point = "CENTER", x = 0, y = -149 },
        anchorPoint = "BOTTOM",
        xKey = "buffXPos",
        yKey = "buffYPos",
        reanchor = function() CDM:UpdateBuffContainerPosition() end,
    })

    local buffBarHeader = UI.CreateHeader(content, L["Buff Bar Container Position"])
    buffBarHeader:SetPoint("TOPLEFT", buffYSlider, "BOTTOMLEFT", 0, -15)

    CreatePositionControls(content, buffBarHeader, page, {
        viewerName = C.VIEWERS.BUFF_BAR,
        defaults = { point = "CENTER", x = 0, y = -324 },
        xKey = "buffBarXPos",
        yKey = "buffBarYPos",
        reanchor = function() CDM:UpdateBuffBarContainerPosition() end,
        getAnchorPoint = function()
            local growDirection = CDM.db.buffBarGrowDirection or "DOWN"
            return growDirection == "DOWN" and "TOP" or "BOTTOM"
        end,
    })

    page:HookScript("OnShow", function()
        buffAnchorInfo:SetShown(CDM.db.moveBuffsDown == true)
    end)
end

API:RegisterConfigTab("positions", L["Positions"], CreatePositionsTab, 3)
