local elements = {}
local function add(arg1)
    arg1:Hide()
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
--[[  PTR things

local dungeonScore = C_ChallengeMode.GetOverallDungeonScore(); 
local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore); 
if(color) then 
    self.WeeklyInfo.Child.DungeonScoreInfo.Score:SetVertexColor(color.r, color.g, color.b);
end 
self.WeeklyInfo.Child.DungeonScoreInfo.Score:SetText(dungeonScore);
self.WeeklyInfo.Child.DungeonScoreInfo:SetShown(chestFrame:IsShown());



--]]
local buttons = {}
local Rio_de_Janeiro = {20,30,40,50,60,70,80,90,100,110,121,133,146,161,177,195,214,236,259,285,314,345,380,418,459,505,556,612,673}
--    Blizz_Janeiro = {}
local weekreward = {200,203,207,210,210,213,216,216,220,220,223,223,226}
while #weekreward < 30 do
    weekreward[#weekreward + 1] = 226
end

local end_of_run = {187,190,194,194,197,200,200,200,203,203,207,207,207}
while #end_of_run < 30 do
    end_of_run[#end_of_run + 1] = 210
end

local function update()
    for i,btn in pairs(buttons) do
        local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(i+1) -- api for loot
        local dmghp = C_ChallengeMode.GetPowerLevelDamageHealthMod(i+1)
        btn:SetData(i+1, max(chest,weekreward[i]),max(key,end_of_run[i]), Rio_de_Janeiro[i], dmghp.."%")
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
    for i = 2, 30 do
        buttons[i-1] = WeekKeys.UI.MTableButton(nil, buttons[i-2] or scrframe, i % 2 == 0 and true or false)
    end

    add(scrframe)
    local fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetPoint("TOPLEFT", 24,-40)
    fontstr:SetWidth(35)
    fontstr:SetText(L["LEVEL_ABBR"])
    add(fontstr)

    local fontstr2 = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr2:SetPoint("TOPLEFT", 59,-40)
    fontstr2:SetText(L["MYTHIC_PLUS_WEEKLY_BEST_LOOT"])
    fontstr2:SetWidth(135)
    add(fontstr2)

    local fontstr3 = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr3:SetPoint("TOPLEFT", 194,-40)
    fontstr3:SetWidth(125)
    fontstr3:SetText(L["keypush"])
    add(fontstr3)

    local fontstr4 = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr4:SetPoint("TOPLEFT", 319,-40)
    fontstr4:SetWidth(50)
    fontstr4:SetText(L["rio"])
    add(fontstr4)

    local fontstr5 = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr5:SetPoint("TOPLEFT", 369,-40)
    fontstr5:SetWidth(85)
    fontstr5:SetText(L["modifier"])
    add(fontstr5)

    WeekKeys.AddButton(L["mmtable"],elements)
    update()
end)
