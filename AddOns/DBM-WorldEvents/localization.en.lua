local L

------------
--  Omen  --
------------
L = DBM:GetModLocalization("Omen")

L:SetGeneralLocalization({
	name = "Omen"
})

------------------------------
--  The Crown Chemical Co.  --
------------------------------
L = DBM:GetModLocalization("d288")

L:SetTimerLocalization{
	HummelActive		= "Hummel becomes active",
	BaxterActive		= "Baxter becomes active",
	FryeActive			= "Frye becomes active"
}

L:SetOptionLocalization({
	TrioActiveTimer		= "Show timers for when Apothecary Trio becomes active"
})

L:SetMiscLocalization({
	SayCombatStart		= "Did they bother to tell you who I am and why I am doing this?"
})

----------------------------
--  The Frost Lord Ahune  --
----------------------------
L = DBM:GetModLocalization("d286")

L:SetWarningLocalization({
	Emerged			= "Emerged",
	specWarnAttack	= "Ahune is vulnerable - Attack now!"
})

L:SetTimerLocalization{
	SubmergeTimer	= "Submerge",
	EmergeTimer		= "Emerge"
}

L:SetOptionLocalization({
	Emerged			= "Show warning when Ahune emerges",
	specWarnAttack	= "Show special warning when Ahune becomes vulnerable",
	SubmergeTimer	= "Show timer for submerge",
	EmergeTimer		= "Show timer for emerge"
})

L:SetMiscLocalization({
	Pull			= "The Ice Stone has melted!"
})

----------------------
--  Coren Direbrew  --
----------------------
L = DBM:GetModLocalization("d287")

L:SetWarningLocalization({
	specWarnBrew		= "Get rid of the brew before she tosses you another one!",
	specWarnBrewStun	= "HINT: You were bonked, remember to drink the brew next time!"
})

L:SetOptionLocalization({
	specWarnBrew		= "Show special warning for $spell:47376",
	specWarnBrewStun	= "Show special warning for $spell:47340"
})

L:SetMiscLocalization({
	YellBarrel			= "Barrel on me!"
})

----------------
--  Brewfest  --
----------------
L = DBM:GetModLocalization("Brew")

L:SetGeneralLocalization({
	name = "Brewfest"
})

L:SetOptionLocalization({
	NormalizeVolume			= "Automatically normalize the DIALOG sound channel volume to match music sound channel volume when in Brewfest area so that it's not so annoyingly loud. (If music sound volume is not set, then volume will be muted.)"
})

-----------------------------
--  The Headless Horseman  --
-----------------------------
L = DBM:GetModLocalization("d285")

L:SetWarningLocalization({
	WarnPhase				= "Phase %d",
	warnHorsemanSoldiers	= "Pulsing Pumpkins spawning",
	warnHorsemanHead		= "Head of the Horseman Active"
})

L:SetOptionLocalization({
	WarnPhase				= "Show a warning for each phase change",
	warnHorsemanSoldiers	= "Show warning for Pulsing Pumpkin spawn",
	warnHorsemanHead		= "Show warning for Head of the Horseman spawning"
})

L:SetMiscLocalization({
	HorsemanSummon			= "Horseman rise...",
	HorsemanSoldiers		= "Soldiers arise, stand and fight! Bring victory at last to this fallen knight!"
})

------------------------------
--  The Abominable Greench  --
------------------------------
L = DBM:GetModLocalization("Greench")

L:SetGeneralLocalization({
	name = "The Abominable Greench"
})

--------------------------
--  Plants Vs. Zombies  --
--------------------------
L = DBM:GetModLocalization("PlantsVsZombies")

L:SetGeneralLocalization({
	name = "Plants Vs. Zombies"
})

L:SetWarningLocalization({
	warnTotalAdds	= "Total zombies spawned since last massive wave: %d",
	specWarnWave	= "Massive Wave!"
})

L:SetTimerLocalization{
	timerWave		= "Next Massive Wave"
}

L:SetOptionLocalization({
	warnTotalAdds	= "Announce total add spawn count between each massive wave",
	specWarnWave	= "Show special warning when a Massive Wave begins",
	timerWave		= "Show timer for next Massive Wave"
})

L:SetMiscLocalization({
	MassiveWave		= "A Massive Wave of Zombies is Approaching!"
})

-- Quest
L = DBM:GetModLocalization("EscortQuests")

L:SetGeneralLocalization{
	name = "Escort Quests",
}

L:SetOptionLocalization{
	Timers = "Show timers for some escort quests"
}

--------------------------
--  Demonic Invasions  --
--------------------------
L = DBM:GetModLocalization("DemonInvasions")

L:SetGeneralLocalization({
	name = "Demonic Invasions"
})

--------------------------
--  Memories of Azeroth: Burning Crusade  --
--------------------------
L = DBM:GetModLocalization("BCEvent")

L:SetGeneralLocalization({
	name = "MoA: Burning Crusade"
})

--------------------------
--  Memories of Azeroth: Wrath of the Lich King  --
--------------------------
L = DBM:GetModLocalization("WrathEvent")

L:SetGeneralLocalization({
	name = "MoA: WotLK"
})

L:SetWarningLocalization{
	WarnEmerge				= "Anub'arak emerges",
	WarnEmergeSoon			= "Emerge in 10 seconds",
	WarnSubmerge			= "Anub'arak submerges",
	WarnSubmergeSoon		= "Submerge in 10 seconds",
	WarningTeleportNow		= "Teleported",
	WarningTeleportSoon		= "Teleport in 10 seconds"
}

L:SetTimerLocalization{
	TimerEmerge				= "Emerge",
	TimerSubmerge			= "Submerge",
	TimerTeleport			= "Teleport"
}

L:SetMiscLocalization{
	Emerge					= "emerges from the ground!",
	Burrow					= "burrows into the ground!"
}

L:SetOptionLocalization{
	WarnEmerge				= "Show warning for emerge",
	WarnEmergeSoon			= "Show pre-warning for emerge",
	WarnSubmerge			= "Show warning for submerge",
	WarnSubmergeSoon		= "Show pre-warning for submerge",
	TimerEmerge				= "Show timer for emerge",
	TimerSubmerge			= "Show timer for submerge",
	WarningTeleportNow		= "Show warning for Teleport",
	WarningTeleportSoon		= "Show pre-warning for Teleport",
	TimerTeleport			= "Show timer for Teleport"
}

--------------------------
--  Memories of Azeroth: Cataclysm  --
--------------------------
L = DBM:GetModLocalization("CataEvent")

L:SetGeneralLocalization({
	name = "MoA: Cataclysm"
})

L:SetWarningLocalization({
	warnSplittingBlow		= "%s in %s",--Spellname in Location
	warnEngulfingFlame		= "%s in %s"--Spellname in Location
})

L:SetOptionLocalization({
	warnSplittingBlow			= "Show location warnings for $spell:98951",
	warnEngulfingFlame			= "Show location warnings for $spell:99171"
})

----------------------------------
--  Azeroth Event World Bosses  --
----------------------------------

-- Lord Kazzak (Badlands)
L = DBM:GetModLocalization("KazzakClassic")

L:SetGeneralLocalization{
	name = "Lord Kazzak"
}

L:SetMiscLocalization({
	Pull		= "For the Legion! For Kil'Jaeden!"
})

-- Azuregos (Azshara)
L = DBM:GetModLocalization("Azuregos")

L:SetGeneralLocalization{
	name = "Azuregos"
}

L:SetMiscLocalization({
	Pull		= "This place is under my protection. The mysteries of the arcane shall remain inviolate."
})

-- Taerar (Ashenvale)
L = DBM:GetModLocalization("Taerar")

L:SetGeneralLocalization{
	name = "Taerar"
}

L:SetMiscLocalization({
	Pull		= "Peace is but a fleeting dream! Let the NIGHTMARE reign!"
})

-- Ysondre (Feralas)
L = DBM:GetModLocalization("Ysondre")

L:SetGeneralLocalization{
	name = "Ysondre"
}

L:SetMiscLocalization({
	Pull		= "The strands of LIFE have been severed! The Dreamers must be avenged!"
})

-- Lethon (Hinterlands)
L = DBM:GetModLocalization("Lethon")

L:SetGeneralLocalization{
	name = "Lethon"
}

L:SetMiscLocalization({
--	Pull		= "The strands of LIFE have been severed! The Dreamers must be avenged!"--Does not have one :\
})

-- Emeriss (Duskwood)
L = DBM:GetModLocalization("Emeriss")

L:SetGeneralLocalization{
	name = "Emeriss"
}

L:SetMiscLocalization({
	Pull		= "Hope is a DISEASE of the soul! This land shall wither and die!"
})

-- Doomwalker (Tanaris)
L = DBM:GetModLocalization("DoomwalkerEvent")

L:SetGeneralLocalization{
	name = "Doomwalker (Event)"
}

-- Archavon (???)
L = DBM:GetModLocalization("ArchavonEvent")

L:SetGeneralLocalization{
	name = "Archavon (Event)"
}

-- Sha of Anger (???)
L = DBM:GetModLocalization("ShaofAngerEvent")

L:SetGeneralLocalization{
	name = "Sha of Anger (Event)"
}

--------------------------
--  Blastenheimer 5000  --
--------------------------
L = DBM:GetModLocalization("Cannon")

L:SetGeneralLocalization({
	name = "Blastenheimer 5000"
})

L = DBM:GetModLocalization("CannonClassic")

L:SetGeneralLocalization({
	name = "Blastenheimer 5000"
})

-------------
--  Gnoll  --
-------------
L = DBM:GetModLocalization("Gnoll")

L:SetGeneralLocalization({
	name = "Whack-a-Gnoll"
})

L:SetWarningLocalization({
	warnGameOverQuest	= "Earned %d out of %d possible points spawned",
	warnGameOverNoQuest	= "Game ended with a total of %d possible points spawned",
	warnGnoll			= "Gnoll spawned",
	warnHogger			= "Hogger spawned",
	specWarnHogger		= "Hogger spawned!"
})

L:SetOptionLocalization({
	warnGameOver	= "Announce total possible points when game ends",
	warnGnoll		= "Announce when a Gnoll spawns",
	warnHogger		= "Announce when a Hogger spawns",
	specWarnHogger	= "Show special warning when a Hogger spawns"
})

------------------------
--  Shooting Gallery  --
------------------------
L = DBM:GetModLocalization("Shot")

L:SetGeneralLocalization({
	name = "Shooting Gallery"
})

L:SetOptionLocalization({
	SetBubbles			= "Automatically disable chat bubbles during $spell:101871<br/>(restores them when game ends)"
})

----------------------
--  Tonk Challenge  --
----------------------
L = DBM:GetModLocalization("Tonks")

L:SetGeneralLocalization({
	name = "Tonk Challenge"
})

---------------------------
--  Fire Ring Challenge  --
---------------------------
L = DBM:GetModLocalization("Rings")

L:SetGeneralLocalization({
	name = "Fire Ring Challenge"
})

-----------------------
--  Darkmoon Rabbit  --
-----------------------
L = DBM:GetModLocalization("Rabbit")

L:SetGeneralLocalization({
	name = "Darkmoon Rabbit"
})

-------------------------
--  Darkmoon Moonfang  --
-------------------------
L = DBM:GetModLocalization("Moonfang")

L:SetGeneralLocalization({
	name = "Moonfang"
})

L:SetWarningLocalization({
	specWarnCallPack		= "Call the Pack - Run > 40 yards from Moonfang!",
	specWarnMoonfangCurse	= "Moonfang's Curse - Run > 10 yards from Moonfang!"
})

L:SetOptionLocalization({
	specWarnCallPack		= DBM_CORE_L.AUTO_SPEC_WARN_OPTIONS.run:format(144602),
	specWarnMoonfangCurse	= DBM_CORE_L.AUTO_SPEC_WARN_OPTIONS.run:format(144590)
})
