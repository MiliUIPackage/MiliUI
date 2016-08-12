local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

SpellBookFramePortrait:SetTexCoord(0.85, 0.15, 0.15, 0.85)	
PrimaryProfession1Icon:SetAlpha(1)
PrimaryProfession1Icon:SetDesaturated(nil)
PrimaryProfession1Icon:SetBlendMode("Blend")
PrimaryProfession1Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
PrimaryProfession2Icon:SetAlpha(1)
PrimaryProfession2Icon:SetDesaturated(nil)
PrimaryProfession2Icon:SetBlendMode("Blend")
PrimaryProfession2Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
SpellBookFrameTutorialButton.Ring:Hide()
local SpellBookSkillLineTab1Icon=select(4,SpellBookSkillLineTab1:GetRegions())
SpellBookSkillLineTab1Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
local SpellBookSkillLineTab2Icon=select(4,SpellBookSkillLineTab2:GetRegions())
SpellBookSkillLineTab2Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
local SpellBookSkillLineTab3Icon=select(4,SpellBookSkillLineTab3:GetRegions())
SpellBookSkillLineTab3Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
local SpellBookSkillLineTab4Icon=select(4,SpellBookSkillLineTab4:GetRegions())
SpellBookSkillLineTab4Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)
local SpellBookSkillLineTab5Icon=select(4,SpellBookSkillLineTab5:GetRegions())
SpellBookSkillLineTab5Icon:SetTexCoord(0.85, 0.15, 0.15, 0.85)

HelpPlateTooltipBg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
HelpPlateTooltipBg:SetColorTexture(0.078,0.078,0.078,1)
m_border(HelpPlateTooltip,226,62,"CENTER",0,0,14,"FULLSCREEN_DIALOG")
m_border_HelpPlateTooltip:SetPoint("TOPLEFT","HelpPlateTooltip",-3,3)
m_border_HelpPlateTooltip:SetPoint("BOTTOMRIGHT","HelpPlateTooltip",3,-3)	
m_fontify(HelpPlateTooltip.Text,"white")	

m_fontify(SpellBookPageText,"white")
m_fontify(PrimaryProfession1Missing,"color")
m_fontify(PrimaryProfession2Missing,"color")
local PrimaryProfession1missingtext=select(4,PrimaryProfession1:GetRegions())
m_fontify(PrimaryProfession1missingtext,"white")
m_fontify(SecondaryProfession1Missing,"color")
m_fontify(SecondaryProfession2Missing,"color")
m_fontify(SecondaryProfession3Missing,"color")
m_fontify(SecondaryProfession4Missing,"color")
local SecondaryProfession1missingtext=select(4,SecondaryProfession1:GetRegions())
m_fontify(SecondaryProfession1missingtext,"white")
local SecondaryProfession2missingtext=select(4,SecondaryProfession2:GetRegions())
m_fontify(SecondaryProfession2missingtext,"white")
local SecondaryProfession3missingtext=select(4,SecondaryProfession3:GetRegions())
m_fontify(SecondaryProfession3missingtext,"white")
local SecondaryProfession4missingtext=select(4,SecondaryProfession4:GetRegions())
m_fontify(SecondaryProfession4missingtext,"white")
local PrimaryProfession2missingtext=select(4,PrimaryProfession2:GetRegions())
m_fontify(PrimaryProfession2missingtext,"white")
m_border(PrimaryProfession1,74,74,"Left",6,-2,14,"MEDIUM")
m_border(PrimaryProfession2,74,74,"Left",6,-2,14,"MEDIUM")

local function miirgui_FormatProfession(frame,index)
	if index then
		frame.missingHeader:Hide();
		frame.missingText:Hide();
		local name = select(1,GetProfessionInfo(index))
		frame.skillName = name;
		m_fontify(frame.rank,"white")
		m_fontify(frame.professionName,"color")
	end
end

hooksecurefunc("FormatProfession",miirgui_FormatProfession)

local function miirgui_UpdateProfessionButton(self)
	local spellIndex = self:GetID() + self:GetParent().spellOffset;
	local isPassive = IsPassiveSpell(spellIndex, SpellBookFrame.bookType);
		if ( isPassive ) then
			--self.highlightTexture:SetTexture("Interface\\Buttons\\UI-PassiveHighlight");
			m_fontify(self.subSpellString,"white")
			m_fontify(self.spellString,"color") 
		else
			--self.highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
			m_fontify(self.spellString,"color")
			m_fontify(self.subSpellString,"white")
		end
end

hooksecurefunc("UpdateProfessionButton",miirgui_UpdateProfessionButton)
		
local function miirgui_SpellButton_UpdateButton(self)
	local slot, slotType = SpellBook_GetSpellBookSlot(self);
	local name = self:GetName();
	local subSpellString = _G[name.."SubSpellName"]
	local spellString = _G[name.."SpellName"];
	m_fontify(spellString,"color")
	m_fontify(subSpellString,"white")
	if slotType == "FUTURESPELL" then
		local level = GetSpellAvailableLevel(slot, SpellBookFrame.bookType)
			if (level and level > UnitLevel("player")) then	
				m_fontify(self.RequiredLevelString,"white")
			end
	end
	local offSpecID = select(6,GetSpellTabInfo(SpellBookFrame.selectedSkillLine))
	local isOffSpec = (offSpecID ~= 0) and (SpellBookFrame.bookType == BOOKTYPE_SPELL);
	if (isOffSpec) then
		m_fontify(self.RequiredLevelString,"white")
	end
	
	local slotFrame = _G[name.."SlotFrame"];
	if slotFrame then
		slotFrame:Show()
	end
end

hooksecurefunc("SpellButton_UpdateButton", miirgui_SpellButton_UpdateButton)
		
end)