local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
if event == "ADDON_LOADED" and arg1 == "Blizzard_ArchaeologyUI" then
	local f= CreateFrame("Frame",nil)
	f:SetFrameStrata("MEDIUM")
	f:SetWidth(256) 
	f:SetHeight(16) 
	local t = f:CreateTexture(nil,"BACKGROUND")
	t:SetTexture("Interface\\Archeology\\progress.blp")
	t:SetAllPoints(f)
	f.texture = t

	local function miirgui_ArcheologyDigsiteProgressBar()
		m_fontify(ArcheologyDigsiteProgressBar.BarTitle,"white")
		ArcheologyDigsiteProgressBar.BarBorderAndOverlay:Hide()
		ArcheologyDigsiteProgressBar.Shadow:Hide()
		ArcheologyDigsiteProgressBar.BarBackground:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
		f:SetParent(ArcheologyDigsiteProgressBar)
		f:SetPoint("CENTER",0,0)
		f:Show()
	end

	ArcheologyDigsiteProgressBar:HookScript("OnShow", miirgui_ArcheologyDigsiteProgressBar)
		
	ArchaeologyFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	m_fontify(ArchaeologyFrameHelpPageTitle,"color")
	m_fontify(ArchaeologyFrameHelpPageDigTitle,"color")
	m_fontify(ArchaeologyFrameHelpPageHelpScrollHelpText,"white")
	m_fontify(ArchaeologyFrameSummaryPageTitle,"color")
	m_fontify(ArchaeologyFrameCompletedPageTitle,"color")
	m_fontify(ArchaeologyFrameCompletedPageTitleMid,"color")
	local nothingcompleted=select(1,ArchaeologyFrameCompletedPage:GetRegions())
	m_fontify(nothingcompleted,"white")

	for i= 1, 12 do
		local DiggingRace= _G["ArchaeologyFrameSummaryPageRace"..i]
		local DiggingRaceProgress = select(1,DiggingRace:GetRegions())
		m_fontify(DiggingRaceProgress,"white")
	end
	m_fontify(ArchaeologyFrameArtifactPageHistoryTitle,"color")
	m_fontify(ArchaeologyFrameArtifactPageHistoryScrollChildText,"white")
	m_fontify(ArchaeologyFrameCompletedPageTitleTop,"color")
			
	for i= 1,12 do
		local ArtifactNumber = _G["ArchaeologyFrameCompletedPageArtifact"..i]
		local ArtifactBg = select(2,ArtifactNumber:GetRegions())
		ArtifactBg:Hide()
		local ArtifactName=select(4,ArtifactNumber:GetRegions())
		m_fontify(ArtifactName,"white")
		local ArtifactSubText=select(5,ArtifactNumber:GetRegions())
		m_fontify(ArtifactSubText,"white")
	end
	m_fontify(ArchaeologyFrameCompletedPagePageText,"white")
	ArchaeologyFrameRankBarBar:SetVertexColor(unpack(miirgui.Color))
	m_fontify(ArchaeologyFrameArtifactPageArtifactName,"color")
	m_fontify(ArchaeologyFrameArtifactPageArtifactSubText,"white")
	m_fontify(ArchaeologyFrameSummaryPagePageText,"white")
	ArchaeologyFrameArtifactPageRaceBG:SetDesaturated(0)

	local function miirgui_ArchaeologyFrame_CurrentArtifactUpdate()
		ArchaeologyFrameArtifactPageRaceBG:SetDesaturated(0)
	end
	
	hooksecurefunc("ArchaeologyFrame_CurrentArtifactUpdate",miirgui_ArchaeologyFrame_CurrentArtifactUpdate)		
end
end

frame:SetScript("OnEvent", frame.OnEvent);