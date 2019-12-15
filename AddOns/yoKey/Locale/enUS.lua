local _, ns = ...

local L = ns:NewLocale()

L.LOCALE_NAME = "enUS"

L["completion1"] = "Beat the timer for |cff8787ED%s [%s]|r in |cff00ffff%s|r. You were %s ahead of the timer, and missed +2 by %s."
L["completion2"] = "Beat the timer for +2 |cff8787ED%s [%s]|r in |cff00ffff%s|r. You were %s ahead of the +2 timer, and missed +3 by %s."
L["completion3"] = "Beat the timer for +3 |cff8787ED%s [%s]|r in |cff00ffff%s|r. You were %s ahead of the +3 timer."
L["completion0"] = "Timer expired for |cff8787ED[%s] %s|r with |cffff0000%s|r, you were %s over the time limit."

L["Schedule"] 	= "Schedule"
L["Rewards"] 	= "Rewards"
L["WeekLeader"] = "Week Leaders"

ns[1] = L
