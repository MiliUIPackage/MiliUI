local addonName = ...
local addon = _G[addonName]
local LibStub = addon.LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("TLDRMissions")

function addon:wipeObsoleteMissionLog(missionID)
    TLDRMissionsLogging[missionID] = nil
end

function addon:logSentMission(missionID, followers, predictedFinalHP)
    local record = {}
    record.missionID = missionID
    record.followers = {}
    record.enemies = {}
    
    -- followers will be in order 1-5 1 being frontleft, 2 being frontmid, and so on to 5 being backright
    local positionToBoardIndex = {[1] = 2, [2] = 3, [3] = 4, [4] = 0, [5] = 1}
    for position, followerID in pairs(followers) do
        local minion = {}
        minion.followerID = followerID
        local info = addon:C_Garrison_GetFollowerAutoCombatStats(followerID)
        minion.HP = info.currentHealth
        minion.maxHP = info.maxHealth
        minion.baseAttack = info.attack
        minion.boardIndex = positionToBoardIndex[position]
        minion.name = C_Garrison.GetFollowerName(followerID)
        info = C_Garrison.GetFollowerInfo(followerID)
        minion.level = info.level
        minion.levelXP = info.levelXP
        minion.xp = info.xp
        if minion.levelXP == 0 then
            minion.levelXP = 1
            minion.xp = 0
        end
        
        if predictedFinalHP then
            minion.predictedFinalHP = predictedFinalHP[minion.boardIndex]
        end

        local autoCombatSpells, autoCombatAutoAttack = C_Garrison.GetFollowerAutoCombatSpells(followerID, info.level)
        minion.spells = {}
        for i, spell in pairs(autoCombatSpells) do
            table.insert(minion.spells, {
                ["spellID"] = spell.autoCombatSpellID,
                ["cooldown"] = spell.cooldown,
                ["duration"] = spell.duration,
            })
        end
        minion.autoAttack = {
            ["spellID"] = autoCombatAutoAttack.autoCombatSpellID,
            ["cooldown"] = autoCombatAutoAttack.cooldown,
            ["duration"] = autoCombatAutoAttack.duration,
        }
        
        table.insert(record.followers, minion)
    end
    
    local enemyID = -1
    for boardIndex, enemy in pairs(C_Garrison.GetMissionDeploymentInfo(missionID).enemies) do
        local minion = {}
        minion.followerID = enemyID
        enemyID = enemyID - 1
        minion.HP = enemy.health
        minion.maxHP = enemy.maxHealth
        minion.baseAttack = enemy.attack
        minion.boardIndex = enemy.boardIndex
        minion.name = enemy.name
    
        minion.spells = {}
        for i, spell in pairs(enemy.autoCombatSpells) do
            table.insert(minion.spells, {
                ["spellID"] = spell.autoCombatSpellID,
                ["cooldown"] = spell.cooldown,
                ["duration"] = spell.duration,
            })
        end
        minion.autoAttack = {
            ["spellID"] = enemy.autoCombatAutoAttack.autoCombatSpellID,
            ["cooldown"] = enemy.autoCombatAutoAttack.cooldown,
            ["duration"] = enemy.autoCombatAutoAttack.duration,
        }
        
        table.insert(record.enemies, minion)
    end
    
    record.environmentEffect = C_Garrison.GetAutoMissionEnvironmentEffect(missionID)
    
    record.addonVersion = GetAddOnMetadata(addonName, "Version")
    record.sentTime = time()
    
    TLDRMissionsLogging[missionID] = record
end

-- from Blizzards global strings, caching them here because I want english versions, not the players localized version
local COVENANT_MISSIONS_COMBAT_LOG_APPLY_AURA = "%s applied %s to %s.";
local COVENANT_MISSIONS_COMBAT_LOG_DIED = "%s killed %s.";
local COVENANT_MISSIONS_COMBAT_LOG_HEAL = "%s cast %s on %s for %d healing.";
local COVENANT_MISSIONS_COMBAT_LOG_MELEE_DAMAGE = "%s meleed %s for %d damage.";
local COVENANT_MISSIONS_COMBAT_LOG_PERIODIC_DAMAGE = "%s's %s dealt %d %s to %s.";
local COVENANT_MISSIONS_COMBAT_LOG_PERIODIC_HEAL = "%s's %s healed %s for %d.";
local COVENANT_MISSIONS_COMBAT_LOG_RANGE_DAMAGE = "%s shot %s for %d damage.";
local COVENANT_MISSIONS_COMBAT_LOG_REMOVE_AURA = "%s removed %s from %s.";
local COVENANT_MISSIONS_COMBAT_LOG_SPELL_MELEE_DAMAGE = "%s cast %s at %s for %d %s damage.";
local COVENANT_MISSIONS_COMBAT_LOG_SPELL_RANGE_DAMAGE = "%s cast %s at %s for %d %s damage.";


-- from Blizzard_AdventurescombatLog.lua
local function GetCombatLogEntryForEventType(spellName, eventType, caster, target, amount, element) 
	if element == nil then
		element = STRING_SCHOOL_UNKNOWN
	end

	if eventType == Enum.GarrAutoMissionEventType.MeleeDamage then
		return COVENANT_MISSIONS_COMBAT_LOG_MELEE_DAMAGE:format(caster, target, amount);
	elseif  eventType == Enum.GarrAutoMissionEventType.RangeDamage then
		return COVENANT_MISSIONS_COMBAT_LOG_RANGE_DAMAGE:format(caster, target, amount);
	elseif  eventType == Enum.GarrAutoMissionEventType.SpellMeleeDamage then
		return COVENANT_MISSIONS_COMBAT_LOG_SPELL_MELEE_DAMAGE:format(caster, spellName, target, amount, element);
	elseif  eventType == Enum.GarrAutoMissionEventType.SpellRangeDamage then
		return COVENANT_MISSIONS_COMBAT_LOG_SPELL_RANGE_DAMAGE:format(caster, spellName, target, amount, element);
	elseif  eventType == Enum.GarrAutoMissionEventType.PeriodicDamage then
		return COVENANT_MISSIONS_COMBAT_LOG_PERIODIC_DAMAGE:format(caster, spellName, amount, element, target);
	elseif  eventType == Enum.GarrAutoMissionEventType.ApplyAura then
		return COVENANT_MISSIONS_COMBAT_LOG_APPLY_AURA:format(caster, spellName, target);
	elseif  eventType == Enum.GarrAutoMissionEventType.Heal then
		return COVENANT_MISSIONS_COMBAT_LOG_HEAL:format(caster, spellName, target, amount);
	elseif  eventType == Enum.GarrAutoMissionEventType.PeriodicHeal then
		return COVENANT_MISSIONS_COMBAT_LOG_PERIODIC_HEAL:format(caster, spellName, target, amount);
	elseif  eventType == Enum.GarrAutoMissionEventType.Died then
		return COVENANT_MISSIONS_COMBAT_LOG_DIED:format(caster, target);
	elseif  eventType == Enum.GarrAutoMissionEventType.RemoveAura then
		return COVENANT_MISSIONS_COMBAT_LOG_REMOVE_AURA:format(caster, spellName, target);
	else 
		return COVENANT_MISSIONS_COMBAT_LOG_RANGE_DAMAGE:format(caster, target, amount);
	end
end

local printOnce = false
function addon:logCompletedMission(missionID, canComplete, success, overmaxSucceeded, followerDeaths, autoCombatResult)
    if not autoCombatResult then return end

    if autoCombatResult.winner then
        if addon.db.profile.DEVTESTING then
            if TLDRMissionsLogging[missionID] == nil then
                return
            end
        else
            TLDRMissionsLogging[missionID] = nil
            return
        end
    else
        if TLDRMissionsLogging[missionID] then
            if (TLDRMissionsLogging[missionID].addonVersion ~= GetAddOnMetadata(addonName, "Version")) and (not addon.db.profile.DEVTESTING) then return end
            if not printOnce then
                print(L["DiscrepancyError"])
                printOnce = true
            end
            addon.GUI.CompleteMissionsButton.usedShortcut = false
        else
            return
        end
    end
    
    local m
    for _, mission in pairs(C_Garrison.GetCompleteMissions(123)) do
        if mission.missionID == missionID then
            m = mission
            break
        end
    end
    if not m then
        print("error 37")
        return
    end
    
    local boardIndexes = {}
    for _, followerID in pairs(m.followers) do
        boardIndexes[C_Garrison.GetFollowerMissionCompleteInfo(followerID).boardIndex] = C_Garrison.GetFollowerMissionCompleteInfo(followerID).name
    end
    
    local missionDeploymentInfo = C_Garrison.GetMissionDeploymentInfo(missionID)
    for _, info in pairs(missionDeploymentInfo.enemies) do
        boardIndexes[info.boardIndex] = info.name
    end
    
    TLDRMissionsLogging[missionID].combatLog = {}
    local finalHealth = {}
    
    -- initialize to cover minions that are never damaged
    for _, minion in pairs(TLDRMissionsLogging[missionID].followers) do
        finalHealth[minion.boardIndex] = minion.HP
    end
    
    for roundNum, round in ipairs(autoCombatResult.combatLog) do
        table.insert(TLDRMissionsLogging[missionID].combatLog, ",")
        table.insert(TLDRMissionsLogging[missionID].combatLog, "Start of round "..roundNum)
        table.insert(TLDRMissionsLogging[missionID].combatLog, ",")
        
        for eventNum, event in pairs(round.events) do
            for targetNum, target in pairs(event.targetInfo) do
                if not event.casterBoardIndex then
                    event.casterBoardIndex = -1
                    boardIndexes[event.casterBoardIndex] = "???"
                elseif not boardIndexes[event.casterBoardIndex] then
                    boardIndexes[event.casterBoardIndex] = "Environment???"
                end
                
                table.insert(TLDRMissionsLogging[missionID].combatLog,
                        GetCombatLogEntryForEventType(
                            C_Garrison.GetCombatLogSpellInfo(event.spellID).name, 
                            event.type, 
                            boardIndexes[event.casterBoardIndex].."["..event.casterBoardIndex.."]", 
                            boardIndexes[target.boardIndex].."["..target.boardIndex.."]["..target.newHealth.."HP]", 
                            target.points, 
                            ""))
                        if target.newHealth then
                            finalHealth[target.boardIndex] = target.newHealth
                        end
            end
        end
    end
    
    TLDRMissionsLogging[missionID].finalHealth = finalHealth
    
    if addon.db.profile.DEVTESTING then
        if addon.db.profile.ZENKTESTING then
            if (not TLDRMissionsLogging[missionID].sentTime) or ((TLDRMissionsLogging[missionID].sentTime + 64800) < time()) then
                TLDRMissionsLogging[missionID] = nil
                return
            end
        end
        for boardIndex, HP in pairs(finalHealth) do
            for _, minion in pairs(TLDRMissionsLogging[missionID].followers) do
                if (minion.boardIndex == boardIndex) and minion.predictedFinalHP then
                    finalHealth[boardIndex] = tonumber(finalHealth[boardIndex])
                    minion.predictedFinalHP = tonumber(minion.predictedFinalHP)
                    
                    if finalHealth[boardIndex] < 0 then finalHealth[boardIndex] = 0 end
                    if minion.predictedFinalHP < 0 then minion.predictedFinalHP = 0 end
                    
                    if (finalHealth[boardIndex] < (minion.predictedFinalHP - 2)) or (finalHealth[boardIndex] > (minion.predictedFinalHP + 2)) then -- allow for small variance for minions healing slightly between sim and being sent
                    
                        -- new exception: allow Kyrian to have their damage taken overestimated by up to 20HP, due to rounding bug that I am now giving up trying to solve
                        -- eg: finalHealth 273, predictedFinalHP 270 - dont report anymore
                        if (C_Covenants.GetActiveCovenantID() == 1) and (finalHealth[boardIndex] > minion.predictedFinalHP) and ((finalHealth[boardIndex] - 20) < minion.predictedFinalHP) then
                            TLDRMissionsLogging[missionID] = nil
                            return
                        end
                        
                        print("DEVTESTING: Discrepancy for mission " ..missionID)
                        if WeakAuras then
                            WeakAuras.ScanEvents("TLDRMISSIONS_DEVTESTING")
                        end
                        addon.GUI.CompleteMissionsButton.usedShortcut = false
                        return
                    end
                end
            end
        end
        
        if autoCombatResult.winner then
            TLDRMissionsLogging[missionID] = nil
        end
    end
end