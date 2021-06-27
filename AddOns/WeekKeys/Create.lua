local Addon = ...
local VERSION = 110
local buttons = {}
local elements = {}
local buttonID = 1
    --[[
        {type = "Fontstr", point = "TEXT", point_x = number, point_y = number, text = "text", width = number, height = number}
    --]]

function WeekKeys:Create()
    WeekKeys.Affixes.init()
    WeekKeys.WeekFrame = CreateFrame('Frame', 'WeekKeysFrame', UIParent,"BasicFrameTemplateWithInset")
    local WeekFrame = WeekKeys.WeekFrame
    tinsert(UISpecialFrames, 'WeekKeysFrame')
    WeekFrame:SetSize(500,500)
    if WeekKeysDB.Settings["MainFramePos"] then
        local db = WeekKeysDB.Settings["MainFramePos"]
        WeekFrame:SetPoint(db["point"],db["xOfs"],db["yOfs"])
    else
        WeekFrame:SetPoint("center")
    end

    WeekFrame.AddonName = WeekFrame:CreateFontString(nil , "BORDER", "GameFontNormal")
    WeekFrame.AddonName:SetPoint("top",0,-5)
    WeekFrame.AddonName:SetFormattedText("%s (v%d)   ",WeekKeys.L["WeekKeys"], VERSION)
    WeekFrame.AddonName:SetTextColor(1,1,1)
    WeekFrame:SetMovable(true)
    WeekFrame:RegisterForDrag("LeftButton")

    WeekFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not self.isMoving then
            self.isMoving = true;
            self:StartMoving();
        end
    end)

    WeekFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isMoving then
            self:StopMovingOrSizing();
            self.isMoving = false;

            local point, _, _, xOfs, yOfs = WeekFrame:GetPoint()

            WeekKeysDB.Settings["MainFramePos"] = {
                ["point"] = point,
                ["xOfs"] = xOfs,
                ["yOfs"] = yOfs,
            }
        end
    end)
    WeekFrame:SetScript("OnHide", function(self)
        if ( self.isMoving ) then
            self:StopMovingOrSizing();
            self.isMoving = false;
        end
    end)
    WeekFrame.ScrollFrame = CreateFrame("Scrollframe",nil , WeekFrame,"UIPanelScrollFrameTemplate")
    WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekFrame, "TOPLEFT", 4, -80);
    WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", WeekFrame, "BOTTOMRIGHT", -5, 5);
    WeekFrame.ScrollFrame:SetClipsChildren(true);

    WeekFrame.ScrollFrame.ScrollBar:ClearAllPoints();
    WeekFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", WeekFrame.ScrollFrame, "TOPRIGHT", -12, -18);
    WeekFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", WeekFrame.ScrollFrame, "BOTTOMRIGHT", -7, 23  );

    WeekFrame.ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local newValue = self:GetVerticalScroll() - (delta * 20);

        if (newValue < 0) then
            newValue = 0;
        elseif (newValue > self:GetVerticalScrollRange()) then
            newValue = self:GetVerticalScrollRange();
        end

        self:SetVerticalScroll(newValue);
    end);
    WeekFrame.ButtonFrame = CreateFrame('Frame', nil, WeekFrame ,"InsetFrameTemplate")
    WeekFrame.ButtonFrame:SetSize(150,200)
    WeekFrame.ButtonFrame:SetPoint("TOPRIGHT",150,0)
    for _,func in pairs(WeekKeys.inits) do
        func()
    end

    buttons[1]:Click()
    WeekKeys.WeekFrame:Hide()
    return WeekKeys.WeekFrame
end

function WeekKeys.AddButton(ButtonText,LabelArray)
    local button
    if #buttons > 0 then
        button = WeekKeys.UI.Button( name, buttons[#buttons], false)
    else
        button = WeekKeys.UI.Button( name, WeekKeys.WeekFrame.ButtonFrame, false)
        button:SetSize(144, 35)
        button:SetPoint("TOPLEFT",3,-2)
    end

    buttons[#buttons+1] = button
    elements[#elements+1] = LabelArray
    button:SetID(#buttons)

    WeekKeys.WeekFrame.ButtonFrame:SetHeight(#buttons * 35 + 5)

    button:SetText(ButtonText)
    button:SetScript("OnClick",function(self)
        -- hide scrollframe
        local scrollChild = WeekKeys.WeekFrame.ScrollFrame:GetScrollChild();
        if (scrollChild) then
            scrollChild:Hide();
        end

        -- hide previous ?section? elements
        for i,v in ipairs(elements[buttonID]) do
            if i ~= 1 then
                v:Hide()
            end
        end
        --set new scrollframe
        WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(elements[self:GetID()][1])
        elements[self:GetID()][1]:Show()
        -- show elements
        for i,v in ipairs(elements[self:GetID()]) do
            if i ~= 1 then
                v:Show()
            end
        end
        buttons[buttonID].texture:SetColorTexture(0.2,0.2,0.2,0)
        self.texture:SetColorTexture(0.2,0.2,0.2,1)
        buttonID = self:GetID()
    end)
end
