local addonsToSkin = {
	["SimBuilder"] = function()
	SimBuilderLaunchButton:ClearAllPoints()
	SimBuilderLaunchButton:SetPoint("LEFT",CharacterFrameCloseButton,-40,0)
	
	SimItemCompareFrameTitleBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
	SimItemCompareFrameDialogBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	SimItemCompareFrameTopRight:Hide()
	SimItemCompareFrameTopLeft:Hide()
	SimItemCompareFrameBottomRight:Hide()
	SimItemCompareFrameBottomLeft:Hide()
	SimItemCompareFrameLeft:Hide()
	SimItemCompareFrameRight:Hide()
	SimItemCompareFrameTop:Hide()
	SimItemCompareFrameBottom:Hide()
	SimItemCompareFrameTitleBG:ClearAllPoints()
	SimItemCompareFrameTitleBG:SetPoint("TOP",SimItemCompareFrame,0,-7)
	SimItemCompareFrameTitleBG:SetSize(586,16)
	m_border(SimItemCompareFrame,590,394,"Center",0.5,-8,12,"HIGH")
	m_border(SimItemCompareFrameClose,591,20,"RIGHT",-6,1,14,"HIGH")
	
	SimItemCopyFrameTitleBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
	SimItemCopyFrameDialogBG:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	SimItemCopyFrameTopRight:Hide()
	SimItemCopyFrameTopLeft:Hide()
	SimItemCopyFrameBottomRight:Hide()
	SimItemCopyFrameBottomLeft:Hide()
	SimItemCopyFrameLeft:Hide()
	SimItemCopyFrameRight:Hide()
	SimItemCopyFrameTop:Hide()
	SimItemCopyFrameBottom:Hide()
	SimItemCopyFrameTitleBG:ClearAllPoints()
	SimItemCopyFrameTitleBG:SetPoint("TOP",SimItemCopyFrame,0,-7)
	SimItemCopyFrameTitleBG:SetSize(586,16)
	m_border(SimItemCopyFrame,590,170,"Center",0.5,-8.5,12,"HIGH")
	m_border(SimItemCopyFrameClose,591,20,"RIGHT",-6,1,14,"HIGH")
	
		end,
	["BugSack"] = function()
	
	hooksecurefunc(BugSack,"OpenSack",function()	
		local _,title= BugSackFrame:GetChildren()
		m_border(title,460,20,"LEFT",-4,0,14,"TOOLTIP")
		m_border(BugSackFrame,508,318,"Center",0,0,14,"BACKGROUND")

		for i=1,10 do 
		local bg = select(i,BugSackFrame:GetRegions())
		bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
		end
	end)
	
		end,
	["AckisRecipeList"] = function()
	
		hooksecurefunc(_G.AckisRecipeList,"Scan",function()
			ARL_ProfessionButtonPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end)
		
		end,
	["BetterArchaeologyUI"] = function()
	
			ArchaeologyFrameSummaryPage:HookScript("OnShow",function()
				for i=1,18 do
					local race = _G["ArchaeologyFrameSummaryPageRace"..i]
					if race then 
						m_fontify(race.raceName,"white")
					end
				end

			end)
			
			ArchaeologyFrameFuturePage:HookScript("OnShow",function()
			
			local futureartifacts = 	ArchaeologyFrameFuturePage:GetRegions()
			m_fontify(futureartifacts,"color")
			m_fontify(ArchaeologyFrameFuturePage.pageText,"white")
				for i=1,12 do
					m_fontify(_G["ArchaeologyFrameFuturePageArtifact"..i.."ArtifactName"],"white")
					m_fontify(_G["ArchaeologyFrameFuturePageArtifact"..i.."ArtifactSubText"],"white")
				end
			
			end)
			
		end,
	["Classic Quest Log"] = function()
	
			m_icon(ClassicQuestLog, "quest", -8, 9, "MEDIUM")
			ClassicQuestLogScrollFrame.BG:Hide()
			ClassicQuestLogDetailScrollFrame.DetailBG:Hide()
			m_border(ClassicQuestLog,0,0,"CENTER",0,0,14,"HIGH")		
			m_border_ClassicQuestLog:SetPoint("TOPLEFT","ClassicQuestLog",2,-58)
			m_border_ClassicQuestLog:SetPoint("BOTTOMRIGHT","ClassicQuestLog",-4,24)
			
			local function miirgui_cql_obj(_,self)
			if self:GetName() == "ClassicQuestLogDetailScrollChildFrame" then		
				local _,_,_,_,QuestInfoRewardsFramewilllearn = QuestInfoRewardsFrame:GetRegions()
				if QuestInfoRewardsFramewilllearn ~= nil then
					m_fontify(QuestInfoRewardsFramewilllearn,"white")
				end	
			end
			end
			
			hooksecurefunc("QuestInfo_Display", miirgui_cql_obj)	
				
			local function miirgui_cql_show()
					m_fontify(QuestInfoTitleHeader,"color")
					m_fontify(QuestInfoDescriptionHeader,"color")
					m_fontify(QuestInfoObjectivesHeader,"color")
					m_fontify(QuestInfoDescriptionText,"white")
					m_fontify(QuestInfoObjectivesText,"white")
					m_fontify(QuestInfoGroupSize,"white")
					m_fontify(QuestInfoRewardText,"white")
			end
			
			ClassicQuestLog:HookScript("OnShow",miirgui_cql_show)
			
		end,
	["Clique"] = function()
	
			hooksecurefunc("ToggleSpellBook",function()
				if (CliqueSpellTab) then
					local _,_,_,_,_,CliqueIcon = CliqueSpellTab:GetRegions()
					CliqueIcon:SetTexCoord(0.13, 0.83, 0.13, 0.83)
					CliqueConfigPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
				end
			end)
			
		end,
	["Combuctor"] = function()
	
			CombuctorFrameinventoryPortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			for i=19,21 do
				local hideit=select(i,CombuctorFrameinventory:GetRegions())
				hideit:Hide()
			end
			
		end,
	["Inventorian"] = function()
	
			InventorianBagFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			InventorianBankFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			for i=19,21 do
				local hideit=select(i,InventorianBagFrame:GetRegions())
				hideit:Hide()
				local hideitalso=select(i,InventorianBankFrame:GetRegions())
				hideitalso:Hide()
			end
			
		end,
	["mOnArs_WardrobeHelper"] = function()
	
			mOnWD_MainFramePortrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			
		end,
}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, addon)
		if event == "ADDON_LOADED" then	
			if addonsToSkin[addon] then
				addonsToSkin[addon]()
				addonsToSkin[addon] = nil	
			end
		else	
			for addon, func in pairs(addonsToSkin) do
				if IsAddOnLoaded(addon) then
					func()
				end
			end
		end
	end)