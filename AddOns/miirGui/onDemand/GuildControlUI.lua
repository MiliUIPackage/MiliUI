local function skin_Blizzard_GuildControlUI()
	GuildControlUIHbar:Hide()
	GuildControlUITopBg:Hide()
	for i =1,8 do
		local hideit= select(i,GuildControlUIRankBankFrameInset:GetRegions())
		hideit:Hide()
	end
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_GuildControlUI" then
		skin_Blizzard_GuildControlUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GuildControlUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_GuildControlUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)