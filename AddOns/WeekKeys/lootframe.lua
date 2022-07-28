local arrayOfElements = {}
local L = WeekKeys.L
local WeekFrame = WeekKeys.WeekFrame

local loot_btns = {}
local hide_frames = {}
local fav_mode = false
local sort = nil

local lootfinder = LF:New({},'WeekKeysDB')

local function update()
    for i = #loot_btns, #lootfinder.results do
        local btn = WeekKeys.UI.LootFinderButton(nil, arrayOfElements[1])
        btn.LF = lootfinder
        loot_btns[#loot_btns + 1] = btn
        btn:SetSize(592,20)
        btn:SetID(i + 1)
        btn:SetPoint("TOPLEFT",4,-(i)*20)
        btn:SetScript("OnClick",function(self)
            local item = lootfinder.results[self:GetID()]

            lootfinder:Favorite(item)
            update()
        end)
    end
    for i = 1, #loot_btns do -- hide all buttons
        loot_btns[i]:Hide()
    end
    if fav_mode then
        if not WeekKeysDB.FavLoot then return end
        local db
        if lootfinder.spec > 0 then
            db = WeekKeysDB.FavLoot[lootfinder.spec] or {}
        elseif lootfinder.class > 0 then
            db = {}
            if WeekKeysDB.FavLoot[lootfinder.class] then
                for _, value in pairs(WeekKeysDB.FavLoot[lootfinder.class]) do
                    db[#db + 1] = value
                end
            end
            for _, specID in pairs(LF.tables.class_spec[lootfinder.class]) do
                if WeekKeysDB.FavLoot[specID] then
                    for _, value in pairs(WeekKeysDB.FavLoot[specID]) do
                        db[#db + 1] = value
                    end
                end
            end
        else
            LootFinder.loot_list = {}
        end

        if sort then
            table.sort(db,function (a,b)
                return a[sort] > b[sort]
            end)
        end

        for index, loot in ipairs(db) do
            local btn = loot_btns[index]
            btn.boss = loot.boss
            btn.dung = loot.name
            btn:SetFavorite(loot.itemlink,"WeekKeysDB")
            btn:SetSource(loot.source)
            btn:SetIcon(loot.icon)
            btn:SetDungeon(loot.name)
            btn.link = loot.itemlink
            btn:SetMainAtr(loot.mainstat)
            btn:SetCrit(loot.crit)
            btn:SetHaste(loot.haste)
            btn:SetMastery(loot.mastery)
            btn:SetVersality(loot.versality)
            btn:Show()
        end
    else

        if sort then
            table.sort(lootfinder.results,function (a,b)
                return a[sort] > b[sort]
            end)
        end

        for index, loot in ipairs(lootfinder.results) do
            local btn = loot_btns[index]
            btn.boss = loot.boss
            btn.dung = loot.name
            btn:SetFavorite(loot.itemlink,"WeekKeysDB")
            btn:SetSource(loot.source)
            btn:SetIcon(loot.icon)
            btn:SetDungeon(loot.name)
            btn.link = loot.itemlink
            btn:SetMainAtr(loot.mainstat)
            btn:SetCrit(loot.crit)
            btn:SetHaste(loot.haste)
            btn:SetMastery(loot.mastery)
            btn:SetVersality(loot.versality)
            btn:Show()
        end
    end

end
--- Function to create frame with class icons
---@param btn Frame @frame/button to anchor
---@return Frame class_frame @Frame with class icons
local function createmyclasslist(btn)
    -- background for class buttons
    local back = CreateFrame("Frame",nil,btn,"InsetFrameTemplate")
    back:SetPoint("BOTTOMLEFT",0,30)
    local btnsize = 35
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

            -- specrefresh()
            btn.texture:SetTexture(self.texture:GetTexture())
            local _, class, _ = GetClassInfo(self:GetID())
            local coords = CLASS_ICON_TCOORDS[class]
            btn.texture:SetTexCoord(unpack(coords))
            back:Hide()

            lootfinder:SetClass(self:GetID())
            lootfinder:Search()

            update()
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
    local btnsize = 35
    back:SetSize(btnsize * 3 + 20, btnsize * 2 + 20)
    for i = 1, 5 do
        local button = WeekKeys.UI.Button(nil, back)
        button:SetPoint("TOPLEFT",(i-1)%3*btnsize+2,-1*math.floor((i-1)/3)*btnsize-2)
        button:SetSize(btnsize,btnsize)
        button:SetScript("OnClick",function(self)

            btn.texture:SetTexture(self.texture:GetTexture())
            back:Hide()

            lootfinder:SetSpec(self:GetID())
            lootfinder:Search()

            update()
        end)
        spec_btn_list[i] = button
    end

    back:SetScript("OnShow",function(self)
        if not LF.tables.class_spec[lootfinder.class] then return self:Hide() end
        local len = #LF.tables.class_spec[lootfinder.class]
        --if len == 0 then self:Hide() return end -- hide if no class choosen
        local spec_ids = LF.tables.class_spec[lootfinder.class]
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
    local btnsize = 35
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

            btn.texture:SetTexture(self.texture:GetTexture())
            back:Hide()

            lootfinder:SetSlot(self:GetID())
            lootfinder:Search()

            update()
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
    local btnsize = 35
    back:SetSize(btnsize * 4 + 20, btnsize * 4 + 20)

    local i = 1
    EJ_SelectTier(EJ_GetNumTiers())
    while EJ_GetInstanceByIndex(i, false) ~= nil do

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
                lootfinder.instances[self:GetID()] = false
                self.texture:SetAlpha(1)
            else
                lootfinder.instances[self:GetID()] = true
                self.texture:SetAlpha(0.3)
            end
            self.find = bool
        end

        button:SetScript("OnClick",function(self)
            self:enable(not self.find)
            lootfinder:Search()
            update()
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
    back:SetHeight(math.ceil((i-1)/4)*btnsize+20)

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
    local btnsize = 35
    back:SetSize(btnsize * 4 + 20, 150)

    local i = 1
    EJ_SelectTier(EJ_GetNumTiers())
    while EJ_GetInstanceByIndex(i, true) ~= nil do
        local _, name, _, _, _, _, buttonImage2 = EJ_GetInstanceByIndex(i, true)
        local button = WeekKeys.UI.Button(nil, back)
        button.name = name
        button:SetPoint("TOPLEFT",(i-1)%4*btnsize+10,-1*math.floor((i-1)/4)*btnsize-10)
        button:SetSize(btnsize,btnsize)
        button:SetID(i)
        button.texture:SetTexture(buttonImage2)
        button.texture:SetAlpha(1)
        button.find = true

        function button:enable(bool)
            if bool then
                lootfinder.raids[self:GetID()] = false
                self.texture:SetAlpha(1)
            else
                lootfinder.raids[self:GetID()] = true
                self.texture:SetAlpha(0.3)
            end
            self.find = bool
        end

        button:SetScript("OnClick",function(self)
            self:enable(not self.find)

            lootfinder:Search()

            update()
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

            lootfinder.raid_difficult = self.val
            lootfinder:Search()

            update()
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
        lootfinder.pvptier = self.val
        lootfinder:Search()

        update()
    end)
    local rating = {
        "0-1399",
        "1400-1599",
        "1600-1799",
        "1800-2099",
        "2100+"
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

            lootfinder.pvptier = self.val
            lootfinder:Search()

            update()
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
    local btnsize = 35
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
                lootfinder.milvl = chest
            else
                lootfinder.milvl = key
            end
            lootfinder.mlevel = id
            btn:SetText(lootfinder.mlevel .. (wchest and "|Tinterface/worldmap/treasurechest_64.blp:20:20|t" or ""))

            lootfinder:Search()

            update()
        end)

    end
    local chesckbtn = CreateFrame("CheckButton", "WeekKeys_WeeklyReward", back, "ChatConfigCheckButtonTemplate");
    chesckbtn:SetPoint("TOPLEFT", 10, -btnsize * 3 -10);
    WeekKeys_WeeklyRewardText:SetText(MYTHIC_PLUS_WEEKLY_BEST);
    chesckbtn:SetChecked(true)
    chesckbtn:SetScript("OnClick",function(self)
        local checked = self:GetChecked()
        local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(max(1,lootfinder.mlevel))

        if checked == true then
            lootfinder.milvl = chest
        else
            lootfinder.milvl = key
        end
        lootfinder.chest = not lootfinder.chest
        btn:SetText(lootfinder.mlevel .. (wchest and "|Tinterface/worldmap/treasurechest_64.blp:20:20|t" or ""))

        lootfinder:Search()

        update()
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
                lootfinder.selectedstats[self.val] = true
            else
                lootfinder.selectedstats[self.val] = nil
            end

            lootfinder:Search()

            update()
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
    class_label:SetPoint("TOPLEFT", 20, -30)
    class_label:SetText(CLASS)
    class_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = class_label
    -- class btn
    local class_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    class_btn:SetSize(30,30)
    class_btn:SetPoint("TopLeft",24,-50)
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
    spec_label:SetPoint("TOPLEFT", 65, -30)
    spec_label:SetText(SPECIALIZATION)
    spec_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = spec_label
    -- spec btn
    local spec_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    spec_btn:SetSize(30,30)
    spec_btn:SetPoint("Topleft",69,-50)
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
    slot_label:SetPoint("TOPLEFT", 110, -30)
    slot_label:SetText(L["SLOT_ABBR"])
    slot_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = slot_label
    -- slot btn
    local slot_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    slot_btn:SetSize(30,30)
    slot_btn:SetPoint("Topleft",114,-50)
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
    instance_label:SetPoint("TOPLEFT", 155, -30)
    instance_label:SetText(INSTANCE)
    instance_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = instance_label
    -- instances
    local instance_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    instance_btn:SetSize(30,30)
    instance_btn:SetPoint("Topleft",159,-50)
    instance_btn.texture:SetTexture('interface/minimap/objecticonsatlas.blp')
    --                      0.1728515625,0.1943359375,0.912109375,0.955078125
    instance_btn.texture:SetTexCoord(0.912109375,0.955078125,0.044921875,0.06640625)
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
    raid_label:SetPoint("TOPLEFT", 200, -30)
    raid_label:SetText(RAID)
    raid_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = raid_label

    local raid_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    raid_btn:SetSize(30,30)
    raid_btn:SetPoint("Topleft",204,-50)
    raid_btn.texture:SetTexture('interface/minimap/objecticonsatlas.blp')
    --                      0.5009765625,0.5224609375,0.294921875,0.337890625
    raid_btn.texture:SetTexCoord(0.689453125,0.732421875,0.166015625,0.1875)
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
    pvp_label:SetPoint("TOPLEFT", 245, -30)
    pvp_label:SetText("PvP")
    pvp_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = pvp_label
    --PLAYER_V_PLAYER
    local pvp_btn = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    pvp_btn:SetSize(30,30)
    pvp_btn:SetPoint("Topleft",249,-50)
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
    key_label:SetPoint("TOPLEFT", 290, -30)
    key_label:SetText(L["LEVEL_ABBR"])
    key_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = key_label
    -- keylevel
    local keylevel = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    keylevel:SetSize(30,30)
    keylevel:SetPoint("Topleft",294,-50)
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
    stat_label:SetPoint("TOPLEFT", 335, -30)
    stat_label:SetText(L["SCORE_POWER_UPS"])
    stat_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = stat_label
    -- stat filters
    local statfilter = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    statfilter:SetSize(30,30)
    statfilter:SetPoint("Topleft",339,-50)
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
    label:SetScript("OnClick", function() sort = "name" update() end)
    arrayOfElements[#arrayOfElements + 1] = label


    local fav_label = WeekKeys.WeekFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fav_label:SetSize(40, 20)
    fav_label:SetPoint("TOPLEFT", 380, -30)
    fav_label:SetText(AUCTION_HOUSE_FAVORITES_SEARCH_TOOLTIP_TITLE)
    fav_label:Hide()
    arrayOfElements[#arrayOfElements + 1] = fav_label

    local fav = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    fav:SetSize(30,30)
    fav:SetPoint("Topleft",384,-50)
    fav:Hide()
    fav.texture:SetTexture('Interface/AuctionFrame/AuctionHouse.blp')
    fav.texture:SetTexCoord(0.9580078125,0.9833984375,0.591796875,0.642578125)
    fav:SetScript("OnClick",function(self)
        if fav_mode then
            self.texture:SetTexCoord(0.9580078125,0.9833984375,0.591796875,0.642578125)
            fav_mode = not fav_mode
        else
            self.texture:SetTexCoord(0.9306640625,0.9560546875,0.591796875,0.642578125)
            fav_mode = not fav_mode
        end

        update()
    end)

    fav:SetScript("OnEnter",function(self)
        GameTooltip:Hide();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AUCTION_HOUSE_FAVORITES_SEARCH_TOOLTIP_TITLE)
        GameTooltip:Show()
    end)

    fav:SetScript("OnLeave",function()
        GameTooltip:Hide();
    end)

    arrayOfElements[#arrayOfElements + 1] = fav

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",235,-80)
    label:SetSize(70,20)
    label:SetText(L["SPEC_FRAME_PRIMARY_STAT"])
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(70,20)
    label:SetScript("OnClick", function()
        sort = "mainstat"
        update()
    end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",305,-80)
    label:SetSize(70,20)
    label:SetText(L["SPELL_CRIT_CHANCE"])
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(70,20)
    label:SetScript("OnClick", function()
        sort = "crit"
        update()
    end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",375,-80)
    label:SetSize(70,20)
    label:SetText(STAT_HASTE)
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(70,20)
    label:SetScript("OnClick", function() sort = "haste" update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",445,-80)
    label:SetSize(70,20)
    label:SetText(STAT_MASTERY)
    label:Hide()
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(70,20)
    label:SetScript("OnClick", function() sort = "mastery" update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    label = WeekKeys.UI.Button(nil, WeekKeys.WeekFrame)
    label:SetPoint("TOPLEFT",515,-80)
    label:SetSize(70,20)
    label:SetText(L["STAT_VERSATILITY"])
    fontstr = label:GetFontString()
    label:SetFontString(fontstr)
    fontstr:SetSize(70,20)
    label:Hide()
    label:SetScript("OnClick", function() sort = "versality" update() end)
    arrayOfElements[#arrayOfElements + 1] = label

    WeekKeys.AddButton(L["lootfinder"],arrayOfElements)
end)
