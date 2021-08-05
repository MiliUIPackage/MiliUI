local elements = {}
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local querytable = {}
local buttons = {}

local function update()

    WeekKeys.DB.GetTorghast(WeekKeysDB.Characters,querytable)
    if #querytable == 0 then return end
    while #buttons < #querytable[1] do
        buttons[#buttons+1] = WeekKeys.UI.ThorgastButton(nil,buttons[#buttons] or elements[1])
    end
    for i = 1,#buttons do
        buttons[i]:SetFaction(querytable[1][i])
        buttons[i]:SetName(querytable[2][i])
        buttons[i]:SetRecords(querytable[3][i],querytable[4][i])
    end
end

WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(480,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        update()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -60);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    scrframe:SetScript("OnHide",function()

    end)

    add(scrframe)
    local fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 20,-40)
    fontstr:SetText(CHARACTER_NAME_PROMPT)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 180,-40)
    add(fontstr)
    if C_AreaPoiInfo.GetAreaPOIInfo(1543, 6640) then
        fontstr:SetText(C_AreaPoiInfo.GetAreaPOIInfo(1543, 6640).name or "")
    else
        fontstr:SetText(L["Torghast, Tower of the Damned"])
    end

    WeekKeys.AddButton(L["torghast"],elements)
end)
