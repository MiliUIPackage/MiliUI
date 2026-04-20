local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local soulstoneModal = nil

local function Show()
    if soulstoneModal then
        Components.RefreshAll()
        soulstoneModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersSoulstoneModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.SoulstoneSettings"])

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
            return BR.Config.Get("defaults.soulstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Soulstone.ReadyCheckOnly"],
                desc = L["Options.Soulstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Soulstone.ReadyCheckWarlock"],
                desc = L["Options.Soulstone.WarlockAlwaysDesc"],
            },
            { value = "always", label = L["Options.Soulstone.AlwaysShow"], desc = L["Options.Soulstone.AlwaysDesc"] },
        },
        tooltip = { title = L["Options.Soulstone.Visibility"], desc = L["Options.Soulstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.soulstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local cdHolder = Components.Checkbox(modal, {
        label = L["Options.Soulstone.HideCooldown"],
        get = function()
            return BR.Config.Get("defaults.soulstoneHideCooldown", false)
        end,
        tooltip = {
            title = L["Options.Soulstone.HideCooldown"],
            desc = L["Options.Soulstone.HideCooldown.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.soulstoneHideCooldown", checked)
        end,
    })
    layout:Add(cdHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    soulstoneModal = modal
    modal:Show()
end

BR.Options.Modals.Soulstone = { Show = Show }
