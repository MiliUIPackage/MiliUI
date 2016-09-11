local function skin_Blizzard_ChallengesUI()

	local _,hideit = ChallengesFrame:GetRegions()
	hideit:Hide()
	
	local function miirgui_ChallengesFrame_Update(self)
	local sortedMaps = {};
		for i = 1, #self.maps do
			local _, _, level, affixes = C_ChallengeMode.GetMapPlayerStats(self.maps[i]);
			if (not level) then
				level = 0;
			else
			end
			tinsert(sortedMaps, { id = self.maps[i], level = level, affixes = affixes });
		end
		table.sort(sortedMaps, function(a, b) return a.level > b.level end);
		for i = 1, #sortedMaps do
			local frame = self.DungeonIcons[i];	
			local border = frame:GetRegions()
			m_SetTexture(border,"Interface\\Garrison\\shipborder.BLP")
			border:ClearAllPoints()
			border:SetPoint("CENTER",frame.Icon,0,-1)
			border:SetSize(52,52)
			frame.Icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)	
		end	 
	end
	
	hooksecurefunc("ChallengesFrame_Update",miirgui_ChallengesFrame_Update)
		
	ChallengesKeystoneFrame.SlotBG:Hide()
	ChallengesKeystoneFrame.KeystoneSlot.Texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	ChallengesKeystoneFrame.KeystoneSlot:SetSize(67,67)
	m_SetTexture(ChallengesKeystoneFrame.InstructionBackground,"Interface\\FrameGeneral\\UI-Background-Marble.BLP")
	m_fontify(ChallengesKeystoneFrame.DungeonName,"color")
	m_fontify(ChallengesKeystoneFrame.Instructions,"white")
	m_fontify(ChallengesKeystoneFrame.PowerLevel,"color")
	m_fontify(ChallengesKeystoneFrame.TimeLimit,"white")
	m_border(ChallengesKeystoneFrame,380,64,"Bottom",0,78,14,"MEDIUM")

	local function miirgui_ChallengesKeystoneFrame()
		m_border_ChallengesKeystoneFrame:Show()
	end
	
	hooksecurefunc(ChallengesKeystoneFrame,"Reset",miirgui_ChallengesKeystoneFrame)
	
	local function miirgui_ChallengesKeystoneFrame(self)
		m_border_ChallengesKeystoneFrame:Hide()
		local _,affixes = C_ChallengeMode.GetSlottedKeystoneInfo()
		for i = 1, #affixes+2 do	
			m_SetTexture(self.Affixes[i].Border,"Interface\\Garrison\\shipborder.blp")
			self.Affixes[i].Border:SetVertexColor(unpack(miirgui.Color))
			self.Affixes[i].Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			m_fontify(self.Affixes[i].Percent,"white")	
		end
	end
	
	hooksecurefunc(ChallengesKeystoneFrame,"OnKeystoneSlotted",miirgui_ChallengesKeystoneFrame)
	
	end

local f= CreateFrame("FRAME")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()	
	local f2= CreateFrame("FRAME")
	f2:RegisterEvent("ADDON_LOADED")
	f2:SetScript("OnEvent", function(_,event, arg1)
		if event == "ADDON_LOADED" and arg1 == "Blizzard_ChallengesUI" then
			skin_Blizzard_ChallengesUI()
			f2:UnregisterEvent("ADDON_LOADED")
		end	
	end)			
	if IsAddOnLoaded("Blizzard_ChallengesUI") then
		skin_Blizzard_ChallengesUI()
		f2:UnregisterEvent("ADDON_LOADED")
	end	
end)