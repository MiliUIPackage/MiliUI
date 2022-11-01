local addonName = "TLDRMissions"
local addon = _G[addonName]

local function print(...)
    if not TLDRMissionsDEVTESTING then return end
    
    local output = ""
    
    local function recursion(t)
        for h, v in pairs(t) do
            output = output.."||"..h.." | "..tostring(v).." | "
            if type(v) == "table" then
                recursion(v)
            end
        end
    end
    recursion({...})
    
    if not TLDRMissionsDB then TLDRMissionsDB = {} end
    table.insert(TLDRMissionsDB, output)
end

function addon:getClosestEnemy(follower, field, taunter)
    local priorityOrder = {
        -- testing found Chachi the Artiste in position 0 attcked 11 before 8 with no other enemies on the board
        -- Venthyr Soulcaster: attacked 10 before 7
        [0] = {5, 6, 10, 7, 9, 11, 8, 12},
        -- Venthyr Soulcaster: options 5+9+12 targetted 12
        [1] = {6, 7, 11, 8, 10, 12, 5, 9},
        [2] = {5, 6, 9, 10, 7, 11, 8, 12},
        -- Maldraxxus Shock Trooper meleed Confused Automa[9][3733HP] for 165 damage. Targetted 9 before 11. 
        [3] = {6, 7, 5, 10, 9, 11, 8, 12},
        -- when there was an enemy minion in 5; Meatball[4][2218HP] meleed Glimmerfly Matriarch[11][3596HP] for 522 damage
        -- when there were enemy minions in 5 and 10, Venthyr Nightblade[4][228HP] meleed Possessed Grovetender[10][1970HP] for 156 damage
        -- Options 5+9+12; Maldraxxus Plaguesinger[4] shot Deviant Scholar[12][750HP] for 420 damage.
        [4] = {7, 8, 6, 11, 10, 12, 5, 9},
        [5] = {2, 0, 3, 1, 4},
        [6] = {2, 3, 0, 1, 4},
        [7] = {3, 4, 2, 0, 1},
        [8] = {4, 3, 1, 2, 0},
        -- targetted 1 before 4 with no other options
        [9] = {2, 3, 0, 1, 4},
        [10] = {2, 3, 4, 0, 1},
        [11] = {2, 3, 4, 0, 1},
        [12] = {3, 4, 2, 0, 1},
    }
    
    if taunter then
        for _, minion in pairs(field) do
            if (minion.boardIndex == taunter.boardIndex) and (minion.HP > 0) then
                return minion
            end
        end
    end
    
    for _, i in pairs(priorityOrder[follower.boardIndex]) do
        for _, minion in pairs(field) do
            if (minion.boardIndex == i) and (not minion.shroud) and (minion.HP > 0) then
                return minion
            end
        end
    end
    
    print("Error: closest enemy not found", follower.name) -- this can happen if theres only one minion and it has shroud.
end

function addon:getCleaveEnemies(follower, field, taunter)
    local priorityOrder = {
        -- options 8+12 cleaved both
        -- options 7+8+10+11, taunted by 11, targetted 7+11
        [0] = {{5, 6}, {6}, {7, 9, 10, 11}, {9, 10, 11}, {10, 11}, {11, 7}, {8, 12}, {12}},
        -- Lost Sybille options 5+9 cleaved both
        -- options 5+8+10+11 taunted by 11 targetted 5+11
        -- options 5+11 targetted only 11 (no taunt) - see below
        [1] = {{6, 7}, {7}, {8, 10, 11, 12}, {10, 11, 12}, {11, 12, 5}, {12}, {5, 9}, {9}},
        -- options 7+11 cleaved them both
        -- options 8+11+12 targetted only 11
        -- options 5+6+8 taunted by 6, targetted only 6 - see below
        -- options 5+6+8 notaunt targetted 5+6
        [2] = {{6}, {5, 6}, {9, 10}, {10}, {7, 11}, {11}, {8, 12}, {12}},
        -- Kleia affected by taunt: options 5+7+8+10+11, taunted by 11, targetted 5+7+11
        -- Lost Sybille: options 8+12 cleaved both
        [3] = {{6, 7}, {7}, {5, 9, 10, 11}, {9, 10, 11}, {10, 11}, {11, 7, 5}, {8, 12}, {12}},
        -- options 9+11+12 targetted 11+12
        [4] = {{7, 8}, {8}, {6, 10, 11, 12}, {10, 11, 12}, {11, 12}, {12}, {5}, {9}},
        -- with nothing in slot 2, cleaved both 0 and 3            
        [5] = {{2}, {0, 3}, {3}, {1, 4}, {4}},
        [6] = {{2, 3}, {3}, {0}, {1}, {4}},
        [7] = {{3, 4}, {4}, {2, 0, 1}, {0, 1}, {1}},
        -- nothing in position 4, cleaved 1 and 3, but not 0 or 2
        -- nothing in 1 3 or 4, cleaved both 0 and 2
        [8] = {{4}, {1, 3}, {3}, {0, 2}, {2}},
        -- "Attack Wave" hit only 2 but not 3
        -- "Attack Wave" hit 4 and 1 with nothing else on the board
        -- "Attack Wave" options 0+1+4 targetted only 0
        [9] = {{2}, {3}, {0}, {4, 1}, {1}},
        -- from 10, Shiftless Smash only hit 2, did not hit 3
        -- Shiftless Smash options 0+1 only hit 0
        [10] = {{2}, {3}, {4}, {0}, {1}},
        -- from 11, hit 2+3
        [11] = {{2, 3}, {3}, {4}, {0, 1}, {1}},
        -- attack wave, options 0+1+2, targetted all 3
        [12] = {{3, 4}, {4}, {2, 0, 1}, {0, 1}, {1}},
    }
    
    local priorityPair
    local function getPriorityPair()
        for _, set in pairs(priorityOrder[follower.boardIndex]) do
            for _, minion in pairs(field) do
                if (minion.HP > 0) and (minion.boardIndex == set[1]) and (not minion.shroud) then
                    return set
                end
            end
        end
    end
    if taunter then

        local function getTauntPriorityPair()
            for _, set in ipairs(priorityOrder[follower.boardIndex]) do
                if set[1] == taunter.boardIndex then
                    return set
                end
            end
        end
        priorityPair = getTauntPriorityPair()
    else
        priorityOrder[1] = {{6, 7}, {7}, {8, 10, 11, 12}, {10, 11, 12}, {11, 12}, {12}, {5, 9}, {9}} -- conflict with an 11 that had taunted
        priorityOrder[2] = {{5, 6}, {6}, {9, 10}, {10}, {7, 11}, {11}, {8, 12}, {12}}
        priorityPair = getPriorityPair()
    end
    
    local targets = {}
    if not priorityPair then
        print("Error: could not find a priority pair in cleave enemies") -- could be all options are shrouded
        return targets
    end
    
    for _, i in pairs(priorityPair) do
        for _, minion in pairs(field) do
            if (minion.boardIndex == i) and (not minion.shroud) and (minion.HP > 0) then
                table.insert(targets, minion)
            end
        end
    end
    return targets
end

function addon:getFurthestEnemy(follower, field, taunter)
    local priorityOrder = {
        -- Llothwellyn: with position 8 dead, attacked 10 before 5
        -- Ardenweald Grovetender: with all frontline dead, attacked 9 before 11
        [0] = {12, 8, 9, 11, 10, 5, 7, 6},
        -- Simone: with 6/7/11 remaining, attacked 11 before 6
        [1] = {9, 5, 10, 12, 11, 6, 8, 7},
        [2] = {12, 8, 11, 7, 9, 10, 5, 6},
        [3] = {9, 12, 5, 8, 10, 11, 6, 7},
        [4] = {9, 5, 10, 6, 11, 12, 7, 8},
        -- possible targets: 0+2+3, targetted 3
        [5] = {4, 1, 3, 0, 2},
        [6] = {4, 1, 0, 2, 3},
        [7] = {2, 0, 1, 3, 4},
        [8] = {2, 0, 3, 1, 4},
        -- Boneweave Ambusher[9][2579HP] applied Ambush to Ardenweald Grovetender[0][1002HP] (instead of [3], 1 and 4 empty)
        [9] = {4, 1, 0, 3, 2},
        [10] = {1, 0, 4, 2, 3},
        [11] = {0, 1, 2, 3, 4},
        [12] = {2, 0, 1, 3, 4},
        }
   
    if taunter then
        for _, minion in pairs(field) do
            if (minion.boardIndex == taunter.boardIndex) and (minion.HP > 0) then
                return minion
            end
        end
    end
        
    for _, i in ipairs(priorityOrder[follower.boardIndex]) do
        for _, minion in pairs(field) do
            if (minion.boardIndex == i) and (not minion.shroud) and (minion.HP > 0) then
                return minion
            end
        end
    end
end

function addon:getClosestAlly(follower, field)
    local priorityOrder = {
        [0] = {2, 3, 1, 4},
        [1] = {0, 3, 4, 2},
        [2] = {0, 3, 1, 4},
        [3] = {2, 0, 1, 4},
        [4] = {3, 1, 2, 0},
        [5] = {9, 6, 10, 7, 11, 8, 12},
        [6] = {5, 10, 7, 9, 11, 8, 12},
        [7] = {6, 11, 8, 10, 12, 5, 9},
        [8] = {7, 12, 11, 6, 10, 5, 9},
        [9] = {5, 10, 6, 11, 7, 12, 8},
        [10] = {9, 6, 11, 5, 7, 12, 8},
        [11] = {10, 7, 12, 6, 8, 9, 5},
        [12] = {11, 8, 7, 10, 6, 9, 5},
    }
    
    for _, i in pairs(priorityOrder[follower.boardIndex]) do
        for _, minion in pairs(field) do
            if (minion.boardIndex == i) and (not minion.shroud) and (minion.HP > 0) then
                return minion
            end
        end
    end
    
    return follower -- some minions have been tested to target themselves when there are no other allies left. need to test if this is true for all "closest ally" spells
end

function addon:getLineEnemies(follower, field, taunter)
    local priorityOrder = {
        -- Actual:
        -- Molako cast Purification Ray at Privileged Contributor[1975HP] for 188  damage.
        -- Simulated had it hitting 7+11
        --
        -- Molako cast Purification Ray at Cruel Collector[7][804HP] for 196  damage.
        -- Simulated had it hitting 9
        -- Groono options 8+11 targetted 11
        [0] = {{5, 9}, {6, 10}, {10}, {7, 11}, {9}, {11}, {8, 12}, {12}},
        -- targets 5+8+9+10, but targetted only 8
        -- targets 5+9+10, targetted only 10
        -- targets 7+8+9+11, targetted 7+11
        -- targets 8+9+11, targetted 11
        -- options 9+12, targetted 12
        [1] = {{6, 10}, {7, 11}, {11}, {8, 12}, {10}, {5, 9}, {12}, {9}},
        -- options 7+9+12, targetted only 9
        -- options 8+10+11, targetted 10
        -- options 7+10+11, targetted 10
        -- Forest's Touch; options 8+11, targetted 11
        [2] = {{5, 9}, {6, 10}, {9}, {10}, {7, 11}, {11}, {8, 12}, {12}},
        -- options 8+10+11 targetted only 10
        -- options 8+11 targetted only 11
        -- options 5+7+10 targetted only 7  
        [3] = {{6, 10}, {7, 11}, {5, 9}, {10}, {11}, {8, 12}, {9}, {12}},
        -- options 5+9+10+11 targetted only 11
        -- options 5+9+10 targetted only 10
        [4] = {{7, 11}, {8, 12}, {6, 10}, {11}, {10}, {5, 9}, {12}, {9}},
        [5] = {{2, 0}, {3, 1}, {4}, {0}, {1}},
        [6] = {{2, 0}, {3, 1}, {4}, {0}, {1}},
        [7] = {{3, 1}, {4}, {2, 0}, {1}, {0}},
        [8] = {{4}, {3, 1}, {2, 0}, {1}, {0}},
        [9] = {{2, 0}, {3, 1}, {4}, {0}, {1}},
        [10] = {{2, 0}, {3, 1}, {4}, {0}, {1}},
        [11] = {{3, 1}, {4}, {2, 0}, {1}, {0}},
        [12] = {{4}, {3, 1}, {2, 0}, {1}, {0}},
    }
    
    local priorityPair
    local function getPriorityPair()
        for _, set in ipairs(priorityOrder[follower.boardIndex]) do
            for _, minion in pairs(field) do
                if (minion.HP > 0) and (minion.boardIndex == set[1]) and (not minion.shroud) then
                    return set
                end
            end
        end
    end
    priorityPair = getPriorityPair()
    
    if not priorityPair then return {} end
    
    local targets = {}
    for _, i in pairs(priorityPair) do
        for _, minion in pairs(field) do
            if (minion.HP > 0) and (minion.boardIndex == i) and (not minion.shroud) then
                table.insert(targets, minion)
            end
        end
    end
    
    return targets
end

function addon:getConeEnemies(follower, field, taunter)
    local priorityOrder = {
        -- other options were (7, 9, 11, 12) but hit just 10
        -- options 8+11+12, targetted only 11
        -- secutor mevix options 9+11+12, targetted only 9
        -- options 5+6+7+8+10+11, taunted by 11, targetted 6+10+11 
        [0] = {{5, 9, 10}, {6, 9, 10, 11}, {10}, {7, 10, 11, 12}, {9}, {11}, {8, 12}, {12}},
        -- Pamoptic beam 5 8 10 11 only hit 11
        -- options 5+8+10, targetted 8
        -- Guardian Kota options 5+10, targetted 10
        [1] = {{6, 9, 10, 11}, {7, 10, 11, 12}, {11}, {8, 12}, {10}, {5, 9}, {12}, {9}}, 
        -- Guardian Kota[2][187HP] cast Flashing Arrows at Majestic Runestag[10][3074HP] for 156 Physical damage. (7 8 10 11 on board, did not hit anything else)
        -- Secutor Mevix cast Secutor's Judgment at Larion Sire[528HP] for 259  damage. (9 10 12 on board, only hit 9)
        -- targets 8+11+12, only hit 11
        [2] = {{5, 9, 10}, {6, 9, 10, 11}, {9}, {10}, {7, 10, 11, 12}, {11}, {8, 12}, {12}},
        -- Secutor Mevix[3] cast Secutor's Judgment at Green Slime[11][0HP] for 365  damage. (8 11 on board, only hit 11)
        -- options 9+10+11+12 targetted 10
        -- options 9+11+12 targetted 9
        [3] = {{6, 9, 10, 11}, {7, 10, 11, 12}, {5, 9, 10}, {10}, {9}, {11}, {8, 12}, {12}},
        -- Secutor Mevix, options 9+10+12, targetted 10
        -- elgu options 5+9+10 targetted 10
        -- options 9+10+11+12 targetted 11
        [4] = {{7, 10, 11, 12}, {8, 11, 12}, {6, 9, 10, 11}, {11}, {10}, {5, 9, 10}, {12}, {9}},
        [5] = {{0, 2}, {2}, {3, 1}, {1}, {4}},
        -- 0+1+4 but targetted only 0
        [6] = {{2, 0}, {3, 0, 1}, {0}, {4, 1}, {1}},
        [7] = {{3, 0, 1}, {4, 1}, {2, 0}, {0}, {1}},
        [8] = {{4, 1}, {3, 0, 1}, {1}, {2, 0}, {0}},
        -- Stygian Bombardier[9] cast Darkness from Above at Maldraxxus Shock Trooper[0][138HP] for 177  damage. when 0 + 1 + 4 were options
        [9] = {{2, 0}, {3, 0, 1}, {0}, {1}, {4}},
        [10] = {{2, 0}, {3, 0, 1}, {4, 1}, {0}, {1}},
        [11] = {{2, 0}, {3, 0, 1}, {4, 1}, {0}, {1}},
        -- tested with followers in all slots, enemy Deviant Scholar hit 3+0+1 ignoring 4
        -- options 0+1, hit 0
        [12] = {{3, 0, 1}, {4, 1}, {2, 0}, {0}, {1}},
    }
  
    local targets = {}
    if taunter then
        local function getTauntPriorityPair()
            for _, set in ipairs(priorityOrder[follower.boardIndex]) do
                for _, v in pairs(set) do
                    if v == taunter.boardIndex then
                        return set
                    end
                end
            end
        end 
        for _, v in pairs(getTauntPriorityPair()) do
            for _, minion in pairs(field) do
                if (minion.HP > 0) and (not minion.shroud) and (minion.boardIndex == v) then
                    table.insert(targets, minion)
                end
            end
        end
    else
        for _, set in pairs(priorityOrder[follower.boardIndex]) do
            for _, minion in pairs(field) do
                if (minion.HP > 0) and (not minion.shroud) and (minion.boardIndex == set[1]) then
                    for _, i in ipairs(set) do
                        for _, minion2 in pairs(field) do
                            if (minion2.boardIndex == i) and (minion2.HP > 0) and (not minion2.shroud) then
                                table.insert(targets, minion2)
                            end
                        end
                    end
                    return targets
                end
            end
        end
    end
    
    return targets
end

function addon:getAdjacentAllies(follower, field)
    local priorityOrder = {
        [0] = {{2, 3, 1}, {0}},
        [1] = {{0, 3, 4}},
        [2] = {{0, 3}},
        [3] = {{2, 0, 1, 4}},
        [4] = {{3, 1}},
        [5] = {{6, 9, 10}},
        [6] = {{5, 7, 9, 10, 11}},
        [7] = {{6, 8, 10, 11, 12}},
        [8] = {{7, 11, 12}},
        [9] = {{5, 6, 10}},
        [10] = {{5, 6, 7, 9, 11}},
        [11] = {{6, 7, 8, 10, 12}},
        [12] = {{7, 8, 11}},
    }
    
    local targets = {}
    
    for _, set in ipairs(priorityOrder[follower.boardIndex]) do
        for _, minion in pairs(field) do
            for _, i in pairs(set) do
                if (minion.boardIndex == i) and (minion.HP > 0) then
                    table.insert(targets, minion)
                end
            end
        end
        if table.getn(targets) > 0 then return targets end
    end
    
    -- probably needs an expanded priority list, investigate with more logs
    if table.getn(targets) == 0 then
        return addon:getAllAllies(follower, field)
    end
    
    return targets
end

function addon:getAdjacentAlliesOrAllAllies(follower, field)
    local priorityOrder = {
        [0] = {2, 3, 1},
        [1] = {0, 3, 4},
        [2] = {0, 3},
        [3] = {2, 0, 1, 4},
        [4] = {3, 1},
        [5] = {6, 9, 10},
        [6] = {5, 7, 9, 10, 11},
        [7] = {6, 8, 10, 11, 12},
        [8] = {7, 11, 12},
        [9] = {5, 6, 10},
        [10] = {5, 6, 7, 9, 11},
        [11] = {6, 7, 8, 10, 12},
        [12] = {7, 8, 11},
    }
    
    local targets = {}
    
    for _, minion in pairs(field) do
        for _, i in pairs(priorityOrder[follower.boardIndex]) do
            if (minion.boardIndex == i) and (minion.HP > 0) then
                table.insert(targets, minion)
            end
        end
    end
    
    -- inconsistent targetting problem:
    -- log 1 - madame iza is in slot 4, only other follower is in slot 0. the heal targets both 0 and 4
    -- log 2 - madame iza is in slot 0, only other follower is in slot 4. the heal only targets 0
    
    if table.getn(targets) == 0 then
        if follower.boardIndex == 0 then
            return {follower}
        else
            return addon:getAllAllies(follower, field)
        end
    end
    
    return targets
end

function addon:getFrontEnemies(follower, field, taunter)
    local targets = {}
    
    -- tezan's spell was affected by taunt. further testing needed to find if taunt affects all "get front enemies" spells
    if taunter and ((taunter.boardIndex < 2) or (taunter.boardIndex > 8)) then
        for _, minion in pairs(field) do
            if minion.HP > 0 then
                if (follower.boardIndex > 4) and (minion.boardIndex < 2) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                elseif (follower.boardIndex < 5) and (minion.boardIndex > 8) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                end
            end
        end
    else
        for _, minion in pairs(field) do
            if minion.HP > 0 then
                if (follower.boardIndex > 4) and (minion.boardIndex > 1) and (minion.boardIndex < 5) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                elseif (follower.boardIndex < 5) and (minion.boardIndex > 4) and (minion.boardIndex < 9) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                end
            end
        end
    end
    
    if table.getn(targets) == 0 then
        for _, minion in pairs(field) do
            if minion.HP > 0 then
                if (follower.boardIndex > 4) and (minion.boardIndex < 5) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                elseif (follower.boardIndex < 5) and (minion.boardIndex > 4) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                end
            end
        end
    end
    
    return targets
end

function addon:getBackEnemies(follower, field, taunter)
    local targets = {}
    
    for _, minion in pairs(field) do
        if minion.HP > 0 then
            if (follower.boardIndex > 4) and (minion.boardIndex < 2) and (not minion.shroud) and (minion.HP > 0) then
                table.insert(targets, minion)
            elseif (follower.boardIndex < 5) and (minion.boardIndex > 8) and (not minion.shroud) and (minion.HP > 0) then
                table.insert(targets, minion)
            end
        end
    end
    
    if taunter then
        -- have not yet determined the true process here
        -- caster in [1], options 5 6 7 8 10 11 taunted by 11, targetted 10+11
        -- had another log where caster was taunted, and targetted only the taunt, with 3 other minions on the back row ignored. Do not have that log available to check anymore
        -- contracdicting above line, have a log with 5+6+7+8+9+10+11+12, taunted by 10, targetted 9+10+11+12
        --if table.getn(targets) > 2 then
        --    return {taunter}
        --end
        -- have a log with 6 9 10 11 12, taunted by 6, targetted only 6
        if (follower.boardIndex < 5) and (taunter.boardIndex < 9) then
            return addon:getFrontEnemies(follower, field, taunter)
        end
    end
    
    if table.getn(targets) == 0 then
        -- if theres no back row enemies left, it targets the front row ones instead
        for _, minion in pairs(field) do
            if minion.HP > 0 then
                if (follower.boardIndex > 4) and (minion.boardIndex < 5) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                elseif (follower.boardIndex < 5) and (minion.boardIndex > 4) and (not minion.shroud) and (minion.HP > 0) then
                    table.insert(targets, minion)
                end
            end
        end
    end
    
    return targets
end

function addon:getOtherAllies(follower, field)
    local targets = {}
    
    for _, minion in pairs(field) do
        if (minion.boardIndex ~= follower.boardIndex) and (minion.HP > 0) and (((follower.boardIndex < 5) and (minion.boardIndex < 5)) or ((follower.boardIndex > 4) and (minion.boardIndex > 4))) then
            table.insert(targets, minion)
        end
    end
    
    return targets
end

function addon:getAllAllies(follower, field)
    local targets = {}
    
    for _, minion in pairs(field) do
        if (minion.HP > 0) and (((follower.boardIndex < 5) and (minion.boardIndex < 5) ) or ((follower.boardIndex > 4) and (minion.boardIndex > 4))) then
            table.insert(targets, minion)
        end
    end
    
    return targets
end

function addon:getAllEnemies(follower, field, taunter)
    local targets = {}
    
    for _, minion in pairs(field) do
        if (((follower.boardIndex < 5) and (minion.boardIndex > 4)) or ((follower.boardIndex > 4) and (minion.boardIndex < 5))) and (minion.HP > 0) and (not minion.shroud) then
            table.insert(targets, minion)
        end
    end
    
    return targets
end

function addon:getFrontAllies(follower, field)
    -- testing with spell ID 126 Possessive Healing, enemy is in backleft position, its two front allies are dead,
    -- the healing spell did not heal itsself, but did heal the backright ally
    -- testing with spell ID 123 Healing Winds, the caster was the last remaining minion and it did heal itsself
    
    local targets = {}
    
    for _, minion in pairs(field) do
        if (follower.boardIndex > 4) and (minion.boardIndex > 4) and (minion.boardIndex < 9) and (minion.HP > 0) and (follower.boardIndex ~= minion.boardIndex) then
            table.insert(targets, minion)
        elseif (follower.boardIndex < 5) and (minion.boardIndex > 1) and (minion.boardIndex < 5) and (minion.HP > 0) and (follower.boardIndex ~= minion.boardIndex) then
            table.insert(targets, minion)
        end
    end
    
    if table.getn(targets) == 0 then
        targets = addon:getOtherAllies(follower, field)
    end
    
    if table.getn(targets) == 0 then
        table.insert(targets, follower)
    end
    
    return targets
end

function addon:getBackAllies(follower, field)
    local targets = {}
    
    for _, minion in pairs(field) do
        if (follower.boardIndex < 5) and (minion.boardIndex < 2) and (minion.HP > 0) then
            table.insert(targets, minion)
        elseif (follower.boardIndex > 4) and (minion.boardIndex > 8) and (minion.HP > 0) then
            table.insert(targets, minion)
        end
    end
    
    if table.getn(targets) == 0 then
        return addon:getAllAllies(follower, field)
    end
    
    return targets
end

function addon:getNearbyAllyOrSelf(follower, field)
    local priorityOrder = {
        [0] = {2, 3, 1, 0},
        -- Revitalizing Vines: 1 cast on 2 even though not "nearby"
        [1] = {0, 3, 4, 2, 1},
        [2] = {0, 3, 2},
        [3] = {2, 0, 1, 4, 3},
        -- wtf 0 wont target 4, but 4 does target 0?
        -- Revitalizing Vines: 4 targetted 2 even though thats not "nearby". Maybe this spell uses different logic?
        [4] = {3, 1, 2, 0, 4},
        [5] = {9, 10, 6, 5},
        [6] = {5, 10, 9, 7, 11, 6},
        [7] = {6, 11, 10, 12, 8, 7},
        -- defense of the drust cast from 8 to 6, maybe it doesn't use this target type?
        [8] = {7, 11, 12, 6, 8},
        [9] = {5, 10, 6, 9},
        -- "CHARGE!" options 7+8+10+11+12 targetted 11
        -- "CHARGE!" options 5+6+7+10 targetted 6
        -- CHARGE! options 5+7+8+10+11 targetted 11
        [10] = {9, 6, 11, 5, 7, 10},
        [11] = {10, 6, 7, 8, 12, 11},
        [12] = {11, 7, 8, 12},
    }
    
    local targets = {}
    
    for _, i in ipairs(priorityOrder[follower.boardIndex]) do
        for _, minion in pairs(field) do
            if (minion.boardIndex == i) and (minion.HP > 0) then
                table.insert(targets, minion)
                return targets
            end
        end
    end
    
    return targets
end

function addon:getPseudorandomMawswornStrength(follower, field)
    local targets = {}
    
    local patterns = {
        -- observed in 2208
        -- see https://github.com/teelolws/TLDRMissions/issues/92
        {alive = {0, 1, 2, 3, 4}, target = 1},
        {alive = {0, 1, 3, 4}, target = 4},
        {alive = {1, 2, 4}, target = 2},
        {alive = {0, 1, 4}, target = 1},
        {alive = {0, 1}, target = 1},
        {alive = {0, 1, 2, 4}, target = 4},
        
        -- observed in 2188 [Deranged Gouge]
        -- see https://github.com/teelolws/TLDRMissions/issues/88
        {alive = {0, 2, 3, 4}, target = 4},
        {alive = {0, 2}, target = 2},
        {alive = {0, 2, 3}, target = 2},
        {alive = {0, 1, 2, 3}, target = 3},
        {alive = {0, 1, 2}, target = 1},
        {alive = {0, 3, 4}, target = 3},
        {alive = {1, 2, 3}, target = 2},
        {alive = {2, 4}, target = 4},
        {alive = {1, 3}, target = 3},
        
        -- observed in 2185 [Goading Motivation]
        -- see https://github.com/TLDRMissions/TLDRMissions/issues/142
        {alive = {1, 2, 3, 4}, target = 4},
        {alive = {1, 2}, target = 2},
        
        -- observed in 2278 (Deranged Gouge)
        {alive = {1, 3, 4}, target = 3},
        {alive = {1, 4}, target = 4},
        
        -- observed in 2242 (Mental Assault)
        {alive = {2, 3}, target = 3},
        
        -- observed in 2254 (Mawsworn Strength)
        {alive = {2, 3, 4}, target = 3},
    }
    
    local aliveMinions = {}
    
    for _, minion in pairs(field) do
        if (minion.boardIndex < 5) and (minion.HP > 0) and (not minion.shroud) then
            aliveMinions[minion.boardIndex] = true
        end
    end
    
    local numAliveMinions = 0
    
    for _ in pairs(aliveMinions) do
        numAliveMinions = numAliveMinions + 1
    end
    
    for _, pattern in pairs(patterns) do
        if table.getn(pattern.alive) == numAliveMinions then
            local match = true
            for minion, _ in pairs(aliveMinions) do
                local m = false
                for _, p in pairs(pattern.alive) do
                    if minion == p then
                        m = true
                    end
                end
                if m == false then
                    match = false
                end
            end
            
            if match then
                for _, minion in pairs(field) do
                    if minion.boardIndex == pattern.target then
                        table.insert(targets, minion)
                        return targets
                    end
                end
            end
        end
    end
    
    local priorityList = {1, 2, 4, 3, 0}

    -- if code reaches here, the combination of alive minions isn't in the lists yet, or theres just 1 minion left alive
    for i = 1, 5 do
        for _, minion in pairs(field) do
            if (minion.boardIndex == priorityList[i]) and (minion.HP > 0) and (not minion.shroud) then
                table.insert(targets, minion)
                return targets
            end
        end
    end
    
    return targets
end

function addon:getPseudorandomRitualFervor(follower, field)
    local targets = {}
    
    local patterns = {
        -- observed in 2221
        -- see https://github.com/teelolws/TLDRMissions/issues/86
        {alive = {6, 7, 9, 10, 11, 12}, target = 7},
        {alive = {6, 7, 10, 11}, target = 11},
        {alive = {7, 9, 11}, target = 9},
        {alive = {6, 7, 11}, target = 7},
        {alive = {6, 7, 9, 10, 11}, target = 7},
        {alive = {7, 11, 12}, target = 11},
        {alive = {7, 9, 10, 11, 12}, target = 9},
        {alive = {11, 12}, target = 12},
        {alive = {9, 10, 11, 12}, target = 12},
        {alive = {7, 10, 11, 12}, target = 12},
        {alive = {7, 10, 11}, target = 10},
        {alive = {7, 9, 10, 11}, target = 11},
        {alive = {7, 10}, target = 10},
        {alive = {7, 9}, target = 9},
        {alive = {6, 7, 9, 10}, target = 10},
        {alive = {7, 9, 10}, target = 9},
        
        -- observed in 2226
        -- see https://github.com/teelolws/TLDRMissions/issues/127
        {alive = {7, 8, 9, 10, 11, 12}, target = 8},
        {alive = {5, 6, 7, 8, 9, 10, 11, 12}, target = 12},
        {alive = {8, 9, 10, 11, 12}, target = 9},
        {alive = {6, 7, 8, 10, 11}, target = 7},
        {alive = {7, 11}, target = 11},
        {alive = {7, 8, 11, 12}, target = 12},
        {alive = {8, 11, 12}, target = 11},
        {alive = {8, 10, 11, 12}, target = 12},
        {alive = {8, 12}, target = 12},
        {alive = {8, 9, 11}, target = 9},
        {alive = {9, 10, 12}, target = 10},
        {alive = {6, 7, 8, 10, 11, 12}, target = 7},
        {alive = {7, 8, 11}, target = 8},
        {alive = {8, 11}, target = 11},
        {alive = {7, 8, 10, 11}, target = 11},
        {alive = {6, 7, 8, 11}, target = 11},
        {alive = {5, 8, 9, 10, 11}, target = 8},
        {alive = {5, 6, 7, 8, 10, 11}, target = 6},
        {alive = {7, 8}, target = 8},
        {alive = {5, 8, 11}, target = 8},
        {alive = {5, 7, 8, 11}, target = 11},
        {alive = {6, 7, 8, 11, 12}, target = 7},
        {alive = {7, 8, 9, 10, 11}, target = 8},
        
        -- observed in 2281
        -- see https://github.com/teelolws/TLDRMissions/issues/98
        {alive = {5, 8, 10}, target = 8},
        {alive = {5, 10}, target = 10},
        {alive = {8, 10}, target = 10},
        
        -- observed in 2285
        -- see https://github.com/teelolws/TLDRMissions/issues/111
        {alive = {5, 8, 10, 11}, target = 11},
        {alive = {10, 11}, target = 11},
        {alive = {8, 10, 11}, target = 10},
        {alive = {5, 10, 11}, target = 10},
        
        -- observed in 2282 [Anima Leech]
        -- see https://github.com/teelolws/TLDRMissions/issues/87
        {alive = {6, 7}, target = 7},
        {alive = {6, 9, 10, 11, 12}, target = 9},
        {alive = {9, 11, 12}, target = 11},
        {alive = {9, 10, 11, 12}, target = 12},
        {alive = {6, 7, 10, 11, 12}, target = 7},
        {alive = {10, 11, 12}, target = 11},
        {alive = {9, 10, 11}, target = 10},
        {alive = {6, 10, 11}, target = 10},
        {alive = {9, 10}, target = 10},
        
        -- observed in 2239 [Leeching Bite]
        -- see https://github.com/teelolws/TLDRMissions/issues/112
        {alive = {5, 8, 9, 10, 11, 12}, target = 8},
        {alive = {9, 12}, target = 12},
        {alive = {7, 8, 10, 11, 12}, target = 8},
        {alive = {5, 7, 8, 10, 11, 12}, target = 7},
        {alive = {5, 6, 7, 8, 9, 10, 11}, target = 11},
        {alive = {5, 7, 10, 11}, target = 11},
        {alive = {8, 10, 12}, target = 10},
        {alive = {6, 8, 10, 11, 12}, target = 8},
        {alive = {8, 9, 10}, target = 9},
        {alive = {5, 6, 8, 9, 10, 11}, target = 6},
        {alive = {5, 8, 9, 10}, target = 10},
        {alive = {5, 8, 10, 11, 12}, target = 8},
        {alive = {8, 9}, target = 9},
        
        -- observed in 2258 [Environment Effect]
        {alive = {5, 6, 7, 8, 9, 10}, target = 6},
        {alive = {6, 10}, target = 10},
        {alive = {5, 6, 7, 10}, target = 10},
        {alive = {5, 9, 10}, target = 9},
        {alive = {5, 7, 9, 10}, target = 10},
        
        -- observed in 2259 [Environment Effect]
        {alive = {7, 8, 10}, target = 8},
        
        -- observed in 2299 [Power of Anguish]
        {alive = {6, 7, 9, 12}, target = 12},
        {alive = {7, 12}, target = 12},
        {alive = {7, 9, 12}, target = 9},  
    }
    
    local aliveMinions = {} -- counting "shroud" as dead for this
    
    for _, minion in pairs(field) do
        if (minion.boardIndex > 4) and (minion.HP > 0) and (not minion.shroud) then
            aliveMinions[minion.boardIndex] = true
        end
    end
    
    local numAliveMinions = 0
    
    for _ in pairs(aliveMinions) do
        numAliveMinions = numAliveMinions + 1
    end
    
    for _, pattern in pairs(patterns) do
        if table.getn(pattern.alive) == numAliveMinions then
            local match = true
            for minion, _ in pairs(aliveMinions) do
                local m = false
                for _, p in pairs(pattern.alive) do
                    if minion == p then
                        m = true
                    end
                end
                if m == false then
                    match = false
                end
            end
            
            if match then
                for _, minion in pairs(field) do
                    if minion.boardIndex == pattern.target then
                        table.insert(targets, minion)
                        return targets
                    end
                end
            end
        end
    end
    
    local priorityList = {12, 7, 11, 8, 5, 6, 9, 10}

    -- if code reaches here, the combination of alive minions isn't in the lists yet, or theres just 1 minion left alive
    for i = 1, 8 do
        for _, minion in pairs(field) do
            if (minion.boardIndex == priorityList[i]) and (minion.HP > 0) then
                table.insert(targets, minion)
                return targets
            end
        end
    end
    
    return targets
end

function addon:getPseudorandomLashOut(follower, field)   
    local patterns = {
        -- observed in 2238
        -- see https://github.com/TLDRMissions/TLDRMissions/issues/89
        {alive = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10}, target = 1},
        {alive = {0, 1, 3, 4, 5, 10}, target = 1},
        {alive = {0, 1, 2, 3, 4, 6, 7, 8, 10}, target = 4},
        {alive = {0, 1, 3, 5, 6, 7, 8, 10}, target = 10},
        {alive = {0, 1, 3, 8, 10}, target = 1},
        {alive = {0, 1, 2, 3, 5, 6, 7, 8, 10}, target = 5},
        {alive = {0, 1, 2, 3, 8, 10}, target = 1},
        {alive = {0, 2, 3, 4, 5, 6, 7, 8, 10}, target = 5},
        {alive = {0, 2, 4, 8, 10}, target = 2},
        {alive = {0, 1, 2, 3, 4, 8, 10}, target = 10},
        {alive = {0, 2, 3, 4, 6, 7, 8, 10}, target = 10},
        {alive = {0, 2, 3, 4, 8, 10}, target = 2},
        {alive = {0, 1, 2, 3, 6, 7, 8, 10}, target = 10},
        {alive = {0, 1, 2, 3, 7, 8, 10}, target = 10},
        {alive = {0, 1, 3, 4, 6, 7, 8, 10}, target = 10},
        {alive = {0, 1, 8, 10}, target = 10},
        {alive = {0, 1, 3, 4, 8, 10}, target = 1},
        {alive = {0, 1, 5, 10}, target = 10},
        {alive = {0, 1, 2, 3, 4, 7}, target = 1},
        {alive = {0, 1, 3, 4, 6, 7}, target = 1},
        {alive = {0, 1, 2, 7, 10}, target = 1},
        {alive = {0, 1, 3, 4, 7, 8, 10}, target = 10},
        {alive = {0, 1, 7, 8, 10}, target = 1},
        {alive = {0, 2, 3, 5, 6, 7, 8, 10}, target = 10},
        {alive = {0, 2, 3, 6, 7, 10}, target = 2},
        {alive = {0, 7, 10}, target = 7},
        {alive = {0, 3, 4, 8, 10}, target = 3},
        {alive = {0, 1, 2, 3, 4, 6, 7}, target = 7},
        {alive = {0, 1, 3, 4, 6, 7, 10}, target = 10},
        {alive = {0, 1, 2, 8, 10}, target = 1},
        {alive = {0, 8}, target = 8},
        {alive = {0, 1, 4, 6, 7, 10}, target = 1},
        {alive = {0, 4, 6, 7, 10}, target = 4},
        {alive = {0, 6, 7}, target = 6},
        {alive = {0, 2, 6, 7, 10}, target = 2},
        {alive = {0, 2, 6, 7}, target = 7},
        {alive = {0, 1, 3, 4, 5, 6, 7, 8, 10}, target = 5},
        {alive = {0, 1, 2, 3, 4, 7, 8, 10}, target = 10},
        {alive = {0, 1, 3, 7, 8}, target = 1},
        {alive = {0, 3, 6, 7, 10}, target = 3},
        {alive = {0, 2, 3, 7, 8, 10}, target = 2},
        {alive = {0, 7, 8}, target = 7},
        {alive = {0, 2, 3, 4, 6, 7, 10}, target = 10},
        {alive = {0, 3, 4, 7}, target = 7},
        {alive = {0, 7}, target = 7},
        {alive = {0, 1, 4, 8, 10}, target = 1},
        {alive = {0, 2, 4, 7, 10}, target = 2},
        {alive = {0, 2, 8, 10}, target = 10},
        {alive = {3, 4, 5, 6, 7, 8, 10}, target = 10},
        {alive = {3, 4, 5, 8, 10}, target = 4},
        {alive = {3, 8, 10}, target = 8},
        {alive = {0, 1, 6, 7, 10}, target = 1},
        {alive = {0, 6, 7, 10}, target = 10},
        {alive = {0, 3, 4, 6, 7, 10}, target = 3},
        {alive = {0, 4, 6}, target = 4},
        {alive = {0, 1, 4, 7}, target = 7},
        {alive = {0, 4, 7}, target = 4},
        {alive = {3, 4, 8, 10}, target = 10},
        {alive = {0, 1, 6, 7}, target = 7},
        {alive = {0, 1, 2, 6, 7, 10}, target = 1},
        {alive = {0, 1, 7, 8}, target = 8},
        {alive = {0, 6}, target = 6},
        {alive = {0, 1, 8}, target = 1},
        {alive = {0, 3, 4, 7, 10}, target = 3},
        {alive = {0, 4, 6, 7}, target = 7},
        {alive = {0, 3, 7, 8, 10}, target = 3},
        {alive = {0, 2, 3, 4, 6, 10}, target = 2},
        {alive = {0, 4, 7, 10}, target = 10},
        {alive = {0, 1, 2, 3, 6, 7, 10}, target = 10},
        {alive = {0, 2, 7, 8, 10}, target = 2},
        {alive = {0, 1, 2, 3, 7, 10}, target = 1},
        {alive = {0, 2, 7}, target = 2},
        {alive = {0, 1, 2, 6, 7}, target = 1},
        {alive = {0, 4, 8, 10}, target = 10},
        {alive = {0, 1, 3, 6, 7, 10}, target = 1},
        {alive = {0, 2, 3, 4, 7, 10}, target = 2},
        {alive = {1, 7, 10}, target = 7},
        {alive = {0, 1, 6}, target = 1},
        {alive = {0, 2, 3, 7, 10}, target = 2},
        {alive = {0, 1, 3, 4, 5, 6, 7, 10}, target = 10},
        {alive = {1, 2, 5, 6, 7, 8, 10}, target = 10},
        {alive = {1, 2, 6, 7, 8, 10}, target = 2},
        {alive = {0, 2, 8}, target = 2},
        {alive = {0, 4, 8}, target = 4},
        {alive = {0, 3, 5, 6, 7, 10}, target = 3},
        {alive = {0, 1, 2, 3, 5, 10}, target = 1},
        {alive = {0, 1, 3, 4, 7}, target = 1},

        -- observed in 2224 (Panic Attack)
        -- see https://github.com/TLDRMissions/TLDRMissions/issues/120
        {alive = {0, 1, 2, 3, 4, 7, 9, 10, 11, 12}, target = 1},
        {alive = {0, 2, 3, 4, 7, 9, 10, 11, 12}, target = 7},
        {alive = {0, 4, 11, 12}, target = 12},
        {alive = {0, 12}, target = 12},
        {alive = {0, 1, 2, 3, 4, 6, 7, 9, 10, 11, 12}, target = 3},
        {alive = {0, 1, 7, 11, 12}, target = 1},
        {alive = {1, 7, 11, 12}, target = 12},
        {alive = {0, 1, 2, 4, 6, 7, 9, 10, 11, 12}, target = 1},
        {alive = {0, 1, 2, 3, 6, 7, 9, 10, 11, 12}, target = 1},
        {alive = {0, 2, 3, 6, 7, 9, 10, 11, 12}, target = 7},
        {alive = {0, 3, 7, 9, 10, 11}, target = 3},
        {alive = {0, 7, 9, 10, 11}, target = 7},
        {alive = {0, 1, 4, 9, 11, 12}, target = 1},
        {alive = {0, 4, 9, 11, 12}, target = 4},
        {alive = {0, 11, 12}, target = 11},
        {alive = {0, 1, 2, 3, 7, 9, 10, 11, 12}, target = 7},
        {alive = {0, 1, 3, 11, 12}, target = 1},
        {alive = {0, 1, 3, 7, 11, 12}, target = 1},
        {alive = {0, 3, 7, 11, 12}, target = 3},
        {alive = {0, 1, 4, 6, 7, 11}, target = 1},
        {alive = {0, 1, 7}, target = 1},
        {alive = {0, 1, 4, 7, 11, 12}, target = 1},
        {alive = {0, 1, 2, 3, 4, 6, 7, 9, 10, 11}, target = 1},
        {alive = {1, 11, 12}, target = 11},
        {alive = {0, 2, 3, 7, 10, 11}, target = 2},
        {alive = {0, 1, 11, 12}, target = 12},
        {alive = {1, 2, 3, 4, 6, 7, 9, 10, 11, 12}, target = 2},
        {alive = {1, 4, 6, 7, 11, 12}, target = 4},
        {alive = {1, 6, 7, 11, 12}, target = 6},
        {alive = {0, 1, 2, 3, 7, 11}, target = 1},
        {alive = {0, 2, 3, 4, 6, 7, 9, 10, 11, 12}, target = 2},
        {alive = {0, 7, 11, 12}, target = 12},
        {alive = {0, 1, 3, 7, 10, 11}, target = 1},
        {alive = {0, 3, 7, 10, 11}, target = 3},
        {alive = {0, 1, 12}, target = 1},
        {alive = {0, 1, 2, 7, 11, 12}, target = 1},
        {alive = {0, 2, 7, 11, 12}, target = 2},
        {alive = {0, 2, 3, 9, 10, 11}, target = 2},
        {alive = {0, 3, 9, 10, 11}, target = 3},
        {alive = {0, 10, 11}, target = 10},
        {alive = {0, 1, 2, 3, 4, 11, 12}, target = 12},
        {alive = {0, 2, 3, 11, 12}, target = 2},
        {alive = {0, 1, 2, 4, 6, 7, 11}, target = 11},
        {alive = {0, 1, 4, 9, 10, 11}, target = 1},
        {alive = {0, 4, 9, 10, 11}, target = 4},
        {alive = {1, 12}, target = 12},
        {alive = {0, 1, 4, 10, 11, 12}, target = 1},
        {alive = {0, 1, 3, 4, 10, 11, 12}, target = 12},
        {alive = {0, 1, 3, 4, 7, 11, 12}, target = 12},
        {alive = {0, 3, 11, 12}, target = 12},
        {alive = {0, 1, 2, 4, 11, 12}, target = 1},
        {alive = {0, 1, 3, 6, 7, 11}, target = 1},
        {alive = {0, 3, 6, 7, 11}, target = 3},
        {alive = {0, 2, 3, 7, 9, 10, 11}, target = 11},
        {alive = {0, 3, 10, 11}, target = 11},
        {alive = {0, 2, 3, 6, 9, 10, 11, 12}, target = 12},
        {alive = {0, 3, 4, 6, 7, 9, 10, 11, 12}, target = 7},
        {alive = {0, 4, 6, 7, 11}, target = 4},
        {alive = {0, 7, 11}, target = 7},
        {alive = {0, 1, 3, 9, 11, 12}, target = 1},
        {alive = {0, 1, 7, 11}, target = 11},
        {alive = {0, 1, 2, 7}, target = 7},
        {alive = {0, 1, 2, 4, 7, 11, 12}, target = 12},
        {alive = {0, 3, 4, 11, 12}, target = 3},
        {alive = {0, 1, 3, 4, 6, 7, 9, 10, 11, 12}, target = 1},
        {alive = {0, 4, 9, 10, 11, 12}, target = 4},
        {alive = {0, 9, 10, 11, 12}, target = 9},
        {alive = {0, 1, 10, 11, 12}, target = 1},
        {alive = {1, 2, 3, 4, 7, 9, 10, 11, 12}, target = 7},
        {alive = {1, 3, 4, 7, 9, 10, 11, 12}, target = 12},
        {alive = {1, 3, 4, 11, 12}, target = 3},
        {alive = {0, 1, 3, 12}, target = 12},
        {alive = {0, 1, 2, 4, 10, 11}, target = 1},
        {alive = {0, 2, 3, 6, 7, 10, 11}, target = 11},
        {alive = {0, 3, 6, 7, 10, 11}, target = 3},
        {alive = {0, 1, 2, 3, 4, 6, 7, 10, 11, 12}, target = 1},
        {alive = {0, 2, 3, 4, 6, 7, 10, 11, 12}, target = 6},
        {alive = {0, 4, 10, 11, 12}, target = 4},
        {alive = {0, 10, 11, 12}, target = 12},
        {alive = {0, 1, 2, 11, 12}, target = 1},
        {alive = {0, 1, 2, 3, 6, 7, 10, 11}, target = 11},
        {alive = {0, 1, 3, 6, 7, 10, 11}, target = 11},
        {alive = {0, 4, 12}, target = 4},
        {alive = {0, 1, 10}, target = 1},
        {alive = {0, 1, 3, 4, 11, 12}, target = 1},
        {alive = {0, 1, 4, 11, 12}, target = 1},
        {alive = {1, 4, 9, 10}, target = 10},
        {alive = {0, 1, 4, 10, 11}, target = 1},
        {alive = {0, 1, 2, 4, 10, 11, 12}, target = 12},
        {alive = {0, 1, 2, 4, 7, 11}, target = 1},
        {alive = {0, 1, 3, 4, 9, 11, 12}, target = 12},
        {alive = {0, 1, 2, 3, 7, 10, 11}, target = 11},
        {alive = {0, 1, 2, 3, 4, 9, 10, 11, 12}, target = 4},
        {alive = {0, 1, 3, 4, 9, 11}, target = 1},
        {alive = {0, 2, 3, 7, 10, 11, 12}, target = 12},
        {alive = {0, 1, 4, 7, 11}, target = 1},
        {alive = {0, 1, 2, 4, 9, 10, 11, 12}, target = 12},
        {alive = {0, 1, 4, 12}, target = 12},
        {alive = {0, 1, 10, 11}, target = 11},
        {alive = {0, 1, 2, 4, 6, 7}, target = 1},
        {alive = {0, 1, 2, 12}, target = 12},
        {alive = {0, 1, 4, 6, 7}, target = 1},
        {alive = {0, 1, 3, 4, 7, 9, 10, 11, 12}, target = 7},
        {alive = {1, 10}, target = 10},
        {alive = {0, 1, 6, 7, 11}, target = 1},
        {alive = {1, 7}, target = 7},
        {alive = {0, 1, 9, 12}, target = 12},
    }
    
    local aliveMinions = {}
    
    for _, minion in pairs(field) do
        if (minion.HP > 0) and (not minion.shroud) then
            aliveMinions[minion.boardIndex] = true
        end
    end
    
    local numAliveMinions = 0
    
    for _ in pairs(aliveMinions) do
        numAliveMinions = numAliveMinions + 1
    end
    
    for _, pattern in pairs(patterns) do
        if table.getn(pattern.alive) == numAliveMinions then
            local match = true
            for minion, _ in pairs(aliveMinions) do
                local m = false
                for _, p in pairs(pattern.alive) do
                    if minion == p then
                        m = true
                    end
                end
                if m == false then
                    match = false
                end
            end
            
            if match then
                for _, minion in pairs(field) do
                    if minion.boardIndex == pattern.target then
                        return {minion}
                    end
                end
            end
        end
    end
    
    local priorityList = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

    for i = 1, 13 do
        for _, minion in pairs(field) do
            if (minion.boardIndex == priorityList[i]) and (minion.HP > 0) and (not minion.shroud) then
                return {minion}
            end
        end
    end
    
    return {}
end