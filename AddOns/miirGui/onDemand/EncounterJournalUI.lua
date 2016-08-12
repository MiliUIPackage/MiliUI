local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_EncounterJournal"  then
		
		m_fontify(EncounterJournalInstanceSelectTierDropDownText,"white")
		m_fontify(EncounterJournalEncounterFrameInfoDifficulty:GetFontString(),"white")
		m_fontify(EncounterJournalEncounterFrameInfoLootScrollFrameFilterToggle:GetFontString(),"white")
		m_fontify(EncounterJournalEncounterFrameInfoInstanceTitle,"color")
		m_fontify(EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildLoreDescription,"white")
		m_fontify(EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChild.overviewDescription.Text,"white")
		m_fontify(EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle,"color")
		EncounterJournalInstanceSelectRaidTab.grayBox:ClearAllPoints()	
		EncounterJournalInstanceSelectRaidTab.grayBox:SetPoint("CENTER",EncounterJournalInstanceSelectRaidTab,"CENTER",-1,11)
		EncounterJournalInstanceSelectRaidTab.grayBox:SetSize(135,52)
		EncounterJournalSuggestFrame.Suggestion1.bg:Hide()			
		EncounterJournalSuggestFrame.Suggestion2.bg:Hide()			
		EncounterJournalSuggestFrame.Suggestion3.bg:Hide()	
		EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollBarTrack:Hide()
		EncounterJournalPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		EncounterJournalInstanceSelectScrollFrameScrollBarTrack:Hide()
		EncounterJournalInstanceSelectBG:Hide()
		EncounterJournalEncounterFrameInfoDetailsScrollFrameScrollBarTrack:Hide()
		EncounterJournalEncounterFrameInstanceFrameLoreScrollFrameScrollBarTrack:Hide()
		EncounterJournalEncounterFrameInfoBossesScrollFrameScrollBarTrack:Hide()
		EncounterJournalEncounterFrameInfoLootScrollFrameScrollBarTrack:Hide()	
		m_border(EncounterJournalEncounterFrameInstanceFrame,340,266,"CENTER",3,34,12,"MEDIUM")
		m_border(EncounterJournalInstanceSelect,794	,388,"CENTER",1,-22,12,"HIGH")
		m_border(EncounterJournalSuggestFrame.Suggestion1,340,260,"CENTER",3,-28,12,"MEDIUM")
		m_border(EncounterJournalSuggestFrame.Suggestion2,280,130,"CENTER",25,14,12,"MEDIUM")
		m_border(EncounterJournalSuggestFrame.Suggestion3,280,130,"CENTER",25,14,12,"MEDIUM")	
		EncounterJournalInsetBg:Hide()	
		local parchement = select(1,EncounterJournal.LootJournal:GetRegions())
		parchement:Hide()		
		for i = 1, 9 do
			_G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i.."Icon"]:SetSize(40,40)	
			m_fontify(_G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i.."ArmorClass"],"white")
			m_fontify(_G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i.."Slot"],"white")
			m_fontify(_G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i.."Boss"],"white")
			m_fontify(_G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i.."Name"],"white")
		end
		m_fontify(_G["EncounterJournalEncounterFrameInstanceFrameLoreScrollFrameScrollChildLore"],"white")
		m_fontify(_G["EncounterJournalEncounterFrameInfoDetailsScrollFrameScrollChildDescription"],"white")
		m_fontify(_G["EncounterJournalEncounterFrameInfoEncounterTitle"],"color")
			
		local function miirgui_EncounterJournal_UpdateButtonState(self)
			if self:GetParent().expanded then
				self.tex = self.textures.expanded;
				m_fontify(self.expandedIcon,"color",12)
				m_fontify(self.title,"color")
			else
				self.tex = self.textures.collapsed;	
				m_fontify(self.expandedIcon,"color",12)
				m_fontify(self.title,"color")
			end
		end

		hooksecurefunc("EncounterJournal_UpdateButtonState",miirgui_EncounterJournal_UpdateButtonState)

		local function miirgui_EncounterJournal_SetBullets(object, description)
			local parent = object:GetParent();
			local bullets = {}
			for v in string.gmatch(description,"\$bullet;([^$]+)") do
				tinsert(bullets, v);
			end
			local k = 1;
			for j = 1,#bullets do
				local text = bullets[j];
				if (text and text ~= "") then
					local bullet;
					bullet = parent.Bullets and parent.Bullets[k];
					m_fontify(bullet.Text,"white")
					k = k + 1;
				end
			end
		end

		hooksecurefunc("EncounterJournal_SetBullets",miirgui_EncounterJournal_SetBullets)

		local function miirgui_EncounterJournal_ToggleHeaders()
			for i = 1, 50 do
				if _G["EncounterJournalInfoHeader"..i] then  
				
					m_fontify(_G["EncounterJournalInfoHeader"..i].description,"white")
					m_fontify(_G["EncounterJournalInfoHeader"..i].button.expandedIcon,"color",12)    
				end
			end    
		end
		
		hooksecurefunc("EncounterJournal_ToggleHeaders", miirgui_EncounterJournal_ToggleHeaders)	
		
		local InstanceIcon = CreateFrame("Frame",nil)
		InstanceIcon:SetSize(36,36)
		local InstanceIcontexture = InstanceIcon:CreateTexture(nil,"BACKGROUND")
		InstanceIcontexture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		InstanceIcontexture:SetAllPoints(InstanceIcon)
		InstanceIcon.InstanceIcontexture = InstanceIcontexture
			
		local function miirgui_EncounterJournal_DisplayInstance()
			local self = EncounterJournal.encounter;
			local buttonImage = select(6,EJ_GetInstanceInfo())
			m_fontify(self.instance.title,"white")
			InstanceIcontexture:SetTexture(buttonImage)
			InstanceIcon:SetPoint("CENTER",self.info.instanceButton,1,0)
			InstanceIcon:SetParent(self.info.instanceButton)	
			for i=1,19 do	
				if _G["EncounterJournalBossButton"..i] then
				m_fontify(_G["EncounterJournalBossButton"..i.."Text"],"white")
				end
			end
		end

		hooksecurefunc("EncounterJournal_DisplayInstance", miirgui_EncounterJournal_DisplayInstance)

		local function miirgui_EncounterJournal_DisplayEncounter()
			for i=1,9 do 
				local id, _, _, displayInfo, _ = EJ_GetCreatureInfo(i);
				if id then
					local button = EncounterJournal_GetCreatureButton(i);
					button.creature:SetTexCoord(0.13, 0.83, 0.13, 0.83);
					SetPortraitTexture(button.creature, displayInfo);
				end
			end
		end
			
		hooksecurefunc("EncounterJournal_DisplayEncounter",miirgui_EncounterJournal_DisplayEncounter)		
		
		local function miirgui_EJSuggestFrame_RefreshDisplay()
			local self = EncounterJournal.suggestFrame;
			C_AdventureJournal.GetSuggestions(self.suggestions);		
			if ( #self.suggestions > 0 ) then
				local suggestion = self.Suggestion1;
				local data = self.suggestions[1];
				suggestion.reward.icon:SetSize(46,46)
				--suggestion.reward.iconRingHighlight:SetAlpha(1)
				m_fontify(suggestion.centerDisplay.title.text,"color")	
				m_fontify(suggestion.centerDisplay.description.text,"white")
				m_fontify(suggestion.reward.text,"white")
				suggestion.icon:Hide();	
				suggestion.iconRing:Show()
				if ( data.iconPath ) then
					suggestion.iconRing:SetSize(suggestion.icon:GetSize())
					suggestion.iconRing:SetTexture(data.iconPath)			
				else
					suggestion.iconRing:SetSize(suggestion.icon:GetSize())
					suggestion.iconRing:SetTexture("INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK.BLP")
				end
			end
			if ( #self.suggestions > 1 ) then			
				for i = 2, #self.suggestions do 
					local suggestion = self["Suggestion"..i];
					if ( not suggestion ) then 
						break;
					end	
					suggestion.reward:ClearAllPoints()
					suggestion.reward:SetPoint("BOTTOM",suggestion.icon,0,-60)
					local data = self.suggestions[i];		
					m_fontify(suggestion.centerDisplay.title.text,"color")
					m_fontify(suggestion.centerDisplay.description.text,"white")
					suggestion.icon:Hide();	
					suggestion.iconRing:Show()
					if ( data.iconPath ) then
						suggestion.iconRing:SetSize(suggestion.icon:GetSize())
						suggestion.iconRing:SetTexture(data.iconPath)		
					else
						suggestion.iconRing:SetSize(suggestion.icon:GetSize())
						suggestion.iconRing:SetTexture("INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK.BLP")
					end
				end
			end
		end
			
		hooksecurefunc("EJSuggestFrame_RefreshDisplay",miirgui_EJSuggestFrame_RefreshDisplay)	
			
		local function miirgui_EJSuggestFrame_UpdateRewards(suggestion)
			suggestion.reward.iconRing:Hide()
			suggestion.reward:SetSize(46,46)
			suggestion.reward.icon:SetMask("Interface\\TALENTFRAME\\icon-shadow")
			suggestion.reward.iconRingHighlight:SetAlpha(0)
		end
			
		hooksecurefunc("EJSuggestFrame_UpdateRewards", miirgui_EJSuggestFrame_UpdateRewards)	
		
		local function miirgui_UpdateList()
			local buttons = EncounterJournal.LootJournal.ItemSetsFrame.buttons;
			for i = 1, #buttons do
				local button = buttons[i];
				m_fontify(button.SetName,"same")
				m_fontify(button.ItemLevel,"white")
			
			end	
		end
			
		hooksecurefunc(EncounterJournal.LootJournal.ItemSetsFrame,"UpdateList",miirgui_UpdateList)
	
		local function miirgui_EncounterJournal_ListInstances()
			m_fontify(EncounterJournalInstanceSelectScrollFrameScrollChildInstanceButton1Name,"white")	
			for i=1,20 do 
				if _G["EncounterJournalInstanceSelectScrollFrameinstance"..i.."Name"] then
					m_fontify(_G["EncounterJournalInstanceSelectScrollFrameinstance"..i.."Name"],"white")
				end
			end
		end
		
		hooksecurefunc("EncounterJournal_ListInstances",miirgui_EncounterJournal_ListInstances)
		
	end
end

frame:SetScript("OnEvent", frame.OnEvent);