do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.productEnabled then
        return
    end
end
-------------------------------------------------------------------------------
--- YUI 购物助手数据方案
--- 负责方案目录、白名单归一化与字符串导入导出。
-------------------------------------------------------------------------------

local _, addonNs = ...
local YUI = _G.YUI or addonNs
if not YUI then return end

local Profiles = {}
YUI.AuctionHelperProfiles = Profiles

Profiles.SCHEMA_VERSION = 1
Profiles.EXPORT_PREFIX = "!YUI-AH-DATA:v1:"
Profiles.MAX_TABS = 8
Profiles.VISIBLE_TABS = 4
Profiles.MAX_CATEGORIES_PER_TAB = 24
Profiles.MAX_ROWS_PER_CATEGORY = 32
Profiles.MAX_ITEMS_PER_ROW = 8
Profiles.MAX_ITEMS = 400
Profiles.OFFICIAL_ID_PREFIX = "official:"
Profiles.officialProfiles = {}
Profiles.officialById = {}

Profiles.ICON_PRESETS = {
    {
        id = "consumable",
        labelKey = "editor.icon.consumable",
        atlas = "Food",
    },
    {
        id = "gem",
        labelKey = "editor.icon.gem",
        atlas = "keyflameon-32x32",
    },
    {
        id = "enchant",
        labelKey = "editor.icon.enchant",
        atlas = "UpgradeItem-32x32",
    },
    {
        id = "crafting",
        labelKey = "editor.icon.crafting",
        atlas = "Professions-Crafting-Orders-Icon",
    },
    { id = "Lumber_Tracking", atlas = "Lumber_Tracking" },
    { id = "poi-workorders", atlas = "poi-workorders" },
    { id = "Vehicle-HammerGold-3", atlas = "Vehicle-HammerGold-3" },
    { id = "WildBattlePetCapturable", atlas = "WildBattlePetCapturable" },
    { id = "Barbershop-32x32", atlas = "Barbershop-32x32" },
    { id = "housing-decor-vendor_32", atlas = "housing-decor-vendor_32" },
    { id = "Banker", atlas = "Banker" },
    { id = "ArchBlob", atlas = "ArchBlob" },
    { id = "Repair", atlas = "Repair" },
    { id = "MagePortalAlliance", atlas = "MagePortalAlliance" },
    { id = "MagePortalHorde", atlas = "MagePortalHorde" },
    { id = "Innkeeper", atlas = "Innkeeper" },
    { id = "Profession", atlas = "Profession" },
    { id = "Soulbind-32x32", atlas = "Soulbind-32x32" },
}

local ICON_BY_ID = {}
for _, preset in ipairs(Profiles.ICON_PRESETS) do
    ICON_BY_ID[preset.id] = preset
end

local MAX_IMPORT_BYTES = 512 * 1024
local MAX_SERIALIZED_BYTES = 2 * 1024 * 1024
local PAYLOAD_KIND = "YUI_AuctionHelper_ShoppingProfile"

local function Trim(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function CopyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[CopyValue(key, seen)] = CopyValue(child, seen)
    end
    return copy
end

local function IsInteger(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value == math.floor(value)
end

local function NormalizeText(value, fallback, maxBytes)
    value = Trim(value)
    if not value or value == "" then value = fallback end
    if type(value) ~= "string" or value == "" or #value > maxBytes then
        return nil
    end
    if value:find("[%z\1-\31\127]") then return nil end
    return value
end

local function NormalizeLocaleKey(value)
    if type(value) ~= "string" or #value > 80 then return nil end
    if not value:match("^[%a][%w_%.%-]*$") then return nil end
    return value
end

local function NormalizeDisplayText(source, nameField, keyField, fallback, maxBytes)
    local name = NormalizeText(source[nameField], nil, maxBytes)
    if name then return name, nil end
    local nameKey = NormalizeLocaleKey(source[keyField])
    if nameKey then return nil, nameKey end
    if fallback then return fallback, nil end
    return nil, nil
end

local function NormalizeIDs(source)
    local ids = source.ids
    if ids == nil then ids = source.id end
    if type(ids) ~= "table" then ids = { ids } end

    local normalized = {}
    local seen = {}
    for index = 1, math.min(#ids, 12) do
        local itemID = tonumber(ids[index])
        if itemID then itemID = math.floor(itemID) end
        if IsInteger(itemID) and itemID > 0 and itemID <= 2147483647 and not seen[itemID] then
            normalized[#normalized + 1] = itemID
            seen[itemID] = true
        end
    end
    if #normalized == 0 then return nil end
    return normalized
end

local function NormalizeItem(source)
    if type(source) ~= "table" then return nil end
    local ids = NormalizeIDs(source)
    if not ids then return nil end

    local tag, tagKey = NormalizeDisplayText(source, "tag", "tagKey", "", 32)
    local shortTagKey = NormalizeLocaleKey(source.enUSShortTagKey)
    return {
        ids = ids,
        tag = tag,
        tagKey = tagKey,
        enUSShortTagKey = shortTagKey,
    }
end

local function NormalizeRows(sourceRows, budget)
    if type(sourceRows) ~= "table" then return nil end
    local rows = {}
    for rowIndex = 1, math.min(#sourceRows, Profiles.MAX_ROWS_PER_CATEGORY) do
        local sourceRow = sourceRows[rowIndex]
        if type(sourceRow) ~= "table" then return nil end
        local row = {}
        for itemIndex = 1, #sourceRow do
            if budget.count >= Profiles.MAX_ITEMS then return nil end
            local item = NormalizeItem(sourceRow[itemIndex])
            if not item then return nil end
            if #row >= Profiles.MAX_ITEMS_PER_ROW then
                rows[#rows + 1] = row
                row = {}
                if #rows >= Profiles.MAX_ROWS_PER_CATEGORY then return nil end
            end
            row[#row + 1] = item
            budget.count = budget.count + 1
        end
        if #row > 0 then rows[#rows + 1] = row end
    end
    return rows
end

local function NormalizeCategory(source, budget)
    if type(source) ~= "table" then return nil end
    local name, nameKey = NormalizeDisplayText(source, "name", "nameKey", nil, 48)
    if not name and not nameKey then return nil end
    local color = type(source.color) == "string" and source.color or source.bgColor
    color = type(color) == "string" and color:gsub("#", ""):upper() or ""
    if not color:match("^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") then
        color = "3366CC"
    end
    local rows = NormalizeRows(source.rows or {}, budget)
    if not rows then return nil end
    return {
        name = name,
        nameKey = nameKey,
        color = color,
        rows = rows,
    }
end

local function NormalizeTab(source, budget)
    if type(source) ~= "table" then return nil end
    local name, nameKey = NormalizeDisplayText(source, "name", "nameKey", nil, 36)
    if not name and not nameKey then return nil end
    local icon = ICON_BY_ID[source.icon] and source.icon or "consumable"
    local categories = {}
    local sourceCategories = source.categories or source.data or {}
    if type(sourceCategories) ~= "table" then return nil end
    for index = 1, math.min(#sourceCategories, Profiles.MAX_CATEGORIES_PER_TAB) do
        local category = NormalizeCategory(sourceCategories[index], budget)
        if not category then return nil end
        categories[#categories + 1] = category
    end
    return {
        name = name,
        nameKey = nameKey,
        icon = icon,
        categories = categories,
    }
end

function Profiles:NormalizeProfile(source, fallbackName)
    if type(source) ~= "table" then return nil, "invalid_profile" end
    local name = NormalizeText(source.name, fallbackName, 64)
    if not name then return nil, "invalid_name" end
    if type(source.tabs) ~= "table" or #source.tabs < 1 or #source.tabs > self.MAX_TABS then
        return nil, "invalid_tabs"
    end

    local normalized = { name = name, tabs = {} }
    local budget = { count = 0 }
    for index = 1, #source.tabs do
        local tab = NormalizeTab(source.tabs[index], budget)
        if not tab then return nil, "invalid_tab_data" end
        normalized.tabs[#normalized.tabs + 1] = tab
    end
    return normalized
end

function Profiles:ResolveText(entry, field, keyField, locale)
    if type(entry) ~= "table" then return "" end
    if type(entry[field]) == "string" then return entry[field] end
    local key = entry[keyField]
    if type(key) == "string" and locale then
        return locale[key] or key
    end
    return ""
end

function Profiles:GetIconPreset(iconID)
    return ICON_BY_ID[iconID] or ICON_BY_ID.consumable
end

local function BuildTemplate(self, data, tabs, fallbackName)
    if type(data) ~= "table" or type(tabs) ~= "table" then return false end
    local categoriesByKey = {}
    for _, category in ipairs(data) do
        if type(category) == "table" and type(category.key) == "string" then
            categoriesByKey[category.key] = category
        end
    end

    local iconOrder = { "consumable", "gem", "enchant", "crafting" }
    local template = { name = fallbackName or "YUI Official", tabs = {} }
    for tabIndex, sourceTab in ipairs(tabs) do
        local tab = {
            nameKey = sourceTab.nameKey,
            icon = sourceTab.icon or iconOrder[tabIndex] or "consumable",
            categories = {},
        }
        for _, categoryKey in ipairs(sourceTab.categories or {}) do
            local sourceCategory = categoriesByKey[categoryKey]
            if sourceCategory then
                tab.categories[#tab.categories + 1] = CopyValue(sourceCategory)
            end
        end
        template.tabs[#template.tabs + 1] = tab
    end

    local normalized = self:NormalizeProfile(template, template.name)
    if not normalized then return false end
    return normalized
end

function Profiles:SetOfficialProfiles(definitions)
    if type(definitions) ~= "table" or #definitions < 1 then return false end

    local profiles = {}
    local byId = {}
    for _, definition in ipairs(definitions) do
        if type(definition) ~= "table"
            or type(definition.id) ~= "string"
            or #definition.id > 64
            or not definition.id:match("^[%w][%w_%.%-]*$") then
            return false
        end
        local revision = tonumber(definition.revision)
        if not IsInteger(revision) or revision < 1 then return false end
        local nameKey = NormalizeLocaleKey(definition.nameKey)
        if definition.nameKey ~= nil and not nameKey then return false end

        local profile = BuildTemplate(
            self,
            definition.data,
            definition.tabs,
            definition.fallbackName or "YUI Official"
        )
        if not profile then return false end

        local profileID = self.OFFICIAL_ID_PREFIX .. definition.id
        if byId[profileID] then return false end
        profile.id = profileID
        profile.official = true
        profile.revision = revision
        profile.nameKey = nameKey
        profiles[#profiles + 1] = profile
        byId[profileID] = profile
    end

    self.officialProfiles = profiles
    self.officialById = byId
    self.defaultTemplate = profiles[1]
    return true
end

function Profiles:SetDefaultTemplate(data, tabs)
    return self:SetOfficialProfiles({
        {
            id = "default",
            revision = 1,
            fallbackName = "YUI Default",
            data = data,
            tabs = tabs,
        },
    })
end

function Profiles:IsOfficial(profileOrID)
    local profileID = type(profileOrID) == "table" and profileOrID.id or profileOrID
    return type(profileID) == "string" and self.officialById[profileID] ~= nil
end

function Profiles:GetProfileName(profile, locale)
    if type(profile) ~= "table" then return "" end
    if profile.official and type(profile.nameKey) == "string" and locale then
        return locale[profile.nameKey] or profile.name
    end
    return profile.name or ""
end

local function FindProfile(catalog, profileID)
    for _, profile in ipairs(catalog.profiles or {}) do
        if profile.id == profileID then return profile end
    end
    return nil
end

local function FindAvailableProfile(self, catalog, profileID)
    return self.officialById[profileID] or FindProfile(catalog, profileID)
end

local function NextProfileID(catalog)
    local nextID = math.max(1, math.floor(tonumber(catalog.nextId) or 1))
    local id
    repeat
        id = "shopping-" .. nextID
        nextID = nextID + 1
    until not FindProfile(catalog, id)
    catalog.nextId = nextID
    return id
end

local function UniqueName(catalog, requested, ignoreID)
    local used = {}
    for _, profile in ipairs(catalog.profiles) do
        if profile.id ~= ignoreID then
            used[string.lower(profile.name)] = true
        end
    end
    if not used[string.lower(requested)] then return requested end
    local base, existingSuffix = requested:match("^(.-) %((%d+)%)$")
    base = base or requested
    local suffix = existingSuffix and (tonumber(existingSuffix) + 1) or 2
    while used[string.lower(base .. " (" .. suffix .. ")")] do
        suffix = suffix + 1
    end
    return base .. " (" .. suffix .. ")"
end

function Profiles:Ensure(db, defaultName)
    if type(db) ~= "table" or not self.defaultTemplate then return nil, "not_ready" end
    local catalog = db.shoppingProfiles
    if type(catalog) ~= "table" then catalog = {} end
    catalog.version = self.SCHEMA_VERSION
    catalog.profiles = type(catalog.profiles) == "table" and catalog.profiles or {}
    catalog.byId = nil

    local valid = {}
    local seenIDs = {}
    for _, stored in ipairs(catalog.profiles) do
        if type(stored) == "table"
            and type(stored.id) == "string"
            and not self.officialById[stored.id]
            and stored.id:sub(1, #self.OFFICIAL_ID_PREFIX) ~= self.OFFICIAL_ID_PREFIX
            and not seenIDs[stored.id] then
            local profile = self:NormalizeProfile(stored, stored.name)
            if profile then
                profile.id = stored.id
                valid[#valid + 1] = profile
                seenIDs[profile.id] = true
            end
        end
    end
    catalog.profiles = valid

    if #catalog.profiles == 0 and #self.officialProfiles == 0 then
        local profile = CopyValue(self.defaultTemplate)
        profile.name = NormalizeText(defaultName, "YUI Default", 64) or "YUI Default"
        profile.id = "shopping-1"
        catalog.profiles[1] = profile
        catalog.nextId = 2
    end

    if not FindAvailableProfile(self, catalog, catalog.activeId) then
        local fallback = self.officialProfiles[1] or catalog.profiles[1]
        catalog.activeId = fallback and fallback.id or nil
    end
    db.shoppingProfiles = catalog
    return catalog
end

function Profiles:GetActive(db, defaultName)
    local catalog, code = self:Ensure(db, defaultName)
    if not catalog then return nil, code end
    return FindAvailableProfile(self, catalog, catalog.activeId), catalog
end

function Profiles:GetByID(db, profileID, defaultName)
    local catalog, code = self:Ensure(db, defaultName)
    if not catalog then return nil, code end
    local profile = FindAvailableProfile(self, catalog, profileID)
    if not profile then return nil, "profile_not_found" end
    return profile, catalog
end

function Profiles:GetAll(db, defaultName)
    local catalog, code = self:Ensure(db, defaultName)
    if not catalog then return nil, code end
    local profiles = {}
    for _, profile in ipairs(self.officialProfiles) do
        profiles[#profiles + 1] = profile
    end
    for _, profile in ipairs(catalog.profiles) do
        profiles[#profiles + 1] = profile
    end
    return profiles, catalog
end

function Profiles:GetOfficialProfiles()
    local profiles = {}
    for _, profile in ipairs(self.officialProfiles) do
        profiles[#profiles + 1] = profile
    end
    return profiles
end

function Profiles:Select(db, profileID, defaultName)
    local catalog = self:Ensure(db, defaultName)
    local profile = catalog and FindAvailableProfile(self, catalog, profileID)
    if not profile then return nil, "profile_not_found" end
    catalog.activeId = profileID
    return profile
end

function Profiles:Create(db, name, source, defaultName)
    local catalog = self:Ensure(db, defaultName)
    if not catalog then return nil, "not_ready" end
    name = NormalizeText(name, nil, 64)
    if not name then return nil, "invalid_name" end

    local template
    if source == "current" then
        template = FindAvailableProfile(self, catalog, catalog.activeId)
    elseif type(source) == "string" and self.officialById[source] then
        template = self.officialById[source]
    else
        template = self.defaultTemplate
    end
    if not template then return nil, "source_not_found" end

    local profile = CopyValue(template)
    profile.id = NextProfileID(catalog)
    profile.name = UniqueName(catalog, name)
    profile.nameKey = nil
    profile.official = nil
    profile.revision = nil
    catalog.profiles[#catalog.profiles + 1] = profile
    catalog.activeId = profile.id
    return profile
end

function Profiles:Duplicate(db, profileID, requestedName, defaultName)
    local catalog = self:Ensure(db, defaultName)
    local source = catalog and FindAvailableProfile(self, catalog, profileID)
    if not source then return nil, "profile_not_found" end
    local name = NormalizeText(requestedName, source.name .. " Copy", 64)
    if not name then return nil, "invalid_name" end
    local profile = CopyValue(source)
    profile.id = NextProfileID(catalog)
    profile.name = UniqueName(catalog, name)
    profile.nameKey = nil
    profile.official = nil
    profile.revision = nil
    catalog.profiles[#catalog.profiles + 1] = profile
    catalog.activeId = profile.id
    return profile
end

function Profiles:Rename(db, profileID, requestedName, defaultName)
    local catalog = self:Ensure(db, defaultName)
    if self.officialById[profileID] then return nil, "official_profile" end
    local profile = catalog and FindProfile(catalog, profileID)
    if not profile then return nil, "profile_not_found" end
    local name = NormalizeText(requestedName, nil, 64)
    if not name then return nil, "invalid_name" end
    profile.name = UniqueName(catalog, name, profileID)
    return profile
end

function Profiles:Delete(db, profileID, defaultName)
    local catalog = self:Ensure(db, defaultName)
    if self.officialById[profileID] then return nil, "official_profile" end
    if not catalog or not FindProfile(catalog, profileID) then return nil, "profile_not_found" end
    if #catalog.profiles <= 1 and #self.officialProfiles == 0 then return nil, "last_profile" end
    for index, profile in ipairs(catalog.profiles) do
        if profile.id == profileID then
            table.remove(catalog.profiles, index)
            break
        end
    end
    if catalog.activeId == profileID then
        local fallback = self.officialProfiles[1] or catalog.profiles[1]
        catalog.activeId = fallback and fallback.id or nil
    end
    return FindAvailableProfile(self, catalog, catalog.activeId)
end

function Profiles:Update(db, profileID, draft, defaultName)
    local catalog = self:Ensure(db, defaultName)
    if self.officialById[profileID] then return nil, "official_profile" end
    local existing = catalog and FindProfile(catalog, profileID)
    if not existing then return nil, "profile_not_found" end
    local normalized, code = self:NormalizeProfile(draft, existing.name)
    if not normalized then return nil, code end
    normalized.id = profileID
    for index, profile in ipairs(catalog.profiles) do
        if profile.id == profileID then
            catalog.profiles[index] = normalized
            break
        end
    end
    return normalized
end

local function GetSerializationLibraries()
    local libStub = _G.LibStub
    if not libStub or type(libStub.GetLibrary) ~= "function" then
        return nil, nil
    end
    local serializer = libStub:GetLibrary("AceSerializer-3.0", true)
    local deflate = libStub:GetLibrary("LibDeflate", true)
    if not serializer or not deflate then return nil, nil end
    if type(serializer.Serialize) ~= "function"
        or type(serializer.Deserialize) ~= "function"
        or type(deflate.CompressDeflate) ~= "function"
        or type(deflate.DecompressDeflate) ~= "function"
        or type(deflate.EncodeForPrint) ~= "function"
        or type(deflate.DecodeForPrint) ~= "function" then
        return nil, nil
    end
    return serializer, deflate
end

function Profiles:Export(profile)
    local normalized, code = self:NormalizeProfile(profile, profile and profile.name)
    if not normalized then return nil, code end
    local serializer, deflate = GetSerializationLibraries()
    if not serializer then return nil, "serialization_unavailable" end
    local envelope = {
        kind = PAYLOAD_KIND,
        formatVersion = self.SCHEMA_VERSION,
        profile = normalized,
    }
    local ok, serialized = pcall(serializer.Serialize, serializer, envelope)
    if not ok or type(serialized) ~= "string" then return nil, "serialize_failed" end
    local compressed
    ok, compressed = pcall(deflate.CompressDeflate, deflate, serialized)
    if not ok or type(compressed) ~= "string" then return nil, "serialize_failed" end
    local encoded
    ok, encoded = pcall(deflate.EncodeForPrint, deflate, compressed)
    if not ok or type(encoded) ~= "string" then return nil, "serialize_failed" end
    local result = self.EXPORT_PREFIX .. encoded
    if #result > MAX_IMPORT_BYTES then return nil, "payload_too_large" end
    return result
end

function Profiles:Import(db, value, defaultName)
    local catalog = self:Ensure(db, defaultName)
    value = Trim(value)
    if not catalog or not value or #value > MAX_IMPORT_BYTES then
        return nil, "invalid_import_string"
    end
    if value:sub(1, #self.EXPORT_PREFIX) ~= self.EXPORT_PREFIX then
        return nil, "invalid_import_string"
    end
    local encoded = value:sub(#self.EXPORT_PREFIX + 1)
    if encoded == "" then return nil, "invalid_import_string" end

    local serializer, deflate = GetSerializationLibraries()
    if not serializer then return nil, "serialization_unavailable" end
    local ok, compressed = pcall(deflate.DecodeForPrint, deflate, encoded)
    if not ok or type(compressed) ~= "string" then return nil, "decode_failed" end
    local serialized
    ok, serialized = pcall(deflate.DecompressDeflate, deflate, compressed, MAX_SERIALIZED_BYTES)
    if not ok or type(serialized) ~= "string" or #serialized > MAX_SERIALIZED_BYTES then
        return nil, "decode_failed"
    end
    local success, envelope
    ok, success, envelope = pcall(serializer.Deserialize, serializer, serialized)
    if not ok or success ~= true or type(envelope) ~= "table" then
        return nil, "decode_failed"
    end
    if envelope.kind ~= PAYLOAD_KIND
        or envelope.formatVersion ~= self.SCHEMA_VERSION
        or type(envelope.profile) ~= "table" then
        return nil, "invalid_payload"
    end
    local profile, code = self:NormalizeProfile(envelope.profile, envelope.profile.name)
    if not profile then return nil, code end
    profile.id = NextProfileID(catalog)
    profile.name = UniqueName(catalog, profile.name)
    catalog.profiles[#catalog.profiles + 1] = profile
    catalog.activeId = profile.id
    return profile
end

function Profiles:Copy(value)
    return CopyValue(value)
end
