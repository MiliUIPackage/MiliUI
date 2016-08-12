		--Code to support Clique

		hooksecurefunc("ToggleSpellBook",function()
			if (CliqueSpellTab) then
				local CliqueIcon = select(6,CliqueSpellTab:GetRegions())
				CliqueIcon:SetTexCoord(0.13, 0.83, 0.13, 0.83)
				CliqueConfigPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			end
		end)
		
		--ARL Support

		local frame = CreateFrame("FRAME")
		frame:RegisterEvent("ADDON_LOADED")
		function frame:OnEvent(_,arg1)
			if string.find (arg1,"AckisRecipeList_") then
				local frame = CreateFrame("FRAME")
				frame:SetScript("OnUpdate",function()	
					if ARL_MainPanel then
						ARL_ProfessionButtonPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
						frame:SetScript("OnUpdate",function()end)
					end
				end)
			end
		end
		frame:SetScript("OnEvent", frame.OnEvent);
			
		--Code to support Combuctor
		
		if  IsAddOnLoaded("Combuctor") then
			CombuctorFrameinventoryPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			for i=19,21 do
				local hideit=select(i,CombuctorFrameinventory:GetRegions())
				hideit:Hide()
			end
		end

		--Code to support Inventorian
		
		if  IsAddOnLoaded("Inventorian")  then
			InventorianBagFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			InventorianBankFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			for i=19,21 do
				local hideit=select(i,InventorianBagFrame:GetRegions())
				hideit:Hide()
				local hideitalso=select(i,InventorianBankFrame:GetRegions())
				hideitalso:Hide()
			end
		end
		
		--Classic Quest Log
		
		if IsAddOnLoaded("Classic Quest Log")  then
			m_icon(ClassicQuestLog, "quest", -8, 9, "MEDIUM")
			ClassicQuestLogScrollFrame.BG:Hide()
			ClassicQuestLogDetailScrollFrame.DetailBG:Hide()
			m_border(ClassicQuestLog,0,0,"CENTER",0,0,14,"HIGH")		
			m_border_ClassicQuestLog:SetPoint("TOPLEFT","ClassicQuestLog",2,-58)
			m_border_ClassicQuestLog:SetPoint("BOTTOMRIGHT","ClassicQuestLog",-4,24)
		end
		
		
		
		local frame = CreateFrame("FRAME")
		frame:RegisterEvent("ADDON_LOADED")
		function frame:OnEvent(event, arg1)
		if event == "ADDON_LOADED" and arg1 == "BetterArchaeologyUI" then
		
			print("fired")
			ArchaeologyFrameSummaryPage:HookScript("OnShow",function()
				for i=1,18 do
					local race = _G["ArchaeologyFrameSummaryPageRace"..i]
					if race then 
						m_fontify(race.raceName,"white")
					end
				end
			end)
		elseif event == "ADDON_LOADED" and arg1 == "mOnArs_WardrobeHelper" then
			mOnWD_MainFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end
		end


		frame:SetScript("OnEvent", frame.OnEvent);
		