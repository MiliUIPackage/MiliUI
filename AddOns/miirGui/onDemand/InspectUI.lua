local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
	
		local function miirgui_InspectPaperDollItemSlotButton_Update()
			local headquality= select(5,InspectHeadSlot:GetRegions() )
			headquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local neckquality= select(5,InspectNeckSlot:GetRegions() )
			neckquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local shoulderquality= select(5,InspectShoulderSlot:GetRegions() )
			shoulderquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local backquality= select(5,InspectBackSlot:GetRegions() )
			backquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local chestquality= select(5,InspectChestSlot:GetRegions() )
			chestquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local shirtquality= select(5,InspectShirtSlot:GetRegions() )
			shirtquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local tabardquality= select(5,InspectTabardSlot:GetRegions() )
			tabardquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local wristquality= select(5,InspectWristSlot:GetRegions() )
			wristquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local handquality= select(5,InspectHandsSlot:GetRegions() )
			handquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local waistquality= select(5,InspectWaistSlot:GetRegions() )
			waistquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local legquality= select(5,InspectLegsSlot:GetRegions() )
			legquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local feetquality= select(5,InspectFeetSlot:GetRegions() )
			feetquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local finger0quality= select(5,InspectFinger0Slot:GetRegions() )
			finger0quality:SetTexture("Interface\\Containerframe\\quality.blp")
			local finger1quality= select(5,InspectFinger1Slot:GetRegions() )
			finger1quality:SetTexture("Interface\\Containerframe\\quality.blp")
			local trinket0quality= select(5,InspectTrinket0Slot:GetRegions() )
			trinket0quality:SetTexture("Interface\\Containerframe\\quality.blp")
			local trinket1quality= select(5,InspectTrinket1Slot:GetRegions() )
			trinket1quality:SetTexture("Interface\\Containerframe\\quality.blp")
			local mainhandquality= select(5,InspectMainHandSlot:GetRegions() )
			mainhandquality:SetTexture("Interface\\Containerframe\\quality.blp")
			local offhandquality= select(5,InspectSecondaryHandSlot:GetRegions() )
			offhandquality:SetTexture("Interface\\Containerframe\\quality.blp")
		end

		hooksecurefunc("InspectPaperDollItemSlotButton_Update",miirgui_InspectPaperDollItemSlotButton_Update)
			
		InspectFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		SpecializationRing:Hide()
		SpecializationSpecIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		InspectGuildFrameBG:Hide()
		m_border(Specialization,76,76,"TOPLEFT",16,-14,14,"MEDIUM")
		m_border(InspectGuildFrame,330,340,"LEFT",4,-18,14,"MEDIUM")
		m_border(InspectTalentFrame,334,364,"CENTER",0,-26,14,"MEDIUM")	
		m_border(InspectPVPFrame,334,364,"CENTER",0,-26,14,"MEDIUM")	
		
		
		for x = 1,7 do
			local frame = "TalentsTalentRow"..x
			
			_G[frame.."Talent1Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent1Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent1Border"]:SetSize(40,42)
		
			_G[frame.."Talent2Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent2Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent2Border"]:SetSize(40,42)
			
			_G[frame.."Talent3Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent3Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent3Border"]:SetSize(40,42)
		end
		
		for x = 1,6 do
			local frame = "InspectPVPFrameTalentRow"..x
			
			_G[frame.."Talent1Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent1Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent1Border"]:SetSize(40,42)
		
			_G[frame.."Talent2Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent2Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent2Border"]:SetSize(40,42)
			
			_G[frame.."Talent3Border"]:SetTexture("Interface\\Buttons\\ButtonHilight-Round.blp")
			_G[frame.."Talent3Border"]:SetPoint("CENTER",0,1)
			_G[frame.."Talent3Border"]:SetSize(40,42)
		end
		
		
	end
end
frame:SetScript("OnEvent", frame.OnEvent);