local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()	

	if miirguiDB.skinminimap == true then
		Minimap:SetMaskTexture("Interface\\AddOns\\miirGui\\gfx\\Mask-SQUARE")
		local _,_,_,_,Date = GameTimeFrame:GetRegions()
		m_fontify(Date,"white")

		Minimap:EnableMouseWheel(true)
		MinimapZoomOut:Hide()
		MinimapZoomIn:Hide()
		Minimap:SetScript("OnMouseWheel", function(zoom,arg)
			if arg > 0 and zoom:GetZoom() < 5 then
					zoom:SetZoom(zoom:GetZoom() + 1)
			elseif arg < 0 and zoom:GetZoom() > 0 then
			  zoom:SetZoom(zoom:GetZoom() - 1)
		  end
		end)

		MiniMapWorldMapButton:SetAlpha(0)
		MinimapZoneTextButton:SetPoint("Center", Minimap, "Top", 8,8)

		hooksecurefunc("Minimap_UpdateRotationSetting", function()
			if ( GetCVar("rotateMinimap") == "1" ) then
				MinimapCompassTexture:Show();
				MinimapNorthTag:Hide();
			else
				MinimapCompassTexture:Hide();
				MinimapNorthTag:Hide();
			end
		end)
	end
	
	hooksecurefunc("GarrisonLandingPageMinimapButton_UpdateIcon",function(self)
		local _,pulse = self:GetRegions()
		pulse:SetSize(36,36)
		m_SetTexture(pulse,"Interface\\Garrison\\pulse.blp")
		self:SetSize(32,32)	
		self:SetNormalTexture("Interface\\Garrison\\horde.blp")
		self:SetPushedTexture("Interface\\Garrison\\horde.blp")		
		self:UnregisterEvent("SHIPMENT_UPDATE")
	end)
	
end)