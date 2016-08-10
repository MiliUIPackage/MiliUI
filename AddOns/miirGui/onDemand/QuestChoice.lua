local frame = CreateFrame("FRAME");
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_QuestChoice" then
		for i=1,14 do 
			local hideit = select(i,QuestChoiceFrame:GetRegions())
			hideit:SetAlpha(0)
		end
		for i=16,19 do 
			local hideit = select(i,QuestChoiceFrame:GetRegions())
			hideit:SetAlpha(0)
		end
		local bg= select(15,QuestChoiceFrame:GetRegions())
		bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
		local missiontext= select(20,QuestChoiceFrame:GetRegions())
		m_fontify(missiontext,"color")

		local function miirui_QuestChoiceFrame_Update(self)
			local choiceID, questionText, numOptions = GetQuestChoiceInfo();
			self.choiceID = choiceID;
			self.QuestionText:SetText(questionText);
			for i=1, numOptions do
				local option = QuestChoiceFrame["Option"..i];
				m_fontify(option.OptionText,"white")
				option.Artwork:ClearAllPoints()			
				if numOptions == 2 then
					option.Artwork:SetPoint("TOP",option,0,0.5)
				elseif numOptions == 3 then
					option.Artwork:SetPoint("TOP",option,0,0)
				end
			end
		end
		
		hooksecurefunc("QuestChoiceFrame_Update",miirui_QuestChoiceFrame_Update)
			
		local function miirgui_QuestChoiceFrame_ShowRewards(numOptions)
			for i=1, numOptions do
				local rewardFrame = QuestChoiceFrame["Option"..i].Rewards;
				local numItems = select(6,GetQuestChoiceRewardInfo(i))
				if (numItems ~= 0) then
					local itemID = select(1,GetQuestChoiceRewardItem(i, 1))
					if itemID then
						rewardFrame.Item.itemID = itemID;
						rewardFrame.Item:Show();
						rewardFrame.Item.Name:SetText(name)
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
end

frame:SetScript("OnEvent", frame.OnEvent);