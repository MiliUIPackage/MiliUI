local function skin_Blizzard_ObliterumUI()

	ObliterumForgeFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	ObliterumForgeFrameInsetBg:Hide()
	m_border(ObliterumForgeFrame,326,164,"CENTER",0,-18,12,"DIALOG")

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

-- function to catch loading addons

local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ObliterumUI" then
		skin_Blizzard_ObliterumUI()
	end
end

-- this function checks whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ObliterumUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ObliterumUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)