do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Icons = YUI.API.Icons or {}
YUI.API.Icons = Icons

local Legacy = YUI.WOW_API
local Talent = YUI.API and YUI.API.Talent or Legacy
local Unit = YUI.API and YUI.API.Unit or Legacy

local type = type
local pairs = pairs
local ipairs = ipairs
local math_min = math.min
local math_max = math.max
local tonumber = tonumber
local tostring = tostring
local string_find = string.find
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_match = string.match
local strupper = string.upper
local strlower = string.lower
local table_insert = table.insert
local table_sort = table.sort
local unpack = unpack

local DEFAULT_SET_ID = "blizzard"
local SCOPE_STATE_VERSION = 2
local NATIVE_SPEC_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }
local DEFAULT_TEXTURE_INDEX_ROOT = "Interface\\Icons\\"

local DEFAULT_SEARCH_ALIASES = {
    ["红"] = { "red", "crimson", "scarlet", "ruby", "blood" },
    ["红色"] = { "red", "crimson", "scarlet", "ruby", "blood" },
    ["赤"] = { "red", "crimson", "scarlet", "ruby", "blood" },
    ["蓝"] = { "blue", "azure", "cyan", "frost", "ice", "water" },
    ["蓝色"] = { "blue", "azure", "cyan", "frost", "ice", "water" },
    ["绿"] = { "green", "emerald", "nature", "poison", "fel" },
    ["绿色"] = { "green", "emerald", "nature", "poison", "fel" },
    ["黄"] = { "yellow", "gold", "holy", "light", "sun" },
    ["黄色"] = { "yellow", "gold", "holy", "light", "sun" },
    ["金"] = { "gold", "yellow", "holy", "light" },
    ["金色"] = { "gold", "yellow", "holy", "light" },
    ["紫"] = { "purple", "violet", "shadow", "arcane" },
    ["紫色"] = { "purple", "violet", "shadow", "arcane" },
    ["黑"] = { "black", "dark", "shadow", "death" },
    ["黑色"] = { "black", "dark", "shadow", "death" },
    ["白"] = { "white", "holy", "light", "frost" },
    ["白色"] = { "white", "holy", "light", "frost" },
    ["火"] = { "fire", "flame", "burn", "lava", "ember" },
    ["火焰"] = { "fire", "flame", "burn", "lava", "ember" },
    ["冰"] = { "frost", "ice", "cold", "snow" },
    ["冰霜"] = { "frost", "ice", "cold", "snow" },
    ["暗影"] = { "shadow", "dark", "void", "death" },
    ["神圣"] = { "holy", "light", "priest" },
    ["自然"] = { "nature", "leaf", "green", "earth" },
    ["奥术"] = { "arcane", "magic", "mage" },
    ["毒"] = { "poison", "toxic", "venom", "green" },
    ["治疗"] = { "heal", "healing", "holy", "renew" },
    ["盾"] = { "shield", "barrier", "protect" },
    ["剑"] = { "sword", "blade" },
    ["斧"] = { "axe" },
    ["锤"] = { "hammer", "mace" },
    ["弓"] = { "bow", "arrow" },
}

local NATIVE_TEXTURE_TO_SPEC = {
    [135770] = 250, [135773] = 251, [135775] = 252,
    [1247264] = 577, [1247265] = 581, [7455385] = 1480, [4574311] = 1465,
    [136096] = 102, [132115] = 103, [132276] = 104, [136041] = 105,
    [4511811] = 1467, [4511812] = 1468, [5198700] = 1473,
    [461112] = 253, [236179] = 254, [461113] = 255,
    [135932] = 62, [135810] = 63, [135846] = 64,
    [608951] = 268, [608952] = 270, [608953] = 269,
    [135920] = 65, [236264] = 66, [135873] = 70,
    [135940] = 256, [237542] = 257, [136207] = 258,
    [236270] = 259, [236286] = 260, [132320] = 261,
    [136048] = 262, [237581] = 263, [136052] = 264,
    [136145] = 265, [136172] = 266, [136186] = 267,
    [132355] = 71, [132347] = 72, [132341] = 73,
}
local nativeTextureToSpecCache
local nativeTextureToSpecDynamicBuilt = false

local DEFAULT_SPEC_ATLAS_COORDS = {
    [250] = "0:64:0:64", [251] = "64:128:0:64", [252] = "128:192:0:64",
    [577] = "128:192:256:320", [581] = "192:256:256:320", [1480] = "448:512:256:320", [1465] = "128:192:256:320",
    [102] = "192:256:0:64", [103] = "256:320:0:64", [104] = "320:384:0:64", [105] = "384:448:0:64",
    [1467] = "256:320:256:320", [1468] = "320:384:256:320", [1473] = "384:448:256:320",
    [253] = "448:512:0:64", [254] = "0:64:64:128", [255] = "64:128:64:128",
    [62] = "128:192:64:128", [63] = "192:256:64:128", [64] = "256:320:64:128",
    [268] = "320:384:64:128", [270] = "384:448:64:128", [269] = "448:512:64:128",
    [65] = "0:64:128:192", [66] = "64:128:128:192", [70] = "128:192:128:192",
    [256] = "192:256:128:192", [257] = "256:320:128:192", [258] = "320:384:128:192",
    [259] = "384:448:128:192", [260] = "448:512:128:192", [261] = "0:64:192:256",
    [262] = "64:128:192:256", [263] = "128:192:192:256", [264] = "192:256:192:256",
    [265] = "256:320:192:256", [266] = "320:384:192:256", [267] = "384:448:192:256",
    [71] = "448:512:192:256", [72] = "0:64:256:320", [73] = "64:128:256:320",
}

local DEFAULT_RACE_ICON_TCOORDS = {
    HUMAN_MALE = { 0, 0.125, 0, 0.25 },
    DWARF_MALE = { 0.125, 0.25, 0, 0.25 },
    GNOME_MALE = { 0.25, 0.375, 0, 0.25 },
    NIGHTELF_MALE = { 0.375, 0.5, 0, 0.25 },
    DRAENEI_MALE = { 0.5, 0.625, 0, 0.25 },
    WORGEN_MALE = { 0.625, 0.75, 0, 0.25 },
    PANDAREN_MALE = { 0.75, 0.875, 0, 0.25 },

    TAUREN_MALE = { 0, 0.125, 0.25, 0.5 },
    SCOURGE_MALE = { 0.125, 0.25, 0.25, 0.5 },
    TROLL_MALE = { 0.25, 0.375, 0.25, 0.5 },
    ORC_MALE = { 0.375, 0.5, 0.25, 0.5 },
    BLOODELF_MALE = { 0.5, 0.625, 0.25, 0.5 },
    GOBLIN_MALE = { 0.625, 0.75, 0.25, 0.5 },

    HUMAN_FEMALE = { 0, 0.125, 0.5, 0.75 },
    DWARF_FEMALE = { 0.125, 0.25, 0.5, 0.75 },
    GNOME_FEMALE = { 0.25, 0.375, 0.5, 0.75 },
    NIGHTELF_FEMALE = { 0.375, 0.5, 0.5, 0.75 },
    DRAENEI_FEMALE = { 0.5, 0.625, 0.5, 0.75 },
    WORGEN_FEMALE = { 0.625, 0.75, 0.5, 0.75 },
    PANDAREN_FEMALE = { 0.75, 0.875, 0.5, 0.75 },

    TAUREN_FEMALE = { 0, 0.125, 0.75, 1 },
    SCOURGE_FEMALE = { 0.125, 0.25, 0.75, 1 },
    TROLL_FEMALE = { 0.25, 0.375, 0.75, 1 },
    ORC_FEMALE = { 0.375, 0.5, 0.75, 1 },
    BLOODELF_FEMALE = { 0.5, 0.625, 0.75, 1 },
    GOBLIN_FEMALE = { 0.625, 0.75, 0.75, 1 },
}

local RACE_ATLAS_STEM_OVERRIDES = {
    lightforgeddraenei = "lightforged",
    highmountaintauren = "highmountain",
    zandalaritroll = "zandalari",
    earthendwarf = "earthen",
    scourge = "undead",
    harronir = "haranir",
}

local coordCache = {}

local function CopyCoord(coord)
    if type(coord) ~= "table" then
        return nil
    end
    return { coord[1], coord[2], coord[3], coord[4] }
end

local function CropCoord(coord, inset)
    if type(coord) ~= "table" then
        return nil
    end

    inset = tonumber(inset) or 0
    local left, right, top, bottom = coord[1], coord[2], coord[3], coord[4]
    if not left or not right or not top or not bottom then
        return nil
    end

    local width = right - left
    local height = bottom - top
    return {
        left + (width * inset),
        right - (width * inset),
        top + (height * inset),
        bottom - (height * inset),
    }
end

local function ParseCoords(key, value)
    if type(value) == "table" then
        return CopyCoord(value)
    end
    if type(value) ~= "string" then
        return nil
    end

    local cacheKey = tostring(key or "") .. ":" .. value
    if coordCache[cacheKey] then
        return CopyCoord(coordCache[cacheKey])
    end

    local x1, x2, y1, y2 = value:match("^(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)$")
    if not x1 then
        return nil
    end

    local coord = {
        tonumber(x1) / 512,
        tonumber(x2) / 512,
        tonumber(y1) / 512,
        tonumber(y2) / 512,
    }
    coordCache[cacheKey] = coord
    return CopyCoord(coord)
end

local function CopySpecCoords(source)
    if source == true then
        source = DEFAULT_SPEC_ATLAS_COORDS
    end
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}
    for specID, coord in pairs(source) do
        copy[specID] = coord
    end
    return copy
end

local function AddNativeSpecTexture(map, specID, texture)
    specID = tonumber(specID)
    if specID and type(texture) == "number" then
        map[texture] = specID
    end
end

local function GetClassIDByIndex(index)
    if GetClassInfo then
        local _, _, classID = GetClassInfo(index)
        if classID then
            return classID
        end
    end
    return index
end

local function GetNumSpecsForClassID(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
    elseif GetNumSpecializationsForClassID then
        return GetNumSpecializationsForClassID(classID)
    end
    return nil
end

local function GetSpecInfoForClassID(classID, index)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        local sex = UnitSex and UnitSex("player") or nil
        return C_SpecializationInfo.GetSpecializationInfoForClassID(classID, index, sex)
    elseif GetSpecializationInfoForClassID then
        local sex = UnitSex and UnitSex("player") or nil
        return GetSpecializationInfoForClassID(classID, index, sex)
    end
    return nil
end

local function HasSpecInfoForClassID()
    return GetSpecializationInfoForClassID
        or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID)
end

local function HasNumSpecsForClassID()
    return GetNumSpecializationsForClassID
        or (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
end

local function EnsureNativeTextureToSpecMap()
    if not nativeTextureToSpecCache then
        nativeTextureToSpecCache = {}
        for texture, specID in pairs(NATIVE_TEXTURE_TO_SPEC) do
            nativeTextureToSpecCache[texture] = specID
        end
    end

    if nativeTextureToSpecDynamicBuilt then
        return nativeTextureToSpecCache
    end

    if not GetNumClasses or not HasNumSpecsForClassID() or not HasSpecInfoForClassID() then
        return nativeTextureToSpecCache
    end

    local numClasses = GetNumClasses()
    if not numClasses or numClasses <= 0 then
        return nativeTextureToSpecCache
    end

    for classIndex = 1, numClasses do
        local classID = GetClassIDByIndex(classIndex)
        local specCount = classID and GetNumSpecsForClassID(classID) or nil
        if specCount and specCount > 0 then
            for specIndex = 1, specCount do
                local specID, _, _, texture = GetSpecInfoForClassID(classID, specIndex)
                AddNativeSpecTexture(nativeTextureToSpecCache, specID, texture)
            end
        end
    end

    nativeTextureToSpecDynamicBuilt = true
    return nativeTextureToSpecCache
end

local function GetSpecIDByNativeTexture(texture)
    if type(texture) ~= "number" then
        return nil
    end
    local map = EnsureNativeTextureToSpecMap()
    return map and map[texture] or nil
end

local function NormalizeLegacySetID(value)
    if value == "Custom1"
        or value == "Custom2"
        or value == "Custom3"
        or value == "YUISpec1"
        or value == "YUISpec2"
        or value == "YUISpec3" then
        return "YUISpec1"
    elseif value == "Blizzard" or value == DEFAULT_SET_ID then
        return DEFAULT_SET_ID
    end
    return nil
end

local function GetAppearanceRootDB()
    if YUI.DB and YUI.DB.GetProfile then
        local profile = YUI.DB:GetProfile("suite")
        if type(profile) == "table" then
            return profile
        end
    end
    return nil
end

local function EnsureAppearanceDB()
    local root = GetAppearanceRootDB()
    if not root then
        return nil
    end
    if type(root.Appearance) ~= "table" then
        root.Appearance = {}
    end

    local db = root.Appearance
    if db.classSpecIconSet == nil then
        local migrated = nil
        if type(root.YDamageMeter) == "table" then
            migrated = NormalizeLegacySetID(root.YDamageMeter.iconTheme)
        end
        if not migrated then
            migrated = NormalizeLegacySetID(root.LightDamage_IconTheme)
        end
        db.classSpecIconSet = migrated or DEFAULT_SET_ID
    else
        db.classSpecIconSet = NormalizeLegacySetID(db.classSpecIconSet) or db.classSpecIconSet
    end

    if type(db.classSpecIconScopeUserSet) ~= "table" then
        db.classSpecIconScopeUserSet = {}
    end
    if type(db.classSpecIconScopeDisabled) ~= "table" then
        db.classSpecIconScopeDisabled = {}
    end

    if db.classSpecIconScopeStateVersion ~= SCOPE_STATE_VERSION then
        local legacyScopes = db.classSpecIconScopes
        if type(legacyScopes) ~= "table" then
            legacyScopes = {}
            if root.PluginSkins_DetailsSpecSync ~= nil then
                legacyScopes.details_spec_sync = root.PluginSkins_DetailsSpecSync == true
            end
            db.classSpecIconScopes = legacyScopes
        end

        if legacyScopes.light_damage == false and db.classSpecIconScopeUserSet.light_damage ~= true then
            legacyScopes.light_damage = true
        end

        for scopeID, enabled in pairs(legacyScopes) do
            if enabled == false then
                db.classSpecIconScopeDisabled[scopeID] = true
            end
        end
        db.classSpecIconScopeStateVersion = SCOPE_STATE_VERSION
    end

    return db
end

local function EmitIconSetChanged(setID, previousID)
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit("YUI_APPEARANCE_ICON_SET_CHANGED", setID, previousID)
    elseif YUI.Fire then
        YUI:Fire("YUI_APPEARANCE_ICON_SET_CHANGED", setID, previousID)
    end
end

local function EmitIconScopeChanged(scopeID, enabled, previous)
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit("YUI_APPEARANCE_ICON_SCOPE_CHANGED", scopeID, enabled, previous)
    elseif YUI.Fire then
        YUI:Fire("YUI_APPEARANCE_ICON_SCOPE_CHANGED", scopeID, enabled, previous)
    end
end

Icons.iconSets = Icons.iconSets or {}
Icons.iconSetOrder = Icons.iconSetOrder or {}
Icons.iconScopes = Icons.iconScopes or {}
Icons.iconScopeOrder = Icons.iconScopeOrder or {}
Icons.textureIndexes = Icons.textureIndexes or {}
Icons.textureIndexOrder = Icons.textureIndexOrder or {}

local function RememberOrder(order, id)
    for _, existing in ipairs(order) do
        if existing == id then
            return
        end
    end
    order[#order + 1] = id
end

local function Trim(value)
    value = tostring(value or "")
    return (string_gsub(value, "^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeIconBaseName(value)
    if type(value) ~= "string" then
        return nil
    end
    value = Trim(value)
    if value == "" then return nil end
    value = string_gsub(value, "^Interface[/\\]Icons[/\\]", "")
    value = string_gsub(value, "^Interface[/\\]icons[/\\]", "")
    value = string_gsub(value, "^interface[/\\]icons[/\\]", "")
    return value ~= "" and value or nil
end

local function NormalizeSearchText(value)
    value = strlower(tostring(value or ""))
    value = string_gsub(value, "[_%-%.]+", " ")
    value = string_gsub(value, "%s+", " ")
    return value
end

local function AddTokenGroup(groups, token)
    if token == "" then return end
    local group, seen = {}, {}
    group[#group + 1] = token
    seen[token] = true

    local aliases = Icons.searchAliases and Icons.searchAliases[token]
    if type(aliases) == "table" then
        for _, alias in ipairs(aliases) do
            alias = NormalizeSearchText(alias)
            for aliasToken in string_gmatch(alias, "[^%s]+") do
                if aliasToken ~= "" and not seen[aliasToken] then
                    seen[aliasToken] = true
                    group[#group + 1] = aliasToken
                end
            end
        end
    end

    groups[#groups + 1] = group
end

local function SplitSearchTokens(query)
    local groups = {}
    query = NormalizeSearchText(query)
    for token in string_gmatch(query, "[^%s]+") do
        AddTokenGroup(groups, token)
    end
    return groups
end

local function JoinAliases(aliases)
    if type(aliases) == "table" then
        local values = {}
        for _, alias in ipairs(aliases) do
            values[#values + 1] = tostring(alias)
        end
        return table.concat(values, " ")
    end
    return tostring(aliases or "")
end

local function ParseTextureIndexEntry(entry)
    local fileID, name, searchText
    if type(entry) == "string" then
        local rawID, rawName = string_match(entry, "^(%d+):(.+)$")
        fileID = tonumber(rawID)
        name = rawName or entry
    elseif type(entry) == "table" then
        fileID = tonumber(entry.fileID or entry.id or entry[1])
        name = entry.name or entry.path or entry[2]
        searchText = entry.searchText or entry.search or entry.aliases
    end

    name = NormalizeIconBaseName(name)
    if not name then return nil end
    return fileID, name, searchText
end

local function EnsureTextureIndexEntries(index)
    if type(index) ~= "table" then return nil end
    return type(index.entries) == "table" and index.entries or nil
end

local function GetTextureIndex(id)
    if id and Icons.textureIndexes[id] then
        return Icons.textureIndexes[id]
    end
    if Icons.activeTextureIndexID and Icons.textureIndexes[Icons.activeTextureIndexID] then
        return Icons.textureIndexes[Icons.activeTextureIndexID]
    end
    for _, indexID in ipairs(Icons.textureIndexOrder) do
        local index = Icons.textureIndexes[indexID]
        if index then return index end
    end
    return nil
end

function Icons.RegisterTextureIndex(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return false
    end
    if type(def.entries) ~= "table" then
        return false
    end

    local id = def.id
    Icons.textureIndexes[id] = {
        id = id,
        name = def.name or id,
        version = def.version,
        flavor = def.flavor,
        root = def.root or DEFAULT_TEXTURE_INDEX_ROOT,
        entries = def.entries,
        count = tonumber(def.count) or #def.entries,
    }
    Icons.activeTextureIndexID = id
    RememberOrder(Icons.textureIndexOrder, id)
    return true
end

function Icons.HasTextureIndex(id)
    local index = GetTextureIndex(id)
    if not index then return false end
    if type(index.entries) == "table" and #index.entries > 0 then return true end
    return false
end

local function TextureEntryMatches(fileID, searchText, tokenGroups, numericQuery)
    if numericQuery and fileID == numericQuery then
        return true
    end
    if #tokenGroups == 0 then
        return false
    end
    local haystack = searchText or ""
    for _, group in ipairs(tokenGroups) do
        local matched = false
        for _, token in ipairs(group) do
            if string_find(haystack, token, 1, true) then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end
    return true
end

local function CreateTextureIndexSearchState(query, opts)
    opts = type(opts) == "table" and opts or {}
    local result = {
        hasIndex = false,
        total = 0,
        truncated = false,
        complete = true,
        scanned = 0,
    }
    local index = GetTextureIndex(opts.indexID)
    if not index then
        return nil, result
    end
    local entries = EnsureTextureIndexEntries(index)
    if type(entries) ~= "table" or #entries == 0 then
        return nil, result
    end

    local queryText = Trim(query)
    local tokenGroups = SplitSearchTokens(queryText)
    local numericQuery = tonumber(queryText)
    result.hasIndex = true
    result.indexID = index.id
    result.indexName = index.name
    result.complete = false

    return {
        entries = entries,
        root = index.root or DEFAULT_TEXTURE_INDEX_ROOT,
        tokenGroups = tokenGroups,
        numericQuery = numericQuery,
        limit = math_min(math_max(tonumber(opts.limit) or 240, 1), 1000),
        stopAfterLimit = opts.stopAfterLimit == true,
        cursor = 1,
        result = result,
        done = false,
    }, result
end

local function StepTextureIndexSearchState(state, opts)
    if not state or state.done then
        return true, state and state.result or nil
    end
    opts = type(opts) == "table" and opts or {}
    local budgetMS = tonumber(opts.budgetMS)
    local minEntries = tonumber(opts.minEntries) or 64
    local maxEntries = tonumber(opts.maxEntries)
    local startTime = budgetMS and debugprofilestop and debugprofilestop() or nil
    local processed = 0
    local entries = state.entries
    local result = state.result

    while state.cursor <= #entries do
        local rawEntry = entries[state.cursor]
        state.cursor = state.cursor + 1
        processed = processed + 1

        local fileID, name, searchExtra = ParseTextureIndexEntry(rawEntry)
        if name then
            local searchText = NormalizeSearchText(name .. " " .. JoinAliases(searchExtra))
            local exactNumericMatch = state.numericQuery and fileID == state.numericQuery
            if TextureEntryMatches(fileID, searchText, state.tokenGroups, state.numericQuery) then
                result.total = result.total + 1
                if #result < state.limit then
                    local texture = state.root .. name
                    table_insert(result, {
                        group = "图标库",
                        label = name,
                        value = texture,
                        icon = texture,
                        source = "图标库",
                        fileID = fileID,
                        name = name,
                    })
                end
                if exactNumericMatch or (state.stopAfterLimit and result.total > state.limit) then
                    result.truncated = not exactNumericMatch
                    state.done = true
                    break
                end
            end
        end

        if maxEntries and processed >= maxEntries then
            break
        end
        if startTime and processed >= minEntries and (debugprofilestop() - startTime) >= budgetMS then
            break
        end
    end

    result.scanned = state.cursor - 1
    if state.cursor > #entries then
        state.done = true
    end
    result.complete = state.done
    if not state.stopAfterLimit then
        result.truncated = result.total > #result
    end
    return state.done, result
end

function Icons.RegisterSearchAliases(map)
    if type(map) ~= "table" then return false end
    Icons.searchAliases = Icons.searchAliases or {}
    for key, aliases in pairs(map) do
        key = NormalizeSearchText(key)
        if key ~= "" then
            Icons.searchAliases[key] = aliases
        end
    end
    return true
end

function Icons.SearchTextureIndex(query, opts)
    opts = type(opts) == "table" and opts or {}
    local offset = math_max(tonumber(opts.offset) or 0, 0)
    local limit = math_min(math_max(tonumber(opts.limit) or 240, 1), 1000)
    local state, result = CreateTextureIndexSearchState(query, opts)
    if not state then return result end
    state.limit = limit + offset
    state.stopAfterLimit = opts.stopAfterLimit == true
    StepTextureIndexSearchState(state, { maxEntries = nil })
    if offset > 0 and #result > 0 then
        local shifted = {}
        for index = offset + 1, #result do
            shifted[#shifted + 1] = result[index]
        end
        for index = 1, #result do
            result[index] = nil
        end
        for index = 1, math_min(#shifted, limit) do
            result[index] = shifted[index]
        end
    end
    return result
end

function Icons.CreateTextureIndexSearchJob(query, opts)
    opts = type(opts) == "table" and opts or {}
    local state, result = CreateTextureIndexSearchState(query, {
        indexID = opts.indexID,
        limit = opts.limit,
        stopAfterLimit = opts.stopAfterLimit ~= false,
    })
    local job = {
        complete = state == nil,
        result = result,
    }

    function job:Step(stepOpts)
        if not state then
            return true, self.result
        end
        local done, nextResult = StepTextureIndexSearchState(state, stepOpts)
        self.complete = done
        self.result = nextResult
        return done, nextResult
    end

    return job
end

Icons.searchAliases = Icons.searchAliases or {}
Icons.RegisterSearchAliases(DEFAULT_SEARCH_ALIASES)

function Icons.RegisterIconSet(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return false
    end

    local id = def.id
    local set = {
        id = id,
        name = def.name or id,
        nameKey = def.nameKey,
        detailsLabel = def.detailsLabel or def.name or id,
        order = tonumber(def.order) or 1000,
        texture = def.texture,
        atlas = def.atlas,
        custom = def.custom == true,
        kind = def.kind or "class-spec",
        specCoords = CopySpecCoords(def.specCoords),
        classCoords = CopySpecCoords(def.classCoords),
    }
    set.hasSpecIcons = type(set.specCoords) == "table" and set.texture ~= nil

    Icons.iconSets[id] = set
    RememberOrder(Icons.iconSetOrder, id)
    return true
end

local function GetScopeDefault(scope)
    if scope and scope.default ~= nil then
        return scope.default == true
    end
    return true
end

function Icons.RegisterIconScope(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return false
    end

    local id = def.id
    local scope = {
        id = id,
        name = def.name or id,
        nameKey = def.nameKey,
        tooltip = def.tooltip,
        tooltipKey = def.tooltipKey,
        order = tonumber(def.order) or 1000,
        default = def.default == nil and true or def.default == true,
    }

    Icons.iconScopes[id] = scope
    RememberOrder(Icons.iconScopeOrder, id)
    return true
end

function Icons.GetIconSet(id)
    id = NormalizeLegacySetID(id) or id or DEFAULT_SET_ID
    return Icons.iconSets[id] or Icons.iconSets[DEFAULT_SET_ID]
end

function Icons.GetIconSets()
    local result = {}
    for _, id in ipairs(Icons.iconSetOrder) do
        local set = Icons.iconSets[id]
        if set then
            result[#result + 1] = set
        end
    end
    table_sort(result, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.id < b.id
    end)
    return result
end

function Icons.GetIconScopes()
    local result = {}
    for _, id in ipairs(Icons.iconScopeOrder) do
        local scope = Icons.iconScopes[id]
        if scope then
            result[#result + 1] = scope
        end
    end
    table_sort(result, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.id < b.id
    end)
    return result
end

function Icons.GetActiveIconSetID()
    local db = EnsureAppearanceDB()
    local id = db and db.classSpecIconSet or Icons.activeIconSetID or DEFAULT_SET_ID
    id = NormalizeLegacySetID(id) or id or DEFAULT_SET_ID
    if not Icons.iconSets[id] then
        return DEFAULT_SET_ID
    end
    return id
end

function Icons.IsIconScopeEnabled(id)
    if type(id) ~= "string" or id == "" then
        return true
    end

    local scope = Icons.iconScopes[id]
    local default = GetScopeDefault(scope)
    local db = EnsureAppearanceDB()
    if db and type(db.classSpecIconScopeDisabled) == "table" then
        if db.classSpecIconScopeDisabled[id] == true then
            return false
        end
        return default
    end

    if Icons.iconScopeDisabled and Icons.iconScopeDisabled[id] == true then
        return false
    end
    if Icons.iconScopeStates and Icons.iconScopeStates[id] ~= nil then
        return Icons.iconScopeStates[id] == true
    end
    return default
end

function Icons.SetIconScopeEnabled(id, enabled)
    if type(id) ~= "string" or id == "" then
        return nil
    end

    enabled = enabled == true
    local previous = Icons.IsIconScopeEnabled(id)
    local db = EnsureAppearanceDB()
    if db then
        db.classSpecIconScopeDisabled = type(db.classSpecIconScopeDisabled) == "table"
            and db.classSpecIconScopeDisabled or {}
        if enabled then
            db.classSpecIconScopeDisabled[id] = nil
        else
            db.classSpecIconScopeDisabled[id] = true
        end
        db.classSpecIconScopeUserSet = type(db.classSpecIconScopeUserSet) == "table"
            and db.classSpecIconScopeUserSet or {}
        db.classSpecIconScopeUserSet[id] = true
        if type(db.classSpecIconScopes) == "table" then
            db.classSpecIconScopes[id] = nil
        end
        db.classSpecIconScopeStateVersion = SCOPE_STATE_VERSION
    else
        Icons.iconScopeStates = Icons.iconScopeStates or {}
        Icons.iconScopeStates[id] = enabled
        Icons.iconScopeDisabled = Icons.iconScopeDisabled or {}
        if enabled then
            Icons.iconScopeDisabled[id] = nil
        else
            Icons.iconScopeDisabled[id] = true
        end
    end

    if previous ~= enabled then
        EmitIconScopeChanged(id, enabled, previous)
    end
    return enabled
end

function Icons.SetActiveIconSetID(id)
    id = NormalizeLegacySetID(id) or id or DEFAULT_SET_ID
    if not Icons.iconSets[id] then
        id = DEFAULT_SET_ID
    end

    local previousID = Icons.GetActiveIconSetID()
    local db = EnsureAppearanceDB()
    if db then
        db.classSpecIconSet = id
    else
        Icons.activeIconSetID = id
    end

    if previousID ~= id then
        EmitIconSetChanged(id, previousID)
    end
    return id
end

local function GetBlizzardSpecIcon(specID, nativeTexture)
    local icon = nativeTexture
    if icon == nil and specID then
        if Talent and Talent.GetSpecializationInfoByID then
            icon = select(4, Talent.GetSpecializationInfoByID(specID))
        elseif GetSpecializationInfoByID then
            icon = select(4, GetSpecializationInfoByID(specID))
        end
    end
    if icon == nil then
        icon = 134400
    end
    return {
        texture = icon,
        texCoord = { 0, 1, 0, 1 },
        setId = DEFAULT_SET_ID,
        kind = "spec",
        custom = false,
        specID = specID,
    }
end

function Icons.GetSpecIcon(specID, setID)
    specID = tonumber(specID)
    if not specID then
        return nil
    end

    local set = Icons.GetIconSet(setID or Icons.GetActiveIconSetID())
    local coordValue = set and set.specCoords and set.specCoords[specID]
    if set and set.id ~= DEFAULT_SET_ID and set.texture and coordValue then
        local texCoord = ParseCoords(specID, coordValue)
        if not texCoord then
            return GetBlizzardSpecIcon(specID)
        end

        return {
            texture = set.texture,
            atlas = set.atlas,
            texCoord = texCoord,
            setId = set.id,
            kind = "spec",
            custom = true,
            specID = specID,
        }
    end

    return GetBlizzardSpecIcon(specID)
end

function Icons.GetSpecIconByNativeTexture(textureOrFileID, setID)
    if textureOrFileID == nil then
        return nil
    end

    local specID = GetSpecIDByNativeTexture(textureOrFileID)
    if specID then
        local set = Icons.GetIconSet(setID or Icons.GetActiveIconSetID())
        local icon = Icons.GetSpecIcon(specID, set and set.id or nil)
        if icon and icon.custom then
            return icon
        end
        return GetBlizzardSpecIcon(specID, textureOrFileID)
    end

    return {
        texture = textureOrFileID,
        texCoord = { 0, 1, 0, 1 },
        setId = DEFAULT_SET_ID,
        kind = "spec",
        custom = false,
    }
end

function Icons.GetNativeSpecTexCoord()
    return CopyCoord(NATIVE_SPEC_TEXCOORD)
end

function Icons.GetScopedSpecIcon(specID, nativeTexture, scopeID, setID)
    specID = tonumber(specID)

    local useTheme = true
    if scopeID and Icons.IsIconScopeEnabled then
        useTheme = Icons.IsIconScopeEnabled(scopeID)
    end

    if useTheme and specID then
        local icon = Icons.GetSpecIcon(specID, setID)
        if icon and (icon.custom or nativeTexture == nil) then
            return icon
        end
    end

    if useTheme and nativeTexture ~= nil then
        local icon = Icons.GetSpecIconByNativeTexture(nativeTexture, setID)
        if icon then
            return icon
        end
    end

    if specID or nativeTexture ~= nil then
        return GetBlizzardSpecIcon(specID, nativeTexture)
    end

    return nil
end

local function ResolveClassFile(classFileOrID)
    if type(classFileOrID) == "number" then
        if Unit and Unit.GetClassInfo then
            local info = Unit.GetClassInfo(classFileOrID)
            return info and info.classFile or nil
        elseif GetClassInfo then
            return select(2, GetClassInfo(classFileOrID))
        end
    elseif type(classFileOrID) == "string" and classFileOrID ~= "" then
        return strupper(classFileOrID)
    end
    return nil
end

local function ResolveRaceGender(gender)
    if type(gender) == "string" then
        local value = strlower(gender)
        if value == "female" or value == "f" or value == "3" then
            return "female", "FEMALE"
        elseif value == "male" or value == "m" or value == "2" then
            return "male", "MALE"
        end
    end

    if tonumber(gender) == 3 then
        return "female", "FEMALE"
    end
    return "male", "MALE"
end

local function ResolveRaceAtlasStem(raceFile)
    if type(raceFile) ~= "string" or raceFile == "" then
        return nil
    end

    local stem = strlower((raceFile:gsub("[^%w]", "")))
    if stem == "" then return nil end
    return RACE_ATLAS_STEM_OVERRIDES[stem] or stem
end

local function GetRaceIconAtlas(raceFile, atlasGender)
    if not (C_Texture and C_Texture.GetAtlasInfo) then
        return nil
    end

    local stem = ResolveRaceAtlasStem(raceFile)
    if not stem then return nil end

    local candidates = {
        "raceicon128-" .. stem .. "-" .. atlasGender,
        "raceicon-" .. stem .. "-" .. atlasGender,
    }

    for _, atlas in ipairs(candidates) do
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
        if ok and info then
            return atlas
        end
    end

    return nil
end

function Icons.GetClassIcon(classFileOrID)
    local classFile = ResolveClassFile(classFileOrID)
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if not coords then
        return nil
    end

    return {
        texture = "Interface\\TargetingFrame\\UI-Classes-Circles",
        texCoord = CopyCoord(coords),
        setId = DEFAULT_SET_ID,
        kind = "class",
        custom = false,
        classFile = classFile,
    }
end

function Icons.GetRaceIcon(raceFile, gender)
    if type(raceFile) ~= "string" or raceFile == "" then
        return nil
    end

    local atlasGender, coordGender = ResolveRaceGender(gender)
    local atlas = GetRaceIconAtlas(raceFile, atlasGender)
    if atlas then
        return {
            atlas = atlas,
            setId = DEFAULT_SET_ID,
            kind = "race",
            custom = false,
            raceFile = raceFile,
            gender = coordGender,
        }
    end

    if GetRaceAtlas then
        local ok, fallbackAtlas = pcall(GetRaceAtlas, strlower(raceFile), atlasGender, true)
        if ok and type(fallbackAtlas) == "string" and fallbackAtlas ~= "" then
            return {
                atlas = fallbackAtlas,
                setId = DEFAULT_SET_ID,
                kind = "race",
                custom = false,
                raceFile = raceFile,
                gender = coordGender,
            }
        end
    end

    local coords = (_G.RACE_ICON_TCOORDS and _G.RACE_ICON_TCOORDS[strupper(raceFile .. "_" .. coordGender)])
        or DEFAULT_RACE_ICON_TCOORDS[strupper(raceFile .. "_" .. coordGender)]
    if coords then
        return {
            texture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races",
            texCoord = CropCoord(coords, 0.08),
            setId = DEFAULT_SET_ID,
            kind = "race",
            custom = false,
            raceFile = raceFile,
            gender = coordGender,
        }
    end

    return nil
end

function Icons.ApplyIcon(texture, icon)
    if not texture or type(icon) ~= "table" then
        return false
    end

    if icon.atlas and texture.SetAtlas then
        if texture.ResetTexCoord then
            pcall(texture.ResetTexCoord, texture)
        elseif texture.SetTexCoord then
            texture:SetTexCoord(0, 1, 0, 1)
        end
        local resetByAtlas = pcall(
            texture.SetAtlas,
            texture,
            icon.atlas,
            false,
            nil,
            true
        )
        if not resetByAtlas then
            texture:SetAtlas(icon.atlas, false)
        end
        if icon.texCoord then
            texture:SetTexCoord(unpack(icon.texCoord))
        end
    elseif icon.texture ~= nil then
        texture:SetTexture(icon.texture)
        if icon.texCoord then
            texture:SetTexCoord(unpack(icon.texCoord))
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
    else
        return false
    end

    return true
end

function Icons.GetDefaultSpecAtlasCoords()
    return DEFAULT_SPEC_ATLAS_COORDS
end

Icons.RegisterIconSet({
    id = DEFAULT_SET_ID,
    name = "Blizzard",
    nameKey = "settings.appearance.icons.blizzard",
    detailsLabel = "Blizzard",
    order = 0,
})

Icons.RegisterIconScope({
    id = "ydamage_meter",
    name = "YUI伤害统计",
    nameKey = "settings.appearance.scope.ydamage_meter",
    tooltipKey = "settings.appearance.scope.ydamage_meter.tooltip",
    order = 10,
    default = true,
})

Icons.RegisterIconScope({
    id = "light_damage",
    name = "LightDamage",
    nameKey = "settings.appearance.scope.light_damage",
    tooltipKey = "settings.appearance.scope.light_damage.tooltip",
    order = 20,
    default = true,
})

Icons.RegisterIconScope({
    id = "ellesmere_damage_meters",
    name = "EllesmereUI伤害统计",
    nameKey = "settings.appearance.scope.ellesmere_damage_meters",
    tooltipKey = "settings.appearance.scope.ellesmere_damage_meters.tooltip",
    order = 25,
    default = true,
})

Icons.RegisterIconScope({
    id = "details_spec_sync",
    name = "Details专精同步",
    nameKey = "settings.appearance.scope.details_spec_sync",
    tooltipKey = "settings.appearance.scope.details_spec_sync.tooltip",
    order = 30,
    default = true,
})

Icons.RegisterIconScope({
    id = "ybar",
    name = "YUI InfoBar",
    nameKey = "settings.appearance.scope.ybar",
    tooltipKey = "settings.appearance.scope.ybar.tooltip",
    order = 40,
    default = true,
})

Icons.RegisterIconScope({
    id = "class_extra_monitor",
    name = "职业额外监控",
    nameKey = "settings.appearance.scope.class_extra_monitor",
    tooltipKey = "settings.appearance.scope.class_extra_monitor.tooltip",
    order = 45,
    default = true,
})

Icons.RegisterIconScope({
    id = "settings",
    name = "设置页面",
    nameKey = "settings.appearance.scope.settings",
    tooltipKey = "settings.appearance.scope.settings.tooltip",
    order = 50,
    default = true,
})

Legacy.Icons = Icons
Legacy.GetRaceIcon = Icons.GetRaceIcon
