local function skin_Blizzard_InspectUI()
	local function miirgui_InspectPaperDollItemSlotButton_Update()
	local kids = { InspectPaperDollItemsFrame:GetChildren() }
		for _, child in ipairs(kids) do
			local _,_,_,_,quality = child:GetRegions()
			m_SetTexture(quality,"Interface\\Containerframe\\quality.blp")
	end
	end

	hooksecurefunc("InspectPaperDollItemSlotButton_Update",miirgui_InspectPaperDollItemSlotButton_Update)
	InspectFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	SpecializationRing:Hide()
	SpecializationSpecIcon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	InspectGuildFrameBG:Hide()
	m_border(Specialization,76,76,"TOPLEFT",16,-14,14,"MEDIUM")
	m_border(InspectGuildFrame,330,340,"LEFT",4,-18,14,"MEDIUM")
	m_border(InspectTalentFrame,334,364,"CENTER",0,-26,14,"MEDIUM")
	m_border(InspectPVPFrame,334,364,"CENTER",0,-26,14,"MEDIUM")


	for x = 1,7 do
		local frame = "TalentsTalentRow"..x

		m_SetTexture(_G[frame.."Talent1Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent1Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent1Border"]:SetSize(40,42)

		m_SetTexture(_G[frame.."Talent2Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent2Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent2Border"]:SetSize(40,42)

		m_SetTexture(_G[frame.."Talent3Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent3Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent3Border"]:SetSize(40,42)
	end
	
	InspectPVPFrame.TrinketSlot.Texture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	InspectPVPFrame.TalentSlot1.Texture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	InspectPVPFrame.TalentSlot2.Texture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	InspectPVPFrame.TalentSlot3.Texture:SetTexCoord(0.85, 0.15, 0.15, 0.85)
	
	m_border(InspectPVPFrame.TrinketSlot,40,40,"CENTER",0,0,14,"MEDIUM")
	m_border(InspectPVPFrame.TalentSlot1,40,40,"CENTER",0,0,14,"MEDIUM")
	m_border(InspectPVPFrame.TalentSlot2,40,40,"CENTER",0,0,14,"MEDIUM")
	m_border(InspectPVPFrame.TalentSlot3,40,40,"CENTER",0,0,14,"MEDIUM")

	
--[[
	for x = 1,6 do
		local frame = "InspectPVPFrameTalentRow"..x

		m_SetTexture(_G[frame.."Talent1Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent1Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent1Border"]:SetSize(40,42)

		m_SetTexture(_G[frame.."Talent2Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent2Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent2Border"]:SetSize(40,42)

		m_SetTexture(_G[frame.."Talent3Border"],"Interface\\Buttons\\ButtonHilight-Round.blp")
		_G[frame.."Talent3Border"]:SetPoint("CENTER",0,1)
		_G[frame.."Talent3Border"]:SetSize(40,42)
	end]]


end

local catchaddon = CreateFrame("FRAME")
catchaddon:RegisterEvent("ADDON_LOADED")

--function to catch loading addons
local function skinnedOnLoad(_, _, addon)
	if addon == "Blizzard_InspectUI" then
		skin_Blizzard_InspectUI()
	end
end

--this function decides whether the addon is already loaded or if we need to look out for it!

local function skinnedOnLogin()
	if IsAddOnLoaded("Blizzard_InspectUI") then
		-- Addon is already loaded, procceed to skin!
		skin_Blizzard_InspectUI()
	else
		-- Addon is not loaded yet, procceed to look out for it!
		catchaddon:SetScript("OnEvent", skinnedOnLoad)
	end
end

local HelloWorld = CreateFrame("FRAME")
HelloWorld:RegisterEvent("PLAYER_ENTERING_WORLD")
HelloWorld:SetScript("OnEvent", skinnedOnLogin)