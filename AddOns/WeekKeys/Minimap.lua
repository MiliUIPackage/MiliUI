
WeekKeys.icon = LibStub("LibDBIcon-1.0")

WeekKeys.icon.minimap_data = LibStub("LibDataBroker-1.1"):NewDataObject("WeekKeys", {
    type = "data source",
    text = "0",
    icon = "interface/worldmap/treasurechest_64.blp",
    HotCornerIgnore = true,
    OnClick = function()
        WeekKeys.WeekFrame = WeekKeys.WeekFrame or WeekKeys.Create()
        WeekKeys.WeekFrame:SetShown(not WeekKeys.WeekFrame:IsShown())
    end,
    OnTooltipShow = function (tooltip)
        tooltip:AddLine (WeekKeys.L["WeekKeys"])
    end,
})
