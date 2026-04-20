local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local delveFoodModal = nil

local function Show()
    if delveFoodModal then
        Components.RefreshAll()
        delveFoodModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersDelveFoodModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.DelveFoodSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local timerHolder = Components.Checkbox(modal, {
        label = L["Options.DelveFoodTimer"],
        get = function()
            return BR.Config.Get("defaults.delveFoodTimer", false) == true
        end,
        tooltip = {
            title = L["Options.DelveFoodTimer"],
            desc = L["Options.DelveFoodTimer.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.delveFoodTimer", checked)
        end,
    })
    layout:Add(timerHolder, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    delveFoodModal = modal
    modal:Show()
end

BR.Options.Modals.DelveFood = { Show = Show }
