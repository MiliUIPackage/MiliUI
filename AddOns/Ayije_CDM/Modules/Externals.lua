local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local BORDER = CDM.BORDER
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local GetConfigValue = CDM_C.GetConfigValue

local GetAuraDuration = C_UnitAuras.GetAuraDuration
local ShouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret
local ShouldSpellAuraBeSecret = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret

local isInitialized = false
local isEnabled = false
local needsStyleUpdate = true

local auraButtons = {}
local container

local TEX_WHITE8X8 = CDM_C.TEX_WHITE8X8
local DEFAULT_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local DEFAULT_COOLDOWN_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local function GetSize()
    local d = CDM.defaults
    local w = GetConfigValue("externalsIconWidth", d.externalsIconWidth)
    local h = GetConfigValue("externalsIconHeight", d.externalsIconHeight)
    return Snap(w), Snap(h)
end

local function StyleCDText(text, fontPath, fontSize, fontOutline, color)
    if not text or not text.SetFont then return end
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetFont(fontPath, Pixel.FontSize(fontSize), fontOutline)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(color.r, color.g, color.b, color.a or 1)
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function StyleButton(button)
    local styleVersion = CDM.styleCacheVersion or 0
    if not needsStyleUpdate and button.cdmExternalStyleVersion == styleVersion then
        return
    end

    local w, h = GetSize()
    local cd = button.cdmExternalCooldown

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
        local cooldownColor = CDM.db and CDM.db.cooldownColor or DEFAULT_COOLDOWN_COLOR

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
        local currentBorderVersion = CDM.borderStyleVersion or 0
        local borderForce = button.cdmExternalBorderVersion ~= currentBorderVersion
        if not button.cdmExternalBorder or borderForce then
            button.cdmExternalBorder = BORDER:CreateBorder(button, borderForce)
            button.cdmExternalBorderVersion = currentBorderVersion
        end
        if button.cdmExternalBorder then
            BORDER:SetBorderSuppressed(button, false)
            button.cdmExternalBorder:Show()
        end
    elseif button.cdmExternalBorder then
        button.cdmExternalBorder:Hide()
    end

    button.cdmExternalStyleVersion = styleVersion
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
    local spacing = GetConfigValue("spacing", CDM.defaults.spacing) or 1

    for _, button in ipairs(auraButtons) do
        button:SetScale(1)
        button:SetSize(w, h)
        button.Icon:ClearAllPoints()
        button.Icon:SetAllPoints(button)
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

-- fix from MiliUI: 12.1 光環變成秘密值之後，tainted 程式碼拿 auraInstanceID 查光環會被擋下
-- （GetAuraDuration(): Auras cannot be accessed when secret while tainted by 'Ayije_CDM'）。
-- 它是「拋錯」不是回 nil，所以要先閘一次，再包 pcall 當保險。
local function CanQueryAura(buttonInfo)
    if not ShouldAurasBeSecret or not ShouldAurasBeSecret() then return true end
    -- 光環為秘密時，只有被標成 never-secret 的法術還查得到
    local spellID = buttonInfo.spellID
    if spellID and ShouldSpellAuraBeSecret and not ShouldSpellAuraBeSecret(spellID) then
        return true
    end
    return false
end

-- 回傳「有沒有成功驅動我們自己的冷卻轉盤」
local function SetCooldownFromButtonInfo(button, buttonInfo)
    local cd = button.cdmExternalCooldown
    if not cd then return false end

    if buttonInfo and buttonInfo.auraInstanceID and CanQueryAura(buttonInfo) then
        local ok, dur = pcall(GetAuraDuration, "player", buttonInfo.auraInstanceID)
        if ok and dur then
            cd:SetCooldownFromDurationObject(dur)
            return true
        end
    end

    cd:Clear()
    return false
end

-- fix from MiliUI: 自己的轉盤畫不出來時（光環為秘密值），把暴雪原本的倒數文字放回來，
-- 否則戰鬥中的外部減傷會完全沒有時間資訊
local function UpdateDurationVisibility(button, hasCooldown, buttonInfo)
    -- auraInstanceID 可能本身就是秘密值，只能做布林測試，不能拿去比較
    local hasAura = (buttonInfo and buttonInfo.auraInstanceID) and true or false
    button.cdmExternalDurationFallback = (not hasCooldown) and hasAura
    if button.cdmExternalDurationFallback then
        button.Duration:Show()
    else
        button.Duration:Hide()
    end
end

local function OnButtonUpdate(button, buttonInfo)
    if not isEnabled then return end

    local hasCooldown = SetCooldownFromButtonInfo(button, buttonInfo)

    UpdateDurationVisibility(button, hasCooldown, buttonInfo)

    StyleButton(button)
end

local function OnButtonOnUpdate(button)
    if not isEnabled then return end
    if CDM.db and CDM.db.externalsDisableBlink ~= false then
        if button:GetAlpha() ~= 1 then
            button:SetAlpha(1)
        end
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
            local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cd:SetAllPoints(button)
            cd:SetDrawEdge(false)
            cd:SetDrawBling(false)
            cd:SetReverse(true)
            CDM.cdmCooldowns[cd] = true
            button.cdmExternalCooldown = cd

            hooksecurefunc(button, "Update", function(self, buttonInfo)
                OnButtonUpdate(self, buttonInfo)
            end)

            button:HookScript("OnUpdate", function(self)
                OnButtonOnUpdate(self)
            end)

            hooksecurefunc(button.Duration, "SetShown", function(self, show)
                -- fix from MiliUI: 秘密光環的退路是讓暴雪的倒數文字留著，這時別再把它藏起來
                if isEnabled and show and not button.cdmExternalDurationFallback then
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
            StyleButton(button)
            local hasCooldown = SetCooldownFromButtonInfo(button, button.buttonInfo)
            UpdateDurationVisibility(button, hasCooldown, button.buttonInfo)
        end
    end

    needsStyleUpdate = false
    ApplySizesAndRelayout()
end

local function DisableExternals()
    if not isEnabled then return end
    isEnabled = false

    for _, button in ipairs(auraButtons) do
        if button.cdmExternalCooldown then
            button.cdmExternalCooldown:Clear()
        end

        if button.Icon then
            button.Icon:SetTexCoord(0, 1, 0, 1)
        end

        if button.cdmExternalBorder then
            BORDER:SetBorderSuppressed(button, true)
        end

        button.cdmExternalDurationFallback = nil
        if button.Duration then
            button.Duration:Show()
        end

        button.cdmExternalStyleVersion = nil
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

local function ReconcileExternals()
    if CDM.db and CDM.db.externalsEnabled ~= false then
        if not isInitialized then InitializeExternals() end
        if not isEnabled then EnableExternals() end
        RefreshExternals()
    elseif isEnabled then
        DisableExternals()
    end
end

CDM.ReconcileExternals = ReconcileExternals

local function OnExternalsProfileApplied()
    needsStyleUpdate = true
end
CDM.OnExternalsProfileApplied = OnExternalsProfileApplied

CDM:RegisterRefreshCallback("externalsStyles", function()
    needsStyleUpdate = true
end, 18, { "TRACKERS", "STYLE" })
