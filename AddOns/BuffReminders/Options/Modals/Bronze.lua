local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local bronzeModal = nil

local function Show()
    if bronzeModal then
        Components.RefreshAll()
        bronzeModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersBronzeModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.BronzeSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local hideInCombatHolder = Components.Checkbox(modal, {
        label = L["Options.BronzeHideInCombat"],
        get = function()
            return BR.profile.bronzeHideInCombat == true
        end,
        tooltip = {
            title = L["Options.BronzeHideInCombat"],
            desc = L["Options.BronzeHideInCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("bronzeHideInCombat", checked)
        end,
    })
    layout:Add(hideInCombatHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    bronzeModal = modal
    modal:Show()
end

BR.Options.Modals.Bronze = { Show = Show }
