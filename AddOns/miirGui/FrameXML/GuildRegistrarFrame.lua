local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

for i=1,2 do
	local button = _G["GuildRegistrarButton"..i]
	if button:GetFontString() then
		if button:GetFontString():GetText() then
			m_fontify(button:GetFontString(),"white")
		end
	end
end
m_fontify(GuildRegistrarPurchaseText,"white")
m_fontify(PetitionFrameCharterTitle,"color")	
m_fontify(PetitionFrameCharterName,"white")
m_fontify(PetitionFrameMasterTitle,"color")
m_fontify(PetitionFrameMasterName,"white")
m_fontify(PetitionFrameMemberTitle,"color")
m_fontify(PetitionFrameInstructions,"white")
m_fontify(AvailableServicesText,"white")
local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,PetitionFrameBg = PetitionFrame:GetRegions()
PetitionFrameBg:Hide() 
local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,GuildRegistrarBG = GuildRegistrarFrame:GetRegions()
GuildRegistrarBG:Hide()
GuildRegistrarFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,PetitionPortrait = PetitionFrame:GetRegions()
PetitionPortrait:Show()
PetitionPortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)
PetitionPortrait:SetPoint("TOPLEFT",-8,10)
PetitionPortrait:SetSize(64,64)
		
for i= 1,9 do
	m_fontify(_G["PetitionFrameMemberName"..i],"white")
end
		
local function miirgui_GuildInvite()
	GuildInviteFrameTabardRing:Hide()
	GuildInviteFrameBackground:Hide()
	m_SetTexture(GuildInviteFrameBg,"Interface\\FrameGeneral\\UI-Background-Rock.blp")
	GuildInviteFrameBg:SetAlpha(0.6)		
	m_fontify(GuildInviteFrameInviterName,"white")
	m_fontify(GuildInviteFrameInviteText,"white")
	m_fontify(GuildInviteFrameGuildName,"color")
	local Achievement= GuildInviteFrame:GetChildren() 
	local Achievementtext= Achievement:GetRegions()
	m_fontify(Achievementtext,"color")
	local GuildLevel = GuildInviteFrame:GetChildren() 
	local _,GuildLevelText = GuildLevel:GetRegions() 
	m_fontify(GuildLevelText,"white")	
	m_border(GuildInviteFrame,68,68,"TOP",0,-68,14,"TOOLTIP")
end
		
GuildInviteFrame:HookScript("OnEvent",miirgui_GuildInvite)

	
m_border(GuildRegistrarFrame,332,340,"TOPLEFT",2,-60,14,"MEDIUM")
m_border(PetitionFrame,332,340,"TOPLEFT",2,-60,14,"MEDIUM")
		
end)