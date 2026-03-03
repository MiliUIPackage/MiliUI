-- Config/ConfigFrame.lua - Main config window and refresh system

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local CDM_C = CDM and CDM.CONST or {}
local UI = ns.ConfigUI
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- =========================================================================
--  MAIN CONFIG FRAME
-- =========================================================================

local ConfigFrame = nil
local categories = {}
local buttons = {}
local currentTab = nil
local ADDON_NAME = "Ayije_CDM"
local versionText = nil
local discordText = nil
local twitchText = nil
local footerRefreshRegistered = false
local combatCloseRegistered = false
local SCROLL_FRAME_NAMES = {
    text = "AyijeCDM_TextScrollFrame",
    positions = "AyijeCDM_PosScrollFrame",
    racials = "AyijeCDM_RacialsScrollFrame",
    defensives = "AyijeCDM_DefensivesScrollFrame",
    trinkets = "AyijeCDM_TrinketsScrollFrame",
    resources = "AyijeCDM_ResourcesScrollFrame",
    bars = "AyijeCDM_BarsScrollFrame",
    castbar = "AyijeCDM_CastBarScrollFrame",
}

local function GetAddonVersionText()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")

    if not version or version == "" then
        return nil
    end

    return "v" .. tostring(version)
end

local function ApplyFooterTextStyle(fontString)
    if not fontString then return end

    local db = CDM.db or {}
    local defaults = CDM.defaults or {}
    local fontName = db.textFont or defaults.textFont or "Friz Quadrata TT"
    local fontOutline = "NONE"
    local fontPath = (LSM and LSM:Fetch("font", fontName)) or CDM_C.FONT_PATH
    local fontSize = (CDM_C.GetPixelFontSize and CDM_C.GetPixelFontSize(24)) or 24

    -- Ensure the FontString always has a valid font, even if a custom font lookup fails.
    fontString:SetFontObject("GameFontHighlightSmall")
    local setOk = fontString:SetFont(fontPath, fontSize, fontOutline)
    if not setOk and CDM_C.FONT_PATH then
        fontString:SetFont(CDM_C.FONT_PATH, fontSize, fontOutline)
    end
end

local function ApplyAllFooterTextStyles()
    ApplyFooterTextStyle(versionText)
    ApplyFooterTextStyle(discordText)
    ApplyFooterTextStyle(twitchText)
end

local function PrintConfigCombatBlocked(actionLabel)
    print("|cffff0000" .. string.format(L["Cannot %s while in combat"], actionLabel or L["open CDM config"]) .. "|r")
end

local function HideConfigUiForCombat()
    local frame = ConfigFrame or ns.ConfigFrame
    if frame and frame.IsShown and frame:IsShown() then
        frame:Hide()
    end

    if StaticPopup_Hide then
        StaticPopup_Hide("AYIJE_CDM_COPY_URL")
        StaticPopup_Hide("AYIJE_CDM_CONFIRM_RESET_PROFILE")
        StaticPopup_Hide("AYIJE_CDM_CONFIRM_COPY_PROFILE")
        StaticPopup_Hide("AYIJE_CDM_CONFIRM_DELETE_PROFILE")
    end
end

local function RegisterCombatConfigAutoClose()
    if combatCloseRegistered then return end
    combatCloseRegistered = true

    CDM:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        HideConfigUiForCombat()
    end)
end

RegisterCombatConfigAutoClose()

local function SetCategoryButtonState(button, isActive)
    if isActive then
        button.Texture:SetAtlas("Options_List_Active", true)
        button.Texture:Show()
        UI.SetTextWhite(button.Text)
        return
    end

    button.Texture:Hide()
    UI.SetTextInactive(button.Text)
end

local function SelectCategory(id)
    currentTab = id
    for categoryId, frame in pairs(categories) do frame:SetShown(categoryId == id) end
    for buttonId, btn in pairs(buttons) do
        SetCategoryButtonState(btn, buttonId == id)
    end

    -- Reset scroll position for tabs with scroll frames
    local scrollFrameName = SCROLL_FRAME_NAMES[id]
    if scrollFrameName then
        local scrollFrame = _G[scrollFrameName]
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end
    end
end

-- Expose SelectCategory for tab files
ns.ConfigSelectCategory = SelectCategory

local function CreateCategoryPage(id, name, Content)
    local page = CreateFrame("Frame", nil, Content)
    page:SetAllPoints()
    page:Hide()
    page.controls = {}
    categories[id] = page
    return page
end

-- Expose CreateCategoryPage for tab files
ns.ConfigCreatePage = CreateCategoryPage

-- Category header definitions for sidebar grouping
local categoryHeaders = {
    { label = L["Display"], tabs = {"sizes", "layout", "positions"} },
    { label = L["Styling"], tabs = {"border", "text", "glow", "fading", "assist"} },
    { label = L["Buffs"], tabs = {"icons", "bars", "custombuffs"} },
    { label = L["Features"], tabs = {"racials", "resources", "defensives", "trinkets", "castbar"} },
    { label = L["Utility"], tabs = {"profiles", "importexport"} },
}

local function CreateConfigFrame()
    if ConfigFrame then return end

    ConfigFrame = CreateFrame("Frame", "Ayije_CDMConfigFrame", UIParent, "SettingsFrameTemplate")
    ConfigFrame:SetSize(920, 720)
    ConfigFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ConfigFrame:SetFrameStrata("HIGH")
    ConfigFrame:Hide()
    tinsert(UISpecialFrames, "Ayije_CDMConfigFrame")

    -- Fix default template elements
    if ConfigFrame.TitleText then
        ConfigFrame.TitleText:SetText("")
    end
    if ConfigFrame.Bg then
        ConfigFrame.Bg:SetFrameLevel(ConfigFrame:GetFrameLevel())
    end

    -- Create a container frame for title text with higher frame level (above title bar)
    local titleContainer = CreateFrame("Frame", nil, ConfigFrame)
    titleContainer:SetPoint("TOP", ConfigFrame, "TOP", 0, 0)
    titleContainer:SetSize(200, 40)
    titleContainer:SetFrameLevel(ConfigFrame:GetFrameLevel() + 10)

    -- Custom title at top of window
    local title = titleContainer:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font18")
    title:SetPoint("TOP", ConfigFrame, "TOP", 0, -30)
    title:SetText("Ayije CDM")
    UI.SetTextColor(title, CDM_C.GOLD or { r = 1, g = 0.82, b = 0, a = 1 })

    -- Subtitle below title
    local subtitle = titleContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText(L["Cooldown Manager"])
    UI.SetTextSubtle(subtitle)

    -- CDM button (opens Blizzard's CooldownViewerSettings)
    local cdmBtn = CreateFrame("Button", nil, titleContainer, "UIPanelButtonTemplate")
    cdmBtn:SetSize(90, 24)
    cdmBtn:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 22, -32)
    cdmBtn:SetText(L["Settings"])
    cdmBtn:SetScript("OnClick", function()
        local frame = CooldownViewerSettings
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end)

    ConfigFrame:SetMovable(true)
    ConfigFrame:EnableMouse(true)
    ConfigFrame:RegisterForDrag("LeftButton")
    ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
    ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)

    -- Add recessed background for entire panel (matches Blizzard's Options_InnerFrame)
    -- Hosted on a child frame so it renders above the template's Bg frame
    local panelBgHolder = CreateFrame("Frame", nil, ConfigFrame)
    panelBgHolder:SetAllPoints()
    local panelBg = panelBgHolder:CreateTexture(nil, "BACKGROUND")
    panelBg:SetAtlas("Options_InnerFrame", true)  -- true = use atlas native size
    panelBg:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 17, -64)  -- Matches Blizzard's positioning

    -- Social links (bottom-left)
    local gold = CDM_C.GOLD or { r = 1, g = 0.82, b = 0, a = 1 }

    local discordBtn = CreateFrame("Button", nil, ConfigFrame)
    discordBtn:SetSize(80, 20)
    discordBtn:SetPoint("BOTTOMLEFT", ConfigFrame, "BOTTOMLEFT", 22, 10)

    local discordIcon = discordBtn:CreateTexture(nil, "ARTWORK")
    discordIcon:SetSize(16, 16)
    discordIcon:SetPoint("LEFT", 0, 0)
    discordIcon:SetTexture("Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Discord.tga")

    discordText = discordBtn:CreateFontString(nil, "OVERLAY")
    discordText:SetPoint("LEFT", discordIcon, "RIGHT", 4, 0)
    ApplyFooterTextStyle(discordText)
    discordText:SetText("Discord")
    UI.SetTextFaint(discordText)

    discordBtn:SetScript("OnClick", function()
        local link = C_EncodingUtil.DeserializeCBOR(
            C_EncodingUtil.DecodeBase64("oURsaW5rWB1odHRwczovL2Rpc2NvcmQuZ2cvUmV4ZjNEaG5CRA==")
        ).link
        StaticPopup_Show("AYIJE_CDM_COPY_URL", nil, nil, {url = link})
    end)
    discordBtn:SetScript("OnEnter", function()
        UI.SetTextColor(discordText, gold)
    end)
    discordBtn:SetScript("OnLeave", function()
        UI.SetTextFaint(discordText)
    end)

    local twitchBtn = CreateFrame("Button", nil, ConfigFrame)
    twitchBtn:SetSize(80, 20)
    twitchBtn:SetPoint("LEFT", discordBtn, "RIGHT", 6, 0)

    local twitchIcon = twitchBtn:CreateTexture(nil, "ARTWORK")
    twitchIcon:SetSize(16, 16)
    twitchIcon:SetPoint("LEFT", 0, 0)
    twitchIcon:SetTexture("Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Twitch.tga")

    twitchText = twitchBtn:CreateFontString(nil, "OVERLAY")
    twitchText:SetPoint("LEFT", twitchIcon, "RIGHT", 4, 0)
    ApplyFooterTextStyle(twitchText)
    twitchText:SetText("Twitch")
    UI.SetTextFaint(twitchText)

    twitchBtn:SetScript("OnClick", function()
        local link = C_EncodingUtil.DeserializeCBOR(
            C_EncodingUtil.DecodeBase64("oURsaW5rV2h0dHBzOi8vdHdpdGNoLnR2L2F5aWpl")
        ).link
        StaticPopup_Show("AYIJE_CDM_COPY_URL", nil, nil, {url = link})
    end)
    twitchBtn:SetScript("OnEnter", function()
        UI.SetTextColor(twitchText, gold)
    end)
    twitchBtn:SetScript("OnLeave", function()
        UI.SetTextFaint(twitchText)
    end)

    -- Version text (bottom-right)
    versionText = ConfigFrame:CreateFontString(nil, "OVERLAY")
    versionText:SetPoint("BOTTOMRIGHT", ConfigFrame, "BOTTOMRIGHT", -22, 10)
    ApplyFooterTextStyle(versionText)
    versionText:SetText(GetAddonVersionText() or "")
    if UI and UI.SetTextFaint then
        UI.SetTextFaint(versionText)
    else
        versionText:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    local Sidebar = CreateFrame("Frame", nil, ConfigFrame)
    Sidebar:SetPoint("TOPLEFT", panelBg, "TOPLEFT", 1, 0)
    Sidebar:SetPoint("BOTTOMLEFT", panelBg, "BOTTOMLEFT", 1, 0)
    Sidebar:SetWidth(180)

    local Content = CreateFrame("Frame", nil, ConfigFrame)
    Content:SetPoint("TOPLEFT", Sidebar, "TOPRIGHT", 35, 0)
    Content:SetPoint("BOTTOMRIGHT", -30, 25)

    -- Store references for tab files
    ns.ConfigContent = Content
    ns.ConfigFrame = ConfigFrame
    ns.ConfigSidebar = Sidebar

    -- Sort tabs by navOrder
    local sortedTabs = {}
    for id, tabDef in pairs(ns.ConfigTabs or {}) do
        table.insert(sortedTabs, tabDef)
    end
    table.sort(sortedTabs, function(a, b) return a.navOrder < b.navOrder end)

    -- Create pages and call tab create functions
    for _, tabDef in ipairs(sortedTabs) do
        local page = CreateCategoryPage(tabDef.id, tabDef.label, Content)
        if tabDef.createFunc then
            tabDef.createFunc(page, tabDef.id)
        end
    end

    -- Create category header using Blizzard's SettingsCategoryListHeaderTemplate
    local headerIndex = 1
    local function AddHeader(label, y)
        local header = CreateFrame("Frame", nil, Sidebar, "SettingsCategoryListHeaderTemplate")
        header:SetPoint("TOPLEFT", 0, y)

        -- Initialize with the mixin pattern (simplified - no ScrollBox infrastructure needed)
        -- Cycle headerIndex within 1-3 range (only 3 atlas textures exist: Options_CategoryHeader_1/2/3)
        local atlasIndex = ((headerIndex - 1) % 3) + 1
        local initializer = { data = { label = label, headerIndex = atlasIndex } }
        header:Init(initializer)

        headerIndex = headerIndex + 1
        return header
    end

    -- Create navigation button with indent support
    local function AddNav(id, label, y, indent)
        indent = indent or 0
        local btn = CreateFrame("Button", nil, Sidebar)
        btn:SetSize(175 - indent, 22)  -- Match header width
        btn:SetPoint("TOPLEFT", indent, y)

        btn.Texture = btn:CreateTexture(nil, "BACKGROUND")
        btn.Texture:SetPoint("TOPLEFT", -10, 0)
        btn.Texture:SetPoint("BOTTOMRIGHT", 20, 0)
        btn.Texture:Hide()

        btn.Text = btn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        btn.Text:SetPoint("LEFT", indent, 0)  -- Include indent for child hierarchy
        btn.Text:SetText(label)

        btn:SetScript("OnEnter", function(self)
            if currentTab ~= id then
                self.Texture:SetAtlas("Options_List_Hover", true)
                self.Texture:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if currentTab ~= id then
                self.Texture:Hide()
            end
        end)

        btn:SetScript("OnClick", function() SelectCategory(id) end)
        buttons[id] = btn
    end

    -- Build navigation with headers and indented tabs
    local yOffset = -4
    local tabIndent = 17  -- Indent for tabs under headers (visible child hierarchy)

    for _, category in ipairs(categoryHeaders) do
        -- Add category header
        AddHeader(category.label, yOffset)
        yOffset = yOffset - 34  -- Header height (30) + spacing (4)

        -- Add tabs belonging to this category
        for _, tabId in ipairs(category.tabs) do
            local tabDef = ns.ConfigTabs and ns.ConfigTabs[tabId]
            if tabDef then
                AddNav(tabDef.id, tabDef.label, yOffset, tabIndent)
                yOffset = yOffset - 24
            end
        end

    end

    -- Select first tab
    if sortedTabs[1] then
        SelectCategory(sortedTabs[1].id)
    end

    if not footerRefreshRegistered then
        API:RegisterRefreshCallback("configFooterTextStyle", function()
            ApplyAllFooterTextStyles()
        end, 95)
        footerRefreshRegistered = true
    end
end

-- =========================================================================
--  PUBLIC API
-- =========================================================================

function API:ShowConfig()
    if InCombatLockdown() then
        PrintConfigCombatBlocked(L["open CDM config"])
        return
    end

    if not ConfigFrame then CreateConfigFrame() end
    ConfigFrame:Show()
end

function API:RebuildConfigFrame(targetTab)
    if InCombatLockdown() then
        PrintConfigCombatBlocked(L["rebuild CDM config"])
        return
    end

    if ConfigFrame then
        if ns.eventRegistryTokens and EventRegistry then
            for eventKey, tokenEntry in pairs(ns.eventRegistryTokens) do
                local eventName = eventKey
                local token = tokenEntry

                if type(tokenEntry) == "table" then
                    eventName = tokenEntry.eventName or tokenEntry[1] or eventKey
                    token = tokenEntry.token or tokenEntry[2]
                elseif type(eventKey) == "string" and eventKey:find("^Icons%.") then
                    eventName = eventKey:gsub("^Icons%.", "")
                end

                if eventName and token then
                    EventRegistry:UnregisterCallback(eventName, token)
                end
            end
            ns.eventRegistryTokens = {}
        end

        API:UnregisterCastBarSliderUpdater()
        API:UnregisterPositionSliderUpdater("essential")
        API:UnregisterPositionSliderUpdater("buff")
        API:UnregisterPositionSliderUpdater("buffBar")

        API:UnregisterRefreshCallback("configFooterTextStyle")
        footerRefreshRegistered = false
        API:UnregisterRefreshCallback("icons-border-colors")

        ConfigFrame:Hide()
        ConfigFrame:SetParent(nil)  -- orphan for GC
        ConfigFrame = nil
        categories = {}
        buttons = {}
        currentTab = nil
        versionText = nil
        discordText = nil
        twitchText = nil
        ns.ConfigFrame = nil
        ns.ConfigContent = nil
        ns.ConfigSidebar = nil
    end
    CreateConfigFrame()
    ConfigFrame:Show()

    local tabToSelect = targetTab or "profiles"
    if not (ns.ConfigTabs and ns.ConfigTabs[tabToSelect]) then
        tabToSelect = "profiles"
    end
    if ns.ConfigTabs and ns.ConfigTabs[tabToSelect] then
        SelectCategory(tabToSelect)
    end
end
