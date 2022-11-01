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

-- simulates a cast-to-int operation from other languages
-- strips all decimals
-- positive numbers will be rounded down to whole number
-- negative numbers will be rounded up
local function castToInt(float)
    if float < 0 then
        return math.ceil(float)
    end
    return math.floor(float)
end

local field
local environmentEffect
local currentTurn

local wasResulted
local function boardStateDefeat()
    if wasResulted then return wasResulted end
    
    local anyEnemyAlive = false
    local anyAllyAlive = false
    
    for _, minion in pairs(field) do
        if (minion.HP > 0) then
            if minion.boardIndex < 5 then
                anyAllyAlive = true
            else
                anyEnemyAlive = true
            end
        end
    end
    
    if not anyAllyAlive then
        wasResulted = "enemy team"
        return "enemy team"
    end
    if not anyEnemyAlive then
        wasResulted = "your team"
        return "your team"
    end
end

local environmentEffectFollower

local function attackOrderSortFunc(a, b)
    -- your team attacks before enemy team
    if (a.boardIndex < 5) and (b.boardIndex > 4) then
        return true
    elseif (a.boardIndex > 4) and (b.boardIndex < 5) then
        return false
    end
    
    -- highest HP attacks first, if HP is tied then lowest board index                
    if a.HP == b.HP then
        return a.boardIndex < b.boardIndex
    end
    return a.HP > b.HP
end

local function getAttackOrder()
    -- Attack order for all units is determined by current health at the start of each round. 
    -- Your team attacks first from highest health to lowest health. If any units on your team start the round with the same health, they attack from 
    --
    -- [[This comment found to not be correct]]
    --" left to right (along the "W")."
    -- [[unsure yet what the actual order is. Perhaps back row first?]]
    -- [[equal health, position backright attacked before position front left]]
    --
    -- If any units on the enemy team have the same health, the front row goes first (left-to-right) followed by the back row.
    local attackOrder = {}
    for _, minion in pairs(field) do
        if minion.HP > 0 then
            table.insert(attackOrder, minion)
        end
    end
    
    table.sort(attackOrder, attackOrderSortFunc)
    return attackOrder
end

local function targetsSortFunc(a, b)
    return a.boardIndex < b.boardIndex
end

local function getTargets(follower, targetType, rngTargets, taunter)
    if taunter and (taunter.HP <= 0) then taunter = nil end
    local targets = {}
    if targetType == addon.Enums.TargetType.closest_enemy then
        local target = addon:getClosestEnemy(follower, field, taunter)
        if target then
            table.insert(targets, target)
        end
    elseif targetType == addon.Enums.TargetType.all_enemies then
        targets = addon:getAllEnemies(follower, field, taunter)
    elseif targetType == addon.Enums.TargetType.back_enemies then
        targets = addon:getBackEnemies(follower, field, taunter)
    elseif targetType == addon.Enums.TargetType.front_enemies then
        targets = addon:getFrontEnemies(follower, field, taunter)
    elseif targetType == addon.Enums.TargetType.cleave_enemies then
        targets = addon:getCleaveEnemies(follower, field, taunter)
    elseif targetType == addon.Enums.TargetType.line then
        targets = addon:getLineEnemies(follower, field, taunter)
    elseif targetType == addon.Enums.TargetType.cone then
        targets = addon:getConeEnemies(follower, field, taunter)
        return targets -- skip sorting for cone abilities - needs to hit closest target first                
    elseif targetType == addon.Enums.TargetType.furthest_enemy then
        local target = addon:getFurthestEnemy(follower, field, taunter)
        if target then
            table.insert(targets, target)
        end
    elseif targetType == addon.Enums.TargetType.pseudorandom_enemies_only then
        targets = addon:getPseudorandomRitualFervor(follower, field)
    elseif targetType == addon.Enums.TargetType.pseudorandom_followers_only then
        targets = addon:getPseudorandomMawswornStrength(follower, field)
    elseif targetType == addon.Enums.TargetType.pseudorandom_everything then
        targets = addon:getPseudorandomLashOut(follower, field)
    elseif targetType == addon.Enums.TargetType.random_enemy then
        if not rngTargets then if TLDRMissionsDebugging then print("Error: random_enemy detected, but rng not set") end return targets end
        for _, minion in pairs(field) do
            if (follower.boardIndex < 5) and (minion.boardIndex == rngTargets["followers_random_enemy"]) and (minion.HP > 0) then
                table.insert(targets, minion)
            elseif (follower.boardIndex > 4) and (minion.boardIndex == rngTargets["enemies_random_enemy"]) and (minion.HP > 0) then
                table.insert(targets, minion)
            end
        end
    elseif targetType == addon.Enums.TargetType.random_ally then
        if not rngTargets then if TLDRMissionsDebugging then print("Error: random_ally detected, but rng not set") end return targets end
        for _, minion in pairs(field) do
            if (follower.boardIndex < 5) and (minion.boardIndex == rngTargets["followers_random_ally"]) then
                table.insert(targets, minion)
            elseif (follower.boardIndex > 4) and (minion.boardIndex == rngTargets["enemies_random_ally"]) then
                table.insert(targets, minion)
            end
        end
    elseif targetType == addon.Enums.TargetType.self then
        table.insert(targets, follower)
    elseif targetType == addon.Enums.TargetType.all_allies then
        targets = addon:getAllAllies(follower, field)
    elseif targetType == addon.Enums.TargetType.closest_ally then
        table.insert(targets, addon:getClosestAlly(follower, field))
    elseif targetType == addon.Enums.TargetType.adjacent_allies then
        targets = addon:getAdjacentAllies(follower, field)
    elseif targetType == addon.Enums.TargetType.adjacent_allies_or_all_allies then
        targets = addon:getAdjacentAlliesOrAllAllies(follower, field)
    elseif targetType == addon.Enums.TargetType.other_allies then
        targets = addon:getOtherAllies(follower, field)
    elseif targetType == addon.Enums.TargetType.front_allies_only then
        targets = addon:getFrontAllies(follower, field)
    elseif targetType == addon.Enums.TargetType.back_allies_exclude_self then
        targets = addon:getBackAllies(follower, field)
        for k, v in pairs(targets) do
            if v.boardIndex == follower.boardIndex then
                table.remove(targets, k)
            end
        end
        -- if there are no back allies, it appears to take all the front allies instead
        if table.getn(targets) == 0 then
            targets = addon:getAllAllies(follower, field)
            for k, v in pairs(targets) do
                if v.boardIndex == follower.boardIndex then
                    table.remove(targets, k)
                end
            end
        end
    elseif targetType == addon.Enums.TargetType.nearby_ally_or_self then
        targets = addon:getNearbyAllyOrSelf(follower, field)
    else
        print("Error: target type not found: "..targetType)
    end
    
    table.sort(targets, targetsSortFunc)
    
    return targets
end

local buffID
local nextThornsID
local function registerBuff(source, target, effect)
    local existingBuff = source.buffs[effect.buffName..target.boardIndex]
    if existingBuff then
        if existingBuff.stacks < existingBuff.stackLimit then
            if not existingBuff.durations then
                existingBuff.durations = {}
            end
            table.insert(existingBuff.durations, effect.duration)
            existingBuff.stacks = existingBuff.stacks + 1
            if TLDRMissionsDebugging then print(effect.buffName.. " gained an additional stack on "..target.name) end
            return
        else
            existingBuff.duration = effect.duration
            if TLDRMissionsDebugging then print(effect.buffName.." was refreshed on "..target.name) end
            return
        end
    else
        source.buffs[effect.buffName..target.boardIndex] = {
            ["target"] = target,
            duration = effect.duration,
            stacks = 1,
            stackLimit = effect.stackLimit or 1,
            damageTargetHPPercent = effect.damageTargetHPPercent,
            healTargetHPPercent = effect.healTargetHPPercent,
            event = effect.event,
            name = effect.buffName,
            removeAfterDeath = effect.removeAfterDeath,
            ID = buffID,
            type = effect.type,
            makeImmuneMathErrors = effect.makeImmuneMathErrors,
        }
        buffID = buffID + 1
    end
    
    local buff = source.buffs[effect.buffName..target.boardIndex]
    
    if effect.changeDamageDealtPercent then
        buff.changeDamageDealtPercent = effect.changeDamageDealtPercent
        buff.dontRound = effect.dontRound
    elseif effect.changeDamageDealtUsingAttack then
        buff.changeDamageDealtRaw = addon:multiplyPercentageWithErrors(source.baseAttack, effect.changeDamageDealtUsingAttack, {buff.name})
        if effect.roundAfter then
            buff.changeDamageDealtRaw = math.floor(buff.changeDamageDealtRaw)
        end
    elseif effect.changeDamageTakenPercent then
        buff.roundFirst = effect.roundFirst
        buff.changeDamageTakenPercent = effect.changeDamageTakenPercent
    elseif effect.changeDamageTakenUsingAttack then
        buff.changeDamageTakenRaw = addon:multiplyPercentageWithErrors(source.baseAttack, effect.changeDamageTakenUsingAttack, {buff.name})
    elseif effect.changeMaxHPPercent then
        local maxHPChangeAmount = castToInt((target.maxHP * effect.changeMaxHPPercent)/100)
        target.maxHP = target.maxHP + maxHPChangeAmount
        if maxHPChangeAmount > 0 then
            target.HP = target.HP + maxHPChangeAmount
        end
        if target.HP > target.maxHP then
            target.HP = target.maxHP
        end
        buff.onUnregister = function()
            target.maxHP = target.maxHP - maxHPChangeAmount
            if target.HP > target.maxHP then
                target.HP = target.maxHP
            end
        end
    elseif effect.changeMaxHPUsingAttack then
        local maxHPChangeAmount = castToInt((source.baseAttack * effect.changeMaxHPUsingAttack)/100)
        target.maxHP = target.maxHP + maxHPChangeAmount
        if maxHPChangeAmount > 0 then
            target.HP = target.HP + maxHPChangeAmount
        end
        if target.HP > target.maxHP then
            target.HP = target.maxHP
        end
        buff.onUnregister = function()
            target.maxHP = target.maxHP - maxHPChangeAmount
            if target.HP > target.maxHP then
                target.HP = target.maxHP
            end
        end
    
    elseif effect.shroud then
        if not target.shroud then
            target.shroud = 1
        else
            target.shroud = target.shroud + 1
        end
        buff.onUnregister = function()
            if not target.shroud then return end
            target.shroud = target.shroud - 1
            if target.shroud < 1 then
                target.shroud = nil
            end
        end
    elseif effect.attackPercent then
        buff.source = source
        buff.attackPercent = effect.attackPercent
    elseif effect.damageTargetHPPercent then
        buff.source = source
        buff.damageTargetHPPercent = effect.damageTargetHPPercent
    elseif effect.healTargetHPPercent then
        buff.source = source
        buff.healTargetHPPercent = effect.healTargetHPPercent
    elseif effect.thorns then
        buff.source = source
        local thornsDetail = {
            ["ID"] = nextThornsID,
            ["damage"] = effect.thorns,
            ["source"] = source.boardIndex,
            ["removeAfterDeath"] = effect.removeAfterDeath,
        }
        table.insert(target.thorns, thornsDetail)
        local id = nextThornsID
        buff.onUnregister = function()
            for k, v in pairs(target.thorns) do
                if v.ID == id then
                    target.thorns[k] = nil
                    break
                end
            end
        end
        nextThornsID = nextThornsID + 1
    elseif effect.taunt then
        -- from the missions I've observed, taunt only seems to affect autoattack
        if target.hasTaunt then
            target.hasTaunt.onUnregister()
        end
        buff.source = source
        target.hasTaunt = buff
        buff.onUnregister = function()
             if target.hasTaunt == buff then
                target.hasTaunt = nil
            end
        end
    elseif effect.healPercent then
        buff.source = source
        buff.healPercent = effect.healPercent
    else
        if TLDRMissionsDebugging then print("Error: buff effect not found for "..buff.name) end
    end
    
    if existingBuff then
        local o = existingBuff.onUnregister
        buff.onUnregister = function()
            o()
            o()
        end
    end
    
    if TLDRMissionsDebugging then print(source.name.."["..source.boardIndex.."]".." applies "..effect.buffName.." to "..target.name.."["..target.boardIndex.."]") end
end

local roundingErrorSpells = {
    dealt = {
        ["Acidic Spray"] = true,
        ["Podtender"] = true,
        ["Deceptive Practice"] = true,
        ["Shield Bash"] = true,
        ["Combat Meditation"] = true,
    },
    taken = {
        ["Shield of Tomorrow (Main)"] = true,
        ["Shield of Tomorrow (Alt)"] = true,
        ["Resilient Plumage"] = true,
    },
}

local function calculateDamage(attacker, defender, attackPercent, targetHPPercent)
    if not targetHPPercent then targetHPPercent = 0 end
    
    local changeDamageTakenRaw = {amount = 0}
    local changeDamageDealtRaw = {amount = 0}
    local changeDamageTakenPercent = {amount = 100, buffs = {}}
    local changeDamageDealtPercent = {amount = 100}
    
    local roundingErrorsDealt = 0
    --local roundingErrorsTaken = 0
    
    for _, minion in pairs(field) do
        for _, buff in pairs(minion.buffs) do
            if buff.target == attacker then
                if buff.changeDamageDealtPercent and ((not buff.alternateTurns) or (buff.activeThisTurn)) then
                    --if buff.immuneMathErrors then
                    --    changeDamageDealtPercent.immuneMathErrors = true
                    --end
                    changeDamageDealtPercent.amount = changeDamageDealtPercent.amount + buff.changeDamageDealtPercent
                    changeDamageDealtPercent.changed = true
                    if not changeDamageDealtPercent.buffNames then
                        changeDamageDealtPercent.buffNames = {}
                    end
                    if buff.dontRound then changeDamageDealtPercent.dontRound = buff.dontRound end
                    changeDamageDealtPercent.buffNames[buff.ID] = buff.name
                    if roundingErrorSpells.dealt[buff.name] then
                        roundingErrorsDealt = roundingErrorsDealt + 1
                    end
                elseif buff.changeDamageDealtRaw then
                    --if buff.immuneMathErrors then
                    --    changeDamageDealtRaw.immuneMathErrors = true
                    --end
                    changeDamageDealtRaw.amount = changeDamageDealtRaw.amount + buff.changeDamageDealtRaw
                end
            end
            -- this is not an elseif because the attacker can be the defender. Anima Leech can be a self-attack
            if buff.target == defender then
                if buff.changeDamageTakenPercent then
                    if buff.immuneMathErrors then
                        changeDamageTakenPercent.immuneMathErrors = true
                    end
                    changeDamageTakenPercent.amount = changeDamageTakenPercent.amount + buff.changeDamageTakenPercent
                    changeDamageTakenPercent.changed = true
                    if not changeDamageTakenPercent.buffNames then
                        changeDamageTakenPercent.buffNames = {}
                    end
                    if buff.roundFirst then changeDamageTakenPercent.roundFirst = buff.roundFirst end
                    changeDamageTakenPercent.buffNames[buff.ID] = buff.name
                    --if roundingErrorSpells.taken[buff.name] then
                    --    roundingErrorsTaken = roundingErrorsTaken + 1
                    --end
                elseif buff.changeDamageTakenRaw then
                    --if buff.immuneMathErrors then
                    --    changeDamageTakenRaw.immuneMathErrors = true
                    --end
                    changeDamageTakenRaw.amount = changeDamageTakenRaw.amount + buff.changeDamageTakenRaw
                end
            end
        end
    end
    
    if environmentEffect then
        for _, buff in pairs(environmentEffectFollower.buffs) do
            if buff.target == attacker then
                if buff.changeDamageDealtPercent and ((not buff.alternateTurns) or (buff.activeThisTurn)) then 
                    changeDamageDealtPercent.amount = changeDamageDealtPercent.amount + buff.changeDamageDealtPercent
                    changeDamageDealtPercent.changed = true
                    if not changeDamageDealtPercent.buffNames then
                        changeDamageDealtPercent.buffNames = {}
                    end
                    changeDamageDealtPercent.buffNames[buff.ID] = buff.name
                    if roundingErrorSpells.dealt[buff.name] then
                        roundingErrorsDealt = roundingErrorsDealt + 1
                    end
                elseif buff.changeDamageDealtRaw then
                    changeDamageDealtRaw.amount = changeDamageDealtRaw.amount + buff.changeDamageDealtRaw
                end
            end
            if buff.target == defender then
                if buff.changeDamageTakenPercent then
                    changeDamageTakenPercent.amount = changeDamageTakenPercent.amount + buff.changeDamageTakenPercent
                    changeDamageTakenPercent.changed = true
                    if not changeDamageTakenPercent.buffNames then
                        changeDamageTakenPercent.buffNames = {}
                    end
                    if buff.roundFirst then changeDamageTakenPercent.roundFirst = buff.roundFirst end
                    changeDamageTakenPercent.buffNames[buff.ID] = buff.name
                    --if roundingErrorSpells.taken[buff.name] then
                    --    roundingErrorsTaken = roundingErrorsTaken + 1
                    --end
                elseif buff.changeDamageTakenRaw then
                    changeDamageTakenRaw.amount = changeDamageTakenRaw.amount + buff.changeDamageTakenRaw
                end
            end
        end
    end
    
    --if roundingErrorsTaken > 1 then
    --    changeDamageTakenRaw.amount = changeDamageTakenRaw.amount - 0.01
    --end
    
    if roundingErrorsDealt > 1 then
        changeDamageDealtRaw.amount = changeDamageDealtRaw.amount - 0.01
    end
    
    local damage = attacker.baseAttack

    if attackPercent > 0 then
        damage = castToInt(((attacker.baseAttack * attackPercent)/100))
    end
    if targetHPPercent > 0 then
        damage = castToInt((defender.maxHP * targetHPPercent)/100)
    end
    
    changeDamageDealtRaw.action = function()
        --if changeDamageDealtRaw.immuneMathErrors then
        --    damage = damage + changeDamageDealtRaw.amount
        --else
            damage = addon:additionWithErrors(damage, changeDamageDealtRaw.amount)
        --end
    end
    
    changeDamageDealtPercent.action = function()
        if changeDamageDealtPercent.changed then
            -- arrange buffs by buff ID
            local newBuffNames = {}
            local buffNamesIndexes = {}
            for k, v in pairs(changeDamageDealtPercent.buffNames) do
                table.insert(buffNamesIndexes, k)
            end
            table.sort(buffNamesIndexes, function(a, b)
                return a<b
            end)
            for k, v in ipairs(buffNamesIndexes) do
                table.insert(newBuffNames, changeDamageDealtPercent.buffNames[v])
            end
            changeDamageDealtPercent.buffNames = newBuffNames
            
            --if not changeDamageDealtPercent.immuneMathErrors then
                damage = addon:multiplyPercentageWithErrors(damage, changeDamageDealtPercent.amount, changeDamageDealtPercent.buffNames)
            --else
            --    damage = (damage * changeDamageDealtPercent.amount)/100
            --end
            
            if not changeDamageDealtPercent.dontRound then
                damage = castToInt(damage)
            end
        end
    end
    
    changeDamageTakenRaw.action = function()
        --if changeDamageTakenRaw.immuneMathErrors then
        --    damage = damage + changeDamageTakenRaw.amount
        --else
            damage = addon:additionWithErrors(damage, changeDamageTakenRaw.amount)
        --end
    end
    
    changeDamageTakenPercent.action = function() 
        if changeDamageTakenPercent.changed then
            if changeDamageTakenPercent.roundFirst then
                damage = castToInt(damage)
            end
            
            -- arrange buffs by buff ID
            local newBuffNames = {}
            local buffNamesIndexes = {}
            for k, v in pairs(changeDamageTakenPercent.buffNames) do
                table.insert(buffNamesIndexes, k)
            end
            table.sort(buffNamesIndexes, function(a, b)
                return a<b
            end)
            for k, v in ipairs(buffNamesIndexes) do
                table.insert(newBuffNames, changeDamageTakenPercent.buffNames[v])
            end
            changeDamageTakenPercent.buffNames = newBuffNames
            
            if changeDamageTakenPercent.immuneMathErrors then
                damage = (damage * changeDamageTakenPercent.amount)/100
            else
                damage = addon:multiplyPercentageWithErrors(damage, changeDamageTakenPercent.amount, changeDamageTakenPercent.buffNames)
            end
            damage = castToInt(damage)
        end
    end
    
    local actions = {changeDamageDealtRaw, changeDamageDealtPercent, changeDamageTakenRaw, changeDamageTakenPercent}
    
    for _, action in ipairs(actions) do
        action.action()
    end
    
    damage = castToInt(damage)
    local d = damage
    
    if damage < 0 then damage = 0 end

    return damage, d -- thorns can be less than zero and actually heals the other minion lolwtfbbq
end

local unregisterBuff
local checkDeath

local thornsKillingBlow = false

local function processBuff(follower, buff)
    if (not thornsKillingBlow) and boardStateDefeat() then return end
    
    local target = buff.target
    
    if target.HP > 0 then
        if buff.damageTargetHPPercent then
            local damage = calculateDamage(buff.source, target, 0, buff.damageTargetHPPercent)
            target.HP = target.HP - damage
            if TLDRMissionsDebugging then print(buff.name.." deals "..damage.." to "..target.name.." ["..target.boardIndex.."]") end
            checkDeath(target)
                
        elseif buff.healTargetHPPercent then
            local healing = castToInt((target.maxHP * buff.healTargetHPPercent)/100)
            target.HP = target.HP + healing
            if target.HP > target.maxHP then
                target.HP = target.maxHP
            end
            if TLDRMissionsDebugging then print(buff.name.." heals "..target.name.." for "..healing) end
                
        elseif buff.healPercent then
            local healing = castToInt((follower.baseAttack * buff.healPercent)/100)
            target.HP = target.HP + healing
            if target.HP > target.maxHP then
                target.HP = target.maxHP
            end
            if TLDRMissionsDebugging then print(buff.name.." heals "..target.name.." for "..healing) end
                
        elseif buff.attackPercent then
            local stackNum = 0
            local stackUpper = buff.stacks
            if not stackUpper then stackUpper = 1 end
                
            while (stackNum < buff.stacks) and (target.HP > 0) do
                local damage = calculateDamage(buff.source, target, buff.attackPercent)
                target.HP = target.HP - damage
                if TLDRMissionsDebugging then print(buff.name.." deals "..damage.." to "..target.name.." ["..target.boardIndex.."]") end
                checkDeath(target)
                stackNum = stackNum + 1
            end
        elseif buff.alternateTurns then
            buff.activeThisTurn = not buff.activeThisTurn
        else
            if TLDRMissionsDebugging then print("Error: buff effect not found for "..buff.name) end
        end
    end
end

unregisterBuff = function(follower, buff)
    if buff.type == addon.Enums.spellType.passive then return end -- special handling for passives elsewhere
    if buff.onUnregister then
        buff.onUnregister()
    end
    follower.buffs[buff.name..buff.target.boardIndex] = nil
    if (not buff.target.isDead) then
        if buff.event and (buff.event == "onRemove") then
            processBuff(follower, buff)
        end
    end
    if (not buff.target.isDead) then
        if TLDRMissionsDebugging then print(buff.name.." faded from "..buff.target.name.." ["..buff.target.boardIndex.."]") end
    end
end

checkDeath = function(target, useThornsExemption)
    if (target.HP > 0) or (target.isDead) then return end
    target.isDead = true
    for _, buff in pairs(target.buffs) do
        if buff.removeAfterDeath then
            unregisterBuff(target, buff)
        end
    end
    if (not useThornsExemption) and target.unregisterPassive then
        target.unregisterPassive()
    end
    if TLDRMissionsDebugging then print(target.name.." died.") end
end

local function checkThorns(source, target)
    local wasDefeat = boardStateDefeat()
    
    if source.boardIndex > 12 then return end -- no thorns against the environment effect
    for _, thorns in pairs(target.thorns) do                                    
        local originBoardIndex = thorns.source
        local origin
        for _, minion in pairs(field) do
            if minion.boardIndex == originBoardIndex then
                origin = minion
                break
            end
        end
        
        if (origin.HP <= 0) and (thorns.removeAfterDeath) then return end
        
        --
        -- does it use the baseattack of the minion that cast the thorns, or the minion that has the buff?
        -- Invasive Lasher[10] applied Drust Thorns to Ingra Krazic
        -- Ingra Krazic[6] cast Drust Thorns at Kyrian Phalanx[1][1152HP] for 141  damage.
        -- Baseattack of the lasher was 176, while the baseattack of ingra was 141
        --
        local _, damage = calculateDamage(target, source, thorns.damage)
        
        source.HP = source.HP - damage
        if source.HP > source.maxHP then
            source.HP = source.maxHP
        end
        if TLDRMissionsDebugging then print(origin.name.."["..origin.boardIndex.."]["..origin.HP.."] thorns deals "..damage.." damage to "..source.name.."["..source.boardIndex.."]["..source.HP.."HP]") end
    end
    
    if (not wasDefeat) and boardStateDefeat() then
        -- unusual case: if thorns gets the killing blow, the combatlog doesn't completely register the match is over and finishes out the round, letting buffs finish and their onRemove functions tick
        thornsKillingBlow = true
    end
end

local function processSpell(follower, spell, effectIndex, rngTargets, hasTaunt, overrideTarget)
    local effect = spell.effects
    if spell.effects[effectIndex] then
        effect = spell.effects[effectIndex]
    end
    
    local targets = overrideTarget or getTargets(follower, effect.target, rngTargets, (hasTaunt and hasTaunt.source))
    
    if table.getn(targets) == 0 then
        return false
    end
    
    if effect.type == addon.Enums.spellType.attack then
        for _, target in ipairs(targets) do
            if target.HP > 0 then
                local damage = 0
                
                if effect.attackPercent then
                    damage = calculateDamage(follower, target, effect.attackPercent, nil)
                    if damage <= 0 then
                        for _, minion in pairs(field) do
                            for _, buff in pairs(minion.buffs) do
                                if (buff.target == target) and buff.makeImmuneMathErrors then
                                    buff.immuneMathErrors = true
                                end
                            end
                        end
                    end
                end
                
                if effect.damageTargetHPPercent then
                    damage = calculateDamage(follower, target, 0, effect.damageTargetHPPercent)
                end
                
                target.HP = target.HP - damage
                if TLDRMissionsDebugging then print(follower.name.."["..follower.boardIndex.."]["..follower.HP.."HP] attacks "..target.name.."["..target.boardIndex.."]["..target.HP.."HP] for "..damage) end
                
                if not effect.ignoreThorns then
                    checkThorns(follower, target)
                    checkDeath(follower, true)
                end                          
                
                checkDeath(target)
            end
        end
    elseif effect.type == addon.Enums.spellType.heal then
        local healing = 0
        
        if effect.healPercent then
            healing = castToInt((follower.baseAttack * effect.healPercent)/100)
        end
        
        -- for spells that do AOE healing, if a single target is valid, then the entire heal goes off. it puts entries in the log for healing targets already full health even though nothing changes
        if effect.skipIfFull then
            local hasValidTarget = false
            for _, target in ipairs(targets) do
                if target.HP < target.maxHP then
                    hasValidTarget = true
                    break
                end
            end
            
            if not hasValidTarget then
                spell.onCooldown = 0
                return true
            end
        end
        
        for _, target in ipairs(targets) do
            if target.HP > 0 then
                if effect.healTargetHPPercent then
                    healing = castToInt((target.maxHP * effect.healTargetHPPercent)/100)
                end
                
                target.HP = target.HP + healing
                if target.HP > target.maxHP then
                    target.HP = target.maxHP
                end
                if TLDRMissionsDebugging then print(follower.name.."["..follower.boardIndex.."]["..follower.HP.."HP] heals "..target.name.."["..target.boardIndex.."]["..target.HP.."HP] for "..healing) end
            end
        end                                                                                                                                                           
    elseif effect.type == addon.Enums.spellType.buff then
        if effect.skipIfFull then
            local hasValidTarget = false
            for _, target in ipairs(targets) do
                if target.HP < target.maxHP then
                    hasValidTarget = true
                    break
                end
            end
            
            if not hasValidTarget then
                spell.onCooldown = 0
                return true
            end
        end
        
        for _, target in ipairs(targets) do
            if target.HP > 0 then
                registerBuff(follower, target, effect)
            end
        end
    end
    
    return true
end

local function processSpells(follower, spells, rngTargets)
    local targets = {}
    for i in ipairs(spells.effects) do
        targets[i] = getTargets(follower, spells.effects[i].target, rngTargets, (spells.effects[i].affectedByTaunt and follower.hasTaunt and follower.hasTaunt.source) or nil)
    end
    
    local result = false
    for i in ipairs(spells.effects) do
        if (follower.HP > 0) or ((i > 1) and spells.effects[1].continueIfCasterDies) then
            if spells.effects[i].cancelIfNoTargets and (table.getn(targets[i]) == 0) then
                spells.onCooldown = 0
                return
            end
            if spells.effects[i].reacquireTargets then
                targets[i] = getTargets(follower, spells.effects[i].target, rngTargets, (spells.effects[i].affectedByTaunt and follower.hasTaunt and follower.hasTaunt.source) or nil)
            end 
            if processSpell(follower, spells, i, rngTargets, nil, targets[i]) then
                result = true
            end
            if spells.effects[i].stopIfTargetDies then
                if targets[i][1] and (targets[i][1].HP <= 0) then
                    break
                end
            end
        end
    end
    return result
end

local function processEnvironmentEffect(rngTargets)
    if environmentEffect.effects.type == addon.Enums.spellType.buff then
        for _, buff in pairs(environmentEffectFollower.buffs) do
            if buff.target.HP > 0 then
                if buff.damageTargetHPPercent or buff.healTargetHPPercent or buff.healPercent or buff.attackPercent or buff.alternateTurns then
                    processBuff(environmentEffectFollower, buff)
                end
                buff.duration = buff.duration - 1
                if buff.durations then
                    for i, duration in ipairs(buff.durations) do
                        buff.durations[i] = duration - 1
                    end
                    local r = false
                    repeat
                        r = false
                        for i, duration in ipairs(buff.durations) do
                            if duration == 0 then
                                r = true
                                table.remove(buff.durations, i)
                                if buff.stacks and buff.stacks > 1 then
                                    buff.stacks = buff.stacks - 1
                                    local targetName = environmentEffect.name
                                    if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..buff.target.name.."["..buff.target.boardIndex.."]") end
                                end
                                break
                            end
                        end
                    until not r
                end
                if buff.duration == 0 then
                    if buff.stacks and buff.stacks > 1 then
                        buff.duration = table.remove(buff.durations, 1)
                        buff.stacks = buff.stacks - 1
                        local targetName = environmentEffect.name
                        if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..buff.target.name.."["..buff.target.boardIndex.."]") end
                    else
                        unregisterBuff(environmentEffectFollower, buff)
                    end
                end
            end
        end
    end

    -- if the target is "random enemy" then take the worst case scenario: the lowest health minion
    local target
    if environmentEffect.effects.target == "random_enemy" then
        local lowestHealth = 99999
        local lowestHealthID
        for _, follower in pairs(field) do
            if (follower.boardIndex < 5) and (follower.HP > 0) then
                if follower.HP < lowestHealth then
                    lowestHealth = follower.HP
                    lowestHealthID = follower
                end
            end
        end
        target = {lowestHealthID}
    else
        target = getTargets(environmentEffectFollower, environmentEffect.effects.target, rngTargets)
    end
    
    if environmentEffect.onCooldown > 0 then
        environmentEffect.onCooldown = environmentEffect.onCooldown - 1
        return
    end
    environmentEffect.onCooldown = environmentEffect.cooldown or 0
    
    if environmentEffect.effects.damageTargetHPPercent then
        for _, t in pairs(target) do
            local damage = calculateDamage(environmentEffectFollower, t, 0, environmentEffect.effects.damageTargetHPPercent)
            t.HP = t.HP - damage
            if TLDRMissionsDebugging then print(environmentEffect.name.." [Environment Effect] deals "..damage.." to "..t.name.." ["..t.boardIndex.."]["..t.HP.."]") end
            checkDeath(t)
        end
    elseif environmentEffect.effects.type == addon.Enums.spellType.buff then
        for _, t in pairs(target) do
            registerBuff(environmentEffectFollower, t, environmentEffect.effects)
        end
    elseif environmentEffect.effects.healPercent then
        for _, minion in pairs(target) do
            local healing = environmentEffect.effects.healPercent
            minion.HP = minion.HP + healing
            if minion.HP > minion.maxHP then
                minion.HP = minion.maxHP
            end
            if TLDRMissionsDebugging then print(environmentEffect.name.." heals "..minion.name.." for "..healing) end
        end
    elseif environmentEffect.effects.attackPercent then
        if environmentEffect.effects.doOnce then
            if environmentEffect.alreadyProcessed then
                return
            end
            environmentEffect.alreadyProcessed = true
        end
        
        for _, minion in pairs(target) do
            local damage = calculateDamage(environmentEffectFollower, minion, environmentEffect.effects.attackPercent)
            
            minion.HP = minion.HP - damage
            if TLDRMissionsDebugging then print(environmentEffect.name.." attacks "..minion.name.."["..minion.boardIndex.."]["..minion.HP.."HP] for "..damage) end

            checkDeath(minion)
        end
    else
        DevTools_Dump("Error: environment effect incomplete: "..environmentEffect.autoCombatSpellInfo.autoCombatSpellID)
    end
end

local function nextTurn(rngTargets)
    if TLDRMissionsDebugging then 
        print(" ")
        print("Turn: "..currentTurn)
        print(" ")
    end
    
    currentTurn = currentTurn + 1
    
    if rngTargets and TLDRMissionsDebugging then
        print(rngTargets)
    end
           
    -- attack phase
    local attackOrder = getAttackOrder()
    
    -- save minions that were dead at the start of the turn for use later
    local deadMinions = {}
    for _, minion in pairs(field) do
        local found = false
        for _, minion2 in pairs(attackOrder) do
            if minion == minion2 then
                found = true
                break
            end
        end
        if not found then
            table.insert(deadMinions, minion)
        end
    end
    
    local processedDeadFollowers = false
    
    for _, minion in ipairs(attackOrder) do
        -- reduce buff durations for dead followers that have persisted buffs
        -- this happens between the turn of the last follower and the first enemy minion
        if (not processedDeadFollowers) and (minion.boardIndex > 4) then
            processedDeadFollowers = true
            for _, minion in pairs(deadMinions) do
                if minion.boardIndex < 5 then
                    local buffIDs = {}
                    local buffIndexes = {}
                    for _, buff in pairs(minion.buffs) do
                        table.insert(buffIDs, buff.ID)
                        buffIndexes[buff.ID] = buff
                    end
                    table.sort(buffIDs, function(a, b)
                        return a < b
                    end)

                    for _, id in ipairs(buffIDs) do
                        local buff = buffIndexes[id]
                        if buff.event == "beforeAttack" then
                            processBuff(minion, buff)
                        end
                        buff.duration = buff.duration - 1
                        if buff.durations then
                            for i, duration in ipairs(buff.durations) do
                                buff.durations[i] = duration - 1
                            end
                            local r
                            repeat
                                r = false
                                for i, duration in ipairs(buff.durations) do
                                    if duration == 0 then
                                        r = true
                                        table.remove(buff.durations, i)
                                        if buff.stacks and buff.stacks > 1 then
                                            buff.stacks = buff.stacks - 1
                                            if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..environmentEffectFollower.name) end
                                        end
                                        break
                                    end
                                end
                            until not r
                        end
                        if buff.duration == 0 then
                            if buff.stacks and buff.stacks > 1 then
                                buff.duration = table.remove(buff.durations, 1)
                                buff.stacks = buff.stacks - 1
                                if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..minion.name) end
                            else
                                unregisterBuff(minion, buff)
                            end
                        end
                    end
                end
            end
        end
    
        -- beforeAttack events
        for _, buff in pairs(minion.buffs) do
            if buff.event == "beforeAttack" then
                processBuff(minion, buff)
            end
        end
        
        -- reduce buff durations
        for _, buff in pairs(minion.buffs) do
            buff.duration = buff.duration - 1
            if buff.durations then
                for i, duration in ipairs(buff.durations) do
                    buff.durations[i] = duration - 1
                end
                local r
                repeat
                    r = false
                    for i, duration in ipairs(buff.durations) do
                        if duration == 0 then
                            r = true
                            table.remove(buff.durations, i)
                            if buff.stacks and buff.stacks > 1 then
                                buff.stacks = buff.stacks - 1
                                if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..environmentEffectFollower.name) end
                            end
                            break
                        end
                    end
                until not r
            end
            if buff.duration == 0 then
                if buff.stacks and buff.stacks > 1 then
                    buff.duration = table.remove(buff.durations, 1)
                    buff.stacks = buff.stacks - 1
                    if TLDRMissionsDebugging then print(buff.name.." lost a stack on "..minion.name) end
                else
                    unregisterBuff(minion, buff)
                end
            end
        end
    
        -- autoattack first
        if minion.autoAttack.onCooldown and minion.autoAttack.onCooldown > 0 then
            minion.autoAttack.onCooldown = minion.autoAttack.onCooldown - 1
        else
            minion.autoAttack.onCooldown = minion.autoAttack.cooldown
            if not boardStateDefeat() and (minion.HP > 0) then
                processSpell(minion, minion.autoAttack, nil, rngTargets, minion.hasTaunt)
            end
        end
        
        if thornsKillingBlow then break end
        if boardStateDefeat() then return end
        
        -- then spells
        for _, spell in ipairs(minion.spells) do
            if boardStateDefeat() then return end
            
            if minion.HP > 0 then
            
                if spell.onCooldown and spell.onCooldown > 0 then
                    spell.onCooldown = spell.onCooldown - 1
                else
                    if spell.effects.overrideCooldown then -- for spellID 205 only seems to cast once, ignoring its cooldown
                        spell.onCooldown = spell.effects.overrideCooldown
                    else
                        spell.onCooldown = spell.cooldown
                    end
                    if spell.effects[1] then
                        local result
                        result = processSpells(minion, spell, rngTargets)
                        if not result then
                            -- spell had no valid targets
                            spell.onCooldown = 0
                        end
                    else
                        local result = processSpell(minion, spell, nil, rngTargets, (spell.effects.affectedByTaunt and minion.hasTaunt or nil))
                        if not result then
                            spell.onCooldown = 0
                        end
                    end
                end
            
            end
        end
        
        if thornsKillingBlow then break end
        if boardStateDefeat() then return end
    end
    
    -- reduce buff durations for dead enemy minions that have persisted buffs
    for _, minion in pairs(deadMinions) do
        if minion.boardIndex > 4 then
            for _, buff in pairs(minion.buffs) do
                if buff.event == "beforeAttack" then
                    processBuff(minion, buff)
                end
                buff.duration = buff.duration - 1
                if buff.duration == 0 then
                    unregisterBuff(minion, buff)
                end
            end
        end
    end
    
    if environmentEffect then
        processEnvironmentEffect(rngTargets)
    end
    
    -- end turn events
    for _, minion in pairs(field) do
        for _, buff in pairs(minion.buffs) do
            if buff.event == "endTurn" then
                processBuff(minion, buff)
            end
        end
    end
end

local function registerPassive(follower, spell)
    for _, target in ipairs(getTargets(follower, spell.effects.target)) do
        local buff = {
                ["target"] = target,
                duration = 9999,
                stacks = 1,
                stackLimit = 1,
                name = spell.effects.buffName,
                source = follower,
                thorns = spell.effects.thorns,
                changeDamageDealtPercent = spell.effects.changeDamageDealtPercent,
                changeDamageTakenPercent = spell.effects.changeDamageTakenPercent,
                changeDamageDealtRaw = (( (spell.effects.changeDamageDealtUsingAttack or 0) /100) * (follower.baseAttack)),
                changeDamageTakenRaw = (( (spell.effects.changeDamageTakenUsingAttack or 0) /100) * (follower.baseAttack)),
                ID = buffID,
                type = addon.Enums.spellType.passive,
                removeAfterDeath = spell.effects.removeAfterDeath,
                roundFirst = spell.effects.roundFirst,
            }
        if spell.effects.removeAfterDeath == nil then buff.removeAfterDeath = true end
        if buff.changeDamageDealtRaw == 0 then buff.changeDamageDealtRaw = nil end
        if buff.changeDamageTakenRaw == 0 then buff.changeDamageTakenRaw = nil end
        buffID = buffID + 1
        
        follower.buffs[spell.effects.buffName..target.boardIndex] = buff
        
        if spell.effects.thorns then
            local thornsDetail = {
                ["ID"] = nextThornsID,
                ["damage"] = spell.effects.thorns,
                ["source"] = follower.boardIndex,
                ["removeAfterDeath"] = buff.removeAfterDeath,
            }
            table.insert(target.thorns, thornsDetail)
            local id = nextThornsID
            buff.onUnregister = function()
                for k, v in pairs(target.thorns) do
                    if v.ID == id then
                        target.thorns[k] = nil
                        break
                    end
                end
            end
            nextThornsID = nextThornsID + 1
        end
        
        if TLDRMissionsDebugging then print(target.name.." gained a passive: "..spell.effects.buffName) end
    end
    
    function follower.unregisterPassive()
        for _, target in ipairs(getTargets(follower, spell.effects.target)) do
            local buff = follower.buffs[spell.effects.buffName..target.boardIndex]
            if buff and (buff.removeAfterDeath) then
                if buff.onUnregister then
                    buff.onUnregister()
                end
                if TLDRMissionsDebugging then print(buff.name.." faded from "..target.name.." ["..target.boardIndex.."]") end
                follower.buffs[spell.effects.buffName..target.boardIndex] = nil
            end
        end
    end
end

local function setupPassives()
    for _, minion in pairs(field) do
        for _, spell in ipairs(minion.spells) do
            if not spell.effects then
                DevTools_Dump(spell)
                DevTools_Dump(missionID)
            end
            if spell.effects.type == addon.Enums.spellType.passive then
                if not spell.effects.bugged then
                    registerPassive(minion, spell)
                end
            end
        end
    end
end

local function registerSpellsStartOnCooldown()
    for _, minion in pairs(field) do
        for _, spell in ipairs(minion.spells) do
            if spell.effects.firstTurn then
                spell.onCooldown = spell.effects.firstTurn
            end
        end
    end
end

local function doSimulation(missionID, callback)
    currentTurn = 1
    wasResulted = nil
    environmentEffectFollower = nil
    
    if environmentEffect then
        environmentEffectFollower = {boardIndex = 13, name = environmentEffect.name, buffs = {}, baseAttack = 100, changeDamageDealtRaw = 0, changeDamageDealtPercent = 100, followerID = "environment",}
        if environmentEffect.effects.firstTurn then
            environmentEffect.onCooldown = environmentEffect.effects.firstTurn
        else
            environmentEffect.onCooldown = 0
        end
        
        if missionID == 2297 then
            environmentEffectFollower.baseAttack = 150
        end
    end

    buffID = 1
    nextThornsID = 1
    thornsKillingBlow = false
    
    local followerVictories = 0
    local enemyVictories = 0
    local turnLimitExceeded = 0
    
    local function turnRecursion()
        if enemyVictories > 0 then return end -- if a single combination loses then we don't need the rest to be simulated anymore. Comment this out for testing only.

        nextTurn()

        if boardStateDefeat() then
            print("Mission won by: "..boardStateDefeat())
            if boardStateDefeat() == "your team" then
                followerVictories = followerVictories + 1
            else
                enemyVictories = enemyVictories + 1
            end
        else
            turnRecursion()
        end
    end
    
    setupPassives()
    registerSpellsStartOnCooldown()
    turnRecursion()
    
    print("total combinations: "..(followerVictories + enemyVictories)..", your team wins: "..followerVictories..", enemies win: "..enemyVictories..", turn limits exceeded: "..turnLimitExceeded)
    local finalHealth = {}
    for _, minion in pairs(field) do
        if minion.boardIndex < 5 then
            finalHealth[minion.boardIndex] = minion.HP
        end
    end
    callback({["victories"] = followerVictories, ["defeats"] = enemyVictories, ["incompletes"] = turnLimitExceeded, ["finalHealth"] = finalHealth})
end

function addon:Simulate(frontLeftFollowerID, frontMiddleFollowerID, frontRightFollowerID, backLeftFollowerID, backRightFollowerID, missionID, callback)
    field = {}
    local enemies = C_Garrison.GetMissionDeploymentInfo(missionID).enemies
    -- enemies board index: 5 is front left, 8 is front right, 9 is back left, 12 is back right
    
    local enemyID = -1
    for _, enemy in pairs(enemies) do
        local minion = {}
        minion.followerID = enemyID
        enemyID = enemyID - 1
        minion.buffs = {}
        minion.HP = enemy.health
        minion.maxHP = enemy.maxHealth
        minion.thorns = {}
        minion.baseAttack = enemy.attack
        minion.boardIndex = enemy.boardIndex
        minion.name = enemy.name
    
        minion.spells = {}
        for i, spell in pairs(enemy.autoCombatSpells) do
            table.insert(minion.spells, {
                ["spellID"] = spell.autoCombatSpellID,
                ["cooldown"] = spell.cooldown,
                ["duration"] = spell.duration,
                ["onCooldown"] = false,
                ["effects"] = addon.spellsDB[spell.autoCombatSpellID],
            })
        end
        minion.autoAttack = {
            ["spellID"] = enemy.autoCombatAutoAttack.autoCombatSpellID,
            ["cooldown"] = enemy.autoCombatAutoAttack.cooldown,
            ["duration"] = enemy.autoCombatAutoAttack.duration,
            ["onCooldown"] = false,
            ["effects"] = addon.spellsDB[enemy.autoCombatAutoAttack.autoCombatSpellID],
        }
        table.insert(field, minion)
    end
    enemies = nil
    
    local teamLineup = {
        [0] = {["followerID"] = backLeftFollowerID, ["boardIndex"] = 0},
        [1] = {["followerID"] = backRightFollowerID, ["boardIndex"] = 1},
        [2] = {["followerID"] = frontLeftFollowerID, ["boardIndex"] = 2},
        [3] = {["followerID"] = frontMiddleFollowerID, ["boardIndex"] = 3},
        [4] = {["followerID"] = frontRightFollowerID, ["boardIndex"] = 4},
    }
    local team = {}
    for i, follower in pairs(teamLineup) do
        if (follower.followerID) then
            table.insert(team, follower)
        end
    end
    
    for _, follower in pairs(team) do
        if follower.followerID then
            local info = addon:C_Garrison_GetFollowerAutoCombatStats(follower.followerID)
            
            follower.buffs = {}
            if not info then DevTools_Dump("TLDRMissions: You're about to get an error here. If you left the simulator running while changing zones, thats probably why.") DevTools_Dump(follower.followerID) end
            follower.HP = info.currentHealth
            follower.maxHP = info.maxHealth
            follower.thorns = {}
            follower.baseAttack = info.attack
            local info = C_Garrison.GetFollowerInfo(follower.followerID)
            if not info then
                -- mission probably expired
                callback({["victories"] = 0, ["defeats"] = 0, ["incompletes"] = 1})
                return
            end
            follower.name = info.name
            follower.levelXP = info.levelXP
            follower.xp = info.xp
            if follower.levelXP == 0 then
                follower.levelXP = 1
                follower.xp = 0
            end
            
            local autoCombatSpells, autoCombatAutoAttack = C_Garrison.GetFollowerAutoCombatSpells(follower.followerID, C_Garrison.GetFollowerInfo(follower.followerID).level)
            follower.spells = {}
            for i, spell in pairs(autoCombatSpells) do
                table.insert(follower.spells, {
                    ["spellID"] = spell.autoCombatSpellID,
                    ["cooldown"] = spell.cooldown,
                    ["duration"] = spell.duration,
                    ["onCooldown"] = false,
                    ["effects"] = addon.spellsDB[spell.autoCombatSpellID],
                })
            end
            follower.autoAttack = {
                ["spellID"] = autoCombatAutoAttack.autoCombatSpellID,
                ["cooldown"] = autoCombatAutoAttack.cooldown,
                ["duration"] = autoCombatAutoAttack.duration,
                ["onCooldown"] = false,
                ["effects"] = addon.spellsDB[autoCombatAutoAttack.autoCombatSpellID],
            }
        end
        table.insert(field, follower)
    end
    
    local output = "Starting simulation for lineup: "
    for _, follower in pairs(team) do
        output = output..follower.boardIndex.." - "..follower.name.." - "..follower.HP.."HP; "
    end
    print(output)
    
    team, teamLineup = nil, nil
    
    environmentEffect = C_Garrison.GetAutoMissionEnvironmentEffect(missionID)
    if environmentEffect then
        environmentEffect.cooldown = environmentEffect.autoCombatSpellInfo.cooldown
        environmentEffect.effects = addon.spellsDB[environmentEffect.autoCombatSpellInfo.autoCombatSpellID]
        if not addon.spellsDB[environmentEffect.autoCombatSpellInfo.autoCombatSpellID] then
            DevTools_Dump(environmentEffect.autoCombatSpellInfo.autoCombatSpellID)
        end
    end
    
    doSimulation(missionID, function(results) 
        callback(results)
    end)
end

--/run TLDRMissions:SimulateFromLog(2319)
function addon:SimulateFromLog(missionID, callback)
    -- use a mission ID in the logs, recreate the followers/enemies
    
    local record = _G["CopyTable"](_G["TLDRMissionsLogging"][missionID])
    
    field = {}
    
    local enemies = record.enemies
    for i, enemy in pairs(enemies) do -- warning: i is not boardIndex
        enemy.buffs = {}
        enemy.thorns = {}
        enemy.name = enemy.name or tostring(enemy.followerID) 
        
        for i, spell in pairs(enemy.spells) do
            spell.onCooldown = false
            spell.effects = addon.spellsDB[spell.spellID]
        end
        enemy.autoAttack.onCooldown = false
        enemy.autoAttack.effects = addon.spellsDB[enemy.autoAttack.spellID]
        
        table.insert(field, enemy)
    end

    for i, follower in pairs(record.followers) do
        follower.buffs = {}
        follower.thorns = {}
        follower.name = follower.name or tostring(follower.followerID)
        
        for i, spell in pairs(follower.spells) do
            spell.onCooldown = false
            spell.effects = addon.spellsDB[spell.spellID]
        end
        follower.autoAttack.onCooldown = false
        follower.autoAttack.effects = addon.spellsDB[follower.autoAttack.spellID]
        table.insert(field, follower)
    end

    environmentEffect = record.environmentEffect
    
    if environmentEffect then
        environmentEffect.cooldown = environmentEffect.autoCombatSpellInfo.cooldown
        environmentEffect.effects = addon.spellsDB[environmentEffect.autoCombatSpellInfo.autoCombatSpellID]
        if not addon.spellsDB[environmentEffect.autoCombatSpellInfo.autoCombatSpellID] then
            DevTools_Dump(environmentEffect.autoCombatSpellInfo.autoCombatSpellID)
        end
    end

    doSimulation(missionID, function(results) if callback then callback(results) end end)
end
