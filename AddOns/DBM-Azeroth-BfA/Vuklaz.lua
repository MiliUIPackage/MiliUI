if not WorldMap_EventOverlayDataProviderMixin then return end--Random 8.3 api check
local mod	= DBM:NewMod(2381, "DBM-Azeroth-BfA", 6, 1028)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20200110170305")
mod:SetCreatureID(160970)
mod:SetEncounterID(2353)
mod:SetReCombatTime(20)
mod:SetZone()
--mod:SetMinSyncRevision(11969)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 314527 314698 314618",
	"SPELL_CAST_SUCCESS 314659"
)

--TODO, see which instance ID she's in, 2275,870
local warnRazorSpines					= mod:NewSpellAnnounce(314698, 3)

local specWarnTremorWave				= mod:NewSpecialWarningDodge(314527, nil, nil, nil, 2, 2)
local specWarnWrithingSands				= mod:NewSpecialWarningSwitch(314659, "Dps", nil, nil, 1, 2)
local specWarnCrushingClaws				= mod:NewSpecialWarningDefensive(314618, "Tank", nil, nil, 1, 2)

local timerTremorWaveCD					= mod:NewAITimer(46.2, 314527, nil, nil, nil, 3)
local timerWrithingSandsCD				= mod:NewAITimer(46.2, 314659, nil, nil, nil, 1, nil, DBM_CORE_DAMAGE_ICON)
local timerRazorSpinesCD				= mod:NewAITimer(46.2, 314698, nil, nil, nil, 2, nil, DBM_CORE_HEALER_ICON)
local timerCrushingClawsCD				= mod:NewAITimer(46.2, 314618, nil, nil, nil, 5, nil, DBM_CORE_TANK_ICON..DBM_CORE_HEALER_ICON)

--[[
function mod:OnCombatStart(delay, yellTriggered)
	if yellTriggered then

	end
end
--]]

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 314527 then
		specWarnTremorWave:Show()
		specWarnTremorWave:Play("shockwave")
		timerTremorWaveCD:Start()
	elseif spellId == 314698 then
		warnRazorSpines:Show()
		timerRazorSpinesCD:Start()
	elseif spellId == 314618 then
		specWarnCrushingClaws:Show()
		specWarnCrushingClaws:Play("defensive")
		timerCrushingClawsCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 314659 then
		specWarnWrithingSands:Show()
		specWarnWrithingSands:Play("killmob")
		timerWrithingSandsCD:Start()
	end
end
