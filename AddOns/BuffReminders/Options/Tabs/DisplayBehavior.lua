local _, BR = ...

-- ============================================================================
-- DISPLAY & BEHAVIOR TAB
-- ============================================================================
-- Global appearance defaults + the collapsible per-category sections (the
-- per-category builder lives in DisplayBehavior_Category.lua).

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local LSM = BR.LSM

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA

local abs = math.abs
local tinsert = table.insert

local function Build(ctx)
    local C = ctx.constants
    local COL_PADDING = C.COL_PADDING

    local IsMasqueActive = ctx.IsMasqueActive
    local RenderCategorySection = BR.Options.Tabs.DisplayBehavior.RenderCategorySection

    local displayBehaviorContent = ctx:CreateScrollableContent("displayBehavior")
    local displayBehaviorX = COL_PADDING
    local displayBehaviorLayout = Components.VerticalLayout(displayBehaviorContent, { x = displayBehaviorX, y = -10 })

    -- Global Defaults section
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.GlobalDefaults"])

    local defNote = displayBehaviorContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    displayBehaviorLayout:AddText(defNote, 12, COMPONENT_GAP)
    defNote:SetText(L["Options.GlobalDefaults.Note"])

    local function isDefDimensionsLinked()
        local db = BR.profile.defaults
        return not db or db.iconWidth == nil
    end

    local defGrid = Components.AppearanceGrid(displayBehaviorContent, {
        get = function(key, default)
            local d = BR.profile.defaults
            return d and d[key] or default
        end,
        set = function(key, value)
            BR.Config.Set("defaults." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["defaults." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isDefDimensionsLinked,
        onLink = function()
            BR.Config.Set("defaults.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local db = BR.profile.defaults
            BR.Config.Set("defaults.iconWidth", db and db.iconSize or 64)
            Components.RefreshAll()
        end,
        masqueCheck = IsMasqueActive,
    })
    displayBehaviorLayout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)

    local function BuildFontOptions()
        local fontList = LSM:List("font")
        local opts = { { label = L["Options.Default"], value = nil } }
        for _, name in ipairs(fontList) do
            tinsert(opts, { label = name, value = name })
        end
        return opts
    end

    local defFontHolder = Components.Dropdown(displayBehaviorContent, {
        label = L["Options.Font"],
        labelWidth = 50,
        options = BuildFontOptions(),
        width = 200,
        maxItems = 15,
        itemInit = function(_, itemLabel, opt)
            if opt.value then
                local path = LSM:Fetch("font", opt.value)
                if path then
                    itemLabel:SetFont(path, 12, "")
                end
            end
        end,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.fontFace or nil
        end,
        onChange = function(val)
            BR.Config.Set("defaults.fontFace", val)
        end,
    })
    displayBehaviorLayout:Add(defFontHolder, nil, COMPONENT_GAP)

    local defOutlineHolder = Components.Dropdown(displayBehaviorContent, {
        label = L["Options.TextOutline"],
        labelWidth = 50,
        options = {
            { label = L["Options.TextOutline.None"], value = "NONE" },
            { label = L["Options.TextOutline.Outline"], value = "OUTLINE" },
            { label = L["Options.TextOutline.Thick"], value = "THICKOUTLINE" },
            { label = L["Options.TextOutline.Monochrome"], value = "MONOCHROME" },
            { label = L["Options.TextOutline.OutlineMono"], value = "OUTLINE, MONOCHROME" },
            { label = L["Options.TextOutline.ThickMono"], value = "THICKOUTLINE, MONOCHROME" },
        },
        width = 200,
        get = function()
            return (BR.profile.defaults and BR.profile.defaults.textOutline) or "OUTLINE"
        end,
        onChange = function(val)
            BR.Config.Set("defaults.textOutline", val)
        end,
    })
    displayBehaviorLayout:Add(defOutlineHolder, nil, COMPONENT_GAP)

    local defDirHolder = Components.DirectionButtons(displayBehaviorContent, {
        labelWidth = 50,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.growDirection or "CENTER"
        end,
        onChange = function(dir)
            BR.Config.Set("defaults.growDirection", dir)
        end,
    })
    displayBehaviorLayout:Add(defDirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local defGlowHolder = Components.Checkbox(displayBehaviorContent, {
        label = L["Options.GlowReminderIcons"],
        tooltip = {
            title = L["Options.GlowReminderIcons.Title"],
            desc = L["Options.GlowReminderIcons.Desc"],
        },
        get = function()
            local d = BR.profile.defaults
            return d and (d.showExpirationGlow ~= false or d.showMissingGlow ~= false)
        end,
        onChange = function(checked)
            BR.Config.Set("defaults.showExpirationGlow", checked)
            BR.Config.Set("defaults.showMissingGlow", checked)
            Components.RefreshAll()
        end,
    })

    local glowSettingsBtn = CreateButton(displayBehaviorContent, L["Options.Customize"], function()
        BR.Options.Modals.Glow.Show()
    end)
    glowSettingsBtn:SetPoint("LEFT", defGlowHolder.label, "RIGHT", 8, 0)
    glowSettingsBtn:SetFrameLevel(defGlowHolder:GetFrameLevel() + 5)

    displayBehaviorLayout:Add(defGlowHolder, nil, COMPONENT_GAP)

    -- Expiration Reminder section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.ExpirationReminder"])
    displayBehaviorLayout:Space(COMPONENT_GAP)

    local defThresholdHolder = Components.Slider(displayBehaviorContent, {
        label = L["Options.Threshold"],
        min = 0,
        max = 45,
        step = 5,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.expirationThreshold or 15
        end,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        onChange = function(val)
            BR.Config.Set("defaults.expirationThreshold", val)
        end,
    })
    displayBehaviorLayout:Add(defThresholdHolder, nil, COMPONENT_GAP)

    local preKeyThresholdHolder = Components.Slider(displayBehaviorContent, {
        label = L["Options.PreKeyThreshold"],
        tooltip = { title = L["Options.PreKeyThreshold"], desc = L["Options.PreKeyThreshold.Desc"] },
        min = 0,
        max = 60,
        step = 5,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.preKeyThreshold or 0
        end,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        onChange = function(val)
            BR.Config.Set("defaults.preKeyThreshold", val)
        end,
    })
    displayBehaviorLayout:Add(preKeyThresholdHolder, nil, COMPONENT_GAP)

    -- Per-Category Customization section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.PerCategoryCustomization"])
    displayBehaviorLayout:Space(COMPONENT_GAP)

    local categorySections = {}

    local function UpdateAppearanceContentHeight()
        local totalHeight = abs(displayBehaviorLayout:GetY())
        for _, sec in ipairs(categorySections) do
            totalHeight = totalHeight + sec:GetHeight() + 4
        end
        displayBehaviorContent:SetHeight(totalHeight)
    end

    local previousSection = nil
    local initialY = displayBehaviorLayout:GetY()
    for _, category in ipairs(ctx.categoryOrder) do
        previousSection = RenderCategorySection(
            ctx,
            category,
            displayBehaviorContent,
            displayBehaviorX,
            initialY,
            previousSection,
            categorySections,
            UpdateAppearanceContentHeight
        )
    end

    UpdateAppearanceContentHeight()
end

BR.Options.Tabs.DisplayBehavior = BR.Options.Tabs.DisplayBehavior or {}
BR.Options.Tabs.DisplayBehavior.Build = Build
