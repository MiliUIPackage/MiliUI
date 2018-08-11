local function skin_Blizzard_MacroUI()
	for i=19,21 do
		local hideit= select(i,MacroFrame:GetRegions() )
		hideit:Hide()
	end
	local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,MacroFramePortraitmiirgui = MacroFrame:GetRegions()
	MacroFramePortraitmiirgui:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	MacroFramePortraitmiirgui:SetPoint("TOPLEFT",-8,9)
	MacroFramePortraitmiirgui:SetWidth(64)
	MacroFramePortraitmiirgui:SetHeight(64)

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_MacroUI" then
		skin_Blizzard_MacroUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_MacroUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_MacroUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)