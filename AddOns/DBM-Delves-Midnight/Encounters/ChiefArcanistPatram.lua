local mod	= DBM:NewMod("ChiefArcanistPatram", "DBM-Delves-Midnight", 2)
--local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260221022657")
--mod:SetCreatureID(0)--TODO
mod:SetEncounterID(3365)
mod:SetZone()

mod:RegisterCombat("combat")
