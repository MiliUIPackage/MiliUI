local elements = {}
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local GuildName = GetGuildInfo("player");
local querytable = {}
local buttons = {}
local updateFrame = CreateFrame("frame")
local function update()
    if not WeekKeysDB.Guild then return end
    if not WeekKeysDB.Guild[GuildName] then return end
    --WeekKeys.DB.GetGuildFormatted(WeekKeysDB.Guild["Академия Пиратов"])
    WeekKeys.DB.GetGuildFormatted(WeekKeysDB.Guild[GuildName],querytable)
    if #querytable == 0 then return end
    while #buttons < #querytable[2] do
        buttons[#buttons+1] = WeekKeys.UI.CovenantButton(nil,buttons[#buttons] or elements[1])
    end
    for i = 1,#buttons do
        buttons[i]:SetCovenant(querytable[1][i])
        buttons[i]:SetName(querytable[2][i])
        buttons[i]:Setilvl(querytable[3][i])
        buttons[i]:SetRecord(querytable[4][i])
        buttons[i]:SetKeystone(querytable[5][i])
        buttons[i]:SetReward(querytable[6][i])
    end
end


updateFrame:SetScript("OnEvent",function(self, event, prefix, text, channel)
    if prefix == "WeekKeys" and channel == "GUILD" then
        C_Timer.After(1,update)
    end
end)
WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(680,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        if not IsInGuild() then
            return
        end
        WeekKeys:SendCommMessage("WeekKeys","request","GUILD")
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
    fontstr:SetPoint("TOPLEFT", 180,-40)
    fontstr:SetText(ITEM_LEVEL_ABBR)
    fontstr:SetWidth(60)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 240,-40)
    fontstr:SetText(strsplit(HEADER_COLON,DUNGEON_SCORE_TOTAL_SCORE))
    fontstr:SetWidth(60)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 300,-40)
    fontstr:SetWidth(70)
    local record,_ = strsplit(HEADER_COLON,MYTHIC_PLUS_BEST_WEEKLY)
    fontstr:SetText(record)
    add(fontstr)

    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 370,-40)
    fontstr:SetWidth(180)
    local keystone,_ = strsplit(HEADER_COLON,CHALLENGE_MODE_KEYSTONE_NAME)
    fontstr:SetText(keystone)
    add(fontstr)
    WeekKeys.AddButton(L["guildkeys"],elements)
end)
