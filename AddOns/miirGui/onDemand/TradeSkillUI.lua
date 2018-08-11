local function skin_Blizzard_TradeSkillUI()
	TradeSkillFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	TradeSkillFrame.DetailsFrame.Background:Hide()
	TradeSkillFrame.DetailsFrame.ScrollBar.Background:Hide()
	m_border(TradeSkillFrame.DetailsFrame.Contents.ResultIcon,48,48,"CENTER",0,0,12,"HIGH")
	TradeSkillFrame.DetailsFrame.Contents.ResultIcon.IconBorder:Hide()
	TradeSkillFrame.DetailsFrame.Contents.ResultIcon.ResultBorder:Hide()

	local function miirgui_TradeSkillFrame_onShow()
		m_border(TradeSkillFrame,340,TradeSkillFrame:GetHeight()-102,"TOPLEFT",326,-79,14,"HIGH")
		m_border(m_border_TradeSkillFrame,330,TradeSkillFrame:GetHeight()-82,"TOPLEFT",-325,0,14,"HIGH")
	end

	TradeSkillFrame:HookScript("OnShow",miirgui_TradeSkillFrame_onShow)

	TradeSkillFrame.RankFrame.Bar:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)

	m_cursorfix(TradeSkillFrame.SearchBox)

	local function miirgui_TradeSkillFrame_RefreshDisplay(self)
		local recipeInfo = self.selectedRecipeID and C_TradeSkillUI.GetRecipeInfo(self.selectedRecipeID);
		if recipeInfo then
			local sourceText
			if recipeInfo.nextRecipeID then
				sourceText = C_TradeSkillUI.GetRecipeSourceText(recipeInfo.nextRecipeID);
				if sourceText then
					self.Contents.SourceText:SetText(sourceText);
				end
			end
		end
	end

	hooksecurefunc(TradeSkillFrame.DetailsFrame,"RefreshDisplay",miirgui_TradeSkillFrame_RefreshDisplay)

end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_TradeSkillUI" then
		skin_Blizzard_TradeSkillUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_TradeSkillUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_TradeSkillUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)