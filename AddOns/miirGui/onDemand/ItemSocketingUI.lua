local function skin_Blizzard_ItemSocketingUI()
		for i=19,27 do
			local hideit= select(i,ItemSocketingFrame:GetRegions() )
			hideit:Hide()
		end
		for i=36,37 do
			local hideit= select(i,ItemSocketingFrame:GetRegions() )
			hideit:Hide()
		end
		for i=46,51 do
			local hideit= select(i,ItemSocketingFrame:GetRegions() )
			hideit:Hide()
		end
		for i=40,50 do
			local hideit= select(i,ItemSocketingFrame:GetRegions() )
			hideit:Hide()
		end
		ItemSocketingFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
		ItemSocketingSocketButton:ClearAllPoints()
		ItemSocketingSocketButton:SetPoint("BOTTOM",ItemSocketingFrame,0,6)
		m_border(ItemSocketingFrameInset,332,364,"TOP",0,2,14,"MEDIUM")

	end
	
local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_ItemSocketingUI" then
			skin_Blizzard_ItemSocketingUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_ItemSocketingUI") then
		skin_Blizzard_ItemSocketingUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)