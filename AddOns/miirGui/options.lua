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
			
			-- color choosing
			
			local blue = CreateFrame("Button","Blue",miirgui.childpanel,"UIPanelButtonTemplate")
			blue:SetPoint("TOPLEFT",6,-42)
			blue:SetSize(100,22)
			blue:SetText("Blue")
			if miirguiDB.blue == true then
				blue:Disable()
			end

			local grey = CreateFrame("Button","Grey",blue,"UIPanelButtonTemplate")
			grey:SetPoint("CENTER",0,-20)
			grey:SetSize(100,22)
			grey:SetText("Grey")
			if miirguiDB.grey == true then
				grey:Disable()
			end

			local green = CreateFrame("Button","Green",grey,"UIPanelButtonTemplate")
			green:SetPoint("CENTER",0,-20)
			green:SetSize(100,22)
			green:SetText("Green")
			if miirguiDB.green == true then
				green:Disable()
			end

			blue:SetScript("OnClick", function()
				miirguiDB.green = false
				miirguiDB.grey = false
				miirguiDB.blue = true
				blue:Disable()
				grey:Enable()
				green:Enable()
			end)			
			blue:SetScript("OnEnter", function()			
				GameTooltip:SetOwner(blue,"ANCHOR_TOP");
				GameTooltip:AddLine("Activate blue color scheme.")
				GameTooltip:Show()
			end)
			
			blue:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			
			grey:SetScript("OnClick", function()
				miirguiDB.green = false
				miirguiDB.grey = true
				miirguiDB.blue = false
				blue:Enable()
				grey:Disable()
				green:Enable()
			end)		
			grey:SetScript("OnEnter", function()			
				GameTooltip:SetOwner(grey,"ANCHOR_TOP");
				GameTooltip:AddLine("Activate grey colors scheme.")
				GameTooltip:Show()
			end)
			
			grey:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			
			green:SetScript("OnClick", function()
				miirguiDB.green = true
				miirguiDB.grey = false
				miirguiDB.blue = false
				blue:Enable()
				grey:Enable()
				green:Disable()
			end)	
			green:SetScript("OnEnter", function()			
				GameTooltip:SetOwner(green,"ANCHOR_TOP");
				GameTooltip:AddLine("Activate green color scheme.")
				GameTooltip:Show()
			end)
			
			green:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			
			-- Misc Settings
			
			local fontstring3 = miirgui.childpanel:CreateFontString()
			fontstring3:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring3:SetText("+ Misc Settings + (reload required)")
			fontstring3:SetPoint("LEFT",green,0,-20)
			
			--cpu saver
			
			local save = CreateFrame("CheckButton", "save", green, "UICheckButtonTemplate")
			save:SetPoint("LEFT", -3, -40)
			save.text:SetText("CPU Saver")
			m_fontify(save.text,"white")
			if miirguiDB.savemode== true then
				save:SetChecked(true)
			end	
			save:SetScript("OnClick", function()
				if save:GetChecked() then
					miirguiDB.savemode = true
				else
					miirguiDB.savemode = false
				end
			end)
			
			local bonus = CreateFrame("CheckButton", "bonus", save, "UICheckButtonTemplate")
			bonus:SetPoint("CENTER",0, -20)
			bonus.text:SetText("Skin lootroll frames")
			m_fontify(bonus.text,"white")
			if miirguiDB.rolls == true then
				bonus:SetChecked(true)
			end
			bonus:SetScript("OnClick", function()
				if bonus:GetChecked() then
					miirguiDB.rolls = true
				else
					miirguiDB.rolls = false
				end
			end)		
			
			
			if miirguiDB.alerpos.enable == true then
				AlertFrame:ClearAllPoints()
				AlertFrame:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y)
			end
		
			local dummyalert = CreateFrame("FRAME","dummyalert",UIParent)
			dummyalert:SetSize(512,64)
			dummyalert:SetFrameStrata("DIALOG")
			dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+60)
			dummyalert:SetBackdrop({
			bgFile = "Interface\\Achievementframe\\miirgui_ach.tga",
			})
			dummyalert:Hide()
				
			local alertpos = CreateFrame("CheckButton", "alertpos",bonus,"UICheckButtonTemplate")
			alertpos:SetPoint("CENTER",0,-20)
			alertpos.text:SetText("Move alertframes")
			m_fontify(alertpos.text,"white")
			if miirguiDB.alerpos.enable == true then
				alertpos:SetChecked(true)
			end
			alertpos:SetScript("OnClick", function()
				if alertpos:GetChecked() then
					miirguiDB.alerpos.enable = true
					alert_x:Show()
				else
					alert_x:Hide()
					miirguiDB.alerpos.enable =false
				end
			end)
		
			local alert_x = CreateFrame("EditBox", "alert_x", alertpos, "InputBoxTemplate");
			alert_x:SetAutoFocus(false)
			alert_x:SetPoint("LEFT", 144,0);
			alert_x:SetSize(40,20)
			alert_x:SetNumber(miirguiDB.alerpos.x)
			alert_x:SetCursorPosition(0)
			alert_x:SetScript("OnEditFocusLost",function()
				alert_x:ClearFocus()
				miirguiDB.alerpos.x = alert_x:GetNumber()	
				dummyalert:ClearAllPoints()
				dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+60)

			end)
			
			alert_x:SetScript("OnEnterPressed",function()
				alert_x:ClearFocus()
				miirguiDB.alerpos.x = alert_x:GetNumber()	
				dummyalert:ClearAllPoints()
				dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB["alerpos"].y+60)
			end)
			if miirguiDB.alerpos.enable == true then
				alert_x:Show()
			else
				alert_x:Hide()
			end
			
			local alert_y = CreateFrame("EditBox", "alert_y", alert_x, "InputBoxTemplate");
			alert_y:SetAutoFocus(false)
			alert_y:SetPoint("LEFT", 46,0);
			alert_y:SetSize(40,20)
			alert_y:SetNumber(miirguiDB.alerpos.y)
			alert_y:SetCursorPosition(0)
			alert_y:SetScript("OnEditFocusLost",function()
				alert_y:ClearFocus()
				miirguiDB.alerpos.y = alert_y:GetNumber()	
				dummyalert:ClearAllPoints()
				dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+60)

			end)
			alert_y:SetScript("OnEnterPressed",function()
				alert_y:ClearFocus()
				miirguiDB.alerpos.y = alert_y:GetNumber()	
				dummyalert:ClearAllPoints()
				dummyalert:SetPoint("CENTER","UIParent",miirguiDB.alerpos.x,miirguiDB.alerpos.y+60)

			end)
					
			local dummyalerpos = CreateFrame("Button","dummyalerpos",alert_y,"UIPanelButtonTemplate")
			dummyalerpos:SetPoint("LEFT",46,0)
			dummyalerpos:SetSize(100,22)
			dummyalerpos:SetText("Show Dummy")
			dummyalerpos:SetScript("OnClick", function()		
				if dummyalert:IsShown() then
					dummyalert:Hide()
				else
					dummyalert:Show()
				end
			end)		
			
			local skinminimap = CreateFrame("CheckButton", "skinminimap",alertpos,"UICheckButtonTemplate")
			skinminimap:SetPoint("CENTER",0,-20)
			skinminimap.text:SetText("Skin minimap (relogg required)")
			m_fontify(skinminimap.text,"white")
			if miirguiDB.skinminimap == true then
				skinminimap:SetChecked(true)
			end
			skinminimap:SetScript("OnClick", function()
				if skinminimap:GetChecked() then
					miirguiDB.skinminimap = true
				else
					miirguiDB.skinminimap = false
				end
			end)
			
			local cbar = CreateFrame("CheckButton", "cbar", skinminimap, "UICheckButtonTemplate")
			cbar:SetPoint("CENTER",0, -20)
			cbar.text:SetText("Hide orderhall command bar")
			m_fontify(cbar.text,"white")
			if miirguiDB.cbar == true then
				cbar:SetChecked(true)
			end
			cbar:SetScript("OnClick", function()
				if cbar:GetChecked() then
					miirguiDB.cbar = true	
					if OrderHallCommandBar then
						OrderHallCommandBar:SetAlpha(0)
					end
				else
					if OrderHallCommandBar then
						OrderHallCommandBar:SetAlpha(1)
					end
					miirguiDB.cbar = false	
				end
			end)		

			
			local reload = CreateFrame("Button","reload",green,"UIPanelButtonTemplate")
			reload:SetPoint("CENTER",0,-140)
			reload:SetSize(100,22)
			reload:SetText("Reload")
			reload:SetScript("OnClick", function()
				ReloadUI()
			end)
	
			local fontstring5 = miirgui.childpanel:CreateFontString()
			fontstring5:SetFont("Fonts\\FRIZQT__.TTF", 14,"OUTLINE")
			fontstring5:SetTextColor(unpack(miirgui.Color))
			fontstring5:SetText("Frequently asked questions")
			fontstring5:SetPoint("LEFT",green,0,-160)
			
			local fontstring6 = miirgui.childpanel:CreateFontString()
			fontstring6:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring6:SetText("+ What is this CPU Saver ?")
			fontstring6:SetPoint("LEFT",green,0,-180)
			
			local fontstring7 = miirgui.childpanel:CreateFontString()
			fontstring7:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring7:SetText("CPU Saver disables all font-outlines. This should allow a better performance on old machines.")
			fontstring7:SetPoint("LEFT",green,0,-200)
			
			local fontstring8 = miirgui.childpanel:CreateFontString()
			fontstring8:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring8:SetText("+ Why is there a button for green color but no green texture pack ?")
			fontstring8:SetPoint("LEFT",green,0,-220)
			
			local fontstring9 = miirgui.childpanel:CreateFontString()
			fontstring9:SetFont("Fonts\\FRIZQT__.TTF", 12,"OUTLINE")
			fontstring9:SetText("Some people might have a green version... :o")
			fontstring9:SetPoint("LEFT",green,0,-240)
			
			-- SLASH  Command
		
			SLASH_MIIRGUI1 = "/miirgui"

			SlashCmdList["MIIRGUI"] = function()
				InterfaceOptionsFrame_OpenToCategory(miirguiPanel)	
				InterfaceOptionsFrame_OpenToCategory(miirguiPanel)
			end
			
			
			
		end) 