local arrayOfElements = {}
local L = WeekKeys.L
local WeekFrame = WeekKeys.WeekFrame

local loot_btns = {}
local hide_frames = {}
local mlevel = 15
local wchest = true

local function update()
    for i = #loot_btns, #LootFinder.loot_list do
        local btn = WeekKeys.UI.LootFinderButton(nil, arrayOfElements[1])
        loot_btns[#loot_btns + 1] = btn
        btn:SetSize(492,20)
        btn:SetPoint("TOPLEFT",4,-(i)*20)
    end
    for i = 1, #loot_btns do -- hide all buttons
        loot_btns[i]:Hide()
    end
    for index, source, name, boss, itemlink, icon, mainstat, crit, haste, mastery, versality in WeekKeys.Iterators.LootList() do
        local btn = loot_btns[index]
        btn.boss = boss
        btn.dung = name
        btn:SetSource(source)
        btn:SetIcon(icon)
        btn:SetDungeon(name)
        btn.link = itemlink
        btn:SetMainAtr(mainstat)
        btn:SetCrit(crit)
        btn:SetHaste(haste)
        btn:SetMastery(mastery)
        btn:SetVersality(versality)
        btn:Show()
    end
end
--- Function to create frame with class icons
---@param btn Frame @frame/button to anchor
---@return Frame class_frame @Frame with class icons
local function createmyclasslist(btn)
    -- background for class buttons
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 4 + 20, btnsize * 3 + 20)
    -- class buttons with onclick script
    for i = 1, 12 do
        local button = WeekKeys.UI.Button(nil, back)
        button:SetPoint("TOPLEFT",(i-1)%4*btnsize+10,-1*math.floor((i-1)/4)*btnsize-10)
        button:SetSize(btnsize,btnsize)
        button:SetID(i)
        local _, class, _ = GetClassInfo(i)
        button.texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local coords = CLASS_ICON_TCOORDS[class]
        button.texture:SetTexCoord(unpack(coords))

        button:SetScript("onclick",function(self)
            LootFinder.class = self:GetID()
            LootFinder.spec = 0
            -- specrefresh()
            btn.texture:SetTexture(self.texture:GetTexture())
            local _, class, _ = GetClassInfo(self:GetID())
            local coords = CLASS_ICON_TCOORDS[class]
            btn.texture:SetTexCoord(unpack(coords))
            back:Hide()
            LootFinder:Find()
        end)
    end
    hide_frames[#hide_frames + 1] = back
  --  back:SetScript("OnLeave",function(self) self:Hide() end)
    back:Hide()
    return back
end

--- Function to create frame with spec list
---@param btn Frame @frame/button to anchor
---@return Frame spec_frame @Frame with class specializations
local function createspeclist(btn)
    local spec_btn_list = {}
    -- background for spec buttons
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 3 + 20, btnsize * 2 + 20)
    for i = 1, 5 do
        local button = WeekKeys.UI.Button(nil, back)
        button:SetPoint("TOPLEFT",(i-1)%3*btnsize+2,-1*math.floor((i-1)/3)*btnsize-2)
        button:SetSize(btnsize,btnsize)
        button:SetScript("OnClick",function(self)
            LootFinder.spec = self:GetID()
            btn.texture:SetTexture(self.texture:GetTexture())
            back:Hide()
            LootFinder:Find()
        end)
        spec_btn_list[i] = button
    end

    back:SetScript("OnShow",function(self)
        if not LootFinder.class_spec[LootFinder.class] then return self:Hide() end
        local len = #LootFinder.class_spec[LootFinder.class]
        --if len == 0 then self:Hide() return end -- hide if no class choosen
        local spec_ids = LootFinder.class_spec[LootFinder.class]
        if len == 2 then back:SetSize(btnsize * 3 + 10, btnsize * 1 + 10) else back:SetSize(btnsize * 3 + 10, btnsize * 2 + 10) end
        for i = 1, len do
           local _, _, _, icon, _, _ = GetSpecializationInfoByID(spec_ids[i])
           spec_btn_list[i]:SetID(spec_ids[i])
           spec_btn_list[i].texture:SetTexture(icon)
           spec_btn_list[i]:Show()
        end
        spec_btn_list[len+1]:SetID(0)
        spec_btn_list[len+1].texture:SetTexture(QUESTION_MARK_ICON)
        spec_btn_list[len+1]:Show()
        for i = len + 2, 5 do
            spec_btn_list[i]:Hide()
        end
    end)
    hide_frames[#hide_frames + 1] = back
    --back:SetScript("OnLeave",function(self) self:Hide() end)
    back:Hide()
    return back
end

--- Function to create frame with clot list
---@param btn Frame @frame/button to anchor
---@return Frame slot_frame @Frame with slots
local function createslotlist(btn)
    -- background for spec buttons
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 4 + 20, btnsize * 4 + 20) -- change to setpoint
    local icons = {133070,133292,135061,133771,132751,132616,132939,132511,134584,132535,135317,134959,801523,133441,QUESTION_MARK_ICON}
    local slots = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,15}

    for i = 1, #icons do 
        local button = WeekKeys.UI.Button(nil, back)
        button:SetPoint("TOPLEFT",(i-1)%4*btnsize+10,-1*math.floor((i-1)/4)*btnsize-10)
        button:SetSize(btnsize,btnsize)
        button.texture:SetTexture(icons[i])
        button:SetID(slots[i])
        button:SetScript("OnClick",function(self)
            LootFinder.slot = self:GetID()
            btn.texture:SetTexture(self.texture:GetTexture())
            back:Hide()
            LootFinder:Find()
        end)
    end
    hide_frames[#hide_frames + 1] = back
    --back:SetScript("OnLeave",function(self) self:Hide() end)
    back:Hide()
    return back
end

--- Function to create frame with instance list
---@param btn Frame @frame/button to anchor
---@return Frame instance_frame @Frame with instances
local function createinstancelist(btn)

    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 4 + 20, btnsize * 4 + 20)

    local i = 1
    EJ_SelectTier(LootFinder.expansion)
    while EJ_GetInstanceByIndex(i, false) ~= nil do
        LootFinder.instances[i] = true
        local _, name, _, _, _, _, buttonImage2 = EJ_GetInstanceByIndex(i, false)
        local button = WeekKeys.UI.Button(nil, back)
        button.name = name
        button:SetPoint("TOPLEFT",(i-1)%4*btnsize+10,-1*math.floor((i-1)/4)*btnsize-10)
        button:SetSize(btnsize,btnsize)
        button:SetID(i)
        button.texture:SetTexture(buttonImage2)
        button.find = true

        function button:enable(bool)
            if bool then
                LootFinder.instances[self:GetID()] = true
                self.texture:SetAlpha(1)
            else
                LootFinder.instances[self:GetID()] = false
                self.texture:SetAlpha(0.3)
            end
            self.find = bool
        end

        button:SetScript("OnClick",function(self)
            self:enable(not self.find)
            LootFinder:Find()
        end)

        button:SetScript("OnEnter",function(self)
            GameTooltip:Hide();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave",function()
            GameTooltip:Hide();
        end)

        i = i + 1
    end
    back:SetHeight(math.floor((i-1)/4)*btnsize+20)

    hide_frames[#hide_frames + 1] = back
    --back:SetScript("OnLeave",function(self) self:Hide() end)
    back:Hide()
    return back
end


--- Function to create frame with raid list
---@param btn Frame @frame/button to anchor
---@return Frame instance_frame @Frame with instances
local function createraidlist(btn)
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 4 + 20, 150)

    local i = 1
    EJ_SelectTier(LootFinder.expansion)
    while EJ_GetInstanceByIndex(i, true) ~= nil do
        LootFinder.raids[i] = true
        local _, name, _, _, _, _, buttonImage2 = EJ_GetInstanceByIndex(i, true)
        local button = WeekKeys.UI.Button(nil, back)
        button.name = name
        button:SetPoint("TOPLEFT",(i-1)%4*btnsize+10,-1*math.floor((i-1)/4)*btnsize-10)
        button:SetSize(btnsize,btnsize)
        button:SetID(i)
        button.texture:SetTexture(buttonImage2)
        button.texture:SetAlpha(0.3)
        button.find = false

        function button:enable(bool)
            if bool then
                LootFinder.raids[self:GetID()] = true
                self.texture:SetAlpha(1)
            else
                LootFinder.raids[self:GetID()] = false
                self.texture:SetAlpha(0.3)
            end
            self.find = bool
        end

        button:SetScript("OnClick",function(self)
            self:enable(not self.find)
            LootFinder:Find()
        end)

        button:SetScript("OnEnter",function(self)
            GameTooltip:Hide();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave",function()
            GameTooltip:Hide();
        end)

        i = i + 1
    end
    local diff_names = {
        PLAYER_DIFFICULTY1, -- normal
        PLAYER_DIFFICULTY2, -- heroic
        PLAYER_DIFFICULTY6, -- mythic
        PLAYER_DIFFICULTY3  -- raid finder
    }
    local diff_ids = {
        14, -- normal
        15, -- heroic
        16, -- mythic
        17  -- raid finder
    }
    for i = 1, 4 do
        local checkbtn = CreateFrame("CheckButton", "WeekKeys_RaidChoose"..i, back, "ChatConfigCheckButtonTemplate")
        checkbtn:SetPoint("TOPLEFT", 5, -(i+1) *20-20)
        checkbtn.val = diff_ids[i]
        _G["WeekKeys_RaidChoose"..i.."Text"]:SetText(diff_names[i])
        checkbtn:SetScript("OnClick",function(self)
            for j = 1,4 do
                _G["WeekKeys_RaidChoose"..j]:SetChecked(false)
            end
            self:SetChecked(true)
            LootFinder.raid_difficult = self.val

            LootFinder:Find()
        end)
    end
    table.wipe(diff_names)
    diff_names = nil
    table.wipe(diff_ids)
    diff_ids = nil

    hide_frames[#hide_frames + 1] = back
    --back:SetScript("OnLeave",function(self) self:Hide() end)
    back:Hide()
    return back
end

--- Function to create frame with pvp tier selection
---@param btn Frame @frame/button to anchor
---@return Frame mplus_frame @frame with pvp tier selection
local function createpvplist(btn)
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    back:SetSize(120, 130)
    local nopvp = CreateFrame("CheckButton", "WeekKeys_PvPChoose0", back, "ChatConfigCheckButtonTemplate")
    nopvp:SetPoint("TOPLEFT", 5, -5)
    nopvp.val = 0
    nopvp:SetChecked(true)
    _G["WeekKeys_PvPChoose0Text"]:SetText(DISABLE)
    nopvp:SetScript("OnClick",function(self)
        for j = 0,5 do
            _G["WeekKeys_PvPChoose"..j]:SetChecked(false)
        end
        self:SetChecked(true)
        LootFinder.pvptier = self.val

        LootFinder:Find()
    end)
    local rating = {
        "0-1399",
        "1400-1599",
        "1600-1799",
        "1800-2099",
        "2100-2399",
        "2400+"
    }
    for i = 0, 4 do
        local checkbtn = CreateFrame("CheckButton", "WeekKeys_PvPChoose"..(i+1), back, "ChatConfigCheckButtonTemplate")
        checkbtn:SetPoint("TOPLEFT", 5, -(i+1) *20-5)
        checkbtn.val = i+1
        checkbtn.tooltip = rating[i+1]
        _G["WeekKeys_PvPChoose"..(i+1).."Text"]:SetText(_G["PVP_RANK_".. i .."_NAME"])
        checkbtn:SetScript("OnClick",function(self)
            for j = 0,5 do
                _G["WeekKeys_PvPChoose"..j]:SetChecked(false)
            end
            self:SetChecked(true)
            LootFinder.pvptier = self.val

            LootFinder:Find()
        end)
    end
    hide_frames[#hide_frames + 1] = back
    back:Hide()
    return back
--[[
    local pvpnames = {
        PVP_RANK_0_NAME,
        PVP_RANK_1_NAME,
        PVP_RANK_2_NAME,
        PVP_RANK_3_NAME,
        PVP_RANK_4_NAME,
        PVP_RANK_5_NAME
    }--]]

end



--- Function to create frame with m+ levels
---@param btn Frame @frame/button to anchor
---@return Frame mplus_frame @frame with m+ choose
local function createmlevel(btn)
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 30
    back:SetSize(btnsize * 5 + 20, btnsize * 4 + 20)

    for i = 1, 15 do
        local button = WeekKeys.UI.Button(nil, back)
        button:SetSize(btnsize, btnsize)
        button:SetPoint("TOPLEFT",(i-1)%5*btnsize+10,-1*math.floor((i-1)/5)*btnsize-10)

        button:SetText(i == 1 and 0 or i)
        button:SetID(i == 1 and 0 or i)

        button:SetScript("OnClick",function (self)
            local id = self:GetID()
            local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(max(1,id))

            if wchest then
                LootFinder.milvl = chest
            else
                LootFinder.milvl = key
            end
            LootFinder.mlevel = id
            btn:SetText(LootFinder.mlevel .. (wchest and "|Tinterface/worldmap/treasurechest_64.blp:20:20|t" or ""))
            LootFinder:Find()
        end)

    end
    local chesckbtn = CreateFrame("CheckButton", "WeekKeys_WeeklyReward", back, "ChatConfigCheckButtonTemplate");
    chesckbtn:SetPoint("TOPLEFT", 10, -btnsize * 3 -10);
    WeekKeys_WeeklyRewardText:SetText(MYTHIC_PLUS_WEEKLY_BEST);
    chesckbtn:SetChecked(true)
    chesckbtn:SetScript("OnClick",function(self)
        local checked = self:GetChecked()
        local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(max(1,mlevel))

        if checked == true then
            LootFinder.milvl = chest
        else
            LootFinder.milvl = key
        end
        wchest = checked
        btn:SetText(LootFinder.mlevel .. (wchest and "|Tinterface/worldmap/treasurechest_64.blp:20:20|t" or ""))
        LootFinder:Find()
    end);
    hide_frames[#hide_frames + 1] = back

    back:Hide()
    return back
end

--- Function to create frame with stat choose
---@param btn Frame @frame to anchor
---@return Frame stat_frame @stat frame
local function createfilters(btn)
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)

    local displayname = {
    --    SPEC_FRAME_PRIMARY_STAT_STRENGTH, -- comment out because useless
    --    SPEC_FRAME_PRIMARY_STAT_AGILITY, -- comment out because useless
    --    SPEC_FRAME_PRIMARY_STAT_INTELLECT, -- comment out because useless
        STAT_CRITICAL_STRIKE,
        STAT_HASTE,
        STAT_VERSATILITY,
        STAT_MASTERY
    }
    local values = {
    --    'ITEM_MOD_STRENGTH_SHORT', -- comment out because useless
    --    'ITEM_MOD_AGILITY_SHORT', -- comment out because useless
    --    'ITEM_MOD_INTELLECT_SHORT', -- comment out because useless
        'ITEM_MOD_CRIT_RATING_SHORT',
        'ITEM_MOD_HASTE_RATING_SHORT',
        'ITEM_MOD_VERSATILITY',
        'ITEM_MOD_MASTERY_RATING_SHORT'
    }
    back:SetSize(150,10 + #values * 20)
    for i = 1, #values do
        local checkbtn = CreateFrame("CheckButton", "WeekKeys_StatChoose"..i, back, "ChatConfigCheckButtonTemplate")
        checkbtn:SetPoint("TOPLEFT", 5, -i*20+15)
        checkbtn.val = values[i]
        _G["WeekKeys_StatChoose"..i.."Text"]:SetText(displayname[i])
        checkbtn:SetScript("OnClick",function(self)
            local checked = self:GetChecked()
            if checked == true then
                LootFinder.stats[self.val] = true
            else
                LootFinder.stats[self.val] = nil
            end
            LootFinder:Find()
        end)
    end
    hide_frames[#hide_frames + 1] = back
    back:Hide()
    return back
    --[[
        SPEC_FRAME_PRIMARY_STAT_STRENGTH    'ITEM_MOD_STRENGTH_SHORT'
        SPEC_FRAME_PRIMARY_STAT_AGILITY     'ITEM_MOD_AGILITY_SHORT'
        SPEC_FRAME_PRIMARY_STAT_INTELLECT   'ITEM_MOD_INTELLECT_SHORT'
        STAT_CRITICAL_STRIKE                'ITEM_MOD_CRIT_RATING_SHORT'
        STAT_HASTE                          'ITEM_MOD_HASTE_RATING_SHORT'
        STAT_VERSATILITY                    'ITEM_MOD_VERSATILITY'
        STAT_MASTERY                        'ITEM_MOD_MASTERY_RATING_SHORT'
    ]]
end



--mylist = nil
WeekKeys.AddInit(function()
    arrayOfElements[1] = CreateFrame('Frame')
   -- mylist = arrayOfElements[1]
    arrayOfElements[1]:SetFrameStrata("BACKGROUND")
    arrayOfElements[1]:SetSize(10,10)
    arrayOfElements[1]:SetScript("OnShow",function()
        WeekKeys.WeekFrame.ScrollFrame:ClearAllPoints()
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("TOPLEFT", WeekKeys.WeekFrame, "TOPLEFT", 4, -100);
        WeekKeys.WeekFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", WeekKeys.WeekFrame, "BOTTOMRIGHT", -5, 5);
    end)
    arrayOfElements[1]:Hide()

    local class_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    class_label:SetSize(40, 20)
    class_label:SetPoint("TOPLEFT", 16, -30)
    class_label:SetText(CLASS)
    class_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = class_label
    -- class btn
    local class_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    class_btn:SetSize(30,30)
    class_btn:SetPoint("TopLeft",20,-50)
    class_btn.texture:SetTexture(QUESTION_MARK_ICON)
    class_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createmyclasslist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    class_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(CLASS)
        GameTooltip:Show()
    end)

    class_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    class_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = class_btn

    local spec_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spec_label:SetSize(40, 20)
    spec_label:SetPoint("TOPLEFT", 56, -30)
    spec_label:SetText(SPECIALIZATION)
    spec_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = spec_label
    -- spec btn
    local spec_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    spec_btn:SetSize(30,30)
    spec_btn:SetPoint("Topleft",60,-50)
    spec_btn.texture:SetTexture(QUESTION_MARK_ICON)
    spec_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createspeclist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    spec_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(SPECIALIZATION)
        GameTooltip:Show()
    end)

    spec_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    spec_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = spec_btn

    local slot_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slot_label:SetSize(40, 20)
    slot_label:SetPoint("TOPLEFT", 96, -30)
    slot_label:SetText(L["SLOT_ABBR"])
    slot_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = slot_label
    -- slot btn
    local slot_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    slot_btn:SetSize(30,30)
    slot_btn:SetPoint("Topleft",100,-50)
    slot_btn.texture:SetTexture(QUESTION_MARK_ICON)
    slot_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createslotlist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    slot_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["SLOT_ABBR"])
        GameTooltip:Show()
    end)

    slot_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    slot_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = slot_btn

    local instance_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instance_label:SetSize(40, 20)
    instance_label:SetPoint("TOPLEFT", 136, -30)
    instance_label:SetText(INSTANCE)
    instance_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = instance_label
    -- instances
    local instance_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    instance_btn:SetSize(30,30)
    instance_btn:SetPoint("Topleft",140,-50)
    instance_btn.texture:SetTexture('interface/minimap/objecticonsatlas.blp')
    --                      0.1728515625,0.1943359375,0.912109375,0.955078125
    instance_btn.texture:SetTexCoord(0.1728515625,0.1943359375,0.912109375,0.955078125)
    instance_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createinstancelist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    instance_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(INSTANCE)
        GameTooltip:Show()
    end)

    instance_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    instance_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = instance_btn

    local raid_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raid_label:SetSize(40, 20)
    raid_label:SetPoint("TOPLEFT", 176, -30)
    raid_label:SetText(RAID)
    raid_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = raid_label

    local raid_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    raid_btn:SetSize(30,30)
    raid_btn:SetPoint("Topleft",180,-50)
    raid_btn.texture:SetTexture('interface/minimap/objecticonsatlas.blp')
    --                      0.5009765625,0.5224609375,0.294921875,0.337890625
    raid_btn.texture:SetTexCoord(0.5009765625,0.5224609375,0.294921875,0.337890625)
    raid_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createraidlist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    raid_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(RAID)
        GameTooltip:Show()
    end)

    raid_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    raid_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = raid_btn

    local pvp_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pvp_label:SetSize(40, 20)
    pvp_label:SetPoint("TOPLEFT", 216, -30)
    pvp_label:SetText("PvP")
    pvp_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = pvp_label
    --PLAYER_V_PLAYER
    local pvp_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    pvp_btn:SetSize(30,30)
    pvp_btn:SetPoint("Topleft",220,-50)
    pvp_btn.texture:SetTexture('Interface/TalentFrame/TalentFrameAtlas.blp')
    pvp_btn.texture:SetTexCoord(0.75390625,0.93359375,0.1015625,0.1435546875)
    pvp_btn:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createpvplist(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    pvp_btn:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(PLAYER_V_PLAYER)
        GameTooltip:Show()
    end)

    pvp_btn:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    pvp_btn:Hide()
    arrayOfElements[#arrayOfElements + 1] = pvp_btn


    local key_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    key_label:SetSize(40, 20)
    key_label:SetPoint("TOPLEFT", 256, -30)
    key_label:SetText(L["LEVEL_ABBR"])
    key_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = key_label
    -- keylevel
    local keylevel = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    keylevel:SetSize(30,30)
    keylevel:SetPoint("Topleft",260,-50)
    keylevel:SetText(15 .. "|Tinterface/worldmap/treasurechest_64.blp:20:20|t")
    keylevel:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createmlevel(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    keylevel:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(LEVEL)
        GameTooltip:Show()
    end)

    keylevel:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    keylevel:Hide()
    arrayOfElements[#arrayOfElements + 1] = keylevel

    local stat_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    stat_label:SetSize(40, 20)
    stat_label:SetPoint("TOPLEFT", 296, -30)
    stat_label:SetText(L["SCORE_POWER_UPS"])
    stat_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = stat_label
    -- stat filters
    local statfilter = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    statfilter:SetSize(30,30)
    statfilter:SetPoint("Topleft",300,-50)
    statfilter:SetText("???")
    statfilter:SetScript("OnClick",function(self)
        self.showframe = self.showframe or createfilters(self)
        if self.showframe:IsShown() then
            return self.showframe:Hide()
        end
        for _,v in pairs(hide_frames) do v:Hide() end
        self.showframe:Show()
    end)
    statfilter:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["SCORE_POWER_UPS"])
        GameTooltip:Show()
    end)

    statfilter:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)
    statfilter:Hide()
    arrayOfElements[#arrayOfElements + 1] = statfilter


    -- "dungeons"
    local label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",25,-80)
    label:SetSize(200,20)
    label:SetText(DUNGEONS)
    label:Hide()
    local fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(200,20)
    label:SetScript("OnClick", function() LootFinder.SortBy("name") update() end)
    arrayOfElements[#arrayOfElements + 1] = label
    -- list of globalstrings dungeon/instance
    -- CALENDAR_TYPE_DUNGEON
    -- INSTANCE_CHAT
    -- INSTANCE_CHAT_MESSAGE
    -- ENCOUNTER_JOURNAL_INSTANCE
    -- DUNGEONS
    -- INSTANCE
    -- CHAT_MSG_INSTANCE_CHAT
    -- GUILD_CHALLENGE_TYPE1
    -- GUILD_INTEREST_DUNGEON
    -- VOICE_CHANNEL_NAME_INSTANCE
    -- LFG_TYPE_DUNGEON

    --
    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",238,-80)
    label:SetSize(50,20)
    label:SetText(L["SPEC_FRAME_PRIMARY_STAT"])
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(50,20)
    label:SetScript("OnClick", function() LootFinder.SortBy("mainstat") update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",288,-80)
    label:SetSize(50,20)
    label:SetText(L["SPELL_CRIT_CHANCE"])
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(50,20)
    label:SetScript("OnClick", function() LootFinder.SortBy("crit") update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",338,-80)
    label:SetSize(50,20)
    label:SetText(STAT_HASTE)
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(50,20)
    label:SetScript("OnClick", function() LootFinder.SortBy("haste") update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",388,-80)
    label:SetSize(50,20)
    label:SetText(STAT_MASTERY)
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(50,20)
    label:SetScript("OnClick", function() LootFinder.SortBy("mastery") update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",438,-80)
    label:SetSize(50,20)
    label:SetText(L["STAT_VERSATILITY"])
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(50,20)
    label:Hide()
    label:SetScript("OnClick", function() LootFinder.SortBy("versality") update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    -- result printing
    hooksecurefunc(LootFinder, "Find",update)

    WeekKeys.AddButton(L["lootfinder"],arrayOfElements)
end)
