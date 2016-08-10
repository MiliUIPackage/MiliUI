local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Blizzard_ChallengesUI" then

	local hideit=select(2,ChallengesFrame:GetRegions())
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
			local border=select(1,frame:GetRegions())
			border:SetTexture("Interface\\Garrison\\shipborder.BLP")
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
	ChallengesKeystoneFrame.InstructionBackground:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble.BLP")
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
		local affixes = select(2,C_ChallengeMode.GetSlottedKeystoneInfo())
		for i = 1, #affixes+2 do	
			self.Affixes[i].Border:SetTexture("Interface\\Garrison\\shipborder.blp")
			self.Affixes[i].Border:SetVertexColor(unpack(miirgui.Color))
			self.Affixes[i].Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
			m_fontify(self.Affixes[i].Percent,"white")	
		end
	end
	
	hooksecurefunc(ChallengesKeystoneFrame,"OnKeystoneSlotted",miirgui_ChallengesKeystoneFrame)
	
	end
end
frame:SetScript("OnEvent", frame.OnEvent);