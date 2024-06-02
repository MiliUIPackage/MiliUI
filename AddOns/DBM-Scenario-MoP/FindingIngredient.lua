local mod	= DBM:NewMod("d745", "DBM-Scenario-MoP")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20200806142037")

mod:RegisterCombat("scenario", 1157)

mod:RegisterEventsInCombat(
	"CHAT_MSG_MONSTER_SAY"
)

function mod:CHAT_MSG_MONSTER_SAY(msg)
	if msg == L.Clear or msg:find(L.Clear) then
		DBM:EndCombat(self)
	end
end