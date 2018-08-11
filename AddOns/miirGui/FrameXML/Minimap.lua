local function skin_MiniMap()

	if miirguiDB.skinminimap == true then
	
		MiniMapInstanceDifficultyText:ClearAllPoints()
		MiniMapInstanceDifficultyText:SetPoint("TOPRIGHT",MiniMapInstanceDifficulty,-5,-3.5)
		MiniMapInstanceDifficultyText:SetJustifyH("LEFT")
		MiniMapInstanceDifficulty:ClearAllPoints()
		MiniMapInstanceDifficulty:SetPoint("TOPLEFT",Minimap,-2,2)
	
		Minimap:SetMaskTexture("Interface\\AddOns\\miirGui\\gfx\\Mask-SQUARE")
		local _,_,_,_,Date = GameTimeFrame:GetRegions()
		m_fontify(Date,"white")
		if miirguiDB["outline"] == false then
			local fontName, fontHeight = Date:GetFont()
			Date:SetFont(fontName, fontHeight, "OUTLINE")
		end

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

	local function miirgui_GarrisonLandingPageMinimapButton_UpdateIcon(self)
		local _,pulse = self:GetRegions()
		pulse:SetSize(36,36)
		m_SetTexture(pulse,"Interface\\Garrison\\pulse.blp")
		self:SetSize(32,32)
		self:SetNormalTexture("Interface\\Garrison\\horde.blp")
		self:SetPushedTexture("Interface\\Garrison\\horde.blp")
		self:UnregisterEvent("SHIPMENT_UPDATE")
	end

	hooksecurefunc("GarrisonLandingPageMinimapButton_UpdateIcon",miirgui_GarrisonLandingPageMinimapButton_UpdateIcon)

	ActionBarUpButton:ClearAllPoints()
	ActionBarUpButton:SetPoint("RIGHT",ActionButton12,25,9.5)

	ActionBarDownButton:ClearAllPoints()
	ActionBarDownButton:SetPoint("CENTER",ActionBarUpButton,"BOTTOMLEFT",9.5,-10.5)
	
end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_MiniMap)