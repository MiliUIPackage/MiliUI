local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Profession = YUI.API.Profession or {}
YUI.API.Profession = Profession

local Legacy = YUI.WOW_API
local lower = string.lower
local ipairs = ipairs
local tableInsert = table.insert

local MINING_SKILL_LINE_ID = 186
local SMELTING_SPELL_ID = 2656

local EXTRA_SPELL_BY_SKILL_LINE = {
    [182] = 2383, -- Herbalism tracking
    [MINING_SKILL_LINE_ID] = SMELTING_SPELL_ID,
}

local professionInfoTable = nil

local function GetSpellNameAndIcon(spellID)
    if not spellID then return nil end

    if GetSpellInfo then
        local spellName, _, iconID = GetSpellInfo(spellID)
        return spellName, iconID
    end

    if C_Spell and C_Spell.GetSpellName then
        local spellName = C_Spell.GetSpellName(spellID)
        local iconID = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or nil
        return spellName, iconID
    end

    return nil
end

local function GetSpellName(spellID)
    return GetSpellNameAndIcon(spellID)
end

local function IsSameProfessionLabel(skillName, professionLabel)
    if not skillName or not professionLabel then return false end
    return skillName == professionLabel or lower(skillName) == lower(professionLabel)
end

local function GetSkillLineProfessions()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return nil, nil, nil, nil, nil, nil
    end

    local professions = {
        first = nil,
        second = nil,
        cooking = nil,
        firstAid = nil,
        fishing = nil,
    }

    for skillIndex = 1, GetNumSkillLines() do
        local skillName, isHeader, _, _, _, _, _, isAbandonable = GetSkillLineInfo(skillIndex)

        if skillName and not isHeader then
            if isAbandonable then
                if not professions.first then
                    professions.first = skillIndex
                else
                    professions.second = skillIndex
                end
            elseif IsSameProfessionLabel(skillName, PROFESSIONS_COOKING) then
                professions.cooking = skillIndex
            elseif IsSameProfessionLabel(skillName, PROFESSIONS_FIRST_AID) then
                professions.firstAid = skillIndex
            elseif IsSameProfessionLabel(skillName, PROFESSIONS_FISHING) then
                professions.fishing = skillIndex
            end
        end
    end

    return professions.first, professions.second, nil, professions.fishing, professions.cooking, professions.firstAid
end

function Profession.GetProfessions()
    if YUI.IsRetail then
        if GetProfessions then
            return GetProfessions()
        end
        return nil, nil, nil, nil, nil, nil
    end

    if YUI.IsMists then
        if GetProfessions then
            return GetProfessions()
        end
        return GetSkillLineProfessions()
    end

    if YUI.IsWrath then
        return GetSkillLineProfessions()
    end

    if GetProfessions then
        return GetProfessions()
    end
    return GetSkillLineProfessions()
end

function Profession.GetClassicProfessionInfoMap()
    if professionInfoTable ~= nil then return professionInfoTable end

    professionInfoTable = {}
    local professionMap = {
        { spellIds = { 3273, 3274, 7924, 10846, 27028, 45542, 74559, 110406, 158741, 195113 }, skillLine = 129, texture = 135966 },
        { spellIds = { 2018, 3100, 3538, 9785, 29844, 51300, 76666, 110396, 158737, 195097 }, skillLine = 164, texture = 136241 },
        { spellIds = { 2108, 3104, 3811, 10662, 32549, 51302, 81199, 110423, 158752, 195119 }, skillLine = 165, texture = 133611 },
        { spellIds = { 2259, 3101, 3464, 11611, 28596, 51304, 80731, 105206 }, skillLine = 171, texture = 136240 },
        { spellIds = { 9134 }, extraSpellId = 2383, skillLine = 182, texture = 136246 },
        { spellIds = { 32606, 2575, 2576, 3564, 10248 }, extraSpellId = SMELTING_SPELL_ID, skillLine = MINING_SKILL_LINE_ID, texture = 136248 },
        { spellIds = { 4036, 4037, 4038, 12656, 30350, 51306, 82774, 110403, 158739, 195112 }, skillLine = 202, texture = 136243 },
        { spellIds = { 7411, 7412, 7413, 13920, 28029, 51313, 74258, 110400, 158716, 195096 }, skillLine = 333, texture = 136244 },
        { spellIds = { 7620 }, skillLine = 356, texture = 136245 },
        { spellIds = { 2550, 3102, 3413, 18260, 33359, 51296, 88053, 104381, 158765, 195128 }, skillLine = 185, texture = 133971 },
        { spellIds = { 3908, 3909, 3910, 12180, 26790, 51309, 75156, 110426, 158758, 195126 }, skillLine = 197, texture = 136249 },
        { spellIds = { 8613 }, skillLine = 393, texture = 134366 },
    }

    tableInsert(professionMap, { spellIds = { 25229, 25230, 28894, 28895, 28897, 51311, 73318, 110420, 158750, 195116 }, skillLine = 755, texture = 134071 })
    tableInsert(professionMap, { spellIds = { 45357, 45358, 45359, 45360, 45361, 45363, 86008, 110417, 158748, 195115 }, skillLine = 773, texture = 237171 })
    tableInsert(professionMap, { spellIds = { 78670, 89721, 89722, 89718, 89720, 89719, 88961 }, skillLine = 794, texture = 441139 })

    for _, prof in ipairs(professionMap) do
        for _, spellID in ipairs(prof.spellIds) do
            local spellName, iconID = GetSpellNameAndIcon(spellID)

            if spellName and (not prof.texture or prof.texture == iconID) then
                professionInfoTable[spellName] = prof
                break
            end
        end
    end

    return professionInfoTable
end

local function GetProfessionInfoFromGlobal(index, includeExtraSpell)
    if not GetProfessionInfo then return nil end

    local skillName, texture, skillRank, skillMaxRank, _, _, skillLine = GetProfessionInfo(index)
    local extraSpellId = includeExtraSpell and EXTRA_SPELL_BY_SKILL_LINE[skillLine] or nil
    return skillLine, skillName, skillRank, skillMaxRank, texture, extraSpellId
end

local function GetProfessionInfoFromSkillLine(index)
    if not GetSkillLineInfo then return nil end

    local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(index)
    local info = Profession.GetClassicProfessionInfoMap()[skillName] or {}
    return info.skillLine, skillName, skillRank, skillMaxRank, info.texture, info.extraSpellId
end

function Profession.GetProfessionInfo(index)
    if not index then return nil end

    if YUI.IsRetail then
        return GetProfessionInfoFromGlobal(index, false)
    end

    if YUI.IsMists then
        return GetProfessionInfoFromGlobal(index, true) or GetProfessionInfoFromSkillLine(index)
    end

    if YUI.IsWrath then
        return GetProfessionInfoFromSkillLine(index)
    end

    return GetProfessionInfoFromGlobal(index, true) or GetProfessionInfoFromSkillLine(index)
end

function Profession.GetOpenName(name, skillLineID, extraSpellId, preferExtraSpell)
    if YUI.IsRetail then
        return name
    end

    if YUI.IsMists or YUI.IsWrath then
        local fallback = skillLineID == MINING_SKILL_LINE_ID and "Smelting" or name

        if extraSpellId and (preferExtraSpell or skillLineID == MINING_SKILL_LINE_ID) then
            return GetSpellName(extraSpellId) or fallback
        end

        return fallback
    end

    return name
end

local function ToggleRetailProfessionFrame(skillLineID)
    if not skillLineID or not C_TradeSkillUI or not C_TradeSkillUI.OpenTradeSkill then
        return nil
    end

    local isShown = ProfessionsFrame and ProfessionsFrame:IsShown()
    if isShown and C_TradeSkillUI.GetBaseProfessionInfo then
        local info = C_TradeSkillUI.GetBaseProfessionInfo()
        if info and info.professionID == skillLineID then
            if C_TradeSkillUI.CloseTradeSkill then
                C_TradeSkillUI.CloseTradeSkill()
            elseif ProfessionsFrame then
                HideUIPanel(ProfessionsFrame)
            end
            return true
        end
    end

    return C_TradeSkillUI.OpenTradeSkill(skillLineID)
end

local function ToggleClassicProfessionFrame(name)
    if CastSpellByName and name then
        return CastSpellByName(name)
    end
    return nil
end

function Profession.ToggleProfessionFrame(name, skillLineID)
    if YUI.IsRetail then
        return ToggleRetailProfessionFrame(skillLineID)
    end

    if YUI.IsMists then
        return ToggleClassicProfessionFrame(name)
    end

    if YUI.IsWrath then
        return ToggleClassicProfessionFrame(name)
    end

    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and skillLineID then
        return C_TradeSkillUI.OpenTradeSkill(skillLineID)
    end
    return ToggleClassicProfessionFrame(name)
end

Legacy.GetProfessions = Profession.GetProfessions
Legacy.GetWrathProfessionInfo = Profession.GetClassicProfessionInfoMap
Legacy.GetProfessionInfo = Profession.GetProfessionInfo
Legacy.GetProfessionOpenName = Profession.GetOpenName
Legacy.ToggleProfessionFrame = Profession.ToggleProfessionFrame
