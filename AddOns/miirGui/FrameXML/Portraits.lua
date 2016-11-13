PlayerPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
TargetFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
TargetFrameToTPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
TargetFrameToTPortrait:SetSize(38,38)
FocusFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
FocusFrameToTPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
FocusFrameToTPortrait:SetSize(38,38)
PetPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame1Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame1PetFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame2Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame2PetFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame3Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame3PetFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame4Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
PartyMemberFrame4PetFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

hooksecurefunc("PlayerFrame_ToVehicleArt",function(_, vehicleType)
	if ( vehicleType == "Natural" ) then
		PlayerFrameHealthBar:SetWidth(112);
		PlayerFrameHealthBar:SetPoint("TOPLEFT",106,-41);
		PlayerFrameManaBar:SetWidth(112);
		PlayerFrameManaBar:SetPoint("TOPLEFT",106,-52);
	else
		PlayerFrameHealthBar:SetWidth(112);
		PlayerFrameHealthBar:SetPoint("TOPLEFT",106,-41);
		PlayerFrameManaBar:SetWidth(112);
		PlayerFrameManaBar:SetPoint("TOPLEFT",106,-52);
	end
end)
