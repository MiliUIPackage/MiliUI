local _, ns = ...

local StyledIcons = {}
ns.StyledIcons = StyledIcons

local isModuleStyledEnabled = false
local areHooksInitialized = false

local BASE_SQUARE_MASK = "Interface\\AddOns\\CooldownManagerCentered\\Media\\Art\\Square"

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BuffIconCooldownViewer = "BuffIcons",
}

local normalizedSizeConfig = {
    Utility = { width = 50, height = 50 },
}

local originalSizesConfig = {
    Essential = { width = 50, height = 50 },
    Utility = { width = 30, height = 30 },
    BuffIcons = { width = 40, height = 40 },
}

local function IsAnyStyledFeatureEnabled()
    if not ns.db or not ns.db.profile then
        return false
    end
    for _, viewerSettingName in pairs(viewersSettingKey) do
        local squareKey = "cooldownManager_squareIcons_" .. viewerSettingName
        if ns.db.profile[squareKey] then
            return true
        end
    end
    if ns.db.profile.cooldownManager_normalizeUtilitySize then
        return true
    end

    return false
end
local function GetViewerIconSize(viewerSettingName)
    if ns.db.profile.cooldownManager_normalizeUtilitySize and viewerSettingName == "Utility" then
        local config = normalizedSizeConfig[viewerSettingName]
        if config then
            return config.width, config.height
        end
    end
    local data = originalSizesConfig[viewerSettingName]
    return data.width, data.height
end

local styleConfig = {
    Essential = {
        paddingFixup = 0,
    },
    Utility = {
        paddingFixup = 0,
    },
    BuffIcons = {
        paddingFixup = 0,
    },
}

local function ApplySquareStyle(button, viewerSettingName)
    local config = styleConfig[viewerSettingName]
    if not config then
        return
    end

    local width = GetViewerIconSize(viewerSettingName)
    local rate = config.rate
    local iconRate = config.iconRate

    local borderKey = "cooldownManager_squareIconsBorder_" .. viewerSettingName
    local borderThickness = ns.db.profile[borderKey]

    button:SetSize(width, width)

    if button.Icon then
        -- local mask = button.Icon:GetMaskTexture(1)
        -- if mask then
        --     button.Icon:RemoveMaskTexture(mask)
        -- end

        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
        button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)

        -- Calculate zoom-based texture coordinates
        local zoom = 0
        if ns.db and ns.db.profile then
            local zoomKey = "cooldownManager_squareIconsZoom_" .. viewerSettingName
            zoom = ns.db.profile[zoomKey] or 0
        end
        local crop = zoom * 0.5
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        end
    end
    for i = 1, select("#", button:GetChildren()) do
        local texture = select(i, button:GetChildren())
        if texture and texture.SetSwipeTexture then
            texture:SetSwipeTexture(BASE_SQUARE_MASK)
            texture:ClearAllPoints()
            texture:SetPoint(
                "TOPLEFT",
                button,
                "TOPLEFT",
                -config.paddingFixup / 2 + borderThickness,
                config.paddingFixup / 2 - borderThickness
            )
            texture:SetPoint(
                "BOTTOMRIGHT",
                button,
                "BOTTOMRIGHT",
                config.paddingFixup / 2 - borderThickness,
                -config.paddingFixup / 2 + borderThickness
            )
        end
    end
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local atlas = region:GetAtlas()

            if (issecretvalue and not issecretvalue(texture) or not issecretvalue) and texture == 6707800 then
                region:SetTexture(BASE_SQUARE_MASK)
                region.__wt_set6707800 = true
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0) -- 6704514
            end
        end
    end
    -- There should be one region left that isn't mapped

    -- Create/update inset black border (overlays icon edges)
    if not button.cmcBorder then
        button.cmcBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.cmcBorder:SetFrameLevel(button:GetFrameLevel() + 1)
    end
    button.cmcBorder:ClearAllPoints()
    button.cmcBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
    button.cmcBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)
    button.cmcBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = borderThickness,
    })
    button.cmcBorder:SetBackdropBorderColor(0, 0, 0, 1)
    button.cmcBorder:Show()

    button.cmcSquareStyled = true
end

local function RestoreOriginalStyle(button, viewerSettingName)
    if not button.cmcSquareStyled then
        return
    end

    local width, height = GetViewerIconSize(viewerSettingName)
    button:SetSize(width, height)

    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0)

        button.Icon:SetSize(width, height)
    end

    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(6707800)
            child:ClearAllPoints()
            child:SetPoint("CENTER", button, "CENTER", 0, 0)
            child:SetSize(width, height)
            break
        end
    end

    -- Restore hidden overlay textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local atlas = region:GetAtlas()

            if region.__wt_set6707800 then
                region:SetTexture(6707800)
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(1) -- 6704514
            end
        end
    end

    if button.cmcBorder then
        button.cmcBorder:Hide()
    end

    button.cmcSquareStyled = false
end

-- Process all children of a viewer
local function ProcessViewer(viewer, viewerSettingName, applyStyle)
    if not viewer then
        return
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then -- Only process icon-like children
            if applyStyle then
                ApplySquareStyle(child, viewerSettingName)
            else
                RestoreOriginalStyle(child, viewerSettingName)
            end
            if child.TriggerPandemicAlert and not child._wt_isStyleHooked then
                child._wt_isStyleHooked = true
                hooksecurefunc(child, "TriggerPandemicAlert", function()
                    if child.PandemicIcon then
                        if applyStyle then
                            child.PandemicIcon:SetScale(1.38) -- magic numbers - TODO fix someday (DebuffBorder/2 +X) where X =0.03
                        else
                            child.PandemicIcon:SetScale(1.0)
                        end
                    end
                    C_Timer.After(0, function()
                        if child.PandemicIcon then
                            if applyStyle then
                                child.PandemicIcon:SetScale(1.38) -- magic numbers - TODO fix someday (DebuffBorder/2 +X) where X =0.03
                            else
                                child.PandemicIcon:SetScale(1.0)
                            end
                        end
                    end)
                end)
            end
            if child.DebuffBorder then
                -- DevTools_Dump(child.DebuffBorder.Texture:GetAtlas()) -- secret and only set AFTER show event
                if applyStyle then
                    child.DebuffBorder:SetScale(1.7) -- magic numbers - TODO fix someday
                else
                    child.DebuffBorder:SetScale(1.0)
                end
            end
        end
    end
end

local function GetSettingKey(viewerSettingName)
    return "cooldownManager_squareIcons_" .. viewerSettingName
end

local function IsSquareIconsEnabled(viewerSettingName)
    if not ns.db or not ns.db.profile then
        return false
    end
    return ns.db.profile[GetSettingKey(viewerSettingName)] or false
end

function StyledIcons:RefreshViewer(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local enabled = IsSquareIconsEnabled(settingName)
    ProcessViewer(viewerFrame, settingName, enabled)
end

function StyledIcons:RefreshAll()
    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local enabled = IsSquareIconsEnabled(settingName)
            ProcessViewer(viewerFrame, settingName, enabled)
        end
    end
end

local function IsNormalizedSizeEnabled()
    return ns.db.profile.cooldownManager_normalizeUtilitySize or false
end

local function ApplyNormalizedSizeToButton(button, viewerSettingName)
    local config = normalizedSizeConfig[viewerSettingName]
    if not config then
        return
    end

    button:SetSize(config.width, config.height)

    for i = 1, select("#", button:GetRegions()) do
        local texture = select(i, button:GetRegions())
        if texture.GetAtlas and texture:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetSize(config.width * 1.36, config.height * 1.36)
        end
    end

    if button.Icon then
        local settingName = viewersSettingKey[viewerName]
        local styleConf = settingName and styleConfig[settingName]
        local padding = button.cmcSquareStyled and (styleConf and styleConf.borderPadding or 4) or 0
        button.Icon:SetSize(config.width - padding, config.height - padding)
    end
end

local function RestoreOriginalSizeToButton(button, viewerSettingName)
    local config = originalSizesConfig[viewerSettingName]

    if not config then
        return
    end

    button:SetSize(config.width, config.height)
    for i = 1, select("#", button:GetRegions()) do
        local texture = select(i, button:GetRegions())
        if texture.GetAtlas and texture:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetSize(config.width * 1.36, config.height * 1.36)
        end
    end

    if button.Icon then
        local padding = button.cmcSquareStyled and 4 or 0
        button.Icon:SetSize(config.width - padding, config.height - padding)
    end
end

function StyledIcons:Shutdown()
    isModuleStyledEnabled = false

    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child.Icon then
                    RestoreOriginalStyle(child, settingName)
                    RestoreOriginalSizeToButton(child, settingName)
                end
            end
        end
    end
end

function StyledIcons:Enable()
    if isModuleStyledEnabled then
        return
    end

    isModuleStyledEnabled = true

    if not areHooksInitialized then
        areHooksInitialized = true

        for viewerName, settingName in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleStyledEnabled then
                        return
                    end

                    StyledIcons:RefreshViewer(viewerName)
                    if viewerName == "UtilityCooldownViewer" then
                        StyledIcons:ApplyNormalizedSize()
                    end
                end)
            end
        end
    end

    self:RefreshAll()
    self:ApplyNormalizedSize()
end

function StyledIcons:Disable()
    if not isModuleStyledEnabled then
        return
    end
    self:Shutdown()
end

function StyledIcons:Initialize()
    if not IsAnyStyledFeatureEnabled() then
        return
    end

    self:Enable()
end

function StyledIcons:OnSettingChanged()
    local shouldBeEnabled = IsAnyStyledFeatureEnabled()

    if shouldBeEnabled and not isModuleStyledEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleStyledEnabled then
        self:Disable()
    elseif isModuleStyledEnabled then
        self:RefreshAll()
        self:ApplyNormalizedSize()
    end

    ns.CooldownManager.ForceRefreshAll()
end

function StyledIcons:ApplyNormalizedSize()
    local viewerFrame = _G["UtilityCooldownViewer"]
    if not viewerFrame then
        return
    end

    local enabled = IsNormalizedSizeEnabled()

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then
            if enabled then
                ApplyNormalizedSizeToButton(child, "Utility")
            else
                RestoreOriginalSizeToButton(child, "Utility")
            end
        end
    end
end
