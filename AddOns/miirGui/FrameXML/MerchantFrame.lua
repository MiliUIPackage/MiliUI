local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

local frame = CreateFrame("Frame");
frame:RegisterEvent("MERCHANT_SHOW")
MerchantFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
BuybackBG:SetColorTexture(0.078,0.078,0.078,1)
		
function frame:OnEvent(event)
	if event == "MERCHANT_SHOW" then
	MerchantExtraCurrencyInset:Show();
	end
end
		
frame:SetScript("OnEvent", frame.OnEvent);
end)