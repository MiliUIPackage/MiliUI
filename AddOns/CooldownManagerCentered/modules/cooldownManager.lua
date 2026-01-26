local _, ns = ...

-- Initialize namespace and DB early
ns.db = ns.db or {}
ns.db.profile = ns.db.profile or {}
local CooldownManager = {}
ns.CooldownManager = CooldownManager

CMC_DEBUG = false
local PrintDebug = function(...)
    if CMC_DEBUG then
        print("[CMC]", ...)
    end
end

local floor = math.floor

-- Architecture:
-- LayoutEngine: pure layout computations (no frame access)
-- StateTracker: invalidation/diffing + repaint tracking
-- ViewerAdapters: WoW Frame interaction per viewer type
-- EventHandler: events

local LayoutEngine = {}
local StateTracker = {}
local ViewerAdapters = {}
local EventHandler = {}

local viewers = {
    EssentialCooldownViewer = _G["EssentialCooldownViewer"],
    UtilityCooldownViewer = _G["UtilityCooldownViewer"],
    BuffIconCooldownViewer = _G["BuffIconCooldownViewer"],
    BuffBarCooldownViewer = _G["BuffBarCooldownViewer"],
}

-- Defaults
local fontSizeDefault = {
    EssentialCooldownViewer = 14,
    UtilityCooldownViewer = 12,
    BuffIconCooldownViewer = 14,
}
local viewerSettingsMap = {
    ["EssentialCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_Essential",
        squareIconsBorder = "cooldownManager_squareIconsBorder_Essential",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_Essential_Overlap",
    },
    ["UtilityCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_Utility",
        squareIconsBorder = "cooldownManager_squareIconsBorder_Utility",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_Utility_Overlap",
    },
    ["BuffIconCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_BuffIcons",
        squareIconsBorder = "cooldownManager_squareIconsBorder_BuffIcons",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_BuffIcons_Overlap",
    },
}

function LayoutEngine.CenteredRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce symmetric X offsets to center a horizontal row.
    -- When: Positioning icons in rows; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local totalWidth = (count * itemWidth) + ((count - 1) * padding)
    local startX = ((-totalWidth / 2 + itemWidth / 2) * dir)
    local offsets = {}
    for i = 1, count do
        offsets[i] = startX + (i - 1) * (itemWidth + padding) * dir
    end
    return offsets
end

function LayoutEngine.CenteredColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce symmetric Y offsets to center a vertical column.
    -- When: Positioning icons in columns; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local totalHeight = ((count * itemHeight) + ((count - 1) * padding))
    local startY = ((totalHeight / 2 - itemHeight / 2) * dir)
    local offsets = {}
    for i = 1, count do
        offsets[i] = (startY - (i - 1) * (itemHeight + padding) * dir)
    end
    return offsets
end

function LayoutEngine.StartRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce X offsets starting from the left edge.
    -- When: Positioning icons aligned to start; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = ((i - 1) * (itemWidth + padding) * dir)
    end
    return offsets
end

function LayoutEngine.EndRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce X offsets starting from the right edge.
    -- When: Positioning icons aligned to end; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = (-((i - 1) * (itemWidth + padding)) * dir)
    end
    return offsets
end

function LayoutEngine.StartColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce Y offsets starting from the top edge.
    -- When: Positioning icons aligned to start; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = (-((i - 1) * (itemHeight + padding)) * dir)
    end
    return offsets
end

function LayoutEngine.EndColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce Y offsets starting from the bottom edge.
    -- When: Positioning icons aligned to end; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = ((i - 1) * (itemHeight + padding) * dir)
    end
    return offsets
end

function LayoutEngine.BuildRows(iconLimit, children)
    -- Why: Group a flat list of icons into rows limited by `iconLimit`.
    -- When: Before computing centered layout for Essential/Utility viewers.
    local rows = {}
    local limit = iconLimit or 0
    if limit <= 0 then
        return rows
    end
    for i = 1, #children do
        local rowIndex = floor((i - 1) / limit) + 1
        rows[rowIndex] = rows[rowIndex] or {}
        rows[rowIndex][#rows[rowIndex] + 1] = children[i]
    end
    return rows
end

-- StateTracker: invalidation/diffing

function StateTracker.MarkViewersDirty(name)
    -- if name == "EssentialCooldownViewer" and ns.db.profile.cooldownManager_centerEssential then
    if name == "EssentialCooldownViewer" then
        CooldownManager.UpdateEssentialIfNeeded()
    end
    if name == "UtilityCooldownViewer" then
        CooldownManager.UpdateUtilityIfNeeded()
    end
end

function StateTracker.MarkBuffIconsDirty()
    -- if ns.db.profile.cooldownManager_centerBuffIcons then
    ViewerAdapters.UpdateBuffIcons()
    -- end
end

function StateTracker.MarkBuffBarsDirty()
    -- if ns.db.profile.cooldownManager_alignBuffBars then
    ViewerAdapters.UpdateBuffBarsIfNeeded()
    -- end
end

-- ViewerAdapters: BuffIcon/BuffBar collection + hooks

function ViewerAdapters.GetBuffIconFrames()
    -- Why: Collect visible Buff Icon viewer children, hook change events, and apply stack visuals.
    -- When: Before positioning buff icons and whenever aura events trigger layout updates.
    if not BuffIconCooldownViewer then
        return {}
    end
    local visible = {}
    local children = { BuffIconCooldownViewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and (child.icon or child.Icon) then
            if child:IsShown() then
                visible[#visible + 1] = child
            end
            if not child._wt_isHooked then
                child._wt_isHooked = true
                hooksecurefunc(child, "OnActiveStateChanged", StateTracker.MarkBuffIconsDirty)
                hooksecurefunc(child, "OnUnitAuraAddedEvent", StateTracker.MarkBuffIconsDirty)
                hooksecurefunc(child, "OnUnitAuraRemovedEvent", StateTracker.MarkBuffIconsDirty)
            end
        end
    end
    table.sort(visible, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return visible
end

function ViewerAdapters.GetBuffBarFrames()
    -- Why: Collect active Buff Bar frames with resilience to API differences, and hook changes.
    -- When: Before aligning bars vertically and whenever aura events trigger layout updates.
    if not BuffBarCooldownViewer then
        return {}
    end
    local frames = {}
    if BuffBarCooldownViewer.GetItemFrames then
        local ok, items = pcall(BuffBarCooldownViewer.GetItemFrames, BuffBarCooldownViewer)
        if ok and items then
            frames = items
        end
    end
    if #frames == 0 then
        local okc, children = pcall(BuffBarCooldownViewer.GetChildren, BuffBarCooldownViewer)
        if okc and children then
            for _, child in ipairs({ children }) do
                if child and child:IsObjectType("Frame") then
                    frames[#frames + 1] = child
                end
            end
        end
    end
    local active = {}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame:IsVisible() then
            active[#active + 1] = frame
        end
        if not frame._wt_isHooked and (frame.icon or frame.Icon or frame.bar or frame.Bar) then
            frame._wt_isHooked = true
            hooksecurefunc(frame, "OnActiveStateChanged", StateTracker.MarkBuffBarsDirty)
            hooksecurefunc(frame, "OnUnitAuraAddedEvent", StateTracker.MarkBuffBarsDirty)
            hooksecurefunc(frame, "OnUnitAuraRemovedEvent", StateTracker.MarkBuffBarsDirty)
        end
    end
    table.sort(active, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return active
end

function ViewerAdapters.UpdateBuffIcons()
    -- Why: Position Buff Icon viewer children based on isHorizontal, iconDirection, and alignment.
    -- When: On aura events, settings changes, or explicit refresh calls when the feature is enabled.

    if
        not ns.Runtime:IsReady(BuffIconCooldownViewer)
        or ns.db.profile.cooldownManager_alignBuffIcons_growFromDirection == "Disable"
    then
        return
    end

    local icons = ViewerAdapters.GetBuffIconFrames()
    local count = #icons
    if count == 0 then
        return
    end

    local refIcon = icons[1]
    local iconWidth = refIcon:GetWidth()
    local iconHeight = refIcon:GetHeight()
    if not iconWidth or iconWidth == 0 or not iconHeight or iconHeight == 0 then
        return
    end

    local isHorizontal = BuffIconCooldownViewer.isHorizontal ~= false
    local iconDirection = BuffIconCooldownViewer.iconDirection == 1 and "NORMAL" or "REVERSED"
    local iconDirectionModifier = iconDirection == "NORMAL" and 1 or -1
    local alignment = ns.db.profile.cooldownManager_alignBuffIcons_growFromDirection or "CENTER"
    local padding = isHorizontal and BuffIconCooldownViewer.childXPadding or BuffIconCooldownViewer.childYPadding
    local settingMap = viewerSettingsMap["BuffIconCooldownViewer"]

    if isHorizontal then
        local offsets
        local anchor, relativePoint

        if alignment == "START" then
            offsets = LayoutEngine.StartRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOPLEFT"
            relativePoint = "TOPLEFT"
        elseif alignment == "END" then
            offsets = LayoutEngine.EndRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOPRIGHT"
            relativePoint = "TOPRIGHT"
        else -- CENTER
            offsets = LayoutEngine.CenteredRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOP"
            relativePoint = "TOP"
        end

        for i, icon in ipairs(icons) do
            local x = offsets[i] or 0
            icon:ClearAllPoints()
            icon:SetPoint(anchor, BuffIconCooldownViewer, relativePoint, x, 0)
        end
    else
        -- Vertical layout
        local offsets
        local anchor, relativePoint

        if alignment == "START" then
            offsets = LayoutEngine.StartColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "TOPLEFT"
            relativePoint = "TOPLEFT"
        elseif alignment == "END" then
            offsets = LayoutEngine.EndColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "BOTTOMLEFT"
            relativePoint = "BOTTOMLEFT"
        else -- CENTER
            offsets = LayoutEngine.CenteredColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "LEFT"
            relativePoint = "LEFT"
        end

        for i, icon in ipairs(icons) do
            local y = offsets[i] or 0
            icon:ClearAllPoints()
            icon:SetPoint(anchor, BuffIconCooldownViewer, relativePoint, 0, y)
        end
    end
end

function ViewerAdapters.UpdateBuffBarsIfNeeded()
    -- Why: Align Buff Bar frames from chosen growth direction when enabled and changes detected.
    -- When: On aura events, settings changes, or explicit refresh calls when the feature is enabled.
    if
        not ns.Runtime:IsReady(BuffBarCooldownViewer)
        or ns.db.profile.cooldownManager_alignBuffBars_growFromDirection == "Disable"
    then
        return
    end

    local bars = ViewerAdapters.GetBuffBarFrames()
    local count = #bars
    if count == 0 then
        return
    end

    local refBar = bars[1]
    local barHeight = refBar and refBar:GetHeight()
    local spacing = BuffBarCooldownViewer.childYPadding or 0
    if not barHeight or barHeight == 0 then
        return
    end

    local growFromBottom = ns.db.profile.cooldownManager_alignBuffBars_growFromDirection == "BOTTOM"

    for index, bar in ipairs(bars) do
        local offsetIndex = index - 1
        local y = growFromBottom and offsetIndex * (barHeight + spacing) or -offsetIndex * (barHeight + spacing)
        y = y
        bar:ClearAllPoints()
        if growFromBottom then
            bar:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y)
        else
            bar:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, y)
        end
    end
end

function ViewerAdapters.CollectViewerChildren(viewer)
    -- Why: Standardized filtered list of visible icon-like children sorted by layoutIndex.
    -- When: Building rows/columns for Essential/Utility centered layouts.
    local all = {}
    local viewerName = viewer:GetName()
    local toDim = viewerName == "UtilityCooldownViewer" and ns.db.profile.cooldownManager_utility_dimWhenNotOnCD
    local toDimOpacity = ns.db.profile.cooldownManager_utility_dimOpacity or 0.3
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child:IsShown() and child.Icon then
            all[#all + 1] = child

            -- TODO move from cooldown manager.lua
            if child.cooldownID and toDim then
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(child.cooldownID)
                if not C_Spell.GetSpellCooldown(info.spellID).isOnGCD then
                    local cd = nil
                    if not issecretvalue(child.cooldownChargesShown) and child.cooldownChargesShown then
                        cd = ns.CooldownTracker:getChargeCD(info.spellID)
                    else
                        cd = ns.CooldownTracker:getSpellCD(info.spellID)
                    end

                    local curve = C_CurveUtil.CreateCurve()
                    curve:AddPoint(0.0, toDimOpacity)
                    curve:AddPoint(0.1, 1)
                    local EvaluateDuration = cd.EvaluateRemainingDuration and cd:EvaluateRemainingDuration(curve)

                    child:SetAlpha(EvaluateDuration)
                end
            else
                child:SetAlpha(1)
            end
        end
    end
    table.sort(all, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return all
end

local function PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor)
    -- Why: Place a single horizontal row centered with optional reversed direction and stack visuals.
    -- When: Essential/Utility viewers are horizontal or configured to grow by rows.
    local count = #row
    local xOffsets = LayoutEngine.CenteredRowXOffsets(count, w, padding, iconDirectionModifier)
    for i, icon in ipairs(row) do
        local x = xOffsets[i] or 0
        local point, relativeTo, relativePoint, offsetX, offsetY = icon:GetPoint()
        local xDiff = math.abs(x - offsetX)
        local yDiff = math.abs(yOffset - offsetY)
        if point == rowAnchor and relativePoint == rowAnchor and xDiff < 1 and yDiff < 1 then
            -- No need to reposition
        else
            if xDiff <= 1 then
                x = offsetX
            end
            icon:ClearAllPoints()
            icon:SetPoint(rowAnchor, viewer, rowAnchor, x, yOffset)
        end
    end
end

local function PositionRowVertical(viewer, row, xOffset, h, padding, iconDirectionModifier, colAnchor)
    -- Why: Place a single vertical column centered with optional reversed direction and stack visuals.
    -- When: Essential/Utility viewers are vertical or configured to grow by columns.
    local count = #row
    local yOffsets = LayoutEngine.CenteredColYOffsets(count, h, padding, iconDirectionModifier)
    for i, icon in ipairs(row) do
        local y = yOffsets[i] or 0
        icon:ClearAllPoints()
        icon:SetPoint(colAnchor, viewer, colAnchor, xOffset, y)
    end
end

local sizeSavedValues = {
    EssentialCooldownViewer = { width = 0, height = 0 },
    UtilityCooldownViewer = { width = 0, height = 0 },
}

function ViewerAdapters.CenterAllRows(viewer, fromDirection)
    -- Why: Core centering routine that groups children into rows/columns and applies offsets.
    -- When: `UpdateEssentialIfNeeded` or `UpdateUtilityIfNeeded` determines changes require recompute.
    if not ns.Runtime:IsReady(viewer) then
        return
    end

    local viewerName = viewer:GetName()

    local isHorizontal = viewer.isHorizontal ~= false
    local iconDirection = viewer.iconDirection == 1 and "NORMAL" or "REVERSED"
    local iconLimit = viewer.iconLimit or 0
    if iconLimit <= 0 then
        return
    end

    local children = ViewerAdapters.CollectViewerChildren(viewer)
    -- todo refactor DIMing as now we have to "early" return just here, to leave dimming working
    if fromDirection == "Disable" or #children == 0 then
        return
    end

    local first = children[1]
    if not first then
        return
    end
    local w, h = first:GetWidth(), first:GetHeight()
    if not w or w == 0 or not h or h == 0 then
        return
    end

    local padding = isHorizontal and viewer.childXPadding or viewer.childYPadding
    if viewerName == "UtilityCooldownViewer" and ns.db.profile.cooldownManager_limitUtilitySizeToEssential then
        local essentialViewer = viewers["EssentialCooldownViewer"]
        if essentialViewer then
            local eWidth = essentialViewer:GetWidth()
            if eWidth and eWidth > 0 then
                local iconActualWidth = (w + padding) * viewer.iconScale
                local maxIcons = floor((eWidth + (padding * viewer.iconScale)) / iconActualWidth)
                if maxIcons > 0 then
                    iconLimit = math.max(math.min(iconLimit, maxIcons), math.min(iconLimit, 5))
                end
            end
        end
    end

    local rows = LayoutEngine.BuildRows(iconLimit, children)
    if #rows == 0 then
        return
    end

    if isHorizontal then
        local rowOffsetModifier = fromDirection == "BOTTOM" and 1 or -1
        local iconDirectionModifier = iconDirection == "NORMAL" and 1 or -1
        local rowAnchor = (fromDirection == "BOTTOM") and "BOTTOM" or "TOP"
        for iRow, row in ipairs(rows) do
            local yOffset = (iRow - 1) * (h + padding) * rowOffsetModifier
            PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor)
        end
    else
        local rowOffsetModifier = fromDirection == "BOTTOM" and -1 or 1
        local iconDirectionModifier = iconDirection == "NORMAL" and -1 or 1
        local colAnchor = (fromDirection == "BOTTOM") and "RIGHT" or "LEFT"
        for iRow, row in ipairs(rows) do
            local xOffset = (iRow - 1) * (w + padding) * rowOffsetModifier
            PositionRowVertical(viewer, row, xOffset, h, padding, iconDirectionModifier, colAnchor)
        end
    end
end

function CooldownManager.UpdateEssentialIfNeeded()
    -- Why: Back-compat entrypoint to center Essential viewer when enabled.
    -- When: On layout refresh events or explicit refresh calls; early-outs if viewer missing or feature disabled.

    local growKey = "cooldownManager_centerEssential_growFromDirection"
    ViewerAdapters.CenterAllRows(EssentialCooldownViewer, ns.db.profile[growKey])
end

function CooldownManager.UpdateUtilityIfNeeded()
    -- Why: Back-compat entrypoint to center Utility viewer when enabled.
    -- When: On layout refresh events or explicit refresh calls; early-outs if viewer missing or feature disabled.
    local growKey = "cooldownManager_centerUtility_growFromDirection"
    ViewerAdapters.CenterAllRows(UtilityCooldownViewer, ns.db.profile[growKey])
end

local function ShouldDebugRefreshLog()
    if ns.db.profile.cooldownManager_debugRefreshLogs ~= nil then
        return ns.db.profile.cooldownManager_debugRefreshLogs
    end
    return false
end

function CooldownManager.ForceRefresh(parts)
    parts = parts or { icons = true, bars = true, essential = true, utility = true }
    if parts.icons then
        StateTracker.MarkBuffIconsDirty()
    end
    if parts.bars then
        StateTracker.MarkBuffBarsDirty()
    end
    if parts.essential then
        StateTracker.MarkViewersDirty("EssentialCooldownViewer")
    end
    if parts.utility then
        StateTracker.MarkViewersDirty("UtilityCooldownViewer")
    end
end

function CooldownManager.ForceRefreshAll()
    CooldownManager.ForceRefresh({ icons = true, bars = true, essential = true, utility = true })
end

-- EventHandler: events

EventHandler.frame = EventHandler.frame or CreateFrame("FRAME")
EventHandler.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventHandler.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
EventHandler.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventHandler.frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
EventHandler.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
EventHandler.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventHandler.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventHandler.frame:RegisterEvent("CINEMATIC_STOP")

-- Simple event→refresh routing map for targeted invalidation where safe
EventHandler.EventRefreshMap = {
    PLAYER_SPECIALIZATION_CHANGED = { essential = true, utility = true },
    CINEMATIC_STOP = { essential = true, utility = true },
}

EventHandler.frame:SetScript("OnEvent", function(_, event)
    local parts = EventHandler.EventRefreshMap[event]
    if event == "PLAYER_REGEN_DISABLED" then
        C_Timer.After(0, function()
            CooldownManager.ForceRefreshAll()
        end)
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" and ns.db.profile.cooldownManager_utility_dimWhenNotOnCD then
        C_Timer.After(0, function()
            CooldownManager.ForceRefresh({ utility = true })
        end)
        return
    end
    if parts then
        CooldownManager.ForceRefresh(parts)
    else
        CooldownManager.ForceRefreshAll()
    end
end)

EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
    PrintDebug("CooldownViewerSettings.OnDataChanged triggered refresh")
    -- ns.Stacks:ApplyAllStackFonts()
    CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnDataChanged")
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
    PrintDebug("CooldownViewerSettings.OnShow triggered refresh")
    CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnShow")
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
    PrintDebug("CooldownViewerSettings.OnHide triggered refresh")
    CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnHide")
end)

EventRegistry:RegisterCallback("EditMode.Exit", function()
    CooldownManager.ForceRefreshAll()
end)

local viewerReasonPartsMap = {
    EssentialCooldownViewer = { essential = true },
    UtilityCooldownViewer = { utility = true },
    BuffIconCooldownViewer = { icons = true },
    BuffBarCooldownViewer = { bars = true },
}

for n, v in pairs(viewers) do
    if v.RefreshLayout then
        hooksecurefunc(v, "RefreshLayout", function()
            -- print("RefreshLayout called for", n)
            CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
            C_Timer.After(0, function()
                CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
            end)
        end)
    end
    -- if v.Layout then
    --     hooksecurefunc(v, "Layout", function()
    --         print("Layout called for", n)
    --         CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
    --         C_Timer.After(0, function()
    --             CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
    --         end)
    --     end)
    -- end
end

function CooldownManager.Initialize()
    CooldownManager.ForceRefreshAll()
end

--[[DEBUG EVENTS] ]
local _ignoredEvents = {
    OnUpdate = true,
    OnUnitAura = true,
    OnUnitTarget = true,
    CacheLayoutSettings = true,
    IgnoreLayoutIndex = true,
    AddLayoutChildren = true,
    IsDirty = true,
    MarkClean = true,
    OnCleaned = true,
    IsLayoutFrame = true,
    RefreshActiveFramesForTargetChange = true,
}
C_Timer.After(3, function()
    for n, v in pairs(UtilityCooldownViewer) do
        if type(v) == "function" then
            -- print(n)
        end
        if type(v) == "function" and not _ignoredEvents[n] then
            hooksecurefunc(UtilityCooldownViewer, n, function(...)
                local str = n .. ":"
                for i, v in ipairs(...) do
                    if type(v) == "string" then
                        str = str + v
                    end
                end
                if str ~= "" then
                    print(str)
                end
            end)
        end
    end
end)
--]]

--[[DEBUG] ]
local testFrame = CreateFrame("FRAME")
local testData = {
    iconHeight = nil,
    iconWidth = nil,
    firstIconCenterX = nil,
    firstIconCenterY = nil,
    elementHeight = nil,
    elementTop = nil,
    elementBottom = nil,
}
testFrame:SetScript("OnUpdate", function(_, elapsed)
    local viewer = UtilityCooldownViewer
    if not viewer then
        return
    end
    local children = ViewerAdapters.CollectViewerChildren(viewer)
    if not children or #children == 0 then
        return
    end

    for _, child in ipairs(children) do
        local icon = child and (child.icon or child.Icon)
        if icon then
            if testData.iconHeight ~= icon:GetHeight() then
                print("Icon Height changed:", testData.iconHeight, "->", icon:GetHeight())
            end
            testData.iconHeight = icon:GetHeight()
            if testData.iconWidth ~= icon:GetWidth() then
                print("Icon Width changed:", testData.iconWidth, "->", icon:GetWidth())
            end
            testData.iconWidth = icon:GetWidth()
            local x, y = icon:GetCenter()

            if testData.firstIconCenterX ~= x then
                print("First Icon Center X changed:", testData.firstIconCenterX, "->", x)
            end

            testData.firstIconCenterX = x
            if testData.firstIconCenterY ~= y then
                print("First Icon Center Y changed:", testData.firstIconCenterY, "->", y)
            end
            testData.firstIconCenterY = y

            break
        end
    end
    if testData.elementHeight ~= viewer:GetHeight() then
        print("Viewer Height changed:", testData.elementHeight, "->", viewer:GetHeight())
    end
    testData.elementHeight = viewer:GetHeight()
    if testData.elementTop ~= viewer:GetTop() then
        print("Viewer Top changed:", testData.elementTop, "->", viewer:GetTop())
    end
    testData.elementTop = viewer:GetTop()
    if testData.elementBottom ~= viewer:GetBottom() then
        print("Viewer Bottom changed:", testData.elementBottom, "->", viewer:GetBottom())
    end
    testData.elementBottom = viewer:GetBottom()
end)
--]]
-- local lastPointY = nil
-- C_Timer.NewTicker(0.2, function()
--     local point, relativeTo, relativePoint, offsetX, offsetY = EssentialCooldownViewer:GetPoint(1)
--     if lastPointY ~= offsetY then
--         DevTools_Dump({
--             point = point,
--             relativeTo = relativeTo and relativeTo:GetName() or "nil",
--             relativePoint = relativePoint,
--             offsetX = offsetX,
--             offsetY = offsetY,
--         })
--         lastPointY = offsetY
--     end
-- end)

-- hooksecurefunc(EssentialCooldownViewer, "SetPoint", function()
--     print("EssentialCooldownViewer SetPoint called")
-- end)
