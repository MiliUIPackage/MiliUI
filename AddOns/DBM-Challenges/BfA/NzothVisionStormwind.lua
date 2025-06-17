local mod	= DBM:NewMod("d1993", "DBM-Challenges", 2)--1993 Stormwind 1995 Org
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20250527223641")

mod:RegisterCombat("scenario", 2213, 2827)
mod:RegisterZoneCombat(2827)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 308278 309819 309648 298691 308669 308366 308406 311456 296911 296537 308481 308575 298033 308375 309882 309671 308305 311399 297315 308998 308265 296669 307870 296718",
	"SPELL_AURA_APPLIED 311390 315385 311641 308380 308366 308265 308998",--316481
	"SPELL_AURA_APPLIED_DOSE 311390",
	"SPELL_AURA_REMOVED 308998 298033",
	"SPELL_CAST_SUCCESS 309035",
	"SPELL_PERIODIC_DAMAGE 312121 296674 308807 313303",
	"SPELL_PERIODIC_MISSED 312121 296674 308807 313303",
	"SPELL_INTERRUPT",
	"UNIT_DIED",
	"ENCOUNTER_START",
	"UNIT_SPELLCAST_SUCCEEDED_UNFILTERED",
	"UNIT_SPELLCAST_INTERRUPTED_UNFILTERED",
	"UNIT_AURA player",
	"UNIT_POWER_UPDATE player"
)

--TODO, maybe add https://ptr.wowhead.com/spell=292021/madness-leaden-foot#see-also-other affix? just depends on warning to stop moving can be counter to a stacked affix
--TODO, see if target scanning will work on Entropic Leap
--NOTE: Alleria does not have RP timer because it has early termination based on proximity. Full rp is 14.4 seconds, but she'll end it early if you're in melee range (takes about 2 sec to trigger)
--General
local warnSanity				= mod:NewCountAnnounce(307831, 3)
local warnSanityOrb				= mod:NewCastAnnounce(307870, 1)
local warnGiftoftheTitans		= mod:NewSpellAnnounce(313698, 1)
local warnScorchedFeet			= mod:NewSpellAnnounce(315385, 4)
--Extra Abilities (used by main boss and the area LTs)
local warnTaintedPolymorph		= mod:NewCastAnnounce(309648, 3)
local warnEntropicMissiles		= mod:NewSpellAnnounce(309373, 3)
local warnExplosiveOrdnance		= mod:NewSpellAnnounce(305672, 3)
local warnSeekAndDestroy		= mod:NewSpellAnnounce(311570, 3)
local warnSummonEyeofChaos		= mod:NewSpellAnnounce(308681, 2)
local warnCorruptedBlight		= mod:NewCastAnnounce(308265, 3)
local warnLurkingAppendage		= mod:NewCastAnnounce(296669, 3)
--Other notable abilities by mini bosses/trash
local warnEntropicLeap			= mod:NewCastAnnounce(308406, 3)
local warnConvert				= mod:NewTargetNoFilterAnnounce(308380, 3)
local warnImprovedMorale		= mod:NewTargetNoFilterAnnounce(308998, 3)
local warnTouchoftheAbyss		= mod:NewCastAnnounce(298033, 4)
local warnBrutalSmash			= mod:NewCastAnnounce(309882, 3)

--General (GTFOs and Affixes)
local specwarnSanity			= mod:NewSpecialWarningCount(307831, nil, nil, nil, 1, 10)
local specWarnGTFO				= mod:NewSpecialWarningGTFO(312121, nil, nil, nil, 1, 8)
local specWarnEntomophobia		= mod:NewSpecialWarningJump(311389, nil, nil, nil, 1, 6)
--local specWarnHauntingShadows	= mod:NewSpecialWarningDodge(306545, false, nil, 4, 1, 2)
local specWarnScorchedFeet		= mod:NewSpecialWarningYou(315385, false, nil, 2, 1, 2)
local yellScorchedFeet			= mod:NewYell(315385, nil, false, 2)
--local specWarnSplitPersonality	= mod:NewSpecialWarningYou(316481, nil, nil, nil, 1, 2)
local specWarnWaveringWill		= mod:NewSpecialWarningReflect(311641, "false", nil, nil, 1, 2)--Off by default, it's only 5%, but that might matter to some classes
--Alleria Windrunner
local specWarnDarkenedSky		= mod:NewSpecialWarningDodge(308278, nil, nil, nil, 2, 2)
local specWarnVoidEruption		= mod:NewSpecialWarningMoveTo(309819, nil, nil, nil, 3, 2)
--Extra Abilities (used by Alleria and the area LTs)
local specWarnChainsofServitude	= mod:NewSpecialWarningRun(298691, nil, nil, nil, 4, 2)--Health based, no CD. 66% and 33% on LT and 50% on alleria
local specWarnDarkGaze			= mod:NewSpecialWarningLookAway(308669, false, nil, 2, 2, 2)
local specWarnForgeBreath		= mod:NewSpecialWarningDodge(309671, nil, nil, nil, 2, 15)
local specWarnTaintedPolymorph	= mod:NewSpecialWarningInterrupt(309648, "HasInterrupt", nil, nil, 1, 2)
--Other notable abilities by mini bosses/trash
local specWarnAgonizingTorment	= mod:NewSpecialWarningInterrupt(308366, "HasInterrupt", nil, nil, 1, 2)
local specWarnEntropicMissiles	= mod:NewSpecialWarningInterrupt(309035, "HasInterrupt", nil, nil, 1, 2)
local specWarnMentalAssault		= mod:NewSpecialWarningInterrupt(296537, "HasInterrupt", nil, nil, 1, 2)
local specWarnShadowShift		= mod:NewSpecialWarningInterrupt(308575, "HasInterrupt", nil, nil, 1, 2)
local specWarnTouchoftheAbyss	= mod:NewSpecialWarningInterrupt(298033, "HasInterrupt", nil, nil, 1, 2)
local specWarnPsychicScream		= mod:NewSpecialWarningInterrupt(308375, "HasInterrupt", nil, nil, 1, 2)
local specWarnImproveMorale		= mod:NewSpecialWarningInterrupt(308998, "HasInterrupt", nil, nil, 1, 2)
local specWarnVoidBuffet		= mod:NewSpecialWarningInterrupt(297315, "HasInterrupt", nil, nil, 1, 2)
local specWarnBladeFlourish		= mod:NewSpecialWarningRun(311399, nil, nil, nil, 4, 2)
local specWarnRoaringBlast		= mod:NewSpecialWarningDodge(311456, nil, nil, nil, 2, 15)
local specWarnChaosBreath		= mod:NewSpecialWarningDodge(296911, nil, nil, nil, 2, 15)
local specWarnAgonizingTormentD	= mod:NewSpecialWarningDispel(308366, "RemoveCurse", nil, nil, 1, 2)
local specWarnCorruptedBlight	= mod:NewSpecialWarningDispel(308265, "RemoveDisease", nil, 2, 1, 2)
local specWarnBlightEruption	= mod:NewSpecialWarningMoveAway(308305, nil, nil, nil, 1, 2)
local yellBlightEruption		= mod:NewYell(308305)
local specWarnRiftStrike		= mod:NewSpecialWarningDodge(308481, nil, nil, nil, 2, 2)
local specWarnDarkSmash			= mod:NewSpecialWarningDodge(296718, nil, nil, nil, 2, 2)

--General
local timerGiftoftheTitan		= mod:NewBuffFadesTimer(20, 313698, nil, nil, nil, 5)
--Affixes/Masks
local timerDarkImaginationCD	= mod:NewCDTimer(60, 315976, nil, nil, nil, 1, 296733)
--Alleria Windrunner
local timerDarkenedSkyCD		= mod:NewCDTimer(13.3, 308278, nil, nil, nil, 3)
local timerVoidEruptionCD		= mod:NewVarTimer("v27.9-31.6", 309819, nil, nil, nil, 2)
local timerVoidEruption			= mod:NewCastTimer(7, 309819, nil, nil, nil, 5)
--Extra Abilities (used by Alleria and the area LTs)
local timerTaintedPolymorphCD	= mod:NewVarTimer("v22.3-30.4", 309648, nil, nil, nil, 3, nil, DBM_COMMON_L.MAGIC_ICON)--22.3-30.4 on alleria, unknown on LT without way more data
local timerExplosiveOrdnanceCD	= mod:NewVarTimer("v20.6-29.1", 305672, nil, nil, nil, 3)--20-29.1 on alleria, 12.1 on LT
local timerForgeBreathCD		= mod:NewCDTimer(13.3, 309671, nil, nil, nil, 3)--13.3-14.6
local timerEntropicMissilesCD	= mod:NewCDTimer(10.1, 309035, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)--10.1-17.1
--Other notable abilities for trash
local timerTouchoftheAbyss		= mod:NewCastNPTimer(2, 298033, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerBladeFlourishCD		= mod:NewCDPNPTimer(14.6, 311399, nil, nil, nil, 3)
local timerDarkSmashCD			= mod:NewCDNPTimer(7.3, 296718, nil, nil, nil, 3)

mod:AddInfoFrameOption(307831, true)
mod:AddNamePlateOption("NPAuraOnMorale", 308998)

--Antispam 1: Boss throttles, 2: GTFOs, 3: Dodge stuff on ground. 4: Face Away/special action. 5: Dodge Shockwaves

local playerName = UnitName("player")
mod.vb.TherumCleared = false
mod.vb.UmbricCleared = false
local warnedGUIDs = {}
local lastSanity = 1000

function mod:OnCombatStart(delay)
	self.vb.TherumCleared = false
	self.vb.UmbricCleared = false
	table.wipe(warnedGUIDs)
	lastSanity = 1000
	if self.Options.NPAuraOnMorale then
		DBM:FireEvent("BossMod_EnableHostileNameplates")
	end
	if self.Options.InfoFrame then
		DBM.InfoFrame:SetHeader(DBM:GetSpellName(307831))
		DBM.InfoFrame:Show(5, "playerpower", 1, ALTERNATE_POWER_INDEX, nil, nil, 2)--Sorting lowest to highest
	end
end

function mod:OnCombatEnd()
	table.wipe(warnedGUIDs)
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
	if self.Options.NPAuraOnMorale then
		DBM.Nameplate:Hide(true, nil, nil, nil, true, self.Options.NPAuraOnMorale, self.Options.CVAR1)--isGUID, unit, spellId, texture, force, isHostile, isFriendly
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 308278 then
		specWarnDarkenedSky:Show()
		specWarnDarkenedSky:Play("watchstep")
		timerDarkenedSkyCD:Start()
	elseif spellId == 309819 then
		specWarnVoidEruption:Show(DBM_COMMON_L.BREAK_LOS)
		specWarnVoidEruption:Play("findshelter")
		timerVoidEruptionCD:Start()
		timerVoidEruption:Start()
	elseif spellId == 309648 then
		if self.Options.SpecWarn309648interrupt and self:CheckInterruptFilter(args.sourceGUID, false, true) then
			specWarnTaintedPolymorph:Show(args.sourceName)
			specWarnTaintedPolymorph:Play("kickcast")
		else
			warnTaintedPolymorph:Show()
		end
		if args:GetSrcCreatureID() == 233675 then--Alleria
			timerTaintedPolymorphCD:Start()--too dirty right now to do LTs timer due to his phases delaying his casts
		end
	elseif spellId == 298691 then
		specWarnChainsofServitude:Show()
		specWarnChainsofServitude:Play("justrun")
	elseif spellId == 308669 and self:AntiSpam(5, 4) then
		specWarnDarkGaze:Show(args.sourceName)
		specWarnDarkGaze:Play("turnaway")
	elseif spellId == 308366 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnAgonizingTorment:Show(args.sourceName)
		specWarnAgonizingTorment:Play("kickcast")
	elseif spellId == 296537 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnMentalAssault:Show(args.sourceName)
		specWarnMentalAssault:Play("kickcast")
	elseif spellId == 308575 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnShadowShift:Show(args.sourceName)
		specWarnShadowShift:Play("kickcast")
	elseif spellId == 308375 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnPsychicScream:Show(args.sourceName)
		specWarnPsychicScream:Play("kickcast")
	elseif spellId == 297315 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnVoidBuffet:Show(args.sourceName)
		specWarnVoidBuffet:Play("kickcast")
	elseif spellId == 308998 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnImproveMorale:Show(args.sourceName)
		specWarnImproveMorale:Play("kickcast")
	elseif spellId == 298033 then
		if self:CheckInterruptFilter(args.sourceGUID, false, true) then
			specWarnTouchoftheAbyss:Show(args.sourceName)
			specWarnTouchoftheAbyss:Play("kickcast")
		else
			warnTouchoftheAbyss:Show()
		end
		timerTouchoftheAbyss:Start(nil, args.sourceGUID)
	elseif spellId == 308406 then
		warnEntropicLeap:Show()
	elseif spellId == 311456 and self:AntiSpam(3, 5) then
		specWarnRoaringBlast:Show()
		specWarnRoaringBlast:Play("frontal")
	elseif spellId == 296911 and self:AntiSpam(3, 5) then
		specWarnChaosBreath:Show()
		specWarnChaosBreath:Play("frontal")
	elseif spellId == 309671 and self:AntiSpam(3, 5) then
		specWarnForgeBreath:Show()
		specWarnForgeBreath:Play("frontal")
		timerForgeBreathCD:Start()
	elseif spellId == 308481 and self:AntiSpam(5, 3) then
		specWarnRiftStrike:Show()
		specWarnRiftStrike:Play("watchstep")
	elseif spellId == 309882 and self:AntiSpam(5, 3) then
		warnBrutalSmash:Show()
	elseif spellId == 308305 and GetNumGroupMembers() > 1 and DBM:UnitDebuff("player", 308265) then
		specWarnBlightEruption:Show()
		specWarnBlightEruption:Play("runout")
		yellBlightEruption:Yell()
	elseif spellId == 311399 then
		specWarnBladeFlourish:Show()
		specWarnBladeFlourish:Play("justrun")
		timerBladeFlourishCD:Start(nil, args.sourceGUID)
	elseif spellId == 308265 then
		warnCorruptedBlight:Show()
	elseif spellId == 296669 then
		warnLurkingAppendage:Show()
	elseif spellId == 307870 then
		warnSanityOrb:Show()
	elseif spellId == 296718 then
		timerDarkSmashCD:Start(nil, args.sourceGUID)
		if self:AntiSpam(3, 3) then
			specWarnDarkSmash:Show()
			specWarnDarkSmash:Play("watchstep")
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 309035 and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnEntropicMissiles:Show(args.sourceName)
		specWarnEntropicMissiles:Play("kickcast")
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 311390 and args:IsPlayer() then
		local amount = args.amount or 1
		if amount >= 4 then
			specWarnEntomophobia:Show()
			specWarnEntomophobia:Play("keepjump")
		end
	elseif spellId == 315385 and args:IsPlayer() then
		if self.Options.SpecWarn315385you then
			specWarnScorchedFeet:Show()
			specWarnScorchedFeet:Play("targetyou")
		else
			warnScorchedFeet:Show()
		end
		if GetNumGroupMembers() > 1 then--Warn allies if in scenario with others
			yellScorchedFeet:Yell()
		end
--	elseif spellId == 316481 and args:IsPlayer() then
--		specWarnSplitPersonality:Show()
--		specWarnSplitPersonality:Play("targetyou")
	elseif spellId == 311641 and args:IsPlayer() then
		specWarnWaveringWill:Show(playerName)
		specWarnWaveringWill:Play("stopattack")
	elseif spellId == 308380 then
		warnConvert:Show(args.destName)
	elseif spellId == 308366 and self:CheckDispelFilter("curse") then
		specWarnAgonizingTormentD:Show(args.destName)
		specWarnAgonizingTormentD:Play("helpdispel")
	elseif spellId == 308265 then
		if self:CheckDispelFilter("disease") then
			specWarnCorruptedBlight:Show(args.destName)
			specWarnCorruptedBlight:Play("helpdispel")
		end
	elseif spellId == 308998 then
		warnImprovedMorale:CombinedShow(0.5, args.destName)
		if self.Options.NPAuraOnMorale then
			DBM.Nameplate:Show(true, args.destGUID, spellId, nil, 12)
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 308998 then
		if self.Options.NPAuraOnMorale then
			DBM.Nameplate:Hide(true, args.destGUID, spellId)
		end
	elseif spellId == 298033 then
		timerTouchoftheAbyss:Stop(args.sourceGUID)
	end
end

function mod:SPELL_PERIODIC_DAMAGE(_, _, _, _, destGUID, _, _, _, spellId, spellName)
	if (spellId == 296674 or spellId == 312121 or spellId == 308807 or spellId == 313303) and destGUID == UnitGUID("player") and self:AntiSpam(2, 2) then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:SPELL_INTERRUPT(args)
	if type(args.extraSpellId) == "number" and args.extraSpellId == 298033 then
		timerTouchoftheAbyss:Stop(args.destGUID)
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 152718 or cid == 233675 then--Alleria Windrunner
		timerDarkenedSkyCD:Stop()
		timerVoidEruptionCD:Stop()
		timerTaintedPolymorphCD:Stop()
		timerExplosiveOrdnanceCD:Stop()
		DBM:EndCombat(self)
	elseif cid == 156577 or cid == 233679 then--Therum Deepforge
		timerExplosiveOrdnanceCD:Stop()
		timerForgeBreathCD:Stop()
		self.vb.TherumCleared = true
--	elseif cid == 153541 or cid == 233685 then--Slavemaster Ul'rok

--	elseif cid == 158157 or cid == 233684 then--Overlord Mathias Shaw

	elseif cid == 158035 or cid == 233681 then--Magister Umbric
		--timerTaintedPolymorphCD:Stop()
		timerEntropicMissilesCD:Stop()
		self.vb.UmbricCleared = true
	elseif cid == 156795 then--S.I. Informant (Unknownn variant ID for TWW)
		timerTouchoftheAbyss:Stop(args.destGUID)
	elseif cid == 156949 then--Alleyway bladeflourish guy
		timerBladeFlourishCD:Stop(args.destGUID)
	elseif cid == 152987 then
		timerDarkSmashCD:Stop(args.destGUID)
	end
end

--All timers subject to a ~0.5 second clipping due to ScanEngagedUnits
function mod:StartEngageTimers(guid, cid, delay)
	if cid == 156949 then
--		timerBladeFlourishCD:Start(14.6-delay, guid)
	elseif cid == 152987 then
--		timerDarkSmashCD:Start(7.3-delay, guid)
	end
end

--Abort timers when all players out of combat, so NP timers clear on a wipe
--Caveat, it won't calls top with GUIDs, so while it might terminate bar objects, it may leave lingering nameplate icons
function mod:LeavingZoneCombat()
	self:Stop(true)
end


function mod:ENCOUNTER_START(encounterID)
	if (encounterID == 2338 or encounterID == 3081) and self:IsInCombat() then--Alleria Windrunner
		timerDarkenedSkyCD:Start(4.9)
		timerVoidEruptionCD:Start(20.5)
		if self.vb.TherumCleared then
			timerExplosiveOrdnanceCD:Start(9.7)
		end
		if self.vb.UmbricCleared then
			timerTaintedPolymorphCD:Start(14.8)
		end
	elseif encounterID == 2374 or encounterID == 3082 then--Therum Deepforge
		timerExplosiveOrdnanceCD:Start(2.4)
		timerForgeBreathCD:Start(8.5)
	end
end

--None of these boss abilities are in combat log
function mod:UNIT_SPELLCAST_SUCCEEDED_UNFILTERED(uId, _, spellId)
	if (spellId == 305708 or spellId == 312260) and self:AntiSpam(2, 1) then--First one is mini boss second is alleria
		local cid = self:GetUnitCreatureId(uId)
		self:SendSync("ExplosiveOrd", cid)
	elseif spellId == 309035 and self:AntiSpam(2, 1) then
		self:SendSync("EntropicMissiles")
	elseif spellId == 311530 and self:AntiSpam(2, 1) then
		self:SendSync("SeekandDestroy")
	elseif spellId == 308681 and self:AntiSpam(2, 1) then
		self:SendSync("SummonEye")
	elseif spellId == 18950 and self:AntiSpam(2, 6) then
		local cid = self:GetUnitCreatureId(uId)
		if cid == 164189 or cid == 164188 then
			self:SendSync("DarkImagination")
		end
	end
end

function mod:UNIT_SPELLCAST_INTERRUPTED_UNFILTERED(uId, _, spellId)
	if spellId == 298033 then
		local guid = UnitGUID(uId)
		timerTouchoftheAbyss:Stop(guid)
	end
end

do
	--Gift of the Titans isn't in combat log either
	local titanWarned = false
	function mod:UNIT_AURA(uId)
		local hasTitan = DBM:UnitBuff("player", 313698)
		if hasTitan and not titanWarned then
			warnGiftoftheTitans:Show()
			timerGiftoftheTitan:Start()
			titanWarned = true
		elseif not hasTitan and titanWarned then
			titanWarned = false
		end
	end
end

function mod:UNIT_POWER_UPDATE(uId)
	local currentSanity = UnitPower(uId, ALTERNATE_POWER_INDEX)
	if currentSanity > lastSanity then
		lastSanity = currentSanity
		return
	end
	if self:AntiSpam(5, 6) then--Additional throttle in case you lose sanity VERY rapidly with increased ICD for special warning
		if currentSanity < 40 and lastSanity > 40 then
			lastSanity = currentSanity
			specwarnSanity:Show(lastSanity)
			specwarnSanity:Play("lowsanity")
		elseif currentSanity < 80 and lastSanity > 80 then
			lastSanity = currentSanity
			specwarnSanity:Show(lastSanity)
			specwarnSanity:Play("lowsanity")
		end
	elseif self:AntiSpam(3, 7) then--Additional throttle in case you lose sanity VERY rapidly
		if currentSanity < 120 and lastSanity > 120 then
			lastSanity = currentSanity
			warnSanity:Show(lastSanity)
		elseif currentSanity < 160 and lastSanity > 160 then
			lastSanity = currentSanity
			warnSanity:Show(lastSanity)
		end
	end
end

function mod:OnSync(msg, creatureId)
	if not self:IsInCombat() then return end
	if msg == "ExplosiveOrd" then
		creatureId = tonumber(creatureId)
		warnExplosiveOrdnance:Show()
		if creatureId then
			local timer = (creatureId == 233679 or creatureId == 156577) and 12.1 or 29.1
			timerExplosiveOrdnanceCD:Start(timer)
		end
	elseif msg == "EntropicMissiles" then
		warnEntropicMissiles:Show()
		timerEntropicMissilesCD:Start()
	elseif msg == "SeekandDestroy" then
		warnSeekAndDestroy:Show()
	elseif msg == "SummonEye" then
		warnSummonEyeofChaos:Show()
	elseif msg == "DarkImagination" then
		timerDarkImaginationCD:Start()
	end
end
