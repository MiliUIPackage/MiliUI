do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout anchor definitions, independent of business frame lifetime
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout then return end
local Layout = YUI.Layout
local P = Layout._private
local definitions, names, dependents, pool = {}, {}, {}, {}
local resolving, notifying, providerChildren, warned = {}, {}, {}, {}
local function Perf(key)
    local capture = YUI.CPUWatchdog and YUI.CPUWatchdog.sceneCapture
    local perf = capture and capture.layoutPerf
    if perf then perf[key] = (perf[key] or 0) + 1 end
end
local function Store()
    local db = P.EnsureDB()
    return db and db.frames
end
local function Usable(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and frame.GetWidth and frame.GetHeight and frame.SetPoint
end
local function Number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number" and value == value and value > 0 and value < math.huge
end
local function HasPhysicalUsers(def)
    if not def.proxy then return false end
    for frame in pairs(def.users or {}) do
        local ok, _, relative
        if frame.GetPoint then ok, _, relative = pcall(frame.GetPoint, frame, 1) end
        if not ok or relative == def.proxy then return true end
        def.users[frame] = nil
    end
    return false
end
local function UseProxy(def, source)
    if source then
        def.users = def.users or setmetatable({}, { __mode = "k" })
        def.users[source] = true
    end
    return def.proxy, "ready", true
end
local function Release(def)
    if def.proxy and not P.InCombat() then
        def.proxy:ClearAllPoints()
        def.proxy:Hide()
        pool[#pool + 1] = def.proxy
        def.proxy = nil
    end
    def.valid, def.store = nil, nil
    if def.parentName and providerChildren[def.parentName] then
        providerChildren[def.parentName][def.id] = nil
        if not next(providerChildren[def.parentName]) then providerChildren[def.parentName] = nil end
    end
    def.parentName, def.users = nil, nil
end
local function Notify(name)
    if notifying[name] then return end
    notifying[name] = true
    for id in pairs(dependents[name] or {}) do
        local entry = Layout.frames[id]
        if entry then
            local ok = pcall(P.ApplyPlacement, entry,
                (entry.placementStore == (P.GetPlacementStorageIdentity and P.GetPlacementStorageIdentity(id) or Store())
                    and entry.pendingPlacement) or P.GetSavedPlacement(id)
                or P.ResolveDefaultPlacement(entry), true)
            if not ok then Perf("providerErrors") end
        end
    end
    notifying[name] = nil
end
function Layout:InvalidateAnchorProvider(id)
    local def = definitions[id]
    if not def then return false end
    def.valid, def.store = nil, nil
    Perf("providerInvalidations")
    if P.InCombat() then def.deferred = true; return true end
    Notify(def.name)
    for childId in pairs(providerChildren[def.name] or {}) do
        local child = definitions[childId]
        if child and not notifying[child.name] then
            notifying[def.name] = true
            self:InvalidateAnchorProvider(childId)
            notifying[def.name] = nil
        end
    end
    return true
end
function Layout:RegisterAnchorProvider(id, spec)
    if type(id) ~= "string" or type(spec) ~= "table"
        or type(spec.name) ~= "string"
        or (type(spec.resolve) ~= "function" and type(spec.getState) ~= "function") then return false end
    local other = names[spec.name]
    if other and other.id ~= id then return false, "duplicate-anchor-name" end
    local def = definitions[id]
    if def and def.name ~= spec.name then return false, "anchor-name-changed" end
    if not def then def = { id = id, name = spec.name }; definitions[id] = def; names[spec.name] = def end
    def.retired = nil
    def.validationEntry = { id = id, spec = spec }
    def.getState = spec.getState
    def.resolve = spec.resolve
    def.snapshot = nil
    self:InvalidateAnchorProvider(id)
    return true
end
function Layout:UnregisterAnchorProvider(id)
    local def = definitions[id]
    if not def then return false end
    if P.InCombat() then return false, "combat-protected" end
    -- Retain only the name tombstone: a leftover global is not a revived provider.
    def.resolve, def.snapshot, def.frame, def.getState = nil, nil, nil, nil
    def.retired = true
    self:InvalidateAnchorProvider(id)
    if not HasPhysicalUsers(def) then Release(def) end
    return true
end
function P.HasAnchorDefinition(id) return definitions[id] ~= nil end
function P.TrackAnchorDependency(entry, name)
    if entry.anchorTargetAvailable == false then name = nil end
    if entry.providerDependency == name then return end
    local old = entry.providerDependency
    if old and dependents[old] then
        dependents[old][entry.id] = nil
        if not next(dependents[old]) then dependents[old] = nil end
    end
    entry.providerDependency = type(name) == "string" and name ~= "UIParent" and name or nil
    name = entry.providerDependency
    if name then
        dependents[name] = dependents[name] or {}
        dependents[name][entry.id] = true
    end
end
local function CaptureAnchorDefinition(entry)
    local frame = P.ResolveEntryFrame(entry)
    if not Usable(frame) or not frame.GetName then return end
    local name = frame:GetName()
    if issecretvalue and issecretvalue(name) then return end
    if not name or name == "" or (names[name] and names[name].id ~= entry.id) then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not Number(width) or not Number(height) or not Number(scale) or not Number(uiScale) then return end
    local def = definitions[entry.id]
    if def and def.retired then return end
    if not def then
        def = { id = entry.id, name = name }
        definitions[entry.id], names[name] = def, def
    end
    local placement = entry.pendingPlacement or P.GetSavedPlacement(entry.id) or P.ResolveDefaultPlacement(entry)
    if not def.resolve then
        def.validationEntry = def.validationEntry or { id = entry.id }
        def.validationEntry.spec = entry.spec
    end
    local previous = def.snapshot
    local anchor, offset = placement.anchor, placement.offset
    local store = Store()
    local captureGuard = entry.spec and entry.spec.captureAnchorSnapshotGuard
    local changed = not previous or previous.store ~= store or previous.captureGuard ~= captureGuard
        or previous.width ~= width or previous.height ~= height
        or previous.scale ~= scale / uiScale or def.frame ~= frame
        or previous.placement.anchor.relative ~= anchor.relative
        or previous.placement.anchor.point ~= anchor.point
        or previous.placement.anchor.relativePoint ~= anchor.relativePoint
        or previous.placement.offset.x ~= offset.x or previous.placement.offset.y ~= offset.y
    def.frame = frame
    if changed then
        def.snapshot = { width = width, height = height, scale = scale / uiScale,
            placement = P.CopyPlacement(placement), store = store, captureGuard = captureGuard,
            guard = previous and previous.store == store and previous.captureGuard == captureGuard
                and previous.guard or (captureGuard and captureGuard()) }
        Layout:InvalidateAnchorProvider(entry.id)
    end
end
function P.CaptureAnchorDefinition(entry)
    local ok = pcall(CaptureAnchorDefinition, entry)
    if not ok then Perf("providerErrors") end
end
local function MissingState(def)
    if not def.getState then return "pending" end
    local ok, state = pcall(def.getState, def.id)
    if not ok then Perf("providerErrors"); return "pending" end
    return state == "disabled" and "unavailable" or "pending"
end
local Resolve
Resolve = function(name, source)
    local def = names[name]
    if not def then return nil, nil, false end
    local entry = Layout.frames[def.id]
    local frame = entry and P.ResolveEntryFrame(entry)
    if frame == source then return nil, "self", true end
    if entry and entry.anchorTargetAvailable ~= false and entry.placementState == "ready" and Usable(frame) then
        return frame, "ready", true
    end
    if resolving[name] then return nil, "pending", true end
    local store = Store()
    if def.valid and def.store == store then Perf("providerCacheHits"); return UseProxy(def, source) end
    -- Combat prevents rebuilding proxies, not reusing a valid current-profile anchor.
    if P.InCombat() then return nil, "pending", true end
    resolving[name] = true
    Perf("providerResolves")
    local placement, width, height, scale
    if def.resolve then
        local ok
        ok, placement, width, height, scale = pcall(def.resolve, def.id)
        if not ok then placement = nil; Perf("providerErrors") end
    elseif def.snapshot and def.snapshot.store == store
        and (not def.snapshot.guard or def.snapshot.guard() == true) then
        local snap = def.snapshot
        placement, width, height, scale = snap.placement, snap.width, snap.height, snap.scale
    end
    placement = P.NormalizePlacement(P.GetSavedPlacement(def.id) or placement)
    scale = scale or 1
    if not placement or not Number(width) or not Number(height) or not Number(scale) then
        resolving[name] = nil
        return nil, MissingState(def), true
    end
    local anchor = placement.anchor
    if def.validationEntry and not P.IsStrictAnchorTargetAllowed(def.validationEntry, anchor.relative) then
        resolving[name] = nil
        return nil, "pending", true
    end
    local parentName = anchor.relative or "UIParent"
    local parent, status, known
    if parentName == "UIParent" then parent, status = UIParent, "ready"
    else
        parent, status, known = Resolve(parentName, source)
        if not known then
            parent, status = P.ResolveAnchorFrame(entry, parentName, source, true)
        end
    end
    if def.parentName ~= parentName then
        if def.parentName and providerChildren[def.parentName] then
            providerChildren[def.parentName][def.id] = nil
            if not next(providerChildren[def.parentName]) then providerChildren[def.parentName] = nil end
        end
        def.parentName = parentName
        providerChildren[parentName] = providerChildren[parentName] or {}
        providerChildren[parentName][def.id] = true
    end
    if not parent or status ~= "ready" then
        resolving[name] = nil
        return nil, status == "unavailable" and "unavailable" or MissingState(def), true
    end
    if not def.proxy then
        def.proxy = table.remove(pool)
        if def.proxy then Perf("providerReused") else def.proxy = CreateFrame("Frame", nil, UIParent); Perf("providerCreated") end
        def.proxy:Hide()
    end
    local proxy = def.proxy
    Perf("providerWrites")
    proxy:SetSize(width, height)
    proxy:SetScale(scale)
    proxy:ClearAllPoints()
    proxy:SetPoint(anchor.point, parent, anchor.relativePoint, placement.offset.x, placement.offset.y)
    def.store, def.valid = store, true
    resolving[name] = nil
    return UseProxy(def, source)
end
function P.ResolveProvidedAnchor(name, source)
    local def = names[name]
    local entry = def and Layout.frames[def.id]
    local watchdog = YUI.CPUWatchdog
    local started = def and not def.valid
        and not (entry and entry.anchorTargetAvailable ~= false and entry.placementState == "ready")
        and watchdog and watchdog.sceneCapture and watchdog.BeginProbeTiming
        and watchdog:BeginProbeTiming()
    local ok, frame, state, known = pcall(Resolve, name, source)
    if started then watchdog:EndProbeTiming("layout.anchor-providers", started) end
    if ok then return frame, state, known end
    for key in pairs(resolving) do resolving[key] = nil end
    Perf("providerErrors")
    return nil, "pending", names[name] ~= nil
end
function P.ForgetAnchorFrame(id)
    if definitions[id] then definitions[id].frame = nil end
end
function P.NotifyMissingAnchor(entry, name, frame)
    if not name or (warned[entry.id] and warned[entry.id][name]) or not frame or not frame.IsShown or not frame:IsShown() then return end
    if entry.spec and P.ResolveSpecValue(entry, "isEnabled", true) == false then return end
    warned[entry.id] = warned[entry.id] or {}
    warned[entry.id][name] = true
    local locale = YUI.Locale and YUI.Locale:Get("Core")
    local message = locale and locale["layout.anchor_missing_notice"]
        or "Mover '%s' has an unavailable anchor target (%s). Open /yui - Edit Mode to adjust it."
    local title = P.ResolveSpecValue(entry, "title", entry.id)
    if type(title) ~= "string" or title == "" then title = entry.id end
    if YUI.Print then YUI:Print(string.format(message, title, name)) end
end

local markGeneration = 0
function P.CollectAnchorProxies()
    if P.InCombat() then return end
    markGeneration = markGeneration + 1
    local function Mark(def)
        while def and def.mark ~= markGeneration do
            def.mark = markGeneration
            def = names[def.parentName]
        end
    end
    for name in pairs(dependents) do Mark(names[name]) end
    for _, def in pairs(definitions) do if HasPhysicalUsers(def) then Mark(def) end end
    for _, def in pairs(definitions) do
        if def.mark ~= markGeneration then Release(def) end
    end
end
function Layout:RefreshAnchorProviders(deferNotify)
    for id, def in pairs(definitions) do
        def.valid, def.store = nil, nil
        if not def.resolve and def.snapshot and def.snapshot.store ~= Store() then
            def.snapshot = nil
        end
    end
    if deferNotify or P.InCombat() then return end
    for _, def in pairs(definitions) do
        if dependents[def.name] then Notify(def.name) end
        def.deferred = nil
    end
    P.CollectAnchorProxies()
end
