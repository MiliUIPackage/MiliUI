local function skin_Blizzard_VoidStorageUI()

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
				local _,_,quality = GetVoidTransferDepositInfo(i)
				button = _G["VoidStorageDepositButton"..i]
				if quality then
					m_SetTexture(button.IconBorder,"Interface\\Containerframe\\quality.blp")
					button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
				end
			end
		end
		if ( doContents ) then
			for i = 1,9 do
				local _,_,quality = GetVoidTransferWithdrawalInfo(i)
				button = _G["VoidStorageWithdrawButton"..i]
				if quality then
					m_SetTexture(button.IconBorder,"Interface\\Containerframe\\quality.blp")
					button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
				end
			end

			for i = 1, 80 do
				local _,_,_,_,_,quality = GetVoidItemInfo(self.page, i)
				button = _G["VoidStorageStorageButton"..i];
				if quality then
					m_SetTexture(button.IconBorder,"Interface\\Containerframe\\quality.blp")
					button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
				end
			end
		end

		m_cursorfix(VoidItemSearchBox)

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
	local _,VoidStoragePurchaseTintage = VoidStoragePurchaseFrame:GetRegions()
	VoidStoragePurchaseTintage:Hide()
	local _,VoidStorageFrameFix1 = VoidStorageFrame:GetRegions()
	VoidStorageFrameFix1:SetColorTexture(1,1,1,0)
	local _,_,_,Portrait1= VoidStorageFrame.Page1:GetRegions()
	Portrait1:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	local _,_,_,Portrait2= VoidStorageFrame.Page2:GetRegions()
	Portrait2:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_border(VoidStoragePurchaseFrame,496,184,"CENTER",0,0,14,"MEDIUM")
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_VoidStorageUI" then
		skin_Blizzard_VoidStorageUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_VoidStorageUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_VoidStorageUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)