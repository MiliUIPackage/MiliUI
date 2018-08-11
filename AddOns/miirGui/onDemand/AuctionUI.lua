local function skin_Blizzard_AuctionUI()

	AuctionProgressFrameCancelButton:ClearAllPoints()
	AuctionProgressFrameCancelButton:SetPoint("RIGHT",AuctionProgressBar,24.5,0)
	AuctionProgressBar.Border:ClearAllPoints()
	AuctionProgressBar.Border:SetPoint("CENTER",AuctionProgressBar,0,2)
	m_border(AuctionProgressBar,28,28,"LEFT",-30.5,2,14,"HIGH")
	AuctionProgressBar.Icon:ClearAllPoints()
	AuctionProgressBar.Icon:SetPoint("LEFT",AuctionProgressBar,-28,1)
	AuctionProgressBar.Text:ClearAllPoints()
	AuctionProgressBar.Text:SetPoint("CENTER",AuctionProgressBar,0,1)
	local function miirgui_AuctionFrameAuctions_Update()
		for i=1, NUM_AUCTIONS_TO_DISPLAY do
			local buttonName = "AuctionsButton"..i;
			local itemButton = _G[buttonName.."Item"];
			if (quality) then
				itemButton.IconBorder:Hide();
			else
				itemButton.IconBorder:Hide();
				end
			local _
			for i=1,9 do
				_G["AuctionsButton"..i.."ItemIconTexture"]:SetTexCoord(0.95, 0.05, 0.05, 0.95)
				 _,_,_,_G["AuctionsButton"..i.."Middle"] = _G["AuctionsButton"..i]:GetRegions()
				_G["AuctionsButton"..i.."Middle"]:SetHeight(36)
				_G["AuctionsButton"..i.."Left"]:SetHeight(36)
				_G["AuctionsButton"..i.."Left"]:ClearAllPoints()
				_G["AuctionsButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
				_G["AuctionsButton"..i.."Right"]:SetHeight(36)
				_G["AuctionsButton"..i.."Right"]:ClearAllPoints()
				_G["AuctionsButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)
				_G["AuctionsButton"..i.."Highlight"]:SetPoint("TOPLEFT",_G["AuctionsButton"..i.."Middle"],-10,-1)
				_G["AuctionsButton"..i.."Highlight"]:SetPoint("BOTTOMRIGHT",_G["AuctionsButton"..i.."Middle"],8,1)
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

		_G["BidButton"..i.."ItemIconTexture"]:SetTexCoord(0.95, 0.05, 0.05, 0.95)
		_,_,_,_,_,_G["BidButton"..i.."Middle"] = _G["BidButton"..i]:GetRegions()
		_G["BidButton"..i.."Middle"]:SetHeight(36)
		_G["BidButton"..i.."Left"]:SetHeight(36)
		_G["BidButton"..i.."Left"]:ClearAllPoints()
		_G["BidButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
		_G["BidButton"..i.."Right"]:SetHeight(36)
		_G["BidButton"..i.."Right"]:ClearAllPoints()
		_G["BidButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)
		_G["BidButton"..i.."Highlight"]:SetPoint("TOPLEFT",_G["BidButton"..i.."Middle"],-10,-1)
		_G["BidButton"..i.."Highlight"]:SetPoint("BOTTOMRIGHT",_G["BidButton"..i.."Middle"],8,1)
		_G["BidButton"..i.."ItemCount"]:ClearAllPoints()
		_G["BidButton"..i.."ItemCount"]:SetPoint("CENTER", 0, -7)
		end
	end

	hooksecurefunc("AuctionFrameBid_Update",miirgui_AuctionFrameBid_Update)

	local function miirgui_AuctionFrameBrowse_Update()
		for i = 1,8 do
			local _,_,_,QualityTexture = _G["BrowseButton"..i.."Item"]:GetRegions()
			QualityTexture:SetAlpha(0)
			_G["BrowseButton"..i.."ItemIconTexture"]:SetTexCoord(0.95, 0.05, 0.05, 0.95)
			_,_,_,_,_G["BrowseButton"..i.."Middle"] = _G["BrowseButton"..i]:GetRegions()
			_G["BrowseButton"..i.."Middle"]:SetHeight(36)
			_G["BrowseButton"..i.."Left"]:SetHeight(36)
			_G["BrowseButton"..i.."Left"]:ClearAllPoints()
			_G["BrowseButton"..i.."Left"]:SetPoint("LEFT",34,3.5)
			_G["BrowseButton"..i.."Right"]:SetHeight(36)
			_G["BrowseButton"..i.."Right"]:ClearAllPoints()
			_G["BrowseButton"..i.."Right"]:SetPoint("RIGHT",0,3.5)

			_G["BrowseButton"..i.."Highlight"]:SetPoint("TOPLEFT",_G["BrowseButton"..i.."Middle"],-10,-1)
			_G["BrowseButton"..i.."Highlight"]:SetPoint("BOTTOMRIGHT",_G["BrowseButton"..i.."Middle"],8,1)
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

	m_cursorfix(BrowseName)
	m_cursorfix(BrowseMinLevel)
	m_cursorfix(BrowseMaxLevel)
	m_cursorfix(StartPriceGold)
	m_cursorfix(StartPriceSilver)
	m_cursorfix(StartPriceCopper)
	m_cursorfix(BuyoutPriceGold)
	m_cursorfix(BuyoutPriceSilver)
	m_cursorfix(BuyoutPriceCopper)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_AuctionUI" then
		skin_Blizzard_AuctionUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_AuctionUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_AuctionUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)