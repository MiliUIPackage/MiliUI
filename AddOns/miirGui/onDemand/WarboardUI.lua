local function skin_Blizzard_QuestChoice()
--[[
	WarboardQuestChoiceFrame.GarrCorners:Hide()
	WarboardQuestChoiceFrame.Left:Hide()
	WarboardQuestChoiceFrame.Right:Hide()
	WarboardQuestChoiceFrame.Top:Hide()
	WarboardQuestChoiceFrame.Bottom:Hide()
	WarboardQuestChoiceFrameTopBorder:Hide()
	WarboardQuestChoiceFrame.Background.BackgroundTile:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
	WarboardQuestChoiceFrame.Background.BackgroundTile:SetPoint("TOPLEFT",WarboardQuestChoiceFrame)
	WarboardQuestChoiceFrame.Background.BackgroundTile:SetPoint("BOTTOMRIGHT",WarboardQuestChoiceFrame)
	m_fontify(WarboardQuestChoiceFrame.Title.Text,"color")
	WarboardQuestChoiceFrame.Title.Left:Hide()
	WarboardQuestChoiceFrame.Title.Middle:Hide()
	WarboardQuestChoiceFrame.Title.Right:Hide()
	]]
	local function miirui_QuestChoiceFrame_Update(self)
	
		local _, _, numOptions = GetQuestChoiceInfo();
			for i=1, numOptions do
				local option = WarboardQuestChoiceFrame["Option"..i];
				option.ArtworkBorder:ClearAllPoints()
				option.ArtworkBorder:SetPoint("TOP",option,0.5,0.5)
				m_fontify(option.OptionText,"white")
				m_fontify(option.Header.Text,"color")
			end
		WarboardQuestChoiceFrameTopBorder:Hide()
		WarboardQuestChoiceFrameBottomBorder:Hide()
		WarboardQuestChoiceFrameTopLeftCorner:Hide()
		WarboardQuestChoiceFrameBotLeftCorner:Hide()
		WarboardQuestChoiceFrameBotRightCorner:Hide()
	end

	hooksecurefunc(WarboardQuestChoiceFrame,"Update",miirui_QuestChoiceFrame_Update)

	m_border(WarboardQuestChoiceFrame,820,602,"CENTER",0,0,14,"TOOLTIP")
	m_border_WarboardQuestChoiceFrame:SetPoint("TOPLEFT",WarboardQuestChoiceFrame,-2,2.5)
	m_border_WarboardQuestChoiceFrame:SetPoint("BOTTOMRIGHT",WarboardQuestChoiceFrame,0,-1.5)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_WarboardUI" then
		skin_Blizzard_QuestChoice()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_WarboardUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_QuestChoice()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)