local function skin_Blizzard_ArchaeologyUI()

	local function miirgui_ArcheologyDigsiteProgressBar()
		m_fontify(ArcheologyDigsiteProgressBar.BarTitle,"white")
		ArcheologyDigsiteProgressBar.Shadow:Hide()
		m_SetTexture(ArcheologyDigsiteProgressBar.BarBackground,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	end

	ArcheologyDigsiteProgressBar:HookScript("OnShow", miirgui_ArcheologyDigsiteProgressBar)
	ArchaeologyFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_fontify(ArchaeologyFrameHelpPageTitle,"color")
	m_fontify(ArchaeologyFrameHelpPageDigTitle,"color")
	m_fontify(ArchaeologyFrameHelpPageHelpScrollHelpText,"white")
	m_fontify(ArchaeologyFrameSummaryPageTitle,"color")
	m_fontify(ArchaeologyFrameCompletedPageTitle,"color")
	m_fontify(ArchaeologyFrameCompletedPageTitleMid,"color")
	local nothingcompleted =ArchaeologyFrameCompletedPage:GetRegions()
	m_fontify(nothingcompleted,"white")

	for i= 1, 12 do
		local DiggingRace= _G["ArchaeologyFrameSummaryPageRace"..i]
		local DiggingRaceProgress = DiggingRace:GetRegions()
		m_fontify(DiggingRaceProgress,"white")
	end
	m_fontify(ArchaeologyFrameArtifactPageHistoryTitle,"color")
	m_fontify(ArchaeologyFrameArtifactPageHistoryScrollChildText,"white")
	m_fontify(ArchaeologyFrameCompletedPageTitleTop,"color")

	for i= 1,12 do
		local ArtifactNumber = _G["ArchaeologyFrameCompletedPageArtifact"..i]
		local _,ArtifactBg,_,ArtifactName,ArtifactSubText = ArtifactNumber:GetRegions()
		ArtifactBg:Hide()
		m_fontify(ArtifactName,"white")
		m_fontify(ArtifactSubText,"white")
	end
	m_fontify(ArchaeologyFrameCompletedPagePageText,"white")
	ArchaeologyFrameRankBarBar:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
	ArchaeologyFrameRankBarBackground:Hide()
	m_fontify(ArchaeologyFrameArtifactPageArtifactName,"color")
	m_fontify(ArchaeologyFrameArtifactPageArtifactSubText,"white")
	m_fontify(ArchaeologyFrameSummaryPagePageText,"white")
	ArchaeologyFrameArtifactPageRaceBG:SetDesaturated(0)

	local function miirgui_ArchaeologyFrame_CurrentArtifactUpdate()
		ArchaeologyFrameArtifactPageRaceBG:SetDesaturated(0)
	end

	hooksecurefunc("ArchaeologyFrame_CurrentArtifactUpdate",miirgui_ArchaeologyFrame_CurrentArtifactUpdate)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ArchaeologyUI" then
		skin_Blizzard_ArchaeologyUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ArchaeologyUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ArchaeologyUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)