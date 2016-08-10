local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
if event == "ADDON_LOADED" and arg1 == "Blizzard_BlackMarketUI" then
	
	BlackMarketFrameTitleBg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	BlackMarketScrollFrameScrollBarTrack:Hide()
	m_border(BlackMarketFrame,612,412,"CENTER",-116,-21,14,"MEDIUM")
	m_border(BlackMarketFrame.HotDeal.Item,34,34,"CENTER",-1,0,14,"MEDIUM")
	BlackMarketFrame.HotDeal.Item.IconBorder:SetAlpha(0)
	m_fontify(BlackMarketFrame.Inset.NoItems,"white")
	for i=12,22 do
		local hideit= select(i,BlackMarketFrame:GetRegions() )
		hideit:Hide()
	end
	
	local hideit= select(9,BlackMarketFrame:GetChildren() )
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
				if ( index <= numItems ) then
					local quality = select(17,C_BlackMarket.GetItemInfoByIndex(index))
					if quality then
						button.Item.IconBorder:SetTexture("Interface\\ContainerFrame\\quality.blp")
						button.Item.IconBorder:SetSize(36,36)
						button.Item:ClearAllPoints()
						button.Item:SetPoint("LEFT", _G["BlackMarketScrollFrameButton"..i], "LEFT",0,3)
						button.Item.IconTexture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
					end
				end
				local fixitleft= select(1,_G["BlackMarketScrollFrameButton"..i]:GetRegions() )
				fixitleft:ClearAllPoints()
				fixitleft:SetPoint("LEFT",38,3.5)
				fixitleft:SetHeight(36)	
				
				local fixitright= select(2,_G["BlackMarketScrollFrameButton"..i]:GetRegions() )
				fixitright:SetHeight(37)
				fixitright:ClearAllPoints()
				fixitright:SetPoint("RIGHT",0,3.5)
						
				local fixitmiddle= select(3,_G["BlackMarketScrollFrameButton"..i]:GetRegions() )
				fixitmiddle:ClearAllPoints()
				fixitmiddle:SetPoint("LEFT",40,3.5)
				fixitmiddle:SetSize(520,37)
						
				local selection =_G["BlackMarketScrollFrameButton"..i]

				local fixselection=select(9,selection:GetRegions())
				fixselection:ClearAllPoints()
				fixselection:SetPoint("CENTER",18.5,3.5)
				fixselection:SetSize(529.5,35)

				local highlight= select(10,_G["BlackMarketScrollFrameButton"..i]:GetRegions() )
				highlight:ClearAllPoints()
				highlight:SetTexture(fixselection:GetTexture())
				highlight:SetPoint("CENTER",18,-9)
				highlight:SetSize(529.5,60)

				m_fontify(button.Name,"same")
				m_fontify(button.Level,"same")
				m_fontify(button.Type,"same")
				m_fontify(button.TimeLeft.Text,"same")
				m_fontify(button.Seller,"same")
				m_fontify(_G["BlackMarketScrollFrameButton"..i.."CurrentBidMoneyFrameGoldButtonText"],"same")
			end
	end
	
	hooksecurefunc("BlackMarketScrollFrame_Update",miirgui_BlackMarketScrollFrame_Update)
	
	hooksecurefunc("BlackMarketFrame_UpdateHotItem",function(self)
		m_fontify(BlackMarketFrame.HotDeal.Title,"color")
		m_fontify(BlackMarketFrame.HotDeal.Name,"same")
		m_fontify(BlackMarketFrame.HotDeal.Type,"same")
		m_fontify(BlackMarketFrame.HotDeal.SellerTAG,"color")
		m_fontify(BlackMarketFrame.HotDeal.Seller,"same")
		m_fontify(BlackMarketFrame.HotDeal.TimeLeft.Text,"same")
		m_fontify(HotItemCurrentBidMoneyFrame.CurrentBid,"color")
		m_fontify(HotItemCurrentBidMoneyFrameGoldButtonText,"same")

	end)	
end

end

frame:SetScript("OnEvent", frame.OnEvent);