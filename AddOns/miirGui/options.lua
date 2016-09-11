		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function()	
			-- Creation of the options menu
			
			miirgui.panel = CreateFrame( "Frame", "miirguiPanel", UIParent)
			miirgui.panel.name = "MiirGui Texture Pack";
			InterfaceOptions_AddCategory(miirgui.panel);
			miirgui.childpanel = CreateFrame( "Frame", "miirguiChild", miirgui.panel)
			miirgui.childpanel:SetPoint("TOPLEFT",miirguiPanel,0,0)
			miirgui.childpanel:SetPoint("BOTTOMRIGHT",miirguiPanel,0,0)
			InterfaceOptions_AddCategory(miirgui.childpanel)
			local version = GetAddOnMetadata("miirGui", "Version")
			local fontstring = miirgui.childpanel:CreateFontString()
			fontstring:SetFont("Fonts\\FRIZQT__.TTF", 14,"OUTLINE")
			fontstring:SetText("MiirGui Texture Pack Settings (Version "..version..")")
			fontstring:SetPoint("TOPLEFT",6,-10)
			fontstring:SetTextColor(unpack(miirgui.Color))
			
			local fontstring2 = miirgui.childpanel:CreateFontString()
			fontstring2:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring2:SetText("+ Color Settings + (reload required)")
			fontstring2:SetPoint("TOPLEFT",6,-26)
			
			
			local blue = CreateFrame("Button","Blue",miirgui.childpanel,"UIPanelButtonTemplate")
			blue:SetPoint("TOPLEFT",6,-42)
			blue:SetSize(100,22)
			blue:SetText("Blue")
			if miirguiDB["blue"] == true then
			blue:Disable()
			end
			blue:SetScript("OnClick", function()
				miirguiDB["green"] = false
				miirguiDB["grey"] = false
				miirguiDB["blue"] = true
				print("MiirGui Texture Pack Set to Blue. Please proceed and reload your UI.")
			end)

			local grey = CreateFrame("Button","Grey",blue,"UIPanelButtonTemplate")
			grey:SetPoint("CENTER",0,-20)
			grey:SetSize(100,22)
			grey:SetText("Grey")
			if miirguiDB["grey"] == true then
			grey:Disable()
			end
			grey:SetScript("OnClick", function()
					miirguiDB["green"] = false
					miirguiDB["blue"] = false
					miirguiDB["grey"] = true
					print("MiirGui Texture Pack Set to Grey. Please proceed and reload your UI.")
			end)

			local green = CreateFrame("Button","Green",grey,"UIPanelButtonTemplate")
			green:SetPoint("CENTER",0,-20)
			green:SetSize(100,22)
			green:SetText("Green")
			if miirguiDB["green"] == true then
			green:Disable()
			end
			green:SetScript("OnClick", function()
					miirguiDB["green"] = true
					miirguiDB["blue"] = false
					miirguiDB["grey"] = false
					print("MiirGui Texture Pack Set to Green. Please proceed and reload your UI.")
			end)
			
			local fontstring3 = miirgui.childpanel:CreateFontString()
			fontstring3:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring3:SetText("+ Misc Settings + (reload required)")
			fontstring3:SetPoint("LEFT",green,0,-20)
			
			local frame = CreateFrame("CheckButton", "save", green, "UICheckButtonTemplate")
			frame:SetPoint("LEFT", -3, -40)
			frame.text:SetText("CPU Saver")
			m_fontify(frame.text,"white")
			if miirguiDB["savemode"] == true then
				frame:SetChecked(true)
			end
			
			frame:SetScript("OnClick", function()
				if frame:GetChecked() then
					miirguiDB["savemode"] = true
					print("CPU Saver activated. Please proceed and reload your UI.")
				else
					miirguiDB["savemode"] = false
					print("CPU Saver de-activated. Please proceed and reload your UI.")
				end
			end)
			
			local reload = CreateFrame("Button","reload",green,"UIPanelButtonTemplate")
			reload:SetPoint("CENTER",0,-60)
			reload:SetSize(100,22)
			reload:SetText("Reload")
			reload:SetScript("OnClick", function()
				ReloadUI()
			end)
					
			local fontstring5 = miirgui.childpanel:CreateFontString()
			fontstring5:SetFont("Fonts\\FRIZQT__.TTF", 14,"OUTLINE")
			fontstring5:SetTextColor(unpack(miirgui.Color))
			fontstring5:SetText("Frequently asked questions")
			fontstring5:SetPoint("LEFT",green,0,-80)
			
			local fontstring6 = miirgui.childpanel:CreateFontString()
			fontstring6:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring6:SetText("+ What is this CPU Saver ?")
			fontstring6:SetPoint("LEFT",green,0,-100)
			
			local fontstring7 = miirgui.childpanel:CreateFontString()
			fontstring7:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring7:SetText("CPU Saver disables all font-outlines. This should allow a better performance on old machines.")
			fontstring7:SetPoint("LEFT",green,0,-120)
			
			local fontstring8 = miirgui.childpanel:CreateFontString()
			fontstring8:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring8:SetText("+ Why is there a button for green color but no green texture pack ?")
			fontstring8:SetPoint("LEFT",green,0,-140)
			
			local fontstring9 = miirgui.childpanel:CreateFontString()
			fontstring9:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring9:SetText("Some people might have a green version... :o")
			fontstring9:SetPoint("LEFT",green,0,-160)
			
			-- SLASH  Command
		
			SLASH_MIIRGUI1 = "/miirgui"

			SlashCmdList["MIIRGUI"] = function()
				InterfaceOptionsFrame_OpenToCategory(miirguiPanel)	
				InterfaceOptionsFrame_OpenToCategory(miirguiPanel)
			end
			
			
			
		end) 