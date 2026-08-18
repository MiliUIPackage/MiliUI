local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - placement
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local UIParent = P.UIParent
local DB_VERSION = P.DB_VERSION
local ANCHOR_POINTS = P.ANCHOR_POINTS
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
local DEFAULT_GRID_DENSITY = P.DEFAULT_GRID_DENSITY or "medium"
local GRID_DENSITY_SPACING = P.GRID_DENSITY_SPACING or {}
local PLACEMENT_READY = P.PLACEMENT_READY
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring
local tonumber = P.tonumber
local tremove = P.tremove
local math_max = P.math_max
local math_min = P.math_min
local math_floor = P.math_floor
local math_ceil = P.math_ceil
local string_find = P.string_find
local string_gsub = P.string_gsub

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
    if type(value) == "table" then
        value = FrameName(value)
    end
    value = NormalizeAnchorTargetName(value)
    if type(value) ~= "string" or value == "" or seen[value] then return end
    seen[value] = true
    options[#options + 1] = FormatAnchorTargetOption and FormatAnchorTargetOption(value) or { text = value, value = value }
end

local function AddAnchorTargetOptions(options, seen, value)
    if type(value) == "string" then
        AddAnchorTargetOption(options, seen, value)
        return
    end
    if type(value) ~= "table" then return end

    local descriptorName = value.name or value.frameName or value.globalName or value.relative or value.frame
    if descriptorName then
        AddAnchorTargetOption(options, seen, descriptorName)
        return
    end

    for key, target in pairs(value) do
        if type(key) == "string" then AddAnchorTargetOption(options, seen, key) end
        if type(target) == "string" or type(target) == "table" then
            if type(target) == "table" then
                AddAnchorTargetOption(options, seen, target.name or target.frameName or target.globalName or target.relative or target.frame)
            else
                AddAnchorTargetOption(options, seen, target)
            end
        end
    end
end

local function BuildPointOptions()
    local options = {}
    for _, point in ipairs(ANCHOR_POINTS) do
        options[#options + 1] = { text = point, value = point }
    end
    return options
end
P.BuildPointOptions = BuildPointOptions

local function CopyPlacement(placement)
    if type(placement) ~= "table" then return nil end
    local copy = {
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
    if placement.size then
        copy.size = {
            width = tonumber(placement.size.width),
            height = tonumber(placement.size.height),
        }
    end
    return copy
end
P.CopyPlacement = CopyPlacement

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
        if value.size then
            placement.size = {
                width = tonumber(value.size.width),
                height = tonumber(value.size.height),
            }
        elseif value.width or value.height then
            placement.size = {
                width = tonumber(value.width),
                height = tonumber(value.height),
            }
        end
        if type(placement.anchor.relative) == "table" then
            placement.anchor.relative = FrameName(placement.anchor.relative)
        end
        placement.anchor.relative = NormalizeAnchorTargetName(placement.anchor.relative)
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
    db.version = DB_VERSION
    if type(db.frames) ~= "table" then db.frames = {} end
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

local function GetSavedPlacement(id)
    local db = EnsureDB()
    return db and NormalizePlacement(db.frames[id]) or nil
end
P.GetSavedPlacement = GetSavedPlacement

local function BuildAnchorTargetOptions(entry)
    local options = {}
    local seen = {}
    AddAnchorTargetOption(options, seen, "UIParent")

    local placement = entry and (GetSavedPlacement(entry.id) or ResolveDefaultPlacement(entry))
    local currentRelative = placement and placement.anchor and placement.anchor.relative
    AddAnchorTargetOption(options, seen, currentRelative)

    local builtinValues = GetBuiltinAnchorTargetValues and GetBuiltinAnchorTargetValues()
    if type(builtinValues) == "table" then
        for _, value in ipairs(builtinValues) do
            AddAnchorTargetOption(options, seen, value)
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

function Layout:WouldCreateAnchorCycle(sourceId, targetName)
    return WouldCreateAnchorCycle(sourceId, targetName)
end

local function ApplySize(frame, placement, spec)
    if not frame or not placement or not placement.size then return end
    local width = tonumber(placement.size.width)
    local height = tonumber(placement.size.height)
    if not width and not height then return end

    if width then
        if spec.minWidth then width = math_max(width, spec.minWidth) end
        if spec.maxWidth then width = math_min(width, spec.maxWidth) end
    end
    if height then
        if spec.minHeight then height = math_max(height, spec.minHeight) end
        if spec.maxHeight then height = math_min(height, spec.maxHeight) end
    end

    if width and height and frame.SetSize then
        frame:SetSize(width, height)
    elseif width and frame.SetWidth then
        frame:SetWidth(width)
    elseif height and frame.SetHeight then
        frame:SetHeight(height)
    end
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

local function CaptureGeneric(frame)
    if not frame or not frame.GetLeft then return DefaultPlacement() end
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if not left or not bottom then return DefaultPlacement() end

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
            x = Round(frameX - parentX),
            y = Round(frameY - parentY),
        },
        size = {
            width = Round(width),
            height = Round(height),
        },
    }
end

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
    captured.size = {
        width = Round(width),
        height = Round(height),
    }
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
    return CaptureRelativePlacement(entry, sourceFrame or frame) or CaptureGeneric(sourceFrame or frame)
end
P.CapturePlacement = CapturePlacement

local function RestorePendingVisibility(entry, frame)
    if entry.pendingAnchorWasShown and frame and frame.Show then
        frame:Show()
    end
end

local function SetPlacementReady(entry, frame)
    local wasPending = entry.placementState == PLACEMENT_PENDING
    entry.placementState = PLACEMENT_READY
    entry.pendingAnchor = nil
    entry.pendingPlacement = nil
    entry.pendingAnchorWasShown = nil
    entry.simulatedAnchorWasShown = nil
    entry.fallbackPlacement = nil
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = nil end
    if wasPending then RestorePendingVisibility(entry, frame) end
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
end

local function SetPlacementPending(entry, frame, placement, anchorName)
    local isNewPending = entry.placementState ~= PLACEMENT_PENDING or entry.pendingAnchor ~= anchorName
    local wasSimulated = entry.placementState == PLACEMENT_SIMULATED
    local simulatedWasShown = entry.simulatedAnchorWasShown
    entry.placementState = PLACEMENT_PENDING
    entry.pendingAnchor = anchorName
    entry.pendingPlacement = CopyPlacement(placement)
    entry.fallbackPlacement = nil
    if isNewPending and wasSimulated then
        entry.pendingAnchorWasShown = simulatedWasShown == true
    elseif isNewPending and frame and frame.IsShown then
        entry.pendingAnchorWasShown = frame:IsShown()
    end
    entry.simulatedAnchorWasShown = nil
    if frame and frame.Hide then frame:Hide() end
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = true end
    if P.QueuePendingAnchorRetry then P.QueuePendingAnchorRetry(entry.id, isNewPending) end
    Layout:UpdateOverlay(entry)
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
    return false
end

local function SetPlacementFallback(entry, frame, fallbackPlacement, pendingPlacement, anchorName)
    entry.placementState = PLACEMENT_FALLBACK
    entry.pendingAnchor = anchorName
    entry.pendingPlacement = CopyPlacement(pendingPlacement)
    entry.simulatedAnchorWasShown = nil
    entry.fallbackPlacement = CopyPlacement(fallbackPlacement)
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
    if Layout.pendingAnchors then Layout.pendingAnchors[entry.id] = true end
    if frame and frame.Show then frame:Show() end
    if P.QueuePendingAnchorRetry then P.QueuePendingAnchorRetry(entry.id, isNewSimulated) end
    if RefreshBuiltinAnchorPlaceholderVisibility then RefreshBuiltinAnchorPlaceholderVisibility() end
end

local function ResolveFallbackPlacement(entry, frame)
    local fallback = NormalizePlacement(ResolveSpecValue(entry, "fallbackPlacement", nil)) or ResolveDefaultPlacement(entry)
    local _, status = ResolveAnchorFrame(entry, fallback and fallback.anchor and fallback.anchor.relative, frame, false)
    if status ~= PLACEMENT_READY then
        fallback = DefaultPlacement()
    end
    return fallback
end

local function ApplyPlacement(entry, placement, skipCallback, options)
    if not entry then return false end
    local frame = ResolveEntryFrame(entry)
    if not frame then return false end
    options = type(options) == "table" and options or nil

    placement = NormalizePlacement(placement) or ResolveDefaultPlacement(entry)
    local anchor = placement.anchor or {}
    if WouldCreateAnchorCycle(entry.id, anchor.relative) then
        placement = ResolveDefaultPlacement(entry)
        anchor = placement.anchor or {}
    end
    local relativeFrame, status, resolvedName = ResolveAnchorFrame(entry, anchor.relative, frame, true)
    if status == PLACEMENT_PENDING then
        if options and options.allowFallback then
            local fallbackPlacement = ResolveFallbackPlacement(entry, frame)
            local ok = ApplyPlacement(entry, fallbackPlacement, true, {
                fallback = true,
                pendingAnchor = resolvedName,
                pendingPlacement = placement,
            })
            return ok
        end
        if options and options.preserveFallback and entry.placementState == PLACEMENT_FALLBACK then
            return false
        end
        return SetPlacementPending(entry, frame, placement, resolvedName)
    end
    if status == "self" or relativeFrame == frame then
        relativeFrame = UIParent
        anchor.relative = "UIParent"
    elseif (status ~= PLACEMENT_READY and status ~= PLACEMENT_SIMULATED) or not relativeFrame then
        placement = ResolveDefaultPlacement(entry)
        anchor = placement.anchor or {}
        relativeFrame = ResolveFrameRef(anchor.relative)
    end
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point or "CENTER", relativeFrame, anchor.relativePoint or anchor.point or "CENTER", placement.offset.x or 0, placement.offset.y or 0)
    ApplySize(frame, placement, entry.spec or {})

    if options and options.fallback then
        SetPlacementFallback(entry, frame, placement, options.pendingPlacement, options.pendingAnchor)
    elseif status == PLACEMENT_SIMULATED then
        SetPlacementSimulated(entry, frame, placement, resolvedName)
    else
        SetPlacementReady(entry, frame)
    end

    if not skipCallback and type(entry.spec.onApply) == "function" then
        SafeCall("Layout:onApply:" .. tostring(entry.id), entry.spec.onApply, frame, CopyPlacement(placement), entry, Layout)
    end

    Layout:UpdateOverlay(entry)
    return true
end
P.ApplyPlacement = ApplyPlacement

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
    if entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
        ApplyPlacement(entry, entry.pendingPlacement or GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true, {
            preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
        })
    end
    if self.editing then
        self:UpdateOverlay(entry)
    end
    if self.moverPanelEntryId == id then
        self:RefreshMovementWidgets()
    end
    return true
end

function Layout:GetPlacement(id)
    local entry = self.frames[id]
    if not entry then return nil end
    return CopyPlacement(GetSavedPlacement(id) or ResolveDefaultPlacement(entry))
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
    if self.moverPanelLiveId == id then
        self.moverPanelLiveId = nil
        self.moverPanelLivePlacement = nil
    end
    SavePlacement(id, placement)
    if applyNow ~= false then
        ApplyPlacement(entry, placement)
    end
    self:RefreshSettingsPanel()
    self:RefreshOverlayVisuals()
    return true
end

function Layout:ResetFrame(id)
    local entry = self.frames[id]
    if not entry then return false end
    return self:SetPlacement(id, ResolveDefaultPlacement(entry), true)
end

function Layout:PatchPlacement(id, patch)
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

    return self:SetPlacement(id, placement, true)
end

function Layout:ResetAllFrames()
    for _, id in ipairs(self.order) do
        self:ResetFrame(id)
    end
end

function Layout:NudgeFrame(id, dx, dy)
    if InCombat() then return false end
    local entry = self.frames[id]
    if not entry then return false end
    local placement = self:GetPlacement(id)
    if not placement then return false end
    placement.offset.x = Round((placement.offset.x or 0) + (dx or 0))
    placement.offset.y = Round((placement.offset.y or 0) + (dy or 0))
    return self:SetPlacement(id, placement, true)
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
    ApplyPlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true)
    if ResolveSpecValue(entry, "showOnlyInEditMode", false) == true and not self.editing then
        local frame = ResolveEntryFrame(entry)
        if frame then frame:Hide() end
    end
    if self.editing then
        self:UpdateOverlay(entry)
    end
    return entry
end

function Layout:UnregisterFrame(id)
    local entry = self.frames[id]
    if not entry then return false end
    if entry.overlay then
        entry.overlay:Hide()
        entry.overlay:SetScript("OnUpdate", nil)
    end
    self:HideMoverPanel(id)
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
