local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local petSummonModal = nil

local function Show()
    if petSummonModal then
        Components.RefreshAll()
        petSummonModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersPetSummonModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.PetSummonSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local felDomHolder = Components.Checkbox(modal, {
        label = L["Options.FelDomination"],
        get = function()
            return BR.Config.Get("defaults.useFelDomination", false)
        end,
        tooltip = {
            title = L["Options.FelDomination.Title"],
            desc = L["Options.FelDomination.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.useFelDomination", checked)
        end,
    })
    layout:Add(felDomHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    petSummonModal = modal
    modal:Show()
end

BR.Options.Modals.PetSummon = { Show = Show }
