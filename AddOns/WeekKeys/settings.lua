local L = WeekKeys.L
local arrayOfElements = {}

WeekKeys.AddInit(
function()
    arrayOfElements[1] = CreateFrame('Frame')
    arrayOfElements[1]:SetFrameStrata("BACKGROUND")
    arrayOfElements[1]:SetSize(100,10)
    arrayOfElements[1]:SetScript("OnShow",function()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -25);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    arrayOfElements[1]:Hide()

    local myCheckButton = CreateFrame("CheckButton", "WeekKeys_CheckButton1", arrayOfElements[1], "ChatConfigCheckButtonTemplate");
    myCheckButton:SetPoint("TOPLEFT", 10, -15);
    WeekKeys_CheckButton1Text:SetText(L["pkeys_react"]);
    myCheckButton.tooltip = L["pkeys_react_tooltip"];
    if WeekKeysDB.Settings["pkeyslink"] == nil then -- 更改預設值
		WeekKeysDB.Settings["pkeyslink"] = true
	end
	if WeekKeysDB.Settings["pkeyslink"] == true then 
        myCheckButton:SetChecked(true)
    end
    myCheckButton:SetScript("OnClick",function(self)
        local checked = self:GetChecked()
        if checked == true then
            WeekKeysDB.Settings["pkeyslink"] = true
        else
            WeekKeysDB.Settings["pkeyslink"] = false
        end
    end);

    local myCheckButton2 = CreateFrame("CheckButton", "WeekKeys_CheckButton2", arrayOfElements[1], "ChatConfigCheckButtonTemplate");
    myCheckButton2:SetPoint("TOPLEFT", 10, -35);
    WeekKeys_CheckButton2Text:SetTextColor(1,1,1)
    WeekKeys_CheckButton2Text:SetText(L["hide_minimap"]);
    if WeekKeys.db.global.minimap.hide == true then -- 更改預設值
        myCheckButton2:SetChecked(true)
    end
    myCheckButton2:SetScript("OnClick",function(self)
        local checked = self:GetChecked()
        if checked == true then
            WeekKeys.db.global.minimap.hide = true
            WeekKeys.icon:Hide("WeekKeys")
        else
            WeekKeys.db.global.minimap.hide = false
            WeekKeys.icon:Show("WeekKeys")
        end
    end);

    local myCheckButton3 = CreateFrame("CheckButton", "WeekKeys_CheckButton3", arrayOfElements[1], "ChatConfigCheckButtonTemplate");
    myCheckButton3:SetPoint("TOPLEFT", 10, -55);
    WeekKeys_CheckButton3Text:SetText(L.covenant);
    myCheckButton3.tooltip = L.covenant_tooltip
    if WeekKeysDB.Settings["covenant"] == nil then
		WeekKeysDB.Settings["covenant"] = true
	end
	if WeekKeysDB.Settings["covenant"] == true then
        myCheckButton3:SetChecked(true)
    end
    myCheckButton3:SetScript("OnClick",function(self)
        local checked = self:GetChecked()
        if checked == true then
            WeekKeysDB.Settings["covenant"] = true
        else
            WeekKeysDB.Settings["covenant"] = false
        end
    end);
    WeekKeys.AddButton(L["settings"],arrayOfElements)
end)
