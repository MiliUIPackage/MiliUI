# Details! Damage Meter

## [Details.20250225.13400.161](https://github.com/Tercioo/Details-Damage-Meter/tree/Details.20250225.13400.161) (2025-02-25)
[Full Changelog](https://github.com/Tercioo/Details-Damage-Meter/compare/Details.20250130.13390.161...Details.20250225.13400.161) 

- Release of all changes done to support the new incoming M+ addon.  
- Breakdown now get the displayId and subDisplayId from the breakdown window instead of the instance.  
- Added: Details:OpenSpecificBreakdownWindow(combatObject, actorName, mainAttribute, subAttribute)  
- Added mainAttributeOverride and subAttributeOverride parameters into Details:OpenBreakdownWindow()  
        local instance = Details:GetWindow(1)  
        local actor = Details:GetActor(0, 1, "Actorname") --got the damage actor  
        Details:OpenBreakdownWindow(instance, actor, false, false, false, false, false, 2, 1) --show healing  
- Removed the new m+ score board, it'll be in a plugin.  
- When inside a 'party' instance type, it'll record .mrating and .role (m+ rating and the player role) into the damage actor.  
- Added another breakdown at the end of m+. Currently under development. Added classCombat:GetInterruptCastAmount(actorName) and classCombat:GetCCCastAmount(actorName)  
