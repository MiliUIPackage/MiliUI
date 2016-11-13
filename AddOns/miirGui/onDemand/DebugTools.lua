local function skin_DebugTools()
	ScriptErrorsFrameTitleBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
	ScriptErrorsFrameDialogBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	ScriptErrorsFrameTopRight:Hide()
	ScriptErrorsFrameTopLeft:Hide()
	ScriptErrorsFrameBottomRight:Hide()
	ScriptErrorsFrameBottomLeft:Hide()
	ScriptErrorsFrameLeft:Hide()
	ScriptErrorsFrameRight:Hide()
	ScriptErrorsFrameTop:Hide()
	ScriptErrorsFrameBottom:Hide()
	ScriptErrorsFrameTitleBG:ClearAllPoints()
	ScriptErrorsFrameTitleBG:SetPoint("TOP",ScriptErrorsFrame,2,-7)
	ScriptErrorsFrameTitleBG:SetSize(368,16)
	m_border(ScriptErrorsFrameTitleButton,372,20,"TOP",-0.5,1.5,9,"TOOLTIP")
	m_border(ScriptErrorsFrameScrollFrame,372,248,"Center",10,-2.5,9,"TOOLTIP")
end


local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()	
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_DebugTools" then
			skin_DebugTools()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_DebugTools") then
		skin_DebugTools()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)

