local _, addon = ...;

addon.Options.Defaults = {
    profile = {
        ShowMinimapIcon = false,
        NumRows = 5,
        NumColumns = 4,
        Direction = addon.L["Columns first"],
        Minimap = {
            hide = true -- not ShowMinimapIcon
        },
        ShowOptionsButton = true,
        ShowHideOption = true
    }
};