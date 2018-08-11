local function skin_Blizzard_Communities()
	CommunitiesFrame.PortraitOverlay.CircleMask:Hide()
	CommunitiesFrame.PortraitOverlay.Portrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	CommunitiesFrame.ChatTab.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	CommunitiesFrame.RosterTab.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	
	ChannelFrame.Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	ChannelFrame.Icon:SetPoint("TOPLEFT",-8,8)
	ChannelFrame.Icon:SetSize(62,62)
	CommunitiesFrameCommunitiesListListScrollFrame.ScrollBar.Background:Hide()
	m_border(ChannelFrame,396,340,"CENTER",-2,-17.5,14,"HIGH")

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_Communities" then
		skin_Blizzard_Communities()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_Communities") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_Communities()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)