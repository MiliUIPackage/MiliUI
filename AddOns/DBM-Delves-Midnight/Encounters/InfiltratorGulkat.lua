local mod	= DBM:NewMod("InfiltratorGulkat", "DBM-Delves-Midnight", 2)
--local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal"
mod.soloChallenge = true

mod:SetRevision("20260227071859")
--mod:SetCreatureID(0)--TODO
mod:SetEncounterID(3361)
mod:SetZone()

mod:RegisterCombat("combat")
