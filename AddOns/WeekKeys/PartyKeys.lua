local elements = {}
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local querytable = {}
local buttons = {}
local updateFrame = CreateFrame("frame")
local function update()
    local name, ilvl, record, keystone, realm, covenant
    for i = 1, 4 do
        name, realm = UnitName("party"..i)
        if realm then
            realm = realm:gsub(" ","")
        else
            realm = GetNormalizedRealmName()
        end
        name, ilvl, record, keystone, covenant = WeekKeys.DB.GetChar(WeekKeys.PartyDB,name, realm)

        if buttons[i] then
            buttons[i]:SetName(name)
            buttons[i]:Setilvl(ilvl)
            buttons[i]:SetRecord(record)
            buttons[i]:SetKeystone(keystone)
            buttons[i]:SetCovenant(covenant)
        else
            buttons[i] = WeekKeys.UI.FactionCovenantButton(nil,buttons[#buttons] or elements[1])
            buttons[i]:SetName(name)
            buttons[i]:Setilvl(ilvl)
            buttons[i]:SetRecord(record)
            buttons[i]:SetKeystone(keystone)
            buttons[i]:SetCovenant(covenant)
        end
    end
end


updateFrame:SetScript("OnEvent",function(self, event, prefix, text, channel)
    if prefix == "WeekKeys" and channel == "PARTY" then
        C_Timer.After(1,update)
    end
end)
WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(480,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        if not IsInGroup() then
            return
        end
        WeekKeys:SendCommMessage("WeekKeys","request","PARTY")
        GuildName = GetGuildInfo("player");
        updateFrame:RegisterEvent("CHAT_MSG_ADDON")
        update()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -60);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    scrframe:SetScript("OnHide",function()
        updateFrame:UnregisterEvent("CHAT_MSG_ADDON")
    end)

    add(scrframe)
    local fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 20,-40)
    fontstr:SetText(CHARACTER_NAME_PROMPT)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 184,-40)
    fontstr:SetText(ITEM_LEVEL_ABBR)
    fontstr:SetWidth(60)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 244,-40)
    fontstr:SetWidth(50)
    -- local record,_ = strsplit(":",MYTHIC_PLUS_BEST_WEEKLY)
    fontstr:SetText(L["MYTHIC_PLUS_BEST_WEEKLY"])
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 290,-40)
    fontstr:SetWidth(180)
    -- local keystone,_ = strsplit(":",CHALLENGE_MODE_KEYSTONE_NAME)
    fontstr:SetText(L["CHALLENGE_MODE_KEYSTONE_NAME"])
    add(fontstr)
    WeekKeys.AddButton(L["partykeys"],elements)
end)
