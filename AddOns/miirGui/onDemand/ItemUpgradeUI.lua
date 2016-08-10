local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_ItemUpgradeUI" then
		ItemUpgradeFrameCornerTL:Hide()
		ItemUpgradeFrameCornerTR:Hide()
		ItemUpgradeFrameCornerBL:Hide()
		ItemUpgradeFrameCornerBR:Hide()
		ItemUpgradeFrameLeftEdge:Hide()
		ItemUpgradeFrameRightEdge:Hide()
		ItemUpgradeFrameTopEdge:Hide()
		ItemUpgradeFrameBottomEdge:Hide()
		for i=2,4 do
			local hideit= select(i,ItemUpgradeFrame.ItemButton:GetRegions() )
			hideit:Hide() 
		end
		local hideit= select(8,ItemUpgradeFrame.ItemButton:GetRegions() )
		hideit:Hide() 
		ItemUpgradeFramePortrait:SetTexCoord(0.13, 0.83, 0.13, 0.83)
		ItemUpgradeFrame.ButtonFrame:GetRegions():Hide()
		ItemUpgradeFrame.ButtonFrame.ButtonBorder:Hide()
		ItemUpgradeFrame.ButtonFrame.ButtonBottomBorder:Hide()
		local ItemUpgradeFrameHeaderTintage = select(23,ItemUpgradeFrame:GetRegions())
		ItemUpgradeFrameHeaderTintage:SetColorTexture(0.128,0.117,0.128,1)
		local ItemUpgradeFrameBackgroundTintage = select(25, ItemUpgradeFrame:GetRegions())
		ItemUpgradeFrameBackgroundTintage:SetColorTexture(0.078,0.078,0.078,1) 
		local ItemUpgradeFrameBackgroundTintage2 = select(27, ItemUpgradeFrame:GetRegions())
		ItemUpgradeFrameBackgroundTintage2:SetColorTexture(0,0,0,0)
		m_border(ItemUpgradeFrame.ItemButton,60,60,"CENTER",0,0,14,"HIGH")
		m_border(ItemUpgradeFrame.ItemButton,330,60,"CENTER",196,0,14,"HIGH")
			
		local function miirgui_ItemUpgradeFrame_Update()
			local icon = select(1,GetItemUpgradeItemInfo())
			if icon then
				local showit= select(1,ItemUpgradeFrame.ItemButton:GetRegions() )
				showit:Show() 
			else	
				local hideit= select(1,ItemUpgradeFrame.ItemButton:GetRegions() )
				hideit:Hide() 
			end
		end

		hooksecurefunc("ItemUpgradeFrame_Update", miirgui_ItemUpgradeFrame_Update)
			
	end
end

frame:SetScript("OnEvent", frame.OnEvent);