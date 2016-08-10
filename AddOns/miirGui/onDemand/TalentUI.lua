local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_TalentUI" then
		PlayerTalentFramePetSpecialization.bg:Hide()
		PlayerTalentFrameSpecialization.bg:Hide()
		
		for i=1,4 do
			_G["PlayerTalentFrameSpecializationSpecButton"..i.."Ring"]:Hide()
			_G["PlayerTalentFrameSpecializationSpecButton"..i.."SpecIcon"]:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			_G["PlayerTalentFrameSpecializationSpecButton"..i.."SpecIcon"]:SetWidth(42)
			_G["PlayerTalentFrameSpecializationSpecButton"..i.."SpecIcon"]:SetHeight(42)
		end
		for i=1,3 do
			_G["PlayerTalentFramePetSpecializationSpecButton"..i.."Ring"]:Hide()
			_G["PlayerTalentFramePetSpecializationSpecButton"..i.."SpecIcon"]:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			_G["PlayerTalentFramePetSpecializationSpecButton"..i.."SpecIcon"]:SetWidth(42)
			_G["PlayerTalentFramePetSpecializationSpecButton"..i.."SpecIcon"]:SetHeight(42)
		end

		PlayerTalentFramePetSpecializationSpellScrollFrameScrollChildRing:Hide()
		PlayerTalentFramePetSpecializationSpellScrollFrameScrollChildSpecIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
		PlayerTalentFramePetSpecializationSpellScrollFrameScrollChildAbility1Ring:Hide()	
		PlayerTalentFramePetSpecializationSpellScrollFrameScrollChildAbility1Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
		PlayerTalentFrameSpecializationSpellScrollFrameScrollChildRing:Hide()
		PlayerTalentFrameSpecializationSpellScrollFrameScrollChildSpecIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
		PlayerTalentFrameSpecializationSpellScrollFrameScrollChildAbility1Ring:Hide()	
		PlayerTalentFrameSpecializationSpellScrollFrameScrollChildAbility1Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
		PlayerTalentFrameTalentsTutorialButton.Ring:Hide()
		PlayerTalentFrameSpecializationTutorialButton.Ring:Hide()	
		PlayerTalentFramePetSpecializationTutorialButton.Ring:Hide()
		local function miirgui_PlayerTalentFrame_UpdateSpecFrame()
		PlayerTalentFramePortrait:SetPoint("TOPLEFT",-8,9)
			PlayerTalentFramePortrait:SetSize(66,66)
		end
		hooksecurefunc("PlayerTalentFrame_UpdateSpecFrame",miirgui_PlayerTalentFrame_UpdateSpecFrame)
		PlayerTalentFrameTab2:HookScript("OnClick",miirgui_PlayerTalentFrame_UpdateSpecFrame)
		local PlayerTalentFrameHoritontal = select(13,PlayerTalentFrameSpecializationSpellScrollFrameScrollChild:GetRegions())
		PlayerTalentFrameHoritontal:SetColorTexture(0.78,0.78,0.78,0)
		local PlayerTalentFrameTintage = select(1,PlayerTalentFrameSpecializationSpellScrollFrameScrollChild:GetRegions())
		PlayerTalentFrameTintage:SetColorTexture(0,0,0,0)		
		local PlayerTalentFramePetHoritontal = select(13,PlayerTalentFramePetSpecializationSpellScrollFrameScrollChild:GetRegions())
		PlayerTalentFramePetHoritontal:SetColorTexture(0.78,0.78,0.78,0)
		local PlayerTalentFramePetTintage = select(1,PlayerTalentFramePetSpecializationSpellScrollFrameScrollChild:GetRegions())
		PlayerTalentFramePetTintage:SetColorTexture(0,0,0,0)	
		local PlayerSpecTab1Icon=select(2,PlayerSpecTab1:GetRegions())
		PlayerSpecTab1Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		local PlayerSpecTab2Icon=select(2,PlayerSpecTab2:GetRegions())
		PlayerSpecTab2Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		m_border(PlayerTalentFrameSpecializationSpellScrollFrame,414,414,"CENTER",0,-2,14,"MEDIUM")	
		m_border(PlayerTalentFramePetSpecializationSpellScrollFrame,414,414,"CENTER",0,-2,14,"MEDIUM")	
		m_border(PlayerTalentFramePetSpecializationSpecButton1,46,46,"LEFT",14,0,14,"MEDIUM")
		m_border(PlayerTalentFramePetSpecializationSpecButton2,46,46,"LEFT",14,0,14,"MEDIUM")
		m_border(PlayerTalentFramePetSpecializationSpecButton3,46,46,"LEFT",14,0,14,"MEDIUM")	
		m_border(PlayerTalentFrameSpecializationSpecButton1,46,46,"LEFT",14,0,14,"MEDIUM")
		m_border(PlayerTalentFrameSpecializationSpecButton2,46,46,"LEFT",14,0,14,"MEDIUM")
		m_border(PlayerTalentFrameSpecializationSpecButton3,46,46,"LEFT",14,0,14,"MEDIUM")	
		m_border(PlayerTalentFrameSpecializationSpellScrollFrameScrollChild,76,76,"TOPLEFT",16,-14,14,"MEDIUM")		
		m_border(PlayerTalentFrameSpecializationSpellScrollFrameScrollChildAbility1,58,58,"CENTER",0,0,14,"MEDIUM")	
		m_border(PlayerTalentFramePetSpecializationSpellScrollFrameScrollChild,76,76,"TOPLEFT",16,-14,14,"MEDIUM")		
		m_border(PlayerTalentFramePetSpecializationSpellScrollFrameScrollChildAbility1,58,58,"CENTER",0,0,14,"MEDIUM")
		m_border(PlayerTalentFrameTalents,640,384,"CENTER",0,0,14,"Medium")	
	
		local PlayerTalentFramePVPTalentsTutorialBoxBg=select(1,PlayerTalentFramePVPTalents.TutorialBox:GetRegions())
		PlayerTalentFramePVPTalentsTutorialBoxBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		PlayerTalentFramePVPTalentsTutorialBoxBg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(PlayerTalentFramePVPTalents.TutorialBox,226,108,"CENTER",0.5,0,14,"DIALOG")
		m_fontify(PlayerTalentFramePVPTalents.TutorialBox.Text,"white")
	
		local function miirgui_PlayerTalentFrame_CreateSpecSpellButton(frame, index)
			local scrollChild = frame.spellsScroll.child;
			local name = scrollChild:GetName() .. "Ability" .. index;
			local child1,child2 = _G[name]:GetRegions();
			child1:Hide()
			child2:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			m_border(_G[name],58,58,"CENTER",0,0,14,"MEDIUM")
		end

		hooksecurefunc("PlayerTalentFrame_CreateSpecSpellButton", miirgui_PlayerTalentFrame_CreateSpecSpellButton)

		local function miirgui_PlayerTalentFrame_UpdateSpecFrame()
			for i=1,4 do
			m_fontify(_G["PlayerTalentFrameSpecializationSpellScrollFrameScrollChildAbility"..i.."SubText"],"white")
			end
		end

		hooksecurefunc("PlayerTalentFrame_UpdateSpecFrame",miirgui_PlayerTalentFrame_UpdateSpecFrame)

	end
end

		frame:SetScript("OnEvent", frame.OnEvent);