local elements = {}
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local checkbuttons = {}
local fontstrings = {}
local cost = {
    [0] = 0,
    [1] = 1250,
    [2] = 2000,
    [3] = 3200,
    [4] = 5150
}
local ilvls = {
    [0] = 0,
    [1] = 190,
    [2] = 210,
    [3] = 225,
    [4] = 235
}
local from = 0

WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(480,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -30);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    scrframe:SetScript("OnHide",function()

    end)
    add(scrframe)

    for i = 0, #ilvls - 1 do
        local myCheckButton = CreateFrame("CheckButton", "WeekKeys_FromButton"..i, scrframe, "UIRadioButtonTemplate");
        myCheckButton.id = i
        myCheckButton:SetPoint("TOPLEFT", 10, -55-i*20);
        _G["WeekKeys_FromButton"..i.."Text"]:SetText(ilvls[i]);
        myCheckButton:SetScript("OnClick",function(self)
            for _,b in pairs(checkbuttons) do
                b:SetChecked(false)
            end
            self:SetChecked(true) 
            from = self.id
            local quantity = C_CurrencyInfo.GetCurrencyInfo(1828).quantity
            for a,b in pairs(fontstrings) do
                if a <= from then
                    b:Hide()
                elseif quantity >= cost[a] - cost[from] then
                    b:SetFormattedText("(%d -> %d) |cff00ff00 %d |T3743738:0|t",ilvls[from],ilvls[a],cost[a] - cost[from]) 
                    b:Show()
                else
                    b:SetFormattedText("(%d -> %d) |cffffffff %d |T3743738:0|t",ilvls[from],ilvls[a],cost[a] - cost[from]) 
                    b:Show()
                end
            end

        end);
        checkbuttons[#checkbuttons + 1] = myCheckButton
        add(myCheckButton)
    end

    for i = 1, #ilvls do
        local myCheckButton = scrframe:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        myCheckButton.id = i
        myCheckButton:SetPoint("TOPLEFT", 100, -35-i*20);
        fontstrings[#fontstrings + 1] = myCheckButton
        add(myCheckButton)
    end

    local fontstr = scrframe:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 20,-20)
    fontstr:SetText(L["choose ilvls"])
    add(fontstr)
    --[[
    local fontstr2 = scrframe:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr2:SetPoint("TOPLEFT", 20,-20*(#ilvls+4))
    fontstr2:SetText(COSTS_LABEL.."|cffffffff 0 |T3743738:0|t") --print("|T3743738:0|t") 
    add(fontstr2)
    

    --]]
    WeekKeys.AddButton(L["Ash calculator"],elements)
end)
