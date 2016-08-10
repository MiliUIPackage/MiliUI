local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildBankUI" then
		GuildBankFrameBlackBG:ClearAllPoints()
		GuildBankFrameBlackBG:SetPoint("BOTTOM",GuildBankFrame)
		GuildBankFrameBlackBG:SetSize(744,20)
		GuildBankFrameBlackBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble.blp")
		GuildBankEmblemFrame:Hide()
		m_border(GuildBankFrame,720,316,"CENTER",1,0,14,"MEDIUM")
		local function miirgui_GuildBankFrame_Update()
			local tab = GetCurrentGuildBankTab();
			local button, index, column;
			for i=1, MAX_GUILDBANK_SLOTS_PER_TAB do
				index = mod(i, NUM_SLOTS_PER_GUILDBANK_GROUP);
				if ( index == 0 ) then
					index = NUM_SLOTS_PER_GUILDBANK_GROUP;
				end
				column = ceil((i-0.5)/NUM_SLOTS_PER_GUILDBANK_GROUP);
				button = _G["GuildBankColumn"..column.."Button"..index];
				local quality = select(5,GetGuildBankItemInfo(tab, i))
				if quality then
					local r, g, b, hex = GetItemQualityColor(quality)
					button.IconBorder:SetTexture("Interface\\Lootframe\\quality.blp")
					button.IconBorder:Show();
					button.IconBorder:SetSize(44,44)
					button.IconBorder:SetVertexColor(r, g, b, hex)
					button.Count:ClearAllPoints()
					button.Count:SetPoint("Center", 0, -11)
				end
			end
		end
		hooksecurefunc("GuildBankFrame_Update", miirgui_GuildBankFrame_Update)
	end
end

frame:SetScript("OnEvent", frame.OnEvent)