local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local petPassiveModal = nil

local function Show()
    if petPassiveModal then
        Components.RefreshAll()
        petPassiveModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersPetPassiveModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.PetPassiveSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local passiveCombatHolder = Components.Checkbox(modal, {
        label = L["Options.PetPassiveCombat"],
        get = function()
            return BR.profile.petPassiveOnlyInCombat == true
        end,
        tooltip = {
            title = L["Options.PetPassiveCombat"],
            desc = L["Options.PetPassiveCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("petPassiveOnlyInCombat", checked)
        end,
    })
    layout:Add(passiveCombatHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    petPassiveModal = modal
    modal:Show()
end

BR.Options.Modals.PetPassive = { Show = Show }
