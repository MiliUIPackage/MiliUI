local function skin_Blizzard_AzeriteRespecUI()
	
	AzeriteRespecFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,AzeriteRespecFramepurpleBg=AzeriteRespecFrame:GetRegions()
	AzeriteRespecFramepurpleBg:Hide()

	AzeriteRespecFrameTopEdge:Hide()
	AzeriteRespecFrameBottomEdge:Hide()
	AzeriteRespecFrameLeftEdge:Hide()
	AzeriteRespecFrameRightEdge:Hide()
	AzeriteRespecFrameCornerTR:Hide()
	AzeriteRespecFrameCornerTL:Hide()
	AzeriteRespecFrameCornerBR:Hide()
	AzeriteRespecFrameCornerBL:Hide()
	local AzeriteRespecFramebuttonframeBg=AzeriteRespecFrame.ButtonFrame:GetRegions()
	AzeriteRespecFramebuttonframeBg:Hide()
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_AzeriteRespecUI" then
		skin_Blizzard_AzeriteRespecUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_AzeriteRespecUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_AzeriteRespecUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)