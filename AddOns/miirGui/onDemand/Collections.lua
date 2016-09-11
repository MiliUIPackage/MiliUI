local function skin_Blizzard_Collections()

		CollectionsJournalPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		MountJournalSummonRandomFavoriteButtonBorder:Hide()
		MountJournalListScrollFrameScrollBarBG:Hide()
		PetJournalTutorialButton.Ring:Hide()
		PetJournalListScrollFrameScrollBarBG:Hide()
		PetJournalLoadoutPet2BG:Hide()
		PetJournalLoadoutPet3BG:Hide()
		PetJournalLoadoutPet1PetTypeIcon:SetBlendMode("Add")
		PetJournalLoadoutPet2PetTypeIcon:SetBlendMode("Add")
		PetJournalLoadoutPet3PetTypeIcon:SetBlendMode("Add")
		PetJournalPetCardBG:Hide()
		PetJournalLoadoutBorder:Hide()
		PetJournalLoadoutPet1BG:Hide()
		PetJournalLoadoutPet2BG:Hide()
		PetJournalLoadoutPet3BG:Hide()
		PetJournalHealPetButtonBorder:Hide()
		ToyBox.iconsFrame.BackgroundTile:SetDesaturated(1)
		ToyBox.iconsFrame.OverlayShadowTopLeft:Hide()
		ToyBox.iconsFrame.OverlayShadowTop:Hide()
		ToyBox.iconsFrame.OverlayShadowTopRight:Hide()
		ToyBox.iconsFrame.OverlayShadowRight:Hide()
		ToyBox.iconsFrame.OverlayShadowLeft:Hide()
		ToyBox.iconsFrame.OverlayShadowBottomLeft:Hide()
		ToyBox.iconsFrame.OverlayShadowBottomRight:Hide()
		ToyBox.iconsFrame.OverlayShadowBottom:Hide()
		ToyBox.iconsFrame.BGCornerFilagreeBottomLeft:Hide()
		ToyBox.iconsFrame.BGCornerFilagreeBottomRight:Hide()
		ToyBox.iconsFrame.BGCornerTopLeft:Hide()
		ToyBox.iconsFrame.BGCornerTopRight:Hide()
		ToyBox.iconsFrame.BGCornerBottomRight:Hide()
		ToyBox.iconsFrame.BGCornerBottomLeft:Hide()
		ToyBox.iconsFrame.ShadowLineTop:Hide()
		ToyBox.iconsFrame.ShadowLineBottom:Hide()
		ToyBox.iconsFrame.ShadowCornerTopRight:Hide()
		ToyBox.iconsFrame.ShadowCornerTopLeft:Hide()
		ToyBox.iconsFrame.ShadowCornerLeft:Hide()
		ToyBox.iconsFrame.ShadowCornerRight:Hide()
		ToyBox.iconsFrame.ShadowCornerBottomLeft:Hide()
		ToyBox.iconsFrame.ShadowCornerBottomRight:Hide()
		ToyBox.iconsFrame.ShadowCornerTop:Hide()
		ToyBox.iconsFrame.ShadowCornerBottom:Hide()
		ToyBox.iconsFrame.watermark:Hide()

		HeirloomsJournal.iconsFrame.BackgroundTile:SetDesaturated(1)
		HeirloomsJournal.iconsFrame.OverlayShadowTopLeft:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowTop:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowTopRight:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowRight:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowLeft:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowBottomLeft:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowBottomRight:Hide()
		HeirloomsJournal.iconsFrame.OverlayShadowBottom:Hide()
		HeirloomsJournal.iconsFrame.BGCornerFilagreeBottomLeft:Hide()
		HeirloomsJournal.iconsFrame.BGCornerFilagreeBottomRight:Hide()
		HeirloomsJournal.iconsFrame.BGCornerTopLeft:Hide()
		HeirloomsJournal.iconsFrame.BGCornerTopRight:Hide()
		HeirloomsJournal.iconsFrame.BGCornerBottomRight:Hide()
		HeirloomsJournal.iconsFrame.BGCornerBottomLeft:Hide()
		HeirloomsJournal.iconsFrame.ShadowLineTop:Hide()
		HeirloomsJournal.iconsFrame.ShadowLineBottom:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerTopRight:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerTopLeft:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerLeft:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerRight:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerBottomLeft:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerBottomRight:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerTop:Hide()
		HeirloomsJournal.iconsFrame.ShadowCornerBottom:Hide()
		HeirloomsJournal.iconsFrame.watermark:Hide()
		
		local robebg = WardrobeCollectionFrame.ModelsFrame.HelpBox:GetRegions()
		robebg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		robebg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(WardrobeCollectionFrame.ModelsFrame.HelpBox,226,82,"CENTER",0,0,14,"DIALOG")		
		m_fontify(WardrobeCollectionFrame.ModelsFrame.HelpBox.Text,"white")	
		
		local robebg = WardrobeTransmogFrame.OutfitHelpBox:GetRegions()
		robebg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		robebg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(WardrobeTransmogFrame.OutfitHelpBox,226,70,"CENTER",0,0,14,"DIALOG")		
		m_fontify(WardrobeTransmogFrame.OutfitHelpBox.Text,"white")	
		
		local robebg = WardrobeTransmogFrame.SpecHelpBox:GetRegions()
		robebg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		robebg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(WardrobeTransmogFrame.SpecHelpBox,226,82,"CENTER",0,0,14,"DIALOG")		
		m_fontify(WardrobeTransmogFrame.SpecHelpBox.Text,"white")			

		local robebg = CollectionsJournal.WardrobeTabHelpBox:GetRegions()
		robebg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		robebg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(CollectionsJournal.WardrobeTabHelpBox,226,94,"CENTER",0.5,0,14,"DIALOG")		
		m_fontify(CollectionsJournal.WardrobeTabHelpBox.Text,"white")	
		
		local toybg = ToyBox.favoriteHelpBox:GetRegions()
		toybg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		toybg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(ToyBox.favoriteHelpBox,226,70,"CENTER",0,0.5,14,"DIALOG")	
		m_fontify(ToyBox.favoriteHelpBox.BigText,"white")
		
		m_fontify(ToyBox.navigationFrame.pageText,"white")
		m_fontify(HeirloomsJournal.navigationFrame.pageText,"white")

		m_border(PetJournalLoadoutPet1,406,110,"CENTER",-0.5,2,14,"HIGH")		
		m_border(PetJournalLoadoutPet2,406,110,"CENTER",-0.5,-1,14,"HIGH")
		m_border(PetJournalLoadoutPet3,406,110,"CENTER",-0.5,-4,14,"HIGH")	
		PetJournalRightInsetBg:ClearAllPoints()
		PetJournalRightInsetBg:SetPoint("TOPLEFT",m_border_PetJournalLoadoutPet1,1,-1)			
		PetJournalRightInsetBg:SetPoint("BOTTOMRIGHT",m_border_PetJournalLoadoutPet3,-1,1)
		PetJournalPetCardInsetBg:ClearAllPoints()
		PetJournalPetCardInsetBg:SetPoint("CENTER",PetJournalPetCard)
		PetJournalPetCardInsetBg:SetSize(402,170)
		m_border(PetJournalLeftInset,264,522,"LEFT",0,0,14,"HIGH")
		m_border(PetJournalPetCard,406,174,"TOPLEFT",0,4,14,"HIGH")
		m_border(ToyBox.iconsFrame,692,540,"CENTER",-0.5,0.5,14,"HIGH")
		m_border(MountJournal.LeftInset,264,522,"LEFT",0,0,14,"HIGH")
		m_border(MountJournal,416,522,"CENTER",139.5,-17,14,"HIGH")
		m_border(MountJournal.MountDisplay.InfoButton,42,42,"CENTER",-66,-20,14,"HIGH")
		m_border(MountJournalListScrollFrameButton1,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton2,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton3,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton4,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton5,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton6,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton7,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton8,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton9,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton10,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(MountJournalListScrollFrameButton11,42,42,"LEFT",-44,0,14,"HIGH")
		m_border(HeirloomsJournal.iconsFrame,692,540,"CENTER",-0.5,0.5,14,"HIGH")
		m_border(WardrobeCollectionFrame.ModelsFrame.SlotsFrame,692,540,"LEFT",-18,-245,14,"HIGH")
		m_border(PetJournalPetCardTypeInfo,23,24,"CENTER",-0.5,0,14,"HIGH")
		for i=1,6 do
			_G["PetJournalPetCardSpell"..i.."Icon"]:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end
		
		local function miirgui_ToySpellButton_UpdateButton(self)
			local slotFrameCollected = self.slotFrameCollected;
			slotFrameCollected:Show()	

			if not (PlayerHasToy(self.itemID)) then
				slotFrameCollected:Show()
				self:HookScript("OnClick",function()
					self:UnregisterEvent("SPELLS_CHANGED");
					self:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
					self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM");
				end)
				
			else
				slotFrameCollected:Show()				
				self:HookScript("OnClick",function()
					self:RegisterEvent("SPELLS_CHANGED");
					self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
					self:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
				end)
			end
			
		end
		
		hooksecurefunc("ToySpellButton_UpdateButton",miirgui_ToySpellButton_UpdateButton)				-- this hook changes the look of the Toys-Tab
		
		local function miirgui_CollectionsSpellButton_UpdateCooldown(self)	
			self:UnregisterEvent("SPELLS_CHANGED");
			self:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
			self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM");
		
			if not (PlayerHasToy(self.itemID)) then
				m_fontify(self.name,"grey")
			else
				m_fontify(self.name,"white")
			end	
		end
		
	hooksecurefunc("CollectionsSpellButton_UpdateCooldown",miirgui_CollectionsSpellButton_UpdateCooldown)				-- cooldown numbers
		
		local function miirgui_PetJournal_UpdatePetLoadOut()
			for i=1,3 do
				local loadoutPlate = PetJournal.Loadout["Pet"..i];
				_G["PetJournalLoadoutPet"..i.."PetTypeIcon"]:ClearAllPoints()
				_G["PetJournalLoadoutPet"..i.."PetTypeIcon"]:SetPoint("LEFT",_G["m_border_PetJournalLoadoutPet"..i],4,-22)
				local petID = C_PetJournal.GetPetLoadOutInfo(i);
				if petID then
					m_fontify(loadoutPlate.level,"white")
					local _,_,_,_,rarity = C_PetJournal.GetPetStats(petID)
					m_SetTexture(loadoutPlate.qualityBorder,"Interface\\Containerframe\\quality.blp")
					loadoutPlate.qualityBorder:SetVertexColor(ITEM_QUALITY_COLORS[rarity-1].r, ITEM_QUALITY_COLORS[rarity-1].g, ITEM_QUALITY_COLORS[rarity-1].b);
					if not loadoutPlate.qualityBorder:IsVisible() then 
					loadoutPlate.qualityBorder:Show()
					end
				end
			end 
		end

		hooksecurefunc("PetJournal_UpdatePetLoadOut",miirgui_PetJournal_UpdatePetLoadOut)				-- this hook changes the quality border on the pet loadout panel

		local function miirgui_PetJournal_UpdatePetCard(self)
			if string.find (self.TypeInfo.typeIcon:GetTexture(),"Humanoid") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Humanoid.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Dragon") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Dragon.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Flying") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Flying.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Undead") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Undead.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Critter") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Critter.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Magical") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Magical.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Elemental") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Elemental.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Beast") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Beast.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Water") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Water.blp")
			elseif string.find (self.TypeInfo.typeIcon:GetTexture(),"Mechanical") then
				self.TypeInfo.typeIcon:SetTexture("Interface\\TargetingFrame\\PetBadge-Mechanical.blp")
			end
			m_fontify(self.PetInfo.level,"white")
			self.TypeInfo.typeIcon:SetTexCoord(0, 1, 0, 1)
			self.TypeInfo.typeIcon:SetSize(32,32)	
		end

		hooksecurefunc("PetJournal_UpdatePetCard",miirgui_PetJournal_UpdatePetCard)						-- this hook changes the class-icon on the pet loadout panel

		local function miirgui_PetJournal_UpdatePetList()
			local scrollFrame = PetJournal.listScroll;
			local offset = HybridScrollFrame_GetOffset(scrollFrame);
			local petButtons = scrollFrame.buttons;
			local pet, index;
			local numPets, numOwned = C_PetJournal.GetNumPets();
			PetJournal.PetCount.Count:SetText(numOwned);
			for i = 1,#petButtons do
				pet = petButtons[i];
				index = offset + i;
				if index <= numPets then
					local petID,_,isOwned = C_PetJournal.GetPetInfoByIndex(index)
					if isOwned then
						local _,_,_,_,rarity = C_PetJournal.GetPetStats(petID)
						m_fontify(pet.dragButton.level,"white")
						m_SetTexture(pet.iconBorder,"Interface\\Containerframe\\quality.blp")
						pet.iconBorder:SetVertexColor(ITEM_QUALITY_COLORS[rarity-1].r, ITEM_QUALITY_COLORS[rarity-1].g, ITEM_QUALITY_COLORS[rarity-1].b);
					end
				end
			end
			for i=1,11 do
			_G["PetJournalListScrollFrameButton"..i.."PetTypeIcon"]:SetHeight(33)
			_G["PetJournalListScrollFrameButton"..i.."PetTypeIcon"]:SetWidth(66)
			_G["PetJournalListScrollFrameButton"..i.."PetTypeIcon"]:ClearAllPoints()
			_G["PetJournalListScrollFrameButton"..i.."PetTypeIcon"]:SetPoint("RIGHT", -4, 0)
			end
		end

		hooksecurefunc("PetJournal_UpdatePetList",miirgui_PetJournal_UpdatePetList)						-- this hook changes the quality border on the pet-list
			
		local function miirgui_MountJournal_UpdateMountList()
			local scrollFrame = MountJournal.ListScrollFrame;
			local offset = HybridScrollFrame_GetOffset(scrollFrame);
			local buttons = scrollFrame.buttons;
			local showMounts = true;
			local numDisplayedMounts = C_MountJournal.GetNumDisplayedMounts();
			for i=1, #buttons do
				local button = buttons[i];
				local displayIndex = i + offset;
				if ( displayIndex <= numDisplayedMounts and showMounts ) then
					local index = displayIndex;
					local _,_,_,_,_,_,isFavorite = C_MountJournal.GetDisplayedMountInfo(index)
					if ( isFavorite ) then
						button.favorite:ClearAllPoints()
						button.favorite:SetPoint("RIGHT", -5, 0)
					end
				end
			end
		end

		hooksecurefunc("MountJournal_UpdateMountList", miirgui_MountJournal_UpdateMountList)			-- this hook changes the position of the favorite icon on the mount list

		local function miirgui_UpdateButton(_,button)
			m_fontify(button.special,"white")
			if C_Heirloom.PlayerHasHeirloom(button.itemID) then
				m_fontify(button.name,"white")
				m_fontify(button.level,"white")				
			else
				m_fontify(button.name,"grey")
				m_fontify(button.special,"grey")			
				button.slotFrameUncollected:SetAlpha(0)
				button.slotFrameCollected:Show()		
			end
		end
 
		hooksecurefunc(HeirloomsJournal,"UpdateButton",miirgui_UpdateButton)							-- this hook changes the look of the heirlooms tab as well as its font color

		local function miirgui_LayoutCurrentPage(self)
			self.UpgradeLevelHelpBox:Hide();
			local pageLayoutData = self.heirloomLayoutData[self.currentPage];
			local numHeadersInUse = 0;
			if pageLayoutData then
				for i, layoutData in ipairs(pageLayoutData) do
					if type(layoutData) == "string" then
						numHeadersInUse = numHeadersInUse + 1;
						local header = self:AcquireFrame(self.heirloomHeaderFrames, numHeadersInUse, "FRAME", "HeirloomHeaderTemplate");						
						m_fontify(header.text,"color")
					end
				end
			end
		end

		hooksecurefunc(HeirloomsJournal,"LayoutCurrentPage",miirgui_LayoutCurrentPage)					-- this hook changes the fonts of the heirloom-headers

		WardrobeFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
		WardrobeCollectionFrame.ModelsFrame.BGCornerFilagreeBottomLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.BGCornerFilagreeBottomRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.BGCornerTopLeft:SetAlpha(0)
		WardrobeCollectionFrame.ModelsFrame.BGCornerTopRight:SetAlpha(0)
		WardrobeCollectionFrame.ModelsFrame.BGCornerBottomLeft:SetAlpha(0)
		WardrobeCollectionFrame.ModelsFrame.BGCornerBottomRight:SetAlpha(0)
		WardrobeCollectionFrame.ModelsFrame.ShadowLineTop:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowTop:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowTopLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowTopRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowLineBottom:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowBottom:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowBottomLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.OverlayShadowBottomRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerTop:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerTopLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerTopRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerBottom:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerBottomLeft:Hide()
		WardrobeCollectionFrame.ModelsFrame.ShadowCornerBottomRight:Hide()
		WardrobeCollectionFrame.ModelsFrame.BackgroundTile:SetDesaturated(true)
		m_fontify(WardrobeCollectionFrame.NavigationFrame.PageText,"white")
		m_border(WardrobeTransmogFrame,652,540,"CENTER",479,2.5,14,"HIGH")
			
		local function miirgui_WardrobeCollectionFrame_SetContainer(parent)
			local collectionFrame = WardrobeCollectionFrame
			if ( parent == CollectionsJournal ) then
				collectionFrame.ModelsFrame.ModelR1C1:SetPoint("TOP", -238.5, -85);
			end
		end
		
		hooksecurefunc("WardrobeCollectionFrame_SetContainer",miirgui_WardrobeCollectionFrame_SetContainer)

	end

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()	
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
			skin_Blizzard_Collections()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_Collections") then
		skin_Blizzard_Collections()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)