do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local ADDON_NAME, YUI = ...
YUI = YUI or _G.YUI

if not YUI then
    return
end

local MinimapIcon = YUI.MinimapIcon or {}
YUI.MinimapIcon = MinimapIcon

MinimapIcon.products = MinimapIcon.products or {}
MinimapIcon.buttons = MinimapIcon.buttons or {}
MinimapIcon.compartmentRegistered = MinimapIcon.compartmentRegistered or {}

local DB_KEY = "YUI_MinimapIcon"
local DEFAULT_ANGLE = 225
local MINIMAP_RADIUS = 80
local BUTTON_SIZE = 32
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Gear_01"

local Locale = YUI.Locale and YUI.Locale.Get and YUI.Locale:Get("Core") or {}

local function T(key, fallback)
    local value = Locale and Locale[key]
    if value and value ~= "" then
        return value
    end
    return fallback or key
end

local function GetProductId(productOrId)
    if type(productOrId) == "table" then
        return productOrId.id
    end
    return productOrId
end

local function GetProduct(productOrId)
    if type(productOrId) == "table" then
        return productOrId
    end
    return MinimapIcon.products[productOrId] or (YUI.Products and YUI.Products[productOrId])
end

local function ProductHasSettings(product)
    return product
        and product.settings
        and product.settings.enabled == true
end

local function ShouldRegisterProduct(product)
    if not ProductHasSettings(product) or product.settings.minimapIcon ~= true then
        return false
    end

    if product.settings.mode == "suite" or YUI.CoreMode == "suite" then
        return false
    end

    if product.id and YUI.BlockedProducts and YUI.BlockedProducts[product.id] then
        return false
    end

    return true
end

local function GetProductTitle(product)
    if YUI.GetProductShortTitle then
        return YUI:GetProductShortTitle(product)
    end

    return (product and (product.shortTitle or product.title or product.id)) or "YUI"
end

local function GetProductIcon(product)
    if product and product.logo then
        local logo = product.logo
        if logo:find("^Interface\\") or logo:find("^Interface/") then
            return logo
        end

        if YUI.Assets and YUI.Assets.Product then
            local resolved = YUI.Assets:Product(product.id, logo)
            if resolved and resolved ~= "" then
                return resolved
            end
        end
    end

    if YUI.Assets and YUI.Assets.Core then
        local resolved = YUI.Assets:Core("Icons\\logo_256.png")
        if resolved and resolved ~= "" then
            return resolved
        end
    end

    return DEFAULT_ICON
end

local function GetProfile(productId)
    if not (YUI.DB and YUI.DB.GetProfile) then
        return nil
    end

    return YUI.DB:GetProfile(productId)
end

local function GetDefaultAngle(productId)
    local text = tostring(productId or "")
    local hash = 0
    for i = 1, #text do
        hash = (hash + (string.byte(text, i) or 0) * i) % 72
    end
    return (DEFAULT_ANGLE + hash * 5) % 360
end

local function GetConfig(productId)
    local profile = GetProfile(productId)
    if not profile then
        return nil
    end

    local cfg = profile[DB_KEY]
    if type(cfg) ~= "table" then
        cfg = {}
        profile[DB_KEY] = cfg
    end

    if cfg.hidden == nil then
        cfg.hidden = false
    end

    if type(cfg.angle) ~= "number" then
        cfg.angle = GetDefaultAngle(productId)
    end

    return cfg
end

local function NormalizeAngle(angle)
    if type(angle) ~= "number" then
        angle = DEFAULT_ANGLE
    end

    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end

    return angle
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function PositionButton(button, angle)
    if not button or not Minimap then
        return
    end

    local radians = math.rad(NormalizeAngle(angle))
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function SaveDragPosition(button)
    if not (button and button.productId and Minimap and GetCursorPosition) then
        return
    end

    local cfg = GetConfig(button.productId)
    if not cfg then
        return
    end

    local scale = Minimap:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not (cursorX and cursorY and centerX and centerY) then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    cfg.angle = NormalizeAngle(math.deg(Atan2(cursorY - centerY, cursorX - centerX)))
    PositionButton(button, cfg.angle)
end

local function OpenProductSettings(product)
    if not product then
        return
    end

    local entry = product.settings and product.settings.entry
    if YUI.Settings and YUI.Settings.OpenProduct then
        YUI.Settings:OpenProduct(product.id, entry)
    elseif YUI.OpenSettings then
        YUI:OpenSettings(entry)
    end
end

local function ShowButtonTooltip(button)
    if not (button and GameTooltip) then
        return
    end

    local product = GetProduct(button.productId)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(GetProductTitle(product))
    GameTooltip:AddLine(T("minimap_icon.tooltip.left_click", "Left-click to open settings."), 1, 1, 1)
    GameTooltip:AddLine(T("minimap_icon.tooltip.drag", "Drag to move this button."), 0.75, 0.75, 0.75)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then
        YUI.HideGameTooltip()
    end
end

local function OnButtonClick(button, mouseButton)
    if button._yuiSuppressClick then
        button._yuiSuppressClick = nil
        return
    end

    if mouseButton == "RightButton" then
        MinimapIcon:ResetPosition(button.productId)
        return
    end

    OpenProductSettings(GetProduct(button.productId))
end

local function OnDragUpdate(button)
    SaveDragPosition(button)
end

local function CreateButton(product)
    if not (product and product.id and Minimap and CreateFrame) then
        return nil
    end

    local name = "YUI_MinimapIcon_" .. tostring(product.id):gsub("[^%w_]", "_")
    local button = CreateFrame("Button", name, Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetMovable(false)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button.productId = product.id

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)

    button:SetScript("OnClick", OnButtonClick)
    button:SetScript("OnEnter", ShowButtonTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        SaveDragPosition(self)
        self._yuiSuppressClick = true
        if C_Timer and C_Timer.After then
            local target = self
            C_Timer.After(0.15, function()
                if target then
                    target._yuiSuppressClick = nil
                end
            end)
        end
    end)

    MinimapIcon.buttons[product.id] = button
    return button
end

function MinimapIcon:GetProduct(productId)
    return GetProduct(productId)
end

function MinimapIcon:GetConfig(productId)
    productId = GetProductId(productId)
    if not productId then
        return nil
    end

    return GetConfig(productId)
end

function MinimapIcon:IsShown(productId)
    productId = GetProductId(productId)
    local cfg = productId and GetConfig(productId)
    if not cfg then
        return false
    end

    return cfg.hidden ~= true
end

function MinimapIcon:SetShown(productId, shown)
    productId = GetProductId(productId)
    if not productId then
        return
    end

    local cfg = GetConfig(productId)
    if not cfg then
        return
    end

    cfg.hidden = not shown
    self:Refresh(productId)
end

function MinimapIcon:ResetPosition(productId)
    productId = GetProductId(productId)
    if not productId then
        return
    end

    local cfg = GetConfig(productId)
    if not cfg then
        return
    end

    cfg.angle = GetDefaultAngle(productId)
    self:Refresh(productId)
end

function MinimapIcon:Refresh(productId)
    productId = GetProductId(productId)
    local product = productId and GetProduct(productId)
    if not ShouldRegisterProduct(product) then
        local button = productId and self.buttons[productId]
        if button then
            button:Hide()
        end
        return
    end

    local cfg = GetConfig(productId)
    if not cfg then
        return
    end

    local button = self.buttons[productId] or CreateButton(product)
    if not button then
        return
    end

    button.productId = productId
    if button.icon then
        button.icon:SetTexture(GetProductIcon(product))
    end

    PositionButton(button, cfg.angle)
    if cfg.hidden then
        button:Hide()
    else
        button:Show()
    end
end

function MinimapIcon:RefreshAll()
    for productId in pairs(self.products) do
        self:Refresh(productId)
    end
end

function MinimapIcon:RegisterProduct(product)
    if not (product and product.id) then
        return false
    end

    if not ShouldRegisterProduct(product) then
        return false
    end

    local productId = product.id
    local existing = self.products[productId]
    local button = self.buttons[productId]
    local needsRefresh = existing ~= product or not button

    self.products[product.id] = product
    if needsRefresh then
        self:Refresh(productId)
    end

    if self.enteredWorld then
        self:RegisterAddonCompartment(product)
    end

    return true
end

function MinimapIcon:RegisterAddonCompartment(product)
    if not (YUI.IsRetail and product and product.id) then
        return false
    end

    if self.compartmentRegistered[product.id] then
        return true
    end

    local frame = _G.AddonCompartmentFrame
    if not (frame and frame.RegisterAddon) then
        return false
    end

    local data = {
        text = GetProductTitle(product),
        icon = GetProductIcon(product),
        func = function()
            OpenProductSettings(product)
        end,
        funcOnEnter = function(menuButton)
            if not (menuButton and GameTooltip) then
                return
            end
            GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(GetProductTitle(product))
            GameTooltip:AddLine(T("minimap_icon.tooltip.left_click", "Left-click to open settings."), 1, 1, 1)
            GameTooltip:Show()
        end,
        funcOnLeave = HideTooltip,
    }

    frame:RegisterAddon(data)
    self.compartmentRegistered[product.id] = true
    return true
end

function MinimapIcon:RegisterAddonCompartments()
    for _, product in pairs(self.products) do
        self:RegisterAddonCompartment(product)
    end
end

function MinimapIcon:RegisterExistingProducts()
    if not YUI.Products then
        return
    end

    for _, product in pairs(YUI.Products) do
        self:RegisterProduct(product)
    end
end

local function OnPlayerEnteringWorld()
    MinimapIcon.enteredWorld = true
    MinimapIcon:RegisterExistingProducts()
    MinimapIcon:RefreshAll()
    MinimapIcon:RegisterAddonCompartments()
end

local function OnReadyRefresh()
    MinimapIcon:RegisterExistingProducts()
    MinimapIcon:RefreshAll()
    if MinimapIcon.enteredWorld then
        MinimapIcon:RegisterAddonCompartments()
    end
end

MinimapIcon:RegisterExistingProducts()

if YUI.Event and YUI.Event.On then
    YUI.Event:On("YUI_DB_READY", OnReadyRefresh, MinimapIcon)
    YUI.Event:On("YUI_WORLD_READY", OnPlayerEnteringWorld, MinimapIcon)
elseif YUI.Event and YUI.Event.Once then
    YUI.Event:Once("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, MinimapIcon)
elseif CreateFrame then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        OnPlayerEnteringWorld()
    end)
end
