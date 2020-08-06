MotherFrame = CreateFrame('Frame', 'MotherFrame', UIParent,"BasicFrameTemplateWithInset")
tinsert(UISpecialFrames, "MotherFrame")
MotherVersion = "1.0.5"
MotherFrame:SetSize(500,500)
MotherFrame:SetPoint("center")
MotherFrame.AddonName = MotherFrame:CreateFontString(nil , "BORDER", "GameFontNormal")
MotherFrame.AddonName:SetPoint("top",0,-5)
MotherFrame.AddonName:SetText("|cffffff00母親大人，汙染物商店  " .. MotherVersion)
MotherFrame:Show()
MotherFrame.ButtonID = 0
MotherFrame.ButtonCount = 0
MotherFrame.btn = {}
MotherFrame.Buttons = {}
MotherFrame.Corrupt = {}
MotherFrame.Mother = {}
MotherFrame.Mother2 = {}
MotherFrame.Mother3 = {}
MotherFrame.Mother4 = {}
MotherFrame.CorruptLinks = {}
MotherFrame:SetMovable(true)
MotherFrame:RegisterForDrag("LeftButton")


local addon = LibStub("AceAddon-3.0"):NewAddon("Mother", "AceConsole-3.0")
local bunnyLDB = LibStub("LibDataBroker-1.1"):NewDataObject("Mother", {
    type = "data source",
    text = "0",
    icon = 2000861,
    HotCornerIgnore = true,
    OnClick = function(self, button)
        if button  then
            if MotherFrame.ButtonID == 0 then
                sChooses()
            end
            MotherFrame:SetShown(not MotherFrame:IsShown())
        end
    end,
    OnTooltipShow = function (tooltip)
        tooltip:AddLine ("母親大人，汙染物商店")
    end,
})
local icon = LibStub("LibDBIcon-1.0")

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MotherDB",
    {
        profile = { 
            minimap = { 
                hide = false,
            },
        },
    })
    icon:Register("Mother", bunnyLDB, self.db.profile.minimap)
end
MotherFrame.events = CreateFrame("frame")
MotherFrame.events:RegisterEvent('GET_ITEM_INFO_RECEIVED')
MotherFrame.events:SetScript("OnEvent",function(self,event,arg1,arg2,arg3,arg4)
	if event == 'GET_ITEM_INFO_RECEIVED' then
        if MotherFrame.CorruptLinks[arg1] ~= nil then
            local _, itemlink = GetItemInfo(arg1)
            MotherFrame.CorruptLinks[arg1] = itemlink
        end

    end
end)

SLASH_MOTHER1 = '/mother'
function SlashCmdList.MOTHER(msg, editbox)
    if MotherFrame.ButtonID == 0 then
        sChooses()
    end
    MotherFrame:SetShown(not MotherFrame:IsShown())
end
MotherFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not self.isMoving then
        self.isMoving = true;
        self:StartMoving();
    end
end)

MotherFrame:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and self.isMoving then
        self:StopMovingOrSizing();
        self.isMoving = false;

        local point, _, _, xOfs, yOfs = MotherFrame:GetPoint()

        MotherDB["MainFramePos"] = {
            ["point"] = point,
            ["xOfs"] = xOfs,
            ["yOfs"] = yOfs,
        }
    end
end)
MotherFrame:SetScript("OnHide", function(self)
    if ( self.isMoving ) then
        self:StopMovingOrSizing();
        self.isMoving = false;
    end
end)
MotherFrame.ScrollFrame = CreateFrame("Scrollframe",nil , MotherFrame,"UIPanelScrollFrameTemplate")
MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
MotherFrame.ScrollFrame:SetClipsChildren(true);

MotherFrame.ScrollFrame.ScrollBar:ClearAllPoints();
MotherFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", MotherFrame.ScrollFrame, "TOPRIGHT", -12, -18);
MotherFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", MotherFrame.ScrollFrame, "BOTTOMRIGHT", -7, 23  );

MotherFrame.ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
	local newValue = self:GetVerticalScroll() - (delta * 20);

	if (newValue < 0) then
		newValue = 0;
	elseif (newValue > self:GetVerticalScrollRange()) then
		newValue = self:GetVerticalScrollRange();
	end

	self:SetVerticalScroll(newValue);
end);

MotherFrame.CorruptNames = {
    [177973] = 315544,
	[177974] = 315545,
	[177975] = 315546, -- haste%
    [177992] = 315554,
	[177993] = 315557,
	[177994] = 315558, -- crit%
    [177986] = 315529,
	[177987] = 315530,
	[177988] = 315531, -- mastery%
    [178010] = 315549,
	[178011] = 315552,
	[178012] = 315553, -- versality%

    [177989] = 318266,
	[177990] = 318492,
	[177991] = 318496, -- haste proc
    [177955] = 318268,
	[177965] = 318493,
	[177966] = 318497, -- crit proc
    [177978] = 318269,
	[177979] = 318494,
	[177980] = 318498, -- mastery proc
    [178001] = 318270,
	[178002] = 318495,
	[178003] = 318499, -- versality proc

    [177998] = 315277,
	[177999] = 315281,
	[178000] = 315282, -- crit modifier
    [177995] = 315590,
	[177996] = 315591,
	[177997] = 315592, -- leech
    [177970] = 315607,
	[177971] = 315608,
	[177972] = 315609, -- avoidance

    [177983] = 318274,
	[177984] = 318487,
	[177985] = 318488, -- inf. stars
    [178004] = 318276,
	[178005] = 318477,
	[178006] = 318478, -- twilight
    [177969] = 318280,
	[177968] = 318485,
	[177967] = 318486, -- echo
    [178007] = 318481,
	[178008] = 318482,
	[178009] = 318483, -- mind flay
    [178013] = 318286,
	[178014] = 318479,
	[178015] = 318480, -- void ritual

    [177981] = 318303,
	[177982] = 318484, -- cooldowns

    [177977] = 318272, -- bleed
    [177976] = 315573 -- 3 sec cd


-- 315573 315574 318239 324881

}

local corruptlist = {--table
    {-- 1.week(1)
        {177981,3300},
        {177978,4125},
        {177999,4125},
        {177987,4125},
        {178009,13200},
        {177975,5000}
    },
    {
        {177986,3000},
        {178013,4125},
        {177965,5000},
        {177996,6300},
        {177982,6750},
        {178012,5000},
        {177971,3300}
    },
    {
        {177983,5000},
        {178001,4125},
        {177976,4125},
        {177993,4125},
        {177991,7875},
        {177997,9000},
        {177972,4250}
    },
    {
        {177992,3000},
        {177995,4250},
        {177974,4125},
        {178005,10000},
        {177980,7875},
        {178000,5000}
    },
    {
        {177973,3000},
        {178007,3000},
        {177990,5000},
        {177968,7875},
        {177985,15000},
        {177994,5000}
    },
    {
        {177989,4125},
        {177988,5000},
        {177998,3000},
        {178014,7875},
        {177970,2400},
        {178002,5000},
        {178006,15000},
    },
    {
        {177969,6250},
        {178010,3000},
        {177979,5000},
        {177984,10000},
        {177966,7875},
        {178015,13200},
        {177977,4125}
    },
    {
        {178004,6250},
        {178003,7875},
        {177967,12000},
        {177955,4125},
        {178011,4125},
        {178008,7875}
    },
}

local list = {
    177973,177974,177975, -- haste%
    177992,177993,177994, -- crit%
    177986,177987,177988, -- mastery%
    178010,178011,178012, -- versality%

    177989,177990,177991, -- haste proc
    177955,177965,177966, -- crit proc
    177978,177979,177980, -- mastery proc
    178001,178002,178003, -- versality proc

    177998,177999,178000, -- crit modifier
    177995,177996,177997, -- leech
    177970,177971,177972, -- avoidance

    177983,177984,177985, -- inf. stars
    178004,178005,178006, -- twilight
    177969,177968,177967, -- echo
    178007,178008,178009, -- mind flay
    178013,178014,178015, -- void ritual

    177981,177982, -- cooldowns

    177977, -- bleed
    177976  -- 3 sec cd
}
for _, value in pairs(list) do
    local _,itemlink = GetItemInfo(value)
	local name = GetSpellInfo(MotherFrame.CorruptNames[value])
	MotherFrame.CorruptNames[value] = name or ""
    MotherFrame.CorruptLinks[value] = itemlink or ""
end


MotherFrame.ButtonFrame = CreateFrame('Frame', nil, MotherFrame ,"InsetFrameTemplate")
MotherFrame.ButtonFrame:SetSize(150,200)
MotherFrame.ButtonFrame:SetPoint("TOPRIGHT",150,0)

function MotherFrame:AddButton(ButtonText,LabelArray)
    MotherFrame.ButtonCount = MotherFrame.ButtonCount + 1
    local button = CreateFrame('Button', name, MotherFrame.ButtonFrame, 'InsetFrameTemplate2')
    button:SetID(MotherFrame.ButtonCount)
    --print(button:GetID())
    MotherFrame.Buttons[MotherFrame.ButtonCount] = LabelArray
    MotherFrame.ButtonFrame:SetSize(MotherFrame.ButtonFrame:GetWidth(),MotherFrame.ButtonCount * 35 + 5)
    --button
    local texture = button:CreateTexture('textureName', 'BACKGROUND')
    texture:SetPoint('TOPLEFT', 2, -2)
    texture:SetPoint('bottomright', -2, 2)
    texture:SetColorTexture(0.2, 0.2, 0.2, 1)
    button:SetHighlightTexture(texture)
    button:DisableDrawLayer("BORDER")
    button:SetNormalFontObject('GameFontNormal')
    button:SetSize(145, 35)
    button:SetText(ButtonText)
    button:SetPoint("TOPLEFT",2,-(MotherFrame.ButtonCount-1)*35-2)
    button:SetScript("OnClick",function(self)
        -- hide scrollframe
        local scrollChild = MotherFrame.ScrollFrame:GetScrollChild();
	    if (scrollChild) then
		    scrollChild:Hide();
        end
        -- hide previous ?section? elements
        for i,v in ipairs(MotherFrame.Buttons[MotherFrame.ButtonID]) do
            if i ~= 1 then
                v:Hide()
            end
        end
        --set new scrollframe
        MotherFrame.ScrollFrame:SetScrollChild(MotherFrame.Buttons[self:GetID()][1])
        MotherFrame.Buttons[self:GetID()][1]:Show()
        -- show this ?section? elements
        for i,v in ipairs(MotherFrame.Buttons[self:GetID()]) do
            if i ~= 1 then
                v:Show()
            end
        end
        MotherFrame.ButtonID = self:GetID()
    end)
	tinsert(MotherFrame.btn, button)
end

MotherFrame.iconStr = {
    [177981] = "|Tinterface/Icons/INV_Wand_1H_NzothRaid_D_01:20:20|t",
    [177982] = "|Tinterface/Icons/INV_Wand_1H_NzothRaid_D_01:20:20|t",
    [177978] = "|Tinterface/Icons/Spell_Nature_FocusedMind:20:20|t",
    [177979] = "|Tinterface/Icons/Spell_Nature_FocusedMind:20:20|t",
    [177980] = "|Tinterface/Icons/Spell_Nature_FocusedMind:20:20|t",
    [177998] = "|Tinterface/Icons/Achievement_Profession_Fishing_FindFish:20:20|t",
    [177999] = "|Tinterface/Icons/Achievement_Profession_Fishing_FindFish:20:20|t",
    [178000] = "|Tinterface/Icons/Achievement_Profession_Fishing_FindFish:20:20|t",
    [177986] = "|TInterface/Icons/Ability_Rogue_SinisterCalling:20:20|t",
    [177987] = "|TInterface/Icons/Ability_Rogue_SinisterCalling:20:20|t",
    [177988] = "|TInterface/Icons/Ability_Rogue_SinisterCalling:20:20|t",
    [178007] = "|TInterface/Icons/Achievement_Boss_YoggSaron_01:20:20|t",
    [178008] = "|TInterface/Icons/Achievement_Boss_YoggSaron_01:20:20|t",
    [178009] = "|TInterface/Icons/Achievement_Boss_YoggSaron_01:20:20|t",
    [177973] = "|TInterface/Icons/Ability_Mage_NetherWindPresence:20:20|t",
    [177974] = "|TInterface/Icons/Ability_Mage_NetherWindPresence:20:20|t",
    [177975] = "|TInterface/Icons/Ability_Mage_NetherWindPresence:20:20|t",
    [177983] = "|TInterface/Icons/Ability_Druid_Starfall:20:20|t",
    [177984] = "|TInterface/Icons/Ability_Druid_Starfall:20:20|t",
    [177985] = "|TInterface/Icons/Ability_Druid_Starfall:20:20|t",
    [178013] = "|TInterface/Icons/Spell_Shadow_Shadesofdarkness:20:20|t",
    [178014] = "|TInterface/Icons/Spell_Shadow_Shadesofdarkness:20:20|t",
    [178015] = "|TInterface/Icons/Spell_Shadow_Shadesofdarkness:20:20|t",
    [177955] = "|TInterface/Icons/Ability_Hunter_RaptorStrike:20:20|t",
    [177965] = "|TInterface/Icons/Ability_Hunter_RaptorStrike:20:20|t",
    [177966] = "|TInterface/Icons/Ability_Hunter_RaptorStrike:20:20|t",
    [177995] = "|TInterface/Icons/Spell_Shadow_LifeDrain02_purple:20:20|t",
    [177996] = "|TInterface/Icons/Spell_Shadow_LifeDrain02_purple:20:20|t",
    [177997] = "|TInterface/Icons/Spell_Shadow_LifeDrain02_purple:20:20|t",
    [178010] = "|TInterface/Icons/Spell_Arcane_ArcaneTactics:20:20|t",
    [178011] = "|TInterface/Icons/Spell_Arcane_ArcaneTactics:20:20|t",
    [178012] = "|TInterface/Icons/Spell_Arcane_ArcaneTactics:20:20|t",
    [177970] = "|TInterface/Icons/spell_warlock_demonsoul:20:20|t",
    [177971] = "|TInterface/Icons/spell_warlock_demonsoul:20:20|t",
    [177972] = "|TInterface/Icons/spell_warlock_demonsoul:20:20|t",
    [178001] = "|TInterface/Icons/Ability_Hunter_OneWithNature:20:20|t",
    [178002] = "|TInterface/Icons/Ability_Hunter_OneWithNature:20:20|t",
    [178003] = "|TInterface/Icons/Ability_Hunter_OneWithNature:20:20|t",
    [177976] = "|TInterface/Icons/ability_warlock_soulswap:20:20|t",
    [177992] = "|TInterface/Icons/Ability_Priest_ShadowyApparition:20:20|t",
    [177993] = "|TInterface/Icons/Ability_Priest_ShadowyApparition:20:20|t",
    [177994] = "|TInterface/Icons/Ability_Priest_ShadowyApparition:20:20|t",
    [177989] = "|TInterface/Icons/Ability_Warrior_BloodFrenzy:20:20|t",
    [177990] = "|TInterface/Icons/Ability_Warrior_BloodFrenzy:20:20|t",
    [177991] = "|TInterface/Icons/Ability_Warrior_BloodFrenzy:20:20|t",
    [178004] = "|TInterface/Icons/Spell_Priest_VoidSear:20:20|t",
    [178005] = "|TInterface/Icons/Spell_Priest_VoidSear:20:20|t",
    [178006] = "|TInterface/Icons/Spell_Priest_VoidSear:20:20|t",
    [177969] = "|TInterface/Icons/Ability_Priest_VoidEntropy:20:20|t",
    [177968] = "|TInterface/Icons/Ability_Priest_VoidEntropy:20:20|t",
    [177967] = "|TInterface/Icons/Ability_Priest_VoidEntropy:20:20|t",
    [177977] = "|TInterface/Icons/Ability_IronMaidens_CorruptedBlood:20:20|t",
}



MotherFrame.CorruptionTier = {
    [177981] = "1階",
    [177982] = "2階",
    [177978] = "1階",
    [177979] = "2階",
    [177980] = "3階",
    [177998] = "1階",
    [177999] = "2階",
    [178000] = "3階",
    [177986] = "1階",
    [177987] = "2階",
    [177988] = "3階",
    [178007] = "1階",
    [178008] = "2階",
    [178009] = "3階",
    [177973] = "1階",
    [177974] = "2階",
    [177975] = "3階",
    [177983] = "1階",
    [177984] = "2階",
    [177985] = "3階",
    [178013] = "1階",
    [178014] = "2階",
    [178015] = "3階",
    [177955] = "1階",
    [177965] = "2階",
    [177966] = "3階",
    [177995] = "1階",
    [177996] = "2階",
    [177997] = "3階",
    [178010] = "1階",
    [178011] = "2階",
    [178012] = "3階",
    [177970] = "1階",
    [177971] = "2階",
    [177972] = "3階",
    [178001] = "1階",
    [178002] = "2階",
    [178003] = "3階",
    [177976] = "1階",
    [177992] = "1階",
    [177993] = "2階",
    [177994] = "3階",
    [177989] = "1階",
    [177990] = "2階",
    [177991] = "3階",
    [178004] = "1階",
    [178005] = "2階",
    [178006] = "3階",
    [177969] = "1階",
    [177968] = "2階",
    [177967] = "3階",
    [177977] = "1階",
}

function sChooses()
    MotherFrame.ButtonID = 1
    do
        local echo = " |Tinterface/icons/inv_inscription_80_vantusrune_nyalotha.blp:15:15|t"
        local arrayOfElements = {}
        arrayOfElements[1] = CreateFrame('Frame')
        arrayOfElements[1]:SetFrameStrata("BACKGROUND")
        arrayOfElements[1]:SetSize(10,10)
        arrayOfElements[1]:SetScript("OnShow",function ()

            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -45);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);

            local nextRotation = 0
            local rotation = -1
            local i = 1
            local color = "|cff00ff00"
            if GetCurrentRegion() == 3 then
                -- 1589958000 -- begin EU
                nextRotation = 302400 -  (GetServerTime() - 1589958000) % 302400
                rotation = math.floor(((GetServerTime() - 1589958000) % 2419200) /302400)
            elseif GetCurrentRegion() == 2 then
				-- 1590015600 Asia?
				nextRotation = 302400 - (GetServerTime() - 1590015600) % 302400
                rotation = math.floor(((GetServerTime() - 1590015600) % 2419200) /302400)
            
			else
                -- 1589900400 -- begin US
                nextRotation = 302400 - (GetServerTime() - 1589900400) % 302400
                rotation = math.floor(((GetServerTime() - 1589900400) % 2419200) /302400)
            end

            for j=rotation,(rotation+10) do
                for _,data in pairs(corruptlist[j%8+1]) do
					MotherFrame.Mother3[i].icon:SetFormattedText(MotherFrame.iconStr[data[1]])
                    MotherFrame.Mother3[i].name:SetFormattedText(color..(MotherFrame.CorruptNames[data[1]]).." ("..MotherFrame.CorruptionTier[data[1]]..")")
                    MotherFrame.Mother3[i].cost:SetFormattedText(color .. string.format("%5d",data[2])..echo)
                    if j == rotation then
                        MotherFrame.Mother3[i].time:SetFormattedText(color.."------")
                    else
                        local days = math.floor(nextRotation/86400)
                        local hours = math.floor(nextRotation%86400/3600)
                        MotherFrame.Mother3[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                    end
                    MotherFrame.Mother3[i]:SetID(data[1])
                    MotherFrame.Mother3[i]:Show()
                    i = i + 1
                end
                if color == "|cffffffff" then
                    color = ""
                else
                    color = "|cffffffff"
                end
                if j == rotation then
                    rotation = -1
                else
                    nextRotation = nextRotation + 302400
                end
            end
        end)
        arrayOfElements[1]:SetScript("OnHide",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
        end)
        arrayOfElements[1]:Hide()
        arrayOfElements[2] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[2]:SetPoint("TOPLEFT",35,-32)
        arrayOfElements[2]:SetText(CALENDAR_EVENT_NAME)
        arrayOfElements[2]:Hide()

        arrayOfElements[3] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[3]:SetPoint("TOPLEFT",310,-32)
		local time = string.gsub(GARRISON_MISSION_TIME_TOTAL,"%%s","") -- replace "%s" to ""
		arrayOfElements[3]:SetText(time)
        arrayOfElements[3]:Hide()

        arrayOfElements[4] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[4]:SetPoint("TOPLEFT",415,-32)
        arrayOfElements[4]:SetText(AUCTION_HOUSE_BROWSE_HEADER_PRICE)
        arrayOfElements[4]:Hide()

        for i = 1, 100 do
            local corrupt = CreateFrame('button',nil , arrayOfElements[1], 'InsetFrameTemplate2')
            local texture = corrupt:CreateTexture('textureName', 'BACKGROUND')
            texture:SetAllPoints(true)
            texture:SetColorTexture(0.2, 0.2, 0.2, 1)
            corrupt:SetHighlightTexture(texture)
            corrupt:DisableDrawLayer("BORDER")
            corrupt:SetNormalFontObject('GameFontNormal')
            corrupt:SetSize(MotherFrame:GetWidth()-30, 20)
            corrupt:SetPoint("TOPLEFT",4,-(i-1)*20)

			corrupt.icon = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.icon:SetPoint("LEFT",5,0)
			
            corrupt.name = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.name:SetPoint("LEFT",35,0)

            corrupt.cost = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.cost:SetPoint("LEFT",400,0)

            corrupt.time = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.time:SetPoint("LEFT",295,0)

            corrupt:Hide()
            corrupt:SetScript("OnEnter",function(self)
                GameTooltip:Hide();
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()])
                GameTooltip:Show()
            end)
            corrupt:SetScript("OnLeave",function(self)
                GameTooltip:Hide();
            end)


            tinsert(MotherFrame.Mother3,corrupt)
        end


        MotherFrame:AddButton("兌換時程",arrayOfElements)
    end
	--[[
    do
        local echo = " |Tinterface/icons/inv_inscription_80_vantusrune_nyalotha.blp:15:15|t"
        local arrayOfElements = {}
        arrayOfElements[1] = CreateFrame('Frame')
        arrayOfElements[1]:SetFrameStrata("BACKGROUND")
        arrayOfElements[1]:SetSize(10,10)
        arrayOfElements[1]:SetScript("OnShow",function ()

            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -45);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);

            local nextRotation = 0
            local rotation = -1
            local i = 1
            local color = "|cff00ff00"
         --   if GetCurrentRegion() == 3 then
                -- 1589958000 -- begin EU
                nextRotation = 302400 -  (GetServerTime() - 1589958000) % 302400
                rotation = math.floor(((GetServerTime() - 1589958000) % 2419200) /302400)
         --   else
                -- 1589900400 -- begin US
         --       nextRotation = 302400 - (GetServerTime() - 1589900400) % 302400
         --       rotation = math.floor(((GetServerTime() - 1589900400) % 2419200) /302400)
         --   end

            for j=rotation,(rotation+10) do
                for _,data in pairs(corruptlist[j%8+1]) do]]
	--				MotherFrame.Mother[i].icon:SetFormattedText(MotherFrame.iconStr[data[1]])
       --             MotherFrame.Mother[i].name:SetFormattedText(color..(MotherFrame.CorruptNames[data[1]]).." ("..MotherFrame.CorruptionTier[data[1]]..")")
        --[[            MotherFrame.Mother[i].cost:SetFormattedText(color .. string.format("%5d",data[2])..echo)
                    if j == rotation then
                        MotherFrame.Mother[i].time:SetFormattedText(color.."------")
                    else
                        local days = math.floor(nextRotation/86400)
                        local hours = math.floor(nextRotation%86400/3600)
                        MotherFrame.Mother[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                    end
                    MotherFrame.Mother[i]:SetID(data[1])
                    MotherFrame.Mother[i]:Show()
                    i = i + 1
                end
                if color == "|cffffffff" then
                    color = ""
                else
                    color = "|cffffffff"
                end
                if j == rotation then
                    rotation = -1
                else
                    nextRotation = nextRotation + 302400
                end
            end
        end)
        arrayOfElements[1]:SetScript("OnHide",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
        end)
        arrayOfElements[1]:Hide()
        arrayOfElements[2] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[2]:SetPoint("TOPLEFT",35,-32)
        arrayOfElements[2]:SetText(CALENDAR_EVENT_NAME)
        arrayOfElements[2]:Hide()

        arrayOfElements[3] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[3]:SetPoint("TOPLEFT",330,-32)
		local time = string.gsub(GARRISON_MISSION_TIME_TOTAL,"%%s","")

		arrayOfElements[3]:SetText(time)
        arrayOfElements[3]:Hide()

        arrayOfElements[4] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[4]:SetPoint("TOPLEFT",415,-32)
        arrayOfElements[4]:SetText(AUCTION_HOUSE_BROWSE_HEADER_PRICE)
        arrayOfElements[4]:Hide()

        for i = 1, 100 do
            local corrupt = CreateFrame('button',nil , arrayOfElements[1], 'InsetFrameTemplate2')
            local texture = corrupt:CreateTexture('textureName', 'BACKGROUND')
            texture:SetAllPoints(true)
            texture:SetColorTexture(0.2, 0.2, 0.2, 1)
            corrupt:SetHighlightTexture(texture)
            corrupt:DisableDrawLayer("BORDER")
            corrupt:SetNormalFontObject('GameFontNormal')
            corrupt:SetSize(MotherFrame:GetWidth()-30, 20)
            corrupt:SetPoint("TOPLEFT",4,-(i-1)*20)

			corrupt.icon = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.icon:SetPoint("LEFT",5,0)

            corrupt.name = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.name:SetPoint("LEFT",35,0)

            corrupt.cost = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.cost:SetPoint("LEFT",410,0)

            corrupt.time = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.time:SetPoint("LEFT",315,0)

            corrupt:Hide()
            corrupt:SetScript("OnEnter",function(self)
                GameTooltip:Hide();
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if self:GetID() and GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()]) then
					GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()])
					else 
					return
				end
                GameTooltip:Show()
            end)
            corrupt:SetScript("OnLeave",function(self)
                GameTooltip:Hide();
            end)


            tinsert(MotherFrame.Mother,corrupt)
        end


        MotherFrame:AddButton("MOTHER_EU",arrayOfElements)
    end
	
	do
        local echo = " |Tinterface/icons/inv_inscription_80_vantusrune_nyalotha.blp:15:15|t"
        local arrayOfElements = {}
        arrayOfElements[1] = CreateFrame('Frame')
        arrayOfElements[1]:SetFrameStrata("BACKGROUND")
        arrayOfElements[1]:SetSize(10,10)
        arrayOfElements[1]:SetScript("OnShow",function ()

		MotherFrame.ScrollFrame:ClearAllPoints()
		MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -45);
		MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);

		local nextRotation = 0
		local rotation = -1
		local i = 1
		local color = "|cff00ff00"
         --   if GetCurrentRegion() == 3 then
                -- 1589958000 -- begin EU
         --       nextRotation = 302400 -  (GetServerTime() - 1589958000) % 302400
          --      rotation = math.floor(((GetServerTime() - 1589958000) % 2419200) /302400)
         --   else
                -- 1589900400 -- begin US
                nextRotation = 302400 - (GetServerTime() - 1589900400) % 302400
               rotation = math.floor(((GetServerTime() - 1589900400) % 2419200) /302400)
         --   end

            for j=rotation,(rotation+10) do
                for _,data in pairs(corruptlist[j%8+1]) do
				MotherFrame.Mother2[i].icon:SetFormattedText(MotherFrame.iconStr[data[1 
                    MotherFrame.Mother2[i].name:SetFormattedText(color..(MotherFrame.CorruptNames[data[1] ]).." ("..MotherFrame.CorruptionTier[data[1] ]..")")
                    MotherFrame.Mother2[i].cost:SetFormattedText(color .. string.format("%5d",data[2])..echo)
                    if j == rotation then
                        MotherFrame.Mother2[i].time:SetFormattedText(color.."------")
                    else
                        local days = math.floor(nextRotation/86400)
                        local hours = math.floor(nextRotation%86400/3600)
                        MotherFrame.Mother2[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                    end
                    MotherFrame.Mother2[i]:SetID(data[1])
                    MotherFrame.Mother2[i]:Show()
                    i = i + 1
                end
                if color == "|cffffffff" then
                    color = ""
                else
                    color = "|cffffffff"
                end
                if j == rotation then
                    rotation = -1
                else
                    nextRotation = nextRotation + 302400
                end
            end
        end)
        arrayOfElements[1]:SetScript("OnHide",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
        end)
        arrayOfElements[1]:Hide()
        arrayOfElements[2] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[2]:SetPoint("TOPLEFT",35,-32)
        arrayOfElements[2]:SetText(CALENDAR_EVENT_NAME)
        arrayOfElements[2]:Hide()

        arrayOfElements[3] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[3]:SetPoint("TOPLEFT",330,-32)
local time = string.gsub(GARRISON_MISSION_TIME_TOTAL,"%%s","")
		arrayOfElements[3]:SetText(time)
        arrayOfElements[3]:Hide()

        arrayOfElements[4] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[4]:SetPoint("TOPLEFT",415,-32)
        arrayOfElements[4]:SetText(AUCTION_HOUSE_BROWSE_HEADER_PRICE)
        arrayOfElements[4]:Hide()
		for i = 1, 100 do
            local corrupt = CreateFrame('button',nil , arrayOfElements[1], 'InsetFrameTemplate2')
            local texture = corrupt:CreateTexture('textureName', 'BACKGROUND')
            texture:SetAllPoints(true)
            texture:SetColorTexture(0.2, 0.2, 0.2, 1)
            corrupt:SetHighlightTexture(texture)
            corrupt:DisableDrawLayer("BORDER")
            corrupt:SetNormalFontObject('GameFontNormal')
            corrupt:SetSize(MotherFrame:GetWidth()-30, 20)
            corrupt:SetPoint("TOPLEFT",4,-(i-1)*20)

corrupt.icon = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.icon:SetPoint("LEFT",5,0)
			
            corrupt.name = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.name:SetPoint("LEFT",35,0)

            corrupt.cost = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.cost:SetPoint("LEFT",410,0)

            corrupt.time = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.time:SetPoint("LEFT",315,0)

            corrupt:Hide()
            corrupt:SetScript("OnEnter",function(self)
                GameTooltip:Hide();
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self:GetID() and GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()]) then
					GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()])
					else 
					return
				end
                GameTooltip:Show()
            end)
            corrupt:SetScript("OnLeave",function(self)
                GameTooltip:Hide();
            end)


            tinsert(MotherFrame.Mother2,corrupt)
        end
        MotherFrame:AddButton("MOTHER_US",arrayOfElements)
    end
    do
        local echo = " |Tinterface/icons/inv_inscription_80_vantusrune_nyalotha.blp:15:15|t"
        local arrayOfElements = {}
        arrayOfElements[1] = CreateFrame('Frame')
        arrayOfElements[1]:SetFrameStrata("BACKGROUND")
        arrayOfElements[1]:SetSize(10,10)
        arrayOfElements[1]:SetScript("OnShow",function ()

		MotherFrame.ScrollFrame:ClearAllPoints()
		MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -45);
		MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);

		local nextRotation = 0
		local rotation = -1
		local i = 1
		local color = "|cff00ff00"
				nextRotation = 302400 - (GetServerTime() - 1590015600) % 302400
                rotation = math.floor(((GetServerTime() - 1590015600) % 2419200) /302400)
            

            for j=rotation,(rotation+10) do
                for _,data in pairs(corruptlist[j%8+1]) do
				MotherFrame.Mother4[i].icon:SetFormattedText(MotherFrame.iconStr[data[1] ])
                    MotherFrame.Mother4[i].name:SetFormattedText(color..(MotherFrame.CorruptNames[data[1] ]).." ("..MotherFrame.CorruptionTier[data[1] ]..")")
                    MotherFrame.Mother4[i].cost:SetFormattedText(color .. string.format("%5d",data[2])..echo)
                    if j == rotation then
                        MotherFrame.Mother4[i].time:SetFormattedText(color.."------")
                    else
                        local days = math.floor(nextRotation/86400)
                        local hours = math.floor(nextRotation%86400/3600)
                        MotherFrame.Mother4[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                    end
                    MotherFrame.Mother4[i]:SetID(data[1])
                    MotherFrame.Mother4[i]:Show()
                    i = i + 1
                end
                if color == "|cffffffff" then
                    color = ""
                else
                    color = "|cffffffff"
                end
                if j == rotation then
                    rotation = -1
                else
                    nextRotation = nextRotation + 302400
                end
            end
        end)
        arrayOfElements[1]:SetScript("OnHide",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
        end)
        arrayOfElements[1]:Hide()
        arrayOfElements[2] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[2]:SetPoint("TOPLEFT",35,-32)
        arrayOfElements[2]:SetText(CALENDAR_EVENT_NAME)
        arrayOfElements[2]:Hide()

        arrayOfElements[3] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[3]:SetPoint("TOPLEFT",330,-32)
local time = string.gsub(GARRISON_MISSION_TIME_TOTAL,"%%s","")
		arrayOfElements[3]:SetText(time)
        arrayOfElements[3]:Hide()

        arrayOfElements[4] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[4]:SetPoint("TOPLEFT",415,-32)
        arrayOfElements[4]:SetText(AUCTION_HOUSE_BROWSE_HEADER_PRICE)
        arrayOfElements[4]:Hide()
		for i = 1, 100 do
            local corrupt = CreateFrame('button',nil , arrayOfElements[1], 'InsetFrameTemplate2')
            local texture = corrupt:CreateTexture('textureName', 'BACKGROUND')
            texture:SetAllPoints(true)
            texture:SetColorTexture(0.2, 0.2, 0.2, 1)
            corrupt:SetHighlightTexture(texture)
            corrupt:DisableDrawLayer("BORDER")
            corrupt:SetNormalFontObject('GameFontNormal')
            corrupt:SetSize(MotherFrame:GetWidth()-30, 20)
            corrupt:SetPoint("TOPLEFT",4,-(i-1)*20)

corrupt.icon = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.icon:SetPoint("LEFT",5,0)

            corrupt.name = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.name:SetPoint("LEFT",35,0)

            corrupt.cost = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.cost:SetPoint("LEFT",410,0)

            corrupt.time = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.time:SetPoint("LEFT",315,0)

            corrupt:Hide()
            corrupt:SetScript("OnEnter",function(self)
                GameTooltip:Hide();
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self:GetID() and GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()]) then
					GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()])
					else 
					return
				end
                GameTooltip:Show()
            end)
            corrupt:SetScript("OnLeave",function(self)
                GameTooltip:Hide();
            end)


            tinsert(MotherFrame.Mother4,corrupt)
        end
        MotherFrame:AddButton("MOTHER_Asia",arrayOfElements)
    end
	]]
    -- corrupt
    do

        for _, id in pairs(list) do
            GetItemInfo(id)
        end
        local echo = " |Tinterface/icons/inv_inscription_80_vantusrune_nyalotha.blp:15:15|t"
        local arrayOfElements = {}
        arrayOfElements[1] = CreateFrame('Frame')
        arrayOfElements[1]:SetFrameStrata("BACKGROUND")
        arrayOfElements[1]:SetSize(10,10)
        arrayOfElements[1]:SetScript("OnShow",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -45);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
            local nextRotation = 0
            local currentRotation = -1
            local color = "|cffffffff"
            if GetCurrentRegion() == 3 then
                -- 1589958000 -- begin EU
                nextRotation = 302400 -  (GetServerTime() - 1589958000) % 302400
                rotation = math.floor(((GetServerTime() - 1589958000) % 2419200) /302400)
            elseif GetCurrentRegion() == 2 then
				-- 1590015600 Asia?
				nextRotation = 302400 - (GetServerTime() - 1590015600) % 302400
                rotation = math.floor(((GetServerTime() - 1590015600) % 2419200) /302400)
            
			else
                -- 1589900400 -- begin US
                nextRotation = 302400 - (GetServerTime() - 1589900400) % 302400
                rotation = math.floor(((GetServerTime() - 1589900400) % 2419200) /302400)
            end

            for i,id in pairs(list) do
                for rotation, corrupts in pairs(corruptlist) do
                    for _, corrputinfo in pairs(corrupts) do
                        if id == corrputinfo[1] then
                            if i % 3 == 1 then
                                if color == "|cffffffff" then
                                    color = ""
                                else
                                    color = "|cffffffff"
                                end
                            end
                            MotherFrame.Corrupt[i]:SetID(id)
							MotherFrame.Corrupt[i].icon:SetFormattedText(MotherFrame.iconStr[id])
                            MotherFrame.Corrupt[i].name:SetText(color..MotherFrame.CorruptNames[id] .." ("..MotherFrame.CorruptionTier[id]..")")
                            MotherFrame.Corrupt[i].cost:SetText(color..string.format("%5d",corrputinfo[2])..echo)
                            if rotation == (currentRotation + 1) then -- +1 because table starts from 1
                                MotherFrame.Corrupt[i].time:SetText(color.."------")
                            elseif rotation - (currentRotation + 1) > 0 then
                                local days = math.floor((nextRotation + (rotation - currentRotation - 2)*302400) / 86400)
                                local hours = math.floor((nextRotation + (rotation - currentRotation - 2)*302400) % 86400 / 3600)
                                MotherFrame.Corrupt[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                            else
                                local days = math.floor((nextRotation + (rotation - currentRotation + 6)*302400) / 86400)
                                local hours = math.floor((nextRotation + (rotation - currentRotation - 2)*302400) % 86400 / 3600)
                                MotherFrame.Corrupt[i].time:SetFormattedText(color..DAY_ONELETTER_ABBR.." "..HOUR_ONELETTER_ABBR,days,hours)
                            end
                            MotherFrame.Corrupt[i]:Show()
                        end
                    end
                end
            end
        end)
        arrayOfElements[1]:SetScript("OnHide",function()
            MotherFrame.ScrollFrame:ClearAllPoints()
            MotherFrame.ScrollFrame:SetPoint("TOPLEFT", MotherFrame, "TOPLEFT", 4, -80);
            MotherFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MotherFrame, "BOTTOMRIGHT", -5, 5);
        end)
        arrayOfElements[1]:Show()
        arrayOfElements[1]:Hide()
        arrayOfElements[2] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[2]:SetPoint("TOPLEFT",35,-32)
        arrayOfElements[2]:SetText(CALENDAR_EVENT_NAME)
        arrayOfElements[2]:Hide()

        arrayOfElements[3] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[3]:SetPoint("TOPLEFT",310,-32)
local time = string.gsub(GARRISON_MISSION_TIME_TOTAL,"%%s","")
        arrayOfElements[3]:SetText(time)
        arrayOfElements[3]:Hide()

        arrayOfElements[4] = MotherFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
        arrayOfElements[4]:SetPoint("TOPLEFT",415,-32)
        arrayOfElements[4]:SetText(AUCTION_HOUSE_BROWSE_HEADER_PRICE)
        arrayOfElements[4]:Hide()

        for i = 1, 52 do
            local corrupt = CreateFrame('button',nil , arrayOfElements[1], 'InsetFrameTemplate2')
            local texture = corrupt:CreateTexture('textureName', 'BACKGROUND')
            texture:SetAllPoints(true)
            texture:SetColorTexture(0.2, 0.2, 0.2, 1)
            corrupt:SetHighlightTexture(texture)
            corrupt:DisableDrawLayer("BORDER")
            corrupt:SetNormalFontObject('GameFontNormal')
            corrupt:SetSize(MotherFrame:GetWidth()-30, 20)
            corrupt:SetPoint("TOPLEFT",4,-(i-1)*20)


corrupt.icon = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.icon:SetPoint("LEFT",5,0)
			
            corrupt.name = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.name:SetPoint("LEFT",35,0)

            corrupt.cost = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.cost:SetPoint("LEFT",400,0)

            corrupt.time = corrupt:CreateFontString(nil , "ARTWORK", "GameFontNormal")
            corrupt.time:SetPoint("LEFT",295,0)

            corrupt:Hide()
            corrupt:SetScript("OnEnter",function(self)
                GameTooltip:Hide();
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self:GetID() and GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()]) then
					GameTooltip:SetHyperlink(MotherFrame.CorruptLinks[self:GetID()])
					else 
					return
					end
				GameTooltip:Show()
            end)

            corrupt:SetScript("OnLeave",function(self)
                GameTooltip:Hide();
            end)


            tinsert(MotherFrame.Corrupt,corrupt)
        end
        MotherFrame:AddButton("腐化列表",arrayOfElements)
    end
	MotherFrame.btn[1]:Click()
end


