local function skin_Blizzard_ChallengesUI()

	local _,hideit = ChallengesFrame:GetRegions()
	hideit:Hide()
		
	ChallengesFrame:HookScript("OnShow",function(self)	
		for i = 1, 13 do
			local frame = self.DungeonIcons[i];
			frame.Icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end
	end)
	
	hooksecurefunc(ChallengesFrame.WeeklyInfo,"SetUp",function(self)
		local affixes = C_MythicPlus.GetCurrentAffixes();
		if (affixes) then 
			for i=1, #affixes do
				local frame = self.Child.Affixes[i];
				frame.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				m_SetTexture(frame.Border,"Interface\\Garrison\\shipborder.blp")
				frame.Border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			end
		end
	end)
	
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
		if #affixes > 0 then
			for i = 1, #affixes+2 do
				m_SetTexture(self.Affixes[i].Border,"Interface\\Garrison\\shipborder.blp")
				self.Affixes[i].Border:SetVertexColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
				self.Affixes[i].Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				m_fontify(self.Affixes[i].Percent,"white")
			end
		end

	end

	hooksecurefunc(ChallengesKeystoneFrame,"OnKeystoneSlotted",miirgui_ChallengesKeystoneFrame)
end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_ChallengesUI" then
		skin_Blizzard_ChallengesUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_ChallengesUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_ChallengesUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)