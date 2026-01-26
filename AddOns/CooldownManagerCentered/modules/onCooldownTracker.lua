local _, ns = ...

local CooldownTracker = {}
ns.CooldownTracker = CooldownTracker

local trackedSpells = {}

local trackedSpellsChargeCDs = {}

function CooldownTracker:getSpellCD(spellId)
    local data = trackedSpells[spellId]

    if data then
        return data.cd
    end
    local obj = C_Spell.GetSpellCooldownDuration(spellId)
    trackedSpells[spellId] = {}
    trackedSpells[spellId].cd = obj
    return obj
end
function CooldownTracker:getChargeCD(spellId)
    local data = trackedSpellsChargeCDs[spellId]

    if data then
        return data.chargeCD
    end
    local chargeCD = C_Spell.GetSpellChargeDuration(spellId)
    trackedSpellsChargeCDs[spellId] = {}
    trackedSpellsChargeCDs[spellId].chargeCD = chargeCD
    return chargeCD
end

local cooldownTrackerFrame = CreateFrame("Frame")
cooldownTrackerFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownTrackerFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
cooldownTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownTrackerFrame:SetScript("OnEvent", function(_, event, spellId)
    if spellId and event == "SPELL_UPDATE_COOLDOWN" and trackedSpells[spellId] then
        local obj = C_Spell.GetSpellCooldownDuration(spellId)
        trackedSpells[spellId].cd = obj
    end
    if event == "PLAYER_ENTERING_WORLD" or not spellId then
        for spellId, data in pairs(trackedSpells) do
            local obj = C_Spell.GetSpellCooldownDuration(spellId)
            trackedSpells[spellId].cd = obj
        end
    end
    if event == "SPELL_UPDATE_CHARGES" then
        for spellId, data in pairs(trackedSpellsChargeCDs) do
            local obj = C_Spell.GetSpellChargeDuration(spellId)
            if obj then
                trackedSpellsChargeCDs[spellId].chargeCD = obj
            end
        end
    end
end)
