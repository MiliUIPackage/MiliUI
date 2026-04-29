local _, BR = ...

-- ============================================================================
-- DISPLAY & BEHAVIOR — PER-CATEGORY SECTION
-- ============================================================================
-- Builds one collapsible section (raid / presence / targeted / self / pet /
-- consumable / custom). Factored out of the DisplayBehavior tab driver so each
-- function stays under Lua 5.1's 60-upvalue ceiling.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit

local UpdateDisplay = BR.Display.Update
local UpdateVisuals = BR.Display.UpdateVisuals
local ResetCategoryFramePosition = BR.Display.ResetCategoryFramePosition
local ReparentBuffFrames = function()
    BR.CallbackRegistry:TriggerEvent("FramesReparent")
end

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA

local abs = math.abs
local mmax = math.max
local mfloor = math.floor
local tinsert = table.insert

-- Builds a single category section and appends it to `categorySections`.
-- Returns the section frame so the driver can chain-anchor the next one.
local function RenderCategorySection(
    ctx,
    category,
    parent,
    displayBehaviorX,
    initialY,
    previousSection,
    categorySections,
    UpdateAppearanceContentHeight
)
    local db = BR.profile
    local defaults = BR.defaults
    local IsMasqueActive = ctx.IsMasqueActive
    local categoryLabels = ctx.categoryLabels

    local section = Components.CollapsibleSection(parent, {
        title = categoryLabels[category],
        defaultCollapsed = true,
        scrollbarOffset = ctx.constants.COL_PADDING,
        onToggle = function()
            C_Timer.After(0, UpdateAppearanceContentHeight)
        end,
    })

    if previousSection then
        section:SetPoint("TOPLEFT", previousSection, "BOTTOMLEFT", 0, -4)
    else
        section:SetPoint("TOPLEFT", displayBehaviorX, initialY)
    end

    local catContent = section:GetContentFrame()
    local catLayout = Components.VerticalLayout(catContent, { x = 0, y = 0 })

    -- W/S/D/R content visibility + ready check (not for custom — custom uses per-buff loadConditions)
    if category ~= "custom" then
        local function OnCategoryVisibilityChange()
            UpdateDisplay()
        end

        local visToggles = Components.VisibilityToggles(catContent, {
            category = category,
            onChange = function()
                OnCategoryVisibilityChange()
                Components.RefreshAll()
            end,
        })
        catLayout:Add(visToggles, nil, SECTION_GAP)

        local hideInPvPMatchHolder = Components.Checkbox(catContent, {
            label = L["Options.HidePvPMatchStart"],
            get = function()
                local vis = db.categoryVisibility and db.categoryVisibility[category]
                return vis and vis.hideInPvPMatch or false
            end,
            enabled = function()
                local vis = db.categoryVisibility and db.categoryVisibility[category]
                return not vis or vis.pvp ~= false
            end,
            tooltip = {
                title = L["Options.HidePvPMatchStart.Title"],
                desc = L["Options.HidePvPMatchStart.Desc"],
            },
            onChange = function(checked)
                if not db.categoryVisibility then
                    db.categoryVisibility = {}
                end
                if not db.categoryVisibility[category] then
                    db.categoryVisibility[category] = {
                        openWorld = true,
                        scenario = true,
                        dungeon = true,
                        raid = true,
                        housing = false,
                        pvp = true,
                        hideInPvPMatch = true,
                    }
                end
                db.categoryVisibility[category].hideInPvPMatch = checked
                OnCategoryVisibilityChange()
            end,
        })
        catLayout:Add(hideInPvPMatchHolder, nil, COMPONENT_GAP)

        local readyCheckHolder = Components.Checkbox(catContent, {
            label = L["Options.ReadyCheckOnly"],
            get = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return cs and cs.showOnlyOnReadyCheck == true
            end,
            tooltip = {
                title = L["Options.ReadyCheckOnly"],
                desc = L["Options.ReadyCheckOnly.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showOnlyOnReadyCheck", checked)
            end,
        })
        catLayout:Add(readyCheckHolder, nil, COMPONENT_GAP)

        -- Free consumables sub-section (consumable category only)
        if category == "consumable" then
            local function EnsureFreeVisibility()
                if not db.defaults then
                    db.defaults = {}
                end
                if not db.defaults.freeConsumableVisibility then
                    db.defaults.freeConsumableVisibility = {
                        openWorld = false,
                        scenario = true,
                        dungeon = true,
                        raid = true,
                        housing = false,
                        pvp = true,
                    }
                end
                return db.defaults.freeConsumableVisibility
            end
            catLayout:Space(SECTION_GAP)
            local freeHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            freeHeader:SetText("|cffffcc00" .. L["Options.FreeConsumables"] .. "|r")
            catLayout:AddText(freeHeader, 12, COMPONENT_GAP)
            local freeNote = catContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            freeNote:SetText(L["Options.FreeConsumables.Note"])
            catLayout:AddText(freeNote, 10, COMPONENT_GAP)

            local function IsFreeOverride()
                return BR.Config.Get("defaults.freeConsumableMode", "override") == "override"
            end

            local freeOverrideHolder = Components.Checkbox(catContent, {
                label = L["Options.FreeConsumables.Override"],
                get = function()
                    return IsFreeOverride()
                end,
                tooltip = {
                    title = L["Options.FreeConsumables.Override"],
                    desc = L["Options.FreeConsumables.Override.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.freeConsumableMode", checked and "override" or "follow")
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(freeOverrideHolder, nil, COMPONENT_GAP)

            local INDENT = 12
            catLayout:SetX(catLayout:GetX() + INDENT)

            local freeVisToggles = Components.VisibilityToggles(catContent, {
                store = {
                    getContent = function(key)
                        local vis = db.defaults and db.defaults.freeConsumableVisibility
                        return not vis or vis[key] ~= false
                    end,
                    setContent = function(key)
                        local vis = EnsureFreeVisibility()
                        vis[key] = not vis[key]
                    end,
                    getDiffTable = function(dbKey)
                        local vis = db.defaults and db.defaults.freeConsumableVisibility
                        return vis and vis[dbKey]
                    end,
                    ensureDiffTable = function(dbKey)
                        local vis = EnsureFreeVisibility()
                        if not vis[dbKey] then
                            vis[dbKey] = {} ---@diagnostic disable-line: assign-type-mismatch
                        end
                        return vis[dbKey]
                    end,
                },
                noAutoRefresh = true,
                onChange = function()
                    UpdateDisplay()
                end,
            })
            local origVisRefresh = freeVisToggles.Refresh
            function freeVisToggles:Refresh()
                origVisRefresh(self)
                local enabled = IsFreeOverride()
                self:SetAlpha(enabled and 1 or 0.4)
                for _, btn in ipairs(self.allToggleButtons) do
                    btn:EnableMouse(enabled)
                end
            end
            tinsert(BR.RefreshableComponents, freeVisToggles)
            catLayout:Add(freeVisToggles, nil, COMPONENT_GAP)

            catLayout:SetX(catLayout:GetX() - INDENT)
            catLayout:Space(SECTION_GAP)
        end
    else
        local banner = Components.Banner(catContent, {
            text = L["CustomBuff.SettingsMovedNote"],
            color = "orange",
            icon = "services-icon-warning",
        })
        -- Set RIGHT before Add so the banner has a determinate width; Add
        -- then sets TOPLEFT and synchronously calls banner:FitHeight().
        banner:SetPoint("RIGHT", catContent, "RIGHT", 0, 0)
        catLayout:Add(banner, nil, SECTION_GAP)
    end

    -- Icons sub-header (all categories except custom)
    if category ~= "custom" then
        local iconsHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        iconsHeader:SetText("|cffffcc00" .. L["Options.Icons"] .. "|r")
        catLayout:AddText(iconsHeader, 12, COMPONENT_GAP)
    end

    -- Show text on icons (not for custom)
    if category ~= "custom" then
        local showTextHolder = Components.Checkbox(catContent, {
            label = L["Options.ShowText"],
            get = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return not cs or cs.showText ~= false
            end,
            tooltip = {
                title = L["Options.ShowText"],
                desc = L["Options.ShowText.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showText", checked)
            end,
        })
        catLayout:Add(showTextHolder, nil, COMPONENT_GAP)
    end

    -- Missing count only (raid only)
    if category == "raid" then
        local missingCountHolder = Components.Checkbox(catContent, {
            label = L["Options.ShowMissingCountOnly"],
            get = function()
                return db.showMissingCountOnly == true
            end,
            tooltip = {
                title = L["Options.ShowMissingCountOnly"],
                desc = L["Options.ShowMissingCountOnly.Desc"],
            },
            enabled = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return not cs or cs.showText ~= false
            end,
            onChange = function(checked)
                BR.Config.Set("showMissingCountOnly", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(missingCountHolder, nil, COMPONENT_GAP)
    end

    -- "BUFF!" text (raid only, grouped under Icons)
    if category == "raid" then
        local reminderHolder = Components.Checkbox(catContent, {
            label = L["Options.ShowBuffReminderText"],
            get = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return not cs or cs.showBuffReminder ~= false
            end,
            onChange = function(checked)
                BR.Config.Set("categorySettings.raid.showBuffReminder", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(reminderHolder, nil, COMPONENT_GAP)

        local buffTextSizeHolder = Components.NumericStepper(reminderHolder, {
            label = L["Options.Size"],
            labelWidth = 28,
            min = 6,
            max = 40,
            get = function()
                local cs = db.categorySettings and db.categorySettings.raid
                if cs and cs.buffTextSize then
                    return cs.buffTextSize
                end
                local textSize = (cs and cs.textSize) or defaults.defaults.textSize
                return mmax(6, mfloor(textSize * 0.8))
            end,
            enabled = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return not cs or cs.showBuffReminder ~= false
            end,
            onChange = function(val)
                BR.Config.Set("categorySettings.raid.buffTextSize", val)
            end,
        })
        buffTextSizeHolder:SetPoint("LEFT", reminderHolder, "LEFT", 210, 0)

        local buffTextOffsetXHolder = Components.Slider(catContent, {
            label = L["Options.BuffTextOffsetX"],
            labelWidth = 60,
            min = -40,
            max = 40,
            get = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return (cs and cs.buffTextOffsetX) or 0
            end,
            enabled = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return not cs or cs.showBuffReminder ~= false
            end,
            onChange = function(val)
                BR.Config.Set("categorySettings.raid.buffTextOffsetX", val)
            end,
        })

        local buffTextOffsetYHolder = Components.Slider(catContent, {
            label = L["Options.BuffTextOffsetY"],
            labelWidth = 60,
            min = -40,
            max = 40,
            get = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return (cs and cs.buffTextOffsetY) or 0
            end,
            enabled = function()
                local cs = db.categorySettings and db.categorySettings.raid
                return not cs or cs.showBuffReminder ~= false
            end,
            onChange = function(val)
                BR.Config.Set("categorySettings.raid.buffTextOffsetY", val)
            end,
        })

        buffTextOffsetYHolder:SetPoint("LEFT", buffTextOffsetXHolder, "LEFT", 210, 0)
        catLayout:Add(buffTextOffsetXHolder, nil, COMPONENT_GAP)
    end

    -- Click to cast checkbox
    if category ~= "custom" then
        local clickableHolder = Components.Checkbox(catContent, {
            label = L["Options.ClickToCast"],
            get = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return cs and cs.clickable == true
            end,
            tooltip = {
                title = L["Options.ClickToCast"],
                desc = L["Options.ClickToCast.DescFull"],
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                db.categorySettings[category].clickable = checked
                BR.Display.UpdateActionButtons(category)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(clickableHolder, nil, 2)

        catLayout:SetX(20)
        local highlightHolder = Components.Checkbox(catContent, {
            label = L["Options.HoverHighlight"],
            get = function()
                local hcs = db.categorySettings and db.categorySettings[category]
                return hcs and hcs.clickableHighlight ~= false
            end,
            enabled = function()
                local hcs = db.categorySettings and db.categorySettings[category]
                return hcs and hcs.clickable == true
            end,
            tooltip = {
                title = L["Options.HoverHighlight"],
                desc = L["Options.HoverHighlight.Desc"],
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                db.categorySettings[category].clickableHighlight = checked
                BR.Display.UpdateActionButtons(category)
            end,
        })
        catLayout:Add(highlightHolder, nil, COMPONENT_GAP)

        if category == "pet" then
            local specIconHolder = Components.Checkbox(catContent, {
                label = L["Options.PetSpecIcon"],
                get = function()
                    return BR.Config.Get("defaults.petSpecIconOnHover", true)
                end,
                enabled = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickable == true
                end,
                tooltip = {
                    title = L["Options.PetSpecIcon.Title"],
                    desc = L["Options.PetSpecIcon.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.petSpecIconOnHover", checked)
                end,
            })
            catLayout:Add(specIconHolder, nil, COMPONENT_GAP)
        end

        if category == "consumable" then
            local showTooltipsHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowItemTooltips"],
                get = function()
                    return BR.Config.Get("defaults.showConsumableTooltips", false) ~= false
                end,
                enabled = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickable == true
                end,
                tooltip = {
                    title = L["Options.ShowItemTooltips"],
                    desc = L["Options.ShowItemTooltips.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.showConsumableTooltips", checked)
                end,
            })
            catLayout:Add(showTooltipsHolder, nil, COMPONENT_GAP)
        end

        catLayout:SetX(0)
    end

    -- Pet display settings (pet only)
    if category == "pet" then
        catLayout:Space(SECTION_GAP)

        local updatePetDisplayModePreview
        local petDisplayModeHolder = Components.Dropdown(catContent, {
            label = L["Options.PetDisplay"],
            width = 120,
            get = function()
                return BR.Config.Get("defaults.petDisplayMode", "generic")
            end,
            options = {
                {
                    value = "generic",
                    label = L["Options.PetDisplay.Generic"],
                    desc = L["Options.PetDisplay.GenericDesc"],
                },
                {
                    value = "expanded",
                    label = L["Options.PetDisplay.Summon"],
                    desc = L["Options.PetDisplay.SummonDesc"],
                },
            },
            tooltip = {
                title = L["Options.PetDisplay.Mode"],
                desc = L["Options.PetDisplay.Mode.Desc"],
            },
            onChange = function(val)
                BR.Config.Set("defaults.petDisplayMode", val)
                if updatePetDisplayModePreview then
                    updatePetDisplayModePreview(val)
                end
            end,
        })
        catLayout:Add(petDisplayModeHolder, nil, COMPONENT_GAP)

        local PP_ICON = 24
        local PP_BORDER = 2
        local PP_GAP = 3
        local PP_STEP = PP_ICON + PP_GAP + PP_BORDER * 2

        local TEX_PET_GENERIC = 136082
        local TEX_PETS = { 136218, 136221, 136217 }

        local petPreviewHeight = PP_ICON + PP_BORDER * 2
        local PET_MODE_ICON_COUNT = { generic = 1, expanded = 3 }

        local petPreviewHolder = CreateFrame("Frame", nil, catContent)
        petPreviewHolder:SetSize(PP_STEP, petPreviewHeight)
        petPreviewHolder:SetPoint("TOPLEFT", petDisplayModeHolder, "TOPRIGHT", 12, 0)

        local petPreviewContainer = CreateFrame("Frame", nil, petPreviewHolder)
        petPreviewContainer:SetPoint("TOPLEFT", 0, 0)
        petPreviewContainer:SetSize(3 * PP_STEP, petPreviewHeight)
        petPreviewContainer:SetAlpha(0.7)

        local function CreatePetPreviewIcon(parentFrame, texture, size)
            local f = CreateFrame("Frame", nil, parentFrame)
            f:SetSize(size, size)
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetAllPoints()
            f.icon:SetTexture(texture)
            local z = TEXCOORD_INSET
            f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
            f.border = f:CreateTexture(nil, "BACKGROUND")
            f.border:SetColorTexture(0, 0, 0, 1)
            f.border:SetPoint("TOPLEFT", -PP_BORDER, PP_BORDER)
            f.border:SetPoint("BOTTOMRIGHT", PP_BORDER, -PP_BORDER)
            return f
        end

        local allPetPreviewFrames = {}

        local genericFrame = CreatePetPreviewIcon(petPreviewContainer, TEX_PET_GENERIC, PP_ICON)
        genericFrame:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", 0, 0)
        genericFrame:Hide()
        allPetPreviewFrames[#allPetPreviewFrames + 1] = genericFrame

        local expandedPetFrames = {}
        for i = 1, 3 do
            local f = CreatePetPreviewIcon(petPreviewContainer, TEX_PETS[i], PP_ICON)
            f:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", (i - 1) * PP_STEP, 0)
            f:Hide()
            expandedPetFrames[i] = f
            allPetPreviewFrames[#allPetPreviewFrames + 1] = f
        end

        local PET_MODE_FRAMES = {
            generic = { genericFrame },
            expanded = expandedPetFrames,
        }
        updatePetDisplayModePreview = function(mode)
            for _, f in ipairs(allPetPreviewFrames) do
                f:Hide()
            end
            local shown = PET_MODE_FRAMES[mode]
            if shown then
                for _, f in ipairs(shown) do
                    f:Show()
                end
            end
            petPreviewHolder:SetWidth((PET_MODE_ICON_COUNT[mode] or 1) * PP_STEP)
        end

        updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))

        function petPreviewHolder:Refresh()
            updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))
        end
        tinsert(BR.RefreshableComponents, petPreviewHolder)

        local petLabelsHolder = Components.Checkbox(catContent, {
            label = L["Options.PetLabels"],
            get = function()
                return BR.Config.Get("defaults.petLabels", true)
            end,
            tooltip = {
                title = L["Options.PetLabels"],
                desc = L["Options.PetLabels.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.petLabels", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(petLabelsHolder, nil, COMPONENT_GAP)

        local petLabelScaleHolder = Components.NumericStepper(petLabelsHolder, {
            label = L["Options.PetLabels.SizePct"],
            labelWidth = 36,
            min = 50,
            max = 200,
            step = 10,
            get = function()
                return BR.Config.Get("defaults.petLabelScale", 100)
            end,
            enabled = function()
                return BR.Config.Get("defaults.petLabels", true)
            end,
            onChange = function(val)
                BR.Config.Set("defaults.petLabelScale", val)
            end,
        })
        petLabelScaleHolder:SetPoint("LEFT", petLabelsHolder, "LEFT", 90, 0)

        local function classColor(cls)
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            if c then
                return { c.r, c.g, c.b }
            end
            return { 0.5, 0.5, 0.5 }
        end

        local petClassBar, petClassButtons = Components.CreateSegmentedBar(petLabelsHolder, {
            toggleDefs = {
                {
                    key = "HUNTER",
                    label = "H",
                    tooltip = { title = L["Class.Hunter"] },
                    color = classColor("HUNTER"),
                },
                {
                    key = "WARLOCK",
                    label = "W",
                    tooltip = { title = L["Class.Warlock"] },
                    color = classColor("WARLOCK"),
                },
                {
                    key = "DEATHKNIGHT",
                    label = "D",
                    tooltip = { title = L["Class.DeathKnight"] },
                    color = classColor("DEATHKNIGHT"),
                },
                { key = "MAGE", label = "M", tooltip = { title = L["Class.Mage"] }, color = classColor("MAGE") },
            },
            getState = function(key)
                local vis = BR.profile.defaults.petLabelClasses
                return not vis or vis[key] ~= false
            end,
            setState = function(key)
                if not BR.profile.defaults.petLabelClasses then
                    BR.profile.defaults.petLabelClasses = {
                        HUNTER = true,
                        WARLOCK = true,
                        DEATHKNIGHT = true,
                        MAGE = true,
                    }
                end
                BR.profile.defaults.petLabelClasses[key] = not BR.profile.defaults.petLabelClasses[key]
            end,
            onChange = function()
                UpdateDisplay()
            end,
        })
        petClassBar:SetPoint("LEFT", petLabelScaleHolder, "RIGHT", 8, 0)

        local function isPetLabelsEnabled()
            return BR.Config.Get("defaults.petLabels", true)
        end
        petClassBar:SetBarDisabled(not isPetLabelsEnabled())

        local petClassBarRefreshHolder = CreateFrame("Frame", nil, petLabelsHolder)
        petClassBarRefreshHolder:SetSize(1, 1)
        function petClassBarRefreshHolder:Refresh()
            petClassBar:SetBarDisabled(not isPetLabelsEnabled())
            for _, btn in ipairs(petClassButtons) do
                btn.UpdateVisual()
            end
        end
        tinsert(BR.RefreshableComponents, petClassBarRefreshHolder)
    end

    -- Item display mode (consumable only)
    if category == "consumable" then
        local hideConsumableLabelsHolder = Components.Checkbox(catContent, {
            label = L["Options.HideConsumableLabels"],
            get = function()
                return BR.Config.Get("defaults.hideConsumableLabels", false)
            end,
            tooltip = {
                title = L["Options.HideConsumableLabels.Title"],
                desc = L["Options.HideConsumableLabels.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.hideConsumableLabels", checked)
            end,
        })
        catLayout:Add(hideConsumableLabelsHolder, nil, COMPONENT_GAP)

        local consumableTextScaleHolder = Components.Slider(catContent, {
            label = L["Options.ConsumableTextScale"],
            min = 5,
            max = 80,
            step = 1,
            suffix = "%",
            get = function()
                return BR.Config.Get("defaults.consumableTextScale", 25)
            end,
            tooltip = {
                title = L["Options.ConsumableTextScale.Title"],
                desc = L["Options.ConsumableTextScale.Desc"],
            },
            onChange = function(val)
                BR.Config.Set("defaults.consumableTextScale", val)
            end,
        })
        catLayout:Add(consumableTextScaleHolder, nil, COMPONENT_GAP)

        local updateDisplayModePreview
        local updateSubIconSideVisibility
        local displayModeHolder = Components.Dropdown(catContent, {
            label = L["Options.ItemDisplay"],
            get = function()
                return BR.Config.Get("defaults.consumableDisplayMode", "sub_icons")
            end,
            options = {
                {
                    value = "icon_only",
                    label = L["Options.ItemDisplay.IconOnly"],
                    desc = L["Options.ItemDisplay.IconOnlyDesc"],
                },
                {
                    value = "sub_icons",
                    label = L["Options.ItemDisplay.SubIcons"],
                    desc = L["Options.ItemDisplay.SubIconsDesc"],
                },
                {
                    value = "expanded",
                    label = L["Options.ItemDisplay.Expanded"],
                    desc = L["Options.ItemDisplay.ExpandedDesc"],
                },
            },
            tooltip = {
                title = L["Options.ItemDisplay.Mode"],
                desc = L["Options.ItemDisplay.Mode.Desc"],
            },
            onChange = function(val)
                BR.Config.Set("defaults.consumableDisplayMode", val)
                if updateDisplayModePreview then
                    updateDisplayModePreview(val)
                end
                if updateSubIconSideVisibility then
                    updateSubIconSideVisibility(val)
                end
            end,
        })
        catLayout:Add(displayModeHolder, nil, COMPONENT_GAP)

        local P_ICON = 24
        local P_SUB = 12
        local P_BORDER = 2
        local P_GAP = 3
        local P_STEP = P_ICON + P_GAP + P_BORDER * 2
        local P_SUB_STEP = P_SUB + P_BORDER * 2
        local TEX_FLASK = { 7548898, 7548899, 7548900 }
        local TEX_FOOD = { 4672193, 1045939 }
        local TEX_OIL = 7548987

        local previewHeight = P_ICON + P_SUB + P_GAP + P_BORDER * 2
        local MODE_ICON_COUNT = { icon_only = 3, sub_icons = 3, expanded = 6 }

        local previewHolder = CreateFrame("Frame", nil, catContent)
        previewHolder:SetSize(3 * P_STEP, previewHeight)
        previewHolder:SetPoint("TOPLEFT", displayModeHolder, "TOPRIGHT", 12, 0)

        local previewContainer = CreateFrame("Frame", nil, previewHolder)
        previewContainer:SetPoint("TOPLEFT", 0, 0)
        previewContainer:SetSize(6 * P_STEP, previewHeight)
        previewContainer:SetAlpha(0.7)

        local function CreatePreviewIcon(parentFrame, texture, size)
            local f = CreateFrame("Frame", nil, parentFrame)
            f:SetSize(size, size)
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetAllPoints()
            f.icon:SetTexture(texture)
            local z = TEXCOORD_INSET
            f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
            f.border = f:CreateTexture(nil, "BACKGROUND")
            f.border:SetColorTexture(0, 0, 0, 1)
            f.border:SetPoint("TOPLEFT", -P_BORDER, P_BORDER)
            f.border:SetPoint("BOTTOMRIGHT", P_BORDER, -P_BORDER)
            return f
        end

        local allPreviewFrames = {}

        local iconOnlyFrames = {}
        local iconOnlyTextures = { TEX_FLASK[1], TEX_FOOD[1], TEX_OIL }
        for i = 1, 3 do
            local f = CreatePreviewIcon(previewContainer, iconOnlyTextures[i], P_ICON)
            f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
            f:Hide()
            iconOnlyFrames[i] = f
            allPreviewFrames[#allPreviewFrames + 1] = f
        end

        local subIconsFrames = { mains = {}, subs = {} }
        local subVariants = { TEX_FLASK, TEX_FOOD, {} }
        for i, variants in ipairs(subVariants) do
            local mainTex = (#variants > 0) and variants[1] or TEX_OIL
            local main = CreatePreviewIcon(previewContainer, mainTex, P_ICON)
            main:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
            main:Hide()
            subIconsFrames.mains[i] = main
            allPreviewFrames[#allPreviewFrames + 1] = main
            if #variants > 1 then
                local subCount = #variants - 1
                local subRowWidth = (subCount - 1) * P_SUB_STEP + P_SUB
                local subOffsetX = (P_ICON - subRowWidth) / 2
                for j = 2, #variants do
                    local sub = CreatePreviewIcon(previewContainer, variants[j], P_SUB)
                    sub:SetPoint("TOPLEFT", main, "BOTTOMLEFT", subOffsetX + (j - 2) * P_SUB_STEP, -P_GAP)
                    sub:Hide()
                    subIconsFrames.subs[#subIconsFrames.subs + 1] = sub
                    allPreviewFrames[#allPreviewFrames + 1] = sub
                end
            end
        end

        local expandedFrames = {}
        local expandedTextures = {
            TEX_FLASK[1],
            TEX_FLASK[2],
            TEX_FLASK[3],
            TEX_FOOD[1],
            TEX_FOOD[2],
            TEX_OIL,
        }
        for i = 1, 6 do
            local f = CreatePreviewIcon(previewContainer, expandedTextures[i], P_ICON)
            f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
            f:Hide()
            expandedFrames[i] = f
            allPreviewFrames[#allPreviewFrames + 1] = f
        end

        local subIconsAll = {}
        for _, f in ipairs(subIconsFrames.mains) do
            subIconsAll[#subIconsAll + 1] = f
        end
        for _, f in ipairs(subIconsFrames.subs) do
            subIconsAll[#subIconsAll + 1] = f
        end

        local MODE_FRAMES = {
            icon_only = iconOnlyFrames,
            sub_icons = subIconsAll,
            expanded = expandedFrames,
        }
        updateDisplayModePreview = function(mode)
            for _, f in ipairs(allPreviewFrames) do
                f:Hide()
            end
            local shown = MODE_FRAMES[mode]
            if shown then
                for _, f in ipairs(shown) do
                    f:Show()
                end
            end
            previewHolder:SetWidth((MODE_ICON_COUNT[mode] or 3) * P_STEP)
        end

        updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

        function previewHolder:Refresh()
            updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))
        end
        tinsert(BR.RefreshableComponents, previewHolder)

        local subIconSideHolder = Components.Dropdown(catContent, {
            label = L["Options.SubIconSide"],
            labelWidth = 30,
            width = 85,
            get = function()
                local catSettings = db.categorySettings and db.categorySettings[category]
                return catSettings and catSettings.subIconSide or "BOTTOM"
            end,
            options = {
                { value = "BOTTOM", label = L["Options.SubIconSide.Bottom"] },
                { value = "TOP", label = L["Options.SubIconSide.Top"] },
                { value = "LEFT", label = L["Options.SubIconSide.Left"] },
                { value = "RIGHT", label = L["Options.SubIconSide.Right"] },
            },
            onChange = function(val)
                BR.Config.Set("categorySettings." .. category .. ".subIconSide", val)
            end,
        })
        subIconSideHolder:SetPoint("TOPLEFT", previewHolder, "TOPRIGHT", 12, 0)

        updateSubIconSideVisibility = function(mode)
            subIconSideHolder:SetShown(mode == "sub_icons")
        end
        updateSubIconSideVisibility(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

        catLayout:Space(SECTION_GAP)
        local behaviorHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        behaviorHeader:SetText("|cffffcc00" .. L["Options.Behavior"] .. "|r")
        catLayout:AddText(behaviorHeader, 12, COMPONENT_GAP)

        local showWithoutItemsHolder = Components.Checkbox(catContent, {
            label = L["Options.ShowWithoutItems"],
            get = function()
                return BR.Config.Get("defaults.showConsumablesWithoutItems", false) == true
            end,
            tooltip = {
                title = L["Options.ShowWithoutItems.Title"],
                desc = L["Options.ShowWithoutItems.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.showConsumablesWithoutItems", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(showWithoutItemsHolder, nil, COMPONENT_GAP)

        local SHOW_WITHOUT_INDENT = 12
        catLayout:SetX(catLayout:GetX() + SHOW_WITHOUT_INDENT)
        local readyCheckOnlyHolder = Components.Checkbox(catContent, {
            label = L["Options.ShowWithoutItemsReadyCheckOnly"],
            get = function()
                return BR.Config.Get("defaults.showWithoutItemsOnlyOnReadyCheck", false) == true
            end,
            enabled = function()
                return BR.Config.Get("defaults.showConsumablesWithoutItems", false) == true
            end,
            tooltip = {
                title = L["Options.ShowWithoutItemsReadyCheckOnly.Title"],
                desc = L["Options.ShowWithoutItemsReadyCheckOnly.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.showWithoutItemsOnlyOnReadyCheck", checked)
            end,
        })
        catLayout:Add(readyCheckOnlyHolder, nil, COMPONENT_GAP)
        catLayout:SetX(catLayout:GetX() - SHOW_WITHOUT_INDENT)

        local delveFoodOnlyHolder = Components.Checkbox(catContent, {
            label = L["Options.DelveFoodOnly"],
            get = function()
                return BR.Config.Get("defaults.delveFoodOnly", false) == true
            end,
            tooltip = {
                title = L["Options.DelveFoodOnly"],
                desc = L["Options.DelveFoodOnly.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.delveFoodOnly", checked)
            end,
        })
        catLayout:Add(delveFoodOnlyHolder, nil, COMPONENT_GAP)

        local hideLegacyHolder = Components.Checkbox(catContent, {
            label = L["Options.HideLegacyConsumables"],
            get = function()
                return BR.Config.Get("defaults.hideLegacyConsumables", true) ~= false
            end,
            tooltip = {
                title = L["Options.HideLegacyConsumables.Title"],
                desc = L["Options.HideLegacyConsumables.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.hideLegacyConsumables", checked)
            end,
        })
        catLayout:Add(hideLegacyHolder, nil, COMPONENT_GAP)
    end

    -- Layout sub-header
    catLayout:Space(SECTION_GAP)
    local layoutHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutHeader:SetText("|cffffcc00" .. L["Options.Layout"] .. "|r")
    catLayout:AddText(layoutHeader, 12, COMPONENT_GAP)

    local priorityHolder = Components.Slider(catContent, {
        label = L["Options.Priority"],
        min = 1,
        max = 7,
        step = 1,
        get = function()
            local cs = db.categorySettings and db.categorySettings[category]
            return cs and cs.priority or defaults.categorySettings[category].priority
        end,
        enabled = function()
            return not IsCategorySplit(category)
        end,
        tooltip = {
            title = L["Options.DisplayPriority"],
            desc = L["Options.Priority.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("categorySettings." .. category .. ".priority", val)
        end,
    })
    catLayout:Add(priorityHolder, nil, COMPONENT_GAP)

    local splitHolder = Components.Checkbox(catContent, {
        label = L["Options.SplitFrame"],
        get = function()
            return IsCategorySplit(category)
        end,
        tooltip = {
            title = L["Options.SplitFrame"],
            desc = L["Options.SplitFrame.Desc"],
        },
        onChange = function(checked)
            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings[category] then
                db.categorySettings[category] = {}
            end
            db.categorySettings[category].split = checked
            ReparentBuffFrames()
            UpdateVisuals()
        end,
    })
    catLayout:Add(splitHolder, nil, COMPONENT_GAP)

    local resetBtn = CreateButton(catContent, L["Options.ResetPosition"], function()
        local catDefaults = defaults.categorySettings[category]
        if catDefaults and catDefaults.position then
            ResetCategoryFramePosition(category, catDefaults.position.x, catDefaults.position.y)
        end
    end)
    resetBtn:SetPoint("LEFT", splitHolder, "RIGHT", 10, 0)
    resetBtn:SetEnabled(IsCategorySplit(category))

    local origSplitClick = splitHolder.checkbox:GetScript("OnClick")
    splitHolder.checkbox:SetScript("OnClick", function(self)
        if origSplitClick then
            origSplitClick(self)
        end
        resetBtn:SetEnabled(IsCategorySplit(category))
        Components.RefreshAll()
    end)

    -- Shared enabled predicates for this category
    local function isCustomAppearanceEnabled()
        return db.categorySettings
            and db.categorySettings[category]
            and db.categorySettings[category].useCustomAppearance == true
    end

    local function isCustomGlowEnabled()
        return isCustomAppearanceEnabled() and db.categorySettings[category].useCustomGlow == true
    end

    local function SnapshotGlowDefaults()
        local cs = db.categorySettings[category]
        local glowDefaults = db.defaults or {}
        local glowSnapshotKeys = {
            "glowType",
            "glowSize",
            "glowPixelLines",
            "glowPixelFrequency",
            "glowPixelLength",
            "glowAutocastParticles",
            "glowAutocastFrequency",
            "glowAutocastScale",
            "glowBorderFrequency",
            "glowProcDuration",
            "glowProcStartAnim",
            "glowProcUseCustomColor",
            "glowXOffset",
            "glowYOffset",
            "missingGlowType",
            "missingGlowSize",
            "missingGlowPixelLines",
            "missingGlowPixelFrequency",
            "missingGlowPixelLength",
            "missingGlowAutocastParticles",
            "missingGlowAutocastFrequency",
            "missingGlowAutocastScale",
            "missingGlowBorderFrequency",
            "missingGlowProcDuration",
            "missingGlowProcStartAnim",
            "missingGlowProcUseCustomColor",
            "missingGlowXOffset",
            "missingGlowYOffset",
        }
        for _, key in ipairs(glowSnapshotKeys) do
            if cs[key] == nil and glowDefaults[key] ~= nil then
                cs[key] = glowDefaults[key]
            end
        end
        for _, colorKey in ipairs({ "glowColor", "missingGlowColor" }) do
            if cs[colorKey] == nil and glowDefaults[colorKey] then
                local gc = glowDefaults[colorKey]
                cs[colorKey] = { gc[1], gc[2], gc[3], gc[4] }
            end
        end
    end

    catLayout:SetX(0)
    local useCustomAppHolder = Components.Checkbox(catContent, {
        label = L["Options.CustomAppearance"],
        get = function()
            return db.categorySettings
                and db.categorySettings[category]
                and db.categorySettings[category].useCustomAppearance == true
        end,
        tooltip = {
            title = L["Options.CustomAppearance"],
            desc = L["Options.CustomAppearance.Desc"],
        },
        onChange = function(checked)
            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings[category] then
                db.categorySettings[category] = {}
            end
            if checked then
                local effective = GetCategorySettings(category)
                local cs = db.categorySettings[category]
                local appearanceKeys = {
                    "iconSize",
                    "iconWidth",
                    "textSize",
                    "spacing",
                    "iconZoom",
                    "borderSize",
                    "iconAlpha",
                    "textAlpha",
                    "growDirection",
                }
                for _, key in ipairs(appearanceKeys) do
                    if cs[key] == nil and effective[key] ~= nil then
                        cs[key] = effective[key]
                    end
                end
                if cs.textColor == nil and effective.textColor then
                    local tc = effective.textColor
                    cs.textColor = { tc[1], tc[2], tc[3] }
                end
            end
            BR.Config.Set("categorySettings." .. category .. ".useCustomAppearance", checked)
            Components.RefreshAll()
        end,
    })
    catLayout:Add(useCustomAppHolder, nil, COMPONENT_GAP)

    local baseContentY = catLayout:GetY()

    catLayout:SetX(10)
    local dirHolder = Components.DirectionButtons(catContent, {
        get = function()
            local catSettings = db.categorySettings and db.categorySettings[category]
            local val = catSettings and catSettings.growDirection
            if val ~= nil then
                return val
            end
            return db.defaults and db.defaults.growDirection or "CENTER"
        end,
        enabled = function()
            return isCustomAppearanceEnabled() and IsCategorySplit(category)
        end,
        onChange = function(dir)
            BR.Config.Set("categorySettings." .. category .. ".growDirection", dir)
        end,
    })
    catLayout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    -- Read the category's own saved value, falling back to defaults only if no value was saved.
    -- This avoids showing inherited defaults when useCustomAppearance is off, so toggling
    -- custom appearance off/on preserves the user's previously configured values.
    local function getCatOwnValue(key, default)
        local catSettings = db.categorySettings and db.categorySettings[category]
        local val = catSettings and catSettings[key]
        if val ~= nil then
            return val
        end
        return db.defaults and db.defaults[key] or default
    end

    local function isCatDimensionsLinked()
        local cs = db.categorySettings and db.categorySettings[category]
        return not cs or cs.iconWidth == nil
    end

    catLayout:SetX(10)
    local appFrame = CreateFrame("Frame", nil, catContent)
    appFrame:SetSize(480, 50)
    catLayout:Add(appFrame, 0)

    local catGrid = Components.AppearanceGrid(appFrame, {
        get = getCatOwnValue,
        set = function(key, value)
            BR.Config.Set("categorySettings." .. category .. "." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["categorySettings." .. category .. "." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isCatDimensionsLinked,
        onLink = function()
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local size = getCatOwnValue("iconSize", 64)
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
            Components.RefreshAll()
        end,
        enabled = isCustomAppearanceEnabled,
        masqueCheck = IsMasqueActive,
    })

    -- Glow settings (positioned after appearance grid)
    local glowRowY = -catGrid.height
    local gridHeight
    if category == "pet" then
        local catPetGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.GlowMissingPets"],
            get = function()
                return getCatOwnValue("showMissingGlow", true) ~= false
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        catPetGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local catPetCustomGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    SnapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        catPetCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local catPetGlowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Modals.Glow.Show(category, "missing")
        end)
        catPetGlowSettingsBtn:SetPoint("LEFT", catPetCustomGlowHolder.label, "RIGHT", 8, 0)
        catPetGlowSettingsBtn:SetFrameLevel(catPetCustomGlowHolder:GetFrameLevel() + 5)

        local function updatePetGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                catPetGlowSettingsBtn:Enable()
                catPetGlowSettingsBtn:SetAlpha(1)
            else
                catPetGlowSettingsBtn:Disable()
                catPetGlowSettingsBtn:SetAlpha(0.4)
            end
        end
        updatePetGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updatePetGlowBtnEnabled })

        gridHeight = catGrid.height + 48
    elseif category == "custom" then
        local catCustomMissGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.Glow"],
            get = function()
                return getCatOwnValue("showMissingGlow", true) ~= false
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        catCustomMissGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local catCustomGlowStyleHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    SnapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        catCustomGlowStyleHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local catCustomGlowBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Modals.Glow.Show(category)
        end)
        catCustomGlowBtn:SetPoint("LEFT", catCustomGlowStyleHolder.label, "RIGHT", 8, 0)
        catCustomGlowBtn:SetFrameLevel(catCustomGlowStyleHolder:GetFrameLevel() + 5)

        local function updateCustomGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                catCustomGlowBtn:Enable()
                catCustomGlowBtn:SetAlpha(1)
            else
                catCustomGlowBtn:Disable()
                catCustomGlowBtn:SetAlpha(0.4)
            end
        end
        updateCustomGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updateCustomGlowBtnEnabled })

        gridHeight = catGrid.height + 48
    else
        local catThresholdHolder = Components.Slider(appFrame, {
            label = L["Options.Expiration"],
            labelWidth = 56,
            min = 0,
            max = 45,
            step = 5,
            formatValue = function(val)
                return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
            end,
            get = function()
                return getCatOwnValue("expirationThreshold", 15)
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(val)
                BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", val)
            end,
        })
        catThresholdHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local catGlowCheckHolder = Components.Checkbox(appFrame, {
            label = L["Options.Glow"],
            get = function()
                local ex = getCatOwnValue("showExpirationGlow", true) ~= false
                local miss = getCatOwnValue("showMissingGlow", true) ~= false
                return ex or miss
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showExpirationGlow", checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        catGlowCheckHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local catCustomGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    SnapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        catCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 48)

        local catGlowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Modals.Glow.Show(category)
        end)
        catGlowSettingsBtn:SetPoint("LEFT", catCustomGlowHolder.label, "RIGHT", 8, 0)
        catGlowSettingsBtn:SetFrameLevel(catCustomGlowHolder:GetFrameLevel() + 5)

        local function updateGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                catGlowSettingsBtn:Enable()
                catGlowSettingsBtn:SetAlpha(1)
            else
                catGlowSettingsBtn:Disable()
                catGlowSettingsBtn:SetAlpha(0.4)
            end
        end
        updateGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updateGlowBtnEnabled })

        gridHeight = catGrid.height + 72
    end

    catLayout:Space(gridHeight)
    catLayout:SetX(0)

    local fullContentHeight = abs(catLayout:GetY()) + 10
    local baseContentHeight = abs(baseContentY) + 10

    local UpdateCustomAppearanceVisibility = function()
        local show = isCustomAppearanceEnabled()
        if show then
            dirHolder:Show()
            appFrame:Show()
            section:SetContentHeight(fullContentHeight)
        else
            dirHolder:Hide()
            appFrame:Hide()
            section:SetContentHeight(baseContentHeight)
        end
        C_Timer.After(0, UpdateAppearanceContentHeight)
    end

    tinsert(BR.RefreshableComponents, { Refresh = UpdateCustomAppearanceVisibility })

    if isCustomAppearanceEnabled() then
        section:SetContentHeight(fullContentHeight)
    else
        dirHolder:Hide()
        appFrame:Hide()
        section:SetContentHeight(baseContentHeight)
    end
    tinsert(categorySections, section)

    return section
end

BR.Options.Tabs.DisplayBehavior = BR.Options.Tabs.DisplayBehavior or {}
BR.Options.Tabs.DisplayBehavior.RenderCategorySection = RenderCategorySection
