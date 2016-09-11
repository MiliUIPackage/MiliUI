local function skin_Blizzard_GuildControlUI()
		GuildControlUIHbar:Hide()
		GuildControlUITopBg:Hide()
		for i =1,8 do
			local hideit= select(i,GuildControlUIRankBankFrameInset:GetRegions())
			hideit:Hide()
		end
end

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildControlUI" then
			skin_Blizzard_GuildControlUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_GuildControlUI") then
		skin_Blizzard_GuildControlUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)