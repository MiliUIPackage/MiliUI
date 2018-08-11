local function skin_ContainerFrame()

	-- Bank

	BankPortraitTexture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	BankPortraitTexture:SetPoint("TOPLEFT",-8,9)
	BankPortraitTexture:SetWidth(64)
	BankPortraitTexture:SetHeight(64)
	BankFrameBg:SetColorTexture(0.078,0.078,0.078,1)

	local function miirgui_BankFrameItemButton_Update(button)
		local container = button:GetParent():GetID()
		local buttonID = button:GetID()
		if( button.isBag ) then
			container = -4
		end
		local _,_,_,quality = GetContainerItemInfo(container, buttonID)
		if (quality) then
			local r, g, b, hex = GetItemQualityColor(quality)
			button.IconBorder:Show()
			m_SetTexture(button.IconBorder,"Interface\\Containerframe\\quality.blp")
			button.IconBorder:SetVertexColor( r, g, b, hex)
			button.Count:ClearAllPoints()
			button.Count:SetPoint("CENTER", 0, -9)
			button.Count:SetJustifyH("CENTER")
		else
			button.IconBorder:Hide()
		end
	end

	hooksecurefunc("BankFrameItemButton_Update",miirgui_BankFrameItemButton_Update)

	-- Bags

	BagHelpBoxBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
	BagHelpBoxBg:SetColorTexture(0.078,0.078,0.078,1)
	m_border(BagHelpBox,226,128,"CENTER",0,0,14,"DIALOG")
	m_border_BagHelpBox:SetPoint("TOPLEFT","BagHelpBox",-3,3)
	m_border_BagHelpBox:SetPoint("BOTTOMRIGHT","BagHelpBox",3,-3)
	m_fontify(BagHelpBox.Text,"white")

	for i=1,12 do
		_G["ContainerFrame"..i.."Portrait"]:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	end

	local function miirgui_ContainerFrame_Update(frame)
		local id = frame:GetID();
		local name = frame:GetName();
		local itemButton;
		for i=1, frame.size, 1 do
			itemButton = _G[name.."Item"..i];
			local _,_,_,quality = GetContainerItemInfo(id, itemButton:GetID())
			if quality then
				local r, g, b, hex = GetItemQualityColor(quality)
				m_SetTexture(itemButton.IconBorder,"Interface\\Containerframe\\quality.blp")
				itemButton.IconBorder:SetVertexColor(r,g,b,hex);
				itemButton.IconBorder:Show();
				itemButton.Count:ClearAllPoints()
				itemButton.Count:SetPoint("CENTER", 0, -9)
				itemButton.Count:SetJustifyH("CENTER")
			end
		end
	end

	hooksecurefunc("ContainerFrame_Update",miirgui_ContainerFrame_Update)

	local function Container_OnShow(frame)
		frame.FilterIcon:SetPoint("CENTER",frame.Portrait,10,0.5)
	end

	for i=1, NUM_CONTAINER_FRAMES do
		local frame = _G["ContainerFrame"..i]
		if frame then
			frame:HookScript("OnShow", Container_OnShow)
		end
	end

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_ContainerFrame)