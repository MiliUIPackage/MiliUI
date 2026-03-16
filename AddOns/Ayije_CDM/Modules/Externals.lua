local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local BORDER = CDM.BORDER
local GetFrameData = CDM.GetFrameData
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local isInitialized = false
local isEnabled = false
local needsStyleUpdate = true

local auraButtons = {}
local container

local TEX_WHITE8X8 = CDM_C.TEX_WHITE8X8
local DEFAULT_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

local function GetSize()
    local s = CDM.Sizes.SIZE_EXTERNALS
    return Snap(s.w), Snap(s.h)
end

local function StyleCDText(text, fontPath, fontSize, fontOutline, color)
    if not text or not text.SetFont then return end
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetFont(fontPath, Pixel.FontSize(fontSize), fontOutline)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(color.r, color.g, color.b)
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function StyleButton(button)
    local fd = GetFrameData(button)
    if not fd then return end

    local styleVersion = CDM.styleCacheVersion or 0
    if not needsStyleUpdate and fd.cdmExternalStyleVersion == styleVersion then
        return
    end

    local w, h = GetSize()
    local cd = fd.cdmExternalCooldown

    local zoomAmount = CDM_C.GetEffectiveZoomAmount()
    CDM_C.ApplyIconTexCoord(button.Icon, zoomAmount, w, h)

    if cd and cd.SetSwipeTexture then
        if zoomAmount > 0 then
            cd:SetSwipeTexture(TEX_WHITE8X8)
        else
            cd:SetSwipeTexture(DEFAULT_SWIPE)
        end
    end

    local sc = CDM.db and CDM.db.swipeColor or CDM_C.SWIPE_COLOR
    if cd and cd.SetSwipeColor then
        cd:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end

    if cd then
        local fontPath = CDM_C.GetBaseFontPath()
        local fontOutline = CDM_C.GetBaseFontOutline()
        local fontSize = CDM.db and CDM.db.externalsCooldownFontSize or 15
        local cooldownColor = CDM.db and CDM.db.cooldownColor or { r = 1, g = 1, b = 1, a = 1 }

        local cdText = cd.Text or cd.text
        StyleCDText(cdText, fontPath, fontSize, fontOutline, cooldownColor)
        for i = 1, cd:GetNumRegions() do
            local region = select(i, cd:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                StyleCDText(region, fontPath, fontSize, fontOutline, cooldownColor)
            end
        end
    end

    local borderActive = CDM.db and CDM.db.borderFile ~= "None"
    if borderActive and BORDER and BORDER.CreateBorder then
        if not fd.cdmExternalBorderFrame then
            fd.cdmExternalBorderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
            fd.cdmExternalBorderFrame:SetAllPoints(button)
        end
        local currentBorderVersion = CDM.borderStyleVersion or 0
        local borderForce = fd.cdmExternalBorderVersion ~= currentBorderVersion
        if not fd.cdmExternalBorderInit or borderForce then
            BORDER:CreateBorder(fd.cdmExternalBorderFrame, { forceUpdate = borderForce })
            fd.cdmExternalBorderInit = true
            fd.cdmExternalBorderVersion = currentBorderVersion
        end
        fd.cdmExternalBorderFrame:Show()
    elseif fd.cdmExternalBorderFrame then
        fd.cdmExternalBorderFrame:Hide()
    end

    fd.cdmExternalStyleVersion = styleVersion
end

local function ApplySizesToButton(button)
    local w, h = GetSize()
    button:SetSize(w, h)
    button.Icon:ClearAllPoints()
    button.Icon:SetAllPoints(button)
    button:SetScale(1)
end

local function ApplySizesAndRelayout()
    if not container then return end

    local layoutInfo = container.currentGridLayoutInfo
    if not layoutInfo then return end

    local w, h = GetSize()
    local spacing = CDM.Sizes.SPACING or 1
    local enabledCount = 0

    for _, button in ipairs(auraButtons) do
        button:SetScale(1)
        button:SetSize(w, h)
        button.Icon:ClearAllPoints()
        button.Icon:SetAllPoints(button)
        if button.hasValidInfo or button.isExample or button.isAuraAnchor then
            enabledCount = enabledCount + 1
        end
    end

    if GridLayoutUtil and GridLayoutUtil.ApplyGridLayout and layoutInfo.anchor then
        local xMult = layoutInfo.addIconsToRight and 1 or -1
        local yMult = layoutInfo.addIconsToTop and 1 or -1
        local layout
        if layoutInfo.isHorizontal then
            layout = GridLayoutUtil.CreateStandardGridLayout(layoutInfo.iconStride, spacing, spacing, xMult, yMult)
        else
            layout = GridLayoutUtil.CreateVerticalGridLayout(layoutInfo.iconStride, spacing, spacing, xMult, yMult)
        end
        GridLayoutUtil.ApplyGridLayout(ExternalDefensivesFrame.auraFrames, layoutInfo.anchor, layout)
    end
end

local function OnButtonUpdate(button, buttonInfo)
    if not isEnabled then return end

    local fd = GetFrameData(button)
    if not fd then return end

    local cd = fd.cdmExternalCooldown
    if cd then
        if buttonInfo and buttonInfo.duration and buttonInfo.duration > 0 and buttonInfo.expirationTime then
            cd:SetCooldown(buttonInfo.expirationTime - buttonInfo.duration, buttonInfo.duration)
        else
            cd:Clear()
        end
    end

    button.Duration:Hide()

    StyleButton(button)
end

local function OnButtonOnUpdate(button)
    if not isEnabled then return end
    button.Duration:Hide()
    if CDM.db and CDM.db.externalsDisableBlink ~= false then
        button:SetAlpha(1)
    end
end

local function OnContainerUpdateGridLayout()
    if not isEnabled then return end
    ApplySizesAndRelayout()
end

local function InitializeExternals()
    if isInitialized then return end
    if not ExternalDefensivesFrame then return end

    container = ExternalDefensivesFrame.AuraContainer
    if not container then return end

    for _, button in ipairs(ExternalDefensivesFrame.auraFrames) do
        if not button.isAuraAnchor then
            local fd = GetFrameData(button)

            local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cd:SetAllPoints(button)
            cd:SetDrawEdge(false)
            cd:SetDrawBling(false)
            cd:SetReverse(true)
            CDM._cdmCooldowns[cd] = true
            fd.cdmExternalCooldown = cd

            hooksecurefunc(button, "Update", function(self, buttonInfo)
                OnButtonUpdate(self, buttonInfo)
            end)

            hooksecurefunc(button, "OnUpdate", function(self)
                OnButtonOnUpdate(self)
            end)

            hooksecurefunc(button.Duration, "SetShown", function(self, show)
                if isEnabled and show then
                    self:Hide()
                end
            end)

            auraButtons[#auraButtons + 1] = button
        end
    end

    hooksecurefunc(container, "UpdateGridLayout", function()
        OnContainerUpdateGridLayout()
    end)

    isInitialized = true
end

local function EnableExternals()
    if not isInitialized then return end
    if isEnabled then return end
    isEnabled = true
    needsStyleUpdate = true

    for _, button in ipairs(auraButtons) do
        ApplySizesToButton(button)
        if button.hasValidInfo then
            button.Duration:Hide()
            StyleButton(button)
            local fd = GetFrameData(button)
            local cd = fd and fd.cdmExternalCooldown
            if cd and button.buttonInfo then
                local bi = button.buttonInfo
                if bi.duration and bi.duration > 0 and bi.expirationTime then
                    cd:SetCooldown(bi.expirationTime - bi.duration, bi.duration)
                end
            end
        end
    end

    needsStyleUpdate = false
    ApplySizesAndRelayout()
end

local function DisableExternals()
    if not isEnabled then return end
    isEnabled = false

    for _, button in ipairs(auraButtons) do
        local fd = GetFrameData(button)

        if fd and fd.cdmExternalCooldown then
            fd.cdmExternalCooldown:Clear()
        end

        if button.Icon then
            button.Icon:SetTexCoord(0, 1, 0, 1)
        end

        if fd and fd.cdmExternalBorderFrame then
            fd.cdmExternalBorderFrame:Hide()
        end

        if button.Duration then
            button.Duration:Show()
        end

        if fd then
            fd.cdmExternalStyleVersion = nil
        end
    end

    if ExternalDefensivesFrame and ExternalDefensivesFrame.UpdateGridLayout then
        ExternalDefensivesFrame:UpdateGridLayout()
    end
end

local function RefreshExternals()
    if not isEnabled then return end
    needsStyleUpdate = true

    for _, button in ipairs(auraButtons) do
        ApplySizesToButton(button)
        if button.hasValidInfo then
            StyleButton(button)
        end
    end

    needsStyleUpdate = false
    ApplySizesAndRelayout()
end

local function OnProfileApplied()
    needsStyleUpdate = true
end

if CDM.ModuleManager and CDM.ModuleManager.RegisterModule then
    CDM.ModuleManager:RegisterModule({
        id = "externals",
        Initialize = function()
            InitializeExternals()
        end,
        Enable = EnableExternals,
        Disable = DisableExternals,
        Refresh = RefreshExternals,
        OnProfileApplied = OnProfileApplied,
        ShouldBeEnabled = function(db)
            return db and db.externalsEnabled ~= false
        end,
    })
end

CDM:RegisterRefreshCallback("externalsStyles", function()
    needsStyleUpdate = true
end, 18, { "text_visuals", "trackers_layout", "viewers" })

CDM:RegisterRefreshCallback("externals", function()
    local moduleManager = CDM.ModuleManager
    if moduleManager and moduleManager.ReconcileModule then
        moduleManager:ReconcileModule("externals")
    end
end, 53, { "trackers_layout", "viewers" })
