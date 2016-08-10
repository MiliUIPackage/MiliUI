local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_ItemSocketingUI" then
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
end

frame:SetScript("OnEvent", frame.OnEvent);