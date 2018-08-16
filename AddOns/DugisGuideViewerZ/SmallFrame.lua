local WATCHFRAME_INITIAL_OFFSET = 0;
local WATCHFRAME_TYPE_OFFSET = 10;
 
local WATCHFRAMELINES_FONTSPACING = 0;

local WATCHFRAME_SETLINES_NUMLINES = 5;  

local WATCHFRAME_ITEM_WIDTH = 33;

local _

local spaceForSmallFrameHeader = 25
--//////////////////////////////////////////


local DGV = DugisGuideViewer
if not DGV then return end

local SmallFrame = DGV:RegisterModule("SmallFrame")--, "Guides")
DGV.SmallFrame = SmallFrame

SmallFrame.Frame = CreateFrame("Frame", "DugisSmallFrameContainer", UIParent)
DugisSmallFrame = SmallFrame.Frame
DugisSmallFrame:SetFrameStrata("BACKGROUND")
DugisSmallFrame:SetFrameLevel(9)
SmallFrame.Frame:SetHeight(52)
SmallFrame.Frame:SetMovable(true)
--SmallFrame.Frame:SetClampedToScreen(true)
--The following is required to maintain positioning through guide states
SmallFrame.Frame:SetWidth(1)
SmallFrame.Frame:SetClampedToScreen(true)
SmallFrame.collapsed = false

---BKG
SmallFrame.SmallFrameBkg = CreateFrame("Frame", "SmallFrameBkg", UIParent)
SmallFrameBkg:SetFrameStrata("BACKGROUND")
SmallFrameBkg:SetFrameLevel(8)
SmallFrameBkg:SetWidth(52)
SmallFrameBkg:SetHeight(52)
SmallFrameBkg:SetPoint("CENTER", 0, 220)
SmallFrameBkg:EnableMouse(false)
SmallFrameBkg:SetAlpha(0)

local header = CreateFrame("Frame", nil, UIParent, "ObjectiveTrackerHeaderTemplate")
header.module = DEFAULT_OBJECTIVE_TRACKER_MODULE;
header.isHeader = true;
header.Text:SetText("Guides");
header.animateReason = OBJECTIVE_TRACKER_UPDATE_QUEST_ADDED or 0;
header:SetFrameStrata("BACKGROUND")
header:SetFrameLevel(10)

if headerAnim == true then 
	header.animating = true;
	header.HeaderOpenAnim:Stop();
	header.HeaderOpenAnim:Play();
end 			

header:ClearAllPoints()
header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -300)
header:EnableMouse(false)

SmallFrame.header = header

SmallFrame.collapseHeader = CreateFrame("Frame", nil, UIParent, "HeaderMenuTemplate")
SmallFrame.collapseHeader:SetPoint("TOPRIGHT", SmallFrame.Frame, "TOPRIGHT", -10, -11)
SmallFrame.collapseHeader:Show()
SmallFrame.collapseHeader:EnableMouse(true)
SmallFrame.collapseHeader:SetWidth(100)
SmallFrame.collapseHeader:SetHeight(20)

SmallFrame.collapseHeader:HookScript("OnMouseDown", function()
	SmallFrame.OnDragStart()
end)

SmallFrame.collapseHeader:HookScript("OnMouseUp", function()
	SmallFrame.OnDragStop()
end)

------------- OBJECTIVE FRAME BACKGROUND ----------------

SmallFrame.ObjectiveFrameDugiBkg = ObjectiveFrameDugiBkg


function SmallFrame.UpdateSmallFrameHeader()
	if SmallFrame.collapsed then
		SmallFrame.OnHeader_Collapse();
	else
		SmallFrame.OnHeader_Expand();
	end
	
	if not DGV.shouldUpdateObjectiveTracker 
	or ObjectiveTrackerFrame.HeaderMenu:IsVisible() then
		SmallFrame.collapseHeader:Hide()
	else
		SmallFrame.collapseHeader:Show()
	end
end

function SmallFrame.OnHeader_Collapse()
	SmallFrame.collapseHeader.MinimizeButton:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
	SmallFrame.collapseHeader.MinimizeButton:GetPushedTexture():SetTexCoord(0.5, 1, 0, 0.5)
	SmallFrame.collapseHeader.Title:Show()
end

function SmallFrame.OnHeader_Expand()
	SmallFrame.collapseHeader.MinimizeButton:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
	SmallFrame.collapseHeader.MinimizeButton:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)
	SmallFrame.collapseHeader.Title:Hide()
end

DGV.shouldUpdateObjectiveTracker = false

function SmallFrame:Show()
	if (SmallFrame.Frame:GetWidth() > 5 or DugisGuideViewer.tukuiloaded)  and not IsSmallFrameCollapsed() then
		SmallFrame.Frame:Show()
	end
end

SmallFrame.UpdateSmallFrameHeader()

SmallFrame:Show()
SmallFrame.Frame:Hide()

--sizing constants
local FLOATING_CONTAINER_TOP_PADDING = 24
local FLOATING_CONTAINER_BOTTOM_PADDING = 15
local FLOATING_STATUS_FRAME_TEXT_DESC_PADDING = 7
local FLOATING_STATUS_FRAME_DESC_OBJECTIVES_PADDING = 3
local ANCHORED_CONTAINER_TOP_PADDING = 10
local ANCHORED_CONTAINER_BOTTOM_PADDING = -2
local ANCHORED_STATUS_FRAME_TEXT_DESC_PADDING = 7
local ANCHORED_STATUS_FRAME_DESC_OBJECTIVES_PADDING = 3

local DBMUpdate

function SmallFrame:Initialize()
	if SmallFrame.initialized then return end
	SmallFrame.initialized = true
			
	local L = DugisLocals

	local oldFrameSize = 0
	local oldTextSize = 0 
	local newFrameSize = 0
	local newTextSize = 0
	local flashGroup, flash
    
	local function IsTooltipEmbedded()
		return DGV:UserSetting(DGV_EMBEDDEDTOOLTIP)
	end
	
	local function IsFixedWidth()
		return DGV:UserSetting(DGV_FIXEDWIDTHSMALL)
	end
	
	local function ShowObjectives()
		return DGV:UserSetting(DGV_OBJECTIVECOUNTER)
	end
	
	local function MultistepMode()
		return DGV:UserSetting(DGV_MULTISTEPMODE)
	end
	
	local statusFrames = UIFrameCache:New("FRAME", "DugisSmallFrameStatus", SmallFrame.Frame, "DugisSmallFrameTemplate")
	function SmallFrame.IterateActiveStatusFrames(invariant, control)
		return next(statusFrames.usedFrames, control)
	end
	
	local function ClearAllStatusFrames()
		while #statusFrames.usedFrames>0 do
			local frame = tremove(statusFrames.usedFrames)
			tinsert(statusFrames.frames, 1, frame)
			frame:Hide()
			if frame.ItemButton then  
				DGV.DoOutOfCombat(function()
					frame.ItemButton.Hide(frame.ItemButton)
				end)
			end					
		end
	end
	
	local function StatusFrame_InitPoints(frame)
		frame:ClearAllPoints()
		local index = #statusFrames.usedFrames
		if index==1 then
				frame:SetPoint("TOPLEFT", 0, -FLOATING_CONTAINER_TOP_PADDING - spaceForSmallFrameHeader  )
		else
			frame:SetPoint("TOPLEFT", statusFrames.usedFrames[index-1], "BOTTOMLEFT", 0, -10)
		end
	end
	
	local function StatusFrame_GetCreate()
		local frame = statusFrames:GetFrame()
		frame:SetParent(SmallFrame.Frame)
		if not frame.objectiveLines then
			frame.objectiveLines = UIFrameCache:New("FRAME", frame:GetName().."ObjectiveLine", frame.Objectives, "ObjectiveTrackerLineTemplate")
			frame:RegisterForDrag("LeftButton")
			frame:HookScript("OnDragStart", SmallFrame.OnDragStart)
			frame:HookScript("OnDragStop", SmallFrame.OnDragStop)
		end
		frame:Show()
		StatusFrame_InitPoints(frame)
		return frame
	end
	
	local function StatusFrame_ClearAllObjectiveLines(frame)
		while #frame.objectiveLines.usedFrames>0 do
			local line = tremove(frame.objectiveLines.usedFrames)
			tinsert(frame.objectiveLines.frames, line)
			line:Hide()
		end
		if frame.ItemButton then 
			DGV.DoOutOfCombat(function()
				frame.ItemButton.Hide(frame.ItemButton)
			end)
		end		
	end
	
	local function StatusFrame_Reset(frame)
		frame:Hide()
		frame.guideIndex = nil
		StatusFrame_ClearAllObjectiveLines(frame)
	end
	
	function StatusFrame_GetNonTextWidth(frame)
		local _, _, _, xOfs, yOfs = frame.Text:GetPoint(2)
		local modelButtonWidth
		
		if (frame.guideIndex == DugisGuideUser.CurrentQuestIndex) and DGV:HasModel(frame.guideIndex ) then modelButtonWidth = frame.ModelButton:GetWidth( ) + 9 else modelButtonWidth = 7 end
		return xOfs + modelButtonWidth
	end
	
	function StatusFrame_GetSmartWidth(frame)
		local _, _, _, xOfs, yOfs = frame.Chk:GetPoint()
		local modelButtonWidth
		frame:SetHeight(1000)
		frame:SetWidth(1000)
		if (frame.guideIndex == DugisGuideUser.CurrentQuestIndex) and DGV:HasModel(frame.guideIndex) then modelButtonWidth = frame.ModelButton:GetWidth( ) else modelButtonWidth = 7 end
		local textWidth = frame.Text:GetStringWidth() + 13
		local descWidth = math.min(frame.Desc:GetStringWidth() + 26, 300)
		local width = textWidth + frame.Waypoint:GetWidth() + frame.Icon:GetWidth() + frame.Chk:GetWidth() + modelButtonWidth + xOfs
		return math.max(width, descWidth), textWidth
	end

	local function StatusFrame_GetDesiredWidth(frame)
		local width
		if not DGV:IsSmallFrameFloating() then
			width = SmallFrame.Frame:GetWidth()
		elseif IsFixedWidth() then
			width = OBJECTIVE_TRACKER_LINE_WIDTH + 40
		else
			return StatusFrame_GetSmartWidth(frame)
		end
		return width, width - StatusFrame_GetNonTextWidth(frame)
	end
	
	local function StatusFrame_GetObjectivesHeight(frame)
		local count = 0
		for _,line in ipairs(frame.objectiveLines.usedFrames) do
			count = count + line:GetHeight()
		end
		if count>0 and frame.ItemButton then
			return math.max(count, (WATCHFRAME_ITEM_WIDTH-5))
		elseif count>0 then 
			return math.max(count, 15) --mininum objective height
		else
			return count
		end
	end
	
	local function StatusFrame_MeasureHeight(frame)
		if not DGV:IsSmallFrameFloating() then
			local hasObjectives = #frame.objectiveLines.usedFrames>0
            local height = frame.Text:GetStringHeight() +
				(IsTooltipEmbedded() and ANCHORED_STATUS_FRAME_TEXT_DESC_PADDING or 2) +
				frame.Desc:GetStringHeight() +
				(hasObjectives and ANCHORED_STATUS_FRAME_DESC_OBJECTIVES_PADDING or 0) +
				StatusFrame_GetObjectivesHeight(frame)
            
            local extraHeight = 0
            
            if not IsTooltipEmbedded() and not ShowObjectives() then
                extraHeight = 10
            end
            
			return height + extraHeight
		else
			local hasObjectives = #frame.objectiveLines.usedFrames>0
            local height = frame.Text:GetStringHeight() +
				(IsTooltipEmbedded() and FLOATING_STATUS_FRAME_TEXT_DESC_PADDING or 2) +
				frame.Desc:GetStringHeight() +
				(hasObjectives and FLOATING_STATUS_FRAME_DESC_OBJECTIVES_PADDING or 0) +
				StatusFrame_GetObjectivesHeight(frame)
            
			return height
				
		end
	end
	
	local function StatusFrame_GetCreateObjectiveLine (frame)
		local line = frame.objectiveLines:GetFrame()
		--line:Reset()
		line:Show()
		line:ClearAllPoints()
		return line
	end
	
	local function StatusFrame_SetCurrentWidth(frame, frameWidth, textWidth)
		frame:SetWidth(frameWidth)
		if textWidth then
			frame.Text:SetWidth(textWidth)
			frame.Objectives:SetWidth(frame.Objectives:GetWidth())
			frame.Desc:SetWidth(frame.Desc:GetWidth()) --so GetStringHeight works properly
			if frame.DescEventHandler then
				frame.DescEventHandler:SetWidth(frame.Desc:GetWidth()) --so GetStringHeight works properly
			end
		end
	end
	

	local function UpdateFontSize(frame)
		local DGV_SmallFrameFontSize = DGV:GetDB(DGV_SMALLFRAMEFONTSIZE)
		local filename, _, _ = frame.Text:GetFont() -- needed so that it doesn't overwrite font style when using other addons. 
		frame.Desc:SetFont(filename, DGV_SmallFrameFontSize - 1)
		frame.DescEventHandler:SetFont(filename, DGV_SmallFrameFontSize - 1)
		frame.Text:SetFont(filename, DGV_SmallFrameFontSize)

		if frame.objectiveLines and frame.objectiveLines.usedFrames then
			for _, line in ipairs(frame.objectiveLines.usedFrames) do
				line.Text:SetFont(filename, DGV_SmallFrameFontSize)
			end
		end
	end
	
	
	local function StatusFrame_Layout(frame)
		if not DGV:IsSmallFrameFloating() then
			--setcharacteristics
			frame.Text:SetMaxLines(3)
			frame.Text:SetWordWrap(true)
			frame.Text:SetNonSpaceWrap(true)


		 
			UpdateFontSize(frame)

			--get desired width
			oldFrameSize, oldTextSize  = StatusFrame_GetDesiredWidth(frame)
			newFrameSize, newTextSize = oldFrameSize, oldTextSize
			
			--set desired width
			StatusFrame_SetCurrentWidth(frame, newFrameSize, newTextSize)

			--set padding values
			frame.Desc:SetPoint("TOP", frame.Text, "BOTTOM", 0, -ANCHORED_STATUS_FRAME_TEXT_DESC_PADDING)
			frame.DescEventHandler:SetPoint("TOP", frame.Text, "BOTTOM", 0, -ANCHORED_STATUS_FRAME_TEXT_DESC_PADDING)
			
			--measure height
			--set height
			frame:SetHeight(StatusFrame_MeasureHeight(frame))
		else
			if IsFixedWidth() then
				--setcharacteristics
				frame.Text:SetMaxLines(2)
				frame.Text:SetWordWrap(true)
				frame.Text:SetNonSpaceWrap(true)
				
				--get desired width
				oldFrameSize, oldTextSize = StatusFrame_GetDesiredWidth(frame)
				newFrameSize, newTextSize = oldFrameSize, oldTextSize
				
				--set desired width
				StatusFrame_SetCurrentWidth(frame, newFrameSize, newTextSize)
			else
				--setcharacteristics
				frame.Text:SetMaxLines(0)
				frame.Text:SetWordWrap(false)
				frame.Text:SetNonSpaceWrap(false)
				
				--get desired width
				StatusFrame_SetCurrentWidth(frame, StatusFrame_GetDesiredWidth(frame))
			end
			
			--set padding values
			frame.Desc:SetPoint("TOP", frame.Text, "BOTTOM", 0, -FLOATING_STATUS_FRAME_TEXT_DESC_PADDING)
			frame.DescEventHandler:SetPoint("TOP", frame.Text, "BOTTOM", 0, -FLOATING_STATUS_FRAME_TEXT_DESC_PADDING)
			
			--measure height
			--set height
			frame:SetHeight(StatusFrame_MeasureHeight(frame))
		end
		
		frame.Desc:SetJustifyH("LEFT")
		frame.DescEventHandler:SetJustifyH("LEFT")
		
	end
	
	local function StatusFrame_GetDescriptionText(frame)
		local name = "DGVRow"..frame.guideIndex.."Desc"
		local text = _G[name]
		
        --Removed lua error
		if not text then
			return "", ""
		end
		
		local descriptionText = text:GetText()
        local rawText = descriptionText
		
			
		if descriptionText and not string.match(descriptionText, "|Hitem") and string.match(descriptionText, "item:%d") then --ReplaceSpecialTags for items if it didn't get converted yet on load. 
			if DGV.NPCJournalFrame then 
				descriptionText = DGV.NPCJournalFrame:ReplaceSpecialTags(descriptionText, true)
			end
		end
		
		return descriptionText, rawText
	end

	local function SetTextColorAndIntensity(fontString, color, highlight, forceDim)
		fontString:SetTextColor(color.r, color.g, color.b)
		if highlight or (not DGV:UserSetting(DGV_HIGHLIGHTSTEPONENTER) and not forceDim) then
			fontString:SetAlpha(1)
		else
			fontString:SetAlpha(0.8)
		end
	end	
	
	local function SetTextColors(frame, onEnter)
		local guideIndex = frame.guideIndex
		if guideIndex and DGV.actions[guideIndex] then
			local level = DGV:GetQuestLevel(DGV.qid[guideIndex])
			local questpart = DGV:ReturnTag("QIDP", guideIndex)
			if IsTooltipEmbedded() then
				SetTextColorAndIntensity(frame.Desc, HIGHLIGHT_FONT_COLOR, onEnter)
			end
			local color  = DGV:GetQuestDiffColor(guideIndex)

			if not (
			(strmatch(DGV.actions[guideIndex], "[ACT]") and color and DGV:UserSetting(DGV_QUESTCOLORON)) or (questpart and color and strmatch(DGV.actions[guideIndex], "[NK]") and DGV:UserSetting(DGV_QUESTCOLORON)) 	--set difficulty color on A/C/T actions
			)	
			then
				color = NORMAL_FONT_COLOR
			end
			SetTextColorAndIntensity(frame.Text, color, onEnter)
			if frame.objectiveLines and frame.objectiveLines.usedFrames then
				for _, line in ipairs(frame.objectiveLines.usedFrames) do
					SetTextColorAndIntensity(line.Text, HIGHLIGHT_FONT_COLOR, onEnter, true)
				end
			end
		else 
			SetTextColorAndIntensity(frame.Text, NORMAL_FONT_COLOR, onEnter)
		end
	end
	
	local function SetPointAbsolute(region, point, relativeRegion, relativeRegionAbsoluteX, relativeRegionAbsoluteY, offsetX, offsetY)
		local absoluteY = relativeRegionAbsoluteY and relativeRegionAbsoluteY + offsetY
		local absoluteX = relativeRegionAbsoluteX and relativeRegionAbsoluteX + offsetX
		region:ClearAllPoints()
		region:SetScale(relativeRegion:GetEffectiveScale())
		if DGV:IsSmallFrameFloating() then
			region:SetPoint(point, UIParent, "BOTTOMLEFT", absoluteX - 4, absoluteY)
		else
			region:SetPoint(point, UIParent, "BOTTOMLEFT", absoluteX, absoluteY)
		end
		region:SetFrameStrata(relativeRegion:GetFrameStrata())
		region:SetFrameLevel(relativeRegion:GetFrameLevel())
	end
	
	local function MoveItemButtonPredicate(reaction, frame)
		local val = frame:IsShown() and frame.ItemButton and frame.ItemButton:IsShown()
		if not val then
			reaction:Dispose()
			frame.moveItemButtonReaction = nil
			return
		end
		return true
	end
	
	local function MoveItemButton(reaction, frame)
		if InCombatLockdown() then return end
		SetPointAbsolute(frame.ItemButton, "TOPRIGHT", frame.Objectives, frame.Objectives:GetRight(), frame.Objectives:GetTop(), 10, -2)
	end
	
	local function SetObjectiveItem(frame, questIndex)
		local itemButton = frame.ItemButton
		if ( not itemButton ) then
			itemButton = CreateFrame("BUTTON", frame:GetName().."Item", nil, "DugisSecureQuestButtonTemplate");
		end
		
		DGV.DoOutOfCombat(function()
			DGV.SetQuestItemButtonAttributes(itemButton, questIndex)	
		end)
		
		if not frame.moveItemButtonReaction then
			frame.moveItemButtonReaction = DGV.RegisterStopwatchReaction(.1, MoveItemButtonPredicate, MoveItemButton, frame)
		end
		frame.ItemButton = itemButton;
		
		DGV.DoOutOfCombat(function()
			itemButton:Show()
		end)
	end
	
	local function StatusFrame_Populate(frame, guideIndex)
		frame.guideIndex = guideIndex
		frame.Chk:SetChecked(false)
		if guideIndex and DGV.actions[guideIndex] then
			local level = DGV:GetQuestLevel(DGV.qid[guideIndex])
			local qName = DGV.quests1L[guideIndex]
			local questpart = DGV:ReturnTag("QIDP", guideIndex)
			
			if (level and level > 0 and strmatch(DGV.actions[guideIndex], "[ACT]") and DGV:UserSetting(DGV_QUESTLEVELON)) or (level and level > 0 and questpart and strmatch(DGV.actions[guideIndex], "[NK]") and DGV:UserSetting(DGV_QUESTLEVELON)) then qName = "["..level.."] "..qName end

			qName = DGV.NPCJournalFrame:ReplaceSpecialTags(qName, true, guideIndex, true)
			
            --Removed lua error
			if DGV.visualRows then
				local row = DGV.visualRows[guideIndex]
				if row and row.Button and frame.Icon then
					frame.Icon:SetNormalTexture(row.Button.validTexture)	
				end
			end
		
			frame.Icon:SetSize(22, 22)
			frame.Icon:SetPoint("RIGHT", frame.Text, "LEFT", -2.5, 0)

			frame.Text:SetText(qName)
			frame.Text:SetPoint("LEFT", 65, 0)
			if IsTooltipEmbedded() then
                local text, rawText = StatusFrame_GetDescriptionText(frame)
				frame.Desc:SetText(text)
                frame.Desc.rawText = rawText
				frame.DescEventHandler:SetText(text)
                frame.DescEventHandler:SetTextColor(1, 0, 0)
                frame.DescEventHandler:SetAlpha(0)
				frame.Desc:Show()		
				frame.DescEventHandler:Show()           
			else
				frame.Desc:SetText("")
				frame.DescEventHandler:SetText("")
				frame.Desc:Hide()
				frame.DescEventHandler:Hide()
			end
            
            if not frame.Desc.isHtml then
                frame.Desc:Hide()
                frame.DescEventHandler:Hide()
            end
            
            if frame.htmlDesc == nil then
                frame.htmlDesc = CreateFrame("SimpleHTML",nil, frame)
                
                frame.htmlDesc:EnableMouse(false)  
                frame.htmlDesc:SetHyperlinksEnabled(false) 

                frame.htmlDesc:SetFontObject(frame.Desc:GetFontObject())
                frame.htmlDesc:SetWidth(222)
                frame.htmlDesc:SetHeight(50)
  
                local text = frame.Desc:GetText()
                
                if text == nil then
                    text = ""
                end
                
                frame.htmlDesc:SetText('<html><body><p align="left">'..text..'<br/><br/></p></body></html>')     
                frame.htmlDesc.rawText = frame.Desc.rawText
                frame.htmlDesc:Show()   

                frame.htmlDesc:SetScript("OnHyperlinkClick", DugisGuideViewer.NPCJournalFrame.OnHyperlinkClick) 
                frame.htmlDesc:SetScript("OnHyperlinkEnter", function(self, linkData, link, button)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkEnter(self, linkData, link, button, true)
                end) 
                frame.htmlDesc:SetScript("OnHyperlinkLeave", DugisGuideViewer.NPCJournalFrame.OnHyperlinkLeave) 
                
                frame.htmlDescEventHandler = CreateFrame("SimpleHTML",nil, frame)

                frame.htmlDescEventHandler:SetFontObject(frame.Desc:GetFontObject())
                frame.htmlDescEventHandler:SetWidth(222)
                frame.htmlDescEventHandler:SetHeight(50)
                
                local text = frame.Desc:GetText()
                
                if text == nil then
                    text = ""
                end
                
                frame.htmlDescEventHandler:SetText('<html><body><p align="left">'..text..'<br/><br/></p></body></html>')     
                frame.htmlDescEventHandler:Show()   

                frame.htmlDescEventHandler:SetScript("OnHyperlinkClick", function(...)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkClick(...)
                end) 
                
                frame.htmlDescEventHandler:SetScript("OnHyperlinkEnter", function(self, linkData, link, button)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkEnter(self, linkData, link, button, true)
                    UpdateSmallFrameBlocksContent()
                end)     
                
                frame.htmlDescEventHandler:SetScript("OnHyperlinkLeave", function(...)
                    DugisGuideViewer.NPCJournalFrame.OnHyperlinkLeave(...)
                    UpdateSmallFrameBlocksContent()
                end) 
                
                frame.DescEventHandler = frame.htmlDescEventHandler
                frame.DescEventHandler.isHtml = true
                
                frame.Desc = frame.htmlDesc
                frame.Desc.isHtml = true
                
                frame.Desc.GetStringHeight = function()
                    local height = frame.htmlDesc:GetContentHeight()
                    if height ~= nil and height < 10 then
                        height = 10
                    end					
                    return height
                end
                
                frame.Desc.GetStringWidth = function()
                    return frame.htmlDesc:GetWidth()
                end                
             end
			 
			frame.htmlDesc:ClearAllPoints()
			frame.htmlDesc:SetPoint("LEFT", frame, "LEFT", 16, 0)    
			frame.htmlDesc:SetPoint("TOP", frame.Text, "BOTTOM", 0, -8)    
			frame.htmlDesc:SetPoint("RIGHT", frame, "RIGHT", -16, 0)  
			
			frame.htmlDescEventHandler:ClearAllPoints()
			frame.htmlDescEventHandler:SetPoint("LEFT", frame, "LEFT", 16, 0)    
			frame.htmlDescEventHandler:SetPoint("TOP", frame.Text, "BOTTOM", 0, -8)    
			frame.htmlDescEventHandler:SetPoint("RIGHT", frame, "RIGHT", -16, 0)  
			 
			
			local havePOIwaypoint
			local qid = DGV.qid[guideIndex]
			
			if DGV:ReturnTag("POI", guideIndex) and qid then 
				local _, posX, posY, objective = QuestPOIGetIconInfo(qid)
				if posX then 
					havePOIwaypoint = true
				end
			end
			
			if DGV:HasCoord(guideIndex) or havePOIwaypoint then 
				frame.Waypoint:Enable()
				frame.Waypoint:Show()
				frame.Text:SetPoint("LEFT", 65, 0)
				frame.Chk:SetPoint("RIGHT", frame.Waypoint, "LEFT", 5, 0)				
			else 
				frame.Waypoint:Disable() 
				frame.Waypoint:Hide()
				frame.Text:SetPoint("LEFT", 51, 0)
				frame.Chk:SetPoint("RIGHT", frame.Icon, "LEFT", 0, 0)
			end
			if (guideIndex == DugisGuideUser.CurrentQuestIndex) and DGV:HasModel(guideIndex) then frame.ModelButton:Show() else frame.ModelButton:Hide() end
			if DGV:ReturnTag("NT") then 
				frame.Chk:Disable()
				frame.Chk:Hide()
			else 
				frame.Chk:Enable()
				frame.Chk:Show()
			end
			

			SetTextColors(frame)
			
			StatusFrame_ClearAllObjectiveLines(frame)
			local lastLine

			if qid and ShowObjectives() and strmatch(DGV.actions[guideIndex], "[CNKT]") and not DGV:ReturnTag("V", guideIndex) and (DGV:getIcon(DGV.actions[guideIndex], guideIndex) ~= "Interface\\Minimap\\TRACKING\\Profession" or DGV:ReturnTag("AYG", guideIndex)) and not DugisGuideUser.shownObjectives[qid] then
				DugisGuideUser.shownObjectives[qid] = true -- prevents repeat display of the same objectives
				if strmatch(DGV.actions[guideIndex], "[CNK]") then
					local questIndex = GetQuestLogIndexByID(DGV.qid[guideIndex])
					local _, _, _, _, _, isComplete, isDaily, questID, startEvent = GetQuestLogTitle(questIndex);
					local questWatched = IsQuestWatched(questIndex)
					
					local questFailed = false;
					local numObjectives = GetNumQuestLeaderBoards(questIndex);
					if ( isComplete and isComplete < 0 ) then
						isComplete = false;
						questFailed = true;
					elseif ( numObjectives == 0 and not startEvent ) then
						isComplete = true;      
					end		
					
					if not isComplete and not questFailed then
						local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questIndex);
						local y = 0
						for i = 1, numObjectives do
							local text, objectiveType, finished = GetQuestLogLeaderBoard(i, questIndex)
							if (text ) then

								--text = ReverseQuestObjective(text, objectiveType) 
								local line = StatusFrame_GetCreateObjectiveLine(frame)
								--Blizzard random WatchFrame_SetLine bug fix (hopefully) 
								
								if finished then
									line.Dash:SetText("|TInterface\\Scenarios\\ScenarioIcon-Check:16:16:-2|t")
								else
									line.Dash:SetText("- ")
								end
								
								line.Text:SetText(text)
								
								if not WATCHFRAME_SETLINES_NUMLINES then WATCHFRAME_SETLINES_NUMLINES = 0 end							
								--WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, false, text, 1);
							
								local itemWidth = 0
								if item then
									itemWidth = WATCHFRAME_ITEM_WIDTH;
								end
								
								local DGV_SmallFrameFontSize = DGV:GetDB(DGV_SMALLFRAMEFONTSIZE)
								local filename, _, _ = line.Text:GetFont()
								line.Text:SetFont(filename, DGV_SmallFrameFontSize)

								line.Text:SetWidth(line:GetWidth()-line.Dash:GetWidth()-itemWidth)
								local lineHeight = line.Text:GetStringHeight()+WATCHFRAMELINES_FONTSPACING+3
								line:SetHeight(lineHeight)

								--if not lastLine then
								line:SetPoint("RIGHT")

								if finished then
									line:SetPoint("LEFT", -8, 0)
								else
									line:SetPoint("LEFT", 0, 0)
								end
							
								line:SetPoint("TOP", WATCHFRAMELINES_FONTSPACING, -(y))
								--end 
	   
								y = y + lineHeight                            

								lastLine = line
							end
						end
						
						if ( item and (not isComplete or showItemWhenComplete) ) then
							SetObjectiveItem(frame, questIndex)
						end
					end
				end
			end
			frame.Objectives:SetHeight(StatusFrame_GetObjectivesHeight(frame))
		end
		
		if DugisGuideViewer.tukuiloaded then
			local point, _, relativePoint, xOffset, yOffset = DugisSmallFrame:GetPoint(1); 
			if xOffset == 0 and yOffset == 0 and point == "BOTTOMRIGHT" and relativePoint == "BOTTOMRIGHT" then
				DugisGuideViewer.Modules.SmallFrame:Reset()
			end
		end
		
	end
    
    function UpdateSmallFrameBlocksContent()
        local blocks = {DugisSmallFrameContainer:GetChildren()}
        
        LuaUtils:foreach(blocks, function(frame)
            if frame.Desc and frame.Desc.rawText then
                local text = DGV.NPCJournalFrame:ReplaceSpecialTags(frame.Desc.rawText, true)
				if text then 
					--Changing color
					text = string.gsub(text, '(|Hguide:)([^|]*:)([0-9]*)(|h|c)(........)([^|]*|r|h)', function(a, b, uniqueID, c, color, d) 
						if DGV.NPCJournalFrame.hoveredGuideLinkId == uniqueID then
							color = "ffffffff"
						else
							color = "ff44ff44"
						end
						
						return a..b..uniqueID..c..color..d
					end) 
					
					frame.Desc:SetText(text)
				end 
            end
        end)
    end
	
	function SmallFrame:Reset()
		if DGV:IsSmallFrameFloating()	then
			SmallFrame.Frame:ClearAllPoints()	
		end
		SmallFrame:ResetFloating()
	end

	local function UnsnapFromWatchFrame()
	
	end

	function SmallFrame:ResetFloating()
		if DGV:IsSmallFrameFloating() or
			not DugisGuideViewer:GuideOn()
		then
			--UnsnapFromWatchFrame()
			
			--loop and layout
			oldFrameSize, oldTextSize = newFrameSize, newTextSize
			local maxWidth, maxTextWidth = 0,0
			for _,frame in SmallFrame.IterateActiveStatusFrames do
				StatusFrame_Layout(frame)
				maxWidth = math.max(maxWidth, frame:GetWidth())
				maxTextWidth = math.max(maxTextWidth, frame.Text:GetStringWidth())
			end
			for _,frame in SmallFrame.IterateActiveStatusFrames do
				StatusFrame_SetCurrentWidth(frame, maxWidth)
			end
			SmallFrame.Frame:SetWidth(maxWidth - 2)
			newFrameSize, newTextSize = maxWidth, maxTextWidth
			if #statusFrames.usedFrames>0 and statusFrames.usedFrames[#statusFrames.usedFrames]:GetBottom() then --GetBottom() nil check needed to stop messy error during petbattle
				--todo: check why this is duplicated
				SmallFrame.Frame:SetHeight(
					statusFrames.usedFrames[1]:GetTop() -
					statusFrames.usedFrames[#statusFrames.usedFrames]:GetBottom() +
					FLOATING_CONTAINER_BOTTOM_PADDING +
					FLOATING_CONTAINER_TOP_PADDING 
					
					+ 30 + spaceForSmallFrameHeader)
			end
			
			DugisGuideViewer:SetSmallFrameBorder()
		else
		end
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	end

	--[[
	local function PLAYER_REGEN_ENABLED(self)
		
			
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
	--]]

	function SmallFrame:OnClick(self, button)
		name = self:GetName()
		
		if button == "RightButton" then
			if DugisMainBorder:IsVisible() then
				DugisGuideViewer:HideLargeWindow()
			else
				--UIFrameFadeIn(DugisMainframe, 0.5, 0, 1)
				--UIFrameFadeIn(Dugis, 0.5, 0, 1)
				DugisGuideViewer:ShowLargeWindow()
			end
		elseif button == "LeftButton" and IsShiftKeyDown() then
			local row = _G["DGVRow"..self.guideIndex]
			DugisGuideViewer.Modules.StickyFrame:AddRow(row)
		elseif button == "LeftButton" and DGV.actions and DGV.actions[self.guideIndex] and strmatch(DGV.actions[self.guideIndex], "[CNKT]") then 
			local qid = DGV.qid[self.guideIndex]
			if qid then
				local questIndex = GetQuestLogIndexByID(qid)
				if questIndex > 0 then 
					QuestLogPopupDetailFrame_Show( questIndex );
				end
			end
		end
	end
	
	--Called possibly in combat
	local populateSmallFrameFirstTime = true
	function SmallFrame:PopulateSmallFrame()
		if not DGV:isValidGuide(CurrentTitle) then
			if not CurrentTitle and #statusFrames.usedFrames==1 then
				StatusFrame_InitPoints(statusFrames.usedFrames[1])
			end
			return
		end
		
		local checkmoved = DugisGuideUser.NextQuestIndex -- check if NextQuestIndex has changed
		
		ClearAllStatusFrames()
 		if MultistepMode() and not DGV:ReturnTag("NT", DugisGuideUser.CurrentQuestIndex) then
 			local maxstep = 0
			local total = math.ceil(DugisGuideViewer:GetDB(DGV_SMALLFRAME_STEPS) - 0.5) or 6
			
			if DGV:ReturnTag("SID", DugisGuideUser.CurrentQuestIndex) or DGV:ReturnTag("SID", DugisGuideUser.CurrentQuestIndex + 1 ) then 
				total = 2
			end
			
 			for guideIndex in DGV.IterateRelevantSteps do				
 				maxstep = maxstep + 1
 				if maxstep <= total then 
 					StatusFrame_Populate(StatusFrame_GetCreate(), guideIndex)
 				end
				if maxstep == 2 and not DGV:ReturnTag("AYG", guideIndex) then 
					DugisGuideUser.NextQuestIndex = guideIndex
				elseif DGV:ReturnTag("AYG", DugisGuideUser.CurrentQuestIndex + 1) then 
					DugisGuideUser.NextQuestIndex = DugisGuideUser.CurrentQuestIndex
				end
			end
		elseif DGV:ReturnTag("AYG", DugisGuideUser.CurrentQuestIndex) and not DGV:ReturnTag("NT", DugisGuideUser.CurrentQuestIndex) then -- AYG to make As you go step stick. 
			local maxstep = 0
			for guideIndex in DGV.IterateRelevantSteps do				
				maxstep = maxstep + 1
				if maxstep <= 2 then 
					StatusFrame_Populate(StatusFrame_GetCreate(), guideIndex)
				end
				if maxstep == 2 and not DGV:ReturnTag("AYG", guideIndex) then 
					DugisGuideUser.NextQuestIndex = guideIndex
				elseif DGV:ReturnTag("AYG", DugisGuideUser.CurrentQuestIndex + 1) then
					DugisGuideUser.NextQuestIndex = DugisGuideUser.CurrentQuestIndex
				end
 			end
 		else
 			StatusFrame_Populate(StatusFrame_GetCreate(), DugisGuideUser.CurrentQuestIndex)
 		end	
		
		if populateSmallFrameFirstTime then
			populateSmallFrameFirstTime = false
			DugisGuideViewer.UpdateSmallFrame()
			SmallFrame:AlignToTop()
		end
	end
	
	function SmallFrame:CheckButton_OnEvent(self, event)
		local guideIndex = self:GetParent().guideIndex
		if DugisGuideUser.CurrentQuestIndex then --If a guide is loaded
			if DGV:ReturnTag("NT", guideIndex) then
				self.Chk:SetChecked(false)
			elseif guideIndex==DugisGuideUser.CurrentQuestIndex and guideIndex == DGV:GetLastGuideNumRows() then--LastGuideNumRows then
				--self.Chk:SetChecked(false)
				DugisGuideViewer:LoadNextGuide()
			else
				DugisGuideViewer:SetChkToComplete(guideIndex)
				if guideIndex then
					DGV.DelayandMoveToNextQuest(0.2)
				end
			end
		end
	end

	local autoTooltipFadeTime = math.huge
	local function ResetAutoTooltip()
		if SmallFrameTooltip then SmallFrameTooltip:SetAlpha(1) end
		autoTooltipFadeTime = math.huge
	end

	local function UpdateAutoTooltip()
		local toEnd = autoTooltipFadeTime-GetTime()
		if toEnd <= 0 then 
			SmallFrameTooltip:Hide()
			ResetAutoTooltip()
		elseif toEnd <= 3 then 
			SmallFrameTooltip:SetAlpha(toEnd/3) 
		end
	end

	local tooltip = CreateFrame( "GameTooltip", "SmallFrameTooltip", nil, "GameTooltipTemplate" ); 
	function SetTooltipOnUpdate(self, event)
		if 
			DugisGuideViewer:isValidGuide(CurrentTitle) == true and 
			DugisGuideUser.CurrentQuestIndex and
			not IsTooltipEmbedded()
		then

			local statusFrameTooltipText = StatusFrame_GetDescriptionText(self)
			local filename, _, _ = SmallFrameTooltipTextLeft1:GetFont() -- needed so that it doesn't overwrite font style when using other addons. 
			
			tooltip:SetOwner(self)
			tooltip:SetFrameStrata("TOOLTIP") 
			tooltip:SetParent(UIParent)
			SmallFrameTooltipTextLeft1:SetFont(filename, 12)
			tooltip:SetPadding(5, 5)
			tooltip:AddLine(statusFrameTooltipText, 1, 1, 1, 1,true)
			tooltip:Show()

			local ttwidth, ttheight, fwidth, fheight, pad = DugisGuideViewer:GetToolTipSize(tooltip)

			tooltip:ClearAllPoints()
			local anchorPoint = strupper(DugisGuideViewer:GetDB(DGV_TOOLTIPANCHOR)):gsub("%s", "")
			if anchorPoint=="DEFAULT" and DGV:IsSmallFrameFloating() then
				anchorPoint = "LEFT"
			elseif anchorPoint=="DEFAULT" then
				anchorPoint = "LEFT"
			end
			
			local toolAnchorPoint 	= ""
			toolAnchorPoint = toolAnchorPoint..((anchorPoint:find("BOTTOM.*") and "TOP") or "")
			toolAnchorPoint	= toolAnchorPoint..((anchorPoint:find("TOP.*") and "BOTTOM") or "")
			toolAnchorPoint = toolAnchorPoint..((anchorPoint:find("^RIGHT") and "LEFT") or "")
			toolAnchorPoint = toolAnchorPoint..((anchorPoint:find("^LEFT") and "RIGHT") or "")
			toolAnchorPoint = toolAnchorPoint..((anchorPoint:find(".+LEFT") and "LEFT") or "")
			toolAnchorPoint = toolAnchorPoint..((anchorPoint:find(".+RIGHT") and "RIGHT") or "")
			
			
			ResetAutoTooltip()
		end
	end
	
	function SmallFrame:OnEnter(self, event)
		SetTooltipOnUpdate(self, event)
		SetTextColors(self, true)
	end
	
	function SmallFrame:OnLeave(self, event)
		DGV:ShowAutoTooltip(self)
		SetTextColors(self)
	end
	
	function SmallFrame:AlignToTop()
		local x, y = GUIUtils:GetRealFeamePos(DugisSmallFrame)
		DugisSmallFrame:ClearAllPoints()
		DugisSmallFrame:SetPoint("TOPLEFT", x, y)
	end	
	
	function SmallFrame:OnDragStart()
		if (DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME) and not DugisGuideViewer:UserSetting(DGV_DISABLEWATCHFRAMEMOD)) or DGV:IsSmallFrameFloating() then
			SmallFrame.Frame:StartMoving()
			SmallFrame.Frame.isMoving = true
		end
	end

	function SmallFrame:OnDragStop()
		SmallFrame.Frame:StopMovingOrSizing();
		SmallFrame.Frame.isMoving = false;
		SmallFrame:AlignToTop()
	end	
	
	SmallFrame.Frame:HookScript("OnMouseDown", SmallFrame.OnDragStart)
	SmallFrame.Frame:HookScript("OnMouseUp", SmallFrame.OnDragStop)
	
	function DugisGuideViewer:ShowAutoTooltip(frame)
		frame = frame or DugisSmallFrameStatus1
		if not frame then return end
		--if 1 then return end
		if DugisGuideViewer:GetDB(DGV_SHOWTOOLTIP)==0 or (DGV.actions[frame.guideIndex] and strmatch(DugisGuideViewer.actions[frame.guideIndex], "[CNK]")==nil) or DGV:UserSetting(DGV_EMBEDDEDTOOLTIP) then
			if tooltip then tooltip:Hide() end
			ResetAutoTooltip()
			return 
		end
		SetTooltipOnUpdate(frame)
		autoTooltipFadeTime = GetTime() + DugisGuideViewer:GetDB(DGV_SHOWTOOLTIP) + 3
		--SmallFrameTooltip:Show()
		tooltip:SetScript("OnUpdate", UpdateAutoTooltip)
	end
	
	function SmallFrame:PlayFlashAnimation(headerAnim)
		LuaUtils:Delay(0.1, function()
			--if header.animating then return end -- stop flash animation spam
			if not SmallFrame.FlashFrame then
				wf_flashGroup, _, SmallFrame.FlashFrame = DGV:CreateFlashFrame(SmallFrameBkg)
			end
			
			if DGV:UserSetting(DGV_WATCHFRAMEBORDER) and (DGV:UserSetting(DGV_SMALLFRAMETRANSITION) == L["Flash"] or DGV:UserSetting(DGV_SMALLFRAMETRANSITION) == L["Scroll"]) then				
				if headerAnim == true then 
					header.animating = true;
					header.HeaderOpenAnim:Stop();
					header.HeaderOpenAnim:Play();
				end 
				--DGV:DebugFormat("PlayFlashAnimation showing", "flashGroup", flashGroup)
				SmallFrame.FlashFrame:Show()
				SmallFrame.FlashFrame:SetWidth(SmallFrameBkg:GetWidth() - 14)
				SmallFrame.FlashFrame:SetHeight(SmallFrameBkg:GetHeight() - 17)
				wf_flashGroup:Stop()
				wf_flashGroup:Play()
			else
				SmallFrame.FlashFrame:Hide()
			end
		end)
	end
    
	function SmallFrame.UpdateProgressBarPosition()
		if not SmallFrameProgressBar then
			return
		end
        SmallFrameProgressBar:ClearAllPoints()
        if DGV:IsSmallFrameFloating() then
            SmallFrameProgressBar:SetPoint("TOPLEFT", 123, -21)
        else
			SmallFrameProgressBar:SetPoint("TOPLEFT", 123, -21)
        end
        
        if (DugisGuideViewer:UserSetting(DGV_DISPLAYGUIDESPROGRESS)) 
		and DugisGuideViewer:isValidGuide(CurrentTitle) == true
		and not IsSmallFrameCollapsed() then
            SmallFrameProgressBar:Show()
        else
            SmallFrameProgressBar:Hide()
        end  
        
        if (DugisGuideViewer:UserSetting(DGV_DISPLAYGUIDESPROGRESSTEXT))
		and DugisGuideViewer:isValidGuide(CurrentTitle) == true
		and not IsSmallFrameCollapsed() then
            SmallFrameProgressBarText:Show()
        else
            SmallFrameProgressBarText:Hide()
        end
    end

	local TransitionFont = nil
	SmallFrame.Load = function()
        if _G["SmallFrameProgressBar"] == nil then
            CreateFrame("StatusBar", "SmallFrameProgressBar", SmallFrame.Frame, "DugisProgressBarTemplate")
            
            SmallFrameProgressBar:SetFrameStrata("BACKGROUND")
            SmallFrameProgressBar:SetFrameLevel(14)
            
            SmallFrameProgressBar:SetScript("OnEnter", function()
                if not DugisGuideViewer:UserSetting(DGV_DISPLAYGUIDESPROGRESSTEXT) then
                    SmallFrameProgressBarText:Show()
                end
            end)
                    
            SmallFrameProgressBar:SetScript("OnLeave", function()
                if not DugisGuideViewer:UserSetting(DGV_DISPLAYGUIDESPROGRESSTEXT) then
                    SmallFrameProgressBarText:Hide()
                end
            end)
        end
        
        SmallFrame.UpdateProgressBarPosition()
    
		if SmallFrame.loaded then return end
		SmallFrame.loaded = true

		local smallElapsed = 1.5
		local watchElapsed = -1

		function SmallFrame:StartFrameTransition( )
			if not DugisSmallFrameStatus1 then return end
			--SmallFrame:StartWatchFrameTransition()
			local fontObj = DugisSmallFrameStatus1.Text:GetFontObject()
			local textR, textG, textB = DugisSmallFrameStatus1.Text:GetTextColor()
			smallElapsed = 0
		end
		
		function SmallFrame:Init( )
		end
		
		function SmallFrame:Enable()
			SmallFrame:Show()
			SmallFrameTooltip:Show()
			SmallFrame:ResetFloating()
		end

		function SmallFrame:Disable()
			SmallFrame.Frame:Hide()
			SmallFrameTooltip:Hide()
			SmallFrame:ResetFloating()
		end
		


		function DGV:LoadInitialView(text, texture, desc)
			ClearAllStatusFrames()
			
			local frame = StatusFrame_GetCreate()
			frame.guideIndex = nil
			frame.Chk:SetChecked(false)
			frame.Desc:SetText(desc)
			frame.Desc:SetPoint("LEFT", 42, 0)
			--frame.Desc:Hide()
			frame.Text:SetText(text)
			frame.Text:SetPoint("LEFT", 42, 0)
			frame.Icon:SetNormalTexture(texture)
			frame.Icon:SetSize(28, 28)
			frame.Icon:SetPoint("RIGHT", frame.Text, "LEFT", -1, -8)
			frame.Waypoint:Disable()
			frame.Waypoint:Hide()
			frame.ModelButton:Hide()
			frame.Chk:Disable()
			frame.Chk:Hide()
			frame.Text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
			StatusFrame_ClearAllObjectiveLines(frame)
			frame.Objectives:SetHeight(0)
			if frame.ItemButton then
				frame.ItemButton:Hide()
			end
			
			
			
		end
		
		function DGV:UpdateSmallFrame(headerAnim)
			DugisGuideUser.shownObjectives = {}
			SmallFrame:PopulateSmallFrame( )
			SmallFrame:ResetFloating()
			SmallFrame:PlayFlashAnimation(headerAnim)	

			DugisGuideViewer:ShowAutoTooltip()
            SmallFrame.UpdateProgressBarPosition()
			
			--Updating
			SmallFrame.Frame:RegisterForDrag(nil)
			SmallFrame.Frame:SetBackdrop(nil)
			SmallFrame.Frame:SetWidth(300)
			
			DugisGuideViewer:SetSmallFrameBorder()
			
			--loop and layout
			for _,frame in SmallFrame.IterateActiveStatusFrames do
				StatusFrame_Layout(frame)
			end

			if #statusFrames.usedFrames>0 and statusFrames.usedFrames[#statusFrames.usedFrames]:GetBottom() then --GetBottom() nil check needed to stop messy error during petbattle
				SmallFrame.Frame:SetHeight(
					statusFrames.usedFrames[1]:GetTop()	-	
					statusFrames.usedFrames[#statusFrames.usedFrames]:GetBottom() +
					ANCHORED_CONTAINER_TOP_PADDING +
					ANCHORED_CONTAINER_BOTTOM_PADDING 
					+ 30 + spaceForSmallFrameHeader)
			end
			DugisGuideViewer:WatchQuest()
		end

		function DGV:OnWatchFrameUpdate()
			--if InCombatLockdown() then return end		
			if DGV.Modules.DugisWatchFrame:ShouldModWatchFrame() and
				not ObjectiveTrackerFrame.collapsed and
				not DBMUpdate
			then
				if not DugisGuideUser.PetBattleOn then 
					SmallFrame:Show()
				end
			else
				SmallFrameTooltip:Hide()
				if not DGV:IsSmallFrameFloating() then
					SmallFrame.Frame:Hide()
				end
			end
            
		end
		
		function DGV:OnDBMUpdate()
			if DBM.Options.HideObjectivesFrame and 
			ObjectiveTrackerFrame:IsVisible() and 
			DGV.Modules.DugisWatchFrame:ShouldModWatchFrame() and
			not ObjectiveTrackerFrame.collapsed and 
			DBMUpdate 
			then
				SmallFrame:Show()
				DBMUpdate = false
			elseif DBM.Options.HideObjectivesFrame and 
				not ObjectiveTrackerFrame:IsVisible() 
			then
				SmallFrameTooltip:Hide()
				if not DGV:IsSmallFrameFloating() then
					SmallFrame.Frame:Hide()
					DBMUpdate = true 
				end		
			end
		end
		
		SmallFrame:Init()
		SmallFrame:Enable()
	end
	SmallFrame.Unload = function()
		if not SmallFrame.loaded then return end
		SmallFrame.loaded = false
		--SmallFrame:Reset()
		SmallFrame:Disable()
		SmallFrame.Frame:Hide()
	end
        
    --This preloader is not visible. It just prevents mouse clicks.
    GUIUtils:CreatePreloader("SmallFramePreloader", SmallFrame.Frame)
    SmallFramePreloader:SetFrameStrata("HIGH")
    SmallFramePreloader.Icon:Hide()  
    
	if DugisGuideViewer.Modules.DugisWatchFrame then
		DugisGuideViewer.Modules.DugisWatchFrame:UpdateWatchFrameMovable()
	end
end