local mod	= DBM:NewMod("z2962", "DBM-Delves-Midnight", 3)
--local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260221022657")
mod:SetHotfixNoticeRev(20250220000000)
mod:SetMinSyncRevision(20250220000000)
mod:SetZone(2962)

mod:RegisterCombat("scenario", 2962)
