WeekKeys.Commands = {}

function WeekKeys.Commands.hide()
    WeekKeys.icon:Hide("WeekKeys")
    WeekKeys.db.global.minimap.hide = true
end
function WeekKeys.Commands.show()
    WeekKeys.icon:Show("WeekKeys")
    WeekKeys.db.global.minimap.hide = false
end

SLASH_WK1 = '/wk'
function SlashCmdList.WK(msg, _)
    if msg == "" then
        WeekKeys.WeekFrame = WeekKeys.WeekFrame or WeekKeys.Create()
        WeekKeys.WeekFrame:SetShown(not WeekKeys.WeekFrame:IsShown())
    else
        if WeekKeys.Commands[string.lower(msg)] then
            WeekKeys.Commands[string.lower(msg)]()
        end
    end
end
