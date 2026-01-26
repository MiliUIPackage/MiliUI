local _, ns = ...

local EditModeHelp = {}
ns.EditModeHelp = EditModeHelp

local pointMap = {
    ["TOPLEFT"] = "TOP",
    ["TOP"] = "TOP",
    ["TOPRIGHT"] = "TOP",
    ["LEFT"] = "CENTER",
    ["CENTER"] = "CENTER",
    ["RIGHT"] = "CENTER",
    ["BOTTOMLEFT"] = "BOTTOM",
    ["BOTTOM"] = "BOTTOM",
    ["BOTTOMRIGHT"] = "BOTTOM",
}
local viewers = {
    {
        frame = BuffIconCooldownViewer,
        viewerName = "BuffIconCooldownViewer",
        growthFrom = "cooldownManager_alignBuffIcons_growFromDirection",
    },
    {
        frame = EssentialCooldownViewer,
        viewerName = "EssentialCooldownViewer",
        growthFrom = "cooldownManager_centerEssential_growFromDirection",
    },
    {
        frame = UtilityCooldownViewer,
        viewerName = "UtilityCooldownViewer",
        growthFrom = "cooldownManager_centerUtility_growFromDirection",
    },
}

local function GetPointAndOffset(frame, growFromDirection)
    if not frame.isHorizontal then
        return nil
    end
    local point, relativeTo = frame:GetPoint(1)

    if relativeTo ~= UIParent then
        return nil
    end

    local y = nil
    point = nil

    if growFromDirection == "BOTTOM" then
        point = "BOTTOM"
    else
        point = "TOP"
    end
    if point == "BOTTOM" then
        y = frame:GetBottom()
    else
        y = frame:GetTop()
    end

    local x = frame:GetCenter()
    pX = UIParent:GetCenter()
    return { point = point, x = x - pX, y = y }
end
local helpText = nil
local function GetHelpText()
    local text = "To edit |cff008945Cool|r|cff1e9a4e|r|cff3faa4fdown Ma|r|cff5fb64anag|r|cff7ac243er|r"
    if not EditModeManagerFrame:GetAccountSettingValueBool(Enum.EditModeAccountSetting.SettingsExpanded) then
        text = text .. '\nclick "Expand options", and'
    end
    text = text .. '\nenable "Cooldown Manager" above'
    return text
end
local function CreateHelpText()
    if not EditModeManagerFrame then
        return
    end
    if helpText then
        if not EditModeManagerFrame:GetAccountSettingValueBool(Enum.EditModeAccountSetting.ShowCooldownViewer) then
            helpText.text:SetText(GetHelpText())
        else
            helpText.text:SetText("")
        end
        return
    end
    helpText = CreateFrame("Frame", nil, EditModeManagerFrame)
    helpText:SetSize(400, 50)
    helpText:SetPoint("TOP", EditModeManagerFrame, "BOTTOM", 0, 20)
    helpText.text = helpText:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeOutline")
    helpText.text:ClearAllPoints()
    helpText.text:SetAllPoints()
    helpText.text:SetText("")
    if not EditModeManagerFrame:GetAccountSettingValueBool(Enum.EditModeAccountSetting.ShowCooldownViewer) then
        helpText.text:SetText(GetHelpText())
    end
end

local arrowsForViewers = {
    ["BuffIconCooldownViewer"] = {
        top = {
            frame = CreateFrame("Frame"),
            anchor = "BOTTOM",
        },
        left = {
            frame = CreateFrame("Frame"),
            anchor = "RIGHT",
        },
        right = {
            frame = CreateFrame("Frame"),
            anchor = "LEFT",
        },
        bottom = {
            frame = CreateFrame("Frame"),
            anchor = "TOP",
        },
    },
    ["EssentialCooldownViewer"] = {
        top = {
            frame = CreateFrame("Frame"),
            anchor = "BOTTOM",
        },
        left = {
            frame = CreateFrame("Frame"),
            anchor = "RIGHT",
        },
        right = {
            frame = CreateFrame("Frame"),
            anchor = "LEFT",
        },
        bottom = {
            frame = CreateFrame("Frame"),
            anchor = "TOP",
        },
    },
    ["UtilityCooldownViewer"] = {
        top = {
            frame = CreateFrame("Frame"),
            anchor = "BOTTOM",
        },
        left = {
            frame = CreateFrame("Frame"),
            anchor = "RIGHT",
        },
        right = {
            frame = CreateFrame("Frame"),
            anchor = "LEFT",
        },
        bottom = {
            frame = CreateFrame("Frame"),
            anchor = "TOP",
        },
    },
}
for _, viewerInfo in ipairs(viewers) do
    local viewerName = viewerInfo.frame:GetName()
    local arrowFrames = arrowsForViewers[viewerName]
    for name, info in pairs(arrowFrames) do
        local frame = info.frame
        frame:SetParent(viewerInfo.frame)
    end
end
for _, viewerInfo in ipairs(viewers) do
    local viewerName = viewerInfo.frame:GetName()
    local arrowFrames = arrowsForViewers[viewerName]
    for name, info in pairs(arrowFrames) do
        local frame = info.frame
        frame:SetSize(10, 14)
        frame.background = frame:CreateTexture(nil, "BACKGROUND")
        frame.background:ClearAllPoints()
        frame.background:SetAllPoints()
        frame.background:SetAtlas("bags-greenarrow", false)
        frame.background:SetRotation(
            name == "left" and math.pi / 2 or (name == "right" and -math.pi / 2 or (name == "bottom" and math.pi or 0))
        )
        frame:SetFrameStrata("HIGH")
        frame:Hide()
    end
end

local function UpdateFrameArrowsAnchors(forceHide)
    for _, viewerInfo in ipairs(viewers) do
        local point, relativeTo, relativePoint, offsetX, offsetY = select(1, viewerInfo.frame:GetPoint(1))

        local viewerName = viewerInfo.frame:GetName()
        local arrowFrames = arrowsForViewers[viewerName]
        for name, info in pairs(arrowFrames) do
            info.frame:SetPoint(info.anchor, viewerInfo.frame, point, 0, 0)
            local pointLower = string.lower(point)
            if forceHide or not ns.Runtime.isInEditMode or pointLower:find(name) or viewerInfo.frame.isDragging then
                info.frame:Hide()
            else
                info.frame:Show()
                info.frame:SetFrameStrata("HIGH")
            end
        end
    end
end

local function UpdateViewerAnchor(frame, viewerInfo)
    if
        not frame.IsInitialized
        or not frame:IsInitialized()
        or frame.layoutApplyInProgress
        or not frame:CanBeMoved()
    then
        return
    end
    if viewerInfo.viewerName == "BuffIconCooldownViewer" and not ns.db.profile[viewerInfo.growthFrom] == "CENTER" then
        return
    end
    if ns.db.profile[viewerInfo.growthFrom] == "Disable" then
        return
    end
    if ns.Runtime.isInEditMode and EditModeManagerFrame:IsShown() then
        local data = GetPointAndOffset(frame, ns.db.profile[viewerInfo.growthFrom])
        if not data then
            return
        end
        local currentPoint, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint()
        if currentPoint ~= data.point or math.floor(data.x - offsetX) > 0 or math.floor(data.y - offsetY) > 0 then
            frame:ClearAllPoints()
            frame:SetPoint(data.point, UIParent, "BOTTOM", data.x, data.y)
            EditModeManagerFrame:OnSystemPositionChange(frame)
        end

        UpdateFrameArrowsAnchors()
    end
end

for _, viewerInfo in ipairs(viewers) do
    local frame = viewerInfo.frame
    hooksecurefunc(frame, "SetPoint", function()
        if
            not frame.IsInitialized
            or not frame:IsInitialized()
            or frame.layoutApplyInProgress
            or not frame:CanBeMoved()
        then
            return
        end
        C_Timer.After(0, function()
            UpdateViewerAnchor(frame, viewerInfo)
        end)
    end)
end

local ticker = nil
EventRegistry:RegisterCallback("EditMode.Enter", function()
    CreateHelpText()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    C_Timer.After(0, function()
        UpdateFrameArrowsAnchors()
    end)
    ticker = C_Timer.NewTicker(0.5, function()
        CreateHelpText()
        UpdateFrameArrowsAnchors()
    end)
end)

EventRegistry:RegisterCallback("EditMode.Exit", function()
    C_Timer.After(0, function()
        UpdateFrameArrowsAnchors()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end)
end)
