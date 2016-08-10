local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_VoidStorageUI" then
		
		VoidStorageHelpBoxBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		VoidStorageHelpBoxBg:SetColorTexture(0.078,0.078,0.078,1)
		m_border(VoidStorageHelpBox,226,62,"CENTER",0,0,14,"DIALOG")
		m_border_VoidStorageHelpBox:SetPoint("TOPLEFT","VoidStorageHelpBox",-3,3)
		m_border_VoidStorageHelpBox:SetPoint("BOTTOMRIGHT","VoidStorageHelpBox",3,-3)	
		m_fontify(VoidStorageHelpBoxBigText,"white")	
		m_fontify(VoidStorageHelpBoxSmallText,"white")	
		
		local function miirgui_VoidStorage_ItemsUpdate(doDeposit, doContents)
			local self = VoidStorageFrame
			local button
			if ( doDeposit ) then
				for i = 1, 9 do
					local quality=select(3,GetVoidTransferDepositInfo(i))
					button = _G["VoidStorageDepositButton"..i]
					if quality then
						button.IconBorder:SetTexture("Interface\\Containerframe\\quality.blp")
						button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
					end
				end
			end
			if ( doContents ) then
				for i = 1,9 do
					local quality=select(3,GetVoidTransferWithdrawalInfo(i))
					button = _G["VoidStorageWithdrawButton"..i]
					if quality then
						button.IconBorder:SetTexture("Interface\\Containerframe\\quality.blp")
						button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
					end
				end

				for i = 1, 80 do
					local quality= select(6,GetVoidItemInfo(self.page, i))
					button = _G["VoidStorageStorageButton"..i];
					if quality then
						button.IconBorder:SetTexture("Interface\\Containerframe\\quality.blp")
						button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
					end
				end
			end
		end

		hooksecurefunc("VoidStorage_ItemsUpdate", miirgui_VoidStorage_ItemsUpdate)

		VoidStoragePurchaseFrameCornerTL:Hide()
		VoidStoragePurchaseFrameCornerTR:Hide()
		VoidStoragePurchaseFrameCornerBL:Hide()
		VoidStoragePurchaseFrameCornerBR:Hide()
		VoidStoragePurchaseFrameLeftEdge:Hide()
		VoidStoragePurchaseFrameRightEdge:Hide()
		VoidStoragePurchaseFrameTopEdge:Hide()
		VoidStoragePurchaseFrameBottomEdge:Hide()
		VoidStorageBorderFrameLeftEdge:Hide()
		VoidStorageBorderFrameRightEdge:Hide()
		VoidStorageBorderFrameTopEdge:Hide()
		VoidStorageBorderFrameBottomEdge:Hide()
		VoidStorageBorderFrameHeader:Hide()
		VoidStorageBorderFrameCornerTL:Hide()
		VoidStorageBorderFrameCornerTR:Hide()
		VoidStorageBorderFrameCornerBL:Hide()
		VoidStorageBorderFrameCornerBR:Hide()
		VoidStorageDepositFrameBg:Hide()
		VoidStorageWithdrawFrameBg:Hide()
		VoidStorageStorageFrameLine1:Hide()
		VoidStorageStorageFrameLine1:SetWidth(1)
		VoidStorageStorageFrameLine2:Hide()
		VoidStorageStorageFrameLine2:SetWidth(1)
		VoidStorageStorageFrameLine3:Hide()
		VoidStorageStorageFrameLine3:SetWidth(1)
		VoidStorageStorageFrameLine4:Hide()
		VoidStorageStorageFrameLine4:SetWidth(1)
		local VoidStoragePurchaseTintage = select (2,VoidStoragePurchaseFrame:GetRegions())
		VoidStoragePurchaseTintage:Hide()
		local VoidStorageFrameFix1 = select (2,VoidStorageFrame:GetRegions())
		VoidStorageFrameFix1:SetColorTexture(1,1,1,0)
		local Portrait1= select(4,VoidStorageFrame.Page1:GetRegions() )
		Portrait1:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		local Portrait2= select(4,VoidStorageFrame.Page2:GetRegions() )
		Portrait2:SetTexCoord(0.85, 0.15, 0.15, 0.85)		
		m_border(VoidStoragePurchaseFrame,496,184,"CENTER",0,0,14,"MEDIUM")
	end
end

frame:SetScript("OnEvent", frame.OnEvent);