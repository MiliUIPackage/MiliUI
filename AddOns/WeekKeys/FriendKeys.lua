local elements = {}
local db
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local querytable = {}
local buttons = {}
local extend = {}
local updateFrame = CreateFrame("frame")
local function update()
    WeekKeys.DB.GetFriends(WeekKeysDB.Friends,querytable,extend)
    if #querytable[3] == 0 then return end
    for _,v in pairs(buttons) do
        v:Hide()
    end
    while #buttons < max(#querytable[3],50) do
        buttons[#buttons+1] = WeekKeys.UI.FactionCovenantButton(nil,buttons[#buttons] or elements[1])
        buttons[#buttons]:SetScript("OnClick",function(self,click)
            if click == "LeftButton" then
                extend[self.bnet] = not extend[self.bnet]
                update()
                --[[
                updateFrame:UnregisterEvent("BN_CHAT_MSG_ADDON")
                WeekKeys.DB.GetCharsByFriend(db,querytable,self.name:GetText())
                for _,v in pairs(buttons) do
                    v:Hide()
                end
                for index, _ in pairs(querytable[3])do
                    buttons[index]:SetFaction(querytable[1][index])
                    buttons[index]:SetCovenant(querytable[2][index])
                    buttons[index]:SetName(querytable[3][index])
                    buttons[index]:Setilvl(querytable[4][index])
                    buttons[index]:SetRecord(querytable[5][index])
                    buttons[index]:SetKeystone(querytable[6][index])
                    buttons[index]:Show()
                end
            else
                updateFrame:RegisterEvent("BN_CHAT_MSG_ADDON")
                update()
                --]]
            end
        end)
    end
    for i = 1,#querytable[3] do
        buttons[i]:SetFaction(querytable[1][i])
        buttons[i]:SetCovenant(querytable[2][i])
        buttons[i]:SetName(querytable[3][i])
        buttons[i]:Setilvl(querytable[4][i])
        buttons[i]:SetRecord(querytable[5][i])
        buttons[i]:SetKeystone(querytable[6][i])
        buttons[i].bnet = querytable[7][i]
        buttons[i]:Show()
    end
end


updateFrame:SetScript("OnEvent",function(self, event, prefix, text, channel)
   -- if prefix == "WeekKeys" then
  --      C_Timer.After(1,update)
   -- end
   update()
end)
WeekKeys.AddInit(
function()
    db = WeekKeysDB.Friends
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(480,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        local i = 1
        while C_BattleNet.GetFriendAccountInfo(i) do
            local friend = C_BattleNet.GetFriendAccountInfo(i)
            local id = friend.gameAccountInfo.gameAccountID
            if id and friend.gameAccountInfo.clientProgram == "WoW" then
                WeekKeys.BNAddMsg("WeekKeys","request",id)
            end
            i = i + 1
        end
        updateFrame:RegisterEvent("BN_CHAT_MSG_ADDON")
        update()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -60);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    scrframe:SetScript("OnHide",function()
        updateFrame:UnregisterEvent("BN_CHAT_MSG_ADDON")
    end)

    add(scrframe)
    local fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 20,-40)
    fontstr:SetText(CHARACTER_NAME_PROMPT)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 180,-40)
    fontstr:SetText(ITEM_LEVEL_ABBR)
    fontstr:SetWidth(60)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 240,-40)
    fontstr:SetWidth(70)
    local record,_ = strsplit(HEADER_COLON,MYTHIC_PLUS_BEST_WEEKLY)
    fontstr:SetText(record)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 310,-40)
    fontstr:SetWidth(180)
    local keystone,_ = strsplit(HEADER_COLON,CHALLENGE_MODE_KEYSTONE_NAME)
    fontstr:SetText(keystone)
    add(fontstr)
    WeekKeys.AddButton(L["friends"],elements)
    update()
end)
