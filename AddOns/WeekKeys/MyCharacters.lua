
local elements = {}
local function add(arg1)
    elements[#elements+1] = arg1
end
local L = WeekKeys.L
local buttons = {}
local updateFrame = CreateFrame("frame")
local mycharsDB = WeekKeys.MyChars
local field = nil
local descending = false
local function update()
    for i, char in mycharsDB:pairs(field,descending) do

        if not buttons[i] then -- create if button does not exist
            buttons[i] = WeekKeys.UI.FactionCovenantButton(nil,buttons[#buttons] or elements[1])
            buttons[i].db = WeekKeysDB.Characters
            buttons[i].update = update
            buttons[i]:SetScript("onclick",function(self)
                if IsShiftKeyDown() then
                    WeekKeys.DB.Remove(self.db,self:GetNameFaction())
                    for _, v in pairs(buttons) do v:Hide() end
                    self.update()
                end
            end)
        end
        -- set info
        buttons[i]:SetFaction(char.faction)
        buttons[i]:SetCovenant(char.covenant)
        buttons[i]:SetName(char.colored)
        buttons[i]:SetRealm(char.realm)
        buttons[i]:Setilvl(char.ilvl)
        buttons[i]:SetRecord(char.record)
        buttons[i]:SetKeystone(char.keystone)
        buttons[i]:SetReward(char.reward)
        buttons[i]:Setmscore(char.mscore)
        buttons[i]:SetTooltip(char.recordtable)
        buttons[i]:Show()
    end
end


updateFrame:SetScript("OnEvent",function()
    C_Timer.After(1,update)
end)
WeekKeys.AddInit(
function()
    local scrframe = CreateFrame('Frame',nil,WeekKeys.WeekFrame.ScrollFrame)
    scrframe:SetFrameStrata("BACKGROUND")
    scrframe:SetSize(680,5)
    WeekKeys.WeekFrame.ScrollFrame:SetScrollChild(scrframe)
    scrframe:SetScript("OnShow",function()
        updateFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
        update()
        C_MythicPlus.RequestRewards()
        C_MythicPlus.RequestMapInfo()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -90);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT",  WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    scrframe:SetScript("OnHide",function()
        updateFrame:UnregisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    end)

    add(scrframe)
    local btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 5,-70)
    btn:SetSize(20,20)
    btn.texture:SetTexture(1126583)
    btn:SetScript("OnClick",function(self)
        if field == "faction" then
            descending = not descending
        else
            field = "faction"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 25,-70)
    btn:SetSize(20,20)
    btn.texture:SetTexture('Interface/CovenantChoice/CovenantChoiceUI')
    btn.texture:SetTexCoord(0.59765625,0.88671875,0.05712890625,0.15185546875)
    btn:SetScript("OnClick",function(self)
        if field == "covenant" then
            descending = not descending
        else
            field = "covenant"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 40,-70)
    btn:SetSize(140,20)
    btn:SetText(CHARACTER_NAME_PROMPT)
    btn:SetScript("OnClick",function(self)
        if field == "name" then
            descending = not descending
        else
            field = "name"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 180,-70)
    btn:SetSize(60,20)
    btn:SetText(ITEM_LEVEL_ABBR)
    btn:SetScript("OnClick",function(self)
        if field == "ilvl" then
            descending = not descending
        else
            field = "ilvl"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 240,-70)
    btn:SetSize(60,20)
    btn:SetText(strsplit(HEADER_COLON,DUNGEON_SCORE_TOTAL_SCORE))
    btn:SetScript("OnClick",function(self)
        if field == "mscore" then
            descending = not descending
        else
            field = "mscore"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 300,-70)
    btn:SetSize(70,20)
    btn:SetText(strsplit(HEADER_COLON,MYTHIC_PLUS_BEST_WEEKLY))
    btn:SetScript("OnClick",function(self)
        if field == "record" then
            descending = not descending
        else
            field = "record"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 370,-70)
    btn:SetSize(90,20)
    btn:SetText(strsplit(HEADER_COLON,CHALLENGE_MODE_KEYSTONE_NAME))
    btn:SetScript("OnClick",function(self)
        if field == "keyID" then
            descending = not descending
        else
            field = "keyID"
            descending = false
        end
        update()
    end)
    add(btn)

    btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    btn:SetPoint("TOPLEFT", 460,-70)
    btn:SetSize(90,20)
    btn:SetText("(" .. LEVEL .. ")")
    btn:SetScript("OnClick",function(self)
        if field == "keyLevel" then
            descending = not descending
        else
            field = "keyLevel"
            descending = false
        end
        update()
    end)--939373
    add(btn)

    local affixIcons = {WeekKeys.Affixes.GetAffixes()}
    for i = 1, 4 do
        local btn = WeekKeys.UI.Button(nil,WeekKeys.WeekFrame,nil)
        btn.SetAffix = function (self,id)
            if id == nil then
                return
            end
            local name, description, filedataid = C_ChallengeMode.GetAffixInfo(id)
            btn.name = name
            btn.desc = description
            btn:SetNormalTexture(filedataid)
        end
        btn:SetSize(35,35)
        btn:SetPoint("TOPLEFT",180+45*i,-30)
        btn:SetScript("OnEnter",function(self)
            GameTooltip:Hide();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name)
            GameTooltip:AddLine(self.desc,1,1,1,true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave",function(self)
            GameTooltip:Hide();
        end)
        btn:SetAffix(affixIcons[i])
        affixIcons[i] = btn
        add(btn)
    end
    fontstr = WeekKeys.WeekFrame:CreateFontString(nil , "ARTWORK", "GameFontNormal")
    fontstr:SetText("|cffffffff"..GUILD_CHALLENGES_THIS_WEEK..":")
    fontstr:SetPoint("TOPLEFT",20,-40)
    add(fontstr)

    local button = CreateFrame("Button",nil,WeekKeys.WeekFrame,"UIPanelButtonTemplate")
    button:SetSize(25,25)
    button:SetPoint("TOPLEFT",195,-35)
    button:SetText("<")
    button:SetScript("OnClick",function()
        WeekKeys.Affixes.Previous()
        local affix1, affix2, affix3, affix4 = WeekKeys.Affixes.GetAffixes()
        if affix1 == nil then
            return
        end
        affixIcons[1]:SetAffix(affix1)
        affixIcons[2]:SetAffix(affix2)
        affixIcons[3]:SetAffix(affix3)
        affixIcons[4]:SetAffix(affix4)
        if WeekKeys.Affixes.GetSteps() == 0 then
            fontstr:SetText("|cffffffff"..GUILD_CHALLENGES_THIS_WEEK..":")
        else
            fontstr:SetFormattedText("|cffffffff"..L["after x weeks"],WeekKeys.Affixes.GetSteps())
        end
    end)
    add(button)

    button = CreateFrame("Button",nil,WeekKeys.WeekFrame,"UIPanelButtonTemplate")
    button:SetSize(25,25)
    button:SetPoint("TOPLEFT",400,-35)
    button:SetText(">")
    button:SetScript("OnClick",function()
        WeekKeys.Affixes.Next()
        local affix1, affix2, affix3, affix4 = WeekKeys.Affixes.GetAffixes()
        if affix1 == nil then
            return
        end
        affixIcons[1]:SetAffix(affix1)
        affixIcons[2]:SetAffix(affix2)
        affixIcons[3]:SetAffix(affix3)
        affixIcons[4]:SetAffix(affix4)
        if WeekKeys.Affixes.GetSteps() == 0 then
            fontstr:SetText("|cffffffff"..GUILD_CHALLENGES_THIS_WEEK..":")
        else
            fontstr:SetFormattedText("|cffffffff"..L["after x weeks"],WeekKeys.Affixes.GetSteps())
        end
    end)
    add(button)

    WeekKeys.AddButton(L["mykeys"],elements)
    update()
end)
