HandyNotes_Draenor = LibStub("AceAddon-3.0"):GetAddon("HandyNotes_Draenor")

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes", true)

local nodes = HandyNotes_Draenor.nodes
local info = {}

local ClickedMapUID = nil
local ClickedCoord = nil

function GetRewardLinkByID(ID)

    if ID ~= nil then

        local _, Reward

        if ID == "824" or ID == "823" then

            Reward = C_CurrencyInfo.GetCurrencyInfo(ID)

            if Reward ~= nil then
                return Reward.name
            end

        else

            _, Reward = GetItemInfo(ID)

            if Reward ~= nil then
                return Reward
            end
        end

    end

    return nil

end

function GetRewardIconByID(ID)

    if ID ~= nil then

        local _, Icon

        if ID == "824" or ID == "823" then
            _, _, Icon = C_CurrencyInfo.GetCurrencyInfo(ID)
        else
            _, _, _, _, Icon = GetItemInfoInstant(ID)
        end

        if Icon ~= nil then
            return Icon
        end

    end

    return Icon_Treasure_Default
end

local function generateMenu(button, level)

    if (level ~= nil) then 

        if (level == 1) then
            info.isTitle = 1
            info.text = "HandyNotes: Draenor"
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)
            
            info.disabled = nil
            info.isTitle = nil
            info.notCheckable = 0
            info.text = "Remove POI from Map"
            info.func = DisablePOI
            info.arg1 = ClickedMapUID
            info.arg2 = ClickedCoord
            UIDropDownMenu_AddButton(info, level)
            
            if HandyNotes_Draenor.db.profile.Integration.TomTom.Loaded == true then
                info.notCheckable = 0
                info.text = "Create TomTom Waypoint"
                info.func = TomTomCreateArrow
                info.arg1 = ClickedMapUID
                info.arg2 = ClickedCoord
                UIDropDownMenu_AddButton(info, level)
            end

            if HandyNotes_Draenor.db.profile.Integration.DBM.Loaded == true then
                if HandyNotes_Draenor.db.profile.Integration.DBM.ArrowCreated == false then
                    info.notCheckable = 0
                    info.text = "Create DBM-Arrow"
                    info.func = DBMCreateArrow
                    info.arg1 = ClickedMapUID
                    info.arg2 = ClickedCoord
                    UIDropDownMenu_AddButton(info, level)
                else
                    info.notCheckable = 0
                    info.text = "Hide DBM-Arrow"
                    info.func = DBMHideArrow
                    UIDropDownMenu_AddButton(info, level)
                end
            end

            info.text = "Restore removed POI's"
            info.func = ResetPOIDatabase
            info.arg1 = nil
            info.arg2 = nil
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)

            info.text = CLOSE
            info.func = function() CloseDropDownMenus() end
            info.arg1 = nil
            info.arg2 = nil
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)
            
        end
    end
end

function ResetPOIDatabase()
    wipe(HandyNotes_Draenor.db.char)
    HandyNotes_Draenor:Refresh()
end

function DisablePOI(button, MapUID, coord)

    local POI = nodes[MapUID][coord][2]

    if (POI ~= nil) then
        HandyNotes_Draenor.db.char[POI] = true;
    end

    HandyNotes_Draenor:Refresh()
end

function GetZoneByMapID(ID)

    if ID == 525 then

        return "FrostfireRidge"

    elseif ID == 534 then

        return "TanaanJungle"

    elseif ID == 535 then

        return "Talador"

    elseif ID == 550 then

        return "Nagrand"

    elseif ID == 543 then

        return "Gorgrond"

    elseif ID == 539 then

        return "ShadowmoonValley"

    elseif ID == 542 then

        return "SpiresOfArak"

    end

    return "Unknown Zone"

end

function TomTomCreateArrow(button, MapUID, coord)
    if HandyNotes_Draenor.db.profile.Integration.TomTom.Loaded == true then

        local x, y = HandyNotes:getXY(coord)

        local Zone = nodes[MapUID][coord][1]
        local ID = nodes[MapUID][coord][2]
        local Name = nodes[MapUID][coord][3]
        local Note = nodes[MapUID][coord][4]
        local Icon = nodes[MapUID][coord][5]
        local Tag = nodes[MapUID][coord][6]
        local ItemID = nodes[MapUID][coord][7]
        local AchievementID = nodes[MapUID][coord][9]
        local AchievementCriteriaIndex = nodes[MapUID][coord][8]

        local ArrowDescription = ""

        if Name ~= nil then
            if Zone ~= nil then
                ArrowDescription = ArrowDescription.."\n"..Name;
                ArrowDescription = ArrowDescription.."\n"..Zone;

                if ItemID ~= nil then
                    ArrowDescription = ArrowDescription.."\n\n"
                    ArrowDescription = ArrowDescription..GetRewardLinkByID(ItemID)
                end

                if Note ~= nil and Note ~= nil then
                    ArrowDescription = ArrowDescription.."\n\n"
                    ArrowDescription = ArrowDescription.."\n"..Note
                end
            end
        end

        TomTom:AddWaypoint(MapUID, x, y, {
            title = ArrowDescription,
            persistent = nil,
            minimap = true,
            world = true
        })
    end
end

function DBMCreateArrow(button, MapUID, coord)
    if HandyNotes_Draenor.db.profile.Integration.DBM.Loaded == true then

        if HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote == nil then
        
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote = DBMArrow:CreateFontString(nil, "OVERLAY", "GameTooltipText")
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote:SetWidth(400)
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote:SetHeight(100)
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote:SetPoint("CENTER", DBMArrow, "CENTER", 0, -70)
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote:SetTextColor(1, 1, 1, 1)
            HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote:SetJustifyH("CENTER")
            DBMArrow.Desc = HandyNotes_Draenor.db.profile.Integration.DBM.ArrowNote

        end

        local x, y = HandyNotes:getXY(coord)

        local Zone = nodes[MapUID][coord][1]
        local ID = nodes[MapUID][coord][2]
        local Name = nodes[MapUID][coord][3]
        local Note = nodes[MapUID][coord][4]
        local Icon = nodes[MapUID][coord][5]
        local Tag = nodes[MapUID][coord][6]
        local ItemID = nodes[MapUID][coord][7]
        local AchievementID = nodes[MapUID][coord][9]
        local AchievementCriteriaIndex = nodes[MapUID][coord][8]

        local ArrowDescription = ""

        if Name ~= nil then
            if Zone ~= nil then
                ArrowDescription = ArrowDescription.."\n"..Name;
                ArrowDescription = ArrowDescription.."\n"..Zone;

                if ItemID ~= nil then
                    ArrowDescription = ArrowDescription.."\n\n"
                    ArrowDescription = ArrowDescription..GetRewardLinkByID(ItemID)
                end

                if Note ~= nil and Note ~= nil then
                    ArrowDescription = ArrowDescription.."\n\n"
                    ArrowDescription = ArrowDescription.."\n"..Note
                end
            end
        end

		if not DBMArrow.Desc:IsShown() then
			DBMArrow.Desc:Show()
		end

		DBMArrow.Desc:SetText(ArrowDescription)
        DBM.Arrow:ShowRunTo(x * 100, y * 100, nil, nil, true)

        HandyNotes_Draenor.db.profile.Integration.DBM.ArrowCreated = true
    end
end

function DBMHideArrow()
    DBM.Arrow:Hide(true)
    HandyNotes_Draenor.db.profile.Integration.DBM.ArrowCreated = false
end

function HandyNotes_Draenor:OnEnter(MapUID, coord)

    local Zone = GetZoneByMapID(MapUID)
    local ItemHeader = nodes[MapUID][coord][3]
    local ItemNote = nodes[MapUID][coord][4]
    local ItemID = nodes[MapUID][coord][7]
    local Reward = GetRewardLinkByID(ItemID)

    local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip

    if self:GetCenter() > UIParent:GetCenter() then
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    if Reward == nil and ItemID ~= nil then

        HandyNotes_Draenor:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()

            Reward = GetRewardLinkByID(ItemID)

            if IsShiftKeyDown() == false and HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == false or IsShiftKeyDown() == true and HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == true then

                tooltip:SetText(ItemHeader) 

                if ItemNote ~= nil and HandyNotes_Draenor.db.profile.Settings.General.ShowNotes == true then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Additional Information")
                    tooltip:AddLine(ItemNote, 1, 1, 1, 1)
                end

                if Reward ~= nil then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Reward")
                    tooltip:AddLine(Reward, 1, 1, 1, 1)
                    tooltip:AddLine(" ")

                    if HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == true then
                        tooltip:AddLine("Release Shift to display the Reward")
                    else
                        tooltip:AddLine("Press Shift to display the Reward")
                    end
                end
            
            else
                if Reward ~= nil and string.match(Reward, ":") then
                    tooltip:SetHyperlink(Reward)
                else
                    if ItemNote ~= nil and HandyNotes_Draenor.db.profile.Settings.General.ShowNotes == true then
                        tooltip:AddLine(" ")
                        tooltip:AddLine("Note")
                        tooltip:AddLine(ItemNote, 1, 1, 1, 1)
                    end
    
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Reward")
    
                    if Reward ~= nil then
                        tooltip:AddLine(" ")
                        tooltip:AddLine("Reward")
                        tooltip:AddLine(Reward, 1, 1, 1, 1)
                    end
                end
            end

            HandyNotes_Draenor:UnregisterEvent("GET_ITEM_INFO_RECEIVED")

            tooltip:Show()

        end)

    else

        if IsShiftKeyDown() == false and HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == false or IsShiftKeyDown() == true and HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == true then

            tooltip:SetText(ItemHeader)

            if ItemNote ~= nil and HandyNotes_Draenor.db.profile.Settings.General.ShowNotes == true then
                tooltip:AddLine(" ")
                tooltip:AddLine("Note")
                tooltip:AddLine(ItemNote, 1, 1, 1, 1)
            end

            if Reward ~= nil then
                tooltip:AddLine(" ")
                tooltip:AddLine("Reward")
                tooltip:AddLine(Reward, 1, 1, 1, 1)
                tooltip:AddLine(" ")

                if HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults == true then
                    tooltip:AddLine("Release Shift to display the Reward")
                else
                    tooltip:AddLine("Press Shift to display the Reward")
                end
            end

        else 
            
            if Reward ~= nil and string.match(Reward, ":") then
                tooltip:SetHyperlink(Reward)
            else
                
                tooltip:SetText(ItemHeader)

                if ItemNote ~= nil and HandyNotes_Draenor.db.profile.Settings.General.ShowNotes == true then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Note")
                    tooltip:AddLine(ItemNote, 1, 1, 1, 1)
                end

                if Reward ~= nil then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Reward")
                    tooltip:AddLine(Reward, 1, 1, 1, 1)
                end

            end
        end

        tooltip:Show()

    end
    
end

function HandyNotes_Draenor:OnClick(button, down, MapUID, coord)
    if button == "RightButton" and down then
        ClickedMapUID = MapUID
        ClickedCoord = coord
        ToggleDropDownMenu(1, nil, HandyNotes_DraenorDropdownMenu, self, 0, 0)
    end
end

function HandyNotes_Draenor:OnLeave()
    if self:GetParent() == WorldMapButton then
        WorldMapTooltip:Hide()
    else
        GameTooltip:Hide()
    end
end

function HandyNotes_Draenor:WorldEnter()

    HandyNotes_Draenor.db.profile.Integration.DBM.Loaded = IsAddOnLoaded("DBM-Core")
    HandyNotes_Draenor.db.profile.Integration.TomTom.Loaded = IsAddOnLoaded("TomTom")
    
    local HandyNotes_DraenorDropdownMenu = CreateFrame("Frame", "HandyNotes_DraenorDropdownMenu")
    HandyNotes_DraenorDropdownMenu.displayMode = "MENU"
    HandyNotes_DraenorDropdownMenu.initialize = generateMenu
    
    self:RegisterWithHandyNotes()

    if HandyNotes.plugins["HandyNotes_Draenor"] == nil then
        HandyNotes:RegisterPluginDB("HandyNotes_Draenor", self, HandyNotes_Draenor.options)
    end

    self:RegisterBucketEvent({"CRITERIA_UPDATE", "CRITERIA_EARNED", "NEW_TOY_ADDED", "NEW_MOUNT_ADDED"}, 2, "LOOT_CLOSED")

end

function HandyNotes_Draenor:WorldLeave()

    HandyNotes.plugins["HandyNotes_Draenor"] = nil
    self = nil

end

function HandyNotes_Draenor:RegisterWithHandyNotes()
    local function iter(t, prestate)

        if t ~= nil then

            local state, value = next(t, prestate)

            while state do

                local Zone = GetZoneByMapID(value[1])
                local ID = value[2]
                local Icon = value[5]
                local Tag = value[6]
                local ItemID = value[7]
                local AchievementID = value[9]
                local AchievementCriteriaIndex = value[8]

                if ID and Zone then

                    if Tag == "Rare" then

                        if self.db.profile.Zones[Zone]["Rares"] then

                            if self.db.profile.Settings.Rares.ShowAlreadyKilled == true or not self.db.char[ID] then

                                if C_QuestLog.IsQuestFlaggedCompleted(ID) == false or self.db.profile.Settings.Rares.ShowAlreadyKilled == true then

                                    if AchievementID ~= nil and AchievementCriteriaIndex ~= nil then

                                        local _, _, Completed = GetAchievementCriteriaInfoByID(AchievementID, AchievementCriteriaIndex)

                                        if Completed == false then
                                            return state, nil, Icon, self.db.profile.Settings.Rares.IconScale, self.db.profile.Settings.Rares.IconAlpha
                                        end

                                    else
                                        return state, nil, Icon, self.db.profile.Settings.Rares.IconScale, self.db.profile.Settings.Rares.IconAlpha
                                    end

                                end

                            end

                        end

                    elseif string.match(Tag, "Treasure") then

                        if self.db.profile.Zones[Zone]["Treasures"] then

                            if self.db.profile.Settings.Treasures.ShowAlreadyCollected == true or not self.db.char[ID] then

                                if string.match(Tag, "Quest") then

                                    if C_QuestLog.IsQuestFlaggedCompleted(AchievementCriteriaIndex) or self.db.profile.Settings.Treasures.ShowAlreadyCollected == true then

                                        if ItemID ~= nil then
                                            return state, nil, GetRewardIconByID(ItemID), self.db.profile.Settings.Treasures.IconScale, self.db.profile.Settings.Treasures.IconAlpha
                                        end

                                    end

                                else

                                    if C_QuestLog.IsQuestFlaggedCompleted(ID) == false or self.db.profile.Settings.Treasures.ShowAlreadyCollected == true then

                                        if ItemID ~= nil then
                                            return state, nil, GetRewardIconByID(ItemID), self.db.profile.Settings.Treasures.IconScale, self.db.profile.Settings.Treasures.IconAlpha
                                        else
                                            return state, nil, Icon, self.db.profile.Settings.Treasures.IconScale, self.db.profile.Settings.Treasures.IconAlpha
                                        end
    
                                    end

                                end

                            end

                        end

                    elseif string.match(Tag, "Mount") then

                        if self.db.profile.Mounts[Tag] and not self.db.char[ID] then

                            return state, nil, Icon, self.db.profile.Settings.Rares.IconScale, self.db.profile.Settings.Rares.IconAlpha

                        end

                    end
                    
                end

                state, value = next(t, state)
            end
        end
    end

    function HandyNotes_Draenor:GetNodes2(uiMapID, minimap)
        return iter, nodes[uiMapID], nil
    end

    self:Refresh()
end

function HandyNotes_Draenor:LOOT_CLOSED()
    if GetZoneByMapID(C_Map.GetBestMapForUnit("player")) ~= "Unknown Zone" then
        self:Refresh()
    end
end


function HandyNotes_Draenor:Refresh()
    self:SendMessage("HandyNotes_NotifyUpdate", "HandyNotes_Draenor")
end