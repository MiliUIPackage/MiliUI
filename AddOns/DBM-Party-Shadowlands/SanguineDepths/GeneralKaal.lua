local mod	= DBM:NewMod(2407, "DBM-Party-Shadowlands", 8, 1189)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20200919232137")
mod:SetCreatureID(168112)
mod:SetEncounterID(2363)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 323821 322903",
	"SPELL_CAST_SUCCESS 323845 324086",
	"SPELL_AURA_APPLIED 323845",
	"SPELL_AURA_REMOVED 323845"
--	"SPELL_PERIODIC_DAMAGE",
--	"SPELL_PERIODIC_MISSED",
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

--Infoframe tracking extra action button usage/CDs of Shining Radiance?
--[[
(ability.id = 323821 or ability.id = 322903) and type = "begincast"
 or ability.id = 323845 and type = "cast"
--]]
local warnWickedRush				= mod:NewTargetAnnounce(323845, 3)
local warnShiningRadiance			= mod:NewTargetNoFilterAnnounce(324086, 1)

local specWarnWickedRush			= mod:NewSpecialWarningMoveAway(323845, nil, nil, nil, 1, 2)
local yellWickedRush				= mod:NewYell(323845)
local yellWickedRushFades			= mod:NewShortFadesYell(323845)
local specWarnPiercingBlur			= mod:NewSpecialWarningDodge(323810, nil, nil, nil, 2, 2)
local specWarnGloomSquall			= mod:NewSpecialWarningSpell(322903, nil, nil, nil, 3, 2)
--local specWarnGTFO					= mod:NewSpecialWarningGTFO(257274, nil, nil, nil, 1, 8)

local timerWickedRushCD				= mod:NewCDTimer(15.8, 323845, nil, nil, nil, 3)--5.7, 15.8, 20.7, 15.8
local timerPiercingBlurCD			= mod:NewCDTimer(9.7, 323810, nil, nil, nil, 3)--10.6, 9.7, 20.7, 9.7, 9.7
local timerGloomSquallCD			= mod:NewCDTimer(38.9, 322903, nil, nil, nil, 2, nil, DBM_CORE_L.IMPORTANT_ICON)

mod.vb.rushCast = 0
mod.vb.blurCast = 1

function mod:OnCombatStart(delay)
	self.vb.rushCast = 0
	self.vb.blurCast = 1--Sequence starts 1 on engage, only 1 cast
	timerWickedRushCD:Start(5.7-delay)
	timerPiercingBlurCD:Start(10.6-delay)
	timerGloomSquallCD:Start(35.1-delay)
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 323821 then
		self.vb.blurCast = self.vb.blurCast + 1
		specWarnPiercingBlur:Show()
		specWarnPiercingBlur:Play("watchstep")
		timerPiercingBlurCD:Start(self.vb.blurCast == 2 and 20.7 or 9.7)
	elseif spellId == 322903 then
		--Each ability cast twice between glooms, then sequence starts over
		self.vb.rushCast = 0
		self.vb.blurCast = 0
		specWarnGloomSquall:Show()
		specWarnGloomSquall:Play("carefly")
		timerGloomSquallCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 323845 then
		self.vb.rushCast = self.vb.rushCast + 1
		timerWickedRushCD:Start(self.vb.rushCast == 2 and 20.7 or 15.8)
	elseif spellId == 324086 then
		warnShiningRadiance:Show(args.sourceName)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 323845 then
		warnWickedRush:CombinedShow(0.3, args.destName)
		if args:IsPlayer() then
			specWarnWickedRush:Show()
			specWarnWickedRush:Play("runout")
			yellWickedRush:Yell()
			yellWickedRushFades:Countdown(spellId)
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 323845 then
		if args:IsPlayer() then
			yellWickedRushFades:Cancel()
		end
	end
end

--[[
function mod:SPELL_PERIODIC_DAMAGE(_, _, _, _, destGUID, _, _, _, spellId, spellName)
	if spellId == 309991 and destGUID == UnitGUID("player") and self:AntiSpam(2, 2) then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:UNIT_SPELLCAST_SUCCEEDED(uId, _, spellId)
	if spellId == 257453  then

	end
end
--]]
