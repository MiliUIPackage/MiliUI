local MAJOR, MINOR = "LibS2kMisc-1.0", 201607281

local lib, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- table extensions

function table.s2k_is_empty(tab)
    for _ in pairs(tab) do
        return false
    end
    return true
end

function table.s2k_len(tab)
    local count = 0
    for _ in pairs(tab) do
        count = count + 1
    end
    return count
end

function table.s2k_select(tab, ...)
    local indexes, res = {...}, {}
    local i, j = 0
    for _, j in ipairs(indexes) do
        i = i + 1
        res[i] = tab[j]
    end
    return unpack(res, 1, i)
end

function table.s2k_pairs(tab, needUnpack)
    local index
    return function()
        local k, v = next(tab, index)
        if k then
            index = k
            if needUnpack then
                return k, unpack(v)
            end
            return k, v
        end
    end
end

function table.s2k_values(tab, needUnpack)
    local index
    return function()
        local k, v = next(tab, index)
        if k then
            index = k
            if needUnpack then
                return unpack(v)
            end
            return v
        end
    end
end

function table.s2k_copy(tab)
    local ret = {}
    local k, v
    for k, v in pairs(tab) do
        if type(v) == "table" then
            ret[k] = table.s2k_copy(v)
        else
            ret[k] = v
        end
    end
    return ret
end

-- in-game functions

function UnitInfoFromGuid(guid)
    local parts = {strsplit('-', guid)}
    local type = parts[1]

    if type == 'Creature' or type == 'Vehicle' then
        local id = tonumber(parts[6])
        return type, id
    end

    return type
end

local function HookPetJournal()
    local saved = { search = "" }

    hooksecurefunc(C_PetJournal, "ClearSearchFilter", function() saved.search = "" end)
    hooksecurefunc(C_PetJournal, "SetSearchFilter", function(text) saved.search = text end)

    C_PetJournal.GetSearchFilter = function() return saved.search end
end

if not oldMinor or oldMinor < 201507294 then
    HookPetJournal()
end
