local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local healthstoneModal = nil

local function Show()
    if healthstoneModal then
        Components.RefreshAll()
        healthstoneModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersHealthstoneModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.HealthstoneSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local visHolder = Components.Dropdown(modal, {
        label = L["Options.Visibility"],
        width = 200,
        get = function()
            return BR.Config.Get("defaults.healthstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Healthstone.ReadyCheckOnly"],
                desc = L["Options.Healthstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Healthstone.ReadyCheckWarlock"],
                desc = L["Options.Healthstone.WarlockAlwaysDesc"],
            },
            {
                value = "always",
                label = L["Options.Healthstone.AlwaysShow"],
                desc = L["Options.Healthstone.AlwaysDesc"],
            },
        },
        tooltip = { title = L["Options.Healthstone.Visibility"], desc = L["Options.Healthstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local lowStockHolder = Components.Checkbox(modal, {
        label = L["Options.Healthstone.LowStock"],
        get = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = {
            title = L["Options.Healthstone.LowStock"],
            desc = L["Options.Healthstone.LowStock.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.healthstoneLowStock", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(lowStockHolder, nil, COMPONENT_GAP)

    local thresholdHolder = Components.Slider(modal, {
        label = L["Options.Healthstone.Threshold"],
        min = 1,
        max = 2,
        step = 1,
        get = function()
            return BR.Config.Get("defaults.healthstoneThreshold", 1)
        end,
        enabled = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = { title = L["Options.Healthstone.Threshold"], desc = L["Options.Healthstone.Threshold.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneThreshold", val)
        end,
    })
    layout:Add(thresholdHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    healthstoneModal = modal
    modal:Show()
end

BR.Options.Modals.Healthstone = { Show = Show }
