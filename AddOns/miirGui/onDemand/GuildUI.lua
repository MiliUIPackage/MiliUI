local function skin_Blizzard_GuildUI()
	GuildInfoDetailsFrameScrollBarTrack:SetAlpha(0)
	GuildNewsContainerScrollBarTrack:SetAlpha(0)
	GuildPerksContainerScrollBarTrack:Hide()
	GuildLogScrollFrameScrollBarTrack:Hide()
	GuildTextEditScrollFrameScrollBarTrack:Hide()
	GuildRewardsFrameBg:Hide()
	m_border(GuildNewsFrame,328,318,"CENTER",0.5,0.5,14,"MEDIUM")
	m_border(GuildRewardsFrame,328,318,"TOP",0.5,0,14,"MEDIUM")
	m_border(GuildInfoFrame,328,336,"TOP",0.5,1,14,"MEDIUM")
	m_border(GuildRosterFrame,330,310,"CENTER",-1,-32,14,"MEDIUM")
	m_border(GuildPerksFrame,330,340,"CENTER",-1,0,12,"MEDIUM")
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_GuildUI" then
		skin_Blizzard_GuildUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GuildUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_GuildUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)