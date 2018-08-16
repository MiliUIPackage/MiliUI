local DGV = DugisGuideViewer
local DGU
if not DGV then return end

local Guides = DGV:RegisterModule("Guides")
local _
local BF = LibStub("LibBabble-Faction-3.0")
local BFR = BF:GetReverseLookupTable()

DGV.Guides = Guides

local AceGUI = LibStub("AceGUI-3.0")

guidePercentagesCache = {}

function Guides:Initialize()
    guidesMainScroll = GUIUtils:CreateScrollFrame(DugisMain)
    guidesMainScroll.scrollBar:SetHeight(322)
    
    --Preparing data for macros
    macrosDataDefaults = LuaUtils:clone(macrosData)

    if not DugisGuideUser.macrosData then 
        DugisGuideUser.macrosData = LuaUtils:clone(macrosData)
    else
        LuaUtils:foreach(macrosData, function(categoryData, categoryName)
            if not DugisGuideUser.macrosData[categoryName] then
                DugisGuideUser.macrosData[categoryName] = LuaUtils:clone(categoryData)
            else
                local userCategoryData = DugisGuideUser.macrosData[categoryName]
                LuaUtils:foreach(categoryData, function(macroData, index)
                
                    local alreadyExistsInUserData = false
                    LuaUtils:foreach(userCategoryData, function(userMacroData, index1)
                        if userMacroData.name == macroData.name and not userMacroData.isEditable then
                            alreadyExistsInUserData = true
                        end
                    end)
                
                    if not alreadyExistsInUserData then
                        userCategoryData[#userCategoryData + 1] = LuaUtils:clone(macroData)
                    end
                end)
            end
        end)
    end
    

	DGU = DugisGuideUser
    if DGU.RecentGuides == nil then
        DGU.RecentGuides = {}
    end
    
    --LastIndices[heading].lastIndex
    if DGU.RecentGuides.LastIndices == nil then
        DGU.RecentGuides.LastIndices = {}
    end
    
    --Guides[heading][1..5]
    if DGU.RecentGuides.Guides == nil then
        DGU.RecentGuides.Guides = {}
    end
    
    --Headings[1...n]
    if DGU.RecentGuides.Categories == nil then
        DGU.RecentGuides.Categories = {}
    end
    
    
    
	local Main, DebugPrint, RegisterFunctionReaction = DugisMain, DGV.DebugPrint, DGV.RegisterFunctionReaction
	local NPCJournalFrame

	local GetQuestDifficultyColor = GetQuestDifficultyColor
	local visualRows
	
	local CurrentAction
	local CurrentQuestName
	local JustTurnedInQID = -1 --A quest that has just been turned in has its isComplete status indeterminate in quest log
	local CurrentTag
	
	local i
	local L = DugisLocals
	local crowheight
	
	function GetCurrentGuideLeftShouldScroll()
		local tabInfo = GetCurrentGuideTypeTabInfo()
		return tabInfo and tabInfo:RightShouldScroll()
	end
	
	local function IterateCurrentHolidays(invariant, control)
		if not control then control = 0 end
		control = control + 1
		Calendar_LoadUI()
		local date = C_Calendar.GetDate()
		
		local presentWeekday = date.weekday;
		local presentMonth = date.month;
		local presentDay = date.monthDay;
		local presentYear = date.year;
		
		C_Calendar.SetAbsMonth(presentMonth, presentYear)
		local numEvents = C_Calendar.GetNumDayEvents(0, presentDay)
		if control > numEvents then return end
		local calendarType
        
        if CalendarGetDayEvent then
           calendarType = select(4, CalendarGetDayEvent(0, presentDay, control))
        else
           calendarType = select(4, C_Calendar.GetDayEvent(0, presentDay, control))
        end
        
		if calendarType=="HOLIDAY" then
            if CalendarGetHolidayInfo then
                return control, CalendarGetHolidayInfo(0, presentDay, control)
            else
                return control, C_Calendar.GetHolidayInfo(0, presentDay, control)
            end
		end
	end
	
	local function SetCurrentEventIcon(icon)
		local textureBase
		for index, _, _, tex in IterateCurrentHolidays do
			if tex and tex~="" then 
				textureBase = tex
				break
			end
		end
		if not textureBase then
            if icon then
                icon:SetTexture("Interface\\Icons\\achievement_bg_masterofallbgs")
            else
                return "Interface\\Icons\\achievement_bg_masterofallbgs"
            end
		else
            if icon then
				if tonumber(textureBase) then
					icon:SetTexture(textureBase)
				else
					icon:SetTexture("Interface\\Calendar\\Holidays\\"..textureBase.."Start")
				end
                
                icon:SetTexCoord(0, 0.7109375, 0, 0.7109375)
            else
                return "Interface\\Calendar\\Holidays\\"..textureBase.."Start", 0, 0.7109375, 0, 0.7109375
            end
		end
	end
	
	local tabs = {
		[1] = {text = "Home",		title = "Home",					LeftFrame = DGVHomeFrame, 						RightFrame = DGVSearchFrame, rightShouldScroll = false},
		[2] = {text = "Current Guide",								LeftFrame = CreateFrame("Frame"), 	RightFrame = DGVCurrentGuideFrame,	rightShouldScroll = true, leftShouldScroll = true},
		[3] = {text = "Settings",	title = "Settings for Dugi Guides", 											RightFrame = DGVScrollFrame3, rightShouldScroll = false},
		[11] = {text = "Help",		title = "Help",									LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame11,	icon="Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\help-i"},
		[5] = {text = "Leveling", 	title = "Leveling Guides", 	guidetype = "L",	LeftFrame = DGVHomeFrame, 		RightFrame = DGVScrollFrame4,	icon="Interface\\Icons\\Achievement_Level_110", rightShouldScroll = false},
		[6] = {text = "Dungeons", 	title = "Dungeon Guides", 	guidetype = "I",	LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame5,	icon="Interface\\Icons\\Achievement_Dungeon_GloryoftheHERO", rightShouldScroll = false},
		[7] = {text = "Dailies",	title = "Daily Guides",	guidetype = "D",		LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame6,	icon="Interface\\Icons\\Achievement_general_25kdailyquests", rightShouldScroll = false},
		[8] = {text = "Events",		title = "Event Guides", 	guidetype = "E",	LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame7,	icon="Interface\\Icons\\achievement_bg_masterofallbgs", rightShouldScroll = false},
		[9] = {text = "Achievements",	title = "Achievement Guides", guidetype = "A",LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame8,	icon="Interface\\Icons\\ACHIEVEMENT_GUILDPERK_HONORABLEMENTION", rightShouldScroll = false},
		[10] = {text = "Professions", 	title = "Profession Guides", guidetype = "P",LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame9,	icon="Interface\\Icons\\INV_Scroll_11", rightShouldScroll = false},
		[4] = {text = "Suggest", title = "Suggested Guides", 				LeftFrame = DGVHomeFrame, 		RightFrame = DGVScrollFrame10, 	icon="Interface\\Icons\\INV_Misc_Orb_01", rightShouldScroll = false},
        [12] = {text = "Elites", 	title = "Elites Guides", guidetype = "NPC", LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame12,	icon="Interface\\Icons\\spell_shadow_deathscream", rightShouldScroll = false},
        [13] = {text = "Mounts", 	title = "Mounts Guides", guidetype = "Mounts", LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame13,	icon="Interface\\Icons\\Ability_mount_ridingelekk", rightShouldScroll = false},
        [14] = {text = "Pets", 	title = "Companions Guides", guidetype = "Pets", LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame14,	icon="Interface\\Icons\\Ability_racial_bearform", rightShouldScroll = false},
        [15] = {text = "Bosses", 	title = "Bosses Guides", guidetype = "Bosses", LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame15,	icon="Interface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster", rightShouldScroll = false},
		[16] = {text = "Clear Guide",		title = "Clear the loaded guide from the Small Frame",									LeftFrame = DGVHomeFrame,		RightFrame = DGVScrollFrame16,	icon="Interface\\Buttons\\UI-GroupLoot-Pass-Up"},		
        [17] = {text = "Recent Guides", title = "Recent Guides", 		LeftFrame = DGVHomeFrame, 		RightFrame = DGVScrollFrame17, 	icon="Interface\\Icons\\Spell_shadow_unstableaffliction_1", rightShouldScroll = false},
        [18] = {text = "Followers", title = "Followers", guidetype = "Followers", LeftFrame = DGVHomeFrame, 		RightFrame = DGVScrollFrame18, 	icon="Interface\\Icons\\achievement_garrisonfollower_rare", rightShouldScroll = false},
     --   [19] = {text = "Macros", title = "Macro guide", LeftFrame = DGVHomeFrame, 		RightFrame = DGVScrollFrame18, 	icon="Interface\\Icons\\INV_Misc_Orb_05", rightShouldScroll = false},
        }
	local SEARCH_TAB, SUGGEST_TAB, RECENT_TAB, MACROS_TAB = 1,4,17,19
	local currentGuideTabInfo = tabs[2]
	
	local function AccessValue(valueOrAccessor)
		if type(valueOrAccessor)=="function" then 
			return valueOrAccessor() 
		else return valueOrAccessor end
	end
	
	local function TabInfoRightShouldScroll(self)
		return self.rightShouldScroll
	end
	
	local function TabInfoLeftShouldScroll(self)
		return AccessValue(self.leftShouldScroll)
	end
	
	local activeTabInfo, PopulateSuggestedGuides
    local lastClickedTab = nil
    
    
	local function TabInfoActivate_(self, isInThread)
        DGV:AddGuideToRecentGuides(CurrentTitle)
        
        PopulateRecentGuides()
        
        
        if DGV:isValidGuide(CurrentTitle) and (not CurrentTitle or not GetCurrentGuideTypeTabInfo().leftShouldScroll) and self.text and self.text ~= "Current Guide" then
            guidesMainScroll.frame:Hide()
        else
            guidesMainScroll.frame:Show()
        end
        
        if whatsNewFrame then
            whatsNewFrame:Hide()
            whatsNewFrame.title:Hide()
        end
        
        if NPCJournalFrame then
            NPCJournalFrame.playersMounts = nil
            NPCJournalFrame.playersPets = nil
            NPCJournalFrame.playersFollowers = nil
        end
        
        local treeData = self.treeData
        
        if not self.treeData and self.text == "Current Guide" then
            if GetCurrentGuideTypeTabInfo() then
                treeData = GetCurrentGuideTypeTabInfo().treeData
            end
        end   

        if self.text ~= "Recent Guides" and recentGuidesLabel then
            recentGuidesLabel:Hide()
        end

        if noGuideLoaded == nil then
            guidesMainScroll.frame:CreateFontString("noGuideLoaded", "ARTWORK", "GameFontNormalLarge")
        end
        
        if treeData then
        
            if guideategorieswrapper then
                guideategorieswrapper:ClearAllPoints() 
            end            
        
            local x = 400
            local y = -30
            local parent = guidesMainScroll.frame
            
            if DugisMain then
                parent = DugisMain
                x = 400
                y = -30
            end
        
            local wrapper = GUIUtils:SetTreeData(parent, nil, "guideategories", 
                treeData, nil, nil, nil, nil, x, y, 5, -5
                ,function(oryginalText, nodeData)
                   if DGV.ProcessNPCLeafColor and nodeData.isLeaf then
                       return DGV.ProcessNPCLeafColor(oryginalText, self.guidetype)
                   else
                       return oryginalText
                   end
                 end,
                 function(self, newHeight)
                    local newMax = newHeight - 100
                    if newMax < 1 then
                        newMax = 1
                    end
                    
                    if whatsNewFrame and whatsNewFrame:IsVisible() and whatsNewFrame:GetRegions() and whatsNewFrame:GetRegions():GetHeight() then
                        newMax = newMax + whatsNewFrame:GetRegions():GetHeight()
                    end

                    guidesMainScroll.scrollBar:SetMinMaxValues(1, newMax)
                    if UpdateWhatsNewFramePositions then
                        UpdateWhatsNewFramePositions()
                    end
                 end,
                 function(self, delta)
                    guidesMainScroll.scrollBar:SetValue(guidesMainScroll.scrollBar:GetValue() - delta * 44)  
                 end, nil, nil, nil, nil, nil, nil, nil, isInThread)

            if DugisMain then
                wrapper:SetParent(DugisMain)
                wrapper:SetPoint("TOPLEFT", DugisMain, "TOPLEFT", 0, 0)
            end
            
            if recentGuidesLabel == nil then
                guideategorieswrapper:CreateFontString("recentGuidesLabel", "ARTWORK", "GameFontNormalLarge")
            end
            
    

            if #treeData == 0 then
                noGuideLoaded:Show()
                noGuideLoaded:SetText(L["No Guide Loaded"])
                noGuideLoaded:SetPoint("TOPLEFT", guidesMainScroll.frame, "TOPLEFT", 3, -5)
                recentGuidesLabel:SetParent(guidesMainScroll.frame)
            else
                noGuideLoaded:Hide()
            end
            
            if self.text == "Recent Guides" then
                    
                recentGuidesLabel:Hide()
                noGuideLoaded:Hide()
                if tabs[RECENT_TAB].treeData and #tabs[RECENT_TAB].treeData > 0 then
                    recentGuidesLabel:Show()
                else
                    recentGuidesLabel:Hide()
                end 
                
                recentGuidesLabel:SetText(L["Recent Guides"])
                
                recentGuidesLabel:SetParent(guideategorieswrapper)
                recentGuidesLabel:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", 3, -5)
                guideategorieswrapper.indernalDeltaX = 0
                guideategorieswrapper.internalDeltaY = -25
                guideategorieswrapper:UpdateTreeVisualization()
                
            end	            
        end
        
        guidesMainScroll.frame.content = guideategorieswrapper
        guidesMainScroll.frame:SetScrollChild(guideategorieswrapper) 
    
        if guideategorieswrapper then
            if self.text == "Current Guide" then
            
                guideategorieswrapper:SetWidth(347)
                guidesMainScroll.frame:SetPoint("TOPLEFT", DugisMain, 5, -47)
                guidesMainScroll.frame:SetWidth(400)
            
                guideategorieswrapper.indernalDeltaX = 0
                guideategorieswrapper.internalDeltaY = -40
                guideategorieswrapper:UpdateTreeVisualization()
               
                DugisMainLeftScrollFrame.currentGuideIcon:SetParent(guideategorieswrapper)
                DugisMainLeftScrollFrame.currentGuideIcon:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", 10, -5)
                DugisMainLeftScrollFrame.currentGuideIcon:Show()
                
                DugisMainLeftScrollFrame.guideType:SetParent(guideategorieswrapper)
                DugisMainLeftScrollFrame.guideType:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", 48, -10)
                DugisMainLeftScrollFrame.guideType:Show()
                
                DugisPreloadButton:ClearAllPoints()
                DugisPreloadButton:SetParent(guideategorieswrapper)
                DugisPreloadButton:SetPoint("TOPLEFT", 250, -10)
                
                if CurrentTitle then
                    DugisPreloadButton:Show()
                    guidesMainScroll.scrollBar:Show()
                else
                    noGuideLoaded:Show()
                    noGuideLoaded:SetText(L["No Guide Loaded"])
                    noGuideLoaded:SetPoint("TOPLEFT", guidesMainScroll.frame, "TOPLEFT", 3, -5)
                    DugisPreloadButton:Hide()
                    guideategorieswrapper:Hide()
                    DugisMainLeftScrollFrame.currentGuideIcon:Hide()
                    DugisMainLeftScrollFrame.guideType:Hide()
                    guidesMainScroll.scrollBar:Hide()
                end
                
                guidesMainScroll.scrollBar:SetPoint("TOPLEFT", guidesMainScroll.frame, "TOPLEFT", 352, -10)
            else
                guideategorieswrapper:SetWidth(405)
                if self.text == "Help" then
                    guidesMainScroll.frame:Hide()
                else
                    guidesMainScroll.frame:SetParent( DugisMain)
                    guidesMainScroll.frame:SetPoint("TOPLEFT", DugisMain, 370, -40)
                    guidesMainScroll.frame:Show()
                    guidesMainScroll.scrollBar:SetPoint("TOPLEFT", guidesMainScroll.frame, "TOPLEFT", 412, -20)
                    guidesMainScroll.scrollBar:SetHeight(319)
                    guidesMainScroll.frame:SetWidth(600)
                    DugisMainLeftScrollFrame.currentGuideIcon:Hide()
                    DugisMainLeftScrollFrame.guideType:Hide()
                    DugisPreloadButton:Hide()
                end
            end
        end

        SetCurrentGuideIcon()
        
        if  self.text == "Settings" then
            guidesMainScroll.frame:Hide()
        end          
    
		if activeTabInfo==self then return end
		if activeTabInfo then
			if activeTabInfo:RightShouldScroll() then
				activeTabInfo.rightScrollHistory = Main.rightScroll.bar:GetValue()
			end
			if activeTabInfo.LeftFrame then
				local leftFrame = AccessValue(activeTabInfo.LeftFrame)
				if leftFrame then
					leftFrame:Hide()
				end
			end
			activeTabInfo.RightFrame:Hide()
			DugisReloadButton:Hide() DugisResetButton:Hide() DugisPercentButton:Hide()
		end
		activeTabInfo = self
		
		Main.title:SetText(self.title)
		Main.title:Show()
		
		if self.text ~= "Home" then
			DGV.Search:Hide()
			DGV.Search:ClearText()
		end
		
		if self.text == "Suggest Guides" then
			PopulateSuggestedGuides()
		end
        
        if self.text == "Recent Guides" then
			PopulateRecentGuides()
            
            if recentGuidesLabel then
                if tabs[RECENT_TAB].treeData and #tabs[RECENT_TAB].treeData > 0 then
                    recentGuidesLabel:Show()
                else
                    recentGuidesLabel:Hide()
                end
            end            
		end
		
		if self.text == "Clear Guide" then
            DugisGuideUser.RecentGuides = {}
            DugisGuideUser.RecentGuides.Categories = {}
            DugisGuideUser.RecentGuides.LastIndices = {}
            DugisGuideUser.RecentGuides.Guides = {}
            
            CurrentTitle = nil
            DugisGuideViewer.CurrentTitle = nil
            
            tabs[RECENT_TAB].treeData = {}
            guideategorieswrapper:UpdateTreeVisualization()

			DGV:ClearScreen()
			
			DugisGuideUser.CurrentQuestIndex = nil
			CurrentQuestName = nil
			DugisGuideViewer:RemoveAllWaypoints()			
			DugisGuideViewer.Modules.ModelViewer.Frame:Hide()
            
            --HOME
            Guides.TabInfoActivate(tabs[1])
		end

		if self.text == "Current Guide" and DGV:isValidGuide(CurrentTitle) == true then	
			DugisReloadButton:Show() DugisResetButton:Show() DugisPercentButton:Show() 
			DGV.Search:Show()
			DGV:TabTextRefresh()
			Main.rightScroll:SetPoint("BOTTOM", Main.rightFrameHost, 0, 30)
            DugisGuideViewer:UpdateCurrentGuideExpanded()
		end
		
		if self.guidetype then
			if not self.text == "Elites" or not self.text == "Mounts" or not self.text == "Pets" or not self.text == "Bosses" or not self.text == "Followers" then
				DugisPreloadButton:SetParent(Main)
				DugisPreloadButton:ClearAllPoints()
				DugisPreloadButton:SetPoint("BOTTOMRIGHT", Main.rightFrameHost, 0, 3)
				DugisPreloadButton:Show()
			end
			Main.rightScroll:SetPoint("BOTTOM", Main.rightFrameHost, 0, 30)
		end
			
		if self.text ~= "Current Guide" and not self.guidetype then
			Main.rightScroll:SetPoint("BOTTOM", Main.rightFrameHost)
			DugisPreloadButton:Hide()
		end
        	
        if searchThread == nil then
            self.RightFrame:Show()
        end
        
		if self:RightShouldScroll() then
			Main.rightScroll:SetScrollChild(self.RightFrame)
			self.RightFrame:SetWidth(400)
			Main.rightScroll.bar:SetValue(self.rightScrollHistory or 1)
			Main.rightScroll:Show()
		else
			Main.rightScroll:Hide()
			self.RightFrame:SetAllPoints(Main.rightFrameHost)
		end
		
        if Main.leftScroll then
            Main.leftScroll:Hide()
        end

		if self.text == "Elites" and not DGV:IsModuleRegistered("NPCDataModule") then 
			Main.rightScroll:Hide()
		end

		if self.text == "Mounts" and not DGV:IsModuleRegistered("MountDataModule") then 
			Main.rightScroll:Hide()
		end
		
		if self.text == "Pets" and not DGV:IsModuleRegistered("PetDataModule") then 
			Main.rightScroll:Hide()
		end
		
		if self.text == "Bosses" and not DGV:IsModuleRegistered("BossDataModule") then 
			Main.rightScroll:Hide()
		end		
        
		if self.text == "Followers" and not DGV:IsModuleRegistered("FollowerDataModule") then 
			Main.rightScroll:Hide()
		end		
        
				
		local leftFrame = AccessValue(self.LeftFrame)
		if leftFrame then
			leftFrame:Show()
			if self:LeftShouldScroll() then
				DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrollBackground())
                if Main.leftScroll then
                    Main.leftScroll:SetScrollChild(leftFrame)
                    leftFrame:SetWidth(350)
                    Main.leftScroll.bar:SetValue(self.leftScrollHistory or 1)
                    Main.leftScroll:Show()
                end
				
				if self.text=="Current Guide" and GetCurrentGuideTypeTabInfo() then
					self.leftScrollMax = GetCurrentGuideTypeTabInfo().rightScrollMax
				else
                    DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrolllesBackground())
                end
			else
				DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrolllesBackground())
				leftFrame:SetAllPoints(Main.leftFrameHost)
			end
			Main.leftFrameHost:Show()
			Main.rightFrameHost:ClearAllPoints()
			Main.rightFrameHost:SetPoint("TOPLEFT", 375, -44)
			Main.rightFrameHost:SetPoint("BOTTOMRIGHT", -25, 0)
			
			if leftFrame==DGVHomeFrame then
				Main.title:Hide()
				DGV.Search:ShowGlobal()
			end
		else
			Main.leftFrameHost:Hide()
			DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrolllesBackground())
			Main.rightFrameHost:ClearAllPoints()
			Main.rightFrameHost:SetPoint("TOPLEFT", 0, -44)
			Main.rightFrameHost:SetPoint("BOTTOMRIGHT", -25, 0)
		end
		if self.RightFrame.panel and self.RightFrame.firstHeading then
			self.RightFrame.firstHeading:SetPoint("TOPLEFT", self.RightFrame, "TOPLEFT", 0, -5)
			self.RightFrame.panel:Hide()
		end
        
		if self.text == "Home" then
            if  DGV_SearchBox:GetText() == "" then
                DGVHomeFrame.selection14:GetScript("OnClick")(DGVHomeFrame.selection14)
            end
            DGVHomeFrame.selection14:Hide()
        end
        
        DugisGuideViewer:UpdateCurrentGuideExpanded()
        
        if lastClickedTab ~= self.text and guideategorieswrapper then
            guideategorieswrapper:SaveExpansionState(self.text)
            guideategorieswrapper:LoadExpansionState(lastClickedTab, isInThread)
            guidesMainScroll.scrollBar:SetValue(0)
        end
        
        if self.text == "Macros" then
            DugisGuideViewer.DeselectTopTabs()
            
            tabs[MACROS_TAB].treeData = {}
            guideategorieswrapper:UpdateTreeVisualization()
            Guides.TabInfoActivate(tabs[MACROS_TAB])
        
            DGVHomeFrame:Hide()
            guidesMainScroll.frame:Hide()
            
            local textEditor, cancelButton, textCancel, editNameButton, editDescriptionButton, editCodeButton, deleteMacroButton
            
            function GetAllMacros()
                local result = {}
                
                for i = 1, MAX_ACCOUNT_MACROS do
                    local name, texture, body = GetMacroInfo(i)
                    if name and body then
                        result[#result + 1] = {index = i, name = name, body = body, texture = texture}
                    else
                        break
                    end 
                end
                
                for i = MAX_ACCOUNT_MACROS + 1, (MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS) do
                    local name, texture, body = GetMacroInfo(i)
                    if name and body then
                        result[#result + 1] = {index = i, name = name, body = body, texture = texture}
                    else
                        break
                    end 
                end
            
                return result
            end
            
            function MacroBody2MacroIndex(body)
                body = LuaUtils:trim(body)
            
                local result = nil
                LuaUtils:foreach(GetAllMacros(), function(macroInfo)
                    if LuaUtils:trim(macroInfo.body) == body then
                        result = macroInfo.index
                    end
                end)
                return result
            end

            if DGV.Guides.currentSelectedMacroData == nil then
                DGV.Guides.currentSelectedMacroData = DugisGuideUser.macrosData.general[1]
            end
            
            if DGV.Guides.currentSelectedCategory == nil then
                DGV.Guides.currentSelectedCategory = "general"
            end
            
            local defaultMacroIcon = [[Interface/ICONS/INV_Misc_QuestionMark]]
            
        
            local MacroEditor = DugisMain.MacrosWrapper.MacroEditor
            local MacroName = MacroEditor.MacroName
            local MacroDescription = MacroEditor.MacroDescription
            local MacroCode = MacroEditor.MacroCode
            
            MacroEditor.AddToSlotButton:SetScript("OnClick", function()
                SlashCmdList["MACRO"]()
                local name = DGV.Guides.currentSelectedMacroData.name
                local body = DGV.Guides.currentSelectedMacroData.data.macroCode
                local icon = DGV.Guides.currentSelectedMacroData.icon
                
                if type(DGV.Guides.currentSelectedMacroData.icon) == "string" then
                    icon = icon:gsub([[Interface/ICONS/]], "")
                end
                
                local numAccountMacros, numCharacterMacros = GetNumMacros();
                
                if numAccountMacros >= MAX_ACCOUNT_MACROS then
                    print("|cff11ff11This account has already 120 macros.|r")
                    return
                end
                
                local index = CreateMacro(name, icon, body, false)
                MacroFrame_SelectMacro(index)
            
                MacroFrame_Update()
            end)
        
            function UpdateTexts()
                MacroName:SetText(DGV.Guides.currentSelectedMacroData.name)
                MacroDescription:SetText(DGV.Guides.currentSelectedMacroData.data.macroDescription)
                MacroCode:SetText(DGV.Guides.currentSelectedMacroData.data.macroCode)
            end
            
            function UpdateIcons()
                LuaUtils:foreach(DugisGuideUser.macrosData, function(value, key)
                    LuaUtils:foreach(DugisGuideUser.macrosData[key], function(node)
                        if not node.isPlusButton then
                            local body = node.data.macroCode
                            local icon = MacroBody2MacroIcon(body)
                            if icon then
                                node.icon = icon
                            else
                                node.icon = defaultMacroIcon
                            end
                        end
                    end)
                end)
                
                RefreshMacrosList()
            end            
            
            MacroEditor.ResetToDefault:SetScript("OnClick", function()
                local name = DGV.Guides.currentSelectedMacroData.name
                local body = DGV.Guides.currentSelectedMacroData.data.macroCode
                local icon = DGV.Guides.currentSelectedMacroData.icon
                
                
                if not DGV.Guides.currentSelectedMacroData or not DGV.Guides.currentSelectedCategory or not DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory] then
                    return
                end
                
                local macroData = DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory]
                local macroIndex = nil
                
                LuaUtils:foreach(macrosDataDefaults[DGV.Guides.currentSelectedCategory], function(defaultMacroData, index)
                    if defaultMacroData.name == name then
                        macroIndex = index
                    end 
                end)
                
                if not macroIndex then
                    return 
                end
                
                local defaultBody = macrosDataDefaults[DGV.Guides.currentSelectedCategory][macroIndex].data.macroCode
                local defaultDescription = macrosDataDefaults[DGV.Guides.currentSelectedCategory][macroIndex].data.macroDescription
                local defaultName = macrosDataDefaults[DGV.Guides.currentSelectedCategory][macroIndex].name
                
                DGV.Guides.currentSelectedMacroData.data.macroCode = defaultBody
                DGV.Guides.currentSelectedMacroData.data.macroDescription = defaultDescription
                DGV.Guides.currentSelectedMacroData.name = defaultName
                UpdateTexts()
                UpdateIcons()
            end)
            
             --local textEditor, cancelButton, textCancel, editNameButton, editDescriptionButton, editCodeButton
             
             function UpdateMacroButtonsVisibility()
                local currentMacroData = DGV.Guides.currentSelectedMacroData
                local isEditable = currentMacroData.isEditable
                
                if isEditable then
                    editNameButton.button:Show()
                    editDescriptionButton.button:Show()
                    editCodeButton.button:Show()
                   Guides.deleteMacroButton.button:Show()
                   MacroEditor.ResetToDefault:Hide()
                  
                else
                    editNameButton.button:Hide()
                    editDescriptionButton.button:Show()
                    editCodeButton.button:Show()
                    MacroEditor.ResetToDefault:Show()
                    Guides.deleteMacroButton.button:Hide()
                end
                
             end
        
            function RefreshMacrosList()
                local macroData =  DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory]
                
                if not macroData then
                    DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory] = {}
                    macroData = DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory]
                end
                
                if #macroData == 0 or not macroData[#macroData].isPlusButton then
                    macroData[#macroData + 1] = {name = "New macro", textColor = {r=1, g=1, b=1}, isPlusButton = true, nodeTextY = -3, nodeTextX = 23
                    , icon = [[Interface/AddOns/DugisGuideViewerZ/Artwork/plus16px]], iconSize = 16
                    , data = {macroCode = "",  macroDescription = ""}}
                end
                
                    
                local config = {
                    parent             = DugisMain.MacrosWrapper
                    , name             = "macrosubcategories"
                    , data             = macroData or {}
                    , x                = 10
                    , y                = -86
                    , nodesOffsetY     = -10
                    , width            = 330
                    , height           = 308
                    , onNodeClick      = function(visualNode)
                            if not visualNode.nodeData.isPlusButton then
                                DGV.Guides.currentSelectedMacroData = visualNode.nodeData
                                UpdateTexts()
                                MacroEditor:Show()
                                UpdateMacroButtonsVisibility()
                            else
                                if DGV.Guides.currentSelectedCategory then
                                    local macros = DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory]

                                    macros[#macros + 1] = {isEditable = true, name = "My new macro", icon = defaultMacroIcon, data = {macroCode = "/say Hello World!",  macroDescription = "description"}}
                                    DGV.Guides.currentSelectedMacroData = macros[#macros]

                                    UpdateIcons()
                                    UpdateTexts()
                                    MacroEditor:Show()
                                    UpdateMacroButtonsVisibility()
                                   
                                    if Guides.macrolist.scrollBar:IsVisible() then
                                        local val = Guides.macrolist.frame:GetVerticalScrollRange()
                                        Guides.macrolist.scrollBar:SetValue(val - 102)
                                    end
                                end 
                            end
                        end
                    , iconSize         = 22
                    , nodeHeight       = 24
                    , onDragFunction   = function(visualNode)
                            local body = visualNode.nodeData.data.macroCode
                            local macroIndex = MacroBody2MacroIndex(body)
                            if macroIndex then
                                PickupMacro(macroIndex)
                            end
                        end
                    , nodeTextX        = 30
                }
                
                Guides.macrolist = SetScrollableTreeFrame(config)
                
                if not Guides.macrolist.scrollBar.bkg then
                    local tex = Guides.macrolist.scrollBar:CreateTexture("BACKGROUND")
                    tex:SetColorTexture(0, 0, 0)
                    tex:SetAllPoints()
                    tex:SetAlpha(0.1)
                    tex:Show()
                    Guides.macrolist.scrollBar.bkg = tex
                end
                
                Guides.macrolist.scrollBar:SetPoint("TOPLEFT", DugisMain.MacrosWrapper, "TOPLEFT", 302, -61)
                Guides.macrolist.scrollBar:SetParent(DugisMain.MacrosWrapper)
                Guides.macrolist.scrollBar:SetHeight(320)
                Guides.macrolist.scrollBar:SetScript("OnValueChanged",
                function (self, value)
                    Guides.macrolist.frame:SetVerticalScroll(value)
                end)
                
                table.remove(macroData, #macroData)
            end
            
            function RefreshMacrosCategories()
                local config = {
                    parent             = DugisMain.MacrosWrapper
                    , name             = "macrocategories"
                    , data             = macroCategories
                    , x                = 10
                    , y                = -86
                    , nodesOffsetY     = -10
                    , width            = 330
                    , height           = 308
                    , onNodeClick      = function(visualNode)
                        DGV.Guides.currentSelectedCategory = visualNode.nodeData.data.categoryName
                        RefreshMacrosList()   
                        macrocategorieswrapper:Hide()
                        Guides.macrolist.frame:Show()
                        
                        DugisMain.MacrosWrapper.MacroInfo.CategoryIcon:SetTexture(visualNode.nodeData.icon)
                        DugisMain.MacrosWrapper.MacroInfo.CategoryIcon:SetPoint("TOPLEFT", 49, -49)
                        DugisMain.MacrosWrapper.MacroInfo.CategoryName:SetText(visualNode.nodeData.name)
                        
                        DugisMain.MacrosWrapper.BackToCategoriesButton:Show()
                        
                        
                        Guides.macrolist.scrollBar:SetValue(0)
                        
                    end
                    , iconSize         = 25
                    , nodeHeight       = 27
                    , noScrollMode     = true
                    , columnWidth      = 120
                    , nodeTextX        = 30
                }
            
                SetScrollableTreeFrame(config)
                
                RefreshMacrosList()
            end
            
            function MacroBody2MacroIcon(body)
                local index = MacroBody2MacroIndex(body)

                if index then
                    local _, texture, _ = GetMacroInfo(index)
                    return texture
                end
            end            

            DugisMain.MacrosWrapper:Show()
            
            if not Guides.uiInitialized then
                RefreshMacrosCategories()    
                UpdateTexts()
                
                UpdateIcons()
            
                Guides.macrolist.frame:Hide()
                
                MacroEditor:Hide()
            end
                
            local initializeMacroHooksTimer    
            initializeMacroHooksTimer = C_Timer.NewTicker(1, function()
                if not Guides.hookedMacroFramefunctions and MacroFrame_Update then
                    hooksecurefunc("MacroFrame_Update", function()
                        UpdateIcons()
                    end)   
                    
                    hooksecurefunc("MacroFrame_Show", function()
                        UpdateIcons()
                    end)    
                    
                    hooksecurefunc("MacroFrameSaveButton_OnClick", function()
                        UpdateIcons()
                    end)   
                    
                    hooksecurefunc("MacroFrame_DeleteMacro", function()
                        UpdateIcons()
                    end)  
                                  
                    hooksecurefunc("RefreshPlayerSpellIconInfo", function()
                        UpdateIcons()
                    end)  
                    
                    hooksecurefunc("MacroFrame_SaveMacro", function()
                        UpdateIcons()
                    end)  
                    
                    initializeMacroHooksTimer:Cancel()
                    Guides.hookedMacroFramefunctions = true
                end
            end)
            
            if not Guides.uiInitialized then
                textEditor = AceGUI:Create("MultiLineEditBox")
                textEditor.frame:SetParent(DugisMain.MacrosWrapper)
                textEditor.editBox:SetCountInvisibleLetters(true)
                textEditor.frame:SetPoint("TOPLEFT", DugisMain.MacrosWrapper, "TOPLEFT", 380, -60)
                textEditor.frame:SetWidth(370)
                textEditor.frame:SetHeight(320)
                Guides.textEditor = textEditor
                Guides.macrolist.scrollBar:Hide()
            else
                textEditor = Guides.textEditor
            end
            
            if not Guides.uiInitialized then
                cancelButton = CreateFrame("Button", nil , textEditor.frame, "UIPanelButtonTemplate" or "UIPanelButtonTemplate2")
                cancelButton:SetPoint("TOPLEFT", textEditor.button, "TOPRIGHT", 10, 0)
                cancelButton:SetHeight(22)
                cancelButton:SetWidth(textEditor.label:GetStringWidth() + 24)
                cancelButton:SetText("Cancel")
                cancelButton:Show()
                
                cancelButton:SetScript("OnClick", function()
                    textEditor.frame:Hide()
                    MacroEditor:Show()
                end)
                Guides.cancelButton = cancelButton
            else
                cancelButton = Guides.cancelButton
            end
            
            if not Guides.uiInitialized then
                textCancel = cancelButton:GetFontString()
                textCancel:ClearAllPoints()
                textCancel:SetPoint("TOPLEFT", cancelButton, "TOPLEFT", 5, -5)
                textCancel:SetPoint("BOTTOMRIGHT", cancelButton, "BOTTOMRIGHT", -5, 1)
                textCancel:SetJustifyV("MIDDLE")
                Guides.textCancel = textCancel
            else
                textCancel = Guides.textCancel
            end
            
            textEditor.editBox:HookScript("OnTextChanged", function()
                  local text = textEditor.editBox:GetText()
            end)
            
            textEditor.button:HookScript("OnClick", function()
              if textEditor.onAccept then
                 textEditor.onAccept()
              end
            end)
            
            local function EditText(caption, initialText, onAccept)
                textEditor.frame:Show()
                MacroEditor:Hide()
                
                textEditor.label:SetText(caption)
                textEditor.editBox:SetText(initialText)
                textEditor.onAccept = function()
                    textEditor.frame:Hide()
                    MacroEditor:Show()
                    
                    onAccept()
                end  
            end
            
            local function ShowInfo(parent, text)
                GameTooltip:SetOwner(DugisMain, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:AddLine(text, 1, 1, 1, 1, true)
                GameTooltip:Show()
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("BOTTOMRIGHT", DugisMain, "BOTTOMRIGHT", 6, -42)            
            end
            
            local function CreateEditButton(onClick, infoText)
                local button = GUIUtils:AddButton(MacroEditor, "", 0,  0, 16, 16, 16, 16, onClick
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/pen16px.tga]]
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/pen16px.tga]]
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/pen16px.tga]]
                )
                
                button.button:Show()
                button.button:ClearAllPoints()
                
                button.button:SetScript("OnEnter", function()
                    ShowInfo(button.button, infoText or "Edit")
                end)
                
                button.button:SetScript("OnLeave", function() GameTooltip:Hide() end)                
            
                return button
            end 

            local function CreateDeleteButton(onClick, infoText)
                local button = GUIUtils:AddButton(MacroEditor, "", 0,  0, 32, 32, 32, 32, onClick
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/trash32px.tga]]
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/trash32px.tga]]
                , [[Interface/AddOns/DugisGuideViewerZ/Artwork/trash32px.tga]]
                )
                
                button.button:Show()
                button.button:ClearAllPoints()
                
                button.button:SetScript("OnEnter", function()
                    ShowInfo(button.button, infoText or "Delete")
                end)
                
                button.button:SetScript("OnLeave", function() GameTooltip:Hide() end)    
            
                return button
            end  

            if not Guides.uiInitialized then
                editNameButton = CreateEditButton(function()
                    textEditor.editBox:SetMaxLetters(30)
                    EditText("Edit macro name", MacroName:GetText(), function()
                        local text = textEditor.editBox:GetText()
                        
                        DGV.Guides.currentSelectedMacroData.name = text
                        MacroName:SetText(text)
                        RefreshMacrosList() 
                    end)
                end, "Edit macro name")
                editNameButton.button:SetPoint("BOTTOMRIGHT", MacroName, "BOTTOMRIGHT", 20, 0)
                Guides.editNameButton = editNameButton
            else
                editNameButton = Guides.editNameButton
            end
            
            if not Guides.uiInitialized then
                editDescriptionButton = CreateEditButton(function()
                    textEditor.editBox:SetMaxLetters(500)
                    EditText("Edit macro '"..MacroName:GetText().."' description", MacroDescription:GetText(), function()
                        local text = textEditor.editBox:GetText()
                        DGV.Guides.currentSelectedMacroData.data.macroDescription = text
                        MacroDescription:SetText(text)
                        RefreshMacrosList() 
                    end)
                end, "Edit macro description")
                editDescriptionButton.button:SetPoint("BOTTOMRIGHT", MacroDescription, "BOTTOMRIGHT", 20, 0)
                Guides.editDescriptionButton = editDescriptionButton
            else
                editDescriptionButton = Guides.editDescriptionButton
            end
            
            if not Guides.uiInitialized then
                editCodeButton = CreateEditButton(function()
                    textEditor.editBox:SetMaxLetters(255)
                    EditText("Edit macro '"..MacroName:GetText().."' code", MacroCode:GetText(), function()
                        local text = textEditor.editBox:GetText()
                        MacroCode:SetText(text)
                        DGV.Guides.currentSelectedMacroData.data.macroCode = text
                        RefreshMacrosList() 
                        UpdateIcons()
                    end)
                end, "Edit macro code")
                editCodeButton.button:SetPoint("BOTTOMRIGHT", MacroCode, "BOTTOMRIGHT", 20, 0)
                Guides.editCodeButton = editCodeButton
            else
                editCodeButton = Guides.editCodeButton
            end     
            
            if not Guides.uiInitialized then
                deleteMacroButton = CreateDeleteButton(function()
                    if DGV.Guides.currentSelectedCategory then
                        local macros = DugisGuideUser.macrosData[DGV.Guides.currentSelectedCategory]
                        local index = LuaUtils:indexOf(DGV.Guides.currentSelectedMacroData, macros) 
                        table.remove(macros, index)
                        RefreshMacrosList()
                        MacroEditor:Hide()
                        if Guides.macrolist.scrollBar:IsVisible() then
                            local val = Guides.macrolist.frame:GetVerticalScrollRange()
                            Guides.macrolist.scrollBar:SetValue(val - 150)
                        else
                            Guides.macrolist.scrollBar:SetValue(0)
                        end
                        
                    end
                    
                end, "Delete this macro")
                deleteMacroButton.button:SetPoint("BOTTOMRIGHT", MacroEditor, "BOTTOMRIGHT", -30, 20)
                Guides.deleteMacroButton = deleteMacroButton
            else
                deleteMacroButton = Guides.deleteMacroButton
            end
            
            Guides.uiInitialized = true

		else
            DugisMain.MacrosWrapper:Hide()
            
        end
        
        function UpdateWhatsNewText()
            local text = NPCJournalFrame:ReplaceSpecialTags(whatsNewText, nil, nil, nil, true)
			whatsNewFrame:SetJustifyH("LEFT")
            whatsNewFrame:SetText(text)
        end
        
        function UpdateWhatsNewFramePositions()
            if whatsNewFrame and whatsNewFrame:IsVisible() then
                guidesMainScroll.scrollBar:SetMinMaxValues(1, whatsNewFrame:GetRegions():GetHeight())
                
                local extraOffset = -10
                local parentHeight = guideategorieswrapper.height
                
                if parentHeight == 0 then
                    extraOffset = 20
                end
                
                local whatsNewLeft = 5
                
                whatsNewFrame:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", whatsNewLeft, -parentHeight -70 + extraOffset) 
                whatsNewFrame.title:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", whatsNewLeft, -parentHeight -40 + extraOffset) 
            end            
        end
        
        if self.text == "Recent Guides" then
            if not whatsNewFrame then
                CreateFrame("SimpleHTML", "whatsNewFrame", guideategorieswrapper)
                CreateFrame("SimpleHTML", "whatsNewFrame_EventHandler", whatsNewFrame)
                
                whatsNewFrame_EventHandler:SetScript("OnHyperlinkClick", function(...)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkClick(...)
                end) 
                
                whatsNewFrame_EventHandler:SetScript("OnHyperlinkEnter", function(self, linkData, link, button)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkEnter(self, linkData, link, button, false, false, true)
                    NPCJournalFrame.needToUpdateWaypointButtonsWN = true
                end)     
                
                whatsNewFrame_EventHandler:SetScript("OnHyperlinkLeave", function(...)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkLeave(...)
                    NPCJournalFrame.needToUpdateWaypointButtonsWN = true
                end) 
                
                --Whats new configuration
                
                local whatsNewTitleYOffset = -9
                local whatsNewTitleFont = "GameFontNormalLarge"
                local whatsNewTitleColor = {1, 0.82, 0, 1}
                local whatsNewContentYOffset = -40
                local whatsNewContentFont = GameFontHighlight
                
                guidesMainScroll.frame:EnableMouseWheel(true)
                guidesMainScroll.frame:SetScript("OnMouseWheel", function(self, delta)
                    guidesMainScroll.scrollBar:SetValue(guidesMainScroll.scrollBar:GetValue() - delta * 44)  
                end)  

                local title = guideategorieswrapper:CreateFontString(guideategorieswrapper, "ARTWORK", whatsNewTitleFont)
                whatsNewFrame.title = title
                title:SetText("What's new|TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\highlight.tga:1:100:-80:10|t")
                title:SetTextColor(unpack(whatsNewTitleColor))
                title:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", 20, whatsNewTitleYOffset)
                title:Show()
                
                whatsNewFrame:SetFontObject(whatsNewContentFont)
                whatsNewFrame:EnableMouse(false)
                whatsNewFrame:SetHyperlinksEnabled(false) 
                whatsNewFrame:SetWidth(362)
                whatsNewFrame:SetHeight(282)
                whatsNewFrame:SetJustifyH("CENTER")
                whatsNewFrame:SetJustifyV("TOP")    
                
                whatsNewFrame:SetSpacing(2)
                whatsNewFrame:SetFrameLevel(51)
                
                whatsNewFrame_EventHandler:SetFontObject(whatsNewContentFont)
                whatsNewFrame_EventHandler:EnableMouse(true)
                whatsNewFrame_EventHandler:SetWidth(362)
                whatsNewFrame_EventHandler:SetHeight(282)
                whatsNewFrame_EventHandler:SetJustifyH("CENTER")
                whatsNewFrame_EventHandler:SetJustifyV("TOP")    
                whatsNewFrame_EventHandler:SetFrameLevel(50)
                whatsNewFrame_EventHandler:SetPoint("TOPLEFT", guideategorieswrapper, "TOPLEFT", 20, whatsNewContentYOffset) 
                whatsNewFrame_EventHandler:SetSpacing(2)
                whatsNewFrame_EventHandler:SetAlpha(0.1)
            end
            
            whatsNewFrame:Show()
            whatsNewFrame.title:Show()
            whatsNewFrame_EventHandler:Show()
            whatsNewFrame_EventHandler:SetAllPoints(whatsNewFrame)
            
            local text = NPCJournalFrame:ReplaceSpecialTags(whatsNewText, nil, nil, nil, true)
			whatsNewFrame_EventHandler:SetJustifyH("LEFT")
            whatsNewFrame_EventHandler:SetText(text)
            
            guidesMainScroll.scrollBar:Show()  
      
            UpdateWhatsNewText()
            
			if UpdateWhatsNewFramePositions then
				UpdateWhatsNewFramePositions()
			end
        end	        
        
        lastClickedTab = self.text
	end
    
    function Guides.TabInfoActivate(self)
        LuaUtils:RunInThreadIfNeeded("TabInfoActivate", function(isInThread, self)   
            TabInfoActivate_(self, isInThread)
        end, nil, {self})
    end    
	
	for _,tab in ipairs(tabs) do
		tab.Activate = Guides.TabInfoActivate
		tab.RightShouldScroll = TabInfoRightShouldScroll
		tab.LeftShouldScroll = TabInfoLeftShouldScroll
	end
	
	GetCurrentGuideTypeTabInfo = function()
		if DGV:isValidGuide(CurrentTitle) == true then
			local guideType = DGV.gtype[CurrentTitle]
			for _,tabInfo in ipairs(tabs) do
				if tabInfo.guidetype==guideType then
					return tabInfo
				end
			end
		end
	end
	
	
	function DGV:GetLastGuideNumRows()
		--return LastGuideNumRows
		return #visualRows
	end
	
	local suspendViewFrameUpdate = false
	local function SuspendViewFrameUpdate()
		suspendViewFrameUpdate = true
	end

	local function ResumeViewFrameUpdate(isInThread)
		suspendViewFrameUpdate = false
		DGV:ViewFrameUpdate(isInThread)
	end

	function DGV:ReloadButtonOnClick()
		DGV:DisplayViewTab(CurrentTitle)
        DGV:CollapseCurrentGuide()
        DGV:UpdateCurrentGuideExpanded()        
	end

	function DGV:ResetButtonOnClick()
        LuaUtils:RunInThreadIfNeeded("DGV_ResetButtonOnClick", function(isInThread)
        
		SuspendViewFrameUpdate()
		local i
		for i = 1, #visualRows do
			LuaUtils:RestIfNeeded(isInThread)
			DGV:ClrChk(i)	
		end
		ResumeViewFrameUpdate(isInThread)
		DGV:MoveToNextQuest(1)
		DGV:AutoScroll(0)
        
        end)    
	end
    
    --choiceId - textual or numeric value
    function DGV:GoToChoice(choiceId)
        DGV:SetChkToComplete(DugisGuideUser.CurrentQuestIndex)
    
		for i = 1, #visualRows do
            local currentChoiceId = DGV:ReturnTag("CHOICE", i)
            if currentChoiceId and tostring(currentChoiceId) == tostring(choiceId) then
                DugisGuideViewer:MoveToNextQuest(i + 1)
                return
            end
		end  
    end

    --choiceId - textual or numeric value
    function DGV:MarkStepsByChoiceId(choiceId, asCompleted)
		for i = 1, #visualRows do
            choiceGuideIndex = i + 1
            local currentChoiceId = DGV:ReturnTag("CHOICE", i)
            if currentChoiceId and tostring(currentChoiceId) == tostring(choiceId) then
                if asCompleted then
                    DGV:SetChkToComplete(i)
                else
                    DGV:SetChkToNotComplete(i)
                end
            end
		end  
    end
    
	function DGV:GetQuestState(index, guideName)
        local questIndex = string.format("%s:%d", guideName or CurrentTitle, index)
		return DGU.QuestState[questIndex]
	end
    
	--Performance optimization
    local duringMultiStepsChecking = false

	function DGV:SetQuestState(index, setting)
		--self:DebugFormat("SetQuestState", "index", index, "setting", setting, "stack", debugstack(2))
		DGU.QuestState[CurrentTitle..':'..index] = setting
        
        if setting == "C" then
            local LargeFramebutton = visualRows[index].Chk
            LargeFramebutton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			LargeFramebutton:SetChecked(true)
        end
        
		--Update visual state of potetial PRE tagged rows
        
        if duringMultiStepsChecking == false then
           -- DGV:ViewFrameUpdate()
        end
	end

	function DGV:GetQIDByLogIndex(lindex)
		return select(8, GetQuestLogTitle(lindex))
	end

	function DGV:GetGuideIndexByQID(qid, action)
		local i
		for i=1, #visualRows do
			if DGV.qid[i] == qid and (not action or DGV.actions[i] == action) then return i end
		end	
	 end

	function DGV:CompleteQID(qid, state)
		local i
		for i = 1, #visualRows do
			if DGV.qid[i] == qid and DGV.actions[i] == state then
				DGV:SetChkToComplete(i)
			end
		end
	end

    function DGV:SetCompletedSID(sid, completed, reset)            
		local i
		for i = 1, #visualRows do
			if DGV.sid[i] == sid then
                local index = string.format("%s:%d", guideName or CurrentTitle, i)
                if (completed) then
                    DGV:SetChkToComplete(i)
                elseif reset then
                    DGV:SetChkToNotComplete(i)
                end
			end
		end
		DGV:MoveToNextQuest()
	end
	
    function DGV:SetCompleteAllSID()
		local i
		for i = 1, #visualRows do
			if DGV:ReturnTag("SID", i) then
                DGV:SetChkToComplete(i)
			end
		end
        DGV:MoveToNextQuest()		
	end	

	function printAllquests(name)
		local i
		local numq, _ = GetNumQuestLogEntries()
		for i=1,numq do
			local title, _, _, isHeader = GetQuestLogTitle(i)
			if not isHeader then
				DebugPrint("Quest title"..title)
			end
		end
	end

	function DGV:IsCompleteLootQO(calledfrom, itemid, guideIndex)
		--Loot completion
		if not guideIndex then guideIndex = DGU.CurrentQuestIndex end
		local lootitem, lootqty 	= DGV:ReturnTag("L", guideIndex)
		local optional 				= DGV:ReturnTag("O", guideIndex)			
		local inlog 				= DGV:GetQuestLogIndexByQID(DGV.qid[guideIndex])
		local flag = 0

		if calledfrom == "CMSG" then
			if (lootitem and (GetItemCount(lootitem) + 1) >= lootqty) and lootitem == itemid then  
				if (optional and inlog) or (not optional) then
				flag = 1
				end
			end
		elseif calledfrom == "QLU" then
			if lootitem and GetItemCount(lootitem) >= lootqty then  
				if (optional and inlog) or (not optional) then
				flag = 1
				end
			end
		end
		
		if flag == 1 then
			return true
		end
	end

	function DGV:QuestPartComplete(guideIndex)
		local questpart = self:ReturnTag("QIDP", guideIndex)
		if questpart then
			local qid 				=  DGV.qid[guideIndex]
			local logidx 			=  DGV:GetQuestLogIndexByQID(qid)
			local desc, _, done 	=  GetQuestLogLeaderBoard(tonumber(questpart), logidx)		
            
            --Fallback to GetQuestObjectiveInfo in case GetQuestLogLeaderBoard doesn't return information about part completeness.
            if not desc and not done and not logidx then
                local text, objectiveType, finished = GetQuestObjectiveInfo(qid, questpart, false)
                if finished then
                    return true
                end
            end
            
			if done and logidx then 
				return true
			end
		end
	end
	
	--Update the look of the frame on QLU
	function DGV:ViewFrameUpdate(isInThread)
		if suspendViewFrameUpdate or not DugisMain:IsVisible() then return end
		local i, qid
		for i, qid in ipairs(DGV.actions) do
            local row = visualRows[i]
            if row and row.Button then
				LuaUtils:RestIfNeeded(isInThread)
                row.Button:SetNormalTexture(DGV:getIcon(DGV.actions[i], i ))		
                DGV:SetQuestColor(i)
                DGV:SetQuestText(i)
            end
		end
	end

	function DGV:UpdatePlayerLevels(playerLevel)
		local i
		playerLevel = playerLevel or UnitLevel("player")
		if DGV:isValidGuide(CurrentTitle) == true then
			local guidesize = DGV:GetLastGuideNumRows()	
			for i=1, guidesize do		
				local reqlvl = self:ReturnTag("PL", i)	
				if reqlvl and reqlvl <= playerLevel and DGV:GetQuestState(i) ~= "C" and not strmatch(self.actions[i], "[f]") then
					self:SetChkToComplete(i)
					if i == DGU.CurrentQuestIndex then self:MoveToNextQuest() end
				end
			end
		end
	end
	
	local function EvaluateMAP(map)
		if map then 
			if DGV:GetPlayerMapPositionDisruptive() == tonumber(map) then return true end
		end
	end
	
	local function EvaluatePHA(pha)
		local currentMap = DGV:GetCurrentMapID()
		local isCurrentMapIsleOfThunder = currentMap == 504 or currentMap == 505 or currentMap == 506
	
		if isCurrentMapIsleOfThunder and NUM_WORLDMAP_POIS == 0 then 
			--WorldMapFrame_Update()
			if NUM_WORLDMAP_POIS == 0 then return true end
		end
		if isCurrentMapIsleOfThunder then 			
			local lowest = 6
			for i=1, NUM_WORLDMAP_POIS do
				local _, poiID

                if GetMapLandmarkInfo then
                    _, _, _, _, _, _, _, _, _, poiID = GetMapLandmarkInfo(i)
                else
                    _, _, _, _, _, _, _, _, _, _, poiID = C_WorldMap.GetMapLandmarkInfo(i)
                end

				if WorldMap_IsSpecialPOI(poiID) then 
					if SPECIAL_POI_INFO[poiID].phase < lowest then 
						lowest = SPECIAL_POI_INFO[poiID].phase
					end
				end
			end
			if lowest ~= 6 then
				return lowest >= tonumber(pha)
			end
		end
	end
	
	local function EvaluateBUFF(buff)
		if buff then 
			buff = tonumber(buff)
		end
		for i=1,10 do
			local _,icon = UnitBuff("player",i)
			if (icon and icon == buff) then return true end
			local _,icon = UnitDebuff("player",i)
			if (icon and icon == buff) then return true end
		end
	end		

	local function EvaluateTID(tid)
		return IsQuestFlaggedCompleted(tid) and not DGV:GetQuestLogIndexByQID(tid)
	end	
	
	local function EvaluateAYG(ayg)
		local index = DGV:GetQuestLogIndexByQID(tonumber(ayg))
		local aygComplete
		if index then 		
			aygComplete = select(6, GetQuestLogTitle(index))
		end
		return IsQuestFlaggedCompleted(ayg) or aygComplete
	end		
	
	local function EvaluateOID(oid)
		local index = DGV:GetGuideIndexByQID(tonumber(oid), "A")
		return (index and DGV:GetQuestState(index) == "C") or IsQuestFlaggedCompleted(oid)
	end		

	local function EvaluatePRE(pre)
		local index = DGV:GetGuideIndexByQID(tonumber(pre), "T")
		--if index then DebugPrint("Debug EvaluatePRE: pre="..tonumber(pre).." DGV:GetQuestState(index)="..DGV:GetQuestState(index)) end
		return (index and DGV:GetQuestState(index) == "C") or IsQuestFlaggedCompleted(pre)
	end

	local function EvaluateREP(factionId, standingRequirement)
		local name, _, standingID = GetFactionInfoByID(tonumber(factionId))
		--DebugPrint("Debug EvaluateREP: standingID="..tostring(standingID).." name="..tostring(name).." factionId="..tonumber(factionId))
		if not standingID then 
			standingID = 4
		end		
		return standingID >= tonumber(standingRequirement)
	end

	local function EvaluateFS(factionId, standingRequirement)
		local name, _, _, _, _, barValue = GetFactionInfoByID(tonumber(factionId))
		return barValue >= tonumber(standingRequirement)
	end

	local function GetVisualRow(i, row)
		if row then return _G[row..i] else return visualRows[i] end
	end

	local function CheckInitOpt(i, row)
		local Row = GetVisualRow(i, row)
		if Row.Opt.text==nil then
			local optional 		= DGV:ReturnTag("O", i)
			local pre, pre2		= DGV:ReturnTag("PRE", i)
			local pha			= DGV:ReturnTag("PHA", i)			
			local rep, standing	= DGV:ReturnTag("REP", i)
			local friend, level	= DGV:ReturnTag("FS", i)
			local prof, _		= DGV:ReturnTag("OP", i)
			if optional then
				Row.Opt.text = string.format(" (%s)", L.Optional)
				Row.Opt.optional = true
			elseif pre then
				Row.Opt.text = string.format(" (%s)", L["Pre-quest required"])
				Row.Opt.pre = tonumber(pre)
			elseif pre2 then
				Row.Opt.text = string.format(" (%s)", L["Pre-quest required"])
				Row.Opt.pre2 = tonumber(pre2)				
			elseif pha then
				Row.Opt.text = string.format(" (%s)", L["Stage required"])
				Row.Opt.pha = tonumber(pha)				
			elseif rep then
				Row.Opt.text = string.format(" (%s)", L["Reputation Required"])
				Row.Opt.rep, Row.Opt.standing = tonumber(rep), tonumber(standing)
			elseif friend then
				Row.Opt.text = string.format(" (%s)", L["Reputation Required"])
				Row.Opt.friend, Row.Opt.level = tonumber(friend), tonumber(level)
			elseif prof then
				Row.Opt.text = string.format(" (%s)", L["Profession Required"])
				Row.Opt.prof = true	
			else
				Row.Opt.text	= ""
			end
		end
	end
	 
	function DGV:SetQuestColor(i) 
		local Row = GetVisualRow(i)
		local questpart = self:ReturnTag("QIDP", i)
		if DGV:CheckForSkip(i) then CheckInitOpt(i) end
		
		
		if (Row.Opt.optional and i~= DGU.CurrentQuestIndex and self:GetQuestState(i) ~= "C") or 
			(Row.Opt.prof and i~= DGU.CurrentQuestIndex and self:GetQuestState(i) ~= "C") or
			(Row.Opt.pre and not EvaluatePRE(Row.Opt.pre)) or 
			(Row.Opt.pre2 and not EvaluatePRE(Row.Opt.pre2)) or 			
			(Row.Opt.pha and not EvaluatePHA(Row.Opt.pha)) or
			(Row.Opt.rep and not EvaluateREP(Row.Opt.rep, Row.Opt.standing)) or
			(Row.Opt.friend and not EvaluateFS(Row.Opt.friend, Row.Opt.level)) then
			Row.Name:SetTextColor(0.75, 0.75, 0.75, 1)
			Row.Desc:SetTextColor(0.75, 0.75, 0.75, 1) 
			Row.Opt:SetTextColor(0.75, 0.75, 0.75, 1) 
			Row.Opt:SetFontObject("GameFontHighlightSmall",5)
			return
		elseif (strmatch(self.actions[i], "[ACT]") and self:UserSetting(DGV_QUESTCOLORON)) or (questpart and strmatch(self.actions[i], "[NK]") and self:UserSetting(DGV_QUESTCOLORON)) then	--set difficulty color on A/C/T actions
			local color  = self:GetQuestDiffColor(i)
			if color then
				Row.Name:SetTextColor(color.r, color.g, color.b, 1) 
				Row.Opt:SetTextColor(color.r, color.g, color.b, 1) 		
			end
			return
		end
		DGV:SetQuestTextNormal(i)
	end

	function DGV:GetQuestDiffColor(i)
		local color
		local qid = self.qid[i]
		if qid then
			local level = DGV:GetQuestLevel(qid)
			if level and level > 0 then
				color = GetQuestDifficultyColor(level)
			end
		end
		return color
	end

	function DGV:SetAllQuestColor()
		local i, qid
		for i, qid in ipairs(DGV.actions) do
			DGV:SetQuestColor(i)
		end
	end

	function DGV:GetQuestLevel(qid)
		if self.ReqLevel[qid] then
			return self.ReqLevel[qid][1]
		end
	end

	function DGV:GetReqQuestLevel(qid)
		if self.ReqLevel[qid] then
			return self.ReqLevel[qid][2]
		end
	end

	function DGV:SetChkToComplete(i)
		if DGV:isValidGuide(CurrentTitle) == true and not visualRows[i].Chk:GetChecked() then
			self:SetQuestState(i, "C")
		end
	end

    function DGV:SetChkToNotComplete(i)
		if DGV:isValidGuide(CurrentTitle) == true then
			self:SetQuestState(i, "U")
			visualRows[i].Chk:SetChecked(false)
		end
	end

	function DGV:AchieveCompleteFromAchieveID(achieveID, achieveIndex)
		if achieveID ~= 6856 and 
			achieveID ~= 6716 and 
			achieveID ~= 6846 and 
			achieveID ~= 6754 and 
			achieveID ~= 6857 and 
			achieveID ~= 6850 and 
			achieveID ~= 6855 and 
			achieveID ~= 6847 and 
			achieveID ~= 6858 and -- Exclude lorewalker achievement 
			self:UserSetting(DGV_ACCOUNTWIDEACH) then -- Account Wide Achievement
			if (select(4, GetAchievementInfo(achieveID))) then return true end
		end 
		
		if not achieveID then
			return achieveID
		end
		
		local achievementNum = tonumber(GetAchievementNumCriteria(achieveID))
		if achieveIndex and tonumber(achieveIndex) <= achievementNum then
			return (select(3, GetAchievementCriteriaInfo(achieveID, achieveIndex)))
		elseif achieveIndex and achieveID then
			--print(achieveID.." "..achieveIndex)
		end
		
	end

	function DGV:AchieveCompleteFromGuideIndex(guideindx)
		--achieve
		if self.gtype[CurrentTitle] == "A" or self.gtype[CurrentTitle] == "E" or self.gtype[CurrentTitle] == "D" then 
			local comp, categoryID, description, completed, achieveID, achieveIndex, ret
			achieveID = self:ReturnTag("AID", guideindx)
			achieveIndex = self:ReturnTag("AC", guideindx)
			
			if achieveID then
				ret = self:AchieveCompleteFromAchieveID(achieveID, achieveIndex)
				return ret
			end
		end
	end

	function DGV:PrintAchieve(achieveID, achieveIndex)
		local name, completed, description, ccompleted, cdescription
		
		_, name, _, completed, _, _, _, description, _, _, _ = GetAchievementInfo(achieveID)
		if completed == true then comp = " complete" else comp = " NOT complete" end

		if achieveIndex then
			cdescription, _, ccompleted = GetAchievementCriteriaInfo(achieveID, achieveIndex)
			if ccompleted == true then ccomp = " complete" else ccomp = " NOT complete" end
			DebugPrint("["..achieveID.."] "..name..comp.." STEP: ["..achieveIndex.."] "..cdescription..ccomp)	
		else
			DebugPrint("["..achieveID.."] "..name..comp)			
		end
	end

	function DGV:PrintAllGuideAchieves()
		for i=1, #visualRows do
			local achieveID = self:ReturnTag("AID", i)
			local achieveIndex = self:ReturnTag("AC", i)
			if achieveID then self:PrintAchieve(achieveID, achieveIndex) end
		end
	end

	function DGV:SetQuestsState(isInThread)
		--SuspendViewFrameUpdate()
		local i
		if DGU.QuestState and visualRows and #visualRows then
			
			--Find all previously completed quests and check them
			for i=1, #visualRows do		
				LuaUtils:RestIfNeeded(isInThread)
            
				local qid = self.qid[i]
				local state = self:GetQuestState(i)
				if state == "X" or DGU.toskip[qid] then --User skipped	
					self:SetChktoX(i)	
				elseif state == "C" then
					self:SetChkToComplete(i)
				else
					self:ClrChk(i)
				end
			end
			
			self:UpdateMainFrame(isInThread)

		end	
		--ResumeViewFrameUpdate()	--UpdateMainFrame will ResumeViewFrameUpdate()
	end

	function DGV:HasQuestBeenTurnedIn(qid)
		if qid then
			return IsQuestFlaggedCompleted(qid)
		end
		-- if DGU.turnedinquests[qid] then
			-- return true
		-- end
	end
	
	local function IsPlayerLevelWithinRange(playerLevel, range)
		if not range then return end
		local minimum, operator, maximum = range:match("%((%d+)(.)(%d*)")
		minimum = tonumber(minimum); maximum = tonumber(maximum)
		if not maximum and operator=="+" then maximum=GetMaxPlayerLevel() end
		return 
			minimum 
			and minimum <= playerLevel 
			and maximum 
			and (maximum > playerLevel or maximum == GetMaxPlayerLevel()),
			minimum,
			maximum
	end

	local function IterateGuidesInRange(invariant, control)
		local playerLevel = DGU.PlayerLevel or UnitLevel("player")
		while true do
			control = next(DGV.guides, control)
			if not control then return end
			local pass, minimum, maximum = IsPlayerLevelWithinRange(playerLevel, DGV:GetGuideRange(control))
			if pass then
				if minimum > UnitLevel("player") - 20 then --need this to reduce suggestions in lower levels
					return control, minimum, maximum
				end
			end
		end
	end
	
	local inRangeLabels = {}
	local inRangeButtons = {}
    
    local function UpdateSuggestFrameImage(mainGuideMetaData, forDungeons)
        local hasImagePreview = (mainGuideMetaData ~= nil and mainGuideMetaData.image ~= nil and mainGuideMetaData.image ~= "")
            
        if hasImagePreview then
            local image = mainGuideMetaData.image
            DugisGuideSuggestFrame.GuideImage:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\Guides\\"..image)
            
            DugisGuideSuggestFrame.GuideImage:SetPoint( "TOPLEFT",  DugisGuideSuggestFrame.GuideTitle,  "TOPLEFT",  10, -35)
            
            if forDungeons then
                DugisGuideSuggestFrame:SetHeight(120 + 138)
            else
                DugisGuideSuggestFrame:SetHeight(120 + 158)
            end
            
            DugisGuideSuggestFrame.Or:SetPoint( "TOPLEFT",  DugisGuideSuggestFrame.GuideTitle,  "TOPLEFT",  -17, -175)
            DugisGuideSuggestFrame.GuideImage:Show()
        else
            DugisGuideSuggestFrame.GuideImage:SetTexture(nil)
            DugisGuideSuggestFrame:SetHeight(120)
            DugisGuideSuggestFrame.Or:SetPoint( "TOPLEFT",  DugisGuideSuggestFrame.GuideTitle,  "TOPLEFT",  -17, -25)
            DugisGuideSuggestFrame.GuideImage:Hide()
        end
    end
    
    --Examples:
    --/script AskDungeonGuideSuggest("121(34-39)#121(35-41)#121(36-42)")
    --/script AskDungeonGuideSuggest("462(1-10 Blood Elf)#462(1-12 Blood Elf)#462(1-13 Blood Elf)", "121(34-39)#121(35-41)#121(36-42)")
	function AskDungeonGuideSuggest(...)
        DugisGuideSuggestFrame.GuideImage:Hide()
        
		if DGV:UserSetting(DGV_GUIDESUGGESTMODE) then
            local suggestedGuideRaw = select(1, ...)
			local suggestedGuide = DGV:GetFormattedTitle(suggestedGuideRaw)
			DugisGuideSuggestFrame.Title:SetText(L["Suggested Dungeon Guide"]..":")
			DugisGuideSuggestFrame.Or:SetText(L["Alternative Dungeon Guides"]..":")
			DugisGuideSuggestFrame.GuideTitle:SetText("|cffffffff"..suggestedGuide.."|r")
            
            local mainGuideMetaData = DugisGuideViewer.guidemetadata[suggestedGuideRaw]
            
			DugisGuideSuggestFrame:SetFrameStrata("TOOLTIP")
			DugisGuideSuggestFrame.Title2:Hide()
			DugisGuideSuggestFrame.CompleteYesButton:Hide()			
			DugisGuideSuggestFrame:Show()
			DugisGuideSuggestFrame.suggestedGuide = suggestedGuide
			for _,label in ipairs(inRangeLabels) do
				label:Hide()
			end
			for _,button in ipairs(inRangeButtons) do
				button:Hide()
			end
            
            UpdateSuggestFrameImage(mainGuideMetaData, true)
			DugisGuideSuggestFrame.Or:Hide()
			
			local lastFontString
			for i=2,select("#", ...) do
				local dungeonGuide = select(i, ...)
				local formatted = DGV:GetFormattedTitle(dungeonGuide)
				
				local fontString,button = inRangeLabels[i-1],inRangeButtons[i-1]
				if not fontString then
					fontString = DugisGuideSuggestFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
					fontString:SetJustifyH("LEFT")
					fontString:SetWidth(240)
					fontString:SetHeight(25)
					fontString:SetPoint(
						"TOPLEFT", 
						lastFontString or  DugisGuideSuggestFrame.Or, 
						"BOTTOMLEFT", 
						(lastFontString and 0) or 20, 0)
					tinsert(inRangeLabels, fontString)
					
					button = CreateFrame("Button", nil, DugisGuideSuggestFrame, "UIPanelButtonTemplate")



					button:SetWidth(55)
					button:SetHeight(23)
					button:SetPoint("LEFT", fontString, "RIGHT", 5, 0)
					button:SetText("Go")
					tinsert(inRangeButtons, button)
				end
				fontString:SetText("|cffffffff"..formatted.."|r")
				fontString:Show()
				button:SetScript("OnClick", 
					function()
						print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(formatted).."|cff11ff11 selected.|r")
						DGV:DisplayViewTab(DGV:GetRawTitle(formatted))
						PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
						DugisGuideSuggestFrame:Hide()
					end)
				button:Show()
				lastFontString = fontString
			end
			if select("#", ...)>1 then
				DugisGuideSuggestFrame:SetHeight(DugisGuideSuggestFrame:GetHeight()+(select("#", ...)-1)*25+35)
				DugisGuideSuggestFrame.Or:Show()
			end
		end
	end
	
	local dungeonMatches
	local function MatchDungeonGuides(currentZone, playerLevel)
		if not currentZone then
            LuaUtils:DugiSetMapToCurrentZone()
			--currentZone = DGV:GetPlayerMapPositionDisruptive()
			currentZone = DGV:GetCurrentMapID() 
		end
		if not playerLevel then
			playerLevel = UnitLevel("player")
		end
		local preferredSuggestionFound
		if not dungeonMatches then dungeonMatches = {} end
		wipe(dungeonMatches)
		if DGV.guidelist["I"] then 
			for _,title in ipairs(DGV.guidelist["I"]) do
				local zone = tonumber(title:match("^(%d+)"))
				if not zone then
					zone = tonumber(DGV:GetMapIDFromName(title:match("^(.-)%s?%(")))
				end
				if currentZone==zone then
					if CurrentTitle==title then return end
					local range = DGV:GetGuideRange(title)
					if not preferredSuggestionFound and IsPlayerLevelWithinRange(playerLevel, range) then
						preferredSuggestionFound = true
						tinsert(dungeonMatches, 1, title)
					else
						tinsert(dungeonMatches, title)
					end
				end
			end
		end 
		if dungeonMatches and #dungeonMatches>0 then
			AskDungeonGuideSuggest(unpack(dungeonMatches))
			return true
		end
	end
	
	local function SuggestDungeonsByLevelRange(playerLevel)
		if not dungeonMatches then dungeonMatches = {} end
		wipe(dungeonMatches)
		for guideInRange in IterateGuidesInRange do
			if DGV.gtype[guideInRange] == "I" then
				tinsert(dungeonMatches, guideInRange)
			end
		end
		if dungeonMatches and #dungeonMatches>0 then
			AskDungeonGuideSuggest(unpack(dungeonMatches))
			return true
		end
	end

	function DGV:DugisSuggestButtonOnClick()
		local playerLevel = UnitLevel("player")
		if activeTabInfo.text=="Leveling" then
			DGV:AskGuideSuggest(playerLevel)
		elseif activeTabInfo.text=="Dungeons" then
			local currentZone = DGV:GetPlayerMapPositionDisruptive()
			if not MatchDungeonGuides(currentZone, playerLevel) then
				SuggestDungeonsByLevelRange(playerLevel)
			end
		end
	end
	
	-- 
	-- Guide Suggest
	--
    --/script DugisGuideViewer:AskGuideSuggest()
    --/script AskDungeonGuideSuggest("462(1-10 Blood Elf)#462(1-12 Blood Elf)#462(1-13 Blood Elf)", "121(34-39)#121(35-41)#121(36-42)")
	function DGV:AskGuideSuggest(playerLevel)
        DugisGuideSuggestFrame.GuideImage:Hide()
    
		if not playerLevel then
			playerLevel = UnitLevel("player")
		end

		if self:UserSetting(DGV_GUIDESUGGESTMODE) then
			local suggestedGuide, suggestedGuideRaw = self:GetSuggestedGuide(playerLevel)
			if not suggestedGuide and UnitLevel("player") ~= GetMaxPlayerLevel() then 
				print("|cff11ff11Dugi Guides: |rPlayer level "..UnitLevel("player").." guide not installed."); return 
			elseif not suggestedGuide then
				return
			end
			suggestedGuide = self:GetFormattedTitle(suggestedGuide)
			DugisGuideSuggestFrame.Title:SetText(L["Suggested Leveling Guide"]..":")
			DugisGuideSuggestFrame.Or:SetText(L["Alternative Leveling Guides"]..":")
			DugisGuideSuggestFrame.GuideTitle:SetText("|cffffffff"..suggestedGuide.."|r")
			DugisGuideSuggestFrame:SetFrameStrata("TOOLTIP")
			DugisGuideSuggestFrame.Title2:Show()
			DugisGuideSuggestFrame.CompleteYesButton:Show()
			DugisGuideSuggestFrame:Show()
			DugisGuideSuggestFrame.suggestedGuide = suggestedGuide
			for _,label in ipairs(inRangeLabels) do
				label:Hide()
			end
			for _,button in ipairs(inRangeButtons) do
				button:Hide()
			end
			DugisGuideSuggestFrame:SetHeight(120)
            
            local mainGuideMetaData = DugisGuideViewer.guidemetadata[suggestedGuideRaw]
            UpdateSuggestFrameImage(mainGuideMetaData)
            
			DugisGuideSuggestFrame.Or:Hide()
			local lastFontString
			local rangeCount = 0
			for guideInRange,minimum in IterateGuidesInRange do
				if minimum > 1 then

					local formatted = self:GetFormattedTitle(guideInRange)
					if formatted~=suggestedGuide and self.gtype[guideInRange] == "L" then
						rangeCount = rangeCount + 1
						local fontString,button = inRangeLabels[rangeCount],inRangeButtons[rangeCount]
						if not fontString then
							fontString = DugisGuideSuggestFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
							fontString:SetJustifyH("LEFT")
							fontString:SetWidth(240)
							fontString:SetHeight(25)
							fontString:SetPoint(
								"TOPLEFT", 
								lastFontString or  DugisGuideSuggestFrame.Or, 
								"BOTTOMLEFT", 
								(lastFontString and 0) or 20, 0)
							tinsert(inRangeLabels, fontString)
							
							button = CreateFrame("Button", nil, DugisGuideSuggestFrame, "UIPanelButtonTemplate")



							button:SetWidth(55)
							button:SetHeight(23)
							button:SetPoint("LEFT", fontString, "RIGHT", 5, 0)
							button:SetText("Go")
							tinsert(inRangeButtons, button)
						end
						fontString:SetText("|cffffffff"..formatted.."|r")
						fontString:Show()
						button:SetScript("OnClick", 
							function()
								print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(formatted).."|cff11ff11 selected.|r")
								DGV:DisplayViewTab(DGV:GetRawTitle(formatted))
								PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
								DugisGuideSuggestFrame:Hide()
							end)
						button:Show()
						lastFontString = fontString
					end
				end
			end
			if rangeCount>0 then
				DugisGuideSuggestFrame:SetHeight(DugisGuideSuggestFrame:GetHeight()+rangeCount*25+35)
				DugisGuideSuggestFrame.Or:Show()
			end
		end

	end

	function DGV:SuggestButtonOnClick(firstTime, threading)
		local suggestedGuide
		
		if firstTime then 
			suggestedGuide = DGV:GetSuggestedGuide(UnitLevel("player"))
		else 
			suggestedGuide = DugisGuideSuggestFrame.suggestedGuide
		end
		
		if suggestedGuide then 
			DebugPrint("#SUGGESTED:"..suggestedGuide) 
		elseif UnitLevel("player") ~= GetMaxPlayerLevel() then
			DebugPrint("#SUGGESTED: NIL")
			print("|cff11ff11Dugi Guides: |rPlayer level "..UnitLevel("player").." guide not installed.")
		end
		
		if suggestedGuide then
			print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(suggestedGuide).."|cff11ff11 selected.|r")
			
			DGV:DisplayViewTab(DGV:GetRawTitle(suggestedGuide), nil, threading)
			PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg")
		end
		
		DugisGuideViewer:RemoveGuideSuggestionNotifications()
		
		DugisGuideSuggestFrame:Hide()
	end

	function DGV:CompleteCurrentQuest()
		if CurrentTitle == nil or DGV.gtype[CurrentTitle] ~= "L" then 
			print("|cff11ff11Dugi Guides:|r No leveling guide loaded. Select a leveling guide first by clicking the suggest button or choose one manually.")
		else 
			local logindex
			local i = DGU.CurrentQuestIndex
			while i <= #visualRows do
					logindex = self:GetQuestLogIndexByQID(self.qid[i])
					if not logindex and (DGV:GetQuestState(i) ~= "C") then
						self:SetChktoX(i)
				end
				i = i + 1
			end		
			DugisGuideSuggestFrame:Hide()
			DGV:DisplayViewTab(CurrentTitle)
			self:MoveToNextQuest()
			print("|cff11ff11Dugi Guides:|r Skipped (|cffcc0000x|r) all steps not related to Quests in Log.")
		end
		
		DugisGuideViewer:RemoveGuideSuggestionNotifications()	
	end
    
    if  DugisGuideUser.alreadySuggestedGuides == nil then
        DugisGuideUser.alreadySuggestedGuides = {}
    end
    
	function DGV:ShouldSuggestNewGuide(playerLevel, checkIfWasAlreadySuggested)
		--Don't suggest new guide when player can't move to next zone
		--502 DK Start Zone, 539, 611, 545, 678, 679, Worgen Start Zone, 605, 544, 681, 682 Goblin Start Zone
		local mapId = DGV:GetCurrentMapID() 
		DebugPrint("Current mapID:"..mapId)
		if mapId == 502 or mapId == 539 or mapId == 611 or mapId == 545 or mapId == 678 or mapId == 679 or mapId == 605 or mapId == 544 or mapId == 681 or mapId == 682 or mapId == 808 then return end 
        
		local suggestedGuide, suggestedGuideRaw = self:GetSuggestedGuide(playerLevel)
        
		if suggestedGuide ~= CurrentTitle and suggestedGuideRaw ~= nil and (not DugisGuideUser.alreadySuggestedGuides[suggestedGuideRaw] or not checkIfWasAlreadySuggested) then
            --Adding to buffer so in the future the same guide is not suggested anymore
            DugisGuideUser.alreadySuggestedGuides[suggestedGuideRaw] = true
			return true
		end
	end
    
	function DGV:LevelUpSuggestGuide(playerLevel)
        if DGV:ShouldSuggestNewGuide(playerLevel) then
            DGV:AskGuideSuggest(playerLevel)
        end
	end
	
	local lastCheck = -1
	function DGV.ShowSuggestGuideNotification(playerLevelToBeUsed, onLevelUp)
		local playerLevel = playerLevelToBeUsed or UnitLevel("player")
        
        --CurrentTitle
        if DGV:ShouldSuggestNewGuide(playerLevel, DGV:UserSetting(DGV_ENABLED_GUIDE_NOTIFICATIONS) and DugisGuideViewer:NotificationsEnabled()) 
        and (CurrentTitle == nil or DGV.gtype[CurrentTitle] == "L") then
			if DGV:UserSetting(DGV_ENABLED_GUIDE_NOTIFICATIONS) and DugisGuideViewer:NotificationsEnabled() then
				
				local notification = DugisGuideViewer:GetNotificationByType("guide-suggestion")
				if notification == nil then
					--Show notification
					--Check if notification already exist:
					notification = DugisGuideViewer:AddNotification({title = "Leveling Guide Suggested"
					, notificationType = "guide-suggestion"})
					DugisGuideViewer:ShowNotifications()   
					DugisGuideViewer.RefreshMainMenu()
				end
				
				if DGV:UserSetting(DGV_ALWAYS_SHOW_STANDARD_PROMPT_GUIDE) then
					DugisGuideViewer:AskGuideSuggest(playerLevel)
				end
				
			else
				--Old standard prompt
				if onLevelUp then
					DugisGuideViewer:AskGuideSuggest(playerLevel)
				end
			end
		
		end
	end
	
	LuaUtils:Delay(5, function()
		DugisGuideUser.alreadySuggestedGuides = {}
		
		LuaUtils:invokeWhen(function()
			return DugiGuidesIsLoading == false
		end, function()
			DugisGuideViewer.ShowSuggestGuideNotification()	
		end)
		
	end)
	
	function DGV:PLAYER_XP_UPDATE(self, level) --not really needed, extra calculations for no reason. 
		--[[local playerXP = UnitXP("player")
		local nextXP = UnitXPMax("player") 
		local percent = playerXP/nextXP
                
        LuaUtils:foreach({0, 1, 2, 3, 4}, function(value)
            value = value * 0.2
            if percent >= value and percent < (value + 0.2) and lastCheck ~= value then
                DGV.ShowSuggestGuideNotification()
                lastCheck = value
            end
        end) ]]
	end	
    
	local function _CycleThroughGuides(guideName, playerLevel)
		local safety = 0
		playerLevel = playerLevel or UnitLevel("player")
		DebugPrint("playerLevel is"..playerLevel.." unitlevel is"..UnitLevel("player"))
		
		while guideName and safety < 50 do
			local LevelRange = DGV:GetGuideRange(guideName)
			if IsPlayerLevelWithinRange(playerLevel, LevelRange) then
				return guideName
			end
			
			safety = safety + 1
			guideName = DGV.nextzones[guideName]
		end
	end

    
    --Result: Formatted Guide, Raw Guide
	function DGV:GetSuggestedGuide(playerLevel)
		if CurrentTitle then DebugPrint("[SG] Start at current guide:"..CurrentTitle) end
		
		local suggestion
		--Only search starting with CurrentTitle if we are on a Leveling guide
		if DGV.gtype[CurrentTitle] == "L" then suggestion = _CycleThroughGuides(self:GetRawTitle(CurrentTitle), playerLevel) end
		
		if suggestion then DebugPrint("[SG] Suggestion from current guide:"..suggestion) return suggestion, suggestion end 
			
		local playerClass, engPlayerClass = UnitClass("player")
		local playerRace,  engPlayerRace  = UnitRace("player") 
		local playerFaction,  engPlayerFaction  = UnitFactionGroup("player") 
		local guideName
		-- 
		-- Starting Zones
		--
		local startguides = 
		{
				BloodElf = "94(1-20 Blood Elf)#94(1-20 Blood Elf)#94(1-20 Blood Elf)", 
				Orc = "1(1-10 Orc)#1(1-10 Orc)#1(1-10 Orc)", 
				Troll = "1(1-10 Troll)#1(1-10 Troll)#1(1-10 Troll)", 
				Goblin = "194(1-5 Goblin)",
				Tauren = "7(1-20 Tauren)#7(1-20 Tauren)#7(1-20 Tauren)", 
				Scourge = "18(1-20 Undead)#18(1-20 Undead)#18(1-20 Undead)", 
				Undead = "18(1-20 Undead)#18(1-20 Undead)#18(1-20 Undead)", 
				Dwarf = "27(1-10 Dwarf)#27(1-10 Dwarf)#27(1-10 Dwarf)", 
				Gnome = "27(1-10 Gnome)#27(1-10 Gnome)#27(1-10 Gnome)", 
				Draenei = "97(1-20 Draenei)#97(1-20 Draenei)#97(1-20 Draenei)", 
				Human = "37(1-20 Human)#37(1-20 Human)#37(1-20 Human)", 
				NightElf = "57(1-20 Night Elf)#57(1-20 Night Elf)#57(1-20 Night Elf)", 
				Worgen = "179(1-12 Worgen)", 
				DeathKnight = "124(55-60 Death Knight)",
				Pandaren = "378(1-12 Pandaren)",
				DemonHunter = "672(98-100)",
--				VoidElf = "",
--				LightforgedDraenei = "",
--				Nightborne = "",
--				HighmountainTauren = "",
		}
		
		if (engPlayerClass == "DEATHKNIGHT") then
			guideName = startguides["DeathKnight"]
		elseif (engPlayerClass == "DEMONHUNTER") then
			guideName = startguides["DemonHunter"]
		elseif (engPlayerRace == "Pandaren") and (engPlayerFaction == "Alliance") then 
			guideName = startguides["Human"]
		elseif (engPlayerRace == "Pandaren") and (engPlayerFaction == "Horde") then 
			guideName = startguides["Orc"]
		else 
			guideName = startguides[engPlayerRace] 
		end
		--DebugPrint("guideName"..guideName)
		DebugPrint("[SG] No guide found, begin with starting playerRace"..engPlayerRace)
		suggestion = _CycleThroughGuides(guideName, playerLevel)

		if suggestion then DebugPrint("[SG] Suggestion is: "..self:GetFormattedTitle(suggestion)) return self:GetFormattedTitle(suggestion), suggestion end



	end

	function DGV:ReturnGuideTag(tag, Title, threading)
		local GuideTitle = Title or CurrentTitle
		local GuideTags = self.guidetags[GuideTitle]
		
		if not GuideTags then return end
		
		if tag == "PZ" then
			return GuideTags:match("|PZ|")
		elseif tag == "SG" then
			local _, _, check 	= GuideTags:find("|SG|([^|]+)|")
			return check and loadstring("return "..check)()
		end
	end

	function DGV:GetQuestDescription(guideIndex)
		local self = DGV
		local isCollect, desc
		local action 	 = DGV.actions[guideIndex]
		local questTitle = DGV.quests1L[guideIndex]
		
		if NPCJournalFrame then
			questTitle = NPCJournalFrame:ReplaceSpecialTags(DGV.quests1L[guideIndex], true)
		end
		
		local questDesc  = DGV:RemoveParen(DGV.quests2[guideIndex]) 
		local npcID		 = DGV:ReturnTag("NPC", guideIndex)
		
		questDesc 	= self:GetLocalizedNPC(npcID) or questDesc	
		questTitle 	= self:TranslateQuestObjective(guideIndex) or questTitle
		
		if (DGV:ReturnTag("T", guideIndex)) then isCollect = true end
		
		if not questTitle then questTitle = "..." end
		if not questDesc then questDesc = "..." end
		
		if action == "A" then
			if questDesc ~= "" then
				desc = L["Accept"].." |cffffd200'"..questTitle.."'|r ("..questDesc..")"
			else
				desc = L["Accept"].." |cffffd200'"..questTitle.."'|r"
			end
		elseif action == "T" then
			if questDesc ~= "" then
				desc = L["Turn in"].." |cffffd200'"..questTitle.."'|r ("..questDesc..")"
			else
				desc = L["Turn in"].." |cffffd200'"..questTitle.."'|r"
			end
		elseif action == "F" then
			desc = L["Fly to"].." |cffffd200"..questTitle.."|r"
		elseif action == "C" then
			desc = L["Complete"].." |cffffd200'"..questTitle.."'|r"
		elseif action == "R" then
			desc = L["Travel to"].." |cffffd200"..questTitle.."|r"
		elseif action == "H" then
			desc = L["Hearth to"].." |cffffd200"..questTitle.."|r"
		elseif action == "h" then
			desc = L["Set Hearth at"].." |cffffd200"..questTitle.."|r"
		elseif action == "f" then
			desc = L["Grab"].." |cffffd200"..questTitle.."|r flight path"				
		elseif action == "U" then
			desc = L["Use"].." |cffffd200"..questTitle.."|r"
		elseif action == "K" then
			desc = L["Kill"].." |cffffd200"..questTitle.."|r"
		elseif action == "B" then
			desc = L["Buy"].." |cffffd200"..questTitle.."|r"
		elseif isCollect == true then
			desc = L["Collect"].." |cffffd200"..questTitle.."|r" 			
		else
			desc = "|cffffd200"..(questTitle or "").."|r"
		end
		return desc
	end

	local function IsInDungeon(mapID)
		if mapID ~= 970 and DGV.Modules.TaxiData.InstancePortals[mapID] then
			return true
		else
			return
		end
	end
	
	--Map current quest. LuaUtils:DugiGetQuestWorldMapAreaID return 0 if player is not on quest
	if not DelayAndMapCurrentObjectiveFrame then
		DelayAndMapCurrentObjectiveFrame = CreateFrame("Frame")
		DelayAndMapCurrentObjectiveFrame:Hide() 
	end 
	
	function DGV:DelayAndMapCurrentObjective(delay, func) 
		if DelayAndMapCurrentObjectiveFrame:IsShown() then return end
		DelayAndMapCurrentObjectiveFrame.func = func
		DelayAndMapCurrentObjectiveFrame.delay = delay 
		DelayAndMapCurrentObjectiveFrame:Show()
	end
	
	DelayAndMapCurrentObjectiveFrame:SetScript("OnUpdate", function(self, elapsed) 
		self.delay = self.delay - elapsed 
		if self.delay <= 0 then  
			self:Hide() 
			DGV:MapCurrentObjective()
			DGV:WatchQuest()
		end
	end)		
	
	function DGV:MapCurrentObjective(guideIndex, onclick)
	if DGV:isValidGuide(CurrentTitle) == true then
		if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and not onclick then 
			guideIndex = DugisGuideUser.NextQuestIndex
		else 	
			guideIndex = guideIndex or DGU.CurrentQuestIndex
		end 
	
		local mapID, mapFloor, desc, i, TomTomUID, qid
		
		if self:UserSetting(DGV_WAYPOINTSON) or onclick then
			desc = DGV:GetQuestDescription(guideIndex)
			qid = self.qid[guideIndex]
			
			-- Get the mapFloor and mapID
			if self:ReturnTag("Z", guideIndex) then 
				mapID, mapFloor = self:ReturnTag("Z", guideIndex)
				if mapFloor == nil then 
					if IsInDungeon(mapID) or mapID == 504 or mapID == 321 then --Dalaran and Orgrimmar
						mapFloor = 1 
					else 
						mapFloor = 0 
					end
				end			
				--DebugPrint("Mapping with |Z|mapID mapFloor| tag mapId: "..mapID)
				--if mapFloor then DebugPrint("Note floor"..mapFloor) end
			-- Use guide header if a valid Guide Zone is stated 	
			elseif self:GetMapNameFromID(self.GuideMapID) then 
				--DebugPrint("Mapping with Guide zone: "..self.GuideMapID)
				mapID = self.GuideMapID
				if IsInDungeon(mapID) or mapID == 504 or mapID == 321 then --Dalaran and Orgrimmar
					mapFloor = 1 
				else 
					mapFloor = 0 
				end
			-- Use the QID zone. 
			elseif qid and LuaUtils:DugiGetQuestWorldMapAreaID(qid) ~= 0 then 
				--DebugPrint("Mapping with QID zone: "..LuaUtils:DugiGetQuestWorldMapAreaID(qid) )
				mapID, mapFloor = LuaUtils:DugiGetQuestWorldMapAreaID(qid), GetCurrentMapDungeonLevel()
			end
				
			--Remove previous objective's mapping
			DGV:RemoveAllWaypoints()
			
			if DGV:ReturnTag("PPOS", guideIndex) then
				if DGV.Modules.MapPreview:IsAnimating() then HideUIPanel(WorldMapFrame) end

				local x, y
				mapID, mapFloor, x, y = DGV:GetPlayerPosition()

				if self:UserSetting(DGV_CARBONITEARROW) and DGV.carboniteloaded and x then
					self.WaypointsShown = false
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x*100, y*100, desc, guideIndex)
				elseif self:UserSetting(DGV_TOMTOMARROW) and DGV.tomtomloaded and x then
					self.WaypointsShown = false
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x*100, y*100, desc, guideIndex)
					DGV:SafeSetMapQuestId(DGV.qid[guideIndex]);
				elseif x then
					self.WaypointsShown = true
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x*100, y*100, desc, guideIndex)
					DGV:SafeSetMapQuestId(DGV.qid[guideIndex]);
				end
				return
			elseif DGV:ReturnTag("POI", guideIndex) and qid and LuaUtils:DugiGetQuestWorldMapAreaID(qid) > 0 then 

				if DGV.Modules.MapPreview:IsAnimating() then HideUIPanel(WorldMapFrame) end
				local m, f = LuaUtils:DugiGetQuestWorldMapAreaID(qid)
				if m then LuaUtils:DugiSetMapByID(m) end --this is needed otherwise QuestPOIGetIconInfo returns nil for POI not in current map.
				local _, posX, posY, objective = QuestPOIGetIconInfo(qid)
	
				if posX then
					DGV:AddCustomWaypoint(posX, posY, desc, m, f, qid)
				end
				return									
			end				
			
			--Get coordinate from current guide step
			local XYVals = DGV:getCoords(guideIndex)
			if not XYVals then return end
			local isCircular = self:ReturnTag("W", guideIndex)~=nil
			if isCircular and #XYVals == 1 then DugisGuideUser.FinalizeWaypoint = nil end

			for i, coord in ipairs(XYVals) do
				local x, y = unpack(coord)	
				if self:UserSetting(DGV_CARBONITEARROW) and DGV.carboniteloaded then
					self.WaypointsShown = false

-- 					local c, z = getCZ(mapID)
-- 					if czLookup[mapID] then
-- 						TomTomUID = TomTom:AddZWaypoint(c, z, x, y, desc)
-- 					else
-- 						TomTomUID = TomTom:AddWaypoint(x, y, desc)
-- 					end
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x, y, desc, guideIndex)
					--TomTom:SetCrazyArrow (carbonite) not working atm, for now coordinates are returned backwards
					--if i == #XYVals then TomTom:SetCrazyArrow(DugisArrow.waypoints[1].tomtom, 5, desc) DugisArrow:Hide() end	
				elseif self:UserSetting(DGV_TOMTOMARROW) and DGV.tomtomloaded then
					self.WaypointsShown = false
-- 					local opts = {}
-- 					opts.title = desc				
-- 					TomTomUID = TomTom:AddMFWaypoint(mapID, mapFloor, x/100, y/100, opts)
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x, y, desc, guideIndex)
-- 					if i == #XYVals then TomTom:SetCrazyArrow(DGV.DugisArrow.waypoints[1].tomtom, 5, desc) DGV.DugisArrow:Hide() end
					DGV:SafeSetMapQuestId(DGV.qid[guideIndex]);	
				else
					self.WaypointsShown = true
					--Guide uses player zone tag and text zone name, text matches zone name 
					--if not self:IsValidDistance( mapID, mapFloor, x, y ) and CurrentTitle:match("|PZ|") and string.find(GetZoneText(), self.CurrentZoneName) then
					if not self:IsValidDistance( mapID, mapFloor, x, y ) and DGV:ReturnGuideTag("PZ") and string.find(GetZoneText(), self.CurrentZoneName) then
						mapID, mapFloor = self:GetPlayerPosition( "player" )
						DebugPrint("Error: No valid distance, changing mapID, mapFloor to current player position")
					end
					--DebugPrint("self.CurrentZoneName="..self.CurrentZoneName.."GetZoneText()="..GetZoneText())
					DGV.DugisArrow:AddWaypoint(mapID, mapFloor, x, y, desc, guideIndex)

					--if i == 1 then DGV.DugisArrow:setArrow( mapID, mapFloor, x, y, desc ) DGV.DugisArrow:Show() end
					DGV:SafeSetMapQuestId(DGV.qid[guideIndex]);
				end			
			end
			
		end
	end
	end

	function DGV:AutoScroll(indx)
		if Main.rightScroll:GetScrollChild() ~= DGVCurrentGuideFrame then return end
		if indx and crowheight then
			local val = (crowheight * indx) - 100
			if val < 0 then val = 0 end
			Main.rightScroll.bar:SetValue(val)
		end	
	end
    
    local lastBoxIndex = -1

	--Large frame checkbox checked by user
	function DugisGuideViewer_CheckButton_OnEvent(self, event,...)
		name = self:GetName()
		local _, _, boxindex = name:find("DGVRow([^ ]*)Chk")
		boxindex = tonumber(boxindex)
		--local chkboxname = "DGVRow"..boxindex.."Chk"

		local oldChk	 =  DGV:GetQuestState(boxindex)
		local clearBox
		
		if event == "RightButton" then clearBox = 1 end
        
        local clickedIndexStart = boxindex
        local clickedIndexEnd = boxindex
        
        if lastBoxIndex ~= -1 and IsShiftKeyDown() then
            clickedIndexStart = lastBoxIndex + 1
        end
        
        lastBoxIndex = boxindex
        
        duringMultiStepsChecking = true
        
        for i = clickedIndexStart, clickedIndexEnd do
            DGV:TriStateChk(i, clearBox)	
            
            local chk	 =  DGV:GetQuestState(i)
            
            --If user is checking box, move to next step
            if visualRows[i].Chk:GetChecked() == true then
                --if not manualmode or chk == "X" then
                if chk == "X" then 
                    DGV:SkipQuest(i)	
                end
                
                --If CQI just got checked (either by user or because it has same QID as another user checked)
                if visualRows[DGU.CurrentQuestIndex].Chk:GetChecked() == true then
                    DGV:MoveToNextQuest()
                elseif (DGV:UserSetting(DGV_MULTISTEPMODE) or DGV:ReturnTag("AYG", DGU.CurrentQuestIndex)) and visualRows[i].Chk:GetChecked() == true then
                    DGV:MoveToNextQuest()
                end
                if i == #visualRows then
                    DGV:LoadNextGuide()
                end	
            --User is unchecking box, move to prev step
            else--if _G[chkboxname]:GetChecked() == 0 then
                DGV:ClrChk(i)
                
                if oldChk == "X" then
                    DGV:UnSkipQuest(i)
                end
                
                local questDesc  = DGV.quests2[i]
                
                local allChoicesText = ""
                
                for match_ in string.gmatch(questDesc, 'ALLCHOICES(.+)END') do 
                    allChoicesText = match_
                end                    
                
                local allChoices = LuaUtils:split(allChoicesText, ':')
                
                LuaUtils:foreach(allChoices, function(choiceId)
                    DGV:MarkStepsByChoiceId(choiceId, false)
                end)
                
                
                --If CQI just got unchecked (either by user or because it has same QID as another user unchecked)
                local nextindex = DGV:FindNextUnchecked()
                if nextindex < DGU.CurrentQuestIndex then
                    DGV:MoveToPrevQuest()
                elseif DGV:UserSetting(DGV_MULTISTEPMODE) or DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) then 
                    DGV:MoveToNextQuest()
                end
            
            end		
        end
        
        duringMultiStepsChecking = false
        
        LuaUtils:RunInThreadIfNeeded("DugisGuideViewer_CheckButton_OnEvent", function(isInThread)
            DGV:ViewFrameUpdate(isInThread)
        end, function()
            DGV:SetPercentComplete()
        end)

	end
    
    function DGV:SetSamallFrameProgressBar(value, text)
        SmallFrameProgressBar:SetValue(100 * value)
        SmallFrameProgressBarText:SetText(text.."%")
    end

	function DGV:LoadNextGuide()
		local nextguide = DGV.nextzones[CurrentTitle]

		if nextguide then 
			DGV:DisplayViewTab(nextguide)
		else -- Clear Guide
			DGV:ClearScreen()
			CurrentTitle = nil
			DugisGuideViewer.CurrentTitle = nil
			DugisGuideUser.CurrentQuestIndex = nil
			CurrentQuestName = nil
			DugisGuideViewer:RemoveAllWaypoints()
		end
				
		if CurrentTitle ~= nil and UnitLevel("player") >= 9 then 
			if self.gtype[CurrentTitle] == "L" then
				DGV:AskGuideSuggest()
			end
		end
	end

	function DGV:TriStateChk(index, clear)
		local stickyFrameChk
		local LargeFramebutton 	= visualRows[index].Chk
		local questState 		= self:GetQuestState(index)
			
		local stickyFrameIndex 	= self.Modules.StickyFrame.revStickyQuests[index]
		
		if stickyFrameIndex then
			stickyFrameChk 	= _G["DGV_SFRow"..stickyFrameIndex.."Chk"]
		end
			
		if clear or questState == "X" then
			self:SetQuestState(index, "U")
			LargeFramebutton:SetCheckedTexture("")
			LargeFramebutton:SetChecked(false)
			if stickyFrameIndex then
				stickyFrameChk:SetCheckedTexture("")
				stickyFrameChk:SetChecked(false)
			end		
		elseif questState == "C" then
			self:SetQuestState(index, "X")
			LargeFramebutton:SetCheckedTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
			LargeFramebutton:SetChecked(true)
			if stickyFrameIndex then
				stickyFrameChk:SetCheckedTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
				stickyFrameChk:SetChecked(true)
			end	
		elseif questState == "U" then
			self:SetQuestState(index, "C")
			LargeFramebutton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			LargeFramebutton:SetChecked(true)
			if stickyFrameIndex then
				stickyFrameChk:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
				stickyFrameChk:SetChecked(true)
			end			
		end
	end

	function DGV:SetChktoX(index)
		self:SetQuestState(index, "X")
		local LargeFramebutton = visualRows[index].Chk
		LargeFramebutton:SetCheckedTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
		LargeFramebutton:SetChecked(true)
	end

	function DGV:ClrChk(index)
		self:SetQuestState(index, "U")
		local LargeFramebutton = visualRows[index].Chk
		LargeFramebutton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		LargeFramebutton:SetChecked(false)
	end

	--User chose to skip the quest and is now changing their mind
	function DGV:UnSkipQuest(qindex)
		local qid = DGV.qid[qindex]
		
		if strmatch(self.actions[qindex], "[ACTNK]") then	
			--Mark all quests with this same qid
			self:UnSkip(qid)
			self:UnSkipPostReqs(qid)	
		else
			DGV:ClrChk(qindex)
		end
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	end

	--User chose to not do this quest
	function DGV:SkipQuest(qindex)
		local qid = DGV.qid[qindex]
		
		--local logindex = DGV:GetQuestLogIndexByQID(DGV.qid[qindex])
		--if logindex then RemoveQuestWatch(logindex)	end	
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		
		if strmatch(self.actions[qindex], "[ACTNK]") then
			self:Skip(qid)
			self:SkipPostReqs(qid)
		else --Other tag type only skip this one, not the chain
			DGV:SetChktoX(qindex)
		end
	end

	function DGV:SetQuestTextNormal(i)
		local Row = GetVisualRow(i)
		Row.Name:SetTextColor(1, 0.82, 0, 1) 
		Row.Desc:SetTextColor(1, 1, 1, 1) 
		Row.Opt:SetText("")
	end
	
	function DGV.IterateRelevantSteps(invariant, control, nextquest, skipped)
		if not control then
			control = DGU.CurrentQuestIndex
			return control
		else
			local qid = DGV.qid[control]
			control = control + 1
			local between = 1
			if not nextquest then nextquest = DGU.CurrentQuestIndex + 1 end
			if not skipped then skipped = 1 end
			
			if control < DGV:GetLastGuideNumRows() then --prevent last row error
				if (qid==DGV.qid[control] and qid==DGV.qid[control - 1] and not DGV:ReturnTag("AYG", control - skipped)) and (strmatch(DGV.actions[control], "[NCK]") and strmatch(DGV.actions[control - 1], "[NCK]")) or 
					DGV:CheckForSkip(control) or 
					DGV:GetQuestState(control) == "C" or 
					DGV:GetQuestState(control) == "X" then

					nextquest = nextquest + 1 
					skipped = skipped + 1
					
					return DGV.IterateRelevantSteps(invariant, control, nextquest, skipped)
				end

				if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and strmatch(DGV.actions[nextquest], "[RATBhU]") and DGV:GetQuestState(nextquest) == "U" then
					if control <= #visualRows and strmatch(DGV.actions[control], "[ATBhUf]") then
						return control					
					end
				end
	
				if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and strmatch(DGV.actions[nextquest], "[RCNK]") and DGV:GetQuestState(nextquest) == "U" then
					if control <= #visualRows and strmatch(DGV.actions[control], "[CNKB]") and not (strmatch(DGV.actions[control - 1], "[ATBhUf]") and DGV:GetQuestState(control) ~= "U") and not DGV:ReturnTag("MD", DGU.CurrentQuestIndex) and not DGV:ReturnTag("MD", control) and not DGV:ReturnTag("AYG", control) then
						return control
					elseif control == nextquest and strmatch(DGV.actions[control], "[RFH]") then
						return control
					end
				end	
							
			
				if strmatch(DGV.actions[DGU.CurrentQuestIndex], "[RFH]") and strmatch(DGV.actions[DGU.CurrentQuestIndex + 1], "[ATBhUf]") and not DGV:ReturnTag("SID", DGU.CurrentQuestIndex) then  
					if control <= #visualRows and strmatch(DGV.actions[control], "[ATBhUf]") then
						return control
					end
				end
	
				if strmatch(DGV.actions[DGU.CurrentQuestIndex], "[RFH]") and strmatch(DGV.actions[DGU.CurrentQuestIndex + 1], "[CNK]") and not DGV:ReturnTag("SID", DGU.CurrentQuestIndex) then  
					if control <= #visualRows and strmatch(DGV.actions[control], "[CNKBU]") and not DGV:ReturnTag("MD", DGU.CurrentQuestIndex) and not DGV:ReturnTag("MD", control) and not DGV:ReturnTag("AYG", control) then
						return control
					elseif control <= #visualRows and DGV:ReturnTag("U", control) and not strmatch(DGV.actions[control], "[RFH]") and not DGV:ReturnTag("MD", DGU.CurrentQuestIndex) and not DGV:ReturnTag("MD", control) then
						return control
					end
				end			
	
				if strmatch(DGV.actions[DGU.CurrentQuestIndex], "[BhUf]") and strmatch(DGV.actions[DGU.CurrentQuestIndex + 1], "[AT]") and not DGV:ReturnTag("SID", DGU.CurrentQuestIndex) then  
					if control <= #visualRows and strmatch(DGV.actions[control], "[ATBhUf]") then
						return control
					end
				end
	
				if strmatch(DGV.actions[DGU.CurrentQuestIndex], "[AT]") or (strmatch(DGV.actions[DGU.NextQuestIndex], "[AT]") and DGV:ReturnTag("AYG", DGU.CurrentQuestIndex)) and not DGV:ReturnTag("SID", DGU.CurrentQuestIndex) then  
					if control <= #visualRows and strmatch(DGV.actions[control], "[ATBhUf]") then
						return control
					end
				end
				
				if strmatch(DGV.actions[DGU.CurrentQuestIndex], "[CNK]") and not DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and not DGV:ReturnTag("SID", DGU.CurrentQuestIndex) then   
					if control <= #visualRows and strmatch(DGV.actions[control], "[CNKB]") and not DGV:ReturnTag("MD", DGU.CurrentQuestIndex) and not DGV:ReturnTag("MD", control) then
						return control
					elseif control <= #visualRows and DGV:ReturnTag("U", control) and not strmatch(DGV.actions[control], "[RFHU]") and not DGV:ReturnTag("MD", DGU.CurrentQuestIndex) and not DGV:ReturnTag("MD", control) then
						return control
					end
				end	
			end			
		end
	end

	function DGV:WatchQuest()
		local logindex
		DGU.removedQuests = {}
		if self:UserSetting(DGV_ENABLEQW) and DGV:isValidGuide(CurrentTitle) == true then
			for logindex = 1, GetNumQuestLogEntries() do
				local qid = DGV:GetQIDByLogIndex(logindex)				
				if DGV.carboniteloaded and qid ~= 0 and Nx.Quest then 
					if Nx.Quest.CurQ then 
						Nx.Quest.Watch:RemoveWatch(qid, logindex)
					end
				else
					RemoveQuestWatch(logindex)
				end 
			end
		end
		
		if (self:UserSetting(DGV_ENABLEQW) or (self:UserSetting(DGV_OBJECTIVECOUNTER) and not self:IsSmallFrameFloating())) and DGV:isValidGuide(CurrentTitle) == true then
			local i = DGU.CurrentQuestIndex
			local action = self.actions[i]
			if i and action and strmatch(action, "[R]") then
				logindex = self:GetQuestLogIndexByQID(self.qid[i])
				i = i + 1
			end
			local skiplogindex = nil
			local onceonly = false
			while i <= #visualRows and action and strmatch(action, "[CTNK]") do
				local qid = tonumber(self.qid[i])
				if self:GetQuestState(i) ~= "X" then
					if DGV.carboniteloaded then
						logindex = self:GetCarboniteQuestLogIndexByQID(qid)	
					else
						logindex = self:GetQuestLogIndexByQID(qid)				
					end
					if logindex and DGV.carboniteloaded and Nx.Quest then
						Nx.Quest.Watch:Add(logindex)
					elseif logindex and DugisGuideUser.shownObjectives[qid] then
						if self:UserSetting(DGV_OBJECTIVECOUNTER) and self:UserSetting(DGV_MULTISTEPMODE) then
							RemoveQuestWatch(logindex)
							DGU.removedQuests[qid] = true
						elseif self:UserSetting(DGV_OBJECTIVECOUNTER) and not self:UserSetting(DGV_MULTISTEPMODE) and (skiplogindex ~= logindex) and not onceonly and not strmatch(self.actions[DGU.CurrentQuestIndex], "[R]") then
							RemoveQuestWatch(logindex)
							skiplogindex = logindex
							onceonly = true
							DGU.removedQuests[qid] = true
						elseif skiplogindex ~= logindex or strmatch(self.actions[DGU.CurrentQuestIndex], "[R]") then
							AddQuestWatch(logindex)
						end
					end
				end			
				i = i + 1
			end
		end
		--[[	
		if self:UserSetting(DGV_ENABLEQW) and DGV:isValidGuide(CurrentTitle) == true then
			if DGV.carboniteloaded and strmatch(self.actions[DGU.CurrentQuestIndex], "[CTNK]") and DGV.qid[DGU.CurrentQuestIndex] and Nx.Quest.Tracking then 
				local cqid = DGV.qid[DGU.CurrentQuestIndex]
				cqid = tonumber(cqid)
				local cqidpart = DGV:ReturnTag("QIDP", DGU.CurrentQuestIndex)
				cqidpart = tonumber(cqidpart)
				if cqid and strmatch(self.actions[DGU.CurrentQuestIndex], "[T]") then
					Nx.Quest.Tracking[cqid] = 1
					Nx.Quest:TrackOnMap(cqid, 0, true, true, true)
				elseif cqid and cqidpart == 1 then 
					Nx.Quest.Tracking[cqid] = 2
					Nx.Quest:TrackOnMap(cqid, 1, true, true, true)
				elseif cqid and cqidpart == 2 then 
					Nx.Quest.Tracking[cqid] = 4
					Nx.Quest:TrackOnMap(cqid, 2, true, true, true)
				elseif cqid and cqidpart == 3 then 
					Nx.Quest.Tracking[cqid] = 8
					Nx.Quest:TrackOnMap(cqid, 3, true, true, true)							
				elseif cqid and cqidpart == 4 then 
					Nx.Quest.Tracking[cqid] = 16
					Nx.Quest:TrackOnMap(cqid, 4, true, true, true)
				elseif cqid then 
					Nx.Quest.Tracking[cqid] = 2
					Nx.Quest:TrackOnMap(cqid, 1, true, true, true)
				end
			end
		end--]]
		
		if (self:UserSetting(DGV_ENABLEQW) or self:UserSetting(DGV_OBJECTIVECOUNTER)) and DGV:isValidGuide(CurrentTitle) == true then
			DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		end
	end	
	
	function DGV:havelootitem(indx)
		local havel
		local lootitem, lootqty 	= DGV:ReturnTag("L", indx)
		if lootitem and (GetItemCount(lootitem) >= lootqty) then havel = true else havel = false end
		return havel
	end
	
	function DGV:havecurrencyitem(indx)
		local havec
		local curitem, curqty 	= DGV:ReturnTag("CUR", indx)
		if curitem and (select(2, GetCurrencyInfo(curitem)) >= curqty) then havec = true else havec = false end
		return havec
	end	

	function DGV:haveuseitem(indx)
		local haveu
		local useitem 				= DGV:ReturnTag("U", indx)
		local uinbag 				= DGV:InBag(useitem)
		if (useitem and uinbag) then haveu = true else haveu = false end 
		return haveu
	end
    
    function DGV:IsQuestInObjectiveTracker(questId)
        if IsWorldQuestWatched(questId) then
            return true
        end
    end    
  
    hooksecurefunc("BonusObjectiveTracker_UntrackWorldQuest", function()
        DugisGuideViewer:MoveToPrevQuest()
    end)   
    
    hooksecurefunc("BonusObjectiveTracker_TrackWorldQuest", function()
        DugisGuideViewer:MoveToPrevQuest()
    end)     

    local function isQuestCompleted(qid)
        if qid then
            local logIndx = DugisGuideViewer:GetQuestLogIndexByQID(qid)
            if logIndx then
                local _, _, _, _, _, qComplete, _, _ = GetQuestLogTitle(logIndx) 
            end
            return qComplete == 1 
        end
    end

	function DGV:CheckForSkip(indx) 
		--local lootitem			 	= DGV:ReturnTag("L", indx)
		local optional 				= DGV:ReturnTag("O", indx)
		local pre, pre2				= DGV:ReturnTag("PRE", indx)
		local rep, standing			= DGV:ReturnTag("REP", indx)
		local friend, level			= DGV:ReturnTag("FS", indx)		
		local useitem 				= DGV:ReturnTag("U", indx)
		local inlog 				= DGV:GetQuestLogIndexByQID(DGV.qid[indx])
		local action				= DGV.actions[indx]
		local toohigh				= DGV:IsQuestTooHigh(indx)
		local hasprof, _			= DGV:ReturnTag("OP", indx)
		local pha					= DGV:ReturnTag("PHA", indx)
		local map1, map2, map3, map4 = DGV:ReturnTag("MAP", indx)
		local tid					= DGV:ReturnTag("TID", indx)
		local questId				= DGV:ReturnTag("QID", indx)
		local WQ					= DGV:ReturnTag("WQ", indx)
		local tidInlog
       
        if questId and LuaUtils:trim(questId) ~= "" and tonumber(questId) ~= nil then
            local isWOrldQuest = QuestUtils_IsQuestWorldQuest(questId)
            if WQ or isWOrldQuest then
            
                if not DGV:IsQuestInObjectiveTracker(questId) or isQuestCompleted(questId) then
                    return true
                end
            end
        end
		
		if tid then tidInlog = DGV:GetQuestLogIndexByQID(tonumber(tid)) end
		
		local haveuse
		haveuse = self:haveuseitem(indx)
		--haveloot = havelootitem(indx)
		local inmap 
		if map1 then 
			if EvaluateMAP(map1) then 
				inmap = true 
			elseif EvaluateMAP(map2) then 
				inmap = true
			elseif EvaluateMAP(map3) then 
				inmap = true
			elseif EvaluateMAP(map4) then 
				inmap = true
			else
				inmap = false
			end
		end
		--|L| + "A" + Optional - skipped if the user does not have the item (and quantity) needed. 
		--|U| + "A" + Optional - skipped if the user does not have the item to use
		
		--[[
		local loginfo
		local qid = DGV.qid[indx]
		if inlog and qid and indx then
			loginfo = "qid:"..qid.."guideindex"..indx.."logindex:"..inlog
		elseif qid and indx then
			loginfo = "qid:"..qid.."guideindex"..indx
		elseif indx then
			loginfo = "guideindex"..indx
		end
		DebugLog(loginfo)
		--]]
		
		--if optional and action == "A" and (haveloot or haveuse)  then
		if optional and action == "A" and haveuse then
			--DebugPrint("Detected use/loot item in bag, display quest")
			return false
		elseif hasprof and not DGV:HasProfession(hasprof) then
			return true
		elseif optional and inmap then 
			return false
		elseif optional and tidInlog then
			return true										
		elseif optional and not inlog then
			--DebugPrint("SKIP: optional and not in log.")
			return true				
		--elseif optional and ((action =="A" and useitem and not haveuse) or (lootitem and not haveloot)) then
		elseif optional and (action =="A" and useitem and not haveuse) then
			--DebugPrint("SKIP: not enough loot or no use item")
			return true
		elseif rep and not EvaluateREP(rep, standing) then
			return true		
		elseif friend and not EvaluateFS(friend, level) then
			return true		
		elseif inlog then
			return false				
		elseif pre and not EvaluatePRE(pre) then
			return true
		elseif pre2 and not EvaluatePRE(pre2) then
			return true			
		elseif pha and not EvaluatePHA(pha) then 
			return true											
		elseif toohigh then
			return true --Create more cons than pros and not really needed
		else
			return false
		end
		
	end

	function DGV:CheckForLocation(indx) 
		--R - Run, F - Fly, b - Boat, H - use hearth
		if not DGV.actions then
		    return 
		end
		local action = DGV.actions[indx]
		local guideIndex
		if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) then
			guideIndex = DGU.NextQuestIndex	
		else
			guideIndex = DGU.CurrentQuestIndex
		end		
		
		if indx == guideIndex and (action == "R" or action == "F" or action == "b" or action == "H") and not DGV.tags[DGU.CurrentQuestIndex]:match("(|REACH|)") then
			local subzonetext = string.trim(GetSubZoneText()) -- returns blank if no subzone
			local zonetext = GetZoneText() 
			local quest = self:RemoveParen(self.quests1L[indx])
			if subzonetext == quest or zonetext == quest then			
				return true
			end
		end
	end

	local function CheckForWaypointLocation(indx)
		if CurrentTitle ~= nil then 
        
			if DGU.CurrentQuestIndex and indx == DGU.CurrentQuestIndex and DGV.tags[DGU.CurrentQuestIndex] then 
            
                local tag = DGV.tags[DGU.CurrentQuestIndex]
            
                -- Case: |REACH|22,22|   
                local coordinates = tag:match("|REACH|[^|0-9]*([0-9]+[^|]*)|")
                
                if coordinates then
                    local x, y, m, f = unpack(LuaUtils:split(coordinates, ","))
                    x, y, m, f = tonumber(x), tonumber(y), tonumber(m), tonumber(f)
                    
                    if not m or not f then
                        local mapID, mapFloor = DGV:ReturnTag("Z", DGU.CurrentQuestIndex)
                        m = m or mapID
                        f = f or mapFloor
                    end
                    
                    if not m or not f then
                        local qid = DGV.qid[DGU.CurrentQuestIndex]
                        local mapID, mapFloor = LuaUtils:DugiGetQuestWorldMapAreaID(qid), GetCurrentMapDungeonLevel()
                        m = m or mapID
                        f = f or mapFloor
                    end
                    
                    if not m or not f then
                        local pmap, pfloor = DGV:GetPlayerPosition()
                        m = m or pmap
                        f = f or pfloor
                    end
                    
                    if DGV.DugisArrow:DidPlayerReachPlace(x, y, m, f) then
                        return true
                    end
                else
                    -- Case: |REACH|
                    if tag:match("(|REACH|)") and DGV.DugisArrow.waypoints and #DGV.DugisArrow.waypoints==1 and 
                    DGV.DugisArrow:getFirstWaypoint()==DGV.DugisArrow:DidPlayerReachWaypoint() then
                        return true
                    end
                end
             
			end
            
		end 
	end

	function DGV:UpdateTravelToLocation()
		local waypointObjective = CheckForWaypointLocation(DGU.CurrentQuestIndex) 
		if waypointObjective then 
			DGV:SetChkToComplete(DGU.CurrentQuestIndex)
			DGV:MoveToNextQuest()
		end
	end
	
	--Check for current hearthstone location
	function DGV:CheckForHearth(indx)
		if indx == DGU.CurrentQuestIndex then
			local action = DGV.actions[indx]
			if action == "h" then
				local quest = DGV.quests1L[indx]
				if GetBindLocation() == quest then			
					return true
				end
			end
		end
	end 

	function DGV:FindNextUnchecked(isInThread)
		local indx = 1
		while indx < #visualRows do
			--self:DebugFormat("FindNextUnchecked", "self:GetQuestState(indx)", self:GetQuestState(indx), "DGV:CheckForSkip(indx)", DGV:CheckForSkip(indx))
			if self:GetQuestState(indx) == "U" and DGV:CheckForSkip(indx) == false then
				break
			end
            
			LuaUtils:RestIfNeeded(isInThread)
            
			indx = indx + 1
		end
		return indx

	end
	
	local function SetUseItem(index)
		DGV:SetUseItem(DGU.CurrentQuestIndex)
	end

	--Move to next quest after CurrentQuest we are on
	--Or specific quest with MoveToIndex

	function DGV:MoveToNextQuest(MoveToIndex, isInThread)
		local checkMoved
		if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and not MoveToIndex then 
			checkMoved = DGU.NextQuestIndex
		else 	
			checkMoved = DGU.CurrentQuestIndex
		end
	
		DGU.CurrentQuestIndex = MoveToIndex or DGU.CurrentQuestIndex
		if not DGU.CurrentQuestIndex then return end
		if DGU.CurrentQuestIndex <= #visualRows then
			local i
			for i = 1, #visualRows do
				visualRows[i]:SetNormalTexture("")
				LuaUtils:RestIfNeeded(isInThread)
			end
			visualRows[DGU.CurrentQuestIndex]:SetNormalTexture("")

			--Phasing out the global CQI
			DGU.CurrentQuestIndex = DGV:FindNextUnchecked()
		
			if DGV:havelootitem(DGU.CurrentQuestIndex) == true or DGV:havecurrencyitem(DGU.CurrentQuestIndex) == true then

				DebugPrint("#####havelootitem(DGU.CurrentQuestIndex) ")
				DGV:SetChkToComplete(DGU.CurrentQuestIndex)
				DGV:MoveToNextQuest(nil, isInThread)    
			end	
			
			if self:ReturnTag("AS", DGU.CurrentQuestIndex) and self:UserSetting(DGV_AUTOSTICK) then
				local row = visualRows[DGU.CurrentQuestIndex]
				self.Modules.StickyFrame:AddRow(row)
				DGV:SetChkToComplete(DGU.CurrentQuestIndex)
				DGV:MoveToNextQuest(nil, isInThread)   

			end
			self.UpdateStickyFrame( )

			if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) then 
				DGV:UpdateCompletionVisuals(true) 
			end			
			
			if (not DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and checkMoved ~= DGU.CurrentQuestIndex) or 
				(DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) and checkMoved ~= DGU.NextQuestIndex) or 
				MoveToIndex then
				if not DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) then
					DGV:UpdateCompletionVisuals(true) 
				end
				DGV:SetQuestColor(DGU.CurrentQuestIndex)
				CurrentAction = DGV.actions[DGU.CurrentQuestIndex] 	
				CurrentQuestName = DGV.quests1L[DGU.CurrentQuestIndex] 
	
				DGV.DoOutOfCombat(SetUseItem, DGU.CurrentQuestIndex)
				DGV:SetTarget(DGU.CurrentQuestIndex)
					
				if DGV:ReturnTag("POI", DGU.CurrentQuestIndex) then 
					DGV:DelayAndMapCurrentObjective(0.5)
				else				
					DGV:DelayAndMapCurrentObjective(0.2) 
					DGV:WatchQuest()
				end
				
				if DGV:IsModelDataOn() then self:ShowModel(DGU.CurrentQuestIndex) end
				
				DGV:SetPercentComplete()
	
				--if not MoveToIndex then
				DGV:PlayCompletionSound(DGV_STEPCOMPLETESOUND)
				--end								
				DGV:CompleteOnZoneCheck()
			end
			visualRows[DGU.CurrentQuestIndex]:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\highlight.tga")
		end
		
		if DGV:ReturnTag("RESET", DGU.CurrentQuestIndex) then 
			DGV:ResetButtonOnClick()
		end			
		
		DugisGuideViewer:SetPercentComplete()
	end

	function DGV:MoveToPrevQuest()
			local checkMoved = DGU.CurrentQuestIndex
            if not checkMoved or not visualRows or not visualRows[checkMoved] then
                return
            end
			visualRows[DGU.CurrentQuestIndex]:SetNormalTexture("")
			
			local nextindex = DGV:FindNextUnchecked()
			DGU.CurrentQuestIndex = nextindex
		
			DGV:SetQuestColor(DGU.CurrentQuestIndex)

			CurrentAction = DGV.actions[DGU.CurrentQuestIndex] 
			CurrentQuestName = DGV.quests1L[DGU.CurrentQuestIndex] 

			if self:ReturnTag("AS", DGU.CurrentQuestIndex) and self:UserSetting(DGV_AUTOSTICK) then
				local row = visualRows[DGU.CurrentQuestIndex]
				self.Modules.StickyFrame:AddRow(row)
				DGV:SetChkToComplete(DGU.CurrentQuestIndex)
				DGV:MoveToNextQuest()   
			end
			self:UpdateStickyFrame( )

			if checkMoved ~= DGU.CurrentQuestIndex then
				DGV:UpdateCompletionVisuals(true)
				DGV.DoOutOfCombat(SetUseItem, DGU.CurrentQuestIndex)
				DGV:SetTarget(DGU.CurrentQuestIndex)
				DGV:DelayAndMapCurrentObjective(0.2)

				if DGV:IsModelDataOn() then self:ShowModel(DGU.CurrentQuestIndex) end
			
				--DGV:UpdateSmallFrame()
				DGV:WatchQuest()
				
				DGV:SetPercentComplete()
				
				DGV:CompleteOnZoneCheck()
			end
			visualRows[DGU.CurrentQuestIndex]:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\highlight.tga")		
	end

	--Uncheck quests and start from beginning of quest progress
	function DGV:ResetAllQuests()
		SuspendViewFrameUpdate()
		for i = 1, #visualRows do
			DGV:ClrChk(i)
		end
		ResumeViewFrameUpdate()
		if not self.preLoadMode then
			CurrentQuestName = DGV.quests1L[1]
			CurrentAction = DGV.actions[1]
			DGU.CurrentQuestIndex = 1
			DGU.NextQuestIndex = 1
			DGV:UpdateSmallFrame()

			DGV.DoOutOfCombat(SetUseItem, DGU.CurrentQuestIndex)
			DGV:SetTarget(DGU.CurrentQuestIndex)
			--QueryQuestsCompleted()
		end
	end
	
	function DGV:WipeOutViewTab()
		local i
		for i =1, #visualRows do
			visualRows[i]:Hide()
		end
		wipe(visualRows)
		DugisPercentButtonName:Hide()	
	end

	--Format: "39(9-14)#39(10-15)#39(11-17)"
	function DGV:GetRawTitle(FormattedTitle)
		if self.rawtitle[FormattedTitle] then
			return self.rawtitle[FormattedTitle]
		else
			return FormattedTitle
		end
	end
	
	local function _GetTitleMapID(title)
		return tonumber(title:match("[%d]*"))
	end


	--Format: Elwynn Forest (1-9 Human)
	--RawTitle, optional GuideDifficulty "Easy" "Normal" or "Hard"
	function DGV:GetFormattedTitle(RawTitle, GuideDifficulty)
		if not RawTitle then return end
		local GuideLevelRange, LocalizedMapName 



		
		local BeforeParen = RawTitle:match("([^%(]*)")
		if BeforeParen then BeforeParen = strtrim(BeforeParen) end
			
		--"(1-9 Human)"
		GuideLevelRange = DGV:GetGuideRange(RawTitle, GuideDifficulty)


		--"Elwynn Forest"

		LocalizedMapName 	= self:GetMapNameFromID(_GetTitleMapID(RawTitle)) or BeforeParen
		
		--"Elwynn Forest (1-9 Human)"
		if GuideLevelRange and LocalizedMapName then
			GuideLevelRange = LocalizedMapName.." "..GuideLevelRange
		end
		
		local ret = GuideLevelRange or RawTitle or "No Title"
		return ret
	end


	--title: 30(1-9 Human) or "478(62-64)" or "27(5-10 Dwarf & Gnome)" or "492(77-80 |cffffd200Lore|r)"

	local function _GetTitleLevels(title)
		local race, race2, levels
		title = title:match("%([^%)]*%)") --"(1-9 Human)" or "(62-64)"
			

		if title then 
			if title:match("%d*-%d*%s.*|r") then --"(77-80 |cffffd200Lore|r)"
				return title 
			else
				race  = title:match("%d%s([%a%s]*)") --"Human"
				if race then race = race:trim() end
				race2 = title:match("&%s([%a%s]*)")  --"Gnome" from "Dwarf & Gnome"
				
				--if title then DebugPrint("title="..title.."#") end
				--if race then DebugPrint("race="..race.."#") end
				--if race2 then DebugPrint("race2="..race2.."#") end
				
				levels = title:match("(%d+-%d+)")   --"1-9"
				if levels and race then  
					race = DGV:localize( race, "RACE")
					
					if race2 then
						race2 = DGV:localize( race2, "RACE")
						race = race.." & "..race2
					end
					title = "("..levels.." "..race..")" --"(1-9 Humano)"
				end	
			end
		end 
			
		return title

	end

	--RawTitle: "30(1-9 Human)#30(1-11 Human)#30(1-12 Human)"
	function DGV:GetGuideRange(RawTitle, GuideDifficulty)
		
		local Hard, Normal, Easy= strsplit("#", RawTitle, 3)

		local level = GuideDifficulty or DGV:UserSetting(DGV_GUIDEDIFFICULTY)
		local GuideRange
		
		--"(1-9 Human)" or "(11-17)"
		if Easy and level == "Easy" then
			GuideRange = _GetTitleLevels(Easy)
		elseif Normal and level == "Normal" then
			GuideRange = _GetTitleLevels(Normal)
		elseif Hard then
			GuideRange = _GetTitleLevels(Hard)
		end
		return GuideRange-- or RawTitle
	end
	
    function SetCurrentGuideIcon()
        if CurrentTitle then
            local guideType = DGV.gtype[CurrentTitle]
            if guideType then
                LuaUtils:foreach(tabs, function(tab)
                    if tab.guidetype == guideType then
                        if tab.icon then
                            if type(tab.icon)=="function" then
                                local textureName = 
                                DugisMainLeftScrollFrame.currentGuideIcon:SetTexture(tab.icon())
                            else
                                DugisMainLeftScrollFrame.currentGuideIcon:SetTexture(tab.icon)
                            end
                        end
                        
                        DugisMainLeftScrollFrame.guideType:SetText(tab.text)
                    end
                end)
            end
        end
    end

	--Called from clicking on a guide title
	function DGV:DisplayViewTab(title, skip, threading)
 		if not title then return end
		if DGV.Modules.StickyFrame.Frame and DGV.Modules.StickyFrame.Frame:IsShown() then 
			DGV:ClearStickyFrame() 
		end
        local rawTitle = string.gsub(title, '|c........', '')
        rawTitle = string.gsub(rawTitle, '|r', '')
        
        if self.guides[rawTitle] and type(self.guides[rawTitle]) ~= "function" and self.guides[rawTitle].OnGuideItemClick then
            self.guides[rawTitle].OnGuideItemClick(self.guides[rawTitle])
            return
        end
    
		if InCombatLockdown() then print("|cff11ff11Dugi Guides: |r|cffcc0000Cannot load guides during combat.|r Please try again."); return end
        
        MainFramePreloader:ShowPreloader()   
        SmallFramePreloader:ShowPreloader()
        
		
		if title ~= CurrentTitle then
			self:ClearStickyFrame()
			DGU.CurrentQuestIndex = 1
			DGU.NextQuestIndex = 1
		end
		
		--Clear existing guide if any and load this guide
		if title == nil or DGV:isValidGuide(title) == false then
			 DGV:ClearScreen()

			CurrentTitle = nil 
			
		else--if title ~= CurrentTitle then
					
			CurrentTitle = title
			self.CurrentTitle = title
            
            DGV:AddGuideToRecentGuides(title)

			self.GuideMapID = _GetTitleMapID(CurrentTitle)
			self.CurrentZoneName = self:GetMapNameFromID(self.GuideMapID) or title:match("(%w*)%s?%(")
			
			DGV:ParseRows(title, false, string.split("\n","\n"..self.guides[title]()))


			if not self.preLoadMode then
				DGV:QuestsBackgroundTranslator()
			end
			
			DGV:PopulateObjectives(title, nil, threading)
			
			--if not self.preLoadMode then
				local name = title..":1"
				if DGU.QuestState[name] == nil then
					DGV:ResetAllQuests()
				else
				--Set state if brand new index appear from due to guide updates
					for i = 1, #visualRows do
						if not DGV:GetQuestState(i) then
							DGV:ResetAllQuests()	
						end
					end						
				end
			--end		
			DGV:SetQuestsState()
			
			if not (self.preLoadMode or skip) then
				DGV:UpdateProfessions()
				DGV:UpdatePlayerLevels()
				DGV:ShowViewTab()
				DGV.DelayandMoveToNextQuest(1, true)
				LuaUtils:Delay(3, function()
					DGV:SetQuestsState() --Need this for OID
				end)		
				
				 LuaUtils:CreateThread("SetAllPercents", function()
					DGV:SetAllPercents(true)
				 end)
				
				visualRows[DGU.CurrentQuestIndex]:SetNormalTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\highlight.tga")
				DGV:AutoScroll(CurrentQuestIndex)
			end
		end
		DGV:UpdateAllSIDs()
        
        SetCurrentGuideIcon()
        
        MainFramePreloader:HidePreloader()
        SmallFramePreloader:HidePreloader()
	end
	
	function Dugis_OnMouseWheel(self, delta)
		local current = self.bar:GetValue()
		local _, Max = self.bar:GetMinMaxValues()
		Max = Max or 1
		if (delta < 0) and (current < Max) then
			self.bar:SetValue(current + 100)
		elseif (delta > 0) and (current > 1) then
			self.bar:SetValue(current - 100)
		end
	end
	
	local function getColor(percent)
	local red, green, blue, alpha
		if percent < 25 then
			red = 1
			green = 0
			blue = 0
			alpha = 1
		elseif percent < 50 then
			red = 1
			green = 0.5
			blue = 0
			alpha = 1
		elseif percent < 75 then
			red = 1
			green = 1
			blue = 0
			alpha = 1
		else
			red = 0
			green = 1
			blue = 0
			alpha = 1
		end
		return red, green, blue, alpha
	end




	-- 
	-- Preload Feature
	--
	local thread
	local preloadFrame = CreateFrame("Frame")
	local preloadCounter = 0
	local preloadThrottle = 0.25
	preloadFrame:SetScript("OnUpdate" , function(self, elapsed)
		preloadCounter = preloadCounter + elapsed
		if preloadCounter >= preloadThrottle and DGV.preLoadMode then
			preloadCounter = preloadCounter - preloadThrottle
			if coroutine.status(thread) ~= "dead" then
				coroutine.resume(thread)
			end
		end

        if NPCJournalFrame and NPCJournalFrame.needToUpdateWaypointButtonsWN then
            UpdateWhatsNewText()
            NPCJournalFrame.needToUpdateWaypointButtonsWN = nil
        end
        
        if whatsNewFrame and whatsNewFrame:IsVisible() and guideategorieswrapper then
            guideategorieswrapper:SetHeight(whatsNewFrame:GetRegions():GetHeight() + 100)
        end  
	end)
    
	local searchThreadFrame = CreateFrame("Frame")
	local searchThreadCounter = 0
	local searchThreadThrottle = 0.01
    
    local function OnSearchThreadEnd()
        DGVSearchFrame:Show()
        
        if not searchDelayTimer then
           DugisSearchProgressIcon:Hide()
        end
        
        DGV_SearchBox:SetAlpha(1)
        SearchingInfoText:Hide()
        DugisMainRightScrollFrame.bar:SetEnabled(true)
    end
    
	searchThreadFrame:SetScript("OnUpdate" , function(self, elapsed)
		searchThreadCounter = searchThreadCounter + elapsed
		if searchThreadCounter >= searchThreadThrottle then
			searchThreadCounter = searchThreadCounter - searchThreadThrottle
            
            if searchThread ~= nil then
                if coroutine.status(searchThread) ~= "dead" then
                    for i=1, 40 do
                        coroutine.resume(searchThread)
                    end
                else
                    OnSearchThreadEnd()
                    searchThread = nil
                end
            end
		end
	end)    
	
	local function GetCreateRowHeading(tabNum, title, originalTabNum, deltaY)
		for _,rh in ipairs(Guides.rowHeadings) do
			if rh.tabNum==tabNum and rh.headingTitle==DGV.headings[title] 
				and (not originalTabNum or originalTabNum==rh.originalTabNum)
				and rh:IsShown()
			then
				return rh
			end
		end
		local label

		for _,rh in ipairs(Guides.rowHeadings) do
			if rh.tabNum==tabNum and not rh:IsShown() then
				label = rh
				break
			end
		end
		if not label then
			label = CreateFrame("Button", "DugisTab"..tabNum.."Heading"..#Guides.rowHeadings, tabs[tabNum].RightFrame, "DugisGuideListingTemplate")
			label.Title:SetFont(GameFontHighlightLarge:GetFont())
			label.Title:SetPoint("RIGHT")
			tinsert(Guides.rowHeadings, label)
		end
		local anchor
		for _,tabLabel in ipairs(Guides.rowHeadings) do
			if tabLabel.tabNum==tabNum and tabLabel:IsShown() then
				anchor = tabLabel

			end
		end
		if not anchor then
			label:SetPoint("TOPLEFT", 0, -5 + (deltaY or 0))
		else
			label:SetPoint("LEFT")
			--label:SetPoint("TOP", anchor, "BOTTOM", 0, -5)
			label.anchor = anchor
		end
		label.tabNum = tabNum
		label.headingTitle = DGV.headings[title]
		label.guideType = tabs[label.tabNum].guidetype
		label.originalTabNum = originalTabNum
		label.Title:SetText(label.headingTitle)
		label:Show()
		return label
	end
    
    DGV.GetCreateRowHeading = GetCreateRowHeading
	
	local function GetCreateTabRow(tabNum, rowNum, title, originalTabNum)
		if tabs[tabNum].visualRows and tabs[tabNum].visualRows[rowNum] then
			local row = tabs[tabNum].visualRows[rowNum]
			row.originalTabNum = originalTabNum
			return row
		end
		local name = "DugisTab"..tabNum.."Row"..rowNum

		local row = _G[name]
		if not row then
			if title then
				row = CreateFrame("Button", name, GetCreateRowHeading(tabNum, title, originalTabNum), "DugisGuideListingTemplate" )
				row:GetParent().lastChild = row
			else
				row = CreateFrame("Button", name, tabs[tabNum].RightFrame, "DugisGuideListingTemplate" )
			end
			row:SetNormalTexture("");
			row.highlight:SetAllPoints()
			row.highlight:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
			if not tabs[tabNum].visualRows then
				tabs[tabNum].visualRows = {}
			end
			tabs[tabNum].visualRows[rowNum] = row
		end
        
        row.oryginalText = title
		row.originalTabNum = originalTabNum
		--row:Show()
		return row
	end
    
    DGV.GetCreateTabRow = GetCreateTabRow

	local function preLoad( )
		local guideNum, tabNum
		local self = DGV
		local currentGuide = CurrentTitle
		local currentGuideType = activeTabInfo.guidetype
		
		--DugisPreloadButton:Disable()

		for tabNum = 1, #tabs do --SIDE_TAB_START, #tabs do 
			local guideType = tabs[tabNum].guidetype
			local guideList = self.guidelist[guideType] -- "L" guide list
			
			if guideType == currentGuideType and guideList then	
				--DebugPrint("guideType="..currentGuideType)
				for guideNum = 1, #guideList do
					
					local guideName = guideList[guideNum]
					local percentText = GetCreateTabRow(tabNum, guideNum).Percent
					--DebugPrint("guideName="..guideName)
					
					--DebugPrint("tab"..tabNum.."row"..guideNum)
					DGV:DisplayViewTab(guideName, nil, true)
                    DGV:SetGuidePercentageCacheValue(guideName, guideType)
					
					LuaUtils:RestIfNeeded(true)
				end
			end
		end
		
		DGV:DisplayViewTab(currentGuide, nil, true)
		
		collectgarbage()
		
		self.preLoadMode = nil
        if guideategorieswrapper then
            guideategorieswrapper:UpdateTreeVisualization()
        end
		
		DebugPrint("####END")
	end

	function DGV:PreloadButtonOnClick()
		self.preLoadMode = true
		thread = coroutine.create(preLoad)
	end

	function DGV:IsPreloadQuestComplete(questLine, guideIndex)

		local qComplete, QuestComplete
		local qid 			= tonumber(questLine:match("|QID|(%d+)")) --self.qid[guideIndex]
		local oid1, oid2, oid3, oid4	= tonumber(questLine:match("|OID|(%d+),?%s?(%d*),?%s?(%d*),?%s?(%d*)|"))
		local ayg			= tonumber(questLine:match("|AYG|(%d+)"))		
		local logIndx 		= self:GetQuestLogIndexByQID(qid)
		local action 		= questLine:match("^(%a)") --self.actions[guideIndex]
		local questState	= self:GetQuestState(guideIndex)
		local questPart 	= questLine:match("|QID|%d+%.(%d+)") --self:ReturnTag("QIDP", guideIndex)
		local needsLoot 	= questLine:match("|L|(%d+)%s?(%d*)|")--self:ReturnTag("L", guideIndex)
		local isDaily		= questLine:match("|D|")--self:ReturnTag("D", guideIndex)
		
		if logIndx then _, _, _, _, _, qComplete, _, _ = GetQuestLogTitle(logIndx) end
		
        	--(needsLoot and self:IsCompleteLootQO("QLU", nil, guideIndex)) or 
        
		if qComplete == 1 
        or self:QuestPartComplete(guideIndex) 
        or (not isDaily and self:HasQuestBeenTurnedIn(qid)) 
        or self:ProfessionCompletedAtGuideIndex(guideIndex) 
        or self:CheckForLocation(guideIndex) 
        or self:AchieveCompleteFromGuideIndex(guideIndex) 
        or self:CheckForHearth(guideIndex) then 
            QuestComplete = true 
        else 
            QuestComplete = nil 
        end
		
		if (action == "A" and logIndx) or (QuestComplete and action ~= "T") or (QuestComplete and action == "T" and not logIndx) or questState == "C" or (oid1 and EvaluateOID(oid1)) or (oid2 and EvaluateOID(oid2)) or (oid3 and EvaluateOID(oid3)) or (oid4 and EvaluateOID(oid4)) or (ayg and EvaluateAYG(ayg)) then--and strmatch(action, "[NFfRBbh]") and not questPart and not needsLoot) then 
			QuestComplete = true
		end

		return QuestComplete
	end

	local percentsSet = false --takes for-ev-er and only needs to be done once
	function DGV:SetAllPercents(threading)
		if percentsSet then return end
		percentsSet = true
		local guidename, text, t, i, guideRow
		local red, green, blue, alpha
		
		
		if DGU["QuestState"] then
			for t = 1, #tabs do 
				local gtype = tabs[t].guidetype
				if gtype and DGV.guidelist[gtype] then
					for i = 1, #DGV.guidelist[gtype] do --Each guide title
                        if threading then
                            LuaUtils:RestIfNeeded(true)
							LuaUtils:WaitForCombatEnd(true)
                        end
						
						guidename 	= 	DGV.guidelist[gtype][i]
						percentText = GetCreateTabRow(t, i).Percent
						if not percentText:GetText() then
							DGV:UpdatePercentText(guidename, percentText, gtype, threading)
						end
						--DebugPrint("guidename="..guidename.."*".."gtype"..gtype)
					end
				end
			end
		end
        LuaUtils:collectgarbage(threading)
            
	end
    
    function DGV:ShouldShowProgess(gtype)
        return gtype ~= "NPC" and gtype ~= "Bosses" and gtype ~= "Followers" and gtype ~= "Mounts" and gtype ~= "Pets" 
    end
    
    function DGV:SetGuidePercentageCacheValue(guideTitle, gtype)
        local guidesize, unchecked, j
        
        guidesize 	= 	DGV:ParseRows(guideTitle, true, string.split("\n","\n"..self.guides[guideTitle]())) - 1		
        unchecked 	=	0
        
        for j=1, guidesize do
            local status = DGV:GetQuestState(j,guideTitle)
            if not status or status == "U" then 
                unchecked = unchecked + 1
            end
        end
        
        if unchecked == 1  then 
            percent = 100 
        else 
            percent = 100 - ((unchecked / guidesize) * 100) 
        end
    
        if not guidePercentagesCache[gtype] then
            guidePercentagesCache[gtype] = {}
        end
        
        guidePercentagesCache[gtype][guideTitle] = percent
        
        return percent
    end
    
	function DGV:GetPercentText(guideTitle, gtype)
        local percentage = nil
        
        if guidePercentagesCache[gtype] and guidePercentagesCache[gtype][guideTitle] then
            percentage = guidePercentagesCache[gtype][guideTitle]
        else
            percentage = DGV:SetGuidePercentageCacheValue(guideTitle, gtype, percentage)
        end
		
		if percentage == 0 or (not DGV:ShouldShowProgess(gtype)) then
			return ""
		else
			text = string.format("%.0f",percentage)
			local r, g, b, alpha = getColor(percentage)
            return "|c"..LuaUtils:normalized2HexColor(r,g,b)..text.."%|r"
		end
	end
    
	function DGV:UpdatePercentText(guideTitle, percentText, gtype, threading)
        
		local guidesize, unchecked, j, percent
		
		guidesize 	= 	DGV:ParseRows(guideTitle, true, string.split("\n","\n"..self.guides[guideTitle]())) - 1		
		unchecked 	=	0
		
		for j=1, guidesize do
			local status = DGV:GetQuestState(j,guideTitle)
			if not status or status == "U" then 
				unchecked = unchecked + 1
			end
		end
		if unchecked == 1  then percent = 100 else percent = 100 - ((unchecked / guidesize) * 100) end
		
		if percent == 0 or (not DGV:ShouldShowProgess(gtype)) then
			percentText:SetText("")
		else
			text = string.format("%.0f",percent)
			percentText:SetText(text.."%")
            
			red, green, blue, alpha = getColor(percent)
			percentText:SetTextColor(red, green, blue, alpha)
		end
	end
	
	local function SetCurrentGuideTabPercentComplete()
		local currentGType = DGV.gtype[CurrentTitle]
		for t = 1, #tabs do 
			local gtype = tabs[t].guidetype
			if gtype==currentGType then
				local guides = gtype and DGV.guidelist[gtype]
				if guides then
					for i = 1, #guides do --Each guide title
						guideTitle = guides[i]
						if guideTitle==CurrentTitle then
                            DGV:SetGuidePercentageCacheValue(guideTitle, gtype)
						end
					end
				end
			end
		end
        
        if guideategorieswrapper then
            guideategorieswrapper:UpdateTreeVisualization()
        end
	end

	function DGV:SetPercentComplete()

		local percent, i
		local unchecked = 0
		local red, green, blue, alpha
		
		if DGV:isValidGuide(CurrentTitle) == true then
			DugisPercentButtonName:Show()
			for i=1, #visualRows do	
				if DGV:GetQuestState(i) == "U" then unchecked = unchecked + 1 end	
			end
			
			if unchecked == 1  then
				percent = 100
			else
				percent = 100 - ((unchecked / #visualRows) * 100)
			end
				

			local text = string.format("%.0f",percent)
			DugisPercentButtonName:SetText(text.."% "..L["Complete"])
            
            DGV:SetSamallFrameProgressBar(percent * 0.01, text)

			
			red, green, blue, alpha = getColor(percent)
			DugisPercentButtonName:SetTextColor(red, green, blue, alpha) 

		else
			DugisPercentButtonName:SetText("")
		end
		SetCurrentGuideTabPercentComplete()
	end
	
	local function AddToChains( tbl, key, val)
		key = tonumber(key) 
		val = tonumber(val)
			
		if not key or not val then return end
		
		if tbl[key] and not tContains(tbl[key], val) then
			tinsert( tbl[key], val )
			--DebugPrint("insert val:"..val)
		else
			tbl[key] = {val}
		end
	end

	local ChainsRaw = ""
	function DGV:RegisterQuestChains(text)
		ChainsRaw = ChainsRaw .. text .."\n"
		--print("registered "..#text.." bytes of chains")
		local postReqs = {}
		local breadCrumbs = {}
		local val, id, pos, start
		local lineCount, dbgCount, lineStart,lineEnd,lineText = 1, 1, 1, 0, 1
		
		while (lineStart and dbgCount < 15000) do
			lineStart, lineEnd, lineText = strfind( ChainsRaw, "%s*(.-)%s*\n", lineEnd + 1 )	
			if lineStart then
				if strfind( lineText, "=") then
					local postReq, preReq = lineText:match( "(%d+)%s*=%s*(%d+)" )
					if strfind ( lineText, "OR" ) then
						AddToChains( breadCrumbs, postReq, preReq)
						for val in string.gmatch(lineText,"OR%s*(%d+)") do
							AddToChains( breadCrumbs, postReq, val)
						end
					elseif postReq and preReq then
						AddToChains( postReqs, preReq, postReq)
						for val in string.gmatch(lineText,"AND%s*(%d+)") do
							AddToChains( postReqs, val, postReq)
						end
					end
				elseif strfind( lineText, ",") then
					local preReq, postReq = lineText:match( "(%d+)%s*,%s*(%d+)" )
					local commaSep = {}
					local mainChain = {}
					
					for val in string.gmatch(lineText,"%,([^%,]*)") do tinsert(commaSep, val) end 		--Create chain data split at ','
					for val in string.gmatch(lineText,"[%,AND]%s*(%d+)") do tinsert(mainChain, val) end --Create main chain of qids
					for _, val in pairs(mainChain) do AddToChains( postReqs, preReq, val ) end
									
					for start = 1, #commaSep do	--Add sub chains
						for pos = start+1, #commaSep do
							if strfind ( commaSep[start], "AND" ) then	 
								for id in string.gmatch( commaSep[start], "(%d+)") do
									if start + 1 <= #commaSep then AddToChains( postReqs, id, commaSep[start+1] ) end
								end
							else
								for id in string.gmatch( commaSep[pos], "(%d+)") do
									AddToChains( postReqs, commaSep[start], id)
								end
							end
						end
					end
				end	
			end

			--if lineText then DebugPrint("lineText="..lineText) end
			lineCount = lineCount + 1
			dbgCount = dbgCount + 1
		end
			
		--DebugPrint("###linecount="..lineCount.."dbgCount="..dbgCount)
		self.postReqs = postReqs
		self.breadCrumbs = breadCrumbs
		
		ChainsRaw = ""
	end

	function DGV:UnSkipPostReqs(qid)
		local postNum, postReq
		base = base or 1
		
		if not self.postReqs[qid] or base > 50 then return end
		
		for _, postReq in pairs(self.postReqs[qid]) do	
			self:UnSkip(postReq)
			self:UnSkipPostReqs( postReq, base + 1 )
		end	
	end


	function DGV:UnSkip(qid)
		local guideIndex

		if DGU.toskip[qid] then DGU.toskip[qid] = nil end
		for guideIndex = 1, #visualRows do
			if (DGV.qid[guideIndex] == qid) and (self:GetQuestState(guideIndex) == "X") and strmatch(self.actions[guideIndex], "[ACTNK]") then 
				DGV:ClrChk(guideIndex)
			end
		end
	end

	function DGV:SkipPostReqs(qid, base)
		local postNum, postReq
		base = base or 1

		
		if not self.postReqs[qid] or base > 50 then return end
		
		for _, postReq in pairs(self.postReqs[qid]) do	
			self:Skip(postReq)
			self:SkipPostReqs( postReq, base + 1 )
		end	
	end

	function DGV:Skip(qid)
		local guideIndex
		
		if DGU.toskip[qid] then DGU.toskip[qid] = true end	
		for guideIndex = 1, #visualRows do
			if (DGV.qid[guideIndex] == qid) and (self:GetQuestState(guideIndex) ~= "C") and strmatch(self.actions[guideIndex], "[ACTNK]") then 
				DGV:SetChktoX(guideIndex)
			end
		end
	end

	function DGV:SkipBreadCrumbs(qid)
		local postNum, postReq

		if self.breadCrumbs[qid] then
			for postNum = 1, #self.breadCrumbs[qid] do
				postReq = self.breadCrumbs[qid][postNum]
				self:Skip(postReq)
			end
		end
	end
	
	function DGV:GetToolTipSize(tooltip)
		if tooltip then
			local textobj = _G[tooltip:GetName().."TextLeft1"]
			
			local ttwidth, ttheight = tooltip:GetSize()
			local fwidth = textobj:GetStringWidth()
			local fheight = textobj:GetStringHeight()
			local pad = tooltip:GetPadding()	
			return ttwidth, ttheight, fwidth, fheight, pad
		end
	end

	function DGV:Tooltip_OnEnter(self, event, ...)
      
			local name = self:GetName()
			local title = _G[self:GetName().."Name"]:GetText()
			local text = _G[self:GetName().."Desc"]:GetText()
			
			CreateFrame( "GameTooltip", "LargeFrameTooltip", nil, "GameTooltipTemplate" ); 
			LargeFrameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			LargeFrameTooltip:SetParent(UIParent)
			local DGV_SmallFrameFontSize = DGV:GetDB(DGV_SMALLFRAMEFONTSIZE)
			local filename, _, _ = LargeFrameTooltipTextLeft1:GetFont()
			LargeFrameTooltipTextLeft1:SetFont(filename, DGV_SmallFrameFontSize)
			
			--LargeFrameTooltip:SetPadding(5)
			LargeFrameTooltip:AddLine("|cffffd200"..(title or "").."|r", 1, 1, 1, true)
			LargeFrameTooltip:AddLine(" ", 1, 1, 1, true)
			LargeFrameTooltip:AddLine(text, 1, 1, 1, true)
			LargeFrameTooltip:Show()
			--[[
			local ttwidth, ttheight, fwidth, fheight, pad = DGV:GetToolTipSize(LargeFrameTooltip)
			
			--DebugPrint("fwidth:"..fwidth.." fheight:"..fheight.." ttwidth"..ttwidth.." ttheight"..ttheight.." pad"..pad)
			
			local scaleFactor = fwidth / ttwidth
			local maxScale = 1.3
			if (scaleFactor > 1) then
				local newwidth
				if scaleFactor > maxScale then
					scaleFactor = maxScale

				end
				
				if(scaleFactor < 1.10) then
					newwidth = fwidth * 1.10
				else 
					newwidth = ttwidth * scaleFactor
				end
				LargeFrameTooltip:SetWidth(newwidth)
				LargeFrameTooltipTextLeft1:SetWidth(newwidth - 15)
				LargeFrameTooltip:SetHeight(LargeFrameTooltipTextLeft1:GetHeight() + 20)

				ttwidth, ttheight, fwidth, fheight, pad = DGV:GetToolTipSize()
				--DebugPrint("2fwidth:"..fwidth.." fheight:"..fheight.." ttwidth"..ttwidth.." ttheight"..ttheight.." pad"..pad)
			end
			--]]
			LargeFrameTooltip:SetFrameStrata("TOOLTIP")
	end

	function DGV:Tooltip_OnLeave()
		if LargeFrameTooltip then LargeFrameTooltip:Hide() end
	end

	local icontbl = {
		[1] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\accept.tga", text = "Accept Quest"},
		[2] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\turnin.tga", text = "Turn in Quest"},
		[3] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\partial_cog.tga", text = "General Task"},
		[4] = {path = "Interface\\Minimap\\TRACKING\\Ammunition", text = "Kill NPC"},
		[5] = {path = "Interface\\Minimap\\TRACKING\\Banker", text = "Collect Item"},
		[6] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\speak.tga", text = "Speak to"},
		[7] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\vehicle.tga", text = "Use Vehicle"},		
		[8] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\flightpath.tga", text = "Get Flight Path"},
		[9] = {path = "Interface\\Minimap\\TRACKING\\Auctioneer", text = "Buy Item"},
		[10] = {path = "Interface\\Minimap\\TRACKING\\None", text = "Use Item"},
		[11] = {path = "Interface\\Minimap\\TRACKING\\Profession", text = "Special Note"},
		[12] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\resting.tga", text = "Set Hearthstone"},
		[13] = {path = "Interface\\Minimap\\TRACKING\\Innkeeper", text = "Use Hearthstone"},
		[14] = {path = "Interface\\Minimap\\TRACKING\\FlightMaster", text = "Fly to"},
		[15] = {path = "Interface\\Minimap\\TRACKING\\StableMaster", text = "Travel to"},
		[16] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\multi_daily.tga", text = "Random Daily"},
		[17] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\dungeon.tga", text = "Use Dungeon Finder"},
		[18] = {path = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\AchievementIcon.tga", text = "Achievement Task"},		
	}

	function DGV:IsQuestTooHigh(guideIndex)
		local reqLevel = self:GetReqQuestLevel(self.qid[guideIndex])
		if reqLevel and reqLevel >  UnitLevel("player") then return true end
	end

	function DGV:IsQuestTooLow(guideIndex)
		if self:GetQuestDiffColor(guideIndex) == QuestDifficultyColors["trivial"] then
			return true

		end
	end

	function DGV:getIcon(objectiveType, i)
		local isDaily, isDungeon, isTooHigh, isKill, isCollect, button, isAlchemy, isBlacksmith, isCooking, isDisenchant, isEnchanting, isEngineering, isFishing, isFirstaid, isHerb, isInscription, isJewel, isLeather, isMining, isSkinning, isSmelting, isTailoring, isMount, isCompanion, isClass, isTabard, isQpart, isSpeak, isVehicle, isMulti, isAchievement, isAchievementpart, isLoot, isUse, isSpeakTitle
		
		local qid = self.qid[i]
		local aid = DGV:ReturnTag("AID", i)
		
		local row = visualRows[i]
		
		if not row then
			return nil
		end
		
		button = row.Button
		isTooHigh = self:IsQuestTooHigh(i)
		if button and not isTooHigh and button.validTexture then
			return button.validTexture
		elseif button and isTooHigh and button.tooHighTexture then
			return button.tooHighTexture
		end
		
		if (DGV.daily[i]) then isDaily = true end
		if (DGV:ReturnTag("I", i)) then isDungeon = true end
		if (DGV:ReturnTag("K", i)) then isKill = true end
		if (DGV:ReturnTag("T", i)) then isCollect = true end
		if (DGV:ReturnTag("AL", i)) then isAlchemy = true end
		if (DGV:ReturnTag("BL", i)) then isBlacksmith = true end
		if (DGV:ReturnTag("CO", i)) then isCooking = true end

		if (DGV:ReturnTag("DI", i)) then isDisenchant = true end
		if (DGV:ReturnTag("ENC", i)) then isEnchanting = true end
		if (DGV:ReturnTag("ENG", i)) then isEngineering = true end
		if (DGV:ReturnTag("FIS", i)) then isFishing = true end
		if (DGV:ReturnTag("FIR", i)) then isFirstaid = true end
		if (DGV:ReturnTag("HE", i)) then isHerb = true end
		if (DGV:ReturnTag("IN", i)) then isInscription = true end	
		if (DGV:ReturnTag("JE", i)) then isJewel = true end
		if (DGV:ReturnTag("LE", i)) then isLeather = true end
		if (DGV:ReturnTag("MI", i)) then isMining = true end
		if (DGV:ReturnTag("SK", i)) then isSkinning = true end
		if (DGV:ReturnTag("SM", i)) then isSmelting = true end
		if (DGV:ReturnTag("TA", i)) then isTailoring = true end
		if (DGV:ReturnTag("MO", i)) then isMount = true end
		if (DGV:ReturnTag("COM", i)) then isCompanion = true end
		if (DGV:ReturnTag("CL", i)) then isClass = true end
		if (DGV:ReturnTag("TAB", i)) then isTabard = true end
		if (DGV:ReturnTag("QIDP", i)) then isQpart = true end
		if (DGV:ReturnTag("S", i)) then isSpeak = true end
		if (DGV:ReturnTag("ST", i)) then isSpeakTitle = true end
		if (DGV:ReturnTag("V", i)) then isVehicle = true end
		if (DGV:ReturnTag("MD", i)) then isMulti = true end
		if (DGV:ReturnTag("AID", i)) then isAchievement = true end
		if (DGV:ReturnTag("AC", i)) then isAchievementpart = true end
		if (DGV:ReturnTag("L", i)) then isLoot = true end
		if (DGV:ReturnTag("U", i)) then isUse = true end
		if (DGV:ReturnTag("SID", i)) then isQpart = true end		
		
		if isTooHigh and objectiveType == "A" then
			button.tooHighTexture = self.ARTWORK_PATH.."accept_g.tga"	
			return button.tooHighTexture		
		elseif isTooHigh and objectiveType == "T" then
			button.tooHighTexture = self.ARTWORK_PATH.."turnin_g.tga"
			return button.tooHighTexture		
		elseif isDaily and objectiveType == "A" then
			button.validTexture = self.ARTWORK_PATH.."accept_d.tga"
			return button.validTexture	
		elseif isDungeon then
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\dungeon.tga" 
			button.validTexture = icontbl[17].path

			return button.validTexture	
		elseif isAlchemy then
			button.validTexture = "Interface\\Icons\\Trade_Alchemy" 
			return button.validTexture
		elseif isBlacksmith then
			button.validTexture = "Interface\\Icons\\Trade_BlackSmithing" 
			return button.validTexture
		elseif isCooking then
			button.validTexture = "Interface\\Icons\\inv_misc_food_15" 
			return button.validTexture
		elseif isDisenchant then
			button.validTexture = "Interface\\Icons\\inv_enchant_disenchant" 
			return button.validTexture
		elseif isEnchanting then
			button.validTexture = "Interface\\Icons\\trade_engraving"
			return button.validTexture
		elseif isEngineering then
			button.validTexture = "Interface\\Icons\\Trade_Engineering"
			return button.validTexture
		elseif isFishing then
			button.validTexture = "Interface\\Icons\\Trade_Fishing"
			return button.validTexture
		elseif isFirstaid then
			button.validTexture = "Interface\\Icons\\Trade_Fishing"
			return button.validTexture
		elseif isHerb then
			button.validTexture = "Interface\\Icons\\Trade_Herbalism" 
			return button.validTexture
		elseif isInscription then
			button.validTexture = "Interface\\Icons\\inv_inscription_tradeskill01" 
			return button.validTexture
		elseif isJewel then
			button.validTexture = "Interface\\Icons\\inv_misc_gem_01" 
			return button.validTexture
		elseif isLeather then
			button.validTexture = "Interface\\Icons\\Trade_LeatherWorking" 
			return button.validTexture		
		elseif isMining then
			button.validTexture = "Interface\\Icons\\Trade_Mining" 
			return button.validTexture
		elseif isSkinning then
			button.validTexture = "Interface\\Icons\\inv_misc_pelt_wolf_01"
			return button.validTexture
		elseif isSmelting then
			button.validTexture = "Interface\\Icons\\spell_fire_flameblades" 
			return button.validTexture		
		elseif isTailoring then
			button.validTexture = "Interface\\Icons\\Trade_Tailoring" 
			return button.validTexture
		elseif isMount then
			button.validTexture = "Interface\\Icons\\Ability_mount_ridingelekk" 
			return button.validTexture
		elseif isCompanion then
			button.validTexture = "Interface\\Icons\\Ability_mount_ridingelekk" 
			return button.validTexture
		elseif isClass then
			button.validTexture = "Interface\\Minimap\\TRACKING\\Class" 
			return button.validTexture
		elseif isTabard then
			button.validTexture = self.ARTWORK_PATH.."tabard.tga" 
			return button.validTexture		
		elseif (objectiveType == "K" ) and (isLoot or isCollect) then
			button.validTexture = self.ARTWORK_PATH.."kill_collect.tga"
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end			

			return button.validTexture		
		elseif isMulti then
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\multi_daily.tga"
			button.validTexture = icontbl[16].path

			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end
			return button.validTexture			
		elseif (objectiveType == "A" ) then 
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\accept.tga"
			button.validTexture = icontbl[1].path
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end
			return button.validTexture
		elseif (objectiveType == "C") then
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end
			if isKill and isCollect then 
				--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\kill_collect.tga"
				button.validTexture = self.ARTWORK_PATH.."kill_collect.tga"
				return button.validTexture
			elseif isKill and isSpeak then
				button.validTexture = self.ARTWORK_PATH.."speak_kill.tga" 
				return button.validTexture		
			elseif isKill and isUse then 
				button.validTexture = self.ARTWORK_PATH.."cog_kill.tga" 
				return button.validTexture
			elseif isKill then 
				--return "Interface\\Minimap\\TRACKING\\Ammunition"
				button.validTexture = icontbl[4].path
				return button.validTexture				
			elseif isCollect then 
				--return "Interface\\Minimap\\TRACKING\\Banker"
				button.validTexture = icontbl[5].path


				return button.validTexture						
			elseif isSpeak then
				button.validTexture = icontbl[6].path
				return button.validTexture				
			else
				--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\partial_cog.tga"
				button.validTexture = icontbl[3].path
				return button.validTexture
			end
		elseif (objectiveType == "T") then
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\turnin.tga"
			button.validTexture = icontbl[2].path
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end
			return button.validTexture
		elseif isVehicle then
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			end				
			if isSpeak then 
				button.validTexture = self.ARTWORK_PATH.."speak_vehicle.tga" 
				return button.validTexture
			else
				button.validTexture = self.ARTWORK_PATH.."vehicle.tga"
				return button.validTexture
			end									
		elseif (objectiveType == "R") then 
			--return "Interface\\Minimap\\TRACKING\\StableMaster"
			if isSpeak then 
				button.validTexture = self.ARTWORK_PATH.."speak_vehicle.tga" 
				return button.validTexture
			else
				button.validTexture = icontbl[15].path 
				return button.validTexture
			end
		elseif (objectiveType == "F" ) then 
			--return "Interface\\Minimap\\TRACKING\\FlightMaster"
			button.validTexture = icontbl[14].path
			return button.validTexture
		elseif (objectiveType == "b" ) then 
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\waves.tga"
			button.validTexture = icontbl[15].path
			return button.validTexture		
		elseif (objectiveType == "H" ) then  
			--return "Interface\\Minimap\\TRACKING\\Innkeeper"
			button.validTexture = icontbl[13].path
			return button.validTexture			
		elseif (objectiveType == "B" ) then 
			--return "Interface\\Minimap\\TRACKING\\Auctioneer"
			button.validTexture = icontbl[9].path
			return button.validTexture			
		elseif (objectiveType == "U" ) then  
			--return "Interface\\Minimap\\TRACKING\\None"
			button.validTexture = icontbl[10].path
			return button.validTexture			
		elseif (objectiveType == "h" ) then 
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\resting.tga"
			button.validTexture = icontbl[12].path
			return button.validTexture
		elseif (objectiveType == "f") then 
			--return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\flightpath.tga"
			button.validTexture = icontbl[8].path
			return button.validTexture				
		elseif isAchievementpart then
			button.validTexture = self.ARTWORK_PATH.."AchievementIcon_p.tga" 
			if aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end
			return button.validTexture	
		elseif isAchievement then
			button.validTexture = icontbl[18].path 
			if aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end			
			return button.validTexture							
		elseif (objectiveType == "N" ) and isQpart then
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			elseif aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end			  
			if isSpeak then 
				button.validTexture = self.ARTWORK_PATH.."speak.tga" 
				return button.validTexture
			elseif isCollect and isKill then
				button.validTexture = self.ARTWORK_PATH.."kill_collect.tga"
				return button.validTexture
			elseif isCollect then
				button.validTexture = icontbl[5].path
				return button.validTexture				
			elseif isKill and isUse then
				button.validTexture = self.ARTWORK_PATH.."cog_kill.tga" 
				return button.validTexture
			elseif isKill then
				button.validTexture = icontbl[4].path 
				return button.validTexture							
			else
				button.validTexture = icontbl[3].path
				return button.validTexture
			end						
		elseif isLoot then
			button.validTexture = icontbl[5].path
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			elseif aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end				
			return button.validTexture		
		elseif (objectiveType == "N" ) then  
			button.validTexture = icontbl[11].path
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			elseif aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end
			if isSpeakTitle then 
				button.validTexture = self.ARTWORK_PATH.."speak.tga" 
				return button.validTexture
			end				
			return button.validTexture		
		else-- (objectiveType == "K" ) then  
			--return "Interface\\Minimap\\TRACKING\\Ammunition"
			button.validTexture = icontbl[4].path
			if qid then 
				button.tag_id = qid
				button.tagType = "qid"
			elseif aid then 
				button.tag_id = aid
				button.tagType = "aid"
			end				
			return button.validTexture		
		end		
	end


	function DGV:HasCoord(guideIndex)
		local coord = "%(([%d.]+),%s?([%d.]+)%)"
		local note = DGV.quests2[guideIndex]
		if note:find(coord) or DGV:ReturnTag("PPOS", guideIndex) then 
			return true 
		end
	end

	--Return a table of current coordinates from the Note tag
	function DGV:getCoords(guideIndex)

		local XYVals = {}
		local coord = "%(([%d.]+),%s?([%d.]+)%)"
		local note = DGV.quests2[guideIndex]
		local x, y
		
		if note and note:find(coord) then
			for x,y in note:gmatch(coord) do
				--if self:UserSetting(DGV_CARBONITEARROW) then --hax: return backwards
				--	table.insert(XYVals, 1, {tonumber(x), tonumber(y)})
				--else
					table.insert(XYVals, {tonumber(x), tonumber(y)})
				--end
			end
		end
		return XYVals
	end

	local xyzon
	function DGV:Retxyz(t, i)
			if i == 1 and t == "AAA" then
				xyzon = true
				t = ""
			elseif i == 1 then
				xyzon = false
			end
			
			if xyzon then
				local textd = ""
				local chard
				local data = 0
				for j = 1, #t do
					local c = t:sub(j,j)
					local cb = string.byte(c, 1)
					local k = 3
					chard = ""
					if cb < 128 - k then 
						chard = string.char(cb + k) 
					elseif cb < 192  then 
						local joined = bit.bor(bit.band(63, cb), data) 	
						joined = joined + k
						local upper2 = bit.bor(bit.rshift(bit.band(192,joined), 6), 192) 
						local lower2 = bit.bor(bit.band(63, joined), 128) 
						chard = string.char(upper2)..string.char(lower2)
					elseif cb < 224  and cb > 193  			then 
						data = bit.lshift(bit.band(3, cb),6)
					else
						DebugPrint("Range Err")
					end	
					textd = textd..chard
				end
				t = textd
				--DebugPrint("t="..t)
			end
		return t
	end
    
    
	function DGV:TranslateText(line)
		----- SubZones ----
		local line = string.gsub(line, '{.-}', function(subzone) 
        
			subzone = string.gsub(subzone, '{', '')
			subzone = string.gsub(subzone, '}', '')
			subzone = subzone
			
			if DugisGuideViewer.Localize == 0 then return subzone end
            
            if (DGV.BZL == nil) then
                return subzone
            end
            

			local translatedSubzone = DGV.BZL[subzone]
			if translatedSubzone then
				return translatedSubzone
			else
				return subzone
			end
		end) 
        
		return line
        
	end

	--Parse rows and fill up 3 items: Objective type (actions), Quest name, Note Tag (actions, quests, tags)
	function DGV:ParseRows(guidetitle, infoOnly, rowinfo,...)

		local i
		local indx = 1
		local _, myClass 	= UnitClass("player")
		local _, myRace 	= UnitRace("player")
		local myFaction		= UnitFactionGroup("player")
		local myGender
		if UnitSex("player") == 3 then myGender = "Female" else myGender = "Male" end 
		if myClass == "DEMONHUNTER" then myClass = "DEMON" end
		--Clear old data from tables
		
		--[[
		local key, value
		for key, value in pairs(DGV.actions) do
			DGV.actions[key] = nil
			DGV.quests1[key] = nil
			DGV.quests1L[key] = nil
			DGV.quests2[key] = nil
		end
		--]]
		--[[DGV.actions = {}
		DGV.quests1 = {}
		DGV.quests1L = {}
		DGV.quests2 = {}]]
        if not infoOnly then
            wipe(DGV.actions)
            wipe(DGV.quests1)
            wipe(DGV.quests1L)
            wipe(DGV.quests2)
        end
		
		--Loop through all rows
		for i = 1, select ("#", ...) do
			local text = select(i, ...)
            
			text = self:TranslateText(text)

			text = self:Retxyz(text, i)
			--if i < 5 then DebugPrint("text="..text) end
			local _, _, classes 	= text:find("|C|([^|]+)|")
			if classes then classes = string.upper(classes) end
			local _, _, races 		= text:find("|R|([^|]+)|")             	
			local _, _, daily 		= text:find("(|D|)")
			local _, _, gender 		= text:find("|G|([^|]+)|")
			local _, _, faction		= text:find("|FAC|([^|]+)|")
			
				if text ~= "" and (not classes or classes:find(myClass)) and (not races or races:find(myRace)) and (not gender or myGender == gender) and (not faction or myFaction == faction) then
					
					local _, _, action, quest, tag = text:find("^(%a) ([^|]*)(.*)") 
					
					if action and quest then 
						action = action:trim()
						quest = quest:trim()
						--Find Use items
						local _, _, useitem = tag:find("|U|([^|]+)|") 
                        
                        if not infoOnly then
                            DGV.useitem[indx] = useitem
                        end

						--If there is a second objective line, retrieve that
						local quest2, questtest
						questtest = tag
						local _, _, questtest = questtest:find("|[NW]R?|([^|]+)|")
						if questtest then
						quest2 = questtest
						else
						quest2 = ""
						end


						local qid = tag:match("|QID|(%d+)")
						qid = tonumber(qid)
                        
                        local sid = tag:match("|SID|(%d+)")
						sid = tonumber(sid)
						
                        if not infoOnly then
                            DGV.actions[indx] = action:trim()
                            DGV.quests1[indx] = quest:trim()
                            DGV.quests1L[indx] = quest:trim()
                            DGV.quests2[indx] = quest2:trim()
                            DGV.tags[indx] = tag
                            DGV.qid[indx] = qid
                            DGV.sid[indx] = sid
                            DGV.daily[indx] = daily
                        end
						indx = indx + 1
					end
			end
		end
        
        return indx
	end
	
	function DGV:InBag(itemid)
		local bag, slot
		if itemid then
			for bag=0,4 do
				for slot=1,GetContainerNumSlots(bag) do
					local item = GetContainerItemLink(bag, slot)
					if item and string.find(item, "item:"..itemid) then return true end
				end
			end
		end
		return false
	end
    
    local function ReplaceCoordinates(qDesc)
        return string.gsub(qDesc, "%(([%d.]+),%s?([%d.]+)%)%s-", "")
    end
    
    function DGV:RefreshReplacedTags()
        if not DGV.actions then
            return
        end
        
        for i = 1 , #DGV.actions do 
            local dgvRowName = "DGVRow"..i
            local rowObj 	= _G[dgvRowName]
            if rowObj ~= nil then
                local qDesc = DGV.quests2[i]
                if DGV.NPCJournalFrame then 
                    qDesc = NPCJournalFrame:ReplaceSpecialTags(qDesc, true, i)
                end
                DGV.quests2[i] = qDesc
                
                if qDesc and not DugisGuideViewer:GetDB(DGV_DISPLAYCOORDINATES) then
                    qDesc = ReplaceCoordinates(qDesc)
                end
                
                rowObj.Desc:SetText(qDesc)
            end
        end
    end

	--Fill screen with 3 items: Objective type (actions), Quest name, Note Tag (actions, quests, tags)
	function DGV:PopulateObjectives(title, SearchMode, threading)
		--DGV:DebugFormat("PopulateObjectives", "stack", debugstack())
			if not title then title = CurrentTitle end
			crowheight = 35
			local i
			local rowObj
			
			SuspendViewFrameUpdate()

		
			--Clear any old data
			for i =1, #visualRows do
				rowObj = visualRows[i]
				rowObj:Hide()
				rowObj:SetNormalTexture("")
				rowObj.Name:SetText("")
				rowObj.Desc:SetText("")
				--DGV:SetQuestTextNormal(i)
			end
			wipe(visualRows)	
			
			self:SetViewTabTitle(self:GetFormattedTitle(title))
					
                    
            local searchResultIndex = 0
            local calculatedHeight = 0
                    
			for i = 1 , #DGV.actions do 
                LuaUtils:RestIfNeeded(threading)
				
				local dgvRowName = "DGVRow"..i
				rowObj 	= _G[dgvRowName]
				if rowObj == nil then
					rowObj = CreateFrame("Button", dgvRowName, currentGuideTabInfo.RightFrame, "DugisQuestRowTemplate")
				end
				rowObj:Show()
				rowObj:ClearAllPoints()
				visualRows[i] = rowObj
				DGV:SetQuestTextNormal(i)
				
				local qDesc = DGV.quests2[i]
				if DGV.NPCJournalFrame and NPCJournalFrame then 
					qDesc = NPCJournalFrame:ReplaceSpecialTags(qDesc, true, i)
				end
				DGV.quests2[i] = qDesc
				
				if qDesc and not DugisGuideViewer:GetDB(DGV_DISPLAYCOORDINATES) then
					qDesc = ReplaceCoordinates(qDesc)
				end
				
				-- set optimization fields
				rowObj.Button.validTexture = nil
				rowObj.Button.tooHighTexture = nil
				rowObj.Name.levelText = nil
				rowObj.Desc:SetText(qDesc)
				
				rowObj.Opt.text = nil
				rowObj.Opt.pre = nil
				rowObj.Opt.rep = nil
				rowObj.Opt.standing = nil
				rowObj.Opt.friend = nil
				rowObj.Opt.level = nil				
				rowObj.Opt.optional = nil
				--visualRows[i] = rowObj
				
				if not SearchMode then 
                    local currentY = -(i - 1) * 35
                    calculatedHeight = -currentY
                    
                    --This was a very bad idea to make the position to be relativily to the previous node. That way in case big amount of nodes it required a lot of calculations.
                    --rowObj:SetPoint("TOP", visualRows[i-1], "BOTTOM", 5, rowspacing )  
                    
                    --Better idea is to calculate right position for each node relatively to the parent. Like this:
                    rowObj:SetPoint("TOPLEFT", 0, currentY)  
				else
					if self.Search:InSearchResults( i ) then
                        searchResultIndex = searchResultIndex + 1
                        
                        local currentY = -(searchResultIndex - 1) * 35
                        calculatedHeight = -currentY
                        
						rowObj:SetPoint("TOPLEFT", 0, currentY)
					else
						rowObj:Hide()
					end
				end
				
				rowObj.Chk:SetChecked(false)
				rowObj.Chk:Show()
				rowObj.Chk:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				rowObj.Button:SetNormalTexture(DGV:getIcon(DGV.actions[i], i ))	
				
				
				if not self:HasCoord(i) then rowObj.WayPoint:Disable() else rowObj.WayPoint:Enable() end
				if self:ReturnTag("NT", i) then rowObj.Chk:Disable() else rowObj.Chk:Enable() end
			end

			local fwidth = DGV:GetFontWidth(L["Reload"])

			DugisReloadButton:SetText(L["Reload"]) 
			DugisReloadButton:SetWidth(fwidth + 20)
			
			fwidth = DGV:GetFontWidth(L["Reset"])
			DugisResetButton:SetText(L["Reset"])
			DugisResetButton:SetWidth(fwidth + 20)
			
            calculatedHeight = calculatedHeight - 280
           
			if calculatedHeight <=1 then 
                calculatedHeight = 500
            end
           
            DugisMain.rightScroll.bar:SetMinMaxValues(1, calculatedHeight)
            DugisMain.rightScroll.bar:SetValue(0)

            LuaUtils:Delay(1, function()
                DugisMain.rightScroll.bar:SetMinMaxValues(1, calculatedHeight)
                DugisMain.rightScroll.bar:SetValue(0)
            end)
            
	end
    
    function DGV:UpdateStepNumbersPosition(Row, i)
        Row.StepNumber:SetText(i)
        Row.StepNumber:ClearAllPoints()
    
        if DugisGuideUser.showLeftMenuForCurrentGuide then
            Row.StepNumber:SetPoint("TOPRIGHT", -410, -6)
        else
            Row.StepNumber:SetPoint("TOPRIGHT", -38, -6)
        end    
    end
    
    function DGV:UpdateStepNumbersPositions()
		for i, qid in ipairs(DGV.actions) do
            local row = visualRows[i]
            if row and row.StepNumber then
                DGV:UpdateStepNumbersPosition(row, i)
            end
		end
    end

	function DGV:SetQuestText( i ) 
		
		local qName 	= DGV.quests1L[i]
		if DGV.NPCJournalFrame and NPCJournalFrame then		
			qName = NPCJournalFrame:ReplaceSpecialTags(qName, true, i, true)
		end
		DGV.quests1L[i] = qName
		local level 	= DGV:GetQuestLevel(self.qid[i])
		local questpart = self:ReturnTag("QIDP", i)
		
		local Row = GetVisualRow(i)
		
		if not Row then
			return
		end
		
		if (level and level > 0 and strmatch(self.actions[i], "[ACT]") and self:UserSetting(DGV_QUESTLEVELON)) or (level and level > 0 and questpart and strmatch(self.actions[i], "[NK]") and self:UserSetting(DGV_QUESTLEVELON)) then
			if not Row.Name.levelText and DGV.Localize == 0  then
				Row.Name.levelText = string.format("[%d] %s", level, qName)
			end
			qName = Row.Name.levelText
		end
		
		if Row.Name:GetText()~=qName then --optimization
			local width = self:GetFontWidth(qName)	
			Row.Name:SetWidth(width + 10)	
			Row.Name:SetText(qName)
		end
        
        DGV:UpdateStepNumbersPosition(Row, i)
        
		if DGV:CheckForSkip(i) then CheckInitOpt(i) end
		Row.Opt:SetText(Row.Opt.text)
		
		if (Row.Opt.optional or
			Row.Opt.prof or 
			(Row.Opt.pre and not EvaluatePRE(Row.Opt.pre)) or 
			(Row.Opt.pre2 and not EvaluatePRE(Row.Opt.pre2)) or 			
			(Row.Opt.pha and not EvaluatePHA(Row.Opt.pha)) or 			
			(Row.Opt.rep and not EvaluateREP(Row.Opt.rep, Row.Opt.standing))) or 
			(Row.Opt.friend and not EvaluateFS(Row.Opt.friend, Row.Opt.level)) then
			Row.Opt:Show()
		else
			Row.Opt:Hide()	
		end
	end

	-- 
	-- Tab Functions
	--

	-- function DGV:SaveLastScrollBar(lasttab)
		-- SliderVal[lasttab] = Dugis_VSlider:GetValue()
	-- end

	-- function DGV:RestoreScrollBar(currenttab)
		-- DGV:DebugFormat("RestoreScrollBar", "currenttab", currenttab, "SliderVal[currenttab]", SliderVal[currenttab], "SliderMax[currenttab]", SliderMax[currenttab])
		-- Dugis_VSlider:SetValue(SliderVal[currenttab])
		-- Dugis_VSlider:SetMinMaxValues(1, SliderMax[currenttab])
	-- end

	function DGV:ShowViewTab()
		if DGV:isValidGuide(CurrentTitle) == true  then 
			Main.currentGuideTab:GetScript("OnClick")(Main.currentGuideTab)
		else
			Main.currentGuideTab:GetScript("OnClick")(Main.homeTab)
		end
	end

	function DGV:SetViewTabTitle(title)
		Main.title:SetText(title)
	end

	--Update the guide level range on guide listings when difficulty is changed
	function DGV:TabTextRefresh()
		local i, GuideRow
		DGV:SetViewTabTitle(self:GetFormattedTitle(CurrentTitle))
		
		for i = 1, #tabs do
			local TabInfo	= tabs[i]

			local gtype = TabInfo.guidetype
			if gtype then
				if DGV.guidelist[gtype] then
					for j =1 , #DGV.guidelist[gtype] do  				
						GuideRow = _G["DugisTab"..i.."Row"..j]
                        
                        if GuideRow then
                            GuideRow.Title:SetText(self:GetFormattedTitle(DGV.guidelist[gtype][j]))
                        end
					end
				else
					GuideRow = _G["DugisTab"..i.."Row"..1]
					if GuideRow and GuideRow.Title then GuideRow.Title:SetText(L["No Guide Loaded"]) end
				end
			end
		end
	end
	
	Guides.rowHeadings = {}
	if not DGU.subCategoriesExpanded then
		DGU.subCategoriesExpanded = {}
	end
    
    function DGV:GetFlatternRecentGuides()
        local result = {}
        for headingIndex, heading in pairs(DugisGuideUser.RecentGuides.Categories) do
            for _,guide in ipairs(DugisGuideUser.RecentGuides.Guides[heading]) do
                result[#result + 1] = guide
            end
        end
        return result
    end    
    
    local function ExistsInRecentGuides(rawTitle)
        for _,guide in ipairs(DGV:GetFlatternRecentGuides()) do
            if guide == rawTitle then
                return true
            end
        end
        return false
    end

    local function Guide2CategoryName(guide)
        for _,tabInfo in ipairs(tabs) do
            local guideType = DGV.gtype[guide]
			if tabInfo.guidetype and guideType ==  tabInfo.guidetype then
                return tabInfo.title
			end
		end
        return L["Others"]
    end
    
    local function InTable(tbl, item)
        for key, value in pairs(tbl) do
            if value == item then return key end
        end
        return false
    end
    
    function DGV:AddGuideToRecentGuides(rawGuideTitle)
        local categoryName = Guide2CategoryName(rawGuideTitle) 
            
        if not ExistsInRecentGuides(rawGuideTitle) then
            if DugisGuideUser.RecentGuides.LastIndices[categoryName] == nil then
                DugisGuideUser.RecentGuides.LastIndices[categoryName] = 1
                DugisGuideUser.RecentGuides.Guides[categoryName] = {}
            else
                DugisGuideUser.RecentGuides.LastIndices[categoryName] = DugisGuideUser.RecentGuides.LastIndices[categoryName] + 1
            end

            if DugisGuideUser.RecentGuides.LastIndices[categoryName] > 5 then
                DugisGuideUser.RecentGuides.LastIndices[categoryName] = 1
            end
            
            local lastIndex = DugisGuideUser.RecentGuides.LastIndices[categoryName]
          
            if DugisGuideUser.RecentGuides.Guides[categoryName] == nil then
                DugisGuideUser.RecentGuides.Guides[categoryName] = {}
            end
            
            DugisGuideUser.RecentGuides.Guides[categoryName][lastIndex] = rawGuideTitle
            if  not InTable(DugisGuideUser.RecentGuides.Categories, categoryName) then
                DugisGuideUser.RecentGuides.Categories[#DugisGuideUser.RecentGuides.Categories + 1] = categoryName
            end
        end
    end
	
	--Load a guide from a tab
	function DugisGuideViewer_TabRow_OnEvent(self, event, ...)
        local rawTitle = self:GetParent().nodeData.data.rawTitle
        DGV:AddGuideToRecentGuides(rawTitle)
        
        local clickedType = DugisGuideViewer.gtype[rawTitle]
        local metaData = DugisGuideViewer.guidemetadata[rawTitle]
        
        if clickedType == "Followers" or clickedType == "Pets" or clickedType == "Mounts" or clickedType == "Bosses" or clickedType == "NPC" then
            NPCJournalFrame:OnGuideRowClick("", metaData.objectId, clickedType)
            return
        end
        
        DGV:DisplayViewTab(rawTitle)
        print("|cff11ff11Dugi Guides: |r"..DGV:GetFormattedTitle(rawTitle).."|cff11ff11 selected.|r")
        
        DGV:AddGuideToRecentGuides(rawTitle)
	end	
	
	local _G = _G
    
    local tabRowsListCache = {}
    --TODO check if there is a need of cache lifetime/cache expiration
    local function GetCachedTabRows(tabNum)
        if tabRowsListCache[tabNum] and tabNum ~= RECENT_TAB and tabNum ~= SUGGEST_TAB  and tabNum ~= SEARCH_TAB then
            return tabRowsListCache[tabNum]
        end
        local index = 1
        local key = format("DugisTab%dRow%d", tabNum, index)
        local result = {}
        local currentValue = _G[key]
        while currentValue do
            result[#result + 1] = currentValue
            index = index + 1
            key = format("DugisTab%dRow%d", tabNum, index)
            currentValue = _G[key]
        end
        
        tabRowsListCache[tabNum] = result
        return result
    end
	
	local function VerifyRank(rank, minimum, maximum)
		if minimum and rank<minimum then return end
		if maximum and rank>=maximum then return end
		return true
	end
	
	function DGV.SuggestProfessionGuidePredicate(englishProfArg1, minRank1, maxRank1, englishProfArg2, minRank2, maxRank2)
		local profIndex1, profIndex2 = GetProfessions()
		local localProf1, rank1
		if profIndex1 then localProf1, _, rank1 = GetProfessionInfo(profIndex1) end
		local localProf2, rank2
		if profIndex2 then localProf2, _, rank2 = GetProfessionInfo(profIndex2) end
		local localProfArg1 = L[englishProfArg1]
		local matchArg1 = (localProfArg1==localProf1 and VerifyRank(rank1, minRank1, maxRank1)) or (localProfArg1==localProf2 and VerifyRank(rank2, minRank1, maxRank1))
		if matchArg1 and not englishProfArg2 then return true end
		if englishProfArg2 then
			local localProfArg2 = L[englishProfArg2]
			local matchArg2 = (localProfArg2==localProf1 and VerifyRank(rank1, minRank2, maxRank2)) or (localProfArg2==localProf2 and VerifyRank(rank2, minRank2, maxRank2))
			return matchArg1 and matchArg2
		end
	end
	
	function DGV.SuggestCurrentHolidayPredicate(guideTextureBase)
		for index, _, _, textureBase in IterateCurrentHolidays do
			if textureBase==guideTextureBase then return true end
		end
	end
	
	function DGV.SuggestReputationAchievementPredicate(reputation)
		local _, _, standingId = GetFactionInfoByID(reputation)
		if standingId<8 then return true end
	end
	
	function DGV.SuggestQuestAchievementPredicate(qid)
		local isCompleted = IsQuestFlaggedCompleted(qid) 
		if isCompleted then return true end
	end	
	
	
	local function IterateSuggestedGuides(invariant, key)
	
		local gtype = invariant[1]
		local threading = invariant[2]
		
		if gtype=="I" or gtype=="L" then
			for guideInRange,minimum in IterateGuidesInRange,nil,key do
				if DGV.gtype[guideInRange] == gtype then
					return guideInRange
				end
			end
		else
			while true do
				LuaUtils:RestIfNeeded(threading)
				key = next(DGV.guides, key)
				if not key then 
					return 
				end
				if DGV.gtype[key] == gtype then
					if DGV:ReturnGuideTag("SG", key) then
						return key
					end
				end
			end
		end
	end
        
    local playerRace,  engPlayerRace  = UnitRace("player") 
    local yofs = -5
    local rowheight = 14
    local rowCount = 0
    local lastHeading
    local function GetGuides(guideType, category)
        local result = {}
        local currentZone = DGV:GetCurrentMapID() 

        if DGV.guidelist[guideType] ~= nil then
            for _,guide in ipairs(DGV.guidelist[guideType]) do
                
                local zone = tonumber(guide:match("^(%d+)"))
                if not zone then
					zone = guide:match("^(.-)%s?%(")
					if zone then 
	                    zone = tonumber(DGV:GetMapIDFromName(zone))
					end 
                end            
            
                if zone == currentZone   then
                     result[#result + 1] = guide
                end
            end
        end
        
        return result
    end
    
    function GetPercentageTextByNodeData(nodeData)
         return DGV:GetPercentText(nodeData.data.rawTitle, nodeData.data.guideType)
    end
    
    local guideType2Node = {}
    local headerL1Title2Node = {}
    local headerL2Title2Node = {}
    local headerL3Title2Node = {}
    tabs[SUGGEST_TAB].treeData = {}  

    function BeginAddingGuidesToTreeData(treeDataParent)
        treeDataParent.treeData = {}
        guideType2Node = {}
        headerL1Title2Node = {}
        headerL2Title2Node = {}
        headerL3Title2Node = {}
    end    
    
    local guideType2GuideTitle = {}
    
    LuaUtils:foreach(tabs, function(tab)
        if tab.guidetype then
            guideType2GuideTitle[tab.guidetype] = tab.title
        end
    end)
    
    local guideType2Icon = {}
    
    LuaUtils:foreach(tabs, function(tab)
        if tab.guidetype then
            guideType2Icon[tab.guidetype] = tab.icon
        end
    end)
    
    function AddGuideToTreeData(treeData, guideTitle, guideType, guideTypeAsTopCategory)
        local currentHeadingL1 = DGV.headings[guideTitle]
        local currentHeadingL2 = DGV.hedingsL2[guideTitle]
        local currentHeadingL3 = DGV.hedingsL3[guideTitle]
        local currentGuideType = guideType
        local currentNode
        
        if guideTypeAsTopCategory then
            currentNode = guideType2Node[guideType]
        else
            currentNode = headerL1Title2Node[currentHeadingL1]
        end 
        
        --New node
        --Categories Level 0
        if not currentNode and guideTypeAsTopCategory then
            local key = currentGuideType
            currentNode = {name=guideType2GuideTitle[currentGuideType], textColor={r=1, g=1, b=1}, expandedByDefault=true, disabledMouse=true, nodes={}, data={}}
            
            if guideType2Icon[currentGuideType] then
                currentNode.icon=guideType2Icon[currentGuideType]
                if type(currentNode.icon) == "function" then
                    currentNode.icon = currentNode.icon()
                end
                
                currentNode.iconSize = 20
                currentNode.iconDY = 1                
                currentNode.iconDX = -3                
           end
            
            guideType2Node[key] = currentNode
            treeData[#treeData + 1] = currentNode
        end
        
        --New node
        --Categories Level 1
        if not guideTypeAsTopCategory then
            if not currentNode then
                local key = currentHeadingL1
                currentNode = {name=currentHeadingL1, nodes={}, data={}}
                headerL1Title2Node[key] = currentNode
                treeData[#treeData + 1] = currentNode
            end
        else
            local key = currentGuideType..currentHeadingL1
            
            local currentL1Node = headerL1Title2Node[key]
            if not currentL1Node then
                currentL1Node = {name=currentHeadingL1, nodes={}, data={}}
                headerL1Title2Node[key] = currentL1Node
                currentNode.nodes[#currentNode.nodes + 1] = currentL1Node
            end
            
            currentNode = currentL1Node
        end
        
        --Categories Level 2
        if currentHeadingL2 then
            local key = currentHeadingL1 .. currentHeadingL2
            
            local currentL2Node = headerL2Title2Node[key]
            if not currentL2Node then
                currentL2Node = {name=currentHeadingL2, nodes={}, data={}}
                headerL2Title2Node[key] = currentL2Node
                currentNode.nodes[#currentNode.nodes + 1] = currentL2Node
            end
            
            currentNode = currentL2Node
        end  
        
        --Categories Level 3
        if currentHeadingL3 then
            local key = currentHeadingL1 .. currentHeadingL2 .. currentHeadingL3
        
            local currentL3Node = headerL3Title2Node[key]
            if not currentL3Node then
                currentL3Node = {name=currentHeadingL3, nodes={}, data={}}
                headerL3Title2Node[key] = currentL3Node
                currentNode.nodes[#currentNode.nodes + 1] = currentL3Node
            end
            
            currentNode = currentL3Node
        end
        
        --Leaf
        if currentNode then
            currentNode.nodes[#currentNode.nodes + 1] = {name=DGV:GetFormattedTitle(guideTitle)
            , isLeaf=true
            , onMouseEnter = OnGuideRowMouseEnter
            , onMouseLeave = OnGuideRowMouseLeave
            , onMouseClick = DugisGuideViewer_TabRow_OnEvent
            , rightText = GetPercentageTextByNodeData
            , data={rawTitle = guideTitle, guideType = guideType}}
        end
    
    end

	PopulateSuggestedGuides = function(threading)
        playerRace,  engPlayerRace  = UnitRace("player") 
        if engPlayerRace == "BloodElf" then
            engPlayerRace = "Blood Elf"
        end
        if engPlayerRace == "NightElf" then
            engPlayerRace = "Night Elf"
        end
        
        if engPlayerRace == "Scourge" then
            engPlayerRace = "Undead"
        end

        BeginAddingGuidesToTreeData(tabs[SUGGEST_TAB])
        
        local iGuides = GetGuides("I", "Current Zone")
        LuaUtils:foreach(iGuides, function(guide)
		
			if threading then
				LuaUtils:RestIfNeeded(threading)
				LuaUtils:WaitForCombatEnd(true)
			end
		
            local isStartingZone = (string.match(DGV.headings[guide], "Starting Zones") ~= nil)
            if not isStartingZone or (isStartingZone and string.match(guide, engPlayerRace)) then
                AddGuideToTreeData(tabs[SUGGEST_TAB].treeData, guide, "I", true)
            end
        end)
        
        local lGuides = GetGuides("L", "Current Zone")
        LuaUtils:foreach(lGuides, function(guide)
		
			if threading then
				LuaUtils:RestIfNeeded(threading)
				LuaUtils:WaitForCombatEnd(true)
			end
		
            local isStartingZone = (string.match(DGV.headings[guide], "Starting Zones") ~= nil)
            if not isStartingZone or (isStartingZone and string.match(guide, engPlayerRace)) then
                AddGuideToTreeData(tabs[SUGGEST_TAB].treeData, guide, "L", true)
            end
        end)

		for _,tabInfo in ipairs(tabs) do
			if tabInfo.guidetype then
			
				local guide = IterateSuggestedGuides({tabInfo.guidetype, threading}, guide)
			
				while guide  do
                    if threading then
                        LuaUtils:RestIfNeeded(threading)
						LuaUtils:WaitForCombatEnd(true)
                    end

                    local isStartingZone = (string.match(DGV.headings[guide], "Starting Zones") ~= nil)
                    if not isStartingZone or (isStartingZone and string.match(guide, engPlayerRace)) then
                        AddGuideToTreeData(tabs[SUGGEST_TAB].treeData, guide, tabInfo.guidetype, true)
                    end
					
					guide = IterateSuggestedGuides({tabInfo.guidetype, threading}, guide)
				end
			end
		end
	end
    
    PopulateRecentGuides = function()
        BeginAddingGuidesToTreeData(tabs[RECENT_TAB])
        
		for _,tabInfo in ipairs(tabs) do
			if tabInfo.guidetype then
				local headingLabel = nil

                local allRecentGuides = DGV:GetFlatternRecentGuides()
				for _,guide in ipairs(allRecentGuides) do
                    if tabInfo.guidetype == DGV.gtype[guide] then
                        if threading then
                            LuaUtils:RestIfNeeded(threading)
                            LuaUtils:WaitForCombatEnd(true)
                        end
                        
                        AddGuideToTreeData(tabs[RECENT_TAB].treeData, guide, tabInfo.guidetype)
                    end
				end
			end
		end
	end
	
	function DGV:InitializeTabs(threading)
		local yofs = -5
		local rowheight = 14
		local i, j, SettingNum, IconNum
		local GuideRow

		Main.homeTab.tabInfo = tabs[1]
		Main.homeTab:SetText(L["Home"])
		Main.currentGuideTab.tabInfo = tabs[2]
		Main.currentGuideTab:SetText(L["Current Guide"])
		Main.settingsTab.tabInfo = tabs[3]
		DGV:CreateSettingsTree(tabs[3].RightFrame)
		tabs[3]:Activate()
		PopulateSuggestedGuides(threading)

		for i = 4, #tabs do
			if threading then
				LuaUtils:RestIfNeeded(threading)
				LuaUtils:WaitForCombatEnd(true)
			end
		
			local selection	= DGVHomeFrame["selection"..i-3]
			local TabInfo	= tabs[i]
			selection.tabInfo = TabInfo
			
			selection.text:SetText(L[TabInfo.text])
			local texture = TabInfo.icon
			if type(texture)=="function" then
				texture(selection.icon)
			else
				selection.icon:SetTexture(texture)
			end
			selection.tooltip = L[TabInfo.title]
            TabInfo.RightFrame:Hide()
			
			if TabInfo.text == "Elites" and not DGV:IsModuleRegistered("NPCDataModule") then 
				selection.icon:Hide()
				selection.text:Hide()
				selection.tooltip = ""
			end

			if TabInfo.text == "Mounts" and not DGV:IsModuleRegistered("MountDataModule") then 
				selection.icon:Hide()
				selection.text:Hide()
				selection.tooltip = ""
			end
			
			if TabInfo.text == "Pets" and not DGV:IsModuleRegistered("PetDataModule") then 
				selection.icon:Hide()
				selection.text:Hide()
				selection.tooltip = ""
			end
			
			if TabInfo.text == "Bosses" and not DGV:IsModuleRegistered("BossDataModule") then 
				selection.icon:Hide()
				selection.text:Hide()
				selection.tooltip = ""
			end			

            if TabInfo.text == "Followers" and not DGV:IsModuleRegistered("FollowerDataModule") then 
				selection.icon:Hide()
				selection.text:Hide()
				selection.tooltip = ""
			end	
           

			
			if TabInfo.text == "Help" then
				--For technical support please contact:
				if not DGV_HelpURLEditBox then
					local logo = CreateFrame("Button", nil, TabInfo.RightFrame)
					logo:SetNormalTexture([[Interface\AddOns\DugisGuideViewerZ\Artwork\logo.tga"]])
					logo:SetPoint("TOPLEFT", -30, 0)
					logo:SetHeight(64)
					logo:SetWidth(256)					

					local techSupport = TabInfo.RightFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
					techSupport:SetText(L["For technical support please contact:"])
					techSupport:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 16, 0)
					
					local helpUrl = CreateFrame("EditBox", "DGV_HelpURLEditBox", TabInfo.RightFrame)
					helpUrl:SetFontObject(GameFontHighlight)
					helpUrl:SetTextInsets(2,2,2,2)
					helpUrl:SetMultiLine(true)
					helpUrl:SetAutoFocus(false)
					local setText = 
						function() 
							helpUrl:SetText("http://www.dugiguides.com/tech-support/")
						end
					setText()
					helpUrl:SetScript("OnTextChanged", function(self, user) if user then setText();helpUrl:HighlightText(); end end)

					helpUrl:SetScript("OnEditFocusGained", function() helpUrl:HighlightText() end)
					helpUrl:SetScript("OnMouseDown", function() helpUrl:HighlightText() end)
					helpUrl:SetScript("OnEditFocusLost", function() helpUrl:HighlightText(0,0) end)
					helpUrl:SetPoint("TOPLEFT", techSupport, "BOTTOMLEFT", 0, 0)
					helpUrl:SetWidth("500")
					helpUrl:SetHeight("20")
					helpUrl:Show()
					
					local videoTutorial = TabInfo.RightFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
					videoTutorial:SetText(L["Video tutorials are available from the link below:"])
					videoTutorial:SetPoint("TOPLEFT", DGV_HelpURLEditBox, "BOTTOMLEFT", 0, -16)
					
					local videoUrl= CreateFrame("EditBox", "DGV_VideoURLEditBox", TabInfo.RightFrame)
					videoUrl:SetFontObject(GameFontHighlight)
					videoUrl:SetTextInsets(2,2,2,2)
					videoUrl:SetMultiLine(true)
					videoUrl:SetAutoFocus(false)
					local setText = 
						function() 
							videoUrl:SetText("http://www.dugiguides.com/videos/")
						end
					setText()
					videoUrl:SetScript("OnTextChanged", function(self, user) if user then setText();videoUrl:HighlightText(); end end)

					videoUrl:SetScript("OnEditFocusGained", function() videoUrl:HighlightText() end)
					videoUrl:SetScript("OnMouseDown", function() videoUrl:HighlightText() end)
					videoUrl:SetScript("OnEditFocusLost", function() videoUrl:HighlightText(0,0) end)
					videoUrl:SetPoint("TOPLEFT", videoTutorial, "BOTTOMLEFT", 0, 0)
					videoUrl:SetWidth("500")
					videoUrl:SetHeight("20")
					videoUrl:Show()		
									
					local iconRefHeading = TabInfo.RightFrame:CreateFontString(nil,"ARTWORK", "GameFontNormalLarge")
					iconRefHeading:SetText(L["Icon Reference"])
					iconRefHeading:SetPoint("TOPLEFT", DGV_VideoURLEditBox, "BOTTOMLEFT", 0, -16) 
				
					local wrow1 = 0
					local wrow2 = 0
					local wrow3 = 0
					local wmax = 0
					for IconNum = 1, #icontbl do
						local width = self:GetFontWidth(L[icontbl[IconNum].text], "GameFontHighlight")
						if width > wmax then wmax = width end
					
						if IconNum == 6 then
							wrow1 = wmax
							wmax = 0
						elseif IconNum == 12 then
							wrow2 = wmax
							wmax = 0
						elseif IconNum == #icontbl then
							wrow3 = wmax
							wmax = 0
						end
						
					end
					
					for IconNum = 1, #icontbl do
						local icon = CreateFrame("Button", "DGV_Settingsicon"..IconNum, TabInfo.RightFrame, "IconReferenceTemplate")
									
						icon.Button:SetNormalTexture(icontbl[IconNum].path)
						icon.Name:SetText(L[icontbl[IconNum].text])
						icon.Name:SetJustifyH("LEFT")
						
						if IconNum < 7 then icon:SetWidth(wrow1 + 50) icon.Name:SetWidth(wrow1 + 50) elseif IconNum < 13 then icon:SetWidth(wrow2 + 50) icon.Name:SetWidth(wrow2 + 50) elseif IconNum < 19 then icon:SetWidth(wrow3 + 50) icon.Name:SetWidth(wrow3 + 50)  end
						if IconNum == 1 then
							icon:SetPoint("TOPLEFT", iconRefHeading, "BOTTOMLEFT",  5, 0)

							--icon:SetPoint("TOPLEFT", 20, -20) 
						elseif IconNum == 7 then
							icon:SetPoint("LEFT", "DGV_Settingsicon1", "RIGHT", -15, 0)
						elseif IconNum == 13 then
							icon:SetPoint("LEFT", "DGV_Settingsicon7", "RIGHT", -15, 0)	
						else
							icon:SetPoint("TOP", "DGV_Settingsicon"..(IconNum-1), "BOTTOM", 0, 13)
						end				
					end
				end
			end
			
            function OnGuideRowMouseEnter(self)
                local nodeData = self:GetParent().nodeData
            
                local title = nodeData.data.rawTitle
                local heading = DugisGuideViewer.headings[title]
                local guidetags = DugisGuideViewer.guidetags[title]
                local gtype = DugisGuideViewer.gtype[title]
                local formatted = DugisGuideViewer:GetFormattedTitle(title)
                local guidemetadata = DugisGuideViewer.guidemetadata[title]
                
                if guidemetadata then
                    NPCJournalFrame:OnGuideRowMouseEnter(title, guidemetadata.objectId, gtype)
                end
                
                if guidemetadata then
                     if guidemetadata.description then
                        local description = guidemetadata.description
                        local image = guidemetadata.image
                        local hintFrame = DGV.NPCJournalFrame.hintFrame
						if description then description = NPCJournalFrame:ReplaceSpecialTags(description, true) end
                        hintFrame:SetMode(GUIUtils.HINT_WINDOW_IMAGE_MODE)
                        hintFrame.frame:ClearAllPoints()
                        hintFrame.frame:SetPoint("TOPLEFT", DugisMain, "TOPRIGHT", 8, 11) 
                        
                        hintFrame.frame:SetWidth(280)
                        hintFrame.showImageInImageMode = (guidemetadata.image ~= nil)
                        
                        formatted = string.gsub(formatted, '|c........', '')
                        formatted = string.gsub(formatted, '|r', '')
                        hintFrame.text:SetTextColor(1, 1, 1);
						if description == "" then 
                            hintFrame:SetText("|cffffd200"..formatted.."|r")
						else
                            hintFrame:SetText("|cffffd200"..formatted.."|r\n\n|cffffffff"..description.."|r")
						end
                        hintFrame.text:SetPoint("TOPLEFT", hintFrame.frame, "TOPLEFT", 18, -150)
                        if image ~= nil then
                            hintFrame.imageFrame.texture:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\Guides\\"..image)
                        end
                        hintFrame:Show(true)    
                        hintFrame:UpdateHeight()                       
                    end
                end
            end    
            
            function OnGuideRowMouseLeave()        
                local hintFrame = NPCJournalFrame.hintFrame
                hintFrame.frame:Hide()   
            end
			
			local gtype = TabInfo.guidetype
			if gtype then
				if DGV.guidelist[gtype] then
                
                    BeginAddingGuidesToTreeData(TabInfo)
                    
					for j =1 , #DGV.guidelist[gtype] do
                        if threading then
                            LuaUtils:RestIfNeeded(threading)
   							LuaUtils:WaitForCombatEnd(true)
                        end
                    
						local title = DGV.guidelist[gtype][j]
                        
                        AddGuideToTreeData(TabInfo.treeData, title, gtype)
					end
				end
			end
		end
	end
    
	function PopulateGlobalSearchResults()
		local yofs = -5
		local rowheight = 14
		local rowCount = 0
        
        local tabRowsList = GetCachedTabRows(SEARCH_TAB)
        
        for i, row in pairs(tabRowsList) do
            row.title = nil
            row:Hide()
        end
        
		for headingIndex,rh in ipairs(Guides.rowHeadings) do
			if rh.tabNum==SEARCH_TAB then
				rh:ClearAllPoints()
				rh:Hide()
			end
		end

        local headerL1Title2Node = {}
        tabs[SEARCH_TAB].treeData = {}
        
        local i=1
		for i=1,#tabs do
			local gtype = tabs[i].guidetype
			if gtype and DGV.guidelist[gtype] then
				local subCat = DGV.guidelist[gtype]
				--DGV:DebugFormat("PopulateGlobalSearchResults", "gtype", gtype)
				for j =1 , #subCat do
                    LuaUtils:RestIfNeeded(true)
					local title = subCat[j]
					if  DGV.Search:InSearchResults(DGV.headings[title], DGV:GetFormattedTitle(title)) then
                        local currentNode = nil
                        local currentHeading = DGV.headings[title]
                        
                        local currentNode = headerL1Title2Node[currentHeading]
                        
                        --New node
                        if not currentNode then
                            currentNode = {name=currentHeading, nodes={}, data={}}
                            headerL1Title2Node[currentHeading] = currentNode
                            tabs[SEARCH_TAB].treeData[#tabs[SEARCH_TAB].treeData + 1] = currentNode
                        end
                        
                        if currentNode then
                            currentNode.nodes[#currentNode.nodes + 1] = {name=DGV:GetFormattedTitle(title)
                            , isLeaf=true
                            , onMouseEnter = OnGuideRowMouseEnter
                            , onMouseLeave = OnGuideRowMouseLeave
                            , onMouseClick = DugisGuideViewer_TabRow_OnEvent
                            , rightText = GetPercentageTextByNodeData
                            , data={rawTitle = title, guideType = gtype}}
                        end
					end
				end
			end

		end

        --Locations
        ---------------------------------
        --------- TREE FRAME ------------
        ---------------------------------
        if DGV_SearchBox:GetNumLetters() > 1 then
            nodes = DGV:GetLocationsAndPortalsByText(DGV_SearchBox:GetText())
            
            LuaUtils:foreach(nodes, function(node)
                tabs[SEARCH_TAB].treeData[#tabs[SEARCH_TAB].treeData + 1] = node
            end)
        else
        end
        
        tabs[SEARCH_TAB]:Activate()
        
		local tabInfo = tabs[SEARCH_TAB]
		tabInfo.rightScrollMax = rowheight * rowCount +  50

        --In case some locations/portals are found the current tab must be hidden 
        if rowCount == 0 and #nodes > 0 then
            activeTabInfo.RightFrame:Hide()
        end
	end
    
    function Guides:UpdateSearch()
        searchThread = coroutine.create(PopulateGlobalSearchResults)

        if DGV_SearchBox:GetNumLetters() > 1 then
            DGV_SearchBox:SetAlpha(0.0)
            SearchingInfoText:Show()
            SearchingInfoText:SetText(L["Searching for"] .. ": " .. DGV_SearchBox:GetText() .. "..")
            searchingPattern = DGV_SearchBox:GetText()
            DugisMainRightScrollFrame.bar:SetEnabled(false)
        else
            SearchingInfoText:Hide()
        end
    end
	
	local abandonQuestReaction
	function Guides:Load()

		DGV:RegisterEvent("UNIT_ENTERED_VEHICLE")
		DGV:RegisterEvent("PLAYER_ENTERING_WORLD")
		DGV:RegisterEvent("UNIT_EXITED_VEHICLE")
		DGV:RegisterEvent("GOSSIP_CLOSED")
        DGV:RegisterEvent("SCENARIO_UPDATE")
        DGV:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
        DGV:RegisterEvent("SCENARIO_COMPLETED")
        DGV:RegisterEvent("UNIT_AURA")		
		if not DGV.guides then DGV.guides = {} end
		if not DGV.guidetags then DGV.guidetags = {} end
        if not DGV.guidemetadata then DGV.guidemetadata = {} end
		if not DGV.nextzones then DGV.nextzones = {} end
		if not DGV.gtype then DGV.gtype = {} end
		if not DGV.rawtitle then DGV.rawtitle = {} end
		if not DGV.guidelist then DGV.guidelist = {} end
		if not DGV.headings then DGV.headings = {} end
        
		if not DGV.hedingsL2 then DGV.hedingsL2 = {} end
		if not DGV.hedingsL3 then DGV.hedingsL3 = {} end

		--DGV.queryquests = {}
		DGV.actions = {}
		DGV.quests1 = {}
		DGV.quests1L = {} --localized quest list
		DGV.quests2 = {}
		DGV.useitem = {}
		DGV.qid = {}
        DGV.sid = {}
		DGV.daily = {}
		DGV.MappedPoints = {}
		DGV.tags = {}
		DGV.coords = {}
		if not DGU.removedQuests then DGU.removedQuests = {} end
		if not DGU.shownObjectives then DGU.shownObjectives = {} end
		DGV.postReqs = {}
		DGV.breadCrumbs = {}
		DGV.visualRows = {}
		visualRows = DGV.visualRows

        
        local questToUncomplete = {}
        
		function DGV:CompleteQuest(completedQID)
			--DebugPrint("Finished a quest, HookScript QuestFrameCompleteQuestButton")
			local qid = completedQID or DGV:GetQIDFromQuestName(GetTitleText())
			--if qid then

			--	DGU.turnedinquests[qid] = true
			--end
			--if CurrentAction and qid then DebugPrint("HOOK qid is"..qid.."*".."action ="..CurrentAction.."*".."titletext="..GetTitleText()) end

			local acceptandcomplete 			= DGV:ReturnTag("E")

			--if not acceptandcomplete then return end

			if not  DGV.quests1L[DGU.CurrentQuestIndex] then return end
			local _, _, questnoparen = DGV.quests1L[DGU.CurrentQuestIndex]:find("([^%(]*)")
			questnoparen = questnoparen:trim()
            
            questToUncomplete[#questToUncomplete + 1] = qid

			if (CurrentAction == "T" and DGV.qid[DGU.CurrentQuestIndex] == qid) or (acceptandcomplete and GetTitleText() == L[questnoparen] )
			then
				if qid then DebugPrint("Detected curent quest turned in"..qid) end
				DGV:SetChkToComplete(DGU.CurrentQuestIndex)
				DGV:MoveToNextQuest()
			else
				DGV:CompleteQID(qid, "T") --not needed UpdateMainFrame() handles this
				DGV:MoveToNextQuest()
			end
			--JustTurnedInQID = qid
            LuaUtils:Delay(5, function()
                LuaUtils:foreach(questToUncomplete, function(qidToUncheck)
                    for i=1, #DugisGuideViewer.visualRows do
                        local qid = DugisGuideViewer.qid[i]
                        if tonumber(qidToUncheck) == tonumber(qid) and QuestUtils_IsQuestWorldQuest(tonumber(qid)) then
                            DugisGuideViewer:SetChkToNotComplete(i)
                        end
                    end
                end)
                
                questToUncomplete = {}
                DugisGuideViewer:MoveToPrevQuest()
            end)
            
		end

		function DGV:ClearScreen()
			if InCombatLockdown() then print("|cff11ff11Dugi Guides: |r|cffcc0000Cannot clear guides during combat.|r Please try again."); return end
			DGV:SetViewTabTitle(L["No Guide Loaded"])
			DGV:LoadInitialView(L["No Guide Loaded"], "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\iconbutton.tga", L["Right Click Here To Select One"])
			DGV:WipeOutViewTab()
			wipe(DGV.actions)
			DGV:UpdateSmallFrame()
			if DugisGuideViewer:IsModuleLoaded("Target") then
				DugisGuideViewer.Modules.Target.Frame:Hide()
			end
			DugisGuideViewerActionItemFrame:Hide()
			DugisSecureQuestButton:Hide()
			if SmallFrameProgressBar and SmallFrameProgressBar:IsShown() then SmallFrameProgressBar:Hide() end			
		end

		function DGV:isValidGuide(title)
			if self.guides[title] then
				return true
			end
			return false
		end
		
		function DGV:ShowLargeWindow()
			if (WorldMapFrame:IsShown() and DugisGuideViewer.Modules.MapPreview:IsAnimating()) then HideUIPanel(WorldMapFrame) end
			--DugisMainframe:SetHeight(400)
			DGV:AutoScroll(DGU.CurrentQuestIndex)
			DugisMainBorder:Show()
			DugisMainBorder.bg:Show()
			--DugisSmallFrameLogo:Show()

			DugisMain:Show()
			LuaUtils:PlaySound("igCharacterInfoOpen")
			--DugisReloadButton:Show()
			--DugisSuggestButton:Show()
			--DugisResetButton:Show()
			--DGV:SetAllBorders()
			DugisMainBorder:SetHeight(420)
            
            DugisGuideViewer:UpdateCurrentGuideExpanded()
            
			if UpdateWhatsNewFramePositions then
				UpdateWhatsNewFramePositions()
			end
		end
		
		function DGV:CheckForFloorChange()
			if CurrentAction == "R" or self:ReturnTag("F") then
				local map, floor = self:ReturnTag("F")
				if map and floor and floor == DGV.DugisArrow.floor and map == DGV.DugisArrow.map then
					--DebugPrint("Detected correct floor in dungeon")
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				elseif not floor and map and map == DGV.DugisArrow.map then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end	
			end
		end
		
		local AbandonQID
		local function UpdateAbandonQID()

			local i = GetQuestLogSelection()
			AbandonQID = select(8, GetQuestLogTitle(i))
			--DGV:DebugFormat("UpdateAbandonQID", "AbandonQID", AbandonQID)
		end
		abandonQuestReaction = RegisterFunctionReaction("AbandonQuest", nil, UpdateAbandonQID)
		
		function DGV:UpdateMainFrame(isInThread)
			if DGV:isValidGuide(CurrentTitle) ~= true then return end
			SuspendViewFrameUpdate()
			local i, guideIndex
			local setChecked = false 
			
            
            local indicesToComplete = {}
            local notCompletedQuests = {}
            
			--Check for all completed or user uncompleted quests in quest log 
			for guideIndex = 1, #visualRows do
				local qComplete, QuestComplete
				local qid 			= self.qid[guideIndex]
				local logIndx 		= self:GetQuestLogIndexByQID(qid)
				local action 		= self.actions[guideIndex]
				local questState	= self:GetQuestState(guideIndex)
				local questPart 	= self:ReturnTag("QIDP", guideIndex)
				local needsLoot 	= self:ReturnTag("L", guideIndex)
				local isDaily		= self:ReturnTag("D", guideIndex)
				local reqlvl 		= self:ReturnTag("PL", guideIndex)
				local playerLevel	= UnitLevel("player")
				local ayg			= self:ReturnTag("AYG", guideIndex)
				local oid1, oid2, oid3, oid4	= self:ReturnTag("OID", guideIndex)
				local tid			= self:ReturnTag("TID", guideIndex)
				local buff			= self:ReturnTag("BUFF", guideIndex)
				
				if logIndx then _, _, _, _, _, qComplete, _, _ = GetQuestLogTitle(logIndx) end
                
                
				LuaUtils:RestIfNeeded(isInThread)
				 
			 	if qComplete == 1 
                 or self:QuestPartComplete(guideIndex) 
                 or (not isDaily and self:HasQuestBeenTurnedIn(qid)) 
                 or self:ProfessionCompletedAtGuideIndex(guideIndex) 
                 or self:CheckForLocation(guideIndex) 
                 or self:AchieveCompleteFromGuideIndex(guideIndex) 
                 or self:CheckForHearth(guideIndex)  then 
                    QuestComplete = true 
                 else 
                    QuestComplete = nil 
                    if qid then
                        notCompletedQuests[qid] = true
                    end
                 end
								
				if (action == "A" and logIndx) 
                or (QuestComplete and action ~= "T") 
                or (QuestComplete and action == "T" and not logIndx) 
                or (ayg and EvaluateAYG(ayg)) 
                or (questState == "C" and strmatch(action, "[NFfRBbh]") and not questPart and not needsLoot) 
                or (reqlvl and reqlvl <= playerLevel and not action == "f") 
                or (oid1 and EvaluateOID(oid1)) 
                or (oid2 and EvaluateOID(oid2)) 
                or (oid3 and EvaluateOID(oid3)) 
                or (oid4 and EvaluateOID(oid4)) 
                or (tid and EvaluateTID(tid)) 
                or (buff and EvaluateBUFF(buff)) then  												
					if not visualRows[guideIndex].Chk:GetChecked() then 
                   
                       indicesToComplete[guideIndex] = qid or 1
					   setChecked = true

					end 
				end
				guideIndex = guideIndex + 1
			end
            
            LuaUtils:foreach(indicesToComplete, function(qid, guideIndex)
                if not qid or qid == 1 then
                    DGV:SetChkToComplete(guideIndex)
                else
                    if QuestUtils_IsQuestWorldQuest(qid) then
                        --Making unchecked World Quests on complete. Filtering out compelted quests.
                        if notCompletedQuests[qid] then
                            DGV:SetChkToComplete(guideIndex)
                        end
                    else
                        DGV:SetChkToComplete(guideIndex)
                    end
                end
            end)
            
			if setChecked and not self.preLoadMode then
                local nextUnchecked = self:FindNextUnchecked(isInThread)
            
				if (nextUnchecked ~= DGU.CurrentQuestIndex) then
					self:MoveToNextQuest(nextUnchecked, isInThread)
				else
					self:MoveToNextQuest(nil, isInThread)
				end
			elseif self:ReturnTag("POI", guideIndex) then 
				self:DelayAndMapCurrentObjective(0.2)				
			end 
			
			--Abandoned Quest
			if AbandonQID and DGU.CurrentQuestIndex then
				--local logidx = self:GetQuestLogIndexByQID(AbandonQID)
				--if not logidx then --user abandoned quest but it hasn't registered yet			
					for i =1, #visualRows do
						LuaUtils:RestIfNeeded(isInThread)
						if self.qid[i] == AbandonQID and strmatch(self.actions[i], "[ACTNKR]") then
							self:ClrChk(i)
						end
						local oid1, oid2, oid3, oid4	= self:ReturnTag("OID", i)
						if tonumber(oid1) == AbandonQID or tonumber(oid2) == AbandonQID or tonumber(oid3) == AbandonQID or tonumber(oid4) == AbandonQID and strmatch(self.actions[i], "[ACTNKR]") then
							self:ClrChk(i)
						end
					end
					local nextindex = self:FindNextUnchecked()
					if nextindex < DGU.CurrentQuestIndex then
						self:MoveToPrevQuest()
					end
					AbandonQID = nil	
				--end
			end				
			
			self.UpdateStickyFrame( )
			ResumeViewFrameUpdate(isInThread)			
		end
		
		-- function DGV:UpdateQueryQuests()
			-- if DGV.queryquests then
				-- local quest
				-- for quest, _ in pairs(DGV.queryquests) do
					-- DGU.turnedinquests[quest] = true
				-- end
				-- DGV.queryquests = {}
			-- end
		-- end
		
		local lastInstanceEntered
		local function CheckDungeonZoneIn()
			if IsInInstance() then
				--local currentZone = DGV:GetPlayerMapPositionDisruptive() --required to override MapPreview
                LuaUtils:DugiSetMapToCurrentZone()
                currentZone = DGV:GetCurrentMapID() 
				if currentZone==lastInstanceEntered then return end --one suggestion per entry
				lastInstanceEntered = currentZone
				MatchDungeonGuides(currentZone)
			end
		end
		
		function DGV:CompleteOnZoneCheck()
			local correctzone
			
			if DGV:ReturnTag("CHKMAP", DGU.CurrentQuestIndex) then 
				DGV:MoveToNextQuest()
			end
			
			if DGV:ReturnTag("AYG", DGU.CurrentQuestIndex) then						
				correctzone = DGV:CheckForLocation(DGU.NextQuestIndex)	
				if correctzone then 
					DGV:SetChkToComplete(DGU.NextQuestIndex)
					DGV:MoveToNextQuest()
				end							
			else 
				correctzone = DGV:CheckForLocation(DGU.CurrentQuestIndex)
				if correctzone then 
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end
			end
		end
		
		function DGV:Zone_OnEvent()
			DGV:CompleteOnZoneCheck()
			CheckDungeonZoneIn()
		end
		
		function DGV:CHAT_MSG_SYSTEM(event, msg)
			--Detect hearth, quest accept or quest complete
			local msgqid, curqid, questnoparen
			local _, _, loc 	= msg:find(L["(.*) is now your home."])
			local _, _, accept = msg:find(L["Quest accepted: (.*)"])
			
			if DGV:isValidGuide(self.CurrentTitle) == false then return end
			
			if loc then --Set Hearth	
				questnoparen = DGV.quests1[DGU.CurrentQuestIndex]:match("([^%(]*)")
				questnoparen = questnoparen:trim()
				if CurrentAction == "h" and questnoparen == loc then
					DebugPrint( "Detected setting hearth to ".. loc.."message:".. msg)
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end

			elseif accept then	--Quest accept
				curqid 		= DGV.qid[DGU.CurrentQuestIndex]
				msgqid 		= DGV:GetQIDFromQuestName(accept)	
				--DebugPrint("accept ="..accept.."quest id is"..msgqid.."*".."action ="..CurrentAction.."*")
				
				if CurrentAction == "A" and msgqid == curqid then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				elseif DGV:ReturnTag("E", DGU.CurrentQuestIndex) then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				else --not current quest but accept by user into log
					DGV:CompleteQID(msgqid, "A")
					DGV:MoveToNextQuest()
				end
				
				--Skip breadcrumbs if any
				self:SkipBreadCrumbs(msgqid)
			end

		end
		
		--[[function DGV:UI_INFO_MESSAGE(err, msg)
			if (CurrentAction == "f") then
			DebugPrint("CurrentAction="..CurrentAction.."msg="..msg.."ERR_NEWTAXIPATH="..ERR_NEWTAXIPATH)
				if msg == ERR_NEWTAXIPATH then

					DebugPrint("Detected completed new flight path")
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()	
				end
			end
		end]]--
		
		local function CheckLTag()
			if CurrentTitle ~= nil then
				local itemid
				local guideIndex = DGU.CurrentQuestIndex
				--local itemlink = string.match(msg, LOOT_SELF_REGEX) or string.match(msg, LOOT_PUSHED_REGEX)
				
				--if itemlink then itemid = string.match(itemlink, "item:(%d+):")	end
				
				--[[for guideIndex = 1, #visualRows do
					if DGV:ReturnTag("L", guideIndex) then 
						if DGV:IsCompleteLootQO("CMSG", itemid, guideIndex) then 
							DGV:SetChkToComplete(guideIndex) 
							DGV:MoveToNextQuest()
						end
					end 
				end]]
				if DGV:ReturnTag("L", guideIndex) and DGV:havelootitem(guideIndex) == true then 
					DGV:SetChkToComplete(guideIndex) 
					DGV:MoveToNextQuest()
				end 				
			end			
		end 

		local LOOT_SELF_REGEX = gsub(LOOT_ITEM_SELF, "%%s", "(.+)") --"You receive item: %s."
		local LOOT_PUSHED_REGEX = gsub(LOOT_ITEM_PUSHED_SELF, "%%s", "(.+)") --"You receive loot: %s."
		function DGV:CHAT_MSG_LOOT(event, msg)	--We use delay 1s now because BFA loot detection is slower. 
			if DGV:ReturnTag("L", guideIndex) then 
				LuaUtils:Delay(1, function()
					CheckLTag()
				end)
			end 
		end
				
		function DGV:UpdateAchieveFrame()
			if DGV:isValidGuide(CurrentTitle) == true then
				if DGV.gtype[CurrentTitle] == "A" or DGV.gtype[CurrentTitle] == "E" or DGV.gtype[CurrentTitle] == "D" then --achieve guide type
					local i
					for i=1, #visualRows do
						if self:AchieveCompleteFromGuideIndex(i) then 
							self:SetChkToComplete(i)
							if i == DGU.CurrentQuestIndex then DebugPrint("3") self:MoveToNextQuest() end		
						end
					end
				end
			end
		end
		
		local achieveDelay
		local achvTime = 0
		function onAchUpdate(self,elapsed)
			achvTime = achvTime + elapsed
			if achvTime >= 3 then
				DebugPrint("***Calling UpdateAchieveFrame()")
				achieveDelay:Hide()
				achvTime = 0
				DGV:UpdateAchieveFrame()

			end
		end

		if not achieveDelay then
			achieveDelay = CreateFrame("frame")
			achieveDelay:SetScript("OnUpdate", onAchUpdate)
			achieveDelay:Hide()
		end

		function achieveDelayStart( )
			achvTime = 0
			achieveDelay:Show()
		end
		
		function DGV:Guide_CRITERIA_UPDATE()
			if DGV.gtype[CurrentTitle] == "A" or DGV.gtype[CurrentTitle] == "E" or DGV.gtype[CurrentTitle] == "D" then
				achieveDelayStart( ) 	
			end
		end
		
		function DGV:PLAYER_LEVEL_UP(self, level)
            DugisCharacterCache.CalculateScore_cache_v11 = {}
            DGV.GearFinderScoreGuide_cache_v1 = {}
        
			--skip quest that is grey ! or too high level, and check again on playerlevel up event to see if they can pick them up
			if not InCombatLockdown() then		
				DGU.PlayerLevel = tonumber(level) or UnitLevel("player")
				DGV:UpdatePlayerLevels(DGU.PlayerLevel)
                DGV.ShowSuggestGuideNotification(DGU.PlayerLevel, true)
				DGV:DisplayViewTab(CurrentTitle)
			else
				DGV.DoOutOfCombat(DGV.PLAYER_LEVEL_UP)
			end
			DugisGuideUser.alreadySuggestedGuides = {}
			
			if DGV.Modules.GearAdvisor then
				DGV.Modules.GearAdvisor.ClearLastOwnedItemsInfo()
			end
		end		

		
		function DGV:GOSSIP_CLOSED()
			DebugPrint("###GOSSIP_CLOSED")
			if self:ReturnTag("V") or DGV.actions[DGU.CurrentQuestIndex] == "F" then
				if UnitInVehicle("player") == 1 or UnitControllingVehicle("player") == true or UnitOnTaxi("player") == true or HasOverrideActionBar("player") == true then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end
			end
		end
		
		function DGV:UNIT_ENTERED_VEHICLE()
			DebugPrint("###UNIT_ENTERED_VEHICLE")
			if self:ReturnTag("V") or DGV.actions[DGU.CurrentQuestIndex] == "F" then
				if UnitInVehicle("player") == 1 or UnitControllingVehicle("player") == true or UnitOnTaxi("player") == true or HasOverrideActionBar("player") == true then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end
			end
		end		
        
        function DGV:PLAYER_ENTERING_WORLD()
           DGV:UpdateAllSIDs(true)
		end
        
        function DGV:UpdateAllSIDs(reset)
			local name, currentStage, numStages = C_Scenario.GetInfo()
			if not name then return end
		--	if ( currentStage and currentStage > numStages ) then --Dungeon Complete
		--		DGV:SetCompleteAllSID()
		--	else 		
			local _, _, numCriteria = C_Scenario.GetStepInfo()
			for crit=1, numCriteria do
				local _, _, criteriaCompleted, _, _, _, _, _, criteriaID = C_Scenario.GetCriteriaInfo(crit)

				DGV:SetCompletedSID(criteriaID, criteriaCompleted, reset)
			end
			local tblBonusSteps = C_Scenario.GetBonusSteps();
			for i = 1, #tblBonusSteps do
				local bonusStepIndex = tblBonusSteps[i];
				local _, _, numCriteria = C_Scenario.GetStepInfo(bonusStepIndex);
			  for criteriaIndex = 1, numCriteria do
					local _, _, criteriaCompleted, _, _, _, _, _, criteriaID = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex)
					DGV:SetCompletedSID(criteriaID, criteriaCompleted, reset)
				end	
			end	
			local setcheck 

			for i = 1, #visualRows do
				local guideStage = DGV:ReturnTag("STAGE", i)
				local qid = DGV:ReturnTag("QID", i)
				if guideStage == "" then 
					guidestage = nil 				
				end
				guideStage = tonumber(guideStage)
				if (guideStage and guideStage < currentStage) or (guideStage and currentStage == 0) then 
					DGV:SetChkToComplete(i)
					setcheck = true
				elseif guideStage and guideStage > currentStage and not qid then 
					DGV:SetChkToNotComplete(i)
					setcheck = true
				end
			end
			if setcheck then DGV:MoveToNextQuest() end
        end
        
        function DGV:SCENARIO_CRITERIA_UPDATE(eventName, criteriaId)
            DGV:UpdateAllSIDs()
		end

		--[[function DGV:SCENARIO_UPDATE()
            DGV:UpdateAllSIDs()
		end

        function DGV:SCENARIO_COMPLETED()
            DGV:UpdateAllSIDs()
		end--]] --don't really need these SCENARIO_CRITERIA_UPDATE takes care of it all.
        
		function DGV:UNIT_EXITED_VEHICLE()
			DebugPrint("###UNIT_EXITED_VEHICLE")
			self:MapCurrentObjective()
		end

		function DGV:UNIT_AURA()
			if self:ReturnTag("BUFF") then
				local buff = self:ReturnTag("BUFF")
				if EvaluateBUFF(buff) == true then
					DGV:SetChkToComplete(DGU.CurrentQuestIndex)
					DGV:MoveToNextQuest()
				end
			end
		end					
        
        
        --heading       Category name. It can be a table for example {"Starting Zones", "Forests", "Green Forests"} in this case "Starting Zones" is Level 1 category, "Forests" level 2 and "Green Forests" level 3 category
		--title: 		A string describing the zone and level range
		--nextguide: 	(Optional) The next guide to load when this guide is completed
		--faction:		Values: Horde, Alliance or nil means both factions
		--guidetype: 	Levling(L), Dailies(D) or Events(E) type of guide
		--rowinfo: 		Containins the actual guide data
		--tag: 			Guide options like |PZ|
		function DGV:RegisterGuide(heading, title, nextguide, faction, class, guidetype, tag, rowinfo, metadata)
			local myfaction = UnitFactionGroup("player") --No need to localize
			local myclass = select(2, UnitClass("player"))
			
			if class ~= nil then 
				if class ~= myclass then return end
			end
            
            local heading = heading
            local hedingL2 = nil
            local hedingL3 = nil
            
            if type(heading) == "table" then
                hedingL3 = heading[3]
                hedingL2 = heading[2]
                heading = heading[1]
            end
			
			if faction == myfaction or faction == nil then	
				--DebugPrint( "Title:"..title.."nextguide:"..nextguide.."faction:"..faction.."guidetype"..guidetype)
				
				self.guides[title] 	= rowinfo
				self.guidetags[title] 	= tag
				self.nextzones[title] 	= nextguide
				self.gtype[title] 	= guidetype
				self.headings[title] 	= heading
                
                if hedingL2 then
                    self.hedingsL2[title] = hedingL2
                end    
                
                if hedingL3 then
                    self.hedingsL3[title] = hedingL3
                end
                
                metadata = metadata or {}
                self.guidemetadata[title] = metadata
				
				--Save backwards lookup from display title to raw title
				local title1 = self:GetFormattedTitle(title, "Easy")
				local title2 = self:GetFormattedTitle(title, "Normal")
				local title3 = self:GetFormattedTitle(title, "Hard")
						

				if title1 then
					self.rawtitle[title1] = title
				end
				
				if title2 then
					self.rawtitle[title2] = title
				end
				
				if title3 then
					self.rawtitle[title3] = title
				end
				
				if guidetype == "L" then 			
					if not self.guidelist["L"] then self.guidelist["L"] ={} end
					table.insert(self.guidelist["L"], title)
				elseif guidetype == "I" then
					if not self.guidelist["I"] then self.guidelist["I"] ={} end
					table.insert(self.guidelist["I"], title)
				elseif guidetype == "D" then
					if not self.guidelist["D"] then self.guidelist["D"] ={} end
					table.insert(self.guidelist["D"], title)
				elseif guidetype == "E" then
					if not self.guidelist["E"] then self.guidelist["E"] ={} end
					table.insert(self.guidelist["E"], title)
				elseif guidetype == "A" then
					if not self.guidelist["A"] then self.guidelist["A"] ={} end
					table.insert(self.guidelist["A"], title)
				elseif guidetype == "Followers" then
					if not self.guidelist["Followers"] then self.guidelist["Followers"] ={} end
					table.insert(self.guidelist["Followers"], title)
				elseif guidetype == "Bosses" then
					if not self.guidelist["Bosses"] then self.guidelist["Bosses"] ={} end
					table.insert(self.guidelist["Bosses"], title)
				elseif guidetype == "NPC" then
					if not self.guidelist["NPC"] then self.guidelist["NPC"] ={} end
					table.insert(self.guidelist["NPC"], title)
				elseif guidetype == "Pets" then
					if not self.guidelist["Pets"] then self.guidelist["Pets"] ={} end
					table.insert(self.guidelist["Pets"], title)				
                elseif guidetype == "Mounts" then
					if not self.guidelist["Mounts"] then self.guidelist["Mounts"] ={} end
					table.insert(self.guidelist["Mounts"], title)
				elseif guidetype == "P" then
					if not self.guidelist["P"] then self.guidelist["P"] ={} end
					table.insert(self.guidelist["P"], title)
				end
			end
		end

		function DGV:GetUnfinishedGuideIndexByQID(qid)
			local i
			for i=1, #visualRows do
				if DGV.qid[i] == qid and DGV:GetQuestState(i)~="C" then return i end
			end	
		end
	

		function DGV:ReturnTag(tag, i)
			i = i or DGU.CurrentQuestIndex
			local tags = DGV.tags[i]
			local questTitle = DGV.quests1L[i]
			
			if not tags then return end
			if tag == "O" then return tags:find("|O|")
			elseif tag == "MAP" then
				local map1, map2, map3, map4 = tags:match("|MAP|(%d+),?%s?(%d*),?%s?(%d*),?%s?(%d*)|")
				if map1 == "" then map1 = nil end
				if map2 == "" then map2 = nil end
				if map3 == "" then map3 = nil end
				if map4 == "" then map4 = nil end				
				return map1, map2, map3, map4
			elseif tag == "PRE" then
				local pre1, pre2 = tags:match("|PRE|(%d+),?%s?(%d*)|")
				if pre1 == "" then pre1 = nil end
				if pre2 == "" then pre2 = nil end
				return pre1, pre2			
			elseif tag == "PHA" then
				return tags:match("|PHA|(%d+)")
			elseif tag == "OID" then
				local oid1, oid2, oid3, oid4 = tags:match("|OID|(%d+),?%s?(%d*),?%s?(%d*),?%s?(%d*)|")
				if oid1 == "" then oid1 = nil end
				if oid2 == "" then oid2 = nil end
				if oid3 == "" then oid3 = nil end
				if oid4 == "" then oid4 = nil end				
				return oid1, oid2, oid3, oid4				
			elseif tag == "AYG" then
				return tags:match("|AYG|(%d+)")
			elseif tag == "TID" then
				return tags:match("|TID|(%d+)")										
			elseif tag == "REP" then
				return tags:match("|REP|(%d+),%s*(%d)")	
			elseif tag == "FS" then
				return tags:match("|FS|(%d+),%s*(%d+)")					
			elseif tag == "QIDP" then
				local qidpart = tags:match("|QID|%d+%.(%d+)")
				return qidpart
			elseif tag == "L" then
				local _, _, lootitem, lootqty = tags:find("|L|(%d+)%s?(%d*)|")
				lootqty = tonumber(lootqty) or 1
				return lootitem, lootqty
			elseif tag == "CUR" then
				local _, _, curitem, curqty = tags:find("|CUR|(%d+)%s?(%d*)|")
				curqty = tonumber(curqty) or 1
				curitem = tonumber(curitem)
				return curitem, curqty				
			elseif tag == "P" then

				local profession, professionlvl = tags:match("|P|(%w+%s?%w*)%s+(%d+)")
				if profession then 
					if L[profession] then profession = L[profession] end
				end
				return profession, tonumber(professionlvl)
			elseif tag == "OP" then
				local profession, professionlvl = tags:match("|OP|(%w+%s?%w*)%s+(%d+)")
				if profession then 

					if L[profession] then profession = L[profession] end
				end
				return profession, tonumber(professionlvl)				
			elseif tag == "PL" then
				local playerlvl = tags:match("|PL|(%d+)|")
				return tonumber(playerlvl)
			elseif tag == "PM" then --ex: |PM|Alchemy|75|
				local profession, maxlevel = tags:match("|PM|(%w+%s?%w*)%s*|(%d+)|")

				if profession then 
					if L[profession] then profession = L[profession] end
				end
				return profession, tonumber(maxlevel)
			elseif tag == "Z" then --ex: |Z|mapID mapFloor|
				local mapID, mapFloor = tags:match("|Z|(%d+)%s?(%d*)|")
				return tonumber(mapID), tonumber(mapFloor)			
			elseif tag == "F" then --ex: |F|mapID mapFloor|
				local mapID, mapFloor = tags:match("|F|(%d+)%s?(%d*)|")
				return tonumber(mapID), tonumber(mapFloor)
			elseif tag == "NPC" then --ex: |NPC|37087| or |NPC|708, 704, 705|
				local npc1, npc2, npc3, npc4, npc5 = tags:match("|NPC|(%d+),?%s?(%d*),?%s?(%d*),?%s?(%d*),?%s?(%d*)|")
				if npc1 == "" then npc1 = nil end
				if npc2 == "" then npc2 = nil end
				if npc3 == "" then npc3 = nil end
				if npc4 == "" then npc4 = nil end
				if npc5 == "" then npc5 = nil end
				return npc1, npc2, npc3, npc4, npc5
			elseif tag == "CHOICE" then --ex: |CHOICE|2|
				local id = tags:match("|CHOICE|(%d+)")
				return id
			elseif tag == "OBJ" then --ex: |OBJ|37087| or |OBJ|708, 704, 705|
				local obj1, obj2, obj3, obj4, obj5 = tags:match("|OBJ|(%d+),?%s?(%d*),?%s?(%d*),?%s?(%d*),?%s?(%d*)|")
				if obj1 == "" then obj1 = nil end
				if obj2 == "" then obj2 = nil end
				if obj3 == "" then obj3 = nil end
				if obj4 == "" then obj4 = nil end
				if obj5 == "" then obj5 = nil end
				return obj1, obj2, obj3, obj4, obj5
			elseif tag == "S" then 
				if tags:match("|N|Speak ") or tags:match("|N|Talk ") or tags:match(" Speak ") or tags:match(" speak ") or tags:match(" Talk ") or tags:match(" talk ") or tags:match("|N|Parle") or tags:match("|N|Discuter") or tags:match(" Parle ") or tags:match(" parle ") or tags:match(" Discuter ") or tags:match(" discuter ") or questTitle:match("Speak") or questTitle:match("Parle") then
					return true
				end
			elseif tag == "ST" then 
				if questTitle:match("Speak") or questTitle:match("Parle") then
					return true
				end				
			elseif tag == "K" then 
				if (tags:match(" Kill ") or tags:match(" kill ") or tags:match("|N|Kill ") or tags:match("|N|kill ") or tags:match(" killing ") or tags:match(" en tuant ") or tags:match("Slay ") or tags:match("slay ") or tags:match("Defeat ") or tags:match("defeat ") or tags:match("ExÃƒÂ©cuter ") or tags:match("exÃƒÂ©cuter ") or tags:match("%) from ") or tags:match("%) sur ") or tags:match("drop") or tags:match("obtenu") or tags:match(" damage ") or tags:match("|N|Damage ") or tags:match(" attack ") or tags:match("|N|Attack ")) and tags:match("|NPC|") then
					if not (questTitle:match("%(item:") or questTitle:match("%[[^%]]+%]")) then
						return true
					end
				end
			elseif tag == "T" then 
				if (tags:match("%(item:") or tags:match("%[[^%]]+%]") or tags:match("|T|")) and not tags:match("|U|") then 
					return true
				end
			elseif tag == "RESET" then 
				if tags:match("|RESET|") then 
					return true
				end					
			elseif tag == "STAGE" then
				local stage = tags:match("|SID|%d+%|(%d*)|")
				return stage
			end
			
			return select(3, tags:find("|"..tag.."|([^|]*)|?"))
		end

		function DGV:IterateGuideIndicesWithQID(qid, delegate)
			local i
			for i=1, #visualRows do
				if DGV.qid[i] == qid then
					delegate(i)
				end
			end
		end
		
		function DGV.DeselectTopTabs()
			Main.homeTab:Enable();
			Main.homeTab:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
			Main.homeTab.selectedGlow:Hide();
			
			Main.currentGuideTab:Enable();
			Main.currentGuideTab:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
			Main.currentGuideTab.selectedGlow:Hide();
			
			Main.settingsTab:SetChecked(false)
		end
	end
	
	function Guides:OnModulesLoaded(threading)
		NPCJournalFrame = DGV.NPCJournalFrame
		DGV:InitializeTabs(threading)
		DGV:HideLargeWindow()	
		DGV:ShowViewTab()
		
		--Load saved guide
		if DGV:isValidGuide(CurrentTitle) == true  then
			DGV:DisplayViewTab(CurrentTitle, nil, threading)
		else --Load Default 	
			DGV:ClearScreen()
			if DGV.chardb.FirstTime then
				DGV.chardb.FirstTime = false
				DGV:InitFramePositions()
				DGV:SuggestButtonOnClick(true, threading)			
			end		
		end
        
        if DGV.GuidesOnModulesLoadedExtension then
            DGV.GuidesOnModulesLoadedExtension()
        end
        
	end
	
	function Guides:Unload()
		DGV:UnregisterEvent("UNIT_ENTERED_VEHICLE")
		DGV:UnregisterEvent("PLAYER_ENTERING_WORLD")
		DGV:UnregisterEvent("UNIT_EXITED_VEHICLE")
		DGV:UnregisterEvent("GOSSIP_CLOSED")
        DGV:UnregisterEvent("SCENARIO_UPDATE")
        DGV:UnregisterEvent("SCENARIO_CRITERIA_UPDATE")
        DGV:UnregisterEvent("SCENARIO_COMPLETED")    
        DGV:UnregisterEvent("UNIT_AURA")		    
		abandonQuestReaction:Dispose()
		for i = 1, #tabs do
			local j
			for j=1,math.huge,1 do

				local row=_G["DugisTab"..i.."Row"..j]
				if not row then break end
				--row:Hide()
			end
		end
		
		QuestLogFrameTrackButton_OnClick = DGV.NoOp
		DGV:HideLargeWindow()
		if DGV:UserSetting(DGV_UNLOADMODULES) then
			wipe(DGV.guides)
			DGV.guides = nil
			wipe(DGV.guidetags)
			DGV.guidetags = nil
			wipe(DGV.nextzones)
			DGV.nextzones = nil
			wipe(DGV.gtype)
			DGV.gtype = nil
			wipe(DGV.rawtitle)
			DGV.rawtitle = nil
			wipe(DGV.guidelist)
			DGV.guidelist = nil
			wipe(DGV.headings)
			DGV.headings = nil
                     
            wipe(DGV.hedingsL2)
			DGV.hedingsL2 = nil 
            wipe(DGV.hedingsL3)
			DGV.hedingsL3 = nil
		end
		
		--wipe(DGV.queryquests)
		--DGV.queryquests = nil
		wipe(DGV.actions)
		DGV.actions = nil
		wipe(DGV.quests1)
		DGV.quests1 = nil
		wipe(DGV.quests1L)
		DGV.quests1L = nil --localized quest list
		wipe(DGV.quests2)
		DGV.quests2 = nil
		wipe(DGV.useitem)
		DGV.useitem = nil
		wipe(DGV.qid)
		DGV.qid = nil
		wipe(DGV.daily)
		DGV.daily = nil
		wipe(DGV.MappedPoints)
		DGV.MappedPoints = nil
		wipe(DGV.tags)
		DGV.tags = nil
		wipe(DGV.coords)
		DGV.coords = nil
		wipe(DGV.postReqs)
		DGV.postReqs = nil
		wipe(DGV.breadCrumbs)
		DGV.breadCrumbs = nil
		wipe(DGV.visualRows)
		DGV.visualRows = nil
		visualRows = nil
	end
end
