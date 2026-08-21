do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - placement
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local GUI2 = YUI.GUI2 or YUI.GUI
local UIParent = P.UIParent
local DB_VERSION = P.DB_VERSION
local ANCHOR_POINTS = P.ANCHOR_POINTS
local AnchorPointDisplayText = P.AnchorPointDisplayText
local PRODUCT_ID = P.PRODUCT_ID
local Round = P.Round
local InCombat = P.InCombat
local SafeCall = P.SafeCall
local FrameName = P.FrameName
local ResolveFrameRef = P.ResolveFrameRef
local FormatAnchorTargetOption = P.FormatAnchorTargetOption
local GetBuiltinAnchorTargetValues = P.GetBuiltinAnchorTargetValues
local IsBuiltinAnchorTarget = P.IsBuiltinAnchorTarget
local ResolveBuiltinAnchorTarget = P.ResolveBuiltinAnchorTarget
local GetBuiltinAnchorPlaceholder = P.GetBuiltinAnchorPlaceholder
local HideBuiltinAnchorPlaceholder = P.HideBuiltinAnchorPlaceholder
local RefreshBuiltinAnchorPlaceholderVisibility = P.RefreshBuiltinAnchorPlaceholderVisibility
local NormalizeAnchorTargetAlias = P.NormalizeAnchorTargetAlias
local Geometry = P.Geometry
local DEFAULT_GRID_DENSITY = P.DEFAULT_GRID_DENSITY or "medium"
local GRID_DENSITY_SPACING = P.GRID_DENSITY_SPACING or {}
local MIN_VISIBLE_SIZE = P.MIN_OVERLAY_SIZE or 24
local PLACEMENT_READY = P.PLACEMENT_READY
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local PLACEMENT_UNAVAILABLE = "unavailable"
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring
local tonumber = P.tonumber
local tremove = P.tremove
local math_max = P.math_max
local math_abs = P.math_abs
local math_floor = P.math_floor
local math_ceil = P.math_ceil
local string_find = P.string_find
local string_gsub = P.string_gsub
local string_format = string.format
local BUILTIN_ANCHOR_TARGETS = P.BUILTIN_ANCHOR_TARGETS or {}
local PARTY_ANCHOR_TARGET = BUILTIN_ANCHOR_TARGETS.PARTY or "@YUI.PartyFrame"
local RAID_ANCHOR_TARGET = BUILTIN_ANCHOR_TARGETS.RAID or "@YUI.RaidFrame"

local function NormalizeAnchorTargetName(name)
    name = tostring(name or "")
    name = string_gsub(name, "^%s+", "")
    name = string_gsub(name, "%s+$", "")
    if NormalizeAnchorTargetAlias then
        name = NormalizeAnchorTargetAlias(name)
    end
    return name
end
P.NormalizeAnchorTargetName = NormalizeAnchorTargetName

local function NormalizeGridDensity(value)
    value = tostring(value or "")
    if GRID_DENSITY_SPACING[value] then return value end
    return DEFAULT_GRID_DENSITY
end
P.NormalizeGridDensity = NormalizeGridDensity

local function AddAnchorTargetOption(options, seen, value)
    local label
    if type(value) == "table" then
        label = value.label or value.title or value.text
        value = value.name or value.frameName or value.globalName or value.relative or value.frame or value
        if type(value) == "table" then value = FrameName(value) end
    end
    value = NormalizeAnchorTargetName(value)
    if type(value) ~= "string" or value == "" or seen[value] then return end
    seen[value] = true
    if type(label) == "string" and label ~= "" then
        Layout.anchorTargetLabels = Layout.anchorTargetLabels or {}
        Layout.anchorTargetLabels[value] = label
        options[#options + 1] = { text = label, selectionText = label, value = value }
    else
        options[#options + 1] = FormatAnchorTargetOption and FormatAnchorTargetOption(value) or { text = value, value = value }
    end
end

local function AddAnchorTargetOptions(options, seen, value)
    if type(value) == "string" then
        AddAnchorTargetOption(options, seen, value)
        return
    end
    if type(value) ~= "table" then return end

    local descriptorName = value.name or value.frameName or value.globalName or value.relative or value.frame
    if descriptorName then
        AddAnchorTargetOption(options, seen, value)
        return
    end

    for key, target in pairs(value) do
        if type(key) == "string" then AddAnchorTargetOption(options, seen, key) end
        if type(target) == "string" or type(target) == "table" then
            if type(target) == "table" then
                AddAnchorTargetOption(options, seen, target)
            else
                AddAnchorTargetOption(options, seen, target)
            end
        end
    end
end

local function BuildPointOptions()
    local options = {}
    for _, point in ipairs(ANCHOR_POINTS) do
        options[#options + 1] = { text = AnchorPointDisplayText(point), value = point }
    end
    return options
end
P.BuildPointOptions = BuildPointOptions

local function CopyBasicPlacement(placement)
    if type(placement) ~= "table" then return nil end
    return {
        version = placement.version or DB_VERSION,
        anchor = {
            point = placement.anchor and placement.anchor.point or "CENTER",
            relative = placement.anchor and placement.anchor.relative or "UIParent",
            relativePoint = placement.anchor and placement.anchor.relativePoint or "CENTER",
        },
        offset = {
            x = placement.offset and (tonumber(placement.offset.x) or 0) or 0,
            y = placement.offset and (tonumber(placement.offset.y) or 0) or 0,
        },
    }
end

local function CopyPlacement(placement)
    local copy = CopyBasicPlacement(placement)
    if copy and type(placement.fallback) == "table" then
        copy.fallback = CopyBasicPlacement(placement.fallback)
    end
    return copy
end
P.CopyPlacement = CopyPlacement

local function BasicPlacementsEqual(left, right)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    local leftAnchor = left.anchor or {}
    local rightAnchor = right.anchor or {}
    local leftOffset = left.offset or {}
    local rightOffset = right.offset or {}
    return left.version == right.version
        and leftAnchor.point == rightAnchor.point
        and leftAnchor.relative == rightAnchor.relative
        and leftAnchor.relativePoint == rightAnchor.relativePoint
        and (tonumber(leftOffset.x) or 0) == (tonumber(rightOffset.x) or 0)
        and (tonumber(leftOffset.y) or 0) == (tonumber(rightOffset.y) or 0)
end

local function PlacementsEqual(left, right)
    if not BasicPlacementsEqual(left, right) then return false end
    local leftFallback = left and left.fallback
    local rightFallback = right and right.fallback
    if leftFallback == nil or rightFallback == nil then
        return leftFallback == rightFallback
    end
    return BasicPlacementsEqual(leftFallback, rightFallback)
end
P.PlacementsEqual = PlacementsEqual

local function NormalizePlacement(value)
    if type(value) ~= "table" then return nil end

    if value.anchor then
        local placement = {
            version = value.version or DB_VERSION,
            anchor = {
                point = value.anchor.point or "CENTER",
                relative = value.anchor.relative or value.anchor.relativeTo or "UIParent",
                relativePoint = value.anchor.relativePoint or value.anchor.point or "CENTER",
            },
            offset = {
                x = tonumber(value.offset and value.offset.x or value.x) or 0,
                y = tonumber(value.offset and value.offset.y or value.y) or 0,
            },
        }
        if type(placement.anchor.relative) == "table" then
            placement.anchor.relative = FrameName(placement.anchor.relative)
        end
        placement.anchor.relative = NormalizeAnchorTargetName(placement.anchor.relative)
        if type(value.fallback) == "table" and value.fallback.anchor then
            placement.fallback = CopyBasicPlacement(value.fallback)
            if type(placement.fallback.anchor.relative) == "table" then
                placement.fallback.anchor.relative = FrameName(placement.fallback.anchor.relative)
            end
            placement.fallback.anchor.relative = NormalizeAnchorTargetName(placement.fallback.anchor.relative)
        end
        return placement
    end

    if value[1] then
        local relative = type(value[2]) == "table" and FrameName(value[2]) or (value[2] or "UIParent")
        return {
            version = DB_VERSION,
            anchor = {
                point = value[1] or "CENTER",
                relative = NormalizeAnchorTargetName(relative),
                relativePoint = value[3] or value[1] or "CENTER",
            },
            offset = {
                x = tonumber(value[4]) or 0,
                y = tonumber(value[5]) or 0,
            },
        }
    end

    return nil
end
P.NormalizePlacement = NormalizePlacement

Layout.groupAnchorEntries = Layout.groupAnchorEntries or {}
Layout.groupAnchorKindCounts = Layout.groupAnchorKindCounts or { party = 0, raid = 0 }

local function PlacementGroupAnchorKind(placement)
    local relative = placement and placement.anchor and placement.anchor.relative
    if relative == PARTY_ANCHOR_TARGET then return "party" end
    if relative == RAID_ANCHOR_TARGET then return "raid" end
    return nil
end

local function UpdateGroupAnchorIndex(entry, placement)
    if not entry then return nil end
    local kind = PlacementGroupAnchorKind(placement)
    local previous = entry.groupAnchorKind
    local entries = Layout.groupAnchorEntries
    local counts = Layout.groupAnchorKindCounts
    if previous == kind then
        if kind then entries[entry.id] = entry end
        return kind
    end
    if previous then
        entries[entry.id] = nil
        counts[previous] = math_max(0, (counts[previous] or 0) - 1)
    end
    entry.groupAnchorKind = kind
    if kind then
        entries[entry.id] = entry
        counts[kind] = (counts[kind] or 0) + 1
    end
    return kind
end
P.UpdateGroupAnchorIndex = UpdateGroupAnchorIndex

local function RemoveGroupAnchorIndex(entry)
    if not entry then return end
    local kind = entry.groupAnchorKind
    if kind then
        Layout.groupAnchorEntries[entry.id] = nil
        Layout.groupAnchorKindCounts[kind] = math_max(
            0,
            (Layout.groupAnchorKindCounts[kind] or 0) - 1
        )
        entry.groupAnchorKind = nil
    end
end
P.RemoveGroupAnchorIndex = RemoveGroupAnchorIndex

local function DefaultPlacement()
    return {
        version = DB_VERSION,
        anchor = {
            point = "CENTER",
            relative = "UIParent",
            relativePoint = "CENTER",
        },
        offset = { x = 0, y = 0 },
    }
end
P.DefaultPlacement = DefaultPlacement

local function ResolveSpecValue(entry, key, defaultValue)
    local spec = entry and entry.spec
    local value = spec and spec[key]
    if type(value) == "function" then
        local ok, result = SafeCall("Layout:" .. key .. ":" .. tostring(entry.id), value, entry.frame, entry, Layout)
        if ok then return result end
        return defaultValue
    end
    if value == nil then return defaultValue end
    return value
end
P.ResolveSpecValue = ResolveSpecValue

local function ResolveDefaultPlacement(entry)
    local spec = entry and entry.spec
    local raw = spec and spec.defaultPlacement
    if type(raw) == "function" then
        local ok, value = SafeCall("Layout:defaultPlacement:" .. tostring(entry.id), raw, entry.frame, entry, Layout)
        if ok then raw = value end
    end
    return NormalizePlacement(raw) or DefaultPlacement()
end
P.ResolveDefaultPlacement = ResolveDefaultPlacement

local function AnchorTargetValueMatches(value, name)
    if type(value) == "string" then
        return NormalizeAnchorTargetName(value) == name
    end
    if type(value) ~= "table" then return false end
    if AnchorTargetValueMatches(value.name, name) then return true end
    if AnchorTargetValueMatches(value.frameName, name) then return true end
    if AnchorTargetValueMatches(value.globalName, name) then return true end
    if AnchorTargetValueMatches(value.relative, name) then return true end
    if AnchorTargetValueMatches(value.frame, name) then return true end
    return false
end

local function AnchorTargetListContains(value, name)
    if AnchorTargetValueMatches(value, name) then return true end
    if type(value) ~= "table" then return false end
    for key, target in pairs(value) do
        if type(key) == "string" and NormalizeAnchorTargetName(key) == name then return true end
        if AnchorTargetValueMatches(target, name) then return true end
    end
    return false
end

local function IsAnchorTargetDeclared(entry, name)
    name = NormalizeAnchorTargetName(name)
    if name == "" or name == "UIParent" then return true end
    if IsBuiltinAnchorTarget and IsBuiltinAnchorTarget(name) then return true end
    if not entry then return false end
    if ResolveSpecValue(entry, "allowMissingAnchorTargets", false) == true then return true end
    return AnchorTargetListContains(ResolveSpecValue(entry, "anchorTargets", nil), name)
        or AnchorTargetListContains(ResolveSpecValue(entry, "lateAnchorTargets", nil), name)
end
P.IsAnchorTargetDeclared = IsAnchorTargetDeclared

local function IsStrictAnchorTargetAllowed(entry, name)
    if ResolveSpecValue(entry, "strictAnchorTargets", false) ~= true then
        return true
    end
    name = NormalizeAnchorTargetName(name)
    if name == "" or name == "UIParent" then return true end
    return AnchorTargetListContains(ResolveSpecValue(entry, "anchorTargets", nil), name)
        or AnchorTargetListContains(ResolveSpecValue(entry, "lateAnchorTargets", nil), name)
end
P.IsStrictAnchorTargetAllowed = IsStrictAnchorTargetAllowed

local function EnsureDB()
    local profile
    if YUI.DB and YUI.DB.GetProfile then
        profile = YUI.DB:GetProfile(PRODUCT_ID)
    end
    if type(profile) ~= "table" then
        profile = YUI.db
    end
    if type(profile) ~= "table" then return nil end

    if type(profile.layout) ~= "table" then
        profile.layout = {}
    end
    local db = profile.layout
    local previousVersion = tonumber(db.version) or 0
    if type(db.frames) ~= "table" then db.frames = {} end
    if previousVersion < 2 then
        for _, placement in pairs(db.frames) do
            if type(placement) == "table" then
                placement.size = nil
                placement.width = nil
                placement.height = nil
            end
        end
    end
    db.version = DB_VERSION
    if type(db.options) ~= "table" then db.options = {} end
    if type(db.anchorPlaceholders) ~= "table" then db.anchorPlaceholders = {} end
    if db.options.snap == nil then db.options.snap = true end
    if db.options.showGrid == nil then db.options.showGrid = false end
    db.options.gridDensity = NormalizeGridDensity(db.options.gridDensity)
    if db.options.locked == nil then db.options.locked = false end
    return db
end
P.EnsureDB = EnsureDB

local function GetOptions()
    local db = EnsureDB()
    if db and type(db.options) == "table" then return db.options end
    return { snap = true, showGrid = false, gridDensity = DEFAULT_GRID_DENSITY, locked = false }
end
P.GetOptions = GetOptions

local function SavePlacement(id, placement)
    local db = EnsureDB()
    if not db then return end
    db.frames[id] = CopyPlacement(placement)
end
P.SavePlacement = SavePlacement

local function ClearSavedPlacement(id)
    local db = EnsureDB()
    if not db or type(db.frames) ~= "table" then return false end
    db.frames[id] = nil
    return true
end
P.ClearSavedPlacement = ClearSavedPlacement

local function GetSavedPlacement(id)
    local db = EnsureDB()
    return db and NormalizePlacement(db.frames[id]) or nil
end
P.GetSavedPlacement = GetSavedPlacement

local function BuildAnchorTargetOptions(entry)
    local options = {}
    local seen = {}
    AddAnchorTargetOption(options, seen, "UIParent")

    if ResolveSpecValue(entry, "strictAnchorTargets", false) ~= true then
        local placement = entry and (GetSavedPlacement(entry.id) or ResolveDefaultPlacement(entry))
        local currentRelative = placement and placement.anchor and placement.anchor.relative
        AddAnchorTargetOption(options, seen, currentRelative)

        local builtinValues = GetBuiltinAnchorTargetValues and GetBuiltinAnchorTargetValues()
        if type(builtinValues) == "table" then
            for _, value in ipairs(builtinValues) do
                AddAnchorTargetOption(options, seen, value)
            end
        end
    end

    AddAnchorTargetOptions(options, seen, entry and ResolveSpecValue(entry, "anchorTargets", nil))
    AddAnchorTargetOptions(options, seen, entry and ResolveSpecValue(entry, "lateAnchorTargets", nil))

    return options
end
P.BuildAnchorTargetOptions = BuildAnchorTargetOptions

local function ResolveEntryFrame(entry)
    if not entry then return nil end
    if entry.frame then return entry.frame end

    local spec = entry.spec or {}
    local frame = spec.frame
    if type(frame) == "string" then
        frame = _G[frame]
    end
    if not frame and type(spec.createFrame) == "function" then
        local ok, result = SafeCall("Layout:createFrame:" .. tostring(entry.id), spec.createFrame, entry, Layout)
        if ok then frame = result end
    end
    if frame then
        entry.frame = frame
    end
    return entry.frame
end
P.ResolveEntryFrame = ResolveEntryFrame

local function ClearPendingPlacementCommit(entry)
    if not entry then return end
    entry.pendingPlacementCommitReason = nil
end

local function NotifyPlacementCommitted(entry, placement, reason, frame)
    local callback = entry and entry.spec and entry.spec.onPlacementCommitted
    if type(callback) ~= "function" then return false end
    placement = CopyPlacement(placement)
    if not placement then return false end
    local ok, result, detail = SafeCall(
        "Layout:onPlacementCommitted:" .. tostring(entry.id),
        callback,
        frame or ResolveEntryFrame(entry),
        placement,
        entry,
        Layout,
        reason or "commit"
    )
    if not ok then
        entry.placementCommitErrorReason = result
        return false
    end
    if result == false then
        entry.placementCommitErrorReason = detail or "callback-rejected"
        return false
    end
    entry.placementCommitErrorReason = nil
    return true
end

local function CompletePendingPlacementCommit(entry, frame)
    if not entry
        or entry.placementState ~= PLACEMENT_READY
        or entry.combatDeferredPlacement ~= nil
        or entry.pendingPlacementCommitReason == nil then
        return false
    end
    local reason = entry.pendingPlacementCommitReason
    ClearPendingPlacementCommit(entry)
    local placement = GetSavedPlacement(entry.id)
    if not placement then return false end
    return NotifyPlacementCommitted(entry, placement, reason, frame)
end

local function EntryFrameName(entry)
    local frame = ResolveEntryFrame(entry)
    if frame == UIParent then return "UIParent" end
    if frame and frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then return name end
    end
    return nil
end
P.EntryFrameName = EntryFrameName

local function FindEntryByFrameName(name)
    name = NormalizeAnchorTargetName(name)
    if name == "" or name == "UIParent" then return nil end
    for _, id in ipairs(Layout.order) do
        local entry = Layout.frames[id]
        if entry and EntryFrameName(entry) == name then
            return entry
        end
    end
    return nil
end
P.FindEntryByFrameName = FindEntryByFrameName

local function IsAnchorTargetAvailable(entry)
    return not entry or entry.anchorTargetAvailable ~= false
end
P.IsAnchorTargetAvailable = IsAnchorTargetAvailable

local function WouldCreateAnchorCycle(sourceId, targetName)
    targetName = NormalizeAnchorTargetName(targetName)
    if targetName == "" or targetName == "UIParent" then return false end

    local sourceEntry = Layout.frames[sourceId]
    if not sourceEntry then return false end
    local sourceName = EntryFrameName(sourceEntry)
    if sourceName and targetName == sourceName then return true end

    local seen = {}
    local currentName = targetName
    while currentName and currentName ~= "" and currentName ~= "UIParent" do
        if sourceName and currentName == sourceName then return true end
        if seen[currentName] then return false end
        seen[currentName] = true

        local currentEntry = FindEntryByFrameName(currentName)
        if not currentEntry then return false end
        if currentEntry.id == sourceId then return true end

        local placement = GetSavedPlacement(currentEntry.id) or ResolveDefaultPlacement(currentEntry)
        currentName = placement and placement.anchor and placement.anchor.relative
        currentName = currentName and NormalizeAnchorTargetName(currentName) or nil
    end
    return false
end
P.WouldCreateAnchorCycle = WouldCreateAnchorCycle

local function IsUsableAnchorFrame(frame)
    if not frame then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return frame.GetObjectType or frame.IsObjectType or frame.GetLeft
end

local function ResolveAnchorFrame(entry, ref, sourceFrame, allowPending)
    if ref == nil or ref == "" or ref == "UIParent" then
        return UIParent, PLACEMENT_READY, "UIParent"
    end
    if type(ref) == "table" then
        if ref == sourceFrame then return nil, "self", FrameName(ref) end
        return ref, PLACEMENT_READY, FrameName(ref)
    end
    if type(ref) ~= "string" then
        return nil, "invalid", NormalizeAnchorTargetName(ref)
    end

    local name = NormalizeAnchorTargetName(ref)
    if name == "" or name == "UIParent" then
        return UIParent, PLACEMENT_READY, "UIParent"
    end

    local targetEntry = FindEntryByFrameName(name)
    if targetEntry and not IsAnchorTargetAvailable(targetEntry) then
        return nil, PLACEMENT_UNAVAILABLE, name
    end

    if IsBuiltinAnchorTarget and IsBuiltinAnchorTarget(name) then
        local builtinFrame = ResolveBuiltinAnchorTarget and ResolveBuiltinAnchorTarget(name)
        if IsUsableAnchorFrame(builtinFrame) then
            if HideBuiltinAnchorPlaceholder then HideBuiltinAnchorPlaceholder(name) end
            if builtinFrame == sourceFrame then return nil, "self", name end
            return builtinFrame, PLACEMENT_READY, name
        end
        local placeholder = GetBuiltinAnchorPlaceholder and GetBuiltinAnchorPlaceholder(name)
        if IsUsableAnchorFrame(placeholder) then
            if placeholder == sourceFrame then return nil, "self", name end
            return placeholder, PLACEMENT_SIMULATED, name
        end
        if allowPending == true or allowPending == "declared" then
            return nil, PLACEMENT_PENDING, name
        end
        return nil, "invalid", name
    end

    local frame = _G[name]
    if IsUsableAnchorFrame(frame) then
        if frame == sourceFrame then return nil, "self", name end
        return frame, PLACEMENT_READY, name
    end

    if allowPending == true or (allowPending == "declared" and IsAnchorTargetDeclared(entry, name)) then
        return nil, PLACEMENT_PENDING, name
    end
    return nil, "invalid", name
end
P.ResolveAnchorFrame = ResolveAnchorFrame

local function ReadFrameRect(frame)
    if not frame then return nil end
    local left = frame.GetLeft and frame:GetLeft() or nil
    local bottom = frame.GetBottom and frame:GetBottom() or nil
    local width = frame.GetWidth and tonumber(frame:GetWidth()) or nil
    local height = frame.GetHeight and tonumber(frame:GetHeight()) or nil
    if frame == UIParent then
        left = left or 0
        bottom = bottom or 0
    end
    if left == nil or bottom == nil or not width or not height or width <= 0 or height <= 0 then
        return nil
    end
    return left, bottom, width, height
end

local function GetPlacementFrameSize(entry, frame)
    local width = frame and frame.GetWidth and tonumber(frame:GetWidth()) or nil
    local height = frame and frame.GetHeight and tonumber(frame:GetHeight()) or nil
    if not width or width <= 0 then
        width = tonumber(ResolveSpecValue(entry, "minWidth", MIN_VISIBLE_SIZE)) or MIN_VISIBLE_SIZE
    end
    if not height or height <= 0 then
        height = tonumber(ResolveSpecValue(entry, "minHeight", MIN_VISIBLE_SIZE)) or MIN_VISIBLE_SIZE
    end
    return math_max(width, 1), math_max(height, 1)
end

local function ResolveRegisteredBounds(entry, frame, preferredKey)
    local spec = entry and entry.spec or {}
    local callback = type(spec[preferredKey]) == "function" and spec[preferredKey] or nil
    local callbackKey = preferredKey
    if not callback and preferredKey ~= "getMoverBounds" and type(spec.getMoverBounds) == "function" then
        callback = spec.getMoverBounds
        callbackKey = "getMoverBounds"
    end

    local width
    local height
    local offsetX = 0
    local offsetY = 0
    if callback then
        local ok, value, valueHeight, valueOffsetX, valueOffsetY = SafeCall(
            "Layout:" .. callbackKey .. ":" .. tostring(entry.id),
            callback,
            frame,
            entry,
            Layout
        )
        if ok then
            if type(value) == "table" then
                width = tonumber(value.width)
                height = tonumber(value.height)
                offsetX = tonumber(value.offsetX or value.x) or 0
                offsetY = tonumber(value.offsetY or value.y) or 0
            else
                width = tonumber(value)
                height = tonumber(valueHeight)
                offsetX = tonumber(valueOffsetX) or 0
                offsetY = tonumber(valueOffsetY) or 0
            end
        end
    end

    width = width or (frame and frame.GetWidth and tonumber(frame:GetWidth())) or 0
    height = height or (frame and frame.GetHeight and tonumber(frame:GetHeight())) or 0
    if spec.exactMoverBounds == true then
        width = math_max(width, 1)
        height = math_max(height, 1)
    else
        width = math_max(width, tonumber(spec.minWidth) or MIN_VISIBLE_SIZE, MIN_VISIBLE_SIZE)
        height = math_max(height, tonumber(spec.minHeight) or MIN_VISIBLE_SIZE, MIN_VISIBLE_SIZE)
    end
    return width, height, offsetX, offsetY
end

local function ResolveMoverBounds(entry, frame)
    return ResolveRegisteredBounds(entry, frame, "getMoverBounds")
end
P.ResolveMoverBounds = ResolveMoverBounds

local function ResolveClampBounds(entry, frame)
    return ResolveRegisteredBounds(entry, frame, "getClampBounds")
end
P.ResolveClampBounds = ResolveClampBounds

local function RoundClampDelta(value)
    if value > 0 then return math_ceil(value) end
    if value < 0 then return math_floor(value) end
    return 0
end

local function ClampPlacementToScreen(entry, placement)
    placement = NormalizePlacement(placement)
    if not entry or not placement or ResolveSpecValue(entry, "allowOffscreen", false) == true then
        return placement, false
    end
    if not (Geometry and Geometry.ComputeAnchoredRect) then return placement, false end

    local frame = ResolveEntryFrame(entry)
    local anchor = placement.anchor
    if not frame or not anchor then return placement, false end

    local relativeFrame, status = ResolveAnchorFrame(entry, anchor.relative, frame, true)
    if status == PLACEMENT_PENDING then return placement, false end
    if status == "self" or relativeFrame == frame then
        relativeFrame = UIParent
        status = PLACEMENT_READY
    end
    if (status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED) or not relativeFrame then
        return placement, false
    end

    local targetLeft, targetBottom, targetWidth, targetHeight = ReadFrameRect(relativeFrame)
    local screenLeft, screenBottom, screenWidth, screenHeight = ReadFrameRect(UIParent)
    if targetLeft == nil or screenLeft == nil then return placement, false end

    local sourceWidth, sourceHeight = GetPlacementFrameSize(entry, frame)
    local left, bottom, right, top = Geometry.ComputeAnchoredRect(
        sourceWidth,
        sourceHeight,
        anchor.point or "CENTER",
        targetLeft,
        targetBottom,
        targetWidth,
        targetHeight,
        anchor.relativePoint or anchor.point or "CENTER",
        placement.offset and placement.offset.x or 0,
        placement.offset and placement.offset.y or 0
    )
    local boundsWidth, boundsHeight, boundsOffsetX, boundsOffsetY = ResolveClampBounds(entry, frame)
    local boundsCenterX = (left + right) * 0.5 + boundsOffsetX
    local boundsCenterY = (bottom + top) * 0.5 + boundsOffsetY
    local boundsLeft = boundsCenterX - boundsWidth * 0.5
    local boundsRight = boundsCenterX + boundsWidth * 0.5
    local boundsBottom = boundsCenterY - boundsHeight * 0.5
    local boundsTop = boundsCenterY + boundsHeight * 0.5
    local screenRight = screenLeft + screenWidth
    local screenTop = screenBottom + screenHeight
    local shiftX = 0
    local shiftY = 0

    if boundsWidth > screenWidth then
        shiftX = (screenLeft + screenRight) * 0.5 - boundsCenterX
    elseif boundsLeft < screenLeft then
        shiftX = screenLeft - boundsLeft
    elseif boundsRight > screenRight then
        shiftX = screenRight - boundsRight
    end
    if boundsHeight > screenHeight then
        shiftY = (screenBottom + screenTop) * 0.5 - boundsCenterY
    elseif boundsBottom < screenBottom then
        shiftY = screenBottom - boundsBottom
    elseif boundsTop > screenTop then
        shiftY = screenTop - boundsTop
    end

    shiftX = RoundClampDelta(shiftX)
    shiftY = RoundClampDelta(shiftY)
    if shiftX == 0 and shiftY == 0 then return placement, false end

    local clamped = CopyPlacement(placement)
    clamped.offset.x = Round((clamped.offset.x or 0) + shiftX)
    clamped.offset.y = Round((clamped.offset.y or 0) + shiftY)
    return clamped, true
end
P.ClampPlacementToScreen = ClampPlacementToScreen

local function EvaluatePlacementVisibility(entry, placement)
    if not entry or ResolveSpecValue(entry, "allowOffscreen", false) == true then return true end
    if not (Geometry and Geometry.ComputeAnchoredRect and Geometry.HasMinimumVisibleArea) then return nil, "unavailable" end

    placement = NormalizePlacement(placement)
    local frame = ResolveEntryFrame(entry)
    local anchor = placement and placement.anchor
    if not frame or not anchor then return nil, "unavailable" end

    local relativeFrame, status = ResolveAnchorFrame(entry, anchor.relative, frame, true)
    if status == PLACEMENT_PENDING then return nil, "pending" end
    if status == "self" or relativeFrame == frame then
        relativeFrame = UIParent
        status = PLACEMENT_READY
    end
    if (status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED) or not relativeFrame then
        return nil, "unavailable"
    end

    local targetLeft, targetBottom, targetWidth, targetHeight = ReadFrameRect(relativeFrame)
    local screenLeft, screenBottom, screenWidth, screenHeight = ReadFrameRect(UIParent)
    if targetLeft == nil or screenLeft == nil then return nil, "unavailable" end

    local sourceWidth, sourceHeight = GetPlacementFrameSize(entry, frame)
    local left, bottom, right, top = Geometry.ComputeAnchoredRect(
        sourceWidth,
        sourceHeight,
        anchor.point or "CENTER",
        targetLeft,
        targetBottom,
        targetWidth,
        targetHeight,
        anchor.relativePoint or anchor.point or "CENTER",
        placement.offset and placement.offset.x or 0,
        placement.offset and placement.offset.y or 0
    )
    local visible = Geometry.HasMinimumVisibleArea(
        left,
        bottom,
        right,
        top,
        screenLeft,
        screenBottom,
        screenLeft + screenWidth,
        screenBottom + screenHeight,
        MIN_VISIBLE_SIZE
    )
    return visible, visible and nil or "offscreen"
end
P.EvaluatePlacementVisibility = EvaluatePlacementVisibility

local function ResolveVisiblePlacement(entry, placement)
    placement = NormalizePlacement(placement) or ResolveDefaultPlacement(entry)
    local clampedPlacement, clamped = ClampPlacementToScreen(entry, placement)
    placement = clampedPlacement
    local visible, reason = EvaluatePlacementVisibility(entry, placement)
    if visible ~= false or reason ~= "offscreen" then
        return placement, clamped
    end

    local fallback = ResolveDefaultPlacement(entry)
    local fallbackVisible = EvaluatePlacementVisibility(entry, fallback)
    if fallbackVisible ~= true then
        fallback = DefaultPlacement()
    end
    return ClampPlacementToScreen(entry, fallback), true
end

local function NotifyOffscreenRecovery(entry)
    if not entry or entry.offscreenRecoveryNotified then return end
    entry.offscreenRecoveryNotified = true
    if P.Print and P.L then
        P.Print(string_format(P.L("layout.message.offscreen_recovered"), entry.spec.title or entry.id))
    end
end

local function EvaluateAnchorTargetCandidate(sourceId, target)
    local sourceEntry = Layout.frames[sourceId]
    if not sourceEntry then return false, nil, "layout.position.anchor_unavailable" end

    local sourceFrame = ResolveEntryFrame(sourceEntry)
    local name
    if type(target) == "table" then
        if target.id and target.spec then
            name = EntryFrameName(target)
        else
            name = FrameName(target)
        end
    else
        name = target
    end

    name = NormalizeAnchorTargetName(name)
    if name == "" then
        return false, name, "layout.position.invalid_anchor_target"
    end
    if not IsStrictAnchorTargetAllowed(sourceEntry, name) then
        return false, name, "layout.position.invalid_anchor_target"
    end

    local frame, status, resolvedName = ResolveAnchorFrame(sourceEntry, name, sourceFrame, "declared")
    local normalized = NormalizeAnchorTargetName(resolvedName or name)
    if status == "self" or (frame and frame == sourceFrame) then
        return false, normalized, "layout.position.anchor_self", frame, status
    end
    if status ~= PLACEMENT_PENDING and not frame then
        local reason = status == "invalid" and "layout.position.invalid_anchor_target" or "layout.position.anchor_unavailable"
        return false, normalized, reason, frame, status
    end
    if WouldCreateAnchorCycle(sourceId, normalized) then
        return false, normalized, "layout.position.anchor_cycle", frame, status
    end

    return true, normalized, nil, frame, status
end
P.EvaluateAnchorTargetCandidate = EvaluateAnchorTargetCandidate

function Layout:WouldCreateAnchorCycle(sourceId, targetName)
    return WouldCreateAnchorCycle(sourceId, targetName)
end

local function PointHas(point, token)
    return string_find(point or "", token, 1, true) ~= nil
end

local function PointCoordinates(left, bottom, width, height, point)
    local x
    if PointHas(point, "LEFT") then
        x = left
    elseif PointHas(point, "RIGHT") then
        x = left + width
    else
        x = left + width / 2
    end

    local y
    if PointHas(point, "BOTTOM") then
        y = bottom
    elseif PointHas(point, "TOP") then
        y = bottom + height
    else
        y = bottom + height / 2
    end
    return x, y
end
P.PointCoordinates = PointCoordinates

local function PickPoint(centerX, centerY)
    local parentWidth = UIParent:GetWidth() or 0
    local parentHeight = UIParent:GetHeight() or 0
    local h = ""
    local v = ""

    if centerX < parentWidth * 0.33 then
        h = "LEFT"
    elseif centerX > parentWidth * 0.67 then
        h = "RIGHT"
    end

    if centerY < parentHeight * 0.33 then
        v = "BOTTOM"
    elseif centerY > parentHeight * 0.67 then
        v = "TOP"
    end

    if v ~= "" and h ~= "" then return v .. h end
    if v ~= "" then return v end
    if h ~= "" then return h end
    return "CENTER"
end

local function CaptureGeneric(frame, entry, exact)
    if not frame or not frame.GetLeft then return DefaultPlacement() end
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if not left or not bottom then return DefaultPlacement() end
    left = left - (entry and entry.pixelOriginCorrectionX or 0)
    bottom = bottom - (entry and entry.pixelOriginCorrectionY or 0)

    local centerX = left + width / 2
    local centerY = bottom + height / 2
    local point = PickPoint(centerX, centerY)
    local frameX, frameY = PointCoordinates(left, bottom, width, height, point)
    local parentX, parentY = PointCoordinates(0, 0, UIParent:GetWidth() or 0, UIParent:GetHeight() or 0, point)

    return {
        version = DB_VERSION,
        anchor = {
            point = point,
            relative = "UIParent",
            relativePoint = point,
        },
        offset = {
            x = exact and (frameX - parentX) or Round(frameX - parentX),
            y = exact and (frameY - parentY) or Round(frameY - parentY),
        },
    }
end
P.CaptureGeneric = CaptureGeneric

local function CaptureRelativePlacement(entry, sourceFrame, basePlacement)
    local frame = sourceFrame or ResolveEntryFrame(entry)
    local placement = NormalizePlacement(basePlacement) or (entry and (GetSavedPlacement(entry.id) or ResolveDefaultPlacement(entry))) or nil
    if not frame or not frame.GetLeft or not placement or not placement.anchor then
        return nil
    end

    local anchor = placement.anchor
    local point = anchor.point or "CENTER"
    local relativePoint = anchor.relativePoint or point
    local relative = anchor.relative or "UIParent"
    local relativeFrame, status = ResolveAnchorFrame(entry, relative, frame, false)
    if (status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED) or not relativeFrame or relativeFrame == frame or not relativeFrame.GetWidth then
        return nil
    end

    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if not left or not bottom then return nil end

    local relativeLeft = relativeFrame:GetLeft()
    local relativeBottom = relativeFrame:GetBottom()
    local relativeWidth = relativeFrame:GetWidth() or 0
    local relativeHeight = relativeFrame:GetHeight() or 0
    if relativeFrame == UIParent then
        relativeLeft = relativeLeft or 0
        relativeBottom = relativeBottom or 0
    end
    if not relativeLeft or not relativeBottom then return nil end

    local frameX, frameY = PointCoordinates(left, bottom, width, height, point)
    frameX = frameX - (entry and entry.pixelOriginCorrectionX or 0)
    frameY = frameY - (entry and entry.pixelOriginCorrectionY or 0)
    local targetX, targetY = PointCoordinates(relativeLeft, relativeBottom, relativeWidth, relativeHeight, relativePoint)
    local captured = CopyPlacement(placement) or DefaultPlacement()
    captured.version = DB_VERSION
    captured.anchor = {
        point = point,
        relative = relative,
        relativePoint = relativePoint,
    }
    captured.offset = {
        x = Round(frameX - targetX),
        y = Round(frameY - targetY),
    }
    captured.fallback = CaptureGeneric(sourceFrame or frame, entry)
    return captured
end
P.CaptureRelativePlacement = CaptureRelativePlacement

local function CapturePlacement(entry, sourceFrame)
    local frame = ResolveEntryFrame(entry)
    local spec = entry and entry.spec or {}
    local basePlacement = entry and (GetSavedPlacement(entry.id) or ResolveDefaultPlacement(entry)) or nil
    local baseAnchor = basePlacement and basePlacement.anchor
    if baseAnchor then
        local _, status = ResolveAnchorFrame(entry, baseAnchor.relative, frame, false)
        if status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED then
            return CopyPlacement(basePlacement)
        end
    end
    if type(spec.capturePlacement) == "function" then
        local ok, value = SafeCall("Layout:capturePlacement:" .. tostring(entry.id), spec.capturePlacement, frame, sourceFrame or frame, entry, Layout)
        local placement = ok and NormalizePlacement(value) or nil
        if placement then return placement end
    end
    return CaptureRelativePlacement(entry, sourceFrame or frame)
        or CaptureGeneric(sourceFrame or frame, entry)
end
P.CapturePlacement = CapturePlacement

local function RestorePendingVisibility(entry, frame)
    if entry.pendingAnchorWasShown and frame and frame.Show then
        frame:Show()
    end
end

local function ClearCombatDeferred(entry)
    if not entry then return end
    entry.combatDeferredPlacement = nil
    if Layout.combatDeferredPlacements then Layout.combatDeferredPlacements[entry.id] = nil end
end

local function IsCombatPlacementProtected(entry, frame)
    if ResolveSpecValue(entry, "combatProtected", false) == true then return true end
    return frame and frame.IsProtected and frame:IsProtected() == true
end

local function SetPlacementCombatDeferred(entry, placement)
    if not entry then return false end
    entry.combatDeferredPlacement = CopyPlacement(placement)
    if Layout.combatDeferredPlacements then Layout.combatDeferredPlacements[entry.id] = true end
    return false
end

local function SetPlacementReady(entry, frame)
    local wasPending = entry.placementState == PLACEMENT_PENDING
    entry.placementState = PLACEMENT_READY
    entry.pendingAnchor = nil
    entry.pendingPlacement = nil
    entry.pendingAnchorWasShown = nil
    entry.simulatedAnchorWasShown = nil
    entry.fallbackPlacement = nil
    ClearCombatDeferred(entry)
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = nil end
    if wasPending then RestorePendingVisibility(entry, frame) end
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
end

local function SetPlacementPending(entry, frame, placement, anchorName, deferOverlay)
    local isNewPending = entry.placementState ~= PLACEMENT_PENDING or entry.pendingAnchor ~= anchorName
    local wasSimulated = entry.placementState == PLACEMENT_SIMULATED
    local simulatedWasShown = entry.simulatedAnchorWasShown
    entry.placementState = PLACEMENT_PENDING
    entry.pendingAnchor = anchorName
    entry.pendingPlacement = CopyPlacement(placement)
    entry.fallbackPlacement = nil
    ClearCombatDeferred(entry)
    if isNewPending and wasSimulated then
        entry.pendingAnchorWasShown = simulatedWasShown == true
    elseif isNewPending and frame and frame.IsShown then
        entry.pendingAnchorWasShown = frame:IsShown()
    end
    entry.simulatedAnchorWasShown = nil
    if frame and frame.Hide then frame:Hide() end
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = true end
    if P.QueuePendingAnchorRetry then P.QueuePendingAnchorRetry(entry.id, isNewPending) end
    if not deferOverlay then Layout:UpdateOverlay(entry) end
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
    return false
end

local function SetPlacementFallback(entry, frame, fallbackPlacement, pendingPlacement, anchorName)
    entry.placementState = PLACEMENT_FALLBACK
    entry.pendingAnchor = anchorName
    entry.pendingPlacement = CopyPlacement(pendingPlacement)
    entry.simulatedAnchorWasShown = nil
    entry.fallbackPlacement = CopyPlacement(fallbackPlacement)
    ClearCombatDeferred(entry)
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = true end
    RestorePendingVisibility(entry, frame)
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
end

local function SetPlacementSimulated(entry, frame, placement, anchorName)
    local isNewSimulated = entry.placementState ~= PLACEMENT_SIMULATED or entry.pendingAnchor ~= anchorName
    local wasShown = entry.pendingAnchorWasShown
    if wasShown == nil and frame and frame.IsShown then
        wasShown = frame:IsShown()
    end
    entry.placementState = PLACEMENT_SIMULATED
    entry.pendingAnchor = anchorName
    entry.pendingPlacement = CopyPlacement(placement)
    entry.pendingAnchorWasShown = nil
    entry.simulatedAnchorWasShown = wasShown == true
    entry.fallbackPlacement = nil
    ClearCombatDeferred(entry)
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = true end
    if frame and frame.Show then frame:Show() end
    if P.QueuePendingAnchorRetry then P.QueuePendingAnchorRetry(entry.id, isNewSimulated) end
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
end

local function ResolveFallbackPlacement(entry, frame, pendingPlacement)
    local fallback = NormalizePlacement(pendingPlacement and pendingPlacement.fallback)
        or NormalizePlacement(ResolveSpecValue(entry, "fallbackPlacement", nil))
        or ResolveDefaultPlacement(entry)
    local _, status = ResolveAnchorFrame(entry, fallback and fallback.anchor and fallback.anchor.relative, frame, false)
    if status ~= PLACEMENT_READY then
        fallback = DefaultPlacement()
    end
    return fallback
end

local function ClearPixelOriginCorrection(entry)
    entry.pixelOriginCorrectionX = nil
    entry.pixelOriginCorrectionY = nil
end

local function ApplyPixelOriginAlignment(
    entry,
    frame,
    anchor,
    relativeFrame,
    placement
)
    if ResolveSpecValue(entry, "pixelAlignOrigin", false) ~= true
        or not (GUI2 and GUI2.GetPixelOriginCorrection) then
        return false
    end

    local logicalLeft = frame.GetLeft and frame:GetLeft()
    local logicalBottom = frame.GetBottom and frame:GetBottom()
    if type(logicalLeft) ~= "number"
        or type(logicalBottom) ~= "number" then
        return false
    end

    local correctionX, correctionY, available =
        GUI2:GetPixelOriginCorrection(frame)
    if available ~= true then return false end
    if correctionX == 0 and correctionY == 0 then return false end

    frame:ClearAllPoints()
    frame:SetPoint(
        anchor.point or "CENTER",
        relativeFrame,
        anchor.relativePoint or anchor.point or "CENTER",
        (placement.offset.x or 0) + correctionX,
        (placement.offset.y or 0) + correctionY
    )

    local alignedLeft = frame.GetLeft and frame:GetLeft()
    local alignedBottom = frame.GetBottom and frame:GetBottom()
    entry.pixelOriginCorrectionX = type(alignedLeft) == "number"
        and alignedLeft - logicalLeft or correctionX
    entry.pixelOriginCorrectionY = type(alignedBottom) == "number"
        and alignedBottom - logicalBottom or correctionY
    return true
end

local function ApplyPlacement(entry, placement, skipCallback, options)
    if not entry then return false end
    options = type(options) == "table" and options or nil

    placement = NormalizePlacement(placement) or ResolveDefaultPlacement(entry)
    local anchor = placement.anchor or {}
    if not IsStrictAnchorTargetAllowed(entry, anchor.relative) then
        placement = ResolveDefaultPlacement(entry)
        anchor = placement.anchor or {}
        if not IsStrictAnchorTargetAllowed(entry, anchor.relative) then
            placement = DefaultPlacement()
            anchor = placement.anchor
        end
        SavePlacement(entry.id, placement)
        entry.strictAnchorRecovered = true
    end
    if WouldCreateAnchorCycle(entry.id, anchor.relative) then
        placement = ResolveDefaultPlacement(entry)
        anchor = placement.anchor or {}
    end
    UpdateGroupAnchorIndex(
        entry,
        options and options.fallback and options.pendingPlacement or placement
    )
    local frame = ResolveEntryFrame(entry)
    if not frame then return false end
    if InCombat() and IsCombatPlacementProtected(entry, frame) then
        return SetPlacementCombatDeferred(entry, placement)
    end
    local relativeFrame, status, resolvedName
    if options and options.resolvedAnchorProvided == true
        and options.resolvedAnchorName == anchor.relative then
        relativeFrame = options.resolvedAnchorFrame
        status = options.resolvedAnchorStatus
        resolvedName = options.resolvedAnchorName
    else
        relativeFrame, status, resolvedName = ResolveAnchorFrame(entry, anchor.relative, frame, true)
    end
    if status == PLACEMENT_PENDING or status == PLACEMENT_UNAVAILABLE then
        entry.resolvedPlacementAnchorFrame = nil
        if status == PLACEMENT_UNAVAILABLE
            or (options and options.allowFallback) then
            local fallbackPlacement = ResolveFallbackPlacement(entry, frame, placement)
            local ok = ApplyPlacement(entry, fallbackPlacement, true, {
                fallback = true,
                pendingAnchor = resolvedName,
                pendingPlacement = placement,
                deferOverlay = options and options.deferOverlay,
            })
            return ok
        end
        if options and options.preserveFallback and entry.placementState == PLACEMENT_FALLBACK then
            return false
        end
        return SetPlacementPending(entry, frame, placement, resolvedName, options and options.deferOverlay)
    end
    if status == "self" or relativeFrame == frame then
        relativeFrame = UIParent
        anchor.relative = "UIParent"
    elseif (status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED) or not relativeFrame then
        placement = ResolveDefaultPlacement(entry)
        anchor = placement.anchor or {}
        relativeFrame = ResolveFrameRef(anchor.relative)
    end
    ClearPixelOriginCorrection(entry)
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point or "CENTER", relativeFrame, anchor.relativePoint or anchor.point or "CENTER", placement.offset.x or 0, placement.offset.y or 0)

    if not (options and options.fallback) and status == PLACEMENT_READY and anchor.relative ~= "UIParent" then
        local absoluteFallback = CaptureGeneric(frame, entry)
        if absoluteFallback then
            placement.fallback = absoluteFallback
            local savedPlacement = GetSavedPlacement(entry.id)
            if savedPlacement and savedPlacement.anchor and savedPlacement.anchor.relative == anchor.relative then
                savedPlacement.fallback = absoluteFallback
                SavePlacement(entry.id, savedPlacement)
            end
        end
    end

    ApplyPixelOriginAlignment(
        entry,
        frame,
        anchor,
        relativeFrame,
        placement
    )

    if options and options.fallback then
        SetPlacementFallback(entry, frame, placement, options.pendingPlacement, options.pendingAnchor)
    elseif status == PLACEMENT_SIMULATED then
        SetPlacementSimulated(entry, frame, placement, resolvedName)
    else
        SetPlacementReady(entry, frame)
    end
    entry.resolvedPlacementAnchorFrame = relativeFrame

    if not skipCallback and type(entry.spec.onApply) == "function" then
        SafeCall("Layout:onApply:" .. tostring(entry.id), entry.spec.onApply, frame, CopyPlacement(placement), entry, Layout)
    end

    if not (options and options.deferOverlay) then
        if Layout.editing and Layout.RefreshEditSessionEntry then
            Layout:RefreshEditSessionEntry(entry)
        else
            Layout:UpdateOverlay(entry)
        end
    end
    CompletePendingPlacementCommit(entry, frame)
    return true
end
P.ApplyPlacement = ApplyPlacement

local function CanonicalPlacementForTarget(entry)
    return entry and (
        entry.pendingPlacement
        or GetSavedPlacement(entry.id)
        or ResolveDefaultPlacement(entry)
    ) or nil
end

local function PlacementTargetsName(entry, targetName)
    local placement = CanonicalPlacementForTarget(entry)
    local anchor = placement and placement.anchor
    return anchor
        and NormalizeAnchorTargetName(anchor.relative) == targetName,
        placement
end

local function RefreshAvailabilityChrome()
    if Layout.RefreshOverlays then Layout:RefreshOverlays() end
    if Layout.RefreshControlPanel then Layout:RefreshControlPanel() end
end

function Layout:SetAnchorTargetAvailable(targetId, available)
    local targetEntry = type(targetId) == "table"
        and targetId or self.frames[targetId]
    if not targetEntry then return false, "frame-not-registered" end

    available = available ~= false
    if targetEntry.anchorTargetAvailable == available then
        return true, 0
    end

    local targetName = EntryFrameName(targetEntry)
    if not targetName then return false, "anchor-target-unnamed" end

    if not available and InCombat() then
        local targetFrame = ResolveEntryFrame(targetEntry)
        if targetFrame
            and IsCombatPlacementProtected(targetEntry, targetFrame) then
            return false, "combat-protected"
        end
        for _, id in ipairs(self.order) do
            local entry = self.frames[id]
            local targets = entry ~= targetEntry
                and PlacementTargetsName(entry, targetName)
            local frame = targets and ResolveEntryFrame(entry) or nil
            if frame and IsCombatPlacementProtected(entry, frame) then
                return false, "combat-protected"
            end
        end
    end

    local changed = 0
    if not available then
        local captureLiveFallback = targetEntry.anchorTargetAvailable == true
        for _, id in ipairs(self.order) do
            local entry = self.frames[id]
            if entry ~= targetEntry then
                local targets, placement = PlacementTargetsName(
                    entry,
                    targetName
                )
                if targets and placement then
                    local frame = ResolveEntryFrame(entry)
                    local fallback
                    if captureLiveFallback
                        and frame
                        and entry.placementState ~= PLACEMENT_PENDING then
                        fallback = CaptureGeneric(frame, entry, true)
                    end
                    fallback = NormalizePlacement(fallback)
                        or NormalizePlacement(placement.fallback)
                        or ResolveFallbackPlacement(entry, frame, placement)
                    if fallback then
                        placement.fallback = CopyPlacement(fallback)
                        SavePlacement(entry.id, placement)
                        if ApplyPlacement(entry, fallback, true, {
                            fallback = true,
                            pendingAnchor = targetName,
                            pendingPlacement = placement,
                            deferOverlay = true,
                        }) then
                            changed = changed + 1
                        end
                    end
                end
            end
        end
        targetEntry.anchorTargetAvailable = false
    else
        targetEntry.anchorTargetAvailable = true
        for _, id in ipairs(self.order) do
            local entry = self.frames[id]
            if entry ~= targetEntry then
                local targets, placement = PlacementTargetsName(
                    entry,
                    targetName
                )
                if targets and placement
                    and (entry.placementState == PLACEMENT_PENDING
                        or entry.placementState == PLACEMENT_FALLBACK
                        or entry.placementState == PLACEMENT_SIMULATED) then
                    if ApplyPlacement(entry, placement, true, {
                        deferOverlay = true,
                    }) then
                        changed = changed + 1
                    end
                end
            end
        end
        if self.editing and self.ActivateEditSessionEntry then
            self:ActivateEditSessionEntry(targetEntry)
        end
    end

    RefreshAvailabilityChrome()
    return true, changed
end

function Layout:RecoverOffscreenPlacements(reason)
    local recoveredCount = 0
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        local frame = ResolveEntryFrame(entry)
        if entry and frame and not (InCombat() and IsCombatPlacementProtected(entry, frame)) then
            local placement, recovered = ResolveVisiblePlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry))
            if recovered then
                SavePlacement(id, placement)
                entry.offscreenRecovered = true
                entry.offscreenRecoveryReason = reason or "runtime"
                ApplyPlacement(entry, placement, true)
                NotifyOffscreenRecovery(entry)
                recoveredCount = recoveredCount + 1
            end
        end
    end
    return recoveredCount
end

function Layout:GetPlacementState(id)
    local entry = type(id) == "table" and id or self.frames[id]
    if not entry then return nil end
    return entry.placementState or PLACEMENT_READY, entry.pendingAnchor
end

function Layout:IsPlacementReady(id)
    local state = self:GetPlacementState(id)
    return state == nil or state == PLACEMENT_READY or state == PLACEMENT_SIMULATED
end

function Layout:RefreshFrame(id)
    local entry = self.frames[id]
    if not entry then return false end
    local desiredAvailability = ResolveSpecValue(entry, "isEnabled", true)
        ~= false
    if not desiredAvailability
        and entry.anchorTargetAvailable ~= false then
        local transitioned = self:SetAnchorTargetAvailable(entry, false)
        if not transitioned then return false end
    end
    if entry.combatDeferredPlacement then
        local placement = ResolveVisiblePlacement(entry, entry.combatDeferredPlacement)
        ApplyPlacement(entry, placement, true)
    elseif entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
        ApplyPlacement(entry, entry.pendingPlacement or GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true, {
            preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
        })
    else
        local placement, clamped = ResolveVisiblePlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry))
        if clamped then SavePlacement(id, placement) end
        ApplyPlacement(entry, placement, true)
    end
    if desiredAvailability
        and entry.anchorTargetAvailable ~= true then
        local transitioned = self:SetAnchorTargetAvailable(entry, true)
        if not transitioned then return false end
    end
    if self.moverPanelEntryId == id then
        self:RefreshMovementWidgets()
    end
    return true
end

local function IsPixelAlignedEntry(entry)
    return entry and ResolveSpecValue(
        entry,
        "pixelAlignOrigin",
        false
    ) == true
end

local function NextPixelRefreshGeneration()
    local generation = (Layout.pixelOriginRefreshGeneration or 0) + 1
    Layout.pixelOriginRefreshGeneration = generation
    return generation
end

local function RefreshPixelAlignedEntry(entry, generation)
    if not IsPixelAlignedEntry(entry)
        or entry.pixelOriginRefreshGeneration == generation then
        return 0
    end

    entry.pixelOriginRefreshGeneration = generation
    local placement = GetSavedPlacement(entry.id)
        or ResolveDefaultPlacement(entry)
    local relative = placement and placement.anchor
        and placement.anchor.relative
    local targetEntry = relative and FindEntryByFrameName(relative)
    local refreshed = RefreshPixelAlignedEntry(targetEntry, generation)
    ApplyPlacement(entry, placement, true)
    return refreshed + 1
end

local function RefreshPixelAlignedBranch(entry, generation)
    local refreshed = RefreshPixelAlignedEntry(entry, generation)
    for _, id in ipairs(Layout.order) do
        local candidate = Layout.frames[id]
        if IsPixelAlignedEntry(candidate)
            and candidate.pixelOriginRefreshGeneration ~= generation then
            local placement = GetSavedPlacement(candidate.id)
                or ResolveDefaultPlacement(candidate)
            local relative = placement and placement.anchor
                and placement.anchor.relative
            local relativeEntry = relative
                and FindEntryByFrameName(relative)
            if relativeEntry == entry then
                refreshed = refreshed
                    + RefreshPixelAlignedBranch(candidate, generation)
            end
        end
    end
    return refreshed
end

local PIXEL_CORRECTION_EPSILON = 0.0001

local function PixelAlignedEntryNeedsRefresh(entry)
    local frame = entry and ResolveEntryFrame(entry)
    if not frame or not (GUI2 and GUI2.GetPixelOriginCorrection) then
        return true, true
    end

    local correctionX, correctionY, available =
        GUI2:GetPixelOriginCorrection(frame)
    if available ~= true
        or type(correctionX) ~= "number"
        or type(correctionY) ~= "number" then
        return true, true
    end
    return math_abs(correctionX) > PIXEL_CORRECTION_EPSILON
        or math_abs(correctionY) > PIXEL_CORRECTION_EPSILON,
        false
end

local function RefreshPixelAlignedEntryIfNeeded(entry, generation)
    if not IsPixelAlignedEntry(entry)
        or entry.pixelOriginRefreshGeneration == generation then
        return 0, 0, 0
    end

    entry.pixelOriginRefreshGeneration = generation
    local placement = GetSavedPlacement(entry.id)
        or ResolveDefaultPlacement(entry)
    local relative = placement and placement.anchor
        and placement.anchor.relative
    local targetEntry = relative and FindEntryByFrameName(relative)
    local visited, applied, unavailable =
        RefreshPixelAlignedEntryIfNeeded(targetEntry, generation)
    local needsRefresh, correctionUnavailable =
        PixelAlignedEntryNeedsRefresh(entry)
    if needsRefresh and ApplyPlacement(entry, placement, true) == true then
        applied = applied + 1
    end
    if correctionUnavailable then unavailable = unavailable + 1 end
    return visited + 1, applied, unavailable
end

local function RefreshPixelAlignedBranchIfNeeded(entry, generation)
    local visited, applied, unavailable =
        RefreshPixelAlignedEntryIfNeeded(entry, generation)
    for _, id in ipairs(Layout.order) do
        local candidate = Layout.frames[id]
        if IsPixelAlignedEntry(candidate)
            and candidate.pixelOriginRefreshGeneration ~= generation then
            local placement = GetSavedPlacement(candidate.id)
                or ResolveDefaultPlacement(candidate)
            local relative = placement and placement.anchor
                and placement.anchor.relative
            local relativeEntry = relative
                and FindEntryByFrameName(relative)
            if relativeEntry == entry then
                local childVisited, childApplied, childUnavailable =
                    RefreshPixelAlignedBranchIfNeeded(candidate, generation)
                visited = visited + childVisited
                applied = applied + childApplied
                unavailable = unavailable + childUnavailable
            end
        end
    end
    return visited, applied, unavailable
end

function Layout:RefreshPixelAlignedFrame(id)
    local entry = self.frames[id]
    if not IsPixelAlignedEntry(entry) then return 0 end
    return RefreshPixelAlignedBranch(
        entry,
        NextPixelRefreshGeneration()
    )
end

function Layout:RefreshPixelAlignedFrameIfNeeded(id)
    local entry = self.frames[id]
    if not IsPixelAlignedEntry(entry) then return 0, 0, 0 end
    return RefreshPixelAlignedBranchIfNeeded(
        entry,
        NextPixelRefreshGeneration()
    )
end

function Layout:RefreshPixelAlignedFrames()
    local generation = NextPixelRefreshGeneration()
    local refreshed = 0
    for _, id in ipairs(self.order) do
        refreshed = refreshed
            + RefreshPixelAlignedEntry(self.frames[id], generation)
    end
    return refreshed
end

function Layout:GetPlacement(id)
    local entry = self.frames[id]
    if not entry then return nil end
    return CopyPlacement(GetSavedPlacement(id) or ResolveDefaultPlacement(entry))
end

function Layout:CommitPlacementOrRestore(id, placement, reason)
    local entry = self.frames[id]
    if not entry then return false end
    local previous = self:GetPlacement(id)
    local applied, failureReason = self:SetPlacement(id, placement, true)
    if applied then
        local committed = self:GetPlacement(id)
        local commitReason = reason or "commit"
        if PlacementsEqual(previous, committed) then
            if type(entry.spec.onPlacementCommitted) == "function"
                and (entry.placementState ~= PLACEMENT_READY
                    or entry.combatDeferredPlacement ~= nil) then
                entry.pendingPlacementCommitReason = commitReason
            end
            return true
        end
        if type(entry.spec.onPlacementCommitted) ~= "function" then
            return true
        end
        if entry.placementState == PLACEMENT_READY
            and entry.combatDeferredPlacement == nil then
            NotifyPlacementCommitted(
                entry,
                committed,
                commitReason,
                ResolveEntryFrame(entry)
            )
        else
            entry.pendingPlacementCommitReason = commitReason
        end
        return true
    end
    if previous then ApplyPlacement(entry, previous, true) end
    return false, failureReason
end

function Layout:CommitFramePosition(id, sourceFrame, reason)
    local entry = self.frames[id]
    if not entry then return false end
    local frame = sourceFrame or ResolveEntryFrame(entry)
    local current = self:GetPlacement(id)
    local placement
    if frame and current and entry.placementState == PLACEMENT_FALLBACK then
        local left = frame.GetLeft and frame:GetLeft()
        local bottom = frame.GetBottom and frame:GetBottom()
        local width = frame.GetWidth and frame:GetWidth()
        local height = frame.GetHeight and frame:GetHeight()
        if type(left) == "number"
            and type(bottom) == "number"
            and type(width) == "number"
            and type(height) == "number" then
            placement = CaptureGeneric(frame, entry, true)
        end
    elseif frame and current then
        placement = CaptureRelativePlacement(entry, frame, current)
    end
    if not placement then
        self:RefreshFrame(id)
        return false
    end
    return self:CommitPlacementOrRestore(
        id,
        placement,
        reason or "frame-drag"
    )
end

function Layout:GetAnchorTargetOptions(entryOrId)
    local entry = type(entryOrId) == "string" and self.frames[entryOrId] or entryOrId
    return BuildAnchorTargetOptions(entry)
end

function Layout:GetPointOptions()
    return BuildPointOptions()
end

function Layout:HasPlacement(id)
    return GetSavedPlacement(id) ~= nil
end

function Layout:SetPlacement(id, placement, applyNow)
    local entry = self.frames[id]
    if not entry then return false end
    placement = NormalizePlacement(placement)
    if not placement then return false end
    local relative = placement.anchor and placement.anchor.relative
    if not IsStrictAnchorTargetAllowed(entry, relative) then
        entry.placementErrorReason = "layout.position.invalid_anchor_target"
        return false, entry.placementErrorReason
    end
    placement = ClampPlacementToScreen(entry, placement)
    local visible, reason = EvaluatePlacementVisibility(entry, placement)
    if visible == false then
        entry.placementErrorReason = reason or "offscreen"
        return false, entry.placementErrorReason
    end
    ClearPendingPlacementCommit(entry)
    entry.placementErrorReason = nil
    if self.moverPanelLiveId == id then
        self.moverPanelLiveId = nil
        self.moverPanelLivePlacement = nil
    end
    SavePlacement(id, placement)
    if applyNow == false then UpdateGroupAnchorIndex(entry, placement) end
    if applyNow ~= false then
        ApplyPlacement(entry, placement)
    end
    self:RefreshSettingsPanel()
    self:RefreshOverlayVisuals()
    return true
end

function Layout:ResetFrame(id, reason)
    local entry = self.frames[id]
    if not entry then return false end
    local placement = ResolveVisiblePlacement(entry, ResolveDefaultPlacement(entry))
    return self:CommitPlacementOrRestore(id, placement, reason or "reset")
end

function Layout:PatchPlacement(id, patch, reason)
    local entry = self.frames[id]
    if not entry or type(patch) ~= "table" then return false end

    local placement = self:GetPlacement(id)
    if not placement then return false end
    placement.anchor = placement.anchor or {}
    placement.offset = placement.offset or { x = 0, y = 0 }

    local anchorPatch = type(patch.anchor) == "table" and patch.anchor or patch
    local offsetPatch = type(patch.offset) == "table" and patch.offset or patch

    if anchorPatch.point ~= nil then placement.anchor.point = anchorPatch.point end
    if anchorPatch.relative ~= nil then placement.anchor.relative = anchorPatch.relative end
    if anchorPatch.relativePoint ~= nil then placement.anchor.relativePoint = anchorPatch.relativePoint end
    if offsetPatch.x ~= nil then placement.offset.x = Round(offsetPatch.x) end
    if offsetPatch.y ~= nil then placement.offset.y = Round(offsetPatch.y) end

    return self:CommitPlacementOrRestore(id, placement, reason or "patch")
end

function Layout:ResetAllFrames(reason)
    for _, id in ipairs(self.order) do
        self:ResetFrame(id, reason or "reset-all")
    end
end

function Layout:NudgeFrame(id, dx, dy, reason)
    if InCombat() then return false end
    local entry = self.frames[id]
    if not entry then return false end
    local placement = self:GetPlacement(id)
    if not placement then return false end
    placement.offset.x = Round((placement.offset.x or 0) + (dx or 0))
    placement.offset.y = Round((placement.offset.y or 0) + (dy or 0))
    return self:CommitPlacementOrRestore(id, placement, reason or "nudge")
end

function Layout:SelectFrame(id, showPanel)
    if id and self.frames[id] then
        self.selectedId = id
        self:RefreshOverlayVisuals()
        self:RefreshControlPanel()
        self:RefreshSettingsPanel()
        self:RefreshAnchorLine()
        if showPanel ~= false and self.editing and self.ShowMoverPanel then
            self:ShowMoverPanel(id)
        end
        return true
    end
    return false
end

function Layout:RegisterOptions(id, options)
    local entry = self.frames[id]
    if not entry then
        self.pendingOptions[id] = options
        return true
    end
    entry.options = options
    return true
end

function Layout:RegisterFrame(id, spec)
    if type(id) ~= "string" or id == "" or type(spec) ~= "table" then
        return false
    end

    local entry = self.frames[id]
    local isNewEntry = entry == nil
    if not entry then
        entry = { id = id }
        self.frames[id] = entry
        self.order[#self.order + 1] = id
    elseif entry.overlay then
        entry.overlay.yuiLayoutEntry = entry
    end

    entry.spec = spec
    entry.frame = nil
    entry.options = spec.options or self.pendingOptions[id] or entry.options
    self.pendingOptions[id] = nil
    ResolveEntryFrame(entry)
    BuildAnchorTargetOptions(entry)
    local desiredAvailability = ResolveSpecValue(entry, "isEnabled", true)
        ~= false
    if isNewEntry and desiredAvailability then
        entry.anchorTargetAvailable = true
    end
    if not desiredAvailability
        and entry.anchorTargetAvailable ~= false then
        self:SetAnchorTargetAvailable(entry, false)
    end
    local placement, recovered = ResolveVisiblePlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry))
    if recovered then
        SavePlacement(id, placement)
        entry.offscreenRecovered = true
    end
    ApplyPlacement(entry, placement, true)
    if desiredAvailability
        and entry.anchorTargetAvailable ~= true then
        self:SetAnchorTargetAvailable(entry, true)
    end
    if recovered then NotifyOffscreenRecovery(entry) end
    if ResolveSpecValue(entry, "showOnlyInEditMode", false) == true and not self.editing then
        local frame = ResolveEntryFrame(entry)
        if frame and not (InCombat() and IsCombatPlacementProtected(entry, frame)) then frame:Hide() end
    end
    return entry
end

function Layout:UnregisterFrame(id)
    local entry = self.frames[id]
    if not entry then return false end
    ClearPendingPlacementCommit(entry)
    ClearCombatDeferred(entry)
    RemoveGroupAnchorIndex(entry)
    if self.DeactivateEditSessionEntry then self:DeactivateEditSessionEntry(entry) end
    self:HideMoverPanel(id)
    if self.ReleaseOverlay then
        self:ReleaseOverlay(entry)
    elseif entry.overlay then
        entry.overlay:Hide()
        entry.overlay:SetScript("OnUpdate", nil)
    end
    self.frames[id] = nil
    for index, value in ipairs(self.order) do
        if value == id then
            tremove(self.order, index)
            break
        end
    end
    if self.selectedId == id then
        self.selectedId = self.order[1]
    end
    self:RefreshControlPanel()
    self:RefreshSettingsPanel()
    return true
end

function Layout:IsEditing()
    return self.editing == true
end
