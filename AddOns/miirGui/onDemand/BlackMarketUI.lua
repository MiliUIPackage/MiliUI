local function skin_Blizzard_BlackMarketUI()

	m_SetTexture(BlackMarketFrameTitleBg,"Interface\\FrameGeneral\\UI-Background-Rock")
	BlackMarketScrollFrameScrollBarTrack:Hide()
	m_border(BlackMarketFrame,612,412,"CENTER",-116,-21,14,"MEDIUM")
	m_border(BlackMarketFrame.HotDeal.Item,34,34,"CENTER",-1,0,14,"MEDIUM")
	BlackMarketFrame.HotDeal.Item.IconBorder:SetAlpha(0)
	m_fontify(BlackMarketFrame.Inset.NoItems,"white")
	for i=12,22 do
		local hideit= select(i,BlackMarketFrame:GetRegions() )
		hideit:Hide()
	end

	local _,_,_,_,_,_,_,_,hideit = BlackMarketFrame:GetChildren()
	for i=1,8 do
		local hideit2 = select(i,hideit:GetRegions() )
		hideit2:Hide()
	end

	local function miirgui_BlackMarketScrollFrame_Update()
		local numItems = C_BlackMarket.GetNumItems();
		local scrollFrame = BlackMarketScrollFrame;
		local offset = HybridScrollFrame_GetOffset(scrollFrame);
		local buttons = scrollFrame.buttons;
		local numButtons = #buttons;
			for i = 1, numButtons do
				local button = buttons[i];
				local index = offset + i;
				if index and numItems and  ( index <= numItems ) then
					local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,quality =C_BlackMarket.GetItemInfoByIndex(index)
					if quality then
						m_SetTexture(button.Item.IconBorder,"Interface\\ContainerFrame\\quality.blp")
						button.Item.IconBorder:SetSize(36,36)
						button.Item:ClearAllPoints()
						button.Item:SetPoint("LEFT", _G["BlackMarketScrollFrameButton"..i], "LEFT",0,3)
						button.Item.IconTexture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
					end
				end
				local fixitleft,fixitright,fixitmiddle = _G["BlackMarketScrollFrameButton"..i]:GetRegions()
				fixitleft:ClearAllPoints()
				fixitleft:SetPoint("LEFT",38,3.5)
				fixitleft:SetHeight(36)

				fixitright:SetHeight(37)
				fixitright:ClearAllPoints()
				fixitright:SetPoint("RIGHT",0,3.5)

				fixitmiddle:ClearAllPoints()
				fixitmiddle:SetPoint("LEFT",40,3.5)
				fixitmiddle:SetSize(520,37)

				local selection=_G["BlackMarketScrollFrameButton"..i]

				local _,_,_,_,_,_,_,_,fixselection = selection:GetRegions()
				fixselection:ClearAllPoints()
				fixselection:SetPoint("CENTER",18.5,3.5)
				fixselection:SetSize(529.5,35)
				local _,_,_,_,_,_,_,_,_,highlight = _G["BlackMarketScrollFrameButton"..i]:GetRegions()
				highlight:ClearAllPoints()
				m_SetTexture(highlight,fixselection:GetTexture())
				highlight:SetPoint("CENTER",18,-9)
				highlight:SetSize(529.5,60)

				end
	end

	hooksecurefunc("BlackMarketScrollFrame_Update",miirgui_BlackMarketScrollFrame_Update)

	local function miirgui_BlackMarketFrame_UpdateHotItem()
		m_fontify(BlackMarketFrame.HotDeal.Title,"color")
		m_fontify(BlackMarketFrame.HotDeal.SellerTAG,"color")
		m_fontify(HotItemCurrentBidMoneyFrame.CurrentBid,"color")
	end

	hooksecurefunc("BlackMarketFrame_UpdateHotItem",miirgui_BlackMarketFrame_UpdateHotItem)

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_BlackMarketUI" then
		skin_Blizzard_BlackMarketUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_BlackMarketUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_BlackMarketUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)