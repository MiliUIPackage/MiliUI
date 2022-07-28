local elements = {}

WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    elements[1] = scrframe
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(480,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()

        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -60);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);

        for i = 3, 10 do
            local _, _, comp = GetAchievementCriteriaInfo(14531,i-2)
            if comp then
                elements[i]:SetTextColor(0,1,0)
            else
                elements[i]:SetTextColor(1,0,0)
            end
        end
        for i = 12, 19 do
            local _,_ , comp = GetAchievementCriteriaInfo(14532,i-11)
            if comp then
                elements[i]:SetTextColor(0,1,0)
            else
                elements[i]:SetTextColor(1,0,0)
            end
        end
    end)
    local btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetSize(200,40)
    btn:SetPoint("Topleft",20,-40)
    local _ ,name = GetAchievementInfo(14531)
    local link = GetAchievementLink(14531)
    btn:SetText(name)
    local fstr = btn:GetFontString()
    fstr:SetWidth(200)
    btn:SetFontString(fstr)
    btn.link = link

    elements[2] = btn
    btn:SetScript("OnEnter",function(self) 
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave",function() 
        GameTooltip:Hide();
    end)
    for i = 3, 10 do
        local str,_ , comp = GetAchievementCriteriaInfo(14531,i-2)
        elements[i] = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        elements[i]:SetPoint("TOPLEFT", 20,-40-20*i)
        if comp then
            elements[i]:SetTextColor(0,1,0)
        else
            elements[i]:SetTextColor(1,0,0)
        end
        elements[i]:SetText(str)
        elements[i]:Hide()
    end

    btn:Hide()

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetSize(200,40)
    btn:SetPoint("Topleft",232,-40)
    _ ,name = GetAchievementInfo(15078)
    link = GetAchievementLink(15078)
    btn:SetText(name)
    fstr = btn:GetFontString()
    fstr:SetWidth(200)
    btn:SetFontString(fstr)
    btn.link = link

    elements[11] = btn
    btn:SetScript("OnEnter",function(self) 
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    for i = 12, 19 do
        local str,_ , comp = GetAchievementCriteriaInfo(14532,i-11)
        elements[i] = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        elements[i]:SetPoint("TOPLEFT", 250,-40-20*(i-9))
        if comp then
            elements[i]:SetTextColor(0,1,0)
        else
            elements[i]:SetTextColor(1,0,0)
        end
        elements[i]:SetText(str)
        elements[i]:Hide()
    end
    btn:Hide()

    WeekKeys.AddButton(ACHIEVEMENTS,elements)
end)
