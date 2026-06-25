local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.DruidForm = BR.Options.Helpers.SingletonDialog(function()
    local travelIcon = C_Spell.GetSpellTexture(783) -- Travel Form
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersDruidFormDialog", "Options.DruidFormSettings", {
        icon = travelIcon,
    })
    local dialog, layout = shell.dialog, shell.layout

    local ignoreTravelHolder = Components.Checkbox(dialog, {
        label = L["Options.DruidIgnoreTravelForm"],
        get = function()
            return BR.profile.druidIgnoreTravelForm ~= false
        end,
        tooltip = {
            title = L["Options.DruidIgnoreTravelForm"],
            desc = L["Options.DruidIgnoreTravelForm.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("druidIgnoreTravelForm", checked)
        end,
    })
    layout:Add(ignoreTravelHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
