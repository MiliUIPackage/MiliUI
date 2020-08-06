local mod	= DBM:NewMod(2413, "DBM-Party-Shadowlands", 4, 1185)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20200720005952")
mod:SetCreatureID(164218)
mod:SetEncounterID(2381)
mod:SetZone()

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 323393 323236 328791",
	"SPELL_CAST_SUCCESS 323437 329113",
	"SPELL_AURA_APPLIED 323437 323143"
--	"SPELL_AURA_APPLIED_DOSE 323410",
--	"SPELL_AURA_REMOVED 323410",
--	"SPELL_AURA_REMOVED_DOSE 323410",
--	"SPELL_PERIODIC_DAMAGE",
--	"SPELL_PERIODIC_MISSED",
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

--TODO, more timer verification with even more pull data to get time in between casts when Ritual of Woe doesn't reset timers and to figure out onslaught behavior
--[[
(ability.id = 323393 or ability.id = 328791 or ability.id = 323236) and type = "begincast"
 or (ability.id = 329113 or ability.id = 323437) and type = "cast"
 or ability.id = 323143 and type = "applybuff"
--]]
local warnTelekineticToss			= mod:NewSpellAnnounce(323143, 2)
local warnStigmaofPride				= mod:NewTargetNoFilterAnnounce(323437, 4)

local specWarnUnleashedSuffering	= mod:NewSpecialWarningDodge(323236, nil, nil, nil, 2, 2)
local specWarnTelekineticOnslaught	= mod:NewSpecialWarningDodge(329113, nil, nil, nil, 2, 2)
local specWarnRitualofWoe			= mod:NewSpecialWarningSoak(323393, nil, nil, nil, 1, 7)
--local yellBlackPowder				= mod:NewYell(257314)
--local specWarnHealingBalm			= mod:NewSpecialWarningInterrupt(257397, "HasInterrupt", nil, nil, 1, 2)
--local specWarnVulnerabilityStack	= mod:NewSpecialWarningStack(323410, nil, 12, nil, nil, 1, 6)
--local specWarnGTFO					= mod:NewSpecialWarningGTFO(257274, nil, nil, nil, 1, 8)

local timerTelekineticTossCD		= mod:NewCDTimer(11.5, 323143, nil, nil, nil, 3)--11.5-15.7
local timerTelekineticOnslaughtCD	= mod:NewCDTimer(5, 329113, nil, nil, nil, 3)--Unknown actual timer
local timerUnleashedSufferingCD		= mod:NewCDTimer(5, 323236, nil, nil, nil, 3)--Unknown actual timer
local timerStigmaofPrideCD			= mod:NewCDTimer(5, 323437, nil, nil, nil, 5, nil, DBM_CORE_L.HEALER_ICON)--Unknown actual timer

--mod:AddInfoFrameOption(323410, true)

local VulnerabilityStacks = {}

function mod:OnCombatStart(delay)
	table.wipe(VulnerabilityStacks)
	timerStigmaofPrideCD:Start(10-delay)--10-15, SUCCESS
	timerUnleashedSufferingCD:Start(17-delay)
	timerTelekineticOnslaughtCD:Start(30-delay)--30-32
--	if self.Options.InfoFrame then
--		DBM.InfoFrame:SetHeader(DBM:GetSpellInfo(323410))
--		DBM.InfoFrame:Show(5, "table", VulnerabilityStacks, 1)
--	end
end

function mod:OnCombatEnd()
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 323393 or spellId == 328791 then--328791 is challenge (all statues), 323393 is non challenge (1 statue)
		specWarnRitualofWoe:Show()
		specWarnRitualofWoe:Play("helpsoak")
		timerTelekineticTossCD:Stop()
		timerStigmaofPrideCD:Stop()
		timerUnleashedSufferingCD:Stop()
		timerTelekineticOnslaughtCD:Stop()
		timerStigmaofPrideCD:Start(17.6)--17.6-18.5
		timerTelekineticTossCD:Start(20)--Not always though, but consistently, but sometimes doesn't happen?
		timerTelekineticOnslaughtCD:Start(22)--22 if toss isn't cast, 26 if it is
		timerUnleashedSufferingCD:Start(32.8)
	elseif spellId == 323236 and self:AntiSpam(3, 1) then--event fires multiple times
		specWarnUnleashedSuffering:Show()
		specWarnUnleashedSuffering:Play("shockwave")
		--timerUnleashedSufferingCD:Start()--TODO, need longer pulls that don't reset timer with Ritual of Woe
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 323437 then
--		timerStigmaofPrideCD:Start()--TODO, need longer pulls that don't reset timer with Ritual of Woe
	elseif spellId == 329113 then
		specWarnTelekineticOnslaught:Show()
		specWarnTelekineticOnslaught:Play("watchstep")
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 323437 then
		warnStigmaofPride:CombinedShow(0.3, args.destName)
	elseif spellId == 323143 then
		warnTelekineticToss:Show()
		timerTelekineticTossCD:Start()
		--Hacky, if timer less than 6 for onslaught, set additional time until it's 6
		local onSlaughtTime = timerTelekineticOnslaughtCD:GetRemaining()
		if onSlaughtTime and onSlaughtTime > 0 and onSlaughtTime < 6 then
			local adjust = 6 - onSlaughtTime
			timerTelekineticOnslaughtCD:AddTime(adjust)
		end
	--[[elseif spellId == 323410 then
		local amount = args.amount or 1
		VulnerabilityStacks[args.destName] = amount
		--if args:IsPlayer() and (amount == 12 or amount >= 15 and amount % 2 == 1) then--12, 15, 17, 19
		--	specWarnVulnerabilityStack:Show(amount)
		--	specWarnVulnerabilityStack:Play("stackhigh")
		--end
		if self.Options.InfoFrame then
			DBM.InfoFrame:UpdateTable(VulnerabilityStacks)
		end--]]
	end
end
--mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

--[[
function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 323410 then
		VulnerabilityStacks[args.destName] = nil
		if self.Options.InfoFrame then
			DBM.InfoFrame:UpdateTable(VulnerabilityStacks)
		end
	end
end

function mod:SPELL_AURA_REMOVED_DOSE(args)
	local spellId = args.spellId
	if spellId == 323410 then
		VulnerabilityStacks[args.destName] = args.amount or 1
		if self.Options.InfoFrame then
			DBM.InfoFrame:UpdateTable(VulnerabilityStacks)
		end
	end
end

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
