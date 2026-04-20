local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local Glow = BR.Glow
local GlowTypes = Glow.Types

local TEXCOORD_INSET = BR.TEXCOORD_INSET
local DEFAULT_BORDER_SIZE = BR.DEFAULT_BORDER_SIZE
local GetBuffTexture = BR.Helpers.GetBuffTexture

local glowAdvancedPanel = nil

---@param targetCategory? string nil = global defaults, string = per-category override
---@param glowKind? "expiring"|"missing" Which glow style to edit (default "expiring")
local function Show(targetCategory, glowKind)
    glowKind = glowKind or "expiring"
    local GlowType = Glow.Type

    if glowAdvancedPanel then
        glowAdvancedPanel:Hide()
        glowAdvancedPanel = nil
    end

    -- Key prefix: "glow" for expiring, "missingGlow" for missing
    local keyPrefix = glowKind == "missing" and "missingGlow" or "glow"
    ---@param suffix string e.g. "Type" → "glowType" or "missingGlowType"
    local function K(suffix)
        return keyPrefix .. suffix
    end

    local configPrefix = targetCategory and ("categorySettings." .. targetCategory .. ".") or "defaults."
    local function getSource()
        if targetCategory then
            return (BR.profile.categorySettings and BR.profile.categorySettings[targetCategory]) or {}
        else
            return BR.profile.defaults or {}
        end
    end

    local PANEL_W = 440
    local PANEL_H = 460
    local PREVIEW_SIZE = 64
    local MARGIN = 20

    local panel = CreatePanel("BuffRemindersGlowAdvanced", PANEL_W, PANEL_H, {
        strata = "FULLSCREEN",
        modal = true,
    })

    local titleBase = glowKind == "missing" and L["Options.GlowSettings.Missing"] or L["Options.GlowSettings.Expiring"]
    local titleText = targetCategory
            and (titleBase .. " — " .. targetCategory:sub(1, 1):upper() .. targetCategory:sub(2))
        or titleBase
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffcc00" .. titleText .. "|r")

    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    -- Expiring / Missing tab toggle
    local expiringTab = Components.Tab(panel, { label = L["Options.GlowKind.Expiring"] })
    expiringTab:SetPoint("TOPLEFT", MARGIN, -32)
    expiringTab:SetActive(glowKind == "expiring")
    expiringTab:SetScript("OnClick", function()
        Show(targetCategory, "expiring")
    end)

    local missingTab = Components.Tab(panel, { label = L["Options.GlowKind.Missing"] })
    missingTab:SetPoint("LEFT", expiringTab, "RIGHT", 4, 0)
    missingTab:SetActive(glowKind == "missing")
    missingTab:SetScript("OnClick", function()
        Show(targetCategory, "missing")
    end)

    local previewKey = "BR_adv_preview"

    -- Content area
    local dynamicHolders = {}
    local staticLayout = Components.VerticalLayout(panel, { x = MARGIN, y = -56 })

    -- Enabled checkbox (per-kind enable/disable)
    local enableKey = glowKind == "missing" and "showMissingGlow" or "showExpirationGlow"
    local enableHolder = Components.Checkbox(panel, {
        label = L["Options.Glow.Enabled"],
        get = function()
            return getSource()[enableKey] ~= false
        end,
        onChange = function(checked)
            BR.Config.Set(configPrefix .. enableKey, checked)
            Components.RefreshAll()
        end,
    })
    staticLayout:Add(enableHolder, 24, 2)

    -- Type dropdown (always visible, top-left beside preview)
    local typeFallback = glowKind == "missing" and GlowType.Pixel or GlowType.AutoCast
    local typeOptions = {}
    for i, gt in ipairs(GlowTypes) do
        typeOptions[i] = { label = gt.name, value = i }
    end

    local typeHolder = Components.Dropdown(panel, {
        label = L["Options.Glow.Type"],
        labelWidth = 40,
        options = typeOptions,
        get = function()
            return getSource()[K("Type")] or typeFallback
        end,
        width = 140,
        onChange = function(val)
            BR.Config.Set(configPrefix .. K("Type"), val)
        end,
    }, "BuffRemindersGlowAdvTypeDropdown")
    staticLayout:Add(typeHolder, 30, 4)

    -- Separator
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", MARGIN, staticLayout:GetY())
    sep:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    staticLayout:Space(10)

    local DYNAMIC_START_Y = staticLayout:GetY()

    -- Preview icon (below separator, top-right)
    local previewFrame = CreateFrame("Frame", nil, panel)
    previewFrame:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(MARGIN + 20), DYNAMIC_START_Y)

    local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    previewIcon:SetTexture(GetBuffTexture(1459))

    local previewBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBorder:SetPoint("TOPLEFT", -DEFAULT_BORDER_SIZE, DEFAULT_BORDER_SIZE)
    previewBorder:SetPoint("BOTTOMRIGHT", DEFAULT_BORDER_SIZE, -DEFAULT_BORDER_SIZE)
    previewBorder:SetColorTexture(0, 0, 0, 1)

    local function RefreshPreview()
        Glow.StopAll(previewFrame, previewKey)
        local d = getSource()
        local typeIdx = d[K("Type")] or typeFallback
        local color = d[K("Color")]
        if typeIdx == GlowType.Proc and not d[K("ProcUseCustomColor")] then
            color = nil
        end
        local size = d[K("Size")] or 2
        local params = Glow.BuildAdvancedParams(d, typeIdx, keyPrefix)
        local xOff = DEFAULT_BORDER_SIZE + (d[K("XOffset")] or 0)
        local yOff = DEFAULT_BORDER_SIZE + (d[K("YOffset")] or 0)
        Glow.Start(previewFrame, typeIdx, color, previewKey, size, xOff, yOff, params)
    end

    local SLIDER_SPACING = 24
    local dynamicLayout

    local function AddSlider(config)
        local holder = Components.Slider(panel, config)
        holder:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    local function AddCheckbox(config)
        local holder = Components.Checkbox(panel, config)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    -- Reset keys per glow type (type-specific only)
    local typeResetKeys = {
        [GlowType.Pixel] = { K("PixelLines"), K("PixelFrequency"), K("PixelLength") },
        [GlowType.AutoCast] = { K("AutocastScale"), K("AutocastParticles"), K("AutocastFrequency") },
        [GlowType.Border] = { K("BorderFrequency") },
        [GlowType.Proc] = { K("ProcDuration"), K("ProcStartAnim"), K("ProcUseCustomColor") },
    }

    local function UnregisterDynamicHolders()
        for _, h in ipairs(dynamicHolders) do
            h:Hide()
            Components.Unregister(h)
        end
    end

    local function BuildTypeContent()
        -- Hide and unregister old dynamic components
        UnregisterDynamicHolders()
        wipe(dynamicHolders)
        dynamicLayout = Components.VerticalLayout(panel, { x = MARGIN, y = DYNAMIC_START_Y })

        local d = getSource()
        local typeIdx = d[K("Type")] or typeFallback

        -- Size + Color row
        local sizeHolder
        if typeIdx == GlowType.Pixel or typeIdx == GlowType.Border then
            sizeHolder = Components.NumericStepper(panel, {
                label = L["Options.Glow.Size"],
                labelWidth = 34,
                min = 1,
                max = 10,
                step = 1,
                get = function()
                    return getSource()[K("Size")] or 2
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("Size"), val)
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, sizeHolder)
        end

        local colorSwatchHolder
        local procColorCheckbox
        if typeIdx == GlowType.Proc then
            -- Proc: optional custom color (desaturated + vertex color, less vibrant than default)
            procColorCheckbox = Components.Checkbox(panel, {
                label = L["Options.UseCustomColor"],
                tooltip = {
                    title = L["Options.UseCustomColor"],
                    desc = L["Options.UseCustomColor.Desc"],
                },
                get = function()
                    return getSource()[K("ProcUseCustomColor")] or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. K("ProcUseCustomColor"), checked)
                    Components.RefreshAll()
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, procColorCheckbox)

            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                enabled = function()
                    return getSource()[K("ProcUseCustomColor")] or false
                end,
                get = function()
                    local c = getSource()[K("Color")] or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. K("Color"), { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        else
            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                get = function()
                    local c = getSource()[K("Color")] or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. K("Color"), { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        end

        if sizeHolder and colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(sizeHolder, 26)
            colorSwatchHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 8, 0)
        elseif sizeHolder then
            dynamicLayout:Add(sizeHolder, 26)
        elseif colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(colorSwatchHolder, 26)
        end

        if procColorCheckbox then
            dynamicLayout:Add(procColorCheckbox, SLIDER_SPACING)
            colorSwatchHolder:SetPoint("LEFT", procColorCheckbox, "RIGHT", 8, 0)
        end

        -- Type-specific parameters
        if typeIdx == GlowType.Pixel then
            -- Pixel
            AddSlider({
                label = L["Options.Glow.Lines"],
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource()[K("PixelLines")] or 8
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelLines"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Frequency"],
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource()[K("PixelFrequency")] or 0.25
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelFrequency"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Length"],
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource()[K("PixelLength")] or 10
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelLength"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.AutoCast then
            -- AutoCast
            AddSlider({
                label = L["Options.Glow.Scale"],
                min = 1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource()[K("AutocastScale")] or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastScale"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Particles"],
                min = 1,
                max = 8,
                step = 1,
                get = function()
                    return getSource()[K("AutocastParticles")] or 4
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastParticles"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Frequency"],
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource()[K("AutocastFrequency")] or 0.125
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastFrequency"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Border then
            -- Border
            AddSlider({
                label = L["Options.Glow.Speed"],
                min = 0.1,
                max = 2,
                step = 0.1,
                get = function()
                    return getSource()[K("BorderFrequency")] or 0.6
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("BorderFrequency"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Proc then
            -- Proc
            AddSlider({
                label = L["Options.Glow.Duration"],
                min = 0.1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource()[K("ProcDuration")] or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("ProcDuration"), val)
                    RefreshPreview()
                end,
            })
            AddCheckbox({
                label = L["Options.Glow.StartAnimation"],
                get = function()
                    return getSource()[K("ProcStartAnim")] or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. K("ProcStartAnim"), checked)
                    RefreshPreview()
                end,
            })
        end

        -- Offsets
        AddSlider({
            label = L["Options.Glow.XOffset"],
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource()[K("XOffset")] or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. K("XOffset"), val)
                RefreshPreview()
            end,
        })
        AddSlider({
            label = L["Options.Glow.YOffset"],
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource()[K("YOffset")] or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. K("YOffset"), val)
                RefreshPreview()
            end,
        })

        -- Reset button (resets current type's params + shared keys)
        dynamicLayout:Space(8)
        local resetBtn = CreateButton(panel, L["Options.ResetToDefaults"], function()
            local keys = { K("Color"), K("Size"), K("XOffset"), K("YOffset") }
            local typeKeys = typeResetKeys[typeIdx]
            if typeKeys then
                for _, k in ipairs(typeKeys) do
                    keys[#keys + 1] = k
                end
            end
            for _, key in ipairs(keys) do
                BR.Config.Set(configPrefix .. key, nil)
            end
            BuildTypeContent()
            RefreshPreview()
            Components.RefreshAll()
        end)
        resetBtn:SetSize(140, 24)
        dynamicLayout:Add(resetBtn, 24)
        table.insert(dynamicHolders, resetBtn)

        -- Adjust panel height
        panel:SetHeight(math.abs(dynamicLayout:GetY()) + 46)

        RefreshPreview()
    end

    BuildTypeContent()

    -- Subscribe to glow type changes to rebuild type-specific content
    local function OnSettingChanged(_, path)
        if path == configPrefix .. K("Type") then
            BuildTypeContent()
        end
    end
    BR.CallbackRegistry:RegisterCallback("SettingChanged", OnSettingChanged, panel)

    panel:SetScript("OnHide", function()
        Glow.StopAll(previewFrame, previewKey)
        BR.CallbackRegistry:UnregisterCallback("SettingChanged", panel)
        UnregisterDynamicHolders()
    end)

    glowAdvancedPanel = panel
end

BR.Options.Modals.Glow = { Show = Show }
