local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildControlUI" then
		GuildControlUIHbar:Hide()
		GuildControlUITopBg:Hide()
		for i =1,8 do
			local hideit= select(i,GuildControlUIRankBankFrameInset:GetRegions())
			hideit:Hide()
		end
	end
end

frame:SetScript("OnEvent", frame.OnEvent);