local addonName, ns = ...
local L = ns.L

local FILTER_OPTIONS = ns.filterOptions or {
    { key = "show_services", label = L.SHOW_SERVICES },
    { key = "show_professions", label = L.SHOW_PROFESSIONS },
    { key = "show_activities", label = L.SHOW_ACTIVITIES },
    { key = "show_travel", label = L.SHOW_TRAVEL },
    { key = "show_portals", label = L.SHOW_PORTALS },
}

local SCALE_VALUES = { 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.5, 3.0 }
local ALPHA_VALUES = { 0.25, 0.5, 0.75, 1.0 }

local function EnsureDropdownAPI()
    if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and ToggleDropDownMenu then
        return true
    end

    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loadAddOn then
        pcall(loadAddOn, "Blizzard_UIDropDownMenu")
    end

    return UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and ToggleDropDownMenu
end

local EasyMenu_Initialize = EasyMenu_Initialize or function(frame, level, menuList)
    for index = 1, #menuList do
        local value = menuList[index]
        if value.text then
            value.index = index
            UIDropDownMenu_AddButton(value, level)
        end
    end
end

local EasyMenu_Fallback = EasyMenu or function(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
    if displayMode == "MENU" then
        menuFrame.displayMode = displayMode
    end

    UIDropDownMenu_Initialize(menuFrame, EasyMenu_Initialize, displayMode, nil, menuList)
    ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
end

local function OpenFullOptions()
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:Open(addonName)

    if dialog.SelectGroup then
        dialog:SelectGroup(addonName)
    end
end

local function FormatScale(value)
    return ("%.1f"):format(value)
end

local function FormatAlpha(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function ReopenMenu()
    if not (ns.worldMapOptionsButton and ns.worldMapOptionsButton:IsShown()) then
        return
    end

    if CloseDropDownMenus then
        CloseDropDownMenus()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if ns.worldMapOptionsButton and ns.worldMapOptionsButton:IsShown() then
                ns.worldMapOptionsButton:OpenMenu()
            end
        end)
    else
        ns.worldMapOptionsButton:OpenMenu()
    end
end

local function AreAllFiltersSet(value)
    for _, option in ipairs(FILTER_OPTIONS) do
        if ns.GetOption(option.key) ~= value then
            return false
        end
    end

    return true
end

local function GetBulkFilterToggleState()
    local showAll = not AreAllFiltersSet(true)
    return showAll, showAll and L.SHOW_ALL or L.HIDE_ALL
end

local function BuildChoiceMenu(setting, values, formatter)
    local menu = {}

    for _, rawValue in ipairs(values) do
        local value = rawValue
        menu[#menu + 1] = {
            text = formatter(value),
            checked = ns.db and ns.db[setting] == value,
            func = function()
                ns.SetOption(setting, value)
                ReopenMenu()
            end,
        }
    end

    return menu
end

local function BuildMenu()
    local menu = {
        {
            text = L.ADDON_NAME,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = " ",
            disabled = true,
            notCheckable = true,
        },
    }

    local showAll, toggleLabel = GetBulkFilterToggleState()
    menu[#menu + 1] = {
        text = toggleLabel,
        notCheckable = true,
        func = function()
            ns.SetAllFilterOptions(showAll)
            ReopenMenu()
        end,
    }
    menu[#menu + 1] = {
        text = " ",
        disabled = true,
        notCheckable = true,
    }

    for _, option in ipairs(FILTER_OPTIONS) do
        menu[#menu + 1] = {
            text = option.label or option.name,
            checked = ns.GetOption(option.key),
            isNotRadio = true,
            keepShownOnClick = true,
            func = function(button)
                ns.SetOption(option.key, button.checked)
            end,
        }
    end

    menu[#menu + 1] = {
        text = " ",
        disabled = true,
        notCheckable = true,
    }
    menu[#menu + 1] = {
        text = L.WORLD_MAP_SCALE_FORMAT:format(FormatScale(ns.GetOption("map_icon_scale"))),
        notCheckable = true,
        hasArrow = true,
        menuList = BuildChoiceMenu("map_icon_scale", SCALE_VALUES, function(value)
            return ("%sx"):format(FormatScale(value))
        end),
    }
    menu[#menu + 1] = {
        text = L.MINIMAP_SCALE_FORMAT:format(FormatScale(ns.GetOption("minimap_icon_scale"))),
        notCheckable = true,
        hasArrow = true,
        menuList = BuildChoiceMenu("minimap_icon_scale", SCALE_VALUES, function(value)
            return ("%sx"):format(FormatScale(value))
        end),
    }
    menu[#menu + 1] = {
        text = L.ICON_ALPHA_FORMAT:format(FormatAlpha(ns.GetOption("icon_alpha"))),
        notCheckable = true,
        hasArrow = true,
        menuList = BuildChoiceMenu("icon_alpha", ALPHA_VALUES, FormatAlpha),
    }
    menu[#menu + 1] = {
        text = " ",
        disabled = true,
        notCheckable = true,
    }
    menu[#menu + 1] = {
        text = L.OPEN_FULL_SETTINGS,
        notCheckable = true,
        func = OpenFullOptions,
    }

    return menu
end

local function GetButtonParent()
    if WorldMapFrame and WorldMapFrame.GetCanvasContainer then
        return WorldMapFrame:GetCanvasContainer()
    end

    return WorldMapFrame
end

local WorldMapOptionsButtonMixin = {}

function WorldMapOptionsButtonMixin:UpdatePosition()
    local parent = GetButtonParent()
    if not parent then
        return
    end

    if self:GetParent() ~= parent then
        self:SetParent(parent)
    end

    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -68)
end

function WorldMapOptionsButtonMixin:Refresh()
    if not (ns.db and WorldMapFrame and WorldMapFrame.GetMapID) then
        self:Hide()
        return
    end

    self:UpdatePosition()

    if ns.GetOption("show_worldmap_button") and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == ns.mapID then
        self:Show()
    else
        self:Hide()
    end
end

function WorldMapOptionsButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    GameTooltip:AddLine(L.QUICK_OPTIONS_DESCRIPTION, 1, 1, 1, true)
    GameTooltip:AddLine(L.LEFT_CLICK_OPTIONS_DESCRIPTION, 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end

function WorldMapOptionsButtonMixin:OnLeave()
    GameTooltip:Hide()
end

function WorldMapOptionsButtonMixin:OnMouseDown(button)
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    self.Icon:ClearAllPoints()
    self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -8)
end

function WorldMapOptionsButtonMixin:OnMouseUp(button)
    self.Icon:ClearAllPoints()
    self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -6)

    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    if not EnsureDropdownAPI() then
        OpenFullOptions()
        return
    end

    if not self.DropDown then
        self.DropDown = CreateFrame("Frame", addonName .. "WorldMapOptionsDropDown", UIParent, "UIDropDownMenuTemplate")
    end

    self:OpenMenu()

    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function WorldMapOptionsButtonMixin:OpenMenu()
    if not self.DropDown then
        return
    end

    EasyMenu_Fallback(BuildMenu(), self.DropDown, self, 0, 0, "MENU", 2)
end

local function CreateWorldMapOptionsButton()
    local parent = GetButtonParent()
    if not parent then
        return nil
    end

    local button = CreateFrame("Button", addonName .. "WorldMapOptionsButton", parent)
    button:SetSize(32, 32)
    button:SetFrameStrata("HIGH")
    button:EnableMouse(true)
    button:SetClampedToScreen(true)

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.Background:SetSize(25, 25)
    button.Background:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -4)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetTexture(ns.addonIcon or "Interface\\Icons\\INV_Misc_Map_01")
    button.Icon:SetSize(20, 20)
    button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)

    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.Border:SetSize(54, 54)
    button.Border:SetPoint("TOPLEFT", button, "TOPLEFT")

    button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.Highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.Highlight:SetBlendMode("ADD")
    button.Highlight:SetAllPoints(button)

    button:SetScript("OnEnter", WorldMapOptionsButtonMixin.OnEnter)
    button:SetScript("OnLeave", WorldMapOptionsButtonMixin.OnLeave)
    button:SetScript("OnMouseDown", WorldMapOptionsButtonMixin.OnMouseDown)
    button:SetScript("OnMouseUp", WorldMapOptionsButtonMixin.OnMouseUp)
    button:SetScript("OnHide", function()
        if CloseDropDownMenus then
            CloseDropDownMenus()
        end
    end)

    for methodName, method in pairs(WorldMapOptionsButtonMixin) do
        button[methodName] = method
    end

    button:Refresh()

    return button
end

function ns.RefreshWorldMapOptions()
    if ns.worldMapOptionsButton then
        ns.worldMapOptionsButton:Refresh()
    end
end

function ns.InitializeWorldMapOptions()
    if ns.worldMapOptionsButton or not WorldMapFrame then
        return
    end

    ns.worldMapOptionsButton = CreateWorldMapOptionsButton()
    if not ns.worldMapOptionsButton then
        return
    end

    local function RefreshButton()
        ns.RefreshWorldMapOptions()
    end

    WorldMapFrame:HookScript("OnShow", RefreshButton)
    WorldMapFrame:HookScript("OnHide", RefreshButton)

    if type(WorldMapFrame.RefreshOverlayFrames) == "function" then
        hooksecurefunc(WorldMapFrame, "RefreshOverlayFrames", RefreshButton)
    elseif type(WorldMapFrame.OnMapChanged) == "function" then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", RefreshButton)
    end

    if type(WorldMapFrame.OnFrameSizeChanged) == "function" then
        hooksecurefunc(WorldMapFrame, "OnFrameSizeChanged", RefreshButton)
    end

    if type(WorldMapFrame.SynchronizeDisplayState) == "function" then
        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", RefreshButton)
    end
end
