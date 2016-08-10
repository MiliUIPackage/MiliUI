		--Code to support Clique

		hooksecurefunc("ToggleSpellBook",function()
			if (CliqueSpellTab) then
				local CliqueIcon = select(6,CliqueSpellTab:GetRegions())
				CliqueIcon:SetTexCoord(0.13, 0.83, 0.13, 0.83)
				CliqueConfigPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
			end
		end)

		--Code to support Combuctor

		local combuctor = IsAddOnLoaded("Combuctor")

		if combuctor == true  then
			CombuctorFrameinventoryPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			for i=19,21 do
				local hideit=select(i,CombuctorFrameinventory:GetRegions())
				hideit:Hide()
			end
		end

		--Code to support Inventorian
		
		local invent = IsAddOnLoaded("Inventorian")

		if invent == true  then
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
		
		local cql = IsAddOnLoaded("Classic Quest Log")
		if cql == true  then
			m_icon(ClassicQuestLog, "quest", -8, 9, "MEDIUM")
			ClassicQuestLogScrollFrame.BG:Hide()
			ClassicQuestLogDetailScrollFrame.DetailBG:Hide()
			m_border(ClassicQuestLog,656,414,"CENTER",0.5,-17,14,"HIGH")
		end
		
		-- BetterArchaeologyUI
		
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

		end
		end

		frame:SetScript("OnEvent", frame.OnEvent);
		