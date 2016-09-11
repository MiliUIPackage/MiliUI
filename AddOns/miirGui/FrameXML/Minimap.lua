local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()	
	Minimap:SetMaskTexture("Interface\\AddOns\\miirGui\\gfx\\Mask-SQUARE")
	--local function GetMinimapShape() return "SQUARE" end

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

	MiniMapWorldMapButton:Hide()
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


	local _,_,_,_,Date = GameTimeFrame:GetRegions()
	m_fontify(Date,"white")

end)