local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
if event == "ADDON_LOADED" and arg1 == "Blizzard_AchievementUI" then
	for i=1,12 do
		_G["AchievementFrameSummaryCategoriesCategory"..i.."FillBar"]:Hide()
		_G["AchievementFrameSummaryCategoriesCategory"..i.."Bar"]:SetVertexColor(unpack(miirgui.Color))
	end

	local kids = {AchievementFrameComparisonSummaryFriend:GetRegions() };
	for _, child in ipairs(kids) do
		child:Hide()
	end

	local kids = {AchievementFrameComparisonSummaryPlayer:GetRegions() };
	for _, child in ipairs(kids) do
		child:Hide()
	end
	AchievementFrameStatsBG:Hide()
	AchievementFrameWoodBorderTopLeft:Hide()
	AchievementFrameWoodBorderTopRight:Hide()
	AchievementFrameWoodBorderBottomLeft:Hide()
	AchievementFrameWoodBorderBottomRight:Hide()
	AchievementFrameWaterMark:Hide()
	AchievementFrameComparisonWatermark:Hide()
	AchievementFrameComparisonSummaryPlayerStatusBarFillBar:Hide()
	AchievementFrameComparisonSummaryPlayerStatusBarBar:SetVertexColor(unpack(miirgui.Color))
	AchievementFrameComparisonSummaryFriendStatusBarFillBar:Hide()
	AchievementFrameComparisonSummaryFriendStatusBarBar:SetVertexColor(unpack(miirgui.Color))
	AchievementFrameSummaryCategoriesStatusBarFillBar:Hide()
	AchievementFrameSummaryCategoriesStatusBarBar:SetVertexColor(unpack(miirgui.Color))
	AchievementFrameAchievementsContainerScrollBarBG:Hide()
	AchievementFrameStatsContainerScrollBarBG:Hide()
	AchievementFrameComparisonStatsContainerScrollBarBG:Hide()
	AchievementFrameComparisonDark:SetAlpha(0)
	AchievementFrameCategoriesContainerScrollBarBG:SetAlpha(0)
	AchievementFrameComparisonContainerScrollBarBG:SetAlpha(0)
	AchievementFrameScrollFrameScrollBarBG:Hide()
	
	local tint = select(3,AchievementFrameAchievements:GetRegions())
	tint:Hide()
	local FuglyGreenBorder1 = select(3,AchievementFrameStats:GetChildren())
	FuglyGreenBorder1:SetBackdropBorderColor(1, 1, 1,0)	
	local FuglyGreenBorder2 = select(2,AchievementFrameAchievements:GetChildren())
	FuglyGreenBorder2:SetBackdropBorderColor(1, 1, 1,0)	
	local FuglyGreenBorder3 = select(5,AchievementFrameComparison:GetChildren())
	FuglyGreenBorder3:SetBackdropBorderColor(1, 1, 1,0)	
	local FuglyGreenBorder4 = select(1,AchievementFrameSummary:GetChildren())
	FuglyGreenBorder4:SetBackdropBorderColor(1, 1, 1,0)		
	
	AchievementFrame:HookScript("OnShow",function()
		for i =1,19 do
			m_fontify(_G["AchievementFrameCategoriesContainerButton"..i.."Label"],"white")
		end
		AchievementFrame:SetBackdrop({
		bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
		edgeSize = 14,
		})
		AchievementFrameCategories:SetBackdropBorderColor(1, 1, 1,0)
		AchievementFrameBackground:Hide()
		AchievementFrameSummaryBackground:Hide()
		AchievementFrameCategoriesBG:Hide()	
		m_fontify(AchievementFrameHeaderTitle,"color")
		AchievementFrameHeaderShield:Hide()
		m_fontify(AchievementFrameHeaderPoints,"same")	
	end)
	
	hooksecurefunc("AchievementFrameComparison_DisplayAchievement",function()
		AchievementFrameComparisonHeaderShield:Hide()
		AchievementFrameComparisonHeader:ClearAllPoints()
		AchievementFrameComparisonHeader:SetPoint("TOPRIGHT",AchievementFrameComparison,42,66.5)
		m_border(AchievementFrameComparisonHeader,118,40,"LEFT",25,-9,14,"HIGH")
		m_fontify(AchievementFrameComparisonSummaryPlayerStatusBarTitle,"white")
		for i=1,9 do	
			_G["AchievementFrameComparisonContainerButton"..i.."PlayerBackground"]:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
			m_border(_G["AchievementFrameComparisonContainerButton"..i.."Player"],0,0,"CENTER",0,0,14,"HIGH")	
			_G["m_border_AchievementFrameComparisonContainerButton"..i.."Player"]:SetPoint("TOPLEFT",_G["AchievementFrameComparisonContainerButton"..i.."Player"],0,0)
			_G["m_border_AchievementFrameComparisonContainerButton"..i.."Player"]:SetPoint("BOTTOMRIGHT",_G["AchievementFrameComparisonContainerButton"..i.."Player"],0,0)
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."PlayerDateCompleted"],"green")
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."PlayerShieldPoints"],"white")
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."PlayerLabel"],"same")
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."PlayerDescription"],"white")
			_G["AchievementFrameComparisonContainerButton"..i.."FriendBackground"]:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
			m_border(_G["AchievementFrameComparisonContainerButton"..i.."Friend"],0,0,"CENTER",0,0,14,"HIGH")	
			_G["m_border_AchievementFrameComparisonContainerButton"..i.."Friend"]:SetPoint("TOPLEFT",_G["AchievementFrameComparisonContainerButton"..i.."Friend"],0,0)
			_G["m_border_AchievementFrameComparisonContainerButton"..i.."Friend"]:SetPoint("BOTTOMRIGHT",_G["AchievementFrameComparisonContainerButton"..i.."Friend"],0,0)
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."FriendStatus"],"same")
			m_fontify(_G["AchievementFrameComparisonContainerButton"..i.."FriendShieldPoints"],"same")
		end
		

	end)
	
	hooksecurefunc("AchievementButton_DisplayAchievement",function(button)
		AchievementFrameAchievementsBackground:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble.blp")
		local r = button.label:GetTextColor()
		if r > 0.9 then
			m_fontify(button.label,"color")
		else
			m_fontify(button.label,"same")
		end
		m_fontify(button.hiddenDescription,"white")
		m_fontify(button.description,"white")
		local r=button.reward:GetTextColor()
		if r >0.9 then
			m_fontify(button.reward,"green")
		else
			m_fontify(button.reward,"same")
		end
		for i=1,3 do
			if _G["AchievementFrameProgressBar"..i]then
				m_fontify(_G["AchievementFrameProgressBar"..i.."Text"],"same")
				local track = select(6,_G["AchievementFrameProgressBar"..i]:GetRegions())
				track:SetVertexColor(unpack(miirgui.Color))
			end
		end
		
		for i = 1,7 do
			_G["AchievementFrameAchievementsContainerButton"..i.."BottomLeftTsunami"]:Hide()
			_G["AchievementFrameAchievementsContainerButton"..i.."BottomRightTsunami"]:Hide()	
			_G["AchievementFrameAchievementsContainerButton"..i.."Background"]:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")	
			_G["AchievementFrameAchievementsContainerButton"..i.."Highlight"]:ClearAllPoints()
			_G["AchievementFrameAchievementsContainerButton"..i.."Highlight"]:SetPoint("TOPLEFT",_G["AchievementFrameAchievementsContainerButton"..i],-1,3)		
			_G["AchievementFrameAchievementsContainerButton"..i.."Highlight"]:SetPoint("BOTTOMRIGHT",_G["AchievementFrameAchievementsContainerButton"..i],1,-3)
			m_fontify(_G["AchievementFrameAchievementsContainerButton"..i.."ShieldPoints"],"same")
			m_fontify(_G["AchievementFrameAchievementsContainerButton"..i.."ShieldDateCompleted"],"green")
			m_border(_G["AchievementFrameAchievementsContainerButton"..i],2,2,"Center",0,0,14,"MEDIUM")
			_G["m_border_AchievementFrameAchievementsContainerButton"..i]:SetPoint("TOPLEFT",_G["AchievementFrameAchievementsContainerButton"..i],0,0)
			_G["m_border_AchievementFrameAchievementsContainerButton"..i]:SetPoint("BOTTOMRIGHT",_G["AchievementFrameAchievementsContainerButton"..i],0,0)
		end
		
		for i=1,8 do
			local hideit=select(i,button:GetRegions())
			hideit:Hide()
		end
	
		for i = 1,71 do		
			if _G["AchievementFrameCriteria"..i] then
				local r = _G["AchievementFrameCriteria"..i.."Name"]:GetTextColor()
				if r == 0 then
					m_fontify(_G["AchievementFrameCriteria"..i.."Name"],"green")
				else
					m_fontify(_G["AchievementFrameCriteria"..i.."Name"],"same")
				end
			end	
			if _G["AchievementFrameMeta"..i] then
				local bg = select(5,_G["AchievementFrameMeta"..i]:GetRegions())
				bg:SetColorTexture(unpack(miirgui.Color))		
				local r = _G["AchievementFrameMeta"..i.."Label"]:GetTextColor()
				if r == 0 then
					m_fontify(_G["AchievementFrameMeta"..i.."Label"],"green")
				else
					m_fontify(_G["AchievementFrameMeta"..i.."Label"],"grey")
				end
			end				
		end
		m_fontify(AchievementFrameAchievementsObjectivesReputationCriteria,"same")

	end)
	
	hooksecurefunc("AchievementFrameSummary_UpdateAchievements",function()
		m_fontify(AchievementFrameSummaryAchievementsHeaderTitle,"color")
		m_fontify(AchievementFrameSummaryCategoriesHeaderTitle,"color")
		m_fontify(AchievementFrameSummaryCategoriesStatusBarTitle,"white")
		for i =1,12 do
			m_fontify(_G["AchievementFrameSummaryCategoriesCategory"..i.."Label"],"white")
			
			m_fontify(_G["AchievementFrameSummaryCategoriesCategory"..i.."Text"],"white")
		end

		for i =1,4 do
			for x=1,8 do
				local hideit= select(x,_G["AchievementFrameSummaryAchievement"..i]:GetRegions())
				hideit:Hide()
			end
		
			_G["AchievementFrameSummaryAchievement"..i.."Background"]:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock.blp")
			
			_G["AchievementFrameSummaryAchievement"..i.."Highlight"]:ClearAllPoints()
			_G["AchievementFrameSummaryAchievement"..i.."Highlight"]:SetPoint("TOPLEFT",_G["AchievementFrameSummaryAchievement"..i],-1,2.5)		
			_G["AchievementFrameSummaryAchievement"..i.."Highlight"]:SetPoint("BOTTOMRIGHT",_G["AchievementFrameSummaryAchievement"..i],1,-2.5)
			
			m_border(_G["AchievementFrameSummaryAchievement"..i],484,46,"Center",0,0,14,"MEDIUM")
			m_fontify(_G["AchievementFrameSummaryAchievement"..i.."Label"],"color")		
			m_fontify(_G["AchievementFrameSummaryAchievement"..i.."DateCompleted"],"green")
			m_fontify(_G["AchievementFrameSummaryAchievement"..i.."Description"],"white")
		end
	end)

	
end
end

frame:SetScript("OnEvent", frame.OnEvent);