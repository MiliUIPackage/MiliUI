local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	CharacterStatsPane.ClassBackground:Hide()
	PaperDollEquipmentManagerPaneEquipSet.ButtonBackground:Hide()
	m_fontify(CharacterStatsPane.ItemLevelCategory.Title,"color")
	m_border(CharacterStatsPane.ItemLevelCategory,180,30,"CENTER",0,0,12.5,"MEDIUM")
	m_border(CharacterStatsPane,200,354,"CENTER",0,0,12,"MEDIUM")
	m_fontify(CharacterStatsPane.AttributesCategory.Title,"color")
	m_border(CharacterStatsPane.AttributesCategory,180,30,"CENTER",0,0,12.5,"MEDIUM")
	m_fontify(CharacterStatsPane.EnhancementsCategory.Title,"color")
	m_border(CharacterStatsPane.EnhancementsCategory,180,30,"CENTER",0,0,12.5,"MEDIUM")
	m_border(ReputationFrame,330,364,"CENTER",-1,-27,14,"MEDIUM")
	m_border(TokenFrame,330,364,"CENTER",-1,-27,14,"MEDIUM")

	local function miirgui_PaperDollItemSlotButton_Update(self)
		local quality = GetInventoryItemQuality("player", self:GetID());
		if quality then
			self.IconBorder:Show()
			m_SetTexture(self.IconBorder,"Interface\\Containerframe\\quality.blp")
			self.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
		end
		CharacterBag0Slot.IconBorder:SetAlpha(0)
		CharacterBag1Slot.IconBorder:SetAlpha(0)
		CharacterBag2Slot.IconBorder:SetAlpha(0)
		CharacterBag3Slot.IconBorder:SetAlpha(0)
	end

	hooksecurefunc("PaperDollItemSlotButton_Update",miirgui_PaperDollItemSlotButton_Update)

	local function miirgui_CharacterFrame_UpdatePortrait()
		CharacterFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	end
			
	hooksecurefunc("CharacterFrame_UpdatePortrait",miirgui_CharacterFrame_UpdatePortrait)
			
	local function miirgui_EquipmentFlyout_DisplayButton(button, paperDollItemSlot)
		local location = button.location;
		if ( not location ) then
			return;
		end
		if ( location >= EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION ) then
			EquipmentFlyout_DisplaySpecialButton(button, paperDollItemSlot);
			return;
		end
		local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,quality = EquipmentManager_GetItemInfoByLocation(location)
		if quality  then
				button.IconBorder:Show();
				m_SetTexture(button.IconBorder,"Interface\\Containerframe\\quality.blp")
		end
	end
			
	hooksecurefunc("EquipmentFlyout_DisplayButton",miirgui_EquipmentFlyout_DisplayButton)
	
end)

