local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

ObjectiveTrackerFrame.HeaderMenu.MinimizeButton:ClearAllPoints() 
ObjectiveTrackerFrame.HeaderMenu.MinimizeButton:SetPoint("TOPRIGHT",ObjectiveTrackerFrame.HeaderMenu,"TOPRIGHT",0.5,-4.5)

local function miirgui_SetStringText(_,fontString)
	local r, g, b = fontString:GetTextColor()
	local red = floor(r * 255 ) 
	local green = floor(g * 255 ) 
	local blue = floor(b * 255 ) 
	if red == 203 and green == 203 and blue == 203 then
		m_fontify(fontString,"white")
	elseif  red == 190 and green == 155 and blue == 0 then
		m_fontify(fontString,"color")
	elseif red == 152 and green == 152 and blue == 152 then
		m_fontify(fontString,"green")
	else
	end
end

hooksecurefunc(DEFAULT_OBJECTIVE_TRACKER_MODULE,"SetStringText", miirgui_SetStringText)
	
local function miirgui_OnBlockHeaderEnter(_,block)
	if ( block.HeaderText ) then
		local r, g, b = block.HeaderText:GetTextColor()
		local red = floor(r * 255 ) 
		local green = floor(g * 255 ) 
		local blue = floor(b * 255 ) 
		if red == 254 and green == 208 and blue == 0 then
			m_fontify(block.HeaderText,"highlight")
		end
	end
	for objectiveKey, line in pairs(block.lines) do
		local r, g, b = line.Text:GetTextColor()
		local red = floor(r * 255 ) 
		local green = floor(g * 255 ) 
		local blue = floor(b * 255 ) 
		if red == 254 and green == 254 and blue == 254 then
			m_fontify(line.Text,"white")
		elseif red == 254 and green == 208 and blue == 0 then
			m_fontify(line.Text,"highlight")
		else
		end
	end	
end

hooksecurefunc(DEFAULT_OBJECTIVE_TRACKER_MODULE,"OnBlockHeaderEnter",miirgui_OnBlockHeaderEnter)

local function miirgui_OnBlockHeaderLeave(_,block)	
	if ( block.HeaderText ) then
		local r, g, b = block.HeaderText:GetTextColor()
		local red = floor(r * 255 ) 
		local green = floor(g * 255 ) 
		local blue = floor(b * 255 )
		if red == 190 and green == 155 and blue == 0 then
			m_fontify(block.HeaderText,"color")
		end
	end
	
	for objectiveKey, line in pairs(block.lines) do
		local r, g, b = line.Text:GetTextColor()
		local red = floor(r * 255 ) 
		local green = floor(g * 255 ) 
		local blue = floor(b * 255 ) 	
		if red == 203 and green == 203 and blue == 203 then
			m_fontify(line.Text,"white")
		elseif red == 190 and green == 155 and blue == 0 then
			m_fontify(line.Text,"color")
		else
		end
	end	
end

hooksecurefunc(DEFAULT_OBJECTIVE_TRACKER_MODULE,"OnBlockHeaderLeave",miirgui_OnBlockHeaderLeave)

local function miirgui_ObjectiveTracker_Collapse()
	m_fontify(ObjectiveTrackerFrame.HeaderMenu.Title,"white")
end

hooksecurefunc("ObjectiveTracker_Collapse",miirgui_ObjectiveTracker_Collapse)
		
local function miirgui_AddObjective(self,block,objectiveKey,_,lineType)
	local line = self:GetLine(block, objectiveKey, lineType);
	if ( line.Dash ) then
		m_fontify(line.Dash,"white")
	end
end
		
hooksecurefunc(DEFAULT_OBJECTIVE_TRACKER_MODULE,"AddObjective", miirgui_AddObjective)
	
	
local function miirgui_ProgressBar_SetValue(self)
	self.Bar:ClearAllPoints()
	self.Bar:SetPoint("CENTER",self,22.5,0.5)
	self.Bar.Icon:SetSize(21,21)
	self.Bar.Icon:ClearAllPoints()
	self.Bar.Icon:SetPoint("CENTER",self.Bar,110,0)	
	self.Bar.Label:ClearAllPoints()
	self.Bar.Label:SetPoint("CENTER",self.Bar,0,1)
	m_fontify(self.Bar.Label,"white")
end
	
hooksecurefunc("ScenarioTrackerProgressBar_SetValue",miirgui_ProgressBar_SetValue)
hooksecurefunc("BonusObjectiveTrackerProgressBar_SetValue",miirgui_ProgressBar_SetValue)

local function miirgui_ObjectiveTracker_Update()
	local splash = GetCVar("splashScreenNormal")
	if splash >= "7" then
		local tracker = ObjectiveTrackerFrame
		for i = 1, #tracker.MODULES do
			if ( tracker.MODULES[i].Header ) then
				m_fontify(tracker.MODULES[i].Header.Text,"white")
			end
		end
	end
end

hooksecurefunc("ObjectiveTracker_Update",miirgui_ObjectiveTracker_Update)

local function miirgui_Update()
	for i = 1, GetNumAutoQuestPopUps() do
		local questID = GetAutoQuestPopUp(i);
		if AUTO_QUEST_POPUP_TRACKER_MODULE:GetExistingBlock(questID) then
			local block = AUTO_QUEST_POPUP_TRACKER_MODULE:GetExistingBlock(questID);
			local blockContents = block.ScrollChild;
			m_fontify(blockContents.TopText,"green")
			m_fontify(blockContents.QuestName,"color")
			m_fontify(blockContents.BottomText,"grey")
			if string.find (blockContents.Exclamation:GetTexture(),"AutoQuest") then
			else
				blockContents.Exclamation:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			end
		end
	end	
end

hooksecurefunc(AUTO_QUEST_POPUP_TRACKER_MODULE,"Update",miirgui_Update)

end)