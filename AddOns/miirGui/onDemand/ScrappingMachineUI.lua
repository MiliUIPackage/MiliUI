local function skin_Blizzard_ScrappingMachineUI()
	
	ScrappingMachineFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)

	hooksecurefunc(ScrappingMachineFrame,"UpdateScrapButtonState",function(self)
		local width, height = 53, 53; 
		local columnNum, rowNum = 3, 3; 
		local slotCount = 0; 
		
		for i = 1, columnNum do
			for j = 1, rowNum do
				local button = self.ItemSlots.scrapButtons:Acquire();
				button.SlotNumber = slotCount; 
				slotCount = slotCount + 1; 
				button:SetPoint("TOPLEFT", self.ItemSlots, "TOPLEFT", ((j - 1) * (width - j) + 2), -((i - 1) * (height - i) + 2));
				button:Show();
				m_border(button,50,50,"CENTER",0,0,12,"HIGH")
			end
		end
	end)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ScrappingMachineUI" then
		skin_Blizzard_ScrappingMachineUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ScrappingMachineUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ScrappingMachineUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)