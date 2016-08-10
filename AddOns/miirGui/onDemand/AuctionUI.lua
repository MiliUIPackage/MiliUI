local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionUI" then
	local function miirgui_AuctionFrameAuctions_Update()
		for i=1, NUM_AUCTIONS_TO_DISPLAY do
			local buttonName = "AuctionsButton"..i;
			local itemButton = _G[buttonName.."Item"];
			if (quality) then
				itemButton.IconBorder:Hide();
			else
				itemButton.IconBorder:Hide();
			end
			for i=1,9 do
				_G["AuctionsButton"..i.."Middle"] = select (4, _G["AuctionsButton"..i]:GetRegions())
				_G["AuctionsButton"..i.."Middle"]:SetHeight(36)
				_G["AuctionsButton"..i.."Left"]:SetHeight(36)
				_G["AuctionsButton"..i.."Left"]:ClearAllPoints()
				_G["AuctionsButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
				_G["AuctionsButton"..i.."Right"]:SetHeight(36)
				_G["AuctionsButton"..i.."Right"]:ClearAllPoints()
				_G["AuctionsButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)
				_G["AuctionsButton"..i.."Highlight"]:ClearAllPoints()
				_G["AuctionsButton"..i.."Highlight"]:SetPoint("TOPLEFT",35,2)
				_G["AuctionsButton"..i.."Highlight"]:SetHeight(34)
				_G["AuctionsButton"..i.."ItemCount"]:ClearAllPoints()
				_G["AuctionsButton"..i.."ItemCount"]:SetPoint("CENTER", 0, -7)
			end
		end
	end

	hooksecurefunc("AuctionFrameAuctions_Update",miirgui_AuctionFrameAuctions_Update)

	local function miirgui_AuctionFrameBid_Update()
	local _, buttonName;
		for i=1, 9 do
			buttonName = "BidButton"..i;
			local itemButton = _G[buttonName.."Item"];
			itemButton.IconBorder:Hide();
		end
		for i=1,9 do
			_G["BidButton"..i.."Middle"] = select (6, _G["BidButton"..i]:GetRegions())
			_G["BidButton"..i.."Middle"]:SetHeight(36)
			_G["BidButton"..i.."Left"]:SetHeight(36)
			_G["BidButton"..i.."Left"]:ClearAllPoints()
			_G["BidButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
			_G["BidButton"..i.."Right"]:SetHeight(36)
			_G["BidButton"..i.."Right"]:ClearAllPoints()
			_G["BidButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)
			_G["BidButton"..i.."Highlight"]:ClearAllPoints()
			_G["BidButton"..i.."Highlight"]:SetPoint("TOPLEFT",35,2)
			_G["BidButton"..i.."Highlight"]:SetHeight(34)
			_G["BidButton"..i.."ItemCount"]:ClearAllPoints()
			_G["BidButton"..i.."ItemCount"]:SetPoint("CENTER", 0, -7)
		end
	end

	hooksecurefunc("AuctionFrameBid_Update",miirgui_AuctionFrameBid_Update)

	local function miirgui_AuctionFrameBrowse_Update()
		for i = 1,8 do
			local QualityTexture= select(4,_G["BrowseButton"..i.."Item"]:GetRegions() )
			QualityTexture:SetAlpha(0)
			_G["BrowseButton"..i.."Middle"] = select (5, _G["BrowseButton"..i]:GetRegions())
			_G["BrowseButton"..i.."Middle"]:SetHeight(36)
			_G["BrowseButton"..i.."Left"]:SetHeight(36)
			_G["BrowseButton"..i.."Left"]:ClearAllPoints()
			_G["BrowseButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
			_G["BrowseButton"..i.."Right"]:SetHeight(36)
			_G["BrowseButton"..i.."Right"]:ClearAllPoints()
			_G["BrowseButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)
			_G["BrowseButton"..i.."Highlight"]:ClearAllPoints()
			_G["BrowseButton"..i.."Highlight"]:SetPoint("TOPLEFT",35,2)
			_G["BrowseButton"..i.."Highlight"]:SetHeight(34)
			_G["BrowseButton"..i.."ItemCount"]:ClearAllPoints()
			_G["BrowseButton"..i.."ItemCount"]:SetPoint("CENTER", 0, -7)
		end
	end

	hooksecurefunc("AuctionFrameBrowse_Update",miirgui_AuctionFrameBrowse_Update)
	
	for i=1,15 do
		m_fontify(_G["AuctionFilterButton"..i.."NormalText"],"white")
	end

	m_fontify(WowTokenGameTimeTutorial.LeftDisplay.Label,"color")
	m_fontify(WowTokenGameTimeTutorial.LeftDisplay.Tutorial1,"white")
	m_fontify(WowTokenGameTimeTutorial.LeftDisplay.Tutorial2,"white")
	m_fontify(WowTokenGameTimeTutorial.LeftDisplay.Tutorial3,"white")
	m_fontify(WowTokenGameTimeTutorial.RightDisplay.Label,"color")
	m_fontify(WowTokenGameTimeTutorial.RightDisplay.Tutorial1,"white")
	m_fontify(WowTokenGameTimeTutorial.RightDisplay.Tutorial2,"white")
	m_fontify(WowTokenGameTimeTutorial.RightDisplay.Tutorial3,"white")
			
end
end

frame:SetScript("OnEvent", frame.OnEvent);