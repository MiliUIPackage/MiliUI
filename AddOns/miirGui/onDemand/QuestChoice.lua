local function skin_Blizzard_QuestChoice()
		for i=1,14 do 
			local hideit = select(i,QuestChoiceFrame:GetRegions())
			hideit:SetAlpha(0)
		end
		for i=16,19 do 
			local hideit = select(i,QuestChoiceFrame:GetRegions())
			hideit:SetAlpha(0)
		end
		local _,_,_,_,_,_,_,_,_,_,_,_,_,_,bg,_,_,_,_,missiontext = QuestChoiceFrame:GetRegions()
		m_SetTexture(bg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
		m_fontify(missiontext,"color")

		local function miirui_QuestChoiceFrame_Update(self)
			local choiceID, questionText, numOptions = GetQuestChoiceInfo();
			self.choiceID = choiceID;
			self.QuestionText:SetText(questionText);
			for i=1, numOptions do
				local option = QuestChoiceFrame["Option"..i];
				m_fontify(option.OptionText,"white")
				m_fontify(option.Header.Text,"white")	
				if numOptions == 2 then
				option.Artwork:ClearAllPoints()
					option.Artwork:SetPoint("TOP",option,0,0.5)
				elseif numOptions == 3 then
					option.Artwork:ClearAllPoints()
					option.Artwork:SetPoint("TOP",option,0,0)
				end
			end
		end
		
		hooksecurefunc("QuestChoiceFrame_Update",miirui_QuestChoiceFrame_Update)
			
		local function miirgui_QuestChoiceFrame_ShowRewards(numOptions)
			for i=1, numOptions do
				local rewardFrame = QuestChoiceFrame["Option"..i].Rewards;
				local _,_,_,_,_,numItems =GetQuestChoiceRewardInfo(i)
				if (numItems ~= 0) then
					local itemID =GetQuestChoiceRewardItem(i, 1)
					if itemID then
						m_fontify(rewardFrame.Item.Name,"white")
					else
						rewardFrame.Item:Hide();
					end
				else
					rewardFrame.Item:Hide();
				end
			end
		end
		
		hooksecurefunc("QuestChoiceFrame_ShowRewards",miirgui_QuestChoiceFrame_ShowRewards)
				
		m_border(QuestChoiceFrame,822,602,"CENTER",0,0,14,"HIGH")
		m_border_QuestChoiceFrame:SetPoint("TOPLEFT",QuestChoiceFrame,16,-16.5)
		m_border_QuestChoiceFrame:SetPoint("BOTTOMRIGHT","QuestChoiceFrame",-16,16.5)
	end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_QuestChoice" then
			skin_Blizzard_QuestChoice()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_QuestChoice") then
		skin_Blizzard_QuestChoice()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)