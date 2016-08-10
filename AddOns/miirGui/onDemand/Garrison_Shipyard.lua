local frame = CreateFrame("FRAME");
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_GarrisonUI" then

		--Hiding Textures at GarrisonShipyardFrame
		GarrisonShipyardFrame.BackgroundTile:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
		local topborder=select(11,GarrisonShipyardFrame.BorderFrame:GetRegions())
		topborder:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")			
		GarrisonShipyardFrameFollowersListScrollFrameScrollBarBG:Hide()						
		GarrisonShipyardFrame.BorderFrame.GarrCorners.TopLeftGarrCorner:Hide()
		GarrisonShipyardFrame.BorderFrame.GarrCorners.TopRightGarrCorner:Hide()
		GarrisonShipyardFrame.BorderFrame.GarrCorners.BottomLeftGarrCorner:Hide()
		GarrisonShipyardFrame.BorderFrame.GarrCorners.BottomRightGarrCorner:Hide()
		GarrisonShipyardFrame.BorderFrame.Left:Hide()
		GarrisonShipyardFrame.BorderFrame.Right:Hide()
		GarrisonShipyardFrame.BorderFrame.Bottom:Hide()		
		--Hide Textures on mission details frame
		for i=1,20 do
			local hideit=select(i,GarrisonShipyardFrame.MissionTab.MissionPage:GetRegions())
			hideit:Hide()
		end		
		GarrisonShipyardFrame.MissionTab.MissionPage.BuffsFrame.BuffsBG:Hide()
		m_fontify(GarrisonShipyardFrame.MissionTab.MissionPage.BuffsFrame.BuffsTitle,"white")
		
		--MissionPageReward
		
		for i=1,10 do
			local hideit=select(i,GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame:GetRegions())
			hideit:Hide()
		end	
		GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward1.BG:Hide()
		m_fontify(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward1.Name,"white")
		GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward2.BG:Hide()
		m_fontify(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward2.Name,"white")
		m_fontify(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.MissionXP,"white")
		m_border(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward1,100,46,"CENTER",20,0,14,"MEDIUM")
		m_border(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward1,46,46,"LEFT",-1,0,14,"MEDIUM")
		m_border(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward2,100,46,"CENTER",20,0,14,"MEDIUM")
		m_border(GarrisonShipyardFrame.MissionTab.MissionPage.RewardsFrame.Reward2,46,46,"LEFT",-1,0,14,"MEDIUM")
				
		-- Fleet Tab
		
		for i = 1,21 do
			local hideit=select(i,GarrisonShipyardFrameFollowers:GetRegions()) 
			hideit:Hide()
		end
		local GarrisonShipyardFrameFollowersMaterialFrameCurrencyBorder=select(1,GarrisonShipyardFrameFollowers.MaterialFrame:GetRegions())
		GarrisonShipyardFrameFollowersMaterialFrameCurrencyBorder:Hide()
		m_border(GarrisonShipyardFrameFollowers,310,570,"CENTER",0,-16,12,"MEDIUM")
		m_border(GarrisonShipyardFrameFollowers.MaterialFrame,300,26,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonShipyardFrame.MissionTab.MissionPage.Stage,558,238,"CENTER",0,0,14,"MEDIUM")	
		m_fontify(GarrisonShipyardFrame.FollowerTab.NumFollowers,"white")
		GarrisonShipyardFrame.FollowerTab.HeaderBG:Hide()	
		GarrisonShipyardFrame.FollowerTab.Quality:Hide()
		GarrisonShipyardFrame.FollowerTab.Trait1.Border:Hide()
		GarrisonShipyardFrame.FollowerTab.Trait2.Border:Hide()
		GarrisonShipyardFrame.FollowerTab.EquipmentFrame.Equipment1.Border:Hide()
		GarrisonShipyardFrame.FollowerTab.EquipmentFrame.Equipment2.Border:Hide()
		for i = 1,21 do
			local hideit=select(i,GarrisonShipyardFrame.FollowerTab:GetRegions()) 
			hideit:Hide()
		end			
		local xpleft=select(2,GarrisonShipyardFrame.FollowerTab.XPBar:GetRegions())
		xpleft:Hide()
		local xpright=select(3,GarrisonShipyardFrame.FollowerTab.XPBar:GetRegions())
		xpright:Hide()
		local xpmiddle=select(4,GarrisonShipyardFrame.FollowerTab.XPBar:GetRegions())
		xpmiddle:Hide()
		local xptext=select(6,GarrisonShipyardFrame.FollowerTab.XPBar:GetRegions())
		m_fontify(xptext,"white")
		m_border(GarrisonShipyardFrame.FollowerTab.XPBar,524,16,"CENTER",0,0,12,"MEDIUM")
			
		--Ship Follower List template
						
		local function miirgui_UpdateData(self)
			local followers = self.followers;
			local followersList = self.followersList;
			local numFollowers = #followersList;
			local scrollFrame = self.listScroll;
			local offset = HybridScrollFrame_GetOffset(scrollFrame);
			local buttons = scrollFrame.buttons;
			local numButtons = #buttons;	
			for i = 1, numButtons do
				local button = buttons[i];
				local index = offset + i;
				if ( index <= numFollowers) then
					local follower = followers[followersList[index]];
					button.Portrait:ClearAllPoints()				
					button.Portrait:SetPoint("LEFT",button.BG,3,3)	
					button.BG:SetTexture("Interface\\Garrison\\ship.blp")
					button.BG:SetSize(256,76)
					button:SetHighlightTexture("Interface\\Garrison\\shiphover.blp")
					button.Selection:SetVertexColor(unpack(miirgui.Color))
					button.Selection:SetTexture("Interface\\Garrison\\shiphover.blp")
					button.Selection:SetAlpha(0.2)
					button.Quality:Hide()
					if (follower.status) then
						button.BusyFrame:Show();
						button.BusyFrame.Texture:SetTexture("Interface\\Garrison\\shiphover.blp");
						button.BusyFrame.Texture:SetAlpha(0.2)
						button.BusyFrame.Texture:SetSize(256,76)
						button.BusyFrame.Texture:ClearAllPoints()
						button.BusyFrame.Texture:SetPoint("TOP",button,0,0)
					else
						button.BusyFrame:Hide();
					end
					button.XPBar:ClearAllPoints()
					button.XPBar:SetPoint("BOTTOMLEFT",button.BG,2,4)
				end
			end
		end
		
		hooksecurefunc(GarrisonShipyardFrameFollowers,"UpdateData",miirgui_UpdateData)
		hooksecurefunc(GarrisonLandingPage.ShipFollowerList,"UpdateData",miirgui_UpdateData)
				
		--mission complete popup
				
		GarrisonShipyardFrame.MissionComplete.NextMissionButton:ClearAllPoints()
		GarrisonShipyardFrame.MissionComplete.NextMissionButton:SetPoint("CENTER",0,-276)	
				
		for i=2,12 do
			local hideit=select(i,GarrisonShipyardFrame.MissionComplete:GetRegions())
			hideit:Hide()
		end
				
		local bg=select(1,GarrisonShipyardFrame.MissionComplete:GetRegions())
		bg:Show()
		bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
		
		for i =1,10 do --rewards
			local hideit=select(i,GarrisonShipyardFrame.MissionComplete.BonusRewards:GetRegions())
			hideit:SetAlpha(0)
		end
		for i=1,6 do
			local hideit=select(i,GarrisonShipyardFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end		
		for i=8,10 do
			local hideit=select(i,GarrisonShipyardFrame.MissionComplete.Stage.MissionInfo:GetRegions())
			hideit:Hide()
		end
				
		GarrisonShipyardFrame.MissionComplete.BonusRewards.Saturated:ClearAllPoints()
				
		m_border(GarrisonShipyardFrame.MissionComplete,558,289,"CENTER",0,148,14,"HIGH")
		m_border(GarrisonShipyardFrame.MissionComplete,558,590,"CENTER",0,-2,14,"HIGH")
				
		--Change the rewards-font

		local rewards=select(11,GarrisonShipyardFrame.MissionComplete.BonusRewards:GetRegions())
		m_fontify(rewards,"white")	

		--Landing Page Fleet Tab
				
		local xpleft=select(2,GarrisonLandingPage.ShipFollowerTab.XPBar:GetRegions())
		xpleft:Hide()
		local xpright=select(3,GarrisonLandingPage.ShipFollowerTab.XPBar:GetRegions())
		xpright:Hide()
		local xpmiddle=select(4,GarrisonLandingPage.ShipFollowerTab.XPBar:GetRegions())
		xpmiddle:Hide()
		local xptext=select(6,GarrisonLandingPage.ShipFollowerTab.XPBar:GetRegions())
		m_fontify(xptext,"white")
		m_fontify(GarrisonLandingPage.ShipFollowerTab.NumFollowers,"white")
		GarrisonLandingPage.ShipFollowerTab.Quality:Hide()
		GarrisonLandingPage.ShipFollowerTab.Trait1.Border:Hide()
		GarrisonLandingPage.ShipFollowerTab.Trait2.Border:Hide()
		GarrisonLandingPage.ShipFollowerTab.EquipmentFrame.Equipment1.Border:Hide()
		GarrisonLandingPage.ShipFollowerTab.EquipmentFrame.Equipment2.Border:Hide()
				
		for i = 1,4 do
			local hideit=select(i,GarrisonLandingPage.ShipFollowerList:GetRegions()) 
			hideit:Hide()
		end	
				
		m_border(GarrisonLandingPage.ShipFollowerTab.XPBar,374,16,"CENTER",0,0,12,"MEDIUM")				
		m_border(GarrisonLandingPage.ShipFollowerTab.EquipmentFrame.Equipment1,52,52,"CENTER",0,0,14,"MEDIUM")
		m_border(GarrisonLandingPage.ShipFollowerTab.EquipmentFrame.Equipment2,52,52,"CENTER",0,0,14,"MEDIUM")		
		m_border(GarrisonLandingPage.ShipFollowerTab.Trait1,52,52,"CENTER",0,-2,14,"MEDIUM")	
		m_border(GarrisonLandingPage.ShipFollowerTab.Trait2,52,52,"CENTER",0,-2,14,"MEDIUM")	

		local function miirgui_Ship_Expand(_,button)
			local bility = #button.info.abilities
				if bility == 1 then
					button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility1.blp")
					button.AbilitiesBG:SetWidth(256)
					button.AbilitiesBG:SetHeight(64)
				elseif bility == 2 then
					button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility2.blp")
					button.AbilitiesBG:SetWidth(256)
					button.AbilitiesBG:SetHeight(64)
				elseif bility == 3 then
					button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility3.blp")
					button.AbilitiesBG:SetWidth(256)
					button.AbilitiesBG:SetHeight(128)
				elseif bility == 4 then
					button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility4.blp")
					button.AbilitiesBG:SetWidth(256)
					button.AbilitiesBG:SetHeight(128)
				elseif bility == 5 then
					button.AbilitiesBG:SetTexture("Interface\\Garrison\\bility5.blp")
					button.AbilitiesBG:SetWidth(256)
					button.AbilitiesBG:SetHeight(128)
				end	
			end
					
		hooksecurefunc(GarrisonShipyardFrameFollowers,"ExpandButton",miirgui_Ship_Expand)
	end	
end
		
frame:SetScript("OnEvent", frame.OnEvent);