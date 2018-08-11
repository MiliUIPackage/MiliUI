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
	ScriptErrorsFrameTitleBG:SetPoint("TOP",ScriptErrorsFrame,1,-7)
	ScriptErrorsFrameTitleBG:SetSize(370,16)
	
	m_border(ScriptErrorsFrame,372,20,"CENTER",1,116,10,"TOOLTIP")
	m_border(ScriptErrorsFrame.ScrollFrame,371.5,230,"Center",9.5,-11.5,9,"TOOLTIP")

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_DebugTools" then
		skin_DebugTools()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_DebugTools") then
		-- Addon is already loaded, procceed to skin!
		skin_DebugTools()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)
