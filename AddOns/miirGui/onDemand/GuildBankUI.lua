local function skin_Blizzard_GuildBankUI()
	GuildBankFrameBlackBG:ClearAllPoints()
	GuildBankFrameBlackBG:SetPoint("BOTTOM",GuildBankFrame)
	GuildBankFrameBlackBG:SetSize(744,20)
	m_SetTexture(GuildBankFrameBlackBG,"Interface\\FrameGeneral\\UI-Background-Marble.blp")
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
			local _,_,_,_,quality = GetGuildBankItemInfo(tab, i)
			if quality then
				local r, g, b, hex = GetItemQualityColor(quality)
				m_SetTexture(button.IconBorder,"Interface\\Lootframe\\quality.blp")
				button.IconBorder:Show();
				button.IconBorder:SetSize(44,44)
				button.IconBorder:SetVertexColor(r, g, b, hex)
				button.Count:ClearAllPoints()
				button.Count:SetPoint("Center", 0, -11)
			end
		end
	end
	hooksecurefunc("GuildBankFrame_Update", miirgui_GuildBankFrame_Update)
	m_cursorfix(GuildItemSearchBox)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_GuildBankUI" then
		skin_Blizzard_GuildBankUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_GuildBankUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_GuildBankUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)