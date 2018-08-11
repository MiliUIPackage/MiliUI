local function skin_Blizzard_TalkingHeadUI()
	hooksecurefunc("TalkingHeadFrame_PlayCurrent",function()
		m_fontify(TalkingHeadFrame.NameFrame.Name,"color")
		m_fontify(TalkingHeadFrame.TextFrame.Text,"white")
	end)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_TalkingHeadUI" then
		skin_Blizzard_TalkingHeadUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_TalkingHeadUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_TalkingHeadUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)